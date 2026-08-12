"""Bake correct facing into the aircraft GLBs.

RECONgame convention: forward = Blender +Y == Godot -Z. Three airframes were
exported nose-to--Y and were being flipped 180 in their .tscn instead - the same
band-aid the Huey carried until real sockets shipped and it became a landmine.
There is no .blend source for any of them, so the fix has to be applied to the
GLB itself.

Also rescales ac47_spooky: measured 151.9m long / 196.3m span against a real
C-47's 19.43m / 29.41m.

Every file is verified after export by re-measuring the written GLB - counts of
meshes/materials/images must survive the round trip, and the nose must land at
+Y. Nothing is trusted; the export is read back.
"""
import bpy, sys, os, math
from mathutils import Matrix

AIR = r"C:\Users\caleb\RECONgame\assets\us\aircraft"

# file -> (rotate_180_z, uniform_scale)
JOBS = {
    "a1_skyraider.glb": (True, 1.0),
    "a4_skyhawk.glb": (True, 1.0),
    "a1_skyraider_crashed.glb": (True, 1.0),
    # 29.41m real wingspan / 196.31m measured = 0.1498
    "ac47_spooky.glb": (True, 0.1498),
    # f4_phantom.glb is already +Y nose - deliberately NOT in this list.
}


def survey():
    meshes = [o for o in bpy.data.objects if o.type == 'MESH' and len(o.data.vertices)]
    verts = sum(len(o.data.vertices) for o in meshes)
    return {
        "meshes": len(meshes),
        "verts": verts,
        "materials": len(bpy.data.materials),
        "images": len(bpy.data.images),
        "armatures": len([o for o in bpy.data.objects if o.type == 'ARMATURE']),
        "actions": len(bpy.data.actions),
    }


def bounds_y():
    lo, hi = 1e9, -1e9
    for o in bpy.data.objects:
        if o.type != 'MESH' or not len(o.data.vertices):
            continue
        for v in o.data.vertices:
            y = (o.matrix_world @ v.co).y
            lo = min(lo, y)
            hi = max(hi, y)
    return lo, hi


def nose_y(hints=("prop", "pitot", "spinner", "gunpod", "cockpit", "canopy")):
    ys = []
    for o in bpy.data.objects:
        if o.type != 'MESH' or not len(o.data.vertices):
            continue
        if not any(h in o.name.lower() for h in hints):
            continue
        vs = [(o.matrix_world @ v.co).y for v in o.data.vertices]
        ys.append(sum(vs) / len(vs))
    return (sum(ys) / len(ys)) if ys else None


ok_all = True
for fname, (rot180, scl) in JOBS.items():
    path = os.path.join(AIR, fname)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)

    before = survey()
    if before["armatures"] or before["actions"]:
        print("SKIP %s - has armature/actions (%d/%d); baking a transform could "
              "desync them. Needs hand work." % (fname, before["armatures"], before["actions"]))
        ok_all = False
        continue

    n0 = nose_y()
    y0 = bounds_y()

    M = Matrix.Identity(4)
    if rot180:
        M = Matrix.Rotation(math.pi, 4, 'Z') @ M
    if scl != 1.0:
        M = Matrix.Scale(scl, 4) @ M

    # Top-level only; children inherit through the hierarchy.
    for o in bpy.data.objects:
        if o.parent is None:
            o.matrix_world = M @ o.matrix_world

    bpy.ops.export_scene.gltf(
        filepath=path, export_format='GLB',
        use_selection=False, export_apply=True,
        export_yup=True)

    # ---- read the written file back; trust nothing ----
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    after = survey()
    n1 = nose_y()
    y1 = bounds_y()

    lost = [k for k in ("meshes", "materials", "images")
            if after[k] < before[k]]
    facing_ok = (n1 is not None) and (n1 > (y1[0] + y1[1]) * 0.5)

    print("\n%s" % fname)
    print("  meshes %d->%d  verts %d->%d  materials %d->%d  images %d->%d"
          % (before["meshes"], after["meshes"], before["verts"], after["verts"],
             before["materials"], after["materials"], before["images"], after["images"]))
    print("  length Y %.2f -> %.2f" % (y0[1] - y0[0], y1[1] - y1[0]))
    print("  nose mean Y %s -> %s (centre %.2f)"
          % ("%.2f" % n0 if n0 is not None else "n/a",
             "%.2f" % n1 if n1 is not None else "n/a",
             (y1[0] + y1[1]) * 0.5))
    if lost:
        print("  FAIL lost data: %s" % lost)
        ok_all = False
    elif not facing_ok:
        print("  FAIL nose is still behind centre")
        ok_all = False
    else:
        print("  OK nose forward of centre, no data lost")

print("\nFIX_%s" % ("OK" if ok_all else "PROBLEM"))
