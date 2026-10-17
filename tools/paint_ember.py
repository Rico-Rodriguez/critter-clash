"""Bake a painted albedo for the Stylized Dragon (ember.glb).

The source base color is a near-flat red. Its form lives in the AO (ORM red
channel) and normal map. This bakes AO, normal-map cavities, a hex scale
pattern on the body islands, and a warm/cool ramp into one albedo, so the
dragon reads on mobile without extra shader cost.
Run: python3 tools/paint_ember.py
"""
import numpy as np
from PIL import Image, ImageFilter

SRC = "assets/models/sketchfab/"
base = np.asarray(Image.open(SRC + "ember_0.png").convert("RGB")).astype(np.float32) / 255
orm = np.asarray(Image.open(SRC + "ember_1.png").convert("RGB")).astype(np.float32) / 255
nrm_img = Image.open(SRC + "ember_2.png").convert("RGB")
nrm = np.asarray(nrm_img).astype(np.float32) / 255 * 2 - 1
H, W, _ = base.shape
ao = orm[..., 0]
island = (ao > 0.02).astype(np.float32)
ao = np.clip(ao, 0, 1)

# Cavity: high-pass of the normal map's tilt, so creases and vein ridges darken.
tilt = 1.0 - np.clip(nrm[..., 2], 0, 1)
blur = np.asarray(Image.fromarray((tilt * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))).astype(np.float32) / 255
cavity = np.clip((tilt - blur) * 4.0, -1, 1)

# Body islands get scales; the wing membranes (left half and top-middle
# fans) keep the veins from the normal map.
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
u, v = xx / W, yy / H
wing = ((u < 0.47) | ((u < 0.66) & (v < 0.36))).astype(np.float32)
body = island * (1 - wing)

# Hex scales: distance to the nearest cell center on a staggered grid.
cell = 15.0
row = np.floor(yy / (cell * 0.866))
off = (row % 2) * cell * 0.5
cx = np.floor((xx - off) / cell) * cell + off + cell * 0.5
cy = row * cell * 0.866 + cell * 0.433
d = np.sqrt(((xx - cx) / cell) ** 2 + ((yy - cy) / (cell * 0.866)) ** 2)
# Overlapping scale look: bright at the upper part of each scale, dark rim.
scale_shade = np.clip(1.0 - d * 1.6, 0, 1) ** 0.6
lip = np.clip((yy - cy) / (cell * 0.5), -1, 1)
jit = np.sin(cx * 12.9898 + cy * 78.233) * 43758.5453
jit = (jit - np.floor(jit)) * 0.12
scales = 0.8 + 0.22 * scale_shade - 0.12 * np.clip(lip, 0, 1) + jit - 0.06

lum = base.mean(-1, keepdims=True)
deep = np.array([0.30, 0.03, 0.04])
mid = np.array([0.66, 0.09, 0.06])
hot = np.array([0.95, 0.30, 0.10])
t = np.clip((ao - 0.35) / 0.65, 0, 1)[..., None] ** 1.6
col = np.where(t < 0.8, deep + (mid - deep) * (t / 0.8), mid + (hot - mid) * ((t - 0.8) / 0.2) * 0.6)
# Keep the eyes, horns, claws and teeth from the source (non-red pixels).
redness = np.clip((base[..., 0] - np.maximum(base[..., 1], base[..., 2])) * 2.5, 0, 1)[..., None]
s = (scales * body + (1 - body))[..., None]
c = cavity[..., None]
wingtone = (wing * island)[..., None]
painted = col * s
painted = painted * (1 - 0.35 * np.clip(c, 0, 1)) + hot * 0.18 * np.clip(-c, 0, 1)
# Membranes: thinner, a touch more orange so they read against the body.
edge = np.clip((ao - 0.85) / 0.15, 0, 1)[..., None]
painted = painted + wingtone * (hot - painted) * 0.25 * edge
out = base * (1 - redness) + painted * redness
out = np.clip(out, 0, 1)
Image.fromarray((out * 255).astype(np.uint8)).save(SRC + "ember_paint.png")
print("wrote", SRC + "ember_paint.png")
