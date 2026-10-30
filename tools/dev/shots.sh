#!/bin/bash
# Screenshots of named screens into ./shots (gitignored), at phone size.
# Usage: tools/dev/shots.sh lobby,hunt,boss [720x1280|720x1560]
# Shots: lobby firstcamp heroes skills log bag chest settings expedition hunt levelup boss victory resultslist swipe gear
#        results death defeat film flow icon bounties hexer shop shopbuy shoplooks (see _capture in src/main.gd;
#        zone shots: run godot-gpu.sh directly with --zone=depths)
# Software rendering is slow: ~1-3 minutes per hunt shot. Read the PNGs to look.
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
D="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/shots"
mkdir -p "$OUT"
timeout 3000 "$D/godot-gpu.sh" --resolution "${2:-720x1280}" --fixed-fps 30 -- --capture --shots="${1:-lobby,hunt}" --out="$OUT" 2>&1 | grep -E "SHOT|BUDGET|SCRIPT ERROR|SHADER ERROR"
ls "$OUT"
