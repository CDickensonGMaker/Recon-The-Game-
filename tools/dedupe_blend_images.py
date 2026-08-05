"""Collapse duplicate image datablocks (name.001, name.002, ...) onto one copy.

    blender -b <file>.blend -P tools/dedupe_blend_images.py -- [--save]

WHY THIS EXISTS. Appending objects from us_base_v3.blend drags in that file's PACKED
images, and Blender makes a fresh copy on every append rather than reusing the one
already present. Re-running the chow hall crew builder six times left the firebase
truth source with 42 copies of `ref_factions` - a 3600x5700 reference sheet at 9.1 MB
each - and took the file from 9 MB to 398 MB on a disk that is nearly full.

A plain orphan purge does NOT fix it: 28 of those 42 are referenced by duplicate
materials, so only 130 MB of the 380 MB is unused.

SCOPED ON PURPOSE. This only merges datablocks whose names differ by a numeric
`.NNN` suffix, and only when the pixel dimensions match. It never touches a uniquely
named image. Never blanket-purge a shared file - that rule was bought on 8/2.
"""
import bpy
import re
import sys


def families():
    out = {}
    for img in bpy.data.images:
        root = re.sub(r"\.\d+$", "", img.name)
        out.setdefault(root, []).append(img)
    return {k: v for k, v in out.items() if len(v) > 1}


def image_nodes():
    trees = [m.node_tree for m in bpy.data.materials if m.node_tree]
    trees += [w.node_tree for w in bpy.data.worlds if w.node_tree]
    trees += [n.node_tree for n in bpy.data.node_groups]
    for t in trees:
        for n in t.nodes:
            if getattr(n, "image", None) is not None:
                yield n


def main():
    before_imgs = len(bpy.data.images)
    before_packed = sum(i.packed_file.size for i in bpy.data.images if i.packed_file)

    merged = 0
    freed = 0
    for root, imgs in sorted(families().items()):
        # Keep the one with the shortest name - the original, un-suffixed copy.
        imgs.sort(key=lambda i: (len(i.name), i.name))
        keep = imgs[0]
        drop = []
        for other in imgs[1:]:
            if tuple(other.size) != tuple(keep.size):
                continue                      # not actually the same picture
            drop.append(other)
        if not drop:
            continue
        dropset = set(drop)
        for node in image_nodes():
            if node.image in dropset:
                node.image = keep
        for d in drop:
            if d.packed_file:
                freed += d.packed_file.size
            bpy.data.images.remove(d)
            merged += 1
        print("  %-30s kept 1, merged %d" % (root, len(drop)))

    # Anything left with no user at all is now genuinely dead.
    orphans = [i for i in bpy.data.images if i.users == 0]
    for i in orphans:
        if i.packed_file:
            freed += i.packed_file.size
        bpy.data.images.remove(i)

    print("\n  images %d -> %d   (merged %d, dropped %d orphans)"
          % (before_imgs, len(bpy.data.images), merged, len(orphans)))
    print("  packed %.0f MB -> %.0f MB   (freed ~%.0f MB)"
          % (before_packed / 1e6,
             sum(i.packed_file.size for i in bpy.data.images if i.packed_file) / 1e6,
             freed / 1e6))

    if "--save" in sys.argv:
        bpy.ops.wm.save_mainfile(compress=True)
        print("  SAVED (compressed)", bpy.data.filepath)
    else:
        print("  dry run (pass --save to write)")


main()
