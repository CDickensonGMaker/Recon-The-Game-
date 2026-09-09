"""Re-export fsb_main_v3.glb from the CANON blend, without rebuilding the firebase.

    blender --background --python tools/reexport_firebase_v3.py

Why this exists, and read it before reaching for gen_firebase_v3.py instead:

`gen_firebase_v3.main()` starts with `read_homefile(use_empty=True)` and builds the whole
compound procedurally from constants. It has no chow hall, no medical complex and no staged
crews - those were merged into the blend afterwards by separate tools - and it never calls
`export_firebase()` at all. Running it does not re-export the firebase; it builds a DIFFERENT,
older one. The kit's own README says the same thing: "those generators are legacy and predate
v3.2." The generator's comment at export_firebase() records what happened the last time source
and export were confused: "that purge and save is what destroyed the medical complex on
2026-07-31."

So the shipping GLB has exactly one source - `kit/firebase_v3.2.blend` - and two export-time
transforms, both generated and undone inside export_firebase(): the `-colonly` twins, and
(from 2026-09-09) the vegetation swap that plants the real species models where the blend's
14 baked CARD groups stand. `refit_firebase_veg.py` explains why that is an export step and
not a blend edit. The blend still holds the cards; the GLB never does.

IT NEVER SAVES THE BLEND. Saving is the artist's call, in Blender, with undo.
"""
import hashlib
import json
import os
import struct
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_firebase as gf          # noqa: E402
import gen_firebase_v3 as v3       # noqa: E402

CANON_BLEND = os.path.join(gf.KIT_DIR, "firebase_v3.2.blend")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    blend = CANON_BLEND
    for i, a in enumerate(argv):
        if a == "--blend" and i + 1 < len(argv):
            blend = argv[i + 1]
    if not os.path.exists(blend):
        raise SystemExit("canon blend not found: %s" % blend)

    bpy.ops.wm.open_mainfile(filepath=blend)
    sc = bpy.context.scene
    meshes = [o for o in sc.objects if o.type == 'MESH']
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes)
    print("opened %s: %d object(s), %d mesh(es), %d tris"
          % (os.path.basename(blend), len(sc.objects), len(meshes), tris))

    # The census the destructible contract turns on, BEFORE the export, so a rename shows up
    # here rather than as a silent bulletproof structure three hours later in the game.
    veg = [o.name for o in meshes if o.name.startswith("fb_veg_")]
    segs = [o.name for o in meshes if o.name.startswith("fb_sbg_seg")]
    print("parapet meshes: %d   fb_veg_ groups: %d" % (len(segs), len(veg)))
    strays = [n for n in segs if n.split("fb_sbg_seg")[1].count("_") > 1 or "." in n]
    if strays:
        print("STRAY parapet duplicates (ship INVULNERABLE - not in the manifest): %s"
              % ", ".join(sorted(strays)))

    size = v3.export_firebase()
    print("re-export done: %.2f MB" % size)

    # HIS TEXTURE LAW (2026-08-18): no embedded image over 1MB. The BLEND holds the
    # full-size sheets, so every export restores them and the shrink has to run again -
    # that is why a bare re-export comes out ~3.9MB heavier than the file it replaces, and
    # it is not a defect in the export.
    #
    # THE BYTE-FOR-BYTE CLAIM IS RETIRED. The pipeline is deterministic against ITSELF, not
    # against a file exported by older code: three separate 2026-09-09 fixes each moved the
    # hash by one node. Re-derive the md5 when you need one; never quote a stored one.
    import shrink_oversized_textures as shrink
    glb = os.path.join(v3.ROOT, "fsb_main_v3.glb")
    res = shrink.process(glb, True)
    if res is None:
        print("textures: nothing over 1MB")
    else:
        old_b, new_b, swaps = res
        print("textures: %d image(s) halved, %.2f -> %.2f MB"
              % (len(swaps), old_b / 1048576.0, new_b / 1048576.0))

    audit_colonly(glb)


def audit_colonly(glb):
    """Post-flight on the SHIPPED BYTES. gen_firebase_v3.assert_colonly_terminal() guards the
    session before the exporter runs; this reads the file that actually goes to Godot, because
    the two have disagreed before."""
    data = open(glb, "rb").read()
    off = 12
    doc = None
    while off < len(data):
        ln, ty = struct.unpack_from("<II", data, off)
        if ty == 0x4E4F534A:
            doc = json.loads(data[off + 8:off + 8 + ln].decode("utf-8"))
            break
        off += 8 + ln
    names = [n.get("name", "") for n in doc.get("nodes", [])]
    strays = [n for n in names if "-colonly" in n and not n.endswith("-colonly")]
    total = sum(1 for n in names if "-colonly" in n)
    print("colonly contract: %d node(s), %d terminal, %d stray %s"
          % (total, total - len(strays), len(strays), strays or ""))
    print("shipped: %d bytes, md5 %s, %d nodes"
          % (len(data), hashlib.md5(data).hexdigest(), len(names)))
    if strays:
        raise RuntimeError("SHIPPED a -colonly marker that is not at the end of the name: %s"
                           % ", ".join(strays))


if __name__ == "__main__":
    main()
