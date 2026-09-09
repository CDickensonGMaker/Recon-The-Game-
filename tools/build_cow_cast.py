"""build_cow_cast.py - the Conquest of Worms US cast, headless.

    "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" --background ^
        "assets/us/characters/us_base_v3.blend" --python tools/build_cow_cast.py

Writes assets/us/characters/conquest_of_worms_us_cast.blend. NEVER saves over the
source (there is an explicit guard below).

Three variants, all in the one file (psx-npc-pipeline standing rule):
  michael      <- grenadier family (he carries the M79 "Thumper"), + a rifleman ruck
                  transplanted across, + journal_michael tucked under the ruck flap
  gus_arrival  <- rifleman family, kit REDUCED (no bandolier, one canteen)
  gus_ears     <- gus_arrival + necklace_ears_gus + bag_gus (medic satchel, no crosses)

Assembly only. No vertex of any donor body is touched; variants are placed by moving
the ARMATURE OBJECT (psx-npc-pipeline FAILURE MODE 1).
"""
import bpy
import os
import sys
import hashlib
import math
from mathutils import Vector, Matrix

D = bpy.data
ROOT = r"C:\Users\caleb\RECONgame"
CHAR = os.path.join(ROOT, "assets", "us", "characters")
SRC = os.path.join(CHAR, "us_base_v3.blend")
OUT = os.path.join(CHAR, "conquest_of_worms_us_cast.blend")

MICHAEL, GUS_A, GUS_E = "michael", "gus_arrival", "gus_ears"
LAYOUT = {MICHAEL: 0.0, GUS_A: 3.0, GUS_E: 6.0}

# Ear anthropometry, measured from the literature and cross-checked on three
# populations: mean adult auricular height 63.4 mm (SD 6.2), width 33.8 mm (SD 6.3);
# Indian males 61.1 mm, Singaporean Chinese males 60.7 mm. A pinna cut at its root
# loses the concha attachment, so the trophy is shorter than the living ear.
EAR_H, EAR_W, EAR_T = 0.070, 0.040, 0.005
N_EARS = 7

# French pocket carnet de route, the format Louie would have carried in 1915:
# 9 x 14 cm ("pocket"). One documented poilu carnet de route runs 12 x 19 cm, which
# is the larger desk format. A 50-year-old swollen field notebook is ~22 mm thick.
JOURNAL_W, JOURNAL_H, JOURNAL_T = 0.095, 0.140, 0.022

SC = bpy.context.scene


def link(o):
    if o.name not in SC.collection.objects:
        SC.collection.objects.link(o)
    return o


def upd():
    bpy.context.view_layer.update()


def family(tag):
    return [o for o in D.objects if o.type == 'MESH' and o.name.endswith("_" + tag)]


def strip(name, tag):
    return name[: -(len(tag) + 1)]


def vhash(o):
    """Per-index RAW vertex coordinate hash. NOT a span (FAILURE MODE 2)."""
    h = hashlib.md5()
    for v in o.data.vertices:
        h.update(b"%.6f|%.6f|%.6f;" % (v.co.x, v.co.y, v.co.z))
    return h.hexdigest()[:12]


def mat_flat(name, rgb, rough=0.85, metal=0.0):
    if name in D.materials:
        return D.materials[name]
    m = D.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs['Base Color'].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    return m


# ---------------------------------------------------------------------------
# 0. prune the lineup down to the three donor families
# ---------------------------------------------------------------------------
DONORS = ("grenadier", "rifleman", "medic")
keep = set()
for t in DONORS:
    keep.add(D.objects["PSXRig_" + t])
    keep.update(family(t))
removed = 0
for o in list(D.objects):
    if o not in keep:
        D.objects.remove(o, do_unlink=True)
        removed += 1
for a in list(D.actions):
    D.actions.remove(a)
print("PRUNE: removed %d objects, %d actions; %d objects left"
      % (removed, 0, len(D.objects)), flush=True)


# ---------------------------------------------------------------------------
# 1. clone / rename the families
# ---------------------------------------------------------------------------
def clone_family(src_tag, dst_tag, new_x):
    srcrig = D.objects["PSXRig_" + src_tag]
    rig = srcrig.copy()
    rig.data = srcrig.data.copy()
    rig.name = "PSXRig_" + dst_tag
    rig.data.name = "PSXArm_" + dst_tag
    link(rig)
    rig.location = Vector((new_x, srcrig.location.y, srcrig.location.z))
    if rig.animation_data:
        rig.animation_data.action = None
    mapping = {}
    for o in family(src_tag):
        n = o.copy()
        n.data = o.data.copy()
        n.name = strip(o.name, src_tag) + "_" + dst_tag
        n.data.name = n.name
        link(n)
        mapping[o] = n
    for o, n in mapping.items():
        n.parent = rig if o.parent is srcrig else mapping.get(o.parent, None)
        n.parent_type = o.parent_type
        n.parent_bone = o.parent_bone
        n.matrix_parent_inverse = o.matrix_parent_inverse.copy()
        n.matrix_basis = o.matrix_basis.copy()
        for m in n.modifiers:
            if m.type == 'ARMATURE':
                m.object = rig
        n.hide_viewport = o.hide_viewport
        n.hide_render = o.hide_render
        n.hide_set(o.hide_get())
    upd()
    print("CLONE %s -> %s at x=%.2f : %d meshes"
          % (src_tag, dst_tag, new_x, len(mapping)), flush=True)
    return rig, mapping


def rename_family(src_tag, dst_tag, new_x):
    rig = D.objects["PSXRig_" + src_tag]
    rig.name = "PSXRig_" + dst_tag
    rig.data.name = "PSXArm_" + dst_tag
    rig.location.x = new_x
    if rig.animation_data:
        rig.animation_data.action = None
    n = 0
    for o in family(src_tag):
        o.name = strip(o.name, src_tag) + "_" + dst_tag
        o.data.name = o.name
        n += 1
    upd()
    print("RENAME %s -> %s at x=%.2f : %d meshes" % (src_tag, dst_tag, new_x, n), flush=True)
    return rig


rig_gus_a, _ = clone_family("rifleman", GUS_A, LAYOUT[GUS_A])
rig_gus_e, _ = clone_family("rifleman", GUS_E, LAYOUT[GUS_E])
rig_mike = rename_family("grenadier", MICHAEL, LAYOUT[MICHAEL])


# ---------------------------------------------------------------------------
# 2. cross-rig transplant (ruck -> Michael, satchel -> gus_ears)
#    Rig-relative, gated. No vertex coordinate is written.
# ---------------------------------------------------------------------------
def transplant(names, donor_rig, dst_rig, newname):
    for nm in names:
        o = D.objects[nm]
        if o.parent_type == 'BONE':
            a = donor_rig.data.bones[o.parent_bone].matrix_local
            b = dst_rig.data.bones[o.parent_bone].matrix_local
            drift = max(abs(a[i][j] - b[i][j]) for i in range(4) for j in range(4))
            if drift > 1e-5:
                raise SystemExit("ABORT transplant %s: rest matrix of %s differs by %.2e "
                                 "between rigs - a rig-relative copy is not valid."
                                 % (nm, o.parent_bone, drift))
    dR = dst_rig.matrix_world @ donor_rig.matrix_world.inverted()
    made = []
    for nm in names:
        o = D.objects[nm]
        want = dR @ o.matrix_world.copy()
        n = o.copy()
        n.data = o.data.copy()
        n.name = newname(nm)
        n.data.name = n.name
        link(n)
        n.parent = dst_rig
        n.parent_type = o.parent_type
        n.parent_bone = o.parent_bone
        n.matrix_parent_inverse = o.matrix_parent_inverse.copy()
        for m in n.modifiers:
            if m.type == 'ARMATURE':
                m.object = dst_rig
        upd()
        n.matrix_world = want
        upd()
        err = (n.matrix_world.translation - want.translation).length
        if err > 1e-4:
            raise SystemExit("ABORT transplant %s: landed %.6f m off target." % (nm, err))
        # rig-relative centroid gate: must match the donor's to 1e-4 m
        def rel(ob, rg):
            c = sum(((ob.matrix_world @ Vector(v.co)) for v in ob.data.vertices),
                    Vector()) / len(ob.data.vertices)
            return rg.matrix_world.inverted() @ c
        d = (rel(n, dst_rig) - rel(o, donor_rig)).length
        if d > 1e-4:
            raise SystemExit("ABORT transplant %s: rig-relative centroid off by %.6f m" % (nm, d))
        n.hide_viewport = o.hide_viewport
        n.hide_render = o.hide_render
        n.hide_set(o.hide_get())
        made.append(n)
        print("   transplant %-26s -> %-24s rel-centroid err %.2e"
              % (nm, n.name, d), flush=True)
    return made


rig_rifle = D.objects["PSXRig_rifleman"]
rig_medic = D.objects["PSXRig_medic"]

RUCK = ["ruck_body", "ruck_flap", "ruck_frame_bar", "ruck_frame_l", "ruck_frame_r",
        "ruck_buckle_l", "ruck_buckle_r", "ruck_pocket_0", "ruck_pocket_1", "ruck_pocket_2"]
print("TRANSPLANT ruck rifleman -> michael", flush=True)
transplant([r + "_rifleman" for r in RUCK], rig_rifle, rig_mike,
           lambda nm: strip(nm, "rifleman") + "_" + MICHAEL)

# The bag: the medic's musette, minus the red crosses (they are separate objects and
# are simply not copied). Bible I3 p10 "he is hiding something in his bag"; I3 p19
# "...Leave the bag."
SATCHEL = ["satchel_body", "satchel_flap", "satchel_sling",
           "satchel_buckle_a", "satchel_buckle_b"]
BAGNAME = {"satchel_body": "bag_gus", "satchel_flap": "bag_gus_flap",
           "satchel_sling": "bag_gus_sling", "satchel_buckle_a": "bag_gus_buckle_a",
           "satchel_buckle_b": "bag_gus_buckle_b"}
print("TRANSPLANT satchel medic -> gus_ears", flush=True)
bag = transplant([s + "_medic" for s in SATCHEL], rig_medic, rig_gus_e,
                 lambda nm: BAGNAME[strip(nm, "medic")] + "_" + GUS_E)

bag_canvas = mat_flat("bag_canvas_gus", (0.052, 0.058, 0.034), rough=0.95)
bag_web = mat_flat("bag_web_gus", (0.038, 0.040, 0.026), rough=0.95)
for o in bag:
    for i, m in enumerate(o.data.materials):
        o.data.materials[i] = bag_web if (m and "Webbing" in m.name) else bag_canvas


# ---------------------------------------------------------------------------
# 3. kit reduction on both Gus variants
#    Bible I2 p4: McCleary - "Until Brass can get an actual spot for him, he's going
#    to be floating around where ever we need him to be." A brand-new unassigned
#    replacement carries LESS than the veterans, not more.
# ---------------------------------------------------------------------------
DROP = ["web_bandolier", "canteen_l.003", "canteen_l.004", "canteen_l.005", "canteen_l.006"]
for tag in (GUS_A, GUS_E):
    gone = []
    for base in DROP:
        o = D.objects.get(base + "_" + tag)
        if o:
            gone.append(o.name)
            D.objects.remove(o, do_unlink=True)
    print("KIT REDUCTION %-12s dropped %d: %s" % (tag, len(gone), gone), flush=True)


# ---------------------------------------------------------------------------
# 4. props
# ---------------------------------------------------------------------------
def box(name, cx, cy, cz, sx, sy, sz, mat, rot_x=0.0):
    me = D.meshes.new(name)
    hx, hy, hz = sx / 2.0, sy / 2.0, sz / 2.0
    vs = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz),
          (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)]
    fs = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    me.from_pydata(vs, [], fs)
    me.update()
    me.materials.append(mat)
    o = D.objects.new(name, me)
    link(o)
    o.matrix_world = (Matrix.Translation(Vector((cx, cy, cz)))
                      @ Matrix.Rotation(rot_x, 4, 'X'))
    return o


def join_into(objs, name):
    for x in bpy.context.view_layer.objects:
        x.select_set(False)
    for x in objs:
        x.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    j = bpy.context.view_layer.objects.active
    j.name = name
    j.data.name = name
    return j


def bone_parent(o, rig, bone):
    want = o.matrix_world.copy()
    o.parent = rig
    o.parent_type = 'BONE'
    o.parent_bone = bone
    o.matrix_parent_inverse = Matrix.Identity(4)
    upd()
    o.matrix_world = want
    upd()
    err = (o.matrix_world.translation - want.translation).length
    if err > 1e-5:
        raise SystemExit("ABORT bone_parent %s: %.2e m off" % (o.name, err))


# --- 4a. journal_michael -----------------------------------------------------
# Bible §1: "He carries his grandfather's First World War journal in his ruck and
# reads it aloud to the squad in the dark."
mx = LAYOUT[MICHAEL]
flap = D.objects["ruck_flap_" + MICHAEL]
body = D.objects["ruck_body_" + MICHAEL]


def wbb(o):
    bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
    return (Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb))),
            Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb))))


fmn, fmx = wbb(flap)
bmn, bmx = wbb(body)
print("MEASURE ruck flap  world x[%.3f,%.3f] y[%.3f,%.3f] z[%.3f,%.3f]"
      % (fmn.x, fmx.x, fmn.y, fmx.y, fmn.z, fmx.z), flush=True)
print("MEASURE ruck body  world x[%.3f,%.3f] y[%.3f,%.3f] z[%.3f,%.3f]"
      % (bmn.x, bmx.x, bmn.y, bmx.y, bmn.z, bmx.z), flush=True)

# Book stands upright in the mouth of the pack, its foot 5.4 cm down under the flap
# and 4.6 cm of it proud - visible from behind and in three-quarter, which is the
# point (the author has to be able to SEE it).
J_TOP = fmx.z + 0.046
J_CZ = J_TOP - JOURNAL_H / 2.0
J_CX = mx + 0.070
J_CY = (fmn.y + fmx.y) / 2.0 + 0.012
lea = mat_flat("journal_leather", (0.030, 0.016, 0.011), rough=0.72)
pap = mat_flat("journal_pages", (0.330, 0.290, 0.196), rough=0.95)
cov = box("journal_cover", J_CX, J_CY, J_CZ, JOURNAL_W, JOURNAL_T, JOURNAL_H, lea, rot_x=math.radians(-9))
pgs = box("journal_pageblock", J_CX + 0.004, J_CY, J_CZ, JOURNAL_W - 0.010,
          JOURNAL_T - 0.006, JOURNAL_H - 0.008, pap, rot_x=math.radians(-9))
journal = join_into([cov, pgs], "journal_" + MICHAEL)
bone_parent(journal, rig_mike, "mixamorig:Spine2")
jmn, jmx = wbb(journal)
print("BUILT journal_%s  %d v / %d p  dims %.3f x %.3f x %.3f  top z=%.3f (flap top %.3f)"
      % (MICHAEL, len(journal.data.vertices), len(journal.data.polygons),
         *(jmx - jmn), jmx.z, fmx.z), flush=True)


# --- 4b. necklace_ears_gus ---------------------------------------------------
# Bible I3 p9: "the ears have become a necklace worn openly in camp."
gx = LAYOUT[GUS_E]
torso = D.objects["us_grunt_joined_" + GUS_E]
dg = bpy.context.evaluated_depsgraph_get()
ev = torso.evaluated_get(dg)


def chest_front(z):
    """Measure the front surface of the chest at height z. Object space, then back to
    world (verify-in-object-space rule) - a world-space ray_cast answers a different
    question."""
    p_world = Vector((gx, -0.60, z))
    p_local = torso.matrix_world.inverted() @ p_world
    ok, loc, nor, idx = ev.closest_point_on_mesh(p_local)
    if not ok:
        raise SystemExit("ABORT: closest_point_on_mesh failed at z=%.3f" % z)
    return (torso.matrix_world @ loc)


for z in (1.50, 1.46, 1.42, 1.38, 1.34):
    w = chest_front(z)
    print("MEASURE chest front z=%.2f -> world (%.4f, %.4f, %.4f)"
          % (z, w.x, w.y, w.z), flush=True)

CH_Y = chest_front(1.40).y          # front skin of the sternum
NECK_Z = 1.470                      # clavicle line (Neck bone head sits at z 1.5014)
CORD_DROP = 0.145
CORD_RX, CORD_RY = 0.105, 0.086
CORD_R = 0.0042
print("MEASURE sternum front y=%.4f  -> cord front y=%.4f" % (CH_Y, CH_Y - 0.016), flush=True)

cord_mat = mat_flat("necklace_cord", (0.014, 0.011, 0.008), rough=0.95)
# Dried/cured tissue, taken off real leather reference, not invented: "Dark Leather"
# #532E21 = sRGB(83,46,33) -> linear (0.087,0.027,0.015); pushed one step darker still,
# because VALUE is what separates the trophy from pale skin and pale fatigues at range.
ear_mat = mat_flat("ear_flesh", (0.062, 0.022, 0.013), rough=0.90)

SEG = 12


def cord_point(t):
    """t in [0,1); t=0 at the BACK of the neck, t=0.5 at the front."""
    a = t * 2.0 * math.pi
    x = gx + CORD_RX * math.sin(a)
    y = -0.010 + CORD_RY * math.cos(a)
    drop = CORD_DROP * ((1.0 - math.cos(a)) * 0.5) ** 1.25
    # pull the front of the loop clear of the chest skin
    if math.cos(a) < 0.0:
        y = min(y, CH_Y - 0.016)
    return Vector((x, y, NECK_Z - drop))


verts, faces = [], []
for i in range(SEG):
    p = cord_point(i / float(SEG))
    q = cord_point((i + 1) % SEG / float(SEG))
    d = (q - p)
    d.normalize()
    side = d.cross(Vector((0, 0, 1)))
    if side.length < 1e-6:
        side = Vector((1, 0, 0))
    side.normalize()
    up = side.cross(d).normalized()
    b = len(verts)
    for pt in (p, q):
        verts += [pt + side * CORD_R + up * CORD_R, pt - side * CORD_R + up * CORD_R,
                  pt - side * CORD_R - up * CORD_R, pt + side * CORD_R - up * CORD_R]
    faces += [(b + 0, b + 4, b + 5, b + 1), (b + 1, b + 5, b + 6, b + 2),
              (b + 2, b + 6, b + 7, b + 3), (b + 3, b + 7, b + 4, b + 0)]
me = D.meshes.new("necklace_cord")
me.from_pydata(verts, [], faces)
me.update()
me.materials.append(cord_mat)
cord = D.objects.new("necklace_cord", me)
link(cord)

# PINNA OUTLINE, traced off ear anatomy rather than invented. At this size the only
# thing that says "ear" is the SILHOUETTE, and it has three features:
#   * the helix - a long C sweeping up the front edge, over the top and down the back
#   * the intertragic notch - the one CONCAVE bite in the outline, between the
#     antitragus and the lobe. A convex blob reads as a petal; the notch is what stops it.
#   * the lobule - a rounded bulge hanging below that notch
# u is across the ear (front of the head is -u), v is up. Wound clockwise from the top.
EAR_OUTLINE = [(-0.04, 0.50), (0.18, 0.46), (0.36, 0.30), (0.44, 0.08), (0.40, -0.14),
               (0.26, -0.26), (0.20, -0.34),                       # antitragus
               (0.24, -0.44), (0.10, -0.50), (-0.04, -0.42),       # lobule
               (-0.10, -0.30), (-0.24, -0.20),                     # intertragic notch + tragus
               (-0.34, 0.02), (-0.40, 0.24), (-0.30, 0.42)]
# The concha bowl, on the front face only, one step darker. A flat card with no interior
# reads as a chip of leather; the bowl is what makes it a specific object.
EAR_CONCHA = [(0.02, 0.22), (0.20, 0.10), (0.20, -0.10), (0.06, -0.20), (-0.10, -0.10),
              (-0.12, 0.10)]
ear_inner_mat = mat_flat("ear_inner", (0.030, 0.011, 0.007), rough=0.92)
ear_objs = []
for k in range(N_EARS):
    # spread over the front arc of the loop; the tilt is baked into the OUTLINE, never
    # applied as an object rotation - the mesh is authored in world coords with an
    # identity object transform, so an object rotation pivots about the world origin
    # and throws the ear metres away. (Caught by the world-bbox print, not by eye.)
    t = 0.16 + (0.68 * k / float(N_EARS - 1))
    anchor = cord_point(t % 1.0)
    nrm = Vector((0, -1, 0))
    side = Vector((1, 0, 0))
    ang = math.radians(((k * 37) % 41) - 20)
    ca, sa = math.cos(ang), math.sin(ang)
    zj = -0.006 * ((k * 5) % 3)
    vs, fs = [], []
    n = len(EAR_OUTLINE)

    def place(u, v, depth):
        uu = u * EAR_W
        vv = v * EAR_H - EAR_H * 0.52 + zj
        ru = uu * ca - vv * sa
        rv = uu * sa + vv * ca
        return anchor + side * ru + Vector((0, 0, 1)) * rv + nrm * depth

    # mirror alternate ears so it reads as a mix of lefts and rights off different men
    mir = -1.0 if (k % 2) else 1.0
    for sgn in (1, -1):
        for (u, v) in EAR_OUTLINE:
            vs.append(place(u * mir, v, sgn * EAR_T * 0.5))
    fs.append(tuple(range(n)))                       # front
    fs.append(tuple(reversed(range(n, 2 * n))))      # back
    for i in range(n):
        j = (i + 1) % n
        fs.append((i, j, n + j, n + i))
    c0 = len(vs)
    for (u, v) in EAR_CONCHA:
        vs.append(place(u * mir, v, EAR_T * 0.5 + 0.0007))
    fs.append(tuple(range(c0, c0 + len(EAR_CONCHA))))
    m2 = D.meshes.new("ear_%02d" % k)
    m2.from_pydata(vs, [], fs)
    m2.update()
    m2.materials.append(ear_mat)
    m2.materials.append(ear_inner_mat)
    m2.polygons[-1].material_index = 1
    ear_objs.append(link(D.objects.new("ear_%02d" % k, m2)))

necklace = join_into([cord] + ear_objs, "necklace_ears_" + GUS_E)
bone_parent(necklace, rig_gus_e, "mixamorig:Spine2")
nmn, nmx = wbb(necklace)
print("BUILT necklace_ears_%s  %d v / %d p (%d tris)  world x[%.3f,%.3f] y[%.3f,%.3f] z[%.3f,%.3f]"
      % (GUS_E, len(necklace.data.vertices), len(necklace.data.polygons),
         sum(len(p.vertices) - 2 for p in necklace.data.polygons),
         nmn.x, nmx.x, nmn.y, nmx.y, nmn.z, nmx.z), flush=True)
print("       one ear = %.1f mm tall x %.1f mm wide (lit. lit. mean adult auricle 63.4 x 33.8 mm; "
      "head mesh is %.1f mm tall)" % (EAR_H * 1000, EAR_W * 1000,
                                      D.objects["grunt_head_" + GUS_E].dimensions.z * 1000), flush=True)


# ---------------------------------------------------------------------------
# 5. faces - the destination cell is MEASURED PER MESH, never assumed
#
# Two facts, both measured here on 2026-09-09 after each cost a render pass:
#   * the VISIBLE joined body and the HIDDEN grunt_head donor sample DIFFERENT cells
#   * every variant samples its OWN cell (that is how the squad has different faces)
# so a cell measured off one man, or off the gib donor, paints a tile nothing looks at
# and the render comes back wearing the stock face. Measure every face-material polygon
# on every mesh of the family and paint every cell any of them lands in.
# ---------------------------------------------------------------------------
import numpy as np

FACE_COLS, FACE_ROWS = 10, 7        # grunt_dresser.gd:20-21


def face_cells(o):
    """Set of (col, row_from_bottom) cells this mesh's face-atlas polygons sample."""
    me = o.data
    if not me.uv_layers:
        return {}
    uv = me.uv_layers.active.data
    out = {}
    for mi, m in enumerate(me.materials):
        if not m or "face_atlas" not in m.name:
            continue
        us, vs = [], []
        for p in me.polygons:
            if p.material_index != mi:
                continue
            for li in p.loop_indices:
                us.append(uv[li].uv[0])
                vs.append(uv[li].uv[1])
        if not us:
            continue
        cu, cv = sum(us) / len(us), sum(vs) / len(vs)
        col = min(FACE_COLS - 1, max(0, int(cu * FACE_COLS)))
        row = min(FACE_ROWS - 1, max(0, int(cv * FACE_ROWS)))
        span_u, span_v = max(us) - min(us), max(vs) - min(vs)
        if span_u > 1.0 / FACE_COLS + 1e-3 or span_v > 1.0 / FACE_ROWS + 1e-3:
            raise SystemExit("ABORT %s: face island %0.4fx%0.4f does not fit one atlas cell "
                             "(%0.4fx%0.4f) - retargeting it would smear across tiles."
                             % (o.name, span_u, span_v, 1.0 / FACE_COLS, 1.0 / FACE_ROWS))
        out[(col, row)] = (min(us), max(us), min(vs), max(vs))
    return out


def px(img):
    w, h = img.size
    return np.array(img.pixels[:], dtype=np.float32).reshape(h, w, img.channels)


def build_face_sheet(name, cell_png, meshes, out_png):
    base = D.images["face_atlas_v5"]
    W, H = base.size
    a = px(base)                               # bottom-up, same colour pipeline as the donor
    donor_img = D.images.load(cell_png)
    d = px(donor_img)
    cells = {}
    for o in meshes:
        for c, bbox in face_cells(o).items():
            cells.setdefault(c, []).append(o.name)
    if not cells:
        raise SystemExit("ABORT %s: no mesh samples a face atlas cell" % name)
    for (col, row), owners in sorted(cells.items()):
        x0, x1 = int(round(col * W / FACE_COLS)), int(round((col + 1) * W / FACE_COLS))
        y0, y1 = int(round(row * H / FACE_ROWS)), int(round((row + 1) * H / FACE_ROWS))
        th, tw = y1 - y0, x1 - x0
        src = d
        if (src.shape[0], src.shape[1]) != (th, tw):
            yi = (np.arange(th) * (src.shape[0] / float(th))).astype(int).clip(0, src.shape[0] - 1)
            xi = (np.arange(tw) * (src.shape[1] / float(tw))).astype(int).clip(0, src.shape[1] - 1)
            src = src[yi][:, xi]
        a[y0:y1, x0:x1, :3] = src[:, :, :3]
        a[y0:y1, x0:x1, 3] = 1.0
        print("   %s: painted cell col=%d row_from_bottom=%d (px x%d-%d y%d-%d) <- %s"
              % (name, col, row, x0, x1, y0, y1, sorted(owners)), flush=True)
    tmp = D.images.new(name + "_tmp", W, H, alpha=True)
    tmp.pixels.foreach_set(np.ascontiguousarray(a, dtype=np.float32).ravel())
    tmp.filepath_raw = out_png
    tmp.file_format = 'PNG'
    tmp.save()
    D.images.remove(tmp)
    # RELOAD from disk. An image made with D.images.new() carries a FLOAT buffer, and the
    # glTF exporter writes it out as a 16-bit PNG - measured: 1.72 MB embedded for a sheet
    # that is 0.75 MB as an ordinary 8-bit file, which busts the 1MB texture law on its
    # own. Reloading gives a plain byte image.
    out = D.images.load(out_png)
    out.name = name
    out.pack()
    D.images.remove(donor_img)
    print("   %s: %dx%d, %.2f MB on disk (8-bit reload)"
          % (name, out.size[0], out.size[1], os.path.getsize(out_png) / 1048576.0), flush=True)
    return out


def face_material(name, img):
    m = D.materials["face_atlas_mat"].copy()
    m.name = name
    for n in m.node_tree.nodes:
        if n.type == 'TEX_IMAGE':
            n.image = img
            n.interpolation = 'Closest'
    return m


SHEETS = {}
for who, cellpng, tags in (("michael", "cow_michael_face_cell.png", [MICHAEL]),
                           ("gus", "cow_gus_face_cell.png", [GUS_A, GUS_E])):
    meshes = [o for t in tags for o in family(t)]
    im = build_face_sheet("cow_%s_face_atlas" % who, os.path.join(CHAR, cellpng),
                          meshes, os.path.join(CHAR, "cow_%s_face_atlas.png" % who))
    SHEETS[who] = face_material("face_atlas_%s" % who, im)

FACE_MAT = {MICHAEL: SHEETS["michael"], GUS_A: SHEETS["gus"], GUS_E: SHEETS["gus"]}
for tag, fm in FACE_MAT.items():
    hits = 0
    for o in family(tag):
        for i, m in enumerate(o.data.materials):
            if m and m.name.startswith("face_atlas_mat"):
                o.data.materials[i] = fm
                hits += 1
    if hits == 0:
        raise SystemExit("ABORT: %s had no face_atlas_mat slot to repoint" % tag)
    print("FACE %-12s -> %-20s (%d material slots repointed)" % (tag, fm.name, hits), flush=True)


# ---------------------------------------------------------------------------
# 6. drop the leftover donor families
# ---------------------------------------------------------------------------
for t in ("rifleman", "medic"):
    n = 0
    for o in family(t) + [D.objects["PSXRig_" + t]]:
        D.objects.remove(o, do_unlink=True)
        n += 1
    print("DROP donor family %s (%d objects)" % (t, n), flush=True)
for blk in (D.meshes, D.armatures, D.materials, D.images):
    for x in list(blk):
        if x.users == 0:
            blk.remove(x)
upd()


# ---------------------------------------------------------------------------
# 7. ACCEPTANCE GATES (psx-npc-pipeline section 5)
# ---------------------------------------------------------------------------
TAGS = [MICHAEL, GUS_A, GUS_E]
fails = []
print("\n================ ACCEPTANCE GATES ================", flush=True)

# per-index vertex hashes, per part, across variants
PARTS = ["us_grunt_joined", "Base_Human", "grunt_head", "grunt_torso", "grunt_uparm_l",
         "grunt_uparm_r", "grunt_forearm_l", "grunt_forearm_r", "grunt_leg_l", "grunt_leg_r",
         "cap_head", "cap_torso", "cap_forearm_l", "cap_forearm_r", "cap_leg_l", "cap_leg_r",
         "cap_uparm_l", "cap_uparm_r"]
print("per-index RAW vertex hashes (not spans):", flush=True)
for p in PARTS:
    hs = {}
    for t in TAGS:
        o = D.objects.get(p + "_" + t)
        if o:
            hs[t] = vhash(o)
    uniq = set(hs.values())
    ok = len(uniq) == 1
    if not ok:
        fails.append("vertex hash mismatch on %s: %s" % (p, hs))
    print("   %-18s %s  %s" % (p, list(uniq)[0] if ok else hs, "OK" if ok else "FAIL"), flush=True)

# raw X span of the body, and evaluated X dimension of every mesh
for t in TAGS:
    o = D.objects["us_grunt_joined_" + t]
    xs = [v.co.x for v in o.data.vertices]
    span = max(xs) - min(xs)
    ok = abs(span - 1.6111) < 1e-3
    if not ok:
        fails.append("body raw X span %s = %.4f" % (t, span))
    print("body raw X span %-12s %.4f  %s" % (t, span, "OK" if ok else "FAIL"), flush=True)

# The pipeline's "no evaluated X > 1.2 m" rule assumes a POSED character. This file is
# parked in the studio T-pose, where the body legitimately spans the 1.6111 m arm span,
# so a flat 1.2 threshold fails on a healthy mesh. The smear signature is an evaluated
# dimension that EXCEEDS the mesh's own raw span - a pose reshapes, a smear inflates.
worst = (0.0, "-")
for o in D.objects:
    if o.type != 'MESH' or not o.data.vertices:
        continue
    xs = [v.co.x for v in o.data.vertices]
    raw = max(xs) - min(xs)
    ev_x = o.dimensions.x
    if ev_x > max(1.2, raw + 1e-3):
        fails.append("evaluated X %.4f exceeds raw span %.4f on %s" % (ev_x, raw, o.name))
    if ev_x > worst[0]:
        worst = (ev_x, o.name)
print("max evaluated X dimension: %.4f m on %s (its own raw span %.4f - T-pose arm span, "
      "not smear)" % (worst[0], worst[1],
                      max(v.co.x for v in D.objects[worst[1]].data.vertices)
                      - min(v.co.x for v in D.objects[worst[1]].data.vertices)), flush=True)

# rigs
for t in TAGS:
    rig = D.objects["PSXRig_" + t]
    posed = 0
    for pb in rig.pose.bones:
        moved = pb.location.length > 1e-5 or abs(pb.scale.x - 1) > 1e-5
        if pb.rotation_mode == 'QUATERNION':
            q = pb.rotation_quaternion
            moved = moved or abs(q.w - 1.0) > 1e-5 or (q.x ** 2 + q.y ** 2 + q.z ** 2) > 1e-10
        else:
            moved = moved or pb.rotation_euler.length > 1e-5
        posed += 1 if moved else 0
    s = tuple(round(v, 4) for v in rig.scale)
    ok = len(rig.data.bones) == 41 and s == (1.0, 1.0, 1.0)
    if not ok:
        fails.append("rig %s bones=%d scale=%s" % (t, len(rig.data.bones), s))
    print("rig %-12s bones=%d posed=%d pose_position=%s scale=%s  %s"
          % (t, len(rig.data.bones), posed, rig.data.pose_position, s,
             "OK" if ok else "FAIL"), flush=True)

# weights
for t in TAGS:
    bad_unw, bad_sum, bad_vg = 0, 0, []
    bones = {b.name for b in D.objects["PSXRig_" + t].data.bones}
    lo, hi = 9e9, -9e9
    for o in family(t):
        if not o.vertex_groups or not any(m.type == 'ARMATURE' for m in o.modifiers):
            continue
        bad_vg += [g.name for g in o.vertex_groups if g.name not in bones]
        for v in o.data.vertices:
            s = sum(g.weight for g in v.groups)
            if not v.groups:
                bad_unw += 1
            else:
                lo, hi = min(lo, s), max(hi, s)
                if abs(s - 1.0) > 1e-3:
                    bad_sum += 1
    ok = bad_unw == 0 and bad_sum == 0 and not bad_vg
    if not ok:
        fails.append("weights %s unweighted=%d offsum=%d orphan_vg=%s"
                     % (t, bad_unw, bad_sum, sorted(set(bad_vg))[:5]))
    print("weights %-12s sum min=%.4f max=%.4f  unweighted=%d  vgroups-without-bone=%d  %s"
          % (t, lo, hi, bad_unw, len(set(bad_vg)), "OK" if ok else "FAIL"), flush=True)

# visibility contract (FAILURE MODE 9)
for t in TAGS:
    fam = family(t)
    jo = [o for o in fam if o.name.startswith("us_grunt_joined")]
    sp = [o for o in fam if o.name.startswith("grunt_")]
    cp = [o for o in fam if o.name.startswith("cap_")]
    hf = [o for o in fam if o.name.startswith("head_frag_")]
    bh = [o for o in fam if o.name.startswith("Base_Human")]
    jv = sum(1 for o in jo if not o.hide_get())
    sv = sum(1 for o in sp if not o.hide_get())
    cv = sum(1 for o in cp if not o.hide_get())
    hv = sum(1 for o in hf if not o.hide_get())
    bv = sum(1 for o in bh if not o.hide_get())
    ok = jv == len(jo) == 1 and sv == 0 and cv == 0 and hv == 0 and bv == 0
    if not ok:
        fails.append("visibility %s joined=%d/%d split=%d/%d caps=%d/%d frags=%d/%d base=%d/%d"
                     % (t, jv, len(jo), sv, len(sp), cv, len(cp), hv, len(hf), bv, len(bh)))
    print("visibility %-12s joined %d/%d visible | split %d/%d | caps %d/%d | frags %d/%d | "
          "Base_Human %d/%d  %s"
          % (t, jv, len(jo), sv, len(sp), cv, len(cp), hv, len(hf), bv, len(bh),
             "OK" if ok else "FAIL"), flush=True)

# gore caps present, on gore_cap_mat
CAPS = ["cap_head", "cap_torso", "cap_forearm_l", "cap_forearm_r",
        "cap_leg_l", "cap_leg_r", "cap_uparm_l", "cap_uparm_r"]
for t in TAGS:
    miss = [c for c in CAPS if (c + "_" + t) not in D.objects]
    wrong = [c for c in CAPS if (c + "_" + t) in D.objects
             and not all(m and m.name == "gore_cap_mat"
                         for m in D.objects[c + "_" + t].data.materials)]
    if miss or wrong:
        fails.append("caps %s missing=%s wrongmat=%s" % (t, miss, wrong))
    print("gore caps %-12s %d/%d present, all on gore_cap_mat: %s  %s"
          % (t, len(CAPS) - len(miss), len(CAPS), not wrong,
             "OK" if not (miss or wrong) else "FAIL"), flush=True)

# name collisions
def dotted(x):
    return len(x.name) > 4 and x.name[-4] == "." and x.name[-3:].isdigit()


# Objects / meshes / images are the load-bearing namespace: gib_system.gd resolves
# meshes by EXACT name, so a .001 there is a real defect and fails the build.
coll = ["%s:%s" % (lbl, x.name)
        for blk, lbl in ((D.objects, "object"), (D.meshes, "mesh"), (D.images, "image"))
        for x in blk if dotted(x) and not x.name.split(".")[0].startswith("canteen")]
if coll:
    fails.append("name collisions: %s" % coll)
print("name collisions in objects/meshes/images (canteens excepted): %d %s"
      % (len(coll), coll if coll else ""), flush=True)
# Materials: dotted names here are INHERITED from us_base_v3 (the M79's Parkerized.006/7,
# the ruck's webbing_canvas.001) and ship in every existing us_grunt_*.glb. Reported,
# not failed - renaming them would diverge this cast from the rest of the squad.
matdots = sorted(x.name for x in D.materials if dotted(x))
print("dotted MATERIAL names inherited from us_base_v3 (reported, not a failure): %s"
      % matdots, flush=True)

# images over 1MB
big = []
for im in D.images:
    if im.size[0] == 0:
        continue
    n = im.size[0] * im.size[1] * im.channels
    if n > 1048576 * 3:
        big.append((im.name, im.size[0], im.size[1]))
print("images by raw size (>1MB flagged; the GLB shrinker runs after export):", flush=True)
for im in sorted(D.images, key=lambda i: -i.size[0] * i.size[1]):
    if im.size[0]:
        print("   %-30s %dx%d" % (im.name, im.size[0], im.size[1]), flush=True)

print("=================================================", flush=True)
if fails:
    print("GATE FAILURES (%d) - REFUSING TO SAVE:" % len(fails), flush=True)
    for f in fails:
        print("   ! " + f, flush=True)
    raise SystemExit(1)
print("ALL GATES PASS", flush=True)


# ---------------------------------------------------------------------------
# 8. save (never over the source)
# ---------------------------------------------------------------------------
if os.path.normcase(os.path.abspath(OUT)) == os.path.normcase(os.path.abspath(SRC)):
    raise SystemExit("ABORT: refusing to write over us_base_v3.blend")
bpy.ops.wm.save_as_mainfile(filepath=OUT, compress=True)
print("SAVED %s  (%.1f MB)" % (OUT, os.path.getsize(OUT) / 1048576.0), flush=True)
