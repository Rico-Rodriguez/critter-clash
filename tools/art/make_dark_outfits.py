"""The shop's outfits for the dark heroes: what each adds over the worn gear
(a cape, a fur mantle, a cowl, a scarf), as skinned models on the hero
skeleton, so it moves with the hero like the rest of the kit. An outfit's
helm is one of its hero's dark helms (DB.OUTFITS), and the outfit's dye goes
over the whole look.

    python3 tools/art/make_dark_outfits.py [outfit ...]   (plain Python + numpy)

Writes assets/kaykit/characters/DarkOutfit_<outfit>.glb, mesh "<file>_Mesh".
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_hero_body as H  # noqa: E402
import make_dark_knight as K  # noqa: E402
import make_dark_heroes as D  # noqa: E402
from dark_kit import IMAGE, sheet, shell, jagged  # noqa: E402


def cowl(m, sw, edge, b=1.0):
    cy = [(1.64, 0.33, 0.24, 0.07, 0.16), (1.72, 0.3, 0.22, 0.07, 0.1), (1.79, 0.22, 0.175, 0.06, 0.05)]
    shell(m, [(0, y, 0) for y, *_ in cy], [(rx * b, rz * b) for _, rx, rz, _, _ in cy], -150, 150, sw, ["chest"], n=18, th=0.02, edge=edge,
          fold=[c[3] for c in cy], dip=[c[4] for c in cy])


def scarf(m, sw, hem, length=0.7, seed=4):
    """A scarf wound at the neck, its tail down the back over one shoulder."""
    D.tube(m, [(0, 1.74, 0), (0, 1.84, 0)], [(0.18, 0.15), (0.14, 0.125)], sw, ["chest"], n=12, fold=0.08, folds=5, caps=(False, False))
    R = 7
    jag = jagged(3, 0.07, seed)
    rows = []
    for r in range(R):
        t = r / (R - 1)
        c = np.array([-0.12 - 0.05 * t, 1.78 - t * length, -0.18 - 0.08 * t])
        last = r == R - 1
        rows.append([c + [0.07, -(jag[2] if last else 0), 0], c + [0, -(jag[1] if last else 0), -0.01], c + [-0.07, -(jag[0] if last else 0), 0]])
    sheet(m, rows, sw, ["chest", "spine"], edge=hem)


def cape(m, sw, hem, torn, seed, long=True):
    """The set capes' shape (make_dark_knight.cape), hung a little wider and
    further back, so it falls over a cape the worn chest already has."""
    R, C = 10, 15
    jag = jagged(C, torn, seed)
    bottom = 0.18 if long else 0.32
    rows = []
    for r in range(R):
        t = r / (R - 1)
        y = 1.76 - t * (1.76 - bottom)
        w = 0.3 + 0.18 * t
        zc = -0.2 - 0.18 * t
        row = []
        for c in range(C):
            u = -1 + 2 * c / (C - 1)
            a = u * math.radians(72)
            z = zc - 0.08 * math.cos(a) * (1 - 0.3 * t) + (0.012 + 0.05 * t) * math.sin(c * math.pi * 0.5)
            row.append((-w * math.sin(a), y - (jag[c] if r == R - 1 else 0.0), z))
        rows.append(row)
    sheet(m, rows, sw, ["chest", "spine", "hips"], th=0.016, edge=hem)


# What each outfit adds; its colors come mostly from the dye, so the cloth is
# the lighter of our swatches, where a dye shows.
OUTFITS = {
    "crimson": lambda m: (cape(m, "white", "silver", 0.14, 61), cowl(m, "white", "silver")),
    "gilded": lambda m: (cape(m, "pale", "agold", 0.03, 62), cowl(m, "pale", "agold")),
    "frostwood": lambda m: (cape(m, "white", "fur", 0.12, 63), D.fur(m, "pale", lo=1.6)),
    "emberstalker": lambda m: (cape(m, "white", "blood", 0.22, 64), scarf(m, "white", "blood", 0.6)),
    "ashen": lambda m: (cape(m, "white", "cloth", 0.2, 65), cowl(m, "white", "cloth")),
    "sunfire": lambda m: (cape(m, "pale", "agold", 0.04, 66), cowl(m, "pale", "agold")),
    "bloodmoon": lambda m: (cape(m, "fur", "blood", 0.24, 67), D.fur(m, "fur", b=D.BB * 1.08)),
    "glacier": lambda m: (cape(m, "white", "silver", 0.1, 68), D.fur(m, "pale", b=D.BB * 1.08)),
    "midnight": lambda m: (cape(m, "white", "cloth", 0.18, 69, long=True), scarf(m, "white", "cloth", 0.8)),
    "viper": lambda m: (cape(m, "white", "moss", 0.26, 70, long=False), scarf(m, "white", "moss", 0.9, seed=8)),
    "embergilt": lambda m: cape(m, "pale", "agold", 0.05, 71),
    "moonsilk": lambda m: cape(m, "white", "silver", 0.05, 72),
    "verdigris": lambda m: cape(m, "pale", "moss", 0.05, 73),
}


if __name__ == "__main__":
    g, nodes, joints, _ = H.skeleton()
    only = sys.argv[1:]
    for key, build in OUTFITS.items():
        if only and key not in only:
            continue
        m = H.Mesh()
        build(m)
        nm = "DarkOutfit_" + key
        H.write(None, D.SK, g, nodes, joints, nm, K.out(nm), meshes=[(nm + "_Mesh", m)], image=IMAGE)
