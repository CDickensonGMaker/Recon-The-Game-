"""Shared helpers for the retro fire VFX pack (PS1 / early-2000s style).

Everything renders through Eevee with a transparent film and a Standard view
transform so the posterised colour bands survive to the PNG untouched.
"""
import os
import math
import bpy

ROOT = r"C:\Users\caleb\RECONgame\assets\textures\retro_fire_pack"
FRAMES = os.path.join(ROOT, "frames")
SHEETS = os.path.join(ROOT, "sheets")

# Classic fire ramp, darkest -> hottest. Alpha rides along so one ramp drives
# both colour and cutout.
FIRE_STOPS = [
    (0.00, (0.00, 0.00, 0.00, 0.00)),   # nothing
    (0.18, (0.09, 0.04, 0.02, 1.00)),   # smoke brown/black
    (0.34, (0.55, 0.05, 0.02, 1.00)),   # deep red
    (0.52, (0.95, 0.28, 0.02, 1.00)),   # orange
    (0.72, (1.00, 0.72, 0.10, 1.00)),   # yellow
    (0.88, (1.00, 0.98, 0.86, 1.00)),   # near-white core
]

SMOKE_STOPS = [
    (0.00, (0.00, 0.00, 0.00, 0.00)),
    (0.22, (0.10, 0.08, 0.06, 1.00)),
    (0.50, (0.20, 0.17, 0.14, 1.00)),
    (0.75, (0.34, 0.30, 0.25, 1.00)),
]


def ensure_dirs():
    for d in (ROOT, FRAMES, SHEETS):
        os.makedirs(d, exist_ok=True)


def wipe_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def setup_render(res_x, res_y, transparent=True):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE'
    sc.render.resolution_x = res_x
    sc.render.resolution_y = res_y
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = transparent
    # No reconstruction filter and a single TAA sample: any averaging at all
    # blends the posterised bands into each other and kills the retro look.
    sc.render.filter_size = 0.0
    sc.render.dither_intensity = 0.0
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    sc.render.image_settings.color_depth = '8'
    sc.render.image_settings.compression = 15
    sc.view_settings.view_transform = 'Standard'
    sc.view_settings.look = 'None'
    sc.display_settings.display_device = 'sRGB'
    ee = sc.eevee
    for attr, val in (("use_bloom", False), ("use_gtao", False),
                      ("use_motion_blur", False), ("use_raytracing", False)):
        if hasattr(ee, attr):
            setattr(ee, attr, val)
    if hasattr(sc.render, "use_motion_blur"):
        sc.render.use_motion_blur = False
    if hasattr(ee, "taa_render_samples"):
        ee.taa_render_samples = 1
    return sc


def add_ortho_camera(ortho_scale, z=6.0):
    cam_data = bpy.data.cameras.new("VFXCam")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = ortho_scale
    cam = bpy.data.objects.new("VFXCam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = (0.0, 0.0, z)
    cam.rotation_euler = (0.0, 0.0, 0.0)
    bpy.context.scene.camera = cam
    return cam


def add_ortho_camera_side(ortho_scale, y=-8.0, z=0.0):
    """Camera looking along +Y, i.e. a side-on view. Used for the sims."""
    cam_data = bpy.data.cameras.new("VFXCamSide")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = ortho_scale
    cam = bpy.data.objects.new("VFXCamSide", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = (0.0, y, z)
    cam.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    bpy.context.scene.camera = cam
    return cam


def make_constant_ramp(nodes, stops, location=(0, 0)):
    """Colour ramp with CONSTANT interpolation -- the whole retro look."""
    ramp = nodes.new('ShaderNodeValToRGB')
    ramp.location = location
    ramp.color_ramp.interpolation = 'CONSTANT'
    ramp.color_ramp.color_mode = 'RGB'
    # A fresh ramp starts with 2 elements; reuse them, then add the rest.
    els = ramp.color_ramp.elements
    while len(els) > 1:
        els.remove(els[len(els) - 1])
    els[0].position = stops[0][0]
    els[0].color = stops[0][1]
    for pos, col in stops[1:]:
        e = els.new(pos)
        e.color = col
    return ramp


def emissive_cutout(mat, fac_socket, ramp_node, strength=1.0):
    """Wire ramp -> emission colour, ramp alpha -> transparent/emission mix."""
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    for n in list(nodes):
        if n.type in {'BSDF_PRINCIPLED'}:
            nodes.remove(n)
    out = next((n for n in nodes if n.type == 'OUTPUT_MATERIAL'), None)
    if out is None:
        out = nodes.new('ShaderNodeOutputMaterial')
    emis = nodes.new('ShaderNodeEmission')
    emis.location = (300, 100)
    emis.inputs['Strength'].default_value = strength
    trans = nodes.new('ShaderNodeBsdfTransparent')
    trans.location = (300, -100)
    mix = nodes.new('ShaderNodeMixShader')
    mix.location = (520, 0)
    links.new(fac_socket, ramp_node.inputs['Fac'])
    links.new(ramp_node.outputs['Color'], emis.inputs['Color'])
    links.new(ramp_node.outputs['Alpha'], mix.inputs['Fac'])
    links.new(trans.outputs['BSDF'], mix.inputs[1])
    links.new(emis.outputs['Emission'], mix.inputs[2])
    links.new(mix.outputs['Shader'], out.inputs['Surface'])
    mat.blend_method = 'BLEND' if hasattr(mat, 'blend_method') else mat.blend_method
    return emis


def render_still(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def render_range(out_dir, prefix, frames):
    """Render an explicit list of scene frames to out_dir/prefix####.png."""
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    written = []
    for i, f in enumerate(frames):
        sc.frame_set(f)
        p = os.path.join(out_dir, "%s%04d.png" % (prefix, i))
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        written.append(p)
    return written


def pack_sheet(frame_paths, cols, rows, cell_w, cell_h, out_path):
    """Copy each frame's pixel block into one sprite sheet image and save it."""
    sheet_w, sheet_h = cols * cell_w, rows * cell_h
    name = os.path.basename(out_path)
    if name in bpy.data.images:
        bpy.data.images.remove(bpy.data.images[name])
    sheet = bpy.data.images.new(name, width=sheet_w, height=sheet_h, alpha=True)
    buf = [0.0] * (sheet_w * sheet_h * 4)

    for idx, fp in enumerate(frame_paths):
        if idx >= cols * rows:
            break
        img = bpy.data.images.load(fp)
        assert img.size[0] == cell_w and img.size[1] == cell_h, \
            "frame %s is %sx%s, expected %sx%s" % (fp, img.size[0], img.size[1], cell_w, cell_h)
        px = list(img.pixels[:])
        col = idx % cols
        row = idx // cols
        # Blender images are bottom-up; row 0 of the grid must be the TOP row.
        y_off = sheet_h - (row + 1) * cell_h
        x_off = col * cell_w
        for y in range(cell_h):
            src = y * cell_w * 4
            dst = ((y_off + y) * sheet_w + x_off) * 4
            buf[dst:dst + cell_w * 4] = px[src:src + cell_w * 4]
        bpy.data.images.remove(img)

    sheet.pixels = buf
    sheet.file_format = 'PNG'
    sheet.alpha_mode = 'STRAIGHT'
    sheet.filepath_raw = out_path
    sheet.save()
    print("SHEET %s %dx%d (%dx%d grid)" % (out_path, sheet_w, sheet_h, cols, rows))
    return out_path


def report(path):
    """Print a coarse description of a rendered PNG so it can be eyeballed."""
    img = bpy.data.images.load(path)
    w, h = img.size
    px = img.pixels[:]
    opaque = 0
    bands = {}
    for i in range(0, len(px), 4):
        a = px[i + 3]
        if a > 0.5:
            opaque += 1
            key = (round(px[i], 2), round(px[i + 1], 2), round(px[i + 2], 2))
            bands[key] = bands.get(key, 0) + 1
    total = w * h
    print("REPORT %s  %dx%d  coverage=%.1f%%  distinct_colours=%d"
          % (os.path.basename(path), w, h, 100.0 * opaque / total, len(bands)))
    for c, n in sorted(bands.items(), key=lambda kv: -kv[1])[:8]:
        print("   band rgb%s  %.1f%% of opaque" % (c, 100.0 * n / max(opaque, 1)))
    # Row coverage profile, bottom -> top, in eighths.
    prof = []
    for seg in range(8):
        y0, y1 = seg * h // 8, (seg + 1) * h // 8
        cnt = sum(1 for y in range(y0, y1) for x in range(w)
                  if px[((y * w) + x) * 4 + 3] > 0.5)
        prof.append(round(100.0 * cnt / max((y1 - y0) * w, 1)))
    print("   alpha profile bottom->top (%%): %s" % prof)
    bpy.data.images.remove(img)
