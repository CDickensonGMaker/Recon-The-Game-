"""Inside-out face audit for a viewmodel rig collection (read-only).

    blender -b assets/player/arms/fp_arms_rifle.blend -P tools/check_viewmodel_normals.py -- RIG_M16A1 M16A1

Per mesh part: matrix determinant, inward-facing fraction (rendered normal vs
outward-from-centroid), and the top-band up/down face split. Ring/tube parts
(sight hoods, trigger guards) legitimately show ~50-70% inward - suspect parts
are the ones at or near 100%, or with top-band down >> up.
Fix = bmesh.ops.recalc_face_normals on the flagged parts (see the PPSh repair,
2026-07-26), then re-run this and re-export.
"""
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if len(argv) != 2:
    raise SystemExit("usage: -- <collection> <gun_prefix>")
coll_name, prefix = argv

coll = bpy.data.collections[coll_name]
dg = bpy.context.evaluated_depsgraph_get()

for o in sorted(coll.objects, key=lambda x: x.name):
    if o.type != 'MESH' or not o.name.startswith(prefix):
        continue
    ev = o.evaluated_get(dg)
    m = ev.matrix_world
    det = m.to_3x3().determinant()
    me = ev.to_mesh()
    if not me.polygons:
        ev.to_mesh_clear()
        continue
    nm = m.to_3x3()
    sgn = 1.0 if det > 0 else -1.0
    cen = m @ (sum((v.co for v in me.vertices), start=me.vertices[0].co * 0.0) / len(me.vertices))
    zmax = max((m @ v.co).z for v in me.vertices)
    inward = up = down = 0
    for p in me.polygons:
        wn = ((nm @ p.normal) * sgn).normalized()
        wc = m @ p.center
        out = wc - cen
        if out.length > 1e-6 and wn.dot(out.normalized()) < 0.0:
            inward += 1
        if wc.z >= zmax - 0.006:
            if wn.z > 0.4:
                up += 1
            elif wn.z < -0.4:
                down += 1
    frac = inward / len(me.polygons)
    flag = "  <-- SUSPECT" if frac > 0.85 or (down > up and down > 2) else ""
    print(f"{o.name}: det={'NEG' if det < 0 else 'pos'} inward {inward}/{len(me.polygons)} "
          f"({frac:.0%})  top-band up={up} down={down}{flag}")
    ev.to_mesh_clear()
