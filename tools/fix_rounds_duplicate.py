"""fix_rounds_duplicate.py - one rounds mesh on m1_rounds, seated on the shell.

    blender -b -P tools/fix_rounds_duplicate.py -- [--apply]

reseat_helmet_props.py rebuilt m1_rounds' cartridge cluster from the reference but
left the original alongside it, so the variant shipped TWO rounds meshes - one of
them floating half a metre off the helmet. Keep the rebuild, drop the original,
seat what remains.
"""
import bpy, sys
from mathutils import Vector

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
APPLY = "--apply" in ARGV
SRC = r"C:\Users\caleb\RECONgame\assets\us\characters\helmet_variants.blend"
DST = SRC if APPLY else SRC.replace(".blend", "_ROUNDSFIX.blend")
EPS = 0.0005


def tris(o):
    o.data.calc_loop_triangles()
    return len(o.data.loop_triangles)


def signed_field(prop, shell):
    Mi = shell.matrix_world.inverted()
    best, bn = 1e9, Vector((0, 0, 1))
    for v in prop.data.vertices:
        lp = Mi @ (prop.matrix_world @ v.co)
        ok, loc, nor, _ = shell.closest_point_on_mesh(lp)
        if not ok:
            continue
        d = (lp - loc).dot(nor)
        if d < best:
            best, bn = d, nor.copy()
    return best, (shell.matrix_world.to_3x3() @ bn).normalized()


bpy.ops.wm.open_mainfile(filepath=SRC)
col = bpy.data.collections["m1_rounds"]
cover = bpy.data.objects["m1_rounds_cover"]
rounds = sorted([o for o in col.objects if o.type == 'MESH' and "rounds" in o.name.replace("m1_rounds", "")],
                key=lambda o: -tris(o))
print("rounds meshes on m1_rounds:")
for o in rounds:
    d, _ = signed_field(o, cover)
    print("  %-26s tris=%3d  nearest surface %+.5f m" % (o.name, tris(o), d))

if len(rounds) < 2:
    print("only one rounds mesh - nothing to fix")
else:
    keep, drop = rounds[0], rounds[1:]     # the rebuild is the higher-poly one
    for o in drop:
        print("  dropping %s (%d tris)" % (o.name, tris(o)))
        bpy.data.objects.remove(o, do_unlink=True)
    if keep.name != "m1_rounds_rounds":
        keep.name = "m1_rounds_rounds"
    keep.data.name = keep.name

    for _ in range(6):
        d, n = signed_field(keep, cover)
        if abs(d - EPS) < 1e-5:
            break
        keep.location = keep.location + n * (EPS - d)
        bpy.context.view_layer.update()
    final, _ = signed_field(keep, cover)
    print("  kept %s at %+.5f m off the shell" % (keep.name, final))
    if not (0.0 < final < 0.010):
        raise SystemExit("ABORT: rounds seated at %+.5f m, outside (0, 10 mm]" % final)

total = sum(tris(o) for o in col.objects if o.type == 'MESH')
print("m1_rounds total = %d tris" % total)
bpy.ops.wm.save_as_mainfile(filepath=DST)
print("wrote %s" % DST)
