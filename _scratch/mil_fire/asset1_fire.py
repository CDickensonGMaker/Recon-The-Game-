"""Asset 1 -- fire_loop_sheet.png (32 frames, 8x4, 256x256, alpha-blended).

Modes:  bake  -> build the scene, bake the sim, save the .blend
        test  -> reopen, render ONE mid-sim frame and describe it
        render-> reopen, render the 32-frame span and pack the sheet
"""
import bpy, sys, os, math
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import milcommon as M

NAME = "asset1_fire"
CACHE = os.path.join(M.CACHE_ROOT, NAME)
BLEND = os.path.join(M.BLENDS, NAME + ".blend")
FRAME_DIR = os.path.join(M.FRAMES, NAME)

BAKE_START, BAKE_END = 1, 92
LOOP_START, LOOP_COUNT = 60, 32      # settled middle of the sim
TEST_FRAME = 76
RES = 256
COLS, ROWS = 8, 4


def build_and_bake():
    M.ensure_dirs()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.frame_start, sc.frame_end = BAKE_START, BAKE_END

    emitter = M.make_pile("RubblePile", rx=1.25, ry=1.05, rz=0.40, seed=11)
    emitter.hide_render = True

    bpy.ops.object.quick_smoke()
    dom = bpy.context.active_object
    dom.name = "FireDomain"
    # Fixed, generous domain: the camera never moves, so the flame needs
    # headroom to lick upward without clipping the top of the box.
    dom.location = (0.0, 0.0, 2.30)
    dom.scale = (1.85, 1.85, 2.55)

    ds = dom.modifiers["Fluid"].domain_settings
    ds.domain_type = 'GAS'
    # Deliberately cheap. 2x up-res multiplies the grid by 8x cells and its
    # cost grows as the domain fills -- and all of that detail is averaged away
    # into a 256px tile drawn on a small billboard. The era look comes from
    # sooty colour and rolling shape, not simulation fidelity.
    ds.resolution_max = 96
    ds.use_noise = False
    ds.use_adaptive_domain = False      # fixed framing for a fixed camera
    ds.cache_directory = CACHE
    ds.cache_frame_start, ds.cache_frame_end = BAKE_START, BAKE_END
    ds.cache_type = 'ALL'

    # Sooty, turbulent, slow-burning fire.
    ds.alpha = 0.55                     # density buoyancy
    ds.beta = 1.70                      # heat buoyancy -> rising column
    ds.vorticity = 0.22
    ds.flame_vorticity = 0.60
    ds.burning_rate = 0.55              # slower burn = taller licking flames
    ds.flame_smoke = 1.80               # THE soot knob -- dirty, not clean glow
    ds.flame_smoke_color = (0.06, 0.055, 0.05)
    ds.flame_max_temp = 2.60
    ds.flame_ignition = 1.30
    ds.use_dissolve_smoke = True
    ds.dissolve_speed = 55
    ds.use_dissolve_smoke_log = True

    fs = emitter.modifiers["Fluid"].flow_settings
    fs.flow_type = 'BOTH'
    fs.flow_behavior = 'INFLOW'
    fs.fuel_amount = 1.60
    fs.temperature = 1.50
    fs.smoke_color = (0.05, 0.045, 0.04)
    fs.surface_distance = 1.2
    fs.use_initial_velocity = True
    fs.velocity_normal = 0.55
    fs.velocity_random = 0.30

    mat, _pv = M.fire_volume_material("FireVol", density=6.5, blackbody=1.35,
                                      temperature=1650.0)
    dom.data.materials.clear()
    dom.data.materials.append(mat)

    M.set_world(strength=0.06)
    M.soft_key_light(energy=420.0)
    M.ortho_cam_side(6.4, loc=(0.0, -12.0, 2.35))

    print("BAKING %s frames %d-%d res %d +noise%d"
          % (NAME, BAKE_START, BAKE_END, ds.resolution_max, ds.noise_scale))
    M.bake_domain(dom, NAME)
    print("CACHE_MB %.0f" % M.cache_size_mb(CACHE))
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("SAVED", BLEND)


def _prep_render():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    M.setup_cycles(RES, RES, samples=32, denoise=True)


def test():
    _prep_render()
    p = os.path.join(FRAME_DIR, "test_%03d.png" % TEST_FRAME)
    os.makedirs(FRAME_DIR, exist_ok=True)
    bpy.context.scene.frame_set(TEST_FRAME)
    bpy.context.scene.render.filepath = p
    bpy.ops.render.render(write_still=True)
    M.describe(p, "test ")


def render():
    _prep_render()
    frames = list(range(LOOP_START, LOOP_START + LOOP_COUNT))
    paths = M.render_frames(FRAME_DIR, "f", frames)
    M.pack_sheet(paths, COLS, ROWS, RES, RES,
                 os.path.join(M.SHEETS, "fire_loop_sheet.png"), crossfade=4)


if __name__ == "__main__":
    mode = sys.argv[-1]
    {"bake": build_and_bake, "test": test, "render": render}[mode]()
    print("ASSET1_%s_DONE" % mode.upper())
