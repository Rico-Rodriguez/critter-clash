#!/bin/bash
# Renders the app icon (tools/app_icon.gd) and writes assets/icon.png.
# Usage: tools/dev/icon.sh [hero] [material tier]   e.g. tools/dev/icon.sh knight 3
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
D="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/shots/icon"
mkdir -p "$OUT"
timeout 900 "$D/godot-gpu.sh" --resolution 1024x1024 --fixed-fps 30 -- --capture --shots=appicon \
	--hero="${1:-knight}" --mat="${2:-3}" --out="$OUT" 2>&1 | grep -E "SHOT|SCRIPT ERROR"
python3 "$D/icon_finish.py" "$OUT/appicon.png" "$ROOT/assets/icon.png"
