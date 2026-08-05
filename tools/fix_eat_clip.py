"""Re-solve chow_eat_seated into a SIMPLE eating loop, in place.

    exec(open(r"C:\\Users\\caleb\\RECONgame\\tools\\fix_eat_clip.py").read())

Caleb: *"people sitting at the table have their elbows going in really weird unnatural
ways when all they should be doing is holding a plate in front of them and eating it"*
and *"a very simple animation loop"*.

WHY THE ELBOWS WENT WRONG. `solve_arm` costed hand-to-target distance, shoulder roll and
drift - and NOTHING about the elbow. A two-link arm reaching a point has one whole
redundant degree of freedom, and that DOF is the elbow swinging around the
shoulder-to-hand axis. Every solution in that family scores identically on hand
distance, so the solver was free to park the elbow up by the shoulder or out to the
side. It did, and every gate still passed, because no gate ever looked at the elbow.

THE FIX: cost the elbow. A man eating has his elbows DOWN, near his ribs, forearms
angled up from the table. So penalise the elbow rising above the hand, and penalise it
swinging away from the body's midline. That is two terms and it removes the whole bad
branch of the solution family.

Targets are deliberately small and close: the plate sits just in front of his chest at
table height, and the eating hand makes a SHORT lift to the mouth. No big arcs.
"""
import bpy
import math
from mathutils import Vector, Euler, Quaternion

M = "mixamorig:"
CLIP = "chow_eat_seated"
REACH = 0.559
RIG = "PSXRig_eater0"          # any seated rig; we only borrow its skeleton


def rad(d):
    return math.radians(d)


def solve_arm_elbowaware(rig, side, target, seed=None, tries=90):
    """Two-link solve that also costs WHERE THE ELBOW ENDS UP."""
    arm = rig.pose.bones[M + side + "Arm"]
    fore = rig.pose.bones[M + side + "ForeArm"]
    hand = rig.pose.bones[M + side + "Hand"]
    for pb in (arm, fore):
        pb.rotation_mode = 'XYZ'

    LO = [rad(-175), rad(-150), rad(-150), rad(-70)]
    HI = [rad(175), rad(150), rad(150), rad(70)]
    best = list(seed) if seed is not None else [rad(60), 0.0, rad(-90), 0.0]
    best = [max(LO[i], min(HI[i], best[i])) for i in range(4)]
    ref = list(best)

    chest = rig.matrix_world @ rig.pose.bones[M + "Spine2"].head
    sgn = 1.0 if side == "Left" else -1.0

    def err(p):
        arm.rotation_euler = Euler((p[0], p[3], p[1]), 'XYZ')
        fore.rotation_euler = Euler((p[2], 0.0, 0.0), 'XYZ')
        bpy.context.view_layer.update()
        hw = rig.matrix_world @ hand.head
        ew = rig.matrix_world @ fore.head          # ForeArm head IS the elbow
        d = (hw - target).length
        # elbow must not ride up above the hand - this is the term that was missing
        d += 1.20 * max(0.0, ew.z - (hw.z + 0.10))
        # and it should stay in near the ribs, not wing out sideways
        out = sgn * (ew.x - chest.x)
        d += 0.45 * max(0.0, out - 0.26)
        d += 0.10 * abs(p[3])
        if seed is not None:
            d += 0.04 * sum(abs(p[i] - ref[i]) for i in range(4))
        return d

    e = err(best)
    step = [rad(30)] * 4
    for _ in range(tries):
        moved = False
        for i in range(4):
            for sg in (+1, -1):
                cand = list(best)
                cand[i] = max(LO[i], min(HI[i], cand[i] + sg * step[i]))
                ce = err(cand)
                if ce < e - 1e-5:
                    best, e, moved = cand, ce, True
        if not moved:
            step = [x * 0.55 for x in step]
            if max(step) < rad(0.3):
                break
    arm.rotation_euler = Euler((best[0], best[3], best[1]), 'XYZ')
    fore.rotation_euler = Euler((best[2], 0.0, 0.0), 'XYZ')
    bpy.context.view_layer.update()
    hw = rig.matrix_world @ hand.head
    ew = rig.matrix_world @ fore.head
    return best, (hw - target).length, ew.z - hw.z


def main():
    rig = bpy.data.objects[RIG]
    act = bpy.data.actions[CLIP]
    for pb in rig.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    if rig.animation_data is None:
        rig.animation_data_create()
    rig.animation_data.action = act
    if len(act.slots):
        rig.animation_data.action_slot = act.slots[0]

    slot = act.slots[0]
    cbag = act.layers[0].strips[0].channelbag(slot, ensure=True)
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    n = f1 - f0 + 1

    seeds = {}
    worst_err = 0.0
    worst_drop = -9.0
    sc = bpy.context.scene

    for i in range(n):
        f = f0 + i
        sc.frame_set(f)
        bpy.context.view_layer.update()
        for pb in rig.pose.bones:
            pb.rotation_mode = 'QUATERNION'
        bpy.context.view_layer.update()

        hp = rig.matrix_world @ rig.pose.bones[M + "Hips"].head
        nk = rig.matrix_world @ rig.pose.bones[M + "Neck"].head

        # SIMPLE loop: three bites over the clip, a short lift each time.
        t = i / float(n)
        bite = (t * 3.0) % 1.0
        lift = max(0.0, math.sin(bite * math.pi)) ** 1.4      # 0 -> 1 -> 0, smooth

        plate_l = hp + Vector((0.13, -0.30, 0.21))            # steadying the plate
        plate_r = hp + Vector((-0.06, -0.29, 0.22))           # eating hand at the plate
        mouth = nk + Vector((-0.06, -0.15, -0.02))            # short trip up

        tg = {"Left": plate_l, "Right": plate_r.lerp(mouth, lift)}
        for side in ("Left", "Right"):
            p, e, drop = solve_arm_elbowaware(rig, side, tg[side], seed=seeds.get(side))
            seeds[side] = p
            worst_err = max(worst_err, e)
            worst_drop = max(worst_drop, drop)
            a = rig.pose.bones[M + side + "Arm"]
            fb = rig.pose.bones[M + side + "ForeArm"]
            qa = Euler((p[0], p[3], p[1]), 'XYZ').to_quaternion()
            qf = Euler((p[2], 0.0, 0.0), 'XYZ').to_quaternion()
            a.rotation_mode = 'QUATERNION'
            a.rotation_quaternion = qa
            fb.rotation_mode = 'QUATERNION'
            fb.rotation_quaternion = qf
            for pb, q in ((a, qa), (fb, qf)):
                path = 'pose.bones["%s"].rotation_quaternion' % pb.name
                for idx, val in enumerate((q.w, q.x, q.y, q.z)):
                    fc = (cbag.fcurves.find(path, index=idx)
                          or cbag.fcurves.new(path, index=idx))
                    fc.keyframe_points.insert(f, val, options={'FAST'})
        bpy.context.view_layer.update()

    for fc in cbag.fcurves:
        fc.update()

    print("=== %s re-solved, %d frames ===" % (CLIP, n))
    print("  worst hand miss      : %.1f cm" % (worst_err * 100))
    print("  worst elbow ABOVE hand: %+.3f m  (want <= +0.10)" % worst_drop)


main()
