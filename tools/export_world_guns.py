"""export_world_guns.py - headless: export each armory gun as a world/drop model.

Unlike export_weapon_glb.py this CENTRES each gun on its own origin before
exporting, so a dropped weapon spawns at the pickup's position instead of
metres away at its armory rack coordinates. Marker empties are excluded --
a dropped gun only needs the mesh.

  blender -b weapons_us.blend -P tools/export_world_guns.py -- OUTDIR

The blend is read-only (never saved); it reads the LAST SAVED state.
"""
import bpy, sys, os, mathutils

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if not argv:
    raise SystemExit("ERROR: need OUTDIR")
OUTDIR = argv[0]
os.makedirs(OUTDIR, exist_ok=True)

# prefix -> game weapon id (matches data/weapons/*.tres where one exists)
GUNS = {
    "M16A1":                   "m16a1",
    "M14":                     "m14",
    "M60":                     "m60",
    "M79":                     "m79",
    "M70sniper":               "m70",
    "Colt45":                  "m1911",
    "Ithaca37":                "shotgun",
    "M26":                     "m26_grenade",
    "Thompson Sub Machinegun": "thompson",
}

groups = {}
for o in bpy.data.objects:
    if o.type != "MESH":
        continue
    groups.setdefault(o.name.split("_", 1)[0], []).append(o)

for prefix, wid in GUNS.items():
    objs = groups.get(prefix, [])
    if not objs:
        print("SKIP (no parts): %s" % prefix)
        continue

    # each gun's origin already sits on its geometry (set in the armory blend),
    # so dropping the rack position is all the centring this needs
    anchor = objs[0].matrix_world.translation.copy()
    saved = {o.name: o.matrix_world.copy() for o in objs}
    for o in objs:
        o.matrix_world = mathutils.Matrix.Translation(-anchor) @ o.matrix_world

    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]

    out = os.path.join(OUTDIR, wid + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=out, use_selection=True, export_format="GLB",
        export_yup=True, export_apply=True,
        export_animations=False, export_cameras=False, export_lights=False)

    for o in objs:
        o.matrix_world = saved[o.name]

    verts = sum(len(o.data.vertices) for o in objs)
    print("EXPORTED %-24s %2d parts %5d verts -> %s.glb (%.0f KB)" % (
        prefix, len(objs), verts, wid, os.path.getsize(out) / 1024))

print("DONE")
