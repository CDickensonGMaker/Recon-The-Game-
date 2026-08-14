"""Re-import the CH-47 v2 GLB and assert the tandem-rotor export contract.

    blender -b --factory-startup --python tools/verify_ch47_v2.py [-- --glb PATH] [--legacy]

Checks the SHIPPED file, not the build scene. A build that ran without error
proves nothing; this proves the artefact.

This is tools/verify_m113_v2.py's SPEC pattern with the ground-vehicle checks
replaced by aircraft ones, and it IMPORTS the floater and coincident-face
probes from tools/build_ch47_v2.py so the shipped file is re-checked with the
same code that built it.

FACING IS THE POINT OF THIS GATE. `ch47_chinook.glb` is exported with its
fuselage along X, and nothing in scenes/vehicles/chinook.tscn compensates, so
the ship flies sideways. Four INDEPENDENT facing probes run here, none of which
reads a node name to decide where the front is:

  1. the fuselage's LONG AXIS must be Blender y / Godot z, by a wide margin
  2. the COCKPIT GLAZING material's faces must lie forward of centre
  3. the airframe's aft extreme must be LOW (the lowered ramp lip) while its
     forward extreme is at mid height (the nose) - a real fore/aft asymmetry
  4. the raw glTF accessor bounds and node translations, which is what Godot
     actually reads, must say the same thing

Negative-tested against the shipped model before being trusted:
    blender -b --factory-startup --python tools/verify_ch47_v2.py -- \
        --glb assets/us/vehicles/ch47_chinook.glb --legacy
"""

import bpy, os, math, json, struct, sys, re
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.abspath(os.path.join(HERE, ".."))
sys.path.insert(0, HERE)
from build_ch47_v2 import floaters, coincident      # noqa: E402

SPEC = {
    "glb": os.path.join(PROJ, "assets", "us", "vehicles", "ch47_chinook_v2.glb"),
    "label": "CH-47A Chinook tandem-rotor medium lift helicopter",
    # vertipedia.vtol.org/aircraft/getAircraft/aircraftID/284 (CH-47A):
    #   rotor 18.01 . overall (rotors turning) 29.90 . height 5.68
    #   fuselage 15.47 x 3.78 . gear base 6.86 . cabin 9.30 x 2.29 x 1.98
    # HUB SEPARATION is derived: 29.90 - 18.01 = 11.89, so honouring both
    # published figures at once is a construction, not a fit.
    "rotor_d": 18.01, "len_turning": 29.90, "height": 5.68,
    "fus_w": 3.78, "hub_sep": 11.89, "cabin_w": 2.29, "cabin_h": 1.98,
    # nose -> lowered ramp lip. The published 15.47 m is nose -> ramp HINGE and
    # the aft pylon overhangs that to 16.40; with the ramp down the airframe is
    # longer, so this band is asserted against the model's own contract, and
    # the 15.47 and 16.40 stations are asserted separately below.
    "airframe_l": 17.848, "ramp_hinge": 15.47, "pylon_te": 16.40,
    "tol_rotor": 0.03, "tol_len": 0.02, "tol_hgt": 0.02, "tol_wid": 0.02,
    "meshes": {"Fuselage", "FrontRotor", "RearRotor",
               "CH47_Col_Lower-colonly", "CH47_Col_Upper-colonly"},
    # scenes/vehicles/chinook.tscn:10-12 + scripts/vehicles/helicopter.gd:18-22
    "rotors": ("FrontRotor", "RearRotor"),
    "fuselage": "Fuselage",
    "cockpit_glass": ["CH47_CockpitGlass"],
    "empties": ({"seat_pilot_l", "seat_pilot_r", "seat_gunner_l", "seat_gunner_r"}
                | {"seat_pax_%d" % i for i in range(1, 9)}
                | {"seat_bench_%d" % i for i in range(1, 7)}),
    "tri_budget": (900, 3500),
    "max_mats": 8,
    "floor_z": 1.15, "ceil_z": 3.13, "bay_hw": 1.14,
    "table_key": "ch47_chinook_v2",
    "table_required": (4.00, 5.70, 17.90), "table_required_y_offset": 2.85,
    "table_gd": os.path.join(PROJ, "scripts", "world", "collision_table.gd"),
}

# rotor_spin.gd:22-25 - any node whose lowered name contains one of these gets
# spun by RotorSpin, which would fight helicopter.gd's own code-driven rotation.
SPIN_HINTS = ("prop", "spinner", "blade", "mainrotor", "rotor_hub", "new_blade",
              "rotor_flybar", "new_rotor", "tailrotor", "tailblade")

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
LEGACY = "--legacy" in argv
if "--glb" in argv:
    SPEC["glb"] = os.path.join(PROJ, argv[argv.index("--glb") + 1])
if LEGACY:
    # the shipped model's own cockpit glass materials, so the glazing probe
    # reads something real rather than failing for the wrong reason
    SPEC["cockpit_glass"] = ["CockpitGlass", "CockpitGlass.001"]

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
    print("    extra:   %s" % sorted(set(objs) - SPEC["meshes"])[:20])

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
print("  visible bbox lo %s hi %s" % (tuple(round(c, 3) for c in lo),
                                      tuple(round(c, 3) for c in hi)))

# =========================================================== FACING, FOUR WAYS
print("\n  FACING - the defect this rebuild exists to kill")
FUS = SPEC["fuselage"]
have_fus = FUS in objs
if have_fus:
    flo, fhi = bbox([FUS])
    fx, fy, fz = fhi.x - flo.x, fhi.y - flo.y, fhi.z - flo.z
    print("    fuselage extents  x %.3f  y %.3f  z %.3f" % (fx, fy, fz))
    # 1 - THE LONG AXIS. The shipped model's Fuselage is 8.10 along X and 1.80
    #     along Y: ninety degrees off, and the .tscn does not compensate.
    check(fy > 3.0 * fx and fy > 3.0 * fz,
          "the fuselage's LONG AXIS is Blender y = Godot z (y %.2f vs x %.2f, z %.2f)"
          % (fy, fx, fz))
    check(abs(flo.x + fhi.x) < 0.01,
          "fuselage is laterally symmetric about x=0 (%.4f)" % (flo.x + fhi.x))
    # 3 - fore/aft asymmetry, measured off the geometry, no names anywhere.
    #     The aft extreme is the LOWERED RAMP LIP, near the ground; the forward
    #     extreme is the nose, at mid height.
    vw = [(objs[FUS].matrix_world @ v.co) for v in objs[FUS].data.vertices]
    vw.sort(key=lambda p: p.y)
    aft = sum((p.z for p in vw[:8]), 0.0) / 8.0
    fwd = sum((p.z for p in vw[-8:]), 0.0) / 8.0
    print("    aft-most 8 verts mean z %.3f   forward-most 8 mean z %.3f" % (aft, fwd))
    check(aft < 0.60 * fz * 0.5 and aft < fwd - 0.6,
          "the AFT extreme is LOW (the lowered ramp lip, z %.2f) and the FORWARD "
          "extreme is the nose at mid height (z %.2f) -> ramp at Godot +Z, nose at -Z"
          % (aft, fwd))
else:
    check(False, "no `%s` mesh - helicopter.gd:80 resolves it by that exact name" % FUS)

# 2 - the cockpit greenhouse, by material, must be forward of centre
def mat_centroid(names):
    """AREA-WEIGHTED, deliberately. An unweighted mean of face centres is not
    invariant under triangulation: cap() reverses a quad's point list when
    Newell disagrees with the outward direction, which flips WHICH DIAGONAL the
    fan uses, and a mirrored pair of quads then produces two tri-centres that do
    not mirror. That alone read as a 62 mm lateral bias on a greenhouse that is
    symmetric to the last vertex. Weighting by area is exact for any planar
    quad, whichever way it was split."""
    tot, wt, n = Vector(), 0.0, 0
    for ob in objs.values():
        idx = [i for i, m in enumerate(ob.data.materials) if m and m.name in names]
        if not idx:
            continue
        for p in ob.data.polygons:
            if p.material_index in idx:
                a = p.area
                tot += (ob.matrix_world @ p.center) * a
                wt += a
                n += 1
    return (tot / wt if wt else None), n


gc, gn = mat_centroid(SPEC["cockpit_glass"])
check(gn > 0, "the cockpit glazing material is painted on something (%d faces)" % gn)
if gc:
    print("    cockpit glazing centroid %s" % (tuple(round(c, 3) for c in gc),))
    check(gc.y > 0.30 * hi.y,
          "the COCKPIT GLAZING is FORWARD -> nose is Blender +Y = Godot -Z (y %+0.3f)"
          % gc.y)
    check(abs(gc.x) < 0.06, "the greenhouse is laterally balanced (x %+0.3f)" % gc.x)

# 4 - the raw glTF, which is what Godot reads. The Blender importer bakes the
#     Y-up conversion into MESH DATA and leaves node rotations at identity, so
#     an imported object's transform is NOT evidence about the shipped file.
raw = open(GLB, "rb").read()
gj = json.loads(raw[20:20 + struct.unpack("<I", raw[12:16])[0]])
nodes = {n.get("name"): n for n in gj["nodes"]}


def gltf_bbox(node_name):
    n = nodes.get(node_name)
    if n is None or "mesh" not in n:
        return None
    a, b = [1e9] * 3, [-1e9] * 3
    for prim in gj["meshes"][n["mesh"]]["primitives"]:
        acc = gj["accessors"][prim["attributes"]["POSITION"]]
        for i in range(3):
            a[i] = min(a[i], acc["min"][i])
            b[i] = max(b[i], acc["max"][i])
    return a, b


gb = gltf_bbox(FUS)
if gb:
    a, b = gb
    print("    glTF Fuselage bounds  X %+0.2f..%+0.2f  Y %+0.2f..%+0.2f  Z %+0.2f..%+0.2f"
          % (a[0], b[0], a[1], b[1], a[2], b[2]))
    check(b[2] - a[2] > 3.0 * (b[0] - a[0]),
          "IN THE FILE GODOT READS, the fuselage runs along Z (%.2f) not X (%.2f)"
          % (b[2] - a[2], b[0] - a[0]))
    check(abs(a[2] + b[2]) < 0.02 and abs(a[0] + b[0]) < 0.02,
          "the Fuselage AABB is centred in plan (X %+0.3f, Z %+0.3f) so "
          "helicopter.gd:82's recentre moves nothing" % (a[0] + b[0], a[2] + b[2]))
else:
    check(False, "the glTF has no `%s` mesh node" % FUS)

# ---- node contract: the rotors -----------------------------------------------
print("\n  ROTOR NODE CONTRACT (chinook.tscn:10-12)")
for n in SPEC["rotors"]:
    check(n in objs, "`%s` is a MESH node (helicopter.gd:64-65 find_child)" % n)
    check(nodes.get(n, {}).get("rotation") is None,
          "glTF node %s has NO rotation - Godot rotate_y() spins it about its own mast" % n)
if all(n in objs for n in SPEC["rotors"]):
    f, r = objs[SPEC["rotors"][0]], objs[SPEC["rotors"][1]]
    ft = nodes.get(SPEC["rotors"][0], {}).get("translation") or [0, 0, 0]
    rt = nodes.get(SPEC["rotors"][1], {}).get("translation") or [0, 0, 0]
    print("    glTF FrontRotor T %s   RearRotor T %s"
          % ([round(c, 3) for c in ft], [round(c, 3) for c in rt]))
    check(ft[2] < -1.0, "FrontRotor is at Godot -Z, i.e. FORWARD (z %+0.3f)" % ft[2])
    check(rt[2] > 1.0, "RearRotor is at Godot +Z, i.e. AFT (z %+0.3f)" % rt[2])
    check(rt[1] > ft[1] + 0.4,
          "the AFT rotor is mounted HIGHER than the forward one (%.2f vs %.2f) - "
          "that is how a tandem's discs clear each other" % (rt[1], ft[1]))
    sep = f.location.y - r.location.y
    print("    hub separation %.3f (29.90 - 18.01 = %.3f)" % (sep, SPEC["hub_sep"]))
    check(abs(sep - SPEC["hub_sep"]) < 0.02,
          "hub separation %.3f m" % sep)
    for n in SPEC["rotors"]:
        ob = objs[n]
        rad = max(math.hypot(v.co.x, v.co.y) for v in ob.data.vertices)
        span = max(abs(v.co.z) for v in ob.data.vertices)
        print("    %-11s tip radius %.4f (disc %.3f)  half-thickness in z %.3f"
              % (n, rad, 2 * rad, span))
        check(abs(2 * rad - SPEC["rotor_d"]) < SPEC["tol_rotor"],
              "%s disc %.3f vs the CH-47A's 18.01 m" % (n, 2 * rad))
        check(span < 0.6, "%s lies FLAT in its own local XY plane (z span %.3f) - "
                          "Godot rotate_y() is Blender's Z" % (n, span))
        check(all(abs(c) < 1e-5 for c in ob.rotation_euler),
              "%s rotation is IDENTITY" % n)
        # blades must be evenly clocked, or the spin wobbles
        angs = sorted({round(math.degrees(math.atan2(v.co.y, v.co.x)) % 120.0, 0)
                       for v in ob.data.vertices
                       if math.hypot(v.co.x, v.co.y) > 0.8 * rad})
        check(len(angs) <= 4,
              "%s blade tips are evenly clocked at 120 deg (%d distinct residues)"
              % (n, len(angs)))

# ---- dimensions --------------------------------------------------------------
print("\n  MEASURED vs REAL")
length, width, height = hi.y - lo.y, hi.x - lo.x, hi.z - lo.z
for lab, got, real, tol in (("rotors-turning length", length, SPEC["len_turning"],
                             SPEC["tol_len"]),
                            ("height             ", height, SPEC["height"], SPEC["tol_hgt"])):
    print("    %s %7.3f  real %6.3f  d %+0.3f (%+0.1f%%)"
          % (lab, got, real, got - real, 100.0 * (got - real) / real))
    check(abs(got - real) <= tol, "%s %.3f m within %.2f of real %.3f"
          % (lab.strip(), got, tol, real))
if have_fus:
    flo, fhi = bbox([FUS])
    print("    fuselage width      %7.3f  real %6.3f" % (fhi.x - flo.x, SPEC["fus_w"]))
    check(abs((fhi.x - flo.x) - SPEC["fus_w"]) <= SPEC["tol_wid"],
          "fuselage width %.3f m over the sponsons vs the real 3.78"
          % (fhi.x - flo.x))
    print("    airframe length     %7.3f  (nose -> lowered ramp lip)" % (fhi.y - flo.y))
    check(abs((fhi.y - flo.y) - SPEC["airframe_l"]) < 0.05,
          "airframe %.3f m nose to ramp lip" % (fhi.y - flo.y))
    check(abs(lo.z) < 0.005,
          "GROUND-LINE ORIGIN: lowest point sits at z %+0.4f, so a landing puts the "
          "wheels on the pad rather than through it" % lo.z)
    check(abs(lo.x + hi.x) < 0.01, "laterally symmetric about x=0 (%.4f)" % (lo.x + hi.x))

# ---- the running gear tells you which end is which, with no names ------------
print("\n  LANDING GEAR - four legs, forward pair DUAL, aft pair SINGLE, no nose wheel")
# Count the tyres by CONNECTED COMPONENT, not by grid cell: a 0.66 m wheel does
# not fit in any cell small enough to separate a dual pair 0.27 m apart, and the
# first pass reported eight forward tyres for four wheels.
#
# AND THE COMPONENTS MUST BE FOUND ON WELDED COORDINATES, NOT VERTEX INDICES.
# A .glb is not the mesh its author built: the exporter splits every vertex
# whose normal differs per face, so a flat-shaded 6-sided tread band arrives as
# six unconnected quads and index-based union-find reported 36 tyres for six
# wheels. Union on the rounded COORDINATE instead.
rub = [ob for ob in objs.values()
       if any(m and "Rubber" in m.name for m in ob.data.materials)]
tyre_c = []
for ob in rub:
    idx = {i for i, m in enumerate(ob.data.materials) if m and "Rubber" in m.name}
    faces = [p for p in ob.data.polygons if p.material_index in idx]
    key = {}
    par = []

    def node(v):
        k = (round(v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4))
        if k not in key:
            key[k] = len(par)
            par.append(len(par))
        return key[k]

    def find(a):
        while par[a] != a:
            par[a] = par[par[a]]
            a = par[a]
        return a

    for p in faces:
        ns = [node(ob.data.vertices[i]) for i in p.vertices]
        for b in ns[1:]:
            ra, rb = find(ns[0]), find(b)
            if ra != rb:
                par[ra] = rb
    groups = {}
    for p in faces:
        root = find(node(ob.data.vertices[p.vertices[0]]))
        groups.setdefault(root, []).append(ob.matrix_world @ p.center)
    for v in groups.values():
        tyre_c.append(sum(v, Vector()) / len(v))
if tyre_c:
    fwd = [c for c in tyre_c if c.y > 0]
    aft = [c for c in tyre_c if c.y <= 0]
    print("    %d tyre clusters: %d forward, %d aft" % (len(tyre_c), len(fwd), len(aft)))
    check(len(fwd) == 4 and len(aft) == 2,
          "FOUR forward tyres (two dual pairs) and TWO aft (singles) - the shipped "
          "model carries a `Nose_Strut` and `Nose_Wheel_+/-`, which no Chinook has")
    if fwd and aft:
        base = (sum(c.y for c in fwd) / len(fwd)) - (sum(c.y for c in aft) / len(aft))
        print("    wheelbase %.3f (real 6.86)" % base)
        check(abs(base - 6.86) < 0.05, "gear base %.3f m" % base)
        check(max(abs(c.z) for c in tyre_c) < 0.45,
              "every wheel hub sits about one radius above the ground line")
else:
    check(False, "no tyre material anywhere - the gear is not modelled")

# ---- the two probes the M113 build added ------------------------------------
print("\n  FLOATER PROBE - every disconnected lump must touch something")
fl = floaters([objs[n] for n in vis], tol=0.030)
for lab, gap, c in fl:
    print("    %-22s %.3f m clear of everything, centred %s" % (lab, gap, c))
check(not fl, "no geometry is attached to NOTHING (%d floating islands)" % len(fl))

print("\n  COINCIDENT-FACE PROBE - coplanar overlapping skins sharing no vertex")
co = coincident([objs[n] for n in vis])
for c in co[:12]:
    print("    %s" % c)
check(not co, "no coincident faces (%d seams; they render as dirt in Cycles and are "
              "hidden by backface culling in Godot, which is what makes them ship)"
      % len(co))

# ---- the seat contract -------------------------------------------------------
print("\n  SEAT SOCKETS (seat_system.gd:434-456 - real markers RETIRE the fallback table)")
check(SPEC["empties"] <= set(empt),
      "all %d seat_* sockets ship in the GLB (%d found)"
      % (len(SPEC["empties"]), len(SPEC["empties"] & set(empt))))
if SPEC["empties"] - set(empt):
    print("    missing: %s" % sorted(SPEC["empties"] - set(empt)))
for n in sorted(SPEC["empties"] & set(empt)):
    e = empt[n]
    p = e.matrix_world.translation
    q = nodes.get(n, {}).get("rotation")
    # A SOCKET EMPTY ROTATES ABOUT Z ONLY. glTF maps Blender local -Y onto Godot
    # local +Z, so any X or Y euler lays the occupant on his side (universal
    # ledger, Huey v3, 2026-08-08 - twelve Huey sockets shipped with rx=90).
    if q is not None:
        check(abs(q[0]) < 1e-4 and abs(q[2]) < 1e-4,
              "%s rotates about Godot Y ONLY (quat %s)" % (n, [round(c, 3) for c in q]))
    if n.startswith("seat_pilot"):
        check(p.y > 5.5, "%s is in the COCKPIT (y %+0.2f)" % (n, p.y))
        continue
    check(abs(p.x) <= SPEC["bay_hw"], "%s is inside the cabin walls (x %+0.2f)" % (n, p.x))
    check(SPEC["floor_z"] < p.z < SPEC["ceil_z"],
          "%s sits between the cargo floor and the ceiling (z %.2f)" % (n, p.z))
    check(-7.4 < p.y < 5.1, "%s is inside the cargo bay fore/aft (y %+0.2f)" % (n, p.y))

# ---- colliders ---------------------------------------------------------------
print("\n  COLLIDERS")
check(len(cols) >= 1, "at least one -colonly mesh ships: %s" % cols)
if cols and have_fus:
    clo, chi = bbox(cols)
    blo, bhi = bbox([FUS])
    print("    collider bbox lo %s hi %s" % (tuple(round(c, 3) for c in clo),
                                             tuple(round(c, 3) for c in chi)))
    check(clo.x <= blo.x + 0.02 and chi.x >= bhi.x - 0.02,
          "colliders span the fuselage across")
    check(clo.y <= blo.y + 0.05 and chi.y >= bhi.y - 0.05,
          "colliders span the fuselage fore and aft")
    check(chi.z >= hi.z - 0.05, "colliders reach the top of the aft rotor head")
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
    if have_fus:
        flo, fhi = bbox([FUS])
        check(fhi.x - flo.x <= bx + 1e-3, "fuselage width fits the box")
        check(hi.z <= by + 1e-3, "height %.3f fits the box's %.2f" % (hi.z, by))
        check(fhi.y - flo.y <= bz + 1e-3, "airframe length fits the box's %.2f" % bz)
    check(abs(yo - by * 0.5) < 0.01,
          "y_offset %.2f is half the box height -> it rests on a ground-line origin" % yo)
else:
    print("    ADOPTER ACTION - no \"%s\" entry yet, so CollisionTable.get_entry falls "
          "through to a 3x2x3 default box with a push_warning." % SPEC["table_key"])
    print("    Add:  \"%s\": {\"box\": Vector3(%.2f, %.2f, %.2f), \"y_offset\": %.2f, "
          "\"footprint\": Vector2(%.1f, %.1f), \"scale\": 1.0, \"mesh\": true},"
          % (SPEC["table_key"], rx, ry, rz, SPEC["table_required_y_offset"],
             rx + 1.2, rz + 1.5))
    print("    The existing \"ch47_chinook\" entry (:67) is box (4, 4, 16) y_offset 2.0 -")
    print("    1.68 m too short for a 5.68 m airframe and measured off the sideways model.")
    if have_fus:
        flo, fhi = bbox([FUS])
        check((fhi.x - flo.x) <= rx + 1e-3 and hi.z <= ry + 1e-3
              and (fhi.y - flo.y) <= rz + 1e-3,
              "model fits the box this asset REQUIRES (%.2f, %.2f, %.2f)" % (rx, ry, rz))
    check(abs(SPEC["table_required_y_offset"] - ry * 0.5) < 0.01,
          "the required y_offset is half the required box height")

# ---- materials, textures, hygiene -------------------------------------------
print("\n  MATERIALS / HYGIENE")
mats = sorted(m.name for m in bpy.data.materials)
print("    %d: %s" % (len(mats), mats))
check(len(mats) <= SPEC["max_mats"], "%d materials" % len(mats))
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
check(not bpy.data.actions,
      "NO BAKED ANIMATION. helicopter.gd:56-59 stops any imported AnimationPlayer "
      "because it fights the code-driven spin; the shipped model ships two rotor "
      "actions anyway. Found: %s" % [a.name for a in bpy.data.actions])

for n in sorted(objs):
    low = n.lower()
    check(not any(h in low for h in SPIN_HINTS),
          "%s trips no RotorSpin hint (rotor_spin.gd:22-25)" % n)
    t = len(objs[n].data.loop_triangles)
    check(t != 1152, "%s is not a default 1152-tri torus" % n)
    check(t != 960, "%s is not a default 960-tri UV sphere (the shipped model has "
                    "FIVE, 4,800 tris of chin bubbles and a beacon)" % n)
    ng = sum(1 for p in objs[n].data.polygons if len(p.vertices) > 4)
    used = set()
    for p in objs[n].data.polygons:
        used.update(p.vertices)
    check(ng == 0, "%s has no n-gons" % n)
    check(len(objs[n].data.vertices) - len(used) == 0, "%s has no loose vertices" % n)
    check(all(abs(c - 1) < 1e-5 for c in objs[n].scale), "%s scale is 1,1,1" % n)
    if n not in SPEC["rotors"]:
        check(objs[n].location.length < 1e-5,
              "%s is at full identity (loc %s)"
              % (n, tuple(round(c, 4) for c in objs[n].location)))

lo_t, hi_t = SPEC["tri_budget"]
print("\n  VISIBLE TRIS %d   collider tris %d   (the shipped model: 12,028)" % (tris, ctris))
check(lo_t <= tris <= hi_t, "visible tris %d inside the %d-%d fleet-class budget"
      % (tris, lo_t, hi_t))
if all(n in objs for n in SPEC["rotors"]):
    rt_t = sum(len(objs[n].data.loop_triangles) for n in SPEC["rotors"])
    print("    airframe %d = %.1f%%   rotors %d = %.1f%%"
          % (tris - rt_t, 100.0 * (tris - rt_t) / tris, rt_t, 100.0 * rt_t / tris))
    check(100.0 * (tris - rt_t) / tris >= 60.0,
          "the AIRFRAME carries %.1f%% of the triangles, not the rotors"
          % (100.0 * (tris - rt_t) / tris))

print("\n%s  (%d failures)" % ("VERIFY PASS" if not fails else "VERIFY FAIL", len(fails)))
for f in fails[:40]:
    print("   ! " + f)
if len(fails) > 40:
    print("   ! ... and %d more" % (len(fails) - 40))
