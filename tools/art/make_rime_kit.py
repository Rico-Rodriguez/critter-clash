"""The Rimehollow prop kit: glacier cliffs, boulders, crystal clusters, snow pines, ice blocks,
and the one-off set pieces (longship, fisher's hut, sled, the Glacier Throne ...).
Palette-textured static meshes, feet at y = 0, facing +z, modelled in Godot axes (see kit_lib.py).
Run: tools/art/blender.sh tools/art/make_rime_kit.py
Writes assets/kits/rime/rime_kit.glb. Deterministic; no random state outside the seeds below."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit_lib as K
from kit_lib import Part, Palette, hexc, ramp, mix, shade, n3, b2g, MATTE, ICE, CRYSTAL
from mathutils import Vector

OUT = os.path.join(K.ROOT, "assets", "kits", "rime", "rime_kit.glb")

# Cold, desaturated, a little dirty. Snow is never pure white.
ROCK = ["#1e2229", "#30363f", "#4a525e", "#6a7380"]
SNOW = ["#8ea0b6", "#b9c8da", "#dfe9f3", "#f3f8fc"]
ICEC = ["#070d13", "#0f2230", "#1d4252", "#356b7c", "#8fb2be"]
CRYS = ["#08202d", "#10404f", "#237282", "#8ec9cf"]
WOOD = ["#1e1510", "#33241a", "#4a3626", "#6a5a48"]
IRON = ["#1a1c21", "#2c3037", "#444a54"]
PINE = ["#08150f", "#102b21", "#1b432f", "#2b5f40"]
BARK = ["#1a120c", "#2b1e14", "#3e2d1f"]


def tidy(p):
    """Triangulates (so each facet is its own flat plane) and keeps the tags."""
    import bmesh
    bmesh.ops.triangulate(p.bm, faces=list(p.bm.faces), quad_method='BEAUTY', ngon_method='BEAUTY')


def rock_colour(seed, height=4.0, snow_up=0.55):
    """Tag 3 is snow; steep faces are rock, laid in strata, with pale ice streaks running down some."""
    def fn(tag, c, n, i):
        j = n3(c, seed, 1.7)
        if tag == 3 or n.y > snow_up + 0.1 * j:
            return ramp(SNOW, 0.3 + 0.55 * max(n.y, 0.0) + 0.12 * j - 0.06 * (1.0 - min(c.y / 2.0, 1.0)))
        streak = n3(Vector((c.x * 2.5, c.y * 0.4, c.z * 2.5)), seed + 5.0, 1.0)
        if streak > 0.34 and c.y > 0.7:
            return ramp(ICEC, 0.2 + 0.22 * j + 0.15 * (c.y / height))
        band = math.sin(c.y * 3.4 + n3(c, seed, 0.8) * 2.0) * 0.5 + 0.5
        t = 0.16 + 0.3 * band + 0.16 * min(c.y / height, 1.0) + 0.1 * j
        k = 0.66 + 0.34 * min(c.y / 1.3, 1.0)
        return shade(ramp(ROCK, t), k)
    return fn


# -- glacier cliffs -----------------------------------------------------------------

def slab(p, n, r, y0, y1, off, taper, twist, snow, jit=0.14, bands=2):
    """A stratum: a jittered prism of `bands` bands narrowing by `taper`, a flat top and a snow pillow on it."""
    rings = []
    for b in range(bands + 1):
        f = b / bands
        rings.append(p.ring(n, r * (1.0 - (1.0 - taper) * f) * (1.0 + 0.05 * math.sin(b * 2.1 + y0)), y0 + (y1 - y0) * f,
                            off=off, phase=twist + 0.2 * b, jit=jit, yjit=0.07 if 0 < b < bands else 0.0))
    p.loft(rings, cap_lo=y0 == 0.0, tag=1)
    top = rings[-1]
    if snow:
        c = Vector((off[0], y1, off[1]))
        lip = [p.v(b2g(v.co) + (b2g(v.co) - c) * Vector((0.07, 0, 0.07)) + Vector((0, 0.03, 0))) for v in top]
        rim = [p.v(c + (b2g(v.co) - c) * Vector((0.72, 0, 0.72)) + Vector((0, 0.2 + p.rng.uniform(0.0, 0.1), 0))) for v in top]
        for k in range(n):
            j = (k + 1) % n
            p.quad(top[k], top[j], lip[j], lip[k], tag=3)
            p.quad(lip[k], lip[j], rim[j], rim[k], tag=3)
        p.face(list(rim), tag=3)
    else:
        p.face(list(top), tag=1)
    return rings


def cliff(name, seed, sides, lean, bump):
    p = Part(name, seed)
    n = sides - 2
    slab(p, n, 1.0, 0.0, 1.5, (0, 0), 0.9, seed * 0.13, True, bands=3)
    slab(p, n, 0.78, 1.45, 2.75, (lean[0] * 0.25, lean[1] * 0.25), 0.82, seed * 0.29, True, bands=2)
    slab(p, n - 1, 0.5, 2.7, 3.7, (lean[0] * 0.5, lean[1] * 0.5), 0.62, seed * 0.41, True, jit=0.18, bands=2)
    apex = p.v(lean[0] * 0.55, 3.98, lean[1] * 0.55)
    top = p.ring(n - 1, 0.2, 3.76, off=(lean[0] * 0.52, lean[1] * 0.52), jit=0.2)
    for k in range(n - 1):
        p.tri(top[k], top[(k + 1) % (n - 1)], apex, tag=3)
    # Shoulders: lower blocks leaning on the base, each with its own snow ledge.
    for ang, rad, hgt in bump:
        off = (math.cos(ang) * 0.95, math.sin(ang) * 0.95)
        slab(p, 6, rad, 0.0, hgt, off, 0.78, ang, True, jit=0.2, bands=2)
    tidy(p)
    return p.paint(rock_colour(seed, 3.9), PAL)


def boulder(name, seed, radii, snow):
    p = Part(name, seed)
    p.lump((0, radii[1] * 0.45, 0), radii, subdiv=2, warp=0.38, seed=seed, flat=0.45)
    tidy(p)
    return p.paint(rock_colour(seed, radii[1] * 2.0, 0.45 if snow else 0.72), PAL)


# -- crystals -----------------------------------------------------------------------

def crystals(name, seed, n_side, tall):
    p = Part(name, seed)
    p.use(mat=CRYSTAL)
    p.crystal((0, -0.1, 0), (0.05, 1, 0.02), 3.0 * tall, 0.42, twist=seed)
    yaw0 = p.rng.uniform(0, math.tau)
    for k in range(n_side):
        a = yaw0 + math.tau * k / n_side + p.rng.uniform(-0.3, 0.3)
        s = p.rng.uniform(0.5, 0.82) * tall
        lean = p.rng.uniform(0.3, 0.62)
        d = (math.sin(lean) * math.cos(a), math.cos(lean), math.sin(lean) * math.sin(a))
        p.crystal((math.cos(a) * 0.5, -0.1, math.sin(a) * 0.5), d, 2.4 * s, 0.33 * s, twist=k)
    tidy(p)

    def fn(tag, c, n, i):
        t = max(0.0, min(1.0, (c.y + 0.1) / (3.0 * tall)))
        j = n3(c, seed, 2.1)
        return ramp(CRYS, 0.1 + 0.85 * t + 0.1 * j + 0.1 * n.y)
    return p.paint(fn, PAL)


def ice_block(name, seed, broken):
    p = Part(name, seed)
    p.use(mat=ICE)
    if not broken:
        rings = [p.ring(6, 1.22, 0.0, jit=0.05), p.ring(6, 1.16, 1.2, phase=0.12, jit=0.06, yjit=0.1),
                 p.ring(6, 0.98, 2.35, phase=0.2, jit=0.1, yjit=0.15), p.ring(6, 0.6, 2.75, phase=0.35, jit=0.2, yjit=0.12)]
        p.loft(rings, cap_lo=True, cap_hi=True)
    else:
        # What is left when the wall breaks: a stump and tilted shards.
        rings = [p.ring(6, 1.22, 0.0, jit=0.05), p.ring(6, 1.05, 0.42, phase=0.1, jit=0.18, yjit=0.12), p.ring(6, 0.8, 0.62, phase=0.2, jit=0.25, yjit=0.15)]
        p.loft(rings, cap_lo=True, cap_hi=True)
        for k, (ox, oz, h, w, tl) in enumerate([(0.7, 0.2, 1.3, 0.36, 0.35), (-0.55, 0.45, 1.0, 0.3, -0.4), (0.0, -0.7, 1.5, 0.34, 0.25), (-0.3, -0.1, 0.8, 0.26, 0.5)]):
            p.box((ox, h / 2, oz), (w, h, w * 0.8), yaw=k * 1.1, tilt=(tl, tl * 0.5), taper=0.25)
    tidy(p)

    def fn(tag, c, n, i):
        j = n3(c, seed, 1.9)
        crack = n3(c, seed + 3.0, 3.1)
        if abs(crack) < 0.06:
            return ramp(ICEC, 0.05)
        if n.y > 0.72 + 0.1 * j:
            return ramp(SNOW, 0.3 + 0.4 * n.y + 0.2 * j)
        t = 0.2 + 0.5 * (c.y / 2.8) + 0.25 * j + 0.1 * n.y
        return ramp(ICEC, t)
    return p.paint(fn, PAL)


# -- snow pines ---------------------------------------------------------------------

def pine(name, seed, height):
    p = Part(name, seed)
    h = height
    t0 = p.ring(5, 0.2, 0.0, jit=0.05)
    t1 = p.ring(5, 0.15, 1.5 * h, jit=0.05)
    p.loft([t0, t1], cap_hi=True, tag=1)
    tiers = 5
    for k in range(tiers):
        f = k / (tiers - 1)
        y0 = (0.8 + f * 2.55) * h
        r = 1.55 - f * 1.1
        m = 8
        ring = []
        for i in range(m * 2):
            a = math.tau * i / (m * 2) + p.rng.uniform(-0.05, 0.05) + k * 0.4
            rr = r * (1.0 if i % 2 == 0 else 0.62) * (1.0 + p.rng.uniform(-0.12, 0.12))
            dy = -0.34 * h if i % 2 == 0 else 0.0
            ring.append(p.v(math.cos(a) * rr, y0 + dy + p.rng.uniform(-0.05, 0.05), math.sin(a) * rr))
        tip = p.v(0, y0 + 0.62 * h * (1.0 - 0.15 * f), 0)
        under = p.v(0, y0 - 0.1 * h, 0)
        for i in range(m * 2):
            j = (i + 1) % (m * 2)
            p.tri(ring[i], ring[j], tip, tag=2 + k)
            p.tri(ring[j], ring[i], under, tag=1)
    tidy(p)

    def fn(tag, c, n, i):
        if tag == 1:
            return ramp(BARK, 0.3 + 0.3 * n3(c, seed, 2.0))
        j = n3(c, seed, 2.3)
        if n.y > 0.42 + 0.15 * j - 0.03 * (tag - 2):
            return ramp(SNOW, 0.5 + 0.35 * n.y + 0.1 * j)
        return ramp(PINE, 0.2 + 0.4 * (c.y / (4.0 * h)) + 0.15 * j)
    return p.paint(fn, PAL)


# -- set pieces -----------------------------------------------------------------------

PAINT = {7: "#58231d", 8: "#6e5426", 9: "#6d7885", 10: "#26384a"}


def prop_colour(seed, height=3.0):
    """Tags: 1 wood, 2 dark wood, 3 snow, 4 iron, 5 stone, 6 ice, 7-10 paint, 11 bone, 12 dark rock."""
    def fn(tag, c, n, i):
        j = n3(c, seed, 2.2)
        if tag == 3:
            return ramp(SNOW, 0.15 + 0.5 * max(n.y, 0.0) + 0.2 * j)
        if tag == 4:
            return ramp(IRON, 0.3 + 0.3 * j + 0.2 * n.y)
        if tag == 5:
            return ramp(ROCK, 0.3 + 0.3 * j + 0.15 * (c.y / height))
        if tag == 6:
            return ramp(ICEC, 0.2 + 0.3 * j + 0.3 * (c.y / height) + 0.15 * n.y)
        if tag in PAINT:
            return shade(hexc(PAINT[tag]), 0.85 + 0.2 * j)
        if tag == 11:
            return ramp(["#4a4338", "#8a8272", "#b8b09c"], 0.4 + 0.3 * j + 0.2 * n.y)
        if tag == 12:
            return ramp(["#14171c", "#232830", "#343b45"], 0.3 + 0.4 * j + 0.2 * n.y)
        t = 0.3 + 0.34 * (0.5 + 0.5 * math.sin(c.x * 9.0 + c.z * 3.0 + j * 2.0)) * (1.0 if tag == 1 else 0.6) + 0.12 * j + 0.1 * n.y
        if tag == 2:
            t *= 0.6
        return ramp(WOOD, t)
    return fn


def longship(name, seed):
    """A beached longship, bow (carved dragon head) toward +z, about 9 m long and 3.4 m across,
    strakes, ribs, thwarts, shields along the rails, a snapped mast, snow drifted in the hull."""
    p = Part(name, seed)
    n = 15
    length = 9.0
    outer, inner = [], []
    for i in range(n + 1):
        t = i / n
        z = (t - 0.5) * length
        beam = math.pow(math.sin(math.pi * min(max(t * 0.96 + 0.02, 0.0), 1.0)), 0.55) * 1.7
        u = abs(2.0 * t - 1.0)
        gun = 1.15 + 1.9 * u ** 4
        keel = 0.6 * u ** 3
        o, q = [], []
        for j in range(7):
            a = j / 6.0
            x = -beam * math.cos(math.pi * a)
            y = keel + (gun - keel) * abs(math.cos(math.pi * a)) ** 1.7
            o.append(p.v(x, y, z))
            q.append(p.v(x * 0.93 + (0.0 if j in (0, 6) else 0.0), y + (0.0 if j in (0, 6) else 0.13), z))
        outer.append(o)
        inner.append(q)
    for i in range(n):
        for j in range(6):
            tag = 1 if (j + i // 5) % 2 == 0 else 2
            p.quad(outer[i][j], outer[i][j + 1], outer[i + 1][j + 1], outer[i + 1][j], tag=tag)
            p.quad(inner[i][j + 1], inner[i][j], inner[i + 1][j], inner[i + 1][j + 1], tag=2)
        # The rails: a flat top joining outer and inner at each side.
        p.quad(outer[i][0], outer[i + 1][0], inner[i + 1][0], inner[i][0], tag=1)
        p.quad(outer[i][6], inner[i][6], inner[i + 1][6], outer[i + 1][6], tag=1)
    # Thwarts across the hull.
    for i in (4, 7, 10):
        o = inner[i]
        p.box((0, b2g(o[0].co).y - 0.3, b2g(o[0].co).z), (2 * abs(o[0].co.x) * 0.98, 0.14, 0.4), tag=1)
    # Mast step and the snapped mast, leaning.
    p.box((0, 0.35, -0.4), (0.8, 0.3, 1.0), tag=2)
    lo, hi = p.limb((0.1, 0.3, -0.4), (0.9, 3.3, -0.1), 0.2, 0.15, sides=6, tag=1)
    for k in range(6):   # splintered top
        a = math.tau * k / 6
        p.tri(hi[k], hi[(k + 1) % 6], p.v(0.9 + 0.12 * math.cos(a + 0.5), 3.3 + 0.35 * (0.4 + 0.6 * (k % 2)), -0.1 + 0.12 * math.sin(a + 0.5)), tag=1)
    # Shields on the outer rail, four a side.
    for side in (-1, 1):
        for k, zc in enumerate((-2.4, -0.9, 0.7, 2.2)):
            i = int((zc / length + 0.5) * n)
            g = b2g(outer[i][0 if side < 0 else 6].co)
            c = (g.x + side * 0.07, g.y - 0.38, g.z)
            p.limb((c[0], c[1], c[2]), (c[0] + side * 0.1, c[1], c[2]), 0.38, 0.38, sides=7, tag=[7, 8, 9, 10][(k + (side > 0)) % 4])
    # Prow: a post rising and curling back into a dragon head; stern post a plain curl.
    prow = [(0, 3.0, 4.52), (0, 3.7, 4.78), (0, 4.4, 4.78), (0, 4.9, 4.42)]
    for a_, b_, ra, rb in zip(prow[:-1], prow[1:], (0.19, 0.16, 0.13), (0.16, 0.13, 0.11)):
        p.limb(a_, b_, ra, rb, sides=5, tag=2)
    h = p.box((0, 5.0, 4.12), (0.3, 0.32, 0.8), tilt=(0.25, 0.0), taper=0.7, tag=2)
    for sx in (-1, 1):
        p.crystal((sx * 0.1, 5.15, 4.35), (sx * 0.5, 0.9, -0.3), 0.55, 0.06, sides=4, tag=11)
    stern = [(0, 3.0, -4.52), (0, 3.5, -4.72), (0, 4.0, -4.55)]
    for a_, b_ in zip(stern[:-1], stern[1:]):
        p.limb(a_, b_, 0.17, 0.12, sides=5, tag=2)
    # Snow drifted into the hull and along the thwarts.
    for zc, rx in ((-2.6, 0.9), (0.9, 1.0), (3.0, 0.7)):
        p.lump((0, 0.62, zc), (rx, 0.22, 0.9), subdiv=1, warp=0.25, seed=zc, flat=0.3, tag=3)
    p.closed = False
    tidy(p)
    return p.paint(prop_colour(seed, 3.0), PAL)


def hut(name, seed):
    """An ice-fisher's hut: plank walls, a steep snow-laden roof, a stone chimney, a dark door.
    About 3 x 2.4 x 2.5; the door faces +z."""
    p = Part(name, seed)
    hw, hd, wh = 1.5, 1.2, 1.55
    for side, (cx, cz, sx, sz) in enumerate(((0, hd, hw * 2, 0.0), (0, -hd, hw * 2, 0.0), (hw, 0, 0.0, hd * 2), (-hw, 0, 0.0, hd * 2))):
        boards = 7 if sx else 5
        for b in range(boards):
            f = (b + 0.5) / boards - 0.5
            w = (2 * hw if sx else 2 * hd) / boards
            hgt = wh + p.rng.uniform(-0.06, 0.08)
            pos = (cx + f * sx * 1.0, hgt / 2, cz + f * sz * 1.0) if sx else (cx, hgt / 2, cz + f * 2 * hd)
            size = (w * 0.96, hgt, 0.14) if sx else (0.14, hgt, w * 0.96)
            p.box(pos, size, tag=1 if (b + side) % 2 == 0 else 2)
    # Door: a dark recess with a frame.
    p.box((0, 0.55, hd + 0.09), (0.86, 1.12, 0.05), tag=12)
    p.box((-0.5, 0.6, hd + 0.1), (0.1, 1.25, 0.08), tag=2)
    p.box((0.5, 0.6, hd + 0.1), (0.1, 1.25, 0.08), tag=2)
    p.box((0, 1.2, hd + 0.1), (1.1, 0.1, 0.08), tag=2)
    # Roof: two slabs meeting at a ridge, snow thick on top, eaves hung with icicles.
    rh = 2.35
    for side in (-1, 1):
        a = math.atan2(rh - wh + 0.15, hd + 0.35)
        mid = (0, (wh + rh) / 2 - 0.05, side * (hd + 0.35) / 2)
        L = math.hypot(rh - wh + 0.15, hd + 0.35)
        p.box(mid, (hw * 2 + 0.6, 0.12, L), tilt=(-side * a, 0.0), tag=2)
        p.box((0, mid[1] + 0.14, mid[2]), (hw * 2 + 0.75, 0.24, L + 0.05), tilt=(-side * a, 0.0), taper=0.97, tag=3)
        for k in range(9):
            x = -hw - 0.2 + k * (hw * 2 + 0.4) / 8
            ln = 0.22 + 0.28 * ((k * 7) % 5) / 4
            p.crystal((x, wh - 0.1, side * (hd + 0.34)), (0, -1, 0), ln, 0.045, sides=3, tag=6)
    p.box((0.8, 2.3, -0.5), (0.5, 0.8, 0.5), tag=5)
    p.box((0.8, 2.78, -0.5), (0.6, 0.18, 0.6), tag=3)
    tidy(p)
    return p.paint(prop_colour(seed, 3.0), PAL)


def sled(name, seed):
    p = Part(name, seed)
    for s_ in (-0.42, 0.42):
        a = (-1.0, 0.0, s_)
        pts = [(-1.0, 0.04, s_), (0.2, 0.0, s_), (0.9, 0.05, s_), (1.25, 0.28, s_), (1.3, 0.46, s_)]
        for q0, q1 in zip(pts[:-1], pts[1:]):
            p.limb(q0, q1, 0.05, 0.05, sides=4, tag=4)
        for xx in (-0.6, 0.3, 0.9):
            p.box((xx, 0.14, s_), (0.07, 0.24, 0.07), tag=2)
    for k in range(6):
        p.box((-0.78 + k * 0.31, 0.27, 0), (0.26, 0.05, 1.0), yaw=p.rng.uniform(-0.04, 0.04), tag=1 if k % 2 else 2)
    p.lump((0.0, 0.34, 0.0), (0.6, 0.12, 0.3), subdiv=1, warp=0.2, seed=2.0, flat=0.3, tag=3)
    p.limb((1.3, 0.46, -0.42), (1.3, 0.46, 0.42), 0.03, 0.03, sides=4, tag=11)
    tidy(p)
    return p.paint(prop_colour(seed, 1.0), PAL)


def snow_bank(name, seed, sx, sz):
    p = Part(name, seed)
    p.lump((0, 0.35, 0), (sx, 0.7, sz), subdiv=2, warp=0.5, seed=seed, flat=0.5, tag=3)
    tidy(p)
    return p.paint(prop_colour(seed, 0.6), PAL)


def hole_rim(name, seed):
    """A fishing hole's lip: a ring of ice chunks round an open centre (radius 0.85), origin at the hole."""
    p = Part(name, seed)
    p.use(mat=ICE)
    m = 9
    for k in range(m):
        a = math.tau * k / m + p.rng.uniform(-0.1, 0.1)
        r = p.rng.uniform(1.0, 1.12)
        w = p.rng.uniform(0.5, 0.7)
        p.box((math.cos(a) * r, 0.1, math.sin(a) * r), (w, p.rng.uniform(0.16, 0.3), w * 0.9), yaw=-a, tilt=(0.0, p.rng.uniform(-0.2, 0.2)), taper=0.7, tag=6)
    tidy(p)
    return p.paint(prop_colour(seed, 0.3), PAL)


def ice_arch(name, seed):
    """A natural ice arch for the glacier gate, 5 m across and 3.6 m high, icicles hanging from the soffit."""
    p = Part(name, seed)
    p.use(mat=ICE)
    r_in, r_out = 1.9, 2.75
    segs = 9
    for k in range(segs):
        a0 = math.pi * k / segs
        a1 = math.pi * (k + 1) / segs
        am = (a0 + a1) / 2
        c = (math.cos(am) * (r_in + r_out) / 2, math.sin(am) * (r_in + r_out) / 2 + 0.8, 0.0)
        thick = (r_out - r_in) * p.rng.uniform(0.95, 1.2)
        p.box(c, (thick, (a1 - a0) * (r_in + r_out) / 2 * 1.08, 1.1 + p.rng.uniform(-0.15, 0.15)), tilt=(0.0, am - math.pi / 2 + math.pi), tag=6)
    for sx in (-1, 1):
        p.box((sx * (r_in + r_out) / 2, 0.45, 0), (r_out - r_in + 0.15, 1.0, 1.25), taper=0.92, tag=6)
        p.box((sx * (r_in + r_out) / 2 + sx * 0.1, 0.12, 0.1), (r_out - r_in + 0.55, 0.3, 1.45), tag=3)
    for k in range(7):
        a = math.pi * (k + 0.5) / 7
        p.crystal((math.cos(a) * (r_in - 0.05), math.sin(a) * (r_in - 0.05) + 0.8, p.rng.uniform(-0.3, 0.3)), (-math.cos(a) * 0.15, -1, 0), 0.3 + 0.35 * p.rng.random(), 0.06, sides=4, tag=6)
    p.lump((0, 0.5 + r_out + 0.55 - 0.9, 0), (1.3, 0.28, 0.65), subdiv=1, warp=0.2, seed=3.0, flat=0.3, tag=3)
    tidy(p)
    return p.paint(prop_colour(seed, 3.6), PAL)


def effigy(name, seed):
    """The Frozen Effigy: an armoured warrior caught mid-stride, half-sunk in slabs of ice. About 2.7 m."""
    p = Part(name, seed)
    p.use(mat=MATTE)
    p.box((0, 0.1, 0), (1.5, 0.2, 1.5), taper=0.9, tag=12)
    for sx in (-1, 1):
        p.limb((sx * 0.22, 0.2, 0.0), (sx * 0.24, 1.0, sx * 0.12), 0.16, 0.14, sides=5, tag=12)
        p.box((sx * 0.25, 0.1, 0.18), (0.22, 0.14, 0.4), tag=12)
    p.box((0, 1.35, 0), (0.7, 0.9, 0.42), taper=1.15, tag=12)
    p.box((0, 1.0, 0), (0.62, 0.22, 0.4), tag=4)
    for sx in (-1, 1):
        p.box((sx * 0.46, 1.68, 0), (0.34, 0.2, 0.36), tilt=(0.0, sx * 0.3), tag=12)
        p.limb((sx * 0.46, 1.6, 0.0), (sx * 0.55, 1.2, 0.35), 0.1, 0.09, sides=5, tag=12)
    p.limb((0.55, 0.0, 0.5), (0.5, 2.7, 0.35), 0.045, 0.03, sides=4, tag=4)
    p.crystal((0.5, 2.55, 0.35), (0.0, 1.0, 0.0), 0.28, 0.07, sides=4, tag=4)
    p.box((0, 2.0, 0), (0.32, 0.38, 0.34), taper=0.85, tag=12)
    for sx in (-1, 1):
        p.crystal((sx * 0.16, 2.12, 0), (sx * 0.9, 0.6, 0.0), 0.5, 0.05, sides=4, tag=11)
    p.use(mat=ICE)
    for k, (x, z, w, h, tl) in enumerate([(-0.45, 0.38, 0.7, 1.5, 0.12), (0.4, 0.4, 0.65, 1.1, -0.1), (0.0, -0.4, 0.9, 1.9, 0.05), (-0.5, -0.1, 0.55, 2.2, -0.12), (0.52, -0.15, 0.5, 1.7, 0.1)]):
        p.box((x, h / 2, z), (w, h, w * 0.7), yaw=k * 0.9, tilt=(tl, tl), taper=0.5, tag=6)
    tidy(p)
    return p.paint(prop_colour(seed, 2.7), PAL)


def throne(name, seed):
    """The Glacier Throne: a stepped stone dais carrying a high-backed seat cut from ice, spires behind.
    About 7 m across, 5.5 m tall; the seat faces +z. Two surfaces: matte dais, glossy ice."""
    p = Part(name, seed)
    p.use(mat=MATTE)
    for k, (r, h) in enumerate(((3.6, 0.3), (3.0, 0.3), (2.4, 0.3))):
        rings = [p.ring(8, r, k * 0.3, jit=0.05, phase=0.2), p.ring(8, r * 0.96, (k + 1) * 0.3, jit=0.05, phase=0.2)]
        p.loft(rings, cap_lo=(k == 0), cap_hi=True, tag=5)
    p.use(mat=ICE)
    y0 = 0.9
    p.box((0, y0 + 0.45, -0.3), (2.6, 0.9, 1.8), taper=0.96, tag=6)           # seat
    p.box((0, y0 + 2.4, -1.0), (2.8, 4.8, 0.8), taper=0.7, tilt=(-0.04, 0.0), tag=6)   # back
    for sx in (-1, 1):
        p.box((sx * 1.55, y0 + 0.7, -0.3), (0.6, 1.4, 1.9), taper=0.8, tag=6)   # arms
        p.crystal((sx * 1.8, y0 + 0.1, -1.2), (sx * 0.25, 1.0, -0.1), 4.6, 0.55, sides=6, tag=6)
        p.crystal((sx * 2.7, 0.3, -0.9), (sx * 0.4, 1.0, -0.1), 3.4, 0.42, sides=6, tag=6)
        p.crystal((sx * 0.9, y0 + 4.5, -1.0), (sx * 0.2, 1.0, 0.0), 1.1, 0.2, sides=5, tag=6)
    p.crystal((0, y0 + 4.5, -1.0), (0.0, 1.0, 0.0), 1.2, 0.24, sides=5, tag=6)
    p.lump((0, y0 + 0.95, -0.3), (0.9, 0.12, 0.7), subdiv=1, warp=0.2, seed=1.0, flat=0.2, tag=3)
    tidy(p)
    return p.paint(prop_colour(seed, 5.5), PAL)


def build():
    global PAL
    K.reset()
    PAL = Palette("rime")
    objs = []
    for nm, sd, sides, lean, bump in (("cliff_a", 40, 9, (0.5, 0.0), [(0.6, 0.55, 1.9)]),
                                      ("cliff_b", 57, 10, (-0.4, 0.3), [(2.4, 0.6, 1.5), (4.4, 0.45, 2.3)]),
                                      ("cliff_c", 74, 11, (0.1, -0.5), [(3.8, 0.7, 2.0)])):
        objs.append(cliff(nm, sd, sides, lean, bump))
    objs.append(boulder("boulder_a", 11, (0.95, 0.75, 0.85), True))
    objs.append(boulder("boulder_b", 12, (0.85, 0.6, 1.0), False))
    for nm, sd, ns, tl in (("crystal_a", 31, 4, 1.0), ("crystal_b", 32, 3, 0.9), ("crystal_c", 33, 5, 1.1), ("crystal_d", 34, 4, 0.8)):
        objs.append(crystals(nm, sd, ns, tl))
    objs.append(ice_block("ice_block", 7, False))
    objs.append(ice_block("ice_block_broken", 8, True))
    for nm, sd, h in (("pine_a", 1, 1.0), ("pine_b", 2, 1.15), ("pine_c", 3, 0.9)):
        objs.append(pine(nm, sd, h))
    objs.append(longship("longship", 3))
    objs.append(hut("hut", 4))
    objs.append(sled("sled", 5))
    objs.append(snow_bank("snow_bank_a", 21, 1.6, 1.1))
    objs.append(snow_bank("snow_bank_b", 22, 1.1, 1.3))
    objs.append(hole_rim("hole_rim", 23))
    objs.append(ice_arch("ice_arch", 24))
    objs.append(effigy("effigy", 25))
    objs.append(throne("throne", 26))
    return objs


if __name__ == "__main__":
    objs = build()
    K.export("rime", objs, PAL, OUT)
