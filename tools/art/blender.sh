#!/usr/bin/env bash
# Runs one of these builders in headless Blender (the official tarball):
#   tools/art/blender.sh tools/art/make_rogue_arms.py [family ...]
# `blender -b --python file` stops at the first read_factory_settings() the
# builders call per model, so the script is run from an expression instead.
set -euo pipefail
script="$1"; shift
args=""; [ $# -gt 0 ] && args=$(printf "'%s'," "$@")
exec "${BLENDER:-blender}" -b --python-exit-code 1 --python-expr "
import sys, runpy
sys.argv = ['$script', ${args%,}]
runpy.run_path('$script', run_name='__main__')"
