# Bog Frog (Cinder Mire): a hound-sized swamp frog, crouched on folded hind legs
# with its chest propped on long forelegs. Mottled moss back with rust warts, a
# bile-yellow throat, huge eyes riding the top of a broad flat head, a wet red
# tongue. It hops (Walk, Run), lashes its tongue and leaps (Attack).
# Writes assets/foes/bog_frog_src.glb.
# Run: python3 tools/blender/foes/bog_frog.py -- <repo root>
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "pets"))
import common
from common import *

ROOT = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(ROOT, "assets/foes/")
reset()
common.SIDES, common.BLOB_SUB = 0.9, 1

# Low stance: every position is squashed toward the ground by K (radii are not), so the legs
# stay thick and the frog sits flat instead of standing on stilts.
K = 0.74
_tube, _blob, _cone, _sheet, _armature = tube, blob, cone, sheet, armature
_Z = lambda v: (v[0], v[1], v[2] * K)
tube = lambda name, path, m, **kw: _tube(name, [(_Z(p), a, b) for p, a, b in path], m, **kw)
blob = lambda name, at, size, m, **kw: _blob(name, _Z(at), size, m, **kw)
cone = lambda name, base, tip, r, m, **kw: _cone(name, _Z(base), _Z(tip), r, m, **kw)
sheet = lambda name, pts, m, thick=0.02: _sheet(name, [_Z(p) for p in pts], m, thick)
armature = lambda spec: _armature([(n, _Z(h), _Z(t), par) for n, h, t, par in spec])

SKIN = mat("frog_skin", "3c4c2a")
DARK = mat("frog_dark", "212d19")
BELLY = mat("frog_belly", "a39c5c")
WART = mat("frog_wart", "6e5a2c")
EYE = mat("frog_eye", "d0a42c")
VOID = mat("frog_void", "0a0c08", 1.0)
TONGUE = mat("frog_tongue", "8e3a3a")
MOUTH = mat("frog_mouth", "4a2420")

S = [
    ("hips", (0, 0.32, 0.5), (0, 0.12, 0.52), None),
    ("spine_01", (0, 0.12, 0.52), (0, -0.2, 0.58), "hips"),
    ("head", (0, -0.2, 0.6), (0, -0.55, 0.66), "spine_01"),
    ("jaw", (0, -0.3, 0.55), (0, -0.62, 0.55), "head"),
    ("tongue_1", (0, -0.45, 0.57), (0, -0.62, 0.57), "head"),
    ("tongue_2", (0, -0.62, 0.57), (0, -0.78, 0.57), "tongue_1"),
]
for s, x in (("l", 1), ("r", -1)):
    S += [
        ("arm_%s_1" % s, (x * 0.24, -0.16, 0.56), (x * 0.3, -0.3, 0.3), "spine_01"),
        ("arm_%s_2" % s, (x * 0.3, -0.3, 0.3), (x * 0.3, -0.46, 0.03), "arm_%s_1" % s),
        ("thigh_" + s, (x * 0.27, 0.34, 0.5), (x * 0.5, 0.08, 0.6), "hips"),
        ("shin_" + s, (x * 0.5, 0.08, 0.6), (x * 0.42, 0.5, 0.14), "thigh_" + s),
        ("foot_" + s, (x * 0.42, 0.5, 0.14), (x * 0.4, 0.1, 0.03), "shin_" + s),
    ]
rig = armature(S)

body = tube("body", [((0, 0.52, 0.46), 0.18, 0.17), ((0, 0.3, 0.52), 0.34, 0.3), ((0, 0.0, 0.54), 0.34, 0.3), ((0, -0.22, 0.56), 0.26, 0.24),
                     ((0, -0.3, 0.57), 0.2, 0.18)], SKIN, n=9)
two_tone(body, BELLY, None, down=-0.35)
bind(body, ["hips", "spine_01"])
# Head: broad, flat, a wide mouth slit; throat sac swollen under it.
head = tube("head", [((0, -0.2, 0.62), 0.27, 0.2), ((0, -0.4, 0.64), 0.28, 0.16), ((0, -0.58, 0.62), 0.2, 0.1), ((0, -0.68, 0.6), 0.1, 0.07)], SKIN, n=8)
two_tone(head, BELLY, None, down=-0.5)
bind(head, ["head"])
bind(tube("lowjaw", [((0, -0.28, 0.54), 0.22, 0.05), ((0, -0.46, 0.53), 0.2, 0.045), ((0, -0.64, 0.55), 0.09, 0.035)], BELLY, n=6), ["jaw"])
bind(blob("mouth", (0, -0.46, 0.575), (0.4, 0.4, 0.035), MOUTH, sub=0), ["head"])
bind(blob("throat", (0, -0.34, 0.5), (0.26, 0.2, 0.14), BELLY), ["jaw", "head"])
bind(tube("tongue", [((0, -0.45, 0.57), 0.04, 0.012), ((0, -0.6, 0.575), 0.045, 0.012), ((0, -0.76, 0.57), 0.035, 0.012)], TONGUE, n=4),
     ["tongue_1", "tongue_2"])
for x in (1, -1):
    bind(blob("eyelump", (x * 0.15, -0.34, 0.77), (0.17, 0.17, 0.13), SKIN, rot=(0, 0, 0)), ["head"])
    bind(blob("eye", (x * 0.17, -0.36, 0.8), (0.13, 0.13, 0.11), EYE, sub=1), ["head"])
    bind(blob("pupil", (x * 0.185, -0.42, 0.81), (0.1, 0.03, 0.026), VOID, sub=0), ["head"])
    bind(blob("nostril", (x * 0.05, -0.64, 0.665), (0.02, 0.02, 0.014), VOID, sub=0), ["head"])
# Warts across the back.
for k, (x, y, z, w) in enumerate([(0.16, 0.2, 0.8, 0.07), (-0.2, 0.05, 0.82, 0.08), (0.05, 0.38, 0.78, 0.06), (-0.14, 0.34, 0.74, 0.06),
                                  (0.24, -0.05, 0.8, 0.06), (0.0, -0.12, 0.8, 0.07), (-0.05, 0.12, 0.84, 0.07)]):
    bind(blob("wart%d" % k, (x, y, z), (w, w, w * 0.7), WART, sub=1), ["spine_01" if y < 0.2 else "hips"])

for s, x in (("l", 1), ("r", -1)):
    P = lambda v: (x * v[0], v[1], v[2])
    # Forelegs: long and stiff, splayed webbed hands.
    bind(tube("fore_" + s, [(P((0.22, -0.16, 0.56)), 0.1, 0.1), (P((0.3, -0.3, 0.3)), 0.07, 0.07), (P((0.3, -0.46, 0.05)), 0.055, 0.05)], SKIN, n=6),
         ["arm_%s_1" % s, "arm_%s_2" % s])
    for k in (-1, 0, 1):
        bind(cone("finger%d%s" % (k, s), P((0.3 + k * 0.03, -0.46, 0.04)), P((0.3 + k * 0.1, -0.62, 0.015)), 0.028, DARK, n=3), ["arm_%s_2" % s])
    bind(sheet("hweb_" + s, [P((0.2, -0.62, 0.012)), P((0.3, -0.46, 0.04)), P((0.4, -0.62, 0.012))], DARK, 0.01), ["arm_%s_2" % s])
    # Hind legs: big thigh, folded shin, long webbed foot.
    bind(tube("thigh_" + s, [(P((0.25, 0.36, 0.5)), 0.17, 0.15), (P((0.42, 0.18, 0.6)), 0.12, 0.11), (P((0.5, 0.08, 0.6)), 0.075, 0.075)], SKIN, n=7),
         ["thigh_" + s])
    bind(tube("shin_" + s, [(P((0.5, 0.08, 0.6)), 0.07, 0.07), (P((0.46, 0.3, 0.38)), 0.06, 0.06), (P((0.42, 0.5, 0.15)), 0.05, 0.05)], SKIN, n=6), ["shin_" + s])
    bind(tube("foot_" + s, [(P((0.42, 0.5, 0.14)), 0.05, 0.04), (P((0.4, 0.3, 0.06)), 0.055, 0.035), (P((0.4, 0.1, 0.035)), 0.06, 0.03)], DARK, n=5), ["foot_" + s])
    for k in (-1, 0, 1):
        bind(cone("toe%d%s" % (k, s), P((0.4 + k * 0.03, 0.12, 0.04)), P((0.4 + k * 0.1, -0.06, 0.015)), 0.028, DARK, n=3), ["foot_" + s])
    bind(sheet("fweb_" + s, [P((0.3, -0.06, 0.012)), P((0.4, 0.12, 0.04)), P((0.5, -0.06, 0.012))], DARK, 0.01), ["foot_" + s])

fr = skin(rig, "BogFrog")
bake(fr, 256, OUT + "bog_frog_tex.png")


def both(bone, ks):
    return {bone + "_l": ks, bone + "_r": ks}

def mk(**kw):
    return kw

def legs(rest_t, rest_s, rest_f, t, s_, f, arm_a):
    """A frame of leg angles: (thigh, shin, foot) X degrees, forearm swing."""
    return {"thigh": t, "shin": s_, "foot": f, "arm": arm_a}

def pose_clip(name, length, frames, loop, extra=None):
    """frames: [(t, hipsZ, hipsY, hips pitch, thigh, shin, foot, arm1, arm2, head, jaw)]"""
    ks = {"hips": [], "head": [], "jaw": [], "thigh_l": [], "thigh_r": [], "shin_l": [], "shin_r": [], "foot_l": [], "foot_r": [],
          "arm_l_1": [], "arm_r_1": [], "arm_l_2": [], "arm_r_2": []}
    for t, hz, hy, hp, th, sh, ft, a1, a2, hd, jw in frames:
        ks["hips"].append((t, (hp, 0, 0), (0, hy, hz)))
        ks["head"].append((t, (hd, 0, 0), None))
        ks["jaw"].append((t, (jw, 0, 0), None))
        for s in "lr":
            ks["thigh_" + s].append((t, (th, 0, 0), None))
            ks["shin_" + s].append((t, (sh, 0, 0), None))
            ks["foot_" + s].append((t, (ft, 0, 0), None))
            ks["arm_%s_1" % s].append((t, (a1, 0, 0), None))
            ks["arm_%s_2" % s].append((t, (a2, 0, 0), None))
    if extra:
        ks.update(extra)
    clip(rig, name, length, ks, loop=loop)

# Idle: throat pulsing, a slow sway, one eye-blink of the head.
pose_clip("Idle", 1.8, [(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), (0.9, -0.012, 0, 1.5, 1, -1, 0, 1, 0, 3, 7), (1.8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)], True)

def hop(name, period, lift, reach, pitch):
    # crouch, spring (legs straighten), air, land; forelegs reach and plant.
    return pose_clip(name, period, [
        (0, -0.05, 0, -6, -22, 38, -10, -6, 0, 4, 0),
        (period * 0.25, lift * 0.5, -reach * 0.3, pitch, 30, -42, 28, 28, -10, -6, 4),
        (period * 0.5, lift, -reach * 0.6, pitch * 0.8, 24, -34, 24, 38, -16, -8, 6),
        (period * 0.8, 0.0, -reach * 0.9, -2, -8, 16, -4, -10, 4, 2, 0),
        (period, -0.05, 0, -6, -22, 38, -10, -6, 0, 4, 0)], True)

hop("Walk", 0.8, 0.12, 0.0, 6)
hop("Run", 0.55, 0.26, 0.0, 12)

# Attack: coils back, then springs forward and lashes its tongue, jaws wide.
pose_clip("Attack", 0.9, [
    (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    (0.3, -0.1, 0.06, -10, -30, 48, -14, -12, 0, 8, 0),
    (0.46, 0.14, -0.2, 14, 34, -46, 30, 40, -10, -12, 40),
    (0.62, 0.04, -0.28, 4, 10, -10, 6, 18, 0, -4, 28),
    (0.9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)], False,
    extra={"tongue_1": [(0, (0, 0, 0), None), (0.3, (0, 0, 0), None), (0.46, (-8, 0, 0), (0, -0.45, 0.0)), (0.62, (0, 0, 0), (0, -0.25, 0)), (0.9, (0, 0, 0), None)],
           "tongue_2": [(0, (0, 0, 0), None), (0.46, (10, 0, 0), None), (0.62, (0, 0, 0), None), (0.9, (0, 0, 0), None)]})
# Hit: flinches back, throat bulging, limbs jerking in.
pose_clip("Hit", 0.4, [(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), (0.1, -0.08, 0.08, -12, -20, 40, -10, -20, 6, 12, 24), (0.4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)], False)
# Die: topples over onto its back, legs curling skyward.
pose_clip("Die", 1.2, [
    (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    (0.3, -0.06, 0.05, -12, -20, 36, -8, -14, 4, 10, 18),
    (0.8, -0.2, 0.05, -90, -50, 60, -20, -50, 20, 14, 26),
    (1.2, -0.3, 0.05, -135, -60, 80, -30, -80, 30, 16, 30)], False)

export(rig, fr, OUT + "bog_frog_src.glb")
os.remove(OUT + "bog_frog_tex.png")
