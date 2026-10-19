"""Check that the audio wiring holds together.

Three things have to agree for a sound to be heard:
  scripts/audio_director.gd  the EVENTS mix map (name -> mix)
  scripts/sfx_manifest.gd     the variant count per event
  assets/audio/sfx/           the clips themselves (name_1.ogg, ...)
and every event someone plays has to be one of those names, and every
event that exists has to be played somewhere in scripts/.

usage: python3 tools/check_sfx.py
"""
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, "scripts")
SFX = os.path.join(ROOT, "assets/audio/sfx")

# The legacy aliases in audio_director.gd: old call names that route to an
# event, so they are legal at a call site.
LEGACY = {
    "click": "ui_press", "merge": "card_pick", "error": "ui_error",
    "win": "chest_open", "lose": "sting_defeat", "hit": "hit",
    "shoot": "atk_enemy", "death": "enemy_die", "deploy": "boss_slam",
    "den": "boss_roar",
}


def read(path):
    with open(path) as fh:
        return fh.read()


def parse_events(text):
    """The EVENTS dict: "name": [db, voices, gap, jitter, bus]."""
    body = text.split("const EVENTS := {", 1)[1].split("\n}", 1)[0]
    out = {}
    for m in re.finditer(r'^\t"([a-z0-9_]+)": \[([-0-9., "A-Za-z]+)\],$', body, re.M):
        out[m.group(1)] = [v.strip() for v in m.group(2).split(",")]
    return out


def parse_manifest(text):
    body = text.split("const COUNTS := {", 1)[1].split("\n}", 1)[0]
    return {m.group(1): int(m.group(2))
            for m in re.finditer(r'^\t"([a-z0-9_]+)": (\d+),$', body, re.M)}


def _call_args(text, start):
    """The argument text of a call whose open paren is at `start`."""
    depth = 0
    for i in range(start, len(text)):
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return text[start + 1:i]
    return ""


def called_names():
    """Every event name a call site asks for, and where it was asked."""
    found = {}
    opener = re.compile(r'AudioDirector\.(?:sfx(?:\.bind)?|play)\(')
    # The director also plays its own stings from inside.
    inner = re.compile(r'(?<![\w.])sfx\(')
    for path in sorted(glob.glob(os.path.join(SCRIPTS, "*.gd"))):
        if os.path.basename(path) == "sim_check.gd":
            continue
        text = read(path)
        spots = [(m.start(), m.end() - 1) for m in opener.finditer(text)]
        if os.path.basename(path) == "audio_director.gd":
            spots += [(m.start(), m.end() - 1) for m in inner.finditer(text)]
        for start, paren in spots:
            args = _call_args(text, paren)
            line = text.count("\n", 0, start) + 1
            # A dictionary key or a lookup key is not an event name.
            args = re.sub(r'"[a-z0-9_]+"\s*:', "", args)
            args = re.sub(r'\.\w+\(\s*"[a-z0-9_]+"\s*,', "", args)
            for name in re.findall(r'"([a-z0-9_]+)"', args):
                found.setdefault(name, []).append(
                    "%s:%d" % (os.path.basename(path), line))
    return found


def main():
    events = parse_events(read(os.path.join(SCRIPTS, "audio_director.gd")))
    manifest = parse_manifest(read(os.path.join(SCRIPTS, "sfx_manifest.gd")))
    called = called_names()
    problems = []

    for name in sorted(set(events) - set(manifest)):
        problems.append("event '%s' has no manifest entry" % name)
    for name in sorted(set(manifest) - set(events)):
        problems.append("event '%s' is in the manifest but not in EVENTS" % name)

    for name, count in sorted(manifest.items()):
        for k in range(1, count + 1):
            path = os.path.join(SFX, "%s_%d.ogg" % (name, k))
            if not os.path.exists(path):
                problems.append("missing clip %s" % os.path.basename(path))
            if not os.path.exists(path + ".import"):
                problems.append("missing .import for %s" % os.path.basename(path))
        for stray in glob.glob(os.path.join(SFX, "%s_*.ogg" % name)):
            m = re.fullmatch(r"%s_(\d+)\.ogg" % re.escape(name), os.path.basename(stray))
            if m and int(m.group(1)) > count:
                problems.append("orphan clip %s (manifest says %d)" % (
                    os.path.basename(stray), count))

    for name, places in sorted(called.items()):
        target = LEGACY.get(name, name)
        if target not in events:
            problems.append("call site %s plays unknown event '%s'" % (
                places[0], name))

    for name in sorted(events):
        if name not in called:
            problems.append("event '%s' is never played" % name)

    if problems:
        print("sfx check FAILED")
        for p in problems:
            print("  " + p)
        return 1
    print("sfx check ok: %d events, %d clips, %d call sites" % (
        len(events), sum(manifest.values()),
        sum(len(v) for v in called.values())))
    return 0


if __name__ == "__main__":
    sys.exit(main())
