#!/usr/bin/env python3
"""Recolours the KayKit palette textures for the Frozen Crypt and the Burning
Swamp. KayKit models sample flat gradient swatches, so a hue/value remap of the
swatches recolours every model that uses them and keeps the baked light-to-dark
ramp, which is why the result stays crisp (no tint wash at runtime).

Run from the repo root:  python3 tools/art/biome_textures.py
"""
import colorsys
import os

import numpy as np
from PIL import Image

KK = "assets/kaykit/"


def load(path):
    return np.asarray(Image.open(KK + path).convert("RGBA"), dtype=np.float32) / 255.0


def save(arr, path):
    out = (np.clip(arr, 0, 1) * 255.0 + 0.5).astype(np.uint8)
    Image.fromarray(out, "RGBA").save(KK + path, optimize=True)
    print("wrote", path)


def rgb_to_hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = np.max(rgb, axis=-1)
    mn = np.min(rgb, axis=-1)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    rc = np.where(m, (mx - r) / np.where(m, d, 1), 0)
    gc = np.where(m, (mx - g) / np.where(m, d, 1), 0)
    bc = np.where(m, (mx - b) / np.where(m, d, 1), 0)
    h = np.where(mx == r, bc - gc, np.where(mx == g, 2.0 + rc - bc, 4.0 + gc - rc))
    h = np.where(m, (h / 6.0) % 1.0, 0.0)
    s = np.where(mx > 1e-6, d / np.where(mx > 1e-6, mx, 1), 0.0)
    return h, s, mx


def hsv_to_rgb(h, s, v):
    i = np.floor(h * 6.0).astype(np.int32)
    f = h * 6.0 - i
    p = v * (1 - s)
    q = v * (1 - f * s)
    t = v * (1 - (1 - f) * s)
    i = i % 6
    r = np.choose(i, [v, q, p, p, t, v])
    g = np.choose(i, [t, v, v, q, p, p])
    b = np.choose(i, [p, p, t, v, v, q])
    return np.stack([r, g, b], axis=-1)


def remap(arr, fn):
    """fn(h, s, v) -> (h, s, v), hue in 0..1. Alpha is kept."""
    h, s, v = rgb_to_hsv(arr[..., :3])
    h2, s2, v2 = fn(h * 360.0, s, v)
    out = arr.copy()
    out[..., :3] = hsv_to_rgb((h2 / 360.0) % 1.0, np.clip(s2, 0, 1), np.clip(v2, 0, 1))
    return out


def warm(h):
    """Bone, skin, wood, pumpkin and gold: the warm swatches (red to yellow)."""
    return (h < 62.0) | (h > 345.0)


def eyes(h, s, v):
    """KayKit's skeleton eye swatch: the bright saturated yellow the character
    shader makes glow. Left alone so the shader still finds it."""
    return (h > 40.0) & (h < 62.0) & (s > 0.75) & (v > 0.85)


# --- Frozen Crypt -------------------------------------------------------------

def rime(h, s, v):
    """Frostbitten bone: warm swatches go glacier blue-white, darks go deep navy."""
    w = warm(h) & ~eyes(h, s, v)
    nh = np.where(w, 205.0 + (v - 0.5) * 18.0, h)
    ns = np.where(w, np.minimum(s * 0.62 + 0.04, 0.42), s)
    nv = np.where(w, np.clip(0.18 + v * 0.92, 0, 1), v)
    grey = (s < 0.14) & ~w
    nh = np.where(grey, 215.0, nh)
    ns = np.where(grey, 0.12 + (1 - v) * 0.2, ns)
    nv = np.where(grey, np.clip(v * 1.04 + 0.03, 0, 1), nv)
    return nh, ns, nv


def regent(h, s, v):
    """The Rime Regent's armour: the same ice, but the metal swatches go a deep
    sapphire so he reads apart from his thralls."""
    nh, ns, nv = rime(h, s, v)
    grey = (s < 0.14)
    nh = np.where(grey & (v > 0.25) & (v < 0.75), 222.0, nh)
    ns = np.where(grey & (v > 0.25) & (v < 0.75), 0.42, ns)
    nv = np.where(grey & (v > 0.25) & (v < 0.75), v * 0.85 + 0.12, nv)
    return nh, ns, nv


def frost_props(h, s, v):
    """Frosted wood, ice and stone: every warm swatch to blue-white, greens to
    deep spruce, the baked light-to-dark ramp kept."""
    w = warm(h)
    spruce = (h >= 62.0) & (h < 180.0) & (s > 0.25)
    nh = np.where(w, 208.0, np.where(spruce, 168.0, h))
    ns = np.where(w, np.minimum(s * 0.55, 0.36), np.where(spruce, s * 0.55, s))
    nv = np.where(w, np.clip(0.1 + v * 0.58, 0, 1), np.where(spruce, v * 0.62, v * 0.9))
    grey = (s < 0.14)
    nh = np.where(grey, 214.0, nh)
    ns = np.where(grey, 0.16 + (1 - v) * 0.2, ns)
    nv = np.where(grey, v * 0.72, nv)
    return nh, ns, nv


# --- Burning Swamp ------------------------------------------------------------

def bog(h, s, v):
    """Bog-drowned bone: peat brown and moss olive, still bone-light on top."""
    w = warm(h) & ~eyes(h, s, v)
    nh = np.where(w, 66.0 + (1 - v) * 12.0, h)
    ns = np.where(w, np.minimum(s * 0.5 + 0.1, 0.42), s)
    nv = np.where(w, np.clip(0.1 + v * 0.52, 0, 1), v)
    grey = (s < 0.14) & ~w
    nh = np.where(grey, 80.0, nh)
    ns = np.where(grey, 0.12, ns)
    nv = np.where(grey, v * 0.9, nv)
    return nh, ns, nv


def cinder(h, s, v):
    """Charred bone: near-black charcoal with a warm cast. The glowing seams are
    added by the character shader (grade.z), not painted here."""
    w = warm(h) & ~eyes(h, s, v)
    nh = np.where(w, 22.0, h)
    ns = np.where(w, np.minimum(s * 0.5 + 0.06, 0.34), s)
    nv = np.where(w, np.clip(0.05 + v * 0.38, 0, 1), v)
    grey = (s < 0.14) & ~w
    nh = np.where(grey, 20.0, nh)
    ns = np.where(grey, 0.18, ns)
    nv = np.where(grey, v * 0.62, nv)
    return nh, ns, nv


def swamp_props(h, s, v):
    """Scorched wood and basalt: charred stone and sooty wood so the firelight
    reads against them, greens to dark murk olive, the baked ramp kept."""
    w = warm(h)
    g = (h >= 62.0) & (h < 180.0) & (s > 0.25)
    nh = np.where(w, 22.0, np.where(g, 78.0, h))
    ns = np.where(w, np.minimum(s * 0.5, 0.34), np.where(g, s * 0.45, s))
    nv = np.where(w, v * 0.42 + 0.04, np.where(g, v * 0.36, v))
    grey = (s < 0.14)
    nh = np.where(grey, 24.0, nh)
    ns = np.where(grey, 0.06, ns)
    nv = np.where(grey, v * 0.42 + 0.03, nv)
    return nh, ns, nv


def main():
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    sk = load("characters/Skeleton_Minion_skeleton_texture.png")
    save(remap(sk, rime), "characters/Skeleton_rime_texture.png")
    save(remap(sk, regent), "characters/Skeleton_regent_texture.png")
    save(remap(sk, bog), "characters/Skeleton_bog_texture.png")
    save(remap(sk, cinder), "characters/Skeleton_cinder_texture.png")
    bb = load("characters/Barbarian_barbarian_texture.png")
    save(remap(bb, cinder), "characters/Barbarian_cinder_texture.png")
    fo = load("forest/forest_texture.png")
    save(remap(fo, frost_props), "forest/forest_frost_texture.png")
    save(remap(fo, swamp_props), "forest/forest_swamp_texture.png")
    hb = load("graveyard/halloweenbits_texture.png")
    save(remap(hb, frost_props), "graveyard/halloweenbits_frost_texture.png")
    save(remap(hb, swamp_props), "graveyard/halloweenbits_swamp_texture.png")


if __name__ == "__main__":
    main()
