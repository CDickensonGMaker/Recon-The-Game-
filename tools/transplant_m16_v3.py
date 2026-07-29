"""Transplant the v3 armory M16A1 into fp_arms_rifle.blend, keeping the clips.

WHY THIS SHAPE. Measured 2026-07-28, the arms rig hangs together like this:

    M16A1_gun                       parent=None   CHILD_OF hand.R   <- the real root
      |- M16A1_ch_rail (empty)
      |    `- M16A1_charge_handle_slide_back      LIMIT_LOCATION rail + NLA
      |- M16A1_magazine.030                       2x CHILD_OF hand.L + NLA
      `- sight_rear_ / sight_front_ / muzzle_ / grip_* / magwell_ / eject_
    M16A1_gun.001 ... .032          32 more shells, each with its OWN CHILD_OF

Only the armature, the magazine and the charge handle carry animation. So the
transplant NEVER deletes M16A1_gun: doing so would orphan the magazine and the
charge-handle rail and break every handoff. Instead each surviving object keeps
its transform, parenting, constraints and NLA, and only its mesh DATA is
swapped. A rigid part rides its object's animation identically, so every
authored key stays valid and no CHILD_OF inverse needs recomputing.

The 32 duplicate shells ARE deleted - their geometry is joined into M16A1_gun,
which collapses 33 CHILD_OF constraints to the one on the root.

    blender -b assets/player/arms/fp_arms_rifle.blend -P tools/transplant_m16_v3.py
"""
import bpy
import math
import os
from mathutils import Matrix, Vector

ROOT = r'C:\Users\caleb\RECONgame'
ARMORY = os.path.join(ROOT, 'assets', 'us', 'characters', 'weapons_us.blend')
GUN = 'M16A1v3'
COLL = 'RIG_M16A1'
MAX_RESIDUAL_MM = 12.0

TRIO = ('muzzle', 'sight_front', 'sight_rear')
# old animated object -> the new armory part(s) that make up its mesh.
# The magazine is TWO shells in this model: the body and the floor plate. Both
# must ride the animated object - leaving the floor in the static shell makes it
# hang in the air when the mag drops out.
GRAFT = {
    'M16A1_magazine.030': ['M16A1v3_magazine', 'M16A1v3_mag_floor'],
    'M16A1_charge_handle_slide_back': ['M16A1v3_charge_handle'],
}
# arms-file marker  ->  armory marker it takes its seat from.
# The arms rig uses the older grip_R_/grip_L_ names; the armory uses the long
# grip_RightHand_/grip_LeftHand_ form. Both are live - do not "tidy" either.
MARKERS = {
    'muzzle_M16A1': 'muzzle_M16A1v3',
    'sight_front_M16A1': 'sight_front_M16A1v3',
    'sight_rear_M16A1': 'sight_rear_M16A1v3',
    'grip_R_M16A1': 'grip_RightHand_M16A1v3',
    'grip_L_M16A1': 'grip_LeftHand_M16A1v3',
    'magwell_M16A1': 'magwell_M16A1v3',
    'eject_M16A1': 'eject_M16A1v3',
    'contact_mag_M16A1': 'contact_mag_M16A1v3',
    'contact_chandle_M16A1': 'contact_chandle_M16A1v3',
}


def bbox_center(o):
    return sum((o.matrix_world @ Vector(c) for c in o.bound_box), Vector()) / 8.0


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
                c = 1 / math.sqrt(t * t + 1); s = t * c
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
            U[r][2] = u2[r]; Vs[r][2] = v2[r]
    return U, S, Vs.transposed()


def append_gun():
    for o in [x for x in bpy.data.objects
              if x.name.startswith(GUN) or x.name.endswith('_' + GUN)]:
        bpy.data.objects.remove(o, do_unlink=True)
    with bpy.data.libraries.load(ARMORY, link=False) as (src, dst):
        dst.objects = [n for n in src.objects
                       if n.startswith(GUN + '_') or n.endswith('_' + GUN)]
    coll = bpy.data.collections[COLL]
    got = [o for o in dst.objects if o is not None]
    for o in got:
        coll.objects.link(o)
    print('appended %d objects from the armory' % len(got))
    return got


def join_static(statics, target):
    """Merge the new static shells into one mesh in `target`'s local space.

    Every M16 part carries the SAME 10-material palette and picks its finish via
    material_index, so the palette is taken once and face indices are left
    alone. Offsetting them per-shell (the obvious-looking thing) writes indices
    past the slot count, and Blender silently CLAMPS those to 0 - which flattens
    the whole gun onto one material.
    """
    import bmesh
    palette = [m for m in statics[0].data.materials] if statics else []
    for o in statics:
        names = [m.name if m else None for m in o.data.materials]
        if names != [m.name if m else None for m in palette]:
            raise SystemExit('ABORT: %s has a different material palette - the '
                             'shared-palette assumption does not hold' % o.name)
    bm = bmesh.new()
    for o in statics:
        me = o.data.copy()
        me.transform(target.matrix_world.inverted() @ o.matrix_world)
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    out = bpy.data.meshes.new(target.data.name + '_v3')
    bm.to_mesh(out)
    bm.free()
    for m in palette:
        out.materials.append(m)
    return out


def extend_charge_handle(ch):
    """Lengthen the charging-handle shaft FORWARD by its own travel.

    The handle rides a 1-DOF rail on local +X and travels 81.7mm, but its body
    is only ~58mm long - so at full pull the receiver channel is left open and
    the gun reads as coming apart. A real M16 charging handle is ~140mm overall,
    nearly all of it hidden in the receiver, which is exactly this fix.
    """
    lim = next((c for c in ch.constraints if c.type == 'LIMIT_LOCATION'), None)
    travel = (lim.max_x - lim.min_x) if lim else 0.0
    if travel <= 0:
        print('  charge handle: no rail travel found, shaft left alone')
        return
    xs = [v.co.x for v in ch.data.vertices]
    x0 = min(xs)
    tol = (max(xs) - x0) * 0.02
    moved = 0
    for v in ch.data.vertices:
        if v.co.x <= x0 + tol:
            v.co.x -= travel
            moved += 1
    ch.data.update()
    print('  charge handle shaft: %d verts extended %.1fmm forward '
          '(body %.1f -> %.1fmm vs %.1fmm travel)'
          % (moved, travel * 1000, (max(xs) - x0) * 1000,
             (max(xs) - x0 + travel) * 1000, travel * 1000))


def main():
    if bpy.context.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    coll = bpy.data.collections[COLL]
    old_gun = bpy.data.objects['M16A1_gun']

    appended = append_gun()
    bpy.context.view_layer.update()

    P = [bpy.data.objects['%s_%s' % (k, GUN)].matrix_world.translation.copy() for k in TRIO]
    Q = [bpy.data.objects['%s_M16A1' % k].matrix_world.translation.copy() for k in TRIO]
    FIT = kabsch(P, Q)
    res = [((FIT @ p) - q).length * 1000 for p, q in zip(P, Q)]
    print('fit residuals (mm): %s' % [round(r, 2) for r in res])
    if max(res) > MAX_RESIDUAL_MM:
        raise SystemExit('ABORT: residual %.2fmm > %.1fmm' % (max(res), MAX_RESIDUAL_MM))

    new_root = bpy.data.objects[GUN + '_root']
    new_root.matrix_world = FIT @ new_root.matrix_world
    bpy.context.view_layer.update()

    # --- carry the armory marker seats across the same fit -------------------
    # The armory markers were measured onto the new geometry; pushing them
    # through FIT lands them on that same geometry in arms space. Doing it any
    # other way is how sight_rear ended up 24mm behind the aperture on 07-28.
    for arms_name, armory_name in MARKERS.items():
        a = bpy.data.objects.get(arms_name)
        b = bpy.data.objects.get(armory_name)
        if a is None or b is None:
            print('  marker SKIP %s <- %s (missing)' % (arms_name, armory_name))
            continue
        # b is a child of the root, which FIT has ALREADY moved - its world
        # position is the fitted one. Applying FIT again here threw every marker
        # 3.4 metres across the scene on the first attempt.
        want = b.matrix_world.translation.copy()
        moved = (a.matrix_world.translation - want).length * 1000
        par = a.parent
        a.parent = None
        a.matrix_world.translation = want
        if par is not None:
            w = a.matrix_world.copy()
            a.parent = par
            a.matrix_parent_inverse = par.matrix_world.inverted()
            a.matrix_world = w
        print('  marker %-24s re-seated, moved %6.1f mm' % (arms_name, moved))
    bpy.context.view_layer.update()

    # --- the two animated parts: mesh data only ------------------------------
    import bmesh
    for oldname, newnames in GRAFT.items():
        old = bpy.data.objects[oldname]
        before = bbox_center(old)
        srcs = [bpy.data.objects[n] for n in newnames]
        palette = [m for m in srcs[0].data.materials]
        bm = bmesh.new()
        for new in srcs:
            tmp = new.data.copy()
            tmp.transform(old.matrix_world.inverted() @ new.matrix_world)
            bm.from_mesh(tmp)
            bpy.data.meshes.remove(tmp)
        me = bpy.data.meshes.new(old.data.name + '_v3')
        bm.to_mesh(me)
        bm.free()
        for m in palette:
            me.materials.append(m)
        old.data = me
        old.data.update()
        print('  grafted %-42s -> %-32s %3dv, moved %.1f mm'
              % ('+'.join(newnames), oldname, len(me.vertices),
                 (bbox_center(old) - before).length * 1000))

    extend_charge_handle(bpy.data.objects['M16A1_charge_handle_slide_back'])

    # --- the static shell ----------------------------------------------------
    skip = {n for names in GRAFT.values() for n in names}
    statics = [o for o in appended if o.type == 'MESH' and o.name not in skip]
    before = bbox_center(old_gun)
    newmesh = join_static(statics, old_gun)
    old_mesh = old_gun.data
    old_gun.data = newmesh
    old_gun.data.update()
    print('  static shell: %d shells -> %d verts on M16A1_gun, moved %.1f mm'
          % (len(statics), len(newmesh.vertices), (bbox_center(old_gun) - before).length * 1000))
    if old_mesh.users == 0:
        bpy.data.meshes.remove(old_mesh)

    # --- retire the 32 duplicate shells and their CHILD_OF copies ------------
    doomed = [o for o in list(coll.objects)
              if o.type == 'MESH' and o.name.startswith('M16A1_gun.')]
    n_con = sum(len([c for c in o.constraints if c.type == 'CHILD_OF']) for o in doomed)
    for o in doomed:
        bpy.data.objects.remove(o, do_unlink=True)
    print('  removed %d duplicate shells carrying %d CHILD_OF constraints' % (len(doomed), n_con))

    for o in [x for x in bpy.data.objects
              if x.name.startswith(GUN) or x.name.endswith('_' + GUN)]:
        bpy.data.objects.remove(o, do_unlink=True)

    left = sum(len([c for c in o.constraints if c.type == 'CHILD_OF'])
               for o in coll.objects if o.type == 'MESH')
    print('  CHILD_OF constraints left on meshes: %d' % left)

    for _ in range(3):
        bpy.ops.outliner.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)
    bpy.ops.wm.save_mainfile()
    print('SAVED', bpy.data.filepath)


if __name__ == '__main__':
    main()
