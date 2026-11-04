# Cinder Imp (cm_imp): a lean, hunched fiend of char-black plate with ember seams, long
# arms, swept horns, bat-scrap wings and a spaded tail, one ember held ready to throw.
# Writes assets/foes/cinder_imp_src.glb.
# Run: python3 tools/blender/foes/cinder_imp.py -- <repo root>
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foe_common import *

reset()
ASH = mat("imp_ash", "2b2522")
CHAR = mat("imp_char", "1a1614")
EMBER = mat("imp_ember", "b8421a")
GLOW = mat("imp_glow", "f08a2a")
HORN = mat("imp_horn", "7d705c")
CLAW = mat("imp_claw", "0f0d0c")
WING = mat("imp_wing", "3a2a24")
EYE = mat("imp_eye", "ffc040")

# Skeleton (Blender: -Y forward, Z up; x > 0 is "l").
S = [
    ("hips", (0, 0.06, 0.6), (0, 0.02, 0.72), None),
    ("spine_01", (0, 0.02, 0.72), (0, -0.07, 0.92), "hips"),
    ("spine_02", (0, -0.07, 0.92), (0, -0.17, 1.08), "spine_01"),
    ("neck", (0, -0.17, 1.08), (0, -0.25, 1.15), "spine_02"),
    ("head", (0, -0.25, 1.15), (0, -0.4, 1.2), "neck"),
    ("jaw", (0, -0.34, 1.12), (0, -0.52, 1.1), "head"),
    ("tail_01", (0, 0.1, 0.62), (0, 0.32, 0.54), "hips"),
    ("tail_02", (0, 0.32, 0.54), (0, 0.52, 0.5), "tail_01"),
    ("tail_03", (0, 0.52, 0.5), (0, 0.7, 0.58), "tail_02"),
]
for s, x in (("l", 1), ("r", -1)):
    S += [
        ("thigh_" + s, (x * 0.1, 0.05, 0.6), (x * 0.12, -0.1, 0.38), "hips"),
        ("shin_" + s, (x * 0.12, -0.1, 0.38), (x * 0.12, 0.04, 0.15), "thigh_" + s),
        ("foot_" + s, (x * 0.12, 0.04, 0.15), (x * 0.12, -0.12, 0.02), "shin_" + s),
        ("upperarm_" + s, (x * 0.16, -0.14, 1.0), (x * 0.25, -0.2, 0.78), "spine_02"),
        ("forearm_" + s, (x * 0.25, -0.2, 0.78), (x * 0.24, -0.38, 0.62), "upperarm_" + s),
        ("hand_" + s, (x * 0.24, -0.38, 0.62), (x * 0.22, -0.48, 0.56), "forearm_" + s),
        ("wing_" + s, (x * 0.08, -0.02, 0.98), (x * 0.42, 0.1, 1.2), "spine_01"),
    ]
rig = armature(S)
common.SIDES, common.BLOB_SUB = 1.0, 0

# Torso: a keeled, hunched chest narrowing to a lean waist; belly seam in ember.
torso = tube("torso", [((0, 0.1, 0.58), 0.09, 0.09), ((0, 0.04, 0.7), 0.12, 0.1), ((0, -0.04, 0.86), 0.16, 0.12),
                       ((0, -0.14, 1.02), 0.18, 0.12), ((0, -0.2, 1.1), 0.1, 0.09)], ASH, n=6)
two_tone(torso, EMBER, CHAR, down=-0.3, up=0.7)
bind(torso, ["hips", "spine_01", "spine_02"])
bind(blob("chestscar", (0, -0.235, 0.96), (0.05, 0.02, 0.16), GLOW, rot=(0.35, 0, 0)), ["spine_02"])
bind(blob("navelscar", (0, -0.12, 0.7), (0.04, 0.02, 0.1), GLOW, rot=(0.15, 0, 0)), ["spine_01"])
# Spine ridge: little blades down the back.
for i, (y, z) in enumerate([(-0.17, 1.12), (-0.12, 1.02), (-0.06, 0.9), (0.0, 0.78), (0.06, 0.66)]):
    bind(cone("ridge_%d" % i, (0, y + 0.1, z - 0.02), (0, y + 0.19, z + 0.07), 0.03, CHAR, n=3), ["spine_02" if i < 3 else "spine_01"])
# Head: a wedge skull with a short muzzle, brow ridges, swept horns and long ears.
head = tube("head", [((0, -0.21, 1.17), 0.07, 0.08), ((0, -0.3, 1.2), 0.11, 0.1), ((0, -0.41, 1.2), 0.1, 0.085),
                     ((0, -0.51, 1.16), 0.06, 0.05), ((0, -0.57, 1.13), 0.03, 0.03)], ASH, n=6)
two_tone(head, EMBER, CHAR, down=-0.6, up=0.8)
bind(head, ["head"])
bind(tube("jaw", [((0, -0.34, 1.1), 0.06, 0.03), ((0, -0.46, 1.075), 0.045, 0.025), ((0, -0.54, 1.075), 0.012, 0.012)], CHAR, n=4), ["jaw"])
bind(tube("neck", [((0, -0.14, 1.04), 0.09, 0.09), ((0, -0.22, 1.13), 0.07, 0.07)], ASH, n=5), ["spine_02", "neck", "head"])
for s, x in (("l", 1), ("r", -1)):
    bind(blob("eye_" + s, (x * 0.075, -0.43, 1.2), (0.026, 0.06, 0.026), EYE, rot=(0, 0, x * -0.5)), ["head"])
    bind(blob("brow_" + s, (x * 0.07, -0.4, 1.255), (0.06, 0.12, 0.025), CHAR, rot=(0.1, x * -0.1, x * -0.4)), ["head"])
    bind(cone("horn_" + s, (x * 0.06, -0.3, 1.27), (x * 0.2, -0.1, 1.5), 0.04, HORN, n=4, bend=(x * 0.06, -0.04, 0.02)), ["head"])
    bind(cone("ear_" + s, (x * 0.1, -0.27, 1.19), (x * 0.34, -0.14, 1.27), 0.045, ASH, n=3, bend=(0, 0, 0.04)), ["head"])
    bind(cone("fang_" + s, (x * 0.025, -0.5, 1.115), (x * 0.025, -0.5, 1.06), 0.014, HORN, n=3), ["head"])
    bind(cone("tusk_" + s, (x * 0.03, -0.46, 1.08), (x * 0.03, -0.49, 1.14), 0.012, HORN, n=3), ["jaw"])
# Arms: long, thin, knuckles near the knee, hooked claws.
for s, x in (("l", 1), ("r", -1)):
    P = lambda v: (x * v[0], v[1], v[2])
    arm = tube("arm_" + s, [(P((0.14, -0.14, 1.0)), 0.06, 0.06), (P((0.25, -0.2, 0.78)), 0.04, 0.04), (P((0.24, -0.38, 0.62)), 0.03, 0.03),
                            (P((0.22, -0.46, 0.57)), 0.034, 0.034)], ASH, n=5)
    bind(arm, ["spine_02", "upperarm_" + s, "forearm_" + s, "hand_" + s])
    bind(blob("pauldron_" + s, P((0.2, -0.13, 1.03)), (0.11, 0.1, 0.06), CHAR, rot=(0, x * 0.5, 0)), ["spine_02", "upperarm_" + s])
    for k in (-1, 0, 1):
        h = P((0.22, -0.48, 0.56))
        bind(cone("fing_%s%d" % (s, k), (h[0] + k * 0.025, h[1], h[2]), (h[0] + k * 0.035, h[1] - 0.09, h[2] - 0.03), 0.013, CLAW, n=3), ["hand_" + s])
# Legs: digitigrade, knee forward, hock back, three toes.
for s, x in (("l", 1), ("r", -1)):
    P = lambda v: (x * v[0], v[1], v[2])
    leg = tube("leg_" + s, [(P((0.1, 0.05, 0.62)), 0.09, 0.09), (P((0.12, -0.1, 0.38)), 0.055, 0.055), (P((0.12, 0.04, 0.15)), 0.035, 0.035),
                            (P((0.12, -0.02, 0.06)), 0.04, 0.04)], ASH, n=5)
    bind(leg, ["hips", "thigh_" + s, "shin_" + s, "foot_" + s])
    for k in (-1, 0, 1):
        bind(cone("toe_%s%d" % (s, k), (x * 0.12 + k * 0.03, -0.02, 0.05), (x * 0.12 + k * 0.05, -0.17, 0.0), 0.022, CLAW, n=3), ["foot_" + s])
# Tail with a spade tip.
tail = tube("tail", [((0, 0.08, 0.62), 0.06, 0.06), ((0, 0.32, 0.54), 0.04, 0.04), ((0, 0.52, 0.5), 0.025, 0.025), ((0, 0.66, 0.56), 0.012, 0.012)], ASH, n=5)
bind(tail, ["hips", "tail_01", "tail_02", "tail_03"])
bind(sheet("spade", [(0, 0.64, 0.56), (0.08, 0.7, 0.58), (0.02, 0.8, 0.66), (0, 0.9, 0.74), (-0.02, 0.8, 0.66), (-0.08, 0.7, 0.58)], EMBER, 0.03), ["tail_03"])
# Wings: scraps of leather on a bony arm.
for s, x in (("l", 1), ("r", -1)):
    P = lambda v: (x * v[0], v[1], v[2])
    bind(tube("wingarm_" + s, [(P((0.06, -0.02, 0.98)), 0.03, 0.03), (P((0.3, 0.04, 1.14)), 0.02, 0.02), (P((0.5, 0.12, 1.34)), 0.007, 0.007)], CHAR, n=4), ["spine_01", "wing_" + s])
    bind(sheet("membrane_" + s, [P((0.08, 0.0, 0.96)), P((0.3, 0.04, 1.14)), P((0.5, 0.12, 1.34)), P((0.5, 0.2, 1.1)), P((0.36, 0.17, 1.0)), P((0.26, 0.12, 0.99)), P((0.14, 0.06, 0.94))],
               WING, 0.014), ["spine_01", "wing_" + s])
# The ember it throws, held in the right hand.
ember = tube("ember", [((-0.22, -0.52, 0.52), 0.002, 0.002), ((-0.22, -0.54, 0.575), 0.05, 0.05), ((-0.22, -0.56, 0.64), 0.002, 0.002)], GLOW, n=5)
bind(ember, ["hand_r"])

imp = skin(rig, "Imp")

# --- Clips: rotations in degrees about the rig's axes (+X pitches forward / swings down-pointing
# limbs back; -Y raises the left limb outward, +Y the right). ---
def walk(period, stride, bob, lean, arm):
    c = {}
    for s, sg, ph in (("l", 1, 0.0), ("r", -1, 0.5)):
        c["thigh_" + s] = osc(period, {0: (stride, ph)})
        c["shin_" + s] = osc(period, {0: (stride * 0.7, ph + 0.18)}, base=(14, 0, 0))
        c["foot_" + s] = osc(period, {0: (stride * 0.5, ph + 0.4)})
        c["upperarm_" + s] = osc(period, {0: (arm, ph + 0.5)})
        c["forearm_" + s] = osc(period, {0: (arm * 0.5, ph + 0.75)}, base=(-20, 0, 0))
    c["hips"] = osc(period, {1: (4, 0), 2: (5, 0.25)}, base=(lean, 0, 0), loc={2: (bob, 0.0)})
    c["spine_02"] = osc(period, {2: (-6, 0.25), 1: (-3, 0)}, base=(lean * 0.5, 0, 0))
    c["head"] = osc(period, {0: (3, 0.2)}, base=(-lean, 0, 0))
    c["tail_01"] = osc(period, {2: (14, 0.0), 0: (4, 0.25)})
    c["tail_02"] = osc(period, {2: (18, 0.12)})
    c["tail_03"] = osc(period, {2: (22, 0.24)})
    for s, sg in (("l", 1), ("r", -1)):
        c["wing_" + s] = osc(period, {1: (-sg * 10, 0.1)})
    return c

idle = {
    "hips": osc(1.6, {0: (2, 0)}, loc={2: (0.012, 0)}),
    "spine_01": osc(1.6, {0: (2, 0.1)}),
    "spine_02": osc(1.6, {0: (2.5, 0.2), 2: (3, 0)}),
    "head": osc(1.6, {2: (14, 0.0), 0: (3, 0.3)}),
    "jaw": osc(1.6, {0: (5, 0.5)}, base=(4, 0, 0)),
    "tail_01": osc(1.6, {2: (10, 0.0)}), "tail_02": osc(1.6, {2: (16, 0.15)}), "tail_03": osc(1.6, {2: (22, 0.3)}),
    "thigh_l": [(0, (6, 0, 0), None), (1.6, (6, 0, 0), None)], "thigh_r": [(0, (6, 0, 0), None), (1.6, (6, 0, 0), None)],
    "shin_l": [(0, (-8, 0, 0), None), (1.6, (-8, 0, 0), None)], "shin_r": [(0, (-8, 0, 0), None), (1.6, (-8, 0, 0), None)],
}
for s, sg in (("l", 1), ("r", -1)):
    idle["upperarm_" + s] = osc(1.6, {0: (5, 0.25), 1: (sg * -4, 0.0)})
    idle["forearm_" + s] = osc(1.6, {0: (6, 0.4)}, base=(-18, 0, 0))
    idle["wing_" + s] = osc(1.6, {1: (-sg * 12, 0.3), 2: (sg * 4, 0)})
clip(rig, "Idle", 1.6, idle)
clip(rig, "Walk", 0.8, walk(0.8, 28, 0.025, 8, 24))
clip(rig, "Run", 0.5, walk(0.5, 42, 0.05, 20, 38))

# Attack: rear back with the ember cocked over the shoulder, then hurl it.
atk = {
    "hips": pose((0, (0, 0, 0), (0, 0, 0)), (0.3, (-8, 0, 12), (0, 0.05, -0.02)), (0.45, (10, 0, -14), (0, -0.1, 0)), (0.9, (0, 0, 0), (0, 0, 0))),
    "spine_02": pose((0, (0, 0, 0)), (0.3, (-14, 0, 22)), (0.45, (22, 0, -26)), (0.9, (0, 0, 0))),
    "head": pose((0, (0, 0, 0)), (0.3, (-8, 0, -14)), (0.45, (12, 0, 0)), (0.9, (0, 0, 0))),
    "upperarm_r": pose((0, (0, 0, 0)), (0.3, (150, 20, 0)), (0.45, (-85, 0, 0)), (0.6, (-60, 0, 0)), (0.9, (0, 0, 0))),
    "forearm_r": pose((0, (-18, 0, 0)), (0.3, (-70, 0, 0)), (0.45, (-4, 0, 0)), (0.9, (-18, 0, 0))),
    "upperarm_l": pose((0, (0, 0, 0)), (0.3, (-40, 0, 0)), (0.45, (30, 0, 0)), (0.9, (0, 0, 0))),
    "jaw": pose((0, (0, 0, 0)), (0.3, (26, 0, 0)), (0.9, (0, 0, 0))),
    "tail_01": pose((0, (0, 0, 0)), (0.3, (-10, 0, 0)), (0.45, (12, 0, 0)), (0.9, (0, 0, 0))),
    "thigh_l": pose((0, (6, 0, 0)), (0.45, (-22, 0, 0)), (0.9, (6, 0, 0))), "thigh_r": pose((0, (6, 0, 0)), (0.3, (14, 0, 0)), (0.9, (6, 0, 0))),
}
clip(rig, "Attack", 0.9, atk, loop=False)

hit = {
    "hips": pose((0, (0, 0, 0), (0, 0, 0)), (0.1, (-10, 0, 6), (0, 0.1, -0.03)), (0.4, (0, 0, 0), (0, 0, 0))),
    "spine_02": pose((0, (0, 0, 0)), (0.1, (-22, 0, -10)), (0.4, (0, 0, 0))),
    "head": pose((0, (0, 0, 0)), (0.1, (-26, 0, 14)), (0.4, (0, 0, 0))),
    "upperarm_l": pose((0, (0, 0, 0)), (0.1, (-30, -50, 0)), (0.4, (0, 0, 0))), "upperarm_r": pose((0, (0, 0, 0)), (0.1, (-30, 50, 0)), (0.4, (0, 0, 0))),
    "jaw": pose((0, (0, 0, 0)), (0.1, (34, 0, 0)), (0.4, (0, 0, 0))),
    "tail_01": pose((0, (0, 0, 0)), (0.1, (-24, 0, 0)), (0.4, (0, 0, 0))),
}
clip(rig, "Hit", 0.4, hit, loop=False)

die = {
    "hips": pose((0, (0, 0, 0), (0, 0, 0)), (0.15, (-12, 0, 0), (0, 0.12, -0.04)), (0.5, (-70, 0, 0), (0, 0.4, -0.3)), (0.75, (-84, 0, 4), (0, 0.48, -0.5)), (1.2, (-86, 0, 4), (0, 0.48, -0.52))),
    "spine_02": pose((0, (0, 0, 0)), (0.3, (-20, 0, 0)), (1.2, (-12, 0, 8))),
    "head": pose((0, (0, 0, 0)), (0.2, (-24, 0, 10)), (0.8, (-18, 0, 16)), (1.2, (-18, 0, 16))),
    "jaw": pose((0, (0, 0, 0)), (0.3, (36, 0, 0)), (1.2, (36, 0, 0))),
    "upperarm_l": pose((0, (0, 0, 0)), (0.3, (-30, -60, 0)), (0.7, (10, -70, 0)), (1.2, (10, -70, 0))),
    "upperarm_r": pose((0, (0, 0, 0)), (0.3, (-30, 60, 0)), (0.7, (10, 70, 0)), (1.2, (10, 70, 0))),
    "thigh_l": pose((0, (6, 0, 0)), (0.5, (-30, -10, 0)), (1.2, (-30, -10, 0))), "thigh_r": pose((0, (6, 0, 0)), (0.5, (-50, 10, 0)), (1.2, (-50, 10, 0))),
    "shin_l": pose((0, (-8, 0, 0)), (0.5, (30, 0, 0)), (1.2, (30, 0, 0))), "shin_r": pose((0, (-8, 0, 0)), (0.5, (40, 0, 0)), (1.2, (40, 0, 0))),
    "tail_01": pose((0, (0, 0, 0)), (0.5, (-16, 0, 0)), (1.2, (-16, 0, 10))),
    "wing_l": pose((0, (0, 0, 0)), (0.5, (0, -30, 0)), (1.2, (0, -30, 0))), "wing_r": pose((0, (0, 0, 0)), (0.5, (0, 30, 0)), (1.2, (0, 30, 0))),
}
clip(rig, "Death", 1.2, die, loop=False)

finish(rig, imp, "cinder_imp")
