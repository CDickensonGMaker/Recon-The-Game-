"""Constrain every unit's weapon to its right hand, wherever the user placed it.

A Child-Of constraint with inverse_matrix = (rig.matrix_world @ pose.matrix)^-1
pins the gun to the bone WITHOUT moving it, so the placement is preserved exactly
and then rides along through all 21 animations.

Idempotent: re-running re-derives the inverse from the gun's current position, so
it's safe after nudging a gun in the viewport.

Run: blender -b sprite_stage.blend -P anchor_guns.py
"""
import bpy, sys
sys.path.insert(0, r'C:\Users\caleb\RECONgame\tools')
from unit_registry import UNITS

BONE = 'mixamorig:RightHand'
sc = bpy.context.scene
sc.frame_set(15)                     # the pose the user placed against
bpy.context.view_layer.update()

for unit, d in UNITS.items():
    gun = bpy.data.objects.get(d['gun'])
    rig = bpy.data.objects.get(d['rig'])
    if not gun or not rig:
        print(f"SKIP {unit}: gun={bool(gun)} rig={bool(rig)}", flush=True)
        continue

    before = gun.matrix_world.copy()

    # drop old constraints, then re-add against the CURRENT placement
    for c in list(gun.constraints):
        if c.type == 'CHILD_OF':
            gun.constraints.remove(c)
    bpy.context.view_layer.update()
    gun.matrix_world = before          # constraint removal can shift it back

    pb = rig.pose.bones[BONE]
    handmat = rig.matrix_world @ pb.matrix
    con = gun.constraints.new('CHILD_OF')
    con.target = rig
    con.subtarget = BONE
    con.inverse_matrix = handmat.inverted()
    bpy.context.view_layer.update()

    drift = (gun.matrix_world.translation - before.translation).length
    nearest = min(((gun.matrix_world @ v.co) - handmat.translation).length
                  for v in gun.data.vertices)
    flag = 'OK ' if drift < 0.002 else '!! '
    print(f"{flag}{unit:16s} {d['gun']:15s} -> {d['rig']}:{BONE}  "
          f"drift={drift*1000:.2f}mm grip_gap={nearest*100:.1f}cm", flush=True)

bpy.ops.wm.save_mainfile()
print("GUNS ANCHORED + SAVED", flush=True)
