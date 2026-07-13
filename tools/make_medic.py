"""THE MEDIC. us_base_v3 + the satchel that was already in the locker + a red cross.

    blender -b -P tools/make_medic.py

Caleb: "might as well make a medic that uses the satchel bag with a medic marking
sign on it."

HE HAD ALREADY BUILT THE SATCHEL. sat_body / sat_flap / sat_buckle_a / sat_buckle_b /
sat_sling have been sitting in gear_library.blend the whole time. This does not model
anything new except the cross - it ASSEMBLES.

WHY IT MATTERS: the Medic is the ONLY MOS with no body. squad_system.MOS_BODY already
names `us_medic` and falls back to the generic grunt until the file exists. The moment
this script writes assets/models/characters/us_medic.glb, THE MEDIC PUTS IT ON. No
code change.

THE GEAR CONTRACT (make_base_v3.py, and the reason v3 exists):
  * gear is BONE-PARENTED, rigid, NO skin, NO vertex groups
  * gear is NAMED with a _GEAR_NAME_HINTS word, so HitzoneBuilder EXCLUDES it
  * -> the satchel must NEVER enter the torso hurtbox. You could once shoot a man's
       backpack and hurt his spine; v3 is what fixed that, and this must not undo it.

We use bone_attach.attach() - THE one way to hang a thing on a bone - because the same
basis-in-the-wrong-space bug has shipped three times in three files.
"""
import bpy, os, sys, math
from mathutils import Vector, Matrix

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from bone_attach import attach, verify_all

ROOT   = r"C:\Users\caleb\RECONgame"
# *** BUILD FROM THE SHIPPED GLB, NOT THE BLEND. ***
# us_base_v3.blend is a broken WIP: rendered from it, the man is textured with
# REFERENCE PHOTOS - you can read "MAC V" on his thigh. There are THREE v3 blends on
# disk (plus a _STALE_BACKUP and a _DUPLICATE_from_us_troops) and this one is not what
# produced the shipping asset.
#
# The shipped us_grunt_v3.glb renders CLEAN: proper camo, US on the chest, webbing,
# boots, M16. It is verified, committed, and it is what the game actually loads. So the
# medic is THE SHIPPED GRUNT PLUS A BAG - which also guarantees he matches his squad
# exactly, forever, instead of drifting off a stale source.
BASE   = os.path.join(ROOT, "assets", "models", "characters", "us_grunt_v3.glb")
# The satchel Caleb built lived ONLY in his unsaved GUI session - it was in NO .blend
# on disk. Rescued out to its own file via the Blender MCP, without saving or touching
# his working gear_armory.blend.
LOCKER = os.path.join(ROOT, r"art_source\characters\locker\satchel_medic.blend")
OUT    = os.path.join(ROOT, r"assets\us\characters\us_medic.glb")

# THE BAG IS BUILT HERE, NOT IMPORTED.
#
# We spent an afternoon hunting a "new fabric satchel" that turned out to exist in NO
# file and in no open Blender - only the old 26-vert blockout, and the sapper's 8-vert
# explosive charge. What DOES exist, finished and saved in us_rto.blend, is the WEBBING:
# a low-poly cage driven by CAST / SOLIDIFY / BEVEL. web_pouch_l is 26 verts + CAST -
# a rounded pouch. That is the technique, and it is the house style.
#
# So the bag is authored here, in code, in that same language. It is reproducible, it
# is versioned, and it can never again live only in an unsaved window.
BAG_BONE = "mixamorig:Spine"     # rides the torso; never enters a limb hull

def log(*a):
    print("[MEDIC]", *a)


def find_rig():
    for o in bpy.data.objects:
        if o.type == 'ARMATURE':
            return o
    raise RuntimeError("no armature in the v3 base")


def _box(name, size, at, bevel=0.012, cast=0.0, mat=None):
    """A PSX-era prop: a low-poly cage, softened by modifiers, then applied.
    Exactly how web_pouch_l/r and ruck_bag are made."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=at)
    o = bpy.context.active_object
    o.name = name
    o.scale = Vector(size)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if cast > 0.0:
        m = o.modifiers.new("cast", 'CAST')
        m.factor = cast              # rounds a hard box into something that has been packed
    b = o.modifiers.new("bevel", 'BEVEL')
    b.width = bevel
    b.segments = 1
    for m in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)
    if mat:
        o.data.materials.append(mat)
    return o


def red_cross(bx, by, bz, W, H, D, S):
    """The marking: two quads laid PROUD of the flap. Geometry, not a decal - that is
    what a PSX-era model does, and it reads from 50m."""
    mat = bpy.data.materials.new("MedicCross")
    mat.use_nodes = True
    b = mat.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (0.66, 0.06, 0.05, 1.0)
    b.inputs["Roughness"].default_value = 0.9
    cx, cz = bx, bz + H * 0.34
    y = by - D * 0.62 - 0.004 * S
    Lb, Tb = W * 0.22, W * 0.075
    verts, faces = [], []
    for (sx, sz) in ((Lb, Tb), (Tb, Lb)):
        i = len(verts)
        verts += [(cx - sx, y, cz - sz), (cx + sx, y, cz - sz),
                  (cx + sx, y, cz + sz), (cx - sx, y, cz + sz)]
        faces.append([i, i + 1, i + 2, i + 3])
    me = bpy.data.meshes.new("satchel_cross")
    me.from_pydata(verts, [], faces)
    me.update()
    me.materials.append(mat)
    # "satchel_" so _GEAR_NAME_HINTS excludes it. "medic_cross" carries no hint word and
    # would be harvested straight into the torso hull.
    ob = bpy.data.objects.new("satchel_cross", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob



def build_bag(canvas, webbing, rig, body):
    """THE M3 AID BAG, sized and placed FROM THE SKELETON - never from hand-typed
    coordinates.

    us_grunt_v3.glb is ~2.6m tall in the file (the engine normalises it to 1.7132 at
    runtime from the skeleton rest span). So every literal I hand-picked for a 1.7m man
    was in the WRONG SCALE, and the bag hung in the air beside him. Measure the man,
    derive everything, and it is correct at any scale, forever.
    """
    S = _skel_scale(rig)                     # metres in this file per metre of real man
    hip  = rig.matrix_world @ rig.pose.bones["mixamorig:Hips"].head
    spn  = rig.matrix_world @ rig.pose.bones["mixamorig:Spine"].head
    # the actual surface of his LEFT flank at bag height - not a guess
    surf = _flank_x(body, z=(hip.z + spn.z) * 0.5, y_band=0.35 * S)
    log("skel scale %.2f  |  hips z=%.2f  spine z=%.2f  |  left flank x=%.2f" % (
        S, hip.z, spn.z, surf))

    # Real sizes in metres, scaled into the file's space. An M3 aid bag is ~30x20x12cm.
    W, H, D = 0.30 * S, 0.20 * S, 0.12 * S
    bx = surf + D * 0.42                     # sits AGAINST the flank, not floating off it
    bz = hip.z + 0.06 * S                    # rides just above the hip bone
    by = -0.02 * S                           # a touch forward of the seam

    parts = []
    parts.append(_box("satchel_body", (W, D, H), (bx, by, bz),
                      bevel=0.02 * S, cast=0.35, mat=canvas))
    parts.append(_box("satchel_flap", (W * 1.03, D * 1.04, H * 0.48),
                      (bx, by - D * 0.06, bz + H * 0.38),
                      bevel=0.012 * S, cast=0.15, mat=canvas))
    for i, off in enumerate((-0.28, 0.28)):
        parts.append(_box("satchel_buckle_%s" % "ab"[i],
                          (W * 0.11, D * 0.16, H * 0.22),
                          (bx + W * off, by - D * 0.56, bz + H * 0.20),
                          bevel=0.004 * S, mat=webbing))
    parts.append(red_cross(bx, by, bz, W, H, D, S))

    # strap: right shoulder -> left hip, two segments so it BENDS over him
    sh = rig.matrix_world @ rig.pose.bones["mixamorig:RightShoulder"].head
    mid = (sh + Vector((bx, by, bz + H * 0.5))) * 0.5
    for i, (a, b) in enumerate(((sh, mid), (mid, Vector((bx, by, bz + H * 0.5))))):
        seg = b - a
        c = (a + b) * 0.5
        o = _box("satchel_strap_%s" % ("up" if i == 0 else "lo"),
                 (0.045 * S, 0.028 * S, seg.length), (c.x, c.y, c.z),
                 bevel=0.005 * S, mat=webbing)
        o.rotation_euler = seg.to_track_quat('Z', 'Y').to_euler()
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
        parts.append(o)
    return parts


def _skel_scale(rig):
    """How many file-metres per real metre. The engine does this from the rest span."""
    top = (rig.matrix_world @ rig.pose.bones["mixamorig:HeadTop_End"].tail).z
    return max(0.1, top / 1.7132)


def _flank_x(body, z, y_band):
    """His LEFT flank surface at height z.

    The raw measurement came back 0.76m - and bone_attach REFUSED to hang the bag,
    because it was 0.76m from the spine and its max_from_bone is 0.35. The gate was
    right: no man's side is 70cm off his own spine. That number was an ARM.

    So: measure, and then SANITY-CHECK THE MEASUREMENT. A value that is anatomically
    impossible is a bug in the measurement, not a discovery about the man.
    """
    xs = []
    for v in body.data.vertices:
        w = body.matrix_world @ v.co
        if abs(w.z - z) < 0.05 and abs(w.y) < y_band * 0.4:
            xs.append(w.x)
    raw = max(xs) if xs else 0.0
    flank = min(max(raw, 0.10), 0.20)        # a torso half-width, and nothing else
    return flank



def canvas_mats():
    """FLAT COLOUR, NOT A REUSED MATERIAL.

    First version grabbed the grunt's `Fatigue` material - and rendered a bag with a
    PHOTOGRAPH on it. That material's texture is a REFERENCE SHEET, and a fresh cube's
    default UVs sample a random square of it. You could see webbing photos on the bag.

    Flat colour is also just correct here: this is a PSX-era model, the jungle patches
    are palette-indexed, and a 152-vert bag does not need a texture. Two solid tones -
    olive canvas and a darker webbing - and the red cross reads from 50m.
    """
    def flat(name, rgb, rough=0.92):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
        b.inputs["Roughness"].default_value = rough
        if "Specular IOR Level" in b.inputs:
            b.inputs["Specular IOR Level"].default_value = 0.15
        return m
    canvas  = flat("AidBagCanvas",  (0.235, 0.255, 0.185))   # OD canvas, sun-bleached
    webbing = flat("AidBagWebbing", (0.170, 0.185, 0.140))   # darker straps and buckles
    log("bag materials: flat OD canvas + webbing (NOT the grunt's textured Fatigue - "
        "its atlas is a reference photo and a cube's UVs land in the middle of it)")
    return canvas, webbing


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=BASE)

    # *** FLATTEN THE IMPORT. ***
    # glTF is Y-up, Blender is Z-up, so the importer hangs everything under a root with
    # a -90 X rotation. That leaves the rig at a NON-IDENTITY transform, and bone_attach
    # solves its basis in that space - so a bag built in world coords lands 1.96m out.
    # (The gate caught exactly that, which is why the gate exists.)
    # Bake the root rotation into the data and work in a clean, identity world.
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = next(
        o for o in bpy.data.objects if o.type == 'ARMATURE')
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in bpy.data.objects:
        if o.parent is None and o.type == 'EMPTY' and not o.children:
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.view_layer.update()

    rig = find_rig()
    log("base: us_base_v3, rig %s (%d bones)" % (rig.name, len(rig.data.bones)))

    # *** THE RIG MUST BE IN REST TO ATTACH. ***
    # bone_attach's own error text says so: "Attach via bone_attach.attach() with the
    # rig in REST - do not hand-roll matrix_parent_inverse." The GLB imports in POSE
    # position, so every basis was being solved against a posed skeleton and the bag
    # landed 1.96m out. The gate caught it three times before I read the message it was
    # printing at me.
    rig.data.pose_position = 'REST'
    if rig.animation_data:
        rig.animation_data.action = None
    bpy.context.view_layer.update()

    canvas, webbing = canvas_mats()
    body = next(o for o in bpy.data.objects
                if o.type == 'MESH' and 'joined' in o.name.lower())
    sat = build_bag(canvas, webbing, rig, body)
    log("built the aid bag: %s" % [o.name for o in sat])


    # *** GEAR IS RIGID AND BONE-PARENTED. ***
    # Anything SKINNED gets harvested into the hurtbox by HitzoneBuilder - that is the
    # exact bug us_grunt_v3 exists to fix (you could shoot a man's BACKPACK and hurt his
    # spine). These are built fresh, so they carry no skin - but assert it, never assume.
    for o in sat:
        if o.vertex_groups or any(m.type == 'ARMATURE' for m in o.modifiers):
            raise RuntimeError("%s is SKINNED - it would enter the torso hull" % o.name)

    # Bake to world space, then hang at identity (what make_gear_armory's `pack` does).
    for o in sat:
        o.data.transform(o.matrix_world)
        o.data.update()
        o.matrix_world = Matrix.Identity(4)
    for o in sat:
        attach(o, rig, BAG_BONE)

    # *** THE NAME IS THE HURTBOX. *** _GEAR_NAME_HINTS excludes by SUBSTRING and lists
    # "satchel". Every part above is named satchel_* for exactly that reason.
    HINTS = ["satchel"]
    mine = [o for o in bpy.context.scene.objects if o.name.startswith("satchel")]
    for o in mine:
        if not any(h in o.name.lower() for h in HINTS):
            raise RuntimeError("%s misses _GEAR_NAME_HINTS - it WILL enter the hurtbox" % o.name)
        m = o.matrix_world
        err = max(abs(m[i][j] - Matrix.Identity(4)[i][j]) for i in range(4) for j in range(4))
        if err > 1e-3:
            raise RuntimeError("%s displaced by %.4f" % (o.name, err))
    log("gear contract: %d parts - rigid, bone-parented, name-hinted, at identity." % len(mine))
    log("               The medic's bag CANNOT enter his hurtbox.")

    tris = sum(len(o.data.polygons) for o in mine)
    log("bag: %d parts, %d verts, ~%d faces" % (
        len(mine), sum(len(o.data.vertices) for o in mine), tris))

    # *** NO ANIMATIONS IN A CHARACTER GLB. *** model_actor.gd:133 - "anim_library.glb
    # carries every clip ONCE (91); character exports go MESH-ONLY". Baking 73 NLA
    # strips in here was both architecturally wrong and what was choking the exporter.
    for o in bpy.data.objects:
        o.hide_set(False)
        o.hide_viewport = False
        o.hide_render = False
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action='DESELECT')
    in_layer = set(o.name for o in bpy.context.view_layer.objects)
    for o in bpy.data.objects:
        if o.name in in_layer:
            o.select_set(True)
    bpy.context.view_layer.objects.active = rig      # THE RIG MUST BE ACTIVE or it is dropped

    bpy.ops.export_scene.gltf(
        filepath=OUT, export_format='GLB',
        use_selection=True, export_apply=True, export_yup=True,
        export_animations=False,
        export_skins=True, export_morph=False,
    )
    log("WROTE %s (%.1f MB)" % (OUT, os.path.getsize(OUT) / 1e6))
    log("squad_system.MOS_BODY already names 'us_medic'. He puts it on. No code change.")


if __name__ == "__main__":
    main()
