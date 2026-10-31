"""The boss uniques' armour, each its own piece on the hero skeleton: a set
stage of its hero (make_dark_knight.py, make_dark_heroes.py) recolored in the
unique's own colors, with what makes it that unique built over it (a crown,
thorns, ice, coals, a shroud).

    python3 tools/art/make_dark_uniques.py [unique ...]   (plain Python + numpy)

Writes assets/kaykit/characters/DarkUnique_<unique>.glb, mesh "<file>_Mesh".
The colors are their own (dark_swatches.py), so no dye goes over them.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_hero_body as H  # noqa: E402
import make_dark_knight as K  # noqa: E402
import make_dark_heroes as D  # noqa: E402
import make_dark_outfits as O  # noqa: E402
from dark_kit import IMAGE, UP, tube, shell, band, stud, star  # noqa: E402

J, HC, HB = K.J, K.HC, D.HB


def recolor(m, swap):
    """Every face of `m` in a swatch named in `swap` takes the new one."""
    for i, (v, faces, uvs, smooth, bones) in enumerate(m.parts):
        m.parts[i] = (v, [(f[0], swap.get(f[1], f[1]), f[2]) for f in faces], uvs, smooth, bones)
    return m


def knight(build, k, **over):
    """A Knight stage `k`, built with its set's materials changed."""
    keep = K.SETS[k]
    K.SETS[k] = dict(keep, **over)
    try:
        return build(k)
    finally:
        K.SETS[k] = keep


def thorns(m, pts, sw, bones, h=0.07):
    """Short hooked spikes standing off a surface: (point, outward normal)."""
    for p, nrm in pts:
        stud(m, p, nrm, 0.016, h, sw, bones, sides=4)


def around(y, rx, rz, a0, a1, n, out=0.0):
    """Points round the torso at height y, with their outward normals."""
    res = []
    for i in range(n):
        a = math.radians(a0 + (a1 - a0) * (i + 0.5) / n)
        res.append((np.array([(rx + out) * math.sin(a), y, (rz + out) * math.cos(a)]), (math.sin(a), 0.25, math.cos(a))))
    return res


# --- The Knight's ---------------------------------------------------------------------

def crown():
    """Crown of the Barrow King: a black bascinet under a tall crown of gold
    points, a red stone at the brow."""
    m, _ = knight(K.helm, 1, trim="agold", mail="iron")
    band(m, HC + [0, 0.29, 0], UP, (0, 0, 1), 0.142, 0.157, 0.06, "agold", HB, n=16)
    band(m, HC + [0, 0.285, 0], UP, (0, 0, 1), 0.146, 0.161, 0.016, "black", HB, n=16)
    for i in range(10):
        a = math.radians(i * 36)
        p = HC + [0.14 * math.sin(a), 0.34, 0.155 * math.cos(a)]
        stud(m, p, (math.sin(a) * 0.25, 1, math.cos(a) * 0.25), 0.026, 0.17 if i % 2 == 0 else 0.09, "agold", HB, sides=4)
    star(m, HC + [0, 0.32, 0.166], (0, 0, 1), UP, 0.04, "red", HB, pts=4, th=0.02)
    for s in (1, -1):
        star(m, HC + [s * 0.1, 0.32, 0.125], (s * 0.7, 0, 0.7), UP, 0.022, "white", HB, pts=4, th=0.014)
    return m


def greaves():
    """Wraithstep Greaves: barrowsteel legs gone cold and pale, ghost rags
    hanging from the belt."""
    m = knight(K.legs, 2, trim="frost", hem="frost", tabard=None, gold="frost")
    D.flaps(m, "frost", "white", (-40, -10, 20, 50, 140, 180, 220), length=0.5, w=0.075, torn=0.12, seed=77)
    return m


def hoardplate():
    """Hoardplate: the Warden's gold, plate of it with black edges, spiked,
    a wine cape."""
    return knight(K.chest, 3, plate="agold", trim="black", mail="iron", gold="red", hem="agold", cape="wine")


def cinder_plate():
    """Pyreplate: black iron cracked through with coals, a scorched cape."""
    m = knight(K.chest, 3, trim="ember", gold="ember", hem="ember", cape="black", cloth="black")
    for p, nrm in around(1.52, 0.29, 0.19, -50, 50, 4, 0.0):
        stud(m, p, nrm, 0.02, 0.02, "ember", ["chest"], sides=4)
    return m


# --- The Ranger's -----------------------------------------------------------------------

def shroud():
    """Shroud of the Barrow: grave cloth, black and tattered, over a moss
    hood-mantle, bound with bone."""
    m = recolor(D.ranger_chest(2), {"moss": "black", "silver": "moss", "iron": "black", "hide": "black", "cloth": "black", "white": "bone"})
    O.cowl(m, "black", "moss", b=1.04)
    O.cape(m, "black", "moss", 0.32, 91)
    for s in (1, -1):
        stud(m, (s * 0.14, 1.7, 0.2), (s * 0.3, 0.2, 1), 0.03, 0.03, "bone", ["chest"], sides=5)
    return m


def rime_cowl():
    """Winter's Cowl: a white hood edged in ice, a frost mask, a crown of
    icicles."""
    m = H.Mesh()
    D.hood(m, "white", edge="frost", peak=0.08, fold=0.06)
    D.mask(m, "frost", edge="white")
    for i in range(9):
        a = math.radians(-80 + i * 20)
        p = HC + [0.16 * math.sin(a), 0.31, 0.17 * math.cos(a)]
        stud(m, p, (math.sin(a) * 0.35, 1, math.cos(a) * 0.35), 0.024, 0.16 if i % 2 == 0 else 0.09, "frost", HB, sides=4)
    return m


# --- The Mage's -----------------------------------------------------------------------

def gown():
    """Gown of Thorns: a violet robe, a black mantle bristling with bark
    thorns, the cape torn."""
    m = recolor(D.mage_chest(3), {"wine": "violet", "blood": "black", "iron": "black", "red": "verdant"})
    thorns(m, around(1.66, 0.3, 0.215, -150, 150, 12, 0.01) + around(1.76, 0.24, 0.18, -140, 140, 9, 0.01), "bark", ["chest"])
    for s, side in ((1, "l"), (-1, "r")):
        ua = J("upperarm." + side)
        thorns(m, [(ua + [s * 0.05, 0.16, z], (s * 0.3, 1, z * 3)) for z in (-0.06, 0.0, 0.06)], "bark", ["upperarm." + side], h=0.1)
    return m


def rime_robe():
    """Rimewoven Robes: white robes, a mantle of ice, icicles on the
    shoulders, fur at the throat."""
    m = recolor(D.mage_chest(2), {"cloth": "white", "iron": "frost", "silver": "white"})
    D.fur(m, "white", lo=1.72)
    for s, side in ((1, "l"), (-1, "r")):
        ua = J("upperarm." + side)
        for z in (-0.07, 0.0, 0.07):
            stud(m, ua + [s * 0.04, 0.17, z], (s * 0.2, 1, z * 2), 0.03, 0.15 if z == 0 else 0.1, "frost", ["upperarm." + side], sides=4)
    return m


# --- The Barbarian's -------------------------------------------------------------------

def barkplate():
    """Barkhide Plate: bark grown into plates, moss in the cracks and on the
    shoulders, thorns everywhere."""
    m = recolor(D.barb_chest(2), {"hide": "bark", "iron": "bark", "silver": "verdant", "fur": "moss"})
    thorns(m, around(1.3, 0.25 * D.BB, 0.165 * D.BB, -60, 60, 5, 0.01) + around(1.45, 0.25 * D.BB, 0.165 * D.BB, -50, 50, 4, 0.01), "bark", D.TORSO)
    return m


# --- The Rogue's ------------------------------------------------------------------------

def cinder_boots():
    """Emberstride Boots: black leathers, the boots and knees glowing with
    coals."""
    m = recolor(D.rogue_legs(3), {"hide": "black", "cloth": "black", "blood": "ember", "iron": "black"})
    for side in ("l", "r"):
        ll, ft = J("lowerleg." + side), J("foot." + side)
        for t in (0.2, 0.38):
            band(m, ft + (ll - ft) * t, UP, (0, 0, 1), 0.094, 0.098, 0.018, "ember", ["lowerleg." + side], n=10)
    return m


UNIQUES = {
    "crown": crown, "greaves": greaves, "hoardplate": hoardplate, "cinder_plate": cinder_plate,
    "shroud": shroud, "rime_cowl": rime_cowl, "gown": gown, "rime_robe": rime_robe,
    "barkplate": barkplate, "cinder_boots": cinder_boots,
}


if __name__ == "__main__":
    g, nodes, joints, _ = H.skeleton()
    only = sys.argv[1:]
    for key, build in UNIQUES.items():
        if only and key not in only:
            continue
        nm = "DarkUnique_" + key
        H.write(None, D.SK, g, nodes, joints, nm, K.out(nm), meshes=[(nm + "_Mesh", build())], image=IMAGE)
        print("WROTE", nm)
