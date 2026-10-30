# Ember Drake: a young dragon at real proportions (long neck and tail, wide
# wings), hovering. Writes assets/sidekicks/dragon_src.glb plus its texture
# and the Ash Wyrm textures.
# Run: <blender python> tools/blender/pets/drake.py -- <repo root>
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *

ROOT = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(ROOT, "assets/sidekicks/")
reset()

SCALE = mat("drake_scale", "b9472a")
DARK = mat("drake_dark", "7c2a1d")
BELLY = mat("drake_belly", "e6b46a")
WING = mat("drake_wing", "8e2c22")
WING_HI = mat("drake_wing_hi", "c45a34")
HORN = mat("drake_horn", "eadcbf")
CLAW = mat("drake_claw", "2b2523")
EYE = mat("drake_eye", "ffc63d")
PUPIL = mat("drake_pupil", "1b1513")

# Skeleton (Blender: -Y is forward, Z up). Wings and legs exist for both sides.
S = [
    ("hips", (0, 0.35, 1.0), (0, 0.05, 1.03), None),
    ("spine_01", (0, 0.05, 1.03), (0, -0.3, 1.1), "hips"),
    ("neck_01", (0, -0.3, 1.1), (0, -0.48, 1.34), "spine_01"),
    ("neck_02", (0, -0.48, 1.34), (0, -0.58, 1.54), "neck_01"),
    ("head", (0, -0.58, 1.54), (0, -0.96, 1.54), "neck_02"),
    ("jaw", (0, -0.64, 1.48), (0, -0.95, 1.44), "head"),
    ("tail_01", (0, 0.35, 1.0), (0, 0.66, 0.95), "hips"),
    ("tail_02", (0, 0.66, 0.95), (0, 0.96, 0.92), "tail_01"),
    ("tail_03", (0, 0.96, 0.92), (0, 1.22, 0.98), "tail_02"),
    ("tail_04", (0, 1.22, 0.98), (0, 1.44, 1.1), "tail_03"),
]
for s, x in (("l", 1), ("r", -1)):
    S += [
        ("wing_%s_1" % s, (x * 0.15, -0.14, 1.2), (x * 0.58, -0.06, 1.42), "spine_01"),
        ("wing_%s_2" % s, (x * 0.58, -0.06, 1.42), (x * 1.02, 0.08, 1.34), "wing_%s_1" % s),
        ("wing_%s_3" % s, (x * 1.02, 0.08, 1.34), (x * 1.32, 0.24, 1.5), "wing_%s_2" % s),
        ("leg_f%s" % s, (x * 0.13, -0.22, 0.98), (x * 0.16, -0.06, 0.84), "spine_01"),
        ("leg_b%s" % s, (x * 0.15, 0.28, 0.95), (x * 0.18, 0.56, 0.82), "hips"),
    ]
rig = armature(S)

# Body: chest broad, hips narrower, two-tone with a plated belly.
body = tube("body", [((0, 0.47, 1.0), 0.1, 0.1), ((0, 0.32, 1.0), 0.17, 0.17), ((0, 0.12, 1.02), 0.22, 0.21),
                     ((0, -0.1, 1.05), 0.23, 0.22), ((0, -0.27, 1.1), 0.19, 0.19), ((0, -0.37, 1.16), 0.13, 0.14)], SCALE, n=12)
two_tone(body, BELLY, DARK)
bind(body, ["hips", "spine_01", "neck_01"])
neck = tube("neck", [((0, -0.3, 1.1), 0.14, 0.14), ((0, -0.42, 1.26), 0.11, 0.11), ((0, -0.52, 1.42), 0.095, 0.095),
                     ((0, -0.6, 1.56), 0.09, 0.09)], SCALE, n=10)
two_tone(neck, BELLY, DARK, down=-0.2)
bind(neck, ["spine_01", "neck_01", "neck_02"])
# Head: a long wedge with a brow, the jaw hinged below.
head = tube("head", [((0, -0.5, 1.6), 0.07, 0.08), ((0, -0.58, 1.6), 0.115, 0.105), ((0, -0.7, 1.585), 0.11, 0.09),
                     ((0, -0.84, 1.56), 0.08, 0.065), ((0, -0.97, 1.545), 0.058, 0.048)], SCALE, n=10)
two_tone(head, BELLY, DARK, down=-0.6, up=0.75)
bind(head, ["head"])
jaw = tube("jaw", [((0, -0.6, 1.5), 0.075, 0.035), ((0, -0.78, 1.48), 0.06, 0.03), ((0, -0.95, 1.47), 0.042, 0.022)], BELLY, n=8)
bind(jaw, ["jaw"])
for s, x in (("l", 1), ("r", -1)):
    bind(blob("brow_" + s, (x * 0.075, -0.66, 1.66), (0.05, 0.08, 0.025), DARK, rot=(0.15, 0, x * -0.25)), ["head"])
    bind(blob("eye_" + s, (x * 0.088, -0.71, 1.615), (0.022, 0.035, 0.022), EYE, sub=1), ["head"])
    bind(blob("pupil_" + s, (x * 0.104, -0.715, 1.615), (0.006, 0.02, 0.016), PUPIL, sub=1), ["head"])
    bind(cone("horn_" + s, (x * 0.06, -0.56, 1.66), (x * 0.13, -0.3, 1.82), 0.035, HORN, bend=(x * 0.02, 0, 0.08)), ["head"])
    bind(cone("horn2_" + s, (x * 0.1, -0.6, 1.6), (x * 0.2, -0.42, 1.64), 0.022, HORN, bend=(0, 0, 0.03)), ["head"])
    bind(blob("nostril_" + s, (x * 0.03, -0.955, 1.585), (0.012, 0.012, 0.008), CLAW, sub=1), ["head"])
    for k in range(3):
        # Teeth along the upper lip.
        bind(cone("tooth_%s%d" % (s, k), (x * 0.042, -0.82 - k * 0.05, 1.525), (x * 0.042, -0.82 - k * 0.05, 1.495), 0.008, HORN, n=4), ["head"])
# Back ridge: spikes from the skull to the tail tip.
ridge = [((0, -0.56, 1.67), 0.03, "head"), ((0, -0.47, 1.47), 0.03, "neck_02"), ((0, -0.38, 1.3), 0.035, "neck_01"),
         ((0, -0.22, 1.29), 0.045, "spine_01"), ((0, -0.02, 1.26), 0.05, "spine_01"), ((0, 0.18, 1.22), 0.045, "hips"),
         ((0, 0.38, 1.12), 0.035, "hips"), ((0, 0.6, 1.06), 0.03, "tail_01"), ((0, 0.82, 1.01), 0.025, "tail_02"), ((0, 1.04, 1.02), 0.02, "tail_03")]
for i, (p, r, bn) in enumerate(ridge):
    bind(cone("spike_%d" % i, p, (p[0], p[1] + r * 1.4, p[2] + r * 2.2), r, HORN, n=4), [bn])
# Tail: tapering, curling up at the tip into a spade.
tail = tube("tail", [((0, 0.42, 1.0), 0.11, 0.11), ((0, 0.66, 0.955), 0.08, 0.08), ((0, 0.96, 0.925), 0.055, 0.055),
                     ((0, 1.22, 0.98), 0.035, 0.035), ((0, 1.42, 1.09), 0.02, 0.02)], SCALE, n=10)
two_tone(tail, BELLY, DARK)
bind(tail, ["hips", "tail_01", "tail_02", "tail_03", "tail_04"])
bind(sheet("spade", [(0, 1.42, 1.09), (0.08, 1.5, 1.14), (0, 1.64, 1.22), (-0.08, 1.5, 1.14)], WING, 0.025), ["tail_04"])
# Legs folded under the body in flight, with pale claws.
for s, x in (("l", 1), ("r", -1)):
    # Tucked back like a bird's in flight.
    for leg, (top, knee, foot) in (("f", ((0.13, -0.22, 1.0), (0.17, -0.18, 0.86), (0.16, -0.04, 0.84))),
                                   ("b", ((0.15, 0.26, 0.98), (0.2, 0.34, 0.83), (0.18, 0.56, 0.82)))):
        P = lambda v: (x * v[0], v[1], v[2])
        r = 0.065 if leg == "b" else 0.05
        bind(tube("leg_%s%s" % (leg, s), [(P(top), r, r), (P(knee), r * 0.8, r * 0.8), (P(foot), r * 0.55, r * 0.5)], SCALE, n=8),
             ["leg_%s%s" % (leg, s), "spine_01" if leg == "f" else "hips"])
        for k in (-1, 0, 1):
            f = P(foot)
            bind(cone("claw_%s%s%d" % (leg, s, k), (f[0] + k * 0.02, f[1], f[2]), (f[0] + k * 0.03, f[1] + 0.07, f[2] - 0.02), 0.012, CLAW, n=4), ["leg_%s%s" % (leg, s)])
# Wings: a bony arm and a two-tone membrane between its fingers.
for s, x in (("l", 1), ("r", -1)):
    P = lambda v: (x * v[0], v[1], v[2])
    bones = ["wing_%s_1" % s, "wing_%s_2" % s, "wing_%s_3" % s]
    bind(tube("arm_" + s, [(P((0.13, -0.14, 1.19)), 0.05, 0.05), (P((0.58, -0.06, 1.42)), 0.032, 0.032),
                          (P((1.02, 0.08, 1.34)), 0.022, 0.022), (P((1.34, 0.25, 1.52)), 0.006, 0.006)], SCALE, n=8), bones)
    tip = [P((1.34, 0.25, 1.52)), P((1.2, 0.5, 1.08)), P((0.86, 0.58, 0.98)), P((0.5, 0.48, 1.04)), P((0.18, 0.3, 1.04))]
    bind(sheet("membrane_" + s, [P((0.58, -0.06, 1.42)), P((1.02, 0.08, 1.34))] + tip + [P((0.14, -0.12, 1.18))], WING, 0.018), bones + ["spine_01"])
    # Finger struts from the wrist out to the trailing points.
    for k, t in enumerate(tip[1:4]):
        bind(cone("finger_%s%d" % (s, k), P((1.02, 0.08, 1.35)), t, 0.014, WING_HI, n=5), bones)
    bind(cone("thumb_" + s, P((1.02, 0.08, 1.34)), P((1.04, -0.04, 1.42)), 0.016, HORN, n=4), [bones[1]])

drake = skin(rig, "Drake")
bake(drake, 1024, OUT + "dragon_tex.png",
     ash={"*": "4b4643", "drake_dark": "2f2b29", "drake_belly": "6d645d", "drake_wing": "3b3533", "drake_wing_hi": "524944",
          "drake_horn": "9a938a", "drake_claw": "1c1a19", "drake_eye": "ffb43a", "drake_pupil": "1c1a19",
          "emit:drake_belly": "a8360c", "emit:drake_eye": "ffa020", "emit:drake_wing_hi": "8a2a08", "emit:drake_scale": "1a0802"})

# Clips. Rotations are degrees about the rig's axes: +X pitches the nose
# down, -Y lifts the left wing (+Y lifts the right), Z turns.
def flap(t, up, down, period, lag=0.12):
    ks = {}
    for s, sg in (("l", 1), ("r", -1)):
        ks["wing_%s_1" % s] = [(0, (0, -sg * up, 0), None), (period * 0.5, (0, sg * down, 0), None), (period, (0, -sg * up, 0), None)]
        ks["wing_%s_2" % s] = [(0, (0, sg * 10, 0), None), (period * (0.5 + lag), (0, -sg * 18, 0), None), (period, (0, sg * 10, 0), None)]
        ks["wing_%s_3" % s] = [(0, (0, sg * 6, 0), None), (period * (0.5 + lag * 2), (0, -sg * 14, 0), None), (period, (0, sg * 6, 0), None)]
    return ks

idle = flap(0, 32, 26, 1.2)
idle["hips"] = [(0, (0, 0, 0), (0, 0, 0.0)), (0.6, (0, 0, 0), (0, 0, 0.06)), (1.2, (0, 0, 0), (0, 0, 0.0))]
idle["neck_01"] = [(0, (-4, 0, 0), None), (0.6, (3, 0, 0), None), (1.2, (-4, 0, 0), None)]
idle["tail_01"] = [(0, (0, 0, 6), None), (0.6, (0, 0, -6), None), (1.2, (0, 0, 6), None)]
idle["tail_03"] = [(0, (0, 0, -8), None), (0.6, (0, 0, 8), None), (1.2, (0, 0, -8), None)]
clip(rig, "Flying_Idle", 1.2, idle)

fast = flap(0, 48, 40, 0.6, 0.1)
fast["hips"] = [(0, (14, 0, 0), (0, 0, 0)), (0.3, (14, 0, 0), (0, 0, 0.05)), (0.6, (14, 0, 0), (0, 0, 0))]
fast["neck_01"] = [(0, (-12, 0, 0), None), (0.6, (-12, 0, 0), None)]
fast["tail_01"] = [(0, (-6, 0, 4), None), (0.3, (-6, 0, -4), None), (0.6, (-6, 0, 4), None)]
clip(rig, "Fast_Flying", 0.6, fast)

atk = flap(0, 30, 30, 0.7)
atk["neck_01"] = [(0, (0, 0, 0), None), (0.25, (-22, 0, 0), None), (0.4, (24, 0, 0), None), (0.7, (0, 0, 0), None)]
atk["head"] = [(0, (0, 0, 0), None), (0.25, (-10, 0, 0), None), (0.4, (8, 0, 0), None), (0.7, (0, 0, 0), None)]
atk["jaw"] = [(0, (0, 0, 0), None), (0.3, (30, 0, 0), None), (0.45, (2, 0, 0), None), (0.7, (0, 0, 0), None)]
clip(rig, "Attack", 0.7, atk, loop=False)

hit = flap(0, 20, 34, 0.45)
hit["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.12, (-16, 0, 0), (0, 0.1, 0.03)), (0.45, (0, 0, 0), (0, 0, 0))]
hit["neck_01"] = [(0, (0, 0, 0), None), (0.12, (-18, 0, 0), None), (0.45, (0, 0, 0), None)]
clip(rig, "Hit", 0.45, hit, loop=False)

sp = {}
for s, sg in (("l", 1), ("r", -1)):
    sp["wing_%s_1" % s] = [(0, (0, 0, 0), None), (0.35, (0, -sg * 50, 0), None), (0.6, (0, sg * 10, 0), None), (1.0, (0, 0, 0), None)]
    sp["wing_%s_2" % s] = [(0, (0, 0, 0), None), (0.35, (0, -sg * 10, 0), None), (1.0, (0, 0, 0), None)]
sp["hips"] = [(0, (0, 0, 0), None), (0.35, (-22, 0, 0), None), (0.6, (6, 0, 0), None), (1.0, (0, 0, 0), None)]
sp["neck_01"] = [(0, (0, 0, 0), None), (0.35, (-26, 0, 0), None), (0.55, (22, 0, 0), None), (0.85, (18, 0, 0), None), (1.0, (0, 0, 0), None)]
sp["jaw"] = [(0, (0, 0, 0), None), (0.45, (2, 0, 0), None), (0.55, (34, 0, 0), None), (0.85, (34, 0, 0), None), (1.0, (0, 0, 0), None)]
sp["tail_01"] = [(0, (0, 0, 0), None), (0.35, (14, 0, 0), None), (1.0, (0, 0, 0), None)]
clip(rig, "Special", 1.0, sp, loop=False)

export(rig, drake, OUT + "dragon_src.glb")
# The Ash Wyrm's maps keep the names sidekick_look.gd preloads; the base
# texture travels inside the .glb.
os.replace(OUT + "dragon_tex_ash.png", OUT + "dragon_ash_albedo.png")
os.replace(OUT + "dragon_tex_ash_emit.png", OUT + "dragon_ash_emission.png")
os.remove(OUT + "dragon_tex.png")
