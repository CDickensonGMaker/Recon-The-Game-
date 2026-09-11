import bpy, os, json, struct
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "probe_alpha.glb")

def variant(name, mode, use_math, thresh=0.5):
    img = bpy.data.images.new(name + "_img", 8, 8, alpha=True)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage"); t.image = img
    nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    if use_math:
        mth = nt.nodes.new("ShaderNodeMath")
        mth.operation = 'ROUND' if use_math == 'ROUND' else 'GREATER_THAN'
        if use_math != 'ROUND':
            mth.inputs[1].default_value = thresh
        nt.links.new(t.outputs["Alpha"], mth.inputs[0])
        nt.links.new(mth.outputs[0], b.inputs["Alpha"])
    else:
        nt.links.new(t.outputs["Alpha"], b.inputs["Alpha"])
    if mode and hasattr(m, "surface_render_method"):
        m.surface_render_method = mode
    return m

bpy.ops.wm.read_factory_settings(use_empty=True)
print("props on Material:", [p for p in ("blend_method", "surface_render_method",
      "alpha_threshold") if hasattr(bpy.types.Material, p)])
cases = [("A_dither_plain", 'DITHERED', None), ("B_blend_plain", 'BLENDED', None),
         ("C_dither_gt", 'DITHERED', 'GT'), ("D_dither_round", 'DITHERED', 'ROUND'),
         ("E_blend_round", 'BLENDED', 'ROUND')]
for i, (n, mode, mm) in enumerate(cases):
    bpy.ops.mesh.primitive_cube_add(location=(i * 3, 0, 0))
    ob = bpy.context.active_object
    ob.name = n
    ob.data.materials.append(variant(n, mode, mm))
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=False,
                          export_materials='EXPORT', export_yup=True)
d = open(OUT, 'rb').read(); off = 12; js = None
while off < len(d):
    ln, ty = struct.unpack_from('<II', d, off); off += 8
    if ty == 0x4E4F534A: js = json.loads(d[off:off + ln].decode('utf-8'))
    off += ln
print("\nRESULT:")
for m in js["materials"]:
    print("  %-18s alphaMode=%-7s cutoff=%s" % (m.get("name"), m.get("alphaMode", "OPAQUE"),
                                                m.get("alphaCutoff")))
