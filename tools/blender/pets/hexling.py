# Hexling: a KayKit hooded figure (the heroes' own kit) at the heroes' adult
# build, re-dyed as a violet cultist with hex-pale skin, carrying a crooked
# staff modelled here. Writes assets/sidekicks/lich_src.glb.
# Run: <blender python> tools/blender/pets/hexling.py -- <repo root>
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import mat, tube, blob, cone
from kaykit import load, clips, recolour, bone_at, wear, export
from mathutils import Vector

ROOT = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(ROOT, "assets/sidekicks/")

rig, meshes = load(ROOT, "Rogue_Hooded")
clips(ROOT, rig, {
    "Idle": "Idle_B", "Walk": "Walking_B", "Run": "Running_A",
    "Attack": "Ranged_Magic_Shoot", "Hit": "Hit_A", "Special": "Ranged_Magic_Summon",
})

# The rogue's greens become cult violet, so it reads as a small cultist
# rather than the Rogue hero.
recolour(meshes, {(0, 1): "2e1a47", (1, 1): "4f2a7a", (1, 2): "4f2a7a"})

WOOD = mat("hexling_wood", "4a3326", 0.85)
ORB = mat("hexling_orb", "b36bff", 0.35)

# A crooked staff in the right hand, hooked at the top around a violet orb.
# It lies along +X in the T-pose rest, which the lowered arm of every clip
# turns upright.
h = bone_at(rig, "handslot.r")
up, side = Vector((1, 0, 0)), Vector((0, -1, 0))
staff = [tube("staff", [(h - up * 0.7, 0.07, 0.07), (h + up * 0.25 + side * 0.02, 0.075, 0.075),
    (h + up * 0.7 - side * 0.03, 0.072, 0.072), (h + up * 0.95, 0.065, 0.065),
    (h + up * 1.08 + side * 0.12, 0.058, 0.058), (h + up * 1.0 + side * 0.24, 0.045, 0.045)], WOOD, n=8)]
staff.append(blob("orb", h + up * 0.9 + side * 0.14, (0.15, 0.15, 0.15), ORB, sub=2))
for o in staff:
    wear(rig, o, "handslot.r")

export(rig, OUT + "lich_src.glb")
