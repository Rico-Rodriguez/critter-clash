# Frozen Effigy (rh_effigy): a soldier carved from grey stone and sealed in ice. Great helm with a
# dark visor slit and pale eyes, an ice-crested crown, layered pauldrons with frozen spikes, a stiff
# cloak hung with icicles, a heater shield on the left arm and a long blade in the right hand.
# Writes assets/foes/frozen_effigy_src.glb. Run: python3 tools/blender/foes/effigy.py -- <repo root>
from kit import *

OUT = out_dir()
reset()

STONE = mat("ef_stone", "56626d", 0.6)
STONE_D = mat("ef_stone_d", "39434c", 0.6)
STONE_L = mat("ef_stone_l", "7d8b96", 0.6)
IRON = mat("ef_iron", "262d34", 0.45)
ICE = mat("ef_ice", "93d3ea")
ICE_D = mat("ef_ice_d", "4d8fae")
FROST = mat("ef_frost", "dbe8ef")
CLOTH = mat("ef_cloth", "34414d")
CLOTH_D = mat("ef_cloth_d", "222c35")
EYE = mat("ef_eye", "cdf3ff")
VOID = mat("ef_void", "05080a", 1.0)
BLADE = mat("ef_blade", "a7bcc8", 0.35)

S = [
    ("hips", (0, 0, 0.95), (0, 0, 1.1), None),
    ("spine_01", (0, 0, 1.1), (0, -0.01, 1.32), "hips"),
    ("chest", (0, -0.01, 1.32), (0, -0.02, 1.55), "spine_01"),
    ("neck", (0, -0.02, 1.55), (0, -0.03, 1.65), "chest"),
    ("head", (0, -0.03, 1.65), (0, -0.04, 1.95), "neck"),
    ("cloak", (0, 0.2, 1.52), (0, 0.32, 0.7), "chest"),
]
for s, x in (("l", 1), ("r", -1)):
    S += [
        ("thigh_" + s, (x * 0.17, 0, 0.98), (x * 0.17, 0, 0.54), "hips"),
        ("shin_" + s, (x * 0.17, 0, 0.54), (x * 0.17, 0.02, 0.1), "thigh_" + s),
        ("foot_" + s, (x * 0.17, 0.02, 0.1), (x * 0.17, -0.22, 0.04), "shin_" + s),
        ("upperarm_" + s, (x * 0.4, 0, 1.5), (x * 0.42, -0.02, 1.2), "chest"),
        ("forearm_" + s, (x * 0.42, -0.02, 1.2), (x * 0.4, -0.16, 1.02), "upperarm_" + s),
        ("hand_" + s, (x * 0.4, -0.16, 1.02), (x * 0.4, -0.24, 0.95), "forearm_" + s),
    ]
S.append(("shield", (0.5, -0.2, 1.05), (0.5, -0.26, 0.7), "forearm_l"))
S.append(("sword", (-0.4, -0.24, 0.97), (-0.4, -0.9, 1.14), "hand_r"))
rig = armature(S)

# Torso: a deep cuirass, broad at the shoulder, with a belt of plates at the waist.
chest = tube("cuirass", [((0, 0, 1.03), 0.19, 0.14), ((0, 0, 1.22), 0.24, 0.17), ((0, 0, 1.46), 0.3, 0.2), ((0, 0, 1.6), 0.2, 0.15)], STONE, n=8)
two_tone(chest, STONE_D, STONE_L, down=-0.4, up=0.8)
bind(chest, ["hips", "spine_01", "chest"])
bind(tube("gorget", [((0, -0.02, 1.57), 0.17, 0.15), ((0, -0.03, 1.7), 0.13, 0.12)], STONE_D, n=8), ["chest", "neck"])
bind(tube("belt", [((0, 0, 1.01), 0.21, 0.16), ((0, 0, 1.08), 0.215, 0.165)], IRON, n=8), ["hips", "spine_01"])
bind(plate("buckle", (0, -0.17, 1.05), (0.09, 0.04, 0.08), STONE_L), ["hips"])
bind(plate("rib", (0, -0.2, 1.33), (0.34, 0.04, 0.05), STONE_D, rot=(0.15, 0, 0)), ["chest", "spine_01"])
bind(crystal("frostpeak", (0, -0.19, 1.4), (0, -0.28, 1.55), 0.05, ICE, n=5), ["chest"])
# Tassets over the thighs.
bind(plate("tas_f", (0, -0.15, 0.85), (0.22, 0.03, 0.3), STONE_D, rot=(0.12, 0, 0)), ["hips", "thigh_l", "thigh_r"])
for s, x in (("l", 1), ("r", -1)):
    bind(plate("tas_" + s, (x * 0.2, -0.1, 0.83), (0.15, 0.03, 0.3), STONE, rot=(0.1, x * 0.1, x * -0.35)), ["hips", "thigh_" + s])
    bind(plate("tas_b" + s, (x * 0.18, 0.12, 0.84), (0.16, 0.03, 0.28), STONE_D, rot=(-0.1, 0, x * 0.3)), ["hips", "thigh_" + s])

# Great helm: a stone barrel with a dark visor slit, pale eyes, a ridge and a crest of ice.
bind(tube("helm", [((0, -0.04, 1.64), 0.14, 0.15), ((0, -0.04, 1.77), 0.17, 0.18), ((0, -0.04, 1.9), 0.16, 0.17), ((0, -0.04, 1.98), 0.08, 0.09)], STONE, n=8), ["head"])
bind(plate("slit", (0, -0.205, 1.8), (0.22, 0.05, 0.045), VOID), ["head"])
bind(plate("breath", (0, -0.2, 1.7), (0.045, 0.04, 0.13), VOID), ["head"])
for x in (1, -1):
    bind(plate("eye", (x * 0.06, -0.228, 1.8), (0.05, 0.012, 0.022), EYE), ["head"])
    bind(plate("cheek", (x * 0.13, -0.12, 1.72), (0.04, 0.16, 0.18), STONE_D, rot=(0, 0, x * -0.25)), ["head"])
bind(plate("ridge", (0, -0.2, 1.86), (0.04, 0.05, 0.2), STONE_L), ["head"])
for k, (y, h) in enumerate([(-0.1, 0.12), (0.0, 0.2), (0.1, 0.16), (0.17, 0.1)]):
    bind(crystal("crest%d" % k, (0, y, 1.97 - k * 0.03), (0, y + 0.08, 1.97 - k * 0.03 + h), 0.04, ICE if k % 2 else ICE_D, n=4), ["head"])

# Shoulders: two layered plates and a frozen spike each; arms in plate.
for s, x in (("l", 1), ("r", -1)):
    P = lambda v: (x * v[0], v[1], v[2])
    bind(plate("paul_" + s, P((0.43, 0, 1.58)), (0.28, 0.24, 0.1), STONE, rot=(0, x * 0.0, x * -0.3)), ["chest", "upperarm_" + s])
    bind(plate("paul2_" + s, P((0.47, 0, 1.47)), (0.26, 0.22, 0.08), STONE_D, rot=(0, 0, x * -0.45)), ["upperarm_" + s])
    bind(crystal("spike_" + s, P((0.44, 0, 1.62)), P((0.5, 0.0, 1.92)), 0.06, ICE, n=5), ["chest", "upperarm_" + s])
    bind(crystal("spike2_" + s, P((0.52, -0.02, 1.6)), P((0.72, -0.02, 1.76)), 0.04, ICE_D, n=4), ["upperarm_" + s])
    bind(tube("arm_" + s, [(P((0.4, 0, 1.5)), 0.085, 0.085), (P((0.42, -0.02, 1.2)), 0.07, 0.07), (P((0.4, -0.16, 1.02)), 0.065, 0.065)], STONE_D, n=6),
         ["chest", "upperarm_" + s, "forearm_" + s])
    bind(plate("couter_" + s, P((0.44, 0.0, 1.2)), (0.1, 0.12, 0.12), STONE, rot=(0, 0, x * 0.3)), ["upperarm_" + s, "forearm_" + s])
    bind(plate("vamb_" + s, P((0.42, -0.1, 1.1)), (0.14, 0.2, 0.1), STONE, rot=(0.5, 0, 0)), ["forearm_" + s])
    bind(blob("gaunt_" + s, P((0.4, -0.2, 0.97)), (0.11, 0.13, 0.11), IRON, sub=1), ["hand_" + s])
    # Legs: stone cuisse, knee plate with a frost spike, greave, a wide sabaton.
    bind(tube("leg_" + s, [(P((0.17, 0, 1.0)), 0.115, 0.115), (P((0.17, 0, 0.55)), 0.09, 0.09), (P((0.17, 0.02, 0.12)), 0.075, 0.075)], STONE_D, n=6),
         ["hips", "thigh_" + s, "shin_" + s])
    bind(plate("knee_" + s, P((0.17, -0.08, 0.56)), (0.16, 0.08, 0.14), STONE, rot=(0.2, 0, 0)), ["thigh_" + s, "shin_" + s])
    bind(crystal("kspike_" + s, P((0.17, -0.12, 0.58)), P((0.17, -0.24, 0.66)), 0.035, ICE, n=4), ["thigh_" + s, "shin_" + s])
    bind(plate("greave_" + s, P((0.17, -0.07, 0.3)), (0.14, 0.04, 0.38), STONE, rot=(-0.05, 0, 0)), ["shin_" + s])
    bind(tube("boot_" + s, [(P((0.17, 0.05, 0.11)), 0.09, 0.07), (P((0.17, -0.1, 0.06)), 0.1, 0.06), (P((0.17, -0.28, 0.03)), 0.06, 0.04)], IRON, n=6), ["foot_" + s, "shin_" + s])

# Cloak: stiff, frozen in folds, a hem of icicles.
bind(sheet("cloak_top", [(-0.3, 0.19, 1.58), (0.3, 0.19, 1.58), (0.38, 0.27, 1.2), (-0.38, 0.27, 1.2)], CLOTH, 0.03), ["chest", "cloak"])
bind(sheet("cloak_low", [(-0.38, 0.27, 1.2), (0.38, 0.27, 1.2), (0.46, 0.33, 0.78), (0.2, 0.36, 0.62), (-0.2, 0.36, 0.62), (-0.46, 0.33, 0.78)], CLOTH_D, 0.03), ["cloak"])
for k in range(6):
    x = -0.34 + k * 0.136
    bind(cone("icicle%d" % k, (x, 0.34, 0.72), (x * 1.05, 0.36, 0.48 - 0.05 * (k % 2) - 0.04), 0.035, FROST, n=3), ["cloak"])

# Shield (left forearm): a heater of dark iron with a stone rim and an ice boss.
bind(sheet("shield", [(0.28, -0.3, 1.3), (0.74, -0.3, 1.3), (0.78, -0.3, 1.02), (0.5, -0.33, 0.52), (0.24, -0.3, 1.02)], IRON, 0.05), ["shield", "forearm_l"])
bind(sheet("shield_rim", [(0.28, -0.335, 1.3), (0.74, -0.335, 1.3), (0.72, -0.335, 1.22), (0.3, -0.335, 1.22)], STONE_L, 0.02), ["shield", "forearm_l"])
bind(crystal("boss", (0.51, -0.34, 1.0), (0.51, -0.5, 1.0), 0.07, ICE, n=6), ["shield"])
bind(crystal("shield_ice", (0.34, -0.3, 1.3), (0.34, -0.3, 1.5), 0.04, ICE_D, n=4), ["shield"])
bind(crystal("shield_ice2", (0.66, -0.3, 1.3), (0.7, -0.3, 1.46), 0.035, ICE, n=4), ["shield"])

# Sword (right hand): a broad blade, crossguard, grip and a stone pommel.
bind(tube("blade", [((-0.4, -0.36, 0.99), 0.05, 0.014), ((-0.4, -0.62, 1.06), 0.055, 0.014), ((-0.4, -0.82, 1.12), 0.04, 0.01), ((-0.4, -0.94, 1.155), 0.004, 0.004)],
          BLADE, n=4), ["sword"])
bind(plate("guard", (-0.4, -0.33, 0.985), (0.26, 0.04, 0.04), IRON, rot=(0.28, 0, 0)), ["sword"])
bind(tube("grip", [((-0.4, -0.16, 0.95), 0.022, 0.022), ((-0.4, -0.31, 0.98), 0.022, 0.022)], IRON, n=4), ["sword", "hand_r"])
bind(blob("pommel", (-0.4, -0.14, 0.945), (0.06, 0.06, 0.06), STONE_L, sub=1), ["sword"])

knight = skin(rig, "Effigy")
bake(knight, 512, OUT + "effigy_tex.png")


def stride(P, amp, flex, arm):
    ks = {}
    for s in "lr":
        a = (amp, -amp) if s == "l" else (-amp, amp)
        ks["thigh_" + s] = cyc(P, *[(v, 0, 0) for v in a])
        ks["shin_" + s] = cyc(P, *[(flex if v < 0 else 4, 0, 0) for v in a])
        ks["foot_" + s] = cyc(P, *[(-flex * 0.4 if v < 0 else 0, 0, 0) for v in a])
        sw = (-arm, arm) if s == "l" else (arm, -arm)
        ks["upperarm_" + s] = cyc(P, *[(v, 0, 0) for v in sw])
    return ks


def sway(ks, P, a):
    ks["cloak"] = cyc(P, (a, 0, 0), (-a * 0.6, 0, 0))
    return ks


idle = sway({}, 2.4, 3)
idle["chest"] = cyc(2.4, (-1.5, 0, 0), (1.5, 0, 0))
idle["head"] = cyc(2.4, (0, 0, -4), (1, 0, 4))
idle["hips"] = cycl(2.4, ((0, 0, 0), (0, 0, 0)), ((0, 0, 0), (0, 0, 0.012)))
idle["upperarm_l"] = cyc(2.4, (0, 0, 0), (-3, 0, 0))
idle["upperarm_r"] = cyc(2.4, (-2, 0, 0), (2, 0, 0))
clip(rig, "Idle", 2.4, idle)

walk = sway(stride(1.2, 22, 36, 8), 1.2, 6)
walk["hips"] = [(0, (0, 0, 3), (0, 0, 0)), (0.3, (0, 0, 0), (0, 0, 0.03)), (0.6, (0, 0, -3), (0, 0, 0)), (0.9, (0, 0, 0), (0, 0, 0.03)), (1.2, (0, 0, 3), (0, 0, 0))]
walk["chest"] = cyc(1.2, (2, 0, -4), (2, 0, 4))
walk["head"] = cyc(1.2, (0, 0, 3), (0, 0, -3))
clip(rig, "Walk", 1.2, walk)

run = sway(stride(0.7, 40, 70, 20), 0.7, 10)
run["hips"] = [(0, (8, 0, 4), (0, 0, 0)), (0.175, (8, 0, 0), (0, 0, 0.05)), (0.35, (8, 0, -4), (0, 0, 0)), (0.525, (8, 0, 0), (0, 0, 0.05)), (0.7, (8, 0, 4), (0, 0, 0))]
run["chest"] = cyc(0.7, (4, 0, -6), (4, 0, 6))
clip(rig, "Run", 0.7, run)

# Attack: the blade swings up over the head, then cleaves down; the shield stays braced.
atk = sway({}, 1.0, 8)
atk["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.4, (-4, 0, 0), (0, 0.04, 0)), (0.56, (10, 0, 0), (0, -0.2, -0.04)), (1.0, (0, 0, 0), (0, 0, 0))]
atk["spine_01"] = [(0, (0, 0, 0), None), (0.4, (-10, 0, 0), None), (0.56, (16, 0, 0), None), (1.0, (0, 0, 0), None)]
atk["chest"] = [(0, (0, 0, 0), None), (0.4, (-8, 0, -10), None), (0.56, (12, 0, 14), None), (1.0, (0, 0, 0), None)]
atk["head"] = [(0, (0, 0, 0), None), (0.4, (-6, 0, 0), None), (0.56, (10, 0, 0), None), (1.0, (0, 0, 0), None)]
atk["upperarm_r"] = [(0, (0, 0, 0), None), (0.4, (-165, 0, 0), None), (0.56, (-30, 0, 0), None), (0.72, (-24, 0, 0), None), (1.0, (0, 0, 0), None)]
atk["forearm_r"] = [(0, (0, 0, 0), None), (0.4, (-24, 0, 0), None), (0.56, (-8, 0, 0), None), (1.0, (0, 0, 0), None)]
atk["upperarm_l"] = [(0, (0, 0, 0), None), (0.4, (-30, 0, 0), None), (0.56, (-14, 0, 0), None), (1.0, (0, 0, 0), None)]
atk["thigh_l"] = [(0, (0, 0, 0), None), (0.4, (8, 0, 0), None), (0.56, (-22, 0, 0), None), (1.0, (0, 0, 0), None)]
atk["shin_l"] = [(0, (0, 0, 0), None), (0.56, (14, 0, 0), None), (1.0, (0, 0, 0), None)]
atk["thigh_r"] = [(0, (0, 0, 0), None), (0.4, (-8, 0, 0), None), (0.56, (16, 0, 0), None), (1.0, (0, 0, 0), None)]
clip(rig, "Attack", 1.0, atk, loop=False)

# Cast: the blade raised high in both hands' worth of stance, a stamp, and the frost answers.
cast = sway({}, 1.4, 10)
cast["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.45, (-6, 0, 0), (0, 0.04, 0.02)), (0.7, (6, 0, 0), (0, -0.05, -0.05)), (1.4, (0, 0, 0), (0, 0, 0))]
cast["chest"] = [(0, (0, 0, 0), None), (0.45, (-14, 0, 0), None), (0.7, (10, 0, 0), None), (1.4, (0, 0, 0), None)]
cast["head"] = [(0, (0, 0, 0), None), (0.45, (-16, 0, 0), None), (0.7, (8, 0, 0), None), (1.4, (0, 0, 0), None)]
cast["upperarm_r"] = [(0, (0, 0, 0), None), (0.45, (-150, -10, 0), None), (0.7, (-120, -10, 0), None), (1.4, (0, 0, 0), None)]
cast["forearm_r"] = [(0, (0, 0, 0), None), (0.45, (-20, 0, 0), None), (1.4, (0, 0, 0), None)]
cast["upperarm_l"] = [(0, (0, 0, 0), None), (0.45, (-100, 14, 0), None), (0.7, (-70, 10, 0), None), (1.4, (0, 0, 0), None)]
cast["forearm_l"] = [(0, (0, 0, 0), None), (0.45, (-14, 0, 0), None), (1.4, (0, 0, 0), None)]
cast["thigh_r"] = [(0, (0, 0, 0), None), (0.45, (-26, 0, 0), None), (0.7, (4, 0, 0), None), (1.4, (0, 0, 0), None)]
cast["shin_r"] = [(0, (0, 0, 0), None), (0.45, (40, 0, 0), None), (0.7, (0, 0, 0), None), (1.4, (0, 0, 0), None)]
clip(rig, "Cast", 1.4, cast, loop=False)

hit = sway({}, 0.45, 12)
hit["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.1, (-6, 0, 4), (0, 0.1, -0.02)), (0.45, (0, 0, 0), (0, 0, 0))]
hit["chest"] = [(0, (0, 0, 0), None), (0.1, (-10, 0, -8), None), (0.45, (0, 0, 0), None)]
hit["head"] = [(0, (0, 0, 0), None), (0.1, (-12, 0, 8), None), (0.45, (0, 0, 0), None)]
hit["upperarm_r"] = [(0, (0, 0, 0), None), (0.1, (14, 10, 0), None), (0.45, (0, 0, 0), None)]
hit["upperarm_l"] = [(0, (0, 0, 0), None), (0.1, (-12, -10, 0), None), (0.45, (0, 0, 0), None)]
clip(rig, "Hit", 0.45, hit, loop=False)

# Die: the knees give, it staggers back and topples forward like a felled statue.
die = {}
die["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.2, (-8, 0, 0), (0, 0.12, -0.04)), (0.5, (-4, 0, 0), (0, 0.2, -0.36)), (0.95, (84, 0, 0), (0, -0.55, -0.72)), (1.3, (86, 0, 0), (0, -0.58, -0.76))]
die["chest"] = [(0, (0, 0, 0), None), (0.2, (-14, 0, 0), None), (0.5, (-8, 0, 0), None), (0.95, (6, 0, 0), None), (1.3, (6, 0, 0), None)]
die["head"] = [(0, (0, 0, 0), None), (0.2, (-18, 0, 0), None), (0.95, (-30, 0, 12), None), (1.3, (-34, 0, 14), None)]
for s, sg in (("l", 1), ("r", -1)):
    die["thigh_" + s] = [(0, (0, 0, 0), None), (0.5, (-56, 0, 0), None), (0.95, (-8, 0, 0), None), (1.3, (-6, 0, 0), None)]
    die["shin_" + s] = [(0, (0, 0, 0), None), (0.5, (90, 0, 0), None), (0.95, (10, 0, 0), None), (1.3, (6, 0, 0), None)]
    die["upperarm_" + s] = [(0, (0, 0, 0), None), (0.2, (-34, -sg * 30, 0), None), (0.95, (-160, -sg * 20, 0), None), (1.3, (-166, -sg * 24, 0), None)]
    die["forearm_" + s] = [(0, (0, 0, 0), None), (0.95, (-20, 0, 0), None)]
die["cloak"] = [(0, (0, 0, 0), None), (0.5, (-12, 0, 0), None), (0.95, (-14, 0, 0), None), (1.3, (-14, 0, 0), None)]
clip(rig, "Death", 1.3, die, loop=False)

# Spawn: a statue at rest, head bowed, then it cracks, shudders, straightens and lifts its head.
sp = {}
sp["hips"] = [(0, (0, 0, 0), (0, 0, -0.03)), (0.5, (0, 0, 0), (0, 0, -0.03)), (1.1, (0, 0, 0), (0, 0, 0.01)), (1.6, (0, 0, 0), (0, 0, 0))]
sp["chest"] = [(0, (10, 0, 0), None), (0.3, (10, 0, 3), None), (0.4, (10, 0, -3), None), (0.5, (10, 0, 3), None), (0.7, (4, 0, -2), None), (1.1, (-6, 0, 0), None), (1.6, (0, 0, 0), None)]
sp["head"] = [(0, (34, 0, 0), None), (0.5, (34, 0, 0), None), (1.1, (-14, 0, 0), None), (1.6, (0, 0, 0), None)]
for s, sg in (("l", 1), ("r", -1)):
    sp["upperarm_" + s] = [(0, (8, -sg * 4, 0), None), (0.5, (8, -sg * 4, 0), None), (1.1, (-6, 0, 0), None), (1.6, (0, 0, 0), None)]
    sp["thigh_" + s] = [(0, (-4, 0, 0), None), (0.5, (-4, 0, 0), None), (1.1, (0, 0, 0), None)]
sp["cloak"] = [(0, (4, 0, 0), None), (0.5, (4, 0, 0), None), (1.1, (-6, 0, 0), None), (1.6, (0, 0, 0), None)]
clip(rig, "Spawn", 1.6, sp, loop=False)

export(rig, knight, OUT + "frozen_effigy_src.glb")
os.remove(OUT + "effigy_tex.png")
