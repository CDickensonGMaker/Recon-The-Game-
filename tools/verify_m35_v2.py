"""Re-import the M35 v2 GLB and assert the ground-vehicle export contract.

    blender -b --factory-startup --python tools/verify_m35_v2.py [-- --glb PATH]

Checks the SHIPPED file, not the build scene. A build that ran without error
proves nothing; this proves the artefact.

This is `tools/verify_m151_v2.py` with a new SPEC, which is exactly what that
file was written to be copied for. Everything this gate knows lives in SPEC or
is read off the mesh - no check reads a node name to decide where the front is.

FACING IS MEASURED BY PART POSITION, NEVER BY NODE NAME. The probe is the LENS
MATERIALS: amber lamp faces must lie forward of centre, red lamp faces aft. The
shipped `m35_deuce_truck.glb` has a node called `Grille` and it drives BACKWARDS;
a node name proves nothing, a headlamp 3.3 m forward of the origin does.

Negative-tested against that shipped truck before being trusted:
    blender -b --factory-startup --python tools/verify_m35_v2.py -- \
        --glb assets/us/vehicles/m35_deuce_truck.glb --legacy
"""

import bpy, os, math, json, struct, sys, re
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.abspath(os.path.join(HERE, ".."))

SPEC = {
    "glb": os.path.join(PROJ, "assets", "us", "vehicles", "m35_deuce_truck_v2.glb"),
    "label": "M35A2 deuce-and-a-half cargo truck",
    # en.wikipedia.org/wiki/M35_series_2%C2%BD-ton_6%C3%976_cargo_truck +
    # truck-encyclopedia.com/coldwar/us/M35-truck.php +
    # generalequipment.info/M35A2.htm (bed floor 50 in). WHEELBASE AND BOGIE are
    # measured off the walkaround against the 9.00x20 tyre OD - see the notes.
    "length": 6.980, "width": 2.438, "height": 3.000,
    "wheelbase": 3.912, "bogie": 1.118, "track": 1.645, "tyre_od": 1.054,
    "bed_floor_z": 1.270, "bed_len": 3.658,
    "tol_len": 0.03, "tol_wid": 0.03, "tol_hgt": 0.10,
    "meshes": {"M35_Body", "M35_Windscreen", "M35_CargoBed", "M35_Tarp",
               "m35_wheel_fl", "m35_wheel_fr", "m35_wheel_ml", "m35_wheel_mr",
               "m35_wheel_rl", "m35_wheel_rr",
               "M35_Col_Lower-colonly", "M35_Col_Upper-colonly"},
    "empties": {"seat_driver", "seat_passenger", "TAILGATE_PIVOT"}
               | {"seat_troop_%s_%d" % (s, i) for s in "lr" for i in range(1, 6)},
    # name -> (side sign, axle key, is a DUAL PAIR)
    "wheels": {"m35_wheel_fl": (-1, "f", False), "m35_wheel_fr": (1, "f", False),
               "m35_wheel_ml": (-1, "m", True), "m35_wheel_mr": (1, "m", True),
               "m35_wheel_rl": (-1, "r", True), "m35_wheel_rr": (1, "r", True)},
    "pivoted": set(),                 # no traversing mount on a cargo truck
    "lens_fwd": "M35_LensAmber",      # headlights + fender markers
    "lens_aft": "M35_LensRed",        # tail lamps
    "tri_budget": (1800, 2600),
    "bodywork": ("M35_Body", "M35_CargoBed", "M35_Tarp"),
    "bodywork_min_share": 45.0,
    "tarp": "M35_Tarp",
    # collision_table.gd:154 today reads box (2.1, 3.3, 5.8) / y_offset 1.60,
    # and it was measured off the OLD truck, so it inherits that truck's -17%
    # length and -11% width. A correctly sized deuce cannot fit it. The gate
    # reads the live table: no entry yet -> ADOPTER ACTION, entry present ->
    # the model must fit it.
    "table_key": "m35_deuce_truck_v2",
    "table_required": (2.50, 3.20, 7.10), "table_required_y_offset": 1.60,
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
    # the shipped truck's own lens material names, so the facing probe has
    # something real to read rather than failing for the wrong reason
    SPEC["lens_fwd"], SPEC["lens_aft"] = "HeadlightGlass", "RedLight_-0.45"

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
print("  meshes:  %s" % sorted(objs))
print("  empties: %s" % sorted(empt))

check(set(objs) == SPEC["meshes"], "mesh node names exactly %s" % sorted(SPEC["meshes"]))
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
def mat_centroid(mat_name):
    tot, n = Vector(), 0
    for ob in objs.values():
        idx = [i for i, m in enumerate(ob.data.materials) if m and m.name == mat_name]
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
    print("    lens centroids: %s at y %+0.3f   %s at y %+0.3f"
          % (SPEC["lens_fwd"], fwd_c.y, SPEC["lens_aft"], aft_c.y))
    print("    head-to-tail separation: dy %+0.3f  dx %+0.3f" % (fwd_c.y - aft_c.y,
                                                                 fwd_c.x - aft_c.x))
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

# ---- the review's two headline defects, asserted directly --------------------
print("\n  THE DEFECTS THIS REBUILD EXISTS TO KILL")
if "M35_CargoBed" in objs and "M35_Body" in objs:
    blo, bhi = bbox(["M35_Body"])
    dlo, dhi = bbox(["M35_CargoBed"])
    cab_w, bed_w = bhi.x - blo.x, dhi.x - dlo.x
    print("    cab/front-end width %.3f   cargo bed width %.3f   ratio %.2f"
          % (cab_w, bed_w, cab_w / bed_w))
    check(cab_w / bed_w > 0.82,
          "the CAB IS NOT HALF THE WIDTH OF ITS OWN BED (%.0f%% of it; the shipped "
          "truck was 1.05 m against a 2.10 m bed = 50%%)" % (100.0 * cab_w / bed_w))
if SPEC["tarp"] in objs:
    tlo, thi = bbox([SPEC["tarp"]])
    above = []
    for n in vis:
        if n == SPEC["tarp"]:
            continue
        for v in objs[n].data.vertices:
            if (objs[n].matrix_world @ v.co).z > thi.z + 1e-4:
                above.append(n)
                break
    print("    tarp crown z %.3f ; parts standing proud of it: %s" % (thi.z, above or "none"))
    check(not above,
          "NOTHING SITS ON TOP OF THE CANVAS. The shipped truck's BowRail_+-0.93 "
          "spanned z 2.212-2.242 over a Canvas_Top at 2.113-2.143 - it wore a metal "
          "cage over its own cover")
    check(abs((tlo.x + thi.x)) < 0.01,
          "the tarp is CENTRED (the shipped Canvas_Top ran x -0.934..+1.010, a 7.6 cm "
          "overhang to one side): x %+0.3f..%+0.3f" % (tlo.x, thi.x))

# ---- wheels: 6x6, named, placed, L/R correct BY POSITION ---------------------
print("\n  WHEELS - 6x6, single front, DUAL rear tandem")
w, axles = {}, {}
for n, (side, axle, dual) in SPEC["wheels"].items():
    if n not in objs:
        check(False, "%s is missing" % n)
        continue
    ob = objs[n]
    w[n] = ob.location.copy()
    hx = max(abs(v.co.x) for v in ob.data.vertices)
    r = max(math.hypot(v.co.y, v.co.z) for v in ob.data.vertices)
    axles.setdefault(axle, []).append(w[n])
    print("    %-16s hub %s  half-width %.3f  radius %.3f  %s"
          % (n, tuple(round(c, 4) for c in w[n]), hx, r, "DUAL" if dual else "single"))
    check((side < 0 and w[n].x < 0) or (side > 0 and w[n].x > 0),
          "%s L/R suffix matches POSITION (+X is the vehicle's right; m35_rigged.blend "
          "has this pair INVERTED and it must not be inherited)" % n)
    check(abs(2 * r - SPEC["tyre_od"]) < 0.02,
          "%s tyre OD %.3f vs real %.3f, mesh centred on its own hub" % (n, 2 * r, SPEC["tyre_od"]))
    check(abs(w[n].z - SPEC["tyre_od"] * 0.5) < 0.01,
          "%s hub sits one tyre radius above the ground line" % n)
    check(all(abs(c) < 1e-5 for c in ob.rotation_euler),
          "%s rotation is IDENTITY -> Godot local X is the spin axis" % n)
    # a dual pair is two tyres on one hub; a single is one
    check(hx > 0.24 if dual else hx < 0.14,
          "%s mesh %s a dual pair (half-width %.3f)"
          % (n, "IS" if dual else "is NOT", hx))

if len(axles) == 3:
    fy = sum(v.y for v in axles["f"]) / 2.0
    my = sum(v.y for v in axles["m"]) / 2.0
    ry = sum(v.y for v in axles["r"]) / 2.0
    wb = fy - (my + ry) * 0.5
    bg = my - ry
    tr = abs(axles["f"][0].x) + abs(axles["f"][1].x)
    print("    axles at y  front %+0.3f  mid %+0.3f  rear %+0.3f" % (fy, my, ry))
    check(fy > my > ry, "the three axles run front-to-back in order")
    check(abs(wb - SPEC["wheelbase"]) < 0.02,
          "wheelbase %.3f m (front axle -> bogie centre) vs %.3f" % (wb, SPEC["wheelbase"]))
    check(abs(bg - SPEC["bogie"]) < 0.02,
          "tandem bogie spacing %.3f m vs %.3f" % (bg, SPEC["bogie"]))
    check(abs(tr - SPEC["track"]) < 0.02, "front track %.3f m vs %.3f" % (tr, SPEC["track"]))
    for k, v in axles.items():
        check(abs(v[0].x + v[1].x) < 1e-4, "the %s axle is centred on x=0" % k)

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
for n, (_s, axle, _d) in SPEC["wheels"].items():
    tr = nodes.get(n, {}).get("translation")
    check(tr is not None and abs(tr[1] - SPEC["tyre_od"] * 0.5) < 0.01,
          "glTF node %s translation %s - Godot +Y is up, so the hub is one radius high"
          % (n, [round(c, 4) for c in tr] if tr else None))
    check(nodes.get(n, {}).get("rotation") is None, "glTF node %s has no rotation" % n)
    if tr and axle == "f":
        check(tr[2] < 0, "glTF node %s is at Godot -Z (forward): z %+0.3f" % (n, tr[2]))
    if tr and axle == "r":
        check(tr[2] > 0, "glTF node %s is at Godot +Z (aft): z %+0.3f" % (n, tr[2]))

# ---- colliders ---------------------------------------------------------------
print("\n  COLLIDERS")
check(len(cols) >= 1, "at least one -colonly mesh ships: %s" % cols)
if cols:
    clo, chi = bbox(cols)
    blo, bhi = bbox([n for n in vis if not n.startswith("m35_wheel")])
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
    check(length <= bz + 1e-3, "model length %.3f fits the box's %.2f (Godot depth)" % (length, bz))
    check(abs(yo - by * 0.5) < 0.01,
          "y_offset %.2f is half the box height -> the box rests on a ground-line origin" % yo)
else:
    print("    ADOPTER ACTION - no \"%s\" entry yet, so CollisionTable.get_entry falls "
          "through to a 3x2x3 default box with a push_warning (collision_table.gd:204-210)."
          % SPEC["table_key"])
    print("    Add:  \"%s\": {\"box\": Vector3(%.2f, %.2f, %.2f), \"y_offset\": %.2f, "
          "\"footprint\": Vector2(%.1f, %.1f), \"scale\": 1.0}"
          % (SPEC["table_key"], rx, ry, rz, SPEC["table_required_y_offset"], rx + 1.1, rz + 1.1))
    print("    The M35's existing entry (:154) box (2.1, 3.3, 5.8) was measured off the OLD "
          "truck and inherits its -17%% length and -11%% width. This model does not fit it "
          "and must not be shrunk to.")
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
check(len(mats) <= 8, "%d materials (the shipped truck ships 12 for the same job)" % len(mats))
check(not any("." in m and m.rsplit(".", 1)[-1].isdigit() for m in mats),
      "no .001-style duplicate materials")
check(all(not m.startswith("Material") and "tmp" not in m.lower() for m in mats),
      "no temp / default material names")
for m in bpy.data.materials:
    b = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if b:
        check(b.inputs["Metallic"].default_value < 0.01,
              "%s is non-metallic (%.2f)" % (m.name, b.inputs["Metallic"].default_value))
imgs = [i.name for i in bpy.data.images if i.name != "Render Result"]
check(not imgs,
      "NO TEXTURES. The shipped truck carries 8 x 1024 images and 7.96 MB, including a "
      "photographic `hessian_230` burlap on the cargo cover that renders as WICKER, and "
      "`worn_asphalt` road-surface photos on all ten tyres: %s" % imgs)
check(not bpy.data.actions, "no baked animation ships")

for n in sorted(objs):
    low = n.lower()
    check(not any(h in low for h in SPIN_HINTS),
          "%s trips no RotorSpin hint (rotor_spin.gd:25)" % n)
    t = len(objs[n].data.loop_triangles)
    check(t != 1152, "%s is not a default 1152-tri torus (the shipped truck has TEN, "
                     "11,520 tris = 69.4%% of the model)" % n)
    ng = sum(1 for p in objs[n].data.polygons if len(p.vertices) > 4)
    used = set()
    for p in objs[n].data.polygons:
        used.update(p.vertices)
    check(ng == 0, "%s has no n-gons" % n)
    check(len(objs[n].data.vertices) - len(used) == 0, "%s has no loose vertices" % n)

lo_t, hi_t = SPEC["tri_budget"]
print("\n  VISIBLE TRIS %d   collider tris %d" % (tris, ctris))
check(lo_t <= tris <= hi_t, "visible tris %d inside the %d-%d fleet-class budget"
      % (tris, lo_t, hi_t))
body_t = sum(len(objs[n].data.loop_triangles) for n in SPEC["bodywork"] if n in objs)
wheel_t = sum(len(objs[n].data.loop_triangles) for n in SPEC["wheels"] if n in objs)
share = 100.0 * body_t / tris
print("    bodywork %s = %.1f%%   wheels = %.1f%%"
      % (list(SPEC["bodywork"]), share, 100.0 * wheel_t / tris))
check(share >= SPEC["bodywork_min_share"],
      "the CAB, BED and TARP carry %.1f%% of the triangles (the shipped truck spent "
      "69.4%% on ten tyre tori and 4.8%% on all 67 bodywork boxes)" % share)

print("\n%s  (%d failures)" % ("VERIFY PASS" if not fails else "VERIFY FAIL", len(fails)))
for f in fails:
    print("   ! " + f)
