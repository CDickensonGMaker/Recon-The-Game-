"""Asset 6 -- mortar_burst_sheet.png (16 frames, 4x4, 256x256, ALPHA-blended).

No fluid sim. Three overlapping elements on one timeline:
  frames 1-3   sharp vertical flash column
  frames 2-10  a cone of dark dirt chunks thrown up and out (real particles,
               with gravity, so they arc instead of drifting)
  frames 6-16  a squat gray-brown smoke pall expanding to nothing by 16

Per the brief this is a DIRT burst, not a fireball -- WWII footage bursts are
overwhelmingly earth with barely any visible flame, so the flash is brief and
small and the debris does the talking.
"""
import bpy, sys, os, math, random
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import milcommon as M

NAME = "asset6_mortar"
FRAME_DIR = os.path.join(M.FRAMES, NAME)
NFRAMES = 16
RES = 192
COLS, ROWS = 4, 4

FLASH = {1: 1.00, 2: 0.72, 3: 0.30}                    # frame -> flash amount
PALL = {6: 0.25, 7: 0.55, 8: 0.80, 9: 1.00, 10: 1.00,  # frame -> pall amount
        11: 0.92, 12: 0.78, 13: 0.60, 14: 0.40, 15: 0.20, 16: 0.0}


def dirt_material():
    """Flat, unlit-looking brown-black. Debris chunks should read as silhouette
    shapes, not as shaded pebbles."""
    mat = bpy.data.materials.new("Dirt")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    emis = nt.nodes.new('ShaderNodeEmission')
    emis.inputs['Color'].default_value = (0.075, 0.055, 0.038, 1.0)
    emis.inputs['Strength'].default_value = 1.0
    nt.links.new(emis.outputs['Emission'], out.inputs['Surface'])
    return mat


def flash_material():
    mat = bpy.data.materials.new("Flash")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    emis = nt.nodes.new('ShaderNodeEmission'); emis.location = (-260, 60)
    emis.inputs['Color'].default_value = (1.0, 0.66, 0.28, 1.0)
    emis.inputs['Strength'].default_value = 0.0
    trans = nt.nodes.new('ShaderNodeBsdfTransparent'); trans.location = (-260, -120)
    mix = nt.nodes.new('ShaderNodeMixShader'); mix.location = (-60, 0)

    # Fade the column out toward its top so it has no hard cap.
    tc = nt.nodes.new('ShaderNodeTexCoord'); tc.location = (-820, -60)
    sep = nt.nodes.new('ShaderNodeSeparateXYZ'); sep.location = (-640, -60)
    nt.links.new(tc.outputs['Generated'], sep.inputs['Vector'])
    mr = nt.nodes.new('ShaderNodeMapRange'); mr.location = (-460, -60)
    mr.clamp = True
    mr.inputs['From Min'].default_value = 0.15
    mr.inputs['From Max'].default_value = 1.0
    mr.inputs['To Min'].default_value = 1.0
    mr.inputs['To Max'].default_value = 0.0
    nt.links.new(sep.outputs['Z'], mr.inputs['Value'])
    nt.links.new(mr.outputs['Result'], mix.inputs['Fac'])
    nt.links.new(trans.outputs['BSDF'], mix.inputs[1])
    nt.links.new(emis.outputs['Emission'], mix.inputs[2])
    nt.links.new(mix.outputs['Shader'], out.inputs['Surface'])
    return mat, emis


def pall_material(obj):
    """Squat gray-brown smoke pall: noise-broken volume with a radial falloff,
    driven by one animatable amount socket."""
    mat = bpy.data.materials.new("Pall")
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    for n in list(nodes):
        nodes.remove(n)
    out = nodes.new('ShaderNodeOutputMaterial')
    pv = nodes.new('ShaderNodeVolumePrincipled'); pv.location = (-260, 0)
    pv.inputs['Color'].default_value = (0.32, 0.28, 0.225, 1.0)    # gray-brown
    pv.inputs['Blackbody Intensity'].default_value = 0.0
    pv.inputs['Anisotropy'].default_value = 0.2

    tc = nodes.new('ShaderNodeTexCoord'); tc.location = (-1120, 0)
    tc.object = obj
    ln = nodes.new('ShaderNodeVectorMath'); ln.operation = 'LENGTH'; ln.location = (-940, -140)
    links.new(tc.outputs['Object'], ln.inputs[0])
    fall = nodes.new('ShaderNodeMapRange'); fall.location = (-760, -140)
    fall.clamp = True
    fall.inputs['From Min'].default_value = 0.15
    fall.inputs['From Max'].default_value = 1.00
    fall.inputs['To Min'].default_value = 1.0
    fall.inputs['To Max'].default_value = 0.0
    links.new(ln.outputs['Value'], fall.inputs['Value'])

    noise = nodes.new('ShaderNodeTexNoise'); noise.location = (-940, 160)
    noise.inputs['Scale'].default_value = 3.2
    noise.inputs['Detail'].default_value = 4.0
    noise.inputs['Roughness'].default_value = 0.55
    links.new(tc.outputs['Object'], noise.inputs['Vector'])
    nr = nodes.new('ShaderNodeMapRange'); nr.location = (-760, 160)
    nr.clamp = True
    nr.inputs['From Min'].default_value = 0.32
    nr.inputs['From Max'].default_value = 0.70
    links.new(noise.outputs['Fac'], nr.inputs['Value'])

    mul = nodes.new('ShaderNodeMath'); mul.operation = 'MULTIPLY'; mul.location = (-580, 30)
    links.new(nr.outputs['Result'], mul.inputs[0])
    links.new(fall.outputs['Result'], mul.inputs[1])
    amt = nodes.new('ShaderNodeMath'); amt.operation = 'MULTIPLY'; amt.location = (-420, 30)
    amt.inputs[1].default_value = 0.0
    links.new(mul.outputs[0], amt.inputs[0])
    links.new(amt.outputs[0], pv.inputs['Density'])
    links.new(pv.outputs['Volume'], out.inputs['Volume'])
    return mat, amt


def build():
    M.ensure_dirs()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.frame_start, sc.frame_end = 1, NFRAMES
    sc.gravity = (0.0, 0.0, -9.81)

    # ---- debris chunk to instance ----
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.10, location=(0, 0, -50))
    chunk = bpy.context.active_object
    chunk.name = "Chunk"
    rnd = random.Random(5)
    for v in chunk.data.vertices:       # irregular, not a ball
        v.co.x *= 1.0 + rnd.uniform(-0.45, 0.45)
        v.co.y *= 1.0 + rnd.uniform(-0.45, 0.45)
        v.co.z *= 1.0 + rnd.uniform(-0.45, 0.45)
    chunk.data.update()
    dmat = dirt_material()
    chunk.data.materials.append(dmat)
    # NOT hide_render: hiding the instanced object hides every instance with
    # it, which is why the first pass had no debris at all. It is parked at
    # z=-50, far outside the camera frame, which achieves the same thing.

    # ---- particle emitter: a small disc at the impact point ----
    bpy.ops.mesh.primitive_circle_add(vertices=16, radius=0.34, fill_type='NGON',
                                      location=(0, 0, 0.05))
    emit = bpy.context.active_object
    emit.name = "BurstEmitter"
    # hide_render on the EMITTER suppresses its particle systems too -- the
    # same trap as hiding the instanced object. show_instancer_for_render hides
    # only the emitter mesh and keeps the particles.
    emit.show_instancer_for_render = False
    ps_mod = emit.modifiers.new("Debris", type='PARTICLE_SYSTEM')
    ps = ps_mod.particle_system.settings
    ps.count = 240                      # 900 at 2x size was a solid brown wall
    ps.frame_start = 1.0
    ps.frame_end = 2.5                  # a burst, not a fountain
    # Must be dead by frame 16: the final frame has to be fully transparent.
    ps.lifetime = 9
    ps.lifetime_random = 0.45
    ps.emit_from = 'FACE'
    ps.use_emit_random = True
    ps.normal_factor = 9.0              # straight up off the disc
    ps.factor_random = 8.5              # ...scattered into a wide cone
    ps.object_align_factor = (0.0, 0.0, 4.0)
    ps.physics_type = 'NEWTON'
    ps.mass = 1.0
    ps.effector_weights.gravity = 1.0   # chunks arc and fall back
    ps.particle_size = 0.85     # sub-pixel chunks read as nothing at 192px
    ps.size_random = 0.8
    ps.render_type = 'OBJECT'
    ps.instance_object = chunk
    ps.use_rotations = True
    ps.rotation_factor_random = 1.0
    ps.angular_velocity_factor = 3.0

    # ---- flash column ----
    bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.30, depth=2.1,
                                        location=(0, 0, 1.02))
    col = bpy.context.active_object
    col.name = "FlashColumn"
    fmat, femis = flash_material()
    col.data.materials.append(fmat)

    # ---- smoke pall: three overlapping lobes, so the silhouette is lumpy
    # rather than one obvious ellipsoid ----
    palls = []
    for i, (ox, oz, sc_) in enumerate(((0.0, 0.62, 0.92),
                                       (-0.95, 0.34, 0.66),
                                       (0.88, 0.44, 0.60))):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, location=(ox, 0.0, oz))
        pb = bpy.context.active_object
        pb.name = "Pall%d" % i
        pm, pa = pall_material(pb)
        pb.data.materials.append(pm)
        palls.append((pb, pa, sc_, ox, oz))

    # ---- animate ----
    for f in range(1, NFRAMES + 1):
        a = FLASH.get(f, 0.0)
        femis.inputs['Strength'].default_value = a * 1.25
        femis.inputs['Strength'].keyframe_insert("default_value", frame=f)
        col.hide_render = (a <= 0.0)
        col.keyframe_insert("hide_render", frame=f)
        s = 0.7 + 0.9 * (1.0 - a)
        col.scale = (1.0, 1.0, s)
        col.keyframe_insert("scale", frame=f)

        p = PALL.get(f, 0.0)
        # squat, and spreading wider than it grows tall
        g = 0.85 + 0.115 * max(0, f - 5)
        for pb, pa, sc_, ox, oz in palls:
            pa.inputs[1].default_value = p * 1.25
            pa.inputs[1].keyframe_insert("default_value", frame=f)
            pb.hide_render = (p <= 0.0)
            pb.keyframe_insert("hide_render", frame=f)
            pb.scale = (1.55 * g * sc_, 1.55 * g * sc_, 0.72 * g * sc_)
            pb.keyframe_insert("scale", frame=f)
            # lobes drift apart as the pall spreads
            pb.location = (ox * g, 0.0, oz + 0.10 * max(0, f - 5))
            pb.keyframe_insert("location", frame=f)

    for ob in [col] + [p[0] for p in palls]:
        M.step_boolean_keys(ob)

    M.set_world(strength=0.12)
    M.soft_key_light(energy=700.0, loc=(-6.0, -8.0, 7.0))
    M.ortho_cam_side(8.8, loc=(0.0, -14.0, 2.70))
    M.setup_cycles(RES, RES, samples=64, denoise=True)


def test():
    build()
    os.makedirs(FRAME_DIR, exist_ok=True)
    for f in (2, 6, 11):
        p = os.path.join(FRAME_DIR, "test_%02d.png" % f)
        bpy.context.scene.frame_set(f)
        bpy.context.scene.render.filepath = p
        bpy.ops.render.render(write_still=True)
        M.describe(p, "mortar f%d " % f)


def render():
    build()
    paths = M.render_frames(FRAME_DIR, "f", list(range(1, NFRAMES + 1)))
    M.pack_sheet(paths, COLS, ROWS, RES, RES,
                 os.path.join(M.SHEETS, "mortar_burst_sheet.png"), crossfade=0)
    for p in (paths[1], paths[7], paths[-1]):
        M.describe(p, "mortar ")


if __name__ == "__main__":
    mode = sys.argv[-1]
    {"test": test, "render": render}[mode]()
    print("ASSET6_%s_DONE" % mode.upper())
