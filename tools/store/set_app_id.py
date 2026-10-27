#!/usr/bin/env python3
"""Point the forced-update screen at the real App Store page.

Usage: python3 tools/store/set_app_id.py 1234567890
Writes app_store_id and store_url into tools/ota_gate.json. Merge to main and the
next publish carries it in version.json. Does not turn the gate on (min_native).
"""
import json
import sys
from pathlib import Path

if len(sys.argv) != 2 or not sys.argv[1].isdigit():
    sys.exit("usage: set_app_id.py <numeric App Store id>")
p = Path(__file__).resolve().parents[2] / "tools/ota_gate.json"
g = json.loads(p.read_text())
g["app_store_id"] = sys.argv[1]
g["store_url"] = f"https://apps.apple.com/app/id{sys.argv[1]}"
p.write_text(json.dumps(g, indent=2) + "\n")
print("store_url ->", g["store_url"])
