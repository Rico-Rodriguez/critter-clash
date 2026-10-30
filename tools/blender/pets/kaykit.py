# Shared helpers for the humanoid pets: a KayKit character (the heroes' own
# Rig_Medium kit, CC0) with its clips picked from the KayKit animation files,
# the heroes' adult build (src/hunt/actor.gd HERO_BUILD: small head, longer
# body and legs, so no chibi pets) keyed into every clip, and
# gear modelled here in Blender, skinned rigidly to one bone each. Exported as
# a self-contained <model>_src.glb so the pet pipeline (wrap, breeding
# regions, skins) treats it like the other Blender pets.
import bpy, os
from mathutils import Vector

KK = "assets/kaykit/"


def load(root, character):
    """Imports the character; returns (rig, [meshes])."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(root, KK, "characters", character + ".glb"))
    rig = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    for o in list(bpy.data.objects):
        if o != rig and o.parent != rig:
            bpy.data.objects.remove(o)
    # Double-sided, as the pet skin shader needs (KayKit ships them single-sided).
    for m in bpy.data.materials:
        m.use_backface_culling = False
    return rig, [o for o in rig.children if o.type == "MESH"]


# src/hunt/actor.gd HERO_BUILD, as pose scales: bone scales multiply down the
# chain, so the head and arms are divided by the trunk.
def _hero_build():
    spine, chest = (1.0, 1.08, 1.0), (1.1, 1.04, 1.1)
    trunk = [a * b for a, b in zip(spine, chest)]
    head = [0.64 / t for t in trunk]
    arm = [a / t for a, t in zip((1.04, 1.06, 1.04), trunk)]
    return {"spine": spine, "chest": chest, "head": tuple(head), "upperarm.l": tuple(arm), "upperarm.r": tuple(arm),
            "upperleg.l": (1.0, 1.28, 1.0), "upperleg.r": (1.0, 1.28, 1.0)}

HERO_BUILD = _hero_build()


def clips(root, rig, wanted, build=HERO_BUILD, lift=None):
    """wanted: {pet clip name: KayKit clip name}. Pulls those clips out of the
    animation files, renames them, keys `build` ({bone: scale}) into each and
    drops every other action. `lift` raises the root so longer legs still
    stand on the ground (defaults to what the build's legs add)."""
    if lift is None:
        leg = (build or {}).get("upperleg.l", (1, 1, 1))[1]
        lift = rig.data.bones["upperleg.l"].head_local.z * (leg - 1.0)
    files = ["General", "MovementBasic", "CombatMelee", "CombatRanged", "Special"]
    for f in files:
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(root, KK, "animations", "Rig_Medium_%s.glb" % f))
        for o in set(bpy.data.objects) - before:
            bpy.data.objects.remove(o)
    keep = []
    for name, src in wanted.items():
        a = bpy.data.actions[src].copy()
        a.name = name
        a.use_fake_user = True
        keep.append(a)
    for a in list(bpy.data.actions):
        if a not in keep:
            bpy.data.actions.remove(a)
    rig.animation_data_create()
    for a in keep:
        rig.animation_data.action = a
        if hasattr(rig.animation_data, "action_slot") and a.slots:
            rig.animation_data.action_slot = a.slots[0]
        f0, f1 = int(a.frame_range[0]), int(a.frame_range[1])
        from common import _fcurves
        for bn, sc in (build or {}).items():
            # Scale the clip's own scale keys where it has them, else key it.
            fcs = {fc.array_index: fc for fc in _fcurves(a) if fc.data_path == 'pose.bones["%s"].scale' % bn}
            if fcs:
                for i, fc in fcs.items():
                    for kp in fc.keyframe_points:
                        kp.co.y *= sc[i]
                        kp.handle_left.y *= sc[i]
                        kp.handle_right.y *= sc[i]
                continue
            pb = rig.pose.bones[bn]
            pb.scale = sc
            for f in (f0, f1):
                pb.keyframe_insert("scale", frame=f)
            pb.scale = (1, 1, 1)
        if lift:
            # The root's own Y axis points up.
            fcs = [fc for fc in _fcurves(a) if fc.data_path == 'pose.bones["root"].location' and fc.array_index == 1]
            if fcs:
                for kp in fcs[0].keyframe_points:
                    kp.co.y += lift
                    kp.handle_left.y += lift
                    kp.handle_right.y += lift
            else:
                pb = rig.pose.bones["root"]
                pb.location = (0, lift, 0)
                for f in (f0, f1):
                    pb.keyframe_insert("location", frame=f)
                pb.location = (0, 0, 0)
    rig.animation_data.action = None
    return keep


def bone_at(rig, bone):
    """A bone's head in world space."""
    return rig.matrix_world @ rig.data.bones[bone].head_local


def wear(rig, obj, bone):
    """Skins `obj` rigidly to `bone`."""
    from common import _apply
    _apply(obj)
    vg = obj.vertex_groups.new(name=bone)
    vg.add([v.index for v in obj.data.vertices], 1.0, "REPLACE")
    obj.parent = rig
    md = obj.modifiers.new("Armature", "ARMATURE")
    md.object = rig
    return obj


def export(rig, path):
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for o in rig.children:
        o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
        export_animation_mode="ACTIONS", export_force_sampling=True, export_image_format="AUTO",
        export_apply=False, export_yup=True)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in rig.children if o.type == "MESH")
    print("PET", path, "tris", tris, "bones", len(rig.data.bones), "clips", [a.name for a in bpy.data.actions])


def recolour(meshes, cells):
    """Gives the character its own copy of its palette texture with some
    swatches repainted. KayKit textures are an 8 x 4 grid of gradient
    swatches; `cells` maps (column, row from the top) to a hex colour, and each
    swatch keeps its own light-to-dark gradient around the new colour (pixels
    and hex both sRGB)."""
    mats = {s.material for o in meshes for s in o.material_slots if s.material}
    for m in mats:
        tex = [n for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image]
        if not tex:
            continue
        src = tex[0].image
        w, h = src.size
        px = list(src.pixels)
        cw, ch = w // 8, h // 4
        for (cx, cy), hexc in cells.items():
            t = [int(hexc[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
            y0 = h - (cy + 1) * ch
            idx = [((y * w) + x) * 4 for y in range(y0, y0 + ch) for x in range(cx * cw, cx * cw + cw)]
            lum = [0.2126 * px[i] + 0.7152 * px[i + 1] + 0.0722 * px[i + 2] for i in idx]
            mean = max(sum(lum) / len(lum), 1e-4)
            for i, l in zip(idx, lum):
                k = l / mean
                for c in range(3):
                    px[i + c] = min(1.0, t[c] * k)
        img = bpy.data.images.new(src.name + "_recolour", w, h, alpha=True)
        img.pixels = px
        img.pack()
        tex[0].image = img
