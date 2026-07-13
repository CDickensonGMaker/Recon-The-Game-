"""Reusable FP semi-auto rifle hand pose. Never hand-pose the fingers again.

The exact hold (right hand on the trigger, left under the handguard, every finger
knuckle placed) is captured in semi_auto_rifle_pose.json. Restore it in one call:

    import rifle_pose
    rifle_pose.apply(arm)          # arm = the ArmsRig armature object

Then fit any rifle with fp_grip (right hand anchors, slide the gun so its grip_R
meets the hand, snap the left hand to the gun's handguard node).

Works in any project that has the PSX arms rig (same bone names).
"""
import bpy, json, os
from mathutils import Quaternion

POSE_JSON = r"C:\Users\caleb\RECONgame\assets\player\arms\semi_auto_rifle_pose.json"

def load(path=POSE_JSON):
    with open(path) as f:
        return json.load(f)

def apply(arm, path=POSE_JSON):
    """Reconstruct the exact captured hold on `arm` (every bone local transform)."""
    data = load(path)
    for name, t in data['bones'].items():
        pb = arm.pose.bones.get(name)
        if pb is None:
            continue
        pb.rotation_mode = 'QUATERNION'
        pb.location = t['location']
        pb.rotation_quaternion = Quaternion(t['rotation_quaternion'])
        if 'scale' in t:
            pb.scale = t['scale']
    bpy.context.view_layer.update()
    return data

def verify(arm, path=POSE_JSON, tol_mm=2.0):
    """Confirm the reconstructed knuckle world positions match the capture."""
    data = load(path)
    from mathutils import Vector
    worst = 0.0
    for name, wj in data['world_joints'].items():
        pb = arm.pose.bones.get(name)
        if pb is None:
            continue
        cur = arm.matrix_world @ pb.head
        d = (cur - Vector(wj['head'])).length * 1000
        worst = max(worst, d)
    return worst  # mm; ~0 means perfect reconstruction
