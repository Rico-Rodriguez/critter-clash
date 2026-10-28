#!/bin/bash
# foe_pipeline.sh <name> <downloaded.glb> <max_tris> [prep_glb.py args...]
# Sketchfab download -> assets/foes/<name>_src.glb: prune clips and shrink textures (prep_glb.py),
# merge skinned meshes (merge_skinned.py), collapse-decimate to <max_tris> when above it
# (decimate_skinned.py, Blender), then strip what the merge left behind (prep_glb.py again).
# Afterwards run tools/dev/godot-gpu.sh -s res://tools/art/wrap_foes.gd to write <name>.tscn.
set -e
D="$(cd "$(dirname "$0")" && pwd)"; ROOT="$D/../.."; T=$(mktemp -d)
n=$1; src=$2; cap=$3; shift 3
python3 "$D/prep_glb.py" "$src" "$T/a.glb" "$@"
python3 "$D/merge_skinned.py" "$T/a.glb" "$T/b.glb"
python3 "$D/prep_glb.py" "$T/b.glb" "$T/c.glb"
tris=$(python3 - "$T/c.glb" <<'P'
import json,struct,sys
b=open(sys.argv[1],'rb').read(); l=struct.unpack('<I',b[12:16])[0]; j=json.loads(b[20:20+l]); t=0
for m in j['meshes']:
    for p in m['primitives']: t+=j['accessors'][p['indices']]['count']//3 if 'indices' in p else 0
print(t)
P
)
if [ "$tris" -gt "$cap" ]; then blender -b -P "$D/decimate_skinned.py" -- "$T/c.glb" "$T/d.glb" "$cap" >/dev/null || cp "$T/c.glb" "$T/d.glb"; else cp "$T/c.glb" "$T/d.glb"; fi
python3 "$D/prep_glb.py" "$T/d.glb" "$ROOT/assets/foes/${n}_src.glb"
rm -rf "$T"
