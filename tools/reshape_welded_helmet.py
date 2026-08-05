"""reshape_welded_helmet.py - put the reshaped M1 on the bodies themselves.

    blender -b -P tools/reshape_welded_helmet.py -- [--apply]

`helmet_shell_worn` is the helmet the player actually sees: model_actor.gd:512-535
hides every gib donor, and it is not one, so it renders; grunt_dresser.gd:49-53 then
hides it and hangs a variant at ITS runtime AABB centre. So it is both the silhouette
and the anchor every detachable variant is placed by - and it had never been reshaped.

Three things this fixes:

  1. The shell is the old shallow pot. Swapped for the reshaped one.
  2. `matrix_world` carried Scale(1, 1.13, 1). grunt_dresser.gd:235 copies that basis
     onto every variant it hangs, so all 15 helmets render 13% deep front-to-back in
     game today. Scale goes to 1.0.
  3. In us_v3_soldier_lineup.blend the welded helmets sit off their own heads - 0.59 m
     on the rifleman, 3.7 m on the marksman - because they were placed by the soldier's
     rig offset rather than his head. Everything here is placed HEAD-RELATIVE, which
     fixes the lineup as a side effect. That file is what fix_grunt_sockets.py reads to
     build helmets.json.

Placement is the Summoner's, fitted by hand on the rifleman 2026-08-04, stored LEVEL -
per-man tilt is applied at spawn by grunt_dresser, so a squad does not wear one angle.

PILOTS ARE EXCLUDED: they wear the SPH-4, never an M1 (grunt_randomizer.gd:13-16,97).
"""
import bpy, os, sys, json
from mathutils import Vector, Matrix

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from bone_attach import attach, AttachError

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
APPLY = "--apply" in ARGV

VAR = r"C:\Users\caleb\RECONgame\assets\us\characters\helmet_variants_RESHAPED2.blend"
FILES = [r"C:\Users\caleb\RECONgame\assets\us\characters\us_base_v3.blend",
         r"C:\Users\caleb\RECONgame\assets\us\characters\us_v3_soldier_lineup.blend"]
OUT = r"C:\Users\caleb\AppData\Local\Temp\claude\C--Users-caleb\662bb9cb-765a-4f0f-b3bf-daee03d139b1\scratchpad"

# Summoner's fit, expressed relative to his own head's REST bbox centre.
# Raised 32.42 mm on 2026-08-04 - his call, "so they read better". He moved all nine
# together, spread 0.00000 m, so this is one number and not a per-man judgement.
HEAD_OFFSET = Vector((-0.00851, -0.00602, 0.06926))

# duplicate rigs carrying stale old-shape helmets - they render underneath the real
# soldiers and would abort export_us_squad.py, which rejects surviving .00N names
JUNK = ("helmet_shell_worn.002", "helmet_shell_worn.003")

# ...but the anchor we actually place against is the HEAD BONE, not the head mesh.
# In us_v3_soldier_lineup.blend the grunt_head_<tag> meshes are deformed by a different
# armature than the rig they hang on - grenadier's head evaluates 1.05 m from its own
# rig's head bone - so the mesh is not a usable anchor there. The bone always is: it is
# what the helmet is parented to. BONE_OFFSET is derived once, from the file where the
# head meshes ARE trustworthy, then reused everywhere.
BONE_OFFSET = None
REFERENCE_TAG = "rifleman"
BUGJUICE_EPS = 0.0005


def rng(vs):
    return (Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs))),
            Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs))))


def wv(o, dg):
    ev = o.evaluated_get(dg); me = ev.to_mesh()
    vs = [ev.matrix_world @ v.co for v in me.vertices]; ev.to_mesh_clear(); return vs


def tris(o):
    o.data.calc_loop_triangles()
    return len(o.data.loop_triangles)


# ------------------------------------------------------- 1. build the donor mesh once
bpy.ops.wm.open_mainfile(filepath=VAR)
cov, bnd = bpy.data.objects["m1_plain_cover"], bpy.data.objects["m1_plain_band"]
bpy.ops.object.select_all(action='DESELECT')
tmp_c = cov.copy(); tmp_c.data = cov.data.copy()
tmp_b = bnd.copy(); tmp_b.data = bnd.data.copy()
for o in (tmp_c, tmp_b):
    o.parent = None
    bpy.context.scene.collection.objects.link(o)
tmp_c.matrix_world = cov.matrix_world.copy()
tmp_b.matrix_world = bnd.matrix_world.copy()
bpy.context.view_layer.update()
for o in (tmp_c, tmp_b):
    o.select_set(True)
bpy.context.view_layer.objects.active = tmp_c
bpy.ops.object.join()
joined = bpy.context.view_layer.objects.active
# bake the world transform in, then centre the mesh on its own bbox
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
lo, hi = rng([v.co for v in joined.data.vertices])
ctr = (lo + hi) / 2
joined.data.transform(Matrix.Translation(-ctr))
joined.data.update()
# the mesh must keep a user or Blender purges it as orphan data on save - that is
# why the donor came back None the first time this ran
joined.name = "m1_welded_shell"
joined.data.name = "m1_welded_shell"
joined.data.use_fake_user = True
SHELL_TRIS = tris(joined)
lo, hi = rng([v.co for v in joined.data.vertices])
print("donor shell: %d tris  dims=(%.4f, %.4f, %.4f)  mats=%s  centred on its own bbox"
      % (SHELL_TRIS, hi.x - lo.x, hi.y - lo.y, hi.z - lo.z,
         [m.name for m in joined.data.materials]))

blend_donor = os.path.join(OUT, "welded_donor.blend")
bpy.ops.wm.save_as_mainfile(filepath=blend_donor)

report = {}
for path in FILES:
    label = os.path.basename(path)
    dst = path if APPLY else path.replace(".blend", "_RESHAPED.blend")
    bpy.ops.wm.open_mainfile(filepath=path)

    with bpy.data.libraries.load(blend_donor, link=False) as (df, dt):
        dt.meshes = ["m1_welded_shell"]
    donor = dt.meshes[0]

    for r in bpy.data.objects:
        if r.type == 'ARMATURE':
            r.data.pose_position = 'REST'
            if r.animation_data:
                r.animation_data.action = None
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()

    for jn in JUNK:
        j = bpy.data.objects.get(jn)
        if j is not None:
            print("  removing stale duplicate %s (on %s)"
                  % (jn, j.parent.name if j.parent else "<no rig>"))
            bpy.data.objects.remove(j, do_unlink=True)

    tags = sorted({o.name.replace("helmet_shell_worn", "").lstrip("_")
                   for o in bpy.data.objects if o.name.startswith("helmet_shell_worn")})
    print("\n===== %s : %d soldiers =====" % (label, len(tags)))

    # pre-pass: derive the bone-relative offset once, from the reference man in the
    # file whose head meshes are trustworthy. Tags iterate alphabetically, so this
    # cannot be folded into the main loop.
    if BONE_OFFSET is None:
        rshell = bpy.data.objects.get("helmet_shell_worn_" + REFERENCE_TAG)
        rhead = bpy.data.objects.get("grunt_head_" + REFERENCE_TAG)
        if rshell is None or rhead is None:
            raise SystemExit("cannot derive BONE_OFFSET: %s missing in %s" % (REFERENCE_TAG, label))
        rlo, rhi = rng(wv(rhead, dg))
        ranchor = rshell.parent.matrix_world @ rshell.parent.data.bones["mixamorig:Head"].head_local
        BONE_OFFSET = ((rlo + rhi) / 2 + HEAD_OFFSET) - ranchor
        print("  BONE_OFFSET derived off %s: %s"
              % (REFERENCE_TAG, tuple(round(v, 5) for v in BONE_OFFSET)))

    rows = {}
    for t in tags:
        suf = ("_" + t) if t else ""
        shell = bpy.data.objects.get("helmet_shell_worn" + suf)
        head = bpy.data.objects.get("grunt_head" + suf)
        if shell is None or head is None:
            print("  %-13s missing shell or head - skipped" % (t or "<base>"))
            continue
        if "pilot" in t:
            print("  %-13s pilot - SKIPPED (SPH-4, never an M1)" % t)
            continue
        rig = shell.parent
        old_lo, old_hi = rng(wv(shell, dg))
        hlo, hhi = rng(wv(head, dg))
        head_ctr = (hlo + hhi) / 2
        anchor = rig.matrix_world @ rig.data.bones["mixamorig:Head"].head_local
        target = anchor + BONE_OFFSET
        # how far this man's head MESH disagrees with his own head BONE - large values
        # are the lineup's mis-bound heads, not a placement error
        drift = (target - (head_ctr + HEAD_OFFSET)).length
        M = Matrix.Translation(target)          # DONOR is centred on its own bbox

        for name in ("helmet_shell_worn" + suf, "helmet_camo_shell" + suf):
            o = bpy.data.objects.get(name)
            if o is None:
                continue
            o.data = donor.copy()               # carries its own MitchellCamo + Webbing
            o.data.name = name
            o.scale = (1.0, 1.0, 1.0)           # kills the 1.13 that grunt_dresser copies
            o.rotation_euler = (0.0, 0.0, 0.0)
            attach(o, rig, "mixamorig:Head", world=M)
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()

        # bug-juice bottle: re-seat against the new shell
        bj = bpy.data.objects.get("helmet_bugjuice" + suf)
        bj_moved = 0.0
        if bj is not None:
            Mi = shell.matrix_world.inverted()
            for _ in range(4):
                best, bn = 1e9, Vector((0, 0, 1))
                for v in bj.data.vertices:
                    lp = Mi @ (bj.matrix_world @ v.co)
                    ok, loc, nor, _ = shell.closest_point_on_mesh(lp)
                    if ok:
                        d = (lp - loc).dot(nor)
                        if d < best:
                            best, bn = d, nor.copy()
                n = (shell.matrix_world.to_3x3() @ bn).normalized()
                step = n * (BUGJUICE_EPS - best)
                bj.matrix_world = Matrix.Translation(step) @ bj.matrix_world
                bj_moved += step.length
                bpy.context.view_layer.update()

        new_lo, new_hi = rng(wv(shell, dg))
        # ADR-002 height box: us_grunt_joined + every mesh ending _worn
        body = bpy.data.objects.get("us_grunt_joined" + suf)
        h = None
        if body is not None:
            parts = [body] + [o for o in bpy.data.objects
                              if o.type == 'MESH' and o.name.endswith("_worn" + suf if suf else "_worn")
                              and not any(k in o.name.lower() for k in ("radio", "antenna", "prc25", "handset"))]
            pts = []
            for p in parts:
                pts += wv(p, dg)
            blo, bhi = rng(pts)
            h = bhi.z - blo.z
        rows[t or "<base>"] = {
            "crown": [round(old_hi.z, 5), round(new_hi.z, 5)],
            "crown_delta": round(new_hi.z - old_hi.z, 5),
            "centre": [round(v, 5) for v in ((new_lo + new_hi) / 2)],
            "target": [round(v, 5) for v in target],
            "head_ctr": [round(v, 5) for v in head_ctr],
            "head_mesh_drift": round(drift, 5),
            "height_box": round(h, 5) if h else None,
            "scale_factor": round(1.7132 / h, 6) if h else None,
            "bugjuice_moved_mm": round(bj_moved * 1000, 2),
        }
        print("  %-13s crown %.4f -> %.4f (%+.4f)  h=%s  s=%s  bj %+.1f mm"
              % (t or "<base>", old_hi.z, new_hi.z, new_hi.z - old_hi.z,
                 ("%.4f" % h) if h else "n/a",
                 ("%.6f" % (1.7132 / h)) if h else "n/a", bj_moved * 1000))

    report[label] = rows
    bpy.ops.wm.save_as_mainfile(filepath=dst)
    print("  wrote %s" % dst)

with open(os.path.join(OUT, "welded_report.json"), "w") as f:
    json.dump(report, f, indent=1)

print("\n=== GATES ===")
fail = []
for label, rows in report.items():
    for t, r in rows.items():
        if abs(r["crown_delta"]) > 0.010:
            fail.append("%s/%s crown moved %+.4f m (limit 10 mm)" % (label, t, r["crown_delta"]))
        if r["scale_factor"] and not (0.930 <= r["scale_factor"] <= 0.945):
            fail.append("%s/%s normalizer s=%.6f outside [0.930, 0.945]" % (label, t, r["scale_factor"]))
        off = Vector(r["centre"]) - Vector(r["target"])
        if off.length > 1e-3:
            fail.append("%s/%s placement off by %.5f m" % (label, t, off.length))
        if r["head_mesh_drift"] > 0.02:
            print("    note: %s/%s head MESH sits %.3f m from its own head BONE "
                  "(pre-existing mis-bind, placement anchored on the bone)"
                  % (label, t, r["head_mesh_drift"]))
print("  shell tris: %d (was ~300)" % SHELL_TRIS)
if fail:
    print("  FAILURES:")
    for f2 in fail:
        print("    - " + f2)
else:
    print("  all gates pass")
