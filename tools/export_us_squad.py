"""export_us_squad.py - export the six v3 grunts from the lineup, one GLB each.

    blender -b -P tools/export_us_squad.py

Mirrors tools/export_us_grunt_v2.py (the PROVEN exporter) - its export call is
copied verbatim, not reinvented. The three contracts it enforces:

  1. THE RIG MUST BE NAMED "PSXRig". model_actor.gd resolves every shared clip as
     PSXRig/Skeleton3D:mixamorig_* . Rename the armature and the whole 100-clip
     library goes silent (T-pose) on that character.

  2. MESH NAMES ARE LOAD-BEARING. hitzone_builder._GEAR_NAME_HINTS excludes gear
     from the hurtbox BY SUBSTRING; gib_system.REGIONS looks pieces up BY EXACT
     NAME (cap_head, helmet_camo_shell...). So the per-man "_rifleman" suffix must
     be STRIPPED before export or the gibs never fire and the gear gets shot.

  3. HEIGHT IS MEASURED OVER THE BODY *AND* EVERY *_worn PIECE. Measure the body
     alone and the normalizer puts his BARE SKULL at 1.7132 m, quietly growing
     every grunt by the height of a helmet (ADR-002).
"""
import bpy, os, sys
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_head_frags import build_head_frags

LINEUP = r"C:\Users\caleb\RECONgame\assets\us\characters\us_base_v3.blend"
OUT_DIR = r"C:\Users\caleb\RECONgame\assets\us\characters"
TARGET_HEIGHT = 1.7132                     # ADR-002. top of helmet, feet at origin.
TAGS = ["rifleman", "grenadier", "mg", "rto", "marksman", "pointman"]


# Men who may never carry a PRC-25: the radio is not exported into their mesh, so
# GruntDresser cannot promote them to radioman (it refuses - see RADIO_FORBIDDEN).
# The rifleman and pointman DO carry it in-mesh but hidden, so either can be promoted.
NO_RADIO = ("marksman", "mg", "grenadier")
RADIO_PREFIX = "prc25_"


def soldier_parts(tag):
    rig = bpy.data.objects["PSXRig_" + tag]
    meshes = [o for o in bpy.data.objects
              if o.type == 'MESH' and o.name.endswith("_" + tag)]
    if tag in NO_RADIO:
        dropped = [o.name for o in meshes if o.name.startswith(RADIO_PREFIX)]
        meshes = [o for o in meshes if not o.name.startswith(RADIO_PREFIX)]
        if dropped:
            print("  %-10s NO RADIO - dropped %s" % (tag, dropped), flush=True)
    return rig, meshes


def export_one(tag):
    bpy.ops.wm.open_mainfile(filepath=LINEUP)       # fresh every time - no cross-contamination
    rig, meshes = soldier_parts(tag)

    # DELETE every other object FIRST.
    #
    # This is not tidiness, it is the whole contract. The lineup still holds the
    # BASE grunt's untagged `helmet_camo_shell`, `grunt_head`, `cap_head`... So when
    # we strip "_rifleman" off this man's copies, Blender hits a name collision and
    # silently appends .001:  grunt_head -> grunt_head.001
    #
    # GibSystem.REGIONS looks its meshes up by EXACT NAME. `grunt_head.001` matches
    # nothing. Every dismemberment prints "OFF-CONTRACT" and does nothing - and it
    # looks fine in the viewport, because the PREFIX-based hiding still works. That
    # is exactly how this shipped unnoticed.
    keep = set([rig] + meshes)
    for o in list(bpy.data.objects):
        if o not in keep:
            bpy.data.objects.remove(o, do_unlink=True)

    # everything must be visible or select_set() silently no-ops and the piece
    # never reaches the GLB. the GAME hides the gib donors at runtime, not us.
    for o in bpy.data.objects:
        o.hide_set(False)
        o.hide_viewport = False
        o.hide_render = False

    # contract 1 + 2: canonical names. no collisions left, so no .001 suffixes.
    rig.name = "PSXRig"
    for o in meshes:
        o.name = o.name[: -(len(tag) + 1)]
        # Canteens ship numbered (the game collapses them); Godot maps "." -> "_" on
        # import, so mirror that. Any OTHER dotted name is a real strip-collision that
        # would silently break gib lookups -> abort.
        if "." in o.name:
            if o.name.split(".")[0].startswith("canteen"):
                o.name = o.name.replace(".", "_")
            else:
                raise SystemExit("ABORT %s: '%s' still has a name-collision suffix. "
                                 "GibSystem looks meshes up by exact name and this "
                                 "would silently break every gib." % (tag, o.name))
        o.data.name = o.name

    rig.data.pose_position = 'REST'
    if rig.animation_data:
        for tr in rig.animation_data.nla_tracks:
            tr.mute = True
        rig.animation_data.action = None
    bpy.context.view_layer.update()

    # GibSystem.dismember_head_burst() collects head_frag_* and returns false on an
    # empty list, so a rig without these cannot lose its head. Must run AFTER the
    # rename (it resolves "grunt_head" and "PSXRig" by name) and BEFORE the height
    # normalize (it parents to the rig, so the scale carries it).
    build_head_frags()
    frags = [o for o in bpy.data.objects if o.name.startswith("head_frag_")]
    # It builds them hidden (they sit inside the skull until they fly), and
    # select_set() silently no-ops on a hidden object - so they would generate
    # cleanly and never reach the GLB. The game re-hides them by prefix.
    for o in frags:
        o.hide_set(False)
        o.hide_viewport = False
        o.hide_render = False
    print("  %-10s head frags: %d" % (tag, len(frags)), flush=True)

    # contract 3: measure body + every *_worn piece.
    #
    # ...EXCEPT anything with a whip antenna on it. The PRC-25's antenna tops out
    # at 2.60 m - a metre above his helmet. Let it into the height box and the
    # normalizer squeezes the WHOLE MAN down to 0.658x to force the antenna tip
    # to 1.7132 m. Every radio grunt ships 34% short. This shipped once as a
    # rename (prc25_radio_pack) and the rename got saved over, so it is now
    # enforced HERE, where a name change cannot undo it.
    HEIGHT_EXCLUDE = ("radio", "antenna", "prc25", "handset")
    dg = bpy.context.evaluated_depsgraph_get()
    parts = [bpy.data.objects["us_grunt_joined"]]
    parts += [o for o in meshes
              if o.name.endswith("_worn")
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
    # a grunt is ~1.8 m in the blend. anything outside this band means something
    # tall (an antenna, a rifle held overhead) leaked into the box - FAIL LOUD
    # rather than silently shipping a 34%-short soldier.
    if not (1.60 <= h <= 2.00):
        raise SystemExit(
            "ABORT %s: height box is %.3f m, expected 1.60-2.00 m.\n"
            "  Something tall got into the box. Parts measured: %s"
            % (tag, h, [o.name for o in parts]))
    s = TARGET_HEIGHT / h
    M = Matrix.Scale(s, 4) @ Matrix.Translation(
        Vector((-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, -mn.z)))
    rig.matrix_world = M @ rig.matrix_world
    bpy.context.view_layer.update()

    exportables = [rig] + meshes + frags
    # NOT bpy.ops.object.select_all - it needs a valid context and poll()-fails in
    # background mode when there's no active object. Direct API cannot fail that way.
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in exportables:
        o.select_set(True)
    bpy.context.view_layer.objects.active = rig

    out = os.path.join(OUT_DIR, "us_grunt_%s.glb" % tag)
    bpy.ops.export_scene.gltf(
        filepath=out,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_animations=False,          # mesh-only: clips come from anim_library.glb
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
    print("  %-10s h=%.3f -> k=%.3f  %2d meshes  %5.2f MB  %s"
          % (tag, h, s, len(meshes), mb, os.path.basename(out)), flush=True)
    return out


print("=== exporting the v3 squad ===", flush=True)
for t in TAGS:
    export_one(t)
print("=== done ===", flush=True)
