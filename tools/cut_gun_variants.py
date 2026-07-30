"""cut_gun_variants.py - fill in missing fire_<id>_2/_3 from the source pack.

The 2026-07-27 decree (D1) specified THREE near-report variants for m16a1, ak47,
rpd and car15. Only m60 and ppsh41 received them; the rest shipped with variant 1
alone, so the player's M16 and every enemy AK fired one identical sample forever.
A repeating single sample combs at automatic cadence -- the exact defect that
decree named when it refused to build m60 from a single 7.62x54R take.

Shots are sliced out of the multi-shot source takes (Burst / Spray / Double Tap),
then the candidates least correlated with the existing variant 1 are kept, so the
variants are genuinely different EVENTS rather than one shot pitch-shifted.

    python tools/cut_gun_variants.py            # report only, writes nothing
    python tools/cut_gun_variants.py --write
"""

from __future__ import annotations

import os
import subprocess
import sys
import wave

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "audio", "sfx", "weapons")
PACK = os.path.join(os.path.expanduser("~"), "Downloads",
                    "Snake's Authentic Gun Sounds And More", "Snake's Authentic Gun Sounds")
SR = 48000

# Which weapons need filling, and which caliber folder feeds them. Treatment
# mirrors the 2026-07-27 mapping so a new variant sits beside variant 1, not
# beside the raw source.
# sks/thompson/kar98k/mp40 are RETIRED BY CANON (test_flat_damage.gd). Adding
# audio for one creates a fossil test_audio_pack.gd fails on. car15 is LIVE again
# (Summoner, 2026-07-29) -- a 10" barrel, so it is treated brighter and harsher
# than the rifle, which is the whole point of the carbine.
TARGETS = {
    "m16a1": dict(cal="5.56", pitch=1.00, tilt_db=0.0),
    "car15": dict(cal="5.56", pitch=0.97, tilt_db=1.2),
    "ak47":  dict(cal="7.62x39", pitch=1.00, tilt_db=0.0),
    "rpd":   dict(cal="7.62x39", pitch=0.96, tilt_db=2.0),
    # SKS: the AK's cartridge out of a 520mm barrel instead of 415mm. More of the
    # powder burns inside, so it reads SHARPER and cleaner with less muzzle blast
    # -- hence the pitch up and the negative shelf. length_s bootstraps it from
    # nothing (no prior audio existed).
    "sks":   dict(cal="7.62x39", pitch=1.02, tilt_db=-1.0, length_s=0.90),
}

RMS_TARGET_DB = -23.0
PEAK_CEIL_DB = -1.0


def _decode(path: str) -> np.ndarray:
    """Source is 44.1k stereo; the house contract is 48k mono."""
    out = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR),
         "-f", "s16le", "-"],
        capture_output=True, check=True).stdout
    return np.frombuffer(out, dtype="<i2").astype(np.float64) / 32768.0


def _read_wav(path: str) -> tuple[np.ndarray, int]:
    """Returns rate too: four of the 2026-07-27 files are 44100, not the house
    48000, so assuming the rate mis-measures variant 1's duration."""
    with wave.open(path) as w:
        x = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64) / 32768.0
        return x, w.getframerate()


def _write_wav(path: str, x: np.ndarray) -> None:
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2").tobytes())


def _onsets(x: np.ndarray, thresh: float = 0.30, guard_s: float = 0.12) -> list[int]:
    env = np.abs(x)
    guard = int(guard_s * SR)
    peak = env.max()
    hits: list[int] = []
    i = 0
    while i < len(env):
        if env[i] > peak * thresh:
            # walk back to the true transient foot
            j = max(0, i - int(0.002 * SR))
            hits.append(j)
            i += guard
        else:
            i += 1
    return hits


def _slice(x: np.ndarray, at: int, length_s: float) -> np.ndarray:
    n = int(length_s * SR)
    seg = np.zeros(n)
    take = x[at:at + n]
    seg[:len(take)] = take
    # short fades: the slice must not click at either end
    fi = int(0.0006 * SR)
    fo = int(0.020 * SR)
    seg[:fi] *= np.linspace(0.0, 1.0, fi)
    seg[-fo:] *= np.linspace(1.0, 0.0, fo)
    return seg


def _resample(x: np.ndarray, ratio: float) -> np.ndarray:
    if abs(ratio - 1.0) < 1e-6:
        return x
    n = int(len(x) / ratio)
    return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x)


def _tilt(x: np.ndarray, db: float) -> np.ndarray:
    """Gentle low shelf, the same 'heavier' treatment the decree applied to rpd."""
    if abs(db) < 0.01:
        return x
    g = 10.0 ** (db / 20.0) - 1.0
    acc = 0.0
    a = 1.0 - np.exp(-2.0 * np.pi * 150.0 / SR)
    low = np.empty_like(x)
    for i, s in enumerate(x):
        acc += a * (s - acc)
        low[i] = acc
    return x + low * g


def _level(x: np.ndarray) -> np.ndarray:
    rms = np.sqrt(np.mean(x ** 2)) + 1e-12
    x = x * (10.0 ** (RMS_TARGET_DB / 20.0) / rms)
    peak = np.abs(x).max()
    ceil = 10.0 ** (PEAK_CEIL_DB / 20.0)
    if peak > ceil:
        x = x * (ceil / peak)
    return x


def _bootstrap(wid: str, cfg: dict, write: bool) -> np.ndarray | None:
    """A weapon with NO audio at all: cut variant 1 from the Single take and the
    distant report from the matching Full Sound take. Full Sound is the same take
    plus its environmental tail (measured 2026-07-27: centroids match to 2 Hz),
    which is exactly what a distant report is."""
    iso = os.path.join(PACK, "Isolated", cfg["cal"], "WAV")
    full = os.path.join(PACK, "Full Sound", cfg["cal"], "WAV")
    single = [f for f in sorted(os.listdir(iso)) if "single" in f.lower()]
    if not single:
        print(f"  {wid}: no Single take to bootstrap from")
        return None
    x = _decode(os.path.join(iso, single[0]))
    hits = _onsets(x)
    if not hits:
        return None
    v1 = _level(_tilt(_resample(_slice(x, hits[0], cfg["length_s"]), cfg["pitch"]), cfg["tilt_db"]))
    if write:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        from gen_weapon_audio import write_import
        disk = os.path.join(OUT, f"fire_{wid}_1.wav")
        _write_wav(disk, v1)
        write_import(f"res://assets/audio/sfx/weapons/fire_{wid}_1.wav", disk)
        print(f"    wrote fire_{wid}_1.wav  {len(v1)/SR:.2f}s  (bootstrapped)")
        fs = [f for f in sorted(os.listdir(full)) if "single" in f.lower()] if os.path.isdir(full) else []
        if fs:
            y = _decode(os.path.join(full, fs[0]))
            fh = _onsets(y)
            if fh:
                dist = _level(_tilt(_resample(_slice(y, fh[0], cfg["length_s"] * 1.8),
                                              cfg["pitch"]), cfg["tilt_db"]))
                dd = os.path.join(OUT, f"fire_{wid}_dist.wav")
                _write_wav(dd, dist)
                write_import(f"res://assets/audio/sfx/weapons/fire_{wid}_dist.wav", dd)
                print(f"    wrote fire_{wid}_dist.wav  {len(dist)/SR:.2f}s  (Full Sound take)")
    return v1


def build(wid: str, cfg: dict, write: bool) -> None:
    src_dir = os.path.join(PACK, "Isolated", cfg["cal"], "WAV")
    if not os.path.isdir(src_dir):
        print(f"  {wid}: source pack missing at {src_dir}")
        return

    v1_path = os.path.join(OUT, f"fire_{wid}_1.wav")
    if not os.path.exists(v1_path):
        if "length_s" not in cfg:
            print(f"  {wid}: no variant 1 and no length_s to bootstrap with, skipping")
            return
        v1 = _bootstrap(wid, cfg, write)
        if v1 is None:
            return
        length_s = len(v1) / float(SR)
    else:
        v1, v1_rate = _read_wav(v1_path)
        length_s = len(v1) / float(v1_rate)

    cands: list[np.ndarray] = []
    for fn in sorted(os.listdir(src_dir)):
        if not fn.lower().endswith(".wav"):
            continue
        if "single" in fn.lower():
            continue  # variant 1 already came from the single take
        x = _decode(os.path.join(src_dir, fn))
        for at in _onsets(x):
            # keep only shots with room to decay before the next one
            seg = _slice(x, at, length_s)
            if np.abs(seg).max() < 0.15:
                continue
            cands.append(seg)

    if len(cands) < 2:
        print(f"  {wid}: only {len(cands)} usable slices, cannot fill")
        return

    # Treat, then rank by decorrelation against variant 1.
    treated = []
    for c in cands:
        y = _resample(c, cfg["pitch"])
        y = _tilt(y, cfg["tilt_db"])
        y = _level(y)
        n = min(len(y), len(v1))
        r = abs(float(np.corrcoef(y[:n], v1[:n])[0, 1]))
        treated.append((r, y))
    treated.sort(key=lambda t: t[0])

    chosen: list[tuple[float, np.ndarray]] = []
    for r, y in treated:
        ok = True
        for _, c in chosen:
            n = min(len(y), len(c))
            if abs(float(np.corrcoef(y[:n], c[:n])[0, 1])) > 0.40:
                ok = False
                break
        if ok:
            chosen.append((r, y))
        if len(chosen) == 2:
            break

    if len(chosen) < 2:
        print(f"  {wid}: could not find 2 decorrelated slices")
        return

    print(f"  {wid}: {len(cands)} slices -> variants 2,3 "
          f"(r vs v1 = {chosen[0][0]:.3f}, {chosen[1][0]:.3f})")
    if not write:
        return

    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from gen_weapon_audio import write_import
    for i, (_, y) in enumerate(chosen, start=2):
        name = f"fire_{wid}_{i}.wav"
        disk = os.path.join(OUT, name)
        _write_wav(disk, y)
        write_import(f"res://assets/audio/sfx/weapons/{name}", disk)
        print(f"    wrote {name}  {len(y)/SR:.2f}s")


def main() -> None:
    write = "--write" in sys.argv
    print("cutting missing gun variants" + ("" if write else "  (dry run, --write to apply)"))
    for wid, cfg in TARGETS.items():
        build(wid, cfg, write)


if __name__ == "__main__":
    main()
