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
    "copper": (5, 1), "skin": (0, 0),
}

bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()
uvl = bm.loops.layers.uv.new("UVMap")


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
