"""Convert a downloaded PSX prop pack into individual game-ready .glb props.

    blender -b -P tools/import_psx_pack.py -- <stage_dir> <out_subdir>

One GLB PER OBJECT, named after the object, because that is how every other prop
kit in this repo is consumed - ai_stress_arena loads
"res://assets/world/vegetation/fern_a.glb" by name, not a pack containing a fern.
A single monolithic pack GLB would have to be instantiated whole and then pruned
at runtime, on every placement.

Textures are PACKED into each GLB. The packs ship loose PNGs next to the FBX and
those paths do not survive the move into assets/, so an unpacked export renders
untextured - the failure looks like a modelling mistake and is not one.

PSX filtering is NOT applied here. Godot's importer owns filtering, and the
material work in this project sets TEXTURE_FILTER_NEAREST engine-side.
"""
import os
import sys

import bpy

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
if len(argv) < 2:
    sys.exit("usage: -- <stage_dir> <out_subdir>")
STAGE, OUT_SUB = argv[0], argv[1]

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recon_paths import ASSETS

OUT_DIR = os.path.join(ASSETS, "world", "props", "psx_kit", OUT_SUB)

# Below this a "mesh" is a stray vertex or an artist's leftover empty, not a prop.
MIN_VERTS = 8


def _safe(name):
    keep = "".join(c if (c.isalnum() or c in "_-") else "_" for c in name)
    return keep.strip("_").lower() or "prop"


def _clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _import(path):
    low = path.lower()
    if low.endswith(".fbx"):
        bpy.ops.import_scene.fbx(filepath=path)
    elif low.endswith(".blend"):
        with bpy.data.libraries.load(path, link=False) as (src, dst):
            dst.objects = list(src.objects)
        for o in dst.objects:
            if o is not None:
                bpy.context.scene.collection.objects.link(o)
    elif low.endswith((".glb", ".gltf")):
        bpy.ops.import_scene.gltf(filepath=path)
    else:
        return False
    return True


def _export_object(ob, out_dir, seen):
    name = _safe(ob.name)
    # Two objects called "Cube" in one pack must not silently overwrite each other.
    n, i = name, 2
    while n in seen:
        n = "%s_%d" % (name, i)
        i += 1
    seen.add(n)

    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob

    # Drop the prop to its own origin so it places on the ground at y=0 rather
    # than wherever it happened to sit in the artist's scene.
    prev = ob.matrix_world.copy()
    mn_z = min((ob.matrix_world @ v.co).z for v in ob.data.vertices)
    ob.location.z -= mn_z
    bpy.context.view_layer.update()

    out = os.path.join(out_dir, n + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=out,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_animations=False,
        export_materials='EXPORT',
        export_image_format='AUTO',
        export_cameras=False,
        export_lights=False,
        export_draco_mesh_compression_enable=False,
    )
    ob.matrix_world = prev
    return out


def main():
    # Packs commonly ship the SAME mesh as both .fbx and .glb. Importing both
    # yields prop and prop_2 - visually identical, and the duplicate is invisible
    # until someone places it expecting a variant. One source per stem wins, glTF
    # first because it needs no conversion.
    by_stem = {}
    for root, _, files in os.walk(STAGE):
        for f in files:
            if not f.lower().endswith((".fbx", ".blend", ".glb", ".gltf")):
                continue
            if "preview" in f.lower():
                continue
            stem = os.path.splitext(f)[0].lower()
            path = os.path.join(root, f)
            rank = 0 if f.lower().endswith((".glb", ".gltf")) else 1
            if stem not in by_stem or rank < by_stem[stem][0]:
                by_stem[stem] = (rank, path)
    sources = [p for _, p in by_stem.values()]
    if not sources:
        sys.exit("no mesh source under %s" % STAGE)

    os.makedirs(OUT_DIR, exist_ok=True)
    seen = set()
    total = 0
    for src in sorted(sources):
        _clear()
        if not _import(src):
            continue
        meshes = [o for o in bpy.data.objects
                  if o.type == 'MESH' and len(o.data.vertices) >= MIN_VERTS]
        print("  %s -> %d object(s)" % (os.path.basename(src), len(meshes)),
              flush=True)
        for ob in meshes:
            _export_object(ob, OUT_DIR, seen)
            total += 1
    print("psx_kit/%s: %d props -> %s" % (OUT_SUB, total, OUT_DIR))


if __name__ == "__main__":
    main()
