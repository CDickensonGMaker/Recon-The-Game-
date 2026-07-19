# bake_family_clip.py - turn a captured pose delta into a weapon-family clip.
# Caleb poses on any rig (Auto-IK), the session writes a deltas JSON, this
# bakes it: duplicate <base_clip> in the anim library -> <new_clip>, apply the
# per-bone quaternion deltas across every keyframe, save the master.
# Run: blender -b assets/shared/anim_library.blend -P tools/bake_family_clip.py -- <deltas.json>
import bpy
import json
import sys
from mathutils import Quaternion

# A hold delta belongs to the ARMS. Leaf markers (head top, toe tips, finger
# tips) pick up sub-degree Auto-IK residue during posing - never bake those.
ALLOW = ("LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
         "RightShoulder", "RightArm", "RightForeArm", "RightHand")

argv = sys.argv[sys.argv.index('--') + 1:]
# utf-8-sig: PowerShell writes BOMs; plain utf-8 json.load dies on them
with open(argv[0], encoding='utf-8-sig') as f:
    spec = json.load(f)

# singular (base_clip/new_clip) or batch ("clips": [{base, new}..]) spec
pairs = spec.get("clips") or [{"base": spec["base_clip"], "new": spec["new_clip"]}]
DELTAS = {}
for b, q in spec["deltas"].items():
    short = b.split(":")[-1]
    if any(short.startswith(a) for a in ALLOW):
        DELTAS[b] = Quaternion(q).normalized()
    else:
        print("filtered non-arm bone:", b)

rig = None
for ob in bpy.data.objects:
    if ob.type == 'ARMATURE':
        rig = ob
        break


def bake_pair(base_name, new_name):
    base_act = bpy.data.actions.get(base_name)
    if base_act is None:
        print("SKIP %s - base clip missing" % base_name)
        return
    old = bpy.data.actions.get(new_name)
    if old is not None:
        bpy.data.actions.remove(old)
    new_act = base_act.copy()
    new_act.name = new_name
    new_act.use_fake_user = True
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
    print("FAMILY CLIP '%s' <- '%s' (%d bones)" % (new_name, base_name, applied))


for p in pairs:
    bake_pair(p["base"], p["new"])
bpy.ops.wm.save_mainfile()
print("library master SAVED (%d clips baked)" % len(pairs))
