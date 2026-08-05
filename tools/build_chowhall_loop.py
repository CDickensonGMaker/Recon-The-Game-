"""THE CHOW HALL LOOP - queue, get a tray, walk to a table, sit, eat, bus the tray.

    exec(open(r"C:\\Users\\caleb\\RECONgame\\tools\\build_chowhall_loop.py").read())

Caleb: *"i need the line queue people to stand in line, get a tray than go sit at a table
and eat. thats the loop."* / *"we should have a line start, each step of the line, and a
line exit marker."*

EVERYTHING ORIENTATION-RELATED IS MEASURED, NOT DERIVED. `tools/calibrate_clips.py` runs
first and reports, per clip, the object X rotation that stands the man up and the offset
between object yaw and the body's ACTUAL facing. Measured on this file:
  * EVERY clip needs rx = +90. Keying yaw alone left men lying on the floor, hips z 0.02.
  * yaw offsets run -88 deg (walks) to -143 deg (tray_hold). So to face direction D the
    object yaw is `D - yaw_off`, per clip. Assuming one convention faced men at walls.

Travel is likewise read off each clip, never retimed:
  chow_queue_step 0.985 m / 17f   chow_tray_carry_walk 3.814 m / 64f
"""
import bpy
import math
from mathutils import Vector

M = "mixamorig:"
FPS = 30
STAGGER = 95

QUEUE_X = -2.05
COUNTER_Y = -240.90
QUEUE_BACK_Y = -242.87

DINERS = ["line1", "line2", "line3", "midline", "traystack", "queuewalk"]
SEATS = ["work_eat.004", "work_eat.010", "work_eat.005",
         "work_eat.011", "work_eat.016", "work_eat.022"]

exec(open(r"C:\Users\caleb\RECONgame\tools\calibrate_clips.py").read())
CAL = CLIP_CAL           # noqa: F821  (defined by the exec above)

import json as _json
try:
    TRAY_OWNERS = _json.load(
        open(r"C:\Users\caleb\RECONgame\production\chowhall_tray_owners.json"))
except OSError:
    TRAY_OWNERS = {}


def clip(n):
    a = bpy.data.actions.get(n)
    if a is None:
        raise RuntimeError("missing clip " + n)
    return a


def span(a):
    return int(a.frame_range[1] - a.frame_range[0]) + 1


def yaw_for(cname, want_deg):
    """Object yaw that makes THIS clip's body face `want_deg` in world."""
    return want_deg - CAL[cname]["yaw_off"]


def world_travel(cname, obj_yaw_deg):
    """Where this clip's root motion carries the body, at that object yaw."""
    t = CAL[cname]["travel"]
    a = math.radians(obj_yaw_deg)
    ca, sa = math.cos(a), math.sin(a)
    return Vector((t.x * ca - t.y * sa, t.x * sa + t.y * ca, 0.0))


def ensure_line_markers():
    """Line start, one per step, and a line exit - Caleb asked for these explicitly."""
    coll = bpy.data.collections["WORKBENCH_chowhall"]
    anchor = bpy.data.objects["WB_chowhall"]
    spec = [("line_start", (QUEUE_X, QUEUE_BACK_Y), 90.0)]
    # the four serving stations along the counter
    for i, x in enumerate((-1.5, -0.5, 0.5, 1.5)):
        spec.append(("line_step_%d" % (i + 1), (x, COUNTER_Y), 0.0))
    spec.append(("line_exit", (2.45, COUNTER_Y), -90.0))
    made = []
    for name, (x, y), facing in spec:
        o = bpy.data.objects.get(name)
        if o is None:
            o = bpy.data.objects.new(name, None)
            o.empty_display_type = 'SINGLE_ARROW'
            o.empty_display_size = 0.45
            coll.objects.link(o)
            o.parent = anchor
            made.append(name)
        o.location = (x - anchor.location.x, y - anchor.location.y, 0.0)
        o.rotation_euler = (0.0, 0.0, math.radians(facing))
    return made, [s[0] for s in spec]


def key_obj(obj, frame, loc, cname, want_face_deg):
    obj.rotation_mode = 'XYZ'
    obj.location = loc
    obj.rotation_euler = (math.radians(CAL[cname]["rx"]), 0.0,
                          math.radians(yaw_for(cname, want_face_deg)))
    for path, idx in (("location", 0), ("location", 1), ("location", 2),
                      ("rotation_euler", 0), ("rotation_euler", 2)):
        obj.keyframe_insert(data_path=path, index=idx, frame=frame)
    act = obj.animation_data.action
    cb = act.layers[0].strips[0].channelbag(obj.animation_data.action_slot, ensure=True)
    for fc in cb.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = 'CONSTANT'


def build_man(name, start, seat_name, repeats=2):
    rig = bpy.data.objects["PSXRig_%s" % name]
    for pb in rig.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    if rig.animation_data is None:
        rig.animation_data_create()
    ad = rig.animation_data
    ad.action = None
    for t in list(ad.nla_tracks):
        ad.nla_tracks.remove(t)
    tr = ad.nla_tracks.new()
    tr.name = "loop"

    seat = bpy.data.objects[seat_name]
    sw = seat.matrix_world.translation
    # the seat's own +X axis IS its facing - read it, do not guess it
    sf = seat.matrix_world.to_3x3() @ Vector((1.0, 0.0, 0.0))
    seat_face = math.degrees(math.atan2(sf.y, sf.x))

    # (clip, repeats, direction the man should FACE, does it travel)
    phases = [
        ("chow_tray_hold", 1, 90.0, False),      # in line, facing up the queue (+Y)
        ("chow_queue_step", 2, 90.0, True),      # step up to the counter
        ("chow_tray_hold", 1, 90.0, False),      # at the head: tray fills
        ("chow_queue_step", 3, 0.0, True),       # sidestep along the counter (+X)
        ("chow_queue_step", 3, -90.0, True),     # out to the tables (-Y)
        ("chow_sit_down", 1, seat_face, False),
        ("chow_eat_seated", 2, seat_face, False),
        ("chow_stand_up", 1, seat_face, False),
    ]

    # his tray, and the food surface that appears when he reaches the last server
    tray_name = TRAY_OWNERS.get(name)
    food = bpy.data.objects.get("foodsurf_" + tray_name) if tray_name else None

    f = start
    laid = []
    for _cycle in range(repeats):
        pos = Vector((QUEUE_X, QUEUE_BACK_Y, 0.0))
        cycle_start = f
        for pi, (cname, reps, face, travels) in enumerate(phases):
            a = clip(cname)
            n = span(a)
            if cname == "chow_sit_down":
                pos = Vector((sw.x, sw.y, 0.0))
            for _ in range(reps):
                key_obj(rig, f, pos.copy(), cname, face)
                st = tr.strips.new("%s_%s_%d" % (name, cname, int(f)), int(f), a)
                st.frame_start_ui = f
                st.extrapolation = 'NOTHING'
                laid.append(st)
                if travels:
                    pos = pos + world_travel(cname, yaw_for(cname, face))
                f += n
            # THE FILL. Caleb: the trays stay empty until they hit the LAST line
            # marker, then the food texture appears. Phase index 3 is the sidestep
            # along the serving counter, so its end IS the last server.
            if food is not None and pi == 3:
                for prop in ("hide_viewport", "hide_render"):
                    food.hide_viewport = True
                    food.hide_render = True
                    food.keyframe_insert(data_path=prop, frame=cycle_start)
                    food.hide_viewport = False
                    food.hide_render = False
                    food.keyframe_insert(data_path=prop, frame=f)
        # he leaves with an empty tray again next cycle
        if food is not None:
            food.hide_viewport = True
            food.hide_render = True
            for prop in ("hide_viewport", "hide_render"):
                food.keyframe_insert(data_path=prop, frame=f)
    if food is not None and food.animation_data and food.animation_data.action:
        for lay in food.animation_data.action.layers:
            for strp in lay.strips:
                for cb in strp.channelbags:
                    for fc in cb.fcurves:
                        for kp in fc.keyframe_points:
                            kp.interpolation = 'CONSTANT'
    return rig, f, laid


def main():
    sc = bpy.context.scene
    made, names = ensure_line_markers()
    print("\n=== line markers ===")
    print("  created:", made or "(already existed)")
    print("  full set:", names)

    _, endf, _ = build_man(DINERS[0], 1, SEATS[0], repeats=1)
    L = int(endf - 1)
    print("\n=== loop ===")
    for i, nm in enumerate(DINERS):
        build_man(nm, 1 - i * STAGGER, SEATS[i], repeats=3)
        print("  %-10s enters f%-5d seat %s" % (nm, 1 - i * STAGGER, SEATS[i]))

    sc.frame_start, sc.frame_end = 1, L
    sc.frame_set(1)
    bpy.context.view_layer.update()
    print("  sequence %d frames | range 1-%d (%.1f s)" % (L, L, L / FPS))


main()
