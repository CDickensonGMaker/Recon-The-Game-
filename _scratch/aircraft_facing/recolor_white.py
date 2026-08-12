"""Recolour pure-white untextured materials on airframes whose FACING was
already correct, so bake_facing.py never opened them.

A4_VietnamCamo is base (1,1,1) with no texture, which is why the Skyhawk renders
as a white model. This is a holding colour, not camo - real two-tone SEA camo
needs authored art.
"""
import bpy, os

TARGETS = [
    r"C:\Users\caleb\RECONgame\assets\us\aircraft\a4_skyhawk.glb",
    r"C:\Users\caleb\RECONgame\assets\us\aircraft\f4_phantom.glb",
]
SEA_GREEN = (0.16, 0.20, 0.13, 1.0)
WHITE_EPS = 0.97

for path in TARGETS:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    before = (len(bpy.data.materials), len(bpy.data.images),
              len([o for o in bpy.data.objects if o.type == 'MESH']))

    fixed = []
    for m in bpy.data.materials:
        if not (m.use_nodes and m.node_tree):
            continue
        if any(n.type == 'TEX_IMAGE' and n.image is not None for n in m.node_tree.nodes):
            continue
        for n in m.node_tree.nodes:
            if n.type != 'BSDF_PRINCIPLED':
                continue
            c = n.inputs['Base Color'].default_value
            if c[0] > WHITE_EPS and c[1] > WHITE_EPS and c[2] > WHITE_EPS:
                n.inputs['Base Color'].default_value = SEA_GREEN
                m.diffuse_color = SEA_GREEN
                fixed.append(m.name)

    if not fixed:
        print("%s - no pure-white untextured materials, untouched"
              % os.path.basename(path))
        continue

    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB',
                              use_selection=False, export_apply=False,
                              export_yup=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    after = (len(bpy.data.materials), len(bpy.data.images),
             len([o for o in bpy.data.objects if o.type == 'MESH']))
    print("%s  recoloured %s  mats %d->%d images %d->%d meshes %d->%d  %s"
          % (os.path.basename(path), fixed, before[0], after[0], before[1],
             after[1], before[2], after[2],
             "OK" if after >= before else "FAIL lost data"))

print("RECOLOR_DONE")
