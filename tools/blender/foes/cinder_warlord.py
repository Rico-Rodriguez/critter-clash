# Cinder Warlord: the Cinder Mire's boss. A hulking, hunched orc in dark cinder
# plate with a horned helm and a great cleaver, ember-lit eyes and rust-red
# cloth. Stands 1.9 m at scale 1.0 (the game scales him 3x).
# Writes assets/foes/cinder_warlord_src.glb (texture inside).
# Run: python3 tools/blender/foes/cinder_warlord.py -- <repo root>
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from plate import *

ROOT = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(ROOT, "assets/foes/")
reset()

SKIN = mat("orc_skin", "4a5136")
SKIN_D = mat("orc_skin_dark", "2f3524")
PLATE = mat("plate", "26221f")
PLATE_HI = mat("plate_hi", "3d3530")
EDGE = mat("plate_edge", "5a4a3e")
RUST = mat("rust", "6a2f18")
CLOTH = mat("cloth", "4a1a12")
LEATHER = mat("leather", "2a1d16")
BONE = mat("bone", "b4a78a")
EMBER = mat("ember", "ff7a1e")
WOOD = mat("wood", "3a281c")
STEEL = mat("steel", "5c5d5f")
VOID = mat("void", "0c0a09")

S = [
    ("hips", (0, 0.03, 0.92), (0, 0.02, 1.06), None),
    ("spine_01", (0, 0.02, 1.06), (0, -0.04, 1.28), "hips"),
    ("chest", (0, -0.04, 1.28), (0, -0.09, 1.52), "spine_01"),
    ("neck_01", (0, -0.09, 1.52), (0, -0.16, 1.62), "chest"),
    ("head", (0, -0.16, 1.62), (0, -0.2, 1.9), "neck_01"),
]
for s, x in (("l", 1), ("r", -1)):
    S += [
        ("thigh_" + s, (x * 0.2, 0.02, 0.92), (x * 0.23, -0.02, 0.5), "hips"),
        ("shin_" + s, (x * 0.23, -0.02, 0.5), (x * 0.23, 0.03, 0.1), "thigh_" + s),
        ("foot_" + s, (x * 0.23, 0.03, 0.1), (x * 0.23, -0.2, 0.04), "shin_" + s),
        ("upperarm_" + s, (x * 0.44, -0.08, 1.46), (x * 0.54, -0.08, 1.12), "chest"),
        ("forearm_" + s, (x * 0.54, -0.08, 1.12), (x * 0.54, -0.18, 0.8), "upperarm_" + s),
        ("hand_" + s, (x * 0.54, -0.18, 0.8), (x * 0.54, -0.22, 0.64), "forearm_" + s),
    ]
rig = armature(S)

# ---- Body: barrel chest, thick neck, gut, long arms and short bowed legs -----
bind(hull("torso", [(-0.34, -0.08, 1.52), (0.34, -0.08, 1.52), (-0.38, -0.2, 1.36), (0.38, -0.2, 1.36),
                    (-0.3, 0.14, 1.5), (0.3, 0.14, 1.5), (-0.34, 0.16, 1.3), (0.34, 0.16, 1.3),
                    (-0.26, -0.14, 1.06), (0.26, -0.14, 1.06), (-0.26, 0.1, 1.06), (0.26, 0.1, 1.06)], SKIN),
     ["chest", "spine_01"])
bind(hull("belly", [(-0.26, -0.19, 1.2), (0.26, -0.19, 1.2), (-0.24, -0.18, 0.98), (0.24, -0.18, 0.98),
                    (-0.2, 0.02, 1.2), (0.2, 0.02, 1.2), (-0.22, 0.08, 0.96), (0.22, 0.08, 0.96)], SKIN_D),
     ["spine_01", "hips"])
bind(hull("pelvis", [(-0.28, -0.12, 1.0), (0.28, -0.12, 1.0), (-0.3, 0.14, 1.0), (0.3, 0.14, 1.0),
                     (-0.26, -0.1, 0.8), (0.26, -0.1, 0.8), (-0.24, 0.1, 0.8), (0.24, 0.1, 0.8)], SKIN_D), ["hips"])
bind(tube("neck", [((0, -0.08, 1.46), 0.15, 0.13), ((0, -0.15, 1.64), 0.12, 0.11)], SKIN, n=8), ["chest", "neck_01", "head"])

# ---- Head: heavy brow, underbite with tusks, horned iron helm -----------------
bind(hull("skull", [(-0.14, -0.1, 1.84), (0.14, -0.1, 1.84), (-0.16, -0.26, 1.78), (0.16, -0.26, 1.78),
                    (-0.17, -0.12, 1.66), (0.17, -0.12, 1.66), (-0.13, 0.04, 1.8), (0.13, 0.04, 1.8),
                    (-0.14, 0.02, 1.68), (0.14, 0.02, 1.68), (-0.12, -0.28, 1.66), (0.12, -0.28, 1.66)], SKIN), ["head"])
bind(hull("jaw", [(-0.15, -0.14, 1.68), (0.15, -0.14, 1.68), (-0.12, -0.3, 1.66), (0.12, -0.3, 1.66),
                  (-0.11, -0.12, 1.57), (0.11, -0.12, 1.57), (-0.09, -0.3, 1.58), (0.09, -0.3, 1.58)], SKIN_D), ["head"])
bind(frustum("brow", (0, -0.25, 1.77), (0.3, 0.08), (0.28, 0.06), 0.05, SKIN_D, rot=(-14, 0, 0)), ["head"])
bind(frustum("nose", (0, -0.29, 1.7), (0.06, 0.05), (0.04, 0.03), 0.07, SKIN_D), ["head"])
for x in (1, -1):
    bind(frustum("socket", (x * 0.07, -0.268, 1.745), (0.07, 0.03), (0.05, 0.02), 0.035, VOID), ["head"])
    bind(frustum("eye", (x * 0.07, -0.285, 1.752), (0.045, 0.016), (0.03, 0.012), 0.022, EMBER), ["head"])
    bind(spike("tusk_%d" % x, (x * 0.075, -0.285, 1.64), (x * 0.085, -0.34, 1.77), 0.032, BONE, n=4), ["head"])
    bind(spike("ear_%d" % x, (x * 0.15, -0.06, 1.74), (x * 0.3, 0.04, 1.84), 0.04, SKIN, n=3), ["head"])
    # cheek guard, nasal bar and horn on the helm
    bind(frustum("cheek_%d" % x, (x * 0.165, -0.12, 1.7), (0.03, 0.15), (0.03, 0.1), 0.14, PLATE, rot=(0, 0, x * -6)), ["head"])
    bind(spike("horn_%d" % x, (x * 0.15, -0.1, 1.88), (x * 0.36, -0.14, 2.08), 0.05, BONE, n=5), ["head"])
    bind(spike("horn_t%d" % x, (x * 0.34, -0.14, 2.04), (x * 0.3, -0.2, 2.2), 0.026, BONE, n=4), ["head"])
bind(hull("helm", [(-0.17, -0.2, 1.88), (0.17, -0.2, 1.88), (-0.19, 0.02, 1.86), (0.19, 0.02, 1.86),
                   (-0.12, -0.14, 1.99), (0.12, -0.14, 1.99), (-0.1, 0.0, 1.97), (0.1, 0.0, 1.97),
                   (-0.18, 0.06, 1.74), (0.18, 0.06, 1.74)], PLATE), ["head"])
bind(frustum("helm_brim", (0, -0.2, 1.84), (0.36, 0.02), (0.34, 0.02), 0.05, PLATE_HI), ["head"])
bind(frustum("helm_bar", (0, -0.215, 1.72), (0.03, 0.03), (0.025, 0.025), 0.15, PLATE_HI), ["head"])
bind(frustum("helm_crest", (0, -0.1, 1.97), (0.03, 0.3), (0.02, 0.28), 0.07, RUST), ["head"])

# ---- Armour on the torso: cuirass, gorget, spiked back plate, belt, tassets ----
bind(hull("cuirass", [(-0.3, -0.16, 1.5), (0.3, -0.16, 1.5), (-0.34, -0.25, 1.32), (0.34, -0.25, 1.32),
                      (-0.2, -0.22, 1.12), (0.2, -0.22, 1.12), (0, -0.28, 1.34), (0, -0.2, 1.52)], PLATE), ["chest"])
bind(frustum("breast_ridge", (0, -0.27, 1.14), (0.05, 0.03), (0.035, 0.03), 0.36, EDGE, shift=(0, 0)), ["chest"])
for k, z in enumerate((1.4, 1.28, 1.17)):
    w = 0.6 - k * 0.1
    bind(frustum("lame%d" % k, (0, -0.2, z - 0.04), (w, 0.1), (w - 0.04, 0.1), 0.06, PLATE_HI if k == 1 else PLATE, rot=(-8, 0, 0)), ["chest"])
bind(ring("gorget", (0, -0.1, 1.5), 0.2, 0.17, 0.1, PLATE_HI, n=8, taper=0.85), ["chest"])
bind(hull("backplate", [(-0.3, 0.12, 1.5), (0.3, 0.12, 1.5), (-0.3, 0.17, 1.2), (0.3, 0.17, 1.2),
                        (0, 0.2, 1.52), (0, 0.22, 1.1)], PLATE), ["chest", "spine_01"])
for k, (x, z, h) in enumerate([(0, 1.5, 0.3), (-0.16, 1.44, 0.2), (0.16, 1.44, 0.2), (-0.2, 1.28, 0.14), (0.2, 1.28, 0.14), (0, 1.3, 0.2)]):
    bind(spike("spine%d" % k, (x, 0.17, z), (x * 1.2, 0.34 + h * 0.2, z + h), 0.04, EDGE, n=4), ["chest"])
bind(ring("belt", (0, 0.01, 0.99), 0.3, 0.2, 0.12, LEATHER, n=8, taper=0.97), ["hips"])
bind(frustum("buckle", (0, -0.2, 1.01), (0.13, 0.04), (0.11, 0.04), 0.1, BONE, rot=(0, 0, 0)), ["hips"])
bind(frustum("buckle_gem", (0, -0.235, 1.045), (0.05, 0.02), (0.03, 0.015), 0.04, EMBER), ["hips"])
for k, x in enumerate((-0.22, -0.08, 0.08, 0.22)):
    bind(frustum("tasset%d" % k, (x, -0.17 - abs(x) * 0.1, 0.99), (0.14, 0.03), (0.1, 0.03), -0.32 - (0.04 if k in (1, 2) else 0),
                 PLATE if k % 2 == 0 else PLATE_HI, rot=(-4, 0, 0)), ["hips"])
bind(hull("rag_back", [(-0.2, 0.14, 0.98), (0.2, 0.14, 0.98), (-0.24, 0.2, 0.5), (0.24, 0.2, 0.55), (0, 0.18, 0.44)], CLOTH), ["hips"])
bind(hull("rag_front", [(-0.1, -0.2, 0.7), (0.1, -0.2, 0.7), (-0.12, -0.23, 0.42), (0.12, -0.23, 0.42), (0, -0.23, 0.36)], CLOTH), ["hips"])

# ---- Cape of rags hung off the pauldrons ---------------------------------------
bind(hull("cape", [(-0.36, 0.2, 1.5), (0.36, 0.2, 1.5), (-0.44, 0.34, 0.78), (0.44, 0.34, 0.78),
                   (-0.2, 0.36, 0.5), (0.2, 0.36, 0.6), (0, 0.2, 1.52)], CLOTH), ["chest", "spine_01"])

# ---- Limbs ----------------------------------------------------------------------
for s, x in (("l", 1), ("r", -1)):
    P = lambda v: (x * v[0], v[1], v[2])
    # arm: heavy bicep, bracer with spikes, gauntlet fist
    bind(tube("arm_" + s, [(P((0.42, -0.08, 1.46)), 0.13, 0.13), (P((0.52, -0.08, 1.2)), 0.14, 0.14), (P((0.54, -0.1, 1.1)), 0.11, 0.11)],
              SKIN, n=8), ["chest", "upperarm_" + s])
    bind(tube("fore_" + s, [(P((0.54, -0.09, 1.12)), 0.115, 0.115), (P((0.54, -0.15, 0.92)), 0.12, 0.12), (P((0.54, -0.2, 0.76)), 0.09, 0.09)],
              SKIN, n=8), ["upperarm_" + s, "forearm_" + s])
    bind(hull("bracer_" + s, [P((0.43, -0.2, 1.06)), P((0.65, -0.2, 1.06)), P((0.41, -0.06, 1.06)), P((0.67, -0.06, 1.06)),
                              P((0.45, -0.28, 0.8)), P((0.63, -0.28, 0.8)), P((0.46, -0.12, 0.8)), P((0.62, -0.12, 0.8))], PLATE),
         ["forearm_" + s])
    bind(frustum("bracer_rim_" + s, P((0.54, -0.16, 1.07)), (0.28, 0.2), (0.3, 0.22), 0.04, EDGE), ["forearm_" + s])
    for k in range(2):
        bind(spike("bracer_sp%d_%s" % (k, s), P((0.65, -0.16 - k * 0.07, 0.98 - k * 0.1)), P((0.8, -0.2 - k * 0.07, 1.0 - k * 0.1)), 0.035, EDGE, n=4),
             ["forearm_" + s])
    bind(hull("fist_" + s, [P((0.47, -0.14, 0.78)), P((0.61, -0.14, 0.78)), P((0.46, -0.3, 0.74)), P((0.62, -0.3, 0.74)),
                            P((0.48, -0.14, 0.58)), P((0.6, -0.14, 0.58)), P((0.48, -0.28, 0.6)), P((0.6, -0.28, 0.6))], SKIN_D), ["hand_" + s])
    bind(frustum("knuckles_" + s, P((0.54, -0.3, 0.7)), (0.16, 0.05), (0.15, 0.05), 0.06, PLATE_HI), ["hand_" + s])
    # pauldron: three stacked lames, a spike, ember-red trim
    bind(hull("pauld1_" + s, [P((0.18, -0.2, 1.58)), P((0.18, 0.12, 1.58)), P((0.62, -0.2, 1.5)), P((0.62, 0.12, 1.5)),
                              P((0.3, -0.26, 1.42)), P((0.3, 0.18, 1.42)), P((0.66, -0.18, 1.28)), P((0.66, 0.1, 1.28))], PLATE), ["upperarm_" + s, "chest"])
    bind(frustum("pauld2_" + s, P((0.6, -0.04, 1.3)), (0.22, 0.34), (0.25, 0.37), 0.05, PLATE_HI, rot=(0, 0, x * -8)), ["upperarm_" + s])
    bind(frustum("pauld_trim_" + s, P((0.4, -0.04, 1.57)), (0.4, 0.34), (0.36, 0.3), 0.03, RUST), ["upperarm_" + s, "chest"])
    bind(spike("pauld_sp_" + s, P((0.44, -0.04, 1.58)), P((0.52, -0.04, 1.86)), 0.07, EDGE, n=4), ["upperarm_" + s, "chest"])
    bind(spike("pauld_sp2_" + s, P((0.58, -0.02, 1.5)), P((0.78, -0.02, 1.62)), 0.05, EDGE, n=4), ["upperarm_" + s])
    # leg: thick thigh, spiked knee, greave, boot
    bind(tube("leg_" + s, [(P((0.2, 0.02, 0.96)), 0.16, 0.15), (P((0.23, -0.02, 0.6)), 0.14, 0.13), (P((0.23, -0.02, 0.5)), 0.1, 0.1)], SKIN_D, n=8),
         ["hips", "thigh_" + s])
    bind(hull("knee_" + s, [P((0.12, -0.14, 0.58)), P((0.34, -0.14, 0.58)), P((0.13, -0.12, 0.42)), P((0.33, -0.12, 0.42)),
                            P((0.2, -0.2, 0.52)), P((0.26, -0.2, 0.52))], PLATE), ["thigh_" + s, "shin_" + s])
    bind(spike("knee_sp_" + s, P((0.23, -0.18, 0.52)), P((0.23, -0.34, 0.56)), 0.05, EDGE, n=4), ["shin_" + s])
    bind(hull("greave_" + s, [P((0.12, -0.14, 0.44)), P((0.34, -0.14, 0.44)), P((0.12, 0.08, 0.44)), P((0.34, 0.08, 0.44)),
                              P((0.15, -0.1, 0.14)), P((0.31, -0.1, 0.14)), P((0.15, 0.06, 0.14)), P((0.31, 0.06, 0.14))], PLATE), ["shin_" + s])
    bind(frustum("greave_band_" + s, P((0.23, -0.02, 0.3)), (0.24, 0.2), (0.26, 0.22), 0.04, EDGE), ["shin_" + s])
    bind(hull("boot_" + s, [P((0.12, 0.08, 0.14)), P((0.34, 0.08, 0.14)), P((0.14, -0.1, 0.12)), P((0.32, -0.1, 0.12)),
                            P((0.1, 0.1, 0.0)), P((0.36, 0.1, 0.0)), P((0.12, -0.32, 0.0)), P((0.34, -0.32, 0.0)), P((0.16, -0.3, 0.08)), P((0.3, -0.3, 0.08))],
              LEATHER), ["foot_" + s])
    bind(frustum("toecap_" + s, P((0.23, -0.31, 0.0)), (0.2, 0.06), (0.18, 0.04), 0.1, PLATE_HI, rot=(0, 0, 0)), ["foot_" + s])

# ---- The cleaver: iron-banded haft, a broad notched blade with an ember edge -------
H = (-0.54, -0.24, 0.7)   # right fist
bind(tube("haft", [((H[0], H[1] + 0.02, 0.12), 0.035, 0.035), ((H[0], H[1], 1.1), 0.04, 0.04), ((H[0], H[1] - 0.02, 1.62), 0.035, 0.035)], WOOD, n=6),
     ["hand_r"])
bind(spike("pommel", (H[0], H[1] + 0.02, 0.14), (H[0], H[1] + 0.03, 0.02), 0.05, EDGE, n=5), ["hand_r"])
for z in (0.55, 0.9, 1.3):
    bind(ring("haft_band%d" % int(z * 10), (H[0], H[1], z), 0.05, 0.05, 0.05, EDGE, n=6), ["hand_r"])
bx, by = H[0], H[1] - 0.01
bind(hull("blade", [(bx - 0.02, by - 0.015, 1.72), (bx - 0.02, by + 0.015, 1.72), (bx - 0.02, by - 0.5, 1.9), (bx - 0.02, by - 0.5, 1.2),
                    (bx + 0.02, by - 0.015, 1.72), (bx + 0.02, by + 0.015, 1.72), (bx + 0.02, by - 0.5, 1.9), (bx + 0.02, by - 0.5, 1.2),
                    (bx, by - 0.02, 1.95), (bx, by - 0.02, 1.0)], STEEL), ["hand_r"])
bind(hull("blade_edge", [(bx - 0.012, by - 0.48, 1.9), (bx + 0.012, by - 0.48, 1.9), (bx - 0.012, by - 0.56, 1.7), (bx + 0.012, by - 0.56, 1.7),
                         (bx - 0.012, by - 0.56, 1.35), (bx + 0.012, by - 0.56, 1.35), (bx - 0.012, by - 0.48, 1.2), (bx + 0.012, by - 0.48, 1.2)], EMBER), ["hand_r"])
bind(hull("blade_back", [(bx - 0.03, by + 0.02, 1.8), (bx + 0.03, by + 0.02, 1.8), (bx - 0.03, by + 0.02, 1.2), (bx + 0.03, by + 0.02, 1.2),
                         (bx, by + 0.1, 1.5)], PLATE), ["hand_r"])
for k, z in enumerate((1.5, 1.38)):
    bind(spike("blade_notch%d" % k, (bx, by + 0.04, z), (bx, by + 0.2, z + 0.06), 0.035, PLATE_HI, n=4), ["hand_r"])
bind(frustum("guard", (bx, by, 1.64), (0.1, 0.07), (0.09, 0.06), 0.05, PLATE_HI), ["hand_r"])

body = skin(rig, "CinderWarlord")
bake(body, 512, OUT + "cinder_warlord_tex.png")

# ---- Clips -------------------------------------------------------------------------
# +X pitches forward (a hanging arm swings back), -X raises an arm forward.
# Left side is +X: -Y-axis turns lift... the arms below swing about X and splay with Y.
def breathe(p, amt):
    return [(0, (0, 0, 0), (0, 0, 0)), (p / 2, (1.5, 0, 0), (0, 0, -amt)), (p, (0, 0, 0), (0, 0, 0))]

def idle_keys():
    p = 2.4
    k = {"hips": breathe(p, 0.012)}
    k["chest"] = [(0, (4, 0, 0), None), (p / 2, (7, 0, 0), None), (p, (4, 0, 0), None)]
    k["head"] = [(0, (-3, 0, 2), None), (p / 2, (-6, 0, -2), None), (p, (-3, 0, 2), None)]
    for s, sg in (("l", 1), ("r", -1)):
        k["upperarm_" + s] = [(0, (4, sg * -4, 0), None), (p / 2, (7, sg * -6, 0), None), (p, (4, sg * -4, 0), None)]
        k["forearm_" + s] = [(0, (-14, 0, 0), None), (p / 2, (-18, 0, 0), None), (p, (-14, 0, 0), None)]
    k["upperarm_r"] = [(0, (-6, 3, 0), None), (p / 2, (-4, 3, 0), None), (p, (-6, 3, 0), None)]
    return k

def walk_keys(p, a, knee, arm, lean, lift):
    ks = {}
    for s, sg in (("l", 1), ("r", -1)):
        ks["thigh_" + s] = [(0, (-sg * a, 0, 0), None), (p / 2, (sg * a, 0, 0), None), (p, (-sg * a, 0, 0), None)]
        if sg > 0:
            ks["shin_" + s] = [(0, (knee * 0.2, 0, 0), None), (p * 0.25, (knee, 0, 0), None), (p * 0.5, (knee * 0.1, 0, 0), None), (p, (knee * 0.2, 0, 0), None)]
        else:
            ks["shin_" + s] = [(0, (knee * 0.1, 0, 0), None), (p * 0.5, (knee * 0.2, 0, 0), None), (p * 0.75, (knee, 0, 0), None), (p, (knee * 0.1, 0, 0), None)]
        o = "upperarm_" + ("r" if s == "l" else "l")
        ks[o] = [(0, (-sg * arm, 0, 0), None), (p / 2, (sg * arm, 0, 0), None), (p, (-sg * arm, 0, 0), None)]
        ks["forearm_" + s] = [(0, (-16, 0, 0), None), (p / 2, (-26, 0, 0), None), (p, (-16, 0, 0), None)]
    ks["upperarm_r"] = [(0, (-22, 4, 0), None), (p / 2, (-30, 4, 0), None), (p, (-22, 4, 0), None)]
    q = p / 4
    ks["hips"] = [(0, (lean, 0, 5), (0, 0, 0)), (q, (lean, 0, 0), (0, 0, lift)), (2 * q, (lean, 0, -5), (0, 0, 0)), (3 * q, (lean, 0, 0), (0, 0, lift)), (p, (lean, 0, 5), (0, 0, 0))]
    ks["chest"] = [(0, (4, 0, -6), None), (p / 2, (6, 0, 6), None), (p, (4, 0, -6), None)]
    ks["head"] = [(0, (-4, 0, 3), None), (p / 2, (-4, 0, -3), None), (p, (-4, 0, 3), None)]
    return ks

clip(rig, "Idle", 2.4, idle_keys())
clip(rig, "Walk", 1.1, walk_keys(1.1, 26, 40, 22, 6, 0.03))
clip(rig, "Run", 0.7, walk_keys(0.7, 40, 70, 34, 16, 0.06))

def ease(k, name, frames):
    k[name] = frames

# Attack_Chop: both hands haul the cleaver overhead, then slam it down. The hit lands near 45%.
a = {
    "hips": [(0, (0, 0, 0), (0, 0, 0)), (0.3, (-8, 0, 0), (0, 0.06, 0.0)), (0.5, (14, 0, 0), (0, -0.14, -0.1)), (0.9, (0, 0, 0), (0, 0, 0))],
    "chest": [(0, (0, 0, 0), None), (0.3, (-18, 0, 0), None), (0.5, (30, 0, 0), None), (0.9, (0, 0, 0), None)],
    "head": [(0, (0, 0, 0), None), (0.3, (10, 0, 0), None), (0.5, (-14, 0, 0), None), (0.9, (0, 0, 0), None)],
    "upperarm_r": [(0, (-6, 3, 0), None), (0.3, (-165, 8, 0), None), (0.5, (-40, 6, 0), None), (0.9, (-6, 3, 0), None)],
    "forearm_r": [(0, (-14, 0, 0), None), (0.3, (-30, 0, 0), None), (0.5, (-10, 0, 0), None), (0.9, (-14, 0, 0), None)],
    "upperarm_l": [(0, (4, -4, 0), None), (0.3, (-150, -10, 0), None), (0.5, (-34, -8, 0), None), (0.9, (4, -4, 0), None)],
    "forearm_l": [(0, (-14, 0, 0), None), (0.3, (-34, 0, 0), None), (0.5, (-12, 0, 0), None), (0.9, (-14, 0, 0), None)],
    "thigh_l": [(0, (0, 0, 0), None), (0.3, (10, 0, 0), None), (0.5, (-18, 0, 0), None), (0.9, (0, 0, 0), None)],
    "thigh_r": [(0, (0, 0, 0), None), (0.3, (-8, 0, 0), None), (0.5, (14, 0, 0), None), (0.9, (0, 0, 0), None)],
    "shin_l": [(0, (0, 0, 0), None), (0.5, (14, 0, 0), None), (0.9, (0, 0, 0), None)],
}
clip(rig, "Attack_Chop", 0.9, a, loop=False)

# Attack_Slash: a wide diagonal cut from the right shoulder across the body.
a = {
    "hips": [(0, (0, 0, 0), (0, 0, 0)), (0.28, (0, 0, -24), (0.04, 0.04, 0)), (0.48, (6, 0, 28), (-0.06, -0.1, -0.04)), (0.85, (0, 0, 0), (0, 0, 0))],
    "chest": [(0, (0, 0, 0), None), (0.28, (-6, 0, -30), None), (0.48, (14, 0, 42), None), (0.85, (0, 0, 0), None)],
    "head": [(0, (0, 0, 0), None), (0.28, (0, 0, 14), None), (0.48, (-6, 0, -22), None), (0.85, (0, 0, 0), None)],
    "upperarm_r": [(0, (-6, 3, 0), None), (0.28, (-120, 40, 0), None), (0.48, (-70, -50, 0), None), (0.85, (-6, 3, 0), None)],
    "forearm_r": [(0, (-14, 0, 0), None), (0.28, (-40, 0, 0), None), (0.48, (-8, 0, 0), None), (0.85, (-14, 0, 0), None)],
    "upperarm_l": [(0, (4, -4, 0), None), (0.28, (-90, -25, 0), None), (0.48, (-50, 30, 0), None), (0.85, (4, -4, 0), None)],
    "forearm_l": [(0, (-14, 0, 0), None), (0.28, (-50, 0, 0), None), (0.48, (-20, 0, 0), None), (0.85, (-14, 0, 0), None)],
    "thigh_l": [(0, (0, 0, 0), None), (0.48, (-16, 0, 0), None), (0.85, (0, 0, 0), None)],
    "thigh_r": [(0, (0, 0, 0), None), (0.48, (12, 0, 0), None), (0.85, (0, 0, 0), None)],
}
clip(rig, "Attack_Slash", 0.85, a, loop=False)

# Attack_Spin: a full turn with the cleaver held out, the whole body winding round.
a = {
    "hips": [(0, (0, 0, 0), (0, 0, 0)), (0.2, (-6, 0, -30), (0, 0.04, -0.06)), (0.5, (6, 0, 180), (0, 0, -0.1)), (0.8, (4, 0, 360), (0, 0, -0.04)), (1.1, (0, 0, 360), (0, 0, 0))],
    "chest": [(0, (0, 0, 0), None), (0.2, (-6, 0, -20), None), (0.5, (14, 0, 0), None), (1.1, (0, 0, 0), None)],
    "upperarm_r": [(0, (-6, 3, 0), None), (0.2, (-50, 70, 0), None), (0.5, (-20, 85, 0), None), (0.8, (-20, 80, 0), None), (1.1, (-6, 3, 0), None)],
    "forearm_r": [(0, (-14, 0, 0), None), (0.5, (-4, 0, 0), None), (1.1, (-14, 0, 0), None)],
    "upperarm_l": [(0, (4, -4, 0), None), (0.2, (-40, -70, 0), None), (0.5, (-10, -80, 0), None), (0.8, (-10, -80, 0), None), (1.1, (4, -4, 0), None)],
    "thigh_l": [(0, (0, 0, 0), None), (0.3, (-26, 0, 0), None), (0.7, (20, 0, 0), None), (1.1, (0, 0, 0), None)],
    "thigh_r": [(0, (0, 0, 0), None), (0.3, (20, 0, 0), None), (0.7, (-26, 0, 0), None), (1.1, (0, 0, 0), None)],
}
clip(rig, "Attack_Spin", 1.1, a, loop=False)

# Roar: rears back, chest out, head up with arms spread, then slams the cleaver butt down.
a = {
    "hips": [(0, (0, 0, 0), (0, 0, 0)), (0.5, (-10, 0, 0), (0, 0.08, 0.04)), (1.4, (-8, 0, 0), (0, 0.06, 0.03)), (2.0, (0, 0, 0), (0, 0, 0))],
    "spine_01": [(0, (0, 0, 0), None), (0.5, (-12, 0, 0), None), (1.4, (-10, 0, 0), None), (2.0, (0, 0, 0), None)],
    "chest": [(0, (0, 0, 0), None), (0.5, (-18, 0, 0), None), (0.7, (-22, 0, 0), None), (1.4, (-20, 0, 0), None), (2.0, (0, 0, 0), None)],
    "head": [(0, (0, 0, 0), None), (0.5, (-28, 0, 0), None), (0.7, (-34, 0, 0), None), (1.2, (-30, 0, 4), None), (1.4, (-16, 0, 0), None), (2.0, (0, 0, 0), None)],
    "upperarm_r": [(0, (-6, 3, 0), None), (0.5, (-20, 60, 0), None), (1.4, (-30, 55, 0), None), (2.0, (-6, 3, 0), None)],
    "upperarm_l": [(0, (4, -4, 0), None), (0.5, (-20, -65, 0), None), (1.4, (-30, -60, 0), None), (2.0, (4, -4, 0), None)],
    "forearm_r": [(0, (-14, 0, 0), None), (0.5, (-40, 0, 0), None), (2.0, (-14, 0, 0), None)],
    "forearm_l": [(0, (-14, 0, 0), None), (0.5, (-40, 0, 0), None), (2.0, (-14, 0, 0), None)],
}
clip(rig, "Roar", 2.0, a, loop=False)

# Hit: flinches back, head snapping up.
a = {
    "hips": [(0, (0, 0, 0), (0, 0, 0)), (0.1, (-10, 0, 4), (0, 0.12, -0.02)), (0.45, (0, 0, 0), (0, 0, 0))],
    "chest": [(0, (0, 0, 0), None), (0.1, (-16, 0, 8), None), (0.45, (0, 0, 0), None)],
    "head": [(0, (0, 0, 0), None), (0.1, (-24, 0, -8), None), (0.45, (0, 0, 0), None)],
    "upperarm_l": [(0, (4, -4, 0), None), (0.1, (-30, -28, 0), None), (0.45, (4, -4, 0), None)],
    "upperarm_r": [(0, (-6, 3, 0), None), (0.1, (-30, 24, 0), None), (0.45, (-6, 3, 0), None)],
}
clip(rig, "Hit", 0.45, a, loop=False)

# Die: staggers, drops to the knees, topples onto his back. Hips drop to rest on the ground.
a = {
    "hips": [(0, (0, 0, 0), (0, 0, 0)), (0.3, (-10, 0, 0), (0, 0.15, -0.04)), (0.8, (-6, 0, 0), (0, 0.3, -0.42)), (1.4, (-86, 0, 0), (0, 0.78, -0.62)), (1.8, (-90, 0, 0), (0, 0.84, -0.66))],
    "spine_01": [(0, (0, 0, 0), None), (0.8, (-6, 0, 0), None), (1.8, (-4, 0, 0), None)],
    "chest": [(0, (0, 0, 0), None), (0.3, (-14, 0, 0), None), (0.8, (10, 0, 0), None), (1.8, (-6, 0, 0), None)],
    "head": [(0, (0, 0, 0), None), (0.3, (-24, 0, 0), None), (0.8, (14, 0, 0), None), (1.8, (-6, 0, 10), None)],
    "thigh_l": [(0, (0, 0, 0), None), (0.8, (-80, 0, 0), None), (1.4, (-30, 0, 8), None), (1.8, (-10, 0, 10), None)],
    "thigh_r": [(0, (0, 0, 0), None), (0.8, (-70, 0, 0), None), (1.4, (-10, 0, -10), None), (1.8, (-4, 0, -14), None)],
    "shin_l": [(0, (0, 0, 0), None), (0.8, (100, 0, 0), None), (1.4, (30, 0, 0), None), (1.8, (14, 0, 0), None)],
    "shin_r": [(0, (0, 0, 0), None), (0.8, (90, 0, 0), None), (1.4, (20, 0, 0), None), (1.8, (10, 0, 0), None)],
    "upperarm_l": [(0, (4, -4, 0), None), (0.8, (-20, -30, 0), None), (1.8, (-30, -60, 0), None)],
    "upperarm_r": [(0, (-6, 3, 0), None), (0.8, (-30, 20, 0), None), (1.8, (-10, 55, 0), None)],
}
clip(rig, "Die", 1.8, a, loop=False)

export(rig, body, OUT + "cinder_warlord_src.glb")
os.remove(OUT + "cinder_warlord_tex.png") if os.path.exists(OUT + "cinder_warlord_tex.png") else None
print("TRIS", tris(body))
