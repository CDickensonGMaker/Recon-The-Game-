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
import bpy, os, sys
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_head_frags import build_head_frags
from flatten_procedural_colors import flatten, assert_none_white

LINEUP = r"C:\Users\caleb\RECONgame\assets\us\characters\us_base_v3.blend"
OUT_DIR = r"C:\Users\caleb\RECONgame\assets\us\characters"
TARGET_HEIGHT = 1.7132                     # ADR-002. top of head/helmet, feet at origin.

# unit_id -> the rig that holds that character in the lineup.
# unit_id is what ModelActor.model_path() resolves (model_actor.gd:22-29).
UNITS = [
    ("us_pilot_white", "PSXRig_pointman.001"),
    ("us_pilot_black", "PSXRig_pilot_black"),
    ("us_medic",       "PSXRig_medic"),
    ("us_medic_black", "PSXRig_medic_black"),
    ("us_surgeon",     "PSXRig_surgeon"),
]

# suffixes stripped off mesh names so gib/hitzone lookups resolve (contract 2).
# LONGEST FIRST: "_medic_black" must be tried before "_medic", or the black medic's
# meshes strip to "..._black" and every gib lookup misses.
SUFFIXES = ("_pointman.001", "_pilot_black", "_medic_black", "_medic", "_surgeon",
            "_pilot", "_GRAFT")

# an antenna in the height box squeezes the whole man; see export_us_squad.py
HEIGHT_EXCLUDE = ("radio", "antenna", "prc25", "handset")

# gib_system.gd REGIONS + the caps under them. tests/test_gib_contract_all.gd
# requires the five regions; the uparm/torso pair round out the 8-piece split.
GIB_CONTRACT = (
    "grunt_head", "grunt_torso", "grunt_uparm_l", "grunt_uparm_r",
    "grunt_forearm_l", "grunt_forearm_r", "grunt_leg_l", "grunt_leg_r",
    "cap_head", "cap_torso", "cap_uparm_l", "cap_uparm_r",
    "cap_forearm_l", "cap_forearm_r", "cap_leg_l", "cap_leg_r",
)

# unit_id -> the rig its gib donors are copied FROM, for units whose own rig
# does not carry the set. us_pilot_white sits on PSXRig_pointman.001, a
# whole-unit duplicate made when the original us_pilot_body bind was destroyed;
# it was taken before the split donors existed, so the man could not lose a
# limb and his one cap_head sat 10.46 m off his body (its parent-inverse
# cancels the rig's X). Measured 2026-08-08: every donor mesh in this lineup is
# bit-identical per-index across all five rigs, so this is a copy, not a rebuild.
GIB_DONOR_RIG = {"us_pilot_white": "PSXRig_pointman"}

# names that no SUFFIX rule can canonicalise. Left alone, us_pilot_white ships
# belt_holster_pilot_NEW while us_pilot_black ships belt_holster.
ALIAS = {"belt_holster_pilot_NEW": "belt_holster"}


def canonical(name):
    if name in ALIAS:
        return ALIAS[name]
    for s in SUFFIXES:
        if name.endswith(s):
            return name[: -len(s)]
    return name


def graft_gib_donors(unit_id, rig):
    """Copy the missing gib donor set onto rig from a healthy sibling.

    Object-level copy only: mesh data, vertex groups, materials, parent-inverse
    and local matrix all come across from the donor untouched, and the armature
    modifier is repointed. No vertex coordinate is written - the rig's position
    is an object transform and must stay one (psx-npc-pipeline FAILURE MODE 1).
    """
    src_name = GIB_DONOR_RIG.get(unit_id)
    if src_name is None:
        return []
    src = bpy.data.objects.get(src_name)
    if src is None:
        raise SystemExit("ABORT %s: donor rig '%s' not in the lineup" % (unit_id, src_name))
    tag = src_name[len("PSXRig"):]
    donors = {}
    for o in src.children:
        if o.type == 'MESH' and o.name.endswith(tag):
            donors[o.name[: -len(tag)]] = o

    made = []
    for part in GIB_CONTRACT:
        d = donors.get(part)
        if d is None:
            raise SystemExit("ABORT %s: donor rig %s has no %s" % (unit_id, src_name, part))
        stale = [o for o in rig.children if o.type == 'MESH' and canonical(o.name) == part]
        for o in stale:
            bpy.data.objects.remove(o, do_unlink=True)
        # the lineup already holds bare-named grunt_*/cap_* under the stock
        # PSXRig, so naming the copy `part` here mints `grunt_forearm_l.001` and
        # the collision check downstream aborts. Tag it; canonical() strips it.
        n = d.copy()
        n.data = d.data.copy()
        n.name = part + "_GRAFT"
        n.data.name = n.name
        bpy.context.scene.collection.objects.link(n)
        n.parent = rig
        n.parent_type = 'OBJECT'
        n.matrix_parent_inverse = d.matrix_parent_inverse.copy()
        n.matrix_basis = d.matrix_basis.copy()
        for m in n.modifiers:
            if m.type == 'ARMATURE':
                m.object = rig
        made.append(n)
    bpy.context.view_layer.update()

    # The graft is only correct if each piece stands on THIS man exactly where
    # the donor stands on his. Comparing to the rig centre would be wrong - a
    # T-pose forearm legitimately sits 0.60 m out. The invariant is that the
    # rig-relative offset is preserved; anything else means a parent-inverse
    # survived that cancels the rig's own transform (the defect being repaired:
    # us_pilot_white's old cap_head sat 10.46 m off him).
    dg = bpy.context.evaluated_depsgraph_get()

    def centre(o):
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        pts = [ev.matrix_world @ v.co for v in me.vertices]
        ev.to_mesh_clear()
        lo = Vector(map(min, *pts)) if len(pts) > 1 else pts[0]
        hi = Vector(map(max, *pts)) if len(pts) > 1 else pts[0]
        return (lo + hi) / 2

    for n, d in zip(made, [donors[p] for p in GIB_CONTRACT]):
        off = (centre(n) - rig.location) - (centre(d) - src.location)
        if off.length > 1e-4:
            raise SystemExit("ABORT %s: grafted %s is %.4f m off the donor's "
                             "rig-relative place" % (unit_id, n.name, off.length))
    print("  %-16s grafted %d gib donors from %s" % (unit_id, len(made), src_name), flush=True)
    return made


def export_one(unit_id, rig_name):
    bpy.ops.wm.open_mainfile(filepath=LINEUP)     # fresh every time
    rig = bpy.data.objects.get(rig_name)
    if rig is None:
        raise SystemExit("ABORT %s: rig '%s' not in the lineup" % (unit_id, rig_name))

    # BEFORE the purge - the donor rig and its children have to still exist.
    graft_gib_donors(unit_id, rig)

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

    # The split head donor keeps whatever face atlas it was cut with, and the
    # black variants were cut from the white line: measured 2026-08-08,
    # grunt_head on us_pilot_black pointed at face_atlas_v5 while his joined
    # body used face_atlas_v5_black, so his severed head was a white man's.
    # The two atlases share layout and size (1296x1132) and differ only in
    # tone - donor-island mean RGB (0.404,0.279,0.194) vs (0.172,0.099,0.067) -
    # so this is a material repoint, not a re-unwrap. Must run BEFORE
    # build_head_frags, which copies grunt_head's mesh data materials and all.
    jb = bpy.data.objects.get("us_grunt_joined")
    head = bpy.data.objects.get("grunt_head")
    if jb is not None and head is not None:
        face = next((s.material for s in jb.material_slots
                     if s.material and s.material.name.startswith("face_atlas")), None)
        if face is not None:
            for s in head.material_slots:
                if s.material and s.material.name.startswith("face_atlas") and s.material != face:
                    print("  %-16s head atlas %s -> %s"
                          % (unit_id, s.material.name, face.name), flush=True)
                    s.material = face

    missing = [p for p in GIB_CONTRACT if bpy.data.objects.get(p) is None]
    if missing:
        raise SystemExit("ABORT %s: gib contract incomplete after rename: %s"
                         % (unit_id, missing))

    # GibSystem.dismember_head_burst() returns false on an empty head_frag_*
    # list, so a rig without these cannot lose its head. After the rename (it
    # resolves "grunt_head"/"PSXRig" by name), before the height normalize.
    build_head_frags()
    frags = [o for o in bpy.data.objects if o.name.startswith("head_frag_")]
    for o in frags:                    # built hidden; select_set no-ops on hidden
        o.hide_set(False)
        o.hide_viewport = False
        o.hide_render = False

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

    exportables = [rig] + meshes + frags
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in exportables:
        o.select_set(True)
    bpy.context.view_layer.objects.active = rig

    # see flatten_procedural_colors: a node-driven Base Color ships as WHITE
    flatten(exportables)
    left = assert_none_white(exportables)
    if left:
        raise SystemExit("ABORT %s: material(s) would ship on the engine default: %s"
                         % (unit_id, left))

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
    print("  %-16s h=%.3f -> k=%.3f  %2d meshes  %d frags  %5.2f MB  %s"
          % (unit_id, h, s, len(meshes), len(frags), mb, os.path.basename(out)), flush=True)


_only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
print("=== exporting pilots + medic ===", flush=True)
for uid, rig in UNITS:
    if _only and uid not in _only:
        continue
    export_one(uid, rig)
print("=== done ===", flush=True)
