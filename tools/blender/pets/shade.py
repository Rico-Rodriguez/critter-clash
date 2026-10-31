# Hexbound Shade: a tall hooded wraith with no legs, its robe thinning into a
# ragged tail of shadow, long sleeves over pale clawed hands, a void under the
# hood with two pale eyes, and the silver thread of the Hexer Queen's spindle
# bound round its waist, the spindle dangling at its side.
# Writes assets/sidekicks/wraith_src.glb.
# Run: <blender python> tools/blender/pets/shade.py -- <repo root>
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *

ROOT = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(ROOT, "assets/sidekicks/")
reset()

ROBE = mat("shade_robe", "221c30")
DEEP = mat("shade_deep", "1a1526")
LIGHT = mat("shade_light", "342b4a")
VOID = mat("shade_void", "06040a", 1.0)
EYE = mat("shade_eye", "c8bcf0")
HAND = mat("shade_hand", "6a6380")
SILVER = mat("shade_silver", "8d89a3", 0.4)
WOOD = mat("shade_wood", "3b2a20")

# Skeleton (Blender: -Y forward, Z up). It floats: the tail tip clears the ground.
S = [
    ("hips", (0, 0, 0.85), (0, 0, 1.05), None),
    ("spine_01", (0, 0, 1.05), (0, 0, 1.3), "hips"),
    ("neck_01", (0, 0, 1.3), (0, -0.02, 1.42), "spine_01"),
    ("head", (0, -0.02, 1.42), (0, -0.02, 1.74), "neck_01"),
    ("tail_01", (0, 0, 0.85), (0, 0.04, 0.62), "hips"),
    ("tail_02", (0, 0.04, 0.62), (0, 0.12, 0.4), "tail_01"),
    ("tail_03", (0, 0.12, 0.4), (0, 0.24, 0.2), "tail_02"),
    ("spindle", (0.24, 0.1, 0.92), (0.28, 0.16, 0.66), "hips"),
]
for s, x in (("l", 1), ("r", -1)):
    S += [
        ("upperarm_" + s, (x * 0.2, 0, 1.28), (x * 0.36, -0.02, 1.02), "spine_01"),
        ("forearm_" + s, (x * 0.36, -0.02, 1.02), (x * 0.44, -0.1, 0.8), "upperarm_" + s),
        ("hand_" + s, (x * 0.44, -0.1, 0.8), (x * 0.48, -0.17, 0.64), "forearm_" + s),
    ]
rig = armature(S)

# Robe: broad at the shoulders, narrowing down into a tail of shadow.
robe = tube("robe", [((0, 0.26, 0.16), 0.015, 0.015), ((0, 0.14, 0.38), 0.09, 0.08), ((0, 0.05, 0.6), 0.18, 0.15),
                     ((0, 0, 0.85), 0.2, 0.16), ((0, 0, 1.05), 0.19, 0.15), ((0, 0, 1.24), 0.26, 0.18),
                     ((0, 0, 1.36), 0.15, 0.12)], ROBE, n=12)
two_tone(robe, DEEP, LIGHT, down=-0.4, up=0.75)
bind(robe, ["hips", "spine_01", "tail_01", "tail_02", "tail_03"])
# Ragged strips hanging from the hem, each its own length.
for k in range(9):
    a = math.pi * (0.15 + k * 0.2)
    x, y = math.cos(a) * 0.2, math.sin(a) * 0.15 + 0.02
    ln = 0.22 + (k % 3) * 0.07
    bind(cone("rag_%d" % k, (x, y, 0.78), (x * 1.15, y + 0.08, 0.78 - ln), 0.065, DEEP if k % 2 else ROBE, n=4),
         ["tail_01", "tail_02"])
bind(blob("mantle", (0, 0.01, 1.31), (0.32, 0.22, 0.07), DEEP), ["spine_01"])

# Hood: a cowl open at the front onto a void just inside its lip, two pale
# eyes, with a point falling back from its crown.
bind(tube("cowl", [((0, 0.16, 1.47), 0.1, 0.12), ((0, 0.06, 1.48), 0.2, 0.21), ((0, -0.08, 1.49), 0.2, 0.21),
                   ((0, -0.19, 1.48), 0.165, 0.18)], ROBE, n=14, cap1=False), ["head"])
bind(tube("lip", [((0, -0.17, 1.48), 0.17, 0.185), ((0, -0.21, 1.48), 0.16, 0.175)], DEEP, n=14, cap0=False, cap1=False), ["head"])
bind(cone("point", (0, 0.04, 1.6), (0, 0.24, 1.78), 0.13, ROBE, n=8), ["head"])
bind(blob("void", (0, -0.13, 1.48), (0.33, 0.06, 0.36), VOID), ["head"])
for x in (1, -1):
    bind(blob("eye", (x * 0.065, -0.17, 1.5), (0.07, 0.03, 0.038), EYE, sub=1, rot=(0, x * 0.25, 0)), ["head"])

# Sleeves flaring at the cuff, thin pale hands with long claws.
for s, x in (("l", 1), ("r", -1)):
    P = lambda v: (x * v[0], v[1], v[2])
    bind(tube("sleeve_" + s, [(P((0.18, 0, 1.3)), 0.075, 0.075), (P((0.36, -0.02, 1.02)), 0.07, 0.07),
                              (P((0.43, -0.09, 0.82)), 0.1, 0.1)], ROBE, n=8, cap1=False),
         ["upperarm_" + s, "forearm_" + s])
    bind(blob("palm_" + s, P((0.44, -0.1, 0.79)), (0.045, 0.05, 0.06), HAND, sub=1), ["hand_" + s])
    for k, (dx, dy) in enumerate([(-0.03, -0.03), (0.0, -0.05), (0.03, -0.03)]):
        bind(cone("claw_%s%d" % (s, k), P((0.45 + dx, -0.12 + dy * 0.5, 0.76)), P((0.47 + dx * 1.6, -0.16 + dy, 0.63)), 0.016, HAND, n=4),
             ["hand_" + s])

# The Queen's thread: a silver band round the waist, a strand down to her spindle.
band = [((math.cos(a) * 0.205, math.sin(a) * 0.165, 0.95 + 0.02 * math.sin(a * 2)), 0.008, 0.008)
        for a in [i * math.pi * 2 / 16 for i in range(17)]]
bind(tube("band", band, SILVER, n=6, sub=0), ["hips"])
bind(tube("strand", [((0.22, 0.1, 0.94), 0.008, 0.008), ((0.26, 0.14, 0.8), 0.008, 0.008), ((0.28, 0.16, 0.7), 0.008, 0.008)],
          SILVER, n=5, sub=0), ["spindle"])
bind(cone("spindle_up", (0.28, 0.16, 0.66), (0.28, 0.16, 0.74), 0.012, WOOD, n=6), ["spindle"])
bind(cone("spindle_dn", (0.28, 0.16, 0.6), (0.28, 0.16, 0.46), 0.014, WOOD, n=6), ["spindle"])
bind(blob("whorl", (0.28, 0.16, 0.61), (0.045, 0.045, 0.02), WOOD, sub=1), ["spindle"])
bind(blob("yarn", (0.28, 0.16, 0.65), (0.03, 0.03, 0.04), SILVER, sub=1), ["spindle"])

shade = skin(rig, "Shade")
bake(shade, 1024, OUT + "wraith_tex.png")


# Clips: +X pitches forward, -Y lifts the left arm (+Y the right), Z turns.
def drift(period, a, keys):
    for i, bn in enumerate(["tail_01", "tail_02", "tail_03"]):
        keys.setdefault(bn, [(0, (a * 0.3, 0, a * (1 + i * 0.5)), None), (period / 2, (a * 0.3, 0, -a * (1 + i * 0.5)), None),
                             (period, (a * 0.3, 0, a * (1 + i * 0.5)), None)])
    keys.setdefault("spindle", [(0, (6, 0, 0), None), (period / 2, (-6, 0, 0), None), (period, (6, 0, 0), None)])
    return keys

def arms(period, sway, fwd=0):
    ks = {}
    for s, sg in (("l", 1), ("r", -1)):
        # +Y lowers the left arm: the rest pose holds them out, the clips let them hang.
        low = sg * 28
        ks["upperarm_" + s] = [(0, (fwd, low + sg * sway, 0), None), (period / 2, (fwd - 6, low - sg * sway * 0.5, 0), None), (period, (fwd, low + sg * sway, 0), None)]
        ks["forearm_" + s] = [(0, (-8, 0, 0), None), (period / 2, (-14, 0, 0), None), (period, (-8, 0, 0), None)]
    return ks

idle = drift(2.4, 7, arms(2.4, 5))
idle["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (1.2, (2, 0, 0), (0, 0, 0.06)), (2.4, (0, 0, 0), (0, 0, 0))]
idle["head"] = [(0, (0, 0, -6), None), (1.2, (4, 0, 6), None), (2.4, (0, 0, -6), None)]
clip(rig, "Idle", 2.4, idle)

walk = drift(1.0, 10, arms(1.0, 8, 22))
walk["hips"] = [(0, (14, 0, 0), (0, 0, 0)), (0.5, (14, 0, 0), (0, 0, 0.04)), (1.0, (14, 0, 0), (0, 0, 0))]
walk["tail_01"] = [(0, (-22, 0, 6), None), (0.5, (-22, 0, -6), None), (1.0, (-22, 0, 6), None)]
walk["head"] = [(0, (-8, 0, 0), None), (1.0, (-8, 0, 0), None)]
clip(rig, "Walk", 1.0, walk)

run = drift(0.6, 12, arms(0.6, 6, 40))
run["hips"] = [(0, (26, 0, 0), (0, 0, 0)), (0.3, (26, 0, 0), (0, 0, 0.05)), (0.6, (26, 0, 0), (0, 0, 0))]
run["tail_01"] = [(0, (-34, 0, 8), None), (0.3, (-34, 0, -8), None), (0.6, (-34, 0, 8), None)]
run["head"] = [(0, (-16, 0, 0), None), (0.6, (-16, 0, 0), None)]
clip(rig, "Run", 0.6, run)

# Shadow Strike: draws the right claw back, then rakes it across.
atk = drift(0.7, 6, {})
atk["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.25, (-6, 0, 18), (0, 0.06, 0.04)), (0.42, (16, 0, -22), (0, -0.16, 0)), (0.7, (0, 0, 0), (0, 0, 0))]
atk["upperarm_r"] = [(0, (0, 0, 0), None), (0.25, (30, 50, 0), None), (0.42, (-70, 30, -40), None), (0.7, (0, 0, 0), None)]
atk["forearm_r"] = [(0, (0, 0, 0), None), (0.25, (-40, 0, 0), None), (0.42, (-10, 0, 0), None), (0.7, (0, 0, 0), None)]
atk["upperarm_l"] = [(0, (0, 0, 0), None), (0.42, (20, -20, 0), None), (0.7, (0, 0, 0), None)]
clip(rig, "Attack", 0.7, atk, loop=False)

hit = drift(0.45, 8, {})
hit["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.12, (-16, 0, 8), (0, 0.1, 0.04)), (0.45, (0, 0, 0), (0, 0, 0))]
hit["head"] = [(0, (0, 0, 0), None), (0.12, (-14, 0, 0), None), (0.45, (0, 0, 0), None)]
for s, sg in (("l", 1), ("r", -1)):
    hit["upperarm_" + s] = [(0, (0, 0, 0), None), (0.12, (20, -sg * 20, 0), None), (0.45, (0, 0, 0), None)]
clip(rig, "Hit", 0.45, hit, loop=False)

# Special: it rises, arms spread wide, and the robe streams out below.
sp = drift(1.2, 4, {})
sp["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.45, (-8, 0, 0), (0, 0, 0.18)), (0.9, (-8, 0, 0), (0, 0, 0.18)), (1.2, (0, 0, 0), (0, 0, 0))]
for s, sg in (("l", 1), ("r", -1)):
    sp["upperarm_" + s] = [(0, (0, 0, 0), None), (0.45, (-20, -sg * 70, 0), None), (0.9, (-20, -sg * 70, 0), None), (1.2, (0, 0, 0), None)]
    sp["forearm_" + s] = [(0, (0, 0, 0), None), (0.45, (0, -sg * 20, 0), None), (0.9, (0, -sg * 20, 0), None), (1.2, (0, 0, 0), None)]
sp["head"] = [(0, (0, 0, 0), None), (0.45, (-18, 0, 0), None), (0.9, (-18, 0, 0), None), (1.2, (0, 0, 0), None)]
clip(rig, "Special", 1.2, sp, loop=False)

export(rig, shade, OUT + "wraith_src.glb")
os.remove(OUT + "wraith_tex.png")
