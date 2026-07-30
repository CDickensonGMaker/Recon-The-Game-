"""Append named actions from a source .blend into anim_library.blend.

The existing sync_anim_library.py is hardwired to US_BASE_V3. This one takes any
source and an explicit action list, which is what the staged work needs: the cover
clips (cover_clips_staging.blend) and the Huey/artillery crew actions each live in
their own staging file and must land on the library's single PSXRig.

Actions are appended by NAME ONLY. A name already in the library is skipped, never
overwritten - the library is the shipped truth and a staging file is a proposal.
Pass --replace to invert that for a deliberate re-author.

    blender -b assets/shared/anim_library.blend -P tools/sync_clips_into_library.py -- \
        --src assets/shared/cover_clips_staging.blend \
        --actions cover_peek,cover_kneel_brace

    # every action matching a prefix, renamed on the way in:
    blender -b assets/shared/anim_library.blend -P tools/sync_clips_into_library.py -- \
        --src assets/us/vehicles/huey_embark_staging.blend --prefix board_ --dry-run

Writes nothing unless it appended something. Always re-export afterwards:
    blender -b assets/shared/anim_library.blend -P tools/export_anim_library.py
"""
import bpy, sys, os, argparse

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--src", required=True, help="source .blend to pull actions from")
ap.add_argument("--actions", default="", help="comma-separated action names")
ap.add_argument("--prefix", default="", help="take every source action with this prefix")
ap.add_argument("--rename", default="", help="comma-separated old=new pairs applied on import")
ap.add_argument("--replace", action="store_true", help="overwrite same-named library actions")
ap.add_argument("--bones-only", action="store_true",
                help="drop every non-pose.bones curve. REQUIRED for staged crew actions: "
                     "their object location/rotation curves are the man's PLACEMENT in the "
                     "staging scene, and keeping them teleports every carrier of the clip "
                     "to that spot in game.")
ap.add_argument("--dry-run", action="store_true")
args = ap.parse_args(argv)

src = os.path.abspath(args.src)
if not os.path.isfile(src):
    print("[SYNC] FATAL: source not found: %s" % src)
    sys.exit(1)

want = {n.strip() for n in args.actions.split(",") if n.strip()}
renames = {}
for pair in args.rename.split(","):
    if "=" in pair:
        old, new = pair.split("=", 1)
        renames[old.strip()] = new.strip()

def _channelbags(action):
    """Blender 5.0 slotted actions: fcurves live under layers/strips/channelbags."""
    out = []
    for layer in action.layers:
        for strip in layer.strips:
            for cb in strip.channelbags:
                out.append(cb)
    return out


def _strip_object_curves(action):
    """Remove every fcurve that is not a bone pose channel. Returns how many went."""
    n = 0
    legacy = None
    try:
        legacy = action.fcurves
        _ = len(legacy)
    except Exception:
        legacy = None
    if legacy is not None and len(legacy):
        for fc in list(legacy):
            if not fc.data_path.startswith("pose.bones"):
                legacy.remove(fc)
                n += 1
        return n
    for cb in _channelbags(action):
        for fc in list(cb.fcurves):
            if not fc.data_path.startswith("pose.bones"):
                cb.fcurves.remove(fc)
                n += 1
    return n


before = {a.name for a in bpy.data.actions}
print("[SYNC] library holds %d action(s) before" % len(before))

# Peek at the source without appending, so a typo reports instead of silently doing nothing.
with bpy.data.libraries.load(src, link=False) as (src_data, _dst):
    available = list(src_data.actions)
print("[SYNC] source holds %d action(s)" % len(available))

if args.prefix:
    want |= {n for n in available if n.startswith(args.prefix)}
if not want:
    print("[SYNC] FATAL: no actions selected (pass --actions or --prefix)")
    sys.exit(1)

missing = sorted(want - set(available))
if missing:
    print("[SYNC] FATAL: not in source: %s" % ", ".join(missing))
    sys.exit(1)

# A name that already exists lands as "<name>.001"; resolving that is the whole job.
take = sorted(want)
collide = [n for n in take if renames.get(n, n) in before]
if collide and not args.replace:
    print("[SYNC] already in the library, skipping: %s" % ", ".join(collide))
    take = [n for n in take if renames.get(n, n) not in before]
if not take:
    print("[SYNC] nothing to do")
    sys.exit(0)

print("[SYNC] appending %d: %s" % (len(take), ", ".join(take)))
if args.dry_run:
    print("[SYNC] dry run - nothing written")
    sys.exit(0)

# A COPY: Blender rewrites the list it is handed in place, swapping the names for the
# loaded datablocks, and `take` is still needed as names below.
with bpy.data.libraries.load(src, link=False) as (src_data, dst):
    dst.actions = list(take)

added, replaced = [], []
for name in take:
    final = renames.get(name, name)
    # The appended datablock is the one that is NOT in `before`: either `name` (fresh)
    # or `name.001` (Blender's collision suffix when --replace put it beside the old).
    inc = bpy.data.actions.get(name + ".001") or bpy.data.actions.get(name)
    if inc is None:
        print("[SYNC] WARN: %s did not append" % name)
        continue
    old = bpy.data.actions.get(final)
    if old is not None and old is not inc:
        old.user_remap(inc)
        bpy.data.actions.remove(old)
        replaced.append(final)
    inc.name = final
    if args.bones_only:
        dropped = _strip_object_curves(inc)
        if dropped:
            print("[SYNC]   %s: dropped %d object curve(s)" % (final, dropped))
    # Survive the export: export_anim_library.py NLA-strips real actions, and a
    # 0-user action is purged on save before it ever gets there.
    inc.use_fake_user = True
    if final not in replaced:
        added.append(final)

after = {a.name for a in bpy.data.actions}
lost = sorted(before - after - set(replaced))
if lost:
    print("[SYNC] FATAL: would have LOST %s - refusing to save" % ", ".join(lost))
    sys.exit(1)

bpy.ops.wm.save_mainfile()
print("[SYNC] added %d, replaced %d; library now holds %d action(s)"
      % (len(added), len(replaced), len(after)))
print("[SYNC] NOW RE-EXPORT: blender -b assets/shared/anim_library.blend -P tools/export_anim_library.py")
