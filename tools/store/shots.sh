#!/bin/bash
# App Store screenshots: portrait 1320x2868 (the 6.9" size Apple requires).
# Usage: tools/store/shots.sh [outdir]   (default docs/app-store/screenshots)
# Software rendering, so it takes a few minutes. Needs xvfb-run, python3 with Pillow, and Godot (GODOT=... or ~/.local/godot).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-$ROOT/docs/app-store/screenshots}"
G="${GODOT:-$HOME/.local/godot/Godot_v4.7.2-stable_linux.x86_64}"
RAW="$(mktemp -d)"
mkdir -p "$OUT"
cd "$ROOT"
xvfb-run -a -s "-screen 0 1600x3000x24" "$G" --rendering-method gl_compatibility --rendering-driver opengl3 --path . \
	--resolution 1320x2868 --fixed-fps 30 -- --capture --shots="${SHOTS:-lobby,heroes,sidekicks,equipskins,shop,hunt}" --cam=0.6 --out="$RAW" 2>&1 | grep -E "SHOT|SCRIPT ERROR" || true
python3 - "$RAW" "$OUT" ${NAMES:-lobby heroes sidekicks equipskins shop hunt} <<'PY'
import os, sys
from PIL import Image
raw, out, names = sys.argv[1], sys.argv[2], sys.argv[3:]
n = 0
for name in names:
    src = os.path.join(raw, name + ".png")
    if not os.path.exists(src):
        continue
    n += 1
    Image.open(src).convert("RGB").resize((1320, 2868)).save(os.path.join(out, "%02d_%s.jpg" % (n, name)), quality=90)
PY
rm -rf "$RAW"
ls -la "$OUT"
