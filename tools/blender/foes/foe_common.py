# Shared helpers for the Blender-made foes: the pets' builders (tools/blender/pets/common.py)
# plus looping-clip helpers and the foe export. Foes are written to
# assets/foes/<id>_src.glb and wrapped by tools/art/wrap_foes.gd.
import sys, os, math
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "pets"))
import common
from common import *

ROOT = sys.argv[sys.argv.index("--") + 1]
SCRATCH = os.path.join(ROOT, "scratch")
os.makedirs(SCRATCH, exist_ok=True)


def osc(period, axes, n=8, base=(0, 0, 0), loc=None):
    """Keys for a looping sway: axes {0|1|2: (amplitude degrees, phase 0..1)}; loc
    {0|1|2: (amplitude metres, phase)} moves the bone. Returns (time, rot, loc) keys."""
    ks = []
    for i in range(n + 1):
        t = period * i / n
        rot = list(base)
        for ax, (amp, ph) in axes.items():
            rot[ax] += amp * math.sin(2 * math.pi * (i / n + ph))
        lc = None
        if loc:
            lc = [0.0, 0.0, 0.0]
            for ax, (amp, ph) in loc.items():
                lc[ax] += amp * math.sin(2 * math.pi * (i / n + ph))
            lc = tuple(lc)
        ks.append((t, tuple(rot), lc))
    return ks


def pose(*frames):
    """Keys from (time, (rx, ry, rz)) or (time, (rx, ry, rz), (dx, dy, dz))."""
    return [(f[0], f[1], f[2] if len(f) > 2 else None) for f in frames]


def finish(rig, body, name, size=512):
    """Bakes the one texture and writes assets/foes/<name>_src.glb."""
    bake(body, size, os.path.join(SCRATCH, name + "_tex.png"))
    export(rig, body, os.path.join(ROOT, "assets/foes/%s_src.glb" % name))
