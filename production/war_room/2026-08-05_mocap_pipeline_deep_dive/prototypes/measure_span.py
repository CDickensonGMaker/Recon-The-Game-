"""Read-only: what hand span did Caleb ACTUALLY perform in each weapon take?

Columnar take.json layout: frames.positions = nframes * njoints * 3.
Scale-normalised by his own forearm, because MediaPipe metric scale is
declared "approximate" in the take meta and must not carry the verdict.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

TAKES = Path(r"C:\Users\caleb\mocap-toolkit\takes")
WANT = ["caleb_mosin_m60_shotgun", "mosin_bolt", "m60_handling", "shotgun_pump",
        "mosin_bolt_v2", "mosin_p1_fire_bolt", "mosin_p2_reload_single",
        "mosin_p3_bolt", "preview_mosin", "mosin_clean"]


def med(v):
    v = sorted(v)
    if not v:
        return float("nan")
    n = len(v)
    return v[n // 2] if n % 2 else 0.5 * (v[n // 2 - 1] + v[n // 2])


def d(p, i, j):
    return math.sqrt(sum((p[i * 3 + k] - p[j * 3 + k]) ** 2 for k in range(3)))


rows = []
for stem in WANT:
    f = TAKES / f"{stem}.take.json"
    if not f.exists():
        continue
    t = json.loads(f.read_text(encoding="utf-8"))
    J = t["skeleton"]["joints"]
    nj = len(J)
    pos = t["frames"]["positions"]
    conf = t["frames"]["confidence"]
    nf = len(pos) // (nj * 3)
    idx = {n: i for i, n in enumerate(J)}
    wl, wr = idx["wrist_l"], idx["wrist_r"]
    el, er = idx["elbow_l"], idx["elbow_r"]
    sl, sr = idx["shoulder_l"], idx["shoulder_r"]

    spans, fores, shoul = [], [], []
    for fr in range(nf):
        p = pos[fr * nj * 3:(fr + 1) * nj * 3]
        c = conf[fr * nj:(fr + 1) * nj]
        ok = lambda i: c[i] > 0.5
        if ok(wl) and ok(wr):
            spans.append(d(p, wl, wr))
        if ok(er) and ok(wr):
            fores.append(d(p, er, wr))
        if ok(el) and ok(wl):
            fores.append(d(p, el, wl))
        if ok(sl) and ok(sr):
            shoul.append(d(p, sl, sr))
    ms, mf, msh = med(spans), med(fores), med(shoul)
    rows.append((stem, nf, len(spans), ms, mf, msh, ms / mf if mf else float("nan")))

print(f"{'take':<26}{'frames':>7}{'usable':>7}{'wristSpan':>11}{'forearm':>9}{'shoulders':>11}{'span/fore':>11}")
print("-" * 82)
for r in rows:
    print(f"{r[0]:<26}{r[1]:>7}{r[2]:>7}{r[3]:>11.3f}{r[4]:>9.3f}{r[5]:>11.3f}{r[6]:>11.2f}")

# --- what the rig demands, converted into the same scale-free unit -----------
# docs/FILMING.md, measured off the live rigs 7/31.
GRIP = {"Mosin": 0.294, "M60": 0.407, "Ithaca shotgun": 0.377}
STALE = {"Mosin": 0.500, "M60": 0.310, "Ithaca shotgun": 0.379}
MOSIN_WRIST_SEP_RIG = 0.418   # the one wrist figure the doc trusted

print()
print("LIVE RIG (docs/FILMING.md, 7/31)   vs   STALE grip_states table")
for k in GRIP:
    err = STALE[k] - GRIP[k]
    print(f"  {k:<16} live {GRIP[k]:.3f} m   stale {STALE[k]:.3f} m   error {err:+.3f} m "
          f"({100*err/GRIP[k]:+.0f}%)")
print(f"\n  Mosin idle WRIST separation on the live rig: {MOSIN_WRIST_SEP_RIG:.3f} m")
print("  (grip points sit inboard of the wrist bones, so compare wrist-to-wrist)")

fore_ref = med([r[4] for r in rows if r[4] == r[4]])
if fore_ref and fore_ref == fore_ref:
    print(f"\n  His median forearm across these takes: {fore_ref:.3f} m")
    print(f"  Rig-demanded Mosin wrist span in forearm units: "
          f"{MOSIN_WRIST_SEP_RIG/fore_ref:.2f}")
