"""Original loops for the Frozen Crypt and the Burning Swamp (no samples).
Run from the repo root: python3 tools/audio/build_biome_music.py
Writes assets/audio/music/{frozen,frozen_boss,swamp,swamp_boss}.ogg (needs ffmpeg)."""

import os
import subprocess

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "audio", "music")
NOTE = {n: 440.0 * 2 ** ((i - 9) / 12) for i, n in enumerate(
    ["C0", "C#0", "D0", "D#0", "E0", "F0", "F#0", "G0", "G#0", "A0", "A#0", "B0"])}


def hz(name):
    """'A3' -> Hz."""
    base = name[:-1]
    octave = int(name[-1])
    semis = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"].index(base)
    return 440.0 * 2 ** ((semis - 9) / 12 + (octave - 4))


def env(n, a, r, curve=2.0):
    t = np.arange(n) / SR
    e = np.minimum(t / max(a, 1e-4), 1.0) * np.exp(-t * curve / max(r, 1e-4))
    return e


def add(buf, sig, at):
    i = int(at * SR)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(sig))
    buf[i:j] += sig[:j - i]


def bell(f, dur, vol):
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = (np.sin(2 * np.pi * f * t) + 0.45 * np.sin(2 * np.pi * f * 2.76 * t) + 0.2 * np.sin(2 * np.pi * f * 5.4 * t))
    return sig * env(n, 0.004, dur * 0.45, 3.0) * vol


def pad(f, dur, vol, detune=0.004):
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = sum(np.sin(2 * np.pi * f * (1 + d) * t) for d in (-detune, 0.0, detune)) / 3.0
    sig += 0.4 * np.sin(2 * np.pi * f * 2 * t)
    e = np.minimum(t / 1.2, 1.0) * np.minimum((dur - t) / 1.4, 1.0)
    return sig * e * vol


def sub(f, dur, vol, tri=False):
    n = int(dur * SR)
    t = np.arange(n) / SR
    if tri:
        sig = 2 * np.abs(2 * ((f * t) % 1.0) - 1) - 1
    else:
        sig = np.sin(2 * np.pi * f * t)
    return sig * env(n, 0.01, dur * 0.8, 1.8) * vol


def noise_band(n, lo, hi, rng):
    x = rng.standard_normal(n)
    X = np.fft.rfft(x)
    fr = np.fft.rfftfreq(n, 1 / SR)
    X[(fr < lo) | (fr > hi)] = 0
    y = np.fft.irfft(X, n)
    return y / (np.abs(y).max() + 1e-9)


def drum(f0, dur, vol, rng, snare=False):
    n = int(dur * SR)
    t = np.arange(n) / SR
    if snare:
        sig = rng.standard_normal(n) * 0.6 + np.sin(2 * np.pi * 190 * t) * 0.4
        return sig * np.exp(-t * 18) * vol
    sig = np.sin(2 * np.pi * (f0 + 90 * np.exp(-t * 30)) * t)
    return sig * np.exp(-t * 7) * vol


def finish(buf, name, loop_fade=1.5):
    buf = buf / (np.abs(buf).max() + 1e-9) * 0.85
    # Seamless loop: fold the tail into the head.
    k = int(loop_fade * SR)
    w = np.linspace(0, 1, k)
    head = buf[:k] * w + buf[-k:] * (1 - w)
    buf = np.concatenate([head, buf[k:-k]])
    pcm = (np.clip(buf, -1, 1) * 32767).astype(np.int16)
    stereo = np.stack([pcm, np.roll(pcm, 700)], axis=1)  # a hair of width
    raw = os.path.join(OUT, name + ".raw")
    stereo.tofile(raw)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(SR), "-ac", "2", "-i", raw,
                    "-c:a", "libvorbis", "-q:a", "3", os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(raw)
    print("wrote", name)


def frozen(boss):
    rng = np.random.default_rng(11 if not boss else 12)
    bpm = 84 if not boss else 118
    beat = 60.0 / bpm
    bars = 16 if not boss else 24
    n = int(beat * 4 * bars * SR)
    buf = np.zeros(n)
    # D minor, glass bells over a deep pad: Dm, Bb, Gm, A.
    prog = [("D2", ["D4", "F4", "A4", "C5"]), ("A#1", ["D4", "F4", "A#4", "A4"]), ("G1", ["D4", "G4", "A#4", "D5"]), ("A1", ["C#4", "E4", "A4", "C#5"])]
    for b in range(bars):
        root, notes = prog[b % 4]
        t0 = b * beat * 4
        add(buf, pad(hz(root), beat * 4 + 0.4, 0.22), t0)
        add(buf, pad(hz(root) * 1.5, beat * 4 + 0.4, 0.1), t0)
        add(buf, sub(hz(root) * 2, beat * 3.6, 0.22, True), t0)
        pattern = [0, 1, 2, 3, 2, 1, 2, 3] if not boss else [0, 2, 1, 3, 2, 3, 1, 2]
        for k, idx in enumerate(pattern):
            if boss or k % 2 == 0 or b % 2 == 1:
                add(buf, bell(hz(notes[idx]) * (2 if boss and k % 4 == 3 else 1), beat * 2.0, 0.16 if not boss else 0.13), t0 + k * beat * 0.5)
        if boss:
            for k in range(4):
                add(buf, drum(52, 0.5, 0.55, rng), t0 + k * beat)
                if k % 2 == 1:
                    add(buf, drum(0, 0.25, 0.22, rng, True), t0 + k * beat)
            for k in range(8):
                add(buf, drum(0, 0.05, 0.05, rng, True), t0 + k * beat * 0.5)
    # Wind: slow-breathing band-passed noise.
    wind = noise_band(n, 180, 1400, rng)
    t = np.arange(n) / SR
    lfo = 0.5 + 0.5 * np.sin(2 * np.pi * t / (beat * 8))
    buf += wind * (0.04 + 0.05 * lfo) * (1.0 if not boss else 1.4)
    finish(buf, "frozen_boss" if boss else "frozen")


def swamp(boss):
    rng = np.random.default_rng(21 if not boss else 22)
    bpm = 76 if not boss else 104
    beat = 60.0 / bpm
    bars = 16 if not boss else 24
    n = int(beat * 4 * bars * SR)
    buf = np.zeros(n)
    # E phrygian: Em, F, Em, D with a crawling bass and low reed tones.
    prog = [("E1", "E3"), ("F1", "F3"), ("E1", "G3"), ("D1", "D3")]
    for b in range(bars):
        root, top = prog[b % 4]
        t0 = b * beat * 4
        add(buf, pad(hz(root) * 2, beat * 4 + 0.4, 0.2, 0.008), t0)
        add(buf, pad(hz(top), beat * 4 + 0.4, 0.09, 0.012), t0)
        walk = [0, 0, 7, 5] if not boss else [0, 0, 7, 0, 0, 5, 7, 5]
        step = beat if not boss else beat * 0.5
        for k, semis in enumerate(walk):
            add(buf, sub(hz(root) * 2 ** (semis / 12) * 2, step * 0.9, 0.5, True), t0 + k * step)
        for k in range(4):
            add(buf, drum(48, 0.6, 0.6 if boss else 0.35, rng), t0 + k * beat + (0 if k % 2 == 0 else beat * 0.0))
        if boss:
            for k in (1, 3):
                add(buf, drum(0, 0.28, 0.3, rng, True), t0 + k * beat)
    # Bubbles and crackle: sparse low blips and fire pops.
    for _ in range(int(n / SR * (1.6 if not boss else 2.4))):
        at = rng.uniform(0, n / SR - 0.5)
        f = rng.uniform(140, 420)
        m = int(0.12 * SR)
        tt = np.arange(m) / SR
        add(buf, np.sin(2 * np.pi * (f + 900 * tt) * tt) * np.exp(-tt * 28) * 0.1, at)
    for _ in range(int(n / SR * 9)):
        at = rng.uniform(0, n / SR - 0.1)
        m = int(0.012 * SR)
        add(buf, rng.standard_normal(m) * np.exp(-np.arange(m) / SR * 400) * 0.08, at)
    buf += noise_band(n, 60, 500, rng) * 0.05
    finish(buf, "swamp_boss" if boss else "swamp")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    frozen(False)
    frozen(True)
    swamp(False)
    swamp(True)
