"""Measure every seat_* marker in a GLB against seat_system.gd's uh1 fallback
table, in GODOT coordinates. Blender export_yup: Godot(x,y,z) = Blender(x,z,-y).
"""
import bpy, sys, os
argv = sys.argv[sys.argv.index("--") + 1:]
UH1 = {
 "seat_pilot_l": (0.55, 1.35, -5.35), "seat_pilot_r": (-0.55, 1.35, -5.35),
 "seat_gunner_l": (1.15, 1.30, -2.70), "seat_gunner_r": (-1.15, 1.30, -2.70),
 "seat_pax_1": (1.05, 0.865, -4.442), "seat_pax_2": (1.05, 0.865, -3.984),
 "seat_pax_3": (1.05, 0.865, -3.525), "seat_pax_4": (1.05, 0.865, -3.067),
 "seat_pax_5": (-1.05, 0.865, -4.442), "seat_pax_6": (-1.05, 0.865, -3.984),
 "seat_pax_7": (-1.05, 0.865, -3.525), "seat_pax_8": (-1.05, 0.865, -3.067),
 "seat_bench_1": (-0.25, 1.125, -4.015), "seat_bench_2": (-0.25, 1.125, -3.565),
 "seat_bench_3": (-0.25, 1.125, -3.115), "seat_bench_4": (0.25, 1.125, -4.015),
 "seat_bench_5": (0.25, 1.125, -3.565), "seat_bench_6": (0.25, 1.125, -3.115),
}
for path in argv:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    print("\n=== %s ===" % os.path.basename(path))
    print("%-16s %-28s %-28s %s" % ("seat", "GLB (godot coords)", "seat_system.gd uh1 fallback", "dist"))
    worst = 0.0
    for n, want in UH1.items():
        o = bpy.data.objects.get(n)
        if o is None:
            print("%-16s ABSENT (fallback socket would be generated)" % n)
            continue
        w = o.matrix_world.translation
        got = (w.x, w.z, -w.y)
        dist = sum((got[i] - want[i]) ** 2 for i in range(3)) ** 0.5
        worst = max(worst, dist)
        flag = "   <-- OFF THE AIRFRAME" if dist > 1.0 else ""
        print("%-16s (%7.3f,%6.3f,%7.3f)      (%7.3f,%6.3f,%7.3f)   %6.3f m%s"
              % (n, got[0], got[1], got[2], want[0], want[1], want[2], dist, flag))
    print("worst marker-vs-table distance: %.3f m" % worst)
