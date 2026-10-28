#!/usr/bin/env python3
"""Fails when a committed `.import` file is broken or a test log shows a
resource that would not load. Run from the repo root.

A `.import` that says `valid=false` has no `path`/`dest_files`: the importer
could not read the source (usually a Git LFS pointer committed instead of the
file), and the content pack then ships without that asset. PR #118 shipped 93
of them and took the game's sound away. Godot also prints a plain `ERROR:`
line when a resource fails to load, which a hunt can survive, so the log scan
below turns those into failures.

Usage: check_imports.py [log ...]   (logs from `--test` or `--bot` runs)
"""
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
errors = []

for p in sorted(root.glob("**/*.import")):
    rel = p.relative_to(root)
    if rel.parts[0] in (".godot", ".git"):
        continue
    if re.search(r"^valid=false\s*$", p.read_text(errors="replace"), re.M):
        errors.append(f"{rel}: valid=false (the source was unreadable at import time; re-import it from the real file)")

BAD = re.compile(r"Failed loading resource|Invalid array format for surface|Failed to load|Cannot open file")
for log in sys.argv[1:]:
    seen = {}
    for line in Path(log).read_text(errors="replace").splitlines():
        if line.startswith("ERROR:") and BAD.search(line):
            seen[line] = seen.get(line, 0) + 1
    for line, n in sorted(seen.items()):
        errors.append(f"{Path(log).name}: {line.strip()} (x{n})")

if errors:
    print("IMPORT CHECK FAILED")
    for e in errors[:40]:
        print("  " + e)
    if len(errors) > 40:
        print(f"  ... and {len(errors) - 40} more")
    sys.exit(1)
print("IMPORT CHECK OK")
