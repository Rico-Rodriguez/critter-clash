#!/bin/bash
# usage: tools/dev/graft_sheet.sh OUTDIR [species]  (compat renderer, software GL)
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export LIBGL_ALWAYS_SOFTWARE=1 OUT="$1" SP="${2:-}"
exec xvfb-run -a -s "-screen 0 1400x1400x24" "$HOME/.local/godot/Godot_v4.7.2-stable_linux.x86_64" --path "$ROOT" --rendering-method gl_compatibility --rendering-driver opengl3 -s res://tools/dev/graft_sheet.gd 2>&1 | grep -E "SHEET|SCRIPT ERROR|Parse Error" -A2
