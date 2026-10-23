"""Helpers for modeling props in KayKit's style with Blender's Python.

KayKit props are low-poly and colored by UV: every face points into a swatch
of a shared gradient texture (light at the top of the swatch, dark at the
bottom). A script builds its mesh with `face` and `lathe`, mapping each part
onto a swatch of knight_texture.png, then calls `export`, so the result sits
beside the real KayKit weapons without a texture of its own. Same axes as
theirs: Y up, the grip at the origin.
"""
import json
import math
import os

import bpy  # first: it is what makes bmesh and mathutils importable
import bmesh
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# knight_texture.png is an 8x4 grid of swatches: (column, row).
SWATCH = {
    "steel": (3, 0), "steel_dark": (4, 0), "black": (2, 0), "gold": (4, 1),
    "red": (0, 1), "wood": (6, 1), "leather": (6, 0), "bone": (1, 1),
    "copper": (5, 1), "skin": (0, 0), "rust": (5, 0), "tan": (1, 0),
    "slate": (7, 1), "stone": (1, 2), "white": (0, 2),
}

bm = None
uvl = None


def reset() -> None:
    """Starts a new mesh (and an empty scene): one per exported model."""
    global bm, uvl
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")


reset()


def mark() -> int:
    """The vertex count now: pass it to `place` to move what was built since."""
    return len(bm.verts)


def place(since: int, rot=(0.0, 0.0, 0.0), at=(0.0, 0.0, 0.0), scale=1.0) -> None:
    """Scales, turns (degrees, X then Y then Z) and moves every vertex made
    after `since`: build a part around the origin along Y, then put it."""
    from mathutils import Euler
    bm.verts.ensure_lookup_table()
    e = Euler([math.radians(a) for a in rot], "XYZ")
    sc = Vector(scale) if isinstance(scale, (tuple, list)) else Vector((scale, scale, scale))
    for v in bm.verts[since:]:
        p = Vector((v.co.x * sc.x, v.co.y * sc.y, v.co.z * sc.z))
        p.rotate(e)
        v.co = p + Vector(at)


def plate(pts, half, sw, edges=(), edge_sw=None, edge_out=None, t=(0.3, 0.6)):
    """A flat part: the outline `pts` [(x, y)], counter-clockwise seen from +z,
    pushed `half` to each side in z. Segments listed in `edges` (segment i
    runs from point i to i+1) are ground to a sharp edge that sticks out
    `edge_out` and takes the light end of `edge_sw`."""
    n = len(pts)
    edges = set(edges)
    edge_sw = edge_sw or sw
    edge_out = half * 1.6 if edge_out is None else edge_out
    front = [vert((x, y, half)) for x, y in pts]
    back = [vert((x, y, -half)) for x, y in pts]

    def outward(i):
        (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % n]
        d = Vector((y1 - y0, -(x1 - x0), 0))
        return d.normalized() if d.length > 0 else d

    mids = {}
    for i in range(n):
        prev, nxt = (i - 1) % n in edges, i in edges
        if prev or nxt:
            o = Vector((0, 0, 0))
            if prev and nxt:
                o = (outward((i - 1) % n) + outward(i)).normalized() * edge_out
            mids[i] = vert(Vector((pts[i][0], pts[i][1], 0)) + o)
    face(front, sw, [t[0]] * n)
    face(list(reversed(back)), sw, [t[1]] * n)
    for i in range(n):
        j = (i + 1) % n
        if i in edges:
            face([front[i], mids[i], mids[j], front[j]], edge_sw, [0.15, 0.0, 0.0, 0.15])
            face([mids[i], back[i], back[j], mids[j]], edge_sw, [0.0, 0.3, 0.3, 0.0])
        else:
            face([front[i], back[i], back[j], front[j]], sw, [0.5, 0.75, 0.75, 0.5])


def box(c, size, sw, t=(0.2, 0.7)):
    """An axis-aligned block centered on `c`, lit from above."""
    cx, cy, cz = c
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    v = [vert((cx + sx * hx, cy + sy * hy, cz + sz * hz)) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    # v index: (sx, sy, sz) -> 4*(sx>0) + 2*(sy>0) + (sz>0)
    face([v[2], v[3], v[7], v[6]], sw, [t[0]] * 4)  # top
    face([v[0], v[4], v[5], v[1]], sw, [t[1]] * 4)  # bottom
    face([v[1], v[5], v[7], v[3]], sw, [0.35] * 4)  # +z
    face([v[0], v[2], v[6], v[4]], sw, [0.55] * 4)  # -z
    face([v[4], v[6], v[7], v[5]], sw, [0.4] * 4)  # +x
    face([v[0], v[1], v[3], v[2]], sw, [0.5] * 4)  # -x


def spike(base_c, base_r, tip, sw, sides=4):
    """A cone from a ring of radius `base_r` around `base_c` (in the plane
    across the spike) to the point `tip`."""
    base_c, tip = Vector(base_c), Vector(tip)
    axis = (tip - base_c).normalized()
    a = axis.orthogonal().normalized()
    b = axis.cross(a)
    ring = [vert(base_c + (a * math.cos(k * 2 * math.pi / sides) + b * math.sin(k * 2 * math.pi / sides)) * base_r) for k in range(sides)]
    tv = vert(tip)
    for k in range(sides):
        face([ring[k], ring[(k + 1) % sides], tv], sw, [0.25 + 0.1 * (k % 2), 0.25 + 0.1 * ((k + 1) % 2), 0.0])


def uv(sw: str, t: float) -> tuple:
    """A point in a swatch; t 0 = its light top, 1 = its dark bottom.
    Blender's v runs up, glTF's down: the exporter flips it."""
    c, r = SWATCH[sw]
    t = min(max(t, 0.0), 1.0)
    return ((c + 0.5) / 8.0, 1.0 - (r + 0.06 + t * 0.88) / 4.0)


def vert(p) -> bmesh.types.BMVert:
    return bm.verts.new(p)


def face(verts, sw, ts):
    f = bm.faces.new(verts)
    for loop, t in zip(f.loops, ts):
        loop[uvl].uv = uv(sw, t)
    return f


def lathe(profile, sw, sides=8, shade=None, center=(0.0, 0.0)):
    """A turned part along Y: profile is [(y, radius)], bottom to top."""
    rings = []
    for y, r in profile:
        rings.append([vert((center[0] + r * math.cos(a), y, center[1] + r * math.sin(a)))
                      for a in [i * 2 * math.pi / sides + math.pi / sides for i in range(sides)]])
    for k in range(len(rings) - 1):
        a, b = rings[k], rings[k + 1]
        for i in range(sides):
            j = (i + 1) % sides
            # Lit from one side: faces toward +x sit higher in the swatch.
            side = 0.5 - 0.5 * math.cos(i * 2 * math.pi / sides)
            ta = shade(profile[k][0]) if shade else side
            tb = shade(profile[k + 1][0]) if shade else side
            face([a[i], a[j], b[j], b[i]], sw, [ta, ta, tb, tb])
    if profile[0][1] > 0:
        face(list(reversed(rings[0])), sw, [0.8] * sides)
    if profile[-1][1] > 0:
        face(rings[-1], sw, [0.2] * sides)


def gem(c, w, h, depth, sw="red", facing=1):
    """A six-sided cut stone set flat on a face, bulging toward +z (or -z)."""
    c = Vector(c)
    pts = [vert(c + Vector((w * math.cos(a), h * math.sin(a), 0))) for a in [i * math.pi / 3 for i in range(6)]]
    top = vert(c + Vector((0, 0, depth * facing)))
    for i in range(6):
        tri = [pts[i], pts[(i + 1) % 6], top] if facing > 0 else [pts[(i + 1) % 6], pts[i], top]
        face(tri, sw, [0.2 + 0.1 * (i % 3), 0.2 + 0.1 * ((i + 1) % 3), 0.0])


def export(name: str, out: str) -> None:
    """Writes the mesh as name.gltf + .bin, textured by knight_texture.png."""
    # The game's character shader culls back faces, so every face must look
    # out: the builders above don't all wind them that way.
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    for p in mesh.polygons:
        p.use_smooth = False
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    # Blender is Z-up and the exporter turns it to glTF's Y-up, so the mesh,
    # built Y-up, is turned the other way first.
    obj.rotation_euler = (math.radians(90), 0, 0)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(rotation=True)
    mat = bpy.data.materials.new("knight")
    obj.data.materials.append(mat)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLTF_SEPARATE", use_selection=True,
                              export_image_format="NONE", export_yup=True)
    # No image was written: point the material at the knight_texture.png
    # already beside the KayKit weapons, as theirs do.
    with open(out) as f:
        g = json.load(f)
    g["images"] = [{"mimeType": "image/png", "name": "knight_texture", "uri": "knight_texture.png"}]
    g["textures"] = [{"source": 0}]
    g["materials"][0] = {"doubleSided": True, "name": "knight",
                         "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0, "roughnessFactor": 0.5}}
    with open(out, "w") as f:
        json.dump(g, f, indent=1)
    print("WROTE", out, len(mesh.vertices), "verts", len(mesh.polygons), "faces")
