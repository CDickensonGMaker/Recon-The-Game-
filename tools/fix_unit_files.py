"""Link each unit file's collection into its scene so the files open normally.
Run: blender -b -P fix_unit_files.py
"""
import bpy, glob

for path in sorted(glob.glob(r"C:\Users\caleb\RECONgame\assets\characters\source\units\unit_*.blend")):
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
