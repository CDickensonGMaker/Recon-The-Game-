"""build_ear_necklace_prop.py - the trophy-ear necklace as a REUSABLE prop.

    "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" --background ^
        "assets/us/characters/conquest_of_worms_us_cast.blend" ^
        --python tools/build_ear_necklace_prop.py

Writes assets/world/props/ear_necklace.blend and ear_necklace.glb.

CALEB'S RULING 2026-09-09: "should be its own blender object we make." It is Gus's state
marker (attach = Issue 3 p9, detach = Issue 2 p4 - one body, two states, no second
character), and the same mechanism later hangs the sniper's captured M1 helmets
(bible section 5, Issue 4 fya.23: "the sniper takes trophies too").

CONVENTION - the shovel one, NOT the rice bundle one. `scripts/world/civilian.gd:169-172`:
"The GLB's origin is the grip", attached with an identity transform under a
BoneAttachment3D. The other convention in this repo (`rice_bundle.glb`,
civilian.gd:178-190) bakes verts in rig REST-POSE WORLD space and its grip transform
"CANNOT BE DERIVED" - that file records deriving it landing the prop 1.70 m from the
fist. The two are not interchangeable, so this prop is authored bone-local:

    vert_local = bone.matrix_local.inverted() @ (rig.matrix_world.inverted() @ vert_world)

i.e. the origin IS the hang point at the head of `mixamorig:Spine2` (Godot:
`mixamorig_Spine2`), with the bone's own rest basis. Spine2 not Neck - a necklace rests
on the chest and must ride the torso; on the neck bone it swings when he turns his head.

NOT VERIFIED IN GODOT. I cannot run the engine from here. If it lands wrong, the thing to
check first is the head-vs-tail question: Blender's BONE parenting uses the bone TAIL,
Godot's BoneAttachment3D uses the bone's global pose at the HEAD, and this script uses the
HEAD (matrix_local) to match Godot. The numbers it needs are printed below.
"""
import bpy
import os
import sys
from mathutils import Vector, Matrix

D = bpy.data
ROOT = r"C:\Users\caleb\RECONgame"
PROPS = os.path.join(ROOT, "assets", "world", "props")
SRC_OBJ = "necklace_ears_gus_ears"
SRC_RIG = "PSXRig_gus_ears"
BONE = "mixamorig:Spine2"
OUT_BLEND = os.path.join(PROPS, "ear_necklace.blend")
OUT_GLB = os.path.join(PROPS, "ear_necklace.glb")

src = D.objects[SRC_OBJ]
rig = D.objects[SRC_RIG]
bone = rig.data.bones[BONE]

# The hang point, in world space, so it can be sanity-checked against the chest.
hang_world = rig.matrix_world @ bone.matrix_local.to_translation()
print("HANG POINT  bone %s head, world (%.4f, %.4f, %.4f)  rig at x=%.3f"
      % (BONE, hang_world.x, hang_world.y, hang_world.z, rig.matrix_world.translation.x),
      flush=True)

# world -> rig -> bone-local (head origin, bone rest basis)
to_local = bone.matrix_local.inverted() @ rig.matrix_world.inverted()

me = src.data.copy()
me.name = "ear_necklace"
obj = D.objects.new("ear_necklace", me)
bpy.context.scene.collection.objects.link(obj)
W = src.matrix_world.copy()
for v in me.vertices:
    v.co = to_local @ (W @ v.co)
obj.matrix_world = Matrix.Identity(4)
bpy.context.view_layer.update()

mn = Vector((min(v.co.x for v in me.vertices), min(v.co.y for v in me.vertices),
             min(v.co.z for v in me.vertices)))
mx = Vector((max(v.co.x for v in me.vertices), max(v.co.y for v in me.vertices),
             max(v.co.z for v in me.vertices)))
tris = sum(len(p.vertices) - 2 for p in me.polygons)
print("PROP ear_necklace  %d v / %d p / %d tris  materials %s"
      % (len(me.vertices), len(me.polygons), tris,
         [m.name for m in me.materials]), flush=True)
print("     BONE-LOCAL bbox  x[%.4f,%.4f] y[%.4f,%.4f] z[%.4f,%.4f]  (origin = hang point)"
      % (mn.x, mx.x, mn.y, mx.y, mn.z, mx.z), flush=True)
print("     span %.4f x %.4f x %.4f m" % (mx.x - mn.x, mx.y - mn.y, mx.z - mn.z), flush=True)

# GATE: the origin must actually be the hang point - the cord must straddle it, not sit
# a metre away. That is exactly the failure the rice-bundle comment records.
if not (mn.x <= 0.0 <= mx.x):
    raise SystemExit("ABORT: origin is outside the prop in X - it is not the hang point.")
d = min(abs(mn.x), abs(mx.x), abs(mn.y), abs(mx.y), abs(mn.z), abs(mx.z))
if max(abs(mn.length), abs(mx.length)) > 0.40:
    raise SystemExit("ABORT: prop extends %.3f m from its own origin - that is not a "
                     "necklace hung at the chest, the transform is wrong."
                     % max(abs(mn.length), abs(mx.length)))
print("     GATE origin-inside-prop OK; furthest vertex %.4f m from origin"
      % max(abs(mn.length), abs(mx.length)), flush=True)

for o in list(D.objects):
    if o is not obj:
        D.objects.remove(o, do_unlink=True)
# Three passes, and clear fake users first. One pass leaves the packed image datablocks
# alive behind a fake user and the .blend saves at 42 MB for a 26 KB prop (measured).
for _ in range(3):
    for blk in (D.meshes, D.armatures, D.materials, D.images, D.actions, D.node_groups):
        for x in list(blk):
            x.use_fake_user = False
            if x.users == 0:
                blk.remove(x)

os.makedirs(PROPS, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND, compress=True)
print("SAVED %s (%.2f MB)" % (OUT_BLEND, os.path.getsize(OUT_BLEND) / 1048576.0), flush=True)

for o in bpy.context.view_layer.objects:
    o.select_set(False)
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
bpy.ops.export_scene.gltf(
    filepath=OUT_GLB, export_format='GLB', use_selection=True, export_apply=True,
    export_yup=True, export_animations=False, export_skins=False, export_morph=False,
    export_materials='EXPORT', export_cameras=False, export_lights=False,
    export_draco_mesh_compression_enable=False, export_extras=True)
print("SAVED %s (%.0f KB)" % (OUT_GLB, os.path.getsize(OUT_GLB) / 1024.0), flush=True)

# read it back - names, tris, texture bytes
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=OUT_GLB)
got = [o for o in bpy.data.objects if o.type == 'MESH']
print("REIMPORT %d mesh(es): %s" % (len(got), [o.name for o in got]), flush=True)
for o in got:
    t = sum(len(p.vertices) - 2 for p in o.data.polygons)
    b = o.bound_box
    print("   %-16s %d tris  local bbox x[%.4f,%.4f] y[%.4f,%.4f] z[%.4f,%.4f]"
          % (o.name, t, min(c[0] for c in b), max(c[0] for c in b),
             min(c[1] for c in b), max(c[1] for c in b),
             min(c[2] for c in b), max(c[2] for c in b)), flush=True)
print("   embedded images: %d (texture budget: none is >1MB)"
      % len([i for i in bpy.data.images if i.size[0]]), flush=True)
