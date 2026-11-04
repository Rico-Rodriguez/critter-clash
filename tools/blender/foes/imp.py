# Rime Crawler (rh_imp): a hunched, long-armed frost ghoul that skitters on all fours, knuckles
# near the ground, ice crystals along its spine and horns, pale eyes in a dark skull.
# Writes assets/foes/frost_imp_src.glb. Run: python3 tools/blender/foes/imp.py -- <repo root>
from kit import *

OUT = out_dir()
reset()

SKIN = mat("imp_skin", "26323f")
BELLY = mat("imp_belly", "607b8b")
DARK = mat("imp_dark", "141b22")
ICE = mat("imp_ice", "8fd0e8")
ICE_D = mat("imp_ice_d", "3f7c9a")
FROST = mat("imp_frost", "d8e8f0")
EYE = mat("imp_eye", "d6f4ff")
CLAW = mat("imp_claw", "0d1115")
VOID = mat("imp_void", "05080a", 1.0)

S = [
    ("hips", (0, 0.2, 0.52), (0, 0.08, 0.6), None),
    ("spine_01", (0, 0.08, 0.6), (0, -0.08, 0.76), "hips"),
    ("chest", (0, -0.08, 0.76), (0, -0.2, 0.9), "spine_01"),
    ("neck", (0, -0.2, 0.9), (0, -0.3, 0.96), "chest"),
    ("head", (0, -0.3, 0.96), (0, -0.5, 0.98), "neck"),
    ("jaw", (0, -0.36, 0.9), (0, -0.54, 0.88), "head"),
    ("tail_01", (0, 0.2, 0.52), (0, 0.46, 0.42), "hips"),
    ("tail_02", (0, 0.46, 0.42), (0, 0.7, 0.36), "tail_01"),
    ("tail_03", (0, 0.7, 0.36), (0, 0.92, 0.4), "tail_02"),
]
for s, x in (("l", 1), ("r", -1)):
    S += [
        ("upperarm_" + s, (x * 0.17, -0.14, 0.86), (x * 0.27, -0.24, 0.6), "chest"),
        ("forearm_" + s, (x * 0.27, -0.24, 0.6), (x * 0.28, -0.44, 0.34), "upperarm_" + s),
        ("hand_" + s, (x * 0.28, -0.44, 0.34), (x * 0.28, -0.52, 0.14), "forearm_" + s),
        ("thigh_" + s, (x * 0.12, 0.16, 0.5), (x * 0.19, 0.02, 0.34), "hips"),
        ("shin_" + s, (x * 0.19, 0.02, 0.34), (x * 0.15, 0.22, 0.14), "thigh_" + s),
        ("foot_" + s, (x * 0.15, 0.22, 0.14), (x * 0.15, 0.08, 0.02), "shin_" + s),
    ]
rig = armature(S)

# Body: a hump of dark hide over a pale belly, narrowing hard to the rump.
body = tube("body", [((0, 0.25, 0.5), 0.07, 0.07), ((0, 0.14, 0.55), 0.14, 0.15), ((0, 0.0, 0.68), 0.16, 0.18),
                     ((0, -0.14, 0.84), 0.17, 0.18), ((0, -0.23, 0.93), 0.1, 0.11)], SKIN, n=6)
two_tone(body, BELLY, DARK, down=-0.35, up=0.7)
bind(body, ["hips", "spine_01", "chest"])
bind(tube("neck", [((0, -0.2, 0.9), 0.08, 0.09), ((0, -0.3, 0.96), 0.07, 0.07)], SKIN, n=6), ["chest", "neck", "head"])

# Head: a dark wedge of skull, a hanging jaw, ice horns, pale eyes.
bind(tube("skull", [((0, -0.28, 0.96), 0.09, 0.1), ((0, -0.36, 0.985), 0.11, 0.11), ((0, -0.46, 0.97), 0.09, 0.085),
                    ((0, -0.57, 0.925), 0.045, 0.04)], DARK, n=6), ["head"])
bind(tube("jaw", [((0, -0.34, 0.91), 0.05, 0.025), ((0, -0.46, 0.9), 0.045, 0.02), ((0, -0.56, 0.893), 0.014, 0.012)], BELLY, n=4), ["jaw"])
for k in range(3):
    bind(cone("tooth_a%d" % k, ((k - 1) * 0.022, -0.5 - abs(k - 1) * -0.02, 0.9), ((k - 1) * 0.022, -0.5, 0.96), 0.012, FROST, n=3), ["jaw"])
for x in (1, -1):
    bind(blob("eye", (x * 0.048, -0.505, 0.99), (0.02, 0.022, 0.016), EYE, rot=(0, 0, x * 0.4)), ["head"])
    bind(blob("brow", (x * 0.05, -0.47, 1.025), (0.05, 0.1, 0.02), VOID, sub=0, rot=(0.2, x * -0.2, x * -0.3)), ["head"])
    bind(crystal("horn_%d" % x, (x * 0.06, -0.34, 1.04), (x * 0.15, -0.26, 1.26), 0.034, ICE, n=5), ["head"])
    bind(crystal("horn2_%d" % x, (x * 0.09, -0.4, 1.0), (x * 0.23, -0.42, 1.1), 0.022, ICE_D, n=4), ["head"])
# Ruff of rime round the neck.
for k, a in enumerate((-60, -20, 20, 60, 140, 220)):
    ar = math.radians(a)
    bind(cone("ruff%d" % k, (math.sin(ar) * 0.07, -0.25, 0.93 + math.cos(ar) * 0.06), (math.sin(ar) * 0.17, -0.2, 0.98 + math.cos(ar) * 0.12), 0.026, FROST, n=3), ["neck"])

# Spine: crystals raked back along the hump; a frost plate on each shoulder blade.
for i, (b, t, r, bn) in enumerate([((0, 0.14, 0.66), (0, 0.22, 0.8), 0.04, "hips"), ((0, 0.02, 0.82), (0, 0.1, 1.0), 0.05, "spine_01"),
                                   ((0, -0.1, 0.95), (0, -0.02, 1.14), 0.045, "chest")]):
    bind(crystal("spike%d" % i, b, t, r, ICE, n=5), [bn])
for x in (1, -1):
    bind(plate("blade_%d" % x, (x * 0.12, -0.02, 0.88), (0.1, 0.16, 0.04), FROST, rot=(0.2, x * 0.4, 0)), ["chest", "spine_01"])

for s, x in (("l", 1), ("r", -1)):
    P = lambda v: (x * v[0], v[1], v[2])
    bind(tube("arm_" + s, [(P((0.17, -0.14, 0.86)), 0.1, 0.1), (P((0.27, -0.24, 0.6)), 0.075, 0.075), (P((0.28, -0.44, 0.34)), 0.06, 0.06),
                          (P((0.28, -0.5, 0.2)), 0.05, 0.05)], SKIN, n=5), ["chest", "upperarm_" + s, "forearm_" + s, "hand_" + s])
    bind(blob("palm_" + s, P((0.28, -0.52, 0.16)), (0.06, 0.07, 0.045), DARK, sub=1), ["hand_" + s])
    for k in (-1, 0, 1):
        bind(cone("fing_%s%d" % (s, k), P((0.28 + k * 0.03, -0.55, 0.14)), P((0.28 + k * 0.045, -0.74, 0.07)), 0.016, CLAW, n=3), ["hand_" + s])
    bind(cone("elbow_" + s, P((0.28, -0.26, 0.6)), P((0.42, -0.1, 0.68)), 0.03, ICE_D, n=4), ["forearm_" + s])
    # Legs: digitigrade, knee forward, ankle back.
    bind(tube("leg_" + s, [(P((0.12, 0.16, 0.5)), 0.11, 0.11), (P((0.19, 0.02, 0.34)), 0.08, 0.08), (P((0.15, 0.22, 0.14)), 0.055, 0.055),
                          (P((0.15, 0.2, 0.07)), 0.045, 0.045)], SKIN, n=5), ["hips", "thigh_" + s, "shin_" + s])
    bind(tube("foot_" + s, [(P((0.15, 0.2, 0.08)), 0.04, 0.035), (P((0.15, 0.1, 0.04)), 0.045, 0.03), (P((0.15, 0.02, 0.02)), 0.03, 0.02)], DARK, n=4), ["foot_" + s])
    for k in (-1, 0, 1):
        bind(cone("toe_%s%d" % (s, k), P((0.15 + k * 0.025, 0.02, 0.03)), P((0.15 + k * 0.04, -0.09, 0.01)), 0.014, CLAW, n=3), ["foot_" + s])

# Tail, an ice crystal at its tip.
bind(tube("tail", [((0, 0.22, 0.52), 0.06, 0.06), ((0, 0.46, 0.42), 0.045, 0.045), ((0, 0.7, 0.36), 0.03, 0.03), ((0, 0.9, 0.4), 0.018, 0.018)],
          SKIN, n=5), ["hips", "tail_01", "tail_02", "tail_03"])
bind(crystal("tailice", (0, 0.88, 0.4), (0, 1.1, 0.5), 0.045, ICE, n=5), ["tail_03"])

imp = skin(rig, "Imp")
bake(imp, 512, OUT + "imp_tex.png")


def limbs(P, amp, ph, arm_amp, bend):
    """Diagonal skitter: thigh_l with upperarm_r. +X swings a hanging limb back."""
    ks = {}
    for s, sg in (("l", 1), ("r", -1)):
        o = 0 if s == "l" else 1
        a = [(amp, 0, 0), (-amp, 0, 0)] if o == 0 else [(-amp, 0, 0), (amp, 0, 0)]
        ks["thigh_" + s] = cyc(P, *a)
        ks["shin_" + s] = cyc(P, *([(-bend, 0, 0), (bend, 0, 0)] if o == 0 else [(bend, 0, 0), (-bend, 0, 0)]))
        b = [(-arm_amp, 0, 0), (arm_amp * 0.6, 0, 0)] if o == 1 else [(arm_amp * 0.6, 0, 0), (-arm_amp, 0, 0)]
        ks["upperarm_" + s] = cyc(P, *b)
        ks["forearm_" + s] = cyc(P, *([(-20, 0, 0), (-5, 0, 0)] if o == 1 else [(-5, 0, 0), (-20, 0, 0)]))
    return ks


def tail_sway(ks, P, a):
    for i, bn in enumerate(["tail_01", "tail_02", "tail_03"]):
        ks[bn] = cyc(P, (0, 0, a * (1 + i * 0.4)), (0, 0, -a * (1 + i * 0.4)))
    return ks


idle = tail_sway({}, 1.6, 8)
idle["hips"] = cycl(1.6, ((0, 0, 0), (0, 0, 0)), ((0, 0, 0), (0, 0, 0.02)))
idle["chest"] = cyc(1.6, (-3, 0, 0), (3, 0, 0))
idle["head"] = cyc(1.6, (0, 0, -9), (4, 0, 9))
idle["jaw"] = cyc(1.6, (2, 0, 0), (9, 0, 0))
idle["upperarm_l"] = cyc(1.6, (0, 0, 0), (-6, 0, 0))
idle["upperarm_r"] = cyc(1.6, (-6, 0, 0), (0, 0, 0))
clip(rig, "Idle", 1.6, idle)

walk = tail_sway(limbs(0.8, 24, 0, 26, 24), 0.8, 12)
walk["hips"] = [(0, (5, 0, 4), (0, 0, 0)), (0.2, (5, 0, 0), (0, 0, 0.03)), (0.4, (5, 0, -4), (0, 0, 0)), (0.6, (5, 0, 0), (0, 0, 0.03)), (0.8, (5, 0, 4), (0, 0, 0))]
walk["head"] = cyc(0.8, (-6, 0, 0), (-6, 0, 0))
clip(rig, "Walk", 0.8, walk)

run = tail_sway(limbs(0.5, 38, 0, 44, 36), 0.5, 16)
run["hips"] = [(0, (14, 0, 5), (0, 0, 0)), (0.125, (14, 0, 0), (0, 0, 0.05)), (0.25, (14, 0, -5), (0, 0, 0)), (0.375, (14, 0, 0), (0, 0, 0.05)), (0.5, (14, 0, 5), (0, 0, 0))]
run["spine_01"] = cyc(0.5, (-8, 0, 0), (6, 0, 0))
run["head"] = cyc(0.5, (-14, 0, 0), (-14, 0, 0))
clip(rig, "Run", 0.5, run)

# Attack: rears back, then rakes both claws down and bites.
atk = tail_sway({}, 0.7, 10)
atk["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.25, (-12, 0, 0), (0, 0.06, 0.05)), (0.4, (16, 0, 0), (0, -0.2, -0.02)), (0.7, (0, 0, 0), (0, 0, 0))]
atk["spine_01"] = [(0, (0, 0, 0), None), (0.25, (-22, 0, 0), None), (0.4, (20, 0, 0), None), (0.7, (0, 0, 0), None)]
atk["head"] = [(0, (0, 0, 0), None), (0.25, (-14, 0, 0), None), (0.4, (14, 0, 0), None), (0.7, (0, 0, 0), None)]
atk["jaw"] = [(0, (0, 0, 0), None), (0.25, (40, 0, 0), None), (0.42, (2, 0, 0), None), (0.7, (0, 0, 0), None)]
for s, sg in (("l", 1), ("r", -1)):
    d = 0 if s == "r" else 0.06
    atk["upperarm_" + s] = [(0, (0, 0, 0), None), (0.25 + d, (-60, 0, 0), None), (0.42 + d, (10, 0, 0), None), (0.7, (0, 0, 0), None)]
    atk["forearm_" + s] = [(0, (0, 0, 0), None), (0.25 + d, (-30, 0, 0), None), (0.42 + d, (-5, 0, 0), None), (0.7, (0, 0, 0), None)]
clip(rig, "Attack", 0.7, atk, loop=False)

hit = tail_sway({}, 0.4, 14)
hit["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.1, (-10, 0, 8), (0, 0.12, 0.02)), (0.4, (0, 0, 0), (0, 0, 0))]
hit["spine_01"] = [(0, (0, 0, 0), None), (0.1, (-22, 0, 0), None), (0.4, (0, 0, 0), None)]
hit["head"] = [(0, (0, 0, 0), None), (0.1, (-18, 0, 12), None), (0.4, (0, 0, 0), None)]
hit["jaw"] = [(0, (0, 0, 0), None), (0.1, (30, 0, 0), None), (0.4, (0, 0, 0), None)]
for s, sg in (("l", 1), ("r", -1)):
    hit["upperarm_" + s] = [(0, (0, 0, 0), None), (0.1, (-30, -sg * 40, 0), None), (0.4, (0, 0, 0), None)]
clip(rig, "Hit", 0.4, hit, loop=False)

# Die: throws its head back, curls and tips over on its side.
die = {}
die["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.2, (-12, 10, 0), (0, 0.1, 0)), (0.7, (0, 80, 0), (0, 0.08, -0.34)), (1.1, (0, 84, 0), (0, 0.08, -0.38))]
die["spine_01"] = [(0, (0, 0, 0), None), (0.2, (-26, 0, 0), None), (0.7, (10, 0, 0), None), (1.1, (14, 0, 0), None)]
die["head"] = [(0, (0, 0, 0), None), (0.2, (-24, 0, 0), None), (0.7, (8, 0, 14), None), (1.1, (10, 0, 14), None)]
die["jaw"] = [(0, (0, 0, 0), None), (0.2, (44, 0, 0), None), (1.1, (30, 0, 0), None)]
for s, sg in (("l", 1), ("r", -1)):
    die["thigh_" + s] = [(0, (0, 0, 0), None), (0.7, (-40, 0, 0), None), (1.1, (-46, 0, 0), None)]
    die["shin_" + s] = [(0, (0, 0, 0), None), (0.7, (40, 0, 0), None), (1.1, (46, 0, 0), None)]
    die["upperarm_" + s] = [(0, (0, 0, 0), None), (0.2, (-60, -sg * 30, 0), None), (0.7, (-10, -sg * 10, 0), None), (1.1, (0, 0, 0), None)]
    die["forearm_" + s] = [(0, (0, 0, 0), None), (0.7, (-30, 0, 0), None), (1.1, (-34, 0, 0), None)]
die["tail_01"] = [(0, (0, 0, 0), None), (0.7, (0, 0, 24), None), (1.1, (0, 0, 28), None)]
clip(rig, "Death", 1.1, die, loop=False)

# Spawn: starts flat and coiled, then springs up onto its claws.
sp = {}
sp["hips"] = [(0, (0, 0, 0), (0, 0, -0.34)), (0.3, (-8, 0, 0), (0, 0.05, -0.34)), (0.55, (10, 0, 0), (0, -0.1, 0.12)), (0.8, (0, 0, 0), (0, 0, 0))]
sp["spine_01"] = [(0, (30, 0, 0), None), (0.3, (36, 0, 0), None), (0.55, (-16, 0, 0), None), (0.8, (0, 0, 0), None)]
sp["head"] = [(0, (20, 0, 0), None), (0.55, (-16, 0, 0), None), (0.8, (0, 0, 0), None)]
for s, sg in (("l", 1), ("r", -1)):
    sp["thigh_" + s] = [(0, (-50, 0, 0), None), (0.3, (-56, 0, 0), None), (0.55, (14, 0, 0), None), (0.8, (0, 0, 0), None)]
    sp["shin_" + s] = [(0, (60, 0, 0), None), (0.3, (66, 0, 0), None), (0.55, (-16, 0, 0), None), (0.8, (0, 0, 0), None)]
    sp["upperarm_" + s] = [(0, (-20, 0, 0), None), (0.55, (-70, 0, 0), None), (0.8, (0, 0, 0), None)]
clip(rig, "Spawn", 0.8, sp, loop=False)

export(rig, imp, OUT + "frost_imp_src.glb")
os.remove(OUT + "imp_tex.png")
