"""Read-only audit of every FP viewmodel rig. Never saves the .blend.

    blender -b assets/player/arms/fp_arms_rifle.blend -P tools/audit_viewmodel_rigs.py -- [gun ...]

Answers, per gun, with measurements rather than opinion:
  1. transform hygiene   - object scale, non-uniform scale, unapplied gun-root rotation
  2. rig contract        - gun root rides hand.R, clip tracks present, markers parented
  3. strip/action pairing- a part strip whose action was authored for a DIFFERENT clip length
                           (the AK reload mag-float class)
  4. pacing              - per-frame hand speed, so "fast then slow" is a curve, not a feeling
  5. handle census       - AUTO_CLAMPED keys, the measured #1 cause of robotic motion
  6. hand/gun penetration- skinned arm vertices that end up INSIDE gun geometry

Writes production/research/viewmodel_rig_audit.json.
"""
import bpy, sys, os, json, math
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []

MANIFEST = r"C:\Users\caleb\RECONgame\tools\viewmodel_manifest.json"
OUT = r"C:\Users\caleb\RECONgame\production\research\viewmodel_rig_audit.json"

with open(MANIFEST) as f:
    manifest = json.load(f)
guns = {k: v for k, v in manifest["guns"].items() if not argv or k in argv}

PENETRATION_MM = 8.0        # deeper than this reads as a hand inside the gun
HAND_RADIUS = 0.16          # only arm verts this close to a hand bone are candidates
SPEED_SPIKE_RATIO = 3.0     # frame-to-frame speed change that reads as a lurch


def fcurves_of(act):
    """Blender 5 slotted actions dropped Action.fcurves."""
    if hasattr(act, "fcurves") and len(act.fcurves):
        return list(act.fcurves)
    out = []
    for layer in getattr(act, "layers", []):
        for strip in getattr(layer, "strips", []):
            bags = getattr(strip, "channelbags", None)
            if bags is None:
                continue
            for cb in bags:
                out.extend(cb.fcurves)
    return out


def act_range(act):
    fcs = fcurves_of(act)
    kps = [kp.co[0] for fc in fcs for kp in fc.keyframe_points]
    return (min(kps), max(kps)) if kps else (0.0, 0.0)


def unhide(objs, coll_name):
    vl = bpy.context.view_layer

    def find(name, layer=None):
        layer = layer or vl.layer_collection
        if layer.collection.name == name:
            return layer
        for ch in layer.children:
            r = find(name, ch)
            if r:
                return r
    lc = find(coll_name)
    if lc:
        lc.exclude = False
        lc.hide_viewport = False
    for o in objs:
        o.hide_viewport = False
        o.hide_render = False
    bpy.context.view_layer.update()
    for o in objs:
        o.hide_set(False)


report = {}

for gun_key, spec in guns.items():
    coll = bpy.data.collections.get(spec["collection"])
    if coll is None:
        report[gun_key] = {"error": f"collection {spec['collection']} missing"}
        continue
    objs = list(coll.objects)
    rig = next((o for o in objs if o.type == 'ARMATURE'), None)
    if rig is None:
        report[gun_key] = {"error": "no armature"}
        continue
    unhide(objs, spec["collection"])

    g = {"collection": spec["collection"], "rig": rig.name,
         "transforms": [], "contract": [], "pairing": [], "pacing": {},
         "handles": {}, "penetration": {}}

    # ---- 1. transform hygiene -------------------------------------------
    for o in objs:
        s = o.scale
        nonuni = abs(s[0] - s[1]) > 1e-4 or abs(s[1] - s[2]) > 1e-4
        scaled = any(abs(v - 1.0) > 1e-4 for v in s)
        rot = o.rotation_euler if o.rotation_mode not in {'QUATERNION', 'AXIS_ANGLE'} else None
        rotated = rot is not None and any(abs(v) > 1e-4 for v in rot)
        if nonuni or scaled or (rotated and o.name in (spec["gun_root"], rig.name)):
            g["transforms"].append({
                "object": o.name,
                "scale": [round(v, 5) for v in s],
                "non_uniform": nonuni,
                "rotation_deg": [round(math.degrees(v), 3) for v in rot] if rot else None,
                "animated": bool(o.animation_data and (o.animation_data.action
                                                       or o.animation_data.nla_tracks)),
            })

    # ---- 2. rig contract -------------------------------------------------
    root = bpy.data.objects.get(spec["gun_root"])
    if root is None:
        g["contract"].append(f"gun root {spec['gun_root']} MISSING")
    else:
        rides = [c for c in root.constraints
                 if c.type == 'CHILD_OF' and getattr(c, "subtarget", "") == "hand.R"]
        if not rides:
            g["contract"].append(
                f"{root.name} has NO CHILD_OF->hand.R (constraints: "
                f"{[c.type for c in root.constraints] or 'none'})")
    rig_tracks = {t.name for t in rig.animation_data.nla_tracks} if rig.animation_data else set()
    for clip in spec["clips"]:
        if clip not in rig_tracks:
            g["contract"].append(f"rig has no NLA track '{clip}'")
    for m in (f"muzzle_{spec['gun_prefix']}", f"sight_front_{spec['gun_prefix']}",
              f"sight_rear_{spec['gun_prefix']}"):
        mo = bpy.data.objects.get(m)
        if mo is None:
            g["contract"].append(f"marker {m} MISSING")
        elif root is not None and mo.parent is not root:
            g["contract"].append(
                f"marker {m} parented to {mo.parent.name if mo.parent else 'WORLD'}, not {root.name}")

    # ---- 3. strip / action pairing ---------------------------------------
    clip_len = {}
    for t in rig.animation_data.nla_tracks:
        for s in t.strips:
            clip_len[t.name] = max(clip_len.get(t.name, 0), int(round(s.frame_end)))
    g["clip_lengths"] = clip_len
    seen_action_tracks = {}
    for o in objs:
        if not o.animation_data:
            continue
        for t in o.animation_data.nla_tracks:
            for s in t.strips:
                if s.action is None:
                    g["pairing"].append(f"{o.name}/{t.name}: strip has NO action")
                    continue
                seen_action_tracks.setdefault(s.action.name, []).append(f"{o.name}/{t.name}")
                if t.name in clip_len:
                    a0, a1 = act_range(s.action)
                    authored = a1 - a0
                    target = clip_len[t.name]
                    if authored > 1 and abs(authored - target) > 2:
                        g["pairing"].append({
                            "part": o.name, "track": t.name,
                            "action": s.action.name,
                            "action_frames": round(authored, 1),
                            "clip_frames": target,
                            "note": "action authored for a different length than the clip it plays under",
                        })
    for aname, users in seen_action_tracks.items():
        tracks = {u.split("/", 1)[1] for u in users}
        if len(tracks) > 1:
            lens = {clip_len.get(t) for t in tracks if t in clip_len}
            if len(lens) > 1:
                g["pairing"].append({
                    "action": aname, "reused_under": sorted(tracks),
                    "clip_frames": sorted(x for x in lens if x),
                    "note": "ONE action reused under clips of DIFFERENT lengths",
                })

    # ---- 4/5/6. evaluate every clip --------------------------------------
    def solo(track):
        for o in objs:
            if o.animation_data:
                for t in o.animation_data.nla_tracks:
                    t.mute = (t.name != track)
        if o and o.animation_data:
            pass

    for o in objs:
        if o.animation_data:
            o.animation_data.action = None

    gun_meshes = []
    if root is not None:
        stack = [root]
        while stack:
            o = stack.pop()
            stack.extend(o.children)
            if o.type == 'MESH':
                gun_meshes.append(o)
    arms = next((o for o in objs if o.type == 'MESH' and o.parent is rig
                 and o.find_armature() is rig), None)
    if arms is None:
        arms = next((o for o in objs if o.type == 'MESH' and o.find_armature() is rig), None)

    sc = bpy.context.scene
    hand_bones = ("hand.R", "hand.L")

    for clip, end in clip_len.items():
        solo(clip)
        speeds = {b: [] for b in hand_bones}
        prev = {}
        pen_frames = {}
        worst = {"depth_mm": 0.0}
        for f in range(0, end + 1):
            sc.frame_set(f)
            bpy.context.view_layer.update()
            dg = bpy.context.evaluated_depsgraph_get()
            rig_ev = rig.evaluated_get(dg)
            pos = {}
            for b in hand_bones:
                pb = rig_ev.pose.bones.get(b)
                if pb is None:
                    continue
                pos[b] = (rig_ev.matrix_world @ pb.matrix).translation.copy()
                if b in prev:
                    speeds[b].append((pos[b] - prev[b]).length * 1000.0)
            prev = pos

            # penetration: skinned arm verts near a hand, inside a gun mesh
            if arms is not None and gun_meshes and f % 2 == 0:
                ev = arms.evaluated_get(dg)
                me = ev.to_mesh()
                mw = ev.matrix_world
                cands = []
                for v in me.vertices:
                    wp = mw @ v.co
                    for b, hp in pos.items():
                        if (wp - hp).length < HAND_RADIUS:
                            cands.append(wp)
                            break
                boxes = []
                for gm in gun_meshes:
                    gev = gm.evaluated_get(dg)
                    pts = [gev.matrix_world @ Vector(c) for c in gev.bound_box]
                    lo = Vector((min(p[i] for p in pts) for i in range(3)))
                    hi = Vector((max(p[i] for p in pts) for i in range(3)))
                    boxes.append((gm, gev, lo, hi))
                deepest = 0.0
                for wp in cands:
                    for gm, gev, lo, hi in boxes:
                        if not all(lo[i] - 0.005 <= wp[i] <= hi[i] + 0.005 for i in range(3)):
                            continue
                        lp = gev.matrix_world.inverted() @ wp
                        ok, loc, nrm, _idx = gev.closest_point_on_mesh(lp)
                        if not ok:
                            continue
                        d = (lp - loc)
                        if d.dot(nrm) < 0:                      # inside the surface
                            depth = d.length * 1000.0
                            if depth > deepest:
                                deepest = depth
                                if depth > worst["depth_mm"]:
                                    worst = {"depth_mm": round(depth, 1), "frame": f,
                                             "gun_part": gm.name}
                ev.to_mesh_clear()
                if deepest > PENETRATION_MM:
                    pen_frames[f] = round(deepest, 1)

        pacing = {}
        for b, sp in speeds.items():
            if not sp:
                continue
            mx = max(sp)
            nz = [v for v in sp if v > 0.05]
            avg = sum(sp) / len(sp)
            spikes = []
            for i in range(1, len(sp)):
                a, c = sp[i - 1], sp[i]
                if max(a, c) > 20.0 and min(a, c) > 0.01 and max(a, c) / min(a, c) > SPEED_SPIKE_RATIO:
                    spikes.append({"frame": i, "mm_per_frame": [round(a, 1), round(c, 1)]})
            pacing[b] = {
                "max_mm_per_frame": round(mx, 1),
                "avg_mm_per_frame": round(avg, 2),
                "dead_frames": len(sp) - len(nz),
                "dead_pct": round(100.0 * (len(sp) - len(nz)) / len(sp), 1),
                "speed_spikes": spikes[:12],
                "spike_count": len(spikes),
                "teleports": [{"frame": i + 1, "mm": round(v, 1)}
                              for i, v in enumerate(sp) if v > 150.0][:6],
            }
        g["pacing"][clip] = pacing
        g["penetration"][clip] = {
            "frames_over_threshold": len(pen_frames),
            "sampled_frames": (end // 2) + 1,
            "worst": worst if worst["depth_mm"] else None,
            "frames": dict(list(pen_frames.items())[:20]),
        }

    # ---- 5. handle census on the rig's own actions ------------------------
    for t in rig.animation_data.nla_tracks:
        for s in t.strips:
            if s.action is None:
                continue
            census = {}
            keys = 0
            for fc in fcurves_of(s.action):
                for kp in fc.keyframe_points:
                    keys += 1
                    for h in (kp.handle_left_type, kp.handle_right_type):
                        census[h] = census.get(h, 0) + 1
            g["handles"][t.name] = {"action": s.action.name, "keys": keys, "handle_types": census}

    report[gun_key] = g

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w") as f:
    json.dump(report, f, indent=2)

# ---- console summary -----------------------------------------------------
for k, g in report.items():
    print(f"\n===== {k.upper()} =====")
    if "error" in g:
        print("  ERROR:", g["error"])
        continue
    print("  clip lengths:", g["clip_lengths"])
    print("  CONTRACT:", *(["OK"] if not g["contract"] else g["contract"]), sep="\n    ")
    if g["transforms"]:
        print("  TRANSFORMS:")
        for t in g["transforms"]:
            print(f"    {t['object']:34s} scale={t['scale']} nonuni={t['non_uniform']} "
                  f"rot={t['rotation_deg']} animated={t['animated']}")
    if g["pairing"]:
        print("  PAIRING:")
        for p in g["pairing"]:
            print("   ", p)
    print("  PACING (hand speed):")
    for clip, pac in g["pacing"].items():
        for b, d in pac.items():
            print(f"    {clip:14s} {b:7s} max={d['max_mm_per_frame']:6.1f}mm/f "
                  f"avg={d['avg_mm_per_frame']:5.2f} dead={d['dead_pct']:4.1f}% "
                  f"spikes={d['spike_count']} teleports={len(d['teleports'])}")
    print("  PENETRATION (arm verts inside gun):")
    for clip, p in g["penetration"].items():
        w = p["worst"]
        print(f"    {clip:14s} {p['frames_over_threshold']}/{p['sampled_frames']} sampled frames"
              + (f"  worst {w['depth_mm']}mm @f{w['frame']} in {w['gun_part']}" if w else ""))
    print("  HANDLES:")
    for clip, h in g["handles"].items():
        print(f"    {clip:14s} {h['keys']:5d} keys  {h['handle_types']}")
print(f"\nwrote {OUT}")
