"""A skeleton on the hero skeleton, for the dead in dark plate (make_dark_hexer.py,
make_dark_regent.py): a faceted skull with ember eyes and a hanging jaw, ribs,
spine, pelvis, limb bones, bony fists and feet. Everything is skinned to the hero
bones, so the baked clips play on it unchanged. Plain Python + numpy.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_dark_knight as K  # noqa: E402
from dark_kit import UP, tube, band, stud  # noqa: E402

J, HC = K.J, K.HC
DARK = "black"


def skull(m, bone="bone", eye="gold", width=1.0):
    """A cranium on the head bone, dark sockets, glowing pinpricks and a jaw."""
    hb = ["head"]
    prof = [(0.06, 0.085, 0.1), (0.12, 0.11, 0.125), (0.2, 0.125, 0.135), (0.28, 0.118, 0.128), (0.34, 0.09, 0.1), (0.38, 0.04, 0.05)]
    tube(m, [HC + [0, y, -0.01] for y, *_ in prof], [(rx * width, rz) for _, rx, rz in prof], bone, hb, n=12, front=1.12)
    for s in (1, -1):
        tube(m, [HC + [0.05 * s * width, 0.19, 0.105], HC + [0.052 * s * width, 0.19, 0.135]], [(0.036, 0.03), (0.032, 0.026)], DARK, hb, n=6)
        # char.gdshader lights the hot gold texels as the eyes' glow.
        stud(m, HC + [0.052 * s * width, 0.19, 0.128], (0, 0, 1), 0.017, 0.012, eye, hb, sides=5)
    stud(m, HC + [0, 0.13, 0.13], (0, 0, 1), 0.018, 0.012, DARK, hb, sides=3)
    # The jaw hangs a little open, teeth along its front.
    tube(m, [HC + [0, 0.04, 0.02], HC + [0, 0.095, 0.04]], [(0.075 * width, 0.07), (0.088 * width, 0.085)], bone, hb, n=8, front=1.15)
    band(m, HC + [0, 0.1, 0.02], UP, (0, 0, 1), 0.09 * width, 0.105, 0.02, DARK, hb, n=10, a0=-70, a1=70)


def bones(m, bone="bone", ribs=True, legs=True, trunk=True):
    """Pelvis, spine, ribs, shoulders, arm and leg bones, bony fists and feet."""
    if trunk:
        if ribs:
            for y in (1.27, 1.35, 1.43, 1.51, 1.59):
                w = 0.19 + 0.05 * (1 - abs(y - 1.47) / 0.25)
                band(m, (0, y, -0.01), UP, (0, 0, 1), w, w * 0.7, 0.04, bone, ["chest"], n=12, a0=20, a1=340)
            tube(m, [(0, 1.25, 0.13), (0, 1.6, 0.14)], [(0.025, 0.015)] * 2, bone, ["chest"], n=4)
        tube(m, [(0, 0.98, -0.07), (0, 1.66, -0.08)], [(0.035, 0.035)] * 2, bone, ["spine", "chest"], n=6)
        for y in np.arange(1.0, 1.66, 0.08):
            band(m, (0, y, -0.08), UP, (0, 0, 1), 0.05, 0.045, 0.03, bone, ["spine" if y < 1.25 else "chest"], n=6)
        tube(m, [(0, 0.9, -0.01), (0, 0.98, 0), (0, 1.06, -0.02)], [(0.16, 0.1), (0.2, 0.13), (0.17, 0.1)], bone, ["hips"], n=10, front=0.8)
    for s, side in ((1, "l"), (-1, "r")):
        ua, la, wr = J("upperarm." + side), J("lowerarm." + side), J("wrist." + side)
        ax = np.array([s, 0, 0.0])
        tube(m, [J("chest") + [0, 0.2, 0.04], ua + ax * 0.02], [0.038, 0.04], bone, ["chest"], n=6)
        tube(m, [ua - ax * 0.02, la], [(0.051, 0.054), (0.041, 0.043)], bone, ["upperarm." + side], fwd=UP, n=6)
        tube(m, [la - ax * 0.03, la + ax * 0.03], [(0.065, 0.065)] * 2, bone, ["upperarm." + side, "lowerarm." + side], fwd=UP, n=6)
        for dz in (0.018, -0.018):
            tube(m, [la + [0, 0, dz], wr + [0, 0, dz]], [0.027, 0.024], bone, ["lowerarm." + side], fwd=UP, n=4)
        K.glove(m, wr, ax, side, bone, bone)
        if legs:
            ul, ll, ft = J("upperleg." + side), J("lowerleg." + side), J("foot." + side)
            tube(m, [ul + [0, -0.03, 0], ll], [(0.061, 0.061), (0.049, 0.049)], bone, ["upperleg." + side], n=6)
            tube(m, [ll + [0, 0.03, 0], ll - [0, 0.03, 0]], [(0.078, 0.078)] * 2, bone, ["upperleg." + side, "lowerleg." + side], n=6)
            tube(m, [ll, ft + [0, 0.03, 0]], [(0.047, 0.047), (0.038, 0.038)], bone, ["lowerleg." + side], n=6)
            K.shoe(m, ft, side, bone, bone)


def grow(m, first, center, k):
    """Scales every part added since `first` (an index into m.parts) about
    `center`: a bigger skull and crown for a boss that is seen from far off."""
    c = np.array(center, float)
    for v, *_ in m.parts[first:]:
        v[:] = c + (v - c) * k
