"""STAGE THE THREE MEDICAL BODIES IN THE OWNER'S OPEN SESSION, for him to pass or fail.

Run inside his live Blender (BlenderMCP), or headless on any file:

    exec(open(r"tools/stage_medical_review.py").read())

STRICTLY ADDITIVE. It never opens a file, never saves, never selects or edits anything
that was already in the scene, and everything it makes lands in one collection called
`_MEDICAL_REVIEW`, so deleting that collection undoes the whole visit.

WHY THE PARANOIA IS THE POINT. `make_medic.main()` and `make_tent_bodies.main()` both
open with `wm.read_factory_settings(use_empty=True)`. Running either of them in his
session would throw away 133 MB of unsaved work. And both of them used to reach for
`bpy.data.objects` by name - which in HIS file finds seven other soldiers' helmets and
ammo pouches. Everything here is scoped to the objects it just imported.
"""
import bpy, os, sys
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.join(
    os.path.dirname(bpy.data.filepath) if bpy.data.filepath else ".", ""))
sys.path.insert(0, r"C:\Users\caleb\RECONgame\tools")

import make_medic as MM
import make_tent_bodies as TB

COLL = "_MEDICAL_REVIEW"
PITCH = 1.9          # metres between men. An A-pose body spans ~1.6 m: any less and
                     # the comparison is two figures inside each other.


def log(*a):
    print("[STAGE]", *a)


def collection():
    c = bpy.data.collections.get(COLL)
    if c is None:
        c = bpy.data.collections.new(COLL)
        bpy.context.scene.collection.children.link(c)
    return c


def import_scoped(path):
    """Import a GLB and return ONLY what it added."""
    before = set(o.name for o in bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o.name not in before]
    rig = next(o for o in new if o.type == 'ARMATURE')

    # Flatten the glTF Y-up root INTO THE NEW OBJECTS ONLY. The headless builders do
    # this with select_all(SELECT) + transform_apply, which in his session would apply
    # transforms to all 477 of his objects. Bake the matrices by hand instead.
    for o in new:
        if o.parent is None and o.type == 'EMPTY':
            root = o
            break
    else:
        root = None
    if root is not None:
        M = root.matrix_world.copy()
        for o in new:
            if o.parent is root:
                o.matrix_world = M @ o.matrix_world
                o.parent = None
        new.remove(root)
        bpy.data.objects.remove(root, do_unlink=True)
    for o in list(new):
        # Icosphere is the glTF importer's bone display shape - viewport furniture that
        # belongs in no exported file. Baked with the rest of the import it became a 6 m
        # white ball standing beside the medic, and only a screenshot caught it.
        # Base_Human is the un-skinned donor: it ships hidden, and a review row wants it
        # out of the way rather than lying at each man's feet.
        if (o.type == 'EMPTY' and not o.children) or o.name.startswith("Icosphere"):
            new.remove(o)
            bpy.data.objects.remove(o, do_unlink=True)
        elif o.name.startswith("Base_Human"):
            o.hide_set(True)

    # bake the rig's own rotation into rig + skinned data, so bone_attach solves in a
    # clean identity world (this is the bug that put the bag 1.96 m out, three times)
    # Each object applies ITS OWN world matrix - exactly what transform_apply does per
    # selected object. Multiplying the rig's matrix in on top of the mesh's applies the
    # glTF Y-up rotation twice, and the result is a bag that gates 24 covered instead
    # of 62 because the man is lying on his face relative to it.
    for o in new:
        M = o.matrix_world.copy()
        if o is rig:
            rig.data.transform(M)
        else:
            o.data.transform(M)
        o.matrix_world = Matrix.Identity(4)
    rig.data.pose_position = 'REST'
    if rig.animation_data:
        rig.animation_data.action = None
    bpy.context.view_layer.update()
    return rig, new


def adopt(objs, coll, x):
    for o in objs:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        coll.objects.link(o)
    # delta_location, not location: the rig's own transform stays identity so the rest
    # pose and every bone-parented piece are undisturbed.
    for o in objs:
        if o.parent is None:
            o.delta_location = Vector((x, 0.0, 0.0))


def stage():
    coll = collection()
    keep = set(o.name for o in bpy.data.objects)
    made = {}

    # ---- 1. THE FIELD MEDIC: squad rifleman + the fixed aid bag, no cross.
    rig, new = import_scoped(MM.BASE)
    rig.name = "REVIEW_medic_rig"
    body = next(o for o in new if o.name.startswith("us_grunt_joined"))
    bag = MM.build_medic(rig, body)
    new += bag
    adopt(new, coll, 0.0)
    made["us_medic"] = (rig, list(new))

    # ---- 2. THE TENT DOCTOR: bare-headed, no gear, blue-green shirt, brassard.
    rig2, new2 = import_scoped(TB.BASE)
    rig2.name = "REVIEW_doctor_rig"
    body2 = next(o for o in new2 if o.name.startswith("us_grunt_joined"))
    scope = [o for o in new2]
    TB.strip_gear(scope)
    # strip_gear removes objects, and a Python handle to a removed Object raises
    # ReferenceError on ANY attribute access - including `.name`. Re-collect from the
    # scene by identity instead of filtering the stale list.
    live = set(bpy.data.objects.values())
    new2 = [o for o in new2 if o in live]
    skinned = [o for o in new2 if o.type == 'MESH' and o.vertex_groups]
    TB.retint(skinned, TB.SHIRT_BONES, TB.flat("DoctorShirt", TB.SHIRT_RGB))
    TB.roll_sleeves(skinned, body2)
    band = TB.wrap("brassard_strap_l", rig2, body2, "LeftArm", "LeftForeArm",
                   t=0.42, half_h=0.028 * MM._skel_scale(rig2),
                   mat=TB.flat("BrassardGauze", TB.GAUZE_RGB))
    cross = TB.cross_patch("brassard_strap_cross", band,
                           TB.flat("BrassardCross", TB.CROSS_RGB))
    TB.lift_clear(cross, body2, 0.014 * MM._skel_scale(rig2))
    from probe_gear_fit import assert_clear
    assert_clear("doctor brassard", body2, [band, cross],
                 pmask=[False] * len(body2.data.polygons))
    TB.hang([band, cross], rig2, "mixamorig:LeftArm")
    new2 += [band, cross]
    adopt(new2, coll, PITCH)
    made["us_doctor"] = (rig2, list(new2))

    # ---- 3. THE MAN ON THE COT: no helmet, no gear, undershirt, chest dressing.
    rig3, new3 = import_scoped(TB.BASE)
    rig3.name = "REVIEW_patient_rig"
    body3 = next(o for o in new3 if o.name.startswith("us_grunt_joined"))
    TB.strip_gear([o for o in new3])
    live3 = set(bpy.data.objects.values())
    new3 = [o for o in new3 if o in live3]
    skinned3 = [o for o in new3 if o.type == 'MESH' and o.vertex_groups]
    TB.retint(skinned3, TB.SHIRT_BONES,
              TB.flat("PatientUndershirt", TB.UNDER_RGB))
    band3 = TB.wrap("dressing_strap_chest", rig3, body3, "Spine1", "Spine2",
                    t=0.65, half_h=0.055 * MM._skel_scale(rig3),
                    mat=TB.flat("DressingGauze", TB.GAUZE_RGB), sides=10)
    assert_clear("patient dressing", body3, [band3],
                 pmask=[False] * len(body3.data.polygons))
    TB.hang([band3], rig3, "mixamorig:Spine1")
    new3 += [band3]
    adopt(new3, coll, PITCH * 2.0)
    made["us_patient"] = (rig3, list(new3))

    # ---- THE GUARD. Nothing that was here before may have moved.
    touched = [n for n in keep if n in bpy.data.objects
               and bpy.data.objects[n].users_collection
               and coll in bpy.data.objects[n].users_collection]
    if touched:
        raise RuntimeError("staging adopted PRE-EXISTING objects: %s" % touched[:10])
    for n in keep:
        if n not in bpy.data.objects:
            raise RuntimeError("staging DELETED a pre-existing object: %s" % n)

    for name, (r, objs) in made.items():
        t = 0
        for o in objs:
            if o.type == 'MESH':
                o.data.calc_loop_triangles()
                t += len(o.data.loop_triangles)
        log("%-11s %5d tris   %2d meshes   rig %s" % (
            name, t, len([o for o in objs if o.type == 'MESH']), r.name))
    log("staged into collection %r. Delete that collection to undo the whole visit.")
    log("NOTHING SAVED, NOTHING EXPORTED.")
    return made


if __name__ == "__main__" or True:
    stage()
