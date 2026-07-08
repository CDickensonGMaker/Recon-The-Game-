"""gen_weapon_audio.py - Procedural weapon audio for RECONgame.

    python tools/gen_weapon_audio.py            # all weapons + explosions
    python tools/gen_weapon_audio.py ak47 m60   # just these
    python tools/gen_weapon_audio.py --report   # print spectral stats, write nothing

Writes to assets/audio/sfx/weapons/ and assets/audio/sfx/explosions/, plus the
Godot .import sidecars so the files are usable without opening the editor.

Per weapon:
    fire_<id>_1..3.wav   near report, 3 genuinely different renders (round-robin)
    fire_<id>_dist.wav   distant report: air-absorbed, tail-dominant
    mech_<id>.wav        action layer (bolt clatter / slide / belt links)
    bolt_<id>.wav        bolt-action cycle, bolt guns only
    reload_<id>.wav      composite: mag out, mag in, charge

Design intent lives in weapon_voices.py. This file is just the renderer.
"""

from __future__ import annotations

import hashlib
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import audio_dsp as D  # noqa: E402
from weapon_voices import ENVIRONMENTS, EXPLOSIONS, WEAPONS, params  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT_W = os.path.join(ROOT, "assets", "audio", "sfx", "weapons")
OUT_X = os.path.join(ROOT, "assets", "audio", "sfx", "explosions")

BOLT_GUNS = {"kar98k", "mosin"}
ROCKETS = {"rpg2", "rpg7", "m72_law"}


# --------------------------------------------------------------------------
# layer renderers
# --------------------------------------------------------------------------


def _ir(kind: str, rng, scale: float = 1.0) -> np.ndarray:
    secs, decay, damp, predelay, density = ENVIRONMENTS[kind]
    return D.env_ir(secs * scale, rng, decay * scale, damp, predelay, density)


def muzzle_blast(p: dict, rng, n: int) -> np.ndarray:
    """Layer 1+2: propellant gas leaving the muzzle, and the body under it.

    Balance note, learned the hard way: the broadband GAS layer must dominate.
    A real gunshot's spectral centroid at the shooter's ear sits around
    1.5-3 kHz. If the low-frequency body sine or the Friedlander front carries
    most of the energy you get a kick-drum, not a rifle. The front is a
    *transient*, not a bass note -- it contributes almost no sustained energy.
    """
    # Shock front. tau here is the POSITIVE-PHASE DURATION: ~0.2-0.5 ms for
    # small arms. Its own spectrum is low, so we highpass out the infrasonic
    # lobe that no speaker reproduces and that only eats headroom.
    front = D.friedlander(n, p["blast_tau"])
    front = D.highpass(front, 55.0)

    # Turbulent gas jet: the actual body of the sound, and it must DOMINATE the
    # RMS or the report collapses into a kick-drum. Its lowpass cutoff is the
    # weapon's `brightness`, so this layer is where the M16-vs-AK timbre lives.
    gas = D.noise(n, rng) * D.expdecay(n, p["blast_tau"] * 22.0, rise=0.00012)
    gas = D.lowpass(gas, p["brightness"], q=0.8)
    gas = D.highpass(gas, 220.0)

    # The "bark": woody mid resonance of the bore + gas column.
    bark_src = D.noise(n, rng) * D.expdecay(n, p["blast_tau"] * 14.0, rise=0.0001)
    bark = D.bandpass(bark_src, p["bark_hz"], q=1.6) * 0.9

    # Body/thump: FELT, not heard. A short low undertone, deliberately kept well
    # below the gas RMS -- when it rivals the gas, centroid crashes to ~250 Hz
    # and every weapon becomes a bass drum. 13 ms, low gain.
    t = np.arange(n) / D.SR
    sweep = p["f_low"] * (1.0 + 0.35 * np.exp(-t / 0.010))
    phase = 2.0 * np.pi * np.cumsum(sweep) / D.SR
    body = np.sin(phase) * D.expdecay(n, 0.013, rise=0.0006) * 0.12

    # Saturate the gas/bark core only. Saturating the front flattens the
    # transient, and the transient is the entire perception of "weight".
    core = D.saturate(gas * 1.35 + bark, p["drive"])
    return front * 1.05 + core + body


def ballistic_crack(p: dict, rng, n: int) -> np.ndarray:
    """Layer 3: the bullet's shock cone. Absent for subsonic rounds."""
    amt = p.get("crack", 0.0)
    if amt <= 0.0:
        return np.zeros(n)
    # N-wave duration scales inversely with velocity: faster round, tighter snap.
    width = 0.00042 * (900.0 / max(p["mv_ms"], 200.0))
    w = D.n_wave(n, width) * amt
    w = D.highpass(w, 1800.0, q=0.8)
    # A supersonic round's crack rides slightly AHEAD of the muzzle report at
    # the shooter's ear (it leaves first). 0.4ms is enough to read as "sharp".
    return w


def mech_layer(p: dict, rng, n: int, jitter: float = 1.0) -> np.ndarray:
    """Layer 4: metal on metal. Resonant transients, not clicks."""
    m = p["mech"]
    out = np.zeros(n)
    for k in range(m["n"]):
        # Each strike is a burst of noise rung through a resonator.
        ln = int(D.SR * (m["ring"] * 4.0))
        strike = D.noise(ln, rng) * D.expdecay(ln, m["ring"], rise=0.00008)
        rung = np.zeros(ln)
        for f in m["freqs"]:
            rung += D.bandpass(strike, f * rng.uniform(0.94, 1.06), q=7.0)
        rung = D.normalize(rung, 1.0)
        at = m["delay"] * jitter + k * m["ring"] * rng.uniform(1.6, 2.8)
        out = D.place(out, rung, at, m["level"] * rng.uniform(0.7, 1.0) / (1 + 0.4 * k))
    return out


def rocket_hiss(p: dict, rng, n: int) -> np.ndarray:
    """Recoilless backblast / sustainer motor: a roar, not a bang."""
    amt = p.get("rocket_hiss", 0.0)
    if amt <= 0.0:
        return np.zeros(n)
    h = D.noise(n, rng) * D.expdecay(n, 0.16, rise=0.004)
    h = D.lowpass(h, 3600.0, passes=2)
    h = D.highpass(h, 220.0)
    return h * amt


# --------------------------------------------------------------------------
# composites
# --------------------------------------------------------------------------


def render_near(wid: str, variant: int) -> np.ndarray:
    p = params(wid)
    rng = np.random.default_rng(_seed(wid, "near", variant))
    n = int(D.SR * 0.75)

    # Per-variant physical jitter: powder burns differently every round. This is
    # what makes 3 renders sound like 3 shots rather than one shot pitch-shifted.
    p = dict(p)
    p["f_low"] *= rng.uniform(0.96, 1.05)
    p["brightness"] *= rng.uniform(0.93, 1.08)
    p["blast_tau"] *= rng.uniform(0.94, 1.07)

    blast = muzzle_blast(p, rng, n)
    crack = ballistic_crack(p, rng, n)
    mech = mech_layer(p, rng, n, jitter=rng.uniform(0.85, 1.2))
    hiss = rocket_hiss(p, rng, n)

    # The crack is the sharp bright edge on a supersonic report. It carries most
    # of the >4kHz energy and, per the acoustics research, the entire
    # position-dependent M16-vs-AK brightness distinction. It is a receiver-side
    # event even at the shooter's ear (it leaves with the bullet), so it rides
    # a hair ahead. Subsonic rounds (.45 ACP, 9mm ball) get none -- correctly dark.
    dry = D.mix(blast, crack * 2.6, mech, hiss)

    # The room answers. Wet is low at the shooter's ear -- you are inside the
    # direct sound, not the reverb.
    kind, wet = p["tail"]
    ir = _ir(kind, rng, scale=0.7)
    wetsig = D.convolve(dry, ir)[: len(dry)]
    out = dry + wetsig * (wet * 0.22)

    # No second saturation pass here: it would squash the transient we just
    # spent the whole function protecting.
    return D.fade_out(D.normalize(out, 0.92), 8.0)


def render_distant(wid: str) -> np.ndarray:
    """What the gun sounds like from >85m: the crack arrives, then the thump,
    then the valley hands it back to you."""
    p = params(wid)
    rng = np.random.default_rng(_seed(wid, "dist", 0))
    n = int(D.SR * 1.6)

    blast = muzzle_blast(p, rng, int(D.SR * 0.5))
    blast = D.air_absorb(blast, 220.0)
    blast = D.pad_to(blast, n)

    out = np.zeros(n)
    # Supersonic round: you hear the CRACK first (it travels with the bullet),
    # then the muzzle THUMP catches up. This gap is the single most recognizable
    # fact about being shot at, and no game ships it often enough.
    if p.get("crack", 0.0) > 0.0:
        c = ballistic_crack(p, rng, int(D.SR * 0.05))
        c = D.lowpass(c, 7000.0)  # even the crack loses its top over distance
        out = D.place(out, c, 0.0, 0.85)
        out = D.place(out, blast, 0.055, 0.75)
    else:
        out = D.place(out, blast, 0.0, 0.8)

    kind, wet = p["tail"]
    ir = _ir(kind, rng, scale=1.6)
    wetsig = D.convolve(out, ir)[:n]
    # At range the TAIL is most of what you hear. Invert the near-field mix.
    out = out * 0.42 + wetsig * (0.55 + wet * 0.35)
    out = D.lowpass(out, 3800.0)
    return D.fade_out(D.normalize(out, 0.80), 40.0)


def render_mech(wid: str) -> np.ndarray:
    p = params(wid)
    rng = np.random.default_rng(_seed(wid, "mech", 0))
    n = int(D.SR * 0.30)
    out = mech_layer(p, rng, n)
    return D.fade_out(D.normalize(out, 0.70), 6.0)


def render_bolt(wid: str) -> np.ndarray:
    """A bolt cycle is four events: lift, pull (extract + eject), push, turn-down."""
    p = params(wid)
    rng = np.random.default_rng(_seed(wid, "bolt", 0))
    n = int(D.SR * 1.5)
    out = np.zeros(n)
    m = p["mech"]

    def clack(freqs, ring, level, at, noisy=0.0):
        ln = int(D.SR * ring * 5.0)
        s = D.noise(ln, rng) * D.expdecay(ln, ring, rise=0.0001)
        r = np.zeros(ln)
        for f in freqs:
            r += D.bandpass(s, f * rng.uniform(0.95, 1.05), q=8.0)
        if noisy > 0.0:
            r += D.lowpass(D.noise(ln, rng) * D.expdecay(ln, ring * 2.5), 3000.0) * noisy
        return D.place(out, D.normalize(r, 1.0), at, level)

    out = clack(m["freqs"], 0.014, 0.55, 0.00)                     # handle lift
    out = clack([f * 0.8 for f in m["freqs"]], 0.030, 0.75, 0.10, noisy=0.35)  # pull back
    out = clack([2600, 4200, 5800], 0.020, 0.40, 0.24)             # brass ejects, tings
    out = clack([f * 0.9 for f in m["freqs"]], 0.022, 0.70, 0.46, noisy=0.25)  # push forward
    out = clack(m["freqs"], 0.012, 0.60, 0.62)                     # lock down

    return D.fade_out(D.normalize(out, 0.75), 10.0)


def render_reload(wid: str) -> np.ndarray:
    """Composite: mag release, mag out, fresh mag seated, action charged.
    Timings are spread across ~2s; Godot plays it as one stream over reload_time."""
    p = params(wid)
    rng = np.random.default_rng(_seed(wid, "reload", 0))
    n = int(D.SR * 2.4)
    out = np.zeros(n)
    m = p["mech"]

    def part(freqs, ring, level, at, noisy=0.0, q=7.0):
        ln = int(D.SR * ring * 5.0)
        s = D.noise(ln, rng) * D.expdecay(ln, ring, rise=0.0001)
        r = np.zeros(ln)
        for f in freqs:
            r += D.bandpass(s, f * rng.uniform(0.95, 1.05), q=q)
        if noisy > 0.0:
            r += D.lowpass(D.noise(ln, rng) * D.expdecay(ln, ring * 2.0), 2600.0) * noisy
        return D.place(out, D.normalize(r, 1.0), at, level)

    out = part([2200, 3600], 0.006, 0.35, 0.05)                    # mag catch
    out = part([700, 1200], 0.035, 0.45, 0.16, noisy=0.5)          # mag drops free
    out = part([f * 1.1 for f in m["freqs"]], 0.010, 0.30, 0.62)   # fresh mag touches
    out = part([f * 0.85 for f in m["freqs"]], 0.028, 0.80, 0.92, noisy=0.3)  # SEATED. thunk.
    out = part([1400, 2400, 3800], 0.030, 0.65, 1.35, noisy=0.4)   # charge back
    out = part([f * 0.9 for f in m["freqs"]], 0.020, 0.70, 1.55)   # bolt slams home

    return D.fade_out(D.normalize(out, 0.72), 12.0)


def render_explosion(xid: str) -> np.ndarray:
    p = EXPLOSIONS[xid]
    rng = np.random.default_rng(_seed(xid, "expl", 0))
    n = int(D.SR * 2.8)

    # Detonation front.
    front = D.friedlander(n, p["blast_tau"])
    gas = D.noise(n, rng) * D.expdecay(n, p["blast_tau"] * 4.0, rise=0.0004)
    gas = D.lowpass(gas, p["brightness"], q=0.8)

    # Sub-bass rumble: the pressure wave in the ground and in your chest.
    t = np.arange(n) / D.SR
    sweep = p["f_low"] * (1.0 + 0.6 * np.exp(-t / 0.06))
    phase = 2.0 * np.pi * np.cumsum(sweep) / D.SR
    rumble = np.sin(phase) * D.expdecay(n, 0.22, rise=0.002) * p["rumble"]

    core = D.saturate(front * 0.9 + gas * 0.8 + rumble * 0.9, p["drive"])

    # Debris / fragmentation: the hiss and patter AFTER the bang. This is the
    # layer that sells "grenade" over "movie explosion".
    deb = np.zeros(n)
    for _ in range(int(70 * p["debris"])):
        at = rng.uniform(0.03, 0.9) ** 1.4
        ln = int(D.SR * rng.uniform(0.004, 0.02))
        tick = D.noise(ln, rng) * D.expdecay(ln, 0.003)
        tick = D.bandpass(tick, rng.uniform(1500, 7000), q=3.0)
        deb = D.place(deb, tick, at, rng.uniform(0.05, 0.28))
    hiss = D.noise(n, rng) * D.expdecay(n, 0.30, rise=0.006)
    hiss = D.bandpass(hiss, 3200.0, q=0.7) * 0.22 * p["debris"]

    dry = core + deb * p["debris"] + hiss

    kind, wet = p["tail"]
    ir = _ir(kind, rng, scale=1.0)
    wetsig = D.convolve(dry, ir)[:n]
    out = dry * 0.8 + wetsig * wet * 0.5
    out = D.saturate(out, 1.2)
    return D.fade_out(D.normalize(out, 0.96), 60.0)


def render_crack_bank(i: int) -> np.ndarray:
    """Shared supersonic crack for rounds passing NEAR the listener.
    Receiver-side event: identical for 5.56/7.62. Gated by is_supersonic."""
    rng = np.random.default_rng(_seed("crack", "bank", i))
    n = int(D.SR * 0.35)
    w = D.n_wave(n, rng.uniform(0.00030, 0.00055))
    w = D.highpass(w, 1500.0, q=0.7)
    w = D.saturate(w * 3.0, 2.0)
    ir = _ir("jungle", rng, scale=0.6)
    out = w + D.convolve(w, ir)[:n] * 0.30
    return D.fade_out(D.normalize(out, 0.90), 8.0)


# --------------------------------------------------------------------------
# godot .import sidecars
# --------------------------------------------------------------------------


def write_import(res_path: str, disk_path: str, loop: bool = False) -> None:
    """Godot derives .godot/imported/<name>-<md5(res_path)>.sample. Emitting the
    sidecar means headless test runs and exports work without opening the editor.
    uid is deliberately omitted -- Godot mints one on first scan."""
    h = hashlib.md5(res_path.encode()).hexdigest()
    base = os.path.basename(res_path)
    dest = f"res://.godot/imported/{base}-{h}.sample"
    with open(disk_path + ".import", "w", newline="\n") as f:
        f.write(
            "[remap]\n\n"
            'importer="wav"\n'
            'type="AudioStreamWAV"\n'
            f'path="{dest}"\n\n'
            "[deps]\n\n"
            f'source_file="{res_path}"\n'
            f'dest_files=["{dest}"]\n\n'
            "[params]\n\n"
            "force/8_bit=false\n"
            "force/mono=true\n"
            "force/max_rate=false\n"
            "force/max_rate_hz=44100\n"
            "edit/trim=false\n"
            "edit/normalize=false\n"
            f"edit/loop_mode={1 if loop else 0}\n"
            "edit/loop_begin=0\n"
            "edit/loop_end=-1\n"
            "compress/mode=0\n"  # PCM: these are short, and the transient is the point
        )


def emit(subdir: str, name: str, samples: np.ndarray) -> None:
    outdir = OUT_W if subdir == "weapons" else OUT_X
    os.makedirs(outdir, exist_ok=True)
    disk = os.path.join(outdir, name)
    D.write_wav(disk, samples)
    write_import(f"res://assets/audio/sfx/{subdir}/{name}", disk)
    print(f"  {subdir}/{name:28s} {len(samples)/D.SR:.2f}s  {os.path.getsize(disk)//1024}KB")


def _seed(*parts) -> int:
    return int(hashlib.md5("|".join(str(p) for p in parts).encode()).hexdigest()[:8], 16)


# --------------------------------------------------------------------------
# report mode: numbers, because I cannot listen to these
# --------------------------------------------------------------------------


def spectral_report(wid: str) -> dict:
    x = render_near(wid, 1)
    X = np.abs(np.fft.rfft(x * np.hanning(len(x))))
    f = np.fft.rfftfreq(len(x), 1.0 / D.SR)
    p = X ** 2
    tot = float(np.sum(p))
    centroid = float(np.sum(f * p) / tot)
    lowband = float(np.sum(p[(f >= 40) & (f < 250)]) / tot)
    midband = float(np.sum(p[(f >= 250) & (f < 4000)]) / tot)
    hiband = float(np.sum(p[f >= 4000]) / tot)
    env = np.abs(x)
    peak_i = int(np.argmax(env))
    thresh = env[peak_i] * 0.01
    tail_i = peak_i + int(np.argmax(env[peak_i:] < thresh)) if np.any(env[peak_i:] < thresh) else len(x)
    decay_ms = (tail_i - peak_i) / D.SR * 1000.0
    crest = 20.0 * np.log10(np.max(np.abs(x)) / (np.sqrt(np.mean(x ** 2)) + 1e-12))
    print(f"{WEAPONS[wid]['name']:24s} centroid {centroid:7.0f}Hz  "
          f"low {lowband*100:5.1f}%  mid {midband*100:5.1f}%  hi>4k {hiband*100:5.1f}%  "
          f"decay40dB {decay_ms:6.1f}ms  crest {crest:4.1f}dB")
    return dict(wid=wid, centroid=centroid, low=lowband, mid=midband, hi=hiband,
                decay_ms=decay_ms, crest=crest)


def _acceptance(rows: list[dict]) -> None:
    """Fail loudly if a render drifts back into kick-drum territory. These are
    the thresholds I use to judge, since I cannot listen. A real gunshot has a
    high crest factor (sharp transient), meaningful mid+high energy (not just
    bass), and a short near-field decay."""
    print("\nacceptance gate:")
    bad = 0
    for r in rows:
        problems = []
        if r["crest"] < 7.0:
            problems.append(f"crest {r['crest']:.1f}<7 (mushy, no transient)")
        if r["low"] > 0.78:
            problems.append(f"low {r['low']*100:.0f}%>78 (kick-drum)")
        if r["mid"] + r["hi"] < 0.30:
            problems.append(f"mid+hi {(r['mid']+r['hi'])*100:.0f}%<30 (dull)")
        if r["decay_ms"] > 90.0:
            problems.append(f"decay {r['decay_ms']:.0f}ms>90 (near field too wet)")
        if problems:
            bad += 1
            print(f"  FAIL {r['wid']:10s} " + "; ".join(problems))
    # Distinctness: M16 vs AK must be separable by ear -> by centroid.
    cd = {r["wid"]: r["centroid"] for r in rows}
    if "m16a1" in cd and "ak47" in cd:
        ratio = cd["m16a1"] / cd["ak47"]
        tag = "OK" if ratio > 1.15 else "FAIL"
        print(f"  {tag}   M16/AK centroid ratio {ratio:.2f} (want >1.15: M16 brighter)")
    print(f"  {'ALL PASS' if bad == 0 else str(bad) + ' FAILED'}")


# --------------------------------------------------------------------------


def main() -> None:
    argv = [a for a in sys.argv[1:] if not a.startswith("--")]
    report = "--report" in sys.argv
    ids = argv or list(WEAPONS.keys())

    if report:
        print(f"{'weapon':24s} spectral fingerprints (near, variant 1)\n" + "-" * 118)
        rows = [spectral_report(wid) for wid in ids]
        _acceptance(rows)
        return

    for wid in ids:
        print(f"[{WEAPONS[wid]['name']}]")
        for v in (1, 2, 3):
            emit("weapons", f"fire_{wid}_{v}.wav", render_near(wid, v))
        emit("weapons", f"fire_{wid}_dist.wav", render_distant(wid))
        emit("weapons", f"mech_{wid}.wav", render_mech(wid))
        emit("weapons", f"reload_{wid}.wav", render_reload(wid))
        if wid in BOLT_GUNS:
            emit("weapons", f"bolt_{wid}.wav", render_bolt(wid))

    if not argv:
        print("[shared]")
        for i in (1, 2, 3):
            emit("weapons", f"crack_{i}.wav", render_crack_bank(i))
        print("[explosions]")
        for xid in EXPLOSIONS:
            emit("explosions", f"{xid}.wav", render_explosion(xid))


if __name__ == "__main__":
    main()
