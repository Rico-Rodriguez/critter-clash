# Gilded Mimic: an iron-bound treasure chest on four crab legs, its lid a jaw
# of fangs over a lolling tongue and one gold eye, a gold chain dragging
# behind. Writes assets/sidekicks/mimic_src.glb.
# Run: <blender python> tools/blender/pets/mimic.py -- <repo root>
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *

ROOT = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(ROOT, "assets/sidekicks/")
reset()

WOOD = mat("mimic_wood", "4f3222")
WOOD_D = mat("mimic_wood_d", "30200f")
GOLD = mat("mimic_gold", "b8893a")
GOLD_D = mat("mimic_gold_d", "7a5622")
IRON = mat("mimic_iron", "33353a")
MOUTH = mat("mimic_mouth", "1d0e11")
TONGUE = mat("mimic_tongue", "8a3346")
TOOTH = mat("mimic_tooth", "c9bfa8")
EYE = mat("mimic_eye", "e6b43a")
PUPIL = mat("mimic_pupil", "120c0a")

W, D = 0.42, 0.28          # half width and half depth of the box
Z0, Z1 = 0.36, 0.72        # base bottom and rim
S = [
    ("hips", (0, 0.0, Z0), (0, 0.0, Z1), None),
    ("lid", (0, D, Z1), (0, -D, Z1), "hips"),
    ("tongue_1", (0, 0.05, Z1 - 0.02), (0, -0.2, Z1), "hips"),
    ("tongue_2", (0, -0.2, Z1), (0, -0.42, Z1 - 0.12), "tongue_1"),
    ("tail_01", (0, D, Z0 + 0.1), (0, D + 0.18, Z0 - 0.02), "hips"),
    ("tail_02", (0, D + 0.18, Z0 - 0.02), (0, D + 0.38, 0.12), "tail_01"),
    ("tail_03", (0, D + 0.38, 0.12), (0, D + 0.6, 0.04), "tail_02"),
]
LEGS = {"fl": (1, -1), "fr": (-1, -1), "bl": (1, 1), "br": (-1, 1)}
for k, (sx, sy) in LEGS.items():
    hip = (sx * (W - 0.04), sy * (D - 0.06), Z0 + 0.06)
    knee = (sx * (W + 0.2), sy * (D + 0.06), Z0 + 0.14)
    foot = (sx * (W + 0.3), sy * (D + 0.12), 0.0)
    S += [("leg_%s_1" % k, hip, knee, "hips"), ("leg_%s_2" % k, knee, foot, "leg_%s_1" % k)]
rig = armature(S)

# The box: dark planks, iron corner bands, a gold rim and lock plate.
bind(blob("box", (0, 0, (Z0 + Z1) / 2), (W * 2, D * 2, Z1 - Z0), WOOD, sub=0), ["hips"])
for i in range(1, 4):
    bind(blob("plank_f%d" % i, (0, -D - 0.004, Z0 + i * (Z1 - Z0) / 4), (W * 2 - 0.02, 0.012, 0.012), WOOD_D, sub=0), ["hips"])
    bind(blob("plank_b%d" % i, (0, D + 0.004, Z0 + i * (Z1 - Z0) / 4), (W * 2 - 0.02, 0.012, 0.012), WOOD_D, sub=0), ["hips"])
for sx in (-1, 1):
    bind(blob("band_%d" % sx, (sx * (W - 0.1), 0, (Z0 + Z1) / 2), (0.07, D * 2 + 0.02, Z1 - Z0 + 0.02), IRON, sub=0), ["hips"])
    for sy in (-1, 1):
        bind(blob("corner_%d%d" % (sx, sy), (sx * (W - 0.01), sy * (D - 0.01), (Z0 + Z1) / 2), (0.05, 0.05, Z1 - Z0 + 0.03), GOLD_D, sub=0), ["hips"])
bind(blob("rim", (0, 0, Z1 - 0.015), (W * 2 + 0.02, D * 2 + 0.02, 0.03), GOLD, sub=0), ["hips"])
bind(blob("mouth", (0, 0, Z1 - 0.005), (W * 2 - 0.08, D * 2 - 0.08, 0.02), MOUTH, sub=0), ["hips"])
bind(blob("lock", (0, -D - 0.02, Z1 - 0.1), (0.12, 0.03, 0.14), GOLD, sub=0), ["hips"])
bind(blob("keyhole", (0, -D - 0.036, Z1 - 0.11), (0.025, 0.01, 0.05), MOUTH, sub=0), ["hips"])
# Lower fangs along the front rim, molars on the sides.
for i in range(7):
    x = -W + 0.1 + i * (W * 2 - 0.2) / 6
    bind(cone("fang_lo%d" % i, (x, -D + 0.05, Z1), (x, -D + 0.07, Z1 + 0.09 + 0.03 * (i % 2)), 0.03, TOOTH, n=5), ["hips"])
for sx in (-1, 1):
    for i in range(3):
        y = -D + 0.15 + i * 0.12
        bind(cone("molar_%d%d" % (sx, i), (sx * (W - 0.06), y, Z1), (sx * (W - 0.07), y, Z1 + 0.05), 0.025, TOOTH, n=4), ["hips"])
# Tongue lolling out over the lock.
bind(tube("tongue", [((0, 0.05, Z1 - 0.01), 0.1, 0.03), ((0, -0.2, Z1 + 0.01), 0.1, 0.03), ((0, -0.36, Z1 - 0.04), 0.085, 0.025),
                     ((0, -0.44, Z1 - 0.14), 0.06, 0.02)], TONGUE, n=8), ["tongue_1", "tongue_2"])
# The lid: a curved top hinged at the back, open, fangs hanging from its front edge.
lid_parts = []
lid_parts.append(blob("lid_box", (0, 0, Z1 + 0.07), (W * 2 + 0.02, D * 2 + 0.02, 0.14), WOOD, sub=0))
lid_parts.append(tube("lid_arch", [((-W - 0.01, 0, Z1 + 0.14), D + 0.01, 0.1), ((W + 0.01, 0, Z1 + 0.14), D + 0.01, 0.1)], WOOD, n=16, sub=0))
lid_parts.append(blob("lid_rim", (0, 0, Z1 + 0.015), (W * 2 + 0.04, D * 2 + 0.04, 0.03), GOLD, sub=0))
lid_parts.append(blob("lid_mouth", (0, 0, Z1 + 0.003), (W * 2 - 0.08, D * 2 - 0.08, 0.02), MOUTH, sub=0))
for sx in (-1, 1):
    lid_parts.append(tube("lid_band_%d" % sx, [((sx * (W - 0.1) - 0.035, 0, Z1 + 0.14), D + 0.025, 0.115), ((sx * (W - 0.1) + 0.035, 0, Z1 + 0.14), D + 0.025, 0.115)], IRON, n=16, sub=0))
for i in range(6):
    x = -W + 0.13 + i * (W * 2 - 0.26) / 5
    lid_parts.append(cone("fang_up%d" % i, (x, -D + 0.05, Z1), (x, -D + 0.07, Z1 - 0.1 - 0.03 * ((i + 1) % 2)), 0.032, TOOTH, n=5))
# One gold eye peering from under the lid.
lid_parts.append(blob("eye", (0, -D + 0.12, Z1 - 0.01), (0.16, 0.06, 0.11), EYE, sub=1))
lid_parts.append(blob("pupil", (0, -D + 0.09, Z1 - 0.01), (0.03, 0.03, 0.09), PUPIL, sub=1))
# Open the lid 38 degrees about its back hinge.
hinge = Matrix.Translation((0, D, Z1)) @ Matrix.Rotation(math.radians(-38), 4, "X") @ Matrix.Translation((0, -D, -Z1))
bpy.context.view_layer.update()  # blobs set .location; matrix_world is stale until this
for o in lid_parts:
    o.matrix_world = hinge @ o.matrix_world
    bind(o, ["lid"])
# Crab legs: thick at the hip, a gold-capped knee and a dark claw tip.
for k, (sx, sy) in LEGS.items():
    hip = Vector((sx * (W - 0.04), sy * (D - 0.06), Z0 + 0.06))
    knee = Vector((sx * (W + 0.2), sy * (D + 0.06), Z0 + 0.14))
    foot = Vector((sx * (W + 0.3), sy * (D + 0.12), 0.0))
    bind(tube("thigh_" + k, [(hip, 0.055, 0.055), (knee, 0.04, 0.04)], WOOD_D, n=8), ["leg_%s_1" % k, "hips"])
    bind(tube("shin_" + k, [(knee, 0.04, 0.04), (knee.lerp(foot, 0.6), 0.03, 0.03), (foot, 0.008, 0.008)], WOOD_D, n=8), ["leg_%s_2" % k])
    bind(blob("knee_" + k, knee, (0.1, 0.1, 0.08), GOLD_D, sub=1), ["leg_%s_1" % k, "leg_%s_2" % k])
    bind(cone("claw_" + k, foot + Vector((0, 0, 0.12)), foot, 0.03, IRON, n=5), ["leg_%s_2" % k])
# A gold chain dragging from the back.
bpy.ops.mesh.primitive_torus_add(major_radius=0.045, minor_radius=0.014, major_segments=10, minor_segments=5)
link = bpy.context.object
for i in range(8):
    t = i / 7
    a = Vector((0, D, Z0 + 0.1))
    b = Vector((0, D + 0.6, 0.04))
    p = a.lerp(b, t) + Vector((0, 0, -0.08 * math.sin(t * math.pi)))
    c = link.copy()
    c.data = link.data.copy()
    bpy.context.scene.collection.objects.link(c)
    c.location = p
    c.rotation_euler = (math.radians(90) * (i % 2), 0, math.radians(90))
    c.data.materials.append(GOLD)
    bind(c, ["tail_01", "tail_02", "tail_03"])
bpy.data.objects.remove(link)

mimic = skin(rig, "Mimic")
bake(mimic, 1024, OUT + "mimic_tex.png")

# Clips: +X about the hinge opens the lid; legs lift by turning about Y
# (-Y lifts a left leg, +Y a right one); +X pitches the box nose-down.
def lid(keys, frames):
    keys["lid"] = [(t, (-a, 0, 0), None) for t, a in frames]
    return keys

def legs(keys, period, lift, phase_pairs=(("fl", "br"), ("fr", "bl"))):
    for j, pair in enumerate(phase_pairs):
        for k in pair:
            sg = 1 if k.endswith("l") else -1
            t0 = j * period / 2
            ks = [(0, 0), (period / 4, 0), (period / 2, 0), (3 * period / 4, 0), (period, 0)]
            ks = [(t, -sg * lift if abs(((t - t0) % period) - period / 4) < 1e-6 else 0) for t, _ in ks]
            keys["leg_%s_1" % k] = [(t, (0, a, 0), None) for t, a in ks]
            keys["leg_%s_2" % k] = [(t, (0, -a * 0.6, 0), None) for t, a in ks]
    return keys

idle = lid({}, [(0, 0), (1.0, 10), (2.0, 0)])
idle["tongue_2"] = [(0, (0, 0, 8), None), (1.0, (10, 0, -8), None), (2.0, (0, 0, 8), None)]
idle["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (1.0, (0, 0, 0), (0, 0, -0.025)), (2.0, (0, 0, 0), (0, 0, 0))]
idle["tail_02"] = [(0, (0, 0, 6), None), (1.0, (0, 0, -6), None), (2.0, (0, 0, 6), None)]
clip(rig, "Idle", 2.0, idle)

walk = legs(lid({}, [(0, 6), (0.3, -6), (0.6, 6)]), 0.6, 26)
walk["hips"] = [(0, (0, 0, -3), (0, 0, 0)), (0.15, (0, 0, 0), (0, 0, 0.04)), (0.3, (0, 0, 3), (0, 0, 0)), (0.45, (0, 0, 0), (0, 0, 0.04)), (0.6, (0, 0, -3), (0, 0, 0))]
walk["tail_01"] = [(0, (0, 0, 8), None), (0.3, (0, 0, -8), None), (0.6, (0, 0, 8), None)]
clip(rig, "Walk", 0.6, walk)

bite = lid({}, [(0, 0), (0.2, 34), (0.34, -38), (0.6, 0)])
bite["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.2, (-8, 0, 0), (0, 0.06, 0.02)), (0.34, (10, 0, 0), (0, -0.16, 0)), (0.6, (0, 0, 0), (0, 0, 0))]
bite["tongue_1"] = [(0, (0, 0, 0), None), (0.2, (-20, 0, 0), None), (0.34, (10, 0, 0), None), (0.6, (0, 0, 0), None)]
clip(rig, "Bite_Front", 0.6, bite, loop=False)

hit = lid({}, [(0, 0), (0.08, -38), (0.4, 0)])
hit["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.08, (-10, 0, 6), (0, 0.08, 0.04)), (0.4, (0, 0, 0), (0, 0, 0))]
clip(rig, "Hit", 0.4, hit, loop=False)

sp = lid({}, [(0, 0), (0.3, 50), (0.75, 50), (1.0, 0)])
sp["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.3, (-14, 0, 0), (0, 0, 0.1)), (0.75, (-14, 0, 0), (0, 0, 0.1)), (1.0, (0, 0, 0), (0, 0, 0))]
sp["tongue_1"] = [(0, (0, 0, 0), None), (0.35, (12, 0, 0), None), (0.75, (12, 0, 0), None), (1.0, (0, 0, 0), None)]
sp["tongue_2"] = [(0, (0, 0, 0), None), (0.35, (20, 0, 0), None), (0.55, (20, 0, 14), None), (0.75, (20, 0, -14), None), (1.0, (0, 0, 0), None)]
clip(rig, "Special", 1.0, sp, loop=False)

export(rig, mimic, OUT + "mimic_src.glb")
os.remove(OUT + "mimic_tex.png")
