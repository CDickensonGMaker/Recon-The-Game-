"""Export ONE weapon's FP viewmodel with ALL its clips.

    blender -b fp_arms_rifle.blend -P tools/export_viewmodel_clips.py -- RIG_M14 M14 m14

Exports every object in the gun's RIG_<gun> collection (arms + rig + gun + its moving
parts + markers) and every NLA track on them as one named glTF animation each.

Two rules this exists to enforce:

  NLA_TRACKS, never ACTIONS. Moving parts (magazine, op-rod, charge handle) are driven
  by CHILD_OF constraints pointed at arm bones. ACTIONS mode bakes each object's action
  in isolation, so the part gets sampled against an unposed arm and lands hundreds of mm
  from the hand it is supposed to ride. Track mode evaluates every object's strip for a
  clip together, so the constraint resolves against the real pose.

  No non-uniform scale on anything animated. glTF nodes store translation/rotation/scale
  separately; a non-uniform scale combined with inherited rotation is a shear, which TRS
  cannot express, and the exporter's decomposition turns it into a tumbling rotation.

Never saves the .blend.
"""
import bpy, sys, os

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
if len(argv) < 3:
    raise SystemExit("argv: <collection> <gun_object_prefix> <out_basename>")
COLL, GUN, OUTNAME = argv[0], argv[1], argv[2]
OUT = rf"C:\Users\caleb\RECONgame\assets\player\viewmodels\{OUTNAME}_fp.glb"
REVIEW_TRACK = "ZZ_REVIEW_ROW"

coll = bpy.data.collections.get(COLL)
if coll is None:
    raise SystemExit(f"collection {COLL} not found")
objs = list(coll.objects)
rig = next((o for o in objs if o.type == 'ARMATURE'), None)
if rig is None:
    raise SystemExit(f"no armature in {COLL}")
print(f"=== {OUTNAME}: {len(objs)} objects from {COLL}, rig {rig.name} ===")

# --- make the whole collection visible and evaluable -------------------------
vl = bpy.context.view_layer


def layer_coll(name, layer=None):
    layer = layer or vl.layer_collection
    if layer.collection.name == name:
        return layer
    for ch in layer.children:
        r = layer_coll(name, ch)
        if r:
            return r


lc = layer_coll(COLL)
if lc:
    lc.exclude = False
    lc.hide_viewport = False
for o in objs:
    o.hide_viewport = False
    o.hide_render = False
    o.hide_select = False
bpy.context.view_layer.update()
for o in objs:
    o.hide_set(False)

# --- clip tracks: drop the review row, unmute the rest, clear active actions --
# an active action sits on top of the NLA stack and masks it
clips = set()
for o in objs:
    ad = o.animation_data
    if not ad:
        continue
    ad.action = None
    for t in list(ad.nla_tracks):
        if t.name == REVIEW_TRACK:
            ad.nla_tracks.remove(t)
    for t in ad.nla_tracks:
        t.mute = False
        clips.add(t.name)
print("clips to export:", sorted(clips))
for o in objs:
    if o.animation_data and o.animation_data.nla_tracks:
        print(f"   {o.name}: " + ", ".join(
            f"{t.name}({int(s.frame_start)}-{int(s.frame_end)})"
            for t in o.animation_data.nla_tracks for s in t.strips))

# --- kill non-uniform scale on anything that animates ------------------------
if bpy.context.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
for o in bpy.data.objects:
    o.select_set(False)
fixed = []
for o in objs:
    if o.type != 'MESH':
        continue
    animated = o.animation_data and (o.animation_data.action or o.animation_data.nla_tracks)
    s = o.scale
    non_uniform = abs(s[0] - s[1]) > 1e-4 or abs(s[1] - s[2]) > 1e-4
    if animated and non_uniform:
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        o.select_set(False)
        fixed.append((o.name, [round(v, 4) for v in s]))
print("non-uniform scale applied on animated parts:", fixed or "none needed")

# --- contract marker names ---------------------------------------------------
for src, dst in ((f"muzzle_{GUN}", "MuzzlePoint"),
                 (f"sight_front_{GUN}", "SightFront"),
                 (f"sight_rear_{GUN}", "SightRear")):
    o = bpy.data.objects.get(src)
    if o:
        o.name = dst
        print(f"   {src} -> {dst}")
    else:
        print(f"   WARNING: {src} missing")

# --- select and export -------------------------------------------------------
for o in bpy.data.objects:
    o.select_set(False)
for o in objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.context.scene.frame_set(0)

kwargs = dict(
    filepath=OUT, export_format='GLB', use_selection=True,
    export_apply=True, export_yup=True,
    export_animations=True, export_animation_mode='NLA_TRACKS',
    export_bake_animation=True, export_force_sampling=True,
    export_anim_single_armature=True, export_reset_pose_bones=False,
    export_skins=True, export_morph=False, export_optimize_animation_size=False,
    export_materials='EXPORT', export_cameras=False, export_lights=False,
    export_draco_mesh_compression_enable=False)
valid = set(bpy.ops.export_scene.gltf.get_rna_type().properties.keys())
dropped = [k for k in kwargs if k not in valid]
kwargs = {k: v for k, v in kwargs.items() if k in valid}
if dropped:
    print("exporter does not support (skipped):", dropped)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(**kwargs)
print(f"EXPORTED {OUTNAME}_fp.glb  {os.path.getsize(OUT) / 1024 / 1024:.2f} MB  (blend NOT saved)")
