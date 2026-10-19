"""Synthesise the one-shot effects the licensed packs could not cover.

tools/build_sfx.py layers CC0 clips into one stream per event. A few
gameplay moments have no matching clip in those packs - a melee arc, a
dash, a splash, a piece of gear hitting the ground - and shipping silence
there reads as a bug. This script draws them instead: short procedural
clips, mono 44.1 kHz, peak-normalised to -1 dBFS, written to the same
assets/audio/sfx folder as the licensed ones so the AudioDirector loader
and the SfxManifest counts work unchanged.

Every clip here is generated from scratch by this file (no sampled source
material), so it carries no third-party licence. The clips are mono OGG
(q3) to match the rest of the folder and to keep the iOS package small.

Clips already on disk are kept: re-running the script only fills in what
is missing, so the resource uids do not churn (Godot re-imports every
clip whose uid moved). Pass --force to re-render everything.

usage: python3 tools/build_sfx_synth.py [--out DIR] [--force]
"""
import glob
import hashlib
import os
import re
import subprocess
import sys
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets/audio/sfx")
MANIFEST = os.path.join(ROOT, "scripts/sfx_manifest.gd")
SR = 44100
PEAK = 10.0 ** (-1.0 / 20.0)


# --- Signal helpers ----------------------------------------------------------

def t_of(dur):
    return np.arange(int(round(dur * SR))) / SR


def silence(dur):
    return np.zeros(int(round(dur * SR)))


def noise(dur, seed):
    rng = np.random.default_rng(seed)
    return rng.uniform(-1.0, 1.0, int(round(dur * SR)))


def sine(freq, dur, phase=0.0):
    """freq may be a scalar or a per-sample array (for sweeps)."""
    t = t_of(dur)
    f = np.full_like(t, freq, dtype=float) if np.isscalar(freq) else np.asarray(freq, dtype=float)
    return np.sin(2.0 * np.pi * np.cumsum(f) / SR + phase)


def saw(freq, dur, harmonics=12):
    """Band-limited saw: a few odd/even partials instead of a raw ramp."""
    t = t_of(dur)
    f = np.full_like(t, freq, dtype=float) if np.isscalar(freq) else np.asarray(freq, dtype=float)
    ph = 2.0 * np.pi * np.cumsum(f) / SR
    out = np.zeros_like(t)
    for k in range(1, harmonics + 1):
        out += np.sin(k * ph) / k
    return out * (2.0 / np.pi)


def square(freq, dur, harmonics=7):
    """Soft square: odd partials only, rolled off fast so it stays polite."""
    t = t_of(dur)
    f = np.full_like(t, freq, dtype=float) if np.isscalar(freq) else np.asarray(freq, dtype=float)
    ph = 2.0 * np.pi * np.cumsum(f) / SR
    out = np.zeros_like(t)
    for k in range(1, harmonics + 1, 2):
        out += np.sin(k * ph) / k
    return out * (4.0 / np.pi)


def sweep(f0, f1, dur, curve=1.0):
    """Per-sample frequency for an exponential-ish glide."""
    t = t_of(dur)
    if curve == 1.0:
        return f0 + (f1 - f0) * (t / max(dur, 1e-6))
    return f0 * np.power(max(f1, 1e-6) / f0, np.power(t / max(dur, 1e-6), curve))


def env_ad(dur, attack, decay, hold=0.0):
    """Attack / decay envelope over a duration, with an optional hold."""
    n = int(round(dur * SR))
    a = max(1, int(round(attack * SR)))
    d = max(1, int(round(decay * SR)))
    h = max(0, int(round(hold * SR)))
    env = np.concatenate([
        np.linspace(0.0, 1.0, a, endpoint=False),
        np.ones(h),
        np.exp(-np.arange(d) / (d / 4.0)),
    ])
    if len(env) < n:
        env = np.concatenate([env, np.zeros(n - len(env))])
    return env[:n]


def fade_edges(x, ms=4.0):
    """Short fades so a clip never clicks on start or stop."""
    n = int(round(ms * SR / 1000.0))
    if n * 2 >= len(x):
        return x
    ramp = np.linspace(0.0, 1.0, n, endpoint=False)
    x[:n] *= ramp
    x[-n:] *= ramp[::-1]
    return x


def band(x, lo, hi):
    """Zero-phase band filter: FFT, keep the band, invert."""
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / SR)
    spec[(freqs < lo) | (freqs > hi)] = 0.0
    return np.fft.irfft(spec, n=len(x))


def low(x, cut):
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / SR)
    spec[freqs > cut] = 0.0
    return np.fft.irfft(spec, n=len(x))


def high(x, cut):
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / SR)
    spec[freqs < cut] = 0.0
    return np.fft.irfft(spec, n=len(x))


def moving_band(x, f0, f1, curve=1.0, q=1.3):
    """Band filter whose centre glides: a swept whoosh.

    A state-variable filter stepped per sample, so the centre frequency can
    move with the glide without the cost of a per-sample FFT.
    """
    n = len(x)
    fc = np.clip(sweep(f0, f1, n / SR, curve), 20.0, SR * 0.45)
    coeff = 2.0 * np.sin(np.pi * fc / SR)
    damp = 1.0 / q
    low = 0.0
    band = 0.0
    out = np.empty(n)
    for i in range(n):
        high = x[i] - low - damp * band
        band += coeff[i] * high
        low += coeff[i] * band
        out[i] = band
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def fit(x, dur):
    """Trim or pad a clip to an exact length."""
    n = int(round(dur * SR))
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def finalise(x, dur):
    """Fade the tail, drop the leading silence, normalise the peak."""
    x = fit(x, dur)
    tail = min(len(x) - 1, int(round(0.05 * SR)))
    if tail > 4:
        ramp = np.linspace(1.0, 0.0, tail)
        x[-tail:] *= ramp
    x = fade_edges(x, 3.0)
    peak = float(np.max(np.abs(x))) if len(x) else 0.0
    if peak > 1e-6:
        x = x * (PEAK / peak)
    return x


# --- The clips ----------------------------------------------------------------
# Each entry returns (samples, duration). `v` is the variant index, used to
# nudge the timbre so repeated plays never sound machine-stamped.

def clip_swing(v):
    """Melee arc: a soft band of air sweeping up and away."""
    dur = 0.30
    n = noise(dur, 11 + v)
    centre = sweep(520 + 60 * v, 2100 + 120 * v, dur)
    body = moving_band(n, 520 + 60 * v, 2100 + 120 * v, 0.7)
    body *= env_ad(dur, 0.012, 0.10)
    low_wind = low(moving_band(n, 180, 900, 0.8), 900) * 0.35
    low_wind *= env_ad(dur, 0.02, 0.09)
    del centre
    return mix(body, low_wind), dur


def clip_dodge(v):
    """Dodge: a short bright rush of air, lighter than the swing."""
    dur = 0.24
    n = noise(dur, 23 + v)
    body = moving_band(n, 900 + 80 * v, 3600, 0.8)
    body *= env_ad(dur, 0.008, 0.07)
    air = high(n, 2400) * 0.25 * env_ad(dur, 0.005, 0.05)
    return mix(body, air), dur


def clip_boom(v):
    """Splash: a low body thump with a burst of grit on top."""
    dur = 0.55
    body = sine(sweep(150 + 10 * v, 42, dur, 0.55), dur)
    body *= env_ad(dur, 0.004, 0.20)
    grit = low(noise(dur, 31 + v), 1400) * 0.7
    grit *= env_ad(dur, 0.002, 0.07)
    crack = high(noise(dur, 37 + v), 3000) * 0.25
    crack *= env_ad(dur, 0.001, 0.02)
    out = mix(body * 1.0, grit, crack)
    return np.tanh(out * 1.5) / 1.3, dur


def clip_charge(v):
    """Gap-closer launch: air rushing in as the tank leaps."""
    dur = 0.38
    n = noise(dur, 41 + v)
    body = moving_band(n, 320, 1700, 0.85)
    body *= env_ad(dur, 0.10, 0.12, 0.06)
    rise = sine(sweep(200, 520, dur, 0.8), dur) * 0.35
    rise *= env_ad(dur, 0.09, 0.12, 0.05)
    return mix(body * 0.9, rise), dur


def clip_charge_land(v):
    """The slam that ends the leap: a hard landing on stone."""
    dur = 0.50
    body = sine(sweep(120, 38, dur, 0.5), dur)
    body *= env_ad(dur, 0.003, 0.22)
    floor = low(noise(dur, 53 + v), 900) * 0.85
    floor *= env_ad(dur, 0.001, 0.09)
    tick = high(noise(dur, 59 + v), 2500) * 0.2
    tick *= env_ad(dur, 0.001, 0.015)
    out = mix(body, floor, tick)
    return np.tanh(out * 1.4) / 1.2, dur


def clip_cleave(v):
    """The cleave arc: a ring of steel left behind by a wide swing."""
    dur = 0.40
    parts = []
    for k, f in enumerate([780.0, 1490.0, 2310.0, 3170.0]):
        tone = sine(f * (1.0 + 0.02 * v), dur)
        tone *= env_ad(dur, 0.002, 0.16 - 0.02 * k)
        parts.append(tone * (0.5 / (1.0 + k)))
    ring = mix(*parts)
    n = noise(dur, 67 + v)
    shing = moving_band(n, 3200, 700, 0.7) * 0.5
    shing *= env_ad(dur, 0.004, 0.09)
    return mix(ring, shing), dur


def clip_gear_drop(v):
    """A gear piece hitting the ground: a small metallic clatter."""
    dur = 0.45
    parts = []
    for k, f in enumerate([2050.0, 3120.0, 4580.0]):
        tone = sine(f * (1.0 + 0.015 * v), dur)
        tone *= env_ad(dur, 0.001, 0.13 - 0.03 * k)
        parts.append(tone * (0.45 / (1.0 + k)))
    ring = mix(*parts)
    tick = high(noise(dur, 71 + v), 3200) * 0.35
    tick *= env_ad(dur, 0.001, 0.02)
    body = sine(sweep(105, 78, dur, 0.6), dur) * 0.5
    body *= env_ad(dur, 0.002, 0.07)
    return mix(ring, tick, body), dur


def clip_goblin_escape(v):
    """The treasure goblin slipping away: a comic downward yelp."""
    dur = 0.40
    wob = 1.0 + 0.06 * np.sin(2.0 * np.pi * 22.0 * t_of(dur))
    tone = square(sweep(880 + 40 * v, 300, dur, 0.8) * wob, dur)
    tone *= env_ad(dur, 0.008, 0.13)
    puff = high(noise(dur, 83 + v), 2200) * 0.2
    puff *= env_ad(dur, 0.02, 0.10)
    return mix(tone * 0.8, puff), dur


def clip_enemy_windup(v):
    """The tell before a ranged shot: a low note pulling upward."""
    dur = 0.35
    tone = sine(sweep(300 + 20 * v, 880, dur, 0.7), dur)
    tone *= env_ad(dur, 0.06, 0.10, 0.04)
    trem = 1.0 + 0.25 * np.sin(2.0 * np.pi * 17.0 * t_of(dur))
    tone *= trem
    air = high(noise(dur, 91 + v), 2600) * 0.12
    air *= env_ad(dur, 0.05, 0.10)
    return mix(tone * 0.7, air), dur


def clip_skill_fx(v):
    """A skill landing: a small arcane chime with a shimmer on top."""
    dur = 0.32
    carrier = 880.0 * (1.0 + 0.03 * v)
    tone = sine(carrier, dur)
    tone *= env_ad(dur, 0.002, 0.12)
    upper = sine(carrier * 1.5, dur) * 0.4
    upper *= env_ad(dur, 0.002, 0.08)
    shimmer = moving_band(noise(dur, 97 + v), 2400, 5200, 0.7) * 0.18
    shimmer *= env_ad(dur, 0.01, 0.09)
    return mix(tone, upper, shimmer), dur


def clip_xp_gain(v):
    """Training tick: a very small high pip."""
    dur = 0.14
    tone = sine(1400 + 60 * v, dur)
    tone *= env_ad(dur, 0.002, 0.05)
    return tone * 0.8, dur


def clip_skill_level(v):
    """A skill levelling: two quick notes, a fifth apart."""
    dur = 0.36
    a = sine(700 + 20 * v, 0.14)
    a *= env_ad(0.14, 0.002, 0.05)
    b = sine(1050 + 30 * v, 0.20)
    b *= env_ad(0.20, 0.002, 0.08)
    b = np.concatenate([np.zeros(int(round(0.11 * SR))), b])
    tone = mix(a, b)
    upper = sine(1400, dur) * 0.12
    upper *= env_ad(dur, 0.10, 0.08)
    return mix(tone * 0.8, upper), dur


def clip_banner(v):
    """An announcement in the run: a short brass stab."""
    dur = 0.55
    parts = []
    for f in [196.0, 196.0 * 1.006, 294.0]:
        tone = saw(f * (1.0 + 0.01 * v), dur, 10)
        tone *= env_ad(dur, 0.05, 0.20, 0.06)
        parts.append(tone)
    stab = mix(*parts)
    stab = low(stab, 2600)
    air = moving_band(noise(dur, 101 + v), 900, 2400, 0.7) * 0.12
    air *= env_ad(dur, 0.05, 0.16)
    return mix(stab * 0.5, air), dur


def clip_buff_end(v):
    """A shrine buff fading: a soft note letting go."""
    dur = 0.45
    tone = sine(sweep(700, 380, dur, 0.7), dur)
    tone *= env_ad(dur, 0.02, 0.16)
    air = high(noise(dur, 103 + v), 1800) * 0.1
    air *= env_ad(dur, 0.03, 0.14)
    return mix(tone * 0.7, air), dur


def clip_gear_equip(v):
    """A piece snapping onto the hero: a bright metal clank."""
    dur = 0.30
    parts = []
    for k, f in enumerate([2620.0, 3910.0, 5230.0]):
        tone = sine(f * (1.0 + 0.012 * v), dur)
        tone *= env_ad(dur, 0.001, 0.10 - 0.02 * k)
        parts.append(tone * (0.4 / (1.0 + k)))
    tick = high(noise(dur, 107 + v), 3400) * 0.3
    tick *= env_ad(dur, 0.001, 0.015)
    return mix(mix(*parts), tick), dur


def clip_gear_unequip(v):
    """A piece coming off: a soft release."""
    dur = 0.22
    body = sine(sweep(230, 165, dur, 0.7), dur)
    body *= env_ad(dur, 0.003, 0.07)
    tick = band(noise(dur, 109 + v), 900, 2600) * 0.2
    tick *= env_ad(dur, 0.001, 0.02)
    return mix(body * 0.8, tick), dur


def clip_hunt_start(v):
    """The hunt opening: a low horn swelling up."""
    dur = 1.30
    parts = []
    for f in [110.0, 110.0 * 1.004, 165.0]:
        tone = saw(f * (1.0 + 0.005 * v), dur, 14)
        tone *= env_ad(dur, 0.28, 0.30, 0.20)
        parts.append(tone)
    horn = low(mix(*parts), 2200)
    wind = moving_band(noise(dur, 113 + v), 400, 1900, 0.8) * 0.16
    wind *= env_ad(dur, 0.30, 0.35, 0.10)
    return mix(horn * 0.55, wind), dur


def clip_chest_ready(v):
    """A chest finished unlocking: a soft rising chime."""
    dur = 0.85
    a = sine(880 + 20 * v, 0.30)
    a *= env_ad(0.30, 0.003, 0.12)
    b = sine(1320 + 30 * v, 0.45)
    b *= env_ad(0.45, 0.003, 0.18)
    b = np.concatenate([np.zeros(int(round(0.18 * SR))), b])
    bell = sine(2640, dur) * 0.1
    bell *= env_ad(dur, 0.20, 0.16)
    return mix(mix(a, b) * 0.8, bell), dur


def clip_music_stab(v):
    """A short chord for the music-volume slider: it previews the bus."""
    dur = 1.20
    parts = []
    for f in [220.0, 261.63, 329.63, 440.0]:
        tone = saw(f * (1.0 + 0.004 * v), dur, 10)
        tone *= env_ad(dur, 0.10, 0.35, 0.20)
        parts.append(tone * 0.3)
    chord = low(mix(*parts), 3000)
    return chord * 0.5, dur


def clip_cast(v):
    """A hero's cast telegraph: a charge rising under the spell."""
    dur = 0.42
    base = 300.0 * (1.0 + 0.04 * v)
    tone = saw(sweep(base, base * 2.6, dur, 0.6), dur, 8)
    tone *= env_ad(dur, 0.10, 0.14, 0.06)
    shimmer = moving_band(noise(dur, 131 + v), 1800, 4200, 0.7) * 0.15
    shimmer *= env_ad(dur, 0.12, 0.12, 0.04)
    return mix(tone * 0.55, shimmer), dur


def clip_impact(v):
    """Where a hit lands: a short whump with a bright edge on it."""
    dur = 0.22
    body = sine(sweep(190 - 10 * v, 70, dur, 0.5), dur)
    body *= env_ad(dur, 0.002, 0.07)
    edge = high(noise(dur, 137 + v), 3200) * 0.5
    edge *= env_ad(dur, 0.001, 0.02)
    return mix(body * 0.8, edge), dur


def clip_block(v):
    """A guarded hit: a dull knock on wood and steel, no bite."""
    dur = 0.26
    body = sine(sweep(150 - 8 * v, 96, dur, 0.6), dur)
    body *= env_ad(dur, 0.002, 0.10)
    knock = band(noise(dur, 139 + v), 300, 1600) * 0.55
    knock *= env_ad(dur, 0.001, 0.05)
    return mix(body * 0.9, knock), dur


def clip_shield_break(v):
    """A ward shattering: a crack and a spray of bright shards."""
    dur = 0.55
    crack = high(noise(dur, 149 + v), 2400) * 0.9
    crack *= env_ad(dur, 0.001, 0.05)
    ring = sine(sweep(1500 + 60 * v, 620, dur, 0.7), dur) * 0.45
    ring *= env_ad(dur, 0.002, 0.16)
    shards = high(noise(dur, 151 + v), 4200) * 0.25
    shards *= env_ad(dur, 0.02, 0.20)
    return mix(crack, ring, shards), dur


def clip_gear_pickup(v):
    """A piece lifted off the ground: a light clink that rises."""
    dur = 0.30
    parts = []
    for k, f in enumerate([1560.0, 2340.0, 3120.0]):
        tone = sine(f * (1.0 + 0.01 * v), dur)
        tone *= env_ad(dur, 0.001, 0.09 - 0.02 * k)
        parts.append(tone * (0.4 / (1.0 + k)))
    ring = mix(*parts)
    lift = sine(sweep(700, 1400, dur, 0.7), dur) * 0.25
    lift *= env_ad(dur, 0.01, 0.09)
    return mix(ring, lift), dur


def clip_aggro(v):
    """A foe noticing the hero: a low growl with a wobble in it."""
    dur = 0.55
    wob = 1.0 + 0.05 * np.sin(2.0 * np.pi * 15.0 * t_of(dur))
    tone = saw(sweep(120 + 8 * v, 95, dur, 0.8) * wob, dur, 7)
    tone *= env_ad(dur, 0.06, 0.20, 0.08)
    rasp = band(noise(dur, 157 + v), 200, 900) * 0.35
    rasp *= env_ad(dur, 0.05, 0.22, 0.08)
    return mix(low(tone, 900) * 0.8, rasp), dur


def clip_lifesteal(v):
    """Life drained off a foe: a short sip going up."""
    dur = 0.42
    body = sine(sweep(280 + 20 * v, 760, dur, 0.7), dur)
    body *= env_ad(dur, 0.03, 0.14, 0.04)
    suck = moving_band(noise(dur, 163 + v), 700, 2600, 0.75) * 0.4
    suck *= env_ad(dur, 0.03, 0.15, 0.05)
    return mix(body * 0.6, suck), dur


def clip_blink(v):
    """A blink: the air tears away, then a pop where the hero lands."""
    dur = 0.36
    tear = moving_band(noise(dur, 167 + v), 2200, 500, 0.7) * 0.55
    tear *= env_ad(dur, 0.005, 0.10)
    pop = sine(sweep(900 + 40 * v, 260, dur, 0.5), dur) * 0.45
    pop *= env_ad(dur, 0.12, 0.06)
    return mix(tear, pop), dur


def clip_chain(v):
    """Chain lightning: a zap and a run of crackles after it."""
    dur = 0.45
    zap = high(noise(dur, 173 + v), 2600) * 0.8
    zap *= env_ad(dur, 0.001, 0.04)
    crackle = np.zeros(int(round(dur * SR)))
    for i in range(7):
        at = int((0.05 + 0.055 * i) * SR)
        tick = high(noise(0.05, 191 + v * 13 + i), 3400)
        tick *= env_ad(0.05, 0.001, 0.02)
        end = min(len(crackle), at + len(tick))
        crackle[at:end] += tick[:end - at] * 0.5
    tone = sine(sweep(1400 + 60 * v, 420, dur, 0.6), dur) * 0.35
    tone *= env_ad(dur, 0.002, 0.12)
    return mix(zap, crackle, tone), dur


def clip_frost(v):
    """Frost nova: glassy bells spreading out and then cooling."""
    dur = 0.60
    parts = []
    for k, f in enumerate([1760.0, 2637.0, 3520.0]):
        tone = sine(f * (1.0 + 0.01 * v), dur)
        tone *= env_ad(dur, 0.005, 0.22 - 0.05 * k, 0.05)
        parts.append(tone * (0.35 / (1.0 + k)))
    bells = mix(*parts)
    hiss = high(noise(dur, 197 + v), 5200) * 0.16
    hiss *= env_ad(dur, 0.01, 0.30)
    fall = sine(sweep(2400, 1200, dur, 0.8), dur) * 0.2
    fall *= env_ad(dur, 0.05, 0.25)
    return mix(bells, hiss, fall), dur


def clip_quake(v):
    """Earthquake: the ground rolls and then settles."""
    dur = 0.75
    rumble = low(noise(dur, 199 + v), 220) * 1.1
    rumble *= env_ad(dur, 0.03, 0.35, 0.10)
    crack = band(noise(dur, 211 + v), 120, 900) * 0.5
    crack *= env_ad(dur, 0.01, 0.25)
    thud = sine(sweep(90, 45, dur, 0.6), dur) * 0.8
    thud *= env_ad(dur, 0.005, 0.20)
    return np.tanh(mix(rumble, crack, thud) * 1.2) / 1.15, dur


def clip_volley(v):
    """A volley: a few arrows arriving in a flurry."""
    dur = 0.45
    out = np.zeros(int(round(dur * SR)))
    for i in range(4):
        at = int((0.02 + 0.075 * i) * SR)
        f = 620 + 55 * i + 25 * v
        thump = sine(sweep(f, f * 0.55, 0.16, 0.5), 0.16)
        thump *= env_ad(0.16, 0.002, 0.06)
        flap = high(noise(0.10, 223 + v * 11 + i), 2600) * 0.3
        flap *= env_ad(0.10, 0.002, 0.04)
        piece = mix(thump * 0.8, flap)
        end = min(len(out), at + len(piece))
        out[at:end] += piece[:end - at]
    return out, dur


def clip_roar(v):
    """A taunt: a chesty growl that swells and falls away."""
    dur = 0.80
    wob = 1.0 + 0.07 * np.sin(2.0 * np.pi * 11.0 * t_of(dur))
    tone = saw(sweep(105 + 6 * v, 76, dur, 0.7) * wob, dur, 9)
    tone *= env_ad(dur, 0.10, 0.30, 0.06)
    rasp = band(noise(dur, 233 + v), 160, 1100) * 0.45
    rasp *= env_ad(dur, 0.08, 0.30, 0.06)
    out = mix(low(tone, 1400) * 0.9, rasp)
    return np.tanh(out * 1.2) / 1.15, dur


def clip_thunder(v):
    """A crown of storm: a crack, then the roll that follows it."""
    dur = 1.10
    crack = high(noise(dur, 239 + v), 2600) * 0.85
    crack *= env_ad(dur, 0.001, 0.05)
    roll = low(noise(dur, 241 + v), 320)
    roll *= env_ad(dur, 0.02, 0.55, 0.05)
    body = sine(sweep(140, 58, dur, 0.6), dur) * 0.55
    body *= env_ad(dur, 0.004, 0.30)
    return mix(crack, roll, body), dur


def clip_phoenix(v):
    """A hero coming back from the fire: a rising whoosh into a burst."""
    dur = 1.00
    whoosh = moving_band(noise(dur, 251 + v), 300, 3200, 0.8) * 0.7
    whoosh *= env_ad(dur, 0.25, 0.35, 0.10)
    body = sine(sweep(180, 720, dur, 0.7), dur) * 0.45
    body *= env_ad(dur, 0.20, 0.35, 0.08)
    flare = high(noise(dur, 257 + v), 4200) * 0.3
    flare *= env_ad(dur, 0.45, 0.25)
    return mix(whoosh, body, flare), dur


def clip_blades(v):
    """Orbiting blades: a ring of steel cutting the air."""
    dur = 0.70
    parts = []
    for k, f in enumerate([1180.0, 1790.0, 2410.0]):
        tone = sine(f * (1.0 + 0.012 * v), dur)
        tone *= env_ad(dur, 0.06, 0.24 - 0.04 * k)
        parts.append(tone * (0.4 / (1.0 + k)))
    ring = mix(*parts)
    swish = moving_band(noise(dur, 263 + v), 2600, 800, 0.8) * 0.45
    swish *= env_ad(dur, 0.05, 0.22)
    return mix(ring, swish), dur


def clip_thorns(v):
    """A thorn aura: a bristle of spines coming up."""
    dur = 0.50
    body = band(noise(dur, 269 + v), 700, 3400) * 0.6
    body *= env_ad(dur, 0.02, 0.18)
    rasp = high(noise(dur, 271 + v), 5200) * 0.25
    rasp *= env_ad(dur, 0.01, 0.10)
    tone = sine(sweep(420, 640, dur, 0.7), dur) * 0.25
    tone *= env_ad(dur, 0.01, 0.14)
    return mix(body, rasp, tone), dur


def clip_static(v):
    """A static field: an electric buzz that rings and dies."""
    dur = 0.65
    buzz = band(noise(dur, 277 + v), 1200, 4200) * 0.6
    buzz *= env_ad(dur, 0.01, 0.26)
    ring = sine(sweep(2400 + 80 * v, 1500, dur, 0.7), dur) * 0.3
    ring *= env_ad(dur, 0.002, 0.18)
    snap = high(noise(dur, 281 + v), 6000) * 0.3
    snap *= env_ad(dur, 0.001, 0.03)
    return mix(buzz, ring, snap), dur


def clip_howl(v):
    """A spirit wolf: a howl that climbs, holds and slides back down."""
    dur = 1.05
    top = 560.0 + 20 * v
    up = sweep(300 + 15 * v, top, 0.40, 0.7)
    hold = np.full(int(round(0.25 * SR)), top)
    down = sweep(top, 240, 0.40, 0.9)
    tone = saw(np.concatenate([up, hold, down]), dur, 12)
    tone *= env_ad(dur, 0.16, 0.30, 0.12)
    air = band(noise(dur, 283 + v), 400, 2000) * 0.22
    air *= env_ad(dur, 0.16, 0.30, 0.10)
    return mix(low(tone, 2200) * 0.8, air), dur


def clip_mark(v):
    """A hunter's mark: a hard whack and a ring on the target."""
    dur = 0.40
    whack = band(noise(dur, 293 + v), 400, 2800) * 0.75
    whack *= env_ad(dur, 0.001, 0.06)
    ring = sine(sweep(1800 + 60 * v, 1200, dur, 0.7), dur) * 0.3
    ring *= env_ad(dur, 0.005, 0.16)
    return mix(whack, ring), dur


def clip_siphon(v):
    """Life pulled off a foe: a low drain that sucks upward."""
    dur = 0.55
    body = sine(sweep(160 + 12 * v, 420, dur, 0.75), dur) * 0.55
    body *= env_ad(dur, 0.06, 0.22, 0.04)
    suck = moving_band(noise(dur, 307 + v), 400, 2200, 0.75) * 0.35
    suck *= env_ad(dur, 0.06, 0.24, 0.05)
    return mix(body, suck), dur


def clip_split(v):
    """A shot splitting: one bolt becomes two."""
    dur = 0.45
    out = np.zeros(int(round(dur * SR)))
    for k, off in enumerate([0.0, 0.06]):
        at = int(off * SR)
        f = 1500 + 120 * k + 40 * v
        bolt = sine(sweep(f, f * 0.45, 0.22, 0.6), 0.22)
        bolt *= env_ad(0.22, 0.001, 0.08)
        crack = high(noise(0.22, 311 + v * 7 + k), 4200) * 0.3
        crack *= env_ad(0.22, 0.001, 0.03)
        piece = mix(bolt * 0.7, crack)
        end = min(len(out), at + len(piece))
        out[at:end] += piece[:end - at]
    return out, dur


def clip_ricochet(v):
    """A shot that bounces: a ping skipping off the ground."""
    dur = 0.55
    out = np.zeros(int(round(dur * SR)))
    for k in range(4):
        at = int((0.02 + 0.10 * k) * SR)
        f = 2100 - 330 * k + 30 * v
        ping = sine(f, 0.16)
        ping *= env_ad(0.16, 0.001, 0.06)
        end = min(len(out), at + len(ping))
        out[at:end] += ping[:end - at] * (0.9 / (1.0 + 0.5 * k))
    return out, dur


def clip_meteor(v):
    """Fire from the sky: a fall of flame and a scorched landing."""
    dur = 0.85
    fall = moving_band(noise(dur, 313 + v), 3600, 700, 0.8) * 0.55
    fall *= env_ad(dur, 0.30, 0.20)
    boom = sine(sweep(120, 45, dur, 0.55), dur) * 0.8
    boom *= env_ad(dur, 0.28, 0.24)
    crackle = band(noise(dur, 317 + v), 800, 4200) * 0.3
    crackle *= env_ad(dur, 0.30, 0.26)
    out = mix(fall, boom, crackle)
    return np.tanh(out * 1.2) / 1.15, dur


def clip_fire_trail(v):
    """A fire trail under the hero: a soft burn ticking over."""
    dur = 0.30
    hiss = band(noise(dur, 337 + v), 400, 2600) * 0.55
    hiss *= env_ad(dur, 0.02, 0.12)
    body = sine(sweep(90 + 6 * v, 62, dur, 0.7), dur) * 0.35
    body *= env_ad(dur, 0.01, 0.10)
    crack = high(noise(dur, 347 + v), 4200) * 0.12
    crack *= env_ad(dur, 0.005, 0.04)
    return mix(hiss, body, crack), dur


def clip_wolf_bite(v):
    """A spectral hound biting: a quick snap with a cold edge on it."""
    dur = 0.22
    snap = high(noise(dur, 353 + v), 2800) * 0.7
    snap *= env_ad(dur, 0.001, 0.045)
    tone = sine(sweep(1300 + 60 * v, 420, dur, 0.6), dur) * 0.3
    tone *= env_ad(dur, 0.001, 0.08)
    return mix(snap, tone), dur


def clip_duel_win(v):
    """A won duel: a short rising fanfare."""
    dur = 1.10
    out = np.zeros(int(round(dur * SR)))
    for k, f in enumerate([392.0, 523.25, 784.0]):
        at = int((0.05 + 0.16 * k) * SR)
        note = saw(f * (1.0 + 0.005 * v), 0.55, 10)
        note *= env_ad(0.55, 0.01, 0.22, 0.06)
        note = low(note, 3200)
        end = min(len(out), at + len(note))
        out[at:end] += note[:end - at] * 0.5
    swell = sine(sweep(196, 392, dur, 0.7), dur) * 0.3
    swell *= env_ad(dur, 0.05, 0.35, 0.10)
    return mix(out, swell), dur


# event -> (clip function, variant count)
SYNTH = {
    "swing": (clip_swing, 2),
    "dodge": (clip_dodge, 2),
    "boom": (clip_boom, 2),
    "charge": (clip_charge, 1),
    "charge_land": (clip_charge_land, 2),
    "cleave": (clip_cleave, 1),
    "gear_drop": (clip_gear_drop, 2),
    "goblin_escape": (clip_goblin_escape, 1),
    "enemy_windup": (clip_enemy_windup, 2),
    "skill_fx": (clip_skill_fx, 2),
    "xp_gain": (clip_xp_gain, 1),
    "skill_level": (clip_skill_level, 1),
    "banner": (clip_banner, 1),
    "buff_end": (clip_buff_end, 1),
    "gear_equip": (clip_gear_equip, 1),
    "gear_unequip": (clip_gear_unequip, 1),
    "hunt_start": (clip_hunt_start, 1),
    "chest_ready": (clip_chest_ready, 1),
    "music_stab": (clip_music_stab, 1),
    "cast": (clip_cast, 2),
    "impact": (clip_impact, 2),
    "block": (clip_block, 2),
    "shield_break": (clip_shield_break, 2),
    "gear_pickup": (clip_gear_pickup, 2),
    "aggro": (clip_aggro, 2),
    "lifesteal": (clip_lifesteal, 1),
    "blink": (clip_blink, 1),
    "chain": (clip_chain, 1),
    "frost": (clip_frost, 1),
    "quake": (clip_quake, 1),
    "volley": (clip_volley, 1),
    "roar": (clip_roar, 1),
    "thunder": (clip_thunder, 1),
    "phoenix": (clip_phoenix, 1),
    "blades": (clip_blades, 1),
    "thorns": (clip_thorns, 1),
    "static": (clip_static, 1),
    "howl": (clip_howl, 1),
    "mark": (clip_mark, 1),
    "siphon": (clip_siphon, 1),
    "split": (clip_split, 1),
    "ricochet": (clip_ricochet, 1),
    "meteor": (clip_meteor, 1),
    "fire_trail": (clip_fire_trail, 1),
    "wolf_bite": (clip_wolf_bite, 1),
    "duel_win": (clip_duel_win, 1),
}

SYNTH_COUNTS = {k: v[1] for k, v in SYNTH.items()}


# --- Writing ------------------------------------------------------------------

# Godot's ResourceUID text form: base 36 over "a-z0-9", 13 characters for a
# 64 bit id. The .import files must carry a uid that does not clash with an
# existing one, or Godot re-imports and rewrites the file on the next build.
UID_ALPHA = "abcdefghijklmnopqrstuvwxyz0123456789"


def _uid_text(value):
    out = ""
    while value:
        value, rem = divmod(value, 36)
        out = UID_ALPHA[rem] + out
    return out


def _used_uids():
    used = set()
    for path in glob.glob(os.path.join(ROOT, "assets/**/*.import"), recursive=True):
        with open(path) as fh:
            for line in fh:
                m = re.search(r'uid="uid://([^"]+)"', line)
                if m:
                    used.add(m.group(1))
    return used


def write_import(path, used_uids):
    """Write the .import sidecar for a freshly rendered clip."""
    rel = "res://" + os.path.relpath(path, ROOT).replace(os.sep, "/")
    digest = hashlib.md5(rel.encode()).hexdigest()
    dest = "res://.godot/imported/%s-%s.oggvorbisstr" % (os.path.basename(path), digest)
    seed = int(digest, 16) & ((1 << 64) - 1)
    uid = None
    for _ in range(64):
        candidate = _uid_text(seed)
        seed = (seed * 6364136223846793005 + 1442695040888963407) % (2 ** 64)
        if candidate and candidate not in used_uids:
            uid = candidate
            break
    if uid is None:
        raise SystemExit("cannot find a free uid for " + rel)
    used_uids.add(uid)
    body = """[remap]

importer="oggvorbisstr"
type="AudioStreamOggVorbis"
uid="uid://%s"
path="%s"

[deps]

source_file="%s"
dest_files=["%s"]

[params]

loop=false
loop_offset=0
bpm=0
beat_count=0
bar_beats=4
""" % (uid, dest, rel, dest)
    with open(path + ".import", "w") as fh:
        fh.write(body)


def write_ogg(path, samples):
    tmp = path + ".wav"
    data = np.clip(samples, -1.0, 1.0)
    pcm = (data * 32767.0).astype("<i2")
    with wave.open(tmp, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(pcm.tobytes())
    subprocess.run([
        "ffmpeg", "-y", "-loglevel", "error", "-i", tmp,
        "-c:a", "libvorbis", "-q:a", "3", path,
    ], check=True)
    os.remove(tmp)


def _own_uid(path):
    """The uid already on disk for this path, if any."""
    try:
        with open(path + ".import") as fh:
            m = re.search(r'uid="uid://([^"]+)"', fh.read())
        return m.group(1) if m else None
    except OSError:
        return None


def render_all(out_dir=OUT, force=False):
    """Render the synthesized clips; returns {event: variant count}.

    Clips that are already on disk are left alone unless force is set: a
    rebuild must not churn the resource uids, because Godot re-imports
    every clip whose uid moved.
    """
    os.makedirs(out_dir, exist_ok=True)
    used = _used_uids()
    counts = {}
    for name in sorted(SYNTH):
        fn, variants = SYNTH[name]
        for k in range(variants):
            path = os.path.join(out_dir, "%s_%d.ogg" % (name, k + 1))
            if not force and os.path.exists(path) and os.path.exists(path + ".import"):
                continue
            samples, dur = fn(k)
            samples = finalise(samples, dur)
            write_ogg(path, samples)
            # The clip's own uid is free again: keeping it means a rebuild
            # lands on the same uid instead of drifting to the next one.
            own = _own_uid(path)
            if own:
                used.discard(own)
            write_import(path, used)
        counts[name] = variants
    return counts


def merge_manifest(counts):
    """Fold the synthesized events into scripts/sfx_manifest.gd."""
    entries = {}
    with open(MANIFEST) as fh:
        text = fh.read()
    for m in re.finditer(r'^\t"([a-z0-9_]+)": (\d+),$', text, re.M):
        entries[m.group(1)] = int(m.group(2))
    entries.update(counts)
    head = text.split("const COUNTS := {")[0]
    with open(MANIFEST, "w") as fh:
        fh.write(head)
        fh.write("const COUNTS := {\n")
        for k in sorted(entries):
            fh.write('\t"%s": %d,\n' % (k, entries[k]))
        fh.write("}\n")
    return entries


if __name__ == "__main__":
    target = OUT
    if "--out" in sys.argv:
        target = sys.argv[sys.argv.index("--out") + 1]
        if not os.path.isabs(target):
            target = os.path.join(ROOT, target)
    counts = render_all(target, force="--force" in sys.argv)
    if target == OUT:
        merge_manifest(counts)
    total = sum(counts.values())
    print("synthesized events", len(counts), "clips", total)
    for k in sorted(counts):
        print("  %-14s %d  %d KB" % (
            k, counts[k],
            sum(os.path.getsize(os.path.join(target, "%s_%d.ogg" % (k, i + 1)))
                for i in range(counts[k])) // 1024))
