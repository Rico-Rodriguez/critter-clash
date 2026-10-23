"""Reaper's Scythe: a weapon skin for the Knight and Barbarian.

    python tools/art/make_reaper.py   (Blender's Python: pip install bpy)

Writes assets/kaykit/weapons/reaper_scythe.gltf. See kk_mesh.py for how the
coloring works.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kk_mesh import ROOT, face, lathe, gem, vert, export  # noqa: E402
from mathutils import Vector  # noqa: E402

# Haft: dark wood, tapering, with a wrapped grip and gold collars.
lathe([(-0.62, 0.042), (0.1, 0.046), (0.9, 0.044), (1.42, 0.04)], "wood", shade=lambda y: 0.85 - 0.5 * (y + 0.6) / 2.0)
lathe([(-0.12, 0.055), (0.32, 0.055)], "leather")
for y0 in (-0.08, 0.05, 0.18):
    lathe([(y0, 0.058), (y0 + 0.05, 0.063), (y0 + 0.1, 0.058)], "black")
lathe([(-0.66, 0.062), (-0.6, 0.068), (-0.55, 0.05)], "gold")
lathe([(-0.9, 0.0), (-0.66, 0.052)], "steel_dark")  # butt spike
lathe([(1.36, 0.05), (1.4, 0.075), (1.62, 0.07), (1.66, 0.05)], "gold")
lathe([(1.66, 0.05), (1.78, 0.0)], "gold")  # finial

# Blade: a crescent leaving the collar sideways and sweeping down to a point.
# Each station along it is a diamond section: spine top and bottom, two
# cheeks, and the cutting edge, which takes the bright end of the swatch.
N = 14
rings = []
for k in range(N + 1):
    s = k / N
    ang = math.radians(8 - 70 * s ** 1.6)  # heading: out, then down
    x = 0.04 + 1.05 * s
    y = 1.56 + 0.22 * math.sin(math.pi * s) * (1 - s) - 0.34 * s ** 2.2
    w = 0.27 * (1 - s ** 1.3) + 0.014  # blade depth
    th = 0.04 * (1 - 0.7 * s) + 0.005  # spine thickness
    n = Vector((math.sin(ang), -math.cos(ang), 0))  # toward the edge
    p = Vector((x, y, 0))
    rings.append([
        vert(p + Vector((0, 0, th))),
        vert(p + n * w * 0.55 + Vector((0, 0, th * 0.6))),
        vert(p + n * w),
        vert(p + n * w * 0.55 - Vector((0, 0, th * 0.6))),
        vert(p - Vector((0, 0, th))),
    ])
for k in range(N):
    a, b = rings[k], rings[k + 1]
    ts = [0.15 + 0.6 * k / N, 0.15 + 0.6 * (k + 1) / N]
    face([a[0], b[0], b[1], a[1]], "steel_dark", [ts[0], ts[1], ts[1], ts[0]])
    face([a[1], b[1], b[2], a[2]], "steel", [0.25, 0.25, 0.0, 0.0])
    face([a[2], b[2], b[3], a[3]], "steel", [0.0, 0.0, 0.25, 0.25])
    face([a[3], b[3], b[4], a[4]], "steel_dark", [ts[0], ts[1], ts[1], ts[0]])
    face([a[4], b[4], b[0], a[0]], "black", [0.3] * 4)
face(list(reversed(rings[0])), "steel_dark", [0.6] * 5)
tip = vert(rings[-1][2].co + Vector((0.03, -0.08, 0)))
for i in range(5):
    face([rings[-1][i], rings[-1][(i + 1) % 5], tip], "steel", [0.3, 0.3, 0.0])

# Back spike, opposite the blade.
base = [vert((-0.04, 1.47 + dy, dz)) for dy, dz in ((0.05, 0.03), (0.05, -0.03), (-0.05, -0.03), (-0.05, 0.03))]
sp = vert((-0.36, 1.58, 0))
for i in range(4):
    face([base[i], base[(i + 1) % 4], sp], "steel_dark", [0.2, 0.5, 0.0])

# A red stone set in the collar on both faces.
gem((0.0, 1.51, 0.074), 0.045, 0.06, 0.03, facing=1)
gem((0.0, 1.51, -0.074), 0.045, 0.06, 0.03, facing=-1)

export("reaper_scythe", ROOT + "/assets/kaykit/weapons/reaper_scythe.gltf")
