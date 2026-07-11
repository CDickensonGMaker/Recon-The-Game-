"""Jungle vegetation batch: palms + vines + grass star-fan for RECONgame.

Imports the palm donor from RealVietnamRTS (READ ONLY), fixes the two known
red flags (research batch_research_jungle_ai_heli_gore.md section 2):
  1. trunks float 0.3-0.65 m above y=0  -> every export is re-grounded
  2. materials duplicated per tree (352 in jungle_heavy) -> consolidated to
     exactly two shared materials: palm_bark + palm_leaf

Then fans out PSX-budget variants:
  - 2 palm archetypes (tall / short donor) x 3 size+lean variants each
  - 2-3 curve-based liana vines merged onto a subset (4-sided tubes, 40 tris)
  - vertex-color sway weights: R = master sway mask (0 at trunk base ->
    ~0.95 at frond tips, so shader-driven wind never uproots the trunk),
    G = frond-flutter mask (fast frequency, tips only)
  - grass_fan.glb: 3 intersecting quads (6 tris), same weight scheme

Exports mesh-only GLBs to RECONgame/assets/models/vegetation/.

Headless (no window context anywhere - bpy.data/bmesh only, plus the
context-free glTF import/export operators):
  & "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" -b --factory-startup --python tools/make_jungle_vegetation.py

If the RTS donor is missing/unreadable a procedural PSX palm is built from
scratch (6-sided tapered trunk + 6 bent frond strips) instead of failing.
"""
import math
import os
import random

import bpy
import bmesh
from mathutils import Matrix, Vector

# ---------------------------------------------------------------- constants
SRC_GLB = r"C:\Users\caleb\RealVietnamRTS\assets\models\terrain\foliage\jungle_medium.glb"
OUT_DIR = r"C:\Users\caleb\RECONgame\assets\models\vegetation"
GRASS_TEX = r"C:\Users\caleb\RECONgame\terrain\textures\clutter\grassland_2.png"

CANON_HEIGHT = 6.5          # canonical palm height (m); variants scale 0.8-1.4
GROUND_SINK = 0.02          # sink base slightly below y=0 for slope forgiveness
TEX_MAX = 256               # PSX texture budget
COL_ATTR = "Col"
UV_LAYER = "UVMap"

# variant table: (suffix, archetype_idx, scale, lean_deg, n_vines)
VARIANTS = [
    ("a1", 0, 0.85, 2.5, 0),
    ("a2", 0, 1.10, 5.0, 2),
    ("a3", 0, 1.35, 3.0, 0),
    ("b1", 1, 0.80, 4.0, 3),
    ("b2", 1, 1.05, 7.0, 0),
    ("b3", 1, 1.30, 5.5, 2),
]

rng = random.Random(20260711)
report_lines = []


# ---------------------------------------------------------------- helpers
def clean_scene():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)


def find_image_of(mat):
    if mat is None or not mat.use_nodes:
        return None
    for n in mat.node_tree.nodes:
        if n.type == 'TEX_IMAGE' and n.image is not None:
            return n.image
    return None


def downscale(img, max_px=TEX_MAX):
    if img is None:
        return
    w, h = img.size
    if w <= 0 or h <= 0 or (w <= max_px and h <= max_px):
        return
    s = max_px / float(max(w, h))
    img.scale(max(1, int(w * s)), max(1, int(h * s)))


def solid_image(name, rgba, px=32):
    """Flat-colour texture. rgba is LINEAR (glTF baseColorFactor space);
    encode to sRGB so the packed PNG displays at the donor's brightness."""
    def srgb(c):
        return 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1.0 / 2.4)) - 0.055
    px_rgba = [srgb(rgba[0]), srgb(rgba[1]), srgb(rgba[2]), rgba[3]]
    img = bpy.data.images.new(name, px, px, alpha=True)
    img.pixels[:] = px_rgba * (px * px)
    img.pack()
    return img


def base_color_of(mat):
    """Linear base colour of a Principled material (glTF baseColorFactor)."""
    if mat is None or not mat.use_nodes:
        return None
    for n in mat.node_tree.nodes:
        if n.type == 'BSDF_PRINCIPLED':
            c = n.inputs['Base Color'].default_value
            return (c[0], c[1], c[2], 1.0)
    return None


def make_material(name, img, alpha_clip=False):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Roughness'].default_value = 0.95
    tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image = img
    mat.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    if alpha_clip:
        mat.node_tree.links.new(tex.outputs['Alpha'], bsdf.inputs['Alpha'])
        for attr, val in (("blend_method", 'CLIP'), ("alpha_threshold", 0.4),
                          ("surface_render_method", 'DITHERED')):
            try:
                setattr(mat, attr, val)
            except (AttributeError, TypeError):
                pass
    return mat


def new_mesh_object(name, verts, faces, mat_indices, uvs, materials, colors):
    """Build a mesh the context-free way. uvs: per-face list of per-corner
    (u,v). colors: per-vertex (r,g,b,a) sway weights."""
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    for m in materials:
        me.materials.append(m)
    for poly, mi in zip(me.polygons, mat_indices):
        poly.material_index = mi
        poly.use_smooth = True
    uv = me.uv_layers.new(name=UV_LAYER)
    li = 0
    for face_uv in uvs:
        for corner in face_uv:
            uv.data[li].uv = corner
            li += 1
    col = me.color_attributes.new(COL_ATTR, 'FLOAT_COLOR', 'POINT')
    for i, c in enumerate(colors):
        col.data[i].color = c
    me.color_attributes.active_color = col
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def paint_palm_colors(me, kinds):
    """kinds: per-vertex 'T' (trunk) or 'L' (leaf). R = master sway mask,
    black at trunk base -> ~white at frond tips. G = fast flutter mask."""
    zs = [v.co.z for v in me.vertices]
    z_top = max(zs) if zs else 1.0
    trunk_top = max((v.co.z for v, k in zip(me.vertices, kinds) if k == 'T'),
                    default=z_top * 0.7)
    radials = [math.hypot(v.co.x, v.co.y) for v in me.vertices]
    max_rad = max((r for r, k in zip(radials, kinds) if k == 'L'), default=1.0)
    max_rad = max(max_rad, 1e-4)
    col = me.color_attributes.get(COL_ATTR)
    if col is None:
        col = me.color_attributes.new(COL_ATTR, 'FLOAT_COLOR', 'POINT')
    for i, v in enumerate(me.vertices):
        if kinds[i] == 'T':
            t = max(0.0, min(1.0, v.co.z / max(trunk_top, 1e-4)))
            r, g = 0.28 * (t ** 1.5), 0.0
        else:
            rad = min(1.0, radials[i] / max_rad)
            r = min(1.0, 0.35 + 0.60 * rad)
            g = min(1.0, 0.15 + 0.75 * (rad ** 1.4))
        col.data[i].color = (r, g, 0.0, 1.0)
    me.color_attributes.active_color = col


def merge_mesh_into(dst_me, src_me):
    """Append src geometry into dst, unifying UV + color layers by name."""
    bm = bmesh.new()
    bm.from_mesh(dst_me)
    bm.from_mesh(src_me)
    bm.to_mesh(dst_me)
    bm.free()
    dst_me.update()


def gltf_export(path, objects):
    for ob in bpy.data.objects:
        try:
            ob.select_set(False)
        except RuntimeError:
            pass
    for ob in objects:
        ob.select_set(True)
    kwargs = dict(
        filepath=path, export_format='GLB', use_selection=True,
        export_apply=True, export_animations=False, export_skins=False,
        export_morph=False, export_cameras=False, export_lights=False,
        export_yup=True, export_extras=False, export_tangents=False,
        export_image_format='AUTO',
        export_vertex_color='ACTIVE',
        export_all_vertex_colors=False,
        export_active_vertex_color_when_no_material=True,
    )
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    kwargs = {k: v for k, v in kwargs.items() if k in props}
    bpy.ops.export_scene.gltf(**kwargs)


def tri_count(me):
    return sum(max(0, len(p.vertices) - 2) for p in me.polygons)


# ---------------------------------------------------- donor palm extraction
def import_donor():
    """Import the RTS palm GLB. Returns list of archetype dicts or None."""
    if not os.path.isfile(SRC_GLB):
        print("[VEG] donor missing:", SRC_GLB)
        return None
    try:
        bpy.ops.import_scene.gltf(filepath=SRC_GLB)
    except Exception as exc:  # unreadable/corrupt -> procedural fallback
        print("[VEG] donor import failed:", exc)
        return None
    src = None
    for ob in bpy.data.objects:
        if ob.type == 'MESH' and len(ob.data.materials) >= 2:
            src = ob
            break
    if src is None:
        print("[VEG] donor has no multi-material mesh")
        return None

    me = src.data
    mw = src.matrix_world
    uv_data = me.uv_layers.active.data if me.uv_layers.active else None

    # group faces by material slot = one glTF prim each (research 2a)
    slot_faces = {}
    for poly in me.polygons:
        slot_faces.setdefault(poly.material_index, []).append(poly)

    def slot_info(slot):
        polys = slot_faces[slot]
        vids = sorted({vi for p in polys for vi in p.vertices})
        cos = [mw @ me.vertices[vi].co for vi in vids]
        zs = [c.z for c in cos]
        cen = sum(cos, Vector()) / len(cos)
        return {"slot": slot, "polys": polys, "min_z": min(zs),
                "max_z": max(zs), "center": cen}

    trunks, leaves = [], []
    for slot in slot_faces:
        mat = me.materials[slot]
        name = (mat.name if mat else "").lower()
        info = slot_info(slot)
        # ground-disc insurance (research 2a): drop flat prims at the floor
        if info["max_z"] - info["min_z"] < 0.1:
            print("[VEG] skipping flat prim (disc heuristic):", name)
            continue
        if name.startswith("bark") or "trunk" in name or "willow" in name:
            trunks.append(info)
        else:
            leaves.append(info)
    if not trunks or not leaves:
        print("[VEG] could not classify trunk/leaf prims")
        return None

    # pair each crown with the nearest trunk (horizontal proximity)
    pairs = []
    for leaf in leaves:
        best = min(trunks, key=lambda t: (t["center"].xy - leaf["center"].xy).length)
        pairs.append((best, leaf))
    # archetypes: tallest and shortest donor palm (silhouette variety free)
    pairs.sort(key=lambda p: p[0]["max_z"])
    picks = [pairs[-1], pairs[0]] if len(pairs) > 1 else [pairs[0], pairs[0]]

    # consolidated shared materials (kills the per-tree duplication).
    # Donor quirk: Palm_Leaf materials carry NO texture - just a flat green
    # baseColorFactor (the crown is modeled frond geometry). Reproduce the
    # donor's exact colour as a small solid texture when that happens.
    bark_src = me.materials[picks[0][0]["slot"]]
    leaf_src = me.materials[picks[0][1]["slot"]]
    bark_img = find_image_of(bark_src)
    leaf_img = find_image_of(leaf_src)
    if bark_img is None:
        bark_img = solid_image("palm_bark_img",
                               base_color_of(bark_src) or (0.35, 0.24, 0.14, 1.0))
    if leaf_img is None:
        leaf_img = solid_image("palm_leaf_img",
                               base_color_of(leaf_src) or (0.16, 0.34, 0.12, 1.0))
    downscale(bark_img)
    downscale(leaf_img)
    bark_mat = make_material("palm_bark", bark_img)
    leaf_mat = make_material("palm_leaf", leaf_img, alpha_clip=True)

    archetypes = []
    for ai, (trunk, leaf) in enumerate(picks):
        verts, faces, mats, uvs, kinds = [], [], [], [], []
        remap = {}
        for kind, info, mi in (('T', trunk, 0), ('L', leaf, 1)):
            for poly in info["polys"]:
                face = []
                for vi in poly.vertices:
                    key = vi
                    if key not in remap:
                        remap[key] = len(verts)
                        verts.append(tuple(mw @ me.vertices[vi].co))
                        kinds.append(kind)
                    face.append(remap[key])
                faces.append(face)
                mats.append(mi)
                if uv_data is not None:
                    uvs.append([tuple(uv_data[li].uv) for li in poly.loop_indices])
                else:
                    uvs.append([(0.0, 0.0)] * len(poly.vertices))
        colors = [(0.0, 0.0, 0.0, 1.0)] * len(verts)
        ob = new_mesh_object("palm_arch_%d" % ai, verts, faces, mats, uvs,
                             [bark_mat, leaf_mat], colors)
        ground_and_normalize(ob.data, kinds)
        paint_palm_colors(ob.data, kinds)
        archetypes.append({"object": ob, "kinds": kinds,
                           "bark": bark_mat, "leaf": leaf_mat})
    bpy.data.objects.remove(src, do_unlink=True)
    return archetypes


def ground_and_normalize(me, kinds):
    """Recenter on trunk base, drop feet to z=0 (kills the 0.3-0.65 float),
    scale to canonical height."""
    trunk_z = [me.vertices[i].co.z for i, k in enumerate(kinds) if k == 'T']
    z_min = min(v.co.z for v in me.vertices)
    z_max = max(v.co.z for v in me.vertices)
    base_cut = min(trunk_z) + 0.3 if trunk_z else z_min + 0.3
    base = [me.vertices[i] for i, k in enumerate(kinds)
            if k == 'T' and me.vertices[i].co.z <= base_cut]
    if not base:
        base = list(me.vertices)
    cx = sum(v.co.x for v in base) / len(base)
    cy = sum(v.co.y for v in base) / len(base)
    height = max(z_max - z_min, 1e-3)
    s = CANON_HEIGHT / height
    me.transform(Matrix.Diagonal((s, s, s, 1.0)) @
                 Matrix.Translation((-cx, -cy, -z_min)))
    me.update()


# ---------------------------------------------------------- procedural palm
def procedural_archetypes():
    """From-scratch PSX palm: 6-sided tapered trunk + 6 bent frond strips."""
    bark_img = solid_image("palm_bark_img", (0.35, 0.24, 0.14, 1.0))
    leaf_img = solid_image("palm_leaf_img", (0.16, 0.34, 0.12, 1.0))
    bark_mat = make_material("palm_bark", bark_img)
    leaf_mat = make_material("palm_leaf", leaf_img, alpha_clip=True)
    archetypes = []
    for ai, (height, n_fronds) in enumerate(((6.5, 6), (4.5, 7))):
        verts, faces, mats, uvs, kinds = [], [], [], [], []
        # trunk: 5 rings of 6 verts, tapered, slight bend
        rings = 5
        for ri in range(rings + 1):
            t = ri / float(rings)
            z = height * 0.72 * t
            rad = 0.22 * (1.0 - 0.55 * t)
            bend = 0.35 * (t ** 2)
            for si in range(6):
                a = si / 6.0 * math.tau
                verts.append((math.cos(a) * rad + bend, math.sin(a) * rad, z))
                kinds.append('T')
        for ri in range(rings):
            for si in range(6):
                a0 = ri * 6 + si
                b0 = ri * 6 + (si + 1) % 6
                a1, b1 = a0 + 6, b0 + 6
                faces.append([a0, b0, b1, a1])
                mats.append(0)
                u0, u1 = si / 6.0, (si + 1) / 6.0
                v0, v1 = ri / float(rings), (ri + 1) / float(rings)
                uvs.append([(u0, v0), (u1, v0), (u1, v1), (u0, v1)])
        # fronds: bent strips of 3 quads radiating from crown
        crown = Vector((0.35, 0.0, height * 0.72))
        f_len = height * 0.42
        for fi in range(n_fronds):
            a = fi / float(n_fronds) * math.tau
            d = Vector((math.cos(a), math.sin(a), 0.0))
            side = Vector((-d.y, d.x, 0.0)) * 0.28
            droops = (0.25, 0.05, -0.35, -0.85)
            base_i = len(verts)
            for si_, frac in enumerate((0.0, 0.34, 0.67, 1.0)):
                p = crown + d * (f_len * frac)
                p.z += f_len * droops[si_] * frac if si_ else 0.0
                w = 1.0 - 0.7 * frac
                for off in (-1.0, 1.0):
                    verts.append(tuple(p + side * (w * off)))
                    kinds.append('L')
            for qi in range(3):
                i0 = base_i + qi * 2
                faces.append([i0, i0 + 1, i0 + 3, i0 + 2])
                mats.append(1)
                v0, v1 = qi / 3.0, (qi + 1) / 3.0
                uvs.append([(0.0, v0), (1.0, v0), (1.0, v1), (0.0, v1)])
        colors = [(0.0, 0.0, 0.0, 1.0)] * len(verts)
        ob = new_mesh_object("palm_arch_%d" % ai, verts, faces, mats, uvs,
                             [bark_mat, leaf_mat], colors)
        ground_and_normalize(ob.data, kinds)
        paint_palm_colors(ob.data, kinds)
        archetypes.append({"object": ob, "kinds": kinds,
                           "bark": bark_mat, "leaf": leaf_mat})
    return archetypes


# ------------------------------------------------------------------- vines
def build_vine(palm_me, bark_mat):
    """One curve-based liana: poly-spline droop from the crown edge, 4-sided
    bevel, ~40 tris. Returns a painted mesh ready to merge (mat index 0)."""
    z_top = max(v.co.z for v in palm_me.vertices)
    crown_z = z_top * rng.uniform(0.78, 0.9)
    a = rng.uniform(0.0, math.tau)
    out = Vector((math.cos(a), math.sin(a), 0.0))
    attach = out * rng.uniform(0.5, 1.1) + Vector((0.0, 0.0, crown_z))
    length = crown_z * rng.uniform(0.45, 0.7)
    swing = out * rng.uniform(0.2, 0.5)

    cu = bpy.data.curves.new("vine_curve", 'CURVE')
    cu.dimensions = '3D'
    cu.bevel_depth = 0.035
    cu.bevel_resolution = 0          # 4-sided tube (PSX budget)
    cu.use_fill_caps = False
    sp = cu.splines.new('POLY')
    n_pts = 6                        # 5 segments x 4 sides x 2 = 40 tris
    sp.points.add(n_pts - 1)
    for i in range(n_pts):
        t = i / float(n_pts - 1)
        # catenary-ish droop: outward drift + accelerating drop
        p = attach + out * (0.3 * math.sin(t * math.pi)) + swing * (t ** 2)
        p.z = attach.z - length * (t ** 1.35)
        sp.points[i].co = (p.x, p.y, p.z, 1.0)
    ob = bpy.data.objects.new("vine_tmp", cu)
    bpy.context.scene.collection.objects.link(ob)

    deps = bpy.context.evaluated_depsgraph_get()
    vme = bpy.data.meshes.new_from_object(ob.evaluated_get(deps))
    bpy.data.objects.remove(ob, do_unlink=True)
    bpy.data.curves.remove(cu)

    vme.materials.append(bark_mat)   # slot 0 == palm bark slot after merge
    for poly in vme.polygons:
        poly.material_index = 0
        poly.use_smooth = True
    # manual UVs: U around the tube, V along the droop (bark reads fine)
    z_hi = max(v.co.z for v in vme.vertices)
    z_lo = min(v.co.z for v in vme.vertices)
    span = max(z_hi - z_lo, 1e-4)
    uv = vme.uv_layers.get(UV_LAYER) or vme.uv_layers.new(name=UV_LAYER)
    for poly in vme.polygons:
        for li in poly.loop_indices:
            co = vme.vertices[vme.loops[li].vertex_index].co
            uv.data[li].uv = (math.atan2(co.y, co.x) / math.tau + 0.5,
                              (z_hi - co.z) / span * 2.0)
    # sway weights: free-hanging tip swings hardest
    col = vme.color_attributes.new(COL_ATTR, 'FLOAT_COLOR', 'POINT')
    for i, v in enumerate(vme.vertices):
        t = (z_hi - v.co.z) / span
        col.data[i].color = (0.35 + 0.55 * t, 0.25 + 0.35 * t, 0.0, 1.0)
    vme.color_attributes.active_color = col
    return vme


# ---------------------------------------------------------------- variants
def make_variant(arch, suffix, scale, lean_deg, n_vines):
    src_ob = arch["object"]
    me = src_ob.data.copy()
    me.name = "jungle_palm_" + suffix
    ob = bpy.data.objects.new("jungle_palm_" + suffix, me)
    bpy.context.scene.collection.objects.link(ob)

    for _ in range(n_vines):
        vme = build_vine(me, arch["bark"])
        merge_mesh_into(me, vme)
        bpy.data.meshes.remove(vme)

    # scale (with per-axis jitter), lean, yaw - then re-ground
    jit = lambda: rng.uniform(0.94, 1.06)
    s = Matrix.Diagonal((scale * jit(), scale * jit(), scale * jit(), 1.0))
    lean_axis = Vector((math.cos(rng.uniform(0.0, math.tau)),
                        math.sin(rng.uniform(0.0, math.tau)), 0.0))
    lean = Matrix.Rotation(math.radians(lean_deg), 4, lean_axis)
    yaw = Matrix.Rotation(rng.uniform(0.0, math.tau), 4, 'Z')
    me.transform(yaw @ lean @ s)
    z_min = min(v.co.z for v in me.vertices)
    me.transform(Matrix.Translation((0.0, 0.0, -z_min - GROUND_SINK)))
    me.update()
    return ob


# --------------------------------------------------------------- grass fan
def build_grass_fan():
    """Star-fan grass card: 3 intersecting quads at 60 degrees, 6 tris, one
    material, sway weights 0 at feet -> 1 at tips. Unit-sized (1m x 1m):
    ground_clutter.gd scales per layer/instance."""
    img = None
    if os.path.isfile(GRASS_TEX):
        try:
            img = bpy.data.images.load(GRASS_TEX)
            img.pack()
            downscale(img, 128)
        except RuntimeError:
            img = None
    if img is None:
        img = solid_image("grass_img", (0.25, 0.42, 0.16, 1.0))
    mat = make_material("grass_fan", img, alpha_clip=True)

    verts, faces, mats, uvs, colors = [], [], [], [], []
    for qi in range(3):
        a = qi * math.tau / 6.0        # 0 / 60 / 120 degrees
        dx, dy = math.cos(a) * 0.5, math.sin(a) * 0.5
        base_i = len(verts)
        verts += [(-dx, -dy, 0.0), (dx, dy, 0.0), (dx, dy, 1.0), (-dx, -dy, 1.0)]
        colors += [(0.0, 0.0, 0.0, 1.0), (0.0, 0.0, 0.0, 1.0),
                   (1.0, 1.0, 0.0, 1.0), (1.0, 1.0, 0.0, 1.0)]
        faces.append([base_i, base_i + 1, base_i + 2, base_i + 3])
        mats.append(0)
        uvs.append([(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)])
    ob = new_mesh_object("grass_fan", verts, faces, mats, uvs, [mat], colors)
    for poly in ob.data.polygons:
        poly.use_smooth = False
    return ob


# -------------------------------------------------------------------- main
def main():
    clean_scene()
    os.makedirs(OUT_DIR, exist_ok=True)

    archetypes = import_donor()
    source = "RTS donor (jungle_medium.glb)"
    if archetypes is None:
        archetypes = procedural_archetypes()
        source = "procedural fallback"
    print("[VEG] palm source:", source)

    exports = []
    for suffix, ai, scale, lean, vines in VARIANTS:
        ob = make_variant(archetypes[ai], suffix, scale, lean, vines)
        path = os.path.join(OUT_DIR, "jungle_palm_%s.glb" % suffix)
        gltf_export(path, [ob])
        h = max(v.co.z for v in ob.data.vertices)
        exports.append((os.path.basename(path), len(ob.data.vertices),
                        tri_count(ob.data), h, vines))
        bpy.data.objects.remove(ob, do_unlink=True)

    fan = build_grass_fan()
    fan_path = os.path.join(OUT_DIR, "grass_fan.glb")
    gltf_export(fan_path, [fan])
    exports.append((os.path.basename(fan_path), len(fan.data.vertices),
                    tri_count(fan.data), 1.0, 0))

    print("[VEG] ---- batch complete (%s) ----" % source)
    for name, nv, nt, h, vines in exports:
        print("[VEG] %-22s verts=%4d tris=%4d height=%.2fm vines=%d"
              % (name, nv, nt, h, vines))


main()
