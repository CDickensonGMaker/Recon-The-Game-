"""dress_cow_gus_necklace.py - Gus "ears" wears the necklace kit; the cast heads get the neck fix.

    "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" --background ^
        "assets/us/characters/conquest_of_worms_us_cast.blend" --python tools/dress_cow_gus_necklace.py ^
        -- [--dry] [--ears-only] [--stages=old,dried,old,days,fresh]

--stages   one kit ear stage per slot 06..10 (fresh|days|rotten|dried|old). Default is the
           2026-09-12 mix: his string is a few weeks old, the fresh one is the newest and
           hangs at the end. The kit's `charm_ear` (= days) is used when a stage is not named.
--ears-only  skip the blob removal and the neck fix; re-hang the cord and the five ears only
           (the 2026-09-12 re-dress, the cast file having just been edited elsewhere). The cord
           is re-appended too so cord and ears share ONE necklace_kit_mat / 512 sheet.

Runs AFTER tools/build_cow_cast.py and BEFORE tools/export_cow_cast.py. Re-runnable: it
removes what it previously hung before hanging it again. Saves the cast file in place, no
.blend1 (Caleb's law).

1. Removes `necklace_ears_gus_ears` - the seven flat ear cards on a 12-segment loop that
   build_cow_cast.py 4b used to weld under the suspenders (348 v / 174 p / 516 tris, bone-
   parented to Spine2, z 1.254-1.474). Those are the "pink blobs". It is identified by its
   geometry and materials, not by name alone, and the numbers are printed before it goes.
2. Applies tools/fix_cow_neck_uvs.py to all three cast heads.
3. Appends `necklace_cord` + the named `charm_ear_<stage>` objects from necklace_kit.blend,
   hangs the cord on PSXRig_gus_ears (skinned: Neck, front drape up to 35% Spine2) and five
   ears on slots 06-10 (Caleb: five, centred on the fifteen), each ear skinned with its slot's
   blend so it rides the cord, never separates from it. Shipped names stay charm_ear_06..10;
   the stage is on the object as `ear_stage`.
"""
import bpy
import os
import sys
import json
import math
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fix_cow_neck_uvs

D = bpy.data
ROOT = r"C:\Users\caleb\RECONgame"
CHAR = os.path.join(ROOT, "assets", "us", "characters")
CAST = os.path.join(CHAR, "conquest_of_worms_us_cast.blend")
KIT = os.path.join(CHAR, "necklace_kit.blend")
TAG = "gus_ears"
RIG = "PSXRig_" + TAG
GUS_SLOTS = ["necklace_slot_%02d" % i for i in range(6, 11)]
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
DRY = "--dry" in argv
EARS_ONLY = "--ears-only" in argv
STAGES = next((a.split("=", 1)[1] for a in argv if a.startswith("--stages=")), "old,dried,old,days,fresh").split(",")
assert len(STAGES) == len(GUS_SLOTS) and all(st in ("fresh", "days", "rotten", "dried", "old") for st in STAGES), STAGES

assert os.path.abspath(D.filepath) == os.path.abspath(CAST) or DRY or "--scratch" in argv, "run this ON the cast file"
bpy.context.preferences.filepaths.save_version = 0
SC = bpy.context.scene


def log(*a):
    print(*a, flush=True)


def save(step):
    if DRY:
        log("   (dry) would save after: %s" % step)
        return
    # the kit's PSXRig rides along as a dependency of the cord's armature modifier and
    # leaves an orphan armature datablock behind once the object is dropped - purge it
    for a in list(D.armatures):
        if a.users == 0:
            D.armatures.remove(a)
    bpy.ops.wm.save_mainfile(filepath=D.filepath, compress=True)   # as build_cow_cast saves it
    log("   SAVED after: %s" % step)


rig = D.objects[RIG]
assert rig.type == 'ARMATURE' and len(rig.data.bones) == 41
assert abs(math.degrees(rig.rotation_euler.x) - 90.0) < 1e-3, "rig must stay upright as appended"
assert rig.scale.length_squared > 2.99

# ---------------------------------------------------------------------------
# 1. the blobs
# ---------------------------------------------------------------------------
old = None if EARS_ONLY else D.objects.get("necklace_ears_" + TAG)
if old is not None:
    me = old.data
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    mats = [m.name for m in me.materials]
    bb = [old.matrix_world @ Vector(c) for c in old.bound_box]
    log("REMOVING %s: %d v / %d p / %d tris, materials %s, parent %s/%s, world z[%.3f,%.3f]"
        % (old.name, len(me.vertices), len(me.polygons), tris, mats, old.parent_type, old.parent_bone,
           min(v.z for v in bb), max(v.z for v in bb)))
    # confirm it is the old cord+ear-card build: 7 ears x (2x15 outline + 6 concha) + 12x8 cord
    assert set(mats) == {"necklace_cord", "ear_flesh", "ear_inner"} and len(me.vertices) == 348, \
        "not the object I expected - stopping rather than deleting the wrong thing"
    D.objects.remove(old, do_unlink=True)
    if me.users == 0:
        D.meshes.remove(me)
    for mn in ("ear_flesh", "ear_inner"):
        m = D.materials.get(mn)
        if m and m.users == 0:
            D.materials.remove(m)
elif not EARS_ONLY:
    log("necklace_ears_%s already gone" % TAG)
# a previous run of this script
for o in list(D.objects):
    if o.name.startswith("necklace_cord_" + TAG) or (o.name.startswith("charm_ear_") and o.name.endswith("_" + TAG)):
        log("   removing previous %s (%s, %d v)" % (o.name, o.data.name, len(o.data.vertices)))
        D.objects.remove(o, do_unlink=True)
for blk in (D.meshes, D.materials, D.images):
    for x in list(blk):
        if x.users == 0 and (x.name.startswith("necklace_") or x.name.startswith("charm_")):
            blk.remove(x)
if not EARS_ONLY:
    save("blobs removed")

    # -----------------------------------------------------------------------
    # 2. neck / jaw fix on every cast head
    # -----------------------------------------------------------------------
    fix_cow_neck_uvs.run()
    save("neck UVs")

# ---------------------------------------------------------------------------
# 3. the cord and five ears
# ---------------------------------------------------------------------------
ear_names = sorted(set("charm_ear_" + st for st in STAGES))
with D.libraries.load(KIT, link=False) as (src, dst):
    dst.objects = ["necklace_cord"] + ear_names
cord_src = dst.objects[0]
table = json.loads(cord_src["necklace_slots"])
ear_srcs = {o.name: o for o in dst.objects if o.name.startswith("charm_ear_")}
assert len(table) == 15, "kit slot table has %d slots" % len(table)

# the kit's verts are in rig-at-origin world space (Z up); the cast rig OBJECT sits at x=6
# with the 90 deg X rotation every PSXRig carries, so the parent inverse cancels the
# rotation and lets the rig's translation place the prop (psx-npc-pipeline: place by
# moving the ARMATURE, never bake position into vertices)
P_INV = Matrix.Rotation(math.radians(-90.0), 4, 'X')
rig_T = Matrix.Translation(rig.matrix_world.translation)
assert (rig.matrix_world - rig_T @ P_INV.inverted()).to_3x3().determinant() < 1e-9

cord = D.objects.new("necklace_cord_" + TAG, cord_src.data)
cord.data.name = "necklace_cord_" + TAG
SC.collection.objects.link(cord)
cord.parent = rig
cord.parent_type = 'OBJECT'
cord.matrix_parent_inverse = P_INV
cord.matrix_basis = Matrix.Identity(4)
mod = cord.modifiers.new("Armature", 'ARMATURE')
mod.object = rig
for vg in cord.vertex_groups:
    assert vg.name in rig.data.bones, "cord vertex group %s has no bone" % vg.name
del cord_src["necklace_slots"]
D.objects.remove(cord_src, do_unlink=True)

ears = []
for sn, stage in zip(GUS_SLOTS, STAGES):
    M = Matrix([Vector(r) for r in table[sn]["rest_world"]])
    w = table[sn]["weights"]
    me = ear_srcs["charm_ear_" + stage].data.copy()
    nm = "charm_ear_%s_%s" % (sn.split("_")[-1], TAG)
    me.name = nm
    o = D.objects.new(nm, me)
    o["ear_stage"] = stage
    SC.collection.objects.link(o)
    o.parent = rig
    o.parent_type = 'OBJECT'
    o.matrix_parent_inverse = P_INV
    o.matrix_basis = M
    for bone, wt in w.items():
        vg = o.vertex_groups.new(name=bone)
        vg.add(list(range(len(me.vertices))), wt, 'REPLACE')
    m2 = o.modifiers.new("Armature", 'ARMATURE')
    m2.object = rig
    ears.append(o)
for o in ear_srcs.values():
    D.objects.remove(o, do_unlink=True)
for nm in ear_names:
    if (m := D.meshes.get(nm)) and m.users == 0:
        D.meshes.remove(m)
bpy.context.view_layer.update()
log("EARS on slots 06-10: %s" % ", ".join("%s=%s" % (sn[-2:], st) for sn, st in zip(GUS_SLOTS, STAGES)))

# ---------------------------------------------------------------------------
# 4. measure it on Gus: cord and ears against HIS body, in object space
# ---------------------------------------------------------------------------
body = D.objects["us_grunt_joined_" + TAG]
dg = bpy.context.evaluated_depsgraph_get()
ev = body.evaluated_get(dg)
BMi = body.matrix_world.inverted()


def closest(p):
    ok, loc, nor, idx = ev.closest_point_on_mesh(BMi @ p)
    w = body.matrix_world @ loc
    n = (body.matrix_world.to_3x3() @ nor).normalized()
    return (p - w).length, (p - w).dot(n)


for o in [cord] + ears:
    oe = o.evaluated_get(dg)
    mesh = oe.to_mesh()
    inside = 0
    worst = 1e9
    for v in mesh.vertices:
        d, s = closest(oe.matrix_world @ v.co)
        if s < 0:
            inside += 1
        worst = min(worst, d if s >= 0 else -d)
    bb = [oe.matrix_world @ v.co for v in mesh.vertices]
    oe.to_mesh_clear()
    log("FIT %-28s evaluated world x[%.3f,%.3f] y[%.3f,%.3f] z[%.3f,%.3f]  inside %d  min clearance %.4f m"
        % (o.name, min(v.x for v in bb), max(v.x for v in bb), min(v.y for v in bb), max(v.y for v in bb),
           min(v.z for v in bb), max(v.z for v in bb), inside, worst))
    assert inside == 0, "%s penetrates Gus" % o.name
# the ears must hang ON the cord: each ear's origin on the cord's centreline polyline
# (ring centres are 19 mm apart, so measure to the SEGMENT, not the nearest vertex - a
# vertex test read 9.4 mm for an ear that was exactly on the cord)
cv = [cord.matrix_world @ v.co for v in cord.data.vertices]
centres = [sum((cv[4 * k + j] for j in range(4)), Vector()) / 4.0 for k in range(len(cv) // 4)]


def seg_dist(p):
    best = 1e9
    for k in range(len(centres)):
        a, b = centres[k], centres[(k + 1) % len(centres)]
        ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
        best = min(best, (p - (a + ab * t)).length)
    return best


mats = {m.name for o in [cord] + ears for m in o.data.materials}
imgs = {n.image.name for m in D.materials if m.name in mats for n in m.node_tree.nodes if n.type == 'TEX_IMAGE'}
log("necklace materials %s, images %s" % (sorted(mats), sorted(imgs)))
assert mats == {"necklace_kit_mat"} and imgs == {"necklace_kit_tex"}, "cord and ears must share one kit material/sheet"
worst_on = max(seg_dist(o.matrix_world.translation) for o in ears)
assert worst_on < 0.003, "an ear origin is %.4f m off the cord centreline" % worst_on
log("ears on the cord: max origin-to-centreline distance %.4f m (cord radius 0.00175)" % worst_on)
save("cord + 5 ears hung on %s" % TAG)
log("DONE")
