#!/usr/bin/env python3
# python3 tools/caps_font.py assets/fonts/BarlowCondensed-Bold.ttf assets/fonts/GravelightCaps-Bold.ttf  (needs fonttools)
# Barlow Condensed Bold with every lowercase letter mapped to its capital, so
# mixed-case strings set in caps (OFL derivative, renamed).
import sys
from fontTools.ttLib import TTFont
src, dst = sys.argv[1], sys.argv[2]
f = TTFont(src)
for t in f['cmap'].tables:
    if not t.isUnicode(): continue
    m = t.cmap
    for cp in list(m):
        ch = chr(cp); up = ch.upper()
        if up != ch and len(up) == 1 and ord(up) in m:
            m[cp] = m[ord(up)]
for rec in f['name'].names:
    s = rec.toUnicode()
    if 'Barlow Condensed' in s or 'BarlowCondensed' in s:
        rec.string = s.replace('Barlow Condensed', 'Gravelight Caps').replace('BarlowCondensed', 'GravelightCaps')
if 'DSIG' in f: del f['DSIG']
f.save(dst)
