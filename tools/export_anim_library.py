"""Export the shared PSXRig animation library as a rig-only .glb (no meshes).

One skeleton, one file, every character on PSXRig shares it. Add new clips to
anim_library.blend, re-run this, and the whole roster gets them — character
GLBs never need re-export for animation changes.

Policy applied on the throwaway export copy (never saved):
  * armature renamed PSXRig so track paths match every character GLB
  * X_fixed replaces broken X (reloading, firing_rifle, idle_aiming, ...)
  * all meshes/materials/images stripped — this is animation data only
  * Hips X/Z root motion stripped (engine drives velocity; Y kept for
    deaths/crouches/jumps)
  * every clip gets an NLA strip so ACTIONS-mode export emits all of them

    blender -b art_source/characters/base_psx/anim_library.blend -P tools/export_anim_library.py
"""
import bpy, os

OUT = r"C:\Users\caleb\RECONgame\assets\models\characters\anim_library.glb"

# ---------------------------------------------------------------- rig only
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
rig.name = "PSXRig"
rig.data.name = "PSXRig"
for o in [o for o in bpy.data.objects if o is not rig]:
    bpy.data.objects.remove(o, do_unlink=True)
for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.textures):
    for db in list(coll):
        try: coll.remove(db)
        except Exception: pass
print(f"rig-only scene: {rig.name}, {len(rig.data.bones)} bones", flush=True)

# ---------------------------------------------------------------- actions
junk = bpy.data.actions.get("m16_visibility_reel")
if junk:
    junk.use_fake_user = False
    bpy.data.actions.remove(junk)

for a in list(bpy.data.actions):
    if a.name.endswith("_fixed"):
        broken = bpy.data.actions.get(a.name[:-6])
        if broken:
            broken.use_fake_user = False
            bpy.data.actions.remove(broken)
        a.name = a.name[:-6]

s1 = bpy.data.actions.get("strafe_1")
if s1:
    s1.name = "strafe_2"

def channelbag(act):
    if not len(act.layers) or not len(act.layers[0].strips):
        return None
    return act.layers[0].strips[0].channelbag(act.slots[0])

n = 0
for act in bpy.data.actions:
    bag = channelbag(act)
    if bag is None:
        continue
    for fc in list(bag.fcurves):
        if fc.data_path == 'pose.bones["mixamorig:Hips"].location' and fc.array_index in (0, 2):
            bag.fcurves.remove(fc)
            n += 1
print(f"stripped {n} root-motion curves across {len(bpy.data.actions)} clips", flush=True)

# ---------------------------------------------------------------- NLA strips
# ACTIONS-mode export emits actions referenced by the object; give every clip a strip
if rig.animation_data is None:
    rig.animation_data_create()
rig.animation_data.action = None
for tr in list(rig.animation_data.nla_tracks):
    rig.animation_data.nla_tracks.remove(tr)
track = rig.animation_data.nla_tracks.new()
track.name = "library"
start = 1
for act in sorted(bpy.data.actions, key=lambda a: a.name):
    strip = track.strips.new(act.name, start, act)
    start = int(strip.frame_end) + 1
track.mute = True
print(f"{len(track.strips)} clips on export track", flush=True)

# ---------------------------------------------------------------- export
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active = rig

bpy.ops.export_scene.gltf(
    filepath=OUT,
    export_format='GLB',
    use_selection=True,
    export_apply=True,
    export_yup=True,
    export_animations=True,
    export_animation_mode='ACTIONS',
    export_bake_animation=True,
    export_anim_single_armature=True,
    export_optimize_animation_size=True,
    export_skins=True,
    export_morph=False,
    export_materials='NONE',
    export_cameras=False,
    export_lights=False,
    export_extras=True,
)
mb = os.path.getsize(OUT) / (1024 * 1024)
print(f"EXPORT COMPLETE -> {OUT}  {mb:.2f} MB  {len(bpy.data.actions)} clips  (blend NOT saved)", flush=True)
