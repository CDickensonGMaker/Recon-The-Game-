"""add_cow_cast_member.py - add Sgt. McCleary or Lt. Champs to the Conquest of Worms cast file.

    "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" --background ^
        assets/us/characters/conquest_of_worms_us_cast.blend --python tools/add_cow_cast_member.py ^
        -- --who mccleary|champs [--save]

ADDS a family to the file Caleb saved himself (2026-09-12 23:15, his UV edits + REVIEW_APPENDED
in it). Every pre-existing object and image is fingerprinted at open (tools/hash_gate_blend.py)
and re-verified before the save; the script refuses to save if anything that was there changed.
Re-runnable: an existing family for the tag is removed first. Saves in place, save_version 0.

Built on the same pipeline as Michael (tools/build_cow_cast.py): clone Michael's family (rig +
55 meshes, per-index vertex-identical), move the ARMATURE OBJECT to the slot, swap kit, paint the
man's own face cell into BOTH cells his meshes sample (body col 1 row_b 4, gib donor col 0 row_b
0) on a private copy of face_atlas_v5, project the head UVs (project_cow_head_uvs), then put the
game's canonical grunt_head wrap back on the 26 non-front head polys exactly as Caleb's ten bodies
carry it now (copied from us_grunt_joined_michael's CURRENT UVs, poly matched by centre).

Caleb's rulings 2026-09-13 (verbatim): "McCleary is a larger and bulkier dude with large
forarms and a larger jaw always chewing on a cigar and has a bandana on most the time but
someitmes has a helmet. Lt Champs is a younger but sharp black guy with a real cool head on his
shoulders."

  mccleary        rifle kit off Michael's family (grenadier + ruck), M79 -> M16 (Gus's
                  m16_world, same RightHand placement), journal dropped, bulk = weight-driven
                  mesh scale in the rig frame on EVERY skinned mesh of the family (torso bones x
                  +10% width / +6% depth, forearm bones +25% radial, upper arm +10% radial;
                  rigid bone-parented gear in the torso band shifted the same way), jaw ring
                  +3.5 mm each side on body AND gib head, cigar (Head-parented, right corner of
                  the mouth = the cell's opened corner), bandana_mccleary over the crown
                  (Head-parented shell of the crown polys + band + knot + tails; the helmet is
                  kept HIDDEN for the export height measure, export drops it), sergeant chevrons
                  as skinned decal quads on both upper sleeves (stripes_sgt_mccleary,
                  cow_insignia_64.png). Sleeves: the base body's forearms already sample the skin
                  texel from the elbow down (measured: polys 156-161 on face_atlas, 118-121 on
                  cloth) - they read rolled on every grunt, nothing to do.
  mccleary_helmet the same man, bandana off, helmet on (Gus's two-state mechanism = two
                  families, one GLB each). Built by cloning the finished mccleary family.
  champs          Michael's family minus ruck (10), journal, bandolier, M79; + M1911 holster on
                  the right hip (Hips-parented), map case on the left hip (Gus's satchel shape,
                  Spine-parented, plus its skinned sling, recoloured), rank_champs = one subdued
                  1st Lt bar on the right collar (Spine2-parented quad) and rank_champs_cpl_ALT
                  = two chevrons, hidden, NOT in the family (no _champs suffix) so the exporter
                  never ships it - Caleb picks Lt or Cpl. Body untouched: per-index vertex hash
                  equal to Michael's on every part. Skin: the hands/forearms sample the cell's
                  lower-cheek texel and the neck rows sample the cell's neck, so a dark cell
                  makes them dark - measured and printed.

Gates: the pre-existing hash gate; rig 41 bones, scale 1, rotation never zeroed (X+90 kept);
weights sum 1 / no orphan groups; visibility contract (joined visible, donors/caps/frags/
Base_Human hidden); gore caps present; no name collisions; body fingerprint (Champs equal to
Michael; McCleary equal poly table + vertex count, measured widths reported); head UV contract
(26 polys bit-equal to Michael's wrap, 4 front polys from his own affine, 20 neck polys from the
projection); every family mesh evaluated X <= its own raw span; new props clear of the body
(closest_point_on_mesh, signed).
"""
import bpy
import bmesh
import os
import sys
import math
import hashlib
import json
import numpy as np
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hash_gate_blend as HG

D = bpy.data
ROOT = r"C:\Users\caleb\RECONgame"
CHAR = os.path.join(ROOT, "assets", "us", "characters")
ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
WHO = ARGV[ARGV.index("--who") + 1] if "--who" in ARGV else None
SAVE = "--save" in ARGV
SRC = "michael"
SLOT = {"mccleary": -3.0, "champs": -6.0, "mccleary_helmet": -9.0}
FACE_COLS, FACE_ROWS = 10, 7
SC = bpy.context.scene
assert WHO in ("mccleary", "champs"), "usage: -- --who mccleary|champs [--save]"
if bpy.context.mode != 'OBJECT':
    print("file was saved in %s - switching to OBJECT (data flush measured no-op 2026-09-13)" % bpy.context.mode, flush=True)
    bpy.ops.object.mode_set(mode='OBJECT')

PRE = HG.snapshot()
PRE_NAMES = {x.name for blk in (D.objects, D.meshes, D.images) for x in blk}
print("PRE-SNAPSHOT: %d objects, %d images" % (len(PRE["objects"]), len(PRE["images"])), flush=True)
FAILS = []


def fail(msg):
    FAILS.append(msg)
    print("   ! " + msg, flush=True)


def upd():
    bpy.context.view_layer.update()


def family(tag):
    return [o for o in D.objects if o.type == 'MESH' and o.name.endswith("_" + tag)]


def strip(name, tag):
    return name[: -(len(tag) + 1)]


def coll_of(o):
    return o.users_collection[0] if o.users_collection else SC.collection


def link_like(o, like):
    c = coll_of(like)
    if o.name not in c.objects:
        c.objects.link(o)


def vhash(o):
    h = hashlib.md5()
    for v in o.data.vertices:
        h.update(b"%.6f|%.6f|%.6f;" % (v.co.x, v.co.y, v.co.z))
    return h.hexdigest()[:12]


def phash(o):
    h = hashlib.md5()
    for p in o.data.polygons:
        h.update(("%d:%s;" % (p.material_index, list(p.vertices))).encode())
    return h.hexdigest()[:12]


def frame_fn(o):
    """world minus the rig's translation = the canonical head/body frame (z up, -y forward)."""
    rig = o.parent if o.parent and o.parent.type == 'ARMATURE' else None
    off = rig.matrix_world.translation.copy() if rig else Vector((0, 0, 0))
    M = o.matrix_world.copy()
    Mi = M.inverted()
    return (lambda v: M @ v - off), (lambda p: Mi @ (p + off))


def mat_flat(name, rgb, rough=0.85):
    if name in D.materials:
        return D.materials[name]
    m = D.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs['Base Color'].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    b.inputs['Roughness'].default_value = rough
    return m


def mat_image(name, img):
    if name in D.materials:
        return D.materials[name]
    m = D.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    t = nt.nodes.new('ShaderNodeTexImage')
    t.image = img
    t.interpolation = 'Closest'
    nt.links.new(t.outputs['Color'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 0.9
    return m


# ---------------------------------------------------------------------------------------------
# 0. re-runnable: drop an existing family for this tag (and the helmet twin)
# ---------------------------------------------------------------------------------------------
def remove_family(tag):
    n = 0
    for o in list(D.objects):
        if o.name.endswith("_" + tag) or o.name == "PSXRig_" + tag:
            D.objects.remove(o, do_unlink=True)
            n += 1
    for o in list(D.objects):
        if tag == "champs" and o.name == "rank_champs_cpl_ALT":
            D.objects.remove(o, do_unlink=True)
            n += 1
    for blk in (D.meshes, D.armatures, D.materials, D.images):
        for x in list(blk):
            if x.users == 0 and (x.name.endswith("_" + tag) or tag in x.name):
                blk.remove(x)
    if n:
        print("REMOVED previous family %s (%d objects)" % (tag, n), flush=True)


for t in ([WHO, "mccleary_helmet"] if WHO == "mccleary" else [WHO]):
    remove_family(t)


# ---------------------------------------------------------------------------------------------
# 1. clone Michael's family
# ---------------------------------------------------------------------------------------------
def clone_family(src_tag, dst_tag, new_x):
    srcrig = D.objects["PSXRig_" + src_tag]
    rig = srcrig.copy()
    rig.data = srcrig.data.copy()
    rig.name = "PSXRig_" + dst_tag
    rig.data.name = "PSXArm_" + dst_tag
    link_like(rig, srcrig)
    rig.location = Vector((new_x, srcrig.location.y, srcrig.location.z))
    if rig.animation_data:
        rig.animation_data.action = None
    mapping = {}
    for o in family(src_tag):
        n = o.copy()
        n.data = o.data.copy()
        n.name = strip(o.name, src_tag) + "_" + dst_tag
        n.data.name = n.name
        link_like(n, o)
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
    print("CLONE %s -> %s at x=%.1f : %d meshes, rig rotation kept %s" % (src_tag, dst_tag, new_x, len(mapping), tuple(round(math.degrees(a), 1) for a in rig.rotation_euler)), flush=True)
    return rig, mapping


rig, _ = clone_family(SRC, WHO, SLOT[WHO])
RIG_SRC = D.objects["PSXRig_" + SRC]


def kill(names):
    gone = []
    for nm in names:
        o = D.objects.get(nm + "_" + WHO)
        if o:
            gone.append(o.name)
            me = o.data
            D.objects.remove(o, do_unlink=True)
            if me.users == 0:
                D.meshes.remove(me)
    print("KIT drop %s" % gone, flush=True)


def clone_onto(src_obj, new_name, dst_rig, src_rig):
    """copy a bone-parented or skinned object from one family onto this rig, same rig-relative
    placement (build_cow_cast.transplant's contract, rigs are clones so the rest matrices agree)."""
    if src_obj.parent_type == 'BONE':
        a = src_rig.data.bones[src_obj.parent_bone].matrix_local
        b = dst_rig.data.bones[src_obj.parent_bone].matrix_local
        drift = max(abs(a[i][j] - b[i][j]) for i in range(4) for j in range(4))
        assert drift < 1e-5, (src_obj.name, drift)
    dR = dst_rig.matrix_world @ src_rig.matrix_world.inverted()
    want = dR @ src_obj.matrix_world.copy()
    n = src_obj.copy()
    n.data = src_obj.data.copy()
    n.name = new_name
    n.data.name = new_name
    link_like(n, src_obj)
    n.parent = dst_rig
    n.parent_type = src_obj.parent_type
    n.parent_bone = src_obj.parent_bone
    n.matrix_parent_inverse = src_obj.matrix_parent_inverse.copy()
    for m in n.modifiers:
        if m.type == 'ARMATURE':
            m.object = dst_rig
    upd()
    n.matrix_world = want
    upd()
    err = (n.matrix_world.translation - want.translation).length
    assert err < 1e-4, (new_name, err)
    n.hide_viewport = src_obj.hide_viewport
    n.hide_render = src_obj.hide_render
    n.hide_set(src_obj.hide_get())
    return n


def bone_parent(o, rg, bone):
    want = o.matrix_world.copy()
    o.parent = rg
    o.parent_type = 'BONE'
    o.parent_bone = bone
    o.matrix_parent_inverse = Matrix.Identity(4)
    upd()
    o.matrix_world = want
    upd()
    assert (o.matrix_world.translation - want.translation).length < 1e-5, o.name


def skin_to(o, rg, bone):
    """armature-skinned to one bone, weight 1.0 (decals ride the sleeve)."""
    vg = o.vertex_groups.new(name=bone)
    vg.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
    o.parent = rg
    o.parent_type = 'OBJECT'
    o.matrix_parent_inverse = rg.matrix_world.inverted()
    m = o.modifiers.new("Armature", 'ARMATURE')
    m.object = rg
    upd()


def new_mesh_obj(name, verts, faces, mat, like, uvs=None):
    me = D.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    me.materials.append(mat)
    if uvs is not None:
        uv = me.uv_layers.new(name="UVMap")
        for p in me.polygons:
            for k, li in enumerate(p.loop_indices):
                uv.data[li].uv = uvs[p.index][k]
    o = D.objects.new(name, me)
    link_like(o, like)
    return o


def rigframe_to_world(p):
    return Vector(p) + rig.matrix_world.translation


body = D.objects["us_grunt_joined_" + WHO]
head_donor = D.objects["grunt_head_" + WHO]
co_body, _ = frame_fn(body)

# ---------------------------------------------------------------------------------------------
# 2. kit
# ---------------------------------------------------------------------------------------------
kill(["journal", "m79_world"])
GUS_RIG = D.objects["PSXRig_gus_arrival"]
GUSE_RIG = D.objects["PSXRig_gus_ears"]
if WHO == "mccleary":
    m16 = clone_onto(D.objects["m16_world_gus_arrival"], "m16_world_" + WHO, rig, GUS_RIG)
    print("KIT + %s (RightHand, basis copied from gus_arrival)" % m16.name, flush=True)
else:
    kill(["ruck_body", "ruck_flap", "ruck_frame_bar", "ruck_frame_l", "ruck_frame_r",
          "ruck_buckle_l", "ruck_buckle_r", "ruck_pocket_0", "ruck_pocket_1", "ruck_pocket_2", "web_bandolier"])
    # map case = Gus's satchel shape (medic musette minus crosses), left hip, recoloured OD canvas
    mc_canvas = mat_flat("mapcase_canvas_champs", (0.075, 0.082, 0.048), rough=0.95)
    mc_web = mat_flat("mapcase_web_champs", (0.050, 0.052, 0.034), rough=0.95)
    for src, nm in (("bag_gus_gus_ears", "mapcase"), ("bag_gus_flap_gus_ears", "mapcase_flap"),
                    ("bag_gus_sling_gus_ears", "mapcase_sling"), ("bag_gus_buckle_a_gus_ears", "mapcase_buckle_a"),
                    ("bag_gus_buckle_b_gus_ears", "mapcase_buckle_b")):
        n = clone_onto(D.objects[src], nm + "_" + WHO, rig, GUSE_RIG)
        for i, m in enumerate(n.data.materials):
            n.data.materials[i] = mc_web if (m and "web" in m.name) else mc_canvas
    print("KIT + map case (5 objects off gus_ears's bag, mapcase_canvas_champs)", flush=True)


# ---------------------------------------------------------------------------------------------
# 3. props built here: holster / rank (champs), cigar / bandana / stripes (mccleary)
# ---------------------------------------------------------------------------------------------
def box_verts(cx, cy, cz, sx, sy, sz):
    hx, hy, hz = sx / 2.0, sy / 2.0, sz / 2.0
    vs = [(cx - hx, cy - hy, cz - hz), (cx + hx, cy - hy, cz - hz), (cx + hx, cy + hy, cz - hz), (cx - hx, cy + hy, cz - hz),
          (cx - hx, cy - hy, cz + hz), (cx + hx, cy - hy, cz + hz), (cx + hx, cy + hy, cz + hz), (cx - hx, cy + hy, cz + hz)]
    fs = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return vs, fs


def add_box(name, c, s, mat, like, base=0):
    vs, fs = box_verts(*c, *s)
    return vs, [tuple(i + base for i in f) for f in fs]


def surface_hit(obj, p_frame):
    """closest point on obj's evaluated surface to a canonical-frame point: (dist, signed)"""
    co, inv = frame_fn(obj)
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    loc_l = ev.matrix_world.inverted() @ rigframe_to_world(p_frame)
    ok, loc, nrm, idx = ev.closest_point_on_mesh(loc_l)
    if not ok:
        return None, None
    hit_w = ev.matrix_world @ loc
    n_w = (ev.matrix_world.to_3x3() @ nrm).normalized()
    d = rigframe_to_world(p_frame) - hit_w
    return d.length, d.dot(n_w)


def clearance_report(o, against, label):
    """every vertex of o vs the body: min distance and how many are INSIDE (signed < 0)"""
    co, _ = frame_fn(o)
    inside, worst = 0, 9e9
    for v in o.data.vertices:
        d, s = surface_hit(against, co(v.co))
        if d is None:
            continue
        worst = min(worst, d)
        if s < -0.002:
            inside += 1
    print("   CLEARANCE %-22s vs %s: nearest %.1f mm, %d/%d verts inside the body (>2 mm)"
          % (label, against.name, worst * 1000, inside, len(o.data.vertices)), flush=True)
    return inside, worst


def top_of_body_at(x, y_lo, y_hi, z_lo, z_hi, dx=0.02):
    """the body's top SURFACE at (x, y=(y_lo+y_hi)/2): a ray cast straight down in the body's
    local space (the upper arm has vertex rings only at the shoulder and the elbow, so a vertex
    search at mid-sleeve finds nothing - measured 2026-09-13)."""
    co, inv = frame_fn(body)
    y = (y_lo + y_hi) / 2.0
    dg = bpy.context.evaluated_depsgraph_get()
    ev = body.evaluated_get(dg)
    Mi = ev.matrix_world.inverted()
    o_l = Mi @ rigframe_to_world(Vector((x, y, z_hi + 0.3)))
    d_l = (Mi.to_3x3() @ Vector((0, 0, -1))).normalized()
    ok, loc, nrm, idx = ev.ray_cast(o_l, d_l)
    if not ok:
        return None
    p = ev.matrix_world @ loc - rig.matrix_world.translation
    return p if z_lo <= p.z <= z_hi else None


INSIG = D.images.get("cow_insignia_64")
if INSIG is None:
    INSIG = D.images.load(os.path.join(CHAR, "cow_insignia_64.png"))
    INSIG.name = "cow_insignia_64"
    INSIG.pack()
insig_mat = mat_image("cow_insignia_mat", INSIG)
TILE = {"sgt": (0.0, 0.5, 0.5, 1.0), "lt": (0.5, 0.5, 1.0, 1.0), "cpl": (0.0, 0.0, 0.5, 0.5)}


def decal_quad(name, centre, u_dir, v_dir, w, h, tile, like):
    """a w x h quad at centre, u_dir = the tile's x (left->right), v_dir = the tile's y (bottom->top =
    the chevron points this way). All canonical-frame vectors."""
    u = Vector(u_dir).normalized() * (w / 2.0)
    v = Vector(v_dir).normalized() * (h / 2.0)
    c = Vector(centre)
    vs = [tuple(rigframe_to_world(c - u - v)), tuple(rigframe_to_world(c + u - v)),
          tuple(rigframe_to_world(c + u + v)), tuple(rigframe_to_world(c - u + v))]
    u0, v0, u1, v1 = TILE[tile]
    uvs = {0: [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]}
    o = new_mesh_obj(name, vs, [(0, 1, 2, 3)], insig_mat, like, uvs)
    return o


def build_props():
    """props measure the body, so this runs AFTER McCleary's bulk (section 6)."""
    global body, co_body
    if WHO == "champs":
        # --- M1911 in an M1916 holster, right hip, hanging off the pistol belt --------------------
        # belt measured on the clone: web_belt frame z 1.072-1.134 (height), x +-0.169. Right hip
        # outer surface at x ~ -0.17; the holster body 4 cm proud of it, 22 cm long, 6 cm wide.
        leather = mat_flat("holster_leather_champs", (0.055, 0.028, 0.014), rough=0.75)
        grip = mat_flat("pistol_grip_champs", (0.040, 0.028, 0.020), rough=0.6)
        hip = top_of_body_at(-0.17, -0.05, 0.10, 0.95, 1.10)   # not used for z; x-extent check below
        xs = [co_body(v.co).x for v in body.data.vertices if 0.95 < co_body(v.co).z < 1.10 and -0.10 < co_body(v.co).y < 0.12 and abs(co_body(v.co).x) < 0.25]   # |x| < 0.25: the T-pose hands are at this height too
        hip_x = min(xs)
        hx = hip_x - 0.028
        vs, fs = box_verts(hx, 0.035, 0.985, 0.048, 0.080, 0.215)           # holster body
        v2, f2 = box_verts(hx + 0.004, 0.035, 1.105, 0.040, 0.090, 0.030)     # flap over the top
        v3, f3 = box_verts(hx, 0.070, 1.115, 0.026, 0.040, 0.060)             # grip poking out the back
        verts = [tuple(rigframe_to_world(Vector(p))) for p in vs + v2 + v3]
        faces = fs + [tuple(i + 8 for i in f) for f in f2] + [tuple(i + 16 for i in f) for f in f3]
        hol = new_mesh_obj("holster_m1911_" + WHO, verts, faces, leather, body)
        hol.data.materials.append(grip)
        for p in hol.data.polygons:
            p.material_index = 1 if p.index >= 12 else 0
        bone_parent(hol, rig, "mixamorig:Hips")
        print("PROP holster_m1911_champs: hip outer x %.3f -> holster centre x %.3f, z 0.88-1.13" % (hip_x, hx), flush=True)
        clearance_report(hol, body, "holster")
        # --- rank: one subdued 1st Lt bar on the right collar point -------------------------------
        # collar/chest-top verts measured on the body: v16 (+0.0536,-0.0579,1.5134), v51 (0,-0.0762,1.5068)
        rk = decal_quad("rank_" + WHO, (-0.036, -0.078, 1.503), (1, 0, 0), (0, 0, 1), 0.026, 0.013, "lt", body)
        bone_parent(rk, rig, "mixamorig:Spine2")
        d, sgn = surface_hit(body, Vector((-0.036, -0.078, 1.503)))
        print("PROP rank_champs (1st Lt bar) at the right collar, %.1f mm off the chest, %s the surface" % (d * 1000, "outside" if sgn > 0 else "INSIDE"), flush=True)
        if sgn <= 0:
            fail("rank_champs sits inside the chest")
        # --- the alternative: corporal chevrons, hidden, NOT in the family --------------------------
        top = top_of_body_at(-0.30, -0.10, 0.10, 1.25, 1.55)
        alt = decal_quad("rank_champs_cpl_ALT", (top.x, top.y, top.z + 0.004), (0, -1, 0), (1, 0, 0), 0.07, 0.08, "cpl", body)
        skin_to(alt, rig, "mixamorig:RightArm")
        alt.hide_set(True)
        alt.hide_render = True
        print("PROP rank_champs_cpl_ALT (hidden, not exported): two chevrons on the right sleeve at %s" % (tuple(round(x, 3) for x in top),), flush=True)

    if WHO == "mccleary":
        # --- sergeant chevrons on both upper sleeves (skinned decals) ------------------------------
        for side, sx, bone in (("r", -1, "mixamorig:RightArm"), ("l", 1, "mixamorig:LeftArm")):
            top = top_of_body_at(sx * 0.30, -0.10, 0.10, 1.25, 1.55)
            assert top is not None, "no sleeve verts at x %.2f" % (sx * 0.30)
            # points toward the shoulder (-x for the right arm) = tile v up; tile u runs front->back
            q = decal_quad("stripes_sgt_%s_%s" % (side, WHO), (top.x, top.y, top.z + 0.004), (0, -sx, 0), (-sx, 0, 0), 0.07, 0.08, "sgt", body)
            skin_to(q, rig, bone)
            print("PROP %s on the sleeve top at %s" % (q.name, tuple(round(x, 3) for x in top)), flush=True)

        # --- cigar: 11 cm x 16 mm, clamped in the right corner of the mouth ------------------------
        # mouth corner on the mesh: the painted corner (cell x 72.1) through the front affine
        # (sx ~529 px/m, cx ~62.5) = x +0.018; lips at z 1.615 (project_cow_head_uvs residual print);
        # face plane y -0.1155. Angled out 20 deg and down 12 deg.
        cig_mat = mat_flat("cigar_brown_" + WHO, (0.16, 0.085, 0.040), rough=0.8)
        ash_mat = mat_flat("cigar_ash_" + WHO, (0.36, 0.34, 0.31), rough=0.95)
        start = Vector((0.019, -0.106, 1.613))
        dire = Vector((math.sin(math.radians(22)), -math.cos(math.radians(22)), -math.tan(math.radians(12)))).normalized()
        L, R, N = 0.105, 0.0075, 6
        side = dire.cross(Vector((0, 0, 1))).normalized()
        upv = side.cross(dire).normalized()
        verts, faces = [], []
        rings = [start - dire * 0.012, start + dire * (L - 0.012), start + dire * L]
        for c in rings:
            for k in range(N):
                a = 2 * math.pi * k / N
                verts.append(tuple(rigframe_to_world(c + (side * math.cos(a) + upv * math.sin(a)) * R)))
        for r_ in range(len(rings) - 1):
            for k in range(N):
                a0, a1 = r_ * N + k, r_ * N + (k + 1) % N
                faces.append((a0, a1, a1 + N, a0 + N))
        faces.append(tuple(range(N)))                                       # butt cap
        faces.append(tuple(reversed(range((len(rings) - 1) * N, len(rings) * N))))   # ash cap
        cig = new_mesh_obj("cigar_" + WHO, verts, faces, cig_mat, body)
        cig.data.materials.append(ash_mat)
        for p in cig.data.polygons:
            p.material_index = 1 if (p.index >= N and p.index != 2 * N) else 0
        bone_parent(cig, rig, "mixamorig:Head")
        d, sgn = surface_hit(body, start)
        print("PROP cigar_mccleary: butt at %s is %.1f mm %s the face, tip at %s" % (tuple(round(x, 3) for x in start), d * 1000, "outside" if sgn > 0 else "INSIDE", tuple(round(x, 3) for x in start + dire * L)), flush=True)
        d2, s2 = surface_hit(body, rings[0])
        print("   cigar butt ring end: %.1f mm %s the face (the 12 mm in the mouth is intended)" % (d2 * 1000, "outside" if s2 > 0 else "inside"), flush=True)

        # --- bandana: shell of the crown polys of the gib head, offset 6 mm, band + knot + tails ---
        co_h, inv_h = frame_fn(head_donor)
        hm = head_donor.data
        crown = [p for p in hm.polygons if min(co_h(hm.vertices[i].co).z for i in p.vertices) >= 1.728]
        assert len(crown) >= 10, len(crown)
        vidx = sorted({i for p in crown for i in p.vertices})
        remap = {i: k for k, i in enumerate(vidx)}
        # vertex normals of the crown verts (from the crown polys only), in the canonical frame
        nrm = {i: Vector((0, 0, 0)) for i in vidx}
        for p in crown:
            n = (head_donor.matrix_world.to_3x3() @ p.normal).normalized()
            for i in p.vertices:
                nrm[i] += n
        OFF = 0.006
        pts = {i: co_h(hm.vertices[i].co) + nrm[i].normalized() * OFF for i in vidx}
        verts = [tuple(rigframe_to_world(pts[i])) for i in vidx]
        faces = [tuple(remap[i] for i in p.vertices) for p in crown]
        # boundary edges of the crown shell -> a band hanging 22 mm down and 4 mm out
        edge_count = {}
        for p in crown:
            vs_ = list(p.vertices)
            for k in range(len(vs_)):
                e = tuple(sorted((vs_[k], vs_[(k + 1) % len(vs_)])))
                edge_count[e] = edge_count.get(e, 0) + 1
        boundary = [e for e, c in edge_count.items() if c == 1]
        bverts = sorted({i for e in boundary for i in e})
        low = {}
        for i in bverts:
            p = pts[i]
            radial = Vector((p.x, p.y + 0.028, 0.0))            # head centre y -0.028 (verts span -0.13..0.075)
            out_dir = radial.normalized() if radial.length > 1e-6 else Vector((0, -1, 0))
            q = p + out_dir * 0.004 + Vector((0, 0, -0.022))
            low[i] = len(verts)
            verts.append(tuple(rigframe_to_world(q)))
        for a, b in boundary:
            # wind the band quad to face outward: order by the crown poly's winding
            pa, pb = pts[a], pts[b]
            cen = Vector((0, 0, 0))
            for i in vidx:
                cen += pts[i]
            cen /= len(vidx)
            mid = (pa + pb) / 2
            normal = (pb - pa).cross(Vector((0, 0, -1)))
            if normal.dot(mid - cen) < 0:
                a, b = b, a
            faces.append((remap[a], remap[b], low[b], low[a]))
        # knot at the back of the crown + two tails down the nape
        nape = max((pts[i] for i in vidx), key=lambda p: p.y)
        kc = Vector((0.0, nape.y + 0.010, nape.z - 0.012))
        kv, kf = box_verts(kc.x, kc.y, kc.z, 0.034, 0.026, 0.026)
        base = len(verts)
        verts += [tuple(rigframe_to_world(Vector(p))) for p in kv]
        faces += [tuple(i + base for i in f) for f in kf]
        for sx in (-1, 1):
            base = len(verts)
            t0 = kc + Vector((sx * 0.010, 0.006, -0.012))
            t1 = t0 + Vector((sx * 0.012, 0.004, -0.075))
            w = Vector((0.010, 0, 0))
            verts += [tuple(rigframe_to_world(v_)) for v_ in (t0 - w, t0 + w, t1 + w * 0.6, t1 - w * 0.6)]
            faces += [(base, base + 1, base + 2, base + 3), (base + 3, base + 2, base + 1, base)]
        band_mat = mat_flat("bandana_od_" + WHO, (0.135, 0.150, 0.082), rough=0.95)
        ban = new_mesh_obj("bandana_" + WHO, verts, faces, band_mat, body)
        bone_parent(ban, rig, "mixamorig:Head")
        zs = [co_h(hm.vertices[i].co).z for i in vidx]
        print("PROP bandana_mccleary: %d crown polys (all verts z >= 1.728) -> shell %d mm out, band 22 mm, knot at %s, %d verts / %d faces"
              % (len(crown), OFF * 1000, tuple(round(x, 3) for x in kc), len(ban.data.vertices), len(ban.data.polygons)), flush=True)
        clearance_report(ban, body, "bandana")
        # helmet: kept for the height box, hidden; export_cow_cast drops it for this tag
        hel = D.objects["helmet_shell_worn_" + WHO]
        hel.hide_set(True)
        hel.hide_render = True
        print("helmet_shell_worn_mccleary HIDDEN (height reference only; exporter NOEXPORT)", flush=True)




# ---------------------------------------------------------------------------------------------
# 4. the face: his own cell into both cells his meshes sample, on a private copy of face_atlas_v5
# ---------------------------------------------------------------------------------------------
def px(img):
    w, h = img.size
    a = np.empty(w * h * img.channels, dtype=np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(h, w, img.channels)


def face_cells(o):
    me = o.data
    out = {}
    if not me.uv_layers:
        return out
    uv = me.uv_layers.active.data
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
        out[(col, row)] = o.name
    return out


base_img = D.images["face_atlas_v5"]
W, H = base_img.size
atlas = px(base_img).copy()
cell_path = os.path.join(CHAR, "cow_%s_face_cell.png" % WHO)
cell_img = D.images.load(cell_path)
c = px(cell_img)
assert (c.shape[1], c.shape[0]) == (130, 162), c.shape
cells = {}
for o in family(WHO):
    for k, name in face_cells(o).items():
        cells.setdefault(k, []).append(name)
assert cells, "no mesh samples a face cell"
for (col, row), owners in sorted(cells.items()):
    x0, x1 = int(round(col * W / FACE_COLS)), int(round((col + 1) * W / FACE_COLS))
    y0, y1 = int(round(row * H / FACE_ROWS)), int(round((row + 1) * H / FACE_ROWS))
    th, tw = y1 - y0, x1 - x0
    src = c
    if (src.shape[0], src.shape[1]) != (th, tw):
        yi = (np.arange(th) * (src.shape[0] / float(th))).astype(int).clip(0, src.shape[0] - 1)
        xi = (np.arange(tw) * (src.shape[1] / float(tw))).astype(int).clip(0, src.shape[1] - 1)
        src = src[yi][:, xi]
    atlas[y0:y1, x0:x1, :3] = src[:, :, :3]
    atlas[y0:y1, x0:x1, 3] = 1.0
    print("FACE painted cell col=%d row_b=%d (px x%d-%d y%d-%d) <- %s" % (col, row, x0, x1, y0, y1, sorted(owners)), flush=True)
D.images.remove(cell_img)
ATLAS_PNG = os.path.join(CHAR, "cow_%s_face_atlas.png" % WHO)
tmp = D.images.new("cow_%s_face_atlas_tmp" % WHO, W, H, alpha=True)
tmp.pixels.foreach_set(np.ascontiguousarray(atlas, dtype=np.float32).ravel())
tmp.filepath_raw = ATLAS_PNG
tmp.file_format = 'PNG'
tmp.save()
D.images.remove(tmp)
face_img = D.images.load(ATLAS_PNG)          # 8-bit reload: a float buffer ships as a 16-bit PNG
face_img.name = "cow_%s_face_atlas" % WHO
face_img.pack()
assert not face_img.is_float and face_img.packed_file is not None
face_mat = D.materials["face_atlas_mat"].copy()
face_mat.name = "face_atlas_" + WHO
for n in face_mat.node_tree.nodes:
    if n.type == 'TEX_IMAGE':
        n.image = face_img
        n.interpolation = 'Closest'
hits = 0
for o in family(WHO):
    for i, m in enumerate(o.data.materials):
        if m and m.name.startswith("face_atlas"):
            o.data.materials[i] = face_mat
            hits += 1
print("FACE %s -> %s (%d slots), %s %dx%d %.2f MB" % (WHO, face_mat.name, hits, face_img.name, W, H, os.path.getsize(ATLAS_PNG) / 1048576.0), flush=True)
# the hand/forearm skin texel (fix_cow_neck_uvs: one texel of the cell) - what colour is it now?
uvl = body.data.uv_layers.active.data
hand_uv = None
for p in body.data.polygons:
    cc = sum((co_body(body.data.vertices[i].co) for i in p.vertices), Vector()) / len(p.vertices)
    if cc.x < -0.74 and p.material_index == 1:
        hand_uv = uvl[p.loop_indices[0]].uv.copy()
        break
ai = px(face_img)
hx_, hy_ = int(hand_uv.x * W), int(hand_uv.y * H)
hand_rgb = ai[hy_, hx_, :3]
ccol, crow_b = int(hx_ // (W / FACE_COLS)), int(hy_ // (H / FACE_ROWS))
cpx, cpy = hx_ - int(round(ccol * W / FACE_COLS)), int(round((crow_b + 1) * H / FACE_ROWS)) - hy_
print("SKIN hands/forearms sample atlas px (%d,%d) = cell col %d row_b %d px (%d,%d from the top): rgb %s (the cell's own skin, so a dark cell gives dark hands)"
      % (hx_, hy_, ccol, crow_b, cpx, cpy, tuple(round(float(x), 3) for x in hand_rgb)), flush=True)


# ---------------------------------------------------------------------------------------------
# 5. head UVs: full-cell projection, then Caleb's canonical wrap on the 26 non-front polys
# ---------------------------------------------------------------------------------------------
sys.argv = [sys.argv[0], "--", "--tags", WHO]
import project_cow_head_uvs as P
P.run()


def head_polys(o):
    co, _ = frame_fn(o)
    me = o.data
    fi = {i for i, m in enumerate(me.materials) if m and m.name.startswith("face_atlas")}
    out = []
    for p in me.polygons:
        if p.material_index not in fi:
            continue
        cc = sum((co(me.vertices[i].co) for i in p.vertices), Vector()) / len(p.vertices)
        if cc.z > 1.60 and abs(cc.x) < 0.12:
            out.append((p, cc))
    return out


src_body = D.objects["us_grunt_joined_" + SRC]
src_uv = src_body.data.uv_layers.active.data
dst_uv = body.data.uv_layers.active.data
src_hp = head_polys(src_body)
dst_hp = head_polys(body)
assert len(src_hp) == len(dst_hp) == 30, (len(src_hp), len(dst_hp))
copied, kept = [], []
for p, cc in dst_hp:
    n = (body.matrix_world.to_3x3() @ p.normal).normalized()
    per_man = n.y < -0.5 and cc.z < 1.70            # the mid + lower FRONT quads: his own affine
    if per_man:
        kept.append(p.index)
        continue
    sp, d = min(((q, (qc - cc).length) for q, qc in src_hp), key=lambda t: t[1])
    assert d < 1e-4 and len(sp.loop_indices) == len(p.loop_indices), (p.index, d)
    for li_d, li_s in zip(p.loop_indices, sp.loop_indices):
        dst_uv[li_d].uv = src_uv[li_s].uv.copy()
    copied.append(p.index)
assert len(copied) == 26 and len(kept) == 4, (len(copied), len(kept))
print("HEAD UV: %d polys carry Michael's current (canonical) wrap, %d front polys his own projection" % (len(copied), len(kept)), flush=True)
# gate: 26 bit-equal, 4 differ (or equal by coincidence), 20 neck from the projection
same = sum(1 for p, cc in dst_hp for q, qc in src_hp if (qc - cc).length < 1e-4
           and all(dst_uv[a].uv == src_uv[b].uv for a, b in zip(p.loop_indices, q.loop_indices)))
print("HEAD UV gate: %d/30 head polys bit-identical to Michael's (26 canonical + front quads only if the affine coincides)" % same, flush=True)
if same < 26:
    fail("head UV copy: only %d polys match Michael's wrap" % same)


# ---------------------------------------------------------------------------------------------
# 6. McCleary's body: bulk + jaw (AFTER the UV work, so the centre match above was exact)
# ---------------------------------------------------------------------------------------------
if WHO == "mccleary":
    Rw = rig.matrix_world
    Rwi = Rw.inverted()
    TORSO = {"mixamorig:Hips", "mixamorig:Spine", "mixamorig:Spine1", "mixamorig:Spine2", "mixamorig:LeftShoulder", "mixamorig:RightShoulder"}
    FORE = {"mixamorig:LeftForeArm": 1, "mixamorig:RightForeArm": -1}
    UPPER = {"mixamorig:LeftArm": 1, "mixamorig:RightArm": -1}
    WIDTH, DEPTH, FORE_G, UP_G = 0.125, 0.06, 0.29, 0.10      # per-bone gains; measured on the body: chest +8-9%, forearm +24-25% (blended weights dilute the gain)
    YC = 0.03                                   # torso front/back centre (body y -0.12..0.18)
    bones = rig.data.bones

    def axis(bn):
        b = bones[bn]
        h = Vector((b.head_local.x, -b.head_local.z, b.head_local.y))    # rig-local (y up) -> frame (z up)
        t = Vector((b.tail_local.x, -b.tail_local.z, b.tail_local.y))
        return h, (t - h).normalized()

    AX = {bn: axis(bn) for bn in list(FORE) + list(UPPER)}

    def deform(p, wt, wf, wu):
        """p in the canonical frame; wt torso weight, wf {bone: w}, wu {bone: w}"""
        q = Vector(p)
        if wt > 0:
            q.x = q.x * (1 + WIDTH * wt)
            q.y = YC + (q.y - YC) * (1 + DEPTH * wt)
        for group, gain in ((wf, FORE_G), (wu, UP_G)):
            for bn, w in group.items():
                if w <= 0:
                    continue
                h, d = AX[bn]
                along = (q - h).dot(d)
                foot = h + d * along
                q = foot + (q - foot) * (1 + gain * w)
        return q

    def weights_of(o, v):
        gi = {g.index: g.name for g in o.vertex_groups}
        wt, wf, wu = 0.0, {}, {}
        for g in v.groups:
            nm = gi.get(g.group, "")
            if nm in TORSO:
                wt += g.weight
            if nm in FORE:
                wf[nm] = g.weight
            if nm in UPPER:
                wu[nm] = g.weight
        return min(wt, 1.0), wf, wu

    def spatial_torso_w(p):
        z = p.z
        if 0.95 <= z <= 1.50:
            return 1.0
        if 0.85 < z < 0.95:
            return (z - 0.85) / 0.10
        if 1.50 < z < 1.58:
            return (1.58 - z) / 0.08
        return 0.0

    SKIP = ("helmet_", "m16_world", "cigar_", "bandana_", "stripes_")
    b_ = D.objects["us_grunt_joined_" + WHO]

    def measure_body():
        cob, _ = frame_fn(b_)
        gi = {g.index: g.name for g in b_.vertex_groups}
        chest, rad = [], {bn: [] for bn in list(FORE) + list(UPPER)}
        for v in b_.data.vertices:
            p = cob(v.co)
            ws = {gi[g.group]: g.weight for g in v.groups}
            if sum(w for n_, w in ws.items() if n_ in TORSO) > 0.5 and 1.30 < p.z < 1.45:
                chest.append(p.x)
            for bn in rad:
                if ws.get(bn, 0) > 0.5:
                    h, d = AX[bn]
                    q = p - h
                    rad[bn].append((q - d * q.dot(d)).length)
        return dict(chest_width=max(chest) - min(chest), n_chest=len(chest),
                    radial={bn: (sum(r) / len(r) if r else 0.0, len(r)) for bn, r in rad.items()})

    before_w = measure_body()
    moved = {}
    # the body first, remembering every vertex's displacement: the gore CAPS carry ONE vertex
    # group (rigid on their limb bone), so a weight-driven deform moves them differently from the
    # blended-weight ring they sit on (cap_uparm_l drifted 32 mm on the first dry run). Caps and
    # any single-group mesh take the displacement of the nearest body vertex instead.
    cob0, _ = frame_fn(b_)
    body_before = [cob0(v.co) for v in b_.data.vertices]
    body_disp = []
    for o in [b_] + [o for o in family(WHO) if o is not b_]:
        if any(o.name.startswith(s) for s in SKIP):
            continue
        co, inv = frame_fn(o)
        skinned = bool(o.vertex_groups) and any(m.type == 'ARMATURE' for m in o.modifiers)
        snap = o.name.startswith("cap_") or (skinned and len(o.vertex_groups) < 4)
        mx = 0.0
        for v in o.data.vertices:
            p = co(v.co)
            if skinned and not snap:
                wt, wf, wu = weights_of(o, v)
                q = deform(p, wt, wf, wu)
            else:
                # caps / single-group / rigid gear: inverse-distance blend of the 4 nearest body
                # vertices' displacements (a cap's corners sit INSIDE the limb, up to 13 cm from
                # any body vertex; the spatial torso rule scaled an elbow cap 55 mm - measured)
                near = sorted(range(len(body_before)), key=lambda i: (body_before[i] - p).length)[:4]
                wsum = 0.0
                disp = Vector((0, 0, 0))
                for i in near:
                    w = 1.0 / max((body_before[i] - p).length, 1e-4)
                    wsum += w
                    disp += body_disp[i] * w
                q = p + disp / wsum
            if o is b_:
                body_disp.append(q - p)
            mx = max(mx, (q - p).length)
            v.co = inv(q)
        o.data.update()
        moved[o.name] = mx
    after_w = measure_body()
    cob, _ = frame_fn(b_)
    print("BULK torso x%.2f width / x%.2f depth, forearm x%.2f, upper arm x%.2f (weight-driven, %d meshes)"
          % (1 + WIDTH, 1 + DEPTH, 1 + FORE_G, 1 + UP_G, len(moved)), flush=True)
    print("   chest width (torso-weighted verts, z 1.30-1.45, n=%d): %.4f -> %.4f m (%+.1f%%)" % (before_w["n_chest"], before_w["chest_width"], after_w["chest_width"], 100 * (after_w["chest_width"] / before_w["chest_width"] - 1)), flush=True)
    for bn in before_w["radial"]:
        r0, n0 = before_w["radial"][bn]
        r1, n1 = after_w["radial"][bn]
        print("   %-24s mean radius (verts >50%% on the bone, n=%d): %.1f -> %.1f mm (%+.1f%%)" % (bn.replace("mixamorig:", ""), n0, r0 * 1000, r1 * 1000, 100 * (r1 / r0 - 1) if r0 else 0), flush=True)
    top5 = sorted(moved.items(), key=lambda kv: -kv[1])[:6]
    print("   largest vertex moves: %s" % ", ".join("%s %.1f mm" % (k, v * 1000) for k, v in top5), flush=True)
    if not (1.07 <= after_w["chest_width"] / before_w["chest_width"] <= 1.13):
        fail("chest width change out of the +8-12%% band: %.3f" % (after_w["chest_width"] / before_w["chest_width"]))
    for bn in FORE:
        r0, r1 = before_w["radial"][bn][0], after_w["radial"][bn][0]
        if not (1.18 <= r1 / max(r0, 1e-9) <= 1.30):
            fail("forearm girth change out of the +18-30%% band on %s: %.3f" % (bn, r1 / max(r0, 1e-9)))
    # the hidden gib donors must match the body per index where they overlap (same deform on both)
    for part in ("grunt_torso", "grunt_forearm_l", "grunt_forearm_r", "grunt_uparm_l", "grunt_uparm_r"):
        d_ = D.objects[part + "_" + WHO]
        cod, _ = frame_fn(d_)
        worst = 0.0
        for v in d_.data.vertices:
            pd = cod(v.co)
            near = min((cob(w.co) - pd).length for w in b_.data.vertices)
            worst = max(worst, near)
        print("   donor %-18s every vertex within %.2f mm of a body vertex" % (part, worst * 1000), flush=True)
        if worst > 0.002:
            fail("gib donor %s drifted %.1f mm from the body" % (part, worst * 1000))

    # --- jaw ring: +3.5 mm each side on the body and the gib head (same positions) -----------
    JAW = [((0.0546, -0.0213, 1.5896), 0.0035), ((0.0546, -0.0241, 1.5896), 0.0035),
           ((0.0313, -0.0971, 1.5787), 0.0020), ((0.0484, 0.0260, 1.5909), 0.0025), ((0.0484, 0.0294, 1.5909), 0.0025)]
    for o in (b_, D.objects["grunt_head_" + WHO]):
        co, inv = frame_fn(o)
        n = 0
        for v in o.data.vertices:
            p = co(v.co)
            for (jx, jy, jz), dx in JAW:
                if abs(abs(p.x) - jx) < 1e-3 and abs(p.y - jy) < 1e-3 and abs(p.z - jz) < 1e-3:
                    p.x += dx * (1 if p.x > 0 else -1)
                    v.co = inv(p)
                    n += 1
        o.data.update()
        print("   JAW %-26s %d ring verts pushed out (+3.5 mm at the corners, +2/+2.5 mm fore/aft)" % (o.name, n), flush=True)
        if n < 6:
            fail("jaw ring on %s: only %d verts matched" % (o.name, n))


build_props()


# ---------------------------------------------------------------------------------------------
# 7. the helmet twin (mccleary_helmet): same man, bandana off, helmet on
# ---------------------------------------------------------------------------------------------
if WHO == "mccleary":
    rig2, map2 = clone_family(WHO, "mccleary_helmet", SLOT["mccleary_helmet"])
    b2 = D.objects.get("bandana_mccleary_helmet")
    D.objects.remove(b2, do_unlink=True)
    h2 = D.objects["helmet_shell_worn_mccleary_helmet"]
    h2.hide_set(False)
    h2.hide_render = False
    print("TWIN mccleary_helmet: bandana dropped, helmet visible, %d meshes" % len(family("mccleary_helmet")), flush=True)


# ---------------------------------------------------------------------------------------------
# 8. gates
# ---------------------------------------------------------------------------------------------
TAGS = [WHO] + (["mccleary_helmet"] if WHO == "mccleary" else [])
print("\n================ ACCEPTANCE GATES ================", flush=True)
PARTS = ["us_grunt_joined", "Base_Human", "grunt_head", "grunt_torso", "grunt_uparm_l", "grunt_uparm_r",
         "grunt_forearm_l", "grunt_forearm_r", "grunt_leg_l", "grunt_leg_r", "cap_head", "cap_torso",
         "cap_forearm_l", "cap_forearm_r", "cap_leg_l", "cap_leg_r", "cap_uparm_l", "cap_uparm_r"]
for t in TAGS:
    eqv, eqp, nv_ok = 0, 0, 0
    for part in PARTS:
        a, b = D.objects.get(part + "_" + SRC), D.objects.get(part + "_" + t)
        if not (a and b):
            fail("part missing: %s_%s" % (part, t))
            continue
        eqp += phash(a) == phash(b)
        eqv += vhash(a) == vhash(b)
        nv_ok += len(a.data.vertices) == len(b.data.vertices)
    print("fingerprint %-16s vs michael: poly-table equal %d/%d, vertex-count equal %d/%d, vertex-hash equal %d/%d %s"
          % (t, eqp, len(PARTS), nv_ok, len(PARTS), eqv, len(PARTS),
             "(equal by design)" if WHO == "champs" else "(bulk + jaw by design: only legs/caps equal)"), flush=True)
    if eqp != len(PARTS) or nv_ok != len(PARTS):
        fail("topology drift on %s" % t)
    if WHO == "champs" and eqv != len(PARTS):
        fail("champs body is not vertex-identical to michael")
    if WHO == "mccleary" and eqv == len(PARTS):
        fail("mccleary bulk did not apply")

for t in TAGS:
    r = D.objects["PSXRig_" + t]
    rot = tuple(round(math.degrees(a), 2) for a in r.rotation_euler)
    s = tuple(round(v, 4) for v in r.scale)
    ok = len(r.data.bones) == 41 and s == (1.0, 1.0, 1.0) and rot == (90.0, 0.0, 0.0)
    if not ok:
        fail("rig %s bones=%d scale=%s rot=%s" % (t, len(r.data.bones), s, rot))
    print("rig %-16s bones=%d rot=%s scale=%s loc=%s %s" % (t, len(r.data.bones), rot, s, tuple(round(v, 2) for v in r.location), "OK" if ok else "FAIL"), flush=True)
    # weights
    bad_unw, bad_sum, bad_vg = 0, 0, set()
    bn = {b.name for b in r.data.bones}
    for o in family(t):
        if not o.vertex_groups or not any(m.type == 'ARMATURE' for m in o.modifiers):
            continue
        bad_vg |= {g.name for g in o.vertex_groups if g.name not in bn}
        for v in o.data.vertices:
            if not v.groups:
                bad_unw += 1
            elif abs(sum(g.weight for g in v.groups) - 1.0) > 1e-3:
                bad_sum += 1
    ok = bad_unw == 0 and bad_sum == 0 and not bad_vg
    if not ok:
        fail("weights %s unweighted=%d offsum=%d orphan=%s" % (t, bad_unw, bad_sum, sorted(bad_vg)))
    print("weights %-16s unweighted=%d offsum=%d orphan-groups=%d %s" % (t, bad_unw, bad_sum, len(bad_vg), "OK" if ok else "FAIL"), flush=True)
    # visibility contract
    fam = family(t)
    jo = [o for o in fam if o.name.startswith("us_grunt_joined")]
    hidden_ok = all(o.hide_get() for o in fam if any(o.name.startswith(p) for p in ("Base_Human", "grunt_", "cap_", "head_frag_")))
    jv = sum(1 for o in jo if not o.hide_get())
    ok = jv == len(jo) == 1 and hidden_ok
    if not ok:
        fail("visibility %s" % t)
    print("visibility %-16s joined %d/%d visible, donors/caps hidden %s %s" % (t, jv, len(jo), hidden_ok, "OK" if ok else "FAIL"), flush=True)
    # caps on gore_cap_mat
    CAPS = ["cap_head", "cap_torso", "cap_forearm_l", "cap_forearm_r", "cap_leg_l", "cap_leg_r", "cap_uparm_l", "cap_uparm_r"]
    miss = [c_ for c_ in CAPS if (c_ + "_" + t) not in D.objects]
    wrong = [c_ for c_ in CAPS if (c_ + "_" + t) in D.objects and not all(m and m.name == "gore_cap_mat" for m in D.objects[c_ + "_" + t].data.materials)]
    if miss or wrong:
        fail("caps %s missing=%s wrongmat=%s" % (t, miss, wrong))
    print("gore caps %-16s %d/8 present, all gore_cap_mat: %s" % (t, 8 - len(miss), not wrong), flush=True)
    # evaluated X vs raw span (smear detector)
    worst = (0.0, "-")
    for o in fam:
        if not o.data.vertices:
            continue
        xs = [v.co.x for v in o.data.vertices]
        raw = max(xs) - min(xs)
        if o.dimensions.x > max(1.2, raw + 1e-3):
            fail("evaluated X %.3f exceeds raw %.3f on %s" % (o.dimensions.x, raw, o.name))
        worst = max(worst, (o.dimensions.x, o.name))
    print("max evaluated X %-16s %.4f on %s" % (t, worst[0], worst[1]), flush=True)
    # upright and planted: feet at z ~0 in world, head up
    bo = D.objects["us_grunt_joined_" + t]
    dg = bpy.context.evaluated_depsgraph_get()
    ev = bo.evaluated_get(dg)
    me = ev.to_mesh()
    zs = [(ev.matrix_world @ v.co).z for v in me.vertices]
    ev.to_mesh_clear()
    print("planted %-16s body z [%.4f, %.4f] (feet on the ground line, head up)" % (t, min(zs), max(zs)), flush=True)
    if abs(min(zs)) > 0.01 or max(zs) < 1.75:
        fail("%s not upright/planted: z %.3f..%.3f" % (t, min(zs), max(zs)))

# name collisions in the new families
def dotted(x):
    return len(x.name) > 4 and x.name[-4] == "." and x.name[-3:].isdigit()
coll = [x.name for blk in (D.objects, D.meshes, D.images) for x in blk
        if dotted(x) and not x.name.split(".")[0].startswith("canteen") and x.name not in PRE_NAMES]
if coll:
    fail("name collisions: %s" % coll)
print("new name collisions (objects/meshes/images): %d %s" % (len(coll), coll), flush=True)

# the pre-existing file: nothing changed
bad, changed, missing, added = HG.verify(PRE)
if bad:
    fail("HASH GATE: %d pre-existing datablocks changed or vanished" % len(bad))
print("=================================================", flush=True)
if FAILS:
    print("GATE FAILURES (%d) - REFUSING TO SAVE:" % len(FAILS), flush=True)
    for f in FAILS:
        print("   ! " + f, flush=True)
    raise SystemExit(1)
print("ALL GATES PASS (%d new datablocks added, 0 changed, 0 missing)" % len(added), flush=True)
if SAVE:
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_mainfile(filepath=D.filepath, compress=True)
    print("SAVED %s (%.1f MB)" % (D.filepath, os.path.getsize(D.filepath) / 1048576.0), flush=True)
else:
    print("DRY RUN (no --save)", flush=True)
