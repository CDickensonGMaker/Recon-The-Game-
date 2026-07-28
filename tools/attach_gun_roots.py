"""Give every staged gun the Child Of that makes it ride the right hand.

    blender -b assets/player/arms/fp_arms_rifle.blend \
        -P tools/attach_gun_roots.py -- [--apply]

The 2026-07-27 transplant brought each gun in with its markers placed and its
arms already posed around it, but left the gun root unparented and
unconstrained - so nothing rode hand.R and no clip could be built. This adds the
missing 'hold_R' Child Of.

A Child Of is continuous ONLY if its stored inverse equals the target bone's
world matrix at the instant it engages:

    inverse = (rig.matrix_world @ pose.bones['hand.R'].matrix).inverted()

Computed at the current rest pose, that pins the gun exactly where it already
sits relative to the hand, so the blessed alignment survives. The script
measures the gun before and after and refuses to save if anything moved.
"""
import bpy
import sys

APPLY = '--apply' in sys.argv


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

added, skipped = [], []
for coll in sorted(bpy.data.collections, key=lambda c: c.name):
    if not coll.name.startswith('RIG_'):
        continue
    rig = next((o for o in coll.objects if o.type == 'ARMATURE'), None)
    if rig is None or 'hand.R' not in rig.pose.bones:
        continue
    pref = coll.name.replace('RIG_', '')
    muz = next((o for o in bpy.data.objects
                if o.name.startswith('muzzle_') and pref in o.name), None)
    if muz is None:
        skipped.append((coll.name, 'no muzzle marker to find the gun by'))
        continue
    root = top_of(muz)
    if any(c.type == 'CHILD_OF' and getattr(c, 'subtarget', '') == 'hand.R'
           for c in root.constraints):
        skipped.append((coll.name, '%s already rides hand.R' % root.name))
        continue

    before = root.matrix_world.copy()
    con = root.constraints.new('CHILD_OF')
    con.name = 'hold_R'
    con.target = rig
    con.subtarget = 'hand.R'
    con.inverse_matrix = (rig.matrix_world @ rig.pose.bones['hand.R'].matrix).inverted()
    con.influence = 1.0
    bpy.context.view_layer.update()
    moved = (root.matrix_world.translation - before.translation).length * 1000
    added.append((coll.name, root.name, moved))

print('\n  ATTACHED')
for cname, rname, moved in added:
    print('    %-30s %-28s moved %.4f mm' % (cname, rname, moved))
print('  SKIPPED')
for cname, why in skipped:
    print('    %-30s %s' % (cname, why))

worst = max([m for _, _, m in added], default=0.0)
print('\n  worst displacement on attach: %.4f mm' % worst)
if worst > 0.5:
    raise SystemExit('ABORT: attaching moved a gun - the inverse is wrong')

if APPLY:
    bpy.ops.wm.save_mainfile()
    print('  SAVED %s' % bpy.data.filepath)
else:
    print('  dry run - nothing saved (pass --apply to write)')
