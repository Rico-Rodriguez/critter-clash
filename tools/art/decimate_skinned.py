# blender -b -P tools/art/decimate_skinned.py -- in.glb out.glb max_tris
# For a glb whose skinned meshes were first merged by merge_skinned.py (nodes, skeleton, clips and
# materials must stay byte-for-byte what the artist shipped). decimate_glb.py re-exports through
# Blender, which rewrites the rig (FBX-origin armatures lose their clips) and turns
# KHR_materials_pbrSpecularGlossiness into a darker specular/ior approximation. This script uses
# Blender only as the decimator: it imports, collapse-decimates, reads the vertices back, maps them to
# the original glTF space, and writes ONLY the replaced primitives into the original file.
# Mesh is rebuilt from the glb arrays rather than imported. Keeps UVs, per-corner normals and the 4 strongest joint weights; drops TANGENT (Godot regenerates).
import bpy, sys, json, struct
import numpy as np
a = sys.argv[sys.argv.index('--') + 1:]; src, dst, cap = a[0], a[1], int(a[2])
b = open(src, 'rb').read(); n = struct.unpack('<I', b[12:16])[0]; j = json.loads(b[20:20 + n])
bn = struct.unpack('<I', b[20 + n:24 + n])[0]; bin_ = bytearray(b[28 + n:28 + n + bn])
CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}
def read(ai):
    ac = j['accessors'][ai]; bv = j['bufferViews'][ac['bufferView']]; dt = np.dtype(CT[ac['componentType']]); nc = NC[ac['type']]
    off = bv.get('byteOffset', 0) + ac.get('byteOffset', 0); st = bv.get('byteStride', dt.itemsize * nc)
    raw = np.frombuffer(bytes(bin_), np.uint8, count=st * (ac['count'] - 1) + dt.itemsize * nc, offset=off)
    return np.lib.stride_tricks.as_strided(raw, (ac['count'], dt.itemsize * nc), (st, 1)).copy().view(dt).reshape(ac['count'], nc)
skin_nodes = [i for i, nd in enumerate(j['nodes']) if 'mesh' in nd and 'skin' in nd]
assert len(skin_nodes) == 1, 'merge_skinned.py first: want exactly one skinned mesh node'
mesh = j['meshes'][j['nodes'][skin_nodes[0]]['mesh']]
joint_names = [j['nodes'][ji].get('name') for ji in j['skins'][0]['joints']]
# Build the Blender mesh straight from the glb arrays (no importer: it re-poses skinned FBX rigs).
# Seam-split vertices are welded by position so the decimator sees one surface; UVs stay per corner.
P = []; UV = []; JJ = []; WW = []; F = []; FM = []
for pr in mesh['primitives']:
    at = pr['attributes']; base = sum(len(x) for x in P)
    P.append(read(at['POSITION']).astype(np.float64)); UV.append(read(at['TEXCOORD_0']).astype(np.float64))
    JJ.append(read(at['JOINTS_0']).astype(np.int64)); WW.append(read(at['WEIGHTS_0']).astype(np.float64))
    ix = read(pr['indices']).reshape(-1, 3).astype(np.int64) + base; F.append(ix); FM.append(np.full(len(ix), pr.get('material', 0)))
P = np.concatenate(P); UV = np.concatenate(UV); JJ = np.concatenate(JJ); WW = np.concatenate(WW); F = np.concatenate(F); FM = np.concatenate(FM)
key = np.round(P / 1e-4).astype(np.int64); _, first, wmap = np.unique(key, axis=0, return_index=True, return_inverse=True)
wmap = wmap.reshape(-1)
bpy.ops.wm.read_factory_settings(use_empty=True)
me = bpy.data.meshes.new('m'); ob = bpy.data.objects.new('m', me); bpy.context.scene.collection.objects.link(ob)
me.from_pydata(P[first].tolist(), [], wmap[F].tolist())
mat_ids = sorted(set(FM.tolist())); 
for _ in mat_ids: me.materials.append(bpy.data.materials.new('x'))
me.polygons.foreach_set('material_index', [mat_ids.index(m) for m in FM])
uvl = me.uv_layers.new(name='uv'); uvl.data.foreach_set('uv', np.c_[UV[F.reshape(-1)][:, 0], 1.0 - UV[F.reshape(-1)][:, 1]].reshape(-1))
# weights: weight each welded vertex by its first source vertex
for nm in range(len(joint_names)): ob.vertex_groups.new(name=str(nm))
for vi, src_v in enumerate(first):
    for jn, w in zip(JJ[src_v], WW[src_v]):
        if w > 1e-6: ob.vertex_groups[int(jn)].add([vi], float(w), 'ADD')
mat_of_slot = dict(enumerate(mat_ids))
tri = lambda o: sum(len(p.vertices) - 2 for p in o.data.polygons)
tot = tri(ob); print('SOURCE TRIS', tot)
d = ob.modifiers.new('dec', 'DECIMATE'); d.ratio = min(1.0, cap / tot * 0.97); d.use_collapse_triangulate = True
bpy.context.view_layer.objects.active = ob; bpy.ops.object.modifier_apply(modifier=d.name)
me = ob.data; me.calc_loop_triangles()
print('DECIMATE', tot, '->', len(me.loop_triangles))
uv = me.uv_layers[0].data; cn = me.corner_normals
vg = {g.index: int(g.name) for g in ob.vertex_groups}
prims = {}
for lt in me.loop_triangles:
    mi = mat_of_slot[me.polygons[lt.polygon_index].material_index]
    for lp in lt.loops:
        v = me.vertices[me.loops[lp].vertex_index]
        ws = sorted(((g.weight, vg[g.group]) for g in v.groups if g.weight > 1e-6), reverse=True)[:4]
        s = sum(w for w, _ in ws); ws += [(0.0, 0)] * (4 - len(ws))
        nrm = np.array(cn[lp].vector, np.float64)
        pos = v.co[:]
        u = uv[lp].uv
        prims.setdefault(mi, []).append([*pos, *nrm, u[0], 1.0 - u[1], *[x[1] for x in ws], *[x[0] / s for x in ws]])
blob = bytearray(); bvs = []; accs = []
def put(arr, ct, typ, target):
    arr = np.ascontiguousarray(arr.astype(CT[ct]))
    while len(blob) % 4: blob.append(0)
    bvs.append({'buffer': 0, 'byteOffset': len(blob), 'byteLength': arr.nbytes}); blob.extend(arr.tobytes())
    if target: bvs[-1]['target'] = target
    ac = {'bufferView': len(bvs) - 1, 'componentType': ct, 'count': len(arr), 'type': typ}
    if typ == 'VEC3' and ct == 5126: ac['min'] = arr.min(0).astype(float).tolist(); ac['max'] = arr.max(0).astype(float).tolist()
    if typ == 'SCALAR' and ct == 5126: ac['min'] = [float(arr.min())]; ac['max'] = [float(arr.max())]
    accs.append(ac); return len(accs) - 1
new_prims = []
for mi, rows in sorted(prims.items()):
    R = np.array(rows, np.float32).reshape(-1, 3, 16).reshape(-1, 16)
    uniq, inv = np.unique(R, axis=0, return_inverse=True)
    new_prims.append({'attributes': {'POSITION': put(uniq[:, 0:3], 5126, 'VEC3', 34962), 'NORMAL': put(uniq[:, 3:6], 5126, 'VEC3', 34962),
        'TEXCOORD_0': put(uniq[:, 6:8], 5126, 'VEC2', 34962), 'JOINTS_0': put(uniq[:, 8:12], 5123, 'VEC4', 34962),
        'WEIGHTS_0': put(uniq[:, 12:16], 5126, 'VEC4', 34962)}, 'indices': put(inv.reshape(-1), 5125, 'SCALAR', 34963), 'material': mi, 'mode': 4})
mesh['primitives'] = new_prims
# The source stacks every clip on one timeline (WALK starts at 16.7 s, ROAR at 64 s). Godot would play
# that lead-in as a frozen pose, so move each clip to start at 0.
for an in j['animations']:
    t0 = min(float(read(sm['input']).min()) for sm in an['samplers'])
    for sm in an['samplers']: sm['input'] = put(read(sm['input']).reshape(-1).astype(np.float32) - np.float32(t0), 5126, 'SCALAR', None) | (1 << 30)
# stray unskinned helper box left over from the source rig
for nd in j['nodes']:
    if 'mesh' in nd and 'skin' not in nd and j['meshes'][nd['mesh']]['name'].startswith('Box001'): del nd['mesh']
# compact: keep only accessors still referenced, repack buffer views
old_accs = j['accessors']; j['accessors'] = accs; base = len(accs)
keep = {}
def ref(i):
    if i not in keep: keep[i] = len(j['accessors']); j['accessors'].append(dict(old_accs[i]))
    return keep[i]
for m in j['meshes']:
    for p in m['primitives']:
        if 'indices' in p and p['indices'] < 0: continue
        if p not in new_prims:
            p['attributes'] = {k: ref(v) for k, v in p['attributes'].items()}
            if 'indices' in p: p['indices'] = ref(p['indices'])
j['skins'][0]['inverseBindMatrices'] = ref(j['skins'][0]['inverseBindMatrices'])
for an in j['animations']:
    for s in an['samplers']: s['input'] &= ~(1 << 30); s['output'] = ref(s['output'])
used = {}
for ac in j['accessors'][base:]:
    i = ac['bufferView']
    if i not in used:
        bv = j['bufferViews'][i]; o = bv.get('byteOffset', 0)
        while len(blob) % 4: blob.append(0)
        nb = dict(bv); nb['byteOffset'] = len(blob); blob.extend(bin_[o:o + bv['byteLength']]); used[i] = len(bvs); bvs.append(nb)
    ac['bufferView'] = used[i]
for im in j['images']:
    bv = j['bufferViews'][im['bufferView']]; o = bv.get('byteOffset', 0)
    while len(blob) % 4: blob.append(0)
    bvs.append({'buffer': 0, 'byteOffset': len(blob), 'byteLength': bv['byteLength']}); blob.extend(bin_[o:o + bv['byteLength']]); im['bufferView'] = len(bvs) - 1
j['bufferViews'] = bvs; j['buffers'] = [{'byteLength': len(blob)}]
while len(blob) % 4: blob.append(0)
js = json.dumps(j, separators=(',', ':')).encode()
while len(js) % 4: js += b' '
open(dst, 'wb').write(struct.pack('<III', 0x46546C67, 2, 28 + len(js) + len(blob)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(blob), 0x004E4942) + bytes(blob))
print('WROTE', dst, len(blob))
