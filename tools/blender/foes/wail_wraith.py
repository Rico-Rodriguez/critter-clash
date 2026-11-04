# Wail Wraith (Rimehollow): a gaunt banshee floating on a ragged tail of frost-grey
# robe, hair streaming behind, mouth open mid-scream, long clawed hands.
# Writes assets/foes/wail_wraith_src.glb (wrap with tools/art/wrap_foes.gd).
# Run: python3 tools/blender/foes/wail_wraith.py -- <repo root>
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "../pets"))
from common import *
import common

ROOT = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(ROOT, "assets/foes/")
reset()
common.SIDES, common.BLOB_SUB = 1.0, 0

ROBE = mat("wr_robe", "3b4858")
DEEP = mat("wr_deep", "1b232d")
LIGHT = mat("wr_light", "5a7288")
FACE = mat("wr_face", "9db4c3")
VOID = mat("wr_void", "05080c", 1.0)
EYE = mat("wr_eye", "c4f0ff")
HAIR = mat("wr_hair", "8aa0b2")
ICE = mat("wr_ice", "7fc4e0")
CLAW = mat("wr_claw", "d3e4ec")
IRON = mat("wr_iron", "262a31")

S = [
    ("hips", (0, 0, 0.95), (0, 0, 1.15), None),
    ("spine_01", (0, 0, 1.15), (0, 0, 1.4), "hips"),
    ("chest", (0, 0, 1.4), (0, -0.02, 1.55), "spine_01"),
    ("neck_01", (0, -0.02, 1.55), (0, -0.04, 1.66), "chest"),
    ("head", (0, -0.04, 1.66), (0, -0.06, 1.95), "neck_01"),
    ("jaw", (0, -0.14, 1.76), (0, -0.2, 1.7), "head"),
    ("hair_01", (0, 0.1, 1.9), (0, 0.3, 1.74), "head"),
    ("hair_02", (0, 0.3, 1.74), (0, 0.5, 1.45), "hair_01"),
    ("tail_01", (0, 0, 0.95), (0, 0.05, 0.7), "hips"),
    ("tail_02", (0, 0.05, 0.7), (0, 0.14, 0.45), "tail_01"),
    ("tail_03", (0, 0.14, 0.45), (0, 0.4, 0.05), "tail_02"),
]
for s, x in (("l", 1), ("r", -1)):
    S += [
        ("upperarm_" + s, (x * 0.22, 0, 1.5), (x * 0.4, -0.04, 1.2), "chest"),
        ("forearm_" + s, (x * 0.4, -0.04, 1.2), (x * 0.5, -0.2, 0.95), "upperarm_" + s),
        ("hand_" + s, (x * 0.5, -0.2, 0.95), (x * 0.54, -0.3, 0.8), "forearm_" + s),
    ]
rig = armature(S)

# Robe: shoulders to a hem that thins to a tail; frayed strips below the waist.
robe = tube("robe", [((0, 0.5, -0.05), 0.012, 0.012), ((0, 0.32, 0.22), 0.07, 0.06), ((0, 0.2, 0.46), 0.12, 0.1), ((0, 0.08, 0.72), 0.2, 0.16),
                     ((0, 0, 0.95), 0.22, 0.17), ((0, 0, 1.2), 0.2, 0.15), ((0, 0, 1.42), 0.27, 0.18),
                     ((0, -0.01, 1.54), 0.14, 0.11)], ROBE, n=12)
two_tone(robe, DEEP, LIGHT, down=-0.4, up=0.7)
bind(robe, ["hips", "spine_01", "chest", "tail_01", "tail_02", "tail_03"])
for k in range(7):
    a = math.pi * (0.1 + k * 0.13)
    x, y = math.cos(a) * 0.22, math.sin(a) * 0.17 + 0.02
    bind(cone("rag_%d" % k, (x, y, 0.9), (x * 1.1, y + 0.1, 0.9 - 0.3 - (k % 3) * 0.1), 0.07, DEEP if k % 2 else ROBE, n=3),
         ["tail_01", "tail_02"])
# Rusted iron chain round the waist, a broken shackle hanging from it.
ring = [((math.cos(a) * 0.225, math.sin(a) * 0.175, 1.0), 0.012, 0.012) for a in [i * math.pi * 2 / 12 for i in range(13)]]
bind(tube("chain", ring, IRON, n=4), ["hips"])
bind(cone("shackle", (0.2, -0.1, 1.0), (0.24, -0.12, 0.72), 0.03, IRON, n=4), ["hips"])
# Ice shards growing from the shoulders.
for x in (1, -1):
    bind(cone("shard_a%d" % x, (x * 0.24, 0.02, 1.46), (x * 0.4, 0.05, 1.78), 0.06, ICE, n=4, bend=(x * 0.03, 0, 0)), ["chest"])
    bind(cone("shard_b%d" % x, (x * 0.2, 0.06, 1.44), (x * 0.26, 0.2, 1.7), 0.04, ICE, n=4), ["chest"])

# Head: a hollow-eyed face, jaw hanging open, a crown of icicles, long hair behind.
bind(tube("neck", [((0, -0.03, 1.5), 0.06, 0.06), ((0, -0.04, 1.68), 0.05, 0.05)], FACE, n=6), ["chest", "neck_01", "head"])
bind(tube("skull", [((0, -0.05, 1.67), 0.05, 0.06), ((0, -0.05, 1.74), 0.1, 0.12), ((0, -0.05, 1.84), 0.125, 0.14), ((0, -0.05, 1.95), 0.105, 0.12),
                    ((0, -0.05, 2.03), 0.05, 0.06)], FACE, n=8), ["head"])
bind(blob("brow", (0, -0.16, 1.9), (0.24, 0.08, 0.05), DEEP, rot=(0.2, 0, 0)), ["head"])
bind(blob("jaw", (0, -0.15, 1.73), (0.15, 0.17, 0.06), FACE, rot=(0.15, 0, 0)), ["jaw"])
bind(blob("maw", (0, -0.2, 1.77), (0.13, 0.04, 0.09), VOID), ["head"])
bind(blob("maw2", (0, -0.2, 1.72), (0.11, 0.04, 0.06), VOID), ["jaw"])
for x in (1, -1):
    bind(blob("socket%d" % x, (x * 0.07, -0.17, 1.86), (0.08, 0.04, 0.09), VOID, rot=(0, 0, x * 0.3)), ["head"])
    bind(blob("eye%d" % x, (x * 0.07, -0.195, 1.855), (0.03, 0.015, 0.045), EYE), ["head"])
for k in range(5):
    a = (k - 2) * 0.5
    bind(cone("crown%d" % k, (math.sin(a) * 0.12, -0.02 - math.cos(a) * 0.05, 1.98), (math.sin(a) * 0.2, -0.04 - math.cos(a) * 0.04, 2.14 + (2 - abs(k - 2)) * 0.05),
              0.03, ICE, n=3), ["head"])
for k, x in enumerate((-0.12, -0.04, 0.04, 0.12)):
    bind(tube("hair%d" % k, [((x, 0.08, 1.94), 0.05, 0.05), ((x * 1.5, 0.28, 1.74), 0.04, 0.04), ((x * 2.2, 0.5, 1.46), 0.03, 0.03),
                              ((x * 2.6, 0.62, 1.12 - abs(x) * 0.8), 0.006, 0.006)], HAIR if k % 2 else LIGHT, n=4),
         ["head", "hair_01", "hair_02"])

# Arms: ragged sleeves, bony forearms, hands with long claws.
for s, x in (("l", 1), ("r", -1)):
    P = lambda v: (x * v[0], v[1], v[2])
    bind(tube("sleeve_" + s, [(P((0.2, 0, 1.5)), 0.08, 0.08), (P((0.4, -0.04, 1.2)), 0.07, 0.07), (P((0.5, -0.2, 0.95)), 0.1, 0.1)],
              ROBE, n=6, cap1=False), ["chest", "upperarm_" + s, "forearm_" + s])
    bind(tube("arm_" + s, [(P((0.5, -0.2, 0.97)), 0.025, 0.025), (P((0.53, -0.28, 0.84)), 0.02, 0.02)], FACE, n=4), ["forearm_" + s, "hand_" + s])
    bind(blob("palm_" + s, P((0.54, -0.3, 0.78)), (0.06, 0.08, 0.07), FACE), ["hand_" + s])
    for k in range(4):
        dx = (k - 1.5) * 0.028
        bind(cone("claw_%s%d" % (s, k), P((0.54 + dx, -0.33, 0.76)), P((0.55 + dx * 1.4, -0.45, 0.5 - (1 if k in (1, 2) else 0) * 0.06)),
                  0.014, CLAW, n=3), ["hand_" + s])

wr = skin(rig, "Wraith")
bake(wr, 512, OUT + "wail_wraith_tex.png")


def drift(period, a, keys):
    for i, bn in enumerate(["tail_01", "tail_02", "tail_03"]):
        keys.setdefault(bn, [(0, (a * 0.3, 0, a * (1 + i * 0.5)), None), (period / 2, (a * 0.3, 0, -a * (1 + i * 0.5)), None),
                             (period, (a * 0.3, 0, a * (1 + i * 0.5)), None)])
    for i, bn in enumerate(["hair_01", "hair_02"]):
        keys.setdefault(bn, [(0, (a * 0.8, 0, -a * (1 + i)), None), (period / 2, (-a * 0.5, 0, a * (1 + i)), None),
                             (period, (a * 0.8, 0, -a * (1 + i)), None)])
    return keys


def arms(period, sway, fwd=0):
    ks = {}
    for s, sg in (("l", 1), ("r", -1)):
        ks["upperarm_" + s] = [(0, (fwd, sg * (sway + 8), 0), None), (period / 2, (fwd - 8, sg * (8 - sway * 0.5), 0), None), (period, (fwd, sg * (sway + 8), 0), None)]
        ks["forearm_" + s] = [(0, (-10, 0, 0), None), (period / 2, (-18, 0, 0), None), (period, (-10, 0, 0), None)]
    return ks


idle = drift(2.4, 7, arms(2.4, 5))
idle["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (1.2, (2, 0, 0), (0, 0, 0.08)), (2.4, (0, 0, 0), (0, 0, 0))]
idle["head"] = [(0, (0, 0, -6), None), (1.2, (4, 0, 6), None), (2.4, (0, 0, -6), None)]
idle["jaw"] = [(0, (8, 0, 0), None), (1.2, (18, 0, 0), None), (2.4, (8, 0, 0), None)]
clip(rig, "Idle", 2.4, idle)

walk = drift(1.0, 10, arms(1.0, 8, 22))
walk["hips"] = [(0, (14, 0, 0), (0, 0, 0)), (0.5, (14, 0, 0), (0, 0, 0.05)), (1.0, (14, 0, 0), (0, 0, 0))]
walk["tail_01"] = [(0, (-22, 0, 6), None), (0.5, (-22, 0, -6), None), (1.0, (-22, 0, 6), None)]
clip(rig, "Walk", 1.0, walk)

run = drift(0.6, 12, arms(0.6, 6, 40))
run["hips"] = [(0, (26, 0, 0), (0, 0, 0)), (0.3, (26, 0, 0), (0, 0, 0.06)), (0.6, (26, 0, 0), (0, 0, 0))]
run["tail_01"] = [(0, (-34, 0, 8), None), (0.3, (-34, 0, -8), None), (0.6, (-34, 0, 8), None)]
clip(rig, "Run", 0.6, run)

# Attack: the wail. Head thrown back, jaw wide, arms flung out and forward.
atk = drift(0.9, 8, {})
atk["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.3, (-14, 0, 0), (0, 0.12, 0.06)), (0.5, (10, 0, 0), (0, -0.2, 0)), (0.9, (0, 0, 0), (0, 0, 0))]
atk["head"] = [(0, (0, 0, 0), None), (0.3, (-26, 0, 0), None), (0.5, (8, 0, 0), None), (0.9, (0, 0, 0), None)]
atk["jaw"] = [(0, (0, 0, 0), None), (0.3, (34, 0, 0), None), (0.7, (34, 0, 0), None), (0.9, (0, 0, 0), None)]
for s, sg in (("l", 1), ("r", -1)):
    atk["upperarm_" + s] = [(0, (0, 0, 0), None), (0.3, (-40, -sg * 60, 0), None), (0.5, (-95, -sg * 20, 0), None), (0.9, (0, 0, 0), None)]
    atk["forearm_" + s] = [(0, (0, 0, 0), None), (0.3, (-20, 0, 0), None), (0.5, (0, 0, 0), None), (0.9, (0, 0, 0), None)]
clip(rig, "Attack", 0.9, atk, loop=False)

# Cast: it rises and spreads its arms, hair lifting.
cast = drift(1.1, 5, {})
cast["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.4, (-8, 0, 0), (0, 0, 0.2)), (0.8, (-8, 0, 0), (0, 0, 0.2)), (1.1, (0, 0, 0), (0, 0, 0))]
for s, sg in (("l", 1), ("r", -1)):
    cast["upperarm_" + s] = [(0, (0, 0, 0), None), (0.4, (-30, -sg * 80, 0), None), (0.8, (-30, -sg * 80, 0), None), (1.1, (0, 0, 0), None)]
    cast["forearm_" + s] = [(0, (0, 0, 0), None), (0.4, (-20, -sg * 20, 0), None), (0.8, (-20, -sg * 20, 0), None), (1.1, (0, 0, 0), None)]
cast["head"] = [(0, (0, 0, 0), None), (0.4, (-20, 0, 0), None), (0.8, (-20, 0, 0), None), (1.1, (0, 0, 0), None)]
cast["jaw"] = [(0, (0, 0, 0), None), (0.4, (30, 0, 0), None), (0.8, (30, 0, 0), None), (1.1, (0, 0, 0), None)]
clip(rig, "Cast", 1.1, cast, loop=False)

hit = drift(0.45, 8, {})
hit["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.12, (-20, 0, 10), (0, 0.14, 0.04)), (0.45, (0, 0, 0), (0, 0, 0))]
hit["head"] = [(0, (0, 0, 0), None), (0.12, (-22, 0, 0), None), (0.45, (0, 0, 0), None)]
hit["jaw"] = [(0, (0, 0, 0), None), (0.12, (30, 0, 0), None), (0.45, (0, 0, 0), None)]
for s, sg in (("l", 1), ("r", -1)):
    hit["upperarm_" + s] = [(0, (0, 0, 0), None), (0.12, (-30, -sg * 40, 0), None), (0.45, (0, 0, 0), None)]
clip(rig, "Hit", 0.45, hit, loop=False)

# Die: it throws its head back in a last wail, falls backward and sinks.
die = drift(1.2, 6, {})
die["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.3, (-10, 0, 0), (0, 0.1, 0.08)), (0.9, (-80, 0, 0), (0, 0.5, -0.35)), (1.3, (-90, 0, 0), (0, 0.6, -0.6))]
die["head"] = [(0, (0, 0, 0), None), (0.3, (-30, 0, 0), None), (1.3, (-20, 0, 0), None)]
die["jaw"] = [(0, (0, 0, 0), None), (0.3, (36, 0, 0), None), (1.3, (30, 0, 0), None)]
for s, sg in (("l", 1), ("r", -1)):
    die["upperarm_" + s] = [(0, (0, 0, 0), None), (0.3, (-50, -sg * 70, 0), None), (1.3, (-30, -sg * 40, 0), None)]
clip(rig, "Die", 1.3, die, loop=False)

export(rig, wr, OUT + "wail_wraith_src.glb")
os.remove(OUT + "wail_wraith_tex.png")
