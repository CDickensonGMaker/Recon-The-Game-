# export_edited_blend.py - WYSIWYG exporter for hand-edited variant blends
# (art_source/characters/variants/*.blend, made by the exporters' save_blend
# mode). NO reassembly: whatever Caleb saved - grip fixes, texture checks -
# ships verbatim. Mesh-only by design: variants animate from the shared
# anim_library in-game (probe-proven).
# Run: blender -b art_source/characters/variants/<name>.blend -P tools/export_edited_blend.py [-- <outname>]
import bpy
import os
import sys
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUTNAME = argv[0] if argv else os.path.splitext(os.path.basename(bpy.data.filepath))[0]
OUT = rf"C:\Users\caleb\RECONgame\assets\models\characters\{OUTNAME}.glb"
TARGET_HEIGHT = 1.7132

rig = bpy.data.objects["PSXRig"]

for o in bpy.data.objects:
    o.hide_viewport = False
    o.hide_set(False)


def _belongs_to_rig(o):
    p = o
    while p is not None:
        if p == rig:
            return True
        p = p.parent
    for m in getattr(o, "modifiers", []):
        if m.type == 'ARMATURE' and m.object == rig:
            return True
    return False


def body_bbox():
    """Bounds of the LIVE BODY only (us_grunt_joined or the vc_* part set) -
    never the whole scene (splayed gib meshes would inflate the box)."""
    dg = bpy.context.evaluated_depsgraph_get()
    mn = Vector((1e9,) * 3)
    mx = Vector((-1e9,) * 3)
    bodies = [o for o in bpy.data.objects if o.type == 'MESH'
              and (o.name.endswith("_joined") or o.name.startswith("vc_"))]
    for o in bodies:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        for v in me.vertices:
            w = ev.matrix_world @ v.co
            mn = Vector(map(min, mn, w))
            mx = Vector(map(max, mx, w))
        ev.to_mesh_clear()
    return mn, mx


rig.data.pose_position = 'REST'
bpy.context.view_layer.update()
mn, mx = body_bbox()
h = mx.z - mn.z
s = TARGET_HEIGHT / h
M = Matrix.Scale(s, 4) @ Matrix.Translation(Vector((-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, -mn.z)))

exportables = [o for o in bpy.data.objects
               if o.type in ('MESH', 'ARMATURE', 'EMPTY')
               and (o == rig or _belongs_to_rig(o))]
_skipped = [o.name for o in bpy.data.objects
            if o.type in ('MESH', 'ARMATURE', 'EMPTY') and o not in exportables]
if _skipped:
    print("  export filter skipped non-rig objects:", _skipped, flush=True)

names = {o.name for o in exportables}
roots = [o for o in exportables if o.parent is None or o.parent.name not in names]
for o in roots:
    o.matrix_world = M @ o.matrix_world
bpy.context.view_layer.update()
mn2, mx2 = body_bbox()
print(f"  height {h:.4f} -> {mx2.z - mn2.z:.4f} m (x{s:.4f}), feet z {mn2.z:.5f}", flush=True)

bpy.ops.object.select_all(action='DESELECT')
for o in exportables:
    o.select_set(True)
bpy.context.view_layer.objects.active = rig

bpy.ops.export_scene.gltf(
    filepath=OUT,
    export_format='GLB',
    use_selection=True,
    export_apply=True,
    export_yup=True,
    export_animations=False,
    export_skins=True,
    export_morph=False,
    export_materials='EXPORT',
    export_cameras=False,
    export_lights=False,
    export_draco_mesh_compression_enable=False,
    export_extras=True,
)
mb = os.path.getsize(OUT) / (1024 * 1024)
print(f"EXPORT COMPLETE -> {OUT}  {mb:.2f} MB (WYSIWYG from edited blend)", flush=True)
