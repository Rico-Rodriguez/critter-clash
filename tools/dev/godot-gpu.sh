#!/bin/bash
# Windowed Godot rendering with the software Vulkan driver under a virtual
# display (Forward+, same look as a desktop GPU, just slow). Used for screenshots.
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json
exec xvfb-run -a -s "-screen 0 1600x1800x24" "$HOME/.local/godot/Godot_v4.7.2-stable_linux.x86_64" --rendering-driver vulkan --path "$ROOT" "$@"
