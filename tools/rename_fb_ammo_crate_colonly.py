import bpy

OLD_OBJ  = "us_fb_ammo_crate_stack-colonly_P2"
NEW_OBJ  = "us_fb_ammo_crate_stack_P2-colonly"
OLD_MESH = "fb_ammo_crate_stack-colonly.002"
NEW_MESH = "fb_ammo_crate_stack_002-colonly"


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


print("MODE", bpy.context.mode)
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

sig = dict(loc=tuple(o.location), wloc=tuple(o.matrix_world.translation),
           rot=tuple(o.rotation_euler), scale=tuple(o.scale),
           parent=o.parent.name if o.parent else None,
           colls=[c.name for c in o.users_collection],
           verts=len(me.vertices), polys=len(me.polygons),
           mats=len(o.material_slots), hide_vp=o.hide_viewport, hide_r=o.hide_render,
           mesh_users=me.users)
print("SIG_BEFORE", sig)

o.name = NEW_OBJ
me.name = NEW_MESH

# assert the rename LANDED as asked - not as a .001 variant
assert o.name == NEW_OBJ, "object name became %r - collision happened" % o.name
assert me.name == NEW_MESH, "mesh name became %r - collision happened" % me.name
assert bpy.data.objects.get(OLD_OBJ) is None
assert bpy.data.meshes.get(OLD_MESH) is None

sig2 = dict(loc=tuple(o.location), wloc=tuple(o.matrix_world.translation),
            rot=tuple(o.rotation_euler), scale=tuple(o.scale),
            parent=o.parent.name if o.parent else None,
            colls=[c.name for c in o.users_collection],
            verts=len(me.vertices), polys=len(me.polygons),
            mats=len(o.material_slots), hide_vp=o.hide_viewport, hide_r=o.hide_render,
            mesh_users=me.users)
print("SIG_AFTER ", sig2)
assert sig == sig2, "something other than the name changed"

after = inventory("INVENTORY_AFTER_RENAME_PRESAVE")
assert before == after, "inventory drifted: %r vs %r" % (before, after)

# the contract the rename buys: it now matches clear_collision() AND still
# matches make_collision()'s skip. Assert both, in the exporter's own terms.
assert NEW_OBJ.endswith("-colonly"), "clear_collision would still miss it"
assert "-colonly" in NEW_OBJ, "make_collision would build a collider for a collider"
print("CONTRACT_OK endswith(-colonly)=True contains(-colonly)=True")

# NO purge. NO cleanup. Save in place, preserving zstd compression.
bpy.ops.wm.save_mainfile(compress=True)
print("SAVED", bpy.data.filepath)
