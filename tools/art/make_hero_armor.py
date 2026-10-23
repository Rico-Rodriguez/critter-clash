"""The Knight's, Ranger's and Mage's armor props: a helm (hat, crown) and
shoulders for each of the five sets.

    python tools/art/make_hero_armor.py   (Blender's Python: pip install bpy)

Writes assets/kaykit/gear/<hero>_helm_<set>.gltf and <hero>_pauldron_<set>.gltf
in the bone spaces make_barbarian_armor.py describes (helm on `head`, +z the
face; pauldron on `upperarm.l` / `.r`, symmetric in x). All four heroes share
one skeleton and nearly one head, so the sizes carry over.

- Knight: kettle hat, bascinet, crested helm, horned dread helm, winged
  seraph helm; round steel pauldrons growing to spiked and winged.
- Ranger: leather cap, feathered cap, a gold circlet over the hood, black
  antlers, a pale stag crown; leather pads.
- Mage: floppy hat, wizard hat, starred hat, horned hat, a pale crowned hat;
  shoulders only from Bloodiron, as a spiked mantle.
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kk_mesh as K  # noqa: E402
from kk_mesh import ROOT, lathe, gem, spike, box, plate, mark, place, export  # noqa: E402
from make_barbarian_armor import SETS, tube, dome, lathe_ring, CAP_TILT  # noqa: E402

BASE = 0.46


def bowl(r, peak, sw, sides=10):
    lathe([(BASE, r), (BASE + 0.18, r), (BASE + 0.38, r * 0.9), (peak - 0.18, r * 0.62), (peak, r * 0.12)], sw, sides=sides,
          shade=lambda y: 0.15 + 0.6 * (1 - (y - BASE) / (peak - BASE)))


def band(r, sw, y=BASE - 0.04, h=0.14, sides=10):
    lathe([(y, r * 1.06), (y + h, r * 1.06)], sw, sides=sides)


def cheeks(r, sw, edge, drop=0.32):
    for side in (-1, 1):
        m = mark()
        plate([(0.0, 0.0), (0.2, 0.0), (0.16, -drop), (0.02, -drop * 0.8)], 0.03, sw, edges=(1,), edge_sw=edge)
        place(m, rot=(0, side * 70, 0), at=(side * r * 0.86, BASE + 0.02, r * 0.38))


# --- The Knight ---------------------------------------------------------------

def knight_helm(k):
    s = SETS[k]
    r = 0.6 * s["size"]
    if k == 0:
        # A kettle hat: a low bowl and a wide brim.
        bowl(r * 0.95, 1.0, "rust")
        lathe([(BASE - 0.02, r * 1.45), (BASE + 0.02, r * 1.45), (BASE + 0.06, r * 1.0)], "rust", sides=10)
        band(r * 0.95, "leather", h=0.08)
        return
    peak = 1.15 + 0.05 * k
    bowl(r, peak, s["metal"])
    band(r, s["trim"])
    if k <= 2:
        plate([(-0.05, BASE + 0.1), (0.05, BASE + 0.1), (0.035, BASE - 0.2), (-0.035, BASE - 0.2)], 0.025, s["metal"])
        K.bm.verts.ensure_lookup_table()
        for v in K.bm.verts[-8:]:
            v.co.z += r * 1.04
    if k >= 1:
        cheeks(r, s["metal"], s["edge"], 0.28 + 0.03 * k)
    if k == 2:
        # A tall crest front to back.
        m = mark()
        plate([(-0.5, 0.0), (0.45, 0.0), (0.3, 0.3), (-0.25, 0.36), (-0.55, 0.12)], 0.035, "red")
        place(m, rot=(0, 90, 0), at=(0, peak - 0.12, 0))
        lathe([(peak - 0.14, 0.08), (peak - 0.05, 0.08)], "gold", sides=6)
    if k == 3:
        for side in (-1, 1):
            tube([(side * 0.5, 0.66, 0.05), (side * 0.78, 0.74, 0.18), (side * 0.86, 0.95, 0.38), (side * 0.8, 1.12, 0.55)], [0.1, 0.07, 0.04, 0.008], "black")
            lathe_ring((side * 0.56, 0.66, 0.05), 0.11, "red", (1, 0, 0))
        m = mark()
        plate([(-0.45, 0.0), (0.4, 0.0), (0.2, 0.42), (-0.3, 0.3)], 0.035, "red")
        place(m, rot=(0, 90, 0), at=(0, peak - 0.1, 0))
        gem((0, BASE + 0.2, r * 1.0), 0.06, 0.08, 0.05, sw="red")
    if k == 4:
        lathe([(BASE + 0.12, r * 1.04), (BASE + 0.2, r * 1.04)], "gold", sides=10)
        gem((0, BASE + 0.18, r * 1.05), 0.08, 0.1, 0.07, sw="white")
        for side in (-1, 1):
            m = mark()
            for i in range(3):
                plate([(0, 0.02 * i), (0.2, 0.08 + 0.05 * i), (0.5 - 0.07 * i, 0.3 + 0.14 * i), (0.08, 0.12 + 0.05 * i)], 0.02, "white" if i else "gold", [1, 2], "gold")
            place(m, rot=(0, 0 if side > 0 else 180, 0), at=(side * 0.55, 0.6, -0.05))
        spike((0, peak - 0.05, 0), 0.06, (0, peak + 0.3, 0), "gold", sides=4)


def round_pauldron(k, s, metal, rim, lames_from=2, spikes_sw=None, wings=False):
    m = mark()
    lames = 1 + (k >= lames_from) + (k >= 4)
    for i in range(lames):
        mm = mark()
        r = (0.21 + 0.012 * k) * s["size"] * (1.0 + 0.08 * i)
        dome(r, 0.14 + 0.015 * k, metal, rim)
        place(mm, at=(0, -0.07 * i, 0))
    if spikes_sw:
        spike((0, 0.15, 0), 0.06, (0, 0.42, 0), spikes_sw, sides=4)
        for a in (-1, 1):
            spike((a * 0.12, 0.1, 0), 0.045, (a * 0.28, 0.32, 0), spikes_sw, sides=4)
    if wings:
        lathe([(-0.2, 0.36 * s["size"]), (-0.16, 0.3 * s["size"])], "gold", sides=10)
        g = mark()
        gem((0, 0, 0), 0.05, 0.05, 0.04, sw="white")
        place(g, rot=(-90, 0, 0), at=(0, 0.17, 0))
    place(m, rot=CAP_TILT, at=(0, 0.0, 0.13))


def knight_pauldron(k):
    s = SETS[k]
    if k == 0:
        round_pauldron(0, s, "rust", "leather")
        return
    round_pauldron(k, s, s["metal"], s["edge"] if k >= 2 else s["trim"], spikes_sw="red" if k == 3 else None, wings=(k == 4))


# --- The Ranger ---------------------------------------------------------------

def antlers(side, sw, size, tines=2):
    base = (side * 0.3, 0.92, -0.02)
    tip = (side * (0.3 + 0.35 * size), 0.92 + 0.55 * size, -0.12)
    mid = (side * (0.3 + 0.28 * size), 0.92 + 0.22 * size, 0.0)
    tube([base, mid, tip], [0.05, 0.035, 0.008], sw, sides=5)
    for t in range(tines):
        f = 0.35 + 0.3 * t
        p = (base[0] + (tip[0] - base[0]) * f, base[1] + (tip[1] - base[1]) * f, base[2] + (tip[2] - base[2]) * f)
        tube([p, (p[0] - side * 0.06, p[1] + 0.22 * size, p[2] + 0.06)], [0.025, 0.006], sw, sides=4)


def ranger_helm(k):
    s = SETS[k]
    r = 0.6 * s["size"]
    if k <= 1:
        # Over the Ranger's hair, so a size up and not the hair's brown.
        whole = mark()
        cap = "slate" if k == 0 else "tan"
        bowl(r * 0.98, 1.05, cap, sides=9)
        band(r * 0.98, "leather" if k else "tan", h=0.08, sides=9)
        # A short brim over the eyes.
        m = mark()
        plate([(-0.3, 0.0), (0.3, 0.0), (0.22, 0.2), (-0.22, 0.2)], 0.02, cap)
        place(m, rot=(-80, 0, 0), at=(0, BASE + 0.02, r * 0.95))
        if k == 1:
            # A long feather swept back off the band.
            m = mark()
            plate([(0, 0), (0.1, 0.25), (0.05, 0.9), (-0.05, 0.25)], 0.016, "red", [1, 2], "white")
            place(m, rot=(-50, 0, -25), at=(r * 0.8, BASE + 0.15, -r * 0.4))
        place(whole, at=(0, 0.02, 0), scale=1.12)
        return
    # Over the hood (a KayKit part worn with it): a circlet, then antlers.
    hood_r = r * 0.86
    lathe([(BASE + 0.18, hood_r), (BASE + 0.26, hood_r)], "gold" if k != 3 else "red", sides=10)
    gem((0, BASE + 0.22, hood_r + 0.01), 0.06, 0.07, 0.05, sw={2: "gold", 3: "red", 4: "white"}[k])
    if k >= 3:
        for side in (-1, 1):
            antlers(side, "black" if k == 3 else "white", 1.0 if k == 3 else 1.3, 2 if k == 3 else 3)
    if k == 4:
        for i in range(5):
            a = math.radians(-50 + 25 * i)
            spike((math.sin(a) * hood_r, BASE + 0.25, math.cos(a) * hood_r), 0.035, (math.sin(a) * hood_r * 1.05, BASE + 0.45 + (0.08 if i == 2 else 0), math.cos(a) * hood_r * 1.05), "gold", sides=3)


def ranger_pauldron(k):
    s = SETS[k]
    pad = ["leather", "leather", "black", "black", "white"][k]
    rim = ["tan", "tan", "gold", "red", "gold"][k]
    round_pauldron(k, s, pad, rim, lames_from=3, spikes_sw="red" if k == 3 else None)


# --- The Mage ---------------------------------------------------------------------

def cone(r, h, sw, bend=0.0, sides=10, y0=BASE + 0.02):
    """A wizard's cone from a ring of radius r up h, its tip flopped back."""
    m = mark()
    n = 6
    prof = []
    for i in range(n + 1):
        t = i / n
        prof.append((y0 + h * t, r * (1 - t) ** 1.1 + 0.01))
    lathe(prof, sw, sides=sides, shade=lambda y: 0.15 + 0.55 * (1 - (y - y0) / h))
    if bend:
        K.bm.verts.ensure_lookup_table()
        for v in K.bm.verts[m:]:
            t = max(0.0, (v.co.y - y0 - h * 0.5) / (h * 0.5))
            v.co.z -= bend * t * t
            v.co.y -= bend * 0.4 * t * t


def mage_helm(k):
    s = SETS[k]
    r = 0.58 * s["size"]
    whole = mark()
    cloth = ["tan", "red", "black", "black", "white"][k]
    trim = ["leather", "gold", "gold", "red", "gold"][k]
    h = 0.9 + 0.12 * k
    # The brim, wide and a little drooped, then the cone.
    lathe([(BASE - 0.04, r * 1.75), (BASE, r * 1.7), (BASE + 0.04, r * 1.05)], cloth, sides=12)
    cone(r * 1.02, h, cloth, bend=0.35 if k in (0, 3) else 0.12)
    lathe([(BASE + 0.03, r * 1.04), (BASE + 0.15, r * 0.95)], trim, sides=12)
    if k >= 2:
        # Stars (or eyes) of gold on the cone.
        for i, (a, y) in enumerate(((20, 0.45), (-35, 0.65), (60, 0.8))):
            ar = math.radians(a)
            rr = r * (1 - (y - 0.02) / h) + 0.04
            g = mark()
            gem((0, 0, 0), 0.04, 0.05, 0.03, sw="gold" if k != 3 else "red")
            place(g, rot=(0, a, 0), at=(math.sin(ar) * rr, BASE + y, math.cos(ar) * rr))
    if k == 3:
        for side in (-1, 1):
            tube([(side * r * 0.9, BASE + 0.15, 0), (side * (r + 0.2), BASE + 0.3, 0.05), (side * (r + 0.28), BASE + 0.6, 0.12)], [0.08, 0.05, 0.008], "black", sides=5)
    if k == 4:
        for i in range(7):
            a = math.radians(-90 + 30 * i)
            c = (math.sin(a) * r * 1.05, BASE + 0.1, math.cos(a) * r * 1.05)
            spike(c, 0.04, (c[0] * 1.03, BASE + 0.32 + (0.08 if i == 3 else 0.0), c[2] * 1.03), "gold", sides=3)
        gem((0, BASE + 0.12, r * 1.08), 0.08, 0.1, 0.07, sw="white")
    # The Mage's hair is tall: lift and widen the whole hat so it sits on
    # top of it rather than through it.
    place(whole, at=(0, 0.14, 0), scale=1.14)


def mage_pauldron(k):
    s = SETS[k]
    m = mark()
    if k < 3:
        # A small cloth shoulder cap: hardly more than the robe's own.
        dome(0.2, 0.08, ["tan", "red", "black"][k], ["leather", "gold", "gold"][k], segs=8)
        place(m, rot=CAP_TILT, at=(0, 0.0, 0.1))
        return
    dome(0.24, 0.12, "black" if k == 3 else "white", "red" if k == 3 else "gold")
    for i, a in enumerate((-50, -15, 20, 55)):
        ar = math.radians(a)
        spike((math.sin(ar) * 0.18, 0.06, math.cos(ar) * 0.12), 0.04, (math.sin(ar) * 0.36, 0.3 + 0.05 * (i % 2), math.cos(ar) * 0.2),
              "red" if k == 3 else "gold", sides=3)
    place(m, rot=CAP_TILT, at=(0, 0.0, 0.12))


BUILD = {
    "knight": (knight_helm, knight_pauldron),
    "ranger": (ranger_helm, ranger_pauldron),
    "mage": (mage_helm, mage_pauldron),
}

if __name__ == "__main__":
    out = ROOT + "/assets/kaykit/gear"
    for hero, (helm, pauldron) in BUILD.items():
        for name, build in (("helm", helm), ("pauldron", pauldron)):
            for k in range(len(SETS)):
                K.reset()
                build(k)
                path = "%s/%s_%s_%d.gltf" % (out, hero, name, k)
                export("%s_%s_%d" % (hero, name, k), path)
                with open(path) as f:
                    g = json.load(f)
                g["images"][0]["uri"] = "../weapons/knight_texture.png"
                with open(path, "w") as f:
                    json.dump(g, f)
