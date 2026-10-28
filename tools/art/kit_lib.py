"""Shared builder for the zone prop kits (Rimehollow, Cinder Mire, Long Road rooms).

A kit is one glb of named, static, origin-at-the-feet meshes that share ONE palette texture
(a 256 px image of 8 px colour cells; each face's UVs sit on one cell centre, so the mesh is
flat-coloured, NEAREST-sampled and needs no vertex colours, which Godot 4.7's glTF import ignores).
Faces carry a material slot: 0 matte, 1 ice (glossy), 2 crystal (glossy plus a faint emission).
All geometry is written in Godot axes (x right, y up, +z toward the camera) and turned into
Blender's z-up on the way in, so `export_yup` hands it back unchanged.

Used from a builder: tools/art/blender.sh tools/art/make_rime_kit.py
"""
import bpy, bmesh, math, os, random, tempfile
from mathutils import Vector, Matrix, noise

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LEVELS = 63           # sRGB steps per channel when a face colour is quantised into the palette
CELL, GRID = 8, 32    # 8 px cells, 32 x 32 of them: up to 1024 colours, a 256 px texture
MATTE, ICE, CRYSTAL = 0, 1, 2
SLOTS = {}   # object name -> the material slots (0..2) its faces use, in order


def hexc(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (1, 3, 5))


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def shade(c, k):
    return tuple(max(0.0, min(1.0, v * k)) for v in c)


def ramp(stops, t):
    """Colour along a list of hex or rgb stops, t in 0..1, snapped to 12 steps so the palette stays small."""
    t = round(max(0.0, min(1.0, t)) * 12) / 12
    cs = [hexc(s) if isinstance(s, str) else s for s in stops]
    x = t * (len(cs) - 1)
    i = min(int(x), len(cs) - 2)
    return mix(cs[i], cs[i + 1], x - i)


def g2b(p):
    """Godot-axes point -> Blender."""
    return Vector((p[0], -p[2], p[1]))


def b2g(p):
    return Vector((p[0], p[2], -p[1]))


def n3(p, seed=0.0, f=1.0):
    """Deterministic smooth noise in about -1..1."""
    return noise.noise(Vector((p[0] * f + seed * 17.3, p[1] * f + seed * 5.1, p[2] * f + seed * 9.7)))


class Palette:
    def __init__(self, name):
        self.name = name
        self.cells = {}

    def uv(self, rgb):
        key = tuple(round(max(0.0, min(1.0, rgb[i])) * LEVELS) for i in range(3))
        i = self.cells.setdefault(key, len(self.cells))
        assert i < GRID * GRID, "palette overflow"
        size = GRID * CELL
        return (((i % GRID) * CELL + CELL / 2) / size, 1.0 - ((i // GRID) * CELL + CELL / 2) / size)

    def image(self):
        size = GRID * CELL
        px = [0.0] * (size * size * 4)
        for key, i in self.cells.items():
            rgb = [k / LEVELS for k in key]
            for y in range((i // GRID) * CELL, (i // GRID + 1) * CELL):
                for x in range((i % GRID) * CELL, (i % GRID + 1) * CELL):
                    o = ((size - 1 - y) * size + x) * 4   # Blender images start at the bottom row
                    px[o:o + 4] = [rgb[0], rgb[1], rgb[2], 1.0]
        img = bpy.data.images.new(self.name + "_palette", size, size)
        img.pixels = px
        img.filepath_raw = os.path.join(tempfile.gettempdir(), self.name + "_palette.png")
        img.file_format = 'PNG'
        img.save()
        img.pack()
        return img


def make_materials(img, kit):
    """The three glTF materials, all on the one palette image."""
    out = []
    for name, rough, emit in ((kit + "_matte", 0.86, 0.0), (kit + "_ice", 0.1, 0.0), (kit + "_crystal", 0.1, 0.3)):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        m.use_backface_culling = False
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.interpolation = 'Closest'
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = 0.0
        if emit > 0.0:
            nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = emit
        out.append(m)
    return out


class Part:
    """One mesh. Build with the helpers (Godot axes), then `paint(fn)` colours every face."""

    def __init__(self, name, seed=1):
        self.name = name
        self.bm = bmesh.new()
        self.tag = self.bm.faces.layers.int.new("tag")
        self.mat = self.bm.faces.layers.int.new("mat")
        self.cur_tag = 1
        self.cur_mat = MATTE
        self.rng = random.Random(seed)
        self.seed = seed

    # -- low level ------------------------------------------------------------
    def v(self, x, y=None, z=None):
        p = x if y is None else (x, y, z)
        return self.bm.verts.new(g2b(p))

    def face(self, vs, tag=None, mat=None):
        try:
            f = self.bm.faces.new(vs)
        except ValueError:
            return None
        f[self.tag] = self.cur_tag if tag is None else tag
        f[self.mat] = self.cur_mat if mat is None else mat
        return f

    def use(self, tag=None, mat=None):
        if tag is not None:
            self.cur_tag = tag
        if mat is not None:
            self.cur_mat = mat

    def quad(self, a, b, c, d, **kw):
        return self.face([a, b, c, d], **kw)

    def tri(self, a, b, c, **kw):
        return self.face([a, b, c], **kw)

    # -- shapes ---------------------------------------------------------------
    def loft(self, rings, cap_lo=False, cap_hi=False, **kw):
        """Quads between consecutive rings (lists of verts, same length, counter-clockwise from above)."""
        n = len(rings[0])
        for r in range(len(rings) - 1):
            for k in range(n):
                j = (k + 1) % n
                self.quad(rings[r][k], rings[r][j], rings[r + 1][j], rings[r + 1][k], **kw)
        if cap_lo:
            self.face(list(reversed(rings[0])), **kw)
        if cap_hi:
            self.face(list(rings[-1]), **kw)

    def ring(self, n, r, y, off=(0.0, 0.0), phase=0.0, jit=0.0, yjit=0.0, sx=1.0, sz=1.0):
        out = []
        for i in range(n):
            a = phase + math.tau * i / n
            rr = r * (1.0 + self.rng.uniform(-jit, jit))
            out.append(self.v(off[0] + math.cos(a) * rr * sx, y + self.rng.uniform(-yjit, yjit), off[1] + math.sin(a) * rr * sz))
        return out

    def box(self, c, size, yaw=0.0, tilt=(0.0, 0.0), taper=1.0, **kw):
        """A box centred at c (Godot axes) with full `size`; `taper` scales the top face; tilt = (about x, about z)."""
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        rot = Matrix.Rotation(yaw, 3, 'Y') @ Matrix.Rotation(tilt[0], 3, 'X') @ Matrix.Rotation(tilt[1], 3, 'Z')
        pts = []
        for yy in (-hy, hy):
            k = taper if yy > 0 else 1.0
            for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                pts.append(self.v(Vector(c) + rot @ Vector((sx * hx * k, yy, sz * hz * k))))
        lo, hi = pts[:4], pts[4:]
        self.face(list(reversed(lo)), **kw)
        self.face(hi, **kw)
        for k in range(4):
            j = (k + 1) % 4
            self.quad(lo[k], lo[j], hi[j], hi[k], **kw)
        return pts

    def limb(self, a, b, ra, rb, sides=5, **kw):
        """A tapered prism from a to b (Godot axes): a pile, a branch, a spar."""
        a, b = Vector(a), Vector(b)
        ax = (b - a).normalized()
        s = ax.cross(Vector((0, 1, 0)) if abs(ax.y) < 0.95 else Vector((1, 0, 0))).normalized()
        f = ax.cross(s)
        lo, hi = [], []
        for i in range(sides):
            ang = math.tau * i / sides + 0.3
            d = s * math.cos(ang) + f * math.sin(ang)
            lo.append(self.v(a + d * ra))
            hi.append(self.v(b + d * rb))
        for i in range(sides):
            j = (i + 1) % sides
            self.quad(lo[i], lo[j], hi[j], hi[i], **kw)
        self.face(hi, **kw)
        return lo, hi

    def crystal(self, base, axis, length, radius, sides=6, shoulder=0.64, twist=0.0, **kw):
        """A six-sided crystal: a short tapered root, a shoulder, a point."""
        t = Vector(axis).normalized()
        a = Vector((0, 1, 0)) if abs(t.y) < 0.9 else Vector((1, 0, 0))
        u = t.cross(a).normalized()
        w = t.cross(u).normalized()
        base = Vector(base)

        def ring(h, r, off):
            return [self.v(base + t * h + (u * math.cos(k * math.tau / sides + off) + w * math.sin(k * math.tau / sides + off)) * r) for k in range(sides)]
        r0 = ring(0.0, radius * 0.72, twist)
        r1 = ring(length * shoulder, radius, twist + 0.12)
        tip = self.v(base + t * length + u * radius * 0.1)
        for k in range(sides):
            n = (k + 1) % sides
            self.quad(r0[k], r0[n], r1[n], r1[k], **kw)
            self.tri(r1[k], r1[n], tip, **kw)
        self.face(list(reversed(r0)), **kw)

    def lump(self, c, radii, subdiv=1, warp=0.2, seed=0.0, flat=0.0, **kw):
        """A lumpy icosphere (boulder, snow drift), with the bottom cut flat at y = c.y - flat*radii.y if flat > 0."""
        c = Vector(c)
        geo = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=1.0)["verts"]
        for vt in geo:
            d = b2g(vt.co).normalized()
            k = 1.0 + warp * n3(d * 1.9, seed + self.seed)
            p = Vector((d.x * radii[0] * k, d.y * radii[1] * k, d.z * radii[2] * k))
            if flat > 0.0:
                p.y = max(p.y, -radii[1] * flat)
            vt.co = g2b(p + c)
        for f in set(f for vt in geo for f in vt.link_faces):
            f[self.tag] = self.cur_tag if kw.get("tag") is None else kw["tag"]
            f[self.mat] = self.cur_mat if kw.get("mat") is None else kw["mat"]
        return geo

    def move(self, since, offset=(0, 0, 0), yaw=0.0, scale=1.0, pivot=(0, 0, 0)):
        """Transforms the verts made since `since` (a count from `mark()`)."""
        vs = list(self.bm.verts)[since:]
        rot = Matrix.Rotation(yaw, 3, 'Y')
        for vt in vs:
            p = (rot @ (b2g(vt.co) - Vector(pivot))) * scale + Vector(pivot) + Vector(offset)
            vt.co = g2b(p)

    def mark(self):
        return len(self.bm.verts)

    def sink(self, y0):
        """Pushes everything below y0 up to y0 (a flat foot)."""
        for vt in self.bm.verts:
            g = b2g(vt.co)
            if g.y < y0:
                vt.co = g2b((g.x, y0, g.z))

    # -- colour ---------------------------------------------------------------
    def paint(self, fn, pal):
        """fn(tag, centre (Godot axes), normal (Godot axes), face index) -> rgb. Returns a Blender object."""
        bmesh.ops.recalc_face_normals(self.bm, faces=list(self.bm.faces)) if getattr(self, "closed", False) else None
        self.bm.normal_update()
        me = bpy.data.meshes.new(self.name)
        cols = []
        for i, f in enumerate(self.bm.faces):
            cols.append(fn(f[self.tag], b2g(f.calc_center_median()), b2g(f.normal), i))
        mats = [f[self.mat] for f in self.bm.faces]
        self.bm.to_mesh(me)
        self.bm.free()
        uv = me.uv_layers.new(name="UV0")
        used = sorted(set(mats))
        for p in me.polygons:
            p.use_smooth = False
            p.material_index = used.index(mats[p.index])
            u, v = pal.uv(cols[p.index])
            for li in p.loop_indices:
                uv.data[li].uv = (u, v)
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.collection.objects.link(ob)
        SLOTS[self.name] = used
        return ob


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    SLOTS.clear()


def export(kit, objs, pal, out_path):
    """One palette image, three materials, every object on the slots it used; writes the glb."""
    img = pal.image()
    mats = make_materials(img, kit)
    for ob in objs:
        for m in SLOTS[ob.name]:
            ob.data.materials.append(mats[m])
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objs:
        ob.select_set(True)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=out_path, export_format='GLB', use_selection=True, export_animations=False,
                              export_yup=True, export_vertex_color='NONE', export_apply=False)
    tris = {ob.name: sum(len(p.vertices) - 2 for p in ob.data.polygons) for ob in objs}
    print("WROTE", out_path, "colours", len(pal.cells), "tris", sum(tris.values()))
    for k, v in tris.items():
        print("  ", k, v)
    return tris
