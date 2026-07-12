# diff_glb.py - mesh-inventory diff of two GLBs (name, verts, dims, origin).
# Run: blender -b --python tools/diff_glb.py -- <old.glb> <new.glb>
import bpy
import sys

argv = sys.argv[sys.argv.index('--') + 1:]
OLD, NEW = argv[0], argv[1]


def inventory(path):
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=path)
    inv = {}
    for ob in bpy.data.objects:
        if ob.type != 'MESH':
            continue
        d = ob.dimensions
        w = ob.matrix_world.translation
        inv[ob.name] = (len(ob.data.vertices), (round(d.x, 3), round(d.y, 3), round(d.z, 3)),
                        (round(w.x, 3), round(w.y, 3), round(w.z, 3)))
    return inv


old = inventory(OLD)
new = inventory(NEW)
print("=== GLB DIFF ===")
print("OLD meshes: %d   NEW meshes: %d" % (len(old), len(new)))
for name in sorted(set(new) - set(old)):
    print("ADDED    %-24s verts=%-5d dims=%s at %s" % (name, new[name][0], new[name][1], new[name][2]))
for name in sorted(set(old) - set(new)):
    print("REMOVED  %-24s verts=%-5d dims=%s" % (name, old[name][0], old[name][1]))
for name in sorted(set(old) & set(new)):
    o, n = old[name], new[name]
    if o[0] != n[0] or o[1] != n[1]:
        print("CHANGED  %-24s verts %d->%d dims %s->%s" % (name, o[0], n[0], o[1], n[1]))
    elif o[2] != n[2]:
        dx = max(abs(a - b) for a, b in zip(o[2], n[2]))
        if dx > 0.02:
            print("MOVED    %-24s %s -> %s" % (name, o[2], n[2]))
print("=== DIFF END ===")
