"""Original cozy music loop and punchy SFX for Critter Clash. No third-party samples."""

import math
import os
import random
import struct
import wave

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "audio")
os.makedirs(OUT, exist_ok=True)
SR = 44100


def clamp(x):
    return max(-1.0, min(1.0, x))


def env_adsr(i, n, a=0.01, d=0.08, s=0.55, r=0.12):
    t = i / SR
    dur = n / SR
    if t < a:
        return t / max(1e-5, a)
    if t < a + d:
        k = (t - a) / max(1e-5, d)
        return 1.0 + (s - 1.0) * k
    rel = dur - r
    if t > rel:
        k = (t - rel) / max(1e-5, r)
        return s * (1.0 - clamp(k))
    return s


def sine(freq, t):
    return math.sin(2 * math.pi * freq * t)


def write_wav(path, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    scale = 0.9 / peak
    with wave.open(path, "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        frames = b"".join(struct.pack("<h", int(clamp(s * scale) * 32767)) for s in samples)
        wf.writeframes(frames)


def tone(freq, dur, vol=0.3, kind="sine", decay=6.0):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        if kind == "sine":
            v = sine(freq, t)
        elif kind == "tri":
            v = 2 * abs(2 * ((t * freq) % 1) - 1) - 1
        else:
            v = random.uniform(-1, 1)
        e = math.exp(-decay * t) * env_adsr(i, n, 0.005, 0.04, 0.4, min(0.12, dur * 0.4))
        out.append(v * e * vol)
    return out


def mix_into(base, extra, at=0):
    start = int(at * SR)
    for i, s in enumerate(extra):
        j = start + i
        if j >= len(base):
            break
        base[j] += s


def save(name, samples):
    path = os.path.join(OUT, name + ".wav")
    write_wav(path, samples)
    print(name, len(samples) / SR)


def sfx_click():
    a = tone(880, 0.06, 0.25, decay=18)
    b = tone(1320, 0.05, 0.12, decay=22)
    mix_into(a, b)
    save("click", a)


def sfx_deploy():
    n = int(SR * 0.28)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        f = 220 + 640 * (t / 0.28)
        out[i] += sine(f, t) * math.exp(-7 * t) * 0.45
        if t < 0.04:
            out[i] += random.uniform(-1, 1) * (1 - t / 0.04) * 0.18
    save("deploy", out)


def sfx_merge():
    n = int(SR * 0.7)
    out = [0.0] * n
    notes = [523.25, 659.25, 783.99, 1046.5]
    for k, f in enumerate(notes):
        mix_into(out, tone(f, 0.45, 0.28, decay=4.5), k * 0.07)
        mix_into(out, tone(f * 2, 0.3, 0.08, decay=6), k * 0.07)
    save("merge", out)


def sfx_hit():
    n = int(SR * 0.14)
    out = []
    for i in range(n):
        t = i / SR
        out.append((sine(140, t) * 0.5 + random.uniform(-1, 1) * 0.5) * math.exp(-22 * t) * 0.7)
    save("hit", out)


def sfx_shoot():
    n = int(SR * 0.12)
    out = []
    for i in range(n):
        t = i / SR
        f = 740 - 420 * (t / 0.12)
        out.append(sine(f, t) * math.exp(-16 * t) * 0.3)
    save("shoot", out)


def sfx_death():
    n = int(SR * 0.4)
    out = []
    for i in range(n):
        t = i / SR
        f = 480 - 360 * (t / 0.4)
        out.append((sine(f, t) * 0.4 + random.uniform(-1, 1) * 0.25) * math.exp(-6 * t) * 0.5)
    save("death", out)


def sfx_error():
    a = tone(220, 0.12, 0.3, decay=10)
    mix_into(a, tone(180, 0.14, 0.25, decay=8), 0.08)
    save("error", a)


def sfx_den():
    n = int(SR * 0.28)
    out = []
    for i in range(n):
        t = i / SR
        out.append((sine(70, t) + sine(110, t) * 0.4) * math.exp(-8 * t) * 0.6)
    save("den", out)


def sfx_win():
    n = int(SR * 1.3)
    out = [0.0] * n
    for k, f in enumerate([523.25, 659.25, 783.99, 1046.5, 1318.5]):
        mix_into(out, tone(f, 0.7, 0.26, decay=3.2), k * 0.11)
    save("win", out)


def sfx_lose():
    n = int(SR * 1.0)
    out = [0.0] * n
    for k, f in enumerate([392, 349.2, 311.1, 261.6]):
        mix_into(out, tone(f, 0.55, 0.26, decay=3.0), k * 0.12)
    save("lose", out)


NOTES = {
    "C3": 130.81, "D3": 146.83, "E3": 164.81, "F3": 174.61, "G3": 196.00, "A3": 220.00, "B3": 246.94,
    "C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23, "G4": 392.00, "A4": 440.00, "B4": 493.88,
    "C5": 523.25, "D5": 587.33, "E5": 659.25, "G5": 783.99, "A5": 880.00,
}

# 76 bpm, 8 bars of 4/4. Resolves C so the loop sits.
BPM = 76
BEAT = 60.0 / BPM
BARS = [
    ("C3", ["E4", "G4", "A4", "G4"]),
    ("G3", ["D4", "E4", "D4", "C4"]),
    ("A3", ["C4", "E4", "A4", "G4"]),
    ("F3", ["A4", "G4", "E4", "D4"]),
    ("C3", ["E4", "G4", "C5", "A4"]),
    ("G3", ["G4", "E4", "D4", "B3"]),
    ("F3", ["A4", "G4", "F4", "E4"]),
    ("C3", ["G4", "E4", "D4", "C4"]),
]


def music():
    dur = BEAT * 4 * len(BARS)
    n = int(SR * dur)
    out = [0.0] * n
    for b, (root, melody) in enumerate(BARS):
        t0 = b * BEAT * 4
        # Pad: root + fifth + octave, soft.
        fifth = NOTES[root] * 1.5
        for f, vol in ((NOTES[root], 0.12), (fifth, 0.06), (NOTES[root] * 2, 0.04)):
            seg = []
            samples = int(BEAT * 4 * SR)
            for i in range(samples):
                t = i / SR
                e = env_adsr(i, samples, 0.08, 0.2, 0.7, 0.25)
                seg.append(sine(f, t) * e * vol)
            mix_into(out, seg, t0)
        for k, name in enumerate(melody):
            mix_into(out, tone(NOTES[name], BEAT * 0.85, 0.16, "sine", decay=3.4), t0 + k * BEAT)
            mix_into(out, tone(NOTES[name] * 2, BEAT * 0.4, 0.035, "sine", decay=5), t0 + k * BEAT)
        # Quiet shaker on eighths.
        for k in range(8):
            hat_n = int(SR * 0.03)
            hat = [random.uniform(-1, 1) * math.exp(-i / SR * 80) * 0.015 for i in range(hat_n)]
            mix_into(out, hat, t0 + k * BEAT * 0.5)
    # Seamless crossfade.
    fade = int(0.04 * SR)
    for i in range(fade):
        w = i / fade
        out[i] = out[i] * w + out[-fade + i] * (1 - w)
    out = out[:-fade]
    save("music", out)


if __name__ == "__main__":
    random.seed(7)
    sfx_click()
    sfx_deploy()
    sfx_merge()
    sfx_hit()
    sfx_shoot()
    sfx_death()
    sfx_error()
    sfx_den()
    sfx_win()
    sfx_lose()
    music()
    print("audio ok")
