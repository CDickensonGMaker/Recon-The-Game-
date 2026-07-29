"""Measure every gun part against the bore centreline and flag crooked ones.

    python tools/check_gun_alignment.py            # every gun in the manifest
    python tools/check_gun_alignment.py m16 ak     # named guns only

The 2026-07-28 M16 session found four structural pieces sitting off the bore
(receiver rail +4.06mm, rear sight aperture +3.75mm, carry handle +3.0mm,
magazine -0.63mm). Nothing in the export gate looked for that, so it kept
coming back. This is the probe.

METHOD. Every piece of a gun is a connected shell, measured in the gun root's
local space. A shell that is mirror-symmetric about some lateral plane tells us
its own true centre exactly - no eyeballing. The bore line is the MEDIAN of all
symmetric shells' centres, which is robust because most of a rifle is on-axis.

CLASSIFICATION, and why it is not just "snap everything to the middle":
  - |err| <= TOL                     : ON BORE
  - TOL < |err| <= PAIR_MIN, no twin : DRIFT      <- the defect
  - |err| > PAIR_MIN with a twin at -err : PAIR   <- sight ears, flash-hider prongs
  - |err| > PAIR_MIN, no twin        : ONE-SIDED  <- bolt catch, forward assist
  - not mirror-symmetric             : ASYMMETRIC <- e.g. a charging handle
Only DRIFT is a failure. Snapping a pair or a one-sided control would break the
model, which is why the naive "centre everything" sweep is wrong.

Also reports open/non-manifold shells - the carry-handle disease.
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLENDER = os.environ.get("RECON_BLENDER",
                         r"C:\Program Files\Blender Foundation\Blender 5.0\blender.exe")
MANIFEST = os.path.join(ROOT, "tools", "viewmodel_manifest.json")

INNER = r'''
import bpy, json, sys, statistics
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
guns = json.loads(args[0])
TOL = 0.0003        # 0.3 mm - on the bore
PAIR_MIN = 0.005    # beyond 5 mm we expect a deliberate pair or a side control
SYM = 2e-4          # vertex match tolerance for the mirror test

def shells(me):
    n = len(me.vertices)
    par = list(range(n))
    def find(a):
        while par[a] != a:
            par[a] = par[par[a]]; a = par[a]
        return a
    for e in me.edges:
        a, b = find(e.vertices[0]), find(e.vertices[1])
        if a != b:
            par[a] = b
    g = {}
    for i in range(n):
        g.setdefault(find(i), []).append(i)
    return list(g.values())

def topology(me):
    ec = {}
    for p in me.polygons:
        vs = list(p.vertices)
        for i in range(len(vs)):
            k = tuple(sorted((vs[i], vs[(i + 1) % len(vs)])))
            ec[k] = ec.get(k, 0) + 1
    return sum(1 for v in ec.values() if v == 1), sum(1 for v in ec.values() if v > 2)

out = {}
for key, spec in guns.items():
    coll = bpy.data.collections.get(spec["collection"])
    root = bpy.data.objects.get(spec["gun_root"])
    if coll is None or root is None:
        out[key] = {"error": "collection or gun_root missing"}
        continue
    inv = root.matrix_world.inverted()
    prefix = spec["gun_prefix"]
    raw = []
    badtopo = []
    for o in coll.objects:
        if o.type != 'MESH' or not o.name.startswith(prefix):
            continue
        op, nm = topology(o.data)
        if op or nm:
            badtopo.append([o.name, op, nm])
        for idx in shells(o.data):
            raw.append((o.name, [inv @ (o.matrix_world @ o.data.vertices[i].co)
                                 for i in idx]))

    # The gun's symmetry plane is not always perpendicular to a root axis (AK and
    # M14 roots are tilted). But muzzle/sight_front/sight_rear all lie ON that
    # plane by contract, so their triangle gives its normal directly - and they
    # are not collinear because the muzzle sits ~45mm below the sight line.
    def marker(nm):
        o = bpy.data.objects.get(nm + "_" + spec["gun_prefix"])
        return None if o is None else inv @ o.matrix_world.translation
    mz, sf, sr = marker("muzzle"), marker("sight_front"), marker("sight_rear")
    cands = []
    if None not in (mz, sf, sr):
        n = (sf - sr).cross(mz - sr)
        if n.length > 1e-6:
            cands.append((n.normalized(), "markers"))
    for ax in range(3):
        cands.append((Vector((1 if ax == 0 else 0, 1 if ax == 1 else 0,
                              1 if ax == 2 else 0)), "local " + "XYZ"[ax]))

    # Markers can sit slightly off-plane, which tilts the derived normal; a root
    # axis can be tilted instead. Score every candidate on how much of the model
    # it actually explains and keep the winner - never trust one blindly.
    def evaluate(lat_n):
        def lat(p):
            return p.dot(lat_n)
        res = []
        for name, pts in raw:
            c = sum(lat(p) for p in pts) / len(pts)
            ok = 0
            for v in pts:
                t = 2 * c - lat(v)
                vp = v - lat_n * lat(v)
                if any(abs(lat(u) - t) < SYM and ((u - lat_n * lat(u)) - vp).length < SYM
                       for u in pts):
                    ok += 1
            along = [p - lat_n * lat(p) for p in pts]
            res.append({"obj": name, "n": len(pts), "c": c, "sym": ok / len(pts),
                        "x": [min(p.x for p in along), max(p.x for p in along)],
                        "z": [min(p.z for p in along), max(p.z for p in along)]})
        return res

    pieces, axis, best = None, None, -1
    for n, label in cands:
        r = evaluate(n)
        score = sum(p["n"] for p in r if p["sym"] >= 0.99)
        if score > best:
            pieces, axis, best = r, label, score
    sym = [p for p in pieces if p["sym"] >= 0.99]
    if not sym:
        out[key] = {"error": "no mirror-symmetric pieces on any local axis"}
        continue
    bore = statistics.median([p["c"] for p in sym])
    rows = []
    for p in pieces:
        err = p["c"] - bore
        if p["sym"] < 0.99:
            verdict = "ASYMMETRIC"
        elif abs(err) <= TOL:
            verdict = "ON BORE"
        elif abs(err) <= PAIR_MIN:
            verdict = "DRIFT"
        else:
            twin = any(q is not p and q["sym"] >= 0.99 and abs((q["c"] - bore) + err) < 0.0015
                       for q in pieces)
            verdict = "PAIR" if twin else "ONE-SIDED"
        rows.append({"obj": p["obj"], "n": p["n"], "err_mm": err * 1000,
                     "sym": p["sym"], "verdict": verdict, "x": p["x"]})
    out[key] = {"bore": bore, "axis": axis, "rows": rows, "badtopo": badtopo}
print("RESULT " + json.dumps(out))
'''


def main():
    with open(MANIFEST) as fh:
        man = json.load(fh)
    want = sys.argv[1:]
    guns = {k: v for k, v in man["guns"].items() if not want or k in want}
    if not guns:
        sys.exit(f"no such gun(s): {want}; have {sorted(man['guns'])}")
    blend = os.path.join(ROOT, man["blend"].replace("/", os.sep))
    if not os.path.exists(BLENDER):
        sys.exit(f"blender not found at {BLENDER} (set RECON_BLENDER)")

    script = os.path.join(ROOT, "tools", "_align_inner.py")
    with open(script, "w") as fh:
        fh.write(INNER)
    try:
        r = subprocess.run([BLENDER, "-b", blend, "-P", script, "--", json.dumps(guns)],
                           capture_output=True, text=True)
    finally:
        os.remove(script)

    line = next((l for l in r.stdout.splitlines() if l.startswith("RESULT ")), None)
    if line is None:
        print(r.stdout[-3000:])
        print(r.stderr[-2000:])
        sys.exit("probe produced no result")

    data = json.loads(line[len("RESULT "):])
    failed = 0
    for gun, res in sorted(data.items()):
        print(f"\n=== {gun} ===")
        if "error" in res:
            print("   ERROR:", res["error"])
            failed += 1
            continue
        print(f"   symmetry plane from {res['axis']}   bore offset = {res['bore']:+.5f}")
        drift = [x for x in res["rows"] if x["verdict"] == "DRIFT"]
        counts = {}
        for x in res["rows"]:
            counts[x["verdict"]] = counts.get(x["verdict"], 0) + 1
        print("   " + "  ".join(f"{k}={v}" for k, v in sorted(counts.items())))
        for x in sorted(drift, key=lambda d: -abs(d["err_mm"])):
            print(f"   DRIFT  {x['obj']:<28} shell n={x['n']:<4} "
                  f"x[{x['x'][0]:+.4f},{x['x'][1]:+.4f}]  {x['err_mm']:+7.2f} mm off bore")
        for x in res["rows"]:
            if x["verdict"] == "ASYMMETRIC":
                print(f"   note   {x['obj']:<28} shell n={x['n']:<4} "
                      f"not mirror-symmetric ({x['sym']*100:.0f}%) - cannot be centred")
        for name, op, nm in res["badtopo"]:
            print(f"   TOPO   {name:<28} open edges={op} non-manifold={nm}")
        if drift:
            failed += 1
    print()
    if failed:
        sys.exit(f"ALIGNMENT: {failed} gun(s) have parts off the bore")
    print("ALIGNMENT: all checked guns are straight")


main()
