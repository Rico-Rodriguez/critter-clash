# Rime Yeti (Rimehollow): a hulking ape-like brute, hunched on knuckles, shaggy
# frost-grey fur in faceted tufts, ice shards along the spine, a dark scowling face
# with two tusks. Clips: Idle Walk Run Slam Swipe Roar Hit Die.
# Writes assets/foes/rime_yeti_src.glb. Run: python3 tools/blender/foes/rime_yeti.py -- <repo root>
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "../pets"))
from common import *
import common

ROOT = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(ROOT, "assets/foes/")
reset()
common.SIDES, common.BLOB_SUB = 1.0, 0

FUR = mat("ry_fur", "56626f")
DARK = mat("ry_dark", "2a323b")
PALE = mat("ry_pale", "8996a2")
FACE = mat("ry_face", "1c2127")
TUSK = mat("ry_tusk", "d6d0bd")
ICE = mat("ry_ice", "86c8e6")
CLAW = mat("ry_claw", "181b20")
EYE = mat("ry_eye", "bdeeff")

# Hunched: hips low and back, chest high and forward, arms down to the ground.
S = [
    ("hips", (0, 0.2, 0.95), (0, 0.15, 1.1), None),
    ("spine_01", (0, 0.15, 1.1), (0, 0.0, 1.38), "hips"),
    ("chest", (0, 0.0, 1.38), (0, -0.14, 1.62), "spine_01"),
    ("neck_01", (0, -0.14, 1.62), (0, -0.26, 1.7), "chest"),
    ("head", (0, -0.26, 1.7), (0, -0.4, 1.76), "neck_01"),
    ("jaw", (0, -0.34, 1.64), (0, -0.52, 1.6), "head"),
]
for s, x in (("l", 1), ("r", -1)):
    S += [
        ("thigh_" + s, (x * 0.22, 0.2, 0.95), (x * 0.26, 0.12, 0.52), "hips"),
        ("shin_" + s, (x * 0.26, 0.12, 0.52), (x * 0.26, 0.2, 0.12), "thigh_" + s),
        ("foot_" + s, (x * 0.26, 0.2, 0.12), (x * 0.26, 0.0, 0.04), "shin_" + s),
        ("upperarm_" + s, (x * 0.46, -0.06, 1.55), (x * 0.62, -0.16, 1.05), "chest"),
        ("forearm_" + s, (x * 0.62, -0.16, 1.05), (x * 0.66, -0.3, 0.52), "upperarm_" + s),
        ("hand_" + s, (x * 0.66, -0.3, 0.52), (x * 0.66, -0.42, 0.1), "forearm_" + s),
    ]
rig = armature(S)

# Torso: a barrel chest and a heavy shoulder hump tapering to the hips.
torso = tube("torso", [((0, 0.22, 0.88), 0.2, 0.17), ((0, 0.18, 1.05), 0.3, 0.23), ((0, 0.05, 1.3), 0.38, 0.3),
                       ((0, -0.08, 1.52), 0.5, 0.33), ((0, -0.18, 1.66), 0.3, 0.2)], FUR, n=8)
two_tone(torso, PALE, DARK, down=-0.5, up=0.8)
bind(torso, ["hips", "spine_01", "chest", "neck_01"])
bind(blob("belly", (0, -0.06, 1.2), (0.46, 0.2, 0.44), PALE), ["spine_01"])
# Shaggy tufts down the back and shoulders, with ice shards among them.
for k in range(7):
    t = k / 6
    y, z = 0.2 - t * 0.38, 1.0 + t * 0.66
    bind(cone("tuft%d" % k, (0, y + 0.1, z), (0, y + 0.3, z + 0.1 + (0.12 if k % 2 else 0)), 0.1, DARK, n=4), ["spine_01" if k < 4 else "chest"])
for k, (x, y, z) in enumerate([(0, 0.0, 1.5), (0.14, 0.02, 1.42), (-0.14, 0.02, 1.42), (0, 0.14, 1.3)]):
    bind(cone("ice%d" % k, (x, y + 0.05, z), (x * 1.5, y + 0.2, z + 0.3 + (0.08 if k == 0 else 0)), 0.07, ICE, n=4), ["chest"])
for x in (1, -1):
    common.BLOB_SUB = 1
    bind(blob("shoulder%d" % x, (x * 0.5, -0.06, 1.52), (0.34, 0.34, 0.3), FUR), ["chest", "upperarm_l" if x > 0 else "upperarm_r"])
    common.BLOB_SUB = 0
    bind(cone("sh_tuft%d" % x, (x * 0.5, 0.0, 1.62), (x * 0.66, 0.1, 1.84), 0.09, DARK, n=4), ["chest"])
    bind(cone("ice_sh%d" % x, (x * 0.4, 0.04, 1.66), (x * 0.5, 0.14, 2.0), 0.06, ICE, n=4), ["chest"])

# Head: low, forward-set, heavy brow, dark face, two tusks, lower jaw hung forward.
bind(tube("skull", [((0, -0.12, 1.77), 0.1, 0.1), ((0, -0.2, 1.77), 0.17, 0.17), ((0, -0.34, 1.77), 0.19, 0.17), ((0, -0.46, 1.76), 0.14, 0.13), ((0, -0.52, 1.74), 0.1, 0.1)], FUR, n=8), ["head"])
bind(tube("crest", [((0, -0.14, 1.9), 0.04, 0.05), ((0, -0.26, 1.96), 0.07, 0.07), ((0, -0.4, 1.9), 0.04, 0.04)], DARK, n=5), ["head"])
bind(blob("face", (0, -0.46, 1.7), (0.26, 0.14, 0.2), FACE), ["head"])
bind(blob("brow", (0, -0.43, 1.84), (0.34, 0.14, 0.07), DARK, rot=(0.25, 0, 0)), ["head"])
bind(blob("jaw", (0, -0.44, 1.6), (0.26, 0.26, 0.1), FACE), ["jaw"])
for x in (1, -1):
    bind(blob("eye%d" % x, (x * 0.08, -0.55, 1.76), (0.045, 0.02, 0.025), EYE), ["head"])
    bind(cone("tusk%d" % x, (x * 0.1, -0.5, 1.62), (x * 0.13, -0.62, 1.88), 0.035, TUSK, n=4, bend=(x * 0.03, -0.03, 0)), ["jaw"])
    bind(cone("ear_t%d" % x, (x * 0.18, -0.26, 1.82), (x * 0.3, -0.22, 1.98), 0.06, DARK, n=3), ["head"])
for k in range(3):
    bind(cone("fang%d" % k, ((k - 1) * 0.07, -0.55, 1.64), ((k - 1) * 0.07, -0.57, 1.72), 0.014, TUSK, n=3), ["jaw"])
bind(blob("nostril", (0, -0.58, 1.72), (0.12, 0.02, 0.04), CLAW), ["head"])

# Arms: huge, tapering from the shoulder to big knuckled fists with black claws.
for s, x in (("l", 1), ("r", -1)):
    P = lambda v: (x * v[0], v[1], v[2])
    ua, fa = "upperarm_" + s, "forearm_" + s
    bind(tube("arm_" + s, [(P((0.48, -0.06, 1.52)), 0.17, 0.17), (P((0.62, -0.16, 1.05)), 0.15, 0.15), (P((0.66, -0.3, 0.55)), 0.14, 0.13)],
              FUR, n=6), ["chest", ua, fa])
    bind(tube("fist_" + s, [(P((0.66, -0.3, 0.52)), 0.16, 0.14), (P((0.66, -0.4, 0.14)), 0.2, 0.16), (P((0.66, -0.42, 0.06)), 0.14, 0.1)],
              DARK, n=6), [fa, "hand_" + s])
    for k in range(3):
        bind(cone("claw_%s%d" % (s, k), P((0.58 + k * 0.08, -0.5, 0.1)), P((0.58 + k * 0.08, -0.62, 0.02)), 0.03, CLAW, n=3), ["hand_" + s])
    for k in range(2):
        bind(cone("fur_%s%d" % (s, k), P((0.7, -0.16 - k * 0.1, 1.0 - k * 0.3)), P((0.84, -0.12 - k * 0.1, 0.8 - k * 0.3)), 0.07, DARK, n=3), [fa])
# Legs: short and thick, broad feet.
for s, x in (("l", 1), ("r", -1)):
    P = lambda v: (x * v[0], v[1], v[2])
    bind(tube("leg_" + s, [(P((0.22, 0.2, 0.98)), 0.19, 0.18), (P((0.26, 0.12, 0.55)), 0.15, 0.15), (P((0.26, 0.2, 0.14)), 0.12, 0.12)],
              FUR, n=6), ["hips", "thigh_" + s, "shin_" + s])
    bind(blob("foot_" + s, (x * 0.26, 0.06, 0.06), (0.26, 0.4, 0.12), DARK), ["foot_" + s])
    for k in range(3):
        bind(cone("toe_%s%d" % (s, k), P((0.18 + k * 0.08, -0.12, 0.06)), P((0.18 + k * 0.08, -0.22, 0.02)), 0.03, CLAW, n=3), ["foot_" + s])

yt = skin(rig, "Yeti")
bake(yt, 512, OUT + "rime_yeti_tex.png")


def stride(period, a, knee, arm):
    ks = {}
    for s, sg in (("l", 1), ("r", -1)):
        ks["thigh_" + s] = [(0, (-sg * a, 0, 0), None), (period / 2, (sg * a, 0, 0), None), (period, (-sg * a, 0, 0), None)]
        if sg > 0:
            ks["shin_" + s] = [(0, (knee * 0.2, 0, 0), None), (period * 0.25, (knee, 0, 0), None), (period * 0.5, (knee * 0.1, 0, 0), None), (period, (knee * 0.2, 0, 0), None)]
        else:
            ks["shin_" + s] = [(0, (knee * 0.1, 0, 0), None), (period * 0.5, (knee * 0.2, 0, 0), None), (period * 0.75, (knee, 0, 0), None), (period, (knee * 0.1, 0, 0), None)]
        o = "upperarm_l" if s == "r" else "upperarm_r"
        ks[o] = [(0, (-sg * arm, 0, 0), None), (period / 2, (sg * arm, 0, 0), None), (period, (-sg * arm, 0, 0), None)]
    return ks


def bob(period, tilt, lift, lean=0):
    q = period / 4
    return [(0, (lean, 0, tilt), (0, 0, 0)), (q, (lean, 0, 0), (0, 0, lift)), (2 * q, (lean, 0, -tilt), (0, 0, 0)),
            (3 * q, (lean, 0, 0), (0, 0, lift)), (period, (lean, 0, tilt), (0, 0, 0))]


idle = {"chest": [(0, (0, 0, 0), None), (1.2, (4, 0, 0), None), (2.4, (0, 0, 0), None)],
        "head": [(0, (0, 0, -5), None), (1.2, (-4, 0, 5), None), (2.4, (0, 0, -5), None)],
        "jaw": [(0, (2, 0, 0), None), (1.2, (8, 0, 0), None), (2.4, (2, 0, 0), None)]}
for s, sg in (("l", 1), ("r", -1)):
    idle["upperarm_" + s] = [(0, (3, sg * 2, 0), None), (1.2, (-3, sg * 4, 0), None), (2.4, (3, sg * 2, 0), None)]
clip(rig, "Idle", 2.4, idle)
walk = stride(1.1, 20, 28, 20)
walk["hips"] = bob(1.1, 3, 0.03, 0)
walk["chest"] = [(0, (0, 0, -4), None), (0.55, (0, 0, 4), None), (1.1, (0, 0, -4), None)]
clip(rig, "Walk", 1.1, walk)
run = stride(0.62, 32, 50, 34)
run["hips"] = bob(0.62, 4, 0.06, 8)
run["head"] = [(0, (-6, 0, 0), None), (0.62, (-6, 0, 0), None)]
clip(rig, "Run", 0.62, run)

# Slam: both fists up overhead, rear back, then smash down into the ground.
sl = {}
sl["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.5, (-20, 0, 0), (0, 0.18, 0.12)), (0.7, (24, 0, 0), (0, -0.3, -0.1)), (1.2, (0, 0, 0), (0, 0, 0))]
sl["chest"] = [(0, (0, 0, 0), None), (0.5, (-22, 0, 0), None), (0.7, (24, 0, 0), None), (1.2, (0, 0, 0), None)]
sl["head"] = [(0, (0, 0, 0), None), (0.5, (-14, 0, 0), None), (0.7, (16, 0, 0), None), (1.2, (0, 0, 0), None)]
sl["jaw"] = [(0, (0, 0, 0), None), (0.5, (28, 0, 0), None), (0.75, (4, 0, 0), None), (1.2, (0, 0, 0), None)]
for s, sg in (("l", 1), ("r", -1)):
    sl["upperarm_" + s] = [(0, (0, 0, 0), None), (0.5, (-170, 0, 0), None), (0.7, (-20, 0, 0), None), (1.2, (0, 0, 0), None)]
    sl["forearm_" + s] = [(0, (0, 0, 0), None), (0.5, (-20, 0, 0), None), (0.7, (-30, 0, 0), None), (1.2, (0, 0, 0), None)]
clip(rig, "Slam", 1.2, sl, loop=False)

# Swipe: winds up the right arm outward and rakes across to the left.
sw = {}
sw["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.35, (-6, 0, -20), (0, 0.06, 0)), (0.55, (10, 0, 28), (0, -0.14, 0)), (1.0, (0, 0, 0), (0, 0, 0))]
sw["chest"] = [(0, (0, 0, 0), None), (0.35, (0, 0, -16), None), (0.55, (0, 0, 24), None), (1.0, (0, 0, 0), None)]
sw["upperarm_r"] = [(0, (0, 0, 0), None), (0.35, (-60, 70, 0), None), (0.55, (-70, -60, 0), None), (1.0, (0, 0, 0), None)]
sw["forearm_r"] = [(0, (0, 0, 0), None), (0.35, (-30, 0, 0), None), (0.55, (-20, 0, 0), None), (1.0, (0, 0, 0), None)]
sw["upperarm_l"] = [(0, (0, 0, 0), None), (0.55, (20, 0, 0), None), (1.0, (0, 0, 0), None)]
clip(rig, "Swipe", 1.0, sw, loop=False)

# Roar: rears upright, head back, jaw wide, fists pounding the chest.
ro = {}
ro["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.5, (-30, 0, 0), (0, 0.22, 0.05)), (1.5, (-30, 0, 0), (0, 0.22, 0.05)), (2.0, (0, 0, 0), (0, 0, 0))]
ro["chest"] = [(0, (0, 0, 0), None), (0.5, (-28, 0, 0), None), (1.5, (-28, 0, 0), None), (2.0, (0, 0, 0), None)]
ro["head"] = [(0, (0, 0, 0), None), (0.5, (-34, 0, 0), None), (1.5, (-30, 0, 4), None), (2.0, (0, 0, 0), None)]
ro["jaw"] = [(0, (0, 0, 0), None), (0.5, (40, 0, 0), None), (1.5, (40, 0, 0), None), (2.0, (0, 0, 0), None)]
for s, sg in (("l", 1), ("r", -1)):
    ro["upperarm_" + s] = [(0, (0, 0, 0), None), (0.5, (-90, -sg * 40, 0), None), (0.8, (-70, sg * 8, 0), None), (1.0, (-100, -sg * 40, 0), None),
                           (1.2, (-70, sg * 8, 0), None), (1.4, (-100, -sg * 40, 0), None), (2.0, (0, 0, 0), None)]
    ro["forearm_" + s] = [(0, (0, 0, 0), None), (0.5, (-60, 0, 0), None), (1.4, (-60, 0, 0), None), (2.0, (0, 0, 0), None)]
clip(rig, "Roar", 2.0, ro, loop=False)

hit = {}
hit["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.12, (-10, 0, 6), (0, 0.1, 0)), (0.5, (0, 0, 0), (0, 0, 0))]
hit["chest"] = [(0, (0, 0, 0), None), (0.12, (-14, 0, 0), None), (0.5, (0, 0, 0), None)]
hit["head"] = [(0, (0, 0, 0), None), (0.12, (-20, 0, 0), None), (0.5, (0, 0, 0), None)]
for s, sg in (("l", 1), ("r", -1)):
    hit["upperarm_" + s] = [(0, (0, 0, 0), None), (0.12, (-24, sg * 12, 0), None), (0.5, (0, 0, 0), None)]
clip(rig, "Hit", 0.5, hit, loop=False)

# Die: staggers, drops to its knees and topples forward onto its fists.
die = {}
die["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.4, (6, 0, 0), (0, 0.05, -0.12)), (1.0, (-40, 0, 0), (0, 0.5, -0.4)), (1.6, (-78, 0, 0), (0, 0.9, -0.6))]
die["chest"] = [(0, (0, 0, 0), None), (0.4, (12, 0, 0), None), (1.6, (-10, 0, 0), None)]
die["head"] = [(0, (0, 0, 0), None), (0.4, (-20, 0, 0), None), (1.6, (-12, 0, 0), None)]
die["jaw"] = [(0, (0, 0, 0), None), (0.4, (30, 0, 0), None), (1.6, (14, 0, 0), None)]
for s_, sg in (("l", 1), ("r", -1)):
    die["thigh_" + s_] = [(0, (0, 0, 0), None), (1.0, (-30, -sg * 14, 0), None), (1.6, (-50, -sg * 18, 0), None)]
    die["shin_" + s_] = [(0, (0, 0, 0), None), (1.6, (30, 0, 0), None)]
    die["upperarm_" + s_] = [(0, (0, 0, 0), None), (0.4, (-60, -sg * 30, 0), None), (1.6, (-25, -sg * 40, 0), None)]
clip(rig, "Die", 1.6, die, loop=False)

export(rig, yt, OUT + "rime_yeti_src.glb")
os.remove(OUT + "rime_yeti_tex.png")
