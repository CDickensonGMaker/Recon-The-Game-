"""The SHARED SIM -- one bake feeds Assets 1, 2 and 3.

Fuel runs full for frames 1-69 and cuts off at 70, so a single cache contains
both a settled burn (frames 30-45: fire + soot) and a pure post-fuel smoke tail
(frames 85-100). Assets differ only by frame range, shader pass and framing.

Engine is Cycles, chosen by measurement on this machine's own baked cache:
4.5s/frame vs 38.9s for Eevee at factory volumetric defaults, for a
near-identical image. Godot 4.7 receives the same PNGs either way.

Domain is deliberately roomier than the flame needs. In the first pass the
smoke reached the box walls and rendered a hard vertical edge straight down the
sprite -- a sim-box artefact baked into the texture.
"""
import bpy, sys, os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import milcommon as M

NAME = "shared_fire"
CACHE = os.path.join(M.CACHE_ROOT, NAME)
BLEND = os.path.join(M.BLENDS, NAME + ".blend")

BAKE_START, BAKE_END = 1, 110
FUEL_CUTOFF = 70

BURN_START, BURN_COUNT = 30, 16      # Assets 1 & 2
SMOKE_START, SMOKE_COUNT = 76, 16    # Asset 3: just after fuel cut, still shaped
SAMPLES = 48


def build_and_bake():
    M.ensure_dirs()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.frame_start, sc.frame_end = BAKE_START, BAKE_END

    # Broad and flat. A narrow emitter concentrates a buoyant plume, and a
    # coherent plume ALWAYS mushrooms -- which read as a rocket, not a fire.
    emitter = M.make_pile("RubblePile", rx=1.15, ry=0.90, rz=0.24, seed=11)
    emitter.hide_render = True

    bpy.ops.object.quick_smoke()
    dom = bpy.context.active_object
    dom.name = "FireDomain"
    dom.location = (0.0, 0.0, 2.35)
    dom.scale = (2.10, 2.10, 2.60)

    ds = dom.modifiers["Fluid"].domain_settings
    ds.domain_type = 'GAS'
    ds.resolution_max = 96
    ds.use_noise = False
    ds.use_adaptive_domain = False
    ds.cache_directory = CACHE
    ds.cache_frame_start, ds.cache_frame_end = BAKE_START, BAKE_END
    ds.cache_type = 'ALL'

    ds.alpha = 0.50
    ds.beta = 1.25                      # gentle rise: high beta builds a plume
    ds.vorticity = 0.34                 # break the plume up into licking flame
    ds.flame_vorticity = 0.85
    ds.burning_rate = 0.95              # burn fuel AT the source, not aloft
    ds.flame_smoke = 1.15
    ds.flame_smoke_color = (0.06, 0.055, 0.05)
    ds.flame_max_temp = 2.20
    ds.flame_ignition = 1.10
    ds.time_scale = 1.35                # more motion per frame -> flicker
    ds.use_dissolve_smoke = True
    ds.dissolve_speed = 35              # keep smoke from piling into a cloud
    ds.use_dissolve_smoke_log = True

    fs = emitter.modifiers["Fluid"].flow_settings
    fs.flow_type = 'BOTH'
    fs.flow_behavior = 'INFLOW'
    fs.fuel_amount = 1.60
    fs.temperature = 1.50
    fs.smoke_color = (0.05, 0.045, 0.04)
    fs.surface_distance = 1.2
    fs.use_initial_velocity = True
    fs.velocity_normal = 0.30
    fs.velocity_random = 0.35              # no upward jet -- that made the plume

    # Fuel on through FUEL_CUTOFF-1, off from FUEL_CUTOFF.
    fs.use_inflow = True
    fs.keyframe_insert("use_inflow", frame=BAKE_START)
    fs.keyframe_insert("use_inflow", frame=FUEL_CUTOFF - 1)
    fs.use_inflow = False
    fs.keyframe_insert("use_inflow", frame=FUEL_CUTOFF)
    M.step_boolean_keys(emitter)

    mat, _pv = M.fire_volume_material("FireVol", density=6.5, blackbody=1.35,
                                      temperature=1650.0)
    dom.data.materials.clear()
    dom.data.materials.append(mat)

    M.set_world(strength=0.06)
    M.soft_key_light(energy=420.0)
    M.ortho_cam_side(4.4, loc=(0.0, -14.0, 1.95))

    print("BAKING %s frames %d-%d res %d (fuel off at %d)"
          % (NAME, BAKE_START, BAKE_END, ds.resolution_max, FUEL_CUTOFF))
    M.bake_domain(dom, NAME)
    print("CACHE_MB %.0f" % M.cache_size_mb(CACHE))
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("SAVED", BLEND)


# ------------------------------------------------------------- shader passes ---
def _fire_pass():
    """Fire + soot together, for alpha blending."""
    return bpy.data.materials["FireVol"]


def _core_pass():
    """Flame emission only. Density is driven by Mantaflow's 'flame' grid, so
    the volume exists ONLY inside combustion -- that is what drops the smoke,
    rather than trying to subtract it afterwards."""
    mat = bpy.data.materials.new("CoreVol")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    pv = nt.nodes.new('ShaderNodeVolumePrincipled')
    pv.inputs['Density Attribute'].default_value = "flame"
    pv.inputs['Density'].default_value = 9.0
    pv.inputs['Color'].default_value = (0.9, 0.9, 0.9, 1.0)
    pv.inputs['Blackbody Intensity'].default_value = 2.2
    pv.inputs['Temperature'].default_value = 2150.0
    pv.inputs['Temperature Attribute'].default_value = "temperature"
    nt.links.new(pv.outputs['Volume'], out.inputs['Volume'])
    return mat


def _smoke_pass():
    """Smoke only: blackbody off so no residual flame emission leaks in."""
    mat = bpy.data.materials.new("SmokeOnly")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    pv = nt.nodes.new('ShaderNodeVolumePrincipled')
    pv.inputs['Density Attribute'].default_value = "density"
    # Density 11 rendered a near-opaque black slab: with blackbody off there is
    # no flame lighting it from inside, so it must be thin enough for the key
    # light to penetrate, and its albedo bright enough to read as grey smoke.
    pv.inputs['Density'].default_value = 4.5
    pv.inputs['Color'].default_value = (0.19, 0.170, 0.145, 1.0)
    pv.inputs['Blackbody Intensity'].default_value = 0.0
    pv.inputs['Anisotropy'].default_value = 0.10
    nt.links.new(pv.outputs['Volume'], out.inputs['Volume'])
    return mat


def _open(res, ortho, cam_z, mat):
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    dom = bpy.data.objects["FireDomain"]
    dom.data.materials.clear()
    dom.data.materials.append(mat() if callable(mat) else mat)
    cam = bpy.data.objects["VFXCam"]
    cam.data.ortho_scale = ortho
    cam.location = (0.0, -14.0, cam_z)
    M.setup_cycles(res, res, samples=SAMPLES, denoise=True)


def checkpoint():
    """Framing sweep: the sim is fine, the question is where to point at it."""
    d = os.path.join(M.FRAMES, NAME)
    os.makedirs(d, exist_ok=True)
    for tag, ortho, z in (("tight", 2.9, 1.05), ("mid", 3.6, 1.35)):
        _open(256, ortho, z, _fire_pass)
        for f in (32, 40):
            p = os.path.join(d, "cp_%s_%03d.png" % (tag, f))
            bpy.context.scene.frame_set(f)
            bpy.context.scene.render.filepath = p
            bpy.ops.render.render(write_still=True)
            M.describe(p, "%s f%d " % (tag, f))


def render_fire():
    # Wider than "fills the frame": content touching the tile border renders
    # in-engine as an effect with its top sliced flat.
    _open(256, 5.4, 2.05, _fire_pass)
    d = os.path.join(M.FRAMES, "asset1_fire")
    paths = M.render_frames(d, "f", list(range(BURN_START, BURN_START + BURN_COUNT)))
    M.pack_sheet(paths, 4, 4, 256, 256,
                 os.path.join(M.SHEETS, "fire_loop_sheet.png"), crossfade=3)


def render_core():
    _open(128, 4.10, 1.55, _core_pass)
    d = os.path.join(M.FRAMES, "asset2_core")
    paths = M.render_frames(d, "f", list(range(BURN_START, BURN_START + BURN_COUNT)))
    M.pack_sheet(paths, 4, 4, 128, 128,
                 os.path.join(M.SHEETS, "fire_core_sheet.png"), crossfade=3)


def _light_for_smoke():
    """Smoke has no internal emission, so it needs real light to read as grey
    rather than as a silhouette."""
    for ob in bpy.data.objects:
        if ob.type == 'LIGHT':
            ob.data.energy = 1400.0
    bpy.context.scene.world.node_tree.nodes["Background"].inputs['Strength'].default_value = 0.30
    # A thin lit volume is the noisiest thing Cycles renders here; these frames
    # are cheap, so buy the samples back.
    bpy.context.scene.cycles.samples = 128


def smoketest():
    _open(256, 5.8, 2.95, _smoke_pass)
    _light_for_smoke()
    d = os.path.join(M.FRAMES, "asset3_smoke")
    os.makedirs(d, exist_ok=True)
    for f in (SMOKE_START, SMOKE_START + 12):
        p = os.path.join(d, "test_%03d.png" % f)
        bpy.context.scene.frame_set(f)
        bpy.context.scene.render.filepath = p
        bpy.ops.render.render(write_still=True)
        M.describe(p, "smoke f%d " % f)


def render_smoke():
    _open(256, 8.2, 3.85, _smoke_pass)
    _light_for_smoke()
    d = os.path.join(M.FRAMES, "asset3_smoke")
    paths = M.render_frames(d, "f", list(range(SMOKE_START, SMOKE_START + SMOKE_COUNT)))
    M.pack_sheet(paths, 4, 4, 256, 256,
                 os.path.join(M.SHEETS, "smoke_loop_sheet.png"), crossfade=3)


if __name__ == "__main__":
    mode = sys.argv[-1]
    {"bake": build_and_bake, "checkpoint": checkpoint, "fire": render_fire,
     "core": render_core, "smoke": render_smoke, "smoketest": smoketest}[mode]()
    print("SHARED_%s_DONE" % mode.upper())
