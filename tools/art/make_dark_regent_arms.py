"""The Rime Regent's great axe and shield, in the dark palette and frost blue.

    python3 tools/art/make_dark_regent_arms.py   (the `bpy` module: pip install bpy)

Writes assets/kaykit/weapons/boss_rime_axe.gltf and boss_rime_shield.gltf. They
sit as the other weapons do (melee along +y with the grip at the origin, the
shield facing +z about its middle) but larger, for a boss's hands.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kk_mesh as K  # noqa: E402
from kk_mesh import ROOT, lathe, gem, plate, box, spike, mark, place, export  # noqa: E402

K.DARK = True


def axe():
    """A great axe: a black haft wound in hide, one broad blade of frost
    steel with a white edge and a row of icicles along its back, a spike on
    the other side."""
    top = 1.5
    lathe([(-0.6, 0.035), (-0.55, 0.05), (0.5, 0.055), (top, 0.045)], "black", sides=6, shade=lambda y: 0.75 - 0.4 * (y + 0.6) / 2.1)
    lathe([(-0.2, 0.07), (0.25, 0.07)], "hide", sides=6)
    for y in (-0.2, 0.25, 0.75):
        lathe([(y - 0.015, 0.078), (y + 0.015, 0.078)], "silver", sides=6)
    spike((0, -0.57, 0), 0.05, (0, -0.8, 0), "frost", sides=4)
    # The socket the head sits in.
    lathe([(top - 0.38, 0.06), (top - 0.34, 0.085), (top + 0.12, 0.085), (top + 0.16, 0.06)], "silver", sides=6)
    # The blade: a broad bearded crescent, its curved edge ground sharp.
    c = top - 0.1
    pts = [(0.06, c - 0.3), (0.3, c - 0.34), (0.56, c - 0.5), (0.72, c - 0.14), (0.66, c + 0.22), (0.5, c + 0.46), (0.28, c + 0.4), (0.06, c + 0.3)]
    plate(pts, 0.03, "frost", [2, 3, 4], "white")
    # A darker inner plate and a rim of silver, so the face has depth.
    plate([(0.07 + (x - 0.06) * 0.62, c + (y - c) * 0.62) for x, y in pts], 0.04, "iron")
    gem((0.26, c, 0.04), 0.07, 0.09, 0.03, sw="white")
    gem((0.26, c, -0.04), 0.07, 0.09, 0.03, sw="white", facing=-1)
    # Icicles along the back of the blade, and the spike opposite.
    for y0, ln in ((0.08, 0.3), (-0.06, 0.22), (0.22, 0.2)):
        spike((-0.06, c + y0, 0.0), 0.05, (-0.06 - ln, c + y0 + 0.03, 0.0), "frost", sides=4)
    spike((0.06, c + 0.36, 0.0), 0.07, (0.05, c + 0.8, 0.0), "frost", sides=4)
    # Icicles hanging from the lower edge.
    for x, ln in ((0.22, 0.14), (0.38, 0.2), (0.54, 0.12)):
        spike((x, c - 0.34 - (x - 0.06) * 0.3, 0.0), 0.035, (x + 0.02, c - 0.34 - (x - 0.06) * 0.3 - ln, 0.0), "white", sides=3)


def shield():
    """A tall kite shield of frost steel, rimmed in silver, a great ice
    crystal for a boss and icicles hanging off its foot."""
    w, top, bot = 0.5, 0.62, -0.82
    pts = [(w, top), (-w, top), (-w, top - 0.16), (-w * 0.9, bot * 0.3), (-w * 0.55, bot * 0.74), (0, bot), (w * 0.55, bot * 0.74), (w * 0.9, bot * 0.3), (w, top - 0.16)]
    plate([(x * 1.07, y * 1.04 if y > 0 else y * 1.05) for x, y in pts], 0.03, "silver", t=(0.3, 0.6))
    plate(pts, 0.05, "frost", t=(0.25, 0.6))
    # An inset field and a ridge of ice down the middle.
    plate([(x * 0.74, y * 0.78) for x, y in pts], 0.062, "iron", t=(0.3, 0.6))
    plate([(-0.05, bot * 0.8), (0.05, bot * 0.8), (0.04, top * 0.8), (-0.04, top * 0.8)], 0.08, "white")
    # The crystal at the heart: a tall hexagonal point.
    gem((0, 0.06, 0.07), 0.2, 0.26, 0.2, sw="white")
    gem((0, 0.06, 0.2), 0.1, 0.14, 0.08, sw="frost")
    # Shards off the top corners and the foot.
    for x, y in ((-w, top), (w, top), (0, top)):
        spike((x * 0.95, y * 0.95, 0.0), 0.06, (x * 1.12, y * 1.05 + (0.28 if x == 0 else 0.2), 0.0), "frost", sides=4)
    for x, y, ln in ((-0.3, bot * 0.62, 0.22), (0.3, bot * 0.62, 0.22), (0, bot, 0.28), (-0.15, bot * 0.9, 0.16), (0.15, bot * 0.9, 0.16)):
        spike((x, y, 0.0), 0.04, (x, y - ln, 0.0), "white", sides=3)
    # The grip, on the back.
    box((0, -0.05, -0.1), (0.05, 0.32, 0.05), "black")
    box((0, 0.1, -0.075), (0.3, 0.05, 0.04), "hide")


ARMS = {"axe": axe, "shield": shield}

if __name__ == "__main__":
    only = sys.argv[1:]
    for name, build in ARMS.items():
        if only and name not in only:
            continue
        K.reset()
        build()
        export("boss_rime_" + name, ROOT + "/assets/kaykit/weapons/boss_rime_%s.gltf" % name)
