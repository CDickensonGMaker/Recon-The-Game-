"""Sync anim_library.blend with the corrected/new actions from us_grunt_v2.blend.

- Appends every action that exists in us_grunt_v2 but not in the library
  (the 23 new clips with arm-fix applied, reloading_fixed, renamed variants)
- Replaces library actions whose us_grunt_v2 counterpart was fixed
  (same-name actions get overwritten with the grunt version)
- Deletes jump_loop (the matrix slow-mo hang) if present
- Saves the library.

    blender -b assets/shared/anim_library.blend -P tools/sync_anim_library.py
"""
import bpy, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recon_paths import US_BASE_V3

SRC = US_BASE_V3        # was us_grunt_v2.blend — gone; v3 is the truth source

# actions the grunt file owns that the library should carry
before = {a.name for a in bpy.data.actions}

with bpy.data.libraries.load(SRC, link=False) as (src, dst):
    dst.actions = list(src.actions)

added, replaced, skipped = [], [], 0
for a in list(bpy.data.actions):
    if a.library:
        continue
    if a.name.endswith(".001"):  # appended duplicate of an existing name
        base = a.name[:-4]
        tgt = bpy.data.actions.get(base)
        if tgt and base in before:
            # incoming version wins: it carries the fixes
            tgt.user_remap(a)
            bpy.data.actions.remove(tgt)
            a.name = base
            replaced.append(base)
        else:
            bpy.data.actions.remove(a)
            skipped += 1
    elif a.name not in before:
        added.append(a.name)

for a in list(bpy.data.actions):
    a.use_fake_user = True

loop = bpy.data.actions.get("jump_loop")
if loop:
    loop.use_fake_user = False
    bpy.data.actions.remove(loop)
    print("jump_loop deleted", flush=True)

print(f"added {len(added)}: {sorted(added)}", flush=True)
print(f"replaced with fixed versions {len(replaced)}: {sorted(replaced)}", flush=True)
print(f"total actions in library: {len(bpy.data.actions)}", flush=True)

bpy.ops.wm.save_mainfile()
print("library saved", flush=True)
