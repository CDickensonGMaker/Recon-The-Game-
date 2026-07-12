"""THE ARMORY: every prop racked on its own, so Caleb can work on the meshes.

    blender -b -P tools/make_gear_armory.py        (build the rack)
    blender -b -P tools/make_gear_armory.py -- pack   (fold his edits back in)

Same idea as the gun armory in weapons_us.blend: each piece laid out in the open where
you can see it and edit it, instead of buried on a character.

THE ONE THING THIS MUST NOT BREAK
Every locker prop's VERTICES are authored in WORLD/REST SPACE - that is the whole
contract, and it is why a prop hangs correctly off a bone with matrix_world = identity.
So the rack CANNOT move vertices. It moves the OBJECT (its transform) onto a rack slot
and leaves the mesh data untouched. Caleb edits geometry in that local space; `pack`
sets every object transform back to identity and re-attaches, and his edited geometry
lands exactly where the old geometry was.

    build  ->  unparent, record the bone in obj["attach_bone"], slide the object onto a
               rack slot. Mesh data NOT touched.
    pack   ->  location back to zero, re-attach to obj["attach_bone"] via bone_attach
               (which forces REST and checks itself), verify_all, save the locker.

The rig and the body stand at the origin as a size reference - hidden from selection so
you cannot grab them by accident.
"""
import bpy, sys, os
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bone_attach import attach, verify_all

LOCKER = r"C:\Users\caleb\RECONgame\art_source\characters\locker\gear_library.blend"
ARMORY = r"C:\Users\caleb\RECONgame\art_source\characters\locker\gear_armory.blend"
BODY_SRC = r"C:\Users\caleb\RECONgame\art_source\characters\base_psx\us_base_v3.blend"
RIG = "PSXRig"

COLS = 6
SPACING_X = 0.62
SPACING_Y = 0.70
RACK_Z = 1.05          # eye height: you are not crouching to look at a sickle


def bbox_centre(ob):
    vs = [v.co for v in ob.data.vertices]
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
        # slide the OBJECT so the mesh's bbox centre lands on the slot. The mesh data
        # is untouched - only obj.location moves - so `pack` can simply zero it again.
        ob.location = slot - bbox_centre(ob)
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
    print("PACKING %d props back onto the rig\n" % len(props))
    for ob in props:
        bone = ob["attach_bone"]
        # back to the authored space: the verts never moved, so identity puts the piece
        # exactly where it belongs.
        ob.location = Vector((0.0, 0.0, 0.0))
        ob.rotation_euler = (0.0, 0.0, 0.0)
        ob.scale = Vector((1.0, 1.0, 1.0))
        d = attach(ob, rig, bone)                 # forces REST, checks itself
        print("   %-22s -> %-12s ok" % (ob.name, bone.replace("mixamorig:", "")))

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
