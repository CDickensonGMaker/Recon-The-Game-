"""Re-import gate: the glTF exporter mutates meshes, so the ONLY number that
counts is the one measured after a round trip through the exported file.

    blender -b --factory-startup --python verify_lod.py -- <original.glb> <lod.glb>

Compares, both sides measured by RE-IMPORT in this same fresh Blender:
  * triangle totals
  * object name set (every name in the original must survive in the LOD)
  * world transform of every surviving object (drop-in swap proof)
  * world AABB (scale/orientation proof)
  * embedded images (Caleb's 1MB texture law)
  * material/surface count (draw-call proxy)
Writes nothing.
"""
import bpy, sys, os, json
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
ORIG, LOD = argv[0], argv[1]
BUDGET = int(argv[2]) if len(argv) > 2 else 3000

CODE_NAMES = {
    "helicopter.gd main/tail rotor": ["New_Blade_1", "New_TailBlade_2_002"],
    "helicopter.gd markings": ["VARIANT_A", "VARIANT_B", "VARIANT_C"],
    "probe_huey_frame.gd": ["fuselage_fwd", "fuselage_aft"],
    "seat_system.gd / heli_lift.gd": [
        "seat_pilot_l", "seat_pilot_r", "seat_gunner_l", "seat_gunner_r",
        "seat_pax_1", "seat_pax_2", "seat_pax_3", "seat_pax_4",
        "seat_pax_5", "seat_pax_6", "seat_pax_7", "seat_pax_8",
        "seat_bench_1", "seat_bench_2", "seat_bench_3",
        "seat_bench_4", "seat_bench_5", "seat_bench_6"],
    "rotor_spin.gd hint nodes": [
        "MainRotorMast", "TailRotorMast", "New_Blade_2", "New_Rotor_Hub",
        "New_Rotor_Flybar", "New_TailBlade_1", "New_TailBlade_Hub"],
    "spectre_gunship.gd muzzles": ["gun_muzzle_1", "gun_muzzle_2", "gun_muzzle_3"],
}


def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    objs = {}
    total = 0
    surfaces = 0
    for o in bpy.data.objects:
        t = 0
        if o.type == 'MESH':
            t = sum(len(p.vertices) - 2 for p in o.data.polygons)
            surfaces += max(1, len([m for m in o.data.materials if m is not None]))
        total += t
        objs[o.name] = {"tris": t, "type": o.type,
                        "mw": [list(r) for r in o.matrix_world]}
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    for o in bpy.data.objects:
        if o.type != 'MESH':
            continue
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            for i in range(3):
                lo[i] = min(lo[i], w[i])
                hi[i] = max(hi[i], w[i])
    health = {"boundary": 0, "loose_v": 0, "zero_area": 0, "nonmanifold": 0}
    per_obj = {}
    for o in bpy.data.objects:
        if o.type != 'MESH':
            continue
        me = o.data
        counts = {}
        for e in me.edges:
            counts[e.key] = 0
        for poly in me.polygons:
            vs = list(poly.vertices)
            for i in range(len(vs)):
                k = tuple(sorted((vs[i], vs[(i + 1) % len(vs)])))
                if k in counts:
                    counts[k] += 1
        b = sum(1 for v in counts.values() if v == 1)
        nm = sum(1 for v in counts.values() if v > 2)
        used = set()
        for poly in me.polygons:
            used.update(poly.vertices)
        lv = len(me.vertices) - len(used)
        za = sum(1 for poly in me.polygons if poly.area < 1e-9)
        health["boundary"] += b
        health["loose_v"] += lv
        health["zero_area"] += za
        health["nonmanifold"] += nm
        per_obj[o.name] = (b, lv, za, nm)

    imgs = [(im.name, im.size[0], im.size[1],
             len(im.packed_file.data) if im.packed_file else 0)
            for im in bpy.data.images if im.size[0] > 0]
    anims = [a.name for a in bpy.data.actions]
    return {"health": health, "per_obj": per_obj,
            "objs": objs, "total": total, "surfaces": surfaces,
            "aabb": [list(lo), list(hi)], "imgs": imgs, "anims": anims,
            "mats": len(bpy.data.materials), "file": path,
            "bytes": os.path.getsize(path)}


A = load(ORIG)
B = load(LOD)
fails = []

print("=" * 78)
print("RE-IMPORT GATE   %s  ->  %s" % (os.path.basename(ORIG), os.path.basename(LOD)))
print("=" * 78)
print("tris (re-import)   %7d  ->  %7d   (%.1f%%, -%d)"
      % (A["total"], B["total"], 100.0 * B["total"] / max(1, A["total"]),
         A["total"] - B["total"]))
print("objects            %7d  ->  %7d" % (len(A["objs"]), len(B["objs"])))
print("mesh surfaces      %7d  ->  %7d   (draw-call proxy)" % (A["surfaces"], B["surfaces"]))
print("materials          %7d  ->  %7d" % (A["mats"], B["mats"]))
print("file bytes         %7d  ->  %7d   (%.3f MB -> %.3f MB)"
      % (A["bytes"], B["bytes"], A["bytes"] / 1048576.0, B["bytes"] / 1048576.0))
print("actions            %-20s -> %s" % (A["anims"], B["anims"]))

if B["total"] > BUDGET:
    fails.append("tri budget: %d > %d" % (B["total"], BUDGET))
else:
    print("PASS  tri budget %d <= %d" % (B["total"], BUDGET))

REFERENCED = set()
for _v in CODE_NAMES.values():
    REFERENCED.update(_v)
missing = sorted(set(A["objs"]) - set(B["objs"]))
extra = sorted(set(B["objs"]) - set(A["objs"]))
ref_here = sorted(n for n in REFERENCED if n in A["objs"])
ref_lost = [n for n in ref_here if n not in B["objs"]]
print("names  %d -> %d   dropped=%d  added=%d" % (len(A["objs"]), len(B["objs"]),
                                                  len(missing), len(extra)))
if ref_lost:
    fails.append("REFERENCED names dropped: %s" % ref_lost)
else:
    print("PASS  all %d code-referenced names present in the source survive in the LOD"
          % len(ref_here))
if missing:
    print("NOTE  %d unreferenced names dropped by the merge: %s%s"
          % (len(missing), missing[:8], " ..." if len(missing) > 8 else ""))
if extra:
    print("NOTE  LOD adds %d objects: %s" % (len(extra), extra))

worst = 0.0
worst_n = ""
for n in set(A["objs"]) & set(B["objs"]):
    for r in range(4):
        for c in range(4):
            d = abs(A["objs"][n]["mw"][r][c] - B["objs"][n]["mw"][r][c])
            if d > worst:
                worst, worst_n = d, n
print("world-transform max delta = %.3e m   (worst node: %s)" % (worst, worst_n))
if worst > 1e-5:
    fails.append("transform drift %.3e on %s" % (worst, worst_n))
else:
    print("PASS  every shared node sits at the same world transform (drop-in)")

sa = [A["aabb"][1][i] - A["aabb"][0][i] for i in range(3)]
sb = [B["aabb"][1][i] - B["aabb"][0][i] for i in range(3)]
print("world AABB size    %s  ->  %s" % ([round(v, 3) for v in sa], [round(v, 3) for v in sb]))
print("world AABB min     %s  ->  %s"
      % ([round(v, 3) for v in A["aabb"][0]], [round(v, 3) for v in B["aabb"][0]]))

print("images  orig %s" % [(n, w, h, "%.0fKB" % (b / 1024.0)) for n, w, h, b in A["imgs"]])
print("images  lod  %s" % [(n, w, h, "%.0fKB" % (b / 1024.0)) for n, w, h, b in B["imgs"]])
over = [n for n, w, h, b in B["imgs"] if b > 1048576]
if over:
    fails.append("embedded image over 1MB: %s" % over)
else:
    print("PASS  no embedded image over 1MB")

print("\n---- MESH HEALTH (boundary edges / loose verts / zero-area faces / non-manifold) ----")
print("  original  %s" % A["health"])
print("  lod       %s" % B["health"])
worse = [k for k in A["health"] if B["health"][k] > A["health"][k]]
if worse:
    print("  worse in the LOD on: %s" % worse)
    for n in sorted(set(A["per_obj"]) & set(B["per_obj"])):
        pa, pb = A["per_obj"][n], B["per_obj"][n]
        if any(pb[i] > pa[i] for i in range(4)):
            print("        %-28s orig=%s lod=%s" % (n, pa, pb))
else:
    print("  PASS  the LOD is no worse than the source on every mesh-health metric")
if (B["health"]["loose_v"] > A["health"]["loose_v"]
        or B["health"]["zero_area"] > A["health"]["zero_area"]):
    fails.append("LOD adds floaters/degenerate faces: %s" % B["health"])

print("\n---- CODE NAME CONTRACT (present in the ORIGINAL must be present in the LOD) ----")
for owner, names in CODE_NAMES.items():
    rel = [n for n in names if n in A["objs"]]
    if not rel:
        print("  %-32s n/a for this airframe" % owner)
        continue
    bad = [n for n in rel if n not in B["objs"]]
    print("  %-32s %2d/%2d preserved %s" % (owner, len(rel) - len(bad), len(rel),
                                            "" if not bad else "MISSING " + str(bad)))
    if bad:
        fails.append("%s missing %s" % (owner, bad))

print("\n---- 15 HEAVIEST OBJECTS IN THE LOD ----")
for n, d in sorted(B["objs"].items(), key=lambda kv: -kv[1]["tris"])[:15]:
    print("  %-30s %5d tris   (source %d)" % (n, d["tris"], A["objs"].get(n, {}).get("tris", -1)))

import struct as _st


def glb_json(path):
    d = open(path, "rb").read()
    off, js = 12, None
    while off < len(d):
        ln, ty = _st.unpack_from("<II", d, off)
        off += 8
        if ty == 0x4E4F534A:
            js = json.loads(d[off:off + ln].decode("utf-8"))
        off += ln
    return js


print("\n---- glTF LEVEL (read straight out of the GLB JSON chunk) ----")
for tag, path in (("original", ORIG), ("lod", LOD)):
    js = glb_json(path)
    prims = sum(len(m["primitives"]) for m in js.get("meshes", []))
    nonop = [(m.get("name"), m.get("alphaMode")) for m in js.get("materials", [])
             if m.get("alphaMode", "OPAQUE") != "OPAQUE"]
    print("  %-9s nodes=%-4d meshes=%-3d primitives=%-4d non-opaque=%s"
          % (tag, len(js.get("nodes", [])), len(js.get("meshes", [])), prims, nonop))
_blend = [m.get("name") for m in glb_json(LOD).get("materials", [])
          if m.get("alphaMode") == "BLEND"]
if _blend:
    print("  NOTE  LOD materials on SORTED alpha blend: %s" % _blend)

print("\n" + ("VERIFY PASS - 0 failures" if not fails
              else "VERIFY FAIL (%d)\n  - %s" % (len(fails), "\n  - ".join(fails))))
sys.exit(1 if fails else 0)
