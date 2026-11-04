"""The Barrow's foes in the dark plate style (the rest of the dead: Risen Bones
and Gravemaw, are in make_dark_dead.py). Every one is the hero skeleton under
bones and a skull, so the baked clips play on them unchanged, and each has its
own outline from the hunt camera:

- DarkDead_Guard: Barrow Guard. A kettle hat, the Warden's black plate and a
  wine tabard; he carries the big shield.
- DarkDead_Stalker: Crypt Stalker. Hooded, a long ragged cloak, a bandolier.
- DarkDead_Hexer: Bone Hexer. A pointed hat, a violet gown, bell sleeves.
- DarkDead_Caller: Grave Caller. A black cowl, a collar of bone spikes, a green hem.
- DarkDead_Hound: Grave Hound. A long jaw and a bone ridge down the back, bare ribs.
- DarkDead_Brute: Bone Brute. Horned skull, fur mantle, spiked pauldrons, chained skulls.
- DarkDead_Bomber: Pumpkin Bomber. A wrapped head and a pumpkin strapped to the belly.
- DarkDead_Robber: Grave Robber. A floppy hat, a scarf over the jaw, a ragged coat.

    python3 tools/art/make_dark_dead.py   (writes these with the first two)
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_hero_body as H  # noqa: E402
import make_dark_knight as K  # noqa: E402
import make_dark_dead as D  # noqa: E402
from dark_kit import UP, tube, shell, band, stud, sheet, jagged  # noqa: E402

J, HC = K.J, K.HC
BONE, DARK = "stone", "black"


# --- Shared pieces -------------------------------------------------------------------------

def hood(m, sw, trim=None, height=0.52, open_deg=52, tip=0.0):
    """A hood round the head, open at the face, with a collar over the shoulders."""
    hp = [(-0.03, 0.15, 0.16), (0.06, 0.17, 0.18), (0.17, 0.178, 0.186), (0.27, 0.168, 0.176), (0.36, 0.14, 0.15), (0.44, 0.09, 0.1),
          (height, 0.02 + tip, 0.03)]
    shell(m, [HC + [0, y, -0.015] for y, *_ in hp], [(rx, rz) for _, rx, rz in hp], open_deg, 360 - open_deg, sw, ["head"], n=14, th=0.022, smooth=False, inner="black")
    if trim:
        band(m, HC + [0, 0.0, -0.015], UP, (0, 0, 1), 0.152, 0.162, 0.02, trim, ["head"], n=14, a0=open_deg, a1=360 - open_deg)
    tube(m, [HC + [0, 0.04, 0], HC + [0, -0.04, 0], HC + [0, -0.12, 0]], [(0.15, 0.16), (0.23, 0.2), (0.3, 0.23)], sw, ["head", "chest"], n=14, smooth=False, caps=(False, False))


def sleeves(m, sw, hem, bell=0.13, drop=0.0):
    """Long sleeves to the wrist, flaring to a bell; `drop` hangs a rag from the cuff."""
    for s, side in ((1, "l"), (-1, "r")):
        ua, la, wr = J("upperarm." + side), J("lowerarm." + side), J("wrist." + side)
        ax = np.array([s, 0, 0.0])
        tube(m, [ua - ax * 0.03, ua + (la - ua) * 0.5, la, la + (wr - la) * 0.6, wr - ax * 0.01], [(0.1, 0.1), (0.09, 0.09), (0.082, 0.08), (0.095, 0.092), (bell, bell * 0.95)],
             sw, ["chest", "upperarm." + side, "lowerarm." + side], fwd=UP, n=10, caps=(True, False), smooth=False)
        band(m, wr - ax * 0.01, ax, UP, bell + 0.006, bell * 0.95 + 0.006, 0.02, hem, ["lowerarm." + side], n=10)


def gown(m, sw, hem, top=1.8, bottom=0.2, belly=1.0):
    """A torso and a long skirt, folded, from the collar to just above the ground."""
    T = ["hips", "spine", "chest"]
    prof = [(1.0, 0.235, 0.16), (1.2, 0.225, 0.15), (1.4, 0.24, 0.158), (1.6, 0.26, 0.165), (1.72, 0.25, 0.15), (top, 0.15, 0.115)]
    tube(m, [(0, y, 0) for y, *_ in prof], [(rx * belly, rz) for _, rx, rz in prof], sw, T, n=14, front=1.04, smooth=False)
    pts = [(0, 1.06, 0), (0, 0.8, 0), (0, 0.5, 0), (0, bottom, 0)]
    rad = [(0.25, 0.18), (0.29, 0.22), (0.33, 0.27), (0.38, 0.32)]
    tube(m, pts, rad, sw, ["hips", "upperleg.l", "upperleg.r"], n=16, fold=[0.02, 0.05, 0.07, 0.09], folds=8, caps=(False, False), smooth=False)
    band(m, (0, bottom + 0.01, 0), UP, (0, 0, 1), 0.385, 0.325, 0.025, hem, ["hips", "upperleg.l", "upperleg.r"], n=16)
    band(m, (0, 1.06, 0), UP, (0, 0, 1), 0.258, 0.178, 0.05, "hide", ["hips"], n=16, front=1.04)


def horn(m, at, s, length=0.3, sw=BONE, curl=0.12, bones=("head",)):
    pts = [at, at + [s * 0.08, 0.05, 0], at + [s * (0.13 + curl), 0.15, 0.02], at + [s * (0.12 + curl), 0.28 * length / 0.3 + 0.1, 0.1]]
    tube(m, pts, [0.04, 0.032, 0.02, 0.0], sw, list(bones), n=6, caps=(True, False))


def pauldron(m, s, side, sw, trim, spikes=3, big=1.0, spike_sw=BONE):
    ua = J("upperarm." + side)
    ax = np.array([s, 0, 0.0])
    g = big
    dome = [(-0.1, 0.07), (-0.06, 0.15), (0.0, 0.19), (0.07, 0.205), (0.13, 0.2)]
    shell(m, [ua + ax * t * g for t, _ in dome], [(r * g, r * 0.95 * g) for _, r in dome], -112, 112, sw, ["upperarm." + side], fwd=UP, n=12, edge=trim, th=0.022)
    band(m, ua + ax * 0.125 * g, ax, UP, 0.205 * g, 0.195 * g, 0.022, trim, ["upperarm." + side], n=12, a0=-112, a1=112)
    for i in range(spikes):
        zz = (i - (spikes - 1) / 2) * 0.09
        stud(m, ua + ax * 0.06 * g + [0, 0.19 * g - abs(zz) * 0.3, zz], (s * 0.3, 1, zz * 2), 0.032 * g, (0.12 + 0.05 * (i == spikes // 2)) * g, spike_sw, ["upperarm." + side], sides=5)


def charm(m, c, sw, bones, r=0.04):
    c = np.array(c, float)
    """A little hanging skull: a faceted ball with two dark sockets."""
    tube(m, [c + [0, -r, 0], c + [0, 0.0, 0], c + [0, r * 0.9, 0]], [(r * 0.7, r * 0.7), (r, r), (r * 0.6, r * 0.6)], sw, bones, n=6, smooth=False)
    for s in (1, -1):
        stud(m, c + [s * r * 0.4, 0.0, r * 0.8], (0, 0, 1), 0.012, 0.01, DARK, bones, sides=3)


def belt(m, sw="hide", bones=("hips",), y=1.04):
    band(m, (0, y, 0), UP, (0, 0, 1), 0.255, 0.175, 0.07, sw, list(bones), n=16, front=1.04)
    stud(m, (0, y, 0.184), (0, 0, 1), 0.035, 0.02, "agold", list(bones), sides=4)


# --- The foes ------------------------------------------------------------------------------

def guard():
    m = H.Mesh()
    D.bones(m, ribs=False)
    D.skull(m)
    helm, _ = K.helm(0)
    return [("DarkDead_Guard_Body", m), ("DarkDead_Guard_Helm", helm), ("DarkDead_Guard_Chest", K.chest(1)), ("DarkDead_Guard_Legs", K.legs(1))]


def stalker():
    m = H.Mesh()
    D.bones(m, ribs=False)
    D.skull(m)
    hood(m, "cloth", trim="hide", height=0.5, tip=0.03)
    # A ragged cloak behind, leather straps across a bare ribcage, a belt of pouches.
    K.cape(m, "cloth", "black", torn=0.16, seed=21, long=True)
    for y in (1.27, 1.39, 1.51, 1.63):
        w = 0.19 + 0.05 * (1 - abs(y - 1.47) / 0.25)
        band(m, (0, y, -0.01), UP, (0, 0, 1), w + 0.012, w * 0.7 + 0.012, 0.035, BONE, ["chest"], n=12, a0=20, a1=340)
    for s in (1, -1):
        tube(m, [(s * 0.2, 1.7, 0.06), (0.0, 1.45, 0.2), (-s * 0.2, 1.12, 0.1)], [(0.03, 0.012)] * 3, "hide", ["chest", "spine"], fwd=(0, 0, 1), n=4, smooth=False, caps=(True, True))
    belt(m, "hide")
    for x in (0.17, -0.17):
        tube(m, [(x, 0.93, 0.1), (x, 1.04, 0.1)], [(0.05, 0.035)] * 2, "hide", ["hips"], fwd=(0, 0, 1), n=6, smooth=False)
    # Scrap boots-wraps, rag at the knees.
    for side in ("l", "r"):
        ll = J("lowerleg." + side)
        band(m, ll + [0, 0.05, 0], UP, (0, 0, 1), 0.075, 0.075, 0.05, "cloth", ["lowerleg." + side], n=8)
    return [("DarkDead_Stalker_Body", m)]


def hexer():
    m = H.Mesh()
    D.bones(m, ribs=False)
    D.skull(m)
    gown(m, "violet", "wine", top=1.82, bottom=0.18)
    sleeves(m, "violet", "wine", bell=0.14)
    # A broad brim and a tall bent cone of a hat.
    hb = ["head"]
    tube(m, [HC + [0, 0.22, 0], HC + [0, 0.25, 0]], [(0.3, 0.3), (0.17, 0.175)], "wine", hb, n=14, caps=(False, False), smooth=False)
    cone = [(0.24, 0.165, 0.17), (0.34, 0.14, 0.145), (0.46, 0.105, 0.11), (0.6, 0.065, 0.07), (0.74, 0.03, 0.035), (0.84, 0.0, 0.0)]
    tube(m, [HC + [0, y, -0.02 * ((y - 0.24) / 0.6) ** 2 * 3] for y, *_ in cone], [(rx, rz) for _, rx, rz in cone], "violet", hb, n=12, smooth=False)
    band(m, HC + [0, 0.3, 0], UP, (0, 0, 1), 0.17, 0.178, 0.04, "agold", hb, n=12)
    stud(m, HC + [0, 0.3, 0.19], (0, 0, 1), 0.04, 0.03, "ember", hb, sides=4)
    charm(m, J("chest") + [0.0, 0.0, 0.2], BONE, ["chest"], 0.05)
    return [("DarkDead_Hexer_Body", m)]


def caller():
    m = H.Mesh()
    D.bones(m, ribs=False)
    D.skull(m)
    gown(m, "cloth", "moss", top=1.82, bottom=0.14)
    sleeves(m, "cloth", "moss", bell=0.15)
    hood(m, "cloth", trim="moss", height=0.6, open_deg=46, tip=0.0)
    # A collar of bone spikes round the shoulders, and a skull at the belt.
    ch = J("chest")
    for k in range(10):
        a = math.radians(k * 36 + 18)
        p = ch + [0.27 * math.sin(a), 0.27, 0.2 * math.cos(a) - 0.02]
        stud(m, p, (math.sin(a) * 1.0, 0.9, math.cos(a) * 0.7), 0.04, 0.2 if k % 2 == 0 else 0.13, BONE, ["chest"], sides=4)
    belt(m, "moss")
    charm(m, (0.0, 0.9, 0.24), BONE, ["hips"], 0.07)
    charm(m, (0.2, 0.92, 0.18), BONE, ["hips"], 0.045)
    charm(m, (-0.2, 0.92, 0.18), BONE, ["hips"], 0.045)
    return [("DarkDead_Caller_Body", m)]


def hound():
    m = H.Mesh()
    D.bones(m)
    hb = ["head"]
    # A big, low wolf's skull thrust forward on a hunched neck: long jaw, fangs, ember eyes.
    k = 1.35
    G = lambda x, y, z: HC + np.array([0.0, -0.07, 0.15]) + k * np.array([x, y, z])  # noqa: E731
    prof = [(0.05, 0.09, 0.11), (0.12, 0.115, 0.14), (0.2, 0.12, 0.15), (0.29, 0.1, 0.12), (0.35, 0.06, 0.07), (0.38, 0.02, 0.03)]
    tube(m, [G(0, y, -0.03) for y, *_ in prof], [(rx * k, rz * k) for _, rx, rz in prof], BONE, hb, n=10, front=1.1)
    tube(m, [G(0, 0.17, 0.05), G(0, 0.145, 0.2), G(0, 0.14, 0.34)], [(0.075 * k, 0.07 * k), (0.06 * k, 0.06 * k), (0.035 * k, 0.035 * k)], BONE, hb, fwd=UP, n=8)
    tube(m, [G(0, 0.08, 0.05), G(0, 0.04, 0.2), G(0, 0.06, 0.32)], [(0.065 * k, 0.06 * k), (0.05 * k, 0.05 * k), (0.03 * k, 0.03 * k)], BONE, hb, fwd=UP, n=8)
    for s in (1, -1):
        tube(m, [G(0.05 * s, 0.205, 0.07), G(0.052 * s, 0.205, 0.1)], [(0.034 * k, 0.028 * k), (0.03 * k, 0.025 * k)], DARK, hb, n=6)
        stud(m, G(0.052 * s, 0.205, 0.095), (0, 0, 1), 0.02, 0.014, "gold", hb, sides=5)
        for fz in (0.24, 0.31):
            stud(m, G(0.045 * s, 0.1, fz), (0, -1, 0.2), 0.014, 0.1, "white", hb, sides=4)
        stud(m, G(0.09 * s, 0.34, -0.05), (s * 0.3, 1, -0.2), 0.05, 0.22, BONE, hb, sides=4)
    # The neck: a short bone column from the shoulders to the skull, and a ruff of spikes round it.
    tube(m, [J("chest") + [0, 0.18, 0.02], HC + [0, 0.02, 0.1]], [(0.07, 0.07), (0.08, 0.08)], BONE, ["chest", "head"], fwd=(0, 0, 1), n=6)
    for j in range(9):
        a = math.radians(j * 40)
        stud(m, J("chest") + [0.2 * math.sin(a), 0.22, 0.14 * math.cos(a)], (math.sin(a), 0.7, math.cos(a)), 0.035, 0.17, BONE, ["chest"], sides=4)
    # A ridge of bone spikes down the spine and ribs to the pelvis.
    for kk, y in enumerate(np.arange(1.0, 1.72, 0.07)):
        stud(m, (0, y, -0.12), (0, 0.6, -1), 0.034, 0.22 - 0.02 * (kk % 3), BONE, ["spine" if y < 1.25 else "chest"], sides=4)
    # Claws: long bone fingers on both hands.
    for s, side in ((1, "l"), (-1, "r")):
        wr = J("wrist." + side)
        ax = np.array([s, 0, 0.0])
        for dz in (-0.03, 0.0, 0.03):
            stud(m, wr + ax * 0.16 + [0, -0.03, dz], (s, -0.35, 0), 0.012, 0.13, "white", ["hand." + side], sides=3)
    # A tattered rag of hide at the loins and a studded collar.
    band(m, (0, 1.03, 0), UP, (0, 0, 1), 0.2, 0.16, 0.05, "hide", ["hips"], n=10)
    band(m, HC + [0, 0.0, 0.08], UP, (0, 0, 1), 0.12, 0.13, 0.05, "blood", hb, n=10)
    return [("DarkDead_Hound_Body", m)]


def brute():
    m = H.Mesh()
    D.bones(m)
    D.skull(m)
    hb = ["head"]
    for s in (1, -1):
        horn(m, HC + [s * 0.1, 0.27, 0.0], s, 0.42, BONE, 0.16)
    # A heavy brow plate and a bone jaw guard.
    band(m, HC + [0, 0.24, 0], UP, (0, 0, 1), 0.135, 0.15, 0.04, "iron", hb, n=10, a0=-90, a1=90)
    for s, side in ((1, "l"), (-1, "r")):
        pauldron(m, s, side, "iron", "rust", spikes=3, big=1.18, spike_sw="white")
    # A fur mantle over the shoulders and an iron breastplate strapped on.
    C = ["chest"]
    cy = [(1.62, 0.32, 0.22, 0.06, 0.02), (1.7, 0.29, 0.2, 0.06, 0.0), (1.78, 0.2, 0.15, 0.05, 0.0)]
    tube(m, [(0, y, 0) for y, *_ in cy], [(rx, rz) for _, rx, rz, _, _ in cy], "fur", C, n=16, fold=[c[3] for c in cy], folds=9, caps=(False, False))
    shell(m, [(0, 1.3, 0), (0, 1.44, 0), (0, 1.58, 0)], [(0.25, 0.185), (0.27, 0.195), (0.26, 0.19)], -64, 64, "iron", C, n=10, edge="rust", front=1.1, point=0.03)
    for y in (1.36, 1.46, 1.56):
        stud(m, (0, y, 0.215), (0, 0, 1), 0.02, 0.025, "rust", C)
    belt(m, "hide")
    # A kilt of hide strips and chained skulls hanging from the belt.
    for zs in (1, -1):
        jag = jagged(5, 0.09, 31 if zs > 0 else 33)
        rows = []
        for r in range(4):
            y = 1.04 - r * 0.14
            rows.append([(-0.15 + 0.075 * c, y - (jag[c] if r == 3 else 0.0), zs * (0.19 + 0.025 * r)) for c in range(5)])
        sheet(m, [[(x * zs, y, z) for x, y, z in row] for row in rows], "hide", ["hips", "upperleg.l", "upperleg.r"], edge="rust")
    charm(m, (0.2, 0.84, 0.18), BONE, ["hips"], 0.06)
    charm(m, (-0.2, 0.84, 0.18), BONE, ["hips"], 0.06)
    # Rusted bracers.
    for s, side in ((1, "l"), (-1, "r")):
        la, wr = J("lowerarm." + side), J("wrist." + side)
        tube(m, [la + (wr - la) * 0.2, wr - np.array([s, 0, 0]) * 0.02], [(0.075, 0.075), (0.065, 0.065)], "iron", ["lowerarm." + side], fwd=UP, n=8, smooth=False)
        band(m, la + (wr - la) * 0.25, (s, 0, 0), UP, 0.08, 0.08, 0.02, "rust", ["lowerarm." + side], n=8)
    return [("DarkDead_Brute_Body", m)]


def bomber():
    m = H.Mesh()
    D.bones(m)
    D.skull(m)
    hb = ["head"]
    # A wrap of scorched rag over the brow and a trailing knot.
    band(m, HC + [0, 0.26, 0], UP, (0, 0, 1), 0.135, 0.145, 0.08, "hide", hb, n=12)
    tube(m, [HC + [0, 0.3, -0.12], HC + [0, 0.22, -0.22], HC + [0.05, 0.1, -0.3]], [(0.04, 0.02), (0.035, 0.015), (0.0, 0.0)], "hide", hb, n=5, smooth=False)
    # A pumpkin strapped to the belly: lobes, a stalk, a cut mouth.
    C = ["spine", "hips"]
    cy = (0.0, 1.25, 0.22)
    for k in range(7):
        a = math.radians(k * 360 / 7)
        c0 = np.array(cy) + [0.2 * math.sin(a), 0.0, 0.17 * math.cos(a)]
        tube(m, [c0 + [0, -0.19, 0], c0 + [0, 0.0, 0], c0 + [0, 0.19, 0]], [(0.075, 0.075), (0.115, 0.11), (0.07, 0.07)], "ember", C, n=6, smooth=False)
    stud(m, np.array(cy) + [0, 0.19, 0], UP, 0.04, 0.1, "moss", C, sides=4)
    for dx, dy in ((-0.09, 0.04), (0.09, 0.04)):
        stud(m, np.array(cy) + [dx, dy, 0.31], (0, 0, 1), 0.04, 0.02, DARK, C, sides=3)
    band(m, np.array(cy) + [0, -0.06, 0.28], UP, (0, 0, 1), 0.07, 0.04, 0.03, DARK, C, n=8, a0=-60, a1=60)
    band(m, (0, 1.12, 0), UP, (0, 0, 1), 0.31, 0.27, 0.035, "hide", ["hips", "spine"], n=14)
    # Powder-keg bandolier across the chest.
    for k in range(4):
        t = k / 3
        tube(m, [(0.2 - 0.4 * t, 1.62 - 0.35 * t, 0.2), (0.2 - 0.4 * t, 1.62 - 0.35 * t - 0.12, 0.2)], [(0.035, 0.035)] * 2, "red", ["chest"], fwd=(0, 0, 1), n=6, smooth=False)
    band(m, (0, 1.03, 0), UP, (0, 0, 1), 0.2, 0.16, 0.04, "hide", ["hips"], n=10)
    return [("DarkDead_Bomber_Body", m)]


def robber():
    m = H.Mesh()
    D.bones(m, ribs=False)
    D.skull(m)
    hb = ["head"]
    # A floppy brimmed hat with a gold buckle, and a scarf over the jaw.
    tube(m, [HC + [0, 0.22, 0], HC + [0, 0.245, 0]], [(0.26, 0.27), (0.16, 0.17)], "wine", hb, n=12, caps=(False, False), smooth=False)
    cone = [(0.23, 0.155, 0.165), (0.32, 0.14, 0.15), (0.38, 0.1, 0.11), (0.41, 0.0, 0.0)]
    tube(m, [HC + [0, y, 0] for y, *_ in cone], [(rx, rz) for _, rx, rz in cone], "wine", hb, n=12, smooth=False)
    band(m, HC + [0, 0.29, 0], UP, (0, 0, 1), 0.158, 0.168, 0.04, "hide", hb, n=12)
    stud(m, HC + [0, 0.29, 0.168], (0, 0, 1), 0.03, 0.02, "agold", hb, sides=4)
    band(m, HC + [0, 0.07, 0.0], UP, (0, 0, 1), 0.1, 0.11, 0.07, "red", hb, n=10, a0=-130, a1=130)
    # A ragged coat with a high collar over a bare ribcage.
    T = ["hips", "spine", "chest"]
    prof = [(0.98, 0.25, 0.17), (1.18, 0.24, 0.16), (1.4, 0.255, 0.165), (1.6, 0.27, 0.17), (1.72, 0.25, 0.155)]
    tube(m, [(0, y, 0) for y, *_ in prof], [(rx, rz) for _, rx, rz in prof], "wine", T, n=14, front=1.03, smooth=False, caps=(False, False))
    for zs in (1, -1):
        jag = jagged(7, 0.1, 41 if zs > 0 else 43)
        rows = []
        for r in range(5):
            y = 1.0 - r * 0.13
            rows.append([((-0.2 + 0.067 * c) * zs, y - (jag[c] if r == 4 else 0.0), zs * (0.19 + 0.03 * r)) for c in range(7)])
        sheet(m, rows, "wine", ["hips", "upperleg.l", "upperleg.r"], edge="hide")
    belt(m, "hide")
    # Coin purses at the belt and a cheeky glint of gold on the sleeves.
    for x in (0.2, -0.2):
        tube(m, [(x, 0.9, 0.12), (x, 1.02, 0.12)], [(0.055, 0.04)] * 2, "agold", ["hips"], fwd=(0, 0, 1), n=6, smooth=False)
    for s, side in ((1, "l"), (-1, "r")):
        ua, la = J("upperarm." + side), J("lowerarm." + side)
        tube(m, [ua - np.array([s, 0, 0]) * 0.03, la], [(0.1, 0.1), (0.085, 0.085)], "wine", ["chest", "upperarm." + side], fwd=UP, n=8, smooth=False)
        band(m, la, (s, 0, 0), UP, 0.09, 0.09, 0.03, "agold", ["upperarm." + side, "lowerarm." + side], n=8)
    return [("DarkDead_Robber_Body", m)]


def all_models():
    return [("DarkDead_Guard", guard()), ("DarkDead_Stalker", stalker()), ("DarkDead_Hexer", hexer()), ("DarkDead_Caller", caller()),
            ("DarkDead_Hound", hound()), ("DarkDead_Brute", brute()), ("DarkDead_Bomber", bomber()), ("DarkDead_Robber", robber())]
