"""Cut the chow hall out of the firebase into its own working file.

    blender -b "<firebase>.blend" -P tools/extract_chowhall.py -- [--save]

Caleb, 2026-08-03: *"lets save everything in this firebase window and than transplant
the chow hall into its own file and lets keep working on it."*

Iterating on the chow hall inside a 1,900-object firebase is slow and risks the rest of
the compound. This lifts `WORKBENCH_chowhall` + `WORKBENCH_chowhall_rigs` + the `chow_*`
clips into `chow_hall.blend` and drops everything else.

FORK WARNING. The moment this file exists, the chow hall inside
`firebase_v3.1_RECOVERED_medical.blend` is the STALE copy. Work here, and transplant
back with `tools/merge_chowhall_to_firebase.py` before any firebase export. Two files
holding the same work is exactly how the medical complex was lost on 7/31.

A blanket orphan purge is safe HERE and only here: this is a derived file we own
outright, not the shared truth source.
"""
import bpy
import os
import sys

KEEP_COLLECTIONS = ("WORKBENCH_chowhall", "WORKBENCH_chowhall_rigs")
KEEP_ACTION_PREFIX = "chow_"
OUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "assets", "world", "building models", "structures", "firebase", "kit",
    "chow_hall.blend")


def main():
    src = bpy.data.filepath
    keep_objs = set()
    for name in KEEP_COLLECTIONS:
        c = bpy.data.collections.get(name)
        if c is None:
            print("  !! missing collection %s - aborting" % name)
            return
        keep_objs |= set(c.all_objects)
    print("  keeping %d objects from %s" % (len(keep_objs), ", ".join(KEEP_COLLECTIONS)))

    # Anything a kept object depends on by parenting or constraint must come too,
    # or trays lose their CHILD_OF target and men lose their anchor empty.
    grew = True
    while grew:
        grew = False
        for o in list(keep_objs):
            deps = []
            if o.parent:
                deps.append(o.parent)
            for con in o.constraints:
                t = getattr(con, "target", None)
                if t:
                    deps.append(t)
            for m in o.modifiers:
                t = getattr(m, "object", None)
                if t:
                    deps.append(t)
            for d in deps:
                if d and d not in keep_objs:
                    keep_objs.add(d)
                    grew = True
    print("  after dependency closure: %d objects" % len(keep_objs))

    dead = [o for o in bpy.data.objects if o not in keep_objs]
    for o in dead:
        bpy.data.objects.remove(o, do_unlink=True)
    print("  removed %d objects" % len(dead))

    # Re-home everything under the scene root, then drop every other collection.
    root = bpy.context.scene.collection
    for o in keep_objs:
        try:
            for c in list(o.users_collection):
                c.objects.unlink(o)
        except ReferenceError:
            continue
    kept_colls = []
    for name in KEEP_COLLECTIONS:
        c = bpy.data.collections.get(name)
        if c:
            kept_colls.append(c)
    for c in list(bpy.data.collections):
        if c not in kept_colls:
            bpy.data.collections.remove(c)
    for c in kept_colls:
        if c.name not in root.children:
            try:
                root.children.link(c)
            except RuntimeError:
                pass
    for o in keep_objs:
        try:
            if not o.users_collection:
                kept_colls[0].objects.link(o)
        except ReferenceError:
            pass

    for a in list(bpy.data.actions):
        if not a.name.startswith(KEEP_ACTION_PREFIX):
            bpy.data.actions.remove(a)
        else:
            a.use_fake_user = True

    # Safe here - derived file we own outright. NEVER do this in the truth source.
    for _ in range(4):
        bpy.ops.outliner.orphans_purge(do_local_ids=True, do_linked_ids=True,
                                       do_recursive=True)

    print("\n  objects %d | collections %d | actions %d | images %d | meshes %d"
          % (len(bpy.data.objects), len(bpy.data.collections), len(bpy.data.actions),
             len(bpy.data.images), len(bpy.data.meshes)))
    print("  clips:", sorted(a.name for a in bpy.data.actions))
    rigs = [o for o in bpy.data.objects if o.type == 'ARMATURE']
    trays = [o for o in bpy.data.objects if o.name.startswith(("tray_base", "food_0"))]
    print("  men: %d | tray parts: %d" % (len(rigs), len(trays)))

    if "--save" in sys.argv:
        bpy.ops.wm.save_as_mainfile(filepath=OUT, compress=True)
        print("  SAVED %s  (%.1f MB)" % (OUT, os.path.getsize(OUT) / 1048576))
        print("  source untouched:", src)
    else:
        print("  dry run (pass --save to write)")


main()
