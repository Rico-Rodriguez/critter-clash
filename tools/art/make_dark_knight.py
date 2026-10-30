"""The Knight's dark-fantasy kit: an undersuit and, for each of the five sets,
a helm, a chest (torso, arms, cape) and legs (belt, tabard, legs, feet), each
its own skinned model on the hero skeleton, so any helm goes with any chest.

    python3 tools/art/make_dark_knight.py [set ...]   (plain Python + numpy)

Writes into assets/kaykit/characters/:
- DarkKnight.glb: the bare hero (meshes Body, ArmLeft, LegLeft, Head): a
  quilted gambeson, a mail coif, boots and gloves; no skin shows.
- DarkKnight_Helm<k>.glb, DarkKnight_Chest<k>.glb, DarkKnight_Legs<k>.glb,
  each with one mesh, "<file>_Mesh", for GearDB's "DarkKnight_Helm2/Mesh".

The ladder: Gravedigger (scavenged mail, a rusty breastplate and a kettle
hat), Warden (plain black plate, a visored bascinet, a wine tabard with a
silver cross), Barrowsteel (black plate edged in silver, a beaked helm, a
cowl, a cape and a star), Bloodiron (black plate edged in blood red, spikes,
a horned great helm, a wine cape), Gravelight (pale steel and gold, a winged
and crowned helm, a white cape and a sun).
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_hero_body as H  # noqa: E402
from dark_kit import IMAGE, UP, Part, tube, shell, band, stud, star, sheet, jagged  # noqa: E402

SETS = [
    {"plate": "iron", "trim": "rust", "mail": "steel_dark", "cloth": "hide", "hem": "rust", "gold": "rust",
     "helm": "kettle", "paul": "leather", "lames": 0, "emblem": None, "tabard": None, "cape": None, "cowl": False, "spikes": False},
    {"plate": "iron", "trim": "steel", "mail": "steel_dark", "cloth": "wine", "hem": "wine", "gold": "steel",
     "helm": "bascinet", "paul": "plain", "lames": 2, "emblem": "cross", "tabard": "wine", "cape": None, "cowl": False, "spikes": False},
    {"plate": "iron", "trim": "silver", "mail": "steel_dark", "cloth": "cloth", "hem": "rust", "gold": "agold",
     "helm": "beaked", "paul": "layered", "lames": 3, "emblem": "star", "tabard": "cloth", "cape": "cloth", "cowl": True, "spikes": False},
    {"plate": "iron", "trim": "blood", "mail": "steel_dark", "cloth": "wine", "hem": "blood", "gold": "blood",
     "helm": "horned", "paul": "spiked", "lames": 3, "emblem": "fang", "tabard": "cloth", "cape": "wine", "cowl": False, "spikes": True},
    {"plate": "pale", "trim": "agold", "mail": "steel", "cloth": "white", "hem": "agold", "gold": "agold",
     "helm": "winged", "paul": "winged", "lames": 3, "emblem": "sun", "tabard": "white", "cape": "white", "cowl": False, "spikes": False},
]

H.BUILD = H.BUILDS["heroic"]
# Every face here is wound outward as it is made.
H.ORIENT_SMALL = False
_, _, _, SK = H.skeleton()


def J(name):
    return H.J(SK, name)


HEAD = J("head")
HC = HEAD + np.array([0, -0.04, 0.0])  # where helms are built from


# --- The bare hero -----------------------------------------------------------------

def undersuit():
    """Quilted gambeson, dark breeches, boots and gloves, and a mail coif with
    the face in shadow."""
    body, arms, legs, head = H.Mesh(), H.Mesh(), H.Mesh(), H.Mesh()
    T = ["hips", "spine", "chest"]
    prof = [(0.88, 0.235, 0.16), (1.0, 0.25, 0.165), (1.15, 0.235, 0.155), (1.3, 0.245, 0.16), (1.45, 0.265, 0.17),
            (1.6, 0.275, 0.172), (1.72, 0.25, 0.155), (1.79, 0.16, 0.12), (1.83, 0.1, 0.095)]
    tube(body, [(0, y, 0) for y, *_ in prof], [(rx, rz) for _, rx, rz in prof], "cloth", T, n=16, front=1.05)
    # Quilting: raised seams round the gambeson.
    for y in (1.2, 1.32, 1.44, 1.56):
        band(body, (0, y, 0), UP, (0, 0, 1), 0.262 if y > 1.4 else 0.25, 0.168, 0.012, "hide", T, n=16, front=1.05)
    tube(body, [(0, 1.04, 0), (0, 1.1, 0)], [(0.258, 0.172)] * 2, "hide", ["hips"], n=16, caps=(False, False), smooth=False)
    for s, side in ((1, "l"), (-1, "r")):
        ua, la, wr = J("upperarm." + side), J("lowerarm." + side), J("wrist." + side)
        ax = np.array([s, 0, 0.0])
        bones = ["chest", "upperarm." + side, "lowerarm." + side, "wrist." + side]
        tube(arms, [ua - ax * 0.04, ua + ax * 0.12, la, wr - ax * 0.03], [(0.1, 0.095), (0.09, 0.085), (0.072, 0.07), (0.058, 0.056)], "cloth", bones, fwd=UP, n=10)
        glove(arms, wr, ax, side, "hide", "hide", cuff=0.07)
        ul, ll, ft = J("upperleg." + side), J("lowerleg." + side), J("foot." + side)
        top = ul + [-0.04 * s, -0.05, 0]
        tube(legs, [top, top + (ll - top) * 0.5, ll, ll + (ft - ll) * 0.45], [(0.12, 0.122), (0.105, 0.11), (0.085, 0.088), (0.075, 0.078)], "cloth",
             ["hips", "upperleg." + side, "lowerleg." + side], n=10)
        boot(legs, ll, ft, side, "hide")
    # The coif: mail over the head and shoulders, open at the face.
    hp = [(0.0, 0.11, 0.12), (0.08, 0.125, 0.135), (0.17, 0.132, 0.142), (0.26, 0.13, 0.14), (0.33, 0.112, 0.122), (0.39, 0.075, 0.085), (0.425, 0.02, 0.025)]
    shell(head, [HC + [0, y, 0] for y, *_ in hp], [(rx, rz) for _, rx, rz in hp], 38, 322, "steel_dark", ["head"], n=16, th=0.02, smooth=False, inner="black")
    # The face, in the coif's shadow.
    tube(head, [HC + [0, 0.07, 0.02], HC + [0, 0.17, 0.07], HC + [0, 0.27, 0.04]], [(0.09, 0.07), (0.1, 0.075), (0.085, 0.06)], "black", ["head"], n=10)
    # Mail falling over the shoulders.
    tube(head, [HC + [0, 0.04, 0], HC + [0, -0.03, 0], HC + [0, -0.08, 0]], [(0.12, 0.13), (0.2, 0.17), (0.27, 0.2)], "steel_dark", ["head", "chest"], n=16, smooth=False, caps=(False, False))
    return {"Body": body, "ArmLeft": arms, "LegLeft": legs, "Head": head}


def glove(m, wr, ax, side, sw, cuff_sw, cuff=0.0, plate=False, trim=None):
    """A fist: the back of the hand, curled fingers and a thumb, and a cuff
    flaring toward the elbow (a gauntlet's when `plate`)."""
    hh = H.BUILD["hand"] * 0.85
    hb = ["hand." + side.split(".")[-1]]
    wb = ["wrist." + side.split(".")[-1]]
    tube(m, [wr + ax * 0.02, wr + ax * 0.08 * hh, wr + ax * 0.13 * hh], [(0.045 * hh, 0.055 * hh), (0.052 * hh, 0.062 * hh), (0.046 * hh, 0.056 * hh)], sw, hb, fwd=(0, 0, 1), n=8)
    tube(m, [wr + ax * 0.12 * hh + [0, -0.008, 0], wr + ax * 0.18 * hh + [0, -0.028, 0]], [(0.042 * hh, 0.05 * hh), (0.032 * hh, 0.044 * hh)], sw if not plate else "steel_dark", hb, fwd=(0, 0, 1), n=8, smooth=False)
    tube(m, [wr + ax * 0.04 * hh + [0, -0.01, 0.045 * hh], wr + ax * 0.11 * hh + [0, -0.02, 0.07 * hh]], [0.022 * hh, 0.017 * hh], sw, hb, fwd=UP, n=6)
    if plate:
        band(m, wr + ax * 0.115 * hh, ax, (0, 0, 1), 0.05 * hh, 0.06 * hh, 0.016, trim, hb, n=8)
    if cuff:
        tube(m, [wr - ax * (0.06 + cuff * 0.3), wr + ax * 0.03], [(cuff + 0.018, cuff + 0.015), (0.062, 0.06)], cuff_sw, wb, fwd=UP, n=12, caps=(False, False))
        if trim:
            band(m, wr - ax * (0.058 + cuff * 0.3), ax, UP, cuff + 0.02, cuff + 0.017, 0.014, trim, wb, n=12)


def boot(m, ll, ft, side, sw):
    s = side.split(".")[-1]
    tube(m, [ft + (ll - ft) * 0.45, ft + (ll - ft) * 0.1], [(0.085, 0.088), (0.075, 0.08)], sw, ["lowerleg." + s], n=10, caps=(False, False))
    shoe(m, ft, s, sw, sw)


def shoe(m, ft, s, sw, toe_sw, trim=None, lames=False):
    """A shoe or a sabaton: heel and instep on the foot bone, toes on the toes."""
    heel = [(-0.11, 0.06, 0.12), (-0.04, 0.072, 0.15), (0.03, 0.075, 0.12)]
    toes_ = [(0.03, 0.073, 0.11), (0.1, 0.07, 0.085), (0.16, 0.062, 0.06), (0.21, 0.045, 0.04), (0.235, 0.02, 0.02)]
    for part, bones, psw in ((heel, ["foot." + s], sw), (toes_, ["toes." + s], toe_sw)):
        P = Part()
        rr = []
        for z, hw, h in part:
            cz = ft[2] + z
            rr.append([P.v((ft[0] + x, y, cz)) for x, y in ((-hw, 0.0), (hw, 0.0), (hw, h * 0.75), (hw * 0.6, h), (-hw * 0.6, h), (-hw, h * 0.75))])
        for k in range(len(rr) - 1):
            cc = np.mean([P.verts[i] for i in rr[k] + rr[k + 1]], axis=0)
            for i in range(6):
                q = [rr[k][i], rr[k][(i + 1) % 6], rr[k + 1][(i + 1) % 6], rr[k + 1][i]]
                P.f(q, psw if i != 0 else "black", want=np.mean([P.verts[t] for t in q], axis=0) - cc)
        for k, sg in ((0, -1), (len(rr) - 1, 1)):
            P.f(rr[k], psw, want=(0, 0, sg))
        P.to(m, bones, False)
    if lames and trim:
        for z in (0.03, 0.1, 0.16):
            band(m, (ft[0], 0.045, ft[2] + z), (0, 0.4, 1), UP, 0.074 - z * 0.06, 0.03, 0.012, trim, ["toes." + s] if z > 0.05 else ["foot." + s], n=8, a0=-90, a1=90)


# --- Helms ------------------------------------------------------------------------

def helm(k):
    S = SETS[k]
    m = H.Mesh()
    pl, tr = S["plate"], S["trim"]
    hb = ["head"]
    st = S["helm"]
    if st == "kettle":
        # A kettle hat: a rusty bowl and a broad brim, over the coif.
        bowl = [(0.24, 0.15, 0.16), (0.32, 0.148, 0.158), (0.38, 0.12, 0.13), (0.43, 0.07, 0.075), (0.455, 0.02, 0.02)]
        tube(m, [HC + [0, y, 0] for y, *_ in bowl], [(rx, rz) for _, rx, rz in bowl], pl, hb, n=14, caps=(True, True))
        tube(m, [HC + [0, 0.215, 0], HC + [0, 0.245, 0]], [(0.25, 0.26), (0.165, 0.175)], tr, hb, n=14, caps=(False, False), smooth=False)
        band(m, HC + [0, 0.33, 0], UP, (0, 0, 1), 0.152, 0.162, 0.03, "hide", hb, n=14)
        for a in range(0, 360, 60):
            r = math.radians(a)
            stud(m, HC + [0.152 * math.sin(r), 0.29, 0.162 * math.cos(r)], (math.sin(r), 0.2, math.cos(r)), 0.012, 0.012, tr, hb)
        return m, False
    if st in ("beaked", "winged"):
        hp = [(0.0, 0.098, 0.11, 1.0, 0.0), (0.05, 0.118, 0.13, 1.05, 0.04), (0.11, 0.13, 0.145, 1.1, 0.11),
              (0.17, 0.135, 0.15, 1.12, 0.13), (0.235, 0.137, 0.152, 1.06, 0.075), (0.29, 0.134, 0.15, 1.02, 0.03),
              (0.345, 0.118, 0.134, 1.0, 0.012), (0.395, 0.085, 0.1, 1.0, 0.0), (0.44 + (0.03 if st == "winged" else 0.0), 0.03, 0.04, 1.0, 0.0)]
        if st == "winged":
            hp = [(y, rx * 0.97, rz, f, p * 0.55) for y, rx, rz, f, p in hp]
        tube(m, [HC + [0, y, 0] for y, *_ in hp], [(rx, rz) for _, rx, rz, _, _ in hp], pl, hb, n=18,
             front=[p[3] for p in hp], point=[p[4] for p in hp])
        pt = 0.09 if st == "beaked" else 0.05
        band(m, HC + [0, 0.215, 0], UP, (0, 0, 1), 0.137, 0.156, 0.024, "black", hb, n=18, a0=-78, a1=78, front=1.08, point=pt)
        band(m, HC + [0, 0.24, 0], UP, (0, 0, 1), 0.139, 0.158, 0.014, tr, hb, n=18, a0=-80, a1=80, front=1.06, point=pt * 0.83)
        band(m, HC + [0, 0.012, 0], UP, (0, 0, 1), 0.106, 0.118, 0.022, tr, hb, n=18, front=1.02, point=0.008)
        crest = [HC + [0, 0.245, 0.2]] + [HC + [0, 0.2 + 0.212 * math.cos(math.radians(-80 + 170 * i / 8)), 0.155 * math.sin(-math.radians(-80 + 170 * i / 8))] for i in range(1, 9)]
        tube(m, crest, [(0.012, 0.028)] * len(crest), tr, hb, fwd=(1, 0, 0), n=4, smooth=False)
        if st == "beaked":
            tube(m, [HC + [0, 0.04, 0.17], HC + [0, 0.13, 0.295], HC + [0, 0.2, 0.27]], [0.012, 0.014, 0.012], tr, hb, fwd=(0, 0, 1), n=4, smooth=False)
        breaths(m, 0.15 * (1.13 if st == "beaked" else 1.1))
        if st == "winged":
            # A gold crown round the brow and swept wings.
            band(m, HC + [0, 0.31, 0], UP, (0, 0, 1), 0.138, 0.153, 0.04, tr, hb, n=18, front=1.0)
            for i in range(8):
                a = math.radians(i * 45)
                p = HC + [0.14 * math.sin(a), 0.33, 0.155 * math.cos(a)]
                stud(m, p, (math.sin(a) * 0.3, 1, math.cos(a) * 0.3), 0.022, 0.09 if i % 2 == 0 else 0.05, tr, hb, sides=4)
            for s in (1, -1):
                wing(m, HC + [s * 0.13, 0.25, -0.03], s, S["plate"], tr, hb)
        return m, True
    if st == "bascinet":
        # A round bascinet drawn to a point at the back, a visor with a slit
        # and breaths, and a mail aventail to the shoulders.
        hp = [(0.02, 0.12, 0.13, 1.0, 0.0), (0.1, 0.135, 0.145, 1.08, 0.03), (0.19, 0.14, 0.15, 1.1, 0.04), (0.27, 0.136, 0.148, 1.04, 0.02),
              (0.34, 0.118, 0.135, 1.0, 0.0), (0.4, 0.08, 0.1, 1.0, 0.0), (0.45, 0.025, 0.04, 1.0, 0.0)]
        tube(m, [HC + [0, y, -0.02 * (y > 0.3)] for y, *_ in hp], [(rx, rz) for _, rx, rz, _, _ in hp], pl, hb, n=16,
             front=[p[3] for p in hp], point=[p[4] for p in hp])
        band(m, HC + [0, 0.225, 0], UP, (0, 0, 1), 0.138, 0.152, 0.02, "black", hb, n=16, a0=-75, a1=75, front=1.1, point=0.035)
        band(m, HC + [0, 0.25, 0], UP, (0, 0, 1), 0.139, 0.153, 0.012, tr, hb, n=16, a0=-85, a1=85, front=1.08, point=0.03)
        breaths(m, 0.16)
        tube(m, [HC + [0, 0.04, 0], HC + [0, -0.03, 0], HC + [0, -0.08, 0]], [(0.125, 0.135), (0.2, 0.17), (0.26, 0.2)], S["mail"], hb + ["chest"], n=16, smooth=False, caps=(False, False))
        for s in (1, -1):
            stud(m, HC + [s * 0.138, 0.19, 0.0], (s, 0, 0), 0.02, 0.015, tr, hb)
        return m, True
    # Horned great helm: a flat-topped barrel with a cross of slits.
    hp = [(0.0, 0.13, 0.14), (0.1, 0.142, 0.152), (0.22, 0.145, 0.155), (0.33, 0.14, 0.15), (0.38, 0.13, 0.14), (0.4, 0.0, 0.0)]
    tube(m, [HC + [0, y, 0] for y, *_ in hp], [(rx, rz) for _, rx, rz in hp], pl, hb, n=16, front=1.05, caps=(True, False))
    band(m, HC + [0, 0.215, 0], UP, (0, 0, 1), 0.146, 0.157, 0.024, "black", hb, n=16, a0=-80, a1=80, front=1.06)
    tube(m, [HC + [0, 0.07, 0.16], HC + [0, 0.33, 0.16]], [(0.016, 0.01)] * 2, tr, hb, fwd=(0, 0, 1), n=4, smooth=False)
    band(m, HC + [0, 0.012, 0], UP, (0, 0, 1), 0.133, 0.143, 0.026, tr, hb, n=16, front=1.05)
    band(m, HC + [0, 0.37, 0], UP, (0, 0, 1), 0.133, 0.143, 0.022, tr, hb, n=16, front=1.05)
    breaths(m, 0.165)
    for s in (1, -1):
        horn = [HC + [s * 0.13, 0.3, 0.0], HC + [s * 0.22, 0.36, -0.02], HC + [s * 0.28, 0.48, 0.0], HC + [s * 0.27, 0.6, 0.06]]
        tube(m, horn, [0.045, 0.035, 0.022, 0.0], [pl, pl, tr], hb, fwd=(0, 0, 1), n=6, smooth=True, caps=(True, False))
    for i in range(5):
        stud(m, HC + [(-0.08 + 0.04 * i), 0.4, 0.0], (0, 1, 0), 0.018, 0.06, tr, hb, sides=4)
    return m, True


def breaths(m, z):
    for s in (1, -1):
        for k in range(3):
            y = 0.08 + k * 0.035
            a = math.radians(32 * s)
            p = HC + [0.13 * math.sin(a), y, z * math.cos(a)]
            tube(m, [p - [0.0, 0.0, 0.004], p + [0, 0, 0.006]], [(0.022, 0.006)] * 2, "black", ["head"], fwd=(0, 1, 0), n=4, smooth=False)


def wing(m, at, s, sw, tr, bones):
    """A swept wing of three feathers on the side of a helm."""
    for i, (ln, up) in enumerate(((0.2, 0.2), (0.24, 0.12), (0.2, 0.04))):
        rows = []
        for hgt in (0.035, -0.035):
            row = []
            for c in range(5):
                t = c / 4
                row.append(np.array(at) + [s * (0.02 + 0.08 * t), up * t + hgt * (1 - t) - i * 0.04, -ln * t])
            rows.append(row if s > 0 else row[::-1])
        sheet(m, rows, sw if i else tr, bones, th=0.012, smooth=False)


# --- Chest: torso, arms, cape ----------------------------------------------------------

def chest(k):
    S = SETS[k]
    m = H.Mesh()
    pl, tr, ml = S["plate"], S["trim"], S["mail"]
    C, SP = ["chest"], ["spine"]
    # Mail shirt under it all, so no gap shows at the waist or the arms.
    prof = [(1.04, 0.25, 0.168), (1.2, 0.238, 0.158), (1.4, 0.255, 0.165), (1.6, 0.27, 0.17), (1.74, 0.24, 0.152), (1.8, 0.14, 0.11)]
    tube(m, [(0, y, 0) for y, *_ in prof], [(rx, rz) for _, rx, rz in prof], ml, ["hips", "spine", "chest"], n=14, smooth=False)
    if k == 0:
        # A breastplate on straps over the mail, and a hide mantle.
        shell(m, [(0, 1.38, 0), (0, 1.52, 0), (0, 1.66, 0)], [(0.26, 0.178), (0.285, 0.19), (0.27, 0.18)], -62, 62, pl, C, n=10, edge=tr, front=1.1, point=0.03)
        for s in (1, -1):
            tube(m, [(s * 0.15, 1.66, 0.19), (s * 0.17, 1.8, 0.0), (s * 0.15, 1.66, -0.18)], [(0.03, 0.008)] * 3, "hide", C, fwd=(1, 0, 0), n=4, smooth=False, caps=(False, False))
        cy = [(1.64, 0.31, 0.21, 0.05, 0.02), (1.72, 0.27, 0.19, 0.05, 0.0), (1.79, 0.18, 0.14, 0.04, 0.0)]
        tube(m, [(0, y, 0) for y, *_ in cy], [(rx, rz) for _, rx, rz, _, _ in cy], "fur", C, n=16, fold=[c[3] for c in cy], folds=9, caps=(False, False))
    else:
        prof = [(1.37, 0.245, 0.165, 1.05, 0.015), (1.47, 0.27, 0.178, 1.12, 0.035), (1.57, 0.29, 0.185, 1.16, 0.045),
                (1.67, 0.29, 0.18, 1.1, 0.035), (1.74, 0.245, 0.155, 1.0, 0.015), (1.79, 0.15, 0.115, 1.0, 0.0)]
        tube(m, [(0, y, 0) for y, *_ in prof], [(rx, rz) for _, rx, rz, _, _ in prof], pl, C, n=18, front=[p[3] for p in prof], point=[p[4] for p in prof])
        band(m, (0, 1.745, 0), UP, (0, 0, 1), 0.25, 0.16, 0.025, tr, C, n=18, a0=-80, a1=80)
        band(m, (0, 1.385, 0), UP, (0, 0, 1), 0.25, 0.168, 0.022, tr, C, n=18, front=1.06, point=0.017)
        for i in range(S["lames"]):
            top = 1.40 - i * 0.085
            r0 = 0.24 - 0.004 * i
            tube(m, [(0, top - 0.1, 0), (0, top, 0)], [(r0 + 0.012, 0.168), (r0, 0.16)], pl, SP, n=18, front=1.05, point=0.012, caps=(False, False))
            band(m, (0, top - 0.092, 0), UP, (0, 0, 1), r0 + 0.015, 0.171, 0.014, tr, SP, n=18, front=1.05, point=0.012)
        if k >= 2:
            for s in (1, -1):
                for y in (1.47, 1.56, 1.65):
                    a = math.radians(62)
                    stud(m, (s * 0.27 * math.sin(a), y, 0.185 * 1.12 * math.cos(a)), (s * 0.8, 0, 0.6), 0.012, 0.012, tr, C)
        em = S["emblem"]
        if em == "star":
            star(m, (0, 1.6, 0.255), (0, 0.15, 1), UP, 0.1, tr, C, pts=4, th=0.018)
            star(m, (0, 1.6, 0.262), (0, 0.15, 1), UP, 0.05, "white", C, pts=4, th=0.02)
        elif em == "fang":
            # A raised keel and a blood-red stone.
            tube(m, [(0, 1.4, 0.235), (0, 1.57, 0.262), (0, 1.72, 0.22)], [(0.02, 0.012)] * 3, tr, C, fwd=(0, 0, 1), n=4, smooth=False)
            star(m, (0, 1.6, 0.26), (0, 0.15, 1), UP, 0.06, "red", C, pts=3, th=0.022)
        elif em == "sun":
            star(m, (0, 1.6, 0.255), (0, 0.15, 1), UP, 0.13, tr, C, pts=8, th=0.016)
            star(m, (0, 1.6, 0.264), (0, 0.15, 1), UP, 0.05, "white", C, pts=6, th=0.02)
    if S["cowl"]:
        cy = [(1.64, 0.32, 0.235, 0.07, 0.16), (1.72, 0.29, 0.215, 0.07, 0.1), (1.79, 0.21, 0.17, 0.06, 0.05), (1.845, 0.14, 0.135, 0.04, 0.0)]
        tube(m, [(0, y, 0) for y, *_ in cy], [(rx, rz) for _, rx, rz, _, _ in cy], S["cloth"], C, n=20, fold=[c[3] for c in cy], dip=[c[4] for c in cy], caps=(False, True))
    if S["cape"]:
        cape(m, S["cape"], S["hem"], torn=0.13 if k < 4 else 0.04, seed=11 + k, long=k >= 3)
    for s, side in ((1, "l"), (-1, "r")):
        arm(m, S, k, s, side)
    return m


def cape(m, sw, hem, torn, seed, long):
    R, C = 10, 15
    jag = jagged(C, torn, seed)
    bottom = 0.22 if long else 0.32
    rows = []
    for r in range(R):
        t = r / (R - 1)
        y = 1.74 - t * (1.74 - bottom)
        w = 0.27 + 0.16 * t
        zc = -0.17 - 0.16 * t
        row = []
        for c in range(C):
            u = -1 + 2 * c / (C - 1)
            a = u * math.radians(70)
            z = zc - 0.08 * math.cos(a) * (1 - 0.3 * t) + (0.012 + 0.045 * t) * math.sin(c * math.pi * 0.5)
            row.append((-w * math.sin(a), y - (jag[c] if r == R - 1 else 0.0), z))
        rows.append(row)
    sheet(m, rows, sw, ["chest", "spine", "hips"], th=0.016, edge=hem)


def arm(m, S, k, s, side):
    pl, tr, ml = S["plate"], S["trim"], S["mail"]
    ua, la, wr = J("upperarm." + side), J("lowerarm." + side), J("wrist." + side)
    ax = np.array([s, 0, 0.0])
    ub, lb = ["upperarm." + side], ["lowerarm." + side]
    # Mail sleeve to the elbow.
    tube(m, [ua - ax * 0.02, la - ax * 0.02], [(0.09, 0.085), (0.075, 0.072)], ml, ub, fwd=UP, n=10, smooth=False)
    st = S["paul"]
    if st == "leather":
        shell(m, [ua + ax * t for t in (-0.06, 0.02, 0.12)], [(0.12, 0.115), (0.15, 0.142), (0.14, 0.133)], -100, 100, "hide", ub, fwd=UP, n=10, edge="hide", th=0.02, smooth=False)
        stud(m, ua + ax * 0.04 + [0, 0.15, 0], (0, 1, 0), 0.015, 0.012, tr, ub)
        # Leather bracers and gloves.
        tube(m, [la + ax * 0.05, wr - ax * 0.02], [(0.075, 0.073), (0.064, 0.062)], "hide", lb, fwd=UP, n=10, smooth=False)
        glove(m, wr, ax, side, "hide", "hide")
        return
    dome = [(-0.1, 0.07), (-0.06, 0.15), (0.0, 0.19), (0.07, 0.205), (0.13, 0.2)]
    g = 0.88 if st == "plain" else 1.0
    shell(m, [ua + ax * t * g for t, _ in dome], [(r * g, r * 0.95 * g) for _, r in dome], -112, 112, pl, ub, fwd=UP, n=14, edge=tr, th=0.02)
    band(m, ua + ax * 0.125 * g, ax, UP, 0.205 * g, 0.195 * g, 0.022, tr, ub, n=14, a0=-112, a1=112)
    for i in range(1 if st == "plain" else 3):
        t0 = 0.12 + i * 0.055
        r0 = (0.195 - i * 0.014) * g
        shell(m, [ua + ax * t0, ua + ax * (t0 + 0.075)], [(r0, r0 * 0.95), (r0 - 0.004, r0 * 0.95 - 0.004)], -100, 100, pl, ub, fwd=UP, n=12, edge=tr, th=0.016)
    if st in ("layered", "winged", "spiked"):
        # A flange curling up off the inner edge, to guard the neck.
        rows = []
        tall = 0.12 if st == "winged" else 0.085
        for hgt in (tall, 0.0):
            row = []
            for c in range(7):
                zz = -0.15 + 0.3 * c / 6
                ys = math.sqrt(max(0.175 ** 2 - zz ** 2, 0.0))
                row.append(ua + ax * (-0.035 - hgt * 0.35) + [0, ys + hgt * (1 - (zz / 0.17) ** 2 * 0.5), zz])
            rows.append(row)
        sheet(m, rows, tr, ub, th=0.014, smooth=False)
    if st == "spiked":
        for i, zz in enumerate((-0.08, 0.0, 0.08)):
            stud(m, ua + ax * 0.06 + [0, 0.19 - abs(zz) * 0.3, zz], (s * 0.3, 1, zz * 2), 0.03, 0.13 + 0.04 * (i == 1), tr, ub, sides=5)
    else:
        stud(m, ua + ax * 0.04 * g + [0, 0.205 * g, 0], (s * 0.2, 1, 0), 0.016, 0.02, tr, ub)
    # Rerebrace, couter, vambrace and gauntlet.
    tube(m, [la - ax * 0.17, la - ax * 0.03], [(0.088, 0.083), (0.08, 0.077)], pl, ub, fwd=UP, n=12, caps=(False, False))
    tube(m, [la + [0, 0, -0.03], la + [0, 0, -0.1], la + [0, 0, -0.125]], [0.07, 0.05, 0.0], pl, lb, fwd=UP, n=10, caps=(False, False))
    band(m, la + [0, 0, -0.035], (0, 0, -1), UP, 0.072, 0.072, 0.014, tr, lb, n=10)
    if S["spikes"]:
        stud(m, la + [0, 0, -0.12], (0, 0, -1), 0.025, 0.09, tr, lb)
    tube(m, [la + ax * 0.03, wr - ax * 0.03], [(0.077, 0.075), (0.062, 0.06)], pl, lb, fwd=UP, n=12, front=1.05, point=0.01)
    band(m, la + ax * 0.04, ax, UP, 0.079, 0.077, 0.016, tr, lb, n=12)
    glove(m, wr, ax, side, pl, pl, cuff=0.07, plate=True, trim=tr)


# --- Legs: belt, tabard, legs, feet --------------------------------------------------------

def legs(k):
    S = SETS[k]
    m = H.Mesh()
    pl, tr, ml = S["plate"], S["trim"], S["mail"]
    HB = ["hips"]
    tube(m, [(0, 0.86, 0), (0, 1.06, 0)], [(0.25, 0.17), (0.245, 0.165)], ml, HB, n=16, smooth=False, caps=(True, False))
    tube(m, [(0, 1.05, 0), (0, 1.115, 0)], [(0.255, 0.175)] * 2, "leather" if k < 4 else "hide", HB, n=18, front=1.04, caps=(False, False), smooth=False)
    if k == 0:
        star(m, (0, 1.083, 0.183), (0, 0, 1), UP, 0.035, "rust", HB, pts=2, th=0.014)
        # A pouch on the belt.
        tube(m, [(0.17, 1.0, 0.13), (0.17, 1.1, 0.13)], [(0.05, 0.035)] * 2, "hide", HB, fwd=(0, 0, 1), n=6, smooth=False)
    else:
        star(m, (0, 1.083, 0.186), (0, 0, 1), UP, 0.055, S["gold"] if k != 2 else "agold", HB, pts=4, th=0.014)
        for a0, a1 in ((-62, 62), (118, 242)):
            shell(m, [(0, 0.95, 0), (0, 1.05, 0)], [(0.275, 0.19), (0.262, 0.18)], a0, a1, pl, HB, n=10, edge=tr)
    if S["tabard"]:
        tabard(m, S, k)
    for s, side in ((1, "l"), (-1, "r")):
        leg(m, S, k, s, side)
    return m


def tabard(m, S, k):
    bones = ["hips", "upperleg.l", "upperleg.r"]
    for zs in (1, -1):
        rows = []
        R, C = 7, 6
        jag = jagged(C, 0.07 if k < 4 else 0.02, 3 if zs > 0 else 5)
        for r in range(R):
            y = 1.04 - r * (1.04 - 0.42) / (R - 1)
            w = 0.12 + 0.02 * r / (R - 1)
            z = zs * (0.2 + 0.02 * r / (R - 1))
            row = []
            for c in range(C):
                x = -w + 2 * w * c / (C - 1)
                row.append((x * zs, y - (jag[c] if r == R - 1 else 0.0), z + zs * 0.012 * math.sin(c * 1.7 + r)))
            rows.append(row)
        sheet(m, rows, S["tabard"], bones, edge=S["hem"])
        z0 = zs * 0.218
        if S["emblem"] == "cross":
            tube(m, [(0, 0.98, z0), (0, 0.6, z0 + zs * 0.015)], [(0.022, 0.006)] * 2, S["trim"], bones, fwd=(0, 0, zs), n=4, smooth=False)
            tube(m, [(-0.09, 0.87, z0 + zs * 0.004), (0.09, 0.87, z0 + zs * 0.004)], [(0.022, 0.006)] * 2, S["trim"], bones, fwd=(0, 0, zs), n=4, smooth=False)
        elif S["emblem"] == "sun" and zs > 0:
            star(m, (0, 0.82, z0 + 0.008), (0, 0, 1), UP, 0.08, S["gold"], bones, pts=8, th=0.012)
        else:
            for r in range(1, 5):
                for x in (-0.07, 0.07):
                    y = 1.0 - r * 0.1
                    stud(m, (x, y, zs * (0.215 + 0.02 * (1.04 - y) / 0.62)), (0, 0, zs), 0.01, 0.01, S["trim"], bones)


def leg(m, S, k, s, side):
    pl, tr, ml = S["plate"], S["trim"], S["mail"]
    ul, ll, ft = J("upperleg." + side), J("lowerleg." + side), J("foot." + side)
    top = ul + [-0.03 * s, -0.04, 0]
    ulb, llb = ["upperleg." + side], ["lowerleg." + side]
    tube(m, [top, top + (ll - top) * 0.5, ll + [0, 0.05, 0]], [(0.118, 0.122), (0.105, 0.11), (0.088, 0.092)], ml, ulb, fwd=(0, 0, 1), n=10, smooth=False)
    tube(m, [ll + [0, 0.06, 0], ll + (ft - ll) * 0.5], [(0.088, 0.092), (0.082, 0.085)], ml, llb, fwd=(0, 0, 1), n=10, smooth=False)
    if k == 0:
        # Mail chausses with leather knee cops, and boots.
        tube(m, [ll + [0, 0, 0.05], ll + [0, 0, 0.11]], [(0.075, 0.07), (0.05, 0.045)], "hide", llb, fwd=UP, n=8, smooth=False)
        boot(m, ll, ft, side, "hide")
        return
    shell(m, [top + [0, -0.02, 0], top + (ll - top) * 0.5, ll + [0, 0.07, 0]], [(0.128, 0.132), (0.116, 0.12), (0.098, 0.102)], -105, 105, pl, ulb, fwd=(0, 0, 1), n=12, edge=tr, front=1.05, point=0.01)
    if k >= 2:
        for i in range(3):
            y0 = 1.03 - i * 0.075
            r0 = 0.15 - i * 0.006
            shell(m, [ul + [0, y0 - ul[1] - 0.09, 0], ul + [0, y0 - ul[1], 0]], [(r0 + 0.01, r0 + 0.014), (r0, r0 + 0.004)], -115 * s if s < 0 else -30, 30 if s < 0 else 115,
                  pl, ulb, fwd=(0, 0, 1), n=9, edge=tr, th=0.016)
    tube(m, [ll + [0, 0, 0.04], ll + [0, 0, 0.1], ll + [0, 0, 0.125]], [(0.085, 0.075), (0.07, 0.06), (0.0, 0.0)], pl, llb, fwd=UP, n=10, caps=(False, False))
    band(m, ll + [0, 0, 0.045], (0, 0, 1), UP, 0.088, 0.078, 0.016, tr, llb, n=10)
    stud(m, ll + [0, 0, 0.122], (0, 0, 1), 0.016 if not S["spikes"] else 0.026, 0.03 if not S["spikes"] else 0.1, tr, llb)
    g0, g1 = ll + (ft - ll) * 0.08, ft + (ll - ft) * 0.08
    tube(m, [g0, g0 + (g1 - g0) * 0.35, g1], [(0.088, 0.09), (0.09, 0.094), (0.072, 0.075)], pl, llb, fwd=(0, 0, 1), n=12, front=1.08, point=0.02, caps=(False, False))
    band(m, g1 + (g0 - g1) * 0.02, g1 - g0, (0, 0, 1), 0.076, 0.079, 0.016, tr, llb, n=12, front=1.08, point=0.018)
    shoe(m, ft, side.split(".")[-1], pl, pl, trim=tr, lames=True)


# --- Writing ---------------------------------------------------------------------------

def out(name):
    return os.path.join(H.ROOT, "assets", "kaykit", "characters", name + ".glb")


if __name__ == "__main__":
    g, nodes, joints, _ = H.skeleton()
    ks = [int(a) for a in sys.argv[1:]] or list(range(len(SETS)))
    us = undersuit()
    H.write(None, SK, g, nodes, joints, "DarkKnight", out("DarkKnight"), meshes=[("DarkKnight_" + n, mm) for n, mm in us.items()], image=IMAGE)
    for k in ks:
        hm, _closed = helm(k)
        for slot, mm in (("Helm", hm), ("Chest", chest(k)), ("Legs", legs(k))):
            nm = "DarkKnight_%s%d" % (slot, k)
            H.write(None, SK, g, nodes, joints, nm, out(nm), meshes=[(nm + "_Mesh", mm)], image=IMAGE)
    print("LIFT", round(H.body_lift(), 4))
