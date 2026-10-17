"""Recolor and export licensed CC0 creatures and nature props for Critter Clash.

Sources live outside the repo (downloaded packs). This script only writes game-ready GLBs.
"""

import math
import os

import bpy
import numpy as np
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "models")
UM = "/tmp/cc0/um/Ultimate Monsters"
NATURE = "/tmp/cc0/nature/glTF"
COZY = "/tmp/cc0/cozy/Gamideo_cozy_animals"
OTTER = os.path.join(COZY, "Otter.glb")
COZY_FOX = os.path.join(COZY, "Fox.glb")
DRAGON = "/tmp/cc0/candidates/dragon.glb"
OWL = "/tmp/cc0/candidates/owl.glb"
os.makedirs(OUT, exist_ok=True)


def srgb(h):
    h = h.lstrip("#")
    rgb = [int(h[i : i + 2], 16) / 255.0 for i in (0, 2, 4)]

    def lin(u):
        return u / 12.92 if u <= 0.04045 else ((u + 0.055) / 1.055) ** 2.4

    return tuple(lin(c) for c in rgb) + (1.0,)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def empty(name):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "PLAIN_AXES"
    obj.empty_display_size = 0.15
    return link(obj)


def import_gltf(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def delete_junk():
    for obj in list(bpy.data.objects):
        if obj.type == "MESH" and obj.name.startswith("Icosphere"):
            bpy.data.objects.remove(obj, do_unlink=True)


def drop_normal_maps(limit=512):
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        nt = mat.node_tree
        bsdf = nt.nodes.get("Principled BSDF")
        if bsdf is None:
            continue
        for link in list(nt.links):
            if link.to_node == bsdf and link.to_socket.name == "Normal":
                nt.links.remove(link)
        for node in nt.nodes:
            if node.type == "TEX_IMAGE" and node.image and max(node.image.size) > limit:
                node.image.scale(limit, limit)


def set_base(mat_name_part, color):
    hits = 0
    for mat in bpy.data.materials:
        if mat_name_part.lower() not in mat.name.lower():
            continue
        if not mat.use_nodes:
            continue
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf is None:
            continue
        # Leave textured materials alone when recoloring by name, unless there is no image.
        linked = False
        for link in mat.node_tree.links:
            if link.to_socket == bsdf.inputs["Base Color"]:
                linked = True
        if linked:
            continue
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = 0.72
        hits += 1
    return hits


def hsv_of(r, g, b):
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    df = np.maximum(mx - mn, 1e-8)
    h = np.zeros_like(mx)
    mask = mx == r
    h[mask] = np.mod((g[mask] - b[mask]) / df[mask], 6.0)
    mask = mx == g
    h[mask] = (b[mask] - r[mask]) / df[mask] + 2.0
    mask = mx == b
    h[mask] = (r[mask] - g[mask]) / df[mask] + 4.0
    h = np.mod(h, 6.0) / 6.0
    s = np.where(mx <= 1e-6, 0.0, (mx - mn) / np.maximum(mx, 1e-6))
    return h, s, mx


def rgb_of(h, s, v):
    h = np.mod(h, 1.0) * 6.0
    i = np.floor(h).astype(np.int32)
    f = h - i
    p = v * (1.0 - s)
    q = v * (1.0 - s * f)
    t = v * (1.0 - s * (1.0 - f))
    out = np.zeros((h.shape[0], 3), dtype=np.float32)
    for idx, (a, b, c) in enumerate(((v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q))):
        m = i == idx
        out[m, 0] = a[m]
        out[m, 1] = b[m]
        out[m, 2] = c[m]
    return out


def shift_images(hue_target, mix_amt, sat_mul=1.12):
    seen = set()
    for img in bpy.data.images:
        if img in seen or img.size[0] == 0:
            continue
        seen.add(img)
        if max(img.size) > 512:
            img.scale(512, 512)
        w, h = img.size
        buf = np.array(img.pixels[:], dtype=np.float32).reshape(-1, 4)
        r, g, b, a = buf[:, 0], buf[:, 1], buf[:, 2], buf[:, 3]
        hh, ss, vv = hsv_of(r, g, b)
        colored = (ss > 0.12) & (vv > 0.08) & (vv < 0.97)
        hh = np.where(colored, hh * (1.0 - mix_amt) + hue_target * mix_amt, hh)
        ss = np.clip(np.where(colored, ss * sat_mul, ss), 0.0, 1.0)
        vv = np.clip((vv - 0.5) * 1.08 + 0.5, 0.0, 1.0)
        rgb = rgb_of(hh, ss, vv)
        buf[:, 0] = rgb[:, 0]
        buf[:, 1] = rgb[:, 1]
        buf[:, 2] = rgb[:, 2]
        img.pixels.foreach_set(buf.reshape(-1))
        img.pack()


def world_bounds():
    mins = Vector((1e9, 1e9, 1e9))
    maxs = Vector((-1e9, -1e9, -1e9))
    bpy.context.view_layer.update()
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            w = obj.matrix_world @ Vector(corner)
            mins = Vector((min(mins.x, w.x), min(mins.y, w.y), min(mins.z, w.z)))
            maxs = Vector((max(maxs.x, w.x), max(maxs.y, w.y), max(maxs.z, w.z)))
    return mins, maxs


def guess_forward():
    arm = next((o for o in bpy.context.scene.objects if o.type == "ARMATURE"), None)
    if arm:
        bone = arm.data.bones.get("Head")
        if bone:
            pos = bone.head_local
            flat = Vector((pos.x, pos.y, 0.0))
            if flat.length > 0.02 and abs(pos.z) < flat.length * 1.4:
                return flat.normalized()
        # Upright Quaternius monsters face -Y in Blender after glTF import.
        return Vector((0.0, -1.0, 0.0))
    return Vector((0.0, 1.0, 0.0))


def wrap_and_scale(target_height, forward):
    delete_junk()
    root = empty("Rig")
    bpy.context.view_layer.update()
    for obj in list(bpy.context.scene.objects):
        if obj == root or obj.parent is not None:
            continue
        obj.parent = root
        obj.matrix_parent_inverse = root.matrix_world.inverted()
    bpy.context.view_layer.update()
    mins, maxs = world_bounds()
    height = max(0.05, maxs.z - mins.z)
    scale = target_height / height
    root.scale = (scale, scale, scale)
    bpy.context.view_layer.update()
    mins, maxs = world_bounds()
    root.location.z -= mins.z
    marker = empty("Forward")
    marker.parent = root
    marker.location = (forward.x * 0.75, forward.y * 0.75, target_height * 0.45)
    print("  height", round(height, 3), "scale", round(scale, 3), "fwd", [round(v, 2) for v in forward])
    return root


def add_glow(root, forward, height, color):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.08, location=(0, 0, 0))
    orb = bpy.context.active_object
    orb.name = "GlowCrest"
    mat = bpy.data.materials.new("Glow")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Emission Color"].default_value = color
    bsdf.inputs["Emission Strength"].default_value = 4.0
    orb.data.materials.append(mat)
    orb.parent = root
    orb.location = (forward.x * 0.05, forward.y * 0.05, height * 1.05)


def export(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_apply=False,
        export_yup=True,
        export_animations=True,
        export_skins=True,
        export_morph=False,
        export_lights=False,
        export_cameras=False,
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_vertex_color="NONE",
        export_normals=True,
        export_texcoords=True,
    )
    print("exported", os.path.basename(path), os.path.getsize(path))


def plump_eyes(scale):
    """Grow separate eye meshes from their own center so the face reads younger."""
    bpy.ops.object.select_all(action="DESELECT")
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH" or "eye" not in obj.name.lower():
            continue
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.transform.resize(value=(scale, scale, scale))
        bpy.ops.object.mode_set(mode="OBJECT")
        obj.select_set(False)


def _fake(act):
    try:
        act.use_fake_user = True
    except Exception:
        pass


def add_flap(arm):
    """A short in-place wingbeat for flyers that only shipped an idle or a blink."""
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    action = bpy.data.actions.new("Fly")
    _fake(action)
    arm.animation_data_create()
    arm.animation_data.action = action
    if hasattr(arm.animation_data, "action_slot") and hasattr(action, "slots"):
        slot = action.slots.new(arm.id_type, "Fly") if len(action.slots) == 0 else action.slots[0]
        arm.animation_data.action_slot = slot
    wings = []
    for name in ("Wing.L", "Wing.R", "Wing L", "Wing R"):
        bone = arm.pose.bones.get(name)
        if bone:
            wings.append(bone)
    body = arm.pose.bones.get("Body") or arm.pose.bones.get("Chest")
    keys = (1, 5, 9, 13, 17)
    lifts = (0.15, 0.85, -0.2, 0.85, 0.15)
    for bone in wings:
        bone.rotation_mode = "XYZ"
        rest = bone.rotation_euler.copy()
        # Pixor wings hinge on local X; the sign flips the left and right together.
        sign = -1.0 if bone.name.endswith("L") or bone.name.endswith(" L") else 1.0
        for frame, lift in zip(keys, lifts):
            bone.rotation_euler = rest
            bone.rotation_euler.x += lift * sign
            bone.keyframe_insert("rotation_euler", frame=frame)
    if body:
        body.rotation_mode = "XYZ"
        rest = body.rotation_euler.copy()
        for frame, lift in zip(keys, (0.0, 0.06, 0.0, 0.06, 0.0)):
            body.rotation_euler = rest
            body.location = body.location.copy()
            body.location.z += lift * 0.04
            body.keyframe_insert("rotation_euler", frame=frame)
            body.keyframe_insert("location", frame=frame)
    action.frame_range = (1, 17)
    bpy.ops.object.mode_set(mode="OBJECT")
    return action


def prepare_anims():
    for act in list(bpy.data.actions):
        if act.name.lower() == "blink":
            act.name = "Idle"
        _fake(act)
    names = [act.name.lower() for act in bpy.data.actions]
    has_idle = any("idle" in name for name in names)
    fly = next((act for act in bpy.data.actions if "fly" in act.name.lower() and "idle" not in act.name.lower()), None)
    arm = next((obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"), None)
    if fly is None and arm is not None:
        winged = any(arm.pose.bones.get(name) for name in ("Wing.L", "Wing.R", "Wing L", "Wing R"))
        if winged:
            fly = add_flap(arm)
    if fly is not None and not has_idle:
        hover = fly.copy()
        hover.name = "Flying_Idle"
        _fake(hover)


def critter(src, dest, height, colors=None, hue=None, glow=None, eyes=1.0, force=False):
    if not force and os.path.exists(dest) and os.path.getsize(dest) > 50000:
        print("skip", os.path.basename(dest))
        return
    print("build", os.path.basename(dest))
    reset()
    import_gltf(src)
    drop_normal_maps(512)
    if eyes != 1.0:
        plump_eyes(eyes)
    if colors:
        for part, col in colors.items():
            set_base(part, srgb(col))
    if hue is not None:
        shift_images(hue[0], hue[1], hue[2] if len(hue) > 2 else 1.12)
    prepare_anims()
    fwd = guess_forward()
    root = wrap_and_scale(height, fwd)
    if glow:
        add_glow(root, fwd, height, srgb(glow))
    export(dest)


def prep_nature(src_name, dest_name, hue=None, height=None):
    dest = os.path.join(OUT, dest_name + ".glb")
    if os.path.exists(dest) and os.path.getsize(dest) > 2000:
        print("skip", dest_name)
        return
    print("prop", dest_name)
    reset()
    import_gltf(os.path.join(NATURE, src_name))
    drop_normal_maps(512)
    if hue is not None:
        shift_images(hue[0], hue[1], hue[2] if len(hue) > 2 else 1.05)
    if height:
        fwd = Vector((0, 1, 0))
        wrap_and_scale(height, fwd)
    export(dest)


def assemble(path, parts, mouth, flag_color):
    print("assemble", os.path.basename(path))
    reset()
    for src, loc, scale, rot in parts:
        fresh = import_gltf(os.path.join(NATURE, src))
        holder = empty("bit")
        bpy.context.view_layer.update()
        for obj in fresh:
            if obj.parent is None:
                obj.parent = holder
                obj.matrix_parent_inverse = holder.matrix_world.inverted()
        holder.location = loc
        holder.scale = scale
        holder.rotation_euler = (0, 0, rot)
    drop_normal_maps(256)
    # Dark doorway.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=0.28, location=mouth)
    door = bpy.context.active_object
    door.name = "Mouth"
    door.scale = (1.15, 0.42, 0.85)
    mat = bpy.data.materials.new("Pupil")
    mat.use_nodes = True
    mat.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = srgb("140c0a")
    door.data.materials.append(mat)
    bpy.ops.mesh.primitive_plane_add(size=0.34, location=(mouth[0] + 0.15, mouth[1] - 0.05, mouth[2] + 0.72))
    flag = bpy.context.active_object
    flag.name = "Flag"
    flag.rotation_euler = (0.2, 0, 1.2)
    fmat = bpy.data.materials.new("Flag")
    fmat.use_nodes = True
    bsdf = fmat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = srgb(flag_color)
    bsdf.inputs["Emission Color"].default_value = srgb(flag_color)
    bsdf.inputs["Emission Strength"].default_value = 0.6
    flag.data.materials.append(fmat)
    fwd = Vector((0.0, -1.0, 0.0))
    wrap_and_scale(1.35, fwd)
    export(path)


def main():
    # Heroes and the rest of the cast. Evolutions reuse the mesh with a new palette.
    # Ember is the Pixor CC0 baby dragon: chubby body, big eyes, warm orange.
    dragon_colors = {
        "base": {
            "Baby dragon scales": "ef6a22",
            "Dragon belly": "ffd7a8",
            "Baby dragon wing": "e25a28",
            "Antler": "f0c27a",
        },
        "lava": {
            "Baby dragon scales": "e23a12",
            "Dragon belly": "ffb080",
            "Baby dragon wing": "ff5a1f",
            "Antler": "ffd0a0",
        },
        "water": {
            "Baby dragon scales": "2f9eae",
            "Dragon belly": "e7f6f4",
            "Baby dragon wing": "7fd0d8",
            "Antler": "d8e8ea",
        },
    }
    for form, colors in dragon_colors.items():
        glow = "ff6a1e" if form == "lava" else ("d8f4ff" if form == "water" else None)
        height = 0.95 if form == "base" else 1.06
        critter(DRAGON, os.path.join(OUT, "ember_%s.glb" % form), height, colors=colors, glow=glow, eyes=1.45, force=True)

    # Juniper matches Pebble: the same Gamideo cozy pack, already chibi.
    fox_hues = {
        "base": (0.07, 0.18, 1.06),
        "forest": (0.30, 0.62, 1.05),
        "lava": (0.03, 0.72, 1.16),
    }
    for form, hue in fox_hues.items():
        glow = "ff7a28" if form == "lava" else ("9ed060" if form == "forest" else None)
        height = 0.92 if form == "base" else 1.02
        critter(COZY_FOX, os.path.join(OUT, "juniper_%s.glb" % form), height, hue=hue, glow=glow, force=True)

    critter(OTTER, os.path.join(OUT, "pebble_base.glb"), 0.9, hue=(0.07, 0.25, 1.08))
    critter(OTTER, os.path.join(OUT, "pebble_water.glb"), 1.0, hue=(0.52, 0.45, 1.1), glow="b9ecff")
    critter(OTTER, os.path.join(OUT, "pebble_forest.glb"), 1.0, hue=(0.28, 0.55, 1.08), glow="b6e090")

    frog = {
        "base": {"Frog_Main": "3ea844", "Frog_Secondary": "e7f3b4", "Eye_White": "f4f7ef"},
        "water": {"Frog_Main": "2f9a78", "Frog_Secondary": "e8f6c8", "Eye_White": "f4f7ef"},
        "forest": {"Frog_Main": "6a8a38", "Frog_Secondary": "d8c48a", "Eye_White": "f4f7ef"},
    }
    for form, colors in frog.items():
        glow = "d8ff9a" if form == "forest" else None
        critter(os.path.join(UM, "Big/glTF/Frog.gltf"), os.path.join(OUT, "pip_%s.glb" % form), 0.88 if form == "base" else 0.98, colors=colors, glow=glow)

    # Lumen is the Pixor CC0 owl, recolored cream so it sits with the cozy cast.
    owl_colors = {
        "base": {"Owl feather": "c4956a", "Owl face": "f6ead4", "Beak": "e07a28", "Yellow eye": "ffc233"},
        "forest": {"Owl feather": "6f9a48", "Owl face": "e7f0c4", "Beak": "d9893a", "Yellow eye": "ffe14a"},
        "water": {"Owl feather": "7eafc4", "Owl face": "f3f7fb", "Beak": "e0a060", "Yellow eye": "ffe566"},
    }
    for form, colors in owl_colors.items():
        glow = "d8f4ff" if form == "water" else ("c6e890" if form == "forest" else None)
        critter(
            OWL,
            os.path.join(OUT, "lumen_%s.glb" % form),
            0.9 if form == "base" else 1.0,
            colors=colors,
            glow=glow,
            eyes=1.28,
            force=True,
        )

    hog = {
        "base": {"Cactoro_Main": "8a6238", "Cactoro_Secondary": "4a3424", "Cactoro_Red": "c46a48", "Eye_White": "f6f1ea"},
        "forest": {"Cactoro_Main": "4f7a34", "Cactoro_Secondary": "2c4a22", "Cactoro_Red": "6aaa44", "Eye_White": "f6f1ea"},
        "lava": {"Cactoro_Main": "a85a30", "Cactoro_Secondary": "5a2818", "Cactoro_Red": "ff5a22", "Eye_White": "f6f1ea"},
    }
    for form, colors in hog.items():
        glow = "ff6a1e" if form == "lava" else None
        critter(os.path.join(UM, "Big/glTF/Cactoro.gltf"), os.path.join(OUT, "bramble_%s.glb" % form), 0.98 if form == "base" else 1.1, colors=colors, glow=glow)

    props = [
        ("CommonTree_1.gltf", "tree_a", None, 2.4),
        ("CommonTree_3.gltf", "tree_b", None, 2.1),
        ("TwistedTree_1.gltf", "tree_twist", None, 2.5),
        ("Pine_1.gltf", "tree_pine", None, 2.6),
        ("Pine_3.gltf", "tree_pine_b", None, 2.2),
        ("DeadTree_1.gltf", "tree_dead", (0.06, 0.35, 1.0), 2.3),
        ("Bush_Common.gltf", "bush", None, 0.7),
        ("Bush_Common_Flowers.gltf", "bush_flower", None, 0.75),
        ("Grass_Common_Short.gltf", "grass_short", None, 0.28),
        ("Grass_Common_Tall.gltf", "grass_tall", None, 0.42),
        ("Grass_Wispy_Tall.gltf", "grass_wispy", None, 0.48),
        ("Fern_1.gltf", "fern", None, 0.36),
        ("Clover_1.gltf", "clover", None, 0.16),
        ("Rock_Medium_1.gltf", "rock_a", None, 0.55),
        ("Rock_Medium_2.gltf", "rock_b", None, 0.48),
        ("Rock_Medium_3.gltf", "rock_c", None, 0.62),
        ("Rock_Medium_1.gltf", "rock_lava", (0.04, 0.65, 1.15), 0.55),
        ("Pebble_Round_1.gltf", "pebble_rock", None, 0.22),
        ("Pebble_Round_3.gltf", "pebble_rock_b", None, 0.18),
        ("Mushroom_Common.gltf", "mushroom", None, 0.32),
        ("Mushroom_Laetiporus.gltf", "mushroom_shelf", None, 0.4),
        ("Flower_3_Group.gltf", "flower_a", None, 0.28),
        ("Flower_4_Group.gltf", "flower_b", None, 0.3),
        ("Flower_4_Group.gltf", "flower_lava", (0.04, 0.55, 1.2), 0.3),
        ("RockPath_Round_Wide.gltf", "path_wide", None, 0.28),
        ("RockPath_Round_Small_1.gltf", "path_small", None, 0.16),
    ]
    for src, name, hue, height in props:
        prep_nature(src, name, hue, height)

    assemble(
        os.path.join(OUT, "den.glb"),
        [
            ("Rock_Medium_1.gltf", (0.0, 0.05, 0.0), (1.15, 1.0, 0.95), 0.2),
            ("Rock_Medium_2.gltf", (0.55, -0.05, 0.05), (0.85, 0.8, 0.75), 0.6),
            ("Rock_Medium_3.gltf", (-0.5, 0.0, 0.02), (0.8, 0.75, 0.7), -0.4),
            ("Pebble_Round_2.gltf", (0.05, -0.15, 0.55), (0.45, 0.4, 0.35), 0.1),
        ],
        (0.0, -0.72, 0.28),
        "ffb15a",
    )
    assemble(
        os.path.join(OUT, "burrow.glb"),
        [
            ("Rock_Medium_2.gltf", (0.0, 0.0, 0.0), (0.9, 0.75, 0.55), 0.3),
            ("Pebble_Round_1.gltf", (0.32, 0.05, 0.05), (0.4, 0.35, 0.3), 0.5),
            ("Pebble_Round_4.gltf", (-0.28, -0.02, 0.02), (0.36, 0.32, 0.28), -0.2),
        ],
        (0.0, -0.48, 0.12),
        "ffb15a",
    )
    # Lane bridge from path stones.
    print("assemble bridge")
    reset()
    for i, x in enumerate((-0.35, 0.35)):
        fresh = import_gltf(os.path.join(NATURE, "RockPath_Round_Wide.gltf"))
        holder = empty("bit")
        bpy.context.view_layer.update()
        for obj in fresh:
            if obj.parent is None:
                obj.parent = holder
                obj.matrix_parent_inverse = holder.matrix_world.inverted()
        holder.location = (x, 0.0, 0.0)
        holder.rotation_euler = (0, 0, math.pi * 0.5)
    drop_normal_maps(256)
    wrap_and_scale(0.22, Vector((0, 1, 0)))
    export(os.path.join(OUT, "bridge.glb"))


if __name__ == "__main__":
    main()
