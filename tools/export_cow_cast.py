"""export_cow_cast.py - the three Conquest of Worms characters, one GLB each.

    "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" --background ^
        --python tools/export_cow_cast.py -- [michael|gus_arrival|gus_ears|all]

Mirrors tools/export_us_squad.py, the PROVEN exporter. Its three contracts, verbatim:
  1. the rig must be named "PSXRig" (model_actor.gd resolves every shared clip through it)
  2. mesh names are load-bearing - gib_system.REGIONS looks pieces up by EXACT NAME, so
     the per-man suffix must be stripped or gibbing silently does nothing
  3. height is measured over the body AND every *_worn piece (ADR-002)

ALIAS below is the one addition: stripping "_michael" off `journal_michael` would ship it
as `journal`, which is not the name the brief asked for and is not a name that says whose
it is. The alias pins it.
"""
import bpy
import os
import sys
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_head_frags import build_head_frags
from flatten_procedural_colors import flatten, assert_none_white

CAST = r"C:\Users\caleb\RECONgame\assets\us\characters\conquest_of_worms_us_cast.blend"
OUT_DIR = r"C:\Users\caleb\RECONgame\assets\us\characters"
TARGET_HEIGHT = 1.7132                       # ADR-002, top of helmet, feet at origin
TAGS = ["michael", "gus_arrival", "gus_ears"]
GLB = {"michael": "cow_michael_crawford.glb",
       "gus_arrival": "cow_gus_arrival.glb",
       "gus_ears": "cow_gus_ears.glb"}
# Suffix-stripping truncates the journal, so pin its shipped name:
#   journal_michael      -> "journal"        (tag "michael")
# The necklace ships as necklace_cord + charm_ear_06..10 (tools/dress_cow_gus_necklace.py).
ALIAS = {"journal": "journal_michael"}
HEIGHT_EXCLUDE = ("radio", "antenna", "prc25", "handset")


def export_one(tag):
    bpy.ops.wm.open_mainfile(filepath=CAST)
    rig = bpy.data.objects["PSXRig_" + tag]
    meshes = [o for o in bpy.data.objects
              if o.type == 'MESH' and o.name.endswith("_" + tag)]

    keep = set([rig] + meshes)
    for o in list(bpy.data.objects):
        if o not in keep:
            bpy.data.objects.remove(o, do_unlink=True)
    for o in bpy.data.objects:
        o.hide_set(False)
        o.hide_viewport = False
        o.hide_render = False

    rig.name = "PSXRig"
    for o in meshes:
        n = o.name[: -(len(tag) + 1)]
        n = ALIAS.get(n, n)
        if "." in n:
            if n.split(".")[0].startswith("canteen"):
                n = n.replace(".", "_")
            else:
                raise SystemExit("ABORT %s: '%s' still carries a collision suffix; "
                                 "GibSystem looks meshes up by exact name." % (tag, n))
        o.name = n
        o.data.name = n

    rig.data.pose_position = 'REST'
    if rig.animation_data:
        for tr in rig.animation_data.nla_tracks:
            tr.mute = True
        rig.animation_data.action = None
    bpy.context.view_layer.update()

    build_head_frags()
    frags = [o for o in bpy.data.objects if o.name.startswith("head_frag_")]
    for o in frags:
        o.hide_set(False)
        o.hide_viewport = False
        o.hide_render = False

    dg = bpy.context.evaluated_depsgraph_get()
    parts = [bpy.data.objects["us_grunt_joined"]]
    parts += [o for o in meshes if o.name.endswith("_worn")
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
        raise SystemExit("ABORT %s: height box %.3f m outside 1.60-2.00; parts=%s"
                         % (tag, h, [o.name for o in parts]))
    s = TARGET_HEIGHT / h
    M = Matrix.Scale(s, 4) @ Matrix.Translation(
        Vector((-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, -mn.z)))
    rig.matrix_world = M @ rig.matrix_world
    bpy.context.view_layer.update()

    # gib contract: the five region meshes and their caps must all be present, BARE named
    REG = ["grunt_head", "grunt_forearm_l", "grunt_forearm_r", "grunt_leg_l", "grunt_leg_r"]
    CAPS = ["cap_head", "cap_forearm_l", "cap_forearm_r", "cap_leg_l", "cap_leg_r"]
    miss = [n for n in REG + CAPS if n not in bpy.data.objects]
    if miss:
        raise SystemExit("ABORT %s: gib contract incomplete, missing %s" % (tag, miss))

    exportables = [rig] + meshes + frags
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in exportables:
        o.select_set(True)
    bpy.context.view_layer.objects.active = rig

    flatten(exportables)
    left = assert_none_white(exportables)
    if left:
        raise SystemExit("ABORT %s: material(s) would ship on the engine default: %s"
                         % (tag, left))

    # TEXTURE BUDGET (Caleb's law 2026-08-18, CLAUDE.md): no embedded image over 1MB.
    # Measured on the first export of this cast: the shared `ref_factions` uniform atlas
    # is 3600x5700 and lands as an 8.63 MB embedded PNG - 88% of the file, and it is the
    # same sheet in all three. tools/shrink_oversized_textures.py did NOT catch it
    # (it took the 2.6 MB face atlas and left this one), so shrink it at SOURCE, which
    # the law says is better anyway. UVs are 0-1 fractions; a downscale cannot shift a
    # wrap. Cost, stated plainly: the painted uniform detail is 4x coarser than the rest
    # of the US cast, which still ships the full sheet and still breaks the law.
    # 1.05 Mpx measured at ~0.86 bytes/px for these sheets -> ~0.90 MB embedded PNG.
    # Power-of-two halving overshot badly (3600x5700 -> 900x1425 was still 1.10 MB, and
    # the next halving would have thrown away 4x more than needed), so scale by a float.
    # MEASURE THE BYTES, do not estimate them. A pixel-count budget was tried first and
    # failed: these sheets compress at wildly different rates - the flat-ish uniform atlas
    # runs ~0.86 bytes/px but the photographic face sheet runs ~1.64, so one Mpx ceiling
    # put ref_factions safely under 1 MB and left the face atlas at 1.72 MB.
    LIMIT = 950_000
    tmpdir = os.path.join(os.environ.get("TEMP", "."), "cow_texbudget")
    os.makedirs(tmpdir, exist_ok=True)
    for im in bpy.data.images:
        if not im.size[0]:
            continue
        w0, h0 = im.size
        tmp = os.path.join(tmpdir, "%s.png" % abs(hash(im.name)))
        for _ in range(12):
            im.filepath_raw = tmp
            im.file_format = 'PNG'
            im.save()
            nbytes = os.path.getsize(tmp)
            if nbytes <= LIMIT:
                break
            f = max(0.45, (float(LIMIT) / nbytes) ** 0.5 * 0.95)
            im.scale(max(8, int(im.size[0] * f)), max(8, int(im.size[1] * f)))
        im.pack()
        if (im.size[0], im.size[1]) != (w0, h0):
            print("  %-12s texture budget: %-26s %dx%d -> %dx%d  (%.2f MB embedded)"
                  % (tag, im.name, w0, h0, im.size[0], im.size[1], nbytes / 1048576.0),
                  flush=True)

    out = os.path.join(OUT_DIR, GLB[tag])
    bpy.ops.export_scene.gltf(
        filepath=out, export_format='GLB', use_selection=True, export_apply=True,
        export_yup=True, export_animations=False, export_animation_mode='ACTIONS',
        export_bake_animation=True, export_anim_single_armature=True,
        export_optimize_animation_size=True, export_skins=True, export_morph=False,
        export_materials='EXPORT', export_cameras=False, export_lights=False,
        export_draco_mesh_compression_enable=False, export_extras=True)
    print("  %-12s H=%.4f -> k=%.4f  %2d meshes + %d frags  gibs %d/5 caps %d/5  %5.2f MB  %s"
          % (tag, h, s, len(meshes), len(frags),
             sum(1 for n in REG if n in bpy.data.objects),
             sum(1 for n in CAPS if n in bpy.data.objects),
             os.path.getsize(out) / 1048576.0, os.path.basename(out)), flush=True)
    return out


argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["all"]
who = TAGS if (not argv or "all" in argv) else [a for a in argv if a in TAGS]
print("=== exporting the Conquest of Worms cast ===", flush=True)
for t in who:
    export_one(t)
print("=== done ===", flush=True)
