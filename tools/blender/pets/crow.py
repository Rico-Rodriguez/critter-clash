# Storm Crow: a big raven at real proportions, blue-black with a storm-blue
# sheen and a yellow eye. Stands with its wings folded; spreads them to fly.
# Writes assets/sidekicks/crow_src.glb.
# Run: <blender python> tools/blender/pets/crow.py -- <repo root>
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *

ROOT = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(ROOT, "assets/sidekicks/")
reset()

BLACK = mat("crow_black", "1e2331")
DEEP = mat("crow_deep", "121520")
SHEEN = mat("crow_sheen", "38507a")
STORM = mat("crow_storm", "8ec2ff")
BEAK = mat("crow_beak", "2d2c31")
EYE = mat("crow_eye", "ffd04f")
PUPIL = mat("crow_pupil", "0d0d10")
LEG = mat("crow_leg", "3b3b42")

S = [
    ("hips", (0, 0.16, 0.55), (0, -0.04, 0.6), None),
    ("spine_01", (0, -0.04, 0.6), (0, -0.2, 0.7), "hips"),
    ("neck_01", (0, -0.2, 0.7), (0, -0.27, 0.82), "spine_01"),
    ("head", (0, -0.27, 0.82), (0, -0.46, 0.86), "neck_01"),
    ("jaw", (0, -0.36, 0.82), (0, -0.55, 0.8), "head"),
    ("tail_01", (0, 0.16, 0.55), (0, 0.4, 0.49), "hips"),
    ("tail_02", (0, 0.4, 0.49), (0, 0.66, 0.43), "tail_01"),
]
for s, x in (("l", 1), ("r", -1)):
    S += [
        ("wing_%s_1" % s, (x * 0.13, -0.12, 0.7), (x * 0.42, -0.07, 0.73), "spine_01"),
        ("wing_%s_2" % s, (x * 0.42, -0.07, 0.73), (x * 0.72, -0.02, 0.71), "wing_%s_1" % s),
        ("wing_%s_3" % s, (x * 0.72, -0.02, 0.71), (x * 0.98, 0.06, 0.67), "wing_%s_2" % s),
        ("leg_%s" % s, (x * 0.08, 0.04, 0.44), (x * 0.09, 0.0, 0.08), "hips"),
    ]
rig = armature(S)

body = tube("body", [((0, 0.24, 0.53), 0.06, 0.05), ((0, 0.14, 0.55), 0.14, 0.13), ((0, 0.0, 0.59), 0.17, 0.17),
                     ((0, -0.14, 0.65), 0.15, 0.16), ((0, -0.22, 0.72), 0.1, 0.11)], BLACK, n=12)
two_tone(body, DEEP, SHEEN, down=-0.3, up=0.6)
bind(body, ["hips", "spine_01"])
neck = tube("neck", [((0, -0.17, 0.68), 0.11, 0.11), ((0, -0.25, 0.78), 0.09, 0.09), ((0, -0.3, 0.86), 0.085, 0.085)], BLACK, n=10)
bind(neck, ["spine_01", "neck_01"])
head = tube("head", [((0, -0.22, 0.88), 0.06, 0.06), ((0, -0.29, 0.89), 0.095, 0.09), ((0, -0.38, 0.88), 0.08, 0.075),
                     ((0, -0.43, 0.86), 0.055, 0.05)], BLACK, n=10)
two_tone(head, BLACK, SHEEN, up=0.7)
bind(head, ["head"])
# A heavy beak: upper hooks over the lower, which hinges open.
bind(tube("beak", [((0, -0.41, 0.87), 0.045, 0.04), ((0, -0.5, 0.86), 0.03, 0.026), ((0, -0.58, 0.84), 0.012, 0.012),
                   ((0, -0.6, 0.82), 0.004, 0.004)], BEAK, n=8), ["head"])
bind(tube("beak_lo", [((0, -0.41, 0.835), 0.035, 0.015), ((0, -0.5, 0.825), 0.022, 0.012), ((0, -0.57, 0.82), 0.006, 0.005)], BEAK, n=8), ["jaw"])
# Throat hackles: a shaggy bib of feathers under the chin.
for k in range(3):
    a = (k - 1) * 0.4
    bind(cone("hackle_%d" % k, (math.sin(a) * 0.05, -0.32, 0.8), (math.sin(a) * 0.06, -0.27, 0.72), 0.035, DEEP, n=4), ["neck_01"])
for s, x in (("l", 1), ("r", -1)):
    bind(blob("eye_" + s, (x * 0.07, -0.36, 0.905), (0.03, 0.04, 0.035), EYE, sub=1), ["head"])
    bind(blob("pupil_" + s, (x * 0.084, -0.365, 0.905), (0.012, 0.022, 0.024), PUPIL, sub=1), ["head"])
    # Legs, scaled, with three talons forward and one back.
    # Feathered thighs to low on the leg, so only a short scaled shin shows.
    bind(tube("thigh_" + s, [((x * 0.08, 0.04, 0.52), 0.065, 0.065), ((x * 0.085, 0.03, 0.36), 0.05, 0.05), ((x * 0.088, 0.02, 0.26), 0.032, 0.032)], BLACK, n=8), ["hips", "leg_%s" % s])
    bind(tube("shin_" + s, [((x * 0.088, 0.02, 0.27), 0.028, 0.028), ((x * 0.09, 0.0, 0.08), 0.024, 0.024)], LEG, n=6), ["leg_%s" % s])
    for k in (-1, 0, 1):
        bind(cone("toe_%s%d" % (s, k), (x * 0.09, 0.0, 0.07), (x * 0.09 + k * 0.05, -0.12, 0.015), 0.014, LEG, n=5, bend=(0, 0, 0.02)), ["leg_%s" % s])
    bind(cone("toe_%sb" % s, (x * 0.09, 0.0, 0.07), (x * 0.09, 0.09, 0.02), 0.012, LEG, n=5), ["leg_%s" % s])
# Wings: an arm, a row of long primaries fanned from the hand, secondaries
# along the forearm and a pale storm-blue band of coverts.
for s, x in (("l", 1), ("r", -1)):
    P = lambda v: (x * v[0], v[1], v[2])
    bones = ["wing_%s_1" % s, "wing_%s_2" % s, "wing_%s_3" % s]
    bind(tube("arm_" + s, [(P((0.1, -0.12, 0.7)), 0.06, 0.05), (P((0.42, -0.07, 0.73)), 0.04, 0.035),
                          (P((0.72, -0.02, 0.71)), 0.025, 0.022), (P((0.9, 0.04, 0.68)), 0.012, 0.01)], BLACK, n=8), bones)
    for k in range(6):
        # Primaries: long fingers off the hand, spreading back.
        t = k / 5
        root = P((0.94 - t * 0.22, 0.04 + t * 0.03, 0.68))
        tipx, tipy = 1.12 - t * 0.28, 0.12 + t * 0.26
        tip = P((tipx, tipy, 0.64 - t * 0.02))
        sideb = P((tipx - 0.11, tipy - 0.02, 0.645))
        bind(sheet("prim_%s%d" % (s, k), [root, P((0.93 - t * 0.22 + 0.02, 0.0 + t * 0.03, 0.685)), tip, sideb], DEEP if k % 2 else BLACK, 0.012), bones[1:])
    for k in range(6):
        # Secondaries along the forearm.
        u = k / 5
        root = P((0.68 - u * 0.48, -0.02 - u * 0.05, 0.71 + u * 0.02))
        bind(sheet("sec_%s%d" % (s, k), [root, P((0.7 - u * 0.48, -0.04 - u * 0.05, 0.715 + u * 0.02)),
                                          P((0.66 - u * 0.48, 0.32 - u * 0.03, 0.66)), P((0.58 - u * 0.48, 0.3 - u * 0.03, 0.665))],
                   BLACK if k % 2 else DEEP, 0.012), bones)
    # The wing's own surface under the feathers, so it reads as one wing.
    bind(sheet("vane_" + s, [P((0.12, -0.1, 0.7)), P((0.42, -0.08, 0.735)), P((0.72, -0.03, 0.715)), P((1.08, 0.12, 0.655)),
                             P((0.88, 0.38, 0.65)), P((0.5, 0.33, 0.665)), P((0.18, 0.22, 0.69))], DEEP, 0.016), bones)
    bind(sheet("covert_" + s, [P((0.14, -0.1, 0.72)), P((0.72, -0.01, 0.72)), P((0.66, 0.12, 0.7)), P((0.16, 0.06, 0.71))], SHEEN, 0.02), bones)
    bind(sheet("band_" + s, [P((0.3, 0.07, 0.725)), P((0.68, 0.1, 0.715)), P((0.64, 0.16, 0.71)), P((0.3, 0.13, 0.72))], STORM, 0.022), bones)
# Tail: a wedge of long feathers.
for k in range(7):
    a = (k - 3) * 0.13
    root = (math.sin(a) * 0.04, 0.2, 0.53)
    tip = (math.sin(a) * 0.2, 0.2 + math.cos(a) * 0.48, 0.43)
    w = (math.cos(a) * 0.045, -math.sin(a) * 0.045, 0)
    bind(sheet("tail_%d" % k, [root, (tip[0] + w[0], tip[1] + w[1], tip[2] + 0.004 * k), (tip[0] - w[0], tip[1] - w[1], tip[2] + 0.004 * k)],
               DEEP if k % 2 else BLACK, 0.012), ["tail_01", "tail_02"])

crow = skin(rig, "Crow")
bake(crow, 1024, OUT + "crow_tex.png")

# Clips: +X pitches the nose down, -Y lifts the left wing (+Y the right), Z
# turns (+Z swings the left wing back). Folded: each wing swept back along
# the body and dropped to the flank.
def fold(t, sg, spread=0.0):
    k = 1.0 - spread
    return {"wing_%s_1": (t, (0, sg * 40 * k, sg * 84 * k), None),
            "wing_%s_2": (t, (0, sg * 6 * k, sg * 8 * k), None),
            "wing_%s_3": (t, (0, 0, sg * 6 * k), None)}

def wings(keys, frames):
    """frames: [(time, spread 0..1, extra lift degrees)]"""
    for s, sg in (("l", 1), ("r", -1)):
        for t, spread, lift in frames:
            for bn, (tt, (rx, ry, rz), loc) in fold(t, sg, spread).items():
                keys.setdefault(bn % s, []).append((tt, (rx, ry - sg * lift * (1 if bn.endswith("_1") else 0.5), rz), loc))
    return keys

idle = wings({}, [(0, 0, 0), (2.4, 0, 0)])
idle["head"] = [(0, (0, 0, 0), None), (0.5, (0, 0, 28), None), (1.0, (6, 0, 28), None), (1.4, (0, 0, -22), None), (2.0, (0, 0, -22), None), (2.4, (0, 0, 0), None)]
idle["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (1.2, (-3, 0, 0), (0, 0, 0.012)), (2.4, (0, 0, 0), (0, 0, 0))]
idle["tail_01"] = [(0, (0, 0, 0), None), (1.2, (-6, 0, 0), None), (2.4, (0, 0, 0), None)]
clip(rig, "Idle", 2.4, idle)

fly = wings({}, [(0, 1, 40), (0.25, 1, -35), (0.5, 1, 40)])
fly["hips"] = [(0, (16, 0, 0), (0, 0, 0.42)), (0.25, (16, 0, 0), (0, 0, 0.5)), (0.5, (16, 0, 0), (0, 0, 0.42))]
fly["neck_01"] = [(0, (-14, 0, 0), None), (0.5, (-14, 0, 0), None)]
for s in "lr":
    fly["leg_" + s] = [(0, (-60, 0, 0), None), (0.5, (-60, 0, 0), None)]
fly["tail_01"] = [(0, (-6, 0, 0), None), (0.25, (4, 0, 0), None), (0.5, (-6, 0, 0), None)]
clip(rig, "Fast_Flying", 0.5, fly)

atk = wings({}, [(0, 0, 0), (0.2, 0.5, 20), (0.35, 0.5, 10), (0.6, 0, 0)])
atk["hips"] = [(0, (0, 0, 0), None), (0.2, (-12, 0, 0), None), (0.35, (22, 0, 0), None), (0.6, (0, 0, 0), None)]
atk["neck_01"] = [(0, (0, 0, 0), None), (0.2, (-20, 0, 0), None), (0.35, (30, 0, 0), None), (0.6, (0, 0, 0), None)]
atk["jaw"] = [(0, (0, 0, 0), None), (0.22, (28, 0, 0), None), (0.36, (0, 0, 0), None), (0.6, (0, 0, 0), None)]
clip(rig, "Attack", 0.6, atk, loop=False)

hit = wings({}, [(0, 0, 0), (0.1, 0.7, 30), (0.4, 0, 0)])
hit["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.1, (-18, 0, 0), (0, 0.08, 0.04)), (0.4, (0, 0, 0), (0, 0, 0))]
clip(rig, "Hit", 0.4, hit, loop=False)

sp = wings({}, [(0, 0, 0), (0.3, 1, 55), (0.5, 1, -10), (0.7, 1, 55), (1.0, 0, 0)])
sp["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.3, (-14, 0, 0), (0, 0, 0.1)), (0.7, (-14, 0, 0), (0, 0, 0.1)), (1.0, (0, 0, 0), (0, 0, 0))]
sp["neck_01"] = [(0, (0, 0, 0), None), (0.3, (-26, 0, 0), None), (0.7, (-26, 0, 0), None), (1.0, (0, 0, 0), None)]
sp["jaw"] = [(0, (0, 0, 0), None), (0.35, (32, 0, 0), None), (0.7, (32, 0, 0), None), (1.0, (0, 0, 0), None)]
clip(rig, "Special", 1.0, sp, loop=False)

export(rig, crow, OUT + "crow_src.glb")
os.remove(OUT + "crow_tex.png")
