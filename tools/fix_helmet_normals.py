"""fix_helmet_normals.py - black patches on the helmets.

    blender -b -P tools/fix_helmet_normals.py -- [--apply]

THE CAUSE: CUSTOM SPLIT NORMALS carried in from the reference OBJ. They were authored
for an 8790-triangle smooth mesh, survived the decimate down to 489 faces, and now
describe a surface that no longer exists - so faces shade as though they were angled
somewhere else, which reads as dark blotches on every helmet, because every helmet
shares that geometry. Winding is clean (0 inconsistent faces), the mesh has no
zero-area faces, no doubled verts and nothing stacked; it is purely the stale normals.

Anything imported and then decimated must have its custom normals cleared, or it is
lit as the mesh it used to be.

Two further guards, measured rather than assumed:

  1. INCONSISTENT NORMALS. The shell is decimated from a reference mesh; a decimate can
     leave faces wound against their neighbours, and a face lit from behind renders
     black. Counting faces that a recalc would flip is the honest test - "how many point
     inward from the centroid" is not, because the underside of a brim legitimately does.

  2. COINCIDENT TWINS. reshape_welded_helmet.py gave helmet_camo_shell the SAME mesh at
     the SAME transform as helmet_shell_worn, so the two are exactly co-planar. They are
     both meant to be hidden on a living man (model_actor.gd:512-535 hides gib donors,
     grunt_dresser hides the stock), but anything that shows both at once Z-fights, and
     the hung variant shares that geometry too. The donor is shrunk fractionally so the
     surfaces can never be co-planar again.
"""
import bpy, bmesh, sys

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
APPLY = "--apply" in ARGV
BASE = r"C:\Users\caleb\RECONgame\assets\us\characters\us_base_v3.blend"
VAR = r"C:\Users\caleb\RECONgame\assets\us\characters\helmet_variants.blend"
DONOR_SHRINK = 0.985     # gib donor sits just inside the shell it duplicates


def flipped_count(me):
    """How many faces would a recalc turn around? That is the real inconsistency."""
    bm = bmesh.new()
    bm.from_mesh(me)
    before = [f.normal.copy() for f in bm.faces]
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.faces.ensure_lookup_table()
    n = 0
    for i, f in enumerate(bm.faces):
        if f.normal.dot(before[i]) < 0.0:
            n += 1
    bm.free()
    return n


def fix_mesh(me):
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.update()


for path, label, dst_suffix in ((BASE, "us_base_v3", "_NORMFIX"),
                                (VAR, "helmet_variants", "_NORMFIX")):
    bpy.ops.wm.open_mainfile(filepath=path)
    print("\n##### %s #####" % label)
    targets = [o for o in bpy.data.objects
               if o.type == 'MESH' and (o.name.startswith("helmet_") or
                                        o.name.endswith(("_cover", "_band")))]
    seen = set()
    total_before = 0
    total_after = 0
    cleared = 0
    for o in sorted(targets, key=lambda x: x.name):
        if o.data.name in seen:
            continue
        seen.add(o.data.name)
        b = flipped_count(o.data)
        total_before += b
        if b:
            fix_mesh(o.data)
        a = flipped_count(o.data)
        total_after += a
        if b:
            print("  %-34s faces wound against neighbours: %d -> %d" % (o.name, b, a))

        # the actual black-spot cause: normals authored for the reference mesh
        if o.data.has_custom_normals:
            bpy.ops.object.select_all(action='DESELECT')
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
            bpy.ops.mesh.customdata_custom_splitnormals_clear()
            cleared += 1
            print("  %-34s cleared stale custom split normals (has_custom=%s)"
                  % (o.name, o.data.has_custom_normals))
    print("  %d mesh datablocks checked, %d inconsistent faces -> %d, %d had stale custom normals"
          % (len(seen), total_before, total_after, cleared))
    left = [o.name for o in targets if o.data.has_custom_normals]
    print("  still carrying custom normals: %s" % (left if left else "none"))

    if label == "us_base_v3":
        n = 0
        for o in bpy.data.objects:
            if o.type == 'MESH' and o.name.startswith("helmet_camo_shell"):
                o.scale = (DONOR_SHRINK, DONOR_SHRINK, DONOR_SHRINK)
                n += 1
        print("  %d gib donors shrunk to %.3f so they can never be co-planar "
              "with the shell they duplicate" % (n, DONOR_SHRINK))

    out = path if APPLY else path.replace(".blend", dst_suffix + ".blend")
    bpy.ops.wm.save_as_mainfile(filepath=out)
    print("  wrote %s" % out)
