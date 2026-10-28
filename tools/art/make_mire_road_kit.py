"""The Cinder Mire Long Road room kit: bog-rock wall faces, sharpened palisades, a gate post with a coal
basket, a burnt watchtower, a gibbet cage, barricades, tar barrels, supply crates, ash rocks, dead snags
and a fire pit. Palette-textured static meshes, feet at y = 0, modelled in Godot axes (see kit_lib.py);
the colours and helpers are the Mire kit's (make_mire_kit.py) on a palette of their own.
Run: tools/art/blender.sh tools/art/make_mire_road_kit.py
Writes assets/kits/mire/road_kit.glb. Deterministic."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit_lib as K
import make_mire_kit as M
from kit_lib import Part, Palette, ramp, n3, b2g, MATTE, CRYSTAL
from mathutils import Vector

OUT = os.path.join(K.ROOT, "assets", "kits", "mire", "road_kit.glb")
GLOW = CRYSTAL


def done(p, seed, h):
    return M.paint(p, seed, h)


def stake(p, x, z, h, lean=(0.0, 0.0), r=0.1, tag=2):
    """A sharpened stake: a tapering post with a pointed head."""
    p.limb((x, -0.15, z), (x + lean[0], h - 0.3, z + lean[1]), r, r * 0.8, sides=5, tag=tag)
    p.crystal((x + lean[0], h - 0.32, z + lean[1]), (lean[0] * 0.3, 1.0, lean[1] * 0.3), 0.36, r * 0.8, sides=5, shoulder=0.4, tag=3)


def rock_slab(p, cx, cz, rx, rz, y0, y1, ph, taper, tag=6):
    n = 8
    rings = [p.ring(n, 1.0, y0, off=(cx, cz), phase=ph, jit=0.14, sx=rx, sz=rz),
             p.ring(n, 1.0, (y0 + y1) / 2, off=(cx, cz), phase=ph + 0.15, jit=0.16, yjit=0.08, sx=rx * (1 + taper) / 2, sz=rz * (1 + taper) / 2),
             p.ring(n, 1.0, y1, off=(cx, cz), phase=ph + 0.3, jit=0.16, yjit=0.07, sx=rx * taper, sz=rz * taper)]
    p.loft(rings, cap_lo=y0 <= 0.01, cap_hi=True, tag=tag)


def wall(name, seed, lean):
    """A wall of bog rock for the road's sides: 4.6 wide, 5 tall, 3.4 deep; soot-black ledges, a char streak
    and thin seams of ember in the cracks."""
    p = Part(name, seed)
    r = p.rng
    rock_slab(p, 0.0, 0.0, 2.3, 1.6, 0.0, 2.2, seed * 0.1, 0.8)
    rock_slab(p, lean * 0.4, -0.3, 1.8, 1.2, 2.1, 3.8, seed * 0.2, 0.74)
    rock_slab(p, lean * 0.8, -0.6, 1.15, 0.85, 3.7, 5.0, seed * 0.3, 0.5)
    for sx in (-1, 1):
        rock_slab(p, sx * 2.0, 0.6, 0.95, 0.8, 0.0, r.uniform(1.2, 1.8), seed * 0.4 + sx, 0.72)
    for k in range(4):
        x = r.uniform(-1.4, 1.4)
        y = 0.8 + k * 0.8 + r.uniform(0.0, 0.3)
        a = Vector((x, y, 1.45 - 0.2 * min(y, 3.0) / 3.0 + 0.0))
        b = Vector((x + r.uniform(-0.3, 0.3), y + 0.7, a.z - 0.1))
        w = Vector((0.05, 0, 0))
        p.quad(p.v(a - w), p.v(a + w), p.v(b + w * 0.6), p.v(b - w * 0.6), tag=9, mat=GLOW)
    return done(p, seed, 5.0)


def palisade(name, seed, mode):
    """A palisade section 2.4 m wide along x: sharpened stakes of uneven height, two lashed cross-rails.
    mode 0 plain, 1 leaning and gap-toothed, 2 with a skull on a stake."""
    p = Part(name, seed)
    r = p.rng
    n = 6 if mode == 0 else 5
    for k in range(n):
        if mode == 1 and k == 3:
            continue
        x = -1.05 + 2.1 * k / (n - 1)
        h = r.uniform(2.1, 2.7) if mode != 1 else r.uniform(1.4, 2.5)
        lean = (r.uniform(-0.04, 0.04), r.uniform(-0.03, 0.03)) if mode != 1 else (r.uniform(-0.2, 0.2), r.uniform(-0.1, 0.1))
        stake(p, x, 0.0, h, lean, 0.11, tag=2 if k % 2 else 1)
    for y in (0.7, 1.45):
        p.box((0.0, y, -0.15), (2.35, 0.09, 0.07), tilt=(0.0, r.uniform(-0.03, 0.03)), tag=2)
        for k in range(0, n, 2):
            x = -1.05 + 2.1 * k / (n - 1)
            p.box((x, y, -0.15), (0.2, 0.15, 0.1), tag=10)
    if mode == 2:
        p.limb((0.55, 2.4, 0.1), (0.55, 2.9, 0.1), 0.03, 0.02, sides=3, tag=2)
        p.lump((0.55, 3.0, 0.1), (0.16, 0.17, 0.17), subdiv=1, warp=0.2, seed=seed, tag=8)
    return done(p, seed, 2.8)


def gate_post(name, seed):
    """A gate post at the gap in a divider: a thick charred post, an arm carrying an iron coal basket, a skull
    on a spike. About 3.6 m; the basket's coals glow, the flame on them is the arena's."""
    p = Part(name, seed)
    p.lump((0, 0.12, 0), (0.55, 0.2, 0.55), subdiv=1, warp=0.3, seed=seed, flat=0.2, tag=6)
    p.limb((0, -0.1, 0), (0.04, 3.4, 0), 0.21, 0.16, sides=6, tag=3)
    for y in (0.9, 1.7, 2.5):
        p.box((0.0, y, 0.0), (0.46, 0.08, 0.46), tag=4)
    p.limb((0.04, 3.2, 0), (0.0, 3.7, 0), 0.04, 0.02, sides=3, tag=4)
    p.lump((0.0, 3.8, 0.0), (0.17, 0.18, 0.18), subdiv=1, warp=0.2, seed=seed, tag=8)
    p.limb((0.15, 2.9, 0), (0.95, 2.95, 0), 0.07, 0.06, sides=4, tag=2)
    M.chain(p, [(0.9, 2.95, 0), (0.9, 2.6, 0)], 0.025, 0.025, sides=3, tag=4)
    for k in range(4):
        a = math.tau * k / 4
        p.limb((0.9 + math.cos(a) * 0.1, 2.4, math.sin(a) * 0.1), (0.9 + math.cos(a) * 0.3, 2.62, math.sin(a) * 0.3), 0.02, 0.02, sides=3, tag=4)
    lo = p.ring(8, 0.12, 2.38, off=(0.9, 0.0))
    rim = p.ring(8, 0.3, 2.62, off=(0.9, 0.0))
    p.loft([lo, rim], cap_lo=True, tag=4)
    p.face(p.ring(8, 0.27, 2.6, off=(0.9, 0.0), jit=0.05, yjit=0.03), tag=9, mat=GLOW)
    p.crystal((0.9, 2.6, 0.0), (0.1, 1.0, 0.0), 0.16, 0.08, sides=4, tag=9, mat=GLOW)
    return done(p, seed, 3.8)


def watchtower(name, seed):
    """A burnt stilt watchtower: four charred legs braced with beams, a platform with a broken rail, a half
    roof, a ladder. About 3.8 x 3.8 x 6.2 m."""
    p = Part(name, seed)
    r = p.rng
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.limb((sx * 1.5, -0.2, sz * 1.5), (sx * 1.1, 3.6, sz * 1.1), 0.17, 0.13, sides=5, tag=3)
            p.lump((sx * 1.5, 0.1, sz * 1.5), (0.4, 0.15, 0.4), subdiv=1, warp=0.3, seed=seed + sx + sz, flat=0.2, tag=6)
    for y in (1.2, 2.4):
        f = 1.5 - (y / 3.6) * 0.4
        for sz in (-1, 1):
            p.limb((-f, y, sz * f), (f, y + 0.6, sz * f), 0.06, 0.06, sides=4, tag=2)
        p.limb((-f, y + 0.6, -f), (f, y, f), 0.05, 0.05, sides=4, tag=2)
    p.box((0, 3.65, 0), (3.0, 0.14, 3.0), tag=2)
    for k in range(6):
        p.box((-1.25 + k * 0.5, 3.74, 0), (0.44, 0.05, 2.9), tag=1 if k % 2 else 2)
    for sx, sz, skip in ((-1, -1, False), (1, -1, False), (-1, 1, True), (1, 1, False)):
        p.limb((sx * 1.4, 3.7, sz * 1.4), (sx * 1.4, 4.9 if not skip else 4.2, sz * 1.4), 0.09, 0.07, sides=4, tag=3)
    p.limb((-1.4, 4.6, -1.4), (1.4, 4.6, -1.4), 0.05, 0.05, sides=4, tag=2)
    p.limb((1.4, 4.6, -1.4), (1.4, 4.4, 1.4), 0.05, 0.05, sides=4, tag=2)
    p.box((0.0, 5.55, -0.7), (3.4, 0.07, 1.8), tilt=(0.4, 0.03), tag=5)
    p.box((-1.0, 5.2, 0.6), (1.2, 0.07, 1.0), tilt=(-0.3, 0.2), tag=5)
    for k in range(8):
        p.limb((-0.3, 0.3 + k * 0.42, 1.65 - 0.1 * k * 0.4), (0.3, 0.3 + k * 0.42, 1.65 - 0.1 * k * 0.4), 0.025, 0.025, sides=3, tag=2)
    for sx in (-0.3, 0.3):
        p.limb((sx, 0.0, 1.8), (sx, 3.7, 1.3), 0.04, 0.04, sides=4, tag=2)
    return done(p, seed, 6.2)


def cage(name, seed):
    """A gibbet: a post, an arm, a chain and a hanging iron cage with bones in it. About 3.2 m."""
    p = Part(name, seed)
    p.lump((0, 0.1, 0), (0.45, 0.18, 0.45), subdiv=1, warp=0.3, seed=seed, flat=0.2, tag=6)
    p.limb((0, -0.1, 0), (0.0, 3.1, 0), 0.12, 0.1, sides=5, tag=2)
    p.limb((0.0, 3.0, 0), (0.9, 2.9, 0), 0.07, 0.06, sides=4, tag=2)
    p.limb((0.35, 2.95, 0), (0.05, 2.45, 0), 0.04, 0.04, sides=3, tag=2)
    M.chain(p, [(0.9, 2.9, 0), (0.9, 2.55, 0)], 0.025, 0.025, sides=3, tag=4)
    for k in range(6):
        a = math.tau * k / 6
        p.limb((0.9 + math.cos(a) * 0.42, 1.2, math.sin(a) * 0.42), (0.9 + math.cos(a) * 0.14, 2.5, math.sin(a) * 0.14), 0.022, 0.02, sides=3, tag=4)
    for y in (1.35, 1.8):
        p.loft([p.ring(6, 0.43 - (y - 1.2) * 0.2, y - 0.02, off=(0.9, 0.0)), p.ring(6, 0.43 - (y - 1.2) * 0.2, y + 0.02, off=(0.9, 0.0))], tag=4)
    p.lump((0.9, 1.45, 0), (0.17, 0.18, 0.18), subdiv=1, warp=0.2, seed=seed, tag=8)
    p.limb((0.75, 1.22, 0.1), (1.1, 1.3, -0.1), 0.03, 0.03, sides=3, tag=8)
    return done(p, seed, 3.1)


def barricade(name, seed, cart):
    """A barricade across the way, about 2.4 m wide and 1.4 m tall: sharpened stakes angled out over a
    crossbar (a), or an overturned cart with a wheel and stakes in front (b)."""
    p = Part(name, seed)
    r = p.rng
    if not cart:
        for sx in (-1, 1):
            p.limb((sx * 0.9, -0.1, 0.1), (sx * 0.9, 0.9, 0.1), 0.07, 0.06, sides=4, tag=2)
        p.limb((-0.95, 0.75, 0.1), (0.95, 0.75, 0.1), 0.06, 0.06, sides=4, tag=1)
        for k in range(6):
            x = -1.0 + 0.4 * k
            stake(p, x, -0.35 + 0.0, 1.05, lean=(0.0, 0.5), r=0.065, tag=2)
            p.limb((x, 0.3, -0.3), (x, 0.75, 0.1), 0.0, 0.0, sides=3, tag=2) if False else None
    else:
        p.box((0.0, 1.0, 0.0), (2.0, 0.12, 1.1), tilt=(0.0, 0.6), tag=2)
        for k in range(3):
            p.box((0.0, 0.8 + k * 0.01, -0.45 + k * 0.45), (2.0, 0.05, 0.4), tilt=(0.0, 0.6), tag=1)
        for sz in (-0.5, 0.5):
            p.box((0.0, 0.65, sz), (1.9, 0.5, 0.06), tilt=(0.0, 0.6), tag=2)
        rr = 0.55
        for k in range(8):
            a0, a1 = math.tau * k / 8, math.tau * (k + 1) / 8
            p.limb((1.1, 0.6 + math.sin(a0) * rr, 0.2 + math.cos(a0) * rr), (1.1, 0.6 + math.sin(a1) * rr, 0.2 + math.cos(a1) * rr), 0.05, 0.05, sides=3, tag=2)
        for k in range(4):
            a = math.tau * k / 4
            p.limb((1.1, 0.6, 0.2), (1.1, 0.6 + math.sin(a) * rr, 0.2 + math.cos(a) * rr), 0.035, 0.03, sides=3, tag=2)
        p.limb((1.1, 0.6, 0.2), (1.25, 0.6, 0.2), 0.08, 0.08, sides=4, tag=4)
        for k in range(3):
            stake(p, -0.8 + k * 0.7, 0.8, 1.0, lean=(0.0, 0.5), r=0.07, tag=2)
    return done(p, seed, 1.4)


def barrels(name, seed):
    """Three tar barrels, two upright and one on its side, iron-banded, tar crusted on the tops. About 1.2 m."""
    p = Part(name, seed)
    r = p.rng
    for ox, oz in ((-0.35, 0.0), (0.4, 0.15)):
        for k in range(2):
            pass
        rings = [p.ring(8, 0.3, 0.0, off=(ox, oz)), p.ring(8, 0.36, 0.45, off=(ox, oz)), p.ring(8, 0.3, 0.9, off=(ox, oz))]
        p.loft(rings, cap_lo=True, tag=2)
        p.face(p.ring(8, 0.28, 0.9, off=(ox, oz), jit=0.04), tag=3)
        for yy in (0.18, 0.72):
            p.loft([p.ring(8, 0.33 + (0.04 if yy < 0.5 else 0.0) * 0.0, yy - 0.025, off=(ox, oz)), p.ring(8, 0.33, yy + 0.025, off=(ox, oz))], tag=4)
    p.box((0.0, 0.3, -0.7), (0.6, 0.6, 0.78), yaw=0.2, tag=2)
    p.box((0.0, 0.3, -0.7), (0.66, 0.06, 0.82), yaw=0.2, tag=4)
    p.lump((0.0, 0.62, -0.7), (0.3, 0.07, 0.35), subdiv=1, warp=0.2, seed=seed, flat=0.2, tag=3)
    return done(p, seed, 1.2)


def crates(name, seed):
    """Supplies for the treasure room: two crates, a sack and a coil of rope, one crate burst open. About 1.2 m."""
    p = Part(name, seed)
    p.box((-0.3, 0.3, 0.0), (0.75, 0.6, 0.7), yaw=0.2, tag=1)
    p.box((0.4, 0.25, -0.2), (0.6, 0.5, 0.6), yaw=-0.3, tag=2)
    p.box((0.05, 0.85, -0.05), (0.55, 0.5, 0.55), yaw=0.9, tag=1)
    for yy in (0.15, 0.45):
        p.box((-0.3, yy + 0.15, 0.0), (0.8, 0.05, 0.75), yaw=0.2, tag=4)
    p.lump((0.35, 0.22, 0.6), (0.34, 0.24, 0.3), subdiv=1, warp=0.3, seed=seed, flat=0.3, tag=10)
    p.limb((0.35, 0.1, -0.75), (0.5, 0.1, -0.6), 0.1, 0.1, sides=6, tag=10)
    for k in range(3):
        p.box((0.4 + k * 0.1, 0.52, -0.2 + k * 0.1), (0.6, 0.04, 0.1), yaw=k, tilt=(0.4, 0.1), tag=3)
    return done(p, seed, 1.2)


def ash_rock(name, seed, rx, ry, rz):
    """A big ash rock to take cover behind, 1.1-1.6 m, black with a pale crown."""
    p = Part(name, seed)
    p.lump((0, ry * 0.4, 0), (rx, ry, rz), subdiv=2, warp=0.36, seed=seed, flat=0.45, tag=6)
    p.lump((rx * 0.5, ry * 0.2, rz * 0.3), (rx * 0.5, ry * 0.5, rz * 0.5), subdiv=1, warp=0.3, seed=seed + 5, flat=0.45, tag=3)
    return done(p, seed, ry * 1.5)


def snag(name, seed, h):
    """A dead snag for the room sides: a black bole splitting into crooked limbs, a broken crown. About 5 m."""
    p = Part(name, seed)
    r = p.rng
    top = Vector((r.uniform(-0.3, 0.3), h * 0.55, r.uniform(-0.3, 0.3)))
    M.chain(p, [(0, -0.05, 0), (0.1, h * 0.25, 0.0), tuple(top)], 0.36, 0.24, sides=6, tag=3)
    for k in range(3):
        a = math.tau * k / 3 + r.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), 0, math.sin(a)))
        p.limb((d.x * 0.1, 0.2, d.z * 0.1), (d.x * 0.9, 0.12, d.z * 0.9), 0.3, 0.08, sides=4, tag=3)
    for k in range(4):
        a = math.tau * k / 4 + r.uniform(-0.4, 0.4)
        d = Vector((math.cos(a), 0, math.sin(a)))
        s = top - Vector((0, 0.1, 0))
        m = s + d * r.uniform(0.7, 1.1) + Vector((0, r.uniform(0.7, 1.2), 0))
        e = m + d * r.uniform(0.3, 0.7) + Vector((-d.z, 0, d.x)) * r.uniform(-0.4, 0.4) + Vector((0, r.uniform(0.7, 1.3), 0))
        M.chain(p, [tuple(s), tuple(m), tuple(e)], 0.2, 0.04, sides=4, tag=3)
    p.limb(tuple(top), (top.x + 0.1, h, top.z), 0.2, 0.05, sides=4, tag=3)
    return done(p, seed, h)


def fire_pit(name, seed):
    """A road-camp fire pit: a ring of ash stones round crossed charred logs, a bed of live coals. About 0.6 m."""
    p = Part(name, seed)
    r = p.rng
    for k in range(9):
        a = math.tau * k / 9
        p.lump((math.cos(a) * 0.78, 0.17, math.sin(a) * 0.78), (0.26, 0.22, 0.25), subdiv=1, warp=0.3, seed=seed + k, flat=0.3, tag=6)
    p.face(p.ring(9, 0.62, 0.12, jit=0.08, yjit=0.02), tag=9, mat=GLOW)
    for k in range(3):
        a = math.tau * k / 3 + 0.4
        d = Vector((math.cos(a), 0, math.sin(a)))
        p.limb(tuple(d * 0.6 + Vector((0, 0.16, 0))), tuple(-d * 0.25 + Vector((0, 0.4, 0))), 0.1, 0.07, sides=4, tag=3)
    p.crystal((0, 0.12, 0), (0.1, 1.0, 0.0), 0.25, 0.12, sides=4, tag=9, mat=GLOW)
    return done(p, seed, 0.6)


def build():
    global PAL
    K.reset()
    PAL = Palette("mire_road")
    M.PAL = PAL
    objs = []
    for nm, sd, ln in (("wall_a", 71, 0.3), ("wall_b", 88, -0.3), ("wall_c", 95, 0.1)):
        objs.append(wall(nm, sd, ln))
    objs.append(palisade("palisade_a", 11, 0))
    objs.append(palisade("palisade_b", 12, 1))
    objs.append(palisade("palisade_c", 13, 2))
    objs.append(gate_post("gate_post", 14))
    objs.append(watchtower("watchtower", 15))
    objs.append(cage("cage", 16))
    objs.append(barricade("barricade_a", 17, False))
    objs.append(barricade("barricade_b", 18, True))
    objs.append(barrels("barrels", 19))
    objs.append(crates("crates", 20))
    objs.append(ash_rock("ash_rock_a", 21, 1.0, 0.9, 0.95))
    objs.append(ash_rock("ash_rock_b", 22, 0.8, 1.1, 0.85))
    objs.append(snag("snag_a", 23, 5.2))
    objs.append(snag("snag_b", 24, 4.4))
    objs.append(fire_pit("fire_pit", 25))
    return objs


if __name__ == "__main__":
    objs = build()
    K.export("mire_road", objs, PAL, OUT)
