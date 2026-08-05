"""
Reusable QC checks for RECONgame's PSXRig animation library, run inside headless
Blender (`blender -b anim_library.blend -P <script>.py`, with this module's
directory on sys.path). See production/anim_qc/gotchas.md for the ledger of
lessons this module encodes, and .claude/agents/blender-overseer.md for the
loop this supports.

Import pattern from a driver script:
    import sys
    sys.path.insert(0, r"C:\\Users\\caleb\\RECONgame\\production\\anim_qc")
    import anim_qc

Everything here is read-only / measurement. Nothing writes to the .blend.
"""
import bpy
import math
import mathutils

NAN_TOL = 1e9          # world-position magnitude past this = "exploded"
QUAT_NORM_TOL = 0.02    # acceptable drift from a unit quaternion
SCALE_TOL = 0.02        # acceptable drift from scale 1.0
LOOP_POP_LOC_TOL = 0.01   # meters
LOOP_POP_ROT_TOL = 0.02   # quaternion component tolerance
ROOT_DRIFT_TOL = 0.05     # meters of XY hip travel tolerated on an "in-place" clip
TELEPORT_LOC_TOL = 0.5    # meters, frame-to-frame jump on a location channel
TELEPORT_ROT_TOL = 0.6    # quaternion component jump frame-to-frame


def get_rig():
    return next(o for o in bpy.data.objects if o.type == 'ARMATURE')


def get_mesh():
    return next(o for o in bpy.data.objects if o.type == 'MESH')


def channelbag(act):
    """Blender 5.0 slotted-action accessor. Returns None if the action has no
    layer/strip/slot yet (shouldn't happen for anything in anim_library.blend,
    but don't crash on it)."""
    if not len(act.layers) or not len(act.layers[0].strips):
        return None
    if not act.slots:
        return None
    return act.layers[0].strips[0].channelbag(act.slots[0])


def action_fcurves(act):
    bag = channelbag(act)
    return list(bag.fcurves) if bag else []


def bone_fcurves(act, bone_name):
    """dict: 'location'|'rotation_quaternion'|'rotation_euler'|'scale' -> {index: fcurve}"""
    prefix = f'pose.bones["{bone_name}"].'
    out = {}
    for fc in action_fcurves(act):
        if fc.data_path.startswith(prefix):
            prop = fc.data_path[len(prefix):]
            out.setdefault(prop, {})[fc.array_index] = fc
    return out


def set_pose(rig, action, frame):
    """Assign action + slot, set the scene frame, evaluate. Call before any
    world-space bone read or before a render."""
    if rig.animation_data is None:
        rig.animation_data_create()
    rig.animation_data.action = action
    if action.slots:
        try:
            rig.animation_data.action_slot = action.slots[0]
        except Exception:
            pass
    bpy.context.scene.frame_set(int(frame))
    bpy.context.view_layer.update()


def reset_pose(rig):
    """Clear pose to rest so bbox/camera calibration isn't polluted by whatever
    action happened to be assigned last (bit us once during this file's own
    bootstrap -- see gotchas.md 2026-07-31)."""
    rig.animation_data_create()
    rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
        pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()


# ---------------------------------------------------------------- BROKEN checks

def check_nan_inf(act):
    """Any NaN/Inf keyframe value on any fcurve. Returns list of (bone, prop, idx, frame)."""
    issues = []
    for fc in action_fcurves(act):
        for kp in fc.keyframe_points:
            v = kp.co[1]
            if math.isnan(v) or math.isinf(v):
                issues.append((fc.data_path, fc.array_index, kp.co[0]))
    return issues


def check_quaternion_normalization(rig, act, bones):
    """Sample rotation_quaternion at each keyframe frame for the given bones;
    flag any that drift from unit length past QUAT_NORM_TOL."""
    issues = []
    frame_orig = bpy.context.scene.frame_current
    for bn in bones:
        fcs = bone_fcurves(act, bn).get('rotation_quaternion')
        if not fcs:
            continue
        frames = sorted({kp.co[0] for fc in fcs.values() for kp in fc.keyframe_points})
        for f in frames:
            bpy.context.scene.frame_set(int(f))
            pb = rig.pose.bones.get(bn)
            mag = mathutils.Vector(pb.rotation_quaternion).length
            if abs(mag - 1.0) > QUAT_NORM_TOL:
                issues.append((bn, f, mag))
    bpy.context.scene.frame_set(frame_orig)
    return issues


def check_rotation_mode_mismatch(rig, act, bones):
    """Bone's rotation_mode is QUATERNION but only euler fcurves exist (or the
    reverse) -- keys that silently don't drive the bone."""
    issues = []
    for bn in bones:
        pb = rig.pose.bones.get(bn)
        if pb is None:
            continue
        fcs = bone_fcurves(act, bn)
        has_quat = 'rotation_quaternion' in fcs
        has_euler = 'rotation_euler' in fcs
        if pb.rotation_mode == 'QUATERNION' and has_euler and not has_quat:
            issues.append((bn, 'QUATERNION mode but only euler fcurves present'))
        if pb.rotation_mode != 'QUATERNION' and has_quat and not has_euler:
            issues.append((bn, f'{pb.rotation_mode} mode but only quaternion fcurves present'))
    return issues


def check_scale_drift(act, bones):
    issues = []
    for bn in bones:
        fcs = bone_fcurves(act, bn).get('scale')
        if not fcs:
            continue
        for idx, fc in fcs.items():
            for kp in fc.keyframe_points:
                if abs(kp.co[1] - 1.0) > SCALE_TOL:
                    issues.append((bn, idx, kp.co[0], kp.co[1]))
    return issues


def check_exploded_bone(rig, act, bones, frames):
    """World head position magnitude beyond NAN_TOL at any sampled frame --
    catches genuinely exploded rigs, not just NaN values (e.g. a huge finite
    number from a bad driver)."""
    issues = []
    for f in frames:
        set_pose(rig, act, f)
        for bn in bones:
            pb = rig.pose.bones.get(bn)
            if pb is None:
                continue
            world = rig.matrix_world @ pb.head
            if world.length > NAN_TOL:
                issues.append((bn, f, tuple(world)))
    return issues


# ---------------------------------------------------------------- GOOFY checks

def check_loop_pop(rig, act, bones):
    """On a looping clip, compare frame1 vs last-frame local pose per channel."""
    f_start, f_end = act.frame_range
    issues = []
    for bn in bones:
        fcs = bone_fcurves(act, bn)
        for prop, idxs in fcs.items():
            tol = LOOP_POP_ROT_TOL if 'rotation' in prop else LOOP_POP_LOC_TOL
            for idx, fc in idxs.items():
                v0 = fc.evaluate(f_start)
                v1 = fc.evaluate(f_end)
                if abs(v0 - v1) > tol:
                    issues.append((bn, prop, idx, v0, v1))
    return issues


def check_root_drift(rig, act, root_bone, frames, tol=ROOT_DRIFT_TOL):
    """XY (or whichever two of the three are horizontal for this rig -- X/Y here,
    Z is up, see rigmap) travel of the root bone across sampled frames. Flag if
    it exceeds tol -- the engine should drive locomotion, not the clip, for an
    in-place cycle. Skip this check entirely for authored root-motion clips."""
    positions = []
    for f in frames:
        set_pose(rig, act, f)
        pb = rig.pose.bones.get(root_bone)
        world = rig.matrix_world @ pb.head
        positions.append((world.x, world.y))
    xs = [p[0] for p in positions]
    ys = [p[1] for p in positions]
    drift = math.hypot(max(xs) - min(xs), max(ys) - min(ys))
    return drift, drift > tol


def check_teleport_pop(act, bones):
    """Frame-to-frame jump on a channel bigger than TELEPORT_*_TOL between
    ADJACENT keyframes (not sampled frames) -- catches an accidental huge key."""
    issues = []
    for bn in bones:
        fcs = bone_fcurves(act, bn)
        for prop, idxs in fcs.items():
            tol = TELEPORT_ROT_TOL if 'rotation' in prop else TELEPORT_LOC_TOL
            for idx, fc in idxs.items():
                kps = sorted(fc.keyframe_points, key=lambda k: k.co[0])
                for a, b in zip(kps, kps[1:]):
                    if abs(b.co[1] - a.co[1]) > tol:
                        issues.append((bn, prop, idx, a.co[0], b.co[0], a.co[1], b.co[1]))
    return issues


def elbow_torso_clearance(rig, act, side, frame):
    """Objective assist for the elbow-into-torso check. Measures the straight-line
    distance from the forearm bone's midpoint to the nearest point on the
    spine-to-hip centerline segment, in meters. This is a coarse proxy -- it
    does NOT replace the visual pass (mesh silhouette can overlap even when the
    bone-to-centerline distance looks generous, because the PSX mesh has real
    volume around each bone). Use it to rank candidates for a visual look, not
    as a pass/fail gate on its own.
    side: 'l' or 'r'
    Returns (distance_m, forearm_mid_world, nearest_centerline_point_world)
    """
    set_pose(rig, act, frame)
    forearm = rig.pose.bones.get(f"mixamorig:{'Left' if side=='l' else 'Right'}ForeArm")
    hips = rig.pose.bones.get("mixamorig:Hips")
    spine2 = rig.pose.bones.get("mixamorig:Spine2")
    fa_mid = rig.matrix_world @ ((forearm.head + forearm.tail) / 2)
    p0 = rig.matrix_world @ hips.head
    p1 = rig.matrix_world @ spine2.tail
    seg = p1 - p0
    seg_len2 = seg.length_squared
    t = 0.0 if seg_len2 == 0 else max(0.0, min(1.0, (fa_mid - p0).dot(seg) / seg_len2))
    nearest = p0 + seg * t
    return (fa_mid - nearest).length, fa_mid, nearest


IDLE_FAMILY = [
    "idle", "idle_aiming", "idle_aiming__smg", "idle_crouching",
    "idle_crouching__smg", "idle_crouching_aiming", "idle_unarmed",
    "idle_unarmed_2", "idle_unarmed_3", "idle_unarmed_4", "idle_unarmed_5",
]

ARM_BONES = [
    "mixamorig:LeftArm", "mixamorig:LeftForeArm", "mixamorig:LeftHand",
    "mixamorig:RightArm", "mixamorig:RightForeArm", "mixamorig:RightHand",
]

LEG_BONES = [
    "mixamorig:LeftUpLeg", "mixamorig:LeftLeg", "mixamorig:LeftFoot",
    "mixamorig:RightUpLeg", "mixamorig:RightLeg", "mixamorig:RightFoot",
]

CORE_BONES = ["mixamorig:Hips", "mixamorig:Spine", "mixamorig:Spine1", "mixamorig:Spine2",
              "mixamorig:Neck", "mixamorig:Head"]


def run_objective_pass(rig, act, bones=None, sample_frames=None):
    """Bundles the checks above into one report dict for a single action."""
    bones = bones or (ARM_BONES + LEG_BONES + CORE_BONES)
    f_start, f_end = act.frame_range
    sample_frames = sample_frames or sorted({int(f_start), int((f_start + f_end) // 2), int(f_end)})
    report = {
        "action": act.name,
        "frame_range": (f_start, f_end),
        "nan_inf": check_nan_inf(act),
        "rotation_mode_mismatch": check_rotation_mode_mismatch(rig, act, bones),
        "quat_normalization": check_quaternion_normalization(rig, act, bones),
        "scale_drift": check_scale_drift(act, bones),
        "exploded_bone": check_exploded_bone(rig, act, bones, sample_frames),
        "loop_pop": check_loop_pop(rig, act, bones),
        "teleport_pop": check_teleport_pop(act, bones),
    }
    return report


def report_is_clean(report, allow_loop_pop_bones=None):
    """True if nothing BROKEN or GOOFY was found (loop_pop on non-looping /
    one-shot clips should be filtered by the caller before calling this)."""
    for key in ("nan_inf", "rotation_mode_mismatch", "quat_normalization",
                "scale_drift", "exploded_bone", "loop_pop", "teleport_pop"):
        if report.get(key):
            return False
    return True
