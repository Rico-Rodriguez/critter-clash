"""The Barbarian's weapons: six families, each in the five sets.

    python tools/art/make_barbarian_arms.py   (Blender's Python: pip install bpy)

Writes assets/kaykit/weapons/barb_<family>_<set>.gltf, set 0 to 4, in the
dark heroes' palette: Gravedigger (scavenged: grey wood, rope, rusted iron),
Warden (black iron, steel edges, on hide), Barrowsteel (black iron edged in
silver, spikes), Bloodiron (black iron with blood-red edges, serrated) and
Gravelight (pale steel and gold, huge and ornate). Each step is bigger and
adds a feature, so the sets read apart from across the screen. See kk_mesh.py for how the coloring works.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kk_mesh as K  # noqa: E402
from kk_mesh import ROOT, lathe, gem, plate, box, spike, mark, place, export  # noqa: E402

# Per set: haft, grip wrap, head metal, cutting edge, trim, size of the head,
# in the dark heroes' palette (dark_texture.png): rust, then black iron with
# steel, silver, blood red, and pale steel with gold.
K.DARK = True
SETS = [
    {"haft": "wood", "wrap": "fur", "metal": "rust", "edge": "rust", "trim": "rust", "size": 0.9},
    {"haft": "hide", "wrap": "black", "metal": "iron", "edge": "steel", "trim": "steel", "size": 1.0},
    {"haft": "black", "wrap": "hide", "metal": "iron", "edge": "silver", "trim": "silver", "size": 1.08},
    {"haft": "black", "wrap": "blood", "metal": "iron", "edge": "red", "trim": "blood", "size": 1.17},
    {"haft": "pale", "wrap": "agold", "metal": "pale", "edge": "white", "trim": "agold", "size": 1.27},
]


def haft(y0, y1, r, s, k, wraps=()):
    """A shaft from y0 to y1 with grip wraps [(y, length)], a butt cap and,
    from Barrowsteel up, trim rings."""
    lathe([(y0, r * 0.9), (y0 + 0.05, r), ((y0 + y1) / 2, r * 1.04), (y1, r * 0.92)], s["haft"], sides=6,
          shade=lambda y: 0.75 - 0.4 * (y - y0) / (y1 - y0))
    for y, ln in wraps:
        lathe([(y, r * 1.25), (y + ln, r * 1.25)], s["wrap"], sides=6)
        if k == 0:
            # Rope: a few thick turns.
            for q in range(3):
                yy = y + ln * (q + 0.5) / 3
                lathe([(yy - 0.015, r * 1.25), (yy, r * 1.45), (yy + 0.015, r * 1.25)], "tan", sides=6)
    if k >= 1:
        lathe([(y0 - 0.06, 0.0), (y0 - 0.02, r * 1.4), (y0 + 0.03, r * 1.4)], s["trim"], sides=6)
    if k >= 2:
        for y in (y0 + 0.12, (y0 + y1) * 0.5):
            lathe([(y, r * 1.2), (y + 0.02, r * 1.45), (y + 0.05, r * 1.2)], s["trim"], sides=6)
    if k >= 3:
        spike((0, y0 - 0.04, 0), r * 1.1, (0, y0 - 0.22 - 0.04 * k, 0), s["trim"])


def crescent(top, w, h, k, s, side=-1, beard=False, half=0.035):
    """One axe blade on the -x side (or +x), its spine at the haft around
    y = top, a convex cutting edge `w` out and `h` tall each way."""
    pts = [(0.03, top + h * 0.35), (w * 0.55, top + h * 0.55)]
    edge_from = len(pts)
    horn = 1.0 + 0.25 * (k >= 3) + 0.25 * (k >= 4)
    n = 7
    for i in range(n + 1):
        a = math.pi * (0.5 - i / n)  # top to bottom
        r = 1.0
        if k == 0 and i in (2, 5):
            r = 0.9  # chipped
        if k >= 3 and i % 2 == 1:
            r = 0.9  # serrated
        x = w * (0.75 + 0.25 * math.cos(a) * r)
        y = top + h * math.sin(a) * (horn if i in (0, n) else 1.0)
        if beard and i > n / 2:
            y -= h * 0.35 * (i - n / 2) / (n / 2)
            x -= w * 0.1 * (i - n / 2) / (n / 2)
        pts.append((x, y))
    edge_to = len(pts) - 1
    pts.append((w * 0.5, top - h * (0.55 + 0.4 * beard)))
    pts.append((0.03, top - h * 0.3))
    edges = range(edge_from, edge_to)
    if side < 0:
        pts = [(-x, y) for x, y in pts]
        pts.reverse()
        m = len(pts) - 1
        edges = [m - 1 - e for e in edges]
    if k >= 3:
        # Bloodiron and Gravelight: the whole blade is edge-metal (red, or
        # pale), with the dark body laid over its middle, so a rim of it
        # shows all round.
        plate(pts, half * s["size"], s["edge"], edges, s["edge"])
        cx = sum(x for x, _ in pts) / len(pts)
        cy = sum(y for _, y in pts) / len(pts)
        inner = [(cx + (x - cx) * 0.74, cy + (y - cy) * 0.74) for x, y in pts]
        plate(inner, half * s["size"] * 1.35, s["metal"])
    else:
        plate(pts, half * s["size"], s["metal"], edges, s["edge"])


def collar(y, r, s, k, h=0.18):
    """Where a head meets the haft: a socket, ringed with trim from Warden up."""
    lathe([(y - h / 2, r), (y + h / 2, r)], s["metal"], sides=6)
    if k >= 1:
        for yy in (y - h / 2, y + h / 2 - 0.03):
            lathe([(yy, r * 1.12), (yy + 0.03, r * 1.12)], s["trim"], sides=6)


def jewels(c, k, s, n=1, size=0.04):
    """Stones on both faces: Bloodiron's red, Gravelight's pale ones."""
    if k < 3:
        return
    sw = "red" if k == 3 else "bone"
    for i in range(n):
        cy = c[1] + (i - (n - 1) / 2) * size * 2.4
        gem((c[0], cy, c[2]), size, size * 1.2, size * 0.7, sw=sw, facing=1)
        gem((c[0], cy, -c[2]), size, size * 1.2, size * 0.7, sw=sw, facing=-1)


# --- Families ---------------------------------------------------------------

def axe(k):
    """Two-handed axe. Gravedigger: a woodsman's bearded blade. Warden: a
    clean war axe. Barrowsteel up: double-bitted with a top spike, growing
    horns and serrations; Gravelight's bits are huge and crowned."""
    s = SETS[k]
    sz = s["size"]
    top = 1.05
    haft(-0.45, top + 0.18, 0.045, s, k, [(-0.3, 0.28), (0.25, 0.18)])
    collar(top, 0.07, s, k)
    crescent(top, 0.62 * sz, 0.32 * sz, k, s, -1, beard=(k == 0))
    if k >= 2:
        crescent(top, 0.5 * sz, 0.26 * sz, k, s, 1)
    if k >= 2:
        spike((0, top + 0.12, 0), 0.05, (0, top + 0.32 + 0.06 * k, 0), s["trim"] if k == 4 else s["metal"])
    if k == 1:
        spike((0.05, top, 0), 0.05, (0.3, top + 0.03, 0), s["metal"])
    if k == 4:
        for dx in (-0.12, 0.12):
            spike((dx, top + 0.16, 0), 0.03, (dx * 1.6, top + 0.38, 0), "gold", sides=3)
    jewels((0, top, 0.075), k, s, 1 if k == 3 else 2)


def maul(k):
    """Two-handed hammer. Gravedigger: an iron-banded log. Warden: a steel
    block. Barrowsteel: flanged with spikes. Bloodiron: black with red
    spikes. Gravelight: a great pale head ringed in gold and spikes."""
    s = SETS[k]
    sz = s["size"]
    top = 0.95
    haft(-0.42, top, 0.05, s, k, [(-0.3, 0.3), (0.3, 0.16)])
    if k == 0:
        m = mark()
        lathe([(-0.32, 0.17), (-0.3, 0.2), (0.3, 0.2), (0.32, 0.17)], "wood", sides=7)
        for y in (-0.2, 0.17):
            lathe([(y, 0.215), (y + 0.05, 0.215)], "rust", sides=7)
        place(m, rot=(0, 0, 90), at=(0, top + 0.08, 0))
        return
    w, hh = 0.62 * sz, 0.3 * sz
    box((0, top + 0.1, 0), (w, hh, hh), s["metal"])
    collar(top - 0.02, 0.075, s, k, 0.14)
    # Faces: a raised striking plate at each end.
    for sx in (-1, 1):
        box((sx * (w / 2 + 0.03), top + 0.1, 0), (0.06, hh * 1.12, hh * 1.12), s["trim"] if k >= 2 else s["metal"])
    if k >= 2:
        # Flanges around the middle and spikes off them.
        box((0, top + 0.1, 0), (w * 0.3, hh * 1.25, hh * 1.25), s["trim"])
        for dz in (-1, 1):
            spike((0, top + 0.1, dz * hh * 0.6), 0.06, (0, top + 0.1, dz * (hh * 0.6 + 0.16 + 0.04 * k)), "red" if k == 3 else s["metal"])
        spike((0, top + 0.1 + hh * 0.6, 0), 0.06, (0, top + 0.35 + 0.06 * k, 0), "red" if k == 3 else s["metal"])
    if k >= 3:
        for sx in (-1, 1):
            for sy in (-1, 1):
                spike((sx * w * 0.32, top + 0.1 + sy * hh * 0.5, 0), 0.04, (sx * w * 0.38, top + 0.1 + sy * (hh * 0.5 + 0.16), 0), "red" if k == 3 else "gold", sides=3)
    jewels((0, top + 0.1, hh * 0.64), k, s, 1)


def scythe(k):
    """The reaping scythe (the OSRS one). A farmer's tool at Gravedigger, a
    war scythe from Warden, a back spike and gold at Barrowsteel, a second,
    serrated blade at Bloodiron, and at Gravelight a vast pale crescent on a
    bone shaft, crowned with a blade of its own."""
    s = SETS[k]
    sz = s["size"]
    top = 1.42 + 0.06 * k
    haft(-0.62, top, 0.042, s, k, [(-0.12, 0.42 if k else 0.3), (0.55, 0.14)])
    collar(top + 0.08, 0.06, s, k, 0.2)
    _scythe_blade(top + 0.12, 1.0 * sz, 0.26 * sz, k, s)
    if k >= 3:
        _scythe_blade(top - 0.06, 0.55 * sz, 0.14 * sz, k, s, flip=True)
    if k >= 2:
        spike((-0.03, top + 0.12, 0), 0.05, (-0.28 - 0.04 * k, top + 0.22, 0), s["metal"])
    if k == 4:
        spike((0, top + 0.2, 0), 0.05, (0, top + 0.6, 0), "white")
        for dx in (-0.08, 0.08):
            spike((dx, top + 0.18, 0), 0.025, (dx * 2.2, top + 0.42, 0), "gold", sides=3)
    jewels((0.0, top + 0.12, 0.07), k, s, 1 if k == 3 else 3, 0.035)


def _scythe_blade(y0, length, depth, k, s, flip=False):
    """A crescent leaving the collar sideways and sweeping down to a point;
    the inner curve is the cutting edge."""
    from mathutils import Vector
    nseg = 10
    top, low = [], []
    for i in range(nseg + 1):
        t = i / nseg
        x = 0.04 + length * t
        y = y0 + 0.18 * math.sin(math.pi * t) * (1 - t) - 0.36 * t ** 2.1 * (length / 1.0)
        w = depth * (1 - t ** 1.3) + 0.012
        top.append((x, y))
        if k >= 3 and 0 < i < nseg and i % 2 == 0:
            w *= 0.82
        low.append((x, y - w))
    pts = top + list(reversed(low))
    pts.reverse()  # counter-clockwise
    # After reversing, the low (cutting) side runs first: segments 0..nseg-1.
    edges = range(0, nseg)
    m = mark()
    plate(pts, 0.035 * s["size"], s["metal"], edges, s["edge"])
    if flip:
        place(m, rot=(0, 180, 0))


def twin(k):
    """One of a pair of hand axes (the other hand holds its twin)."""
    s = SETS[k]
    sz = s["size"]
    top = 0.78
    haft(-0.25, top + 0.1, 0.038, s, k, [(-0.18, 0.3)])
    collar(top, 0.055, s, k, 0.14)
    crescent(top, 0.46 * sz, 0.26 * sz, k, s, -1, beard=(k in (0, 3)), half=0.03)
    if k >= 1:
        # A guard plate over the knuckles.
        plate([(0.0, -0.14), (0.09, -0.12), (0.11, 0.0), (0.0, -0.04)], 0.012, s["trim"])
    if k >= 2:
        spike((0.04, top, 0), 0.04, (0.24 + 0.03 * k, top + 0.05, 0), s["metal"])
    if k == 4:
        spike((0, top + 0.08, 0), 0.04, (0, top + 0.3, 0), "gold")
    jewels((0, top, 0.06), k, s, 1, 0.03)


def halberd(k):
    """A pole with a spear point, an axe blade and a back hook: the hook
    arrives at Warden, a longer point and gold at Barrowsteel, red edges at
    Bloodiron, and Gravelight's crescent blade and three-pronged crown."""
    s = SETS[k]
    sz = s["size"]
    top = 1.55
    haft(-0.9, top + 0.1, 0.04, s, k, [(-0.2, 0.36), (0.6, 0.14)])
    collar(top, 0.06, s, k, 0.22)
    # The point: a long flat leaf, edged on both sides.
    ln = (0.38 + 0.05 * k) * sz
    wd = 0.07 * sz
    pts = [(0, top + 0.1), (wd, top + 0.1 + ln * 0.3), (0, top + 0.1 + ln), (-wd, top + 0.1 + ln * 0.3)]
    plate(pts, 0.025, s["metal"], [0, 1, 2, 3], s["edge"])
    crescent(top - 0.02, 0.4 * sz, 0.2 * sz, k, s, -1, half=0.03)
    if k >= 1:
        hook = [(0.03, top + 0.03), (0.2 + 0.03 * k, top + 0.05), (0.32 + 0.04 * k, top + 0.16), (0.2, top - 0.02), (0.03, top - 0.06)]
        plate(hook, 0.025, s["metal"], [1, 2], s["edge"])
    if k == 4:
        for dx in (-1, 1):
            m = mark()
            plate([(0, 0), (0.05, 0.1), (0, 0.42), (-0.05, 0.1)], 0.02, "white", [0, 1, 2, 3], "white")
            place(m, rot=(0, 0, -dx * 22), at=(dx * 0.05, top + 0.1, 0))
    jewels((0, top, 0.065), k, s, 1, 0.032)


def throwing(k):
    """A light axe balanced for throwing, its head raked forward like a
    francisca: a hatchet, then a tomahawk with a spike, growing wicked and
    pale. A tassel at the butt streams behind it in flight."""
    s = SETS[k]
    sz = s["size"]
    top = 0.62
    haft(-0.25, top + 0.06, 0.034, s, k, [(-0.2, 0.22)])
    collar(top, 0.05, s, k, 0.12)
    m = mark()
    crescent(0.0, 0.36 * sz, 0.17 * sz, k, s, -1, beard=(k >= 2), half=0.028)
    place(m, rot=(0, 0, -42), at=(0, top, 0))
    tassel = "tan" if k == 0 else ("red" if k == 3 else ("gold" if k == 4 else "leather"))
    for a in (-18, 0, 18):
        m = mark()
        plate([(0, 0), (0.025, -0.05), (0, -0.2 - 0.02 * k), (-0.025, -0.05)], 0.008, tassel)
        place(m, rot=(0, 0, a), at=(0, -0.27, 0))
    if k >= 1:
        spike((0.04, top, 0), 0.035, (0.2 + 0.03 * k, top - 0.03, 0), s["metal"] if k < 4 else "gold")
    jewels((0, top, 0.055), k, s, 1, 0.026)


FAMILIES = {"axe": axe, "maul": maul, "scythe": scythe, "twin": twin, "halberd": halberd, "throwing": throwing}

if __name__ == "__main__":
    only = sys.argv[1:]
    for name, build in FAMILIES.items():
        if only and name not in only:
            continue
        for k in range(len(SETS)):
            K.reset()
            build(k)
            export("barb_%s_%d" % (name, k), ROOT + "/assets/kaykit/weapons/barb_%s_%d.gltf" % (name, k))
