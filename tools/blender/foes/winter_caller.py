# Winter Caller (Rimehollow): a tall gaunt summoner in a long dark-iron and frost-blue
# robe, a ram-horned skull for a head, an ice-crystal staff in its right hand.
# Kept very light (about 1.3k tris). Writes assets/foes/winter_caller_src.glb.
# Run: python3 tools/blender/foes/winter_caller.py -- <repo root>
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "../pets"))
from common import *
import common

ROOT = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(ROOT, "assets/foes/")
reset()
common.SIDES, common.BLOB_SUB = 1.0, 0

ROBE = mat("wc_robe", "27313f")
DEEP = mat("wc_deep", "141a22")
TRIM = mat("wc_trim", "4e6a82")
BONE = mat("wc_bone", "c9cfc6")
VOID = mat("wc_void", "05080c", 1.0)
EYE = mat("wc_eye", "9be4ff")
HORN = mat("wc_horn", "8a8f8a")
ICE = mat("wc_ice", "6fbfe6")
IRON = mat("wc_iron", "2a2d34")
WOOD = mat("wc_wood", "3a2f2a")

S = [
    ("hips", (0, 0, 0.95), (0, 0, 1.12), None),
    ("spine_01", (0, 0, 1.12), (0, 0, 1.45), "hips"),
    ("chest", (0, 0, 1.45), (0, -0.02, 1.72), "spine_01"),
    ("neck_01", (0, -0.02, 1.72), (0, -0.05, 1.82), "chest"),
    ("head", (0, -0.05, 1.82), (0, -0.07, 2.1), "neck_01"),
    ("cloak_01", (0, 0.14, 1.7), (0, 0.22, 1.0), "chest"),
    ("cloak_02", (0, 0.22, 1.0), (0, 0.3, 0.35), "cloak_01"),
]
for s, x in (("l", 1), ("r", -1)):
    S += [
        ("thigh_" + s, (x * 0.1, 0, 0.95), (x * 0.11, 0, 0.5), "hips"),
        ("shin_" + s, (x * 0.11, 0, 0.5), (x * 0.11, 0.02, 0.1), "thigh_" + s),
        ("foot_" + s, (x * 0.11, 0.02, 0.1), (x * 0.11, -0.14, 0.04), "shin_" + s),
        ("upperarm_" + s, (x * 0.28, 0, 1.62), (x * 0.34, -0.03, 1.28), "chest"),
        ("forearm_" + s, (x * 0.34, -0.03, 1.28), (x * 0.38, -0.2, 1.06), "upperarm_" + s),
        ("hand_" + s, (x * 0.38, -0.2, 1.06), (x * 0.4, -0.28, 0.98), "forearm_" + s),
    ]
S.append(("staff", (-0.4, -0.24, 1.02), (-0.4, -0.24, 2.4), "hand_r"))
rig = armature(S)

# Long robe to the ground, split at the front so the legs read; heavy shoulders.
robe = tube("robe", [((0, 0, 0.04), 0.3, 0.26), ((0, 0, 0.5), 0.24, 0.2), ((0, 0, 0.95), 0.2, 0.16), ((0, 0, 1.3), 0.19, 0.14),
                     ((0, 0, 1.58), 0.27, 0.17), ((0, -0.01, 1.74), 0.14, 0.11)], ROBE, n=10)
two_tone(robe, DEEP, None, down=-0.5)
bind(robe, ["thigh_l", "thigh_r", "hips", "spine_01", "chest"])
bind(tube("hem", [((0, 0, 0.04), 0.31, 0.27), ((0, 0, 0.16), 0.29, 0.25)], TRIM, n=10, cap0=False, cap1=False), ["thigh_l", "thigh_r", "hips"])
bind(tube("sash", [((0, 0, 0.99), 0.215, 0.17), ((0, 0, 1.07), 0.21, 0.165)], IRON, n=10, cap0=False, cap1=False), ["hips", "spine_01"])
# Cloak of tattered panels down the back.
bind(sheet("cloak", [(0, 0.14, 1.72), (0.3, 0.2, 1.6), (0.36, 0.3, 0.7), (0.2, 0.34, 0.3), (0, 0.38, 0.4), (-0.2, 0.34, 0.3), (-0.36, 0.3, 0.7), (-0.3, 0.2, 1.6)],
           DEEP, 0.02), ["chest", "cloak_01", "cloak_02"])
for x in (1, -1):
    bind(blob("pauldron%d" % x, (x * 0.3, 0, 1.66), (0.2, 0.2, 0.1), IRON, rot=(0, x * 0.35, 0)), ["chest"])
    bind(cone("spike%d" % x, (x * 0.34, 0, 1.7), (x * 0.5, 0, 1.92), 0.05, ICE, n=4), ["chest"])

# Head: a bone-white skull under a hood point, big ram horns curling out and down.
bind(tube("skull", [((0, -0.07, 1.83), 0.05, 0.06), ((0, -0.07, 1.9), 0.1, 0.12), ((0, -0.07, 2.0), 0.115, 0.135), ((0, -0.07, 2.08), 0.09, 0.11),
                    ((0, -0.07, 2.14), 0.04, 0.05)], BONE, n=8), ["head"])
bind(blob("snout", (0, -0.2, 1.9), (0.1, 0.12, 0.1), BONE), ["head"])
bind(tube("hood", [((0, 0.05, 1.86), 0.1, 0.1), ((0, 0.06, 1.96), 0.17, 0.17), ((0, 0.06, 2.06), 0.17, 0.17), ((0, 0.04, 2.16), 0.08, 0.09)], ROBE, n=8), ["head"])
for x in (1, -1):
    bind(blob("socket%d" % x, (x * 0.06, -0.17, 1.99), (0.07, 0.04, 0.07), VOID), ["head"])
    bind(blob("eye%d" % x, (x * 0.06, -0.19, 1.99), (0.025, 0.012, 0.03), EYE), ["head"])
    bind(tube("horn%d" % x, [((x * 0.1, -0.03, 2.12), 0.05, 0.05), ((x * 0.26, 0.0, 2.18), 0.045, 0.045), ((x * 0.38, -0.02, 2.06), 0.035, 0.035),
                             ((x * 0.4, -0.08, 1.9), 0.02, 0.02), ((x * 0.34, -0.12, 1.8), 0.006, 0.006)], HORN, n=4), ["head"])
    bind(cone("antler%d" % x, (x * 0.12, 0.0, 2.2), (x * 0.18, 0.02, 2.52), 0.03, HORN, n=3, bend=(x * 0.04, 0, 0)), ["head"])
bind(blob("nose", (0, -0.26, 1.9), (0.03, 0.02, 0.04), VOID), ["head"])

# Arms in wide sleeves, bony hands; the right grips a staff topped with ice.
for s, x in (("l", 1), ("r", -1)):
    P = lambda v: (x * v[0], v[1], v[2])
    bind(tube("sleeve_" + s, [(P((0.28, 0, 1.62)), 0.09, 0.09), (P((0.34, -0.03, 1.28)), 0.075, 0.075), (P((0.38, -0.2, 1.06)), 0.11, 0.11)],
              ROBE, n=5, cap1=False), ["chest", "upperarm_" + s, "forearm_" + s])
    bind(blob("hand_" + s, P((0.4, -0.27, 0.98)), (0.07, 0.09, 0.07), BONE), ["hand_" + s])
    for k in range(3):
        bind(cone("claw_%s%d" % (s, k), P((0.4 + (k - 1) * 0.025, -0.3, 0.97)), P((0.41 + (k - 1) * 0.035, -0.4, 0.9)), 0.014, BONE, n=3), ["hand_" + s])
bind(tube("staff", [((-0.4, -0.24, 0.0), 0.03, 0.03), ((-0.4, -0.24, 1.0), 0.03, 0.03), ((-0.4, -0.24, 2.2), 0.04, 0.04)], WOOD, n=5), ["staff"])
bind(cone("crystal", (-0.4, -0.24, 2.18), (-0.4, -0.24, 2.62), 0.1, ICE, n=5), ["staff"])
bind(cone("crystal_b", (-0.4, -0.24, 2.12), (-0.28, -0.2, 2.36), 0.05, ICE, n=4), ["staff"])
bind(cone("crystal_c", (-0.4, -0.24, 2.12), (-0.52, -0.3, 2.36), 0.05, ICE, n=4), ["staff"])
# Boots under the hem.
for s, x in (("l", 1), ("r", -1)):
    bind(blob("boot_" + s, (x * 0.11, -0.09, 0.05), (0.12, 0.3, 0.1), IRON), ["foot_" + s])

c = skin(rig, "Caller")
bake(c, 512, OUT + "winter_caller_tex.png")
tri = sum(len(p.vertices) - 2 for p in c.data.polygons)


def stride(period, a, knee, arm):
    ks = {}
    for s, sg in (("l", 1), ("r", -1)):
        ks["thigh_" + s] = [(0, (-sg * a, 0, 0), None), (period / 2, (sg * a, 0, 0), None), (period, (-sg * a, 0, 0), None)]
        if sg > 0:
            ks["shin_" + s] = [(0, (knee * 0.2, 0, 0), None), (period * 0.25, (knee, 0, 0), None), (period * 0.5, (knee * 0.1, 0, 0), None), (period, (knee * 0.2, 0, 0), None)]
        else:
            ks["shin_" + s] = [(0, (knee * 0.1, 0, 0), None), (period * 0.5, (knee * 0.2, 0, 0), None), (period * 0.75, (knee, 0, 0), None), (period, (knee * 0.1, 0, 0), None)]
    ks["upperarm_l"] = [(0, (arm, 0, 0), None), (period / 2, (-arm, 0, 0), None), (period, (arm, 0, 0), None)]
    ks["upperarm_r"] = [(0, (-arm * 0.3, 0, 0), None), (period / 2, (arm * 0.3, 0, 0), None), (period, (-arm * 0.3, 0, 0), None)]
    ks["cloak_01"] = [(0, (arm * 0.5, 0, 0), None), (period / 2, (-arm * 0.2, 0, 0), None), (period, (arm * 0.5, 0, 0), None)]
    return ks


def bob(period, tilt, lift, lean=0):
    q = period / 4
    return [(0, (lean, 0, tilt), (0, 0, 0)), (q, (lean, 0, 0), (0, 0, lift)), (2 * q, (lean, 0, -tilt), (0, 0, 0)),
            (3 * q, (lean, 0, 0), (0, 0, lift)), (period, (lean, 0, tilt), (0, 0, 0))]


idle = {"chest": [(0, (0, 0, 0), None), (1.5, (3, 0, 0), None), (3, (0, 0, 0), None)],
        "head": [(0, (0, 0, -6), None), (1.5, (3, 0, 6), None), (3, (0, 0, -6), None)],
        "upperarm_l": [(0, (4, 0, 0), None), (1.5, (-4, 0, 0), None), (3, (4, 0, 0), None)],
        "cloak_01": [(0, (2, 0, 0), None), (1.5, (-3, 0, 0), None), (3, (2, 0, 0), None)],
        "cloak_02": [(0, (3, 0, 0), None), (1.5, (-5, 0, 0), None), (3, (3, 0, 0), None)]}
clip(rig, "Idle", 3.0, idle)
walk = stride(1.0, 22, 30, 18)
walk["hips"] = bob(1.0, 3, 0.02, 4)
clip(rig, "Walk", 1.0, walk)
run = stride(0.65, 32, 50, 28)
run["hips"] = bob(0.65, 4, 0.04, 10)
clip(rig, "Run", 0.65, run)

# Attack: staff swung up, then brought down across.
atk = {}
atk["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.3, (-8, 0, 14), (0, 0.06, 0)), (0.5, (14, 0, -16), (0, -0.14, 0)), (0.8, (0, 0, 0), (0, 0, 0))]
atk["upperarm_r"] = [(0, (0, 0, 0), None), (0.3, (-110, 20, 0), None), (0.5, (-20, -10, 0), None), (0.8, (0, 0, 0), None)]
atk["forearm_r"] = [(0, (0, 0, 0), None), (0.3, (-30, 0, 0), None), (0.5, (-10, 0, 0), None), (0.8, (0, 0, 0), None)]
atk["upperarm_l"] = [(0, (0, 0, 0), None), (0.5, (-30, -20, 0), None), (0.8, (0, 0, 0), None)]
clip(rig, "Attack", 0.8, atk, loop=False)

# Cast: both arms rise, staff lifted high, head back.
cast = {}
cast["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.5, (-6, 0, 0), (0, 0, 0.05)), (1.0, (-6, 0, 0), (0, 0, 0.05)), (1.3, (0, 0, 0), (0, 0, 0))]
cast["upperarm_r"] = [(0, (0, 0, 0), None), (0.5, (-150, 10, 0), None), (1.0, (-150, 10, 0), None), (1.3, (0, 0, 0), None)]
cast["upperarm_l"] = [(0, (0, 0, 0), None), (0.5, (-80, -50, 0), None), (1.0, (-80, -50, 0), None), (1.3, (0, 0, 0), None)]
cast["forearm_l"] = [(0, (0, 0, 0), None), (0.5, (-30, 0, 0), None), (1.0, (-30, 0, 0), None), (1.3, (0, 0, 0), None)]
cast["head"] = [(0, (0, 0, 0), None), (0.5, (-20, 0, 0), None), (1.0, (-20, 0, 0), None), (1.3, (0, 0, 0), None)]
cast["cloak_01"] = [(0, (0, 0, 0), None), (0.5, (14, 0, 0), None), (1.3, (0, 0, 0), None)]
clip(rig, "Cast", 1.3, cast, loop=False)

# Spawn: rises from a crouch, arms spreading.
sp = {}
sp["hips"] = [(0, (30, 0, 0), (0, -0.1, -0.5)), (0.6, (30, 0, 0), (0, -0.1, -0.5)), (1.2, (0, 0, 0), (0, 0, 0))]
sp["chest"] = [(0, (30, 0, 0), None), (0.6, (30, 0, 0), None), (1.2, (-6, 0, 0), None), (1.5, (0, 0, 0), None)]
sp["head"] = [(0, (30, 0, 0), None), (0.6, (30, 0, 0), None), (1.2, (-14, 0, 0), None), (1.5, (0, 0, 0), None)]
for s in ("l", "r"):
    sp["thigh_" + s] = [(0, (-50, 0, 0), None), (0.6, (-50, 0, 0), None), (1.2, (0, 0, 0), None)]
    sp["shin_" + s] = [(0, (70, 0, 0), None), (0.6, (70, 0, 0), None), (1.2, (0, 0, 0), None)]
sp["upperarm_l"] = [(0, (0, 0, 0), None), (0.6, (0, 0, 0), None), (1.2, (-40, -50, 0), None), (1.5, (0, 0, 0), None)]
clip(rig, "Spawn", 1.5, sp, loop=False)

hit = {}
hit["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.12, (-12, 0, 8), (0, 0.1, 0)), (0.45, (0, 0, 0), (0, 0, 0))]
hit["head"] = [(0, (0, 0, 0), None), (0.12, (-18, 0, 0), None), (0.45, (0, 0, 0), None)]
hit["upperarm_l"] = [(0, (0, 0, 0), None), (0.12, (20, -30, 0), None), (0.45, (0, 0, 0), None)]
clip(rig, "Hit", 0.45, hit, loop=False)

# Die: staggers, folds at the knees and falls onto its back.
die = {}
die["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.3, (-8, 0, 0), (0, 0.1, -0.1)), (0.8, (-60, 0, 0), (0, 0.5, -0.55)), (1.2, (-88, 0, 0), (0, 0.9, -0.7))]
die["head"] = [(0, (0, 0, 0), None), (0.3, (-18, 0, 0), None), (1.2, (-10, 0, 0), None)]
for s in ("l", "r"):
    die["thigh_" + s] = [(0, (0, 0, 0), None), (0.5, (-40, 0, 0), None), (1.2, (-20, 0, 0), None)]
    die["shin_" + s] = [(0, (0, 0, 0), None), (0.5, (50, 0, 0), None), (1.2, (20, 0, 0), None)]
die["upperarm_l"] = [(0, (0, 0, 0), None), (0.5, (-40, -50, 0), None), (1.2, (-10, -60, 0), None)]
die["upperarm_r"] = [(0, (0, 0, 0), None), (0.5, (-40, 40, 0), None), (1.2, (-60, 50, 0), None)]
clip(rig, "Die", 1.2, die, loop=False)

export(rig, c, OUT + "winter_caller_src.glb")
os.remove(OUT + "winter_caller_tex.png")
