"""Bake out the two non-uniform part scales the GLB validator caught (2026-07-26).

    blender -b assets/player/arms/fp_arms_rifle.blend -P tools/normalize_m16_part_scales.py

M16A1_magazine.030 carried object scale (1.4606, 1.0023, 2.7149) - the mesh data is
authored thin and the scale fattens it. Applying the scale bakes the true size into
the verts; appearance is untouched (leaf object, its clips key only constraint
influence, never scale). sight_rear_M16A1 is an empty with scale (1.18, 1, 1) -
scale is meaningless on a childless marker; normalized. Verifies world positions
unchanged, saves only on pass, never writes .blend1.
"""
import bpy, sys

fails = []
if bpy.context.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')

mag = bpy.data.objects["M16A1_magazine.030"]
pre = mag.matrix_world.translation.copy()
pre_dim = mag.dimensions[:]
if mag.data.users > 1:
    mag.data = mag.data.copy()
for o in bpy.data.objects:
    o.select_set(False)
mag.select_set(True)
bpy.context.view_layer.objects.active = mag
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
bpy.context.view_layer.update()
if (mag.matrix_world.translation - pre).length > 1e-4:
    fails.append("mag moved during scale apply")
if any(abs(a - b) > 1e-3 for a, b in zip(pre_dim, mag.dimensions[:])):
    fails.append(f"mag dimensions changed: {pre_dim} -> {mag.dimensions[:]}")
if max(mag.scale) - min(mag.scale) > 1e-4:
    fails.append(f"mag scale still non-uniform: {list(mag.scale)}")

sr = bpy.data.objects["sight_rear_M16A1"]
pre_sr = sr.matrix_world.translation.copy()
sr.scale = (1.0, 1.0, 1.0)
bpy.context.view_layer.update()
if (sr.matrix_world.translation - pre_sr).length > 1e-4:
    fails.append("sight_rear moved during scale normalize")

if fails:
    for f in fails:
        print("NORM-FAIL:", f)
    sys.exit(1)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_mainfile()
print("NORMALIZE RESULT: PASS - saved", bpy.data.filepath)
