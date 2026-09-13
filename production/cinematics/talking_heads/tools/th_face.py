"""th_face.py - the cutscene face patch for cs_head_<name>: a mouth with two concentric loops around the lip edge
(4-poles at the lip corners, the outer loop's corners are the 5-poles under the nose wings), a dark cavity behind the
lips with an upper and lower teeth strip and a 2-quad tongue, blink/brow rows on the painted eyes, and the nine
Rhubarb visemes A B C D E F G H X (+ blink, blink_L, blink_R, brow_up, brow_down) as shape keys.

Every feature row/column is placed by the PAINTED cell: tools/project_cow_head_uvs.solve_front gives the affine+shear
that maps head space to cell pixels, and each vertex is solved onto the bilinear face patch so that it projects to its
painted pixel (mouth line, lip corners, nostril row, pupils, eyebrows). After the head is re-projected the gates read
the UVs back and compare to the paint, so the chain vertex -> UV -> paint is measured, not assumed.

Frame: head-local = rig-local (rig at the origin), Z up, the face toward -Y, the character's LEFT is +X.
Side suffix in vertex names is the MESH side ('L' = x < 0 = the character's right); the blink_L/blink_R keys are named
by the CHARACTER's own left/right.
"""
import math
import bmesh
from mathutils import Vector

VISEMES = "ABCDEFGHX"
# Rhubarb cue -> skull jaw angle (deg about the jaw bone's hinge axis)
JAW_DEG = {"X": 0.0, "A": 0.0, "G": 2.0, "B": 4.0, "F": 5.0, "E": 7.0, "H": 8.0, "C": 11.0, "D": 18.0}
EYE_KEYS = ("blink", "blink_L", "blink_R", "brow_up", "brow_down")

# face patch = the 4 front quads of the game head, a 3x3 vertex grid; (s,t) in [0,1]^2, s: -x..+x, t: neck ring..hairline
GRID3 = [[15, 14, 1], [30, 29, 10], [26, 24, 7]]
NECK_RING = [14, 1, 2, 11, 31, 32, 16, 15]
FACE_POLYS = [(14, 1, 10, 29), (29, 10, 7, 24), (14, 29, 30, 15), (29, 24, 26, 30)]

# viseme recipe: J jaw drop mm, U upper-lip raise mm, Lx lower-lip extra drop mm, W corner width change mm (+ wider),
# F lips forward mm (pucker), press = lips pressed (A), tuck = lower lip under the upper teeth (G), tongue = tip up (H)
VISEME_PARAMS = {
    "X": dict(),
    "A": dict(press=1.0, W=-1.0),
    "B": dict(U=2.5, Lx=3.0, W=1.0),
    "C": dict(J=8.0, U=3.0, Lx=3.0, W=2.0),
    "D": dict(J=16.0, U=4.0, Lx=3.0, W=1.0),
    "E": dict(J=6.0, U=2.0, Lx=2.0, W=-3.0, F=2.0),
    "F": dict(J=3.5, U=0.5, Lx=1.0, W=-7.0, F=4.5),
    "G": dict(J=2.0, U=3.0, tuck=1.0),
    "H": dict(J=7.0, U=3.0, Lx=3.0, W=1.0, tongue=1.0),
}
TEETH_DEPTH, TEETH_H, BACK_DEPTH = 0.007, 0.009, 0.022     # m behind the lip line; teeth strip height; back wall depth


def bilerp(grid, s, t):
    """grid[r][c] -> value; piecewise bilinear over the 2x2 quads of a 3x3 grid."""
    ci = 0 if s <= 0.5 else 1
    ri = 0 if t <= 0.5 else 1
    ls = (s - 0.5 * ci) / 0.5
    lt = (t - 0.5 * ri) / 0.5
    a, b, c, d = grid[ri][ci], grid[ri][ci + 1], grid[ri + 1][ci], grid[ri + 1][ci + 1]
    return (a * (1 - ls) + b * ls) * (1 - lt) + (c * (1 - ls) + d * ls) * lt


def solve_st(G_co, front, px, py, s=None, t=None):
    """(s,t) on the patch whose front projection is (px,py). Alternating bisection (z is monotonic in t, px in s);
    a fixed s or t pins the vertex to a patch edge. Returns (s, t, residual_px)."""
    fs, ft = s, t
    s = 0.5 if fs is None else fs
    t = 0.5 if ft is None else ft
    for _ in range(8):
        if ft is None:
            lo, hi = 0.0, 1.0
            for _ in range(40):
                t = 0.5 * (lo + hi)
                if front(bilerp(G_co, s, t))[1] > py:      # py grows downward: too low on the face -> raise t
                    lo = t
                else:
                    hi = t
        if fs is None:
            lo, hi = 0.0, 1.0
            for _ in range(40):
                s = 0.5 * (lo + hi)
                if front(bilerp(G_co, s, t))[0] < px:
                    lo = s
                else:
                    hi = s
    qx, qy = front(bilerp(G_co, s, t))
    res = math.hypot(qx - px, qy - py) if (fs is None and ft is None) else (abs(qy - py) if ft is None else abs(qx - px))
    return s, t, res


def layout(S):
    """Vertex table in cell pixels from the measured paint. Returns (verts, rows) where verts = {name: (px, py, kind)},
    kind in {'in', 'edge', 'top', 'centre'}. rows = the measured feature rows for the report."""
    f = S["feat"]
    cx, co, me, front = S["cx"], S["co"], S["me"], S["front"]
    lip = f["mouth"][1] + 0.5                       # dark mouth line, pixel centre
    mx = 0.5 * (f["mouth_l"] + f["mouth_r"])        # painted mouth centre (may sit ~1 px off the mesh centre line)
    hw = 0.5 * (f["mouth_r"] - f["mouth_l"])        # painted mouth half-width
    ny = f["nostril_y"] + 0.5
    v15_py = front(co(me.vertices[15]))[1]
    chin_py = v15_py - 2.5
    eyes = {"L": f["eye_l"], "R": f["eye_r"]}
    ecx = 0.5 * (f["eye_l"][0] + f["eye_r"][0]) + 0.5
    V = {}

    def add(name, px, py, kind="in"):
        V[name] = (px, py, kind)
    # ---- mouth rings (ring 2 outer loop, ring 1 vermilion border, ring 0 lip line)
    for sd, sg in (("L", -1.0), ("R", 1.0)):
        add(f"L2_{sd}", mx + sg * (hw + 7.0), lip)
        add(f"T2a_{sd}", mx + sg * (hw + 7.0), ny)
        add(f"T2b_{sd}", mx + sg * (hw - 1.5), ny)
        add(f"B2a_{sd}", mx + sg * (hw + 5.0), lip + 9.5)
        add(f"B2b_{sd}", mx + sg * (hw - 1.5), lip + 9.5)
        add(f"L1_{sd}", mx + sg * hw, lip)
        add(f"T1a_{sd}", mx + sg * (hw - 1.0), lip - 2.0)
        add(f"T1b_{sd}", mx + sg * hw * 0.5, lip - 3.0)
        add(f"B1a_{sd}", mx + sg * (hw - 1.0), lip + 2.0)
        add(f"B1b_{sd}", mx + sg * hw * 0.5, lip + 3.0)
        add(f"U0b_{sd}", mx + sg * hw * 0.5, lip)
        add(f"D0b_{sd}", mx + sg * hw * 0.5, lip)
        add(f"C_{sd}", mx + sg * (hw - 1.5), chin_py)
        add(f"E_m_{sd}", 0.0, lip, "edge")
    add("T1c", mx, lip - 3.0)
    add("B1c", mx, lip + 3.0)
    add("U0c", mx, lip)
    add("D0c", mx, lip)
    add("B2c", mx, lip + 9.5)
    add("Cc", mx, chin_py)
    # ---- eyes / brow / top: pupils + corners at +-6 px, lids at -3.5/+2.5 px of the pupil row, brow at least 3 px above the lid
    ul_rows, ll_rows, br_rows = {}, {}, {}
    for sd, sg in (("L", -1.0), ("R", 1.0)):
        ex, ey = eyes[sd]
        ex, ey = ex + 0.5, ey + 0.5
        ul, ll = ey - 3.5, ey + 2.5
        br = min(f["brow_y"] + 0.5 - 0.5, ul - 3.0)
        ul_rows[sd], ll_rows[sd], br_rows[sd] = ul, ll, br
        cols = {"c1": ex + sg * 6.0, "c2": ex, "c3": ex - sg * 6.0}
        for c, px in cols.items():
            add(f"{c}ll_{sd}", px, ll)
            add(f"{c}ul_{sd}", px, ul)
            add(f"{c}br_{sd}", px, br)
            add(f"{c}top_{sd}", px, 0.0, "top")
        add(f"E_ll_{sd}", 0.0, ll, "edge")
        add(f"E_ul_{sd}", 0.0, ul, "edge")
        add(f"E_br_{sd}", 0.0, br, "edge")
    add("c4ll", cx, 0.5 * (ll_rows["L"] + ll_rows["R"]), "centre")
    add("c4ul", cx, 0.5 * (ul_rows["L"] + ul_rows["R"]), "centre")
    add("c4br", cx, 0.5 * (br_rows["L"] + br_rows["R"]), "centre")
    rows = dict(lip_py=lip, mouth_cx=mx, mouth_hw_px=hw, nostril_py=ny, chin_py=chin_py, v15_py=v15_py,
                eye_L=eyes["L"], eye_R=eyes["R"], ul=ul_rows, ll=ll_rows, brow=br_rows, brow_y_painted=f["brow_y"])
    return V, rows


# faces of the patch, by vertex name; '{S}' is expanded per side. Existing verts: v15 v14 v1 v30 v29 v10 v26 v24 v7.
SIDE_QUADS = [
    ("E_m_{S}", "L2_{S}", "T2a_{S}", "v30_{S}"),
    ("E_m_{S}", "L2_{S}", "B2a_{S}", "v15_{S}"),
    ("v15_{S}", "B2a_{S}", "B2b_{S}", "C_{S}"),
    ("C_{S}", "B2b_{S}", "B2c", "Cc"),
    ("v15_{S}", "C_{S}", "Cc", "v14"),
    ("v30_{S}", "T2a_{S}", "c1ll_{S}", "E_ll_{S}"),
    ("T2a_{S}", "T2b_{S}", "c2ll_{S}", "c1ll_{S}"),
    ("T2b_{S}", "v29", "c4ll", "c3ll_{S}"),
    ("E_ll_{S}", "c1ll_{S}", "c1ul_{S}", "E_ul_{S}"),
    ("c1ll_{S}", "c2ll_{S}", "c2ul_{S}", "c1ul_{S}"),
    ("c2ll_{S}", "c3ll_{S}", "c3ul_{S}", "c2ul_{S}"),
    ("c3ll_{S}", "c4ll", "c4ul", "c3ul_{S}"),
    ("E_ul_{S}", "c1ul_{S}", "c1br_{S}", "E_br_{S}"),
    ("c1ul_{S}", "c2ul_{S}", "c2br_{S}", "c1br_{S}"),
    ("c2ul_{S}", "c3ul_{S}", "c3br_{S}", "c2br_{S}"),
    ("c3ul_{S}", "c4ul", "c4br", "c3br_{S}"),
    ("E_br_{S}", "c1br_{S}", "c1top_{S}", "v26_{S}"),
    ("c1br_{S}", "c2br_{S}", "c2top_{S}", "c1top_{S}"),
    ("c2br_{S}", "c3br_{S}", "c3top_{S}", "c2top_{S}"),
    ("c3br_{S}", "c4br", "v24", "c3top_{S}"),
    # upper lip / lower lip (lip line <-> ring 1)
    ("L1_{S}", "T1a_{S}", "T1b_{S}", "U0b_{S}"),
    ("U0b_{S}", "T1b_{S}", "T1c", "U0c"),
    ("L1_{S}", "D0b_{S}", "B1b_{S}", "B1a_{S}"),
    ("D0b_{S}", "D0c", "B1c", "B1b_{S}"),
]
SIDE_TRIS = [("T2b_{S}", "c3ll_{S}", "c2ll_{S}")]          # the one triangle per side: nostril wing -> inner eye corner
RING2 = ["L2_L", "T2a_L", "T2b_L", "v29", "T2b_R", "T2a_R", "L2_R", "B2a_R", "B2b_R", "B2c", "B2b_L", "B2a_L"]
RING1 = ["L1_L", "T1a_L", "T1b_L", "T1c", "T1b_R", "T1a_R", "L1_R", "B1a_R", "B1b_R", "B1c", "B1b_L", "B1a_L"]
UPPER_EDGE = ["L1_L", "U0b_L", "U0c", "U0b_R", "L1_R"]
LOWER_EDGE = ["L1_L", "D0b_L", "D0c", "D0b_R", "L1_R"]
EXISTING = {"v15_L": 15, "v15_R": 1, "v14": 14, "v30_L": 30, "v30_R": 10, "v29": 29, "v26_L": 26, "v26_R": 7, "v24": 24}
# neighbours whose patch-boundary edge gets split: (poly vert set, (a, b, [mid names in a->b order]))
NEIGHBOURS = [
    ((15, 30, 17, 16), (15, 30, ["E_m_L"])),
    ((30, 26, 28, 17), (30, 26, ["E_ll_L", "E_ul_L", "E_br_L"])),
    ((1, 2, 3, 10), (10, 1, ["E_m_R"])),
    ((10, 3, 9, 7), (7, 10, ["E_br_R", "E_ul_R", "E_ll_R"])),
    ((24, 23, 22, 26), (26, 24, ["c1top_L", "c2top_L", "c3top_L"])),
    ((24, 7, 6, 23), (24, 7, ["c3top_R", "c2top_R", "c1top_R"])),
]


def role_of(name):
    """(role, lateral index i in -2..2, side sign) for the viseme rules; None for verts the mouth never moves."""
    sg = -1.0 if name.endswith("_L") else (1.0 if name.endswith("_R") else 0.0)
    base = name[:-2] if name.endswith(("_L", "_R")) else name
    idx = {"a": 2, "b": 1, "c": 0}
    if base in ("U0b", "U0c"):
        return "lipU", int(idx[base[-1]] * sg) if sg else 0, sg
    if base in ("D0b", "D0c"):
        return "lipD", int(idx[base[-1]] * sg) if sg else 0, sg
    if base == "L1":
        return "corner", int(2 * sg), sg
    if base == "L2":
        return "L2", int(2 * sg), sg
    for r in ("T1", "B1", "T2", "B2"):
        if base.startswith(r):
            return r, int(idx[base[-1]] * sg) if sg else 0, sg
    if base in ("C", "Cc"):
        return "C", int(sg), sg
    if base == "E_m":
        return "E_m", int(2 * sg), sg
    if base.startswith("UT"):
        return "UT", 0, sg
    if base.startswith("LT"):
        return "LT", 0, sg
    if base.startswith("TGf"):
        return "TGf", 0, sg
    if base.startswith("TGb"):
        return "TGb", 0, sg
    if base.startswith("BW"):
        return "BW", 0, sg
    return None


def viseme_disp(role, i, sg, P, rest, ctx):
    """Displacement (m) of one vertex under a viseme recipe P. rest = the vertex rest position, ctx = (z_m, y_lip)."""
    J, U, Lx, W, F = P.get("J", 0.0), P.get("U", 0.0), P.get("Lx", 0.0), P.get("W", 0.0), P.get("F", 0.0)
    a = abs(i)
    d = Vector((0.0, 0.0, 0.0))
    mm = 0.001
    # jaw drop (rotation about the condyle: down and a little back)
    wj = {"lipD": 1.0, "corner": 0.45, "B1": {0: 0.95, 1: 0.9, 2: 0.7}, "B2": {0: 0.8, 1: 0.75, 2: 0.55},
          "L2": 0.3, "C": 0.65, "LT": 0.85, "TGf": 0.85, "TGb": 0.85, "E_m": 0.15}.get(role, 0.0)
    if isinstance(wj, dict):
        wj = wj[a]
    d.z -= J * wj * mm
    d.y += 0.12 * J * wj * mm
    # upper lip raise
    wu = {"lipU": {0: 1.0, 1: 0.9}, "T1": {0: 0.6, 1: 0.55, 2: 0.3}, "corner": 0.15}.get(role, 0.0)
    if isinstance(wu, dict):
        wu = wu[a]
    d.z += U * wu * mm
    # lower lip extra drop (the lip peels off the lower teeth)
    wl = {"lipD": {0: 1.0, 1: 0.9}, "B1": {0: 0.4, 1: 0.35, 2: 0.15}}.get(role, 0.0)
    if isinstance(wl, dict):
        wl = wl[a]
    d.z -= Lx * wl * mm
    # corner width
    ww = {"corner": 1.0, "T1": {2: 0.85, 1: 0.45, 0: 0.0}, "B1": {2: 0.85, 1: 0.45, 0: 0.0}, "lipU": {1: 0.45, 0: 0.0},
          "lipD": {1: 0.45, 0: 0.0}, "L2": 0.5, "T2": {2: 0.25, 1: 0.1}, "B2": {2: 0.3, 1: 0.12, 0: 0.0},
          "C": {1: 0.1, 0: 0.0}}.get(role, 0.0)
    if isinstance(ww, dict):
        ww = ww[a]
    d.x += sg * W * ww * mm
    # pucker forward (-y)
    wf = {"lipU": 1.0, "lipD": 1.0, "T1": 0.8, "B1": 0.8, "corner": 0.5, "L2": 0.25, "T2": 0.2, "B2": 0.2, "C": 0.05}.get(role, 0.0)
    d.y -= F * wf * mm
    if P.get("press"):
        if role == "T1":
            d.z -= 0.8 * (1.0 - a / 3.0) * mm
        if role == "B1":
            d.z += 0.8 * (1.0 - a / 3.0) * mm
        if role in ("lipU", "lipD"):
            d.y += 2.0 * mm
    if P.get("tuck"):
        if role == "lipD":
            d.y += 4.0 * mm
            d.z += 1.5 * mm
        if role == "B1":
            d.y += 2.0 * mm
            d.z += 0.8 * mm
    if P.get("tongue"):
        z_m, y_lip = ctx
        if role == "TGf":
            d = Vector((0.0, (y_lip + 0.003) - rest.y, (z_m + 0.003) - rest.z))
        if role == "TGb":
            d = Vector((0.0, 0.0, (z_m - 0.002) - rest.z))
    return d


def build_face(obj, src, S, mouth_mat, log, REPORT, name):
    """Rebuild the 4 front quads of obj.data (a copy of src.data) as the animated face patch + cavity, add the shape
    keys. S = project_cow_head_uvs.solve_front(src). Returns the vertex-name -> index map and the layout rows."""
    me = obj.data
    front, co, G_idx = S["front"], S["co"], GRID3
    src_co = [v.co.copy() for v in src.data.vertices]
    uvl = me.uv_layers.active
    pv_uv = {}
    for p in me.polygons:
        if tuple(p.vertices) in FACE_POLYS or tuple(p.vertices)[::-1] in FACE_POLYS:
            for li, vi in zip(p.loop_indices, p.vertices):
                pv_uv[vi] = uvl.data[li].uv.copy()

    def weights(vi):
        return {obj.vertex_groups[g.group].name: g.weight for g in src.data.vertices[vi].groups}
    G_co = [[src_co[i] for i in row] for row in G_idx]
    G_uv = [[pv_uv[i] for i in row] for row in G_idx]
    gnames = sorted({n for row in G_idx for i in row for n in weights(i)})
    G_w = {n: [[weights(i).get(n, 0.0) for i in row] for row in G_idx] for n in gnames}
    face_mat_index = [p.material_index for p in me.polygons if tuple(p.vertices) in FACE_POLYS or tuple(p.vertices)[::-1] in FACE_POLYS][0]

    Vtab, rows = layout(S)
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    uv_lay = bm.loops.layers.uv.active
    dl = bm.verts.layers.deform.verify()
    gidx = {vg.name: vg.index for vg in obj.vertex_groups}
    V = {k: bm.verts[i] for k, i in EXISTING.items()}
    st_of = {V["v15_L"]: (0.0, 0.0), V["v14"]: (0.5, 0.0), V["v15_R"]: (1.0, 0.0), V["v30_L"]: (0.0, 0.5), V["v29"]: (0.5, 0.5),
             V["v30_R"]: (1.0, 0.5), V["v26_L"]: (0.0, 1.0), V["v24"]: (0.5, 1.0), V["v26_R"]: (1.0, 1.0)}

    def set_weights(v, s, t):
        for n in gnames:
            w = bilerp(G_w[n], s, t)
            if w > 1e-4:
                v[dl][gidx[n]] = w
    worst = 0.0
    for nm, (px, py, kind) in Vtab.items():
        if kind == "edge":
            s, t, res = solve_st(G_co, front, px, py, s=(0.0 if nm.endswith("_L") else 1.0))
        elif kind == "top":
            s, t, res = solve_st(G_co, front, px, py, t=1.0)
        elif kind == "centre":
            s, t, res = solve_st(G_co, front, px, py, s=0.5)
        else:
            s, t, res = solve_st(G_co, front, px, py)
        worst = max(worst, res)
        assert 0.0 <= s <= 1.0 and 0.0 <= t <= 1.0, (nm, s, t)
        v = bm.verts.new(bilerp(G_co, s, t))
        set_weights(v, s, t)
        st_of[v] = (s, t)
        V[nm] = v
    log(f"  {name}: {len(Vtab)} patch verts solved onto the paint, worst residual {worst:.3f} px")
    assert worst < 0.05, worst
    # delete the 4 face quads
    face_faces = [f for f in bm.faces if tuple(v.index for v in f.verts) in FACE_POLYS or tuple(v.index for v in f.verts)[::-1] in FACE_POLYS]
    assert len(face_faces) == 4, len(face_faces)
    bmesh.ops.delete(bm, geom=face_faces, context='FACES_ONLY')
    new_faces = []

    def face(names):
        f = bm.faces.new([V[n] for n in names])
        f.material_index = face_mat_index
        new_faces.append(f)
        return f
    for sd in ("L", "R"):
        for q in SIDE_QUADS:
            face([n.format(S=sd) for n in q])
        for tq in SIDE_TRIS:
            face([n.format(S=sd) for n in tq])
    for i in range(len(RING2)):
        face([RING2[i], RING2[(i + 1) % 12], RING1[(i + 1) % 12], RING1[i]])
    uv_of = {v: bilerp(G_uv, s, t) for v, (s, t) in st_of.items()}

    # neighbours whose boundary edges got split: rebuild them through the new boundary verts
    def rebuild(vidx_loop, insert):
        f = None
        for cand in bm.faces:
            if set(v.index for v in cand.verts) == set(vidx_loop):
                f = cand
                break
        assert f is not None, vidx_loop
        loop_verts = [v for v in f.verts]
        loop_uv = {l.vert: l[uv_lay].uv.copy() for l in f.loops}
        mat = f.material_index
        bmesh.ops.delete(bm, geom=[f], context='FACES_ONLY')
        a_idx, b_idx, mids = insert
        mids = [V[m] for m in mids]
        seq = []
        n = len(loop_verts)
        for i, v in enumerate(loop_verts):
            seq.append(v)
            nxt = loop_verts[(i + 1) % n]
            if v.index == a_idx and nxt.index == b_idx:
                seq.extend(mids)
            elif v.index == b_idx and nxt.index == a_idx:
                seq.extend(mids[::-1])
        assert len(seq) == n + len(mids), (vidx_loop, len(seq))
        nf = bm.faces.new(seq)
        nf.material_index = mat
        for l in nf.loops:
            l[uv_lay].uv = loop_uv[l.vert] if l.vert in loop_uv else uv_of[l.vert]
        new_faces.append(nf)
    for poly, ins in NEIGHBOURS:
        rebuild(poly, ins)
    for f in new_faces:
        if all(v in uv_of for v in f.verts):
            for l in f.loops:
                l[uv_lay].uv = uv_of[l.vert]

    # ---- cavity: roof + upper teeth, floor + lower teeth, side caps, back wall, tongue (mouth material)
    UE = [V[n] for n in UPPER_EDGE]
    LE = [V[n] for n in LOWER_EDGE]
    z_m = sum(v.co.z for v in UE) / 5.0
    y_lip = UE[2].co.y                                  # centre of the lip line (the tongue tip's datum)
    s_lip, t_lip = st_of[V["U0c"]]
    hw_m = rows["mouth_hw_px"] / S["sx"]

    def surf_y(x, z):
        """y of the face patch at (x, z): the face curves back 4-7 mm from the lip centre to the corners, so cavity
        depth is measured from the LOCAL surface, never from one mean (measured 2026-09-12: a mean-depth back wall
        poked 9 mm out of the jaw and the teeth ends 1 mm out of the cheek). Beyond the patch edge s clamps to the edge."""
        s_, t_, _ = solve_st(G_co, lambda v: (v.x * 1000.0, -v.z * 1000.0), x * 1000.0, -z * 1000.0)
        return bilerp(G_co, s_, t_).y

    def cav(nm, x, depth, z):
        v = bm.verts.new(Vector((x, surf_y(x, z) + depth, z)))
        set_weights(v, 0.5, t_lip)
        V[nm] = v
        return v
    UTt = [cav(f"UTt{i}", UE[i].co.x, TEETH_DEPTH, z_m + TEETH_H - 0.001) for i in range(5)]
    UTb = [cav(f"UTb{i}", UE[i].co.x, TEETH_DEPTH, z_m - 0.001) for i in range(5)]
    LTt = [cav(f"LTt{i}", LE[i].co.x, TEETH_DEPTH, z_m - 0.0015) for i in range(5)]
    LTb = [cav(f"LTb{i}", LE[i].co.x, TEETH_DEPTH, z_m - 0.0015 - TEETH_H) for i in range(5)]
    bw = hw_m + 6.0 / S["sx"]
    BW = [cav("BW0", -bw, BACK_DEPTH, z_m + 0.012), cav("BW1", bw, BACK_DEPTH, z_m + 0.012),
          cav("BW2", bw, BACK_DEPTH, z_m - 0.032), cav("BW3", -bw, BACK_DEPTH, z_m - 0.032)]
    TGf = [cav(f"TGf{i}", x, 0.009, z_m - 0.007) for i, x in enumerate((-0.008, 0.0, 0.008))]
    TGb = [cav(f"TGb{i}", x, 0.020, z_m - 0.006) for i, x in enumerate((-0.008, 0.0, 0.008))]
    # every cavity vertex must sit behind the face patch by at least 4 mm (the H tongue tip is placed by its key, not here)
    worst_in = min(V[n].co.y - surf_y(V[n].co.x, V[n].co.z) for n in V if n[:2] in ("UT", "LT", "BW", "TG"))
    log(f"  {name}: cavity depth behind the local face surface, min {worst_in * 1000:.1f} mm")
    assert worst_in >= 0.004, worst_in
    mouth_slot = [i for i, m in enumerate(me.materials) if m and m.name == mouth_mat.name][0]
    cav_faces = []

    def cface(verts, uvs):
        f = bm.faces.new(verts)
        f.material_index = mouth_slot
        for l, uv in zip(f.loops, uvs):
            l[uv_lay].uv = uv
        cav_faces.append(f)
        return f
    DARK, PINK = (0.15, 0.25), (0.8, 0.25)
    for i in range(4):
        u0, u1 = i / 4.0, (i + 1) / 4.0
        cface((UE[i], UE[i + 1], UTt[i + 1], UTt[i]), [DARK] * 4)                                   # roof (inner upper lip)
        cface((UTt[i], UTt[i + 1], UTb[i + 1], UTb[i]), [(u0, 0.97), (u1, 0.97), (u1, 0.53), (u0, 0.53)])   # upper teeth
        cface((LE[i], LE[i + 1], LTb[i + 1], LTb[i]), [DARK] * 4)                                   # floor (inner lower lip)
        cface((LTb[i], LTb[i + 1], LTt[i + 1], LTt[i]), [(u0, 0.97), (u1, 0.97), (u1, 0.53), (u0, 0.53)])   # lower teeth
    cface((UE[0], LTb[0], UTt[0]), [DARK] * 3)                                                       # side caps at the corners
    cface((UE[4], UTt[4], LTb[4]), [DARK] * 3)
    cface(tuple(BW), [DARK] * 4)                                                                     # back wall
    for i in range(2):
        cface((TGf[i], TGf[i + 1], TGb[i + 1], TGb[i]), [(0.6 + 0.35 * i / 2, 0.05), (0.6 + 0.35 * (i + 1) / 2, 0.05),
                                                       (0.6 + 0.35 * (i + 1) / 2, 0.45), (0.6 + 0.35 * i / 2, 0.45)])
    n_cav = len(cav_faces)
    # triangulate the rebuilt n-gons (side/scalp polys; flat-shaded PSX read is unchanged), consistent normals, front = -Y
    ng = [f for f in bm.faces if len(f.verts) > 4]
    bmesh.ops.triangulate(bm, faces=ng, quad_method='BEAUTY', ngon_method='BEAUTY')
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    frontf = [f for f in bm.faces if all(v in st_of for v in f.verts)]
    if sum(f.normal.y for f in frontf) > 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    # the back wall and the tongue are islands: recalc orients them by guess, so face them by measurement
    bm.normal_update()
    bwf = [f for f in cav_faces if f.verts[0] in BW]
    if bwf[0].normal.y > 0:
        bmesh.ops.reverse_faces(bm, faces=bwf)
    tgf = [f for f in cav_faces if f.verts[0] in TGf]
    if sum(f.normal.z for f in tgf) < 0:
        bmesh.ops.reverse_faces(bm, faces=tgf)
    bm.normal_update()
    teeth = [f for f in cav_faces if f.verts[0] in UTt or f.verts[0] in LTb]
    log(f"  {name}: normals - front y {sum(f.normal.y for f in frontf):+.2f}, teeth y {sum(f.normal.y for f in teeth):+.2f} "
        f"(both must be negative), back wall y {bwf[0].normal.y:+.2f}, tongue z {sum(f.normal.z for f in tgf):+.2f}")
    assert sum(f.normal.y for f in teeth) < 0 and bwf[0].normal.y < 0
    bm.verts.index_update()
    idx = {nm: v.index for nm, v in V.items()}
    n_ngons = sum(1 for f in bm.faces if len(f.verts) > 4)
    bm.to_mesh(me)
    bm.free()
    me.update()
    assert n_ngons == 0
    ctx = (z_m, y_lip)
    return idx, rows, ctx, n_cav


def add_shape_keys(obj, idx, ctx, log, REPORT, name):
    me = obj.data
    obj.shape_key_add(name="Basis", from_mix=False)
    basis = [v.co.copy() for v in me.vertices]
    roles = {}
    for nm, i in idx.items():
        r = role_of(nm)
        if r:
            roles[i] = r
    out = {}

    def add_key(kname, fn):
        kb = obj.shape_key_add(name=kname, from_mix=False)
        mx = 0.0
        for i, co in enumerate(basis):
            d = fn(i)
            if d is not None and d.length > 0:
                kb.data[i].co = co + d
                mx = max(mx, d.length)
        out[kname] = round(mx * 1000, 2)
        return kb
    for vis in VISEMES:
        P = VISEME_PARAMS[vis]
        add_key(vis, lambda i, P=P: (viseme_disp(*roles[i], P, basis[i], ctx) if i in roles else None))
    # eyes: the upper-lid row drops onto the lower-lid row (measured per column), the brow row rises/falls
    def blink_fn(sides):
        def fn(i):
            for sd in sides:
                for c in ("c1", "c2", "c3"):
                    if i == idx[f"{c}ul_{sd}"]:
                        return Vector((0.0, 0.0003, basis[idx[f"{c}ll_{sd}"]].z - basis[i].z))
            if "L" in sides and "R" in sides and i == idx["c4ul"]:
                return Vector((0.0, 0.0002, 0.6 * (basis[idx["c4ll"]].z - basis[i].z)))
            return None
        return fn
    # blink_L / blink_R are the CHARACTER's left/right: character left = +X = mesh side 'R'
    add_key("blink", blink_fn("LR"))
    add_key("blink_L", blink_fn("R"))
    add_key("blink_R", blink_fn("L"))
    up = {"c1br": 4.5, "c2br": 5.5, "c3br": 5.0, "c4br": 4.0, "c1ul": 1.2, "c2ul": 1.2, "c3ul": 1.2, "c4ul": 0.8}
    down = {"c1br": (-2.5, 0.0), "c2br": (-3.5, 1.0), "c3br": (-4.5, 1.5), "c4br": (-4.0, 0.0), "c1ul": (-0.8, 0.0), "c2ul": (-0.8, 0.0), "c3ul": (-0.8, 0.5), "c4ul": (-0.6, 0.0)}
    by_index = {}
    for nm, i in idx.items():
        base = nm[:-2] if nm.endswith(("_L", "_R")) else nm
        sg = -1.0 if nm.endswith("_L") else (1.0 if nm.endswith("_R") else 0.0)
        by_index[i] = (base, sg)
    add_key("brow_up", lambda i: Vector((0.0, 0.0, up[by_index[i][0]] * 0.001)) if i in by_index and by_index[i][0] in up else None)
    add_key("brow_down", lambda i: Vector((-by_index[i][1] * down[by_index[i][0]][1] * 0.001, -0.0005, down[by_index[i][0]][0] * 0.001))
            if i in by_index and by_index[i][0] in down else None)
    REPORT[f"shape_keys_{name}"] = out
    log(f"  {name}: shape keys (max displacement mm): {out}")
    return out


def measure_visemes(obj, idx, log, REPORT, name):
    """Numbers per viseme from the shape-key data: lip gap at the centre, lower-lip drop, mouth width, teeth visibility."""
    kb = obj.data.shape_keys.key_blocks
    basis = kb["Basis"].data
    res = {}
    w0 = (basis[idx["L1_R"]].co - basis[idx["L1_L"]].co).length
    for vis in VISEMES:
        d = kb[vis].data
        ue, le = d[idx["U0c"]].co, d[idx["D0c"]].co
        gap = (ue.z - le.z) * 1000
        drop = (basis[idx["D0c"]].co.z - le.z) * 1000
        raise_ = (ue.z - basis[idx["U0c"]].co.z) * 1000
        width = (d[idx["L1_R"]].co - d[idx["L1_L"]].co).length
        chin = (basis[idx["Cc"]].co.z - d[idx["Cc"]].co.z) * 1000
        upper_teeth_vis = (ue.z - d[idx["UTb2"]].co.z) * 1000       # upper teeth face showing below the raised upper lip
        lower_teeth_vis = (d[idx["LTt2"]].co.z - le.z) * 1000       # lower teeth face showing above the dropped lower lip
        dark = (d[idx["UTb2"]].co.z - d[idx["LTt2"]].co.z) * 1000   # back-wall gap between the tooth rows
        fwd = (basis[idx["U0c"]].co.y - d[idx["U0c"]].co.y) * 1000
        tongue = (d[idx["TGf1"]].co.z - basis[idx["TGf1"]].co.z) * 1000
        res[vis] = dict(lip_gap_mm=round(gap, 1), lower_lip_drop_mm=round(drop, 1), upper_lip_raise_mm=round(raise_, 1),
                        width_mm=round(width * 1000, 1), width_ratio=round(width / w0, 3), chin_drop_mm=round(chin, 1),
                        upper_teeth_visible_mm=round(upper_teeth_vis, 1), lower_teeth_visible_mm=round(lower_teeth_vis, 1),
                        dark_gap_mm=round(dark, 1), lips_forward_mm=round(fwd, 1), tongue_rise_mm=round(tongue, 1))
    REPORT[f"visemes_{name}"] = res
    for vis, r in res.items():
        log(f"  {name} {vis}: {r}")
    assert res["D"]["lower_lip_drop_mm"] >= 14.0 and res["D"]["chin_drop_mm"] >= 8.0, res["D"]
    assert res["F"]["width_ratio"] <= 0.70, res["F"]
    assert res["B"]["upper_teeth_visible_mm"] >= 2.0 and res["B"]["lower_teeth_visible_mm"] >= 1.0 and res["B"]["lip_gap_mm"] >= 4.0, res["B"]
    assert res["A"]["lip_gap_mm"] <= 0.1 and res["X"]["lip_gap_mm"] <= 0.1
    assert res["H"]["tongue_rise_mm"] >= 8.0, res["H"]
    return res
