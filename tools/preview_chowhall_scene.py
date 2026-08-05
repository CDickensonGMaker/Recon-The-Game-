"""Render the whole chow hall workbench - props, tables, seats and the crew running.

    blender -b "<firebase>.blend" -P tools/preview_chowhall_scene.py

Writes _scratch/chow_preview/scene/ : three stills (overhead, line, dining) plus a
turn of frames so the clips read as motion.
"""
import bpy, os, sys, math
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recon_paths import ROOT

OUT = os.path.join(ROOT, "_scratch", "chow_preview", "scene")
CHOW = "WORKBENCH_chowhall"
RIGS = "WORKBENCH_chowhall_rigs"
RES = 900
ANCHOR = Vector((0.0, -240.0, 0.0))

# name, camera position (LOCAL to WB_chowhall), aim point (local), lens
SHOTS = [
    ("overhead", (0.5, -5.0, 11.0), (0.2, -3.2, 0.4), 40),
    ("line",     (-6.2, -6.0, 2.6), (-0.6, -1.2, 1.0), 50),
    ("dining",   (5.2, -9.6, 2.4), (0.0, -5.4, 0.9), 45),
]


def isolate():
    """Hide everything except the chow hall, so the firebase does not fill the frame."""
    keep = set()
    for cn in (CHOW, RIGS):
        c = bpy.data.collections.get(cn)
        if c:
            keep |= set(c.all_objects)
    n = 0
    for o in bpy.data.objects:
        if o.type in {'MESH', 'CURVE', 'SURFACE'} and o not in keep:
            o.hide_render = True
            n += 1
    return len(keep), n


def ground():
    me = bpy.data.meshes.new("ChowGround")
    s = 14.0
    me.from_pydata([(ANCHOR.x - s, ANCHOR.y - s, -0.01), (ANCHOR.x + s, ANCHOR.y - s, -0.01),
                    (ANCHOR.x + s, ANCHOR.y + s, -0.01), (ANCHOR.x - s, ANCHOR.y + s, -0.01)],
                   [], [(0, 1, 2, 3)])
    me.update()
    o = bpy.data.objects.new("ChowGround", me)
    bpy.context.scene.collection.objects.link(o)


def main():
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.render.resolution_x = sc.render.resolution_y = RES
    sc.render.image_settings.file_format = 'PNG'
    sh = sc.display.shading
    sh.light = 'STUDIO'
    sh.color_type = 'TEXTURE'
    sh.show_shadows = True
    sh.show_cavity = True

    kept, hidden = isolate()
    ground()
    print("  chow hall objects kept: %d, hidden elsewhere: %d" % (kept, hidden))

    aim = bpy.data.objects.new("ChowAim", None)
    sc.collection.objects.link(aim)
    cam_d = bpy.data.cameras.new("ChowCam")
    cam = bpy.data.objects.new("ChowCam", cam_d)
    sc.collection.objects.link(cam)
    con = cam.constraints.new('TRACK_TO')
    con.target = aim
    con.track_axis = 'TRACK_NEGATIVE_Z'
    con.up_axis = 'UP_Y'
    sc.camera = cam

    for name, pos, look, lens in SHOTS:
        cam_d.lens = lens
        cam.location = ANCHOR + Vector(pos)
        aim.location = ANCHOR + Vector(look)
        bpy.context.view_layer.update()
        sc.frame_set(1)
        sc.render.filepath = os.path.join(OUT, "%s.png" % name)
        bpy.ops.render.render(write_still=True)
        print("  %s -> %s" % (name, sc.render.filepath))

    # a short turn on the dining shot so the clips read as motion
    cam_d.lens = 45
    cam.location = ANCHOR + Vector((5.2, -9.6, 2.4))
    aim.location = ANCHOR + Vector((0.0, -5.4, 0.9))
    sc.frame_start, sc.frame_end = 1, 60
    sc.render.filepath = os.path.join(OUT, "motion", "f_")
    bpy.ops.render.render(animation=True)
    print("  motion -> %s" % sc.render.filepath)


main()
