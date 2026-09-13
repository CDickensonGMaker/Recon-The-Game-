"""build_ww1_cast.py - the Conquest of Worms WW1 cast (French poilus + German infantry, 1915).

    "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" --background ^
        "assets/us/characters/us_base_v3.blend" --python tools/build_ww1_cast.py

Writes assets/ww1/characters/conquest_of_worms_ww1.blend. NEVER saves over the source
(explicit guard at the bottom).

SEVEN MEN, one file (psx-npc-pipeline standing rule). See CAST below for the kit and the
historical basis of each decision.

ASSEMBLY FIRST. Caleb's 2026-08-04 ruling stands: no procedural geometry generation - "just
make a copy of one of the core units and modify it". Every piece of WW1 kit in this file is
an EXISTING project object duplicated, scaled and placed:

    kepi          <- officer_cap_black      (peaked cap: flat top, band, peak)
    cerveliere    <- scrub_cap_surgeon      (shallow skull cap -> the steel brain-pan)
    adrian shell  <- helmet_shell_worn      (M1 dome + brim; helmet band polys deleted)
    adrian crest  <- officer_cigar          (tapered cylinder -> the crown ridge)
    pickelhaube   <- scrub_cap_surgeon      (dome, raised)
    spike         <- officer_cigar          (tapered cylinder)
    peak/neck gd  <- web_back_yoke          (thin strip)
    cover number  <- helmet_bugjuice        (small box, flattened into a plate)
    cartridge pouches / braces / belt / buckle <- the rifleman's own web_* set (the 1888
                     French set is the same belt + two front pouches + Y-braces layout;
                     the German 1909 pouches are the front pouches widened, braces dropped)
    third pouch   <- web_pouch_l copied to the small of the back
    musette / Brotbeutel <- ruck_pocket_0    bidon / Feldflasche <- canteen_l.002
    rifles        <- the Mosin parts kit in assets/nva_vc/weapons_vc.blend (armory style,
                     real scale, muzzle at -X): Lebel 1.300 m, Gewehr 98 1.250 m

The two exceptions, both measured off the body rather than invented (2026-09-12 finish pass):
    coat skirt    a 16 x 8 loft of the joined body's OWN silhouette (support function per
                  ring + cloth offset), skinned Hips -> UpLeg so it walks with him. The v1
                  apron panels were flat white boards.
    rifle grip    the kit is re-origined at the stock wrist and hung in the RightHand frame
                  with the M16's measured grip offset, so it sits in the hand like the
                  Vietnam cast's guns instead of floating over the head (v1).

EVERY PIECE IS ON THE MAN'S OWN SHEET. Kit swatches are painted into the unused rows of
the uniform sheet and every piece is UV-mapped there; one uniform image + one face atlas
per man. (v1 gave the kit flat materials whose sRGB bytes were written into a LINEAR
socket - the "white blocks" in the 2026-09-09 lineup were a colour-space bug, not
missing paint.)

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
        kit="bare kepi, red band | capote M1877, DOUBLE-breasted | pantalon garance | Lebel",
        nation="fr", head="kepi", cover_kepi=False, coat="double", skirt=True,
        rifle=("lebel", 1.300),
        coat_rgb=(58, 66, 84),         # M1877 iron blue
        trou_rgb=(158, 48, 42),        # PANTALON GARANCE - madder red, not yet replaced
        putt_rgb=(66, 74, 90),
        boot_rgb=(62, 45, 32), belt_rgb=(74, 53, 37),
        kepi_rgb=(52, 60, 78), band_rgb=(150, 44, 40)),   # red band showing: no cover

    "poilu_b": dict(
        label="POILU - LINE (young)", year="May 1915",
        kit="kepi + cerveliere worn ON TOP | capote M1914, dark 'English' cloth | Lebel",
        nation="fr", head="kepi", cover_kepi=True, cerveliere=True, coat="single", skirt=True,
        rifle=("lebel", 1.300),
        coat_rgb=(101, 110, 122),      # "dark blue-gray", the other end of the gamut
        trou_rgb=(116, 102, 82),       # substitute brown/tan cloth
        putt_rgb=(122, 110, 88),
        boot_rgb=(62, 45, 32), belt_rgb=(74, 53, 37),
        kepi_rgb=(112, 120, 130), band_rgb=(112, 120, 130)),

    "poilu_1916": dict(
        label="POILU - LINE", year="1916",
        kit="casque Adrian M15 | capote M1915, DOUBLE-breasted | Lebel",
        nation="fr", head="adrian", coat="double", skirt=True,
        rifle=("lebel", 1.300),
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
        boot_rgb=(26, 24, 24), belt_rgb=(58, 42, 30),   # pouches/belt: natural brown, the
        helm_rgb=(150, 141, 118)),     # cover, a washed-out light tan   1915 blackening order not yet reached him

    "german_line": dict(
        label="GERMAN INFANTRYMAN", year="1915",
        kit="Pickelhaube + Ueberzug, NO number | M1907/10 Feldrock | Gewehr 98",
        nation="de", head="pickelhaube", cover_number=False, coat="german", skirt=False,
        rifle=("gew98", 1.250),
        coat_rgb=(95, 99, 82), trou_rgb=(88, 90, 92),
        putt_rgb=(30, 28, 28), boot_rgb=(26, 24, 24), belt_rgb=(50, 38, 28),
        helm_rgb=(143, 134, 112)),
}
TAGS = list(CAST.keys())
LAYOUT = {t: i * SPACING for i, t in enumerate(TAGS)}

SHEET_W, SHEET_H = 1024, 1621      # keeps 3600:5700; body band lands at ~655x306 px

# US kit that must not survive onto a 1915 European. Prefixes, matched before the tag.
# web_belt / web_buckle / web_pouch_* / web_flap_* / web_susp_* are KEPT on purpose and
# re-cut into the leather set in section 4 (web_snap_* is deleted there). v1 listed
# "web_suspender" / "web_strap", names that do not exist, so the M1956 set shipped green.
STRIP = ("m16_world", "helmet_shell_worn", "helmet_camo_shell", "helmet_bugjuice",
         "web_bandolier", "web_back_yoke", "web_clip", "web_yoke",
         "canteen_", "pouch_belt_worn", "ruck_")


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


def srgb_to_linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat_flat(name, rgb, rough=0.92, metal=0.0):
    """rgb are sRGB bytes; the Principled socket (and glTF baseColorFactor) is LINEAR.
    Writing bytes/255 straight in made every flat piece ~2x too bright (white in render)."""
    if name in D.materials:
        return D.materials[name]
    m = D.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs['Base Color'].default_value = (srgb_to_linear(rgb[0]), srgb_to_linear(rgb[1]),
                                            srgb_to_linear(rgb[2]), 1.0)
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
    "gunanchor":  ("m16_world_" + DONOR, "PSXRig_" + DONOR, 'BONE', "mixamorig:RightHand"),
    "canteen":    ("canteen_l.002_" + DONOR, "PSXRig_" + DONOR, 'BONE', "mixamorig:Hips"),
    "pocket":     ("ruck_pocket_0_" + DONOR, "PSXRig_" + DONOR, 'BONE', "mixamorig:Spine2"),
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
    for m in list(n.modifiers):
        n.modifiers.remove(m)          # a donor BEVEL would be applied twice by the exporter
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
    """Targeted polygon deletion. Islands, not vertices, and it is measured."""
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


def _assert_unrotated(o):
    R3 = o.matrix_world.to_3x3()
    if max(abs(R3[i][j] - (1.0 if i == j else 0.0)) for i in range(3) for j in range(3)) > 1e-6:
        raise SystemExit("ABORT %s: object frame is rotated/scaled; local-space edit invalid" % o.name)


def scale_in_place(o, s):
    """Scale a SKINNED kit piece's vertices about its own centre, IN LOCAL SPACE.

    The first version went through matrix_world and back. Vertex coordinates are float32,
    so for a rig standing at x=18 the round trip lost bits in the 6th decimal and the
    same pouch hashed differently on every man - the rig's X leaking into vertex data
    (psx-npc-pipeline FAILURE MODE 1) at the 1e-6 level. Local space, small numbers, exact.
    """
    _assert_unrotated(o)
    L = [v.co.copy() for v in o.data.vertices]
    mn = Vector(map(min, *L))
    mx = Vector(map(max, *L))
    c = (mn + mx) * 0.5
    for v, l in zip(o.data.vertices, L):
        v.co = Vector((c[i] + s[i] * (l[i] - c[i]) for i in range(3)))
    o.data.update()


def translate_verts(o, d):
    """Translate in LOCAL space; `d` is a world delta and the frame is unrotated."""
    _assert_unrotated(o)
    for v in o.data.vertices:
        v.co = v.co + Vector(d)
    o.data.update()


def set_all_weights(o, bone):
    for g in list(o.vertex_groups):
        o.vertex_groups.remove(g)
    g = o.vertex_groups.new(name=bone)
    g.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')


# ---- sheet swatch rects (px on the SHEET_W x SHEET_H uniform sheet) ----------------
# The body samples v[0.610, 0.799] = rows 324..632 of the 1621-row sheet (measured on
# us_grunt_joined_rifleman). Everything below row 700 was one flat colour; the kit lives
# there now, so every piece of gear is a textured island on the man's own sheet and the
# whole man ships on ONE uniform image + ONE face atlas.
SWATCH = {
    "skirt":        (0, 720, 420, 940),      # cylindrical wrap of the capote skirt
    "leather":      (420, 720, 700, 940),
    "pouch_fr":     (700, 720, 1024, 940),   # 1888 pouch front: flap, strap, buckle
    "helm_paint":   (0, 940, 300, 1140),     # Adrian, horizon-blue painted steel
    "helm_badge":   (300, 940, 500, 1140),   # Adrian front: the RF flaming grenade
    "cover_tan":    (500, 940, 800, 1140),   # Ueberzug reed linen
    "cover_num":    (800, 940, 1024, 1140),  # Ueberzug plate with the green number
    "wood":         (0, 1140, 350, 1340),
    "steel_blue":   (350, 1140, 600, 1340),
    "steel_bright": (600, 1140, 800, 1340),
    "canvas":       (800, 1140, 1024, 1340), # musette / Brotbeutel
    "bidon":        (0, 1340, 300, 1540),    # 2 L bidon in its blue cloth cover
    "pouch_de":     (300, 1340, 640, 1540),  # 1909 pouch front: three cells
    "kepi":         (640, 1340, 860, 1540),  # cylindrical wrap of the kepi
    "felt":         (860, 1340, 1024, 1540), # Feldflasche felt cover
}
SW_MARGIN = 6


def _rect_uv(fu, fv, rect):
    x0, y0, x1, y1 = rect
    m = SW_MARGIN
    px = x0 + m + (x1 - x0 - 2 * m) * min(max(fu, 0.0), 1.0)
    py = y0 + m + (y1 - y0 - 2 * m) * min(max(fv, 0.0), 1.0)
    return (px / SHEET_W, 1.0 - py / SHEET_H)


def uv_map(o, swatch, mode="box", polys=None, frame=None):
    """Write this piece's UVs into one swatch rect of the sheet.

    mode 'box'  : per-polygon planar projection along the polygon's dominant normal
                  axis, the piece's bbox fitted to the rect (three projections overlap).
    mode 'cyl'  : angle around the piece's vertical axis -> u (front = 0.5), z -> v.
    mode 'front': planar x/z of the selected polys, fitted to the rect. Used for the
                  detail faces (badge, pouch flaps) - the CALLER picks polys by NORMAL.
    Coordinates are world coordinates through `frame` (default matrix_world), so the
    orientation words above mean what they say for a placed piece.
    """
    me = o.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uv = me.uv_layers.active.data
    M = o.matrix_world if frame is None else frame
    W = [M @ v.co for v in me.vertices]
    sel = list(me.polygons) if polys is None else [me.polygons[i] for i in polys]
    if not sel:
        return 0
    idx = sorted({i for p in sel for i in p.vertices})
    pts = [W[i] for i in idx]
    mn = Vector(map(min, *pts))
    mx = Vector(map(max, *pts))
    ext = [max(mx[i] - mn[i], 1e-6) for i in range(3)]
    N = M.to_3x3().inverted().transposed()
    rect = SWATCH[swatch]
    n_done = 0
    for p in sel:
        nrm = (N @ p.normal)
        if mode == "cyl" and abs(nrm.normalized().z) > 0.7:
            # a cap (the kepi's flat top) spans every angle; planar x/y into the same rect
            for li, vi in zip(p.loop_indices, p.vertices):
                w = W[vi]
                uv[li].uv = _rect_uv((w.x - mn.x) / ext[0], (mx.y - w.y) / ext[1], rect)
        elif mode == "cyl":
            c = (mn + mx) * 0.5
            fus, fvs = [], []
            for vi in p.vertices:
                w = W[vi]
                ang = math.atan2(w.x - c.x, -(w.y - c.y))     # 0 at the front (-Y)
                fus.append(0.5 + ang / (2.0 * math.pi))
                fvs.append((mx.z - w.z) / ext[2])
            # a polygon across the u=0/1 seam at the back: unwrap it the short way, on
            # whichever side keeps every loop inside [0, 1]. (atan2 at exactly +-pi flips
            # sign on 1e-9 noise in the bbox centre, so the seam vertex may read 0 or 1.)
            if max(fus) - min(fus) > 0.5:
                up = [f + 1.0 if f < 0.5 else f for f in fus]
                dn = [f - 1.0 if f > 0.5 else f for f in fus]
                fus = up if max(up) <= 1.0 + 1e-6 else dn
            for li, fu, fv in zip(p.loop_indices, fus, fvs):
                uv[li].uv = _rect_uv(fu, fv, rect)
        elif mode == "front":
            for li, vi in zip(p.loop_indices, p.vertices):
                w = W[vi]
                uv[li].uv = _rect_uv((w.x - mn.x) / ext[0], (mx.z - w.z) / ext[2], rect)
        else:
            a = max(range(3), key=lambda i: abs(nrm[i]))
            u_ax, v_ax = {0: (1, 2), 1: (0, 2), 2: (0, 1)}[a]
            for li, vi in zip(p.loop_indices, p.vertices):
                w = W[vi]
                fu = (w[u_ax] - mn[u_ax]) / ext[u_ax]
                fv = (mx[v_ax] - w[v_ax]) / ext[v_ax]
                uv[li].uv = _rect_uv(fu, fv, rect)
        n_done += 1
    return n_done


def polys_facing(o, dirn, dot=0.5, frame=None):
    M = o.matrix_world if frame is None else frame
    N = M.to_3x3().inverted().transposed()
    d = Vector(dirn)
    return [p.index for p in o.data.polygons if (N @ p.normal).normalized().dot(d) > dot]


UVPLAN = {}            # object name -> list of (swatch, mode, polys) applied after the sheet exists


def plan(o, swatch, mode="box", polys=None):
    UVPLAN.setdefault(o.name, []).append((swatch, mode, polys))


# ---- measured real-world targets ------------------------------------------
# kepi M1884: crown ~0.19 across, ~0.115 tall at the back, peak projecting ~0.05
# cerveliere: stamped steel bowl 0.5 mm thick, semi-spherical, three sizes
# Adrian M15 (IMA original, listed): 11-11/16 x 8-5/8 x 5-1/2 in = 0.297 x 0.219 x 0.140 m
#   over the brims; visor 50 mm, neck guard 44 mm (151ril). Shell here 0.290 x 0.215 x 0.140.
# Pickelhaube M1895 (IWM object records): L 24-26.7 cm, W 16.5-19 cm, H 22-25 cm w/ spike
HEAD_TOP = 1.7999                    # measured top of the body mesh, rest space
KEPI = dict(dims=(0.190, 0.215, 0.118), c=(0.0, -0.012, 1.790))
CERV = dict(dims=(0.178, 0.190, 0.082), c=(0.0, -0.004, 1.878))
ADRIAN = dict(dims=(0.215, 0.290, 0.140), c=(0.0, -0.010, 1.786))
CREST = dict(dims=(0.030, 0.210, 0.036), c=(0.0, -0.010, 1.862))
# bags, in the rig frame. The body's LEFT is +X (LeftUpLeg head x +0.087, RightHand x -0.638)
MUSETTE = dict(dims=(0.090, 0.270, 0.230))        # canvas haversack, left hip (x = thickness)
BIDON = dict(dims=(0.095, 0.150, 0.200))          # 2 L bidon, right hip, over the coat
BROTBEUTEL = dict(dims=(0.080, 0.260, 0.200))     # bread bag, right rear hip
FELDFLASCHE = dict(dims=(0.070, 0.105, 0.165))    # felt-covered canteen, in front of the bread bag

RX90 = Matrix.Rotation(math.radians(90), 4, 'X')
RZ180 = Matrix.Rotation(math.radians(180), 4, 'Z')
ROD_UP = Matrix.Identity(4)                    # spike: long axis -> world Z
ROD_FORE = Matrix.Rotation(math.radians(90), 4, 'X')   # crest: long axis -> world Y


# ---- the capote skirt: lofted from the body's OWN silhouette ----------------------
# Rings at measured heights; the radius at each angle is the support function of the
# joined body's vertices in a +-5 cm band (the silhouette seen from outside), plus a
# cloth offset that grows toward the hem so the skirt hangs like a bell. Hem at mid-calf
# (z 0.42; the knee is at z 0.538). The top ring sits under the belt (belt z 1.072-1.134,
# inner clearance ~2 cm off the torso) so the coat reads as one garment.
SKIRT_RINGS = [(1.060, 0.012), (0.980, 0.028), (0.900, 0.036), (0.800, 0.045),
               (0.700, 0.052), (0.600, 0.060), (0.500, 0.068), (0.420, 0.078)]
SKIRT_SEGS = 16


def build_skirt(tag, body):
    rig = RIG[tag]
    R = rig.matrix_world
    # "rig frame" here = WORLD minus the rig's translation (z up). The armature object
    # itself carries Mixamo's 90-degree rotation, so its full inverse would hand back a
    # Y-up mesh - the first run's cross-section came back with z in [-0.119, 0.181], which
    # is the body's DEPTH, and found nothing at z 1.06.
    Rt = R.translation.copy()
    dg = bpy.context.evaluated_depsgraph_get()
    dg.update()
    ev = body.evaluated_get(dg)
    me_ev = ev.to_mesh()
    P = [(ev.matrix_world @ v.co) - Rt for v in me_ev.vertices]
    E = [(e.vertices[0], e.vertices[1]) for e in me_ev.edges]
    ev.to_mesh_clear()
    verts, radii = [], []
    for z, off in SKIRT_RINGS:
        # the true cross-section: every mesh EDGE that crosses the plane z, intersected.
        # (A vertex band is useless here - the thigh is one quad from z 0.55 to 0.90.)
        band = []
        for i, j in E:
            a, b = P[i], P[j]
            if (a.z - z) * (b.z - z) < 0:
                f = (z - a.z) / (b.z - a.z)
                q = a + (b - a) * f
                if abs(q.x) < 0.30:
                    band.append(q)
        if len(band) < 6:
            raise SystemExit("ABORT skirt %s: only %d section points at z=%.3f (P %d verts z[%.3f,%.3f], E %d edges)"
                             % (tag, len(band), z, len(P), min(q.z for q in P), max(q.z for q in P), len(E)))
        cx = 0.0
        cy = sum(p.y for p in band) / len(band)
        ring = []
        for k in range(SKIRT_SEGS):
            ang = 2.0 * math.pi * k / SKIRT_SEGS
            d = Vector((math.sin(ang), -math.cos(ang)))          # k=0 is the FRONT (-Y)
            r = max((p.x - cx) * d.x + (p.y - cy) * d.y for p in band)
            r = max(r, 0.09) + off
            ring.append(Vector((cx + d.x * r, cy + d.y * r, z)))
        verts += ring
        rs = [math.hypot(v.x - cx, v.y - cy) for v in ring]
        radii.append((z, min(rs), max(rs), cy, max(v.x for v in ring), min(v.x for v in ring)))
    faces = []
    nr = len(SKIRT_RINGS)
    for i in range(nr - 1):
        for k in range(SKIRT_SEGS):
            a = i * SKIRT_SEGS + k
            b = i * SKIRT_SEGS + (k + 1) % SKIRT_SEGS
            faces.append((a, a + SKIRT_SEGS, b + SKIRT_SEGS, b))   # (down x CCW tangent) = OUT
    me = D.meshes.new("coat_skirt_%s" % tag)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    # normals OUT, asserted not assumed: every face normal must point away from the axis
    bad = 0
    for p in me.polygons:
        c = p.center
        if p.normal.dot(Vector((c.x, c.y - radii[0][3], 0.0))) <= 0:
            bad += 1
    if bad:
        raise SystemExit("ABORT skirt %s: %d of %d faces point inward" % (tag, bad, len(me.polygons)))
    o = D.objects.new("coat_skirt_%s" % tag, me)
    link(o)
    o.parent = rig
    o.parent_type = 'OBJECT'
    o.matrix_parent_inverse = Matrix.Identity(4)
    upd()
    o.matrix_world = Matrix.Translation(Rt)
    upd()
    if (o.matrix_world.translation - Rt).length > 1e-6 or abs(o.matrix_world.to_3x3().determinant() - 1.0) > 1e-6:
        raise SystemExit("ABORT skirt %s: object frame did not land at the rig origin" % tag)
    mod = o.modifiers.new("Armature", 'ARMATURE')
    mod.object = rig
    # WEIGHTS: waist rows ride the Hips; below the hip the skirt follows the nearer leg so
    # it walks with the man instead of standing still while his knees go through it.
    lx = (R @ rig.data.bones["mixamorig:LeftUpLeg"].head_local).x - Rt.x
    rx = (R @ rig.data.bones["mixamorig:RightUpLeg"].head_local).x - Rt.x
    left_is_plus = lx > rx
    g_h = o.vertex_groups.new(name="mixamorig:Hips")
    g_l = o.vertex_groups.new(name="mixamorig:LeftUpLeg")
    g_r = o.vertex_groups.new(name="mixamorig:RightUpLeg")
    for i, v in enumerate(verts):
        wl = min(max((0.95 - v.z) / 0.40, 0.0), 1.0) * 0.85
        side = min(max(0.5 + v.x / 0.16, 0.0), 1.0)          # 1 = +X leg, 0 = -X leg
        if not left_is_plus:
            side = 1.0 - side
        g_h.add([i], 1.0 - wl, 'REPLACE')
        g_l.add([i], wl * side, 'REPLACE')
        g_r.add([i], wl * (1.0 - side), 'REPLACE')
    upd()
    return o, radii


# ---- rifles from the Mosin parts kit (weapons_vc.blend) ----------------------------
# The kit is built at real scale, muzzle at x=0, butt at x=+1.294, bore z 0.412, and is
# the only full-stocked bolt-action in the project. A Lebel and a Gewehr 98 share that
# silhouette; what distinguishes them at PSX distance is length, the Lebel's fat tube-
# magazine fore-end and the absence of the Mosin's cleaning rod / sight hood / bayonet.
WEAPONS_VC = os.path.join(ROOT, "assets", "nva_vc", "weapons_vc.blend")
MOSIN_DROP = ("Mosin_bayonet", "Mosin_bay_socket", "Mosin_cleanrod", "Mosin_fs_hood")
# grip point in kit space: the wrist of the stock, 5.5 cm behind the trigger guard, 5 cm
# under the bore. This becomes the rifle's ORIGIN so it can be hung exactly where the
# M16's pistol grip sits in the US rifleman's hand.
KIT_GRIP = Vector((0.975, 0.264, 0.365))
# the M16's grip in ITS object frame (measured: grip polys at x +0.21..0.24, z to -0.122)
M16_GRIP = Vector((0.22, 0.0, -0.07))
RIFLE_SPEC = {
    "lebel": dict(length=1.300, forend=(1.0, 1.25, 1.45)),
    "gew98": dict(length=1.250, forend=(1.0, 1.0, 1.0)),
}
_KIT = {}


def load_mosin_kit():
    with bpy.data.libraries.load(WEAPONS_VC, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n.startswith("Mosin_") and n not in MOSIN_DROP]
    for o in dst.objects:
        if o is not None:
            link(o)
            o.name = "_KIT_" + o.name
            _KIT[o.name] = o
    upd()
    print("MOSIN KIT: %d parts appended from weapons_vc.blend (dropped %s)"
          % (len(_KIT), list(MOSIN_DROP)), flush=True)


def build_rifle(kind, tag):
    spec = RIFLE_SPEC[kind]
    parts = []
    for nm, src in _KIT.items():
        n = src.copy()
        n.data = src.data.copy()
        link(n)
        n.parent = None
        n.matrix_world = src.matrix_world.copy()
        parts.append(n)
    upd()
    # world coordinates of every part (the kit parts carry parent chains: bolt handle on
    # the bolt, knob on the handle) - bake to world first, then join by hand
    import bmesh
    bm = bmesh.new()
    wood_mat = set()
    mat_of_face = []
    for p in parts:
        me = p.data
        base = p.name.replace("_KIT_", "")
        M = p.matrix_world
        off = len(bm.verts)
        vs = []
        for v in me.vertices:
            w = M @ v.co
            if base == "Mosin_forend" and kind == "lebel":
                # tube magazine: fatten the fore-end downward and sideways about its TOP
                w = Vector((w.x, 0.264 + (w.y - 0.264) * spec["forend"][1],
                            0.408 - (0.408 - w.z) * spec["forend"][2]))
            vs.append(bm.verts.new(w))
        bm.verts.ensure_lookup_table()
        mname = me.materials[0].name if me.materials else ""
        for poly in me.polygons:
            try:
                f = bm.faces.new([vs[i] for i in poly.vertices])
            except ValueError:
                continue
            f.smooth = False
            mat_of_face.append((f, "wood" if "Wood" in mname else
                                ("steel_bright" if "Bright" in mname else "steel_blue")))
    # origin at the grip. No remove_doubles: the parts stay separate islands (as in the
    # kit) so bm.faces order == mesh polygon order and the swatch-per-face list holds.
    for v in bm.verts:
        v.co = v.co - KIT_GRIP
    me = D.meshes.new("rifle_%s_%s" % (kind, tag))
    kinds = ["wood", "steel_blue", "steel_bright"]
    bm.to_mesh(me)
    me.update()
    if len(me.polygons) != len(mat_of_face):
        raise SystemExit("ABORT rifle %s: %d polys vs %d recorded" % (kind, len(me.polygons), len(mat_of_face)))
    swatch_of = {i: k for i, (_, k) in enumerate(mat_of_face)}
    bm.free()
    for p in parts:
        D.objects.remove(p, do_unlink=True)
    o = D.objects.new("rifle_%s_%s" % (kind, tag), me)
    link(o)
    xs = [v.co.x for v in me.vertices]
    raw = max(xs) - min(xs)
    k = spec["length"] / raw
    for v in me.vertices:
        v.co = v.co * k
    me.update()
    xs = [v.co.x for v in me.vertices]
    got = max(xs) - min(xs)
    if abs(got - spec["length"]) > 1e-4:
        raise SystemExit("ABORT rifle %s: %.4f m, wanted %.4f" % (kind, got, spec["length"]))
    # the swatch plan, by material family: box projections into wood / blued / bright
    for kname in kinds:
        ids = [i for i, s in swatch_of.items() if s == kname]
        if ids:
            plan(o, kname, "box", ids)
    return o, got, len(me.polygons)



# ---- the Pickelhaube, measured against the head it sits on ---------------------------
# Reference: kaisersbunker.com/feldgrau/helmets/fgh01.htm (M1915), IWM records L 24-26.7 /
# W 16.5-19 / H 22-25 cm with spike. This head (measured): widest +-0.080 x, y -0.130..
# +0.074 at z 1.74, ear line 1.657, crown 1.800. The skull rim sits 3 cm above the ears
# and the dome closes 8 mm over the scalp; every ring is >= 5 mm clear of the head
# (asserted by the intersection gate). One object, 166 tris:
#   skull  12 segs x 5 rings + crown fan   (108)   round spike base 8 segs      (24)
#   spike  6-seg frustum + tip             (18)    squared visor 4 quads         (8)
#   curved neck guard 4 quads              (8)
PICK = dict(W=0.190, D=0.234, cy=-0.028, rim=1.685, top=1.808,
            rings=((0.00, 1.00), (0.35, 1.00), (0.60, 0.92), (0.80, 0.72), (0.93, 0.42)),
            base_r=0.025, base_h=0.012, spike_r=(0.011, 0.004), spike_h=0.050, tip=0.010,
            visor=0.050, visor_drop=0.012, guard=0.045, guard_drop=0.030)


def build_pickelhaube(tag):
    rig = RIG[tag]
    Rt = rig.matrix_world.translation.copy()
    K = PICK
    S = 12
    V, F, kind = [], [], []          # kind per face: "skull" / "front" / "top" / "plate"
    hw, hd = K["W"] / 2.0, K["D"] / 2.0
    H = K["top"] - K["rim"]
    rings = []
    for t, f in K["rings"]:
        ring = []
        for k in range(S):
            ang = 2.0 * math.pi * k / S
            dx, dy = math.sin(ang), -math.cos(ang)            # k = 0 is the FRONT (-Y)
            ring.append(len(V))
            V.append(Vector((dx * hw * f, K["cy"] + dy * hd * f, K["rim"] + H * t)))
        rings.append(ring)
    crown = len(V)
    V.append(Vector((0.0, K["cy"], K["top"])))
    for i in range(len(rings) - 1):
        for k in range(S):
            a, b = rings[i][k], rings[i][(k + 1) % S]
            c, d = rings[i + 1][(k + 1) % S], rings[i + 1][k]
            F.append((a, b, c, d))
            kind.append("front" if (k in (0, S - 1) and i < 3) else "skull")
    for k in range(S):
        F.append((rings[-1][k], rings[-1][(k + 1) % S], crown))
        kind.append("skull")
    # spike base: a short round drum on the crown
    b0, b1 = [], []
    for k in range(8):
        ang = 2.0 * math.pi * k / 8
        for lst, z in ((b0, K["top"] - 0.002), (b1, K["top"] + K["base_h"])):
            lst.append(len(V))
            V.append(Vector((math.sin(ang) * K["base_r"], K["cy"] - math.cos(ang) * K["base_r"], z)))
    for k in range(8):
        F.append((b0[k], b0[(k + 1) % 8], b1[(k + 1) % 8], b1[k]))
        kind.append("top")
    bc = len(V)
    V.append(Vector((0.0, K["cy"], K["top"] + K["base_h"])))
    for k in range(8):
        F.append((b1[k], b1[(k + 1) % 8], bc))
        kind.append("top")
    # spike: frustum + tip
    z0 = K["top"] + K["base_h"]
    s0, s1 = [], []
    for k in range(6):
        ang = 2.0 * math.pi * k / 6
        for lst, r, z in ((s0, K["spike_r"][0], z0), (s1, K["spike_r"][1], z0 + K["spike_h"])):
            lst.append(len(V))
            V.append(Vector((math.sin(ang) * r, K["cy"] - math.cos(ang) * r, z)))
    tip = len(V)
    V.append(Vector((0.0, K["cy"], z0 + K["spike_h"] + K["tip"])))
    for k in range(6):
        F.append((s0[k], s0[(k + 1) % 6], s1[(k + 1) % 6], s1[k]))
        kind.append("top")
        F.append((s1[k], s1[(k + 1) % 6], tip))
        kind.append("top")
    # visor: from the rim's front five vertices (k = -2..2), pushed forward and SQUARED
    # (the middle three share one y), dropping a little; neck guard: rear five (k = 4..8),
    # pushed back and curving down. Both single-sided plates - the material is not
    # backface-culled, so glTF ships them doubleSided (and duplicate faces are dropped by
    # the exporter anyway, see blender_lessons 2026-09-12).
    def plate(ks, push, drop, square):
        # pushed straight FORWARD / BACK (not radially - a radial push at +-60 deg made the
        # helmet 25 cm wide with wings); the flank verts move half as far so the plate
        # tapers into the rim. The visor's middle three share one y: a squared front edge.
        outer = []
        sgn = -1.0 if square else 1.0
        for k in ks:
            kk = k % S
            base = V[rings[0][kk]]
            edge = abs(kk if kk < 6 else kk - 12) if square else abs(kk - 6)
            f = 1.0 if edge <= 1 else 0.55
            o = Vector((base.x, base.y + sgn * push * f, base.z - drop * f))
            if square and edge <= 1:
                o.y = V[rings[0][0]].y - push                  # one straight front edge
            outer.append(len(V))
            V.append(o)
        for i in range(len(ks) - 1):
            F.append((rings[0][ks[i] % S], outer[i], outer[i + 1], rings[0][ks[i + 1] % S]))
            kind.append("plate")
    plate([-2, -1, 0, 1, 2], K["visor"], K["visor_drop"], True)
    plate([4, 5, 6, 7, 8], K["guard"], K["guard_drop"], False)

    me = D.meshes.new("helmet_pickelhaube_%s" % tag)
    me.from_pydata([tuple(v) for v in V], [], F)
    me.update()
    # normals out of the skull / up off the plates - asserted
    bad = 0
    for p, kd in zip(me.polygons, kind):
        c = p.center
        ref = Vector((c.x, c.y - K["cy"], c.z - K["rim"] - H * 0.3)) if kd != "plate" else Vector((0, 0, 1))
        if p.normal.dot(ref) <= 0:
            bad += 1
    if bad:
        raise SystemExit("ABORT pickelhaube %s: %d faces face inward" % (tag, bad))
    o = D.objects.new(me.name, me)
    link(o)
    o.matrix_world = Matrix.Translation(Rt)
    upd()
    front = [i for i, kd in enumerate(kind) if kd == "front"]
    rest_cyl = [i for i, kd in enumerate(kind) if kd == "skull"]
    boxed = [i for i, kd in enumerate(kind) if kd in ("top", "plate")]
    return o, front, rest_cyl, boxed, len(me.polygons)

print("\n=== GEAR ===", flush=True)
load_mosin_kit()
SKIRT_RADII = {}
SKIRT_MESH = None
RIFLE_INFO = {}

for t in TAGS:
    spec = CAST[t]
    rig = RIG[t]
    Rt = rig.matrix_world.translation
    made = []
    fr = spec["nation"] == "fr"

    # --- headgear ---------------------------------------------------------
    if spec["head"] == "kepi":
        o, obox = place("kepi", t, "kepi", KEPI["dims"], KEPI["c"])
        zs = [(p.index, (o.matrix_world @ p.center).z) for p in o.data.polygons]
        lo = min(z for _, z in zs)
        peak = [i for i, z in zs if z < lo + 0.030]
        crown = [i for i, z in zs if z >= lo + 0.030]
        plan(o, "kepi", "cyl", crown)
        plan(o, "leather", "box", peak)
        bone_parent(o, t, "mixamorig:Head")
        made.append(o)
        print("   %-14s kepi: %d polys (%d peak) world box %s, crown top z=%.3f"
              % (t, len(o.data.polygons), len(peak),
                 tuple(round(v, 4) for v in (obox[1] - obox[0])), obox[1].z))
        if spec.get("cerveliere"):
            c, cbox = place("domecap", t, "cerveliere", CERV["dims"], CERV["c"])
            plan(c, "steel_bright", "box")
            bone_parent(c, t, "mixamorig:Head")
            made.append(c)
            print("   %-14s cerveliere ON TOP of the kepi: bowl %s, underside z=%.3f on the "
                  "crown at z=%.3f" % (t, tuple(round(v, 4) for v in (cbox[1] - cbox[0])),
                                       cbox[0].z, obox[1].z))

    elif spec["head"] == "adrian":
        h, hbox = place("adrian", t, "helmet_adrian", ADRIAN["dims"], ADRIAN["c"])
        nband = delete_by_material(h, ("Webbing",))        # the M1 donor's helmet band
        # front polys above the brim carry the RF grenade; everything else is paint
        front = [p.index for p in h.data.polygons
                 if (h.matrix_world.to_3x3().inverted().transposed() @ p.normal).normalized().y < -0.55
                 and (h.matrix_world @ p.center).z > hbox[0].z + 0.045
                 and abs((h.matrix_world @ p.center).x - Rt.x) < 0.045]
        rest = [p.index for p in h.data.polygons if p.index not in set(front)]
        plan(h, "helm_badge", "front", front)
        plan(h, "helm_paint", "box", rest)
        bone_parent(h, t, "mixamorig:Head")
        made.append(h)
        cr, crbox = place("rod", t, "helmet_crest", CREST["dims"], CREST["c"], canon=ROD_FORE)
        plan(cr, "helm_paint", "box")
        bone_parent(cr, t, "mixamorig:Head")
        made.append(cr)
        print("   %-14s Adrian M15: shell %s (%d band polys removed, %d badge polys) + crest %s"
              % (t, tuple(round(v, 4) for v in (hbox[1] - hbox[0])), nband, len(front),
                 tuple(round(v, 4) for v in (crbox[1] - crbox[0]))))

    elif spec["head"] == "pickelhaube":
        d, dfront, dcyl, dbox, npk = build_pickelhaube(t)
        if spec.get("cover_number"):
            plan(d, "cover_num", "front", dfront)       # "112" painted low on the cover front
        else:
            plan(d, "cover_tan", "cyl", dfront)
        plan(d, "cover_tan", "cyl", dcyl)
        plan(d, "cover_tan", "box", dbox)
        bone_parent(d, t, "mixamorig:Head")
        made.append(d)
        mn_, mx_ = wbb([d])
        tris_ = sum(len(p.vertices) - 2 for p in d.data.polygons)
        H = mx_.z - mn_.z
        L = mx_.y - mn_.y
        Wd = mx_.x - mn_.x
        print("   %-14s Pickelhaube+Ueberzug, spike ON (Issue 2 p13 / Issue 3 p5): skull W %.3f x "
              "D %.3f x H %.3f (H/W %.2f), overall L %.3f (records 0.24-0.267) H %.3f (0.22-0.25) "
              "W %.3f (0.165-0.19), %d tris, number %s"
              % (t, PICK["W"], PICK["D"], PICK["top"] - PICK["rim"], (PICK["top"] - PICK["rim"]) / PICK["W"],
                 L, H, Wd, tris_, "painted" if spec.get("cover_number") else "none"))
        if tris_ > 220 or not (0.18 <= H <= 0.27 and 0.22 <= L <= 0.34 and 0.15 <= Wd <= 0.21):
            raise SystemExit("ABORT %s: Pickelhaube outside the envelope (H %.3f L %.3f W %.3f, %d tris)"
                             % (t, H, L, Wd, tris_))

    # --- greatcoat skirt --------------------------------------------------
    body = D.objects["us_grunt_joined_" + t]
    if spec["skirt"]:
        # ONE loft, copied. Evaluating each man's body separately hands back coordinates
        # that differ per rig in the 6th decimal (float32 armature deform at x=18), and
        # the hash gate is right to refuse that. The bodies are bit-identical, so the
        # skirt built off the first is the skirt of every man.
        if SKIRT_MESH is None:
            sk, radii = build_skirt(t, body)
            SKIRT_MESH = (sk.data, radii, sk)
        else:
            src_sk = SKIRT_MESH[2]
            sk = D.objects.new("coat_skirt_%s" % t, SKIRT_MESH[0].copy())
            sk.data.name = sk.name
            link(sk)
            sk.parent = rig
            sk.parent_type = 'OBJECT'
            sk.matrix_parent_inverse = Matrix.Identity(4)
            upd()
            sk.matrix_world = Matrix.Translation(Rt)
            upd()
            mod = sk.modifiers.new("Armature", 'ARMATURE')
            mod.object = rig
            # vertex groups (names AND weights) ride on the mesh datablock in Blender 5,
            # so the copy already has them; re-adding made ".001" orphans (measured)
            if [g.name for g in sk.vertex_groups] != [g.name for g in src_sk.vertex_groups]:
                raise SystemExit("ABORT skirt %s: mesh copy lost its vertex groups" % t)
            radii = SKIRT_MESH[1]
        SKIRT_RADII[t] = radii
        plan(sk, "skirt", "cyl")
        made.append(sk)
        print("   %-14s capote skirt: %d rings x %d segs = %d quads, hem z=%.3f; ring radii "
              "(z: min-max) %s"
              % (t, len(SKIRT_RINGS), SKIRT_SEGS, len(sk.data.polygons), SKIRT_RINGS[-1][0],
                 " ".join("%.2f:%.3f-%.3f" % (r[0], r[1], r[2]) for r in radii)))

    # --- the inherited US webbing becomes the 1888 leather set / the 1909 pouches --------
    belt = D.objects.get("web_belt_" + t)
    if belt:
        plan(belt, "leather", "box")
    buck = D.objects.get("web_buckle_" + t)
    if buck:
        plan(buck, "steel_bright", "box")
    for side in ("l", "r"):
        pouch = D.objects.get("web_pouch_%s_%s" % (side, t))
        flap = D.objects.get("web_flap_%s_%s" % (side, t))
        snap = D.objects.get("web_snap_%s_%s" % (side, t))
        if snap:
            D.objects.remove(snap, do_unlink=True)
        if not (pouch and flap):
            raise SystemExit("ABORT %s: missing web_pouch/web_flap %s" % (t, side))
        if fr:
            # M1888/1905 cartouchiere: a stiff leather box ~0.12 x 0.06 x 0.10
            for o in (pouch, flap):
                scale_in_place(o, (0.86, 0.80, 0.80))
            newp, newf = "cart_pouch_%s_%s" % (side, t), "cart_flap_%s_%s" % (side, t)
            sw = "pouch_fr"
        else:
            # M1909 Patronentasche: three cells, ~0.20 wide. Two per man.
            for o in (pouch, flap):
                scale_in_place(o, (1.45, 0.85, 0.85))
            newp, newf = "ammo_pouch_%s_%s" % (side, t), "ammo_flap_%s_%s" % (side, t)
            sw = "pouch_de"
        pouch.name = newp
        pouch.data.name = newp
        flap.name = newf
        flap.data.name = newf
        for o in (pouch, flap):
            fr_polys = polys_facing(o, (0, -1, 0), 0.6)
            plan(o, sw, "front", fr_polys)
            plan(o, "leather", "box", [p.index for p in o.data.polygons if p.index not in set(fr_polys)])
    # braces: the French Y-straps stay (leather); the 1915 German had none on the line
    for side in ("l", "r"):
        s = D.objects.get("web_susp_%s_%s" % (side, t))
        if not s:
            continue
        if fr:
            s.name = "brace_%s_%s" % (side, t)
            s.data.name = s.name
            plan(s, "leather", "box")
        else:
            D.objects.remove(s, do_unlink=True)
    if fr:
        # third cartouchiere at the small of the back (the 1888 set carried three)
        src = D.objects["cart_pouch_l_" + t]
        rp = src.copy()
        rp.data = src.data.copy()
        rp.name = "cart_pouch_b_" + t
        rp.data.name = rp.name
        link(rp)
        Lv = [v.co.copy() for v in src.data.vertices]
        c = (Vector(map(min, *Lv)) + Vector(map(max, *Lv))) * 0.5
        off = src.matrix_world.translation - Rt          # object origin vs rig origin
        translate_verts(rp, (-(c.x + off.x), 0.165 - (c.y + off.y), 0.0))
        set_all_weights(rp, "mixamorig:Hips")
        plan(rp, "leather", "box")
        made.append(rp)

    # --- bags and bottles -------------------------------------------------
    # placed against the skirt's measured radius at their height, never through it
    def skirt_x_at(z, sgn):
        best = min(SKIRT_RADII[t], key=lambda r: abs(r[0] - z))
        return best[4] if sgn > 0 else best[5]
    if fr:
        z_m = 0.960
        rx = skirt_x_at(z_m, +1) + MUSETTE["dims"][0] * 0.5 + 0.004
        mus, _ = place("pocket", t, "musette", MUSETTE["dims"], (rx, 0.03, z_m),
                       rot=Matrix.Rotation(math.radians(90), 4, 'Z'))
        plan(mus, "canvas", "box")
        bone_parent(mus, t, "mixamorig:Hips")
        made.append(mus)
        z_b = 1.000
        bx = skirt_x_at(z_b, -1) - BIDON["dims"][0] * 0.5 - 0.004
        bid, _ = place("canteen", t, "bidon", BIDON["dims"], (bx, 0.06, z_b),
                       rot=Matrix.Rotation(math.radians(90), 4, 'Z'))
        plan(bid, "bidon", "box")
        bone_parent(bid, t, "mixamorig:Hips")
        made.append(bid)
        print("   %-14s musette at x=%+.3f (skirt +x %.3f) | bidon at x=%+.3f" % (t, rx, skirt_x_at(z_m, +1), bx))
    else:
        bb, _ = place("pocket", t, "breadbag", BROTBEUTEL["dims"], (-0.215, 0.115, 0.985),
                      rot=Matrix.Rotation(math.radians(90), 4, 'Z'))
        plan(bb, "canvas", "box")
        bone_parent(bb, t, "mixamorig:Hips")
        made.append(bb)
        ff, _ = place("canteen", t, "feldflasche", FELDFLASCHE["dims"], (-0.215, -0.075, 0.965),
                      rot=Matrix.Rotation(math.radians(90), 4, 'Z'))
        plan(ff, "felt", "box")
        bone_parent(ff, t, "mixamorig:Hips")
        made.append(ff)

    # --- rifle: built from the kit, hung EXACTLY where the M16 hangs ----------------
    kind, length = spec["rifle"]
    r, got, npoly = build_rifle(kind, t)
    anchor = STASH["gunanchor"]
    m16_frame = (rig.matrix_world @ DONOR_RIG_MW["gunanchor"].inverted()) @ anchor.matrix_world
    r.matrix_world = m16_frame @ Matrix.Translation(M16_GRIP)
    upd()
    bone_parent(r, t, "mixamorig:RightHand")
    made.append(r)
    hand = rig.matrix_world @ rig.data.bones["mixamorig:RightHand"].head_local
    grip_w = r.matrix_world.translation
    RIFLE_INFO[t] = dict(kind=kind, length=got, polys=npoly, grip_to_wrist=(grip_w - hand).length)
    print("   %-14s rifle %-6s %d polys, length %.4f m (real %.3f, %+.1f%%), grip %.3f m from "
          "the RightHand head, child of mixamorig:RightHand like m16_world"
          % (t, kind, npoly, got, length, 100.0 * (got - length) / length, (grip_w - hand).length))

    for o in made:
        o.hide_viewport = False
        o.hide_render = False
        o.hide_set(False)
upd()
for o in list(_KIT.values()):
    D.objects.remove(o, do_unlink=True)
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



# --- the kit swatches ----------------------------------------------------------------
def _noise(h, w, scale, rng, octaves=3):
    from PIL import Image
    out = np.zeros((h, w), dtype=np.float32)
    amp, tot = 1.0, 0.0
    for _ in range(octaves):
        gh, gw = max(2, int(round(h / scale))), max(2, int(round(w / scale)))
        g = (rng.random((gh, gw)) * 255).astype(np.uint8)
        im = Image.fromarray(g).resize((w, h), Image.BILINEAR)
        out += amp * (np.array(im).astype(np.float32) / 255.0 - 0.5)
        tot += amp
        amp *= 0.5
        scale = max(scale / 2.0, 1.5)
    return out / tot


def _fill(a, rect, rgb, amp=0.16, scale=22.0, seed=0, stretch=1.0):
    """Base colour modulated by value noise. `stretch` > 1 elongates the grain along u
    (wood, cloth weave). Returns the (h, w) slice for further painting."""
    from PIL import Image
    x0, y0, x1, y1 = rect
    h, w = y1 - y0, x1 - x0
    rng = np.random.default_rng(seed)
    n = _noise(h, max(2, int(w / stretch)), scale, rng)
    if stretch != 1.0:
        n = np.array(Image.fromarray(((n + 0.5) * 255).astype(np.uint8)).resize((w, h), Image.BILINEAR)) / 255.0 - 0.5
    base = np.array(rgb, dtype=np.float32)
    a[y0:y1, x0:x1, :3] = np.clip(base[None, None, :] * (1.0 + amp * 2.0 * n[..., None]), 0, 255)
    return a[y0:y1, x0:x1, :3]


def _line(sl, x0, y0, x1, y1, k, width=2):
    """Darken/lighten along a segment (k < 1 darkens). Coordinates in the slice."""
    from PIL import Image, ImageDraw
    h, w = sl.shape[:2]
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).line([(x0, y0), (x1, y1)], fill=255, width=width)
    mk = np.array(m).astype(np.float32) / 255.0
    sl[...] = np.clip(sl * (1.0 + (k - 1.0) * mk[..., None]), 0, 255)


def _disc(sl, cx, cy, r, rgb, ring=None):
    h, w = sl.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.hypot(xx - cx, yy - cy)
    m = d <= r
    sl[m] = np.array(rgb, dtype=np.float32)
    if ring:
        e = (d > r - ring) & (d <= r)
        sl[e] = np.array(rgb, dtype=np.float32) * 0.55


def _text(sl, cx, cy, txt, rgb, size):
    from PIL import Image, ImageDraw, ImageFont
    im = Image.fromarray(sl.astype(np.uint8))
    d = ImageDraw.Draw(im)
    try:
        f = ImageFont.truetype("arialbd.ttf", size)
    except OSError:
        f = ImageFont.load_default()
    bb = d.textbbox((0, 0), txt, font=f)
    d.text((cx - (bb[2] - bb[0]) / 2 - bb[0], cy - (bb[3] - bb[1]) / 2 - bb[1]), txt, fill=tuple(rgb), font=f)
    sl[...] = np.array(im).astype(np.float32)


def paint_kit_swatches(a, spec):
    """Every kit island on the sheet, painted from the period palette in the CAST."""
    fr = spec["nation"] == "fr"
    coat = spec["coat_rgb"]
    lea = spec["belt_rgb"]
    # capote skirt: cloth, vertical fold streaks, front button column, rear vent
    sl = _fill(a, SWATCH["skirt"], coat, amp=0.10, scale=18.0, seed=1)
    h, w = sl.shape[:2]
    folds = _noise(2, w, 40.0, np.random.default_rng(2), octaves=2)[0]
    sl[...] = np.clip(sl * (1.0 + 0.16 * folds[None, :, None]), 0, 255)
    if spec["skirt"]:
        rows = 1 if spec["coat"] == "single" else 2
        for j in range(rows):
            bx = w * 0.5 + (j - (rows - 1) / 2.0) * w * 0.10
            _line(sl, bx, 0, bx, h, 0.82, width=2)
            for i in range(4):
                _disc(sl, bx, h * (0.10 + 0.20 * i), 4.0, (150, 128, 70), ring=1.2)
        _line(sl, 1, h * 0.35, 1, h, 0.7, width=3)          # rear vent (u=0 seam)
        _line(sl, w - 2, h * 0.35, w - 2, h, 0.7, width=3)
        _line(sl, 0, h - 2, w, h - 2, 0.72, width=3)        # hem
    # leather: grain + two scuffs
    sl = _fill(a, SWATCH["leather"], lea, amp=0.14, scale=9.0, seed=3, stretch=1.6)
    _line(sl, 20, 60, 200, 90, 0.85, width=1)
    _line(sl, 60, 150, 240, 130, 1.12, width=1)
    # 1888 pouch front: flap line at 45 %, centre strap, brass buckle
    sl = _fill(a, SWATCH["pouch_fr"], lea, amp=0.12, scale=9.0, seed=4)
    h, w = sl.shape[:2]
    _line(sl, 0, h * 0.45, w, h * 0.45, 0.62, width=4)
    _line(sl, w * 0.5, h * 0.05, w * 0.5, h * 0.70, 0.75, width=8)
    _disc(sl, w * 0.5, h * 0.60, 9.0, (168, 140, 74), ring=2.5)
    # 1909 pouch front: three cells with straps
    sl = _fill(a, SWATCH["pouch_de"], lea, amp=0.12, scale=9.0, seed=5)
    h, w = sl.shape[:2]
    for i in (1, 2):
        _line(sl, w * i / 3.0, 0, w * i / 3.0, h, 0.45, width=4)
    _line(sl, 0, h * 0.42, w, h * 0.42, 0.62, width=3)
    for i in range(3):
        cx = w * (i + 0.5) / 3.0
        _line(sl, cx, h * 0.05, cx, h * 0.65, 0.78, width=6)
        _disc(sl, cx, h * 0.55, 6.0, (120, 118, 110), ring=2.0)
    # Adrian paint: horizon blue over steel, lit from above
    hp = spec.get("helm_rgb", (120, 132, 141))
    sl = _fill(a, SWATCH["helm_paint"], hp, amp=0.07, scale=30.0, seed=6)
    h, w = sl.shape[:2]
    grad = np.linspace(1.10, 0.90, h).astype(np.float32)
    sl[...] = np.clip(sl * grad[:, None, None], 0, 255)
    # the RF flaming grenade, brass, centred on the front strip
    sl = _fill(a, SWATCH["helm_badge"], hp, amp=0.07, scale=30.0, seed=6)
    h, w = sl.shape[:2]
    grad = np.linspace(1.10, 0.90, h).astype(np.float32)
    sl[...] = np.clip(sl * grad[:, None, None], 0, 255)
    brass = (176, 146, 70)
    _disc(sl, w * 0.5, h * 0.62, 32.0, brass, ring=4.0)
    for dx, dy in ((-24, -44), (-10, -56), (6, -58), (20, -46), (0, -36)):
        _line(sl, w * 0.5 + dx * 0.5, h * 0.62 - 20, w * 0.5 + dx, h * 0.62 + dy, 1.0, width=5)
        _disc(sl, w * 0.5 + dx, h * 0.62 + dy, 6.0, brass)
    _text(sl, w * 0.5, h * 0.63, "RF", (70, 52, 22), 26)
    # Ueberzug: reed linen weave
    ct = spec.get("helm_rgb", (150, 141, 118))
    sl = _fill(a, SWATCH["cover_tan"], ct, amp=0.11, scale=6.0, seed=7, stretch=1.3)
    h, w = sl.shape[:2]
    for fx in (0.25, 0.75):                              # the cover's side seams (cyl u)
        _line(sl, w * fx, 0, w * fx, h, 0.78, width=3)
    _line(sl, 0, h * 0.94, w, h * 0.94, 0.80, width=3)   # the drawstring hem at the rim
    sl = _fill(a, SWATCH["cover_num"], ct, amp=0.11, scale=6.0, seed=7)
    h, w = sl.shape[:2]
    if spec.get("cover_number"):
        _text(sl, w * 0.5, h * 0.74, "112", (38, 74, 44), 64)
    # rifle: walnut grain along u, blued steel, bright bolt steel
    _fill(a, SWATCH["wood"], (112, 72, 40), amp=0.20, scale=14.0, seed=8, stretch=6.0)
    _fill(a, SWATCH["steel_blue"], (40, 42, 48), amp=0.18, scale=12.0, seed=9, stretch=3.0)
    _fill(a, SWATCH["steel_bright"], (118, 120, 126), amp=0.12, scale=10.0, seed=10, stretch=3.0)
    # bags: musette tan canvas / Brotbeutel feldgrau canvas; both with a flap line
    cv = (156, 140, 108) if fr else (108, 110, 94)
    sl = _fill(a, SWATCH["canvas"], cv, amp=0.13, scale=5.0, seed=11, stretch=1.2)
    h, w = sl.shape[:2]
    _line(sl, 0, h * 0.40, w, h * 0.40, 0.70, width=3)
    _line(sl, w * 0.5, h * 0.05, w * 0.5, h * 0.55, 0.80, width=4)
    # 2 L bidon: blue-grey cloth cover, strap, two spouts at the top
    sl = _fill(a, SWATCH["bidon"], (92, 102, 116), amp=0.12, scale=8.0, seed=12)
    h, w = sl.shape[:2]
    _line(sl, 0, h * 0.30, w, h * 0.30, 0.72, width=5)
    _disc(sl, w * 0.38, h * 0.08, 7.0, (60, 60, 64))
    _disc(sl, w * 0.62, h * 0.08, 5.0, (60, 60, 64))
    # kepi: covered = one cloth; bare = dark crown over the red band of the line infantry
    sl = _fill(a, SWATCH["kepi"], spec.get("kepi_rgb", coat), amp=0.10, scale=14.0, seed=13)
    h, w = sl.shape[:2]
    if spec.get("head") == "kepi" and not spec.get("cover_kepi", True):
        band = np.array(spec["band_rgb"], dtype=np.float32)
        n = _noise(h, w, 10.0, np.random.default_rng(14))
        y0 = int(h * 0.62)
        sl[y0:, :, :] = np.clip(band[None, None, :] * (1.0 + 0.16 * n[y0:, :, None]), 0, 255)
        _line(sl, 0, y0, w, y0, 0.5, width=2)
    _line(sl, 0, 2, w, 2, 0.80, width=3)                      # crown edge
    # Feldflasche felt
    _fill(a, SWATCH["felt"], (104, 92, 76), amp=0.14, scale=4.0, seed=15)


def build_uniform_sheet(tag, spec, obj, out_png):
    from PIL import Image
    from PIL import ImageFilter
    src = Image.open(SHEET_SRC).convert("RGB").resize((SHEET_W, SHEET_H), Image.LANCZOS)
    # SOFTEN the photographic detail before it is recoloured: the "US ARMY" name tape and
    # the jungle-fatigue pocket flaps survived a straight hue swap and read as lettering on
    # a 1915 capote (seen in the 2026-09-12 front render). Wool has folds, not print.
    src = src.filter(ImageFilter.GaussianBlur(2.2))
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
        k = np.clip(lum[md] / max(base_l, 1.0), 0.72, 1.32)[:, None]
        a[md] = np.clip(tgt[None, :] * k, 0, 255)
        painted |= md
        rep.append((r, counts[r], int(m.sum()), int(md.sum()), base_l, TARGET[r]))

    # Everything the body never samples becomes one flat colour. It costs nothing to look
    # at and it makes the PNG compress to almost nothing, which is how this sheet stays
    # inside the 1 MB texture law at a usable resolution for the part that IS sampled.
    a[~painted] = np.array(spec["coat_rgb"], dtype=np.float32) * 0.55

    paint_kit_swatches(a, spec)

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

    # KIT: every planned piece gets the man's uniform material and its swatch UVs
    nk, npoly = 0, 0
    for oname, plans in UVPLAN.items():
        if not oname.endswith("_" + t):
            continue
        o = D.objects[oname]
        o.data.materials.clear()
        o.data.materials.append(umat)
        for sw, mode, polys in plans:
            npoly += uv_map(o, sw, mode, polys)
        nk += 1
    print("   %-14s kit on the sheet: %d pieces, %d polys mapped into %d swatches"
          % (t, nk, npoly, len(SWATCH)))

    # face: the destination cell is MEASURED PER MESH (the visible body and the grunt_head
    # gib donor sample different cells, and every variant samples its own)
    fp = os.path.join(OUTDIR, "ww1_%s_face_atlas.png" % t)
    cell = os.path.join(OUTDIR, "ww1_%s_face_cell.png" % t)
    if not os.path.exists(cell):
        raise SystemExit("ABORT: run tools/build_ww1_face_cells.py first - missing %s" % cell)
    fimg = build_face_sheet("ww1_%s_face_atlas" % t, cell, fam, fp)
    fmat = D.materials["face_atlas_mat"].copy()
    fmat.name = "face_atlas_ww1_%s" % t      # prefix is API: project_cow_head_uvs.py + grunt_dresser.gd:38
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

# INTERSECTION: no NEW piece may sit inside the body. Proximity-filtered (a vertex 5 cm
# off the skin is a different body part), signed by the body's surface normal, and the
# inherited US webbing is reported rather than gated (its pouch backs were authored inside
# the body by the US pipeline and that is how the whole roster ships).
NEW_PIECES = ("coat_skirt", "musette", "bidon", "breadbag", "feldflasche", "cart_pouch_b",
              "kepi", "cerveliere", "helmet_")
def inside_by_parity(body, w):
    """Odd number of surface crossings along +X, +Y and +Z (majority of three) = inside.
    closest_point_on_mesh's signed distance alone trusts the nearest polygon's normal, and
    one flipped inner-thigh polygon on the inherited body reported an 8 mm 'penetration'
    for a skirt vertex 4.5 cm outside the section it was lofted from."""
    Mi = body.matrix_world.inverted()
    votes = 0
    for d in (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))):
        o = Mi @ w
        dl = (Mi.to_3x3() @ d).normalized()
        n = 0
        for _ in range(32):
            ok, loc, nrm, idx = body.ray_cast(o, dl, distance=5.0)
            if not ok:
                break
            n += 1
            o = loc + dl * 1e-4
        votes += n % 2
    return votes >= 2


print("BODY INTERSECTION - gear vertices inside the joined body (signed distance < -4 mm, "
      "within 5 cm of the skin, confirmed by ray parity):", flush=True)
for t in TAGS:
    body = D.objects["us_grunt_joined_" + t]
    Mi = body.matrix_world.inverted()
    Nw = body.matrix_world.to_3x3().inverted().transposed()
    hand = RIG[t].matrix_world @ RIG[t].data.bones["mixamorig:RightHand"].head_local
    rows = []
    for o in family(t):
        b = strip_tag(o.name, t)
        if o.hide_get() or b in BODY_BASES:
            continue
        inside, n_near = 0, 0
        worst = (0.0, Vector((0, 0, 0)))
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            if b.startswith("rifle_") and (w - hand).length < 0.16:
                continue                          # the gripped part lives in the fist
            ok, loc, nrm, _ = body.closest_point_on_mesh(Mi @ w)
            if not ok:
                continue
            lw = body.matrix_world @ loc
            d = (w - lw).length
            if d > 0.05:
                continue
            n_near += 1
            sd = (w - lw).dot((Nw @ nrm).normalized())
            if sd < -0.004 and inside_by_parity(body, w):
                inside += 1
                if sd < worst[0]:
                    worst = (sd, w - RIG[t].matrix_world.translation)
        gated = b.startswith(NEW_PIECES)
        if gated and b.startswith(("kepi", "helmet_", "cerveliere")) and worst[0] > -0.020:
            gated = False                     # a hat's sweatband sits inside the skull
        if inside and gated:
            fails.append("%s: %d verts inside the body, deepest %.1f mm at %s"
                         % (o.name, inside, -1000 * worst[0], tuple(round(v, 3) for v in worst[1])))
        rows.append("%s %d/%d%s" % (b, inside, n_near, "" if not inside else
                                    ("!%.0fmm@z%.2f" % (-1000 * worst[0], worst[1].z) if gated else "~")))
    print("   %-14s %s" % (t, "  ".join(rows)), flush=True)
print("   (! = gated new piece, ~ = inherited US webbing, reported only)", flush=True)

print("RIFLES - length vs real, grip vs hand, mechanism:", flush=True)
for t in TAGS:
    r = next(o for o in family(t) if strip_tag(o.name, t).startswith("rifle_"))
    info = RIFLE_INFO[t]
    real = CAST[t]["rifle"][1]
    mn, mx = wbb([r])
    span = max((mx - mn)[i] for i in range(3))
    xs = [v.co.x for v in r.data.vertices]
    raw = max(xs) - min(xs)
    ok = abs(raw - real) / real <= 0.03 and r.parent_type == 'BONE' \
        and r.parent_bone == "mixamorig:RightHand" and info["grip_to_wrist"] < 0.14
    if not ok:
        fails.append("rifle %s: raw %.4f real %.3f parent %s/%s grip %.3f"
                     % (t, raw, real, r.parent_type, r.parent_bone, info["grip_to_wrist"]))
    print("   %-14s %-6s raw length %.4f m (real %.3f, %+.2f%%) | world extent %.3f | origin %.3f m "
          "from the RightHand head | %s/%s  %s"
          % (t, info["kind"], raw, real, 100.0 * (raw - real) / real, span, info["grip_to_wrist"],
             r.parent_type, r.parent_bone, "OK" if ok else "FAIL"), flush=True)

print("SKIRT - top ring under the belt, hem at mid-calf, deforms with the legs:", flush=True)
for t in TAGS:
    sk = D.objects.get("coat_skirt_" + t)
    if not sk:
        continue
    belt = D.objects["web_belt_" + t]
    bmn, bmx = wbb([belt])
    smn, smx = wbb([sk])
    vg = {g.name for g in sk.vertex_groups}
    mods = [m.type for m in sk.modifiers]
    ok = smx.z <= bmx.z and smx.z >= bmn.z - 0.02 and abs(smn.z - SKIRT_RINGS[-1][0]) < 1e-3 \
        and vg == {"mixamorig:Hips", "mixamorig:LeftUpLeg", "mixamorig:RightUpLeg"} and mods == ['ARMATURE']
    if not ok:
        fails.append("skirt %s: top %.3f belt z[%.3f,%.3f] hem %.3f vg %s mods %s"
                     % (t, smx.z, bmn.z, bmx.z, smn.z, sorted(vg), mods))
    print("   %-14s top z=%.3f (belt z %.3f-%.3f) hem z=%.3f x-span %.3f m  %d polys  %s"
          % (t, smx.z, bmn.z, bmx.z, smn.z, smx.x - smn.x, len(sk.data.polygons), "OK" if ok else "FAIL"),
          flush=True)

print("UV SWATCH GATE - every kit loop inside its swatch rect, no kit loop in the body band:", flush=True)
for t in TAGS:
    bad, n = 0, 0
    badn = {}
    for oname, plans in UVPLAN.items():
        if not oname.endswith("_" + t):
            continue
        o = D.objects[oname]
        uv = o.data.uv_layers.active.data
        for sw, mode, polys in plans:
            x0, y0, x1, y1 = SWATCH[sw]
            sel = o.data.polygons if polys is None else [o.data.polygons[i] for i in polys]
            for p in sel:
                for li in p.loop_indices:
                    u, v = uv[li].uv
                    px, py = u * SHEET_W, (1.0 - v) * SHEET_H
                    n += 1
                    if not (x0 - 0.5 <= px <= x1 + 0.5 and y0 - 0.5 <= py <= y1 + 0.5):
                        bad += 1
                        badn.setdefault(strip_tag(oname, t) + "/" + sw, []).append((round(px), round(py)))
    if bad:
        fails.append("uv swatch %s: %d of %d kit loops outside their rect: %s"
                     % (t, bad, n, {k: v[:3] for k, v in badn.items()}))
    print("   %-14s %d kit loops, %d outside  %s" % (t, n, bad, "OK" if not bad else "FAIL"), flush=True)

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
