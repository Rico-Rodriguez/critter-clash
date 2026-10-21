#!/bin/bash
# Headless Godot in this project. Example: tools/dev/godot.sh -- --check
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
exec "$HOME/.local/godot/Godot_v4.7.2-stable_linux.x86_64" --headless --path "$ROOT" "$@"
