"""Build sprite_stage.blend: US grunt + VC1 farmer side by side, with the
v2 M16A1 and user's fixed AK-47 floating in front for hand placement.

Run:  blender -b "art_source/characters/us units/unit_us_grunt.blend" -P build_sprite_stage.py
(The grunt file is the base — keeps SpriteRig/SpriteCam wiring and 21 actions.)
"""
import bpy
from mathutils import Vector

CHAR = r"C:\Users\caleb\RECONgame\art_source\characters"
GUER = CHAR + r"\vc and nva units\unit_vc_guerilla.blend"
WUS  = CHAR + r"\us units\weapons_us.blend"
WV1  = CHAR + r"\us units\weapons_v1.blend"
OUT  = CHAR + r"\sprite_stage.blend"

# ---------- 1. strip old M16 + source-part backups ----------
removed = []
for ob in list(bpy.data.objects):
    if 'm16' in ob.name.lower():
        removed.append(ob.name)
        bpy.data.objects.remove(ob, do_unlink=True)
src = bpy.data.collections.get('GruntParts_Source')
if src:
    for ob in list(src.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    bpy.data.collections.remove(src)
print("removed old M16 objects:", removed, flush=True)

# ---------- 2. bring in the farmer (collection + his rig) ----------
before_arms = set(o.name for o in bpy.data.objects if o.type == 'ARMATURE')
with bpy.data.libraries.load(GUER) as (df, dt):
    dt.collections = ['VC1_Farmer']
coll = bpy.data.collections.get('VC1_Farmer')
bpy.context.scene.collection.children.link(coll)
# find the farmer's armature (came along as a modifier dependency)
rig2 = None
for ob in coll.objects:
    for m in ob.modifiers:
        if m.type == 'ARMATURE' and m.object:
            rig2 = m.object
if rig2 is None:
    raise RuntimeError('farmer rig not found')
rig2.name = 'MixamoRig_VC1'
if rig2.name not in [o.name for o in bpy.context.scene.objects]:
    bpy.context.scene.collection.objects.link(rig2)
# drop any duplicated actions that rode in with him
if rig2.animation_data:
    rig2.animation_data.action = None
for a in list(bpy.data.actions):
    if a.name.endswith('.001'):
        bpy.data.actions.remove(a)
print("farmer in, rig:", rig2.name, "parts:", len(coll.objects), flush=True)

# ---------- 3. separate the two units: farmer 2 m to the right ----------
grunt_rig = bpy.data.objects['MixamoRig']
dx = (grunt_rig.matrix_world.translation.x + 2.0) - rig2.matrix_world.translation.x
rig2.location.x += dx
for ob in coll.objects:
    if ob != rig2:
        ob.location.x += dx
print(f"farmer shifted dx={dx:.2f}", flush=True)

# ---------- 4. user's fixed AK-47, floating in front of the farmer ----------
with bpy.data.libraries.load(WV1) as (df, dt):
    dt.objects = ['AK47_stock']
ak = bpy.data.objects['AK47_stock']
bpy.context.scene.collection.objects.link(ak)
ak.name = 'AK47_Rifle'
fx = rig2.matrix_world.translation.x
ak.location = (fx - 0.44, -0.55, 1.0)   # centered-ish in front at chest height
print("AK47_Rifle placed", flush=True)

# ---------- 5. v2 M16A1, joined, floating in front of the grunt ----------
with bpy.data.libraries.load(WUS) as (df, dt):
    dt.objects = [n for n in dt.objects if n.startswith('M16A1_')]
m16_parts = []
for ob in bpy.data.objects:
    if ob.name.startswith('M16A1_') and ob.name != 'M16A1_Rifle':
        if ob.name not in [o.name for o in bpy.context.scene.objects]:
            bpy.context.scene.collection.objects.link(ob)
        m16_parts.append(ob)
bpy.ops.object.select_all(action='DESELECT')
for ob in m16_parts:
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.convert(target='MESH')   # bake bevels so join keeps them
bpy.ops.object.select_all(action='DESELECT')
for ob in m16_parts:
    ob.select_set(True)
bpy.context.view_layer.objects.active = m16_parts[0]
bpy.ops.object.join()
m16 = bpy.context.view_layer.objects.active
m16.name = 'M16A1_Rifle'
# armory row is y=0.5 — bring it to the grunt
gx = grunt_rig.matrix_world.translation.x
mn = min((m16.matrix_world @ Vector(c)).x for c in m16.bound_box)
mx = max((m16.matrix_world @ Vector(c)).x for c in m16.bound_box)
m16.location.x += (gx - 0.44) - mn
m16.location.y -= 0.5 + 0.55
m16.location.z += 1.0 - 0.3
print("M16A1_Rifle joined + placed, verts:", len(m16.data.vertices), flush=True)

# ---------- 6. pose both rigs in the aiming idle for placement ----------
act = bpy.data.actions.get('rifle_aiming_idle')
for rig in (grunt_rig, rig2):
    if rig.animation_data is None:
        rig.animation_data_create()
    rig.animation_data.action = act
    if len(act.slots):
        rig.animation_data.action_slot = act.slots[0]
bpy.context.scene.frame_set(15)
bpy.context.view_layer.update()
print("both rigs posed: rifle_aiming_idle f15", flush=True)

bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("STAGE SAVED:", OUT, flush=True)
