# Bogfin (Cinder Mire): a hunched swamp lizardman, real proportions. Moss-dark
# scales over a bile-yellow belly, digitigrade legs, a long tail, a finned
# crest down head and back, webbed claws, and a rusted fishing spear lashed in
# its right hand. Writes assets/foes/bogfin_src.glb.
# Run: python3 tools/blender/foes/bogfin.py -- <repo root>
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "pets"))
import common
from common import *
from biped import stride, bob

ROOT = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(ROOT, "assets/foes/")
reset()
common.SIDES, common.BLOB_SUB = 0.9, 1

SCALE = mat("fin_scale", "34442a")
DARK = mat("fin_dark", "1f2a19")
BELLY = mat("fin_belly", "8a8648")
FIN = mat("fin_fin", "5a3a26")
FIN_D = mat("fin_fin_d", "3a2518")
CLAW = mat("fin_claw", "a39c82")
EYE = mat("fin_eye", "e8c43a")
VOID = mat("fin_void", "0a0c08", 1.0)
WOOD = mat("fin_wood", "4a3624")
IRON = mat("fin_iron", "5c4a40", 0.5)
RUST = mat("fin_rust", "7a4a2a")
CORD = mat("fin_cord", "8a7a58")

S = [
    ("hips", (0, 0.08, 0.92), (0, 0.02, 1.06), None),
    ("spine_01", (0, 0.02, 1.06), (0, -0.06, 1.3), "hips"),
    ("chest", (0, -0.06, 1.3), (0, -0.14, 1.5), "spine_01"),
    ("neck_01", (0, -0.14, 1.5), (0, -0.24, 1.62), "chest"),
    ("head", (0, -0.24, 1.62), (0, -0.52, 1.56), "neck_01"),
    ("jaw", (0, -0.3, 1.54), (0, -0.52, 1.5), "head"),
    ("tail_01", (0, 0.1, 0.9), (0, 0.42, 0.8), "hips"),
    ("tail_02", (0, 0.42, 0.8), (0, 0.78, 0.68), "tail_01"),
    ("tail_03", (0, 0.78, 0.68), (0, 1.1, 0.6), "tail_02"),
]
for s, x in (("l", 1), ("r", -1)):
    S += [
        ("thigh_" + s, (x * 0.15, 0.06, 0.92), (x * 0.17, -0.1, 0.6), "hips"),
        ("shin_" + s, (x * 0.17, -0.1, 0.6), (x * 0.17, 0.1, 0.26), "thigh_" + s),
        ("foot_" + s, (x * 0.17, 0.1, 0.26), (x * 0.17, -0.18, 0.03), "shin_" + s),
        ("upperarm_" + s, (x * 0.26, -0.1, 1.42), (x * 0.34, -0.14, 1.12), "chest"),
        ("forearm_" + s, (x * 0.34, -0.14, 1.12), (x * 0.36, -0.3, 0.94), "upperarm_" + s),
        ("hand_" + s, (x * 0.36, -0.3, 0.94), (x * 0.36, -0.42, 0.86), "forearm_" + s),
    ]
rig = armature(S)

# Torso: pelvis, belly, deep chest, hunched.
torso = tube("torso", [((0, 0.12, 0.88), 0.15, 0.13), ((0, 0.04, 1.02), 0.2, 0.17), ((0, -0.04, 1.24), 0.23, 0.19),
                       ((0, -0.12, 1.44), 0.24, 0.19), ((0, -0.16, 1.54), 0.14, 0.13)], SCALE, n=9)
two_tone(torso, BELLY, None, down=-0.3, front=0.0)
bind(torso, ["hips", "spine_01", "chest"])
bind(tube("neck", [((0, -0.14, 1.5), 0.1, 0.1), ((0, -0.26, 1.62), 0.085, 0.085)], SCALE, n=6), ["neck_01", "head"])
# Head: long wedge snout, brow ridges, yellow eyes, nostril pits, toothy jaw.
head = tube("head", [((0, -0.22, 1.63), 0.115, 0.115), ((0, -0.34, 1.62), 0.12, 0.1), ((0, -0.46, 1.58), 0.08, 0.065),
                     ((0, -0.56, 1.55), 0.055, 0.045)], SCALE, n=7)
bind(head, ["head"])
bind(tube("jaw", [((0, -0.3, 1.53), 0.08, 0.04), ((0, -0.44, 1.5), 0.065, 0.032), ((0, -0.54, 1.49), 0.04, 0.025)], BELLY, n=5), ["jaw"])
for x in (1, -1):
    bind(blob("brow", (x * 0.1, -0.33, 1.7), (0.07, 0.12, 0.04), DARK, rot=(0, x * 0.2, 0)), ["head"])
    bind(blob("eye", (x * 0.115, -0.34, 1.665), (0.04, 0.05, 0.045), EYE, sub=1), ["head"])
    bind(blob("pupil", (x * 0.14, -0.35, 1.665), (0.012, 0.012, 0.04), VOID, sub=0), ["head"])
    bind(blob("nostril", (x * 0.03, -0.575, 1.57), (0.014, 0.014, 0.014), VOID, sub=0), ["head"])
    for k in range(3):
        bind(cone("tooth%d%s" % (k, "l" if x > 0 else "r"), (x * 0.05, -0.42 - k * 0.05, 1.52), (x * 0.05, -0.42 - k * 0.05, 1.575), 0.012, CLAW, n=3), ["jaw"])
# Fins: a crest over the skull and down the spine, frilled gill sheets by the jaw.
bind(sheet("crest", [(0, -0.3, 1.7), (0, -0.2, 1.88), (0, -0.12, 1.76), (0, -0.04, 1.92), (0, 0.03, 1.74), (0, 0.1, 1.82), (0, 0.14, 1.64),
                     (0, -0.22, 1.66)], FIN, 0.02), ["head", "neck_01"])
bind(sheet("dorsal", [(0, 0.14, 1.52), (0, 0.12, 1.72), (0, 0.18, 1.6), (0, 0.2, 1.62), (0, 0.24, 1.38), (0, 0.24, 1.46), (0, 0.22, 1.18),
                      (0, 0.18, 1.2), (0, 0.18, 1.0), (0, 0.12, 1.02)][:3] + [(0, 0.2, 1.4), (0, 0.17, 1.3), (0, 0.12, 1.2), (0, 0.1, 1.0), (0, 0.08, 1.46)], FIN_D, 0.02),
     ["chest", "spine_01"])
for x in (1, -1):
    bind(sheet("gill", [(x * 0.1, -0.26, 1.6), (x * 0.24, -0.22, 1.7), (x * 0.2, -0.26, 1.6), (x * 0.26, -0.24, 1.52), (x * 0.16, -0.28, 1.52), (x * 0.1, -0.3, 1.56)],
               FIN, 0.015), ["head"])
# Tail: thick root tapering to a finned tip.
tail = tube("tail", [((0, 0.1, 0.9), 0.14, 0.12), ((0, 0.42, 0.8), 0.1, 0.09), ((0, 0.78, 0.68), 0.06, 0.055), ((0, 1.1, 0.6), 0.012, 0.012)], SCALE, n=6)
bind(tail, ["tail_01", "tail_02", "tail_03"])
bind(sheet("tailfin", [(0, 0.6, 0.86), (0, 0.8, 0.9), (0, 1.0, 0.78), (0, 1.14, 0.64), (0, 1.0, 0.56), (0, 0.8, 0.62)], FIN_D, 0.018), ["tail_02", "tail_03"])

for s, x in (("l", 1), ("r", -1)):
    P = lambda v: (x * v[0], v[1], v[2])
    # Digitigrade leg: thigh forward, shin back to a high hock, long clawed foot.
    bind(tube("thigh_" + s, [(P((0.13, 0.06, 0.94)), 0.1, 0.09), (P((0.17, -0.1, 0.62)), 0.075, 0.07)], SCALE, n=6), ["thigh_" + s])
    bind(tube("shin_" + s, [(P((0.17, -0.1, 0.6)), 0.06, 0.06), (P((0.17, 0.1, 0.27)), 0.04, 0.04)], DARK, n=6), ["shin_" + s])
    bind(blob("heel_" + s, P((0.17, 0.12, 0.26)), (0.06, 0.09, 0.07), DARK), ["foot_" + s])
    bind(tube("foot_" + s, [(P((0.17, 0.12, 0.27)), 0.045, 0.04), (P((0.17, -0.0, 0.1)), 0.055, 0.04), (P((0.17, -0.17, 0.045)), 0.06, 0.035)], SCALE, n=6), ["foot_" + s, "shin_" + s])
    for k in (-1, 0, 1):
        bind(cone("toe%d%s" % (k, s), P((0.17 + k * 0.04, -0.17, 0.04)), P((0.17 + k * 0.06, -0.28, 0.015)), 0.02, CLAW, n=3), ["foot_" + s])
    # Arm and webbed claw.
    bind(blob("shoulder_" + s, P((0.27, -0.1, 1.42)), (0.12, 0.12, 0.11), DARK, sub=1), ["upperarm_" + s])
    bind(tube("arm_" + s, [(P((0.27, -0.1, 1.42)), 0.065, 0.06), (P((0.34, -0.14, 1.12)), 0.05, 0.05)], SCALE, n=6), ["upperarm_" + s])
    bind(tube("fore_" + s, [(P((0.34, -0.14, 1.12)), 0.048, 0.048), (P((0.36, -0.3, 0.95)), 0.04, 0.04)], SCALE, n=6), ["forearm_" + s])
    bind(sheet("web_" + s, [P((0.36, -0.3, 0.94)), P((0.28, -0.44, 0.86)), P((0.44, -0.44, 0.86))], FIN, 0.012), ["hand_" + s])
    bind(blob("palm_" + s, P((0.36, -0.34, 0.91)), (0.06, 0.08, 0.05), DARK, sub=1), ["hand_" + s])
    for k in (-1, 0, 1):
        bind(cone("claw%d%s" % (k, s), P((0.36 + k * 0.035, -0.38, 0.9)), P((0.36 + k * 0.06, -0.5, 0.82)), 0.016, CLAW, n=3), ["hand_" + s])

# The spear: a rusted fishing spear, shaft through the right fist, leaf-shaped iron head, cord wraps.
bind(tube("shaft", [((-0.36, 0.1, 0.4), 0.018, 0.018), ((-0.36, -0.3, 0.92), 0.018, 0.018), ((-0.36, -0.62, 1.32), 0.018, 0.018), ((-0.36, -0.78, 1.52), 0.016, 0.016)],
          WOOD, n=5), ["hand_r"])
bind(cone("spearhead", (-0.36, -0.78, 1.52), (-0.36, -0.9, 1.74), 0.05, IRON, n=4), ["hand_r"])
bind(cone("barb_l", (-0.33, -0.78, 1.52), (-0.31, -0.74, 1.66), 0.02, RUST, n=3), ["hand_r"])
bind(cone("barb_r", (-0.39, -0.78, 1.52), (-0.41, -0.74, 1.66), 0.02, RUST, n=3), ["hand_r"])
for z in (0.9, 0.96):
    bind(blob("wrap", (-0.36, -0.3 - (z - 0.9) * 0.2, z + 0.0), (0.05, 0.05, 0.03), CORD, sub=0), ["hand_r"])

body = skin(rig, "Bogfin")
bake(body, 256, OUT + "bogfin_tex.png")

# Clips (+X pitches forward, -Y lifts the left arm; tail swings in Z).
def tail_sway(period, a, keys):
    for i, bn in enumerate(["tail_01", "tail_02", "tail_03"]):
        keys[bn] = [(0, (0, 0, a * (1 + i * 0.6)), None), (period / 2, (0, 0, -a * (1 + i * 0.6)), None), (period, (0, 0, a * (1 + i * 0.6)), None)]
    return keys

idle = tail_sway(2.2, 5, {})
idle["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (1.1, (1, 0, 0), (0, 0, 0.015)), (2.2, (0, 0, 0), (0, 0, 0))]
idle["chest"] = [(0, (0, 0, 2), None), (1.1, (3, 0, -2), None), (2.2, (0, 0, 2), None)]
idle["head"] = [(0, (0, 0, -6), None), (1.1, (-3, 0, 5), None), (2.2, (0, 0, -6), None)]
idle["jaw"] = [(0, (0, 0, 0), None), (1.1, (6, 0, 0), None), (2.2, (0, 0, 0), None)]
clip(rig, "Idle", 2.2, idle)

def gait(period, a, knee, arm, lean, tilt, lift):
    ks = stride(period, a, knee, arm)
    ks["hips"] = bob(period, tilt, lift, lean)
    ks["chest"] = [(0, (lean * 0.5, 0, -tilt), None), (period / 2, (lean * 0.5, 0, tilt), None), (period, (lean * 0.5, 0, -tilt), None)]
    ks["head"] = [(0, (-lean, 0, 0), None), (period, (-lean, 0, 0), None)]
    # The right fist keeps the spear carried across.
    ks["upperarm_r"] = [(0, (-25, 10, 0), None), (period, (-25, 10, 0), None)]
    return tail_sway(period, 8, ks)

clip(rig, "Walk", 0.9, gait(0.9, 26, 36, 14, 6, 4, 0.03))
clip(rig, "Run", 0.5, gait(0.5, 40, 52, 22, 18, 5, 0.06))

# Attack: spear drawn back over the shoulder, then a lunging thrust.
atk = tail_sway(0.8, 6, {})
atk["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.3, (-8, 0, 12), (0, 0.06, -0.03)), (0.46, (20, 0, -10), (0, -0.28, -0.05)), (0.8, (0, 0, 0), (0, 0, 0))]
atk["chest"] = [(0, (0, 0, 0), None), (0.3, (-10, 0, 18), None), (0.46, (14, 0, -16), None), (0.8, (0, 0, 0), None)]
atk["upperarm_r"] = [(0, (-25, 10, 0), None), (0.3, (-80, 40, 0), None), (0.46, (-60, 4, 0), None), (0.8, (-25, 10, 0), None)]
atk["forearm_r"] = [(0, (0, 0, 0), None), (0.3, (-50, 0, 0), None), (0.46, (0, 0, 0), None), (0.8, (0, 0, 0), None)]
atk["upperarm_l"] = [(0, (0, 0, 0), None), (0.3, (-20, -30, 0), None), (0.46, (20, 0, 0), None), (0.8, (0, 0, 0), None)]
atk["head"] = [(0, (0, 0, 0), None), (0.3, (-8, 0, 0), None), (0.46, (10, 0, 0), None), (0.8, (0, 0, 0), None)]
atk["jaw"] = [(0, (0, 0, 0), None), (0.3, (0, 0, 0), None), (0.46, (26, 0, 0), None), (0.8, (0, 0, 0), None)]
clip(rig, "Attack", 0.8, atk, loop=False)

hit = {"hips": [(0, (0, 0, 0), (0, 0, 0)), (0.1, (-12, 0, 6), (0, 0.1, -0.03)), (0.4, (0, 0, 0), (0, 0, 0))],
       "chest": [(0, (0, 0, 0), None), (0.1, (-14, 0, -8), None), (0.4, (0, 0, 0), None)],
       "head": [(0, (0, 0, 0), None), (0.1, (-22, 0, 10), None), (0.4, (0, 0, 0), None)],
       "jaw": [(0, (0, 0, 0), None), (0.1, (30, 0, 0), None), (0.4, (0, 0, 0), None)],
       "tail_01": [(0, (0, 0, 0), None), (0.1, (0, 0, 25), None), (0.4, (0, 0, 0), None)],
       "upperarm_l": [(0, (0, 0, 0), None), (0.1, (-30, -30, 0), None), (0.4, (0, 0, 0), None)]}
clip(rig, "Hit", 0.4, hit, loop=False)

# Die: staggers, drops to its knees, tips over backwards onto its tail.
die = {"hips": [(0, (0, 0, 0), (0, 0, 0)), (0.3, (-8, 0, 4), (0, 0.06, -0.1)), (0.7, (-30, 0, 8), (0, 0.4, -0.5)), (1.2, (-86, 0, 10), (0, 0.78, -0.78)), (1.5, (-90, 0, 10), (0, 0.82, -0.8))],
       "chest": [(0, (0, 0, 0), None), (0.7, (-12, 0, 0), None), (1.5, (6, 0, 0), None)],
       "head": [(0, (0, 0, 0), None), (0.7, (-24, 0, 0), None), (1.5, (-30, 0, 12), None)],
       "jaw": [(0, (0, 0, 0), None), (0.7, (20, 0, 0), None), (1.5, (32, 0, 0), None)],
       "thigh_l": [(0, (0, 0, 0), None), (0.7, (50, 0, 0), None), (1.5, (80, 0, 0), None)],
       "thigh_r": [(0, (0, 0, 0), None), (0.7, (50, 0, 0), None), (1.5, (70, 0, 5), None)],
       "shin_l": [(0, (0, 0, 0), None), (0.7, (-30, 0, 0), None), (1.5, (-60, 0, 0), None)],
       "shin_r": [(0, (0, 0, 0), None), (0.7, (-30, 0, 0), None), (1.5, (-50, 0, 0), None)],
       "upperarm_l": [(0, (0, 0, 0), None), (1.2, (-50, -50, 0), None), (1.5, (-60, -60, 0), None)],
       "upperarm_r": [(0, (0, 0, 0), None), (1.2, (-40, 40, 0), None), (1.5, (-50, 60, 0), None)],
       "tail_01": [(0, (0, 0, 0), None), (1.5, (0, 0, 20), None)]}
clip(rig, "Die", 1.5, die, loop=False)

export(rig, body, OUT + "bogfin_src.glb")
os.remove(OUT + "bogfin_tex.png")
