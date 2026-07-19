"""Link each unit file's collection into its scene so the files open normally.
Run: blender -b -P fix_unit_files.py
"""
import bpy, glob, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recon_paths import US_CHARACTERS_DIR

_UNITS = os.path.join(US_CHARACTERS_DIR, "_archive", "unit_*.blend")
for path in sorted(glob.glob(_UNITS)):
    bpy.ops.wm.open_mainfile(filepath=path)
    sc = bpy.context.scene
    linked = 0
    for c in bpy.data.collections:
        if c.name not in [x.name for x in sc.collection.children]:
            sc.collection.children.link(c)
            linked += 1
    if linked:
        bpy.ops.wm.save_mainfile()
    print(f"FIXED {path}: linked {linked} collection(s), objects now visible: {len(sc.objects)}", flush=True)
print("ALL UNIT FILES FIXED", flush=True)
