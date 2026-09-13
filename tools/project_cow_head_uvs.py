"""project_cow_head_uvs.py - full-cell head projection for the Conquest of Worms cast.

Caleb's ruling 2026-09-11: "the faces are too small for the heads where we need to spread out
the uv more so it fits better." This overrides the pipeline's "never re-unwrap the head" rule
for the CoW cast ONLY (the stock roster wrap is untouched; us_base_v3.blend is never opened).

    "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" --background ^
        assets/us/characters/conquest_of_worms_us_cast.blend --python tools/project_cow_head_uvs.py -- [--save]
    "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" --background ^
        production/cinematics/talking_heads/talking_heads.blend --python tools/project_cow_head_uvs.py -- --talking-heads [--save]
    ... assets/ww1/characters/conquest_of_worms_ww1.blend --python tools/project_cow_head_uvs.py -- --tags a,b,c [--save]
        (any cast built on us_grunt_joined_<tag> / grunt_head_<tag> with a "face_atlas*" material)

THE DEFECT, measured on the shipping body (us_grunt_joined_*): the 4 front quads sampled only
the inner 45 px of the 130 px painted cell (cheek to cheek, no ears), the 4 side quads took
the cheeks+ears, and the other 20 head polys (scalp, back, nape, behind the ears) sat on ONE
texel each. The painted face read as a small mask on a big flat head.

THE FIX: every head poly gets a real patch of the painted cell, chosen by what the polygon
FACES (polygon normal, never vertex position):
  FRONT  (n.y < -0.5)                               front planar projection (x,z), affine
         solved by least squares so mesh chin/nose/brow/ear verts land on the painted
         chin/nose-tip/hairline/ear centroids; residuals printed in cell pixels.
  SIDE   (|n.x| > 0.85, n.y < 0: face edge -> widest ring)  cheek skin. Front-edge verts take
         the FRONT value (seam exact); the widest-ring verts take the painted CHEEK column
         8 px inside the face outline at that height. A UV seam sits on the widest ring.
  EAR    (|n.x| > 0.85, n.y > 0, centre z < 1.72: widest ring -> rear verts)  the painted ear,
         column by DEPTH: the ear/cheek crease (+2 px) on the widest ring, the cell's right
         edge on the rear verts, rows by the same vertical affine as the face. Caleb's ruling
         2026-09-12: "we just need to push the ears back to the sides of all their heads" -
         the old side shear put the ear centroid at y -0.064 (27% of head depth, on the
         cheek); this puts it at ~60%, behind the jaw corner (v2/v16, y -0.021).
  TOP    (n.z > 0.85)                               top-down (x,y) into the hair dome rows.
  HAIR   (rear/rear-side above the ear line)         back (x,z) into the hair band rows.
  LOWER  (nape, n.y > 0.5 and n.z < -0.3)            side (y,z) into the shadowed skin strip
                                                     under each painted ear.
  NECK   (body only, every vert z < 1.60, |x| < 0.12) front (x,z) into the painted neck rows.
Hands/forearms (the other polys on the face material) are NOT touched - they keep the
lower-cheek texel from tools/fix_cow_neck_uvs.py.

Gates: no vertex moves (coordinate hash before == after), poly/loop counts unchanged, every
touched loop inside its cell rectangle AND clear of the cell's white border (px >= 3,
py <= 158), untouched loops bit-identical, group counts FRONT 6 / SIDE 6 / EAR 6 / TOP 4 /
HAIR 6 / LOWER 2 (+20 neck) per game head, no SIDE loop on ear paint, painted ear centroid
behind the jaw corner.
"""
import bpy
import sys
import hashlib
import math
import numpy as np
from mathutils import Vector

D = bpy.data
FACE_COLS, FACE_ROWS = 10, 7          # grunt_dresser.gd:20-21
ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
TALKING = "--talking-heads" in ARGV
SAVE = "--save" in ARGV
# --tags a,b,c : any cast whose bodies are us_grunt_joined_<tag> / grunt_head_<tag> and whose
# face material name starts with "face_atlas" (the WW1 cast, 2026-09-12)
TAGS = next((a.split("=", 1)[1] if "=" in a else ARGV[ARGV.index(a) + 1] for a in ARGV if a.startswith("--tags")), "")
TAGS = [t for t in TAGS.split(",") if t]
CELL_W, CELL_H = 130, 162            # painted cell size (cow_*_face_cell.png)
BORDER_X, BORDER_Y = 3, 158          # white grid lines live at px<3 and py>158 in the cell


# ----------------------------------------------------------------------------------------------
# image side
# ----------------------------------------------------------------------------------------------
def img_of(mat):
    for n in mat.node_tree.nodes:
        if n.type == 'TEX_IMAGE' and n.image:
            return n.image
    return None


_PX = {}


def pixels_topdown(img):
    """(H, W, 4) float array, row 0 = TOP of the image (Blender stores bottom-up)."""
    if img.name in _PX:
        return _PX[img.name]
    w, h = img.size
    a = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    a = a.reshape(h, w, 4)[::-1].copy()
    _PX[img.name] = a
    return a


def cell_rect(us, vs, W, H):
    """Atlas-pixel rect (x0, y0_from_top, w, h) of the cell the given island sits in."""
    col = int(math.floor(np.mean(us) * FACE_COLS))
    row_b = int(math.floor(np.mean(vs) * FACE_ROWS))
    x0 = int(round(col * W / FACE_COLS))
    y0 = int(round((FACE_ROWS - 1 - row_b) * H / FACE_ROWS))
    return col, row_b, x0, y0, min(CELL_W, W - x0), min(CELL_H, H - y0)


def box3(m):
    p = np.pad(m, 1, mode='edge')
    o = np.zeros_like(m)
    for dy in (0, 1, 2):
        for dx in (0, 1, 2):
            o += p[dy:dy + m.shape[0], dx:dx + m.shape[1]]
    return o / 9.0


def measure_cell(block):
    """Painted feature positions in cell pixels (x right, y DOWN from the cell top).
    Thresholds calibrated on cow_michael/gus_face_cell.png; every value is asserted."""
    a = block[..., :3]
    Hh, W = a.shape[:2]
    lum = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
    ls = box3(lum)
    skin = (lum > 0.30) & (a[..., 0] > a[..., 2] + 0.08)
    f = {}
    eyes = []
    for x0, x1 in ((30, 63), (67, 100)):
        win = ls[55:80, x0:x1]
        iy, ix = np.unravel_index(win.argmin(), win.shape)
        eyes.append((x0 + ix, 55 + iy))
    f["eye_l"], f["eye_r"] = eyes
    ey = (eyes[0][1] + eyes[1][1]) / 2.0
    xm0, xm1 = eyes[0][0] + 5, eyes[1][0] - 5
    # lip line: darkest band between the nose base and the chin. Rows 98-118, not 100-135:
    # on a light-lipped cell (german_line, atlas 3/7) the chin crease at 128 out-darkened
    # the lips and the "mouth" landed on the chin (2026-09-12). Every cell measured so far
    # has its lips at 100-105 and the assert below already demands 95 < my < 120.
    band = ls[98:118, xm0:xm1].mean(axis=1)
    my = 98 + int(band.argmin())
    f["mouth"] = ((xm0 + xm1) / 2.0, my)
    # chin crease: darkest row well below the mouth. Starts 12 rows down, not 5: on a
    # moustached cell (poilu_1916, atlas 2/4) the "mouth" lands on the moustache and the
    # lip line 5 rows under it read as the chin (105 vs the real 128) - 2026-09-12.
    cb = ls[my + 12: my + 38, 55:75].mean(axis=1)
    f["chin_y"] = my + 12 + int(cb.argmin())
    nb = ls[int(ey) + 5: my - 8, 60:71]
    iy, ix = np.unravel_index(nb.argmax(), nb.shape)
    hi_y = int(ey) + 5 + iy                                   # nose-tip highlight
    r0, r1 = int(ey) + 12, my - 9
    nband = ls[r0:r1, 54:72].mean(axis=1)
    nostril_y = r0 + int(nband.argmin())
    f["nose_tip"] = ((eyes[0][0] + eyes[1][0]) / 2.0, (hi_y + nostril_y) / 2.0)
    f["nostril_y"] = nostril_y
    # mouth corners: where the dark lip line (3-row mean) rises back to skin, sub-pixel by linear crossing
    mrow = ls[my - 1:my + 2, :].mean(axis=0)
    skin_l, line_l = float(mrow[xm0 - 12:xm0 - 4].mean()), float(mrow[xm0:xm1].min())
    thr = 0.5 * (skin_l + line_l)
    mxc = int(round(f["mouth"][0]))

    def cross(step):
        x = mxc
        while 3 < x < W - 4 and mrow[x] < thr:
            x += step
        a, b = mrow[x - step], mrow[x]
        return x - step + step * (thr - a) / (b - a) if b != a else float(x)
    f["mouth_l"], f["mouth_r"] = cross(-1), cross(1)
    # eyebrow: darkest 3-row band above each eye in the pupil column
    bys = []
    for (ex, ey_) in eyes:
        colp = ls[ey_ - 11:ey_ - 3, ex - 1:ex + 2].mean(axis=1)      # stops 3 rows above the pupil: the lash line is not a brow
        bys.append(ey_ - 11 + int(colp.argmin()))
    f["brow_y"] = (bys[0] + bys[1]) / 2.0
    col = ls[:, 55:75].mean(axis=1)
    f["hair_y"] = int(np.argmax(col > 0.28))
    ears = {}
    for nm, (x0, x1) in (("ear_l", (10, 36)), ("ear_r", (94, 120))):
        m = skin[62:104, x0:x1]
        ys, xs = np.nonzero(m)
        assert m.sum() > 300, "%s: only %d skin px in the ear box" % (nm, m.sum())
        ears[nm] = (x0 + xs.mean(), 62 + ys.mean())
        ears[nm + "_outer"] = float(x0 + (xs.max() if nm == "ear_r" else xs.min()))
    f.update(ears)
    # ear/cheek crease: darkest column between the cheek and each ear centroid over the ear rows
    for nm, sgn in (("ear_r", -1), ("ear_l", 1)):
        ex_, ey_ = int(round(ears[nm][0])), int(round(ears[nm][1]))
        cols = list(range(ex_ + sgn * 15, ex_ + sgn * 4, -sgn)) if sgn < 0 else list(range(ex_ + 5, ex_ + 16))
        prof = [float(ls[ey_ - 13:ey_ + 13, x].mean()) for x in cols]
        f[nm + "_inner"] = float(cols[int(np.argmin(prof))])
    # regions the non-front groups will sample - assert they are what they must be
    def region(y0, y1, x0, x1):
        b = a[y0:y1, x0:x1]
        l = lum[y0:y1, x0:x1]
        s = skin[y0:y1, x0:x1].mean()
        return dict(rgb=tuple(round(float(v), 3) for v in b.reshape(-1, 3).mean(0)),
                    lum=round(float(l.mean()), 3), skin=round(float(s), 2))
    f["hair_band"] = region(14, 35, 23, 105)
    f["hair_dome"] = region(8, 31, 33, 95)
    f["under_ear_r"] = region(102, 127, 98, 113)
    f["under_ear_l"] = region(102, 127, 17, 32)
    f["neck"] = region(131, 150, 38, 90)
    assert f["hair_band"]["lum"] < 0.2 and f["hair_band"]["skin"] < 0.05, f["hair_band"]
    assert f["hair_dome"]["lum"] < 0.2 and f["hair_dome"]["skin"] < 0.05, f["hair_dome"]
    assert f["under_ear_r"]["skin"] > 0.9 and f["under_ear_l"]["skin"] > 0.9, (f["under_ear_r"], f["under_ear_l"])
    assert f["neck"]["skin"] > 0.95 and f["neck"]["lum"] > 0.45, f["neck"]
    assert 60 < ey < 85 and 95 < my < 120 and 120 < f["chin_y"] < 135 and 30 < f["hair_y"] < 48, f
    return f


# ----------------------------------------------------------------------------------------------
# mesh side
# ----------------------------------------------------------------------------------------------
# the canonical head's feature vertices (grunt_head indices; positions asserted below)
V_CHIN, V_NOSE, V_BROW, V_EAR_R, V_EAR_L = 14, 29, 24, 3, 17
CANON = {14: (0.0, -0.1098, 1.5677), 29: (0.0, -0.1317, 1.6369), 24: (0.0, -0.1305, 1.7413),
         3: (0.0774, -0.0236, 1.6565), 17: (-0.0774, -0.0236, 1.6565)}


def head_frame(o):
    """world -> canonical head frame (rig at origin, z up, -y forward)."""
    off = o.parent.matrix_world.translation.copy() if o.parent else Vector((0, 0, 0))
    M = o.matrix_world

    def co(v):
        return M @ v.co - off
    N = M.to_3x3().inverted().transposed()

    def nrm(p):
        return (N @ p.normal).normalized()
    return co, nrm


def classify(p, n, c, zmax, body):
    if body and zmax < 1.60:     # joined bodies only: the neck tops out at z 1.591. A head object has no neck, and the
        return "NECK"            # cutscene heads' chin quads sit entirely below 1.60 (v14 is at 1.5677)
    if n.z > 0.85:
        return "TOP"
    if abs(n.x) > 0.85 and n.y < 0:
        return "SIDE"
    if abs(n.x) > 0.85 and n.y > 0 and c.z < 1.72:
        return "EAR"
    if n.y < -0.5:
        return "FRONT"
    if n.y > 0.5 and n.z < -0.3:
        return "LOWER"
    return "HAIR"


def coord_hash(me):
    h = hashlib.sha1()
    for v in me.vertices:
        h.update(("%.7f %.7f %.7f" % tuple(v.co)).encode())
    return h.hexdigest()[:12]


def solve_affine(feat, pts):
    """rows: py = tz - sz*z  (chin, nose tip, brow, ear L/R);  cols: px = cx + sx*x."""
    A, b = [], []
    for key, (x, y, z) in pts.items():
        tx, ty = feat[key]
        A.append([1.0, -z]); b.append(ty + 0.5)
    (tz, sz), *_ = np.linalg.lstsq(np.array(A), np.array(b), rcond=None)
    A, b = [], []
    for key, (x, y, z) in pts.items():
        tx, ty = feat[key]
        A.append([1.0, x]); b.append(tx + 0.5)
    (cx, sx), *_ = np.linalg.lstsq(np.array(A), np.array(b), rcond=None)
    return dict(sx=float(sx), cx=float(cx), sz=float(sz), tz=float(tz))


def solve_front(o, label):
    """Measure the painted cell this head samples and solve the FRONT projection (affine + side shear).
    Returns everything project_mesh needs; th_face.py uses the same closures to put feature rows on the paint."""
    me = o.data
    uv = me.uv_layers.active.data
    fi = [i for i, m in enumerate(me.materials) if m and m.name.startswith("face_atlas")]
    assert fi, label + ": no face_atlas material"
    img = img_of(me.materials[fi[0]])
    W, H = img.size
    A = pixels_topdown(img)
    co, nrm = head_frame(o)
    # feature verts: find by POSITION (the body's indices differ from the head's)
    feat_v = {}
    for k, want in CANON.items():
        best = min(me.vertices, key=lambda v: (co(v) - Vector(want)).length)
        d = (co(best) - Vector(want)).length
        assert d < 0.002, "%s: canonical vert %d not found (nearest %.4f m)" % (label, k, d)
        feat_v[k] = best.index
    # head polys and their cell (from where the CURRENT island sits)
    face_polys = [p for p in me.polygons if p.material_index in fi]
    head = [p for p in face_polys if co_center(co, me, p).z > 1.45 and abs(co_center(co, me, p).x) < 0.12]
    head_idx = {p.index for p in head}
    us = [uv[l].uv.x for p in head for l in p.loop_indices]
    vs = [uv[l].uv.y for p in head for l in p.loop_indices]
    col, row_b, x0, y0, cw, ch = cell_rect(us, vs, W, H)
    block = A[y0:y0 + ch, x0:x0 + cw]
    assert block[..., :3].std() > 0.05, label + ": cell block is flat - wrong rect"
    feat = measure_cell(block)
    pts = {"chin": co(me.vertices[feat_v[V_CHIN]]), "nose_tip": co(me.vertices[feat_v[V_NOSE]]),
           "brow": co(me.vertices[feat_v[V_BROW]]), "ear_r": co(me.vertices[feat_v[V_EAR_R]]),
           "ear_l": co(me.vertices[feat_v[V_EAR_L]])}
    feat["chin"] = (feat["mouth"][0], feat["chin_y"])
    feat["brow"] = ((feat["eye_l"][0] + feat["eye_r"][0]) / 2.0, feat["hair_y"])
    aff = solve_affine(feat, {k: tuple(v) for k, v in pts.items()})
    sx, cx, sz, tz = aff["sx"], aff["cx"], aff["sz"], aff["tz"]

    Y0 = -0.1155                      # y of the front quads' outer verts = the face plane

    def front(v):
        return cx + sx * v.x, tz - sz * v.z

    # SIDE: the face outline column at this height (canonical edge chain v1 -> v10 -> v7), 8 px inside = cheek skin
    EDGE = [(1.5787, 0.0313), (1.6402, 0.0499), (1.7324, 0.0614)]
    CHEEK_IN = 8.0

    def x_outline(z):
        if z <= EDGE[0][0]:
            return EDGE[0][1]
        if z >= EDGE[-1][0]:
            return EDGE[-1][1]
        for (z0, xa), (z1, xb) in zip(EDGE, EDGE[1:]):
            if z0 <= z <= z1:
                return xa + (z - z0) / (z1 - z0) * (xb - xa)

    def side(v):
        if v.y < -0.06:               # a face-edge vertex: the FRONT value, so the seam is exact
            return front(v)
        sgn = 1.0 if v.x > 0 else -1.0
        return cx + sgn * (sx * x_outline(v.z) - CHEEK_IN), tz - sz * v.z

    # EAR: column by depth on the rear-side polys. Widest ring (y_ring) -> the ear/cheek crease + 2 px; the rear
    # verts (y_rear) -> the cell's usable edge. Rows: the face's own vertical affine, so the ear sits level with the
    # painted ear (between the eye line and the nose base).
    ear_verts = [co(me.vertices[i]) for p in head for i in p.vertices
                 if classify(p, nrm(p), co_center(co, me, p), max(co(me.vertices[j]).z for j in p.vertices), False) == "EAR"]
    y_ring = min(v.y for v in ear_verts) if ear_verts else -0.0242
    y_rear = max(v.y for v in ear_verts) if ear_verts else 0.0569
    a_r = (feat["ear_r_inner"] + 0.5 - cx) + 2.0
    a_l = (cx - (feat["ear_l_inner"] + 0.5)) + 2.0
    k_r = (cw - 3.5 - cx - a_r) / (y_rear - y_ring)
    k_l = (cx - a_l - 3.5) / (y_rear - y_ring)

    def ear(v):
        if v.x > 0:
            return cx + a_r + k_r * (v.y - y_ring), tz - sz * v.z
        return cx - a_l - k_l * (v.y - y_ring), tz - sz * v.z
    # where the painted ear centroid lands on the head (depth), per side
    y_ec = {"R": y_ring + (feat["ear_r"][0] + 0.5 - cx - a_r) / k_r, "L": y_ring + (cx - a_l - feat["ear_l"][0] - 0.5) / k_l}
    ear_w_mm = {"R": (feat["ear_r_outer"] - feat["ear_r_inner"]) / k_r * 1000, "L": (feat["ear_l_inner"] - feat["ear_l_outer"]) / k_l * 1000}
    return dict(me=me, uv=uv, fi=fi, img=img, W=W, H=H, co=co, nrm=nrm, feat=feat, pts=pts, feat_v=feat_v,
                head=head, head_idx=head_idx, col=col, row_b=row_b, x0=x0, y0=y0, cw=cw, ch=ch,
                sx=sx, cx=cx, sz=sz, tz=tz, K=0.0, k_r=k_r, k_l=k_l, Y0=Y0, front=front, side=side, ear=ear, aff=aff,
                y_ring=y_ring, y_rear=y_rear, y_ec=y_ec, ear_w_mm=ear_w_mm)


def project_mesh(o, label):
    assert bpy.context.mode == 'OBJECT'
    S_ = solve_front(o, label)
    me, uv, fi, img, W, H, co, nrm, feat, pts = (S_[k] for k in ("me", "uv", "fi", "img", "W", "H", "co", "nrm", "feat", "pts"))
    head, head_idx, col, row_b, x0, y0, cw, ch = (S_[k] for k in ("head", "head_idx", "col", "row_b", "x0", "y0", "cw", "ch"))
    sx, cx, sz, tz, K, k_r, k_l, Y0, front, aff = (S_[k] for k in ("sx", "cx", "sz", "tz", "K", "k_r", "k_l", "Y0", "front", "aff"))
    side, ear, y_ec, ear_w_mm = (S_[k] for k in ("side", "ear", "y_ec", "ear_w_mm"))

    # group extents for the secondary projections come from the canonical head, not the mesh
    def top(v):      # crown, x in +-0.0701, y in [-0.0902, 0.0340] -> cols 33.5..93.5, rows 8.5..30.5
        return cx + v.x * (30.0 / 0.0701), 8.5 + (v.y + 0.0902) / (0.0340 + 0.0902) * 22.0

    def hair(v):     # back/rear-side, z 1.6565..1.7906 -> rows 34.5..14.5, x +-0.0811 -> cols 23.5..103.5
        return cx + v.x * (40.0 / 0.0811), 34.5 - (v.z - 1.6565) / (1.7906 - 1.6565) * 20.0

    def lower(v, side):   # under-ear skin strip: y -0.0236..0.0716 -> 14 px outward, z 1.5866..1.6643 -> rows 126.5..102.5
        t = (v.y + 0.0236) / (0.0716 + 0.0236)
        px = (98.5 + t * 14.0) if side > 0 else (31.5 - t * 14.0)
        return px, 126.5 - (v.z - 1.5866) / (1.6643 - 1.5866) * 24.0

    def neck(v):     # painted neck rows 131.5..149.5 for z 1.591..1.507, x +-0.075 -> +-26 px
        return cx + v.x * (26.0 / 0.075), 131.5 + (1.591 - v.z) / (1.591 - 1.507) * 18.0

    before = coord_hash(me)
    n_polys, n_loops = len(me.polygons), len(me.loops)
    untouched_uv = {}
    groups = {}
    for p in me.polygons:
        if p.material_index not in fi or p.index not in head_idx:
            for l in p.loop_indices:
                untouched_uv[l] = uv[l].uv.copy()
            continue
        n = nrm(p)
        c = co_center(co, me, p)
        zmax = max(co(me.vertices[i]).z for i in p.vertices)
        g = classify(p, n, c, zmax, label.startswith("us_grunt_joined"))
        groups.setdefault(g, []).append(p.index)
        sd = 1 if c.x >= 0 else -1
        for l in p.loop_indices:
            v = co(me.vertices[me.loops[l].vertex_index])
            if g == "FRONT":
                px, py = front(v)
            elif g == "SIDE":
                px, py = side(v)
            elif g == "EAR":
                px, py = ear(v)
            elif g == "TOP":
                px, py = top(v)
            elif g == "HAIR":
                px, py = hair(v)
            elif g == "LOWER":
                px, py = lower(v, sd)
            else:
                px, py = neck(v)
            assert BORDER_X <= px <= cw and 0 <= py <= BORDER_Y, \
                "%s: poly %d (%s) loop lands at cell px (%.1f,%.1f) - outside the safe rect" % (label, p.index, g, px, py)
            uv[l].uv = ((x0 + px) / W, 1.0 - (y0 + py) / H)
    # ---- gates
    assert coord_hash(me) == before, label + ": VERTEX DATA CHANGED"
    assert (len(me.polygons), len(me.loops)) == (n_polys, n_loops)
    for l, old in untouched_uv.items():
        assert uv[l].uv == old, label + ": untouched loop %d moved" % l
    outside = 0
    for p in head:
        for l in p.loop_indices:
            u, v_ = uv[l].uv
            px, py = u * W - x0, (1.0 - v_) * H - y0
            if not (0 <= px <= cw and 0 <= py <= ch):
                outside += 1
    assert outside == 0, label + ": %d loops outside the cell" % outside
    # ear gates: no SIDE loop samples ear paint (the crease column is the limit), the painted ear centroid lands
    # behind the jaw corner (v2/v16, y -0.0213) and between 50% and 70% of the head's depth from the face plane
    on_ear = 0
    for pi in groups.get("SIDE", []):
        for l in me.polygons[pi].loop_indices:
            px, py = uv[l].uv.x * W - x0, (1.0 - uv[l].uv.y) * H - y0
            vx = co(me.vertices[me.loops[l].vertex_index]).x
            in_rows = abs(py - (feat["ear_r"][1] if vx > 0 else feat["ear_l"][1])) < 22        # the painted ear's rows
            if in_rows and ((px > feat["ear_r_inner"] + 0.5) if vx > 0 else (px < feat["ear_l_inner"] + 0.5)):
                on_ear += 1
    assert on_ear == 0, label + ": %d side loops on ear paint" % on_ear
    jaw_y = -0.0213                                            # v2 / v16, the jaw corner
    depth_frac = {k: (y - Y0) / (0.0745 - Y0) for k, y in y_ec.items()}
    for k, y in y_ec.items():
        assert y > jaw_y and 0.50 <= depth_frac[k] <= 0.70, (label, k, y, depth_frac[k])
    # residuals in cell px (target pixel centre vs projected vertex); ears report the ear map, not the front one
    res = {}
    for k, v in pts.items():
        if k.startswith("ear"):
            continue                    # the widest verts are the ear's FRONT edge by design, not a centroid fit
        px, py = front(v)
        tx, ty = feat[k][0] + 0.5, feat[k][1] + 0.5
        res[k] = (round(px - tx, 2), round(py - ty, 2))
    # where the painted eyes / mouth land on the mesh (no vertex there - report the landing)
    ez = (tz - (feat["eye_l"][1] + 0.5)) / sz
    ex = ((feat["eye_l"][0] + 0.5) - cx) / sx, ((feat["eye_r"][0] + 0.5) - cx) / sx
    mz = (tz - (feat["mouth"][1] + 0.5)) / sz
    # stretch: UV px area / world area relative to the front quads, per group
    def px_area(p):
        pts2 = [((uv[l].uv.x * W), (uv[l].uv.y * H)) for l in p.loop_indices]
        s = 0.0
        for i in range(len(pts2)):
            x1, y1 = pts2[i]; x2, y2 = pts2[(i + 1) % len(pts2)]
            s += x1 * y2 - x2 * y1
        return abs(s) / 2.0

    def w_area(p):
        vs_ = [co(me.vertices[i]) for i in p.vertices]
        s = Vector((0, 0, 0))
        for i in range(len(vs_)):
            s += vs_[i].cross(vs_[(i + 1) % len(vs_)])
        return s.length / 2.0
    ref = sx * sz  # px^2 per m^2 of a perfectly front-facing poly
    stretch = {}
    for g, idxs in groups.items():
        r = [px_area(me.polygons[i]) / max(w_area(me.polygons[i]), 1e-9) / ref for i in idxs]
        stretch[g] = (round(min(r), 2), round(max(r), 2))
    print("%-26s cell col %d row_b %d (atlas px x%d y%d)  affine sx %.1f sz %.1f px/m cx %.1f tz %.1f"
          % (label, col, row_b, x0, y0, sx, sz, cx, tz))
    print("   painted: eyes %s %s  nose_tip %s  mouth %s  chin_y %d  hair_y %d  ears %s %s"
          % (feat["eye_l"], feat["eye_r"], tuple(round(x, 1) for x in feat["nose_tip"]), feat["mouth"],
             feat["chin_y"], feat["hair_y"], tuple(round(x, 1) for x in feat["ear_l"]), tuple(round(x, 1) for x in feat["ear_r"])))
    print("   residual px (dx,dy): " + "  ".join("%s %s" % (k, v) for k, v in res.items()))
    print("   ears: crease cols %.0f / %.0f, ear map %.0f / %.0f px/m over y %.4f..%.4f; painted ear centroid lands at y %+.4f / %+.4f "
          "(%.0f%% / %.0f%% of head depth from the face plane; jaw corner y -0.0213; before this fix -0.0645 = 27%%), ear %.0f / %.0f mm wide on the head"
          % (feat["ear_r_inner"], feat["ear_l_inner"], k_r, k_l, S_["y_ring"], S_["y_rear"], y_ec["R"], y_ec["L"],
             depth_frac["R"] * 100, depth_frac["L"] * 100, ear_w_mm["R"], ear_w_mm["L"]))
    print("   painted eyes land at z %.4f (%.0f%% chin->crown), x %.4f/%.4f; mouth at z %.4f (%.0f%% chin->nose)"
          % (ez, (ez - 1.5677) / (1.7999 - 1.5677) * 100, ex[0], ex[1], mz, (mz - 1.5677) / (1.6369 - 1.5677) * 100))
    print("   groups: %s   texel-density ratio vs front (min,max): %s"
          % ({g: len(v) for g, v in groups.items()}, stretch))
    print("   regions: hair_band %s  under_ear_r %s  neck %s" % (feat["hair_band"], feat["under_ear_r"], feat["neck"]))
    return dict(groups={g: len(v) for g, v in groups.items()}, res=res, aff=aff, cell=(col, row_b),
                ear_centroid_y=y_ec, ear_depth_fraction=depth_frac, ear_width_mm=ear_w_mm, ear_before_y=-0.0645)


def co_center(co, me, p):
    c = Vector((0, 0, 0))
    for i in p.vertices:
        c += co(me.vertices[i])
    return c / len(p.vertices)


def run():
    if TALKING:
        targets = [("cs_head_michael", None), ("cs_head_gus", None)]
    else:
        targets = []
        for tag in (TAGS or ("michael", "gus_arrival", "gus_ears")):
            targets.append(("us_grunt_joined_" + tag, "grunt_head_" + tag))
    results = {}
    for body, donor in targets:
        for name in (body, donor):
            if name is None:
                continue
            o = D.objects.get(name)
            assert o is not None, "MISSING " + name
            results[name] = project_mesh(o, name)
    # the body and its donor must classify identically (same geometry, different cells)
    for body, donor in targets:
        if donor:
            assert results[body]["groups"] == {**results[donor]["groups"], "NECK": 20}, (results[body]["groups"], results[donor]["groups"])
            assert results[donor]["groups"] == {"FRONT": 6, "SIDE": 6, "EAR": 6, "TOP": 4, "HAIR": 6, "LOWER": 2}, results[donor]["groups"]
        else:
            g = results[body]["groups"]
            assert (g["TOP"], g["HAIR"], g["LOWER"], g["EAR"]) == (4, 6, 2, 6) and g["SIDE"] >= 6 and "NECK" not in g, g
    return results


if __name__ == "__main__":
    run()
    if SAVE:
        bpy.context.preferences.filepaths.save_version = 0     # no .blend1 (Caleb's rule)
        bpy.ops.wm.save_mainfile(filepath=D.filepath)
        print("SAVED", D.filepath)
    else:
        print("DRY RUN (no --save)")
