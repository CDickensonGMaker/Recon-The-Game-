"""Stage-and-fill workflow for the FP arms: Caleb poses, this captures and keys.

The Summoner's ruling 2026-07-28: *"We did have the best success with animations
by having me stage things and you filled the gaps."* This is that loop, made
repeatable instead of ad-hoc.

    import fp_pose

    fp_pose.capture('m16_jam_smack1')        # he poses, this snapshots it
    fp_pose.list_poses()                     # what is banked
    fp_pose.apply('m16_jam_smack1', key=True)  # drop it in at the current frame
    fp_pose.build('m16_jam', [('m16_jam_smack1', 8), ('m16_jam_smack2', 22)])

Format matches the existing pose_library entries (pose_basis is what actually
restores; pose_world is kept for diffing). Part transforms are captured too, so
a beat that involves the magazine or the charging handle restores those with it.
"""
import bpy
import json
import os

DIR = r'C:\Users\caleb\RECONgame\assets\player\arms\pose_library'
RIG = 'ArmsRig_M16A1'
PARTS = ('M16A1_magazine.030', 'M16A1_charge_handle_slide_back', 'M16A1_gun')

# Per weapon: the rig, the gun frame, and the moving parts a beat may involve.
# `mag` is whatever the left hand carries - a box magazine on the M16, the
# stripper charger on the Mosin, which is the same thing as far as a pose beat
# is concerned: a feed device the support hand brings to the weapon.
WEAPONS = {
    'm16': {'rig': 'ArmsRig_M16A1', 'gun': 'M16A1_gun',
            'mag': 'M16A1_magazine.030', 'handle': 'M16A1_charge_handle_slide_back',
            'parts': ('M16A1_magazine.030', 'M16A1_charge_handle_slide_back', 'M16A1_gun')},
    'mosin': {'rig': 'ArmsRig_Mosin', 'gun': 'Mosin',
              'mag': 'stripper_clip_Mosin', 'handle': 'Mosin_boltknob',
              'parts': ('stripper_clip_Mosin', 'Mosin_boltknob', 'Mosin')},
}


def _spec(rig):
    for w in WEAPONS.values():
        if w['rig'] == rig:
            return w
    return WEAPONS['m16']


def _rig(name=RIG):
    o = bpy.data.objects.get(name)
    if o is None:
        raise SystemExit('rig %s not found' % name)
    return o


def _m(mat):
    return [list(r) for r in mat]


FINGERS = ('hand.L', 'palm.01.L', 'palm.02.L', 'palm.03.L', 'palm.04.L',
           'f_index.01.L', 'f_index.02.L', 'f_index.03.L',
           'f_middle.01.L', 'f_middle.02.L', 'f_middle.03.L',
           'f_ring.01.L', 'f_ring.02.L', 'f_ring.03.L',
           'f_pinky.01.L', 'f_pinky.02.L', 'f_pinky.03.L',
           'thumb.01.L', 'thumb.02.L', 'thumb.03.L')


def capture(name, rig=RIG, note=''):
    """Snapshot the CURRENT pose and part transforms under `name`.

    Writes BOTH forms: Caleb's gun-relative matrices (handIK_*_vs_gun /
    _vs_mag / _vs_handle + finger quaternions), which survive the gun model
    being swapped and re-apply to another weapon, AND a full pose_basis for an
    exact restore on this rig. Read-only - it never moves the pose.
    """
    arm = _rig(rig)
    bpy.context.view_layer.update()
    A = arm.matrix_world
    sp = _spec(rig)
    gun = bpy.data.objects.get(sp['gun'])
    mag = bpy.data.objects.get(sp['mag'])
    han = bpy.data.objects.get(sp['handle'])

    def bw(bn):
        pb = arm.pose.bones.get(bn)
        return (A @ pb.matrix) if pb else None

    data = {
        'name': name,
        'weapon': sp['gun'],
        'note': note,
        'captured_at_frame': bpy.context.scene.frame_current,
        'rig': rig,
        'pose_basis': {b.name: _m(b.matrix_basis) for b in arm.pose.bones},
        'pose_world': {b.name: _m(A @ b.matrix) for b in arm.pose.bones},
        'parts': {},
    }
    for bn, key in (('handIK.L', 'handIK_L'), ('handIK.R', 'handIK_R'),
                    ('elbowIK.L', 'elbowIK_L'), ('elbowIK.R', 'elbowIK_R')):
        w = bw(bn)
        if w is None:
            continue
        data[key + '_world'] = _m(w)
        if gun is not None:
            data[key + '_vs_gun'] = _m(gun.matrix_world.inverted() @ w)
        if mag is not None and key == 'handIK_L':
            data[key + '_vs_mag'] = _m(mag.matrix_world.inverted() @ w)
        if han is not None and key == 'handIK_L':
            data[key + '_vs_handle'] = _m(han.matrix_world.inverted() @ w)
    data['fingers'] = {}
    for bn in FINGERS:
        pb = arm.pose.bones.get(bn)
        if pb is None:
            continue
        q = (pb.rotation_quaternion if pb.rotation_mode == 'QUATERNION'
             else pb.matrix_basis.to_quaternion())
        data['fingers'][bn] = list(q)
    if gun is not None:
        data['gun_matrix_world'] = _m(gun.matrix_world)
    if mag is not None:
        data['mag_matrix_world'] = _m(mag.matrix_world)
    if han is not None:
        data['handle_matrix_world'] = _m(han.matrix_world)
        data['handle_local_loc'] = list(han.matrix_basis.translation)

    for p in sp['parts']:
        o = bpy.data.objects.get(p)
        if o is not None:
            data['parts'][p] = {
                'matrix_basis': _m(o.matrix_basis),
                'matrix_world': _m(o.matrix_world),
            }
    os.makedirs(DIR, exist_ok=True)
    path = os.path.join(DIR, name + '.json')
    with open(path, 'w') as f:
        json.dump(data, f, indent=1)
    print('captured %d bones + %d parts at frame %d -> %s'
          % (len(data['pose_basis']), len(data['parts']), data['captured_at_frame'], path))
    return path


ANIM = ('ArmsRig_M16A1', 'M16A1_magazine.030', 'M16A1_charge_handle_slide_back')
CLIP = {'ArmsRig_M16A1': 'm16_jam_v2',
        'M16A1_magazine.030': 'm16_mag_jam_v2',
        'M16A1_charge_handle_slide_back': 'm16_ch_jam_v2'}


def review_mode(frame=None):
    """Attach the clip actions so scrubbing PLAYS. Manual posing will not hold."""
    for n in ANIM:
        o = bpy.data.objects.get(n)
        if o is None or o.animation_data is None:
            continue
        a = bpy.data.actions.get(CLIP[n])
        if a:
            o.animation_data.action = a
        for t in o.animation_data.nla_tracks:
            t.mute = True
    if frame is not None:
        bpy.context.scene.frame_set(int(frame))
    bpy.context.view_layer.update()
    print('REVIEW mode - scrub to play. Posing will NOT stick.')


def pose_mode(frame=None):
    """Freeze the current evaluated pose and detach, so hand posing HOLDS.

    Scrubbing does nothing in this mode - that is expected, not a bug.
    """
    sc = bpy.context.scene
    if frame is not None:
        review_mode(frame)
    bpy.context.view_layer.update()
    rig = bpy.data.objects[ANIM[0]]
    basis = {b.name: b.matrix_basis.copy() for b in rig.pose.bones}
    parts = {n: bpy.data.objects[n].matrix_basis.copy() for n in ANIM[1:]
             if bpy.data.objects.get(n)}
    for n in ANIM:
        o = bpy.data.objects.get(n)
        if o is None or o.animation_data is None:
            continue
        o.animation_data.action = None
        for t in o.animation_data.nla_tracks:
            t.mute = True
    for b in rig.pose.bones:
        b.matrix_basis = basis[b.name]
    for n, m in parts.items():
        bpy.data.objects[n].matrix_basis = m
    bpy.context.view_layer.update()
    print('POSE mode at frame %d - your pose holds. Scrubbing does nothing here.'
          % sc.frame_current)


def load(name):
    with open(os.path.join(DIR, name + '.json')) as f:
        return json.load(f)


def list_poses(prefix=''):
    out = sorted(n[:-5] for n in os.listdir(DIR)
                 if n.endswith('.json') and n.startswith(prefix))
    for n in out:
        try:
            d = load(n)
            print('  %-28s frame %-5s %s' % (n, d.get('captured_at_frame', '?'), d.get('note', '')))
        except Exception:
            print('  %-28s (unreadable)' % n)
    return out


def apply(name, frame=None, key=False, parts=True, rig=RIG):
    """Restore a captured pose. With key=True, keyframe it at `frame`."""
    from mathutils import Matrix
    d = load(name)
    arm = _rig(rig)
    sc = bpy.context.scene
    if frame is not None:
        sc.frame_set(int(frame))
    n = 0
    for bname, mat in d['pose_basis'].items():
        pb = arm.pose.bones.get(bname)
        if pb is None:
            continue
        pb.matrix_basis = Matrix(mat)
        n += 1
    if parts:
        for pname, pd in d.get('parts', {}).items():
            o = bpy.data.objects.get(pname)
            if o is not None:
                o.matrix_basis = Matrix(pd['matrix_basis'])
    bpy.context.view_layer.update()
    if key:
        f = sc.frame_current
        for pb in arm.pose.bones:
            if pb.name in d['pose_basis']:
                pb.keyframe_insert('location', frame=f)
                pb.keyframe_insert('rotation_quaternion' if pb.rotation_mode == 'QUATERNION'
                                   else 'rotation_euler', frame=f)
                pb.keyframe_insert('scale', frame=f)
        if parts:
            for pname in d.get('parts', {}):
                o = bpy.data.objects.get(pname)
                if o is not None:
                    o.keyframe_insert('location', frame=f)
    print('applied %s (%d bones) at frame %d%s'
          % (name, n, sc.frame_current, ', keyed' if key else ''))


def build(label, beats, rig=RIG):
    """Key a whole sequence: beats = [(pose_name, frame), ...] in order.

    Blender interpolates between them - that is the 'filling the gaps' half.
    """
    beats = sorted(beats, key=lambda b: b[1])
    for pose_name, frame in beats:
        apply(pose_name, frame=frame, key=True, rig=rig)
    print('built %s across frames %s' % (label, [b[1] for b in beats]))
