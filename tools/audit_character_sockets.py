"""audit_character_sockets.py - is every unit wearing its gear, and does it have its markers?

    blender -b -P tools/audit_character_sockets.py

Answers two questions by measurement, never by eye:

  1. ANCHORING. Rigid worn gear must be bone-parented to the bone it belongs on, and
     must sit on the man it belongs to. SKINNED gear (the gore caps, the bodies) is
     object-parented with an armature modifier - that is correct and is NOT a defect.
     Ownership is resolved through the RIG, never through the name suffix: a helmet on
     PSXRig_pointman.001 belongs to grunt_head_pointman.001, not to grunt_head_pilot,
     and matching on "_pilot" reports a 10 m error that does not exist.

  2. MARKERS. Which empties each rig carries, so the gaps are a list and not a hunch.
     Muzzle points live on the WEAPONS (weapons_us.blend: muzzle_<gun>), not on the
     characters - a character with no MuzzlePoint is not missing anything.

Read-only. Prints a table; changes nothing.
"""
import bpy, os
from mathutils import Vector

FILES = [r"C:\Users\caleb\RECONgame\assets\us\characters\us_base_v3.blend",
         r"C:\Users\caleb\RECONgame\assets\us\characters\us_v3_soldier_lineup.blend",
         r"C:\Users\caleb\RECONgame\assets\us\characters\us_pilot_white.blend",
         r"C:\Users\caleb\RECONgame\assets\us\characters\us_pilot_black.blend"]
RIGID_GEAR = ("helmet_", "hat_", "pith_")
FAR = 0.35          # bone_attach.py's own sanity limit


def rng(vs):
    return (Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs))),
            Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs))))


def ctr(o, dg):
    ev = o.evaluated_get(dg); me = ev.to_mesh()
    vs = [ev.matrix_world @ v.co for v in me.vertices]; ev.to_mesh_clear()
    lo, hi = rng(vs); return (lo + hi) / 2


def deformer(o):
    for m in o.modifiers:
        if m.type == 'ARMATURE' and m.object:
            return m.object
    return None


for path in FILES:
    if not os.path.exists(path):
        print("\n##### %s  -- ABSENT" % os.path.basename(path))
        continue
    bpy.ops.wm.open_mainfile(filepath=path)
    print("\n##### %s" % os.path.basename(path))
    for r in bpy.data.objects:
        if r.type == 'ARMATURE':
            r.data.pose_position = 'REST'
            if r.animation_data:
                r.animation_data.action = None
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()

    # every rig's own head mesh, found through the rig rather than through the name
    head_of = {}
    for o in bpy.data.objects:
        if o.type != 'MESH' or not o.name.startswith("grunt_head"):
            continue
        rig = deformer(o) or o.parent
        if rig is not None and rig.type == 'ARMATURE':
            head_of.setdefault(rig.name, o)

    print("\n  --- ANCHORING ---")
    problems = 0
    for g in sorted([o for o in bpy.data.objects
                     if o.type == 'MESH' and o.name.lower().startswith(RIGID_GEAR)],
                    key=lambda o: o.name):
        rig = g.parent
        flags = []
        if g.parent_type != 'BONE':
            if deformer(g) is not None:
                flags.append("skinned (ok)")
            else:
                flags.append("NOT bone-parented and NOT skinned")
        head = head_of.get(rig.name) if rig else None
        if head is not None and g.parent_type == 'BONE':
            d = (ctr(g, dg) - ctr(head, dg)).length
            if d > FAR:
                flags.append("%.3f m FROM ITS OWN HEAD (%s)" % (d, head.name))
        s = g.scale
        if max(abs(s.x - 1), abs(s.y - 1), abs(s.z - 1)) > 1e-4:
            flags.append("scale=%s" % (tuple(round(v, 4) for v in s),))
        bad = [f for f in flags if "ok" not in f]
        if bad:
            problems += 1
        print("    %-32s rig=%-24s %s"
              % (g.name, rig.name if rig else "<none>", " | ".join(flags) if flags else "OK"))
    print("    -> %d rigid gear piece(s) with a real problem" % problems)

    print("\n  --- SKINNED HEADGEAR (object-parented by design) ---")
    caps = [o for o in bpy.data.objects
            if o.type == 'MESH' and o.name.startswith("cap_head")]
    unskinned = [o.name for o in caps if deformer(o) is None]
    print("    %d cap_head* meshes, %s"
          % (len(caps), "all skinned" if not unskinned else "NOT SKINNED: %s" % unskinned))

    print("\n  --- MARKERS per rig ---")
    by_rig = {}
    for e in [o for o in bpy.data.objects if o.type == 'EMPTY']:
        by_rig.setdefault(e.parent.name if e.parent else "<unparented>", []).append(e.name)
    for rn in sorted(by_rig):
        print("    %-28s %d: %s" % (rn, len(by_rig[rn]), sorted(by_rig[rn])))
    rigs = sorted(o.name for o in bpy.data.objects if o.type == 'ARMATURE')
    missing = [r for r in rigs if not any(n.startswith("socket_head") for n in by_rig.get(r, []))]
    if missing:
        print("    rigs with NO socket_head: %s" % missing)
