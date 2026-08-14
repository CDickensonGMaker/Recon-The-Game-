"""Re-import a1_skyraider_v2.glb and assert the export contract.

    blender -b --factory-startup --python tools/verify_a1_skyraider_v2.py

Checks the SHIPPED file, not the build scene: node names, the propeller's spin
axis in Godot terms, facing, real dimensions, collider naming and materials.
A build that ran without error proves nothing; this proves the artefact.
"""

import bpy, os, math, json, struct
from mathutils import Vector

GLB = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "..", "assets", "us", "aircraft", "a1_skyraider_v2.glb")

REAL_LENGTH, REAL_SPAN, REAL_PROP_D = 11.84, 15.25, 4.115
EXPECT = {"A1_Airframe", "A1_Stores", "A1_Markings", "A1_Prop",
          "A1_Col_Hull-colonly", "A1_Col_Wing-colonly", "A1_Col_Aft-colonly"}
# rotor_spin.gd:25 - a node whose lowered name contains one of these gets spun
PROP_HINTS = ("prop", "spinner", "blade")
MAIN_HINTS = ("mainrotor", "rotor_hub", "new_blade", "rotor_flybar", "new_rotor")
TAIL_HINTS = ("tailrotor", "tailblade", "new_tailblade")

fails = []


def check(ok, msg):
    print(("  PASS  " if ok else "  FAIL  ") + msg)
    if not ok:
        fails.append(msg)


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(GLB))

objs = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
print("\n--- a1_skyraider_v2.glb -------------------------------------")
print("  imported meshes: %s" % sorted(objs))

check(set(objs) == EXPECT, "node names exactly %s" % sorted(EXPECT))

# ---- the propeller contract -------------------------------------------------
# Read the GLB's own node table. Blender's glTF IMPORTER bakes the Y-up->Z-up
# conversion into mesh data and leaves object rotations at identity, so an
# imported object's local Z tells you nothing about the shipped node. Godot reads
# the node transform, so the node transform is what has to be asserted.
raw = open(os.path.abspath(GLB), "rb").read()
gj = json.loads(raw[20:20 + struct.unpack("<I", raw[12:16])[0]])
nodes = {n.get("name"): n for n in gj["nodes"]}
print("  glTF nodes: %s" % {k: {a: v[a] for a in ("translation", "rotation", "scale")
                                if a in v} for k, v in nodes.items()})
pn = nodes.get("A1_Prop", {})
rot = pn.get("rotation")
check(rot is None or (abs(rot[3]) > 0.9999 and max(abs(c) for c in rot[:3]) < 1e-4),
      "A1_Prop glTF node rotation is IDENTITY -> its Godot local Z is the thrust "
      "line, which is the axis rotor_spin.gd:76 turns (rotation=%s)" % rot)
tr = pn.get("translation")
check(tr is not None and abs(tr[0]) < 1e-4 and tr[2] < -4.0,
      "A1_Prop hub is on the centreline and forward at Godot -Z (%s)" % tr)
for n in gj["nodes"]:
    if n.get("name") != "A1_Prop":
        check("rotation" not in n and "translation" not in n,
              "%s node is at identity" % n.get("name"))

prop = objs.get("A1_Prop")
if prop is not None:
    check(any(h in prop.name.lower() for h in PROP_HINTS),
          "A1_Prop matches RotorSpin.PROP_HINTS (gets spun at PROP_RPS)")
    # after import the disc lies in the Blender XZ plane (thrust line is +Y)
    r = max(math.hypot(v.co.x, v.co.z) for v in prop.data.vertices)
    check(abs(2.0 * r - REAL_PROP_D) < 0.05,
          "prop diameter %.3f m vs real %.3f" % (2.0 * r, REAL_PROP_D))

for name, ob in objs.items():
    if ob is prop:
        continue
    low = name.lower()
    check(not any(h in low for h in PROP_HINTS + MAIN_HINTS + TAIL_HINTS),
          "%s does NOT trip a RotorSpin hint" % name)

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
alo, ahi = bbox(["A1_Airframe"])
span, length, height = hi.x - lo.x, hi.y - lo.y, hi.z - lo.z
print("  visible bbox lo %s hi %s" % (tuple(round(c, 3) for c in lo),
                                      tuple(round(c, 3) for c in hi)))
check(abs(span - REAL_SPAN) < 0.05, "span %.3f m vs real %.3f" % (span, REAL_SPAN))
check(abs(length - REAL_LENGTH) < 0.10, "length %.3f m vs real %.3f" % (length, REAL_LENGTH))
check(hi.y > 5.0 and lo.y < -5.0, "nose at +Y (Godot -Z): nose %+0.2f tail %+0.2f" % (hi.y, lo.y))
check(abs(lo.x + hi.x) < 0.02, "laterally symmetric about x=0 (%.4f)" % (lo.x + hi.x))
# CoM origin, not ground line. Do NOT test bbox symmetry - the fin is a thin
# surface 2.2 m up and skews the box, while the mass sits on the fuselage
# centreline. The check that matters is the code contract: cas_airplane.gd:355
# spawns the strafe muzzle 1.2 m below the node origin and calls it "slightly
# under the fuselage", so the airframe's lowest skin must be just above that.
check(0.75 <= -alo.z <= 1.30,
      "airframe belly %.2f m below the origin -> cas_airplane.gd's -1.2 m strafe "
      "muzzle sits just under the skin, not inside it and not in mid-air" % -alo.z)
check(abs(lo.z + 1.60) < 0.05,
      "ground line (lowest point, prop tip) at z %+0.3f - add this to park it" % lo.z)
print("  height (level, gear up, incl. prop arc + stores) %.3f m" % height)
print("  airframe fin-top-above-belly %.3f m" % (ahi.z - alo.z))

# colliders must actually cover the airframe in plan
clo, chi = bbox(cols)
check(clo.x <= alo.x + 0.05 and chi.x >= ahi.x - 0.05
      and clo.y <= alo.y + 0.15 and chi.y >= ahi.y - 0.60,
      "colliders span the airframe in plan (x %.2f..%.2f vs %.2f..%.2f, "
      "y %.2f..%.2f vs %.2f..%.2f)" % (clo.x, chi.x, alo.x, ahi.x,
                                       clo.y, chi.y, alo.y, ahi.y))

# ---- transforms and colliders ----------------------------------------------
for name, ob in objs.items():
    r = ob.rotation_euler if ob.rotation_mode == "XYZ" else None
    sc = ob.scale
    check(abs(sc.x - 1) < 1e-4 and abs(sc.y - 1) < 1e-4 and abs(sc.z - 1) < 1e-4,
          "%s scale is 1,1,1" % name)

check(len(cols) == 3, "three -colonly colliders: %s" % sorted(cols))

# ---- materials --------------------------------------------------------------
mats = sorted(m.name for m in bpy.data.materials)
print("  materials (%d): %s" % (len(mats), mats))
check(all(not m.startswith("Material") and "tmp" not in m.lower()
          for m in mats), "no temp / default material names")
for m in bpy.data.materials:
    b = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if b is None:
        continue
    check(b.inputs["Metallic"].default_value < 0.01,
          "%s is non-metallic (%.2f) - no PSX sparkle"
          % (m.name, b.inputs["Metallic"].default_value))
imgs = [i.name for i in bpy.data.images if i.name != "Render Result"]
check(not imgs, "no textures shipped (flat-material fleet convention): %s" % imgs)

check(not bpy.data.actions, "no baked animation (runtime spin path in rotor_spin.gd)")

print("\n  VISIBLE TRIS %d   collider tris %d"
      % (tris, sum(len(objs[c].data.loop_triangles) for c in cols)))
print("\n%s  (%d failures)" % ("VERIFY PASS" if not fails else "VERIFY FAIL", len(fails)))
for f in fails:
    print("   ! " + f)
