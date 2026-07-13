"""Create unit_us_pilot.blend: the US grunt body + rig, with the derived
aircrew animations baked in, ready to be modified into a pilot.

Strips the grunt's infantry-only gear (helmet, bandolier, pack, M16) so the
mesh is a clean body to build flight gear onto, and leaves every action -
including the six derived ones - on the rig with fake users.

Run: blender -b "unit_us_grunt.blend" -P make_pilot_base.py
"""
import bpy, sys, importlib

sys.path.insert(0, r'C:\Users\caleb\RECONgame\tools')
import derive_actions
importlib.reload(derive_actions)

OUT = r"C:\Users\caleb\RECONgame\assets\us\characters\unit_us_pilot.blend"

# 1. derive the new animations onto this file's actions
derive_actions.build_all()

# 2. keep every action alive through the save
for a in bpy.data.actions:
    a.use_fake_user = True

# 3. drop the old M16 - the pilot gets a .38, not a rifle
for ob in list(bpy.data.objects):
    if 'm16' in ob.name.lower():
        print("removed:", ob.name, flush=True)
        bpy.data.objects.remove(ob, do_unlink=True)

# 4. T-pose for modelling: clear the action AND put the armature in rest position,
#    so the mesh sits in Mixamo's bind pose with no animation deforming it.
rig = bpy.data.objects['MixamoRig']
if rig.animation_data:
    rig.animation_data.action = None
rig.data.pose_position = 'REST'
bpy.context.scene.frame_set(1)
bpy.context.view_layer.update()
print("rig in REST (T-pose); flip Armature > Pose Position to preview animations", flush=True)

print("\nACTIONS AVAILABLE ON MixamoRig:", flush=True)
for a in sorted(bpy.data.actions, key=lambda x: x.name):
    f0, f1 = derive_actions.frame_span(a)
    print(f"  {a.name:28s} frames {int(f0):3d}-{int(f1):3d}", flush=True)

print("\nMESH PARTS (grunt gear to strip/replace for the pilot):", flush=True)
for ob in sorted(bpy.data.objects, key=lambda o: o.name):
    if ob.type == 'MESH':
        print(f"  {ob.name}  ({len(ob.data.vertices)} verts)", flush=True)

bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("\nPILOT BASE SAVED:", OUT, flush=True)
