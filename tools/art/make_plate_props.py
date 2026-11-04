"""Dark plate props: the coffins, skulls, lanterns, lantern and skull posts, chests and coin stacks that
replace the KayKit graveyard/dungeon pieces in every zone and the camp. Flat-faceted hard-surface
shapes in gunmetal plate, old bone and tarnished gold, with the lanterns' cores and the candle flames
carrying the one warm glow (the kit's third material).

One small static gltf per prop in assets/props/, same file names the KayKit ones had so the arenas'
collision policy and baked footprints keep working. Each file carries its own palette image
(see kit_lib.py). Built in Godot axes (x right, y up, +z toward the camera / the front).
The chests are two objects: the body and `chest_lid`, whose origin is the hinge (the camp rotates it).

Run: tools/art/blender.sh tools/art/make_plate_props.py
Deterministic.
"""
import base64, json, math, os, struct, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit_lib as K
from kit_lib import Part, Palette, ramp, n3, MATTE, CRYSTAL
from mathutils import Vector
import bpy

OUT = os.path.join(K.ROOT, "assets", "props")
K.EMIT["plate_props"] = 1.0

IRON = ["#101216", "#1f2227", "#333841", "#4d545f"]
BONE = ["#1e1b16", "#4a443a", "#7d7564", "#aaa28c"]
WOOD = ["#17110d", "#271d16", "#3d2e22", "#5a4636"]
GOLD = ["#24190a", "#4f3a10", "#8a6516", "#c79a2e"]
WAX = ["#3a352c", "#6e6857", "#a39b84"]
EMB = ["#7a1e04", "#c4400a", "#ff7a1a", "#ffc060"]
VOID = ["#020202", "#060606", "#0c0c0c"]
TAGS = {1: IRON, 2: WOOD, 3: BONE, 4: GOLD, 5: EMB, 6: WAX, 7: VOID}


def colour(seed):
    """Tags: 1 plate, 2 wood, 3 bone, 4 gold, 5 ember (glow), 6 wax, 7 void."""
    def fn(tag, c, n, i):
        j = n3(c, seed, 3.1)
        up = max(n.y, 0.0)
        front = max(n.z, 0.0)
        if tag == 5:
            return ramp(EMB, 0.35 + 0.35 * (0.5 + 0.5 * j))
        if tag == 7:
            return ramp(VOID, 0.5 + 0.4 * j)
        return ramp(TAGS[tag], 0.18 + 0.28 * (0.5 + 0.5 * j) + 0.4 * up + 0.12 * front)
    return fn


def finish(p, seed):
    import bmesh
    bmesh.ops.triangulate(p.bm, faces=list(p.bm.faces), quad_method='BEAUTY', ngon_method='BEAUTY')
    p.closed = True
    return p.paint(colour(seed), PAL)


def poly(p, pts, y, s=1.0, c=(0.0, 0.0)):
    """A ring of verts over an outline of (x, z) points, scaled about c."""
    return [p.v(c[0] + (x - c[0]) * s, y, c[1] + (z - c[1]) * s) for x, z in pts]


def prism(p, pts, y0, y1, s0=1.0, s1=1.0, c=(0.0, 0.0), **kw):
    p.loft([poly(p, pts, y0, s0, c), poly(p, pts, y1, s1, c)], cap_lo=True, cap_hi=True, **kw)


def disc(p, c, r, y0, y1, yaw=0.0, n=8, **kw):
    """An octagonal coin: a ring prism."""
    lo = p.ring(n, r, y0, off=(c[0], c[1]), phase=yaw)
    hi = p.ring(n, r, y1, off=(c[0], c[1]), phase=yaw)
    p.loft([lo, hi], cap_lo=True, cap_hi=True, **kw)


# --- skulls -----------------------------------------------------------------

def skull_shape(p, at=(0, 0, 0), k=1.0):
    """A faceted skull, face toward +z, jaw on the ground. About 0.9 x 0.9 x 0.9 at k = 1."""
    m = p.mark()
    p.use(3, MATTE)
    p.lump((0, 0.58, -0.02), (0.44, 0.34, 0.42), subdiv=1, warp=0.1, seed=3.0)
    p.box((0, 0.36, 0.2), (0.54, 0.26, 0.36), taper=0.8)
    p.box((0, 0.17, 0.17), (0.44, 0.16, 0.3), taper=0.85)
    for sx in (-1, 1):
        p.box((sx * 0.14, 0.46, 0.4), (0.19, 0.17, 0.1), tilt=(0, sx * 0.2), tag=7)
        p.box((sx * 0.3, 0.3, 0.12), (0.1, 0.1, 0.3), tag=3)
    p.box((0, 0.34, 0.43), (0.09, 0.14, 0.08), taper=0.5, tag=7)
    for t in range(5):
        p.box(((t - 2) * 0.085, 0.2, 0.34), (0.06, 0.1, 0.05), tag=3)
    p.box((0, 0.1, 0.1), (0.3, 0.05, 0.22), tag=7)
    p.move(m, offset=at, scale=k, pivot=(0, 0, 0))


def skull(name):
    p = Part(name, 11)
    skull_shape(p)
    return [finish(p, 11)]


def skull_candle(name):
    p = Part(name, 12)
    skull_shape(p)
    p.use(6)
    p.limb((0.04, 0.84, -0.02), (0.04, 1.08, -0.02), 0.11, 0.095, sides=6)
    p.limb((0.15, 0.9, 0.06), (0.15, 0.78, 0.06), 0.035, 0.025, sides=4)
    p.use(1)
    p.limb((0.04, 1.08, -0.02), (0.04, 1.1, -0.02), 0.13, 0.12, sides=6)
    p.use(5, CRYSTAL)
    p.crystal((0.04, 1.1, -0.02), (0, 1, 0), 0.15, 0.05, sides=4)
    return [finish(p, 12)]


# --- lanterns ---------------------------------------------------------------

def cage(p, y0, h, r):
    """A six-sided iron lantern cage with a glowing core, base at y0, h tall, r across."""
    p.use(1, MATTE)
    p.loft([p.ring(6, r * 0.95, y0), p.ring(6, r * 0.82, y0 + 0.08)], cap_lo=True, cap_hi=True)
    for k in range(6):
        a = math.tau * k / 6
        p.limb((math.cos(a) * r * 0.8, y0 + 0.08, math.sin(a) * r * 0.8),
               (math.cos(a) * r * 0.7, y0 + h - 0.14, math.sin(a) * r * 0.7), 0.035, 0.03, sides=4)
    yt = y0 + h - 0.14
    p.loft([p.ring(6, r * 0.78, yt), p.ring(6, r * 0.5, yt + 0.09), p.ring(6, r * 0.14, yt + 0.16)], cap_lo=True, cap_hi=True)
    p.use(5, CRYSTAL)
    p.loft([p.ring(6, r * 0.34, y0 + 0.12), p.ring(6, r * 0.5, y0 + h * 0.4), p.ring(6, r * 0.3, y0 + h - 0.2)],
           cap_lo=True, cap_hi=True)
    p.use(1, MATTE)


def link(p, a, b):
    p.limb(a, b, 0.03, 0.03, sides=4)


def chain(p, x, z, y_top, y_bot, step=0.16):
    p.use(1, MATTE)
    y, k = y_top, 0
    while y - step > y_bot - 1e-6:
        p.box((x, y - step / 2, z), (0.07 if k % 2 == 0 else 0.03, step * 1.15, 0.03 if k % 2 == 0 else 0.07))
        y -= step
        k += 1


def lantern_standing(name):
    p = Part(name, 21)
    p.use(1)
    p.box((0, 0.04, 0), (0.46, 0.08, 0.46), taper=0.8)
    cage(p, 0.08, 0.78, 0.31)
    p.box((0, 0.93, 0), (0.07, 0.07, 0.07))
    return [finish(p, 21)]


def lantern_hanging(name):
    p = Part(name, 22)
    chain(p, 0, 0, 0.1, -0.7)
    p.use(1)
    p.box((0, 0.1, 0), (0.18, 0.05, 0.05))
    p.loft([p.ring(6, 0.1, -0.7), p.ring(6, 0.05, -0.64)], cap_lo=True, cap_hi=True)
    cage(p, -1.31, 0.62, 0.31)
    return [finish(p, 22)]


def post(p, lantern, y_bot=-1.31):
    """The lamp post: a plated pole, a bracket arm out to +z and a brace."""
    p.use(1, MATTE)
    p.box((0, (y_bot + 3.3) / 2, 0), (0.24, 3.3 - y_bot, 0.24), taper=0.85)
    p.box((0, y_bot + 0.2, 0), (0.4, 0.4, 0.4), taper=0.8)
    p.box((0, 3.0, 0.6), (0.14, 0.14, 1.3))
    p.limb((0, 2.35, 0.1), (0, 2.98, 0.9), 0.06, 0.05, sides=4)
    p.loft([p.ring(6, 0.17, 3.3), p.ring(6, 0.03, 3.55)], cap_lo=True, cap_hi=True)
    lantern(p)


def post_lantern(name):
    p = Part(name, 23)
    start = p.mark()
    cage(p, 1.93, 0.62, 0.28)
    p.move(start, offset=(0, 0, 1.2))     # carried out to the end of the arm
    chain(p, 0, 1.2, 3.0, 2.55, 0.15)
    post(p, lambda q: None)
    return [finish(p, 23)]


def post_skull(name):
    p = Part(name, 24)
    chain(p, 0, 1.2, 3.0, 2.6, 0.13)
    s0 = p.mark()
    skull_shape(p, k=0.52)
    p.move(s0, offset=(0, 2.2, 1.2))
    p.use(1)
    p.box((0, 3.02, 1.2), (0.12, 0.05, 0.12))
    post(p, lambda q: None)
    return [finish(p, 24)]


# --- coffins ----------------------------------------------------------------

COFFIN = [(-0.5, -1.5), (0.5, -1.5), (0.98, -0.72), (0.62, 1.5), (-0.62, 1.5), (-0.98, -0.72)]


def coffin_body(p, h, decorated):
    p.use(1, MATTE)
    prism(p, COFFIN, 0.0, 0.18, 1.08, 1.08)                  # plinth
    p.use(2)
    prism(p, COFFIN, 0.18, h * 0.78, 1.0, 0.98)                # the box
    p.use(1)
    prism(p, COFFIN, h * 0.78, h * 0.9, 1.04, 0.9)             # the lid's shoulder
    p.use(2)
    prism(p, COFFIN, h * 0.9, h, 0.9, 0.5)                     # the lid's crown
    # iron straps across the lid and the foot
    for z in (-0.95, 0.15, 1.05):
        w = 0.8 - 0.06 * max(z, 0) * 0.5
        p.use(1)
        p.box((0, h * 0.62, z), (2 * (0.98 - 0.22 * max(0, (z + 0.72) / 2.2)) * 1.03, h * 0.13, 0.16))
    # corner studs
    p.use(1)
    for x, z in COFFIN:
        p.box((x * 1.06, h * 0.84, z * 1.04), (0.12, 0.12, 0.12), taper=0.7)
    if decorated:
        p.use(3)
        # a bone cross inlaid on the crown, a skull plate at the head
        p.box((0, h + 0.0, 0.1), (0.14, 0.05, 1.3), taper=0.8)
        p.box((0, h + 0.0, -0.35), (0.62, 0.05, 0.14), taper=0.8)
        p.use(4)
        p.box((0, h * 0.62, -1.52), (0.5, 0.34, 0.1), taper=0.8)
        p.use(7)
        p.box((0, h * 0.62, -1.58), (0.2, 0.14, 0.05))


def coffin(name):
    p = Part(name, 31)
    coffin_body(p, 1.0, False)
    return [finish(p, 31)]


def coffin_decorated(name):
    p = Part(name, 32)
    coffin_body(p, 0.88, True)
    return [finish(p, 32)]


# --- chests -----------------------------------------------------------------

def chest(name, gold):
    """Body in Godot axes with its hinge at (0, 0.5, -0.565); the lid is its own object around that hinge."""
    p = Part(name, 41 if not gold else 42)
    z0, z1 = -0.6, 1.3
    zc = (z0 + z1) / 2
    p.use(1, MATTE)
    p.box((0, 0.26, zc), (1.7, 0.52, z1 - z0), taper=0.97)
    for x in (-0.66, 0.66):                                 # plate straps round the body
        p.box((x, 0.26, zc), (0.16, 0.56, z1 - z0 + 0.08))
    p.box((0, 0.02, zc), (1.8, 0.08, z1 - z0 + 0.1))        # foot plate
    for sx in (-1, 1):
        for sz in (z0, z1):
            p.box((sx * 0.84, 0.46, sz), (0.12, 0.2, 0.12), taper=0.7)
    p.use(4 if gold else 1)
    p.box((0, 0.5, zc), (1.4, 0.04, z1 - z0 - 0.3))         # the hoard under the lid
    p.use(4)
    p.box((0, 0.32, z1 + 0.02), (0.3, 0.26, 0.06), taper=0.85)   # lock plate
    body = finish(p, 41 if not gold else 42)

    q = Part("chest_lid", 43 if not gold else 44)
    w = q.mark()
    zl0, zl1 = z0 - 0.04, z1 + 0.04
    hz = -0.565
    top = 0.3 if gold else 0.22
    q.use(1, MATTE)
    q.box((0, 0.1, (zl0 + zl1) / 2 - hz), (1.74, 0.2, zl1 - zl0), taper=1.0)
    q.use(2 if not gold else 1)
    q.box((0, 0.2 + top * 0.5, (zl0 + zl1) / 2 - hz), (1.5, top, zl1 - zl0 - 0.12), taper=0.78)
    for x in (-0.66, 0.66):
        q.use(1)
        q.box((x, 0.2 + top * 0.35, (zl0 + zl1) / 2 - hz), (0.16, top * 0.8 + 0.04, zl1 - zl0 + 0.04), taper=0.9)
    if gold:
        q.use(4)
        q.box((0, 0.2 + top, (zl0 + zl1) / 2 - hz), (0.2, 0.06, zl1 - zl0 - 0.16))
        q.box((0, 0.12, zl1 - hz + 0.03), (0.22, 0.2, 0.07))
        q.use(5, CRYSTAL)
        q.crystal((0, 0.2 + top + 0.02, (zl0 + zl1) / 2 - hz), (0, 1, 0), 0.2, 0.07, sides=4)
    else:
        q.use(4)
        q.box((0, 0.12, zl1 - hz + 0.03), (0.2, 0.18, 0.07))
    lid = finish(q, 43 if not gold else 44)
    lid.location = K.g2b((0, 0.5, hz))
    return [body, lid]


def chest_plain(name):
    return chest(name, False)


def chest_gold(name):
    return chest(name, True)


# --- coins ------------------------------------------------------------------

def tower(p, c, n, r=0.22, t=0.075, y0=0.0, wobble=0.012):
    for i in range(n):
        o = (c[0] + p.rng.uniform(-wobble, wobble), c[1] + p.rng.uniform(-wobble, wobble))
        disc(p, o, r * (1 + 0.02 * (i % 2)), y0 + i * t, y0 + (i + 1) * t - 0.006, yaw=p.rng.uniform(0, 1), tag=4)


def coin(name):
    p = Part(name, 51)
    p.use(4)
    disc(p, (0, 0), 0.18, -0.06, 0.06, yaw=0.2)
    p.use(1)
    disc(p, (0, 0), 0.07, -0.065, 0.065, yaw=0.2, n=6)
    return [finish(p, 51)]


def coin_stack_small(name):
    p = Part(name, 52)
    tower(p, (-0.12, -0.08), 6)
    tower(p, (0.2, 0.1), 4)
    tower(p, (-0.18, 0.2), 2, r=0.2)
    tower(p, (0.28, -0.22), 1, r=0.2)
    return [finish(p, 52)]


def coin_stack_medium(name):
    p = Part(name, 53)
    tower(p, (-0.1, -0.12), 8)
    tower(p, (0.26, 0.05), 5)
    tower(p, (-0.28, 0.24), 3)
    tower(p, (0.12, 0.34), 2, r=0.2)
    tower(p, (0.38, -0.3), 1, r=0.2)
    return [finish(p, 53)]


def coin_stack_large(name):
    p = Part(name, 54)
    p.use(4)
    p.lump((0, 0.12, 0), (0.7, 0.2, 0.78), subdiv=1, warp=0.12, seed=9.0, flat=0.6)
    tower(p, (-0.05, -0.1), 14, r=0.26, y0=0.0)
    tower(p, (0.42, 0.18), 9, r=0.24)
    tower(p, (-0.42, 0.22), 7, r=0.24)
    tower(p, (0.1, 0.5), 4, r=0.22)
    tower(p, (-0.3, -0.5), 5, r=0.22)
    tower(p, (0.5, -0.42), 3, r=0.22)
    return [finish(p, 54)]


BUILDERS = [coffin, coffin_decorated, skull, skull_candle, lantern_standing, lantern_hanging, post_lantern, post_skull,
            chest_plain, chest_gold, coin, coin_stack_small, coin_stack_medium, coin_stack_large]
FILES = {"chest_plain": "chest"}


def export(file, objs):
    img = PAL.image()
    mats = K.make_materials(img, "plate_props")
    for ob in objs:
        for m in K.SLOTS[ob.name]:
            ob.data.materials.append(mats[m])
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objs:
        ob.select_set(True)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, file + ".gltf")
    glb = os.path.join(tempfile.gettempdir(), file + "_plate.glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', use_selection=True, export_animations=False,
                              export_yup=True, export_vertex_color='NONE', export_apply=False)
    with open(glb, "rb") as f:
        blob = f.read()
    jl, = struct.unpack_from("<I", blob, 12)
    doc = json.loads(blob[20:20 + jl])
    bl, = struct.unpack_from("<I", blob, 20 + jl)
    data = blob[28 + jl:28 + jl + bl]
    # One embedded .gltf, so the file names stay what the arenas' collision tables are keyed by.
    doc["buffers"] = [{"byteLength": len(data), "uri": "data:application/octet-stream;base64," + base64.b64encode(data).decode()}]
    with open(path, "w") as f:
        json.dump(doc, f, separators=(",", ":"))
    os.remove(glb)
    tris = sum(len(pp.vertices) - 2 for ob in objs for pp in ob.data.polygons)
    print("WROTE", path, "colours", len(PAL.cells), "tris", tris)


if __name__ == "__main__":
    only = set(sys.argv[1:])
    for b in BUILDERS:
        file = FILES.get(b.__name__, b.__name__)
        if only and file not in only:
            continue
        K.reset()
        PAL = Palette(file)
        export(file, b(file))
