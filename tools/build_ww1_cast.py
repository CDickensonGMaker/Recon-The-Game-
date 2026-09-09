"""build_ww1_cast.py - the Conquest of Worms WW1 cast (French poilus + German infantry, 1915).

    "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" --background ^
        "assets/us/characters/us_base_v3.blend" --python tools/build_ww1_cast.py

Writes assets/ww1/characters/conquest_of_worms_ww1.blend. NEVER saves over the source
(explicit guard at the bottom).

SEVEN MEN, one file (psx-npc-pipeline standing rule). See CAST below for the kit and the
historical basis of each decision.

ASSEMBLY ONLY. Caleb's 2026-08-04 ruling stands: no procedural geometry generation - "just
make a copy of one of the core units and modify it". Every piece of WW1 kit in this file is
an EXISTING us_base_v3 object duplicated, scaled and placed:

    kepi          <- officer_cap_black      (peaked cap: flat top, band, peak)
    cerveliere    <- scrub_cap_surgeon      (shallow skull cap -> the steel brain-pan)
    adrian shell  <- helmet_shell_worn      (M1 dome + brim -> the Adrian dome + brim)
    adrian crest  <- officer_cigar          (tapered cylinder -> the crown ridge)
    pickelhaube   <- scrub_cap_surgeon      (dome, raised)
    spike         <- officer_cigar          (tapered cylinder)
    peak/neck gd  <- web_back_yoke          (thin strip)
    cover number  <- helmet_bugjuice        (small box, flattened into a plate)
    coat skirt    <- apron_front_surgeon    (hanging cloth panel, front + back)
    rifle         <- M70sniper              (bolt-action, scope polygons deleted)
    waist belt    <- web_belt               (recoloured leather)

No vertex of any BODY mesh is touched. Variants are placed by moving the ARMATURE OBJECT
(psx-npc-pipeline FAILURE MODE 1). All 14 rigs in us_base_v3 were measured to have
bit-identical bone rest matrices (max drift 0.000e+00 over 41 bones), so the rig-relative
transplant used for the cross-family donors is exactly valid; the gate is re-run here.

The uniforms are PAINTED INTO THE BODY TEXTURE, per the citizens ruling - a copy of the
shared atlas per man, recoloured region by region under a mask rasterised from the body's
OWN UV polygons. Only silhouettes paint cannot fake (coat skirt, headgear) are geometry.
"""
import bpy
import os
import sys
import math
import hashlib
import numpy as np
from mathutils import Vector, Matrix

D = bpy.data
ROOT = r"C:\Users\caleb\RECONgame"
USCHAR = os.path.join(ROOT, "assets", "us", "characters")
OUTDIR = os.path.join(ROOT, "assets", "ww1", "characters")
SRC = os.path.join(USCHAR, "us_base_v3.blend")
OUT = os.path.join(OUTDIR, "conquest_of_worms_ww1.blend")
SHEET_SRC = os.path.join(USCHAR, "recovered_ref_factions.png")
os.makedirs(OUTDIR, exist_ok=True)

DONOR = "rifleman"                  # the body family every man is cloned from
SPACING = 3.0

# ---------------------------------------------------------------------------
# THE CAST
#
# Every date below was checked against reference before anything was modelled; the
# sources are named in the report. The three that matter most:
#   * The Adrian helmet's first large-scale field use was SEPTEMBER 1915 (Champagne and
#     Artois). At Notre-Dame de Lorette in MAY 1915 it did not exist in the field. The
#     headgear is the KEPI, over (or, as the troops actually wore it, ON TOP OF) the
#     cerveliere steel brain-pan - 700,000 made Dec 1914-Feb 1915, only 200,000 issued,
#     so it is a MINORITY item and only one man in this set has one.
#   * The capote M1914 "Poiret" is SINGLE-breasted, one row of six buttons, body cut from
#     one piece of cloth. Introduced September 1914. The M1877 it replaced is
#     double-breasted (two rows of six) and was "completely replaced by the spring of
#     1915" - so one holdout in the set, not a squad of them.
#   * The double-breasted M1915 capote is NOT a September 1915 garment. Existing Poiret
#     stocks had to be exhausted first and significant M1915 distribution did not happen
#     until the LATE SUMMER OF 1916, with M1914s issued and worn well into 1917. So the
#     helmet and the coat are two SEPARATE marks of time passing, a year apart, and this
#     cast carries them as two separate men.
# ---------------------------------------------------------------------------
CAST = {
    "louie_1915": dict(
        label="LOUIE", year="April-May 1915",
        kit="kepi (couvre-kepi) | capote M1914 Poiret, single-breasted | Lebel",
        nation="fr", head="kepi", cover_kepi=True, coat="single", skirt=True,
        rifle=("lebel", 1.300),
        coat_rgb=(150, 161, 171),      # "ashen light blue" - the lightest of the cloths
        trou_rgb=(116, 122, 127),      # substitute grey-blue: horizon-blue cloth was
        putt_rgb=(110, 116, 121),      # reserved for GREATCOATS AND KEPIS until end-May
        boot_rgb=(62, 45, 32),         # 1915, so trousers were whatever was available
        belt_rgb=(74, 53, 37),
        kepi_rgb=(126, 136, 146), band_rgb=(126, 136, 146)),

    "louie_adrian": dict(
        label="LOUIE", year="September 1915",
        kit="casque Adrian M15 | capote M1914 Poiret (unchanged) | Lebel",
        nation="fr", head="adrian", coat="single", skirt=True,
        rifle=("lebel", 1.300),
        coat_rgb=(150, 161, 171),      # THE SAME COAT. The helmet is what changed.
        trou_rgb=(133, 145, 153), putt_rgb=(128, 139, 147),
        boot_rgb=(62, 45, 32), belt_rgb=(74, 53, 37),
        helm_rgb=(120, 132, 141)),

    "poilu_a": dict(
        label="POILU - LINE (the older man)", year="May 1915",
        kit="bare kepi, red band | capote M1877, DOUBLE-breasted | pantalon garance | Berthier",
        nation="fr", head="kepi", cover_kepi=False, coat="double", skirt=True,
        rifle=("berthier", 1.306),
        coat_rgb=(58, 66, 84),         # M1877 iron blue
        trou_rgb=(158, 48, 42),        # PANTALON GARANCE - madder red, not yet replaced
        putt_rgb=(66, 74, 90),
        boot_rgb=(62, 45, 32), belt_rgb=(74, 53, 37),
        kepi_rgb=(52, 60, 78), band_rgb=(150, 44, 40)),   # red band showing: no cover

    "poilu_b": dict(
        label="POILU - LINE (young)", year="May 1915",
        kit="kepi + cerveliere worn ON TOP | capote M1914, dark 'English' cloth | Berthier",
        nation="fr", head="kepi", cover_kepi=True, cerveliere=True, coat="single", skirt=True,
        rifle=("berthier", 1.306),
        coat_rgb=(101, 110, 122),      # "dark blue-gray", the other end of the gamut
        trou_rgb=(116, 102, 82),       # substitute brown/tan cloth
        putt_rgb=(122, 110, 88),
        boot_rgb=(62, 45, 32), belt_rgb=(74, 53, 37),
        kepi_rgb=(112, 120, 130), band_rgb=(112, 120, 130)),

    "poilu_1916": dict(
        label="POILU - LINE", year="1916",
        kit="casque Adrian M15 | capote M1915, DOUBLE-breasted | Berthier",
        nation="fr", head="adrian", coat="double", skirt=True,
        rifle=("berthier", 1.306),
        coat_rgb=(133, 145, 153),      # standardised horizon blue at last
        trou_rgb=(133, 145, 153), putt_rgb=(128, 139, 147),
        boot_rgb=(62, 45, 32), belt_rgb=(74, 53, 37),
        helm_rgb=(120, 132, 141)),

    "german_boy": dict(
        label="THE YOUNG GERMAN (spared)", year="1915",
        kit="Pickelhaube + Ueberzug, GREEN number | M1907/10 Feldrock | Gewehr 98",
        nation="de", head="pickelhaube", cover_number=True, coat="german", skirt=False,
        rifle=("gew98", 1.250),
        coat_rgb=(100, 104, 86),       # feldgrau
        trou_rgb=(92, 94, 96),         # STEINGRAU - stone grey, introduced August 1914
        putt_rgb=(30, 28, 28),         # Marschstiefel: black leather knee jackboot
        boot_rgb=(26, 24, 24), belt_rgb=(30, 28, 28),
        helm_rgb=(150, 141, 118)),     # the cover, a washed-out light tan

    "german_line": dict(
        label="GERMAN INFANTRYMAN", year="1915",
        kit="Pickelhaube + Ueberzug, NO number | M1907/10 Feldrock | Gewehr 98",
        nation="de", head="pickelhaube", cover_number=False, coat="german", skirt=False,
        rifle=("gew98", 1.250),
        coat_rgb=(95, 99, 82), trou_rgb=(88, 90, 92),
        putt_rgb=(30, 28, 28), boot_rgb=(26, 24, 24), belt_rgb=(30, 28, 28),
        helm_rgb=(143, 134, 112)),
}
TAGS = list(CAST.keys())
LAYOUT = {t: i * SPACING for i, t in enumerate(TAGS)}

SHEET_W, SHEET_H = 1024, 1621      # keeps 3600:5700; body band lands at ~655x306 px

# US kit that must not survive onto a 1915 European. Prefixes, matched before the tag.
STRIP = ("m16_world", "helmet_shell_worn", "helmet_camo_shell", "helmet_bugjuice",
         "web_bandolier", "web_back_yoke", "web_buckle", "web_clip", "web_strap",
         "web_suspender", "web_yoke", "canteen_", "pouch_belt_worn", "ruck_")


def link(o):
    if o.name not in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.link(o)


def upd():
    bpy.context.view_layer.update()


def family(tag):
    return [o for o in D.objects if o.type == 'MESH' and o.name.endswith("_" + tag)]


def strip_tag(name, tag):
    return name[: -(len(tag) + 1)]


def vhash(o):
    """Per-index RAW vertex coordinate hash. NOT a span (FAILURE MODE 2)."""
    h = hashlib.md5()
    for v in o.data.vertices:
        h.update(b"%.6f|%.6f|%.6f;" % (v.co.x, v.co.y, v.co.z))
    return h.hexdigest()[:12]


def mat_flat(name, rgb, rough=0.92, metal=0.0):
    if name in D.materials:
        return D.materials[name]
    m = D.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs['Base Color'].default_value = (rgb[0] / 255.0, rgb[1] / 255.0, rgb[2] / 255.0, 1.0)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    return m


def wbb(objs):
    # `obj.dimensions` is the LOCAL bounding box times scale, not the world AABB, and
    # `bound_box` is pre-modifier. Both lie about a rotated or deformed object, so every
    # measurement in this file goes through the evaluated mesh in world space. The
    # explicit dg.update() is not decoration: without it the first read after a transform
    # write comes back stale, which is what made the kepi land 12 mm off its target box.
    dg = bpy.context.evaluated_depsgraph_get()
    dg.update()
    mn = Vector((1e9,) * 3)
    mx = Vector((-1e9,) * 3)
    for o in objs:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        for v in me.vertices:
            w = ev.matrix_world @ v.co
            mn = Vector(map(min, mn, w))
            mx = Vector(map(max, mx, w))
        ev.to_mesh_clear()
    return mn, mx


# ===========================================================================
# 0. gate every rig's rest pose against the donor BEFORE any transplant
# ===========================================================================
base_rig = D.objects["PSXRig_" + DONOR]
worst = 0.0
for r in [o for o in D.objects if o.type == 'ARMATURE']:
    for b in base_rig.data.bones:
        ob = r.data.bones.get(b.name)
        if ob is None:
            raise SystemExit("ABORT: %s is missing bone %s" % (r.name, b.name))
        worst = max(worst, max(abs(b.matrix_local[i][j] - ob.matrix_local[i][j])
                               for i in range(4) for j in range(4)))
print("REST GATE: max bone rest-matrix drift across all %d rigs = %.3e (0 means a "
      "rig-relative transplant is exact)"
      % (len([o for o in D.objects if o.type == 'ARMATURE']), worst), flush=True)
if worst > 1e-6:
    raise SystemExit("ABORT: rigs disagree at rest by %.3e - transplant is not valid." % worst)

# grab the cross-family donors BEFORE the prune removes their families
DONOR_SPEC = {
    "kepi":       ("officer_cap_black", "PSXRig.002", 'BONE', "mixamorig:Head"),
    "domecap":    ("scrub_cap_surgeon", "PSXRig_surgeon", 'BONE', "mixamorig:Head"),
    "adrian":     ("helmet_shell_worn_" + DONOR, "PSXRig_" + DONOR, 'BONE', "mixamorig:Head"),
    "rod":        ("officer_cigar", "PSXRig.002", 'BONE', "mixamorig:LeftHand"),
    "strip":      ("web_back_yoke_" + DONOR, "PSXRig_" + DONOR, 'OBJECT', ""),
    "plate":      ("helmet_bugjuice_" + DONOR, "PSXRig_" + DONOR, 'BONE', "mixamorig:Head"),
    "skirt":      ("apron_front_surgeon", "PSXRig_surgeon", 'BONE', "mixamorig:Spine1"),
    "rifle":      ("M70sniper", None, 'OBJECT', ""),
    "gunanchor":  ("m16_world_" + DONOR, "PSXRig_" + DONOR, 'BONE', "mixamorig:RightHand"),
}
STASH = {}
for k, (nm, rig, ptype, bone) in DONOR_SPEC.items():
    o = D.objects.get(nm)
    if o is None:
        raise SystemExit("ABORT: donor %s (%s) not found in us_base_v3" % (k, nm))
    cp = o.copy()
    cp.data = o.data.copy()
    cp.name = "_DONOR_" + k
    cp.data.name = "_DONOR_" + k
    link(cp)
    cp.parent = None
    cp.matrix_world = o.matrix_world.copy()          # world pose of the donor as worn
    STASH[k] = cp
    print("STASH donor %-10s <- %-28s v=%-4d p=%-4d world dims %s"
          % (k, nm, len(cp.data.vertices), len(cp.data.polygons),
             tuple(round(v, 4) for v in cp.dimensions)), flush=True)
upd()

# the rig-space frame of the donor rig, so a stashed world pose can be replayed on any rig
DONOR_RIG_MW = {}
for k, (nm, rig, ptype, bone) in DONOR_SPEC.items():
    DONOR_RIG_MW[k] = D.objects[rig].matrix_world.copy() if rig else Matrix.Identity(4)


# ===========================================================================
# 1. prune to the donor family + the stashed donors
# ===========================================================================
keep = set(STASH.values())
keep.add(base_rig)
keep.update(family(DONOR))
removed = 0
for o in list(D.objects):
    if o not in keep:
        D.objects.remove(o, do_unlink=True)
        removed += 1
for a in list(D.actions):
    D.actions.remove(a)
print("PRUNE: removed %d objects, %d left" % (removed, len(D.objects)), flush=True)


# ===========================================================================
# 2. clone the family once per man
# ===========================================================================
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
        n.name = strip_tag(o.name, src_tag) + "_" + dst_tag
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
    print("CLONE %-14s at x=%5.1f : %d meshes" % (dst_tag, new_x, len(mapping)), flush=True)
    return rig


RIG = {}
for t in TAGS:
    RIG[t] = clone_family(DONOR, t, LAYOUT[t])

# --- the stance -------------------------------------------------------------
# us_base_v3 parks its rigs on pose_position='REST' while their pose channels still hold
# the US rifleman's carry stance - 34 of 41 bones posed, with the hands closed around an
# M16. Two things are wrong with inheriting that here: these men do not carry an M16, and
# a rig sitting on REST with an invisible authored stance is FAILURE MODE 4 by definition
# (it also swings a Spine2-parented item ~44 cm off the body the moment anything flips it
# to POSE, which is why export_us_squad.py forces REST).
#
# So the stance is CLEARED rather than hidden: every channel back to identity, and
# pose_position set to POSE. The T-pose is then genuine - what you see is what the rig
# holds - the gear can be placed against a skeleton that will not move under it, and the
# pipeline's `pose_position == 'POSE'` gate reads true honestly instead of by omission.
for t in TAGS:
    rig = RIG[t]
    n = 0
    for pb in rig.pose.bones:
        pb.location = (0.0, 0.0, 0.0)
        pb.scale = (1.0, 1.0, 1.0)
        if pb.rotation_mode == 'QUATERNION':
            pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        else:
            pb.rotation_euler = (0.0, 0.0, 0.0)
        pb.matrix_basis = Matrix.Identity(4)
        n += 1
    rig.data.pose_position = 'POSE'
    upd()
print("STANCE: cleared the inherited US carry stance on all %d rigs (41 channels each) and "
      "set pose_position='POSE'. POSE now equals REST, so the T-pose is the real pose."
      % len(TAGS), flush=True)
# drop the donor family itself
for o in family(DONOR) + [base_rig]:
    D.objects.remove(o, do_unlink=True)
upd()


# ===========================================================================
# 3. strip the American kit
# ===========================================================================
for t in TAGS:
    gone = []
    for o in list(family(t)):
        b = strip_tag(o.name, t)
        if any(b.startswith(p) for p in STRIP):
            gone.append(b)
            D.objects.remove(o, do_unlink=True)
    print("STRIP US kit %-14s removed %2d: %s" % (t, len(gone), sorted(set(gone))), flush=True)
upd()


# ===========================================================================
# 4. WW1 gear - duplicate a stashed donor, place it, scale it to a MEASURED target
# ===========================================================================
def place(kind, tag, name, target_dims, centre, rot=None, canon=None):
    """Duplicate a stashed donor onto this man's rig and scale it to a measured box.

    target_dims / centre are in the RIG's local frame (rig at the origin), so the same
    numbers hold for every man however the lineup is laid out. Never writes a vertex.
    """
    rig = RIG[tag]
    src = STASH[kind]
    n = src.copy()
    n.data = src.data.copy()
    n.name = "%s_%s" % (name, tag)
    n.data.name = n.name
    link(n)
    if canon is not None:
        # The rod donor (officer_cigar) is held in a hand at an arbitrary angle, so its
        # world AABB is a diagonal blob and no world-axis scale can turn it into a thin
        # ridge or an upright spike - the first attempt produced (0.072, 0.139, 0.125)
        # for a wanted (0.022, 0.200, 0.026). Discard the donor's pose and stand the mesh
        # on a known axis first; only then does the box scale mean anything.
        n.matrix_world = canon
    else:
        # replay the donor's pose in this rig's frame
        n.matrix_world = (rig.matrix_world @ DONOR_RIG_MW[kind].inverted()) @ src.matrix_world
    upd()
    # measure what we have, then scale/translate it into the target box
    mn, mx = wbb([n])
    have = mx - mn
    if rot is not None:
        n.matrix_world = Matrix.Translation(rig.matrix_world.translation) @ rot @ \
            Matrix.Translation(-rig.matrix_world.translation) @ n.matrix_world
        upd()
        mn, mx = wbb([n])
        have = mx - mn
    # MEASURE, CORRECT, MEASURE AGAIN. One analytic scale is only exact if the first
    # measurement was exact; iterating converges whatever the depsgraph did and, more
    # importantly, the loop's exit condition IS the acceptance test for this piece.
    want_c = rig.matrix_world.translation + Vector(centre)
    got = have
    for it in range(8):
        s = Vector([(target_dims[i] / got[i]) if got[i] > 1e-6 else 1.0 for i in range(3)])
        cur_c = (mn + mx) * 0.5
        M = (Matrix.Translation(want_c)
             @ Matrix.Diagonal(s.to_4d())
             @ Matrix.Translation(-cur_c))
        n.matrix_world = M @ n.matrix_world
        upd()
        mn, mx = wbb([n])
        got = mx - mn
        err = max(abs(got[i] - target_dims[i]) for i in range(3))
        cerr = ((mn + mx) * 0.5 - want_c).length
        if err < 1e-4 and cerr < 1e-4:
            break
    if err > 1e-4 or cerr > 1e-4:
        raise SystemExit("ABORT %s/%s: after %d passes landed %s at centre off %.5f m, "
                         "wanted %s (err %.5f)"
                         % (tag, name, it + 1, tuple(round(v, 4) for v in got), cerr,
                            target_dims, err))
    return n, (mn, mx)


def bone_parent(o, tag, bone):
    rig = RIG[tag]
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


def setmat(o, mat):
    if not o.data.materials:
        o.data.materials.append(mat)
    else:
        for i in range(len(o.data.materials)):
            o.data.materials[i] = mat


def delete_by_material(o, needles):
    """Targeted polygon deletion - the ONLY mesh surgery in this file, and it removes a
    telescopic sight from a 1915 rifle. Islands, not vertices, and it is measured."""
    import bmesh
    idx = [i for i, m in enumerate(o.data.materials)
           if m and any(k in m.name for k in needles)]
    if not idx:
        return 0
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.faces.ensure_lookup_table()
    doomed = [f for f in bm.faces if f.material_index in idx]
    n = len(doomed)
    bmesh.ops.delete(bm, geom=doomed, context='FACES')
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context='VERTS')
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()
    return n


# ---- measured real-world targets ------------------------------------------
# kepi M1884: crown ~0.19 across, ~0.115 tall at the back, peak projecting ~0.05
# cerveliere: stamped steel bowl 0.5 mm thick, semi-spherical, three sizes
# Adrian M15: shell ~0.20 x 0.28 x 0.145 with a narrow all-round brim and a crown crest
# Pickelhaube M1895 (IWM object records): L 24-26.7 cm, W 16.5-19 cm, H 22-25 cm w/ spike
HEAD_TOP = 1.7999                    # measured top of the body mesh, rest space
KEPI = dict(dims=(0.190, 0.215, 0.118), c=(0.0, -0.012, 1.790))
CERV = dict(dims=(0.178, 0.190, 0.082), c=(0.0, -0.004, 1.878))
ADRIAN = dict(dims=(0.205, 0.278, 0.140), c=(0.0, -0.008, 1.786))
CREST = dict(dims=(0.022, 0.200, 0.026), c=(0.0, -0.008, 1.858))
PICK_DOME = dict(dims=(0.180, 0.200, 0.118), c=(0.0, -0.006, 1.782))
PICK_SPIKE = dict(dims=(0.032, 0.032, 0.105), c=(0.0, -0.006, 1.890))
PICK_PEAK = dict(dims=(0.170, 0.062, 0.016), c=(0.0, -0.104, 1.742))
PICK_NECK = dict(dims=(0.168, 0.070, 0.018), c=(0.0, 0.082, 1.740))
PICK_NUM = dict(dims=(0.056, 0.010, 0.040), c=(0.0, -0.086, 1.800))
# capote skirt: hem at mid-calf. Body knee sits near z 0.50; hem 0.42, top at the waist.
SKIRT_F = dict(dims=(0.360, 0.055, 0.640), c=(0.0, -0.112, 0.740))
SKIRT_B = dict(dims=(0.360, 0.055, 0.640), c=(0.0, 0.088, 0.740))

RX90 = Matrix.Rotation(math.radians(90), 4, 'X')
RZ180 = Matrix.Rotation(math.radians(180), 4, 'Z')
# canonical stances for the rod donor: its long axis is LOCAL +Z.
ROD_UP = Matrix.Identity(4)                    # spike: long axis -> world Z
ROD_FORE = Matrix.Rotation(math.radians(90), 4, 'X')   # crest: long axis -> world Y

for t in TAGS:
    spec = CAST[t]
    made = []

    # --- headgear ---------------------------------------------------------
    if spec["head"] == "kepi":
        crown = mat_flat("ww1_kepi_%s" % t, spec["kepi_rgb"])
        band = mat_flat("ww1_kepiband_%s" % t, spec["band_rgb"])
        o, obox = place("kepi", t, "kepi", KEPI["dims"], KEPI["c"])
        # the donor's two islands are crown and peak; peak goes leather-dark
        peak = mat_flat("ww1_peak_%s" % t, (34, 28, 24), rough=0.55)
        o.data.materials.clear()
        o.data.materials.append(crown)
        o.data.materials.append(peak)
        # lowest-lying polygons of the cap are its peak
        zs = [(p.index, (o.matrix_world @ p.center).z) for p in o.data.polygons]
        lo = min(z for _, z in zs)
        for i, z in zs:
            o.data.polygons[i].material_index = 1 if z < lo + 0.030 else 0
        npeak = sum(1 for p in o.data.polygons if p.material_index == 1)
        bone_parent(o, t, "mixamorig:Head")
        made.append(o)
        print("   %-14s kepi: %d polys (%d peak) measured world box %s, crown top z=%.3f"
              % (t, len(o.data.polygons), npeak,
                 tuple(round(v, 4) for v in (obox[1] - obox[0])), obox[1].z))
        if spec.get("cerveliere"):
            # "The brain-pan was a stamped steel skull-cap intended to be worn UNDER the
            # kepi. In actual use, the troops took to wearing them ON TOP for comfort."
            # (151e RI). So it sits on top of the kepi, which is also what makes it read.
            c, cbox = place("domecap", t, "cerveliere", CERV["dims"], CERV["c"])
            setmat(c, mat_flat("ww1_cerveliere_%s" % t, (96, 98, 100), rough=0.45, metal=0.55))
            bone_parent(c, t, "mixamorig:Head")
            made.append(c)
            print("   %-14s cerveliere ON TOP of the kepi: bowl %s, its underside z=%.3f "
                  "sits on the crown at z=%.3f"
                  % (t, tuple(round(v, 4) for v in (cbox[1] - cbox[0])), cbox[0].z, obox[1].z))

    elif spec["head"] == "adrian":
        h, hbox = place("adrian", t, "helmet_adrian", ADRIAN["dims"], ADRIAN["c"])
        setmat(h, mat_flat("ww1_adrian_%s" % t, spec["helm_rgb"], rough=0.55, metal=0.25))
        bone_parent(h, t, "mixamorig:Head")
        made.append(h)
        cr, crbox = place("rod", t, "helmet_crest", CREST["dims"], CREST["c"], canon=ROD_FORE)
        setmat(cr, mat_flat("ww1_adrian_%s" % t, spec["helm_rgb"], rough=0.55, metal=0.25))
        bone_parent(cr, t, "mixamorig:Head")
        made.append(cr)
        print("   %-14s Adrian M15: shell %s + crest %s (measured world boxes; real "
              "Adrian shell ~0.20 x 0.28 x 0.14 m)"
              % (t, tuple(round(v, 4) for v in (hbox[1] - hbox[0])),
                 tuple(round(v, 4) for v in (crbox[1] - crbox[0]))))

    elif spec["head"] == "pickelhaube":
        cov = mat_flat("ww1_uberzug_%s" % t, spec["helm_rgb"])
        d, dbox = place("domecap", t, "helmet_pickelhaube", PICK_DOME["dims"], PICK_DOME["c"])
        setmat(d, cov)
        bone_parent(d, t, "mixamorig:Head")
        made.append(d)
        sp, spbox = place("rod", t, "helmet_spike", PICK_SPIKE["dims"], PICK_SPIKE["c"], canon=ROD_UP)
        setmat(sp, cov)
        bone_parent(sp, t, "mixamorig:Head")
        made.append(sp)
        pkbox = {}
        for nm, box in (("helmet_peak", PICK_PEAK), ("helmet_neckguard", PICK_NECK)):
            pk, pkbox[nm] = place("strip", t, nm, box["dims"], box["c"])
            setmat(pk, cov)
            bone_parent(pk, t, "mixamorig:Head")
            made.append(pk)
        H = spbox[1].z - dbox[0].z
        L = pkbox["helmet_neckguard"][1].y - pkbox["helmet_peak"][0].y
        Wd = dbox[1].x - dbox[0].x
        print("   %-14s Pickelhaube+Ueberzug: overall H %.3f m (records 0.22-0.25), "
              "L front-peak to neck-guard %.3f m (records 0.24-0.267), shell W %.3f m "
              "(records 0.165-0.19)" % (t, H, L, Wd))
        if not (0.20 <= H <= 0.27 and 0.22 <= L <= 0.29 and 0.15 <= Wd <= 0.21):
            raise SystemExit("ABORT %s: Pickelhaube outside the measured record envelope "
                             "(H %.3f L %.3f W %.3f)" % (t, H, L, Wd))
        if spec.get("cover_number"):
            # Ueberzug regimental numbers were RED felt until 15 August 1914, then DARK
            # GREEN, and were deleted entirely on 27 October 1916 (kaisersbunker). A 1915
            # cover carries a green number or none - never red. The two Germans in this
            # set differ in exactly that way.
            nb, _ = place("plate", t, "helmet_number", PICK_NUM["dims"], PICK_NUM["c"], canon=ROD_UP)
            setmat(nb, mat_flat("ww1_uberzugnum_%s" % t, (38, 74, 44)))
            bone_parent(nb, t, "mixamorig:Head")
            made.append(nb)
            print("   %-14s Ueberzug number: GREEN (red was deleted 15 Aug 1914)" % t)
        else:
            print("   %-14s Ueberzug number: NONE - removed for front-line service" % t)

    # --- greatcoat skirt --------------------------------------------------
    if spec["skirt"]:
        cloth = mat_flat("ww1_coat_%s" % t, spec["coat_rgb"])
        for nm, box, rot in (("coat_skirt_f", SKIRT_F, None),
                             ("coat_skirt_b", SKIRT_B, RZ180)):
            sk, _ = place("skirt", t, nm, box["dims"], box["c"], rot=rot)
            setmat(sk, cloth)
            bone_parent(sk, t, "mixamorig:Hips")
            made.append(sk)
        print("   %-14s capote skirt: 2 panels, hem at z=%.3f (mid-calf), %d polys each"
              % (t, SKIRT_F["c"][2] - SKIRT_F["dims"][2] / 2,
                 len(made[-1].data.polygons)))

    # --- rifle ------------------------------------------------------------
    kind, length = spec["rifle"]
    r = STASH["rifle"].copy()
    r.data = STASH["rifle"].data.copy()
    r.name = "rifle_%s_%s" % (kind, t)
    r.data.name = r.name
    link(r)
    anchor = STASH["gunanchor"]
    r.matrix_world = (RIG[t].matrix_world @ DONOR_RIG_MW["gunanchor"].inverted()) \
        @ anchor.matrix_world @ (STASH["rifle"].matrix_world.inverted()
                                 @ STASH["rifle"].matrix_world)
    # place the rifle where the M16 hangs: same hand, same attitude
    r.matrix_world = (RIG[t].matrix_world @ DONOR_RIG_MW["gunanchor"].inverted()) \
        @ anchor.matrix_world
    upd()
    ndel = delete_by_material(r, ("ScopeSteel",))
    upd()
    mn, mx = wbb([r])
    have = (mx - mn).length
    long_axis = max(range(3), key=lambda i: (mx - mn)[i])
    k = length / (mx - mn)[long_axis]
    c = (mn + mx) * 0.5
    r.matrix_world = (Matrix.Translation(c) @ Matrix.Scale(k, 4)
                      @ Matrix.Translation(-c)) @ r.matrix_world
    upd()
    mn2, mx2 = wbb([r])
    got = (mx2 - mn2)[long_axis]
    if abs(got - length) > 1e-3:
        raise SystemExit("ABORT %s rifle: %.4f m, wanted %.4f" % (t, got, length))
    bone_parent(r, t, "mixamorig:RightHand")
    made.append(r)
    print("   %-14s rifle %-9s %d scope polys deleted, %d polys left, length %.4f m "
          "(real: %.3f m)" % (t, kind, ndel, len(r.data.polygons), got, length))

    # --- belt -------------------------------------------------------------
    belt = D.objects.get("web_belt_" + t)
    if belt:
        setmat(belt, mat_flat("ww1_belt_%s" % t, spec["belt_rgb"], rough=0.6))

    for o in made:
        o.hide_viewport = False
        o.hide_render = False
        o.hide_set(False)
upd()


# ===========================================================================
# 5. TEXTURES - the uniform painted into a copy of the shared atlas
# ===========================================================================
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
            raise SystemExit("ABORT %s: face island does not fit one atlas cell" % o.name)
        out[(col, row)] = True
    return out


def px(img):
    w, h = img.size
    return np.array(img.pixels[:], dtype=np.float32).reshape(h, w, img.channels)


def build_face_sheet(name, cell_png, meshes, out_png):
    from PIL import Image
    base = D.images["face_atlas_v5"]
    W, H = base.size
    a = px(base)
    donor = np.array(Image.open(cell_png).convert("RGB"), dtype=np.float32) / 255.0
    donor = donor[::-1]                       # PIL is top-down, image.pixels bottom-up
    cells = {}
    for o in meshes:
        for c in face_cells(o):
            cells.setdefault(c, []).append(o.name)
    if not cells:
        raise SystemExit("ABORT %s: no mesh samples a face atlas cell" % name)
    for (col, row), owners in sorted(cells.items()):
        x0, x1 = int(round(col * W / FACE_COLS)), int(round((col + 1) * W / FACE_COLS))
        y0, y1 = int(round(row * H / FACE_ROWS)), int(round((row + 1) * H / FACE_ROWS))
        th, tw = y1 - y0, x1 - x0
        src = donor
        if (src.shape[0], src.shape[1]) != (th, tw):
            yi = (np.arange(th) * (src.shape[0] / float(th))).astype(int).clip(0, src.shape[0] - 1)
            xi = (np.arange(tw) * (src.shape[1] / float(tw))).astype(int).clip(0, src.shape[1] - 1)
            src = src[yi][:, xi]
        # face_atlas_v5 is an sRGB byte image; image.pixels are the sRGB BYTES as floats
        # in this pipeline (build_cow_cast does the same), so no transfer is applied.
        a[y0:y1, x0:x1, :3] = src[:, :, :3]
        a[y0:y1, x0:x1, 3] = 1.0
        print("   %s: cell col=%d row_from_bottom=%d <- %s" % (name, col, row, sorted(owners)))
    tmp = D.images.new(name + "_tmp", W, H, alpha=True)
    tmp.pixels.foreach_set(np.ascontiguousarray(a, dtype=np.float32).ravel())
    tmp.filepath_raw = out_png
    tmp.file_format = 'PNG'
    tmp.save()
    D.images.remove(tmp)

    # TEXTURE BUDGET (Caleb's law): no embedded image over 1 MB. A straight 8-bit save of
    # this 1296x1132 sheet is 2.47 MB. QUANTISE FIRST, resolution second - that ordering
    # was measured tonight on the US cast (1024 sheet, 1.86 MB -> 832 KB with no detail
    # loss) and it holds here for the same reason: the sheet is 70 faces of skin tone, so
    # 256 colours costs almost nothing, whereas a resolution cut throws away the only part
    # anybody looks at. Resolution is only touched if quantising is not enough, and the
    # bytes are MEASURED at every step rather than estimated.
    LIMIT = 950_000
    im = Image.open(out_png).convert("RGB")
    w0, h0 = im.size
    steps = []
    for i in range(8):
        im.quantize(colors=256, method=Image.MEDIANCUT).save(out_png, optimize=True)
        nb = os.path.getsize(out_png)
        steps.append((im.size[0], im.size[1], nb))
        if nb <= LIMIT:
            break
        f = max(0.55, (float(LIMIT) / nb) ** 0.5 * 0.94)
        im = im.resize((max(64, int(im.size[0] * f)), max(64, int(im.size[1] * f))),
                       Image.LANCZOS)
    nb = os.path.getsize(out_png)
    if nb > LIMIT:
        raise SystemExit("ABORT %s: %.2f MB after %d passes, still over the 1 MB law"
                         % (name, nb / 1048576.0, len(steps)))

    # RELOAD from disk, then pack. Two traps in one line:
    #  * an image made with D.images.new() carries a FLOAT buffer and the glTF exporter
    #    writes it out as a 16-bit PNG - measured at 1.72 MB for a sheet that is 0.75 MB
    #    as an ordinary 8-bit file, which busts the law on its own;
    #  * the palettised bytes only survive export while the image stays an UNMODIFIED file
    #    reference. Calling image.scale() in-session makes Blender re-encode it as
    #    truecolour and the saving is lost. So the resizing happens in PIL, on disk,
    #    BEFORE Blender ever loads it.
    out = D.images.load(out_png)
    out.name = name
    out.pack()
    print("   %s: %dx%d -> %dx%d, %.0f KB palettised (256 colours, %d pass%s)"
          % (name, w0, h0, out.size[0], out.size[1], nb / 1024.0,
             len(steps), "" if len(steps) == 1 else "es"))
    return out


# --- the body/uniform sheet -------------------------------------------------
def body_region_mask(obj, W, H):
    """Rasterise the body's OWN UV polygons into a region label image.

    The regions are classified from REST-SPACE GEOMETRY, not from the UV bbox: the
    islands interleave on the sheet (arm u[0.039,0.465] and leg u[0.399,0.646] overlap),
    so a bbox recolour would paint a sleeve onto a trouser leg.
    """
    from PIL import Image, ImageDraw
    me = obj.data
    uv = me.uv_layers.active.data
    body_mi = [i for i, m in enumerate(me.materials)
               if m and not (m.name.startswith("face_atlas"))]
    REG = ["torso", "arm", "hip", "leg", "puttee", "boot"]
    lab = Image.new("L", (W, H), 0)
    dl = ImageDraw.Draw(lab)
    counts = {r: 0 for r in REG}
    for p in me.polygons:
        if p.material_index not in body_mi:
            continue
        vs = [me.vertices[vi].co for vi in p.vertices]
        z = sum(v.z for v in vs) / len(vs)
        x = sum(abs(v.x) for v in vs) / len(vs)
        if x > 0.135 and z > 1.25:
            r = "arm"
        elif z > 1.02:
            r = "torso"
        elif z > 0.80:
            r = "hip"
        elif z > 0.42:
            r = "leg"
        elif z > 0.13:
            r = "puttee"
        else:
            r = "boot"
        counts[r] += 1
        pts = [(uv[li].uv[0] * W, (1.0 - uv[li].uv[1]) * H) for li in p.loop_indices]
        dl.polygon(pts, fill=REG.index(r) + 1)
    return np.array(lab), REG, counts


def chest_front_uv(obj, W, H):
    """UV rect of the chest polygons that FACE FORWARD, for the button rows.

    Classified by the POLYGON NORMAL, never by vertex position: a rear polygon's edge
    verts sit forward of the form's midpoint and would take front-facing coordinates
    with them. The body faces -Y (the head mesh runs y[-0.132, 0.075]).
    """
    me = obj.data
    uv = me.uv_layers.active.data
    us, vs = [], []
    n = 0
    for p in me.polygons:
        c = p.center
        if not (1.05 < c.z < 1.50 and abs(c.x) < 0.14):
            continue
        if p.normal.y > -0.45:                    # not a forward-facing polygon
            continue
        n += 1
        for li in p.loop_indices:
            us.append(uv[li].uv[0])
            vs.append(uv[li].uv[1])
    if n < 3:
        raise SystemExit("ABORT: only %d forward-facing chest polygons found" % n)
    return (min(us), max(us), min(vs), max(vs)), n


def dump_source_atlas():
    """THE SOURCE ATLAS IS THE PACKED ONE, not the file its filepath points at.

    `us_grunt_mat` points at `assets/us/characters/recovered_ref_factions.png`, which
    exists at 11.7 MB and which PIL refused to open once during this build
    ("cannot identify image file") and opened on the next attempt. An intermittently
    readable file is not a source of truth. The living copy is the PACKED `ref_factions`
    datablock inside us_base_v3 - 123 objects use it and a project note records that the
    original was lost from disk and survives only because it is packed. Dump that.
    """
    im = D.images["ref_factions"]
    p = os.path.join(os.environ.get("TEMP", "."), "ww1_ref_factions_dump.png")
    fp, ff = im.filepath_raw, im.file_format
    im.filepath_raw, im.file_format = p, 'PNG'
    im.save()
    im.filepath_raw, im.file_format = fp, ff
    print("source atlas: PACKED `ref_factions` %dx%d -> %s (%.1f MB)"
          % (im.size[0], im.size[1], p, os.path.getsize(p) / 1048576.0), flush=True)
    return p


def build_uniform_sheet(tag, spec, obj, out_png):
    from PIL import Image
    src = Image.open(SHEET_SRC).convert("RGB").resize((SHEET_W, SHEET_H), Image.LANCZOS)
    a = np.array(src).astype(np.float32)
    lab, REG, counts = body_region_mask(obj, SHEET_W, SHEET_H)

    TARGET = {"torso": spec["coat_rgb"], "arm": spec["coat_rgb"], "hip": spec["coat_rgb"],
              "leg": spec["trou_rgb"], "puttee": spec["putt_rgb"], "boot": spec["boot_rgb"]}
    # DILATE each region before recolouring. The wrap has polygons that straddle the
    # sheet's own row divider (one upper-arm poly reaches into the "US MARINES" row), and
    # a texel exactly on an island edge otherwise samples un-recoloured olive drab.
    def dilate(m, k):
        out = m.copy()
        for _ in range(k):
            o2 = out.copy()
            o2[1:, :] |= out[:-1, :]
            o2[:-1, :] |= out[1:, :]
            o2[:, 1:] |= out[:, :-1]
            o2[:, :-1] |= out[:, 1:]
            out = o2
        return out

    painted = np.zeros((SHEET_H, SHEET_W), dtype=bool)
    rep = []
    for i, r in enumerate(REG):
        m = (lab == i + 1)
        if not m.any():
            continue
        md = dilate(m, 5) & ~painted
        lum = a[..., :3].mean(axis=2)
        base_l = float(lum[m].mean())
        tgt = np.array(TARGET[r], dtype=np.float32)
        # keep the photographic detail (pockets, folds, buttons, laces) and change only
        # the hue/value: FAILURE MODE 8 - a flat fill reads as an untextured mannequin.
        k = np.clip(lum[md] / max(base_l, 1.0), 0.55, 1.65)[:, None]
        a[md] = np.clip(tgt[None, :] * k, 0, 255)
        painted |= md
        rep.append((r, counts[r], int(m.sum()), int(md.sum()), base_l, TARGET[r]))

    # Everything the body never samples becomes one flat colour. It costs nothing to look
    # at and it makes the PNG compress to almost nothing, which is how this sheet stays
    # inside the 1 MB texture law at a usable resolution for the part that IS sampled.
    a[~painted] = np.array(spec["coat_rgb"], dtype=np.float32) * 0.55

    # --- double-breasted button rows -------------------------------------
    if spec["coat"] in ("double",):
        (u0, u1, v0, v1), nfront = chest_front_uv(obj, SHEET_W, SHEET_H)
        x0, x1 = u0 * SHEET_W, u1 * SHEET_W
        y0, y1 = (1.0 - v1) * SHEET_H, (1.0 - v0) * SHEET_H
        cx = (x0 + x1) * 0.5
        offs = (x1 - x0) * 0.19
        rad = max(1.6, (x1 - x0) * 0.052)
        dark = np.array([0.42, 0.40, 0.36], dtype=np.float32)
        yy, xx = np.mgrid[0:SHEET_H, 0:SHEET_W].astype(np.float32)
        nb = 0
        for side in (-1, 1):
            for j in range(6):
                by = y0 + (y1 - y0) * (0.13 + 0.145 * j)
                bx = cx + side * offs
                d = np.hypot(xx - bx, yy - by)
                m = d <= rad
                a[m] = np.clip(a[m] * dark[None, :], 0, 255)
                nb += 1
        print("   %-14s DOUBLE-BREASTED: %d buttons in 2 rows, %.1f px apart, r=%.1f px, "
              "on %d forward-facing chest polys (u[%.4f,%.4f] v[%.4f,%.4f])"
              % (tag, nb, 2 * offs, rad, nfront, u0, u1, v0, v1))

    Image.fromarray(a.astype(np.uint8)).save(out_png)
    # PALETTISE. Measured tonight on the US cast: quantising to 256 colours BEFORE
    # touching resolution took a 1024 sheet from 1.86 MB to 832 KB with no detail loss,
    # where a resolution cut would have thrown away the painted detail instead.
    before = os.path.getsize(out_png)
    Image.fromarray(a.astype(np.uint8)).quantize(colors=256, method=Image.MEDIANCUT) \
        .save(out_png, optimize=True)
    after = os.path.getsize(out_png)
    print("   %-14s uniform sheet %dx%d  %.0f KB -> %.0f KB palettised (256 colours)"
          % (tag, SHEET_W, SHEET_H, before / 1024.0, after / 1024.0))
    for r, npoly, npx, ndx, bl, col in rep:
        print("        %-7s %2d polys  %6d px (+%5d dilated)  src lum %5.1f -> RGB %s"
              % (r, npoly, npx, ndx - npx, bl, col))
    img = D.images.load(out_png)
    img.name = "ww1_%s_uniform" % tag
    img.pack()
    return img


print("\n=== TEXTURES ===", flush=True)
SHEET_SRC = dump_source_atlas()
for t in TAGS:
    spec = CAST[t]
    fam = family(t)
    body = D.objects["us_grunt_joined_" + t]

    # uniform: one sheet per man, its own material, repointed on every mesh that uses the
    # shared body material - including the hidden gib donors, so a severed arm matches.
    up = os.path.join(OUTDIR, "ww1_%s_uniform.png" % t)
    uimg = build_uniform_sheet(t, spec, body, up)
    umat = D.materials["us_grunt_mat"].copy()
    umat.name = "ww1_uniform_%s" % t
    for n in umat.node_tree.nodes:
        if n.type == 'TEX_IMAGE':
            n.image = uimg
            n.interpolation = 'Closest'
    hits = 0
    for o in fam:
        for i, m in enumerate(o.data.materials):
            if m and m.name.startswith("us_grunt_mat"):
                o.data.materials[i] = umat
                hits += 1
    if hits == 0:
        raise SystemExit("ABORT %s: no us_grunt_mat slot to repoint" % t)

    # face: the destination cell is MEASURED PER MESH (the visible body and the grunt_head
    # gib donor sample different cells, and every variant samples its own)
    fp = os.path.join(OUTDIR, "ww1_%s_face_atlas.png" % t)
    cell = os.path.join(OUTDIR, "ww1_%s_face_cell.png" % t)
    if not os.path.exists(cell):
        raise SystemExit("ABORT: run tools/build_ww1_face_cells.py first - missing %s" % cell)
    fimg = build_face_sheet("ww1_%s_face_atlas" % t, cell, fam, fp)
    fmat = D.materials["face_atlas_mat"].copy()
    fmat.name = "ww1_face_%s" % t
    for n in fmat.node_tree.nodes:
        if n.type == 'TEX_IMAGE':
            n.image = fimg
            n.interpolation = 'Closest'
    fh = 0
    for o in fam:
        for i, m in enumerate(o.data.materials):
            if m and m.name.startswith("face_atlas_mat"):
                o.data.materials[i] = fmat
                fh += 1
    if fh == 0:
        raise SystemExit("ABORT %s: no face_atlas_mat slot to repoint" % t)
    print("   %-14s uniform slots repointed %d | face slots repointed %d" % (t, hits, fh))

# drop the stashed donors and purge
for o in list(STASH.values()):
    D.objects.remove(o, do_unlink=True)
for blk in (D.meshes, D.armatures, D.materials, D.images):
    for x in list(blk):
        if x.users == 0:
            blk.remove(x)
upd()


# ===========================================================================
# 6. ACCEPTANCE GATES (psx-npc-pipeline section 5)
# ===========================================================================
fails = []
print("\n================ ACCEPTANCE GATES ================", flush=True)

PARTS = ["us_grunt_joined", "Base_Human", "grunt_head", "grunt_torso", "grunt_uparm_l",
         "grunt_uparm_r", "grunt_forearm_l", "grunt_forearm_r", "grunt_leg_l", "grunt_leg_r",
         "cap_head", "cap_torso", "cap_forearm_l", "cap_forearm_r", "cap_leg_l", "cap_leg_r",
         "cap_uparm_l", "cap_uparm_r"]
print("per-index RAW vertex hashes (not spans - FAILURE MODE 2):", flush=True)
for p in PARTS:
    hs = {}
    for t in TAGS:
        o = D.objects.get(p + "_" + t)
        if o:
            hs[t] = vhash(o)
    uniq = set(hs.values())
    ok = len(uniq) == 1 and len(hs) == len(TAGS)
    if not ok:
        fails.append("vertex hash mismatch on %s: %s" % (p, hs))
    print("   %-18s %-14s across %d/%d men  %s"
          % (p, list(uniq)[0] if len(uniq) == 1 else "MISMATCH", len(hs), len(TAGS),
             "OK" if ok else "FAIL"), flush=True)

for t in TAGS:
    o = D.objects["us_grunt_joined_" + t]
    xs = [v.co.x for v in o.data.vertices]
    span = max(xs) - min(xs)
    ok = abs(span - 1.6111) < 1e-3
    if not ok:
        fails.append("body raw X span %s = %.4f" % (t, span))
    print("body raw X span %-14s %.4f  %s" % (t, span, "OK" if ok else "FAIL"), flush=True)

# THE SMEAR GATE, and the two ways the pipeline's version of it is a broken instrument.
#
#  1. The flat "no evaluated X > 1.2 m" rule assumes a POSED character. This file is parked
#     in the studio T-pose, where the body legitimately spans its 1.6111 m arm span, so the
#     flat threshold fails a healthy mesh.
#  2. The obvious repair - "evaluated X must not exceed the mesh's own raw X span" - reads
#     `obj.dimensions`, which is the LOCAL bounding box times the object scale. On a
#     ROTATED object that number is meaningless. It failed all seven rifles here at
#     1.7129 m against a 1.1180 m raw span, on rifles measured to be exactly 1.306 m long
#     in world space. A gate that fails correct work is worse than no gate.
#
# So the test is split by what the object actually is. The body meshes are unrotated and
# unscaled, so their evaluated WORLD X extent must EQUAL their raw span - that is the true
# smear test and it is an equality, not a ceiling. The gear is deliberately rotated and
# non-uniformly scaled onto measured target boxes, so the equivalent test for it is that
# its vertex data is identical across all seven men (it is copied, never edited, except
# the rifle where whole polygons are deleted - identically, on every man).
BODY_BASES = set(PARTS)
worstx = (0.0, "-")
for t in TAGS:
    for o in family(t):
        base = strip_tag(o.name, t)
        if base not in BODY_BASES or not o.data.vertices:
            continue
        xs = [v.co.x for v in o.data.vertices]
        raw = max(xs) - min(xs)
        mn, mx = wbb([o])
        ev = mx.x - mn.x
        if abs(ev - raw) > 1.5e-3:
            fails.append("SMEAR? %s evaluated world X %.4f != raw span %.4f"
                         % (o.name, ev, raw))
        if ev > worstx[0]:
            worstx = (ev, o.name)
print("body meshes: max evaluated WORLD X extent %.4f m on %s - equals its raw span, which "
      "is the T-pose arm span and not smear" % (worstx[0], worstx[1]), flush=True)

gear_bases = {}
for t in TAGS:
    for o in family(t):
        b = strip_tag(o.name, t)
        if b in BODY_BASES:
            continue
        gear_bases.setdefault(b, {})[t] = vhash(o)
print("gear vertex hashes (identical geometry across every man who carries the piece):",
      flush=True)
for b in sorted(gear_bases):
    hs = gear_bases[b]
    uniq = set(hs.values())
    ok = len(uniq) == 1
    if not ok:
        fails.append("gear vertex hash mismatch on %s: %s" % (b, hs))
    print("   %-22s %-14s worn by %d/%d  %s"
          % (b, list(uniq)[0] if ok else "MISMATCH", len(hs), len(TAGS),
             "OK" if ok else "FAIL"), flush=True)

for t in TAGS:
    rig = RIG[t]
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
    # These are EUROPEAN soldiers on the US line body, so armature scale is 1.0. The
    # deliberate 0.952 belongs to the VC/NVA faction only and must not be applied here.
    ok = len(rig.data.bones) == 41 and s == (1.0, 1.0, 1.0)
    if not ok:
        fails.append("rig %s bones=%d scale=%s" % (t, len(rig.data.bones), s))
    print("rig %-14s bones=%d posed=%d pose_position=%s scale=%s  %s"
          % (t, len(rig.data.bones), posed, rig.data.pose_position, s,
             "OK" if ok else "FAIL"), flush=True)

for t in TAGS:
    bad_unw, bad_sum, bad_vg = 0, 0, []
    bones = {b.name for b in RIG[t].data.bones}
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
    print("weights %-14s sum min=%.4f max=%.4f  unweighted=%d  vgroups-without-bone=%d  %s"
          % (t, lo, hi, bad_unw, len(set(bad_vg)), "OK" if ok else "FAIL"), flush=True)

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
    print("visibility %-14s joined %d/%d visible | grunt_* %d/%d | cap_* %d/%d | "
          "head_frag_* %d/%d | Base_Human %d/%d  %s"
          % (t, jv, len(jo), sv, len(sp), cv, len(cp), hv, len(hf), bv, len(bh),
             "OK" if ok else "FAIL"), flush=True)

CAPS = ["cap_head", "cap_torso", "cap_forearm_l", "cap_forearm_r",
        "cap_leg_l", "cap_leg_r", "cap_uparm_l", "cap_uparm_r"]
for t in TAGS:
    miss = [c for c in CAPS if (c + "_" + t) not in D.objects]
    wrong = [c for c in CAPS if (c + "_" + t) in D.objects
             and not all(m and m.name == "gore_cap_mat"
                         for m in D.objects[c + "_" + t].data.materials)]
    if miss or wrong:
        fails.append("caps %s missing=%s wrongmat=%s" % (t, miss, wrong))
    print("gore caps %-14s %d/%d present, all on gore_cap_mat: %s  %s"
          % (t, len(CAPS) - len(miss), len(CAPS), not wrong,
             "OK" if not (miss or wrong) else "FAIL"), flush=True)


def dotted(x):
    return len(x.name) > 4 and x.name[-4] == "." and x.name[-3:].isdigit()


coll = ["%s:%s" % (lbl, x.name)
        for blk, lbl in ((D.objects, "object"), (D.meshes, "mesh"), (D.images, "image"))
        for x in blk if dotted(x)]
if coll:
    fails.append("name collisions: %s" % coll)
print("name collisions in objects/meshes/images: %d %s"
      % (len(coll), coll if coll else ""), flush=True)
matdots = sorted(x.name for x in D.materials if dotted(x))
print("dotted MATERIAL names inherited from us_base_v3 (reported, not a failure): %s"
      % matdots, flush=True)

# TEXTURE BUDGET. The law is about what SHIPS, so the gate walks the materials actually
# on each man's meshes and only judges those images. The first version of this gate judged
# every image datablock in the file and failed on eight inherited us_base_v3 sheets
# (ref_us_kit, ref_vc_nva, us_pilot_atlas...) that no WW1 mesh references and that no WW1
# export will embed - a gate failing on somebody else's asset tells you nothing.
def images_used_by(objs):
    out = {}
    for o in objs:
        for m in o.data.materials:
            if not m or not m.use_nodes:
                continue
            for n in m.node_tree.nodes:
                if n.type == 'TEX_IMAGE' and n.image and n.image.size[0]:
                    out.setdefault(n.image, set()).add(m.name)
    return out


print("TEXTURE BUDGET - images reachable from each man's own materials:", flush=True)
shipping = {}
for t in TAGS:
    for im, mats in images_used_by(family(t)).items():
        shipping.setdefault(im, set()).update(mats)
for im in sorted(shipping, key=lambda i: -(i.size[0] * i.size[1])):
    fp = bpy.path.abspath(im.filepath) if im.filepath else ""
    nb = os.path.getsize(fp) if fp and os.path.exists(fp) else -1
    flag = ""
    if nb > 1048576:
        flag = "  <-- OVER 1 MB"
        fails.append("shipping image over 1MB: %s (%.2f MB) used by %s"
                     % (im.name, nb / 1048576.0, sorted(shipping[im])[:3]))
    print("   %-30s %5dx%-5d %8.0f KB  <- %s%s"
          % (im.name, im.size[0], im.size[1], nb / 1024.0 if nb > 0 else 0,
             sorted(shipping[im])[0], flag), flush=True)
unused = [im.name for im in D.images
          if im.size[0] and im not in shipping]
print("   inherited us_base_v3 images still in the file but on NO ww1 mesh (they do not "
      "ship): %s" % sorted(unused), flush=True)

print("visible tri counts and STATURE (the shipping state - donors hidden):", flush=True)
ngon_owner = {}
for t in TAGS:
    vis = [o for o in family(t) if not o.hide_get()]
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in vis)
    for o in vis:
        n = sum(1 for p in o.data.polygons if len(p.vertices) > 4)
        if n:
            ngon_owner[strip_tag(o.name, t)] = n
    ngons = sum(1 for o in vis for p in o.data.polygons if len(p.vertices) > 4)
    # STATURE is measured over the body and what he WEARS, never over the rifle: a 1.3 m
    # weapon held in a T-pose hand adds most of a metre to the raw bbox and the first
    # version of this line reported all seven men as 2.67 m tall. Same exclusion rule
    # export_us_squad.py uses (ADR-002).
    worn = [o for o in vis if "rifle_" not in o.name]
    mnw, mxw = wbb(worn)
    body = [o for o in vis if o.name.startswith("us_grunt_joined")]
    mnb, mxb = wbb(body)
    mna, mxa = wbb(vis)
    print("   %-14s %2d meshes  %5d tris  %d n-gons | bare body %.4f m | top of headgear "
          "%.4f m | with rifle %.4f m"
          % (t, len(vis), tris, ngons, mxb.z - mnb.z, mxw.z - mnw.z, mxa.z - mna.z),
          flush=True)
# N-GONS: reported by owner, not swept under a total. Both sources are INHERITED donor
# geometry, not anything authored here, and the glTF export triangulates
# (export_apply=True) so nothing n-gonned reaches the engine - but a checklist item that
# says "no n-gons" deserves the actual list rather than a number.
print("   n-gons by piece (all inherited donor geometry; export triangulates): %s"
      % (ngon_owner if ngon_owner else "none"), flush=True)

print("=================================================", flush=True)
if fails:
    print("GATE FAILURES (%d) - REFUSING TO SAVE:" % len(fails), flush=True)
    for f in fails:
        print("   ! " + f, flush=True)
    raise SystemExit(1)
print("ALL GATES PASS", flush=True)


# ===========================================================================
# 7. save (never over the source)
# ===========================================================================
if os.path.normcase(os.path.abspath(OUT)) == os.path.normcase(os.path.abspath(SRC)):
    raise SystemExit("ABORT: refusing to write over us_base_v3.blend")
bpy.context.preferences.filepaths.save_version = 0        # no .blend1 (Caleb's rule)
bpy.ops.wm.save_as_mainfile(filepath=OUT, compress=True)
print("SAVED %s  (%.1f MB)" % (OUT, os.path.getsize(OUT) / 1048576.0), flush=True)
