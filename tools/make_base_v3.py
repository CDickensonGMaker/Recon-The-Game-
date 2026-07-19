"""Clone the grunt truth source and cut the GEAR out of the body mesh.

    blender -b -P tools/make_base_v3.py

WHY: `us_grunt_joined` in us_grunt_v2.blend is not a body - it is a body with the
helmet, bandolier, ruck and a belt pouch WELDED IN (bounds reach z=1.822, above
the 1.74 head-top, and y=0.247 into the ruck volume). Two consequences:

  1. HURTBOX: HitzoneBuilder excludes gear BY MESH NAME. "us_grunt_joined" is not
     a gear name, so the helmet inflated the head hull by 2cm and the ruck the
     torso hull by 11cm. The "gear never enters the hurtbox" contract was being
     silently broken - you could shoot a man's backpack and hurt his spine.
  2. MODULARITY: no variant can drop the ruck, because the ruck IS the body. You
     cannot build an RTO, a pilot or a civilian from this.

(The separate helmet_camo_shell / ruck_bag / bandolier objects are HIDDEN gib
copies - they fly off when a region pops. They are not the live gear. Untouched.)

WHAT THIS DOES: writes a NEW blend (us_base_v3.blend). The shipping truth source
is NOT touched. In the clone:
  * live gear is cut out of the joined mesh into its own BONE-PARENTED meshes
    (rigid, no skin, no vertex groups) named with _GEAR_NAME_HINTS words
  * `us_grunt_joined` is left as BODY ONLY
Bone-parented gear has no skin, so probe_silhouette still counts parts = 1, and
the hitzone harvester now skips it by name - which is the whole point.

TWO PASSES, because the modeller was not consistent:
  pass 1 - gear with its OWN materials (MitchellCamo, BandolierCloth, ...)
  pass 2 - gear wearing the BODY's material (a belt pouch shaded with the same
           OD-green fatigue material). It gives itself away by being a DETACHED,
           TINY island: every anatomical island here is 13+ faces. Pass 2 must run
           AFTER pass 1's faces are stripped, or the gear itself reads as islands.
"""
import bpy, bmesh, os, sys
from mathutils import Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recon_paths import US_BASE_V3, dead

# SRC (us_grunt_v2.blend) is GONE and has no copy. This tool BUILDS us_base_v3
# from it — and us_base_v3 has since been hand-worked and is the truth source for
# every US model. Running this would overwrite that. Input dead => tool inert.
# Do NOT repoint SRC at DST: that makes the builder eat its own output.
SRC = None
DST = US_BASE_V3
BODY = "us_grunt_joined"
RIG = "PSXRig"

# DISARMED 2026-07-13 (Drift Council, bead DRIFT-8).
#
# The premise above is DEAD. SRC was deleted by the Summoner on 2026-07-13 during his
# art-folder cleanup, and DST is no longer this script's disposable output - it is
# HAND-AUTHORED TRUTH. He has since built 7 rigs, 361 meshes, a SQUAD collection of
# 6 MOS and _BAG_TEMPLATES inside DST, by hand. None of it is reproducible from SRC.
#
# A plain run would open a stale SRC and save_as_mainfile over DST, silently
# destroying all of it. Today that only fails safe because SRC is absent - restore
# SRC "to fix the tool" and you arm the gun.
#
# This guard is the safety, not the missing file.
if os.path.exists(DST):
    sys.exit(
        "\n*** REFUSING TO RUN ***\n"
        f"{DST}\nexists, and is HAND-AUTHORED TRUTH - not this script's output.\n"
        "Overwriting it destroys the SQUAD collection, the 7 rigs and _BAG_TEMPLATES.\n"
        "If you genuinely mean to regenerate the base from scratch, move DST aside\n"
        "yourself, deliberately, with your own hands. This script will not do it for you.\n"
    )

# pass 1: gear group -> materials welded into the body. Every new name carries a
# _GEAR_NAME_HINTS word or the piece lands right back in the hurtbox.
GEAR_GROUPS = [
    ("helmet_shell_worn", ["MitchellCamo", "Webbing", "bugjuice", "CigPack"]),
    ("bandolier_worn",    ["BandolierCloth"]),
    ("ruck_pack_worn",    ["Fatigue", "AluFrame"]),
]
BODY_MATS = ["us_grunt_mat", "face_atlas_mat", "gore_cap_mat"]

# pass 2
ISLAND_MAX_FACES = 8     # smallest anatomical island on this body is 13 faces
MAX_ISLAND_GEAR = 3      # cut more than this and the rule is wrong - abort, look.


def dominant_bone(ob, vert_idx):
    """Which bone actually carries this geometry (so we bone-parent it there)."""
    tot = {}
    for vi in vert_idx:
        for g in ob.data.vertices[vi].groups:
            n = ob.vertex_groups[g.group].name
            tot[n] = tot.get(n, 0.0) + g.weight
    return max(tot, key=tot.get) if tot else "mixamorig:Spine2"


def cut_out(body, rig, new_name, face_ids, made):
    """Copy `face_ids` out of the body into a rigid bone-parented gear mesh."""
    vids = sorted({vi for i in face_ids for vi in body.data.polygons[i].vertices})
    bone = dominant_bone(body, vids)

    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in face_ids],
                     context='FACES')
    me = bpy.data.meshes.new(new_name)
    bm.to_mesh(me)
    bm.free()
    for m in body.data.materials:
        me.materials.append(m)

    ob = bpy.data.objects.new(new_name, me)
    bpy.context.scene.collection.objects.link(ob)

    # The cut verts are in the BODY's LOCAL space, and the body carries a
    # NON-IDENTITY transform (a 1.13 Y-scale). Wear the body's matrix or the gear
    # comes out squashed and in the wrong place.
    ob.matrix_world = body.matrix_world.copy()
    keep_world = ob.matrix_world.copy()

    # RIGID bone attach: no armature modifier, no vertex groups. That keeps it out
    # of probe_silhouette's skinned-part count and lets the harvester skip it.
    # Set matrix_world AFTER parenting and let Blender solve the basis - bone
    # parenting adds a bone-LENGTH tail offset, and hand-rolling that inverse is
    # exactly how the gear ended up in a pile at his feet the first time.
    ob.parent = rig
    ob.parent_type = 'BONE'
    ob.parent_bone = bone
    ob.matrix_parent_inverse = Matrix.Identity(4)
    bpy.context.view_layer.update()
    ob.matrix_world = keep_world
    bpy.context.view_layer.update()

    made.append((new_name, bone, len(me.vertices), len(me.polygons)))


def strip(body, face_ids):
    """Delete those faces from the body."""
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index in face_ids],
                     context='FACES')
    bm.to_mesh(body.data)
    bm.free()
    body.data.update()


def islands(body):
    """Connected face islands of the body, as sets of face indices."""
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.faces.ensure_lookup_table()
    seen, out = set(), []
    for f in bm.faces:
        if f in seen:
            continue
        stack, cur = [f], set()
        while stack:
            c = stack.pop()
            if c in seen:
                continue
            seen.add(c)
            cur.add(c.index)
            for e in c.edges:
                for lf in e.link_faces:
                    if lf not in seen:
                        stack.append(lf)
        out.append(cur)
    bm.free()
    return out


def main():
    dead("us_grunt_v2.blend")
    bpy.ops.wm.open_mainfile(filepath=SRC)
    rig = bpy.data.objects[RIG]
    rig.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    body = bpy.data.objects[BODY]
    mats = [s.material.name if s.material else "?" for s in body.material_slots]

    print("BEFORE: %s has %d verts, %d faces" %
          (BODY, len(body.data.vertices), len(body.data.polygons)))

    made = []

    # ---- pass 1: gear with its own materials -------------------------------
    for new_name, gear_mats in GEAR_GROUPS:
        idxs = {i for i, m in enumerate(mats) if m in gear_mats}
        fids = {p.index for p in body.data.polygons if p.material_index in idxs}
        if not fids:
            print("  (no faces for %s - skipping)" % new_name)
            continue
        cut_out(body, rig, new_name, fids, made)

    gear_idxs = {i for i, m in enumerate(mats) if m not in BODY_MATS}
    strip(body, {p.index for p in body.data.polygons
                 if p.material_index in gear_idxs})

    # ---- pass 2: gear wearing the body's material (runs on the STRIPPED body) --
    small = [i for i in islands(body) if len(i) <= ISLAND_MAX_FACES]
    if len(small) > MAX_ISLAND_GEAR:
        raise SystemExit("ABORT: %d islands under %d faces. That is not gear, that "
                         "is a body built differently. Look before cutting."
                         % (len(small), ISLAND_MAX_FACES))
    for n, isl in enumerate(small):
        name = "pouch_belt_worn" if len(small) == 1 else "pouch_belt_worn_%d" % n
        cut_out(body, rig, name, isl, made)
    if small:
        strip(body, set().union(*small))

    # ---- report ------------------------------------------------------------
    ws = [body.matrix_world @ v.co for v in body.data.vertices]
    print("\nAFTER: %s = BODY ONLY, %d verts, %d faces" %
          (BODY, len(body.data.vertices), len(body.data.polygons)))
    print("  bounds z %.3f..%.3f  y %.3f..%.3f  (head-top 1.74, ruck was y>0.10)"
          % (min(w.z for w in ws), max(w.z for w in ws),
             min(w.y for w in ws), max(w.y for w in ws)))
    print("\n%-20s %-20s %6s %6s" % ("cut out ->", "bone-parented to", "verts", "faces"))
    for n, b, v, f in made:
        print("%-20s %-20s %6d %6d" % (n, b.replace("mixamorig:", ""), v, f))

    bpy.ops.wm.save_as_mainfile(filepath=DST)
    print("\nsaved CLONE:", DST)
    print("truth source untouched:", SRC)


if __name__ == "__main__":
    main()
