"""reseat_helmet_props.py - put the sockets and the props back where they belong.

    blender -b -P tools/reseat_helmet_props.py -- [--apply]

reshape_helmet_shell.py grew the shells; three things did not follow:

  1. `<variant>_socket_head` stayed put. It must sit at the cover-union-band bbox
     centre, because export_helmets.py:59-62 zeroes each helmet on the socket and
     grunt_dresser.gd:233-235 drops the GLB origin on the stock helmet's runtime
     AABB centre. Socket-off-centre = every variant hangs low in game.
  2. The props were re-seated by a radial ray from the vertical axis, which misses
     entirely when a prop starts far off the shell - m1_veteran's bug-juice bottle
     was left 156 mm out (it was already adrift in the source file).
  3. The foliage sprig bases ended up buried in the shell surface. Two near-coplanar
     surfaces Z-fight, which reads in game as jitter under camera motion.

Props are seated by nearest-surface solve instead, with a standoff: flat cards need
a real gap to stay out of the depth fight, solids only need to touch.

m1_rounds' rounds were never a prop - they are a scattered 5-round cloud spanning
0.418 x 0.406 m against a 0.229 m helmet. Rebuilt from the reference's own rounds,
which are already tucked in its band, so registering them to the shell seats them.
"""
import bpy, bmesh, math, os, sys, json
from mathutils import Vector

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
APPLY = "--apply" in ARGV

SRC = r"C:\Users\caleb\RECONgame\assets\us\characters\helmet_variants_RESHAPED.blend"
REF = r"C:\Users\caleb\AppData\Local\Temp\claude\C--Users-caleb\662bb9cb-765a-4f0f-b3bf-daee03d139b1\scratchpad\helmet_ref\source\m1Helmet\m1Helmet.obj"
DST = r"C:\Users\caleb\RECONgame\assets\us\characters\helmet_variants.blend" if APPLY else \
      r"C:\Users\caleb\RECONgame\assets\us\characters\helmet_variants_RESHAPED2.blend"
OUT = r"C:\Users\caleb\AppData\Local\Temp\claude\C--Users-caleb\662bb9cb-765a-4f0f-b3bf-daee03d139b1\scratchpad"

# standoff from the shell surface, metres
EPS_FLAT = 0.002     # foliage, playing cards - near-coplanar, must clear the depth fight
EPS_SOLID = 0.0005   # bottles, packs, rounds, gum - solids, tangency reads fine
FLAT = ("foliage", "card_ace")
ATTACH = ("cigpack", "bugjuice", "card_ace", "rounds", "foliage", "gum")
FLOAT_LIMIT = 0.010  # nothing may sit more than 10 mm off the shell
ROUND_TRIS = 24      # per round, after decimation


def rng(vs):
    return (Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs))),
            Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs))))


def wverts(o):
    return [o.matrix_world @ v.co for v in o.data.vertices]


def tris(o):
    o.data.calc_loop_triangles()
    return len(o.data.loop_triangles)


def act(o):
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o


def signed_field(prop, shell):
    """(min signed distance, outward normal at the deepest vertex). -ve = inside."""
    Mi = shell.matrix_world.inverted()
    best, bn = 1e9, Vector((0, 0, 1))
    for v in prop.data.vertices:
        lp = Mi @ (prop.matrix_world @ v.co)
        ok, loc, nor, _ = shell.closest_point_on_mesh(lp)
        if not ok:
            continue
        d = (lp - loc).dot(nor)
        if d < best:
            best, bn = d, nor.copy()
    return best, (shell.matrix_world.to_3x3() @ bn).normalized()


def seat(prop, shell, eps, passes=4):
    """Translate prop along the surface normal until its deepest vertex sits eps proud."""
    for _ in range(passes):
        d, n = signed_field(prop, shell)
        if abs(d - eps) < 1e-5:
            break
        prop.location = prop.location + n * (eps - d)
        bpy.context.view_layer.update()
    return signed_field(prop, shell)[0]


bpy.ops.wm.open_mainfile(filepath=SRC)
sc = bpy.context.scene
root = bpy.data.collections["HELMETS"]
variants = sorted(c.name for c in root.children)

# ---------------------------------------------------------------- reference rounds
before = set(bpy.data.objects)
bpy.ops.wm.obj_import(filepath=REF)
imp = [o for o in bpy.data.objects if o not in before][0]
act(imp)
bpy.ops.mesh.separate(type='MATERIAL')
# the shell material re-imports as blinn1SG.001 etc - the reshape left the first
# copy in this blend - so match on the stem, never the exact name
def is_shell_mat(o):
    return bool(o.data.materials) and o.data.materials[0].name.startswith('blinn1SG')

g = [o for o in bpy.data.objects if o not in before and is_shell_mat(o)]
act(g[0])
bpy.ops.mesh.separate(type='LOOSE')
sp = sorted([o for o in bpy.data.objects if o not in before and is_shell_mat(o)],
            key=lambda o: -len(o.data.vertices))
REF_SHELL = sp[0]
REF_ROUNDS = [o for o in sp[2:] if 130 <= len(o.data.vertices) <= 150]   # the five 138-vert cases
for o in [x for x in bpy.data.objects
          if x not in before and x not in [REF_SHELL] + REF_ROUNDS]:
    bpy.data.objects.remove(o, do_unlink=True)
print("reference: shell %d tris, %d rounds" % (tris(REF_SHELL), len(REF_ROUNDS)))

S = 0.030044   # the uniform scale reshape_helmet_shell.py locked to the shell width
for o in [REF_SHELL] + REF_ROUNDS:
    o.scale = (S, S, S)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
for o in [REF_SHELL] + REF_ROUNDS:
    o.select_set(True)
bpy.context.view_layer.objects.active = REF_SHELL
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

for o in REF_ROUNDS:
    act(o)
    m = o.modifiers.new("dec", 'DECIMATE')
    m.decimate_type = 'COLLAPSE'
    m.ratio = min(1.0, ROUND_TRIS / float(tris(o)))
    bpy.ops.object.modifier_apply(modifier="dec")
print("rounds decimated to %d tris total" % sum(tris(o) for o in REF_ROUNDS))

report = {}
for name in variants:
    col = bpy.data.collections[name]
    meshes = {o.name.replace(name + "_", ""): o for o in col.objects if o.type == 'MESH'}
    cover, band = meshes.get("cover"), meshes.get("band")
    sock = bpy.data.objects.get(name + "_socket_head")
    if cover is None or band is None or sock is None:
        print("  %-18s incomplete - skipped" % name)
        continue

    # ---- 1. socket onto the cover-union-band bbox centre ----
    pts = wverts(cover) + wverts(band)
    lo, hi = rng(pts)
    centre = (lo + hi) / 2
    moved = centre - sock.matrix_world.translation
    kids = [o for o in bpy.data.objects if o.parent is sock]
    world_keep = {o.name: o.matrix_world.copy() for o in kids}
    sock.location = sock.location + moved
    bpy.context.view_layer.update()
    for o in kids:                      # origin moves, geometry must not
        o.matrix_world = world_keep[o.name]
    bpy.context.view_layer.update()
    resid = (sock.matrix_world.translation - centre).length

    # ---- 2. rebuild m1_rounds' cloud from the reference's own rounds ----
    if name == "m1_rounds" and "rounds" in meshes:
        old = meshes["rounds"]
        rlo, rhi = rng(wverts(REF_SHELL))
        clo, chi = rng(wverts(cover))
        off = (clo + chi) / 2 - (rlo + rhi) / 2      # ref shell -> this variant's shell
        copies = []
        for i, r in enumerate(REF_ROUNDS):
            c = r.copy(); c.data = r.data.copy()
            sc.collection.objects.link(c)
            c.location = r.location + off
            copies.append(c)
        bpy.context.view_layer.update()
        bpy.ops.object.select_all(action='DESELECT')
        for c in copies:
            c.select_set(True)
        bpy.context.view_layer.objects.active = copies[0]
        bpy.ops.object.join()
        joined = bpy.context.view_layer.objects.active
        me = joined.data
        M = old.matrix_world.inverted() @ joined.matrix_world
        me.transform(M)
        me.update()
        me.materials.clear()
        for m in old.data.materials:
            me.materials.append(m)
        for p in me.polygons:
            p.use_smooth = any(q.use_smooth for q in old.data.polygons)
        old.data = me
        old.data.name = old.name
        bpy.data.objects.remove(joined, do_unlink=True)
        print("  m1_rounds       rounds rebuilt from reference -> %d tris" % tris(old))

    # ---- 3. seat every prop against the shell ----
    seated = []
    for tag, o in sorted(meshes.items()):
        if not any(k in tag for k in ATTACH):
            continue
        eps = EPS_FLAT if any(f in tag for f in FLAT) else EPS_SOLID
        d0, _ = signed_field(o, cover)
        d1 = seat(o, cover, eps)
        seated.append((tag, d0, d1))

    total = sum(tris(o) for o in col.objects if o.type == 'MESH')
    report[name] = {
        "socket_moved_mm": round(moved.length * 1000, 3),
        "socket_residual_mm": round(resid * 1000, 6),
        "total_tris": total,
        "props": [(t, round(a, 5), round(b, 5)) for t, a, b in seated],
    }
    print("  %-18s socket %+.1f mm (resid %.4f mm)  tris=%d  props=%s"
          % (name, moved.length * 1000, resid * 1000, total,
             ["%s %.4f->%.4f" % (t, a, b) for t, a, b in seated]))

for o in [REF_SHELL] + REF_ROUNDS:
    bpy.data.objects.remove(o, do_unlink=True)

# ---------------------------------------------------------------- gates
print("\n=== GATES ===")
fail = []
for name, r in report.items():
    if r["socket_residual_mm"] > 1e-3:
        fail.append("%s socket off centre by %.4f mm" % (name, r["socket_residual_mm"]))
    if r["total_tris"] > 900:
        fail.append("%s over tri budget (%d)" % (name, r["total_tris"]))
    for tag, d0, d1 in r["props"]:
        if d1 <= 0.0:
            fail.append("%s/%s still intersects the shell (%.5f)" % (name, tag, d1))
        elif d1 > FLOAT_LIMIT:
            fail.append("%s/%s floats %.1f mm off the shell" % (name, tag, d1 * 1000))
print("  sockets on centre : max residual %.6f mm" % max(r["socket_residual_mm"] for r in report.values()))
print("  tri budget        : max total %d (limit 900)" % max(r["total_tris"] for r in report.values()))
allp = [(n, t, d1) for n, r in report.items() for t, d0, d1 in r["props"]]
if allp:
    print("  prop seating      : %d props, nearest %+.5f, furthest %+.5f"
          % (len(allp), min(d for _, _, d in allp), max(d for _, _, d in allp)))
if fail:
    print("  FAILURES:")
    for f in fail:
        print("    - " + f)
else:
    print("  all gates pass")

with open(os.path.join(OUT, "reseat_report.json"), "w") as f:
    json.dump(report, f, indent=1)
bpy.ops.wm.save_as_mainfile(filepath=DST)
print("\nwrote %s" % DST)
