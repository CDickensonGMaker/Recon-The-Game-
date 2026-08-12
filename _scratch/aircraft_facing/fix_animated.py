"""Reorient the ANIMATED aircraft GLBs without touching their animation.

a1_skyraider, a1_skyraider_crashed and ac47_spooky carry actions (propeller
spin and similar). Baking a rotation into the objects themselves would rewrite
the transforms those curves drive, so instead everything is parented under a new
root node that carries the 180 deg yaw (and Spooky's rescale). The animation
curves stay in local space and are never edited; the root reorients the whole
airframe on top of them.

The written file is read back and re-measured. Nothing is trusted.
"""
import bpy, os, math
from mathutils import Matrix

AIR = r"C:\Users\caleb\RECONgame\assets\us\aircraft"
JOBS = {
    "a1_skyraider.glb": (True, 1.0),
    "a1_skyraider_crashed.glb": (True, 1.0),
    "ac47_spooky.glb": (True, 0.1498),
}
HINTS = ("prop", "pitot", "spinner", "gunpod", "cockpit", "canopy")


def survey():
    meshes = [o for o in bpy.data.objects if o.type == 'MESH' and len(o.data.vertices)]
    return {"meshes": len(meshes),
            "verts": sum(len(o.data.vertices) for o in meshes),
            "materials": len(bpy.data.materials),
            "images": len(bpy.data.images),
            "actions": len(bpy.data.actions)}


def bounds_y():
    lo, hi = 1e9, -1e9
    for o in bpy.data.objects:
        if o.type != 'MESH' or not len(o.data.vertices):
            continue
        for v in o.data.vertices:
            y = (o.matrix_world @ v.co).y
            lo, hi = min(lo, y), max(hi, y)
    return lo, hi


def nose_y():
    ys = []
    for o in bpy.data.objects:
        if o.type != 'MESH' or not len(o.data.vertices):
            continue
        if not any(h in o.name.lower() for h in HINTS):
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
    n0, y0 = nose_y(), bounds_y()

    root = bpy.data.objects.new("AirframeRoot", None)
    bpy.context.collection.objects.link(root)
    M = Matrix.Identity(4)
    if rot180:
        M = Matrix.Rotation(math.pi, 4, 'Z') @ M
    if scl != 1.0:
        M = Matrix.Scale(scl, 4) @ M
    root.matrix_world = M

    # Parent WITHOUT keep-transform: children must inherit the root's yaw.
    for o in list(bpy.data.objects):
        if o is root or o.parent is not None:
            continue
        o.parent = root
        o.matrix_parent_inverse = Matrix.Identity(4)

    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB',
                              use_selection=False, export_apply=False,
                              export_yup=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    after = survey()
    n1, y1 = nose_y(), bounds_y()
    centre = (y1[0] + y1[1]) * 0.5

    lost = [k for k in ("meshes", "materials", "images", "actions")
            if after[k] < before[k]]
    facing_ok = (n1 is not None) and (n1 > centre)

    print("\n%s" % fname)
    print("  meshes %d->%d  verts %d->%d  materials %d->%d  actions %d->%d"
          % (before["meshes"], after["meshes"], before["verts"], after["verts"],
             before["materials"], after["materials"], before["actions"], after["actions"]))
    print("  length Y %.2f -> %.2f" % (y0[1] - y0[0], y1[1] - y1[0]))
    print("  nose mean Y %.2f -> %.2f (centre %.2f)"
          % (n0 if n0 is not None else 0.0, n1 if n1 is not None else 0.0, centre))
    if lost:
        print("  FAIL lost: %s" % lost)
        ok_all = False
    elif not facing_ok:
        print("  FAIL nose still behind centre")
        ok_all = False
    else:
        print("  OK nose forward, animation actions intact")

print("\nFIXANIM_%s" % ("OK" if ok_all else "PROBLEM"))
