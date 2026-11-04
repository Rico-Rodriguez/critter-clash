# Shared parts for foes built as faceted dark plate (run with Blender's Python).
# Builds on the pets' helpers: convex hulls give crisp plates, frustums give
# pauldrons, lames and tassets. Same axes as the pets: -Y forward, Z up.
import sys, os, math
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "pets"))
import bpy, bmesh
from mathutils import Vector, Euler
import common
from common import *

common.HARD = True
common.BLOB_SUB = 0


def hull(name, pts, m, at=(0, 0, 0), rot=(0, 0, 0)):
    """The convex hull of `pts` as a flat-shaded solid."""
    bm = bmesh.new()
    vs = [bm.verts.new(Vector(p)) for p in pts]
    bmesh.ops.convex_hull(bm, input=vs)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    o = common._obj(name, bm, m, 0)
    o.location = at
    o.rotation_euler = Euler([math.radians(a) for a in rot])
    return o


def frustum(name, at, bot, top, h, m, rot=(0, 0, 0), shift=(0, 0)):
    """A plate: a rectangle `bot` (w, d) at the base, `top` (w, d) at height h,
    the top slid by `shift` (x, y). Rotation in degrees."""
    pts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            pts.append((sx * bot[0] / 2, sy * bot[1] / 2, 0))
            pts.append((sx * top[0] / 2 + shift[0], sy * top[1] / 2 + shift[1], h))
    return hull(name, pts, m, at, rot)


def spike(name, base, tip, r, m, n=4):
    return cone(name, base, tip, r, m, n=n)


def ring(name, centre, rx, ry, h, m, n=8, z0=0.0, taper=1.0):
    """A band round a limb or waist: two rings joined, `taper` scales the top."""
    pts = []
    for i in range(n):
        a = 2 * math.pi * (i + 0.5) / n
        pts.append((math.cos(a) * rx, math.sin(a) * ry, 0))
        pts.append((math.cos(a) * rx * taper, math.sin(a) * ry * taper, h))
    return hull(name, pts, m, (centre[0], centre[1], centre[2] + z0))


def tris(body):
    return sum(len(p.vertices) - 2 for p in body.data.polygons)
