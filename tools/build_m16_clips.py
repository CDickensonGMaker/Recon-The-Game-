"""Rebuild every M16A1 first-person clip from the banked pose library.

Clip set matches the M14 (the richest rig): rifle_idle, reload, reload_empty,
charge_handle, jam. The AK ships four - it has no standalone charge_handle.

DOCTRINE (researched 2026-07-28, US Army FM 3-22.9 / TM 9-1005-249-10):
  * Magazine reload - insert, push until the catch engages, TUG/TAP upward to
    confirm it is seated. Bolt stays closed on a tactical reload.
  * Empty reload - bolt is locked back; after seating the fresh magazine the
    left thumb hits the BOLT CATCH paddle on the LEFT side and the bolt runs.
  * Immediate action is SPORTS - Slap the magazine, Pull the charging handle
    fully to the rear, Observe the round eject, Release the handle (never ride
    it forward), Tap the FORWARD ASSIST, Shoot.
  * The Summoner's jam is REMEDIAL action, not immediate action: the handle is
    held to the rear THROUGH the magazine strip and reseat. That is the correct
    drill for a double feed, and it is what this builds.

HARD-WON RULES ENCODED HERE - break them and the clip silently comes out wrong:
  1. Set the FRAME FIRST, then apply the pose, then insert keys. Calling
     frame_set after posing re-evaluates the action and wipes the pose.
  2. Key SCALE as well as location/rotation, or bone bases only partly restore.
  3. Move the magazine in GUN-LOCAL coordinates. A world-space "down" vector
     had the mag extracting UP through the receiver.
  4. Bookend every clip on the idle pose, first frame and last.

    exec(open(r'C:\\Users\\caleb\\RECONgame\\tools\\build_m16_clips.py').read())
"""
import bpy
import math
import os
import sys
from mathutils import Matrix, Vector

sys.path.insert(0, r'C:\Users\caleb\RECONgame\tools')
import fp_pose

RIG = 'ArmsRig_M16A1'
MAG = 'M16A1_magazine.030'
CH = 'M16A1_charge_handle_slide_back'
GUN = 'M16A1_gun'
PORT = 'M16A1_port_cover'

# The ejection port cover hinges on its lower edge and swings OUT to the right.
# -90 deg is open and clear of the port; +90 would drive it through the receiver.
# It pops open the first time the bolt cycles and STAYS open - it is never closed
# by the action, only by hand. The M16A2 reference rig animates it the same way.
PORT_OPEN = -90.0

# The magazine now carries its size in its MESH, not its object scale, so this
# is identity. It must stay identity: the Summoner's resize was non-uniform
# (1.1977/0.6978/1.4378) and glTF cannot compose rotation with non-uniform scale
# on an ANIMATED node - the validator rejects it and the mag shears in engine.
# The scale was baked into the vertices, visual size unchanged to 0.000mm.
# Still forced explicitly, because matrix_basis carries scale and a pose banked
# before the resize once restored a 2.71x tall magazine and broke every clip.
MAG_SCALE = Vector((1.0, 1.0, 1.0))


def with_mag_scale(m):
    """Take translation + rotation from a banked basis, but keep HIS scale."""
    loc = m.to_translation()
    rot = m.to_quaternion().to_matrix().to_4x4()
    out = rot @ Matrix.Diagonal(MAG_SCALE.to_4d())
    out.translation = loc
    return out


def objs():
    return (bpy.data.objects[RIG], bpy.data.objects[MAG],
            bpy.data.objects[CH], bpy.data.objects[GUN],
            bpy.data.objects[PORT])


def pose_of(name):
    d = fp_pose.load(name)
    return ({k: Matrix(v) for k, v in d['pose_basis'].items()},
            Matrix(d['parts'][MAG]['matrix_basis']))


def blend(rig, a, b, t):
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


def fresh_action(o, name):
    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    a = bpy.data.actions.new(name)
    a.use_fake_user = True
    if o.animation_data is None:
        o.animation_data_create()
    o.animation_data.action = a
    return a


class Clip:
    """Builds one clip across the rig, the magazine and the charging handle."""

    def __init__(self, label, suffix):
        self.rig, self.mag, self.ch, self.gun, self.port = objs()
        self.travel = next(c for c in self.ch.constraints
                           if c.type == 'LIMIT_LOCATION').max_x
        fresh_action(self.rig, 'm16_%s' % suffix)
        fresh_action(self.mag, 'm16_mag_%s' % suffix)
        fresh_action(self.ch, 'm16_ch_%s' % suffix)
        fresh_action(self.port, 'm16_port_%s' % suffix)
        self.label = label
        self.seated_world = None

    def key(self, f):
        for pb in self.rig.pose.bones:
            pb.keyframe_insert('location', frame=f)
            pb.keyframe_insert('rotation_quaternion'
                               if pb.rotation_mode == 'QUATERNION' else 'rotation_euler',
                               frame=f)
            pb.keyframe_insert('scale', frame=f)          # rule 2
        self.ch.keyframe_insert('location', frame=f)
        self.mag.keyframe_insert('location', frame=f)
        self.mag.keyframe_insert('rotation_euler', frame=f)
        self.port.keyframe_insert('rotation_euler', frame=f)

    def beat(self, f, basis, magbasis, handle_mm, mag_drop_mm=0.0, hand_follows_mag=False,
             port_deg=0.0):
        sc = bpy.context.scene
        sc.frame_set(f)                                    # rule 1
        for pb in self.rig.pose.bones:
            if pb.name in basis:
                pb.matrix_basis = basis[pb.name].copy()
        self.mag.matrix_basis = with_mag_scale(magbasis)      # never his scale
        self.ch.matrix_basis = Matrix.Translation(Vector((handle_mm / 1000.0, 0, 0)))
        self.port.rotation_euler = (math.radians(port_deg), 0.0, 0.0)
        bpy.context.view_layer.update()
        if self.seated_world is None:
            self.seated_world = self.mag.matrix_world.copy()
        if mag_drop_mm:
            d = self.gun.matrix_world.to_3x3() @ Vector((0, 0, -mag_drop_mm / 1000.0))  # rule 3
            base = self.mag.matrix_world.copy()
            hand = (self.rig.matrix_world @ self.rig.pose.bones['handIK.L'].matrix).copy()
            m = base.copy(); m.translation = base.translation + d
            self.mag.matrix_world = m
            if hand_follows_mag:
                h = hand.copy(); h.translation = hand.translation + d
                self.rig.pose.bones['handIK.L'].matrix = self.rig.matrix_world.inverted() @ h
            bpy.context.view_layer.update()
        self.key(f)
        return self

    def report(self, frames):
        sc = bpy.context.scene
        print('  %s' % self.label)
        for f in frames:
            sc.frame_set(f)
            bpy.context.view_layer.update()
            G = self.gun.matrix_world.inverted()
            z = sum((G @ (self.mag.matrix_world @ v.co)).z
                    for v in self.mag.data.vertices) / len(self.mag.data.vertices) * 1000
            dg = bpy.context.evaluated_depsgraph_get(); dg.update()
            a = bpy.data.objects['ArmsMesh_M16A1'].evaluated_get(dg)
            av = [a.matrix_world @ v.co for v in a.data.vertices]
            gv = [self.gun.matrix_world @ v.co for v in self.gun.data.vertices]
            print('     f%-4d handle %5.1f  mag z %+7.1f  arm->gun %5.1f'
                  % (f, self.ch.matrix_basis.translation.x * 1000, z,
                     min(min((x - g).length for g in gv) for x in av) * 1000))


def wire(suffix, track):
    """Push each object's action onto its own NLA track, named for the contract."""
    for obj_name, act in ((RIG, 'm16_%s' % suffix), (MAG, 'm16_mag_%s' % suffix),
                          (CH, 'm16_ch_%s' % suffix), (PORT, 'm16_port_%s' % suffix)):
        o = bpy.data.objects[obj_name]
        a = bpy.data.actions.get(act)
        if a is None:
            continue
        if o.animation_data is None:
            o.animation_data_create()
        for t in list(o.animation_data.nla_tracks):
            if t.name == track:
                o.animation_data.nla_tracks.remove(t)
        tr = o.animation_data.nla_tracks.new()
        tr.name = track
        st = tr.strips.new(act, 0, a)
        # A strip created from script comes in at influence 0 and plays NOTHING.
        # Everything else can look right - range, slot, mute - and the clip is
        # still silent. Always force influence and clear the animated flag.
        st.use_animated_influence = False
        st.influence = 1.0
        st.blend_type = 'REPLACE'
        st.extrapolation = 'HOLD'
        # Blender 5.0 slotted actions: a script-created strip reports the right
        # action_slot but is NOT actually bound - it evaluates to NOTHING until
        # you assign it explicitly. This one line is the difference between a
        # silent NLA track and a working one.
        if a.slots:
            st.action_slot = a.slots[0]
        tr.mute = True
        o.animation_data.action = None


def build_all():
    sc = bpy.context.scene
    rig, mag, ch, gun, port = objs()
    for o in (rig, mag, ch, port):
        if o.animation_data is None:
            o.animation_data_create()
        o.animation_data.action = None
        for t in o.animation_data.nla_tracks:
            t.mute = True

    IDLE, IDLE_MAG = pose_of('m16_idle_caleb_v3')
    WIND, _ = pose_of('m16_jam_slap')
    HIT, _ = pose_of('m16_jam_slap_contact')
    GRAB, _ = pose_of('m16_jam_ch_grab')
    PULL, _ = pose_of('m16_jam_ch_pull')
    MGRAB, MGRAB_MAG = pose_of('m16_mag_grab_v3')
    SLAP4, SLAP4_MAG = pose_of('m16_bolt_release_v3')
    T = next(c for c in ch.constraints if c.type == 'LIMIT_LOCATION').max_x * 1000
    DROP = 127.0                      # measured: clears the receiver underside

    # ---- rifle_idle -------------------------------------------------------
    c = Clip('rifle_idle', 'fp_idle')
    c.beat(0, IDLE, IDLE_MAG, 0).beat(1, IDLE, IDLE_MAG, 0)
    c.report([0])

    # ---- charge_handle: pull and release to chamber ------------------------
    # Reference timing (M16A2 rig, 30fps): the pull itself runs 10 frames, not
    # 14. Both reference rigs also separate every burst with a dead HOLD - that
    # stillness is what makes the burst read as fast.
    c = Clip('charge_handle', 'charge_handle')
    c.beat(0, IDLE, IDLE_MAG, 0)
    c.beat(12, GRAB, IDLE_MAG, 0)
    c.beat(16, GRAB, IDLE_MAG, 0)          # HOLD - settle on the handle
    c.beat(26, PULL, IDLE_MAG, T, port_deg=PORT_OPEN)   # cover pops as it cycles
    c.beat(32, PULL, IDLE_MAG, T, port_deg=PORT_OPEN)   # HOLD at the rear
    c.beat(35, GRAB, IDLE_MAG, 0, port_deg=PORT_OPEN)   # RELEASED, never ridden
    c.beat(40, GRAB, IDLE_MAG, 0, port_deg=PORT_OPEN)   # HOLD - bolt slammed
    c.beat(60, IDLE, IDLE_MAG, 0, port_deg=PORT_OPEN)   # stays open
    c.report([0, 26, 35, 60])

    # ---- reload: tactical, bolt stays closed -------------------------------
    # burst -> HOLD -> burst, the profile both references use
    c = Clip('reload', 'reload')
    c.beat(0, IDLE, IDLE_MAG, 0)
    c.beat(14, MGRAB, MGRAB_MAG, 0)                      # hand arrives
    c.beat(18, MGRAB, MGRAB_MAG, 0)                      # HOLD - grip the mag
    c.beat(32, MGRAB, MGRAB_MAG, 0, DROP, True)          # strip, 14f burst
    c.beat(38, MGRAB, MGRAB_MAG, 0, DROP, True)          # HOLD - mag clear
    c.beat(52, MGRAB, MGRAB_MAG, 0, DROP * 0.38, True)   # fresh mag up, burst
    c.beat(62, MGRAB, MGRAB_MAG, 0)                      # seated
    c.beat(66, MGRAB, MGRAB_MAG, 0)                      # HOLD
    c.beat(72, HIT, MGRAB_MAG, 0)                        # TUG/TAP to confirm seat
    c.beat(78, HIT, MGRAB_MAG, 0)                        # HOLD on the tap
    c.beat(90, IDLE, IDLE_MAG, 0)
    c.report([0, 32, 62, 72, 90])

    # ---- reload_empty: bolt locked back, released off the catch ------------
    P = PORT_OPEN
    c = Clip('reload_empty', 'reload_empty')
    c.beat(0, IDLE, IDLE_MAG, T, port_deg=P)             # bolt locked back, cover open
    c.beat(16, MGRAB, MGRAB_MAG, T, port_deg=P)
    c.beat(34, MGRAB, MGRAB_MAG, T, DROP, True, port_deg=P)
    c.beat(52, MGRAB, MGRAB_MAG, T, DROP * 0.38, True, port_deg=P)
    c.beat(66, MGRAB, MGRAB_MAG, T, port_deg=P)
    c.beat(78, SLAP4, SLAP4_MAG, T, port_deg=P)          # thumb to the bolt catch
    c.beat(84, SLAP4, SLAP4_MAG, 0, port_deg=P)          # bolt runs forward
    c.beat(102, IDLE, IDLE_MAG, 0, port_deg=P)
    c.report([0, 34, 66, 84, 102])

    # ---- jam: REMEDIAL action ---------------------------------------------
    c = Clip('jam', 'jam')
    BOUNCE = blend(rig, HIT, WIND, 0.45)
    c.beat(0, IDLE, IDLE_MAG, 0)
    c.beat(10, WIND, IDLE_MAG, 0)
    c.beat(12, HIT, IDLE_MAG, 0)                         # SLAP 1 - 2 frames in
    c.beat(16, BOUNCE, IDLE_MAG, 0)
    c.beat(22, WIND, IDLE_MAG, 0)
    c.beat(24, HIT, IDLE_MAG, 0)                         # SLAP 2
    c.beat(28, BOUNCE, IDLE_MAG, 0)
    c.beat(48, GRAB, IDLE_MAG, 0)
    c.beat(56, GRAB, IDLE_MAG, 0)                        # contact before it moves
    c.beat(70, PULL, IDLE_MAG, T, port_deg=PORT_OPEN)    # PULL - round ejects
    c.beat(88, PULL, IDLE_MAG, T, port_deg=PORT_OPEN)
    c.beat(101, MGRAB, MGRAB_MAG, T, port_deg=PORT_OPEN) # strip the magazine
    c.beat(118, MGRAB, MGRAB_MAG, T, DROP, True, port_deg=PORT_OPEN)
    c.beat(134, MGRAB, MGRAB_MAG, T, DROP * 0.38, True, port_deg=PORT_OPEN)
    c.beat(148, MGRAB, MGRAB_MAG, T, port_deg=PORT_OPEN) # reseated
    c.beat(158, blend(rig, MGRAB, SLAP4, 0.55), SLAP4_MAG, T, port_deg=PORT_OPEN)
    c.beat(165, SLAP4, SLAP4_MAG, T, port_deg=PORT_OPEN) # TAP the forward assist
    c.beat(171, SLAP4, SLAP4_MAG, 0, port_deg=PORT_OPEN) # bolt released
    c.beat(186, IDLE, IDLE_MAG, 0, port_deg=PORT_OPEN)
    c.report([0, 12, 70, 118, 148, 171, 186])

    # ---- fire: the port cover snaps open as the bolt cycles ----------------
    # Deliberately SHORT. At 750 rpm there are 2.4 frames between shots at 30fps,
    # so a long authored cycle can never keep up - the kick stays procedural
    # (recoil_* in the .tres) and the brass is spawned in Godot at eject_M16A1.
    c = Clip('fire', 'fire')
    c.beat(0, IDLE, IDLE_MAG, 0, port_deg=0.0)
    c.beat(2, IDLE, IDLE_MAG, 0, port_deg=PORT_OPEN)     # snaps open in 2 frames
    c.beat(12, IDLE, IDLE_MAG, 0, port_deg=PORT_OPEN)    # and stays open
    c.report([0, 2, 12])

    def bind_all_strips():
        """Blender 5.0: binding action_slot at strip-creation time does NOT take.
        It has to be done in a second pass, after every strip exists. Without
        this the tracks look perfect - right action, right range, unmuted - and
        evaluate to absolutely nothing."""
        n = 0
        for o in bpy.data.collections['RIG_M16A1'].objects:
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

    for suffix, track in (('fp_idle', 'rifle_idle'), ('reload', 'reload'), ('fire', 'fire'),
                          ('reload_empty', 'reload_empty'),
                          ('charge_handle', 'charge_handle'), ('jam', 'jam')):
        wire(suffix, track)
    sc.frame_set(0)
    print('\nwired 5 NLA tracks: rifle_idle, reload, reload_empty, charge_handle, jam')


if __name__ == '__main__':
    build_all()
