"""Export the flashlight FP viewmodel: arms + Colt45 + MX991 flashlight.

Same contract as export_viewmodel.py but bundles TWO held objects:
right hand Colt45_Pistol (muzzle -> 'MuzzlePoint'), left hand MX991_Flashlight
(light_origin -> 'LightOrigin' for the beam attach in Godot).

Runs headless on fp_arms_rifle.blend, never saves it.
    blender -b fp_arms_rifle.blend -P export_flashlight_fp.py
"""
import bpy, os

IDLE = 'flashlight_idle'
OUT = r"C:\Users\caleb\RECONgame\assets\player\viewmodels\flashlight_fp.glb"

arm = bpy.data.objects['ArmsRig']
mesh = bpy.data.objects['ArmsMesh']
colt = bpy.data.objects['Colt45_Pistol']
fl = bpy.data.objects['MX991_Flashlight']

if arm.animation_data is None:
    arm.animation_data_create()
idle = bpy.data.actions.get(IDLE)
if idle is None:
    raise SystemExit(f"idle action '{IDLE}' not found")
arm.animation_data.action = idle
if len(idle.slots):
    arm.animation_data.action_slot = idle.slots[0]
bpy.context.scene.frame_set(1)

# strip ALL pose-bone constraints so sampling reads the idle action verbatim
# (every *_idle is a visual-keyed full bake; live staging locks would corrupt the pose)
stripped = 0
for pb in arm.pose.bones:
    for con in list(pb.constraints):
        pb.constraints.remove(con)
        stripped += 1
print(f"stripped {stripped} pose-bone constraints (export reads action verbatim)")

# keep ONLY the idle, renamed to 'rifle_idle' (the shared viewmodel clip name)
for a in list(bpy.data.actions):
    if a.name != IDLE:
        a.use_fake_user = False
        bpy.data.actions.remove(a)
idle.name = 'rifle_idle'
print("actions kept:", [a.name for a in bpy.data.actions])

muz = bpy.data.objects.get('muzzle_Colt45_Pistol')
if muz:
    muz.name = 'MuzzlePoint'
    print("muzzle -> MuzzlePoint, parent:", muz.parent.name if muz.parent else None)
else:
    print("WARNING: no muzzle_Colt45_Pistol empty found")

light = bpy.data.objects.get('light_origin_MX991_Flashlight')
if light:
    light.name = 'LightOrigin'
    print("light_origin -> LightOrigin, parent:", light.parent.name if light.parent else None)
else:
    print("WARNING: no light_origin_MX991_Flashlight empty found")

mesh.hide_select = False
for o in bpy.data.objects:
    o.hide_set(False); o.hide_viewport = False
bpy.context.view_layer.objects.active = arm
if bpy.context.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
for o in bpy.data.objects:
    o.select_set(False)
export_set = [arm, mesh, colt, fl]
if muz: export_set.append(muz)
if light: export_set.append(light)
for o in export_set:
    o.select_set(True)
bpy.context.view_layer.objects.active = arm
print("exporting:", [o.name for o in export_set])

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format='GLB', use_selection=True,
    export_apply=True, export_yup=True,
    export_animations=True, export_animation_mode='ACTIONS',
    export_bake_animation=True, export_anim_single_armature=True,
    export_skins=True, export_morph=False,
    export_materials='EXPORT', export_cameras=False, export_lights=False,
    export_draco_mesh_compression_enable=False)
mb = os.path.getsize(OUT)/(1024*1024)
print(f"EXPORTED flashlight_fp.glb  {mb:.2f} MB  (blend NOT saved)")
