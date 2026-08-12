"""Assets 7, 8, 9 -- the three static images. No sim, no Cycles.

fire_glow.png and ember.png are written pixel-by-pixel rather than rendered:
a rendered radial falloff picks up sampling noise and a faint edge, and the
spec is explicit that there must be no hard edge anywhere. Image pixels in
Blender are LINEAR and PNG save applies the sRGB encode, so writing the
intended linear falloff round-trips correctly when the engine decodes it.

haze_noise.png IS rendered, because it needs a real Noise Texture. It wraps
both axes onto a 4D torus so the tiling is structural, not patched up after.
"""
import bpy, sys, os, math
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import milcommon as M

TAU = math.pi * 2.0


def write_image(name, size, fn):
    path = os.path.join(M.SHEETS, name)
    if name in bpy.data.images:
        bpy.data.images.remove(bpy.data.images[name])
    img = bpy.data.images.new(name, width=size, height=size, alpha=True)
    buf = [0.0] * (size * size * 4)
    for y in range(size):
        # pixel centres, mapped to -1..1
        v = (y + 0.5) / size * 2.0 - 1.0
        for x in range(size):
            u = (x + 0.5) / size * 2.0 - 1.0
            r, g, b, a = fn(u, v)
            i = (y * size + x) * 4
            buf[i:i + 4] = [r, g, b, a]
    img.pixels = buf
    img.file_format = 'PNG'
    img.alpha_mode = 'STRAIGHT'
    img.filepath_raw = path
    img.save()
    print("WROTE %s %dx%d" % (path, size, size))
    return path


def smoothstep(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


# ------------------------------------------------- Asset 7: fire_glow.png ---
def glow(u, v):
    r = math.hypot(u, v)
    s = smoothstep(1.0 - r) ** 1.15     # 0 at the rim, zero-slope both ends
    if s <= 0.0:
        return (0.0, 0.0, 0.0, 0.0)
    k = s ** 0.75                        # colour blend: hotter toward centre
    cr = 1.00
    cg = 0.34 + (0.88 - 0.34) * k
    cb = 0.06 + (0.62 - 0.06) * k
    return (cr * s, cg * s, cb * s, s)


# ----------------------------------------------------- Asset 8: ember.png ---
def ember(u, v):
    r = math.hypot(u, v) / 0.85          # dot fills most of the 32px tile
    s = smoothstep(1.0 - r) ** 2.0
    if s <= 0.0:
        return (0.0, 0.0, 0.0, 0.0)
    k = s ** 0.5
    cr = 1.00
    cg = 0.50 + (0.96 - 0.50) * k
    cb = 0.14 + (0.88 - 0.14) * k
    return (cr * s, cg * s, cb * s, s)


# ------------------------------------------------ Asset 9: haze_noise.png ---
def build_haze():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE'
    sc.render.resolution_x = sc.render.resolution_y = 256
    sc.render.film_transparent = False
    sc.render.filter_size = 0.6
    sc.eevee.taa_render_samples = 1
    sc.view_settings.view_transform = 'Standard'
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'

    me = bpy.data.meshes.new("P")
    me.from_pydata([(-1, -1, 0), (1, -1, 0), (1, 1, 0), (-1, 1, 0)], [], [(0, 1, 2, 3)])
    me.update()
    ob = bpy.data.objects.new("P", me)
    bpy.context.collection.objects.link(ob)

    cd = bpy.data.cameras.new("C"); cd.type = 'ORTHO'; cd.ortho_scale = 2.0
    cam = bpy.data.objects.new("C", cd); bpy.context.collection.objects.link(cam)
    cam.location = (0, 0, 5); sc.camera = cam

    mat = bpy.data.materials.new("Haze"); mat.use_nodes = True
    ob.data.materials.append(mat)
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    for n in list(nodes):
        if n.type == 'BSDF_PRINCIPLED':
            nodes.remove(n)
    outn = next(n for n in nodes if n.type == 'OUTPUT_MATERIAL')

    tc = nodes.new('ShaderNodeTexCoord')
    sep = nodes.new('ShaderNodeSeparateXYZ')
    links.new(tc.outputs['Generated'], sep.inputs['Vector'])

    def m(op, a=None, b=None, clamp=False):
        n = nodes.new('ShaderNodeMath'); n.operation = op; n.use_clamp = clamp
        for i, val in enumerate((a, b)):
            if val is None:
                continue
            if hasattr(val, 'is_output'):
                links.new(val, n.inputs[i])
            else:
                n.inputs[i].default_value = val
        return n.outputs[0]

    # Both axes onto a torus in 4D -> exact tiling in X and Y.
    R = 1.0 / TAU
    au = m('MULTIPLY', sep.outputs['X'], TAU)
    av = m('MULTIPLY', sep.outputs['Y'], TAU)
    x = m('MULTIPLY', m('COSINE', au), R)
    y = m('MULTIPLY', m('SINE', au), R)
    z = m('MULTIPLY', m('COSINE', av), R)
    w4 = m('MULTIPLY', m('SINE', av), R)

    comb = nodes.new('ShaderNodeCombineXYZ')
    links.new(x, comb.inputs['X']); links.new(y, comb.inputs['Y']); links.new(z, comb.inputs['Z'])

    noise = nodes.new('ShaderNodeTexNoise')
    noise.noise_dimensions = '4D'
    noise.inputs['Scale'].default_value = 6.0
    noise.inputs['Detail'].default_value = 3.0
    noise.inputs['Roughness'].default_value = 0.45
    links.new(comb.outputs['Vector'], noise.inputs['Vector'])
    links.new(w4, noise.inputs['W'])

    # Smooth medium ripples want contrast, but must stay soft -- no clipping.
    mr = nodes.new('ShaderNodeMapRange'); mr.clamp = True
    mr.inputs['From Min'].default_value = 0.32
    mr.inputs['From Max'].default_value = 0.68
    mr.inputs['To Min'].default_value = 0.05
    mr.inputs['To Max'].default_value = 0.95
    links.new(noise.outputs['Fac'], mr.inputs['Value'])

    emis = nodes.new('ShaderNodeEmission')
    links.new(mr.outputs['Result'], emis.inputs['Color'])
    links.new(emis.outputs['Emission'], outn.inputs['Surface'])

    out = os.path.join(M.SHEETS, "haze_noise.png")
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)

    img = bpy.data.images.load(out)
    w, h, px = img.size[0], img.size[1], img.pixels[:]
    lo = min(px[i] for i in range(0, len(px), 4))
    hi = max(px[i] for i in range(0, len(px), 4))
    mean = sum(px[i] for i in range(0, len(px), 4)) / (w * h)
    sx = max(abs(px[(yy * w) * 4] - px[(yy * w + w - 1) * 4]) for yy in range(h))
    sy = max(abs(px[xx * 4] - px[((h - 1) * w + xx) * 4]) for xx in range(w))
    print("HAZE range %.3f..%.3f mean %.3f  seam X=%.3f Y=%.3f" % (lo, hi, mean, sx, sy))
    bpy.data.images.remove(img)


if __name__ == "__main__":
    mode = sys.argv[-1]
    if mode not in ("glow", "ember", "haze"):
        mode = "all"
    M.ensure_dirs()
    if mode in ("glow", "all"):
        M.describe(write_image("fire_glow.png", 128, glow), "glow  ")
    if mode in ("ember", "all"):
        M.describe(write_image("ember.png", 32, ember), "ember ")
    if mode in ("haze", "all"):
        build_haze()
    print("STATIC_DONE")
