"""The chow hall enclosure: an open-sided mess tent sized to its own contents.

    exec(open(r"C:\\Users\\caleb\\RECONgame\\tools\\build_chowhall_tent.py").read())

Caleb's original spec, unchanged since 8/2: *"an open aired tent with a dedicated
cooking section and than tables for people to sit at and eat"*, with **one wall**
permitted to frame it. That wall already exists (`WB_chowhall_backwall`, y -236.85).

BUILD ORDER IS LAW here - contents first, shell last. The contents are finished, so
the frame is measured off THEM rather than guessed: posts stand clear of the tables,
the eave clears a standing man, the ridge clears the eave.

MEASURED FOOTPRINT (excluding bodies and the orphan trays at the world origin):
    x -3.17 .. 3.57   6.74 m wide
    y -247.38 .. -236.85   10.53 m deep
    tallest content 2.00 m (the back wall)
"""
import bpy
import math
from mathutils import Vector, Matrix

COLL = "WORKBENCH_chowhall"

MARGIN = 0.55          # walkway outside the furniture
EAVE = 2.25            # underside of the roof at the edge - clears a 1.75 m man
RIDGE = 3.20           # apex
POST = 0.09            # square post section
BAY = 2.9              # post spacing along the length


def coll():
    return bpy.data.collections[COLL]


def anchor():
    return bpy.data.objects["WB_chowhall"]


def mk(name, verts, faces, mat=None):
    me = bpy.data.meshes.get(name) or bpy.data.meshes.new(name)
    me.clear_geometry()
    me.from_pydata(verts, [], faces)
    me.validate()
    me.update()
    me.polygons.foreach_set("use_smooth", [False] * len(me.polygons))
    o = bpy.data.objects.get(name)
    if o is None:
        o = bpy.data.objects.new(name, me)
        coll().objects.link(o)
    o.data = me
    o.parent = anchor()
    o.matrix_parent_inverse = Matrix.Identity(4)
    o.location = (0.0, 0.0, 0.0)
    o.rotation_euler = (0.0, 0.0, 0.0)
    if mat is not None and not me.materials:
        me.materials.append(mat)
    return o


def box(v, f, x0, x1, y0, y1, z0, z1):
    b = len(v)
    v += [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
          (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
    f += [(b+0, b+3, b+2, b+1), (b+4, b+5, b+6, b+7),
          (b+0, b+1, b+5, b+4), (b+1, b+2, b+6, b+5),
          (b+2, b+3, b+7, b+6), (b+3, b+0, b+4, b+7)]


def content_bounds():
    lo = Vector((9e9, 9e9, 9e9))
    hi = Vector((-9e9, -9e9, -9e9))
    for o in coll().all_objects:
        if o.type != 'MESH' or o.name.startswith(("grunt_", "cap_", "tent_")):
            continue
        p = o.matrix_world.translation
        if p.y > -200.0:            # orphan trays sitting at the world origin
            continue
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
            hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
    return lo, hi


def main():
    a = anchor()
    lo, hi = content_bounds()
    x0, x1 = lo.x - MARGIN - a.location.x, hi.x + MARGIN - a.location.x
    y0, y1 = lo.y - MARGIN - a.location.y, hi.y + 0.15 - a.location.y
    print("tent footprint (local): x %.2f..%.2f (%.2f m)  y %.2f..%.2f (%.2f m)"
          % (x0, x1, x1 - x0, y0, y1, y1 - y0))

    timber = bpy.data.materials.get("fb_timber")
    canvas = bpy.data.materials.get("fb_canvas")

    # ---- posts down both long sides, plus the two front corners ---------------
    v, f = [], []
    n = max(2, int(round((y1 - y0) / BAY)) + 1)
    ys = [y0 + (y1 - y0) * i / (n - 1) for i in range(n)]
    for yy in ys:
        for xx in (x0, x1):
            box(v, f, xx - POST / 2, xx + POST / 2, yy - POST / 2, yy + POST / 2,
                0.0, EAVE)
    # eave beams along both sides
    for xx in (x0, x1):
        box(v, f, xx - POST / 2, xx + POST / 2, y0, y1, EAVE - POST, EAVE)
    # ridge beam
    box(v, f, -POST / 2, POST / 2, y0, y1, RIDGE - POST, RIDGE)
    # rafters, eave to ridge, one per bay
    for yy in ys:
        for xx in (x0, x1):
            steps = 6
            for s in range(steps):
                t0, t1 = s / steps, (s + 1) / steps
                ax0 = xx + (0.0 - xx) * t0
                ax1 = xx + (0.0 - xx) * t1
                z0 = EAVE + (RIDGE - EAVE) * t0
                z1 = EAVE + (RIDGE - EAVE) * t1
                box(v, f, min(ax0, ax1), max(ax0, ax1),
                    yy - 0.04, yy + 0.04, min(z0, z1) - 0.05, max(z0, z1))
    frame = mk("tent_frame_chowhall", v, f, timber)

    # ---- canvas roof: two slopes -------------------------------------------
    v, f = [], []
    for side in (x0, x1):
        b = len(v)
        v += [(side, y0, EAVE), (0.0, y0, RIDGE), (0.0, y1, RIDGE), (side, y1, EAVE)]
        f += [(b + 0, b + 1, b + 2, b + 3)]
        b = len(v)                                   # underside, so it reads from below
        v += [(side, y0, EAVE - 0.02), (0.0, y0, RIDGE - 0.02),
              (0.0, y1, RIDGE - 0.02), (side, y1, EAVE - 0.02)]
        f += [(b + 3, b + 2, b + 1, b + 0)]
    roof = mk("tent_roof_chowhall", v, f, canvas)

    # ---- gable infill over the back wall only (the one wall he allowed) -------
    v, f = [], []
    b = len(v)
    v += [(x0, y1, EAVE), (x1, y1, EAVE), (0.0, y1, RIDGE)]
    f += [(b + 0, b + 1, b + 2)]
    gable = mk("tent_gable_chowhall", v, f, canvas)

    bpy.context.view_layer.update()

    # ---- verify: does anything collide, and is there headroom? ---------------
    tri = sum(len(o.data.polygons) for o in (frame, roof, gable))
    print("tent built: %d objects, %d faces" % (3, tri))
    print("  eave %.2f m, ridge %.2f m" % (EAVE, RIDGE))
    worst = 9e9
    sc = bpy.context.scene
    for fr in (1, 300, 600, 900):
        sc.frame_set(fr)
        bpy.context.view_layer.update()
        for o in coll().all_objects:
            if o.type != 'ARMATURE' or o.hide_viewport:
                continue
            hd = (o.matrix_world @ o.pose.bones["mixamorig:Head"].head).z
            worst = min(worst, EAVE - hd)
    sc.frame_set(1)
    bpy.context.view_layer.update()
    print("  tightest headroom under the eave: %.2f m" % worst)

    posts_x = [x0 + a.location.x, x1 + a.location.x]
    clash = []
    for o in coll().all_objects:
        if o.type != 'MESH' or o.name.startswith(("tent_", "grunt_", "cap_")):
            continue
        p = o.matrix_world.translation
        if p.y > -200.0:
            continue
        for px in posts_x:
            if abs(p.x - px) < 0.35:
                clash.append((o.name, round(abs(p.x - px), 2)))
    print("  props within 0.35 m of a post line: %s" % (clash[:6] if clash else "none"))


main()
