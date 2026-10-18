#!/usr/bin/env python3
"""Grimdark boss repaints (Gravemaw troll, Nightmaw werewolf).

Writes, next to each boss model in assets/models/sketchfab/boss/:
  troll_veins_*.png  emission masks: a corruption crack network in UV space,
               denser in blotches (upper body, lower body, head UV sets).
  werewolf_veins.png  the same, plus the werewolf's own red wounds/claws.
  werewolf_paint.png / werewolf_wool_paint.png  desaturated ashen hide that
               keeps the red accents.
Derived from the models' own CC-BY textures (same credit as the models).
Run from the repo root: python3 tools/paint_boss.py
"""
import numpy as np
from PIL import Image, ImageFilter

D = "assets/models/sketchfab/boss/"
rng = np.random.default_rng(7)


def value_noise(n, cells, seed):
    r = np.random.default_rng(seed)
    g = r.random((cells + 1, cells + 1))
    img = Image.fromarray((g * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC)
    return np.asarray(img, np.float32) / 255.0


def cracks(n, cells, seed, width):
    """Voronoi F2-F1 edge lines (tileable-ish), 1 on the line, 0 off it."""
    r = np.random.default_rng(seed)
    pts = r.random((cells, 2)) * n
    # wrap copies so edges continue across the UV seam
    offs = [(dx, dy) for dx in (-n, 0, n) for dy in (-n, 0, n)]
    allp = np.concatenate([pts + np.array(o) for o in offs])
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    f1 = np.full((n, n), 1e9, np.float32)
    f2 = np.full((n, n), 1e9, np.float32)
    for p in allp:
        d = np.hypot(xx - p[0], yy - p[1])
        f2 = np.where(d < f1, f1, np.minimum(f2, d))
        f1 = np.minimum(f1, d)
    e = f2 - f1
    return np.clip(1.0 - e / width, 0.0, 1.0)


def vein_mask(n, seed, density=0.5, extra=None):
    big = cracks(n, 46, seed, 2.4)
    fine = cracks(n, 160, seed + 1, 1.3) * 0.65
    blot = value_noise(n, 5, seed + 2) * 0.7 + value_noise(n, 13, seed + 3) * 0.3
    gate = np.clip((blot - (1.0 - density)) * 4.0, 0.0, 1.0)
    m = np.maximum(big, fine) * gate
    if extra is not None:
        m = np.maximum(m, extra)
    img = Image.fromarray((np.clip(m, 0, 1) * 255).astype(np.uint8))
    # soft halo round each crack so it glows rather than aliases
    halo = img.filter(ImageFilter.GaussianBlur(2.2))
    out = np.maximum(np.asarray(img, np.float32), np.asarray(halo, np.float32) * 0.8)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).convert("L")


def save(img, name):
    img.save(D + name, optimize=True)
    print("wrote", D + name, img.size)


# Troll: upper body (troll_0 UV), lower body (troll_3), head (troll_8).
save(vein_mask(512, 11, 0.42), "troll_veins_upper.png")
save(vein_mask(512, 21, 0.32), "troll_veins_lower.png")
save(vein_mask(512, 31, 0.3), "troll_veins_head.png")

# Werewolf: ashen hide that keeps blood-red accents; those accents glow.
body = np.asarray(Image.open(D + "werewolf_0.png").convert("RGB"), np.float32) / 255.0
hsv = np.asarray(Image.open(D + "werewolf_0.png").convert("HSV"), np.float32) / 255.0
h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
red = ((h < 0.04) | (h > 0.93)) & (s > 0.45) & (v > 0.25)
grey = body.mean(axis=2, keepdims=True)
ash = grey * np.array([0.92, 0.9, 0.88]) * 0.8
keep = red[..., None].astype(np.float32)
paint = ash * (1 - keep) + body * np.array([0.85, 0.35, 0.3]) * keep
save(Image.fromarray((np.clip(paint, 0, 1) * 255).astype(np.uint8)), "werewolf_paint.png")
redm = Image.fromarray((red * 255).astype(np.uint8)).resize((512, 512), Image.BILINEAR)
save(vein_mask(512, 41, 0.36, np.asarray(redm, np.float32) / 255.0 * 0.85), "werewolf_veins.png")
wool = np.asarray(Image.open(D + "werewolf_4.png").convert("RGB"), np.float32) / 255.0
wg = wool.mean(axis=2, keepdims=True) * np.array([0.8, 0.8, 0.82]) * 0.75
save(Image.fromarray((np.clip(wg, 0, 1) * 255).astype(np.uint8)), "werewolf_wool_paint.png")
