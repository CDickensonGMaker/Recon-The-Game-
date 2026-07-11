# bake_family_clip.py - turn a captured pose delta into a weapon-family clip.
# Caleb poses on any rig (Auto-IK), the session writes a deltas JSON, this
# bakes it: duplicate <base_clip> in the anim library -> <new_clip>, apply the
# per-bone quaternion deltas across every keyframe, save the master.
# Run: blender -b art_source/characters/base_psx/anim_library.blend -P tools/bake_family_clip.py -- <deltas.json>
import bpy
import json
import sys
from mathutils import Quaternion

argv = sys.argv[sys.argv.index('--') + 1:]
with open(argv[0]) as f:
    spec = json.load(f)

BASE = spec["base_clip"]
NEW = spec["new_clip"]
DELTAS = {b: Quaternion(q).normalized() for b, q in spec["deltas"].items()}

rig = None
for ob in bpy.data.objects:
    if ob.type == 'ARMATURE':
        rig = ob
        break
base_act = bpy.data.actions[BASE]

old = bpy.data.actions.get(NEW)
if old is not None:
    bpy.data.actions.remove(old)
new_act = base_act.copy()
new_act.name = NEW
new_act.use_fake_user = True

# find the channelbag (Blender 5 slotted actions)
slot = new_act.slots[0]
cb = None
for layer in new_act.layers:
    for strip in layer.strips:
        cb = strip.channelbag(slot)
        break

applied = 0
for bone, d in DELTAS.items():
    path = 'pose.bones["%s"].rotation_quaternion' % bone
    fcs = sorted([fc for fc in cb.fcurves if fc.data_path == path], key=lambda f: f.array_index)
    if len(fcs) != 4:
        print("SKIP %s (channels: %d)" % (bone, len(fcs)))
        continue
    n = len(fcs[0].keyframe_points)
    prev = None
    for i in range(n):
        q = Quaternion((fcs[0].keyframe_points[i].co[1], fcs[1].keyframe_points[i].co[1],
                        fcs[2].keyframe_points[i].co[1], fcs[3].keyframe_points[i].co[1]))
        qn = (d @ q).normalized()
        if prev is not None and prev.dot(qn) < 0.0:
            qn = -qn
        prev = qn
        for ci, fc in enumerate(fcs):
            fc.keyframe_points[i].co[1] = qn[ci]
    for fc in fcs:
        fc.update()
    applied += 1
    print("baked %s across %d keys" % (bone, n))

print("FAMILY CLIP '%s' created from '%s' (%d bones adjusted)" % (NEW, BASE, applied))
bpy.ops.wm.save_mainfile()
print("library master SAVED")
