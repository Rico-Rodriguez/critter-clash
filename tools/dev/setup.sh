#!/bin/bash
# One-time setup for a fresh Linux/cloud container: Godot 4.7.2, a software
# Vulkan driver (lavapipe) and a virtual display, then a first asset import.
# Usage: tools/dev/setup.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GDIR="$HOME/.local/godot"
GODOT="$GDIR/Godot_v4.7.2-stable_linux.x86_64"
if [ ! -x "$GODOT" ]; then
	mkdir -p "$GDIR"
	curl -fsSL -o /tmp/godot.zip "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip"
	unzip -oq /tmp/godot.zip -d "$GDIR"
	chmod +x "$GODOT"
fi
"$GODOT" --version
if [ ! -f /usr/share/vulkan/icd.d/lvp_icd.json ] || ! command -v xvfb-run >/dev/null; then
	(apt-get install -y -q mesa-vulkan-drivers xvfb >/dev/null 2>&1) || (apt-get update -q >/dev/null 2>&1 && apt-get install -y -q mesa-vulkan-drivers xvfb >/dev/null)
fi
git -C "$ROOT" lfs pull >/dev/null 2>&1 || true
echo "Importing assets (first run takes ~1 min)..."
timeout 900 "$GODOT" --headless --path "$ROOT" --import --quit >/dev/null 2>&1 || true
echo "Ready. Next: tools/dev/check.sh"
