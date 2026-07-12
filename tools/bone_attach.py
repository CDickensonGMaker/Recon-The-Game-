"""THE ONE WAY TO HANG A THING ON A BONE. Import this. Do not write your own.

    from bone_attach import attach, verify_all

This exists because the same bug shipped THREE TIMES, in three different files, and
every time it was a bone-parented object whose basis got solved in the wrong space:

    * make_base_v3.py      the grunt's helmet, ruck and bandolier landed in a pile at
                           his FEET (helmet at z 0.08 instead of 1.68)
    * make_gear_library.py the ENTIRE kit - radio, antenna, pouches, the lot - ended
                           up 1.5m out in front of him on the floor, with its verts
                           still saying "on his back"
    * make_civilian_anims  every prop on the workbench rig sat ~1 METRE off its bone.
                           Sickle 1.056m from the hand. Only a RENDER caught it.

Three times, because the attach logic was COPY-PASTED into six tools and each copy was
a fresh chance to get it wrong. It is now in one place, and it CHECKS ITSELF.

------------------------------------------------------------------------------
THE TWO TRAPS. Both are silent. Blender hands you a plausible transform either way.

TRAP 1 - THE TAIL OFFSET.
    Blender's bone parenting does NOT put the child at the bone's HEAD. It puts it at
    the bone's TAIL:
        world = arm_world @ bone_matrix @ Translate(0, bone_length, 0)
                @ parent_inverse @ basis
    So a hand-rolled `matrix_parent_inverse = (arm.matrix_world @ pose.matrix).inverted()`
    is MISSING the Translate(0, length, 0), and everything slides off by one bone
    length - which, chained up a skeleton, is how gear ends up on the floor.
    THE FIX: never hand-roll the inverse. Set parent_inverse to IDENTITY, parent, THEN
    assign matrix_world, and let Blender solve the basis itself. It knows about its own
    tail offset. We do not have to.

TRAP 2 - THE POSE THE BASIS IS SOLVED IN.
    `matrix_world = X` solves the basis against WHATEVER POSE THE RIG IS IN AT THAT
    MOMENT. Attach while the rig is posed - or worse, while an ACTION is driving it -
    and the offset is baked against a posed bone. It will look perfect in that pose and
    be a metre out in every other one.
    THE FIX: force REST, clear the action, FLUSH THE DEPSGRAPH, attach, restore.
    The flush matters: clearing the action does not take effect until the depsgraph is
    re-evaluated, so the first update after clearing still has the old action driving.
    (That same lag silently clobbered frame 1 of every animation clip.)
------------------------------------------------------------------------------
"""
import bpy
from mathutils import Vector, Matrix


class AttachError(RuntimeError):
    pass


def _centre(ob):
    if ob.type != 'MESH' or not ob.data.vertices:
        return ob.matrix_world.translation.copy()
    ws = [ob.matrix_world @ v.co for v in ob.data.vertices]
    return sum(ws, Vector()) / len(ws)


def attach(ob, rig, bone, world=None, max_from_bone=0.60):
    """Hang `ob` rigidly on `rig`'s `bone`.

    world  -- the world matrix the object should END UP AT. Default = identity, which
              is right for anything whose verts are authored in WORLD/REST space (the
              whole locker, and every piece cut out of a body).
    max_from_bone -- sanity limit. A prop more than this far from the bone it hangs on
              is not a prop, it is a bug. Raises rather than shipping it.

    Returns the measured distance from the object's centre to the bone head.
    """
    if bone not in rig.data.bones:
        raise AttachError("no bone %r on %s" % (bone, rig.name))
    if world is None:
        world = Matrix.Identity(4)

    # TRAP 2: force REST and kill the action, then FLUSH. Clearing the action does not
    # land until the depsgraph re-evaluates - the first update after still has the old
    # action driving, and would clobber what we set.
    prev_pos = rig.data.pose_position
    prev_act = rig.animation_data.action if rig.animation_data else None
    rig.data.pose_position = 'REST'
    if rig.animation_data:
        rig.animation_data.action = None
    bpy.context.view_layer.update()

    try:
        if ob.name not in bpy.context.scene.collection.all_objects:
            try:
                bpy.context.scene.collection.objects.link(ob)
            except RuntimeError:
                pass
        # TRAP 1: identity inverse, parent, THEN set world. Blender solves the basis
        # and it knows about its own tail offset.
        ob.parent = rig
        ob.parent_type = 'BONE'
        ob.parent_bone = bone
        ob.matrix_parent_inverse = Matrix.Identity(4)
        bpy.context.view_layer.update()
        ob.matrix_world = world
        bpy.context.view_layer.update()

        # ---- CHECK ITSELF. This is the part that was missing for three months.
        got = ob.matrix_world
        err = max(abs(got[i][j] - world[i][j]) for i in range(4) for j in range(4))
        if err > 1e-3:
            raise AttachError(
                "%s: matrix_world did not take (off by %.4f). The basis solve failed - "
                "almost always a stale depsgraph." % (ob.name, err))

        head = rig.matrix_world @ rig.data.bones[bone].head_local
        d = (_centre(ob) - head).length
        if d > max_from_bone:
            raise AttachError(
                "%s is %.3f m from bone %s (limit %.2f). It is not attached, it is "
                "LYING ON THE FLOOR NEXT TO HIM. This is the bug that shipped three "
                "times: the basis was solved in the wrong pose, or the parent inverse "
                "was hand-rolled and missed the bone's tail offset."
                % (ob.name, d, bone, max_from_bone))
        return d
    finally:
        rig.data.pose_position = prev_pos
        if rig.animation_data and prev_act is not None:
            rig.animation_data.action = prev_act
        bpy.context.view_layer.update()


def verify_all(rig, max_from_bone=0.60, quiet=False):
    """Every bone-parented mesh on this rig: is it actually ON its bone?

    Run this before you save ANY blend that has props on a rig. It is the gate that
    would have caught all three shipped instances of this bug on the spot, instead of
    a render catching it weeks later.
    """
    prev = rig.data.pose_position
    prev_act = rig.animation_data.action if rig.animation_data else None
    rig.data.pose_position = 'REST'
    if rig.animation_data:
        rig.animation_data.action = None
    bpy.context.view_layer.update()

    bad, checked = [], 0
    for ob in bpy.data.objects:
        if ob.type != 'MESH' or ob.parent is not rig or ob.parent_type != 'BONE':
            continue
        if not ob.parent_bone or ob.parent_bone not in rig.data.bones:
            bad.append((ob.name, ob.parent_bone or "<none>", -1.0))
            continue
        checked += 1
        head = rig.matrix_world @ rig.data.bones[ob.parent_bone].head_local
        d = (_centre(ob) - head).length
        if d > max_from_bone:
            bad.append((ob.name, ob.parent_bone, d))
        elif not quiet:
            print("    ok  %-22s %.3f m from %s"
                  % (ob.name, d, ob.parent_bone.replace("mixamorig:", "")))

    rig.data.pose_position = prev
    if rig.animation_data and prev_act is not None:
        rig.animation_data.action = prev_act
    bpy.context.view_layer.update()

    if bad:
        lines = ["\n*** %d BONE-PARENTED OBJECT(S) ARE NOT ON THEIR BONE ***" % len(bad)]
        for n, b, d in bad:
            lines.append("      %-22s %s  %s" % (
                n, b.replace("mixamorig:", ""),
                "NO SUCH BONE" if d < 0 else "%.3f m away" % d))
        lines.append("    They are lying on the floor next to him. Attach in REST via")
        lines.append("    bone_attach.attach() - do not hand-roll matrix_parent_inverse.")
        raise AttachError("\n".join(lines))
    print("  bone-attach gate: %d props, all on their bones" % checked)
    return checked
