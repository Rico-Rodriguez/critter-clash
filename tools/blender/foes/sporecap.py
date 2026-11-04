# Sporecap (Cinder Mire): a squat fungus walker. A fat grey stem body with two
# short legs and stubby arms, a hollow dark face, and a wide bruise-purple cap
# faceted like a shield, gills under its rim, bile-yellow spots and spore sacs
# on top. It staggers up to you and bursts. Writes assets/foes/sporecap_src.glb.
# Run: python3 tools/blender/foes/sporecap.py -- <repo root>
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "pets"))
import common
from common import *

ROOT = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(ROOT, "assets/foes/")
reset()
common.SIDES, common.BLOB_SUB = 1.0, 1

STEM = mat("spore_stem", "4a4a3e")
STEM_D = mat("spore_stem_d", "2e2e26")
CAP = mat("spore_cap", "3b2a3a")
CAP_L = mat("spore_cap_l", "55405a")
GILL = mat("spore_gill", "6b5a3c")
SPOT = mat("spore_spot", "a29a3a")
VOID = mat("spore_void", "070806", 1.0)
EYE = mat("spore_eye", "c8d84a")
ROT = mat("spore_rot", "3a3022")
SAC = mat("spore_sac", "6f7a2e")

S = [
    ("hips", (0, 0, 0.34), (0, 0, 0.46), None),
    ("spine_01", (0, 0, 0.46), (0, 0, 0.8), "hips"),
    ("cap", (0, 0, 0.8), (0, 0, 1.22), "spine_01"),
]
for s, x in (("l", 1), ("r", -1)):
    S += [
        ("thigh_" + s, (x * 0.1, 0, 0.36), (x * 0.11, 0, 0.19), "hips"),
        ("shin_" + s, (x * 0.11, 0, 0.19), (x * 0.11, 0, 0.03), "thigh_" + s),
        ("arm_" + s, (x * 0.2, -0.02, 0.62), (x * 0.3, -0.06, 0.42), "spine_01"),
    ]
rig = armature(S)

# Stem: a lumpy barrel, wider at the belly, necking in under the cap.
stem = tube("stem", [((0, 0, 0.3), 0.14, 0.13), ((0, 0, 0.4), 0.23, 0.2), ((0, 0, 0.54), 0.25, 0.22),
                     ((0, 0, 0.68), 0.2, 0.17), ((0, 0, 0.82), 0.12, 0.11)], STEM, n=9)
two_tone(stem, STEM_D, None, down=-0.5)
bind(stem, ["hips", "spine_01"])
# Face: two sunk eyes with a sick glint, a ragged mouth hole.
for x in (1, -1):
    bind(blob("socket", (x * 0.08, -0.185, 0.58), (0.075, 0.04, 0.07), VOID, rot=(0, 0, x * 0.2)), ["spine_01"])
    bind(blob("eye", (x * 0.08, -0.2, 0.585), (0.03, 0.014, 0.03), EYE, sub=1), ["spine_01"])
bind(blob("mouth", (0, -0.205, 0.46), (0.11, 0.04, 0.09), VOID), ["spine_01"])
for k in range(3):
    bind(cone("tooth%d" % k, ((k - 1) * 0.04, -0.222, 0.505), ((k - 1) * 0.04, -0.23, 0.44), 0.014, GILL, n=3), ["spine_01"])
# Rot patches and a root collar at the base.
for k, (x, y, z, w) in enumerate([(0.17, -0.1, 0.42, 0.08), (-0.14, 0.12, 0.5, 0.09), (0.05, 0.19, 0.38, 0.07)]):
    bind(blob("rot%d" % k, (x, y, z), (w, w, w * 0.8), ROT, sub=1), ["spine_01"])

# Cap: a faceted dome, gills below the rim, plum on top with a lighter crown.
cap = tube("cap", [((0, 0, 0.77), 0.2, 0.2), ((0, 0, 0.8), 0.47, 0.45), ((0, 0, 0.88), 0.5, 0.48), ((0, 0, 0.98), 0.4, 0.38),
                   ((0, 0, 1.08), 0.26, 0.25), ((0, 0, 1.17), 0.13, 0.12), ((0, 0, 1.21), 0.04, 0.04)], CAP, n=10)
two_tone(cap, GILL, CAP_L, down=-0.2, up=0.8)
bind(cap, ["cap"])
# Spots and spore sacs on the dome (z follows the dome's surface).
for k, (a, r, sz) in enumerate([(0.3, 0.38, 0.1), (1.5, 0.28, 0.08), (2.6, 0.4, 0.11), (3.9, 0.32, 0.09), (4.9, 0.42, 0.1), (5.6, 0.18, 0.07)]):
    z = 1.1 - r * 0.62 if r < 0.4 else 0.96 - (r - 0.4) * 1.6
    bind(blob("spot%d" % k, (math.cos(a) * r, math.sin(a) * r, z + 0.02), (sz, sz, sz * 0.45), SPOT, sub=1,
              rot=(math.sin(a) * 0.5, -math.cos(a) * 0.5, 0)), ["cap"])
for k, (a, r) in enumerate([(0.9, 0.14), (3.4, 0.17), (5.2, 0.12)]):
    bind(blob("sac%d" % k, (math.cos(a) * r, math.sin(a) * r, 1.17), (0.08, 0.08, 0.1), SAC, sub=1), ["cap"])
# Gill ribs hanging under the rim.
for k in range(8):
    a = k * math.pi / 4 + 0.2
    bind(blob("gill%d" % k, (math.cos(a) * 0.4, math.sin(a) * 0.39, 0.765), (0.07, 0.02, 0.025), GILL, sub=0, rot=(0, 0, a)), ["cap"])

for s, x in (("l", 1), ("r", -1)):
    P = lambda v: (x * v[0], v[1], v[2])
    bind(tube("leg_" + s, [(P((0.1, 0, 0.38)), 0.075, 0.075), (P((0.11, 0, 0.19)), 0.06, 0.06), (P((0.11, 0, 0.06)), 0.05, 0.05)], STEM_D, n=6),
         ["thigh_" + s, "shin_" + s])
    bind(blob("foot_" + s, P((0.11, -0.05, 0.03)), (0.13, 0.2, 0.06), ROT), ["shin_" + s])
    bind(tube("arm_" + s, [(P((0.19, -0.02, 0.62)), 0.06, 0.06), (P((0.3, -0.06, 0.42)), 0.045, 0.045)], STEM, n=6), ["arm_" + s])
    bind(blob("fist_" + s, P((0.31, -0.07, 0.39)), (0.08, 0.08, 0.08), SAC, sub=1), ["arm_" + s])

body = skin(rig, "Sporecap")
bake(body, 256, OUT + "sporecap_tex.png")


def walk(period, a, arm, bob_z, roll):
    ks = {"thigh_l": [(0, (-a, 0, 0), None), (period / 2, (a, 0, 0), None), (period, (-a, 0, 0), None)],
          "thigh_r": [(0, (a, 0, 0), None), (period / 2, (-a, 0, 0), None), (period, (a, 0, 0), None)],
          "shin_l": [(0, (a * 0.4, 0, 0), None), (period * 0.25, (a * 1.5, 0, 0), None), (period * 0.5, (0, 0, 0), None), (period, (a * 0.4, 0, 0), None)],
          "shin_r": [(0, (0, 0, 0), None), (period * 0.5, (a * 0.4, 0, 0), None), (period * 0.75, (a * 1.5, 0, 0), None), (period, (0, 0, 0), None)],
          "arm_l": [(0, (arm, 0, 0), None), (period / 2, (-arm, 0, 0), None), (period, (arm, 0, 0), None)],
          "arm_r": [(0, (-arm, 0, 0), None), (period / 2, (arm, 0, 0), None), (period, (-arm, 0, 0), None)],
          "hips": [(0, (0, 0, roll), (0, 0, 0)), (period / 4, (0, 0, 0), (0, 0, bob_z)), (period / 2, (0, 0, -roll), (0, 0, 0)),
                   (period * 0.75, (0, 0, 0), (0, 0, bob_z)), (period, (0, 0, roll), (0, 0, 0))],
          "cap": [(0, (3, 0, -roll), None), (period / 2, (-3, 0, roll), None), (period, (3, 0, -roll), None)]}
    return ks

idle = {"hips": [(0, (0, 0, 0), (0, 0, 0)), (1.0, (0, 0, 0), (0, 0, -0.02)), (2.0, (0, 0, 0), (0, 0, 0))],
        "cap": [(0, (2, 0, 3), None), (1.0, (-3, 0, -3), None), (2.0, (2, 0, 3), None)],
        "arm_l": [(0, (4, 0, 0), None), (1.0, (-4, 0, 0), None), (2.0, (4, 0, 0), None)],
        "arm_r": [(0, (-4, 0, 0), None), (1.0, (4, 0, 0), None), (2.0, (-4, 0, 0), None)]}
clip(rig, "Idle", 2.0, idle)
clip(rig, "Walk", 0.9, walk(0.9, 24, 18, 0.03, 5))
clip(rig, "Run", 0.5, walk(0.5, 34, 28, 0.05, 6))

# Attack: rears back, cap tipped, then lurches forward and slams its cap down.
clip(rig, "Attack", 0.8, {
    "hips": [(0, (0, 0, 0), (0, 0, 0)), (0.3, (-8, 0, 0), (0, 0.05, -0.03)), (0.5, (14, 0, 0), (0, -0.14, -0.05)), (0.8, (0, 0, 0), (0, 0, 0))],
    "spine_01": [(0, (0, 0, 0), None), (0.3, (-6, 0, 0), None), (0.5, (10, 0, 0), None), (0.8, (0, 0, 0), None)],
    "cap": [(0, (0, 0, 0), None), (0.3, (-12, 0, 0), None), (0.5, (22, 0, 0), None), (0.8, (0, 0, 0), None)],
    "arm_l": [(0, (0, 0, 0), None), (0.3, (-30, -20, 0), None), (0.5, (50, 0, 0), None), (0.8, (0, 0, 0), None)],
    "arm_r": [(0, (0, 0, 0), None), (0.3, (-30, 20, 0), None), (0.5, (50, 0, 0), None), (0.8, (0, 0, 0), None)]}, loop=False)
clip(rig, "Hit", 0.4, {
    "hips": [(0, (0, 0, 0), (0, 0, 0)), (0.1, (-14, 0, 6), (0, 0.1, -0.03)), (0.4, (0, 0, 0), (0, 0, 0))],
    "cap": [(0, (0, 0, 0), None), (0.1, (-20, 0, -10), None), (0.4, (0, 0, 0), None)],
    "arm_l": [(0, (0, 0, 0), None), (0.1, (-40, -30, 0), None), (0.4, (0, 0, 0), None)],
    "arm_r": [(0, (0, 0, 0), None), (0.1, (-40, 30, 0), None), (0.4, (0, 0, 0), None)]}, loop=False)
# Die: knees buckle, it keels over backward and the cap flops loose.
clip(rig, "Die", 1.1, {
    "hips": [(0, (0, 0, 0), (0, 0, 0)), (0.3, (-10, 0, 0), (0, 0.04, -0.1)), (0.8, (-78, 0, 0), (0, 0.34, -0.2)), (1.1, (-84, 0, 0), (0, 0.36, -0.21))],
    "cap": [(0, (0, 0, 0), None), (0.5, (14, 0, 6), None), (0.8, (-12, 0, 10), None), (1.1, (-6, 0, 12), None)],
    "thigh_l": [(0, (0, 0, 0), None), (0.5, (40, 0, 0), None), (1.1, (30, 0, 0), None)],
    "thigh_r": [(0, (0, 0, 0), None), (0.5, (30, 0, 0), None), (1.1, (45, 0, 0), None)],
    "shin_l": [(0, (0, 0, 0), None), (0.5, (50, 0, 0), None), (1.1, (40, 0, 0), None)],
    "shin_r": [(0, (0, 0, 0), None), (0.5, (40, 0, 0), None), (1.1, (60, 0, 0), None)],
    "arm_l": [(0, (0, 0, 0), None), (0.8, (-70, -40, 0), None), (1.1, (-80, -50, 0), None)],
    "arm_r": [(0, (0, 0, 0), None), (0.8, (-70, 40, 0), None), (1.1, (-80, 50, 0), None)]}, loop=False)

export(rig, body, OUT + "sporecap_src.glb")
os.remove(OUT + "sporecap_tex.png")
