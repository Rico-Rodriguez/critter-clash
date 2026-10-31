# Shared parts for the two-legged pets made from code (Bonelet, Hexling): a
# grown-up biped skeleton (head about a fifth of the height, so no chibi), a
# skeleton's bones to dress it in, and a walk cycle. Same axes as the other
# pets: -Y forward, Z up. +X pitches forward or swings a leg back, -Y lifts
# the left arm.
import math
from common import blob, tube, bind


def skeleton(extra=()):
    """The biped bone spec, plus `extra` [(name, head, tail, parent)]."""
    S = [
        ("hips", (0, 0, 0.62), (0, 0, 0.8), None),
        ("spine_01", (0, 0, 0.8), (0, -0.01, 1.02), "hips"),
        ("chest", (0, -0.01, 1.02), (0, -0.02, 1.22), "spine_01"),
        ("neck_01", (0, -0.02, 1.22), (0, -0.04, 1.32), "chest"),
        ("head", (0, -0.04, 1.32), (0, -0.05, 1.6), "neck_01"),
    ]
    for s, x in (("l", 1), ("r", -1)):
        S += [
            ("thigh_" + s, (x * 0.1, 0, 0.62), (x * 0.11, 0, 0.34), "hips"),
            ("shin_" + s, (x * 0.11, 0, 0.34), (x * 0.11, 0.02, 0.07), "thigh_" + s),
            ("foot_" + s, (x * 0.11, 0.02, 0.07), (x * 0.11, -0.12, 0.03), "shin_" + s),
            ("upperarm_" + s, (x * 0.2, -0.02, 1.18), (x * 0.26, -0.02, 0.94), "chest"),
            ("forearm_" + s, (x * 0.26, -0.02, 0.94), (x * 0.28, -0.1, 0.75), "upperarm_" + s),
            ("hand_" + s, (x * 0.28, -0.1, 0.75), (x * 0.29, -0.14, 0.67), "forearm_" + s),
        ]
    return S + list(extra)


def bones(BONE, BONE_D, VOID, EYE, ribs=True, skull=True):
    """A skeleton's bones on the biped rig: skull, spine, ribs, pelvis, limbs."""
    if skull:
        bind(blob("skull", (0, -0.06, 1.47), (0.22, 0.24, 0.23), BONE), ["head"])
        bind(blob("jaw", (0, -0.12, 1.35), (0.15, 0.13, 0.07), BONE_D), ["head"])
        for x in (1, -1):
            bind(blob("socket", (x * 0.05, -0.165, 1.46), (0.07, 0.035, 0.065), VOID), ["head"])
            bind(blob("glint", (x * 0.05, -0.183, 1.46), (0.024, 0.012, 0.024), EYE, sub=1), ["head"])
            bind(blob("cheek", (x * 0.078, -0.15, 1.405), (0.05, 0.05, 0.035), BONE), ["head"])
        bind(blob("nose", (0, -0.178, 1.415), (0.03, 0.015, 0.035), VOID, sub=1), ["head"])
        for k in range(5):
            bind(blob("tooth%d" % k, ((k - 2) * 0.024, -0.177, 1.375), (0.018, 0.012, 0.025), BONE, sub=0), ["head"])
    bind(tube("neck", [((0, -0.03, 1.22), 0.035, 0.035), ((0, -0.04, 1.34), 0.03, 0.03)], BONE_D, n=6), ["neck_01", "head"])
    bind(tube("spine", [((0, 0.01, 0.7), 0.035, 0.035), ((0, 0.02, 1.0), 0.035, 0.035), ((0, 0.01, 1.2), 0.03, 0.03)], BONE_D, n=6),
         ["hips", "spine_01", "chest"])
    for k in range(4):
        bind(blob("vert%d" % k, (0, 0.02, 0.76 + k * 0.06), (0.07, 0.06, 0.035), BONE, sub=1), ["spine_01" if k else "hips"])
    if ribs:
        bind(blob("sternum", (0, -0.12, 1.1), (0.04, 0.03, 0.18), BONE), ["chest"])
        for k in range(4):
            z = 1.17 - k * 0.055
            w = 0.17 - k * 0.012
            rib = [((math.sin(a) * w, 0.02 - math.cos(a) * 0.13, z - 0.02 * abs(math.sin(a))), 0.016, 0.016)
                   for a in [math.pi * (-0.9 + i * 0.15) for i in range(13)]]
            bind(tube("rib%d" % k, rib, BONE, n=5, sub=0), ["chest" if k < 2 else "spine_01"])
    bind(blob("pelvis", (0, 0.01, 0.65), (0.2, 0.13, 0.1), BONE), ["hips"])
    for x in (1, -1):
        bind(blob("ilium", (x * 0.085, 0.02, 0.69), (0.11, 0.05, 0.1), BONE, rot=(0, x * 0.4, 0)), ["hips"])
    for s, x in (("l", 1), ("r", -1)):
        P = lambda v: (x * v[0], v[1], v[2])
        bind(tube("femur_" + s, [(P((0.1, 0, 0.62)), 0.04, 0.04), (P((0.11, 0, 0.36)), 0.036, 0.036)], BONE, n=6), ["thigh_" + s])
        bind(blob("knee_" + s, P((0.11, -0.01, 0.34)), (0.07, 0.07, 0.07), BONE_D, sub=1), ["shin_" + s])
        bind(tube("tibia_" + s, [(P((0.11, 0, 0.32)), 0.034, 0.034), (P((0.11, 0.02, 0.09)), 0.03, 0.03)], BONE, n=6), ["shin_" + s])
        bind(blob("heel_" + s, P((0.11, -0.02, 0.05)), (0.08, 0.17, 0.06), BONE_D), ["foot_" + s])
        for k in range(3):
            bind(blob("toe%d_%s" % (k, s), P((0.085 + k * 0.025, -0.13, 0.03)), (0.022, 0.06, 0.03), BONE, sub=0), ["foot_" + s])
        bind(blob("shoulder_" + s, P((0.19, -0.02, 1.18)), (0.08, 0.08, 0.08), BONE_D, sub=1), ["upperarm_" + s])
        bind(tube("humerus_" + s, [(P((0.2, -0.02, 1.16)), 0.035, 0.035), (P((0.26, -0.02, 0.95)), 0.032, 0.032)], BONE, n=6), ["upperarm_" + s])
        bind(blob("elbow_" + s, P((0.26, -0.02, 0.94)), (0.06, 0.06, 0.06), BONE_D, sub=1), ["forearm_" + s])
        bind(tube("radius_" + s, [(P((0.26, -0.02, 0.93)), 0.028, 0.028), (P((0.28, -0.09, 0.78)), 0.026, 0.026)], BONE, n=6), ["forearm_" + s])
        bind(blob("palm_" + s, P((0.285, -0.115, 0.73)), (0.06, 0.07, 0.07), BONE, sub=1), ["hand_" + s])
        for k in range(3):
            bind(tube("finger%d_%s" % (k, s), [(P((0.27 + k * 0.016, -0.13, 0.7)), 0.012, 0.012), (P((0.275 + k * 0.016, -0.16, 0.64)), 0.009, 0.009)],
                      BONE, n=4, sub=0), ["hand_" + s])


def stride(period, a, knee, arm):
    """A walk or run: legs swinging, knees folding as each leg passes, arms
    swinging against the legs."""
    ks = {}
    for s, sg in (("l", 1), ("r", -1)):
        ks["thigh_" + s] = [(0, (-sg * a, 0, 0), None), (period / 2, (sg * a, 0, 0), None), (period, (-sg * a, 0, 0), None)]
        if sg > 0:
            ks["shin_" + s] = [(0, (knee * 0.2, 0, 0), None), (period * 0.25, (knee, 0, 0), None),
                               (period * 0.5, (knee * 0.1, 0, 0), None), (period, (knee * 0.2, 0, 0), None)]
        else:
            ks["shin_" + s] = [(0, (knee * 0.1, 0, 0), None), (period * 0.5, (knee * 0.2, 0, 0), None),
                               (period * 0.75, (knee, 0, 0), None), (period, (knee * 0.1, 0, 0), None)]
        o = "upperarm_l" if s == "r" else "upperarm_r"
        ks[o] = [(0, (-sg * arm, 0, 0), None), (period / 2, (sg * arm, 0, 0), None), (period, (-sg * arm, 0, 0), None)]
    return ks


def bob(period, tilt=4, lift=0.025, lean=0):
    """Hips rising at each step and rolling side to side."""
    q = period / 4
    return [(0, (lean, 0, tilt), (0, 0, 0)), (q, (lean, 0, 0), (0, 0, lift)), (2 * q, (lean, 0, -tilt), (0, 0, 0)),
            (3 * q, (lean, 0, 0), (0, 0, lift)), (period, (lean, 0, tilt), (0, 0, 0))]
