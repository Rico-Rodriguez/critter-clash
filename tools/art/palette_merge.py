"""palette_merge.py in.glb out.glb [--drop-prefixed] [--recolor R,G,B=R,G,B ...]: one draw for a flat-colour skinned model.

Quaternius-style rigs colour each part with its own factor-only material (a wolf has four). The
foe budget is one material, so this merges the primitives of the (single) skinned mesh node into one
and gives it one material whose base-colour texture is a palette: one 8x8 px cell per original
colour, each vertex's UV pointing at its cell centre. Metallic, roughness and every colour stay
exactly as authored (the factors move into the texture, sRGB-encoded), so the render is the same.
Needs numpy and Pillow. --drop-prefixed drops the "Armature|Clip" duplicates of plain clip names.
--recolor swaps one authored colour (8-bit sRGB) for another in the palette, e.g. to blank out eye whites
and pupils into one glowing colour; the one case where a colour is not kept as authored."""
import json, struct, sys, io, numpy as np
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
b = open(src, 'rb').read(); n = struct.unpack('<I', b[12:16])[0]; j = json.loads(b[20:20 + n])
bn = struct.unpack('<I', b[20 + n:24 + n])[0]; bin_ = bytearray(b[28 + n:28 + n + bn])
CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {'MAT4': 16, 'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}
def read(ai):
    a = j['accessors'][ai]; bv = j['bufferViews'][a['bufferView']]; dt = np.dtype(CT[a['componentType']]); nc = NC[a['type']]
    st = bv.get('byteStride', dt.itemsize * nc); off = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    raw = np.frombuffer(bytes(bin_), dtype=np.uint8, count=st * (a['count'] - 1) + dt.itemsize * nc, offset=off)
    out = np.lib.stride_tricks.as_strided(raw, shape=(a['count'], dt.itemsize * nc), strides=(st, 1)).copy().view(dt).reshape(a['count'], nc)
    return out, a
def write(arr, ct, typ, target=None):
    arr = np.ascontiguousarray(arr.astype(CT[ct]))
    while len(bin_) % 4: bin_.append(0)
    off = len(bin_); bin_.extend(arr.tobytes())
    bv = {'buffer': 0, 'byteOffset': off, 'byteLength': arr.nbytes}
    if target: bv['target'] = target
    j['bufferViews'].append(bv)
    acc = {'bufferView': len(j['bufferViews']) - 1, 'componentType': ct, 'count': len(arr), 'type': typ}
    if typ == 'VEC3' and ct == 5126: acc['min'] = arr.min(0).tolist(); acc['max'] = arr.max(0).tolist()
    j['accessors'].append(acc); return len(j['accessors']) - 1

nodes = [i for i, nd in enumerate(j['nodes']) if 'mesh' in nd]
assert len(nodes) == 1, 'one mesh node expected (run merge_skinned.py first)'
mesh = j['meshes'][j['nodes'][nodes[0]]['mesh']]
mats = [j['materials'][p['material']] for p in mesh['primitives']]
for m in mats:
    assert not any(k in m for k in ('normalTexture', 'emissiveTexture', 'occlusionTexture')), 'flat-colour models only'
    assert 'baseColorTexture' not in m['pbrMetallicRoughness'], 'flat-colour models only'
ref = mats[0]['pbrMetallicRoughness']
for m in mats:
    p = m['pbrMetallicRoughness']
    assert abs(p.get('metallicFactor', 1) - ref.get('metallicFactor', 1)) < 1e-4 and abs(p.get('roughnessFactor', 1) - ref.get('roughnessFactor', 1)) < 1e-4, 'materials differ beyond colour'
    assert not any(m.get('emissiveFactor', [0, 0, 0])), 'emissive colours not carried'
cells = []   # distinct colours, in first-use order
cell_of = []
for m in mats:
    c = tuple(round(x, 5) for x in m['pbrMetallicRoughness'].get('baseColorFactor', [1, 1, 1, 1]))
    if c not in cells: cells.append(c)
    cell_of.append(cells.index(c))
C = 8; W = C * len(cells)
def srgb(x): x = np.clip(np.array(x[:3]), 0, 1); return np.where(x <= 0.0031308, x * 12.92, 1.055 * np.power(x, 1 / 2.4) - 0.055)
img = np.zeros((C, W, 3), np.uint8)
for i, c in enumerate(cells): img[:, i * C:(i + 1) * C] = np.round(srgb(c) * 255).astype(np.uint8)
for a in sys.argv[3:]:
    if a == '--recolor': continue
    if '=' in a:
        old, new = [np.array([int(v) for v in h.split(',')], np.uint8) for h in a.split('=')]
        hit = np.all(img == old, axis=2); assert hit.any(), 'no palette cell is ' + a
        img[hit] = new
buf = io.BytesIO(); Image.fromarray(img).save(buf, 'PNG')
A = {}; I = []; base = 0; uvs = []
keys = set.intersection(*[set(p['attributes']) for p in mesh['primitives']]) - {'TEXCOORD_0'}
for k in keys: A[k] = []
for p, ci in zip(mesh['primitives'], cell_of):
    cnt = j['accessors'][p['attributes']['POSITION']]['count']
    for k in keys: A[k].append(read(p['attributes'][k])[0])
    I.append(read(p['indices'])[0][:, 0].astype(np.uint32) + base); base += cnt
    uvs.append(np.tile([(ci * C + C / 2) / W, 0.5], (cnt, 1)))
att = {}
for k in keys:
    v = np.concatenate(A[k]); a0 = j['accessors'][mesh['primitives'][0]['attributes'][k]]
    if k.startswith('JOINTS'): att[k] = write(v, 5123, 'VEC4', 34962)
    elif a0['componentType'] != 5126:   # normalised ints (weights): keep the type
        acc = write(v, a0['componentType'], a0['type'], 34962); j['accessors'][acc]['normalized'] = a0.get('normalized', False); att[k] = acc
    else: att[k] = write(v, 5126, a0['type'], 34962)
att['TEXCOORD_0'] = write(np.concatenate(uvs).astype(np.float32), 5126, 'VEC2', 34962)
prim = {'attributes': att, 'indices': write(np.concatenate(I), 5125, 'SCALAR', 34963), 'material': 0}
mesh['primitives'] = [prim]
j['meshes'] = [mesh]; j['nodes'][nodes[0]]['mesh'] = 0   # drop meshes nothing uses (merge_skinned.py leaves the originals)
while len(bin_) % 4: bin_.append(0)
off = len(bin_); bin_.extend(buf.getvalue())
j['bufferViews'].append({'buffer': 0, 'byteOffset': off, 'byteLength': len(buf.getvalue())})
j['images'] = [{'bufferView': len(j['bufferViews']) - 1, 'mimeType': 'image/png', 'name': 'palette'}]
j['samplers'] = [{'magFilter': 9728, 'minFilter': 9728, 'wrapS': 33071, 'wrapT': 33071}]
j['textures'] = [{'source': 0, 'sampler': 0}]
mat = {'name': 'palette', 'pbrMetallicRoughness': {'baseColorTexture': {'index': 0}, 'metallicFactor': ref.get('metallicFactor', 1), 'roughnessFactor': ref.get('roughnessFactor', 1)}}
if any(m.get('doubleSided') for m in mats): mat['doubleSided'] = True
j['materials'] = [mat]
if '--drop-prefixed' in sys.argv:
    names = {a['name'] for a in j['animations']}
    j['animations'] = [a for a in j['animations'] if '|' not in a['name'] or a['name'].split('|')[-1] not in names]
# drop accessors/views nothing references any more
used = set()
def walk(o):
    if isinstance(o, dict):
        for k, v in o.items():
            if k in ('POSITION', 'NORMAL', 'JOINTS_0', 'WEIGHTS_0', 'TEXCOORD_0') and isinstance(v, int): used.add(v)
            elif k in ('indices', 'input', 'output', 'inverseBindMatrices') and isinstance(v, int): used.add(v)
            else: walk(v)
    elif isinstance(o, list):
        for x in o: walk(x)
walk(j['meshes']); walk(j['animations']); walk(j['skins'])
amap = {}; accs = []
for i, a in enumerate(j['accessors']):
    if i in used: amap[i] = len(accs); accs.append(a)
vused = {a['bufferView'] for a in accs} | {im['bufferView'] for im in j['images']}
vmap = {}; views = []; nb = bytearray()
for i, v in enumerate(j['bufferViews']):
    if i in vused:
        while len(nb) % 4: nb.append(0)
        vmap[i] = len(views); w = dict(v); w['byteOffset'] = len(nb); nb.extend(bin_[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']]); views.append(w)
for a in accs: a['bufferView'] = vmap[a['bufferView']]
for im in j['images']: im['bufferView'] = vmap[im['bufferView']]
def remap(o):
    if isinstance(o, dict):
        for k, v in o.items():
            if k in ('POSITION', 'NORMAL', 'JOINTS_0', 'WEIGHTS_0', 'TEXCOORD_0', 'indices', 'input', 'output', 'inverseBindMatrices') and isinstance(v, int): o[k] = amap[v]
            else: remap(v)
    elif isinstance(o, list):
        for x in o: remap(x)
remap(j['meshes']); remap(j['animations']); remap(j['skins'])
j['accessors'] = accs; j['bufferViews'] = views; bin_ = nb
while len(bin_) % 4: bin_.append(0)
j['buffers'] = [{'byteLength': len(bin_)}]
js = json.dumps(j, separators=(',', ':')).encode(); js += b' ' * ((4 - len(js) % 4) % 4)
open(dst, 'wb').write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bin_)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(bin_), 0x004E4942) + bytes(bin_))
print('colours', len(cells), 'tris', sum(len(i) for i in I) // 3, 'anims', len(j['animations']), f'{len(js)+len(bin_)} bytes')
