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
OUTDIR = r"C:\Users\caleb\RECONgame\art_source\characters\civilians"
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

# name -> spec. `cloth`/`skin` are linear-ish PSX flats; `face_tint` multiplies
# the shared face atlas so one texture serves every skin tone.
UNITS = {
    "civ_farmer_m": dict(bare=BARE_PEASANT, cloth=(0.09, 0.09, 0.10), skin=(0.72, 0.56, 0.42),
                         face_tint=(0.86, 0.78, 0.68), hat="conical",
                         head=1.0, shoulders=1.0, girth=1.0),
    "civ_farmer_f": dict(bare=BARE_PEASANT, cloth=(0.10, 0.10, 0.14), skin=(0.74, 0.58, 0.44),
                         face_tint=(0.88, 0.80, 0.70), hat="conical",
                         head=1.0, shoulders=0.90, girth=0.96),
    "civ_elder":    dict(bare=BARE_PEASANT, cloth=(0.62, 0.58, 0.48), skin=(0.70, 0.55, 0.43),
                         face_tint=(0.84, 0.78, 0.70), hat="conical",
                         head=1.0, shoulders=0.94, girth=0.90),
    "civ_kid":      dict(bare=BARE_PEASANT, cloth=(0.35, 0.42, 0.50), skin=(0.74, 0.58, 0.44),
                         face_tint=(0.88, 0.80, 0.70), hat=None,
                         head=1.30, shoulders=0.88, girth=0.94),
    "us_pilot_white": dict(bare=BARE_BOOTED, cloth=(0.30, 0.31, 0.22), skin=(0.85, 0.68, 0.57),
                           face_tint=(1.0, 1.0, 1.0), hat="flight",
                           head=1.0, shoulders=1.0, girth=1.0),
    "us_pilot_black": dict(bare=BARE_BOOTED, cloth=(0.30, 0.31, 0.22), skin=(0.36, 0.25, 0.19),
                           face_tint=(0.44, 0.38, 0.34), hat="flight",
                           head=1.0, shoulders=1.0, girth=1.0),
}


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


def face_texture_nodes():
    """Every TEX_IMAGE node that actually feeds a face material, and the image it
    is wired to. Do NOT go looking for an image *named* face_atlas: this blend
    carries several (v2 and v3), and the first one by name is not the one the
    material uses. Ask the material what it is showing."""
    nodes, img = [], None
    for m in bpy.data.materials:
        if not (m.use_nodes and m.name.startswith("face_atlas")):
            continue
        for n in m.node_tree.nodes:
            if n.type == 'TEX_IMAGE' and n.image is not None and n.image.size[0] > 0:
                nodes.append(n)
                img = n.image
    return nodes, img


def tint_face_atlas(unit, src, tint):
    """One face atlas, many skin tones: copy the image and multiply its RGB.
    A tint node between the texture and Base Color would not reliably survive
    glTF, so bake it into pixels.

    Read the pixels from the SOURCE, never from the copy. A fresh copy's pixel
    buffer reads back as all-zeros until Blender fills it, so `list(cp.pixels)`
    hands you black, and multiplying black by a tint gives you black - which is
    exactly the featureless head this comment exists to prevent."""
    if src is None or tint == (1.0, 1.0, 1.0):
        return src
    n = len(src.pixels)                      # touching .pixels forces the load
    if n == 0:
        return src
    buf = [0.0] * n
    src.pixels.foreach_get(buf)
    for i in range(0, n, 4):
        buf[i]     *= tint[0]
        buf[i + 1] *= tint[1]
        buf[i + 2] *= tint[2]
    cp = src.copy()
    cp.name = "%s_face" % unit
    cp.pixels.foreach_set(buf)
    cp.pack()
    cp.update()
    return cp


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
        # non la: a shallow straw cone, ~40cm across, brim riding just below the
        # crown. The silhouette IS the unit - at PSX range this cone is how the
        # player reads "civilian, do not shoot".
        me = cone("hat_conical_worn", 0.005, max(0.20, r * 2.1), 0.13, seg=12)
        m = flat_mat("hat_straw", (0.78, 0.68, 0.42))
        me.materials.append(m)
        ob = bpy.data.objects.new("hat_conical_worn", me)
        w = Matrix.Translation(Vector((centre.x, centre.y, crown - 0.015 + 0.065)))
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
    cloth = flat_mat(unit + "_cloth", spec["cloth"])
    repoint_slot("us_grunt_mat", cloth)
    nodes, src = face_texture_nodes()
    atlas = tint_face_atlas(unit, src, spec["face_tint"])
    if atlas is not None:
        for n in nodes:
            n.image = atlas
    print("      face atlas: %s -> %s (tint %s)"
          % (src.name if src else "NONE", atlas.name if atlas else "NONE",
             spec["face_tint"]))

    # 3. bare skin where a peasant shows it
    skin = flat_mat(unit + "_skin", spec["skin"])
    boot = flat_mat(unit + "_boot", (0.12, 0.10, 0.08))
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

    os.makedirs(OUTDIR, exist_ok=True)
    path = os.path.join(OUTDIR, unit + ".blend")
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
