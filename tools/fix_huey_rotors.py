"""Balance the Huey rotors in a staging .blend.

The shipped assets/us/vehicles/huey.glb is CORRECT -- it carries New_Blade_2 and
New_TailBlade_2.001. The staging scenes were built from a subset and lost the second
blade on both rotors, so each pivot swung a single paddle around in a wide circle
(main rotor centroid 3.578 m off axis, tail 0.526 m) instead of turning a disc.

This centres the surviving blade's chord on the spin axis, puts its root on the axis,
and adds a linked-duplicate blade 180 deg opposite. Linked, so reshaping one blade
updates the twin. Idempotent -- re-running removes and rebuilds the twins.

    blender -b <file.blend> -P tools/fix_huey_rotors.py
"""
import bpy, sys, math, traceback
from mathutils import Vector, Matrix

SCR = r"C:/Users/caleb/AppData/Local/Temp/claude/C--Users-caleb/196c26d6-27be-4609-96bb-84e0469827e5/scratchpad"

# pivot, spin axis, chord component index, span component index
ROTORS = (("ROTOR_PIVOT", 'Z', 1, 0),
          ("TAIL_PIVOT", 'X', 2, 1))
log = []


def radial(v, axis):
    return Vector((v.x, v.y)).length if axis == 'Z' else Vector((v.y, v.z)).length


def balance(pivot_name, axis, chord_i, span_i):
    P = bpy.data.objects.get(pivot_name)
    if P is None:
        log.append("  %-12s MISSING" % pivot_name)
        return
    for o in list(P.children):
        if o.name.endswith("_opposite"):
            bpy.data.objects.remove(o, do_unlink=True)
    blades = [c for c in P.children if c.type == 'MESH']
    if not blades:
        log.append("  %-12s no blade meshes" % pivot_name)
        return
    inv = P.matrix_world.inverted()

    def cloud(objs):
        pts = []
        for o in objs:
            pts += [inv @ (o.matrix_world @ v.co) for v in o.data.vertices]
        return pts

    before = radial(sum(cloud(blades), Vector()) / len(cloud(blades)), axis)
    if before < 0.05 and len(blades) > 1:
        log.append("  %-12s already balanced (%d blades, %.4f m) - left alone"
                   % (pivot_name, len(blades), before))
        return

    C = blades[0]
    pl = cloud([C])
    comp = lambda i: [p[i] for p in pl]
    cmid = (min(comp(chord_i)) + max(comp(chord_i))) / 2.0
    lo, hi = min(comp(span_i)), max(comp(span_i))
    root = lo if abs(lo) < abs(hi) else hi
    d = [0.0, 0.0, 0.0]
    d[chord_i] = -cmid
    d[span_i] = -root
    C.matrix_world.translation += P.matrix_world.to_3x3() @ Vector(d)
    bpy.context.view_layer.update()

    opp = bpy.data.objects.new(C.name + "_opposite", C.data)
    bpy.context.scene.collection.objects.link(opp)
    opp.parent = P
    opp.matrix_parent_inverse = Matrix.Identity(4)
    opp.matrix_local = Matrix.Rotation(math.pi, 4, axis) @ C.matrix_local
    bpy.context.view_layer.update()

    pair = cloud([C, opp])
    after = radial(sum(pair, Vector()) / len(pair), axis)
    tip = max(radial(p, axis) for p in pair)
    log.append("  %-12s %d->2 blades  centroid %.3f -> %.4f m  tip R %.3f"
               % (pivot_name, len(blades), before, after, tip))


try:
    target = bpy.data.filepath
    log.append(target.split("\\")[-1])
    for args in ROTORS:
        balance(*args)
    bpy.ops.wm.save_mainfile()
    log.append("  saved")
except Exception:
    log.append("  ERROR\n" + traceback.format_exc())

with open(SCR + "/rotors.txt", "a", encoding="utf-8") as fh:
    fh.write("\n".join(log) + "\n")
