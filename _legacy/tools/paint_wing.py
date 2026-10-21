"""Paint Ember's wing membrane from the Cute Dragon's own painted atlas.

The model's wings are tiny, so Stage3D builds bigger procedural wings. Their
texture is painted here from the model's own wing island (same palette,
same brush and scale texture), then pushed further:
  - a dark root fading to a warm, lighter translucent trailing edge
  - bone struts fanning from the wrist to each scallop tip, with highlights
  - a fine branching vein network between the struts
  - soft scalloped alpha edges (the island's own outline, feathered)
  - a normal map from struts, veins and the paint's own grain
Writes assets/models/sketchfab/ember_wing_paint.png (RGBA) and
ember_wing_normal.png. Run: python3 tools/paint_wing.py
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

SRC = "assets/models/sketchfab/"
atlas = np.asarray(Image.open(SRC + "ember_cute_0.png").convert("RGB")).astype(float)
solid = atlas.max(2) > 24
lab, _ = ndimage.label(solid)
island = lab == lab[490, 580]
ys, xs = np.nonzero(island)
y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
pad = 6
crop = atlas[y0 - pad:y1 + pad, x0 - pad:x1 + pad]
mask = island[y0 - pad:y1 + pad, x0 - pad:x1 + pad]
# Fill the black gaps just outside the island with its own colour so the
# feathered edge doesn't pick up black fringes.
idx = ndimage.distance_transform_edt(~mask, return_distances=False, return_indices=True)
crop = crop[idx[0], idx[1]]
# Mirror so the root (the island's right side) is u = 0, the tip u = 1.
crop = crop[:, ::-1]
mask = mask[:, ::-1]
OUT_W, OUT_H = 1024, int(1024 * crop.shape[0] / crop.shape[1])
img = Image.fromarray(crop.astype("uint8")).resize((OUT_W, OUT_H), Image.LANCZOS)
col = np.asarray(img).astype(float)
m = np.asarray(Image.fromarray((mask * 255).astype("uint8")).resize((OUT_W, OUT_H), Image.LANCZOS)).astype(float) / 255.0
H, W = OUT_H, OUT_W
v, u = np.mgrid[0:H, 0:W]
u = u / W
v = v / H

# Root-to-edge gradient: deep at the root, warm and light at the scallops.
dist_in = ndimage.distance_transform_edt(m > 0.5) / (0.18 * W)
edge = np.clip(1.0 - dist_in, 0, 1)
root = np.clip(1.0 - u * 2.2, 0, 1)
col *= (0.86 - 0.42 * root)[..., None]
warm = np.array([255.0, 170.0, 90.0])
col = col + (warm - col) * (edge * 0.22 * (u > 0.12))[..., None]

# Scallop tips: local maxima of distance from the root along the outline.
outline = (m > 0.5) & ~ndimage.binary_erosion(m > 0.5, iterations=2)
oy, ox = np.nonzero(outline)
wrist = np.array([0.5 * W, 0.08 * H])  # where the struts fan out
ang = np.arctan2(oy - wrist[1], ox - wrist[0])
rad = np.hypot(oy - wrist[1], ox - wrist[0])
tips = []
bins = np.linspace(ang.min(), ang.max(), 40)
for a0, a1 in zip(bins[:-1], bins[1:]):
    sel = (ang >= a0) & (ang < a1)
    if sel.any():
        k = np.argmax(np.where(sel, rad, -1))
        tips.append((ox[k], oy[k], rad[k]))
tips.sort(key=lambda t: np.arctan2(t[1] - wrist[1], t[0] - wrist[0]))
peaks = [tips[i] for i in range(1, len(tips) - 1) if tips[i][2] >= tips[i - 1][2] and tips[i][2] >= tips[i + 1][2]]
peaks = sorted(peaks, key=lambda t: -t[2])[:5]

height = Image.new("L", (W, H), 0)
hd = ImageDraw.Draw(height)
paint = Image.new("RGBA", (W, H), (0, 0, 0, 0))
pd = ImageDraw.Draw(paint)
rng = np.random.default_rng(7)
bone = (214, 168, 120, 255)
bone_dark = (92, 44, 24, 220)


def strut(a, b, w0, w1):
    n = 24
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        p0 = (a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0)
        p1 = (a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1)
        w = w0 + (w1 - w0) * t0
        pd.line([p0, p1], fill=bone_dark, width=int(w + 6))
        pd.line([p0, p1], fill=bone, width=int(w))
        hd.line([p0, p1], fill=255, width=int(w + 2))


# Leading-edge arm: root -> wrist, then wrist -> each scallop tip.
shoulder = (0.02 * W, 0.18 * H)
strut(shoulder, tuple(wrist), 20, 15)
for x, y, _ in peaks:
    strut(tuple(wrist), (x, y), 11, 4)


def vein(p, a, length, width, depth):
    if depth == 0 or length < 8:
        return
    q = (p[0] + np.cos(a) * length, p[1] + np.sin(a) * length)
    pd.line([p, q], fill=(110, 40, 22, 150), width=max(1, int(width)))
    hd.line([p, q], fill=110, width=max(1, int(width)))
    for s in (-1, 1):
        if rng.random() < 0.8:
            vein(q, a + s * rng.uniform(0.3, 0.7), length * rng.uniform(0.55, 0.75), width * 0.7, depth - 1)


for x, y, _ in peaks:
    for k in range(5):
        t = rng.uniform(0.2, 0.8)
        p = (wrist[0] + (x - wrist[0]) * t, wrist[1] + (y - wrist[1]) * t)
        a = np.arctan2(y - wrist[1], x - wrist[0]) + rng.choice([-1, 1]) * rng.uniform(0.6, 1.1)
        vein(p, a, rng.uniform(40, 80), 4, 4)

paint = paint.filter(ImageFilter.GaussianBlur(1.2))
pa = np.asarray(paint).astype(float)
alpha = pa[..., 3:4] / 255.0
col = col * (1 - alpha) + pa[..., :3] * alpha

# Soft scalloped alpha: feather the outline a few texels.
soft = ndimage.gaussian_filter(m, 2.5)
a_out = np.clip((soft - 0.3) / 0.4, 0, 1)
rgba = np.dstack([np.clip(col, 0, 255), a_out * 255]).astype("uint8")
Image.fromarray(rgba).save(SRC + "ember_wing_paint.png")

# Normal map: struts and veins raised, plus the paint's own grain.
hgt = np.asarray(height.filter(ImageFilter.GaussianBlur(3))).astype(float) / 255.0
lum = col.mean(2) / 255.0
hgt = hgt + ndimage.gaussian_filter(lum, 1.0) * 0.35
gy, gx = np.gradient(hgt)
s = 9.0
n = np.dstack([-gx * s, gy * s, np.ones_like(hgt)])
n /= np.linalg.norm(n, axis=2, keepdims=True)
Image.fromarray(((n * 0.5 + 0.5) * 255).astype("uint8")).save(SRC + "ember_wing_normal.png")
print("wing", W, H, "tips", len(peaks), "aspect", round(H / W, 3))
