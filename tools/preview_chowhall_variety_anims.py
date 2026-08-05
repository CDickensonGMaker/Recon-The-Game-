"""Render the chow hall VARIETY clips on a REAL US grunt v3 body - no helmet, no
gear, no weapon. Same harness as tools/preview_chowhall_anims.py (that file is
scoped to the OTHER agent's five station clips; this one is scoped to
chow_variety_workbench.blend so neither pass's render run touches the other's
workbench).

    blender -b -P tools/preview_chowhall_variety_anims.py

This ALSO doubles as the clean-room QUATERNION-mode verification the invariants
require: US_BASE_V3's own PSXRig_rifleman pose bones arrive in whatever mode
that file uses, not necessarily the QUATERNION mode chow_variety_workbench.blend
authored with, so `pb.rotation_mode = 'QUATERNION'` is forced on every bone
before assigning a clip - the exact bug the 8/3 session lost hours to.
"""
import bpy, os, sys
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recon_paths import ASSETS, ROOT, US_BASE_V3

WORKBENCH = os.path.join(ASSETS, "shared", "chow_variety_workbench.blend")
OUTDIR = os.path.join(ROOT, "_scratch", "chow_variety_preview")
DONOR = "rifleman"
RES, FPS = 720, 30

BODY = ('grunt_torso', 'grunt_head', 'grunt_leg_l', 'grunt_leg_r',
        'grunt_forearm_l', 'grunt_forearm_r', 'grunt_uparm_l', 'grunt_uparm_r',
        'cap_torso', 'cap_head', 'cap_leg_l', 'cap_leg_r',
        'cap_forearm_l', 'cap_forearm_r', 'cap_uparm_l', 'cap_uparm_r')

CLIPS = ["chow_talk_seated_a", "chow_talk_seated_b", "chow_eat_standing",
         "chow_tray_carry_walk", "chow_sit_down", "chow_stand_up"]


def append_clips():
    d = WORKBENCH + os.sep + "Action" + os.sep
    got = []
    for name in CLIPS:
        if bpy.data.actions.get(name):
            got.append(name)
            continue
        try:
            bpy.ops.wm.append(directory=d, filename=name)
        except RuntimeError as ex:
            print("  clip append failed %s: %s" % (name, ex))
            continue
        if bpy.data.actions.get(name):
            got.append(name)
    return got


def setup_scene(rig):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.render.resolution_x = sc.render.resolution_y = RES
    sc.render.resolution_percentage = 100
    sc.render.fps = FPS
    sc.render.image_settings.file_format = 'PNG'
    sh = sc.display.shading
    sh.light = 'STUDIO'
    sh.color_type = 'TEXTURE'
    sh.show_shadows = True
    sh.show_cavity = True

    for n in ("PreviewCam", "PreviewFloor", "PreviewAim"):
        o = bpy.data.objects.get(n)
        if o:
            bpy.data.objects.remove(o, do_unlink=True)

    cam_d = bpy.data.cameras.new("PreviewCam")
    cam_d.lens = 55
    cam = bpy.data.objects.new("PreviewCam", cam_d)
    sc.collection.objects.link(cam)
    aim = bpy.data.objects.new("PreviewAim", None)
    sc.collection.objects.link(aim)
    aim.location = Vector((0.0, 0.0, 1.05))
    cam.location = Vector((1.9, -2.6, 1.55))
    con = cam.constraints.new('TRACK_TO')
    con.target = aim
    con.track_axis = 'TRACK_NEGATIVE_Z'
    con.up_axis = 'UP_Y'
    sc.camera = cam

    me = bpy.data.meshes.new("PreviewFloor")
    me.from_pydata([(-4, -4, 0), (4, -4, 0), (4, 4, 0), (-4, 4, 0)], [], [(0, 1, 2, 3)])
    me.update()
    sc.collection.objects.link(bpy.data.objects.new("PreviewFloor", me))
    return cam


def main():
    bpy.ops.wm.open_mainfile(filepath=US_BASE_V3)
    got = append_clips()
    print("  clips appended: %s" % ", ".join(got))
    rig = bpy.data.objects["PSXRig_%s" % DONOR]

    keep = {"%s_%s" % (b, DONOR) for b in BODY}
    parts, hidden = [], 0
    for o in bpy.data.objects:
        if o.type != 'MESH':
            continue
        if o.name in keep:
            parts.append(o)
        else:
            o.hide_render = True
            hidden += 1
    print("  body parts: %d / %d, other meshes hidden: %d"
          % (len(parts), len(BODY), hidden))

    # THE INVARIANT: a pose bone in EULER mode ignores its quaternion channels.
    for pb in rig.pose.bones:
        pb.rotation_mode = 'QUATERNION'

    cam = setup_scene(rig)

    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in parts for c in o.bound_box]
    if pts:
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        mid = Vector(((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, 0.0))
        aim = bpy.data.objects["PreviewAim"]
        aim.location = mid + Vector((0.0, 0.0, 1.05))
        cam.location = mid + Vector((1.9, -2.6, 1.55))
        bpy.context.view_layer.update()

    if rig.animation_data is None:
        rig.animation_data_create()

    for name in CLIPS:
        act = bpy.data.actions.get(name)
        if act is None:
            print("  MISSING clip", name)
            continue
        rig.animation_data.action = act
        if len(act.slots):
            rig.animation_data.action_slot = act.slots[0]
        f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
        sc = bpy.context.scene
        sc.frame_start, sc.frame_end = f0, f1
        sc.render.filepath = os.path.join(OUTDIR, name, "f_")
        print("  rendering %-22s frames %d-%d -> %s" % (name, f0, f1, sc.render.filepath))
        bpy.ops.render.render(animation=True)

    print("\n  PNGs under", OUTDIR)


main()
