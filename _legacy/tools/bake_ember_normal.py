"""Add hex scales to the Stylized Dragon's own normal map (ember.glb).

The source albedo, roughness and AO are bound unchanged. Only the normal map
gains a scale relief on the body islands; the wing membranes keep their veins.
Run: python3 tools/bake_ember_normal.py
"""
import numpy as np
from PIL import Image

SRC = "assets/models/sketchfab/"
orm = np.asarray(Image.open(SRC + "ember_1.png").convert("RGB")).astype(np.float32) / 255
nrm = np.asarray(Image.open(SRC + "ember_2.png").convert("RGB")).astype(np.float32) / 255 * 2 - 1
base = np.asarray(Image.open(SRC + "ember_0.png").convert("RGB")).astype(np.float32) / 255
H, W, _ = nrm.shape
island = (orm[..., 0] > 0.02).astype(np.float32)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
u, v = xx / W, yy / H
wing = ((u < 0.47) | ((u < 0.66) & (v < 0.36))).astype(np.float32)
redness = np.clip((base[..., 0] - np.maximum(base[..., 1], base[..., 2])) * 2.5, 0, 1)
body = island * (1 - wing) * redness

# Overlapping hex scales as a height field: domed cells that dip at the rim
# and step down toward the lower edge, like shingles.
cell = 13.0
row = np.floor(yy / (cell * 0.866))
off = (row % 2) * cell * 0.5
cx = np.floor((xx - off) / cell) * cell + off + cell * 0.5
cy = row * cell * 0.866 + cell * 0.433
d = np.sqrt(((xx - cx) / cell) ** 2 + ((yy - cy) / (cell * 0.866)) ** 2)
height = np.clip(1.0 - d * 1.7, 0, 1) ** 0.5 - 0.35 * np.clip((yy - cy) / (cell * 0.45), 0, 1)
height *= body
gy, gx = np.gradient(height)
strength = 2.2
sn = np.stack([-gx * strength, -gy * strength, np.ones_like(gx)], -1)
sn /= np.linalg.norm(sn, axis=-1, keepdims=True)
# Reoriented normal blending (base + detail).
t = nrm + np.array([0, 0, 1.0])
s = sn * np.array([-1, -1, 1.0])
out = t * (t * s).sum(-1, keepdims=True) / t[..., 2:3] - s
out /= np.linalg.norm(out, axis=-1, keepdims=True)
Image.fromarray(((out * 0.5 + 0.5) * 255).clip(0, 255).astype(np.uint8)).save(SRC + "ember_normal_scales.png")
print("wrote", SRC + "ember_normal_scales.png")
