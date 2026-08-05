"""fix_lineup_rig_drift.py - put each lineup soldier's skeleton back under his body.

    blender -b -P tools/fix_lineup_rig_drift.py -- [--apply]

In us_v3_soldier_lineup.blend the bodies stand on a clean 1.5 m grid while the rigs
have drifted to a widening spread:

    bodies   0.0   1.5    3.0    4.5    6.0    7.5     9.0
    rigs     0.0   2.084  4.054  6.088  8.522  11.216  13.751

The skinned meshes are object-parented with a compensating basis, so they stayed on the
grid; the helmets and weapons are bone-parented, so they followed the rigs. That is why
a helmet measured up to 4.75 m from its own head - NOT a mis-bind. Every mesh in the
file is correctly bound to its own rig with 34/34 matching vertex groups, and raw centre
equals evaluated centre, so the skinning was never the problem.

The grid is the intended lineup, so the rigs come back to the bodies. Skinned meshes have
their world transforms restored afterwards (moving a parent drags them otherwise);
bone-parented gear is left to follow its rig, which is exactly what lands it on the man.

`socket_head_*` matrices are BONE-relative, so `helmets.json` is unaffected - but
`export_helmets.py:24-25` reads this file, so it is worth it being correct.
"""
import bpy, sys
from mathutils import Vector

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
APPLY = "--apply" in ARGV
SRC = r"C:\Users\caleb\RECONgame\assets\us\characters\us_v3_soldier_lineup.blend"
DST = SRC if APPLY else SRC.replace(".blend", "_RIGFIX.blend")
TAGS = ("", "grenadier", "marksman", "mg", "pointman", "rifleman", "rto")

bpy.ops.wm.open_mainfile(filepath=SRC)
for r in bpy.data.objects:
    if r.type == 'ARMATURE':
        r.data.pose_position = 'REST'
        if r.animation_data:
            r.animation_data.action = None
bpy.context.view_layer.update()


def centre(o):
    vs = [o.matrix_world @ v.co for v in o.data.vertices]
    return sum(vs, Vector()) / len(vs)


def eval_centre(o, dg):
    ev = o.evaluated_get(dg); me = ev.to_mesh()
    vs = [ev.matrix_world @ v.co for v in me.vertices]; ev.to_mesh_clear()
    return sum(vs, Vector()) / len(vs)


print("=== moving each rig back under its body ===")
for t in TAGS:
    suf = ("_" + t) if t else ""
    rig = bpy.data.objects.get("PSXRig" + suf)
    body = bpy.data.objects.get("us_grunt_joined" + suf)
    if rig is None or body is None:
        print("  %-12s missing rig or body - skipped" % (t or "<base>"))
        continue

    before = rig.location.x
    target = centre(body).x
    if abs(before - target) < 1e-6:
        print("  %-12s already aligned at %.3f" % (t or "<base>", before))
        continue

    # skinned / object-parented children must NOT be dragged along
    keep = {}
    for o in bpy.data.objects:
        if o.parent is rig and o.parent_type == 'OBJECT':
            keep[o.name] = o.matrix_world.copy()

    rig.location.x = target
    bpy.context.view_layer.update()
    for n, M in keep.items():
        bpy.data.objects[n].matrix_world = M
    bpy.context.view_layer.update()

    print("  %-12s rig %.3f -> %.3f  (%+.3f m)   %d skinned meshes held in place"
          % (t or "<base>", before, target, target - before, len(keep)))

# ------------------------------------------------------------------ gates
print("\n=== GATES ===")
dg = bpy.context.evaluated_depsgraph_get()
fail = []
for t in TAGS:
    suf = ("_" + t) if t else ""
    rig = bpy.data.objects.get("PSXRig" + suf)
    head = bpy.data.objects.get("grunt_head" + suf)
    helm = bpy.data.objects.get("helmet_shell_worn" + suf)
    if not (rig and head and helm):
        continue
    bone = rig.matrix_world @ rig.data.bones["mixamorig:Head"].head_local
    hc = eval_centre(head, dg)
    mc = eval_centre(helm, dg)
    d_bone = (hc - bone).length
    d_helm = (mc - hc).length
    print("  %-12s head-to-bone %.4f m   helmet-to-head %.4f m" % (t or "<base>", d_bone, d_helm))
    if d_bone > 0.20:
        fail.append("%s: head is %.3f m from its own head bone" % (t or "<base>", d_bone))
    if d_helm > 0.35:
        fail.append("%s: helmet is %.3f m from its head" % (t or "<base>", d_helm))
if fail:
    print("  FAILURES:")
    for f in fail:
        print("    - " + f)
else:
    print("  every soldier's skeleton, body and helmet are together")

bpy.ops.wm.save_as_mainfile(filepath=DST)
print("\nwrote %s" % DST)
