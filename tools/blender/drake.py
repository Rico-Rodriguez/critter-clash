# Low-poly KayKit-style drake, built from primitives. Exports a .glb.
import bpy, bmesh, math, sys
from mathutils import Vector, Euler

out = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene

def mat(name, rgb, rough=0.8):
    m = bpy.data.materials.get(name)
    if m: return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    return m

def srgb(h):
    c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)

SCALE = mat("scale", srgb("c4492f"))
BELLY = mat("belly", srgb("f0c27a"))
HORN = mat("horn", srgb("efe3c8"))
WING = mat("wing", srgb("8f2a24"))
EYE = mat("eye", srgb("1b1a1f"), 0.3)
GLINT = mat("glint", srgb("ffffff"), 0.2)

parts = []
def add(o, m, smooth=True, sub=1):
    o.data.materials.append(m)
    if sub:
        mod = o.modifiers.new("s", "SUBSURF"); mod.levels = sub; mod.render_levels = sub
    if smooth:
        for p in o.data.polygons: p.use_smooth = True
    parts.append(o)
    return o

def cube(loc, size, rot=(0, 0, 0), m=SCALE, sub=1, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.object; o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        b = o.modifiers.new("b", "BEVEL"); b.width = bevel; b.segments = 2
    return add(o, m, sub=sub)

def sphere(loc, size, m=SCALE, seg=10, ring=7, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=ring, location=loc, rotation=rot)
    o = bpy.context.object; o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return add(o, m, sub=0)

def cone(loc, r1, r2, depth, rot, m, verts=6):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    return add(bpy.context.object, m, sub=0)

# Body: a squat egg, belly plate on the front.
cube((0, 0, 0.62), (0.42, 0.5, 0.42), m=SCALE, sub=2)
cube((0, -0.36, 0.58), (0.3, 0.16, 0.32), m=BELLY, sub=2)
# Head: big and blocky with a snout, like KayKit's chunky heads.
cube((0, -0.18, 1.32), (0.44, 0.4, 0.36), m=SCALE, sub=2)
cube((0, -0.6, 1.2), (0.28, 0.22, 0.2), m=SCALE, sub=2)
cube((0, -0.62, 1.07), (0.24, 0.18, 0.08), m=BELLY, sub=2)
for s in (-1, 1):
    # Nostrils, eyes with a glint, horns sweeping back.
    sphere((s * 0.1, -0.8, 1.27), (0.035, 0.03, 0.03), m=EYE, seg=6, ring=4)
    sphere((s * 0.24, -0.5, 1.42), (0.09, 0.07, 0.11), m=EYE)
    sphere((s * 0.26, -0.56, 1.47), (0.03, 0.02, 0.03), m=GLINT, seg=6, ring=4)
    cone((s * 0.24, 0.08, 1.68), 0.1, 0.0, 0.42, (math.radians(-35), math.radians(s * 18), 0), HORN)
    # Stubby legs and claws.
    cube((s * 0.27, -0.12, 0.18), (0.13, 0.15, 0.2), m=SCALE, sub=2)
    for k in (-1, 0, 1):
        cone((s * 0.27 + k * 0.07, -0.29, 0.04), 0.03, 0.0, 0.1, (math.radians(-90), 0, 0), HORN, verts=4)
    cube((s * 0.3, -0.38, 0.6), (0.08, 0.09, 0.14), rot=(math.radians(25), 0, 0), m=SCALE, sub=2)
    # Wings: an arm bar plus a membrane fan.
    bpy.ops.mesh.primitive_plane_add(size=1)
    w = bpy.context.object
    bm = bmesh.new()
    pts = [(0, 0, 0), (0.35, 0.0, 0.45), (0.75, 0.05, 0.62), (0.7, 0.2, 0.2), (0.5, 0.28, 0.02), (0.25, 0.25, -0.08)]
    vs = [bm.verts.new(Vector(p)) for p in pts]
    bm.faces.new(vs)
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.04)
    bm.to_mesh(w.data); bm.free()
    w.location = (s * 0.28, 0.2, 0.88)
    w.scale = (s, 1, 1)
    w.rotation_euler = (0, 0, math.radians(s * -30))
    add(w, WING, sub=0, smooth=False)
    # Wing bones: a leading edge and two ribs, horn-coloured like KayKit trims.
    for (a, b) in [((0, 0, 0), (0.35, 0.0, 0.45)), ((0.35, 0.0, 0.45), (0.75, 0.05, 0.62)), ((0.35, 0.0, 0.45), (0.5, 0.28, 0.02)), ((0.35, 0.0, 0.45), (0.7, 0.2, 0.2))]:
        va, vb = Vector(a), Vector(b)
        d = vb - va
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.03, depth=d.length)
        c = bpy.context.object
        c.rotation_mode = "QUATERNION"
        c.rotation_quaternion = d.to_track_quat("Z", "Y")
        c.location = (va + vb) / 2
        c.parent = w
        add(c, SCALE, sub=0)
# Tail: tapering segments curling up, with a spade tip.
seg = [((0, 0.45, 0.4), 0.18), ((0, 0.72, 0.32), 0.13), ((0, 0.95, 0.36), 0.09), ((0, 1.12, 0.48), 0.06)]
for (p, r) in seg:
    sphere(p, (r, r * 1.3, r), m=SCALE, seg=8, ring=6)
cone((0, 1.22, 0.58), 0.13, 0.0, 0.22, (math.radians(-60), 0, 0), WING, verts=4)
# Back spikes.
for i, (y, z) in enumerate([(-0.2, 1.68), (0.1, 1.05), (0.3, 0.88), (0.5, 0.58)]):
    cone((0, y, z), 0.07 - i * 0.008, 0.0, 0.16, (math.radians(-20), 0, 0), HORN, verts=4)

bpy.ops.object.select_all(action="DESELECT")
for o in parts: o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
for o in parts:
    bpy.context.view_layer.objects.active = o
    for m in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
d = bpy.context.object; d.name = "Drake"
# Godot is Y-up, -Z forward; glTF export converts. Face -Y in Blender = +Z forward in glTF.
print("tris", sum(len(p.vertices) - 2 for p in d.data.polygons))
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True)
