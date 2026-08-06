"""Render each zombie to a PNG for review.

    blender -b -P tools/render_zombie_sheet.py

One front-on portrait per unit into _scratch/zombie_renders/. EEVEE, three-point
lit, transparent background so the sheet composites cleanly.

The renders are REVIEW OUTPUT, not game assets - they go to _scratch, never into
assets/ (his standing rule that reference material is not a ship asset).
"""
import glob
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recon_paths import ROOT, ZOMBIE_DIR

OUT_DIR = os.path.join(ROOT, "_scratch", "zombie_renders")
RES = (520, 820)
SAMPLES = 24


def _clear_non_rig():
    for o in [o for o in bpy.data.objects if o.type in ('CAMERA', 'LIGHT')]:
        bpy.data.objects.remove(o, do_unlink=True)


def _body_bounds():
    """The LIVE body only - gib donors sit off to the side and would wreck framing."""
    mn = Vector((1e9,) * 3)
    mx = Vector((-1e9,) * 3)
    dg = bpy.context.evaluated_depsgraph_get()
    for o in bpy.data.objects:
        if o.type != 'MESH' or not o.name.endswith("_joined"):
            continue
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        for v in me.vertices:
            w = ev.matrix_world @ v.co
            mn = Vector(map(min, mn, w))
            mx = Vector(map(max, mx, w))
        ev.to_mesh_clear()
    return mn, mx


def _light(name, loc, energy, size=3.0):
    d = bpy.data.lights.new(name, type='AREA')
    d.energy = energy
    d.size = size
    ob = bpy.data.objects.new(name, d)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    return ob


def _aim(ob, at):
    d = (at - ob.location)
    ob.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()


def render_one(blend_path, out_png):
    bpy.ops.wm.open_mainfile(filepath=blend_path)
    _clear_non_rig()

    # Splayed gib donors are parked away from the body; hide them or they float
    # around the portrait like spare parts.
    for o in bpy.data.objects:
        if o.type == 'MESH' and not o.name.endswith("_joined"):
            o.hide_render = True

    mn, mx = _body_bounds()
    if mn.x > 1e8:
        print("  no body in %s - skipped" % os.path.basename(blend_path))
        return False
    centre = (mn + mx) * 0.5
    height = max(0.5, mx.z - mn.z)

    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = height * 1.18
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    # In Blender these units face -Y, so the camera stands on -Y looking back.
    cam.location = Vector((centre.x, centre.y - 6.0, centre.z))
    _aim(cam, centre)
    bpy.context.scene.camera = cam

    _light("Key", Vector((centre.x - 2.2, centre.y - 3.4, centre.z + 2.4)), 420.0)
    _light("Fill", Vector((centre.x + 2.8, centre.y - 2.6, centre.z + 0.7)), 130.0)
    _light("Rim", Vector((centre.x + 0.6, centre.y + 3.2, centre.z + 2.6)), 320.0)
    for n in ("Key", "Fill", "Rim"):
        _aim(bpy.data.objects[n], centre)

    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE_NEXT'
    try:
        sc.eevee.taa_render_samples = SAMPLES
    except Exception:
        pass
    sc.render.resolution_x, sc.render.resolution_y = RES
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    sc.render.filepath = out_png
    bpy.ops.render.render(write_still=True)
    return True


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    blends = sorted(glob.glob(os.path.join(ZOMBIE_DIR, "zed_*.blend")))
    if not blends:
        sys.exit("no zed_*.blend in %s" % ZOMBIE_DIR)
    done = 0
    for b in blends:
        name = os.path.splitext(os.path.basename(b))[0]
        out = os.path.join(OUT_DIR, name + ".png")
        if render_one(b, out):
            done += 1
            print("  rendered %s" % name, flush=True)
    print("rendered %d/%d -> %s" % (done, len(blends), OUT_DIR))


if __name__ == "__main__":
    main()
