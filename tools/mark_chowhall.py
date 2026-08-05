"""Author the chow hall's marker set: where every man stands and every prop lives.

    exec(open(r"C:\\Users\\caleb\\RECONgame\\tools\\mark_chowhall.py").read())

Caleb: *"make sure the chow hall has markers noting where everyone and the props should
be going."*

Markers are placed FROM the scene - each one is snapped to the thing it names, rather
than typed in from memory. That is the whole reason `work_trayreturn` ended up 1.9 m
from its own table earlier today: the table moved and the marker did not.

CONVENTIONS (measured off the original firebase markers, not assumed):
  * facing is the marker's +X axis
  * man-stance markers sit on the ground, z = 0
  * interaction markers sit at working height, z = 0.90
  * `work_*` are consumed by the game; `prop_*` and `line_*` are authoring aids
"""
import bpy
import math
from mathutils import Vector

COLL = "WORKBENCH_chowhall"
GROUND, WORK = 0.0, 0.90


def coll():
    return bpy.data.collections[COLL]


def anchor():
    return bpy.data.objects["WB_chowhall"]


def put(name, world_xy, z, facing_deg, style='SINGLE_ARROW', size=0.45):
    a = anchor()
    o = bpy.data.objects.get(name)
    if o is None:
        o = bpy.data.objects.new(name, None)
        coll().objects.link(o)
    elif o.type != 'EMPTY':
        return None
    o.empty_display_type = style
    o.empty_display_size = size
    o.parent = a
    o.matrix_parent_inverse.identity()
    o.location = (world_xy[0] - a.location.x, world_xy[1] - a.location.y, z)
    o.rotation_euler = (0.0, 0.0, math.radians(facing_deg))
    return o


def face_of(obj):
    """Facing of a body or object, as degrees, measured not assumed."""
    if obj.type == 'ARMATURE':
        M = "mixamorig:"
        l = obj.matrix_world @ obj.pose.bones[M + "LeftArm"].head
        r = obj.matrix_world @ obj.pose.bones[M + "RightArm"].head
        s = l - r
        v = Vector((s.y, -s.x, 0.0))
    else:
        v = obj.matrix_world.to_3x3() @ Vector((1.0, 0.0, 0.0))
        v = Vector((v.x, v.y, 0.0))
    if v.length < 1e-6:
        return 0.0
    v.normalize()
    return math.degrees(math.atan2(v.y, v.x))


def xy(obj, bone=None):
    if bone and obj.type == 'ARMATURE':
        p = obj.matrix_world @ obj.pose.bones["mixamorig:" + bone].head
    else:
        p = obj.matrix_world.translation
    return (p.x, p.y)


def main():
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()
    made = []

    # ---- MEN: where each one stands ------------------------------------------
    for rig_name, marker in (("PSXRig_cook", "work_cook_range"),
                             ("PSXRig_server", "work_chow_server_line"),
                             ("PSXRig_trayreturn", "work_traycollector"),
                             ("PSXRig_line3", "work_trayhandoff")):
        r = bpy.data.objects.get(rig_name)
        if not r:
            continue
        o = put(marker, xy(r, "Hips"), GROUND, face_of(r))
        if o:
            made.append((marker, "man", o))

    # ---- PROPS: where each one lives -----------------------------------------
    for obj_name, marker in (("fb_chow_pot", "prop_pot_serving"),
                             ("fb_chow_pot_range", "prop_pot_range"),
                             ("fb_tray_pile_stand", "prop_traypile"),
                             ("fb_int_fb_wash_drum", "prop_washdrum"),
                             ("fb_int_fb_tray_stack", "prop_traystack_clean"),
                             ("fb_int_fb_prep_table_cook", "prop_preptable")):
        ob = bpy.data.objects.get(obj_name)
        if not ob:
            continue
        o = put(marker, xy(ob), GROUND, face_of(ob), style='PLAIN_AXES', size=0.3)
        if o:
            made.append((marker, "prop", o))

    # ladles are held, so mark the hand that carries them
    for rig_name, marker in (("PSXRig_server", "prop_ladle_server"),
                             ("PSXRig_cook", "prop_ladle_cook")):
        r = bpy.data.objects.get(rig_name)
        if not r:
            continue
        p = r.matrix_world @ r.pose.bones["mixamorig:RightHand"].head
        o = put(marker, (p.x, p.y), round(p.z, 3), face_of(r),
                style='PLAIN_AXES', size=0.2)
        if o:
            made.append((marker, "prop", o))

    # ---- THE ROUTE: start, each step, exit ------------------------------------
    # already authored by build_chowhall_loop; re-snap them to the real stations
    q = sorted([o for o in coll().all_objects if o.name.startswith("work_queue")],
               key=lambda x: x.name)
    if q:
        p = q[-1].matrix_world.translation
        put("line_start", (p.x, p.y), GROUND, 90.0)
    serves = sorted([o for o in coll().all_objects if o.name.startswith("work_chow_diner")
                     and not o.name.startswith("work_chow_server")], key=lambda x: x.name)
    for i, s in enumerate(serves):
        p = s.matrix_world.translation
        put("line_step_%d" % (i + 1), (p.x, p.y), GROUND, 0.0)
    if serves:
        p = serves[-1].matrix_world.translation
        put("line_exit", (p.x + 0.95, p.y), GROUND, -90.0)

    bpy.context.view_layer.update()

    print("=== chow hall markers ===")
    for kind in ("man", "prop"):
        print("  -- %s --" % kind)
        for nm, k, o in made:
            if k != kind:
                continue
            w = o.matrix_world.translation
            print("     %-24s (%6.2f,%8.2f,%5.2f)  facing %6.1f"
                  % (nm, w.x, w.y, w.z, math.degrees(o.rotation_euler.z)))

    fam = {}
    for o in coll().all_objects:
        if o.type != 'EMPTY':
            continue
        import re
        fam.setdefault(re.sub(r"\.\d+$", "", o.name), 0)
        fam[re.sub(r"\.\d+$", "", o.name)] += 1
    print("\n  -- full marker census --")
    for k in sorted(fam):
        print("     %-24s x%d" % (k, fam[k]))
    print("\n  total empties in %s: %d"
          % (COLL, len([o for o in coll().all_objects if o.type == 'EMPTY'])))


main()
