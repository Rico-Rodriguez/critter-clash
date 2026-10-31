"""The Ranger, Mage, Barbarian and Rogue in the Knight's dark-fantasy style
(make_dark_knight.py): for each hero an undersuit and, per set, a helm, a
chest and legs, each its own skinned model on the hero skeleton.

    python3 tools/art/make_dark_heroes.py [hero ...] [set ...]   (plain Python + numpy)

Writes Dark<Hero>.glb (meshes Body, ArmLeft, LegLeft, Head) and
Dark<Hero>_{Helm,Chest,Legs}<k>.glb into assets/kaykit/characters/.

Every hero climbs the same ladder as the Knight, in its own trade:
Gravedigger (scavenged hide), Warden (plain dark kit, a wine accent),
Barrowsteel (iron edged in silver, a star), Bloodiron (blood-red edges,
spikes, a wine cape), Gravelight (pale steel, gold and white). No skin shows:
faces sit in the shadow of a hood, a mask or a helm.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_hero_body as H  # noqa: E402
import make_dark_knight as K  # noqa: E402
from dark_kit import IMAGE, UP, tube, shell, band, stud, star, sheet, jagged  # noqa: E402

J, HC, SK = K.J, K.HC, K.SK
HB = ["head"]
TORSO = ["hips", "spine", "chest"]
# The undersuit's torso: (y, half width, half depth).
PROF = [(0.88, 0.235, 0.16), (1.0, 0.25, 0.165), (1.15, 0.235, 0.155), (1.3, 0.245, 0.16), (1.45, 0.265, 0.17),
        (1.6, 0.275, 0.172), (1.72, 0.25, 0.155), (1.79, 0.16, 0.12), (1.83, 0.1, 0.095)]

# Five sets per hero: the palette, then what each piece is made of.
PAL = [
    {"main": "hide", "dark": "hide", "trim": "rust", "metal": "iron", "cloth": "cloth", "hem": "rust", "gem": "rust"},
    {"main": "hide", "dark": "cloth", "trim": "steel", "metal": "iron", "cloth": "wine", "hem": "wine", "gem": "steel"},
    {"main": "hide", "dark": "cloth", "trim": "silver", "metal": "iron", "cloth": "cloth", "hem": "silver", "gem": "white"},
    {"main": "hide", "dark": "cloth", "trim": "blood", "metal": "iron", "cloth": "wine", "hem": "blood", "gem": "red"},
    {"main": "pale", "dark": "white", "trim": "agold", "metal": "pale", "cloth": "white", "hem": "agold", "gem": "white"},
]


def prof(lo, hi, b=1.0, add=0.0):
    rows = [(y, rx * b + add, rz * b + add) for y, rx, rz in PROF if lo <= y <= hi]
    return [(0, y, 0) for y, _, _ in rows], [(rx, rz) for _, rx, rz in rows]


def surf(y, b=1.0):
    """Half width and depth of the torso at height y."""
    ys = [p[0] for p in PROF]
    return float(np.interp(y, ys, [p[1] for p in PROF])) * b, float(np.interp(y, ys, [p[2] for p in PROF])) * b


def on_front(x, y, b=1.0, out=0.02):
    rx, rz = surf(y, b)
    t = min(abs(x) / (rx + out), 0.98)
    return np.array([x, y, (rz + out) * math.sqrt(1 - t * t)])


# --- Pieces ------------------------------------------------------------------------

def hood(m, sw, edge=None, peak=0.06, b=1.0, drape=True, fold=0.05, deep=1.0):
    """A cloth hood drawn to a point at the back, the face in its shadow, and
    a capelet over the shoulders."""
    hp = [(-0.01, 0.13, 0.14), (0.08, 0.147, 0.157), (0.17, 0.155, 0.165), (0.26, 0.153, 0.163), (0.33, 0.135, 0.145),
          (0.39, 0.1, 0.11), (0.44, 0.05, 0.055), (0.475, 0.01, 0.01)]
    pts = [HC + [0, y, -peak * 1.6 * (max(y, 0.0) / 0.475) ** 2] for y, _, _ in hp]
    shell(m, pts, [(rx * deep, rz * deep) for _, rx, rz in hp], 42, 318, sw, HB, n=16, th=0.022, edge=edge or sw, inner="black",
          front=1.06, point=[0.0, 0.0, 0.02, 0.035, 0.02, 0.0, 0.0, 0.0])
    tube(m, [HC + [0, 0.06, 0.01], HC + [0, 0.17, 0.05], HC + [0, 0.28, 0.03]], [(0.1, 0.08), (0.11, 0.085), (0.095, 0.07)], "black", HB, n=10)
    if drape:
        tube(m, [HC + [0, 0.05, 0], HC + [0, -0.03, 0], HC + [0, -0.1, 0]], [(0.135, 0.145), (0.21 * b, 0.18 * b), (0.29 * b, 0.215 * b)], sw,
             HB + ["chest"], n=16, fold=[0.0, fold, fold], folds=7, caps=(False, False), dip=[0.0, 0.02, 0.05])
        if edge:
            band(m, HC + [0, -0.1, 0], UP, (0, 0, 1), 0.295 * b, 0.222 * b, 0.016, edge, ["chest"], n=16, fold=fold, folds=7, dip=0.05)


def mask(m, sw, edge=None, high=0.17):
    """A face mask from the chin to under the eyes, ridged down the nose."""
    ys = [0.02, 0.09, high]
    shell(m, [HC + [0, y, 0.0] for y in ys], [(0.118, 0.138), (0.13, 0.152), (0.133, 0.156)], -72, 72, sw, HB, n=12, th=0.016,
          edge=edge or sw, inner="black", front=1.08, point=[0.0, 0.02, 0.03])


def coif(m, sw):
    """A leather coif tight to the head, open at the face."""
    hp = [(0.0, 0.118, 0.128), (0.08, 0.132, 0.142), (0.17, 0.138, 0.148), (0.26, 0.136, 0.146), (0.33, 0.118, 0.128), (0.39, 0.08, 0.09), (0.425, 0.02, 0.025)]
    shell(m, [HC + [0, y, 0] for y, *_ in hp], [(rx, rz) for _, rx, rz in hp], 40, 320, sw, HB, n=16, th=0.02, inner="black")
    tube(m, [HC + [0, 0.07, 0.02], HC + [0, 0.17, 0.07], HC + [0, 0.27, 0.04]], [(0.09, 0.07), (0.1, 0.075), (0.085, 0.06)], "black", HB, n=10)


def hat(m, sw, band_sw, brim, tall, bend=0.12, y0=0.29):
    """A pointed hat: a wide brim and a crown bent over at the tip."""
    tube(m, [HC + [0, y0 - 0.02, 0], HC + [0, y0, 0]], [(brim * 0.95, brim), (0.155, 0.165)], sw, HB, n=18, caps=(False, False))
    tube(m, [HC + [0, y0 - 0.035, 0], HC + [0, y0 - 0.02, 0]], [(0.15, 0.16), (brim * 0.95, brim)], "black", HB, n=18, caps=(False, False))
    cone = [(0.0, 0.0, 0.16), (0.3, -0.01, 0.125), (0.55, -0.04, 0.085), (0.78, -bend * 0.5, 0.045), (1.0, -bend, 0.0)]
    tube(m, [HC + [0, y0 + t * tall, z] for t, z, _ in cone], [(r, r * 1.05) for _, _, r in cone], sw, HB, fwd=(1, 0, 0), n=10)
    band(m, HC + [0, y0 + 0.03, 0], UP, (0, 0, 1), 0.162, 0.17, 0.045, band_sw, HB, n=10)


def horns(m, base, tip, at=0.3, size=1.0, out=0.13, curl=0.06):
    for s in (1, -1):
        h = [HC + [s * out, at, 0.0], HC + [s * (out + 0.09 * size), at + 0.06 * size, -0.02], HC + [s * (out + 0.15 * size), at + 0.18 * size, 0.0],
             HC + [s * (out + 0.14 * size), at + 0.3 * size, curl]]
        tube(m, h, [0.045 * size, 0.035 * size, 0.022 * size, 0.0], [base, base, tip], HB, fwd=(0, 0, 1), n=6, caps=(True, False))


def antlers(m, sw, tip, size=1.0, y=0.33):
    for s in (1, -1):
        p = [HC + [s * 0.1, y, -0.02], HC + [s * (0.1 + 0.1 * size), y + 0.13 * size, -0.05], HC + [s * (0.1 + 0.16 * size), y + 0.29 * size, -0.04],
             HC + [s * (0.1 + 0.14 * size), y + 0.43 * size, 0.01]]
        tube(m, p, [0.022, 0.018, 0.013, 0.0], [sw, sw, tip], HB, fwd=(0, 0, 1), n=6, caps=(True, False))
        for k, (dx, dy, dz) in ((1, (0.03, 0.09, 0.08)), (2, (0.07, 0.08, 0.05)), (2, (-0.05, 0.1, -0.02))):
            q = p[k] + np.array([s * dx, dy, dz]) * size
            tube(m, [p[k], q], [0.012, 0.0], [sw, tip], HB, fwd=(1, 0, 0), n=4, caps=(True, False))


def circlet(m, sw, gem, y=0.27, r=1.0):
    band(m, HC + [0, y, 0], UP, (0, 0, 1), 0.172 * r, 0.183 * r, 0.026, sw, HB, n=16)
    star(m, HC + [0, y + 0.012, 0.19 * r], (0, 0.1, 1), UP, 0.045, gem, HB, pts=4, th=0.016)


def crown(m, sw, y=0.31, r=1.0, tall=0.09, n=8):
    band(m, HC + [0, y, 0], UP, (0, 0, 1), 0.15 * r, 0.162 * r, 0.04, sw, HB, n=16)
    for i in range(n):
        a = math.radians(i * 360 / n)
        p = HC + [0.15 * r * math.sin(a), y + 0.02, 0.162 * r * math.cos(a)]
        stud(m, p, (math.sin(a) * 0.3, 1, math.cos(a) * 0.3), 0.022, tall if i % 2 == 0 else tall * 0.55, sw, HB, sides=4)


def fur(m, sw, b=1.0, lo=1.62, sides=(1, -1)):
    """A fur mantle over the shoulders."""
    cy = [(lo, 0.32, 0.22, 0.06), (lo + 0.08, 0.28, 0.2, 0.06), (lo + 0.16, 0.19, 0.15, 0.05)]
    tube(m, [(0, y, 0) for y, *_ in cy], [(rx * b, rz * b) for _, rx, rz, _ in cy], sw, ["chest"], n=16, fold=[c[3] for c in cy], folds=9, caps=(False, False))


def strap(m, sw, b, x0, x1, y0=1.76, y1=1.08, back=True, w=0.035):
    """A strap from one shoulder across the chest (and down the back)."""
    pts = [on_front(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, b, 0.022) for t in np.linspace(0, 1, 6)]
    tube(m, pts, [(w, 0.008)] * len(pts), sw, TORSO, fwd=(0, 0, 1), n=4, caps=(False, False))
    if back:
        bk = [p * [1, 1, -1] for p in pts]
        tube(m, bk, [(w, 0.008)] * len(bk), sw, TORSO, fwd=(0, 0, -1), n=4, caps=(False, False))


def studs(m, sw, b, xs, ys, out=0.02):
    for y in ys:
        for x in xs:
            p = on_front(x, y, b, out)
            nrm = p * [1, 0, 1]
            stud(m, p, nrm / np.linalg.norm(nrm), 0.011, 0.012, sw, ["chest" if y > 1.33 else "spine"])


def belt(m, sw, buckle, b=1.0, y=1.08, pouch=None):
    tube(m, [(0, y - 0.03, 0), (0, y + 0.035, 0)], [(0.258 * b, 0.178 * b)] * 2, sw, ["hips"], n=18, front=1.04, caps=(False, False))
    star(m, (0, y + 0.003, 0.186 * b + 0.005), (0, 0, 1), UP, 0.045, buckle, ["hips"], pts=4, th=0.014)
    if pouch:
        for s in (1, -1):
            tube(m, [(s * 0.19 * b, y - 0.1, 0.11 * b), (s * 0.19 * b, y + 0.01, 0.11 * b)], [(0.05, 0.035)] * 2, pouch, ["hips"], fwd=(0, 0, 1), n=6)


def emblem(m, kind, tr, b=1.0, y=1.58):
    z = surf(y, b)[1] + 0.06
    if kind == "star":
        star(m, (0, y, z), (0, 0.15, 1), UP, 0.09, tr, ["chest"], pts=4, th=0.018)
        star(m, (0, y, z + 0.007), (0, 0.15, 1), UP, 0.045, "white", ["chest"], pts=4, th=0.02)
    elif kind == "fang":
        star(m, (0, y, z), (0, 0.15, 1), UP, 0.06, "red", ["chest"], pts=3, th=0.022)
    elif kind == "sun":
        star(m, (0, y, z), (0, 0.15, 1), UP, 0.12, tr, ["chest"], pts=8, th=0.016)
        star(m, (0, y, z + 0.009), (0, 0.15, 1), UP, 0.045, "white", ["chest"], pts=6, th=0.02)


def paul(m, s, side, style, pl, tr, g=1.0, spikes=0):
    """A pauldron: hide, plate with lames, or a fur pad; spiked on demand."""
    ua = J("upperarm." + side)
    ax = np.array([s, 0, 0.0])
    ub = ["upperarm." + side]
    if style == "fur":
        tube(m, [ua - ax * 0.05, ua + ax * 0.06, ua + ax * 0.14], [(0.16 * g, 0.15 * g), (0.18 * g, 0.17 * g), (0.15 * g, 0.14 * g)], pl, ub, fwd=UP, n=12,
             fold=0.08, folds=7, caps=(False, False))
    elif style == "hide":
        shell(m, [ua + ax * t for t in (-0.06, 0.02, 0.12)], [(0.12 * g, 0.115 * g), (0.15 * g, 0.142 * g), (0.14 * g, 0.133 * g)], -100, 100, pl, ub,
              fwd=UP, n=10, edge=tr, th=0.02)
        stud(m, ua + ax * 0.04 + [0, 0.15 * g, 0], (0, 1, 0), 0.015, 0.012, tr, ub)
    else:
        dome = [(-0.1, 0.07), (-0.06, 0.15), (0.0, 0.19), (0.07, 0.205), (0.13, 0.2)]
        shell(m, [ua + ax * t * g for t, _ in dome], [(r * g, r * 0.95 * g) for _, r in dome], -112, 112, pl, ub, fwd=UP, n=14, edge=tr, th=0.02)
        for i in range(1 if style == "plate" else 3):
            t0 = 0.12 + i * 0.055
            r0 = (0.195 - i * 0.014) * g
            shell(m, [ua + ax * t0 * g, ua + ax * (t0 + 0.075) * g], [(r0, r0 * 0.95), (r0 - 0.004, r0 * 0.95 - 0.004)], -100, 100, pl, ub, fwd=UP, n=12,
                  edge=tr, th=0.016)
    for i in range(spikes):
        zz = (i - (spikes - 1) / 2) * 0.08
        stud(m, ua + ax * 0.05 * g + [0, 0.19 * g - abs(zz) * 0.3, zz], (s * 0.3, 1, zz * 2), 0.028, 0.12 + 0.04 * (abs(zz) < 0.01), tr, ub, sides=5)


def bracer(m, s, side, sw, tr, spikes=0, flare=0.0):
    la, wr = J("lowerarm." + side), J("wrist." + side)
    ax = np.array([s, 0, 0.0])
    lb = ["lowerarm." + side]
    tube(m, [la + ax * 0.05, wr - ax * 0.03], [(0.078 + flare, 0.076 + flare), (0.066, 0.064)], sw, lb, fwd=UP, n=10, caps=(False, False))
    for t in (0.06, 0.29):
        band(m, la + ax * t, ax, UP, 0.08 + flare * (t < 0.1), 0.078 + flare * (t < 0.1), 0.014, tr, lb, n=10)
    for i in range(spikes):
        stud(m, la + ax * (0.1 + 0.08 * i) + [0, 0.072, 0], (0, 1, -0.3), 0.018, 0.07, tr, lb, sides=4)


def sleeve(m, s, side, sw, bell=0.0, hem=None):
    """A robe sleeve over the arm, belling out at the wrist."""
    ua, la, wr = J("upperarm." + side), J("lowerarm." + side), J("wrist." + side)
    ax = np.array([s, 0, 0.0])
    tube(m, [ua - ax * 0.03, la - ax * 0.02], [(0.108, 0.103), (0.09, 0.087)], sw, ["upperarm." + side], fwd=UP, n=10, caps=(False, False))
    tube(m, [la - ax * 0.03, la + (wr - la) * 0.5, wr - ax * 0.02], [(0.088, 0.085), (0.095 + bell * 0.4, 0.092 + bell * 0.4), (0.1 + bell, 0.11 + bell * 1.3)], sw,
         ["lowerarm." + side], fwd=UP, n=10, caps=(False, False), dip=[0, 0.0, bell * 0.6])
    if hem:
        band(m, wr - ax * 0.025, ax, UP, 0.103 + bell, 0.113 + bell * 1.3, 0.016, hem, ["lowerarm." + side], n=10, dip=bell * 0.6)


def gloves(m, sw, tr=None, plate=False):
    for s, side in ((1, "l"), (-1, "r")):
        K.glove(m, J("wrist." + side), np.array([s, 0, 0.0]), side, sw, sw, cuff=0.07 if tr else 0.06, plate=plate, trim=tr)


def arms(m, sw, b=1.0):
    """Sleeves from the shoulder to the wrist, under what a chest piece puts on the arms."""
    for s, side in ((1, "l"), (-1, "r")):
        ua, la, wr = J("upperarm." + side), J("lowerarm." + side), J("wrist." + side)
        ax = np.array([s, 0, 0.0])
        tube(m, [ua - ax * 0.04, ua + ax * 0.12, la, wr - ax * 0.03], [(0.104 * b, 0.099 * b), (0.094 * b, 0.089 * b), (0.075, 0.073), (0.06, 0.058)], sw,
             ["chest", "upperarm." + side, "lowerarm." + side, "wrist." + side], fwd=UP, n=10)


def seat(m, sw, b=1.0):
    """The seat of the breeches, so no gap shows between the legs and the belt."""
    tube(m, [(0, 0.86, 0), (0, 1.06, 0)], [(0.25 * b, 0.17 * b), (0.248 * b, 0.168 * b)], sw, ["hips"], n=16, caps=(True, False))


def trousers(m, sw, b=1.0):
    for s, side in ((1, "l"), (-1, "r")):
        ul, ll, ft = J("upperleg." + side), J("lowerleg." + side), J("foot." + side)
        top = ul + [-0.04 * s, -0.05, 0]
        tube(m, [top, top + (ll - top) * 0.5, ll, ll + (ft - ll) * 0.45], [(0.125 * b, 0.127 * b), (0.11 * b, 0.115 * b), (0.088, 0.092), (0.078, 0.082)], sw,
             ["hips", "upperleg." + side, "lowerleg." + side], n=10)


def boots(m, sw, cuff=None, fur_sw=None, tall=0.45):
    for s, side in ((1, "l"), (-1, "r")):
        ll, ft = J("lowerleg." + side), J("foot." + side)
        tube(m, [ft + (ll - ft) * tall, ft + (ll - ft) * 0.1], [(0.09, 0.093), (0.078, 0.083)], sw, ["lowerleg." + side], n=10, caps=(False, False))
        K.shoe(m, ft, side, sw, sw)
        if cuff:
            band(m, ft + (ll - ft) * (tall - 0.02), UP, (0, 0, 1), 0.098, 0.1, 0.03, cuff, ["lowerleg." + side], n=10)
        if fur_sw:
            tube(m, [ft + (ll - ft) * (tall - 0.12), ft + (ll - ft) * (tall + 0.02)], [(0.11, 0.112), (0.1, 0.102)], fur_sw, ["lowerleg." + side], n=10,
                 fold=0.1, folds=7, caps=(False, False))


def knees(m, sw, tr=None, spike=False):
    for side in ("l", "r"):
        ll = J("lowerleg." + side)
        tube(m, [ll + [0, 0, 0.05], ll + [0, 0, 0.11]], [(0.078, 0.072), (0.052, 0.047)], sw, ["lowerleg." + side], fwd=UP, n=8)
        if tr:
            band(m, ll + [0, 0, 0.055], (0, 0, 1), UP, 0.08, 0.074, 0.014, tr, ["lowerleg." + side], n=8)
        if spike:
            stud(m, ll + [0, 0, 0.11], (0, 0.2, 1), 0.024, 0.09, tr or sw, ["lowerleg." + side])


def greaves(m, pl, tr, spikes=False, thighs=False):
    for s, side in ((1, "l"), (-1, "r")):
        ul, ll, ft = J("upperleg." + side), J("lowerleg." + side), J("foot." + side)
        llb = ["lowerleg." + side]
        if thighs:
            top = ul + [-0.03 * s, -0.04, 0]
            shell(m, [top + [0, -0.06, 0], top + (ll - top) * 0.5, ll + [0, 0.07, 0]], [(0.13, 0.134), (0.118, 0.122), (0.1, 0.104)], -80, 80, pl,
                  ["upperleg." + side], n=12, edge=tr, front=1.05, point=0.01)
        tube(m, [ll + [0, 0, 0.04], ll + [0, 0, 0.1], ll + [0, 0, 0.125]], [(0.085, 0.075), (0.07, 0.06), (0.0, 0.0)], pl, llb, fwd=UP, n=10, caps=(False, False))
        band(m, ll + [0, 0, 0.045], (0, 0, 1), UP, 0.088, 0.078, 0.016, tr, llb, n=10)
        if spikes:
            stud(m, ll + [0, 0, 0.122], (0, 0, 1), 0.026, 0.1, tr, llb)
        g0, g1 = ll + (ft - ll) * 0.08, ft + (ll - ft) * 0.08
        tube(m, [g0, g0 + (g1 - g0) * 0.35, g1], [(0.09, 0.092), (0.092, 0.096), (0.074, 0.077)], pl, llb, fwd=(0, 0, 1), n=12, front=1.08, point=0.02,
             caps=(False, False))
        band(m, g1 + (g0 - g1) * 0.02, g1 - g0, (0, 0, 1), 0.078, 0.081, 0.016, tr, llb, n=12, front=1.08, point=0.018)
        K.shoe(m, ft, side, pl, pl, trim=tr, lames=True)


def flaps(m, sw, hem, angles, length=0.42, w=0.11, b=1.0, torn=0.05, seed=3, y0=1.05):
    """Cloth or hide flaps hung round the belt, at angles (0 = the front)."""
    for i, deg in enumerate(angles):
        a = math.radians(deg)
        nrm = np.array([math.sin(a), 0, math.cos(a)])
        side = np.array([math.cos(a), 0, -math.sin(a)])
        rx, rz = 0.262 * b, 0.18 * b
        R, C = 6, 5
        jag = jagged(C, torn, seed + i)
        rows = []
        for r in range(R):
            t = r / (R - 1)
            c0 = np.array([rx * math.sin(a), y0 - t * length, rz * math.cos(a)]) + nrm * (0.012 + 0.05 * t)
            ww = w * (1 + 0.15 * t)
            rows.append([c0 + side * (-ww + 2 * ww * c / (C - 1)) - [0, jag[c] if r == R - 1 else 0.0, 0] for c in range(C)])
        x = math.sin(a)
        bones = ["hips"] + (["upperleg.l"] if x > -0.3 else []) + (["upperleg.r"] if x < 0.3 else [])
        sheet(m, rows, sw, bones, edge=hem)


def skirt(m, sw, hem, b=1.0, bottom=0.14, flare=0.13, torn=0.0, seed=7, y0=1.09, slit=False):
    """A robe from the belt to the ankles, hung from the hips and the thighs,
    in four panels so the legs can stride (slit at the front and back)."""
    for i, (a0, a1) in enumerate(((-38, 38), (40, 140), (142, 218), (220, 320)) if slit else ((-45, 45), (45, 135), (135, 225), (225, 315))):
        R, C = 8, 6
        jag = jagged(C, torn, seed + i)
        rows = []
        for r in range(R):
            t = r / (R - 1)
            y = y0 - t * (y0 - bottom)
            rx, rz = (0.262 + flare * t) * b, (0.182 + flare * 0.8 * t) * b
            row = []
            for c in range(C):
                a = math.radians(a0 + (a1 - a0) * c / (C - 1))
                f = 1 + 0.06 * t * math.sin(c * 2.2 + i)
                row.append((rx * f * math.sin(a), y - (jag[c] if r == R - 1 else 0.0), rz * f * math.cos(a)))
            rows.append(row)
        mid = math.radians((a0 + a1) / 2)
        x = math.sin(mid)
        bones = ["hips"] + (["upperleg.l"] if x > -0.3 else []) + (["upperleg.r"] if x < 0.3 else [])
        sheet(m, rows, sw, bones, edge=hem, back_sw="black")


def undersuit(body, arms, legs, head_fn, gl, bt, b=1.0, seams="black"):
    m = {"Body": H.Mesh(), "ArmLeft": H.Mesh(), "LegLeft": H.Mesh(), "Head": H.Mesh()}
    p, r = prof(0.88, 1.83, b)
    tube(m["Body"], p, r, body, TORSO, n=16, front=1.05)
    for y in (1.2, 1.38, 1.56):
        band(m["Body"], (0, y, 0), UP, (0, 0, 1), surf(y, b)[0] + 0.006, surf(y, b)[1] + 0.006, 0.012, seams, TORSO, n=16, front=1.05)
    for s, side in ((1, "l"), (-1, "r")):
        ua, la, wr = J("upperarm." + side), J("lowerarm." + side), J("wrist." + side)
        ax = np.array([s, 0, 0.0])
        tube(m["ArmLeft"], [ua - ax * 0.04, ua + ax * 0.12, la, wr - ax * 0.03], [(0.1 * b, 0.095 * b), (0.09 * b, 0.085 * b), (0.072, 0.07), (0.058, 0.056)], arms,
             ["chest", "upperarm." + side, "lowerarm." + side, "wrist." + side], fwd=UP, n=10)
    gloves(m["ArmLeft"], gl)
    trousers(m["LegLeft"], legs, b)
    boots(m["LegLeft"], bt)
    head_fn(m["Head"])
    return m


# --- Ranger: the Grave Warden ---------------------------------------------------------
# Hide and a hood, then a studded brigandine, then plate on the shoulders;
# an antlered crown at the top.

def ranger_under():
    return undersuit("hide", "hide", "cloth", lambda m: hood(m, "cloth", peak=0.05, drape=False), "hide", "hide")


def ranger_helm(k):
    P, m = PAL[k], H.Mesh()
    if k == 0:
        coif(m, "hide")
        mask(m, "cloth", high=0.14)
        tube(m, [HC + [0, 0.3, 0], HC + [0, 0.33, 0]], [(0.205, 0.215), (0.15, 0.16)], "hide", HB, n=14, caps=(False, False))
        band(m, HC + [0, 0.3, 0], UP, (0, 0, 1), 0.15, 0.16, 0.035, "hide", HB, n=14)
        tube(m, [HC + [0.12, 0.33, -0.04], HC + [0.2, 0.42, -0.14]], [(0.018, 0.006), (0.0, 0.0)], "bone", HB, fwd=(0, 0, 1), n=4)
        return m, True
    hood(m, P["cloth"] if k != 2 else "moss", edge=P["trim"] if k > 1 else None, peak=0.07, fold=0.05)
    mask(m, P["dark"] if k < 4 else "pale", edge=P["trim"])
    if k == 2:
        circlet(m, "silver", "white")
    elif k == 3:
        antlers(m, "bone", "blood", size=0.8)
    elif k == 4:
        crown(m, "agold", y=0.3, r=1.12, tall=0.06)
        antlers(m, "agold", "agold", size=1.05, y=0.34)
    return m, True


def ranger_chest(k):
    P, m = PAL[k], H.Mesh()
    p, r = prof(1.0, 1.8, 1.0, 0.016)
    tube(m, p, r, P["main"], TORSO, n=16, front=1.05, point=0.012)
    arms(m, "cloth" if k < 4 else "white")
    if k == 0:
        fur(m, "fur")
        strap(m, "hide", 1.0, 0.2, -0.2)
    else:
        # A brigandine: rows of rivets, then plates at the top of the chest.
        studs(m, P["trim"] if k < 4 else "agold", 1.0, (-0.17, -0.09, 0.09, 0.17), (1.22, 1.32, 1.42) if k > 1 else (1.22, 1.32, 1.42, 1.52, 1.62))
        strap(m, "hide" if k < 4 else "agold", 1.0, 0.22, -0.18, w=0.04)
        if k >= 2:
            shell(m, [(0, 1.47, 0), (0, 1.6, 0), (0, 1.72, 0)], [(0.29, 0.19), (0.3, 0.192), (0.265, 0.172)], -64, 64, P["metal"], ["chest"], n=12,
                  edge=P["trim"], front=1.12, point=0.035)
            emblem(m, {2: "star", 3: "fang", 4: "sun"}[k], P["trim"], y=1.6)
        if k >= 2:
            cy = [(1.64, 0.32, 0.235, 0.07, 0.16), (1.72, 0.29, 0.215, 0.07, 0.1), (1.79, 0.21, 0.17, 0.06, 0.05)]
            shell(m, [(0, y, 0) for y, *_ in cy], [(rx, rz) for _, rx, rz, _, _ in cy], -150, 150, P["cloth"] if k != 2 else "moss", ["chest"], n=18,
                  th=0.02, edge=P["hem"], fold=[c[3] for c in cy], dip=[c[4] for c in cy])
        if k >= 1:
            K.cape(m, P["cloth"] if k != 2 else "moss", P["hem"], torn=0.16 if k < 4 else 0.05, seed=21 + k, long=k >= 3)
    for s, side in ((1, "l"), (-1, "r")):
        if k == 0:
            paul(m, s, side, "hide", "hide", "rust", g=0.85)
        elif k == 1:
            paul(m, s, side, "hide", "hide", "steel", g=0.9)
        else:
            # The bow arm keeps a lighter guard.
            paul(m, s, side, "plate" if s < 0 or k == 4 else "hide", P["metal"] if s < 0 or k == 4 else "hide", P["trim"], g=0.85 if s > 0 else 0.95,
                 spikes=3 if k == 3 and s < 0 else 0)
        bracer(m, s, side, "hide" if k < 4 else "pale", P["trim"], spikes=2 if k == 3 else 0)
    gloves(m, "hide" if k < 4 else "pale")
    return m


def ranger_legs(k):
    P, m = PAL[k], H.Mesh()
    seat(m, "cloth" if k < 4 else "white", 1.04)
    trousers(m, "cloth" if k < 4 else "white", 1.04)
    belt(m, "hide", P["trim"], pouch="hide" if k < 2 else "hide")
    flaps(m, P["main"], P["trim"] if k else "hide", (-30, 30, 150, 210) if k else (0, 180), length=0.3 + 0.03 * k, w=0.09, seed=5 + k)
    if k < 2:
        knees(m, "hide" if k == 0 else "hide", "steel" if k else None)
        boots(m, "hide", cuff="hide", fur_sw="fur" if k == 0 else None, tall=0.55)
    else:
        greaves(m, P["metal"], P["trim"], spikes=k == 3)
    return m


# --- Mage: the Ember Witch -------------------------------------------------------------
# Robes from the shoulders to the ankles; the hat rises with the set.

def mage_under():
    return undersuit("cloth", "cloth", "cloth", lambda m: hood(m, "cloth", peak=0.03, drape=False, deep=0.97), "hide", "hide")


def mage_helm(k):
    P, m = PAL[k], H.Mesh()
    if k == 0:
        hood(m, "hide", peak=0.04, drape=False)
        mask(m, "cloth", high=0.14)
        hat(m, "hide", "hide", brim=0.33, tall=0.5, bend=0.18)
        return m, True
    if k == 1:
        hood(m, "cloth", peak=0.03, drape=False)
        mask(m, "black", edge="steel")
        hat(m, "cloth", "wine", brim=0.3, tall=0.62, bend=0.14)
        stud(m, HC + [0, 0.34, 0.172], (0, 0, 1), 0.02, 0.012, "steel", HB)
        return m, True
    hood(m, P["cloth"], edge=P["trim"], peak=0.1 if k < 4 else 0.02, fold=0.06)
    mask(m, "black" if k < 4 else "pale", edge=P["trim"])
    if k == 2:
        circlet(m, "silver", "white", y=0.29)
    elif k == 3:
        horns(m, "iron", "blood", at=0.32, size=1.05, out=0.12)
        crown(m, "iron", y=0.34, r=1.08, tall=0.05)
    else:
        # A tall mitre of gold over the hood.
        tube(m, [HC + [0, 0.3, 0], HC + [0, 0.48, -0.01], HC + [0, 0.62, -0.03]], [(0.165, 0.175), (0.15, 0.13), (0.0, 0.0)], "agold", HB, n=8, front=1.0,
             point=[0.0, 0.03, 0.0])
        star(m, HC + [0, 0.42, 0.155], (0, 0.15, 1), UP, 0.06, "white", HB, pts=6, th=0.016)
    return m, True


def mage_chest(k):
    P, m = PAL[k], H.Mesh()
    robe = {0: "hide", 1: "wine", 2: "cloth", 3: "wine", 4: "white"}[k]
    p, r = prof(1.0, 1.8, 1.0, 0.018)
    tube(m, p, r, robe, TORSO, n=16, front=1.05)
    # A front panel down the robe, edged in the set's trim.
    tube(m, [on_front(0, 1.04, 1.0, 0.026), on_front(0, 1.4, 1.0, 0.026), on_front(0, 1.74, 1.0, 0.01)], [(0.05, 0.008)] * 3, P["dark"] if k else "hide",
         TORSO, fwd=(0, 0, 1), n=4, caps=(False, False))
    if k == 0:
        fur(m, "hide", lo=1.6)
        strap(m, "hide", 1.0, 0.21, -0.2, back=False)
    else:
        # A mantle: a stiff, high-collared capelet, metal from the third set.
        cy = [(1.6, 0.33, 0.235, 0.04, 0.1), (1.7, 0.3, 0.215, 0.04, 0.06), (1.8, 0.22, 0.175, 0.03, 0.02), (1.88, 0.2, 0.17, 0.0, 0.0)]
        ms = P["metal"] if k >= 2 else P["cloth"]
        shell(m, [(0, y, 0) for y, *_ in cy], [(rx, rz) for _, rx, rz, _, _ in cy], -155, 155, ms, ["chest"], n=18, th=0.022, edge=P["trim"],
              fold=[c[3] for c in cy], dip=[c[4] for c in cy])
        band(m, (0, 1.6, 0), UP, (0, 0, 1), 0.335, 0.24, 0.018, P["trim"], ["chest"], n=18, a0=-155, a1=155, fold=0.04, dip=0.1)
        if k >= 2:
            emblem(m, {2: "star", 3: "fang", 4: "sun"}[k], P["trim"], y=1.48)
        if k >= 3:
            K.cape(m, P["cloth"], P["hem"], torn=0.18 if k == 3 else 0.04, seed=31 + k, long=True)
    for s, side in ((1, "l"), (-1, "r")):
        sleeve(m, s, side, robe, bell=0.05 + 0.012 * k, hem=P["trim"] if k else None)
        if k >= 2:
            paul(m, s, side, "plate" if k < 4 else "layered", P["metal"], P["trim"], g=0.8, spikes=2 if k == 3 else 0)
    gloves(m, "black" if k < 4 else "pale")
    return m


def mage_legs(k):
    P, m = PAL[k], H.Mesh()
    robe = {0: "hide", 1: "wine", 2: "cloth", 3: "wine", 4: "white"}[k]
    seat(m, "cloth")
    trousers(m, "cloth")
    boots(m, "hide" if k < 4 else "pale", tall=0.4)
    skirt(m, robe, P["hem"] if k else "hide", flare=0.1 + 0.015 * k, torn=0.06 if k in (0, 3) else 0.0, seed=13 + k, slit=k >= 2)
    belt(m, "hide" if k < 4 else "agold", P["trim"], y=1.1)
    if k >= 2:
        # A cord down the front, with a charm at its end.
        tube(m, [(0.09, 1.07, 0.2), (0.1, 0.8, 0.24)], [0.01, 0.01], P["trim"], ["hips", "upperleg.l"], n=4)
        star(m, (0.1, 0.77, 0.245), (0, 0, 1), UP, 0.04, P["gem"], ["upperleg.l"], pts=4, th=0.02)
    return m


# --- Barbarian: the Bonebreaker --------------------------------------------------------
# Broader than the others; hide and fur, then iron on the shoulders and a
# horned helm.

BB = 1.1


def barb_under():
    return undersuit("hide", "hide", "hide", lambda m: coif(m, "hide"), "hide", "hide", b=BB)


def barb_helm(k):
    P, m = PAL[k], H.Mesh()
    pl, tr = P["metal"], P["trim"]
    if k == 0:
        coif(m, "hide")
        # An iron cap with a nasal and a mask of hide.
        cap = [(0.24, 0.15, 0.16), (0.32, 0.148, 0.158), (0.38, 0.12, 0.13), (0.43, 0.07, 0.075), (0.455, 0.02, 0.02)]
        tube(m, [HC + [0, y, 0] for y, *_ in cap], [(rx, rz) for _, rx, rz in cap], "iron", HB, n=14)
        band(m, HC + [0, 0.25, 0], UP, (0, 0, 1), 0.152, 0.162, 0.03, "rust", HB, n=14)
        tube(m, [HC + [0, 0.27, 0.16], HC + [0, 0.12, 0.175]], [(0.02, 0.01), (0.016, 0.01)], "iron", HB, fwd=(0, 0, 1), n=4)
        mask(m, "hide", high=0.12)
        return m, True
    # An open-faced iron helm over a face mask, cheek guards to the jaw.
    hp = [(0.02, 0.135, 0.145, 1.0, 0.0), (0.12, 0.148, 0.158, 1.06, 0.02), (0.22, 0.152, 0.162, 1.08, 0.03), (0.31, 0.142, 0.152, 1.02, 0.01),
          (0.38, 0.115, 0.125, 1.0, 0.0), (0.43, 0.07, 0.075, 1.0, 0.0), (0.46, 0.02, 0.02, 1.0, 0.0)]
    shell(m, [HC + [0, y, 0] for y, *_ in hp], [(rx, rz) for _, rx, rz, _, _ in hp], 34, 326, pl, HB, n=16, th=0.024, edge=tr, inner="black",
          front=[p[3] for p in hp], point=[p[4] for p in hp])
    tube(m, [HC + [0, 0.07, 0.02], HC + [0, 0.17, 0.07], HC + [0, 0.27, 0.04]], [(0.09, 0.07), (0.1, 0.075), (0.085, 0.06)], "black", HB, n=10)
    mask(m, "iron" if k < 4 else "pale", edge=tr, high=0.13)
    band(m, HC + [0, 0.27, 0], UP, (0, 0, 1), 0.155, 0.165, 0.03, tr, HB, n=16, front=1.08, point=0.03)
    tube(m, [HC + [0, 0.3, 0.17], HC + [0, 0.13, 0.19]], [(0.022, 0.012), (0.018, 0.012)], tr, HB, fwd=(0, 0, 1), n=4)
    if k == 1:
        horns(m, "bone", "bone", at=0.28, size=1.0, out=0.14)
    elif k == 2:
        # A crest of iron fins, front to back.
        crest = [HC + [0, 0.3 + 0.17 * math.cos(math.radians(a)), 0.17 * math.sin(math.radians(a))] for a in range(70, -100, -24)]
        tube(m, crest, [(0.012, 0.05)] * len(crest), tr, HB, fwd=(1, 0, 0), n=4)
        horns(m, "iron", "silver", at=0.26, size=0.7, out=0.14, curl=0.1)
    elif k == 3:
        horns(m, "iron", "blood", at=0.27, size=1.5, out=0.13, curl=0.12)
        for i in range(5):
            stud(m, HC + [-0.08 + 0.04 * i, 0.44, -0.02], (0, 1, -0.2), 0.02, 0.08, tr, HB, sides=4)
    else:
        horns(m, "pale", "agold", at=0.27, size=1.3, out=0.13, curl=0.1)
        crown(m, "agold", y=0.33, r=1.05, tall=0.1)
    return m, True


def barb_chest(k):
    P, m = PAL[k], H.Mesh()
    pl, tr = P["metal"], P["trim"]
    p, r = prof(1.0, 1.8, BB, 0.014)
    tube(m, p, r, "hide" if k < 4 else "white", TORSO, n=16, front=1.05, point=0.01)
    arms(m, "hide" if k < 4 else "white", BB)
    fur(m, "fur" if k < 4 else "white", b=BB * 1.05)
    if k == 0:
        strap(m, "hide", BB, 0.22, -0.2)
        paul(m, 1, "l", "fur", "fur", "fur", g=1.05)
    else:
        strap(m, "hide", BB, 0.24, -0.22, w=0.045)
        strap(m, "hide", BB, -0.24, 0.22, w=0.045)
        star(m, on_front(0, 1.42, BB, 0.03), (0, 0, 1), UP, 0.06, tr, ["chest"], pts=4, th=0.02)
        if k >= 2:
            # A plate over the heart.
            shell(m, [(0, 1.44, 0), (0, 1.58, 0), (0, 1.7, 0)], [(0.3 * BB, 0.192 * BB), (0.31 * BB, 0.196 * BB), (0.28 * BB, 0.178 * BB)], -10, 70, pl, ["chest"],
                  n=12, edge=tr, front=1.1, point=0.02)
        for s, side in ((1, "l"), (-1, "r")):
            if s > 0 or k >= 2:
                paul(m, s, side, "layered" if k >= 2 else "plate", pl, tr, g=1.12, spikes={3: 3, 4: 2}.get(k, 0) if k >= 2 else 0)
        if k >= 3:
            K.cape(m, "fur" if k == 3 else "white", P["hem"], torn=0.2 if k == 3 else 0.05, seed=41 + k, long=True)
        elif k == 2:
            K.cape(m, "hide", "fur", torn=0.2, seed=43, long=False)
    for s, side in ((1, "l"), (-1, "r")):
        bracer(m, s, side, "hide" if k < 2 else pl, tr if k else "rust", spikes=3 if k >= 3 else 0, flare=0.012)
    gloves(m, "hide" if k < 2 else "hide")
    return m


def barb_legs(k):
    P, m = PAL[k], H.Mesh()
    pl, tr = P["metal"], P["trim"]
    seat(m, "hide" if k < 4 else "cloth", BB)
    trousers(m, "hide" if k < 4 else "cloth", BB)
    belt(m, "hide", tr if k else "rust", b=BB, pouch="hide" if k < 3 else None)
    flaps(m, "fur" if k == 0 else "hide", "fur" if k < 4 else "agold", (-25, 25, 155, 205) if k < 2 else (-40, 0, 40, 140, 180, 220), length=0.36, w=0.08,
          b=BB, torn=0.07, seed=9 + k)
    if k < 2:
        knees(m, "iron" if k else "hide", "rust" if k else None)
        boots(m, "hide", fur_sw="fur", tall=0.5)
    else:
        greaves(m, pl, tr, spikes=k >= 3)
        for side in ("l", "r"):
            ll, ft = J("lowerleg." + side), J("foot." + side)
            tube(m, [ft + (ll - ft) * 0.55, ft + (ll - ft) * 0.72], [(0.11, 0.112), (0.1, 0.102)], "fur" if k < 4 else "white", ["lowerleg." + side], n=10,
                 fold=0.1, folds=7, caps=(False, False))
    return m


# --- Rogue: the Unseen -------------------------------------------------------------------
# Slight and close-fitted: a deep hood, a mask, leather that darkens and
# sharpens, a long scarf that trails.

RB = 0.93


def rogue_under():
    return undersuit("hide", "hide", "hide", lambda m: (hood(m, "cloth", peak=0.08, drape=False, deep=0.98), mask(m, "black")), "black", "hide", b=RB)


def rogue_helm(k):
    P, m = PAL[k], H.Mesh()
    hs = {0: "hide", 1: "cloth", 2: "cloth", 3: "wine", 4: "white"}[k]
    hood(m, hs, edge=P["trim"] if k >= 2 else None, peak=0.1 + 0.02 * k, b=RB, fold=0.06, deep=1.0 + 0.02 * k)
    if k == 0:
        mask(m, "cloth", high=0.15)
    elif k == 1:
        mask(m, "iron", edge="steel", high=0.15)
    elif k == 2:
        mask(m, "iron", edge="silver", high=0.16)
    elif k == 3:
        mask(m, "black", edge="blood", high=0.16)
        for s in (1, -1):
            # Horns swept back through the hood.
            h = [HC + [s * 0.09, 0.36, -0.06], HC + [s * 0.14, 0.42, -0.16], HC + [s * 0.16, 0.44, -0.3]]
            tube(m, h, [0.03, 0.02, 0.0], ["iron", "blood"], HB, fwd=(0, 1, 0), n=6, caps=(True, False))
    else:
        mask(m, "agold", edge="agold", high=0.17)
        circlet(m, "agold", "white", y=0.28, r=1.04)
    return m, True


def rogue_chest(k):
    P, m = PAL[k], H.Mesh()
    p, r = prof(1.0, 1.8, RB, 0.015)
    tube(m, p, r, {0: "hide", 4: "pale"}.get(k, "cloth"), TORSO, n=16, front=1.05, point=0.015)
    arms(m, "cloth" if k < 4 else "white", RB)
    # A bandolier of throwing knives across the chest.
    strap(m, "black" if k else "hide", RB, 0.2, -0.2, w=0.04)
    for i, t in enumerate(np.linspace(0.25, 0.7, 3 + min(k, 2))):
        p0 = on_front(0.2 - 0.4 * t, 1.76 - 0.68 * t, RB, 0.035)
        tube(m, [p0 + [0, 0.05, 0], p0 + [0, -0.05, 0]], [(0.012, 0.004), (0.0, 0.0)], P["trim"] if k else "steel", TORSO, fwd=(0, 0, 1), n=4)
    if k >= 1:
        # A scarf wound at the neck, its tail trailing over a shoulder.
        sc = {1: "wine", 2: "cloth", 3: "wine", 4: "white"}[k]
        tube(m, [(0, 1.74, 0), (0, 1.84, 0)], [(0.17, 0.14), (0.13, 0.115)], sc, ["chest"], n=12, fold=0.08, folds=5, caps=(False, False))
        R = 7
        rows = []
        jag = jagged(3, 0.06 + 0.02 * (k == 3), 4 + k)
        for r_ in range(R):
            t = r_ / (R - 1)
            c = np.array([-0.12 - 0.05 * t, 1.78 - t * (0.55 + 0.12 * k), -0.17 - 0.08 * t])
            rows.append([c + [-0.06, -(jag[0] if r_ == R - 1 else 0), 0], c + [0, -(jag[1] if r_ == R - 1 else 0), -0.01], c + [0.06, -(jag[2] if r_ == R - 1 else 0), 0]])
        sheet(m, [[np.array(p_) * [1, 1, 1] for p_ in row][::-1] for row in rows], sc, ["chest", "spine"], edge=P["hem"])
    if k >= 2:
        shell(m, [(0, 1.5, 0), (0, 1.62, 0), (0, 1.72, 0)], [(0.27 * RB, 0.175 * RB), (0.28 * RB, 0.178 * RB), (0.25 * RB, 0.16 * RB)], -60, 10, P["metal"], ["chest"],
              n=10, edge=P["trim"], front=1.1, point=0.02)
        K.cape(m, {2: "cloth", 3: "wine", 4: "white"}[k], P["hem"], torn=0.2 if k < 4 else 0.06, seed=51 + k, long=k >= 3)
    for s, side in ((1, "l"), (-1, "r")):
        if k >= 1:
            paul(m, s, side, "hide" if k < 3 else "plate", "hide" if k < 3 else P["metal"], P["trim"], g=0.8, spikes=2 if k == 3 and s > 0 else 0)
        bracer(m, s, side, "hide" if k < 4 else "pale", P["trim"] if k else "hide", spikes=3 if k == 3 else 0, flare=0.006)
    gloves(m, "black" if k < 4 else "pale")
    return m


def rogue_legs(k):
    P, m = PAL[k], H.Mesh()
    seat(m, "cloth" if k < 4 else "white", RB)
    trousers(m, "cloth" if k < 4 else "white", RB)
    belt(m, "black", P["trim"], b=RB)
    # Wraps round the thighs and a knife on the hip.
    for side, s in (("l", 1), ("r", -1)):
        ul, ll = J("upperleg." + side), J("lowerleg." + side)
        for t in (0.35, 0.55) if k < 2 else (0.45,):
            band(m, ul + (ll - ul) * t, UP, (0, 0, 1), 0.112, 0.116, 0.025, "hide" if k < 4 else "agold", ["upperleg." + side], n=10)
    tube(m, [(0.24, 1.0, 0.04), (0.27, 0.78, 0.06)], [(0.025, 0.012), (0.018, 0.01)], "black", ["hips", "upperleg.l"], fwd=(0, 0, 1), n=4)
    flaps(m, "hide" if k < 4 else "pale", P["trim"] if k else "hide", (150, 210) if k < 2 else (-35, 35, 150, 210), length=0.35, w=0.08, b=RB, torn=0.08,
          seed=17 + k)
    if k < 2:
        knees(m, "hide", "steel" if k else None)
        boots(m, "hide", cuff="black", tall=0.6)
    else:
        knees(m, P["metal"], P["trim"], spike=k == 3)
        boots(m, "hide" if k < 4 else "pale", cuff=P["trim"], tall=0.6)
    return m


HEROES = {
    "Ranger": (ranger_under, ranger_helm, ranger_chest, ranger_legs),
    "Mage": (mage_under, mage_helm, mage_chest, mage_legs),
    "Barbarian": (barb_under, barb_helm, barb_chest, barb_legs),
    "Rogue": (rogue_under, rogue_helm, rogue_chest, rogue_legs),
}


if __name__ == "__main__":
    g, nodes, joints, _ = H.skeleton()
    names = [a for a in sys.argv[1:] if not a.isdigit()] or list(HEROES)
    ks = [int(a) for a in sys.argv[1:] if a.isdigit()] or list(range(len(PAL)))
    for hero in names:
        under, helm, chest, legs = HEROES[hero]
        base = "Dark" + hero
        H.write(None, SK, g, nodes, joints, base, K.out(base), meshes=[(base + "_" + n, mm) for n, mm in under().items()], image=IMAGE)
        for k in ks:
            hm, _closed = helm(k)
            for slot, mm in (("Helm", hm), ("Chest", chest(k)), ("Legs", legs(k))):
                nm = "%s_%s%d" % (base, slot, k)
                H.write(None, SK, g, nodes, joints, nm, K.out(nm), meshes=[(nm + "_Mesh", mm)], image=IMAGE)
        print("WROTE", base)
