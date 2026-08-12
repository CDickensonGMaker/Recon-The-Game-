"""Engine benchmark on the real baked fire cache.

The earlier 90s/frame Eevee figure was measured at RAISED volumetric quality
(tile size 2, 128 samples) because the first spec demanded it. The lean spec
says DEFAULT volumetric settings, which is a different cost entirely, so this
re-measures fairly: Eevee at factory volumetric defaults vs Cycles at the cheap
settings, same frame, same 256x256 output.
"""
import bpy, sys, os, time
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import milcommon as M

BLEND = os.path.join(M.BLENDS, "asset1_fire.blend")
OUT = os.path.join(M.FRAMES, "bench")
os.makedirs(OUT, exist_ok=True)
FRAME = 76
RES = 256


def stats(path):
    img = bpy.data.images.load(path)
    px = img.pixels[:]
    n = len(px) // 4
    lit = sum(1 for i in range(0, len(px), 4) if px[i + 3] > 0.02)
    peak = max(max(px[i], px[i + 1], px[i + 2]) for i in range(0, len(px), 4))
    mean = sum(px[i] + px[i + 1] + px[i + 2] for i in range(0, len(px), 4)) / (3.0 * max(lit, 1))
    bpy.data.images.remove(img)
    return 100.0 * lit / n, peak, mean


for engine in ('BLENDER_EEVEE', 'CYCLES'):
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    sc = bpy.context.scene
    if engine == 'CYCLES':
        M.setup_cycles(RES, RES, samples=32, denoise=True)
    else:
        sc.render.engine = 'BLENDER_EEVEE'
        sc.render.resolution_x = sc.render.resolution_y = RES
        sc.render.film_transparent = True
        sc.render.use_motion_blur = False
        sc.view_settings.view_transform = 'Standard'
        sc.render.image_settings.file_format = 'PNG'
        sc.render.image_settings.color_mode = 'RGBA'
        # factory volumetric defaults left untouched on purpose
        print("EEVEE defaults: tile=%s samples=%d" %
              (sc.eevee.volumetric_tile_size, sc.eevee.volumetric_samples))
    p = os.path.join(OUT, "bench_%s.png" % engine)
    sc.frame_set(FRAME)
    sc.render.filepath = p
    t0 = time.time()
    bpy.ops.render.render(write_still=True)
    dt = time.time() - t0
    cov, peak, mean = stats(p)
    print("BENCH %-14s %6.1fs  coverage=%.1f%%  peak=%.2f  mean=%.3f"
          % (engine, dt, cov, peak, mean))

print("BENCH_DONE")
