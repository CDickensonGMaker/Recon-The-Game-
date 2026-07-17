"""export_helmets.py - one GLB per helmet variant, plus the socket offset for Godot.

    blender -b -P tools/export_helmets.py

Each helmet exports with its SOCKET AT THE ORIGIN. So in Godot you make a
BoneAttachment3D on mixamorig_Head, drop the helmet in, apply the offset from
helmet_socket.json, and it lands exactly where the truth helmet sat. No per-helmet
fitting - every variant was cloned off the same shell, so they all share one offset.

NAMING: every mesh is prefixed `helmet_`. hitzone_builder._GEAR_NAME_HINTS excludes
a mesh from the hurtbox by SUBSTRING, and "helmet" is on that list. Without the
prefix a bug-juice bottle or a playing card would be harvested into the man's
damage volume and you could shoot him by hitting his smokes.
"""
import bpy, os, json
from mathutils import Vector

SRC     = r"C:\Users\caleb\RECONgame\assets\us\characters\helmet_variants.blend"
LINEUP  = r"C:\Users\caleb\RECONgame\assets\us\characters\us_v3_soldier_lineup.blend"
OUT_DIR = r"C:\Users\caleb\RECONgame\assets\us\props\helmets"
os.makedirs(OUT_DIR, exist_ok=True)

# ---- 1. the socket's transform relative to the Head bone (read from a real grunt) ----
bpy.ops.wm.open_mainfile(filepath=LINEUP)
rig = bpy.data.objects["PSXRig_rifleman"]
sock = bpy.data.objects["socket_head_rifleman"]
bpy.context.view_layer.update()

loc, rot, scl = sock.matrix_basis.decompose()
socket_meta = {
    "bone": sock.parent_bone,
    "parent_type": sock.parent_type,
    "matrix_basis": [list(r) for r in sock.matrix_basis],
    "translation": list(loc),
    "rotation_quat": [rot.w, rot.x, rot.y, rot.z],
    "note": ("Bone-local transform of socket_head on mixamorig:Head. Every helmet "
             "GLB exports with its socket at the origin, so applying this puts any "
             "variant exactly where the truth helmet sat."),
}
print("socket_head on %s: bone=%s  local translation=(%.4f, %.4f, %.4f)"
      % (rig.name, sock.parent_bone, loc.x, loc.y, loc.z))

# ---- 2. export each helmet ----
bpy.ops.wm.open_mainfile(filepath=SRC)
root = bpy.data.collections["HELMETS"]
names = sorted(c.name for c in root.children)
print("\n=== exporting %d helmets ===" % len(names))

manifest = {"socket": socket_meta, "helmets": {}}

for name in names:
    col = bpy.data.collections[name]
    sock = bpy.data.objects.get(name + "_socket_head")
    meshes = [o for o in col.objects if o.type == 'MESH']
    if sock is None or not meshes:
        print("  %-18s missing socket or meshes - skipped" % name)
        continue

    # move the whole helmet so the SOCKET sits at the world origin
    delta = -sock.matrix_world.translation.copy()
    sock.location += delta
    bpy.context.view_layer.update()

    tris = 0
    for o in meshes:
        o.hide_set(False)
        o.hide_viewport = False
        o.hide_render = False
        # `helmet_` prefix -> matches _GEAR_NAME_HINTS -> never enters the hurtbox
        base = o.name.replace(name + "_", "")
        o.name = "helmet_%s_%s" % (name.replace("m1_", ""), base)
        o.data.name = o.name
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)

    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]

    out = os.path.join(OUT_DIR, "%s.glb" % name)
    bpy.ops.export_scene.gltf(
        filepath=out,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_animations=False,
        export_skins=False,          # rigid prop - bone-attached, not skinned
        export_morph=False,
        export_materials='EXPORT',
        export_cameras=False,
        export_lights=False,
        export_draco_mesh_compression_enable=False,
        export_extras=True,
    )
    kb = os.path.getsize(out) / 1024.0
    manifest["helmets"][name] = {
        "glb": "res://assets/us/props/helmets/%s.glb" % name,
        "tris": tris,
        "parts": sorted(o.name for o in meshes),
    }
    print("  %-18s %4d tris  %6.1f KB  %s.glb" % (name, tris, kb, name))

    sock.location -= delta        # put it back so the next one measures clean
    bpy.context.view_layer.update()

with open(os.path.join(OUT_DIR, "helmets.json"), "w") as f:
    json.dump(manifest, f, indent=2)
print("\nwrote helmets.json (socket offset + %d helmets)" % len(manifest["helmets"]))
print("=== done ===")
