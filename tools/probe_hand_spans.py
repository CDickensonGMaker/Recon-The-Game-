"""Measure each clip's two-handed grip: hand separation and height.

    blender -b assets/shared/anim_library.blend -P tools/probe_hand_spans.py

A weapon-family hold is defined by where the hands sit relative to the body. A
rifle hold and an LMG hold differ mostly in SPAN (hands further apart on a longer
receiver) and DROP (a heavy gun rides lower). This prints both so a family hold
can be lifted from a clip we already own instead of authored from nothing.

Saves nothing.
"""
import bpy

rig = None
for ob in bpy.data.objects:
    if ob.type == "ARMATURE":
        rig = ob
        break
if rig is None:
    print("[SPAN] FATAL: no armature")
    raise SystemExit(1)

L, R, HIP = "mixamorig:LeftHand", "mixamorig:RightHand", "mixamorig:Hips"
for b in (L, R, HIP):
    if b not in rig.pose.bones:
        print("[SPAN] FATAL: missing %s" % b)
        raise SystemExit(1)

scn = bpy.context.scene
rows = []
for act in bpy.data.actions:
    try:
        rig.animation_data.action = act
    except Exception:
        continue
    fr = act.frame_range
    scn.frame_set(int(fr[0]) + 1)
    bpy.context.view_layer.update()
    lh = rig.pose.bones[L].matrix.translation
    rh = rig.pose.bones[R].matrix.translation
    hp = rig.pose.bones[HIP].matrix.translation
    span = (lh - rh).length
    drop = ((lh.z + rh.z) * 0.5) - hp.z
    fwd = ((lh.y + rh.y) * 0.5) - hp.y
    rows.append((span, drop, fwd, act.name))

rows.sort(reverse=True)
print("[SPAN] span_m  drop_m  fwd_m   clip   (span = hand separation, drop = vs hips)")
for span, drop, fwd, nm in rows:
    print("[SPAN] %6.3f %7.3f %7.3f  %s" % (span, drop, fwd, nm))
