"""Export ONE weapon's FP viewmodel: arms + gun + MuzzlePoint + rifle_idle.

Clean per-weapon glb for Godot. Strips the leftover PSX animations (keeps only
rifle_idle), renames the gun's muzzle_<gun> empty to 'MuzzlePoint' (the name
weapon_holder looks for), and exports only arms + that gun + its muzzle.

Runs headless on fp_arms_rifle.blend, never saves it.
    blender -b fp_arms_rifle.blend -P export_viewmodel.py -- M14_Rifle m14

argv: <gun_object_name> <out_basename>
"""
import bpy, sys, os

argv = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
GUN = argv[0] if argv else 'M14_Rifle'
OUTNAME = argv[1] if len(argv) > 1 else 'm14'
IDLE = argv[2] if len(argv) > 2 else 'rifle_idle'   # per-gun arm pose action
OUT = rf"C:\Users\caleb\RECONgame\assets\player\viewmodels\{OUTNAME}_fp.glb"

arm = bpy.data.objects['ArmsRig']
mesh = bpy.data.objects['ArmsMesh']
gun = bpy.data.objects.get(GUN)
if gun is None:
    raise SystemExit(f"gun {GUN} not found")

# set this gun's arm pose
if arm.animation_data is None:
    arm.animation_data_create()
idle = bpy.data.actions.get(IDLE)
if idle is None:
    raise SystemExit(f"idle action '{IDLE}' not found")
arm.animation_data.action = idle
if len(idle.slots):
    arm.animation_data.action_slot = idle.slots[0]
bpy.context.scene.frame_set(1)

# strip ALL pose-bone constraints (staging locks, arm IK, finger COPY_ROTATION)
# so sampling reads the idle action verbatim. Every *_idle is a visual-keyed
# full bake of all 52 bones, so the constraints are redundant here and live
# staging locks (e.g. handIK.L -> grip_L_<staged gun>) would corrupt the pose.
stripped = 0
for pb in arm.pose.bones:
    for con in list(pb.constraints):
        pb.constraints.remove(con)
        stripped += 1
print(f"stripped {stripped} pose-bone constraints (export reads action verbatim)")

# keep ONLY this gun's idle, renamed to 'rifle_idle' so every viewmodel has the same clip name
for a in list(bpy.data.actions):
    if a.name != IDLE:
        a.use_fake_user = False
        bpy.data.actions.remove(a)
idle.name = 'rifle_idle'
print("actions kept:", [a.name for a in bpy.data.actions])

# rename this gun's muzzle empty -> MuzzlePoint (the contract name)
muz = bpy.data.objects.get(f'muzzle_{GUN}')
if muz:
    muz.name = 'MuzzlePoint'
    print("muzzle -> MuzzlePoint, parent:", muz.parent.name if muz.parent else None)
else:
    print(f"WARNING: no muzzle_{GUN} empty found")

# rename ADS sight markers -> SightRear / SightFront (the contract names)
rear = bpy.data.objects.get(f'sight_rear_{GUN}')
if rear is None:
    rear = bpy.data.objects.get('sight_rear')
if rear:
    rear.name = 'SightRear'
    print("sight rear -> SightRear")
front = bpy.data.objects.get(f'sight_front_{GUN}')
if front is None:
    front = bpy.data.objects.get('sight_front')
if front:
    front.name = 'SightFront'
    print("sight front -> SightFront")

# select ONLY arms + this gun + MuzzlePoint + sight markers (+ nothing else)
mesh.hide_select = False
for o in bpy.data.objects:
    o.hide_set(False); o.hide_viewport = False
# file may be saved in pose mode; ops need OBJECT mode and a valid active object
bpy.context.view_layer.objects.active = arm
if bpy.context.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
for o in bpy.data.objects:
    o.select_set(False)
export_set = [arm, mesh, gun]
if muz: export_set.append(muz)
if rear: export_set.append(rear)
if front: export_set.append(front)
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
print(f"EXPORTED {OUTNAME}_fp.glb  {mb:.2f} MB  (blend NOT saved)")
