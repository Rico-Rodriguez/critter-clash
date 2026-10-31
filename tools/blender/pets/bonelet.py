# Bonelet: a small skeleton that follows you everywhere, at grown proportions
# (no chibi), made from code. Ivory bones, a ragged red hooded mantle that sets
# it apart from the enemy dead, a broken iron shackle still on one wrist, and
# a femur to throw. Writes assets/sidekicks/skeleton_src.glb.
# Run: <blender python> tools/blender/pets/bonelet.py -- <repo root>
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *
from biped import skeleton, bones, stride, bob

ROOT = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(ROOT, "assets/sidekicks/")
reset()

BONE = mat("bl_bone", "bdb39c")
BONE_D = mat("bl_bone_d", "7f7663")
VOID = mat("bl_void", "0b0a0a", 1.0)
EYE = mat("bl_eye", "8fd0e6")
MANTLE = mat("bl_mantle", "4a1714")
MANTLE_D = mat("bl_mantle_d", "2a0e0c")
IRON = mat("bl_iron", "4a5155", 0.5)

# The thrown femur has its own bone, so a bred pet's arms take the donor's
# colours while the bone it throws stays bone.
rig = armature(skeleton([("femur", (-0.29, -0.13, 0.7), (-0.29, -0.13, 0.98), "hand_r")]))
bones(BONE, BONE_D, VOID, EYE)

# Mantle: a short hood thrown back over the shoulders and a ragged cape.
bind(tube("collar", [((0, -0.01, 1.14), 0.21, 0.16), ((0, -0.01, 1.22), 0.2, 0.15), ((0, -0.02, 1.27), 0.12, 0.1)],
          MANTLE, n=12, cap0=False, cap1=False), ["chest"])
bind(blob("hood", (0, 0.11, 1.27), (0.26, 0.1, 0.12), MANTLE_D), ["chest"])
bind(sheet("cape", [(0, 0.11, 1.24), (0.18, 0.08, 1.22), (0.21, 0.13, 0.92), (0.14, 0.17, 0.86), (0.07, 0.15, 0.93),
                    (0, 0.19, 0.84), (-0.07, 0.15, 0.93), (-0.14, 0.17, 0.86), (-0.21, 0.13, 0.92), (-0.18, 0.08, 1.22)],
           MANTLE, 0.02), ["chest", "spine_01"])
bind(blob("clasp", (0, -0.15, 1.2), (0.05, 0.03, 0.05), IRON, sub=1), ["chest"])

# A broken shackle on the left wrist, a link of chain still hanging.
cuff = [((0.28 + math.cos(a) * 0.045, -0.1 + math.sin(a) * 0.045, 0.78), 0.014, 0.014) for a in [i * math.pi * 2 / 12 for i in range(13)]]
bind(tube("cuff", cuff, IRON, n=4, sub=0), ["forearm_l"])
for k in range(2):
    z = 0.74 - k * 0.05
    link = [((0.31 + math.cos(a) * 0.012, -0.1, z + math.sin(a) * 0.022), 0.006, 0.006) for a in [i * math.pi * 2 / 8 for i in range(9)]]
    bind(tube("link%d" % k, link, IRON, n=4, sub=0), ["forearm_l"])

# The femur it throws.
bind(tube("throw", [((-0.29, -0.13, 0.66), 0.03, 0.03), ((-0.29, -0.13, 0.82), 0.025, 0.025), ((-0.29, -0.13, 0.98), 0.03, 0.03)],
          BONE, n=6), ["femur"])
for z in (0.64, 1.0):
    for dx in (-0.025, 0.025):
        bind(blob("knob", (-0.29 + dx, -0.13, z), (0.05, 0.045, 0.05), BONE, sub=1), ["femur"])

bl = skin(rig, "Bonelet")
bake(bl, 1024, OUT + "skeleton_tex.png")

# Clips.
idle = {"chest": [(0, (0, 0, 0), None), (1.0, (3, 0, 0), None), (2.0, (0, 0, 0), None)]}
idle["head"] = [(0, (0, 0, -8), None), (0.6, (6, 0, 0), None), (1.2, (0, 0, 10), None), (2.0, (0, 0, -8), None)]
idle["upperarm_r"] = [(0, (0, 0, 0), None), (1.0, (-6, 0, 0), None), (2.0, (0, 0, 0), None)]
idle["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (1.0, (0, 0, 0), (0, 0, -0.01)), (2.0, (0, 0, 0), (0, 0, 0))]
clip(rig, "Idle", 2.0, idle)

# A loose-jointed shamble.
walk = stride(0.8, 26, 44, 20)
walk["hips"] = bob(0.8, tilt=6)
walk["head"] = [(0, (0, 0, 6), None), (0.4, (0, 0, -6), None), (0.8, (0, 0, 6), None)]
clip(rig, "Walk", 0.8, walk)

run = stride(0.5, 38, 72, 32)
run["hips"] = bob(0.5, tilt=6, lift=0.04, lean=14)
clip(rig, "Run", 0.5, run)

# Bone Toss: wind back, hurl overarm.
atk = {"upperarm_r": [(0, (0, 0, 0), None), (0.25, (40, 0, -30), None), (0.4, (-130, 0, 10), None), (0.7, (0, 0, 0), None)]}
atk["forearm_r"] = [(0, (0, 0, 0), None), (0.25, (-60, 0, 0), None), (0.4, (-10, 0, 0), None), (0.7, (0, 0, 0), None)]
atk["chest"] = [(0, (0, 0, 0), None), (0.25, (-8, 0, -20), None), (0.4, (12, 0, 16), None), (0.7, (0, 0, 0), None)]
atk["upperarm_l"] = [(0, (0, 0, 0), None), (0.25, (-40, 0, 0), None), (0.4, (20, 0, 0), None), (0.7, (0, 0, 0), None)]
atk["thigh_l"] = [(0, (0, 0, 0), None), (0.4, (-20, 0, 0), None), (0.7, (0, 0, 0), None)]
clip(rig, "Attack", 0.7, atk, loop=False)

hit = {"hips": [(0, (0, 0, 0), (0, 0, 0)), (0.12, (-12, 0, 8), (0, 0.06, 0)), (0.45, (0, 0, 0), (0, 0, 0))]}
hit["head"] = [(0, (0, 0, 0), None), (0.12, (-20, 0, 14), None), (0.45, (0, 0, 0), None)]
clip(rig, "Hit", 0.45, hit, loop=False)

# Special: a taunt, arms flung wide, head rattling.
sp = {}
for s, sg in (("l", 1), ("r", -1)):
    sp["upperarm_" + s] = [(0, (0, 0, 0), None), (0.3, (-20, -sg * 70, 0), None), (0.9, (-20, -sg * 70, 0), None), (1.2, (0, 0, 0), None)]
sp["head"] = [(0, (0, 0, 0), None), (0.3, (-16, 0, 12), None), (0.45, (-16, 0, -12), None), (0.6, (-16, 0, 12), None),
              (0.75, (-16, 0, -12), None), (0.9, (-16, 0, 0), None), (1.2, (0, 0, 0), None)]
sp["chest"] = [(0, (0, 0, 0), None), (0.3, (-10, 0, 0), None), (0.9, (-10, 0, 0), None), (1.2, (0, 0, 0), None)]
clip(rig, "Special", 1.2, sp, loop=False)

export(rig, bl, OUT + "skeleton_src.glb")
os.remove(OUT + "skeleton_tex.png")
