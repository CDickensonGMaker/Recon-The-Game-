"""Re-import f4_phantom_v2.glb and assert the export contract.

    blender -b --factory-startup --python tools/verify_f4_phantom_v2.py

Checks the SHIPPED file, not the build scene: node names, facing, real
dimensions, origin, collider naming and materials - plus the rule that matters
on a JET and on nothing else in this fleet: NOTHING on this aeroplane may spin.
A build that ran without error proves nothing; this proves the artefact.
"""

import bpy, os, math, json, struct
from mathutils import Vector

GLB = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "..", "assets", "us", "aircraft", "f4_phantom_v2.glb")

# F-4E-proportioned airframe. The F-4C/D is 17.76 m; see the 2026-08-14 entry in
# production/blender_notes.md for why this build carries the E's numbers and how
# to switch (build_f4_phantom_v2.py NOSE_CUT).
REAL_LENGTH, REAL_SPAN, REAL_STAB_SPAN = 19.20, 11.71, 4.92
REAL_FIN_TOP_AGL = 4.98          # GEAR DOWN three-point figure - does NOT apply here
GROUND_Z = -2.05                 # local z of the ground line, gear extended

EXPECT = {"F4_Airframe", "F4_Stores", "F4_Markings",
          "F4_Col_Hull-colonly", "F4_Col_Wing-colonly", "F4_Col_Aft-colonly"}
# rotor_spin.gd:23-25 - a node whose lowered name contains any of these gets spun
PROP_HINTS = ("prop", "spinner", "blade")
MAIN_HINTS = ("mainrotor", "rotor_hub", "new_blade", "rotor_flybar", "new_rotor")
TAIL_HINTS = ("tailrotor", "tailblade", "new_tailblade")
# rotor_spin.gd:20 - an action with any of these names is played instead
SPIN_CLIPS = ("prop_spin", "A1_PropellerAction.001", "A1_PropellerAction", "rotor_spin")

fails = []


def check(ok, msg):
    print(("  PASS  " if ok else "  FAIL  ") + msg)
    if not ok:
        fails.append(msg)


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(GLB))

objs = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
print("\n--- f4_phantom_v2.glb ---------------------------------------")
print("  imported meshes: %s" % sorted(objs))

check(set(objs) == EXPECT, "node names exactly %s" % sorted(EXPECT))

# ---- the JET contract -------------------------------------------------------
# Read the GLB's own node table. Blender's glTF IMPORTER bakes the Y-up->Z-up
# conversion into mesh data and leaves object rotations at identity, so an
# imported object's transform tells you nothing about the shipped node. Godot
# reads the node transform, so the node transform is what has to be asserted.
raw = open(os.path.abspath(GLB), "rb").read()
gj = json.loads(raw[20:20 + struct.unpack("<I", raw[12:16])[0]])
nodes = {n.get("name"): n for n in gj["nodes"]}
print("  glTF nodes: %s" % {k: {a: v[a] for a in ("translation", "rotation", "scale")
                                if a in v} for k, v in nodes.items()})
for n in gj["nodes"]:
    check("rotation" not in n and "translation" not in n and "scale" not in n,
          "%s node is at identity - the whole airframe is one rigid body"
          % n.get("name"))

# cas_airplane.gd:104 attaches RotorSpin to EVERY fixed-wing model, jets
# included. A Phantom has no propeller, so the correct behaviour is for
# RotorSpin to bind nothing at all: no hint name anywhere, and no clip.
for name in objs:
    low = name.lower()
    hit = [h for h in PROP_HINTS + MAIN_HINTS + TAIL_HINTS if h in low]
    check(not hit, "%s trips no RotorSpin hint (would be spun at runtime: %s)"
          % (name, hit))
check(not bpy.data.actions,
      "no actions ship, so rotor_spin.gd:20 finds no %s clip and hand-spins "
      "nothing either - a jet's engines are audio, not geometry" % (SPIN_CLIPS,))


# ---- facing, scale, origin --------------------------------------------------
def bbox(names):
    a = Vector((1e9, 1e9, 1e9))
    b = Vector((-1e9, -1e9, -1e9))
    for n in names:
        ob = objs[n]
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

# After import the scene is Blender-Z-up again, so +Y is still the nose. Measure
# VISIBLE geometry only - the aft collider deliberately overhangs the rudder.
lo, hi = bbox(vis)
alo, ahi = bbox(["F4_Airframe"])
span, length, height = hi.x - lo.x, hi.y - lo.y, hi.z - lo.z
print("  visible bbox lo %s hi %s" % (tuple(round(c, 3) for c in lo),
                                      tuple(round(c, 3) for c in hi)))
check(abs(span - REAL_SPAN) < 0.05, "span %.3f m vs real %.3f" % (span, REAL_SPAN))
check(abs(length - REAL_LENGTH) < 0.10,
      "length %.3f m vs real %.3f (probe tip to rudder TE, as the manual "
      "three-view dimensions it)" % (length, REAL_LENGTH))
check(hi.y > 9.0 and lo.y < -8.0,
      "nose at +Y (Godot -Z): nose %+0.2f tail %+0.2f" % (hi.y, lo.y))
check(abs(lo.x + hi.x) < 0.02, "laterally symmetric about x=0 (%.4f)" % (lo.x + hi.x))

# CoM origin, not ground line. Do NOT test bbox symmetry - the fin is a thin
# surface 2.9 m up and skews the box. The check that matters is the code
# contract: cas_airplane.gd:355 spawns the strafe muzzle 1.2 m below the node
# origin and calls it "slightly under the fuselage", so the airframe's lowest
# skin must be just above that and not below it.
check(0.75 <= -alo.z <= 1.30,
      "airframe belly %.2f m below the origin -> cas_airplane.gd's -1.2 m strafe "
      "muzzle sits just under the skin, not inside it and not in mid-air" % -alo.z)
# and the origin must be near mid-length or the jet pivots about its nose
mid = (hi.y + lo.y) * 0.5
check(abs(mid) < 1.0,
      "origin is within %.2f m of mid-length (wing quarter MAC) - a nose-biased "
      "origin makes the flyby pivot about the radome" % abs(mid))

# ---- the identity geometry, measured, not eyeballed -------------------------
# The three canted surfaces ARE the Phantom. If a future edit flattens any of
# them the silhouette dies and nothing else in this file would notice.
air = objs["F4_Airframe"]
vw = [air.matrix_world @ v.co for v in air.data.vertices]
tipz = [v.z for v in vw if abs(v.x) > 5.60]
foldz = [v.z for v in vw if 4.05 < abs(v.x) < 4.35 and v.y > -2.0]
if tipz and foldz:
    rise = (sum(tipz) / len(tipz)) - (sum(foldz) / len(foldz))
    run = 5.72 - 4.20
    check(math.degrees(math.atan2(rise, run)) > 9.0,
          "outer wing panels are canted UP %.1f deg from the fold at x 4.205 "
          "(real 12 deg)" % math.degrees(math.atan2(rise, run)))
stab = [v for v in vw if v.y < -6.0 and abs(v.x) > 2.30]
if stab:
    droop = min(v.z for v in stab)
    check(droop < -0.35,
          "stabilator tips droop to z %+0.2f - the 23 deg anhedral that makes "
          "the X from astern" % droop)
    sspan = 2.0 * max(abs(v.x) for v in stab)
    check(abs(sspan - REAL_STAB_SPAN) < 0.08,
          "stabilator span %.3f m vs real %.3f" % (sspan, REAL_STAB_SPAN))
finz = max(v.z for v in vw)
check(abs((finz - alo.z) - 3.91) < 0.10,
      "fin top %.3f m above the airframe belly. The published %.2f m height is "
      "a GEAR-DOWN three-point figure and does not apply to this level, "
      "gear-up model" % (finz - alo.z, REAL_FIN_TOP_AGL))
check(abs(lo.z - GROUND_Z) > 0.3,
      "origin is NOT on the ground line (lowest visible point z %+0.3f; the "
      "ground line is at %+0.2f - add that to park it)" % (lo.z, GROUND_Z))
print("  height (level, gear up, incl. stores) %.3f m" % height)

# Colliders must cover the SOLID airframe in plan. Not the pitot boom: that is a
# 5 cm needle 0.7 m ahead of the radome, and growing the collision hull to
# swallow it would push the jet's forward hit surface a metre past its nose. The
# solid nose is found by radius about the probe axis, not by the bbox - taking
# the bbox here is exactly how a needle silently inflates a hitbox.
clo, chi = bbox(cols)
solid = [v for v in vw if math.hypot(v.x, v.z + 0.60) > 0.12]
nose_solid = max(v.y for v in solid)
print("  airframe nose: probe tip %+0.3f, solid radome tip %+0.3f"
      % (ahi.y, nose_solid))
check(clo.x <= alo.x + 0.05 and chi.x >= ahi.x - 0.05
      and clo.y <= alo.y + 0.15 and chi.y >= nose_solid - 0.05,
      "colliders span the SOLID airframe in plan (x %.2f..%.2f vs %.2f..%.2f, "
      "y %.2f..%.2f vs %.2f..%.2f)" % (clo.x, chi.x, alo.x, ahi.x,
                                       clo.y, chi.y, alo.y, nose_solid))
check(chi.y < ahi.y,
      "the collision hull stops SHORT of the pitot boom (%.2f < %.2f) - a "
      "needle must not inflate the jet's hit surface" % (chi.y, ahi.y))
check(len(cols) == 3, "three -colonly colliders: %s" % sorted(cols))

for name, ob in objs.items():
    sc = ob.scale
    check(abs(sc.x - 1) < 1e-4 and abs(sc.y - 1) < 1e-4 and abs(sc.z - 1) < 1e-4,
          "%s scale is 1,1,1" % name)

# ---- materials --------------------------------------------------------------
mats = sorted(m.name for m in bpy.data.materials)
print("  materials (%d): %s" % (len(mats), mats))
check(all(not m.startswith("Material") and "tmp" not in m.lower() for m in mats),
      "no temp / default material names")
for m in bpy.data.materials:
    b = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if b is None:
        continue
    check(b.inputs["Metallic"].default_value < 0.01,
          "%s is non-metallic (%.2f) - no PSX sparkle"
          % (m.name, b.inputs["Metallic"].default_value))
imgs = [i.name for i in bpy.data.images if i.name != "Render Result"]
check(not imgs, "no textures shipped (flat-material fleet convention): %s" % imgs)
# all three SEA colours plus the grey must survive the export, or the camo is
# a single flat blob and nobody notices until it is in the game
for want in ("f4_sea_tan", "f4_sea_green_med", "f4_sea_green_dark",
             "f4_underside_grey"):
    check(want in mats, "%s survived the export" % want)

print("\n  VISIBLE TRIS %d   collider tris %d"
      % (tris, sum(len(objs[c].data.loop_triangles) for c in cols)))
print("\n%s  (%d failures)" % ("VERIFY PASS" if not fails else "VERIFY FAIL", len(fails)))
for f in fails:
    print("   ! " + f)
