"""PROTOTYPE of the decree's `beats.json` — extract weapon-handling BEAT TIMING from a take.

Doctrine being tested: video supplies TIMING, never hand position. Timing is a 1-D
signal, so the 48-51%% inferred-depth problem does not touch it.

Method, all in WEAPON-RELATIVE space so the performer walking around cannot pollute it:
  * the two wrists lie on the gun, so wrist_L -> wrist_R approximates the bore axis
  * express the working hand relative to the support hand, in that frame
  * DWELL  = speed below a percentile floor for >= min_hold frames  -> a contact
  * STROKE = the travel between two dwells                          -> a working motion
  * classify a stroke by its signed displacement along the bore axis
Read-only. Writes nothing.
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

TAKES = Path(r"C:\Users\caleb\mocap-toolkit\takes")


def sub(a, b):
    return [a[i] - b[i] for i in range(3)]


def norm(v):
    return math.sqrt(sum(x * x for x in v))


def unit(v):
    n = norm(v)
    return [x / n for x in v] if n > 1e-9 else [0.0, 0.0, 0.0]


def dot(a, b):
    return sum(a[i] * b[i] for i in range(3))


def cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def smooth(xs, w=5):
    h = w // 2
    return [sum(xs[max(0, i - h):min(len(xs), i + h + 1)]) /
            len(xs[max(0, i - h):min(len(xs), i + h + 1)]) for i in range(len(xs))]


def pct(xs, p):
    s = sorted(xs)
    return s[max(0, min(len(s) - 1, int(p * len(s))))]


def load(stem):
    t = json.loads((TAKES / f"{stem}.take.json").read_text(encoding="utf-8"))
    J = t["skeleton"]["joints"]
    nj = len(J)
    pos, conf = t["frames"]["positions"], t["frames"]["confidence"]
    nf = len(pos) // (nj * 3)
    idx = {n: i for i, n in enumerate(J)}
    fps = t["meta"]["fps"]

    def P(fr, name):
        i = idx[name]
        b = fr * nj * 3 + i * 3
        return pos[b:b + 3]

    def C(fr, name):
        return conf[fr * nj + idx[name]]

    return t, nf, fps, P, C


def extract(stem, work="wrist_r", supp="wrist_l", min_hold=4):
    t, nf, fps, P, C = load(stem)

    # A FIXED bore axis for the whole take -- the median direction of the
    # hand-to-hand vector. Deriving it per frame from the same vector we then
    # project onto is degenerate: lift and lateral come out identically zero.
    dirs = [unit(sub(P(f, work), P(f, supp))) for f in range(nf)
            if C(f, work) > 0.5 and C(f, supp) > 0.5]
    bore = unit([sorted(d[k] for d in dirs)[len(dirs) // 2] for k in range(3)])
    up = [0.0, 0.0, 1.0]
    lat = unit(cross(bore, up))
    lift = unit(cross(lat, bore))

    # working hand in support-hand frame, on that fixed bore/lift/lateral basis
    rel, ok = [], []
    for f in range(nf):
        good = C(f, work) > 0.5 and C(f, supp) > 0.5
        ok.append(good)
        if not good:
            rel.append(rel[-1] if rel else [0.0, 0.0, 0.0])
            continue
        d = sub(P(f, work), P(f, supp))
        rel.append([dot(d, bore), dot(d, lift), dot(d, lat)])

    spd = [0.0]
    for f in range(1, nf):
        spd.append(norm(sub(rel[f], rel[f - 1])) * fps)
    spd = smooth(spd, 5)

    floor = pct([s for s, o in zip(spd, ok) if o], 0.35)
    peak = pct([s for s, o in zip(spd, ok) if o], 0.90)

    # dwell runs
    dwells, run = [], None
    for f in range(nf):
        if spd[f] <= floor and ok[f]:
            run = run or [f, f]
            run[1] = f
        else:
            if run and run[1] - run[0] + 1 >= min_hold:
                dwells.append(tuple(run))
            run = None
    if run and run[1] - run[0] + 1 >= min_hold:
        dwells.append(tuple(run))

    beats = []
    for i in range(len(dwells) - 1):
        a_s, a_e = dwells[i]
        b_s, b_e = dwells[i + 1]
        if b_s - a_e < 2:
            continue
        seg = spd[a_e:b_s]
        if not seg or max(seg) < peak * 0.5:
            continue                      # drift, not a working stroke
        if (b_s - a_e) / fps > 1.5:
            continue                      # too long to be one stroke; it is a transit
        d_bore = rel[b_s][0] - rel[a_e][0]
        d_lift = rel[b_s][1] - rel[a_e][1]
        d_lat = rel[b_s][2] - rel[a_e][2]
        travel = norm(sub(rel[b_s], rel[a_e]))
        beats.append({
            "start": a_e, "end": b_s,
            "frames": b_s - a_e,
            "ms": round(1000 * (b_s - a_e) / fps),
            "travel_mm": round(travel * 1000),
            "bore_mm": round(d_bore * 1000),
            "lift_mm": round(d_lift * 1000),
            "lat_mm": round(d_lat * 1000),
            "peak_speed": round(max(seg), 3),
        })
    return t, nf, fps, dwells, beats, floor, peak, rel, ok


def label(b):
    """Name the stroke from its dominant axis and sign. Mosin bolt convention:
    +bore = hand travels rearward along the gun (bolt back)."""
    if abs(b["lift_mm"]) > abs(b["bore_mm"]) * 1.3:
        return "LIFT_UP" if b["lift_mm"] > 0 else "LIFT_DOWN"
    return "REARWARD" if b["bore_mm"] > 0 else "FORWARD"


for stem in (sys.argv[1:] or ["mosin_p3_bolt", "mosin_p1_fire_bolt", "shotgun_pump"]):
    t, nf, fps, dwells, beats, floor, peak, rel, ok = extract(stem)
    print(f"\n=== {stem} === {nf} frames @ {fps:.2f} fps "
          f"({nf/fps:.1f}s)  speed floor {floor:.3f} peak {peak:.3f} m/s")
    print(f"  dwells (contacts held >=4f): {len(dwells)}   working strokes: {len(beats)}")
    if not beats:
        print("  (no strokes cleared the peak gate)")
        continue
    print(f"  {'#':>3} {'frames':>11} {'ms':>5} {'travel':>8} {'bore':>6} {'lift':>6} "
          f"{'LATERAL':>8}  label")
    for i, b in enumerate(beats):
        print(f"  {i:>3} {b['start']:>4}->{b['end']:<5} {b['ms']:>5} "
              f"{b['travel_mm']:>6}mm {b['bore_mm']:>6} {b['lift_mm']:>6} "
              f"{b['lat_mm']:>8}  {label(b)}")
    per = [b["frames"] for b in beats]
    print(f"  stroke length: min {min(per)}f  median {sorted(per)[len(per)//2]}f  max {max(per)}f")

    # How much of the STROKE motion rides the camera-facing (inferred) axis?
    # In a side-on shot: bore + lift are in the image plane, lateral IS depth.
    num = sum(abs(b["lat_mm"]) for b in beats)
    den = sum(abs(b["bore_mm"]) + abs(b["lift_mm"]) + abs(b["lat_mm"]) for b in beats)
    print(f"  >> LATERAL (inferred-depth) share of stroke displacement: "
          f"{100*num/den:.0f}%" if den else "")

    # The depth-ROBUST 1-D alternative: hand separation, measured in the image plane.
    sep = [norm([rel[f][0], rel[f][1], rel[f][2]]) for f in range(nf)]
    sep_s = smooth(sep, 5)
    turns = sum(1 for f in range(2, nf - 1)
                if (sep_s[f] - sep_s[f - 1]) * (sep_s[f + 1] - sep_s[f]) < 0
                and abs(sep_s[f + 1] - sep_s[f - 1]) > 0.004)
    print(f"  >> hand-separation reversals (1-D, depth-robust beat signal): {turns}")
