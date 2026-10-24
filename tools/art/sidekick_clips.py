"""Add Attack / Hit / Special (and Run / Idle variants) clips to the sidekick GLBs.

usage: python3 tools/art/sidekick_clips.py [model ...]   (default: all)

Keyframes the models' own rigs by editing the GLB directly (the same approach as
mimic_hop.py): new animations are appended, nothing else in the file changes, so
meshes, skins, materials and textures stay byte-identical and the shipped clips
(Idle, Walk, ...) are untouched. Re-running is idempotent: clips this tool owns
(see OWNED) are dropped and rebuilt from the original data.

Each new clip = a base clip from the model sampled over time (so flapping wings,
breathing etc. keep going) + hand-keyed offsets. Offsets are rotations about
*model-space* axes (x: pitch, + leans forward / nose down; z: roll, + raises the
model's left side; for L/R roles y and z mirror on bones sitting on the right) and a root translation in
model heights (+z forward, +y up). Model space: +Y up, +Z forward (Godot import).
"""
import json, struct, sys, re, math, os
import numpy as np
from scipy.spatial.transform import Rotation as R, Slerp

DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'sidekicks')
FPS = 30
OWNED = {'Attack', 'Hit', 'Special', 'Run', 'Hover', 'Idle_Loop', 'Walk_Loop'}

# ---------------------------------------------------------------- glb io
def load(p):
    b = open(p, 'rb').read(); n = struct.unpack('<I', b[12:16])[0]
    j = json.loads(b[20:20 + n]); bn = struct.unpack('<I', b[20 + n:24 + n])[0]
    return j, bytearray(b[28 + n:28 + n + bn])

def save(p, j, bin_):
    while len(bin_) % 4: bin_.append(0)
    j['buffers'][0]['byteLength'] = len(bin_)
    js = json.dumps(j, separators=(',', ':')).encode(); js += b' ' * ((4 - len(js) % 4) % 4)
    open(p, 'wb').write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bin_))
                        + struct.pack('<II', len(js), 0x4E4F534A) + js
                        + struct.pack('<II', len(bin_), 0x004E4942) + bytes(bin_))

NCOMP = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}
def read_acc(j, bin_, i):
    a = j['accessors'][i]; v = j['bufferViews'][a['bufferView']]
    assert a['componentType'] == 5126, 'float accessors only'
    n = NCOMP[a['type']]; off = v.get('byteOffset', 0) + a.get('byteOffset', 0)
    stride = v.get('byteStride', 4 * n)
    raw = np.frombuffer(bytes(bin_[off:off + stride * (a['count'] - 1) + 4 * n]), dtype=np.uint8)
    out = np.empty((a['count'], n), np.float32)
    for k in range(a['count']):
        out[k] = np.frombuffer(raw[k * stride:k * stride + 4 * n].tobytes(), np.float32)
    return out[:, 0] if n == 1 else out

def write_acc(j, bin_, arr, typ):
    arr = np.ascontiguousarray(np.asarray(arr, dtype=np.float32))
    while len(bin_) % 4: bin_.append(0)
    off = len(bin_); bin_.extend(arr.tobytes())
    j['bufferViews'].append({'buffer': 0, 'byteOffset': off, 'byteLength': arr.nbytes})
    acc = {'bufferView': len(j['bufferViews']) - 1, 'componentType': 5126, 'count': len(arr), 'type': typ}
    if typ == 'SCALAR': acc['min'] = [float(arr.min())]; acc['max'] = [float(arr.max())]
    j['accessors'].append(acc); return len(j['accessors']) - 1

# ---------------------------------------------------------------- pose sampling
class Model:
    def __init__(self, j, bin_):
        self.j, self.bin = j, bin_
        self.nodes = j['nodes']; self.parent = {}
        for i, n in enumerate(self.nodes):
            for c in n.get('children', []): self.parent[c] = i
        self.byname = {n.get('name', ''): i for i, n in enumerate(self.nodes)}
        self.tracks = {}  # clip -> {(node, path): (times, values, interp)}
        for a in j.get('animations', []):
            tr = {}
            for c in a['channels']:
                s = a['samplers'][c['sampler']]
                tr[(c['target']['node'], c['target']['path'])] = (
                    read_acc(j, bin_, s['input']), read_acc(j, bin_, s['output']), s.get('interpolation', 'LINEAR'))
            self.tracks[a['name']] = tr
        self.length = {k: max(float(v[0][-1]) for v in tr.values()) for k, tr in self.tracks.items()}

    def rest(self, i, path):
        n = self.nodes[i]
        if 'matrix' in n:
            m = np.array(n['matrix']).reshape(4, 4).T
            if path == 'translation': return m[:3, 3]
            sc = np.linalg.norm(m[:3, :3], axis=0)
            if path == 'scale': return sc
            return R.from_matrix(m[:3, :3] / sc).as_quat()
        return np.array(n.get(path, {'translation': [0, 0, 0], 'rotation': [0, 0, 0, 1], 'scale': [1, 1, 1]}[path]), float)

    def sample(self, clip, i, path, t):
        tr = self.tracks.get(clip, {}).get((i, path))
        if tr is None: return self.rest(i, path)
        ts, vs, interp = tr
        if len(ts) == 1 or t <= ts[0]: return np.array(vs[0], float)
        if t >= ts[-1]: return np.array(vs[-1], float)
        k = int(np.searchsorted(ts, t) - 1); u = (t - ts[k]) / max(ts[k + 1] - ts[k], 1e-9)
        if interp == 'STEP': return np.array(vs[k], float)
        a, b = np.array(vs[k], float), np.array(vs[k + 1], float)
        if path == 'rotation':
            if np.dot(a, b) < 0: b = -b
            q = a * (1 - u) + b * u; return q / np.linalg.norm(q)
        return a * (1 - u) + b * u

    def local(self, pose, i):
        t, q, s = pose.get((i, 'translation')), pose.get((i, 'rotation')), pose.get((i, 'scale'))
        t = self.rest(i, 'translation') if t is None else t
        q = self.rest(i, 'rotation') if q is None else q
        s = self.rest(i, 'scale') if s is None else s
        m = np.eye(4); m[:3, :3] = R.from_quat(q).as_matrix() * s; m[:3, 3] = t; return m

    def globals(self, pose):
        g = {}
        def go(i, pm):
            m = pm @ self.local(pose, i); g[i] = m
            for c in self.nodes[i].get('children', []): go(c, m)
        for r in self.j['scenes'][0]['nodes']: go(r, np.eye(4))
        return g

def rot_of(m):
    a = m[:3, :3]; return R.from_matrix(a / np.linalg.norm(a, axis=0))

# ---------------------------------------------------------------- curves
def curve(keys, t):
    """keys [(t, v)], smooth (ease in-out) between keys, v scalar or tuple."""
    if not keys: return 0.0
    if t <= keys[0][0]: return np.array(keys[0][1], float)
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t <= t1:
            u = (t - t0) / max(t1 - t0, 1e-9); u = u * u * (3 - 2 * u)
            return np.array(v0, float) * (1 - u) + np.array(v1, float) * u
    return np.array(keys[-1][1], float)

# ---------------------------------------------------------------- build
def build_clip(m, cfg, name, spec):
    """spec: dur, base, speed, offs {role: [(axis, keys)]}, root [(t,(x,y,z))], calm (0..1 toward rest)."""
    dur = spec['dur']; base = spec.get('base', cfg['idle']); speed = spec.get('speed', 1.0)
    blen = m.length.get(base, dur); H = cfg['H']
    roles = {}
    for role, pat in cfg['roles'].items():
        ids = [i for n, i in m.byname.items() if re.fullmatch(pat, n)]
        if not ids and role in spec.get('offs', {}): raise SystemExit(f'{cfg["file"]}: role {role} /{pat}/ matched nothing')
        roles[role] = ids
    base_tracks = sorted({k for k in m.tracks.get(base, {})})
    rot_nodes = set(i for (i, p) in base_tracks if p == 'rotation')
    off_nodes = {}
    for role, lst in spec.get('offs', {}).items():
        for r2 in [role] + cfg.get('link', {}).get(role, []):
            ids = roles[r2]
            for i in ids: off_nodes.setdefault(i, []).append((r2, lst, 1 if r2 in cfg.get('flat', ()) else len(ids)))
    rot_nodes |= set(off_nodes)
    root = m.byname[cfg['root']]
    times = np.arange(0, dur + 1e-6, 1.0 / FPS); times[-1] = dur
    out = {k: [] for k in base_tracks}
    for i in rot_nodes: out.setdefault((i, 'rotation'), [])
    out.setdefault((root, 'translation'), [])
    calm = spec.get('calm', 0.0)
    # Side of each offset bone from where it actually sits (rig names lie: some
    # ".l" bones are on the model's right). +x is the model's left.
    g0 = m.globals({kk: m.sample(base, kk[0], kk[1], 0.0) for kk in base_tracks})
    rx = g0[root][0, 3]
    side = {i: (-1 if g0[i][0, 3] < rx - 1e-6 else 1) for i in off_nodes}
    for t in times:
        pp = spec.get('pp', cfg.get('base_pp') if base == cfg['idle'] and 'speed' not in spec else None)
        if pp:  # ping-pong a clean segment (a, b) of the base take, period p
            a, b, per = pp; u = (t / per) % 1.0
            bt = a + (b - a) * (1 - abs(1 - 2 * u))
        else:
            bt = (t * speed + spec.get('t0', 0.0)) % blen if blen > 0 else 0.0
        pose = {k: m.sample(base, k[0], k[1], bt) for k in base_tracks}
        if calm:
            for (i, p), v in list(pose.items()):
                if p == 'rotation':
                    pose[(i, p)] = Slerp([0, 1], R.from_quat([v, m.rest(i, p)]))([calm])[0].as_quat()
        g = m.globals(pose)
        for (i, p) in out:
            if p == 'rotation':
                q = pose.get((i, 'rotation'), m.rest(i, 'rotation'))
                if i in off_nodes:
                    pr = rot_of(g[m.parent[i]]) if i in m.parent else R.identity()
                    w = R.identity()
                    for role, lst, cnt in off_nodes[i]:
                        mir = side[i] if role[-1] in 'LR' else 1
                        for axis, keys in lst:
                            ang = float(curve(keys, t)) / cnt
                            if axis != 'x': ang *= mir
                            w = R.from_euler(axis, ang, degrees=True) * w
                    q = (pr.inv() * w * pr * R.from_quat(q)).as_quat()
                out[(i, p)].append(q)
            elif p == 'translation' and i == root:
                v = np.array(pose.get((i, p), m.rest(i, p)), float)
                d = curve(spec.get('root', []), t)
                if np.ndim(d):
                    pm = g[m.parent[i]] if i in m.parent else np.eye(4)
                    v = v + np.linalg.inv(pm[:3, :3]) @ (np.asarray(d) * H)
                out[(i, p)].append(v)
            else:
                out[(i, p)].append(pose.get((i, p), m.rest(i, p)))
    j, bin_ = m.j, m.bin
    tin = write_acc(j, bin_, times, 'SCALAR')
    anim = {'name': name, 'channels': [], 'samplers': []}
    for (i, p), vals in sorted(out.items()):
        vals = np.array(vals)
        if p == 'rotation':  # keep hemisphere continuity
            for k in range(1, len(vals)):
                if np.dot(vals[k], vals[k - 1]) < 0: vals[k] = -vals[k]
        anim['samplers'].append({'input': tin, 'output': write_acc(j, bin_, vals, 'VEC4' if p == 'rotation' else 'VEC3'), 'interpolation': 'LINEAR'})
        anim['channels'].append({'sampler': len(anim['samplers']) - 1, 'target': {'node': i, 'path': p}})
    j['animations'].append(anim)

def tscn_scale(name):
    txt = open(os.path.join(DIR, name + '.tscn')).read()
    return float(re.search(r'transform = Transform3D\(([-\d.e]+)', txt).group(1))

def run(key):
    from sidekick_clip_specs import MODELS
    cfg = MODELS[key]; path = os.path.join(DIR, cfg['file'] + '_src.glb')
    j, bin_ = load(path)
    # Drop only what this model's spec rebuilds (the squire ships its own Run).
    j['animations'] = [a for a in j.get('animations', []) if a['name'] not in OWNED or a['name'] not in cfg['clips']]
    m = Model(j, bin_)
    # model height in scene units: wrapper scales the glb to 1 m, times Sketchfab root scale
    cfg['H'] = 1.0 / tscn_scale(cfg['file'])
    for name, spec in cfg['clips'].items():
        build_clip(m, cfg, name, spec)
    save(path, m.j, m.bin)
    print(key, [a['name'] for a in m.j['animations']], f'{os.path.getsize(path)/1e6:.2f} MB')

if __name__ == '__main__':
    sys.path.insert(0, os.path.dirname(__file__))
    from sidekick_clip_specs import MODELS
    for k in sys.argv[1:] or list(MODELS): run(k)
