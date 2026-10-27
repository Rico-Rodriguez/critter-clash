#!/bin/bash
# Frame costs of a hunt: draw calls, triangles, script time per frame.
# Usage: [RES=WxH] tools/dev/perf.sh [hunt|busy|boss] [zone] [low|high|auto] [frames]
# Both runs step the game at a fixed 60 fps, so "wall fps" in the headless run is
# how many frames per second this machine's CPU can compute (a ceiling, not the phone).
# Two runs, one Godot at a time:
#   1. headless: script ms per frame (process + physics), nodes, allocations.
#   2. software Vulkan with the phone's renderer at 1179x2556: draw calls and
#      triangles (the same counts a GPU would get; the software frame rate means
#      nothing, so ignore "wall fps" in that run).
# Prints the PERF lines of each run.
D="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$D/../.." && pwd)"
SCENE="${1:-hunt}"; ZONE="${2:-barrow}"; Q="${3:-auto}"; N="${4:-240}"
ARGS="--capture --shots=perf --scene=$SCENE --zone=$ZONE --quality=$Q --frames=$N --out=${TMPDIR:-/tmp}/perf-shots"
echo "== headless (script cost)"
timeout 1500 "$D/godot.sh" --fixed-fps 60 -- $ARGS 2>&1 | grep -E "^PERF|SCRIPT ERROR"
echo "== mobile renderer, ${RES:-1179x2556} (draw calls, triangles)"
timeout 3000 "$D/godot-gpu.sh" --rendering-method mobile --resolution "${RES:-1179x2556}" --fixed-fps 60 -- $ARGS 2>&1 | grep -E "^PERF draws|^PERF scene|SCRIPT ERROR|SHADER ERROR"
