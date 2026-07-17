"""sync_radio_to_armory.py - push the RTO's fixed PRC-25 back into the gear armory.

    blender -b -P tools/sync_radio_to_armory.py

Caleb re-fitted the radio on the lineup's RTO (the pack was floating 10cm off the
ruck and the handset was 1.6 m off the man). The armory still holds the OLD radio,
so anything rebuilt from the armory would resurrect the broken one. This makes the
armory match the man.

The radio ships as THREE separate objects and must stay that way:

    prc25_pack      the set itself, strapped to the ruck
    prc25_antenna   the whip. NEVER let this into a *_worn height box - it tops out
                    a metre above his helmet and the normalizer will shrink the whole
                    grunt 34% to fit it. (tools/export_us_squad.py guards this now.)
    prc25_handset   RadioHandset.stowed_mesh. The game HIDES this one and shows a
                    copy in the player's hand when he grabs it. Weld it into the pack
                    and that swap becomes impossible.
"""
import bpy, os

LINEUP = r"C:\Users\caleb\RECONgame\assets\us\characters\us_v3_soldier_lineup.blend"
ARMORY = r"C:\Users\caleb\RECONgame\assets\us\props\gear_armory.blend"
PARTS = ["prc25_pack_rto", "prc25_antenna_rto", "prc25_handset_rto"]

# 1. pull the fixed meshes out of the lineup
with bpy.data.libraries.load(LINEUP, link=False) as (src, dst):
    dst.objects = [n for n in PARTS if n in src.objects]
fixed = {o.name: o for o in dst.objects if o}
print("pulled from the lineup: %s" % sorted(fixed))
if len(fixed) != len(PARTS):
    raise SystemExit("ABORT: expected %s, got %s" % (PARTS, sorted(fixed)))

# keep the mesh data alive across the file switch
keep = {}
for n, o in fixed.items():
    me = o.data.copy()
    me.use_fake_user = True
    keep[n.replace("_rto", "")] = me
    print("  %-22s %3d verts" % (n, len(me.vertices)))

# 2. open the armory and swap the old radio out
bpy.ops.wm.open_mainfile(filepath=ARMORY)
print("\nopened armory: %s" % os.path.basename(bpy.data.filepath))

old = [o for o in bpy.data.objects if o.type == 'MESH' and 'prc25' in o.name.lower()]
print("removing old radio parts: %s" % [o.name for o in old])
for o in old:
    bpy.data.objects.remove(o, do_unlink=True)

# the meshes we carried over were dropped on file-open; re-pull them
with bpy.data.libraries.load(LINEUP, link=False) as (src, dst):
    dst.objects = [n for n in PARTS if n in src.objects]

col = bpy.context.scene.collection
for o in dst.objects:
    if o is None:
        continue
    o.name = o.name.replace("_rto", "")     # armory holds the canonical, untagged part
    o.data.name = o.name
    o.parent = None                          # armory parts are free-standing
    o.matrix_world = o.matrix_world          # keep the authored transform
    col.objects.link(o)
    print("  armory now holds %-22s %3d verts" % (o.name, len(o.data.vertices)))

bpy.ops.wm.save_mainfile()
print("\nSAVED %s - armory matches the man." % os.path.basename(bpy.data.filepath))
