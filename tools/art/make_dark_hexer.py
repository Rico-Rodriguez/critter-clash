"""The Hexer Queen of the Sunken Crypt in the dark plate style, on the hero
skeleton, so the baked clips (Skeletons_*, Ranged_Magic_*, Idle_A...) play on
her unchanged.

    python3 tools/art/make_dark_hexer.py   (plain Python + numpy)

Writes assets/kaykit/characters/DarkBoss_hexer.glb: a skull-faced queen in a
trailing violet gown with black bodice and bell sleeves, a raised collar and a
spired crown with swept horns, a long veil behind. Her staff is built apart
(make_dark_boss_arms.py) and held in the right hand.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_hero_body as H  # noqa: E402
import make_dark_knight as K  # noqa: E402
import dark_bones as B  # noqa: E402
from dark_kit import IMAGE, UP, tube, shell, band, stud, star, sheet, jagged  # noqa: E402

J, HC = K.J, K.HC
LEGS = ["hips", "upperleg.l", "upperleg.r", "lowerleg.l", "lowerleg.r"]

# The gown's outline, hem to waist: (y, half-width, half-depth).
GOWN = [(0.03, 0.62, 0.55), (0.14, 0.58, 0.51), (0.34, 0.47, 0.41), (0.6, 0.37, 0.3), (0.85, 0.29, 0.22), (1.02, 0.245, 0.175)]


def gown_r(y):
    """The gown's radii at height y."""
    ys = [g[0] for g in GOWN]
    return np.interp(y, ys, [g[1] for g in GOWN]), np.interp(y, ys, [g[2] for g in GOWN])


def skirt(m):
    prof = GOWN[::-1]
    fold = [0.0, 0.025, 0.045, 0.06, 0.07, 0.08]
    tube(m, [(0, y, 0) for y, *_ in prof], [(rx, rz) for _, rx, rz in prof], "violet", LEGS, n=20, fold=fold, folds=9, front=1.04, caps=(False, False))
    # A black underskirt shows at the hem, and a gold hem over it.
    tube(m, [(0, 0.03, 0), (0, 0.13, 0)], [(0.625, 0.555), (0.585, 0.515)], "black", LEGS, n=20, fold=0.08, folds=9, caps=(False, False))
    band(m, (0, 0.05, 0), UP, (0, 0, 1), 0.64, 0.57, 0.03, "agold", LEGS, n=20, fold=0.08, folds=9)
    # The front panel: black, edged in gold, with a violet star.
    R, C = 7, 6
    jag = jagged(C, 0.05, 4)
    rows = []
    for r in range(R):
        y = 1.04 - r * (1.04 - 0.1) / (R - 1)
        rx, rz = gown_r(y)
        w = 0.1 + 0.07 * r / (R - 1)
        row = []
        for c in range(C):
            x = -w + 2 * w * c / (C - 1)
            z = rz * math.sqrt(max(0.0, 1 - (x / rx) ** 2)) * 1.06 + 0.025
            row.append((x, y - (jag[c] if r == R - 1 else 0.0), z))
        rows.append(row)
    sheet(m, rows, "black", LEGS, edge="agold")
    star(m, (0, 0.78, gown_r(0.78)[1] * 1.06 + 0.04), (0, 0.1, 1), UP, 0.07, "violet", LEGS, pts=6, th=0.012)


def bodice(m):
    T = ["hips", "spine", "chest"]
    prof = [(0.98, 0.235, 0.17), (1.1, 0.205, 0.15), (1.25, 0.185, 0.14), (1.4, 0.2, 0.15), (1.55, 0.235, 0.165), (1.68, 0.255, 0.165), (1.76, 0.2, 0.14)]
    tube(m, [(0, y, 0) for y, *_ in prof], [(rx, rz) for _, rx, rz in prof], "black", T, n=16, front=[1.05, 1.1, 1.12, 1.12, 1.1, 1.06, 1.0], point=[0, 0.02, 0.03, 0.03, 0.02, 0.0, 0.0])
    # Corset ridges, a gold girdle, a violet stone at the breast.
    for y in (1.15, 1.25, 1.35):
        band(m, (0, y, 0), UP, (0, 0, 1), 0.2 - (abs(y - 1.25) * -0.1), 0.15, 0.012, "violet", T, n=16, front=1.12, a0=-70, a1=70, point=0.03)
    band(m, (0, 1.03, 0), UP, (0, 0, 1), 0.245, 0.18, 0.05, "agold", ["hips"], n=16, front=1.04)
    band(m, (0, 1.745, 0), UP, (0, 0, 1), 0.245, 0.17, 0.03, "agold", ["chest"], n=16, a0=-85, a1=85, front=1.02)
    star(m, (0, 1.45, 0.2), (0, 0.1, 1), UP, 0.075, "agold", ["chest"], pts=4, th=0.016)
    star(m, (0, 1.45, 0.212), (0, 0.1, 1), UP, 0.04, "violet", ["chest"], pts=4, th=0.016)
    # A gorget of bone-pale scale over the throat: the neck itself is bare.
    cy = [(1.7, 0.2, 0.15), (1.78, 0.15, 0.12), (1.86, 0.1, 0.095)]
    tube(m, [(0, y, 0) for y, *_ in cy], [(rx, rz) for _, rx, rz in cy], "black", ["chest", "head"], n=12, caps=(False, False))
    for s in (1, -1):
        # Shoulder plates, each with a swept gold spike.
        side = "l" if s > 0 else "r"
        ua = J("upperarm." + side)
        ax = np.array([s, 0, 0.0])
        shell(m, [ua - ax * 0.07 + [0, 0.07, 0], ua + ax * 0.06 + [0, 0.1, 0], ua + ax * 0.2 + [0, 0.02, 0]], [(0.12, 0.12), (0.14, 0.14), (0.11, 0.11)], -105, 105, "black", ["upperarm." + side],
              fwd=UP, n=10, edge="agold", th=0.02, inner="violet")
        stud(m, ua + ax * 0.04 + [0, 0.19, 0], (s * 0.35, 1, 0), 0.03, 0.2, "agold", ["upperarm." + side], sides=4)
        stud(m, ua + ax * 0.14 + [0, 0.12, 0], (s * 0.8, 1, 0), 0.022, 0.12, "agold", ["upperarm." + side], sides=4)


def sleeves(m):
    for s, side in ((1, "l"), (-1, "r")):
        ua, la, wr = J("upperarm." + side), J("lowerarm." + side), J("wrist." + side)
        ax = np.array([s, 0, 0.0])
        bn = ["upperarm." + side, "lowerarm." + side]
        # A long bell sleeve, tight at the shoulder, flared past the wrist.
        pts = [ua + ax * 0.04, la, la + (wr - la) * 0.6, wr + ax * 0.02, wr + ax * 0.13 - [0, 0.03, 0]]
        rad = [(0.09, 0.09), (0.085, 0.085), (0.095, 0.095), (0.14, 0.14), (0.215, 0.2)]
        tube(m, pts, rad, ["violet", "violet", "violet", "violet"], bn + ["wrist." + side], fwd=UP, n=12, fold=[0, 0, 0.03, 0.06, 0.1], folds=7, caps=(False, False))
        band(m, wr + ax * 0.125 - [0, 0.03, 0], ax, UP, 0.222, 0.208, 0.03, "agold", bn + ["wrist." + side], n=12, fold=0.1, folds=7)
        # A trailing streamer off the elbow, cut to points.
        R, C = 5, 5
        jag = jagged(C, 0.1, 21 + s)
        rows = []
        for r in range(R):
            t = r / (R - 1)
            row = []
            for c in range(C):
                u = -1 + 2 * c / (C - 1)
                x = la[0] + s * (0.05 + 0.5 * t)
                row.append((x, la[1] - 0.04 - 0.1 * t * t - (jag[c] * t if r == R - 1 else 0), la[2] + u * (0.11 - 0.03 * t) * (1 if s > 0 else -1) - 0.02))
            rows.append(row)
        sheet(m, rows, "violet", bn, edge="agold", back_sw="black")


def collar(m):
    """A tall collar fanned behind the skull, lined in violet, its edge spiked."""
    hp = [(-0.08, 0.15, 0.13), (0.06, 0.2, 0.17), (0.22, 0.27, 0.2), (0.4, 0.32, 0.23), (0.56, 0.32, 0.22)]
    shell(m, [HC + [0, y, -0.06 - 0.01 * i] for i, (y, *_) in enumerate(hp)], [(rx, rz) for _, rx, rz in hp], 105, 255, "black", ["head", "chest"], fwd=(0, 0, 1), n=12,
          edge="agold", th=0.02, inner="violet", fold=0.0)
    for i in range(7):
        a = math.radians(115 + i * 21.6)
        r = 0.32
        p = HC + [r * math.sin(a), 0.56, -0.06 - 0.05 + 0.22 * math.cos(a)]
        stud(m, p, (math.sin(a) * 0.4, 1, math.cos(a) * 0.4), 0.025, 0.14 if i % 2 == 0 else 0.08, "agold", ["head"], sides=4)


def crown(m):
    hb = ["head"]
    c = HC + [0, 0.28, 0.0]
    band(m, c, UP, (0, 0, 1), 0.137, 0.147, 0.045, "agold", hb, n=12)
    # Spires round the brow, the front one tallest, each rising off a violet stone.
    for k in range(7):
        a = math.radians(-90 + k * 30)
        p = c + [0.14 * math.sin(a), 0.02, 0.15 * math.cos(a)]
        hgt = 0.34 if k == 3 else (0.22 if k in (2, 4) else 0.14)
        stud(m, p, (math.sin(a) * 0.2, 1, math.cos(a) * 0.2), 0.026, hgt, "agold", hb, sides=4)
    stud(m, c + [0, 0.0, 0.158], (0, 0.15, 1), 0.026, 0.02, "violet", hb, sides=5)
    # Two long horns sweep out, back and up over the collar.
    for s in (1, -1):
        horn = [HC + [s * 0.12, 0.3, 0.0], HC + [s * 0.22, 0.36, -0.05], HC + [s * 0.3, 0.52, -0.1], HC + [s * 0.27, 0.72, -0.14], HC + [s * 0.14, 0.88, -0.14]]
        tube(m, horn, [0.045, 0.04, 0.03, 0.02, 0.0], ["black", "black", "black", "agold"], hb, fwd=(0, 0, 1), n=6, smooth=False, caps=(True, False))
        stud(m, HC + [s * 0.3, 0.52, -0.06], (s, 0.6, 0.3), 0.022, 0.1, "agold", hb, sides=4)


def veil(m):
    """The train: a long black veil lined in violet, torn to points at the floor."""
    R, C = 12, 15
    jag = jagged(C, 0.16, 31)
    rows = []
    for r in range(R):
        t = r / (R - 1)
        y = 1.72 - t * (1.72 - 0.06)
        w = 0.25 + 0.4 * t ** 1.3
        zc = -0.16 - 0.38 * t ** 1.5
        row = []
        for c in range(C):
            u = -1 + 2 * c / (C - 1)
            a = u * math.radians(75)
            z = zc - 0.1 * math.cos(a) * (1 - 0.3 * t) + (0.012 + 0.06 * t) * math.sin(c * math.pi * 0.5)
            row.append((-w * math.sin(a), y - (jag[c] if r == R - 1 else 0.0), z))
        rows.append(row)
    sheet(m, rows, "black", ["chest", "spine", "hips"], th=0.016, edge="agold", back_sw="violet")


def queen():
    m = H.Mesh()
    B.bones(m, ribs=False)
    head = len(m.parts)
    B.skull(m, bone="bone")
    collar(m)
    crown(m)
    # She is seen from far off: a larger head and crown than the hero's.
    B.grow(m, head, HC + [0, -0.04, 0], 1.28)
    skirt(m)
    bodice(m)
    sleeves(m)
    veil(m)
    return [("DarkBoss_hexer_Body", m)]


if __name__ == "__main__":
    g, nodes, joints, _ = H.skeleton()
    parts = queen()
    H.write(None, K.SK, g, nodes, joints, "DarkBoss_hexer", K.out("DarkBoss_hexer"), meshes=parts, image=IMAGE)
    print("WROTE DarkBoss_hexer")
