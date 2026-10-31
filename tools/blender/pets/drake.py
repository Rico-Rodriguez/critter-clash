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

SCALE = mat("drake_scale", "3a2e2a")
DARK = mat("drake_dark", "1e1816")
BELLY = mat("drake_belly", "8f4e2a")
WING = mat("drake_wing", "2a1d1a")
WING_HI = mat("drake_wing_hi", "6e2a1a")
HORN = mat("drake_horn", "a89e88")
CLAW = mat("drake_claw", "141414")
EYE = mat("drake_eye", "ffb03a")
PUPIL = mat("drake_pupil", "0d0a09")

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

# Angular build: hard facets, a keel and a ridge, swept horns, barbed wings.
# Tuned by hand: every side and corner as written.
import common
common.SIDES, common.BLOB_SUB = 1.0, 0


def scallop(pts, wrist, k=0.35):
    """Between each pair of trailing points, a cut pulled toward the wrist."""
    out = [pts[0]]
    for a, b in zip(pts, pts[1:]):
        mid = [(a[i] + b[i]) / 2 for i in range(3)]
        out.append(tuple(mid[i] + (wrist[i] - mid[i]) * k for i in range(3)))
        out.append(b)
    return out


# Body: a deep keeled chest narrowing hard to the hips; belly, flank and back
# each take their own flat band of colour.
body = tube("body", [((0, 0.47, 1.0), 0.07, 0.08), ((0, 0.32, 1.0), 0.15, 0.17), ((0, 0.12, 1.02), 0.2, 0.24),
                     ((0, -0.1, 1.05), 0.22, 0.27), ((0, -0.27, 1.1), 0.16, 0.21), ((0, -0.37, 1.16), 0.11, 0.14)], SCALE, n=6)
two_tone(body, BELLY, DARK)
bind(body, ["hips", "spine_01", "neck_01"])
neck = tube("neck", [((0, -0.3, 1.1), 0.13, 0.15), ((0, -0.42, 1.26), 0.1, 0.12), ((0, -0.52, 1.42), 0.085, 0.1),
                     ((0, -0.6, 1.56), 0.08, 0.09)], SCALE, n=6)
two_tone(neck, BELLY, DARK, down=-0.2)
bind(neck, ["spine_01", "neck_01", "neck_02"])
# Head: a long blade of a skull ending in a point, the jaw a wedge below.
head = tube("head", [((0, -0.5, 1.6), 0.07, 0.08), ((0, -0.58, 1.615), 0.115, 0.1), ((0, -0.7, 1.6), 0.1, 0.08),
                     ((0, -0.86, 1.565), 0.06, 0.055), ((0, -1.0, 1.54), 0.02, 0.025)], SCALE, n=6)
two_tone(head, BELLY, DARK, down=-0.6, up=0.75)
bind(head, ["head"])
jaw = tube("jaw", [((0, -0.6, 1.5), 0.075, 0.04), ((0, -0.78, 1.48), 0.055, 0.03), ((0, -0.96, 1.475), 0.018, 0.015)], BELLY, n=4)
bind(jaw, ["jaw"])
for s, x in (("l", 1), ("r", -1)):
    # A heavy brow plate over a narrow, slanted eye.
    bind(blob("brow_" + s, (x * 0.08, -0.68, 1.665), (0.06, 0.15, 0.025), DARK, rot=(0.22, x * -0.2, x * -0.3)), ["head"])
    bind(blob("eye_" + s, (x * 0.09, -0.72, 1.62), (0.016, 0.06, 0.018), EYE, rot=(0.3, 0, x * -0.25)), ["head"])
    bind(blob("pupil_" + s, (x * 0.098, -0.72, 1.62), (0.006, 0.03, 0.014), PUPIL, rot=(0.3, 0, x * -0.25)), ["head"])
    # Long horns swept back past the neck, a shorter pair below, a cheek spur.
    bind(cone("horn_" + s, (x * 0.06, -0.57, 1.67), (x * 0.17, -0.16, 1.86), 0.042, HORN, n=4, bend=(x * 0.03, 0, 0.06)), ["head"])
    bind(cone("horn2_" + s, (x * 0.1, -0.6, 1.6), (x * 0.24, -0.36, 1.62), 0.026, HORN, n=4, bend=(0, 0, 0.02)), ["head"])
    bind(cone("spur_" + s, (x * 0.07, -0.66, 1.5), (x * 0.17, -0.5, 1.46), 0.02, HORN, n=3), ["jaw"])
    bind(blob("nostril_" + s, (x * 0.022, -0.955, 1.565), (0.012, 0.02, 0.006), CLAW), ["head"])
    for k in range(3):
        bind(cone("tooth_%s%d" % (s, k), (x * 0.04, -0.8 - k * 0.055, 1.525), (x * 0.04, -0.8 - k * 0.055, 1.48), 0.01, HORN, n=3), ["head"])
# Back ridge: tall blades raked back, from the skull to the tail tip.
ridge = [((0, -0.56, 1.67), 0.035, "head"), ((0, -0.47, 1.49), 0.035, "neck_02"), ((0, -0.38, 1.32), 0.045, "neck_01"),
         ((0, -0.22, 1.33), 0.06, "spine_01"), ((0, -0.02, 1.31), 0.065, "spine_01"), ((0, 0.18, 1.25), 0.055, "hips"),
         ((0, 0.38, 1.12), 0.045, "hips"), ((0, 0.6, 1.06), 0.035, "tail_01"), ((0, 0.82, 1.01), 0.03, "tail_02"), ((0, 1.04, 1.02), 0.025, "tail_03")]
for i, (p, r, bn) in enumerate(ridge):
    bind(cone("spike_%d" % i, p, (p[0], p[1] + r * 2.4, p[2] + r * 2.4), r, HORN, n=3), [bn])
# Tail: faceted, ending in a barbed arrowhead.
tail = tube("tail", [((0, 0.42, 1.0), 0.1, 0.11), ((0, 0.66, 0.955), 0.075, 0.08), ((0, 0.96, 0.925), 0.05, 0.055),
                     ((0, 1.22, 0.98), 0.03, 0.035), ((0, 1.42, 1.09), 0.015, 0.015)], SCALE, n=6)
two_tone(tail, BELLY, DARK)
bind(tail, ["hips", "tail_01", "tail_02", "tail_03", "tail_04"])
bind(sheet("spade", [(0, 1.4, 1.08), (0.13, 1.44, 1.1), (0.05, 1.52, 1.16), (0, 1.74, 1.28), (-0.05, 1.52, 1.16), (-0.13, 1.44, 1.1)],
           WING, 0.025), ["tail_04"])
# Legs folded under in flight, hooked claws.
for s, x in (("l", 1), ("r", -1)):
    for leg, (top, knee, foot) in (("f", ((0.13, -0.22, 1.0), (0.17, -0.18, 0.86), (0.16, -0.04, 0.84))),
                                   ("b", ((0.15, 0.26, 0.98), (0.2, 0.34, 0.83), (0.18, 0.56, 0.82)))):
        P = lambda v: (x * v[0], v[1], v[2])
        r = 0.065 if leg == "b" else 0.05
        bind(tube("leg_%s%s" % (leg, s), [(P(top), r, r), (P(knee), r * 0.75, r * 0.8), (P(foot), r * 0.45, r * 0.45)], SCALE, n=5),
             ["leg_%s%s" % (leg, s), "spine_01" if leg == "f" else "hips"])
        for k in (-1, 0, 1):
            f = P(foot)
            bind(cone("claw_%s%s%d" % (leg, s, k), (f[0] + k * 0.02, f[1], f[2]), (f[0] + k * 0.035, f[1] + 0.1, f[2] - 0.05), 0.014, CLAW, n=3,
                      bend=(0, 0.02, 0.02)), ["leg_%s%s" % (leg, s)])
# Wings: a bony arm, long finger struts, and a membrane cut into points.
for s, x in (("l", 1), ("r", -1)):
    P = lambda v: (x * v[0], v[1], v[2])
    bones = ["wing_%s_1" % s, "wing_%s_2" % s, "wing_%s_3" % s]
    bind(tube("arm_" + s, [(P((0.13, -0.14, 1.19)), 0.05, 0.05), (P((0.58, -0.06, 1.42)), 0.032, 0.036),
                          (P((1.02, 0.08, 1.34)), 0.022, 0.025), (P((1.38, 0.24, 1.56)), 0.005, 0.005)], SCALE, n=4), bones)
    wrist = P((1.02, 0.08, 1.34))
    tips = [P((1.38, 0.24, 1.56)), P((1.3, 0.56, 1.02)), P((0.92, 0.7, 0.9)), P((0.52, 0.58, 0.98)), P((0.18, 0.34, 1.02))]
    edge = scallop(tips, wrist)
    bind(sheet("membrane_" + s, [P((0.58, -0.06, 1.42)), wrist] + edge + [P((0.14, -0.12, 1.18))], WING, 0.018), bones + ["spine_01"])
    for k, t in enumerate(tips[1:4]):
        bind(cone("finger_%s%d" % (s, k), wrist, t, 0.016, WING_HI, n=3), bones)
    bind(cone("thumb_" + s, wrist, P((1.06, -0.1, 1.46)), 0.022, HORN, n=3, bend=(0, -0.02, 0.03)), [bones[1]])

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
