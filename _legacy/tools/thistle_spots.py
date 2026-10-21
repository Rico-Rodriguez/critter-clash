"""Thistle second pass, run after tools/paint_thistle.py.

1. Below the cap (wrist frills, tail ribbon, neck) the oxblood is
   repainted in a deep bone shade: from the hunt camera those red frills
   read as stray shards. Only the cap keeps its red spots.
2. Cap spots become raised domes: a height field from the distance to each
   spot's edge is turned into normals and folded into the normal map, the
   ring just outside each spot is darkened (contact AO), and spot edges are
   lifted toward a lighter, translucent red.

Writes thistle_paint.png (in place) and thistle_normal_spots.png.
"""
import json, struct
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

D = "assets/models/sketchfab/"
b = open(D + "thistle.glb", "rb").read()
n = struct.unpack("<I", b[12:16])[0]
j = json.loads(b[20:20 + n])
bo = 20 + n + 8


def acc(i, k, dt):
    a = j["accessors"][i]
    v = j["bufferViews"][a["bufferView"]]
    off = bo + v.get("byteOffset", 0) + a.get("byteOffset", 0)
    return np.frombuffer(b, dtype=dt, count=a["count"] * k, offset=off).reshape(a["count"], k)


p = j["meshes"][0]["primitives"][0]
P = acc(p["attributes"]["POSITION"], 3, "f4")
UV = acc(p["attributes"]["TEXCOORD_0"], 2, "f4")
ia = j["accessors"][p["indices"]]
I = acc(p["indices"], 1, {5123: "u2", 5125: "u4"}[ia["componentType"]]).reshape(-1, 3)
tex = Image.open(D + "thistle_paint.png").convert("RGB")
W, H = tex.size
A = np.asarray(tex).astype(float)
cen = P[I].mean(1)


def island(sel):
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    for t in I[sel]:
        d.polygon([(UV[k, 0] * W, UV[k, 1] * H) for k in t], fill=255)
    return np.asarray(m) > 0


low = island(cen[:, 1] < 4.4)
cap = island(cen[:, 1] >= 5.2)
r, g, bl = A[..., 0], A[..., 1], A[..., 2]
redness = (r > g * 1.5) & (r > bl * 1.5) & (r > 60)

# 1. Frills and ribbon to bone.
red_low = redness & low & ~cap
body = np.median(A[low & ~redness], 0)
lum = A[red_low].mean(1, keepdims=True)
A[red_low] = np.clip(body * 0.62 * (0.6 + 0.8 * lum / max(lum.mean(), 1.0)), 0, 255)

# 2. Raised spots on the cap.
spots = ndimage.binary_opening(redness & cap, iterations=1)
inside = ndimage.distance_transform_edt(spots)
outside = ndimage.distance_transform_edt(~spots)
dome = np.sqrt(np.clip(inside / 9.0, 0, 1))  # rounded shoulder, flat top
height = ndimage.gaussian_filter(dome, 1.2)
gy, gx = np.gradient(height)
strength = 6.0
nx, ny = -gx * strength, -gy * strength
nrm = np.asarray(Image.open(D + "thistle_2.png").convert("RGB")).astype(float) / 127.5 - 1.0
# Reoriented-ish blend: add the dome's slope to the base normal, renormalise.
out = np.dstack([nrm[..., 0] + nx, nrm[..., 1] - ny, nrm[..., 2]])
out /= np.linalg.norm(out, axis=2, keepdims=True) + 1e-6
Image.fromarray(np.clip((out + 1.0) * 127.5, 0, 255).astype("uint8")).save(D + "thistle_normal_spots.png")

ring = np.clip(1.0 - outside / 5.0, 0, 1) * (~spots) * cap
A *= (1.0 - 0.35 * ring)[..., None]
edge = np.clip(1.0 - inside / 4.0, 0, 1) * spots
A = A + edge[..., None] * np.array([70.0, 18.0, 14.0]) * 0.8
top = np.clip(inside / 9.0, 0, 1) * spots
A *= (1.0 - 0.15 * top)[..., None]  # deeper core, lighter translucent edge
Image.fromarray(np.clip(A, 0, 255).astype("uint8")).save(D + "thistle_paint.png")
print("spots", int(spots.sum()), "frill texels", int(red_low.sum()))
