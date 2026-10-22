#!/usr/bin/env python3
"""Write and validate the AltStore / SideStore source for Gravelight.

CI runs this after every IPA build:
  python3 tools/altstore_source.py --ipa build/ios/CritterClash.ipa \
      --version 1.1.212 --build-version 1.1.212 --sha <git sha> --run 212 \
      --out dist/altstore.json
  python3 tools/altstore_source.py --validate dist/altstore.json

The source is hosted as an asset on the 'ota' release:
  https://github.com/Rico-Rodriguez/critter-clash/releases/download/ota/altstore.json
"""
import argparse
import datetime as dt
import json
import os
import re
import sys

REPO = "Rico-Rodriguez/critter-clash"
SOURCE_URL = f"https://github.com/{REPO}/releases/download/ota/altstore.json"
IPA_URL = f"https://github.com/{REPO}/releases/download/ios-v1/CritterClash.ipa"
ICON_URL = f"https://raw.githubusercontent.com/{REPO}/main/icon.png"
TINT = "C47A12"


def bundle_id(presets="export_presets.cfg"):
    text = open(presets, encoding="utf-8").read()
    m = re.search(r'^application/bundle_identifier="([^"]+)"', text, re.M)
    if not m:
        raise SystemExit("bundle_identifier not found in export_presets.cfg")
    return m.group(1)


def build(args):
    size = os.path.getsize(args.ipa) if args.ipa else int(args.size)
    date = args.date or dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    notes = f"Build {args.run} from {args.sha[:7]}. Content-only changes arrive in game as OTA packs; install this when a new app build is needed."
    desc = ("A grimdark portrait hero-run. Pick one of four knights, carve through a 3D hunt, "
            "earn gear that visibly changes your knight, and break the bosses of each biome.\n\n"
            "Most updates arrive inside the game (over-the-air content packs). "
            "Update here when a new app build is published.")
    version = {
        "version": args.version,
        "buildVersion": args.build_version,
        "date": date,
        "localizedDescription": notes,
        "downloadURL": IPA_URL,
        "size": size,
        "minOSVersion": "15.0",
    }
    app = {
        "name": "Gravelight",
        "bundleIdentifier": bundle_id(),
        "developerName": "Rico Rodriguez",
        "subtitle": "Grimdark knights, one hunt at a time.",
        "localizedDescription": desc,
        "iconURL": ICON_URL,
        "tintColor": TINT,
        "category": "games",
        "screenshots": [],
        "versions": [version],
        "appPermissions": {"entitlements": [], "privacy": {}},
        # Legacy fields for AltStore 1.x.
        "version": args.version,
        "versionDate": date,
        "versionDescription": notes,
        "downloadURL": IPA_URL,
        "size": size,
    }
    return {
        "name": "Gravelight",
        "identifier": "com.rico.critterclash.source",
        "subtitle": "Sideload builds of Gravelight",
        "description": "Unsigned Gravelight builds from CI, for AltStore and SideStore.",
        "iconURL": ICON_URL,
        "website": f"https://github.com/{REPO}",
        "tintColor": TINT,
        "sourceURL": SOURCE_URL,
        "featuredApps": [app["bundleIdentifier"]],
        "apps": [app],
        "news": [],
    }


def _need(obj, key, kind, where):
    if key not in obj:
        raise ValueError(f"{where}: missing '{key}'")
    if not isinstance(obj[key], kind) or (kind is str and not obj[key]):
        raise ValueError(f"{where}: '{key}' should be a non-empty {kind}")


def validate(src):
    """AltStore source schema (v2 fields plus the legacy 1.x app fields)."""
    _need(src, "name", str, "source")
    _need(src, "identifier", str, "source")
    _need(src, "apps", list, "source")
    if not src["apps"]:
        raise ValueError("source: apps is empty")
    for app in src["apps"]:
        w = "app " + str(app.get("name"))
        for key in ["name", "bundleIdentifier", "developerName", "localizedDescription", "iconURL"]:
            _need(app, key, str, w)
        _need(app, "versions", list, w)
        _need(app, "appPermissions", dict, w)
        if not app["versions"]:
            raise ValueError(w + ": versions is empty")
        for v in app["versions"]:
            for key in ["version", "date", "downloadURL"]:
                _need(v, key, str, w + " version")
            _need(v, "size", int, w + " version")
            if v["size"] <= 0:
                raise ValueError(w + ": version size must be positive")
            dt.datetime.fromisoformat(v["date"].replace("Z", "+00:00"))
            if not v["downloadURL"].startswith("https://"):
                raise ValueError(w + ": downloadURL must be https")
        # Legacy AltStore 1.x reads these from the app itself.
        for key in ["version", "versionDate", "downloadURL"]:
            _need(app, key, str, w + " (legacy)")
        _need(app, "size", int, w + " (legacy)")
        if app["version"] != app["versions"][0]["version"]:
            raise ValueError(w + ": legacy version does not match versions[0]")
    return True


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--validate")
    p.add_argument("--ipa")
    p.add_argument("--size", default="0")
    p.add_argument("--version")
    p.add_argument("--build-version")
    p.add_argument("--sha", default="")
    p.add_argument("--run", default="0")
    p.add_argument("--date")
    p.add_argument("--out")
    args = p.parse_args()
    if args.validate:
        with open(args.validate, encoding="utf-8") as f:
            validate(json.load(f))
        print(f"{args.validate}: valid AltStore source")
        return
    src = build(args)
    validate(src)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(src, f, indent=2)
        f.write("\n")
    print(f"wrote {args.out}")


if __name__ == "__main__":
    sys.exit(main())
