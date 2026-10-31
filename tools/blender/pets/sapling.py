# Thorn Sapling: a young treant at real proportions. A bark trunk with a face
# in it, a crown of leaves with a few blossoms, branch arms with twig fingers
# and thorns, walking on two thick roots. Writes assets/sidekicks/treant_src.glb.
# Run: <blender python> tools/blender/pets/sapling.py -- <repo root>
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *

ROOT = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(ROOT, "assets/sidekicks/")
reset()

BARK = mat("sap_bark", "47331f")
BARK_D = mat("sap_bark_d", "2e1f12")
BARK_L = mat("sap_bark_l", "5e4a32")
LEAF = mat("sap_leaf", "3e6526")
LEAF_D = mat("sap_leaf_d", "27441a")
LEAF_L = mat("sap_leaf_l", "5a8231")
BLOSSOM = mat("sap_blossom", "a3445f")
THORN = mat("sap_thorn", "a89c80")
EYE = mat("sap_eye", "a8e050")
HOLLOW = mat("sap_hollow", "120b05")
MOSS = mat("sap_moss", "4f6e27")

S = [
    ("hips", (0, 0, 0.3), (0, 0, 0.45), None),
    ("spine_01", (0, 0, 0.45), (0, 0, 0.62), "hips"),
    ("head", (0, 0, 0.62), (0, 0, 0.86), "spine_01"),
    ("jaw", (0, -0.08, 0.66), (0, -0.13, 0.64), "head"),
    ("crown", (0, 0, 0.86), (0, 0, 1.2), "head"),
]
for s, x in (("l", 1), ("r", -1)):
    S += [
        ("arm_%s_1" % s, (x * 0.12, 0, 0.62), (x * 0.21, -0.01, 0.48), "spine_01"),
        ("arm_%s_2" % s, (x * 0.21, -0.01, 0.48), (x * 0.26, -0.05, 0.34), "arm_%s_1" % s),
        ("leg_%s_1" % s, (x * 0.07, 0, 0.32), (x * 0.1, 0, 0.17), "hips"),
        ("leg_%s_2" % s, (x * 0.1, 0, 0.17), (x * 0.11, -0.03, 0.03), "leg_%s_1" % s),
    ]
rig = armature(S)

# Trunk: the lower half is the body, the upper half (with the face) the head.
low = tube("trunk_low", [((0, 0, 0.26), 0.14, 0.13), ((0, 0, 0.36), 0.12, 0.115), ((0, 0, 0.5), 0.11, 0.105), ((0, 0, 0.62), 0.12, 0.115)], BARK, n=10)
two_tone(low, BARK_D, None, down=-0.4)
bind(low, ["hips", "spine_01"])
up = tube("trunk_up", [((0, 0, 0.6), 0.12, 0.115), ((0, 0, 0.72), 0.13, 0.125), ((0, 0, 0.82), 0.125, 0.12), ((0, 0, 0.9), 0.09, 0.09)], BARK, n=10)
two_tone(up, BARK_D, BARK_L, down=-0.4, up=0.8)
bind(up, ["head"])
# Bark ridges running up the trunk, and a patch of moss on one shoulder.
for k in range(6):
    a = k * math.pi / 3 + 0.3
    bind(tube("ridge_%d" % k, [((math.cos(a) * 0.125, math.sin(a) * 0.12, 0.3), 0.018, 0.018), ((math.cos(a + 0.2) * 0.11, math.sin(a + 0.2) * 0.105, 0.5), 0.016, 0.016),
                               ((math.cos(a + 0.1) * 0.12, math.sin(a + 0.1) * 0.115, 0.6), 0.012, 0.012)], BARK_D, n=5), ["hips", "spine_01"])
bind(blob("moss", (0.07, 0.03, 0.86), (0.14, 0.14, 0.06), MOSS, sub=1), ["head"])
# The face: two hollows with a green glow deep inside, a heavy brow and a knot mouth.
for s, x in (("l", 1), ("r", -1)):
    bind(blob("hollow_" + s, (x * 0.048, -0.11, 0.75), (0.055, 0.04, 0.045), HOLLOW, sub=1), ["head"])
    bind(blob("eye_" + s, (x * 0.048, -0.125, 0.748), (0.026, 0.02, 0.024), EYE, sub=1), ["head"])
bind(tube("brow", [((0.1, -0.095, 0.79), 0.022, 0.02), ((0, -0.125, 0.785), 0.026, 0.022), ((-0.1, -0.095, 0.79), 0.022, 0.02)], BARK_D, n=6), ["head"])
bind(blob("nose", (0, -0.135, 0.71), (0.035, 0.04, 0.05), BARK_L, sub=1), ["head"])
bind(blob("mouth", (0, -0.118, 0.655), (0.07, 0.03, 0.026), HOLLOW, sub=1), ["jaw"])
# Crown: short branches up from the trunk into clumps of leaves, with blossoms.
for k, (a, r) in enumerate([(0.0, 0.06), (2.1, 0.07), (4.2, 0.065)]):
    bind(cone("branch_%d" % k, (math.cos(a) * 0.04, math.sin(a) * 0.04, 0.86), (math.cos(a) * r * 3.2, math.sin(a) * r * 3.2, 1.06), 0.035, BARK, n=5), ["crown"])
CROWN = 1.8  # leaf layout below, scaled up about the top of the trunk
def cz(p):
    return (p[0] * CROWN, p[1] * CROWN, 0.88 + (p[2] - 0.9) * CROWN)
for k, (p, sz, m) in enumerate([((0, 0.01, 1.0), (0.3, 0.28, 0.2), LEAF), ((0.13, 0.03, 0.95), (0.2, 0.2, 0.16), LEAF_D), ((-0.13, 0.03, 0.95), (0.2, 0.2, 0.16), LEAF_D),
                                 ((0.04, 0.12, 0.97), (0.2, 0.18, 0.16), LEAF_D), ((-0.05, -0.08, 0.96), (0.18, 0.16, 0.14), LEAF_L), ((0.0, 0.0, 1.09), (0.16, 0.16, 0.12), LEAF_L)]):
    bind(blob("leaves_%d" % k, cz(p), tuple(v * CROWN for v in sz), m, sub=1), ["crown"])
for k, p in enumerate([(0.12, -0.06, 1.0), (-0.1, -0.07, 1.02), (0.02, -0.11, 0.96), (-0.15, 0.06, 0.98), (0.08, 0.1, 1.06), (0.15, 0.08, 0.94), (-0.04, -0.1, 1.08)]):
    bind(blob("blossom_%d" % k, cz(p), (0.06, 0.06, 0.045), BLOSSOM, sub=1), ["crown"])
# Thorns along the trunk.
for k, (a, z) in enumerate([(0.6, 0.4), (2.0, 0.48), (3.6, 0.36), (5.0, 0.52), (1.2, 0.84), (4.4, 0.8)]):
    base = (math.cos(a) * 0.11, math.sin(a) * 0.105, z)
    bind(cone("thorn_%d" % k, base, (math.cos(a) * 0.18, math.sin(a) * 0.17, z + 0.03), 0.014, THORN, n=4), ["head"] if z > 0.62 else ["spine_01"])
for s, x in (("l", 1), ("r", -1)):
    P = lambda v: (x * v[0], v[1], v[2])
    # Branch arms with three twig fingers and a thorn at the elbow.
    bind(tube("arm_" + s, [(P((0.1, 0, 0.64)), 0.045, 0.045), (P((0.21, -0.01, 0.48)), 0.034, 0.034), (P((0.26, -0.05, 0.34)), 0.026, 0.026)], BARK, n=6), ["arm_%s_1" % s, "arm_%s_2" % s])
    for k in (-1, 0, 1):
        bind(cone("twig_%s%d" % (s, k), P((0.26, -0.05, 0.34)), P((0.28 + k * 0.035, -0.09 + k * 0.03, 0.25)), 0.012, BARK_D, n=4, bend=P((0.01, 0, 0))), ["arm_%s_2" % s])
    bind(cone("ethorn_" + s, P((0.21, 0.0, 0.49)), P((0.29, 0.04, 0.53)), 0.012, THORN, n=4), ["arm_%s_1" % s])
    bind(blob("sprig_" + s, P((0.16, -0.03, 0.58)), (0.07, 0.04, 0.05), LEAF_L, sub=1), ["arm_%s_1" % s])
    # Root legs, splaying into root toes.
    bind(tube("leg_" + s, [(P((0.06, 0, 0.32)), 0.075, 0.075), (P((0.1, 0, 0.17)), 0.065, 0.065), (P((0.11, -0.02, 0.05)), 0.07, 0.07)], BARK, n=8), ["hips", "leg_%s_1" % s, "leg_%s_2" % s])
    for k in (-1, 0, 1):
        bind(cone("toe_%s%d" % (s, k), P((0.11, -0.02, 0.05)), P((0.11 + k * 0.06, -0.13, 0.01)), 0.025, BARK_D, n=5, bend=(0, 0, 0.01)), ["leg_%s_2" % s])
    bind(cone("heel_" + s, P((0.11, 0.0, 0.05)), P((0.13, 0.1, 0.01)), 0.022, BARK_D, n=5), ["leg_%s_2" % s])
# A few trailing roots from the base of the trunk.
for k, a in enumerate((1.2, 1.9, 2.6)):
    bind(cone("root_%d" % k, (math.cos(a) * 0.09, math.sin(a) * 0.08 + 0.02, 0.27), (math.cos(a) * 0.2, math.sin(a) * 0.2 + 0.05, 0.12), 0.03, BARK_D, n=5), ["hips"])

sap = skin(rig, "Sapling")
bake(sap, 1024, OUT + "treant_tex.png")

# Clips: +X pitches forward / swings a leg back, -X swings it forward. For
# the arms, -Y lifts the left one out to the side (+Y the right).
idle = {
    "hips": [(0, (0, 0, 0), (0, 0, 0)), (1.2, (0, 3, 0), (0, 0, 0.008)), (2.4, (0, 0, 0), (0, 0, 0))],
    "head": [(0, (0, 0, 0), None), (0.8, (-4, 0, 6), None), (1.6, (2, 0, -6), None), (2.4, (0, 0, 0), None)],
    "crown": [(0, (0, 0, 0), None), (0.6, (3, 4, 0), None), (1.4, (-2, -4, 0), None), (2.4, (0, 0, 0), None)],
}
for s, sg in (("l", 1), ("r", -1)):
    idle["arm_%s_1" % s] = [(0, (0, 0, 0), None), (1.2, (-6, -sg * 6, 0), None), (2.4, (0, 0, 0), None)]
clip(rig, "Idle", 2.4, idle)

walk = {"hips": [(0, (4, 0, 0), (0, 0, 0)), (0.2, (4, 0, -4), (0, 0, 0.02)), (0.4, (4, 0, 0), (0, 0, 0)), (0.6, (4, 0, 4), (0, 0, 0.02)), (0.8, (4, 0, 0), (0, 0, 0))],
        "crown": [(0, (0, 0, 0), None), (0.2, (-4, 0, 0), None), (0.4, (0, 0, 0), None), (0.6, (-4, 0, 0), None), (0.8, (0, 0, 0), None)]}
for s, ph in (("l", 1), ("r", -1)):
    walk["leg_%s_1" % s] = [(0, (-25 * ph, 0, 0), None), (0.4, (25 * ph, 0, 0), None), (0.8, (-25 * ph, 0, 0), None)]
    walk["leg_%s_2" % s] = [(0, (10, 0, 0), None), (0.2, (30 if ph < 0 else 0, 0, 0), None), (0.4, (10, 0, 0), None), (0.6, (30 if ph > 0 else 0, 0, 0), None), (0.8, (10, 0, 0), None)]
    walk["arm_%s_1" % s] = [(0, (20 * ph, 0, 0), None), (0.4, (-20 * ph, 0, 0), None), (0.8, (20 * ph, 0, 0), None)]
clip(rig, "Walk", 0.8, walk)

# A lash: the right branch swings up and cracks down.
atk = {"hips": [(0, (0, 0, 0), None), (0.2, (-6, 0, -15), None), (0.35, (12, 0, 10), None), (0.6, (0, 0, 0), None)],
       "arm_r_1": [(0, (0, 0, 0), None), (0.2, (-110, 0, 0), None), (0.35, (-10, 0, 0), None), (0.6, (0, 0, 0), None)],
       "arm_r_2": [(0, (0, 0, 0), None), (0.2, (-30, 0, 0), None), (0.35, (10, 0, 0), None), (0.6, (0, 0, 0), None)],
       "jaw": [(0, (0, 0, 0), (0, 0, 0)), (0.3, (0, 0, 0), (0, 0, -0.015)), (0.6, (0, 0, 0), (0, 0, 0))]}
clip(rig, "Attack", 0.6, atk, loop=False)

hit = {"hips": [(0, (0, 0, 0), (0, 0, 0)), (0.1, (-14, 0, 0), (0, 0.04, 0)), (0.4, (0, 0, 0), (0, 0, 0))],
       "crown": [(0, (0, 0, 0), None), (0.12, (-12, 0, 0), None), (0.4, (0, 0, 0), None)]}
clip(rig, "Hit", 0.4, hit, loop=False)

# Rootsnare: both branches thrown up, then a stomp that drives the roots down.
sp = {"hips": [(0, (0, 0, 0), (0, 0, 0)), (0.35, (-8, 0, 0), (0, 0, 0.05)), (0.55, (10, 0, 0), (0, 0, -0.04)), (1.0, (0, 0, 0), (0, 0, 0))],
      "crown": [(0, (0, 0, 0), None), (0.35, (-10, 0, 0), None), (0.6, (8, 0, 0), None), (1.0, (0, 0, 0), None)]}
for s, sg in (("l", 1), ("r", -1)):
    sp["arm_%s_1" % s] = [(0, (0, 0, 0), None), (0.35, (0, -sg * 80, 0), None), (0.55, (0, sg * 10, 0), None), (1.0, (0, 0, 0), None)]
    sp["leg_%s_1" % s] = [(0, (0, 0, 0), None), (0.35, (0, -sg * 6, 0), None), (0.55, (0, sg * 4, 0), None), (1.0, (0, 0, 0), None)]
clip(rig, "Special", 1.0, sp, loop=False)

export(rig, sap, OUT + "treant_src.glb")
os.remove(OUT + "treant_tex.png")
