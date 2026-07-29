"""Retarget a reference FPS animation pack onto our IK arms rig.

    blender -b assets/player/arms/fp_arms_rifle.blend \
        -P tools/retarget_ref_anim.py -- ak <refjson_dir> [--apply]

Without --apply this reports the basis solve and the transferred motion and
saves nothing.

WHY THIS WORKS ON FOUR BONES. Our arms rig is IK-driven: handIK.L/R and
elbowIK.L/R drive everything, and hand.L/R only COPY_ROTATION from the IK
targets. So a retarget solves four controls, not a 105-bone skeleton.

WHY WEAPON SPACE. The reference character faces a different way, is a different
size, and its weapon rides its own CB_Weapon bone while ours rides hand.R. What
transfers is each hand's pose RELATIVE TO THE WEAPON - invariant to all of that.

THE SCALE CONTRACT. Both reference armatures import with object scale 0.01.
World translations are correct metres, but every bone matrix carries that 0.01
in its basis, so a plain inverse inflates translation by 100x. norm() below
strips it. Skipping that measures the AK magazine 10.2 m from the weapon.

MOTION IS TRANSFERRED AS A DELTA off our own rest pose, not as absolute mapped
position: the model layer (bore alignment, marker seating, magazine placement)
is finished and blessed, so the retarget must preserve frame 0 exactly and
carry only the performance.

THE BASIS IS ROTATION ONLY, SOLVED FROM AXES, NEVER FROM POINTS. The two rigs
put their bone and object origins at different places - measured 2026-07-28, the
magazine-to-bolt span is 86.3 mm on the reference and 191.7 mm on ours - so no
point-to-point correspondence exists and fitting one produces a bogus
translation that inflates every transferred displacement. What DOES correspond
is direction: the bolt's travel axis and the magazine's hang axis. A rotation
solved from those preserves displacement magnitude exactly.

THE MAGAZINE IS CARRIED BY THE LEFT HAND, NOT BY BAKED GEOMETRY (Summoner's
ruling 2026-07-28: "the magazine is attached to the left hand instead of trying
to raw geometry things - the left hand carries all mag changes besides the
sniper rifle"). The magazine keeps its seated rest transform in EVERY frame of
every clip; what moves it is its own `CHILD_OF hand.L` constraint, whose
influence is keyed as a CONSTANT 0->1 step at the handoff frame. Baking the
carry as per-frame location/rotation keys is what produced the 171.9 deg,
715.7 mm magazine measured on the AK and the M16 - a part driven by matrix math
can adopt any orientation, while a part riding the hand can only rotate as far
as the hand does.

A Child Of is continuous only if its stored inverse_matrix equals the target
bone's world matrix at the instant it engages, so the inverse is re-seated at
each clip's own handoff frame. Clips whose handoff poses agree within
HANDOFF_TOL_MM share one constraint; a clip that needs a different seat gets its
own (the M16's `hand_handoff_jam` is the precedent - its handoff sat 50 mm from
the reload's).

The gun stays on hand.R for every clip. The reference performs the whole reload
with the left hand while the right never leaves the pistol grip, so no
gun-to-left-hand handoff is needed. Idle sway and recoil punch are generated
procedurally in Godot (scripts/player/weapon_holder.gd:876-889); baking them
here would double them.
"""
import bpy
import json
import math
import os
import sys
from mathutils import Matrix, Quaternion, Vector

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
if not argv:
    raise SystemExit('usage: -- <gun> <refjson_dir> [--apply]')
GUN = argv[0]
CARRY_MM = 3.0   # magazine displacement from seated that counts as held
# which clips pull the hand onto a part. 'fire' is deliberately absent from
# BOLT_CONTACT: gas cycles the bolt and no hand touches it.
# a real grab leaves the knuckles standing off the marker - calibrated true
# grabs measured 7.9-24 mm (tools/audit_viewmodel_rigs.py:35). Landing the hand
# ON the marker drives arm vertices into the gun.
GRIP_GAP = 0.024
# the charging handle sits on top of a low receiver, so the palm needs more
# clearance there than the magazine grab does
GRIP_GAP_BOLT = 0.038
# how fast the contact correction may be walked in, mm per frame
MAX_CORR_STEP_MM = 32.0
# two clips may share one hand_handoff constraint only if their handoff poses
# agree this closely; the M16's reload/reload_empty measured 4 mm apart and its
# jam 50 mm, which is why the jam carries its own constraint
HANDOFF_TOL_MM = 5.0
HANDOFF_BASE = 'hand_handoff'
# The AK reference dumps its magazine: 572 mm away and rolled 166.8 deg, which
# is a real two-magazine swap. Our rig has ONE magazine object, so replaying
# that whole arc reads as the magazine turning upside down and coming back -
# the defect the Summoner reported 2026-07-28. A rifle magazine change is a
# rock-out and a rock-in, so the roll is capped and the frames past the cap are
# dropped, splicing the out-stroke straight to the in-stroke.
MAG_ROLL_DEG = 50.0
MAG_EXCURSION_MM = 400.0
MAG_CONTACT = ('reload', 'reload_empty')
BOLT_CONTACT = ('charge_handle', 'reload_empty', 'jam')
MANIFEST = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        'viewmodel_manifest.json')
REF_MAIN = 'RIG_UE5_Comando_AK_Reload.json'
REF_FIRE = 'RIG_UE5_Comando_AK_Fire.json'
REFDIR = argv[1] if len(argv) > 1 and not argv[1].startswith('--') else 'refjson'
APPLY = '--apply' in argv


# --------------------------------------------------------------------------
# reference math
# --------------------------------------------------------------------------

def norm(m):
    """4x4 with unit-length basis columns. Translation is already metres."""
    M = Matrix(m)
    out = Matrix.Identity(4)
    for c in range(3):
        col = Vector((M[0][c], M[1][c], M[2][c]))
        col.normalize()
        for r in range(3):
            out[r][c] = col[r]
    for r in range(3):
        out[r][3] = M[r][3]
    return out


def kabsch(P, Q):
    """Rigid transform mapping points P onto Q (least squares)."""
    cp = sum(P, Vector()) / len(P)
    cq = sum(Q, Vector()) / len(Q)
    H = Matrix(((0, 0, 0), (0, 0, 0), (0, 0, 0)))
    for p, q in zip(P, Q):
        a, b = p - cp, q - cq
        for i in range(3):
            for j in range(3):
                H[i][j] += a[i] * b[j]
    U, S, Vt = _svd3(H)
    R = Vt.transposed() @ U.transposed()
    if R.determinant() < 0:
        Vt[2] = [-v for v in Vt[2]]
        R = Vt.transposed() @ U.transposed()
    M = R.to_4x4()
    M.translation = cq - R @ cp
    return M


def _svd3(H):
    A = H.transposed() @ H
    V = Matrix.Identity(3)
    for _ in range(64):
        if sum(A[i][j] ** 2 for i in range(3) for j in range(3) if i != j) < 1e-24:
            break
        for p in range(2):
            for q in range(p + 1, 3):
                if abs(A[p][q]) < 1e-18:
                    continue
                th = (A[q][q] - A[p][p]) / (2 * A[p][q])
                t = (1 if th >= 0 else -1) / (abs(th) + math.sqrt(th * th + 1))
                c = 1 / math.sqrt(t * t + 1)
                s = t * c
                J = Matrix.Identity(3)
                J[p][p] = c; J[q][q] = c; J[p][q] = s; J[q][p] = -s
                A = J.transposed() @ A @ J
                V = V @ J
    sv = [math.sqrt(max(A[i][i], 0.0)) for i in range(3)]
    order = sorted(range(3), key=lambda i: -sv[i])
    Vs = Matrix([[V[r][c] for c in order] for r in range(3)])
    S = [sv[i] for i in order]
    cols = []
    for i in range(3):
        v = Vector((Vs[0][i], Vs[1][i], Vs[2][i]))
        cols.append((H @ v).normalized() if S[i] > 1e-12 else Vector((0, 0, 0)))
    U = Matrix([[cols[c][r] for c in range(3)] for r in range(3)])
    if S[2] <= 1e-12:
        u0 = Vector((U[0][0], U[1][0], U[2][0]))
        u1 = Vector((U[0][1], U[1][1], U[2][1]))
        u2 = u0.cross(u1)
        v2 = (Vector((Vs[0][0], Vs[1][0], Vs[2][0]))
              .cross(Vector((Vs[0][1], Vs[1][1], Vs[2][1]))))
        for r in range(3):
            U[r][2] = u2[r]
            Vs[r][2] = v2[r]
    return U, S, Vs.transposed()


class Ref:
    """One reference clip, scale-normalised, in its own weapon's frame."""

    def __init__(self, path):
        d = json.load(open(path))
        self.name = os.path.basename(path)
        self.fps = d['fps']
        self.raw = d['frames']
        self._cache = {}

    def W(self, f, key):
        """Bone `key` in the reference WEAPON frame at frame f."""
        ck = (f, key)
        if ck in self._cache:
            return self._cache[ck]
        rec = self.raw[f]
        if key not in rec or 'W_Grip' not in rec:
            return None
        m = norm(rec['W_Grip']).inverted() @ norm(rec[key])
        self._cache[ck] = m
        return m

    def delta(self, f, key, f0=0):
        """Motion of `key` between f0 and f, as a transform in weapon space."""
        a, b = self.W(f0, key), self.W(f, key)
        if a is None or b is None:
            return Matrix.Identity(4)
        return b @ a.inverted()


# --------------------------------------------------------------------------
# per-gun contract
# --------------------------------------------------------------------------

GUNS = {
    # A gun needs its collection, an action-name prefix, and which contact
    # marker plays which role. Everything else - rig, gun root, gun frame, the
    # magazine and bolt objects, the rail and its axis - is derived from the
    # rig itself, because 20 hand-written object names is 20 chances to be wrong.
    'ak':   {'collection': 'RIG_AK47', 'prefix': 'ak',
             'mag': 'contact_mag_AK47', 'bolt': 'contact_bolt_AK47'},
    'm16':  {'collection': 'RIG_M16A1', 'prefix': 'm16',
             'mag': 'contact_mag_M16A1', 'bolt': 'contact_chandle_M16A1',
             'port': 'M16A1_port_cover', 'port_open_deg': -90.0},
    # the M14 op-rod carries no LIMIT_LOCATION rail, so its throw is declared
    # here (M14 bolt travel ~86 mm) and applied along the bore
    'm14':  {'collection': 'RIG_M14', 'prefix': 'm14',
             'mag': 'contact_clip_M14', 'bolt': 'contact_oprod_M14',
             'bolt_travel': 0.086},
    'ppsh': {'collection': 'RIG_PPSh41', 'prefix': 'ppsh',
             'mag': 'contact_drum_PPSh41', 'bolt': None},
    # --- drum / box fed, charging handle: the AK performance fits directly ---
    'rpd':  {'collection': 'RIG_RPD', 'prefix': 'rpd',
             'mag': 'contact_drum_RPD', 'bolt': 'contact_chandle_RPD',
             'bolt_travel': 0.100},
    'thompson': {'collection': 'RIG_Thompson_Submachine_Gun', 'prefix': 'thompson',
                 'mag': 'contact_drum_Thompson_Submachine_Gun',
                 'bolt': 'contact_chandle_Thompson_Submachine_Gun',
                 'bolt_travel': 0.070},
    'colt45': {'collection': 'RIG_Colt45_Pistol', 'prefix': 'colt45',
               'mag': 'contact_mag_Colt45_Pistol',
               'bolt': 'contact_slide_Colt45_Pistol', 'bolt_travel': 0.038},
    # --- no detachable magazine: the action IS the reload -------------------
    'm60':  {'collection': 'RIG_M60_MG', 'prefix': 'm60', 'mag': None,
             'bolt': 'contact_chandle_M60_MG', 'bolt_travel': 0.100},
    # --- bolt action: a true lift-draw-push-turn, and the charger is carried --
    # the stripper clip rides hand.L on the magazine's own CHILD_OF machinery;
    # a charger brought to the receiver IS a feed device carried by that hand
    'mosin': {'collection': 'RIG_Mosin', 'prefix': 'mosin',
              'mag': 'contact_clip_Mosin',
              'bolt': 'contact_bolt_Mosin', 'bolt_travel': 0.090,
              'pack': 'bolt_rifle'},
    'm70':  {'collection': 'RIG_M70sniper', 'prefix': 'm70', 'mag': None,
             'bolt': 'contact_bolt_M70sniper', 'bolt_travel': 0.090,
             'pack': 'bolt_rifle'},
    'ithaca': {'collection': 'RIG_Ithaca37_Shotgun', 'prefix': 'ithaca', 'mag': None,
               'bolt': 'contact_pump_Ithaca37_Shotgun'},
    'm79':  {'collection': 'RIG_M79_Launcher', 'prefix': 'm79', 'mag': None,
             'bolt': 'contact_barrel_M79_Launcher', 'bolt_travel': 0.060},
    'm72_law': {'collection': 'RIG_M72_LAW', 'prefix': 'm72law', 'mag': None,
                'bolt': 'contact_tube_M72_LAW'},
    # --- the rocket is the loaded round: it rides the hand like a magazine ---
    'rpg2': {'collection': 'RIG_RPG2', 'prefix': 'rpg2',
             'mag': 'contact_rocket_RPG2', 'bolt': None},
    'rpg7': {'collection': 'RIG_RPG7', 'prefix': 'rpg7',
             'mag': 'contact_rocket_RPG7', 'bolt': None},
}


def resolve(spec):
    """Fill in every object the build needs by reading the rig."""
    coll = bpy.data.collections[spec['collection']]
    spec['rig'] = next(o for o in coll.objects if o.type == 'ARMATURE').name

    mag_mark = bpy.data.objects.get(spec.get('mag') or '')
    bolt_mark = bpy.data.objects.get(spec.get('bolt') or '')
    spec['mag_obj'] = mag_mark.parent.name if mag_mark else None
    spec['bolt_obj'] = bolt_mark.parent.name if bolt_mark else None

    # the gun root is whatever rides hand.R; the gun FRAME is what the fixed
    # markers hang off, which on the AK is a carrier empty under the root
    root = None
    for o in bpy.data.objects:
        for c in o.constraints:
            if (c.type == 'CHILD_OF' and getattr(c, 'subtarget', '') == 'hand.R'
                    and c.target and c.target.name == spec['rig']):
                if root is None or c.influence > 0:
                    root = o
    if root is None:
        raise SystemExit('%s: no object rides hand.R' % spec['collection'])
    spec['root'] = root.name

    pref = spec['collection'].replace('RIG_', '')
    muz = next((o for o in bpy.data.objects
                if o.name.startswith('muzzle_') and pref in o.name), None)
    spec['gun'] = muz.parent.name if muz and muz.parent else root.name
    spec['muzzle'] = muz.name if muz else None
    spec['grip_r'] = next((o.name for o in bpy.data.objects
                           if o.name.startswith('grip_R_') and pref in o.name), None)

    # the rail is the bolt's own LIMIT_LOCATION; its live axis is the one with
    # a non-zero span
    spec['rail_max'], spec['rail_axis'] = 0.0, 0
    if spec['bolt_obj']:
        b = bpy.data.objects[spec['bolt_obj']]
        lim = next((c for c in b.constraints if c.type == 'LIMIT_LOCATION'), None)
        if lim:
            spans = [(lim.max_x - lim.min_x), (lim.max_y - lim.min_y),
                     (lim.max_z - lim.min_z)]
            i = max(range(3), key=lambda k: spans[k])
            spec['rail_axis'] = i
            spec['rail_max'] = spans[i]
    return spec

spec = GUNS[GUN]
REFS = {}
if spec.get('pack'):
    # The bolt correction drags the SUPPORT hand onto our bolt marker, because
    # the AK reference works the action with the hand that is already free. A
    # bolt pack transfers the throwing hand itself, so it arrives on the bolt on
    # its own; correcting it would be a second, contradictory reach.
    BOLT_CONTACT = ()


def O(n):
    o = bpy.data.objects.get(n)
    if o is None:
        raise SystemExit('missing object: %s' % n)
    return o


# --------------------------------------------------------------------------
# clip plan
# --------------------------------------------------------------------------

def build_plan(main, fire):
    """Frame recipes. Each entry is (ref, frame, bolt_override_mm or None).

    Segments are cut from the measured performance:
      f0-6 rest · f7-23 reach to mag · f21-32 mag out · f38-50 new mag in
      f51 seated · f57-68 hand up to the charging handle · f69-74 bolt cycle
      f75-88 hand home · f89+ dead air (the reference's own padding)
    """
    def seg(ref, a, b, bolt=None):
        step = 1 if b >= a else -1
        return [(ref, f, bolt) for f in range(a, b + step, step)]

    def mag_disp(ref, f):
        a, b = ref.W(0, 'W_Magazine'), ref.W(f, 'W_Magazine')
        if a is None or b is None:
            return 0.0
        return (b.translation - a.translation).length * 1000.0

    def mag_roll(ref, f):
        a, b = ref.W(0, 'W_Magazine'), ref.W(f, 'W_Magazine')
        if a is None or b is None:
            return 0.0
        q = b.to_quaternion().rotation_difference(a.to_quaternion())
        ang = abs(q.angle) % (2 * math.pi)
        return math.degrees(min(ang, 2 * math.pi - ang))

    def mag_stroke(ref):
        """The reference's magazine SEATING stroke: (apex, seated).

        `seated` is where the magazine is home again; `apex` is the frame
        furthest out that still respects the roll cap. Cutting a seam out of
        the dump phase was tried twice and both attempts collapsed - every
        cost function that scores a join prefers deleting more of the
        performance, because poses near rest always match each other best."""
        n = len(ref.raw)
        disp = [mag_disp(ref, f) for f in range(n)]
        peak = max(range(n), key=lambda f: disp[f])
        seated = next((f for f in range(peak, n) if disp[f] <= CARRY_MM), n - 1)
        ok = [f for f in range(peak, seated + 1)
              if mag_roll(ref, f) <= MAG_ROLL_DEG
              and disp[f] <= MAG_EXCURSION_MM]
        apex = max(ok, key=lambda f: disp[f]) if ok else seated
        return apex, seated

    def lead_frame(ref, seated):
        """Where the approach hands over to the swap: the frame before the
        magazine first moves whose hand pose sits closest to `seated`, so the
        two halves join as one continuous reach."""
        n = len(ref.raw)
        out = next((f for f in range(n) if mag_disp(ref, f) > CARRY_MM), 20)
        tgt = ref.W(seated, 'hand_L')
        best, pick = None, max(0, out - 1)
        for f in range(max(0, out - 8), out):
            h = ref.W(f, 'hand_L')
            if h is None or tgt is None:
                continue
            d = (h.translation - tgt.translation).length
            if best is None or d < best:
                best, pick = d, f
        return pick, (best or 0.0) * 1000.0

    if spec.get('pack'):
        # A bolt gun's performance is already split across clips, so the plan is
        # a cut list, not a reconstruction. Beats measured off the pack's own
        # fire clip: recoil f1-19, bolt lift/draw/push/turn f33-65, settle f77-91.
        idle, rel = REFS['idle'], REFS['reload']
        plan = {}
        plan['rifle_idle'] = seg(idle, 0, 0) * 12
        plan['fire'] = seg(fire, 0, 19)
        plan['charge_handle'] = seg(fire, 26, 95)
        # a jam is the same throw with the bolt refusing to travel: a short
        # snatch that stalls, worked back and forth, then a full clearing pull
        jam = seg(fire, 26, 40)
        jam += [(fire, f, 40.0 * min(1.0, (f - 40) / 3.0)) for f in range(40, 46)]
        jam += [(fire, 45, 40.0)] * 5
        jam += [(fire, 45, 40.0 + 14.0 * (k % 2)) for k in range(6)]
        jam += [(fire, 45, 12.0)] * 3
        jam += [(fire, 45, 0.0)] * 4
        jam += seg(fire, 33, 95)
        plan['jam'] = jam
        # stripper reload: the charger is brought up by the left hand exactly as
        # the reference brings a magazine, so its own performance transfers. The
        # empty variant additionally works the bolt.
        plan['reload'] = seg(rel, 0, len(rel.raw) - 1)
        plan['reload_empty'] = seg(main, 0, len(main.raw) - 1)
        return plan

    plan = {}
    plan['rifle_idle'] = seg(main, 0, 0) * 12
    # the reference never returns to the foregrip after a mag-only reload - it
    # carries straight on to the charging handle. Its own opening played
    # backwards IS that return: f51 (mag just seated) and f20 (hand at the
    # magwell about to rock the old mag out) are the same pose to 11.5 mm.
    plan['reload'] = seg(main, 0, 51) + seg(main, 20, 7)
    plan['reload_empty'] = seg(main, 0, 88)
    # approach = the hand-comes-home motion played backwards (f88->f76); it
    # rejoins f68 within 1mm, so the whole clip is real performance.
    plan['charge_handle'] = seg(main, 88, 76) + seg(main, 68, 88)
    plan['fire'] = seg(fire, 1, 8)
    # a jam is the same hand performance with the bolt refusing to travel: a
    # short snatch that stalls, a beat, then a full pull that clears it.
    # immediate action, not a single stalled pull: snatch, stall, work it, let
    # it run forward, then a full clearing pull
    jam = seg(main, 88, 76)
    jam += [(main, f, 40.0 * min(1.0, (f - 68) / 2.0)) for f in range(68, 72)]
    jam += [(main, 71, 40.0)] * 6
    jam += [(main, 71, 40.0 + 14.0 * (k % 2)) for k in range(6)]
    jam += [(main, 71, 12.0)] * 3
    jam += [(main, 71, 0.0)] * 4
    jam += seg(main, 68, 88)
    plan['jam'] = jam
    if not GUNS[GUN].get('mag'):
        plan['reload'] = plan['charge_handle']
        plan['reload_empty'] = plan['charge_handle'] + plan['charge_handle']
    else:
        apex, seated = mag_stroke(main)
        lead, join_mm = lead_frame(main, seated)
        print('  MAG SWAP  approach ends f%d, seating stroke f%d<->f%d, '
              'apex %.1f mm / %.1f deg, join %.1f mm'
              % (lead, seated, apex, mag_disp(main, apex),
                 mag_roll(main, apex), join_mm))
        # out is the seating stroke reversed, in is the same stroke forwards:
        # the two share the apex frame exactly, so the turn cannot pop
        swap = seg(main, seated, apex) + seg(main, apex, seated)
        plan['reload'] = seg(main, 0, lead) + swap + seg(main, lead, 7)
        plan['reload_empty'] = seg(main, 0, lead) + swap + seg(main, seated, 88)
    return plan


# --------------------------------------------------------------------------
# build
# --------------------------------------------------------------------------

def fcurves_of(act):
    if hasattr(act, 'fcurves') and len(act.fcurves):
        return list(act.fcurves)
    out = []
    for layer in getattr(act, 'layers', []):
        for strip in getattr(layer, 'strips', []):
            for cb in (getattr(strip, 'channelbags', None) or []):
                out.extend(cb.fcurves)
    return out


def unhide(coll_name):
    """An excluded collection evaluates every matrix as identity, which turns
    the axis solve degenerate. Returns (layer_collection, prior_state) so
    restore_visibility can put the scene back exactly as it was.

    Restoring matters far more when this runs inside a live session than
    headless: leaving three gun collections unhidden stacks three complete
    rigs in the same space, which reads as a scene full of broken models.
    """
    vl = bpy.context.view_layer

    def find(name, layer=None):
        layer = layer or vl.layer_collection
        if layer.collection.name == name:
            return layer
        for ch in layer.children:
            r = find(name, ch)
            if r:
                return r
    lc = find(coll_name)
    was = {'exclude': lc.exclude if lc else False,
           'lc_hide': lc.hide_viewport if lc else False,
           'objects': {}}
    for o in bpy.data.collections[coll_name].objects:
        was['objects'][o.name] = (o.hide_viewport, o.hide_render, o.hide_get())
    if lc:
        lc.exclude = False
        lc.hide_viewport = False
    for o in bpy.data.collections[coll_name].objects:
        o.hide_viewport = False
        o.hide_render = False
    bpy.context.view_layer.update()
    for o in bpy.data.collections[coll_name].objects:
        o.hide_set(False)
    bpy.context.view_layer.update()
    return lc, was


def restore_visibility(coll_name, lc, was):
    """Put every visibility flag unhide() touched back where it was."""
    for name, (hv, hr, hg) in was['objects'].items():
        o = bpy.data.objects.get(name)
        if o is None:
            continue
        o.hide_viewport = hv
        o.hide_render = hr
        try:
            o.hide_set(hg)
        except RuntimeError:
            pass
    if lc is not None:
        lc.hide_viewport = was['lc_hide']
        lc.exclude = was['exclude']
    bpy.context.view_layer.update()


def handoff_con(mag, rig, name):
    """The magazine's CHILD_OF hand.L, created if this gun never had one.

    PPSh, RPD, Colt45 and both RPGs reached 2026-07-28 with no handoff
    constraint at all, which is why their magazines could only ever be faked
    with baked transforms.
    """
    c = mag.constraints.get(name)
    if c is None:
        c = mag.constraints.new('CHILD_OF')
        c.name = name
        c.target = rig
        c.subtarget = 'hand.L'
    c.influence = 0.0
    return c


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


def main():
    sc = bpy.context.scene
    rig = O(spec['rig'])
    gun = O(spec['gun'])
    root = O(spec['root'])
    mag = bpy.data.objects.get(spec['mag_obj'] or '')
    bolt = bpy.data.objects.get(spec['bolt_obj'] or '')
    pre = spec['prefix']

    lc, was_excluded = unhide(spec['collection'])
    resolve(spec)

    refs = {}
    pack = spec.get('pack')
    if pack:
        # a pack extracted by tools/extract_ref_pack.py: one json per clip
        for k, clip in (('main', 'reload_empty'), ('fire', 'fire'),
                        ('reload', 'reload'), ('idle', 'idle')):
            p = os.path.join(REFDIR, '%s_%s.json' % (pack, clip))
            if not os.path.exists(p):
                raise SystemExit('reference json not found: %s\n'
                                 '  rebuild it: blender -b -P tools/extract_ref_pack.py'
                                 ' -- %s' % (p, pack))
            refs[k] = Ref(p)
    else:
        for k, fn in (('main', REF_MAIN), ('fire', REF_FIRE)):
            p = os.path.join(REFDIR, fn)
            if not os.path.exists(p):
                raise SystemExit('reference json not found: %s' % p)
            refs[k] = Ref(p)
    R, RF = refs['main'], refs['fire']
    global REFS
    REFS = refs

    # ---- rest state: our blessed idle, captured through the existing NLA ----
    for o in bpy.data.collections[spec['collection']].objects:
        if o.animation_data:
            for t in o.animation_data.nla_tracks:
                t.mute = (t.name != 'rifle_idle')
            o.animation_data.action = None
    for o in (o for o in (mag, bolt, root) if o is not None):
        if o.animation_data:
            for t in o.animation_data.nla_tracks:
                t.mute = (t.name != 'rifle_idle')
            o.animation_data.action = None
    sc.frame_set(0)
    bpy.context.view_layer.update()

    A = rig.matrix_world
    G = gun.matrix_world.copy()
    Ginv = G.inverted()
    REST_BASIS = {b.name: b.matrix_basis.copy() for b in rig.pose.bones}
    REST_GUNSPACE = {}
    for bn in ('handIK.L', 'handIK.R', 'elbowIK.L', 'elbowIK.R'):
        pb = rig.pose.bones.get(bn)
        if pb:
            REST_GUNSPACE[bn] = Ginv @ (A @ pb.matrix)
    REST_MAG = mag.matrix_basis.copy() if mag is not None else Matrix.Identity(4)
    MAG_REST_WORLD = (mag.matrix_world.copy() if mag is not None
                      else Matrix.Identity(4))
    REST_BOLT = bolt.matrix_basis.copy() if bolt is not None else Matrix.Identity(4)
    ROOT_TRS = (root.location.copy(), root.rotation_quaternion.copy(), root.scale.copy())
    ROOT_REST_WORLD = root.matrix_world.translation.copy()

    # ---- solve the rotation basis from corresponding AXES -------------------
    def triad(fwd, down):
        a = fwd.normalized()
        b = (down - a * a.dot(down)).normalized()
        return Matrix([[a.x, b.x, (a.cross(b)).x],
                       [a.y, b.y, (a.cross(b)).y],
                       [a.z, b.z, (a.cross(b)).z]])

    # frame 70 is where the AK pack's bolt sits at full travel; a pack with its
    # own framing has to be asked where that is rather than told
    if spec.get('pack'):
        f_open = max(range(len(R.raw)),
                     key=lambda f: (R.W(f, 'W_bolt').translation
                                    - R.W(0, 'W_bolt').translation).length)
    else:
        f_open = 70
    ref_fwd = (R.W(f_open, 'W_bolt').translation - R.W(0, 'W_bolt').translation)
    ref_down = R.W(0, 'W_Magazine').translation.copy()
    if spec.get('pack'):
        # A magazine POSITION is only a hang axis when the magazine hangs below
        # the weapon frame. On the bolt pack the Mag bone sits behind Body, so
        # that vector lands within 8 deg of the bolt axis and triad() collapses.
        # Both rigs hold the weapon roughly level in a Z-up world, so world down
        # carried into each weapon's own frame is a real, non-degenerate axis.
        ref_down = norm(R.raw[0]['W_Grip']).to_3x3().inverted() @ Vector((0, 0, -1))
    if bolt is not None and bolt.parent is not None and spec['rail_max'] > 0:
        r3 = (Ginv @ bolt.parent.matrix_world).to_3x3()
        i = spec['rail_axis']
        our_fwd = Vector((r3[0][i], r3[1][i], r3[2][i]))
    else:
        # no rail to read: rearward is muzzle -> pistol grip along the bore
        our_fwd = ((Ginv @ O(spec['grip_r']).matrix_world).translation
                   - (Ginv @ O(spec['muzzle']).matrix_world).translation)
    our_down = (G.to_3x3().inverted() @ Vector((0, 0, -1))) if spec.get('pack') else \
               ((Ginv @ mag.matrix_world).translation.copy() if mag is not None
                else (Ginv @ O(spec['grip_r']).matrix_world).translation
                - our_fwd.normalized() * ((Ginv @ O(spec['grip_r']).matrix_world)
                                          .translation.dot(our_fwd.normalized())))

    Pm, Qm = triad(ref_fwd, ref_down), triad(our_fwd, our_down)
    R3 = Qm @ Pm.transposed()
    Rq = R3.to_quaternion()
    print('\n  BASIS SOLVE (rotation only, from axes)')
    print('    ref rearward (%6.3f,%6.3f,%6.3f)  ->  ours (%6.3f,%6.3f,%6.3f)'
          % (*ref_fwd.normalized(), *our_fwd.normalized()))
    print('    ref down     (%6.3f,%6.3f,%6.3f)  ->  ours (%6.3f,%6.3f,%6.3f)'
          % (*(-ref_down).normalized(), *(-our_down).normalized()))
    print('    rotation %.1f deg   orthonormality err %.2e   det %.4f'
          % (math.degrees(Rq.angle),
             max(abs((R3 @ R3.transposed())[a][b] - (1.0 if a == b else 0.0))
                 for a in range(3) for b in range(3)),
             R3.determinant()))

    def xfer(ref, f, key, rest):
        """Reference motion of `key` applied to our rest pose. Displacement is
        rotated, never rescaled, so magnitude survives exactly."""
        a, b = ref.W(0, key), ref.W(f, key)
        if a is None or b is None:
            return rest.copy()
        dt = R3 @ (b.translation - a.translation)
        dq = Rq @ (b.to_quaternion() @ a.to_quaternion().inverted()) @ Rq.inverted()
        m = (dq @ rest.to_quaternion()).to_matrix().to_4x4()
        m.translation = rest.translation + dt
        return m

    # ---- bolt rail ----------------------------------------------------------
    rail_max = spec['rail_max']
    ax = spec['rail_axis']
    global MAG_MARK, BOLT_MARK
    MAG_MARK, BOLT_MARK = spec.get('mag'), spec.get('bolt')
    parts = [o for o in (mag, bolt, root) if o is not None]
    port = bpy.data.objects.get(spec.get('port') or '')
    if port is not None:
        parts.append(port)
    BPARinv = ((bolt.parent.matrix_world.to_3x3().inverted())
               if bolt is not None and bolt.parent else Matrix.Identity(3))

    plan = build_plan(R, RF)
    with open(MANIFEST) as f:
        declared = json.load(f)['guns'][GUN]['clips']
    plan = {k: v for k, v in plan.items() if k in declared}
    print('  clips declared for %s: %s' % (GUN, declared))

    # the reference bolt throw is scaled to OUR rail rather than clamped to it,
    # so a shorter rail still gets a full travel-and-return instead of sitting
    # against its stop (AK 130.0 mm, M16 81.7 mm)
    ref_throw = max((R.W(f, 'W_bolt').translation
                     - R.W(0, 'W_bolt').translation).length for f in range(len(R.raw)))

    def bolt_mm(ref, f, override):
        lim_mm = (rail_max or spec.get('bolt_travel', 0.0)) * 1000.0
        if override is not None:
            return min(override, lim_mm)
        d, d0 = ref.W(f, 'W_bolt'), ref.W(0, 'W_bolt')
        if d is None or d0 is None:
            return 0.0
        frac = (d.translation - d0.translation).length / ref_throw if ref_throw else 0.0
        return min(frac * lim_mm, lim_mm)

    def ramp(flags, lead, tail):
        """Weight curve: 1 where the flag holds, smoothstepped in over `lead`
        frames before it and out over `tail` frames after."""
        n = len(flags)
        w = [1.0 if f else 0.0 for f in flags]
        for i in range(n):
            if flags[i]:
                continue
            best = 0.0
            for j in range(n):
                if not flags[j]:
                    continue
                d = i - j
                span = tail if d > 0 else lead
                if span <= 0:
                    continue
                x = 1.0 - min(1.0, abs(d) / float(span))
                best = max(best, x * x * (3 - 2 * x))
            w[i] = best
        return w

    # hand poses already used to seat a handoff constraint, by constraint name.
    # Shared across clips so reload and reload_empty ride one constraint when
    # their handoffs agree, the way the M16's do.
    seated = {}
    report = {}
    for clip, frames in plan.items():
        acts = {
            rig: fresh(rig, '%s_%s' % (pre, clip)),
            **({mag: fresh(mag, '%s_mag_%s' % (pre, clip))} if mag else {}),
            **({bolt: fresh(bolt, '%s_bolt_%s' % (pre, clip))} if bolt else {}),
            root: fresh(root, '%s_root_%s' % (pre, clip)),
        }

        # Contact correction. The transfer carries the performance's MOTION but
        # not its TARGETS: our charging handle and magazine sit elsewhere on the
        # model than the reference's, so the copied hand lands 63-128 mm off the
        # part it is supposed to be holding. Inside a contact window the hand is
        # pulled onto OUR marker, ramped so the seam never shows.
        carry_flag, bolt_flag = [], []
        for ref, rf, bo in frames:
            a0, af = ref.W(0, 'W_Magazine'), ref.W(rf, 'W_Magazine')
            carry_flag.append(af is not None and a0 is not None
                              and (af.translation - a0.translation).length * 1000.0 > CARRY_MM)
            bolt_flag.append(bolt_mm(ref, rf, bo) > 2.0)
        w_mag = (ramp(carry_flag, 26, 10)
                 if clip in MAG_CONTACT and MAG_MARK else [0.0] * len(frames))
        w_bolt = (ramp(bolt_flag, 26, 18)
                  if clip in BOLT_CONTACT and BOLT_MARK else [0.0] * len(frames))

        stats = {'hand_max': 0.0, 'mag_max': 0.0, 'bolt_max': 0.0, 'step_max': 0.0,
                 'carried': 0, 'corr_max': 0.0, 'handoff': '-'}
        prevL = None
        clip_con = None
        grip_local = None

        def seat_handoff():
            """Pick the constraint this clip's carry rides on, seating its
            inverse to the hand pose at the handoff instant. Reuses a
            constraint already seated for an earlier clip when the two handoff
            poses agree, so guns do not accumulate one constraint per clip."""
            H = A @ rig.pose.bones['hand.L'].matrix
            for name, H0 in seated.items():
                if (H.translation - H0.translation).length * 1000.0 <= HANDOFF_TOL_MM:
                    return handoff_con(mag, rig, name)
            name = HANDOFF_BASE if HANDOFF_BASE not in seated else \
                '%s_%s' % (HANDOFF_BASE, clip)
            c = handoff_con(mag, rig, name)
            c.inverse_matrix = H.inverted()
            seated[name] = H.copy()
            return c

        applied = Vector((0, 0, 0))
        for i, (ref, rf, bo) in enumerate(frames):
            # TRAP: set the frame BEFORE posing. frame_set afterwards
            # re-evaluates the action and silently wipes the pose.
            sc.frame_set(i)

            for pb in rig.pose.bones:
                if pb.name in REST_BASIS:
                    pb.matrix_basis = REST_BASIS[pb.name].copy()

            # the AK reference never takes the right hand off the pistol grip, so
            # only the left arm carries performance. A bolt gun is the inverse:
            # the right hand leaves the grip and throws the bolt, so both arms do.
            arms = (('handIK.L', 'hand_L'), ('elbowIK.L', 'elbow_L'))
            if spec.get('pack'):
                arms = arms + (('handIK.R', 'hand_R'), ('elbowIK.R', 'elbow_R'))
            for bn, refkey in arms:
                pb = rig.pose.bones.get(bn)
                if pb is None or bn not in REST_GUNSPACE:
                    continue
                pb.matrix = A.inverted() @ (G @ xfer(ref, rf, refkey, REST_GUNSPACE[bn]))

            t = bolt_mm(ref, rf, bo)
            if bolt is not None:
                bb = REST_BOLT.copy()
                if spec['rail_max'] > 0:
                    bb.translation[ax] = t / 1000.0
                else:
                    bb.translation = REST_BOLT.translation + BPARinv @ (
                        G.to_3x3() @ our_fwd.normalized() * (t / 1000.0))
                bolt.matrix_basis = bb
            bpy.context.view_layer.update()

            if port is not None:
                frac = t / (rail_max * 1000.0) if rail_max else 0.0
                port.rotation_euler = (math.radians(spec['port_open_deg'])
                                       * min(1.0, frac * 2.5), 0.0, 0.0)

            carried = carry_flag[i]

            def tail_of(bn):
                pb = rig.pose.bones[bn]
                return A @ (pb.matrix @ Vector((0, pb.length, 0)))

            def aim(marker, tail, gap=GRIP_GAP):
                off = tail - marker
                if off.length < 1e-6:
                    return Vector((0, 0, 0))
                return (marker + off.normalized() * gap) - tail

            pre_corr = (A @ rig.pose.bones['handIK.L'].matrix).translation.copy()
            pbL = rig.pose.bones['handIK.L']

            want = Vector((0, 0, 0))
            if w_bolt[i] > 1e-4 and BOLT_MARK:
                want = aim(O(BOLT_MARK).matrix_world.translation,
                           tail_of('hand.L'), GRIP_GAP_BOLT) * w_bolt[i]
            if w_mag[i] > 1e-4 and MAG_MARK:
                if not carried:
                    want = want + aim(O(MAG_MARK).matrix_world.translation,
                                      tail_of('hand.L')) * w_mag[i]
                elif grip_local is not None:
                    want = want + (A.to_3x3() @ (pbL.matrix.to_3x3() @ grip_local))

            # A big reach - the M14 op-rod is 342 mm from the support hand - has
            # to be walked in, or the correction itself reads as a teleport.
            step = want - applied
            if step.length * 1000.0 > MAX_CORR_STEP_MM:
                step = step.normalized() * (MAX_CORR_STEP_MM / 1000.0)
            applied = applied + step
            if applied.length > 1e-6:
                m = pbL.matrix.copy()
                m.translation += A.inverted().to_3x3() @ applied
                pbL.matrix = m
                bpy.context.view_layer.update()
            if w_mag[i] > 1e-4 and MAG_MARK and not carried:
                grip_local = (pbL.matrix.to_3x3().inverted()
                              @ (A.inverted().to_3x3() @ applied))

            net = ((A @ rig.pose.bones['handIK.L'].matrix).translation - pre_corr)
            stats['corr_max'] = max(stats['corr_max'], net.length * 1000)

            # THE MAGAZINE LAW. The magazine never takes a baked transform: it
            # holds its seated rest basis in every frame and the LEFT HAND
            # carries it through CHILD_OF. A part driven by matrix math can
            # reach any orientation - that is the 171.9 deg, 715.7 mm magazine.
            # A part riding the hand can only turn as far as the hand turns.
            if mag is not None:
                mag.matrix_basis = REST_MAG.copy()
                if carried and clip_con is None:
                    clip_con = seat_handoff()
                    stats['handoff'] = '%s@f%d' % (clip_con.name, i)

            root.location, root.rotation_quaternion, root.scale = (
                ROOT_TRS[0].copy(), ROOT_TRS[1].copy(), ROOT_TRS[2].copy())

            bpy.context.view_layer.update()

            # TRAP: key scale too, or a bone basis only partly restores. And key
            # the SAME channel set in every clip - binding a slotted action
            # resets whatever it does not key.
            for pb in rig.pose.bones:
                pb.keyframe_insert('location', frame=i)
                pb.keyframe_insert('rotation_quaternion' if pb.rotation_mode == 'QUATERNION'
                                   else 'rotation_euler', frame=i)
                pb.keyframe_insert('scale', frame=i)
            for o in parts:
                o.keyframe_insert('location', frame=i)
                # key the channel that matches the object's rotation_mode:
                # matrix_basis writes euler on an XYZ object, so keying the
                # quaternion there records a stale value and the part's
                # orientation silently reverts through the NLA
                o.keyframe_insert('rotation_quaternion' if o.rotation_mode == 'QUATERNION'
                                  else 'rotation_euler', frame=i)
                o.keyframe_insert('scale', frame=i)
            for o in {o for o in (mag, root) if o is not None}:
                for c in o.constraints:
                    if c.type != 'CHILD_OF':
                        continue
                    if o is root:
                        holds = getattr(c, 'subtarget', '') == 'hand.R'
                    else:
                        # TRAP: two bpy wrappers for one constraint are not the
                        # same Python object, so `is` silently never matches and
                        # the handoff is keyed off for the whole clip
                        holds = carried and clip_con is not None \
                            and c.name == clip_con.name
                    c.influence = 1.0 if holds else 0.0
                    c.keyframe_insert('influence', frame=i)

            # the influence just changed; the magazine's world matrix is only
            # correct once the constraint has been re-evaluated
            bpy.context.view_layer.update()

            hp = (A @ rig.pose.bones['handIK.L'].matrix).translation
            gl = (Ginv @ hp)
            stats['hand_max'] = max(stats['hand_max'],
                                    (gl - REST_GUNSPACE['handIK.L'].translation).length * 1000)
            if mag is not None:
                # measured in the GUN's frame: the basis is constant now, so a
                # basis-space reading would report 0 for every carry
                stats['mag_max'] = max(
                    stats['mag_max'],
                    ((Ginv @ mag.matrix_world).translation
                     - (Ginv @ MAG_REST_WORLD).translation).length * 1000)
            stats['bolt_max'] = max(stats['bolt_max'], t)
            stats['carried'] += 1 if carried else 0
            if prevL is not None:
                stats['step_max'] = max(stats['step_max'], (hp - prevL).length * 1000)
            prevL = hp.copy()

        for a in acts.values():
            for fc in fcurves_of(a):
                # a handoff is a switch, not a blend: easing the influence curve
                # would drag the magazine through a half-attached in-between
                if fc.data_path.endswith('.influence'):
                    for kp in fc.keyframe_points:
                        kp.interpolation = 'CONSTANT'
                    continue
                for kp in fc.keyframe_points:
                    kp.interpolation = 'BEZIER'
                    kp.handle_left_type = 'AUTO'
                    kp.handle_right_type = 'AUTO'
        stats['frames'] = len(frames)
        stats['seconds'] = len(frames) / R.fps
        report[clip] = stats

    sc.frame_set(0)
    bpy.context.view_layer.update()
    drift = (root.matrix_world.translation - ROOT_REST_WORLD).length * 1000
    return rig, mag, bolt, root, report, (lc, was_excluded), drift


def wire(rig, mag, bolt, root):
    """Rebuild the six NLA tracks, then bind slots in a SECOND pass.

    TRAP: strips created by script are born at influence 0 AND their action_slot
    must be assigned after all strips exist, or every track looks correct and
    evaluates to nothing.
    """
    pre = spec['prefix']
    objmap = [(rig, '%s_%%s' % pre), (root, '%s_root_%%s' % pre)]
    if mag is not None:
        objmap.append((mag, '%s_mag_%%s' % pre))
    if bolt is not None:
        objmap.append((bolt, '%s_bolt_%%s' % pre))
    with open(MANIFEST) as f:
        clips = json.load(f)['guns'][GUN]['clips']
    for clip in clips:
        for o, pat in objmap:
            a = bpy.data.actions.get(pat % clip)
            if a is None:
                continue
            if o.animation_data is None:
                o.animation_data_create()
            for t in list(o.animation_data.nla_tracks):
                if t.name == clip:
                    o.animation_data.nla_tracks.remove(t)
            tr = o.animation_data.nla_tracks.new()
            tr.name = clip
            tr.strips.new(pat % clip, 0, a)
            tr.mute = True
            o.animation_data.action = None

    keep = set(clips) | {'ZZ_REVIEW_ROW'}
    for o, _ in objmap:
        if o.animation_data:
            for t in list(o.animation_data.nla_tracks):
                if t.name not in keep:
                    o.animation_data.nla_tracks.remove(t)

    # the review row is a scaffold the exporter deletes; after a rebuild its
    # strips no longer match the clips they mirror
    for o, _ in objmap:
        if o.animation_data:
            for t in list(o.animation_data.nla_tracks):
                if t.name == 'ZZ_REVIEW_ROW':
                    o.animation_data.nla_tracks.remove(t)

    n = 0
    for o, _ in objmap:
        for t in o.animation_data.nla_tracks:
            for st in t.strips:
                if st.action and st.action.slots:
                    st.action_slot = st.action.slots[0]
                    st.use_animated_influence = False
                    st.influence = 1.0
                    n += 1
    return n


if __name__ == '__main__':
    # the FIRST unhide sees the scene as the user left it; every later call
    # sees it already unhidden, so only this one can restore it
    lc0, was0 = unhide(spec['collection'])
    resolve(spec)
    rig, mag, bolt, root, report, (lc, _inner), drift = main()
    n = wire(rig, mag, bolt, root)

    print('\n  CLIPS BUILT')
    print('    %-15s %6s %7s %9s %9s %9s %9s %8s  %s'
          % ('clip', 'frames', 'sec', 'handL_mm', 'mag_mm', 'bolt_mm', 'step_mm',
             'corr_mm', 'handoff'))
    for c, s in report.items():
        print('    %-15s %6d %7.2f %9.1f %9.1f %9.1f %9.1f %8.1f  %s'
              % (c, s['frames'], s['seconds'], s['hand_max'], s['mag_max'],
                 s['bolt_max'], s['step_max'], s['corr_max'], s['handoff']))
    print('  bound %d NLA strips' % n)

    print('  gun root drift at rest: %.4f mm' % drift)
    if drift > 0.5:
        raise SystemExit('ABORT: gun root moved %.3f mm - the rifle would be '
                         'displaced in every clip' % drift)

    restore_visibility(spec['collection'], lc0, was0)

    if APPLY:
        bpy.ops.wm.save_mainfile()
        print('  SAVED %s' % bpy.data.filepath)
    else:
        print('  dry run - nothing saved (pass --apply to write)')
