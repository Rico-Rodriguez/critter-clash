# Shared helpers for the Blender-made pets (run with Blender's Python, `bpy`).
# Each pet script builds its parts from code, rigs them to a small skeleton,
# keys its clips, bakes the flat colours into one texture and writes a .glb.
# Style: the heroes' (KayKit) look at real proportions: soft low-poly forms,
# flat colours, two tones per surface (darker back, lighter belly).
import bpy, bmesh, math
from mathutils import Vector, Matrix, Quaternion

parts = []      # [object, [bone names it may weigh on]]


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    parts.clear()


def srgb(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


def mat(name, hexcol, rough=0.75, emit=None):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*srgb(hexcol), 1)
    b.inputs["Roughness"].default_value = rough
    m["hex"] = hexcol
    m["emit"] = emit or ""
    return m


# Angular style, to sit beside the dark plate heroes: flat-shaded facets, tubes
# with fewer sides (SIDES of what the script asks) and no subdivision, blobs
# subdivided at most BLOB_SUB times, and tube rings with a corner on top and
# bottom so bodies get a ridge and a keel.
HARD = True
SIDES = 0.6
BLOB_SUB = 1


def _ring(n, rx, rz):
    ph = math.pi / 2 if HARD else 0.0
    return [(math.cos(ph + 2 * math.pi * i / n) * rx, math.sin(ph + 2 * math.pi * i / n) * rz) for i in range(n)]


def tube(name, path, m, n=10, sub=1, cap0=True, cap1=True):
    """A soft tube along `path`: [(point, rx, rz), ...]. Rings sit square to
    the path; rx is sideways (world X), rz the other way."""
    if HARD:
        n, sub = max(3, round(n * SIDES)), 0
    bm = bmesh.new()
    rings = []
    pts = [Vector(p) for p, _, _ in path]
    for i, (p, rx, rz) in enumerate(path):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        side = Vector((1, 0, 0))
        up = t.cross(side).normalized()
        if up.length < 0.1:
            up = Vector((0, 0, 1))
        side = up.cross(t).normalized()
        ring = []
        for (a, b) in _ring(n, max(rx, 0.002), max(rz, 0.002)):
            ring.append(bm.verts.new(Vector(p) + side * a + up * b))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    if cap0:
        bm.faces.new(list(reversed(rings[0])))
    if cap1:
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return _obj(name, bm, m, sub)


def blob(name, at, size, m, sub=2, rot=(0, 0, 0)):
    if HARD:
        sub = min(sub, BLOB_SUB)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    o = _obj(name, bm, m, sub)
    o.location = at
    o.rotation_euler = rot
    return o


def cone(name, base, tip, r, m, n=6, bend=None):
    """A horn or claw from `base` to `tip`, bent toward `bend` halfway."""
    base, tip = Vector(base), Vector(tip)
    mid = (base + tip) / 2 + (Vector(bend) if bend else Vector())
    path = []
    for i in range(5):
        t = i / 4
        p = (1 - t) ** 2 * base + 2 * (1 - t) * t * mid + t * t * tip
        rr = r * (1 - t) + 0.004
        path.append((p, rr, rr))
    return tube(name, path, m, n=n, sub=0, cap0=True, cap1=True)


def sheet(name, pts, m, thick=0.02):
    """A flat membrane through `pts` (a fan from pts[0]), given a thickness."""
    bm = bmesh.new()
    vs = [bm.verts.new(Vector(p)) for p in pts]
    for i in range(1, len(vs) - 1):
        bm.faces.new((vs[0], vs[i], vs[i + 1]))
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=thick)
    return _obj(name, bm, m, 0, smooth=False)


def _obj(name, bm, m, sub, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.append(m)
    if HARD:
        smooth = False
    if sub:
        md = o.modifiers.new("s", "SUBSURF")
        md.levels = sub
        md.render_levels = sub
    for p in me.polygons:
        p.use_smooth = smooth
    return o


def mirror_x(o, name):
    c = o.copy()
    c.data = o.data.copy()
    c.name = name
    bpy.context.scene.collection.objects.link(c)
    c.scale.x *= -1
    c.location.x *= -1
    return c


def two_tone(o, under, over=None, down=-0.35, up=0.65, front=None):
    """Belly faces (normal pointing down) take `under`; back faces `over`."""
    _apply(o)
    me = o.data
    for mm in (under, over):
        if mm and mm.name not in [x.name for x in me.materials]:
            me.materials.append(mm)
    idx = {x.name: i for i, x in enumerate(me.materials)}
    for p in me.polygons:
        if p.normal.z < down and (front is None or p.center.y < front):
            p.material_index = idx[under.name]
        elif over and p.normal.z > up:
            p.material_index = idx[over.name]


def _apply(o):
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    for md in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)
    flipped = o.matrix_world.determinant() < 0
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if flipped:
        # A mirrored copy turns inside out once its scale is applied.
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
        bm.to_mesh(o.data)
        bm.free()
    o.select_set(False)


def bind(o, bones):
    """Mark `o` to be skinned to `bones` (weights by distance to each bone)."""
    parts.append([o, bones])
    return o


# --- Skeleton ---------------------------------------------------------------

def armature(spec):
    """spec: [(name, head, tail, parent or None)]. Returns the armature object."""
    arm = bpy.data.armatures.new("Rig")
    ob = bpy.data.objects.new("Rig", arm)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for name, h, t, par in spec:
        b = arm.edit_bones.new(name)
        b.head = h
        b.tail = t
        b.roll = 0.0
        if par:
            b.parent = arm.edit_bones[par]
            b.use_connect = (Vector(arm.edit_bones[par].tail) - Vector(h)).length < 1e-4
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def _seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (a + ab * t - p).length


def skin(rig, name):
    """Joins every bound part into one mesh skinned to `rig`. Each vertex
    weighs on its part's two nearest bones, so joints bend softly."""
    bones = {b.name: (rig.matrix_world @ b.head_local, rig.matrix_world @ b.tail_local) for b in rig.data.bones}
    for o, allowed in parts:
        _apply(o)
        for bn in allowed:
            if bn not in o.vertex_groups:
                o.vertex_groups.new(name=bn)
        for v in o.data.vertices:
            p = o.matrix_world @ v.co
            ds = sorted((_seg_dist(p, *bones[bn]), bn) for bn in allowed)
            if len(ds) == 1 or ds[1][0] > ds[0][0] * 2.5 + 0.03:
                o.vertex_groups[ds[0][1]].add([v.index], 1.0, "REPLACE")
                continue
            w0 = 1.0 / max(ds[0][0], 0.01)
            w1 = 1.0 / max(ds[1][0], 0.01)
            o.vertex_groups[ds[0][1]].add([v.index], w0 / (w0 + w1), "REPLACE")
            o.vertex_groups[ds[1][1]].add([v.index], w1 / (w0 + w1), "REPLACE")
    bpy.ops.object.select_all(action="DESELECT")
    for o, _ in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0][0]
    bpy.ops.object.join()
    body = bpy.context.object
    body.name = name
    body.data.name = name
    # Merge doubled materials (mirror copies share them already).
    md = body.modifiers.new("Armature", "ARMATURE")
    md.object = rig
    body.parent = rig
    return body


# --- One texture --------------------------------------------------------------

def bake(body, size, out_png, ash=None):
    """Unwraps `body`, paints each material's flat colour into one texture and
    gives the mesh a single textured material (the skin shader's patterns run
    in this UV space). `ash`: {material name: hex} for a second, recoloured
    texture (and its ember emission map) written next to `out_png`."""
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.01)
    bpy.ops.object.mode_set(mode="OBJECT")
    img = _paint(body, size, lambda m: m["hex"])
    _save(img, out_png)
    if ash:
        _save(_paint(body, size, lambda m: ash.get(m.name, ash["*"])), out_png.replace(".png", "_ash.png"))
        _save(_paint(body, size, lambda m: ash.get("emit:" + m.name, "000000")), out_png.replace(".png", "_ash_emit.png"))
    one = bpy.data.materials.new(body.name)
    one.use_nodes = True
    nt = one.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Linear"
    b = nt.nodes["Principled BSDF"]
    nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.8
    one.use_backface_culling = False
    body.data.materials.clear()
    body.data.materials.append(one)
    for p in body.data.polygons:
        p.material_index = 0


def _paint(body, size, colour):
    """Fills every face's UV island with its material's colour (no render
    bake needed: the colours are flat)."""
    import array
    px = array.array("f", [0.0] * (size * size * 4))
    uv = body.data.uv_layers.active.data
    mats = body.data.materials
    for p in body.data.polygons:
        h = colour(mats[p.material_index])
        # Byte images hold sRGB, so the hex goes in as it is.
        col = tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
        pts = [uv[li].uv * size for li in p.loop_indices]
        for i in range(1, len(pts) - 1):
            _tri(px, size, pts[0], pts[i], pts[i + 1], col)
    img = bpy.data.images.new("tex", size, size, alpha=False)
    img.pixels.foreach_set(px)
    # Bleed colours past island edges so filtering never pulls in black.
    for _ in range(6):
        _dilate(img, size)
    return img


def _tri(px, size, a, b, c, col):
    pad = 1.5
    x0 = max(int(min(a.x, b.x, c.x) - pad), 0)
    x1 = min(int(max(a.x, b.x, c.x) + pad) + 1, size)
    y0 = max(int(min(a.y, b.y, c.y) - pad), 0)
    y1 = min(int(max(a.y, b.y, c.y) + pad) + 1, size)
    d = (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
    if abs(d) < 1e-9:
        return
    e = 1.2 / max(abs(d), 1e-9) ** 0.5
    for y in range(y0, y1):
        for x in range(x0, x1):
            l1 = ((b.y - c.y) * (x + 0.5 - c.x) + (c.x - b.x) * (y + 0.5 - c.y)) / d
            l2 = ((c.y - a.y) * (x + 0.5 - c.x) + (a.x - c.x) * (y + 0.5 - c.y)) / d
            if l1 >= -e and l2 >= -e and 1 - l1 - l2 >= -e:
                i = (y * size + x) * 4
                px[i], px[i + 1], px[i + 2], px[i + 3] = col[0], col[1], col[2], 1.0


def _dilate(img, size):
    import array
    px = array.array("f", img.pixels[:])
    out = array.array("f", px)
    for y in range(size):
        for x in range(size):
            i = (y * size + x) * 4
            if px[i + 3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < size and 0 <= yy < size:
                    j = (yy * size + xx) * 4
                    if px[j + 3] > 0:
                        out[i:i + 4] = px[j:j + 4]
                        break
    img.pixels.foreach_set(out)


def _save(img, path):
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()


# --- Clips --------------------------------------------------------------------

def clip(rig, name, length, keys, loop=True):
    """keys: {bone: [(time, (ax, ay, az) degrees about armature axes, (dx, dy, dz) or None)]}.
    Rotations are given in armature space and converted to each bone's own."""
    act = bpy.data.actions.new(name)
    rig.animation_data_create()
    rig.animation_data.action = act
    fps = 30
    bpy.context.scene.render.fps = fps
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
    for bn, ks in keys.items():
        pb = rig.pose.bones[bn]
        rest = pb.bone.matrix_local.to_3x3()
        for t, rot, loc in ks:
            q = Matrix.Identity(3)
            for axis, deg in zip("XYZ", rot):
                if deg:
                    q = Matrix.Rotation(math.radians(deg), 3, axis) @ q
            local = (rest.inverted() @ q @ rest).to_quaternion()
            pb.rotation_quaternion = local
            f = 1 + round(t * fps)
            pb.keyframe_insert("rotation_quaternion", frame=f)
            if loc is not None:
                pb.location = rest.inverted() @ Vector(loc)
                pb.keyframe_insert("location", frame=f)
    act.use_fake_user = True
    act.frame_range = (1, 1 + round(length * fps))
    # Smooth, looping curves.
    for fc in _fcurves(act):
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"
    for pb in rig.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    rig.animation_data.action = None
    return act


def _fcurves(act):
    if hasattr(act, "fcurves") and len(getattr(act, "fcurves", [])):
        return act.fcurves
    out = []
    for layer in getattr(act, "layers", []):
        for strip in layer.strips:
            for bag in strip.channelbags:
                out.extend(bag.fcurves)
    return out


def export(rig, body, path):
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
        export_animation_mode="ACTIONS", export_force_sampling=True, export_image_format="AUTO",
        export_apply=False, export_yup=True)
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print("PET", path, "tris", tris, "bones", len(rig.data.bones))
