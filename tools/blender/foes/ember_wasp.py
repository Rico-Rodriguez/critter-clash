# Ember Wasp (cm_wasp): a hand-long hornet at real proportions, hovering body-up with its
# abdomen hanging, char-black plate banded with ember, smoky amber wings, a hot stinger.
# Writes assets/foes/ember_wasp_src.glb.
# Run: python3 tools/blender/foes/ember_wasp.py -- <repo root>
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from foe_common import *

reset()
SHELL = mat("wasp_shell", "2a1d1a")
DARK = mat("wasp_dark", "15100f")
BAND = mat("wasp_band", "b8481a")
GLOW = mat("wasp_glow", "f08a2a")
EYE = mat("wasp_eye", "e8581a")
WING = mat("wasp_wing", "9a6232")
VEIN = mat("wasp_vein", "3a241a")
CLAW = mat("wasp_claw", "0e0c0b")

S = [
    ("thorax", (0, -0.08, 0.66), (0, 0.0, 0.56), None),
    ("head", (0, -0.08, 0.68), (0, -0.2, 0.82), "thorax"),
    ("jaw", (0, -0.2, 0.8), (0, -0.28, 0.72), "head"),
    ("abd_01", (0, 0.0, 0.56), (0, 0.12, 0.4), "thorax"),
    ("abd_02", (0, 0.12, 0.4), (0, 0.23, 0.27), "abd_01"),
    ("abd_03", (0, 0.23, 0.27), (0, 0.3, 0.14), "abd_02"),
]
legs = {"f": ((0.06, -0.1, 0.56), (0.13, -0.2, 0.4), (0.1, -0.28, 0.27)),
        "m": ((0.07, -0.04, 0.54), (0.2, -0.06, 0.36), (0.17, -0.1, 0.2)),
        "b": ((0.06, 0.0, 0.5), (0.18, 0.12, 0.34), (0.15, 0.18, 0.2))}
for s, x in (("l", 1), ("r", -1)):
    S += [("ant_" + s, (x * 0.04, -0.2, 0.82), (x * 0.1, -0.38, 0.99), "head"),
          ("wingf_" + s, (x * 0.05, -0.06, 0.72), (x * 0.6, -0.1, 0.9), "thorax"),
          ("wingh_" + s, (x * 0.05, 0.0, 0.7), (x * 0.45, 0.12, 0.8), "thorax")]
    for k, (a, _, c) in legs.items():
        S.append(("leg_%s_%s" % (k, s), (x * a[0], a[1], a[2]), (x * c[0], c[1], c[2]), "thorax"))
rig = armature(S)
common.SIDES, common.BLOB_SUB = 1.0, 0

thorax = tube("thorax", [((0, -0.05, 0.76), 0.04, 0.04), ((0, -0.07, 0.69), 0.12, 0.12), ((0, 0.0, 0.58), 0.12, 0.12), ((0, 0.04, 0.52), 0.06, 0.06)], SHELL, n=6)
two_tone(thorax, DARK, None)
bind(thorax, ["thorax"])
bind(blob("stripe", (0, -0.06, 0.75), (0.16, 0.06, 0.03), BAND, rot=(-0.3, 0, 0)), ["thorax"])
# Abdomen: three hot-banded segments hanging from the thorax, a barbed sting at the tip.
bind(tube("abd1", [((0, 0.03, 0.54), 0.06, 0.06), ((0, 0.07, 0.46), 0.11, 0.11), ((0, 0.12, 0.39), 0.09, 0.09)], SHELL, n=6), ["thorax", "abd_01"])
bind(tube("abd2", [((0, 0.12, 0.39), 0.09, 0.09), ((0, 0.17, 0.33), 0.125, 0.125), ((0, 0.23, 0.26), 0.1, 0.1)], BAND, n=6), ["abd_01", "abd_02"])
bind(tube("abd3", [((0, 0.23, 0.26), 0.1, 0.1), ((0, 0.27, 0.2), 0.085, 0.085), ((0, 0.3, 0.15), 0.035, 0.035)], GLOW, n=6), ["abd_02", "abd_03"])
bind(cone("sting", (0, 0.3, 0.15), (0, 0.26, 0.0), 0.03, CLAW, n=4, bend=(0, -0.01, 0)), ["abd_03"])
bind(blob("sting_barb", (0, 0.285, 0.07), (0.025, 0.05, 0.015), CLAW, rot=(0.5, 0, 0)), ["abd_03"])
# Head with great compound eyes, mandibles and long antennae.
bind(tube("head", [((0, -0.1, 0.72), 0.03, 0.03), ((0, -0.13, 0.76), 0.085, 0.08), ((0, -0.19, 0.8), 0.095, 0.085), ((0, -0.24, 0.82), 0.05, 0.05)], SHELL, n=6), ["head"])
for s, x in (("l", 1), ("r", -1)):
    bind(blob("eye_" + s, (x * 0.085, -0.17, 0.8), (0.05, 0.07, 0.085), EYE, rot=(0.5, 0, 0)), ["head"])
    bind(cone("mand_" + s, (x * 0.04, -0.24, 0.8), (x * 0.015, -0.3, 0.72), 0.02, CLAW, n=3, bend=(x * 0.02, 0, 0)), ["jaw"])
    bind(tube("antenna_" + s, [((x * 0.04, -0.2, 0.83), 0.01, 0.01), ((x * 0.07, -0.29, 0.92), 0.008, 0.008), ((x * 0.1, -0.38, 0.99), 0.004, 0.004)], DARK, n=3), ["head", "ant_" + s])
    P = lambda v: (x * v[0], v[1], v[2])
    # Legs: thin barbed, hanging folded under the thorax.
    for k, (a, kn, c) in legs.items():
        bind(tube("leg_%s_%s" % (k, s), [(P(a), 0.017, 0.017), (P(kn), 0.013, 0.013), (P(c), 0.007, 0.007)], DARK, n=3), ["leg_%s_%s" % (k, s), "thorax"])
        bind(cone("foot_%s_%s" % (k, s), P(c), (P(c)[0], P(c)[1] - 0.03, P(c)[2] - 0.05), 0.008, CLAW, n=3), ["leg_%s_%s" % (k, s)])
    # Wings: a leading vein and a tattered, amber membrane.
    bind(sheet("fw_" + s, [P((0.05, -0.06, 0.72)), P((0.35, -0.15, 0.86)), P((0.62, -0.1, 0.92)), P((0.56, 0.04, 0.86)), P((0.3, 0.08, 0.78)), P((0.06, 0.04, 0.7))], WING, 0.012), ["wingf_" + s, "thorax"])
    bind(cone("fvein_" + s, P((0.05, -0.06, 0.72)), P((0.62, -0.1, 0.92)), 0.014, VEIN, n=3), ["wingf_" + s])
    bind(sheet("hw_" + s, [P((0.05, 0.0, 0.7)), P((0.3, 0.04, 0.8)), P((0.46, 0.12, 0.8)), P((0.36, 0.17, 0.74)), P((0.08, 0.09, 0.68))], WING, 0.012), ["wingh_" + s, "thorax"])
    bind(cone("hvein_" + s, P((0.05, 0.0, 0.7)), P((0.46, 0.12, 0.8)), 0.011, VEIN, n=3), ["wingh_" + s])

wasp = skin(rig, "Wasp")

def rep(keys, cycles, period):
    out = []
    for c in range(cycles):
        for t, r, l in keys[(1 if c else 0):]:
            out.append((t + c * period, r, l))
    return out

def flap(length, period, amp=34, base=0, hind=0.08):
    """Wings beating about the Y axis (-Y lifts the left); one cycle every `period`."""
    c = {}
    cyc = int(round(length / period))
    for s, sg in (("l", 1), ("r", -1)):
        c["wingf_" + s] = rep(osc(period, {1: (-sg * amp, 0)}, n=6, base=(0, -sg * base, 0)), cyc, period)
        c["wingh_" + s] = rep(osc(period, {1: (-sg * amp * 0.9, hind)}, n=6, base=(0, -sg * base, 0)), cyc, period)
    return c

def legs_dangle(c, length, amount=8, ph=0.0):
    for s in ("l", "r"):
        for k, p in (("f", 0.0), ("m", 0.2), ("b", 0.4)):
            c["leg_%s_%s" % (k, s)] = osc(length, {0: (amount, ph + p)})
    return c

idle = flap(1.2, 0.2)
idle["thorax"] = osc(1.2, {0: (4, 0), 2: (5, 0.25)}, loc={2: (0.03, 0)})
idle["abd_01"] = osc(1.2, {0: (8, 0.2)}); idle["abd_02"] = osc(1.2, {0: (10, 0.3)}); idle["abd_03"] = osc(1.2, {0: (8, 0.4)})
idle["head"] = osc(1.2, {2: (10, 0), 0: (4, 0.3)})
idle["ant_l"] = osc(1.2, {0: (10, 0.2)}); idle["ant_r"] = osc(1.2, {0: (10, 0.4)})
idle["jaw"] = osc(1.2, {0: (10, 0.5)}, base=(6, 0, 0))
legs_dangle(idle, 1.2)
clip(rig, "Idle", 1.2, idle)

fast = flap(0.6, 0.1, 30, 0, 0.1) if False else flap(0.6, 0.2, 40, 6)
fast["thorax"] = osc(0.6, {2: (4, 0)}, base=(24, 0, 0), loc={2: (0.02, 0.0), 1: (-0.04, 0)})
fast["abd_01"] = osc(0.6, {0: (6, 0.2)}, base=(-14, 0, 0)); fast["abd_02"] = osc(0.6, {0: (8, 0.3)}, base=(-12, 0, 0))
fast["head"] = [(0, (-16, 0, 0), None), (0.6, (-16, 0, 0), None)]
fast["ant_l"] = [(0, (-30, 0, 0), None), (0.6, (-30, 0, 0), None)]; fast["ant_r"] = [(0, (-30, 0, 0), None), (0.6, (-30, 0, 0), None)]
legs_dangle(fast, 0.6, 6)
clip(rig, "Fly", 0.6, fast)

atk = flap(0.8, 0.2, 38)
atk["thorax"] = pose((0, (0, 0, 0), (0, 0, 0)), (0.3, (-18, 0, 0), (0, 0.08, 0.06)), (0.45, (46, 0, 0), (0, -0.28, -0.1)), (0.8, (0, 0, 0), (0, 0, 0)))
atk["abd_01"] = pose((0, (0, 0, 0)), (0.3, (14, 0, 0)), (0.45, (-70, 0, 0)), (0.8, (0, 0, 0)))
atk["abd_02"] = pose((0, (0, 0, 0)), (0.3, (14, 0, 0)), (0.45, (-60, 0, 0)), (0.8, (0, 0, 0)))
atk["abd_03"] = pose((0, (0, 0, 0)), (0.45, (-30, 0, 0)), (0.8, (0, 0, 0)))
atk["jaw"] = pose((0, (0, 0, 0)), (0.3, (40, 0, 0)), (0.5, (2, 0, 0)), (0.8, (0, 0, 0)))
for s in ("l", "r"):
    for k in "fmb":
        atk["leg_%s_%s" % (k, s)] = pose((0, (0, 0, 0)), (0.45, (-40, 0, 0)), (0.8, (0, 0, 0)))
clip(rig, "Attack", 0.8, atk, loop=False)

hit = flap(0.4, 0.2, 44, 10)
hit["thorax"] = pose((0, (0, 0, 0), (0, 0, 0)), (0.1, (-30, 0, 12), (0, 0.16, -0.04)), (0.4, (0, 0, 0), (0, 0, 0)))
hit["abd_01"] = pose((0, (0, 0, 0)), (0.1, (30, 0, 0)), (0.4, (0, 0, 0)))
hit["head"] = pose((0, (0, 0, 0)), (0.1, (-20, 0, -10)), (0.4, (0, 0, 0)))
hit["ant_l"] = pose((0, (0, 0, 0)), (0.1, (30, 0, 0)), (0.4, (0, 0, 0))); hit["ant_r"] = hit["ant_l"]
clip(rig, "Hit", 0.4, hit, loop=False)

die = flap(0.8, 0.2, 40)
for s, sg in (("l", 1), ("r", -1)):   # then the wings stall, folded up and still
    die["wingf_" + s] = pose((0, (0, 0, 0)), (0.2, (0, -sg * 40, 0)), (0.4, (0, sg * 20, 0)), (0.6, (0, -sg * 30, 0)), (0.9, (0, -sg * 8, 0)), (1.4, (0, -sg * 8, 0)))
    die["wingh_" + s] = pose((0, (0, 0, 0)), (0.2, (0, -sg * 36, 0)), (0.4, (0, sg * 24, 0)), (0.6, (0, -sg * 24, 0)), (0.9, (0, -sg * 4, 0)), (1.4, (0, -sg * 4, 0)))
    for k in "fmb":
        die["leg_%s_%s" % (k, s)] = pose((0, (0, 0, 0)), (0.5, (0, sg * 30, 0)), (1.4, (-30, sg * 40, 0)))
die["thorax"] = pose((0, (0, 0, 0), (0, 0, 0)), (0.25, (-30, 0, 20), (0, 0.1, -0.02)), (0.6, (-120, 0, 60), (0, 0.15, -0.2)), (0.9, (-170, 0, 70), (0, 0.1, -0.34)), (1.4, (-172, 0, 70), (0, 0.1, -0.36)))
die["abd_01"] = pose((0, (0, 0, 0)), (0.6, (-24, 0, 0)), (1.4, (-30, 0, 0))); die["abd_02"] = pose((0, (0, 0, 0)), (0.6, (-24, 0, 0)), (1.4, (-30, 0, 0)))
die["head"] = pose((0, (0, 0, 0)), (0.6, (14, 0, 0)), (1.4, (20, 0, 0)))
die["ant_l"] = pose((0, (0, 0, 0)), (0.8, (40, 0, 0)), (1.4, (40, 0, 0))); die["ant_r"] = die["ant_l"]
clip(rig, "Death", 1.4, die, loop=False)

finish(rig, wasp, "ember_wasp")
