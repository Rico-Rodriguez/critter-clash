# Mire Hag (cm_hag): a stooped swamp crone in a moss-rotted robe and drooping hat, long
# grey hair, claw hands, a hooked staff with a bile-lit lantern. Casts lanterns.
# Writes assets/foes/mire_hag_src.glb.
# Run: python3 tools/blender/foes/mire_hag.py -- <repo root>
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foe_common import *

reset()
SKIN = mat("hag_skin", "76845a")
SKIN_D = mat("hag_skin_d", "56633f")
ROBE = mat("hag_robe", "34402a")
ROBE_D = mat("hag_robe_d", "1f261a")
ROBE_L = mat("hag_robe_l", "5a5e2c")
RUST = mat("hag_rust", "6a3e24")
HAT = mat("hag_hat", "2a3020")
HAIR = mat("hag_hair", "8d8f7c")
EYE = mat("hag_eye", "e8c43a")
TOOTH = mat("hag_tooth", "b0a888")
WOOD = mat("hag_wood", "3b2a20")
IRON = mat("hag_iron", "2c2c2a")
GLOW = mat("hag_glow", "f0a030")
BILE = mat("hag_bile", "a8b030")

S = [
    ("hips", (0, 0.05, 0.75), (0, 0.05, 0.9), None),
    ("spine_01", (0, 0.05, 0.9), (0, -0.06, 1.1), "hips"),
    ("spine_02", (0, -0.06, 1.1), (0, -0.18, 1.3), "spine_01"),
    ("neck", (0, -0.18, 1.3), (0, -0.3, 1.38), "spine_02"),
    ("head", (0, -0.3, 1.38), (0, -0.4, 1.5), "neck"),
]
for s, x in (("l", 1), ("r", -1)):
    S += [
        ("thigh_" + s, (x * 0.1, 0.05, 0.75), (x * 0.1, 0.0, 0.4), "hips"),
        ("shin_" + s, (x * 0.1, 0.0, 0.4), (x * 0.1, 0.03, 0.06), "thigh_" + s),
        ("foot_" + s, (x * 0.1, 0.03, 0.06), (x * 0.1, -0.12, 0.02), "shin_" + s),
        ("upperarm_" + s, (x * 0.2, -0.14, 1.26), (x * 0.3, -0.16, 1.0), "spine_02"),
        ("forearm_" + s, (x * 0.3, -0.16, 1.0), (x * 0.27, -0.34, 0.86), "upperarm_" + s),
        ("hand_" + s, (x * 0.27, -0.34, 0.86), (x * 0.25, -0.44, 0.8), "forearm_" + s),
    ]
rig = armature(S)
common.SIDES, common.BLOB_SUB = 1.0, 0

# Robe: a ragged bell from the shoulders, mantled with rust-coloured sacking.
robe = tube("robe", [((0, 0.08, 0.14), 0.32, 0.3), ((0, 0.06, 0.5), 0.27, 0.25), ((0, 0.05, 0.8), 0.2, 0.19),
                     ((0, 0.02, 1.0), 0.19, 0.17), ((0, -0.08, 1.2), 0.2, 0.17), ((0, -0.18, 1.32), 0.13, 0.12)], ROBE, n=8, cap0=False)
two_tone(robe, ROBE_D, ROBE_L, down=-0.4, up=0.8)
bind(robe, ["hips", "spine_01", "spine_02", "thigh_l", "thigh_r"])
# Ragged hem: points of cloth round the skirt.
for k in range(10):
    a = 2 * math.pi * k / 10
    x, y = math.cos(a) * 0.3, math.sin(a) * 0.28 + 0.08
    bind(cone("hem_%d" % k, (x, y, 0.22), (x * 1.08, y * 1.04, 0.02 + (k % 3) * 0.03), 0.07, ROBE_D if k % 2 else ROBE, n=3), ["hips", "thigh_l", "thigh_r"])
bind(blob("mantle", (0, -0.1, 1.28), (0.5, 0.34, 0.1), RUST, rot=(0.25, 0, 0)), ["spine_02"])
bind(blob("hump", (0, 0.1, 1.26), (0.26, 0.22, 0.24), ROBE, rot=(-0.4, 0, 0)), ["spine_02"])
bind(blob("sash", (0, 0.0, 0.92), (0.42, 0.34, 0.06), IRON), ["hips", "spine_01"])
for k, x in enumerate((-0.14, 0.0, 0.14)):
    bind(cone("sack_%d" % k, (x, -0.17, 0.92), (x * 1.2, -0.2, 0.66), 0.03, BILE if k == 1 else RUST, n=3), ["hips"])
# Head: bald crone skull, long hooked nose, sunken eyes, heavy chin, pointed drooping hat.
head = tube("head", [((0, -0.26, 1.42), 0.08, 0.09), ((0, -0.33, 1.47), 0.12, 0.12), ((0, -0.43, 1.45), 0.11, 0.1),
                     ((0, -0.5, 1.4), 0.08, 0.07), ((0, -0.52, 1.35), 0.06, 0.05)], SKIN, n=6)
two_tone(head, SKIN_D, None, down=-0.5)
bind(head, ["head", "neck"])
bind(tube("neck", [((0, -0.16, 1.26), 0.09, 0.09), ((0, -0.26, 1.38), 0.07, 0.08)], SKIN, n=5), ["spine_02", "neck", "head"])
bind(cone("nose", (0, -0.5, 1.42), (0, -0.7, 1.28), 0.045, SKIN, n=4, bend=(0, -0.05, 0.1)), ["head"])
bind(cone("wart", (0.02, -0.6, 1.38), (0.03, -0.63, 1.37), 0.015, SKIN_D, n=3), ["head"])
bind(cone("chin", (0, -0.46, 1.34), (0, -0.56, 1.22), 0.04, SKIN, n=4, bend=(0, -0.03, 0.04)), ["head"])
bind(cone("tooth", (0.02, -0.5, 1.33), (0.02, -0.52, 1.27), 0.012, TOOTH, n=3), ["head"])
bind(cone("tooth2", (-0.025, -0.5, 1.33), (-0.025, -0.52, 1.28), 0.01, TOOTH, n=3), ["head"])
for s, x in (("l", 1), ("r", -1)):
    bind(blob("eye_" + s, (x * 0.065, -0.46, 1.455), (0.03, 0.035, 0.028), EYE, rot=(0, 0, x * -0.3)), ["head"])
    bind(blob("brow_" + s, (x * 0.07, -0.44, 1.5), (0.07, 0.07, 0.03), SKIN_D, rot=(0.1, 0, x * -0.3)), ["head"])
    bind(cone("ear_" + s, (x * 0.11, -0.34, 1.46), (x * 0.26, -0.3, 1.52), 0.04, SKIN, n=3), ["head"])
    # Long hair, hanging in rat-tails.
    for k in range(3):
        bind(cone("hair_%s%d" % (s, k), (x * (0.1 + 0.01 * k), -0.26 + k * 0.03, 1.5), (x * (0.2 + 0.03 * k), -0.1 + k * 0.05, 1.12 - k * 0.1), 0.035, HAIR, n=3,
                  bend=(x * 0.03, 0.04, 0)), ["head", "neck"])
bind(blob("brim", (0, -0.32, 1.57), (0.62, 0.6, 0.04), HAT, rot=(0.12, 0, 0)), ["head"])
bind(tube("hatcone", [((0, -0.32, 1.58), 0.2, 0.2), ((0, -0.3, 1.74), 0.14, 0.14), ((0, -0.2, 1.88), 0.08, 0.08), ((0, -0.04, 1.94), 0.03, 0.03)], HAT, n=6), ["head"])
bind(tube("hatband", [((0, -0.32, 1.6), 0.215, 0.215), ((0, -0.32, 1.65), 0.2, 0.2)], ROBE_L, n=6), ["head"])
# Arms: long, knotted, clawed.
for s, x in (("l", 1), ("r", -1)):
    P = lambda v: (x * v[0], v[1], v[2])
    arm = tube("arm_" + s, [(P((0.18, -0.12, 1.28)), 0.07, 0.07), (P((0.3, -0.16, 1.0)), 0.05, 0.05), (P((0.27, -0.34, 0.86)), 0.04, 0.04),
                            (P((0.25, -0.44, 0.8)), 0.04, 0.04)], ROBE, n=5)
    bind(arm, ["spine_02", "upperarm_" + s, "forearm_" + s, "hand_" + s])
    bind(tube("wrist_" + s, [(P((0.27, -0.34, 0.86)), 0.04, 0.04), (P((0.25, -0.44, 0.8)), 0.035, 0.035)], SKIN, n=5), ["forearm_" + s, "hand_" + s])
    for k in (-1, 0, 1):
        h = P((0.25, -0.44, 0.8))
        bind(cone("claw_%s%d" % (s, k), (h[0] + k * 0.025, h[1], h[2]), (h[0] + k * 0.04, h[1] - 0.12, h[2] - 0.05), 0.013, SKIN_D, n=3, bend=(0, 0, -0.02)), ["hand_" + s])
    f = P((0.1, 0.0, 0.05))
    bind(tube("leg_" + s, [(P((0.1, 0.0, 0.3)), 0.05, 0.05), (P((0.1, 0.03, 0.06)), 0.03, 0.03), (P((0.1, -0.02, 0.03)), 0.04, 0.04)], SKIN, n=5), ["thigh_" + s, "shin_" + s, "foot_" + s])
    bind(blob("foot_" + s, P((0.1, -0.1, 0.03)), (0.09, 0.2, 0.05), SKIN_D), ["foot_" + s])
# Staff held in the right hand: a gnarled shaft with a hook, a lantern hanging from it.
bind(tube("staff", [((-0.26, -0.4, 0.0), 0.02, 0.02), ((-0.26, -0.4, 1.0), 0.026, 0.026), ((-0.26, -0.42, 1.7), 0.03, 0.03)], WOOD, n=5), ["hand_r"])
bind(tube("hook", [((-0.26, -0.42, 1.7), 0.025, 0.025), ((-0.26, -0.52, 1.78), 0.02, 0.02), ((-0.26, -0.62, 1.74), 0.015, 0.015), ((-0.26, -0.62, 1.68), 0.01, 0.01)], WOOD, n=4), ["hand_r"])
bind(blob("lantern", (-0.26, -0.62, 1.54), (0.12, 0.12, 0.16), IRON), ["hand_r"])
bind(blob("flame", (-0.26, -0.62, 1.54), (0.16, 0.08, 0.1), GLOW), ["hand_r"])
bind(blob("flame2", (-0.26, -0.62, 1.54), (0.08, 0.16, 0.1), GLOW), ["hand_r"])
bind(blob("lantern_cap", (-0.26, -0.62, 1.64), (0.15, 0.15, 0.03), IRON), ["hand_r"])
bind(blob("lantern_base", (-0.26, -0.62, 1.44), (0.14, 0.14, 0.03), IRON), ["hand_r"])
bind(tube("chain", [((-0.26, -0.62, 1.68), 0.008, 0.008), ((-0.26, -0.62, 1.74), 0.008, 0.008)], IRON, n=3), ["hand_r"])

hag = skin(rig, "Hag")

def walk(period, stride, bob, lean, arm):
    c = {}
    for s, ph in (("l", 0.0), ("r", 0.5)):
        c["thigh_" + s] = osc(period, {0: (stride, ph)})
        c["shin_" + s] = osc(period, {0: (stride * 0.8, ph + 0.2)}, base=(10, 0, 0))
        c["foot_" + s] = osc(period, {0: (stride * 0.4, ph + 0.35)})
    c["upperarm_l"] = osc(period, {0: (arm, 0.5), 1: (-6, 0)})
    c["forearm_l"] = osc(period, {0: (arm * 0.5, 0.75)}, base=(-30, 0, 0))
    c["upperarm_r"] = osc(period, {0: (arm * 0.3, 0.0)}, base=(-20, 0, 0))
    c["forearm_r"] = osc(period, {0: (arm * 0.2, 0.2)}, base=(-30, 0, 0))
    c["hand_r"] = [(0, (50 - 0, 0, 0), None), (period, (50, 0, 0), None)]   # keeps the staff upright
    c["hips"] = osc(period, {1: (4, 0), 2: (5, 0.25)}, base=(lean, 0, 0), loc={2: (bob, 0.0)})
    c["spine_02"] = osc(period, {2: (-6, 0.25), 1: (-3, 0)}, base=(lean * 0.6, 0, 0))
    c["head"] = osc(period, {0: (4, 0.2), 1: (4, 0.5)}, base=(-lean * 0.8, 0, 0))
    return c

idle = {
    "hips": osc(2.0, {1: (2, 0)}, loc={2: (0.01, 0)}),
    "spine_01": osc(2.0, {0: (2, 0.1)}),
    "spine_02": osc(2.0, {0: (2, 0.2), 2: (3, 0)}, base=(6, 0, 0)),
    "head": osc(2.0, {2: (16, 0.0), 1: (6, 0.5), 0: (3, 0.3)}, base=(-4, 0, 0)),
    "upperarm_l": osc(2.0, {0: (8, 0.25), 1: (-6, 0.0)}, base=(-30, 0, 0)),
    "forearm_l": osc(2.0, {0: (14, 0.4)}, base=(-40, 0, 0)),
    "hand_l": osc(2.0, {0: (18, 0.6)}),
    "upperarm_r": osc(2.0, {0: (2, 0.25)}, base=(-20, 0, 0)),
    "forearm_r": [(0, (-30, 0, 0), None), (2.0, (-30, 0, 0), None)],
    "hand_r": [(0, (50, 0, 0), None), (2.0, (50, 0, 0), None)],
}
clip(rig, "Idle", 2.0, idle)
clip(rig, "Walk", 1.0, walk(1.0, 22, 0.02, 10, 18))
clip(rig, "Run", 0.6, walk(0.6, 34, 0.04, 18, 30))

def hold(*frames):
    return pose(*frames)

atk = {
    "hips": pose((0, (0, 0, 0), (0, 0, 0)), (0.3, (-8, 0, 10), (0, 0.04, 0)), (0.5, (14, 0, -12), (0, -0.1, -0.03)), (1.0, (0, 0, 0), (0, 0, 0))),
    "spine_02": pose((0, (6, 0, 0)), (0.3, (-10, 0, 20)), (0.5, (24, 0, -24)), (1.0, (6, 0, 0))),
    "head": pose((0, (-4, 0, 0)), (0.3, (-14, 0, 0)), (0.5, (16, 0, 0)), (1.0, (-4, 0, 0))),
    "upperarm_l": pose((0, (-30, 0, 0)), (0.3, (-150, -25, 0)), (0.5, (-95, 0, 0)), (0.7, (-70, 0, 0)), (1.0, (-30, 0, 0))),
    "forearm_l": pose((0, (-40, 0, 0)), (0.3, (-30, 0, 0)), (0.5, (-6, 0, 0)), (1.0, (-40, 0, 0))),
    "hand_l": pose((0, (0, 0, 0)), (0.3, (-30, 0, 0)), (0.5, (30, 0, 0)), (1.0, (0, 0, 0))),
    "upperarm_r": pose((0, (-20, 0, 0)), (0.3, (-40, 0, 0)), (0.5, (-50, 0, 0)), (1.0, (-20, 0, 0))),
}
clip(rig, "Attack", 1.0, atk, loop=False)

cast = {
    "hips": pose((0, (0, 0, 0), (0, 0, 0)), (0.45, (-6, 0, 0), (0, 0.05, 0.03)), (0.8, (-6, 0, 0), (0, 0.05, 0.03)), (1.3, (0, 0, 0), (0, 0, 0))),
    "spine_02": pose((0, (6, 0, 0)), (0.45, (-22, 0, 0)), (0.8, (-24, 0, 0)), (1.3, (6, 0, 0))),
    "head": pose((0, (-4, 0, 0)), (0.45, (-18, 0, 0)), (0.8, (-14, 0, 0)), (1.3, (-4, 0, 0))),
    "upperarm_l": pose((0, (-30, 0, 0)), (0.45, (-130, -50, 0)), (0.8, (-130, -50, 0)), (1.3, (-30, 0, 0))),
    "upperarm_r": pose((0, (-20, 0, 0)), (0.45, (-90, 50, 0)), (0.8, (-100, 50, 0)), (1.3, (-20, 0, 0))),
    "forearm_l": pose((0, (-40, 0, 0)), (0.45, (-20, 0, 0)), (1.3, (-40, 0, 0))), "forearm_r": pose((0, (-30, 0, 0)), (0.45, (-20, 0, 0)), (1.3, (-30, 0, 0))),
    "hand_l": osc(1.3, {0: (25, 0)}, n=6),
}
clip(rig, "Cast", 1.3, cast, loop=False)

hit = {
    "hips": pose((0, (0, 0, 0), (0, 0, 0)), (0.1, (-10, 0, 6), (0, 0.08, -0.02)), (0.45, (0, 0, 0), (0, 0, 0))),
    "spine_02": pose((0, (6, 0, 0)), (0.1, (-22, 0, -10)), (0.45, (6, 0, 0))),
    "head": pose((0, (-4, 0, 0)), (0.1, (-30, 0, 16)), (0.45, (-4, 0, 0))),
    "upperarm_l": pose((0, (-30, 0, 0)), (0.1, (-50, -50, 0)), (0.45, (-30, 0, 0))),
    "upperarm_r": pose((0, (-20, 0, 0)), (0.1, (-30, 40, 0)), (0.45, (-20, 0, 0))),
}
clip(rig, "Hit", 0.45, hit, loop=False)

die = {
    "hips": pose((0, (0, 0, 0), (0, 0, 0)), (0.3, (6, 0, 4), (0, 0, -0.18)), (0.7, (10, 0, 6), (0, -0.05, -0.5)), (1.4, (8, 0, 8), (0, -0.05, -0.52))),
    "spine_01": pose((0, (0, 0, 0)), (0.7, (20, 0, 0)), (1.4, (24, 0, 0))),
    "spine_02": pose((0, (6, 0, 0)), (0.5, (30, 0, 6)), (1.4, (44, 0, 10))),
    "head": pose((0, (-4, 0, 0)), (0.3, (-26, 0, 0)), (0.9, (20, 0, 14)), (1.4, (30, 0, 14))),
    "thigh_l": pose((0, (0, 0, 0)), (0.7, (-84, 0, 0)), (1.4, (-84, 0, 0))), "thigh_r": pose((0, (0, 0, 0)), (0.7, (-84, 0, 0)), (1.4, (-84, 0, 0))),
    "shin_l": pose((0, (0, 0, 0)), (0.7, (92, 0, 0)), (1.4, (92, 0, 0))), "shin_r": pose((0, (0, 0, 0)), (0.7, (92, 0, 0)), (1.4, (92, 0, 0))),
    "upperarm_l": pose((0, (-30, 0, 0)), (0.5, (-60, -40, 0)), (1.4, (-30, -20, 0))), "upperarm_r": pose((0, (-20, 0, 0)), (0.5, (-40, 40, 0)), (1.4, (-10, 20, 0))),
}
clip(rig, "Death", 1.4, die, loop=False)

finish(rig, hag, "mire_hag")
