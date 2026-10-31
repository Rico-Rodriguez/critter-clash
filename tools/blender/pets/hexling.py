# Hexling: a small cultist with a smaller staff, at grown proportions (no
# chibi), made from code. A violet robe under a tall pointed hood, a pale
# carved mask with a hex sign over narrow eye slits, talismans on a cord belt,
# and a crooked staff whose claw-top holds a violet orb.
# Writes assets/sidekicks/lich_src.glb.
# Run: <blender python> tools/blender/pets/hexling.py -- <repo root>
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *
from biped import skeleton, stride, bob

ROOT = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(ROOT, "assets/sidekicks/")
reset()

ROBE = mat("hx_robe", "33204d")
DEEP = mat("hx_deep", "1d1230")
LIGHT = mat("hx_light", "452a63")
MASK = mat("hx_mask", "b8ae98")
SIGIL = mat("hx_sigil", "9a55e0")
VOID = mat("hx_void", "0c0812", 1.0)
EYE = mat("hx_eye", "c6a6f0")
WOOD = mat("hx_wood", "30231a")
ORB = mat("hx_orb", "9a55e0", 0.35)
CORD = mat("hx_cord", "8a7550")
SKIN = mat("hx_skin", "6a5e75")
LEATHER = mat("hx_leather", "241b1e")

# The staff has its own bone, so a bred pet's sleeves take the donor's colours
# while the staff keeps its own.
rig = armature(skeleton([("staff", (-0.29, -0.13, 0.7), (-0.29, -0.13, 1.2), "hand_r")]))

# Robe to the shins, open below so the boots show as it walks.
robe = tube("robe", [((0, 0.0, 0.24), 0.25, 0.23), ((0, 0.0, 0.5), 0.22, 0.2), ((0, 0, 0.8), 0.18, 0.15),
                     ((0, -0.01, 1.02), 0.2, 0.16), ((0, -0.02, 1.18), 0.18, 0.14), ((0, -0.03, 1.27), 0.09, 0.08)],
            ROBE, n=12, cap0=False)
two_tone(robe, DEEP, LIGHT, down=-0.5, up=0.8)
bind(robe, ["hips", "spine_01", "chest", "thigh_l", "thigh_r"])
bind(blob("mantle", (0, -0.02, 1.19), (0.44, 0.34, 0.09), DEEP), ["chest"])
# Hem trim and a front panel with a hex sign.
hem = [((math.cos(a) * 0.25, math.sin(a) * 0.23, 0.25), 0.014, 0.014) for a in [i * math.pi * 2 / 20 for i in range(21)]]
bind(tube("hem", hem, SIGIL, n=4, sub=0), ["thigh_l", "thigh_r", "hips"])
bind(sheet("panel", [(0, -0.16, 0.78), (0.06, -0.17, 0.76), (0.07, -0.22, 0.4), (0, -0.235, 0.32), (-0.07, -0.22, 0.4), (-0.06, -0.17, 0.76)],
           DEEP, 0.01), ["hips", "thigh_l", "thigh_r"])
# Cord belt with three talismans: bone, a violet bead, a small hex disc.
belt = [((math.cos(a) * 0.185, math.sin(a) * 0.155, 0.8), 0.014, 0.014) for a in [i * math.pi * 2 / 16 for i in range(17)]]
bind(tube("belt", belt, CORD, n=5, sub=0), ["hips"])
for k, (x, y, m) in enumerate([(0.15, -0.1, MASK), (0.1, -0.14, ORB), (0.17, -0.04, SIGIL)]):
    bind(tube("tcord%d" % k, [((x, y, 0.79), 0.006, 0.006), ((x, y - 0.01, 0.7 - k * 0.02), 0.006, 0.006)], CORD, n=4, sub=0), ["hips"])
    bind(blob("talisman%d" % k, (x, y - 0.01, 0.67 - k * 0.02), (0.035, 0.02, 0.05), m, sub=1), ["hips"])

# Legs: dark leggings and soft boots.
for s, x in (("l", 1), ("r", -1)):
    bind(tube("leg_" + s, [((x * 0.1, 0, 0.6), 0.06, 0.06), ((x * 0.11, 0, 0.34), 0.048, 0.048), ((x * 0.11, 0.02, 0.1), 0.044, 0.044)],
              LEATHER, n=8), ["thigh_" + s, "shin_" + s])
    bind(blob("boot_" + s, (x * 0.11, -0.04, 0.05), (0.1, 0.2, 0.1), DEEP), ["foot_" + s])

# Hood: a tall cowl, its point bent back, open on a carved mask.
bind(tube("cowl", [((0, 0.08, 1.45), 0.1, 0.11), ((0, -0.02, 1.46), 0.17, 0.19), ((0, -0.13, 1.46), 0.16, 0.18),
                   ((0, -0.2, 1.45), 0.135, 0.155)], ROBE, n=14, cap1=False), ["head"])
bind(tube("lip", [((0, -0.18, 1.45), 0.14, 0.16), ((0, -0.22, 1.45), 0.13, 0.15)], DEEP, n=14, cap0=False, cap1=False), ["head"])
bind(cone("point", (0, -0.02, 1.58), (0, 0.16, 1.86), 0.13, ROBE, n=8, bend=(0, -0.04, 0.06)), ["head"])
bind(blob("shadow", (0, -0.15, 1.45), (0.26, 0.04, 0.3), VOID), ["head"])
bind(blob("mask", (0, -0.18, 1.44), (0.19, 0.06, 0.24), MASK), ["head"])
for x in (1, -1):
    bind(blob("slit", (x * 0.048, -0.208, 1.47), (0.06, 0.02, 0.022), VOID, sub=1, rot=(0, x * 0.2, 0)), ["head"])
    bind(blob("eye", (x * 0.048, -0.215, 1.47), (0.022, 0.01, 0.012), EYE, sub=0), ["head"])
# The hex sign: a ring and a stroke on the mask's brow.
ring = [((math.cos(a) * 0.03, -0.212, 1.53 + math.sin(a) * 0.03), 0.006, 0.006) for a in [i * math.pi * 2 / 12 for i in range(13)]]
bind(tube("sign", ring, SIGIL, n=4, sub=0), ["head"])
bind(tube("stroke", [((0, -0.214, 1.56), 0.006, 0.006), ((0, -0.214, 1.37), 0.006, 0.006)], SIGIL, n=4, sub=0), ["head"])

# Sleeves and thin grey hands.
for s, x in (("l", 1), ("r", -1)):
    P = lambda v: (x * v[0], v[1], v[2])
    bind(tube("sleeve_" + s, [(P((0.19, -0.02, 1.18)), 0.07, 0.07), (P((0.26, -0.02, 0.94)), 0.065, 0.065),
                              (P((0.28, -0.09, 0.78)), 0.088, 0.088)], ROBE, n=8, cap1=False), ["upperarm_" + s, "forearm_" + s])
    bind(blob("hand_" + s, P((0.285, -0.12, 0.72)), (0.07, 0.08, 0.09), SKIN, sub=1), ["hand_" + s])

# The staff: crooked blackwood, three claws around a violet orb.
bind(tube("shaft", [((-0.29, -0.13, 0.08), 0.022, 0.022), ((-0.3, -0.13, 0.5), 0.026, 0.026), ((-0.285, -0.14, 0.95), 0.026, 0.026),
                    ((-0.29, -0.13, 1.22), 0.03, 0.03)], WOOD, n=7), ["staff"])
for k in range(3):
    a = k * math.pi * 2 / 3
    dx, dy = math.cos(a) * 0.06, math.sin(a) * 0.06
    bind(cone("claw%d" % k, (-0.29 + dx * 0.5, -0.13 + dy * 0.5, 1.22), (-0.29 + dx * 0.6, -0.13 + dy * 0.6, 1.4), 0.022, WOOD, n=5,
              bend=(dx, dy, 0.0)), ["staff"])
bind(blob("orb", (-0.29, -0.13, 1.31), (0.11, 0.11, 0.11), ORB, sub=2), ["staff"])

hx = skin(rig, "Hexling")
bake(hx, 1024, OUT + "lich_tex.png")

# Clips.
idle = {"chest": [(0, (0, 0, 0), None), (1.0, (3, 0, 0), None), (2.0, (0, 0, 0), None)]}
idle["head"] = [(0, (0, 0, -5), None), (1.0, (4, 6, 5), None), (2.0, (0, 0, -5), None)]
idle["upperarm_l"] = [(0, (-10, 0, 0), None), (1.0, (-14, 4, 0), None), (2.0, (-10, 0, 0), None)]
idle["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (1.0, (0, 0, 0), (0, 0, -0.01)), (2.0, (0, 0, 0), (0, 0, 0))]
clip(rig, "Idle", 2.0, idle)

walk = stride(0.85, 24, 40, 14)
walk.pop("upperarm_r")  # the staff hand stays steady
walk["hips"] = bob(0.85)
walk["chest"] = [(0, (6, 0, -4), None), (0.425, (6, 0, 4), None), (0.85, (6, 0, -4), None)]
clip(rig, "Walk", 0.85, walk)

run = stride(0.55, 36, 70, 26)
run["upperarm_r"] = [(0, (-20, 0, 0), None), (0.55, (-20, 0, 0), None)]
run["hips"] = bob(0.55, tilt=6, lift=0.04, lean=14)
clip(rig, "Run", 0.55, run)

# Hex: the staff thrust forward, the free hand flung out after it.
atk = {"upperarm_r": [(0, (0, 0, 0), None), (0.25, (-30, 0, -20), None), (0.4, (-80, 0, 10), None), (0.75, (0, 0, 0), None)]}
atk["forearm_r"] = [(0, (0, 0, 0), None), (0.25, (-40, 0, 0), None), (0.4, (0, 0, 0), None), (0.75, (0, 0, 0), None)]
atk["upperarm_l"] = [(0, (0, 0, 0), None), (0.25, (10, 20, 0), None), (0.42, (-70, -20, 0), None), (0.75, (0, 0, 0), None)]
atk["chest"] = [(0, (0, 0, 0), None), (0.25, (-6, 0, -14), None), (0.4, (10, 0, 12), None), (0.75, (0, 0, 0), None)]
clip(rig, "Attack", 0.75, atk, loop=False)

hit = {"hips": [(0, (0, 0, 0), (0, 0, 0)), (0.12, (-12, 0, 8), (0, 0.06, 0)), (0.45, (0, 0, 0), (0, 0, 0))]}
hit["head"] = [(0, (0, 0, 0), None), (0.12, (-16, 0, 0), None), (0.45, (0, 0, 0), None)]
clip(rig, "Hit", 0.45, hit, loop=False)

# Special: the staff raised high, the other hand spread, head back.
sp = {"upperarm_r": [(0, (0, 0, 0), None), (0.4, (-150, 0, 0), None), (0.9, (-150, 0, 0), None), (1.2, (0, 0, 0), None)]}
sp["upperarm_l"] = [(0, (0, 0, 0), None), (0.4, (-30, -60, 0), None), (0.9, (-30, -60, 0), None), (1.2, (0, 0, 0), None)]
sp["head"] = [(0, (0, 0, 0), None), (0.4, (-20, 0, 0), None), (0.9, (-20, 0, 0), None), (1.2, (0, 0, 0), None)]
sp["chest"] = [(0, (0, 0, 0), None), (0.4, (-8, 0, 0), None), (0.9, (-8, 0, 0), None), (1.2, (0, 0, 0), None)]
clip(rig, "Special", 1.2, sp, loop=False)

export(rig, hx, OUT + "lich_src.glb")
os.remove(OUT + "lich_tex.png")
