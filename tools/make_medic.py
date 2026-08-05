"""THE MEDIC. us_base_v3 + the satchel that was already in the locker + a red cross.

    blender -b -P tools/make_medic.py

Caleb: "might as well make a medic that uses the satchel bag with a medic marking
sign on it."

HE HAD ALREADY BUILT THE SATCHEL. sat_body / sat_flap / sat_buckle_a / sat_buckle_b /
sat_sling have been sitting in gear_library.blend the whole time. This does not model
anything new except the cross - it ASSEMBLES.

WHY IT MATTERS: the Medic is the ONLY MOS with no body.

CORRECTED 2026-08-03. This header used to claim "squad_system.MOS_BODY already names
`us_medic` ... THE MEDIC PUTS IT ON. No code change." Measured: FALSE.
`scripts/squad/squad_system.gd:125-127` holds `DETERMINISTIC_MOS_BODY = {"RTO": ...}`
and nothing else, so MEDIC resolves through `MOS_WEAPON["MEDIC"] = "m16a1"` ->
`WEAPON_BODY_POOLS["m16a1"]` -> a random rifleman body. Exporting the file alone puts
it on nobody; one line of GDScript is still owed, and it is not a modeller's line.

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
from probe_gear_fit import assert_clear, limb_mask

from recon_paths import ROOT, US_CHARACTERS_DIR
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
# *** THE BASE IS A SQUAD BODY, NOT us_grunt_v3. ***
# Caleb, looking at the medic: "they have a different color pants." Measured, and he is
# right - and it is not the bag's fault, it is the base:
#     us_grunt_v3.glb   us_grunt_joined  v[0.0050 .. 0.7951]
#     us_grunt_rifleman us_grunt_joined  v[0.0952 .. 0.7951]
#     us_grunt_pointman us_grunt_joined  v[0.0952 .. 0.7951]
# Same mesh, same 453 verts, same atlas - but the v3 base man's UVs reach down into the
# v 0.005-0.095 strip that NO squad body uses, and that strip is a different shade of
# green. He is off-squad by construction, and since `us_grunt_v3` is still in
# WEAPON_BODY_POOLS["m16a1"] that mismatch is already in the game on other men too.
#
# Building off the rifleman also settles the helmet: the squad body already carries
# helmet_shell_worn + helmet_camo_shell + helmet_bugjuice, which IS the stock-helmet
# contract GruntRandomizer needs to swap in the fifteen authored variants. So the medic
# gets a real helmet by inheritance, with no new geometry and no cross on it.
BASE   = os.path.join(US_CHARACTERS_DIR, "us_grunt_rifleman.glb")
# The satchel Caleb built lived ONLY in his unsaved GUI session - it was in NO .blend
# on disk. Rescued out to its own file via the Blender MCP, without saving or touching
# his working gear_armory.blend.
# (a LOCKER constant pointing at the long-gone satchel_medic.blend used to sit
#  here; nothing in this file ever read it, so it is dropped rather than repointed)
OUT    = os.path.join(US_CHARACTERS_DIR, "us_medic.glb")

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


def _apply_mods(o):
    """Bake the modifier stack into the mesh WITHOUT bpy.ops.

    modifier_apply needs a valid active object and a poll() that passes; it is the
    first thing to break when a builder is run inside a live session instead of
    headless. new_from_object asks the depsgraph directly and cannot fail that way.
    """
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
    o.modifiers.clear()
    old = o.data
    o.data = me
    if old.users == 0:
        bpy.data.meshes.remove(old)


def _box(name, size, at, bevel=0.012, cast=0.0, mat=None):
    """A PSX-era prop: a low-poly cage, softened by modifiers, then applied.
    Exactly how web_pouch_l/r and ruck_bag are made."""
    sx, sy, sz = (s * 0.5 for s in size)
    co = [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz),
          (-sx, -sy, sz), (sx, -sy, sz), (sx, sy, sz), (-sx, sy, sz)]
    fa = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4),
          (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    me = bpy.data.meshes.new(name)
    me.from_pydata(co, [], fa)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.location = Vector(at)
    if cast > 0.0:
        m = o.modifiers.new("cast", 'CAST')
        m.factor = cast              # rounds a hard box into something that has been packed
    b = o.modifiers.new("bevel", 'BEVEL')
    b.width = bevel
    b.segments = 1
    _apply_mods(o)
    if mat:
        o.data.materials.append(mat)
    return o


def _surface(body, p, clearance, pmask=None):
    """`p` (world) pushed OUT to the body's surface plus `clearance`, and the normal.

    This is the whole strap fix in one function. The old strap was a straight box from
    the shoulder to the hip, and a straight line between two points on a man passes
    THROUGH him - 92 of its 96 verts were inside his chest. A sling does not do that: it
    LIES ON HIM. So every station of the strap is projected onto the surface it rides
    and lifted off it by a fixed clearance, which is the same thing fit_webbing.py gets
    from a live SHRINKWRAP, computed once and applied.
    """
    inv = body.matrix_world.inverted()
    lp = inv @ p
    ok, hit, nor, idx = body.closest_point_on_mesh(lp)
    if not ok or (pmask is not None and 0 <= idx < len(pmask) and pmask[idx]):
        # nearest surface is a T-posed ARM - not what a sling rides. Re-solve against
        # the torso only, by walking in towards the body's midline until the torso wins.
        for t in (0.15, 0.3, 0.45, 0.6, 0.75):
            q = lp.lerp(Vector((0.0, lp.y, lp.z)), t)
            ok2, h2, n2, i2 = body.closest_point_on_mesh(q)
            if ok2 and not (pmask is not None and pmask[i2]):
                hit, nor, ok = h2, n2, True
                break
    if not ok:
        return p, Vector((0.0, 0.0, 1.0))
    n = (body.matrix_world.to_3x3() @ nor).normalized()
    return (body.matrix_world @ hit) + n * clearance, n


def _ribbon(name, stations, half_w, thick, mat):
    """A strap: 4 corners per station, quads between consecutive stations.

    Each corner is projected to the surface INDEPENDENTLY (see _stations) rather than
    swept off a single spine, because a chest is curved - a rail built by offsetting
    sideways from a cleared centreline dives straight back into the ribs.
    """
    verts, faces = [], []
    for (c, n, side) in stations:
        s = side * half_w
        base = c
        verts += [base - s, base + s, base + s + n * thick, base - s + n * thick]
    for i in range(len(stations) - 1):
        a, b = i * 4, (i + 1) * 4
        for k in range(4):
            k2 = (k + 1) % 4
            faces.append([a + k, a + k2, b + k2, b + k])
    faces.append([0, 3, 2, 1])
    a = (len(stations) - 1) * 4
    faces.append([a, a + 1, a + 2, a + 3])
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    me.materials.append(mat)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def _stations(body, path, half_w, clearance, pmask=None):
    """Turn a rough world-space path into cleared ribbon stations."""
    out = []
    for i, p in enumerate(path):
        nxt = path[min(i + 1, len(path) - 1)]
        prv = path[max(i - 1, 0)]
        tan = (nxt - prv)
        if tan.length < 1e-6:
            tan = Vector((0.0, 0.0, 1.0))
        tan.normalize()
        c, n = _surface(body, p, clearance, pmask)
        side = tan.cross(n)
        if side.length < 1e-6:
            side = Vector((0.0, 1.0, 0.0))
        side.normalize()
        # Each rail gets its OWN surface solve. A single centre solve leaves the rails
        # buried wherever the body curves away under the strap's width.
        cl, _ = _surface(body, c + side * half_w, clearance, pmask)
        cr, _ = _surface(body, c - side * half_w, clearance, pmask)
        c = (cl + cr) * 0.5
        out.append((c, n, (cl - cr).normalized()))
    return out


def _hits(obstacles, objs, masks):
    for o in objs:
        for ob in obstacles:
            inv = ob.matrix_world.inverted()
            pm = masks.get(ob.name)
            for v in o.data.vertices:
                p = inv @ (o.matrix_world @ v.co)
                ok, hit, nor, i = ob.closest_point_on_mesh(p)
                if not ok or (pm is not None and 0 <= i < len(pm) and pm[i]):
                    continue
                if (p - hit).length < 0.35 and (p - hit).dot(nor) < 0.0:
                    return ob.name
    return None


def _push_clear(obstacles, objs, step, limit=60, masks=None):
    """Translate `objs` along +X until no vertex of any of them is inside any obstacle.

    The bag is placed from a measurement, but a measurement of a flank is a single
    number and a hip is not a plane. So the placement is CHECKED and corrected, and the
    correction it needed is printed - which is how a silent 5 cm burial becomes a line
    of log output instead of a shipped defect.

    THE OBSTACLES ARE NOT JUST THE MAN. He already wears an M1956 belt with an ammo
    pouch on the LEFT hip, which is exactly where a slung aid bag goes. A bag that
    clears his body and buries itself in his own pouch is the same defect one layer out,
    and it is the layer the eye actually notices.
    """
    masks = masks or {}
    moved = 0.0
    for _ in range(limit):
        hit = _hits(obstacles, objs, masks)
        if hit is None:
            return moved
        for o in objs:
            o.location.x += step
        bpy.context.view_layer.update()
        moved += step
    raise RuntimeError("bag would not clear %s after %d pushes" % (hit, limit))


def owned_by(rig):
    """Every mesh that belongs to THIS rig.

    Never `bpy.data.objects` with a name filter. These builders also run additively
    inside the owner's open us_base_v3.blend, which holds seven other soldiers - a bare
    name scan there finds the RIFLEMAN's ammo pouch and gates the medic's bag against a
    different man standing somewhere else in the scene.
    """
    out = []
    for o in bpy.data.objects:
        if o.type != 'MESH':
            continue
        if o.parent is rig or any(m.type == 'ARMATURE' and m.object is rig
                                  for m in o.modifiers):
            out.append(o)
    return out


def build_bag(canvas, webbing, rig, body):
    """THE M5 AID BAG, sized and placed FROM THE SKELETON - never from hand-typed
    coordinates.

    us_grunt_v3.glb is ~2.6m tall in the file (the engine normalises it to 1.7132 at
    runtime from the skeleton rest span). So every literal I hand-picked for a 1.7m man
    was in the WRONG SCALE, and the bag hung in the air beside him. Measure the man,
    derive everything, and it is correct at any scale, forever.

    AXES ARE LOAD-BEARING. The bag is 30 wide x 20 tall x 12 DEEP. The 12 cm depth is
    the axis that points at the man; the 30 cm width runs fore-and-aft along his hip.
    Building it (W, D, H) put the 30 cm face against him and offset it by half of D, so
    15 cm of bag sat inside a 5 cm gap - 36 of 96 body verts buried, 4.9 cm deep. It is
    built (D, W, H) now, and _push_clear checks the result instead of trusting it.
    """
    S = _skel_scale(rig)                     # metres in this file per metre of real man
    vmask, pmask = limb_mask(body)
    hip  = rig.matrix_world @ rig.pose.bones["mixamorig:Hips"].head
    spn  = rig.matrix_world @ rig.pose.bones["mixamorig:Spine"].head
    # the actual surface of his LEFT flank at bag height - not a guess
    surf = _flank_x(body, z=(hip.z + spn.z) * 0.5, y_band=0.35 * S, S=S, vmask=vmask)
    log("skel scale %.2f  |  hips z=%.2f  spine z=%.2f  |  left flank x=%.2f" % (
        S, hip.z, spn.z, surf))

    # Real sizes in metres, scaled into the file's space. An M5 aid bag is ~30x20x12cm.
    W, H, D = 0.30 * S, 0.20 * S, 0.12 * S
    CLEAR = 0.012 * S                        # canvas standing off the uniform
    bx = surf + D * 0.5 + CLEAR              # the THIN face against the flank
    bz = hip.z + 0.06 * S                    # rides just above the hip bone
    by = -0.02 * S                           # a touch forward of the seam

    bag = []
    bag.append(_box("satchel_body", (D, W, H), (bx, by, bz),
                    bevel=0.02 * S, cast=0.35, mat=canvas))
    bag.append(_box("satchel_flap", (D * 1.04, W * 1.03, H * 0.48),
                    (bx, by, bz + H * 0.38),
                    bevel=0.012 * S, cast=0.15, mat=canvas))
    for i, off in enumerate((-0.28, 0.28)):
        bag.append(_box("satchel_buckle_%s" % "ab"[i],
                        (D * 0.16, W * 0.11, H * 0.22),
                        (bx + D * 0.56, by + W * off, bz + H * 0.20),
                        bevel=0.004 * S, mat=webbing))
    # NO RED CROSS ON THE FIELD MEDIC. Ruled by the owner, and it is what the archival
    # footage shows: not one medic in any frame wears a brassard or a helmet cross,
    # because the marking made him the first man shot. The cross belongs inside the
    # wire - on the aid-station tent and on the doctor - and it is built there.
    WORN = ("web_pouch", "web_flap", "web_belt", "web_snap", "web_clip",
            "pouch_belt", "canteen")
    obstacles = [body] + [o for o in owned_by(rig)
                          if any(w in o.name for w in WORN)]
    moved = _push_clear(obstacles, bag, step=0.004 * S, masks={body.name: pmask})
    if moved:
        log("bag pushed %.1f cm clear of the flank and his own belt kit "
            "(the flank measurement alone was optimistic)" % (moved * 100.0))
    log("obstacles gated against: body + %d worn pieces"
        % (len(obstacles) - 1))

    # THE SLING. Over the RIGHT shoulder, across the chest, onto the bag at the LEFT
    # hip, so it never fouls the rifle. Routed ON the body, not through it.
    sh = rig.matrix_world @ rig.pose.bones["mixamorig:RightShoulder"].head
    nk = rig.matrix_world @ rig.pose.bones["mixamorig:Neck"].head
    top = Vector((bag[0].location.x, by, bz + H * 0.5))
    over = sh.lerp(nk, 0.35) + Vector((0.0, 0.0, 0.05 * S))
    path = [over]
    for t in (0.18, 0.36, 0.54, 0.72, 0.88, 1.0):
        path.append(over.lerp(top, t))
    st = _stations(body, path, half_w=0.026 * S, clearance=CLEAR, pmask=pmask)
    # the last station belongs ON the bag, not on the man
    st[-1] = (top + Vector((0.0, 0.0, -0.02 * S)), st[-1][1], st[-1][2])
    bag.append(_ribbon("satchel_sling", st, 0.026 * S, 0.010 * S, webbing))
    return bag


def _skel_scale(rig):
    """How many file-metres per real metre. The engine does this from the rest span."""
    top = (rig.matrix_world @ rig.pose.bones["mixamorig:HeadTop_End"].tail).z
    return max(0.1, top / 1.7132)


def _flank_x(body, z, y_band, S=1.0, vmask=None):
    """His LEFT flank surface at height z.

    The raw measurement came back 0.76m - and bone_attach REFUSED to hang the bag,
    because it was 0.76m from the spine and its max_from_bone is 0.35. The gate was
    right: no man's side is 70cm off his own spine. That number was an ARM.

    So: measure, and then SANITY-CHECK THE MEASUREMENT. A value that is anatomically
    impossible is a bug in the measurement, not a discovery about the man. The clamp is
    in FILE units (x S) - clamping real metres against a 2.69 m man silently truncated
    every flank wider than 18 cm.
    """
    xs = []
    for v in body.data.vertices:
        if vmask is not None and vmask[v.index]:
            continue                          # a T-posed forearm is not his flank
        w = body.matrix_world @ v.co
        if abs(w.z - z) < 0.05 * S and abs(w.y) < y_band * 0.4:
            xs.append(w.x)
    raw = max(xs) if xs else 0.0
    return min(max(raw, 0.10 * S), 0.22 * S)  # a torso half-width, and nothing else



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


def build_medic(rig, body):
    """Hang the aid bag on an ALREADY-IMPORTED, already-flattened grunt. Returns the
    bag parts. Split out of main() so the review staging can build the medic beside the
    doctor and the patient in one scene without re-entering an exporter."""
    canvas, webbing = canvas_mats()
    sat = build_bag(canvas, webbing, rig, body)
    log("built the aid bag: %s" % [o.name for o in sat])

    # *** GEAR IS RIGID AND BONE-PARENTED. ***
    # Anything SKINNED gets harvested into the hurtbox by HitzoneBuilder - that is the
    # exact bug us_grunt_v3 exists to fix (you could shoot a man's BACKPACK and hurt his
    # spine). These are built fresh, so they carry no skin - but assert it, never assume.
    for o in sat:
        if o.vertex_groups or any(m.type == 'ARMATURE' for m in o.modifiers):
            raise RuntimeError("%s is SKINNED - it would enter the torso hull" % o.name)

    # THE ELBOW GATE, in its numeric form. Run BEFORE the attach bakes everything to
    # identity, while the parts still sit where they were built.
    assert_clear("medic bag", body, sat)

    # Bake to world space, then hang at identity (what make_gear_armory's `pack` does).
    for o in sat:
        o.data.transform(o.matrix_world)
        o.data.update()
        o.matrix_world = Matrix.Identity(4)
    for o in sat:
        attach(o, rig, BAG_BONE)

    # *** THE NAME IS THE HURTBOX. *** _GEAR_NAME_HINTS excludes by SUBSTRING and lists
    # "satchel". Every part above is named satchel_* for exactly that reason.
    for o in sat:
        if "satchel" not in o.name.lower():
            raise RuntimeError("%s misses _GEAR_NAME_HINTS - it WILL enter the hurtbox"
                               % o.name)
        m = o.matrix_world
        err = max(abs(m[i][j] - Matrix.Identity(4)[i][j])
                  for i in range(4) for j in range(4))
        if err > 1e-3:
            raise RuntimeError("%s displaced by %.4f" % (o.name, err))
    log("gear contract: %d parts - rigid, bone-parented, name-hinted, at identity." % len(sat))
    log("               The medic's bag CANNOT enter his hurtbox.")
    log("bag: %d parts, %d verts, %d faces" % (
        len(sat), sum(len(o.data.vertices) for o in sat),
        sum(len(o.data.polygons) for o in sat)))
    return sat


def main(export=False):
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

    body = next(o for o in bpy.data.objects
                if o.type == 'MESH' and 'joined' in o.name.lower())
    build_medic(rig, body)

    tri = 0
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.data.calc_loop_triangles()
            tri += len(o.data.loop_triangles)
    log("us_medic: %d tris across %d meshes"
        % (tri, len([o for o in bpy.data.objects if o.type == 'MESH'])))

    # *** EXPORT IS GATED ON THE OWNER. *** 2026-08-03: "dont export til i pass it."
    # A .glb landing in assets/us/characters/ IS shipping - ModelActor.model_path()
    # resolves a unit_id straight off the folder, so the file appearing is the feature
    # going live. Default is build-and-measure only; pass --export once he has passed it.
    if not export:
        log("NOT EXPORTED (owner gate). Re-run with --export once he has passed it.")
        return

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
    log("NOTE: squad_system.gd:125 DETERMINISTIC_MOS_BODY holds only RTO. MEDIC still "
        "resolves through WEAPON_BODY_POOLS['m16a1'] to a random rifleman body, so "
        "this file does NOT put itself on anyone. One line of GDScript is still owed.")


if __name__ == "__main__":
    main(export="--export" in sys.argv)
