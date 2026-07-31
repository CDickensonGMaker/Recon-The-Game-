"""Turn a folder of downloaded Mixamo FBX files into one staging .blend.

    blender -b --factory-startup -P tools/import_mixamo_clips.py -- \
        --src assets/shared/mixamo_clips \
        --out assets/shared/mixamo_staging.blend

WHERE THINGS LIVE. Downloads go in `assets/shared/mixamo_clips/`, beside the library
they feed; the staging blend is `assets/shared/mixamo_staging.blend`, the same shape
as cover_clips_staging.blend and mg_gunner_staging.blend next to it. **`art_source/`
is a FORBIDDEN path - it was deleted and must not be recreated.**

The clips folder carries a `.gdignore`: 39 raw FBX are source, not game resources,
and without it Godot imports every one as a scene and carries them into the .pck.

Each clip's action is renamed to the FBX's filename stem - that stem IS the
house clip name, so naming happens on disk where it can be seen and fixed.

Mixamo rigs carry the same 41 bone names as PSXRig (measured by
tools/probe_mixamo_fit.py: 41/41, scale 1.0), so nothing is retargeted here.
Object-level curves are dropped for the same reason sync_clips_into_library
takes --bones-only: they are the performer's placement, not the performance.

Then, per clip:
    blender -b assets/shared/anim_library.blend -P tools/sync_clips_into_library.py -- \
        --src art_source/animations/mixamo_staging.blend --actions <names> --bones-only
    blender -b assets/shared/anim_library.blend -P tools/export_anim_library.py
"""
import bpy, sys, os, glob, argparse

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--src", required=True, help="folder of .fbx downloads")
ap.add_argument("--out", required=True, help="staging .blend to write")
args = ap.parse_args(argv)

src_dir = os.path.abspath(args.src)
fbxs = sorted(glob.glob(os.path.join(src_dir, "*.fbx")))
if not fbxs:
    print("[IMPORT] FATAL: no .fbx under %s" % src_dir)
    sys.exit(1)

for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)
for act in list(bpy.data.actions):
    bpy.data.actions.remove(act)


def _channelbags(action):
    out = []
    for layer in action.layers:
        for strip in layer.strips:
            for cb in strip.channelbags:
                out.append(cb)
    return out


def _strip_object_curves(action):
    n = 0
    for cb in _channelbags(action):
        for fc in list(cb.fcurves):
            if not fc.data_path.startswith("pose.bones"):
                cb.fcurves.remove(fc)
                n += 1
    return n


kept = []
for fbx in fbxs:
    stem = os.path.splitext(os.path.basename(fbx))[0]
    before = set(bpy.data.actions)
    before_objs = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=fbx)
    new_actions = [a for a in bpy.data.actions if a not in before]
    new_objs = [o for o in bpy.data.objects if o not in before_objs]

    if not new_actions:
        print("[IMPORT] %-22s NO ACTION - skipped" % stem)
        for o in new_objs:
            bpy.data.objects.remove(o, do_unlink=True)
        continue
    if len(new_actions) > 1:
        print("[IMPORT] %-22s %d actions, taking the longest" % (stem, len(new_actions)))
    act = max(new_actions, key=lambda a: a.frame_range[1] - a.frame_range[0])

    dropped = _strip_object_curves(act)
    act.name = stem
    act.use_fake_user = True
    fr = act.frame_range
    bones = len({fc.data_path.split('"')[1] for cb in _channelbags(act)
                 for fc in cb.fcurves if '"' in fc.data_path})
    print("[IMPORT] %-22s frames %.0f..%.0f  bones %d  dropped %d object curve(s)"
          % (stem, fr[0], fr[1], bones, dropped))
    kept.append(stem)

    for a in new_actions:
        if a is not act:
            bpy.data.actions.remove(a)
    for o in new_objs:
        bpy.data.objects.remove(o, do_unlink=True)

out = os.path.abspath(args.out)
os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=out)
print("[IMPORT] wrote %s" % out)
print("[IMPORT] actions: %s" % ",".join(kept))
