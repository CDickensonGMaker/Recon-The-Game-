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
BASE   = os.path.join(ROOT, r"art_source\characters\base_psx\us_base_v3.blend")
# The satchel Caleb built lived ONLY in his unsaved GUI session - it was in NO .blend
# on disk. Rescued out to its own file via the Blender MCP, without saving or touching
# his working gear_armory.blend.
LOCKER = os.path.join(ROOT, r"art_source\characters\locker\satchel_medic.blend")
OUT    = os.path.join(ROOT, r"assets\models\characters\us_medic.glb")

SATCHEL = ["sat_body", "sat_flap", "sat_buckle_a", "sat_buckle_b", "sat_sling"]

# The medic's bag rides on the hip/side, slung across the body. It hangs off the SPINE
# (the torso), not an arm - so it swings with the chest and never enters a limb hull.
BAG_BONE = "mixamorig:Spine"   # Blender uses a COLON; Godot sanitises it to "_"


def log(*a):
    print("[MEDIC]", *a)


def find_rig():
    for o in bpy.data.objects:
        if o.type == 'ARMATURE':
            return o
    raise RuntimeError("no armature in the v3 base")


def append_satchel():
    """Pull the satchel out of the locker. It was already built."""
    got = []
    with bpy.data.libraries.load(LOCKER, link=False) as (src, dst):
        want = [n for n in src.objects if n in SATCHEL]
        dst.objects = want
    for o in bpy.data.objects:
        if o.name in SATCHEL and o.users_collection == ():
            pass
    for o in list(bpy.data.objects):
        if o.name.split('.')[0] in SATCHEL and o.name not in [x.name for x in bpy.context.scene.objects]:
            bpy.context.scene.collection.objects.link(o)
            got.append(o)
    return got


def red_cross(parent):
    """The marking. A cross of two quads laid ON the satchel flap, offset a hair so it
    never z-fights. Not a decal, not a texture - the PSX way is geometry."""
    mat = bpy.data.materials.new("MedicCross")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.62, 0.05, 0.05, 1.0)   # dried blood red
    bsdf.inputs["Roughness"].default_value = 0.9

    # size the cross to the flap it sits on
    bb = [parent.matrix_world @ Vector(c) for c in parent.bound_box]
    lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    mid = (lo + hi) * 0.5
    w = (hi.x - lo.x)
    arm_l = w * 0.30      # bar length
    arm_w = w * 0.10      # bar thickness
    # the flap faces -Y (the man faces -Y); push the cross a hair proud of it
    y = lo.y - 0.002

    verts, faces = [], []
    for (sx, sz) in [(arm_l, arm_w), (arm_w, arm_l)]:   # horizontal bar, vertical bar
        i = len(verts)
        verts += [
            (mid.x - sx, y, mid.z - sz), (mid.x + sx, y, mid.z - sz),
            (mid.x + sx, y, mid.z + sz), (mid.x - sx, y, mid.z + sz),
        ]
        faces.append([i, i + 1, i + 2, i + 3])

    me = bpy.data.meshes.new("medic_cross")
    me.from_pydata(verts, [], faces)
    me.update()
    me.materials.append(mat)
    # "satchel_" so _GEAR_NAME_HINTS excludes it too. "medic_cross" contains NO hint
    # word and would have been harvested into the torso hull.
    ob = bpy.data.objects.new("satchel_cross", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def main():
    bpy.ops.wm.open_mainfile(filepath=BASE)
    rig = find_rig()
    log("base: us_base_v3, rig %s (%d bones)" % (rig.name, len(rig.data.bones)))

    sat = append_satchel()
    if not sat:
        raise RuntimeError("satchel not found in the locker: %s" % SATCHEL)
    log("appended %d satchel parts from the locker: %s" % (len(sat), [o.name for o in sat]))

    # *** THE NAME IS THE HURTBOX. ***
    # hitzone_builder._GEAR_NAME_HINTS excludes gear BY SUBSTRING, and it lists
    # "satchel" - but these parts are called sat_body / sat_flap / sat_sling, and
    # "sat_" DOES NOT CONTAIN "satchel". Ship them under those names and every one of
    # them is HARVESTED INTO THE TORSO HULL: you could shoot the medic's BAG and hurt
    # his SPINE. That is precisely the bug us_grunt_v3 exists to fix, and it would have
    # been undone silently, by a naming convention, in the same afternoon.
    for o in sat:
        stem = o.name.split('.')[0]
        o.name = stem.replace("sat_", "satchel_", 1)
    log("renamed for the gear contract: %s" % [o.name for o in sat])

    # *** STRIP THE SKIN. GEAR IS RIGID. ***
    # satchel_sling came out of the locker SKINNED (it has vertex groups), and the
    # guard below caught it. A skinned mesh gets harvested into the torso hull - so
    # shipping this sling would have silently undone us_grunt_v3 on the same afternoon
    # it went live. Gear is bone-parented and rigid, always. A PSX-era sling does not
    # need to deform.
    for o in sat:
        for m in [m for m in o.modifiers if m.type == 'ARMATURE']:
            o.modifiers.remove(m)
        if o.vertex_groups:
            log("stripped %d vertex group(s) off %s - gear must be RIGID" % (
                len(o.vertex_groups), o.name))
            o.vertex_groups.clear()

    # HE MODELLED IT IN PLACE. Measured: 0.40 x 0.30 x 0.69 m centred at z=1.13 - that
    # is a bag on the hip with the sling running up over the shoulder, exactly as worn.
    # DO NOT "correct" it. Measure, then leave it alone. Just hang it on the bone.
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    for o in sat:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
            hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
    log("satchel as modelled: %.2f x %.2f x %.2f m, centre z=%.2f - worn, not racked" % (
        hi.x - lo.x, hi.y - lo.y, hi.z - lo.z, (lo.z + hi.z) * 0.5))

    # *** BAKE THE TRANSFORM INTO THE VERTS, THEN ATTACH AT IDENTITY. ***
    # This is exactly what make_gear_armory's `pack` does, and it exists because Caleb
    # sets origin-to-geometry ("its easier to edit things that way" - and it is). That
    # moves the verts into local space while keeping the world position identical, so a
    # prop attached with a non-identity object transform fails bone_attach's verify_all
    # gate. Bake first; then the verts ARE the world position and identity is correct.
    for o in sat:
        me = o.data
        me.transform(o.matrix_world)
        me.update()
        o.matrix_world = Matrix.Identity(4)
    for o in sat:
        attach(o, rig, BAG_BONE)          # default world = identity
    log("satchel baked to world space and hung at identity on %s" % BAG_BONE)

    # The cross, on the flap, parented to the same bone so it rides with the bag.
    flap = next((o for o in sat if o.name.split('.')[0] == "sat_flap"), sat[0])
    cross = red_cross(flap)
    attach(cross, rig, BAG_BONE)      # built in world space -> identity

    # *** VERIFY THE GEAR CONTRACT - and verify the RIGHT THING. ***
    #
    # My first version of this check flagged ruck_bag, m16_world and the gib donors,
    # all of which ship fine in v3. THE CHECK WAS WRONG, NOT THE MODEL - and it is a
    # good thing it hard-failed instead of quietly "fixing" a shipping asset.
    #
    # HitzoneBuilder harvests hulls by skinning verts THROUGH BONES. A bone-parented
    # rigid prop has NO armature modifier and NO vertex groups, so it contributes NO
    # vertices and is excluded BY CONSTRUCTION. That is what actually keeps the ruck
    # out of the torso hull. The _GEAR_NAME_HINTS list is the belt-and-braces for
    # anything that IS skinned.
    #
    # So the real test for our new gear is: (1) is it bone-parented and unskinned?
    # and (2) does its name ALSO carry a hint, so a future skin-by-accident is caught?
    mine = [o for o in bpy.context.scene.objects if o.name.startswith("satchel")]
    HINTS = ["satchel"]
    for o in mine:
        skinned = any(m.type == 'ARMATURE' for m in o.modifiers) or len(o.vertex_groups) > 0
        boned   = (o.parent is not None and o.parent_type == 'BONE')
        hinted  = any(h in o.name.lower() for h in HINTS)
        if skinned:
            raise RuntimeError("%s IS SKINNED - it would be harvested into the torso hull" % o.name)
        if not boned:
            raise RuntimeError("%s is not bone-parented - it will not follow the man" % o.name)
        if not hinted:
            raise RuntimeError("%s misses _GEAR_NAME_HINTS" % o.name)
    log("gear contract: %d satchel parts - bone-parented, UNSKINNED, name-hinted. "
        "The medic's bag CANNOT enter his hurtbox." % len(mine))

    ok = verify_all(rig, quiet=True)
    log("bone_attach verify_all: %s" % ("OK" if ok else "*** FAILED ***"))

    n = sum(1 for o in bpy.context.scene.objects if o.type == 'MESH')
    log("scene: %d meshes" % n)

    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(
        filepath=OUT, export_format='GLB',
        export_yup=True, use_selection=True,
        export_animations=True, export_animation_mode='ACTIONS',
        export_skins=True, export_morph=False,
    )
    log("WROTE %s (%.1f MB)" % (OUT, os.path.getsize(OUT) / 1e6))
    log("squad_system.MOS_BODY already names 'us_medic'. He puts it on. No code change.")


if __name__ == "__main__":
    main()
