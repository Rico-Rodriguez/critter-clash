"""Repaint the Thistle mushroom boss in darker, more mature tones.

The source albedo is pastel mint with lilac spots, which read as plastic
toy under the hunt light. This keeps its layout and detail (luminance,
the fibrous gills, the eyes) and remaps the hues:
  - mint skin -> weathered bone and umber with darker mottling (it has
    to read against green grass)
  - lilac spots -> oxblood warts with a dark bruised rim
  - pink tongue -> deep oxblood
It adds a fine fungal grain, and writes a roughness map: matte, damp skin,
slightly glossier spots (G channel, read by Stage3D._fix_pbr rough_tex).
"""
import numpy as np
from PIL import Image
from scipy import ndimage

SRC = "assets/models/sketchfab/thistle_0.png"
OUT = "assets/models/sketchfab/thistle_paint.png"
ROUGH = "assets/models/sketchfab/thistle_rough.png"

a = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float32) / 255.0
r, g, b = a[..., 0], a[..., 1], a[..., 2]
lum = 0.3 * r + 0.59 * g + 0.11 * b
mx, mn = a.max(-1), a.min(-1)
sat = (mx - mn) / np.maximum(mx, 1e-4)

spot = np.clip(((r + b) * 0.5 - g) * 7.0, 0, 1)            # lilac
tongue = np.clip((r - b) * 5.0 - 0.3, 0, 1) * np.clip((r - g) * 5.0, 0, 1)
dark = lum < 0.12                                            # eyes, pupils
spot = ndimage.gaussian_filter(spot, 0.8)

h, w = lum.shape
rng = np.random.default_rng(7)
def noise(scale, amp):
    n = rng.standard_normal((h // scale + 2, w // scale + 2)).astype(np.float32)
    n = ndimage.zoom(n, scale, order=3)[:h, :w]
    return n * amp
grain = noise(2, 0.05) + noise(8, 0.08) + noise(32, 0.10)

shade = np.clip(lum / 0.62, 0.25, 1.4)[..., None]
skin = np.array([0.30, 0.25, 0.19])
skin_hi = np.array([0.50, 0.43, 0.32])
mott = np.clip(0.5 + grain, 0, 1)[..., None]
col = (skin * (1 - mott) + skin_hi * mott) * shade
plum = np.array([0.30, 0.075, 0.09]) * shade
# A pale ring round each spot, like real cap warts.
edge = np.clip(ndimage.gaussian_filter(spot, 3.0) - spot, 0, 1)[..., None] * 1.6
col = col * (1 - edge) + np.array([0.20, 0.13, 0.10]) * shade * edge
col = col * (1 - spot[..., None]) + plum * spot[..., None]
ox = np.array([0.34, 0.06, 0.07]) * shade
col = col * (1 - tongue[..., None]) + ox * tongue[..., None]
col = np.where(dark[..., None], a, col)
col = np.clip(col * (1 + grain[..., None] * 0.5), 0, 1)
Image.fromarray((col * 255).astype(np.uint8)).save(OUT)

rough = np.clip(0.82 - spot * 0.22 - tongue * 0.3 + grain * 0.3, 0.35, 0.95)
rimg = np.stack([rough, rough, rough], -1)
Image.fromarray((rimg * 255).astype(np.uint8)).save(ROUGH)
print("wrote", OUT, ROUGH)
