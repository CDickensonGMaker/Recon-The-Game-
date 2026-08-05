"""The tray collector: wait -> take the tray off the man -> stack it -> wait again.

    exec(open(r"C:\\Users\\caleb\\RECONgame\\tools\\clip_tray_receive.py").read())

Built from Caleb's two beats plus one solved phase:
  APPROACH  his hand-posed handoff placement (collector's hands still down)
  CONTACT   his grip markers `contact_tray_L/R`, solved onto with the elbow-aware IK
  STACK     hands solved to the top of the growing tray pile

The grip markers are parented to the TRAY, so they are the contract: wherever the tray
is, that is where the hands go. Same rule that made the gun crews work and that this
whole set was missing until now.
"""
import bpy
import json
import math
from mathutils import Vector, Euler, Quaternion

M = "mixamorig:"
PROD = r"C:\Users\caleb\RECONgame\production"
RIG = "PSXRig_trayreturn"


def as_quat(b):
    return Quaternion(b["quat"]) if b["mode"] == 'QUATERNION' \
        else Euler(b["euler"], b["mode"]).to_quaternion()


def ease(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3.0 - 2.0 * x)


def solve(rig, side, target, seed=None, tries=90):
    arm = rig.pose.bones[M + side + "Arm"]
    fore = rig.pose.bones[M + side + "ForeArm"]
    hand = rig.pose.bones[M + side + "Hand"]
    for pb in (arm, fore):
        pb.rotation_mode = 'XYZ'
    LO = [math.radians(-175), math.radians(-150), math.radians(-150), math.radians(-70)]
    HI = [math.radians(175), math.radians(150), math.radians(150), math.radians(70)]
    best = list(seed) if seed else [math.radians(55), 0.0, math.radians(-80), 0.0]
    chest = rig.matrix_world @ rig.pose.bones[M + "Spine2"].head
    sgn = 1.0 if side == "Left" else -1.0

    def err(p):
        arm.rotation_euler = Euler((p[0], p[3], p[1]), 'XYZ')
        fore.rotation_euler = Euler((p[2], 0.0, 0.0), 'XYZ')
        bpy.context.view_layer.update()
        hw = rig.matrix_world @ hand.head
        ew = rig.matrix_world @ fore.head
        d = (hw - target).length
        d += 1.10 * max(0.0, ew.z - (hw.z + 0.12))
        d += 0.40 * max(0.0, sgn * (ew.x - chest.x) - 0.28)
        d += 0.10 * abs(p[3])
        return d

    e = err(best); step = [math.radians(28)] * 4
    for _ in range(tries):
        moved = False
        for i in range(4):
            for sg in (+1, -1):
                c = list(best)
                c[i] = max(LO[i], min(HI[i], c[i] + sg * step[i]))
                ce = err(c)
                if ce < e - 1e-5:
                    best, e, moved = c, ce, True
        if not moved:
            step = [x * 0.55 for x in step]
            if max(step) < math.radians(0.3):
                break
    qa = Euler((best[0], best[3], best[1]), 'XYZ').to_quaternion()
    qf = Euler((best[2], 0.0, 0.0), 'XYZ').to_quaternion()
    arm.rotation_mode = 'QUATERNION'; arm.rotation_quaternion = qa
    fore.rotation_mode = 'QUATERNION'; fore.rotation_quaternion = qf
    bpy.context.view_layer.update()
    return best, (rig.matrix_world @ hand.head - target).length


def main():
    rig = bpy.data.objects[RIG]
    approach = json.load(open(PROD + r"\pose_tray_handoff_caleb.json"))["collector"]["bones"]
    contact = json.load(open(PROD + r"\pose_tray_receive_caleb.json"))["bones"]
    cL = bpy.data.objects["contact_tray_L"]
    cR = bpy.data.objects["contact_tray_R"]
    pile_top = max((bpy.data.objects["tray_pile_09"].matrix_world @ Vector(c)).z
                   for c in bpy.data.objects["tray_pile_09"].bound_box)
    pile = bpy.data.objects["tray_pile_09"].matrix_world.translation.copy()

    for pb in rig.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    if rig.animation_data is None:
        rig.animation_data_create()
    rig.animation_data.action = None

    name = "chow_tray_receive"
    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    slot = act.slots.new('OBJECT', "Rig")
    cb = act.layers.new("base").strips.new(type='KEYFRAME').channelbag(slot, ensure=True)

    N = 140
    seeds = {}
    worst = 0.0
    for i in range(N):
        t = i / float(N)
        # blend body between his two stances, then override the arms where needed
        if t < 0.15:
            w = 0.0
        elif t < 0.35:
            w = ease((t - 0.15) / 0.20)
        elif t < 0.80:
            w = 1.0
        else:
            w = 1.0 - ease((t - 0.80) / 0.20)
        for pb in rig.pose.bones:
            a, b = approach[pb.name], contact[pb.name]
            pb.rotation_quaternion = as_quat(a).slerp(as_quat(b), w)
            pb.location = Vector(a["loc"]).lerp(Vector(b["loc"]), w)
            pb.scale = Vector(a["scale"]).lerp(Vector(b["scale"]), w)
        bpy.context.view_layer.update()

        if 0.30 <= t < 0.55:                      # hands ON the tray
            for side, m in (("Left", cL), ("Right", cR)):
                p, miss = solve(rig, side, m.matrix_world.translation, seeds.get(side))
                seeds[side] = p; worst = max(worst, miss)
        elif 0.55 <= t < 0.80:
            # CARRY BY TURNING THE MAN, NOT BY RE-SOLVING THE ARMS.
            # Solving two arms toward a moving drop point kept missing by 14-22 cm:
            # the target travels, the arms chase it, and the grip breaks. A man
            # carrying a tray does not re-aim his hands - he holds the grip and
            # pivots. So freeze the contact arms and rotate the torso instead. The
            # tray is parented to his hands downstream, so it follows exactly.
            k = ease((t - 0.55) / 0.25)
            for side in ("Left", "Right"):
                p = seeds.get(side)
                if not p:
                    continue
                a = rig.pose.bones[M + side + "Arm"]
                fb = rig.pose.bones[M + side + "ForeArm"]
                a.rotation_mode = 'QUATERNION'
                a.rotation_quaternion = Euler((p[0], p[3], p[1]), 'XYZ').to_quaternion()
                fb.rotation_mode = 'QUATERNION'
                fb.rotation_quaternion = Euler((p[2], 0.0, 0.0), 'XYZ').to_quaternion()
            for bone, amt in ((M + "Spine", 13.0), (M + "Spine1", 9.0),
                              (M + "Spine2", 6.0)):
                pb = rig.pose.bones[bone]
                pb.rotation_quaternion = pb.rotation_quaternion @ Euler(
                    (math.radians(5.0 * k), 0.0, math.radians(amt * k)),
                    'XYZ').to_quaternion()
            for bone in (M + "Neck", M + "Head"):
                pb = rig.pose.bones[bone]
                pb.rotation_quaternion = pb.rotation_quaternion @ Euler(
                    (math.radians(6.0 * k), 0.0, math.radians(9.0 * k)),
                    'XYZ').to_quaternion()
        bpy.context.view_layer.update()

        f = i + 1
        for pb in rig.pose.bones:
            q = pb.rotation_quaternion
            path = 'pose.bones["%s"].rotation_quaternion' % pb.name
            for k2, v in enumerate((q.w, q.x, q.y, q.z)):
                fc = cb.fcurves.find(path, index=k2) or cb.fcurves.new(path, index=k2)
                fc.keyframe_points.insert(f, v, options={'FAST'})
            lp = 'pose.bones["%s"].location' % pb.name
            for k2, v in enumerate(pb.location):
                fc = cb.fcurves.find(lp, index=k2) or cb.fcurves.new(lp, index=k2)
                fc.keyframe_points.insert(f, v, options={'FAST'})
    for fc in cb.fcurves:
        fc.update()
    print("=== chow_tray_receive, %d frames ===" % N)
    print("  worst solved hand miss: %.1f cm" % (worst * 100))
    print("  phases: wait 0-15%% | reach 15-35%% | hold on tray 30-55%% | "
          "carry to pile 55-80%% | back to wait 80-100%%")
    return act


ACT = main()
