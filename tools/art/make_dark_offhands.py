"""Every hero's offhand in the five sets, in the dark palette: the Knight's
and the Barbarian's shields, the Rogue's parrying dagger, the Mage's tome and
the Ranger's quiver.

    python tools/art/make_dark_offhands.py [hero ...]   (Blender's Python: pip install bpy)

Writes assets/kaykit/weapons/<prefix>_off_<set>.gltf, sitting as the KayKit
props they replace do: shields face +z in the x-y plane, the dagger points up
+y, the tome stands on its spine edge (covers to +-x), the quiver runs up +y.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kk_mesh as K  # noqa: E402
from kk_mesh import ROOT, lathe, gem, plate, box, spike, mark, place, export  # noqa: E402
from make_barbarian_arms import SETS, haft  # noqa: E402
from make_hero_arms import blade, guard, pommel  # noqa: E402

K.DARK = True
# The badge on each set's shield, as on its armour.
EMBLEM = [None, "cross", "star", "fang", "sun"]


def star(c, r, sw, pts=4, depth=0.02, inner=0.4, z=1):
    """A flat star standing off a face toward +z (or -z)."""
    ring = []
    for i in range(pts * 2):
        a = math.pi / 2 + i * math.pi / pts
        rr = r if i % 2 == 0 else r * inner
        ring.append((c[0] + rr * math.cos(a), c[1] + rr * math.sin(a)))
    m = mark()
    plate(ring, depth / 2, sw)
    place(m, at=(0, 0, c[2] + z * depth / 2))


def emblem(kind, y, z, s, size=1.0):
    if kind == "cross":
        m = mark()
        plate([(-0.035, -0.2), (0.035, -0.2), (0.035, 0.2), (-0.035, 0.2)], 0.012, s["trim"])
        plate([(-0.14, 0.04), (0.14, 0.04), (0.14, 0.11), (-0.14, 0.11)], 0.012, s["trim"])
        place(m, at=(0, y, z + 0.012), scale=size)
    elif kind == "star":
        star((0, y, z), 0.15 * size, s["trim"], pts=4, depth=0.024)
        star((0, y, z + 0.02), 0.07 * size, "white", pts=4, depth=0.02)
    elif kind == "fang":
        star((0, y, z), 0.13 * size, s["trim"], pts=3, depth=0.024, inner=0.3)
        gem((0, y, z + 0.03), 0.05 * size, 0.06 * size, 0.04, sw="red")
    elif kind == "sun":
        star((0, y, z), 0.18 * size, s["trim"], pts=8, depth=0.022, inner=0.55)
        gem((0, y, z + 0.025), 0.06 * size, 0.06 * size, 0.05, sw="white")


def rim(pts, s, half, z, k):
    """The shield's raised border: the outline again, a size up, behind the face."""
    m = mark()
    plate([(x * 1.07, y * 1.07) for x, y in pts], half, s["trim"] if k else s["metal"], edges=range(len(pts)) if k >= 3 else (), edge_sw=s["edge"])
    place(m, at=(0, 0, z))


def grip(s):
    """The strap and handle on the back."""
    box((0, 0.0, -0.1), (0.05, 0.3, 0.05), s["wrap"])
    box((0, 0.15, -0.075), (0.05, 0.04, 0.05), s["haft"])
    box((0, -0.15, -0.075), (0.05, 0.04, 0.05), s["haft"])


def knight_shield(k):
    """A heater shield: a buckler at Gravedigger, then taller and pointed,
    spiked at Bloodiron, winged at Gravelight."""
    s = SETS[k]
    if k == 0:
        # A scavenged round buckler of planks with an iron boss.
        lathe([(-0.07, 0.0), (-0.06, 0.36), (0.02, 0.36), (0.04, 0.0)], s["haft"], sides=10)
        lathe([(0.0, 0.1), (0.07, 0.07), (0.1, 0.0)], s["metal"], sides=8)
        lathe([(-0.07, 0.38), (0.0, 0.38)], s["trim"], sides=10)
        # Turned along y: face them to +z.
        place(0, rot=(90, 0, 0))
        for x in (-0.2, 0.2):
            box((x, 0, 0.02), (0.04, 0.6, 0.02), s["metal"])
        grip(s)
        return
    w = 0.38 + 0.02 * k
    top = 0.42 + 0.03 * k
    bot = -0.55 - 0.05 * k
    pts = [(-w, top), (-w, top - 0.12), (-w * 0.92, bot * 0.25), (-w * 0.55, bot * 0.75), (0, bot), (w * 0.55, bot * 0.75), (w * 0.92, bot * 0.25),
           (w, top - 0.12), (w, top)]
    pts = list(reversed(pts))
    rim(pts, s, 0.03, -0.03, k)
    plate(pts, 0.035, s["metal"], t=(0.25, 0.6))
    # A ridge down the middle.
    plate([(-0.03, bot * 0.9), (0.03, bot * 0.9), (0.03, top * 0.95), (-0.03, top * 0.95)], 0.05, s["trim"])
    emblem(EMBLEM[k], 0.02, 0.05, s, size=1.0 + 0.08 * k)
    if k >= 3:
        for x, y in ((-w, top), (w, top), (0, bot)):
            spike((x * 0.95, y * 0.95, 0.0), 0.04, (x * 1.25, y * 1.18 + (0.05 if y > 0 else -0.08), 0.0), s["edge"])
    if k == 4:
        wing = [(0, 0), (0.22, 0.12), (0.3, 0.3), (0.12, 0.2), (0, 0.12)]
        for sgn in (-1, 1):
            m = mark()
            plate(wing if sgn > 0 else [(-x, y) for x, y in reversed(wing)], 0.015, s["trim"])
            place(m, at=(sgn * w * 0.9, top - 0.08, 0.0))
    grip(s)


def barb_shield(k):
    """A round shield of planks, iron-bound, its boss growing a spike."""
    s = SETS[k]
    r = 0.4 + 0.03 * k
    m = mark()
    lathe([(-0.05, 0.0), (-0.045, r), (0.03, r * 0.98), (0.05, 0.0)], s["haft"] if k < 4 else "pale", sides=10)
    lathe([(-0.06, r * 1.04), (0.045, r * 1.04)], s["trim"] if k else s["metal"], sides=10)
    lathe([(0.03, 0.13), (0.1, 0.1), (0.13, 0.0)], s["metal"], sides=8)
    place(m, rot=(90, 0, 0))
    for a in range(0, 180, 60 if k < 2 else 45):
        m = mark()
        box((0, 0, 0.055), (0.035, r * 1.9, 0.02), s["metal"])
        place(m, rot=(0, 0, a))
    if k >= 2:
        for i in range(8):
            a = i * math.pi / 4
            box((r * 0.88 * math.cos(a), r * 0.88 * math.sin(a), 0.065), (0.04, 0.04, 0.03), s["trim"])
    if k >= 3:
        spike((0, 0, 0.12), 0.06, (0, 0, 0.35 + 0.05 * k), s["edge"], sides=5)
    if k == 4:
        emblem("sun", 0, 0.08, s, size=1.3)
    grip(s)


def rogue_dagger(k):
    """A parrying dagger: a short blade with side rings that grow to hooks."""
    s = SETS[k]
    ln = 0.5 + 0.05 * k
    blade(0.16, ln, 0.05 + 0.005 * k, k, s, tip=0.3)
    guard(0.14, 0.22 + 0.03 * k, k, s)
    if k >= 2:
        # Hooks to catch a blade, curling up off the guard.
        for sgn in (-1, 1):
            spike((sgn * (0.11 + 0.015 * k), 0.14, 0), 0.02, (sgn * (0.14 + 0.02 * k), 0.3 + 0.03 * k, 0), s["edge"])
    haft(-0.12, 0.12, 0.028, s, k, wraps=((-0.08, 0.17),))
    pommel(-0.14, k, s, r=0.04)


def mage_tome(k):
    """A grimoire on its spine: board covers, clasps, a sigil; it grows
    corners, a skull-red stone and finally gilt wings."""
    s = SETS[k]
    cover = {0: "hide", 1: "wine", 2: "black", 3: "blood", 4: "white"}[k]
    box((0, 0, 0), (0.2, 0.52, 0.4), "bone")
    box((0.11, 0, 0), (0.03, 0.56, 0.43), cover)
    box((-0.11, 0, 0), (0.03, 0.56, 0.43), cover)
    box((0, 0, -0.205), (0.25, 0.56, 0.03), cover)
    if k >= 1:
        for y in (-0.15, 0.15):
            box((0, y, 0.215), (0.26, 0.05, 0.02), s["trim"])
    if k >= 2:
        for sgn in (-1, 1):
            for y in (-0.25, 0.25):
                for z in (-0.19, 0.19):
                    box((sgn * 0.125, y, z), (0.02, 0.07, 0.07), s["trim"])
    m = mark()
    sym = {0: None, 1: "cross", 2: "star", 3: "fang", 4: "sun"}[k]
    if sym:
        emblem(sym, 0.0, 0.0, s, size=0.9)
        place(m, rot=(0, 90, 0), at=(0.125, 0, 0))
        m = mark()
        emblem(sym, 0.0, 0.0, s, size=0.9)
        place(m, rot=(0, -90, 0), at=(-0.125, 0, 0))


def ranger_quiver(k):
    """A quiver of hide, then leather banded in the set's metal, full of
    arrows whose fletching takes the set's colors."""
    s = SETS[k]
    body = {0: "hide", 1: "hide", 2: "black", 3: "black", 4: "pale"}[k]
    lathe([(-0.42, 0.0), (-0.4, 0.11), (0.3, 0.13), (0.36, 0.14)], body, sides=8)
    for y in ([-0.3, 0.25] if k < 2 else [-0.36, -0.05, 0.25]):
        lathe([(y, 0.135), (y + 0.04, 0.135)], s["trim"] if k else "hide", sides=8)
    if k >= 2:
        star((0, 0.0, 0.14), 0.07, s["trim"], pts=4 if k != 4 else 8, depth=0.02)
    fl = {0: "fur", 1: "white", 2: "silver", 3: "red", 4: "agold"}[k]
    for i, (x, z) in enumerate(((-0.05, -0.04), (0.04, -0.05), (0.0, 0.04), (0.06, 0.03), (-0.06, 0.05))):
        h = 0.36 + 0.06 * (i % 3)
        box((x, h, z), (0.014, 0.3, 0.014), "wood")
        m = mark()
        plate([(-0.03, 0), (0.03, 0), (0.012, 0.12), (-0.012, 0.12)], 0.004, fl)
        place(m, at=(x, h + 0.06, z), rot=(0, 45 * i, 0))
    # A strap across the back of it.
    box((0, -0.05, -0.135), (0.06, 0.7, 0.02), "hide")


HEROES = {"knight": knight_shield, "barb": barb_shield, "rogue": rogue_dagger, "mage": mage_tome, "ranger": ranger_quiver}


if __name__ == "__main__":
    only = sys.argv[1:]
    for name, build in HEROES.items():
        if only and name not in only:
            continue
        for k in range(len(SETS)):
            K.reset()
            build(k)
            export("%s_off_%d" % (name, k), ROOT + "/assets/kaykit/weapons/%s_off_%d.gltf" % (name, k))
