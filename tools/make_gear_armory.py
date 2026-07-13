"""THE ARMORY: every prop racked on its own, so Caleb can work on the meshes.

    blender -b -P tools/make_gear_armory.py        (build the rack)
    blender -b -P tools/make_gear_armory.py -- pack   (fold his edits back in)

Same idea as the gun armory in weapons_us.blend: each piece laid out in the open where
you can see it and edit it, instead of buried on a character.

HOW THIS SURVIVES "ORIGIN TO GEOMETRY"
The first version of this tool assumed every prop's VERTICES stay in world/rest space,
so `pack` could just zero the object transform and everything would land back where it
belonged. That assumption was garbage, because Caleb does this:

    "i set the origin to the geometry because its easier to edit things that way"

...which is correct - it IS easier - and it moves the verts into local space while
keeping the world position identical. Under the old `pack`, that put the radio at his
FEET, because zeroing the transform of a re-originned mesh throws the position away.

So the rack no longer cares where the origin is. At build it records the exact world
translation it slid the prop by:

    obj["rack_delta"] = (the vector from the WORN position to the RACK slot)

and `pack` simply undoes that translation in WORLD space, bakes the object transform
into the vertices, and hangs the result at identity. Move the origin, scale it, rotate
it, apply transforms - none of it matters, because we never assume anything about the
object's local space. We only ever ask for its matrix_world.

    build  ->  unparent, record obj["attach_bone"] + obj["rack_delta"], slide onto a slot
    pack   ->  undo rack_delta in world, bake matrix into verts, attach at identity,
               verify_all, save the locker.

LEGACY PROPS: anything racked before rack_delta existed has no such key. For those we
recover the delta by comparing the prop's current world bbox centre against the same
prop's centre in gear_library.blend. Rebuild the rack once and this goes away.

The rig and the body stand at the origin as a size reference - hidden from selection so
you cannot grab them by accident.
"""
import bpy, sys, os
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bone_attach import attach, verify_all, AttachError

LOCKER = r"C:\Users\caleb\RECONgame\art_source\characters\locker\gear_library.blend"
ARMORY = r"C:\Users\caleb\RECONgame\art_source\characters\locker\gear_armory.blend"
BODY_SRC = r"C:\Users\caleb\RECONgame\art_source\characters\base_psx\us_base_v3.blend"
RIG = "PSXRig"

COLS = 6
SPACING_X = 0.62
SPACING_Y = 0.70
RACK_Z = 1.05          # eye height: you are not crouching to look at a sickle


def world_centre(ob):
    """The prop's bbox centre IN WORLD SPACE. Never ask where its origin is - that is
    Caleb's business, and he moves it, because origin-to-geometry is easier to model
    with. Only ever ask matrix_world."""
    vs = [ob.matrix_world @ v.co for v in ob.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return (lo + hi) * 0.5


def build():
    bpy.ops.wm.open_mainfile(filepath=LOCKER)
    rig = bpy.data.objects[RIG]
    rig.data.pose_position = 'REST'
    if rig.animation_data:
        rig.animation_data.action = None
    bpy.context.view_layer.update()

    props = [o for o in bpy.data.objects
             if o.type == 'MESH' and o.parent is rig and o.parent_type == 'BONE']
    props.sort(key=lambda o: o.name)

    # the body, at the origin, as a size reference
    before = set(bpy.data.objects)
    with bpy.data.libraries.load(BODY_SRC, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n == "us_grunt_joined"]
    for o in dst.objects:
        if o is None:
            continue
        bpy.context.scene.collection.objects.link(o)
        o.parent = None
        for m in list(o.modifiers):
            o.modifiers.remove(m)
        md = o.modifiers.new("Armature", 'ARMATURE')
        md.object = rig
        o.hide_select = True          # reference only. Do not let him grab it.
        o.display_type = 'TEXTURED'

    print("RACKING %d props (mesh data is NOT touched - only the object transform)\n" % len(props))
    print("%-22s %-12s %s" % ("prop", "bone", "rack slot"))
    for i, ob in enumerate(props):
        bone = ob.parent_bone
        ob["attach_bone"] = bone                  # remember where it came from
        # unparent, KEEPING its world transform (which is identity - verts are world space)
        world = ob.matrix_world.copy()
        ob.parent = None
        ob.matrix_world = world

        col, row = i % COLS, i // COLS
        slot = Vector((-((COLS - 1) * SPACING_X) * 0.5 + col * SPACING_X,
                       -1.30 - row * SPACING_Y,
                       RACK_Z))
        # Slide the OBJECT so the prop's world centre lands on the slot, and REMEMBER the
        # translation. pack() undoes exactly this, in world space, so it does not matter
        # what Caleb does to the origin in between.
        worn_centre = world_centre(ob)
        delta = slot - worn_centre
        ob.location = ob.location + delta
        ob["rack_delta"] = tuple(delta)
        ob.hide_select = False
        ob.display_type = 'TEXTURED'
        print("%-22s %-12s (%+.2f, %+.2f, %.2f)"
              % (ob.name, bone.replace("mixamorig:", ""), slot.x, slot.y, slot.z))

    bpy.ops.wm.save_as_mainfile(filepath=ARMORY)
    print("\nsaved:", ARMORY)
    print("Edit the meshes. Do NOT apply object transforms - `pack` zeroes them.")


def pack():
    """Fold his edited meshes back into the locker, on their bones, and gate it."""
    bpy.ops.wm.open_mainfile(filepath=ARMORY)
    rig = bpy.data.objects[RIG]
    props = [o for o in bpy.data.objects
             if o.type == 'MESH' and "attach_bone" in o.keys()]
    props.sort(key=lambda o: o.name)
    # legacy fallback: props racked before rack_delta existed
    legacy = [o for o in props if "rack_delta" not in o.keys()]
    worn = {}
    if legacy:
        print("%d prop(s) have no rack_delta (racked by the old tool). Recovering their")
        print("worn positions from gear_library.blend by bbox centre.\n" % len(legacy))
        tmp = bpy.data.objects[:]
        with bpy.data.libraries.load(LOCKER, link=False) as (src, dst):
            dst.objects = [o.name for o in legacy if o.name in src.objects]
        for o in dst.objects:
            if o is None:
                continue
            bpy.context.scene.collection.objects.link(o)
            bpy.context.view_layer.update()
            worn[o.name] = world_centre(o)
            bpy.data.objects.remove(o, do_unlink=True)

    print("PACKING %d props back onto the rig\n" % len(props))
    for ob in props:
        bone = ob["attach_bone"]
        if "rack_delta" in ob.keys():
            delta = Vector(tuple(ob["rack_delta"]))
        elif ob.name in worn:
            delta = world_centre(ob) - worn[ob.name]
        else:
            raise AttachError(
                "%s has no rack_delta and is not in the locker, so there is no way to "
                "know where it is WORN. Refusing to guess - it would land at his feet."
                % ob.name)

        # Undo the rack slide IN WORLD SPACE, then bake the whole transform into the
        # vertices. We never assume anything about the origin, so origin-to-geometry,
        # applied scales and rotations are all fine.
        ob.matrix_world = Matrix.Translation(-delta) @ ob.matrix_world
        bpy.context.view_layer.update()
        ob.data.transform(ob.matrix_world)
        ob.matrix_world = Matrix.Identity(4)
        bpy.context.view_layer.update()

        attach(ob, rig, bone)                 # forces REST, and checks itself
        print("   %-22s -> %-12s  (undid rack slide %.2f m)"
              % (ob.name, bone.replace("mixamorig:", ""), delta.length))

    # drop the reference body - it is not part of the locker
    body = bpy.data.objects.get("us_grunt_joined")
    if body:
        bpy.data.objects.remove(body, do_unlink=True)

    verify_all(rig)
    bpy.ops.wm.save_as_mainfile(filepath=LOCKER)
    print("\nsaved:", LOCKER)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    if argv and argv[0] == "pack":
        pack()
    else:
        build()
