"""gen_aircraft_audio.py - aircraft and heavy-ordnance voices for RECONgame.

    python tools/gen_aircraft_audio.py --report   # spectral stats, writes nothing
    python tools/gen_aircraft_audio.py --write

Everything here is physically keyed, because the instrument IS the identity:

  UH-1 "Huey"   2-blade main rotor at 324 rpm -> 5.4 Hz shaft, 10.8 Hz blade
                passage. The famous whop is BLADE-VORTEX INTERACTION: a sharp
                impulsive slap once per blade passage, NOT an amplitude-modulated
                drone. Modelling it as a tremolo sine is why most games get a
                lawnmower. Tail rotor 2 blades at ~1660 rpm -> ~55 Hz.
  C-130 Spectre 4x Allison T56, prop 1020 rpm, 4 blades -> 68 Hz blade passage,
                plus turbine whine well above it. Reads as a heavy drone, not a
                helicopter -- the gunship currently borrows rotor_loop.wav.
  F-4 / A-1     turbojet: broadband roar shaped by a wide resonance, with a
                compressor whine that rises with throttle. No blade passage.

Loops are cut to an integer number of blade-passage periods so the seam closes
on the physics rather than on a crossfade.
"""

from __future__ import annotations

import hashlib
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import audio_dsp as D  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT_AIR = os.path.join(ROOT, "assets", "audio", "sfx", "aircraft")
OUT_W = os.path.join(ROOT, "assets", "audio", "sfx", "weapons")


def _seed(*parts) -> int:
    return int(hashlib.md5("|".join(str(p) for p in parts).encode()).hexdigest()[:8], 16)


def _loop_len(period_s: float, target_s: float) -> int:
    """Whole number of periods nearest the target, so the loop closes on phase."""
    cycles = max(1, int(round(target_s / period_s)))
    return int(round(cycles * period_s * D.SR))


def _snap(f: float, f0: float, even: bool = False) -> float:
    """Snap a frequency to a harmonic of the loop fundamental. Every partial must
    complete a whole number of cycles inside the loop or the seam clicks --
    closing only the blade passage is not enough, because the shaft turns at half
    blade rate and its sine would land mid-cycle."""
    k = max(1, int(round(f / f0)))
    if even and k % 2:
        k += 1
    return k * f0


def _periodic_noise(n: int, rng, cutoff_hz: float, slope: float = 2.0) -> np.ndarray:
    """Noise that loops. Built in the frequency domain with random phase, so it
    is periodic in n BY CONSTRUCTION. A time-domain noise layer put through a
    biquad can never close a loop -- its first and last samples are unrelated,
    and that alone clicks no matter how well the tonal partials are snapped."""
    m = n // 2 + 1
    f = np.fft.rfftfreq(n, 1.0 / D.SR)
    mag = 1.0 / (1.0 + (f / max(cutoff_hz, 1.0)) ** slope)
    mag[0] = 0.0
    phase = rng.uniform(0.0, 2.0 * np.pi, m)
    x = np.fft.irfft(mag * np.exp(1j * phase), n)
    return x / (np.abs(x).max() + 1e-12)


def _dc(x: np.ndarray) -> np.ndarray:
    """An impulsive layer whose impulses are one-sided carries a DC offset, which
    steals headroom and thumps a speaker on start/stop."""
    return x - x.mean()


# --------------------------------------------------------------------------


def heli_rotor_loop(blade_hz: float = 10.8, target_s: float = 3.0) -> np.ndarray:
    """Huey main+tail rotor. Impulsive slap per blade passage over a low drone."""
    rng = np.random.default_rng(_seed("heli", blade_hz))
    n = int(round(target_s * D.SR))
    f0 = D.SR / float(n)
    # Even multiple: the shaft turns at half blade rate and must close too.
    blade_hz = _snap(blade_hz, f0, even=True)
    shaft = blade_hz / 2.0
    period = 1.0 / blade_hz
    t = np.arange(n) / D.SR
    out = np.zeros(n)

    # BVI slap: a short asymmetric impulse. This is the whop. It carries mid
    # energy as well as low -- a purely sub slap disappears on a laptop speaker
    # and leaves a 34 Hz rumble nobody can localise.
    slap_n = int(0.055 * D.SR)
    slap = D.noise(slap_n, rng) * D.expdecay(slap_n, 0.012, rise=0.0009)
    slap = D.lowpass(slap, 900.0, q=0.9, passes=2)
    slap += D.bandpass(D.noise(slap_n, rng) * D.expdecay(slap_n, 0.008), 1500.0, q=1.4) * 0.55
    slap += np.sin(2.0 * np.pi * 46.0 * np.arange(slap_n) / D.SR) * \
        D.expdecay(slap_n, 0.030, rise=0.0015) * 0.75

    k = 0
    while k * period < n / D.SR:
        # Alternating blades are never perfectly matched: the 2-per-rev wobble.
        gain = 1.0 if k % 2 == 0 else 0.86
        i = int(round(k * period * D.SR))
        if i >= n:
            break
        if i + slap_n <= n:
            out[i:i + slap_n] += slap * gain
        else:  # wrap, so the loop's own slap continues across the seam
            tail = n - i
            out[i:] += slap[:tail] * gain
            out[:slap_n - tail] += slap[tail:] * gain
        k += 1

    drone = np.zeros(n)
    for h, amp in ((1, 0.16), (2, 0.13), (3, 0.10), (5, 0.05)):
        drone += np.sin(2.0 * np.pi * _snap(shaft * h, f0) * t) * amp
    tail_r = (np.sin(2.0 * np.pi * _snap(55.3, f0) * t) * 0.14
              + np.sin(2.0 * np.pi * _snap(110.6, f0) * t) * 0.07)
    whine = (np.sin(2.0 * np.pi * _snap(1180.0, f0) * t) * 0.045
             + np.sin(2.0 * np.pi * _snap(2360.0, f0) * t) * 0.018)
    wash = _periodic_noise(n, rng, 2200.0) * 0.30

    mix = out * 0.85 + drone + tail_r + whine + wash
    mix = D.saturate(mix, 1.25)
    return D.normalize(_dc(mix), 0.88)


def prop_loop(blade_hz: float = 68.0, target_s: float = 2.0) -> np.ndarray:
    """C-130 turboprop bank: dense blade passage + turbine whine. A DRONE."""
    rng = np.random.default_rng(_seed("prop", blade_hz))
    n = int(round(target_s * D.SR))
    f0 = D.SR / float(n)
    blade_hz = _snap(blade_hz, f0)
    t = np.arange(n) / D.SR
    out = np.zeros(n)
    for h, amp in ((1, 0.55), (2, 0.34), (3, 0.20), (4, 0.12), (6, 0.06)):
        out += np.sin(2.0 * np.pi * _snap(blade_hz * h, f0) * t) * amp
    # Four engines slightly out of sync -> the characteristic beating. Each
    # detune still has to close, so it snaps to a neighbouring harmonic.
    for det in (0.994, 1.006, 1.011):
        out += np.sin(2.0 * np.pi * _snap(blade_hz * det, f0) * t) * 0.22
    whine = (np.sin(2.0 * np.pi * _snap(2100.0, f0) * t) * 0.05
             + np.sin(2.0 * np.pi * _snap(4200.0, f0) * t) * 0.02)
    air = _periodic_noise(n, rng, 2600.0) * 0.26
    mix = D.saturate(out * 0.55 + whine + air, 1.2)
    return D.normalize(_dc(mix), 0.86)


def jet_loop(target_s: float = 2.0) -> np.ndarray:
    """Turbojet: broadband roar, wide resonance, compressor whine on top."""
    rng = np.random.default_rng(_seed("jet", 1))
    n = int(round(target_s * D.SR))
    f0 = D.SR / float(n)
    t = np.arange(n) / D.SR
    roar = _periodic_noise(n, rng, 1500.0)
    roar += _periodic_noise(n, rng, 320.0, slope=1.2) * 0.9
    whine = np.zeros(n)
    for f, a in ((3200.0, 0.055), (6400.0, 0.022), (9600.0, 0.010)):
        whine += np.sin(2.0 * np.pi * _snap(f, f0) * t) * a
    mix = D.saturate(roar * 0.8 + whine, 1.5)
    return D.normalize(_dc(mix), 0.90)


def bofors_40mm() -> np.ndarray:
    """Spectre's 40mm Bofors: a heavy, hollow THUMP, slower than the Vulcan."""
    rng = np.random.default_rng(_seed("bofors", 1))
    n = int(0.9 * D.SR)
    front = D.highpass(D.friedlander(n, 0.0022), 45.0)
    gas = D.noise(n, rng) * D.expdecay(n, 0.030, rise=0.0004)
    gas = D.lowpass(gas, 2400.0, q=0.8, passes=2)
    t = np.arange(n) / D.SR
    sweep = 96.0 * (0.75 + 0.6 * np.exp(-t / 0.045))
    body = np.sin(2.0 * np.pi * np.cumsum(sweep) / D.SR) * D.expdecay(n, 0.085, rise=0.001) * 0.8
    core = D.saturate(front * 0.9 + gas * 1.1 + body, 2.0)
    ir = D.env_ir(2.2, rng, 0.52, 5200.0, 0.022, 0.35)
    return D.fade_out(D.normalize(core + D.convolve(core, ir)[:n] * 0.25, 0.93), 25.0)


def vulcan_burst() -> np.ndarray:
    """20mm gatling: individual reports fuse into the BRRRT. 6000 rpm = 100/s."""
    rng = np.random.default_rng(_seed("vulcan", 1))
    dur = 1.2
    n = int(dur * D.SR)
    out = np.zeros(n)
    shot_n = int(0.030 * D.SR)
    shot = D.noise(shot_n, rng) * D.expdecay(shot_n, 0.0045, rise=0.00012)
    shot = D.lowpass(shot, 4200.0, q=0.8)
    shot += np.sin(2.0 * np.pi * 210.0 * np.arange(shot_n) / D.SR) * \
        D.expdecay(shot_n, 0.008) * 0.5
    step = 1.0 / 100.0
    k = 0
    while k * step < dur:
        i = int(k * step * D.SR)
        if i + shot_n <= n:
            out[i:i + shot_n] += shot * rng.uniform(0.85, 1.0)
        k += 1
    ir = D.env_ir(2.2, rng, 0.52, 5200.0, 0.022, 0.35)
    out = D.saturate(out, 1.6)
    return D.fade_out(D.normalize(_dc(out + D.convolve(out, ir)[:n] * 0.30), 0.92), 30.0)


def cannon_20mm(variant: int) -> np.ndarray:
    """Single 20mm report from an airframe. The strafe gun fires these in threes;
    it had no render at all and fell through to the rifle class bank."""
    rng = np.random.default_rng(_seed("20mm", variant))
    n = int(0.55 * D.SR)
    front = D.highpass(D.friedlander(n, 0.0013 * rng.uniform(0.93, 1.08)), 50.0)
    gas = D.noise(n, rng) * D.expdecay(n, 0.016, rise=0.00025)
    gas = D.lowpass(gas, 3800.0 * rng.uniform(0.92, 1.09), q=0.8)
    gas = D.highpass(gas, 200.0)
    t = np.arange(n) / D.SR
    body = np.sin(2.0 * np.pi * 175.0 * (1.0 + 0.35 * np.exp(-t / 0.010)) * t) *         D.expdecay(n, 0.020, rise=0.0007) * 0.40
    core = D.saturate(front * 0.95 + gas * 1.3 + body, 1.9)
    ir = D.env_ir(2.2, rng, 0.52, 5200.0, 0.022, 0.35)
    return D.fade_out(D.normalize(_dc(core + D.convolve(core, ir)[:n] * 0.20), 0.92), 10.0)


def mortar_tube() -> np.ndarray:
    """The launch: a hollow, wet THOOMP from a steel tube. Not a bang."""
    rng = np.random.default_rng(_seed("mortar_tube", 1))
    n = int(1.1 * D.SR)
    t = np.arange(n) / D.SR
    sweep = 130.0 * (1.0 + 0.9 * np.exp(-t / 0.030))
    body = np.sin(2.0 * np.pi * np.cumsum(sweep) / D.SR) * D.expdecay(n, 0.055, rise=0.0016)
    gas = D.noise(n, rng) * D.expdecay(n, 0.020, rise=0.0009)
    gas = D.lowpass(gas, 1500.0, q=0.9, passes=2)
    ring = D.bandpass(D.noise(n, rng) * D.expdecay(n, 0.055), 520.0, q=9.0) * 0.35
    core = D.saturate(body * 1.1 + gas * 0.85 + ring, 1.5)
    ir = D.env_ir(0.90, rng, 0.16, 2600.0, 0.006, 1.0)
    return D.fade_out(D.normalize(core + D.convolve(core, ir)[:n] * 0.30, 0.90), 30.0)


def shell_incoming() -> np.ndarray:
    """The whistle. Falling pitch + rising level: the shell is coming to YOU.
    Deliberately long -- this is the warning that buys the player his hole."""
    rng = np.random.default_rng(_seed("incoming", 1))
    dur = 2.6
    n = int(dur * D.SR)
    t = np.arange(n) / D.SR
    # Descending glide, accelerating at the end.
    f = 1250.0 * np.exp(-t / 1.5) + 190.0
    ph = 2.0 * np.pi * np.cumsum(f) / D.SR
    tone = np.sin(ph) * 0.55 + np.sin(2.0 * ph) * 0.18 + np.sin(3.0 * ph) * 0.07
    air = D.bandpass(D.noise(n, rng), 1700.0, q=0.8) * 0.30
    swell = (t / dur) ** 2.1
    out = (tone + air) * swell
    out[: int(0.05 * D.SR)] *= np.linspace(0.0, 1.0, int(0.05 * D.SR))
    return D.normalize(out, 0.85)


def shotgun_shot(variant: int) -> np.ndarray:
    """12ga buckshot: broad, dark, no supersonic crack. The shotgun currently
    fires a rifle sample through the class-bank fallback."""
    rng = np.random.default_rng(_seed("shotgun", variant))
    n = int(0.75 * D.SR)
    front = D.highpass(D.friedlander(n, 0.0011 * rng.uniform(0.94, 1.07)), 50.0)
    gas = D.noise(n, rng) * D.expdecay(n, 0.020, rise=0.0003)
    gas = D.lowpass(gas, 3400.0 * rng.uniform(0.92, 1.09), q=0.8)
    gas = D.highpass(gas, 180.0)
    t = np.arange(n) / D.SR
    body = np.sin(2.0 * np.pi * 150.0 * (1.0 + 0.3 * np.exp(-t / 0.012)) * t) * \
        D.expdecay(n, 0.022, rise=0.0008) * 0.45
    core = D.saturate(front * 0.95 + gas * 1.25 + body, 1.7)
    ir = D.env_ir(0.90, rng, 0.16, 2600.0, 0.006, 1.0)
    return D.fade_out(D.normalize(core + D.convolve(core, ir)[:n] * 0.22, 0.92), 10.0)


# --------------------------------------------------------------------------

SPECS = {
    "aircraft": [
        ("heli_rotor_loop.wav", lambda: heli_rotor_loop(), True),
        ("prop_loop.wav", lambda: prop_loop(), True),
        ("jet_loop.wav", lambda: jet_loop(), True),
        ("bofors_40mm.wav", bofors_40mm, False),
        ("vulcan_burst.wav", vulcan_burst, False),
    ],
    "weapons": [
        ("mortar_tube.wav", mortar_tube, False),
        ("shell_incoming.wav", shell_incoming, False),
        ("fire_shotgun_1.wav", lambda: shotgun_shot(1), False),
        ("fire_shotgun_2.wav", lambda: shotgun_shot(2), False),
        ("fire_shotgun_3.wav", lambda: shotgun_shot(3), False),
        ("fire_aircraft_20mm_1.wav", lambda: cannon_20mm(1), False),
        ("fire_aircraft_20mm_2.wav", lambda: cannon_20mm(2), False),
        ("fire_aircraft_20mm_3.wav", lambda: cannon_20mm(3), False),
    ],
}


def _stats(name: str, x: np.ndarray, loop: bool) -> None:
    X = np.abs(np.fft.rfft(x * np.hanning(len(x))))
    f = np.fft.rfftfreq(len(x), 1.0 / D.SR)
    p = X ** 2
    tot = p.sum()
    seam = abs(float(x[0] - x[-1])) if loop else 0.0
    steps = np.abs(np.diff(x))
    seam_ok = "n/a" if not loop else ("SEAMLESS" if seam <= np.percentile(steps, 99) else "CLICK")
    print(f"  {name:22s} {len(x)/D.SR:5.2f}s  centroid {float((f*p).sum()/tot):6.0f}Hz  "
          f"peak {np.abs(x).max():.2f}  DC {x.mean():+.5f}  seam {seam_ok}")


def main() -> None:
    write = "--write" in sys.argv
    for subdir, items in SPECS.items():
        outdir = OUT_AIR if subdir == "aircraft" else OUT_W
        print(f"[{subdir}]")
        for name, fn, loop in items:
            x = fn()
            _stats(name, x, loop)
            if not write:
                continue
            os.makedirs(outdir, exist_ok=True)
            disk = os.path.join(outdir, name)
            D.write_wav(disk, x)
            from gen_weapon_audio import write_import
            res = f"res://assets/audio/sfx/{'aircraft' if subdir == 'aircraft' else 'weapons'}/{name}"
            write_import(res, disk, loop=loop)
    if not write:
        print("\ndry run - pass --write to emit")


if __name__ == "__main__":
    main()
