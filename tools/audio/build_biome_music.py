"""Loops for the Frozen Crypt and the Burning Swamp, cut from four CC BY 4.0 tracks by
Kevin MacLeod (incompetech.com). See the Music section of CREDITS.md.

Run from the repo root: python3 tools/audio/build_biome_music.py
Needs ffmpeg (with libvorbis), numpy, and network for the first run (the mp3s are cached
in $TMPDIR/incompetech). Writes assets/audio/music/{frozen,frozen_boss,swamp,swamp_boss}.ogg.

Each loop is the stretch [start, start+length) of the source. Where the loop ends, the last
`xfade` seconds are an equal-power blend into the audio that sits just before `start`, so
the stream wraps from the tail back to `start` with no seam, and the first play begins
clean. `start` and `length` were picked by a search (matching
log-spectrum before the two points, with `length` a whole number of bars for the rhythmic
tracks). The result is trimmed of any lead-in, loudness-matched to -16.5 LUFS like the other
biome tracks, peak-limited, and encoded as 44.1 kHz stereo Vorbis at 96 kbit/s like grove.
"""

import os
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request

import numpy as np

SR = 44100
LUFS = -16.5
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
OUT = os.path.join(ROOT, "assets", "audio", "music")
CACHE = os.path.join(tempfile.gettempdir(), "incompetech")
BASE = "https://incompetech.com/music/royalty-free/mp3-royaltyfree/"

# out name: (incompetech file, start s, length s, crossfade s)
TRACKS = {
    "frozen": ("Night Vigil.mp3", 16.63, 88.89, 3.0),
    "frozen_boss": ("Eternal Terminal.mp3", 32.97, 95.71, 1.5),
    "swamp": ("Static Motion.mp3", 38.34, 97.75, 3.0),
    "swamp_boss": ("Burnt Spirit.mp3", 4.09, 70.00, 1.5),
}


def fetch(name):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, name)
    if not os.path.exists(path):
        urllib.request.urlretrieve(BASE + urllib.parse.quote(name), path)
    return path


def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).copy()


def loop(y, start, length, xfade):
    a = int(round(start * SR))
    b = a + int(round(length * SR))
    x = int(round(xfade * SR))
    seg = y[a:b].copy()
    t = np.linspace(0.0, np.pi / 2, x)[:, None]
    seg[-x:] = y[b - x:b] * np.cos(t) + y[a - x:a] * np.sin(t)
    return seg


def lufs(wav):
    r = subprocess.run(["ffmpeg", "-nostats", "-i", wav, "-af", "ebur128", "-f", "null", "-"], capture_output=True, text=True)
    tail = r.stderr.split("Summary:")[-1]
    return float(tail.split("I:")[1].split("LUFS")[0])


def encode(seg, out):
    tmp = os.path.join(tempfile.gettempdir(), "biome_loop.wav")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-", tmp],
                   input=seg.astype(np.float32).tobytes(), check=True)
    gain = LUFS - lufs(tmp)
    # alimiter takes a linear ceiling: -1.5 dBFS leaves room for the Vorbis overshoot.
    af = "volume=%.3fdB,alimiter=limit=0.84:attack=5:release=50:level=disabled" % gain
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-af", af, "-c:a", "libvorbis", "-b:a", "96k",
                    "-ar", str(SR), "-ac", "2", "-map_metadata", "-1", out], check=True)
    os.remove(tmp)
    return gain


def main():
    only = sys.argv[1:] or list(TRACKS)
    for name in only:
        src, start, length, xfade = TRACKS[name]
        seg = loop(decode(fetch(src)), start, length, xfade)
        out = os.path.join(OUT, name + ".ogg")
        gain = encode(seg, out)
        print("%-12s %-22s %6.2fs  gain %+.1f dB  %d KB" % (name, src, len(seg) / SR, gain, os.path.getsize(out) // 1024))


if __name__ == "__main__":
    main()
