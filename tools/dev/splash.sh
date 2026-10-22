#!/bin/bash
# Renders the launch splash (the app icon's scene, full length) and writes
# assets/splash.png: the iOS launch screen and Godot's boot splash both use it.
# Usage: tools/dev/splash.sh [hero] [material tier]
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/shots/splash"
mkdir -p "$OUT"
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json
# A taller virtual screen than godot-gpu.sh: the splash is a full phone height.
timeout 900 xvfb-run -a -s "-screen 0 1400x2900x24" "$HOME/.local/godot/Godot_v4.7.2-stable_linux.x86_64" \
	--rendering-driver vulkan --path "$ROOT" --resolution 1290x2796 --fixed-fps 30 -- --capture --shots=splash \
	--hero="${1:-knight}" --mat="${2:-3}" --out="$OUT" 2>&1 | grep -E "SHOT|SCRIPT ERROR"
python3 "$(dirname "$0")/splash_finish.py" "$OUT/splash.png" "$ROOT/assets/fonts/Cinzel-Variable.ttf" "$ROOT/assets/splash.png"
