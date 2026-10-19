"""Check that the audio wiring holds together.

Three things have to agree for a sound to be heard:
  scripts/audio_director.gd  the EVENTS mix map (name -> mix)
  scripts/sfx_manifest.gd     the variant count per event
  assets/audio/sfx/           the clips themselves (name_1.ogg, ...)
and every event someone plays has to be one of those names, and every
event that exists has to be played somewhere in scripts/.

On top of that: every clip has to be on disk with a usable .import
sidecar and must not be silent, no clip may sit in the folder unreached,
the music loops the director can be asked for have to exist, and every
event the sim raises has to reach the screen with a sound.

The clip paths are read out of the director's own loader, so the check
cannot drift from what the game loads.

usage: python3 tools/check_sfx.py
"""
import glob
import hashlib
import os
import re
import shutil
import subprocess
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

# A clip quieter than this is a mistake: the file is there, but it plays
# nothing a player can hear.
SILENT_DB = -60.0

# The events that are silent by design: a hitstop is a freeze on the
# picture, not a moment that needs a sound; a gather is phase 1 plumbing
# (docs/gathering.md) with no node art and no UI, and it announces itself
# through its xp_drop.
SILENT_EVENTS = {"hitstop", "gather"}

# Every uid in the project and the .import file that owns it, filled in
# by _collect_uids() before the clips are checked.
_uid_owner = {}


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


def clip_path_format(text):
    """The path the director builds for a clip, read out of its own source.

    The checker has to look for the files the game loads, so the format
    comes from the loader instead of being repeated here.
    """
    m = re.search(r'"(res://[^"]*/sfx/[^"]*%s[^"]*%d[^"]*)"', text)
    if not m:
        raise SystemExit("cannot find the clip path format in audio_director.gd")
    return m.group(1)


def music_path_format(text):
    """The path the director builds for a music loop."""
    m = re.search(r'"(res://[^"]*/music/[^"]*)"', text)
    if not m:
        raise SystemExit("cannot find the music path format in audio_director.gd")
    return m.group(1)


def music_tracks():
    """Every music loop the game can ask the director for.

    The names are literal at the call sites, plus the default every
    screen starts on; the loop itself is a variable, so this is the
    best a static check can do.
    """
    names = set()
    for path in sorted(glob.glob(os.path.join(SCRIPTS, "*.gd"))):
        if os.path.basename(path) == "sim_check.gd":
            continue
        text = read(path)
        for m in re.finditer(r'\.music\(\s*"([a-z0-9_]+)"', text):
            names.add(m.group(1))
        m = re.search(r'var music_track := "([a-z0-9_]+)"', text)
        if m:
            names.add(m.group(1))
    return names


def clip_path(fmt, event, index):
    """The res:// path of one clip, and where it lives on disk."""
    res = fmt.replace("%s", event).replace("%d", str(index))
    rel = res[len("res://"):] if res.startswith("res://") else res
    return res, os.path.join(ROOT, rel)


def check_import(path, res_path):
    """The .import sidecar has to match what Godot expects, or it re-imports.

    Godot names the imported file after the md5 of the source path and
    keys the resource by a uid that must be unique in the project.
    """
    side = path + ".import"
    if not os.path.exists(side):
        return ["missing .import for %s" % os.path.basename(path)]
    text = read(side)
    digest = hashlib.md5(res_path.encode()).hexdigest()
    problems = []
    if digest not in text:
        problems.append("%s.import does not name the imported file Godot expects" % (
            os.path.basename(path)))
    if 'importer="oggvorbisstr"' not in text:
        problems.append("%s.import is not an ogg importer" % os.path.basename(path))
    m = re.search(r'uid="uid://([^"]+)"', text)
    if not m:
        problems.append("%s.import has no uid" % os.path.basename(path))
    else:
        owner = _uid_owner.get(m.group(1))
        if owner and os.path.abspath(owner) != os.path.abspath(side):
            problems.append("uid %s is shared by %s and %s" % (
                m.group(1), os.path.basename(owner),
                os.path.basename(side)))
    return problems


def _collect_uids():
    """Every uid in the project, and the .import file that owns it."""
    owners = {}
    for path in glob.glob(os.path.join(ROOT, "assets/**/*.import"), recursive=True):
        m = re.search(r'uid="uid://([^"]+)"', read(path))
        if m:
            owners.setdefault(m.group(1), path)
    return owners


def mean_volume(path):
    """The mean level of a clip in dB, or None if ffmpeg is not there."""
    if not shutil.which("ffmpeg"):
        return None
    out = subprocess.run(
        ["ffmpeg", "-hide_banner", "-i", path, "-af", "volumedetect", "-f", "null", "-"],
        capture_output=True, text=True).stderr
    m = re.search(r"mean_volume:\s*(-?[\d.]+) dB", out)
    return float(m.group(1)) if m else None


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


def sim_events():
    """Every event type the sim raises."""
    text = read(os.path.join(SCRIPTS, "run_sim.gd"))
    return set(re.findall(r'"type":\s*"([a-z0-9_]+)"', text))


def drain_branches():
    """The event branches of run_screen's _drain, and the body of each.

    A branch is a `match` arm, so it is a block of its own: the sound
    it plays is the sound of that event.
    """
    text = read(os.path.join(SCRIPTS, "run_screen.gd"))
    try:
        block = text[text.index("func _drain()"):text.index("func _sync(alpha: float)")]
    except ValueError:
        return {}
    parts = re.split(r'^\t\t\t"([a-z0-9_]+)":\s*$', block, flags=re.M)
    return {parts[i]: parts[i + 1] for i in range(1, len(parts), 2)}


def main():
    director = read(os.path.join(SCRIPTS, "audio_director.gd"))
    events = parse_events(director)
    manifest = parse_manifest(read(os.path.join(SCRIPTS, "sfx_manifest.gd")))
    called = called_names()
    fmt = clip_path_format(director)
    problems = []
    _uid_owner.update(_collect_uids())

    for name in sorted(set(events) - set(manifest)):
        problems.append("event '%s' has no manifest entry" % name)
    for name in sorted(set(manifest) - set(events)):
        problems.append("event '%s' is in the manifest but not in EVENTS" % name)

    known = set()
    for name, count in sorted(manifest.items()):
        for k in range(1, count + 1):
            res_path, path = clip_path(fmt, name, k)
            known.add(os.path.basename(path))
            if not os.path.exists(path):
                problems.append("missing clip %s" % os.path.basename(path))
                continue
            problems.extend(check_import(path, res_path))
            level = mean_volume(path)
            if level is not None and level < SILENT_DB:
                problems.append("clip %s is silent (mean %.1f dB)" % (
                    os.path.basename(path), level))

    # Every clip in the folder has to belong to an event, or the game
    # ships audio nothing can reach.
    for path in sorted(glob.glob(os.path.join(SFX, "*.ogg"))):
        if os.path.basename(path) not in known:
            problems.append("orphan clip %s (no event ships it)" % (
                os.path.basename(path)))

    # The music loops the director can be asked for have to be on disk
    # too: a missing loop is a silent screen, not a missing file.
    music_fmt = music_path_format(director)
    for name in sorted(music_tracks()):
        res_path = music_fmt.replace("%s", name)
        rel = res_path[len("res://"):] if res_path.startswith("res://") else res_path
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            problems.append("missing music loop %s" % name)
            continue
        problems.extend(check_import(path, res_path))

    for name, places in sorted(called.items()):
        target = LEGACY.get(name, name)
        if target not in events:
            problems.append("call site %s plays unknown event '%s'" % (
                places[0], name))

    for name in sorted(events):
        if name not in called:
            problems.append("event '%s' is never played" % name)

    # Every event the sim raises has to reach the screen with a voice,
    # or the fight goes on in silence. The exceptions are the moments
    # that are silent by design.
    branches = drain_branches()
    if not branches:
        problems.append("cannot find the event branches in run_screen.gd")
    for name in sorted(sim_events()):
        body = branches.get(name)
        if body is None:
            problems.append("sim event '%s' is not handled by run_screen" % name)
            continue
        if name in SILENT_EVENTS:
            continue
        if not re.search(r'AudioDirector\.(?:sfx|play|gem|sting)\(', body):
            problems.append("sim event '%s' reaches the screen with no sound" % name)

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
