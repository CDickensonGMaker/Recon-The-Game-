"""export_pilots_medics.py - export the two pilots and the medic, one GLB each.

    blender -b -P tools/export_pilots_medics.py

Mirrors tools/export_us_squad.py, whose export call and contracts are copied
verbatim rather than reinvented. One deliberate difference:

  SELECTION IS BY RIG CHILDREN, NOT BY NAME SUFFIX. The squad exporter gathers
  `o.name.endswith("_" + tag)`. These characters carry pieces that do not follow
  that convention at all - `helmet_sph4_pilot`, `belt_holster_pilot_NEW`,
  `m1911_world_pilot`, `socket_holster_pilot` - so a suffix gather drops the
  pilot's helmet, holster and sidearm and the drop is silent.

The squad exporter's three contracts still bind here:
  1. the rig must ship named "PSXRig" or the shared clip library goes silent
  2. mesh names are load-bearing; the per-man suffix is stripped before export
  3. height is measured over the body AND the worn pieces (ADR-002)
"""
import bpy, os
from mathutils import Vector, Matrix

LINEUP = r"C:\Users\caleb\RECONgame\assets\us\characters\us_base_v3.blend"
OUT_DIR = r"C:\Users\caleb\RECONgame\assets\us\characters"
TARGET_HEIGHT = 1.7132                     # ADR-002. top of head/helmet, feet at origin.

# unit_id -> the rig that holds that character in the lineup.
# unit_id is what ModelActor.model_path() resolves (model_actor.gd:22-29).
UNITS = [
    ("us_pilot_white", "PSXRig_pointman.001"),
    ("us_pilot_black", "PSXRig_pilot_black"),
    ("us_medic",       "PSXRig_medic"),
]

# suffixes stripped off mesh names so gib/hitzone lookups resolve (contract 2)
SUFFIXES = ("_pointman.001", "_pilot_black", "_medic_black", "_medic", "_pilot")

# an antenna in the height box squeezes the whole man; see export_us_squad.py
HEIGHT_EXCLUDE = ("radio", "antenna", "prc25", "handset")


def canonical(name):
    for s in SUFFIXES:
        if name.endswith(s):
            return name[: -len(s)]
    return name


def export_one(unit_id, rig_name):
    bpy.ops.wm.open_mainfile(filepath=LINEUP)     # fresh every time
    rig = bpy.data.objects.get(rig_name)
    if rig is None:
        raise SystemExit("ABORT %s: rig '%s' not in the lineup" % (unit_id, rig_name))

    # Superseded pieces kept in the lineup for recovery, and loose scratch
    # geometry, are NOT part of the character. They are hidden in the .blend,
    # but this exporter unhides everything (gib donors ship hidden), so hidden
    # is not a filter here - they have to be named out.
    JUNK = ("_OLD", "Icosphere")
    meshes = [o for o in rig.children
              if o.type == 'MESH' and not any(j in o.name for j in JUNK)]
    keep = set([rig] + meshes)
    for o in list(bpy.data.objects):
        if o not in keep:
            bpy.data.objects.remove(o, do_unlink=True)
    stray = [o.name for o in bpy.data.objects if o not in keep]
    if stray:
        raise SystemExit("ABORT %s: %s survived the purge" % (unit_id, stray))

    # select_set() silently no-ops on a hidden object, so a hidden piece never
    # reaches the GLB. The game hides gib donors at runtime, not us.
    for o in bpy.data.objects:
        o.hide_set(False)
        o.hide_viewport = False
        o.hide_render = False

    rig.name = "PSXRig"
    for o in meshes:
        n = canonical(o.name)
        if "." in n:
            if n.split(".")[0].startswith("canteen"):
                n = n.replace(".", "_")
            else:
                raise SystemExit("ABORT %s: '%s' keeps a collision suffix; gib "
                                 "lookups are by exact name." % (unit_id, n))
        o.name = n
        o.data.name = n

    rig.data.pose_position = 'REST'
    if rig.animation_data:
        for tr in rig.animation_data.nla_tracks:
            tr.mute = True
        rig.animation_data.action = None
    bpy.context.view_layer.update()

    body = bpy.data.objects.get("us_grunt_joined")
    if body is None:
        raise SystemExit("ABORT %s: no us_grunt_joined after rename" % unit_id)
    dg = bpy.context.evaluated_depsgraph_get()
    parts = [body] + [o for o in bpy.data.objects
                      if o.type == 'MESH' and o is not body
                      and (o.name.endswith("_worn") or o.name.startswith("helmet_"))
                      and not any(k in o.name.lower() for k in HEIGHT_EXCLUDE)]
    mn = Vector((1e9,) * 3)
    mx = Vector((-1e9,) * 3)
    for o in parts:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        for v in me.vertices:
            w = ev.matrix_world @ v.co
            mn = Vector(map(min, mn, w))
            mx = Vector(map(max, mx, w))
        ev.to_mesh_clear()

    h = mx.z - mn.z
    if not (1.60 <= h <= 2.00):
        raise SystemExit("ABORT %s: height box %.3f m, expected 1.60-2.00.\n  parts: %s"
                         % (unit_id, h, [o.name for o in parts]))
    s = TARGET_HEIGHT / h
    rig.matrix_world = (Matrix.Scale(s, 4) @ Matrix.Translation(
        Vector((-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, -mn.z)))) @ rig.matrix_world
    bpy.context.view_layer.update()

    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in [rig] + meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = rig

    out = os.path.join(OUT_DIR, "%s.glb" % unit_id)
    bpy.ops.export_scene.gltf(
        filepath=out,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_animations=False,          # clips come from anim_library.glb
        export_animation_mode='ACTIONS',
        export_bake_animation=True,
        export_anim_single_armature=True,
        export_optimize_animation_size=True,
        export_skins=True,
        export_morph=False,
        export_materials='EXPORT',
        export_cameras=False,
        export_lights=False,
        export_draco_mesh_compression_enable=False,
        export_extras=True,
    )
    mb = os.path.getsize(out) / (1024 * 1024)
    print("  %-16s h=%.3f -> k=%.3f  %2d meshes  %5.2f MB  %s"
          % (unit_id, h, s, len(meshes), mb, os.path.basename(out)), flush=True)


print("=== exporting pilots + medic ===", flush=True)
for uid, rig in UNITS:
    export_one(uid, rig)
print("=== done ===", flush=True)
