"""Measure which way each aircraft GLB actually points.

RECONgame convention: forward = Blender +Y  ==  Godot -Z.
A GLB is imported into Blender with Y-up->Z-up conversion, so a model whose nose
sits at -Y in Blender after import is the one that reads backwards in Godot.

Nothing here is eyeballed: we report the overall bounds plus the Y-extent of
every named part, so the nose can be identified by NAME (propeller, pitot,
gunpod, cockpit) rather than by guessing which end is pointy.
"""
import bpy, sys, os, math

FILES = [
    r"C:\Users\caleb\RECONgame\assets\us\aircraft\a1_skyraider.glb",
    r"C:\Users\caleb\RECONgame\assets\us\aircraft\a4_skyhawk.glb",
    r"C:\Users\caleb\RECONgame\assets\us\aircraft\f4_phantom.glb",
    r"C:\Users\caleb\RECONgame\assets\us\aircraft\ac47_spooky.glb",
    r"C:\Users\caleb\RECONgame\assets\us\aircraft\a1_skyraider_crashed.glb",
]

# Part-name fragments that identify the FRONT and the BACK of an airframe.
NOSE_HINTS = ("prop", "pitot", "spinner", "gunpod", "radome", "nose", "cockpit",
              "canopy", "intake")
TAIL_HINTS = ("tail", "exhaust", "vstab", "vfin", "rudder", "hstab", "stab",
              "elevator")


def bounds_world(ob):
    ws = [ob.matrix_world @ v.co for v in ob.data.vertices]
    if not ws:
        return None
    return (min(v.y for v in ws), max(v.y for v in ws),
            min(v.x for v in ws), max(v.x for v in ws),
            min(v.z for v in ws), max(v.z for v in ws))


for path in FILES:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    try:
        bpy.ops.import_scene.gltf(filepath=path)
    except Exception as e:
        print("IMPORT_FAIL %s %s" % (os.path.basename(path), e))
        continue

    meshes = [o for o in bpy.data.objects if o.type == 'MESH' and len(o.data.vertices)]
    if not meshes:
        print("NO_MESH %s" % os.path.basename(path))
        continue

    allb = [bounds_world(o) for o in meshes]
    allb = [b for b in allb if b]
    ymin = min(b[0] for b in allb); ymax = max(b[1] for b in allb)
    xmin = min(b[2] for b in allb); xmax = max(b[3] for b in allb)
    zmin = min(b[4] for b in allb); zmax = max(b[5] for b in allb)

    nose_y = []
    tail_y = []
    for o in meshes:
        b = bounds_world(o)
        if not b:
            continue
        mid = (b[0] + b[1]) * 0.5
        n = o.name.lower()
        if any(h in n for h in NOSE_HINTS):
            nose_y.append((o.name, round(mid, 2)))
        if any(h in n for h in TAIL_HINTS):
            tail_y.append((o.name, round(mid, 2)))

    print("\n=== %s ===" % os.path.basename(path))
    print("  length Y %.2f (%.2f..%.2f)   span X %.2f   height Z %.2f"
          % (ymax - ymin, ymin, ymax, xmax - xmin, zmax - zmin))
    print("  nose-ish parts: %s" % (nose_y if nose_y else "none named"))
    print("  tail-ish parts: %s" % (tail_y if tail_y else "none named"))

    verdict = "UNKNOWN"
    if nose_y and tail_y:
        nm = sum(v for _, v in nose_y) / len(nose_y)
        tm = sum(v for _, v in tail_y) / len(tail_y)
        verdict = "OK (+Y nose)" if nm > tm else "BACKWARDS (-Y nose)"
        print("  nose mean Y %.2f vs tail mean Y %.2f" % (nm, tm))
    print("  VERDICT %s" % verdict)

print("\nMEASURE_DONE")
