# Night Bat: a big vampire bat at real proportions, dark fur with a rusty
# chest, blood-red wing membranes on long finger bones, tall ears and fangs.
# Hovers on beating wings. Writes assets/sidekicks/bat_src.glb.
# Run: <blender python> tools/blender/pets/bat.py -- <repo root>
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *

ROOT = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(ROOT, "assets/sidekicks/")
reset()

FUR = mat("bat_fur", "2e2226")
DEEP = mat("bat_deep", "1a1215")
CHEST = mat("bat_chest", "45282a")
SKIN = mat("bat_skin", "241619")
WEB = mat("bat_web", "4a1c25")
WEB_D = mat("bat_web_d", "2e1018")
INNER = mat("bat_inner", "7a3a44")
EYE = mat("bat_eye", "ff3b2e")
PUPIL = mat("bat_pupil", "1a0c0e")
FANG = mat("bat_fang", "c9bfa8")
MOUTH = mat("bat_mouth", "2a1216")

S = [
    ("hips", (0, 0.12, 0.5), (0, -0.02, 0.55), None),
    ("spine_01", (0, -0.02, 0.55), (0, -0.12, 0.6), "hips"),
    ("neck_01", (0, -0.12, 0.6), (0, -0.16, 0.66), "spine_01"),
    ("head", (0, -0.16, 0.66), (0, -0.3, 0.68), "neck_01"),
    ("jaw", (0, -0.21, 0.635), (0, -0.3, 0.62), "head"),
    ("tail_01", (0, 0.14, 0.5), (0, 0.3, 0.45), "hips"),
]
for s, x in (("l", 1), ("r", -1)):
    S += [
        ("ear_%s" % s, (x * 0.05, -0.18, 0.72), (x * 0.1, -0.16, 0.86), "head"),
        ("wing_%s_1" % s, (x * 0.07, -0.08, 0.6), (x * 0.3, -0.04, 0.63), "spine_01"),
        ("wing_%s_2" % s, (x * 0.3, -0.04, 0.63), (x * 0.56, 0.02, 0.6), "wing_%s_1" % s),
        ("wing_%s_3" % s, (x * 0.56, 0.02, 0.6), (x * 0.76, 0.1, 0.58), "wing_%s_2" % s),
        ("leg_%s" % s, (x * 0.06, 0.12, 0.48), (x * 0.08, 0.28, 0.42), "hips"),
    ]
rig = armature(S)

body = tube("body", [((0, 0.22, 0.48), 0.035, 0.035), ((0, 0.13, 0.5), 0.1, 0.09), ((0, 0.01, 0.55), 0.125, 0.12),
                     ((0, -0.09, 0.6), 0.105, 0.1), ((0, -0.15, 0.64), 0.075, 0.075)], FUR, n=12)
two_tone(body, CHEST, DEEP, down=-0.3, up=0.65)
bind(body, ["hips", "spine_01"])
# A shaggy ruff where the neck meets the shoulders.
for k in range(5):
    a = (k - 2) * 0.55
    bind(cone("ruff_%d" % k, (math.sin(a) * 0.07, -0.1, 0.6 + math.cos(a) * 0.05), (math.sin(a) * 0.12, -0.04, 0.6 + math.cos(a) * 0.09), 0.04, FUR, n=4), ["spine_01"])
head = tube("head", [((0, -0.13, 0.665), 0.06, 0.06), ((0, -0.19, 0.68), 0.08, 0.075), ((0, -0.25, 0.67), 0.062, 0.056),
                     ((0, -0.29, 0.655), 0.035, 0.032), ((0, -0.31, 0.65), 0.012, 0.012)], FUR, n=10)
two_tone(head, CHEST, DEEP, down=-0.5, up=0.7)
bind(head, ["head"])
# Pug nose leaf and the mouth: fangs on the upper jaw, the lower one hinges.
bind(blob("nose", (0, -0.305, 0.665), (0.04, 0.02, 0.035), SKIN, sub=1), ["head"])
bind(tube("lip", [((0, -0.2, 0.635), 0.05, 0.016), ((0, -0.27, 0.63), 0.035, 0.012), ((0, -0.3, 0.632), 0.01, 0.006)], MOUTH, n=8), ["jaw"])
for s, x in (("l", 1), ("r", -1)):
    bind(cone("fang_" + s, (x * 0.017, -0.29, 0.643), (x * 0.018, -0.293, 0.618), 0.006, FANG, n=5), ["head"])
    bind(blob("eye_" + s, (x * 0.045, -0.245, 0.69), (0.03, 0.026, 0.03), EYE, sub=1), ["head"])
    bind(blob("pupil_" + s, (x * 0.054, -0.26, 0.692), (0.012, 0.012, 0.022), PUPIL, sub=1), ["head"])
    # Tall pointed ears, furred outside and pink within.
    bind(tube("ear_" + s, [((x * 0.05, -0.175, 0.71), 0.04, 0.015), ((x * 0.075, -0.17, 0.79), 0.042, 0.014),
                           ((x * 0.1, -0.16, 0.86), 0.022, 0.01), ((x * 0.11, -0.155, 0.9), 0.004, 0.004)], FUR, n=8), ["ear_" + s])
    bind(sheet("ear_in_" + s, [(x * 0.052, -0.19, 0.72), (x * 0.09, -0.188, 0.79), (x * 0.105, -0.18, 0.87), (x * 0.07, -0.186, 0.8), (x * 0.045, -0.19, 0.76)], INNER, 0.006), ["ear_" + s])
    # Hind legs trailing back, with hooked claws.
    bind(tube("leg_" + s, [((x * 0.06, 0.1, 0.49), 0.035, 0.035), ((x * 0.075, 0.2, 0.45), 0.02, 0.02), ((x * 0.08, 0.28, 0.42), 0.014, 0.014)], SKIN, n=6), ["hips", "leg_%s" % s])
    for k in (-1, 0, 1):
        bind(cone("claw_%s%d" % (s, k), (x * 0.08, 0.28, 0.42), (x * 0.08 + k * 0.018, 0.32, 0.39), 0.006, DEEP, n=4, bend=(0, 0.0, -0.01)), ["leg_%s" % s])
# Wings: arm and forearm, then four long fingers from the wrist with the
# membrane stretched between them and back to the leg, scalloped between tips.
for s, x in (("l", 1), ("r", -1)):
    P = lambda v: (x * v[0], v[1], v[2])
    bones = ["wing_%s_1" % s, "wing_%s_2" % s, "wing_%s_3" % s]
    bind(tube("arm_" + s, [(P((0.06, -0.08, 0.6)), 0.04, 0.035), (P((0.3, -0.04, 0.63)), 0.026, 0.024),
                          (P((0.56, 0.02, 0.6)), 0.018, 0.016)], SKIN, n=8), bones)
    bind(cone("thumb_" + s, P((0.56, 0.02, 0.6)), P((0.6, -0.05, 0.62)), 0.012, DEEP, n=4), ["wing_%s_3" % s])
    tips = [(0.98, 0.02, 0.58), (0.92, 0.26, 0.56), (0.7, 0.44, 0.55), (0.44, 0.44, 0.54)]
    for k, t in enumerate(tips):
        bind(cone("finger_%s%d" % (s, k), P((0.56, 0.02, 0.6)), P(t), 0.011, SKIN, n=5), bones[1:])
    web = [P((0.06, -0.08, 0.6)), P((0.3, -0.04, 0.63)), P((0.56, 0.02, 0.6)), P(tips[0]), P((0.86, 0.15, 0.575)),
           P(tips[1]), P((0.74, 0.32, 0.56)), P(tips[2]), P((0.54, 0.38, 0.552)), P(tips[3]), P((0.24, 0.3, 0.52)), P((0.07, 0.2, 0.49))]
    bind(sheet("web_" + s, web, WEB, 0.012), bones)
    # A darker band along the arm, where the membrane is thicker.
    bind(sheet("web_band_" + s, [P((0.08, -0.06, 0.605)), P((0.3, -0.02, 0.632)), P((0.56, 0.04, 0.605)), P((0.5, 0.12, 0.59)), P((0.1, 0.06, 0.58))], WEB_D, 0.016), bones)
# A short tail inside the membrane stretched between the legs.
bind(cone("tail", (0, 0.14, 0.5), (0, 0.3, 0.45), 0.02, SKIN, n=5), ["tail_01"])
bind(sheet("tail_web", [(0, 0.14, 0.5), (0.075, 0.24, 0.44), (0.08, 0.28, 0.42), (0, 0.32, 0.44), (-0.08, 0.28, 0.42), (-0.075, 0.24, 0.44)], WEB_D, 0.01), ["hips", "tail_01"])

bat = skin(rig, "Bat")
bake(bat, 1024, OUT + "bat_tex.png")

# Clips: +X pitches the nose down, -Y lifts the left wing (+Y the right), Z
# turns (+Z swings the left wing back). Each beat: wings up and folded a
# little, then down hard and spread.
def beat(keys, frames):
    """frames: [(time, lift degrees, fold 0..1)]"""
    for s, sg in (("l", 1), ("r", -1)):
        for t, lift, fold in frames:
            keys.setdefault("wing_%s_1" % s, []).append((t, (0, -sg * lift, sg * 10 * fold), None))
            keys.setdefault("wing_%s_2" % s, []).append((t, (0, -sg * lift * 0.3, sg * 30 * fold), None))
            keys.setdefault("wing_%s_3" % s, []).append((t, (0, -sg * lift * 0.2, sg * 25 * fold), None))
    return keys

hover = beat({}, [(0, -30, 0), (0.3, 45, 0.7), (0.6, -30, 0)])
hover["hips"] = [(0, (-18, 0, 0), (0, 0, 0.03)), (0.3, (-18, 0, 0), (0, 0, -0.02)), (0.6, (-18, 0, 0), (0, 0, 0.03))]
hover["neck_01"] = [(0, (14, 0, 0), None), (0.6, (14, 0, 0), None)]
hover["tail_01"] = [(0, (0, 0, 0), None), (0.3, (-10, 0, 0), None), (0.6, (0, 0, 0), None)]
for s in "lr":
    hover["leg_" + s] = [(0, (-10, 0, 0), None), (0.3, (8, 0, 0), None), (0.6, (-10, 0, 0), None)]
clip(rig, "Hover", 0.6, hover)

fly = beat({}, [(0, -35, 0), (0.2, 50, 0.8), (0.4, -35, 0)])
fly["hips"] = [(0, (8, 0, 0), (0, 0, 0.02)), (0.2, (8, 0, 0), (0, 0, -0.03)), (0.4, (8, 0, 0), (0, 0, 0.02))]
fly["neck_01"] = [(0, (-8, 0, 0), None), (0.4, (-8, 0, 0), None)]
clip(rig, "Bat_Flying", 0.4, fly)

# A dive: wings swept back, mouth open, then a bite and the wings flung out.
atk = beat({}, [(0, -30, 0), (0.2, 20, 1.0), (0.35, -40, 0.2), (0.6, -30, 0)])
atk["hips"] = [(0, (-18, 0, 0), (0, 0, 0)), (0.2, (25, 0, 0), (0, -0.12, -0.05)), (0.35, (30, 0, 0), (0, -0.2, -0.08)), (0.6, (-18, 0, 0), (0, 0, 0))]
atk["jaw"] = [(0, (0, 0, 0), None), (0.2, (35, 0, 0), None), (0.33, (0, 0, 0), None), (0.6, (0, 0, 0), None)]
clip(rig, "Attack", 0.6, atk, loop=False)

hit = beat({}, [(0, -30, 0), (0.1, 60, 0.3), (0.4, -30, 0)])
hit["hips"] = [(0, (-18, 0, 0), (0, 0, 0)), (0.1, (-40, 0, 0), (0, 0.1, 0.04)), (0.4, (-18, 0, 0), (0, 0, 0))]
hit["jaw"] = [(0, (0, 0, 0), None), (0.1, (20, 0, 0), None), (0.4, (0, 0, 0), None)]
clip(rig, "Hit", 0.4, hit, loop=False)

# Blood Dive wind-up: rears back, wings flung wide and high, a screech.
sp = beat({}, [(0, -30, 0), (0.3, 60, 0), (0.7, 60, 0), (1.0, -30, 0)])
sp["hips"] = [(0, (-18, 0, 0), (0, 0, 0)), (0.3, (-45, 0, 0), (0, 0.04, 0.08)), (0.7, (-45, 0, 0), (0, 0.04, 0.08)), (1.0, (-18, 0, 0), (0, 0, 0))]
sp["head"] = [(0, (0, 0, 0), None), (0.3, (-20, 0, 0), None), (0.7, (-20, 0, 0), None), (1.0, (0, 0, 0), None)]
sp["jaw"] = [(0, (0, 0, 0), None), (0.35, (40, 0, 0), None), (0.7, (40, 0, 0), None), (1.0, (0, 0, 0), None)]
for s, sg in (("l", 1), ("r", -1)):
    sp["ear_" + s] = [(0, (0, 0, 0), None), (0.3, (0, sg * 15, 0), None), (0.7, (0, sg * 15, 0), None), (1.0, (0, 0, 0), None)]
clip(rig, "Special", 1.0, sp, loop=False)

export(rig, bat, OUT + "bat_src.glb")
os.remove(OUT + "bat_tex.png")
