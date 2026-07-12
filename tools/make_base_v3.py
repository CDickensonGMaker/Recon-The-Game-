"""Clone the grunt truth source and cut the GEAR out of the body mesh.

    blender -b -P tools/make_base_v3.py

WHY: `us_grunt_joined` in us_grunt_v2.blend is not a body - it is a body with the
helmet, bandolier and ruck WELDED IN (materials MitchellCamo / Webbing / bugjuice
/ CigPack / BandolierCloth / Fatigue / AluFrame; bounds reach z=1.822, above the
1.74 head-top, and y=0.247 into the ruck volume). Two consequences:

  1. HURTBOX: HitzoneBuilder excludes gear BY MESH NAME. "us_grunt_joined" is not
     a gear name, so the helmet inflates the head hull and the ruck inflates the
     torso hull. The "gear never enters the hurtbox" contract is silently broken.
  2. MODULARITY: no variant can drop the ruck, because the ruck IS the body. You
     cannot build an RTO, a pilot or a civilian from this.

(The separate helmet_camo_shell / ruck_bag / bandolier objects are HIDDEN gib
copies - they fly off when a region pops. They are not the live gear. We keep
them exactly as they are.)

WHAT THIS DOES: writes a NEW blend (us_base_v3.blend). The shipping truth source
is not touched. In the clone:
  * the live gear is cut out of the joined mesh into its own BONE-PARENTED meshes
    (rigid, no skin, no vertex groups) named with _GEAR_NAME_HINTS words
  * `us_grunt_joined` is left as BODY ONLY
Bone-parented gear has no skin, so probe_silhouette still counts parts = 1, and
the hitzone harvester now skips it by name - which is the whole point.
"""
import bpy, bmesh, os
from mathutils import Vector, Matrix

SRC = r"C:\Users\caleb\RECONgame\art_source\characters\base_psx\us_grunt_v2.blend"
DST = r"C:\Users\caleb\RECONgame\art_source\characters\base_psx\us_base_v3.blend"
BODY = "us_grunt_joined"
RIG = "PSXRig"

# gear group -> (materials welded into the body, new mesh name). Every new name
# carries a _GEAR_NAME_HINTS word or it lands back in the hurtbox.
GEAR_GROUPS = [
    ("helmet_shell_worn", ["MitchellCamo", "Webbing", "bugjuice", "CigPack"]),
    ("bandolier_worn",    ["BandolierCloth"]),
    ("ruck_pack_worn",    ["Fatigue", "AluFrame"]),
]
BODY_MATS = ["us_grunt_mat", "face_atlas_mat", "gore_cap_mat"]


def dominant_bone(ob, vert_idx):
    """Which bone actually carries this geometry (so we bone-parent it there)."""
    tot = {}
    for vi in vert_idx:
        v = ob.data.vertices[vi]
        for g in v.groups:
            n = ob.vertex_groups[g.group].name
            tot[n] = tot.get(n, 0.0) + g.weight
    return max(tot, key=tot.get) if tot else "mixamorig:Spine2"


def main():
    bpy.ops.wm.open_mainfile(filepath=SRC)
    rig = bpy.data.objects[RIG]
    rig.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    body = bpy.data.objects[BODY]
    mats = [s.material.name if s.material else "?" for s in body.material_slots]

    print("BEFORE: %s has %d verts, %d faces, materials %s"
          % (BODY, len(body.data.vertices), len(body.data.polygons), mats))

    made = []
    for new_name, gear_mats in GEAR_GROUPS:
        idxs = {i for i, m in enumerate(mats) if m in gear_mats}
        faces = [p for p in body.data.polygons if p.material_index in idxs]
        if not faces:
            print("  (no faces for %s - skipping)" % new_name)
            continue
        vids = sorted({vi for p in faces for vi in p.vertices})
        bone = dominant_bone(body, vids)

        # copy those faces out into a fresh mesh
        bm = bmesh.new()
        bm.from_mesh(body.data)
        bm.faces.ensure_lookup_table()
        keep = [f for f in bm.faces if f.material_index in idxs]
        drop = [f for f in bm.faces if f.material_index not in idxs]
        bmesh.ops.delete(bm, geom=drop, context='FACES')
        me = bpy.data.meshes.new(new_name)
        bm.to_mesh(me)
        bm.free()
        for m in body.data.materials:
            me.materials.append(m)
        ob = bpy.data.objects.new(new_name, me)
        bpy.context.scene.collection.objects.link(ob)

        # The cut verts are in the BODY's LOCAL space, and the body carries a
        # non-identity transform (a 1.13 Y-scale!). Wear the body's matrix so the
        # gear lands exactly where it was welded.
        ob.matrix_world = body.matrix_world.copy()
        keep_world = ob.matrix_world.copy()

        # RIGID bone attach: no armature modifier, no vertex groups. That keeps it
        # out of probe_silhouette's skinned-part count AND lets the hitzone
        # harvester skip it by name.
        # Set matrix_world AFTER parenting and let Blender solve the basis - bone
        # parenting adds a bone-length tail offset, and hand-rolling the inverse
        # is how the gear ended up in a pile at his feet.
        ob.parent = rig
        ob.parent_type = 'BONE'
        ob.parent_bone = bone
        ob.matrix_parent_inverse = Matrix.Identity(4)
        bpy.context.view_layer.update()
        ob.matrix_world = keep_world
        bpy.context.view_layer.update()
        made.append((new_name, bone, len(me.vertices), len(me.polygons)))

    # strip the gear faces OUT of the body
    gear_idxs = {i for i, m in enumerate(mats)
                 if any(m in g for _, g in GEAR_GROUPS for g in [g])}
    gear_idxs = {i for i, m in enumerate(mats)
                 if m not in BODY_MATS}
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.faces.ensure_lookup_table()
    doomed = [f for f in bm.faces if f.material_index in gear_idxs]
    bmesh.ops.delete(bm, geom=doomed, context='FACES')
    bm.to_mesh(body.data)
    bm.free()
    body.data.update()

    ws = [body.matrix_world @ v.co for v in body.data.vertices]
    print("\nAFTER: %s = BODY ONLY, %d verts, %d faces"
          % (BODY, len(body.data.vertices), len(body.data.polygons)))
    print("  bounds z %.3f..%.3f  y %.3f..%.3f  (head-top 1.74, ruck was y>0.10)"
          % (min(w.z for w in ws), max(w.z for w in ws),
             min(w.y for w in ws), max(w.y for w in ws)))
    print("\n%-20s %-22s %6s %6s" % ("cut out ->", "bone-parented to", "verts", "faces"))
    for n, b, v, f in made:
        print("%-20s %-22s %6d %6d" % (n, b.replace("mixamorig:", ""), v, f))

    bpy.ops.wm.save_as_mainfile(filepath=DST)
    print("\nsaved CLONE:", DST)
    print("truth source untouched:", SRC)


if __name__ == "__main__":
    main()
