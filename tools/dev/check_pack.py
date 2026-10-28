#!/usr/bin/env python3
"""Fails when the exported content pack lacks imported data for an asset.

A pack lists each imported resource as `.godot/imported/<file>-<md5>.<ext>`
(`.oggvorbisstr` for sound, `.ctex` for textures, `.mp3str`, `.sample`...).
If a source file's `.import` is broken, its name is simply absent from the
pack, and the game ships without that asset: that is how PR #118 silenced the
game. This lists every audio and texture source the repo has an `.import`
for and checks the pack carries an imported copy of each.

Usage: check_pack.py path/to/critter_clash.pck   (run from the repo root)
Prints the pack's size so CI logs show how it grows. Set PACK_BUDGET_MB to
fail when it passes a budget.
"""
import os
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
pck = Path(sys.argv[1])
data = pck.read_bytes()
size_mb = len(data) / 1048576
names = set(re.findall(rb"\.godot/imported/([A-Za-z0-9_.\-]+?)-[0-9a-f]{32}\.", data))
missing = []
checked = 0
for imp in sorted((root / "assets").glob("**/*.import")):
    src = imp.name[: -len(".import")]
    if not src.lower().endswith((".ogg", ".wav", ".mp3", ".png", ".jpg")):
        continue
    rel = imp.relative_to(root)
    checked += 1
    if src.encode() not in names:
        missing.append(str(rel.with_suffix("")))
print(f"pack: {size_mb:.1f} MB, {checked} audio/texture sources checked")
budget = os.environ.get("PACK_BUDGET_MB")
bad = False
if missing:
    bad = True
    print(f"PACK CHECK FAILED: {len(missing)} sources have no imported copy in the pack")
    for m in missing[:30]:
        print("  " + m)
if budget and size_mb > float(budget):
    bad = True
    print(f"PACK CHECK FAILED: {size_mb:.1f} MB is over the {budget} MB budget")
if not bad:
    print("PACK CHECK OK")
sys.exit(1 if bad else 0)
