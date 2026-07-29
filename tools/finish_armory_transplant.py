"""Bring across the gun parts the 2026-07-27 transplant left at the armory.

    blender -b assets/player/arms/fp_arms_rifle.blend \
        -P tools/finish_armory_transplant.py -- <T.json> [--apply] [gun ...]

transplant_armory_parts.py maps armory space to arms space with
`o.matrix_world = T @ o.matrix_world` (:195), where T is the fused copy's own
object matrix. Some parts never got that pass, so they still sit at armory
coordinates - measured 2026-07-28, RPD_drum 2.63 m from its receiver and the
M60's charge handle 34 m - which makes the gun measure 2.7x its real length and
export_all_viewmodels reject it.

The fused copies were consumed by that run, so T is recovered from the last
commit before it (5a969c81) and passed in as JSON.

A part is stranded if it sits more than THRESH from where its gun lives in the
arms file. Applying T to an already-transplanted part would double-transform it,
so only stranded parts are touched, and the script re-measures afterwards.
"""
import bpy
import json
import sys
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
TJSON = argv[0]
APPLY = '--apply' in argv
ONLY = [a for a in argv[1:] if not a.startswith('--')]

THRESH = 1.0

# fused mesh name -> the collection its parts belong to
FUSED = {
    'M60_MG_gun': 'RIG_M60_MG', 'RPD_gun': 'RIG_RPD', 'Mosin_gun': 'RIG_Mosin',
    'Colt45_Pistol_gun': 'RIG_Colt45_Pistol',
    'Ithaca37_Shotgun_gun': 'RIG_Ithaca37_Shotgun',
    'M79_Launcher_gun': 'RIG_M79_Launcher', 'M72_LAW_gun': 'RIG_M72_LAW',
    'RPG2_gun': 'RIG_RPG2', 'RPG7_gun': 'RIG_RPG7',
    'Thompson_Submachine_Gun_gun': 'RIG_Thompson_Submachine_Gun',
    'M70sniper_gun': 'RIG_M70sniper',
}

Ts = {k: Matrix(v) for k, v in json.load(open(TJSON)).items()}


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


for coll in bpy.data.collections:
    if coll.name.startswith('RIG_'):
        unhide(coll)
bpy.context.view_layer.update()
bpy.context.scene.frame_set(0)
bpy.context.view_layer.update()

print('\n  %-28s %6s %8s %10s %10s' % ('gun', 'parts', 'stranded', 'worst_before', 'worst_after'))
for fused, cname in sorted(FUSED.items()):
    coll = bpy.data.collections.get(cname)
    if coll is None or fused not in Ts:
        continue
    if ONLY and cname.replace('RIG_', '') not in ONLY:
        continue
    T = Ts[fused]
    target = T.translation

    objs = [o for o in coll.objects if o.type in {'MESH', 'EMPTY'}]
    seen = set(objs)
    for o in list(objs):
        stack = list(o.children)
        while stack:
            c = stack.pop()
            stack.extend(c.children)
            if c not in seen and c.type in {'MESH', 'EMPTY'}:
                seen.add(c)
                objs.append(c)

    def dist(o):
        return (o.matrix_world.translation - target).length

    stranded = [o for o in objs if dist(o) > THRESH]
    before = max((dist(o) for o in objs), default=0.0)

    if APPLY and stranded:
        # deepest-first, so a parent's move does not drag a child already queued
        for o in sorted(stranded, key=lambda x: -len(x.name)):
            keep = [(c, c.matrix_world.copy()) for c in o.children if c not in stranded]
            o.matrix_world = T @ o.matrix_world
            for c, wm in keep:
                c.matrix_world = wm
        bpy.context.view_layer.update()

    after = max((dist(o) for o in objs), default=0.0)
    print('  %-28s %6d %8d %9.2f m %9.2f m'
          % (cname.replace('RIG_', ''), len(objs), len(stranded), before, after))

if APPLY:
    bpy.ops.wm.save_mainfile()
    print('\n  SAVED %s' % bpy.data.filepath)
else:
    print('\n  dry run - nothing saved (pass --apply to write)')
