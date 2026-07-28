"""Move each staged gun root's ORIGIN into the gun, without moving the gun.

    blender -b assets/player/arms/fp_arms_rifle.blend \
        -P tools/reorigin_gun_roots.py -- [--apply]

Measured 2026-07-28: the staged guns are NOT mis-placed. The RPD's mesh centroid
sits 0.475 m from its hand.R and the AK's sits 0.322 m - both correctly in the
hands. What is wrong is the ROOT EMPTY's origin, still parked at the armory
station 2.76 m away, and that origin is what export_all_viewmodels measures:
"RPD bakes 2.76 m from hand.R - rig contract broken".

So this moves the origin only. Every child's world matrix is saved and restored
across the move, so no vertex shifts. The script measures the mesh centroid
before and after and refuses to save if any geometry moved.

Run order for a newly transplanted gun:
    reorigin_gun_roots.py  ->  attach_gun_roots.py  ->  retarget_ref_anim.py
"""
import bpy
import sys
from mathutils import Matrix, Vector

APPLY = '--apply' in sys.argv
KNOWN_GOOD = {'AK47', 'M16A1', 'M14', 'PPSh41'}


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


def centroid(root):
    pts = []
    stack = [root]
    while stack:
        o = stack.pop()
        stack.extend(o.children)
        if o.type == 'MESH' and len(o.data.vertices):
            mw = o.matrix_world
            vs = o.data.vertices
            for i in range(0, len(vs), max(1, len(vs) // 60)):
                pts.append(mw @ vs[i].co)
    return (sum(pts, Vector()) / len(pts)) if pts else None


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
    if pref in KNOWN_GOOD:
        continue
    rig = next((o for o in coll.objects if o.type == 'ARMATURE'), None)
    if rig is None or 'hand.R' not in rig.pose.bones:
        continue
    muz = bpy.data.objects.get('muzzle_%s' % pref)
    if muz is None:
        rows.append((pref, None, None, None, 'no muzzle marker - not a gun'))
        continue
    anchor = bpy.data.objects.get('grip_R_%s' % pref) or muz
    root = top_of(anchor)
    hand = (rig.matrix_world @ rig.pose.bones['hand.R'].matrix).translation
    before_c = centroid(root)
    before_d = (root.matrix_world.translation - hand).length

    # anchor on a MARKER, never a centroid: a stray child put the M60's origin
    # 35 m out when the centroid was used
    target = anchor.matrix_world.translation.copy()
    if before_c is None:
        rows.append((pref, None, None, None, 'no mesh under root'))
        continue

    if APPLY:
        cons = [(c.type, getattr(c, 'target', None), getattr(c, 'subtarget', ''),
                 c.influence, c.name) for c in root.constraints if c.type == 'CHILD_OF']
        for c in list(root.constraints):
            if c.type == 'CHILD_OF':
                root.constraints.remove(c)
        bpy.context.view_layer.update()
        saved = [(ch, ch.matrix_world.copy()) for ch in root.children]
        m = root.matrix_world.copy()
        m.translation = target
        root.matrix_world = m
        bpy.context.view_layer.update()
        for ch, wm in saved:
            ch.matrix_world = wm
        bpy.context.view_layer.update()
        # constraints are re-added by attach_gun_roots.py with a fresh inverse
        del cons

    after_c = centroid(root)
    after_d = (root.matrix_world.translation - hand).length
    drift = (after_c - before_c).length * 1000 if (after_c and before_c) else 0.0
    rows.append((pref, before_d, after_d, drift, None))

print('\n  %-26s %14s %14s %12s' % ('gun', 'root->hand was', 'now', 'geom moved'))
worst = 0.0
for pref, bd, ad, drift, err in rows:
    if err:
        print('  %-26s %s' % (pref, err))
        continue
    worst = max(worst, drift)
    print('  %-26s %11.3f m %11.3f m %9.3f mm' % (pref, bd, ad, drift))

print('\n  worst geometry movement: %.4f mm' % worst)
if worst > 0.5:
    raise SystemExit('ABORT: re-origin moved geometry')

if APPLY:
    bpy.ops.wm.save_mainfile()
    print('  SAVED %s' % bpy.data.filepath)
    print('  NEXT: re-run tools/attach_gun_roots.py -- --apply')
else:
    print('  dry run - nothing saved (pass --apply to write)')
