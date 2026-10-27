"""Boss-entrance stings: one per boss plus a shared fallback, cut and coloured from three
short Kevin MacLeod (incompetech.com) tracks, CC BY 4.0 (see CREDITS.md), with the repo's own
CC0 `boom` hits layered under the heavy ones.

Run from the repo root: python3 tools/audio/build_boss_stings.py
Needs ffmpeg with libvorbis; downloads the sources once to $TMPDIR/incompetech.
Writes assets/audio/sfx/boss_sting_<boss>.ogg (the intro plays `boss_sting_<id>`, else
`boss_sting`, which is boss_sting_1.ogg) as 44.1 kHz stereo Vorbis, the hit lands within 30 ms
of the start (the intro's name card slams at the same moment), -14 LUFS, peak under -1 dBFS.
"""

import os
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
SFX = os.path.join(ROOT, "assets", "audio", "sfx")
CACHE = os.path.join(tempfile.gettempdir(), "incompetech")
LUFS = -14.0
BASE = "https://incompetech.com/music/royalty-free/mp3-royaltyfree/"

HIT1 = "Danse Macabre - Big Hit 1.mp3"   # full orchestra, two-note hit, onset 0.50 s
HIT2 = "Danse Macabre - Big Hit 2.mp3"   # full orchestra, two-note hit, onset 0.30 s
GONG = "Darkness Speaks.mp3"             # gong and synth swell, onset 1.20 s

# name -> (source, onset s, length s, filter on the hit, optional (boom file, dB, pitch)).
# Every sting is cut to `length` seconds after the filter, so pitching down does not stretch it.
STINGS = {
    "gravemaw": (HIT1, 0.50, 3.4, "anull", ("boom_1", -7, 1.0)),
    "thorn": (HIT2, 0.30, 3.2, "asetrate=44100*0.9,aresample=44100,lowpass=f=7000", None),
    "hexer": (GONG, 1.20, 3.6, "anull", None),
    "warden": (HIT1, 0.50, 3.6, "asetrate=44100*0.82,aresample=44100", ("boom_2", -5, 0.9)),
    "rime": (HIT2, 0.30, 3.4, "anull", None),
    "cinder": (HIT1, 0.50, 3.8, "asetrate=44100*0.72,aresample=44100,acompressor=threshold=-18dB:ratio=3:attack=5:release=120", ("boom_1", -4, 0.7)),
    "1": (HIT1, 0.50, 3.2, "anull", None),
}
# Rime Regent gets an icy ring: the hit's top end, echoed twice, mixed under it.
SHIMMER = "[hit]asplit[d][s];[s]highpass=f=2500,aecho=0.8:0.6:90|170:0.5|0.3,volume=-8dB[sh];[d][sh]amix=inputs=2:normalize=0[hit]"


def fetch(name):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, name)
    if not os.path.exists(path):
        urllib.request.urlretrieve(BASE + urllib.parse.quote(name), path)
    return path


def build(name, spec):
    src, onset, length, flt, boom = spec
    out = os.path.join(SFX, "boss_sting_%s.ogg" % name)
    inputs = ["-ss", "%.3f" % (onset - 0.03), "-t", "%.2f" % (length * 1.6), "-i", fetch(src)]
    graph = "[0:a]aformat=sample_rates=44100:channel_layouts=stereo,%s,atrim=0:%.2f[hit]" % (flt, length)
    if name == "rime":
        graph += ";" + SHIMMER
    last = "hit"
    if boom:
        inputs += ["-i", os.path.join(SFX, boom[0] + ".ogg")]
        graph += ";[1:a]asetrate=44100*%.2f,aresample=44100,aformat=channel_layouts=stereo,volume=%ddB[b]" % (boom[2], boom[1])
        graph += ";[hit][b]amix=inputs=2:normalize=0:duration=longest[mix]"
        last = "mix"
    graph += ";[%s]atrim=0:%.2f,afade=t=in:d=0.004,afade=t=out:st=%.2f:d=0.9[o]" % (last, length, length - 0.9)
    tmp = os.path.join(tempfile.gettempdir(), "sting.wav")
    subprocess.run(["ffmpeg", "-v", "error", "-y"] + inputs + ["-filter_complex", graph, "-map", "[o]", "-ar", "44100", "-ac", "2", tmp], check=True)
    # Loudness to -14 LUFS (the boss roar it lands with is -17), peaks held under -1 dBFS.
    r = subprocess.run(["ffmpeg", "-nostats", "-i", tmp, "-af", "ebur128", "-f", "null", "-"], capture_output=True, text=True)
    gain = LUFS - float(r.stderr.split("Summary:")[-1].split("I:")[1].split("LUFS")[0])
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-af", "volume=%.2fdB,alimiter=limit=0.89:attack=2:release=60:level=disabled" % gain,
                    "-c:a", "libvorbis", "-q:a", "4", "-map_metadata", "-1", out], check=True)
    os.remove(tmp)
    return out


if __name__ == "__main__":
    for n in sys.argv[1:] or STINGS:
        p = build(n, STINGS[n])
        print("%-9s %5d KB" % (n, os.path.getsize(p) // 1024))
