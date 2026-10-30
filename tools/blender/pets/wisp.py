# Grave Wisp: a stone-skinned spirit fish that swims through the air, a
# glowing belly, a toothed maw, a lantern lure over its brow and a tail that
# trails off into spirit flame. Writes assets/sidekicks/mawko_src.glb.
# Run: <blender python> tools/blender/pets/wisp.py -- <repo root>
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *

ROOT = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(ROOT, "assets/sidekicks/")
reset()

STONE = mat("wisp_stone", "8e9096")
DARK = mat("wisp_dark", "5a5d64")
GLOW = mat("wisp_glow", "86e6d8")
SPIRIT = mat("wisp_spirit", "5cc9bb")
TOOTH = mat("wisp_tooth", "eee6d2")
MOUTH = mat("wisp_mouth", "2b2228")
EYE = mat("wisp_eye", "c9fff6")
IRON = mat("wisp_iron", "3a3c42")

# Skeleton (Blender: -Y forward, Z up).
S = [
    ("hips", (0, 0.25, 1.0), (0, 0.0, 1.0), None),
    ("spine_01", (0, 0.0, 1.0), (0, -0.22, 1.02), "hips"),
    ("neck_01", (0, -0.22, 1.02), (0, -0.34, 1.04), "spine_01"),
    ("head", (0, -0.34, 1.04), (0, -0.66, 1.06), "neck_01"),
    ("jaw", (0, -0.3, 0.94), (0, -0.64, 0.9), "neck_01"),
    ("lure_1", (0, -0.36, 1.26), (0, -0.52, 1.44), "head"),
    ("lure_2", (0, -0.52, 1.44), (0, -0.72, 1.4), "lure_1"),
    ("tail_01", (0, 0.25, 1.0), (0, 0.5, 1.02), "hips"),
    ("tail_02", (0, 0.5, 1.02), (0, 0.76, 1.08), "tail_01"),
    ("tail_03", (0, 0.76, 1.08), (0, 1.02, 1.16), "tail_02"),
]
for s, x in (("l", 1), ("r", -1)):
    S += [
        ("fin_%s_1" % s, (x * 0.22, -0.08, 0.98), (x * 0.5, 0.02, 0.92), "spine_01"),
        ("fin_%s_2" % s, (x * 0.5, 0.02, 0.92), (x * 0.78, 0.16, 0.84), "fin_%s_1" % s),
    ]
rig = armature(S)

# Body: a heavy teardrop, stone above and a glowing belly below.
body = tube("body", [((0, 0.32, 1.0), 0.09, 0.09), ((0, 0.18, 1.0), 0.19, 0.2), ((0, 0.0, 1.0), 0.26, 0.27),
                     ((0, -0.18, 1.01), 0.27, 0.27), ((0, -0.3, 1.02), 0.24, 0.24)], STONE, n=12)
two_tone(body, GLOW, DARK, down=-0.25, up=0.7)
bind(body, ["hips", "spine_01", "neck_01"])
# Head: a blunt skull over a deep lower jaw, the mouth dark inside.
head = tube("head", [((0, -0.28, 1.08), 0.24, 0.2), ((0, -0.42, 1.08), 0.23, 0.18), ((0, -0.56, 1.06), 0.19, 0.14),
                     ((0, -0.66, 1.04), 0.12, 0.09)], STONE, n=12)
two_tone(head, MOUTH, DARK, down=-0.5, up=0.7)
bind(head, ["head", "neck_01"])
jaw = tube("jaw", [((0, -0.28, 0.9), 0.23, 0.1), ((0, -0.46, 0.88), 0.2, 0.085), ((0, -0.62, 0.89), 0.13, 0.06)], STONE, n=10)
two_tone(jaw, GLOW, MOUTH, down=-0.4, up=0.5)
bind(jaw, ["jaw"])
bind(blob("brow", (0, -0.4, 1.22), (0.17, 0.12, 0.05), DARK, rot=(-0.2, 0, 0)), ["head"])
# Teeth: an upper row hanging down, a lower row standing up.
for k in range(7):
    a = -0.9 + k * 0.3
    x = math.sin(a) * 0.16
    y = -0.46 - math.cos(a) * 0.17
    bind(cone("tooth_u%d" % k, (x, y, 0.995), (x, y - 0.01, 0.94), 0.022, TOOTH, n=4), ["head"])
    bind(cone("tooth_l%d" % k, (x * 0.92, y + 0.01, 0.925), (x * 0.92, y, 0.975), 0.018, TOOTH, n=4), ["jaw"])
for s, x in (("l", 1), ("r", -1)):
    bind(blob("eye_" + s, (x * 0.17, -0.47, 1.15), (0.07, 0.09, 0.06), EYE, sub=1), ["head"])
    bind(blob("socket_" + s, (x * 0.16, -0.46, 1.19), (0.12, 0.13, 0.04), DARK, rot=(0, x * 0.4, 0)), ["head"])
    # Stone plates along the flanks and a gill slit.
    for k in range(3):
        bind(blob("plate_%s%d" % (s, k), (x * 0.24, -0.1 + k * 0.14, 1.1 - k * 0.02), (0.06, 0.12, 0.11), DARK, rot=(0, x * 0.5, 0)), ["spine_01" if k < 2 else "hips"])
    bind(blob("gill_" + s, (x * 0.255, -0.26, 1.0), (0.025, 0.04, 0.16), MOUTH, sub=1), ["neck_01"])
# Dorsal ridge.
for i, (y, z) in enumerate([(-0.3, 1.24), (-0.12, 1.27), (0.06, 1.25), (0.2, 1.18)]):
    bind(cone("ridge_%d" % i, (0, y, z - 0.04), (0, y + 0.1, z + 0.1), 0.05 - i * 0.008, DARK, n=4), ["spine_01" if i < 3 else "hips"])
# Lantern lure on an iron stalk.
bind(tube("stalk", [((0, -0.34, 1.2), 0.025, 0.025), ((0, -0.5, 1.44), 0.018, 0.018), ((0, -0.7, 1.42), 0.014, 0.014)], IRON, n=6, sub=0), ["head", "lure_1", "lure_2"])
bind(blob("lantern", (0, -0.73, 1.33), (0.1, 0.1, 0.13), GLOW, sub=1), ["lure_2"])
bind(blob("cap", (0, -0.73, 1.405), (0.11, 0.11, 0.04), IRON, sub=1), ["lure_2"])
bind(blob("base", (0, -0.73, 1.26), (0.1, 0.1, 0.035), IRON, sub=1), ["lure_2"])
# Pectoral fins: a stone spine and a ragged spirit-glow web.
for s, x in (("l", 1), ("r", -1)):
    P = lambda v: (x * v[0], v[1], v[2])
    bones = ["fin_%s_1" % s, "fin_%s_2" % s]
    bind(tube("finbone_" + s, [(P((0.2, -0.08, 0.98)), 0.035, 0.035), (P((0.5, 0.02, 0.92)), 0.024, 0.024), (P((0.8, 0.16, 0.84)), 0.006, 0.006)], STONE, n=6), bones)
    bind(sheet("fin_" + s, [P((0.2, -0.06, 0.98)), P((0.5, 0.02, 0.92)), P((0.8, 0.16, 0.84)), P((0.74, 0.36, 0.74)),
                            P((0.6, 0.32, 0.8)), P((0.5, 0.46, 0.78)), P((0.36, 0.3, 0.86)), P((0.24, 0.24, 0.92))], SPIRIT, 0.02), bones + ["spine_01"])
# Tail: stone tapering into a forked tongue of spirit flame.
tail = tube("tail", [((0, 0.28, 1.0), 0.1, 0.1), ((0, 0.5, 1.02), 0.07, 0.075), ((0, 0.74, 1.07), 0.045, 0.05)], STONE, n=10)
two_tone(tail, GLOW, DARK, down=-0.25)
bind(tail, ["hips", "tail_01", "tail_02"])
bind(sheet("flame", [(0, 0.7, 1.06), (0, 0.86, 1.24), (0, 1.0, 1.2), (0, 1.12, 1.34), (0, 1.1, 1.12), (0, 1.2, 1.02),
                     (0, 1.02, 0.98), (0, 1.08, 0.86), (0, 0.86, 0.96)], SPIRIT, 0.03), ["tail_02", "tail_03"])
bind(sheet("flame_in", [(0.016, 0.76, 1.06), (0.016, 0.92, 1.16), (0.016, 1.0, 1.08), (0.016, 0.94, 0.98)], GLOW, 0.01), ["tail_02", "tail_03"])
bind(sheet("flame_in2", [(-0.016, 0.76, 1.06), (-0.016, 0.92, 1.16), (-0.016, 1.0, 1.08), (-0.016, 0.94, 0.98)], GLOW, 0.01), ["tail_02", "tail_03"])

wisp = skin(rig, "Wisp")
bake(wisp, 1024, OUT + "mawko_tex.png")

# Clips: +X pitches the nose down, -Y lifts the left fin (+Y the right), Z turns.
def fins(period, up, down):
    ks = {}
    for s, sg in (("l", 1), ("r", -1)):
        ks["fin_%s_1" % s] = [(0, (0, -sg * up, 0), None), (period / 2, (0, sg * down, 0), None), (period, (0, -sg * up, 0), None)]
        ks["fin_%s_2" % s] = [(0, (0, sg * 8, 0), None), (period * 0.62, (0, -sg * 14, 0), None), (period, (0, sg * 8, 0), None)]
    return ks

def swish(period, a, keys):
    for i, bn in enumerate(["tail_01", "tail_02", "tail_03"]):
        sh = i * 0.12 * period
        keys[bn] = [(0, (0, 0, a * (1 + i * 0.4)), None), (period / 2, (0, 0, -a * (1 + i * 0.4)), None), (period, (0, 0, a * (1 + i * 0.4)), None)]
    return keys

idle = swish(2.0, 9, fins(2.0, 14, 10))
idle["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (1.0, (3, 0, 0), (0, 0, 0.07)), (2.0, (0, 0, 0), (0, 0, 0))]
idle["lure_1"] = [(0, (6, 0, 4), None), (1.0, (-6, 0, -4), None), (2.0, (6, 0, 4), None)]
idle["lure_2"] = [(0, (-8, 0, 0), None), (1.0, (10, 0, 0), None), (2.0, (-8, 0, 0), None)]
idle["jaw"] = [(0, (0, 0, 0), None), (1.0, (6, 0, 0), None), (2.0, (0, 0, 0), None)]
clip(rig, "Idle", 2.0, idle)

walk = swish(0.8, 16, fins(0.8, 22, 18))
walk["hips"] = [(0, (10, 0, 0), (0, 0, 0)), (0.4, (10, 0, 0), (0, 0, 0.04)), (0.8, (10, 0, 0), (0, 0, 0))]
walk["lure_1"] = [(0, (-14, 0, 0), None), (0.8, (-14, 0, 0), None)]
clip(rig, "Walk", 0.8, walk)

atk = swish(0.7, 8, fins(0.7, 10, 10))
atk["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.25, (-10, 0, 0), (0, 0.08, 0)), (0.42, (12, 0, 0), (0, -0.14, 0)), (0.7, (0, 0, 0), (0, 0, 0))]
atk["jaw"] = [(0, (0, 0, 0), None), (0.28, (38, 0, 0), None), (0.42, (0, 0, 0), None), (0.7, (0, 0, 0), None)]
atk["head"] = [(0, (0, 0, 0), None), (0.28, (-14, 0, 0), None), (0.42, (4, 0, 0), None), (0.7, (0, 0, 0), None)]
clip(rig, "Attack", 0.7, atk, loop=False)

hit = swish(0.45, 10, fins(0.45, 24, 10))
hit["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.12, (-14, 0, 8), (0, 0.1, 0.04)), (0.45, (0, 0, 0), (0, 0, 0))]
hit["jaw"] = [(0, (0, 0, 0), None), (0.12, (16, 0, 0), None), (0.45, (0, 0, 0), None)]
clip(rig, "Hit", 0.45, hit, loop=False)

sp = swish(1.2, 6, {})
for s, sg in (("l", 1), ("r", -1)):
    sp["fin_%s_1" % s] = [(0, (0, 0, 0), None), (0.45, (0, -sg * 40, 0), None), (0.9, (0, -sg * 40, 0), None), (1.2, (0, 0, 0), None)]
sp["hips"] = [(0, (0, 0, 0), (0, 0, 0)), (0.45, (-18, 0, 0), (0, 0, 0.16)), (0.9, (-18, 0, 0), (0, 0, 0.16)), (1.2, (0, 0, 0), (0, 0, 0))]
sp["lure_1"] = [(0, (0, 0, 0), None), (0.45, (-30, 0, 0), None), (0.9, (-30, 0, 0), None), (1.2, (0, 0, 0), None)]
sp["jaw"] = [(0, (0, 0, 0), None), (0.45, (26, 0, 0), None), (0.9, (26, 0, 0), None), (1.2, (0, 0, 0), None)]
clip(rig, "Special", 1.2, sp, loop=False)

export(rig, wisp, OUT + "mawko_src.glb")
os.remove(OUT + "mawko_tex.png")
