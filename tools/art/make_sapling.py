"""Thorn Sapling: a little treant on KayKit's Rig_Medium skeleton, so the
game's shared animation library (idle, walk, attacks) drives it unchanged.
Each part is rigid on one bone. Run: tools/art/blender.sh tools/art/make_sapling.py
Writes assets/kaykit/characters/Sapling.glb (palette texture embedded)."""
import bpy, bmesh, math, os
from mathutils import Vector, Matrix

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CH = os.path.join(ROOT, "assets/kaykit/characters/")
TEX = "/tmp/Sapling_texture.png"  # embedded in the glb; Godot extracts it

# A small palette in the KayKit way: flat cells with a soft vertical ramp.
CELLS = {
    "bark": ((0.42, 0.27, 0.16), (0.27, 0.16, 0.09)),
    "bark_lt": ((0.62, 0.44, 0.27), (0.45, 0.30, 0.17)),
    "leaf": ((0.45, 0.78, 0.30), (0.22, 0.52, 0.18)),
    "leaf_dk": ((0.25, 0.55, 0.22), (0.12, 0.34, 0.12)),
    "moss": ((0.60, 0.72, 0.30), (0.40, 0.55, 0.20)),
    "eye": ((0.08, 0.06, 0.05), (0.05, 0.04, 0.03)),
    "glint": ((0.96, 0.98, 0.90), (0.85, 0.90, 0.80)),
    "bloom": ((0.98, 0.62, 0.72), (0.85, 0.40, 0.55)),
}
ORDER = list(CELLS)
N = 4  # 4x4 grid of 32px cells on a 128px sheet


def make_texture():
    size, cell = 128, 32
    img = bpy.data.images.new("Sapling_texture", size, size, alpha=False)
    px = [0.0] * (size * size * 4)
    for i, k in enumerate(ORDER):
        top, bot = CELLS[k]
        cx, cy = (i % N) * cell, (i // N) * cell
        for y in range(cell):
            t = y / (cell - 1)
            c = [bot[j] + (top[j] - bot[j]) * t for j in range(3)]
            for x in range(cell):
                o = ((cy + y) * size + cx + x) * 4
                px[o:o + 4] = [c[0], c[1], c[2], 1.0]
    img.pixels = px
    img.filepath_raw = TEX
    img.file_format = 'PNG'
    img.save()
    return img


def uv_of(k, v):
    i = ORDER.index(k)
    u0, v0 = (i % N) / N, (i // N) / N
    return (u0 + 0.5 / N, v0 + (0.15 + 0.7 * v) / N)


class Builder:
    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new()
        self.dl = self.bm.verts.layers.deform.new()
        self.groups = []

    def _gi(self, bone):
        if bone not in self.groups:
            self.groups.append(bone)
        return self.groups.index(bone)

    def add(self, mesh_fn, cell, bone, z0, z1):
        """mesh_fn builds into a temp bmesh; its verts go on `bone`, colored by
        height between z0 (dark) and z1 (light)."""
        t = bmesh.new()
        mesh_fn(t)
        m = bpy.data.meshes.new("t"); t.to_mesh(m); t.free()
        gi = self._gi(bone)
        base = len(self.bm.verts)
        vmap = []
        for v in m.vertices:
            nv = self.bm.verts.new(v.co)
            nv[self.dl][gi] = 1.0
            vmap.append(nv)
        self.bm.verts.ensure_lookup_table()
        for p in m.polygons:
            try:
                f = self.bm.faces.new([vmap[i] for i in p.vertices])
            except ValueError:
                continue
            for l in f.loops:
                h = 0.5 if z1 == z0 else (l.vert.co.z - z0) / (z1 - z0)
                l[self.uv].uv = uv_of(cell, max(0.0, min(1.0, h)))
        bpy.data.meshes.remove(m)


def cyl(a, b, r0, r1, seg=7):
    a, b = Vector(a), Vector(b)
    def fn(t):
        res = bmesh.ops.create_cone(t, cap_ends=True, segments=seg, radius1=r0, radius2=r1, depth=(b - a).length)
        d = (b - a).normalized()
        rot = Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4()
        bmesh.ops.transform(t, matrix=Matrix.Translation((a + b) / 2) @ rot, verts=t.verts)
    return fn


def blob(c, r, sub=1, squash=(1, 1, 1)):
    def fn(t):
        bmesh.ops.create_icosphere(t, subdivisions=sub, radius=r)
        bmesh.ops.transform(t, matrix=Matrix.Translation(c) @ Matrix.Diagonal((*squash, 1)), verts=t.verts)
    return fn


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=CH + "Skeleton_Minion.glb", bone_heuristic='BLENDER')
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    for o in list(bpy.data.objects):
        if o.type == 'MESH':
            bpy.data.objects.remove(o)
    B = {b.name: arm.matrix_world @ b.head_local for b in arm.data.bones}
    T = {b.name: arm.matrix_world @ b.tail_local for b in arm.data.bones}
    g = Builder()
    # Trunk: a stout, slightly tapered stump from the hips to the chest.
    g.add(cyl((0, 0, 0.40), (0, 0, 0.98), 0.27, 0.24, 10), "bark", "hips", 0.40, 0.98)
    g.add(cyl((0, 0, 0.98), (0, 0, 1.24), 0.24, 0.26, 10), "bark", "chest", 0.98, 1.24)
    g.add(blob((0.12, -0.2, 0.75), 0.07, 1), "moss", "spine", 0.7, 0.8)
    # Head: the top of the stump with a face, under a big leafy crown.
    g.add(cyl((0, 0, 1.22), (0, 0, 1.52), 0.27, 0.24, 10), "bark_lt", "head", 1.22, 1.52)
    for x in (-0.1, 0.1):
        g.add(blob((x, -0.235, 1.39), 0.055, 1), "eye", "head", 1.3, 1.45)
        g.add(blob((x + 0.018, -0.275, 1.41), 0.018, 0), "glint", "head", 1.3, 1.45)
    for c, r in [((0, 0.02, 1.68), 0.30), ((-0.2, 0.05, 1.58), 0.2), ((0.21, 0.0, 1.6), 0.21),
                 ((0.05, 0.16, 1.62), 0.22), ((-0.06, -0.12, 1.62), 0.18), ((0.0, 0.0, 1.88), 0.16)]:
        g.add(blob(c, r, 2, (1, 1, 0.82)), "leaf" if r > 0.19 else "leaf_dk", "head", 1.45, 1.95)
    g.add(blob((0.17, -0.18, 1.74), 0.06, 1), "bloom", "head", 1.7, 1.8)
    g.add(cyl((0.0, 0.0, 1.9), (0.05, -0.02, 2.04), 0.025, 0.012, 5), "bark", "head", 1.9, 2.04)
    # Arms: twisty branches ending in a leafy tuft (the hand).
    for s in ("l", "r"):
        g.add(cyl(B["upperarm." + s], B["lowerarm." + s], 0.075, 0.06, 6), "bark", "upperarm." + s, 1.0, 1.2)
        g.add(cyl(B["lowerarm." + s], B["hand." + s], 0.06, 0.045, 6), "bark", "lowerarm." + s, 1.0, 1.2)
        g.add(blob(T["hand." + s], 0.1, 2), "leaf", "hand." + s, 1.0, 1.2)
        side = 1 if s == "l" else -1
        g.add(cyl(B["lowerarm." + s], B["lowerarm." + s] + Vector((0.02 * side, -0.05, 0.14)), 0.03, 0.01, 5), "bark_lt", "lowerarm." + s, 1.0, 1.3)
    # Legs: two root stumps with splayed toes.
    for s in ("l", "r"):
        g.add(cyl(B["upperleg." + s], B["lowerleg." + s], 0.11, 0.1, 7), "bark", "upperleg." + s, 0.25, 0.55)
        g.add(cyl(B["lowerleg." + s], B["foot." + s] + Vector((0, 0, 0.02)), 0.1, 0.13, 7), "bark", "lowerleg." + s, 0.0, 0.3)
        f = B["foot." + s]
        for d in (-0.5, 0.0, 0.5):
            tip = f + Vector((math.sin(d) * 0.16, -math.cos(d) * 0.16, -0.12))
            g.add(cyl(f + Vector((0, 0, -0.06)), tip, 0.05, 0.015, 5), "bark_lt", "foot." + s, 0.0, 0.15)
    me = bpy.data.meshes.new("Sapling_Body")
    g.bm.to_mesh(me); g.bm.free()
    for p in me.polygons:
        p.use_smooth = False
    ob = bpy.data.objects.new("Sapling_Body", me)
    bpy.context.scene.collection.objects.link(ob)
    for bn in g.groups:
        ob.vertex_groups.new(name=bn)
    ob.parent = arm
    mod = ob.modifiers.new("Armature", 'ARMATURE'); mod.object = arm
    # One material on the palette texture, as KayKit does.
    img = make_texture()
    mat = bpy.data.materials.new("sapling"); mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    tx = mat.node_tree.nodes.new("ShaderNodeTexImage"); tx.image = img; tx.interpolation = 'Closest'
    mat.node_tree.links.new(tx.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.8
    me.materials.append(mat)
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True); ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=CH + "Sapling.glb", export_format='GLB', use_selection=True,
                              export_animations=False, export_skins=True, export_yup=True)
    print("WROTE", CH + "Sapling.glb")


build()
