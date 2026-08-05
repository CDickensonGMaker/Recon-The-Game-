"""Put the finished chow hall back into the firebase.

    blender -b "<firebase>.blend" -P tools/merge_chowhall_to_firebase.py -- [--save]

`tools/extract_chowhall.py` forked the chow hall out into its own file so it could be
iterated fast. This closes the fork: the copy inside the firebase is STALE and gets
replaced wholesale by the finished one.

WHY WHOLESALE AND NOT A PATCH. The chow hall changed shape completely - static eaters
deleted, a tent added, markers moved, trays re-parented, every rig re-animated. Trying
to reconcile object-by-object is how the two files diverged on 8/2 in the first place.
Delete the old, append the new, verify the counts.

Two files holding the same work is what lost the medical complex on 7/31. After this
runs, `chow_hall.blend` is the working copy and the firebase holds the shipped one -
re-run this after any further chow hall work.
"""
import bpy
import os
import re
import sys

SRC = (r"C:\Users\caleb\RECONgame\assets\world\building models\structures"
       r"\firebase\kit\chow_hall.blend")
COLLS = ("WORKBENCH_chowhall", "WORKBENCH_chowhall_rigs")


def dedupe_images():
    """Appending drags packed textures; Blender copies rather than reusing them.
    This took the firebase from 9 MB to 398 MB on 8/3."""
    fam = {}
    for img in bpy.data.images:
        fam.setdefault(re.sub(r"\.\d+$", "", img.name), []).append(img)

    def nodes():
        trees = [m.node_tree for m in bpy.data.materials if m.node_tree]
        trees += [w.node_tree for w in bpy.data.worlds if w.node_tree]
        trees += list(bpy.data.node_groups)
        for t in trees:
            for n in t.nodes:
                if getattr(n, "image", None) is not None:
                    yield n

    merged = 0
    for imgs in fam.values():
        if len(imgs) < 2:
            continue
        imgs.sort(key=lambda i: (len(i.name), i.name))
        keep = imgs[0]
        drop = {o for o in imgs[1:] if tuple(o.size) == tuple(keep.size)}
        if not drop:
            continue
        for nd in nodes():
            if nd.image in drop:
                nd.image = keep
        for d in drop:
            bpy.data.images.remove(d)
            merged += 1
    for i in [x for x in bpy.data.images if x.users == 0]:
        bpy.data.images.remove(i)
    return merged


def strip_the_men():
    """Caleb, 2026-08-03: "we dont really need those models in the scene since people
    will be coming up to this place and doing their animations there."

    The firebase ships the ROOM - tent, tables, benches, ranges, and the markers the
    NPCs walk to. The animated men, the trays in their hands, and the clips that drive
    them stay in `chow_hall.blend`, which is where the loop is authored and where it
    stays playable. Godot brings its own soldiers.
    """
    def descendants(o):
        out = []
        for c in bpy.data.objects:
            if c.parent is o:
                out.append(c)
                out += descendants(c)
        return out

    col = bpy.data.collections.get("WORKBENCH_chowhall")
    if col is None:
        return 0
    doomed = set()
    for a in [o for o in col.all_objects if o.type == 'ARMATURE']:
        doomed.add(a)
        doomed.update(descendants(a))
    # loop-only props: the trays that appear and vanish on visibility keys. The static
    # `fb_int_fb_tray_stack` on the counter is set dressing and stays.
    for o in col.all_objects:
        if o.name.startswith(("tray_pile_", "tray_seated_", "foodsurf_tray_seated_")):
            doomed.add(o)
            doomed.update(descendants(o))
    for o in list(doomed):
        bpy.data.objects.remove(o, do_unlink=True)
    for a in [x for x in bpy.data.actions if x.name.startswith("chow_")]:
        bpy.data.actions.remove(a)
    for o in col.all_objects:
        if o.animation_data:
            o.animation_data_clear()
        o.hide_viewport = o.hide_render = False
    for d in [m for m in bpy.data.meshes if m.users == 0]:
        bpy.data.meshes.remove(d)
    for d in [a for a in bpy.data.armatures if a.users == 0]:
        bpy.data.armatures.remove(d)
    return len(doomed)


def main():
    before_objs = len(bpy.data.objects)

    # 0. WHERE CALEB PUT IT. He sited the hall in the firebase on 8/3; the working copy
    # still has it parked out at y=-240. Step 1 deletes the root, so its transform has
    # to be carried across or every merge shoves the building back out of the base.
    _old = bpy.data.objects.get("WB_chowhall")
    placement = _old.matrix_world.copy() if _old else None
    if placement is not None:
        print("  keeping placement: (%.2f, %.2f, %.2f)" % tuple(placement.translation))

    # 1. rip out the stale chow hall
    killed = 0
    for cname in COLLS:
        c = bpy.data.collections.get(cname)
        if c is None:
            continue
        for o in list(c.all_objects):
            try:
                bpy.data.objects.remove(o, do_unlink=True)
                killed += 1
            except ReferenceError:
                pass
    for cname in COLLS:
        c = bpy.data.collections.get(cname)
        if c is not None:
            bpy.data.collections.remove(c)
    for a in [x for x in bpy.data.actions if x.name.startswith("chow_")]:
        bpy.data.actions.remove(a)
    print("  stale chow hall removed: %d objects" % killed)

    # 2. bring in the finished one
    with bpy.data.libraries.load(SRC, link=False) as (src, dst):
        dst.collections = [n for n in src.collections if n in COLLS]
        dst.actions = [n for n in src.actions if n.startswith("chow_")]
    root = bpy.context.scene.collection
    for c in bpy.data.collections:
        if c.name in COLLS and c.name not in root.children:
            try:
                root.children.link(c)
            except RuntimeError:
                pass
    for a in bpy.data.actions:
        if a.name.startswith("chow_"):
            a.use_fake_user = True

    stripped = strip_the_men()
    print("  stripped the animated men and their trays: %d objects" % stripped)

    new_root = bpy.data.objects.get("WB_chowhall")
    if new_root is not None and placement is not None:
        new_root.matrix_world = placement
        bpy.context.view_layer.update()
        print("  hall re-sited at (%.2f, %.2f, %.2f)" % tuple(placement.translation))

    ch = bpy.data.collections.get("WORKBENCH_chowhall")
    rg = bpy.data.collections.get("WORKBENCH_chowhall_rigs")
    print("  appended: %s (%d objs) | %s (%d objs)"
          % ("WORKBENCH_chowhall", len(ch.all_objects) if ch else 0,
             "WORKBENCH_chowhall_rigs", len(rg.all_objects) if rg else 0))
    print("  clips: %d" % len([a for a in bpy.data.actions
                               if a.name.startswith("chow_")]))
    if ch:
        men = [o for o in ch.all_objects if o.type == 'ARMATURE']
        tent = [o for o in ch.all_objects if o.name.startswith("tent_")]
        mk = [o for o in ch.all_objects if o.type == 'EMPTY']
        print("  men %d | tent pieces %d | markers %d" % (len(men), len(tent), len(mk)))

    n = dedupe_images()
    print("  images deduped: merged %d, now %d" % (n, len(bpy.data.images)))
    print("  objects %d -> %d" % (before_objs, len(bpy.data.objects)))

    if "--save" in sys.argv:
        bpy.ops.wm.save_mainfile(compress=True)
        print("  SAVED %s (%.1f MB)"
              % (bpy.data.filepath, os.path.getsize(bpy.data.filepath) / 1048576))
    else:
        print("  dry run (pass --save to write)")


main()
