"""Read-only inventory of every RIG_* collection in the FP staging file, shaped
for extending tools/viewmodel_manifest.json.

    blender -b assets/player/arms/fp_arms_rifle.blend -P tools/probe_all_rigs.py

Per rig: armature, NLA clip tracks, bakeable parts (constraints or NLA), marker
empties, gun-root candidates, and worst part distance from hand.R at frame 0 of
each clip (cheap wreckage sniff - frame 0 only, the full gate runs at export).
"""
import bpy

for a in bpy.data.actions:
    a.use_frame_range = False

sc = bpy.context.scene
for coll in sorted(bpy.data.collections, key=lambda c: c.name):
    if not coll.name.startswith("RIG_"):
        continue
    objs = list(coll.objects)
    rig = next((o for o in objs if o.type == 'ARMATURE'), None)
    print(f"\n=== {coll.name} ({len(objs)} objects) ===")
    if rig is None:
        print("   NO ARMATURE")
        continue
    if rig.animation_data is None:
        print(f"   armature {rig.name}: NO animation_data")
        continue
    tracks = [t.name for t in rig.animation_data.nla_tracks if t.name != "ZZ_REVIEW_ROW"]
    print(f"   armature {rig.name}  clips: {sorted(set(tracks))}")
    parts = [o for o in objs if o.type != 'ARMATURE'
             and (o.constraints or (o.animation_data and o.animation_data.nla_tracks))]
    print(f"   parts: {[o.name for o in parts]}")
    markers = [o.name for o in objs if o.type == 'EMPTY'
               and any(k in o.name.lower() for k in ("muzzle", "sight_front", "sight_rear"))]
    # markers may live outside the collection - search globally by suffix too
    gun_tag = coll.name[4:]
    global_markers = [o.name for o in bpy.data.objects
                      if o.type == 'EMPTY' and gun_tag.lower() in o.name.lower()
                      and any(k in o.name.lower() for k in ("muzzle", "sight_front", "sight_rear"))]
    print(f"   markers in coll: {markers}  by name: {global_markers}")
    roots = [o.name for o in objs if o.type == 'MESH' and any(
        c.type == 'CHILD_OF' for c in o.constraints)]
    print(f"   gun-root candidates (mesh with CHILD_OF): {roots}")
    orphans = [o.name for o in objs if o.parent is None and o.type == 'MESH'
               and o not in [rig] and not o.constraints
               and not (o.animation_data and o.animation_data.nla_tracks)]
    print(f"   parentless static meshes: {orphans}")
