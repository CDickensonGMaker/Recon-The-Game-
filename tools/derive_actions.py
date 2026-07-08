"""Make new animations out of the ones we already have.

Blender 5 stores keyframes in slotted actions:
    action.layers[0].strips[0].channelbag(action.slots[0]).fcurves
so every helper here goes through fcurves_of() rather than the removed
`action.fcurves`.

Primitives
----------
reverse(src, name)              play it backwards      stand_to_cover -> cover_to_stand
splice(name, lower=, upper=)    legs from A, torso+arms from B
hold(src, frame, name, length)  freeze one frame into a static pose clip
offset_bones(act, {bone: (axis, degrees)})  rotate bones on every keyframe
time_scale(src, name, factor)   retime without touching poses
mirror(src, name)               flip left/right across the body centreline

Bone-local mirroring negates quaternion Y,Z and location X - the same operation
Blender's own "Paste Pose Flipped" performs.

Run: blender -b <file>.blend -P derive_actions.py -- [--save]
"""
import bpy, sys
from math import radians
from mathutils import Quaternion, Vector

# ---------------------------------------------------------------- bone groups
LOWER_KEYS = ('Hips', 'UpLeg', 'Leg', 'Foot', 'ToeBase', 'Toe_End')
UPPER_KEYS = ('Spine', 'Neck', 'Head', 'Shoulder', 'Arm', 'ForeArm', 'Hand',
              'Thumb', 'Index', 'Middle', 'Ring', 'Pinky')

def bone_of(data_path):
    return data_path.split('"')[1] if '"' in data_path else None

def is_lower(bone):
    # 'LeftUpLeg' matches UpLeg; 'LeftArm' must NOT match 'Leg'
    return any(k in bone for k in LOWER_KEYS)

def is_upper(bone):
    return not is_lower(bone)

# ---------------------------------------------------------------- action plumbing
def fcurves_of(act):
    if not len(act.layers) or not len(act.layers[0].strips):
        return []
    strip = act.layers[0].strips[0]
    return list(strip.channelbag(act.slots[0]).fcurves)

def new_action(name):
    if name in bpy.data.actions:
        bpy.data.actions.remove(bpy.data.actions[name])
    act = bpy.data.actions.new(name)
    # a freshly-made action has zero users and is discarded on save/reload
    act.use_fake_user = True
    slot = act.slots.new('OBJECT', 'Slot')
    layer = act.layers.new('Layer')
    strip = layer.strips.new(type='KEYFRAME')
    strip.channelbag(slot, ensure=True)
    return act

def bag(act):
    return act.layers[0].strips[0].channelbag(act.slots[0], ensure=True)

def put_curve(dst, data_path, index, keys):
    """keys: list of (frame, value)"""
    fc = bag(dst).fcurves.new(data_path, index=index)
    fc.keyframe_points.add(len(keys))
    for kp, (f, v) in zip(fc.keyframe_points, keys):
        kp.co = (f, v)
        kp.interpolation = 'BEZIER'
    fc.update()
    return fc

def keys_of(fc):
    return [(kp.co[0], kp.co[1]) for kp in fc.keyframe_points]

def frame_span(act):
    fcs = fcurves_of(act)
    fr = [kp.co[0] for fc in fcs for kp in fc.keyframe_points]
    return (min(fr), max(fr)) if fr else (1.0, 1.0)

# ---------------------------------------------------------------- primitives
def reverse(src_name, new_name):
    src = bpy.data.actions[src_name]
    f0, f1 = frame_span(src)
    dst = new_action(new_name)
    for fc in fcurves_of(src):
        ks = [(f0 + (f1 - k[0]), k[1]) for k in keys_of(fc)]
        ks.sort(key=lambda k: k[0])
        put_curve(dst, fc.data_path, fc.array_index, ks)
    print(f"reverse: {src_name} -> {new_name} ({len(fcurves_of(dst))} curves)", flush=True)
    return dst

def time_scale(src_name, new_name, factor):
    src = bpy.data.actions[src_name]
    f0, _ = frame_span(src)
    dst = new_action(new_name)
    for fc in fcurves_of(src):
        ks = [(f0 + (k[0] - f0) * factor, k[1]) for k in keys_of(fc)]
        put_curve(dst, fc.data_path, fc.array_index, ks)
    print(f"time_scale: {src_name} x{factor} -> {new_name}", flush=True)
    return dst

def splice(new_name, lower, upper):
    """Legs + root motion from `lower`, torso/arms/head from `upper`.
    Both clips are resampled onto the longer clip's frame span."""
    lower_name, upper_name = lower, upper
    lo, up = bpy.data.actions[lower_name], bpy.data.actions[upper_name]
    l0, l1 = frame_span(lo)
    u0, u1 = frame_span(up)
    n = int(max(l1 - l0, u1 - u0)) + 1
    dst = new_action(new_name)

    def resample(act, a0, a1, want_lower):
        for fc in fcurves_of(act):
            b = bone_of(fc.data_path)
            if b is None or (is_lower(b) != want_lower):
                continue
            span = max(a1 - a0, 1e-6)
            ks = []
            for i in range(n):
                t = i / max(n - 1, 1)
                ks.append((1.0 + i, fc.evaluate(a0 + t * span)))
            put_curve(dst, fc.data_path, fc.array_index, ks)

    resample(lo, l0, l1, want_lower=True)
    resample(up, u0, u1, want_lower=False)
    print(f"splice: legs={lower_name} + torso={upper_name} -> {new_name} "
          f"({len(fcurves_of(dst))} curves, {n} frames)", flush=True)
    return dst

def hold(src_name, frame, new_name, length=8):
    """Freeze one frame of a clip into a short static clip (still 2 keys so it
    has a real frame range the sprite renderer can sample)."""
    src = bpy.data.actions[src_name]
    dst = new_action(new_name)
    for fc in fcurves_of(src):
        v = fc.evaluate(frame)
        put_curve(dst, fc.data_path, fc.array_index, [(1.0, v), (float(length), v)])
    print(f"hold: {src_name}@{frame} -> {new_name} ({length} frames)", flush=True)
    return dst

AXES = {'X': Vector((1, 0, 0)), 'Y': Vector((0, 1, 0)), 'Z': Vector((0, 0, 1))}

def offset_bones(act, spec):
    """spec: {bone_name: (axis, degrees)} - post-multiply a local rotation onto
    every keyframe of that bone's quaternion. Bone-local, so 'X' bends about the
    bone's own pitch axis."""
    fcs = fcurves_of(act)
    for bone, (axis, deg) in spec.items():
        path = f'pose.bones["{bone}"].rotation_quaternion'
        curves = {fc.array_index: fc for fc in fcs if fc.data_path == path}
        if len(curves) != 4:
            print(f"  !! {bone}: {len(curves)}/4 quat curves, skipped", flush=True)
            continue
        delta = Quaternion(AXES[axis], radians(deg))
        n = len(curves[0].keyframe_points)
        for i in range(n):
            q = Quaternion([curves[j].keyframe_points[i].co[1] for j in range(4)])
            q = q @ delta
            for j in range(4):
                curves[j].keyframe_points[i].co[1] = q[j]
        for fc in curves.values():
            fc.update()
        print(f"  offset {bone}: {deg:+.0f}deg about {axis}", flush=True)
    return act

FLIP = {'Left': 'Right', 'Right': 'Left'}

def mirror(src_name, new_name):
    src = bpy.data.actions[src_name]
    dst = new_action(new_name)
    for fc in fcurves_of(src):
        b = bone_of(fc.data_path)
        if b is None:
            continue
        nb = b
        for a, c in FLIP.items():
            if a in b:
                nb = b.replace(a, c, 1); break
        path = fc.data_path.replace(f'"{b}"', f'"{nb}"')
        prop = fc.data_path.rsplit('.', 1)[-1]
        idx = fc.array_index
        # bone-local mirror: quat (w, x, -y, -z); location (-x, y, z)
        neg = (prop == 'rotation_quaternion' and idx in (2, 3)) or \
              (prop == 'location' and idx == 0)
        ks = [(f, -v if neg else v) for f, v in keys_of(fc)]
        put_curve(dst, path, idx, ks)
    print(f"mirror: {src_name} -> {new_name}", flush=True)
    return dst


# ================================================================= recipes
def build_all():
    made = []

    # -- general infantry additions ------------------------------------------
    made.append(reverse('stand_to_cover', 'cover_to_stand'))

    # crouched firing: legs stay crouched, upper body works the rifle
    crouch_hold = hold('rifle_crouch_idle_to_walk', 2.0, '_tmp_crouch', length=8)
    made.append(splice('crouch_fire', lower='_tmp_crouch', upper='firing_rifle'))

    # -- pilot / aircrew ------------------------------------------------------
    # cockpit idle: seated legs, hands brought up and forward onto the controls
    seat = hold('sitting', 10.0, '_tmp_seat', length=10)
    cockpit = splice('cockpit_idle', lower='_tmp_seat', upper='_tmp_seat')
    offset_bones(cockpit, {
        'mixamorig:RightArm':     ('X', -38),   # upper arms down + forward
        'mixamorig:LeftArm':      ('X', -38),
        'mixamorig:RightForeArm': ('X', -55),   # forearms up to the cyclic/collective
        'mixamorig:LeftForeArm':  ('X', -55),
        'mixamorig:Spine1':       ('X',   6),   # slight lean into the controls
    })
    made.append(cockpit)

    # dead in the seat: same seated base, slumped forward over the controls
    dead = splice('cockpit_dead', lower='_tmp_seat', upper='_tmp_seat')
    offset_bones(dead, {
        'mixamorig:Spine':    ('X', 26),
        'mixamorig:Spine1':   ('X', 22),
        'mixamorig:Spine2':   ('X', 16),
        'mixamorig:Neck':     ('X', 30),
        'mixamorig:Head':     ('X', 22),
        'mixamorig:RightArm': ('X', 20),
        'mixamorig:LeftArm':  ('X', 20),
    })
    made.append(dead)

    # pistol stance: rifle aim, support hand dropped away
    pistol = splice('pistol_aim_idle', lower='rifle_aiming_idle', upper='rifle_aiming_idle')
    offset_bones(pistol, {
        'mixamorig:LeftArm':     ('X',  48),
        'mixamorig:LeftForeArm': ('X',  35),
    })
    made.append(pistol)

    # signalling / waving someone in - from the pointing pose
    wave = hold('kneeling_pointing', 6.0, 'signal_wave', length=8)
    offset_bones(wave, {
        'mixamorig:RightArm':     ('X', -60),
        'mixamorig:RightForeArm': ('X', -40),
    })
    made.append(wave)

    for t in ('_tmp_crouch', '_tmp_seat'):
        if t in bpy.data.actions:
            bpy.data.actions.remove(bpy.data.actions[t])

    print("\nDERIVED ACTIONS:", flush=True)
    for a in made:
        f0, f1 = frame_span(a)
        print(f"  {a.name:20s} frames {int(f0)}-{int(f1)}  curves {len(fcurves_of(a))}", flush=True)
    return made


if __name__ == '__main__':
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    build_all()
    if '--save' in argv:
        bpy.ops.wm.save_mainfile()
        print("SAVED", flush=True)
    print("DERIVE DONE", flush=True)
