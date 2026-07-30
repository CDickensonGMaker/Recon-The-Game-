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


def _ir_unit(kind: str, rng, scale: float = 1.0) -> np.ndarray:
    """IR scaled to unit diffuse energy. Without this a `wet` value means a
    different loudness in every environment, because a 5.6s valley IR carries
    far more energy than a 0.9s jungle one -- so the longest tail drowned its
    own transient and the crest factor collapsed."""
    ir = _ir(kind, rng, scale)
    diffuse = ir[1:]
    e = float(np.sqrt(np.sum(diffuse ** 2)))
    if e > 1e-9:
        ir = ir / e
        ir[0] = 1.0
    return ir


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


def render_explosion(xid: str, variant: int = 1) -> np.ndarray:
    """Near-field detonation. Eight layers, in the order the ear receives them:
    shock front, gas fireball, sub body, ground slap, terrain returns, frag
    whizz, debris fall, environment tail."""
    p = EXPLOSIONS[xid]
    rng = np.random.default_rng(_seed(xid, "expl", variant))
    n = int(D.SR * p["dur"])

    # Per-variant charge jitter, same principle as render_near: three shells are
    # three events, not one file replayed. Without this a 3-round mortar volley
    # is the identical waveform three times a second.
    p = dict(p)
    p["f_low"] *= rng.uniform(0.90, 1.12)
    p["brightness"] *= rng.uniform(0.84, 1.18)
    p["blast_tau"] *= rng.uniform(0.86, 1.16)

    front = D.highpass(D.friedlander(n, p["blast_tau"]), 42.0)

    gas = D.noise(n, rng) * D.expdecay(n, p["blast_tau"] * p["gas_mult"], rise=0.0004)
    gas = D.lowpass(gas, p["brightness"], q=0.8, passes=2)

    # Sub body. The pitch does NOT decay exponentially to zero -- a real blast
    # cavity collapses, so the sweep settles onto a floor instead of vanishing.
    t = np.arange(n) / D.SR
    sweep = p["f_low"] * (0.72 + 0.75 * np.exp(-t / (p["sub_tau"] * 0.45)))
    phase = 2.0 * np.pi * np.cumsum(sweep) / D.SR
    sub = np.sin(phase) * D.expdecay(n, p["sub_tau"], rise=0.0015) * p["rumble"]

    core = D.saturate(front * 0.85 + gas * 1.15 + sub * 0.95, p["drive"])

    # Ground slap: the blast reflecting off the earth a few metres below the
    # burst. Arrives too soon to hear as an echo -- it is heard as WEIGHT.
    if p["slap_ms"] > 0.0:
        slap = D.lowpass(core, p["brightness"] * 0.55, passes=2)
        core = D.place(core.copy(), slap[: n - int(p["slap_ms"] * 0.001 * D.SR)],
                       p["slap_ms"] * 0.001, 0.42)

    # Discrete terrain returns: treelines and valley walls handing the shell
    # back. Each is later, darker and quieter than the last. This is the layer
    # that makes artillery ROLL instead of stop.
    ret = np.zeros(n)
    at, gain = 0.11, 0.17
    for k in range(int(p["returns"])):
        src = D.air_absorb(D.lowpass(core, 3200.0 - 180.0 * k), 120.0 + 60.0 * k)
        ret = D.place(ret, src[: max(1, n - int(at * D.SR))], at, gain * rng.uniform(0.7, 1.15))
        at *= rng.uniform(1.75, 2.35)
        gain *= 0.52
        if at >= p["dur"] * 0.85:
            break

    # Fragment whizz: casing shards passing the listener. Doppler-swept tones,
    # not noise -- a shard has a note.
    whizz = np.zeros(n)
    for _ in range(int(26 * p["frag"])):
        ln = int(D.SR * rng.uniform(0.05, 0.16))
        f0 = rng.uniform(450, 1500)
        ph = 2.0 * np.pi * np.cumsum(np.linspace(f0 * 1.5, f0 * 0.55, ln)) / D.SR
        w = np.sin(ph) * np.hanning(ln) * rng.uniform(0.035, 0.10)
        whizz = D.place(whizz, w, rng.uniform(0.02, 0.35) ** 1.2)

    # Debris fall. `debris` scales the COUNT here and nothing else -- applying it
    # again to the summed layer squared it, which is why the frag patter had all
    # but vanished on the small classes.
    deb = np.zeros(n)
    for _ in range(int(90 * p["debris"])):
        at_d = rng.uniform(0.03, p["dur"] * 0.55) ** 1.4
        ln = int(D.SR * rng.uniform(0.004, 0.02))
        tick = D.noise(ln, rng) * D.expdecay(ln, 0.003)
        tick = D.bandpass(tick, rng.uniform(900, 4200), q=3.0)
        deb = D.place(deb, tick, at_d, rng.uniform(0.05, 0.28))
    hiss = D.noise(n, rng) * D.expdecay(n, 0.30 + 0.5 * p["sub_tau"], rise=0.006)
    hiss = D.bandpass(hiss, 2600.0, q=0.7) * 0.22 * p["debris"]

    dry = core + ret + whizz + deb + hiss

    kind, wet = p["tail"]
    ir = _ir_unit(kind, rng, scale=1.0)
    out = dry * 0.9 + D.convolve(dry, ir)[:n] * wet * 0.22
    out = D.saturate(out, 1.2)
    return D.fade_out(D.normalize(out, p["peak"]), 60.0)


def render_explosion_distant(xid: str) -> np.ndarray:
    """The same burst heard from across the AO. Air has eaten the fireball; what
    survives is the sub, the returns and a long roll. Mirrors render_distant for
    guns -- explosions had no distance layer at all, so a shell at 500 m was the
    near-field file played quieter."""
    p = EXPLOSIONS[xid]
    rng = np.random.default_rng(_seed(xid, "expl_dist", 0))
    dur = p["dur"] * 1.9
    n = int(D.SR * dur)

    near = D.pad_to(render_explosion(xid, 1), n)
    body = D.air_absorb(near, 520.0)
    body = D.lowpass(body, 900.0, passes=2)

    out = np.zeros(n)
    out = D.place(out, body, 0.0, 0.55)

    # Long, sparse returns: at range the roll IS the event.
    at, gain = 0.22, 0.42
    for _ in range(int(p["returns"]) + 4):
        src = D.air_absorb(D.lowpass(body, 700.0), 600.0)
        out = D.place(out, src[: max(1, n - int(at * D.SR))], at, gain * rng.uniform(0.7, 1.2))
        at *= rng.uniform(1.6, 2.1)
        gain *= 0.70
        if at >= dur * 0.9:
            break

    ir = _ir("valley", rng, scale=1.5)
    out = out * 0.45 + D.convolve(out, ir)[:n] * 0.75
    out = D.lowpass(out, 1400.0, passes=2)
    return D.fade_out(D.normalize(out, 0.82), 120.0)


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


def _explosion_stats(xid: str, variant: int = 1) -> dict:
    x = render_explosion(xid, variant)
    X = np.abs(np.fft.rfft(x * np.hanning(len(x))))
    f = np.fft.rfftfreq(len(x), 1.0 / D.SR)
    p = X ** 2
    tot = float(np.sum(p))
    # Smoothed RMS envelope. A raw |x| envelope crosses any threshold at the
    # first zero-crossing dip, which reports a 60 dB decay inside 70 ms for a
    # sound that is still rolling half a second later.
    w = int(0.020 * D.SR)
    env = np.sqrt(np.convolve(x ** 2, np.ones(w) / w, mode="same"))
    pk = int(np.argmax(env))
    below = np.where(env[pk:] < env[pk] * 0.001)[0]
    t60 = float(below[0] / D.SR) if below.size else float(len(x) - pk) / D.SR
    # Energy arriving after 400 ms proves the returns/roll layer exists at all.
    late = float(np.sum(x[int(0.4 * D.SR):] ** 2) / (np.sum(x ** 2) + 1e-12))
    return dict(
        xid=xid,
        centroid=float(np.sum(f * p) / tot),
        low=float(np.sum(p[(f >= 30) & (f < 250)]) / tot),
        hi=float(np.sum(p[f >= 4000]) / tot),
        t60=t60,
        late=late,
        crest=20.0 * np.log10(np.max(env) / (np.sqrt(np.mean(x ** 2)) + 1e-12)),
        dur=len(x) / D.SR,
    )


def _acceptance_explosions() -> None:
    """The size ladder, enforced numerically. A grenade and a 155 must not be
    interchangeable, and 'more weight' must not mean 'kick drum'."""
    print(f"\n{'explosion':22s} spectral fingerprints\n" + "-" * 96)
    rows = {}
    for xid in EXPLOSIONS:
        r = _explosion_stats(xid)
        rows[xid] = r
        print(f"{xid:22s} centroid {r['centroid']:6.0f}Hz  low {r['low']*100:5.1f}%  "
              f"hi>4k {r['hi']*100:4.1f}%  t60 {r['t60']:5.2f}s  late>400ms {r['late']*100:5.1f}%  "
              f"crest {r['crest']:4.1f}dB")

    print("\nacceptance gate:")
    bad = 0
    for xid, r in rows.items():
        probs = []
        if r["crest"] < 9.0:
            probs.append(f"crest {r['crest']:.1f}<9 (mushy)")
        # Ceiling is per-class and comes from measurement, not taste. A real
        # blast recorded at 250 m (BigSoundBank 1806) measures 91.2% of its
        # energy below 250 Hz with a 247 Hz centroid -- a heavy shell IS that
        # low-dominated, and holding it to the small-ordnance ceiling would mean
        # tuning the truth out of it.
        low_max = 0.93 if r["dur"] >= 4.0 else 0.90
        if r["low"] > low_max:
            probs.append(f"low {r['low']*100:.0f}%>{low_max*100:.0f} (kick-drum)")
        if r["centroid"] > 1400.0:
            probs.append(f"centroid {r['centroid']:.0f}>1400 (firework, not detonation)")
        # A 40mm HE genuinely has no roll; only the classes long enough to
        # carry one are held to it.
        min_late = 0.012 if r["dur"] < 2.0 else 0.02
        if r["late"] < min_late:
            probs.append(f"late {r['late']*100:.1f}%<{min_late*100:.1f} (no roll -- returns layer missing)")
        if probs:
            bad += 1
            print(f"  FAIL {xid:20s} " + "; ".join(probs))

    # Cross-checks: the ladder itself.
    g, h = rows["explosion_grenade"], rows["explosion_heavy"]
    checks = [
        ("heavy darker than grenade", h["centroid"] < 0.75 * g["centroid"],
         f"{h['centroid']:.0f} vs {g['centroid']:.0f}"),
        ("heavy rolls longer than grenade", h["t60"] > 2.0 * g["t60"],
         f"{h['t60']:.2f}s vs {g['t60']:.2f}s"),
        ("40mm shorter than rocket", rows["explosion_40mm"]["dur"] < rows["explosion_rocket"]["dur"],
         f"{rows['explosion_40mm']['dur']:.1f}s vs {rows['explosion_rocket']['dur']:.1f}s"),
    ]
    for name, ok, detail in checks:
        if not ok:
            bad += 1
        print(f"  {'OK  ' if ok else 'FAIL'} {name} ({detail})")

    # Variants must be genuinely different renders, not one file pitch-shifted.
    for xid in EXPLOSIONS:
        a, b = render_explosion(xid, 1), render_explosion(xid, 2)
        m = min(len(a), len(b))
        c = float(np.corrcoef(a[:m], b[:m])[0, 1])
        ok = abs(c) < 0.35
        if not ok:
            bad += 1
        print(f"  {'OK  ' if ok else 'FAIL'} {xid} variant decorrelation (r={c:+.3f}, want |r|<0.35)")

    print(f"  {'ALL PASS' if bad == 0 else str(bad) + ' FAILED'}")


def main() -> None:
    argv = [a for a in sys.argv[1:] if not a.startswith("--")]
    report = "--report" in sys.argv
    ids = argv or list(WEAPONS.keys())

    if report:
        if "--explosions" in sys.argv:
            _acceptance_explosions()
            return
        print(f"{'weapon':24s} spectral fingerprints (near, variant 1)\n" + "-" * 118)
        rows = [spectral_report(wid) for wid in ids]
        _acceptance(rows)
        return

    if "--explosions" in sys.argv:
        print("[explosions]")
        for xid in EXPLOSIONS:
            for v in (1, 2, 3):
                emit("explosions", f"{xid}_{v}.wav", render_explosion(xid, v))
            emit("explosions", f"{xid}_dist.wav", render_explosion_distant(xid))
        return

    # GUARD. These carry REAL RECORDINGS from the source pack (2026-07-27 decree,
    # production/war_room/2026-07-27_audio_pack/synthesis.md; sks/car15 added
    # 2026-07-29). Rendering synth over one is the downgrade the Summoner
    # explicitly forbade -- and naming the id on the command line is NOT enough
    # intent, because the fire_* files are the ones that get clobbered while the
    # mech_/reload_ layers legitimately want regenerating.
    real_audio = {"m16a1", "car15", "ak47", "rpd", "mosin", "m70", "m14", "m60",
                  "ppsh41", "sks"}
    if not argv:
        print("refusing to regenerate every weapon: real recordings would be "
              "overwritten with synth.\n"
              "  name the ids explicitly   python tools/gen_weapon_audio.py m79 rpg7\n"
              "  or render ordnance only   python tools/gen_weapon_audio.py --explosions")
        return
    clash = sorted(set(ids) & real_audio)
    if clash and "--force" not in sys.argv:
        print(f"refusing: {', '.join(clash)} carry REAL recordings; synth would be a "
              f"downgrade.\n"
              f"  rebuild them from the pack   python tools/cut_gun_variants.py --write\n"
              f"  override anyway              --force")
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


if __name__ == "__main__":
    main()
