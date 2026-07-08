"""Recompute RigVC3 / RigVC6 scale + position from BODY parts only.

Accessories (spare rockets, RPG rack, satchels, pouches) skew the bounding box,
which wrecked the height ratio (VC6 came out at 0.219). Measure the torso->foot
chain instead, then re-align the rig to the mesh the same way VC2/VC5 were fixed.

Run: blender -b sprite_stage.blend -P fix_variant_rigs.py
"""
import bpy
from mathutils import Vector

ACCESSORY = ('spare', 'rack', 'pouch', 'satchel', 'ruck', 'chicom',
             'riceroll', 'canteen', 'strap', 'bag')

PARTS = [('l_uparm','mixamorig:LeftArm'), ('l_loarm','mixamorig:LeftForeArm'),
         ('r_uparm','mixamorig:RightArm'), ('r_loarm','mixamorig:RightForeArm'),
         ('torso','mixamorig:Spine2'), ('head','mixamorig:Head'),
         ('l_thigh','mixamorig:LeftUpLeg'), ('r_thigh','mixamorig:RightUpLeg')]

def is_body(ob):
    b = ob.name.split('.')[0].lower()
    return ob.type == 'MESH' and not any(k in b for k in ACCESSORY)

def body_bbox(cn):
    mn = Vector((1e9,)*3); mx = Vector((-1e9,)*3)
    for ob in bpy.data.collections[cn].objects:
        if not is_body(ob): continue
        for c in ob.bound_box:
            w = ob.matrix_world @ Vector(c)
            mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
    return mn, mx

def part_center(cn, base):
    for ob in bpy.data.collections[cn].objects:
        if ob.name.split('.')[0] == base:
            cs = [ob.matrix_world @ v.co for v in ob.data.vertices]
            return sum(cs, Vector()) / len(cs)

def bone_mid(rig, bname):
    b = rig.data.bones[bname]
    return rig.matrix_world @ ((b.head_local + b.tail_local) / 2)

rigF = bpy.data.objects['MixamoRig_VC1']
fmn, fmx = body_bbox('VC1_Farmer')
f_h = fmx.z - fmn.z
print(f"farmer body height {f_h:.3f}m", flush=True)

for cn, rign in [('VC3_Sapper', 'RigVC3'), ('VC6_Heavy', 'RigVC6')]:
    rig = bpy.data.objects[rign]
    mn, mx = body_bbox(cn)
    h = mx.z - mn.z
    ratio = h / f_h
    rig.scale = rigF.scale * ratio
    rig.location = ((mn.x + mx.x) / 2, rigF.location.y, rigF.location.z)
    bpy.context.view_layer.update()

    offs = []
    for base, bone in PARTS:
        pc = part_center(cn, base)
        if pc: offs.append(pc - bone_mid(rig, bone))
    rig.location += sum(offs, Vector()) / len(offs)
    bpy.context.view_layer.update()

    worst = max((part_center(cn, b) - bone_mid(rig, bn)).length for b, bn in PARTS)
    print(f"{cn}: body_h={h:.3f} ratio={ratio:.3f} worst_residual={worst*100:.1f}cm", flush=True)

# re-pose for placement
act = bpy.data.actions.get('rifle_aiming_idle')
for rign in ('RigVC3', 'RigVC6'):
    rig = bpy.data.objects[rign]
    if rig.animation_data is None: rig.animation_data_create()
    rig.animation_data.action = act
    if len(act.slots): rig.animation_data.action_slot = act.slots[0]
bpy.context.scene.frame_set(15)
bpy.context.view_layer.update()

bpy.ops.wm.save_mainfile()
print("VARIANT RIGS FIXED + SAVED", flush=True)
