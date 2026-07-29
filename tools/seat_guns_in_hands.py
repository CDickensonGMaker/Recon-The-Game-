"""Move each staged gun into the hands that are posed to hold it.

    blender -b assets/player/arms/fp_arms_rifle.blend \
        -P tools/seat_guns_in_hands.py -- [--apply] [gun ...]

The 2026-07-27 transplant left every staged gun parked at its armory station
rather than in the hands: measured 2026-07-28, AK47_root sits 0.094 m from its
hand.R while RPD sits 2.759 m from its own. Constraining a gun there only locks
in the wrong offset, and export_all_viewmodels rejects it - "bakes 2.76 m from
hand.R, rig contract broken".

The grip markers' ROTATIONS are not a usable convention (measured across the four
correct guns the hand-to-grip offset ranges 18-451 mm with scattered angles), so
this solves POSITION only, from three non-collinear correspondences:

    grip_R -> hand.R head      grip_L -> hand.L head
    magwell -> below the hand midpoint, at its own distance from the grip line

which says exactly what holding a rifle means: both grips in both hands, magazine
hanging down. Kabsch gives the rigid transform; no scaling is applied, so the
model is never resized.

SELF-TEST: run without --apply. The four already-correct guns (ak, m16, m14,
ppsh) are solved too and MUST come out close to where they already are. If they
move far, the method is wrong and nothing should be applied.
"""
import bpy
import math
import sys
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
APPLY = '--apply' in argv
ONLY = [a for a in argv if not a.startswith('--')]

KNOWN_GOOD = {'AK47', 'M16A1', 'M14', 'PPSh41'}


def kabsch(P, Q):
    cp = sum(P, Vector()) / len(P)
    cq = sum(Q, Vector()) / len(Q)
    H = Matrix(((0, 0, 0), (0, 0, 0), (0, 0, 0)))
    for p, q in zip(P, Q):
        a, b = p - cp, q - cq
        for i in range(3):
            for j in range(3):
                H[i][j] += a[i] * b[j]
    U, S, Vt = _svd3(H)
    R = Vt.transposed() @ U.transposed()
    if R.determinant() < 0:
        Vt[2] = [-v for v in Vt[2]]
        R = Vt.transposed() @ U.transposed()
    M = R.to_4x4()
    M.translation = cq - R @ cp
    return M


def _svd3(H):
    A = H.transposed() @ H
    V = Matrix.Identity(3)
    for _ in range(64):
        if sum(A[i][j] ** 2 for i in range(3) for j in range(3) if i != j) < 1e-24:
            break
        for p in range(2):
            for q in range(p + 1, 3):
                if abs(A[p][q]) < 1e-18:
                    continue
                th = (A[q][q] - A[p][p]) / (2 * A[p][q])
                t = (1 if th >= 0 else -1) / (abs(th) + math.sqrt(th * th + 1))
                c = 1 / math.sqrt(t * t + 1)
                s = t * c
                J = Matrix.Identity(3)
                J[p][p] = c; J[q][q] = c; J[p][q] = s; J[q][p] = -s
                A = J.transposed() @ A @ J
                V = V @ J
    sv = [math.sqrt(max(A[i][i], 0.0)) for i in range(3)]
    order = sorted(range(3), key=lambda i: -sv[i])
    Vs = Matrix([[V[r][c] for c in order] for r in range(3)])
    S = [sv[i] for i in order]
    cols = []
    for i in range(3):
        v = Vector((Vs[0][i], Vs[1][i], Vs[2][i]))
        cols.append((H @ v).normalized() if S[i] > 1e-12 else Vector((0, 0, 0)))
    U = Matrix([[cols[c][r] for c in range(3)] for r in range(3)])
    if S[2] <= 1e-12:
        u0 = Vector((U[0][0], U[1][0], U[2][0]))
        u1 = Vector((U[0][1], U[1][1], U[2][1]))
        u2 = u0.cross(u1)
        v2 = (Vector((Vs[0][0], Vs[1][0], Vs[2][0]))
              .cross(Vector((Vs[0][1], Vs[1][1], Vs[2][1]))))
        for r in range(3):
            U[r][2] = u2[r]
            Vs[r][2] = v2[r]
    return U, S, Vs.transposed()


def unhide(coll):
    vl = bpy.context.view_layer

    def find(name, layer=None):
        layer = layer or vl.layer_collection
        if layer.collection.name == name:
            return layer
        for ch in layer.children:
            r = find(name, ch)
            if r:
                return r
    lc = find(coll.name)
    if lc:
        lc.exclude = False
        lc.hide_viewport = False
    for o in coll.objects:
        o.hide_viewport = False
        o.hide_render = False


def top_of(o):
    while o.parent is not None:
        o = o.parent
    return o


for coll in bpy.data.collections:
    if coll.name.startswith('RIG_'):
        unhide(coll)
bpy.context.view_layer.update()
bpy.context.scene.frame_set(0)
bpy.context.view_layer.update()

rows = []
for coll in sorted(bpy.data.collections, key=lambda c: c.name):
    if not coll.name.startswith('RIG_'):
        continue
    pref = coll.name.replace('RIG_', '')
    if ONLY and pref not in ONLY:
        continue
    rig = next((o for o in coll.objects if o.type == 'ARMATURE'), None)
    if rig is None or 'hand.R' not in rig.pose.bones:
        continue
    gR = bpy.data.objects.get('grip_R_%s' % pref)
    gL = bpy.data.objects.get('grip_L_%s' % pref)
    mw = bpy.data.objects.get('magwell_%s' % pref)
    if not (gR and gL and mw):
        rows.append((pref, None, 'missing grip/magwell markers'))
        continue
    root = top_of(gR)

    hR = (rig.matrix_world @ rig.pose.bones['hand.R'].matrix).translation
    hL = (rig.matrix_world @ rig.pose.bones['hand.L'].matrix).translation

    P = [gR.matrix_world.translation.copy(), gL.matrix_world.translation.copy(),
         mw.matrix_world.translation.copy()]
    grip_mid = (P[0] + P[1]) * 0.5
    drop = (P[2] - grip_mid).length
    Q = [hR.copy(), hL.copy(), (hR + hL) * 0.5 + Vector((0, 0, -1)) * drop]

    M = kabsch(P, Q)
    resid = max(((M @ p) - q).length * 1000 for p, q in zip(P, Q))
    move = (M @ root.matrix_world.translation - root.matrix_world.translation).length

    # a Child Of already on the root would fight the move; drop it and let
    # attach_gun_roots.py re-add it with a correct inverse afterwards
    if APPLY and pref not in KNOWN_GOOD:
        for c in list(root.constraints):
            if c.type == 'CHILD_OF':
                root.constraints.remove(c)
        root.matrix_world = M @ root.matrix_world
        bpy.context.view_layer.update()
    rows.append((pref, (move * 1000, resid,
                        (gR.matrix_world.translation - hR).length * 1000), None))

print('\n  %-26s %12s %12s %12s' % ('gun', 'would_move', 'fit_resid', 'gripR->handR'))
for pref, vals, err in rows:
    tag = '  <- known good' if pref in KNOWN_GOOD else ''
    if err:
        print('  %-26s %s' % (pref, err))
    else:
        print('  %-26s %9.1f mm %9.1f mm %9.1f mm%s'
              % (pref, vals[0], vals[1], vals[2], tag))

if APPLY:
    bpy.ops.wm.save_mainfile()
    print('\n  SAVED %s' % bpy.data.filepath)
else:
    print('\n  dry run - nothing saved. Check the known-good guns above first.')
