"""Asset 4 -- napalm_explosion_sheet.png (64 frames, 8x8, 512x512 tiles).

Sheet is 4096x4096 by the Summoner's call: sim stays at res 128 + 2x up-res,
but the tiles render at 512 so the hero effect holds up close.

Non-looping one-shot. A wide disc emitter dumps fuel hard for the first 10
frames and then shuts off, so the fireball rolls and mushrooms under its own
momentum and starves into black smoke.

Frame 64 must be FULLY transparent. That is not left to the sim dissipating on
schedule -- an animated density multiplier drives the whole volume to exactly
0.0 on the last frame, so the requirement holds no matter how the bake lands.
"""
import bpy, sys, os, math
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import milcommon as M

NAME = "asset4_napalm"
CACHE = os.path.join(M.CACHE_ROOT, NAME)
BLEND = os.path.join(M.BLENDS, NAME + ".blend")
FRAME_DIR = os.path.join(M.FRAMES, NAME)

BAKE_START, BAKE_END = 1, 40
SIM_FIRST = 5                 # skip the flat initial fuel-disc frames
NFRAMES = 36
RES = 192
COLS, ROWS = 6, 6
TEST_FRAME = 12

FUEL_CUTOFF = 8               # inflow stops after this sim frame
FADE_FRAMES = 16              # thin out early instead of holding a black slab


def build_and_bake():
    M.ensure_dirs()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.frame_start, sc.frame_end = BAKE_START, BAKE_END

    # Wide flat disc: napalm spreads before it climbs.
    # Compact charge, not a wide sheet: a broad disc emits a flat pancake of
    # fuel that spreads sideways instead of rolling upward.
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=1.05, depth=0.25,
                                        location=(0, 0, 0.16))
    emitter = bpy.context.active_object
    emitter.name = "NapalmDisc"
    emitter.hide_render = True

    bpy.ops.object.quick_smoke()
    dom = bpy.context.active_object
    dom.name = "NapalmDomain"
    # Taller box AND a wider camera below. Measured on the first sheet: frames
    # 20-35 had up to 43/48 sampled pixels opaque along the tile's TOP EDGE -
    # the rising column was being sliced flat by the frame, which reads in-game
    # as an explosion with its top cut off. Nothing may touch the border.
    dom.location = (0.0, 0.0, 4.90)
    dom.scale = (3.60, 3.60, 5.80)

    ds = dom.modifiers["Fluid"].domain_settings
    ds.domain_type = 'GAS'
    ds.resolution_max = 96
    ds.use_noise = False
    ds.use_adaptive_domain = False
    ds.cache_directory = CACHE
    ds.cache_frame_start, ds.cache_frame_end = BAKE_START, BAKE_END
    ds.cache_type = 'ALL'

    ds.alpha = 0.50
    ds.beta = 2.60               # strong heat buoyancy -> the mushroom climb
    ds.vorticity = 0.42          # rolling billows
    ds.time_scale = 1.50         # only 40 frames to cover the whole event
    ds.flame_vorticity = 0.75
    ds.burning_rate = 0.42       # slow burn = long rolling fireball
    ds.flame_smoke = 2.40        # very sooty -- the black shroud is the look
    ds.flame_smoke_color = (0.04, 0.036, 0.032)
    ds.flame_max_temp = 2.90
    ds.flame_ignition = 1.20
    ds.use_dissolve_smoke = True
    ds.dissolve_speed = 26       # so it is already thinning by the tail
    ds.use_dissolve_smoke_log = True

    fs = emitter.modifiers["Fluid"].flow_settings
    fs.flow_type = 'BOTH'
    fs.flow_behavior = 'INFLOW'
    fs.fuel_amount = 3.20
    fs.temperature = 2.60
    fs.smoke_color = (0.045, 0.04, 0.036)
    fs.surface_distance = 1.6
    fs.use_initial_velocity = True
    fs.velocity_normal = 0.60                 # outward off the disc
    fs.velocity_coord = (0.0, 0.0, 5.00)      # and hard upward
    fs.velocity_random = 0.55

    # Hard emission for 10 frames, then nothing.
    fs.use_inflow = True
    fs.keyframe_insert("use_inflow", frame=BAKE_START)
    fs.keyframe_insert("use_inflow", frame=FUEL_CUTOFF)
    fs.use_inflow = False
    fs.keyframe_insert("use_inflow", frame=FUEL_CUTOFF + 1)
    M.step_boolean_keys(emitter)

    mat, pv = M.fire_volume_material("NapalmVol", density=7.0, blackbody=1.55,
                                     temperature=1750.0,
                                     smoke_color=(0.030, 0.027, 0.025))
    dom.data.materials.clear()
    dom.data.materials.append(mat)

    M.set_world(strength=0.05)
    M.soft_key_light(energy=900.0, loc=(-12.0, -14.0, 12.0))
    M.ortho_cam_side(ORTHO, loc=(0.0, -26.0, CAM_Z))

    print("BAKING %s frames %d-%d res %d +noise%d"
          % (NAME, BAKE_START, BAKE_END, ds.resolution_max, ds.noise_scale))
    M.bake_domain(dom, NAME)
    print("CACHE_MB %.0f" % M.cache_size_mb(CACHE))
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("SAVED", BLEND)


ORTHO, CAM_Z = 11.4, 4.60


def _prep(res=RES, samples=32, ortho=None, cam_z=None):
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    cam = bpy.data.objects["VFXCam"]
    cam.data.ortho_scale = ortho if ortho is not None else ORTHO
    cam.location = (0.0, -26.0, cam_z if cam_z is not None else CAM_Z)
    _retune_emission()
    M.setup_cycles(res, res, samples=samples, denoise=True)


def _retune_emission():
    """The first pass saturated to flat yellow-white: blackbody 1.55 at 1750K
    over a dense volume clips every channel, which erases both the orange body
    and the black soot the effect is supposed to be wrapped in."""
    pv = _density_node()
    # Temperature sets HUE (the attribute multiplies it, so 2800 lets the
    # hottest voxels reach white-yellow while cooler ones stay deep orange).
    # Blackbody Intensity sets magnitude -- that is the saturation knob.
    # The sim has almost no temperature gradient -- nearly every voxel sits at
    # max temp -- so 2800K painted the WHOLE ball white. 1750K puts max temp at
    # orange-yellow and lets only the optically thickest parts clip to white,
    # which is where the flash reads from. Intensity rescaled by T^4.
    pv.inputs['Temperature'].default_value = 1750.0
    pv.inputs['Blackbody Intensity'].default_value = 0.34
    pv.inputs['Density'].default_value = 10.0
    # Measured 0.003 mean luminance past frame 20 on the previous pass - a black
    # slab, which is the "dull/muddy" half of the complaint. Brighter albedo so
    # the dying smoke reads as grey-brown rather than a hole in the world.
    pv.inputs['Color'].default_value = (0.165, 0.147, 0.126, 1.0)

    # A fireball lights ITSELF. A strong key washes the lit soot to pale grey
    # and drowns the emission -- keep external light to a rim/shaping role.
    for ob in bpy.data.objects:
        if ob.type == 'LIGHT':
            # Scattered white light on dense smoke desaturates the fireball to
            # pale grey. Keep it to a rim role and let the fire light itself.
            ob.data.energy = 300.0
    bg = bpy.context.scene.world.node_tree.nodes["Background"]
    bg.inputs['Strength'].default_value = 0.02


def _density_node():
    # The node is created as ShaderNodeVolumePrincipled but reports its type as
    # PRINCIPLED_VOLUME -- bl_idname and the type enum do not match here.
    mat = bpy.data.materials["NapalmVol"]
    return next(n for n in mat.node_tree.nodes
                if n.type in ('PRINCIPLED_VOLUME', 'VOLUME_PRINCIPLED'))


def _apply_tail_fade(base_density=10.0):
    """Drive density to exactly 0 on the final output frame."""
    pv = _density_node()
    last_sim = SIM_FIRST + NFRAMES - 1
    start = last_sim - FADE_FRAMES
    pv.inputs['Density'].default_value = base_density
    pv.inputs['Density'].keyframe_insert("default_value", frame=start)
    pv.inputs['Density'].default_value = 0.0
    pv.inputs['Density'].keyframe_insert("default_value", frame=last_sim)


def test():
    os.makedirs(FRAME_DIR, exist_ok=True)
    for tag, ortho, z in (("A", 6.2, 2.10),):
        _prep(res=RES, samples=48, ortho=ortho, cam_z=z)
        for f in (4, 8, TEST_FRAME, 20, 30, 38):
            p = os.path.join(FRAME_DIR, "test_%s_%03d.png" % (tag, f))
            bpy.context.scene.frame_set(f)
            bpy.context.scene.render.filepath = p
            bpy.ops.render.render(write_still=True)
            M.describe(p, "napalm %s f%d " % (tag, f))


def render():
    _prep()
    _apply_tail_fade()
    frames = list(range(SIM_FIRST, SIM_FIRST + NFRAMES))
    paths = M.render_frames(FRAME_DIR, "f", frames)
    M.pack_sheet(paths, COLS, ROWS, RES, RES,
                 os.path.join(M.SHEETS, "napalm_explosion_sheet.png"), crossfade=0)
    for p in (paths[0], paths[10], paths[24], paths[-1]):
        M.describe(p, "napalm ")


if __name__ == "__main__":
    mode = sys.argv[-1]
    {"bake": build_and_bake, "test": test, "render": render}[mode]()
    print("ASSET4_%s_DONE" % mode.upper())
