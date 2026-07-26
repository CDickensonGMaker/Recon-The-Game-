"""Export ONE weapon's FP viewmodel with ALL its clips.

    blender -b fp_arms_rifle.blend -P tools/export_viewmodel_clips.py -- RIG_M14 M14 m14

Exports every object in the gun's RIG_<gun> collection (arms + rig + gun + its moving
parts + markers), one named glTF animation per NLA track.

THE THING THIS EXISTS TO FIX: glTF has no constraints, and Blender's exporter only
samples an object it considers animated - meaning an object carrying TRS fcurves. Our
moving parts carry none: the magazine's entire motion is a CHILD_OF pointed at hand.L
with a keyed influence, and the rifle rides hand.R the same way. The exporter therefore
wrote NO channels for the magazine at all (it stayed welded to the rifle in game - "the
mag never disappears") and only the constant keys for the rifle root.

So we bake first: evaluate every clip frame by frame, record each part's world matrix,
strip the constraints, and write the result back as real location/rotation/scale keys.
glTF then has actual channels to carry.

Two supporting rules:
  * NLA_TRACKS, never ACTIONS - ACTIONS bakes each object's action in isolation, so a
    part gets sampled against an unposed arm and lands hundreds of mm from its hand.
  * No non-uniform scale on anything animated - glTF stores T/R/S separately, so
    non-uniform scale plus inherited rotation is a shear it cannot represent, and the
    decomposition comes out as a tumbling rotation.

Never saves the .blend.
"""
import bpy, sys, os
from mathutils import Matrix

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

# --- make the collection visible and evaluable -------------------------------
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

# --- clip tracks: drop the review row, unmute, clear masking active actions ---
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

# clip name -> authored length, taken from the RIG's strip (the authority)
clip_len = {}
for t in rig.animation_data.nla_tracks:
    for s in t.strips:
        clip_len[t.name] = max(clip_len.get(t.name, 0), int(round(s.frame_end)))
print("clips:", {k: f"0-{v}" for k, v in sorted(clip_len.items())})

# parts that move but carry no TRS fcurves of their own
parts = [o for o in objs if o.type != 'ARMATURE'
         and (o.constraints or (o.animation_data and o.animation_data.nla_tracks))]
print("parts to bake:", [o.name for o in parts])


def depth(o):
    d, p = 0, o.parent
    while p:
        d, p = d + 1, p.parent
    return d


parts.sort(key=depth)          # parents first, so a child's basis is solved against a baked parent


def solo(track):
    for o in objs:
        if o.animation_data:
            for t in o.animation_data.nla_tracks:
                t.mute = (t.name != track)


# --- 1. record every part's world matrix, per clip, with constraints live -----
sc = bpy.context.scene
recorded = {}
for clip, end in clip_len.items():
    solo(clip)
    frames = {}
    for f in range(0, end + 1):
        sc.frame_set(f)
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        frames[f] = {o.name: o.evaluated_get(dg).matrix_world.copy() for o in parts}
    recorded[clip] = frames
print(f"recorded {sum(len(v) for v in recorded.values())} frames across {len(recorded)} clips")

# --- 2. strip constraints and the old animation off the parts ----------------
for o in parts:
    for c in list(o.constraints):
        o.constraints.remove(c)
    if o.animation_data:
        o.animation_data.action = None
        for t in list(o.animation_data.nla_tracks):
            o.animation_data.nla_tracks.remove(t)
bpy.context.view_layer.update()

# --- 3. write the recorded motion back as real TRS keys ---------------------
for clip, frames in recorded.items():
    acts = {}
    for o in parts:
        a = bpy.data.actions.new(f"{OUTNAME}_{clip}_{o.name}")
        a.use_fake_user = True
        acts[o.name] = a
    for f in sorted(frames):
        sc.frame_set(f)
        for o in parts:                     # parent-first: see the depth sort above
            if o.animation_data is None:
                o.animation_data_create()
            if o.animation_data.action is not acts[o.name]:
                o.animation_data.action = acts[o.name]
            o.matrix_world = frames[f][o.name]
            bpy.context.view_layer.update()
            o.keyframe_insert("location", frame=f)
            o.keyframe_insert("rotation_quaternion" if o.rotation_mode == 'QUATERNION'
                              else "rotation_euler", frame=f)
            o.keyframe_insert("scale", frame=f)
    for o in parts:
        o.animation_data.action = None
        t = o.animation_data.nla_tracks.new()
        t.name = clip
        s = t.strips.new(acts[o.name].name, 0, acts[o.name])
        s.blend_type = 'REPLACE'
        s.extrapolation = 'HOLD'
        t.mute = False
print("baked parts to explicit TRS keys")

# --- 4. no non-uniform scale on anything animated ----------------------------
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
    if animated and (abs(s[0] - s[1]) > 1e-4 or abs(s[1] - s[2]) > 1e-4):
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        o.select_set(False)
        fixed.append((o.name, [round(v, 4) for v in s]))
print("non-uniform scale applied on animated parts:", fixed or "none needed")

# --- 5. contract marker names ------------------------------------------------
for src, dst in ((f"muzzle_{GUN}", "MuzzlePoint"),
                 (f"sight_front_{GUN}", "SightFront"),
                 (f"sight_rear_{GUN}", "SightRear")):
    o = bpy.data.objects.get(src)
    if o:
        o.name = dst
    else:
        print(f"   WARNING: {src} missing")

# --- 6. export ---------------------------------------------------------------
for o in bpy.data.objects:
    o.select_set(False)
for o in objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = rig
sc.frame_set(0)

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
kwargs = {k: v for k, v in kwargs.items() if k in valid}
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(**kwargs)
print(f"EXPORTED {OUTNAME}_fp.glb  {os.path.getsize(OUT) / 1024 / 1024:.2f} MB  (blend NOT saved)")
