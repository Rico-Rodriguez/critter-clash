#!/usr/bin/env python3
"""Paint placeholder sprites for Critter Clash.

The game loads PNGs by filename. Drop a replacement on the same path and
the next launch uses it. Sizes are documented in the README.

    python3 tools/build_sprites.py
"""

from __future__ import annotations

import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
CRITTER = ROOT / "assets" / "sprites" / "critters"
ARENA = ROOT / "assets" / "sprites" / "arenas"
FX = ROOT / "assets" / "sprites" / "fx"
UI = ROOT / "assets" / "sprites" / "ui"

# body, belly, dark, accent, cheek, eyes
CAST = {
    "ember": ("dragon", (255, 122, 60), (255, 214, 176), (140, 52, 28), (255, 86, 34), (255, 150, 120)),
    "juniper": ("fox", (224, 122, 61), (255, 232, 214), (120, 58, 28), (255, 170, 90), (255, 150, 130)),
    "pebble": ("otter", (58, 168, 160), (236, 250, 246), (24, 90, 88), (120, 214, 204), (255, 170, 160)),
    "lumen": ("owl", (244, 220, 176), (255, 248, 236), (92, 64, 42), (186, 140, 84), (255, 180, 160)),
    "pip": ("frog", (125, 186, 98), (214, 240, 170), (48, 96, 40), (90, 160, 70), (255, 160, 170)),
    "bramble": ("hog", (150, 104, 72), (236, 214, 186), (78, 48, 34), (92, 140, 64), (255, 160, 140)),
    "thistle": ("boar", (206, 112, 142), (255, 226, 214), (110, 48, 64), (244, 186, 92), (255, 150, 160)),
    "caplet": ("toad", (214, 96, 196), (255, 220, 236), (96, 36, 84), (232, 72, 64), (255, 160, 180)),
    "nimbus": ("hare", (226, 238, 248), (255, 255, 255), (120, 150, 176), (150, 196, 230), (255, 180, 180)),
    "cinder": ("newt", (255, 92, 48), (255, 196, 120), (120, 36, 22), (255, 210, 60), (255, 140, 100)),
    "sprout": ("sprout", (104, 186, 90), (210, 236, 150), (40, 100, 42), (70, 160, 60), (255, 170, 160)),
    "beetle": ("beetle", (214, 164, 58), (255, 228, 160), (110, 72, 24), (90, 150, 70), (255, 170, 140)),
    "moth": ("moth", (244, 228, 186), (255, 248, 230), (120, 90, 60), (186, 150, 210), (255, 180, 170)),
    "boarlet": ("boar", (206, 126, 92), (255, 220, 200), (110, 60, 40), (240, 180, 120), (255, 160, 140)),
    "capling": ("sprout", (216, 96, 140), (255, 210, 220), (110, 40, 70), (180, 60, 70), (255, 170, 170)),
    "spore": ("puff", (206, 186, 240), (240, 232, 255), (90, 70, 130), (160, 130, 210), (255, 180, 190)),
    "glowmoth": ("moth", (150, 236, 206), (230, 255, 244), (40, 110, 90), (120, 210, 255), (255, 180, 180)),
    "puddle": ("toad", (112, 150, 84), (214, 230, 170), (48, 78, 36), (170, 120, 70), (255, 160, 150)),
    "snowpup": ("fox", (236, 244, 252), (255, 255, 255), (140, 164, 186), (180, 210, 230), (255, 180, 180)),
    "shard": ("beetle", (164, 214, 238), (230, 248, 255), (50, 100, 130), (120, 180, 220), (200, 220, 240)),
    "icewisp": ("moth", (214, 244, 255), (245, 252, 255), (90, 140, 170), (160, 210, 255), (220, 230, 255)),
    "yeti": ("hog", (246, 248, 252), (255, 255, 255), (150, 164, 180), (190, 210, 230), (255, 180, 180)),
    "cindling": ("sprout", (255, 140, 60), (255, 214, 150), (140, 50, 24), (255, 90, 40), (255, 160, 120)),
    "skink": ("newt", (226, 96, 48), (255, 190, 130), (120, 40, 24), (255, 170, 50), (255, 140, 110)),
    "ashbat": ("moth", (110, 86, 78), (180, 150, 140), (48, 36, 32), (255, 120, 60), (200, 140, 120)),
    "magmash": ("beetle", (255, 96, 48), (255, 180, 90), (90, 30, 20), (255, 210, 70), (255, 140, 100)),
}


def clamp(v: int) -> int:
    return max(0, min(255, int(v)))


def ellipse(d: ImageDraw.ImageDraw, c, r, fill) -> None:
    d.ellipse([c[0] - r[0], c[1] - r[1], c[0] + r[0], c[1] + r[1]], fill=fill)


def eye(d: ImageDraw.ImageDraw, x: float, y: float, s: float, dark) -> None:
    ellipse(d, (x, y), (s, s * 1.05), (255, 252, 246, 255))
    ellipse(d, (x + s * 0.12, y + s * 0.08), (s * 0.48, s * 0.52), dark)
    ellipse(d, (x - s * 0.22, y - s * 0.28), (s * 0.18, s * 0.18), (255, 255, 255, 240))


def paint_creature(kind: str, body, belly, dark, accent, cheek) -> Image.Image:
    n = 1024
    u = 2.0
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    # Coordinates below are in a 512 space, then scaled onto the 1024 canvas.
    cx, cy = 256.0, 292.0

    def e(x, y, rx, ry, fill):
        ellipse(d, (x * u, y * u), (rx * u, ry * u), fill)

    def poly(pts, fill):
        d.polygon([(x * u, y * u) for x, y in pts], fill=fill)

    # Ground contact is drawn by the game. Keep the feet low in the frame.
    if kind == "fox":
        e(cx + 150, cy + 40, 70, 90, dark)
        e(cx + 150, cy + 30, 54, 74, accent)
    elif kind == "dragon":
        e(cx + 160, cy + 70, 46, 28, accent)
        e(cx + 190, cy + 78, 22, 16, (255, 220, 90, 255))
    elif kind == "newt":
        e(cx + 170, cy + 50, 90, 28, dark)
        e(cx + 170, cy + 48, 74, 18, accent)
    elif kind == "otter":
        e(cx + 140, cy + 80, 80, 26, dark)
        e(cx + 140, cy + 78, 64, 16, body)

    if kind in ("dragon", "moth"):
        e(cx - 150, cy - 10, 90, 56, (*dark[:3], 255))
        e(cx + 150, cy - 10, 90, 56, (*dark[:3], 255))
        e(cx - 150, cy - 16, 72, 40, accent)
        e(cx + 150, cy - 16, 72, 40, accent)

    if kind == "hog":
        for i, ang in enumerate(range(-50, 60, 18)):
            poly([
                (256 + ang * 1.3, 150),
                (246 + ang * 1.3, 230),
                (276 + ang * 1.3, 230),
            ], dark if i % 2 == 0 else accent)

    if kind == "fox":
        poly([(150, 250), (230, 90), (300, 250)], dark)
        poly([(210, 250), (250, 130), (290, 250)], body)
        poly([(512 - 150, 250), (512 - 230, 90), (512 - 300, 250)], dark)
        poly([(512 - 210, 250), (512 - 250, 130), (512 - 290, 250)], body)
    elif kind == "hare":
        e(cx - 70, cy - 210, 28, 110, dark)
        e(cx + 70, cy - 210, 28, 110, dark)
        e(cx - 70, cy - 214, 16, 92, belly)
        e(cx + 70, cy - 214, 16, 92, belly)
    elif kind == "dragon":
        poly([(200, 230), (250, 70), (290, 230)], dark)
        poly([(512 - 200, 230), (512 - 250, 70), (512 - 290, 230)], dark)
    elif kind == "owl":
        poly([(190, 240), (230, 120), (280, 230)], dark)
        poly([(512 - 190, 240), (512 - 230, 120), (512 - 280, 230)], dark)
    elif kind == "sprout":
        e(cx, cy - 150, 34, 70, accent)
        e(cx - 36, cy - 130, 28, 18, (90, 170, 70, 255))
        e(cx + 30, cy - 120, 24, 14, (120, 190, 80, 255))
    elif kind == "toad":
        e(cx, cy - 150, 120, 70, accent)
        e(cx - 36, cy - 170, 28, 18, belly)
        e(cx + 40, cy - 160, 22, 14, (255, 230, 180, 255))

    # Body
    e(cx, cy + 8, 168, 150, dark)
    e(cx, cy, 150, 136, body)
    e(cx, cy + 36, 96, 78, belly)

    if kind == "beetle":
        e(cx, cy - 20, 120, 90, dark)
        e(cx - 40, cy - 24, 52, 70, accent)
        e(cx + 40, cy - 24, 52, 70, body)
        e(cx - 70, cy - 150, 8, 36, dark)
        e(cx + 70, cy - 150, 8, 36, dark)
    if kind == "boar":
        e(cx, cy + 20, 70, 48, dark)
        e(cx, cy + 24, 54, 36, belly)
        poly([(200, 300), (150, 340), (230, 330)], belly)
        poly([(512 - 200, 300), (512 - 150, 340), (512 - 230, 330)], belly)
    if kind == "frog":
        e(cx - 90, cy - 70, 18, 14, accent)
        e(cx + 80, cy - 40, 16, 12, accent)
        e(cx + 20, cy + 10, 14, 10, accent)
    if kind == "puff":
        e(cx - 80, cy - 20, 50, 46, belly)
        e(cx + 70, cy + 10, 46, 42, accent)
        e(cx, cy - 80, 40, 36, belly)
    if kind == "newt":
        for dx, dy in ((-40, 20), (30, 50), (10, -20), (60, 10)):
            e(cx + dx, cy + dy, 16, 12, accent)

    # Flower crown / ice / lava brow
    if kind == "boar" and body[0] > 180 and body[2] > 100:
        for dx in (-70, 0, 70):
            e(cx + dx, cy - 120, 22, 22, accent)
            e(cx + dx, cy - 120, 8, 8, (255, 244, 210, 255))
    if kind == "hare":
        e(cx, cy - 80, 16, 10, (180, 220, 255, 230))
    if kind == "newt" and body[0] > 240:
        e(cx, cy - 40, 70, 16, accent)

    # Face. eye() takes canvas pixels.
    eye_y = cy - 18
    eye_dx = 58
    eye_s = 34
    if kind == "frog":
        eye_y = cy - 78
        eye_s = 42
    if kind == "owl":
        eye_s = 44
        eye_dx = 64
    eye(d, (cx - eye_dx) * u, eye_y * u, eye_s * u, dark)
    eye(d, (cx + eye_dx) * u, eye_y * u, eye_s * u, dark)
    e(cx - 78, cy + 34, 22, 12, (*cheek, 150))
    e(cx + 78, cy + 34, 22, 12, (*cheek, 150))
    if kind == "owl":
        poly([(cx, cy + 18), (cx - 22, cy + 52), (cx + 22, cy + 52)], accent)
    elif kind == "frog":
        d.arc([(cx - 50) * u, (cy + 8) * u, (cx + 50) * u, (cy + 62) * u], 15, 165, fill=dark, width=int(8 * u))
    else:
        d.arc([(cx - 34) * u, (cy + 16) * u, (cx + 34) * u, (cy + 58) * u], 20, 160, fill=dark, width=int(7 * u))

    e(cx - 46, cy - 70, 40, 24, (255, 255, 255, 60))
    return _finish(img, 512)


def _finish(img: Image.Image, size: int) -> Image.Image:
    arr = np.array(img)
    rng = np.random.default_rng(size + int(arr[:, :, 0].sum() % 997))
    alpha = arr[:, :, 3]
    mask = (rng.random(alpha.shape) < 0.45) & (alpha > 30)
    noise = rng.integers(-18, 19, size=alpha.shape, dtype=np.int16)
    for c in range(3):
        ch = arr[:, :, c].astype(np.int16)
        ch[mask] = np.clip(ch[mask] + noise[mask], 0, 255)
        arr[:, :, c] = ch.astype(np.uint8)
    painted = Image.fromarray(arr, "RGBA")
    return painted.resize((size, size), Image.Resampling.LANCZOS)


def arena(name: str) -> Image.Image:
    w, h = 720, 1280
    palettes = {
        "meadow": ((186, 214, 112), (112, 168, 78), (246, 232, 170), (255, 255, 255)),
        "mushroom": ((92, 78, 130), (48, 86, 78), (214, 120, 168), (232, 210, 255)),
        "frost": ((186, 214, 232), (120, 164, 196), (255, 255, 255), (210, 230, 245)),
        "volcano": ((92, 48, 40), (48, 28, 32), (255, 120, 48), (255, 196, 90)),
    }
    top, bot, accent, light = palettes[name]
    col = np.zeros((h, w, 3), dtype=np.uint8)
    for y in range(h):
        t = y / (h - 1)
        col[y, :, 0] = int(top[0] * (1 - t) + bot[0] * t)
        col[y, :, 1] = int(top[1] * (1 - t) + bot[1] * t)
        col[y, :, 2] = int(top[2] * (1 - t) + bot[2] * t)
    img = Image.fromarray(col, "RGB")
    blot = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(blot, "RGBA")
    rng = random.Random(name)
    for _ in range(70):
        x = rng.randrange(w)
        y = rng.randrange(h)
        rx = rng.randint(30, 110)
        ry = rng.randint(18, 60)
        shade = tuple(clamp(c + rng.randint(-24, 24)) for c in (top if y < h * 0.45 else bot))
        d.ellipse([x - rx, y - ry, x + rx, y + ry], fill=(*shade, 90))
    # Clearing where the hunt happens.
    d.ellipse([80, 260, w - 80, h - 180], fill=(*light, 70))
    # Edge thicket.
    for i in range(16):
        x = rng.choice([rng.randint(-20, 80), rng.randint(w - 90, w + 20)])
        y = rng.randint(180, h - 80)
        d.ellipse([x - 50, y - 30, x + 70, y + 46], fill=(*bot, 180))
        d.ellipse([x - 20, y - 70, x + 40, y + 10], fill=(*accent, 160))
    for _ in range(48):
        x = rng.randint(40, w - 40)
        y = rng.randint(200, h - 80)
        if 160 < x < w - 160 and 420 < y < h - 280:
            if rng.random() < 0.7:
                continue
        r = rng.randint(4, 9)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(*accent, 210))
        d.ellipse([x - 2, y - r - 8, x + 2, y], fill=(*bot, 180))
    if name == "mushroom":
        for _ in range(8):
            x = rng.randint(40, w - 40)
            y = rng.randint(160, h - 100)
            d.ellipse([x - 28, y - 18, x + 28, y + 16], fill=(220, 90, 110, 230))
            d.rectangle([x - 8, y, x + 8, y + 36], fill=(236, 220, 190, 230))
    if name == "frost":
        for _ in range(18):
            x = rng.randint(20, w - 20)
            y = rng.randint(140, h - 40)
            d.ellipse([x - 26, y - 10, x + 26, y + 12], fill=(255, 255, 255, 160))
    if name == "volcano":
        for _ in range(7):
            x1 = rng.randint(60, w - 60)
            y1 = rng.randint(300, h - 120)
            d.line([(x1, y1), (x1 + rng.randint(-80, 80), y1 + rng.randint(40, 140))], fill=(255, 140, 40, 180), width=6)
    img = Image.alpha_composite(img.convert("RGBA"), blot).convert("RGB")
    return img.filter(ImageFilter.SMOOTH)


def fx_images() -> None:
    FX.mkdir(parents=True, exist_ok=True)
    gem = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(gem, "RGBA")
    d.polygon([(64, 12), (108, 64), (64, 116), (20, 64)], fill=(190, 245, 120, 255))
    d.polygon([(64, 28), (88, 64), (64, 96), (40, 64)], fill=(236, 255, 190, 255))
    gem.save(FX / "gem.png")

    orb = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(orb, "RGBA")
    d.ellipse([8, 8, 120, 120], fill=(255, 150, 60, 90))
    d.ellipse([24, 24, 104, 104], fill=(255, 196, 80, 230))
    d.ellipse([40, 36, 78, 70], fill=(255, 244, 210, 240))
    orb.save(FX / "orb.png")

    arrow = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(arrow, "RGBA")
    d.polygon([(18, 64), (78, 40), (78, 88)], fill=(92, 58, 36, 255))
    d.polygon([(70, 28), (116, 64), (70, 100)], fill=(232, 214, 170, 255))
    d.polygon([(78, 48), (100, 64), (78, 80)], fill=(120, 72, 42, 255))
    arrow.save(FX / "arrow.png")

    heart = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(heart, "RGBA")
    d.ellipse([18, 22, 70, 74], fill=(255, 110, 140, 255))
    d.ellipse([58, 22, 110, 74], fill=(255, 110, 140, 255))
    d.polygon([(22, 58), (64, 112), (106, 58)], fill=(255, 110, 140, 255))
    d.ellipse([36, 32, 54, 48], fill=(255, 210, 220, 220))
    heart.save(FX / "heart.png")

    shadow = Image.new("RGBA", (256, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(shadow, "RGBA")
    d.ellipse([16, 28, 240, 100], fill=(40, 24, 16, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(8))
    shadow.save(FX / "shadow.png")


def vignette() -> None:
    UI.mkdir(parents=True, exist_ok=True)
    w, h = 720, 1280
    y = np.linspace(-1, 1, h)[:, None]
    x = np.linspace(-1, 1, w)[None, :]
    r = np.clip(np.sqrt(x * x * 0.85 + y * y) - 0.55, 0, 1)
    alpha = (r * r * 170).astype(np.uint8)
    arr = np.zeros((h, w, 4), dtype=np.uint8)
    arr[:, :, 3] = alpha
    Image.fromarray(arr, "RGBA").save(UI / "vignette.png")


def main() -> None:
    CRITTER.mkdir(parents=True, exist_ok=True)
    ARENA.mkdir(parents=True, exist_ok=True)
    for cid, spec in CAST.items():
        img = paint_creature(*spec)
        img.save(CRITTER / f"{cid}.png")
        print("critter", cid)
    for name in ("meadow", "mushroom", "frost", "volcano"):
        arena(name).save(ARENA / f"{name}.png")
        print("arena", name)
    fx_images()
    vignette()
    print("fx and vignette")


if __name__ == "__main__":
    main()
