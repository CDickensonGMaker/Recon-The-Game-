"""Feasibility probe: headless Mantaflow bake + volume render through an ortho
camera, in both Eevee and Cycles. Tiny sim, tiny resolution -- this only has to
answer "does the pipeline work at all", not look good.
"""
import bpy, os, math, time

OUT = r"C:\Users\caleb\RECONgame\_scratch\mil_fire\probe"
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene

# --- GPU availability -------------------------------------------------------
prefs = bpy.context.preferences.addons.get('cycles')
if prefs:
    cp = prefs.preferences
    for dev_type in ('OPTIX', 'CUDA', 'HIP', 'ONEAPI'):
        try:
            cp.compute_device_type = dev_type
            cp.get_devices()
            names = [d.name for d in cp.devices if d.type == dev_type]
            if names:
                print("GPU_OK %s -> %s" % (dev_type, names))
                for d in cp.devices:
                    d.use = (d.type == dev_type)
                break
        except Exception as e:
            print("GPU_NO %s (%s)" % (dev_type, e))
    else:
        print("GPU_NONE -- CPU only")
else:
    print("CYCLES_ADDON_MISSING")

# --- tiny fire sim ----------------------------------------------------------
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.5, location=(0, 0, 0.3))
flow_obj = bpy.context.active_object
flow_obj.scale = (1.0, 1.0, 0.4)

bpy.ops.object.quick_smoke()
dom = bpy.context.active_object
print("DOMAIN", dom.name, [m.type for m in dom.modifiers])

fluid = dom.modifiers.get("Fluid")
ds = fluid.domain_settings
ds.domain_type = 'GAS'
ds.resolution_max = 48
ds.use_noise = False
ds.cache_directory = os.path.join(OUT, "cache")
ds.cache_frame_start = 1
ds.cache_frame_end = 20
ds.cache_type = 'ALL'
ds.use_adaptive_domain = False

fl = flow_obj.modifiers.get("Fluid")
fs = fl.flow_settings
fs.flow_type = 'BOTH'
fs.flow_behavior = 'INFLOW'
fs.fuel_amount = 1.5
fs.temperature = 1.5
print("FLOWTYPE", fs.flow_type, "BEHAVIOR", fs.flow_behavior)

sc.frame_start, sc.frame_end = 1, 20

t0 = time.time()
ctx = bpy.context.copy()
ctx['object'] = dom
ctx['active_object'] = dom
ctx['scene'] = sc
try:
    with bpy.context.temp_override(**ctx):
        bpy.ops.fluid.bake_all()
    print("BAKE_OK %.1fs" % (time.time() - t0))
except Exception as e:
    print("BAKE_FAIL", type(e).__name__, e)

# --- ortho camera -----------------------------------------------------------
cd = bpy.data.cameras.new("C"); cd.type = 'ORTHO'; cd.ortho_scale = 6.0
cam = bpy.data.objects.new("C", cd)
bpy.context.collection.objects.link(cam)
cam.location = (0, -10, 1.0)
cam.rotation_euler = (math.radians(90), 0, 0)
sc.camera = cam

sc.render.resolution_x = sc.render.resolution_y = 128
sc.render.film_transparent = True
sc.view_settings.view_transform = 'Standard'
sc.render.image_settings.file_format = 'PNG'
sc.render.image_settings.color_mode = 'RGBA'
sc.frame_set(18)


def coverage(path):
    img = bpy.data.images.load(path)
    px = img.pixels[:]
    n = len(px) // 4
    lit = sum(1 for i in range(0, len(px), 4) if px[i + 3] > 0.02)
    peak = max(max(px[i], px[i + 1], px[i + 2]) for i in range(0, len(px), 4))
    bpy.data.images.remove(img)
    return 100.0 * lit / n, peak


for engine in ('BLENDER_EEVEE', 'CYCLES'):
    sc.render.engine = engine
    if engine == 'CYCLES':
        sc.cycles.samples = 32
        sc.cycles.use_denoising = True
        try:
            sc.cycles.device = 'GPU'
        except Exception:
            pass
    else:
        sc.eevee.volumetric_tile_size = '2'
        sc.eevee.volumetric_samples = 128
    p = os.path.join(OUT, "probe_%s.png" % engine)
    sc.render.filepath = p
    t0 = time.time()
    try:
        bpy.ops.render.render(write_still=True)
        cov, peak = coverage(p)
        print("RENDER %s ok %.1fs coverage=%.1f%% peak=%.2f" % (engine, time.time() - t0, cov, peak))
    except Exception as e:
        print("RENDER %s FAIL %s %s" % (engine, type(e).__name__, e))

print("PROBE_DONE")
