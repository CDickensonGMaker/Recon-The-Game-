"""Export every zombie .blend as a Godot-ready .glb, in one Blender run.

    blender -b -P tools/export_zombies.py

Same export contract as export_edited_blend.py - origin at the feet, 1.7132 m
tall, -Y maps to Godot -Z, mesh only. Zombies animate from the shared
anim_library like every other PSXRig character, so no clips are exported here.

Batch rather than one-file-at-a-time because there are twelve of them and the
per-invocation Blender startup is most of the cost.
"""
import glob
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recon_paths import ZOMBIE_DIR

TARGET_HEIGHT = 1.7132
RIG = "PSXRig"


def _belongs_to_rig(o, rig):
    p = o
    while p is not None:
        if p == rig:
            return True
        p = p.parent
    for m in getattr(o, "modifiers", []):
        if m.type == 'ARMATURE' and m.object == rig:
            return True
    return False


def _body_bbox():
    """The LIVE body only. Splayed gib meshes sit off to the side of the scene and
    would inflate the box, which would then scale the man down to compensate."""
    dg = bpy.context.evaluated_depsgraph_get()
    mn = Vector((1e9,) * 3)
    mx = Vector((-1e9,) * 3)
    for o in [o for o in bpy.data.objects
              if o.type == 'MESH' and o.name.endswith("_joined")]:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        for v in me.vertices:
            w = ev.matrix_world @ v.co
            mn = Vector(map(min, mn, w))
            mx = Vector(map(max, mx, w))
        ev.to_mesh_clear()
    return mn, mx


def export_one(blend_path):
    name = os.path.splitext(os.path.basename(blend_path))[0]
    bpy.ops.wm.open_mainfile(filepath=blend_path)
    rig = bpy.data.objects[RIG]
    for o in bpy.data.objects:
        o.hide_viewport = False
        o.hide_set(False)

    rig.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    mn, mx = _body_bbox()
    h = mx.z - mn.z
    if h <= 0.0:
        print("  %-16s NO BODY MESH - skipped" % name, flush=True)
        return None
    s = TARGET_HEIGHT / h
    M = Matrix.Scale(s, 4) @ Matrix.Translation(
        Vector((-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, -mn.z)))

    exportables = [o for o in bpy.data.objects
                   if o.type in ('MESH', 'ARMATURE', 'EMPTY')
                   and (o == rig or _belongs_to_rig(o, rig))]
    names = {o.name for o in exportables}
    for o in [o for o in exportables
              if o.parent is None or o.parent.name not in names]:
        o.matrix_world = M @ o.matrix_world
    bpy.context.view_layer.update()

    bpy.ops.object.select_all(action='DESELECT')
    for o in exportables:
        o.select_set(True)
    bpy.context.view_layer.objects.active = rig

    out = os.path.join(ZOMBIE_DIR, name + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=out,
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
    mn2, mx2 = _body_bbox()
    mb = os.path.getsize(out) / (1024 * 1024)
    print("  %-16s %.4f -> %.4f m  feet z %+.5f  %5.2f MB"
          % (name, h, mx2.z - mn2.z, mn2.z, mb), flush=True)
    return out


def main():
    blends = sorted(glob.glob(os.path.join(ZOMBIE_DIR, "zed_*.blend")))
    if not blends:
        sys.exit("no zed_*.blend in %s - run make_zombies.py first" % ZOMBIE_DIR)
    print("=== exporting %d zombies ===" % len(blends), flush=True)
    ok = [b for b in blends if export_one(b) is not None]
    print("done: %d/%d exported" % (len(ok), len(blends)))


if __name__ == "__main__":
    main()
