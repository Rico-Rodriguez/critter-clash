"""The Barbarian's armor: a helm and a pauldron for each of the five sets.

    python tools/art/make_barbarian_armor.py   (Blender's Python: pip install bpy)

Writes assets/kaykit/gear/barb_helm_<set>.gltf and barb_pauldron_<set>.gltf.
They are rigid props pinned to a bone (GearDB "P:file@bone"), so each is
built in its bone's own space:

- helm, on `head`: +y up, +z the face. The head is about 1.1 across and
  reaches y 0.95; the brow sits near y 0.45.
- pauldron, on `upperarm.l` / `upperarm.r`: +y runs out along the arm, +z
  is up. The two arms' x axes point opposite ways (forward on the left, back
  on the right), so a pauldron is kept symmetric in x and fits either.

Same ladder as the weapons: Gravedigger (a rusty cap, one leather pad),
Warden (clean steel, nasal, bone horns), Barrowsteel (slate, gold crest,
cheek guards, layered plates), Bloodiron (black iron, red edges, a spiked
crown, spiked plates) and Gravelight (pale steel and gold, swept horns,
huge flared plates).
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kk_mesh as K  # noqa: E402
from kk_mesh import ROOT, lathe, gem, spike, box, vert, face, export  # noqa: E402
from mathutils import Vector  # noqa: E402

SETS = [
    {"metal": "rust", "trim": "rust", "edge": "rust", "horn": "bone", "pad": "leather", "size": 0.95},
    {"metal": "steel", "trim": "steel_dark", "edge": "steel", "horn": "bone", "pad": "leather", "size": 1.0},
    {"metal": "slate", "trim": "gold", "edge": "steel", "horn": "bone", "pad": "black", "size": 1.05},
    {"metal": "steel_dark", "trim": "black", "edge": "red", "horn": "black", "pad": "red", "size": 1.1},
    {"metal": "steel", "trim": "gold", "edge": "white", "horn": "white", "pad": "gold", "size": 1.16},
]


def shell(profile, a0, a1, sw, segs=8, shade=None):
    """Part of a surface of revolution around y: profile [(y, r)], swept from
    angle a0 to a1 (degrees, 0 = +z, 90 = +x)."""
    rings = []
    for y, r in profile:
        ring = []
        for i in range(segs + 1):
            a = math.radians(a0 + (a1 - a0) * i / segs)
            ring.append(vert((r * math.sin(a), y, r * math.cos(a))))
        rings.append(ring)
    for k in range(len(rings) - 1):
        for i in range(segs):
            ta = shade(k) if shade else 0.2 + 0.5 * k / max(1, len(rings) - 1)
            tb = shade(k + 1) if shade else 0.2 + 0.5 * (k + 1) / max(1, len(rings) - 1)
            face([rings[k][i], rings[k][i + 1], rings[k + 1][i + 1], rings[k + 1][i]], sw, [ta, ta, tb, tb])


def tube(points, radii, sw, sides=6):
    """A bent cone through `points`, `radii` thick at each: a horn."""
    pts = [Vector(p) for p in points]
    rings = []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        a = d.orthogonal().normalized()
        b = d.cross(a)
        r = radii[i]
        rings.append([vert(p + (a * math.cos(q * 2 * math.pi / sides) + b * math.sin(q * 2 * math.pi / sides)) * r) for q in range(sides)])
    for k in range(len(rings) - 1):
        t0 = 0.2 + 0.6 * k / len(rings)
        t1 = 0.2 + 0.6 * (k + 1) / len(rings)
        for q in range(sides):
            j = (q + 1) % sides
            face([rings[k][q], rings[k][j], rings[k + 1][j], rings[k + 1][q]], sw, [t0, t0, t1, t1])
    if radii[-1] > 0.001:
        face(rings[-1], sw, [0.1] * sides)


def horn(side, k, s, length, up, fwd=0.0):
    """A horn from the helm's side, curving out and up (side -1 or 1)."""
    pts = []
    rad = []
    n = 6
    for i in range(n + 1):
        t = i / n
        x = side * (0.52 + length * (0.55 * t + 0.25 * t * t))
        y = 0.62 + up * (t * t) + 0.08 * t
        z = 0.05 + fwd * t * t
        pts.append((x, y, z))
        rad.append(0.11 * (1.0 - t) + 0.008)
    tube(pts, rad, s["horn"])
    # A ring where the horn leaves the helm.
    lathe_ring((side * 0.56, 0.62, 0.05), 0.12, s["trim"], (1, 0, 0))


def lathe_ring(c, r, sw, axis, w=0.04, sides=6):
    """A short band of radius r around `axis` at `c`."""
    c = Vector(c)
    ax = Vector(axis).normalized()
    tube([tuple(c - ax * w), tuple(c + ax * w)], [r, r], sw, sides)


# --- Helms ------------------------------------------------------------------

def helm(k):
    s = SETS[k]
    sz = s["size"]
    base = 0.46
    r = 0.6 * sz
    sides = 10
    # The bowl: a low cap for the scavenger, taller and more pointed up the sets.
    peak = 1.12 + 0.05 * k
    lathe([(base, r), (base + 0.18, r * 1.0), (base + 0.38, r * 0.9), (peak - 0.18, r * 0.62), (peak, r * 0.18 if k < 4 else r * 0.05)],
          s["metal"], sides=sides, shade=lambda y: 0.15 + 0.6 * (1 - (y - base) / (peak - base)))
    # The brow band.
    lathe([(base - 0.04, r * 1.06), (base + 0.1, r * 1.06)], s["trim"] if k else "leather", sides=sides)
    if k == 0:
        # A leather strap over the top and two stubs of horn.
        box((0, peak - 0.25, 0), (0.12, 0.08, r * 1.6), "leather")
        for side in (-1, 1):
            spike((side * 0.52, 0.66, 0.05), 0.08, (side * 0.78, 0.86, 0.08), "bone", sides=5)
        return
    # A nasal guard down the face.
    if k in (1, 2):
        K.plate([(-0.05, base + 0.1), (0.05, base + 0.1), (0.035, base - 0.2), (-0.035, base - 0.2)], 0.025, s["metal"])
        K.place(K.mark(), at=(0, 0, 0))
        _nasal_fix(r, base)
    # Horns, longer each set.
    if k in (1, 2, 4):
        length = {1: 0.35, 2: 0.5, 4: 0.8}[k]
        up = {1: 0.35, 2: 0.55, 4: 0.85}[k]
        for side in (-1, 1):
            horn(side, k, s, length, up, fwd=0.15 if k == 4 else 0.0)
    if k >= 2:
        # Cheek guards hang from the band on each side of the face.
        for side in (-1, 1):
            m = K.mark()
            K.plate([(0.0, 0.0), (0.2, 0.0), (0.16, -0.32), (0.02, -0.26)], 0.03, s["metal"], edges=(1,), edge_sw=s["edge"])
            K.place(m, rot=(0, side * 70, 0), at=(side * r * 0.86, base + 0.02, r * 0.38))
    if k == 2:
        # A gold crest ridge front to back.
        m = K.mark()
        K.plate([(-0.5, 0.0), (0.5, 0.0), (0.35, 0.16), (-0.35, 0.16)], 0.03, "gold")
        K.place(m, rot=(0, 90, 0), at=(0, peak - 0.1, 0))
    if k == 3:
        # A crown of red-edged spikes and two black horns sweeping forward.
        for i in range(5):
            a = math.radians(-60 + 30 * i)
            c = (math.sin(a) * r * 0.85, base + 0.3, math.cos(a) * r * 0.85)
            tip = (math.sin(a) * r * 1.05, base + 0.75 + (0.15 if i == 2 else 0.0), math.cos(a) * r * 1.05)
            spike(c, 0.09, tip, "red", sides=4)
        for side in (-1, 1):
            tube([(side * 0.5, 0.62, -0.05), (side * 0.85, 0.7, 0.0), (side * 1.0, 0.95, 0.15), (side * 0.95, 1.2, 0.35)],
                 [0.12, 0.09, 0.06, 0.01], "black")
            lathe_ring((side * 0.55, 0.62, -0.03), 0.13, "red", (1, 0, 0))
        gem((0, base + 0.2, r * 0.95), 0.07, 0.09, 0.06, sw="red")
    if k == 4:
        # A gold circlet, a pale soul stone at the brow, a tall gold spike.
        lathe([(base + 0.12, r * 1.04), (base + 0.2, r * 1.04)], "gold", sides=sides)
        gem((0, base + 0.2, r * 1.04), 0.09, 0.12, 0.08, sw="white")
        spike((0, peak - 0.05, 0), 0.08, (0, peak + 0.45, 0), "gold", sides=4)
        for side in (-1, 1):
            spike((side * 0.2, peak - 0.12, 0.0), 0.05, (side * 0.32, peak + 0.22, 0.0), "gold", sides=3)


def _nasal_fix(r, base):
    """Moves the nasal plate (the last 8 vertices) out to the face."""
    K.bm.verts.ensure_lookup_table()
    for v in K.bm.verts[-8:]:
        v.co.z += r * 1.04


# --- Pauldrons --------------------------------------------------------------

def dome(r, h, sw, rim_sw, segs=10, lip=0.04):
    """A shallow bowl along +y, open below: radius r at y 0, rising h."""
    lathe([(0.0, r), (h * 0.45, r * 0.88), (h * 0.8, r * 0.6), (h, r * 0.2)], sw, sides=segs,
          shade=lambda y: 0.15 + 0.55 * (1 - y / h))
    lathe([(-lip, r * 1.04), (0.0, r * 1.04)], rim_sw, sides=segs)


# Up and out from the shoulder joint, in the arm bone's space: +z in the
# T-pose, turned a little back toward the neck so it caps the shoulder.
CAP_TILT = (105.0, 0.0, 0.0)


def pauldron(k):
    s = SETS[k]
    sz = s["size"]
    m = K.mark()
    if k == 0:
        # A scrap of hide over one shoulder, tied on with rope.
        dome(0.22, 0.12, "leather", "tan", segs=7)
        K.place(m, rot=CAP_TILT, at=(0, 0.0, 0.13))
        return
    # Stacked lames: each a wider, lower bowl under the last.
    lames = 1 + (k >= 1) + (k >= 2) + (k >= 4)
    for i in range(lames):
        mm = K.mark()
        r = (0.22 + 0.012 * k) * sz * (1.0 + 0.08 * i)
        dome(r, 0.15 + 0.02 * k, s["metal"], s["edge"] if k >= 2 else s["trim"])
        K.place(mm, at=(0, -0.07 * i, 0))
    if k == 1:
        for a in range(0, 360, 90):
            ar = math.radians(a)
            box((math.cos(ar) * 0.2, 0.08, math.sin(ar) * 0.2), (0.04, 0.04, 0.04), "steel_dark")
    if k == 2:
        g = K.mark()
        gem((0, 0, 0), 0.06, 0.06, 0.05, sw="gold")
        K.place(g, rot=(-90, 0, 0), at=(0, 0.19, 0))
    if k >= 3:
        # A spike out of the crown, two more beside it.
        spike((0, 0.15, 0), 0.07, (0, 0.5 + 0.08 * (k == 4), 0), "red" if k == 3 else "gold", sides=4)
        for a in (-1, 1):
            spike((a * 0.13, 0.11, 0), 0.05, (a * 0.32, 0.36, 0), "black" if k == 3 else "gold", sides=4)
    if k == 4:
        # A flared gold wing round the bottom lame.
        lathe([(-0.24, 0.42 * sz), (-0.2, 0.36 * sz)], "gold", sides=10)
    K.place(m, rot=CAP_TILT, at=(0, 0.0, 0.13))


if __name__ == "__main__":
    out = ROOT + "/assets/kaykit/gear"
    os.makedirs(out, exist_ok=True)
    for name, build in (("helm", helm), ("pauldron", pauldron)):
        for k in range(len(SETS)):
            K.reset()
            build(k)
            path = "%s/barb_%s_%d.gltf" % (out, name, k)
            export("barb_%s_%d" % (name, k), path)
            # One texture for all our props: the weapons folder's copy.
            with open(path) as f:
                g = json.load(f)
            g["images"][0]["uri"] = "../weapons/knight_texture.png"
            with open(path, "w") as f:
                json.dump(g, f)
