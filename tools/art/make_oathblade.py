"""Oathbound Blade: a weapon skin for the Knight.

    python tools/art/make_oathblade.py   (Blender's Python: pip install bpy)

Writes assets/kaykit/weapons/oathbound_blade.gltf. See kk_mesh.py for how the
coloring works.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kk_mesh import ROOT, face, lathe, gem, vert, export  # noqa: E402
from mathutils import Vector  # noqa: E402

# Grip and pommel.
lathe([(-0.3, 0.035), (-0.05, 0.04), (0.12, 0.036)], "leather", sides=6)
for y0 in (-0.24, -0.12, 0.0):
    lathe([(y0, 0.042), (y0 + 0.04, 0.046), (y0 + 0.08, 0.042)], "black", sides=6)
lathe([(-0.46, 0.0), (-0.42, 0.06), (-0.36, 0.07), (-0.31, 0.04)], "gold")
gem((0.0, -0.39, 0.06), 0.03, 0.03, 0.02, facing=1)
gem((0.0, -0.39, -0.06), 0.03, 0.03, 0.02, facing=-1)

# Crossguard: a gold bar whose ends sweep up like wings, built as a strip of
# boxes along a curve, mirrored.
for side in (1, -1):
    pts = []
    for k in range(7):
        s = k / 6
        x = side * (0.05 + 0.3 * s)
        y = 0.14 + 0.16 * s ** 2.4
        h = 0.07 * (1 - 0.6 * s)
        d = 0.05 * (1 - 0.5 * s)
        pts.append([vert((x, y - h / 2, d)), vert((x, y + h / 2, d)), vert((x, y + h / 2, -d)), vert((x, y - h / 2, -d))])
    for k in range(6):
        a, b = pts[k], pts[k + 1]
        for i in range(4):
            j = (i + 1) % 4
            quad = [a[i], b[i], b[j], a[j]] if side > 0 else [a[j], b[j], b[i], a[i]]
            face(quad, "gold", [0.1 + 0.2 * i, 0.1 + 0.2 * i, 0.2 + 0.2 * i, 0.2 + 0.2 * i])
    tip = vert((side * 0.4, 0.36, 0))
    for i in range(4):
        j = (i + 1) % 4
        tri = [pts[-1][i], tip, pts[-1][j]] if side > 0 else [pts[-1][j], tip, pts[-1][i]]
        face(tri, "gold", [0.2, 0.0, 0.2])
# The guard's centre block, with a red stone each side.
c = [vert((x, y, z)) for x, y, z in ((-0.06, 0.1, 0.055), (0.06, 0.1, 0.055), (0.06, 0.2, 0.055), (-0.06, 0.2, 0.055),
                                     (-0.06, 0.1, -0.055), (0.06, 0.1, -0.055), (0.06, 0.2, -0.055), (-0.06, 0.2, -0.055))]
for q, t in (((0, 1, 2, 3), 0.2), ((5, 4, 7, 6), 0.2), ((4, 0, 3, 7), 0.5), ((1, 5, 6, 2), 0.5), ((3, 2, 6, 7), 0.1), ((4, 5, 1, 0), 0.8)):
    face([c[i] for i in q], "gold", [t] * 4)
gem((0.0, 0.15, 0.056), 0.035, 0.04, 0.025, facing=1)
gem((0.0, 0.15, -0.056), 0.035, 0.04, 0.025, facing=-1)

# Blade: broad at the guard, a slight waist, then a long point. Section is a
# flattened hexagon: two edges, a dark fuller down the middle of each face.
N = 8
rings = []
for k in range(N + 1):
    s = k / N
    y = 0.2 + 1.12 * s
    w = 0.13 * (1 - 0.18 * math.sin(math.pi * s * 0.8)) * (1 - s ** 3)  # half width
    th = 0.03 * (1 - 0.6 * s)
    rings.append([vert((w, y, 0)), vert((w * 0.3, y, th)), vert((-w * 0.3, y, th)),
                  vert((-w, y, 0)), vert((-w * 0.3, y, -th)), vert((w * 0.3, y, -th))])
for k in range(N):
    a, b = rings[k], rings[k + 1]
    t0, t1 = 0.6 - 0.5 * k / N, 0.6 - 0.5 * (k + 1) / N
    face([a[0], b[0], b[1], a[1]], "steel", [0.0, 0.0, 0.2, 0.2])
    face([a[1], b[1], b[2], a[2]], "steel_dark", [t0, t1, t1, t0])
    face([a[2], b[2], b[3], a[3]], "steel", [0.2, 0.2, 0.0, 0.0])
    face([a[3], b[3], b[4], a[4]], "steel", [0.3, 0.3, 0.5, 0.5])
    face([a[4], b[4], b[5], a[5]], "steel_dark", [t0, t1, t1, t0])
    face([a[5], b[5], b[0], a[0]], "steel", [0.5, 0.5, 0.3, 0.3])
face(list(reversed(rings[0])), "steel_dark", [0.6] * 6)
tip = vert((0, 1.42, 0))
for i in range(6):
    face([rings[-1][i], rings[-1][(i + 1) % 6], tip], "steel", [0.2, 0.2, 0.0])

export("oathbound_blade", ROOT + "/assets/kaykit/weapons/oathbound_blade.gltf")
