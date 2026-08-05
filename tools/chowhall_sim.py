"""The chow hall as a SIMULATION, not a baked diorama.

    exec(open(r"C:\\Users\\caleb\\RECONgame\\tools\\chowhall_sim.py").read())
    build(n=1)      # one man, full cycle - judge it before scaling
    build(n=5)      # then more

Caleb: *"can we start with just one guy in the line and than add more and have them
randomly sit down at different tables."*

WHY THE OLD VERSION PUT MEN IN THE SAME SEAT. Seats were assigned from a fixed list
while men cycled at different phases, so two men could hold the same seat at the same
time - measured 0.01-0.02 m apart. Seats are now scheduled by TIME.

THE SCHEDULING RULE. A man occupies a seat for D frames. With N men evenly staggered by
L/N, the number of seats that can be simultaneously busy is ceil(D / (L/N)); anything
beyond that is free choice. So man i takes seat `order[i % K]` where K is that count
plus one, and `order` is shuffled by a fixed seed. It looks random and it is provably
collision-free, because men i and i+K start K*(L/N) >= D apart. This is also what the
game will do at runtime: ask for a free seat.

THE COLLECTOR IS A RESOURCE. One man receiving takes `receive` frames, so arrivals must
be at least that far apart. build() checks it and refuses rather than double-booking him.

CALEB'S PLACEMENTS ARE THE TRUTH. The collector sits where he put him; the diner walks
to a stand-point in front of him. Nothing here moves anything he placed.
"""
import bpy
import json
import math
from mathutils import Vector, Matrix, Euler

M = "mixamorig:"
PROD = r"C:\Users\caleb\RECONgame\production"
COLL = "WORKBENCH_chowhall"

QUEUE_X, COUNTER_Y, QUEUE_BACK_Y = -2.05, -240.90, -242.87
LIB_PATH = r"C:\Users\caleb\RECONgame\assets\shared\anim_library.blend"

# (clip, repeats, facing degrees, does it travel)
PHASES = [
    ("chow_tray_hold",   1,  90.0, False),   # in line
    ("chow_carry_step",  2,  90.0, True),    # up to the counter, tray held
    ("chow_tray_hold",   1,  90.0, False),   # served here - tray fills
    ("chow_carry_step",  3,   0.0, True),    # along the counter, tray held
    ("chow_carry_step",  3, -90.0, True),    # out to the tables, tray held
    ("chow_sit_down",    1,  None, False),   # None = face the seat
    ("chow_eat_seated",  2,  None, False),
    ("chow_stand_up",    1,  None, False),
    ("chow_carry_step",  2,  None, True),    # walk to the tray return
    ("chow_tray_hold",   1,  None, False),   # hand it over
    ("WALK_AWAY_CLIP",   4,  None, True),    # walk away, empty handed
]
WALK_TO_STOP_PHASE = 1
SERVED_PHASE = 2
FILL_PHASE = 3          # tray fills at the end of the counter sidestep
SIT_PHASE = 5
STAND_PHASE = 7
WALK_TO_RETURN_PHASE = 8
HANDOFF_PHASE = 9
WALK_AWAY_PHASE = 10


def cal():
    exec(open(r"C:\Users\caleb\RECONgame\tools\calibrate_clips.py").read(), globals())
    return CLIP_CAL          # noqa: F821


def span(a):
    return int(a.frame_range[1] - a.frame_range[0]) + 1


def yaw_for(CAL, c, want):
    return want - CAL[c]["yaw_off"]


def travel(CAL, c, obj_yaw):
    t = CAL[c]["travel"]
    a = math.radians(obj_yaw)
    return Vector((t.x * math.cos(a) - t.y * math.sin(a),
                   t.x * math.sin(a) + t.y * math.cos(a), 0.0))


def seats():
    s = sorted([o for o in bpy.data.collections[COLL].all_objects
                if o.name.startswith("work_eat")], key=lambda x: x.name)
    return s


def key_obj(CAL, obj, f, loc, clip, face):
    obj.rotation_mode = 'XYZ'
    obj.location = loc
    obj.rotation_euler = (math.radians(CAL[clip]["rx"]), 0.0,
                          math.radians(yaw_for(CAL, clip, face)))
    for path, i in (("location", 0), ("location", 1), ("location", 2),
                    ("rotation_euler", 0), ("rotation_euler", 2)):
        obj.keyframe_insert(data_path=path, index=i, frame=f)
    act = obj.animation_data.action
    cb = act.layers[0].strips[0].channelbag(obj.animation_data.action_slot, ensure=True)
    for fc in cb.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = 'CONSTANT'


def phase_lengths():
    return [span(bpy.data.actions[c]) * r for c, r, _f, _t in PHASES]


def cycle_len():
    return sum(phase_lengths())


def make_diner(CAL, rig, i, n, L, seat_obj, start, tray, food, collector_xy,
               exit_xy=None, stop_xy=None, stop_face=None):
    """One man's whole cycle. Returns (sit_frame, stand_frame, handoff_frame)."""
    for pb in rig.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    if rig.animation_data is None:
        rig.animation_data_create()
    ad = rig.animation_data
    ad.action = None
    for t in list(ad.nla_tracks):
        ad.nla_tracks.remove(t)
    tr = ad.nla_tracks.new()
    tr.name = "sim"

    sw = seat_obj.matrix_world.translation
    sf = seat_obj.matrix_world.to_3x3() @ Vector((1.0, 0.0, 0.0))
    seat_face = math.degrees(math.atan2(sf.y, sf.x))
    # where he stands to hand the tray over: 0.75 m in front of the collector
    cx, cy, cface = collector_xy
    hand_pt = Vector((cx, cy, 0.0)) + Vector((math.cos(math.radians(cface)),
                                              math.sin(math.radians(cface)), 0.0)) * 0.75
    hand_face = cface + 180.0

    if exit_xy is None:
        exit_xy = Vector((QUEUE_X - 1.6, -246.5, 0.0))
    marks = {}
    f = start
    for cycle in range(3):                     # lay it three times so the loop is covered
        # A REAL LINE. Caleb: "when people line up outside the chow hall there is a
        # real line that forms as they get food and not just people teleporting into
        # the chow hall to eat." Each man holds his own slot in the queue, one step
        # further back per man, and walks in from there.
        pos = Vector((QUEUE_X, QUEUE_BACK_Y - i * 0.98, 0.0))
        for pi, (cname, reps, face, travels) in enumerate(PHASES):
            a = bpy.data.actions[cname]
            ln = span(a)
            if pi == SERVED_PHASE:
                if stop_xy is not None:
                    pos = Vector((stop_xy.x, stop_xy.y, 0.0))
                    # (he has already WALKED here - see WALK_TO_STOP_PHASE below)
                # HE WAITS FOR THE LADLE TO FINISH. Caleb: "the guy inline has to stop
                # and wait for the animation to end with the server guy... than they
                # move forward". The hold is 90 frames and the serve is 100, so he was
                # walking off mid-scoop. Hold for as long as the serve actually takes.
                serve_len = span(bpy.data.actions["chow_serve_ladle"])
                reps = max(reps, int(math.ceil(serve_len / float(ln))))
            if pi == SIT_PHASE:
                pos = Vector((sw.x, sw.y, 0.0))
            if pi == HANDOFF_PHASE:
                pos = hand_pt.copy()
            want = face
            if want is None:
                want = seat_face if pi in (SIT_PHASE, SIT_PHASE + 1, STAND_PHASE) \
                    else hand_face

            # HE WALKS FROM HIS SEAT TO THE TRAY RETURN. He does not teleport there.
            # The distance depends on WHICH seat he took, so step count and heading are
            # computed per man rather than fixed in the phase table. Caleb: "he needs
            # to stand up and walk from his table to the tray return area".
            if pi == WALK_AWAY_PHASE:
                to = Vector((exit_xy.x - pos.x, exit_xy.y - pos.y, 0.0))
                step_len = travel(CAL, cname, yaw_for(CAL, cname, 0.0)).length
                reps = max(1, int(round(to.length / max(1e-3, step_len))))
                want = math.degrees(math.atan2(to.y, to.x))

            # HE WALKS UP TO THE SERVERY. Caleb: "from frame 124 to 125 the man in
            # line makes a big jump to where the server is". Same fault as the tray
            # return: a fixed step count then a positional snap. Compute the steps
            # from where he actually stands to the food stop.
            if pi == WALK_TO_STOP_PHASE and stop_xy is not None:
                to = Vector((stop_xy.x - pos.x, stop_xy.y - pos.y, 0.0))
                step_len = travel(CAL, cname, yaw_for(CAL, cname, 0.0)).length
                reps = max(1, int(round(to.length / max(1e-3, step_len))))
                want = math.degrees(math.atan2(to.y, to.x))

            if pi == WALK_TO_RETURN_PHASE:
                to = Vector((hand_pt.x - pos.x, hand_pt.y - pos.y, 0.0))
                step_len = travel(CAL, cname, yaw_for(CAL, cname, 0.0)).length
                reps = max(1, int(round(to.length / max(1e-3, step_len))))
                want = math.degrees(math.atan2(to.y, to.x))

            for _ in range(reps):
                key_obj(CAL, rig, f, pos.copy(), cname, want)
                st = tr.strips.new("%s_%d_%d" % (rig.name, cycle, int(f)), int(f), a)
                st.frame_start_ui = f
                st.extrapolation = 'NOTHING'
                if travels and pi != HANDOFF_PHASE:
                    pos = pos + travel(CAL, cname, yaw_for(CAL, cname, want))
                f += ln
            if cycle == 0 and pi == SERVED_PHASE:
                marks["serve"] = f - ln * reps
            if cycle == 0 and pi == FILL_PHASE:
                marks["fill"] = f
            if cycle == 0 and pi == SIT_PHASE:
                marks["sit"] = f - ln * reps
            if cycle == 0 and pi == STAND_PHASE:
                marks["stand"] = f
            if cycle == 0 and pi == HANDOFF_PHASE:
                marks["handoff"] = f - ln * reps
            if cycle == 0 and pi == WALK_AWAY_PHASE:
                marks["gone"] = f
        if cycle == 0:
            marks["cycle_end"] = f

    # the tray: empty through the queue, full from the last server, gone after handoff
    if food is not None:
        food.animation_data_clear()
        for base in range(3):
            o = start + base * L
            food.hide_viewport = food.hide_render = True
            for p in ("hide_viewport", "hide_render"):
                food.keyframe_insert(data_path=p, frame=max(1, o))
            food.hide_viewport = food.hide_render = False
            for p in ("hide_viewport", "hide_render"):
                food.keyframe_insert(data_path=p,
                                     frame=max(1, marks["fill"] + base * L))
            food.hide_viewport = food.hide_render = True
            for p in ("hide_viewport", "hide_render"):
                food.keyframe_insert(data_path=p,
                                     frame=max(1, marks["handoff"] + base * L))
        if food.animation_data and food.animation_data.action:
            for lay in food.animation_data.action.layers:
                for stp in lay.strips:
                    for cb in stp.channelbags:
                        for fc in cb.fcurves:
                            for kp in fc.keyframe_points:
                                kp.interpolation = 'CONSTANT'
    return marks


def seated_tray(man, seat_obj, tray_mesh, food_mesh):
    """A tray on the TABLE while he eats.

    Caleb: the food image "is going into the table when they sit down". Cause: the
    tray stays bone-parented to his hand through the meal, so it follows the hand
    down into the tabletop. A man who sits down PUTS THE TRAY DOWN. So the carried
    tray is hidden for the meal and this one - static, on the table, in front of his
    seat - is shown instead.
    """
    coll = bpy.data.collections[COLL]
    anchor = bpy.data.objects["WB_chowhall"]
    nm = "tray_seated_" + man
    o = bpy.data.objects.get(nm)
    if o is None:
        o = bpy.data.objects.new(nm, tray_mesh)
        coll.objects.link(o)
    fo = bpy.data.objects.get("foodsurf_" + nm)
    if fo is None:
        fo = bpy.data.objects.new("foodsurf_" + nm, food_mesh)
        coll.objects.link(fo)
    fo.parent = o
    fo.matrix_parent_inverse = Matrix.Identity(4)
    fo.location = (0.0, 0.0, 0.0)
    fo.hide_viewport = fo.hide_render = False

    sw = seat_obj.matrix_world.translation
    sf = seat_obj.matrix_world.to_3x3() @ Vector((1.0, 0.0, 0.0))
    sf = Vector((sf.x, sf.y, 0.0)).normalized()
    o.parent = anchor
    o.matrix_parent_inverse = Matrix.Identity(4)
    o.matrix_world = (Matrix.Translation(Vector((sw.x + sf.x * 0.34,
                                                 sw.y + sf.y * 0.34, 0.755)))
                      @ Matrix.Rotation(math.atan2(sf.y, sf.x) - math.pi / 2, 4, 'Z'))
    return o


def key_visible(obj, windows, L, cycles=3, clear=True):
    """Visible only inside these frame windows, repeated each cycle.

    `clear=False` for ARMATURES. animation_data_clear() wipes the object's location and
    rotation keys AND its NLA tracks - calling it on a rig froze the diner at his last
    position for the entire loop, standing in the back holding a tray. Only prop
    objects, which have nothing but visibility keys, can be cleared.
    """
    if clear:
        obj.animation_data_clear()
    obj.hide_viewport = obj.hide_render = True
    for p in ("hide_viewport", "hide_render"):
        obj.keyframe_insert(data_path=p, frame=1)
    for c in range(cycles):
        for a, b in windows:
            for fr, vis in ((a + c * L, False), (b + c * L, True)):
                if fr < 1:
                    continue
                obj.hide_viewport = obj.hide_render = vis
                for p in ("hide_viewport", "hide_render"):
                    obj.keyframe_insert(data_path=p, frame=int(fr))
    if obj.animation_data and obj.animation_data.action:
        for lay in obj.animation_data.action.layers:
            for st in lay.strips:
                for cb in st.channelbags:
                    for fc in cb.fcurves:
                        for kp in fc.keyframe_points:
                            kp.interpolation = 'CONSTANT'


def make_wait_clip():
    """The collector's idle: the BASE MIXAMO STANDING IDLE, not something I invent.

    Caleb: "why do you not know what an idle pose is? just use the base maximo idle
    standing pose". He is right. `idle_unarmed` is a real 120-frame standing idle with
    the arms down, it already loops, and it is already in the library.

    What I did instead, twice, and both were wrong: looped a 20-frame slice of the
    receive clip (snapped 0.708 m on every repeat), then hand-rotated the arms down
    from the receive stance (a man perpetually half-reaching). Use the clip that exists.
    """
    for name in ("idle_unarmed", "idle"):
        a = bpy.data.actions.get(name)
        if a is not None:
            a.use_fake_user = True
            return a
    lib = LIB_PATH
    with bpy.data.libraries.load(lib, link=False) as (src, dst):
        dst.actions = [n for n in src.actions if n in ("idle_unarmed", "idle")]
    for name in ("idle_unarmed", "idle"):
        a = bpy.data.actions.get(name)
        if a is not None:
            a.use_fake_user = True
            print("    base idle '%s' (%d frames) appended from anim_library"
                  % (name, int(a.frame_range[1] - a.frame_range[0]) + 1))
            return a
    raise RuntimeError("no base idle clip available")



def ensure_walk_clip():
    """A real Mixamo walk for the empty-handed walk-away.

    Caleb has already posed the tray CARRY, and `chow_carry_step` is that splice - his
    arms on the walk's legs - used for every leg where a man is holding a tray. But
    after the handoff his hands are empty, so the carry pose would read as carrying an
    invisible tray. `chow_queue_step` was my authored clip and its elbows fail the
    elbow law. Use the stock Mixamo walk instead: real arm swing, nothing invented.
    """
    for name in ("walking_unarmed", "walk_forward"):
        a = bpy.data.actions.get(name)
        if a is not None:
            a.use_fake_user = True
            return a
    with bpy.data.libraries.load(LIB_PATH, link=False) as (src, dst):
        dst.actions = [n for n in src.actions
                       if n in ("walking_unarmed", "walk_forward")]
    for name in ("walking_unarmed", "walk_forward"):
        a = bpy.data.actions.get(name)
        if a is not None:
            a.use_fake_user = True
            print("    base walk '%s' (%d frames, %.3f m/cycle) appended"
                  % (name, int(a.frame_range[1] - a.frame_range[0]) + 1, 1.907))
            return a
    raise RuntimeError("no base walk clip available")


def food_stop_point():
    """Where a man STOPS to be served. Caleb: "we need a stop for food node infront of
    him so that animation reads". Authored as a marker he can drag; the diner halts on
    it and the server's ladle fires only while somebody is standing there."""
    coll = bpy.data.collections[COLL]
    a = bpy.data.objects["WB_chowhall"]
    srv = bpy.data.objects["PSXRig_server"]
    bpy.context.view_layer.update()
    o = bpy.data.objects.get("work_chow_trigger")
    if o is None:
        o = bpy.data.objects.new("work_chow_trigger", None)
        o.empty_display_type = 'ARROWS'
        o.empty_display_size = 0.6
        o.show_name = True
        coll.objects.link(o)
        o.parent = a
        o.matrix_parent_inverse.identity()
        sh = srv.matrix_world @ srv.pose.bones[M + "Hips"].head
        # THE STOP BELONGS AT THE POT. Caleb: "the node to recive the food needs to be
        # by the pot its not there". Derive it from the pot the server is ladling out
        # of, on the far side from him, rather than from his own stride - that put it
        # a metre down the counter from the food.
        pot = bpy.data.objects.get("fb_chow_pot")
        if pot is not None:
            p = pot.matrix_world.translation
            away = Vector((p.x - sh.x, p.y - sh.y, 0.0))
            away = away.normalized() if away.length > 1e-6 else Vector((0.0, -1.0, 0.0))
            # right AT the pot across the counter, not past it - a man reaching the
            # servery stands at the counter edge with the pot in front of him
            tgt = Vector((p.x, p.y, 0.0)) + away * 0.55
        else:
            l = srv.matrix_world @ srv.pose.bones[M + "LeftArm"].head
            r = srv.matrix_world @ srv.pose.bones[M + "RightArm"].head
            sd = l - r
            fw = Vector((sd.y, -sd.x, 0.0))
            fw = fw.normalized() if fw.length > 1e-6 else Vector((0.0, -1.0, 0.0))
            tgt = Vector((sh.x, sh.y, 0.0)) + fw * 1.55
        o.location = (tgt.x - a.location.x, tgt.y - a.location.y, 0.0)
        # face him back at the server, whichever branch produced the position
        back = Vector((sh.x - tgt.x, sh.y - tgt.y, 0.0))
        back = back.normalized() if back.length > 1e-6 else Vector((0.0, 1.0, 0.0))
        o.rotation_euler = (0.0, 0.0, math.atan2(back.y, back.x))
    bpy.context.view_layer.update()
    return o


def exit_point():
    """Where a man goes when he is done with the chow hall.

    Caleb: "we do need a walk away phase where the unit will go about to another task".
    Authored as a marker so he can drag it to wherever men should actually leave to.
    """
    coll = bpy.data.collections[COLL]
    a = bpy.data.objects["WB_chowhall"]
    o = bpy.data.objects.get("work_chow_exit")
    if o is None:
        o = bpy.data.objects.new("work_chow_exit", None)
        o.empty_display_type = 'SINGLE_ARROW'
        o.empty_display_size = 0.7
        o.show_name = True
        coll.objects.link(o)
        o.parent = a
        o.matrix_parent_inverse.identity()
    # ALWAYS re-derive from world coords into the anchor's local space. Setting a
    # world value straight onto a parented object's `.location` put this marker at the
    # world origin, 240 m away, and the walk-away phase dutifully computed a 240 m
    # walk. Same class of bug as tray_table_eater0 ending up at y -484.
    if o.parent is a and abs(o.matrix_world.translation.y) < 100.0:
        o.location = (QUEUE_X - 2.2 - a.location.x, -248.5 - a.location.y, 0.0)
    # matrix_world is STALE until the depsgraph catches up - reading it straight after
    # setting .location returned (0,0) and the walk-away computed a 240 m march.
    bpy.context.view_layer.update()
    return o.matrix_world.translation.copy()


def clear_static_eaters():
    """Caleb's ruling: the permanently-seated men go. Every seated man now comes from
    the loop, so tables fill and empty instead of being furniture."""
    gone = []
    for i in range(8):
        for nm in ("PSXRig_eater%d" % i,):
            r = bpy.data.objects.get(nm)
            if r is None:
                continue
            for o in [c for c in bpy.data.objects if c.parent is r]:
                bpy.data.objects.remove(o, do_unlink=True)
            bpy.data.objects.remove(r, do_unlink=True)
            gone.append(nm)
        for nm in ("tray_table_eater%d" % i, "foodsurf_tray_table_eater%d" % i):
            o = bpy.data.objects.get(nm)
            if o:
                bpy.data.objects.remove(o, do_unlink=True)
    return gone


def collector_station():
    """Caleb placed him. His placement is the truth - read it, never move it."""
    d = json.load(open(PROD + r"\pose_tray_handoff_caleb.json"))
    loc = d["collector"]["object"]["loc"]
    col = bpy.data.objects["PSXRig_trayreturn"]
    col.rotation_mode = 'XYZ'
    col.location = (loc[0], loc[1], loc[2])
    rot = d["collector"]["object"]["rot_euler"]
    col.rotation_euler = (rot[0], rot[1], rot[2])
    bpy.context.view_layer.update()
    f = col.matrix_world.to_3x3() @ Vector((1.0, 0.0, 0.0))
    f = Vector((f.x, f.y, 0.0)).normalized()
    return (loc[0], loc[1], math.degrees(math.atan2(f.y, f.x)))


def weld_to_root():
    """The hall must move as ONE object when it is grabbed.

    Two faults made it explode instead. Rigless deform meshes - body parts whose
    armature was deleted out from under them - sat at the world origin, inside the
    firebase, with an Armature modifier pointing at nothing. And the six PSXRig_*
    armatures had no parent, so a select-all-and-drag moved a mesh and its deformer
    by different amounts and the men tore apart.

    Every clip is bone-only, so re-parenting with the inverse baked in leaves the
    animation untouched.
    """
    col = bpy.data.collections[COLL]
    root = bpy.data.objects["WB_chowhall"]

    dead = [o for o in col.all_objects if o.type == 'MESH'
            and any(m.type == 'ARMATURE' and m.object is None for m in o.modifiers)]
    for o in dead:
        bpy.data.objects.remove(o, do_unlink=True)

    inv = root.matrix_world.inverted()
    welded = 0
    for o in [x for x in col.all_objects if x.parent is None and x is not root]:
        mw = o.matrix_world.copy()
        o.parent = root
        o.matrix_parent_inverse = inv
        o.matrix_world = mw
        welded += 1
    bpy.context.view_layer.update()
    return len(dead), welded


def rigid_move_check(dist=10.0):
    """Grab the root, and every visible man must travel exactly with it and keep his
    proportions. This is the gate on the fault Caleb saw - the cook blowing up out of
    proportion when the hall was dragged.

    Only VISIBLE meshes can be checked: a hide_viewport object is never evaluated by
    the depsgraph, so its matrix is stale and reads as 'did not move' whatever is true.
    """
    root = bpy.data.objects["WB_chowhall"]
    targets = [o for o in bpy.data.collections[COLL].all_objects
               if o.type == 'MESH' and not o.hide_viewport
               and any(m.type == 'ARMATURE' for m in o.modifiers)]

    def sample():
        dg = bpy.context.evaluated_depsgraph_get()
        out = {}
        for o in targets:
            ev = o.evaluated_get(dg)
            me = ev.to_mesh()
            vs = [ev.matrix_world @ v.co for v in me.vertices]
            out[o.name] = (vs[0].copy(),
                           Vector((max(v.x for v in vs) - min(v.x for v in vs),
                                   max(v.y for v in vs) - min(v.y for v in vs),
                                   max(v.z for v in vs) - min(v.z for v in vs))))
            ev.to_mesh_clear()
        return out

    a = sample()
    root.location.x += dist
    bpy.context.view_layer.update()
    b = sample()
    root.location.x -= dist
    bpy.context.view_layer.update()

    bad = []
    for nm, (p0, s0) in a.items():
        p1, s1 = b[nm]
        d = p1 - p0
        if abs(d.x - dist) > 1e-4 or abs(d.y) > 1e-4 or abs(d.z) > 1e-4:
            bad.append("%s TORE OFF the hall (moved %.2f, %.2f, %.2f)" % (nm, d.x, d.y, d.z))
        if (s1 - s0).length > 1e-4:
            bad.append("%s CHANGED SIZE when the hall moved (%.3f -> %.3f)"
                       % (nm, s0.length, s1.length))
    return len(targets), bad


def build(n=1, seed=7):
    CAL = cal()
    # resolve the walk-away clip first - cycle_len() reads the phase table
    walkaway = ensure_walk_clip()
    PHASES[WALK_AWAY_PHASE] = (walkaway.name,) + tuple(PHASES[WALK_AWAY_PHASE][1:])
    print("  walk-away uses '%s' (empty handed, stock arm swing)" % walkaway.name)
    L = cycle_len()
    lens = phase_lengths()
    D = lens[SIT_PHASE] + lens[SIT_PHASE + 1] + lens[STAND_PHASE]   # seat busy window
    recv = span(bpy.data.actions["chow_tray_receive"])
    stagger = L // max(1, n)

    print("=== chow hall sim ===")
    print("  cycle %d frames (%.1f s) | %d men | stagger %d frames"
          % (L, L / 30.0, n, stagger))
    print("  seat occupied for %d frames | collector needs %d between arrivals"
          % (D, recv))
    if n > 1 and stagger < recv:
        print("  !! %d men puts arrivals %d frames apart but the collector needs %d."
              % (n, stagger, recv))
        print("     Cap is n=%d with one collector." % max(1, L // recv))
        return

    gone = clear_static_eaters()
    if gone:
        print("  removed static eaters:", len(gone))
    cxy = collector_station()
    stop_obj = food_stop_point()
    stop_pt = stop_obj.matrix_world.translation.copy()
    _sf = stop_obj.matrix_world.to_3x3() @ Vector((1.0, 0.0, 0.0))
    stop_face = math.degrees(math.atan2(_sf.y, _sf.x))
    print("  work_chow_trigger node at (%.2f, %.2f) facing %.1f"
          % (stop_pt.x, stop_pt.y, stop_face))
    exit_xy = exit_point()
    print("  exit marker 'work_chow_exit' at (%.2f, %.2f)" % (exit_xy.x, exit_xy.y))
    print("  collector restored to Caleb's placement (%.2f, %.2f) facing %.1f" % cxy)

    S = seats()
    need = int(math.ceil(D / float(stagger))) + 1 if n > 1 else 1
    order = list(range(len(S)))
    # deterministic shuffle - looks random, repeats exactly
    for i in range(len(order) - 1, 0, -1):
        j = (seed * (i + 7) * 1103515245 + 12345) % (i + 1)
        order[i], order[j] = order[j], order[i]
    print("  seats: %d available, %d needed to avoid overlap" % (len(S), need))

    pool = [o for o in bpy.data.objects if o.type == 'ARMATURE'
            and o.name.startswith("PSXRig_")
            and o.name not in ("PSXRig_trayreturn", "PSXRig_cook", "PSXRig_server")]
    pool.sort(key=lambda x: x.name)
    if len(pool) < n:
        print("  !! only %d diner rigs available, need %d" % (len(pool), n))
        n = len(pool)

    owners = json.load(open(PROD + r"\chowhall_tray_owners.json"))
    report = []
    L_actual = []
    for i in range(n):
        rig = pool[i]
        seat = S[order[i % max(1, need)] % len(S)]
        tname = owners.get(rig.name.replace("PSXRig_", ""))
        tray = bpy.data.objects.get(tname) if tname else None
        food = bpy.data.objects.get("foodsurf_" + tname) if tname else None
        start = 1 - i * stagger
        marks = make_diner(CAL, rig, i, n, L, seat, start, tray, food, cxy, exit_xy,
                           stop_xy=stop_pt, stop_face=stop_face)
        man = rig.name.replace("PSXRig_", "")
        # THE CYCLE IS NOT A FIXED LENGTH ANY MORE. The walk to the tray return and the
        # walk away are both computed from the man's seat, so his real cycle differs
        # from the phase table's nominal one. Key everything off what he ACTUALLY did.
        Lman = marks.get("cycle_end", start + L) - start
        L_actual.append(Lman)

        # THE TRAY CHANGES OWNER THROUGH THE CYCLE.
        #   carried  : from the start of the cycle until he sits
        #   on table : while he eats
        #   carried  : again from standing up until the handoff
        #   gone     : after he hands it over
        if tray is not None:
            key_visible(tray, [(start, marks["sit"]),
                               (marks["stand"], marks["handoff"])], Lman)
        if food is not None:
            key_visible(food, [(marks["fill"], marks["sit"]),
                               (marks["stand"], marks["handoff"])], Lman)
        st = seated_tray(man, seat, bpy.data.meshes["fb_tray_base"],
                         bpy.data.meshes["fb_tray_food_surface"])
        key_visible(st, [(marks["sit"], marks["stand"])], Lman)
        # the food surface is its OWN object - hiding the tray does not hide it, so
        # it was left floating over the table with no tray under it. Key them together.
        stf = bpy.data.objects.get("foodsurf_tray_seated_" + man)
        if stf is not None:
            key_visible(stf, [(marks["sit"], marks["stand"])], Lman)
        if "gone" in marks:
            key_visible(rig, [(start, marks["gone"])], Lman, clear=False)
        report.append((rig.name, seat.name, marks))

    # NOBODY STANDS AROUND. Caleb: "i need the person that is handing the tray to
    # just not stand there permanently". Any diner rig this run does not use is
    # cleared and hidden rather than left frozen mid-pose in the room.
    for extra in pool[n:]:
        if extra.animation_data:
            extra.animation_data.action = None
            for t in list(extra.animation_data.nla_tracks):
                extra.animation_data.nla_tracks.remove(t)
        extra.hide_viewport = extra.hide_render = True
        for ch in bpy.data.objects:
            if ch.parent is extra:
                ch.hide_viewport = ch.hide_render = True
        own = owners.get(extra.name.replace("PSXRig_", ""))
        if own:
            for nm2 in (own, "foodsurf_" + own):
                o2 = bpy.data.objects.get(nm2)
                if o2:
                    o2.animation_data_clear()
                    o2.hide_viewport = o2.hide_render = True
    for used in pool[:n]:
        used.hide_viewport = used.hide_render = False
    print("  hidden unused diners:", [o.name for o in pool[n:]])

    ck = bpy.data.objects.get("PSXRig_cook")
    if ck is not None and ck.animation_data:
        for t in ck.animation_data.nla_tracks:
            for stp in t.strips:
                stp.frame_start_ui = stp.frame_start - 53   # his own phase

    # THE SERVER LADLES ONLY WHEN SOMEONE IS AT THE FOOD STOP.
    # Caleb: "the guy laddeling the food needs to only do it when someones infront of
    # him". Same shape as the collector: a base idle underneath, and the serve clip
    # fired as an event at each diner's serve window.
    srv = bpy.data.objects.get("PSXRig_server")
    if srv is not None:
        if srv.animation_data is None:
            srv.animation_data_create()
        sad = srv.animation_data
        sad.action = None
        for t in list(sad.nla_tracks):
            sad.nla_tracks.remove(t)
        sidle = make_wait_clip()
        swt = sad.nla_tracks.new()
        swt.name = "wait"
        sws = swt.strips.new("wait", 1, sidle)
        # STAGGER THE IDLES. Caleb: "all the men in idle are in the same time frame
        # loop... we'll have to stagger their idle movements a bit more." Every
        # stationed man started his idle at frame 1, so they breathed in unison.
        # Start each at his own phase inside the clip.
        sws.frame_start_ui = 1 - int(0.37 * sidle.frame_range[1])
        sws.repeat = float(L) / float(sidle.frame_range[1]) + 1.0
        sws.extrapolation = 'HOLD'
        sws.blend_type = 'REPLACE'
        sst = sad.nla_tracks.new()
        sst.name = "serve"
        sact = bpy.data.actions["chow_serve_ladle"]
        nserve = 0
        for _nm, _sn, mk in report:
            if "serve" not in mk:
                continue
            for base in range(3):
                fr = mk["serve"] + base * L
                if fr > 0:
                    ss = sst.strips.new("serve_%d" % int(fr), int(fr), sact)
                    ss.frame_start_ui = fr
                    ss.extrapolation = 'NOTHING'
                    nserve += 1
        print("  server: idle base + %d ladle events (only when a man is on work_chow_trigger)"
              % nserve)

    # the collector receives at each arrival
    col = bpy.data.objects["PSXRig_trayreturn"]
    if col.animation_data is None:
        col.animation_data_create()
    col.animation_data.action = None
    for t in list(col.animation_data.nla_tracks):
        col.animation_data.nla_tracks.remove(t)
    # BASE WAIT TRACK FIRST, so it sits underneath. Without it the receive strips use
    # NOTHING extrapolation and nothing drives him between arrivals - he drops to rest,
    # which is the T-pose Caleb keeps seeing. This must be rebuilt inside build(),
    # because build() wipes his tracks every run.
    wt = col.animation_data.nla_tracks.new()
    wt.name = "wait"
    widle = make_wait_clip()
    ws = wt.strips.new("wait", 1, widle)
    ws.frame_start_ui = 1 - int(0.71 * widle.frame_range[1])
    ws.repeat = float(L) / float(widle.frame_range[1]) + 1.0
    ws.extrapolation = 'HOLD'
    # REPLACE, do not blend. Left as the default the idle layers on top of whatever
    # stance is underneath, so his arms stayed half-raised from the receive pose and
    # the elbow gate caught them 0.24 m above his hands. The idle IS his pose.
    ws.blend_type = 'REPLACE'
    ws.influence = 1.0
    ws.use_animated_influence = False

    ctr = col.animation_data.nla_tracks.new()
    ctr.name = "receive"
    ra = bpy.data.actions["chow_tray_receive"]
    for nm, sn, mk in report:
        for base in range(3):
            f = mk["handoff"] + base * L
            if f > 0:
                s = ctr.strips.new("recv_%s_%d" % (nm, int(f)), int(f), ra)
                s.frame_start_ui = f
                s.extrapolation = 'NOTHING'

    sc = bpy.context.scene
    L = max(L_actual) if L_actual else L
    sc.frame_start, sc.frame_end = 1, L
    sc.frame_set(1)
    bpy.context.view_layer.update()

    # SELF-CHECK. Every fix I made live got wiped the next time build() regenerated
    # the thing it fixed - the collector's wait track three times over. So the checks
    # live HERE, at the end of the builder, and shout rather than pass quietly.
    fails = []
    for f in (1, L // 4, L // 2, (3 * L) // 4, L - 1):
        sc.frame_set(max(1, f))
        bpy.context.view_layer.update()
        for o in bpy.data.objects:
            if o.type != 'ARMATURE' or o.hide_viewport:
                continue
            if M + "LeftHand" not in o.pose.bones:
                continue
            lh = o.matrix_world @ o.pose.bones[M + "LeftHand"].head
            rh = o.matrix_world @ o.pose.bones[M + "RightHand"].head
            hp = o.matrix_world @ o.pose.bones[M + "Hips"].head
            hd = o.matrix_world @ o.pose.bones[M + "Head"].head
            if (lh - rh).length > 1.10:
                fails.append("%s REST/T-POSE at f%d (hand span %.2f)"
                             % (o.name, f, (lh - rh).length))
            if hd.z < hp.z + 0.30:
                fails.append("%s not upright at f%d" % (o.name, f))

            # ELBOW LAW. Caleb, 2026-08-03: "your number one mistake has been putting
            # elbows into characters themselves or objects... that needs to be
            # corrected forever." A 2-link arm has a redundant DOF - the elbow orbits
            # the shoulder-to-hand axis - so a hand-only solve is free to bury it.
            # Check the elbow itself, every man, every sampled frame.
            chest = o.matrix_world @ o.pose.bones[M + "Spine2"].head
            for side, hand in (("Left", lh), ("Right", rh)):
                el = o.matrix_world @ o.pose.bones[M + side + "ForeArm"].head
                sh = o.matrix_world @ o.pose.bones[M + side + "Arm"].head
                # NOT "elbow above hand" - with the arms hanging at his sides the elbow
                # is ABOVE the hand and that is correct anatomy. The faults are the
                # elbow riding above the SHOULDER while the hand is low (a chicken
                # wing), and the elbow inside solid geometry.
                if el.z > sh.z + 0.04 and hand.z < sh.z:
                    fails.append("%s %s ELBOW ABOVE SHOULDER (%.2f m) with hand low at f%d"
                                 % (o.name, side, el.z - sh.z, f))
                # inside his own torso? chest half-width is ~0.17 on this rig
                if Vector((el.x - chest.x, el.y - chest.y, 0.0)).length < 0.13:
                    fails.append("%s %s ELBOW INSIDE HIS OWN BODY at f%d"
                                 % (o.name, side, f))
                # inside a prop? test the props he is actually near
                for pr in bpy.data.objects:
                    if pr.type != 'MESH' or pr.hide_viewport:
                        continue
                    if not pr.name.startswith(("fb_int_", "fb_chow_", "tray_")):
                        continue
                    loc = pr.matrix_world.inverted() @ el
                    ok, pt, nor, _i = pr.closest_point_on_mesh(loc)
                    if ok and (loc - pt).length < 0.05 and (loc - pt).dot(nor) < 0:
                        fails.append("%s %s ELBOW INSIDE %s at f%d"
                                     % (o.name, side, pr.name, f))
    sc.frame_set(1)
    bpy.context.view_layer.update()

    dead, welded = weld_to_root()
    print("  welded to WB_chowhall: %d objects | removed %d rigless meshes"
          % (welded, dead))
    checked, tore = rigid_move_check()
    fails += tore
    if not tore:
        print("  rigid-move: %d visible rigged meshes travel with the root, no distortion"
              % checked)

    if fails:
        print("  !! SELF-CHECK FAILED")
        for x in sorted(set(fails)):
            print("     ", x)
    else:
        print("  self-check: every visible man posed and upright at 5 sample frames")
    print("\n  %-20s %-16s %6s %6s %8s" % ("man", "seat", "sit", "stand", "handoff"))
    for nm, sn, mk in report:
        print("  %-20s %-16s %6d %6d %8d"
              % (nm, sn, mk["sit"], mk["stand"], mk["handoff"]))
    print("\n  scene range 1-%d" % L)
    return report
