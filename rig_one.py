#!/usr/bin/env python3
"""Auto-rig one FBX model with a simple humanoid armature and export GLB.

Usage: blender --background --python rig_one.py -- <in.fbx> <out.glb>

- Imports the FBX, bakes object transforms, measures the world-space bbox.
- Builds a humanoid armature (hips/spine/chest/neck/head, arms, legs)
  sized proportionally to the bbox, centered on the mesh.
- Parents meshes to the armature with automatic (bone-heat) weights,
  falling back to envelope weights when heat weighting fails or leaves
  unweighted vertices.
- Exports a GLB with skinning.
"""
import sys
import os

import bpy
from mathutils import Vector


def log(msg):
    print("[rig_one] " + msg, flush=True)


def clean_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_fbx(path):
    bpy.ops.import_scene.fbx(filepath=path)


def get_meshes():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def apply_transforms(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    if objs:
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def world_bbox(meshes):
    mn = Vector((1e18, 1e18, 1e18))
    mx = Vector((-1e18, -1e18, -1e18))
    for o in meshes:
        for corner in o.bound_box:
            w = o.matrix_world @ Vector(corner)
            mn = Vector((min(mn.x, w.x), min(mn.y, w.y), min(mn.z, w.z)))
            mx = Vector((max(mx.x, w.x), max(mx.y, w.y), max(mx.z, w.z)))
    return mn, mx


# Bone layout: (name, head, tail, parent_name). Coordinates are filled by
# build_armature using proportions of the bbox height H, centered at (cx, cy).
def build_armature(cx, cy, z0, H):
    def P(x, y, zf):
        return Vector((cx + x * H, cy + y * H, z0 + zf * H))

    # (name, head, tail, parent)
    bones = [
        ("hips",        P(0, 0, 0.50), P(0, 0, 0.58), None),
        ("spine",       P(0, 0, 0.58), P(0, 0, 0.68), "hips"),
        ("chest",       P(0, 0, 0.68), P(0, 0, 0.78), "spine"),
        ("neck",        P(0, 0, 0.78), P(0, 0, 0.84), "chest"),
        ("head",        P(0, 0, 0.84), P(0, 0, 1.00), "neck"),
    ]
    for side, s in (("L", 1.0), ("R", -1.0)):
        bones += [
            ("upper_arm." + side, P(s * 0.10, 0, 0.76), P(s * 0.24, 0, 0.62), "chest"),
            ("forearm." + side,   P(s * 0.24, 0, 0.62), P(s * 0.34, 0, 0.48), "upper_arm." + side),
            ("hand." + side,      P(s * 0.34, 0, 0.48), P(s * 0.38, 0, 0.42), "forearm." + side),
            ("thigh." + side,     P(s * 0.055, 0, 0.50), P(s * 0.06, 0, 0.27), "hips"),
            ("shin." + side,      P(s * 0.06, 0, 0.27), P(s * 0.065, 0, 0.06), "thigh." + side),
            ("foot." + side,      P(s * 0.065, 0, 0.06), P(s * 0.065, -0.09, 0.02), "shin." + side),
        ]

    arm_data = bpy.data.armatures.new("Armature")
    arm_obj = bpy.data.objects.new("Armature", arm_data)
    bpy.context.scene.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")
    created = {}
    for name, head, tail, _parent in bones:
        b = arm_data.edit_bones.new(name)
        b.head = head
        b.tail = tail
        b.use_connect = False
        created[name] = b
    for name, _h, _t, parent in bones:
        if parent:
            created[name].parent = created[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm_obj


def count_unweighted(mesh, arm_obj):
    """Return number of vertices with no (or ~zero) total weight."""
    bad = 0
    for v in mesh.data.vertices:
        total = sum(g.weight for g in v.groups)
        if total < 1e-6:
            bad += 1
    return bad


def dist_point_to_segment(p, a, b):
    ab = b - a
    t = (p - a).dot(ab) / max(ab.dot(ab), 1e-12)
    t = max(0.0, min(1.0, t))
    return (p - (a + ab * t)).length


def nearest_deform_bone(mesh, arm_obj, co_world):
    """Name of the deform bone closest to the given world-space point."""
    arm_mw = arm_obj.matrix_world
    best, best_d = None, 1e18
    for pb in arm_obj.pose.bones:
        if not pb.bone.use_deform:
            continue
        h = arm_mw @ pb.head
        t = arm_mw @ pb.tail
        d = dist_point_to_segment(co_world, h, t)
        if d < best_d:
            best, best_d = pb.name, d
    return best


def fix_unweighted_verts(mesh, arm_obj):
    """Assign any verts left weightless by AUTO to their nearest deform bone."""
    mw = mesh.matrix_world
    fixed = 0
    for v in mesh.data.vertices:
        if sum(g.weight for g in v.groups) >= 1e-6:
            continue
        name = nearest_deform_bone(mesh, arm_obj, mw @ v.co)
        if not name:
            continue
        grp = mesh.vertex_groups.get(name)
        if grp is None:
            grp = mesh.vertex_groups.new(name=name)
        grp.add([v.index], 1.0, "REPLACE")
        fixed += 1
    return fixed


def parent_mesh(mesh, arm_obj, mode):
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    arm_obj.select_set(True)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.parent_set(type=mode)


def parent_mesh_auto(mesh, arm_obj):
    """AUTO weights, then assign any leftover unweighted verts to nearest bone."""
    try:
        parent_mesh(mesh, arm_obj, "ARMATURE_AUTO")
    except Exception as e:
        log("%s: AUTO parent_set raised: %s" % (mesh.name, e))
    bad = count_unweighted(mesh, arm_obj)
    if bad:
        fixed = fix_unweighted_verts(mesh, arm_obj)
        bad = count_unweighted(mesh, arm_obj)
        log("%s: AUTO + nearest-bone fix: %d/%d unweighted verts (fixed %d)" % (
            mesh.name, bad, len(mesh.data.vertices), fixed))
    else:
        log("%s: AUTO weights, 0/%d unweighted verts" % (
            mesh.name, len(mesh.data.vertices)))
    if bad:
        raise RuntimeError("%s still has %d unweighted verts" % (mesh.name, bad))


def rig(in_path, out_path):
    clean_scene()
    import_fbx(in_path)
    meshes = get_meshes()
    if not meshes:
        raise RuntimeError("no mesh objects after FBX import")
    log("meshes: %s" % [m.name for m in meshes])

    apply_transforms(meshes)
    mn, mx = world_bbox(meshes)
    H = mx.z - mn.z
    if H <= 0:
        raise RuntimeError("degenerate bbox height")
    cx = (mn.x + mx.x) / 2.0
    cy = (mn.y + mx.y) / 2.0
    log("bbox min=%s max=%s H=%.3f center=(%.3f, %.3f)" % (tuple(mn), tuple(mx), H, cx, cy))

    arm_obj = build_armature(cx, cy, mn.z, H)

    for mesh in meshes:
        parent_mesh_auto(mesh, arm_obj)

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format="GLB",
        export_skins=True,
        export_apply=False,
    )
    log("exported %s" % out_path)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    if len(argv) != 2:
        raise SystemExit("usage: rig_one.py -- <in.fbx> <out.glb>")
    rig(argv[0], argv[1])


if __name__ == "__main__":
    main()
