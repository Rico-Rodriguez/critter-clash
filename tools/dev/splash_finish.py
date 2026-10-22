"""Finish the rendered splash: vignette, the GRAVELIGHT title in Cinzel with a
warm glow, saved as an opaque 1290x2796 RGB PNG. The launch screen crops it to
cover the phone (shorter phones lose top and bottom), so the title and hero
stay inside the middle 80% of the height.
Usage: python3 splash_finish.py in.png Cinzel.ttf out.png"""
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

src, font_path, dst = sys.argv[1], sys.argv[2], sys.argv[3]
W, H = 1290, 2796
img = Image.open(src).convert("RGB").resize((W, H), Image.LANCZOS)
mask = Image.new("L", img.size, 0)
ImageDraw.Draw(mask).ellipse((-300, int(H * 0.30), W + 300, int(H * 1.05)), fill=255)
mask = mask.filter(ImageFilter.GaussianBlur(260))
dark = Image.new("RGB", img.size, (4, 7, 11))
img = Image.composite(img, ImageChops.blend(img, dark, 0.7), mask)

font = ImageFont.truetype(font_path, 150)
try:
    font.set_variation_by_name("Bold")
except Exception:
    pass
small = ImageFont.truetype(font_path, 44)
title, sub = "GRAVELIGHT", "RISE THROUGH THE BARROW"
ty = int(H * 0.25)


def centered(draw, y, text, f, fill, spacing=0):
    w = draw.textlength(text, font=f) + spacing * (len(text) - 1)
    x = (W - w) / 2
    for ch in text:
        draw.text((x, y), ch, font=f, fill=fill)
        x += draw.textlength(ch, font=f) + spacing


glow = Image.new("RGB", img.size, (0, 0, 0))
centered(ImageDraw.Draw(glow), ty, title, font, (255, 150, 60), 14)
glow = glow.filter(ImageFilter.GaussianBlur(28))
img = ImageChops.add(img, glow)
d = ImageDraw.Draw(img)
centered(d, ty, title, font, (250, 222, 170), 14)
centered(d, ty + 205, sub, small, (150, 170, 185), 10)
img.save(dst, optimize=True)
