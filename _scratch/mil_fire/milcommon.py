"""Shared rig for the CoD/MoH-style military fire pack.

Engine note: this pack renders in CYCLES, not Eevee. Measured on this machine
(no GPU, 12 logical cores): one 128x128 volume frame took 90.1s in Eevee at
raised volumetric quality versus 2.6s in Cycles. The spec's own fallback clause
applies -- Eevee is not viable for volume work here.

Blender 5.0 gotcha: the stock `quick_smoke` volume material ships with
Blackbody Intensity = 0.0, so fire emits nothing and the render comes back pure
black. Every fire material below sets it explicitly.
"""
import bpy, os, math, random, time

PACK = r"C:\Users\caleb\RECONgame\assets\textures\military_fire_pack"
FRAMES = os.path.join(PACK, "frames")
SHEETS = os.path.join(PACK, "sheets")
# Fluid caches are huge and regenerable -- keep them off the project disk.
CACHE_ROOT = r"D:\recon_fluid_cache"
BLENDS = r"D:\recon_fluid_cache\blends"


def ensure_dirs():
    for d in (PACK, FRAMES, SHEETS, CACHE_ROOT, BLENDS):
        os.makedirs(d, exist_ok=True)


# --------------------------------------------------------------- rendering ---
def setup_cycles(res_x, res_y, samples=48, denoise=True):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = samples
    sc.cycles.use_adaptive_sampling = True
    sc.cycles.adaptive_threshold = 0.02
    sc.cycles.use_denoising = denoise
    sc.cycles.max_bounces = 4
    sc.cycles.volume_bounces = 2
    sc.cycles.transparent_max_bounces = 16
    # Coarser volume stepping: at 256px tiles the fine steps buy nothing you
    # can see, and step rate is the dominant term in volume render cost.
    sc.cycles.volume_step_rate = 0.85
    sc.cycles.volume_max_steps = 512
    sc.render.resolution_x = res_x
    sc.render.resolution_y = res_y
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.use_motion_blur = False
    # Photographic look: keep the filter, this pack is NOT posterised.
    sc.render.filter_size = 1.5
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    sc.render.image_settings.color_depth = '8'
    sc.view_settings.view_transform = 'Standard'
    sc.view_settings.look = 'None'
    return sc


def ortho_cam_side(ortho_scale, loc=(0.0, -12.0, 2.0)):
    cd = bpy.data.cameras.new("VFXCam")
    cd.type = 'ORTHO'
    cd.ortho_scale = ortho_scale
    cam = bpy.data.objects.new("VFXCam", cd)
    bpy.context.collection.objects.link(cam)
    cam.location = loc
    cam.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    bpy.context.scene.camera = cam
    return cam


def soft_key_light(energy=300.0, loc=(-6.0, -8.0, 6.0)):
    """Smoke is black without something to scatter. A single soft key gives the
    soot volume and form instead of a flat silhouette."""
    ld = bpy.data.lights.new("Key", type='AREA')
    ld.energy = energy
    ld.size = 8.0
    ld.color = (0.85, 0.88, 1.0)
    lo = bpy.data.objects.new("Key", ld)
    bpy.context.collection.objects.link(lo)
    lo.location = loc
    lo.rotation_euler = (math.radians(55.0), 0.0, math.radians(-35.0))
    return lo


def set_world(strength=0.05, color=(0.35, 0.38, 0.45)):
    w = bpy.data.worlds.new("W")
    w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    bg.inputs['Color'].default_value = (*color, 1.0)
    bg.inputs['Strength'].default_value = strength
    bpy.context.scene.world = w
    return w


# ---------------------------------------------------------------- material ---
def fire_volume_material(name, density=6.0, smoke_color=(0.035, 0.032, 0.030),
                         blackbody=1.35, temperature=1650.0, emission_strength=0.0):
    """Realistic sooty fire: dark absorbing smoke + blackbody flame in ONE
    volume, so the soot is baked into the flame frames as the spec requires."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    pv = nt.nodes.new('ShaderNodeVolumePrincipled')
    pv.location = (-320, 0)
    pv.inputs['Density'].default_value = density
    pv.inputs['Density Attribute'].default_value = "density"
    pv.inputs['Color'].default_value = (*smoke_color, 1.0)
    pv.inputs['Anisotropy'].default_value = 0.25
    pv.inputs['Blackbody Intensity'].default_value = blackbody   # 0.0 by default in 5.0!
    pv.inputs['Temperature'].default_value = temperature
    pv.inputs['Temperature Attribute'].default_value = "temperature"
    pv.inputs['Emission Strength'].default_value = emission_strength
    nt.links.new(pv.outputs['Volume'], out.inputs['Volume'])
    return mat, pv


def smoke_volume_material(name, density=9.0, color=(0.055, 0.05, 0.045)):
    mat, pv = fire_volume_material(name, density=density, smoke_color=color,
                                   blackbody=0.0, temperature=0.0)
    return mat, pv


# --------------------------------------------------------------------- sim ---
def make_pile(name="Emitter", rx=1.3, ry=1.1, rz=0.42, seed=7, jitter=0.22):
    """Low irregular rubble-pile emitter."""
    rnd = random.Random(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=(0, 0, 0))
    ob = bpy.context.active_object
    ob.name = name
    for v in ob.data.vertices:
        v.co.x *= rx * (1.0 + rnd.uniform(-jitter, jitter))
        v.co.y *= ry * (1.0 + rnd.uniform(-jitter, jitter))
        v.co.z *= rz * (1.0 + rnd.uniform(-jitter, jitter))
        if v.co.z < 0.0:
            v.co.z *= 0.25          # flatten the underside into a pile
    ob.data.update()
    return ob


def all_fcurves(obj):
    """Yield every fcurve on an object's action.

    Blender 4.4+ moved actions to layers/strips/channelbags and `action.fcurves`
    is no longer populated for them, so both layouts have to be walked.
    """
    ad = getattr(obj, "animation_data", None)
    if not ad or not ad.action:
        return
    act = ad.action
    layers = getattr(act, "layers", None)
    if layers:
        for layer in layers:
            for strip in layer.strips:
                for cbag in getattr(strip, "channelbags", []):
                    for fc in cbag.fcurves:
                        yield fc
    else:
        for fc in act.fcurves:
            yield fc


def step_boolean_keys(obj):
    """Booleans must step, never interpolate."""
    n = 0
    for fc in all_fcurves(obj):
        for kp in fc.keyframe_points:
            kp.interpolation = 'CONSTANT'
            n += 1
    print("  stepped %d keyframes on %s" % (n, obj.name))
    return n


def bake_domain(dom, label=""):
    t0 = time.time()
    ctx = bpy.context.copy()
    ctx['object'] = dom
    ctx['active_object'] = dom
    ctx['scene'] = bpy.context.scene
    with bpy.context.temp_override(**ctx):
        bpy.ops.fluid.bake_all()
    dt = time.time() - t0
    print("BAKE_OK %s %.1fs" % (label, dt))
    return dt


def cache_size_mb(path):
    tot = 0
    for root, _dirs, files in os.walk(path):
        for f in files:
            try:
                tot += os.path.getsize(os.path.join(root, f))
            except OSError:
                pass
    return tot / (1024.0 * 1024.0)


# ------------------------------------------------------------------ output ---
def render_frames(out_dir, prefix, frames):
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    written = []
    t0 = time.time()
    for i, f in enumerate(frames):
        sc.frame_set(f)
        p = os.path.join(out_dir, "%s%03d.png" % (prefix, i))
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        written.append(p)
        print("  frame %d/%d (scene %d) %.1fs elapsed" % (i + 1, len(frames), f, time.time() - t0))
    return written


def _load_px(path, cell_w, cell_h):
    img = bpy.data.images.load(path)
    assert tuple(img.size) == (cell_w, cell_h), \
        "%s is %s, expected %dx%d" % (path, tuple(img.size), cell_w, cell_h)
    px = list(img.pixels[:])
    bpy.data.images.remove(img)
    return px


def check_border_clear(frames, cell_w, cell_h, label="", alpha_eps=0.03):  # noqa: D401
    """Refuse frames whose content touches the tile border.

    A sprite frame with opaque pixels on its edge renders in-engine as an
    effect with its top (or side) sliced flat -- there is no engine setting
    that can undo it, because the pixels are cut in the texture itself. The
    first pass of this pack shipped four sheets like that (fire_core 16/16,
    fire_loop 15/16, mortar 9/16, smoke 6/16) because the brief said to fill
    ~90% of frame and that was followed literally. This is the gate that stops
    the whole bug class rather than those four instances.
    """
    offenders = []
    for i, px in enumerate(frames):
        hits = 0
        for x in range(cell_w):
            if px[((0) * cell_w + x) * 4 + 3] > alpha_eps:
                hits += 1
            if px[((cell_h - 1) * cell_w + x) * 4 + 3] > alpha_eps:
                hits += 1
        for y in range(cell_h):
            if px[(y * cell_w + 0) * 4 + 3] > alpha_eps:
                hits += 1
            if px[(y * cell_w + cell_w - 1) * 4 + 3] > alpha_eps:
                hits += 1
        if hits:
            offenders.append((i, hits))
    if offenders:
        worst = max(o[1] for o in offenders)
        raise AssertionError(
            "BORDER_CLIP %s: %d/%d frames touch the tile edge (worst %d px). "
            "Widen the camera / raise the domain and re-render; do NOT ship."
            % (label, len(offenders), len(frames), worst))
    print("BORDER_OK %s: 0/%d frames touch the tile edge" % (label, len(frames)))


def pack_sheet(frame_paths, cols, rows, cell_w, cell_h, out_path, crossfade=0):
    """Grid-pack frames into one sheet.

    crossfade > 0 blends the final N frames toward frame 0, which hides the
    loop seam when the sim's first and last sampled frames don't quite match.
    """
    n = cols * rows
    frames = [_load_px(p, cell_w, cell_h) for p in frame_paths[:n]]
    check_border_clear(frames, cell_w, cell_h, os.path.basename(out_path))

    if crossfade > 0 and len(frames) > crossfade:
        first = frames[0]
        for k in range(crossfade):
            idx = len(frames) - crossfade + k
            # k=0 -> barely blended, k=crossfade-1 -> mostly frame 0
            t = (k + 1) / float(crossfade + 1)
            cur = frames[idx]
            frames[idx] = [cur[i] * (1.0 - t) + first[i] * t for i in range(len(cur))]

    sheet_w, sheet_h = cols * cell_w, rows * cell_h
    name = os.path.basename(out_path)
    if name in bpy.data.images:
        bpy.data.images.remove(bpy.data.images[name])
    sheet = bpy.data.images.new(name, width=sheet_w, height=sheet_h, alpha=True)
    buf = [0.0] * (sheet_w * sheet_h * 4)

    for idx, px in enumerate(frames):
        col, row = idx % cols, idx // cols
        # Blender images are bottom-up; grid row 0 must land at the TOP.
        y_off = sheet_h - (row + 1) * cell_h
        x_off = col * cell_w
        for y in range(cell_h):
            s = y * cell_w * 4
            d = ((y_off + y) * sheet_w + x_off) * 4
            buf[d:d + cell_w * 4] = px[s:s + cell_w * 4]

    sheet.pixels = buf
    sheet.file_format = 'PNG'
    sheet.alpha_mode = 'STRAIGHT'
    sheet.filepath_raw = out_path
    sheet.save()
    print("SHEET %s  %dx%d  (%dx%d grid, %d frames, crossfade=%d)"
          % (out_path, sheet_w, sheet_h, cols, rows, len(frames), crossfade))
    return out_path


def describe(path, label=""):
    """Coarse numeric read of a frame so it can be judged without eyeballing."""
    img = bpy.data.images.load(path)
    w, h = img.size
    px = img.pixels[:]
    n = w * h
    lit = bright = 0
    amax = 0.0
    lum_sum = 0.0
    hot = 0
    for i in range(0, len(px), 4):
        a = px[i + 3]
        if a > 0.02:
            lit += 1
            amax = max(amax, a)
            lum = 0.2126 * px[i] + 0.7152 * px[i + 1] + 0.0722 * px[i + 2]
            lum_sum += lum
            if lum > 0.75:
                hot += 1
            if lum > 0.25:
                bright += 1
    print("DESC %s%s %dx%d  coverage=%.1f%%  max_alpha=%.2f  mean_lum=%.3f  bright=%.1f%%  hotcore=%.1f%%"
          % (label, os.path.basename(path), w, h, 100.0 * lit / n, amax,
             lum_sum / max(lit, 1), 100.0 * bright / max(lit, 1), 100.0 * hot / max(lit, 1)))
    prof = []
    for seg in range(8):
        y0, y1 = seg * h // 8, (seg + 1) * h // 8
        c = sum(1 for y in range(y0, y1) for x in range(w) if px[((y * w) + x) * 4 + 3] > 0.02)
        prof.append(round(100.0 * c / max((y1 - y0) * w, 1)))
    print("     alpha bottom->top: %s" % prof)
    bpy.data.images.remove(img)
