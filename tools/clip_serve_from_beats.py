"""Build chow_serve_ladle by interpolating Caleb's two hand-set beats.

    exec(open(r"C:\\Users\\caleb\\RECONgame\\tools\\clip_serve_from_beats.py").read())

He posed the two extremes against real geometry - a real pot and a real tray on a real
receiver - rather than against numbers I invented:

    DIP   ladle cup tip z 0.939, inside the pot (floor 0.770, rim 1.010)
          right elbow +0.118 ABOVE the hand
    PLOP  cup tip 0.247 m from the receiver's tray, 0.200 m above it
          right elbow -0.068 BELOW the hand - that sign flip IS the wrist turn

So the clip is a blend between two measured stances, not a solve. Quaternions are
SLERPed per bone (never lerped - lerping quaternions shortens the arc and makes the
elbow dive through the pose), locations and scales are lerped, and the timing is eased
with holds at both ends so the ladle settles in the pot and pauses to pour instead of
sliding at constant speed.
"""
import bpy
import json
import math
from mathutils import Quaternion, Vector, Euler

M = "mixamorig:"
PROD = r"C:\Users\caleb\RECONgame\production"
N = 100


def load(fn):
    return json.load(open("%s\\%s" % (PROD, fn)))


def as_quat(b):
    if b["mode"] == 'QUATERNION':
        return Quaternion(b["quat"])
    return Euler(b["euler"], b["mode"]).to_quaternion()


def ease(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3.0 - 2.0 * x)


def blend_at(t):
    """0 = dip, 1 = plop. Holds at both ends; the pour is the pause at the top."""
    if t < 0.12:
        return 0.0
    if t < 0.42:
        return ease((t - 0.12) / 0.30)
    if t < 0.60:
        return 1.0                      # holding over the tray, pouring
    if t < 0.88:
        return 1.0 - ease((t - 0.60) / 0.28)
    return 0.0


def main():
    dip = load("pose_serve_dip_caleb.json")
    plop = load("pose_serve_plop_caleb.json")
    rig = bpy.data.objects[dip["rig"]]

    for pb in rig.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    if rig.animation_data is None:
        rig.animation_data_create()

    name = "chow_serve_ladle"
    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    slot = act.slots.new('OBJECT', "Rig")
    cbag = act.layers.new("base").strips.new(type='KEYFRAME').channelbag(slot, ensure=True)

    for i in range(N):
        w = blend_at(i / float(N))
        for pb in rig.pose.bones:
            a, b = dip["bones"][pb.name], plop["bones"][pb.name]
            pb.rotation_quaternion = as_quat(a).slerp(as_quat(b), w)
            pb.location = Vector(a["loc"]).lerp(Vector(b["loc"]), w)
            pb.scale = Vector(a["scale"]).lerp(Vector(b["scale"]), w)
        bpy.context.view_layer.update()
        f = i + 1
        for pb in rig.pose.bones:
            q = pb.rotation_quaternion
            p = 'pose.bones["%s"].rotation_quaternion' % pb.name
            for k, v in enumerate((q.w, q.x, q.y, q.z)):
                fc = cbag.fcurves.find(p, index=k) or cbag.fcurves.new(p, index=k)
                fc.keyframe_points.insert(f, v, options={'FAST'})
            lp = 'pose.bones["%s"].location' % pb.name
            for k, v in enumerate(pb.location):
                fc = cbag.fcurves.find(lp, index=k) or cbag.fcurves.new(lp, index=k)
                fc.keyframe_points.insert(f, v, options={'FAST'})
    for fc in cbag.fcurves:
        fc.update()

    # verify against the real pot and the real tray
    rig.animation_data.action = act
    rig.animation_data.action_slot = act.slots[0]
    ladle = bpy.data.objects["fb_chow_ladle"]
    pot = bpy.data.objects["fb_chow_pot"]
    tray = bpy.data.objects.get("tray_carry_traystack")
    sc = bpy.context.scene
    lo, hi, near = 9.0, -9.0, 9.0
    for f in range(1, N + 1):
        sc.frame_set(f)
        bpy.context.view_layer.update()
        tip = ladle.matrix_world @ Vector((0.0, 0.0, 0.395))
        lo = min(lo, tip.z)
        hi = max(hi, tip.z)
        if tray:
            near = min(near, (tip - tray.matrix_world.translation).length)
    print("=== chow_serve_ladle, %d frames, from your two beats ===" % N)
    print("  ladle cup tip travels z %.3f -> %.3f  (%.0f mm)" % (lo, hi, (hi - lo) * 1000))
    print("  reaches into the pot (floor 0.770, rim 1.010): %s" % ("YES" if lo < 1.010 else "NO"))
    print("  closest approach to the receiver's tray: %.3f m" % near)
    sc.frame_set(1)
    bpy.context.view_layer.update()


main()
