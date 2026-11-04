# Methane Bloat (Cinder Mire): a floating gas sac. A swollen bile-green bladder
# crusted with sallow boils, one dull eye and a gaping slit of a mouth, three
# rust vent pipes glowing ember-orange on top, two small side bladders and a
# fringe of limp tendrils trailing beneath. Drifts, lunges, bursts.
# Writes assets/foes/methane_bloat_src.glb.
# Run: python3 tools/blender/foes/methane_bloat.py -- <repo root>
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "pets"))
import common
from common import *

ROOT = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(ROOT, "assets/foes/")
reset()
common.SIDES, common.BLOB_SUB = 0.9, 2

SAC = mat("bloat_sac", "56602a")
SAC_L = mat("bloat_sac_l", "7a8236")
BELLY = mat("bloat_belly", "8c8a3e")
BOIL = mat("bloat_boil", "a69c3c")
VEIN = mat("bloat_vein", "3a2c20")
EYE = mat("bloat_eye", "d6cf70")
VOID = mat("bloat_void", "0a0b06", 1.0)
RUST = mat("bloat_rust", "6a4128")
EMBER = mat("bloat_ember", "ff8a22")
TEETH = mat("bloat_teeth", "b0a888")
TENT = mat("bloat_tent", "4a4a28")
TENT_T = mat("bloat_tent_t", "8a7a3a")

S = [("body", (0, 0, 0.7), (0, 0, 1.3), None), ("jaw", (0, -0.4, 0.82), (0, -0.52, 0.76), "body")]
for k, (x, y) in enumerate([(0.18, -0.06), (-0.16, -0.1), (0.0, 0.16)]):
    S.append(("vent_%d" % k, (x, y, 1.4), (x, y, 1.64), "body"))
for s, x in (("l", 1), ("r", -1)):
    S.append(("bladder_" + s, (x * 0.5, 0.0, 1.0), (x * 0.74, 0.0, 0.95), "body"))
TENDRILS = [(0.16, -0.12), (-0.18, -0.08), (0.12, 0.16), (-0.12, 0.14), (0.0, -0.22)]
for k, (x, y) in enumerate(TENDRILS):
    S += [("t%d_1" % k, (x, y, 0.5), (x * 1.2, y * 1.2, 0.34), "body"),
          ("t%d_2" % k, (x * 1.2, y * 1.2, 0.34), (x * 1.4, y * 1.4, 0.18), "t%d_1" % k),
          ("t%d_3" % k, (x * 1.4, y * 1.4, 0.18), (x * 1.5, y * 1.5, 0.04), "t%d_2" % k)]
rig = armature(S)

sac = blob("sac", (0, 0, 1.0), (1.05, 1.0, 1.1), SAC, sub=2)
two_tone(sac, BELLY, SAC_L, down=-0.45, up=0.55)
bind(sac, ["body"])
# Boils, veins, a sallow cluster around the vents.
for k, (a, z, w) in enumerate([(0.4, 1.28, 0.1), (1.9, 1.2, 0.12), (2.7, 0.9, 0.09), (3.6, 1.1, 0.13), (4.4, 1.3, 0.1), (5.3, 1.0, 0.11), (0.9, 0.72, 0.08), (3.2, 0.7, 0.09)]):
    r = (1 - ((z - 1.0) / 0.55) ** 2) ** 0.5 * 0.5
    bind(blob("boil%d" % k, (math.cos(a) * r * 1.02, math.sin(a) * r, z), (w, w, w), BOIL, sub=1), ["body"])
for k, a in enumerate([0.8, 2.4, 4.0, 5.4]):
    path = [((math.cos(a) * 0.5 * (1 - ((z - 1.0) / 0.55) ** 2) ** 0.5 * 1.04, math.sin(a) * 0.5 * (1 - ((z - 1.0) / 0.55) ** 2) ** 0.5 * 1.04, z), 0.012, 0.012)
            for z in (0.55, 0.75, 0.95, 1.15, 1.3)]
    bind(tube("vein%d" % k, path, VEIN, n=4, sub=0), ["body"])
# Face: one big dull eye above a ragged mouth.
bind(blob("eye", (0.06, -0.47, 1.12), (0.2, 0.08, 0.2), EYE, sub=1), ["body"])
bind(blob("pupil", (0.06, -0.52, 1.12), (0.06, 0.03, 0.14), VOID, sub=0), ["body"])
bind(blob("brow", (0.06, -0.47, 1.26), (0.26, 0.09, 0.05), VEIN, sub=0, rot=(0.2, 0, 0.1)), ["body"])
bind(blob("mouth", (0, -0.46, 0.8), (0.4, 0.1, 0.17), VOID, sub=1), ["body"])
bind(tube("lowlip", [((-0.18, -0.48, 0.74), 0.035, 0.03), ((0, -0.5, 0.7), 0.04, 0.03), ((0.18, -0.48, 0.74), 0.035, 0.03)], BELLY, n=5), ["jaw"])
for k in range(5):
    bind(cone("tooth%d" % k, ((k - 2) * 0.07, -0.5, 0.74), ((k - 2) * 0.07, -0.51, 0.84), 0.016, TEETH, n=3), ["jaw"])
for k in range(4):
    bind(cone("utooth%d" % k, ((k - 1.5) * 0.08, -0.5, 0.88), ((k - 1.5) * 0.08, -0.5, 0.8), 0.014, TEETH, n=3), ["body"])
# Vent pipes with ember tips, ringed in rust.
for k, (x, y) in enumerate([(0.18, -0.06), (-0.16, -0.1), (0.0, 0.16)]):
    bind(tube("vent%d" % k, [((x, y, 1.38), 0.11, 0.11), ((x, y, 1.48), 0.07, 0.07), ((x, y, 1.62), 0.075, 0.075)], RUST, n=6), ["vent_%d" % k])
    bind(blob("ember%d" % k, (x, y, 1.65), (0.1, 0.1, 0.05), EMBER, sub=1), ["vent_%d" % k])
# Side bladders and tendrils.
for s, x in (("l", 1), ("r", -1)):
    bind(blob("bladder_" + s, (x * 0.62, 0, 0.98), (0.3, 0.26, 0.3), SAC_L, sub=1), ["bladder_" + s])
    bind(tube("stalk_" + s, [((x * 0.42, 0, 1.0), 0.05, 0.05), ((x * 0.52, 0, 0.99), 0.04, 0.04)], VEIN, n=4, sub=0), ["bladder_" + s, "body"])
for k, (x, y) in enumerate(TENDRILS):
    bind(tube("tent%d" % k, [((x, y, 0.55), 0.06, 0.06), ((x * 1.2, y * 1.2, 0.34), 0.045, 0.045), ((x * 1.4, y * 1.4, 0.18), 0.03, 0.03), ((x * 1.5, y * 1.5, 0.04), 0.012, 0.012)],
              TENT, n=5), ["t%d_1" % k, "t%d_2" % k, "t%d_3" % k])
    bind(blob("bulb%d" % k, (x * 1.4, y * 1.4, 0.2), (0.07, 0.07, 0.07), TENT_T, sub=1), ["t%d_2" % k])

body = skin(rig, "MethaneBloat")
bake(body, 256, OUT + "methane_bloat_tex.png")


def tent(period, a, extra=0.0, ph=0.0):
    ks = {}
    for k in range(len(TENDRILS)):
        for j in (1, 2, 3):
            d = ph + k * 0.9 + j * 0.5
            ks["t%d_%d" % (k, j)] = [(0, (a * math.sin(d), 0, a * math.cos(d) * 0.8 + extra), None),
                                     (period / 2, (-a * math.sin(d), 0, -a * math.cos(d) * 0.8 + extra), None),
                                     (period, (a * math.sin(d), 0, a * math.cos(d) * 0.8 + extra), None)]
    return ks

def flutter(ks, period, a):
    for k in range(3):
        ks["vent_%d" % k] = [(0, (a, 0, 0), None), (period / 2, (-a, 0, a), None), (period, (a, 0, 0), None)]
    for s, sg in (("l", 1), ("r", -1)):
        ks["bladder_" + s] = [(0, (0, 0, sg * a * 2), None), (period / 2, (0, 0, -sg * a * 2), None), (period, (0, 0, sg * a * 2), None)]
    return ks

idle = flutter(tent(2.4, 8), 2.4, 4)
idle["body"] = [(0, (0, 0, 0), (0, 0, 0.0)), (1.2, (2, 0, 3), (0, 0, 0.1)), (2.4, (0, 0, 0), (0, 0, 0.0))]
idle["jaw"] = [(0, (0, 0, 0), None), (1.2, (8, 0, 0), None), (2.4, (0, 0, 0), None)]
clip(rig, "Idle", 2.4, idle)

def drift(period, lean, bob, a):
    ks = flutter(tent(period, a, 6 + lean * 0.5), period, 6)
    ks["body"] = [(0, (lean, 0, 3), (0, 0, 0)), (period / 2, (lean + 3, 0, -3), (0, 0, bob)), (period, (lean, 0, 3), (0, 0, 0))]
    ks["jaw"] = [(0, (0, 0, 0), None), (period / 2, (6, 0, 0), None), (period, (0, 0, 0), None)]
    return ks

clip(rig, "Walk", 1.2, drift(1.2, 8, 0.1, 12))
clip(rig, "Run", 0.7, drift(0.7, 16, 0.14, 18))

# Attack: swells back and up, then lunges at the target, maw wide, vents flaring.
atk = flutter(tent(0.8, 10, 10), 0.8, 10)
atk["body"] = [(0, (0, 0, 0), (0, 0, 0)), (0.3, (-16, 0, 0), (0, 0.12, 0.14)), (0.46, (22, 0, 0), (0, -0.5, -0.04)), (0.8, (0, 0, 0), (0, 0, 0))]
atk["jaw"] = [(0, (0, 0, 0), None), (0.3, (0, 0, 0), None), (0.46, (40, 0, 0), None), (0.8, (0, 0, 0), None)]
for k in range(3):
    atk["vent_%d" % k] = [(0, (0, 0, 0), None), (0.3, (-18, 0, 12), None), (0.46, (22, 0, -12), None), (0.8, (0, 0, 0), None)]
clip(rig, "Attack", 0.8, atk, loop=False)

hit = tent(0.4, 18, 8)
hit["body"] = [(0, (0, 0, 0), (0, 0, 0)), (0.1, (-14, 0, 10), (0, 0.22, 0.08)), (0.4, (0, 0, 0), (0, 0, 0))]
hit["jaw"] = [(0, (0, 0, 0), None), (0.1, (36, 0, 0), None), (0.4, (0, 0, 0), None)]
clip(rig, "Hit", 0.4, hit, loop=False)

# Die: shudders, sags and sinks to the ground, tendrils and vents flopping.
die = {"body": [(0, (0, 0, 0), (0, 0, 0)), (0.2, (-10, 0, 6), (0, 0.06, 0.1)), (0.8, (24, 0, 20), (0, -0.1, -0.6)), (1.1, (30, 0, 24), (0, -0.14, -0.66))],
       "jaw": [(0, (0, 0, 0), None), (0.8, (34, 0, 0), None), (1.1, (40, 0, 0), None)]}
for k in range(len(TENDRILS)):
    for j in (1, 2, 3):
        die["t%d_%d" % (k, j)] = [(0, (0, 0, 0), None), (0.8, (35 * (1 if k % 2 else -1), 0, 30 * (1 if k % 3 else -1)), None), (1.1, (45 * (1 if k % 2 else -1), 0, 40 * (1 if k % 3 else -1)), None)]
for k in range(3):
    die["vent_%d" % k] = [(0, (0, 0, 0), None), (0.8, (40 - k * 30, 0, 30 * (k - 1)), None), (1.1, (46 - k * 36, 0, 40 * (k - 1)), None)]
for s, sg in (("l", 1), ("r", -1)):
    die["bladder_" + s] = [(0, (0, 0, 0), None), (0.8, (0, 0, -sg * 50), None), (1.1, (0, 0, -sg * 60), None)]
clip(rig, "Die", 1.1, die, loop=False)

export(rig, body, OUT + "methane_bloat_src.glb")
os.remove(OUT + "methane_bloat_tex.png")
