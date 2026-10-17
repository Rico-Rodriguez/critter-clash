"""Paint a multi-tone albedo for the Stylized Dragon (ember.glb).

The source base colour is one flat red, so the dragon read as a silhouette.
This rasterises the mesh into its own UV layout to learn, per texel, where
the surface sits on the body and which way it faces, then paints:
  - dark crimson back and spine, red flanks, amber-to-cream belly and throat
  - darker wing membranes with lighter veins and a warm translucent edge
  - gold horns and claws (the source's dark, unsaturated texels)
  - hex scales and the model's own AO and normal-map cavities baked in.
Eyes and teeth keep their source colours. Needs: pip install trimesh scipy
Run: python3 tools/paint_ember.py
"""
import numpy as np
import trimesh
from PIL import Image, ImageFilter
from scipy import ndimage

SRC = "assets/models/sketchfab/"
S = 1024


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    return a + (b - a) * t[..., None]


# --- Rasterise object-space position and normal into UV space -----------
geo = trimesh.load(SRC + "ember.glb", force="scene").geometry["GLTF"]
V, F, UV, N = geo.vertices, geo.faces, geo.visual.uv, geo.vertex_normals
pos = np.zeros((S, S, 3), np.float32)
nrm = np.zeros((S, S, 3), np.float32)
cov = np.zeros((S, S), bool)
P = np.stack([UV[:, 0] * S, (1 - UV[:, 1]) * S], 1)
for f in F:
    a, b, c = P[f]
    x0, x1 = int(max(0, np.floor(min(a[0], b[0], c[0])))), int(min(S - 1, np.ceil(max(a[0], b[0], c[0]))))
    y0, y1 = int(max(0, np.floor(min(a[1], b[1], c[1])))), int(min(S - 1, np.ceil(max(a[1], b[1], c[1]))))
    if x1 < x0 or y1 < y0:
        continue
    xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
    d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
    if abs(d) < 1e-9:
        continue
    w0 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / d
    w1 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / d
    w2 = 1 - w0 - w1
    m = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
    if not m.any():
        continue
    W = np.stack([w0[m], w1[m], w2[m]], 1)
    yy, xx = (ys[m] - 0.5).astype(int), (xs[m] - 0.5).astype(int)
    pos[yy, xx] = W @ V[f]
    nrm[yy, xx] = W @ N[f]
    cov[yy, xx] = True
nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True) + 1e-6

# --- Source maps ----------------------------------------------------------
base = np.asarray(Image.open(SRC + "ember_0.png").convert("RGB")).astype(np.float32) / 255
orm = np.asarray(Image.open(SRC + "ember_1.png").convert("RGB")).astype(np.float32) / 255
tn = np.asarray(Image.open(SRC + "ember_2.png").convert("RGB")).astype(np.float32) / 255 * 2 - 1
ao = np.clip(orm[..., 0], 0, 1)
yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
u, v = xx / S, yy / S
wing = cov & ((u < 0.47) | ((u < 0.66) & (v < 0.36)))
body = cov & ~wing

# Source colour classes: red hide, dark unsaturated horn/claw, the rest
# (eye, teeth, tongue) kept as is.
mx, mn = base.max(-1), base.min(-1)
sat = (mx - mn) / (mx + 1e-4)
red = (base[..., 0] > base[..., 1] * 2.2) & (sat > 0.5)
horn = ~red & (mx < 0.4)
keep = ~red & ~horn

X, Y, Z = pos[..., 0], pos[..., 1], pos[..., 2]
nx, ny, nz = nrm[..., 0], nrm[..., 1], nrm[..., 2]

# Belly: faces down on torso and tail; on the rising neck the throat faces
# forward. Back is the opposite. Spine: the dorsal midline.
# The head (above the neck) uses down-facing again, so only the jaw
# underside goes pale, not the face.
head = smooth(13.5, 15.0, Y) * smooth(-4.0, -1.5, Z)
neck = smooth(6.0, 10.0, Y) * smooth(-7.0, -3.0, Z) * (1 - head)
belly_dir = ny * -1.0 * (1 - neck) + nz * neck
belly = smooth(0.05, 0.6, belly_dir)
back = smooth(0.1, 0.75, -belly_dir)
spine = np.exp(-(X / 0.9) ** 2) * back
throat = belly * neck

deep = np.array([0.26, 0.035, 0.04])
crimson = np.array([0.50, 0.06, 0.06])
flank = np.array([0.72, 0.13, 0.08])
amber = np.array([0.80, 0.40, 0.15])
cream = np.array([0.86, 0.62, 0.36])
col = mix(np.broadcast_to(flank, base.shape).copy(), crimson, back)
col = mix(col, deep, np.clip(spine * 1.2, 0, 1))
col = mix(col, amber, belly)
col = mix(col, cream, np.clip(throat * 0.75 + belly * 0.2, 0, 1))

# Scales: hex cells as a height field; belly plates are broader bands.
def hexes(cell):
    row = np.floor(yy / (cell * 0.866))
    off = (row % 2) * cell * 0.5
    cx = np.floor((xx - off) / cell) * cell + off + cell * 0.5
    cy = row * cell * 0.866 + cell * 0.433
    d = np.sqrt(((xx - cx) / cell) ** 2 + ((yy - cy) / (cell * 0.866)) ** 2)
    dome = np.clip(1.0 - d * 1.7, 0, 1) ** 0.5
    lip = np.clip((yy - cy) / (cell * 0.45), 0, 1)
    jit = np.sin(cx * 12.9898 + cy * 78.233) * 43758.5453
    return dome - 0.35 * lip, jit - np.floor(jit)
sc, jit = hexes(13.0)
scale_tone = 0.78 + 0.3 * sc + (jit - 0.5) * 0.1
plate = 0.86 + 0.14 * np.cos((Y * 1.6) * np.pi) ** 2
tone = mix(scale_tone[..., None] * np.ones(3), plate[..., None] * np.ones(3), belly)[..., 0]
col = col * tone[..., None]

# Wings: dark membrane, lighter veins (normal-map ridges), warm thin edge.
tilt = 1.0 - np.clip(tn[..., 2], 0, 1)
tb = np.asarray(Image.fromarray((tilt * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(5))).astype(np.float32) / 255
vein = np.clip((tilt - tb) * 6.0, 0, 1)
edge_d = ndimage.distance_transform_edt(wing)
edge = np.exp(-edge_d / 14.0)
memb = np.array([0.30, 0.045, 0.05])
vein_c = np.array([0.80, 0.30, 0.14])
rim_c = np.array([0.86, 0.38, 0.16])
wcol = mix(np.broadcast_to(memb, base.shape).copy(), vein_c, np.clip(vein * 1.3, 0, 1))
wcol = mix(wcol, rim_c, edge * 0.7)
wcol = wcol * (0.9 + 0.1 * smooth(-1, 1, ny))[..., None]
col = np.where(wing[..., None], wcol, col)

# Gold horns and claws: a metal ramp keyed off the source value.
lum = base.mean(-1)
gold = mix(np.broadcast_to(np.array([0.36, 0.22, 0.08]), base.shape).copy(), np.array([0.96, 0.78, 0.42]), smooth(0.02, 0.3, lum))
col = np.where(horn[..., None], gold, col)

# AO and cavities from the model's own maps over everything painted.
cav = np.clip((tilt - tb) * 3.0, -1, 1)
col = col * (0.45 + 0.55 * ao)[..., None]
col = col * (1 - 0.3 * np.clip(-cav, 0, 1))[..., None]
col = np.where(keep[..., None], base, col)
col = np.where(cov[..., None], col, base)

# Pad islands outward so mip levels do not bleed the old red at seams.
idx = ndimage.distance_transform_edt(~cov, return_distances=False, return_indices=True)
pad = col[idx[0], idx[1]]
col = np.where(cov[..., None], col, pad)
Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)).save(SRC + "ember_paint.png")
print("wrote", SRC + "ember_paint.png")
