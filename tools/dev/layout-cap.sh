#!/bin/bash
# usage: layout-cap.sh <zone> <out_prefix>   top-down and angled stills of a zone's arena (compat renderer)
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIBGL_ALWAYS_SOFTWARE=1 timeout 200 xvfb-run -a -s "-screen 0 1000x1000x24" "$HOME/.local/godot/Godot_v4.7.2-stable_linux.x86_64" --path "$ROOT" --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 900x900 res://tools/dev/layout_preview.tscn -- "$@" 2>&1 | grep -i "SCRIPT ERROR\|SHADER ERROR\|Parse\|ERROR"
