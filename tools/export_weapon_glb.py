"""export_weapon_glb.py - Blender headless: extract per-weapon GLBs from a blend
full of loose, name-prefixed parts (M16A1_barrel, M16A1_stock, ...).

Groups objects by the token before the first underscore, selects each group,
and exports one self-contained .glb per weapon named by an id mapping.

Run (from a bash/cmd shell, NOT inside Blender):
  blender --background WEAPONS.blend --python tools/export_weapon_glb.py -- \
      OUTDIR PREFIX1=id1 PREFIX2=id2 ...
  # omit the PREFIX=id pairs to export EVERY prefix, id = prefix.lower()

Exports use +Y up and apply modifiers so Godot imports them upright and clean.
The blend is read-only; run reads the LAST SAVED state (save your blend first
if you have unsaved edits).
"""
import bpy
import sys
import os

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if not argv:
    print("ERROR: need OUTDIR [PREFIX=id ...]")
    sys.exit(1)

outdir = argv[0]
os.makedirs(outdir, exist_ok=True)
wanted = {}
for pair in argv[1:]:
    if "=" in pair:
        p, i = pair.split("=", 1)
        wanted[p] = i

# group mesh objects by name prefix
groups = {}
for o in bpy.data.objects:
    if o.type != "MESH":
        continue
    prefix = o.name.split("_", 1)[0]
    groups.setdefault(prefix, []).append(o)

targets = wanted if wanted else {p: p.lower() for p in groups}

for prefix, wid in targets.items():
    objs = groups.get(prefix, [])
    if not objs:
        print("SKIP (no parts):", prefix)
        continue
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    out = os.path.join(outdir, wid + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=out,
        use_selection=True,
        export_format="GLB",
        export_yup=True,
        export_apply=True,
    )
    print("EXPORTED %s (%d parts) -> %s" % (prefix, len(objs), out))

print("DONE")
