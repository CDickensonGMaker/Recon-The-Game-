"""Asset 5 -- muzzle_flash_sheet.png (8 frames, 8x1, 128x128, ADDITIVE).

No simulation. A bright core plus radiating cone spikes, collapsing over 8
frames. Rendered for additive blending, so what matters is brightness, not
alpha coverage.

One spec conflict resolved deliberately: the brief asks for a smoke wisp on
frames 4-8 AND for frame 8 to be fully transparent. Those cannot both hold, so
the wisp runs 4-7 and frame 8 is left completely empty -- a clean end beats a
one-frame wisp, and a non-empty final frame pops when the one-shot recycles.
"""
import bpy, sys, os, math, random
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import milcommon as M

RES = 128
COLS, ROWS = 8, 1
NFRAMES = 8
FRAME_DIR = os.path.join(M.FRAMES, "asset5_muzzle")

# per-frame (scale, emission strength) -- fast collapse, gone by 8
# Strength is deliberately low: the PNG clips at 1.0, so anything above ~3
# flattens the whole star to a white disc and throws away the orange ramp.
# These values let the core blow out while the spike tips stay orange.
# Strength stays at/below ~1.15. Above that, orange (1.0, 0.44, 0.09) clips its
# green channel upward and the whole flash turns yellow then white -- which is
# exactly what the first two attempts did. Brightness lives in the ramp colours.
CURVE = [
    (1.00, 1.15),
    (0.90, 0.95),
    (0.70, 0.72),
    (0.50, 0.50),
    (0.34, 0.32),
    (0.21, 0.18),
    (0.10, 0.08),
    (0.00, 0.00),
]
WISP = {4: 0.35, 5: 0.45, 6: 0.32, 7: 0.15}   # frame -> wisp density


def flash_material(root):
    mat = bpy.data.materials.new("Flash")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    emis = nt.nodes.new('ShaderNodeEmission'); emis.location = (-200, 0)

    # White-hot at the origin, orange toward the spike tips.
    # Coordinates are taken in the ROOT empty's space. Each cone's own Object
    # coords are local to that cone, which would run the white-hot gradient
    # from every spike's midpoint instead of from the star's centre. Pointing
    # at the root also makes the gradient immune to the root's scale animation.
    tc = nt.nodes.new('ShaderNodeTexCoord'); tc.location = (-900, 0)
    tc.object = root
    length = nt.nodes.new('ShaderNodeVectorMath'); length.operation = 'LENGTH'
    length.location = (-720, -180)
    nt.links.new(tc.outputs['Object'], length.inputs[0])

    ramp = nt.nodes.new('ShaderNodeValToRGB'); ramp.location = (-500, 0)
    ramp.color_ramp.interpolation = 'EASE'
    els = ramp.color_ramp.elements
    els[0].position = 0.0
    els[0].color = (1.00, 0.97, 0.88, 1.0)    # white-hot core
    els[1].position = 0.30
    els[1].color = (1.00, 0.72, 0.30, 1.0)    # hot yellow-orange
    e = els.new(0.60)
    e.color = (1.00, 0.42, 0.08, 1.0)         # orange body
    e = els.new(0.88)
    e.color = (0.70, 0.16, 0.02, 1.0)         # deep orange tip
    # Length now runs 0..~2 (the long lateral flares), but ramp stops live in
    # 0..1, so normalise or everything past the core reads as the tip colour.
    cnorm = nt.nodes.new('ShaderNodeMapRange'); cnorm.location = (-620, 60)
    cnorm.clamp = True
    cnorm.inputs['From Min'].default_value = 0.0
    cnorm.inputs['From Max'].default_value = 1.70
    nt.links.new(length.outputs['Value'], cnorm.inputs['Value'])
    nt.links.new(cnorm.outputs['Result'], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], emis.inputs['Color'])

    # Fade the spikes out toward their tips instead of ending on a hard edge.
    trans = nt.nodes.new('ShaderNodeBsdfTransparent'); trans.location = (-200, -180)
    mix = nt.nodes.new('ShaderNodeMixShader'); mix.location = (0, 0)
    fall = nt.nodes.new('ShaderNodeMapRange'); fall.location = (-500, -260)
    fall.clamp = True
    fall.inputs['From Min'].default_value = 0.55
    fall.inputs['From Max'].default_value = 2.05
    fall.inputs['To Min'].default_value = 1.0
    fall.inputs['To Max'].default_value = 0.0
    nt.links.new(length.outputs['Value'], fall.inputs['Value'])
    nt.links.new(fall.outputs['Result'], mix.inputs['Fac'])
    nt.links.new(trans.outputs['BSDF'], mix.inputs[1])
    nt.links.new(emis.outputs['Emission'], mix.inputs[2])
    nt.links.new(mix.outputs['Shader'], out.inputs['Surface'])
    return mat, emis


def wisp_material(wisp_obj):
    """Faint powder-smoke wisp.

    Scattering albedo is kept near black on purpose: this sheet is ADDITIVE, so
    a wisp lit by the key light renders as a solid white blob and would add a
    bright haze over the barrel in-engine. The visible warmth comes from a weak
    emission term instead, and noise plus a radial falloff break the sphere up
    so it reads as smoke rather than an ellipsoid.
    """
    mat = bpy.data.materials.new("Wisp")
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    for n in list(nodes):
        nodes.remove(n)
    out = nodes.new('ShaderNodeOutputMaterial')
    pv = nodes.new('ShaderNodeVolumePrincipled'); pv.location = (-260, 0)
    pv.inputs['Color'].default_value = (0.02, 0.02, 0.02, 1.0)   # ~no scattering
    pv.inputs['Blackbody Intensity'].default_value = 0.0
    pv.inputs['Emission Color'].default_value = (0.42, 0.33, 0.26, 1.0)
    pv.inputs['Emission Strength'].default_value = 0.22

    tc = nodes.new('ShaderNodeTexCoord'); tc.location = (-1080, 0)
    tc.object = wisp_obj
    ln = nodes.new('ShaderNodeVectorMath'); ln.operation = 'LENGTH'; ln.location = (-900, -120)
    links.new(tc.outputs['Object'], ln.inputs[0])
    fall = nodes.new('ShaderNodeMapRange'); fall.location = (-720, -120)
    fall.clamp = True
    fall.inputs['From Min'].default_value = 0.10
    fall.inputs['From Max'].default_value = 0.80
    fall.inputs['To Min'].default_value = 1.0
    fall.inputs['To Max'].default_value = 0.0

    noise = nodes.new('ShaderNodeTexNoise'); noise.location = (-900, 140)
    noise.inputs['Scale'].default_value = 4.5
    noise.inputs['Detail'].default_value = 3.0
    links.new(tc.outputs['Object'], noise.inputs['Vector'])
    nrange = nodes.new('ShaderNodeMapRange'); nrange.location = (-720, 140)
    nrange.clamp = True
    nrange.inputs['From Min'].default_value = 0.35
    nrange.inputs['From Max'].default_value = 0.65
    links.new(noise.outputs['Fac'], nrange.inputs['Value'])
    links.new(ln.outputs['Value'], fall.inputs['Value'])

    mul = nodes.new('ShaderNodeMath'); mul.operation = 'MULTIPLY'; mul.location = (-540, 40)
    links.new(nrange.outputs['Result'], mul.inputs[0])
    links.new(fall.outputs['Result'], mul.inputs[1])

    amt = nodes.new('ShaderNodeMath'); amt.operation = 'MULTIPLY'; amt.location = (-400, 40)
    amt.inputs[1].default_value = 0.0          # animated: the wisp amount
    links.new(mul.outputs[0], amt.inputs[0])
    links.new(amt.outputs[0], pv.inputs['Density'])

    links.new(pv.outputs['Volume'], out.inputs['Volume'])
    return mat, amt


def build():
    M.ensure_dirs()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.frame_start, sc.frame_end = 1, NFRAMES

    root = bpy.data.objects.new("FlashRoot", None)
    bpy.context.collection.objects.link(root)

    mat, emis = flash_material(root)
    rnd = random.Random(3)
    parts = []

    # Bright core
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=0.24)
    core = bpy.context.active_object
    core.name = "Core"
    parts.append(core)

    # Radiating spikes in the camera plane (XZ), uneven so it isn't a pinwheel.
    n_spikes = 7
    for i in range(n_spikes):
        a = (i / n_spikes) * math.tau + rnd.uniform(-0.16, 0.16)
        ln = rnd.uniform(0.80, 1.35)
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=rnd.uniform(0.17, 0.30),
                                        radius2=0.0, depth=ln)
        c = bpy.context.active_object
        c.name = "Spike%d" % i
        # Cone points +Z by default; lay it into XZ and aim it outward.
        c.rotation_euler = (math.radians(90.0), 0.0, 0.0)
        c.rotation_mode = 'XYZ'
        c.rotation_euler = (0.0, math.pi * 0.5 - a, 0.0)
        c.location = (math.cos(a) * ln * 0.5, 0.0, math.sin(a) * ln * 0.5)
        parts.append(c)

    # Two long lateral flares -- the classic wide muzzle star
    for sgn in (-1.0, 1.0):
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.18, radius2=0.0, depth=1.95)
        c = bpy.context.active_object
        c.name = "Flare%d" % int(sgn)
        c.rotation_euler = (0.0, math.radians(90.0) * sgn, 0.0)
        c.location = (0.97 * sgn, 0.0, 0.0)
        parts.append(c)

    for p in parts:
        p.data.materials.append(mat)
        p.parent = root

    # Smoke wisp volume, off by default
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.75, location=(0.10, 0.0, 0.28))
    wisp = bpy.context.active_object
    wisp.name = "Wisp"
    wisp.scale = (0.85, 0.65, 0.60)
    wmat, wamt = wisp_material(wisp)
    wisp.data.materials.append(wmat)

    # ---- animate: scale + emission collapse, wisp fades in then out ----
    for f, (scale, strength) in enumerate(CURVE, start=1):
        root.scale = (scale, scale, scale)
        root.keyframe_insert("scale", frame=f)
        emis.inputs['Strength'].default_value = strength
        emis.inputs['Strength'].keyframe_insert("default_value", frame=f)
        root.hide_render = (scale <= 0.0)
        root.keyframe_insert("hide_render", frame=f)

        d = WISP.get(f, 0.0)
        wamt.inputs[1].default_value = d * 3.0
        wamt.inputs[1].keyframe_insert("default_value", frame=f)
        wisp.hide_render = (d <= 0.0)
        wisp.keyframe_insert("hide_render", frame=f)
        s = 0.75 + 0.55 * (f / float(NFRAMES))
        wisp.scale = (0.85 * s, 0.65 * s, 0.60 * s)
        wisp.keyframe_insert("scale", frame=f)

    M.set_world(strength=0.0)
    M.soft_key_light(energy=90.0, loc=(-4.0, -5.0, 4.0))
    # Headroom, not "fills the frame": the wisp on frames 4-7 grew into the tile
    # border, which renders in-engine as a flash with a sliced edge.
    # Headroom, not "fills the frame". The lateral flares reach 1.945 units from
    # centre (depth 1.95 at offset 0.97), so the half-width must clear that with
    # margin or the flare tips render with a sliced edge in-engine.
    M.ortho_cam_side(4.60, loc=(0.0, -10.0, 0.0))

    sc = M.setup_cycles(RES, RES, samples=64, denoise=True)
    # Share the box with the running fluid bake.
    sc.render.threads_mode = 'FIXED'
    sc.render.threads = 4
    return sc


def test():
    build()
    os.makedirs(FRAME_DIR, exist_ok=True)
    for f in (1, 3, 5):
        p = os.path.join(FRAME_DIR, "test_%02d.png" % f)
        bpy.context.scene.frame_set(f)
        bpy.context.scene.render.filepath = p
        bpy.ops.render.render(write_still=True)
        M.describe(p, "muzzle f%d " % f)


def render():
    build()
    paths = M.render_frames(FRAME_DIR, "f", list(range(1, NFRAMES + 1)))
    M.pack_sheet(paths, COLS, ROWS, RES, RES,
                 os.path.join(M.SHEETS, "muzzle_flash_sheet.png"), crossfade=0)
    for p in (paths[0], paths[3], paths[-1]):
        M.describe(p, "muzzle ")


if __name__ == "__main__":
    mode = sys.argv[-1]
    {"test": test, "render": render}[mode]()
    print("ASSET5_%s_DONE" % mode.upper())
