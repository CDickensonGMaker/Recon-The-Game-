"""Export the shipping UH-1 from huey_v3.blend to assets/us/vehicles/huey_v3.glb.

    blender -b assets/us/vehicles/huey_v3.blend -P tools/export_huey_v3.py

WHAT SHIPS. Only the collections below. INT_TRANSPORT is 414 TR_pax staging
objects and must never export; the same goes for CREW_PREVIEW, the workbenches
and the side-by-side preview copy.

All three VARIANT_* marking sets are forced visible for the export - the game
picks one per airframe at spawn (helicopter.gd::_pick_markings), so every set
has to be present in the GLB.
"""
import bpy, os, sys

EXPORT_COLLECTIONS = [
    "AIRFRAME_SHARED",        # hull, skids, rotors, cockpit
    "CABIN_SEATING_SHARED",   # centre bench + seat_pax_1..8 + seat_bench_1..6
    "INT_GUNSHIP",            # pintles, M60s, gunner pads
    "CARGO_OPTIONAL",         # rack, ammo, crates
    "DOORS_PARKED",           # cargo doors (removed, but carried for the variant)
    "DETAIL_KIT",             # pitot, antennas, tail skid, exhaust
    "MARKINGS",               # ARMY on the boom
    "VARIANT_A", "VARIANT_B", "VARIANT_C",
]

OUT = os.path.join(os.path.dirname(bpy.data.filepath), "huey_v3.glb")

vl = bpy.context.view_layer


def layer_of(coll):
    def walk(lc):
        if lc.collection == coll:
            return lc
        for ch in lc.children:
            r = walk(ch)
            if r:
                return r
    return walk(vl.layer_collection)


for o in bpy.data.objects:
    o.select_set(False)

picked = 0
for cname in EXPORT_COLLECTIONS:
    coll = bpy.data.collections.get(cname)
    if coll is None:
        print("[EXPORT] WARNING: collection %s missing" % cname)
        continue
    lc = layer_of(coll)
    if lc is not None:
        lc.hide_viewport = False
        lc.exclude = False
    taken = 0
    for o in coll.objects:
        # PV_* are the side-by-side preview copy parked 18m away - never ship them
        if o.name.startswith("PV_"):
            continue
        o.hide_viewport = False
        o.hide_set(False)
        o.select_set(True)
        picked += 1
        taken += 1
    print("[EXPORT] %-22s %3d objects (%d skipped)" % (cname, taken, len(coll.objects) - taken))

if picked == 0:
    print("[EXPORT] FATAL: nothing selected")
    sys.exit(1)

bpy.context.view_layer.objects.active = next(o for o in bpy.data.objects if o.select_get())

bpy.ops.export_scene.gltf(
    filepath=OUT,
    export_format='GLB',
    use_selection=True,
    export_apply=True,          # bake modifiers: the ARMY decal is a shrinkwrap
    export_yup=True,
    export_animations=False,    # rotors are code-driven; clips live in anim_library.glb
    export_materials='EXPORT',
    export_cameras=False,
    export_lights=False,
)
print("[EXPORT] wrote %s  %.2f MB  (%d objects)"
      % (OUT, os.path.getsize(OUT) / 1048576.0, picked))
