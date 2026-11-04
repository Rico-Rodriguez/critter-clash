# Frost Wolf (rh_wolf): a lean, long-legged wolf in dark blue-grey plate, a pale chest and
# belly, a ruff and spine of ice shards, rime on its haunches, pale eyes.
# Writes assets/foes/frost_wolf_src.glb. Run: python3 tools/blender/foes/wolf.py -- <repo root>
from kit import *

OUT = out_dir()
reset()

FUR = mat("wolf_fur", "2c3946")
FUR_D = mat("wolf_fur_d", "182029")
FUR_L = mat("wolf_fur_l", "566b7b")
BELLY = mat("wolf_belly", "9db3c0")
ICE = mat("wolf_ice", "9bdcf0")
ICE_D = mat("wolf_ice_d", "468aa8")
FROST = mat("wolf_frost", "dbe9f0")
EYE = mat("wolf_eye", "d9f6ff")
CLAW = mat("wolf_claw", "0f1418")
VOID = mat("wolf_void", "05080a", 1.0)

S = [
    ("hips", (0, 0.4, 0.62), (0, 0.22, 0.64), None),
    ("spine_01", (0, 0.22, 0.64), (0, -0.05, 0.68), "hips"),
    ("chest", (0, -0.05, 0.68), (0, -0.3, 0.7), "spine_01"),
    ("neck", (0, -0.3, 0.7), (0, -0.5, 0.86), "chest"),
    ("head", (0, -0.5, 0.86), (0, -0.74, 0.84), "neck"),
    ("jaw", (0, -0.58, 0.8), (0, -0.84, 0.76), "head"),
    ("tail_01", (0, 0.46, 0.64), (0, 0.7, 0.58), "hips"),
    ("tail_02", (0, 0.7, 0.58), (0, 0.9, 0.46), "tail_01"),
    ("tail_03", (0, 0.9, 0.46), (0, 1.04, 0.3), "tail_02"),
]
for s, x in (("l", 1), ("r", -1)):
    S += [
        ("ear_" + s, (x * 0.07, -0.58, 0.96), (x * 0.1, -0.56, 1.1), "head"),
        ("fup_" + s, (x * 0.12, -0.24, 0.62), (x * 0.13, -0.22, 0.36), "chest"),
        ("flo_" + s, (x * 0.13, -0.22, 0.36), (x * 0.13, -0.26, 0.14), "fup_" + s),
        ("fpaw_" + s, (x * 0.13, -0.26, 0.14), (x * 0.13, -0.38, 0.02), "flo_" + s),
        ("hup_" + s, (x * 0.13, 0.4, 0.62), (x * 0.14, 0.28, 0.4), "hips"),
        ("hlo_" + s, (x * 0.14, 0.28, 0.4), (x * 0.12, 0.48, 0.2), "hup_" + s),
        ("hpaw_" + s, (x * 0.12, 0.48, 0.2), (x * 0.12, 0.38, 0.02), "hlo_" + s),
    ]
rig = armature(S)

# Body: deep chest, tucked waist, strong haunch. Pale belly, dark back.
body = tube("body", [((0, 0.58, 0.6), 0.06, 0.07), ((0, 0.46, 0.64), 0.14, 0.17), ((0, 0.26, 0.64), 0.13, 0.15),
                     ((0, 0.04, 0.67), 0.15, 0.18), ((0, -0.2, 0.69), 0.18, 0.21), ((0, -0.38, 0.72), 0.14, 0.17)], FUR, n=6)
two_tone(body, BELLY, FUR_D, down=-0.35, up=0.72)
bind(body, ["hips", "spine_01", "chest"])
neck = tube("neck", [((0, -0.28, 0.72), 0.14, 0.16), ((0, -0.42, 0.8), 0.11, 0.12), ((0, -0.54, 0.88), 0.1, 0.1)], FUR, n=6)
two_tone(neck, BELLY, FUR_D, down=-0.4, up=0.8)
bind(neck, ["chest", "neck", "head"])
# Head: a long wedge of skull and a narrow muzzle; the jaw below.
bind(tube("skull", [((0, -0.5, 0.9), 0.1, 0.1), ((0, -0.58, 0.9), 0.115, 0.11), ((0, -0.68, 0.87), 0.075, 0.075),
                    ((0, -0.8, 0.82), 0.045, 0.045), ((0, -0.88, 0.8), 0.028, 0.028)], FUR, n=6), ["head"])
bind(tube("jaw", [((0, -0.56, 0.8), 0.07, 0.03), ((0, -0.7, 0.77), 0.05, 0.022), ((0, -0.84, 0.75), 0.022, 0.015)], FUR_L, n=4), ["jaw"])
bind(blob("nose", (0, -0.9, 0.805), (0.035, 0.03, 0.03), CLAW, sub=0), ["head"])
for k in range(3):
    bind(cone("fang_u%d" % k, ((k - 1) * 0.018, -0.78 - k * 0.0, 0.79), ((k - 1) * 0.018, -0.78, 0.735), 0.011, FROST, n=3), ["head"])
for x in (1, -1):
    bind(blob("eye", (x * 0.06, -0.66, 0.9), (0.014, 0.04, 0.016), EYE, sub=1, rot=(0, 0, x * -0.3)), ["head"])
    bind(blob("brow", (x * 0.06, -0.64, 0.935), (0.045, 0.1, 0.02), FUR_D, sub=0, rot=(0.15, x * -0.15, x * -0.25)), ["head"])
    bind(tube("ear_%d" % x, [((x * 0.07, -0.58, 0.96), 0.045, 0.02), ((x * 0.09, -0.57, 1.04), 0.04, 0.018), ((x * 0.1, -0.56, 1.14), 0.006, 0.006)], FUR_D, n=3),
         ["ear_" + ("l" if x > 0 else "r"), "head"])
# Ice ruff on the neck and a crest of shards down the back.
for k, (p, h, bn) in enumerate([((0, -0.5, 0.94), 0.16, "neck"), ((0, -0.4, 0.88), 0.2, "neck"), ((0, -0.28, 0.9), 0.22, "chest"),
                                ((0, -0.14, 0.88), 0.2, "chest"), ((0, 0.02, 0.85), 0.18, "spine_01"), ((0, 0.2, 0.82), 0.16, "spine_01"),
                                ((0, 0.4, 0.8), 0.13, "hips")]):
    bind(crystal("crest%d" % k, p, (p[0], p[1] + 0.08, p[2] + h), 0.035 + 0.004 * (k < 4), ICE if k % 2 == 0 else ICE_D, n=4), [bn])
for x in (1, -1):
    bind(plate("rime_%d" % x, (x * 0.15, 0.42, 0.72), (0.04, 0.2, 0.12), FROST, rot=(0.1, 0, x * 0.1)), ["hips"])
    bind(plate("shoulderp_%d" % x, (x * 0.17, -0.2, 0.78), (0.04, 0.18, 0.12), FUR_L, rot=(0.1, 0, x * 0.2)), ["chest"])

# Legs: a bent hind leg with a high hock, straighter forelegs, dark paws with claws.
for s, x in (("l", 1), ("r", -1)):
    P = lambda v: (x * v[0], v[1], v[2])
    bind(tube("fleg_" + s, [(P((0.12, -0.24, 0.64)), 0.105, 0.11), (P((0.13, -0.22, 0.36)), 0.07, 0.07), (P((0.13, -0.26, 0.15)), 0.05, 0.05),
                           (P((0.13, -0.28, 0.07)), 0.05, 0.05)], FUR, n=5), ["chest", "fup_" + s, "flo_" + s])
    bind(tube("fpaw_" + s, [(P((0.13, -0.27, 0.08)), 0.042, 0.03), (P((0.13, -0.36, 0.03)), 0.045, 0.025), (P((0.13, -0.42, 0.015)), 0.03, 0.015)], FUR_D, n=4), ["fpaw_" + s])
    bind(tube("hleg_" + s, [(P((0.13, 0.4, 0.64)), 0.125, 0.14), (P((0.14, 0.28, 0.4)), 0.085, 0.09), (P((0.12, 0.48, 0.2)), 0.05, 0.05),
                           (P((0.12, 0.46, 0.08)), 0.045, 0.045)], FUR, n=5), ["hips", "hup_" + s, "hlo_" + s])
    bind(tube("hpaw_" + s, [(P((0.12, 0.46, 0.08)), 0.04, 0.03), (P((0.12, 0.38, 0.03)), 0.045, 0.025), (P((0.12, 0.32, 0.015)), 0.03, 0.015)], FUR_D, n=4), ["hpaw_" + s])
    for k in (-1, 0, 1):
        bind(cone("fcl_%s%d" % (s, k), P((0.13 + k * 0.022, -0.42, 0.02)), P((0.13 + k * 0.03, -0.48, 0.005)), 0.012, CLAW, n=3), ["fpaw_" + s])
        bind(cone("hcl_%s%d" % (s, k), P((0.12 + k * 0.022, 0.32, 0.02)), P((0.12 + k * 0.03, 0.26, 0.005)), 0.012, CLAW, n=3), ["hpaw_" + s])

# Tail: a heavy brush sweeping down, an ice shard at the tip.
tail = tube("tail", [((0, 0.5, 0.64), 0.06, 0.07), ((0, 0.7, 0.58), 0.09, 0.1), ((0, 0.9, 0.46), 0.075, 0.085), ((0, 1.04, 0.3), 0.04, 0.045),
                     ((0, 1.08, 0.24), 0.008, 0.01)], FUR, n=6)
two_tone(tail, FUR_L, FUR_D, down=-0.4, up=0.8)
bind(tail, ["hips", "tail_01", "tail_02", "tail_03"])

wolf = skin(rig, "Wolf")
bake(wolf, 512, OUT + "wolf_tex.png")



def gait(P, amp, lift, diag=True):
    """Walk/trot: forelegs and hindlegs swing, diagonal pairs together. +X swings a hanging leg back."""
    ks = {}
    for s, sg in (("l", 1), ("r", -1)):
        ph = 0 if (s == "l") else 1
        a = (amp, -amp) if ph == 0 else (-amp, amp)
        ks["fup_" + s] = cyc(P, *[(v, 0, 0) for v in a])
        ks["flo_" + s] = cyc(P, *[(-lift if v < 0 else 8, 0, 0) for v in a])
        h = (-amp, amp) if ph == 0 else (amp, -amp)
        ks["hup_" + s] = cyc(P, *[(v * 0.9, 0, 0) for v in h])
        ks["hlo_" + s] = cyc(P, *[(lift if v < 0 else -8, 0, 0) for v in h])
        ks["fpaw_" + s] = cyc(P, *[(-lift * 0.5 if v < 0 else 0, 0, 0) for v in a])
        ks["hpaw_" + s] = cyc(P, *[(-lift * 0.5 if v < 0 else 0, 0, 0) for v in h])
    return ks


def tailw(ks, P, a, base=0):
    for i, bn in enumerate(["tail_01", "tail_02", "tail_03"]):
        ks[bn] = cyc(P, (base, 0, a * (1 + i * 0.5)), (base, 0, -a * (1 + i * 0.5)))
    return ks


idle = tailw({}, 2.0, 5)
idle["chest"] = cyc(2.0, (-1.5, 0, 0), (2, 0, 0))
idle["neck"] = cyc(2.0, (4, 0, 0), (-3, 0, 0))
idle["head"] = cyc(2.0, (0, 0, -10), (3, 0, 10))
idle["jaw"] = cyc(2.0, (2, 0, 0), (7, 0, 0))
idle["ear_l"] = cyc(2.0, (0, 0, 0), (0, 8, 4))
idle["ear_r"] = cyc(2.0, (0, -8, 0), (0, 0, 0))
idle["hips"] = cycl(2.0, ((0, 0, 0), (0, 0, 0)), ((0, 0, 0), (0, 0, 0.012)))
clip(rig, "Idle", 2.0, idle)

walk = tailw(gait(1.0, 26, 22), 1.0, 8)
walk["hips"] = [(0, (0, 0, 3), (0, 0, 0)), (0.25, (0, 0, 0), (0, 0, 0.025)), (0.5, (0, 0, -3), (0, 0, 0)), (0.75, (0, 0, 0), (0, 0, 0.025)), (1.0, (0, 0, 3), (0, 0, 0))]
walk["chest"] = cyc(1.0, (0, 0, -4), (0, 0, 4))
walk["head"] = cyc(1.0, (5, 0, 3), (5, 0, -3))
walk["neck"] = cyc(1.0, (10, 0, 0), (10, 0, 0))
clip(rig, "Walk", 1.0, walk)

run = tailw(gait(0.5, 44, 34), 0.5, 5, base=-14)
run["hips"] = [(0, (-6, 0, 0), (0, 0, 0)), (0.125, (-10, 0, 0), (0, 0, 0.05)), (0.25, (0, 0, 0), (0, 0, 0.08)), (0.375, (8, 0, 0), (0, 0, 0.02)), (0.5, (-6, 0, 0), (0, 0, 0))]
run["spine_01"] = cyc(0.5, (8, 0, 0), (-8, 0, 0))
run["neck"] = cyc(0.5, (22, 0, 0), (22, 0, 0))
run["head"] = cyc(0.5, (6, 0, 0), (6, 0, 0))
run["jaw"] = cyc(0.5, (10, 0, 0), (14, 0, 0))
clip(rig, "Run", 0.5, run)

# Attack: sinks back on the haunches, then lunges forward with the jaws wide and snaps shut.
atk = tailw({}, 0.7, 5)
atk["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.25, (-14, 0, 0), (0, 0.06, -0.08)), (0.4, (10, 0, 0), (0, -0.32, 0.05)), (0.7, (0, 0, 0), (0, 0, 0))]
atk["spine_01"] = [(0, (0, 0, 0), None), (0.25, (12, 0, 0), None), (0.4, (-10, 0, 0), None), (0.7, (0, 0, 0), None)]
atk["neck"] = [(0, (0, 0, 0), None), (0.25, (-20, 0, 0), None), (0.4, (28, 0, 0), None), (0.7, (0, 0, 0), None)]
atk["head"] = [(0, (0, 0, 0), None), (0.25, (-16, 0, 0), None), (0.42, (10, 0, 0), None), (0.7, (0, 0, 0), None)]
atk["jaw"] = [(0, (0, 0, 0), None), (0.25, (6, 0, 0), None), (0.36, (46, 0, 0), None), (0.46, (0, 0, 0), None), (0.7, (0, 0, 0), None)]
for s in "lr":
    atk["fup_" + s] = [(0, (0, 0, 0), None), (0.25, (20, 0, 0), None), (0.4, (-44, 0, 0), None), (0.7, (0, 0, 0), None)]
    atk["flo_" + s] = [(0, (0, 0, 0), None), (0.4, (-20, 0, 0), None), (0.7, (0, 0, 0), None)]
    atk["hup_" + s] = [(0, (0, 0, 0), None), (0.25, (-26, 0, 0), None), (0.4, (30, 0, 0), None), (0.7, (0, 0, 0), None)]
    atk["hlo_" + s] = [(0, (0, 0, 0), None), (0.25, (26, 0, 0), None), (0.4, (-24, 0, 0), None), (0.7, (0, 0, 0), None)]
clip(rig, "Attack", 0.7, atk, loop=False)

hit = tailw({}, 0.4, 10)
hit["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.1, (0, 0, 8), (0, 0.14, -0.03)), (0.4, (0, 0, 0), (0, 0, 0))]
hit["spine_01"] = [(0, (0, 0, 0), None), (0.1, (-12, 0, -10), None), (0.4, (0, 0, 0), None)]
hit["neck"] = [(0, (0, 0, 0), None), (0.1, (-24, 0, 12), None), (0.4, (0, 0, 0), None)]
hit["jaw"] = [(0, (0, 0, 0), None), (0.1, (30, 0, 0), None), (0.4, (0, 0, 0), None)]
for s in "lr":
    hit["fup_" + s] = [(0, (0, 0, 0), None), (0.1, (14, 0, 0), None), (0.4, (0, 0, 0), None)]
    hit["ear_" + s] = [(0, (0, 0, 0), None), (0.1, (30, 0, 0), None), (0.4, (0, 0, 0), None)]
clip(rig, "Hit", 0.4, hit, loop=False)

# Die: legs fold and the wolf falls over on its side, head back.
die = {}
die["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.2, (-8, 12, 0), (0, 0.12, -0.04)), (0.75, (0, 82, 0), (0, 0.06, -0.4)), (1.1, (0, 86, 0), (0, 0.06, -0.44))]
die["spine_01"] = [(0, (0, 0, 0), None), (0.2, (-12, 0, 0), None), (0.75, (6, 0, 14), None), (1.1, (6, 0, 14), None)]
die["neck"] = [(0, (0, 0, 0), None), (0.2, (-26, 0, 0), None), (0.75, (-10, 0, 20), None), (1.1, (-8, 0, 22), None)]
die["jaw"] = [(0, (0, 0, 0), None), (0.2, (40, 0, 0), None), (1.1, (24, 0, 0), None)]
for s in "lr":
    die["fup_" + s] = [(0, (0, 0, 0), None), (0.75, (-52, 0, 0), None), (1.1, (-58, 0, 0), None)]
    die["flo_" + s] = [(0, (0, 0, 0), None), (0.75, (-40, 0, 0), None), (1.1, (-48, 0, 0), None)]
    die["hup_" + s] = [(0, (0, 0, 0), None), (0.75, (50, 0, 0), None), (1.1, (54, 0, 0), None)]
    die["hlo_" + s] = [(0, (0, 0, 0), None), (0.75, (-30, 0, 0), None), (1.1, (-36, 0, 0), None)]
    die["ear_" + s] = [(0, (0, 0, 0), None), (0.75, (26, 0, 0), None), (1.1, (30, 0, 0), None)]
die["tail_01"] = [(0, (0, 0, 0), None), (0.75, (0, 0, 20), None), (1.1, (0, 0, 24), None)]
clip(rig, "Death", 1.1, die, loop=False)

# Taunt: head thrown up in a howl.
th = tailw({}, 2.0, 4)
th["neck"] = [(0, (0, 0, 0), None), (0.5, (-62, 0, 0), None), (1.5, (-66, 0, 0), None), (2.0, (0, 0, 0), None)]
th["head"] = [(0, (0, 0, 0), None), (0.5, (-34, 0, 0), None), (1.5, (-34, 0, 0), None), (2.0, (0, 0, 0), None)]
th["jaw"] = [(0, (0, 0, 0), None), (0.5, (36, 0, 0), None), (1.5, (36, 0, 0), None), (2.0, (0, 0, 0), None)]
th["chest"] = [(0, (0, 0, 0), None), (0.5, (-12, 0, 0), None), (1.5, (-12, 0, 0), None), (2.0, (0, 0, 0), None)]
clip(rig, "Taunt", 2.0, th, loop=False)

export(rig, wolf, OUT + "frost_wolf_src.glb")
os.remove(OUT + "wolf_tex.png")
