"""One continuous load/unload cycle on the Huey, built to loop seamlessly.

    inbound -> flare -> touchdown -> six men step off the floor lip and crouch out to
    the flanks -> beat -> they crouch back in, sit on the lip with legs hanging out
    -> liftoff

Built on huey_v2 (the from-scratch aircraft at real dimensions). v2 conforms to the
project facing rule -- nose +Y -- so the ship flies in from -Y and departs nose-first
over +Y. The v1 huey faced the other way; that scene is in archive/.

v2 ships no cargo doors (period-correct: slicks routinely flew with them removed), so
there is no door beat here. It also ships no root, so this builds HELI_ROOT and parents
the airframe to it.

Men load and unload from the SIDES only -- the disc dips toward the nose as the ship
settles and the tail rotor is invisible spinning. See
production/research/huey_loading/NOTES.md.

    blender -b assets/us/vehicles/huey_lz_staging.blend -P tools/huey_load_unload_loop.py
"""
import bpy, random, math, traceback
from mathutils import Matrix, Vector

SCR = r"C:/Users/caleb/AppData/Local/Temp/claude/C--Users-caleb/196c26d6-27be-4609-96bb-84e0469827e5/scratchpad"
OUT = r"C:/Users/caleb/RECONgame/assets/us/vehicles/huey_load_unload_loop.blend"
V2 = r"C:/Users/caleb/RECONgame/assets/us/vehicles/huey_v2.blend"
GRUNT = r"C:/Users/caleb/RECONgame/assets/us/characters/us_grunt_rifleman.glb"
LIB = r"C:/Users/caleb/RECONgame/assets/shared/anim_library.blend"
SEED = 1969

F_START, F_FLARE, F_LAND = 1, 170, 250
F_OFF, F_ON = 320, 900
F_LIFT, F_END = 1380, 1620
STAGGER, OUT_LEN, IN_LEN = 32, 210, 210
GROUND_Z = -0.035          # the crouch-walk clip floats the feet ~35mm; measured
SIT_DROP = 0.40            # the sitting clip puts hips ~0.55 above the object origin

log = []


def channelbag(act):
    if not len(act.layers) or not len(act.layers[0].strips):
        return None
    return act.layers[0].strips[0].channelbag(act.slots[0])


def capture_kit():
    before = {o.name for o in bpy.data.objects}
    bpy.ops.import_scene.gltf(filepath=GRUNT)
    new = [o for o in bpy.data.objects if o.name not in before]
    imp = next(o for o in new if o.type == 'ARMATURE')
    imp.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    pre = ("helmet", "web", "ruck", "canteen", "pouch")
    specs = []
    for o in new:
        if o.type != 'MESH':
            continue
        if not (o.name.startswith(pre) or "m16_world" in o.name):
            continue
        if o.parent_type == 'BONE' and o.parent_bone:
            bw = imp.matrix_world @ imp.pose.bones[o.parent_bone].matrix
            specs.append({"data": o.data.copy(), "name": o.name, "bone": o.parent_bone,
                          "rel": (bw.inverted() @ o.matrix_world).copy()})
        else:
            specs.append({"data": o.data.copy(), "name": o.name, "bone": None,
                          "rel": (imp.matrix_world.inverted() @ o.matrix_world).copy()})
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
    return specs


def wanted(name, rng):
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

    # ---- rip out the v1 airframe -----------------------------------------
    old = bpy.data.objects.get("HELI_ROOT")
    doomed = []
    if old:
        doomed = [old] + list(old.children_recursive)
    for o in doomed:
        bpy.data.objects.remove(o, do_unlink=True)
    log.append("removed v1 airframe: %d objects" % len(doomed))

    # ---- bring in v2 and give it a root ----------------------------------
    before = {o.name for o in bpy.data.objects}
    with bpy.data.libraries.load(V2, link=False) as (src, dst):
        dst.objects = list(src.objects)
    v2 = []
    for o in bpy.data.objects:
        if o.name in before or o.users_collection:
            continue
        sc.collection.objects.link(o)
        v2.append(o)
    heli = bpy.data.objects.new("HELI_ROOT", None)
    heli.empty_display_type = 'PLAIN_AXES'
    heli.empty_display_size = 2.0
    sc.collection.objects.link(heli)
    bpy.context.view_layer.update()
    for o in v2:
        if o.parent is None:
            o.parent = heli
            o.matrix_parent_inverse = Matrix.Identity(4)
    bpy.context.view_layer.update()
    log.append("appended huey_v2: %d objects under HELI_ROOT" % len(v2))

    # sit the skids on the deck
    rails = [o for o in v2 if o.name.startswith("skid_rail")]
    skid_low = min((o.matrix_world @ v.co).z for o in rails for v in o.data.vertices)
    heli.location = (0.0, 0.0, -skid_low)
    bpy.context.view_layer.update()
    ground = heli.matrix_world.translation.copy()

    fc = bpy.data.objects["floor_cabin"]
    floor = max((fc.matrix_world @ v.co).z for v in fc.data.vertices)
    sill_x = abs(bpy.data.objects["door_sill_l"].matrix_world.translation.x)
    log.append("v2 on deck: skids z0, cabin floor z %.3f, door sills x +/-%.2f" % (floor, sill_x))

    # ---- flight path: nose is +Y, so in from -Y and out over +Y ----------
    for f, dy, dz in ((F_START, -44.0, 26.0), (F_FLARE, -7.0, 4.0), (F_LAND, 0.0, 0.0),
                      (F_LIFT, 0.0, 0.0), (F_LIFT + 90, 6.0, 6.0), (F_END, 44.0, 26.0)):
        heli.location = (ground.x, ground.y + dy, ground.z + dz)
        heli.keyframe_insert("location", frame=f)
    heli.location = ground
    log.append("heli: in f%d, down f%d, up f%d, gone f%d (nose +Y)" % (F_START, F_LAND, F_LIFT, F_END))

    specs = capture_kit()
    with bpy.data.libraries.load(LIB, link=False) as (src, dst):
        dst.actions = [a for a in src.actions
                       if a in ("walk_crouching_forward", "sitting", "idle_crouching")]
    walk = bpy.data.actions.get("walk_crouching_forward")
    sit = bpy.data.actions.get("sitting")
    hold = bpy.data.actions.get("idle_crouching")
    for a in (walk, sit, hold):
        if a is None:
            continue
        a.use_fake_user = True
        b = channelbag(a)
        if b:
            # Hips location carries hip HEIGHT as well as travel -- strip X/Z, keep Y.
            for f2 in list(b.fcurves):
                if f2.data_path == 'pose.bones["mixamorig:Hips"].location' \
                        and f2.array_index in (0, 2):
                    b.fcurves.remove(f2)

    def strip(track, name, act, start, end):
        span = max(1.0, act.frame_range[1] - act.frame_range[0])
        s = track.strips.new(name, int(start), act)
        s.repeat = max(1.0, (end - start) / span)
        s.blend_type = 'REPLACE'
        return s

    sc.frame_set(F_LAND)
    bpy.context.view_layer.update()
    inv = heli.matrix_world.inverted()
    cabin_y = ground.y

    for i in range(1, 7):
        rig = bpy.data.objects["us_pax_%d" % i]
        rig.constraints.clear()
        rig.animation_data_clear()

        side = -1.0 if i <= 3 else 1.0
        slot = ((i - 1) % 3) - 1.0
        lip = Vector((side * sill_x, cabin_y + slot * 0.60, floor - SIT_DROP))
        muster = Vector((side * (sill_x + 1.6), cabin_y + slot * 0.60, GROUND_Z))
        flank = Vector((side * (7.0 + abs(slot) * 0.9), cabin_y + slot * 2.4, GROUND_Z))

        t_off = F_OFF + (i - 1) * STAGGER
        t_down = t_off + 45
        t_flank = t_off + OUT_LEN
        t_back = F_ON + (i - 1) * STAGGER
        t_muster = t_back + IN_LEN - 60
        t_lip = t_back + IN_LEN

        for f, pos in ((F_START, lip), (t_off, lip), (t_down, muster), (t_flank, flank),
                       (t_back, flank), (t_muster, muster), (t_lip, lip), (F_END, lip)):
            rig.location = pos
            rig.keyframe_insert("location", frame=f)

        # Rig forward is -Y (mc_pose.face): to face (dx,dy), yaw = atan2(dy,dx) + pi/2.
        # The old -pi/2 ran every man backwards both legs. Seated faces OUT of the door.
        face_out = math.atan2(0.0, side) + math.pi / 2
        out_hdg = math.atan2(flank.y - muster.y, flank.x - muster.x) + math.pi / 2
        in_hdg = math.atan2(muster.y - flank.y, muster.x - flank.x) + math.pi / 2
        for f, yz in ((F_START, face_out), (t_off, face_out), (t_down, out_hdg),
                      (t_flank, out_hdg), (t_back, out_hdg), (t_back + 25, in_hdg),
                      (t_muster, in_hdg), (t_lip, face_out), (F_END, face_out)):
            rig.rotation_euler.z = yz
            rig.keyframe_insert("rotation_euler", index=2, frame=f)

        ad = rig.animation_data
        trk = ad.nla_tracks.new()
        trk.name = "body"
        strip(trk, "seated_in", sit, F_START, t_off)
        strip(trk, "unload", walk, t_off, t_flank)
        strip(trk, "on_the_flank", hold, t_flank, t_back)
        strip(trk, "load", walk, t_back, t_lip)
        strip(trk, "seated_out", sit, t_lip, F_END)

        # waypoint paths must be LINEAR; bezier overshoot throws a man into the air
        bag = channelbag(ad.action)
        if bag:
            for f2 in bag.fcurves:
                if f2.data_path in ("location", "rotation_euler"):
                    for k in f2.keyframe_points:
                        k.interpolation = 'LINEAR'
                    f2.update()

        # CHILD_OF needs an explicit inverse or it throws the rider out of the map
        con = rig.constraints.new('CHILD_OF')
        con.name = "ride"
        con.target = heli
        con.inverse_matrix = inv
        for f, infl in ((F_START, 1.0), (t_off - 1, 1.0), (t_off, 0.0),
                        (t_lip - 1, 0.0), (t_lip, 1.0), (F_END, 1.0)):
            con.influence = infl
            con.keyframe_insert("influence", frame=f)
        cb = channelbag(rig.animation_data.action)
        if cb:
            for f2 in cb.fcurves:
                if "influence" in f2.data_path:
                    for k in f2.keyframe_points:
                        k.interpolation = 'CONSTANT'
                    f2.update()

        n = rekit(rig, specs, rng)
        log.append("us_pax_%d off f%d flank f%d back f%d aboard f%d kit %d"
                   % (i, t_off, t_flank, t_back, t_lip, n))

    # Crew ride the whole cycle. They carry object animation keyed to the OLD heli path,
    # so without this they fly their own trajectory behind the aircraft.
    CREW = (("us_pilot_left", "seat_pilot_l"), ("us_pilot_right", "seat_pilot_r"),
            ("us_doorgunner_left", "seat_gunner_l"), ("us_doorgunner_right", "seat_gunner_r"))
    for rig_name, seat_name in CREW:
        rig = bpy.data.objects.get(rig_name)
        seat = bpy.data.objects.get(seat_name)
        if rig is None or seat is None:
            log.append("crew MISSING %s / %s" % (rig_name, seat_name))
            continue
        rig.constraints.clear()
        rig.animation_data_clear()
        s = seat.matrix_world.translation
        rig.location = (s.x, s.y, s.z - 0.55)
        ad = rig.animation_data_create()
        trk = ad.nla_tracks.new()
        trk.name = "body"
        strip(trk, "seated", sit, F_START, F_END)
        con = rig.constraints.new('CHILD_OF')
        con.name = "ride"
        con.target = heli
        con.inverse_matrix = inv
        con.influence = 1.0
        log.append("crew %-20s -> %s" % (rig_name, seat_name))

    # the grunt GLB ships these three unlinked pure white
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

    sc.frame_start, sc.frame_end = F_START, F_END
    sc.render.fps = 30
    bpy.ops.wm.save_as_mainfile(filepath=OUT)
    log.append("SAVED %s (%d frames, %.1fs, loops)" % (OUT, F_END, F_END / 30.0))
except Exception:
    log.append("ERROR\n" + traceback.format_exc())

open(SCR + "/loop.txt", "w", encoding="utf-8").write("\n".join(log))
