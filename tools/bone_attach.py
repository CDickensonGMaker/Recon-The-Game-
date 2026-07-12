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


def _nearest(ob, point):
    """Distance from `point` to the CLOSEST vertex of `ob`.

    NOT the centre. A prc25_antenna is a metre-long whip that arcs up over the
    shoulder, so its CENTRE sits 0.84m from the spine it hangs on - and a centre-based
    check calls that "off the bone" and cries wolf. The question is not "is its midpoint
    near the bone", it is "does any part of this thing TOUCH the man". A prop that is
    genuinely detached is far from its bone by every vertex; a long prop is only far by
    its middle."""
    if ob.type != 'MESH' or not ob.data.vertices:
        return (ob.matrix_world.translation - point).length
    return min((ob.matrix_world @ v.co - point).length for v in ob.data.vertices)


def attach(ob, rig, bone, world=None, max_from_bone=0.35):
    """Hang `ob` rigidly on `rig`'s `bone`.

    world  -- the world matrix the object should END UP AT. Default = identity, which
              is right for anything whose verts are authored in WORLD/REST space (the
              whole locker, and every piece cut out of a body).
    max_from_bone -- sanity limit, measured to the CLOSEST vertex (see _nearest). A prop
              whose nearest point is this far from its bone is not attached, it is lying
              on the floor next to him. Raises rather than shipping it.

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
        d = _nearest(ob, head)
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


def verify_all(rig, expect=None, quiet=False):
    """Every bone-parented mesh on this rig: is it EXACTLY where it was authored?

    DISTANCE IS THE WRONG TEST, and I got there by trying it and watching it cry wolf
    twice in a row:
      * prc25_antenna is a metre-long whip - its CENTRE sits 0.84m from the spine, and
        a centre check called it detached.
      * carry_pole is a 6-sided tube with verts ONLY AT ITS TWO ENDS - so its NEAREST
        vertex to the spine is 0.52m away, even though the bar passes right over his
        shoulders. A nearest-vertex check called that detached too.
    Long props are far from their bone. Thin props have no vertices in the middle.
    There is no threshold that separates "detached" from "long", because the geometry
    of an honest prop is unbounded.

    THE REAL INVARIANT IS EXACT. Every locker prop is authored in WORLD/REST space, so
    once it is hung on its bone, its matrix_world must come back to IDENTITY. If it is
    anything else, it has been displaced - and that is exactly what the three shipped
    bugs were. No thresholds, no false alarms, no judgement call.

    expect -- the world matrix each prop should sit at. Default identity.
    """
    if expect is None:
        expect = Matrix.Identity(4)
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
        m = ob.matrix_world
        err = max(abs(m[i][j] - expect[i][j]) for i in range(4) for j in range(4))
        if err > 1e-3:
            bad.append((ob.name, ob.parent_bone, err))
        elif not quiet:
            print("    ok  %-22s on %s" % (ob.name, ob.parent_bone.replace("mixamorig:", "")))

    rig.data.pose_position = prev
    if rig.animation_data and prev_act is not None:
        rig.animation_data.action = prev_act
    bpy.context.view_layer.update()

    if bad:
        lines = ["*** %d BONE-PARENTED OBJECT(S) HAVE BEEN DISPLACED ***" % len(bad)]
        for n, b, e in bad:
            lines.append("      %-22s %-12s %s" % (
                n, b.replace("mixamorig:", ""),
                "NO SUCH BONE" if e < 0 else "matrix_world off by %.4f" % e))
        lines.append("    Their verts are authored in world/rest space, so attached they")
        lines.append("    must sit at IDENTITY. They do not. Attach via bone_attach.attach()")
        lines.append("    with the rig in REST - do not hand-roll matrix_parent_inverse.")
        raise AttachError("\n".join(lines))
    print("  bone-attach gate: %d props, all exactly where they were authored" % checked)
    return checked
