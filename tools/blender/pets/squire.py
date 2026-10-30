# Barrow Squire: a small, loyal skeleton knight from the first king's barrow,
# at grown proportions. Old bone in old iron: a gilt-banded kettle helm with a
# red plume, a breastplate over the ribs, a faded red tabard, pauldrons,
# gauntlets and greaves, a round shield on its left arm and a short notched
# sword. Writes assets/sidekicks/squire_src.glb.
# Run: <blender python> tools/blender/pets/squire.py -- <repo root>
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *

ROOT = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(ROOT, "assets/sidekicks/")
reset()

BONE = mat("sq_bone", "e3d8bb")
BONE_D = mat("sq_bone_d", "a8997a")
IRON = mat("sq_iron", "6f747c", 0.45)
IRON_D = mat("sq_iron_d", "474b52", 0.5)
GILT = mat("sq_gilt", "cdaf5a", 0.35)
RED = mat("sq_red", "8e2a26")
RED_D = mat("sq_red_d", "5e1b19")
VOID = mat("sq_void", "15100c", 1.0)
EYE = mat("sq_eye", "ffe39a")
LEATHER = mat("sq_leather", "4a3424")

S = [
    ("hips", (0, 0, 0.62), (0, 0, 0.8), None),
    ("spine_01", (0, 0, 0.8), (0, -0.01, 1.02), "hips"),
    ("chest", (0, -0.01, 1.02), (0, -0.02, 1.22), "spine_01"),
    ("neck_01", (0, -0.02, 1.22), (0, -0.04, 1.32), "chest"),
    ("head", (0, -0.04, 1.32), (0, -0.05, 1.6), "neck_01"),
]
for s, x in (("l", 1), ("r", -1)):
    S += [
        ("thigh_" + s, (x * 0.1, 0, 0.62), (x * 0.11, 0, 0.34), "hips"),
        ("shin_" + s, (x * 0.11, 0, 0.34), (x * 0.11, 0.02, 0.07), "thigh_" + s),
        ("foot_" + s, (x * 0.11, 0.02, 0.07), (x * 0.11, -0.12, 0.03), "shin_" + s),
        ("upperarm_" + s, (x * 0.2, -0.02, 1.18), (x * 0.26, -0.02, 0.94), "chest"),
        ("forearm_" + s, (x * 0.26, -0.02, 0.94), (x * 0.28, -0.1, 0.75), "upperarm_" + s),
        ("hand_" + s, (x * 0.28, -0.1, 0.75), (x * 0.29, -0.14, 0.67), "forearm_" + s),
    ]
# Shield and sword on their own bones, so a bred pet's arms take the donor's
# colours while the gear keeps its own.
S.append(("shield", (0.3, -0.08, 0.86), (0.3, -0.12, 0.76), "forearm_l"))
S.append(("sword", (-0.29, -0.13, 0.7), (-0.29, -0.4, 0.66), "hand_r"))
rig = armature(S)

# Skull under a kettle helm: brow, cheekbones, dark sockets with a gold glint, a jaw.
bind(blob("skull", (0, -0.06, 1.46), (0.21, 0.23, 0.22), BONE), ["head"])
bind(blob("jaw", (0, -0.12, 1.35), (0.15, 0.13, 0.07), BONE_D), ["head"])
for x in (1, -1):
    bind(blob("socket", (x * 0.05, -0.165, 1.45), (0.065, 0.03, 0.06), VOID), ["head"])
    bind(blob("glint", (x * 0.05, -0.18, 1.45), (0.022, 0.012, 0.022), EYE, sub=1), ["head"])
    bind(blob("cheek", (x * 0.075, -0.15, 1.4), (0.05, 0.05, 0.035), BONE), ["head"])
bind(blob("nose", (0, -0.175, 1.41), (0.03, 0.015, 0.035), VOID, sub=1), ["head"])
for k in range(5):
    bind(blob("tooth%d" % k, ((k - 2) * 0.024, -0.175, 1.37), (0.018, 0.012, 0.025), BONE, sub=0), ["head"])
bind(blob("dome", (0, -0.06, 1.57), (0.26, 0.27, 0.2), IRON), ["head"])
brim = [((math.cos(a) * 0.175, -0.06 + math.sin(a) * 0.185, 1.5), 0.014, 0.014) for a in [i * math.pi * 2 / 20 for i in range(21)]]
bind(tube("brim", brim, GILT, n=4, sub=0), ["head"])
bind(tube("brimdisc", [((0, -0.06, 1.54), 0.13, 0.135), ((0, -0.06, 1.5), 0.175, 0.185)], IRON_D, n=20, sub=0, cap0=False, cap1=False), ["head"])
bind(blob("comb", (0, -0.06, 1.66), (0.03, 0.24, 0.06), GILT, sub=1), ["head"])
bind(tube("plume", [((0, -0.02, 1.64), 0.03, 0.03), ((0, 0.06, 1.71), 0.05, 0.04), ((0, 0.16, 1.68), 0.045, 0.035),
                    ((0, 0.24, 1.56), 0.025, 0.02), ((0, 0.27, 1.48), 0.008, 0.008)], RED, n=8), ["head"])

# Neck and spine bones, a ribcage half hidden under the breastplate, a pelvis.
bind(tube("neck", [((0, -0.03, 1.22), 0.035, 0.035), ((0, -0.04, 1.34), 0.03, 0.03)], BONE_D, n=6), ["neck_01", "head"])
bind(tube("spine", [((0, 0.01, 0.74), 0.04, 0.04), ((0, 0.0, 0.95), 0.04, 0.04)], BONE_D, n=6), ["hips", "spine_01"])
for k in range(3):
    bind(blob("vert%d" % k, (0, 0.0, 0.8 + k * 0.065), (0.07, 0.06, 0.035), BONE, sub=1), ["spine_01" if k else "hips"])
bind(blob("pelvis", (0, 0.0, 0.66), (0.26, 0.15, 0.12), BONE), ["hips"])
bind(tube("plate", [((0, -0.01, 0.95), 0.15, 0.11), ((0, -0.025, 1.08), 0.2, 0.145), ((0, -0.02, 1.2), 0.19, 0.13),
                    ((0, -0.02, 1.25), 0.1, 0.08)], IRON, n=12), ["spine_01", "chest"])
rim = [((math.cos(a) * 0.155, -0.01 + math.sin(a) * 0.115, 0.955), 0.013, 0.013) for a in [i * math.pi * 2 / 16 for i in range(17)]]
bind(tube("platerim", rim, GILT, n=4, sub=0), ["spine_01"])
for x in (1, -1):
    bind(blob("pauldron", (x * 0.2, -0.02, 1.19), (0.17, 0.2, 0.11), IRON_D, rot=(0, x * 0.5, 0)), ["upperarm_" + ("l" if x > 0 else "r")])
# A faded tabard, front and back, hanging from a leather belt.
belt = [((math.cos(a) * 0.15, math.sin(a) * 0.1, 0.74), 0.015, 0.015) for a in [i * math.pi * 2 / 16 for i in range(17)]]
bind(tube("belt", belt, LEATHER, n=5, sub=0), ["hips"])
bind(sheet("tab_f", [(0, -0.11, 0.74), (0.11, -0.1, 0.74), (0.12, -0.12, 0.42), (0.04, -0.13, 0.38), (-0.04, -0.13, 0.42),
                     (-0.12, -0.12, 0.4), (-0.11, -0.1, 0.74)], RED, 0.015), ["hips", "thigh_l", "thigh_r"])
bind(sheet("tab_stripe", [(0, -0.128, 0.73), (0.025, -0.128, 0.73), (0.025, -0.138, 0.43), (-0.025, -0.138, 0.43), (-0.025, -0.128, 0.73)],
           GILT, 0.005), ["hips", "thigh_l", "thigh_r"])
bind(sheet("tab_b", [(0, 0.1, 0.74), (0.11, 0.09, 0.74), (0.12, 0.11, 0.44), (0.0, 0.12, 0.4), (-0.12, 0.11, 0.44),
                     (-0.11, 0.09, 0.74)], RED_D, 0.015), ["hips", "thigh_l", "thigh_r"])

# Bony limbs, iron at the shins, hands and feet.
for s, x in (("l", 1), ("r", -1)):
    P = lambda v: (x * v[0], v[1], v[2])
    bind(tube("femur_" + s, [(P((0.1, 0, 0.62)), 0.045, 0.045), (P((0.11, 0, 0.36)), 0.04, 0.04)], BONE, n=6), ["thigh_" + s])
    bind(blob("knee_" + s, P((0.11, -0.025, 0.34)), (0.1, 0.09, 0.09), IRON_D, sub=1), ["shin_" + s])
    bind(tube("greave_" + s, [(P((0.11, 0, 0.31)), 0.06, 0.06), (P((0.11, 0.015, 0.14)), 0.055, 0.055), (P((0.11, 0.02, 0.07)), 0.05, 0.05)], IRON, n=8), ["shin_" + s])
    bind(blob("sabaton_" + s, P((0.11, -0.04, 0.045)), (0.1, 0.2, 0.08), IRON_D), ["foot_" + s])
    bind(tube("humerus_" + s, [(P((0.2, -0.02, 1.16)), 0.04, 0.04), (P((0.26, -0.02, 0.95)), 0.036, 0.036)], BONE, n=6), ["upperarm_" + s])
    bind(blob("elbow_" + s, P((0.26, -0.02, 0.94)), (0.08, 0.08, 0.08), IRON_D, sub=1), ["forearm_" + s])
    bind(tube("bracer_" + s, [(P((0.265, -0.04, 0.9)), 0.05, 0.05), (P((0.28, -0.1, 0.77)), 0.055, 0.055)], IRON, n=8), ["forearm_" + s])
    bind(tube("radius_" + s, [(P((0.26, -0.02, 0.93)), 0.024, 0.024), (P((0.28, -0.09, 0.78)), 0.022, 0.022)], BONE, n=6), ["forearm_" + s])
    bind(blob("gauntlet_" + s, P((0.285, -0.12, 0.72)), (0.085, 0.1, 0.1), IRON), ["hand_" + s])

# Round shield on the left arm: iron rim, red field, gilt boss.
bind(tube("shield_rim", [((0.3, -0.13, 0.85), 0.21, 0.21), ((0.3, -0.17, 0.85), 0.21, 0.21)], IRON_D, n=18, sub=0), ["shield"])
bind(tube("shield_face", [((0.3, -0.165, 0.85), 0.185, 0.185), ((0.3, -0.178, 0.85), 0.185, 0.185)], RED, n=18, sub=0), ["shield"])
bind(tube("shield_bar", [((0.3, -0.18, 0.67), 0.014, 0.014), ((0.3, -0.18, 1.03), 0.014, 0.014)], GILT, n=4, sub=0), ["shield"])
bind(blob("boss", (0.3, -0.19, 0.85), (0.1, 0.05, 0.1), GILT, sub=2), ["shield"])

# Short sword, held low and forward: leather grip, gilt guard, a notched blade.
bind(tube("grip", [((-0.29, -0.09, 0.71), 0.016, 0.016), ((-0.29, -0.17, 0.7), 0.016, 0.016)], LEATHER, n=6, sub=0), ["sword"])
bind(blob("pommel", (-0.29, -0.08, 0.71), (0.035, 0.035, 0.035), GILT, sub=1), ["sword"])
bind(blob("guard", (-0.29, -0.18, 0.7), (0.17, 0.03, 0.03), GILT, sub=1), ["sword"])
bind(tube("blade", [((-0.29, -0.19, 0.7), 0.01, 0.042), ((-0.29, -0.5, 0.66), 0.009, 0.038), ((-0.29, -0.66, 0.64), 0.004, 0.006)],
          IRON, n=6, sub=0), ["sword"])
bind(blob("notch", (-0.29, -0.4, 0.71), (0.024, 0.035, 0.02), VOID, sub=0), ["sword"])

sq = skin(rig, "Squire")
bake(sq, 1024, OUT + "squire_tex.png")


# Clips: +X pitches forward or swings a leg back, -Y lifts the left arm, Z turns.
def stride(period, a, knee, arm):
    ks = {}
    for s, sg in (("l", 1), ("r", -1)):
        ks["thigh_" + s] = [(0, (-sg * a, 0, 0), None), (period / 2, (sg * a, 0, 0), None), (period, (-sg * a, 0, 0), None)]
        # The knee folds as that leg swings through, half a stride apart.
        if sg > 0:
            ks["shin_" + s] = [(0, (knee * 0.2, 0, 0), None), (period * 0.25, (knee, 0, 0), None),
                               (period * 0.5, (knee * 0.1, 0, 0), None), (period, (knee * 0.2, 0, 0), None)]
        else:
            ks["shin_" + s] = [(0, (knee * 0.1, 0, 0), None), (period * 0.5, (knee * 0.2, 0, 0), None),
                               (period * 0.75, (knee, 0, 0), None), (period, (knee * 0.1, 0, 0), None)]
        o = "upperarm_l" if s == "r" else "upperarm_r"
        ks[o] = [(0, (-sg * arm, 0, 0), None), (period / 2, (sg * arm, 0, 0), None), (period, (-sg * arm, 0, 0), None)]
    return ks

# A ready stance: shield arm raised a little, sword arm forward.
GUARD_L = (-25, 0, 0)

idle = {"upperarm_l": [(0, GUARD_L, None), (1.0, (-28, 0, 0), None), (2.0, GUARD_L, None)]}
idle["chest"] = [(0, (0, 0, 0), None), (1.0, (2, 0, 0), None), (2.0, (0, 0, 0), None)]
idle["head"] = [(0, (0, 0, -6), None), (1.0, (3, 0, 6), None), (2.0, (0, 0, -6), None)]
idle["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (1.0, (0, 0, 0), (0, 0, -0.01)), (2.0, (0, 0, 0), (0, 0, 0))]
clip(rig, "Idle", 2.0, idle)

walk = stride(0.8, 26, 42, 16)
walk["upperarm_l"] = [(0, GUARD_L, None), (0.8, GUARD_L, None)]
walk["hips"] = [(0, (0, 0, 4), (0, 0, 0)), (0.2, (0, 0, 0), (0, 0, 0.025)), (0.4, (0, 0, -4), (0, 0, 0)),
                (0.6, (0, 0, 0), (0, 0, 0.025)), (0.8, (0, 0, 4), (0, 0, 0))]
walk["chest"] = [(0, (4, 0, -5), None), (0.4, (4, 0, 5), None), (0.8, (4, 0, -5), None)]
clip(rig, "Walk", 0.8, walk)

run = stride(0.5, 38, 72, 28)
run["upperarm_l"] = [(0, (-40, 0, 0), None), (0.5, (-40, 0, 0), None)]
run["hips"] = [(0, (14, 0, 6), (0, 0, 0)), (0.125, (14, 0, 0), (0, 0, 0.04)), (0.25, (14, 0, -6), (0, 0, 0)),
               (0.375, (14, 0, 0), (0, 0, 0.04)), (0.5, (14, 0, 6), (0, 0, 0))]
clip(rig, "Run", 0.5, run)

# Shield Bash: a step in, the shield thrust forward, then slammed down.
atk = {}
atk["upperarm_l"] = [(0, GUARD_L, None), (0.22, (-30, 30, 20), None), (0.38, (-80, 0, -10), None), (0.5, (-40, 0, 0), None), (0.8, GUARD_L, None)]
atk["forearm_l"] = [(0, (0, 0, 0), None), (0.22, (-30, 0, 0), None), (0.38, (-10, 0, 0), None), (0.8, (0, 0, 0), None)]
atk["upperarm_r"] = [(0, (0, 0, 0), None), (0.22, (20, 0, 0), None), (0.5, (10, 0, 0), None), (0.8, (0, 0, 0), None)]
atk["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.22, (-4, 0, -14), (0, 0.04, 0.02)), (0.38, (14, 0, 10), (0, -0.14, -0.04)),
               (0.5, (16, 0, 6), (0, -0.14, -0.06)), (0.8, (0, 0, 0), (0, 0, 0))]
atk["thigh_l"] = [(0, (0, 0, 0), None), (0.38, (-30, 0, 0), None), (0.5, (-34, 0, 0), None), (0.8, (0, 0, 0), None)]
atk["shin_l"] = [(0, (0, 0, 0), None), (0.38, (24, 0, 0), None), (0.5, (34, 0, 0), None), (0.8, (0, 0, 0), None)]
atk["thigh_r"] = [(0, (0, 0, 0), None), (0.38, (18, 0, 0), None), (0.8, (0, 0, 0), None)]
clip(rig, "Attack", 0.8, atk, loop=False)

hit = {"upperarm_l": [(0, GUARD_L, None), (0.12, (-50, 0, 0), None), (0.45, GUARD_L, None)]}
hit["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.12, (-12, 0, 8), (0, 0.06, 0)), (0.45, (0, 0, 0), (0, 0, 0))]
hit["head"] = [(0, (0, 0, 0), None), (0.12, (-18, 0, 10), None), (0.45, (0, 0, 0), None)]
clip(rig, "Hit", 0.45, hit, loop=False)

# Special: the sword raised to the sky, shield braced, head up.
sp = {}
sp["upperarm_r"] = [(0, (0, 0, 0), None), (0.4, (-150, 0, 0), None), (0.9, (-150, 0, 0), None), (1.2, (0, 0, 0), None)]
sp["forearm_r"] = [(0, (0, 0, 0), None), (0.4, (-10, 0, 0), None), (0.9, (-10, 0, 0), None), (1.2, (0, 0, 0), None)]
sp["upperarm_l"] = [(0, GUARD_L, None), (0.4, (-45, 0, 0), None), (0.9, (-45, 0, 0), None), (1.2, GUARD_L, None)]
sp["head"] = [(0, (0, 0, 0), None), (0.4, (-20, 0, 0), None), (0.9, (-20, 0, 0), None), (1.2, (0, 0, 0), None)]
sp["chest"] = [(0, (0, 0, 0), None), (0.4, (-8, 0, 0), None), (0.9, (-8, 0, 0), None), (1.2, (0, 0, 0), None)]
clip(rig, "Special", 1.2, sp, loop=False)

export(rig, sq, OUT + "squire_src.glb")
os.remove(OUT + "squire_tex.png")
