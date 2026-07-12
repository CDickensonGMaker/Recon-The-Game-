"""Put every gore cap ON its joint and on a bone that SURVIVES the pop.

RECONgame-bv4q. Run on any character blend that follows the gib-rig contract:

    blender -b <character.blend> -P tools/fix_wound_caps.py

THE BUG THIS FIXES (found on BOTH the VC and the grunt truth source):
GibSystem.dismember() severs a limb by COLLAPSING its bone chain to zero. A cap
skinned to the severed bone therefore collapses with the limb and the stump
renders hollow. The cap must ride the severed bone's PARENT - the bone still
standing after the cut - and sit exactly on the joint (the cut plane).

Caught on the grunt: cap_head rode `Neck`, cap_forearm_l rode `LeftForeArm`,
cap_leg_r rode `RightUpLeg` - all three are the bones that get collapsed.
Caught on the VC: every cap was ALSO parked 1.4-2.2m out in front of the body.
tests/test_gore_rig.tscn passed anyway, because it only asserts the caps EXIST
and get revealed - not that they survive the collapse. Do not trust it alone.

Gear caps and cap_torso are left alone (TORSO is not a GibSystem REGION).
"""
import bpy
from mathutils import Vector

RIG = "PSXRig"

# cap -> (bone that is SEVERED and collapsed, bone that SURVIVES and carries it)
CAPS = {
    "cap_head":      ("mixamorig:Neck",         "mixamorig:Spine2"),
    "cap_forearm_l": ("mixamorig:LeftForeArm",  "mixamorig:LeftArm"),
    "cap_forearm_r": ("mixamorig:RightForeArm", "mixamorig:RightArm"),
    "cap_leg_l":     ("mixamorig:LeftUpLeg",    "mixamorig:Hips"),
    "cap_leg_r":     ("mixamorig:RightUpLeg",   "mixamorig:Hips"),
    "cap_uparm_l":   ("mixamorig:LeftArm",      "mixamorig:LeftShoulder"),
    "cap_uparm_r":   ("mixamorig:RightArm",     "mixamorig:RightShoulder"),
}


def main():
    rig = bpy.data.objects.get(RIG)
    if rig is None:
        print("SKIP: no %s" % RIG)
        return
    rig.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    bones = rig.data.bones

    fixed, ok, missing = [], [], []
    for cname, (sev, surv) in CAPS.items():
        o = bpy.data.objects.get(cname)
        if o is None or len(o.data.vertices) == 0:
            missing.append(cname)          # an empty husk exports to nothing
            continue
        me = o.data
        sb = bones[sev]
        joint = rig.matrix_world @ sb.head_local
        axis = (rig.matrix_world.to_3x3() @ (sb.tail_local - sb.head_local)).normalized()

        ws = [o.matrix_world @ v.co for v in me.vertices]
        ctr = sum(ws, Vector()) / len(ws)
        dom_tot = {}
        for v in me.vertices:
            for g in v.groups:
                n = o.vertex_groups[g.group].name
                dom_tot[n] = dom_tot.get(n, 0.0) + g.weight
        dom = max(dom_tot, key=dom_tot.get) if dom_tot else None
        off = (ctr - joint).length
        if dom == surv and off < 0.02:
            ok.append(cname)
            continue

        # face the cap down the limb, then land it on the cut plane
        nrm = (o.matrix_world.to_3x3() @ me.polygons[0].normal).normalized()
        rot = nrm.rotation_difference(axis).to_matrix()
        inv = o.matrix_world.inverted()
        for v in me.vertices:
            w = o.matrix_world @ v.co
            w = ctr + (rot @ (w - ctr))
            v.co = inv @ (w + (joint - ctr))
        me.update()

        for g in list(o.vertex_groups):
            o.vertex_groups.remove(g)
        vg = o.vertex_groups.new(name=surv)
        vg.add([v.index for v in me.vertices], 1.0, 'REPLACE')
        if not any(m.type == 'ARMATURE' for m in o.modifiers):
            m = o.modifiers.new("Armature", 'ARMATURE')
            m.object = rig
        o.hide_set(True)
        fixed.append("%s: rode %s (collapses!) %.3fm off -> rides %s, on joint"
                     % (cname, dom, off, surv))

    for line in fixed:
        print("  FIXED " + line)
    if ok:
        print("  already correct: %s" % ", ".join(ok))
    if missing:
        print("  MISSING/EMPTY (stump will render hollow): %s" % ", ".join(missing))

    rig.data.pose_position = 'POSE'
    if rig.animation_data:
        rig.animation_data.action = None
    bpy.context.scene.frame_set(1)
    if fixed:
        bpy.ops.wm.save_mainfile()
        print("saved:", bpy.data.filepath)
    else:
        print("nothing to do:", bpy.data.filepath)


if __name__ == "__main__":
    main()
