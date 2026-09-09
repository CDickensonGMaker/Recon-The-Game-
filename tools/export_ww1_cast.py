"""export_ww1_cast.py - the seven Conquest of Worms WW1 characters, one GLB each.

    "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" --background ^
        --python tools/export_ww1_cast.py -- [tag|all]

Mirrors tools/export_cow_cast.py and tools/export_us_squad.py, the proven exporters.
Their three contracts, unchanged:
  1. the rig must be named "PSXRig" (model_actor.gd resolves every shared clip through it)
  2. mesh names are load-bearing - gib_system.REGIONS looks pieces up by EXACT BARE NAME,
     so the per-man suffix must be stripped or gibbing silently does nothing
  3. height is measured over the body AND every worn piece, never over the weapon (ADR-002)
"""
import bpy
import os
import sys
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_head_frags import build_head_frags
from flatten_procedural_colors import flatten, assert_none_white

ROOT = r"C:\Users\caleb\RECONgame"
CAST = os.path.join(ROOT, "assets", "ww1", "characters", "conquest_of_worms_ww1.blend")
OUT_DIR = os.path.join(ROOT, "assets", "ww1", "characters")
# STATURE IS NORMALISED ON THE BARE BODY, NOT ON THE TOP OF THE HEADGEAR.
#
# The US exporters scale "body + every worn piece" to 1.7132 m, and for that roster it is
# the same thing as normalising stature, because every US grunt wears the identical M1
# helmet. This cast does not: a Pickelhaube with its spike stands 9.4 cm over the skull
# and a kepi 4.9 cm. Normalising on the top of the headgear therefore SHRANK THE MAN
# UNDER THE TALLER HAT - measured on the first export run, bare bodies came out between
# 1.5875 m (German, Pickelhaube) and 1.6678 m (Louie, kepi), so the Germans would have
# stood 8 cm shorter than the Frenchmen for no reason but their helmets.
#
# The datum below is measured, not invented: us_grunt_rifleman.glb, us_grunt_grenadier.glb,
# cow_michael_crawford.glb and cow_gus_arrival.glb all import with a bare joined body of
# exactly 1.6678 m (and 1.7266 m over the helmet). So every RECON human is 1.6678 m of
# body, and headgear adds height ABOVE that, which is also what happens to real soldiers.
TARGET_BODY = 1.6678

TAGS = ["louie_1915", "louie_adrian", "poilu_a", "poilu_b", "poilu_1916",
        "german_boy", "german_line"]
GLB = {t: "ww1_%s.glb" % t for t in TAGS}
# Height excludes the weapon (a 1.3 m rifle in a T-pose hand adds ~0.87 m to the raw bbox)
HEIGHT_EXCLUDE = ("rifle_",)


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
        if "." in n:
            raise SystemExit("ABORT %s: '%s' still carries a collision suffix; "
                             "GibSystem looks meshes up by exact name." % (tag, n))
        o.name = n
        o.data.name = n

    # The studio file already sits at POSE with every channel at identity (the inherited
    # US carry stance was cleared at build time), so POSE and REST are the same skeleton
    # here. REST is set anyway to match export_us_squad.py, and it is a no-op by
    # construction rather than by hope - asserted below.
    before = [tuple(rig.matrix_world @ b.head) for b in rig.pose.bones]
    rig.data.pose_position = 'REST'
    if rig.animation_data:
        for tr in rig.animation_data.nla_tracks:
            tr.mute = True
        rig.animation_data.action = None
    bpy.context.view_layer.update()
    after = [tuple(rig.matrix_world @ b.head) for b in rig.pose.bones]
    drift = max(max(abs(a[i] - b[i]) for i in range(3)) for a, b in zip(before, after))
    if drift > 1e-6:
        raise SystemExit("ABORT %s: flipping POSE->REST moved bones by %.4f m - the file "
                         "is carrying a hidden stance." % (tag, drift))

    build_head_frags()
    frags = [o for o in bpy.data.objects if o.name.startswith("head_frag_")]
    for o in frags:
        o.hide_set(False)
        o.hide_viewport = False
        o.hide_render = False

    def box(objs):
        dg = bpy.context.evaluated_depsgraph_get()
        dg.update()
        mn = Vector((1e9,) * 3)
        mx = Vector((-1e9,) * 3)
        for o in objs:
            ev = o.evaluated_get(dg)
            me = ev.to_mesh()
            for v in me.vertices:
                w = ev.matrix_world @ v.co
                mn = Vector(map(min, mn, w))
                mx = Vector(map(max, mx, w))
            ev.to_mesh_clear()
        return mn, mx

    body = [o for o in bpy.data.objects if o.name == "us_grunt_joined"]
    worn = [o for o in bpy.data.objects
            if o.type == 'MESH'
            and (o.name == "us_grunt_joined"
                 or o.name.startswith(("kepi", "cerveliere", "helmet_", "coat_skirt")))
            and not any(k in o.name.lower() for k in HEIGHT_EXCLUDE)]
    bmn, bmx = box(body)
    h = bmx.z - bmn.z
    if not (1.60 <= h <= 2.10):
        raise SystemExit("ABORT %s: bare body %.3f m outside 1.60-2.10" % (tag, h))
    s = TARGET_BODY / h
    wmn, wmx = box(worn)
    M = Matrix.Scale(s, 4) @ Matrix.Translation(
        Vector((-(wmn.x + wmx.x) / 2, -(wmn.y + wmx.y) / 2, -wmn.z)))
    rig.matrix_world = M @ rig.matrix_world
    bpy.context.view_layer.update()
    # PROVE IT LANDED. A scale factor that was computed is not a scale factor that was
    # applied, and this is the number the whole roster's consistency rests on.
    bmn2, bmx2 = box(body)
    wmn2, wmx2 = box(worn)
    got, top = bmx2.z - bmn2.z, wmx2.z
    if abs(got - TARGET_BODY) > 1e-3:
        raise SystemExit("ABORT %s: bare body landed %.4f m, wanted %.4f"
                         % (tag, got, TARGET_BODY))
    if abs(wmn2.z) > 1e-3:
        raise SystemExit("ABORT %s: feet at z=%.4f, not on the ground" % (tag, wmn2.z))

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

    # TEXTURE BUDGET (Caleb's law): no embedded image over 1 MB. The sheets are already
    # built under it at source - palettised to 256 colours BEFORE any resolution cut - so
    # this loop should be a no-op. It stays as the second gate, and it MEASURES the bytes
    # rather than estimating from a pixel count: these sheets compress at wildly different
    # rates (the flat uniform sheet runs ~0.04 bytes/px, the photographic face sheet
    # ~0.57), so one Mpx ceiling would be wrong for both.
    #
    # DO NOT TOUCH AN IMAGE THAT IS ALREADY COMPLIANT. The first version of this loop
    # called im.save() on everything to find out how big it was, and that ONE CALL cost
    # the whole build: saving re-encodes a palettised PNG as truecolour, so every
    # already-compliant 850 KB face sheet came back over the limit and the loop then
    # "fixed" it by scaling it to 801x700 - a 38% resolution loss on the only texture
    # anybody looks at, caused entirely by the instrument that was measuring it.
    # The packed block already knows its own size. Read it and leave it alone.
    LIMIT = 950_000
    tmpdir = os.path.join(os.environ.get("TEMP", "."), "ww1_texbudget")
    os.makedirs(tmpdir, exist_ok=True)
    used = set()
    for o in exportables:
        if o.type != 'MESH':
            continue
        for m in o.data.materials:
            if not m or not m.node_tree:
                continue
            for nd in m.node_tree.nodes:
                if nd.type == 'TEX_IMAGE' and nd.image:
                    used.add(nd.image)
    touched = []
    for im in bpy.data.images:
        if not im.size[0] or im not in used:
            continue                       # unused images are never embedded in the GLB
        have = im.packed_file.size if im.packed_file else 0
        if not have:
            fp = bpy.path.abspath(im.filepath)
            have = os.path.getsize(fp) if fp and os.path.exists(fp) else 0
        if have and have <= LIMIT:
            continue                       # compliant as it stands - measuring it would
                                           # destroy it, so do not measure it
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
        touched.append("%s %dx%d->%dx%d" % (im.name, w0, h0, im.size[0], im.size[1]))

    out = os.path.join(OUT_DIR, GLB[tag])
    bpy.ops.export_scene.gltf(
        filepath=out, export_format='GLB', use_selection=True, export_apply=True,
        export_yup=True, export_animations=False, export_animation_mode='ACTIONS',
        export_bake_animation=True, export_anim_single_armature=True,
        export_optimize_animation_size=True, export_skins=True, export_morph=False,
        export_materials='EXPORT', export_cameras=False, export_lights=False,
        export_draco_mesh_compression_enable=False, export_extras=True)
    print("  %-13s bare body %.4f -> %.4f (k=%.4f), top of headgear %.4f  %2d meshes + "
          "%d frags  gibs %d/5 caps %d/5  %5.2f MB  %s%s"
          % (tag, h, got, s, top, len(meshes), len(frags),
             sum(1 for n in REG if n in bpy.data.objects),
             sum(1 for n in CAPS if n in bpy.data.objects),
             os.path.getsize(out) / 1048576.0, os.path.basename(out),
             ("  shrunk: " + ", ".join(touched)) if touched else ""), flush=True)
    return out


argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["all"]
who = TAGS if (not argv or "all" in argv) else [a for a in argv if a in TAGS]
print("=== exporting the Conquest of Worms WW1 cast ===", flush=True)
for t in who:
    export_one(t)
print("=== done ===", flush=True)
