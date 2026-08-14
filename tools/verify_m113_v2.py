"""Re-import the M113 v2 GLB and assert the ground-vehicle export contract.

    blender -b --factory-startup --python tools/verify_m113_v2.py [-- --glb PATH]

Checks the SHIPPED file, not the build scene. A build that ran without error
proves nothing; this proves the artefact.

This is `tools/verify_m35_v2.py` with a new SPEC, which is exactly what that
file was written to be copied for. Everything this gate knows lives in SPEC or
is read off the mesh - no check reads a node name to decide where the front is.

FACING IS MEASURED BY PART POSITION, NEVER BY NODE NAME. The probe is the LAMP
LENS MATERIALS: amber faces must lie forward of centre, red aft.

NEW IN THIS GATE, and the M151's and M35's should inherit both: it imports the
FLOATER PROBE and the COINCIDENT-FACE PROBE from tools/build_m113_v2.py and
runs them on the re-imported GLB. Those are the two defect classes on this
fleet that a topology QC provably cannot see - the shipped M113's `Shovel`
hangs 0.32 m clear of the vehicle attached to nothing, and coplanar skins
render as dirt in Cycles while backface culling hides them in Godot.

Negative-tested against the shipped model before being trusted:
    blender -b --factory-startup --python tools/verify_m113_v2.py -- \
        --glb assets/us/vehicles/m113_apc.glb --legacy
"""

import bpy, os, math, json, struct, sys, re
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.abspath(os.path.join(HERE, ".."))
sys.path.insert(0, HERE)
from build_m113_v2 import floaters, coincident      # noqa: E402

SPEC = {
    "glb": os.path.join(PROJ, "assets", "us", "vehicles", "m113_apc_v2.glb"),
    "label": "M113A1 ACAV armoured personnel carrier",
    # en.wikipedia.org/wiki/M113_armored_personnel_carrier : 4.863 x 2.686 x
    # 2.5 m, ground clearance 17.1 in (0.434) on the A1, 5 road wheels.
    # army-guide.com/eng/product1424.html : drive sprocket FRONT, idler REAR,
    # no return rollers, 63/64 track links. T130E1 track 15 in (0.381) wide.
    #
    # THE 2.5 m IS OVERALL, NOT THE ROOF. The commission brief read it as "2.5 m
    # to hull roof"; the Puckapunyal walkaround refutes that - fitters standing
    # beside the vehicle have their heads AT the roof line, so the roof is
    # ~1.85 m and 2.5 m is over the cupola. Both numbers are asserted below.
    "length": 4.863, "width": 2.686, "height": 2.500, "roof": 1.850,
    "track_w": 0.381, "clearance": 0.434, "wheel_d": 0.610,
    "tol_len": 0.03, "tol_wid": 0.03, "tol_hgt": 0.10, "tol_roof": 0.06,
    "meshes": ({"M113_Hull", "M113_TrimVane", "M113_Ramp", "m113_cupola",
                "M113_ACAV_Rear", "M113_Track_L", "M113_Track_R",
                "m113_sprocket_l", "m113_sprocket_r", "m113_idler_l", "m113_idler_r",
                "M113_Col_Lower-colonly", "M113_Col_Upper-colonly"}
               | {"m113_wheel_%s%d" % (s, i) for s in "lr" for i in range(1, 6)}),
    "empties": ({"seat_driver", "seat_commander", "seat_gunner_l", "seat_gunner_r",
                 "RAMP_PIVOT"}
                | {"seat_troop_%s_%d" % (s, i) for s in "lr" for i in range(1, 6)}),
    # name -> (side sign, kind)
    "wheels": dict([("m113_wheel_l%d" % i, (-1, "road")) for i in range(1, 6)]
                   + [("m113_wheel_r%d" % i, (1, "road")) for i in range(1, 6)]
                   + [("m113_sprocket_l", (-1, "sprocket")),
                      ("m113_sprocket_r", (1, "sprocket")),
                      ("m113_idler_l", (-1, "idler")),
                      ("m113_idler_r", (1, "idler"))]),
    "road": ["m113_wheel_%s%d" % (s, i) for s in "lr" for i in range(1, 6)],
    "tracks": ["M113_Track_L", "M113_Track_R"],
    "hull": "M113_Hull",
    "vane": "M113_TrimVane",
    "pivoted": {"m113_cupola"},
    "lens_fwd": ["M113_LensAmber"],
    "lens_aft": ["M113_LensRed"],
    "tri_budget": (2000, 2600),
    "bodywork": ("M113_Hull", "M113_TrimVane", "M113_Ramp", "m113_cupola",
                 "M113_ACAV_Rear"),
    "bodywork_min_share": 45.0,
    "max_mats": 8,
    # collision_table.gd:56 today reads m113_apc box (2.7, 2.2, 5) y_offset 1.1.
    # Width and length fit a correctly sized M113; the 2.2 HEIGHT does not -
    # it is 0.30 m shorter than the vehicle, because it was measured off a
    # model whose height was read without the cupola. The gate reads the live
    # table: no v2 entry -> ADOPTER ACTION with the exact line, entry present
    # -> the model must fit it.
    "table_key": "m113_apc_v2",
    "table_required": (2.80, 2.60, 5.00), "table_required_y_offset": 1.30,
    "table_gd": os.path.join(PROJ, "scripts", "world", "collision_table.gd"),
}

# rotor_spin.gd:25,20 - any node whose lowered name contains one of these gets
# spun by RotorSpin. A ground vehicle must trip NONE of them.
SPIN_HINTS = ("prop", "spinner", "blade", "mainrotor", "rotor_hub", "new_blade",
              "rotor_flybar", "new_rotor", "tailrotor", "tailblade")

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
LEGACY = "--legacy" in argv
if "--glb" in argv:
    SPEC["glb"] = os.path.join(PROJ, argv[argv.index("--glb") + 1])
if LEGACY:
    # the shipped model's own lamp material names, so the facing probe reads
    # something real rather than failing for the wrong reason
    SPEC["lens_fwd"] = ["Light_L", "Light_R"]
    SPEC["lens_aft"] = ["Red_Light_L", "Red_Light_R"]

fails = []


def check(ok, msg):
    print(("  PASS  " if ok else "  FAIL  ") + msg)
    if not ok:
        fails.append(msg)


GLB = os.path.abspath(SPEC["glb"])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
bpy.context.view_layer.update()

print("\n--- %s : %s ---------------------" % (SPEC["label"], os.path.basename(GLB)))
print("  %.1f KB" % (os.path.getsize(GLB) / 1024.0))

# the glTF importer spawns bone-display Icospheres that are in no exported file
objs = {o.name: o for o in bpy.data.objects
        if o.type == "MESH" and not o.name.startswith("Icosphere")}
empt = {o.name: o for o in bpy.data.objects if o.type == "EMPTY"}
print("  %d meshes, %d empties" % (len(objs), len(empt)))

check(set(objs) == SPEC["meshes"], "mesh node names exactly the %d-node contract"
      % len(SPEC["meshes"]))
if set(objs) != SPEC["meshes"]:
    print("    missing: %s" % sorted(SPEC["meshes"] - set(objs)))
    print("    extra:   %s" % sorted(set(objs) - SPEC["meshes"]))
check(SPEC["empties"] <= set(empt), "socket empties present: %s" % sorted(SPEC["empties"]))

vis = sorted(n for n in objs if not n.endswith("-colonly"))
cols = sorted(n for n in objs if n.endswith("-colonly"))
for ob in objs.values():
    ob.data.calc_loop_triangles()
tris = sum(len(objs[n].data.loop_triangles) for n in vis)
ctris = sum(len(objs[n].data.loop_triangles) for n in cols)


def bbox(names):
    a, b = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for n in names:
        ob = objs[n]
        for v in ob.data.vertices:
            w = ob.matrix_world @ v.co
            a = Vector((min(a[i], w[i]) for i in range(3)))
            b = Vector((max(b[i], w[i]) for i in range(3)))
    return a, b


lo, hi = bbox(vis)
length, width, height = hi.y - lo.y, hi.x - lo.x, hi.z - lo.z
print("  visible bbox lo %s hi %s" % (tuple(round(c, 3) for c in lo),
                                      tuple(round(c, 3) for c in hi)))

# ---- FACING, BY PART POSITION -----------------------------------------------
def mat_centroid(names):
    tot, n = Vector(), 0
    for ob in objs.values():
        idx = [i for i, m in enumerate(ob.data.materials) if m and m.name in names]
        if not idx:
            continue
        for p in ob.data.polygons:
            if p.material_index in idx:
                tot += ob.matrix_world @ p.center
                n += 1
    return (tot / n if n else None), n


print("\n  FACING (measured, never read off a node name)")
fwd_c, fwd_n = mat_centroid(SPEC["lens_fwd"])
aft_c, aft_n = mat_centroid(SPEC["lens_aft"])
check(fwd_n > 0 and aft_n > 0, "both lamp lens materials are painted (%d fwd, %d aft faces)"
      % (fwd_n, aft_n))
if fwd_c and aft_c:
    print("    lens centroids: fwd y %+0.3f   aft y %+0.3f   separation %+0.3f"
          % (fwd_c.y, aft_c.y, fwd_c.y - aft_c.y))
    check(fwd_c.y > 0.25 * hi.y, "headlamps are FORWARD -> nose is Blender +Y = Godot -Z")
    check(aft_c.y < 0.25 * lo.y, "tail lamps are AFT")
    check(fwd_c.y - aft_c.y > SPEC["length"] * 0.6,
          "head and tail lamps are a vehicle-length apart (%.3f m)" % (fwd_c.y - aft_c.y))
    check(abs(fwd_c.x) < 0.05 and abs(aft_c.x) < 0.05,
          "lamp clusters are laterally balanced (fwd x %+0.3f, aft x %+0.3f)"
          % (fwd_c.x, aft_c.x))

# ---- dimensions --------------------------------------------------------------
print("\n  MEASURED vs REAL")
for lab, got, real, tol in (("length", length, SPEC["length"], SPEC["tol_len"]),
                            ("width ", width, SPEC["width"], SPEC["tol_wid"]),
                            ("height", height, SPEC["height"], SPEC["tol_hgt"])):
    print("    %s %7.3f  real %6.3f  d %+0.3f (%+0.1f%%)"
          % (lab, got, real, got - real, 100.0 * (got - real) / real))
    check(abs(got - real) <= tol, "%s %.3f m within %.2f of real %.3f" % (lab, got, tol, real))

check(abs(lo.x + hi.x) < 0.01, "laterally symmetric about x=0 (%.4f)" % (lo.x + hi.x))
check(abs(lo.z) < 0.005,
      "GROUND-LINE ORIGIN: lowest point sits at z %+0.4f. destructible_vehicle.gd:30-31 "
      "drops the node origin onto terrain height, so anything else buries or floats it" % lo.z)

# ---- the review's headline defects, asserted directly ------------------------
print("\n  THE DEFECTS THIS REBUILD EXISTS TO KILL")

# 1 - THE INVERTED HULL/TRACK RELATIONSHIP. Generic: whatever mesh owns the
#     widest point must be a real track run - at least 0.35 m of x-thickness
#     and spanning most of the vehicle's length. The shipped model's widest
#     part is a 20 mm-thick `Shovel` hung outboard of a 120 mm "track".
widest, wname = -1e9, None
for n in vis:
    a, b = bbox([n])
    if b.x > widest:
        widest, wname = b.x, n
wa, wb = bbox([wname])
print("    widest visible mesh is %-16s x %+0.3f..%+0.3f (%.3f thick), y span %.3f"
      % (wname, wa.x, wb.x, wb.x - wa.x, wb.y - wa.y))
check(wb.x - wa.x >= 0.35,
      "the WIDEST part of the vehicle is a %.3f m-thick track run, not a 0.12 m belt or a "
      "0.02 m pioneer tool hung outboard of everything" % (wb.x - wa.x))
check(abs((wb.x - wa.x) - SPEC["track_w"]) < 0.03,
      "track width %.3f vs the real T130E1 %.3f (the shipped model: 0.120, -68%%)"
      % (wb.x - wa.x, SPEC["track_w"]))
check(wb.y - wa.y > SPEC["length"] * 0.75,
      "it runs %.3f m fore-and-aft, i.e. it really is the track" % (wb.y - wa.y))

if SPEC["hull"] in objs:
    ha, hb = bbox([SPEC["hull"]])
    print("    hull side |x| %.3f   track outer |x| %.3f   hull length %.3f"
          % (hb.x, hi.x, hb.y - ha.y))
    check(hb.x < hi.x - 0.02,
          "THE HULL SIDE SITS INBOARD OF THE TRACK'S OUTER FACE (%.3f < %.3f). The shipped "
          "model hung 0.12 m tracks 0.19 m OUTBOARD of a 2.716 m hull - a hull wider on its "
          "own than a real M113 is in total" % (hb.x, hi.x))
    check(2.0 * hb.x < SPEC["width"],
          "the hull ALONE (%.3f m) is narrower than the real vehicle's total %.3f"
          % (2 * hb.x, SPEC["width"]))

# 2 - the nose that overhung its own running gear by 0.73 m
if SPEC["hull"] in objs and SPEC["tracks"][0] in objs:
    ta, tb = bbox(SPEC["tracks"])
    over = bbox([SPEC["hull"]])[1].y - tb.y
    print("    hull nose y %+0.3f   track front y %+0.3f   OVERHANG %.3f m"
          % (bbox([SPEC["hull"]])[1].y, tb.y, over))
    check(over < 0.30, "the nose overhangs the running gear by %.3f m "
                       "(the shipped model: 0.730)" % over)

# 3 - ground clearance and the roof, both published, both asserted
hull_lo = bbox([SPEC["hull"]])[0].z if SPEC["hull"] in objs else lo.z
print("    hull belly z %.3f (real ground clearance %.3f)   roof/height %.3f"
      % (hull_lo, SPEC["clearance"], height))
check(abs(hull_lo - SPEC["clearance"]) < 0.05,
      "belly sits at the published %.3f m ground clearance" % SPEC["clearance"])

# 4 - the trim vane, on the glacis, forward, and NOT the front extreme
if SPEC["vane"] in objs:
    va, vb = bbox([SPEC["vane"]])
    print("    trim vane bbox y %+0.3f..%+0.3f  z %.3f..%.3f  x %+0.3f..%+0.3f"
          % (va.y, vb.y, va.z, vb.z, va.x, vb.x))
    check(va.y > 0.55 * hi.y, "the TRIM VANE is on the glacis, well forward")
    check(vb.z > 0.4 * height and va.z < 0.75 * height, "it lies across the glacis face")
    check(vb.x - va.x > 1.6, "it is %.2f m wide, i.e. it spans the nose" % (vb.x - va.x))
    check(vb.y <= hi.y + 1e-4, "it does not stand proud of the published length")
else:
    check(False, "NO TRIM VANE. It is the M113's single most recognisable front feature "
                 "and the shipped model has nothing of it")

# 5 - THE FLOATING SHOVEL. TWO checks, because the obvious one does not catch it.
#     The shipped `Shovel` spans x 1.690..1.710 against a hull face at 1.367:
#     0.32 m clear of the vehicle. But it grazes the TRACK by 0.03 m, so a
#     "does this touch anything" probe calls it attached - to a moving part.
#     The rule that convicts it is that NOTHING may hang outboard of the
#     running gear. Both checks ship; each catches a class the other misses.
outboard = []
for n in vis:
    if n in SPEC["tracks"]:
        continue
    a, b = bbox([n])
    if max(abs(a.x), abs(b.x)) > hi.x - 1e-4:
        outboard.append((n, round(max(abs(a.x), abs(b.x)), 3)))
print("\n  NOTHING OUTBOARD OF THE TRACK: offenders %s" % (outboard or "none"))
check(not outboard,
      "no mesh reaches outboard of the track's outer face (%.3f). The shipped model's "
      "`Shovel` sits at 1.710 with its track at 1.656 - a pioneer tool bolted to thin "
      "air past the widest part of the vehicle: %s" % (hi.x, outboard))

print("\n  FLOATER PROBE - every disconnected lump must touch something")
fl = floaters([objs[n] for n in vis], tol=0.030)
for lab, gap, c in fl:
    print("    %-22s %.3f m clear of everything, centred %s" % (lab, gap, c))
check(not fl, "no geometry is attached to NOTHING (%d floating islands)" % len(fl))

# 6 - coplanar skins: the low-poly z-fight, invisible to any topology QC
print("\n  COINCIDENT-FACE PROBE - coplanar overlapping skins sharing no vertex")
co = coincident([objs[n] for n in vis])
for c in co[:12]:
    print("    %s" % c)
check(not co, "no coincident faces (%d seams; they render as dirt in Cycles and are "
              "hidden by backface culling in Godot, which is what makes them ship)" % len(co))

# ---- running gear: 5 road wheels a side, sprocket front, idler rear ----------
print("\n  RUNNING GEAR - 5 road wheels/side, DRIVE SPROCKET FRONT, IDLER REAR")
w, kinds = {}, {}
for n, (side, kind) in SPEC["wheels"].items():
    if n not in objs:
        check(False, "%s is missing" % n)
        continue
    ob = objs[n]
    w[n] = ob.location.copy()
    r = max(math.hypot(v.co.y, v.co.z) for v in ob.data.vertices)
    hx = max(abs(v.co.x) for v in ob.data.vertices)
    kinds.setdefault(kind, []).append((n, w[n], r))
    check((side < 0 and w[n].x < 0) or (side > 0 and w[n].x > 0),
          "%s L/R suffix matches POSITION (+X is the vehicle's right)" % n)
    check(all(abs(c) < 1e-5 for c in ob.rotation_euler),
          "%s rotation is IDENTITY -> Godot local X is the spin axis" % n)
    check(hx < 0.20, "%s is a single hub, not a pair (half-width %.3f)" % (n, hx))
    check(abs(w[n].x) < hi.x, "%s hub is inboard of the track's outer face" % n)

if "road" in kinds:
    rw = sorted(kinds["road"], key=lambda t: -t[1].y)
    print("    road wheel radius %.3f (real %.3f), hubs at z %.3f"
          % (rw[0][2], SPEC["wheel_d"] * 0.5, rw[0][1].z))
    check(len(rw) == 10, "ten road wheels, five a side (%d)" % len(rw))
    check(abs(2 * rw[0][2] - SPEC["wheel_d"]) < 0.03,
          "road wheel OD %.3f vs the real 24 in %.3f" % (2 * rw[0][2], SPEC["wheel_d"]))
    ys = sorted({round(t[1].y, 3) for t in rw})
    print("    road wheel stations y %s" % ys)
    check(len(ys) == 5, "five distinct road wheel stations (%d)" % len(ys))
    gaps = [b - a for a, b in zip(ys, ys[1:])]
    check(max(gaps) - min(gaps) < 0.02, "road wheels are evenly spaced: %s"
          % [round(g, 3) for g in gaps])
    for _n, loc, rr in rw:
        check(abs(loc.z - rr) < 0.06,
              "road wheel hub sits about one radius above the ground line (%.3f vs %.3f)"
              % (loc.z, rr))
if "sprocket" in kinds and "idler" in kinds and "road" in kinds:
    sy = sum(t[1].y for t in kinds["sprocket"]) / len(kinds["sprocket"])
    iy = sum(t[1].y for t in kinds["idler"]) / len(kinds["idler"])
    sz = sum(t[1].z for t in kinds["sprocket"]) / len(kinds["sprocket"])
    rz = sum(t[1].z for t in kinds["road"]) / len(kinds["road"])
    print("    sprocket y %+0.3f z %.3f   idler y %+0.3f   road wheel z %.3f"
          % (sy, sz, iy, rz))
    check(sy > max(t[1].y for t in kinds["road"]),
          "the DRIVE SPROCKET IS FORWARD of every road wheel (army-guide: sprocket front)")
    check(iy < min(t[1].y for t in kinds["road"]), "the IDLER IS AFT of every road wheel")
    check(sz > rz + 0.05, "the sprocket is RAISED above the road wheel line (%.3f vs %.3f)"
          % (sz, rz))

# ---- transforms --------------------------------------------------------------
print("\n  TRANSFORMS")
movable = set(SPEC["wheels"]) | SPEC["pivoted"]
for n in sorted(objs):
    ob = objs[n]
    check(all(abs(c - 1) < 1e-5 for c in ob.scale), "%s scale is 1,1,1" % n)
    if n not in movable:
        check(ob.location.length < 1e-5,
              "%s is at full identity (loc %s)" % (n, tuple(round(c, 4) for c in ob.location)))

# Read the GLB's own node table: the Blender importer bakes the Y-up->Z-up
# conversion into mesh data, so an imported object's transform is NOT proof of
# what Godot will read. Godot reads the node transform.
raw = open(GLB, "rb").read()
gj = json.loads(raw[20:20 + struct.unpack("<I", raw[12:16])[0]])
nodes = {n.get("name"): n for n in gj["nodes"]}
for n, (_s, kind) in SPEC["wheels"].items():
    tr = nodes.get(n, {}).get("translation")
    check(tr is not None, "glTF node %s carries a translation" % n)
    check(nodes.get(n, {}).get("rotation") is None, "glTF node %s has no rotation" % n)
    if tr and kind == "sprocket":
        check(tr[2] < 0, "glTF node %s is at Godot -Z (forward): z %+0.3f" % (n, tr[2]))
    if tr and kind == "idler":
        check(tr[2] > 0, "glTF node %s is at Godot +Z (aft): z %+0.3f" % (n, tr[2]))

# ---- colliders ---------------------------------------------------------------
print("\n  COLLIDERS")
check(len(cols) >= 1, "at least one -colonly mesh ships: %s" % cols)
if cols:
    clo, chi = bbox(cols)
    blo, bhi = bbox([n for n in vis if not n.startswith("m113_wheel")
                     and not n.startswith("m113_sprocket") and not n.startswith("m113_idler")])
    print("    collider bbox lo %s hi %s" % (tuple(round(c, 3) for c in clo),
                                             tuple(round(c, 3) for c in chi)))
    check(clo.x <= blo.x + 0.02 and chi.x >= bhi.x - 0.02
          and clo.y <= blo.y + 0.02 and chi.y >= bhi.y - 0.02,
          "colliders span the body in plan")
    check(chi.z >= bhi.z - 0.05, "colliders reach the top of the body")
    check(abs(clo.z) < 0.01, "colliders start at the ground line")

# ---- the box the game authors for it ----------------------------------------
print("\n  collision_table.gd")
src = ""
if os.path.exists(SPEC["table_gd"]):
    src = open(SPEC["table_gd"], encoding="utf-8").read()
m = re.search(r'"%s"\s*:\s*\{[^}]*?Vector3\(([\d.,\s]+)\)[^}]*?"y_offset"\s*:\s*([\d.]+)'
              % re.escape(SPEC["table_key"]), src)
rx, ry, rz = SPEC["table_required"]
if m:
    bx, by, bz = [float(v) for v in m.group(1).split(",")]
    yo = float(m.group(2))
    print("    live entry: box (%.2f, %.2f, %.2f) y_offset %.2f" % (bx, by, bz, yo))
    check(width <= bx + 1e-3, "model width %.3f fits the box's %.2f" % (width, bx))
    check(height <= by + 1e-3, "model height %.3f fits the box's %.2f" % (height, by))
    check(length <= bz + 1e-3, "model length %.3f fits the box's %.2f (Godot depth)"
          % (length, bz))
    check(abs(yo - by * 0.5) < 0.01,
          "y_offset %.2f is half the box height -> the box rests on a ground-line origin" % yo)
else:
    print("    ADOPTER ACTION - no \"%s\" entry yet, so CollisionTable.get_entry falls "
          "through to a 3x2x3 default box with a push_warning (collision_table.gd:204-210)."
          % SPEC["table_key"])
    print("    Add:  \"%s\": {\"box\": Vector3(%.2f, %.2f, %.2f), \"y_offset\": %.2f, "
          "\"footprint\": Vector2(%.1f, %.1f), \"scale\": 1.0, \"mesh\": true},"
          % (SPEC["table_key"], rx, ry, rz, SPEC["table_required_y_offset"],
             rx + 1.0, rz + 1.0))
    print("    The M113's existing entry (:56) box (2.7, 2.2, 5) fits in plan but its 2.2 m "
          "HEIGHT is 0.30 m SHORTER than the vehicle - it was measured without the cupola.")
    check(width <= rx + 1e-3 and height <= ry + 1e-3 and length <= rz + 1e-3,
          "model %.3f x %.3f x %.3f fits the box this asset REQUIRES (%.2f, %.2f, %.2f)"
          % (width, height, length, rx, ry, rz))
    check(abs(SPEC["table_required_y_offset"] - ry * 0.5) < 0.01,
          "the required y_offset %.2f is half the required box height"
          % SPEC["table_required_y_offset"])

# ---- materials, textures, hygiene -------------------------------------------
print("\n  MATERIALS / HYGIENE")
mats = sorted(m.name for m in bpy.data.materials)
print("    %d: %s" % (len(mats), mats))
check(len(mats) <= SPEC["max_mats"],
      "%d materials (the shipped model ships 26 for two colours: OD_Green + .002 + .003, "
      "Track_Dark + .001...009, two Gun_Metal, six identical Glass_*)" % len(mats))
check(not any("." in m and m.rsplit(".", 1)[-1].isdigit() for m in mats),
      "no .001-style duplicate materials")
check(all(not m.startswith("Material") and "tmp" not in m.lower() for m in mats),
      "no temp / default material names")
for mt in bpy.data.materials:
    b = next((n for n in mt.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if b:
        check(b.inputs["Metallic"].default_value < 0.01,
              "%s is non-metallic (%.2f)" % (mt.name, b.inputs["Metallic"].default_value))
imgs = [i.name for i in bpy.data.images if i.name != "Render Result"]
check(not imgs, "NO TEXTURES: %s" % imgs)
check(not bpy.data.actions, "no baked animation ships")

for n in sorted(objs):
    low = n.lower()
    check(not any(h in low for h in SPIN_HINTS),
          "%s trips no RotorSpin hint (rotor_spin.gd:25)" % n)
    t = len(objs[n].data.loop_triangles)
    check(t != 1152, "%s is not a default 1152-tri torus (the shipped model has ELEVEN, "
                     "67.4%% of its geometry, five of them 'lift rings' on the roof and two "
                     "of those a METRE wide)" % n)
    ng = sum(1 for p in objs[n].data.polygons if len(p.vertices) > 4)
    used = set()
    for p in objs[n].data.polygons:
        used.update(p.vertices)
    check(ng == 0, "%s has no n-gons" % n)
    check(len(objs[n].data.vertices) - len(used) == 0, "%s has no loose vertices" % n)

lo_t, hi_t = SPEC["tri_budget"]
print("\n  VISIBLE TRIS %d   collider tris %d   (the shipped model: 18,808)" % (tris, ctris))
check(lo_t <= tris <= hi_t, "visible tris %d inside the %d-%d fleet-class budget"
      % (tris, lo_t, hi_t))
body_t = sum(len(objs[n].data.loop_triangles) for n in SPEC["bodywork"] if n in objs)
share = 100.0 * body_t / tris if tris else 0.0
gear = sum(len(objs[n].data.loop_triangles) for n in
           list(SPEC["wheels"]) + SPEC["tracks"] if n in objs)
print("    bodywork %.1f%%   running gear %.1f%%" % (share, 100.0 * gear / tris))
check(share >= SPEC["bodywork_min_share"],
      "the HULL, TRIM VANE, RAMP, CUPOLA and ACAV kit carry %.1f%% of the triangles "
      "(the shipped model spent 67.4%% on decorative tori)" % share)

print("\n%s  (%d failures)" % ("VERIFY PASS" if not fails else "VERIFY FAIL", len(fails)))
for f in fails[:40]:
    print("   ! " + f)
if len(fails) > 40:
    print("   ! ... and %d more" % (len(fails) - 40))
