"""Fit RigVC3 (and re-check RigVC6) by searching scale + vertical offset to
minimise the WORST part-to-bone residual, not just the mean.

A single mean offset can't fix a proportion mismatch: the sapper's torso sits
high while his thighs sit low. Scale trades one against the other, so solve for
both together.

Run: blender -b sprite_stage.blend -P fit_rig_vc3.py
"""
import bpy
from mathutils import Vector

PARTS = [('l_uparm','mixamorig:LeftArm'), ('l_loarm','mixamorig:LeftForeArm'),
         ('r_uparm','mixamorig:RightArm'), ('r_loarm','mixamorig:RightForeArm'),
         ('torso','mixamorig:Spine2'), ('head','mixamorig:Head'),
         ('l_thigh','mixamorig:LeftUpLeg'), ('r_thigh','mixamorig:RightUpLeg'),
         ('l_shin','mixamorig:LeftLeg'), ('r_shin','mixamorig:RightLeg'),
         ('l_foot','mixamorig:LeftFoot'), ('r_foot','mixamorig:RightFoot'),
         ('neck','mixamorig:Neck'), ('waist','mixamorig:Spine'), ('hem','mixamorig:Hips')]

def part_center(cn, base):
    for ob in bpy.data.collections[cn].objects:
        if ob.name.split('.')[0] == base:
            cs = [ob.matrix_world @ v.co for v in ob.data.vertices]
            return sum(cs, Vector()) / len(cs)

def bone_mid(rig, bn):
    b = rig.data.bones[bn]
    return rig.matrix_world @ ((b.head_local + b.tail_local) / 2)

def residuals(cn, rig):
    bpy.context.view_layer.update()
    out = []
    for base, bone in PARTS:
        pc = part_center(cn, base)
        if pc: out.append((pc - bone_mid(rig, bone)).length)
    return out

for cn, rign in [('VC3_Sapper', 'RigVC3'), ('VC6_Heavy', 'RigVC6')]:
    rig = bpy.data.objects[rign]
    base_scale = rig.scale.copy()
    base_loc = rig.location.copy()
    best = None
    for si in range(-14, 15):                 # +/-7% scale, 0.5% steps
        s = 1.0 + si * 0.005
        rig.scale = base_scale * s
        for zi in range(-24, 25):             # +/-12 cm, 5 mm steps
            rig.location = Vector((base_loc.x, base_loc.y, base_loc.z + zi * 0.005))
            r = residuals(cn, rig)
            score = (max(r), sum(r) / len(r))
            if best is None or score < best[0]:
                best = (score, s, zi * 0.005)
    (worst, mean), s, dz = best
    rig.scale = base_scale * s
    rig.location = Vector((base_loc.x, base_loc.y, base_loc.z + dz))
    bpy.context.view_layer.update()
    print(f"{cn}: scale x{s:.3f} dz={dz*100:+.1f}cm -> worst={worst*100:.1f}cm mean={mean*100:.1f}cm", flush=True)

# farmer's numbers, for reference on what "good" looks like
rigF = bpy.data.objects['MixamoRig_VC1']
rF = residuals('VC1_Farmer', rigF)
print(f"VC1_Farmer (reference): worst={max(rF)*100:.1f}cm mean={sum(rF)/len(rF)*100:.1f}cm", flush=True)

act = bpy.data.actions.get('rifle_aiming_idle')
for rign in ('RigVC3', 'RigVC6'):
    rig = bpy.data.objects[rign]
    if rig.animation_data is None: rig.animation_data_create()
    rig.animation_data.action = act
    if len(act.slots): rig.animation_data.action_slot = act.slots[0]
bpy.context.scene.frame_set(15)
bpy.context.view_layer.update()
bpy.ops.wm.save_mainfile()
print("RIG FIT SAVED", flush=True)
