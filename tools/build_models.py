"""Headless Blender builder for Critter Clash.

Original stylized critters and diorama props. Meshes are hand-parameterized
(not primitives dropped in as stand-ins): big readable silhouettes, clay
vertex colors, and separate parts so the game can animate them.

Run:
  blender --background --python tools/build_models.py
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "models")
os.makedirs(OUT, exist_ok=True)


def C(hex_color):
    h = hex_color.lstrip("#")
    return tuple(int(h[i : i + 2], 16) / 255.0 for i in (0, 2, 4))


def mix(a, b, t):
    t = 0.0 if t < 0 else 1.0 if t > 1 else t
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)


def lighten(c, a=0.2):
    return mix(c, (1, 1, 1), a)


def darken(c, a=0.22):
    return mix(c, (0.16, 0.09, 0.08), a)


def clamp01(v):
    return 0.0 if v < 0 else 1.0 if v > 1 else v


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def empty(name):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "PLAIN_AXES"
    obj.empty_display_size = 0.12
    return link(obj)


def prepare(obj):
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = True
    me.update()


def new_mesh(name, bm, mat=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    link(obj)
    if mat is not None:
        obj.data.materials.append(mat)
    prepare(obj)
    return obj


def make_sphere(name, radius, mat, seg=24, rings=14):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=radius, calc_uvs=False)
    return new_mesh(name, bm, mat)


def make_ico(name, radius, mat, subdiv=2):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius, calc_uvs=False)
    return new_mesh(name, bm, mat)


def make_cone(name, radius, depth, mat, segments=8, origin="base"):
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        segments=segments,
        radius1=radius,
        radius2=max(radius * 0.04, 0.004),
        depth=depth,
        calc_uvs=False,
    )
    for v in bm.verts:
        if origin == "base":
            v.co.z += depth * 0.5
        elif origin == "top":
            v.co.z -= depth * 0.5
    return new_mesh(name, bm, mat)


def make_cyl(name, radius, depth, mat, segments=12, origin="base"):
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        segments=segments,
        radius1=radius,
        radius2=radius,
        depth=depth,
        calc_uvs=False,
    )
    for v in bm.verts:
        if origin == "base":
            v.co.z += depth * 0.5
        elif origin == "top":
            v.co.z -= depth * 0.5
    return new_mesh(name, bm, mat)


def make_box(name, sx, sy, sz, mat):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= sx
        v.co.y *= sy
        v.co.z *= sz
    return new_mesh(name, bm, mat)


def scale_verts(obj, sx, sy, sz):
    for v in obj.data.vertices:
        v.co.x *= sx
        v.co.y *= sy
        v.co.z *= sz


def shift_max_to_zero(obj, axis):
    idx = "xyz".index(axis)
    peak = max(v.co[idx] for v in obj.data.vertices)
    for v in obj.data.vertices:
        v.co[idx] -= peak


def parent_to(child, parent, loc=(0, 0, 0), rot=(0, 0, 0)):
    child.parent = parent
    child.location = Vector(loc)
    child.rotation_euler = Euler(rot, "XYZ")
    child.scale = (1, 1, 1)
    return child


def parent_keep(child, parent):
    mw = child.matrix_world.copy()
    child.parent = parent
    child.matrix_world = mw
    return child


def join_objects(objs, name):
    objs = [o for o in objs if o is not None]
    if not objs:
        return None
    if len(objs) == 1:
        objs[0].name = name
        return objs[0]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    return obj


def paint(obj, base, belly=None, tip=None, blush=None, spots=None):
    me = obj.data
    existing = me.color_attributes.get("Color")
    if existing is not None:
        me.color_attributes.remove(existing)
    attr = me.color_attributes.new(name="Color", type="BYTE_COLOR", domain="POINT")
    verts = me.vertices
    zs = [v.co.z for v in verts]
    ys = [v.co.y for v in verts]
    z0, z1 = min(zs), max(zs)
    y0, y1 = min(ys), max(ys)
    dz = max(1e-5, z1 - z0)
    if belly is None:
        belly = lighten(base, 0.24)
    for i, v in enumerate(verts):
        t = (v.co.z - z0) / dz
        u = (v.co.y - y0) / max(1e-5, y1 - y0)
        if tip is not None:
            col = mix(base, tip, t)
        else:
            col = mix(darken(base, 0.2), lighten(base, 0.18), t * 0.85 + 0.15)
            front = clamp01((u - 0.42) * 2.4)
            low = clamp01((0.58 - t) * 1.7)
            col = mix(col, belly, front * low * 0.92)
        if blush is not None:
            center, radius, bcol = blush
            mirrored = Vector((abs(v.co.x), v.co.y, v.co.z))
            target = Vector((abs(center[0]), center[1], center[2]))
            d = (mirrored - target).length
            col = mix(col, bcol, clamp01(1.0 - d / radius))
        if spots:
            for center, radius, scol in spots:
                d = (v.co - Vector(center)).length
                if d < radius:
                    col = mix(col, scol, clamp01(1.0 - d / radius) ** 0.6)
        attr.data[i].color = (col[0], col[1], col[2], 1.0)
    me.color_attributes.active_color = attr


def solid_mat(name, color, emit=0.0, rough=0.45):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1)
    bsdf.inputs["Roughness"].default_value = rough
    if emit > 0:
        bsdf.inputs["Emission Color"].default_value = (color[0], color[1], color[2], 1)
        bsdf.inputs["Emission Strength"].default_value = emit
    return mat


def clay_mat(name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.8
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Color"
    vc.location = (-320, 180)
    nt.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def make_materials(glow_colors=None):
    mats = {
        "clay": clay_mat("Clay"),
        "foliage": clay_mat("Foliage"),
        "sclera": solid_mat("Sclera", (0.99, 0.97, 0.94), 0.25, 0.28),
        "pupil": solid_mat("Pupil", (0.10, 0.07, 0.08), 0.0, 0.2),
        "catch": solid_mat("Catch", (1, 1, 1), 4.0, 0.15),
        "flag": solid_mat("Flag", (0.98, 0.95, 0.88), 0.0, 0.55),
        "cloud": solid_mat("Cloud", (0.96, 0.97, 1.0), 0.55, 1.0),
    }
    if glow_colors:
        first = True
        for col in glow_colors:
            mats.setdefault("glow" if first else "glow_%d" % len(mats), solid_mat("Glow", col, 4.2, 0.35))
            first = False
        if "glow" not in mats:
            mats["glow"] = solid_mat("Glow", glow_colors[0], 4.2, 0.35)
    return mats


def track_z_to(direction):
    quat = direction.normalized().to_track_quat("Z", "Y")
    return quat.to_euler("XYZ")


def add_forward(rig):
    marker = empty("Forward")
    parent_to(marker, rig, (0.0, 0.85, 0.45))


def ground_align(rig):
    bpy.context.view_layer.update()
    lowest = 1e9
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        mw = obj.matrix_world
        for v in obj.data.vertices:
            lowest = min(lowest, (mw @ v.co).z)
    rig.location.z -= lowest
    bpy.context.view_layer.update()


def export_glb(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_apply=True,
        export_yup=True,
        export_animations=False,
        export_skins=False,
        export_morph=False,
        export_lights=False,
        export_cameras=False,
        export_materials="EXPORT",
        export_vertex_color="ACTIVE",
        export_normals=True,
        export_texcoords=False,
        use_selection=False,
        use_visible=False,
        use_renderable=False,
        export_hierarchy_flatten_objs=False,
    )
    print("exported", os.path.basename(path), os.path.getsize(path))


def add_eyes(head, mats, spacing, y, z, radius, iris, pupil_scale=0.46, rot=(0, 0, 0)):
    for sign, side in ((-1, "L"), (1, "R")):
        eye = make_sphere("Sclera" + side, radius, mats["sclera"], 16, 10)
        parent_to(eye, head, (spacing * sign, y, z), rot)
        iris_m = make_sphere("Iris" + side, radius * 0.72, mats["clay"], 12, 8)
        paint(iris_m, iris, lighten(iris, 0.15))
        parent_to(iris_m, eye, (0, radius * 0.42, 0))
        pupil = make_sphere("Pupil" + side, radius * pupil_scale, mats["pupil"], 10, 8)
        parent_to(pupil, eye, (0, radius * 0.62, 0))
        catch = make_sphere("Catch" + side, radius * 0.16, mats["catch"], 8, 6)
        parent_to(catch, eye, (radius * 0.22, radius * 0.72, radius * 0.28))


def add_cheeks(head, mat, color, spacing, y, z, size):
    for sign, side in ((-1, "L"), (1, "R")):
        cheek = make_sphere("Cheek" + side, size, mat, 10, 8)
        scale_verts(cheek, 1.0, 0.45, 0.72)
        prepare(cheek)
        paint(cheek, color, lighten(color, 0.2))
        parent_to(cheek, head, (spacing * sign, y, z))


def add_belly(body, mat, color, loc, size, squash=(0.82, 0.42, 0.72)):
    belly = make_sphere("Belly", size, mat, 16, 10)
    scale_verts(belly, squash[0], squash[1], squash[2])
    prepare(belly)
    paint(belly, color, lighten(color, 0.12))
    parent_to(belly, body, loc)
    return belly


def add_nose(head, mat, loc, size, color):
    nose = make_sphere("Nose", size, mat, 10, 8)
    scale_verts(nose, 1.05, 0.85, 0.75)
    prepare(nose)
    paint(nose, color, lighten(color, 0.1))
    parent_to(nose, head, loc)
    return nose


def add_leg(parent, name, mat, loc, length, radius, color, foot=1.0):
    limb = make_sphere(name, radius, mat, 12, 8)
    scale_verts(limb, 1.0, 0.92, length / (2.0 * radius))
    shift_max_to_zero(limb, "z")
    prepare(limb)
    paint(limb, color, lighten(color, 0.12))
    parent_to(limb, parent, loc)
    foot_m = make_sphere(name.replace("Leg", "Foot"), radius * 0.95 * foot, mat, 10, 6)
    scale_verts(foot_m, 1.15, 1.45, 0.42)
    prepare(foot_m)
    paint(foot_m, darken(color, 0.18), lighten(color, 0.05))
    parent_to(foot_m, limb, (0, radius * 0.25, -length * 0.92))
    return limb


def add_tail(parent, mat, loc, lengths, radii, colors, tip=None):
    prev = parent
    local = loc
    names = ["Tail", "TailMid", "TailTip"]
    segs = []
    for i, (length, radius) in enumerate(zip(lengths, radii)):
        seg = make_sphere(names[i], radius, mat, 14, 10)
        scale_verts(seg, 1.0, length / (2.0 * radius), 1.0)
        shift_max_to_zero(seg, "y")
        prepare(seg)
        col = colors[min(i, len(colors) - 1)]
        paint(seg, col, lighten(col, 0.16), tip=tip if i == len(lengths) - 1 else None)
        parent_to(seg, prev, local)
        segs.append(seg)
        prev = seg
        local = (0, -length * 0.82, 0)
    return segs


def make_wing(name, mat, length, sign, color, belly):
    bm = bmesh.new()
    pts = [
        (0.0, 0.0, 0.0),
        (0.22 * length, 0.0, 0.48 * length),
        (0.78 * length, 0.0, 0.36 * length),
        (1.05 * length, 0.0, 0.0),
        (0.68 * length, 0.0, -0.30 * length),
        (0.16 * length, 0.0, -0.10 * length),
    ]
    thick = 0.018 * max(1.0, length)
    top = []
    bot = []
    for x, y, z in pts:
        top.append(bm.verts.new((sign * x, thick, z)))
        bot.append(bm.verts.new((sign * x, -thick, z)))
    bm.verts.ensure_lookup_table()

    def face(vs, flip=False):
        seq = list(reversed(vs)) if flip else vs
        try:
            bm.faces.new(seq)
        except ValueError:
            pass

    order = list(range(len(pts)))
    face([top[i] for i in order], flip=sign < 0)
    face([bot[i] for i in order], flip=sign > 0)
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        face([top[i], bot[i], bot[j], top[j]], flip=sign < 0)
    return new_mesh(name, bm, mat)


def add_wings(body, mat, length, color, belly, z=0.05, y=0.02, droop=-0.35):
    wings = []
    for sign, side in ((1, "L"), (-1, "R")):
        wing = make_wing("Wing" + side, mat, length, sign, color, belly)
        paint(wing, color, belly)
        parent_to(wing, body, (sign * 0.12, y, z), (0.15, droop * sign, 0.2 * sign))
        wings.append(wing)
    return wings


def add_leaf(parent, mat, loc, rot, length, color):
    leaf = make_sphere("Leaf", length * 0.45, mat, 10, 8)
    scale_verts(leaf, 0.28, 1.0, 0.55)
    shift_max_to_zero(leaf, "y")
    for v in leaf.data.vertices:
        v.co.y *= -1
        v.co.y -= length * 0.05
    prepare(leaf)
    paint(leaf, color, lighten(color, 0.2), tip=lighten(color, 0.35))
    parent_to(leaf, parent, loc, rot)
    return leaf


def add_flower(parent, mats, loc, scale, petal, center, foliage=False):
    root = empty("Flower")
    parent_to(root, parent, loc)
    mat = mats["foliage"] if foliage else mats["clay"]
    petals = []
    for i in range(5):
        ang = i * math.tau / 5.0
        petal_m = make_sphere("Petal", 0.09 * scale, mat, 8, 6)
        scale_verts(petal_m, 0.7, 1.25, 0.35)
        prepare(petal_m)
        paint(petal_m, petal, lighten(petal, 0.25))
        parent_to(
            petal_m,
            root,
            (math.cos(ang) * 0.09 * scale, math.sin(ang) * 0.09 * scale, 0),
            (0, 0, ang),
        )
        petals.append(petal_m)
    heart = make_sphere("FlowerHeart", 0.055 * scale, mats["clay"], 8, 6)
    paint(heart, center, lighten(center, 0.2))
    parent_to(heart, root, (0, 0, 0.02 * scale))
    return root


def add_horn(parent, mat, name, loc, rot, radius, length, base, tip):
    horn = make_cone(name, radius, length, mat, segments=7, origin="base")
    paint(horn, base, tip=tip)
    parent_to(horn, parent, loc, rot)
    return horn


def add_quills(body, mat, glow, body_r, count, length, radius, base, tip, glow_tips=False):
    root = empty("Quills")
    parent_to(root, body, (0, 0, 0))
    golden = math.pi * (3.0 - math.sqrt(5.0))
    made = 0
    i = 0
    while made < count and i < count * 8:
        # Hemisphere biased toward the back (+Z, -Y).
        t = (made + 0.5) / count
        phi = math.acos(1.0 - t) * 0.78
        theta = golden * i
        y = -math.sin(phi) * math.cos(theta)
        x = math.sin(phi) * math.sin(theta)
        z = math.cos(phi)
        if y > 0.35:
            i += 1
            continue
        outward = Vector((x, y, z)).normalized()
        pos = outward * body_r * 0.78
        rot = track_z_to(outward)
        quill = make_cone("Quill", radius, length, mat, segments=6, origin="base")
        paint(quill, base, tip=tip)
        parent_to(quill, root, pos, rot)
        if glow_tips and glow is not None:
            spark = make_sphere("GlowTip", radius * 0.85, glow, 6, 4)
            parent_to(spark, quill, (0, 0, length * 0.92))
        made += 1
        i += 1
    return root


def align_and_export(rig, path):
    add_forward(rig)
    ground_align(rig)
    export_glb(path)


def build_dragon(path, p):
    reset_scene()
    glow_cols = []
    if p.get("flame"):
        glow_cols.append(C("ff8a1e"))
    if p.get("mist"):
        glow_cols.append(C("d7f4ff"))
    mats = make_materials(glow_cols or [C("ffb15a")])
    s = p["s"]
    body_c, belly_c = p["body"], p["belly"]
    rig = empty("Rig")
    body = make_sphere("Body", 0.34 * s, mats["clay"], 28, 16)
    scale_verts(body, 0.98, 1.12, 0.86)
    for v in body.data.vertices:
        if v.co.y > 0 and v.co.z > 0:
            v.co.y += 0.06 * s
            v.co.z += 0.03 * s
    prepare(body)
    blush = (0.16 * s, 0.18 * s, 0.05 * s)
    paint(body, body_c, belly_c, blush=(blush, 0.12 * s, p["blush"]))
    parent_to(body, rig, (0, 0.02 * s, 0.40 * s))
    add_belly(body, mats["clay"], belly_c, (0, 0.20 * s, -0.06 * s), 0.22 * s, (0.78, 0.55, 0.62))

    head = make_sphere("Head", 0.25 * s, mats["clay"], 26, 14)
    scale_verts(head, 1.05, 1.02, 0.96)
    prepare(head)
    paint(head, body_c, belly_c, blush=((0.12 * s, 0.12 * s, -0.02 * s), 0.09 * s, p["blush"]))
    parent_to(head, body, (0, 0.30 * s, 0.20 * s))

    snout = make_sphere("Snout", 0.11 * s, mats["clay"], 14, 10)
    scale_verts(snout, 0.85, 1.35, 0.62)
    prepare(snout)
    paint(snout, mix(body_c, belly_c, 0.35), belly_c)
    parent_to(snout, head, (0, 0.20 * s, -0.04 * s))
    add_nose(head, mats["clay"], (0, 0.30 * s, -0.02 * s), 0.035 * s, darken(body_c, 0.45))
    mouth = make_sphere("Mouth", 0.055 * s, mats["pupil"], 10, 8)
    scale_verts(mouth, 1.3, 0.55, 0.4)
    parent_to(mouth, head, (0, 0.22 * s, -0.07 * s))

    add_eyes(
        head,
        mats,
        spacing=0.105 * s,
        y=0.14 * s,
        z=0.05 * s,
        radius=0.078 * s,
        iris=p["iris"],
        pupil_scale=0.42,
    )
    add_cheeks(head, mats["clay"], p["blush"], 0.15 * s, 0.12 * s, -0.04 * s, 0.055 * s)

    horn_n = p.get("horns", 2)
    horn_len = p.get("horn_len", 0.18) * s
    spots = [(-0.09, 0.09), (0.09, -0.09), (-0.12, -0.02), (0.12, 0.04)]
    for i in range(horn_n):
        x, z = spots[i]
        sign = -1 if x < 0 else 1
        add_horn(
            head,
            mats["clay"],
            "Horn%s%d" % ("L" if sign < 0 else "R", i),
            (x * s, -0.02 * s, 0.16 * s + (0.05 * s if i > 1 else 0)),
            (0.5, 0, -0.55 * sign),
            0.045 * s * (0.8 if i > 1 else 1.0),
            horn_len * (0.7 if i > 1 else 1.0),
            p.get("horn", belly_c),
            p.get("horn_tip", lighten(belly_c, 0.3)),
        )

    add_wings(body, mats["clay"], p.get("wing", 0.55) * s, p["wing_c"], lighten(p["wing_c"], 0.2), z=0.08 * s, y=-0.02 * s)
    add_tail(
        body,
        mats["clay"],
        (0, -0.30 * s, 0.02 * s),
        [0.22 * s, 0.20 * s, 0.18 * s],
        [0.09 * s, 0.07 * s, 0.055 * s],
        [body_c, body_c, mix(body_c, belly_c, 0.4)],
    )
    # Spade on the last segment. TailTip is the third sphere; find it.
    tip = bpy.data.objects["TailTip"]
    spade = make_sphere("ExtraA", 0.10 * s, mats["clay"], 10, 8)
    scale_verts(spade, 1.6, 0.55, 0.28)
    prepare(spade)
    paint(spade, p.get("spade", belly_c), lighten(belly_c, 0.15))
    parent_to(spade, tip, (0, -0.16 * s, 0))

    for sign, side, x in ((-1, "L", -0.16), (1, "R", 0.16)):
        add_leg(body, "LegF" + side, mats["clay"], (x * s, 0.16 * s, -0.20 * s), 0.20 * s, 0.07 * s, darken(body_c, 0.05))
        add_leg(body, "LegB" + side, mats["clay"], (x * s, -0.16 * s, -0.22 * s), 0.18 * s, 0.065 * s, darken(body_c, 0.08))

    if p.get("flame"):
        glow = mats["glow"]
        for i, (x, y, z, ln) in enumerate(
            ((0, 0.05, 0.22, 0.22), (-0.08, -0.02, 0.16, 0.14), (0.08, -0.02, 0.16, 0.14), (0, -0.12, 0.18, 0.16))
        ):
            flame = make_cone("GlowCrest", 0.055 * s, ln * s, glow, segments=6, origin="base")
            parent_to(flame, body if i else head, (x * s, y * s, z * s), (-0.4, 0, 0))
    if p.get("mist"):
        glow = mats["glow"]
        for i, loc in enumerate(((0.18, 0.05, 0.16), (-0.2, -0.08, 0.14), (0.05, -0.2, 0.18), (0, 0.22, 0.22))):
            puff = make_sphere("CloudPuff", 0.09 * s, glow, 10, 8)
            scale_verts(puff, 1.2, 0.8, 0.7)
            parent_to(puff, body, tuple(c * s for c in loc))
        fin = make_sphere("ExtraB", 0.12 * s, mats["clay"], 10, 8)
        scale_verts(fin, 0.25, 0.9, 1.1)
        prepare(fin)
        paint(fin, p["wing_c"], lighten(p["wing_c"], 0.25))
        parent_to(fin, bpy.data.objects["TailMid"], (0, -0.02 * s, 0.06 * s))
        # Whiskers.
        for sign in (-1, 1):
            for k, dz in enumerate((-0.01, 0.015)):
                whisk = make_cyl("Whisker", 0.006 * s, 0.16 * s, mats["clay"], segments=6, origin="base")
                paint(whisk, lighten(belly_c, 0.1), tip=belly_c)
                parent_to(whisk, snout, (0.04 * s * sign, 0.06 * s, dz * s), (0.2, 1.2 * sign, 0))
    align_and_export(rig, path)


def build_otter(path, p):
    reset_scene()
    mats = make_materials([C("b9ecff")])
    s = p["s"]
    body_c, belly_c = p["body"], p["belly"]
    rig = empty("Rig")
    body = make_sphere("Body", 0.30 * s, mats["clay"], 28, 16)
    scale_verts(body, 0.78, 1.85, 0.62)
    prepare(body)
    paint(body, body_c, belly_c, blush=((0.12 * s, 0.28 * s, 0.02 * s), 0.1 * s, p["blush"]))
    parent_to(body, rig, (0, 0, 0.30 * s))
    add_belly(body, mats["clay"], belly_c, (0, 0.10 * s, -0.06 * s), 0.20 * s, (0.7, 1.3, 0.45))

    head = make_sphere("Head", 0.20 * s, mats["clay"], 22, 12)
    scale_verts(head, 1.05, 0.95, 0.9)
    prepare(head)
    paint(head, body_c, belly_c, blush=((0.1 * s, 0.08 * s, -0.02 * s), 0.08 * s, p["blush"]))
    parent_to(head, body, (0, 0.46 * s, 0.10 * s))
    snout = make_sphere("Snout", 0.09 * s, mats["clay"], 12, 8)
    scale_verts(snout, 0.9, 1.25, 0.6)
    prepare(snout)
    paint(snout, mix(body_c, belly_c, 0.45), belly_c)
    parent_to(snout, head, (0, 0.14 * s, -0.03 * s))
    add_nose(head, mats["clay"], (0, 0.22 * s, -0.01 * s), 0.038 * s, C("3c241c"))
    add_eyes(head, mats, 0.09 * s, 0.10 * s, 0.04 * s, 0.055 * s, p["iris"], 0.5)
    add_cheeks(head, mats["clay"], p["blush"], 0.12 * s, 0.08 * s, -0.03 * s, 0.045 * s)
    for sign, side in ((-1, "L"), (1, "R")):
        ear = make_sphere("Ear" + side, 0.045 * s, mats["clay"], 8, 6)
        scale_verts(ear, 0.7, 0.45, 1.0)
        prepare(ear)
        paint(ear, darken(body_c, 0.1), belly_c)
        parent_to(ear, head, (0.12 * s * sign, -0.02 * s, 0.14 * s), (0, 0, 0.4 * sign))
        for k in range(2):
            whisk = make_cyl("Whisker", 0.005 * s, 0.14 * s, mats["clay"], 5, origin="base")
            paint(whisk, C("f4e6d4"))
            parent_to(whisk, snout, (0.04 * s * sign, 0.04 * s, (-0.01 + k * 0.02) * s), (0.1, 1.15 * sign, 0))

    # Paddle tail.
    tail = make_sphere("Tail", 0.16 * s, mats["clay"], 16, 10)
    scale_verts(tail, 1.15, 1.7, 0.28)
    shift_max_to_zero(tail, "y")
    prepare(tail)
    paint(tail, p.get("tail", body_c), belly_c)
    parent_to(tail, body, (0, -0.48 * s, -0.02 * s))

    for sign, side, x in ((-1, "L", -0.16), (1, "R", 0.16)):
        add_leg(body, "LegF" + side, mats["clay"], (x * s, 0.28 * s, -0.12 * s), 0.14 * s, 0.055 * s, darken(body_c, 0.08), foot=1.25)
        add_leg(body, "LegB" + side, mats["clay"], (x * s, -0.22 * s, -0.13 * s), 0.13 * s, 0.05 * s, darken(body_c, 0.1), foot=1.3)

    if p.get("fin"):
        fin = make_sphere("ExtraA", 0.10 * s, mats["clay"], 10, 8)
        scale_verts(fin, 0.28, 0.7, 1.15)
        prepare(fin)
        paint(fin, p["fin"], lighten(p["fin"], 0.2))
        parent_to(fin, body, (0, -0.05 * s, 0.16 * s))
        for loc in ((0.18, 0.1, 0.12), (-0.16, -0.15, 0.1), (0.1, 0.3, 0.14)):
            drop = make_sphere("Drop", 0.035 * s, mats["glow"], 8, 6)
            parent_to(drop, body, tuple(c * s for c in loc))
    if p.get("moss"):
        leaf_c = C("6f9a45")
        add_leaf(head, mats["foliage"], (0, -0.02 * s, 0.18 * s), (0.4, 0, 0), 0.18 * s, leaf_c)
        for loc in ((0.12, -0.1, 0.08), (-0.1, 0.05, 0.1), (0.02, -0.25, 0.08)):
            blob = make_sphere("Moss", 0.07 * s, mats["foliage"], 8, 6)
            scale_verts(blob, 1.2, 1.0, 0.55)
            prepare(blob)
            paint(blob, leaf_c, lighten(leaf_c, 0.2))
            parent_to(blob, body, tuple(c * s for c in loc))
        add_flower(head, mats, (0.1 * s, 0.02 * s, 0.16 * s), s * 0.7, C("f2c1d2"), C("ffe08a"))
    align_and_export(rig, path)


def build_fox(path, p):
    reset_scene()
    mats = make_materials([C("ffb15a"), C("ffd27a")])
    s = p["s"]
    body_c, belly_c = p["body"], p["belly"]
    rig = empty("Rig")
    body = make_sphere("Body", 0.28 * s, mats["clay"], 26, 14)
    scale_verts(body, 0.62, 1.25, 0.78)
    prepare(body)
    paint(body, body_c, belly_c, blush=((0.1 * s, 0.18 * s, 0.05 * s), 0.08 * s, p["blush"]))
    parent_to(body, rig, (0, 0, 0.40 * s))
    add_belly(body, mats["clay"], belly_c, (0, 0.12 * s, -0.08 * s), 0.16 * s, (0.55, 0.9, 0.55))

    head = make_sphere("Head", 0.18 * s, mats["clay"], 22, 12)
    scale_verts(head, 0.95, 1.05, 0.92)
    prepare(head)
    paint(head, body_c, belly_c, blush=((0.08 * s, 0.08 * s, -0.01 * s), 0.07 * s, p["blush"]))
    parent_to(head, body, (0, 0.30 * s, 0.16 * s))
    snout = make_sphere("Snout", 0.09 * s, mats["clay"], 12, 8)
    scale_verts(snout, 0.7, 1.65, 0.5)
    prepare(snout)
    paint(snout, belly_c, lighten(belly_c, 0.08))
    parent_to(snout, head, (0, 0.14 * s, -0.04 * s))
    add_nose(head, mats["clay"], (0, 0.26 * s, -0.02 * s), 0.032 * s, C("2c1814"))
    add_eyes(head, mats, 0.075 * s, 0.09 * s, 0.04 * s, 0.048 * s, p["iris"], 0.48)
    add_cheeks(head, mats["clay"], p["blush"], 0.10 * s, 0.06 * s, -0.02 * s, 0.04 * s)

    for sign, side in ((-1, "L"), (1, "R")):
        ear = make_cone("Ear" + side, 0.07 * s, 0.20 * s, mats["clay"], segments=8, origin="base")
        paint(ear, body_c, tip=p.get("ear_tip", darken(body_c, 0.25)))
        parent_to(ear, head, (0.08 * s * sign, -0.02 * s, 0.12 * s), (-0.25, 0, -0.35 * sign))
        if p.get("cinder"):
            spark = make_sphere("GlowEar", 0.03 * s, mats["glow"], 8, 6)
            parent_to(spark, ear, (0, 0, 0.19 * s))

    add_tail(
        body,
        mats["clay"],
        (0, -0.30 * s, 0.06 * s),
        [0.18 * s, 0.18 * s, 0.20 * s],
        [0.08 * s, 0.11 * s, 0.15 * s],
        [body_c, body_c, belly_c],
        tip=lighten(belly_c, 0.15),
    )
    for sign, side, x, y in ((-1, "L", -0.12, 0.16), (1, "R", 0.12, 0.16)):
        add_leg(body, "LegF" + side, mats["clay"], (x * s, y * s, -0.16 * s), 0.24 * s, 0.045 * s, darken(body_c, 0.12))
    for sign, side, x in ((-1, "L", -0.12), (1, "R", 0.12)):
        add_leg(body, "LegB" + side, mats["clay"], (x * s, -0.14 * s, -0.16 * s), 0.22 * s, 0.045 * s, darken(body_c, 0.15))

    if p.get("thorn"):
        leaf_c = C("6ea84a")
        for i in range(6):
            ang = i / 6 * math.tau
            add_leaf(
                body,
                mats["foliage"],
                (math.cos(ang) * 0.12 * s, 0.18 * s, 0.10 * s + math.sin(ang) * 0.04 * s),
                (0.6, ang, 0.2),
                0.16 * s,
                leaf_c,
            )
    if p.get("cinder"):
        spark = make_sphere("GlowTail", 0.06 * s, mats["glow"], 8, 6)
        parent_to(spark, bpy.data.objects["TailTip"], (0, -0.12 * s, 0.04 * s))
    align_and_export(rig, path)


def build_hedgehog(path, p):
    reset_scene()
    mats = make_materials([C("ff9a3c")])
    s = p["s"]
    body_c, belly_c = p["body"], p["belly"]
    rig = empty("Rig")
    body_r = 0.40 * s
    body = make_sphere("Body", body_r, mats["clay"], 28, 16)
    scale_verts(body, 1.05, 1.08, 0.95)
    prepare(body)
    paint(body, body_c, belly_c, blush=((0.12 * s, 0.22 * s, -0.02 * s), 0.1 * s, p["blush"]))
    parent_to(body, rig, (0, 0, body_r * 0.78))
    add_belly(body, mats["clay"], belly_c, (0, 0.22 * s, -0.12 * s), 0.20 * s, (0.85, 0.55, 0.6))

    head = make_sphere("Head", 0.20 * s, mats["clay"], 20, 12)
    scale_verts(head, 1.1, 0.95, 0.9)
    prepare(head)
    paint(head, mix(body_c, belly_c, 0.55), belly_c, blush=((0.1 * s, 0.08 * s, -0.02 * s), 0.08 * s, p["blush"]))
    parent_to(head, body, (0, 0.30 * s, -0.06 * s))
    add_nose(head, mats["clay"], (0, 0.16 * s, -0.02 * s), 0.055 * s, C("3a241c"))
    add_eyes(head, mats, 0.09 * s, 0.10 * s, 0.05 * s, 0.055 * s, p["iris"], 0.55)
    add_cheeks(head, mats["clay"], p["blush"], 0.12 * s, 0.06 * s, -0.04 * s, 0.05 * s)
    for sign, side in ((-1, "L"), (1, "R")):
        ear = make_sphere("Ear" + side, 0.05 * s, mats["clay"], 8, 6)
        scale_verts(ear, 0.7, 0.4, 1.0)
        prepare(ear)
        paint(ear, belly_c, darken(body_c, 0.1))
        parent_to(ear, head, (0.12 * s * sign, -0.02 * s, 0.12 * s))

    add_quills(
        body,
        mats["clay"],
        mats["glow"] if p.get("ember") else None,
        body_r,
        p.get("quill_count", 18),
        p.get("quill_len", 0.26) * s,
        0.035 * s,
        p["quill"],
        p["quill_tip"],
        glow_tips=p.get("ember", False),
    )
    tail = make_sphere("Tail", 0.04 * s, mats["clay"], 8, 6)
    paint(tail, body_c)
    parent_to(tail, body, (0, -0.32 * s, -0.05 * s))

    for sign, side, x, y in ((-1, "L", -0.16, 0.16), (1, "R", 0.16, 0.16)):
        add_leg(body, "LegF" + side, mats["clay"], (x * s, y * s, -0.28 * s), 0.12 * s, 0.055 * s, darken(body_c, 0.15))
    for sign, side, x in ((-1, "L", -0.16), (1, "R", 0.16)):
        add_leg(body, "LegB" + side, mats["clay"], (x * s, -0.14 * s, -0.28 * s), 0.11 * s, 0.05 * s, darken(body_c, 0.18))

    if p.get("briar"):
        leaf_c = C("6d8a48")
        for sign, loc in ((-1, (-0.28, 0.02, 0.05)), (1, (0.28, 0.02, 0.05)), (-1, (-0.18, -0.16, 0.1)), (1, (0.2, 0.16, 0.08))):
            plate = make_sphere("Leaf", 0.12 * s, mats["foliage"], 10, 8)
            scale_verts(plate, 0.7, 1.1, 0.28)
            prepare(plate)
            paint(plate, leaf_c, lighten(leaf_c, 0.25))
            parent_to(plate, body, tuple(c * s for c in loc))
        add_flower(body, mats, (0, -0.05 * s, body_r * 0.85), s * 0.85, C("e86b8a"), C("ffe08a"))
    align_and_export(rig, path)


def build_owl(path, p):
    reset_scene()
    mats = make_materials([C("ffe27a"), C("c5ddff")])
    s = p["s"]
    body_c, belly_c = p["body"], p["belly"]
    rig = empty("Rig")
    body = make_sphere("Body", 0.32 * s, mats["clay"], 28, 16)
    scale_verts(body, 0.92, 0.78, 1.2)
    prepare(body)
    paint(body, body_c, belly_c)
    parent_to(body, rig, (0, 0, 0.46 * s))
    add_belly(body, mats["clay"], belly_c, (0, 0.16 * s, -0.02 * s), 0.20 * s, (0.75, 0.4, 0.85))

    head = make_sphere("Head", 0.24 * s, mats["clay"], 24, 14)
    scale_verts(head, 1.12, 0.95, 1.0)
    prepare(head)
    paint(head, body_c, belly_c)
    parent_to(head, body, (0, 0.06 * s, 0.30 * s))
    add_eyes(head, mats, 0.10 * s, 0.14 * s, 0.02 * s, 0.105 * s, p["iris"], 0.38)
    beak = make_cone("Snout", 0.045 * s, 0.10 * s, mats["clay"], segments=6, origin="base")
    paint(beak, p["beak"], tip=darken(p["beak"], 0.2))
    parent_to(beak, head, (0, 0.16 * s, -0.04 * s), (1.15, 0, 0))
    for sign, side in ((-1, "L"), (1, "R")):
        tuft = make_cone("Ear" + side, 0.04 * s, 0.12 * s, mats["clay"], segments=6, origin="base")
        paint(tuft, body_c, tip=darken(body_c, 0.2))
        parent_to(tuft, head, (0.10 * s * sign, -0.04 * s, 0.16 * s), (-0.5, 0, -0.4 * sign))

    add_wings(
        body,
        mats["clay"],
        p.get("wing", 0.72) * s,
        p["wing_c"],
        lighten(p["wing_c"], 0.18),
        z=0.05 * s,
        y=0.0,
        droop=-0.9,
    )
    # Feather fan.
    fan_root = empty("Tail")
    parent_to(fan_root, body, (0, -0.18 * s, -0.05 * s))
    for i, x in enumerate((-0.08, 0.0, 0.08)):
        feather = make_sphere("Feather", 0.08 * s, mats["clay"], 8, 6)
        scale_verts(feather, 0.45, 1.3, 0.15)
        shift_max_to_zero(feather, "y")
        prepare(feather)
        paint(feather, p["wing_c"], belly_c)
        parent_to(feather, fan_root, (x * s, 0, -0.02 * s), (0.4, 0, x * 2.5))
    # Tiny feet.
    for sign, side in ((-1, "L"), (1, "R")):
        add_leg(body, "LegF" + side, mats["clay"], (0.08 * s * sign, 0.06 * s, -0.30 * s), 0.10 * s, 0.035 * s, p["beak"], foot=1.4)
        # Back legs hidden stubs so the animator still finds them.
        stub = make_sphere("LegB" + side, 0.02 * s, mats["clay"], 6, 4)
        paint(stub, p["beak"])
        parent_to(stub, body, (0.06 * s * sign, -0.08 * s, -0.28 * s))

    if p.get("grove"):
        leaf_c = C("7da35a")
        for i in range(5):
            ang = -0.8 + i * 0.4
            add_leaf(body, mats["foliage"], (math.sin(ang) * 0.18 * s, 0.08 * s, 0.05 * s), (0.9, 0, ang), 0.18 * s, leaf_c)
    if p.get("storm"):
        bolt = make_cone("GlowBolt", 0.05 * s, 0.16 * s, mats["glow"], segments=4, origin="base")
        parent_to(bolt, body, (0.04 * s, 0.18 * s, 0.02 * s), (1.2, 0, 0.4))
        bolt2 = make_cone("GlowBoltB", 0.035 * s, 0.10 * s, mats["glow"], segments=4, origin="base")
        parent_to(bolt2, body, (-0.02 * s, 0.16 * s, -0.06 * s), (1.3, 0, -0.5))
    align_and_export(rig, path)


def build_frog(path, p):
    reset_scene()
    mats = make_materials([C("e7ffa8"), C("d7c4ff")])
    s = p["s"]
    body_c, belly_c = p["body"], p["belly"]
    rig = empty("Rig")
    body = make_sphere("Body", 0.32 * s, mats["clay"], 26, 14)
    scale_verts(body, 1.28, 1.05, 0.72)
    prepare(body)
    spots = None
    if p.get("spots"):
        spots = [
            ((0.12 * s, 0.05 * s, 0.08 * s), 0.06 * s, p["spots"]),
            ((-0.14 * s, -0.08 * s, 0.06 * s), 0.05 * s, p["spots"]),
            ((0.02 * s, -0.12 * s, 0.10 * s), 0.045 * s, p["spots"]),
            ((-0.05 * s, 0.12 * s, 0.04 * s), 0.04 * s, p["spots"]),
        ]
    paint(body, body_c, belly_c, blush=((0.16 * s, 0.12 * s, 0.0), 0.1 * s, p["blush"]), spots=spots)
    parent_to(body, rig, (0, 0, 0.30 * s))
    add_belly(body, mats["clay"], belly_c, (0, 0.12 * s, -0.08 * s), 0.22 * s, (1.0, 0.7, 0.45))

    head = make_sphere("Head", 0.22 * s, mats["clay"], 20, 12)
    scale_verts(head, 1.25, 1.0, 0.72)
    prepare(head)
    paint(head, body_c, belly_c, blush=((0.14 * s, 0.08 * s, 0.0), 0.08 * s, p["blush"]))
    parent_to(head, body, (0, 0.16 * s, 0.10 * s))
    mouth = make_sphere("Mouth", 0.12 * s, mats["pupil"], 12, 8)
    scale_verts(mouth, 1.5, 0.35, 0.28)
    parent_to(mouth, head, (0, 0.12 * s, -0.06 * s))
    add_eyes(
        head,
        mats,
        spacing=0.12 * s,
        y=0.04 * s,
        z=0.12 * s,
        radius=0.075 * s,
        iris=p["iris"],
        pupil_scale=0.62,
        rot=(-0.6, 0, 0),
    )
    add_cheeks(head, mats["clay"], p["blush"], 0.16 * s, 0.08 * s, -0.02 * s, 0.055 * s)

    # Folded hind legs are the silhouette.
    for sign, side in ((-1, "L"), (1, "R")):
        thigh = make_sphere("LegB" + side, 0.12 * s, mats["clay"], 12, 8)
        scale_verts(thigh, 0.7, 1.35, 0.7)
        prepare(thigh)
        paint(thigh, body_c, belly_c)
        parent_to(thigh, body, (0.22 * s * sign, -0.10 * s, -0.08 * s), (0.5, 0, 0.5 * sign))
        shin = make_sphere("Shin" + side, 0.07 * s, mats["clay"], 10, 6)
        scale_verts(shin, 0.6, 1.4, 0.55)
        prepare(shin)
        paint(shin, body_c, belly_c)
        parent_to(shin, thigh, (0.04 * s * sign, -0.12 * s, -0.06 * s))
        add_leg(body, "LegF" + side, mats["clay"], (0.14 * s * sign, 0.16 * s, -0.16 * s), 0.12 * s, 0.04 * s, darken(body_c, 0.05))

    tail = make_sphere("Tail", 0.02 * s, mats["clay"], 6, 4)
    paint(tail, body_c)
    parent_to(tail, body, (0, -0.28 * s, 0))

    if p.get("lily"):
        add_flower(head, mats, (0, -0.02 * s, 0.16 * s), s, C("f2a0c0"), C("ffe08a"), foliage=False)
        pad = make_sphere("ExtraA", 0.16 * s, mats["foliage"], 12, 8)
        scale_verts(pad, 1.3, 1.1, 0.12)
        prepare(pad)
        paint(pad, C("7dbe6a"), C("d7f0a8"))
        parent_to(pad, body, (0, -0.08 * s, 0.16 * s))
    if p.get("spore"):
        cap = make_sphere("ExtraB", 0.20 * s, mats["clay"], 16, 10)
        scale_verts(cap, 1.15, 1.15, 0.55)
        prepare(cap)
        paint(
            cap,
            C("f3ead4"),
            C("fff8ec"),
            spots=[
                ((0.08 * s, 0.04 * s, 0.04 * s), 0.045 * s, C("8b6bb5")),
                ((-0.07 * s, -0.05 * s, 0.05 * s), 0.04 * s, C("8b6bb5")),
                ((0.0, 0.09 * s, 0.05 * s), 0.035 * s, C("c45b8a")),
            ],
        )
        parent_to(cap, head, (0, 0, 0.12 * s))
        for loc in ((0.16, 0.02, 0.2), (-0.14, -0.06, 0.18), (0.02, 0.12, 0.22)):
            mote = make_sphere("GlowSpore", 0.03 * s, mats["glow"], 6, 4)
            parent_to(mote, head, tuple(c * s for c in loc))
    align_and_export(rig, path)


def noise3(x, y, z):
    return (
        math.sin(x * 3.1 + y * 1.7)
        + math.sin(y * 2.4 + z * 3.3)
        + math.sin(z * 2.8 + x * 1.3)
    ) / 3.0


def build_tree_round(path, blossom=False):
    reset_scene()
    mats = make_materials()
    rig = empty("Rig")
    trunk = make_cyl("Trunk", 0.16, 1.25, mats["clay"], segments=10, origin="base")
    for v in trunk.data.vertices:
        taper = 1.0 - 0.28 * (v.co.z / 1.25)
        v.co.x *= taper
        v.co.y *= taper
    prepare(trunk)
    paint(trunk, C("8a5a3a"), C("c4926a"), spots=[((0.05, 0.02, 0.4), 0.08, C("6e4630")), ((-0.04, -0.03, 0.8), 0.07, C("6e4630"))])
    parent_to(trunk, rig)
    cols = [C("6ea85a"), C("87bf68"), C("5d944c"), C("9ccc78"), C("78a85a")]
    if blossom:
        cols = [C("6ea85a"), C("f2b3c8"), C("87bf68"), C("f7c6d6"), C("78a85a")]
    parts = []
    spots_xyz = [(0, 0, 1.55, 0.62), (0.32, 0.1, 1.72, 0.42), (-0.28, -0.05, 1.62, 0.4), (0.05, -0.22, 1.48, 0.36), (0.1, 0.18, 1.9, 0.34)]
    for i, (x, y, z, r) in enumerate(spots_xyz):
        ball = make_ico("CanopyBit", r, mats["foliage"], 2)
        scale_verts(ball, 1.05, 0.95, 0.82)
        prepare(ball)
        paint(ball, cols[i], lighten(cols[i], 0.18))
        ball.location = (x, y, z)
        parts.append(ball)
    canopy = join_objects(parts, "Canopy")
    parent_keep(canopy, rig)
    align_and_export(rig, path)


def build_tree_pine(path):
    reset_scene()
    mats = make_materials()
    rig = empty("Rig")
    trunk = make_cyl("Trunk", 0.12, 0.7, mats["clay"], segments=8, origin="base")
    prepare(trunk)
    paint(trunk, C("7a5134"), C("b88862"))
    parent_to(trunk, rig)
    parts = []
    for i, (z, r, h, col) in enumerate(
        ((0.55, 0.62, 0.7, C("3f6b3a")), (0.95, 0.48, 0.6, C("4e7c46")), (1.32, 0.32, 0.5, C("6ea85a")))
    ):
        cone = make_cone("CanopyBit", r, h, mats["foliage"], segments=10, origin="base")
        paint(cone, col, tip=lighten(col, 0.2))
        cone.location = (0, 0, z)
        parts.append(cone)
    canopy = join_objects(parts, "Canopy")
    parent_keep(canopy, rig)
    align_and_export(rig, path)


def build_bush(path):
    reset_scene()
    mats = make_materials()
    rig = empty("Rig")
    parts = []
    for i, (x, y, z, r, col) in enumerate(
        ((0, 0, 0.28, 0.32, C("6ea85a")), (0.18, 0.06, 0.26, 0.22, C("87bf68")), (-0.16, -0.04, 0.24, 0.2, C("5d944c")))
    ):
        ball = make_ico("CanopyBit", r, mats["foliage"], 1)
        prepare(ball)
        paint(ball, col, lighten(col, 0.15))
        ball.location = (x, y, z)
        parts.append(ball)
    canopy = join_objects(parts, "Canopy")
    parent_keep(canopy, rig)
    align_and_export(rig, path)


def build_grass(path):
    reset_scene()
    mats = make_materials()
    rig = empty("Rig")
    parts = []
    for i in range(6):
        ang = i / 6 * math.tau
        blade = make_cone("Blade", 0.03, 0.28 + (i % 3) * 0.05, mats["foliage"], segments=4, origin="base")
        paint(blade, C("6ea85a"), tip=C("d5efa0"))
        blade.location = (math.cos(ang) * 0.06, math.sin(ang) * 0.06, 0)
        blade.rotation_euler = (0.25 * math.cos(ang), 0.25 * math.sin(ang), ang)
        parts.append(blade)
    clump = join_objects(parts, "Canopy")
    parent_keep(clump, rig)
    align_and_export(rig, path)


def build_mushroom(path, tall=False):
    reset_scene()
    mats = make_materials()
    rig = empty("Rig")
    stem_h = 0.55 if tall else 0.28
    stem = make_cyl("Stem", 0.07 if tall else 0.09, stem_h, mats["clay"], segments=10, origin="base")
    for v in stem.data.vertices:
        v.co.x *= 1.0 + 0.15 * math.sin(v.co.z * 8)
        v.co.y *= 1.0 + 0.15 * math.sin(v.co.z * 8)
    prepare(stem)
    paint(stem, C("f3e6cf"), C("fff8ee"))
    parent_to(stem, rig)
    cap = make_sphere("Cap", 0.22 if not tall else 0.18, mats["clay"], 18, 10)
    scale_verts(cap, 1.25, 1.25, 0.55)
    prepare(cap)
    paint(
        cap,
        C("e07a6a") if not tall else C("c45b6a"),
        C("f2b3a4"),
        spots=[((0.08, 0.04, 0.06), 0.05, C("fff6ea")), ((-0.07, -0.05, 0.05), 0.04, C("fff6ea")), ((0.02, -0.08, 0.07), 0.035, C("fff6ea"))],
    )
    parent_to(cap, rig, (0, 0, stem_h + 0.02))
    align_and_export(rig, path)


def build_rock(path, flat=False):
    reset_scene()
    mats = make_materials()
    rig = empty("Rig")
    rock = make_ico("Body", 0.45, mats["clay"], 2)
    for v in rock.data.vertices:
        n = noise3(v.co.x * 2.2, v.co.y * 2.2, v.co.z * 2.2)
        v.co *= 1.0 + n * 0.18
        if flat:
            v.co.z *= 0.45
        else:
            v.co.z *= 0.75
    prepare(rock)
    paint(rock, C("b7a898"), C("e6d8c8"), spots=[((0.1, 0.05, 0.1), 0.12, C("8d7b6c")), ((-0.12, -0.04, 0.02), 0.1, C("9a8878"))])
    parent_to(rock, rig)
    align_and_export(rig, path)


def build_lantern(path):
    reset_scene()
    mats = make_materials([C("ffc56b")])
    rig = empty("Rig")
    post = make_cyl("Post", 0.045, 1.15, mats["clay"], segments=8, origin="base")
    paint(post, C("8a5a3a"), C("c4926a"))
    parent_to(post, rig)
    base = make_ico("Base", 0.16, mats["clay"], 1)
    scale_verts(base, 1.2, 1.2, 0.55)
    prepare(base)
    paint(base, C("a89888"), C("d9cfc2"))
    parent_to(base, rig, (0, 0, 0.08))
    cap = make_cone("Cap", 0.16, 0.16, mats["clay"], segments=8, origin="base")
    paint(cap, C("a86a3c"), tip=C("e7b07a"))
    parent_to(cap, rig, (0, 0, 1.18))
    for i in range(4):
        ang = i * math.tau / 4
        bar = make_cyl("Bar", 0.012, 0.28, mats["clay"], segments=5, origin="base")
        paint(bar, C("6e4630"))
        parent_to(bar, rig, (math.cos(ang) * 0.09, math.sin(ang) * 0.09, 0.9))
    flame = make_sphere("GlowFlame", 0.07, mats["glow"], 8, 6)
    parent_to(flame, rig, (0, 0, 1.02))
    align_and_export(rig, path)


def build_flower(path, petal, center, leaf):
    reset_scene()
    mats = make_materials()
    rig = empty("Rig")
    stem = make_cyl("Stem", 0.018, 0.32, mats["foliage"], segments=6, origin="base")
    paint(stem, leaf, tip=lighten(leaf, 0.2))
    parent_to(stem, rig)
    add_flower(rig, mats, (0, 0, 0.34), 1.1, petal, center)
    leaf_m = add_leaf(rig, mats["foliage"], (0.02, 0, 0.14), (0.3, 0.6, 0.4), 0.12, leaf)
    align_and_export(rig, path)


def build_reed(path):
    reset_scene()
    mats = make_materials()
    rig = empty("Rig")
    parts = []
    for i, tilt in enumerate((-0.25, 0.05, 0.22)):
        reed = make_cyl("Blade", 0.02, 0.85, mats["foliage"], segments=5, origin="base")
        paint(reed, C("7d9a55"), tip=C("d5e2a4"))
        reed.location = (i * 0.05 - 0.05, 0, 0)
        reed.rotation_euler = (tilt, 0, tilt * 0.3)
        parts.append(reed)
    clump = join_objects(parts, "Canopy")
    parent_keep(clump, rig)
    align_and_export(rig, path)


def build_lily(path):
    reset_scene()
    mats = make_materials()
    rig = empty("Rig")
    pad = make_sphere("Pad", 0.28, mats["foliage"], 16, 8)
    scale_verts(pad, 1.0, 1.0, 0.08)
    # Notch.
    for v in pad.data.vertices:
        if v.co.y > 0.12 and abs(v.co.x) < 0.06:
            v.co.y *= 0.25
    prepare(pad)
    paint(pad, C("6ea85a"), C("d7f0a8"))
    parent_to(pad, rig, (0, 0, 0.02))
    add_flower(rig, mats, (0.08, -0.02, 0.06), 0.7, C("f2a0c0"), C("ffe08a"))
    align_and_export(rig, path)


def build_crystal(path):
    reset_scene()
    mats = make_materials([C("ffb15a")])
    rig = empty("Rig")
    shard = make_cone("GlowShard", 0.12, 0.55, mats["glow"], segments=5, origin="base")
    parent_to(shard, rig, (0, 0, 0), (0, 0, 0))
    shard2 = make_cone("GlowShardB", 0.07, 0.32, mats["glow"], segments=5, origin="base")
    parent_to(shard2, rig, (0.1, 0.02, 0), (0, 0.2, 0.4))
    align_and_export(rig, path)


def build_hill(path):
    reset_scene()
    mats = make_materials()
    rig = empty("Rig")
    hill = make_ico("Body", 1.4, mats["clay"], 2)
    for v in hill.data.vertices:
        v.co.z *= 0.55
        v.co.z += 0.2
        if v.co.z < 0.05:
            v.co.z = 0.05
        n = noise3(v.co.x, v.co.y, v.co.z)
        v.co.x *= 1 + n * 0.05
        v.co.y *= 1 + n * 0.05
    prepare(hill)
    paint(hill, C("7da35a"), C("c2b2a0"))
    parent_to(hill, rig)
    align_and_export(rig, path)


def build_stump(path):
    reset_scene()
    mats = make_materials()
    rig = empty("Rig")
    stump = make_cyl("Body", 0.28, 0.32, mats["clay"], segments=12, origin="base")
    prepare(stump)
    paint(stump, C("8a5a3a"), tip=C("e6c39a"))
    parent_to(stump, rig)
    ring = make_cyl("Ring", 0.30, 0.05, mats["clay"], segments=12, origin="base")
    paint(ring, C("6e4630"))
    parent_to(ring, rig, (0, 0, 0.30))
    align_and_export(rig, path)


def build_log(path):
    reset_scene()
    mats = make_materials()
    rig = empty("Rig")
    log = make_cyl("Body", 0.16, 0.9, mats["clay"], segments=12, origin="center")
    prepare(log)
    paint(log, C("8a5a3a"), C("d8b48a"))
    log.rotation_euler = (0, math.radians(90), 0)
    parent_to(log, rig, (0, 0, 0.16), (0, math.radians(90), 0))
    align_and_export(rig, path)


def build_cloud(path):
    reset_scene()
    mats = make_materials()
    rig = empty("Rig")
    parts = []
    for x, y, z, r in ((0, 0, 0, 0.55), (0.5, 0.05, 0.05, 0.4), (-0.48, -0.02, 0.02, 0.38), (0.2, -0.1, 0.08, 0.32), (-0.15, 0.12, 0.06, 0.28)):
        puff = make_ico("CloudBit", r, mats["cloud"], 1)
        puff.location = (x, y, z)
        parts.append(puff)
    cloud = join_objects(parts, "Cloud")
    parent_keep(cloud, rig)
    align_and_export(rig, path)


def build_vent(path):
    reset_scene()
    mats = make_materials([C("ff7a3c")])
    rig = empty("Rig")
    rocks = []
    for i in range(6):
        ang = i / 6 * math.tau
        rock = make_ico("RockBit", 0.16, mats["clay"], 1)
        scale_verts(rock, 1.0, 0.8, 0.7)
        prepare(rock)
        paint(rock, C("5a403c"), C("8a6458"))
        rock.location = (math.cos(ang) * 0.38, math.sin(ang) * 0.38, 0.08)
        rocks.append(rock)
    ring = join_objects(rocks, "Rocks")
    parent_keep(ring, rig)
    glow = make_sphere("GlowVent", 0.22, mats["glow"], 12, 8)
    scale_verts(glow, 1.0, 1.0, 0.28)
    parent_to(glow, rig, (0, 0, 0.06))
    align_and_export(rig, path)


def build_bridge(path):
    reset_scene()
    mats = make_materials()
    rig = empty("Rig")
    planks = []
    for i in range(8):
        y = -1.15 + i * 0.33
        arch = math.sin((i / 7) * math.pi) * 0.12
        plank = make_box("Plank", 1.15, 0.28, 0.08, mats["clay"])
        paint(plank, C("c4926a") if i % 2 == 0 else C("a86a3c"), C("e7c39a"))
        plank.location = (0, y, 0.18 + arch)
        planks.append(plank)
    deck = join_objects(planks, "Deck")
    parent_keep(deck, rig)
    for sign in (-1, 1):
        rail = make_box("Rail", 0.06, 2.5, 0.06, mats["clay"])
        paint(rail, C("8a5a3a"))
        parent_to(rail, rig, (0.52 * sign, 0, 0.42))
        for y in (-0.9, 0.9):
            post = make_cyl("Post", 0.05, 0.38, mats["clay"], segments=6, origin="base")
            paint(post, C("6e4630"))
            parent_to(post, rig, (0.52 * sign, y, 0.12))
    align_and_export(rig, path)


def build_den(path, burrow=False):
    reset_scene()
    mats = make_materials([C("ffc56b")])
    rig = empty("Rig")
    s = 0.72 if burrow else 1.0
    mound = make_sphere("Mound", 1.05 * s, mats["clay"], 32, 18)
    scale_verts(mound, 1.18, 1.0, 0.78)
    for v in mound.data.vertices:
        if v.co.z < 0.0:
            v.co.z = 0.0
        # Soft door indent on the front.
        if v.co.y > 0.35 * s and abs(v.co.x) < 0.32 * s and v.co.z < 0.55 * s:
            v.co.y -= 0.08 * s
    prepare(mound)
    paint(
        mound,
        C("c48a5a"),
        C("e7c39a"),
        spots=[((0.3, -0.2, 0.4), 0.18, C("7da35a")), ((-0.35, 0.1, 0.25), 0.16, C("6ea85a")), ((0.1, -0.4, 0.55), 0.14, C("8fbf6a"))],
    )
    parent_to(mound, rig, (0, 0, 0))
    skirt = make_sphere("MossSkirt", 0.95 * s, mats["foliage"], 18, 10)
    scale_verts(skirt, 1.35, 1.15, 0.22)
    prepare(skirt)
    paint(skirt, C("6ea85a"), C("b7d98a"))
    parent_to(skirt, rig, (0, 0, 0.05 * s))

    opening_r = 0.30 * s if burrow else 0.36 * s
    hole = make_sphere("Mouth", opening_r, mats["pupil"], 16, 10)
    scale_verts(hole, 1.0, 0.45, 1.0)
    parent_to(hole, rig, (0, 0.55 * s, 0.42 * s))
    trim = make_cyl("Trim", opening_r * 1.12, 0.08 * s, mats["clay"], segments=16, origin="center")
    paint(trim, C("a86a3c"), C("e7b07a"))
    parent_to(trim, rig, (0, 0.62 * s, 0.42 * s), (math.radians(90), 0, 0))

    if not burrow:
        for i, z in enumerate((0.08, 0.18)):
            step = make_box("Step", 0.7 - i * 0.12, 0.28, 0.1, mats["clay"])
            paint(step, C("b7a898"), C("e6d8c8"))
            parent_to(step, rig, (0, 0.85 + i * 0.18, z))
        chimney = make_cyl("Chimney", 0.12, 0.45, mats["clay"], segments=8, origin="base")
        paint(chimney, C("a89888"), C("d9cfc2"))
        parent_to(chimney, rig, (0.55, -0.25, 0.85))
        smoke = make_sphere("CloudSmoke", 0.1, mats["cloud"], 8, 6)
        parent_to(smoke, chimney, (0.04, 0, 0.5))
        window = make_sphere("GlowWindow", 0.1, mats["glow"], 10, 8)
        parent_to(window, rig, (-0.28, 0.48, 0.78))
    else:
        lintel = make_box("Lintel", 0.7, 0.1, 0.1, mats["clay"])
        paint(lintel, C("8a5a3a"))
        parent_to(lintel, rig, (0, 0.55 * s, 0.72 * s))

    pole = make_cyl("Pole", 0.025 * s, 0.7 * s, mats["clay"], segments=6, origin="base")
    paint(pole, C("6e4630"))
    parent_to(pole, rig, (-0.7 * s, -0.15 * s, 0.7 * s))
    flag = make_box("Flag", 0.34 * s, 0.02 * s, 0.22 * s, mats["flag"])
    parent_to(flag, pole, (0.18 * s, 0, 0.58 * s))
    add_flower(rig, mats, (0.75 * s, 0.35 * s, 0.05), 0.9, C("f2a0c0"), C("ffe08a"))
    add_flower(rig, mats, (-0.8 * s, 0.25 * s, 0.05), 0.75, C("ffd27a"), C("fff6ea"))
    align_and_export(rig, path)


def wanted_only():
    if "--" not in sys.argv:
        return None
    args = sys.argv[sys.argv.index("--") + 1 :]
    return args[0] if args else None


def run_job(key, fn):
    only = wanted_only()
    if only and only not in key:
        return
    print("building", key)
    fn()


def main():
    jobs = {
        "ember_base": lambda: build_dragon(
            os.path.join(OUT, "ember_base.glb"),
            dict(s=1.05, body=C("f27d3a"), belly=C("ffe1b0"), blush=C("ff8fa8"), iris=C("f2b84a"), wing_c=C("ffb07a"), horns=2, horn_len=0.16, wing=0.52, horn=C("ffe8c8"), horn_tip=C("fff6ea"), spade=C("ffe1b0")),
        ),
        "ember_lava": lambda: build_dragon(
            os.path.join(OUT, "ember_lava.glb"),
            dict(s=1.38, body=C("e23d22"), belly=C("ffb020"), blush=C("ff6a6a"), iris=C("ffe27a"), wing_c=C("ff7a3c"), horns=4, horn_len=0.28, wing=0.78, horn=C("ffd27a"), horn_tip=C("fff1c2"), spade=C("ff8a1e"), flame=True),
        ),
        "ember_water": lambda: build_dragon(
            os.path.join(OUT, "ember_water.glb"),
            dict(s=1.32, body=C("7ec8d4"), belly=C("e7f7f8"), blush=C("f2c1d8"), iris=C("d7c4f5"), wing_c=C("b7e4ea"), horns=2, horn_len=0.12, wing=0.7, horn=C("e7f0ff"), horn_tip=C("ffffff"), spade=C("d7e8ff"), mist=True),
        ),
        "pebble_base": lambda: build_otter(
            os.path.join(OUT, "pebble_base.glb"),
            dict(s=1.05, body=C("b5814f"), belly=C("f3d7b5"), blush=C("f2b3a8"), iris=C("6a422c"), tail=C("8d623c")),
        ),
        "pebble_water": lambda: build_otter(
            os.path.join(OUT, "pebble_water.glb"),
            dict(s=1.32, body=C("4aa3b8"), belly=C("d5f0f5"), blush=C("f2c1d2"), iris=C("1d4e6e"), tail=C("1d6e86"), fin=C("b9ecff")),
        ),
        "pebble_forest": lambda: build_otter(
            os.path.join(OUT, "pebble_forest.glb"),
            dict(s=1.30, body=C("7d9a4e"), belly=C("efe6c8"), blush=C("f2b3c4"), iris=C("3f6b3a"), tail=C("5d7a38"), moss=True),
        ),
        "juniper_base": lambda: build_fox(
            os.path.join(OUT, "juniper_base.glb"),
            dict(s=1.05, body=C("e07a3d"), belly=C("fff1dd"), blush=C("ff9aa8"), iris=C("d8a15a"), ear_tip=C("6e4630")),
        ),
        "juniper_forest": lambda: build_fox(
            os.path.join(OUT, "juniper_forest.glb"),
            dict(s=1.32, body=C("d4652f"), belly=C("f3e6cf"), blush=C("f2a0b0"), iris=C("6ea84a"), ear_tip=C("6ea84a"), thorn=True),
        ),
        "juniper_lava": lambda: build_fox(
            os.path.join(OUT, "juniper_lava.glb"),
            dict(s=1.32, body=C("c4482a"), belly=C("ffd0a8"), blush=C("ff8a7a"), iris=C("ffb347"), ear_tip=C("ffb347"), cinder=True),
        ),
        "bramble_base": lambda: build_hedgehog(
            os.path.join(OUT, "bramble_base.glb"),
            dict(s=1.02, body=C("8d6a45"), belly=C("f6e7cf"), blush=C("f2b3a8"), iris=C("5c3a2a"), quill=C("6b4a32"), quill_tip=C("c4a07a"), quill_count=16, quill_len=0.24),
        ),
        "bramble_forest": lambda: build_hedgehog(
            os.path.join(OUT, "bramble_forest.glb"),
            dict(s=1.36, body=C("6d5a40"), belly=C("efe6c8"), blush=C("e86b8a"), iris=C("3f6b3a"), quill=C("4e6a38"), quill_tip=C("d7e2a8"), quill_count=22, quill_len=0.34, briar=True),
        ),
        "bramble_lava": lambda: build_hedgehog(
            os.path.join(OUT, "bramble_lava.glb"),
            dict(s=1.34, body=C("5a463c"), belly=C("e7cbb0"), blush=C("ff8a6a"), iris=C("ffb347"), quill=C("3a2c28"), quill_tip=C("ff9a3c"), quill_count=20, quill_len=0.32, ember=True),
        ),
        "lumen_base": lambda: build_owl(
            os.path.join(OUT, "lumen_base.glb"),
            dict(s=1.05, body=C("f2e2c4"), belly=C("fff6ea"), iris=C("f2b84a"), beak=C("e0a15a"), wing_c=C("c9843a"), wing=0.7),
        ),
        "lumen_forest": lambda: build_owl(
            os.path.join(OUT, "lumen_forest.glb"),
            dict(s=1.32, body=C("dfe8c8"), belly=C("f7f3e2"), iris=C("6ea84a"), beak=C("c4926a"), wing_c=C("7da35a"), wing=0.86, grove=True),
        ),
        "lumen_water": lambda: build_owl(
            os.path.join(OUT, "lumen_water.glb"),
            dict(s=1.32, body=C("c5d0de"), belly=C("f4f7fb"), iris=C("6a7fbf"), beak=C("ffe27a"), wing_c=C("8aa0c8"), wing=0.92, storm=True),
        ),
        "pip_base": lambda: build_frog(
            os.path.join(OUT, "pip_base.glb"),
            dict(s=1.05, body=C("7fbf63"), belly=C("f3f0c8"), blush=C("f2a0b4"), iris=C("1d3a28")),
        ),
        "pip_water": lambda: build_frog(
            os.path.join(OUT, "pip_water.glb"),
            dict(s=1.32, body=C("6fbf8a"), belly=C("f7f3e2"), blush=C("f2a0c0"), iris=C("2a4a38"), lily=True),
        ),
        "pip_forest": lambda: build_frog(
            os.path.join(OUT, "pip_forest.glb"),
            dict(s=1.30, body=C("8b6bb5"), belly=C("f3e6ff"), blush=C("e7a0c4"), iris=C("2a1c38"), spots=C("5c3d78"), spore=True),
        ),
        "tree_round": lambda: build_tree_round(os.path.join(OUT, "tree_round.glb"), False),
        "tree_blossom": lambda: build_tree_round(os.path.join(OUT, "tree_blossom.glb"), True),
        "tree_pine": lambda: build_tree_pine(os.path.join(OUT, "tree_pine.glb")),
        "bush": lambda: build_bush(os.path.join(OUT, "bush.glb")),
        "grass": lambda: build_grass(os.path.join(OUT, "grass.glb")),
        "mushroom": lambda: build_mushroom(os.path.join(OUT, "mushroom.glb"), False),
        "mushroom_tall": lambda: build_mushroom(os.path.join(OUT, "mushroom_tall.glb"), True),
        "rock": lambda: build_rock(os.path.join(OUT, "rock.glb"), False),
        "rock_flat": lambda: build_rock(os.path.join(OUT, "rock_flat.glb"), True),
        "lantern": lambda: build_lantern(os.path.join(OUT, "lantern.glb")),
        "flower_warm": lambda: build_flower(os.path.join(OUT, "flower_warm.glb"), C("f2a0c0"), C("ffe08a"), C("6ea85a")),
        "flower_cool": lambda: build_flower(os.path.join(OUT, "flower_cool.glb"), C("b7d4f2"), C("fff6ea"), C("5d8a72")),
        "reed": lambda: build_reed(os.path.join(OUT, "reed.glb")),
        "lily": lambda: build_lily(os.path.join(OUT, "lily.glb")),
        "crystal": lambda: build_crystal(os.path.join(OUT, "crystal.glb")),
        "hill": lambda: build_hill(os.path.join(OUT, "hill.glb")),
        "stump": lambda: build_stump(os.path.join(OUT, "stump.glb")),
        "log": lambda: build_log(os.path.join(OUT, "log.glb")),
        "cloud": lambda: build_cloud(os.path.join(OUT, "cloud.glb")),
        "vent": lambda: build_vent(os.path.join(OUT, "vent.glb")),
        "bridge": lambda: build_bridge(os.path.join(OUT, "bridge.glb")),
        "den": lambda: build_den(os.path.join(OUT, "den.glb"), False),
        "burrow": lambda: build_den(os.path.join(OUT, "burrow.glb"), True),
    }
    for key, fn in jobs.items():
        run_job(key, fn)
    print("done", len(os.listdir(OUT)), "files")


if __name__ == "__main__":
    main()
