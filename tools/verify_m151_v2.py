"""Re-import a ground vehicle GLB and assert the fleet export contract.

    blender -b --factory-startup --python tools/verify_m151_v2.py

Checks the SHIPPED file, not the build scene. A build that ran without error
proves nothing; this proves the artefact.

THIS IS THE GROUND-VEHICLE GATE THE FLEET NEVER HAD. The M151 shipped driving
90 degrees sideways for three months (2026-05-25 -> 2026-08-14) and the M35
still drives backwards, because nothing ever asserted facing on a vehicle GLB.

TO EXTEND IT to the M35 or the M113: copy this file, change SPEC, and change
nothing else. Every check below reads SPEC or reads the mesh - none of them
reads a node name to decide where the front is.

FACING IS MEASURED BY PART POSITION, NEVER BY NODE NAME. The probe is the LENS
MATERIALS: amber/clear lamp faces must lie forward of the centre and red lamp
faces aft of it. A node called `Grille` proves nothing about which way a model
points; a headlight lens 1.6 m forward of the origin does.
"""

import bpy, os, math, json, struct
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))

SPEC = {
    "glb": os.path.join(HERE, "..", "assets", "us", "vehicles", "m151_mutt_gun_jeep_v2.glb"),
    "label": "M151A2 MUTT gun jeep",
    # en.wikipedia.org/wiki/M151_jeep + warwheels.net M151A2 data sheet
    "length": 3.371, "width": 1.633, "height": 1.803,
    "wheelbase": 2.159, "track": 1.346, "tyre_od": 0.780,
    "tol_len": 0.03, "tol_wid": 0.03, "tol_hgt": 0.10,
    "meshes": {"M151_Body", "M151_Windscreen", "M151_GunMount", "M151_Gun",
               "M151_SpareTyre", "m151_wheel_fl", "m151_wheel_fr",
               "m151_wheel_rl", "m151_wheel_rr",
               "M151_Col_Tub-colonly", "M151_Col_Upper-colonly"},
    "empties": {"seat_driver", "seat_passenger", "seat_gunner", "MuzzlePoint"},
    "wheels": ("m151_wheel_fl", "m151_wheel_fr", "m151_wheel_rl", "m151_wheel_rr"),
    "pivoted": {"M151_Gun"},          # nodes allowed a translation besides wheels
    "lens_fwd": "M151_LensAmber",     # headlights / fender combination lamps
    "lens_aft": "M151_LensRed",       # tail lamps
    "tri_budget": (1200, 2600),
    # collision_table.gd:57 - the authored box the model has to live inside
    "table_box": (1.8, 1.8, 3.5), "table_y_offset": 0.9,
}

# rotor_spin.gd:25,20 - any node whose lowered name contains one of these gets
# spun by RotorSpin. A ground vehicle must trip NONE of them.
SPIN_HINTS = ("prop", "spinner", "blade", "mainrotor", "rotor_hub", "new_blade",
              "rotor_flybar", "new_rotor", "tailrotor", "tailblade")

fails = []


def check(ok, msg):
    print(("  PASS  " if ok else "  FAIL  ") + msg)
    if not ok:
        fails.append(msg)


GLB = os.path.abspath(SPEC["glb"])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
bpy.context.view_layer.update()

print("\n--- %s  ---------------------------" % os.path.basename(GLB))
print("  %.1f KB" % (os.path.getsize(GLB) / 1024.0))

objs = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
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
# Not by node name. Read the lamp lens materials and see where they physically
# sit. This is the check whose absence let a 90-degrees-sideways jeep lead every
# convoy in the game for three months.
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


fwd_c, fwd_n = mat_centroid(SPEC["lens_fwd"])
aft_c, aft_n = mat_centroid(SPEC["lens_aft"])
check(fwd_n > 0 and aft_n > 0, "both lamp lens materials are painted (%d fwd, %d aft faces)"
      % (fwd_n, aft_n))
if fwd_c and aft_c:
    print("  lens centroids: %s at y %+0.3f   %s at y %+0.3f"
          % (SPEC["lens_fwd"], fwd_c.y, SPEC["lens_aft"], aft_c.y))
    check(fwd_c.y > 0.5 * (hi.y * 0.5), "headlamps are FORWARD -> nose is Blender +Y = Godot -Z")
    check(aft_c.y < 0.5 * (lo.y * 0.5), "tail lamps are AFT")
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

# ---- wheels: named, placed, and L/R correct BY POSITION ----------------------
print("\n  WHEELS (spin axis = local X, steer axis = local Y in Godot)")
w = {}
for n in SPEC["wheels"]:
    if n not in objs:
        check(False, "%s is missing" % n)
        continue
    w[n] = objs[n].location.copy()
    print("    %-16s hub %s" % (n, tuple(round(c, 4) for c in w[n])))
if len(w) == 4:
    fl, fr, rl, rr = (w[n] for n in SPEC["wheels"])
    # +X is the vehicle's right when +Y is forward and +Z is up. The M35's
    # rigged blend has this inverted; assert it rather than trust the suffix.
    check(fl.x < 0 < fr.x and rl.x < 0 < rr.x,
          "L/R suffixes match POSITION (_l at -x, _r at +x) - not inherited backwards")
    check(fl.y > 0 > rl.y and fr.y > 0 > rr.y, "f/r suffixes match position")
    wb = ((fl.y + fr.y) - (rl.y + rr.y)) * 0.5
    tr = ((fr.x - fl.x) + (rr.x - rl.x)) * 0.5
    check(abs(wb - SPEC["wheelbase"]) < 0.02,
          "wheelbase %.3f m vs real %.3f" % (wb, SPEC["wheelbase"]))
    check(abs(tr - SPEC["track"]) < 0.02, "track %.3f m vs real %.3f" % (tr, SPEC["track"]))
    check(abs(fl.x + fr.x) < 1e-4 and abs(rl.x + rr.x) < 1e-4, "axles are centred on x=0")
    check(abs(fl.z - SPEC["tyre_od"] * 0.5) < 0.01 and abs(rl.z - SPEC["tyre_od"] * 0.5) < 0.01,
          "hubs sit one tyre radius above the ground line")
    for n in SPEC["wheels"]:
        ob = objs[n]
        r = max(math.hypot(v.co.y, v.co.z) for v in ob.data.vertices)
        check(abs(2 * r - SPEC["tyre_od"]) < 0.02,
              "%s OD %.3f m vs real %.3f, and its mesh is centred on its own hub"
              % (n, 2 * r, SPEC["tyre_od"]))
        check(all(abs(c) < 1e-5 for c in ob.rotation_euler),
              "%s rotation is IDENTITY -> Godot local X is the spin axis" % n)

# ---- transforms --------------------------------------------------------------
print("\n  TRANSFORMS")
movable = set(SPEC["wheels"]) | SPEC["pivoted"]
for n in sorted(objs):
    ob = objs[n]
    check(all(abs(c - 1) < 1e-5 for c in ob.scale), "%s scale is 1,1,1" % n)
    if n not in movable:
        check(ob.location.length < 1e-5,
              "%s is at full identity (loc %s)" % (n, tuple(round(c, 4) for c in ob.location)))
for n in SPEC["pivoted"]:
    if n in objs:
        check(objs[n].location.length > 1e-5,
              "%s carries its pivot as a node translation %s"
              % (n, tuple(round(c, 3) for c in objs[n].location)))

# Read the GLB's own node table too: the Blender importer bakes the Y-up->Z-up
# conversion into mesh data, so an imported object's transform is NOT proof of
# what Godot will read. Godot reads the node transform.
raw = open(GLB, "rb").read()
gj = json.loads(raw[20:20 + struct.unpack("<I", raw[12:16])[0]])
nodes = {n.get("name"): n for n in gj["nodes"]}
for n in SPEC["wheels"]:
    tr = nodes.get(n, {}).get("translation")
    check(tr is not None and abs(tr[1] - SPEC["tyre_od"] * 0.5) < 0.01,
          "glTF node %s translation %s - Godot +Y is up, so the hub is one radius high"
          % (n, [round(c, 4) for c in tr] if tr else None))
    check(nodes.get(n, {}).get("rotation") is None,
          "glTF node %s has no rotation" % n)
fwd_nodes = [n for n in SPEC["wheels"] if n.startswith("m151_wheel_f")]
for n in fwd_nodes:
    tr = nodes[n]["translation"]
    check(tr[2] < 0, "glTF node %s is at Godot -Z (forward): z %+0.3f" % (n, tr[2]))

# ---- colliders ---------------------------------------------------------------
print("\n  COLLIDERS")
check(len(cols) >= 1, "at least one -colonly mesh ships: %s" % cols)
if cols:
    clo, chi = bbox(cols)
    blo, bhi = bbox([n for n in vis if not n.startswith("m151_wheel")])
    print("    collider bbox lo %s hi %s" % (tuple(round(c, 3) for c in clo),
                                             tuple(round(c, 3) for c in chi)))
    check(clo.x <= blo.x + 0.02 and chi.x >= bhi.x - 0.02
          and clo.y <= blo.y + 0.02 and chi.y >= bhi.y - 0.02,
          "colliders span the body in plan")
    check(chi.z >= bhi.z - 0.05, "colliders reach the top of the body")
    check(abs(clo.z) < 0.01, "colliders start at the ground line")

# ---- it must fit the box the game already authored for it -------------------
bx, by, bz = SPEC["table_box"]
print("\n  collision_table.gd box %s y_offset %.2f" % (str(SPEC["table_box"]), SPEC["table_y_offset"]))
check(width <= bx + 1e-3, "model width %.3f fits the box's %.2f" % (width, bx))
check(height <= by + 1e-3, "model height %.3f fits the box's %.2f" % (height, by))
check(length <= bz + 1e-3, "model length %.3f fits the box's %.2f (Godot depth)" % (length, bz))
check(abs(SPEC["table_y_offset"] - by * 0.5) < 0.01,
      "y_offset %.2f is half the box height -> the box rests on a ground-line origin"
      % SPEC["table_y_offset"])

# ---- materials, textures, hygiene -------------------------------------------
print("\n  MATERIALS / HYGIENE")
mats = sorted(m.name for m in bpy.data.materials)
print("    %d: %s" % (len(mats), mats))
check(not any("." in m and m.rsplit(".", 1)[-1].isdigit() for m in mats),
      "no .001-style duplicate materials (the M113 ships 26 for two colours)")
check(all(not m.startswith("Material") and "tmp" not in m.lower() for m in mats),
      "no temp / default material names")
for m in bpy.data.materials:
    b = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if b:
        check(b.inputs["Metallic"].default_value < 0.01,
              "%s is non-metallic (%.2f)" % (m.name, b.inputs["Metallic"].default_value))
imgs = [i.name for i in bpy.data.images if i.name != "Render Result"]
check(not imgs, "no textures shipped (flat-material fleet convention): %s" % imgs)
check(not bpy.data.actions, "no baked animation ships")

for n in sorted(objs):
    low = n.lower()
    check(not any(h in low for h in SPIN_HINTS),
          "%s trips no RotorSpin hint (rotor_spin.gd:25)" % n)
    t = len(objs[n].data.loop_triangles)
    check(t != 1152, "%s is not a default 1152-tri torus" % n)
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
# distribution, the review's real indictment: the body must carry the geometry
body_t = len(objs["M151_Body"].data.loop_triangles) if "M151_Body" in objs else 0
check(body_t >= 0.40 * tris,
      "the BODY carries %.1f%% of the triangles (the shipped jeep spent 41%% on "
      "two tow hooks and a steering wheel and 5.4%% on bodywork)" % (100.0 * body_t / tris))

print("\n%s  (%d failures)" % ("VERIFY PASS" if not fails else "VERIFY FAIL", len(fails)))
for f in fails:
    print("   ! " + f)
