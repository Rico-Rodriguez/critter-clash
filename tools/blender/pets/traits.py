# The small designed traits a bred pet shows for each part it inherited
# (horns, a crest, a lure, ears...). The pet keeps its body parent's whole
# model; the inherited region takes the donor's colours (fx/pet_skin.gdshader)
# and wears one of these (core/pet_parts.gd mounts them).
# Writes assets/sidekicks/pet_traits.glb: one mesh per "<donor>_<slot>".
# Same axes as the pets: -Y forward, Z up. Each trait is drawn at unit size,
# origin at its mount point:
#   head  - for a head 1 wide, origin on the crown, growing up (+Z)
#   wings - for a back 1 wide, origin between the shoulders, a pair (+-X)
#   tail  - for a body 1 long, origin at the tail's root or tip, growing back (+Y)
# Run: /tmp/claude-0/bvenv/bin/python tools/blender/pets/traits.py
import os, sys, math
import bpy
sys.path.insert(0, os.path.dirname(__file__))
from common import reset, mat, tube, blob, cone, sheet, mirror_x, _apply

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "..", "assets", "sidekicks", "pet_traits.glb")

reset()


def glow(name, hexcol, strength=2.5):
    m = mat(name, hexcol, 0.4)
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Emission Color"].default_value = b.inputs["Base Color"].default_value
    b.inputs["Emission Strength"].default_value = strength
    return m


def join(name, objs):
    for o in objs:
        _apply(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = name
    o.data.name = name
    return o


def wing_pair(name, membrane, strut, tip=None):
    """Two small folded winglets: a strut arm and a membrane behind it."""
    out = []
    for side in (1, -1):
        s = side
        parts = [
            cone(f"{name}_arm{s}", (0.12 * s, 0.0, 0.0), (0.42 * s, 0.18, 0.32), 0.05, strut, bend=(0.06 * s, 0.0, 0.1)),
            sheet(f"{name}_web{s}", [(0.14 * s, 0.02, 0.02), (0.42 * s, 0.18, 0.32), (0.5 * s, 0.42, 0.12),
                (0.34 * s, 0.5, -0.02), (0.18 * s, 0.34, -0.04)], membrane, 0.02),
        ]
        if tip:
            parts.append(cone(f"{name}_claw{s}", (0.42 * s, 0.18, 0.32), (0.47 * s, 0.1, 0.42), 0.025, tip))
        out += parts
    return out


# --- Ember Drake --------------------------------------------------------------
HORN = mat("t_horn", "eadcbf", 0.6)
HORN_D = mat("t_horn_d", "a8977a", 0.6)
SCALE = mat("t_drake", "b9472a")
WING = mat("t_drake_wing", "8e2c22")
CLAW = mat("t_claw", "2b2523", 0.5)

parts = []
for s in (1, -1):
    parts.append(cone(f"dh{s}", (0.2 * s, -0.05, 0.0), (0.34 * s, 0.42, 0.34), 0.09, HORN, n=8, bend=(0.04 * s, 0.0, 0.16)))
    parts.append(cone(f"dh2{s}", (0.36 * s, 0.08, -0.08), (0.52 * s, 0.3, 0.02), 0.045, HORN_D, n=6))
join("drake_head", parts)
join("drake_wings", wing_pair("dw", WING, SCALE, CLAW))
# A spade tip on a short length of scaled tail.
join("drake_tail", [
    tube("dt", [((0, 0.0, 0.0), 0.06, 0.05), ((0, 0.14, -0.01), 0.045, 0.04), ((0, 0.26, 0.0), 0.03, 0.03)], SCALE, n=8),
    sheet("dts", [(0, 0.24, 0.0), (0.11, 0.3, 0.0), (0.0, 0.46, 0.0), (-0.11, 0.3, 0.0)], WING, 0.03),
    cone("dtk1", (0, 0.06, 0.04), (0, 0.1, 0.12), 0.03, HORN),
    cone("dtk2", (0, 0.16, 0.03), (0, 0.2, 0.1), 0.025, HORN),
])

# --- Storm Crow ---------------------------------------------------------------
FEATHER = mat("t_crow", "1e2331")
SHEEN = mat("t_crow_sheen", "38507a")
STORM = glow("t_storm", "8ec2ff", 1.5)


def feather(name, root, tip, w, m, side=(1, 0, 0)):
    """A flat, pointed feather from `root` to `tip`, `w` wide."""
    from mathutils import Vector
    r, t = Vector(root), Vector(tip)
    d = (t - r)
    sv = Vector(side).normalized() * w
    return sheet(name, [r, r + d * 0.35 + sv, t, r + d * 0.35 - sv], m, 0.018)


parts = []
for i, (x, lean) in enumerate([(0.0, 0.0), (0.09, 0.08), (-0.09, -0.08), (0.17, 0.16), (-0.17, -0.16)]):
    h = 0.55 - abs(x) * 1.2
    parts.append(feather(f"cc{i}", (x * 0.6, 0.0 + abs(x) * 0.3, 0.0), (x + lean, 0.36, h), 0.06, FEATHER if i % 2 else SHEEN))
parts.append(feather("ccs", (0.0, 0.05, 0.05), (0.0, 0.28, 0.42), 0.02, STORM))
join("crow_head", parts)
parts = []
for s in (1, -1):
    for i in range(3):
        parts.append(feather(f"cw{s}{i}", (0.12 * s, 0.0 + 0.04 * i, 0.0), ((0.36 + 0.06 * i) * s, 0.3 + 0.08 * i, 0.26 - 0.1 * i),
            0.07, SHEEN if i == 0 else FEATHER, side=(0, 0, 1)))
join("crow_wings", parts)
parts = [tube("ct", [((0, 0.0, 0.0), 0.05, 0.035), ((0, 0.1, 0.0), 0.04, 0.03)], FEATHER, n=8)]
for i, a in enumerate((-28, -10, 10, 28)):
    r = math.radians(a)
    parts.append(feather(f"ctf{i}", (0, 0.06, 0.0), (math.sin(r) * 0.42, 0.06 + math.cos(r) * 0.42, 0.02), 0.07,
        SHEEN if i in (1, 2) else FEATHER, side=(math.cos(r), -math.sin(r), 0)))
join("crow_tail", parts)

# --- Grave Wisp ---------------------------------------------------------------
STONE = mat("t_stone", "8e9096")
STONE_D = mat("t_stone_d", "5a5d64")
LAMP = glow("t_lamp", "86e6d8", 3.0)
IRON = mat("t_iron", "3a3c42", 0.5)

join("wisp_head", [
    tube("wl", [((0, 0.05, 0.0), 0.04, 0.04), ((0, 0.0, 0.28), 0.032, 0.032), ((0, -0.2, 0.46), 0.026, 0.026), ((0, -0.4, 0.44), 0.02, 0.02)], STONE_D, n=8),
    blob("wlc", (0, -0.42, 0.38), (0.1, 0.1, 0.05), IRON),
    blob("wlb", (0, -0.42, 0.3), (0.16, 0.16, 0.18), LAMP),
])
parts = []
for s in (1, -1):
    parts.append(sheet(f"wf{s}", [(0.1 * s, 0.0, 0.0), (0.46 * s, 0.08, 0.16), (0.52 * s, 0.3, 0.06), (0.4 * s, 0.34, -0.06), (0.12 * s, 0.2, -0.04)], LAMP, 0.02))
    parts.append(cone(f"wfr{s}", (0.1 * s, 0.0, 0.0), (0.46 * s, 0.08, 0.16), 0.03, STONE))
    parts.append(cone(f"wfr2{s}", (0.11 * s, 0.06, 0.0), (0.52 * s, 0.3, 0.06), 0.025, STONE))
join("wisp_wings", parts)
join("wisp_tail", [
    tube("wt", [((0, 0.0, 0.0), 0.06, 0.05), ((0, 0.14, 0.0), 0.045, 0.035), ((0, 0.24, 0.0), 0.03, 0.025)], STONE, n=8),
    sheet("wtf", [(0, 0.22, 0.0), (0.0, 0.34, 0.22), (0.0, 0.44, 0.24), (0.0, 0.42, 0.0), (0.0, 0.44, -0.24), (0.0, 0.34, -0.22)], LAMP, 0.025),
])

# --- Gilded Mimic -------------------------------------------------------------
GOLD = mat("t_gold", "e2aa3c", 0.35)
GOLD_D = mat("t_gold_d", "a3712a", 0.4)
RUBY = glow("t_ruby", "e0344a", 0.6)

parts = [tube("mcr", [((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.04), 0.04, 0.05) for a in [i * math.pi / 8 for i in range(17)]], GOLD, n=6, sub=0, cap0=False, cap1=False)]
for i in range(5):
    a = -math.pi / 2 + (i - 2) * 0.6
    parts.append(cone(f"mcs{i}", (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.06), (math.cos(a) * 0.32, math.sin(a) * 0.32, 0.26 - abs(i - 2) * 0.04), 0.05, GOLD_D if i % 2 else GOLD, n=4))
parts.append(blob("mcg", (0, -0.31, 0.1), (0.09, 0.05, 0.09), RUBY))
join("mimic_head", parts)
parts = []
for i in range(4):
    y = 0.03 + i * 0.11
    rot = (0, math.pi / 2 if i % 2 else 0, 0)
    ring = tube(f"mtl{i}", [((math.cos(a) * 0.04, y + math.sin(a) * 0.065, 0.0), 0.014, 0.014) for a in [k * math.pi / 6 for k in range(13)]], GOLD if i % 2 else GOLD_D, n=5, sub=0, cap0=False, cap1=False)
    if i % 2:
        ring.rotation_euler = (0, math.pi / 2, 0)
        ring.location = (0, 0, 0)
    parts.append(ring)
parts.append(blob("mtp", (0, 0.5, -0.02), (0.13, 0.06, 0.12), GOLD))
parts.append(tube("mts", [((0.0, 0.5, 0.04), 0.03, 0.03), ((0.0, 0.5, 0.1), 0.03, 0.03)], GOLD_D, n=6))
join("mimic_tail", parts)

# --- Night Bat ----------------------------------------------------------------
BAT = mat("t_bat", "4a3346")
BAT_IN = mat("t_bat_in", "c46a7a")
BAT_WING = mat("t_bat_wing", "5b2a3a")
parts = []
for s in (1, -1):
    parts.append(sheet(f"be{s}", [(0.16 * s, 0.04, 0.0), (0.4 * s, 0.06, 0.06), (0.36 * s, 0.1, 0.56), (0.14 * s, 0.08, 0.12)], BAT, 0.03))
    parts.append(sheet(f"bi{s}", [(0.19 * s, 0.02, 0.05), (0.35 * s, 0.035, 0.1), (0.33 * s, 0.06, 0.44), (0.18 * s, 0.05, 0.14)], BAT_IN, 0.01))
join("bat_head", parts)
join("bat_wings", wing_pair("bw", BAT_WING, BAT, CLAW))

# --- Heads only: the humanoids and the sapling --------------------------------
BONE = mat("t_bone", "e9e0c9", 0.7)
parts = []
for s in (1, -1):
    parts.append(cone(f"sk{s}", (0.18 * s, 0.0, 0.0), (0.3 * s, 0.1, 0.36), 0.07, BONE, n=6, bend=(0.06 * s, 0.0, 0.0)))
    parts.append(cone(f"sk2{s}", (0.08 * s, 0.04, 0.02), (0.12 * s, 0.14, 0.24), 0.045, BONE, n=6))
join("bonelet_head", parts)

HEX = mat("t_hex", "3d2b55")
HEX_G = glow("t_hex_g", "b47cff", 2.2)
join("hexling_head", [
    tube("hh", [((0, 0.0, 0.0), 0.36, 0.36), ((0, 0.02, 0.06), 0.2, 0.2), ((0, 0.06, 0.24), 0.12, 0.12), ((0, 0.16, 0.42), 0.05, 0.05), ((0, 0.3, 0.5), 0.015, 0.015)], HEX, n=10, cap0=True),
    tube("hb", [((0, 0.0, 0.07), 0.21, 0.21), ((0, 0.0, 0.1), 0.205, 0.205)], HEX_G, n=10),
])

THORN = mat("t_thorn", "4f6b2a")
THORN_D = mat("t_thorn_d", "2e3f1a")
parts = [tube("ac", [((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.03), 0.03, 0.03) for a in [i * math.pi / 8 for i in range(17)]], THORN_D, n=5, sub=0, cap0=False, cap1=False)]
for i in range(8):
    a = i * math.pi / 4 + 0.2
    parts.append(cone(f"at{i}", (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.04), (math.cos(a) * 0.4, math.sin(a) * 0.4, 0.2), 0.03, THORN, n=4))
join("acolyte_head", parts)

PLUME = mat("t_plume", "a8322c")
STEEL = mat("t_steel", "8a8f99", 0.4)
join("barrow_squire_head", [
    blob("sqb", (0, 0.0, 0.04), (0.08, 0.36, 0.08), STEEL),
    tube("sqp", [((0, -0.14, 0.06), 0.03, 0.06), ((0, -0.02, 0.2), 0.05, 0.1), ((0, 0.16, 0.22), 0.05, 0.09), ((0, 0.34, 0.1), 0.03, 0.05), ((0, 0.42, -0.04), 0.01, 0.02)], PLUME, n=8, sub=1),
])

LEATHER_T = mat("t_leather", "4a3424")
GILT_T = mat("t_gilt", "cdaf5a", 0.35)
# Barrow Squire: a small war banner on a pole, carried across the back.
parts = [tube("sqpole", [((-0.2, 0.06, -0.2), 0.02, 0.02), ((0.08, 0.06, 0.62), 0.02, 0.02)], LEATHER_T, n=6, sub=0),
         blob("sqfin", (0.085, 0.06, 0.64), (0.05, 0.05, 0.05), GILT_T, sub=1),
         sheet("sqban", [(0.06, 0.06, 0.56), (0.32, 0.06, 0.62), (0.3, 0.06, 0.4), (0.22, 0.06, 0.46), (0.14, 0.06, 0.34), (0.0, 0.06, 0.36)], PLUME, 0.02),
         sheet("sqbanb", [(0.06, 0.075, 0.54), (0.3, 0.075, 0.6), (0.29, 0.075, 0.56), (0.06, 0.075, 0.5)], GILT_T, 0.005)]
join("barrow_squire_wings", parts)

SHADE = mat("t_shade", "2c2440")
SHADE_G = glow("t_shade_g", "8a73ff", 1.8)
parts = []
for s in (1, -1):
    parts.append(cone(f"sh{s}", (0.16 * s, 0.0, 0.0), (0.42 * s, 0.24, 0.42), 0.08, SHADE, n=6, bend=(0.12 * s, -0.08, 0.04)))
    parts.append(cone(f"sh2{s}", (0.2 * s, 0.04, 0.12), (0.36 * s, 0.22, 0.34), 0.02, SHADE_G, n=4, bend=(0.1 * s, -0.06, 0.04)))
join("shade_head", parts)
# Ragged shadow-cloth winglets with a glowing hem, and a tongue of shadow.
parts = []
for s in (1, -1):
    parts.append(sheet(f"shw{s}", [(0.1 * s, 0.0, 0.0), (0.44 * s, 0.1, 0.24), (0.5 * s, 0.24, 0.04), (0.42 * s, 0.3, -0.12),
        (0.34 * s, 0.22, -0.04), (0.26 * s, 0.3, -0.16), (0.14 * s, 0.16, -0.06)], SHADE, 0.02))
    parts.append(cone(f"shwg{s}", (0.44 * s, 0.1, 0.24), (0.5 * s, 0.24, 0.04), 0.02, SHADE_G, n=4))
join("shade_wings", parts)
join("shade_tail", [
    sheet("sht", [(0, 0.0, 0.06), (0, 0.18, 0.14), (0, 0.3, 0.04), (0, 0.46, 0.12), (0, 0.42, -0.04), (0, 0.24, -0.08), (0, 0.0, -0.06)], SHADE, 0.03),
    sheet("shtg", [(0.018, 0.16, 0.06), (0.018, 0.3, 0.02), (0.018, 0.4, 0.06), (0.018, 0.3, -0.02)], SHADE_G, 0.01),
])

# Acolyte: a short moss cape over the shoulders, a thorned vine along its edge.
MOSS = mat("t_moss", "4f6b34")
MOSS_D = mat("t_moss_d", "324a22")
THORN = mat("t_thorn", "d8c9a0")
parts = [sheet("acc", [(0, 0.04, 0.06), (0.34, 0.04, 0.04), (0.38, 0.16, -0.22), (0.18, 0.2, -0.34), (0, 0.22, -0.38),
                       (-0.18, 0.2, -0.34), (-0.38, 0.16, -0.22), (-0.34, 0.04, 0.04)], MOSS, 0.025),
         tube("acv", [((-0.36, 0.17, -0.2), 0.016, 0.016), ((-0.18, 0.22, -0.32), 0.016, 0.016), ((0, 0.24, -0.36), 0.016, 0.016),
                      ((0.18, 0.22, -0.32), 0.016, 0.016), ((0.36, 0.17, -0.2), 0.016, 0.016)], MOSS_D, n=5, sub=0)]
for i, (x, z) in enumerate([(-0.27, -0.27), (0.0, -0.36), (0.27, -0.27)]):
    parts.append(cone(f"act{i}", (x, 0.22, z), (x * 1.15, 0.3, z - 0.03), 0.014, THORN, n=4))
join("acolyte_wings", parts)

BARK = mat("t_bark", "6b4a2e")
LEAF = mat("t_leaf", "6aa83a")
LEAF_D = mat("t_leaf_d", "3f7a26")
parts = [tube("sp", [((0, 0.0, 0.0), 0.05, 0.05), ((0, 0.04, 0.2), 0.035, 0.035), ((0, 0.02, 0.36), 0.02, 0.02)], BARK, n=6)]
for i, (a, z) in enumerate([(0.3, 0.2), (2.4, 0.28), (4.4, 0.36)]):
    d = (math.cos(a), math.sin(a))
    base = (d[0] * 0.02, 0.04 + d[1] * 0.02, z)
    parts.append(sheet(f"sl{i}", [base, (base[0] + d[0] * 0.14 - d[1] * 0.07, base[1] + d[1] * 0.14 + d[0] * 0.07, z + 0.1),
        (base[0] + d[0] * 0.3, base[1] + d[1] * 0.3, z + 0.14), (base[0] + d[0] * 0.14 + d[1] * 0.07, base[1] + d[1] * 0.14 - d[0] * 0.07, z + 0.02)],
        LEAF if i % 2 == 0 else LEAF_D, 0.015))
join("sapling_head", parts)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=os.path.abspath(OUT), export_format="GLB", use_selection=True,
    export_apply=True, export_yup=True, export_animations=False)
for o in bpy.data.objects:
    print("TRAIT", o.name, sum(len(p.vertices) - 2 for p in o.data.polygons))
