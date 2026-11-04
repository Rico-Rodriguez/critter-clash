"""The Gilded Vault's bosses and foes in the dark plate style, on the hero
skeleton, so the baked clips (Idle_A, Melee_*, Ranged_*, Skeletons_*...) play
on them unchanged. Each is one skinned mesh: the Knight's undersuit, a helm, a
chest and legs from make_dark_knight.py recolored in the Vault's gold, with the
treasure guard's livery (coins, keys, a vault-wheel halo) built over them.

    python3 tools/art/make_dark_vault.py [model ...]   (plain Python + numpy)

Writes into assets/kaykit/characters/:
- DarkVault_Warden.glb: the Gilded Warden, a towering jailer in gold plate
  with a ring of keys, a coin at the breast and a vault-wheel halo.
- DarkVault_Guard.glb: Gilded Guard (the warrior's role), black plate edged in
  gold, a wine tabard, a coin on the breast.
- DarkVault_Crossbowman.glb: Vault Crossbowman (the rogue's), a gilded kettle
  hat, a coin bandolier, light plate.
- DarkVault_Brute.glb: Vault Brute (the brute's), a horned gold great helm,
  spiked gold pauldrons, a wide coin belt.
- DarkVault_Hound.glb: Vault Hound (the hound's), a beaked gilded helm, a
  wine cowl and cape, a ring of keys.
The boss's key and vault-door arms are tools/art/make_warden.py's.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_hero_body as H  # noqa: E402
import make_dark_knight as K  # noqa: E402
from dark_kit import IMAGE, UP, Part, tube, shell, band, stud, star  # noqa: E402

J, HC = K.J, K.HC
HB = ["head"]

BASE = {"plate": "iron", "trim": "gold", "mail": "steel_dark", "cloth": "wine", "hem": "agold", "gold": "gold",
        "helm": "bascinet", "paul": "layered", "lames": 2, "emblem": None, "tabard": "wine", "cape": None, "cowl": False, "spikes": False}
GUARD = dict(BASE, plate="black", trim="gold", helm="bascinet", paul="layered", lames=2, cape=None)
BOWMAN = dict(BASE, plate="iron", trim="gold", helm="kettle", paul="leather", lames=1, tabard="wine", hem="agold", cloth="hide", cape=None)
BRUTE = dict(BASE, plate="agold", trim="black", helm="horned", paul="spiked", lames=3, tabard=None, spikes=True, gold="red", hem="black")
HOUND = dict(BASE, plate="black", trim="gold", helm="beaked", paul="plain", lames=1, tabard=None, cape="wine", cowl=True, cloth="wine", hem="agold")
WARDEN = dict(BASE, plate="agold", trim="black", helm="horned", paul="layered", lames=3, tabard="wine", cape="wine", hem="agold", gold="gold", mail="iron")


def build(fn, S):
    """fn(k) of make_dark_knight, with the set S standing as its set k."""
    K.SETS.append(S)
    try:
        return fn(len(K.SETS) - 1)
    finally:
        K.SETS.pop()


def recolor(m, swap):
    for i, (v, faces, uvs, smooth, bones) in enumerate(m.parts):
        m.parts[i] = (v, [(f[0], swap.get(f[1], f[1]), f[2]) for f in faces], uvs, smooth, bones)
    return m


def merge(*meshes):
    out = H.Mesh()
    for mm in meshes:
        out.parts.extend(mm.parts)
    return out


def under(swap):
    us = K.undersuit()
    return recolor(merge(*us.values()), swap)


def coin(m, c, nrm, r, bones, sw="gold", core="agold"):
    """A coin standing proud of a plate: a rim, a sunk face, a raised mark."""
    nrm = np.array(nrm, float)
    nrm /= np.linalg.norm(nrm)
    ref = (0, 1, 0) if abs(nrm[1]) < 0.9 else (0, 0, 1)
    tube(m, [np.array(c), np.array(c) + nrm * 0.016], [(r, r)] * 2, sw, bones, fwd=ref, n=10)
    tube(m, [np.array(c) + nrm * 0.014, np.array(c) + nrm * 0.024], [(r * 0.7, r * 0.7), (r * 0.62, r * 0.62)], core, bones, fwd=ref, n=10)
    star(m, np.array(c) + nrm * 0.02, nrm, UP if abs(nrm[1]) < 0.9 else (0, 0, 1), r * 0.5, sw, bones, pts=4, th=0.012)


def key_ring(m, at, sw="gold", bones=("hips",), keys=3, scale=1.0):
    """A ring of keys hung at the hip."""
    bones = list(bones)
    at = np.array(at, float)
    band(m, at, (1, 0, 0.3), UP, 0.05 * scale, 0.05 * scale, 0.012, sw, bones, n=8)
    for i in range(keys):
        a = math.radians(-30 + 30 * i)
        d = np.array([math.sin(a) * 0.3, -math.cos(a), 0.0])
        tip = at + d * 0.17 * scale
        tube(m, [at + d * 0.03 * scale, tip], [(0.012 * scale, 0.012 * scale)] * 2, sw, bones, n=4)
        tube(m, [tip, tip + d * 0.025 * scale], [(0.032 * scale, 0.012 * scale)] * 2, sw, bones, n=6)
        stud(m, tip + d * 0.02 * scale + [0.0, 0, 0.0], (1, 0, 0), 0.012 * scale, 0.03 * scale, sw, bones, sides=4)


def halo(m, scale=1.0):
    """A vault-wheel behind the head: a gold ring, spokes and bolts."""
    c = HC + [0, 0.22, -0.26]
    r = 0.5 * scale
    annulus(m, c, r * 0.8, r, 0.04, "gold", "agold", HB, n=24)
    annulus(m, c + [0, 0, 0.01], r * 0.7, r * 0.8, 0.03, "black", "black", HB, n=24)
    for i in range(8):
        a = math.radians(45 * i + 22.5)
        d = np.array([math.sin(a), math.cos(a), 0.0])
        spoke(m, c, d, r * 0.1, r * 0.74, 0.035 * scale, 0.03, "agold", HB)
        stud(m, c + d * r * 1.0, d, 0.035 * scale, 0.09 * scale, "gold", HB, sides=4)
    annulus(m, c + [0, 0, 0.012], 0.0, r * 0.2, 0.06, "gold", "agold", HB, n=10)


def annulus(m, c, r_in, r_out, th, sw, edge, bones, n=24):
    """A flat ring (or a disc, r_in 0) in the XY plane facing +z, `th` thick."""
    P = Part()
    c = np.array(c, float)
    rim = []
    for k in range(n):
        a = 2 * math.pi * k / n
        rim.append((math.sin(a), math.cos(a)))
    z0, z1 = -th / 2, th / 2
    out = [[P.v(c + [rx * r_out, ry * r_out, z]) for rx, ry in rim] for z in (z0, z1)]
    inn = [[P.v(c + [rx * r_in, ry * r_in, z]) for rx, ry in rim] for z in (z0, z1)] if r_in > 0 else None
    mid = c
    for k in range(n):
        j = (k + 1) % n
        P.f([out[0][k], out[0][j], out[1][j], out[1][k]], edge, want=np.array([rim[k][0] + rim[j][0], rim[k][1] + rim[j][1], 0.0]))
        if inn:
            P.f([out[1][k], out[1][j], inn[1][j], inn[1][k]], sw, want=(0, 0, 1))
            P.f([out[0][k], out[0][j], inn[0][j], inn[0][k]], edge, want=(0, 0, -1))
            P.f([inn[0][k], inn[0][j], inn[1][j], inn[1][k]], edge, want=-np.array([rim[k][0] + rim[j][0], rim[k][1] + rim[j][1], 0.0]))
        else:
            ci1, ci0 = P.v(mid + [0, 0, z1]), P.v(mid + [0, 0, z0])
            P.f([out[1][k], out[1][j], ci1], sw, want=(0, 0, 1))
            P.f([out[0][k], out[0][j], ci0], edge, want=(0, 0, -1))
    P.to(m, bones, False)


def spoke(m, c, d, a, b, w, th, sw, bones):
    """A flat bar from a to b along the in-plane direction d."""
    P = Part()
    c = np.array(c, float)
    d = np.array(d, float)
    side = np.array([-d[1], d[0], 0.0])
    pts = []
    for t in (a, b):
        for sgn in (-1, 1):
            for z in (-th / 2, th / 2):
                pts.append(P.v(c + d * t + side * sgn * w + [0, 0, z + 0.012]))
    # pts index: t*4 + (sgn==1)*2 + (z==th/2)
    q = lambda t, s, z: pts[t * 4 + s * 2 + z]  # noqa: E731
    P.f([q(0, 0, 1), q(0, 1, 1), q(1, 1, 1), q(1, 0, 1)], sw, want=(0, 0, 1))
    P.f([q(0, 0, 0), q(0, 1, 0), q(1, 1, 0), q(1, 0, 0)], sw, want=(0, 0, -1))
    P.f([q(0, 0, 0), q(0, 0, 1), q(1, 0, 1), q(1, 0, 0)], sw, want=-side)
    P.f([q(0, 1, 0), q(0, 1, 1), q(1, 1, 1), q(1, 1, 0)], sw, want=side)
    P.to(m, bones, False)


def great_helm(S, tall=False):
    """A flat-topped barrel helm with a keyhole slit and a fin; the Warden's."""
    m = H.Mesh()
    pl, tr = S["plate"], S["trim"]
    hp = [(0.0, 0.13, 0.14), (0.1, 0.142, 0.152), (0.22, 0.145, 0.155), (0.33, 0.14, 0.15), (0.38, 0.13, 0.14), (0.4, 0.0, 0.0)]
    tube(m, [HC + [0, y, 0] for y, *_ in hp], [(rx, rz) for _, rx, rz in hp], pl, HB, n=16, front=1.05, caps=(True, False))
    band(m, HC + [0, 0.215, 0], UP, (0, 0, 1), 0.146, 0.157, 0.024, "black", HB, n=16, a0=-80, a1=80, front=1.06)
    # The keyhole: a round hole over a long slit.
    tube(m, [HC + [0, 0.205, 0.158], HC + [0, 0.205, 0.17]], [(0.026, 0.026)] * 2, "black", HB, fwd=(0, 1, 0), n=8)
    tube(m, [HC + [0, 0.07, 0.16], HC + [0, 0.19, 0.162]], [(0.012, 0.01)] * 2, "black", HB, fwd=(0, 0, 1), n=4, smooth=False)
    band(m, HC + [0, 0.012, 0], UP, (0, 0, 1), 0.133, 0.143, 0.026, "gold", HB, n=16, front=1.05)
    band(m, HC + [0, 0.37, 0], UP, (0, 0, 1), 0.133, 0.143, 0.022, "gold", HB, n=16, front=1.05)
    K.breaths(m, 0.165)
    # A crown of vault-key teeth round the top, and a fin from brow to nape.
    for i in range(10):
        a = math.radians(i * 36)
        p = HC + [0.125 * math.sin(a), 0.395, 0.135 * math.cos(a)]
        stud(m, p, (math.sin(a) * 0.2, 1, math.cos(a) * 0.2), 0.024, 0.12 if i % 2 == 0 else 0.07, "gold", HB, sides=4)
    fin = [HC + [0, 0.37, 0.15], HC + [0, 0.5, 0.08], HC + [0, 0.52, -0.05], HC + [0, 0.4, -0.15]]
    tube(m, fin, [(0.012, 0.03)] * 4, "gold", HB, fwd=(1, 0, 0), n=4, smooth=False)
    return m


def warden():
    S = WARDEN
    body = under({"cloth": "wine", "hide": "black"})
    chest = build(K.chest, S)
    legs = build(K.legs, S)
    m = merge(body, chest, legs, great_helm(S))
    C = ["chest"]
    # A great coin at the breast, and a gold gorget.
    coin(m, (0, 1.57, 0.262), (0, 0.12, 1), 0.1, C)
    tube(m, [(0, 1.7, 0), (0, 1.8, 0)], [(0.25, 0.19), (0.2, 0.16)], "gold", C, n=16, front=1.05, caps=(False, False))
    for s in (1, -1):
        for k in range(3):
            coin(m, (s * (0.12 + 0.07 * k), 1.36 + 0.0 * k, 0.215 - 0.015 * k), (s * 0.5, 0.1, 1), 0.026, C)
    # The belt: a gold buckle-coin and the Warden's ring of keys.
    coin(m, (0, 1.083, 0.19), (0, 0, 1), 0.052, ["hips"])
    key_ring(m, (0.255, 1.0, 0.07), keys=4, scale=1.5)
    key_ring(m, (-0.255, 1.0, 0.07), keys=3, scale=1.3)
    halo(m, 1.0)
    return m


def guard():
    S = GUARD
    m = merge(under({"cloth": "wine", "hide": "leather"}), build(K.chest, S), build(K.legs, S), build(K.helm, S)[0])
    C = ["chest"]
    coin(m, (0, 1.56, 0.262), (0, 0.12, 1), 0.075, C)
    coin(m, (0, 1.083, 0.19), (0, 0, 1), 0.04, ["hips"])
    # A gold plume.
    plume = [HC + [0, 0.36, 0.02], HC + [0, 0.5, -0.04], HC + [0, 0.46, -0.16], HC + [0, 0.3, -0.24]]
    tube(m, plume, [(0.014, 0.04), (0.012, 0.05), (0.01, 0.04), (0.0, 0.0)], "gold", HB, fwd=(1, 0, 0), n=4, smooth=False)
    return m


def crossbowman():
    S = BOWMAN
    m = merge(under({"cloth": "wine", "hide": "leather"}), build(K.chest, S), build(K.legs, S), build(K.helm, S)[0])
    C = ["chest"]
    # A bandolier of coins across the chest and a broad gold hat band.
    for i in range(6):
        t = i / 5
        coin(m, (-0.2 + 0.4 * t, 1.74 - 0.38 * t, 0.2 + 0.03 * math.sin(math.pi * t)), (-0.2 + 0.4 * t, 0.1, 1), 0.034, C)
    tube(m, [(-0.24, 1.76, 0.17), (0.24, 1.36, 0.19)], [(0.02, 0.012)] * 2, "hide", C, fwd=(0, 0, 1), n=4, smooth=False)
    band(m, HC + [0, 0.33, 0], UP, (0, 0, 1), 0.152, 0.162, 0.03, "gold", HB, n=14)
    key_ring(m, (0.255, 1.0, 0.07), keys=2, scale=1.0)
    return m


def brute():
    S = BRUTE
    m = merge(under({"cloth": "wine", "hide": "leather"}), build(K.chest, S), build(K.legs, S), build(K.helm, S)[0])
    C = ["chest"]
    coin(m, (0, 1.56, 0.262), (0, 0.12, 1), 0.11, C, sw="gold", core="black")
    # A wide belt of coins.
    for i in range(7):
        a = math.radians(-70 + 140 * i / 6)
        coin(m, (0.27 * math.sin(a), 1.083, 0.185 * math.cos(a) * 1.04), (math.sin(a), 0, math.cos(a)), 0.034, ["hips"])
    key_ring(m, (0.26, 1.0, 0.05), keys=3, scale=1.3)
    return m


def hound():
    S = HOUND
    m = merge(under({"cloth": "wine", "hide": "leather"}), build(K.chest, S), build(K.legs, S), build(K.helm, S)[0])
    C = ["chest"]
    coin(m, (0, 1.57, 0.24), (0, 0.12, 1), 0.055, C)
    key_ring(m, (0.24, 1.02, 0.1), keys=3, scale=1.1)
    key_ring(m, (-0.24, 1.02, 0.1), keys=2, scale=1.0)
    return m


MODELS = {"Warden": warden, "Guard": guard, "Crossbowman": crossbowman, "Brute": brute, "Hound": hound}


if __name__ == "__main__":
    g, nodes, joints, _ = H.skeleton()
    only = sys.argv[1:]
    for key, fn in MODELS.items():
        if only and key not in only:
            continue
        nm = "DarkVault_" + key
        H.write(None, K.SK, g, nodes, joints, nm, K.out(nm), meshes=[(nm + "_Mesh", fn())], image=IMAGE)
        print("WROTE", nm)
