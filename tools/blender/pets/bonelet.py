# Bonelet: a KayKit skeleton (the heroes' own kit) at the heroes' adult build,
# in a red mantle, with a femur to throw. Writes assets/sidekicks/skeleton_src.glb.
# Run: <blender python> tools/blender/pets/bonelet.py -- <repo root>
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import mat, tube, blob
from kaykit import load, clips, bone_at, wear, export
from mathutils import Vector

ROOT = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(ROOT, "assets/sidekicks/")

rig, meshes = load(ROOT, "Skeleton_Minion")
clips(ROOT, rig, {
    "Idle": "Skeletons_Idle", "Walk": "Skeletons_Walking", "Run": "Running_A",
    "Attack": "Throw", "Hit": "Hit_A", "Special": "Skeletons_Taunt",
})

MANTLE = mat("bonelet_mantle", "a8322c", 0.9)
BONE = mat("bonelet_bone", "e9e0c9", 0.7)

# Its shoulder mantle dyed red, so it never reads as one of the enemy dead.
for o in meshes:
    if o.name.endswith("_Cloak"):
        o.data.materials.clear()
        o.data.materials.append(MANTLE)

# A femur in the right hand: the bone it throws.
h = bone_at(rig, "handslot.r")
femur = [tube("femur", [(h + Vector((0, 0, -0.3)), 0.055, 0.055), (h + Vector((0, 0, 0.0)), 0.045, 0.045), (h + Vector((0, 0, 0.3)), 0.055, 0.055)], BONE, n=8)]
for z in (-0.34, 0.34):
    for x in (-0.05, 0.05):
        femur.append(blob("knuckle", h + Vector((x, 0, z)), (0.11, 0.09, 0.11), BONE, sub=1))
for o in femur:
    wear(rig, o, "handslot.r")

export(rig, OUT + "skeleton_src.glb")
