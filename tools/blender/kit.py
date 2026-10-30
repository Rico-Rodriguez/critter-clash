import bpy, bmesh, math
from mathutils import Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
parts = []
def srgb(h):
    c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)
def mat(name, rgb, rough=0.8):
    m = bpy.data.materials.get(name)
    if m: return m
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1); b.inputs["Roughness"].default_value = rough
    return m
def add(o, m, smooth=True, sub=1):
    o.data.materials.append(m)
    if sub:
        mod = o.modifiers.new("s", "SUBSURF"); mod.levels = sub; mod.render_levels = sub
    if smooth:
        for p in o.data.polygons: p.use_smooth = True
    parts.append(o); return o
def cube(loc, size, rot=(0, 0, 0), m=None, sub=1, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.object; o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        b = o.modifiers.new("b", "BEVEL"); b.width = bevel; b.segments = 2
    return add(o, m, sub=sub, smooth=sub > 0)
def sphere(loc, size, m=None, seg=10, ring=7, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=ring, location=loc, rotation=rot)
    o = bpy.context.object; o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return add(o, m, sub=0)
def cone(loc, r1, r2, depth, rot, m, verts=6):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    return add(bpy.context.object, m, sub=0, smooth=False)
def finish(out, name):
    for o in parts:
        bpy.context.view_layer.objects.active = o
        for m in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts: o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    d = bpy.context.object; d.name = name; d.parent = None
    print("tris", sum(len(p.vertices) - 2 for p in d.data.polygons))
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True)
