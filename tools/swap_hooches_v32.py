"""Replace the 8 baked fb_hootch_i shells in firebase_v3.2.blend with the new screened hooch.

The old hooches are NOT placed by code - they are baked into the firebase mesh, so
there is no path to repoint. They have to be deleted here and the new one instanced
in their spots.

    # look, change nothing:
    blender -b <firebase_v3.2.blend> -P tools/swap_hooches_v32.py -- --probe

    # do it:
    blender -b <firebase_v3.2.blend> -P tools/swap_hooches_v32.py -- --apply

Or import it over the MCP bridge and call probe() / apply() against the live session,
which is how this is meant to run while Caleb watches. NEVER open the firebase over
the bridge - wm.open_mainfile rebuilds the bpy.data the handler is running inside and
crashes Blender a few calls later. He opens it; we drive it.

Positions and rotations are MEASURED off the old shells in this file, never converted
from the GLB - the glTF Y-up swap is one sign error away from putting eight buildings
underground, and the blend is the truth source anyway.
"""
import bpy, os, math
from mathutils import Vector

SRC = r"C:\Users\caleb\RECONgame\assets\shared\hooch_workbench.blend"
OLD_PREFIX = "fb_hootch_i"
# what the new building is made of, in the source file
WANT_COLLECTIONS = ("HOOCH_ASSEMBLY", "MARKERS_hooch")
# staging that must NOT come across: the animation bench, the damaged variant and the
# loose kit parts all sit off to the side of the workbench scene.
SKIP_COLLECTIONS = ("ANIM_BENCH_HOOCH", "HOOCH_DAMAGED", "HOOCH_STAGE")
# the new hooch is centred here in the workbench scene, measured not assumed
SRC_CENTRE = Vector((-25.000, 94.999, 0.0))


def _mesh_bounds(objs):
    vs = []
    for o in objs:
        if o.type == 'MESH':
            vs += [o.matrix_world @ v.co for v in o.data.vertices]
    if not vs:
        return None
    return (min(v.x for v in vs), max(v.x for v in vs),
            min(v.y for v in vs), max(v.y for v in vs),
            min(v.z for v in vs), max(v.z for v in vs))


def old_shells():
    """Every object belonging to an old hooch, grouped by shell index.

    Both the visible shell and its -colonly twin must go. Leaving a colonly behind
    is the dangerous half: an invisible collider that still blocks nav and still
    stops bullets, with nothing on screen to explain it.
    """
    groups = {}
    for o in bpy.data.objects:
        if not o.name.startswith(OLD_PREFIX):
            continue
        key = o.name.replace("-colonly", "").split("_")[-1]
        groups.setdefault(key, []).append(o)
    return groups


def probe():
    groups = old_shells()
    total = sum(len(v) for v in groups.values())
    print("[SWAP] %d old hooch objects in %d groups" % (total, len(groups)))
    spots = []
    for key in sorted(groups):
        objs = groups[key]
        b = _mesh_bounds(objs)
        if b is None:
            print("   group %-8s %d objs  (no mesh - colonly only?)" % (key, len(objs)))
            continue
        cx, cy = (b[0] + b[1]) / 2, (b[2] + b[3]) / 2
        # a shell's yaw, read off the object transform rather than reconstructed
        yaw = 0.0
        for o in objs:
            if o.type == 'MESH' and "colonly" not in o.name:
                yaw = o.matrix_world.to_euler('XYZ').z
                break
        spots.append((cx, cy, b[4], yaw))
        print("   group %-8s %d objs  centre (%8.2f,%8.2f)  base z=%6.2f  "
              "size %.2f x %.2f x %.2f  yaw=%7.1f deg" % (
                  key, len(objs), cx, cy, b[4],
                  b[1] - b[0], b[3] - b[2], b[5] - b[4], math.degrees(yaw)))
    print("[SWAP] new hooch is 5.78 x 10.97 x 3.05 - LONGER than the old 5.20 x 7.70 x 2.56")
    return spots


def _append_new():
    """Bring the new hooch across as its own collection, once."""
    existing = bpy.data.collections.get("HOOCH_NEW")
    if existing:
        print("[SWAP] HOOCH_NEW already present, reusing")
        return existing
    holder = bpy.data.collections.new("HOOCH_NEW")
    bpy.context.scene.collection.children.link(holder)
    with bpy.data.libraries.load(SRC, link=False) as (src, dst):
        dst.collections = [c for c in src.collections if c in WANT_COLLECTIONS]
    for c in dst.collections:
        if c is None or c.name in SKIP_COLLECTIONS:
            continue
        holder.children.link(c)
    n = sum(len(c.objects) for c in holder.children)
    print("[SWAP] appended %d objects across %d collections"
          % (n, len(list(holder.children))))
    return holder


def apply():
    spots = probe()
    if not spots:
        print("[SWAP] FATAL: found no old hooches - wrong file?")
        return
    holder = _append_new()

    # instance the appended collection once per old spot, then delete the old shells.
    # Deleting LAST means a crash mid-run leaves the firebase intact rather than
    # stripped of eight buildings with nothing standing in their place.
    for i, (cx, cy, bz, yaw) in enumerate(spots):
        inst = bpy.data.objects.new("hooch_new_%02d" % i, None)
        inst.instance_type = 'COLLECTION'
        inst.instance_collection = holder
        inst.location = (cx - SRC_CENTRE.x, cy - SRC_CENTRE.y, bz)
        inst.rotation_euler = (0.0, 0.0, yaw)
        bpy.context.scene.collection.objects.link(inst)
        print("[SWAP] placed hooch_new_%02d at (%.2f,%.2f,%.2f) yaw %.1f"
              % (i, cx, cy, bz, math.degrees(yaw)))

    groups = old_shells()
    gone = 0
    for objs in groups.values():
        for o in objs:
            bpy.data.objects.remove(o, do_unlink=True)
            gone += 1
    print("[SWAP] removed %d old hooch objects" % gone)
    print("[SWAP] NOT SAVED - check it, then save yourself")


if __name__ == "__main__":
    import sys
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--apply" in argv:
        apply()
    else:
        probe()
