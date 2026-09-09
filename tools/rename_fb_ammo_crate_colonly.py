"""Move the stray collider's `-colonly` marker to the END of its name so the export strips it.

    blender --background --factory-startup --python tools/rename_fb_ammo_crate_colonly.py

`us_fb_ammo_crate_stack-colonly_P2` is a 24-vert / 12-tri box hull with no UV layer and no
material slot, parented to `US_MC_crate_root_P2` at distance 0.0000 from the real crate
`us_fb_ammo_crate_stack_P2` (96 verts / 48 tris, `UVMap`, `fb_crate.013`). It is a collision
twin that escaped `clear_collision()` years ago: that function matches `endswith("-colonly")`
or `"-colonly." in name`, and a MIDDLE suffix matches neither. The same character-position
assumption defeats Godot's glTF importer, so it ships as a material-less mesh - a default
WHITE box z-fighting the textured crate in the P2 mortar pit.

Renaming it to `us_fb_ammo_crate_stack_P2` - the obvious fix - is WRONG: that name is already
the real crate's, Blender appends `.001` rather than refusing, and `make_collision` takes
`o.name.split(".")[0]`, so the untextured box would ship VISIBLE and collect a box collider of
its own. Strictly worse.

Moving the marker to the end instead makes `clear_collision()` finally match it, so the object
is removed from the session before `make_collision()` runs and before the exporter selects
anything: it ships nothing at all, the real crate keeps its own generated collider, and no
geometry leaves the artist's file. The mesh datablock loses its `.002` for the same reason the
object name is the way it is - `split(".")[0]` must never be able to eat the marker.
"""
import os
import sys

import bpy

OLD_OBJ  = "us_fb_ammo_crate_stack-colonly_P2"
NEW_OBJ  = "us_fb_ammo_crate_stack_P2-colonly"
OLD_MESH = "fb_ammo_crate_stack-colonly.002"
NEW_MESH = "fb_ammo_crate_stack_002-colonly"

BLEND = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                     "assets", "world", "building models", "structures", "firebase",
                     "kit", "firebase_v3.2.blend")


def inventory(tag):
    tris = 0
    verts = 0
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.data.calc_loop_triangles()
            tris += len(o.data.loop_triangles)
            verts += len(o.data.vertices)
    props = sum(len(o.keys()) for o in bpy.data.objects)
    inv = dict(objects=len(bpy.data.objects),
               mesh_objects=sum(1 for o in bpy.data.objects if o.type == 'MESH'),
               tris=tris, verts=verts,
               meshes=len(bpy.data.meshes), materials=len(bpy.data.materials),
               images=len(bpy.data.images), collections=len(bpy.data.collections),
               armatures=len(bpy.data.armatures), actions=len(bpy.data.actions),
               node_groups=len(bpy.data.node_groups),
               empties=sum(1 for o in bpy.data.objects if o.type == 'EMPTY'),
               obj_custom_prop_keys=props,
               scene_objects=len(bpy.context.scene.objects))
    print(tag, inv)
    return inv


def signature(o):
    me = o.data
    return dict(loc=tuple(o.location), wloc=tuple(o.matrix_world.translation),
                rot=tuple(o.rotation_euler), scale=tuple(o.scale),
                parent=o.parent.name if o.parent else None,
                colls=sorted(c.name for c in o.users_collection),
                verts=len(me.vertices), polys=len(me.polygons),
                mats=len(o.material_slots), hide_vp=o.hide_viewport, hide_r=o.hide_render,
                mesh_users=me.users)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    blend = BLEND
    for i, a in enumerate(argv):
        if a == "--blend" and i + 1 < len(argv):
            blend = argv[i + 1]
    if not os.path.exists(blend):
        raise SystemExit("canon blend not found: %s" % blend)

    # HIS LAW: no .blend backups. --factory-startup restores the stock save_version of 1,
    # which would drop a 50 MB firebase_v3.2.blend1 beside the file the moment we save.
    bpy.context.preferences.filepaths.save_version = 0

    bpy.ops.wm.open_mainfile(filepath=blend)
    print("MODE", bpy.context.mode, "FILE", bpy.data.filepath)
    assert bpy.context.mode == 'OBJECT', "must be in OBJECT mode"

    before = inventory("INVENTORY_BEFORE")

    # PRE-FLIGHT: never assign a name that is already taken. Blender does not refuse;
    # it appends .001 and reports success. That is what killed the first prescribed fix.
    o = bpy.data.objects.get(OLD_OBJ)
    assert o is not None, "source object missing"
    assert bpy.data.objects.get(NEW_OBJ) is None, "TARGET OBJECT NAME ALREADY TAKEN - abort"
    assert bpy.data.meshes.get(NEW_MESH) is None, "TARGET MESH NAME ALREADY TAKEN - abort"
    me = o.data
    assert me.name == OLD_MESH, "unexpected mesh datablock %r" % me.name

    # The whole point of the fix: it must be in the SCENE, because clear_collision()
    # iterates bpy.context.scene.objects, not bpy.data.objects.
    assert o.name in bpy.context.scene.objects, "not in scene - clear_collision would never see it"

    sig = signature(o)
    print("SIG_BEFORE", sig)

    o.name = NEW_OBJ
    me.name = NEW_MESH

    # assert the rename LANDED as asked - not as a .001 variant
    assert o.name == NEW_OBJ, "object name became %r - collision happened" % o.name
    assert me.name == NEW_MESH, "mesh name became %r - collision happened" % me.name
    assert bpy.data.objects.get(OLD_OBJ) is None
    assert bpy.data.meshes.get(OLD_MESH) is None

    sig2 = signature(o)
    print("SIG_AFTER ", sig2)
    assert sig == sig2, "something other than the name changed"

    after = inventory("INVENTORY_AFTER_RENAME_PRESAVE")
    assert before == after, "inventory drifted: %r vs %r" % (before, after)

    # the contract the rename buys: clear_collision() now matches it, and make_collision()
    # still skips it. Assert both, in the exporter's own terms.
    assert NEW_OBJ.endswith("-colonly"), "clear_collision would still miss it"
    assert "-colonly" in NEW_OBJ, "make_collision would build a collider for a collider"
    assert "-colonly" not in NEW_OBJ.split("-colonly")[0], "marker is not unique in the name"
    print("CONTRACT_OK endswith(-colonly)=True contains(-colonly)=True")

    # NO purge. NO cleanup. Save in place, preserving zstd compression (save_mainfile does
    # not inherit the source file's compression in background mode).
    bpy.ops.wm.save_mainfile(filepath=blend, compress=True)
    print("SAVED", bpy.data.filepath)

    # Re-open the file we just wrote and prove the rename is IN THE BYTES, not just the session.
    bpy.ops.wm.read_homefile(use_empty=True)
    bpy.ops.wm.open_mainfile(filepath=blend)
    reread = inventory("INVENTORY_AFTER_REOPEN")
    assert reread == before, "reopened file drifted: %r vs %r" % (reread, before)
    ro = bpy.data.objects.get(NEW_OBJ)
    assert ro is not None, "rename did not survive the save"
    assert bpy.data.objects.get(OLD_OBJ) is None, "old name still in the file"
    assert signature(ro) == sig, "reopened object drifted"
    strays = [x.name for x in bpy.data.objects
              if "-colonly" in x.name and not x.name.endswith("-colonly")]
    assert not strays, "mid-name -colonly still in the blend: %s" % strays
    print("VERIFIED_ON_DISK", repr(ro.name), "mesh", repr(ro.data.name))


if __name__ == "__main__":
    main()
