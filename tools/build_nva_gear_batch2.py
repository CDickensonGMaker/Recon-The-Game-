"""NVA/VC gear library BATCH 2 - fills the two declared gaps plus a new
CHEST-worn gear category, on top of the batch-1 headgear/pack library.

Works ONLY on assets/nva_vc/props/nva_vc_gear_variants.blend. Never touches
assets/nva_vc/characters/nva_vc_soldiers.blend - a live Blender window has
that file open and this script must not go near it.

SOCKET CONVENTION (matches batch 1, verified by round-trip in this session):
every prop mesh here is authored with its vertices baked directly into a
bone's LOCAL space via world_vert -> (rig.matrix_world @ pose_bone.matrix)
.inverted() @ world_vert. That makes the Godot-side socket an IDENTITY
BoneAttachment3D, exactly like socket_headgear/socket_pack in the manifest.
Verified before building: forward-transforming the EXISTING pack_worn_
ruck_light and pith_worn vertices through this same matrix lands them in
plausible world positions (pack on the back at Y=0.06-0.26 vs a measured
back surface of Y=0.10; helmet at Z=1.67-1.76 above the measured head
position Z=1.54) - so this build reuses that exact convention rather than
re-deriving it.

Adds:
  headgear/pith_net.glb        - THE PITH_NET GAP, closed. NVA pith helmets
                                  wore a camouflage SCRIM (net + oilcloth
                                  strips), never a modelled cord net - see
                                  reference note below. Built as a low-poly
                                  offset shell over the existing pith_worn
                                  dome, textured with an alpha net pattern,
                                  plus a handful of loose scrim strip tabs
                                  for silhouette break-up.
  packs/pack_rice_tube.glb     - THE RICE TUBE GAP, closed. The VC/NVA
                                  cooked-rice sock ("elephant gut"), worn
                                  bandolier style, one continuous loop over
                                  the right shoulder and down the back,
                                  0.127 m diameter (5in, per reference),
                                  built as a tapered, pinched tube with a
                                  tied-off coil at the hip.
  NEW socket_chest (mixamorig:Spine2) + chest/chest_rig_ak.glb,
  chest/chest_rig_worn.glb (texture variant), chest/bandolier_ammo.glb -
  none of these existed in any form; audited against nva_vc_gear.json and
  built from reference (see report).

Reference used (verified 2026-08-07, session WebSearch/WebFetch - see the
build report for full citations):
  - IMA-USA / enemymilitaria.com listings: NVA pith helmets covered in
    "green oilcloth net and scrim", homemade wartime variety - a SHELL,
    not a knotted net.
  - enemymilitaria.com rice tube listings: ~5.5 ft (1.68 m) long, ~5 in
    (0.127 m) diameter cotton tube, issued per soldier heading south,
    carried dried rice.
  - mooremilitaria.com / AWM C153520 / phillosoph.blogspot.com: VC/NVA
    AK-47 chest rig - 3 large central pouches (2 mags each) flanked by a
    small pouch each side, canvas backing, crossed shoulder straps.
  - vietnam-surplus.com / cartridgecollectors.org: NVA 9-10 pocket cotton
    cartridge bandolier, worn across the chest on a neck strap.

    blender -b --factory-startup -P tools/build_nva_gear_batch2.py
"""
import bpy, bmesh, math, os, json
from mathutils import Vector, Matrix

PROPS_DIR = r"C:\Users\caleb\RECONgame\assets\nva_vc\props"
BLEND = os.path.join(PROPS_DIR, "nva_vc_gear_variants.blend")
MANIFEST = os.path.join(PROPS_DIR, "nva_vc_gear.json")


# --------------------------------------------------------------- world-space primitives
def tube(p0, p1, r0, r1, sides=8, cap=True):
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    if d.length < 1e-7:
        return [], []
    z = d.normalized()
    up = Vector((0, 0, 1)) if abs(z.z) < 0.9 else Vector((1, 0, 0))
    x = z.cross(up).normalized()
    y = z.cross(x).normalized()
    v, f = [], []
    for i in range(sides):
        a = math.tau * i / sides
        v.append(p0 + x * (r0 * math.cos(a)) + y * (r0 * math.sin(a)))
    for i in range(sides):
        a = math.tau * i / sides
        v.append(p1 + x * (r1 * math.cos(a)) + y * (r1 * math.sin(a)))
    for i in range(sides):
        j = (i + 1) % sides
        f.append([i, j, sides + j, sides + i])
    if cap:
        f.append(list(range(sides))[::-1])
        f.append([sides + i for i in range(sides)])
    return v, f


def box(c, s):
    cx, cy, cz = c
    sx, sy, sz = s
    v = [Vector((cx - sx, cy - sy, cz - sz)), Vector((cx + sx, cy - sy, cz - sz)),
         Vector((cx + sx, cy + sy, cz - sz)), Vector((cx - sx, cy + sy, cz - sz)),
         Vector((cx - sx, cy - sy, cz + sz)), Vector((cx + sx, cy - sy, cz + sz)),
         Vector((cx + sx, cy + sy, cz + sz)), Vector((cx - sx, cy + sy, cz + sz))]
    f = [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
    return v, f


def quad(p00, p10, p11, p01):
    return [Vector(p00), Vector(p10), Vector(p11), Vector(p01)], [[0, 1, 2, 3]]


class Builder:
    """Collects world-space verts/faces, then bakes into a bone's local space."""

    def __init__(self):
        self.v, self.f = [], []

    def add(self, verts, faces):
        b = len(self.v)
        self.v += verts
        for face in faces:
            self.f.append([b + i for i in face])

    def bake(self, name, bone_wm):
        inv = bone_wm.inverted()
        local = [inv @ v for v in self.v]
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(v) for v in local], [], self.f)
        me.update()
        for p in me.polygons:
            p.use_smooth = False
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def make_uv(ob):
    uv = ob.data.uv_layers.new(name="UVMap")
    for poly in ob.data.polygons:
        for li in poly.loop_indices:
            co = ob.data.vertices[ob.data.loops[li].vertex_index].co
            uv.data[li].uv = (co.x * 2.0 % 1.0, co.z * 2.0 % 1.0)


def tris(faces):
    return sum(max(0, len(f) - 2) for f in faces)


BATCH2_OBJECTS = [
    "pith_net", "pith_net_band", "pith_net_scrim", "pith_net_tabs",
    "pack_rice_tube", "chest_rig_ak", "chest_rig_worn", "bandolier_ammo",
]
BATCH2_MESHES = [n + "_mesh" for n in BATCH2_OBJECTS] + BATCH2_OBJECTS
BATCH2_IMAGES = ["pith_net_scrim"]
BATCH2_MATERIALS = ["pith_net_scrim"]


def purge_prior_batch2():
    """Re-runnable from the file batch 1 left behind: delete anything a prior
    run of THIS script added, before adding it again. Without this, a second
    run silently renames every new object to `.001` and the stale originals
    (and their now-orphaned GLBs) go on lying about the library's contents."""
    for name in BATCH2_OBJECTS:
        ob = bpy.data.objects.get(name)
        if ob:
            bpy.data.objects.remove(ob, do_unlink=True)
    for name in BATCH2_IMAGES:
        img = bpy.data.images.get(name)
        if img:
            bpy.data.images.remove(img)
    for name in BATCH2_MATERIALS:
        mat = bpy.data.materials.get(name)
        if mat:
            bpy.data.materials.remove(mat)
    # sweep any now-unused mesh/material/image data the object removals left
    # behind (new_from_object() names the mesh after its SOURCE, not the new
    # object, so a name-keyed purge above cannot catch it).
    for _ in range(2):
        bpy.data.orphans_purge(do_local_ids=True, do_recursive=True)


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    purge_prior_batch2()
    rig = bpy.data.objects["PSXRig"]
    head_wm = rig.matrix_world @ rig.pose.bones["mixamorig:Head"].matrix
    spine1_wm = rig.matrix_world @ rig.pose.bones["mixamorig:Spine1"].matrix
    spine2_wm = rig.matrix_world @ rig.pose.bones["mixamorig:Spine2"].matrix

    pack_canvas = bpy.data.materials["pack_canvas"]
    webbing_canvas = bpy.data.materials["webbing_canvas"]
    new_objs = {}   # name -> (object, category, socket_bone_name)

    # =====================================================================
    # 1. pith_net - camo scrim shell over the existing pith_worn dome
    # =====================================================================
    # Net/scrim material: alpha-cut diamond lattice over dark oilcloth green.
    net_img = bpy.data.images.new("pith_net_scrim", 256, 256, alpha=True)
    px = [0.0] * (256 * 256 * 4)
    for y in range(256):
        for x in range(256):
            i = (y * 256 + x) * 4
            # diamond lattice: distance to nearest lattice line, in a rotated grid
            u = (x - y) % 24
            w = (x + y) % 24
            on_line = min(u, 24 - u) < 3 or min(w, 24 - w) < 3
            if on_line:
                px[i:i + 4] = [0.06, 0.085, 0.045, 1.0]   # dark oilcloth green
            else:
                px[i:i + 4] = [0.0, 0.0, 0.0, 0.0]         # gap - see the helmet through
    net_img.pixels = px
    net_img.pack()
    net_mat = bpy.data.materials.new("pith_net_scrim")
    net_mat.use_nodes = True
    net_mat.blend_method = 'HASHED' if hasattr(net_mat, 'blend_method') else net_mat.blend_method
    bsdf = next(n for n in net_mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    tex = net_mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image = net_img
    tex.interpolation = 'Closest'
    net_mat.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    net_mat.node_tree.links.new(tex.outputs['Alpha'], bsdf.inputs['Alpha'])
    bsdf.inputs['Roughness'].default_value = 1.0
    try:
        net_mat.surface_render_method = 'DITHERED'
    except AttributeError:
        pass

    pith_worn = bpy.data.objects["pith_worn"]
    pith_worn_band = bpy.data.objects["pith_worn_band"]

    # Base dome + band: duplicate pith_worn's geometry verbatim (already
    # correctly fitted in this exact local frame - no matrix work needed).
    b_dome = bpy.data.meshes.new_from_object(pith_worn)
    dome_ob = bpy.data.objects.new("pith_net", b_dome)
    bpy.context.scene.collection.objects.link(dome_ob)
    dome_ob.data.materials.append(bpy.data.materials["pith_worn_cover"])

    b_band = bpy.data.meshes.new_from_object(pith_worn_band)
    band_ob = bpy.data.objects.new("pith_net_band", b_band)
    bpy.context.scene.collection.objects.link(band_ob)
    band_ob.data.materials.append(bpy.data.materials["pith_worn_cover"])

    # Scrim shell: offset the dome outward along its own vertex normals by
    # ~6mm (a draped net sits proud of the shell, it does not hug it) and
    # drop every other ring to keep it cheap - reads as netting at PSX range
    # far better than a dense duplicate would, and it is a third the tris.
    dome_src = pith_worn.data
    scrim_v, scrim_f = [], []
    idx_map = {}
    for i, v in enumerate(dome_src.vertices):
        idx_map[i] = len(scrim_v)
        scrim_v.append(v.co + v.normal * 0.006)
    for poly in dome_src.polygons:
        scrim_f.append([idx_map[i] for i in poly.vertices])
    scrim_me = bpy.data.meshes.new("pith_net_shell_mesh")
    scrim_me.from_pydata([tuple(v) for v in scrim_v], [], scrim_f)
    scrim_me.update()
    scrim_ob = bpy.data.objects.new("pith_net_scrim", scrim_me)
    bpy.context.scene.collection.objects.link(scrim_ob)
    scrim_ob.data.materials.append(net_mat)
    for p in scrim_ob.data.polygons:
        p.use_smooth = False
    make_uv(scrim_ob)

    # A handful of loose scrim tabs at the rim - the "cloth petals" reference
    # describes for silhouette break-up. Cheap: 6 tabs, 2 tris each.
    tabs_b = Builder()
    band_src = pith_worn_band.data
    import random
    rnd = random.Random(7)
    rim_verts = [v.co for v in band_src.vertices]
    for k in range(6):
        base = rim_verts[rnd.randrange(len(rim_verts))]
        out = Vector((base.x, base.y, base.z))
        drop = out + Vector((0, 0, -0.028 - rnd.random() * 0.02))
        w = 0.014
        tv, tf = quad(
            (out.x - w, out.y, out.z), (out.x + w, out.y, out.z),
            (drop.x + w * 0.4, drop.y, drop.z), (drop.x - w * 0.4, drop.y, drop.z))
        tabs_b.add(tv, tf)
    tabs_me = bpy.data.meshes.new("pith_net_tabs_mesh")
    tabs_me.from_pydata([tuple(v) for v in tabs_b.v], [], tabs_b.f)
    tabs_me.update()
    tabs_ob = bpy.data.objects.new("pith_net_tabs", tabs_me)
    bpy.context.scene.collection.objects.link(tabs_ob)
    tabs_ob.data.materials.append(net_mat)
    for p in tabs_ob.data.polygons:
        p.use_smooth = False
    make_uv(tabs_ob)

    net_parts = [dome_ob, band_ob, scrim_ob, tabs_ob]
    new_objs["pith_net"] = (net_parts, "headgear", "mixamorig:Head")

    # =====================================================================
    # 2. pack_rice_tube - cooked-rice sock, one loop over the right shoulder
    # =====================================================================
    # 0.127 m diameter (5in reference), ~1.5 m of visible run once looped
    # over the shoulder (full 1.68 m body length minus the tied-off coil).
    R = 0.0635
    path = [
        (0.135, -0.020, 1.010),   # tucked end, front, near left hip - clear of the hip bulge
        (0.070, -0.085, 1.06),
        (0.010, -0.100, 1.16),
        (-0.035, -0.085, 1.26),
        (-0.095, -0.025, 1.375),  # crossing the front toward right shoulder
        (-0.105, 0.005, 1.445),   # over the top of the right shoulder - clear of the joint
        (-0.095, 0.085, 1.375),   # starts down the back
        (-0.025, 0.100, 1.26),
        (0.020, 0.110, 1.16),
        (0.075, 0.100, 1.06),
        (0.130, 0.100, 1.010),    # back end, meets the coil clear of the hip
    ]
    rice_b = Builder()
    n = len(path)
    for i in range(n - 1):
        t0, t1 = i / (n - 1), (i + 1) / (n - 1)
        # taper to a tied point at both ends; pinch every other segment for
        # the "sausage link" ties visible in every reference photo.
        r0 = R * (0.35 + 0.65 * min(1.0, t0 * 6)) * (1.0 if i % 2 == 0 else 0.72)
        r1 = R * (0.35 + 0.65 * min(1.0, (1 - t1) * 6 if t1 > 0.85 else 1.0)) * (0.72 if i % 2 == 0 else 1.0)
        v, f = tube(path[i], path[i + 1], r0, r1, sides=8, cap=(i == 0 or i == n - 2))
        rice_b.add(v, f)
    # tied-off coil at the hip - two small loops of excess tube
    coil_c = Vector((0.150, 0.080, 1.010))
    for k in range(2):
        a0 = k * math.pi
        p_a = coil_c + Vector((0.045 * math.cos(a0), 0.045 * math.sin(a0) * 0.4, 0))
        p_b = coil_c + Vector((0.045 * math.cos(a0 + math.pi), 0.045 * math.sin(a0 + math.pi) * 0.4, -0.01))
        v, f = tube(p_a, p_b, R * 0.55, R * 0.5, sides=6, cap=False)
        rice_b.add(v, f)
    rice_ob = rice_b.bake("pack_rice_tube", spine1_wm)
    rice_ob.data.materials.append(webbing_canvas)
    for p in rice_ob.data.polygons:
        p.use_smooth = False
    make_uv(rice_ob)
    new_objs["pack_rice_tube"] = ([rice_ob], "packs", "mixamorig:Spine1")

    # =====================================================================
    # 3. NEW socket_chest (mixamorig:Spine2) + chest rig / bandolier
    # =====================================================================
    def build_chest_rig(name, mat):
        b = Builder()
        # canvas backing panel
        v, f = box((0.0, -0.085, 1.298), (0.105, 0.008, 0.082), )
        b.add(v, f)
        # 3 large central pouches (2 AK mags each) + 2 small end pouches
        for x, big in ((-0.065, True), (0.0, True), (0.065, True),
                       (-0.115, False), (0.115, False)):
            hs = (0.030, 0.026, 0.044) if big else (0.022, 0.020, 0.032)
            v, f = box((x, -0.115, 1.298), hs)
            b.add(v, f)
            # toggle flap lip
            v, f = box((x, -0.140, 1.298 + hs[2] * 0.55), (hs[0] * 0.9, 0.006, 0.014))
            b.add(v, f)
        # crossed shoulder straps, up to the shoulder bones, short stub over
        # and onto the back so the rig reads from behind too
        for x, shoulder in ((-0.09, (-0.150, 0.02, 1.41)), (0.09, (0.150, 0.02, 1.41))):
            top = (x, -0.088, 1.375)
            v, f = tube(top, shoulder, 0.010, 0.010, sides=4)
            b.add(v, f)
            back = (shoulder[0] * 0.65, 0.11, 1.30)
            v, f = tube(shoulder, back, 0.010, 0.009, sides=4)
            b.add(v, f)
        ob = b.bake(name, spine2_wm)
        ob.data.materials.append(mat)
        for p in ob.data.polygons:
            p.use_smooth = False
        make_uv(ob)
        return ob

    rig_ob = build_chest_rig("chest_rig_ak", pack_canvas)
    new_objs["chest_rig_ak"] = ([rig_ob], "chest", "mixamorig:Spine2")

    # texture variant: same mesh, weathered/faded cover (reuses the existing
    # pith_worn_cover.png swatch - already a worn-look texture in this file,
    # exactly the "share topology, swap the cover PNG" trick the pith family
    # already uses for plain/faded/worn/star).
    worn_ob = build_chest_rig("chest_rig_worn", bpy.data.materials["pith_worn_cover"])
    new_objs["chest_rig_worn"] = ([worn_ob], "chest", "mixamorig:Spine2")

    # 10-pocket ammo bandolier: diagonal strip, opposite shoulder from the
    # chest rig for visual variety, neck-strap hung.
    band_b = Builder()
    p0 = Vector((0.065, -0.030, 1.415))     # left shoulder / neck strap point
    p1 = Vector((-0.085, -0.065, 0.985))    # right hip, strap end
    strap_r = 0.014
    v, f = tube(p0, p1, strap_r, strap_r, sides=6)
    band_b.add(v, f)
    for k in range(10):
        t = (k + 0.5) / 10.0
        c = p0.lerp(p1, t)
        # pouches sit proud of the strap, forward-facing
        v, f = box((c.x, c.y - 0.020, c.z), (0.020, 0.014, 0.020))
        band_b.add(v, f)
    band_ob2 = band_b.bake("bandolier_ammo", spine2_wm)
    band_ob2.data.materials.append(pack_canvas)
    for p in band_ob2.data.polygons:
        p.use_smooth = False
    make_uv(band_ob2)
    new_objs["bandolier_ammo"] = ([band_ob2], "chest", "mixamorig:Spine2")

    # =====================================================================
    # Report + export
    # =====================================================================
    report = {}
    for key, (objs, cat, bone) in new_objs.items():
        total_v = sum(len(o.data.vertices) for o in objs)
        total_t = sum(tris([p.vertices for p in o.data.polygons]) for o in objs)
        report[key] = dict(category=cat, bone=bone, verts=total_v, tris=total_t,
                            parts=[o.name for o in objs])
        print("%-18s cat=%-9s tris=%-5d verts=%-5d parts=%s"
              % (key, cat, total_t, total_v, [o.name for o in objs]))

    sub = {"headgear": "headgear", "packs": "packs", "chest": "chest"}
    for key, (objs, cat, bone) in new_objs.items():
        out_dir = os.path.join(PROPS_DIR, sub[cat])
        os.makedirs(out_dir, exist_ok=True)
        for x in bpy.data.objects:
            x.select_set(False)
        for o in objs:
            o.select_set(True)
        rig.select_set(True)
        bpy.context.view_layer.objects.active = rig
        kw = dict(filepath=os.path.join(out_dir, key + ".glb"),
                  export_format='GLB', use_selection=True, export_apply=True,
                  export_animations=False, export_skins=False, export_morph=False,
                  export_cameras=False, export_lights=False, export_yup=True)
        props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
        bpy.ops.export_scene.gltf(**{k: v for k, v in kw.items() if k in props})

    with open(os.path.join(PROPS_DIR, "_batch2_report.json"), "w") as f:
        json.dump(report, f, indent=2)

    bpy.ops.wm.save_mainfile(filepath=BLEND)
    print("saved:", BLEND)


if __name__ == "__main__":
    main()
