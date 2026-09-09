"""Plant the REAL species models where the firebase's baked vegetation CARDS stand.

    blender --background --python tools/refit_firebase_veg.py     # measures, writes nothing

His art ruling, 2026-09-08: "no more 2d terrain cards, or 3d plane spliced cards or whatever.
all 3d blender models only in game", barbwire the one exemption. The runtime halves shipped on
2026-09-09; this is the art bake, the last card population in the live world.

HOW THE TRANSFORMS COME BACK. scatter_veg() fuses every instance of a species into ONE mesh, so
the per-instance transforms are not stored anywhere. They are still RECOVERABLE exactly, because
bmesh.from_mesh() appends: instance i occupies vertices [i*V, (i+1)*V) where V is the source
card's vertex count. A Umeyama fit on each block returns translation, rotation and uniform scale.
Measured 2026-09-09 across all 14 card groups: max residual 0.0000 m. The fit is not an estimate.

WHY THIS IS AN EXPORT STEP AND NOT A BLEND EDIT. Same reason the -colonly twins are one: the
canon blend is the artist's file and this pipeline never saves it (reexport_firebase_v3.py says
so at length). The swap is generated, exported and undone inside one call, so reverting the
ruling is reverting this file - the card GLBs and their sheets stay untouched on disk.
"""
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_firebase as gf          # noqa: E402
import gen_firebase_v3 as v3       # noqa: E402

CANON_BLEND = os.path.join(gf.KIT_DIR, "firebase_v3.2.blend")

## A block fit that is not ~0 means the merged mesh is no longer N copies in vertex order -
## hand-edited, or welded by something. Planting on a bad fit would scatter real plants at wrong
## yaws and scales along the treeline and it would look plausible. Fail loud instead. Measured
## 0.0000 on the 2026-09-09 blend; a millimetre is three orders of slack.
FIT_TOLERANCE_M = 0.001


def _load_mesh(path):
    """The real species model, world-transformed, as ONE mesh. Mirrors scatter_veg's loader
    except that it JOINS a multi-part GLB instead of silently taking part one."""
    before = set(bpy.data.objects.keys())
    bpy.ops.import_scene.gltf(filepath=path)
    new = [bpy.data.objects[k] for k in set(bpy.data.objects.keys()) - before]
    src = [o for o in new if o.type == 'MESH' and 'colonly' not in o.name.lower()]
    me = None
    if src:
        bm = bmesh.new()
        mats = []
        for o in src:
            part = o.data.copy()
            part.transform(o.matrix_world)
            bm.from_mesh(part)
            for m in part.materials:
                if m is not None and m not in mats:
                    mats.append(m)
            bpy.data.meshes.remove(part)
        me = bpy.data.meshes.new(os.path.basename(path))
        bm.to_mesh(me)
        bm.free()
        for m in mats:
            if getattr(m, "blend_method", None) == 'BLEND':
                m.blend_method = 'HASHED'
            me.materials.append(m)
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
    return me, len(src)


def _svd3(M):
    import numpy as np
    A = np.array([[M[i][j] for j in range(3)] for i in range(3)], dtype=float)
    U, S, Vt = np.linalg.svd(A)
    return (Matrix([[float(U[i][j]) for j in range(3)] for i in range(3)]),
            [float(x) for x in S],
            Matrix([[float(Vt[i][j]) for j in range(3)] for i in range(3)]))


def umeyama(src, dst):
    """Fit dst = s*R*src + t for a rotation with UNIFORM scale, which is exactly the family
    scatter_veg applies (Translation @ Euler @ Scale(s)). Returns (Matrix4, max residual)."""
    n = len(src)
    cs = sum(src, Vector((0.0, 0.0, 0.0))) / n
    cd = sum(dst, Vector((0.0, 0.0, 0.0))) / n
    P = [p - cs for p in src]
    Q = [q - cd for q in dst]
    H = Matrix(((0.0, 0.0, 0.0), (0.0, 0.0, 0.0), (0.0, 0.0, 0.0)))
    for p, q in zip(P, Q):
        for i in range(3):
            for j in range(3):
                H[i][j] += p[i] * q[j]
    U, S, Vt = _svd3(H)
    R = Vt.transposed() @ U.transposed()
    if R.determinant() < 0.0:
        Vt[2][0], Vt[2][1], Vt[2][2] = -Vt[2][0], -Vt[2][1], -Vt[2][2]
        R = Vt.transposed() @ U.transposed()
        S[2] = -S[2]
    var = sum(p.length_squared for p in P)
    s = (S[0] + S[1] + S[2]) / var if var > 1e-12 else 1.0
    t = cd - (R @ cs) * s
    res = 0.0
    for a, b in zip(src, dst):
        res = max(res, ((R @ a) * s + t - b).length)
    return (Matrix.Translation(t) @ R.to_4x4() @ Matrix.Scale(s, 4)), res


def recover_instances(ob, card_pts):
    """Per-instance transforms of one merged card group. Raises if the block model breaks."""
    V = len(card_pts)
    merged = [v.co.copy() for v in ob.data.vertices]
    if V == 0 or len(merged) % V:
        raise SystemExit("%s: %d verts is not a multiple of the card's %d - the merged mesh is "
                         "no longer N copies in order, refusing to guess"
                         % (ob.name, len(merged), V))
    out, worst = [], 0.0
    for i in range(len(merged) // V):
        m, res = umeyama(card_pts, merged[i * V:(i + 1) * V])
        worst = max(worst, res)
        out.append(m)
    if worst > FIT_TOLERANCE_M:
        raise SystemExit("%s: block fit residual %.4f m exceeds %.4f - refusing to plant"
                         % (ob.name, worst, FIT_TOLERANCE_M))
    return out, worst


def _card_points(card_rel):
    me, _n = _load_mesh(os.path.join(v3.VEG_DIR, card_rel.replace("/", os.sep)))
    if me is None:
        raise SystemExit("card GLB has no mesh: %s" % card_rel)
    pts = [v.co.copy() for v in me.vertices]
    bpy.data.meshes.remove(me)
    return pts


def _tris(me):
    return sum(len(p.vertices) - 2 for p in me.polygons)


def swap_cards_for_models(report=True):
    """Replace every merged CARD group's mesh with the same instances built from the real
    species model. Object names, count and collections are untouched, so the destructible and
    ballistic naming contracts see no change. Returns the ledger for restore()."""
    sc = bpy.context.scene
    saved = []
    tot_before = tot_after = 0
    if report:
        print("\n%-24s %5s %5s %8s %9s %10s %s"
              % ("species", "cardV", "inst", "fit m", "tris in", "tris out", "model"))
    for stem, card_rel in sorted(v3.VEG_BAKED_CARDS.items()):
        ob = sc.objects.get("fb_veg_" + stem)
        if ob is None:
            raise SystemExit("fb_veg_%s is not in the blend - the recovery table has drifted "
                             "from the bake; fix VEG_BAKED_CARDS before exporting" % stem)
        card_pts = _card_points(card_rel)
        xforms, worst = recover_instances(ob, card_pts)
        model, parts = _load_mesh(os.path.join(v3.VEG_DIR, stem + ".glb"))
        if model is None:
            raise SystemExit("no real model for %s - do NOT substitute another species" % stem)
        bm = bmesh.new()
        for m in xforms:
            tmp = model.copy()
            tmp.transform(m)
            bm.from_mesh(tmp)
            bpy.data.meshes.remove(tmp)
        out = bpy.data.meshes.new("fb_veg_%s_real" % stem)
        bm.to_mesh(out)
        bm.free()
        for mat in model.materials:
            out.materials.append(mat)
        before, after = _tris(ob.data), _tris(out)
        tot_before += before
        tot_after += after
        if report:
            print("%-24s %5d %5d %8.4f %9d %10d %d part(s), %d mat(s)"
                  % (stem, len(card_pts), len(xforms), worst, before, after,
                     parts, len(out.materials)))
        saved.append((ob, ob.data, out))
        ob.data = out
        bpy.data.meshes.remove(model)
    if report:
        print("%-24s %5s %5s %8s %9d %10d  (x%.1f)"
              % ("TOTAL", "", "", "", tot_before, tot_after,
                 tot_after / max(tot_before, 1)))
    return saved


def restore(saved):
    for ob, old, made in saved:
        ob.data = old
        bpy.data.meshes.remove(made)


def main():
    bpy.ops.wm.open_mainfile(filepath=CANON_BLEND)
    saved = swap_cards_for_models(report=True)
    restore(saved)
    print("\nDRY RUN: measured only. Nothing exported, blend not saved.")
    print("The shipping path runs this from gen_firebase_v3.export_firebase().")


if __name__ == "__main__":
    main()
