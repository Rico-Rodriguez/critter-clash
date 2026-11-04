# Crystal Shardling (rh_shard): a floating crystal golem. A faceted geode torso that tapers to a
# point, iron bands, a glowing heart, a floating crown-head with a dark visor, two heavy crystal
# fists and a ring of six shards orbiting it. Writes assets/foes/shardling_src.glb.
# Run: python3 tools/blender/foes/shard.py -- <repo root>
from kit import *

OUT = out_dir()
reset()

ICE = mat("sh_ice", "8fd3ea")
ICE_D = mat("sh_ice_d", "3d7ea0")
DEEP = mat("sh_deep", "24506b")
IRON = mat("sh_iron", "232a32", 0.45)
IRON_L = mat("sh_iron_l", "4a5560", 0.45)
CORE = mat("sh_core", "c8f6ff")
EYE = mat("sh_eye", "e4fbff")
VOID = mat("sh_void", "05080a", 1.0)

R = 0.62
SH = [(0, 0.58), (60, 0.82), (120, 1.1), (180, 0.7), (240, 1.0), (300, 1.22)]

S = [
    ("root", (0, 0, 0.4), (0, 0, 0.65), None),
    ("body", (0, 0, 0.65), (0, 0, 1.0), "root"),
    ("head", (0, 0, 1.08), (0, -0.02, 1.34), "body"),
    ("orbit", (0, 0, 0.8), (0, 0, 0.9), "root"),
]
for i, (a, h) in enumerate(SH):
    ar = math.radians(a)
    S.append(("sh%d" % i, (math.cos(ar) * R, math.sin(ar) * R, h), (math.cos(ar) * (R + 0.12), math.sin(ar) * (R + 0.12), h), "orbit"))
for s, x in (("l", 1), ("r", -1)):
    S += [
        ("upperarm_" + s, (x * 0.3, 0, 0.95), (x * 0.5, -0.05, 0.78), "body"),
        ("forearm_" + s, (x * 0.5, -0.05, 0.78), (x * 0.56, -0.28, 0.68), "upperarm_" + s),
    ]
rig = armature(S)

# Torso: a hexagonal geode, widest at the shoulders, running down to a point.
bind(tube("torso", [((0, 0, 0.37), 0.015, 0.015), ((0, 0, 0.55), 0.14, 0.14), ((0, 0, 0.8), 0.24, 0.24), ((0, 0, 0.98), 0.27, 0.27),
                    ((0, 0, 1.05), 0.14, 0.14)], ICE_D, n=6), ["root", "body"])
bind(tube("collar", [((0, 0, 0.66), 0.175, 0.175), ((0, 0, 0.73), 0.2, 0.2)], IRON, n=6), ["body"])
bind(tube("yoke", [((0, 0, 0.93), 0.285, 0.285), ((0, 0, 1.0), 0.285, 0.285)], IRON, n=6), ["body"])
# The heart: a pale prism showing through the chest.
bind(crystal("heart", (0, -0.1, 0.84), (0, -0.32, 0.84), 0.06, CORE, n=6), ["body"])
for k, a in enumerate((20, 140, 260)):
    ar = math.radians(a)
    bind(crystal("back%d" % k, (math.cos(ar) * 0.13, 0.12 + math.sin(ar) * 0.1, 0.9), (math.cos(ar) * 0.3, 0.3 + math.sin(ar) * 0.2, 1.22 - k * 0.07), 0.06,
                 ICE if k % 2 else ICE_D, n=5), ["body"])
# Head: a floating diamond with a dark visor and a crown of points.
bind(tube("skull", [((0, 0, 1.06), 0.015, 0.015), ((0, 0, 1.14), 0.1, 0.11), ((0, 0, 1.23), 0.11, 0.12), ((0, 0, 1.3), 0.06, 0.07)], ICE, n=6), ["head"])
bind(plate("visor", (0, -0.1, 1.2), (0.17, 0.05, 0.05), VOID), ["head"])
for x in (1, -1):
    bind(blob("eye", (x * 0.04, -0.125, 1.2), (0.026, 0.018, 0.02), EYE, sub=0), ["head"])
for k, a in enumerate((0, 72, 144, 216, 288)):
    ar = math.radians(a)
    bind(crystal("crown%d" % k, (math.sin(ar) * 0.06, math.cos(ar) * 0.06, 1.27), (math.sin(ar) * 0.1, math.cos(ar) * 0.1, 1.42 + 0.04 * (k % 2)), 0.03,
                 ICE if k % 2 else ICE_D, n=4), ["head"])
for s, x in (("l", 1), ("r", -1)):
    P = lambda v: (x * v[0], v[1], v[2])
    bind(crystal("paul_" + s, P((0.28, 0.0, 0.97)), P((0.5, 0.02, 1.3)), 0.075, ICE, n=5), ["body"])
    bind(crystal("paul2_" + s, P((0.3, 0.05, 0.95)), P((0.52, 0.2, 1.1)), 0.05, DEEP, n=4), ["body"])
    bind(tube("arm_" + s, [(P((0.3, 0, 0.95)), 0.075, 0.075), (P((0.5, -0.05, 0.78)), 0.06, 0.06), (P((0.54, -0.2, 0.7)), 0.055, 0.055)], IRON_L, n=5),
         ["body", "upperarm_" + s, "forearm_" + s])
    bind(blob("fist_" + s, P((0.57, -0.3, 0.67)), (0.17, 0.18, 0.15), ICE_D, sub=1), ["forearm_" + s])
    for k in (-1, 0, 1):
        bind(crystal("knuck_%s%d" % (s, k), P((0.57 + k * 0.05, -0.38, 0.68 - abs(k) * 0.01)), P((0.57 + k * 0.07, -0.58, 0.64)), 0.04, ICE, n=4), ["forearm_" + s])
    bind(crystal("under_" + s, P((0.55, -0.26, 0.62)), P((0.58, -0.2, 0.36)), 0.045, DEEP, n=4), ["forearm_" + s])
# The orbit: six shards, each tilted along its own path.
for i, (a, h) in enumerate(SH):
    ar = math.radians(a)
    c, sn = math.cos(ar), math.sin(ar)
    base = (c * R, sn * R, h - 0.13)
    tip = (c * R - sn * 0.05, sn * R + c * 0.05, h + 0.2 + 0.03 * (i % 2))
    bind(crystal("shard%d" % i, base, tip, 0.055 + 0.01 * (i % 2), ICE if i % 2 else ICE_D, n=4), ["sh%d" % i])

golem = skin(rig, "Shardling")
bake(golem, 512, OUT + "shard_tex.png")


def spin(act, turns, period):
    """The orbit bone turning `turns` times in `period` seconds (written by hand so the quaternions
    stay on one side and the spin stays even)."""
    rig.animation_data_create()
    rig.animation_data.action = act
    pb = rig.pose.bones["orbit"]
    pb.rotation_mode = "QUATERNION"
    n = 12
    for i in range(n + 1):
        th = math.pi * 2 * turns * i / n
        pb.rotation_quaternion = (math.cos(th / 2), 0, math.sin(th / 2), 0)
        pb.keyframe_insert("rotation_quaternion", frame=1 + round(period * i / n * 30))
    pb.rotation_quaternion = (1, 0, 0, 0)
    linear(act, ["orbit"])
    rig.animation_data.action = None






def shards(keys, times_d):
    """times_d: [(t, radial offset, z offset)] applied to every shard."""
    for i, (a, _) in enumerate(SH):
        ar = math.radians(a)
        keys["sh%d" % i] = [(t, (0, 0, 0), (math.cos(ar) * d, math.sin(ar) * d, z)) for t, d, z in times_d]
    return keys


def arms(keys, period, swing, fore=0):
    for s, sg in (("l", 1), ("r", -1)):
        ph = 1 if s == "l" else -1
        keys["upperarm_" + s] = cyc(period, (swing * ph, -sg * 6, 0), (-swing * ph, -sg * 6, 0))
        keys["forearm_" + s] = cyc(period, (fore - 6, 0, 0), (fore, 0, 0))
    return keys


def hov(period, amp):
    return cycl(period, ((0, 0, 0), (0, 0, amp)), ((0, 0, 0), (0, 0, -amp)))


idle = arms({}, 3.0, 5)
idle["root"] = hov(3.0, 0.05)
idle["body"] = cyc(3.0, (0, -3, 0), (0, 3, 0))
idle["head"] = cyc(3.0, (0, 0, -12), (2, 0, 12))
for i in range(6):
    idle["sh%d" % i] = [(0, (0, 0, 0), (0, 0, 0.03 * (1 if i % 2 else -1))), (1.5, (0, 0, 0), (0, 0, -0.03 * (1 if i % 2 else -1))), (3.0, (0, 0, 0), (0, 0, 0.03 * (1 if i % 2 else -1)))]
spin(clip(rig, "Idle", 3.0, idle), 1, 3.0)

walk = arms({}, 1.2, 18, 12)
walk["root"] = [(0, (12, 0, 0), (0, 0, 0)), (0.3, (12, 0, 0), (0, 0, 0.04)), (0.6, (12, 0, 0), (0, 0, 0)), (0.9, (12, 0, 0), (0, 0, 0.04)), (1.2, (12, 0, 0), (0, 0, 0))]
walk["body"] = cyc(1.2, (0, -5, 0), (0, 5, 0))
walk["head"] = cyc(1.2, (-8, 0, -6), (-8, 0, 6))
spin(clip(rig, "Walk", 1.2, walk), 1, 1.2)

run = arms({}, 0.8, 30, 24)
run["root"] = [(0, (22, 0, 0), (0, 0, 0)), (0.2, (22, 0, 0), (0, 0, 0.05)), (0.4, (22, 0, 0), (0, 0, 0)), (0.6, (22, 0, 0), (0, 0, 0.05)), (0.8, (22, 0, 0), (0, 0, 0))]
run["body"] = cyc(0.8, (0, -7, 0), (0, 7, 0))
run["head"] = cyc(0.8, (-14, 0, 0), (-14, 0, 0))
spin(clip(rig, "Run", 0.8, run), 1, 0.8)

# Attack: the shards draw in and the arms pull back, then it bursts out and slams both fists forward.
atk = {}
atk["root"] = [(0, (0, 0, 0), (0, 0, 0)), (0.3, (-12, 0, 0), (0, 0.08, -0.1)), (0.42, (18, 0, 0), (0, -0.2, 0.04)), (0.8, (0, 0, 0), (0, 0, 0))]
atk["head"] = [(0, (0, 0, 0), None), (0.3, (-14, 0, 0), None), (0.42, (12, 0, 0), None), (0.8, (0, 0, 0), None)]
for s in "lr":
    atk["upperarm_" + s] = [(0, (0, 0, 0), None), (0.3, (50, 0, 0), None), (0.42, (-70, 0, 0), None), (0.8, (0, 0, 0), None)]
    atk["forearm_" + s] = [(0, (0, 0, 0), None), (0.3, (30, 0, 0), None), (0.42, (-25, 0, 0), None), (0.8, (0, 0, 0), None)]
shards(atk, [(0, 0, 0), (0.3, -0.28, -0.05), (0.42, 0.34, 0.06), (0.8, 0, 0)])
spin(clip(rig, "Attack", 0.8, atk, loop=False), 0.6, 0.8)

hit = {}
hit["root"] = [(0, (0, 0, 0), (0, 0, 0)), (0.1, (-14, 0, 6), (0, 0.16, 0.02)), (0.4, (0, 0, 0), (0, 0, 0))]
hit["head"] = [(0, (0, 0, 0), None), (0.1, (-20, 0, 14), None), (0.4, (0, 0, 0), None)]
for s, sg in (("l", 1), ("r", -1)):
    hit["upperarm_" + s] = [(0, (0, 0, 0), None), (0.1, (22, -sg * 24, 0), None), (0.4, (0, 0, 0), None)]
shards(hit, [(0, 0, 0), (0.1, 0.14, 0.04), (0.4, 0, 0)])
spin(clip(rig, "Hit", 0.4, hit, loop=False), 0.3, 0.4)

# Die: the heart goes dark, the body drops and the crystals fly apart.
die = {}
die["root"] = [(0, (0, 0, 0), (0, 0, 0)), (0.12, (-10, 0, 0), (0, 0.1, 0.05)), (0.55, (30, 22, 0), (0.06, -0.04, -0.36)), (0.9, (34, 26, 0), (0.06, -0.04, -0.38))]
die["head"] = [(0, (0, 0, 0), None), (0.12, (-18, 0, 10), None), (0.55, (30, 0, 60), (0.18, -0.08, -0.24)), (0.9, (36, 0, 80), (0.22, -0.1, -0.3))]
for s, sg in (("l", 1), ("r", -1)):
    die["upperarm_" + s] = [(0, (0, 0, 0), None), (0.12, (-30, -sg * 30, 0), None), (0.55, (20, sg * 30, 0), (sg * 0.08, 0, -0.1)), (0.9, (26, sg * 40, 0), (sg * 0.12, 0, -0.14))]
    die["forearm_" + s] = [(0, (0, 0, 0), None), (0.55, (40, 0, 0), None), (0.9, (50, 0, 0), None)]
shards(die, [(0, 0, 0), (0.12, 0.1, 0.05), (0.55, 0.42, -0.5), (0.9, 0.5, -0.78)])
spin(clip(rig, "Death", 0.9, die, loop=False), 0.5, 0.9)

# Spawn: the shards fly in from far out and the golem rises from the ground.
sp = {}
sp["root"] = [(0, (0, 0, 0), (0, 0, -0.42)), (0.5, (-8, 0, 0), (0, 0, 0.06)), (0.8, (0, 0, 0), (0, 0, 0))]
sp["head"] = [(0, (30, 0, 0), None), (0.5, (-14, 0, 0), None), (0.8, (0, 0, 0), None)]
for s, sg in (("l", 1), ("r", -1)):
    sp["upperarm_" + s] = [(0, (20, -sg * 40, 0), None), (0.5, (-30, -sg * 10, 0), None), (0.8, (0, 0, 0), None)]
shards(sp, [(0, 1.2, -0.2), (0.5, 0.0, 0.0), (0.8, 0, 0)])
spin(clip(rig, "Spawn", 0.8, sp, loop=False), 1.4, 0.8)

export(rig, golem, OUT + "shardling_src.glb")
os.remove(OUT + "shard_tex.png")
