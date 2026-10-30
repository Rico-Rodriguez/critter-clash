# Plague Acolyte: the Thornmother's small cultist, at grown proportions (a
# head about a fifth of its height). A moss-green robe and deep hood, a carved
# bark beak-mask with round amber lenses, a mantle wound with a thorny vine
# and one rose, a rope belt hung with herbs, and a briar crook with a seed
# censer swinging from its hook. Writes assets/sidekicks/plague_src.glb.
# Run: <blender python> tools/blender/pets/acolyte.py -- <repo root>
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *

ROOT = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(ROOT, "assets/sidekicks/")
reset()

ROBE = mat("aco_robe", "4f6b34")
DEEP = mat("aco_deep", "324a22")
LIGHT = mat("aco_light", "6f8c46")
BARK = mat("aco_bark", "7a5636")
BARK_D = mat("aco_bark_d", "4e3523")
LENS = mat("aco_lens", "f0b440", 0.3)
LEATHER = mat("aco_leather", "3b2f25")
ROPE = mat("aco_rope", "b39a6a")
THORN = mat("aco_thorn", "d8c9a0")
LEAF = mat("aco_leaf", "6aa83a")
ROSE = mat("aco_rose", "c8455a")
VOID = mat("aco_void", "120d08", 1.0)

# Skeleton (Blender: -Y forward, Z up). A slight stoop: neck and head lean forward.
S = [
    ("hips", (0, 0, 0.62), (0, 0, 0.8), None),
    ("spine_01", (0, 0, 0.8), (0, -0.02, 1.05), "hips"),
    ("chest", (0, -0.02, 1.05), (0, -0.04, 1.22), "spine_01"),
    ("neck_01", (0, -0.04, 1.22), (0, -0.08, 1.32), "chest"),
    ("head", (0, -0.08, 1.32), (0, -0.1, 1.58), "neck_01"),
]
for s, x in (("l", 1), ("r", -1)):
    S += [
        ("thigh_" + s, (x * 0.1, 0, 0.62), (x * 0.11, 0, 0.34), "hips"),
        ("shin_" + s, (x * 0.11, 0, 0.34), (x * 0.11, 0.02, 0.07), "thigh_" + s),
        ("foot_" + s, (x * 0.11, 0.02, 0.07), (x * 0.11, -0.12, 0.03), "shin_" + s),
        ("upperarm_" + s, (x * 0.17, -0.03, 1.17), (x * 0.24, -0.03, 0.93), "chest"),
        ("forearm_" + s, (x * 0.24, -0.03, 0.93), (x * 0.26, -0.12, 0.74), "upperarm_" + s),
        ("hand_" + s, (x * 0.26, -0.12, 0.74), (x * 0.27, -0.16, 0.66), "forearm_" + s),
    ]
# The crook has its own bone so a bred pet's sleeves take the donor's colour
# but the wood doesn't; the censer hangs from its hook on another.
S.append(("crook", (-0.27, -0.16, 0.66), (-0.27, -0.16, 1.2), "hand_r"))
S.append(("censer", (-0.27, -0.42, 1.3), (-0.27, -0.42, 1.08), "crook"))
rig = armature(S)

# Robe: falls to the shins, open below so the boots show as it walks.
robe = tube("robe", [((0, 0.0, 0.26), 0.25, 0.23), ((0, 0.0, 0.5), 0.22, 0.2), ((0, 0, 0.8), 0.19, 0.16),
                     ((0, -0.02, 1.05), 0.2, 0.16), ((0, -0.04, 1.2), 0.17, 0.14), ((0, -0.05, 1.27), 0.09, 0.08)],
            ROBE, n=12, cap0=False)
two_tone(robe, DEEP, LIGHT, down=-0.5, up=0.8)
bind(robe, ["hips", "spine_01", "chest", "thigh_l", "thigh_r"])
bind(blob("mantle", (0, -0.03, 1.2), (0.44, 0.34, 0.1), DEEP), ["chest"])
# Rope belt with two herb bundles at the hip.
belt = [((math.cos(a) * 0.195, math.sin(a) * 0.165, 0.8), 0.016, 0.016) for a in [i * math.pi * 2 / 16 for i in range(17)]]
bind(tube("belt", belt, ROPE, n=6, sub=0), ["hips"])
for k, (x, y) in enumerate([(0.17, -0.08), (0.12, -0.14)]):
    bind(tube("cord%d" % k, [((x, y, 0.79), 0.008, 0.008), ((x + 0.01, y - 0.01, 0.68), 0.008, 0.008)], ROPE, n=4, sub=0), ["hips"])
    bind(blob("herb%d" % k, (x + 0.01, y - 0.01, 0.63), (0.05, 0.05, 0.1), LEAF if k else DEEP, sub=1), ["hips"])

# Legs: dark leggings and turned-up boots.
for s, x in (("l", 1), ("r", -1)):
    bind(tube("leg_" + s, [((x * 0.1, 0, 0.6), 0.065, 0.065), ((x * 0.11, 0, 0.34), 0.05, 0.05), ((x * 0.11, 0.02, 0.1), 0.045, 0.045)],
              LEATHER, n=8), ["thigh_" + s, "shin_" + s])
    bind(blob("boot_" + s, (x * 0.11, -0.04, 0.05), (0.11, 0.2, 0.1), BARK_D), ["foot_" + s])
    bind(cone("toe_" + s, (x * 0.11, -0.12, 0.05), (x * 0.11, -0.2, 0.1), 0.04, BARK_D, n=6), ["foot_" + s])

# Hood: a cowl open at the front onto a carved beak-mask.
bind(tube("cowl", [((0, 0.08, 1.44), 0.09, 0.1), ((0, 0.0, 1.45), 0.17, 0.18), ((0, -0.12, 1.45), 0.16, 0.17),
                   ((0, -0.2, 1.44), 0.135, 0.15)], ROBE, n=14, cap1=False), ["head"])
bind(tube("lip", [((0, -0.18, 1.44), 0.14, 0.155), ((0, -0.22, 1.44), 0.13, 0.145)], DEEP, n=14, cap0=False, cap1=False), ["head"])
bind(cone("hoodtip", (0, 0.02, 1.54), (0, 0.2, 1.48), 0.1, ROBE, n=8, bend=(0, 0.04, 0.06)), ["head"])
bind(blob("shadow", (0, -0.15, 1.44), (0.26, 0.04, 0.29), VOID), ["head"])
bind(blob("mask", (0, -0.18, 1.43), (0.2, 0.06, 0.22), BARK), ["head"])
bind(cone("beak", (0, -0.2, 1.39), (0, -0.46, 1.27), 0.075, BARK, n=8, bend=(0, -0.02, 0.03)), ["head"])
bind(tube("beakband", [((0, -0.24, 1.38), 0.06, 0.06), ((0, -0.26, 1.37), 0.058, 0.058)], LEATHER, n=8, sub=0), ["head"])
for x in (1, -1):
    bind(blob("rim", (x * 0.055, -0.21, 1.47), (0.075, 0.03, 0.075), BARK_D), ["head"])
    bind(blob("lens", (x * 0.055, -0.225, 1.47), (0.055, 0.02, 0.055), LENS, sub=1), ["head"])

# Sleeves and gloved hands.
for s, x in (("l", 1), ("r", -1)):
    P = lambda v: (x * v[0], v[1], v[2])
    bind(tube("sleeve_" + s, [(P((0.16, -0.03, 1.18)), 0.07, 0.07), (P((0.24, -0.03, 0.93)), 0.065, 0.065),
                              (P((0.26, -0.11, 0.76)), 0.085, 0.085)], ROBE, n=8, cap1=False), ["upperarm_" + s, "forearm_" + s])
    bind(blob("glove_" + s, P((0.265, -0.13, 0.71)), (0.08, 0.09, 0.1), LEATHER, sub=1), ["hand_" + s])

# A thorny vine wound over the mantle, with one rose at the shoulder.
vine = [((math.cos(a) * 0.23, -0.03 + math.sin(a) * 0.17, 1.2 + 0.04 * math.sin(a * 3)), 0.014, 0.014)
        for a in [math.pi * (0.15 + i * 0.1) for i in range(9)]]
bind(tube("vine", vine, DEEP, n=5, sub=0), ["chest"])
for i, (p, _, _) in enumerate(vine[1:-1:2]):
    bind(cone("vthorn%d" % i, p, (p[0] * 1.12, p[1] * 1.12 - 0.01, p[2] + 0.05), 0.012, THORN, n=4), ["chest"])
bind(blob("rose", (0.19, -0.13, 1.24), (0.08, 0.08, 0.07), ROSE), ["chest"])
for k, (dx, dy) in enumerate([(0.06, 0.0), (-0.02, 0.06)]):
    bind(sheet("rleaf%d" % k, [(0.19, -0.13, 1.22), (0.19 + dx, -0.13 + dy - 0.03, 1.2), (0.19 + dx * 1.6, -0.13 + dy * 1.6, 1.21),
                               (0.19 + dx * 0.6, -0.13 + dy * 0.6 + 0.02, 1.23)], LEAF, 0.01), ["chest"])

# The briar crook in the right hand, thorned, its hook holding the censer.
crook = [((-0.27, -0.16, 0.04), 0.022, 0.022), ((-0.275, -0.16, 0.66), 0.026, 0.026), ((-0.27, -0.17, 1.2), 0.024, 0.024),
         ((-0.27, -0.22, 1.36), 0.02, 0.02), ((-0.27, -0.34, 1.4), 0.018, 0.018), ((-0.27, -0.42, 1.33), 0.014, 0.014)]
bind(tube("crook", crook, BARK_D, n=7), ["crook"])
for k, z in enumerate([0.3, 0.5, 0.95, 1.12]):
    sx = 1 if k % 2 else -1
    bind(cone("cthorn%d" % k, (-0.27, -0.16, z), (-0.27 + sx * 0.05, -0.19, z + 0.04), 0.012, THORN, n=4), ["crook"])
bind(tube("chain", [((-0.27, -0.42, 1.31), 0.006, 0.006), ((-0.27, -0.42, 1.14), 0.006, 0.006)], LEATHER, n=4, sub=0), ["censer"])
bind(blob("censer_cap", (-0.27, -0.42, 1.13), (0.07, 0.07, 0.03), BARK_D, sub=1), ["censer"])
bind(blob("censer_pot", (-0.27, -0.42, 1.08), (0.08, 0.08, 0.08), LENS, sub=1), ["censer"])
bind(blob("censer_base", (-0.27, -0.42, 1.035), (0.06, 0.06, 0.025), BARK_D, sub=1), ["censer"])

aco = skin(rig, "Acolyte")
bake(aco, 1024, OUT + "plague_tex.png")


# Clips: +X pitches forward or swings a leg back, -Y lifts the left arm, Z turns.
def censer(period, a):
    return [(0, (a, 0, a * 0.4), None), (period / 2, (-a, 0, -a * 0.4), None), (period, (a, 0, a * 0.4), None)]

def stride(period, a, knee, arm):
    ks = {}
    for s, sg in (("l", 1), ("r", -1)):
        ks["thigh_" + s] = [(0, (-sg * a, 0, 0), None), (period / 2, (sg * a, 0, 0), None), (period, (-sg * a, 0, 0), None)]
        # The knee folds as that leg swings through, half a stride apart.
        if sg > 0:
            ks["shin_" + s] = [(0, (knee * 0.2, 0, 0), None), (period * 0.25, (knee, 0, 0), None),
                               (period * 0.5, (knee * 0.1, 0, 0), None), (period, (knee * 0.2, 0, 0), None)]
        else:
            ks["shin_" + s] = [(0, (knee * 0.1, 0, 0), None), (period * 0.5, (knee * 0.2, 0, 0), None),
                               (period * 0.75, (knee, 0, 0), None), (period, (knee * 0.1, 0, 0), None)]
        ks["upperarm_l" if s == "r" else "upperarm_r"] = [(0, (-sg * arm, 0, 0), None), (period / 2, (sg * arm, 0, 0), None), (period, (-sg * arm, 0, 0), None)]
    return ks

idle = {"censer": censer(2.0, 8)}
idle["chest"] = [(0, (0, 0, 0), None), (1.0, (3, 0, 0), None), (2.0, (0, 0, 0), None)]
idle["head"] = [(0, (0, 0, -5), None), (1.0, (4, 6, 5), None), (2.0, (0, 0, -5), None)]
idle["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (1.0, (0, 0, 0), (0, 0, -0.01)), (2.0, (0, 0, 0), (0, 0, 0))]
clip(rig, "Idle", 2.0, idle)

walk = stride(0.9, 24, 40, 14)
walk.pop("upperarm_r")  # the crook hand stays steady
walk["censer"] = censer(0.9, 16)
walk["hips"] = [(0, (0, 0, 4), (0, 0, 0)), (0.225, (0, 0, 0), (0, 0, 0.025)), (0.45, (0, 0, -4), (0, 0, 0)),
                (0.675, (0, 0, 0), (0, 0, 0.025)), (0.9, (0, 0, 4), (0, 0, 0))]
walk["chest"] = [(0, (6, 0, -4), None), (0.45, (6, 0, 4), None), (0.9, (6, 0, -4), None)]
clip(rig, "Walk", 0.9, walk)

run = stride(0.55, 36, 70, 26)
run.pop("upperarm_r")
run["censer"] = censer(0.55, 26)
run["hips"] = [(0, (14, 0, 6), (0, 0, 0)), (0.14, (14, 0, 0), (0, 0, 0.04)), (0.275, (14, 0, -6), (0, 0, 0)),
               (0.41, (14, 0, 0), (0, 0, 0.04)), (0.55, (14, 0, 6), (0, 0, 0))]
run["upperarm_r"] = [(0, (-20, 0, 0), None), (0.55, (-20, 0, 0), None)]
clip(rig, "Run", 0.55, run)

# Thorn Ward: lifts the crook high and drives it into the ground.
atk = {"censer": [(0, (0, 0, 0), None), (0.3, (-30, 0, 0), None), (0.45, (40, 0, 0), None), (0.8, (0, 0, 0), None)]}
atk["upperarm_r"] = [(0, (0, 0, 0), None), (0.3, (-70, 0, 0), None), (0.45, (-10, 0, 0), None), (0.8, (0, 0, 0), None)]
atk["forearm_r"] = [(0, (0, 0, 0), None), (0.3, (-30, 0, 0), None), (0.45, (0, 0, 0), None), (0.8, (0, 0, 0), None)]
atk["upperarm_l"] = [(0, (0, 0, 0), None), (0.3, (-20, 30, 0), None), (0.45, (10, 20, 0), None), (0.8, (0, 0, 0), None)]
atk["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.3, (-6, 0, 0), (0, 0, 0.04)), (0.45, (12, 0, 0), (0, -0.04, -0.06)), (0.8, (0, 0, 0), (0, 0, 0))]
for s in ("l", "r"):
    atk["thigh_" + s] = [(0, (0, 0, 0), None), (0.45, (-18, 0, 0), None), (0.8, (0, 0, 0), None)]
    atk["shin_" + s] = [(0, (0, 0, 0), None), (0.45, (30, 0, 0), None), (0.8, (0, 0, 0), None)]
clip(rig, "Attack", 0.8, atk, loop=False)

hit = {"censer": [(0, (0, 0, 0), None), (0.12, (30, 0, 10), None), (0.45, (0, 0, 0), None)]}
hit["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.12, (-12, 0, 8), (0, 0.06, 0)), (0.45, (0, 0, 0), (0, 0, 0))]
hit["head"] = [(0, (0, 0, 0), None), (0.12, (-16, 0, 0), None), (0.45, (0, 0, 0), None)]
clip(rig, "Hit", 0.45, hit, loop=False)

# Special: the free arm raised to the Thornmother, the crook held up, head back.
sp = {"censer": censer(1.2, 20)}
sp["upperarm_l"] = [(0, (0, 0, 0), None), (0.4, (-60, -50, 0), None), (0.9, (-60, -50, 0), None), (1.2, (0, 0, 0), None)]
sp["forearm_l"] = [(0, (0, 0, 0), None), (0.4, (-20, 0, 0), None), (0.9, (-20, 0, 0), None), (1.2, (0, 0, 0), None)]
sp["upperarm_r"] = [(0, (0, 0, 0), None), (0.4, (-40, 20, 0), None), (0.9, (-40, 20, 0), None), (1.2, (0, 0, 0), None)]
sp["head"] = [(0, (0, 0, 0), None), (0.4, (-22, 0, 0), None), (0.9, (-22, 0, 0), None), (1.2, (0, 0, 0), None)]
sp["chest"] = [(0, (0, 0, 0), None), (0.4, (-8, 0, 0), None), (0.9, (-8, 0, 0), None), (1.2, (0, 0, 0), None)]
clip(rig, "Special", 1.2, sp, loop=False)

export(rig, aco, OUT + "plague_src.glb")
os.remove(OUT + "plague_tex.png")
