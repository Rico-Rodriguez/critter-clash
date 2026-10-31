"""Thrown and shot things, and the coin, in the dark palette: they replace the
KayKit arrow, bolt, dagger, axe, bone and coin that flew or dropped in the hunt.

    python tools/art/make_dark_ammo.py [name ...]   (Blender's Python: pip install bpy)

Writes assets/kaykit/weapons/ammo_<name>.gltf. Flat-faceted like the dark
weapons (K.DARK), small and bold so they read at hunt distance:
- arrow, bolt, bone: fly along +z (the projectile turns toward its velocity),
  centred on the origin;
- knife, axe: held along +y with the grip at the origin; the hunt lays them
  flat and spins them about y;
- coin: a disc round y, thick enough to catch light when it turns.
"""
import base64
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kk_mesh as K  # noqa: E402
from kk_mesh import ROOT, lathe, plate, box, spike, mark, place, export  # noqa: E402

K.DARK = True


def along_z(build):
    """Builds along +y, then lays the result down to run along +z."""
    m = mark()
    build()
    place(m, rot=(90, 0, 0))


def fletch(y, length, span, sw, n=3):
    """Vanes round the shaft's tail, each a thin quad standing off it."""
    for i in range(n):
        m = mark()
        plate([(0.0, 0.0), (span, -length * 0.35), (span, length * 0.65), (0.0, length)], 0.006, sw)
        place(m, rot=(0, i * 360 / n, 0), at=(0, y, 0))


def arrow():
    def b():
        box((0, 0.0, 0), (0.035, 1.0, 0.035), "wood")
        spike((0, 0.5, 0), 0.07, (0, 0.74, 0), "silver", sides=4)
        spike((0, 0.5, 0), 0.07, (0, 0.44, 0), "iron", sides=4)
        fletch(-0.5, 0.26, 0.09, "blood")
        lathe([(-0.52, 0.02), (-0.5, 0.032)], "pale", sides=4)
    along_z(b)


def bolt():
    def b():
        box((0, 0.0, 0), (0.05, 0.62, 0.05), "iron")
        spike((0, 0.31, 0), 0.085, (0, 0.55, 0), "silver", sides=4)
        spike((0, 0.31, 0), 0.085, (0, 0.25, 0), "iron", sides=4)
        fletch(-0.31, 0.16, 0.07, "ember", n=3)
    along_z(b)


def knife():
    # Held along +y, grip at the origin: wrap, guard, a leaf blade ground to an edge.
    lathe([(-0.2, 0.03), (-0.2, 0.04), (0.0, 0.035), (0.02, 0.03)], "hide", sides=6)
    lathe([(-0.24, 0.0), (-0.21, 0.05), (-0.2, 0.0)], "iron", sides=6)
    box((0, 0.03, 0), (0.22, 0.04, 0.07), "silver")
    plate([(-0.05, 0.05), (0.05, 0.05), (0.07, 0.35), (0.0, 0.72), (-0.07, 0.35)], 0.014, "silver", [1, 2, 3, 4], "pale")
    box((0, 0.3, 0.017), (0.012, 0.5, 0.004), "iron")


def axe():
    # A throwing axe: a short haft and a broad crescent head with a back spike.
    lathe([(-0.2, 0.04), (-0.2, 0.034), (0.55, 0.03), (0.55, 0.0)], "wood", sides=6)
    lathe([(-0.24, 0.0), (-0.2, 0.05), (-0.17, 0.0)], "iron", sides=6)
    m = mark()
    plate([(0.0, 0.0), (0.2, -0.12), (0.34, -0.06), (0.3, 0.14), (0.34, 0.34), (0.2, 0.4), (0.0, 0.3)], 0.022, "iron", [1, 2, 3, 4, 5], "silver")
    place(m, at=(0.02, 0.2, 0))
    spike((-0.03, 0.34, 0), 0.04, (-0.2, 0.36, 0), "iron", sides=4)
    box((0.0, 0.2, 0), (0.07, 0.3, 0.07), "iron")


def bone():
    # A sharpened shard of bone: a knuckle at the tail, a long shaft, a fang tip.
    def b():
        lathe([(-0.45, 0.0), (-0.43, 0.1), (-0.33, 0.12), (-0.25, 0.05), (0.2, 0.045), (0.3, 0.03)], "pale", sides=5)
        spike((0, 0.3, 0), 0.03, (0, 0.55, 0), "pale", sides=5)
        for sx in (-1, 1):
            spike((sx * 0.05, -0.43, 0), 0.07, (sx * 0.12, -0.52, 0), "pale", sides=4)
        # A ring of dark binding where the shard was lashed.
        lathe([(0.0, 0.055), (0.05, 0.055)], "hide", sides=5)
    along_z(b)


def coin():
    # A silver-rimmed disc round y with a raised face of old gold.
    lathe([(-0.05, 0.0), (-0.05, 0.21), (0.05, 0.21), (0.05, 0.0)], "silver", sides=8)
    lathe([(-0.058, 0.0), (-0.058, 0.15), (0.058, 0.15), (0.058, 0.0)], "agold", sides=8)


BUILDS = {"arrow": arrow, "bolt": bolt, "knife": knife, "axe": axe, "bone": bone, "coin": coin}

if __name__ == "__main__":
    only = sys.argv[1:]
    for name, build in BUILDS.items():
        if only and name not in only:
            continue
        K.reset()
        build()
        out = ROOT + "/assets/kaykit/weapons/ammo_%s.gltf" % name
        export("ammo_" + name, out)
        # The buffer goes inside the .gltf (a few KB), so there is no .bin for git LFS to carry.
        with open(out) as f:
            g = json.load(f)
        binp = out[:-5] + ".bin"
        with open(binp, "rb") as f:
            g["buffers"][0]["uri"] = "data:application/octet-stream;base64," + base64.b64encode(f.read()).decode()
        with open(out, "w") as f:
            json.dump(g, f, indent=1)
        os.remove(binp)
