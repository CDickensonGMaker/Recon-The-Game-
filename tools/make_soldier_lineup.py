# make_soldier_lineup.py - review lineup: import the new soldier variants (plus
# the two base characters for comparison) into one scene, spaced in a row with
# floor labels, and save to art_source/characters/lineup_review.blend.
# NEVER touches master blends - this writes a NEW review file only.
# Run: & "C:\Program Files\Blender Foundation\Blender 5.0\blender.exe" -b --python tools/make_soldier_lineup.py
import bpy
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHAR = os.path.join(ROOT, "assets", "models", "characters")
OUT = os.path.join(ROOT, "art_source", "characters", "lineup_review.blend")

LINEUP = [
    ("us_grunt_v2", "US BASE (M16)"),
    ("us_grunt_m60", "US M60"),
    ("us_grunt_m79", "US M79"),
    ("us_grunt_m14", "US M14"),
    ("vc_guerilla", "VC BASE (AK)"),
    ("vc_guerilla_m16", "VC M16 (captured)"),
    ("vc_guerilla_rpg", "VC RPG-2"),
    ("vc_guerilla_mosin", "VC MOSIN"),
    ("vc_guerilla_ppsh", "VC PPSH"),
    ("vc_guerilla_rpd", "VC RPD"),
]
SPACING = 1.4

# clean default scene
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)

for i, (unit, label) in enumerate(LINEUP):
    path = os.path.join(CHAR, unit + ".glb")
    if not os.path.exists(path):
        print("[LINEUP] missing:", path)
        continue
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new_objs = [o for o in bpy.data.objects if o not in before]
    coll = bpy.data.collections.new(unit)
    bpy.context.scene.collection.children.link(coll)
    x = i * SPACING
    for o in new_objs:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        coll.objects.link(o)
        if o.parent is None:
            o.location.x += x
    # floor label
    txt = bpy.data.curves.new(unit + "_label", type='FONT')
    txt.body = label
    txt.size = 0.14
    txt.align_x = 'CENTER'
    tob = bpy.data.objects.new(unit + "_label", txt)
    tob.location = (x, -0.55, 0.01)
    coll.objects.link(tob)
    print("[LINEUP] %s at x=%.1f (%d objects)" % (unit, x, len(new_objs)))

bpy.context.scene.frame_set(1)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("[LINEUP] saved ->", OUT)
