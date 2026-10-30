"""The Knight's plate armour, sword and shield in the five sets: a sample of
the remade hero gear, built to sit on the adult hero build (Actor.HERO_BUILD).

    python tools/art/make_knight_plate.py [set ...]   (Blender's Python: pip install bpy)

Writes, for each set k:
- assets/kaykit/gear/knight_plate_helm_<k>.gltf      on `head`
- assets/kaykit/gear/knight_plate_cuirass_<k>.gltf   on `chest`
- assets/kaykit/gear/knight_plate_fauld_<k>.gltf     on `hips`
- assets/kaykit/gear/knight_plate_pauldron_<k>.gltf  on `upperarm.l` / `.r`
- assets/kaykit/gear/knight_plate_vambrace_<k>.gltf  on `lowerarm.l` / `.r`
- assets/kaykit/gear/knight_plate_greave_<k>.gltf    on `lowerleg.l` / `.r`
- assets/kaykit/weapons/knight_plate_sword_<k>.gltf  in the hand
- assets/kaykit/weapons/knight_plate_shield_<k>.gltf on the off hand

Each piece is built in its bone's own space (KayKit Rig_Medium):
- head, chest, hips: +y up, +z the front; the chest bone starts at the
  bottom of the ribs, the hips bone at the top of the legs.
- upperarm / lowerarm: +y out along the arm, +z up; x points forward on
  one arm and back on the other, so arm pieces are symmetric in x.
- lowerleg: +y down the shin from the knee, +z toward the calf.

Plates are thick curved shells with smooth shading, so they read as forged
metal next to the KayKit body; trims, rivets and spikes stay faceted.

The ladder, one look per set: Gravedigger (rusty half-plate over leather,
an open kettle helm), Warden (clean steel, a visored bascinet), Barrowsteel
(slate plate with gold trim, a crested sallet), Bloodiron (black iron with
red edges, spikes and a horned helm), Gravelight (pale steel and gold, a
winged great helm and a sun on the chest).
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kk_mesh as K  # noqa: E402
from kk_mesh import ROOT, lathe, gem, spike, box, plate, mark, place, export, vert, face  # noqa: E402

SETS = [
    {"metal": "rust", "trim": "rust", "edge": "rust", "under": "leather", "cloth": "tan", "jewel": None, "spikes": 0},
    {"metal": "steel", "trim": "steel_dark", "edge": "steel", "under": "leather", "cloth": "tan", "jewel": None, "spikes": 0},
    {"metal": "slate", "trim": "gold", "edge": "steel", "under": "black", "cloth": "black", "jewel": "red", "spikes": 0},
    {"metal": "steel_dark", "trim": "black", "edge": "red", "under": "black", "cloth": "red", "jewel": "red", "spikes": 1},
    {"metal": "white", "trim": "gold", "edge": "gold", "under": "steel", "cloth": "white", "jewel": "white", "spikes": 1},
]


def _ring(y, rx, rz, a0, a1, segs, cx=0.0, cz=0.0):
    out = []
    for i in range(segs + 1):
        a = math.radians(a0 + (a1 - a0) * i / segs)
        out.append(vert((cx + rx * math.sin(a), y, cz + rz * math.cos(a))))
    return out


def shell(profile, a0, a1, sw, th=0.025, segs=10, edge_sw=None, sq=(1.0, 1.0), smooth=True, full=False):
    """A forged plate: part of a surface around y, profile [(y, r)] bottom to
    top, swept from angle a0 to a1 (degrees, 0 = +z, 90 = +x), `th` thick.
    `sq` squashes it in x and z. The cut edges take `edge_sw` (a trim)."""
    edge_sw = edge_sw or sw
    n = len(profile)
    if full:
        a1 = a0 + 360.0
    outer = [_ring(y, r * sq[0], r * sq[1], a0, a1, segs) for y, r in profile]
    inner = [_ring(y, (r - th) * sq[0], (r - th) * sq[1], a0, a1, segs) for y, r in profile]
    cols = segs if full else segs + 1

    def t_of(k):
        return 0.15 + 0.55 * (1 - k / max(1, n - 1))

    for k in range(n - 1):
        for i in range(segs):
            j = i + 1
            f = face([outer[k][i], outer[k][j], outer[k + 1][j], outer[k + 1][i]], sw, [t_of(k), t_of(k), t_of(k + 1), t_of(k + 1)])
            f.smooth = smooth
            g = face([inner[k][j], inner[k][i], inner[k + 1][i], inner[k + 1][j]], "black", [0.6] * 4)
            g.smooth = smooth
    # Rims: bottom and top rings, and the two cut sides.
    for k, flip in ((0, False), (n - 1, True)):
        for i in range(segs):
            q = [outer[k][i], outer[k][i + 1], inner[k][i + 1], inner[k][i]]
            face(list(reversed(q)) if flip else q, edge_sw, [0.1, 0.1, 0.3, 0.3])
    if not full:
        for k in range(n - 1):
            face([outer[k][0], outer[k + 1][0], inner[k + 1][0], inner[k][0]], edge_sw, [0.1, 0.1, 0.3, 0.3])
            face([outer[k][segs], inner[k][segs], inner[k + 1][segs], outer[k + 1][segs]], edge_sw, [0.1, 0.3, 0.3, 0.1])
    del cols


def rim(y, r, a0, a1, sw, w=0.03, out=0.012, segs=10, sq=(1.0, 1.0)):
    """A rolled edge laid on a shell at height y: a thin band standing out."""
    shell([(y - w / 2, r + out), (y + w / 2, r + out)], a0, a1, sw, th=out + 0.012, segs=segs, sq=sq, smooth=True)


def rivet(p, r=0.018, sw="steel"):
    m = mark()
    lathe([(0, r), (r * 0.6, r * 0.8), (r, 0.0)], sw, sides=5)
    place(m, at=p)


def stud(c, normal, r, h, sw, sides=5):
    """A spike or stud from point c along `normal`."""
    c = K.Vector(c)
    nv = K.Vector(normal).normalized()
    spike(c, r, c + nv * h, sw, sides=sides)


def _on(r, a, y, sq=(1.0, 1.0), out=0.0):
    a = math.radians(a)
    return ((r + out) * sq[0] * math.sin(a), y, (r + out) * sq[1] * math.cos(a))


# --- Body plates ---------------------------------------------------------------

def cuirass(k):
    s = SETS[k]
    sq = (1.0, 0.92)
    # Ribs to collar; the chest swells and flattens toward the neck.
    prof = [(-0.15, 0.335), (-0.05, 0.345), (0.06, 0.365), (0.17, 0.375), (0.25, 0.355), (0.3, 0.3), (0.33, 0.22)]
    if k == 0:
        # A breastplate only, held on by straps over a leather jerkin.
        shell(prof[1:5], -62, 62, s["metal"], segs=8, sq=sq)
        for x in (-0.18, 0.18):
            box((x, 0.31, -0.02), (0.07, 0.03, 0.6), "leather")
        rim(-0.02, 0.37, -40, 40, "leather", w=0.05, sq=sq)
        return
    front = (-68, 68)
    back = (112, 248)
    shell(prof, *front, s["metal"], segs=12, sq=sq, edge_sw=s["trim"])
    shell(prof, *back, s["metal"], segs=12, sq=sq, edge_sw=s["trim"])
    # The plackart: a second plate over the belly, and the edge rolls.
    shell([(-0.17, 0.36), (-0.07, 0.365), (0.04, 0.375)], -55, 55, s["metal"], segs=10, sq=sq, edge_sw=s["trim"])
    rim(0.31, 0.29, front[0], front[1], s["trim"], sq=sq)
    if k >= 2:
        rim(0.04, 0.375, -55, 55, s["trim"], sq=sq)
        for a in (-62, 62, 118, 242):
            for y in (-0.08, 0.12, 0.25):
                rivet(_on(0.37, a, y, sq, 0.005), sw=s["trim"])
    if k >= 3:
        # A raised keel down the middle.
        m = mark()
        plate([(-0.03, -0.12), (0.03, -0.12), (0.02, 0.3), (-0.02, 0.3)], 0.02, s["edge"], [1, 3], s["edge"])
        place(m, rot=(-6, 0, 0), at=(0, 0, 0.36))
        for x in (-1, 1):
            stud((x * 0.18, 0.2, 0.31), (x * 0.4, 0.2, 1), 0.03, 0.08, s["edge"])
    if k == 4:
        # A gold sun on the breast.
        m = mark()
        for i in range(12):
            a = i * math.pi / 6
            ln = 0.13 if i % 2 == 0 else 0.09
            spike((0, 0, 0), 0.025, (ln * math.cos(a), ln * math.sin(a), 0), "gold", sides=4)
        gem((0, 0, 0.01), 0.05, 0.05, 0.035, sw="white")
        place(m, rot=(-8, 0, 0), at=(0, 0.17, 0.355))
    elif k == 2:
        gem((0, 0.18, 0.355), 0.035, 0.045, 0.03, sw=s["jewel"])
    elif k == 3:
        gem((0, 0.2, 0.37), 0.04, 0.05, 0.035, sw="red")


def fauld(k):
    """Lames hanging from the belt, front and back, flaring out."""
    s = SETS[k]
    if k == 0:
        # A leather skirt with two rusty tassets.
        shell([(0.12, 0.40), (0.4, 0.36)], -70, 70, "leather", segs=10, sq=(1.0, 0.95))
        shell([(0.12, 0.40), (0.4, 0.36)], 110, 250, "leather", segs=10, sq=(1.0, 0.95))
        return
    n = {1: 2, 2: 3, 3: 3, 4: 4}[k]
    for i in range(n):
        top = 0.42 - i * 0.085
        bot = top - 0.11
        r0 = 0.345 + i * 0.022
        for a0, a1 in ((-64, 64), (116, 244)):
            shell([(bot, r0 + 0.025), (top, r0)], a0, a1, s["metal"], segs=10, sq=(1.0, 0.95), edge_sw=s["trim"])
    if k >= 2:
        # A cloth tabard falls between the front lames.
        m = mark()
        plate([(-0.12, 0.0), (0.12, 0.0), (0.1, -0.34), (0.0, -0.4), (-0.1, -0.34)], 0.012, s["cloth"])
        place(m, rot=(6, 0, 0), at=(0, 0.42, 0.39))


def pauldron(k):
    """Shoulder lames over the top of the arm (+z up, +y out along it). They
    stand out past the cuirass, so the shoulders are the widest point."""
    s = SETS[k]
    if k == 0:
        shell([(0.02, 0.17), (0.1, 0.21), (0.2, 0.2)], -85, 85, "leather", segs=8)
        rivet((0, 0.1, 0.215), sw="rust")
        return
    a = 92 + 6 * k
    g = 1.0 + 0.05 * k
    # The cop over the joint, then lames stepping down the arm.
    shell([(0.0, 0.1 * g), (0.05, 0.2 * g), (0.12, 0.245 * g), (0.18, 0.25 * g)], -a, a, s["metal"], segs=12, edge_sw=s["trim"])
    for i in range(1 + min(k, 3)):
        y = 0.17 + i * 0.06
        shell([(y, 0.255 * g - i * 0.01), (y + 0.075, 0.245 * g - i * 0.01)], -a + 8, a - 8, s["metal"], segs=12, edge_sw=s["trim"])
    if k >= 2:
        rim(0.17, 0.25 * g, -a, a, s["trim"], segs=12)
        rivet((0, 0.08, 0.235 * g), sw=s["trim"])
    if k >= 3:
        # A haute-piece standing up to guard the neck, spiked.
        m = mark()
        plate([(-0.15, 0.0), (0.15, 0.0), (0.13, 0.13), (-0.13, 0.13)], 0.015, s["metal"], [1, 2, 3], s["edge"])
        place(m, rot=(90, 0, 0), at=(0, 0.04, 0.22 * g))
        for x in (-0.07, 0.07):
            stud((x, 0.12, 0.25 * g), (x * 2, 0.1, 1), 0.03, 0.12, s["edge"])
    if k == 4:
        for i, x in enumerate((-0.1, 0.0, 0.1)):
            stud((x, 0.1, 0.27 * g), (x * 3, -0.2, 1), 0.025, 0.14 + 0.05 * (i == 1), "gold", sides=4)


def vambrace(k):
    """A tube round the forearm, wrist to elbow, with a couter flange."""
    s = SETS[k]
    sw = "leather" if k <= 1 else s["metal"]
    shell([(0.04, 0.145), (0.13, 0.15), (0.22, 0.14)], 0, 0, sw, segs=12, full=True, edge_sw=s["trim"] if k >= 2 else sw)
    if k >= 1:
        shell([(-0.03, 0.15), (0.02, 0.17), (0.05, 0.155)], 0, 0, s["metal"], segs=12, full=True, edge_sw=s["trim"])
    if k >= 2:
        rim(0.2, 0.145, 0, 360, s["trim"], segs=12)
    if k >= 3:
        for a in (0, 120, 240):
            p = _on(0.15, a, 0.13)
            stud(p, (p[0], 0, p[2]), 0.022, 0.07, s["edge"])


def greave(k):
    """A shin plate and a knee cop. Front is -z in the lower leg's space."""
    s = SETS[k]
    if k == 0:
        shell([(0.02, 0.15), (0.15, 0.14)], 110, 250, "leather", segs=8)
        for y in (0.05, 0.12):
            rim(y, 0.15, 110, 250, "leather", w=0.02)
        return
    shell([(0.0, 0.15), (0.08, 0.155), (0.17, 0.15)], 95, 265, s["metal"], segs=10, edge_sw=s["trim"])
    # The knee cop, a small dome over the joint.
    m = mark()
    lathe([(0.0, 0.11), (0.03, 0.105), (0.06, 0.07), (0.075, 0.0)], s["metal"], sides=10)
    place(m, rot=(-90, 0, 0), at=(0, -0.03, -0.12))
    if k >= 2:
        rim(0.15, 0.152, 100, 260, s["trim"])
    if k >= 3:
        stud((0, -0.03, -0.2), (0, 0.1, -1), 0.035, 0.1, s["edge"])


def helm(k):
    """Head space: the head is about 1.1 across, the brow near y 0.45,
    the crown near y 1.0 (KayKit's head, before the adult build shrinks it)."""
    s = SETS[k]
    sw = s["metal"]
    if k == 0:
        # A kettle hat: a rusty bowl with a wide brim, and a leather coif.
        shell([(0.42, 0.6), (0.62, 0.62), (0.82, 0.55), (0.98, 0.38), (1.06, 0.14), (1.08, 0.02)], 0, 0, sw, segs=14, full=True, th=0.03)
        shell([(0.4, 0.78), (0.44, 0.74)], 0, 0, sw, segs=14, full=True, th=0.15)
        shell([(-0.05, 0.56), (0.3, 0.6), (0.43, 0.6)], 120, 240, "leather", segs=8)
        return
    # The skull: a smooth dome, taller and more pointed up the ladder. Built
    # at the head's size, then drawn in so it reads as a helm, not a bucket.
    m0 = mark()
    _helm_shapes(k, s, sw)
    if k >= 2:
        # Closed helms cover the whole head, so they can be smaller than it.
        place(m0, at=(0, 0.06, 0), scale=(0.86, 0.88, 0.86))


def _helm_shapes(k, s, sw):
    peak = 1.12 + 0.05 * k
    shell([(0.3, 0.55), (0.5, 0.58), (0.72, 0.56), (0.9, 0.47), (1.02, 0.32), (peak - 0.02, 0.11), (peak, 0.02)], 0, 0, sw, segs=16, full=True, th=0.03)
    rim(0.34, 0.555, 0, 360, s["trim"], w=0.06, segs=16)
    if k == 1:
        # A bascinet: a nasal and mail falling to the shoulders.
        m = mark()
        plate([(-0.05, 0.0), (0.05, 0.0), (0.04, -0.3), (-0.04, -0.3)], 0.02, sw)
        place(m, at=(0, 0.62, 0.58))
        # Mail round the sides and back of the neck.
        shell([(0.02, 0.56), (0.32, 0.555)], 55, 305, "steel_dark", segs=14)
        return
    # A closed face: a visor with an eye slit and breaths.
    vis_top = 0.5
    shell([(0.04, 0.46), (0.16, 0.55), (0.32, 0.585), (vis_top - 0.04, 0.595)], -80, 80, sw, segs=14, edge_sw=s["trim"])
    shell([(vis_top + 0.08, 0.6), (0.68, 0.585)], -80, 80, sw, segs=14, edge_sw=s["trim"])
    # The slit, dark (or burning on Bloodiron and Gravelight).
    slit = "black" if k == 2 else ("red" if k == 3 else "white")
    shell([(vis_top - 0.04, 0.57), (vis_top + 0.08, 0.57)], -70, 70, slit, segs=12, th=0.02)
    for x in (-0.14, -0.07, 0.07, 0.14):
        box((x, 0.24, 0.585), (0.025, 0.1, 0.03), "black")
    # Gorget round the neck.
    shell([(0.0, 0.44), (0.05, 0.47)], 0, 0, sw, segs=14, full=True, edge_sw=s["trim"])
    if k == 2:
        # A gold crest along the skull.
        m = mark()
        plate([(-0.5, 0.0), (0.5, 0.0), (0.36, 0.18), (0.0, 0.26), (-0.36, 0.18)], 0.03, "gold", [1, 2, 3, 4], "gold")
        place(m, rot=(0, 90, 0), at=(0, peak - 0.18, 0))
    if k == 3:
        for x in (-1, 1):
            K_tube([(x * 0.5, 0.78, 0.0), (x * 0.76, 0.9, -0.05), (x * 0.88, 1.16, -0.02), (x * 0.82, 1.38, 0.08)], [0.1, 0.08, 0.05, 0.0], "black")
        for i in range(5):
            a = -50 + i * 25
            p = _on(0.5, a, 0.92)
            stud(p, (p[0], 0.6, p[2]), 0.04, 0.16, "red")
    if k == 4:
        # A gold crown and swept wings.
        for i in range(10):
            a = i * 36
            p = _on(0.46, a, 0.96)
            stud(p, (p[0] * 0.3, 1, p[2] * 0.3), 0.05, 0.2 if i % 2 == 0 else 0.12, "gold", sides=4)
        rim(0.92, 0.46, 0, 360, "gold", w=0.07, segs=16)
        for x in (-1, 1):
            m = mark()
            pts = [(0.0, 0.0), (0.1, -0.05), (0.55, 0.25), (0.62, 0.55), (0.42, 0.42), (0.48, 0.7), (0.26, 0.48), (0.24, 0.66), (0.08, 0.35)]
            plate([(px * x, py) for px, py in (pts if x > 0 else list(reversed(pts)))], 0.02, "white", [], "white")
            place(m, rot=(0, -25 * x, 0), at=(x * 0.55, 0.7, -0.05))
        gem((0, 0.82, 0.58), 0.06, 0.07, 0.05, sw="white")


def K_tube(points, radii, sw, sides=6):
    from make_barbarian_armor import tube
    tube(points, radii, sw, sides)


# --- Sword and shield -----------------------------------------------------------

def sword(k):
    """A longsword along +y, the grip at the origin, flats toward +-z."""
    s = SETS[k]
    blade_sw = {0: "rust", 1: "steel", 2: "steel", 3: "steel_dark", 4: "white"}[k]
    edge_sw = {0: "rust", 1: "white", 2: "white", 3: "red", 4: "white"}[k]
    length = 1.05 + 0.06 * k
    w = 0.075 + 0.006 * k
    y0 = 0.2
    pts = [(-w, y0), (w, y0), (w * 0.95, y0 + length * 0.78), (0, y0 + length), (-w * 0.95, y0 + length * 0.78)]
    plate(pts, 0.022, blade_sw, [1, 2, 3, 4] if k else [], edge_sw)
    # The fuller.
    plate([(-w * 0.22, y0 + 0.04), (w * 0.22, y0 + 0.04), (w * 0.1, y0 + length * 0.66), (-w * 0.1, y0 + length * 0.66)],
          0.026, "black" if k != 4 else "gold")
    # Guard, swept on the higher sets.
    gw = 0.22 + 0.03 * k
    box((0, y0 - 0.02, 0), (gw * 2, 0.05, 0.07), s["trim"] if k else "rust")
    if k >= 2:
        for x in (-1, 1):
            spike((x * gw, y0 - 0.02, 0), 0.035, (x * (gw + 0.08), y0 + 0.08 + 0.02 * k, 0), s["trim"], sides=5)
    if k >= 3:
        gem((0, y0 - 0.02, 0.04), 0.035, 0.035, 0.03, sw="red" if k == 3 else "white")
        gem((0, y0 - 0.02, -0.04), 0.035, 0.035, 0.03, sw="red" if k == 3 else "white", facing=-1)
    # Grip wrapped in leather, and the pommel.
    lathe([(-0.17, 0.032), (-0.1, 0.036), (0.0, 0.036), (y0 - 0.05, 0.032)], "leather" if k < 3 else "black", sides=6)
    for y in (-0.12, -0.06, 0.0, 0.06):
        lathe([(y, 0.038), (y + 0.015, 0.038)], s["trim"] if k >= 2 else "leather", sides=6)
    lathe([(-0.27, 0.0), (-0.25, 0.04), (-0.21, 0.055), (-0.18, 0.04), (-0.17, 0.03)], s["trim"] if k else "rust", sides=8)
    if k == 4:
        gem((0, -0.21, 0.05), 0.03, 0.03, 0.03, sw="white")


def shield(k):
    """A heater shield, in the plane of x-y, its face toward -z."""
    s = SETS[k]
    hw = 0.36 + 0.02 * k
    top = 0.48 + 0.02 * k
    bot = -0.56 - 0.03 * k
    outline = [(-hw, top), (-hw, 0.05), (-hw * 0.78, -0.25), (-hw * 0.4, bot * 0.82), (0.0, bot), (hw * 0.4, bot * 0.82), (hw * 0.78, -0.25), (hw, 0.05), (hw, top)]
    outline = list(reversed(outline))
    face_sw = {0: "wood", 1: "steel", 2: "slate", 3: "black", 4: "white"}[k]
    plate(outline, 0.04, face_sw, list(range(len(outline))), s["trim"] if k else "rust", edge_out=0.03)
    # A raised field: the heraldry. A cross for the Warden, a chevron, a
    # burning cross, a gold sun.
    m = mark()
    if k == 0:
        for x in (-0.18, 0.0, 0.18):
            box((x, -0.02, 0), (0.025, 0.95, 0.02), "black")
        box((0, 0.3, 0), (0.75, 0.06, 0.03), "rust")
        box((0, -0.25, 0), (0.6, 0.06, 0.03), "rust")
    elif k == 1:
        box((0, -0.03, 0), (0.12, 0.9, 0.03), "red")
        box((0, 0.18, 0), (0.6, 0.12, 0.03), "red")
    elif k == 2:
        plate([(-0.32, -0.12), (0.0, 0.18), (0.32, -0.12), (0.32, 0.02), (0.0, 0.32), (-0.32, 0.02)], 0.02, "gold")
        gem((0, -0.25, 0.02), 0.06, 0.07, 0.05, sw="red")
    elif k == 3:
        box((0, -0.03, 0), (0.14, 0.95, 0.03), "red")
        box((0, 0.18, 0), (0.62, 0.14, 0.03), "red")
        for p in ((-0.24, 0.36), (0.24, 0.36), (-0.24, -0.15), (0.24, -0.15), (0.0, -0.5)):
            spike((p[0], p[1], 0), 0.04, (p[0], p[1], 0.14), "steel", sides=4)
    else:
        for i in range(16):
            a = i * math.pi / 8
            ln = 0.3 if i % 2 == 0 else 0.2
            spike((0, 0, 0), 0.04, (ln * math.cos(a), ln * math.sin(a), 0), "gold", sides=4)
        gem((0, 0, 0.01), 0.09, 0.09, 0.06, sw="white")
    place(m, rot=(0, 180, 0), at=(0, 0.0 if k != 4 else 0.02, -0.045))
    # The boss of rivets round the rim from Warden up.
    if k >= 1:
        for x, y in ((-hw * 0.85, top * 0.85), (hw * 0.85, top * 0.85), (-hw * 0.85, 0.0), (hw * 0.85, 0.0)):
            m = mark()
            lathe([(0, 0.025), (0.015, 0.02), (0.025, 0.0)], s["trim"], sides=5)
            place(m, rot=(-90, 0, 0), at=(x, y, -0.04))


def sword_dark():
    """The dark plate mockup's longsword: a long bright blade, a gold
    cross-guard and pommel, a black grip (make_dark_plate.py)."""
    length, w, y0 = 1.3, 0.07, 0.2
    pts = [(-w, y0), (w, y0), (w * 0.9, y0 + length * 0.82), (0, y0 + length), (-w * 0.9, y0 + length * 0.82)]
    plate(pts, 0.02, "steel", [1, 2, 3, 4], "white")
    plate([(-w * 0.2, y0 + 0.03), (w * 0.2, y0 + 0.03), (w * 0.08, y0 + length * 0.6), (-w * 0.08, y0 + length * 0.6)], 0.024, "steel_dark")
    box((0, y0 - 0.02, 0), (0.42, 0.05, 0.06), "gold")
    for x in (-1, 1):
        spike((x * 0.21, y0 - 0.02, 0), 0.03, (x * 0.27, y0 + 0.05, 0), "gold", sides=5)
    m = mark()
    lathe([(0.0, 0.0), (0.05, 0.035), (0.11, 0.0)], "gold", sides=4)
    place(m, rot=(0, 0, 0), at=(0, y0 - 0.02 + 0.02, 0))
    lathe([(-0.2, 0.03), (-0.1, 0.034), (0.0, 0.034), (y0 - 0.05, 0.03)], "black", sides=6)
    for y in (-0.15, -0.08, -0.01, 0.06):
        lathe([(y, 0.036), (y + 0.012, 0.036)], "leather", sides=6)
    lathe([(-0.31, 0.0), (-0.29, 0.04), (-0.25, 0.055), (-0.22, 0.04), (-0.2, 0.03)], "gold", sides=8)


def shield_dark():
    """A black heater with a silver rim and a silver four-pointed star."""
    hw, top, bot = 0.37, 0.5, -0.6
    outline = [(-hw, top), (-hw, 0.05), (-hw * 0.78, -0.25), (-hw * 0.4, bot * 0.82), (0.0, bot), (hw * 0.4, bot * 0.82), (hw * 0.78, -0.25), (hw, 0.05), (hw, top)]
    outline = list(reversed(outline))
    plate(outline, 0.04, "black", list(range(len(outline))), "steel", edge_out=0.03)
    m = mark()
    for i in range(8):
        a = i * math.pi / 4
        ln = 0.3 if i % 2 == 0 else 0.11
        spike((0, 0, 0), 0.05 if i % 2 == 0 else 0.03, (ln * math.sin(a), ln * math.cos(a), 0), "steel", sides=4)
    gem((0, 0, 0.01), 0.05, 0.05, 0.04, sw="white")
    place(m, rot=(0, 180, 0), at=(0, 0.02, -0.045))
    for x, y in ((-hw * 0.85, top * 0.85), (hw * 0.85, top * 0.85), (-hw * 0.85, 0.0), (hw * 0.85, 0.0), (0.0, bot * 0.8)):
        m = mark()
        lathe([(0, 0.025), (0.015, 0.02), (0.025, 0.0)], "steel", sides=5)
        place(m, rot=(-90, 0, 0), at=(x, y, -0.04))


PIECES = {
    "helm": ("gear", helm), "cuirass": ("gear", cuirass), "fauld": ("gear", fauld),
    "pauldron": ("gear", pauldron), "vambrace": ("gear", vambrace), "greave": ("gear", greave),
    "sword": ("weapons", sword), "shield": ("weapons", shield),
}


# Refit for the new hero body (make_hero_body.py): its bones are longer and
# its head and limbs slimmer than KayKit's, so each piece is scaled (x, y, z)
# and moved in its bone's space. `--body` writes them as hero_plate_*.
BODY_FIT = {
    "helm": ((0.36, 0.36, 0.36), (0, 0.0, 0.0)), "cuirass": ((0.8, 1.2, 0.85), (0, -0.2, 0.0)),
    "fauld": ((0.85, 1.25, 0.85), (0, -0.32, 0.0)), "pauldron": ((0.85, 0.85, 0.85), (0, 0.0, 0.0)),
    "vambrace": ((0.55, 1.6, 0.55), (0, 0.0, 0.0)), "greave": ((0.65, 2.9, 0.65), (0, 0.0, 0.0)),
}


if __name__ == "__main__":
    if "--dark" in sys.argv:
        for name, fn in (("sword", sword_dark), ("shield", shield_dark)):
            K.reset()
            fn()
            export("dark_plate_" + name, os.path.join(ROOT, "assets", "kaykit", "weapons", "dark_plate_%s.gltf" % name))
        sys.exit(0)
    body = "--body" in sys.argv
    ks = [int(a) for a in sys.argv[1:] if a != "--body"] or list(range(len(SETS)))
    prefix = "hero_plate" if body else "knight_plate"
    for k in ks:
        for name, (where, fn) in PIECES.items():
            if body and name not in BODY_FIT:
                continue
            K.reset()
            fn(k)
            if body:
                sc, at = BODY_FIT[name]
                place(0, at=at, scale=sc)
            path = os.path.join(ROOT, "assets", "kaykit", where, "%s_%s_%d.gltf" % (prefix, name, k))
            export("%s_%s_%d" % (prefix, name, k), path)
            if where == "gear":
                # One texture for all our props: the weapons folder's copy.
                with open(path) as f:
                    g = json.load(f)
                g["images"][0]["uri"] = "../weapons/knight_texture.png"
                with open(path, "w") as f:
                    json.dump(g, f)
