import bpy, sys, os
p = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=p)
print("\n=== %s : marking structure as Godot will see it ===" % os.path.basename(p))
for v in ("VARIANT_A", "VARIANT_B", "VARIANT_C"):
    o = bpy.data.objects.get(v)
    if o is None:
        print("  %s ABSENT - _pick_markings would find nothing" % v); continue
    kids = list(o.children)
    t = sum(sum(len(pl.vertices) - 2 for pl in k.data.polygons) for k in kids if k.type == 'MESH')
    mats = sorted({m.name for k in kids if k.type == 'MESH' for m in k.data.materials if m})
    print("  %-10s type=%-6s children=%d  tris=%-4d  mats=%s"
          % (v, o.type, len(kids), t, mats))
    for k in kids:
        uv = k.data.uv_layers.active
        us = sorted({(round(l.uv[0], 4), round(l.uv[1], 4)) for l in uv.data}) if uv else []
        print("      %-24s %s  %d tris  %d unique UVs" % (k.name, k.type,
              sum(len(pl.vertices) - 2 for pl in k.data.polygons), len(us)))
m = bpy.data.objects.get("MARK_ARMY")
print("  MARK_ARMY  parent=%s tris=%d (always visible - the boom ARMY decal)"
      % (m.parent, sum(len(pl.vertices) - 2 for pl in m.data.polygons)) if m else "  MARK_ARMY ABSENT")
print("\n  images: %s" % [(i.name, i.size[0], i.size[1]) for i in bpy.data.images if i.size[0]])
