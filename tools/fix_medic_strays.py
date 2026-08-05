"""fix_medic_strays.py - seat the medic's arm cross, bury the superseded slings.

    blender -b -P tools/fix_medic_strays.py -- [--apply]

us_medic.glb measured 11.61 m across against every other man's 2.73 m, because three
pieces ride at the world origin instead of on him:

  medic_cross_arm_h/v   the red cross for his brassard, stranded at (11.6, -8.3, -10.6)
  satchel_sling_*_OLD   superseded by the live 100-tri satchel_sling_*, never deleted

He already wears the brassard (medic_brassard_*, medic_brassard_white) and the bag
already carries its cross (medic_cross_bag_*, parented to satchel_body). The arm cross
is seated the same way the bag cross is - parented to the piece it decorates and set
proud of its +X face by the same margin - so the two crosses are placed by one rule.

The _OLD slings are deleted, not hidden: FOSSIL LAW, the replacement already ships.
"""
import bpy, sys
from mathutils import Vector

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
APPLY = "--apply" in ARGV
SRC = r"C:\Users\caleb\RECONgame\assets\us\characters\us_base_v3.blend"
DST = SRC if APPLY else SRC.replace(".blend", "_MEDICFIX.blend")
TAGS = ("medic", "medic_black")


def bb(o):
    vs = [o.matrix_world @ v.co for v in o.data.vertices]
    return (Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs))),
            Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs))))


bpy.ops.wm.open_mainfile(filepath=SRC)

for tag in TAGS:
    print("\n===== %s =====" % tag)
    brass = bpy.data.objects.get("medic_brassard_" + tag)
    if brass is None:
        print("  no brassard - skipped")
        continue
    blo, bhi = bb(brass)
    bctr = (blo + bhi) / 2

    # learn the margin from the cross that is ALREADY placed correctly, on the bag
    bag = bpy.data.objects.get("satchel_body_" + tag)
    margin = 0.006
    if bag is not None:
        glo, ghi = bb(bag)
        bagcross = bpy.data.objects.get("medic_cross_bag_h_" + tag)
        if bagcross is not None:
            clo, chi = bb(bagcross)
            margin = ((clo.x + chi.x) / 2) - ((glo.x + ghi.x) / 2) - (ghi.x - glo.x) / 2
            print("  margin learned from the bag cross: %+.4f m" % margin)

    target = Vector((bhi.x + margin, bctr.y, bctr.z))
    print("  brassard centre (%.4f, %.4f, %.4f), +X face %.4f -> cross target (%.4f, %.4f, %.4f)"
          % (bctr.x, bctr.y, bctr.z, bhi.x, target.x, target.y, target.z))

    moved = []
    for part in ("medic_cross_arm_h_", "medic_cross_arm_v_"):
        o = bpy.data.objects.get(part + tag)
        if o is None:
            continue
        lo, hi = bb(o)
        cur = (lo + hi) / 2
        d = target - cur
        o.location = o.location + d
        bpy.context.view_layer.update()
        # ride the brassard, exactly as the bag cross rides the satchel body
        M = o.matrix_world.copy()
        o.parent = brass
        o.matrix_parent_inverse = brass.matrix_world.inverted()
        o.matrix_world = M
        bpy.context.view_layer.update()
        nlo, nhi = bb(o)
        moved.append((o.name, d.length, (nlo + nhi) / 2))
        print("    %-30s moved %.3f m -> (%.4f, %.4f, %.4f), parent=%s"
              % (o.name, d.length, ((nlo + nhi) / 2).x, ((nlo + nhi) / 2).y,
                 ((nlo + nhi) / 2).z, brass.name))

    for nm in ("satchel_sling_%s_OLD" % tag,):
        o = bpy.data.objects.get(nm)
        if o is None:
            continue
        live = bpy.data.objects.get("satchel_sling_" + tag)
        if live is None:
            print("    %s: no live replacement found - KEPT" % nm)
            continue
        o.data.calc_loop_triangles()
        live.data.calc_loop_triangles()
        print("    deleting %s (%d tris) - superseded by %s (%d tris)"
              % (nm, len(o.data.loop_triangles), live.name, len(live.data.loop_triangles)))
        bpy.data.objects.remove(o, do_unlink=True)

# ---- gate: nothing belonging to a medic may sit far from him ----
print("\n=== GATE ===")
fail = []
for tag in TAGS:
    body = bpy.data.objects.get("us_grunt_joined_" + tag)
    if body is None:
        continue
    lo, hi = bb(body)
    ctr = (lo + hi) / 2
    worst = None
    for o in bpy.data.objects:
        if o.type != 'MESH' or not o.name.endswith("_" + tag):
            continue
        olo, ohi = bb(o)
        d = max((olo - ctr).length, (ohi - ctr).length)
        if worst is None or d > worst[1]:
            worst = (o.name, d)
    print("  %-12s furthest piece: %-32s %.3f m from his centre" % (tag, worst[0], worst[1]))
    if worst[1] > 1.6:
        fail.append("%s: %s is %.3f m away" % (tag, worst[0], worst[1]))
if fail:
    print("  FAILURES:")
    for f in fail:
        print("    - " + f)
else:
    print("  all medic parts are on the man")

bpy.ops.wm.save_as_mainfile(filepath=DST)
print("\nwrote %s" % DST)
