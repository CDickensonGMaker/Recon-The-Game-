"""audio_dsp.py - Minimal numpy DSP core for procedural weapon audio.

No scipy. Everything here is either vectorized numpy or a tight per-sample IIR
loop (fine at 48kHz for sub-second one-shots).

Physical model of a gunshot at the shooter's ear, in layers:

  1. MUZZLE BLAST  - propellant gas venting into free air. A Friedlander wave:
                     near-instant rise (~0.1-0.5 ms), positive overpressure
                     phase, then a negative phase. Broadband. Spectral centroid
                     drops as powder charge and bore grow.
  2. BODY / THUMP  - the low-frequency component you feel. Decaying sine at
                     f_low, set by charge mass and bore.
  3. BALLISTIC CRACK - the bullet's own N-wave. Only exists if supersonic.
                     ~200-400 microseconds, very high frequency. Dominates for
                     rounds passing NEAR you; barely audible at the shooter's
                     own ear (the blast swamps it).
  4. MECHANICAL    - bolt/carrier reciprocating, spring twang, brass ejecting.
                     Resonant metallic transients, offset a few ms to tens of ms.
  5. TAIL          - the environment answering back. Synthesized decaying-noise
                     impulse response, lowpassed (jungle eats highs).

Saturation is applied because real blasts overdrive both the ear and any mic
that ever recorded one; a clean sum sounds thin and synthetic.
"""

from __future__ import annotations

import math
import struct
import wave

import numpy as np

SR = 48000


# --------------------------------------------------------------------------
# filters (RBJ audio EQ cookbook biquads)
# --------------------------------------------------------------------------


def _biquad(x: np.ndarray, b: tuple[float, float, float], a: tuple[float, float, float]) -> np.ndarray:
    """Direct-form I biquad. a[0] assumed already normalized to 1.0."""
    b0, b1, b2 = b
    a1, a2 = a[1], a[2]
    y = np.empty_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(x.shape[0]):
        xi = x[i]
        yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        y[i] = yi
        x2, x1 = x1, xi
        y2, y1 = y1, yi
    return y


def _rbj(kind: str, freq: float, q: float, sr: int = SR):
    freq = max(20.0, min(freq, sr * 0.45))
    w0 = 2.0 * math.pi * freq / sr
    cos_w0, sin_w0 = math.cos(w0), math.sin(w0)
    alpha = sin_w0 / (2.0 * q)

    if kind == "lp":
        b = ((1 - cos_w0) / 2, 1 - cos_w0, (1 - cos_w0) / 2)
        a = (1 + alpha, -2 * cos_w0, 1 - alpha)
    elif kind == "hp":
        b = ((1 + cos_w0) / 2, -(1 + cos_w0), (1 + cos_w0) / 2)
        a = (1 + alpha, -2 * cos_w0, 1 - alpha)
    elif kind == "bp":  # constant skirt gain, peak = Q
        b = (sin_w0 / 2, 0.0, -sin_w0 / 2)
        a = (1 + alpha, -2 * cos_w0, 1 - alpha)
    else:
        raise ValueError(kind)

    a0 = a[0]
    return (b[0] / a0, b[1] / a0, b[2] / a0), (1.0, a[1] / a0, a[2] / a0)


def lowpass(x: np.ndarray, freq: float, q: float = 0.707, passes: int = 1) -> np.ndarray:
    b, a = _rbj("lp", freq, q)
    for _ in range(passes):
        x = _biquad(x, b, a)
    return x


def highpass(x: np.ndarray, freq: float, q: float = 0.707, passes: int = 1) -> np.ndarray:
    b, a = _rbj("hp", freq, q)
    for _ in range(passes):
        x = _biquad(x, b, a)
    return x


def bandpass(x: np.ndarray, freq: float, q: float = 2.0) -> np.ndarray:
    b, a = _rbj("bp", freq, q)
    return _biquad(x, b, a)


# --------------------------------------------------------------------------
# primitives
# --------------------------------------------------------------------------


def _t(n: int) -> np.ndarray:
    return np.arange(n, dtype=np.float64) / SR


def noise(n: int, rng: np.random.Generator) -> np.ndarray:
    return rng.uniform(-1.0, 1.0, n)


def expdecay(n: int, tau: float, rise: float = 0.0002) -> np.ndarray:
    """Fast-attack, exponential-release envelope."""
    t = _t(n)
    env = np.exp(-t / max(tau, 1e-6))
    if rise > 0:
        nr = max(1, int(rise * SR))
        env[:nr] *= np.linspace(0.0, 1.0, nr) ** 0.5
    return env


def friedlander(n: int, tau: float, rise: float = 0.00015) -> np.ndarray:
    """Friedlander blast waveform: p(t) = (1 - t/tau) * exp(-t/tau).

    Positive overpressure spike followed by a negative underpressure phase --
    the reason a real blast has that 'pushed then pulled' quality rather than
    just being a click.
    """
    t = _t(n)
    w = (1.0 - t / tau) * np.exp(-t / tau)
    nr = max(1, int(rise * SR))
    w[:nr] *= np.linspace(0.0, 1.0, nr) ** 2
    return w


def n_wave(n: int, width_s: float) -> np.ndarray:
    """Ballistic crack: the bullet's shock cone. Classic N-shape --
    up-spike, linear ramp down through zero, down-spike, snap back."""
    out = np.zeros(n)
    w = max(2, int(width_s * SR))
    seg = np.linspace(1.0, -1.0, w)
    out[:w] = seg
    return out


def saturate(x: np.ndarray, drive: float = 1.0) -> np.ndarray:
    return np.tanh(x * drive) / math.tanh(drive) if drive > 0 else x


def normalize(x: np.ndarray, peak: float = 0.95) -> np.ndarray:
    m = float(np.max(np.abs(x))) if x.size else 0.0
    return x * (peak / m) if m > 1e-9 else x


def fade_out(x: np.ndarray, ms: float = 6.0) -> np.ndarray:
    n = min(len(x), max(1, int(ms * 0.001 * SR)))
    x = x.copy()
    x[-n:] *= np.linspace(1.0, 0.0, n)
    return x


def pad_to(x: np.ndarray, n: int) -> np.ndarray:
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def mix(*layers: np.ndarray) -> np.ndarray:
    n = max(len(x) for x in layers)
    out = np.zeros(n)
    for x in layers:
        out += pad_to(x, n)
    return out


def place(dest: np.ndarray, src: np.ndarray, at_s: float, gain: float = 1.0) -> np.ndarray:
    """Sum `src` into `dest` starting at `at_s` seconds. Clips at the end."""
    i = int(at_s * SR)
    if i >= len(dest):
        return dest
    j = min(len(dest), i + len(src))
    dest[i:j] += src[: j - i] * gain
    return dest


# --------------------------------------------------------------------------
# reverb tail (synthesized impulse response, convolved via FFT)
# --------------------------------------------------------------------------


def env_ir(seconds: float, rng: np.random.Generator, decay: float, damp_hz: float,
           predelay: float = 0.008, density: float = 1.0) -> np.ndarray:
    """A cheap but convincing environment IR: exponentially-decaying noise,
    lowpassed (air + foliage absorb highs), with a pre-delay gap.

    jungle  -> short decay, heavy damping, high density (leaves everywhere)
    open AO -> longer decay, less damping, sparse early reflections (slapback)
    """
    n = int(seconds * SR)
    ir = noise(n, rng) * np.exp(-_t(n) * (1.0 / max(decay, 1e-3)))
    if density < 1.0:
        keep = rng.random(n) < density
        ir *= keep
    ir = lowpass(ir, damp_hz, passes=2)
    pd = int(predelay * SR)
    ir = np.concatenate([np.zeros(pd), ir])[:n]
    ir[0] += 1.0  # direct path
    return ir


def convolve(x: np.ndarray, ir: np.ndarray) -> np.ndarray:
    n = len(x) + len(ir) - 1
    nfft = 1 << (n - 1).bit_length()
    y = np.fft.irfft(np.fft.rfft(x, nfft) * np.fft.rfft(ir, nfft), nfft)[:n]
    return y


# --------------------------------------------------------------------------
# air / distance
# --------------------------------------------------------------------------


def air_absorb(x: np.ndarray, meters: float) -> np.ndarray:
    """High frequencies die with distance. Crude but the right shape:
    a rifle at 400m is a *thump*, not a crack."""
    if meters <= 1.0:
        return x
    cutoff = 18000.0 * math.exp(-meters / 260.0) + 380.0
    return lowpass(x, cutoff, passes=2)


# --------------------------------------------------------------------------
# wav io
# --------------------------------------------------------------------------


def write_wav(path: str, x: np.ndarray, sr: int = SR) -> None:
    x = np.clip(x, -1.0, 1.0)
    pcm = (x * 32767.0).astype("<i2")
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())
