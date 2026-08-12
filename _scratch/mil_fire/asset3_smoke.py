"""Asset 3 -- smoke_loop_sheet.png (16 frames, 4x4, 256x256, ALPHA-blended).

Its own sim: smoke only, no combustion grid at all. Slowed with time_scale so
the churn reads lazy rather than boiling, and given real opacity so it can be
alpha-blended in-engine instead of glowing.
"""
import bpy, sys, os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import milcommon as M

NAME = "asset3_smoke"
CACHE = os.path.join(M.CACHE_ROOT, NAME)
BLEND = os.path.join(M.BLENDS, NAME + ".blend")
FRAME_DIR = os.path.join(M.FRAMES, NAME)

BAKE_START, BAKE_END = 1, 84    # render window ends at 81; the rest is waste
LOOP_START, LOOP_COUNT = 66, 16
TEST_FRAME = 74
RES = 256
COLS, ROWS = 4, 4


def build_and_bake():
    M.ensure_dirs()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.frame_start, sc.frame_end = BAKE_START, BAKE_END

    emitter = M.make_pile("SmokeSource", rx=0.95, ry=0.85, rz=0.34, seed=23)
    emitter.hide_render = True

    bpy.ops.object.quick_smoke()
    dom = bpy.context.active_object
    dom.name = "SmokeDomain"
    # Tall box: this one is a rising column, not a squat fire.
    dom.location = (0.0, 0.0, 3.10)
    dom.scale = (1.75, 1.75, 3.40)

    ds = dom.modifiers["Fluid"].domain_settings
    ds.domain_type = 'GAS'
    ds.resolution_max = 96
    ds.use_noise = False
    ds.use_adaptive_domain = False
    ds.cache_directory = CACHE
    ds.cache_frame_start, ds.cache_frame_end = BAKE_START, BAKE_END
    ds.cache_type = 'ALL'

    ds.alpha = 0.42
    ds.beta = 1.05
    ds.vorticity = 0.30          # churn
    ds.time_scale = 0.65         # ...but lazy, not boiling
    ds.use_dissolve_smoke = True
    ds.dissolve_speed = 90
    ds.use_dissolve_smoke_log = True

    fs = emitter.modifiers["Fluid"].flow_settings
    fs.flow_type = 'SMOKE'       # no fuel, no flame grid
    fs.flow_behavior = 'INFLOW'
    fs.density = 1.0
    fs.temperature = 0.70
    fs.smoke_color = (0.05, 0.046, 0.042)
    fs.surface_distance = 1.1
    fs.use_initial_velocity = True
    fs.velocity_normal = 0.35

    mat, _pv = M.smoke_volume_material("SmokeVol", density=9.0,
                                       color=(0.055, 0.050, 0.045))
    dom.data.materials.clear()
    dom.data.materials.append(mat)

    M.set_world(strength=0.10)
    M.soft_key_light(energy=650.0, loc=(-7.0, -9.0, 8.0))
    M.ortho_cam_side(7.2, loc=(0.0, -14.0, 3.10))

    print("BAKING %s frames %d-%d res %d" % (NAME, BAKE_START, BAKE_END, ds.resolution_max))
    M.bake_domain(dom, NAME)
    print("CACHE_MB %.0f" % M.cache_size_mb(CACHE))
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("SAVED", BLEND)


def _prep():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    M.setup_cycles(RES, RES, samples=32, denoise=True)


def test():
    _prep()
    os.makedirs(FRAME_DIR, exist_ok=True)
    p = os.path.join(FRAME_DIR, "test_%03d.png" % TEST_FRAME)
    bpy.context.scene.frame_set(TEST_FRAME)
    bpy.context.scene.render.filepath = p
    bpy.ops.render.render(write_still=True)
    M.describe(p, "smoke ")


def render():
    _prep()
    paths = M.render_frames(FRAME_DIR, "f", list(range(LOOP_START, LOOP_START + LOOP_COUNT)))
    M.pack_sheet(paths, COLS, ROWS, RES, RES,
                 os.path.join(M.SHEETS, "smoke_loop_sheet.png"), crossfade=3)


if __name__ == "__main__":
    mode = sys.argv[-1]
    {"bake": build_and_bake, "test": test, "render": render}[mode]()
    print("ASSET3_%s_DONE" % mode.upper())
