"""Stage the Huey EMBARK beat: six grunts run up, climb aboard, doors shut, liftoff.

Re-runnable source of truth, same pattern as huey_lz_loop.py. Opens the LZ staging
file (heli, crew and the six pax already placed), rebuilds each man's kit with a
per-man random assembly so no two read as clones, then keys the boarding
choreography and saves a separate embark file.

The film reference (We Were Soldiers, 24.2-27.3s) would not mocap: 360p with heavy
occlusion tracked at 82% yet retargeted to a collapsed heap, so the beats below are
hand-keyed off that footage instead -- run up, turn at the door, step aboard.

    blender -b assets/us/vehicles/huey_lz_staging.blend -P tools/huey_embark_loop.py
"""
import bpy, random, math, traceback
from mathutils import Matrix, Vector

SCR = r"C:/Users/caleb/AppData/Local/Temp/claude/C--Users-caleb/196c26d6-27be-4609-96bb-84e0469827e5/scratchpad"
OUT = r"C:/Users/caleb/RECONgame/assets/us/vehicles/huey_embark_staging.blend"
GRUNT = r"C:/Users/caleb/RECONgame/assets/us/characters/us_grunt_rifleman.glb"
SEED = 1969

# beats, 30fps
F_HOLD, F_RUN, F_DOORS, F_LIFT, F_END = 1, 60, 560, 620, 800
STAGGER = 34
RUN_LEN = 150
STEP_LEN = 70

log = []


def channelbag(act):
    if not len(act.layers) or not len(act.layers[0].strips):
        return None
    return act.layers[0].strips[0].channelbag(act.slots[0])


def capture_kit():
    """Read the grunt kit once in REST pose, recording each piece's parent bone."""
    before = {o.name for o in bpy.data.objects}
    bpy.ops.import_scene.gltf(filepath=GRUNT)
    new = [o for o in bpy.data.objects if o.name not in before]
    imp = next(o for o in new if o.type == 'ARMATURE')
    imp.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    prefixes = ("helmet", "web", "ruck", "canteen", "pouch")
    specs = []
    for o in new:
        if o.type != 'MESH':
            continue
        if not (o.name.startswith(prefixes) or "m16_world" in o.name):
            continue
        if o.parent_type == 'BONE' and o.parent_bone:
            bw = imp.matrix_world @ imp.pose.bones[o.parent_bone].matrix
            rel = bw.inverted() @ o.matrix_world
            specs.append({"data": o.data.copy(), "name": o.name,
                          "bone": o.parent_bone, "rel": rel.copy()})
        else:
            rel = imp.matrix_world.inverted() @ o.matrix_world
            specs.append({"data": o.data.copy(), "name": o.name,
                          "bone": None, "rel": rel.copy()})
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
    return specs


def wanted(name, rng):
    """Per-man assembly roll. Rifle and core webbing always; the rest varies."""
    if "m16_world" in name:
        return True
    if name.startswith(("web_belt", "web_susp", "web_buckle", "web_back_yoke")):
        return True
    if name.startswith("helmet_shell_worn"):
        return True
    if name.startswith("helmet_camo_shell"):
        return rng.random() < 0.55
    if name.startswith("helmet_bugjuice"):
        return rng.random() < 0.35
    if name.startswith("ruck"):
        return rng.random() < 0.50
    if name.startswith("web_bandolier"):
        return rng.random() < 0.60
    if name.startswith("canteen"):
        return rng.random() < 0.55
    if name.startswith("pouch"):
        return rng.random() < 0.70
    return rng.random() < 0.80


def rekit(rig, specs, rng):
    body = rig.name + "_body"
    for c in [c for c in rig.children if c.type == 'MESH' and c.name != body]:
        bpy.data.objects.remove(c, do_unlink=True)
    was = rig.data.pose_position
    rig.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    n = 0
    for s in specs:
        if not wanted(s["name"], rng):
            continue
        m = bpy.data.objects.new("%s_%s" % (rig.name, s["name"]), s["data"].copy())
        bpy.context.scene.collection.objects.link(m)
        m.parent = rig
        if s["bone"]:
            m.parent_type = 'BONE'
            m.parent_bone = s["bone"]
            m.matrix_parent_inverse = Matrix.Identity(4)
            bpy.context.view_layer.update()
            m.matrix_world = (rig.matrix_world @ rig.pose.bones[s["bone"]].matrix) @ s["rel"]
        else:
            m.parent_type = 'OBJECT'
            m.matrix_world = rig.matrix_world @ s["rel"]
            m.modifiers.new("Armature", 'ARMATURE').object = rig
        n += 1
    rig.data.pose_position = was
    return n


try:
    rng = random.Random(SEED)
    sc = bpy.context.scene
    heli = bpy.data.objects["HELI_ROOT"]

    # the aircraft is already down when the beat opens, and climbs out at the end
    sc.frame_set(400)
    bpy.context.view_layer.update()
    ground = heli.matrix_world.translation.copy()
    floor = max((bpy.data.objects["huey_int_floor_cabin"].evaluated_get(
        bpy.context.evaluated_depsgraph_get()).matrix_world @ v.co).z
        for v in bpy.data.objects["huey_int_floor_cabin"].data.vertices)
    if heli.animation_data and heli.animation_data.action:
        heli.animation_data.action.use_fake_user = False
        heli.animation_data_clear()
    heli.location = ground
    for f, dz in ((F_HOLD, 0.0), (F_LIFT, 0.0), (F_LIFT + 80, 6.0), (F_END, 24.0)):
        drift = 0.0 if f <= F_LIFT else (f - F_LIFT) * 0.05
        heli.location = (ground.x, ground.y - drift, ground.z + dz)
        heli.keyframe_insert("location", frame=f)
    log.append("heli grounded f%d-%d, climbs to +24m by f%d" % (F_HOLD, F_LIFT, F_END))

    sc.frame_set(F_HOLD)
    bpy.context.view_layer.update()
    seats = {i: bpy.data.objects["seat_pax_%d" % i].matrix_world.translation.copy()
             for i in range(1, 7)}
    # muster point outside the left door
    door = (seats[2] + seats[5]) * 0.5 + Vector((-2.2, 0.0, 0.0))

    specs = capture_kit()
    log.append("kit library: %d pieces captured" % len(specs))

    # Body clips come from the shared library. Men crouch-walk in under the disc
    # and sit once aboard -- without these they slide along in their frozen
    # disembark pose.
    LIB = r"C:/Users/caleb/RECONgame/assets/shared/anim_library.blend"
    with bpy.data.libraries.load(LIB, link=False) as (src, dst):
        dst.actions = [a for a in src.actions
                       if a in ("walk_crouching_forward", "sitting")]
    walk_act = bpy.data.actions.get("walk_crouching_forward")
    sit_act = bpy.data.actions.get("sitting")
    for a in (walk_act, sit_act):
        if a is None:
            continue
        a.use_fake_user = True
        b = channelbag(a)
        if b:
            # The root path is keyed on the object, so clip travel must go -- but the
            # Hips location channel also carries hip HEIGHT. Dropping it whole folds
            # the man onto the ground (head z 0.02). Strip X/Z, keep Y, exactly as
            # tools/export_anim_library.py does.
            for fc in list(b.fcurves):
                if fc.data_path == 'pose.bones["mixamorig:Hips"].location' \
                        and fc.array_index in (0, 2):
                    b.fcurves.remove(fc)
    log.append("body clips: walk=%s sit=%s" % (
        walk_act.name if walk_act else None, sit_act.name if sit_act else None))

    seated_at = {}
    for i in range(1, 7):
        rig = bpy.data.objects["us_pax_%d" % i]
        # Read where the disembark left him BEFORE touching anything -- sampling
        # after the curves are stripped returns a stale static transform, and the
        # LZ scene leaves men constrained to the airframe, which reads as +24m.
        sc.frame_set(1150)
        bpy.context.view_layer.update()
        start = rig.matrix_world.translation.copy()
        rig.constraints.clear()
        rig.animation_data_clear()
        # Set location only. Writing matrix_world here wipes the rig's rest
        # orientation (these came in from glTF) and lays every man on his back.
        rig.location = start
        bpy.context.view_layer.update()

        t0 = F_RUN + (i - 1) * STAGGER
        t_lane = t0 + 90
        t_door = t0 + RUN_LEN
        t_seat = t_door + STEP_LEN
        seated_at[i] = t_seat

        # You always load a Huey from the SIDE. Coming in off the nose puts you under
        # a rotor disc that dips as the ship settles; coming in off the tail puts you
        # into the tail rotor. So every man runs out to a lane abeam his door first,
        # then turns in perpendicular to the fuselage. Three men to a side.
        side = -1.0 if i <= 3 else 1.0
        door_x = seats[i].x + side * 1.6
        cabin_y = ground.y
        # Three men to a door, spread along the opening.
        slot = ((i - 1) % 3) - 1.0
        lane = Vector((door_x + side * 3.4, cabin_y + slot * 0.9, start.z))
        muster = Vector((door_x + side * 1.3, cabin_y + slot * 0.75, start.z))
        # They do NOT climb in and perch on the bench. The Vietnam Huey load is a man
        # sitting on the cabin FLOOR at the door lip with his legs hanging outside --
        # that is the iconic silhouette, and it also kills the fake vertical slide,
        # because the height change becomes one sit onto the lip.
        # The library "sitting" clip is a chair sit: hips ~0.55 above the object origin
        # with the legs hanging down. Drop the origin so the hips land on the deck and
        # those legs hang out over the lip instead of perching at bench height.
        aboard = Vector((side * 1.20, cabin_y + slot * 0.75, floor - 0.40))

        for f, pos in ((F_HOLD, start), (t0, start), (t_lane, lane),
                       (t_door, muster), (t_seat, aboard), (F_END, aboard)):
            rig.location = pos
            rig.keyframe_insert("location", frame=f)

        # Facing convention matches the walk aim: to face (dx,dy), yaw = atan2(dy,dx) - pi/2.
        yaw0 = rig.rotation_euler.z
        out = math.atan2(lane.y - start.y, lane.x - start.x) - math.pi / 2
        turn_in = math.atan2(muster.y - lane.y, muster.x - lane.x) - math.pi / 2
        # Seated facing OUT of the door. atan2(0,side) - pi/2 pointed his legs into the
        # cabin, so it is the opposite heading: add pi.
        face_out = math.atan2(0.0, side) + math.pi / 2
        for f, yz in ((F_HOLD, yaw0), (t0, yaw0), (t0 + 25, out), (t_lane, out),
                      (t_lane + 20, turn_in), (t_door, turn_in), (t_seat, face_out)):
            rig.rotation_euler.z = yz
            rig.keyframe_insert("rotation_euler", index=2, frame=f)

        # Body: crouch-walk the whole approach, then sit once aboard. These ride on
        # NLA tracks so the object-level path keys above stay in the active action
        # and evaluate on top of them.
        ad = rig.animation_data
        if walk_act is not None:
            trk = ad.nla_tracks.new()
            trk.name = "approach"
            span = max(1.0, walk_act.frame_range[1] - walk_act.frame_range[0])
            s = trk.strips.new("crouch_walk", int(t0), walk_act)
            s.repeat = max(1.0, (t_seat - t0) / span)
            s.blend_type = 'REPLACE'
        if sit_act is not None:
            trk2 = ad.nla_tracks.new()
            trk2.name = "aboard"
            span2 = max(1.0, sit_act.frame_range[1] - sit_act.frame_range[0])
            s2 = trk2.strips.new("seated", int(t_seat), sit_act)
            s2.repeat = max(1.0, (F_END - t_seat) / span2)
            s2.blend_type = 'REPLACE'

        # Travel paths are waypoint-to-waypoint, so they must be LINEAR. Bezier
        # handles overshoot between widely spaced keys and threw a man 10m into
        # the air on the run-in.
        if rig.animation_data and rig.animation_data.action:
            bagged = channelbag(rig.animation_data.action)
            if bagged:
                for fc in bagged.fcurves:
                    if fc.data_path in ("location", "rotation_euler"):
                        for k in fc.keyframe_points:
                            k.interpolation = 'LINEAR'
                        fc.update()

        n = rekit(rig, specs, rng)
        log.append("us_pax_%d  runs f%d  door f%d  aboard f%d  kit %d pieces"
                   % (i, t0, t_door, t_seat, n))

    # Once aboard each man rides the airframe. CHILD_OF applies the target's full
    # transform, so without an explicit inverse the aircraft's world matrix lands on
    # top of the already-world-space keys and throws the man out of the map.
    sc.frame_set(F_HOLD)
    bpy.context.view_layer.update()
    ride_inverse = heli.matrix_world.inverted()
    for i in range(1, 7):
        rig = bpy.data.objects["us_pax_%d" % i]
        con = rig.constraints.new('CHILD_OF')
        con.name = "ride"
        con.target = heli
        con.inverse_matrix = ride_inverse
        con.influence = 0.0
        con.keyframe_insert("influence", frame=seated_at[i] - 1)
        con.influence = 1.0
        con.keyframe_insert("influence", frame=seated_at[i])

    # The clips carry hip HEIGHT in Hips location Y, which stacks on top of the rig's
    # own rest hip height and floats every man ~0.9m off the deck. Measure each man's
    # lowest foot mid-stride and drop his whole path by that much.
    for i in range(1, 7):
        rig = bpy.data.objects["us_pax_%d" % i]
        probe = F_RUN + (i - 1) * STAGGER + 40
        sc.frame_set(probe)
        bpy.context.view_layer.update()
        ev = rig.evaluated_get(bpy.context.evaluated_depsgraph_get())
        gm = ev.matrix_world
        drop = min((gm @ ev.pose.bones[b].matrix).translation.z
                   for b in ("mixamorig:LeftToeBase", "mixamorig:RightToeBase",
                             "mixamorig:LeftFoot", "mixamorig:RightFoot"))
        bagged = channelbag(rig.animation_data.action)
        if bagged:
            for fc in bagged.fcurves:
                if fc.data_path == "location" and fc.array_index == 2:
                    for k in fc.keyframe_points:
                        k.co.y -= drop
                        k.handle_left.y -= drop
                        k.handle_right.y -= drop
                    fc.update()
        log.append("us_pax_%d grounded: dropped %.3fm" % (i, drop))

    # capture_kit re-imports the grunt GLB, which ships these three materials as
    # unlinked pure white -- helmets and chest straps read as bright white without this.
    for mat_name, rgb in (("MitchellCamo", (0.055, 0.070, 0.032, 1.0)),
                          ("Webbing", (0.075, 0.082, 0.048, 1.0)),
                          ("bandolier_tex", (0.085, 0.090, 0.052, 1.0))):
        for m in [x for x in bpy.data.materials if x.name.split(".")[0] == mat_name]:
            if not m.use_nodes:
                continue
            for bsdf in [n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED']:
                bc = bsdf.inputs['Base Color']
                if not bc.is_linked and tuple(round(v, 2) for v in bc.default_value)[:3] == (1.0, 1.0, 1.0):
                    bc.default_value = rgb
                    bsdf.inputs['Roughness'].default_value = 0.88
                    bsdf.inputs['Metallic'].default_value = 0.0

    # Huey cargo doors SLIDE AFT on a rail -- they do not swing. Rotating them was
    # wrong. Open (slid back) for the whole load, then run forward to shut before
    # liftoff. Tail is +Y, so aft is +Y.
    for name in ("Door_Left", "Door_Right"):
        o = bpy.data.objects.get(name)
        if o is None:
            continue
        shut = o.location.y
        for f, dy in ((F_HOLD, 1.15), (F_DOORS, 1.15), (F_DOORS + 40, 0.0)):
            o.location.y = shut + dy
            o.keyframe_insert("location", index=1, frame=f)
        o.location.y = shut
    log.append("doors slide aft-open until f%d, shut by f%d" % (F_DOORS, F_DOORS + 40))

    sc.frame_start = F_HOLD
    sc.frame_end = F_END
    bpy.ops.wm.save_as_mainfile(filepath=OUT)
    log.append("SAVED %s (%d frames)" % (OUT, F_END))
except Exception:
    log.append("ERROR\n" + traceback.format_exc())

open(SCR + "/embark.txt", "w", encoding="utf-8").write("\n".join(log))
