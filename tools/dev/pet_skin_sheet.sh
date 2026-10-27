#!/bin/bash
# usage: tools/dev/pet_skin_sheet.sh OUTDIR [species,...] [grid|solo:<mutation>:<pattern>:<0|1>]
# Phone-size (1179x2556) sheets of pet coats and mutations, compat renderer, software GL.
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
G="${GODOT:-$HOME/.local/godot/Godot_v4.7.2-stable_linux.x86_64}"
export LIBGL_ALWAYS_SOFTWARE=1
mkdir -p "$1"
timeout 1500 xvfb-run -a -s "-screen 0 1400x2900x24" "$G" --path "$ROOT" --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1179x2556 --fixed-fps 30 -- --capture --shots=petskins --out="$1" --skinsp="${2:-bonelet}" --skinmode="${3:-grid}" 2>&1 | grep -E "SHOT|SCRIPT ERROR|Parse Error|SHADER ERROR|ERROR: .*hader" -A2
