"""BATCH 2 - civilians and US aircrew, built on the v3 base.

    blender -b -P tools/make_civilians.py

Six units, each a clone of us_base_v3.blend (the gear-cut grunt):

    civ_farmer_m   1.62  black ba-ba pyjamas, conical hat, barefoot
    civ_farmer_f   1.52  as above, narrower shoulders
    civ_elder      1.55  pale shirt, thinner
    civ_kid        1.26  faded shirt, child head-to-body ratio
    us_pilot_white 1.7132  flight suit + SPH-4 helmet
    us_pilot_black 1.7132  same airframe, darker skin

WHY THIS IS EVEN POSSIBLE NOW: on us_grunt_v2 the helmet, bandolier and ruck were
WELDED into the body mesh - you could not build a farmer from it, because the ruck
WAS the body. us_base_v3 cut them into bone-parented `*_worn` meshes, so making a
civilian is now a delete. That was the point of the clone.

WHAT EVERY UNIT INHERITS (do not break these):
  * PSXRig, 41 bones, name is a contract -> the shared 100-clip anim library
  * the gib contract: grunt_* donors, splay_* bind copies, cap_* wound caps
  * one skinned body mesh -> probe_silhouette parts == 1
  * gear as rigid bone-parented `*_worn` -> never enters the hurtbox

MATERIALS: the body, the gib donors and the caps all share material SLOTS, so a
civilian is made by REPOINTING the slot ("us_grunt_mat" -> "civ_farmer_m_cloth")
rather than by reassigning faces. Repoint once, and the man, the arm that flies
off him and the stump left behind all match. Bare skin (hands, feet) is the one
exception: it is assigned per-face by dominant bone.

HEIGHT: authored at 1.7132 like every export, and the ENGINE scales each unit to
its ModelActor.UNIT_HEIGHT_M. Proportion is what the mesh must carry - a child is
not a shrunken adult, he is a small body under a big head - so `head` scales the
skull about the neck joint. Head scaling needs NO bone edit: head verts ride the
Head bone rigidly, so a bigger skull still animates correctly. LIMB-LENGTH changes
would need the bones moved too, and are deliberately not done here. POSTURE (the
elder's stoop) belongs in an animation clip, not in the rest skeleton.
"""
import bpy, bmesh, os, math
from mathutils import Vector, Matrix

BASE = r"C:\Users\caleb\RECONgame\art_source\characters\base_psx\us_base_v3.blend"

# WORKSPACES (Caleb, 2026-07-12): one folder per family, so a change to the
# farmers can never reach into the fireteam.
#   civilians/  farmers, elder, kid
#   us_troops/  the v3 base and every US variant (grunt, RTO, pilots, gun variants)
#   enemies/    VC and NVA
#   locker/     ALL equipment - bone-attachable, hitbox-free (gear_library.blend)
CIV_DIR = r"C:\Users\caleb\RECONgame\art_source\characters\civilians"
US_DIR = r"C:\Users\caleb\RECONgame\art_source\characters\us_troops"
RIG = "PSXRig"
BODY = "us_grunt_joined"

# every piece of US kit in the base blend: the live worn gear, the gib copies of
# that gear, and the rifle. A farmer has none of it.
US_KIT = [
    "helmet_shell_worn", "bandolier_worn", "ruck_pack_worn", "pouch_belt_worn",
    "helmet_camo_shell", "helmet_bugjuice", "ruck_bag", "ruck_crossbar",
    "ruck_rail_l", "ruck_rail_r", "bandolier", "bando_mag0", "bando_mag1",
    "bando_mag2", "m16_world", "Base_Human",
]

# What skin actually shows. A rice farmer works barefoot - that is half of why he
# reads as a farmer. A helicopter pilot does NOT: give him boots, or he flies in
# his socks. (Found by rendering: SKIN_BONES was global and the aircrew came out
# barefoot.)
BARE_PEASANT = ("Hand", "Foot", "ToeBase")
BARE_BOOTED = ("Hand",)
BOOT_BONES = ("Foot", "ToeBase")

# THE FACE ATLAS ALREADY HAS THE RIGHT FACES. It carries 11 faces along its
# bottom row - white, black, Asian male, Asian female, Asian youth - and every
# unit I built was pinned to face 0 (the grunt's scarred white face) and then
# TINTED brown to fake it. That is why "they all have US male faces". Use the
# faces that are there.
#
# The bottom row is NOT on the 10x96px grid the rest of the atlas uses - the
# faces are packed at irregular widths (44px to 99px). These bounds are MEASURED
# from the pixels, not derived from a grid; re-measure if the atlas is repainted.
# (u0, u1, v0, v1)
FACE_CELLS = [
    (0.0042, 0.0958, 0.0000, 0.1429),   #  0  scarred white male  <- the grunt
    (0.1010, 0.1469, 0.0000, 0.1429),   #  1  pale white male
    (0.1500, 0.1990, 0.0000, 0.1429),   #  2  old bald man, white beard
    (0.2146, 0.2854, 0.0000, 0.1429),   #  3  black man, beard + headset
    (0.3125, 0.3844, 0.0000, 0.1429),   #  4  black man, clean shaven
    (0.3969, 0.5000, 0.0000, 0.1429),   #  5  Asian male, young
    (0.5010, 0.6000, 0.0000, 0.1429),   #  6  Asian male, moustache
    (0.6167, 0.6865, 0.0000, 0.1429),   #  7  Asian male, gaunt, long hair
    (0.7177, 0.7823, 0.0000, 0.1429),   #  8  Asian female, bob
    (0.8042, 0.8958, 0.0000, 0.1429),   #  9  Asian youth
    (0.8990, 0.9990, 0.0000, 0.1429),   # 10  Asian female, tied back
]
GRUNT_FACE = 0

# cloth colours are LINEAR (they get sRGB-encoded on the way into the image)
UNITS = {
    "civ_farmer_m": dict(bare=BARE_PEASANT, face=6,  hat="conical",
                         cloth=(0.030, 0.030, 0.035), skin=(0.36, 0.20, 0.11),
                         head=1.00, shoulders=1.00, girth=1.00),
    "civ_farmer_f": dict(bare=BARE_PEASANT, face=8,  hat="conical",
                         cloth=(0.028, 0.030, 0.045), skin=(0.38, 0.22, 0.13),
                         head=1.00, shoulders=0.90, girth=0.96),
    "civ_elder":    dict(bare=BARE_PEASANT, face=7,  hat="conical",
                         cloth=(0.34, 0.31, 0.24), skin=(0.34, 0.19, 0.11),
                         head=1.00, shoulders=0.94, girth=0.90),
    "civ_kid":      dict(bare=BARE_PEASANT, face=9,  hat=None,
                         cloth=(0.10, 0.13, 0.17), skin=(0.38, 0.22, 0.13),
                         head=1.28, shoulders=0.88, girth=0.94),
    "us_pilot_white": dict(bare=BARE_BOOTED, face=1, hat="flight",
                           cloth=(0.075, 0.080, 0.045), skin=(0.55, 0.33, 0.22),
                           head=1.00, shoulders=1.00, girth=1.00),
    "us_pilot_black": dict(bare=BARE_BOOTED, face=4, hat="flight",
                           cloth=(0.075, 0.080, 0.045), skin=(0.10, 0.055, 0.032),
                           head=1.00, shoulders=1.00, girth=1.00),
}


def _srgb(c):
    """Linear -> sRGB. Blender reads an sRGB image's pixels as ALREADY encoded, so
    writing linear values straight in gets them decoded a second time and the whole
    unit renders near-black. This bit us on the jungle; do not lose it again."""
    c = max(0.0, min(1.0, c))
    return 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1.0 / 2.4)) - 0.055


def fabric(name, rgb, seed, weave=0.05, blotch=0.17):
    """A woven cloth texture, generated. The grunt's body samples a PHOTO of OD-green
    fabric - that is why he reads as cloth and why a flat colour reads as plastic.
    Civilians get the same treatment: full-bleed fabric, so wherever the body's UVs
    land they land on cloth. No UV work needed.

    Low-frequency blotches = wear and sun-fade. High-frequency grain + a 3px weave
    = the thread. Deterministic per unit (seeded), so a rebuild is byte-identical."""
    import random
    rnd = random.Random(seed)
    S, G = 256, 16
    grid = [[rnd.uniform(-1.0, 1.0) for _ in range(G + 1)] for _ in range(G + 1)]
    px = [0.0] * (S * S * 4)
    for y in range(S):
        fy = y * G / S
        y0 = int(fy)
        ty = fy - y0
        for x in range(S):
            fx = x * G / S
            x0 = int(fx)
            tx = fx - x0
            a = grid[y0][x0] * (1 - tx) + grid[y0][x0 + 1] * tx
            b = grid[y0 + 1][x0] * (1 - tx) + grid[y0 + 1][x0 + 1] * tx
            v = 1.0 + (a * (1 - ty) + b * ty) * blotch
            v += rnd.uniform(-1.0, 1.0) * 0.045                 # thread grain
            v += (weave if (x % 3 == 0) != (y % 3 == 0) else -weave)
            i = ((y * S) + x) * 4
            px[i]     = _srgb(rgb[0] * v)
            px[i + 1] = _srgb(rgb[1] * v)
            px[i + 2] = _srgb(rgb[2] * v)
            px[i + 3] = 1.0
    img = bpy.data.images.new(name, S, S, alpha=False)
    img.pixels.foreach_set(px)
    img.pack()
    return img


def cloth_mat(name, rgb, seed):
    """Principled with the fabric wired STRAIGHT into Base Color - a texture with a
    mix node in front of it does not survive glTF."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = fabric(name + "_tex", rgb, seed)
    tex.interpolation = 'Closest'          # PSX: no bilinear mush
    nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.92
    if "Specular IOR Level" in b.inputs:
        b.inputs["Specular IOR Level"].default_value = 0.0
    return m


def remap_face_uvs(unit, cell):
    """Point the head at a DIFFERENT face in the atlas.

    The head's UVs are laid out inside face 0's box. Rescale that box onto the
    target face's box and every feature - eyes, mouth, hair - lands correctly,
    because the atlas faces are all registered the same way inside their cells.
    Runs on the body AND the head gib donors, so the head that gets blown off a
    farmer is the same man's head."""
    su0, su1, sv0, sv1 = FACE_CELLS[GRUNT_FACE]
    du0, du1, dv0, dv1 = FACE_CELLS[cell]
    sw, sh = su1 - su0, sv1 - sv0
    dw, dh = du1 - du0, dv1 - dv0
    touched = 0
    for ob in bpy.data.objects:
        if ob.type != 'MESH' or not ob.data.uv_layers:
            continue
        mats = [s.material.name if s.material else "" for s in ob.material_slots]
        fi = [i for i, m in enumerate(mats) if m.startswith("face_atlas")]
        if not fi:
            continue
        uv = ob.data.uv_layers.active
        for p in ob.data.polygons:
            if p.material_index not in fi:
                continue
            for li in p.loop_indices:
                u, v = uv.data[li].uv
                uv.data[li].uv = (du0 + (u - su0) / sw * dw,
                                  dv0 + (v - sv0) / sh * dh)
                touched += 1
    return touched


def flat_mat(name, rgb):
    """PSX flat: an unlit-looking Principled with no spec. Exports as a plain
    glTF baseColorFactor - no node tree for the exporter to have to flatten."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    b.inputs["Roughness"].default_value = 0.9
    if "Specular IOR Level" in b.inputs:
        b.inputs["Specular IOR Level"].default_value = 0.0
    return m


def repoint_slot(slot_name, new_mat):
    """Repoint a material SLOT across every mesh that uses it - body, gib donors,
    splay copies, caps. One call and the man, the arm that flies off him and the
    stump he is left with all match."""
    n = 0
    for o in bpy.data.objects:
        if o.type != 'MESH':
            continue
        for s in o.material_slots:
            if s.material is not None and s.material.name == slot_name:
                s.material = new_mat
                n += 1
    return n


def assign_by_bone(ob, mat, bones):
    """Paint the faces a set of bones owns. Runs on the body AND the gib donors,
    so the forearm that flies off a farmer still ends in a bare hand."""
    if ob.type != 'MESH' or not ob.vertex_groups:
        return 0
    idx = len(ob.data.materials)
    ob.data.materials.append(mat)
    hits = 0
    for p in ob.data.polygons:
        tot = {}
        for vi in p.vertices:
            for g in ob.data.vertices[vi].groups:
                nm = ob.vertex_groups[g.group].name
                tot[nm] = tot.get(nm, 0.0) + g.weight
        if not tot:
            continue
        if any(b in max(tot, key=tot.get) for b in bones):
            p.material_index = idx
            hits += 1
    return hits


def skinned_meshes():
    """The live body and every gib donor - everything that is MADE of this man."""
    return [o for o in bpy.data.objects
            if o.type == 'MESH' and o.vertex_groups and not o.name.endswith("_worn")]


def scale_region(bones, factor, pivot, axes=(0, 1, 2)):
    """Scale every skinned vert about `pivot`, WEIGHTED by how much it belongs to
    `bones`. Weighting is what keeps the neck from tearing: a vert half-owned by
    the head moves half as far. Applied to every mesh with those groups (body AND
    the gib donors), so a big-headed kid loses a big head."""
    if abs(factor - 1.0) < 1e-4:
        return
    for o in bpy.data.objects:
        if o.type != 'MESH' or not o.vertex_groups:
            continue
        gi = {g.index for g in o.vertex_groups if any(b in g.name for b in bones)}
        if not gi:
            continue
        for v in o.data.vertices:
            w = sum(g.weight for g in v.groups if g.group in gi)
            if w <= 0.0:
                continue
            w = min(1.0, w)
            world = o.matrix_world @ v.co
            d = world - pivot
            for ax in axes:
                d[ax] *= (1.0 + (factor - 1.0) * w)
            v.co = o.matrix_world.inverted() @ (pivot + d)
        o.data.update()


def move_height_ruler(rig, factor, pivot):
    """Scaling the head MESH is not enough: ModelActor measures a man from the
    SKELETON (mixamorig_HeadTop_End -> LeftToeBase) and scales him to his declared
    height. Grow the skull and leave the bone, and the skull pokes out above its
    own ruler - the kid renders 1.31 m when the table says 1.26.

    HeadTop_End carries ZERO vertex weight (verified): it is a pure measuring
    stick, so moving it changes what the engine READS without changing how one
    single vertex DEFORMS. The deforming Head bone is deliberately not touched -
    moving it would shift the bind matrix and tear the neck when he turns."""
    if abs(factor - 1.0) < 1e-4:
        return
    prev = bpy.context.view_layer.objects.active
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    eb = rig.data.edit_bones.get("mixamorig:HeadTop_End")
    if eb is not None:
        inv = rig.matrix_world.inverted()
        p = inv @ pivot
        eb.head = p + (eb.head - p) * factor
        eb.tail = p + (eb.tail - p) * factor
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.context.view_layer.objects.active = prev


def cone(name, r_top, r_bot, h, seg=10):
    # cap_ends: the underside disc is what the head pokes through, and it is what
    # reads as the BRIM RING around the face. Without it you see straight up into
    # a hollow cone.
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg,
                          radius1=r_bot, radius2=r_top, depth=h)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return me


def uv_sphere(name, r, seg=10, rings=5):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return me


def bone_attach(ob, rig, bone, world):
    """Rigid bone attach. matrix_world is set AFTER parenting so Blender solves the
    basis - bone parenting adds a bone-LENGTH tail offset, and hand-rolling that
    inverse is how gear ends up in a pile at a man's feet."""
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = rig
    ob.parent_type = 'BONE'
    ob.parent_bone = bone
    ob.matrix_parent_inverse = Matrix.Identity(4)
    bpy.context.view_layer.update()
    ob.matrix_world = world
    bpy.context.view_layer.update()


def skull(rig):
    """Where the HEAD actually is, measured from the geometry.

    Do NOT size headgear off the Head BONE: `head.head` is the base of the skull
    (the neck joint), so a helmet placed relative to it lands 15cm low and cuts a
    band straight across the pilot's eyes. Measure the verts the Head bone owns
    and fit the hat to the skull it can see. This also means the KID - whose skull
    is scaled 1.3x - gets headgear that fits him, for free."""
    body = bpy.data.objects[BODY]
    gi = {g.index for g in body.vertex_groups if "Head" in g.name}
    pts = [body.matrix_world @ v.co for v in body.data.vertices
           if any(g.group in gi and g.weight > 0.5 for g in v.groups)]
    if not pts:
        h = rig.matrix_world @ rig.pose.bones["mixamorig:Head"].head
        return h + Vector((0, 0, 0.12)), 0.10, h.z + 0.23
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    centre = (lo + hi) * 0.5
    radius = max(hi.x - lo.x, hi.y - lo.y) * 0.5
    return centre, radius, hi.z


def add_hat(kind, rig):
    """Headgear as `*_worn`: rigid, unskinned, gear-named -> renders, never a hurtbox."""
    centre, r, crown = skull(rig)

    if kind == "conical":
        # NON LA. The old one FLOATED: it was a small cone parked above the crown,
        # so you could see daylight between hat and head.
        #
        # A real conical hat is ~40cm across and its BRIM COMES DOWN TO THE BROW -
        # the head sits up INSIDE the cone. That is what kills the gap: from any
        # angle you see hat, then face. You never see the join.
        #   brim: just above the eyes (skull centre + 2cm), radius 0.21
        #   apex: 5cm clear of the crown
        brim_z = centre.z + 0.020
        apex_z = crown + 0.055
        depth = apex_z - brim_z
        me = cone("hat_conical_worn", 0.014, 0.215, depth, seg=14)
        m = flat_mat("hat_straw", (0.30, 0.22, 0.09))
        me.materials.append(m)
        ob = bpy.data.objects.new("hat_conical_worn", me)
        # a few degrees of forward tilt - nothing on a working man sits square
        w = (Matrix.Translation(Vector((centre.x, centre.y, (brim_z + apex_z) * 0.5)))
             @ Matrix.Rotation(math.radians(-5.0), 4, 'X'))
        bone_attach(ob, rig, "mixamorig:Head", w)
        return ob

    if kind == "flight":
        # SPH-4: pale shell over the CROWN (never across the eyes - see skull()),
        # smoked visor down over the brow. Shell radius clears the skull by 2cm so
        # it reads as worn kit rather than a swollen head.
        R = r + 0.022
        me = uv_sphere("helmet_flight_worn", R, seg=12, rings=6)
        bm = bmesh.new()
        bm.from_mesh(me)
        # Cut at the brow: KEEP THE DOME, lose the jaw. Mind the polarity -
        # clear_inner removes what lies on the NEGATIVE side of plane_no, so with
        # a DOWN normal this exact call deletes the dome and leaves a bowl hanging
        # under his chin. That is how the pilot came to wear his helmet across his
        # eyes. Normal points UP; what goes is the half below the brow.
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:],
                               plane_co=(0, 0, -R * 0.35), plane_no=(0, 0, 1),
                               clear_outer=False, clear_inner=True)
        bm.to_mesh(me)
        bm.free()
        shell = flat_mat("flight_shell", (0.78, 0.78, 0.75))
        me.materials.append(shell)
        ob = bpy.data.objects.new("helmet_flight_worn", me)
        w = Matrix.Translation(Vector((centre.x, centre.y, centre.z + 0.028)))
        bone_attach(ob, rig, "mixamorig:Head", w)

        # visor: a shallow smoked band across the FRONT of the face (-Y faces
        # forward on this rig), sitting at brow height under the shell lip.
        visor = flat_mat("flight_visor", (0.05, 0.06, 0.08))
        vme = uv_sphere("visor_flight_worn", R * 0.97, seg=12, rings=6)
        bmv = bmesh.new()
        bmv.from_mesh(vme)
        for v in bmv.verts:
            v.co.z *= 0.42                       # squash into a band
        bmesh.ops.bisect_plane(bmv, geom=bmv.verts[:] + bmv.edges[:] + bmv.faces[:],
                               plane_co=(0, -R * 0.30, 0), plane_no=(0, -1, 0),
                               clear_outer=False, clear_inner=True)
        bmv.to_mesh(vme)
        bmv.free()
        vme.materials.append(visor)
        vob = bpy.data.objects.new("visor_flight_worn", vme)
        wv = Matrix.Translation(Vector((centre.x, centre.y, centre.z - 0.012)))
        bone_attach(vob, rig, "mixamorig:Head", wv)
        return ob

    return None


def build(unit, spec):
    bpy.ops.wm.open_mainfile(filepath=BASE)
    rig = bpy.data.objects[RIG]
    rig.data.pose_position = 'REST'
    bpy.context.view_layer.update()

    # 1. strip every scrap of US kit
    gone = []
    for n in US_KIT:
        for o in [x for x in bpy.data.objects if x.name == n or x.name.startswith(n + ".")]:
            gone.append(o.name)
            bpy.data.objects.remove(o, do_unlink=True)
    for o in [x for x in bpy.data.objects if x.name.startswith("canteen_l")]:
        gone.append(o.name)
        bpy.data.objects.remove(o, do_unlink=True)

    # 2. clothe him - repoint the shared slot, so donors and caps follow
    cloth = cloth_mat(unit + "_cloth", spec["cloth"], seed=abs(hash(unit)) % 9973)
    repoint_slot("us_grunt_mat", cloth)
    n_uv = remap_face_uvs(unit, spec["face"])
    print("      face -> atlas cell %d  (%d head UVs remapped)  cloth: woven"
          % (spec["face"], n_uv))

    # 3. bare skin where a peasant shows it
    skin = flat_mat(unit + "_skin", spec["skin"])
    boot = flat_mat(unit + "_boot", (0.02, 0.016, 0.012))
    faces = 0
    for ob in skinned_meshes():
        faces += assign_by_bone(ob, skin, spec["bare"])
        if spec["bare"] is BARE_BOOTED:
            assign_by_bone(ob, boot, BOOT_BONES)

    # 4. proportion (mesh only - see the module docstring on why no bone edits)
    neck = rig.matrix_world @ rig.pose.bones["mixamorig:Neck"].head
    chest = rig.matrix_world @ rig.pose.bones["mixamorig:Spine2"].head
    scale_region(("Head",), spec["head"], neck)
    move_height_ruler(rig, spec["head"], neck)   # keep the skeleton's ruler on the skull
    scale_region(("Shoulder", "Arm"), spec["shoulders"], chest, axes=(0,))
    scale_region(("Spine", "Hips"), spec["girth"], chest, axes=(0, 1))

    # 5. headgear
    hat = add_hat(spec["hat"], rig) if spec["hat"] else None

    rig.data.pose_position = 'POSE'
    if rig.animation_data:
        rig.animation_data.action = None
    bpy.context.scene.frame_set(1)

    # aircrew are US troops, not civilians - they live with the fireteam
    outdir = US_DIR if unit.startswith("us_") else CIV_DIR
    os.makedirs(outdir, exist_ok=True)
    path = os.path.join(outdir, unit + ".blend")
    bpy.ops.wm.save_as_mainfile(filepath=path)
    print("  %-15s stripped %2d US items | skin faces %3d | hat %-8s -> %s"
          % (unit, len(gone), faces, str(spec["hat"]), os.path.basename(path)))


def main():
    print("=== BATCH 2: civilians + aircrew, on the v3 gear-cut base ===")
    for unit, spec in UNITS.items():
        build(unit, spec)
    print("\nnext: export each with GUN='none' (unarmed -> no MuzzlePoint)")


if __name__ == "__main__":
    main()
