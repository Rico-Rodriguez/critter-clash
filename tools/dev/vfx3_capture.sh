#!/bin/bash
# Review clips for docs/review/vfx3 (compatibility renderer, 720x1560 portrait).
# usage: tools/dev/vfx3_capture.sh tiers <element> | busy <hero> | fire
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
G="$HOME/.local/godot/Godot_v4.7.2-stable_linux.x86_64"
OUT="$ROOT/docs/review/vfx3"
TMP="${TMPDIR:-/tmp}/vfx3"
mkdir -p "$OUT" "$TMP"
cd "$ROOT"
printf '[display]\n\nwindow/size/window_width_override=720\nwindow/size/window_height_override=1560\n' > override.cfg
trap 'rm -f "$ROOT/override.cfg"' EXIT
run() { # name, args...
	local name=$1; shift
	rm -f "$TMP/$name.avi"
	timeout 900 xvfb-run -a -s "-screen 0 800x1700x24" "$G" --path . --rendering-method gl_compatibility --resolution 720x1560 \
		--write-movie "$TMP/$name.avi" --fixed-fps 30 "$@" > "$TMP/$name.log" 2>&1
	grep -E "SCRIPT ERROR|SHADER ERROR" -A3 "$TMP/$name.log" | head -12
	grep -E "^DRAWS|^BUSY" "$TMP/$name.log"
	ffmpeg -y -loglevel error -i "$TMP/$name.avi" -c:v libx264 -pix_fmt yuv420p -crf 23 -vf scale=360:-2 -movflags +faststart "$OUT/$name.mp4"
}
case "$1" in
	tiers) run "el_$2" -s tools/dev/vfx_tiers.gd -- --el="$2" ;;
	fire) run "fire_modes" -s tools/dev/vfx_tiers.gd -- --fire ;;
	busy) run "busy_$2" -- --capture --shots=busy --hero="$2" --clip=1 --cam=0.6 ;;
esac
