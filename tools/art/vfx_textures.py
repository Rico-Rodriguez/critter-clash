#!/usr/bin/env python3
"""Authors every texture in assets/vfx/ (original work, CC0, see CREDITS.md).

Art lock: clean, crisp, clear. Every sprite is a hard-edged shape drawn at 4x
and downsampled once, so edges are anti-aliased but never blurry. No soft
gaussian blobs: glow comes from short additive accents in the engine, not from
the textures. Run: python3 tools/art/vfx_textures.py
"""
import math, os, random
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "vfx")
SS = 4  # supersample


def canvas(w, h=None):
    h = h or w
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))


def done(im, name):
    w, h = im.size
    im = im.resize((w // SS, h // SS), Image.LANCZOS)
    im.save(os.path.join(OUT, name + ".png"))
    print("wrote", name, im.size)


def poly(d, pts, fill, s=1.0, ox=0, oy=0):
    d.polygon([(ox + x * s, oy + y * s) for x, y in pts], fill=fill)


def star(cx, cy, n, r_out, r_in, rot=0.0):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = rot + math.pi * i / n
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


# --- Fire ------------------------------------------------------------------


def ember():
    im = canvas(32)
    d = ImageDraw.Draw(im)
    poly(d, [(16, 2), (22, 16), (16, 30), (10, 16)], (255, 150, 40, 255), SS)
    poly(d, [(16, 8), (19, 16), (16, 24), (13, 16)], (255, 240, 190, 255), SS)
    done(im, "ember")


def spark():
    """A thin four-point glint, white core (tinted in game)."""
    im = canvas(64)
    d = ImageDraw.Draw(im)
    poly(d, star(32, 32, 4, 30, 4, -math.pi / 2), (255, 255, 255, 255), SS)
    poly(d, star(32, 32, 4, 14, 3, -math.pi / 4), (255, 255, 255, 200), SS)
    done(im, "spark")


def scorch_decal():
    """Burnt ground: ragged char blot with branching cracks (hard edges)."""
    S = 256
    im = canvas(S)
    d = ImageDraw.Draw(im)
    rnd = random.Random(3)
    pts = []
    for i in range(48):
        a = i / 48 * math.tau
        r = S * (0.34 + 0.1 * math.sin(a * 5 + 1) + rnd.random() * 0.06)
        pts.append((S / 2 + math.cos(a) * r, S / 2 + math.sin(a) * r))
    poly(d, pts, (18, 12, 9, 215), SS)
    pts2 = [(S / 2 + (x - S / 2) * 0.62, S / 2 + (y - S / 2) * 0.62) for x, y in pts]
    poly(d, pts2, (10, 7, 5, 235), SS)
    for k in range(9):
        a = k / 9 * math.tau + rnd.random() * 0.3
        x, y = S / 2, S / 2
        r = 0
        while r < S * 0.4:
            a += rnd.uniform(-0.5, 0.5)
            step = rnd.uniform(8, 16)
            nx, ny = x + math.cos(a) * step, y + math.sin(a) * step
            d.line([(x * SS, y * SS), (nx * SS, ny * SS)], fill=(255, 120, 30, 255), width=int(SS * max(1.2, 3.2 - r / 40)))
            x, y, r = nx, ny, r + step
    done(im, "scorch")


# --- Ice ---------------------------------------------------------------------


def snowflake():
    im = canvas(64)
    d = ImageDraw.Draw(im)
    for k in range(6):
        a = k / 6 * math.tau
        ex, ey = 32 + math.cos(a) * 29, 32 + math.sin(a) * 29
        d.line([(32 * SS, 32 * SS), (ex * SS, ey * SS)], fill=(235, 248, 255, 255), width=4 * SS // 2)
        for b in (0.5, 0.75):
            bx, by = 32 + math.cos(a) * 29 * b, 32 + math.sin(a) * 29 * b
            for s in (-1, 1):
                aa = a + s * 0.7
                d.line([(bx * SS, by * SS), ((bx + math.cos(aa) * 8) * SS, (by + math.sin(aa) * 8) * SS)], fill=(200, 235, 255, 255), width=3 * SS // 2)
    done(im, "snowflake")


def frost_decal():
    """Frost rime patch: crystalline spikes radiating, pale blue, hard edged."""
    S = 256
    im = canvas(S)
    d = ImageDraw.Draw(im)
    rnd = random.Random(5)
    pts = []
    for i in range(40):
        a = i / 40 * math.tau
        r = S * (0.3 + (0.14 if i % 2 == 0 else 0.04) + rnd.random() * 0.04)
        pts.append((S / 2 + math.cos(a) * r, S / 2 + math.sin(a) * r))
    poly(d, pts, (170, 215, 240, 150), SS)
    for k in range(26):
        a = rnd.random() * math.tau
        r0, r1 = S * rnd.uniform(0.05, 0.2), S * rnd.uniform(0.3, 0.48)
        w = rnd.uniform(3, 6)
        c, s = math.cos(a), math.sin(a)
        p = [(S / 2 + c * r0 - s * w, S / 2 + s * r0 + c * w), (S / 2 + c * r1, S / 2 + s * r1), (S / 2 + c * r0 + s * w, S / 2 + s * r0 - c * w)]
        poly(d, p, (230, 248, 255, 230), SS)
    done(im, "frost")


# --- Lightning ---------------------------------------------------------------


# --- Poison / nature ---------------------------------------------------------

def bubble():
    im = canvas(64)
    d = ImageDraw.Draw(im)
    d.ellipse([4 * SS, 4 * SS, 60 * SS, 60 * SS], fill=(110, 200, 60, 200))
    d.ellipse([9 * SS, 9 * SS, 55 * SS, 55 * SS], fill=(160, 235, 90, 150))
    d.ellipse([16 * SS, 13 * SS, 28 * SS, 25 * SS], fill=(240, 255, 220, 255))
    done(im, "bubble")


def spore():
    im = canvas(32)
    d = ImageDraw.Draw(im)
    poly(d, star(16, 16, 6, 14, 8), (190, 230, 90, 255), SS)
    d.ellipse([11 * SS, 11 * SS, 21 * SS, 21 * SS], fill=(250, 255, 200, 255))
    done(im, "spore")


def leaves():
    F = 64
    im = canvas(F * 2)
    d = ImageDraw.Draw(im)
    cols = [(70, 150, 50), (110, 175, 55), (150, 160, 50), (60, 130, 70)]
    for i in range(4):
        ox, oy = (i % 2) * F * SS, (i // 2) * F * SS
        c = cols[i]
        pts = []
        for k in range(21):
            u = k / 20
            pts.append((F / 2 + math.sin(u * math.pi) * F * 0.24, F * 0.08 + u * F * 0.84))
        for k in range(20, -1, -1):
            u = k / 20
            pts.append((F / 2 - math.sin(u * math.pi) * F * 0.24, F * 0.08 + u * F * 0.84))
        poly(d, pts, c + (255,), SS, ox, oy)
        d.line([(ox + F / 2 * SS, oy + F * 0.1 * SS), (ox + F / 2 * SS, oy + F * 0.92 * SS)], fill=lerp(c, (240, 255, 200), 0.5) + (255,), width=2 * SS)
    done(im, "leaves")


def poison_decal():
    S = 256
    im = canvas(S)
    d = ImageDraw.Draw(im)
    rnd = random.Random(9)
    for k in range(7):
        a = rnd.random() * math.tau
        r = rnd.uniform(0, S * 0.22)
        cx, cy = S / 2 + math.cos(a) * r, S / 2 + math.sin(a) * r
        rr = rnd.uniform(S * 0.12, S * 0.22)
        d.ellipse([(cx - rr) * SS, (cy - rr * 0.8) * SS, (cx + rr) * SS, (cy + rr * 0.8) * SS], fill=(70, 140, 30, 190))
    for k in range(10):
        cx, cy = S / 2 + rnd.uniform(-60, 60), S / 2 + rnd.uniform(-50, 50)
        rr = rnd.uniform(4, 10)
        d.ellipse([(cx - rr) * SS, (cy - rr) * SS, (cx + rr) * SS, (cy + rr) * SS], fill=(190, 245, 110, 230))
    done(im, "poison")


# --- Holy --------------------------------------------------------------------

def ray():
    """A tall tapered light ray, hard sides (used vertical, additive)."""
    W, H = 32, 256
    im = canvas(W, H)
    d = ImageDraw.Draw(im)
    poly(d, [(16, 0), (25, H * 0.9), (16, H), (7, H * 0.9)], (255, 225, 140, 200), SS)
    poly(d, [(16, 10), (19, H * 0.88), (16, H - 6), (13, H * 0.88)], (255, 255, 235, 255), SS)
    done(im, "ray")


def holy_decal():
    """A crisp sun-glyph: rays and a hard broken band, not a glowing disc."""
    S = 256
    im = canvas(S)
    d = ImageDraw.Draw(im)
    c = S / 2
    for k in range(16):
        a = k / 16 * math.tau
        r0, r1 = S * 0.18, S * (0.47 if k % 2 == 0 else 0.36)
        w = 0.07 if k % 2 == 0 else 0.05
        p = [(c + math.cos(a - w) * r0, c + math.sin(a - w) * r0), (c + math.cos(a) * r1, c + math.sin(a) * r1), (c + math.cos(a + w) * r0, c + math.sin(a + w) * r0)]
        poly(d, p, (255, 220, 120, 235), SS)
    for k in range(8):
        a0 = k / 8 * 360 + 6
        d.arc([(c - S * 0.16) * SS, (c - S * 0.16) * SS, (c + S * 0.16) * SS, (c + S * 0.16) * SS], a0, a0 + 32, fill=(255, 245, 210, 255), width=5 * SS)
    done(im, "holy")


# --- Shadow / necrotic -------------------------------------------------------

def wisp():
    """A curling shadow tendril, two-tone violet/black. Mix-blended."""
    im = canvas(64)
    d = ImageDraw.Draw(im)
    pts_l, pts_r = [], []
    for k in range(25):
        u = k / 24
        x = 32 + math.sin(u * 5.5) * 10 * u
        w = 13 * (1 - u) ** 0.8
        y = 60 - u * 56
        pts_l.append((x - w, y))
        pts_r.append((x + w, y))
    poly(d, pts_l + pts_r[::-1], (60, 30, 90, 230), SS)
    pts_l2 = [(x + (32 - x) * 0.0 + 4, y) for x, y in pts_l[:18]]
    pts_r2 = [(x - 4, y) for x, y in pts_r[:18]]
    poly(d, pts_l2 + pts_r2[::-1], (150, 90, 210, 255), SS)
    done(im, "wisp")


def shadow_decal():
    S = 256
    im = canvas(S)
    d = ImageDraw.Draw(im)
    rnd = random.Random(13)
    c = S / 2
    for k in range(11):
        a = k / 11 * math.tau + rnd.random() * 0.2
        pts_l, pts_r = [], []
        for j in range(16):
            u = j / 15
            r = S * (0.08 + 0.38 * u)
            aa = a + math.sin(u * 4) * 0.25
            w = 7 * (1 - u) + 0.5
            px, py = c + math.cos(aa) * r, c + math.sin(aa) * r
            nx, ny = -math.sin(aa), math.cos(aa)
            pts_l.append((px + nx * w, py + ny * w))
            pts_r.append((px - nx * w, py - ny * w))
        poly(d, pts_l + pts_r[::-1], (40, 18, 60, 225), SS)
    d.ellipse([(c - 30) * SS, (c - 30) * SS, (c + 30) * SS, (c + 30) * SS], fill=(28, 12, 40, 235))
    for k in range(6):
        a = k / 6 * math.tau
        d.line([((c + math.cos(a) * 10) * SS, (c + math.sin(a) * 10) * SS), ((c + math.cos(a) * 26) * SS, (c + math.sin(a) * 26) * SS)], fill=(170, 110, 230, 255), width=3 * SS)
    done(im, "shadow")


# --- Physical ----------------------------------------------------------------

def debris():
    F = 64
    im = canvas(F * 2)
    d = ImageDraw.Draw(im)
    rnd = random.Random(19)
    for i in range(4):
        ox, oy = (i % 2) * F * SS, (i // 2) * F * SS
        n = rnd.randint(5, 7)
        pts = [(F / 2 + math.cos(k / n * math.tau) * F * rnd.uniform(0.25, 0.42), F / 2 + math.sin(k / n * math.tau) * F * rnd.uniform(0.25, 0.42)) for k in range(n)]
        poly(d, pts, (92, 78, 62, 255), SS, ox, oy)
        poly(d, pts[: n // 2 + 1] + [(F / 2, F / 2)], (140, 122, 98, 255), SS, ox, oy)
    done(im, "debris")


def dust():
    """Crisp dust puff: three overlapping flat lobes (alpha mix, no blur)."""
    im = canvas(64)
    d = ImageDraw.Draw(im)
    for cx, cy, r in [(24, 36, 16), (40, 34, 15), (32, 24, 14)]:
        d.ellipse([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], fill=(200, 185, 160, 210))
    for cx, cy, r in [(30, 22, 7), (42, 30, 6)]:
        d.ellipse([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], fill=(235, 225, 205, 230))
    done(im, "dust")


def crack_decal():
    S = 256
    im = canvas(S)
    d = ImageDraw.Draw(im)
    rnd = random.Random(23)
    c = S / 2
    for k in range(10):
        a = k / 10 * math.tau + rnd.random() * 0.3
        x, y, r = c, c, 0
        while r < S * 0.46:
            a += rnd.uniform(-0.45, 0.45)
            st = rnd.uniform(8, 18)
            nx, ny = x + math.cos(a) * st, y + math.sin(a) * st
            d.line([(x * SS, y * SS), (nx * SS, ny * SS)], fill=(25, 18, 12, 230), width=int(SS * max(1.5, 6 - r / 22)))
            if rnd.random() < 0.25:
                b = a + rnd.choice([-1, 1]) * 0.9
                d.line([(nx * SS, ny * SS), ((nx + math.cos(b) * 14) * SS, (ny + math.sin(b) * 14) * SS)], fill=(25, 18, 12, 220), width=2 * SS)
            x, y, r = nx, ny, r + st
    done(im, "crack")


def blood():
    F = 64
    im = canvas(F * 2)
    d = ImageDraw.Draw(im)
    for i in range(4):
        ox, oy = (i % 2) * F * SS, (i // 2) * F * SS
        poly(d, [(32, 6 + i * 3), (44, 36), (32, 58), (20, 36)], (150, 14, 20, 255), SS, ox, oy)
        d.ellipse([ox + 20 * SS, oy + 30 * SS, ox + 44 * SS, oy + 58 * SS], fill=(150, 14, 20, 255))
        d.ellipse([ox + 25 * SS, oy + 34 * SS, ox + 31 * SS, oy + 40 * SS], fill=(240, 120, 120, 255))
    done(im, "blood")


# --- Heal / buff / level ---------------------------------------------------

def cross():
    im = canvas(64)
    d = ImageDraw.Draw(im)
    d.rectangle([22 * SS, 6 * SS, 42 * SS, 58 * SS], fill=(60, 150, 60, 255))
    d.rectangle([6 * SS, 22 * SS, 58 * SS, 42 * SS], fill=(60, 150, 60, 255))
    d.rectangle([26 * SS, 10 * SS, 38 * SS, 54 * SS], fill=(190, 255, 170, 255))
    d.rectangle([10 * SS, 26 * SS, 54 * SS, 38 * SS], fill=(190, 255, 170, 255))
    done(im, "cross")


def chevron():
    im = canvas(64)
    d = ImageDraw.Draw(im)
    poly(d, [(32, 6), (58, 34), (46, 34), (32, 20), (18, 34), (6, 34)], (255, 255, 255, 255), SS)
    poly(d, [(32, 28), (58, 56), (46, 56), (32, 42), (18, 56), (6, 56)], (255, 255, 255, 190), SS)
    done(im, "chevron")


# --- Ground telegraph edge strips (u along the edge, v 0 = outer rim) --------

def strip(name, draw):
    W, H = 512, 64
    im = canvas(W, H)
    d = ImageDraw.Draw(im)
    draw(d, W, H, random.Random(hash(name) & 0xffff))
    done(im, "edge_" + name)


def edge_danger(d, W, H, r):
    d.rectangle([0, 0, W * SS, 5 * SS], fill=(255, 255, 255, 255))
    for x in range(0, W, 32):
        poly(d, [(x, 8), (x + 16, 8), (x + 8, 20)], (255, 255, 255, 200), SS)


def edge_fire(d, W, H, r):
    # Molten crack line with charred lips and flame teeth pointing inward.
    d.rectangle([0, 0, W * SS, 7 * SS], fill=(40, 14, 6, 255))
    d.rectangle([0, 2 * SS, W * SS, 5 * SS], fill=(255, 140, 30, 255))
    x = 0
    while x < W:
        w = r.uniform(10, 22)
        h = r.uniform(14, 34)
        poly(d, [(x, 6), (x + w * 0.5, 6 + h), (x + w, 6)], (230, 90, 20, 255), SS)
        poly(d, [(x + w * 0.25, 6), (x + w * 0.5, 6 + h * 0.55), (x + w * 0.75, 6)], (255, 215, 90, 255), SS)
        x += w
    for k in range(18):
        x0 = r.uniform(0, W)
        d.line([(x0 * SS, 7 * SS), ((x0 + r.uniform(-8, 8)) * SS, r.uniform(20, 48) * SS)], fill=(30, 12, 6, 255), width=2 * SS)


def edge_frost(d, W, H, r):
    d.rectangle([0, 0, W * SS, 5 * SS], fill=(225, 245, 255, 255))
    x = 0
    while x < W:
        w = r.uniform(6, 14)
        h = r.uniform(10, 40)
        poly(d, [(x, 4), (x + w * 0.5, 4 + h), (x + w, 4)], (150, 205, 240, 255), SS)
        poly(d, [(x + w * 0.35, 4), (x + w * 0.5, 4 + h * 0.8), (x + w * 0.6, 4)], (240, 252, 255, 255), SS)
        x += w * r.uniform(0.8, 1.6)


def edge_poison(d, W, H, r):
    d.rectangle([0, 0, W * SS, 6 * SS], fill=(90, 170, 40, 255))
    x = 0
    while x < W:
        w = r.uniform(12, 26)
        h = r.uniform(6, 22)
        d.ellipse([x * SS, 2 * SS, (x + w) * SS, (2 + h) * SS], fill=(110, 190, 50, 255))
        d.ellipse([(x + w * 0.3) * SS, (h * 0.3) * SS, (x + w * 0.5) * SS, (h * 0.3 + 5) * SS], fill=(220, 255, 170, 255))
        x += w * 0.85


def edge_holy(d, W, H, r):
    d.rectangle([0, 0, W * SS, 4 * SS], fill=(255, 240, 190, 255))
    d.rectangle([0, 9 * SS, W * SS, 11 * SS], fill=(255, 210, 110, 255))
    for x in range(0, W, 24):
        poly(d, [(x + 12, 12), (x + 15, 26), (x + 12, 40), (x + 9, 26)], (255, 230, 150, 255), SS)


def edge_shadow(d, W, H, r):
    d.rectangle([0, 0, W * SS, 6 * SS], fill=(150, 90, 220, 255))
    x = 0
    while x < W:
        w = r.uniform(14, 28)
        h = r.uniform(16, 44)
        pts = [(x, 5)]
        for k in range(7):
            u = k / 6
            pts.append((x + w * 0.5 + math.sin(u * 5) * 4 * u, 5 + h * u))
        pts.append((x + w, 5))
        poly(d, pts, (60, 28, 95, 255), SS)
        x += w


def edge_stone(d, W, H, r):
    d.rectangle([0, 0, W * SS, 5 * SS], fill=(235, 220, 190, 255))
    x = 0
    while x < W:
        w = r.uniform(18, 40)
        poly(d, [(x, 6), (x + w * 0.2, 6 + r.uniform(8, 16)), (x + w * 0.7, 6 + r.uniform(4, 12)), (x + w, 6)], (110, 92, 70, 255), SS)
        d.line([((x + w) * SS, 6 * SS), ((x + w + r.uniform(-6, 6)) * SS, r.uniform(18, 34) * SS)], fill=(60, 48, 36, 255), width=2 * SS)
        x += w


def edge_light(d, W, H, r):  # storm / lightning
    d.rectangle([0, 0, W * SS, 4 * SS], fill=(235, 245, 255, 255))
    x = 0
    while x < W:
        w = r.uniform(16, 30)
        pts = [(x, 4), (x + w * 0.4, 4 + r.uniform(10, 22)), (x + w * 0.55, 4 + r.uniform(4, 10)), (x + w * 0.8, 4 + r.uniform(16, 30))]
        d.line([(p[0] * SS, p[1] * SS) for p in pts], fill=(150, 200, 255, 255), width=3 * SS)
        x += w


def noise():
    """Tileable fractal value noise (data, not art): drives the dissolve cores.
    Saved straight, no supersample, so it tiles exactly."""
    import numpy as np
    rng = np.random.default_rng(7)
    N = 128
    acc = np.zeros((N, N))
    amp, tot = 1.0, 0.0
    for f in (4, 8, 16, 32):
        g = rng.random((f, f))
        x = np.arange(N) * f / N
        i0 = np.floor(x).astype(int) % f
        i1 = (i0 + 1) % f
        t = x - np.floor(x)
        t = t * t * (3 - 2 * t)
        rows = g[i0][:, :] * (1 - t)[:, None] + g[i1] * t[:, None]
        acc += amp * (rows[:, i0] * (1 - t)[None, :] + rows[:, i1] * t[None, :])
        tot += amp
        amp *= 0.5
    acc /= tot
    acc = (acc - acc.min()) / (acc.max() - acc.min())
    Image.fromarray((acc * 255).astype("uint8"), "L").save(os.path.join(OUT, "noise.png"))
    print("wrote noise", (N, N))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for f in [ember, spark, scorch_decal, snowflake, frost_decal, bubble, spore, leaves, poison_decal, ray, holy_decal, wisp, shadow_decal, debris, dust, crack_decal, blood, cross, chevron, noise]:
        f()
    for n, fn in [("danger", edge_danger), ("fire", edge_fire), ("frost", edge_frost), ("poison", edge_poison), ("holy", edge_holy), ("shadow", edge_shadow), ("stone", edge_stone), ("storm", edge_light)]:
        strip(n, fn)
