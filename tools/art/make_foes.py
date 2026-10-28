"""Custom foes for the biome rebuild that no CC0/CC BY model covers in tone: the
Crystal Shardling (rh_shard), the Methane Bloat (cm_bloat) and the Sporecap (cm_spore).
Static meshes with one PBR material whose base colour is a palette texture (the painted vertex
colours are quantised into 8x8 px cells; UVs point at the cell centres); the game animates them
with FoeRig's generated clips ("proc:" foes). Nodes named Orbit* turn once per idle loop.
Run: tools/art/blender.sh tools/art/make_foes.py [shard bloat spore]
Writes assets/foes/<name>_src.glb. Deterministic (fixed noise offsets, no random)."""
import bpy, bmesh, math, os, sys, tempfile
from mathutils import Vector, Matrix, noise

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "foes")


def lin(h):
    """Hex colour -> rgb floats. Byte-colour layers take sRGB values; the palette bake reads them back."""
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (1, 3, 5))


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


class Part:
    """A bmesh with a colour layer; `col(v)` paints each new vertex."""
    def __init__(self):
        self.bm = bmesh.new()
        self.lay = self.bm.loops.layers.color.new("Col")

    def paint(self, verts, fn):
        for v in verts:
            c = fn(v.co)
            for f in v.link_faces:
                for l in f.loops:
                    if l.vert == v:
                        l[self.lay] = (c[0], c[1], c[2], 1.0)

    def ring_tube(self, pts, radii, sides, fn):
        """A closed-end tube along `pts` with a radius per point (no caps at the root)."""
        rings = []
        for i, p in enumerate(pts):
            t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
            a = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            u = t.cross(a).normalized(); w = t.cross(u).normalized()
            rings.append([self.bm.verts.new(p + (u * math.cos(k * math.tau / sides) + w * math.sin(k * math.tau / sides)) * radii[i]) for k in range(sides)])
        tip = self.bm.verts.new(pts[-1] + (pts[-1] - pts[-2]).normalized() * radii[-2] * 0.6)
        for r in range(len(rings) - 1):
            for k in range(sides):
                self.bm.faces.new((rings[r][k], rings[r][(k + 1) % sides], rings[r + 1][(k + 1) % sides], rings[r + 1][k]))
        for k in range(sides):
            self.bm.faces.new((rings[-1][k], rings[-1][(k + 1) % sides], tip))
        self.bm.faces.new(list(reversed(rings[0])))
        self.paint([v for r in rings for v in r] + [tip], fn)

    def blob(self, centre, size, subdiv, warp, fn, seed=0.0):
        """A lumpy icosphere: `size` = (rx, ry, rz); `warp` lump amplitude."""
        geo = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=1.0)["verts"]
        for v in geo:
            d = v.co.normalized()
            n = noise.noise(d * 1.7 + Vector((seed, seed * 0.7, seed * 1.3)))
            k = 1.0 + warp * n
            v.co = Vector((d.x * size[0] * k, d.y * size[1] * k, d.z * size[2] * k)) + centre
        self.paint(geo, fn)
        return geo

    def crystal(self, base, axis, length, radius, fn, sides=6, shoulder=0.62, twist=0.0):
        t = axis.normalized()
        a = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
        u = t.cross(a).normalized(); w = t.cross(u).normalized()
        def ring(h, r, off):
            return [self.bm.verts.new(base + t * h + (u * math.cos(k * math.tau / sides + off) + w * math.sin(k * math.tau / sides + off)) * r) for k in range(sides)]
        r0 = ring(0.0, radius * 0.7, twist); r1 = ring(length * shoulder, radius, twist + 0.1)
        tip = self.bm.verts.new(base + t * length + u * radius * 0.08)
        for k in range(sides):
            n = (k + 1) % sides
            self.bm.faces.new((r0[k], r0[n], r1[n], r1[k]))
            self.bm.faces.new((r1[k], r1[n], tip))
        self.bm.faces.new(list(reversed(r0)))
        self.paint(r0 + r1 + [tip], lambda c: fn((c - base).dot(t) / length))

    def build(self, name, smooth):
        me = bpy.data.meshes.new(name)
        self.bm.normal_update()
        self.bm.to_mesh(me); self.bm.free()
        for p in me.polygons:
            p.use_smooth = smooth
        ob = bpy.data.objects.new(name, me)
        bpy.context.collection.objects.link(ob)
        return ob


LEVELS = 14   # sRGB steps per channel when the painted colours are quantised into the palette
CELL, GRID = 8, 32   # 8 px cells, 32 x 32 of them: at most 1024 colours, a 256 px texture


def to_srgb8(v):
    v = max(0.0, min(1.0, v))
    return (v * 12.92 if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055)


def bake_palette(objs, name):
    """Turns each object's "Col" loop colours into UVs on one shared palette image; returns the material."""
    cells = {}
    for o in objs:
        me = o.data
        uv = me.uv_layers.new(name="UV0")
        col = me.color_attributes["Col"]
        for lp in me.loops:
            c = col.data[lp.index].color
            key = tuple(round(to_srgb8(c[i]) * LEVELS) for i in range(3))
            cells.setdefault(key, len(cells))
            i = cells[key]
            assert i < GRID * GRID, "too many colours"
            uv.data[lp.index].uv = (((i % GRID) * CELL + CELL / 2) / (GRID * CELL), ((i // GRID) * CELL + CELL / 2) / (GRID * CELL))
        me.color_attributes.remove(col)
    size = GRID * CELL
    px = [0.0] * (size * size * 4)
    for key, i in cells.items():
        rgb = [k / LEVELS for k in key]   # a byte image takes sRGB values as they are
        for y in range((i // GRID) * CELL, (i // GRID + 1) * CELL):
            for x in range((i % GRID) * CELL, (i % GRID + 1) * CELL):
                o = (y * size + x) * 4
                px[o:o + 4] = [rgb[0], rgb[1], rgb[2], 1.0]
    img = bpy.data.images.new(name + "_palette", size, size)
    img.pixels = px
    img.filepath_raw = os.path.join(tempfile.gettempdir(), name + "_palette.png")
    img.file_format = 'PNG'
    img.save()
    img.pack()
    m = bpy.data.materials.new("foe")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = img; tex.interpolation = 'Closest'
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.62
    bsdf.inputs["Metallic"].default_value = 0.0
    print(name, "palette colours", len(cells))
    return m


def finish(name, objs):
    mat = bake_palette(objs, name)
    for o in objs:
        o.data.materials.append(mat)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    path = os.path.join(OUT, name + "_src.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_animations=False,
                              export_yup=True, export_vertex_color='NONE')
    print("WROTE", path, "polys", sum(len(o.data.polygons) for o in objs))


# -- Crystal Shardling -----------------------------------------------------------

def shard():
    deep, mid, pale = lin("#2c4a63"), lin("#6c9fc2"), lin("#e6f5fc")
    def ice(t, dark=1.0):
        c = mix(deep, mid, t * 1.6) if t < 0.62 else mix(mid, pale, (t - 0.62) / 0.38)
        return tuple(v * dark for v in c)
    core = Part()
    # A heavy upright crystal with a splayed collar of shorter ones, rooted in one point.
    core.crystal(Vector((0, 0, 0.0)), Vector((0.04, 0.0, 1.0)), 1.45, 0.24, ice)
    for i, (az, tilt, ln, r) in enumerate([(0, 0.55, 0.85, 0.15), (70, 0.7, 0.62, 0.13), (140, 0.5, 0.95, 0.16),
                                          (215, 0.65, 0.7, 0.14), (285, 0.6, 0.8, 0.15)]):
        a = math.radians(az)
        d = Vector((math.sin(tilt) * math.cos(a), math.sin(tilt) * math.sin(a), math.cos(tilt)))
        core.crystal(Vector((0.05 * math.cos(a), 0.05 * math.sin(a), 0.02)), d, ln, r, lambda t: ice(t, 0.9), twist=i)
    # Two rings of loose shards held in orbit, points down.
    ring_a, ring_b = Part(), Part()
    for part, n, rad, z, ln, r, off in ((ring_a, 3, 0.62, 0.95, 0.42, 0.075, 0.0), (ring_b, 3, 0.45, 0.38, 0.32, 0.06, 1.0)):
        for k in range(n):
            a = off + k * math.tau / n
            part.crystal(Vector((rad * math.cos(a), rad * math.sin(a), z)), Vector((0.12 * math.cos(a), 0.12 * math.sin(a), -1.0)), ln, r, lambda t: ice(1.0 - t * 0.9, 1.0), twist=k)
    objs = [core.build("Core", False), ring_a.build("OrbitA", False), ring_b.build("OrbitB", False)]
    finish("shard", objs)


# -- Methane Bloat ---------------------------------------------------------------

def bloat():
    skin, vein, bruise, scar = lin("#a09a4a"), lin("#4a4f22"), lin("#7a6446"), lin("#e0d8a6")
    def hide(c):
        v = noise.noise(c * 3.1 + Vector((4.0, 1.0, 2.0)))
        w = noise.noise(c * 7.5 + Vector((9.0, 3.0, 7.0)))
        col = mix(skin, bruise, 0.5 + 0.9 * v)
        col = mix(col, vein, max(0.0, 0.55 - abs(w) * 3.0) * 1.4)
        return mix(col, bruise, max(0.0, -c.z * 0.5))
    p = Part()
    p.blob(Vector((0, 0, 1.35)), (0.95, 0.9, 0.85), 2, 0.16, hide, seed=2.0)
    for k, (az, ph) in enumerate([(0, 0.0), (62, 1.7), (125, 3.1), (190, 0.9), (250, 2.4), (310, 4.0)]):
        a = math.radians(az)
        rd = Vector((math.cos(a), math.sin(a), 0))
        base = rd * 0.42 + Vector((0, 0, 0.78))
        pts = []
        for i in range(9):
            t = i / 8
            sway = math.sin(t * 3.2 + ph) * 0.13
            pts.append(base + rd * (0.28 * t + sway) + Vector((-rd.y, rd.x, 0)) * sway * 0.7 + Vector((0, 0, -0.82 * t)))
        p.ring_tube(pts, [0.13 * (1 - 0.88 * i / 8) for i in range(9)], 6, lambda c: mix(bruise, vein, (0.9 - c.z) * 0.5))
    # Boils: pale, swollen, one is split.
    for az, el, s in [(20, 0.5, 0.17), (100, 0.2, 0.2), (170, 0.65, 0.14), (230, 0.35, 0.18), (300, 0.75, 0.16), (345, 0.2, 0.13), (65, 0.9, 0.12)]:
        a, e = math.radians(az), el
        d = Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e)))
        p.blob(Vector((0, 0, 1.35)) + Vector((d.x * 0.93, d.y * 0.88, d.z * 0.83)), (s, s, s * 0.8), 1, 0.2, lambda c: mix(scar, skin, 0.35), seed=az)
    # A ridge of dark spines down the back.
    for i in range(5):
        a = math.radians(200 + i * 28)
        q = Vector((math.cos(a) * 0.62, math.sin(a) * 0.62, 1.35 + 0.62 - i * 0.04))
        p.crystal(q, Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, 1.0)), 0.34, 0.07, lambda t: mix(vein, bruise, t), sides=4)
    finish("bloat", [p.build("Bloat", True)])


# -- Sporecap --------------------------------------------------------------------

def spore():
    cap_top, cap_edge, gill, stalk, bone, rot = lin("#7c5568"), lin("#3e2833"), lin("#2a1c24"), lin("#a89c7c"), lin("#e2dab8"), lin("#4a4234")
    def capc(c):
        n = noise.noise(c * 2.6 + Vector((1, 2, 3)))
        base = mix(cap_edge, cap_top, (c.z - 0.55) * 3.0 + 0.1 * n)
        return mix(gill, base, 1.0 if c.z > 0.62 else max(0.0, (c.z - 0.52) * 8.0))
    def stalkc(c):
        n = noise.noise(c * 5.0 + Vector((7, 1, 4)))
        return mix(rot, stalk, 0.55 + 0.6 * n + (c.z - 0.3) * 0.5)
    p = Part()
    p.blob(Vector((0, 0, 0.78)), (0.72, 0.72, 0.34), 2, 0.1, capc, seed=5.0)
    pts = [Vector((0.03 * math.sin(i), 0.03 * math.cos(i * 1.3), 0.12 + i * 0.075)) for i in range(8)]
    p.ring_tube(pts, [0.21, 0.19, 0.17, 0.16, 0.16, 0.17, 0.2, 0.22], 7, stalkc)
    for az, s in [(15, 0.1), (85, 0.07), (140, 0.12), (200, 0.08), (255, 0.1), (310, 0.07), (35, 0.06)]:
        a = math.radians(az); r = 0.18 + (az % 97) / 97 * 0.34
        z = 0.78 + 0.34 * math.sqrt(max(0.0, 1.0 - (r / 0.72) ** 2)) * 0.96
        p.blob(Vector((r * math.cos(a), r * math.sin(a), z)), (s, s, s * 0.5), 1, 0.15, lambda c: bone, seed=az)
    for k in range(5):
        a = k * math.tau / 5 + 0.3
        rd = Vector((math.cos(a), math.sin(a), 0))
        pts = [Vector((0, 0, 0.3)) + rd * (0.1 + 0.2 * t) + Vector((0, 0, -0.3 * t * t * 0.9 - 0.02 * t)) for t in [i / 6 for i in range(7)]]
        pts = [rd * (0.12 + 0.55 * t) + Vector((0, 0, 0.32 * (1 - t) ** 1.6)) for t in [i / 6 for i in range(7)]]
        p.ring_tube(pts, [0.1 * (1 - 0.8 * i / 6) for i in range(7)], 5, lambda c: mix(stalk, rot, 0.6 - c.z))
    finish("spore", [p.build("Spore", True)])


BUILDERS = {"shard": shard, "bloat": bloat, "spore": spore}

if __name__ == "__main__":
    names = [a for a in sys.argv[1:] if a in BUILDERS] or list(BUILDERS)
    for n in names:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        BUILDERS[n]()
