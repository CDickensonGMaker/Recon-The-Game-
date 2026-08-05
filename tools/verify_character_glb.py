"""verify_character_glb.py - read back an exported character GLB and prove it.

    blender -b -P tools/verify_character_glb.py

Checks the four things that ship broken silently:
  rig named PSXRig · every mesh has a UV layer · every material's image is
  embedded (not a dead path) · height == ADR-002 TARGET_HEIGHT.
"""
import bpy, os
from mathutils import Vector

DIR = r"C:\Users\caleb\RECONgame\assets\us\characters"
FILES = ["us_pilot_white.glb", "us_pilot_black.glb", "us_medic.glb",
         "us_grunt_rifleman.glb", "us_grunt_grenadier.glb", "us_grunt_mg.glb",
         "us_grunt_rto.glb", "us_grunt_marksman.glb", "us_grunt_pointman.glb"]
TARGET = 1.7132

for f in FILES:
    p = os.path.join(DIR, f)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=p)
    rigs = [o for o in bpy.data.objects if o.type == 'ARMATURE']
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    no_uv = [o.name for o in meshes if not o.data.uv_layers]
    dead = []
    for m in bpy.data.materials:
        if not m.use_nodes:
            continue
        for n in m.node_tree.nodes:
            if n.type == 'TEX_IMAGE' and n.image:
                if n.image.packed_file is None and not os.path.exists(bpy.path.abspath(n.image.filepath)):
                    dead.append((m.name, n.image.name))
    dg = bpy.context.evaluated_depsgraph_get()

    def extent(objs):
        mn = Vector((1e9,) * 3); mx = Vector((-1e9,) * 3)
        for o in objs:
            ev = o.evaluated_get(dg); me = ev.to_mesh()
            for v in me.vertices:
                w = ev.matrix_world @ v.co
                mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
            ev.to_mesh_clear()
        return mx.z - mn.z

    # ADR-002 height is measured over the BODY + worn pieces, not over held
    # weapons - a rifle in a raised hand is not the man's height.
    body = [o for o in meshes if o.name == "us_grunt_joined"
            or o.name.endswith("_worn") or o.name.startswith("helmet_")]
    h = extent(body) if body else 0.0
    full = extent(meshes)
    tris = sum(len(o.data.loop_triangles) if o.data.loop_triangles else len(o.data.polygons) for o in meshes)
    junk = [o.name for o in meshes if "_OLD" in o.name or "Icosphere" in o.name]
    print("%-22s rig=%-8s meshes=%2d  body_h=%.4f %-3s  full=%.2f  no_uv=%s  dead_img=%s  junk=%s"
          % (f, rigs[0].name if rigs else "NONE", len(meshes), h,
             "OK" if abs(h - TARGET) < 0.02 else "OFF", full,
             no_uv or "none", dead or "none", junk or "none"), flush=True)
