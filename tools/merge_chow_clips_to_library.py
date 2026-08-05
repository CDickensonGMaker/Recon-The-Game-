"""Merge the chow hall clips into the shared animation library.

    blender -b assets/shared/anim_library.blend -P tools/merge_chow_clips_to_library.py -- --save

Caleb: *"were making animation clips not a baked model."* The Blender scene is a review
diorama; the DELIVERABLE is the clip set, which the engine repeats per model.

Every clip is verified self-contained before it is taken: 41 bones, location keyed on
all 41, root motion in the Hips channel. A clip that keys only the root silently depends
on pose state that is not in the file and collapses the moment it is played anywhere
else - that cost most of a day on 8/3.
"""
import bpy
import os
import sys

SRC = (r"C:\Users\caleb\RECONgame\assets\world\building models\structures"
       r"\firebase\kit\chow_hall.blend")
PREFIX = "chow_"


def channels(a):
    kinds, bones = {}, set()
    for lay in a.layers:
        for st in lay.strips:
            for cb in st.channelbags:
                for fc in cb.fcurves:
                    key = fc.data_path.rsplit(".", 1)[-1]
                    kinds[key] = kinds.get(key, 0) + 1
                    if fc.data_path.startswith('pose.bones['):
                        bones.add(fc.data_path.split('"')[1])
    return kinds, bones


def main():
    before = {a.name for a in bpy.data.actions}
    # drop any older copy so a re-author is never silently ignored
    dropped = [a.name for a in list(bpy.data.actions) if a.name.startswith(PREFIX)]
    for n in dropped:
        bpy.data.actions.remove(bpy.data.actions[n])
    if dropped:
        print("  replaced existing:", ", ".join(sorted(dropped)))

    with bpy.data.libraries.load(SRC, link=False) as (src, dst):
        dst.actions = [n for n in src.actions if n.startswith(PREFIX)]

    took, bad = [], []
    for a in bpy.data.actions:
        if not a.name.startswith(PREFIX):
            continue
        a.use_fake_user = True          # zero-user datablocks are NOT written on save
        kinds, bones = channels(a)
        nloc = kinds.get("location", 0) // 3
        n = int(a.frame_range[1] - a.frame_range[0]) + 1
        if len(bones) < 41 or nloc < len(bones):
            bad.append("%s: %d bones, location on %d" % (a.name, len(bones), nloc))
        took.append((a.name, n, len(bones), nloc))

    print("\n%-24s %6s %6s %6s" % ("clip", "frames", "bones", "loc"))
    for n, f, b, l in sorted(took):
        print("%-24s %6d %6d %6d" % (n, f, b, l))
    print("\n  merged %d clips | library now holds %d actions"
          % (len(took), len(bpy.data.actions)))
    if bad:
        print("  NOT SELF-CONTAINED:")
        for b in bad:
            print("   !!", b)

    if "--save" in sys.argv and not bad:
        bpy.ops.wm.save_mainfile(compress=True)
        print("  SAVED %s (%.1f MB)"
              % (bpy.data.filepath, os.path.getsize(bpy.data.filepath) / 1048576))
    elif bad:
        print("  NOT SAVING - fix the clips above first")
    else:
        print("  dry run (pass --save to write)")


main()
