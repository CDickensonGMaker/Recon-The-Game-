"""Breath audio for the hold-breath lockout.

Pure stdlib: writes a 16-bit mono WAV with no numpy, no scipy, and no dependency on
gen_weapon_audio.py -- that generator has overwritten real recordings before, so this one is
deliberately separate and only ever writes NEW files under assets/audio/sfx/player/.

A breath is broadband noise shaped by an envelope and a soft low-pass. What makes it read as a
BREATH rather than as static is the two-part gesture: the held air leaving in a rush, a beat of
nothing, then a ragged pull back in. One burst alone sounds like a hiss.

Run:  python tools/gen_breath_audio.py
"""
import math
import os
import random
import struct
import wave

SR = 44100
OUT_DIR = os.path.join("assets", "audio", "sfx", "player")


def one_pole_lowpass(samples, cutoff_hz):
    """Single-pole IIR. Breath has almost no energy above ~2 kHz; unfiltered noise reads as hiss."""
    dt = 1.0 / SR
    rc = 1.0 / (2.0 * math.pi * cutoff_hz)
    a = dt / (rc + dt)
    out = []
    prev = 0.0
    for s in samples:
        prev += a * (s - prev)
        out.append(prev)
    return out


def one_pole_highpass(samples, cutoff_hz):
    """Strips the DC/rumble a raw noise burst carries, which otherwise thumps the speaker."""
    dt = 1.0 / SR
    rc = 1.0 / (2.0 * math.pi * cutoff_hz)
    a = rc / (rc + dt)
    out = []
    prev_in = 0.0
    prev_out = 0.0
    for s in samples:
        prev_out = a * (prev_out + s - prev_in)
        prev_in = s
        out.append(prev_out)
    return out


def burst(dur_s, attack_s, cutoff_hz, peak, rng, jitter=0.0):
    """One breath gesture: noise under an attack/decay envelope.

    `jitter` slowly modulates the amplitude, which is what makes an inhale sound unsteady
    instead of like a fan. A perfectly smooth envelope is the tell that it is synthetic.
    """
    n = int(dur_s * SR)
    atk = max(1, int(attack_s * SR))
    raw = [rng.uniform(-1.0, 1.0) for _ in range(n)]
    shaped = one_pole_lowpass(raw, cutoff_hz)
    shaped = one_pole_highpass(shaped, 120.0)
    # Normalise before enveloping: the filters cost a lot of level and it varies with cutoff.
    m = max(1e-9, max(abs(s) for s in shaped))
    shaped = [s / m for s in shaped]
    out = []
    for i, s in enumerate(shaped):
        if i < atk:
            env = i / atk
        else:
            t = (i - atk) / max(1, n - atk)
            env = math.pow(1.0 - t, 1.6)
        if jitter > 0.0:
            env *= 1.0 - jitter * 0.5 * (1.0 + math.sin(i / SR * 2.0 * math.pi * 7.3))
        out.append(s * env * peak)
    return out


def silence(dur_s):
    return [0.0] * int(dur_s * SR)


def write_wav(path, samples):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    if peak > 1.0:
        samples = [s / peak for s in samples]
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32000)) for s in samples)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)
    print("wrote %s  (%.2fs)" % (path, len(samples) / SR))


def main():
    # Seeded: the same file every run, so a re-generate is not a silent asset change (ADR-010).
    rng = random.Random(0x8EEA7)
    # The hold breaking: air out fast and low, a beat, then a ragged pull back in.
    out_rush = burst(0.34, 0.012, 1500.0, 1.0, rng)
    gap = silence(0.07)
    pull_in = burst(0.46, 0.10, 2100.0, 0.62, rng, jitter=0.35)
    tail = silence(0.05)
    write_wav(os.path.join(OUT_DIR, "breath_break.wav"), out_rush + gap + pull_in + tail)
    # The intake as the hold STARTS. Not wired yet - offered so the gesture can bookend.
    rng2 = random.Random(0x1E5)
    write_wav(os.path.join(OUT_DIR, "breath_hold.wav"),
              burst(0.28, 0.05, 1800.0, 0.55, rng2) + silence(0.04))


if __name__ == "__main__":
    main()
