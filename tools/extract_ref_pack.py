"""Extract a reference FPS animation pack into weapon-space motion JSON.

    blender -b -P tools/extract_ref_pack.py -- bolt_rifle [--out refjson]

Reads tools/ref_packs.json, imports the pack's source, and writes one JSON per
clip holding every canonical key's world matrix on every frame. That JSON is
what tools/retarget_ref_anim.py transfers onto our rigs.

WHY THIS FILE EXISTS. ref_packs.json named this extractor as the thing that
rebuilds a pack, but it was never written: the only extracted pack lived in a
session scratchpad under AppData/Local/Temp, so the viewmodel pipeline depended
on a directory Windows is free to delete.

MATRICES ARE WORLD SPACE AND RAW. The consumer re-expresses everything in the
weapon's frame itself (Ref.W does W_Grip.inverted() @ key) and strips basis
scale itself (its norm()), so doing either here would apply it twice.

CLIP NAMES ARE MATCHED BY SUFFIX. The FBX importer prefixes actions with the
object they came off, so the pack's `Rig|SRifle_Reload` arrives as
`Rig|Rig|SRifle_Reload`. Exact match is tried first so a pack can always pin an
exact name if two clips ever collide.
"""
import bpy
import json
import os
import sys

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
if not argv:
    raise SystemExit('usage: -- <pack> [--out <dir>]')
PACK = argv[0]
OUT = argv[argv.index('--out') + 1] if '--out' in argv else 'refjson'

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
REG = json.load(open(os.path.join(HERE, 'ref_packs.json')))
if PACK not in REG['packs']:
    raise SystemExit('unknown pack %r; have %s' % (PACK, sorted(REG['packs'])))
spec = REG['packs'][PACK]
root = os.environ.get('RECON_REF_PACKS', REG['root'])
src = os.path.join(root, spec['source'])
if not os.path.exists(src):
    raise SystemExit('pack source missing: %s' % src)


def import_fbx(path):
    """Blender 5.0's FBX importer dies on lights (blen_read_light reaches for
    lamp.cycles.cast_shadow, removed in 5.0). We want bones, so stub it."""
    from io_scene_fbx import import_fbx as imp
    imp.blen_read_light = lambda tmpl, obj, settings: bpy.data.lights.new('stub', 'POINT')
    bpy.ops.import_scene.fbx(filepath=path, use_anim=True, ignore_leaf_bones=False)


def animates_bones(act):
    """A pack's clip name can match several actions - the FBX carries a camera
    action per clip whose name ends the same way. Only one drives the skeleton."""
    for layer in getattr(act, 'layers', []):
        for strip in getattr(layer, 'strips', []):
            for cb in (getattr(strip, 'channelbags', None) or []):
                for fc in cb.fcurves:
                    if fc.data_path.startswith('pose.bones'):
                        return True
    return False


def find_action(name):
    stem = name.split('|')[-1]
    cands = [a for a in bpy.data.actions
             if a.name == name or a.name.endswith(name)
             or a.name.endswith(stem) or stem in a.name]
    if not cands:
        return None
    boned = [a for a in cands if animates_bones(a)]
    pool = boned or cands
    exact = [a for a in pool if a.name == name or a.name.endswith(name)]
    return (exact or pool)[0]


def bind(obj, act):
    obj.animation_data_create()
    obj.animation_data.action = act
    # Blender 5.0 slotted actions: an action's curves are inert until a slot is
    # bound, and ActionSlot spells it target_id_type.
    pick = next((s for s in act.slots
                 if getattr(s, 'target_id_type', None) == 'OBJECT'), None)
    if pick is None and len(act.slots):
        pick = act.slots[0]
    if pick is not None:
        obj.animation_data.action_slot = pick


bpy.ops.wm.read_factory_settings(use_empty=True)
if spec.get('kind') == 'fbx':
    import_fbx(src)
elif spec.get('kind') == 'fbx_dir':
    for f in sorted(os.listdir(src)):
        if f.lower().endswith('.fbx'):
            import_fbx(os.path.join(src, f))
else:
    raise SystemExit('unsupported kind %r' % spec.get('kind'))

arm_name = spec.get('armature')
rig = (bpy.data.objects.get(arm_name) if arm_name else
       next((o for o in bpy.data.objects if o.type == 'ARMATURE'), None))
if rig is None:
    raise SystemExit('no armature (wanted %r)' % arm_name)

# map: canonical key -> "bone:Name" or "obj:Name"
targets = {}
for key, ref in spec['map'].items():
    kind, _, nm = ref.partition(':')
    if kind == 'bone':
        if nm not in rig.pose.bones:
            print('  WARN %s: no bone %r on %s' % (key, nm, rig.name))
            continue
        targets[key] = ('bone', nm)
    else:
        if nm not in bpy.data.objects:
            print('  WARN %s: no object %r' % (key, nm))
            continue
        targets[key] = ('obj', nm)

scene = bpy.context.scene
fps = scene.render.fps
outdir = OUT if os.path.isabs(OUT) else os.path.join(REPO, OUT)
os.makedirs(outdir, exist_ok=True)

print('pack %s  source %s' % (PACK, src))
print('  armature %s (%d bones)  fps %d' % (rig.name, len(rig.data.bones), fps))
print('  keys: %s' % ', '.join(sorted(targets)))
missing = [k for k in spec['map'] if k not in targets]
if missing:
    print('  MISSING KEYS: %s' % ', '.join(missing))

written = []
for clip, act_name in spec.get('clips', {}).items():
    act = find_action(act_name)
    if act is None:
        print('  %-14s SKIP - no action matching %r' % (clip, act_name))
        continue
    bind(rig, act)
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    frames = []
    for f in range(f0, f1 + 1):
        scene.frame_set(f)
        bpy.context.view_layer.update()
        rec = {}
        for key, (kind, nm) in targets.items():
            if kind == 'bone':
                m = rig.matrix_world @ rig.pose.bones[nm].matrix
            else:
                m = bpy.data.objects[nm].matrix_world
            rec[key] = [list(row) for row in m]
        frames.append(rec)
    path = os.path.join(outdir, '%s_%s.json' % (PACK, clip))
    with open(path, 'w') as fh:
        json.dump({'pack': PACK, 'clip': clip, 'action': act.name,
                   'fps': fps, 'frames': frames}, fh)
    written.append((clip, len(frames), os.path.getsize(path)))
    print('  %-14s %s  %3d frames (%.2fs)  -> %s' %
          (clip, act.name, len(frames), len(frames) / float(fps),
           os.path.basename(path)))

print('wrote %d clips to %s' % (len(written), outdir))
if not written:
    raise SystemExit('no clips extracted')
