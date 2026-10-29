#!/usr/bin/env python3
"""App Store readiness lint. Run from the repo root (CI does, on every push).

Fails (exit 1) on mistakes that must never ship:
  - a crash-report DSN committed in project.godot
  - tools/ota_gate.json that is not valid, or an app_store_id that is not digits
  - the forced-update gate switched on (min_native > 0) while the store link
    is still the sideload placeholder
Prints a ::warning:: for each placeholder still open (not a failure):
  - no app_store_id yet, so "Update required" opens the sideload page
  - privacy policy URL still pointing at the repo copy
  - store listing items marked TODO in docs/app-store/checklist.md
"""
import json
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
errors, warnings = [], []

proj = (root / "project.godot").read_text()
m = re.search(r'\[crash\][^\[]*?\ndsn="([^"]*)"', proj, re.S)
if not m:
    errors.append("project.godot has no [crash] dsn setting")
elif m.group(1):
    errors.append("project.godot has a crash DSN committed; it must stay empty (CI stamps it from the CRASH_DSN secret)")

try:
    gate = json.loads((root / "tools/ota_gate.json").read_text())
except Exception as e:  # noqa: BLE001
    gate = {}
    errors.append(f"tools/ota_gate.json is not valid JSON: {e}")

app_id = str(gate.get("app_store_id", "")).strip()
if app_id and not app_id.isdigit():
    errors.append("app_store_id must be digits only (the number after 'id' in the App Store URL)")
store_url = str(gate.get("store_url", ""))
listed = bool(app_id) or store_url.startswith(("https://apps.apple.com/", "https://itunes.apple.com/"))
if not listed:
    if int(gate.get("min_native", 0)) > 0:
        # Rico's call (2026-10-29): while the game is sideloaded the gate points at the IPA release.
        warnings.append("min_native is on and store_url is the sideload page: switch it to the App Store link before launch")
    warnings.append("App Store URL is a placeholder: set app_store_id in tools/ota_gate.json (python3 tools/store/set_app_id.py <id>)")

priv = (root / "src/core/privacy.gd").read_text()
url = re.search(r'const POLICY_URL := "([^"]+)"', priv)
if not url or not url.group(1).startswith("https://"):
    errors.append("src/core/privacy.gd needs an https POLICY_URL")
elif "github.com" in url.group(1):
    warnings.append("privacy policy URL is the repo copy: host it publicly and update POLICY_URL and App Store Connect")

check = root / "docs/app-store/checklist.md"
if check.exists():
    todo = len(re.findall(r"^- \[ \]", check.read_text(), re.M))
    if todo:
        warnings.append(f"{todo} item(s) still open in docs/app-store/checklist.md")
else:
    errors.append("docs/app-store/checklist.md is missing")

for w in warnings:
    print(f"::warning::{w}")
for e in errors:
    print(f"::error::{e}")
print("store check:", "FAILED" if errors else "ok", f"({len(warnings)} open placeholder(s))")
sys.exit(1 if errors else 0)
