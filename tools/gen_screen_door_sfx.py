"""gen_screen_door_sfx.py - synthesise the screen door's creak and slap.

There is no recorded door foley in assets/audio/sfx, and a screen door on a spring is
almost entirely two sounds: a rusty stick-slip whine while the leaf swings, and a light
wood-on-frame slap when the spring takes it back. Both are cheap to synthesise honestly
and neither wants a licence.

Run: python tools/gen_screen_door_sfx.py
Writes assets/audio/sfx/door_screen_creak.wav and door_screen_slap.wav (mono 44.1k 16-bit).
"""
import math
import os
import struct
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")


def _write(name, sig):
    """Normalise to -3 dBFS and write 16-bit mono."""
    peak = float(np.max(np.abs(sig))) or 1.0
    sig = (sig / peak) * 0.707
    pcm = (np.clip(sig, -1.0, 1.0) * 32767.0).astype(np.int16)
    path = os.path.abspath(os.path.join(OUT, name))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("wrote %s (%.2f s, %d KB)" % (path, len(sig) / SR,
                                        os.path.getsize(path) // 1024))


def _resonator(x, freq, q):
    """One-pole-pair bandpass. A hinge is a resonance, not a tone."""
    w = 2.0 * math.pi * freq / SR
    r = math.exp(-w / (2.0 * q))
    a1 = -2.0 * r * math.cos(w)
    a2 = r * r
    y = np.zeros_like(x)
    for i in range(2, len(x)):
        y[i] = x[i] - x[i - 2] - a1 * y[i - 1] - a2 * y[i - 2]
    return y


def creak(dur=1.10):
    """STICK-SLIP, not a tone. Dry metal does not glide - it catches, releases, catches,
    and the release rate falls as the leaf slows. That irregular rate IS the creak; a
    smooth vibrato reads as a cartoon ghost."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    rng = np.random.default_rng(7)

    # Slip events thin out as the swing decays.
    rate = np.linspace(90.0, 26.0, n)
    phase = np.cumsum(rate) / SR
    slip = (np.abs(((phase % 1.0) - 0.5)) * 2.0) ** 3.0

    # Each slip drags the hinge frequency; the drag is what makes it sound rusty.
    drag = 320.0 + 180.0 * slip + rng.normal(0.0, 26.0, n)
    exciter = rng.normal(0.0, 1.0, n) * slip

    body = np.zeros(n)
    for f, q, g in ((520.0, 26.0, 1.0), (1180.0, 34.0, 0.55), (2350.0, 40.0, 0.22)):
        body += _resonator(exciter, f, q) * g
    body *= (drag / drag.max())

    env = np.exp(-t * 2.6) * np.minimum(1.0, t / 0.045)
    return body * env


def slap(dur=0.34):
    """Wood on a wooden frame, plus the spring's own ring-off. Short, and it must not
    sound like a gunshot - the transient stays soft and the body decays fast."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    rng = np.random.default_rng(11)

    hit = rng.normal(0.0, 1.0, n) * np.exp(-t * 130.0)
    body = np.zeros(n)
    for f, q, g in ((168.0, 12.0, 1.0), (430.0, 16.0, 0.6), (900.0, 20.0, 0.28)):
        body += _resonator(hit, f, q) * g

    # The spring: a brief high partial that outlives the knock.
    spring = np.sin(2.0 * math.pi * 2100.0 * t) * np.exp(-t * 16.0) * 0.10
    spring *= np.minimum(1.0, t / 0.004)
    return body * np.exp(-t * 11.0) + spring


if __name__ == "__main__":
    os.makedirs(os.path.abspath(OUT), exist_ok=True)
    _write("door_screen_creak.wav", creak())
    _write("door_screen_slap.wav", slap())
