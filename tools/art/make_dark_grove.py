"""The Hollow Grove's cult and its Mother in the dark plate style, on the hero
skeleton so the baked clips (Idle_A, Running_A, Melee_*, Ranged_*, Spawn_Ground,
Death_A, Hit_A, Skeletons_*) play on them unchanged.

    python3 tools/art/make_dark_grove.py [name ...]   (plain Python + numpy)

Writes into assets/kaykit/characters/ (one model each, a few meshes):
- GroveCutthroat.glb: lean and hooded, a long rust scarf, thorn knives on a
  bandolier. The fast stabber.
- GroveSlinger.glb: a wide leather hat, a moss mantle, a quiver of bolts. The
  crossbow archer.
- GroveShaman.glb: a long green robe, an orange leaf mantle, a hood crowned
  with big antlers, green eyes. The caster.
- GroveBrawler.glb: the Barbarian's bulk in iron and bark, antlers, thorn
  pauldrons. The heavy.
- Thornmother.glb: a huge hooded root-mother in bark and verdant, a halo of
  thorns, a skirt of roots. The boss.

Same vocabulary as the dark heroes (make_dark_heroes.py): hoods, masks, studs,
iron trim; the Grove's own colours come from the bark, verdant, moss and rust
swatches of weapons/dark_texture.png.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_hero_body as H  # noqa: E402
import make_dark_knight as K  # noqa: E402
import make_dark_heroes as D  # noqa: E402
from dark_kit import IMAGE, UP, tube, shell, band, stud, star, sheet, jagged  # noqa: E402

J, HC, SK = K.J, K.HC, K.SK
HB = D.HB
TORSO = D.TORSO


def eyes(m, col="verdant", y=0.17, spread=0.05, z=0.125, size=0.02):
    """Two small glowing eyes deep in a hood."""
    for s in (1, -1):
        stud(m, HC + [spread * s, y, z], (0, 0, 1), size, 0.012, col, HB, sides=4)


def scarf(m, sw, hem, drop=0.8, seed=5, b=1.0):
    """A neck wrap with a long tail down the back over one shoulder."""
    tube(m, [(0, 1.74, 0), (0, 1.84, 0)], [(0.17 * b, 0.14 * b), (0.13 * b, 0.115 * b)], sw, ["chest"], n=12, fold=0.08, folds=5, caps=(False, False))
    R = 8
    jag = jagged(3, 0.08, seed)
    rows = []
    for r in range(R):
        t = r / (R - 1)
        c = np.array([-0.12 - 0.04 * t, 1.78 - t * drop, -0.17 * b - 0.09 * t])
        rows.append([c + [-0.07, -(jag[0] if r == R - 1 else 0), 0], c + [0, -(jag[1] if r == R - 1 else 0), -0.01], c + [0.07, -(jag[2] if r == R - 1 else 0), 0]])
    sheet(m, [row[::-1] for row in rows], sw, ["chest", "spine"], edge=hem)


def thorn_row(m, pts, sw, bones, tall=0.08, r=0.02):
    """A row of thorns standing out of a polyline of (point, normal)."""
    for p, n in pts:
        stud(m, p, n, r, tall, sw, bones, sides=4)


def leaves(m, sw, edge, y=1.66, rx=0.34, rz=0.24, n=10, bones=("chest",)):
    """A mantle of overlapping leaf scales round the shoulders."""
    for k in range(n):
        a = math.radians(k * 360 / n + 18)
        for row, (dy, grow) in enumerate(((0.0, 1.0), (-0.1, 0.95))):
            c = np.array([rx * grow * math.sin(a), y + dy, rz * grow * math.cos(a)])
            nrm = np.array([math.sin(a), 0.5, math.cos(a)])
            stud(m, c, nrm, 0.055, 0.1, sw if (k + row) % 2 else edge, list(bones), sides=4)


def swap_pal(k, **kw):
    """Context for borrowing a hero set's builder with the Grove's colours."""
    class Ctx:
        def __enter__(self):
            self.old = dict(D.PAL[k])
            D.PAL[k].update(kw)

        def __exit__(self, *a):
            D.PAL[k].clear()
            D.PAL[k].update(self.old)
    return Ctx()


# --- The Cutthroat --------------------------------------------------------------------

def cutthroat():
    b = 0.9
    head = lambda m: (D.hood(m, "moss", edge="ember", peak=0.14, b=b, fold=0.07), D.mask(m, "black", edge="rust", high=0.16),
                      D.antlers(m, "bark", "bone", size=0.5, y=0.34), eyes(m, "rust", size=0.017))
    p = D.undersuit("moss", "hide", "cloth", head, "black", "hide", b=b)
    g = H.Mesh()
    p["Body"], p["Gear"] = p["Body"], g
    # A bandolier of thorn knives and a rust scarf trailing behind.
    D.strap(g, "black", b, 0.2, -0.2, w=0.04)
    for t in np.linspace(0.22, 0.75, 4):
        p0 = D.on_front(0.2 - 0.4 * t, 1.76 - 0.68 * t, b, 0.035)
        tube(g, [p0 + [0, 0.05, 0], p0 + [0, -0.05, 0]], [(0.014, 0.005), (0.0, 0.0)], "bone", TORSO, fwd=(0, 0, 1), n=4)
    scarf(g, "ember", "rust", drop=0.9, seed=11, b=b)
    D.belt(g, "black", "rust", b=b)
    D.flaps(g, "moss", "ember", (-35, 35, 150, 210), length=0.4, w=0.085, b=b, torn=0.1, seed=13)
    for s, side in ((1, "l"), (-1, "r")):
        D.paul(g, s, side, "hide", "moss", "ember", g=0.75, spikes=0)
        D.bracer(g, s, side, "hide", "rust", spikes=3 if s > 0 else 0, flare=0.004)
    D.knees(g, "hide", "rust")
    for side in ("l", "r"):
        ul, ll = J("upperleg." + side), J("lowerleg." + side)
        for t in (0.4, 0.6):
            band(g, ul + (ll - ul) * t, UP, (0, 0, 1), 0.106, 0.11, 0.025, "rust", ["upperleg." + side], n=10)
    tube(g, [(0.22, 1.0, 0.05), (0.26, 0.74, 0.07)], [(0.025, 0.012), (0.018, 0.01)], "bone", ["hips", "upperleg.l"], fwd=(0, 0, 1), n=4)
    return p


# --- The Slinger ---------------------------------------------------------------------

def slinger():
    b = 0.96

    def head(m):
        D.coif(m, "hide")
        D.mask(m, "cloth", edge="moss", high=0.15)
        D.hat(m, "hide", "ember", brim=0.34, tall=0.22, bend=0.16, y0=0.27)
        eyes(m, "rust", y=0.15, size=0.016)
    p = D.undersuit("hide", "cloth", "cloth", head, "hide", "hide", b=b)
    g = H.Mesh()
    p["Gear"] = g
    # A moss mantle with leaf scales, a studded jerkin, a quiver on the back.
    D.fur(g, "moss", b=b * 1.02, lo=1.6)
    leaves(g, "ember", "moss", y=1.7, rx=0.33 * b, rz=0.23 * b, n=10)
    D.studs(g, "rust", b, (-0.17, -0.09, 0.09, 0.17), (1.22, 1.32, 1.42, 1.52))
    D.strap(g, "black", b, 0.24, -0.2, w=0.045)
    tube(g, [(0.1, 1.2, -0.2), (0.0, 1.62, -0.27), (-0.04, 1.86, -0.3)], [(0.09, 0.075), (0.085, 0.07), (0.075, 0.06)], "bark", ["chest", "spine"], fwd=(0, 0, 1), n=8)
    band(g, (0.1, 1.2, -0.2), (-0.1, 0.42, -0.07), (0, 0, 1), 0.09, 0.075, 0.03, "iron", ["spine"], n=8)
    for i, (x, dz) in enumerate(((-0.05, 0.0), (0.03, -0.03), (-0.01, 0.04), (0.06, 0.03))):
        stud(g, np.array([-0.04 + x, 1.9, -0.3 + dz]), (x * 3, 1, dz * 3), 0.014, 0.12 + 0.02 * i, "bone", ["chest"], sides=3)
    D.belt(g, "hide", "rust", b=b, pouch="hide")
    D.flaps(g, "moss", "rust", (-30, 30, 150, 210), length=0.34, w=0.085, b=b, torn=0.1, seed=19)
    for s, side in ((1, "l"), (-1, "r")):
        D.paul(g, s, side, "hide", "hide", "rust", g=0.8)
        D.bracer(g, s, side, "hide", "moss", spikes=0)
    D.knees(g, "hide", "rust")
    for side in ("l", "r"):
        ll, ft = J("lowerleg." + side), J("foot." + side)
        tube(g, [ft + (ll - ft) * 0.5, ft + (ll - ft) * 0.64], [(0.108, 0.11), (0.098, 0.1)], "moss", ["lowerleg." + side], n=10, fold=0.1, folds=7, caps=(False, False))
    return p


# --- The Shaman ----------------------------------------------------------------------

def shaman():
    b = 1.0

    def head(m):
        D.hood(m, "moss", edge="ember", peak=0.2, b=1.1, fold=0.07, deep=1.06)
        D.mask(m, "black", edge="verdant", high=0.17)
        D.antlers(m, "bark", "bone", size=1.5, y=0.36)
        eyes(m, "verdant", y=0.18, spread=0.055, size=0.026)
    p = D.undersuit("moss", "moss", "moss", head, "hide", "hide", b=b)
    g = H.Mesh()
    p["Gear"] = g
    # A robe from the belt to the ground, an orange leaf mantle, bell sleeves.
    D.skirt(g, "moss", "ember", b=1.0, bottom=0.07, flare=0.17, torn=0.1, seed=23, y0=1.1, slit=True)
    for s, side in ((1, "l"), (-1, "r")):
        D.sleeve(g, s, side, "moss", bell=0.07, hem="rust")
    D.fur(g, "ember", b=1.08, lo=1.58)
    leaves(g, "ember", "rust", y=1.7, rx=0.36, rz=0.26, n=12)
    leaves(g, "moss", "ember", y=1.6, rx=0.38, rz=0.28, n=12)
    D.belt(g, "hide", "verdant", b=1.0)
    star(g, D.on_front(0, 1.5, b, 0.04), (0, 0, 1), UP, 0.06, "verdant", ["chest"], pts=6, th=0.016)
    # Charms hung from the belt: seeds on cords.
    for x in (-0.16, 0.0, 0.16):
        tube(g, [(x, 1.07, 0.19), (x, 0.84 - 0.04 * abs(x) * 5, 0.2)], [(0.008, 0.004), (0.01, 0.01)], "bone", ["hips"], fwd=(0, 0, 1), n=4)
        stud(g, np.array([x, 0.84 - 0.04 * abs(x) * 5, 0.2]), (0, -1, 0), 0.03, 0.05, "verdant", ["hips"], sides=4)
    for side in ("l", "r"):
        ll, ft = J("lowerleg." + side), J("foot." + side)
        K.shoe(g, ft, side, "hide", "hide")
    return p


# --- The Brawler ----------------------------------------------------------------------

def brawler():
    b = D.BB * 1.04
    p = D.barb_under()
    # Rebuild it a touch broader than the hero Barbarian, in the Grove's colours.
    p = D.undersuit("hide", "hide", "hide", lambda m: D.coif(m, "hide"), "hide", "hide", b=b)
    g = H.Mesh()
    p["Gear"] = g
    with swap_pal(2, main="hide", dark="hide", trim="rust", metal="iron", cloth="moss", hem="rust", gem="verdant"):
        chest = D.barb_chest(2)
        legs = D.barb_legs(2)
    p["Chest"], p["Legs"] = chest, legs
    # An iron cap with a nasal, bark-brown antlers growing from it.
    D.coif(g, "hide")
    cap = [(0.24, 0.15, 0.16), (0.32, 0.148, 0.158), (0.38, 0.12, 0.13), (0.43, 0.07, 0.075), (0.455, 0.02, 0.02)]
    tube(g, [HC + [0, y, 0] for y, *_ in cap], [(rx, rz) for _, rx, rz in cap], "iron", HB, n=14)
    band(g, HC + [0, 0.25, 0], UP, (0, 0, 1), 0.152, 0.162, 0.03, "ember", HB, n=14)
    tube(g, [HC + [0, 0.27, 0.16], HC + [0, 0.12, 0.175]], [(0.02, 0.01), (0.016, 0.01)], "iron", HB, fwd=(0, 0, 1), n=4)
    D.mask(g, "black", edge="rust", high=0.13)
    D.antlers(g, "bark", "bone", size=1.15, y=0.3)
    eyes(g, "rust", y=0.15, spread=0.05, size=0.018)
    # Thorns up the big shoulder and on the back, bark plates on the belly.
    for s, side in ((1, "l"), (-1, "r")):
        ua = J("upperarm." + side)
        for i in range(3):
            zz = (i - 1) * 0.09
            stud(g, ua + [s * 0.08, 0.2 - abs(zz) * 0.3, zz], (s * 0.3, 1, zz * 2), 0.03, 0.15 + 0.05 * (i == 1), "bone", ["upperarm." + side], sides=5)
    for k in range(5):
        a = (k - 2) * 0.28
        stud(g, np.array([0.17 * math.sin(a) * 1.4, 1.5 + 0.06 * abs(k - 2), -0.2]), (math.sin(a), 0.4, -1), 0.026, 0.14, "bone", ["chest"], sides=4)
    for y in (1.18, 1.3):
        shell(g, [(0, y, 0), (0, y + 0.1, 0)], [(0.29 * b, 0.19 * b), (0.285 * b, 0.188 * b)], -50, 50, "bark", ["spine"], n=10, edge="rust", front=1.1)
    return p


# --- The Thornmother ------------------------------------------------------------------

def thornmother():
    b = 1.12

    def head(m):
        D.hood(m, "bark", edge="verdant", peak=0.26, b=b, fold=0.08, deep=1.1)
        D.mask(m, "black", edge="verdant", high=0.18)
        D.antlers(m, "bark", "bone", size=2.4, y=0.38)
        D.antlers(m, "moss", "verdant", size=1.5, y=0.3)
        D.crown(m, "bark", y=0.36, r=1.2, tall=0.17, n=9)
        eyes(m, "verdant", y=0.19, spread=0.06, size=0.04)
    p = D.undersuit("bark", "bark", "bark", head, "hide", "hide", b=b)
    g = H.Mesh()
    p["Gear"] = g
    # The mantle: layered bark pauldrons crowned with thorns, leaf scales.
    D.fur(g, "moss", b=b * 1.1, lo=1.58)
    leaves(g, "verdant", "moss", y=1.72, rx=0.4, rz=0.28, n=14)
    leaves(g, "ember", "bark", y=1.6, rx=0.43, rz=0.31, n=14)
    for s, side in ((1, "l"), (-1, "r")):
        D.paul(g, s, side, "layered", "bark", "verdant", g=1.35, spikes=5)
        D.sleeve(g, s, side, "bark", bell=0.12, hem="verdant")
        D.bracer(g, s, side, "iron", "verdant", spikes=3, flare=0.02)
    # A breastplate of bark with the seed-heart glowing in it.
    shell(g, [(0, 1.42, 0), (0, 1.58, 0), (0, 1.72, 0)], [(0.31 * b, 0.2 * b), (0.32 * b, 0.204 * b), (0.285 * b, 0.185 * b)], -68, 68, "iron", ["chest"], n=12,
          edge="verdant", front=1.12, point=0.03)
    star(g, D.on_front(0, 1.56, b, 0.06), (0, 0.1, 1), UP, 0.1, "verdant", ["chest"], pts=6, th=0.02)
    star(g, D.on_front(0, 1.56, b, 0.07), (0, 0.1, 1), UP, 0.05, "white", ["chest"], pts=6, th=0.02)
    # A halo of thorns standing behind the shoulders.
    for k in range(11):
        a = math.radians(-100 + k * 20)
        r = 0.34
        stud(g, np.array([r * math.sin(a), 1.85 + 0.14 * math.cos(a * 1.4), -0.26]), (math.sin(a) * 0.8, 0.5 + 0.5 * math.cos(a), -0.9), 0.03, 0.34 - 0.1 * abs(math.sin(a)),
             "bone" if k % 2 else "bark", ["chest"], sides=4)
    D.belt(g, "hide", "verdant", b=b)
    # The robe: two skirts, the inner one rotten green, the outer bark with torn
    # hems, and roots creeping out over the ground.
    D.skirt(g, "moss", "rust", b=b * 1.0, bottom=0.1, flare=0.32, torn=0.15, seed=31, y0=1.1, slit=True)
    D.skirt(g, "bark", "verdant", b=b * 1.06, bottom=0.28, flare=0.3, torn=0.18, seed=37, y0=1.12)
    for k in range(9):
        a = math.radians(k * 40 + 10)
        ca, sa = math.cos(a), math.sin(a)
        r0 = 0.46 * b
        pts = [(r0 * sa, 0.3, r0 * ca * 0.8), ((r0 + 0.2) * sa, 0.08, (r0 + 0.2) * ca * 0.8), ((r0 + 0.5) * sa + 0.05 * ca, 0.03, (r0 + 0.5) * ca * 0.8 - 0.05 * sa),
               ((r0 + 0.75) * sa, 0.02, (r0 + 0.75) * ca * 0.8)]
        tube(g, pts, [(0.06, 0.05), (0.05, 0.04), (0.03, 0.025), (0.0, 0.0)], "bark", ["hips"], fwd=UP, n=6, caps=(True, False))
        stud(g, np.array(pts[1]) + [0, 0.03, 0], (sa, 1.2, ca), 0.02, 0.1, "bone", ["hips"], sides=3)
    for side in ("l", "r"):
        ll, ft = J("lowerleg." + side), J("foot." + side)
        K.shoe(g, ft, side, "bark", "bark")
    return p


MODELS = {"GroveCutthroat": cutthroat, "GroveSlinger": slinger, "GroveShaman": shaman, "GroveBrawler": brawler, "Thornmother": thornmother}


if __name__ == "__main__":
    g, nodes, joints, _ = H.skeleton()
    names = sys.argv[1:] or list(MODELS)
    for name in names:
        parts = MODELS[name]()
        H.write(None, K.SK, g, nodes, joints, name, K.out(name), meshes=[(name + "_" + n, mm) for n, mm in parts.items()], image=IMAGE)
        print("WROTE", name)
