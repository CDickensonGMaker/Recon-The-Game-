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

BASE = r"C:\Users\caleb\RECONgame\assets\us\characters\us_base_v3.blend"

# WORKSPACES (Caleb, 2026-07-12): one folder per family, so a change to the
# farmers can never reach into the fireteam.
#   civilians/  farmers, elder, kid
#   us_troops/  the v3 base and every US variant (grunt, RTO, pilots, gun variants)
#   enemies/    VC and NVA
#   locker/     ALL equipment - bone-attachable, hitbox-free (gear_library.blend)
CIV_DIR = r"C:\Users\caleb\RECONgame\assets\civilians\characters"
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

# ---------------------------------------------------------------- the village
# VARIANTS, not clones. A village of identical men in identical black reads as a
# spawner, not a place. Each type gets several dye lots and, for most of them, a
# JOB - a sickle in the fist, a basket on the back, the shoulder pole. A civilian
# standing empty-handed in a paddy is a target; a civilian doing a job is a person,
# and the player has to make a decision about him.
#
# Props come out of the LOCKER (gear_library.blend), bone-attached and hitbox-free,
# so the same sickle hangs on a farmer, an elder, or a VC pretending to be one.
PROP_BONE = {
    "rice_basket_back": "mixamorig:Spine2",
    "rice_sickle":      "mixamorig:RightHand",
    "carry_pole":       "mixamorig:Spine2",
    "rice_bundle":      "mixamorig:LeftHand",
}

# base type -> (face, hat, skin, head, shoulders, girth, bare)
_TYPES = {
    "civ_farmer_m": dict(bare=BARE_PEASANT, face=6, hat="conical",
                         skin=(0.36, 0.20, 0.11), head=1.00, shoulders=1.00, girth=1.00),
    "civ_farmer_f": dict(bare=BARE_PEASANT, face=8, hat="conical",
                         skin=(0.38, 0.22, 0.13), head=1.00, shoulders=0.90, girth=0.96),
    "civ_elder":    dict(bare=BARE_PEASANT, face=7, hat="conical",
                         skin=(0.34, 0.19, 0.11), head=1.00, shoulders=0.94, girth=0.90),
    "civ_kid":      dict(bare=BARE_PEASANT, face=9, hat=None,
                         skin=(0.38, 0.22, 0.13), head=1.28, shoulders=0.88, girth=0.94),
}

# suffix -> (cloth [LINEAR], prop). Cloth colours are hand-dye lots: black ba-ba,
# brown homespun, indigo, and the faded ones that have been washed in a river for
# ten years.
_VARIANTS = {
    "civ_farmer_m": [("",   (0.030, 0.030, 0.035), None),               # black ba-ba
                     ("_b", (0.055, 0.040, 0.026), "rice_sickle"),      # brown, cutting
                     ("_c", (0.025, 0.032, 0.050), "rice_basket_back")],  # indigo, hauling
    "civ_farmer_f": [("",   (0.028, 0.030, 0.045), None),               # indigo
                     ("_b", (0.030, 0.030, 0.033), "carry_pole"),       # black, the don ganh
                     ("_c", (0.070, 0.035, 0.032), "rice_bundle")],     # faded maroon
    "civ_elder":    [("",   (0.340, 0.310, 0.240), None),               # cream
                     ("_b", (0.150, 0.140, 0.120), "rice_basket_back")],  # grey
    "civ_kid":      [("",   (0.100, 0.130, 0.170), None),               # faded blue
                     ("_b", (0.170, 0.140, 0.090), "rice_bundle")],     # dirty tan
}

UNITS = {}
for _t, _spec in _TYPES.items():
    for _sfx, _cloth, _prop in _VARIANTS[_t]:
        UNITS[_t + _sfx] = dict(_spec, cloth=_cloth, prop=_prop)

UNITS["us_pilot_white"] = dict(bare=BARE_BOOTED, face=1, hat="flight", prop=None,
                               cloth=(0.075, 0.080, 0.045), skin=(0.55, 0.33, 0.22),
                               head=1.00, shoulders=1.00, girth=1.00)
UNITS["us_pilot_black"] = dict(bare=BARE_BOOTED, face=4, hat="flight", prop=None,
                               cloth=(0.075, 0.080, 0.045), skin=(0.10, 0.055, 0.032),
                               head=1.00, shoulders=1.00, girth=1.00)


# CALEB'S EYE. He hand-placed the hats THREE times and was right three times, so
# these numbers are his. Measured off his review file each time and folded back in -
# a correction that only lives in a review scene is a correction you make again next
# week.
#   pass 1: forward 1.7cm, down 6.0cm
#   pass 2: forward 1.3cm, down 5.1cm more
#   pass 3: forward 5.0cm more, and a per-TYPE vertical trim (below)
# A non la is worn LOW and FORWARD. It is a sunshade, not a cap - it wants to sit
# down over the brow and out over the eyes. My instinct kept perching it on the
# crown and pulling it back; his eye kept dragging it down and forward. His pass 3
# forward nudge was IDENTICAL on all eight units, which is what a systematic error
# looks like - mine.
HAT_NUDGE = Vector((0.0, -0.0795, -0.111))

# ...and the vertical was NOT uniform: he trimmed each type differently. That is
# taste, not a bug, so it lives per-type.
HAT_DZ = {
    "civ_elder":    +0.006,
    "civ_farmer_f": -0.030,
    "civ_farmer_m": -0.010,
}


def _srgb(c):
    """Linear -> sRGB. Blender reads an sRGB image's pixels as ALREADY encoded, so
    writing linear values straight in gets them decoded a second time and the whole
    unit renders near-black. This bit us on the jungle; do not lose it again."""
    c = max(0.0, min(1.0, c))
    return 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1.0 / 2.4)) - 0.055


def _valnoise(rnd, S, G):
    """Bilinear value noise, G cells across S pixels. Cheap, and it tiles nowhere
    near well enough to matter at PSX range."""
    grid = [[rnd.uniform(-1.0, 1.0) for _ in range(G + 1)] for _ in range(G + 1)]
    out = [0.0] * (S * S)
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
            out[y * S + x] = a * (1 - ty) + b * ty
    return out


def fabric(name, rgb, seed):
    """HAND-LOOMED COTTON, generated. The grunt's body samples a PHOTO of OD-green
    fabric - that is why he reads as cloth and why a flat colour reads as plastic.

    A flat weave of even threads reads as CG, so this is built the way the real
    cloth is wrong:
      * PLAIN WEAVE - warp over weft, alternating, 2px, so the surface has a grain
        with a direction instead of uniform noise
      * SLUB - the threads are hand-spun, so they vary in thickness along their
        length. Slub is the single thing that separates homespun from nylon.
      * UNEVEN DYE - indigo dipped by hand blotches at two scales, and sun-bleaches
      * FADE - a slow drift, because no garment out here is one colour

    Full-bleed, so wherever the body's UVs land they land on cloth. There is NO real
    UV unwrap on this body (it samples arbitrary patches of a photo sheet), which is
    exactly why grime cannot be painted at the knees - that is what the vertex-colour
    grime pass is for."""
    import random
    rnd = random.Random(seed)
    S = 512
    dye_lo = _valnoise(rnd, S, 6)      # big blotches: the dye vat
    dye_hi = _valnoise(rnd, S, 28)     # small mottling
    slub_w = _valnoise(rnd, S, 90)     # thread thickness along the warp
    slub_f = _valnoise(rnd, S, 90)     # ... and the weft
    px = [0.0] * (S * S * 4)
    for y in range(S):
        for x in range(S):
            i = y * S + x
            # plain weave: which thread is on top at this crossing
            over = ((x // 2) + (y // 2)) % 2 == 0
            warp = 1.0 + slub_w[i] * 0.22          # hand-spun: uneven thickness
            weft = 1.0 + slub_f[i] * 0.22
            thread = warp if over else weft
            shade = 1.0 + (0.055 if over else -0.055) * thread
            # the gap between threads is darker than the threads themselves
            if (x % 2 == 0) and (y % 2 == 0):
                shade *= 0.90
            v = shade
            v *= 1.0 + dye_lo[i] * 0.17 + dye_hi[i] * 0.07
            v *= 1.0 + rnd.uniform(-1.0, 1.0) * 0.025
            j = i * 4
            px[j]     = _srgb(rgb[0] * v)
            px[j + 1] = _srgb(rgb[1] * v)
            px[j + 2] = _srgb(rgb[2] * v)
            px[j + 3] = 1.0
    img = bpy.data.images.new(name, S, S, alpha=False)
    img.pixels.foreach_set(px)
    img.pack()
    return img


def grime(body, rig):
    """Wear and mud, baked into VERTEX COLOURS.

    This body has no usable UV unwrap - it samples patches of a photo sheet - so
    grime cannot be painted onto the knees or the hem in the texture. But glTF's
    COLOR_0 multiplies albedo, and Godot honours that, so vertex colour IS a second
    albedo channel we already own. (Blender's own preview lies about this. Godot is
    the one that is right - we learned that the hard way on the jungle.)

    Three layers, multiplied:
      * CAVITY - creases and folds darken, so the shirt stops looking shrink-wrapped
      * PADDY MUD - dark at the ankle, fading out by the knee. A man who works in
        water is filthy from the shins down and nowhere else.
      * SUN - the shoulders and the top of the hat are bleached lighter

    The FACE is forced to white: COLOR_0 hits every material on the mesh, and a man
    with a shadow baked into his cheekbones looks embalmed."""
    me = body.data
    if not me.color_attributes:
        me.color_attributes.new(name="Col", type='BYTE_COLOR', domain='CORNER')
    col = me.color_attributes[0]

    mats = [s.material.name if s.material else "" for s in body.material_slots]
    face_slots = {i for i, m in enumerate(mats) if m.startswith("face_atlas")}

    ws = [body.matrix_world @ v.co for v in me.vertices]
    zmin = min(w.z for w in ws)
    zmax = max(w.z for w in ws)

    # crude cavity: a vert surrounded by neighbours that lean away from it sits in
    # a crease. Cheap, and at PSX vertex density it is all the fold shading we need.
    nbr = {i: set() for i in range(len(me.vertices))}
    for e in me.edges:
        a, b = e.vertices
        nbr[a].add(b)
        nbr[b].add(a)
    cav = [1.0] * len(me.vertices)
    for i, v in enumerate(me.vertices):
        if not nbr[i]:
            continue
        n = Vector(v.normal)
        acc = 0.0
        for j in nbr[i]:
            d = (me.vertices[j].co - v.co)
            if d.length > 1e-6:
                acc += n.dot(d.normalized())
        acc /= len(nbr[i])
        cav[i] = 1.0 + max(-0.5, min(0.0, acc)) * 0.55     # concave -> darker

    for p in me.polygons:
        white = p.material_index in face_slots
        for li in p.loop_indices:
            vi = me.loops[li].vertex_index
            if white:
                col.data[li].color = (1.0, 1.0, 1.0, 1.0)
                continue
            z = ws[vi].z
            t = (z - zmin) / max(1e-6, zmax - zmin)
            mud = 1.0 - 0.42 * max(0.0, 1.0 - t / 0.24) ** 1.5     # shin-deep
            sun = 1.0 + 0.10 * max(0.0, (t - 0.72) / 0.28)         # bleached top
            v = max(0.25, min(1.25, cav[vi] * mud * sun))
            col.data[li].color = (v, v, v, 1.0)
    me.update()
    return len(col.data)


def skin_tex(name, rgb, seed):
    """Skin, mottled. Same reasoning as the cloth: a flat fill is plastic. Sun on the
    forearms, a little unevenness, nothing clever."""
    import random
    rnd = random.Random(seed)
    S = 128
    lo = _valnoise(rnd, S, 5)
    hi = _valnoise(rnd, S, 20)
    px = [0.0] * (S * S * 4)
    for i in range(S * S):
        v = 1.0 + lo[i] * 0.10 + hi[i] * 0.045 + rnd.uniform(-1.0, 1.0) * 0.02
        j = i * 4
        px[j]     = _srgb(rgb[0] * v)
        px[j + 1] = _srgb(rgb[1] * v)
        px[j + 2] = _srgb(rgb[2] * v)
        px[j + 3] = 1.0
    img = bpy.data.images.new(name, S, S, alpha=False)
    img.pixels.foreach_set(px)
    img.pack()
    return img


def textured_mat(name, img, rgb):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = 'Closest'
    nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.92
    if "Specular IOR Level" in b.inputs:
        b.inputs["Specular IOR Level"].default_value = 0.0
    m.diffuse_color = (rgb[0], rgb[1], rgb[2], 1.0)
    return m


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
    m.diffuse_color = (rgb[0], rgb[1], rgb[2], 1.0)   # so previews stop lying
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


LOCKER = r"C:\Users\caleb\RECONgame\art_source\characters\locker\gear_library.blend"


def give_prop(rig, name):
    """Hang a tool off the locker onto this man.

    The locker's pieces are authored in WORLD/REST space and sit at IDENTITY, so
    once appended they only need re-hanging on THIS rig's bone. Same contract as
    everything else worn: rigid, unskinned, gear-named -> it moves with him and
    contributes no hitbox. Shoot the sickle, hit nothing."""
    if not name:
        return None
    before = set(bpy.data.objects)
    with bpy.data.libraries.load(LOCKER, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n == name]
    for o in dst.objects:
        if o is not None:
            bpy.context.scene.collection.objects.link(o)
    new = [o for o in bpy.data.objects if o not in before and o.type == 'MESH']
    if not new:
        print("      (locker has no %s - skipped)" % name)
        return None
    ob = new[0]
    ob.parent = rig
    ob.parent_type = 'BONE'
    ob.parent_bone = PROP_BONE[name]
    ob.matrix_parent_inverse = Matrix.Identity(4)
    bpy.context.view_layer.update()
    ob.matrix_world = Matrix.Identity(4)
    bpy.context.view_layer.update()
    return ob


def bone_head(rig, name):
    return rig.matrix_world @ rig.pose.bones[name].head


def tailor(rig):
    """Turn the GRUNT's body into PEASANT CLOTHES.

    Everything below this line was the real complaint: a farmer in a recoloured
    fatigue silhouette is still a soldier. Ba-ba pyjamas are LOOSE - baggy trousers,
    a wide untucked shirt, no military collar - and no texture work fixes a shape.

    Each limb is puffed about ITS OWN axis, not the body centre. Scale both legs
    about the pelvis and you do not get baggy trousers, you get a wider stance."""
    L, R = "mixamorig:Left", "mixamorig:Right"

    # baggy trousers: widen each leg about its own vertical axis
    for s in (L, R):
        scale_region((s + "UpLeg", s + "Leg"), 1.16,
                     bone_head(rig, s + "UpLeg"), axes=(0, 1))
    # loose sleeves: the arms run along X in rest, so puff Y and Z
    for s in (L, R):
        scale_region((s + "Arm", s + "ForeArm"), 1.15,
                     bone_head(rig, s + "Arm"), axes=(1, 2))
    # a wide shirt, not a tunic-fit tunic
    scale_region(("Spine", "Spine1", "Spine2"), 1.09,
                 bone_head(rig, "mixamorig:Spine"), axes=(0, 1))
    # kill the military collar: the grunt's fatigue collar stands up around the
    # neck. A peasant shirt has none - pull it in against the throat.
    scale_region(("Neck",), 0.80, bone_head(rig, "mixamorig:Neck"), axes=(0, 1))
    # BARE FEET, not boots painted skin-colour: crush the sole and narrow the last
    for s in (L, R):
        scale_region((s + "Foot", s + "ToeBase"), 0.72,
                     bone_head(rig, s + "Foot"), axes=(2,))
        scale_region((s + "Foot", s + "ToeBase"), 0.86,
                     bone_head(rig, s + "Foot"), axes=(0,))


def shirt_hem(body, drop=0.13, flare=1.22):
    """Hang the shirt OVER the trousers.

    The torso is its own island and its bottom rim is an OPEN boundary loop, tucked
    up inside the tops of the legs where nobody ever saw it. That rim is exactly a
    waist, so extrude it: down, and outward. The result is an untucked shirt with a
    hem - the single silhouette cue that separates a peasant from a soldier at
    fifty metres.

    New verts inherit the weights of the rim vert they came from, so the hem swings
    with the hips instead of hanging in space."""
    me = body.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    dvert = bm.verts.layers.deform.verify()
    uvlay = bm.loops.layers.uv.active

    # every boundary loop, then keep the one that is a WAIST: low on the torso,
    # wide, and owned by the spine/hips.
    spine_gi = {g.index for g in body.vertex_groups
                if any(b in g.name for b in ("Spine", "Hips"))}
    bnd = [e for e in bm.edges if len(e.link_faces) == 1]
    seen, loops = set(), []
    for e in bnd:
        if e in seen:
            continue
        stack, loop = [e], []
        while stack:
            c = stack.pop()
            if c in seen:
                continue
            seen.add(c)
            loop.append(c)
            for v in c.verts:
                for ne in v.link_edges:
                    if ne not in seen and len(ne.link_faces) == 1:
                        stack.append(ne)
        loops.append(loop)

    # There are TWO rims at the waist: the bottom of the TORSO tube and the top of
    # the LEGS, tucked inside each other. Do not tell them apart by vertex weight -
    # the waist verts belong to the legs on both. Tell them apart by WHERE THE
    # GEOMETRY IS: the torso's rim has the torso above it; the legs' rim has the
    # legs below it. We want the one with body above - that is the hem line.
    best, best_score = None, -1.0
    for lp in loops:
        vs = {v for e in lp for v in e.verts}
        if len(vs) < 6:
            continue
        ws = [body.matrix_world @ v.co for v in vs]
        z = sum(w.z for w in ws) / len(ws)
        if not (0.80 < z < 1.05):                  # waist height, not a wrist
            continue
        faces = {f for e in lp for f in e.link_faces}
        fz = sum((body.matrix_world @ f.calc_center_median()).z for f in faces) / len(faces)
        if fz < z:                                 # geometry hangs BELOW -> leg top
            continue
        rad = max((w - Vector((0, 0, w.z))).length for w in ws)
        if rad > best_score:
            best, best_score = lp, rad
    if best is None:
        print("      (no waist loop found - shirt hem skipped)")
        bm.free()
        return 0

    # walk the loop into an ordered ring
    ring, vset = [], {v for e in best for v in e.verts}
    start = next(iter(vset))
    prev, cur = None, start
    while True:
        ring.append(cur)
        nxt = None
        for e in cur.link_edges:
            if len(e.link_faces) != 1:
                continue
            o = e.other_vert(cur)
            if o in vset and o is not prev:
                nxt = o
                break
        if nxt is None or nxt is start:
            break
        prev, cur = cur, nxt
    if len(ring) < 6:
        bm.free()
        return 0

    inv = body.matrix_world.inverted()
    ws = [body.matrix_world @ v.co for v in ring]
    cx = sum(w.x for w in ws) / len(ws)
    cy = sum(w.y for w in ws) / len(ws)

    new = []
    for v, w in zip(ring, ws):
        p = Vector((cx + (w.x - cx) * flare,
                    cy + (w.y - cy) * flare,
                    w.z - drop))
        nv = bm.verts.new(inv @ p)
        nv[dvert].clear()
        for g, wt in v[dvert].items():          # the hem swings with the hips
            nv[dvert][g] = wt
        new.append(nv)
    bm.verts.ensure_lookup_table()

    made = 0
    hem_faces = []
    for i in range(len(ring)):
        j = (i + 1) % len(ring)
        try:
            f = bm.faces.new((ring[i], ring[j], new[j], new[i]))
        except ValueError:
            continue
        f.material_index = 0                    # the cloth slot
        if uvlay is not None:
            for lo in f.loops:
                lo[uvlay].uv = (0.5, 0.5)       # full-bleed fabric: any UV is cloth
        f.smooth = True            # bmesh spells it `smooth`, not `use_smooth`.
                                   # The body is smooth-shaded, and a FLAT hem lights
                                   # up like a lampshade - which is exactly what the
                                   # "light grey skirt" in the render was.
        hem_faces.append(f)
        made += 1
    # The ring is walked in whatever order the boundary happened to connect, so half
    # the time the new quads are wound backwards and the OUTSIDE of the shirt renders
    # as a backface. Let bmesh settle it against the rest of the mesh.
    bmesh.ops.recalc_face_normals(bm, faces=hem_faces)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    me.update()
    return made


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


def add_hat(kind, rig, dz=0.0):
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
        brim_z = centre.z + 0.020 + HAT_NUDGE.z + dz
        apex_z = crown + 0.055 + HAT_NUDGE.z + dz
        depth = apex_z - brim_z
        me = cone("hat_conical_worn", 0.014, 0.215, depth, seg=14)
        m = flat_mat("hat_straw", (0.30, 0.22, 0.09))
        me.materials.append(m)
        ob = bpy.data.objects.new("hat_conical_worn", me)
        # a few degrees of forward tilt - nothing on a working man sits square
        w = (Matrix.Translation(Vector((centre.x,
                                        centre.y + HAT_NUDGE.y,
                                        (brim_z + apex_z) * 0.5)))
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
    skin = textured_mat(unit + "_skin",
                        skin_tex(unit + "_skin_tex", spec["skin"],
                                 seed=abs(hash(unit + "skin")) % 9973),
                        spec["skin"])
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

    # 4b. TAILORING. A recoloured fatigue silhouette is still a soldier - the
    # clothes have to be a different SHAPE. Peasants only: aircrew wear a fitted
    # flight suit and boots, which is what the grunt's body already is.
    hem = 0
    if spec["bare"] is BARE_PEASANT:
        tailor(rig)
        hem = shirt_hem(bpy.data.objects[BODY])
        print("      tailored: baggy trousers, loose sleeves, no collar, bare feet"
              " | shirt hem %d faces" % hem)
    # cavity shading + paddy mud + sun-bleach, baked into COLOR_0
    grime(bpy.data.objects[BODY], rig)

    # 5. headgear + the job in his hands
    base_type = unit.rsplit("_b", 1)[0].rsplit("_c", 1)[0]
    hat = add_hat(spec["hat"], rig, HAT_DZ.get(base_type, 0.0)) if spec["hat"] else None
    prop = give_prop(rig, spec.get("prop"))
    if prop is not None:
        print("      prop: %s on %s" % (prop.name, spec["prop"]))

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
