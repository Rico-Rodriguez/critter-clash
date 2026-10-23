"""The Knight's, Ranger's and Mage's weapons: six families each, in the five sets.

    python tools/art/make_hero_arms.py [family ...]   (Blender's Python: pip install bpy)

Writes assets/kaykit/weapons/<hero>_<family>_<set>.gltf (see GearDB.family_look),
in the same set ladder as the Barbarian's (make_barbarian_arms.py): scavenged,
clean steel, dark steel and gold, black iron and red, pale steel and gold.

Each is built the way KayKit's own weapons sit in the hand:
- melee weapons, staves, wands, knives: along +y, the grip at the origin,
  flat faces toward +-z;
- bows: in the x-z plane, limbs along z, the string on the -x side;
- crossbows: the stock along +z, the prod across x.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kk_mesh as K  # noqa: E402
from kk_mesh import ROOT, lathe, gem, plate, box, spike, mark, place, export  # noqa: E402
from make_barbarian_arms import SETS, haft, collar, jewels  # noqa: E402
from make_barbarian_armor import tube  # noqa: E402


def blade(y0, length, width, k, s, tip=0.22, guard_w=None, runes=False):
    """A straight double-edged blade up +y from y0. From Bloodiron the whole
    blade is edge metal with the dark body laid over it, so a rim shows."""
    pts = [(-width, y0), (width, y0), (width * 0.92, y0 + length * (1 - tip)), (0, y0 + length), (-width * 0.92, y0 + length * (1 - tip))]
    edges = [1, 2, 3]
    if k >= 3:
        plate(pts, 0.03, s["edge"], edges, s["edge"])
        inner = [(x * 0.62, y0 + 0.02 + (y - y0) * 0.9) for x, y in pts]
        plate(inner, 0.042, s["metal"])
    else:
        plate(pts, 0.03, s["metal"], edges, s["edge"])
    if k >= 2:
        # A fuller down the middle.
        plate([(-width * 0.18, y0 + 0.05), (width * 0.18, y0 + 0.05), (width * 0.12, y0 + length * 0.7), (-width * 0.12, y0 + length * 0.7)],
              0.036, s["trim"] if k == 2 else "black")
    if runes:
        for i in range(4):
            y = y0 + 0.15 + i * length * 0.18
            gem((0, y, 0.045), 0.03, 0.04, 0.02, sw="white" if k == 4 else "red")
            gem((0, y, -0.045), 0.03, 0.04, 0.02, sw="white" if k == 4 else "red", facing=-1)


def guard(y, w, k, s):
    """A crossguard, swept up at the ends from Barrowsteel."""
    box((0, y, 0), (w, 0.07, 0.09), s["trim"] if k >= 1 else s["metal"])
    if k >= 2:
        for sx in (-1, 1):
            spike((sx * w * 0.45, y, 0), 0.04, (sx * (w * 0.5 + 0.06 + 0.03 * k), y + 0.12 + 0.03 * k, 0), s["trim"], sides=4)


def pommel(y, k, s, r=0.05):
    lathe([(y - r, r * 0.6), (y - r * 0.5, r), (y + r * 0.5, r), (y + r, r * 0.6)], s["trim"] if k >= 1 else s["metal"], sides=6)
    if k >= 3:
        gem((0, y, r * 0.9), r * 0.6, r * 0.7, r * 0.5, sw="red" if k == 3 else "white")


# --- The Knight ---------------------------------------------------------------

def sword(k):
    s = SETS[k]
    sz = s["size"]
    haft(-0.3, 0.06, 0.035, s, k, [(-0.26, 0.28)])
    pommel(-0.32, k, s)
    guard(0.08, 0.34 + 0.05 * k, k, s)
    blade(0.1, (1.0 + 0.07 * k) * sz, 0.085 * sz, k, s)
    jewels((0, 0.08, 0.05), k, s, 1, 0.03)


def mace(k):
    s = SETS[k]
    sz = s["size"]
    top = 0.72
    haft(-0.3, top, 0.035, s, k, [(-0.26, 0.26)])
    pommel(-0.32, k, s, 0.04)
    r = 0.13 * sz
    if k == 0:
        lathe([(top - 0.12, 0.05), (top, 0.12), (top + 0.18, 0.13), (top + 0.26, 0.06)], "wood", sides=7)
        for y in (top - 0.02, top + 0.14):
            lathe([(y, 0.135), (y + 0.035, 0.135)], "rust", sides=7)
        spike((0.12, top + 0.08, 0), 0.025, (0.2, top + 0.1, 0), "rust", sides=3)
        spike((-0.12, top + 0.12, 0), 0.025, (-0.2, top + 0.16, 0), "rust", sides=3)
        return
    lathe([(top - 0.04, r * 0.4), (top + 0.03, r * 0.9), (top + 0.2, r), (top + 0.3, r * 0.5), (top + 0.33, 0.0)], s["metal"], sides=8)
    collar(top - 0.04, 0.05, s, k, 0.08)
    # Flanges round the head, more and taller each set.
    n = 4 + 2 * (k >= 2)
    for i in range(n):
        m = mark()
        fl = (0.1 + 0.02 * k) * sz
        plate([(0, 0), (fl, 0.04), (fl, 0.22), (0, 0.28)], 0.018, s["trim"] if k >= 2 else s["metal"], [1, 2], s["edge"])
        place(m, rot=(0, i * 360 / n, 0), at=(0, top + 0.02, 0))
    if k >= 3:
        spike((0, top + 0.3, 0), 0.05, (0, top + 0.5 + 0.06 * (k == 4), 0), "red" if k == 3 else "gold")


def spear(k):
    s = SETS[k]
    sz = s["size"]
    top = 1.45
    haft(-0.95, top, 0.035, s, k, [(-0.15, 0.32)])
    collar(top, 0.05, s, k, 0.16)
    ln = (0.36 + 0.05 * k) * sz
    wd = (0.08 + 0.01 * k) * sz
    pts = [(0, top + 0.08), (wd, top + 0.08 + ln * 0.3), (0, top + 0.08 + ln), (-wd, top + 0.08 + ln * 0.3)]
    plate(pts, 0.025, s["edge"] if k >= 3 else s["metal"], [0, 1, 2, 3], s["edge"])
    if k >= 1:
        # Lugs below the point stop a foe running up the shaft.
        box((0, top + 0.02, 0), (0.22 + 0.04 * k, 0.04, 0.05), s["trim"])
    if k == 4:
        for sx in (-1, 1):
            m = mark()
            plate([(0, 0), (0.05, 0.08), (0, 0.32), (-0.04, 0.08)], 0.018, "gold", [0, 1, 2, 3], "gold")
            place(m, rot=(0, 0, -sx * 35), at=(sx * 0.06, top + 0.05, 0))
    if k == 0:
        for q in range(3):
            lathe([(top - 0.18 + q * 0.05, 0.05), (top - 0.15 + q * 0.05, 0.05)], "tan", sides=5)
    jewels((0, top + 0.08 + ln * 0.3, 0.03), k, s, 1, 0.025)


def flail(k):
    s = SETS[k]
    sz = s["size"]
    haft(-0.3, 0.35, 0.035, s, k, [(-0.26, 0.3)])
    pommel(-0.32, k, s, 0.04)
    collar(0.35, 0.045, s, k, 0.08)
    # The chain, hanging straight up from the haft, and the ball.
    for i in range(4):
        y = 0.43 + i * 0.09
        box((0, y, 0), (0.04, 0.07, 0.04) if i % 2 == 0 else (0.02, 0.07, 0.06), "steel_dark" if k else "rust")
    c = 0.85 + 0.03 * k
    r = (0.12 + 0.015 * k) * sz
    lathe([(c - r, 0.0), (c - r * 0.7, r * 0.72), (c, r), (c + r * 0.7, r * 0.72), (c + r, 0.0)], s["metal"] if k else "rust", sides=8)
    if k >= 1:
        n = 4 + 2 * k
        for i in range(n):
            a = i * 2 * math.pi / n
            el = 0.6 if i % 2 else -0.3
            d = (math.cos(a) * math.cos(el), math.sin(el), math.sin(a) * math.cos(el))
            spike((d[0] * r * 0.85, c + d[1] * r * 0.85, d[2] * r * 0.85), 0.03, (d[0] * (r + 0.09 + 0.02 * k), c + d[1] * (r + 0.09 + 0.02 * k), d[2] * (r + 0.09 + 0.02 * k)),
                  "red" if k == 3 else ("gold" if k == 4 else s["metal"]), sides=3)
    spike((0, c + r * 0.85, 0), 0.035, (0, c + r + 0.14, 0), s["edge"] if k else "rust", sides=4)


def warhammer(k):
    s = SETS[k]
    sz = s["size"]
    top = 0.82
    haft(-0.32, top + 0.1, 0.04, s, k, [(-0.28, 0.3)])
    pommel(-0.34, k, s, 0.045)
    w, hh = 0.3 * sz, 0.2 * sz
    box((w * 0.25, top, 0), (w, hh, hh), s["metal"])
    box((w * 0.75 + 0.03, top, 0), (0.06, hh * 1.15, hh * 1.15), s["trim"] if k >= 2 else s["metal"])
    # The back: a beak to pierce helms.
    spike((-w * 0.25, top, 0), hh * 0.45, (-w * 0.25 - 0.3 - 0.04 * k, top - 0.08, 0), s["edge"] if k >= 3 else s["metal"])
    spike((w * 0.2, top + hh * 0.5, 0), 0.05, (w * 0.2, top + hh * 0.5 + 0.2 + 0.04 * k, 0), s["trim"] if k >= 2 else s["metal"])
    collar(top - hh * 0.6, 0.055, s, k, 0.1)
    jewels((w * 0.25, top, hh * 0.52), k, s, 1, 0.035)


def runeblade(k):
    s = SETS[k]
    sz = s["size"]
    haft(-0.36, 0.06, 0.038, s, k, [(-0.32, 0.34)])
    pommel(-0.38, k, s, 0.055)
    guard(0.08, 0.42 + 0.05 * k, k, s)
    blade(0.1, (1.18 + 0.08 * k) * sz, 0.11 * sz, k, s, tip=0.18, runes=True)
    if k >= 2:
        # A ring of light where the blade leaves the guard.
        lathe([(0.12, 0.1), (0.18, 0.1)], s["trim"], sides=8)
    jewels((0, 0.08, 0.05), k, s, 1, 0.035)


# --- The Ranger -----------------------------------------------------------------

def _limbs(half, depth, r, s, k, recurve=False):
    """A bow's limbs and string in the x-y plane (y along the limbs), then laid
    into x-z: the grip at the origin, the tips back toward -x."""
    m = mark()
    pts, rad = [], []
    n = 8
    for i in range(n + 1):
        t = -1 + 2 * i / n
        y = half * t
        x = -depth * t * t
        if recurve and abs(t) > 0.75:
            x += depth * 0.6 * (abs(t) - 0.75) / 0.25
        pts.append((x, y, 0))
        rad.append(r * (1.25 - 0.6 * abs(t)))
    wood = s["haft"] if k else "wood"
    tube(pts[: n // 2 + 1], rad[: n // 2 + 1], wood, sides=5)
    tube(pts[n // 2:], rad[n // 2:], wood, sides=5)
    # The grip and the string.
    lathe([(-0.12, r * 1.6), (0.12, r * 1.6)], s["wrap"], sides=6)
    tip_x = pts[0][0]
    tube([(tip_x - 0.01, -half, 0), (tip_x - 0.01, half, 0)], [0.008, 0.008], "white" if k >= 3 else "tan", sides=3)
    if k >= 1:
        for sy in (-1, 1):
            spike((tip_x, sy * half * 0.98, 0), r * 0.9, (tip_x - 0.02, sy * (half + 0.1 + 0.03 * k), 0), s["trim"], sides=4)
    if k >= 2:
        for sy in (-1, 1):
            lathe([(sy * 0.18 - 0.03, r * 1.5), (sy * 0.18 + 0.03, r * 1.5)], s["trim"], sides=6)
    if k >= 3:
        # Blades along the backs of the limbs.
        for sy in (-1, 1):
            mm = mark()
            plate([(0, 0), (0.06, 0.1), (0.02, 0.4), (-0.01, 0.1)], 0.012, s["edge"], [1, 2], s["edge"])
            place(mm, rot=(0, 0, 0 if sy > 0 else 180), at=(0.03, sy * 0.22, 0))
        gem((0.04, 0, 0.0), 0.04, 0.05, 0.03, sw="red" if k == 3 else "white")
    place(m, rot=(90, 0, 0))


def shortbow(k):
    s = SETS[k]
    _limbs(0.78 * s["size"], 0.5, 0.035, s, k)


def longbow(k):
    s = SETS[k]
    _limbs(1.12 * s["size"], 0.42, 0.038, s, k)


def soulbow(k):
    s = SETS[k]
    _limbs(1.0 * s["size"], 0.55, 0.042, s, k, recurve=True)


def knives(k):
    s = SETS[k]
    sz = s["size"]
    haft(-0.2, 0.03, 0.03, s, k, [(-0.18, 0.18)])
    box((0, 0.04, 0), (0.16 + 0.02 * k, 0.04, 0.06), s["trim"] if k else "rust")
    blade(0.06, (0.38 + 0.04 * k) * sz, 0.055 * sz, k, s, tip=0.35)
    if k >= 2:
        lathe([(-0.25, 0.03), (-0.22, 0.045), (-0.2, 0.03)], s["trim"], sides=5)


def _crossbow(k, s, scale, magazine=False):
    sz = s["size"] * scale
    m = mark()
    # The stock along +z, its grip hanging below.
    box((0, 0, 0.3 * sz), (0.09, 0.09, 1.0 * sz), s["haft"] if k else "wood")
    box((0, -0.13, -0.02), (0.07, 0.2, 0.09), s["wrap"])
    box((0, 0.06, 0.3 * sz), (0.035, 0.02, 0.95 * sz), s["metal"] if k else "rust")
    # The prod: a short bow across the front.
    pm = mark()
    _prod(0.48 * sz, 0.16 * sz, 0.03, s, k)
    place(pm, at=(0, 0.02, 0.72 * sz))
    if magazine:
        box((0, 0.13, 0.35 * sz), (0.1, 0.12, 0.3 * sz), s["trim"] if k >= 2 else s["metal"])
    if k >= 2:
        spike((0, 0, 0.82 * sz), 0.04, (0, 0, 0.82 * sz + 0.14 + 0.03 * k), s["edge"], sides=4)
    if k >= 3:
        gem((0.05, 0, 0.1), 0.035, 0.04, 0.025, sw="red" if k == 3 else "white")
    place(m, scale=1.0)


def _prod(half, depth, r, s, k):
    """The crossbow's bow: across x, bending back toward -z, with its string."""
    pts, rad = [], []
    n = 6
    for i in range(n + 1):
        t = -1 + 2 * i / n
        pts.append((half * t, 0, -depth * t * t))
        rad.append(r * (1.2 - 0.5 * abs(t)))
    tube(pts, rad, s["metal"] if k else "wood", sides=5)
    tube([(-half, 0, -depth - 0.01), (0, 0, -depth - 0.25), (half, 0, -depth - 0.01)], [0.007, 0.007, 0.007], "white" if k >= 3 else "tan", sides=3)
    if k >= 1:
        for sx in (-1, 1):
            spike((sx * half, 0, -depth), r, (sx * (half + 0.08 + 0.02 * k), 0, -depth + 0.04), s["trim"], sides=4)


def crossbow(k):
    _crossbow(k, SETS[k], 1.0)


def repeater(k):
    _crossbow(k, SETS[k], 0.78, magazine=True)


# --- The Mage ---------------------------------------------------------------------

def _orb(c, r, sw, sides=7):
    lathe([(c - r, 0.0), (c - r * 0.6, r * 0.8), (c, r), (c + r * 0.6, r * 0.8), (c + r, 0.0)], sw, sides=sides)


STONE = ["stone", "copper", "gold", "red", "white"]


def staff(k):
    s = SETS[k]
    sz = s["size"]
    top = 1.15
    haft(-0.9, top, 0.04, s, k, [(-0.1, 0.3)])
    if k == 0:
        # A forked branch holding a pebble.
        for sx in (-1, 1):
            tube([(0, top - 0.05, 0), (sx * 0.1, top + 0.12, 0), (sx * 0.07, top + 0.3, 0)], [0.035, 0.025, 0.012], "wood")
        _orb(top + 0.14, 0.07, "stone")
        return
    collar(top, 0.05, s, k, 0.1)
    # A cradle of prongs round the stone, more of them each set.
    n = 2 + k
    c = top + 0.2 + 0.02 * k
    for i in range(n):
        a = i * 2 * math.pi / n
        tube([(0, top + 0.03, 0), (math.cos(a) * 0.12, c - 0.06, math.sin(a) * 0.12), (math.cos(a) * 0.06, c + 0.16 + 0.02 * k, math.sin(a) * 0.06)],
             [0.03, 0.022, 0.006], s["trim"] if k >= 2 else s["metal"], sides=4)
    _orb(c, (0.085 + 0.01 * k) * sz, STONE[k])
    if k == 4:
        for sx in (-1, 1):
            m = mark()
            plate([(0, 0), (0.18, 0.08), (0.24, 0.26), (0.08, 0.1)], 0.015, "gold", [1, 2], "white")
            place(m, rot=(0, 0 if sx > 0 else 180, 0), at=(0, top + 0.06, 0))


def wand(k):
    s = SETS[k]
    sz = s["size"]
    lathe([(-0.24, 0.022), (0.0, 0.03), (0.42, 0.02)], s["haft"] if k else "wood", sides=6)
    lathe([(-0.2, 0.034), (0.02, 0.034)], s["wrap"], sides=6)
    if k >= 1:
        collar(0.42, 0.03, s, k, 0.06)
    _orb(0.5, (0.04 + 0.006 * k) * sz, STONE[k], sides=6)
    if k >= 2:
        for i in range(3):
            a = i * 2 * math.pi / 3
            spike((math.cos(a) * 0.03, 0.46, math.sin(a) * 0.03), 0.012, (math.cos(a) * 0.06, 0.6 + 0.02 * k, math.sin(a) * 0.06), s["trim"], sides=3)


def tome(k):
    """A closed spellbook held up by its spine: covers, pages, metal corners,
    a clasp, and a stone on the cover."""
    s = SETS[k]
    sz = s["size"]
    w, h, d = 0.36 * sz, 0.46 * sz, 0.13 * sz
    cover = ["leather", "red", "black", "black", "white"][k]
    box((0, 0.1, 0), (w, h, d), cover)
    box((0.015, 0.1, 0), (w * 0.94, h * 0.92, d * 0.8), "tan" if k < 4 else "white")
    if k >= 1:
        for sx in (-1, 1):
            for sy in (-1, 1):
                box((sx * w * 0.42, 0.1 + sy * h * 0.42, 0), (w * 0.2, h * 0.16, d * 1.08), s["trim"])
    box((w * 0.5, 0.1, 0), (0.04, 0.08, d * 1.1), s["metal"] if k else "rust")
    gem((0, 0.1, d * 0.52), 0.05 + 0.008 * k, 0.06 + 0.008 * k, 0.03, sw=STONE[k] if k else "stone")
    if k >= 3:
        for sy in (-1, 1):
            spike((0, 0.1 + sy * h * 0.5, d * 0.5), 0.025, (0, 0.1 + sy * (h * 0.5 + 0.08), d * 0.6), s["edge"], sides=3)


def scepter(k):
    s = SETS[k]
    sz = s["size"]
    top = 0.55
    lathe([(-0.24, 0.03), (top, 0.032)], s["haft"] if k else "wood", sides=6)
    lathe([(-0.2, 0.04), (0.02, 0.04)], s["wrap"], sides=6)
    pommel(-0.26, k, s, 0.04)
    collar(top, 0.045, s, k, 0.08)
    _orb(top + 0.12, (0.07 + 0.008 * k) * sz, STONE[k])
    n = 4 + k
    for i in range(n):
        a = i * 2 * math.pi / n
        spike((math.cos(a) * 0.07, top + 0.06, math.sin(a) * 0.07), 0.02, (math.cos(a) * 0.12, top + 0.26 + 0.02 * k, math.sin(a) * 0.12),
              s["trim"] if k >= 1 else "rust", sides=3)


def skullstaff(k):
    s = SETS[k]
    sz = s["size"]
    top = 1.15
    haft(-0.9, top, 0.042, s, k, [(-0.1, 0.32)])
    collar(top, 0.05, s, k, 0.1)
    c = top + 0.2
    r = 0.14 * sz
    # The skull: a round cranium, a jaw, dark sockets lit in the set's stone.
    _orb(c, r, "bone", sides=8)
    box((0, c - r * 0.85, r * 0.25), (r * 1.1, r * 0.45, r * 1.0), "bone")
    for sx in (-1, 1):
        gem((sx * r * 0.38, c - r * 0.1, r * 0.92), r * 0.24, r * 0.26, r * 0.08, sw=STONE[k] if k >= 3 else "black")
    if k >= 2:
        for sx in (-1, 1):
            tube([(sx * r * 0.8, c + r * 0.3, 0), (sx * (r + 0.12), c + r * 0.7, -0.03), (sx * (r + 0.1), c + r + 0.18 + 0.04 * k, -0.06)],
                 [0.04, 0.025, 0.004], "black" if k == 3 else ("gold" if k == 4 else s["trim"]), sides=5)


def soulstaff(k):
    s = SETS[k]
    sz = s["size"]
    top = 1.25
    haft(-0.95, top, 0.04, s, k, [(-0.1, 0.3), (0.6, 0.1)])
    collar(top, 0.055, s, k, 0.12)
    c = top + 0.3
    # A crescent of metal opening upward, a great stone floating in it.
    pts = []
    for i in range(9):
        a = math.pi * (1.1 + 0.8 * i / 8)
        pts.append((0.26 * sz * math.cos(a), c + 0.24 * sz * math.sin(a)))
    inner = [(x * 0.72, c + (y - c) * 0.72) for x, y in reversed(pts)]
    plate(pts + inner, 0.03, s["trim"] if k >= 2 else s["metal"])
    _orb(c + 0.02, (0.1 + 0.01 * k) * sz, STONE[k], sides=8)
    spike((0, c - 0.24 * sz, 0), 0.04, (0, c - 0.24 * sz - 0.01, 0.0), s["trim"], sides=3)
    if k >= 3:
        for sx in (-1, 1):
            spike((sx * 0.25 * sz, c + 0.08, 0), 0.03, (sx * 0.34 * sz, c + 0.3, 0), s["edge"], sides=3)


FAMILIES = {
    "knight": {"sword": sword, "mace": mace, "spear": spear, "flail": flail, "warhammer": warhammer, "runeblade": runeblade},
    "ranger": {"shortbow": shortbow, "knives": knives, "crossbow": crossbow, "longbow": longbow, "repeater": repeater, "soulbow": soulbow},
    "mage": {"staff": staff, "wand": wand, "tome": tome, "scepter": scepter, "skullstaff": skullstaff, "soulstaff": soulstaff},
}

if __name__ == "__main__":
    only = sys.argv[1:]
    for hero, fams in FAMILIES.items():
        for name, build in fams.items():
            if only and name not in only:
                continue
            for k in range(len(SETS)):
                K.reset()
                build(k)
                export("%s_%s_%d" % (hero, name, k), ROOT + "/assets/kaykit/weapons/%s_%s_%d.gltf" % (hero, name, k))
