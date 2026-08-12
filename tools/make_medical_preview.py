"""Strip a copy of the firebase down to just the medical complex + its crew.

    # copy first - NEVER run this against the truth source
    cp firebase_v3.1_RECOVERED_medical.blend assets/shared/medical_preview.blend
    blender -b assets/shared/medical_preview.blend -P tools/make_medical_preview.py

Copy-and-strip, not append: appending re-links NLA strips, parenting and armature
modifiers, and 33 of the 40 crew carry their clip on an NLA strip rather than an
active action. Deleting everything else preserves all of that untouched.
"""
import bpy, os

KEEP = {"bld_medical_complex", "WORKBENCH_medical_tent"}

path = bpy.data.filepath
assert "RECOVERED" not in path, "refusing to run against the truth source"

keep_objs = set()
for cname in KEEP:
    c = bpy.data.collections.get(cname)
    if c is None:
        print("[MEDPREV] WARNING: %s missing" % cname)
        continue
    for o in c.objects:
        keep_objs.add(o)
        p = o.parent
        while p is not None:          # parents of a kept object must survive
            keep_objs.add(p)
            p = p.parent

# children of kept rigs (bodies) are already in WORKBENCH_medical_tent, but be safe
for o in list(keep_objs):
    for k in bpy.data.objects:
        if k.parent == o:
            keep_objs.add(k)

before = len(bpy.data.objects)
for o in list(bpy.data.objects):
    if o not in keep_objs:
        bpy.data.objects.remove(o, do_unlink=True)
print("[MEDPREV] objects %d -> %d" % (before, len(bpy.data.objects)))

# drop now-empty collections
for c in list(bpy.data.collections):
    if c.name not in KEEP and len(c.objects) == 0 and len(c.children) == 0:
        bpy.data.collections.remove(c)

# make sure what survived is linked into the scene and visible
scene_coll = bpy.context.scene.collection
for cname in KEEP:
    c = bpy.data.collections.get(cname)
    if c is None:
        continue
    if c.name not in [ch.name for ch in scene_coll.children]:
        try:
            scene_coll.children.link(c)
        except RuntimeError:
            pass

vl = bpy.context.view_layer
def walk(lc):
    lc.exclude = False
    lc.hide_viewport = False
    for ch in lc.children:
        walk(ch)
walk(vl.layer_collection)
for o in bpy.data.objects:
    o.hide_viewport = False
    o.hide_render = False

# longest clip drives the range so every loop plays through
end = 1
for a in bpy.data.actions:
    end = max(end, int(a.frame_range[1]))
sc = bpy.context.scene
sc.frame_start, sc.frame_end = 1, end
sc.frame_set(1)
sc.render.fps = 30

for m in bpy.data.meshes:
    if m.users == 0:
        bpy.data.meshes.remove(m)

bpy.ops.wm.save_mainfile(compress=True)
print("[MEDPREV] collections: %s" % sorted(c.name for c in bpy.data.collections))
print("[MEDPREV] actions: %d  frame range 1..%d @ %dfps"
      % (len(bpy.data.actions), end, sc.render.fps))
print("[MEDPREV] saved %s  %.1f MB" % (path, os.path.getsize(path) / 1048576.0))
