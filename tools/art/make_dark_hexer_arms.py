"""The Hexer Queen's staff, in the dark palette and her violet.

    tools/art/blender.sh tools/art/make_dark_hexer_arms.py   (Blender's Python)

Writes assets/kaykit/weapons/boss_hexer_staff.gltf: sits as the other
weapons do (melee along +y, the grip at the origin), but about 2.2 tall, for a
boss's hand: a black shaft wound in wine, a crescent of black horns holding a
violet orb, a bone skull at the throat.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kk_mesh as K  # noqa: E402
from kk_mesh import ROOT, lathe, gem, box, spike, mark, place, export  # noqa: E402
from make_barbarian_armor import tube  # noqa: E402

K.DARK = True


def orb(c, r, sw, sides=8):
    lathe([(c - r, 0.0), (c - r * 0.6, r * 0.8), (c, r), (c + r * 0.6, r * 0.8), (c + r, 0.0)], sw, sides=sides)


def staff():
    top = 1.6
    lathe([(-0.55, 0.03), (-0.5, 0.045), (0.5, 0.05), (top, 0.04)], "black", sides=6, shade=lambda y: 0.75 - 0.4 * (y + 0.5) / 2.1)
    lathe([(-0.15, 0.062), (0.2, 0.062)], "wine", sides=6)
    for y in (-0.15, 0.2):
        lathe([(y - 0.015, 0.07), (y + 0.015, 0.07)], "agold", sides=6)
    # A spiked butt cap.
    spike((0, -0.52, 0), 0.045, (0, -0.72, 0), "agold", sides=4)
    lathe([(0.9, 0.056), (0.93, 0.07), (0.96, 0.056)], "agold", sides=6)
    # The throat: a gold socket and a small bone skull.
    lathe([(top - 0.12, 0.05), (top - 0.1, 0.075), (top + 0.04, 0.07), (top + 0.06, 0.05)], "agold", sides=6)
    c = top - 0.2
    orb(c, 0.065, "bone", sides=7)
    box((0, c - 0.055, 0.022), (0.07, 0.04, 0.05), "bone")
    for s in (-1, 1):
        gem((s * 0.025, c + 0.01, 0.055), 0.016, 0.018, 0.008, sw="violet")
    # A crescent of two horns cradles the orb.
    oc = top + 0.32
    for s in (-1, 1):
        horn = [(s * 0.02, top + 0.04, 0), (s * 0.2, top + 0.1, 0), (s * 0.3, top + 0.3, 0), (s * 0.22, top + 0.52, 0), (s * 0.07, top + 0.66, 0)]
        tube(horn, [0.05, 0.045, 0.04, 0.03, 0.0], "black", sides=6)
        for k, (hx, hy) in enumerate(((0.27, 0.2), (0.3, 0.36))):
            spike((s * hx, top + hy, 0), 0.022, (s * (hx + 0.1), top + hy + 0.05, 0), "agold", sides=3)
    orb(oc, 0.15, "violet", sides=8)
    # Rings of gold about the orb, and shards of violet standing off it.
    m = mark()
    lathe([(-0.012, 0.19), (0.012, 0.19)], "agold", sides=8)
    place(m, rot=(70, 0, 0), at=(0, oc, 0))
    for i in range(5):
        a = i * 2 * math.pi / 5 + 0.3
        ca, sa = math.cos(a), math.sin(a)
        spike((ca * 0.17, oc + 0.02 * sa, sa * 0.17), 0.03, (ca * 0.3, oc + 0.12 * (1 if i % 2 else -1), sa * 0.3), "violet", sides=4)
    spike((0, oc + 0.15, 0), 0.04, (0, oc + 0.42, 0), "violet", sides=4)
    # Built at hero size for the hand it is held in, then drawn in a little.
    place(0, scale=0.78)


if __name__ == "__main__":
    K.reset()
    staff()
    export("boss_hexer_staff", ROOT + "/assets/kaykit/weapons/boss_hexer_staff.gltf")
