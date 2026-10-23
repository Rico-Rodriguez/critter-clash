"""Synthesise the combat contact and power-up clips.

The hunt used to go quiet in the middle of a fight: a skeleton taking a hit,
an arrow sinking in, the Barbarian's spin, an orbiting blade nicking a foe and
the fire powers had no sound of their own. These are drawn from scratch with
the helpers in build_sfx_synth.py (no sampled source, no third-party licence),
mono 44.1 kHz OGG peak-normalised to -1 dBFS like the rest of the folder.

Clips already on disk are kept unless --force is passed. Godot writes the
.import sidecars on the next import (tools/dev/check.sh does one).

usage: python3 tools/audio/build_sfx_combat.py [--force]
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_sfx_synth import (  # noqa: E402
    SR, band, clip_goblin_escape, env_ad, finalise, high, low, mix,
    moving_band, noise, sine, sweep, t_of, write_ogg,
)

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets/audio/sfx")


def crackle(dur, seed, rate, lo=1500, hi=6000):
    """Sparse random clicks, band-limited: burning wood, splintering bone."""
    rng = np.random.default_rng(seed)
    n = int(round(dur * SR))
    x = np.zeros(n)
    hits = rng.random(n) < rate / SR
    x[hits] = rng.uniform(-1.0, 1.0, hits.sum())
    return band(x, lo, hi) * 6.0


def clip_contact(v):
    """A foe taking a hit: a dull knock in the body and a crack of bone."""
    dur = 0.22
    knock = sine(sweep(210 + 25 * v, 85, dur, 0.5), dur) * env_ad(dur, 0.001, 0.05)
    thud = low(noise(dur, 401 + v), 1100) * 0.9 * env_ad(dur, 0.001, 0.035)
    crack = band(noise(dur, 409 + v), 1800 + 300 * v, 5200) * 0.5 * env_ad(dur, 0.0005, 0.012)
    splinter = crackle(dur, 419 + v, 260, 2200, 7000) * 0.25 * env_ad(dur, 0.004, 0.06)
    out = mix(knock, thud, crack, splinter)
    return np.tanh(out * 1.6) / 1.3, dur


def clip_pierce(v):
    """An arrow sinking in: a short thunk and a tick of the shaft."""
    dur = 0.18
    thunk = sine(sweep(320 + 30 * v, 140, dur, 0.5), dur) * env_ad(dur, 0.001, 0.035)
    tick = band(noise(dur, 431 + v), 2500, 6500) * 0.45 * env_ad(dur, 0.0005, 0.008)
    quiver = sine(1150 + 90 * v, dur) * 0.12 * env_ad(dur, 0.002, 0.06) * (1.0 + 0.5 * np.sin(2 * np.pi * 70 * t_of(dur)))
    return mix(thunk, tick, quiver), dur


def clip_fire_hit(v):
    """Fire bursting on a foe: a soft whump and a sizzle that dies away."""
    dur = 0.45
    whump = sine(sweep(140 + 15 * v, 55, dur, 0.5), dur) * 0.8 * env_ad(dur, 0.002, 0.10)
    roar = low(noise(dur, 443 + v), 1800) * 0.7 * env_ad(dur, 0.004, 0.08)
    sizzle = band(noise(dur, 449 + v), 3000, 9000) * 0.25 * env_ad(dur, 0.01, 0.22)
    pops = crackle(dur, 457 + v, 90) * 0.35 * env_ad(dur, 0.02, 0.25)
    out = mix(whump, roar, sizzle, pops)
    return np.tanh(out * 1.4) / 1.2, dur


def clip_firebolt(v):
    """A fire bolt spat out: a short fwoosh that rises and flutters."""
    dur = 0.32
    n = noise(dur, 461 + v)
    body = moving_band(n, 300 + 40 * v, 1900, 0.7, q=0.9) * env_ad(dur, 0.01, 0.13)
    flutter = 1.0 + 0.35 * np.sin(2 * np.pi * (34 + 4 * v) * t_of(dur))
    pops = crackle(dur, 467 + v, 140) * 0.25 * env_ad(dur, 0.02, 0.12)
    return mix(body * flutter, pops), dur


def clip_nova(v):
    """Fire Nova: a deep whoomph, a wall of flame rolling out, crackling."""
    dur = 0.95
    whoomph = sine(sweep(95, 38, dur, 0.5), dur) * env_ad(dur, 0.01, 0.30)
    roll = moving_band(noise(dur, 479 + v), 250, 1400, 0.6, q=0.8) * 0.8 * env_ad(dur, 0.03, 0.40)
    sizzle = band(noise(dur, 487 + v), 2500, 8000) * 0.18 * env_ad(dur, 0.08, 0.45)
    pops = crackle(dur, 491 + v, 70) * 0.4 * env_ad(dur, 0.06, 0.55)
    out = mix(whoomph, roll, sizzle, pops)
    return np.tanh(out * 1.3) / 1.15, dur


def clip_whirl(v):
    """One turn of the Barbarian's spin: the blade passing close by."""
    dur = 0.26
    n = noise(dur, 503 + v)
    # Up then down: the edge comes round toward you and away again.
    up = moving_band(n, 380 + 50 * v, 1500, 0.8)
    t = t_of(dur)
    shape = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 2
    hum = sine(sweep(150 + 15 * v, 110, dur), dur) * 0.25 * shape
    return mix(up * shape, hum), dur


def clip_dash(v):
    """A dash: a heavier rush of air than the dodge, with a scuff of feet."""
    dur = 0.30
    n = noise(dur, 521 + v)
    rush = moving_band(n, 500 + 60 * v, 2600, 0.6) * env_ad(dur, 0.01, 0.12)
    scuff = low(noise(dur, 529 + v), 700) * 0.5 * env_ad(dur, 0.002, 0.04)
    return mix(rush, scuff), dur


def clip_blade_hit(v):
    """A spectral blade nicking a foe: a bright glassy ting."""
    dur = 0.30
    parts = []
    for k, f in enumerate([2350.0, 3520.0, 5240.0]):
        parts.append(sine(f * (1.0 + 0.03 * v), dur) * env_ad(dur, 0.001, 0.12 - 0.03 * k) * (0.5 / (1 + k)))
    tick = high(noise(dur, 541 + v), 4000) * 0.3 * env_ad(dur, 0.0005, 0.006)
    return mix(*parts, tick), dur


def clip_wave(v):
    """A sword wave let loose: a whistling slice of air."""
    dur = 0.36
    n = noise(dur, 557 + v)
    slice_ = moving_band(n, 2800, 900, 0.7, q=2.5) * env_ad(dur, 0.005, 0.14)
    whistle = sine(sweep(1900, 1200, dur), dur) * 0.2 * env_ad(dur, 0.01, 0.12)
    return mix(slice_, whistle), dur


COMBAT = {
    "contact": (clip_contact, 3),
    "pierce": (clip_pierce, 2),
    "fire_hit": (clip_fire_hit, 2),
    "firebolt": (clip_firebolt, 2),
    "nova": (clip_nova, 1),
    "whirl": (clip_whirl, 3),
    "dash": (clip_dash, 2),
    "blade_hit": (clip_blade_hit, 2),
    "wave": (clip_wave, 2),
    "goblin_escape": (clip_goblin_escape, 1),
}


if __name__ == "__main__":
    force = "--force" in sys.argv
    for name in sorted(COMBAT):
        fn, variants = COMBAT[name]
        for k in range(variants):
            path = os.path.join(OUT, "%s_%d.ogg" % (name, k + 1))
            if os.path.exists(path) and not force:
                continue
            samples, dur = fn(k)
            write_ogg(path, finalise(samples, dur))
            print("wrote", os.path.relpath(path), os.path.getsize(path) // 1024, "KB")
