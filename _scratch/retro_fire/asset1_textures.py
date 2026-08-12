"""Asset 1 -- scrolling flame textures: fire_gradient.png + fire_noise.png.

Both are baked by rendering a procedural emission plane through a fixed ortho
camera. Seamlessness is structural, not fixed up afterwards: the U axis is
wrapped onto a circle before it enters the noise, so the left and right edges
sample literally the same point. fire_noise goes one step further and wraps
both axes onto a torus using 4D noise.
"""
import sys, os, math
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import bpy
import common as C

TAU = math.pi * 2.0

C.ensure_dirs()


def make_plane(name, half_x, half_y):
    me = bpy.data.meshes.new(name)
    me.from_pydata(
        [(-half_x, -half_y, 0), (half_x, -half_y, 0),
         (half_x, half_y, 0), (-half_x, half_y, 0)],
        [], [(0, 1, 2, 3)])
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob


def uv_sockets(nodes, links):
    """Return (u, v) value sockets from Generated coords, 0..1 across the plane."""
    tc = nodes.new('ShaderNodeTexCoord'); tc.location = (-1400, 0)
    sep = nodes.new('ShaderNodeSeparateXYZ'); sep.location = (-1220, 0)
    links.new(tc.outputs['Generated'], sep.inputs['Vector'])
    return sep.outputs['X'], sep.outputs['Y']


def m(nodes, links, op, a=None, b=None, c=None, loc=(0, 0), clamp=False):
    n = nodes.new('ShaderNodeMath')
    n.operation = op
    n.use_clamp = clamp
    n.location = loc
    for i, v in enumerate((a, b, c)):
        if v is None:
            continue
        if hasattr(v, 'is_output'):
            links.new(v, n.inputs[i])
        else:
            n.inputs[i].default_value = v
    return n.outputs[0]


# ---------------------------------------------------------------- gradient ---
def build_gradient():
    C.wipe_scene()
    C.setup_render(128, 256)
    C.add_ortho_camera(2.0)
    ob = make_plane("GradPlane", 0.5, 1.0)

    mat = bpy.data.materials.new("FireGradient")
    mat.use_nodes = True
    ob.data.materials.append(mat)
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    u, v = uv_sockets(nodes, links)

    # U -> circle, so x=0 and x=1 land on the same noise sample.
    ang = m(nodes, links, 'MULTIPLY', u, TAU, loc=(-1040, 200))
    R = 0.42
    cx = m(nodes, links, 'MULTIPLY', m(nodes, links, 'COSINE', ang, loc=(-880, 300)), R, loc=(-720, 300))
    cy = m(nodes, links, 'MULTIPLY', m(nodes, links, 'SINE', ang, loc=(-880, 160)), R, loc=(-720, 160))
    vz = m(nodes, links, 'MULTIPLY', v, 1.30, loc=(-720, 20))

    comb = nodes.new('ShaderNodeCombineXYZ'); comb.location = (-560, 200)
    links.new(cx, comb.inputs['X']); links.new(cy, comb.inputs['Y']); links.new(vz, comb.inputs['Z'])

    noise = nodes.new('ShaderNodeTexNoise'); noise.location = (-400, 200)
    noise.noise_dimensions = '3D'
    noise.inputs['Scale'].default_value = 2.6
    noise.inputs['Detail'].default_value = 2.0
    noise.inputs['Roughness'].default_value = 0.55
    links.new(comb.outputs['Vector'], noise.inputs['Vector'])

    # 4 flame tongues -- integer period keeps the horizontal tiling exact.
    tong = m(nodes, links, 'COSINE', m(nodes, links, 'MULTIPLY', u, TAU * 4.0, loc=(-1040, -120)), loc=(-880, -120))
    tong = m(nodes, links, 'MULTIPLY_ADD', tong, 0.5, 0.5, loc=(-720, -120))

    # height = how far up the flame reaches at this u
    h = m(nodes, links, 'MULTIPLY_ADD', tong, 0.40, 0.34, loc=(-220, -120))
    wob = m(nodes, links, 'MULTIPLY', m(nodes, links, 'SUBTRACT', noise.outputs['Fac'], 0.5, loc=(-220, 60)), 0.70, loc=(-60, 60))
    h = m(nodes, links, 'ADD', h, wob, loc=(100, -60))
    h = m(nodes, links, 'MAXIMUM', h, 0.06, loc=(260, -60))

    # 1 at the bottom edge everywhere, 0 at the tongue tip -> solid hot base.
    inten = m(nodes, links, 'SUBTRACT', 1.0, m(nodes, links, 'DIVIDE', v, h, loc=(420, 0)), loc=(580, 0), clamp=True)

    ramp = C.make_constant_ramp(nodes, C.FIRE_STOPS, location=(760, 0))
    C.emissive_cutout(mat, inten, ramp)

    out = os.path.join(C.SHEETS, "fire_gradient.png")
    C.render_still(out)
    C.report(out)

    # Seam check. Posterisation means neighbouring columns legitimately jump a
    # whole band, so an absolute delta proves nothing. Instead compare the
    # wrap pair (col w-1 -> col 0) against the average interior neighbour pair:
    # if the wrap is seamless the two numbers sit in the same ballpark.
    img = bpy.data.images.load(out)
    w, hgt, px = img.size[0], img.size[1], img.pixels[:]

    def coldelta(a, b):
        s = 0.0
        for y in range(hgt):
            ia, ib = ((y * w) + a) * 4, ((y * w) + b) * 4
            s += sum(abs(px[ia + c] - px[ib + c]) for c in range(4))
        return s / hgt

    wrap = coldelta(w - 1, 0)
    interior = sum(coldelta(x, x + 1) for x in range(w - 1)) / (w - 1)
    print("SEAM_X wrap=%.4f  interior_mean=%.4f  ratio=%.2f (near 1.0 = seamless)"
          % (wrap, interior, wrap / max(interior, 1e-6)))
    bpy.data.images.remove(img)


# ------------------------------------------------------------------- noise ---
def build_noise():
    C.wipe_scene()
    C.setup_render(128, 128)
    C.add_ortho_camera(2.0)
    ob = make_plane("NoisePlane", 1.0, 1.0)

    mat = bpy.data.materials.new("FireNoise")
    mat.use_nodes = True
    ob.data.materials.append(mat)
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    u, v = uv_sockets(nodes, links)

    # Both axes wrapped onto a torus in 4D -> tiles in X and Y exactly.
    # radius = 1/TAU so one full lap covers exactly 1.0 unit of noise space;
    # the Noise scale of 4 then gives ~4 features per tile as specified.
    R = 1.0 / TAU
    au = m(nodes, links, 'MULTIPLY', u, TAU, loc=(-1040, 240))
    av = m(nodes, links, 'MULTIPLY', v, TAU, loc=(-1040, 40))
    x = m(nodes, links, 'MULTIPLY', m(nodes, links, 'COSINE', au, loc=(-880, 320)), R, loc=(-720, 320))
    y = m(nodes, links, 'MULTIPLY', m(nodes, links, 'SINE', au, loc=(-880, 200)), R, loc=(-720, 200))
    z = m(nodes, links, 'MULTIPLY', m(nodes, links, 'COSINE', av, loc=(-880, 80)), R, loc=(-720, 80))
    w4 = m(nodes, links, 'MULTIPLY', m(nodes, links, 'SINE', av, loc=(-880, -40)), R, loc=(-720, -40))

    comb = nodes.new('ShaderNodeCombineXYZ'); comb.location = (-560, 200)
    links.new(x, comb.inputs['X']); links.new(y, comb.inputs['Y']); links.new(z, comb.inputs['Z'])

    noise = nodes.new('ShaderNodeTexNoise'); noise.location = (-380, 200)
    noise.noise_dimensions = '4D'
    noise.inputs['Scale'].default_value = 4.0
    noise.inputs['Detail'].default_value = 2.0
    noise.inputs['Roughness'].default_value = 0.5
    links.new(comb.outputs['Vector'], noise.inputs['Vector'])
    links.new(w4, noise.inputs['W'])

    nt = mat.node_tree
    for n in list(nodes):
        if n.type == 'BSDF_PRINCIPLED':
            nodes.remove(n)
    outn = next(n for n in nodes if n.type == 'OUTPUT_MATERIAL')
    # Raw Fac only spans ~0.3..0.7; a UV-distortion map wants the full range.
    mr = nodes.new('ShaderNodeMapRange'); mr.location = (-190, 200)
    mr.clamp = True
    mr.inputs['From Min'].default_value = 0.30
    mr.inputs['From Max'].default_value = 0.70
    links.new(noise.outputs['Fac'], mr.inputs['Value'])

    emis = nodes.new('ShaderNodeEmission'); emis.location = (0, 200)
    emis.inputs['Strength'].default_value = 1.0
    links.new(mr.outputs['Result'], emis.inputs['Color'])
    links.new(emis.outputs['Emission'], outn.inputs['Surface'])

    out = os.path.join(C.SHEETS, "fire_noise.png")
    C.render_still(out)

    img = bpy.data.images.load(out)
    w, hgt, px = img.size[0], img.size[1], img.pixels[:]
    lo, hi, tot = 1.0, 0.0, 0.0
    for i in range(0, len(px), 4):
        g = px[i]
        lo, hi, tot = min(lo, g), max(hi, g), tot + g
    print("NOISE range %.3f..%.3f mean %.3f" % (lo, hi, tot / (w * hgt)))
    sx = max(abs(px[(y * w) * 4] - px[(y * w + w - 1) * 4]) for y in range(hgt))
    sy = max(abs(px[x * 4] - px[((hgt - 1) * w + x) * 4]) for x in range(w))
    print("NOISE seam deltas  X=%.3f  Y=%.3f" % (sx, sy))
    bpy.data.images.remove(img)


if __name__ == "__main__":
    which = sys.argv[-1]
    if which in ("gradient", "both"):
        build_gradient()
    if which in ("noise", "both"):
        build_noise()
    print("ASSET1_DONE")
