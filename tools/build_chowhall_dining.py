"""Dining tables + seat markers for WORKBENCH_chowhall.

blender -b <firebase>.blend --python tools/build_chowhall_dining.py -- [--save]

Facing convention for work_* empties is the +X axis, measured off the existing
cook/server/queue markers - not +Y.
"""
import sys
import math
import bpy
from mathutils import Vector

COLL = "WORKBENCH_chowhall"
ANCHOR = "WB_chowhall"
TABLE_MESH = "fb_folding_table.003"   # 1.80 x 0.76 x 0.75
BENCH_MESH = "fb_bench.002"           # 1.80 x 0.30 x 0.46

TABLE_XY = [(-1.55, -4.2), (1.55, -4.2), (-1.55, -6.6), (1.55, -6.6)]
BENCH_DY = 0.63          # table half-depth 0.38 + 0.10 gap + bench half-depth 0.15
SEAT_DX = (-0.6, 0.0, 0.6)
SEAT_BACKOFF = 0.10      # seat marker sits just outside the bench centre line

ARROW = ("SINGLE_ARROW", 0.5)
AXES = ("PLAIN_AXES", 0.25)


def world_bb(o):
    bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
    mn = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    mx = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    return mn, mx


def only_in(o, coll):
    for c in list(o.users_collection):
        c.objects.unlink(o)
    coll.objects.link(o)


def make_mesh(name, mesh, coll, anchor, loc, rz=0.0):
    o = bpy.data.objects.new(name, mesh)
    only_in(o, coll)
    o.parent = anchor
    o.location = loc
    o.rotation_euler = (0.0, 0.0, rz)
    return o


def make_empty(name, coll, anchor, loc, rz, style):
    o = bpy.data.objects.new(name, None)
    o.empty_display_type, o.empty_display_size = style
    only_in(o, coll)
    o.parent = anchor
    o.location = loc
    o.rotation_euler = (0.0, 0.0, rz)
    return o


def main():
    coll = bpy.data.collections[COLL]
    anchor = bpy.data.objects[ANCHOR]
    tmesh = bpy.data.meshes[TABLE_MESH]
    bmesh_ = bpy.data.meshes[BENCH_MESH]

    existing = [o for o in coll.all_objects if o.type == 'MESH']

    # Probe the bench mesh orientation instead of trusting the source object's rotation.
    probe = make_mesh("__probe", bmesh_, coll, anchor, (0.0, 0.0, 0.0))
    bpy.context.view_layer.update()
    mn, mx = world_bb(probe)
    bench_rz = 0.0 if (mx.x - mn.x) > (mx.y - mn.y) else math.radians(90.0)
    print(f"[probe] bench mesh at rz=0 is ({mx.x-mn.x:.3f} x {mx.y-mn.y:.3f}) "
          f"-> bench_rz={math.degrees(bench_rz):.0f} deg")
    bpy.data.objects.remove(probe, do_unlink=True)

    new_meshes, new_markers = [], []

    for tx, ty in TABLE_XY:
        new_meshes.append(make_mesh("fb_int_fb_folding_table", tmesh, coll, anchor, (tx, ty, 0.0)))
        new_markers.append(make_empty("prop_furniture", coll, anchor, (tx, ty, 0.0), 0.0, AXES))

        for side in (-1, 1):
            by = ty + side * BENCH_DY
            new_meshes.append(make_mesh("fb_int_fb_bench", bmesh_, coll, anchor,
                                        (tx, by, 0.0), bench_rz))
            new_markers.append(make_empty("prop_seat", coll, anchor, (tx, by, 0.0), 0.0, AXES))
            # A man on the south bench (side -1) faces +Y; north bench faces -Y.
            face_rz = math.radians(90.0) if side < 0 else math.radians(-90.0)
            for dx in SEAT_DX:
                new_markers.append(make_empty(
                    "work_eat", coll, anchor,
                    (tx + dx, by - side * SEAT_BACKOFF, 0.0), face_rz, ARROW))

    bpy.context.view_layer.update()

    # ---- verification ----------------------------------------------------
    fails = []

    tris = 0
    for o in new_meshes:
        tris += sum(len(p.vertices) - 2 for p in o.data.polygons)

    boxes = [(o.name, *world_bb(o)) for o in new_meshes]
    old_boxes = [(o.name, *world_bb(o)) for o in existing]

    def overlap(a, b):
        (_, amn, amx), (_, bmn, bmx) = a, b
        return all(amn[i] < bmx[i] - 1e-4 and bmn[i] < amx[i] - 1e-4 for i in range(3))

    for nb in boxes:
        for ob in old_boxes:
            if overlap(nb, ob):
                fails.append(f"new {nb[0]} overlaps existing {ob[0]}")
    for i in range(len(boxes)):
        for j in range(i + 1, len(boxes)):
            if overlap(boxes[i], boxes[j]):
                fails.append(f"{boxes[i][0]} overlaps {boxes[j][0]}")

    seats = [o for o in new_markers if o.name.startswith("work_eat")]
    for i in range(len(seats)):
        for j in range(i + 1, len(seats)):
            d = (seats[i].matrix_world.translation - seats[j].matrix_world.translation).length
            if d < 0.42:
                fails.append(f"seat spacing {seats[i].name}/{seats[j].name} = {d:.3f} m < 0.42")

    # Every seat must face its own table across the bench.
    for s in seats:
        fwd = (s.matrix_world.to_3x3() @ Vector((1, 0, 0))).normalized()
        best = min(TABLE_XY, key=lambda t: (Vector((t[0], t[1], 0)) - s.location).length)
        # Square to the table EDGE at his own x, not aimed at the table centre.
        to_table = (Vector((s.location.x, best[1], 0.0)) - s.location)
        to_table.z = 0
        if fwd.dot(to_table.normalized()) < 0.85:
            fails.append(f"{s.name} faces {fwd.x:.2f},{fwd.y:.2f} not toward its table")

    bench_tops = {round(world_bb(o)[1].z, 3) for o in new_meshes if "bench" in o.name}
    table_tops = {round(world_bb(o)[1].z, 3) for o in new_meshes if "table" in o.name}

    mn = Vector((min(b[1].x for b in boxes), min(b[1].y for b in boxes), min(b[1].z for b in boxes)))
    mx = Vector((max(b[2].x for b in boxes), max(b[2].y for b in boxes), max(b[2].z for b in boxes)))
    a = anchor.location

    print("\n=== DINING BUILD ===")
    print(f"  meshes  : {len(new_meshes)}  tris {tris}")
    print(f"  markers : {len(new_markers)}  (work_eat {len(seats)})")
    print(f"  bench top z {sorted(bench_tops)}   table top z {sorted(table_tops)}")
    print(f"  local extent x {mn.x-a.x:.2f}..{mx.x-a.x:.2f}  y {mn.y-a.y:.2f}..{mx.y-a.y:.2f}")
    print(f"  VERIFY  : {'PASS' if not fails else 'FAIL'}")
    for f in fails:
        print("    !!", f)

    ch_meshes = [o for o in coll.all_objects if o.type == 'MESH']
    total = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in ch_meshes)
    print(f"  chowhall now: {len(ch_meshes)} meshes / {total} tris / "
          f"{len([o for o in coll.all_objects if o.type == 'EMPTY'])} empties")

    if fails:
        print("  NOT SAVING - verification failed")
        return

    if "--save" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("  SAVED", bpy.data.filepath)
    else:
        print("  dry run (pass --save to write)")


main()
