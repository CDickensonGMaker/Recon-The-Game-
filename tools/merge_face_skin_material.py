"""merge_face_skin_material.py - fold each grunt's skin material into his face material.

    blender -b -P tools/merge_face_skin_material.py

WHY THIS IS THE LOAD-BEARING STEP FOR THE RANDOM GRUNT GENERATOR
----------------------------------------------------------------
The head and the hands/forearms/neck currently use TWO materials:

    face_atlas_mat   -> the head, UV'd into one cell of the 10x7 face atlas
    skin_<name>      -> hands/forearms/neck, UV'd into a SKIN PATCH inside that
                        same cell (so the tone already matches by construction)

Both sample face_atlas_v3, and both live inside the SAME atlas cell. So a single
`uv1_offset` in Godot slides the face AND the skin to a different man together:

    mat.uv1_offset = Vector3(col * 0.1, row * (1.0/7.0), 0.0)   # 10 x 7 = 70 men

But `uv1_offset` is a MATERIAL property. With two materials, the offset moves the
face and leaves the hands behind - a white man's head on a black man's arms. They
must be ONE material for the generator to work at all.

After this runs: one material per grunt covering head + skin, one UV offset picks
the man, and the skin can never drift from the face again.
"""
import bpy, os

LINEUP = r"C:\Users\caleb\RECONgame\assets\us\characters\us_v3_soldier_lineup.blend"
TAGS = ["rifleman", "grenadier", "mg", "rto", "marksman", "pointman"]

bpy.ops.wm.open_mainfile(filepath=LINEUP)

for tag in TAGS:
    body = bpy.data.objects.get("us_grunt_joined_" + tag)
    if body is None:
        print("  %-10s MISSING" % tag)
        continue
    me = body.data

    # NOTE: all six bodies SHARE one face material datablock. Rename it on the first
    # man and the name-lookup breaks for the other five - they silently skip and you
    # ship one merged grunt and five broken ones. So match EITHER name.
    face_i = next((i for i, m in enumerate(me.materials)
                   if m and ("face_atlas" in m.name or m.name == "grunt_face_skin")), None)
    skin_i = next((i for i, m in enumerate(me.materials)
                   if m and m.name.startswith("skin_")), None)
    if face_i is None:
        print("  %-10s NO FACE MATERIAL - skipped" % tag)
        continue
    if skin_i is None:
        print("  %-10s already merged (no skin_ slot left)" % tag)
        continue

    # every skin face now points at the FACE material. its UVs already sit in the
    # skin patch of that man's cell, so it keeps sampling exactly the same pixels.
    moved = 0
    for p in me.polygons:
        if p.material_index == skin_i:
            p.material_index = face_i
            moved += 1

    face_mat = me.materials[face_i]
    face_mat.name = "grunt_face_skin"          # one material: head + hands + neck

    print("  %-10s %3d skin faces -> %s   (slot %d absorbed slot %d)"
          % (tag, moved, face_mat.name, face_i, skin_i))

bpy.ops.wm.save_mainfile()
print("\nsaved. head + skin are ONE material now.")
print("Godot can slide both to a new man with a single uv1_offset.")
