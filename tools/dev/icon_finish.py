"""Finish the rendered icon: a soft vignette pulls the eye to the lit face,
then save as an opaque 1024x1024 RGB PNG (iOS rejects icons with alpha).
Usage: python3 icon_finish.py in.png out.png"""
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

src, dst = sys.argv[1], sys.argv[2]
img = Image.open(src).convert("RGB").resize((1024, 1024), Image.LANCZOS)
mask = Image.new("L", img.size, 0)
ImageDraw.Draw(mask).ellipse((-180, -140, 1204, 1250), fill=255)
mask = mask.filter(ImageFilter.GaussianBlur(160))
dark = Image.new("RGB", img.size, (4, 8, 14))
out = Image.composite(img, ImageChops.blend(img, dark, 0.6), mask)
out.save(dst, optimize=True)
