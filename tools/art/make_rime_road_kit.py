"""The Rimehollow Long Road room kit: glacier wall faces, rock ramparts, gate posts, ice pillars,
boss-hall spires, a frozen standard, a skull cairn, buried crates and a frost beacon.
Palette-textured static meshes, feet at y = 0, modelled in Godot axes (see kit_lib.py); the colours and
helpers are the Rimehollow kit's (make_rime_kit.py) on a palette of their own.
Run: tools/art/blender.sh tools/art/make_rime_road_kit.py
Writes assets/kits/rime/road_kit.glb. Deterministic."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit_lib as K
import make_rime_kit as R
from kit_lib import Part, Palette, ramp, mix, shade, n3, b2g, MATTE, ICE, CRYSTAL
from mathutils import Vector

OUT = os.path.join(K.ROOT, "assets", "kits", "rime", "road_kit.glb")


def done(p, seed, height):
    R.tidy(p)
    base = R.prop_colour(seed, height)

    def fn(tag, c, n, i):
        if tag == 13:
            return ramp(R.CRYS, 0.15 + 0.8 * min(c.y / height, 1.0) + 0.1 * n3(c, seed, 2.1))
        return base(tag, c, n, i)
    return p.paint(fn, PAL)


def face_slab(p, cx, cz, rx, rz, y0, y1, seed_off, taper, snow=True, tag=5):
    """One stratum of a wall face: an elongated jittered prism, with a snow pillow on top."""
    n = 8
    rings = [p.ring(n, 1.0, y0, off=(cx, cz), phase=seed_off, jit=0.12, sx=rx, sz=rz),
             p.ring(n, 1.0, (y0 + y1) / 2, off=(cx, cz), phase=seed_off + 0.15, jit=0.12, yjit=0.08, sx=rx * (1 + taper) / 2, sz=rz * (1 + taper) / 2),
             p.ring(n, 1.0, y1, off=(cx, cz), phase=seed_off + 0.3, jit=0.14, yjit=0.06, sx=rx * taper, sz=rz * taper)]
    p.loft(rings, cap_lo=y0 <= 0.01, tag=tag)
    top = rings[-1]
    if snow:
        c = Vector((cx, y1, cz))
        rim = [p.v(c + (b2g(v.co) - c) * Vector((0.8, 0, 0.8)) + Vector((0, 0.22 + p.rng.uniform(0.0, 0.1), 0))) for v in top]
        for k in range(n):
            j = (k + 1) % n
            p.quad(top[k], top[j], rim[j], rim[k], tag=3)
        p.face(list(rim), tag=3)
    else:
        p.face(list(top), tag=tag)


def wall(name, seed, lean):
    """A glacier face for the road's side walls: 4.6 m wide along x, 4.8 m tall, 3 m deep, ledges of rock
    stepping back with snow on each, a few ice shards in the cracks."""
    p = Part(name, seed)
    r = p.rng
    face_slab(p, 0.0, 0.0, 2.3, 1.5, 0.0, 2.0, seed * 0.1, 0.8)
    face_slab(p, lean * 0.4, -0.3, 1.8, 1.15, 1.9, 3.5, seed * 0.2, 0.75)
    face_slab(p, lean * 0.8, -0.6, 1.1, 0.8, 3.4, 4.7, seed * 0.3, 0.55)
    for sx in (-1, 1):
        face_slab(p, sx * 1.9, 0.5, 0.9, 0.8, 0.0, r.uniform(1.0, 1.5), seed * 0.4 + sx, 0.75)
    p.use(mat=ICE)
    for k in range(4):
        x = r.uniform(-1.6, 1.6)
        p.crystal((x, 0.9 + r.uniform(0.0, 1.4), 1.3 - 0.3 * (k % 2)), (r.uniform(-0.3, 0.3), 0.5, 1.0), r.uniform(0.5, 0.9), 0.1, sides=4, tag=6)
    return done(p, seed, 4.8)


def rampart(name, seed, n, shard):
    """A low rock rampart section 2.4 m long along x, 1.4 m tall: piled slabs under a snow cap; `shard` adds
    ice spikes along the top."""
    p = Part(name, seed)
    r = p.rng
    for k in range(n):
        f = (k + 0.5) / n
        face_slab(p, (f - 0.5) * 2.1, r.uniform(-0.12, 0.12), 0.62 + r.uniform(0.0, 0.12), 0.5, 0.0, r.uniform(0.9, 1.35), seed + k, 0.7)
    face_slab(p, 0.0, 0.0, 1.0, 0.45, 0.0, 0.8, seed, 0.85, snow=True)
    if shard:
        p.use(mat=ICE)
        for k in range(3):
            p.crystal(((k - 1) * 0.7, 1.05, r.uniform(-0.1, 0.1)), (r.uniform(-0.2, 0.2), 1.0, 0.1), r.uniform(0.5, 0.8), 0.1, sides=4, tag=6)
    return done(p, seed, 1.5)


def gate_post(name, seed):
    """A gate post at the gap in a divider: a tapering stone pylon with an iron band, a crystal cap and a
    tattered pennant. About 2.9 m."""
    p = Part(name, seed)
    r = p.rng
    p.box((0, 0.12, 0), (1.2, 0.24, 1.2), taper=0.92, tag=5)
    p.box((0, 1.1, 0), (0.86, 1.8, 0.86), taper=0.8, tilt=(0.01, 0.01), tag=5)
    p.box((0, 1.5, 0), (0.78, 0.12, 0.78), tag=4)
    p.box((0, 1.0, 0), (0.7, 0.1, 0.7), tag=4)
    p.box((0, 2.08, 0), (0.62, 0.2, 0.62), taper=1.18, tag=5)
    p.lump((0, 2.2, 0), (0.42, 0.1, 0.42), subdiv=1, warp=0.2, seed=2.0, flat=0.2, tag=3)
    p.use(mat=CRYSTAL)
    p.crystal((0, 2.15, 0), (0.05, 1.0, 0.0), 0.75, 0.2, sides=5, tag=13)
    p.crystal((0.18, 2.15, 0.1), (0.5, 1.0, 0.2), 0.42, 0.1, sides=4, tag=13)
    p.use(mat=MATTE)
    p.limb((0.46, 1.9, 0.0), (0.46, 0.7, 0.0), 0.02, 0.02, sides=3, tag=4)
    p.quad(p.v(0.46, 1.85, 0.01), p.v(0.9, 1.7, 0.01), p.v(0.82, 1.2, 0.01), p.v(0.46, 1.1, 0.01), tag=7)
    return done(p, seed, 2.9)


def pillar(name, seed, h, sides, shards):
    """An ice pillar to fight round: a rough stone footing, a faceted column of ice, a broken top."""
    p = Part(name, seed)
    r = p.rng
    p.use(mat=MATTE)
    rings = [p.ring(7, 1.25, 0.0, jit=0.1), p.ring(7, 1.0, 0.45, jit=0.12, yjit=0.05)]
    p.loft(rings, cap_lo=True, cap_hi=False, tag=5)
    p.lump((0, 0.5, 0), (0.95, 0.2, 0.95), subdiv=1, warp=0.2, seed=seed, flat=0.2, tag=3)
    p.use(mat=ICE)
    rg = [p.ring(sides, 0.78, 0.4, jit=0.05), p.ring(sides, 0.7, h * 0.4, phase=0.1, jit=0.1, yjit=0.1),
          p.ring(sides, 0.55, h * 0.75, phase=0.2, jit=0.12, yjit=0.15), p.ring(sides, 0.3, h, phase=0.3, jit=0.3, yjit=0.2)]
    p.loft(rg, cap_hi=True, tag=6)
    for k in range(shards):
        a = r.uniform(0, math.tau)
        p.crystal((math.cos(a) * 0.62, 0.45, math.sin(a) * 0.62), (math.cos(a) * 0.5, 1.0, math.sin(a) * 0.5), r.uniform(0.9, 1.5), 0.2, sides=4, tag=6)
    return done(p, seed, h)


def spire(name, seed, h, n):
    """A boss-hall spire: a crag of dark rock carrying a tall crystal fang and a few lesser ones. 5-6 m."""
    p = Part(name, seed)
    r = p.rng
    p.use(mat=MATTE)
    face_slab(p, 0.0, 0.0, 1.6, 1.4, 0.0, 1.6, seed * 0.1, 0.7, tag=12)
    face_slab(p, 0.15, 0.0, 1.1, 1.0, 1.5, 2.5, seed * 0.2, 0.6, tag=12)
    p.use(mat=CRYSTAL)
    p.crystal((0.0, 1.5, 0.0), (0.06, 1.0, 0.03), h - 1.5, 0.52, sides=6, tag=13)
    for k in range(n):
        a = math.tau * k / n + r.uniform(-0.3, 0.3)
        p.crystal((math.cos(a) * 0.9, 1.0, math.sin(a) * 0.9), (math.cos(a) * 0.55, 1.0, math.sin(a) * 0.55), r.uniform(1.8, 2.8), 0.3, sides=5, tag=13)
    return done(p, seed, h)


def standard(name, seed):
    """A frozen war-standard: a leaning pole in a cairn of stones, a tattered banner, a skull. About 3.4 m."""
    p = Part(name, seed)
    r = p.rng
    for k in range(5):
        a = math.tau * k / 5
        p.lump((math.cos(a) * 0.4, 0.14, math.sin(a) * 0.4), (0.26, 0.2, 0.24), subdiv=1, warp=0.3, seed=seed + k, flat=0.3, tag=5)
    p.limb((0, 0.0, 0), (0.12, 3.2, 0), 0.07, 0.05, sides=5, tag=2)
    p.limb((0.12, 3.15, 0), (0.12, 3.4, 0), 0.04, 0.02, sides=4, tag=4)
    p.limb((0.12, 2.95, 0), (0.95, 2.95, 0), 0.03, 0.03, sides=4, tag=2)
    pts = [(0.12, 2.9), (0.5, 2.88), (0.95, 2.92)]
    lo = [(0.12, 1.7), (0.5, 1.9), (0.8, 1.95), (0.95, 2.2)]
    for k in range(2):
        a0, a1 = pts[k], pts[k + 1]
        b0, b1 = lo[k], lo[k + 1]
        p.quad(p.v(a0[0], a0[1], 0.0), p.v(a1[0], a1[1], 0.0), p.v(b1[0], b1[1] + 0.2, 0.0), p.v(b0[0], b0[1], 0.0), tag=7)
        p.quad(p.v(a1[0], a1[1], 0.01), p.v(a0[0], a0[1], 0.01), p.v(b0[0], b0[1], 0.01), p.v(b1[0], b1[1] + 0.2, 0.01), tag=7)
    p.tri(p.v(0.6, 1.9, 0.0), p.v(0.8, 1.95, 0.0), p.v(0.7, 1.35, 0.0), tag=7)
    p.tri(p.v(0.8, 1.95, 0.01), p.v(0.6, 1.9, 0.01), p.v(0.7, 1.35, 0.01), tag=7)
    p.lump((0.12, 3.1, 0.06), (0.14, 0.15, 0.15), subdiv=1, warp=0.2, seed=seed, tag=11)
    p.lump((0.1, 0.6, 0.0), (0.4, 0.16, 0.35), subdiv=1, warp=0.2, seed=seed, flat=0.2, tag=3)
    return done(p, seed, 3.4)


def cairn(name, seed):
    """A skull cairn: stones heaped into a cone, skulls pressed into it, a horn on top. About 1.5 m."""
    p = Part(name, seed)
    r = p.rng
    for k, (ra, y, rr) in enumerate(((0.62, 0.22, 0.4), (0.42, 0.55, 0.34), (0.2, 0.86, 0.3), (0.0, 1.12, 0.26))):
        for j in range(5 if ra > 0.1 else 1):
            a = math.tau * j / 5 + k
            p.lump((math.cos(a) * ra, y, math.sin(a) * ra), (rr, rr * 0.8, rr), subdiv=1, warp=0.3, seed=seed + k * 7 + j, flat=0.2, tag=5 if (j + k) % 3 else 12)
    for k, (a, y, rr) in enumerate(((0.3, 0.45, 0.62), (2.4, 0.38, 0.66), (4.3, 0.6, 0.45))):
        p.lump((math.cos(a) * rr, y, math.sin(a) * rr), (0.15, 0.16, 0.16), subdiv=1, warp=0.2, seed=seed + k, tag=11)
    p.crystal((0, 1.3, 0), (0.1, 1.0, 0.1), 0.45, 0.07, sides=4, tag=11)
    p.lump((0, 1.4, 0), (0.3, 0.1, 0.3), subdiv=1, warp=0.2, seed=2.0, flat=0.2, tag=3)
    return done(p, seed, 1.5)


def crates(name, seed):
    """Supplies half-buried in snow: two crates, a barrel, a sack, a drift over them. About 1.1 m."""
    p = Part(name, seed)
    r = p.rng
    p.box((-0.3, 0.3, 0.0), (0.75, 0.6, 0.7), yaw=0.2, tag=1)
    p.box((0.4, 0.25, -0.2), (0.6, 0.5, 0.6), yaw=-0.3, tag=2)
    p.box((0.05, 0.85, -0.05), (0.55, 0.5, 0.55), yaw=0.9, tag=1)
    for yy in (0.15, 0.45):
        p.box((-0.3, yy + 0.15, 0.0), (0.8, 0.05, 0.75), yaw=0.2, tag=4)
    rings = [p.ring(8, 0.3, 0.0, off=(0.3, 0.55)), p.ring(8, 0.34, 0.4, off=(0.3, 0.55)), p.ring(8, 0.3, 0.8, off=(0.3, 0.55))]
    p.loft(rings, cap_lo=True, cap_hi=True, tag=2)
    for yy in (0.2, 0.62):
        p.loft([p.ring(8, 0.35, yy - 0.025, off=(0.3, 0.55)), p.ring(8, 0.35, yy + 0.025, off=(0.3, 0.55))], tag=4)
    p.lump((0.0, 0.1, 0.2), (0.9, 0.4, 0.8), subdiv=1, warp=0.25, seed=seed, flat=0.5, tag=3)
    p.lump((-0.5, 0.55, -0.1), (0.4, 0.2, 0.4), subdiv=1, warp=0.25, seed=seed + 1, flat=0.4, tag=3)
    return done(p, seed, 1.2)


def beacon(name, seed):
    """A frost beacon: an iron post, a cage of three bars, a crystal burning cold inside. About 2.3 m."""
    p = Part(name, seed)
    p.box((0, 0.1, 0), (0.7, 0.2, 0.7), taper=0.8, tag=5)
    p.limb((0, 0.0, 0), (0, 1.5, 0), 0.07, 0.05, sides=5, tag=4)
    p.box((0, 1.52, 0), (0.5, 0.06, 0.5), tag=4)
    for k in range(3):
        a = math.tau * k / 3
        d = (math.cos(a) * 0.22, math.sin(a) * 0.22)
        p.limb((d[0], 1.55, d[1]), (d[0] * 0.5, 2.2, d[1] * 0.5), 0.025, 0.02, sides=3, tag=4)
    p.use(mat=CRYSTAL)
    p.crystal((0, 1.58, 0), (0.0, 1.0, 0.0), 0.55, 0.14, sides=5, tag=13)
    p.crystal((0.07, 1.58, 0.05), (0.4, 1.0, 0.3), 0.3, 0.07, sides=4, tag=13)
    return done(p, seed, 2.3)


def build():
    global PAL
    K.reset()
    PAL = Palette("rime_road")
    R.PAL = PAL
    objs = []
    for nm, sd, ln in (("wall_a", 41, 0.3), ("wall_b", 58, -0.3), ("wall_c", 75, 0.1)):
        objs.append(wall(nm, sd, ln))
    objs.append(rampart("rampart_a", 11, 3, False))
    objs.append(rampart("rampart_b", 12, 3, True))
    objs.append(rampart("rampart_c", 13, 4, True))
    objs.append(gate_post("gate_post", 14))
    objs.append(pillar("pillar_a", 21, 3.4, 6, 3))
    objs.append(pillar("pillar_b", 22, 2.7, 5, 2))
    objs.append(pillar("pillar_c", 23, 2.1, 6, 2))
    objs.append(spire("spire_a", 31, 5.4, 4))
    objs.append(spire("spire_b", 32, 6.3, 3))
    objs.append(standard("standard", 33))
    objs.append(cairn("cairn", 34))
    objs.append(crates("crates", 35))
    objs.append(beacon("beacon", 36))
    return objs


if __name__ == "__main__":
    objs = build()
    K.export("rime_road", objs, PAL, OUT)
