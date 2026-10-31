"""The boss uniques' weapons and offhands, and the Mage's offhand
alternatives, in the dark palette (make_barbarian_arms.py) and the uniques'
own colors (dark_swatches.py).

    python tools/art/make_unique_arms.py [name ...]   (Blender's Python: pip install bpy)

Writes assets/kaykit/weapons/uniq_<name>.gltf. Each sits as its family's
weapons do (make_hero_arms.py): melee along +y with the grip at the origin,
bows in the x-z plane; shields face +z; the Mage's held pieces stand on the
hand, about the origin.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kk_mesh as K  # noqa: E402
from kk_mesh import ROOT, lathe, gem, plate, box, spike, mark, place, export  # noqa: E402
from make_barbarian_arms import SETS, haft, collar  # noqa: E402
from make_barbarian_armor import tube  # noqa: E402
from make_hero_arms import _limbs, _orb, guard, pommel  # noqa: E402
import make_dark_offhands as OFF  # noqa: E402

K.DARK = True


def mat(k, **over):
    """Set k's materials, with the unique's own laid over them."""
    return dict(SETS[k], **over)


def cleaver():
    """Gravemaw's Cleaver: a butcher's slab of a blade, a row of the maw's
    teeth along its spine, its edge a sickly green."""
    s = mat(3, haft="black", wrap="hide", metal="iron", edge="verdant", trim="bone")
    top = 1.0
    haft(-0.45, top + 0.35, 0.045, s, 3, [(-0.3, 0.28), (0.25, 0.18)])
    pts = [(-0.04, top + 0.34), (-0.04, top - 0.2), (-0.5, top - 0.28), (-0.62, top - 0.1), (-0.6, top + 0.3), (-0.5, top + 0.4)]
    plate(pts, 0.03, "iron", [1, 2, 3], "verdant")
    plate([(x * 0.7 - 0.02, top + 0.06 + (y - top - 0.06) * 0.7) for x, y in pts], 0.04, "black")
    for i in range(5):
        x = -0.1 - i * 0.1
        spike((x, top + 0.36 - i * 0.008, 0), 0.03, (x - 0.02, top + 0.5 - i * 0.008, 0), "bone", sides=4)
    gem((-0.3, top + 0.05, 0.05), 0.06, 0.07, 0.04, sw="verdant")
    gem((-0.3, top + 0.05, -0.05), 0.06, 0.07, 0.04, sw="verdant", facing=-1)


def scepter():
    """Hexer's Scepter: a black rod, a violet stone held in a cage of thorns."""
    s = mat(3, haft="black", wrap="wine", trim="agold", metal="iron")
    top = 0.55
    lathe([(-0.24, 0.03), (top, 0.033)], "black", sides=6)
    lathe([(-0.2, 0.04), (0.02, 0.04)], "wine", sides=6)
    pommel(-0.26, 3, s, 0.04)
    collar(top, 0.045, s, 3, 0.08)
    c = top + 0.16
    _orb(c, 0.09, "violet")
    for i in range(5):
        a = i * 2 * math.pi / 5
        ca, sa = math.cos(a), math.sin(a)
        tube([(ca * 0.03, top + 0.03, sa * 0.03), (ca * 0.11, c - 0.04, sa * 0.11), (ca * 0.1, c + 0.08, sa * 0.1), (ca * 0.02, c + 0.2, sa * 0.02)],
             [0.02, 0.016, 0.012, 0.0], "bark", sides=4)
        spike((ca * 0.11, c, sa * 0.11), 0.01, (ca * 0.18, c + 0.03, sa * 0.18), "bark", sides=3)


def thornbow():
    """Thornwood Longbow: limbs of living bark, thorns down their backs,
    leaves at the grip."""
    s = mat(3, haft="bark", wrap="moss", trim="verdant", edge="verdant")
    half = 1.2
    _limbs(half, 0.42, 0.042, s, 3)
    m = mark()
    for i in range(1, 8):
        t = -1 + 2 * i / 8
        if abs(t) < 0.2:
            continue
        x, y = -0.42 * t * t, half * t
        spike((x + 0.03, y, 0), 0.016, (x + 0.11, y + 0.03 * (1 if t > 0 else -1), 0), "bark", sides=3)
    for sy in (-1, 1):
        mm = mark()
        plate([(0, 0), (0.05, 0.06), (0.04, 0.16), (0, 0.2), (-0.02, 0.1)], 0.006, "verdant")
        place(mm, rot=(0, 0, -30 if sy > 0 else 210), at=(0.05, sy * 0.14, 0))
    place(m, rot=(90, 0, 0))


def gilded_fang():
    """Gilded Fangs: a pair of curved gold fangs, white at the edge."""
    s = mat(4, haft="black", wrap="blood", trim="agold", metal="agold", edge="white")
    haft(-0.2, 0.02, 0.032, s, 3, [(-0.17, 0.17)])
    pommel(-0.22, 3, s, r=0.042)
    guard(0.04, 0.24, 3, s)
    pts = []
    n = 6
    for i in range(n + 1):
        t = i / n
        pts.append((0.09 * (1 - t) + 0.14 * t * t, 0.06 + 0.52 * t))
    inner = [(-0.08 * (1 - t) + 0.1 * t * t, 0.06 + 0.42 * t) for t in (i / n for i in range(n, -1, -1))]
    plate(pts + inner, 0.026, "agold", list(range(n)), "white")
    gem((0.02, 0.12, 0.035), 0.022, 0.03, 0.02, sw="red")
    gem((0.02, 0.12, -0.035), 0.022, 0.03, 0.02, sw="red", facing=-1)


def rime_maul():
    """Glacierfall Maul: a hammer frozen into a block of ice, icicles all
    round it."""
    s = mat(2, haft="iron", wrap="hide", trim="silver", metal="iron")
    top = 0.85
    haft(-0.32, top + 0.1, 0.042, s, 2, [(-0.28, 0.3)])
    pommel(-0.34, 2, s, 0.045)
    collar(top - 0.14, 0.055, s, 2, 0.1)
    box((0, top, 0), (0.46, 0.26, 0.26), "frost")
    for sx in (-1, 1):
        box((sx * 0.25, top, 0), (0.05, 0.3, 0.3), "white")
    for x, y, z, dx, dy, dz in ((0, 0.13, 0, 0, 0.22, 0), (0.12, 0.13, 0.06, 0.03, 0.14, 0.02), (-0.12, 0.13, -0.06, -0.03, 0.16, -0.02),
                                (0, 0, 0.13, 0, 0.02, 0.16), (0, 0, -0.13, 0, 0.02, -0.16), (0.1, -0.13, 0.05, 0.02, -0.12, 0)):
        spike((x, top + y, z), 0.04, (x + dx, top + y + dy, z + dz), "frost", sides=4)


def cinder_maul():
    """Ashmaker: a black maul, its faces cracked open on live coals, ember
    spikes off its crown."""
    s = mat(3, haft="black", wrap="blood", trim="black", metal="iron")
    top = 0.95
    haft(-0.42, top, 0.05, s, 3, [(-0.3, 0.3), (0.3, 0.16)])
    collar(top - 0.02, 0.075, s, 3, 0.14)
    w, hh = 0.7, 0.34
    box((0, top + 0.1, 0), (w, hh, hh), "black")
    for sx in (-1, 1):
        box((sx * (w / 2 + 0.03), top + 0.1, 0), (0.06, hh * 0.8, hh * 0.8), "ember")
        box((sx * w * 0.2, top + 0.1, 0), (0.05, hh * 1.06, hh * 1.06), "ember")
    for dx in (-0.2, 0.0, 0.2):
        spike((dx, top + 0.1 + hh / 2, 0), 0.05, (dx, top + 0.42 + (0.06 if dx == 0 else 0), 0), "ember", sides=4)


def emberheart():
    """Emberheart: a burning heart in an iron cage, carried in the hand."""
    lathe([(-0.12, 0.05), (-0.1, 0.07), (-0.07, 0.06)], "iron", sides=6)
    _orb(0.06, 0.09, "ember")
    gem((0, 0.06, 0.09), 0.04, 0.05, 0.03, sw="red")
    for i in range(4):
        a = i * math.pi / 2 + math.pi / 4
        ca, sa = math.cos(a), math.sin(a)
        tube([(ca * 0.06, -0.07, sa * 0.06), (ca * 0.12, 0.06, sa * 0.12), (ca * 0.04, 0.19, sa * 0.04)], [0.012, 0.012, 0.012], "iron", sides=4)
    lathe([(0.18, 0.04), (0.21, 0.045), (0.24, 0.0)], "agold", sides=6)
    for i in range(3):
        a = i * 2 * math.pi / 3
        spike((math.cos(a) * 0.03, 0.14, math.sin(a) * 0.03), 0.025, (math.cos(a) * 0.05, 0.27 + 0.03 * (i == 0), math.sin(a) * 0.05), "ember", sides=3)


def seedheart():
    """Seedheart Aegis: a heater shield of bark bound in moss, a green seed
    at its heart, leaves round it."""
    keep, em = OFF.SETS[2], OFF.EMBLEM[2]
    OFF.SETS[2], OFF.EMBLEM[2] = mat(2, metal="bark", trim="moss", edge="verdant", haft="bark", wrap="hide"), None
    try:
        OFF.knight_shield(2)
    finally:
        OFF.SETS[2], OFF.EMBLEM[2] = keep, em
    # Planks of bark across the face, under the seed.
    for y in (-0.4, -0.2, 0.0, 0.2, 0.36):
        box((0, y, 0.045), (0.7 if y > -0.3 else 0.45, 0.025, 0.02), "hide")
    gem((0, 0.02, 0.07), 0.09, 0.12, 0.06, sw="verdant")
    for i in range(6):
        m = mark()
        plate([(0, 0), (0.04, 0.05), (0.03, 0.14), (0, 0.17), (-0.03, 0.12), (-0.035, 0.05)], 0.008, "verdant" if i % 2 else "moss")
        place(m, rot=(0, 0, i * 60), at=(0, 0.02, 0.07))


def skull_orb():
    """A skull with burning eyes, on an iron cup."""
    lathe([(-0.15, 0.05), (-0.12, 0.07), (-0.08, 0.06), (-0.06, 0.08)], "iron", sides=6)
    c, r = 0.05, 0.11
    _orb(c, r, "bone", sides=8)
    box((0, c - r * 0.85, r * 0.25), (r * 1.1, r * 0.45, r * 1.0), "bone")
    for sx in (-1, 1):
        gem((sx * r * 0.38, c - r * 0.1, r * 0.92), r * 0.24, r * 0.26, r * 0.08, sw="ember")


def candelabra():
    """Three black candles on a forked iron stand, their flames lit."""
    lathe([(-0.2, 0.07), (-0.17, 0.08), (-0.14, 0.03), (0.05, 0.025)], "iron", sides=6)
    box((0, 0.05, 0), (0.34, 0.03, 0.03), "iron")
    for x, h in ((-0.16, 0.12), (0.0, 0.18), (0.16, 0.12)):
        m = mark()
        lathe([(0.05, 0.035), (0.07, 0.04)], "agold", sides=6)
        lathe([(0.07, 0.025), (0.07 + h, 0.025)], "black", sides=6)
        spike((0, 0.07 + h, 0), 0.022, (0, 0.07 + h + 0.09, 0), "ember", sides=4)
        place(m, at=(x, 0, 0))


def phylactery():
    """A green glass bottle bound in iron, stoppered in gold."""
    lathe([(-0.15, 0.04), (-0.14, 0.09), (0.02, 0.1), (0.08, 0.05), (0.13, 0.03)], "verdant", sides=7)
    for y in (-0.12, 0.0):
        lathe([(y, 0.098), (y + 0.025, 0.098)], "iron", sides=7)
    for i in range(4):
        a = i * math.pi / 2
        box((math.cos(a) * 0.098, -0.05, math.sin(a) * 0.098), (0.02, 0.2, 0.02), "iron")
    lathe([(0.12, 0.04), (0.17, 0.04), (0.19, 0.0)], "agold", sides=6)
    gem((0, -0.04, 0.1), 0.03, 0.04, 0.02, sw="white")


ARMS = {
    "cleaver": cleaver, "scepter": scepter, "thornbow": thornbow, "gilded_fang": gilded_fang, "rime_maul": rime_maul, "cinder_maul": cinder_maul,
    "emberheart": emberheart, "seedheart": seedheart, "skull_orb": skull_orb, "candelabra": candelabra, "phylactery": phylactery,
}


if __name__ == "__main__":
    only = sys.argv[1:]
    for name, build in ARMS.items():
        if only and name not in only:
            continue
        K.reset()
        build()
        export("uniq_" + name, ROOT + "/assets/kaykit/weapons/uniq_%s.gltf" % name)
