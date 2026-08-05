"""fix_lineup_rig_drift.py - put each lineup soldier's gib pieces back on his body.

    blender -b -P tools/fix_lineup_rig_drift.py -- [--apply]

In us_v3_soldier_lineup.blend each soldier is split across two positions. His RIG, his
joined body and every bone-parented item (helmet, weapon, canteen, radio) stand on a
widening spread; his separate GIB PIECES - grunt_head, grunt_torso, the cap_* stumps,
Base_Human - sit back on the original 1.5 m grid:

    gib pieces   0.0  1.5    3.0    4.5    6.0    7.5     9.0
    rigs         0.0  2.084  4.054  6.088  8.522  11.216  13.751

That gap is the whole "helmet is 4.75 m from its head" symptom. It is NOT a mis-bind:
every mesh is bound to its own rig with 34/34 matching vertex groups, and raw centre
equals evaluated centre. The pieces were simply never moved when the lineup was spread.

The joined body is what renders and exports, and it is with the rig - so the rig is
right and the gib pieces are wrong. Each man's delta is measured from HIS OWN head bone
against his own grunt_head, so nobody is moved by a number borrowed from someone else.

Offsets WITHIN a soldier are left alone: a T-posed man's left forearm genuinely sits
0.4 m from his centre, and "correcting" that would take his arms off.
"""
import bpy, sys
from mathutils import Vector

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
APPLY = "--apply" in ARGV
SRC = r"C:\Users\caleb\RECONgame\assets\us\characters\us_v3_soldier_lineup.blend"
DST = SRC if APPLY else SRC.replace(".blend", "_RIGFIX.blend")
TAGS = ("", "grenadier", "marksman", "mg", "pointman", "rifleman", "rto")
GIB_PREFIX = ("grunt_", "cap_", "Base_Human", "splay_")

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


print("=== moving each soldier's gib pieces onto his rig ===")
for t in TAGS:
    suf = ("_" + t) if t else ""
    rig = bpy.data.objects.get("PSXRig" + suf)
    head = bpy.data.objects.get("grunt_head" + suf)
    if rig is None or head is None:
        print("  %-12s missing rig or head - skipped" % (t or "<base>"))
        continue

    bone = rig.matrix_world @ rig.data.bones["mixamorig:Head"].head_local
    delta = bone - centre(head)
    delta.y = 0.0
    delta.z = 0.0                      # the drift is purely along the lineup axis
    if delta.length < 0.01:
        print("  %-12s already together (%.4f m)" % (t or "<base>", delta.length))
        continue

    moved = 0
    for o in bpy.data.objects:
        if o.type != 'MESH' or not o.name.endswith(suf if suf else ""):
            continue
        if suf and not o.name.endswith(suf):
            continue
        if not suf and any(o.name.endswith("_" + x) for x in TAGS if x):
            continue
        if o.parent is not rig or o.parent_type == 'BONE':
            continue
        if not o.name.startswith(GIB_PREFIX):
            continue
        o.location = o.location + delta
        moved += 1
    bpy.context.view_layer.update()
    print("  %-12s delta %+.3f m along X, %d gib pieces moved" % (t or "<base>", delta.x, moved))

# ------------------------------------------------------------------ gates
print("\n=== GATES ===")
dg = bpy.context.evaluated_depsgraph_get()
fail = []
for t in TAGS:
    suf = ("_" + t) if t else ""
    rig = bpy.data.objects.get("PSXRig" + suf)
    head = bpy.data.objects.get("grunt_head" + suf)
    helm = bpy.data.objects.get("helmet_shell_worn" + suf)
    body = bpy.data.objects.get("us_grunt_joined" + suf)
    if not (rig and head and helm and body):
        continue
    bone = rig.matrix_world @ rig.data.bones["mixamorig:Head"].head_local
    hc = eval_centre(head, dg)
    d_bone = (hc - bone).length
    d_helm = (eval_centre(helm, dg) - hc).length
    d_body = abs(eval_centre(body, dg).x - hc.x)
    print("  %-12s head-to-bone %.4f  helmet-to-head %.4f  head-to-joined-body(x) %.4f"
          % (t or "<base>", d_bone, d_helm, d_body))
    if d_bone > 0.20:
        fail.append("%s: head %.3f m from its own head bone" % (t or "<base>", d_bone))
    if d_helm > 0.35:
        fail.append("%s: helmet %.3f m from its head" % (t or "<base>", d_helm))
    if d_body > 0.20:
        fail.append("%s: gib head %.3f m from the joined body" % (t or "<base>", d_body))
if fail:
    print("  FAILURES:")
    for f in fail:
        print("    - " + f)
else:
    print("  every soldier's skeleton, body, gib pieces and helmet are together")

bpy.ops.wm.save_as_mainfile(filepath=DST)
print("\nwrote %s" % DST)
