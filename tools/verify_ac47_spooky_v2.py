"""Re-import ac47_spooky_v2.glb and assert the export contract.

    blender -b --factory-startup --python tools/verify_ac47_spooky_v2.py

Checks the SHIPPED file, not the build scene: node names, both propellers' spin
axes in Godot terms, the three muzzle empties, facing, real dimensions, collider
naming, materials and the port battery's asymmetry. A build that ran without
error proves nothing; this proves the artefact.

It also asserts that his ORIGINAL `ac47_spooky.glb` is byte-identical to the
copy this pipeline was built against - the whole commission is a new variant.
"""

import bpy, os, math, json, struct, hashlib
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
AIR = os.path.join(HERE, "..", "assets", "us", "aircraft")
GLB = os.path.abspath(os.path.join(AIR, "ac47_spooky_v2.glb"))
BASE = os.path.abspath(os.path.join(AIR, "ac47_spooky.glb"))
BASE_MD5 = "5ee96aabf0d59ebe613e09189f63c3e2"

REAL_LENGTH, REAL_SPAN, REAL_PROP_D = 19.43, 29.11, 3.51
REAL_STAB_SPAN, REAL_FUSE_W = 8.70, 2.60

MESHES = {"AC47_Airframe", "AC47_Guns", "AC47_Gear", "AC47_PortSide",
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


print("\n--- ac47_spooky_v2.glb --------------------------------------")

# ---- his original must be untouched -----------------------------------------
md5 = hashlib.md5(open(BASE, "rb").read()).hexdigest()
check(md5 == BASE_MD5,
      "his ac47_spooky.glb is byte-identical (%s) - v2 is a NEW variant" % md5)

raw = open(GLB, "rb").read()
gj = json.loads(raw[20:20 + struct.unpack("<I", raw[12:16])[0]])
nodes = {n.get("name"): n for n in gj["nodes"]}
print("  glTF nodes: %s" % sorted(nodes))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)

objs = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
emp = {o.name: o for o in bpy.data.objects if o.type == "EMPTY"}
check(set(objs) == MESHES, "mesh nodes exactly %s" % sorted(MESHES))
check(EMPTIES <= set(emp), "muzzle empties present: %s" % sorted(EMPTIES))

# ---- the propeller contract -------------------------------------------------
# Blender's glTF IMPORTER bakes the Y-up->Z-up conversion into mesh data and
# leaves object rotations at identity, so an imported object's local Z tells you
# nothing about the shipped node. Godot reads the NODE transform, so that is
# what has to be asserted - read it out of the file's own JSON.
for name, sign in (("AC47_Prop_L", -1.0), ("AC47_Prop_R", 1.0)):
    n = nodes.get(name, {})
    rot = n.get("rotation")
    check(rot is None or (abs(rot[3]) > 0.9999 and max(abs(c) for c in rot[:3]) < 1e-4),
          "%s glTF node rotation is IDENTITY -> its Godot local Z is the thrust "
          "line, the axis rotor_spin.gd:76 turns (rotation=%s)" % (name, rot))
    tr = n.get("translation")
    check(tr is not None and abs(abs(tr[0]) - 3.15) < 0.01 and tr[0] * sign > 0.0
          and tr[2] < -1.5,
          "%s hub is on its own side and forward at Godot -Z (%s)" % (name, tr))
    ob = objs[name]
    r = max(math.hypot(v.co.x, v.co.z) for v in ob.data.vertices)
    check(abs(2.0 * r - REAL_PROP_D) < 0.10,
          "%s disc %.3f m vs real %.3f" % (name, 2.0 * r, REAL_PROP_D))
    check(any(h in name.lower() for h in PROP_HINTS),
          "%s matches RotorSpin.PROP_HINTS (spun at PROP_RPS if RotorSpin binds)" % name)

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
# to the model at all.
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
ys = sorted(nodes[n]["translation"][2] for n in EMPTIES)
check(all(abs(ys[i + 1] - ys[i]) > 0.5 for i in range(len(ys) - 1)),
      "the three muzzles are spread along the fuselage (Godot z %s)"
      % [round(v, 3) for v in ys])

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
check(abs(length - REAL_LENGTH) < 0.10,
      "length %.3f m vs real %.3f (his base was 22.757 - +17%%)" % (length, REAL_LENGTH))
check(hi.y > 4.0 and lo.y < -12.0,
      "nose at +Y (Godot -Z): nose %+0.2f tail %+0.2f" % (hi.y, lo.y))
check(abs(lo.x + hi.x) < 0.02, "laterally symmetric about x=0 (%.4f)" % (lo.x + hi.x))

air = objs["AC47_Airframe"]
# Band chosen so ONLY the fuselage is in it. The origin is the wing quarter
# chord, so y ~ 0 is mid-WING and reads 2.18 m there - the fuselage's widest
# station is at y -6.7, aft of the wing trailing edge at y -5.79. A width query
# that does not name its band answers about whatever else was nearby.
fuse_w = 2.0 * max(abs(v.co.x) for v in air.data.vertices
                   if -8.0 < v.co.y < -6.0 and abs(v.co.x) < 1.60)
check(abs(fuse_w - REAL_FUSE_W) < 0.06,
      "fuselage %.3f m across vs real %.3f (his base was 3.631 - +40%%)"
      % (fuse_w, REAL_FUSE_W))
stab = 2.0 * max(abs(v.co.x) for v in air.data.vertices if v.co.y < -9.0)
check(abs(stab - REAL_STAB_SPAN) < 0.10,
      "tailplane %.3f m vs real %.3f (his base was 12.855 - +48%%)"
      % (stab, REAL_STAB_SPAN))

# Prop tip clearance is why the nacelles sit at 3.15 and not the drawing's 2.88.
hub_y = objs["AC47_Prop_L"].matrix_world.translation.y
at_prop = max(abs(v.co.x) for v in air.data.vertices
              if abs(v.co.y - hub_y) < 1.0 and abs(v.co.x) < 1.60)
gap = 3.15 - REAL_PROP_D * 0.5 - at_prop
check(gap > 0.05, "inboard prop tip clears the fuselage by %.3f m" % gap)

# ---- the port battery is the one thing that is NOT symmetric ----------------
guns = objs["AC47_Guns"]
gx = [v.co.x for v in guns.data.vertices]
check(max(gx) < 0.0, "every gun vertex is to PORT (max x %+0.3f)" % max(gx))
side = objs["AC47_PortSide"]
check(max(v.co.x for v in side.data.vertices) < 0.0,
      "the cargo door and gun ports are to PORT only")
for p in side.data.polygons:
    if p.normal.x >= -0.05:
        fails.append("AC47_PortSide face at %s is backfacing" % tuple(round(c, 2) for c in p.center))
check(all(p.normal.x < -0.05 for p in side.data.polygons),
      "no port-side decal is backfacing (worst n.x %.2f)"
      % max(p.normal.x for p in side.data.polygons))
check(abs(min(v.co.x for v in objs["AC47_Gear"].data.vertices)
          + max(v.co.x for v in objs["AC47_Gear"].data.vertices)) < 0.02,
      "the main wheels ARE symmetric - only the battery is one-sided")

# ---- ground line and origin -------------------------------------------------
# The static bbox understates the bottom: no blade sits at bottom dead centre in
# the rest pose, but the disc sweeps there.
arc_z = objs["AC47_Prop_L"].matrix_world.translation.z - REAL_PROP_D * 0.5
check(-0.35 < alo.z + 1.65 < 0.35,
      "airframe belly %.2f m below the origin (centred origin, not ground line)" % -alo.z)
print("  ground line (swept prop arc) z %+0.3f; static bbox bottoms at %+0.3f" % (arc_z, lo.z))
print("  height (level, gear up) %.3f m" % (hi.z - lo.z))

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

# ---- materials and his paint ------------------------------------------------
mats = sorted(m.name for m in bpy.data.materials)
print("  materials (%d): %s" % (len(mats), mats))
check(all(not m.startswith("Material") and "tmp" not in m.lower() for m in mats),
      "no temp / default material names (his base shipped 'Material'/'Material.001')")
for m in bpy.data.materials:
    b = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if b is None:
        continue
    check(b.inputs["Metallic"].default_value < 0.01,
          "%s is non-metallic (%.2f) - no PSX sparkle"
          % (m.name, b.inputs["Metallic"].default_value))
imgs = [i.name for i in bpy.data.images if i.name != "Render Result"]
check(imgs == ["planecamo"],
      "HIS camo texture ships, and only his. This is the fleet's one textured "
      "airframe on purpose - a1/f4 have no authored paint, this one does: %s" % imgs)
uvl = air.data.uv_layers.active
check(uvl is not None, "AC47_Airframe has a UV layer")
if uvl is not None:
    uniq = len({(round(d.uv[0], 4), round(d.uv[1], 4)) for d in uvl.data})
    check(uniq > 100, "AC47_Airframe carries %d unique UVs - his camo wrap "
                      "survived the merge (a single UV would be unpaintable)" % uniq)

check(1900 <= tris <= 3000,
      "visible tris %d inside the 2,000-3,000 class (his base was 2,483)" % tris)
print("  collider tris %d" % sum(len(objs[c].data.loop_triangles) for c in cols))

print("\n%s  (%d failures)" % ("VERIFY PASS" if not fails else "VERIFY FAIL", len(fails)))
for f in fails:
    print("   ! " + f)
