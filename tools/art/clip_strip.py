"""Compose clip_sheet.gd frames into one contact strip per model.
usage: clip_strip.py IN_DIR OUT_DIR sk[,sk...]  -> OUT_DIR/<sk>_clips.png
Rows: one per clip (attack, hit, special, run, move, idle); columns: 0/25/40/60/85%.
Each 1179x2556 frame is cropped round the model and scaled to 360 px wide."""
import sys, os, glob
from PIL import Image, ImageDraw
src, dst, sks = sys.argv[1], sys.argv[2], sys.argv[3].split(',')
os.makedirs(dst, exist_ok=True)
CROP = (0, 628, 1179, 1928)  # centre window: the sheet camera frames the model here
W = 360; Hh = int(W * (CROP[3] - CROP[1]) / (CROP[2] - CROP[0]))
for sk in sks:
    rows = [st for st in ['attack', 'hit', 'special', 'run', 'move', 'idle'] if os.path.exists(f'{src}/{sk}_{st}_0.png')]
    sheet = Image.new('RGB', (110 + 5 * W, len(rows) * Hh + 30), (20, 20, 22))
    d = ImageDraw.Draw(sheet)
    for c, lab in enumerate(['0%', '25%', '40% hit', '60%', '85%']): d.text((110 + c * W + 6, 8), lab, fill=(220, 220, 220))
    for r, st in enumerate(rows):
        d.text((8, 30 + r * Hh + Hh // 2), st, fill=(240, 240, 240))
        for c in range(5):
            im = Image.open(f'{src}/{sk}_{st}_{c}.png').convert('RGB').crop(CROP).resize((W, Hh), Image.LANCZOS)
            sheet.paste(im, (110 + c * W, 30 + r * Hh))
    sheet.save(f'{dst}/{sk}_clips.png'); print(f'{dst}/{sk}_clips.png')
