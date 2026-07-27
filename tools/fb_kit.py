"""Firebase micro-part library and sandbag wall generator.

Ground truth: a sandbag is 0.50 x 0.25 x 0.13 m laid flat. Bags are NEVER scaled to reach a
target wall height - the course count changes and the height lands where it lands.

The wall body is a slab whose outer face carries a low-frequency per-bag displacement; the
texture carries the fine bag rhythm. Real bag meshes are spent only where silhouette reads:
the top course, loose scatter, split bags, hand-placed detail.

fb_sandbag_wall is appended at material index 9. Inserting it would shift every index in
gen_firebase.py:76 MAT_INDEX and silently reassign every face in the existing kit.
"""
import bpy, bmesh, math, os, random
import numpy as np
from mathutils import Vector, Matrix, Euler

ROOT = r"C:\Users\caleb\RECONgame\assets\world\building models\structures\firebase"
TEX_DIR = os.path.join(ROOT, "tex")
KIT_DIR = os.path.join(ROOT, "kit")
SRC_TEX = r"C:\Users\caleb\Desktop\recon game image ideas\sandbag_textures.png"

BAG_L, BAG_W, BAG_H = 0.50, 0.25, 0.13
THICKNESS = BAG_W
LUMP = 0.03
TEXEL = 160.0
WALL_TILE = 2.0

# Order is load-bearing: gen_firebase.py:61-76 assigns faces by index into this list.
MATS9 = ["fb_sandbag", "fb_earth", "fb_timber", "fb_psp", "fb_canvas",
         "fb_corrugated", "fb_crate", "fb_gunmetal", "fb_olive"]
WALL_MAT = "fb_sandbag_wall"
WALL_MAT_INDEX = 9

MAT_COLOURS = {
    "fb_sandbag": (0.54, 0.49, 0.38, 1.0), "fb_earth": (0.48, 0.35, 0.24, 1.0),
    "fb_timber": (0.42, 0.33, 0.22, 1.0), "fb_psp": (0.38, 0.39, 0.36, 1.0),
    "fb_canvas": (0.41, 0.42, 0.31, 1.0), "fb_corrugated": (0.44, 0.44, 0.42, 1.0),
    "fb_crate": (0.34, 0.36, 0.24, 1.0), "fb_gunmetal": (0.055, 0.055, 0.060, 1.0),
    "fb_olive": (0.152, 0.180, 0.110, 1.0), WALL_MAT: (0.54, 0.49, 0.38, 1.0),
}


# --------------------------------------------------------------------- texture --

def _area_resize(a, new_h, new_w):
    h, w = a.shape[:2]
    ry = np.linspace(0, h, new_h, endpoint=False).astype(int)
    rx = np.linspace(0, w, new_w, endpoint=False).astype(int)
    cy = np.diff(np.append(ry, h))[:, None, None]
    cx = np.diff(np.append(rx, w))[None, :, None]
    return np.add.reduceat(np.add.reduceat(a, ry, axis=0), rx, axis=1) / (cy * cx)


def _seam_blend(a, f):
    """Overlap cross-fade. Returns an image f px smaller per axis whose edges wrap cleanly."""
    h, w = a.shape[:2]
    tx = np.linspace(0.0, 1.0, f)[None, :, None]
    out = a[:, :w - f].copy()
    out[:, :f] = a[:, :f] * tx + a[:, w - f:] * (1.0 - tx)
    ty = np.linspace(0.0, 1.0, f)[:, None, None]
    out2 = out[:h - f].copy()
    out2[:f] = out[:f] * ty + out[h - f:] * (1.0 - ty)
    return out2


def build_wall_texture(save=True):
    """Resample the source photo into a seamless tile at exactly TEXEL px/m.

    Measured on the source by autocorrelation of row/column means: bag period 412 px,
    running-bond period 196 px = 2 courses. A crop of 2 bag periods x 2 bond periods is
    therefore 2 bags x 4 courses of real wall = 1.00 m x 0.50 m.
    """
    img = bpy.data.images.load(SRC_TEX, check_existing=True)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)

    cw, ch = 824, 392
    x0, y0 = (w - cw) // 2, (h - ch) // 2
    crop = px[y0:y0 + ch, x0:x0 + cw]

    f = 16
    unit_w, unit_h = int(round(1.00 * TEXEL)), int(round(0.50 * TEXEL))
    small = _seam_blend(_area_resize(crop, unit_h + f, unit_w + f), f)

    tile = np.tile(small, (int(round(WALL_TILE / 0.50)), int(round(WALL_TILE / 1.00)), 1))
    tile[:, :, 3] = 1.0
    th, tw = tile.shape[:2]

    out = bpy.data.images.get(WALL_MAT + ".png")
    if out is not None and tuple(out.size) != (tw, th):
        bpy.data.images.remove(out)
        out = None
    if out is None:
        out = bpy.data.images.new(WALL_MAT + ".png", tw, th, alpha=True)
    out.pixels = tile.reshape(-1).tolist()
    if save:
        out.filepath_raw = os.path.join(TEX_DIR, WALL_MAT + ".png")
        out.file_format = 'PNG'
        out.save()
    return out, (tw, th)


def build_mud_texture(save=True):
    """Wet churned laterite with wheel ruts, for the perimeter road and the mud patches.

    Authored at the kit's own density - 256 px over the 1.6 m box-projection tile = 160 px/m.
    """
    src = os.path.join(TEX_DIR, "fb_earth.png")
    n = 256
    if os.path.exists(src):
        e = bpy.data.images.load(src, check_existing=True)
        a = np.array(e.pixels[:], dtype=np.float32).reshape(e.size[1], e.size[0], 4)
        a = _area_resize(a, n, n)
    else:
        a = np.zeros((n, n, 4), dtype=np.float32)
        a[:, :, :3] = (0.48, 0.35, 0.24)
        a[:, :, 3] = 1.0

    y, x = np.mgrid[0:n, 0:n].astype(np.float32) / n
    rng = np.random.default_rng(7)
    grain = rng.random((n, n)).astype(np.float32)
    grain = (grain + np.roll(grain, 3, 0) + np.roll(grain, 3, 1)) / 3.0

    # Ruts run along U. Two bands per tile puts a wheel pair under a 2 m vehicle track.
    rut = np.cos(y * math.tau * 2.0) * 0.5 + 0.5
    rut = rut ** 6
    wet = 0.42 + 0.30 * grain - 0.22 * rut
    a[:, :, :3] *= wet[:, :, None]
    a[:, :, :3] += (rut * 0.05)[:, :, None]
    a[:, :, :3] = np.clip(a[:, :, :3], 0.0, 1.0)
    a[:, :, 3] = 1.0

    out = bpy.data.images.get("fb_mud.png")
    if out is not None and tuple(out.size) != (n, n):
        bpy.data.images.remove(out)
        out = None
    if out is None:
        out = bpy.data.images.new("fb_mud.png", n, n, alpha=True)
    out.pixels = a.reshape(-1).tolist()
    if save:
        out.filepath_raw = os.path.join(TEX_DIR, "fb_mud.png")
        out.file_format = 'PNG'
        out.save()
    return out


def ensure_materials():
    """The nine kit slots in their fixed order, plus fb_sandbag_wall appended at index 9."""
    mats = []
    for name in MATS9 + [WALL_MAT]:
        m = bpy.data.materials.get(name)
        if m is None:
            m = bpy.data.materials.new(name)
            m.use_nodes = True
            nt = m.node_tree
            bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
            bsdf.inputs["Base Color"].default_value = MAT_COLOURS[name]
            bsdf.inputs["Roughness"].default_value = 0.94
            path = os.path.join(TEX_DIR, name + ".png")
            if os.path.exists(path):
                tex = nt.nodes.new("ShaderNodeTexImage")
                tex.image = bpy.data.images.load(path, check_existing=True)
                tex.interpolation = 'Closest'
                tex.location = (-420, 220)
                nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        m.diffuse_color = MAT_COLOURS[name]
        mats.append(m)
    return mats


def box_project(mesh, tile=WALL_TILE):
    uv = mesh.uv_layers.get("UVMap") or mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        n = poly.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for li in poly.loop_indices:
            co = mesh.vertices[mesh.loops[li].vertex_index].co
            u, v = (co.y, co.z) if ax == 0 else ((co.x, co.z) if ax == 1 else (co.x, co.y))
            uv.data[li].uv = (u / tile, v / tile)


# ------------------------------------------------------------------- micro-part --

def sandbag_bmesh(variant="A", seed=0):
    """One bag. Lofted pillow: 4 rings of 6, pinched ends, triangulated caps. 44 tris.

    The profile is authored with its underside ON z=0. Scaling z at the pinched end rings
    would lift the bag's ends off the deck and it reads as a flat lozenge floating above
    the course below - only the width tapers.
    """
    rng = random.Random(f"bag:{variant}:{seed}")
    sag = {"A": 1.00, "B": 0.92, "C": 1.06}.get(variant, 1.0)
    bm = bmesh.new()
    hw, hl = BAG_W / 2.0, BAG_L / 2.0
    top = BAG_H * sag
    section = [(-hw, top * 0.16), (-hw * 0.90, top * 0.80), (0.0, top),
               (hw * 0.90, top * 0.80), (hw, top * 0.16), (0.0, 0.0)]
    rings = []
    for x, k, zk in [(-hl, 0.58, 0.72), (-hl * 0.5, 1.0, 1.0),
                     (hl * 0.5, 1.0, 1.0), (hl, 0.58, 0.72)]:
        slump = 1.0 + rng.uniform(-0.05, 0.05)
        rings.append([bm.verts.new((x, y * k * slump, z * zk)) for y, z in section])
    bm.verts.ensure_lookup_table()
    n = len(section)
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    for f in bm.faces:
        f.smooth = True
        f.material_index = WALL_MAT_INDEX
    return bm


# ------------------------------------------------------------------------ wall --

def courses_for(height):
    return max(1, int(round(height / BAG_H)))


def _stations(path, step):
    """Centreline samples. Path vertices carry a mitred normal; interior samples carry the
    segment normal, so a corner stays hard instead of bending across the whole arm."""
    def seg_n(a, b):
        d = (Vector(b) - Vector(a)).normalized()
        return Vector((d.y, -d.x))

    normals = [seg_n(path[i], path[i + 1]) for i in range(len(path) - 1)]
    st = []
    for i in range(len(path) - 1):
        a, b = Vector(path[i]), Vector(path[i + 1])
        n_seg = normals[i]
        if i == 0:
            st.append((a, n_seg, 1.0))
        cnt = max(1, int(round((b - a).length / step)))
        for j in range(1, cnt):
            st.append((a.lerp(b, j / cnt), n_seg, 1.0))
        if i < len(path) - 2:
            m = (n_seg + normals[i + 1]).normalized()
            k = 1.0 / max(math.sqrt(max((1.0 + n_seg.dot(normals[i + 1])) / 2.0, 1e-6)), 0.35)
            st.append((b, n_seg, 1.0))
            st.append((b, m, k))
            st.append((b, normals[i + 1], 1.0))
        else:
            st.append((b, n_seg, 1.0))
    return st


def build_sandbag_wall(length=1.0, height=None, courses=None, style="straight", seed=0,
                       thickness=THICKNESS, lump=LUMP, inner="flat", back="keep",
                       top_course="real", name="fb_sbg_wall", path=None, base_z=0.0,
                       side=None, into=None):
    """Emit one sandbag wall module. Origin sits at the connection face, on Z=0.

    `courses` wins over `height`; a height is rounded to whole courses and the built height
    is reported back, never forced to match the request.

    `path` overrides the style-derived centreline with an explicit XY polyline, which is how
    the firebase families lay revetments along an arbitrary run or around a pit. `into` welds
    the result straight into a caller's bmesh and returns (None, stats) instead of an object.
    """
    if courses is None:
        courses = courses_for(height if height is not None else 1.17)
    slab_courses = max(1, courses - 1) if top_course == "real" else courses
    slab_h = slab_courses * BAG_H
    t = thickness

    if path is None:
        if style in ("straight", "end_cap"):
            path = [(0.0, 0.0), (length, 0.0)]
        elif style in ("corner_out", "corner_in"):
            path = [(0.0, 0.0), (length - t / 2.0, 0.0), (length - t / 2.0, length)]
        else:
            raise ValueError(f"style {style!r} not in this batch")
    else:
        path = [(float(p[0]), float(p[1])) for p in path]
    if side is None:
        # +1 is the right-hand side of travel; a CCW ring therefore faces outward.
        side = 1.0 if style == "corner_in" else -1.0
    side = float(side)
    flip = side > 0

    st = _stations(path, BAG_L / 2.0)
    nrows = max(3, int(round(slab_h / (BAG_H * 2.0))))
    zs = [slab_h * i / nrows for i in range(nrows + 1)]
    rng = random.Random(f"wall:{style}:{seed}")

    bm = bmesh.new()
    outer, innr = [], []
    for ci, (c, nv, nk) in enumerate(st):
        oc, ic = [], []
        for ri, z in enumerate(zs):
            r = random.Random(f"{seed}:{ci}:{ri}")
            # Damping the top row is what made the crest read as a machined straight edge.
            d = r.uniform(-lump, lump) * (0.35 if ri == 0 else 1.0)
            zj = base_z + z + (r.uniform(-lump * 0.6, lump * 0.6) if ri == nrows else 0.0)
            off = nv * side * (t / 2.0 * nk)
            push = nv * side * d
            oc.append(bm.verts.new((c.x + off.x + push.x, c.y + off.y + push.y, zj)))
            ic.append(bm.verts.new((c.x - off.x, c.y - off.y, zj)))
        outer.append(oc)
        innr.append(ic)

    def quad(vs, smooth=False):
        try:
            f = bm.faces.new(tuple(reversed(vs)) if flip else tuple(vs))
        except ValueError:
            return
        f.material_index = WALL_MAT_INDEX
        f.smooth = smooth

    for ci in range(len(st) - 1):
        for ri in range(nrows):
            quad([outer[ci][ri], outer[ci + 1][ri], outer[ci + 1][ri + 1], outer[ci][ri + 1]], True)
            if back == "keep":
                quad([innr[ci][ri + 1], innr[ci + 1][ri + 1], innr[ci + 1][ri], innr[ci][ri]])
        quad([outer[ci][nrows], outer[ci + 1][nrows], innr[ci + 1][nrows], innr[ci][nrows]])
    for ri in range(nrows):
        quad([outer[0][ri + 1], innr[0][ri + 1], innr[0][ri], outer[0][ri]])
        if style != "end_cap":
            quad([outer[-1][ri], innr[-1][ri], innr[-1][ri + 1], outer[-1][ri + 1]])

    if top_course == "real":
        total_len = sum((Vector(path[i + 1]) - Vector(path[i])).length for i in range(len(path) - 1))
        n_bags = max(1, int(round(total_len / BAG_L)))
        for i in range(n_bags):
            s = (i + 0.5) / n_bags
            idx = min(int(s * (len(st) - 1)), len(st) - 2)
            c, _, _ = st[idx]
            c2 = st[idx + 1][0]
            head = math.atan2(c2.y - c.y, c2.x - c.x)
            if (c2 - c).length < 1e-6:
                head = 0.0
            bb = sandbag_bmesh("ABC"[i % 3], seed * 97 + i)
            sc = 1.0 + rng.uniform(-0.04, 0.04)
            m = Euler((0.0, 0.0, head + math.radians(rng.uniform(-8, 8)))).to_matrix().to_4x4()
            m.translation = Vector((c.x + rng.uniform(-0.02, 0.02),
                                    c.y + rng.uniform(-0.02, 0.02), base_z + slab_h))
            for vt in bb.verts:
                vt.co = m @ (vt.co * sc)
            tmp = bpy.data.meshes.new("_bag")
            bb.to_mesh(tmp)
            bb.free()
            bm.from_mesh(tmp)
            bpy.data.meshes.remove(tmp)

    tris = sum(len(f.verts) - 2 for f in bm.faces)
    if into is not None:
        tmp = bpy.data.meshes.new("_wall")
        bm.to_mesh(tmp)
        bm.free()
        into.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
        return None, {"name": name, "tris": tris, "courses": courses,
                      "height": round(courses * BAG_H, 4), "dims": None}

    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in ensure_materials():
        me.materials.append(m)
    box_project(me)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)

    return ob, {"name": name, "tris": tris, "courses": courses,
                "height": round(courses * BAG_H, 4),
                "dims": tuple(round(v, 3) for v in ob.dimensions)}
