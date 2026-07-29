"""Add the charge_handle and fire clips to the AK, and re-wire all six tracks.

The AK's reload / reload_empty / jam are AUTHORED work and are NOT rebuilt here -
only the two missing clips are created, so the gun reaches the same six-clip set
as the M16: rifle_idle, reload, reload_empty, charge_handle, fire, jam.

THE ANCHOR HANDOFF. AK47_root rides hand.R, so the rifle physically follows the
right hand. The Summoner posed the charging-handle grab with the RIGHT hand, so
during that beat the gun is handed to hand.L ('ak_charge_handoff') and handed
back afterwards. A Child Of is continuous ONLY if its stored inverse equals the
target bone's world matrix at the instant it engages:
    inverse = (rig.matrix_world @ pose.bones[bone].matrix).inverted()
computed AT the handoff frame. Get that wrong and the rifle teleports - the
exact defect that produced the M16 mag-pop.

Same hard-won rules as build_m16_clips: frame FIRST then pose then key; key
scale; and bind every NLA strip's action_slot in a SECOND pass or the tracks
evaluate to nothing.

    exec(open(r'C:\\Users\\caleb\\RECONgame\\tools\\build_ak_clips.py').read())
"""
import bpy
import json
import os
from mathutils import Matrix, Vector

DIR = r'C:\Users\caleb\RECONgame\assets\player\arms\pose_library'
RIG, ROOT, GUN, BOLT, MAG = ('ArmsRig_AK47', 'AK47_root', 'AK47_gun',
                             'AK47_bolt', 'AK47_mag')
COLL = 'RIG_AK47'


def O(n):
    return bpy.data.objects[n]


def fresh(o, name):
    a = bpy.data.actions.get(name)
    if a:
        bpy.data.actions.remove(a)
    a = bpy.data.actions.new(name)
    a.use_fake_user = True
    if o.animation_data is None:
        o.animation_data_create()
    o.animation_data.action = a
    return a


def build():
    sc = bpy.context.scene
    rig, root, gun, bolt, mag = O(RIG), O(ROOT), O(GUN), O(BOLT), O(MAG)
    A = rig.matrix_world
    travel = next(c for c in bolt.constraints if c.type == 'LIMIT_LOCATION').max_x
    hold = next(c for c in root.constraints if c.name == 'hold_R')
    hand = next(c for c in root.constraints if c.name == 'ak_charge_handoff')

    for o in (rig, bolt, mag, root):
        if o.animation_data:
            for t in o.animation_data.nla_tracks:
                t.mute = (t.name != 'rifle_idle')
            o.animation_data.action = None
    sc.frame_set(0)
    bpy.context.view_layer.update()
    IDLE = {b.name: b.matrix_basis.copy() for b in rig.pose.bones}
    IBOLT = bolt.matrix_basis.copy()
    IMAG = mag.matrix_basis.copy()

    d = json.load(open(os.path.join(DIR, 'ak_charge_grab.json')))
    GRAB = {k: Matrix(v) for k, v in d['pose_basis'].items()}

    def blend(a, b, t):
        out = {}
        for pb in rig.pose.bones:
            n = pb.name
            if n in a and n in b:
                m = (a[n].to_quaternion().slerp(b[n].to_quaternion(), t)).to_matrix().to_4x4()
                m.translation = a[n].to_translation().lerp(b[n].to_translation(), t)
                out[n] = m
            elif n in a:
                out[n] = a[n]
        return out

    ROOT_LOC = root.location.copy()
    ROOT_ROT = root.rotation_quaternion.copy()
    ROOT_SCL = root.scale.copy()

    def key(f):
        # Key the root's OWN transform at every beat. Binding a fresh slotted
        # action to an object resets its unkeyed properties - that is what sent
        # AK47_root to the world origin and teleported the rifle 7.7m off the
        # hands. Keying it explicitly makes that impossible.
        root.location = ROOT_LOC
        root.rotation_quaternion = ROOT_ROT
        root.scale = ROOT_SCL
        root.keyframe_insert('location', frame=f)
        root.keyframe_insert('rotation_quaternion', frame=f)
        root.keyframe_insert('scale', frame=f)
        for pb in rig.pose.bones:
            pb.keyframe_insert('location', frame=f)
            pb.keyframe_insert('rotation_quaternion'
                               if pb.rotation_mode == 'QUATERNION' else 'rotation_euler', frame=f)
            pb.keyframe_insert('scale', frame=f)
        bolt.keyframe_insert('location', frame=f)
        mag.keyframe_insert('location', frame=f)
        hold.keyframe_insert('influence', frame=f)
        hand.keyframe_insert('influence', frame=f)

    def beat(f, basis, bolt_mm, on_left, engage=False):
        sc.frame_set(f)
        for pb in rig.pose.bones:
            if pb.name in basis:
                pb.matrix_basis = basis[pb.name].copy()
        bolt.matrix_basis = Matrix.Translation(Vector((bolt_mm / 1000.0, 0, 0)))
        mag.matrix_basis = IMAG.copy()
        bpy.context.view_layer.update()
        if engage and on_left:
            # ONLY ever recompute the HANDOFF constraint. hold_R carries the
            # rifle's rest relationship to the right hand and is shared by every
            # authored clip - recomputing it teleports the AK in all of them.
            # Handing BACK needs no recompute: hold_R's original inverse is
            # already correct, and the hand-back beat is posed at idle.
            con = hand
            con.inverse_matrix = (A @ rig.pose.bones['hand.L'].matrix).inverted()
            bpy.context.view_layer.update()
        hold.influence = 0.0 if on_left else 1.0
        hand.influence = 1.0 if on_left else 0.0
        bpy.context.view_layer.update()
        key(f)

    # ---- charge_handle -----------------------------------------------------
    fresh(rig, 'ak_charge_handle'); fresh(bolt, 'ak_bolt_charge_handle')
    fresh(mag, 'ak_mag_charge_handle'); fresh(root, 'ak_root_charge_handle')
    # Hand the rifle to the LEFT hand BEFORE the right hand starts moving, and
    # take it back only after the right hand is home. Engaging mid-reach lets the
    # rifle drift with the reaching hand (measured 59-80mm).
    beat(0, IDLE, 0, False)
    beat(4, IDLE, 0, True, engage=True)       # gun -> left hand, right hand freed
    beat(12, blend(IDLE, GRAB, 0.5), 0, True)
    beat(18, GRAB, 0, True)                   # hand on the charging handle
    beat(22, GRAB, 0, True)                   # HOLD
    beat(32, GRAB, travel * 1000, True)       # pull the bolt fully back
    beat(38, GRAB, travel * 1000, True)       # HOLD at the rear
    beat(41, GRAB, 0, True)                   # RELEASED - never ridden forward
    beat(46, GRAB, 0, True)                   # HOLD - bolt has slammed
    beat(56, blend(IDLE, GRAB, 0.5), 0, True)
    beat(62, IDLE, 0, True)                   # right hand home again
    beat(64, IDLE, 0, False, engage=True)     # gun -> right hand
    beat(72, IDLE, 0, False)

    # ---- fire --------------------------------------------------------------
    fresh(rig, 'ak_fire'); fresh(bolt, 'ak_bolt_fire')
    fresh(mag, 'ak_mag_fire'); fresh(root, 'ak_root_fire')
    beat(0, IDLE, 0, False)
    beat(2, IDLE, travel * 1000 * 0.85, False)   # carrier slams back
    beat(6, IDLE, 0, False)                      # and returns
    beat(12, IDLE, 0, False)
    sc.frame_set(0)


def wire_and_bind():
    pairs = (('rifle_idle', None), ('reload', None), ('reload_empty', None), ('jam', None),
             ('charge_handle', 'charge_handle'), ('fire', 'fire'))
    objmap = ((RIG, 'ak_%s'), (BOLT, 'ak_bolt_%s'), (MAG, 'ak_mag_%s'), (ROOT, 'ak_root_%s'))
    for track, suffix in pairs:
        if suffix is None:
            continue
        for obj_name, pat in objmap:
            o = O(obj_name)
            a = bpy.data.actions.get(pat % suffix)
            if a is None:
                continue
            if o.animation_data is None:
                o.animation_data_create()
            for t in list(o.animation_data.nla_tracks):
                if t.name == track:
                    o.animation_data.nla_tracks.remove(t)
            tr = o.animation_data.nla_tracks.new()
            tr.name = track
            tr.strips.new(pat % suffix, 0, a)
            tr.mute = True
            o.animation_data.action = None
    n = 0
    for o in bpy.data.collections[COLL].objects:
        if not o.animation_data:
            continue
        for t in o.animation_data.nla_tracks:
            for st in t.strips:
                if st.action and st.action.slots:
                    st.action_slot = st.action.slots[0]
                    st.use_animated_influence = False
                    st.influence = 1.0
                    n += 1
    print('bound %d NLA strips' % n)


if __name__ == '__main__':
    r = O(ROOT)
    r.rotation_mode = 'QUATERNION'
    before = (r.location.copy(), r.rotation_quaternion.copy(), r.scale.copy())
    build()
    wire_and_bind()
    after = (r.location.copy(), r.rotation_quaternion.copy(), r.scale.copy())
    drift = (after[0] - before[0]).length * 1000
    if drift > 0.01:
        raise SystemExit('ABORT: AK47_root moved %.3f mm during the build - the '
                         'rifle would be displaced in every clip' % drift)
    print('AK47_root transform preserved (%.4f mm drift)' % drift)
    print('AK: charge_handle + fire built, six tracks wired')
