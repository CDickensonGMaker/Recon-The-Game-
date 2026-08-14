"""Re-import ac47_spooky_v3.glb and assert the export contract.

    blender -b --factory-startup --python tools/verify_ac47_spooky_v3.py

Checks the SHIPPED file, not the build scene: node names, both propellers' spin
axes in Godot terms, the three muzzle empties and their bore directions, facing,
real dimensions, collider naming, materials and the port battery's asymmetry.
A build that ran without error proves nothing; this proves the artefact.

v3 is built FROM PURE REFERENCE - no donor - so this also asserts that BOTH
earlier assets are byte-identical: his original `ac47_spooky.glb` and the
donor-derived `ac47_spooky_v2.glb`. All three are meant to sit side by side.
"""

import bpy, os, math, json, struct, hashlib
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
AIR = os.path.join(HERE, "..", "assets", "us", "aircraft")
GLB = os.path.abspath(os.path.join(AIR, "ac47_spooky_v3.glb"))
UNTOUCHED = {
    "ac47_spooky.glb": "5ee96aabf0d59ebe613e09189f63c3e2",
    "ac47_spooky_v2.glb": "cd5b77d7afc5cbbe50d140d8898f6f27",
}

REAL_LENGTH, REAL_SPAN, REAL_PROP_D = 19.43, 29.11, 3.51
REAL_STAB_SPAN, REAL_FUSE_W, REAL_FUSE_H = 8.54, 2.55, 2.905
NACELLE_X = 2.82
# The build's own design datum, needed to turn Godot/Blender coordinates back
# into stations. Origin is the wing quarter chord at s 5.9625 * 0.98961.
NOSE_Y = 5.9005
KS = REAL_LENGTH / 19.634

MESHES = {"AC47_Airframe", "AC47_Glazing", "AC47_Guns", "AC47_Gear",
          "AC47_PortSide", "AC47_Windows", "AC47_Markings",
          "AC47_Prop_L", "AC47_Prop_R",
          "AC47_Col_Hull-colonly", "AC47_Col_Wing-colonly", "AC47_Col_Aft-colonly"}
EMPTIES = {"gun_muzzle_1", "gun_muzzle_2", "gun_muzzle_3"}
# rotor_spin.gd:22-25 - a node whose lowered name contains one of these gets spun
PROP_HINTS = ("prop", "spinner", "blade")
MAIN_HINTS = ("mainrotor", "rotor_hub", "new_blade", "rotor_flybar", "new_rotor")
TAIL_HINTS = ("tailrotor", "tailblade")

fails = []


def check(ok, msg):
    print(("  PASS  " if ok else "  FAIL  ") + msg)
    if not ok:
        fails.append(msg)


print("\n--- ac47_spooky_v3.glb (PURE REFERENCE BUILD) ----------------")

for name, want in sorted(UNTOUCHED.items()):
    p = os.path.abspath(os.path.join(AIR, name))
    got = hashlib.md5(open(p, "rb").read()).hexdigest()
    check(got == want, "%s is byte-identical (%s) - v3 is a NEW variant, all "
                       "three ship side by side" % (name, got))

raw = open(GLB, "rb").read()
gj = json.loads(raw[20:20 + struct.unpack("<I", raw[12:16])[0]])
nodes = {n.get("name"): n for n in gj["nodes"]}
print("  glTF nodes: %s" % sorted(nodes))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
# The importer brings `prop_spin` in and the scene sits at frame 1, so every
# matrix_world read is of a propeller a QUARTER TURN into its animation. That
# put the static bbox floor 0.25 m below the true rest value and made the
# ground-line assertion fail on a correct file. Rest pose, explicitly.
bpy.context.scene.frame_set(0)
bpy.context.view_layer.update()

objs = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
emp = {o.name: o for o in bpy.data.objects if o.type == "EMPTY"}
check(set(objs) == MESHES, "mesh nodes exactly %s" % sorted(MESHES))
check(EMPTIES <= set(emp), "muzzle empties present: %s" % sorted(EMPTIES))

# ---- the propeller contract -------------------------------------------------
# Blender's glTF IMPORTER bakes the Y-up->Z-up conversion into mesh data and
# leaves object rotations at identity, so an imported object's local Z says
# nothing about the shipped node. Godot reads the NODE transform - assert on the
# file's own JSON.
for name, sign in (("AC47_Prop_L", -1.0), ("AC47_Prop_R", 1.0)):
    n = nodes.get(name, {})
    rot = n.get("rotation")
    check(rot is None or (abs(rot[3]) > 0.9999 and max(abs(c) for c in rot[:3]) < 1e-4),
          "%s glTF node rotation is IDENTITY -> its Godot local Z is the thrust "
          "line, the axis rotor_spin.gd:76 turns (rotation=%s)" % (name, rot))
    tr = n.get("translation")
    check(tr is not None and abs(abs(tr[0]) - NACELLE_X) < 0.01 and tr[0] * sign > 0.0
          and tr[2] < -2.0,
          "%s hub is on its own side and forward at Godot -Z (%s)" % (name, tr))
    ob = objs[name]
    r = max(math.hypot(v.co.x, v.co.z) for v in ob.data.vertices)
    check(abs(2.0 * r - REAL_PROP_D) < 0.10,
          "%s disc %.3f m vs real %.3f" % (name, 2.0 * r, REAL_PROP_D))
    check(any(h in name.lower() for h in PROP_HINTS),
          "%s matches RotorSpin.PROP_HINTS" % name)
    # no blade at bottom dead centre, or the swept arc and the static bbox
    # coincide and the ground-line figure stops meaning anything
    low = min(v.co.z for v in ob.data.vertices)
    check(low > -REAL_PROP_D * 0.5 + 0.15,
          "%s rest pose has no blade at bottom dead centre (lowest %.3f vs a "
          "%.3f swept radius)" % (name, low, REAL_PROP_D * 0.5))

props = {"AC47_Prop_L", "AC47_Prop_R"}
for name in list(objs) + list(emp):
    if name in props:
        continue
    low = name.lower()
    check(not any(h in low for h in PROP_HINTS + MAIN_HINTS + TAIL_HINTS),
          "%s does NOT trip a RotorSpin hint" % name)

# ---- the baked clip spectre_gunship.gd:132 asks for by name ------------------
anims = {a.get("name"): a for a in gj.get("animations", [])}
check("prop_spin" in anims,
      "ships a `prop_spin` animation - spectre_gunship.gd:132 plays that clip by "
      "name and never attaches RotorSpin (%s)" % sorted(anims))
if "prop_spin" in anims:
    targets = {gj["nodes"][c["target"]["node"]].get("name")
               for c in anims["prop_spin"]["channels"]}
    check(targets == props, "prop_spin drives BOTH propellers: %s" % sorted(targets))
    paths = {c["target"]["path"] for c in anims["prop_spin"]["channels"]}
    check(paths == {"rotation"}, "prop_spin drives rotation only: %s" % sorted(paths))

# ---- the muzzle contract ----------------------------------------------------
# These replace the synthesised muzzle at spectre_gunship.gd:217, which puts the
# gun 3.2 m toward the target and 0.9 m below the node origin with no reference
# to the model at all. Convention is v2's, unchanged, so the adopter's code
# works against either variant.
for name in sorted(EMPTIES):
    n = nodes.get(name, {})
    tr = n.get("translation")
    check(tr is not None, "%s ships a node translation %s" % (name, tr))
    if tr is None:
        continue
    # glTF/Godot: +X starboard, +Y up, -Z forward. The battery is to PORT.
    check(tr[0] < -1.2, "%s is on the PORT side (Godot x %+0.3f)" % (name, tr[0]))
    ob = emp[name]
    # after import the scene is Blender-Z-up again; local +Y is the bore
    bore = (ob.matrix_world.to_3x3() @ Vector((0.0, 1.0, 0.0))).normalized()
    check(bore.x < -0.9 and -0.30 < bore.z < -0.10,
          "%s bore points out to port and %.1f deg down (%s) - the adopter reads "
          "it in Godot as -basis.z"
          % (name, math.degrees(math.asin(-bore.z)),
             tuple(round(c, 3) for c in bore)))
zs = sorted(nodes[n]["translation"][2] for n in EMPTIES)
check(all(0.5 < zs[i + 1] - zs[i] < 2.0 for i in range(len(zs) - 1)),
      "the three muzzles are spread along the fuselage (Godot z %s)"
      % [round(v, 3) for v in zs])

for n in gj["nodes"]:
    nm = n.get("name")
    if nm in props or nm in EMPTIES:
        continue
    check("rotation" not in n and "translation" not in n and "scale" not in n,
          "%s node is at identity" % nm)


# ---- facing, scale, origin --------------------------------------------------
def bbox(names):
    a = Vector((1e9, 1e9, 1e9))
    b = Vector((-1e9, -1e9, -1e9))
    for nm in names:
        ob = objs[nm]
        for v in ob.data.vertices:
            w = ob.matrix_world @ v.co
            a = Vector((min(a[i], w[i]) for i in range(3)))
            b = Vector((max(b[i], w[i]) for i in range(3)))
    return a, b


vis = [n for n in objs if not n.endswith("-colonly")]
cols = [n for n in objs if n.endswith("-colonly")]
tris = 0
for n in objs:
    objs[n].data.calc_loop_triangles()
    if n in vis:
        tris += len(objs[n].data.loop_triangles)

lo, hi = bbox(vis)
alo, ahi = bbox(["AC47_Airframe"])
span, length = hi.x - lo.x, hi.y - lo.y
print("  visible bbox lo %s hi %s" % (tuple(round(c, 3) for c in lo),
                                      tuple(round(c, 3) for c in hi)))
check(abs(span - REAL_SPAN) < 0.05, "span %.3f m vs real %.3f" % (span, REAL_SPAN))
check(abs(length - REAL_LENGTH) < 0.05,
      "length %.3f m vs real %.3f" % (length, REAL_LENGTH))
check(hi.y > 5.0 and lo.y < -13.0,
      "nose at +Y (Godot -Z): nose %+0.2f tail %+0.2f" % (hi.y, lo.y))
check(abs(lo.x + hi.x) < 0.02, "laterally symmetric about x=0 (%.4f)" % (lo.x + hi.x))
check(abs(hi.y - NOSE_Y) < 0.02,
      "origin is the wing quarter chord: the nose sits %.3f m ahead of it" % hi.y)

air = objs["AC47_Airframe"]


def station(y):
    return (NOSE_Y - y) / KS


# A width query must name its band AND say why nothing else lives there. s 8.5
# is the widest fuselage station; the wing spans that y too, so the |x| clause
# is load-bearing - without it this reads 29.11.
fuse_w = 2.0 * max(abs(v.co.x) for v in air.data.vertices
                   if abs(station(v.co.y) - 8.5) < 0.4 and abs(v.co.x) < 1.60)
check(abs(fuse_w - REAL_FUSE_W) < 0.06,
      "fuselage %.3f m across at its widest station vs real %.3f" % (fuse_w, REAL_FUSE_W))
band = [v.co.z for v in air.data.vertices
        if abs(station(v.co.y) - 8.5) < 0.4 and abs(v.co.x) < 0.30]
fuse_h = max(band) - min(band)
check(fuse_h > fuse_w,
      "the fuselage is TALLER THAN WIDE: %.3f deep vs %.3f across (%.1f%%) - the "
      "DC-3's head-on identity" % (fuse_h, fuse_w, 100.0 * (fuse_h / fuse_w - 1.0)))
# aft of s 16 the only things wider than the tail cone are the tailplane tips;
# the fin lies in the x = 0 plane and contributes |x| < 0.16.
stab = 2.0 * max(abs(v.co.x) for v in air.data.vertices if station(v.co.y) > 16.0)
check(abs(stab - REAL_STAB_SPAN) < 0.10,
      "tailplane %.3f m vs real %.3f (29.3%% of the wingspan)" % (stab, REAL_STAB_SPAN))

# Prop/fuselage clearance, swept over HEIGHT against the model's own skin. At the
# widest fuselage station this reads as an interference that does not exist,
# because the engines hang 1.2 m below the fuselage centreline.
hub = objs["AC47_Prop_L"].matrix_world.translation
gap, gap_z = 1e9, 0.0
for i in range(121):
    z = hub.z - REAL_PROP_D * 0.5 + i * REAL_PROP_D / 120.0
    dz = z - hub.z
    if abs(dz) >= REAL_PROP_D * 0.5:
        continue
    inboard = NACELLE_X - math.sqrt((REAL_PROP_D * 0.5) ** 2 - dz * dz)
    near = [abs(v.co.x) for v in air.data.vertices
            if abs(station(v.co.y) - 2.75) < 0.9 and abs(v.co.x) < 1.60
            and abs(v.co.z - z) < 0.25]
    if not near:
        continue
    d = inboard - max(near)
    if d < gap:
        gap, gap_z = d, z
check(gap > 0.10,
      "inboard prop tip clears the fuselage by %.3f m, worst at z %+0.2f - "
      "nacelles sit at the drawing's +/-%.2f with no compromise" % (gap, gap_z, NACELLE_X))

# ---- the port battery is the one thing that is NOT symmetric ----------------
guns = objs["AC47_Guns"]
check(max(v.co.x for v in guns.data.vertices) < 0.0,
      "every gun vertex is to PORT (max x %+0.3f)"
      % max(v.co.x for v in guns.data.vertices))
side = objs["AC47_PortSide"]
check(max(v.co.x for v in side.data.vertices) < 0.0,
      "the cargo door is to PORT only")
check(all(p.normal.x < -0.05 for p in side.data.polygons),
      "no port-side panel is backfacing (worst n.x %.2f)"
      % max(p.normal.x for p in side.data.polygons))
wins = objs["AC47_Windows"]
for p in wins.data.polygons:
    want = 1.0 if p.center.x > 0.0 else -1.0
    if p.normal.x * want <= 0.05:
        fails.append("AC47_Windows face at %s is backfacing"
                     % tuple(round(c, 2) for c in p.center))
check(all(p.normal.x * (1.0 if p.center.x > 0 else -1.0) > 0.05
          for p in wins.data.polygons),
      "all %d cabin-window faces face outboard" % len(wins.data.polygons))
# the port side is short two windows (they are gun ports) and one more (it is
# inside the cargo door aperture)
# 8, not 4: each 2x2-quad panel arrives TRIANGULATED out of the glTF.
nport = sum(1 for p in wins.data.polygons if p.center.x < 0) / 8
nstbd = sum(1 for p in wins.data.polygons if p.center.x > 0) / 8
check(nstbd == 7 and nport == 6,
      "%d starboard windows, %d port panels (2 of them gun ports; the 7th is "
      "swallowed by the cargo door)" % (nstbd, nport))
marks = objs["AC47_Markings"]
check(all(p.normal.z > 0.85 for p in marks.data.polygons),
      "the upper-wing star-and-bar faces up on every face (worst n.z %.2f)"
      % min(p.normal.z for p in marks.data.polygons))
check(max(v.co.x for v in marks.data.vertices) < 0.0,
      "the insignia is on the PORT wing, where the upper-wing one goes")
gear = objs["AC47_Gear"]
gx = [v.co.x for v in gear.data.vertices]
check(abs(min(gx) + max(gx)) < 0.02,
      "the main wheels ARE symmetric - only the battery and the door are one-sided")
check(min(v.co.z for v in gear.data.vertices)
      < min(v.co.z for v in air.data.vertices) + 0.05,
      "the main wheels hang below the nacelles - retracted but half exposed")

# ---- ground line and origin -------------------------------------------------
arc_z = hub.z - REAL_PROP_D * 0.5
check(arc_z < lo.z - 0.20,
      "GROUND LINE is the SWEPT prop arc at z %+0.3f, %.3f m below the static "
      "bbox floor %+0.3f - no blade sits at bottom dead centre in the rest pose"
      % (arc_z, lo.z - arc_z, lo.z))
keel = min(v.co.z for v in air.data.vertices if abs(v.co.x) < 0.30)
check(abs((ahi.z - keel) - 5.32) < 0.20,
      "belly-to-fin-top %.3f m (the published 5.16 m is GROUND to fin top with "
      "the tail DOWN on its gear, which is not this pose)" % (ahi.z - keel))

clo, chi = bbox(cols)
check(clo.x <= alo.x + 0.10 and chi.x >= ahi.x - 0.10
      and clo.y <= alo.y + 0.35 and chi.y >= ahi.y - 0.35,
      "colliders span the airframe in plan (x %.2f..%.2f vs %.2f..%.2f, "
      "y %.2f..%.2f vs %.2f..%.2f)" % (clo.x, chi.x, alo.x, ahi.x,
                                       clo.y, chi.y, alo.y, ahi.y))
check(len(cols) == 3, "three -colonly colliders: %s" % sorted(cols))

for name, ob in objs.items():
    sc = ob.scale
    check(max(abs(sc[i] - 1.0) for i in range(3)) < 1e-4, "%s scale is 1,1,1" % name)

# ---- materials --------------------------------------------------------------
mats = sorted(m.name for m in bpy.data.materials)
print("  materials (%d): %s" % (len(mats), mats))
check(all(not m.startswith("Material") and "tmp" not in m.lower()
          and all(c.islower() or c.isdigit() or c == "_" for c in m) for m in mats),
      "every material name is clean lower_snake - no temp or default names")
check(len(mats) <= 10, "%d materials, fleet class (a1 ships 10, f4 9)" % len(mats))
for m in bpy.data.materials:
    b = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if b is None:
        continue
    check(b.inputs["Metallic"].default_value < 0.01,
          "%s is non-metallic (%.2f) - no PSX sparkle"
          % (m.name, b.inputs["Metallic"].default_value))
imgs = [i.name for i in bpy.data.images if i.name != "Render Result"]
check(imgs == [],
      "NO textures at all - the paint is per-face flat material, exactly like "
      "a1_skyraider_v2 and f4_phantom_v2; nothing for Godot to re-extract "
      "beside the .glb (%s)" % imgs)
check({"ac47_sea_tan", "ac47_sea_green_med", "ac47_sea_green_dark",
       "ac47_night_black"} <= set(mats),
      "carries the SEA gunship scheme: FS 30219 tan / FS 34102 medium green / "
      "FS 34079 forest green over FS 17038 BLACK undersides")

check(2500 <= tris <= 3500,
      "visible tris %d inside the 2,500-3,500 class the brief set" % tris)
print("  collider tris %d" % sum(len(objs[c].data.loop_triangles) for c in cols))
print("  glb %.0f KB" % (len(raw) / 1024.0))

print("\n%s  (%d failures)" % ("VERIFY PASS" if not fails else "VERIFY FAIL", len(fails)))
for f in fails:
    print("   ! " + f)
