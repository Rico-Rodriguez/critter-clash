# Shared setup for the Blender-made foes: the pets' helpers (tools/blender/pets/common.py)
# plus a crystal prism and clip shorthands. Each foe script writes assets/foes/<id>_src.glb;
# tools/art/wrap_foes.gd then wraps it into <id>.tscn. Run a script with:
#   python3 tools/blender/foes/<name>.py -- <repo root>
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "pets"))
import common
from common import *

common.SIDES, common.BLOB_SUB = 1.0, 1


def root_dir():
    return sys.argv[sys.argv.index("--") + 1]


def out_dir():
    return os.path.join(root_dir(), "assets/foes/")


def crystal(name, base, tip, r, m, n=6, bulge=0.3):
    """A pointed prism from `base` to `tip`: a short taper at the base, straight sides, a point."""
    b, t = Vector(base), Vector(tip)
    path = [(b, r * 0.1, r * 0.1), (b + (t - b) * bulge * 0.5, r, r), (b + (t - b) * 0.72, r * 0.9, r * 0.9), (t, r * 0.03, r * 0.03)]
    return tube(name, path, m, n=n, sub=0)


def plate(name, at, size, m, rot=(0, 0, 0)):
    """A flat-sided box (no rounding): armour plates, blades, slabs."""
    return blob(name, at, size, m, sub=0, rot=rot)


def cyc(period, *vals):
    """Keys that start and end on the same pose: evenly spaced `vals` over `period`, then vals[0] again."""
    n = len(vals)
    ks = [(period * i / n, v, None) for i, v in enumerate(vals)]
    ks.append((period, vals[0], None))
    return ks


def cycl(period, *vals):
    """As `cyc`, with a (rot, loc) pair per value."""
    n = len(vals)
    ks = [(period * i / n, v[0], v[1]) for i, v in enumerate(vals)]
    ks.append((period, vals[0][0], vals[0][1]))
    return ks


def linear(act, bone_names):
    """Linear interpolation on the curves of the given bones (a spin must not ease at each key)."""
    for fc in common._fcurves(act):
        if any('"%s"' % b in fc.data_path for b in bone_names):
            for kp in fc.keyframe_points:
                kp.interpolation = "LINEAR"
