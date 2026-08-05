"""reshape_helmet_shell.py - rebuild the 15 M1 shells from the high-quality reference.

    blender -b -P tools/reshape_helmet_shell.py -- [--apply] [--out <blend>]

Shell and band geometry come from the reference OBJ (decimated to budget); UVs are
transferred from the shell each variant already had, so assets/us/textures/helmets/
helm_<id>.png and the graffiti/card atlas keep mapping without a rebuild.

Registration is UNIFORM scale anchored on the existing shell WIDTH (the head fit that
already works), positioned by the BAND, so the rim stays where it sat and the extra
depth goes upward into the crown - the shells were too shallow to cover the skull.

`<variant>_socket_head` is never moved: export_helmets.py zeroes each helmet on it and
Godot applies the stored mixamorig:Head matrix from helmets.json.

Without --apply the result is written beside the source as *_RESHAPED.blend.
"""
import bpy, bmesh, math, os, sys, json
from mathutils import Vector

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
APPLY = "--apply" in ARGV

SRC = r"C:\Users\caleb\RECONgame\assets\us\characters\helmet_variants.blend"
REF = r"C:\Users\caleb\AppData\Local\Temp\claude\C--Users-caleb\662bb9cb-765a-4f0f-b3bf-daee03d139b1\scratchpad\helmet_ref\source\m1Helmet\m1Helmet.obj"
OUT_BLEND = SRC if APPLY else SRC.replace(".blend", "_RESHAPED.blend")
RENDER_DIR = r"C:\Users\caleb\AppData\Local\Temp\claude\C--Users-caleb\662bb9cb-765a-4f0f-b3bf-daee03d139b1\scratchpad"

SHELL_TRIS = 520
BAND_TRIS = 140
ATTACH = ("cigpack", "bugjuice", "card_ace", "rounds", "foliage", "gum")


def rng(vs):
    return (Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs))),
            Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs))))


def bbo(o):
    return rng([o.matrix_world @ v.co for v in o.data.vertices])


def tris(o):
    o.data.calc_loop_triangles()
    return len(o.data.loop_triangles)


def act(o):
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o


# ------------------------------------------------------------------ load
bpy.ops.wm.open_mainfile(filepath=SRC)
sc = bpy.context.scene
root = bpy.data.collections["HELMETS"]
variants = sorted(c.name for c in root.children)
print("=== %d variants ===" % len(variants))

before = set(bpy.data.objects)
bpy.ops.wm.obj_import(filepath=REF)
imp = [o for o in bpy.data.objects if o not in before][0]
act(imp)
bpy.ops.mesh.separate(type='MATERIAL')
grp = [o for o in bpy.data.objects if o not in before and o.data.materials[0].name == 'blinn1SG']
act(grp[0])
bpy.ops.mesh.separate(type='LOOSE')
sp = sorted([o for o in bpy.data.objects if o not in before and o.data.materials[0].name == 'blinn1SG'],
            key=lambda o: -len(o.data.vertices))
REF_SHELL, REF_BAND = sp[0], sp[1]
# everything else from the import (the 5 rounds, the clip, both chinstraps) is reference
# clutter - our variants carry their own rounds mesh
for o in sp[2:] + [o for o in bpy.data.objects
                   if o not in before and o.data.materials[0].name == 'blinn2SG']:
    bpy.data.objects.remove(o, do_unlink=True)
REF_SHELL.name, REF_BAND.name = "REF_shell", "REF_band"
print("  reference: shell %d tris, band %d tris" % (tris(REF_SHELL), tris(REF_BAND)))

# ------------------------------------------------- scale, once, off m1_plain
proto_cover = bpy.data.objects["m1_plain_cover"]
pclo, pchi = bbo(proto_cover)
rlo, rhi = bbo(REF_SHELL)
S = (pchi.x - pclo.x) / (rhi.x - rlo.x)
for o in (REF_SHELL, REF_BAND):
    o.scale = (S, S, S)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
for o in (REF_SHELL, REF_BAND):
    o.select_set(True)
bpy.context.view_layer.objects.active = REF_SHELL
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
print("  uniform scale = %.6f" % S)

for o, budget in ((REF_SHELL, SHELL_TRIS), (REF_BAND, BAND_TRIS)):
    act(o)
    m = o.modifiers.new("dec", 'DECIMATE')
    m.decimate_type = 'COLLAPSE'
    m.ratio = min(1.0, budget / float(tris(o)))
    bpy.ops.object.modifier_apply(modifier="dec")
print("  decimated: shell %d tris, band %d tris" % (tris(REF_SHELL), tris(REF_BAND)))


def transferred_mesh(ref_obj, donor, offset):
    """Copy of ref_obj's mesh, moved by `offset`, carrying donor's UVs + material,
    returned in donor's LOCAL space so it can be dropped straight onto donor."""
    tmp = ref_obj.copy()
    tmp.data = ref_obj.data.copy()
    sc.collection.objects.link(tmp)
    tmp.location = ref_obj.location + offset
    bpy.context.view_layer.update()
    act(tmp)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)

    if not tmp.data.uv_layers:
        tmp.data.uv_layers.new(name="UVMap")
    tmp.data.uv_layers[0].name = "UVMap"
    dt = tmp.modifiers.new("dt", 'DATA_TRANSFER')
    dt.object = donor
    dt.use_loop_data = True
    dt.data_types_loops = {'UV'}
    dt.loop_mapping = 'POLYINTERP_NEAREST'
    act(tmp)
    bpy.ops.object.modifier_apply(modifier="dt")

    tmp.data.materials.clear()
    for m in donor.data.materials:
        tmp.data.materials.append(m)
    smooth = any(p.use_smooth for p in donor.data.polygons)
    for p in tmp.data.polygons:
        p.use_smooth = smooth

    # into donor's local space
    M = donor.matrix_world.inverted() @ tmp.matrix_world
    me = tmp.data
    me.transform(M)
    me.update()
    tmp.data = bpy.data.meshes.new("scratch")
    bpy.data.objects.remove(tmp, do_unlink=True)
    return me


def surface_hit(obj, origin_w, dir_w):
    """Ray-cast in OBJECT space (obj.ray_cast wants local), return world hit or None."""
    Mi = obj.matrix_world.inverted()
    o_l = Mi @ origin_w
    d_l = (Mi.to_3x3() @ dir_w).normalized()
    ok, loc, _, _ = obj.ray_cast(o_l, d_l)
    return (obj.matrix_world @ loc) if ok else None


report = {}
for name in variants:
    col = bpy.data.collections[name]
    meshes = {o.name.replace(name + "_", ""): o for o in col.objects if o.type == 'MESH'}
    cover = meshes.get("cover")
    band = meshes.get("band")
    sock = bpy.data.objects.get(name + "_socket_head")
    if cover is None or band is None:
        print("  %-18s missing cover/band - skipped" % name)
        continue
    sock_before = sock.matrix_world.translation.copy() if sock else None

    clo, chi = bbo(cover)
    blo, bhi = bbo(band)
    rblo, rbhi = bbo(REF_BAND)
    off = Vector(((clo.x + chi.x) / 2 - (rblo.x + rbhi.x) / 2,
                  (blo.y + bhi.y) / 2 - (rblo.y + rbhi.y) / 2,
                  (blo.z + bhi.z) / 2 - (rblo.z + rbhi.z) / 2))

    # keep a copy of the old cover to re-seat attachments against
    old = cover.copy()
    old.data = cover.data.copy()
    sc.collection.objects.link(old)
    old.name = name + "_OLDREF"

    new_cover = transferred_mesh(REF_SHELL, cover, off)
    new_band = transferred_mesh(REF_BAND, band, off)
    old_cover_tris, old_band_tris = tris(cover), tris(band)
    cover.data = new_cover
    band.data = new_band
    cover.data.name = cover.name
    band.data.name = band.name

    nlo, nhi = bbo(cover)
    axis = Vector(((nlo.x + nhi.x) / 2, (nlo.y + nhi.y) / 2, 0.0))

    # ---- re-seat the attachments onto the new surface ----
    moved = []
    for key, o in meshes.items():
        if not any(k in key for k in ATTACH):
            continue
        vs = [o.matrix_world @ v.co for v in o.data.vertices]
        c = sum(vs, Vector()) / len(vs)
        radial = Vector((c.x - axis.x, c.y - axis.y, 0.0))
        if radial.length < 1e-6:
            continue
        radial.normalize()
        start = Vector((axis.x, axis.y, c.z))
        h_old = surface_hit(old, start, radial)
        h_new = surface_hit(cover, start, radial)
        if h_old is None or h_new is None:
            print("     %-14s ray missed (old=%s new=%s) - left in place"
                  % (key, h_old is not None, h_new is not None))
            continue
        d = h_new - h_old
        o.location = o.location + d
        moved.append((key, d.length))
    bpy.context.view_layer.update()

    bpy.data.objects.remove(old, do_unlink=True)

    if sock:
        drift = (sock.matrix_world.translation - sock_before).length
        if drift > 1e-6:
            raise SystemExit("SOCKET MOVED on %s by %.6f - aborting" % (name, drift))

    total = sum(tris(o) for o in col.objects if o.type == 'MESH')
    report[name] = {
        "cover_tris": [old_cover_tris, tris(cover)],
        "band_tris": [old_band_tris, tris(band)],
        "total_tris": total,
        "dims": [round(nhi[i] - nlo[i], 4) for i in range(3)],
        "crown_delta": round(nhi.z - chi.z, 4),
        "rim_delta": round(nlo.z - clo.z, 4),
        "reseated": [(k, round(d, 4)) for k, d in moved],
    }
    print("  %-18s cover %d->%d  band %d->%d  total=%d  dims=(%.3f, %.3f, %.3f)  crown %+.4f rim %+.4f  reseated=%s"
          % (name, old_cover_tris, tris(cover), old_band_tris, tris(band), total,
             nhi.x - nlo.x, nhi.y - nlo.y, nhi.z - nlo.z, nhi.z - chi.z, nlo.z - clo.z,
             [k for k, _ in moved]))

for o in (REF_SHELL, REF_BAND):
    bpy.data.objects.remove(o, do_unlink=True)

# ------------------------------------------------------------------ gates
print("\n=== GATES ===")
fail = []
for name, r in report.items():
    col = bpy.data.collections[name]
    if r["total_tris"] > 900:
        fail.append("%s over tri budget (%d)" % (name, r["total_tris"]))
    for o in col.objects:
        if o.type != 'MESH':
            continue
        if not o.name.startswith(name + "_"):
            fail.append("%s: %s cannot be renamed to helmet_*" % (name, o.name))
        uv = o.data.uv_layers.get("UVMap")
        if uv is None:
            fail.append("%s: %s lost its UVMap" % (name, o.name))
            continue
        bad = sum(1 for l in uv.data if not (math.isfinite(l.uv.x) and math.isfinite(l.uv.y)))
        if bad:
            fail.append("%s: %s has %d non-finite UVs" % (name, o.name, bad))
print("  tri budget  : max total = %d (limit 900)" % max(r["total_tris"] for r in report.values()))
print("  crown rise  : %+.4f m on every variant" % report["m1_plain"]["crown_delta"])
print("  rim drift   : %+.4f m" % report["m1_plain"]["rim_delta"])
print("  sockets     : unmoved (asserted per variant)")
if fail:
    print("  FAILURES:")
    for f in fail:
        print("    - " + f)
else:
    print("  all gates pass")

with open(os.path.join(RENDER_DIR, "reshape_report.json"), "w") as f:
    json.dump(report, f, indent=1)

bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
print("\nwrote %s" % OUT_BLEND)
