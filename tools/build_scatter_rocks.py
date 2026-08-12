"""Ground-scatter rocks for RECONgame - replaces the legacy flat billboard
(terrain/textures/clutter/rock.png, a Catacombs of Gore texture ruled out of
the project) with real 3D boulders for assets/world/rocks/.

Same construction technique as the existing jungle-floor props
(tools/make_jungle_flora.py's Plant.bake(): a tiny horizontal PALETTE strip
texture, one texel per face via UV, one shared material, one surface, one
draw call - proven already in fallen_log_a/tree_stump/moss_a). Reference:
Central Highlands/Mekong ground stone is weathered granite and basalt over
red laterite soil (Truong Son orogenic belt granite intrusions; tropical
laterite weathering stains lower rock faces red-brown - GIA Gems & Gemology,
Wikipedia "Central Highlands (Vietnam)"), often moss/lichen on shaded and
top faces. The palette below encodes that story as ~11 hand-picked texels,
not a photograph.

Each rock is a stack of irregular polygon rings (deterministic per-seed
jitter), flat bottom ring pinned at z=0 (true coplanar contact, matches
"origin at base contact point"), flat-shaded. Per-face UV picks a palette
texel by a rule (height fraction + face normal + a per-face hash) so the
same seed always paints the same rock the same way. Per-vertex colour holds
a modest AO/highlight (never pure black - see the multiply-safety note in
build_rock()) rather than the vegetation sway-shader placeholder scheme;
these are static, non-swaying, non-billboarded props.

Headless:
  & "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" -b --factory-startup --python tools/build_scatter_rocks.py
"""
import bpy
import math
import os
import random

OUT_DIR = r"C:\Users\caleb\RECONgame\assets\world\rocks"
UV_LAYER = "UVMap"
COL_ATTR = "Color"
SEED = 20260812

# ------------------------------------------------------------------ palette
# LINEAR values (Principled Base Color space); encoded to sRGB on save, same
# convention as make_jungle_flora.palette_image().
PALETTE = {
    "granite_mid":   (0.240, 0.220, 0.195),
    "granite_light": (0.420, 0.400, 0.360),
    "granite_dark":  (0.080, 0.072, 0.062),
    "basalt_dark":   (0.040, 0.037, 0.034),
    "laterite":      (0.280, 0.100, 0.055),
    "laterite_dust": (0.380, 0.170, 0.090),
    "wet_dark":      (0.030, 0.030, 0.032),
    "moss_deep":     (0.055, 0.100, 0.030),
    "moss_bright":   (0.115, 0.185, 0.055),
    "lichen_pale":   (0.340, 0.340, 0.255),
    "soil_collar":   (0.095, 0.050, 0.028),
}
PAL_ORDER = list(PALETTE.keys())
PAL_INDEX = {n: i for i, n in enumerate(PAL_ORDER)}
_atlas = [None]


def _srgb(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1.0 / 2.4)) - 0.055


def palette_image():
    if _atlas[0] is not None:
        return _atlas[0]
    img = bpy.data.images.new("rock_palette", len(PAL_ORDER), 1, alpha=True)
    img.colorspace_settings.name = 'sRGB'
    px = []
    for n in PAL_ORDER:
        r, g, b = PALETTE[n]
        px += [_srgb(r), _srgb(g), _srgb(b), 1.0]
    img.pixels = px
    img.pack()
    _atlas[0] = img
    return img


def palette_material():
    """Texture wired DIRECTLY to Base Color - no vertex-colour node in the
    SOURCE graph. This matches make_jungle_flora.py's palette_material()
    exactly (verified by dumping tree_stump.glb's raw glTF JSON: the
    material has only baseColorTexture, no vertex-colour reference at all -
    the Mix/VertexColor graph Blender shows on RE-IMPORT is the importer's
    own reconstruction of core glTF COLOR_0-multiplies-baseColor behaviour,
    not something the exporter needs wired in the source material). Vertex
    colour still rides along as mesh data (color_attributes + export_vertex_
    color='ACTIVE') for any consumer that wants it; wiring a Mix node into
    Base Color here risked the exporter not finding a clean image texture
    to bake as pbrMetallicRoughness.baseColorTexture."""
    m = bpy.data.materials.get("rock_atlas")
    if m:
        return m
    m = bpy.data.materials.new("rock_atlas")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Roughness'].default_value = 0.96
    bsdf.inputs['Metallic'].default_value = 0.0
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = palette_image()
    tex.interpolation = 'Closest'
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    return m


def clean():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for b in list(block):
            if b.users == 0:
                block.remove(b)
    _atlas[0] = None


# --------------------------------------------------------------- rock build
def _ring(rng, sides, cx, cy, z, r, xy_jitter, z_jitter, angle_jitter):
    verts = []
    for s in range(sides):
        a = (s / sides) * math.tau + rng.uniform(-angle_jitter, angle_jitter)
        rr = r * rng.uniform(1.0 - xy_jitter, 1.0 + xy_jitter)
        zz = z + rng.uniform(-z_jitter, z_jitter)
        verts.append((cx + rr * math.cos(a), cy + rr * math.sin(a), zz))
    return verts


def build_lump(rng, sides, profile, radius, height, xy_jitter, z_jitter,
               angle_jitter, cx=0.0, cy=0.0):
    """profile: [(z_frac, r_frac), ...] silhouette control points, z_frac=0
    and z_frac=1 MUST be present. Returns (verts, faces) in local space, the
    z_frac=0 ring exactly flat at z=0 (no z_jitter there - true base
    contact)."""
    rings = []
    for i, (zf, rf) in enumerate(profile):
        z = zf * height
        r = rf * radius
        zj = 0.0 if i == 0 else z_jitter          # base ring stays flat
        rings.append(_ring(rng, sides, cx, cy, z, r, xy_jitter, zj, angle_jitter))

    verts = []
    faces = []
    ring_start = []
    for ring in rings:
        ring_start.append(len(verts))
        verts.extend(ring)

    # side quads between consecutive rings
    for ri in range(len(rings) - 1):
        b0, b1 = ring_start[ri], ring_start[ri + 1]
        for s in range(sides):
            sn = (s + 1) % sides
            faces.append([b0 + s, b0 + sn, b1 + sn, b1 + s])

    # flat bottom cap (fan to a centroid at the base ring's own z, i.e. 0.0)
    base_ring = rings[0]
    base_start = ring_start[0]
    cxb = sum(v[0] for v in base_ring) / sides
    cyb = sum(v[1] for v in base_ring) / sides
    base_centre_i = len(verts)
    verts.append((cxb, cyb, 0.0))
    for s in range(sides):
        sn = (s + 1) % sides
        faces.append([base_start + sn, base_start + s, base_centre_i])

    # top cap: fan to a centroid at (near) the ring's OWN average height. A
    # tall extension above the ring reads as a crystalline spike, not a
    # weathered boulder top - measured off the first render pass (every
    # variant showed a needle-like apex). A small nudge (not a peak) keeps
    # the cap from being perfectly flat/disc-like.
    top_ring = rings[-1]
    top_start = ring_start[-1]
    top_z = (sum(v[2] for v in top_ring) / sides) + 0.015 * height
    cxt = sum(v[0] for v in top_ring) / sides
    cyt = sum(v[1] for v in top_ring) / sides
    top_centre_i = len(verts)
    verts.append((cxt, cyt, top_z))
    for s in range(sides):
        sn = (s + 1) % sides
        faces.append([top_start + s, top_start + sn, top_centre_i])

    # Hard floor: z_jitter on a low ring (small z_frac * height) can exceed
    # that ring's own target height and poke a vertex below the flat base
    # plane - measured on rock_small_b (index 7, z=-0.0086m). The base ring
    # is the ONLY thing that may sit at z=0; every other vertex is clamped
    # to stay at or above it so the flat contact plane is always the mesh's
    # true lowest point (ADR-side requirement: flat-bottomed, no floating
    # AND no sub-surface spurs).
    verts = [(x, y, max(0.0, z)) for (x, y, z) in verts]
    return verts, faces


def _face_normal(vs):
    # Newell's method - correct for the n-gon caps too
    nx = ny = nz = 0.0
    n = len(vs)
    for i in range(n):
        x0, y0, z0 = vs[i]
        x1, y1, z1 = vs[(i + 1) % n]
        nx += (y0 - y1) * (z0 + z1)
        ny += (z0 - z1) * (x0 + x1)
        nz += (x0 - x1) * (y0 + y1)
    length = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
    return (nx / length, ny / length, nz / length)


def paint_and_uv(verts, faces, height, rng, moss_bias=0.5, laterite_bias=0.5,
                  base_texel="wet_dark"):
    """Returns (uv_per_face_corner, vertex_colors). UV: every corner of a
    face points at that face's chosen palette texel (same trick as
    make_jungle_flora.Plant.bake). Vertex colour: modest AO (height + normal
    based), clamped so it never approaches 0 - see palette_material()."""
    n_pal = float(len(PAL_ORDER))
    face_uv = []
    for f in faces:
        vs = [verts[i] for i in f]
        nz = _face_normal(vs)[2]
        zf = (sum(v[2] for v in vs) / len(vs)) / max(height, 1e-4)
        h = rng.random()  # deterministic draw off the rock's own rng stream

        if zf < 0.05:
            name = base_texel
        elif nz > 0.75 and h < moss_bias * 0.5:
            name = "moss_bright" if h < moss_bias * 0.25 else "moss_deep"
        elif nz > 0.7:
            name = "granite_light"
        elif nz < -0.30:
            name = "granite_dark"
        else:
            r = h
            laterite_cut = laterite_bias * (1.0 - zf) * 0.6
            if r < laterite_cut * 0.5:
                name = "laterite"
            elif r < laterite_cut:
                name = "laterite_dust"
            elif r < laterite_cut + 0.10:
                name = "basalt_dark"
            elif r < laterite_cut + 0.18:
                name = "lichen_pale"
            else:
                name = "granite_mid"
        u = (PAL_INDEX[name] + 0.5) / n_pal
        face_uv.append([(u, 0.5)] * len(f))

    vcol = []
    for v in verts:
        zf = max(0.0, min(1.0, v[2] / max(height, 1e-4)))
        ao = 0.72 + 0.28 * zf                 # darker at the base, brighter up top
        ao += rng.uniform(-0.05, 0.05)         # hand-painted grain
        ao = max(0.55, min(1.05, ao))
        vcol.append((ao, ao, ao, 1.0))
    return face_uv, vcol


def bake_object(name, verts, faces, face_uv, vcol):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    me.materials.append(palette_material())
    for poly in me.polygons:
        poly.material_index = 0
        poly.use_smooth = False               # flat facets, PSX read
    uv = me.uv_layers.new(name=UV_LAYER)
    li = 0
    for corners in face_uv:
        for c in corners:
            uv.data[li].uv = c
            li += 1
    col = me.color_attributes.new(COL_ATTR, 'BYTE_COLOR', 'CORNER')
    # CORNER domain - one entry per loop, in polygon/loop order (matches the
    # existing tree_stump/fallen_log convention measured off their GLBs)
    for poly in me.polygons:
        for li2 in poly.loop_indices:
            vi = me.loops[li2].vertex_index
            col.data[li2].color = vcol[vi]
    me.color_attributes.active_color = col
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def merge_objects(objs, name):
    """Join a list of baked objects into one mesh (cluster variant). All
    already share the one 'rock_atlas' material."""
    bpy.context.view_layer.objects.active = objs[0]
    for o in bpy.data.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    joined.name = name
    joined.data.name = name
    return joined


def tri_count(me):
    return sum(max(0, len(p.vertices) - 2) for p in me.polygons)


def export(ob, path):
    for o in bpy.data.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    kwargs = dict(filepath=path, export_format='GLB', use_selection=True,
                  export_apply=True, export_animations=False, export_skins=False,
                  export_morph=False, export_cameras=False, export_lights=False,
                  export_yup=True, export_extras=False, export_tangents=False,
                  export_vertex_color='ACTIVE', export_all_vertex_colors=False,
                  export_active_vertex_color_when_no_material=True)
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    bpy.ops.export_scene.gltf(**{k: v for k, v in kwargs.items() if k in props})


def save_palette_png(path=None):
    path = path or os.path.join(OUT_DIR, "rock_palette.png")
    img = palette_image()
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    return path


# ---------------------------------------------------------------- variants
def make_rock_small_a(rng):
    """Fist-sized, rounded/domed river-worn stone."""
    profile = [(0.0, 0.92), (0.22, 1.05), (0.50, 1.00), (0.80, 0.68), (1.0, 0.34)]
    verts, faces = build_lump(rng, sides=6, profile=profile, radius=0.155,
                               height=0.30, xy_jitter=0.14, z_jitter=0.05,
                               angle_jitter=0.28)
    face_uv, vcol = paint_and_uv(verts, faces, 0.30, rng, moss_bias=0.55,
                                  laterite_bias=0.45)
    return bake_object("rock_small_a", verts, faces, face_uv, vcol)


def make_rock_small_b(rng):
    """Different silhouette in the same size band: angular/blocky, not
    rounded - fewer sides, sharper radius steps, heavier jitter."""
    profile = [(0.0, 0.88), (0.18, 1.10), (0.48, 0.78), (0.72, 0.92), (1.0, 0.32)]
    verts, faces = build_lump(rng, sides=5, profile=profile, radius=0.15,
                               height=0.27, xy_jitter=0.22, z_jitter=0.055,
                               angle_jitter=0.18)
    face_uv, vcol = paint_and_uv(verts, faces, 0.27, rng, moss_bias=0.35,
                                  laterite_bias=0.55)
    return bake_object("rock_small_b", verts, faces, face_uv, vcol)


def make_rock_cluster_a(rng):
    """3-4 stones as ONE mesh, ~0.8-1.2m footprint."""
    lumps_spec = [
        # (cx, cy, sides, radius, height, profile)
        (0.00, 0.00, 6, 0.24, 0.42,
         [(0.0, 0.90), (0.25, 1.05), (0.55, 0.95), (0.80, 0.60), (1.0, 0.32)]),
        (0.34, 0.10, 5, 0.16, 0.28,
         [(0.0, 0.85), (0.20, 1.08), (0.5, 0.80), (0.75, 0.62), (1.0, 0.30)]),
        (-0.22, 0.28, 6, 0.14, 0.22,
         [(0.0, 0.92), (0.3, 1.05), (0.6, 0.85), (1.0, 0.34)]),
        (0.08, -0.32, 5, 0.11, 0.17,
         [(0.0, 0.88), (0.3, 1.05), (0.7, 0.58), (1.0, 0.28)]),
    ]
    objs = []
    for i, (cx, cy, sides, radius, height, profile) in enumerate(lumps_spec):
        verts, faces = build_lump(rng, sides=sides, profile=profile, radius=radius,
                                   height=height, xy_jitter=0.16, z_jitter=0.06,
                                   angle_jitter=0.22, cx=cx, cy=cy)
        face_uv, vcol = paint_and_uv(verts, faces, height, rng,
                                      moss_bias=0.5, laterite_bias=0.5,
                                      base_texel="wet_dark")
        objs.append(bake_object("rock_cluster_lump_%d" % i, verts, faces, face_uv, vcol))
    return merge_objects(objs, "rock_cluster_a")


def make_rock_half_buried_a(rng):
    """Larger stone emerging from the ground - flat cylindrical lower 55%
    (reads as still-submerged mass), lumpy emergent boulder on top, a darker
    damp-soil texel ring right at the contact line."""
    profile = [(0.0, 1.00), (0.10, 1.02), (0.30, 0.98), (0.55, 0.90),
               (0.72, 0.68), (0.90, 0.48), (1.0, 0.30)]
    verts, faces = build_lump(rng, sides=8, profile=profile, radius=0.34,
                               height=0.62, xy_jitter=0.10, z_jitter=0.03,
                               angle_jitter=0.16)
    face_uv, vcol = paint_and_uv(verts, faces, 0.62, rng, moss_bias=0.6,
                                  laterite_bias=0.65, base_texel="soil_collar")
    return bake_object("rock_half_buried_a", verts, faces, face_uv, vcol)


BUILDERS = [
    ("rock_small_a", make_rock_small_a),
    ("rock_small_b", make_rock_small_b),
    ("rock_cluster_a", make_rock_cluster_a),
    ("rock_half_buried_a", make_rock_half_buried_a),
]


def main():
    clean()
    os.makedirs(OUT_DIR, exist_ok=True)
    save_palette_png()
    rows = []
    for name, fn in BUILDERS:
        rng = random.Random("%d:%s" % (SEED, name))
        clean_but_keep_palette_mat()
        ob = fn(rng)
        me = ob.data
        tris = tri_count(me)
        zs = [v.co.z for v in me.vertices]
        xs = [v.co.x for v in me.vertices]
        ys = [v.co.y for v in me.vertices]
        path = os.path.join(OUT_DIR, name + ".glb")
        export(ob, path)
        rows.append((name, len(me.vertices), tris,
                      round(max(xs) - min(xs), 3), round(max(ys) - min(ys), 3),
                      round(max(zs) - min(zs), 3), round(min(zs), 4)))
    print("\n%-20s %6s %6s %8s %8s %8s %10s" %
          ("asset", "verts", "tris", "dx_m", "dy_m", "dz_m", "min_z"))
    for r in rows:
        print("%-20s %6d %6d %8.3f %8.3f %8.3f %10.4f" % r)
    print("\n%d rocks -> %s" % (len(rows), OUT_DIR))


def clean_but_keep_palette_mat():
    """Between variants: remove mesh objects/data but keep the shared
    rock_atlas material + rock_palette image (one material, one texture for
    the whole batch, matching the jungle_atlas convention)."""
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)


if __name__ == "__main__":
    main()
