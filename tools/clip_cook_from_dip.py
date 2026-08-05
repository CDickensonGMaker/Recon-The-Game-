"""The cook's three clips, all built on Caleb's dip stance.

    exec(open(r"C:\\Users\\caleb\\RECONgame\\tools\\clip_cook_from_dip.py").read())

Caleb: *"the cook should be doing the dipping pose the server has and just wiggling the
wrist to show the stirring of the food. and than just like some looking around and
grabbing other things but than just returning to stirring in the background."*

So no new pose was needed - the same stance he set for the server is the base for all
three, and only small measured deltas ride on top.

MEASURED ON HIS STANCE (10 deg of wrist, cup tip displacement):
    RightHand X -> (-0.020, -0.030, +0.048)  |0.060|
    RightHand Y -> (0,0,0)                    - twist about the bone, cup does not move
    RightHand Z -> (+0.055, -0.022, +0.009)  |0.060|
X and Z are near-perpendicular and equal in magnitude, so driving them 90 deg out of
phase traces a CIRCLE with the cup - which is what stirring is. Y is useless here and
is left alone.

The pot was moved to fit the pose rather than the pose bent to reach the pot: prep
table at 0.750, pot rim 1.010, cup tip 0.939 = inside it.
"""
import bpy
import json
import math
from mathutils import Quaternion, Euler, Vector

M = "mixamorig:"
PROD = r"C:\Users\caleb\RECONgame\production"
RIG = "PSXRig_cook"


def as_quat(b):
    return Quaternion(b["quat"]) if b["mode"] == 'QUATERNION' \
        else Euler(b["euler"], b["mode"]).to_quaternion()


def new_action(name):
    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    a = bpy.data.actions.new(name)
    a.use_fake_user = True
    slot = a.slots.new('OBJECT', "Rig")
    cb = a.layers.new("base").strips.new(type='KEYFRAME').channelbag(slot, ensure=True)
    return a, cb


def key_all(rig, cb, f):
    for pb in rig.pose.bones:
        q = pb.rotation_quaternion
        p = 'pose.bones["%s"].rotation_quaternion' % pb.name
        for k, v in enumerate((q.w, q.x, q.y, q.z)):
            fc = cb.fcurves.find(p, index=k) or cb.fcurves.new(p, index=k)
            fc.keyframe_points.insert(f, v, options={'FAST'})
        lp = 'pose.bones["%s"].location' % pb.name
        for k, v in enumerate(pb.location):
            fc = cb.fcurves.find(lp, index=k) or cb.fcurves.new(lp, index=k)
            fc.keyframe_points.insert(f, v, options={'FAST'})


def build(rig, stance, name, n, delta_fn):
    act, cb = new_action(name)
    if rig.animation_data is None:
        rig.animation_data_create()
    for i in range(n):
        t = i / float(n)
        for pb in rig.pose.bones:                 # rebuild from the stance every frame
            b = stance[pb.name]
            pb.rotation_mode = 'QUATERNION'
            pb.rotation_quaternion = as_quat(b)
            pb.location = Vector(b["loc"])
            pb.scale = Vector(b["scale"])
        for bone, e in delta_fn(t).items():
            pb = rig.pose.bones[bone]
            pb.rotation_quaternion = pb.rotation_quaternion @ Euler(e, 'XYZ').to_quaternion()
        bpy.context.view_layer.update()
        key_all(rig, cb, i + 1)
    for fc in cb.fcurves:
        fc.update()
    return act


def d_stir(t):
    """Wrist traces a circle - X and Z 90 deg out of phase. 3 stirs per loop."""
    a = t * math.tau * 3.0
    return {M + "RightHand": (math.radians(9.0 * math.sin(a)), 0.0,
                              math.radians(9.0 * math.cos(a))),
            M + "Spine": (0.0, 0.0, math.radians(1.4 * math.sin(a))),
            M + "Neck": (math.radians(1.5 * math.sin(a * 0.5)), 0.0, 0.0)}


def d_look(t):
    """He straightens off the pot and looks around, then goes back to it."""
    up = math.sin(min(1.0, max(0.0, (t - 0.1) / 0.8)) * math.pi)
    turn = math.sin(t * math.tau)
    a = t * math.tau * 2.0
    return {M + "RightHand": (math.radians(5.0 * math.sin(a)), 0.0,
                              math.radians(5.0 * math.cos(a))),
            M + "Spine": (math.radians(-7.0 * up), 0.0, math.radians(4.0 * turn)),
            M + "Spine1": (math.radians(-5.0 * up), 0.0, math.radians(3.0 * turn)),
            M + "Neck": (math.radians(-9.0 * up), 0.0, math.radians(16.0 * turn)),
            M + "Head": (math.radians(-5.0 * up), 0.0, math.radians(20.0 * turn))}


def d_grab(t):
    """Reaches off to his left for something, brings it back over the pot."""
    reach = math.sin(min(1.0, max(0.0, (t - 0.05) / 0.9)) * math.pi)
    return {M + "LeftArm": (math.radians(-26.0 * reach), 0.0, math.radians(18.0 * reach)),
            M + "LeftForeArm": (math.radians(-20.0 * reach), 0.0, 0.0),
            M + "Spine": (math.radians(-4.0 * reach), 0.0, math.radians(-9.0 * reach)),
            M + "Neck": (0.0, 0.0, math.radians(-12.0 * reach)),
            M + "Head": (0.0, 0.0, math.radians(-10.0 * reach)),
            M + "RightHand": (math.radians(4.0 * math.sin(t * math.tau * 2)), 0.0,
                              math.radians(4.0 * math.cos(t * math.tau * 2)))}


def main():
    rig = bpy.data.objects[RIG]
    stance = json.load(open(PROD + r"\pose_serve_dip_caleb.json"))["bones"]
    made = []
    for name, n, fn in (("chow_cook_stir", 120, d_stir),
                        ("chow_cook_check", 100, d_look),
                        ("chow_cook_prep", 100, d_grab)):
        made.append(build(rig, stance, name, n, fn))

    # verify against the real pot
    pot = bpy.data.objects["fb_chow_pot_range"]
    ladle = bpy.data.objects["fb_chow_ladle_cook"]
    pz = pot.matrix_world.translation.z
    sc = bpy.context.scene
    print("=== cook clips, all from your dip stance ===")
    for act in made:
        rig.animation_data.action = act
        rig.animation_data.action_slot = act.slots[0]
        f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
        inside = 0
        xs, ys = [], []
        worst_elbow = -9
        for f in range(f0, f1 + 1):
            sc.frame_set(f)
            bpy.context.view_layer.update()
            tip = ladle.matrix_world @ Vector((0.0, 0.0, 0.395))
            xs.append(tip.x); ys.append(tip.y)
            if pz + 0.00 < tip.z < pz + 0.30:
                inside += 1
            rh = rig.matrix_world @ rig.pose.bones[M + "RightHand"].head
            re_ = rig.matrix_world @ rig.pose.bones[M + "RightForeArm"].head
            worst_elbow = max(worst_elbow, re_.z - rh.z)
        print("  %-18s %3d f | cup over pot %3d%% | swirl %.0f x %.0f mm | elbow %+.3f"
              % (act.name, f1, 100 * inside // (f1 - f0 + 1),
                 (max(xs) - min(xs)) * 1000, (max(ys) - min(ys)) * 1000, worst_elbow))
    sc.frame_set(1)
    bpy.context.view_layer.update()


main()
