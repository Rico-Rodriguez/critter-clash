#!/usr/bin/env python3
"""Build the VFX review set from capture frames.

usage: vfx_review.py AFTER_DIR BEFORE_DIR OUT_DIR

AFTER_DIR holds a `--shots=hunt,powers,fire,hexer,vfx` capture from this
branch, BEFORE_DIR the same shots (minus vfx) from main. Writes one mp4 per
element, a contact sheet of every element and a before/after sheet.
"""
import subprocess, sys, os
from PIL import Image, ImageDraw

ELS = "fire frost storm poison nature holy shadow physical blood heal buff level".split()
after, before, out = sys.argv[1:4]
os.makedirs(out, exist_ok=True)
CROP = (0, 230, 540, 830)  # the hero and the effects around them


def label(im, text):
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 8 * len(text) + 16, 22), fill=(0, 0, 0))
    d.text((8, 5), text, fill=(255, 255, 255))
    return im


for el in ELS:
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "15", "-i", f"{after}/vfx_{el}_%02d.png",
                    "-vf", "crop=540:600:0:230", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "27",
                    "-movflags", "+faststart", f"{out}/vfx_{el}.mp4"], check=True)

W, H = 360, 400
sheet = Image.new("RGB", (W * 4, H * 3))
for i, el in enumerate(ELS):
    im = Image.open(f"{after}/vfx_{el}_04.png").convert("RGB").crop(CROP).resize((W, H))
    sheet.paste(label(im, el), ((i % 4) * W, (i // 4) * H))
sheet.save(f"{out}/elements_contact.jpg", quality=85)

shots = [s for s in ["hunt", "powers", "fire", "hexer"] if os.path.exists(f"{before}/{s}.png")]
ba = Image.new("RGB", (W * 2, H * len(shots)))
for r, s in enumerate(shots):
    for c, (d, tag) in enumerate([(before, "before"), (after, "after")]):
        im = Image.open(f"{d}/{s}.png").convert("RGB").crop(CROP).resize((W, H))
        ba.paste(label(im, f"{s} {tag}"), (c * W, r * H))
ba.save(f"{out}/before_after.jpg", quality=85)
print("wrote", out)
