"""Ambient beds and one-shots for Rimehollow (frost) and the Cinder Mire (swamp).

Writes assets/audio/ambient/*.ogg. Run from the repo root:
    python3 tools/audio/build_ambience.py [SRC]
SRC (default /workspace/cc-pr/_amb) holds the downloads listed below. Needs ffmpeg
(libvorbis) and numpy. Every source is CC0; see the Ambience section of CREDITS.md.

Sources (OpenGameArt, all CC0):
  wind.ogg            "Icy Heights" by Ecrivain         -> frost_bed, frost_gust
  winter-wind.mp3     "Winter Wind" by wipics           -> frost_gust
  swamp.ogg           "Swamp Environment Audio" by LokiF -> swamp_bed
  swamp_sounds.zip    same pack (bubbling_*.ogg)         -> swamp_bubble
  croak_0*.mp3, ribbit_0*.mp3  "Frog Croaks", "Ribbit Frog Sounds" by EZduzziteh -> swamp_frog
  crow_caw.wav        "Crow caw" by zeroisnotnull        -> swamp_crow
  fire-1.ogg          "Fire Crackling" by AntumDeluge    -> swamp_ember
Drawn from scratch here (no source): frost_creak, frost_drip.

Beds are stereo-free (mono) loops cut with an equal-power crossfade so the stream wraps
without a seam, loudness-matched to -30 LUFS (they sit under everything). One-shots are
mono, trimmed, faded, peak-normalised to -3 dBFS; the game sets how loud they play.
"""
import os
import subprocess
import sys
import tempfile

import numpy as np

SR = 44100
SRC = sys.argv[1] if len(sys.argv) > 1 else "/workspace/cc-pr/_amb"
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
OUT = os.path.join(ROOT, "assets", "audio", "ambient")
os.makedirs(OUT, exist_ok=True)


def load(path):
    p = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"], capture_output=True, check=True)
    return np.frombuffer(p.stdout, dtype=np.float32).copy()


def save(name, x, bitrate="64k"):
    tmp = tempfile.mktemp(suffix=".f32")
    x.astype(np.float32).tofile(tmp)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", tmp, "-c:a", "libvorbis", "-b:a", bitrate, os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(tmp)


def lufs(x):
    p = subprocess.run(["ffmpeg", "-v", "info", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-", "-af", "ebur128", "-f", "null", "-"], input=x.astype(np.float32).tobytes(), capture_output=True)
    for line in p.stderr.decode().splitlines()[::-1]:
        if line.strip().startswith("I:"):
            return float(line.split()[1])
    raise RuntimeError("no loudness")


def to_lufs(x, target):
    g = 10 ** ((target - lufs(x)) / 20)
    y = x * g
    pk = np.max(np.abs(y))
    return y / pk * 0.9 if pk > 0.9 else y


def peak(x, db=-3.0):
    return x / np.max(np.abs(x)) * 10 ** (db / 20)


def fade(x, a=0.01, b=0.08):
    x = x.copy()
    n, m = int(a * SR), int(b * SR)
    x[:n] *= np.linspace(0, 1, n)
    x[-m:] *= np.linspace(1, 0, m)
    return x


def trim(x, thr=0.02):
    idx = np.where(np.abs(x) > thr * np.max(np.abs(x)))[0]
    return x[idx[0]: idx[-1] + 1]


def loop(x, start, length, xfade=3.0):
    """[start, start+length) where the last xfade seconds blend into the audio just before start."""
    n = int(xfade * SR)
    s, L = int(start * SR), int(length * SR)
    seg = x[s: s + L].copy()
    pre = x[s - n: s]
    t = np.linspace(0, np.pi / 2, n)
    seg[-n:] = seg[-n:] * np.cos(t) + pre * np.sin(t)
    return seg


def hits(x, count, length, gap=0.4):
    """The `count` loudest non-overlapping windows of `length` seconds."""
    w = int(length * SR)
    c = np.concatenate([[0.0], np.cumsum(x.astype(np.float64) ** 2)])
    env = (c[w:] - c[:-w]) / w
    out = []
    for _ in range(count):
        i = int(np.argmax(env))
        if env[i] <= 0:
            break
        out.append(x[i: i + w].copy())
        env[max(0, i - int(gap * SR)): i + w + int(gap * SR)] = 0
    return out


rng = np.random.default_rng(11)


def lowpass(x, hz):
    from numpy.fft import irfft, rfft
    f = rfft(x)
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    f[fr > hz] = 0
    return irfft(f, len(x))


def build():
    # --- Rimehollow ---
    wind = load(os.path.join(SRC, "wind.ogg"))
    save("frost_bed", to_lufs(loop(wind, 3.5, len(wind) / SR - 3.6), -30.0), "48k")
    big = load(os.path.join(SRC, "winter-wind.mp3"))
    for i, g in enumerate(hits(big, 3, 4.0, 3.0), 1):
        save("frost_gust_%d" % i, peak(fade(g, 0.8, 1.2), -6.0), "48k")
    # Ice creak: a resonant band of noise whose pitch slides down, in two or three groans.
    for i in range(1, 4):
        d = 1.1 + 0.3 * i
        t = np.arange(int(d * SR)) / SR
        f = (420 + 90 * i) * np.exp(-1.6 * t / d) + 60
        ph = 2 * np.pi * np.cumsum(f) / SR
        wob = 1 + 0.35 * np.sin(2 * np.pi * (11 + 4 * i) * t)
        n = lowpass(rng.standard_normal(len(t)), 2400)
        x = (np.sin(ph) * 0.6 + np.sin(ph * 2.01) * 0.25 + n * 0.25) * wob
        env = np.sin(np.pi * np.clip(t / d, 0, 1)) ** 1.5
        save("frost_creak_%d" % i, peak(fade(x * env, 0.02, 0.15)), "48k")
    # Drip: a short falling ping on ice.
    for i in range(1, 4):
        t = np.arange(int(0.45 * SR)) / SR
        f0 = 2100 + 340 * i
        f = f0 * (1 + 0.5 * np.exp(-t * 60))
        x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 16)
        x += 0.3 * np.sin(2 * np.pi * np.cumsum(f * 2.4) / SR) * np.exp(-t * 28)
        save("frost_drip_%d" % i, peak(fade(x, 0.002, 0.1)), "48k")
    # --- Cinder Mire ---
    swamp = load(os.path.join(SRC, "swamp.ogg"))
    save("swamp_bed", to_lufs(loop(swamp, 3.5, len(swamp) / SR - 3.6), -30.0), "48k")
    k = 1
    for name in ["croak_01", "croak_03", "croak_04", "ribbit_01", "ribbit_02", "ribbit_03"]:
        x = trim(load(os.path.join(SRC, name + ".mp3")))
        save("swamp_frog_%d" % k, peak(fade(x, 0.005, 0.06)), "48k")
        k += 1
    crow = trim(load(os.path.join(SRC, "crow_caw.wav")))
    save("swamp_crow_1", peak(fade(crow, 0.005, 0.1)), "48k")
    k = 1
    for n in ["bubbling_1", "bubbling_2", "bubbling_3", "bubbling_4"]:
        b = load(os.path.join(SRC, "swampz", n + ".ogg"))
        for g in hits(b, 1, 0.5, 1.0):
            save("swamp_bubble_%d" % k, peak(fade(g, 0.01, 0.2)), "48k")
            k += 1
    fire = load(os.path.join(SRC, "fire-1.ogg"))
    k = 1
    for g in hits(fire, 3, 0.6, 0.3):
        save("swamp_ember_%d" % k, peak(fade(g, 0.01, 0.2)), "48k")
        k += 1


if __name__ == "__main__":
    build()
    for f in sorted(os.listdir(OUT)):
        print(f, os.path.getsize(os.path.join(OUT, f)))
