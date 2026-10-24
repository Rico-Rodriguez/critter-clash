"""The Gilded Warden's arms: the Vault boss (DB.BOSSES.warden).

    tools/art/blender.sh tools/art/make_warden.py

Writes assets/kaykit/weapons/warden_key.gltf, a great gold key swung as a
mace (grip at the origin, the shaft up +y, the bit at the top), and
warden_door.gltf, a round vault door carried as a shield (its face toward
+z, the hand at the origin): bolts round the rim, a dial and spokes. Both
use knight_texture.png's swatches like every KayKit weapon (kk_mesh.py).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kk_mesh as K  # noqa: E402
from kk_mesh import ROOT, lathe, gem, plate, box, spike, mark, place, export  # noqa: E402


def key():
    # The grip, wrapped, under a ring bow for a pommel.
    lathe([(-0.3, 0.04), (0.1, 0.045)], "leather", sides=6)
    for y in (-0.24, -0.12, 0.0):
        lathe([(y, 0.05), (y + 0.02, 0.058), (y + 0.04, 0.05)], "gold", sides=6)
    n = 12
    outer, inner = [], []
    for i in range(n + 1):
        a = math.pi * 2 * i / n - math.pi / 2
        outer.append((0.2 * math.cos(a), -0.48 + 0.18 * math.sin(a)))
        inner.append((0.11 * math.cos(a), -0.48 + 0.1 * math.sin(a)))
    plate(outer + list(reversed(inner)), 0.04, "gold")
    gem((0, -0.48 + 0.14, 0.045), 0.035, 0.04, 0.02, sw="red")
    gem((0, -0.48 + 0.14, -0.045), 0.035, 0.04, 0.02, sw="red", facing=-1)
    # A collar, then the heavy shaft.
    lathe([(0.1, 0.07), (0.14, 0.09), (0.18, 0.07)], "gold", sides=8)
    lathe([(0.18, 0.06), (1.25, 0.07), (1.32, 0.09), (1.36, 0.06)], "gold", sides=8,
          shade=lambda y: 0.3 + 0.4 * (y - 0.18) / 1.2)
    for y in (0.5, 0.85):
        lathe([(y, 0.07), (y + 0.03, 0.09), (y + 0.06, 0.07)], "steel_dark", sides=8)
    # The bit: a stepped block of wards off the +x side near the top.
    plate([(0.05, 0.95), (0.42, 0.95), (0.42, 1.05), (0.3, 1.05), (0.3, 1.12), (0.42, 1.12), (0.42, 1.28), (0.05, 1.28)],
          0.05, "gold", [1, 2, 5, 6], "steel")
    for y in (1.0, 1.2):
        spike((0.42, y, 0), 0.04, (0.56, y, 0), "steel", sides=4)
    # A crown of spikes on top makes it read as a weapon from afar.
    spike((0, 1.36, 0), 0.06, (0, 1.6, 0), "gold", sides=4)
    for a in (-1, 1):
        spike((a * 0.06, 1.33, 0), 0.04, (a * 0.18, 1.5, 0), "steel", sides=4)


def door():
    m = mark()
    # The door: a thick disc with a raised rim and a sunken face.
    lathe([(-0.06, 0.0), (-0.06, 0.62), (0.06, 0.62), (0.08, 0.56), (0.05, 0.5), (0.05, 0.2), (0.09, 0.18), (0.1, 0.0)],
          "steel_dark", sides=16)
    place(m, rot=(90, 0, 0))
    # Gold bolts all round the rim.
    for i in range(12):
        a = math.pi * 2 * i / 12
        m = mark()
        lathe([(0.0, 0.045), (0.04, 0.04), (0.06, 0.0)], "gold", sides=6)
        place(m, rot=(90, 0, 0), at=(0.56 * math.cos(a), 0.56 * math.sin(a), 0.07))
    # Spokes from the dial, then the dial and its handle.
    for i in range(4):
        m = mark()
        box((0, 0.3, 0), (0.05, 0.36, 0.04), "gold")
        place(m, rot=(0, 0, 45 + 90 * i), at=(0, 0, 0.08))
    m = mark()
    lathe([(0.0, 0.17), (0.05, 0.16), (0.08, 0.1), (0.09, 0.0)], "gold", sides=12)
    place(m, rot=(90, 0, 0), at=(0, 0, 0.08))
    gem((0, 0, 0.18), 0.06, 0.06, 0.03, sw="red")
    for i in range(8):
        a = math.pi * 2 * i / 8
        box((0.13 * math.cos(a), 0.13 * math.sin(a), 0.16), (0.02, 0.02, 0.03), "black")


if __name__ == "__main__":
    for name, build in (("warden_key", key), ("warden_door", door)):
        K.reset()
        build()
        export(name, ROOT + "/assets/kaykit/weapons/%s.gltf" % name)
