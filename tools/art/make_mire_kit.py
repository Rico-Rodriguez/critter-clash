"""The Cinder Mire prop kit: boardwalk planks, piles, rails, a rope bridge, the jetty and boat shed,
stilt shacks, the Pyre Tree, the stilted forge with its cauldron, braziers, reeds, bog stones,
dead mangroves, charred stumps, a wrecked riverboat and a skull totem.
Palette-textured static meshes, feet at y = 0, modelled in Godot axes (see kit_lib.py). Flames, light and
smoke are the arena's particles; the glowing coals and seams are the kit's third material (ember).
Run: tools/art/blender.sh tools/art/make_mire_kit.py
Writes assets/kits/mire/mire_kit.glb. Deterministic."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit_lib as K
from kit_lib import Part, Palette, hexc, ramp, mix, shade, n3, b2g, MATTE, ICE, CRYSTAL
from mathutils import Vector

OUT = os.path.join(K.ROOT, "assets", "kits", "mire", "mire_kit.glb")
GLOW = CRYSTAL   # the third material carries the ember emission

# Black, wet, smouldering. Wood is grey-brown and old; the fire is the only warm colour.
WOOD = ["#1a1612", "#2e2822", "#483f35", "#6e6050"]
CHAR = ["#070606", "#100e0d", "#1b1816", "#2c2723"]
ASHC = ["#0e0e0e", "#1a1a19", "#2b2a27", "#43403a"]
IRON = ["#121316", "#22252a", "#3a3e45"]
RUST = ["#150e0b", "#221510", "#33211a"]
EMB = ["#7a1e04", "#c4400a", "#ff7a1a", "#ffc060"]
REED = ["#1d180c", "#32280f", "#4e401a", "#6e5c2a"]
BONE = ["#352f27", "#6a6354", "#948b76"]
ROPE = ["#1c160e", "#3a2f1e", "#5a4a30"]


def tidy(p):
    import bmesh
    bmesh.ops.triangulate(p.bm, faces=list(p.bm.faces), quad_method='BEAUTY', ngon_method='BEAUTY')


def colour(seed, height=3.0):
    """Tags: 1 wood, 2 dark wood, 3 char, 4 iron, 5 rust, 6 ash stone, 7 reed, 8 bone, 9 ember (glow), 10 rope."""
    def fn(tag, c, n, i):
        j = n3(c, seed, 2.3)
        j2 = n3(c, seed + 7.0, 3.7)
        up = max(n.y, 0.0)
        if tag == 9:
            return ramp(EMB, 0.12 + 0.4 * (0.5 + 0.5 * j2) + 0.2 * min(c.y / max(height, 1.0), 1.0))
        if tag == 3:
            if j2 > 0.82:
                return ramp(EMB, 0.12 + 0.2 * j)
            return ramp(CHAR, 0.12 + 0.4 * (0.5 + 0.5 * j) + 0.25 * up)
        if tag == 4:
            return ramp(IRON, 0.25 + 0.3 * j + 0.3 * up)
        if tag == 5:
            return ramp(RUST, 0.2 + 0.4 * (0.5 + 0.5 * j) + 0.2 * up)
        if tag == 6:
            return ramp(ASHC, 0.15 + 0.35 * (0.5 + 0.5 * j) + 0.3 * up + 0.12 * min(c.y / height, 1.0))
        if tag == 7:
            return ramp(REED, 0.15 + 0.5 * min(c.y / height, 1.0) + 0.2 * j)
        if tag == 8:
            return ramp(BONE, 0.25 + 0.3 * j + 0.3 * up)
        if tag == 10:
            return ramp(ROPE, 0.3 + 0.4 * j)
        grain = 0.5 + 0.5 * math.sin(c.x * 11.0 + c.z * 5.0 + j * 2.5)
        t = 0.26 + 0.3 * grain * (1.0 if tag == 1 else 0.5) + 0.12 * j + 0.12 * up
        return ramp(WOOD, t * (0.55 if tag == 2 else 1.0))
    return fn


def paint(p, seed, height):
    tidy(p)
    return p.paint(colour(seed, height), PAL)


def chain(p, pts, r0, r1, sides=4, **kw):
    """A bent limb through the points, tapering r0 -> r1."""
    n = len(pts) - 1
    for k in range(n):
        ra = r0 + (r1 - r0) * k / n
        rb = r0 + (r1 - r0) * (k + 1) / n
        p.limb(pts[k], pts[k + 1], ra, rb, sides=sides, **kw)


# -- boardwalk ---------------------------------------------------------------------------

def plank(name, seed, mode="straight"):
    """One 2 x 2 m cell of boardwalk, the top about 0.2 m over the bog. Boards run along x (straight, end),
    bearers across them; the burn swap is the arena's (charred override over this one material).
    straight: opens -x, +x. end: opens -x, a post and beam close +x. corner: opens -x, +z.
    tee: opens -x, +x, +z (the +z branch's boards run along x)."""
    p = Part(name, seed)
    r = p.rng
    top = 0.17

    def board(cx, cz, lx, lz, tag=None):
        p.box((cx + r.uniform(-0.02, 0.02), top + r.uniform(-0.012, 0.012), cz), (lx, 0.09, lz), yaw=r.uniform(-0.025, 0.025),
              tilt=(r.uniform(-0.02, 0.02), r.uniform(-0.02, 0.02)), tag=tag if tag else (1 if r.random() < 0.6 else 2))

    def run_x(x0, x1, z0, z1, rows):
        w = (z1 - z0) / rows
        for k in range(rows):
            z = z0 + (k + 0.5) * w
            if x1 - x0 > 1.5:
                cut = (x0 + x1) / 2 + r.uniform(-0.3, 0.3)
                board((x0 + cut) / 2 - 0.01, z, cut - x0 - 0.03, w - 0.05)
                board((cut + x1) / 2 + 0.01, z, x1 - cut - 0.03, w - 0.05)
            else:
                board((x0 + x1) / 2, z, x1 - x0 - 0.02, w - 0.05)

    def run_z(z0, z1, x0, x1, cols):
        w = (x1 - x0) / cols
        for k in range(cols):
            x = x0 + (k + 0.5) * w
            board(x, (z0 + z1) / 2, w - 0.05, z1 - z0 - 0.02)

    if mode in ("straight", "end"):
        run_x(-1.0, 1.0 if mode == "straight" else 0.78, -1.0, 1.0, 4)
        for sx in (-0.62, 0.62):
            if mode == "end" and sx > 0.6:
                continue
            p.box((sx, 0.09, 0.0), (0.2, 0.14, 2.02), tag=3)
        if mode == "end":
            p.box((0.62, 0.09, 0.0), (0.2, 0.14, 1.8), tag=3)
            p.box((0.9, 0.3, 0.0), (0.22, 0.34, 2.0), tag=2)
            for sz in (-0.85, 0.85):
                p.limb((0.9, -0.1, sz), (0.9, 0.9, sz), 0.1, 0.08, sides=5, tag=3)
            p.limb((0.9, 0.8, -0.85), (0.9, 0.6, 0.85), 0.03, 0.03, sides=4, tag=10)
    elif mode == "corner":
        run_z(-1.0, 1.0, -1.0, 0.0, 2)
        run_x(0.0, 1.0, -1.0, 1.0, 4)
        p.box((-0.5, 0.09, -0.62), (1.0, 0.14, 0.2), tag=3)
        p.box((-0.5, 0.09, 0.62), (1.0, 0.14, 0.2), tag=3)
        p.box((0.3, 0.09, 0.0), (0.2, 0.14, 2.02), tag=3)
        p.box((0.85, 0.09, 0.0), (0.2, 0.14, 2.02), tag=3)
    else:
        run_z(-1.0, 0.0, -1.0, 1.0, 4)
        run_x(-1.0, 1.0, 0.0, 1.0, 2)
        p.box((-0.62, 0.09, -0.5), (0.2, 0.14, 1.0), tag=3)
        p.box((0.62, 0.09, -0.5), (0.2, 0.14, 1.0), tag=3)
        p.box((0.0, 0.09, 0.62), (2.02, 0.14, 0.2), tag=3)
        p.box((0.0, 0.09, -0.62 + 0.0), (2.02, 0.14, 0.2), tag=3)
    return paint(p, seed, 0.3)


def pile(name, seed, h):
    """A pile driven into the bog: a leaning, tapering post with a rope whipping and a split head."""
    p = Part(name, seed)
    r = p.rng
    lean = (r.uniform(-0.06, 0.06), r.uniform(-0.06, 0.06))
    p.limb((0, -0.2, 0), (lean[0], h, lean[1]), 0.14, 0.1, sides=5, tag=2)
    p.limb((lean[0] * 0.8, h * 0.72, lean[1] * 0.8), (lean[0] * 0.86, h * 0.78, lean[1] * 0.86), 0.125, 0.125, sides=5, tag=10)
    p.crystal((lean[0], h - 0.02, lean[1]), (0.4, 1.0, 0.1), 0.18, 0.06, sides=4, tag=3)
    p.lump((0, 0.05, 0), (0.22, 0.1, 0.22), subdiv=1, warp=0.3, seed=seed, flat=0.2, tag=6)
    return paint(p, seed, h)


def rail(name, seed):
    """A handrail section 2 m long along x: posts, a top rail, a slack rope below."""
    p = Part(name, seed)
    r = p.rng
    for sx in (-0.92, 0.92):
        p.limb((sx, 0.0, 0), (sx + r.uniform(-0.04, 0.04), 1.05, 0), 0.07, 0.06, sides=4, tag=2)
    p.limb((-0.92, 1.0, 0), (0.92, 0.95 + r.uniform(-0.04, 0.0), 0), 0.045, 0.045, sides=4, tag=1)
    chain(p, [(-0.92, 0.55, 0), (-0.3, 0.46, 0), (0.3, 0.46, 0), (0.92, 0.55, 0)], 0.025, 0.025, sides=3, tag=10)
    return paint(p, seed, 1.0)


def rope_bridge(name, seed):
    """A rope bridge 6 m long along x, 1.4 m wide, sagging in the middle, with a post at each end."""
    p = Part(name, seed)
    r = p.rng
    L, W = 6.0, 1.4
    def sag(x):
        return 0.5 - 0.3 * (1.0 - (2.0 * x / L) ** 2)
    n = 12
    for k in range(n):
        x = -L / 2 + (k + 0.5) * L / n
        p.box((x, sag(x), 0), (L / n - 0.07, 0.05, W * 0.86 + r.uniform(-0.06, 0.04)), yaw=r.uniform(-0.04, 0.04), tilt=(0.0, -0.0), tag=1 if k % 3 else 2)
    for sz in (-W / 2, W / 2):
        pts = [(-L / 2 + L * k / 6, sag(-L / 2 + L * k / 6) + 0.12, sz) for k in range(7)]
        chain(p, pts, 0.03, 0.03, sides=3, tag=10)
        top = [(-L / 2 + L * k / 6, sag(-L / 2 + L * k / 6) + 1.0, sz) for k in range(7)]
        chain(p, top, 0.035, 0.035, sides=3, tag=10)
        for k in range(0, 7, 2):
            p.limb(pts[k], top[k], 0.02, 0.02, sides=3, tag=10)
        for sx in (-L / 2, L / 2):
            p.limb((sx, -0.1, sz), (sx, 1.25, sz), 0.1, 0.08, sides=5, tag=2)
    return paint(p, seed, 1.4)


def jetty(name, seed):
    """The rotting jetty: 2 m wide, 8 m long toward +z from the shore, boards missing, piles each side,
    a mooring post and a snapped end."""
    p = Part(name, seed)
    r = p.rng
    n = 14
    for k in range(n):
        z = 0.3 + k * 0.55
        if k in (6, 11) or (k == 12 and r.random() < 0.5):
            continue
        L = 2.0 - (0.0 if k < 12 else r.uniform(0.3, 0.9))
        p.box((r.uniform(-0.03, 0.03) - (0.0 if k < 12 else 0.2), 0.42 + r.uniform(-0.02, 0.02), z), (L, 0.07, 0.48), yaw=r.uniform(-0.03, 0.03), tilt=(r.uniform(-0.03, 0.03), r.uniform(-0.02, 0.02)), tag=1 if k % 2 else 2)
    for sx in (-0.7, 0.7):
        p.box((sx, 0.3, 4.0), (0.16, 0.14, 7.4), tag=3)
    for k in range(5):
        z = 0.4 + k * 1.75
        for sx in (-1.1, 1.1):
            p.limb((sx, -0.2, z), (sx + r.uniform(-0.04, 0.04), 0.75 + r.uniform(0.0, 0.25), z), 0.13, 0.1, sides=5, tag=2)
    p.limb((1.1, 0.7, 7.5), (1.1, 1.5, 7.5), 0.1, 0.07, sides=5, tag=3)
    chain(p, [(1.1, 1.25, 7.5), (0.9, 1.0, 7.5), (0.7, 0.55, 7.2)], 0.025, 0.025, sides=3, tag=10)
    return paint(p, seed, 1.5)


def boards_wall(p, x0, z0, x1, z1, h, n, tag_a=1, tag_b=2, y0=0.0, gap=0.04, droop=0.0, skip=()):
    """Vertical boards along the line from (x0, z0) to (x1, z1)."""
    r = p.rng
    length = math.hypot(x1 - x0, z1 - z0)
    yaw = -math.atan2(z1 - z0, x1 - x0)
    w = length / n
    for k in range(n):
        if k in skip:
            continue
        f = (k + 0.5) / n
        hh = h * (1.0 - droop * r.random())
        p.box((x0 + (x1 - x0) * f, y0 + hh / 2, z0 + (z1 - z0) * f), (w - gap, hh, 0.07), yaw=yaw + r.uniform(-0.02, 0.02),
              tilt=(r.uniform(-0.03, 0.03), 0.0), tag=tag_a if k % 2 == 0 else tag_b)


def roof_slab(p, cx, cy, cz, lx, lz, slope, side, tag=5, thick=0.07):
    """A sheet of the roof tilted about the ridge (along x): side = +1 slopes toward +z."""
    p.box((cx, cy, cz), (lx, thick, lz), tilt=(side * slope, 0.0), tag=tag)


def shack(name, seed, burnt=False):
    """A stilt shack: four piles, a floor, plank walls, a sheet-iron roof, a dark door facing +z, a ladder.
    About 3 x 3.2 x 2.6. burnt: charred wood, the roof half down."""
    p = Part(name, seed)
    r = p.rng
    wt = 3 if burnt else 1
    for sx in (-1.2, 1.2):
        for sz in (-1.0, 1.0):
            p.limb((sx, -0.15, sz), (sx, 0.95, sz), 0.12, 0.1, sides=5, tag=3 if burnt else 2)
    p.box((0, 0.97, 0), (3.0, 0.07, 2.5), tag=3 if burnt else 2)
    wh = 1.4 if not burnt else 1.1
    boards_wall(p, -1.45, 1.2, 1.45, 1.2, wh, 7, tag_a=wt, tag_b=3 if burnt else 2, y0=1.0, droop=0.0 if not burnt else 0.5, skip=(3,))
    boards_wall(p, -1.45, -1.2, 1.45, -1.2, wh, 7, tag_a=wt, tag_b=3 if burnt else 2, y0=1.0, droop=0.0 if not burnt else 0.6)
    boards_wall(p, -1.45, -1.2, -1.45, 1.2, wh, 6, tag_a=wt, tag_b=3 if burnt else 2, y0=1.0, droop=0.0 if not burnt else 0.5)
    boards_wall(p, 1.45, -1.2, 1.45, 1.2, wh, 6, tag_a=wt, tag_b=3 if burnt else 2, y0=1.0, droop=0.0 if not burnt else 0.7)
    p.box((0, 1.5, 1.17), (0.62, 1.0, 0.04), tag=3)    # the dark doorway
    p.box((-0.36, 1.55, 1.2), (0.08, 1.1, 0.07), tag=2)
    p.box((0.36, 1.55, 1.2), (0.08, 1.1, 0.07), tag=2)
    p.box((0, 2.08, 1.2), (0.85, 0.08, 0.07), tag=2)
    top = 2.4
    if not burnt:
        for side in (-1, 1):
            roof_slab(p, 0, 2.5 + 0.0, side * 0.78, 3.5, 1.7, 0.36, side)
        p.box((0, 2.82, 0), (3.5, 0.08, 0.1), tag=5)
        top = 2.9
    else:
        roof_slab(p, 0, 2.55, -0.78, 3.5, 1.7, 0.36, -1)
        p.box((0.2, 1.2, 0.5), (1.3, 0.05, 0.9), yaw=0.4, tilt=(0.5, 0.3), tag=5)     # the other sheet, fallen in
        for k in range(3):
            p.box((-1.0 + k * 1.0, 2.3, 0.1), (0.1, 0.1, 1.6), tilt=(0.3 * k - 0.2, 0.0), tag=3)
        top = 2.75
    for sx in (-0.3, 0.3):
        p.limb((sx, 0.0, 2.1), (sx, 1.0, 1.4), 0.04, 0.04, sides=4, tag=2)
    for k in range(4):
        p.limb((-0.3, 0.2 + k * 0.22, 2.0 - k * 0.15), (0.3, 0.2 + k * 0.22, 2.0 - k * 0.15), 0.025, 0.025, sides=3, tag=2)
    return paint(p, seed, top)


def boat_shed(name, seed):
    """The boat shed: an open-fronted lean-to on the shore, 4.2 x 3.6 x 3.2, front toward +z, a slipway of
    planks, back and side walls of boards (some fallen), a sagging roof with a hole."""
    p = Part(name, seed)
    r = p.rng
    for sx in (-1.9, 1.9):
        for sz, hh in ((-1.6, 3.0), (1.6, 2.5)):
            p.limb((sx, -0.1, sz), (sx + r.uniform(-0.05, 0.05), hh, sz), 0.13, 0.11, sides=5, tag=2)
    for k in range(7):
        p.box((0, 0.06, -1.5 + k * 0.5), (3.6, 0.08, 0.46), yaw=r.uniform(-0.02, 0.02), tag=1 if k % 2 else 2)
    boards_wall(p, -1.95, -1.65, 1.95, -1.65, 3.0, 9, droop=0.25, skip=(2,))
    boards_wall(p, -1.95, -1.6, -1.95, 1.6, 2.8, 7, droop=0.5, skip=(1, 5))
    boards_wall(p, 1.95, -1.6, 1.95, 1.6, 2.6, 7, droop=0.7, skip=(3,))
    for k in range(5):
        x = -1.7 + k * 0.85
        p.limb((x, 3.0, -1.6), (x + r.uniform(-0.05, 0.05), 2.45 + r.uniform(-0.1, 0.1), 1.65), 0.05, 0.05, sides=3, tag=2)
    for k, (cx, lx) in enumerate(((-1.25, 1.6), (0.9, 2.2))):
        if k == 1:
            p.box((cx, 2.78, -0.35), (lx, 0.06, 1.8), tilt=(0.17, 0.05), tag=5)
            p.box((cx, 2.64, 1.2), (lx, 0.06, 1.0), tilt=(0.2, -0.04), tag=5)
        else:
            p.box((cx, 2.78, 0.0), (lx, 0.06, 3.5), tilt=(0.17, 0.0), tag=5)
    p.limb((1.2, 0.05, 1.0), (-0.4, 0.3, 3.2), 0.5, 0.2, sides=5, tag=3) if False else None
    p.lump((1.2, 0.3, 0.9), (0.6, 0.18, 0.5), subdiv=1, warp=0.3, seed=2.0, flat=0.3, tag=6)
    return paint(p, seed, 3.2)


# -- landmarks ---------------------------------------------------------------------------

def pyre_tree(name, seed):
    """The Pyre Tree: a vast dead tree, black bark, limbs splayed like fingers, seams of ember in the trunk
    and ember lodged in the crown. About 9.5 m tall; the flames on it are the arena's particles."""
    p = Part(name, seed)
    r = p.rng
    levels = [(0.0, 1.35, (0.0, 0.0)), (1.2, 1.1, (0.1, 0.05)), (2.8, 0.95, (0.35, 0.1)), (4.3, 0.8, (0.5, 0.2)), (5.5, 0.62, (0.5, 0.35))]
    rings = [p.ring(8, rr, y, off=off, phase=0.2 * k, jit=0.12) for k, (y, rr, off) in enumerate(levels)]
    p.loft(rings, cap_hi=True, tag=3)
    tops = [(off[0], y, off[1]) for (y, rr, off) in levels]
    for i in range(8):
        a = math.tau * i / 8 + r.uniform(-0.2, 0.2)
        d = (math.cos(a), 0, math.sin(a))
        mid = (d[0] * 1.3, 0.35, d[2] * 1.3)
        chain(p, [(d[0] * 0.55, 1.3, d[2] * 0.55), mid, (d[0] * 2.5, -0.1, d[2] * 2.5)], 0.42, 0.12, sides=5, tag=3)
    for i in range(7):
        a = math.tau * i / 7 + r.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), 0, math.sin(a)))
        frm = Vector(tops[3 + (i % 2)])
        mid = frm + d * r.uniform(1.3, 1.9) + Vector((0, r.uniform(0.8, 1.3), 0))
        tip = mid + d * r.uniform(1.1, 1.7) + Vector((0, r.uniform(1.3, 2.3), 0))
        chain(p, [tuple(frm), tuple(mid), tuple(tip)], 0.34, 0.07, sides=4, tag=3 if i % 3 else 6)
        side = d.cross(Vector((0, 1, 0))) * r.uniform(-1.0, 1.0)
        p.limb(tuple(mid), tuple(mid + side * 1.1 + Vector((0, 1.3, 0))), 0.14, 0.04, sides=3, tag=3)
        p.limb(tuple(frm + d * 0.2 + Vector((0, 0.3, 0))), tuple(frm + d * 0.7 + Vector((0, 1.5, 0))), 0.12, 0.04, sides=3, tag=3)
    p.use(tag=9, mat=GLOW)
    for k in range(5):      # the seams, up the trunk's front
        y0 = 0.5 + k * 1.0
        x0 = (r.uniform(-0.5, 0.5))
        c = [tops[min(k // 2 + 0, 3)][0], y0, 1.05 - 0.07 * k]
        a = Vector((x0 * 0.3, y0, 1.18 - 0.1 * k))
        b = Vector((x0 * 0.3 + 0.07, y0 + 0.9, 1.1 - 0.1 * k))
        w = Vector((0.06, 0, 0))
        p.quad(p.v(a - w), p.v(a + w), p.v(b + w * 0.5), p.v(b - w * 0.5), tag=9, mat=GLOW)
    for pos in ((1.8, 6.4, 0.9), (-1.6, 7.0, -1.2), (0.4, 7.8, 1.4), (-0.4, 6.0, -1.9)):
        p.crystal(pos, (0.1, 1.0, 0.1), 0.45, 0.12, sides=4, tag=9, mat=GLOW)
    return paint(p, seed, 9.5)


def forge(name, seed):
    """The Ogre's stilted forge-hut on a plank platform: 6 x 5 m deck 1.1 m up on piles, a three-sided hut with
    the forge mouth toward +z, a stone chimney, an anvil block and a bellows. Ember in the hearth."""
    p = Part(name, seed)
    r = p.rng
    for sx in (-2.7, 0.0, 2.7):
        for sz in (-2.2, 0.0, 2.2):
            p.limb((sx, -0.2, sz), (sx, 1.05, sz), 0.16, 0.13, sides=5, tag=3)
    for k in range(10):
        p.box((-2.7 + (k + 0.5) * 0.6, 1.12 + r.uniform(-0.01, 0.01), 0), (0.56, 0.1, 5.2), yaw=r.uniform(-0.02, 0.02), tag=2 if k % 2 else 1)
    wh = 2.8
    boards_wall(p, -2.0, -1.6, 2.0, -1.6, wh, 10, y0=1.17, droop=0.15)
    boards_wall(p, -2.0, -1.6, -2.0, 1.2, wh, 7, y0=1.17, droop=0.2)
    boards_wall(p, 2.0, -1.6, 2.0, 1.2, wh, 7, y0=1.17, droop=0.2)
    for sx in (-2.0, 2.0):
        p.limb((sx, 1.17, 1.3), (sx, 4.0, 1.3), 0.15, 0.13, sides=5, tag=2)
    p.box((0, 3.6, 1.3), (4.4, 0.25, 0.25), tag=2)
    for side in (-1, 1):
        p.box((0, 4.2, side * 0.75 - 0.2), (4.8, 0.08, 1.8), tilt=(side * 0.38, 0.0), tag=5)
    p.box((0, 4.62, -0.2), (4.8, 0.1, 0.12), tag=5)
    p.box((-0.8, 2.2, -1.1), (1.6, 2.0, 1.1), taper=0.9, tag=6)       # hearth and chimney
    p.box((-0.8, 4.6, -1.15), (1.0, 3.0, 0.9), taper=0.82, tag=6)
    p.box((-0.8, 1.5, -0.52), (0.9, 0.5, 0.06), tag=9, mat=GLOW)
    p.box((-0.8, 1.75, -0.5), (1.1, 0.9, 0.04), tag=3)
    p.box((1.0, 1.55, -0.6), (0.7, 0.8, 0.5), taper=0.85, tag=4)      # anvil block
    p.box((1.0, 1.98, -0.6), (1.0, 0.1, 0.35), tag=4)
    p.box((0.35, 1.5, -1.35), (0.3, 0.5, 0.5), tilt=(0.0, 0.0), tag=2)
    return paint(p, seed, 6.0)


def cauldron(name, seed):
    """The great cauldron: an iron pot over a log fire, slung from a gibbet with chains. About 1.9 m wide, 3.3 m tall."""
    p = Part(name, seed)
    r = p.rng
    prof = [(0.0, 0.35), (0.12, 0.75), (0.55, 0.98), (1.0, 0.95), (1.18, 0.82), (1.22, 0.9)]
    rings = [p.ring(10, rr, 0.55 + y, jit=0.02) for y, rr in prof]
    p.use(tag=4)
    p.loft(rings, cap_lo=True, tag=4)
    p.use(tag=9, mat=GLOW)
    p.face(list(rings[-1]), tag=9, mat=GLOW) if False else None
    cs = p.ring(10, 0.78, 1.68, jit=0.03)
    p.face(cs, tag=9, mat=GLOW)
    p.use(mat=MATTE)
    for k in range(6):
        a = math.tau * k / 6 + 0.3
        p.limb((math.cos(a) * 0.55 - 0.0, 0.05, math.sin(a) * 0.55), (math.cos(a + 0.9) * 0.55, 0.3, math.sin(a + 0.9) * 0.55), 0.13, 0.11, sides=4, tag=3)
    for k in range(3):
        a = math.tau * k / 3 + 0.6
        p.limb((math.cos(a) * 0.95, 0.0, math.sin(a) * 0.95), (math.cos(a) * 0.4, 0.62, math.sin(a) * 0.4), 0.05, 0.05, sides=4, tag=4)
    for sx in (-1.5, 1.5):
        p.limb((sx, -0.1, 0), (sx, 3.2, 0), 0.14, 0.12, sides=5, tag=2)
    p.limb((-1.5, 3.1, 0), (1.5, 3.1, 0), 0.13, 0.13, sides=5, tag=2)
    for sx in (-0.5, 0.5):
        chain(p, [(sx * 0.4, 3.0, 0), (sx * 0.8, 2.5, 0), (sx * 0.95, 2.0, 0)], 0.035, 0.035, sides=3, tag=4)
    return paint(p, seed, 3.3)


def hook_post(name, seed):
    """A gibbet post for the forge deck: 3 m upright, an arm, a chain and a meat hook."""
    p = Part(name, seed)
    p.limb((0, -0.1, 0), (0.03, 3.0, 0), 0.12, 0.1, sides=5, tag=2)
    p.limb((0.03, 2.9, 0), (1.0, 2.75, 0), 0.07, 0.06, sides=4, tag=2)
    p.limb((0.4, 2.9, 0), (0.1, 2.35, 0), 0.04, 0.04, sides=3, tag=2)
    chain(p, [(1.0, 2.7, 0), (1.0, 2.2, 0), (1.0, 1.7, 0), (1.0, 1.4, 0)], 0.03, 0.03, sides=3, tag=4)
    chain(p, [(1.0, 1.4, 0), (1.0, 1.15, 0.0), (1.12, 1.05, 0.0), (1.16, 1.25, 0.0)], 0.04, 0.025, sides=3, tag=4)
    p.lump((0, 0.1, 0), (0.4, 0.2, 0.4), subdiv=1, warp=0.3, seed=seed, flat=0.2, tag=6)
    return paint(p, seed, 3.0)


def brazier(name, seed):
    """A standing iron brazier: three legs, a bowl, glowing coals. About 1.1 m."""
    p = Part(name, seed)
    for k in range(3):
        a = math.tau * k / 3 + 0.4
        d = Vector((math.cos(a), 0, math.sin(a)))
        p.limb(tuple(d * 0.42), tuple(d * 0.16 + Vector((0, 0.72, 0))), 0.04, 0.035, sides=4, tag=4)
    lo = p.ring(8, 0.2, 0.58)
    mid = p.ring(8, 0.42, 0.82)
    rim = p.ring(8, 0.5, 0.92)
    p.loft([lo, mid, rim], cap_lo=True, tag=4)
    co = p.ring(8, 0.44, 0.9, jit=0.05, yjit=0.04)
    p.face(co, tag=9, mat=GLOW)
    p.crystal((0.1, 0.9, 0.05), (0.2, 1.0, 0.0), 0.18, 0.07, sides=4, tag=9, mat=GLOW)
    return paint(p, seed, 1.1)


def reeds(name, seed, n):
    """A tuft of reeds burnt to brown: bent blades and a few seed heads. About 1.1 m."""
    p = Part(name, seed)
    r = p.rng
    for i in range(n):
        a = r.uniform(0, math.tau)
        foot = Vector((math.cos(a), 0, math.sin(a))) * r.uniform(0.04, 0.35)
        h = r.uniform(0.7, 1.15)
        lean = Vector((r.uniform(-0.18, 0.18), 0, r.uniform(-0.18, 0.18)))
        mid = foot + lean * 0.4 + Vector((0, h * 0.55, 0))
        tip = foot + lean + Vector((0, h, 0))
        w = Vector((math.cos(a + 1.6), 0, math.sin(a + 1.6))) * 0.035
        p.quad(p.v(foot - w), p.v(foot + w), p.v(mid + w * 0.7), p.v(mid - w * 0.7), tag=7)
        p.tri(p.v(mid - w * 0.7), p.v(mid + w * 0.7), p.v(tip), tag=7)
        if i % 4 == 0:
            p.limb(tuple(tip - Vector((0, 0.2, 0))), tuple(tip + Vector((0, 0.05, 0))), 0.04, 0.025, sides=3, tag=3)
    return paint(p, seed, 1.2)


def stone(name, seed, rx, ry, rz):
    """A bog stone, soot-dark with a paler crown. About 1 m."""
    p = Part(name, seed)
    p.lump((0, ry * 0.4, 0), (rx, ry, rz), subdiv=2, warp=0.34, seed=seed, flat=0.45, tag=6)
    return paint(p, seed, ry * 1.4)


def mangrove(name, seed, spread, h, nroots):
    """A dead mangrove: a thick leaning bole on arching, forked prop roots, bare crooked branches.
    Spread about 3.5 m, 3-4.5 m tall."""
    p = Part(name, seed)
    r = p.rng
    lean = Vector((r.uniform(-0.3, 0.3), 0, r.uniform(-0.3, 0.3)))
    base = Vector((0, 0.9, 0))
    mid = base + Vector((lean.x * 0.5 + r.uniform(-0.25, 0.25), (h - 0.9) * 0.5, lean.z * 0.5 + r.uniform(-0.25, 0.25)))
    top = base + Vector((lean.x, h - 0.9, lean.z))
    chain(p, [tuple(base - Vector((0, 0.5, 0))), tuple(base), tuple(mid), tuple(top)], 0.5, 0.17, sides=6, tag=3)
    for i in range(nroots):
        a = math.tau * i / nroots + r.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), 0, math.sin(a)))
        out = spread * r.uniform(0.45, 0.62)
        hi = r.uniform(0.25, 1.1)
        frm = base + d * 0.3 + Vector((0, hi, 0))
        kink = Vector((-d.z, 0, d.x)) * r.uniform(-0.3, 0.3)
        pts = [frm, frm + d * out * 0.3 + Vector((0, 0.25, 0)) + kink * 0.4, frm + d * out * 0.65 + Vector((0, 0.1 - hi * 0.3, 0)) + kink,
               frm + d * out * 0.9 + Vector((0, -hi * 0.8, 0)) + kink * 0.6, d * out + Vector((0, -0.12, 0)) + kink * 0.5]
        chain(p, [tuple(q) for q in pts], 0.2, 0.06, sides=4, tag=3 if i % 3 else 2)
        if i % 2 == 0:
            q = pts[2]
            e = q + d * 0.55 + Vector((-d.z, 0, d.x)) * r.uniform(-0.5, 0.5)
            chain(p, [tuple(q), tuple(Vector((e.x, q.y - 0.25, e.z))), tuple(Vector((e.x, -0.1, e.z)))], 0.07, 0.03, sides=3, tag=3)
    for i in range(5):
        a = r.uniform(0, math.tau)
        d = Vector((math.cos(a), 0, math.sin(a)))
        s = base + (top - base) * r.uniform(0.45, 0.95)
        m = s + d * r.uniform(0.5, 0.9) + Vector((0, r.uniform(0.2, 0.6), 0))
        e = m + Vector((-d.z, 0, d.x)) * r.uniform(-0.6, 0.6) + d * 0.4 + Vector((0, r.uniform(0.3, 0.9), 0))
        chain(p, [tuple(s), tuple(m), tuple(e)], 0.13, 0.03, sides=3, tag=3)
    return paint(p, seed, h)


def stump(name, seed, rr, h):
    """A charred stump: a jagged broken top, flared roots, a vein of ember."""
    p = Part(name, seed)
    r = p.rng
    rings = [p.ring(7, rr * 1.15, 0.0, jit=0.08), p.ring(7, rr, h * 0.45, jit=0.1), p.ring(7, rr * 0.82, h, jit=0.12, yjit=0.18)]
    p.loft(rings, cap_hi=True, tag=3)
    for k in range(4):
        a = math.tau * k / 4 + r.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), 0, math.sin(a)))
        p.limb(tuple(d * rr * 0.5 + Vector((0, h * 0.5, 0))), tuple(d * rr * 1.7 + Vector((0, -0.04, 0))), 0.14, 0.05, sides=3, tag=3)
    p.quad(p.v(rr * 0.9, h * 0.15, rr * 0.3), p.v(rr * 0.98, h * 0.2, rr * 0.4), p.v(rr * 0.8, h * 0.8, rr * 0.35), p.v(rr * 0.72, h * 0.75, rr * 0.28), tag=9, mat=GLOW)
    return paint(p, seed, h)


def wrecked_boat(name, seed):
    """A wrecked riverboat, listing in the bog: a flat hull split open, a cabin frame, a stove-pipe, a
    paddle-wheel hoop. About 6.5 x 3 x 3.6 m, bow toward +z."""
    p = Part(name, seed)
    r = p.rng
    L, W = 6.5, 1.5
    n = 8
    sides_o = []
    for i in range(n + 1):
        z = -L / 2 + L * i / n
        u = abs(2.0 * i / n - 1.0)
        w = W * (1.0 - 0.3 * u ** 3)
        hh = 0.9 + 0.5 * u ** 2
        sides_o.append((z, w, hh))
    for i in range(n):
        (z0, w0, h0), (z1, w1, h1) = sides_o[i], sides_o[i + 1]
        if i in (3, 4):
            continue
        for sx in (-1, 1):
            a = [p.v(sx * w0, 0.15, z0), p.v(sx * w1, 0.15, z1), p.v(sx * w1, h1, z1), p.v(sx * w0, h0, z0)]
            p.quad(*a, tag=1 if (i + (sx > 0)) % 2 else 2)
            b = [p.v(sx * (w0 - 0.07), 0.2, z0), p.v(sx * (w0 - 0.07), h0, z0), p.v(sx * (w1 - 0.07), h1, z1), p.v(sx * (w1 - 0.07), 0.2, z1)]
            p.quad(*b, tag=2)
        p.quad(p.v(-w0, 0.15, z0), p.v(w0, 0.15, z0), p.v(w1, 0.15, z1), p.v(-w1, 0.15, z1), tag=3)
    for k in range(5):
        z = -L / 2 + 0.4 + k * 0.45
        p.box((0, 0.2, z), (2 * W * 0.9, 0.06, 0.4), tag=2)
    for sx in (-1.15, 1.15):
        for z in (-1.8, -0.5, 0.8):
            p.limb((sx, 0.9, z), (sx + r.uniform(-0.05, 0.05), 3.0 - (0.5 if z > 0 else 0.0), z), 0.08, 0.07, sides=4, tag=2)
    p.box((0, 3.0, -1.2), (2.5, 0.06, 2.0), tilt=(0.0, 0.14), tag=5)
    p.limb((0.6, 0.9, -2.3), (0.6, 3.6, -2.3), 0.22, 0.2, sides=6, tag=4)
    p.limb((0.6, 3.5, -2.3), (0.6, 3.75, -2.3), 0.3, 0.26, sides=6, tag=3)
    ring = [(math.cos(a) * 1.5, 1.5 + math.sin(a) * 1.5) for a in [k * math.tau / 10 for k in range(10)]]
    for k in range(10):
        if k in (3, 4):
            continue
        a0, a1 = ring[k], ring[(k + 1) % 10]
        p.limb((1.55, a0[1] - 0.3 + 0.9, a0[0] - 2.6 + 0.0), (1.55, a1[1] - 0.3 + 0.9, a1[0] - 2.6), 0.06, 0.06, sides=3, tag=2)
    p.lump((0, 0.5, 1.0), (0.8, 0.2, 1.0), subdiv=1, warp=0.3, seed=3.0, flat=0.3, tag=6)
    return paint(p, seed, 3.7)


def skull_totem(name, seed):
    """A skull totem: a charred post, a crossbar, skulls on spikes and a ring of ash stones. About 2.6 m."""
    p = Part(name, seed)
    r = p.rng
    p.limb((0, -0.1, 0), (0.03, 2.5, 0), 0.13, 0.1, sides=5, tag=3)
    p.limb((-0.8, 1.9, 0), (0.8, 1.85, 0), 0.06, 0.06, sides=4, tag=2)
    for k, (x, y, s) in enumerate(((0.0, 2.55, 0.2), (-0.8, 1.95, 0.15), (0.8, 1.9, 0.15), (0.0, 1.2, 0.15))):
        p.lump((x, y + s, 0.05), (s, s * 1.05, s * 1.1), subdiv=1, warp=0.25, seed=seed + k, tag=8)
        p.crystal((x - s * 0.5, y + s * 0.4, s * 0.9), (0.0, 0.0, 1.0), 0.0 + 0.001, 0.001, sides=3, tag=3) if False else None
        p.crystal((x, y - 0.1, 0.0), (0.0, 1.0, 0.0), 0.2, 0.05, sides=3, tag=2)
    for k in range(4):
        a = math.tau * k / 4 + 0.5
        p.lump((math.cos(a) * 0.55, 0.14, math.sin(a) * 0.55), (0.28, 0.2, 0.26), subdiv=1, warp=0.3, seed=seed + k, flat=0.2, tag=6)
    return paint(p, seed, 2.6)


def build():
    global PAL
    K.reset()
    PAL = Palette("mire")
    objs = []
    for nm, sd in (("plank_a", 1), ("plank_b", 2), ("plank_c", 3)):
        objs.append(plank(nm, sd))
    objs.append(plank("plank_end", 4, "end"))
    objs.append(plank("plank_corner", 5, "corner"))
    objs.append(plank("plank_tee", 6, "tee"))
    objs.append(pile("pile_a", 7, 1.5))
    objs.append(pile("pile_b", 8, 1.35))
    objs.append(pile("pile_tall", 9, 2.4))
    objs.append(rail("rail", 10))
    objs.append(rope_bridge("rope_bridge", 11))
    objs.append(jetty("jetty", 12))
    objs.append(boat_shed("boat_shed", 13))
    objs.append(shack("shack", 14))
    objs.append(shack("shack_burnt", 15, True))
    objs.append(pyre_tree("pyre_tree", 13))
    objs.append(forge("forge", 16))
    objs.append(cauldron("cauldron", 17))
    objs.append(hook_post("hook_post", 18))
    objs.append(brazier("brazier", 5))
    objs.append(reeds("reeds_a", 4, 14))
    objs.append(reeds("reeds_b", 24, 11))
    objs.append(reeds("reeds_c", 34, 16))
    objs.append(stone("stone_a", 3, 0.62, 0.5, 0.55))
    objs.append(stone("stone_b", 33, 0.5, 0.42, 0.7))
    objs.append(stone("stone_c", 43, 0.55, 0.62, 0.5))
    objs.append(mangrove("mangrove_a", 51, 3.6, 3.4, 7))
    objs.append(mangrove("mangrove_b", 52, 3.0, 4.2, 6))
    objs.append(mangrove("mangrove_c", 53, 3.4, 3.0, 8))
    objs.append(stump("stump_a", 61, 0.5, 0.9))
    objs.append(stump("stump_b", 62, 0.42, 0.6))
    objs.append(wrecked_boat("wrecked_boat", 19))
    objs.append(skull_totem("skull_totem", 20))
    return objs


if __name__ == "__main__":
    objs = build()
    K.export("mire", objs, PAL, OUT)
