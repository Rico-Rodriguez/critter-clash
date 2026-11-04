"""The Grove Cult's weapons, in the dark palette and the Thorn's own colours
(bark, verdant, moss: dark_swatches.py).

    python tools/art/make_grove_arms.py [name ...]   (Blender's Python: pip install bpy)

Writes assets/kaykit/weapons/grove_<name>.gltf. Held pieces stand along +y with
the grip at the origin, as the other families do (make_hero_arms.py).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kk_mesh as K  # noqa: E402
from kk_mesh import ROOT, lathe, gem, plate, spike, mark, place, export  # noqa: E402
from make_barbarian_armor import tube  # noqa: E402

K.DARK = True


def knife():
    """The cutthroat's thorn knife: a hooked blade of bone-white thorn on a
    wrapped grip, a rusted guard."""
    lathe([(-0.2, 0.03), (-0.05, 0.034), (0.04, 0.03)], "bark", sides=6)
    lathe([(-0.16, 0.042), (-0.04, 0.042)], "hide", sides=6)
    lathe([(0.04, 0.05), (0.07, 0.05)], "rust", sides=6)
    tube([(0, 0.07, 0), (0.0, 0.2, 0.035), (0.0, 0.34, 0.1), (0.0, 0.42, 0.19)], [0.04, 0.036, 0.022, 0.0], "bone", sides=4)
    spike((0, -0.18, 0.0), 0.03, (0, -0.26, 0.0), "rust", sides=4)


def staff():
    """The shaman's staff: a branch, three thorn prongs round a green seed."""
    pts = [(0, -0.9, 0), (0.015, -0.4, 0), (-0.02, 0.2, 0), (0.0, 0.8, 0.0), (0.0, 1.05, 0.0)]
    tube(pts, [0.036, 0.04, 0.036, 0.036, 0.03], "bark", sides=6)
    lathe([(-0.12, 0.05), (0.2, 0.05)], "hide", sides=6)
    lathe([(0.75, 0.05), (0.9, 0.05)], "moss", sides=6)
    c = 1.2
    for i in range(3):
        a = i * 2 * math.pi / 3 + 0.5
        ca, sa = math.cos(a), math.sin(a)
        tube([(0, 1.02, 0), (ca * 0.13, c - 0.05, sa * 0.13), (ca * 0.05, c + 0.22, sa * 0.05)], [0.03, 0.022, 0.0], "bark", sides=4)
    gem((0, c, 0.0), 0.09, 0.12, 0.09, sw="verdant")
    gem((0, c, 0.0), 0.09, 0.12, 0.09, sw="verdant", facing=-1)
    for i in range(2):
        spike((0.03 * (1 - 2 * i), 0.4 + 0.25 * i, 0.03), 0.02, (0.11 * (1 - 2 * i), 0.46 + 0.25 * i, 0.07), "bone", sides=3)


def thorn_staff():
    """The Thornmother's staff: a long knotted root, thorns along it, a cage
    of root-fingers round a glowing seed-heart."""
    n = 9
    pts, rad = [], []
    for i in range(n):
        t = i / (n - 1)
        pts.append((0.05 * math.sin(t * 9), -1.2 + t * 2.7, 0.05 * math.cos(t * 7)))
        rad.append(0.05 + 0.014 * math.sin(t * 17))
    tube(pts, rad, "bark", sides=6)
    lathe([(-0.15, 0.065), (0.15, 0.065)], "hide", sides=6)
    for i in range(5):
        a = i * 2.4
        y = -0.55 + i * 0.4
        spike((math.cos(a) * 0.05, y, math.sin(a) * 0.05), 0.026, (math.cos(a) * 0.2, y + 0.14, math.sin(a) * 0.2), "bone", sides=3)
    for y in (0.5, 0.9):
        lathe([(y, 0.06), (y + 0.03, 0.085), (y + 0.06, 0.06)], "moss", sides=6)
    c = 1.78
    for i in range(5):
        a = i * 2 * math.pi / 5
        ca, sa = math.cos(a), math.sin(a)
        tube([(0, 1.45, 0), (ca * 0.2, c - 0.2, sa * 0.2), (ca * 0.27, c + 0.06, sa * 0.27), (ca * 0.1, c + 0.34, sa * 0.1)], [0.045, 0.034, 0.026, 0.0], "bark", sides=4)
        spike((ca * 0.24, c - 0.08, sa * 0.24), 0.02, (ca * 0.36, c - 0.04, sa * 0.36), "bone", sides=3)
    gem((0, c, 0.0), 0.16, 0.2, 0.16, sw="verdant")
    gem((0, c, 0.0), 0.16, 0.2, 0.16, sw="verdant", facing=-1)


ARMS = {"knife": knife, "staff": staff, "thorn_staff": thorn_staff}

if __name__ == "__main__":
    only = sys.argv[1:]
    for name, build in ARMS.items():
        if only and name not in only:
            continue
        K.reset()
        build()
        export("grove_" + name, ROOT + "/assets/kaykit/weapons/grove_%s.gltf" % name)
