"""Build the field medical crate and export it to assets/world/props/medical_crate.glb.

    blender -b -P tools/make_medical_crate.py

Standalone on purpose: this is a WORLD prop, not a viewmodel, so it does not belong in
fp_arms_rifle.blend and does not go through export_viewmodel_clips.py. Run it again to
regenerate - it builds from nothing every time and saves no .blend.

The medic drops one of these in the field; the player takes bandages off it.
"""
import bpy, bmesh, os, math

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "assets", "world", "props", "medical_crate.glb")

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)

MM = 1000.0
bm = bmesh.new()


def box(x0, x1, y0, y1, z0, z1):
    co = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
          (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
    vs = [bm.verts.new([c / MM for c in p]) for p in co]
    for f in [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]:
        bm.faces.new([vs[i] for i in f])
    return vs


# body, lid lip, and two strap ribs. 580 x 360 x 300 - a two-man chest a man can sit on.
box(-290, 290, -180, 180, 0, 262)
box(-298, 298, -188, 188, 262, 300)
box(-150, -120, -190, 190, 0, 262)
box(120, 150, -190, 190, 0, 262)
# the red cross, proud of the front face so it needs no texture
box(-46, 46, -196, -188, 120, 152)
box(-16, 16, -196, -188, 90, 182)

bm.normal_update()
me = bpy.data.meshes.new("medical_crate")
bm.to_mesh(me)
bm.free()

crate = bpy.data.objects.new("medical_crate", me)
bpy.context.scene.collection.objects.link(crate)


def mat(name, rgb, rough):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    b.inputs["Roughness"].default_value = rough
    return m


me.materials.append(mat("CrateOD", (0.17, 0.19, 0.13), 0.85))
me.materials.append(mat("CrateCross", (0.42, 0.03, 0.03), 0.70))
# the last two boxes (12 faces) are the cross
for p in list(me.polygons)[-12:]:
    p.material_index = 1

os.makedirs(os.path.dirname(OUT), exist_ok=True)
crate.select_set(True)
bpy.context.view_layer.objects.active = crate
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True,
                          export_apply=True, export_yup=True, export_materials="EXPORT",
                          export_animations=False)
print("verts %d  polys %d  dims %s" % (len(me.vertices), len(me.polygons),
                                       tuple(round(v, 3) for v in crate.dimensions)))
print("EXPORTED %s  %.1f KB" % (OUT, os.path.getsize(OUT) / 1024.0))
