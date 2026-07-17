"""fix_grunt_sockets.py - put the grunts' attach sockets where the GEAR actually is.

    blender -b -P tools/fix_grunt_sockets.py

THE BUG THIS FIXES
------------------
socket_head / socket_ruck / socket_radio were built by copying the gear object's
matrix_basis. But `helmet_shell_worn`'s OBJECT ORIGIN was never moved off the
grunt's world origin - only its GEOMETRY sits up at head height. So the socket
landed at (x, y, 0.000): on the floor, 1.75 m below the helmet it was supposed to
mark. Every helmet dropped on that socket would have spawned at his boots.

A socket must sit where the gear RENDERS, not where its origin happens to be.
So: measure the gear's evaluated geometric centre and put the socket there.
"""
import bpy
from mathutils import Vector, Matrix

LINEUP = r"C:\Users\caleb\RECONgame\assets\us\characters\us_v3_soldier_lineup.blend"
TAGS = ["rifleman", "grenadier", "mg", "rto", "marksman", "pointman"]

SOCKETS = {
    "socket_head":  ("helmet_shell_worn", "mixamorig:Head"),
    "socket_ruck":  ("ruck_pack_worn",    "mixamorig:Spine2"),
    "socket_radio": ("prc25_pack",        "mixamorig:Spine2"),
}

bpy.ops.wm.open_mainfile(filepath=LINEUP)
bpy.context.view_layer.update()

print("=== fixing sockets on %d grunts ===\n" % len(TAGS))
for tag in TAGS:
    rig = bpy.data.objects.get("PSXRig_" + tag)
    if rig is None:
        print("  %-10s NO RIG" % tag)
        continue

    for sname, (gear_base, bone) in SOCKETS.items():
        gear = bpy.data.objects.get(gear_base + "_" + tag)
        sock = bpy.data.objects.get(sname + "_" + tag)
        if gear is None:
            continue

        # where the gear RENDERS - not where its origin sits
        bb = [gear.matrix_world @ Vector(c) for c in gear.bound_box]
        ctr = sum(bb, Vector()) / 8

        if sock is None:
            sock = bpy.data.objects.new(sname + "_" + tag, None)
            sock.empty_display_type = 'ARROWS'
            sock.empty_display_size = 0.06
            sock.show_in_front = True
            for c in gear.users_collection:
                c.objects.link(sock)
                break
            else:
                bpy.context.scene.collection.objects.link(sock)

        before = sock.matrix_world.translation.copy()

        # bone-parent it, then put it AT the gear's centre with the gear's orientation
        sock.parent = rig
        sock.parent_type = 'BONE'
        sock.parent_bone = bone
        sock.matrix_parent_inverse = Matrix.Identity(4)
        bpy.context.view_layer.update()
        w = Matrix.Translation(ctr) @ gear.matrix_world.to_quaternion().to_matrix().to_4x4()
        sock.matrix_world = w
        bpy.context.view_layer.update()

        moved = (sock.matrix_world.translation - before).length
        pb = rig.pose.bones[bone]
        bone_w = rig.matrix_world @ pb.head
        above = (sock.matrix_world.translation - bone_w).length

        print("  %-10s %-13s moved %6.0f mm -> now %.0f mm from the %s bone"
              % (tag, sname, moved * 1000, above * 1000, bone.split(":")[1]))

bpy.context.view_layer.update()

print("\n=== verify: every socket is ON its gear ===")
bad = 0
for tag in TAGS:
    for sname, (gear_base, bone) in SOCKETS.items():
        gear = bpy.data.objects.get(gear_base + "_" + tag)
        sock = bpy.data.objects.get(sname + "_" + tag)
        if gear is None or sock is None:
            continue
        bb = [gear.matrix_world @ Vector(c) for c in gear.bound_box]
        ctr = sum(bb, Vector()) / 8
        d = (sock.matrix_world.translation - ctr).length * 1000
        if d > 1.0:
            bad += 1
            print("  *** %-10s %-13s %.1f mm OFF" % (tag, sname, d))
print("  %s" % ("all sockets sit on their gear" if bad == 0 else "%d sockets still off" % bad))

bpy.ops.wm.save_mainfile()
print("\nsaved %s" % LINEUP)
