"""SAMPLE: the Barrow's dead in the dark plate style, on the hero skeleton, so
the baked clips play on them unchanged (a mockup for Rico, not wired in).

    python3 tools/art/make_dark_dead.py   (plain Python + numpy)

Writes into assets/kaykit/characters/:
- DarkDead_Minion.glb: a Risen Bones. Faceted old bone, a rusted kettle hat,
  one scrap pauldron and a rag loincloth.
- DarkDead_King.glb: Gravemaw. The same bones in the Knight's Bloodiron chest
  and legs, the skull bare under an iron crown.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_hero_body as H  # noqa: E402
import make_dark_knight as K  # noqa: E402
from dark_kit import IMAGE, UP, tube, shell, band, stud, sheet, jagged  # noqa: E402

J, HC = K.J, K.HC
BONE, DARK = "stone", "black"


def skull(m, crown=None):
    """A cranium on the head bone, dark sockets and a jaw; `crown` rings it."""
    hb = ["head"]
    prof = [(0.06, 0.085, 0.1), (0.12, 0.11, 0.125), (0.2, 0.125, 0.135), (0.28, 0.118, 0.128), (0.34, 0.09, 0.1), (0.38, 0.04, 0.05)]
    tube(m, [HC + [0, y, -0.01] for y, *_ in prof], [(rx, rz) for _, rx, rz in prof], BONE, hb, n=12, front=1.12)
    for s in (1, -1):
        tube(m, [HC + [0.05 * s, 0.19, 0.105], HC + [0.052 * s, 0.19, 0.135]], [(0.036, 0.03), (0.032, 0.026)], DARK, hb, n=6)
        # A warm ember in each socket: char.gdshader's eye glow lights the hot gold texels.
        stud(m, HC + [0.052 * s, 0.19, 0.128], (0, 0, 1), 0.017, 0.012, "gold", hb, sides=5)
    stud(m, HC + [0, 0.13, 0.13], (0, 0, 1), 0.018, 0.012, DARK, hb, sides=3)
    # The jaw: hangs a little open, teeth on its front.
    tube(m, [HC + [0, 0.04, 0.02], HC + [0, 0.095, 0.04]], [(0.075, 0.07), (0.088, 0.085)], BONE, hb, n=8, front=1.15)
    band(m, HC + [0, 0.1, 0.02], UP, (0, 0, 1), 0.09, 0.105, 0.02, DARK, hb, n=10, a0=-70, a1=70)
    if crown:
        c = HC + [0, 0.27, -0.01]
        band(m, c, UP, (0, 0, 1), 0.135, 0.145, 0.05, crown, hb, n=10)
        for k in range(8):
            a = np.radians(k * 45)
            stud(m, c + [0.14 * np.sin(a), 0.02, 0.145 * np.cos(a)], (np.sin(a) * 0.25, 1, np.cos(a) * 0.25), 0.026, 0.11 if k % 2 == 0 else 0.07, crown, hb, sides=4)


def bones(m, ribs=True):
    """Pelvis, spine, ribs, shoulders, arm and leg bones, bony fists and feet."""
    if ribs:
        for y in (1.27, 1.35, 1.43, 1.51, 1.59):
            w = 0.19 + 0.05 * (1 - abs(y - 1.47) / 0.25)
            band(m, (0, y, -0.01), UP, (0, 0, 1), w, w * 0.7, 0.04, BONE, ["chest"], n=12, a0=20, a1=340)
        tube(m, [(0, 1.25, 0.13), (0, 1.6, 0.14)], [(0.025, 0.015)] * 2, BONE, ["chest"], n=4)
        tube(m, [(0, 0.98, -0.07), (0, 1.66, -0.08)], [(0.035, 0.035)] * 2, BONE, ["spine", "chest"], n=6)
        for y in np.arange(1.0, 1.66, 0.08):
            band(m, (0, y, -0.08), UP, (0, 0, 1), 0.05, 0.045, 0.03, BONE, ["spine" if y < 1.25 else "chest"], n=6)
    # Pelvis: a hipbone bowl.
    tube(m, [(0, 0.9, -0.01), (0, 0.98, 0), (0, 1.06, -0.02)], [(0.16, 0.1), (0.2, 0.13), (0.17, 0.1)], BONE, ["hips"], n=10, front=0.8)
    for s, side in ((1, "l"), (-1, "r")):
        ua, la, wr = J("upperarm." + side), J("lowerarm." + side), J("wrist." + side)
        ax = np.array([s, 0, 0.0])
        tube(m, [J("chest") + [0, 0.2, 0.04], ua + ax * 0.02], [0.038, 0.04], BONE, ["chest"], n=6)
        tube(m, [ua - ax * 0.02, la], [(0.051, 0.054), (0.041, 0.043)], BONE, ["upperarm." + side], fwd=UP, n=6)
        tube(m, [la - ax * 0.03, la + ax * 0.03], [(0.065, 0.065)] * 2, BONE, ["upperarm." + side, "lowerarm." + side], fwd=UP, n=6)
        for dz in (0.018, -0.018):
            tube(m, [la + [0, 0, dz], wr + [0, 0, dz]], [0.027, 0.024], BONE, ["lowerarm." + side], fwd=UP, n=4)
        K.glove(m, wr, ax, side, BONE, BONE)
        ul, ll, ft = J("upperleg." + side), J("lowerleg." + side), J("foot." + side)
        tube(m, [ul + [0, -0.03, 0], ll], [(0.061, 0.061), (0.049, 0.049)], BONE, ["upperleg." + side], n=6)
        tube(m, [ll + [0, 0.03, 0], ll - [0, 0.03, 0]], [(0.078, 0.078)] * 2, BONE, ["upperleg." + side, "lowerleg." + side], n=6)
        tube(m, [ll, ft + [0, 0.03, 0]], [(0.047, 0.047), (0.038, 0.038)], BONE, ["lowerleg." + side], n=6)
        K.shoe(m, ft, side, BONE, BONE)


def minion():
    m = H.Mesh()
    bones(m)
    skull(m)
    helm, _ = K.helm(0)
    # A rag tied round the hips, front and back.
    for zs in (1, -1):
        jag = jagged(5, 0.08, 7 if zs > 0 else 11)
        rows = []
        for r in range(5):
            y = 1.03 - r * 0.11
            row = []
            for c in range(5):
                x = -0.13 + 0.065 * c
                row.append((x * zs, y - (jag[c] if r == 4 else 0.0), zs * (0.15 + 0.02 * r)))
            rows.append(row)
        sheet(m, rows, "hide", ["hips", "upperleg.l", "upperleg.r"], edge="cloth")
    band(m, (0, 1.03, 0), UP, (0, 0, 1), 0.2, 0.16, 0.04, "cloth", ["hips"], n=10)
    # One scrap pauldron, on the left.
    ua = J("upperarm.l")
    shell(m, [ua + [-0.06, 0.08, 0], ua + [0.08, 0.04, 0], ua + [0.16, -0.04, 0]], [(0.11, 0.12), (0.12, 0.13), (0.1, 0.11)], -100, 100, "iron", ["upperarm.l"],
          fwd=UP, n=10, edge="rust", th=0.02)
    stud(m, ua + [0.04, 0.17, 0.0], UP, 0.015, 0.02, "rust", ["upperarm.l"])
    return [("DarkDead_Minion_Body", m), ("DarkDead_Minion_Helm", helm)]


def king():
    m = H.Mesh()
    bones(m, ribs=False)
    skull(m, crown="iron")
    return [("DarkDead_King_Body", m), ("DarkDead_King_Chest", K.chest(3)), ("DarkDead_King_Legs", K.legs(3))]


if __name__ == "__main__":
    g, nodes, joints, _ = H.skeleton()
    for name, parts in (("DarkDead_Minion", minion()), ("DarkDead_King", king())):
        H.write(None, K.SK, g, nodes, joints, name, K.out(name), meshes=parts, image=IMAGE)
        print("WROTE", name)
