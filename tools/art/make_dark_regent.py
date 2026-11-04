"""The Rime Regent of the Frozen Crypt in the dark plate style, on the hero
skeleton, so the baked clips (Skeletons_*, Melee_2H_*, Idle_A...) play on him
unchanged.

    python3 tools/art/make_dark_regent.py   (plain Python + numpy)

Writes assets/kaykit/characters/DarkBoss_rime.glb: a skeleton king in frost-blue
plate edged in silver (the Knight's Barrowsteel pieces recolored), a fur mantle
rimed white, shards of ice standing off his shoulders and back, and a rime
crown on the bare skull. His great axe and shield are built apart
(make_dark_regent_arms.py).
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_hero_body as H  # noqa: E402
import make_dark_knight as K  # noqa: E402
import dark_bones as B  # noqa: E402
from dark_kit import IMAGE, UP, tube, band, stud, star  # noqa: E402

J, HC = K.J, K.HC
HB = ["head"]


def knight(build, k, **over):
    """A Knight stage `k`, built with its set's materials changed."""
    keep = K.SETS[k]
    K.SETS[k] = dict(keep, **over)
    try:
        return build(k)
    finally:
        K.SETS[k] = keep


# Barrowsteel's pieces in dark rimed iron edged in ice-blue, so he stands out against the bright frost.
ICE = dict(plate="iron", trim="frost", mail="steel_dark", cloth="iron", hem="frost", gold="silver", cowl=False, cape="iron", tabard="iron", emblem="star", spikes=False)


def shards(m, at, dirs, bones, sw="frost", r=0.04):
    """Crystals of ice standing off a point: (direction, length) each."""
    for d, ln in dirs:
        stud(m, at, d, r * (0.6 + 0.4 * ln / 0.4), ln, sw, bones, sides=5)


def mantle(m):
    """A thick mantle of rimed fur round the shoulders, and ice standing off both."""
    cy = [(1.62, 0.34, 0.24, 0.06), (1.7, 0.31, 0.22, 0.07), (1.78, 0.22, 0.17, 0.05), (1.84, 0.14, 0.13, 0.03)]
    tube(m, [(0, y, 0) for y, *_ in cy], [(rx, rz) for _, rx, rz, _ in cy], "white", ["chest", "head"], n=18, fold=[c[3] for c in cy], folds=9, caps=(False, False))
    for s, side in ((1, "l"), (-1, "r")):
        ua = J("upperarm." + side)
        ub = ["upperarm." + side]
        # Three tall crystals on each shoulder, leaning out.
        shards(m, ua + [s * 0.02, 0.2, 0.0], [((s * 0.5, 1, 0.1), 0.42), ((s * 0.2, 1, -0.2), 0.34), ((s * 1.0, 0.8, 0.0), 0.26)], ub, "frost", 0.05)
        shards(m, ua + [s * 0.1, 0.18, 0.1], [((s * 0.4, 0.7, 1), 0.2)], ub, "white", 0.035)


def back_ice(m):
    """A fan of crystals rising behind the shoulders, a frozen halo."""
    C = ["chest"]
    for i, (x, ln, lean) in enumerate(((-0.24, 0.5, -0.5), (-0.12, 0.7, -0.2), (0.0, 0.85, 0.0), (0.12, 0.7, 0.2), (0.24, 0.5, 0.5), (-0.34, 0.32, -0.9), (0.34, 0.32, 0.9))):
        stud(m, (x, 1.66, -0.2), (lean, 1.0, -0.35), 0.06 if ln > 0.4 else 0.04, ln, "frost" if i % 2 == 0 else "white", C, sides=5)


def crown(m):
    c = HC + [0, 0.25, 0.0]
    band(m, c, UP, (0, 0, 1), 0.136, 0.146, 0.05, "silver", HB, n=12)
    band(m, c + [0, 0.03, 0], UP, (0, 0, 1), 0.139, 0.149, 0.012, "frost", HB, n=12)
    # A rime crown: spikes of ice, the tallest at the brow and the sides.
    for k in range(11):
        a = math.radians(-150 + k * 30)
        p = c + [0.14 * math.sin(a), 0.02, 0.15 * math.cos(a)]
        hgt = [0.2, 0.3, 0.2, 0.38, 0.2, 0.46, 0.2, 0.38, 0.2, 0.3, 0.2][k]
        stud(m, p, (math.sin(a) * 0.3, 1, math.cos(a) * 0.3), 0.03 if hgt > 0.25 else 0.024, hgt, "frost" if hgt > 0.25 else "white", HB, sides=4)
    star(m, c + [0, 0.0, 0.158], (0, 0.1, 1), UP, 0.04, "white", HB, pts=4, th=0.02)


def regent():
    m = H.Mesh()
    B.bones(m, ribs=False, trunk=False)
    head = len(m.parts)
    B.skull(m, bone="pale", eye="gold")
    crown(m)
    B.grow(m, head, HC + [0, -0.04, 0], 1.25)
    mantle(m)
    back_ice(m)
    return [("DarkBoss_rime_Body", m), ("DarkBoss_rime_Chest", knight(K.chest, 2, **ICE)), ("DarkBoss_rime_Legs", knight(K.legs, 2, **ICE))]


if __name__ == "__main__":
    g, nodes, joints, _ = H.skeleton()
    H.write(None, K.SK, g, nodes, joints, "DarkBoss_rime", K.out("DarkBoss_rime"), meshes=regent(), image=IMAGE)
    print("WROTE DarkBoss_rime")
