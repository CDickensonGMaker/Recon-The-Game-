"""The RTO: a grunt carrying the PRC-25 instead of his ruck. (bead i1vu)

    blender -b -P tools/make_rto.py

This is the first unit that exists ONLY because of the v3 gear-cut base. On
us_grunt_v2 the ruck was welded into the body mesh, so you could not take it off
a man - and an RTO is precisely a man with the ruck taken off and a radio put on.
Here it is three lines: delete `ruck_pack_worn`, append the PRC-25 from the gear
library, bone-attach it to the same Spine2.

The radio pieces are named radio / antenna / cord / handset, all of which are in
HitzoneBuilder._GEAR_NAME_HINTS, and they are rigid + unskinned - so the player
cannot shoot a man's ANTENNA and hurt his spine. They are also deliberately NOT
named `*_worn`: the exporter's body_bbox() measures the body plus its *_worn gear
to normalise height, and a 60cm whip antenna in that box would shrink the man to
fit his own aerial inside 1.7132 m.
"""
import bpy, os
from mathutils import Matrix

BASE = r"C:\Users\caleb\RECONgame\art_source\characters\base_psx\us_base_v3.blend"
GEAR = r"C:\Users\caleb\RECONgame\art_source\characters\base_psx\gear_library.blend"
OUT = r"C:\Users\caleb\RECONgame\art_source\characters\variants\us_rto.blend"
RIG = "PSXRig"

DROP = ["ruck_pack_worn"]                       # the ruck comes off
TAKE = ["prc25_radio_pack", "prc25_antenna", "prc25_cord", "prc25_handset"]


def main():
    bpy.ops.wm.open_mainfile(filepath=BASE)
    rig = bpy.data.objects[RIG]
    rig.data.pose_position = 'REST'
    bpy.context.view_layer.update()

    for n in DROP:
        o = bpy.data.objects.get(n)
        if o:
            bpy.data.objects.remove(o, do_unlink=True)
            print("  dropped %s (that is the whole point of the v3 base)" % n)

    before = set(bpy.data.objects)
    with bpy.data.libraries.load(GEAR, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n in TAKE or n == RIG]
    for o in dst.objects:
        if o is not None:
            bpy.context.scene.collection.objects.link(o)
    new = [o for o in bpy.data.objects if o not in before]

    lib_rig = next((o for o in new if o.type == 'ARMATURE'), None)
    if lib_rig is not None:
        lib_rig.data.pose_position = 'REST'
    bpy.context.view_layer.update()

    made = []
    for o in [x for x in new if x.type == 'MESH']:
        # Both blends share the SAME rest skeleton, so the library's world
        # placement transfers verbatim. Capture it, then re-hang the piece off
        # THIS rig's bone (world set after parenting - Blender solves the basis).
        keep = o.matrix_world.copy()
        bone = o.parent_bone
        o.parent = rig
        o.parent_type = 'BONE'
        o.parent_bone = bone
        o.matrix_parent_inverse = Matrix.Identity(4)
        bpy.context.view_layer.update()
        o.matrix_world = keep
        bpy.context.view_layer.update()
        ws = [o.matrix_world @ v.co for v in o.data.vertices]
        made.append((o.name, bone, len(o.data.polygons),
                     min(w.z for w in ws), max(w.z for w in ws)))

    if lib_rig is not None:
        bpy.data.objects.remove(lib_rig, do_unlink=True)

    rig.data.pose_position = 'POSE'
    if rig.animation_data:
        rig.animation_data.action = None
    bpy.context.scene.frame_set(1)

    print("\n%-20s %-10s %6s  %s" % ("piece", "bone", "tris", "world z"))
    for n, b, t, z0, z1 in made:
        print("%-20s %-10s %6d  %.3f..%.3f"
              % (n, b.replace("mixamorig:", ""), t, z0, z1))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=OUT)
    print("\nsaved:", OUT)


if __name__ == "__main__":
    main()
