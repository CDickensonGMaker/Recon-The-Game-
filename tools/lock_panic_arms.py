"""CIV_PANIC_RUN: lock Caleb's arm rotation onto every frame of the run.

    blender -b -P tools/lock_panic_arms.py

Caleb: "lock in the way i have the arms rotated but overall the animation works they
look helpless which is what we want the player to read when they are running."

So this is surgical, and deliberately so:

  * THE LEGS ARE NOT TOUCHED. They are running_unarmed's - Caleb's - and they are the
    hardest part of a run. Nothing here goes near them.
  * THE SPINE AND HEAD ARE NOT TOUCHED. The forward-thrown torso and the head snapping
    back over his shoulder already work.
  * ONLY THE EIGHT ARM BONES are overwritten, with HIS rotation, HELD constant. No IK,
    no flail, no per-frame solve. The solver is what made them windmill; there is
    nothing to solve, because he has already put the arms where they go.

Rigid raised arms on a running body is exactly the read he wants: a man who is not
FIGHTING, he is FLEEING. A soldier's arms pump. A terrified farmer's arms are just...
up. That stiffness IS the helplessness, and it is the thing that tells the player, at
a glance and at distance, that this one is not a threat.
"""
import bpy, math, json, os
from mathutils import Quaternion

WB = r"C:\Users\caleb\RECONgame\art_source\characters\civilians\civ_anim_workbench.blend"
ARMS_JSON = r"C:\Users\caleb\RECONgame\art_source\characters\civilians\caleb_panic_arms.json"
RIG = "PSXRig"
M = "mixamorig:"
NAME = "civ_panic_run"


def main():
    bpy.ops.wm.open_mainfile(filepath=WB)
    rig = bpy.data.objects[RIG]
    rig.data.pose_position = 'POSE'
    act = bpy.data.actions[NAME]
    cbag = act.layers[0].strips[0].channelbag(act.slots[0])

    arms = json.load(open(ARMS_JSON))["arms"]
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])

    # Overwrite the arm channels with a CONSTANT - his value, on every frame. Any key
    # already there gets its value replaced; we do not add or remove keys, so the clip
    # keeps its shape.
    touched = 0
    for bone, q in arms.items():
        path = 'pose.bones["%s"].rotation_quaternion' % bone
        for idx in range(4):
            fc = cbag.fcurves.find(path, index=idx)
            if fc is None:
                fc = cbag.fcurves.new(path, index=idx)
            for f in range(f0, f1 + 1):
                fc.keyframe_points.insert(f, q[idx], options={'FAST'})
            fc.update()
            touched += 1

    # ---- verify: the arms must be STILL, and the legs must still be RUNNING
    sc = bpy.context.scene
    if rig.animation_data is None:
        rig.animation_data_create()
    rig.animation_data.action = act
    rig.animation_data.action_slot = act.slots[0]

    arm_bones = list(arms.keys())
    leg_bones = [M + s + b for s in ("Left", "Right") for b in ("UpLeg", "Leg", "Foot")]
    a0 = l0 = None
    arm_move = leg_move = 0.0
    for f in range(f0, f1 + 1):
        sc.frame_set(f1 if f != f1 else f0)
        sc.frame_set(f)
        bpy.context.view_layer.update()
        a = [rig.pose.bones[b].rotation_quaternion.copy() for b in arm_bones]
        l = [rig.pose.bones[b].rotation_quaternion.copy() for b in leg_bones]
        if a0 is None:
            a0, l0 = a, l
        else:
            arm_move = max(arm_move, max(math.degrees(x.rotation_difference(y).angle)
                                         for x, y in zip(a0, a)))
            leg_move = max(leg_move, max(math.degrees(x.rotation_difference(y).angle)
                                         for x, y in zip(l0, l)))
    print("civ_panic_run, %d arm channels rewritten\n" % touched)
    print("MEASURED across the clip:")
    print("   arms move  %6.2f deg   <- LOCKED (should be ~0)" % arm_move)
    print("   legs move  %6.1f deg   <- STILL RUNNING (should be large)" % leg_move)
    if arm_move > 1.0:
        print("   *** the arms are still moving - the lock did not take ***")
    if leg_move < 20.0:
        print("   *** the legs stopped running - something clobbered them ***")

    rig.animation_data.action = None
    sc.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=WB)
    print("\nsaved:", os.path.basename(WB))


if __name__ == "__main__":
    main()
