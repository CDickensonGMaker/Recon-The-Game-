"""build_ww1_face_cells.py - SEVEN DIFFERENT MEN for the Conquest of Worms WW1 cast.

    python tools/build_ww1_face_cells.py [--preview]

Writes assets/ww1/characters/ww1_<tag>_face_cell.png (130x162, the CoW cell format), one per man
(Louie's two states share one cell: he is one man).

WHY (2026-09-13, Caleb: "we need to do a better job fixing up the ww1 soldiers"): the 9/12 cells were
six picks off face_atlas_v5 rows 2-3, and EVERY light-skin cell on that sheet is the same generated
template head with different hair/moustache flecks (found on Michael 9/12) - so the seven WW1 men
shipped as one face. This does for each of them what tools/build_cow_michael_face_cell.py did for
Michael: a genuinely different painted head from face_source/newfaceatlas.png (36 distinct men) is
thin-plate-spline warped so that ITS landmarks land on the template's landmark PIXELS (pupils
(49,73)/(76,73), nostril row 93, mouth line 105 with corners 52.2/72.1, chin 127-131, hairline 38)
and composited into the template frame (ears, neck, background, outer hair mass), which
tools/project_cow_head_uvs.measure_cell asserts on and the game's canonical grunt_head wrap was
authored for. Same feature placement => the head's UVs stay valid; only the paint changes.

Unlike Michael's tool the donor landmarks are DETECTED, not hand-read (36 donors, the framing varies
by ~25 px in head position and ~20 % in scale between cells): the chin and centre line from the
skin mask, the head top from the warm/dark foreground, the pupils as the darkest SYMMETRIC pair
scored dark-above (brow) / bright-below (cheek) so brows and canthus shadows lose, the mouth as the
darkest row near its prior with sub-pixel corner crossings, the hairline as the first row reaching
85 % of the forehead plateau (blond hair passes a skin-colour test; the plateau test it fails), the
face width at the JAW (the ears are skin-coloured and attach between the eye and nostril rows).
Validated against Michael's hand-measured donor (3,3): pupils within 1.5 / 4 px, mouth corners
within 1 px, nostril 0.5, hairline 5 (his fringe), chin 1.5.

Per man (the pages are the reference - Issue 2 p8-9-11, Issue 3 p3-5 - and the bible's WW1 thread):
  louie        r0 c6  soft young face, light tousled fringe (Issue 3 p3 crater panel), 17.  Blue-grey eyes.
  poilu_a      r1 c0  heavy jaw, stern, cropped - the Gaston type (Issue 2 p9): moustache + stubble, older.
  poilu_b      r3 c0  lean, wide-eyed, light hair - the young line poilu (Pierre's rhyme, no freckles: Gus's mark).
  poilu_1916   r2 c1  the Durand type (Issue 2 p9 bottom, p11): older, heavy DROOPING moustache, lined.
  german_boy   r1 c1  round soft face, blond crop, big eyes - "no older than I" (Issue 3 p5) + THE SCAR.
  german_line  r2 c5  gaunt, older, dark - the line infantryman.

Gates (measured on the written PNG with a copy of measure_cell's arithmetic on sRGB bytes/255, exactly
what Blender's Image.pixels hands the projection tool): pupils within 1.5 px of (49,73)/(76,73);
lip line row 103-108; corners within 2 px of 52.2/72.1; nostril row 91-96; chin 125-133; hairline
34-43; hair band + dome lum < 0.2 and skin < 0.05; under-ear boxes skin > 0.9; neck skin > 0.95
lum > 0.45; both ear boxes > 300 skin px; every pair of the six cells differs on > 55 % of face
pixels (the thing Caleb saw); the scar on the boy is > 100 changed px on lit skin.
"""
import os
import sys
import numpy as np
from PIL import Image

ROOT = r"C:\Users\caleb\RECONgame"
CHAR = os.path.join(ROOT, "assets", "us", "characters")
SRC_TEMPLATE = os.path.join(CHAR, "face_source", "face_atlas_v5.png")     # 1296x1132, 10x7
SRC_DONOR = os.path.join(CHAR, "face_source", "newfaceatlas.png")         # 909x878, 9x4
OUT = os.path.join(ROOT, "assets", "ww1", "characters")
PREVIEW = "--preview" in sys.argv
SCRATCH = os.path.join(os.environ.get("TEMP", r"C:\Temp"), "ww1_face_cells_preview")
CW, CH = 130, 162
DW, DH = 101, 220
CX = 62.5

# tag -> frame cell (row_from_top, col on face_atlas_v5: the template head whose ears/neck/hair mass
# stay), donor cell (row, col on newfaceatlas), and the man's own marks
CAST = {
    "louie":       dict(frame=(3, 1), donor=(0, 6), hair=(0.240, 0.155, 0.085), iris=(0.32, 0.42, 0.54),
                        moustache=None, stubble=0.0, age=0.0, scar=False),
    "poilu_a":     dict(frame=(3, 2), donor=(1, 0), hair=(0.120, 0.088, 0.060), iris=(0.28, 0.22, 0.14),
                        moustache="heavy", stubble=0.40, age=0.5, scar=False),
    "poilu_b":     dict(frame=(2, 3), donor=(3, 0), hair=(0.215, 0.145, 0.082), iris=(0.30, 0.40, 0.50),
                        moustache=None, stubble=0.0, age=0.0, scar=False),
    "poilu_1916":  dict(frame=(2, 4), donor=(2, 1), hair=(0.225, 0.150, 0.082), iris=(0.30, 0.30, 0.24),
                        moustache="droop", stubble=0.25, age=0.7, scar=False),
    "german_boy":  dict(frame=(2, 6), donor=(1, 1), hair=(0.235, 0.160, 0.088), iris=(0.34, 0.44, 0.56),
                        moustache=None, stubble=0.0, age=0.0, scar=True),
    "german_line": dict(frame=(3, 7), donor=(2, 5), hair=(0.125, 0.095, 0.065), iris=(0.28, 0.24, 0.16),
                        moustache="clipped", stubble=0.35, age=0.6, scar=False),
}
FILES = {"louie_1915": "louie", "louie_adrian": "louie", "poilu_a": "poilu_a", "poilu_b": "poilu_b",
         "poilu_1916": "poilu_1916", "german_boy": "german_boy", "german_line": "german_line"}

# ---- targets, cell pixels (130x162): the template head's landmarks (identical on every light-skin
# cell of face_atlas_v5 to +-2 px, measured 2026-09-13 on 8 cells) ---------------------------------
TGT = {
    "pupil_l": (49.0, 73.0), "pupil_r": (76.0, 73.0),
    "brow_l": (49.0, 66.0), "brow_r": (76.0, 66.0), "brow_c": (CX, 66.5),
    "brow_in_l": (55.5, 65.0), "brow_in_r": (69.5, 65.0),
    "lid_up_l": (49.0, 69.5), "lid_up_r": (76.0, 69.5),
    "lid_lo_l": (49.0, 76.5), "lid_lo_r": (76.0, 76.5),
    "nostril_c": (CX, 93.0), "wing_l": (55.0, 92.5), "wing_r": (70.0, 92.5),
    "nose_bridge": (CX, 82.0),
    "mouth_l": (52.2, 106.0), "mouth_r": (72.1, 106.0), "mouth_c": (62.2, 105.0),
    "lip_low": (62.2, 109.5),
    "chin_bottom": (62.2, 127.0), "chin_shadow": (62.2, 131.0),
    "face_l_eye": (33.5, 73.0), "face_r_eye": (91.5, 73.0),
    "cheek_l": (35.0, 90.0), "cheek_r": (90.0, 90.0),
    "jaw_l": (38.5, 106.0), "jaw_r": (86.5, 106.0),
    "chin_l": (47.5, 124.0), "chin_r": (77.5, 124.0),
    "hairline_c": (CX, 38.0), "temple_l": (37.0, 42.0), "temple_r": (88.0, 42.0),
    "hair_top": (CX, 5.0), "hair_l": (28.0, 20.0), "hair_r": (97.0, 20.0),
}
# scar path on the boy, cell fractions (kept from the 9/12 cell: inside col ~86 so the projection
# tool's ear-crease search (cols 90-101) never takes its dark edge for the crease)
SCAR_A = (0.640, 0.440)
SCAR_B = (0.585, 0.745)
SCAR_W = 5.5


# ---------------------------------------------------------------------------------------------------
def cell(sheet, cols, rows, r, c, w, h):
    W, H = sheet.size
    x0, y0 = int(round(c * W / cols)), int(round(r * H / rows))
    return np.array(sheet.crop((x0, y0, x0 + w, y0 + h)).convert("RGB")).astype(np.float32) / 255.0


def lum(a):
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


def skin_mask(a):
    return (lum(a) > 0.30) & (a[..., 0] > a[..., 2] + 0.08)


def box3(m):
    p = np.pad(m, [(1, 1), (1, 1)] + [(0, 0)] * (m.ndim - 2), mode='edge')
    o = np.zeros_like(m)
    for dy in (0, 1, 2):
        for dx in (0, 1, 2):
            o += p[dy:dy + m.shape[0], dx:dx + m.shape[1]]
    return o / 9.0


def blur(m, n=1):
    for _ in range(n):
        m = box3(m)
    return m


def tps_fit(src, dst):
    src = np.asarray(src, np.float64)
    dst = np.asarray(dst, np.float64)
    n = len(src)
    d = np.sqrt(((src[:, None, :] - src[None, :, :]) ** 2).sum(-1))
    K = np.where(d > 0, d ** 2 * np.log(np.maximum(d, 1e-12) ** 2), 0.0)
    P = np.hstack([np.ones((n, 1)), src])
    L = np.zeros((n + 3, n + 3))
    L[:n, :n] = K + 1e-6 * np.eye(n)
    L[:n, n:] = P
    L[n:, :n] = P.T
    Y = np.zeros((n + 3, 2))
    Y[:n] = dst
    Wt = np.linalg.solve(L, Y)

    def f(pts):
        pts = np.asarray(pts, np.float64)
        dd = np.sqrt(((pts[:, None, :] - src[None, :, :]) ** 2).sum(-1))
        U = np.where(dd > 0, dd ** 2 * np.log(np.maximum(dd, 1e-12) ** 2), 0.0)
        return U @ Wt[:n] + np.hstack([np.ones((len(pts), 1)), pts]) @ Wt[n:]
    return f


def sample_bilinear(img, xy):
    H, W = img.shape[:2]
    x = np.clip(xy[:, 0], 0, W - 1.001)
    y = np.clip(xy[:, 1], 0, H - 1.001)
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = (x - x0)[:, None], (y - y0)[:, None]
    a = img[y0, x0]
    b = img[y0, x0 + 1]
    c = img[y0 + 1, x0]
    d = img[y0 + 1, x0 + 1]
    return (a * (1 - fx) * (1 - fy) + b * fx * (1 - fy) + c * (1 - fx) * fy + d * fx * fy)


# ---------------------------------------------------------------------------------------------------
# donor landmarks, detected
# ---------------------------------------------------------------------------------------------------
FR = dict(eye=0.343, nostril=0.644, mouth=0.788)      # fractions hairline->chin on the hand-read donor (3,3)


def run_extents(row, cx, maxgap):
    W = len(row)
    out = []
    for step in (-1, 1):
        x = int(cx)
        last = x
        gap = 0
        while 0 < x < W - 1:
            x += step
            if row[x]:
                last = x
                gap = 0
            else:
                gap += 1
                if gap > maxgap:
                    break
        out.append(last)
    return out


def detect_donor(Dn):
    H, W = Dn.shape[:2]
    l = lum(Dn)
    ls = box3(l)
    l5 = box3(ls)
    skin = (l > 0.33) & (Dn[..., 0] > Dn[..., 2] + 0.10) & (Dn[..., 0] > Dn[..., 1] + 0.03)
    fg = (Dn[..., 0] - Dn[..., 2] > 0.035) | (l < 0.10)
    fg[189:] = False
    fg[:, :6] = False
    fg[:, 95:] = False
    f = {}
    xs = []
    for y in range(70, 170):
        cols = np.nonzero(skin[y])[0]
        if len(cols) > 20:
            xs.append((cols.min() + cols.max()) / 2.0)
    cx = float(np.median(xs))
    colskin = skin[:, int(cx) - 4:int(cx) + 5].mean(axis=1)
    # chin: last skin row on the centre columns (gap-tolerant: a soul patch is a gap; the olive collar
    # fails the skin test outright)
    last, gap = 110, 0
    for y in range(110, min(H, 215)):
        if colskin[y] >= 0.5:
            last, gap = y, 0
        else:
            gap += 1
            if gap > 10:
                break
    chin = last + 1
    rows = np.nonzero(fg[:, int(cx) - 3:int(cx) + 4].mean(axis=1) > 0.5)[0]
    top = rows[0] if len(rows) else 12
    ey0 = top + 0.53 * (chin - top)
    hwe = run_extents(fg[int(ey0)], cx, 2)
    hw = hwe[1] - hwe[0]
    # pupils: a SYMMETRIC pair (equidistant from the centre line to +-1.5 px, same row to +-1), scored
    # dark-at-the-point PLUS dark 8 px above (the brow) MINUS bright 8 px below (the cheek), so the
    # brow pair (bright forehead above, dark eye below) loses to the iris pair, and the inner-canthus
    # shadow (darker than the iris on some donors) is never symmetric at iris spacing.
    best = None
    for dx in np.arange(0.14 * hw, 0.30 * hw, 0.5):
        for y in np.arange(ey0 - 11, ey0 + 12, 1.0):
            for asym in (-1.5, -1.0, -0.5, 0, 0.5, 1.0, 1.5):
                for dy in (-1, 0, 1):
                    xl, xr = int(cx - dx + asym), int(cx + dx + asym)
                    yl, yr = int(y), int(y + dy)
                    v = (l5[yl, xl] + l5[yr, xr]) + 0.5 * (l5[yl - 8, xl] + l5[yr - 8, xr]) \
                        - 0.5 * (l5[yl + 8, xl] + l5[yr + 8, xr])
                    if best is None or v < best[0]:
                        best = (v, (xl + 0.5, yl + 0.5), (xr + 0.5, yr + 0.5))
    pl, pr = best[1], best[2]
    ey = (pl[1] + pr[1]) / 2
    f["pupil_l"], f["pupil_r"] = pl, pr
    bys = []
    for ex, ey_ in (pl, pr):
        exi = int(ex)
        col = ls[int(ey_) - 16:int(ey_) - 5, exi - 2:exi + 3].mean(axis=1)
        bys.append(int(ey_) - 16 + int(col.argmin()) + 0.5)
    f["brow_l"] = (pl[0], bys[0])
    f["brow_r"] = (pr[0], bys[1])
    f["brow_c"] = (cx, (bys[0] + bys[1]) / 2 + 1.5)
    f["brow_in_l"] = (pl[0] + 8.5, (bys[0] + bys[1]) / 2 + 0.5)
    f["brow_in_r"] = (pr[0] - 8.5, (bys[0] + bys[1]) / 2 + 0.5)
    for k, (ex, ey_) in (("l", pl), ("r", pr)):
        f["lid_up_" + k] = (ex, ey_ - 4.0)
        f["lid_lo_" + k] = (ex, ey_ + 3.5)
    # hairline: scanning down the centre column from the top, the first row that reaches 85 % of the
    # forehead plateau (max 5x5 lum between 40 and 5 rows above the brows)
    by = int((bys[0] + bys[1]) / 2)
    plateau = float(l5[by - 40:by - 5, int(cx) - 3:int(cx) + 4].mean(axis=1).max())
    colL = l5[:, int(cx) - 3:int(cx) + 4].mean(axis=1)
    hl = next(y for y in range(int(top) + 2, by - 4) if colL[y] >= 0.85 * plateau)
    fh = chin - hl
    f["hairline_c"] = (cx, hl - 0.5)
    # mouth: darkest row within +-7 of the fraction prior, between the pupils' inner 60 %
    my0 = hl + FR["mouth"] * fh
    r0, r1 = int(my0 - 7), int(my0 + 8)
    xm0, xm1 = int(pl[0]) + 6, int(pr[0]) - 6
    band = ls[r0:r1, xm0:xm1].mean(axis=1)
    my = r0 + int(band.argmin())
    mrow = ls[my - 1:my + 2, :].mean(axis=0)
    line_l = float(mrow[xm0:xm1].min())
    skin_l = float(np.median(np.concatenate([mrow[xm0 - 14:xm0 - 6], mrow[xm1 + 6:xm1 + 14]])))
    thr = 0.5 * (skin_l + line_l)
    mxc = xm0 + int(mrow[xm0:xm1].argmin())

    def cross(step):
        x = mxc
        while 3 < x < W - 4 and mrow[x] < thr:
            x += step
        a, b = mrow[x - step], mrow[x]
        return x - step + step * (thr - a) / (b - a) if b != a else float(x)
    ml, mr = cross(-1), cross(1)
    f["mouth_l"] = (ml, my + 0.5)
    f["mouth_r"] = (mr, my + 0.5)
    f["mouth_c"] = ((ml + mr) / 2, my + 0.5)
    f["lip_low"] = ((ml + mr) / 2, my + 7.5)
    # face width at the JAW (rows mouth-2..mouth+6, 30 px gap tolerance for the lips; shadowed skin
    # passes, the olive collar and dark hair fail): the ears are skin-coloured and attach to the head
    # between the eye row and the nostril row, so any width taken up there includes them.
    skin_sh = (l > 0.16) & (Dn[..., 0] > Dn[..., 2] + 0.06) & (Dn[..., 0] > Dn[..., 1] + 0.02)
    ws = [run_extents(skin_sh[y], cx, 30) for y in range(my - 2, my + 7)]
    jl, jr = float(np.median([w[0] for w in ws])), float(np.median([w[1] for w in ws]))
    fw = jr - jl
    # nostrils: darkest row within +-6 of the prior, centre columns
    ny0 = hl + FR["nostril"] * fh
    r0, r1 = int(ny0 - 6), int(ny0 + 7)
    nb = ls[r0:r1, int(cx) - 8:int(cx) + 8].mean(axis=1)
    ny = r0 + int(nb.argmin())
    f["nostril_c"] = (cx, ny + 0.5)
    f["wing_l"] = (cx - 0.155 * fw, ny - 0.5)
    f["wing_r"] = (cx + 0.155 * fw, ny - 0.5)
    f["nose_bridge"] = (cx, ey + 0.13 * fh)
    f["chin_bottom"] = (cx, chin - 1.5)
    f["chin_shadow"] = (cx, chin + 4.5)

    def ext(y, maxgap=16):
        e = run_extents(skin[int(y)], cx, maxgap)
        return [max(e[0], jl - 4), min(e[1], jr + 4)]
    # cheek / eye-row / temple outline = the jaw outline carried up (+1 / +2 / clamped): the ears and a
    # blond fringe both pass the skin colour test, so a row scan there is not an instrument
    yc = (ey + ny) / 2 + 3
    f["cheek_l"], f["cheek_r"] = (jl - 1, yc), (jr + 1, yc)
    f["face_l_eye"], f["face_r_eye"] = (jl - 2, ey), (jr + 2, ey)
    f["jaw_l"], f["jaw_r"] = (jl, my), (jr, my)
    e = ext(chin - 5)
    f["chin_l"], f["chin_r"] = (e[0] + 3, chin - 5), (e[1] - 3, chin - 5)
    e2 = ext(hl + 6)
    f["temple_l"], f["temple_r"] = (max(e2[0], jl), hl + 6), (min(e2[1], jr - 1), hl + 6)
    f["hair_top"] = (cx, top + 0.5)
    yh = int(hl) - 0.17 * fh
    e = run_extents(fg[int(yh)], cx, 2)
    f["hair_l"], f["hair_r"] = (e[0] + 1, yh), (e[1] - 1, yh)
    f["_box"] = (hl, chin, fw, cx, top)
    return f, fg


# ---------------------------------------------------------------------------------------------------
# measure_cell's arithmetic (tools/project_cow_head_uvs.py), for the gates
# ---------------------------------------------------------------------------------------------------
def measure(a):
    l = lum(a)
    ls = box3(l)
    skin = skin_mask(a)
    f = {}
    eyes = []
    for x0, x1 in ((30, 63), (67, 100)):
        win = ls[55:80, x0:x1]
        iy, ix = np.unravel_index(win.argmin(), win.shape)
        eyes.append((x0 + ix, 55 + iy))
    f["eye_l"], f["eye_r"] = eyes
    ey = (eyes[0][1] + eyes[1][1]) / 2.0
    xm0, xm1 = eyes[0][0] + 5, eyes[1][0] - 5
    band = ls[98:118, xm0:xm1].mean(axis=1)
    my = 98 + int(band.argmin())
    f["mouth"] = ((xm0 + xm1) / 2.0, my)
    # the lip line itself, rows 103-108 (a moustache out-darkens it in the tool's 98-118 band)
    lb = ls[103:109, xm0:xm1].mean(axis=1)
    ly = 103 + int(lb.argmin())
    f["lip_y"] = ly
    cb = ls[my + 12: my + 38, 55:75].mean(axis=1)
    f["chin_y"] = my + 12 + int(cb.argmin())
    nb = ls[int(ey) + 5: my - 8, 60:71]
    iy, ix = np.unravel_index(nb.argmax(), nb.shape)
    hi_y = int(ey) + 5 + iy
    r0, r1 = int(ey) + 12, int(ey) + 23          # project_cow_head_uvs.measure_cell (2026-09-13 band)
    nband = ls[r0:r1, 54:72].mean(axis=1)
    nostril_y = r0 + int(nband.argmin())
    f["nose_tip_y"] = (hi_y + nostril_y) / 2.0
    f["nostril_y"] = nostril_y
    mrow = ls[ly - 1:ly + 2, :].mean(axis=0)
    skin_l, line_l = float(mrow[xm0 - 12:xm0 - 4].mean()), float(mrow[xm0:xm1].min())
    thr = 0.5 * (skin_l + line_l)
    mxc = xm0 + int(mrow[xm0:xm1].argmin())

    def cross(step):
        x = mxc
        while 3 < x < CW - 4 and mrow[x] < thr:
            x += step
        p, q = mrow[x - step], mrow[x]
        return x - step + step * (thr - p) / (q - p) if q != p else float(x)
    f["mouth_l"], f["mouth_r"] = cross(-1), cross(1)
    bys = []
    for (ex, ey_) in eyes:
        colp = ls[ey_ - 11:ey_ - 3, ex - 1:ex + 2].mean(axis=1)
        bys.append(ey_ - 11 + int(colp.argmin()))
    f["brow_y"] = (bys[0] + bys[1]) / 2.0
    col = ls[:, 55:75].mean(axis=1)
    f["hair_y"] = int(np.argmax(col > 0.28))
    for nm, (x0, x1) in (("ear_l", (10, 36)), ("ear_r", (94, 120))):
        m = skin[62:104, x0:x1]
        ys, xs = np.nonzero(m)
        f[nm + "_px"] = int(m.sum())
        f[nm] = (round(float(x0 + xs.mean()), 1), round(float(62 + ys.mean()), 1)) if len(xs) else None

    def region(y0, y1, x0, x1):
        return dict(lum=round(float(l[y0:y1, x0:x1].mean()), 3), skin=round(float(skin[y0:y1, x0:x1].mean()), 2))
    f["hair_band"] = region(14, 35, 23, 105)
    f["hair_dome"] = region(8, 31, 33, 95)
    f["under_ear_r"] = region(102, 127, 98, 113)
    f["under_ear_l"] = region(102, 127, 17, 32)
    f["neck"] = region(131, 150, 38, 90)
    return f


# ---------------------------------------------------------------------------------------------------
# marks
# ---------------------------------------------------------------------------------------------------
def hair_noise(h, w, seed, scale=2.0, sy=None):
    """Value noise; sy > scale stretches it vertically (strands)."""
    rng = np.random.default_rng(seed)
    n = rng.random((max(2, int(h / (sy or scale))), max(2, int(w / scale))))
    return np.array(Image.fromarray((n * 255).astype(np.uint8)).resize((w, h), Image.BILINEAR)) / 255.0


def paint_moustache(out, style, hair_rgb, seed):
    """A moustache between the nostril row (93) and the lip line (105-106), in the man's hair colour:
    two wings meeting under the nose (the bottom edge rises at the philtrum), strand noise, soft
    edges. Its darkest core stays at row 99-102 and it never crosses row 103, so the lip line at 105
    is still the darkest row of 103-108 (the gate) even though the tool's 98-118 band will report
    the moustache as 'mouth' - exactly what it did on the 9/12 poilu_1916 cell, and the chin search
    already starts 12 rows down for that reason."""
    cy, cx = np.mgrid[0:CH, 0:CW].astype(np.float32)
    if style == "heavy":          # Gaston: thick, ends past the mouth corners
        x0, x1, ytop, ybot, wing = 46.0, 79.0, 97.5, 103.0, 0.0
    elif style == "droop":        # Durand: thick, the ends drooping past the corners to the lip line
        x0, x1, ytop, ybot, wing = 44.0, 81.0, 97.0, 103.0, 6.0
    else:                         # clipped: narrow, under the nose only
        x0, x1, ytop, ybot, wing = 52.0, 73.0, 97.5, 102.5, 0.0
    xm = (x0 + x1) / 2
    hw = (x1 - x0) / 2
    t = np.clip(np.abs(cx - xm) / hw, 0, 1)
    top = ytop + 2.0 * t ** 2                      # the top edge curves down toward the ends
    bot = ybot - 1.6 * np.clip(1.0 - t / 0.25, 0, 1) ** 2 + wing * t ** 3   # rises at the philtrum, droops at the ends
    inside = (cy >= top - 1) & (cy <= bot + 1) & (t < 1.0)
    if wing:
        inside &= cy <= 105.0                      # never onto the lip line
    edge = np.minimum(np.minimum(cy - top + 1, bot + 1 - cy) / 2.2, (1.0 - t) * hw / 3.0)
    alpha = np.clip(edge, 0, 1) * inside
    n = hair_noise(CH, CW, seed, 1.1, sy=4.0)          # fine vertical strands
    n2 = hair_noise(CH, CW, seed + 7, 2.5, sy=6.0)     # coarser clumps
    strands = np.clip(0.15 + 1.1 * (0.55 * n + 0.45 * n2), 0, 1.2)
    col = np.array(hair_rgb, np.float32)[None, None, :] * (0.35 + 1.5 * strands[..., None])
    a = (alpha * (0.72 + 0.28 * strands))[..., None]
    out[...] = out * (1 - a) + col * a
    return alpha


def paint_stubble(out, k, seed):
    """Beard-shadow: the lower face (below the nostril row, outside the lips) pulled toward a cool dark
    by a speckled noise. k = strength."""
    if k <= 0:
        return
    cy, cx = np.mgrid[0:CH, 0:CW].astype(np.float32)
    zone = (cy >= 96) & (cy <= 131) & (cx >= 36) & (cx <= 89) & skin_mask(out)
    zone &= ~((cy >= 102) & (cy <= 109) & (cx >= 49) & (cx <= 76))         # lips
    # the beard's own outline: full under the jaw, thinning up the cheek toward the cheekbone
    fade = np.clip((cy - 96) / 14.0, 0, 1) * np.clip(1.0 - (np.abs(cx - CX) - 18) / 8.0, 0, 1)
    n = hair_noise(CH, CW, seed, 1.3)
    speck = (n > 0.62).astype(np.float32) * 0.6 + 0.4 * n
    d = np.clip(k * fade * (0.55 + 0.45 * speck), 0, 1) * zone
    dark = np.array([0.42, 0.40, 0.42], np.float32)
    out[...] = out * (1 - 0.55 * d[..., None]) + out * dark[None, None, :] * (0.55 * d[..., None])


def paint_age(out, k, seed):
    """Lines: nasolabial folds (nose wing -> past the mouth corners), crow's feet, a brow furrow;
    darkening along short strokes, k = depth."""
    if k <= 0:
        return
    from PIL import ImageDraw
    m = Image.new("L", (CW, CH), 0)
    d = ImageDraw.Draw(m)
    for sgn in (-1, 1):
        # nasolabial: from beside the nose wing down and out past the mouth corner
        d.line([(CX + sgn * 8.5, 93), (CX + sgn * 12.5, 102), (CX + sgn * 14.5, 112)], fill=255, width=1)
        # crow's feet: three short strokes fanning from the outer eye corner
        ex = CX + sgn * 21.0
        for dy in (-2.5, 0.5, 3.5):
            d.line([(ex, 73), (ex + sgn * 6, 73 + dy * 1.8)], fill=200, width=1)
        # under-eye line
        d.line([(CX + sgn * 9, 79), (CX + sgn * 17, 78.5)], fill=160, width=1)
    # brow furrows, two short verticals between the brows
    d.line([(CX - 2.5, 62), (CX - 3.0, 68)], fill=200, width=1)
    d.line([(CX + 2.5, 62), (CX + 3.0, 68)], fill=200, width=1)
    mk = blur(np.array(m).astype(np.float32) / 255.0, 1) * 0.55 * k
    mk[~skin_mask(out)] = 0
    out[...] = out * (1 - 0.45 * mk[..., None])


def scar(a):
    """The German boy's mark, from the 9/12 cell builder: a tapered line, distance-field painted,
    healed-scar colouring (darker red edges, a pale raised core). a = float cell (0-1)."""
    out = a.copy()
    h, w, _ = out.shape
    x0, y0 = SCAR_A[0] * w, SCAR_A[1] * h
    x1, y1 = SCAR_B[0] * w, SCAR_B[1] * h
    half = SCAR_W * (w / 129.0) * 0.5
    L = lum(out)
    samples = []
    for t in np.linspace(0.15, 0.85, 12):
        px, py = int(round(x0 + (x1 - x0) * t)), int(round(y0 + (y1 - y0) * t))
        samples.append(float(L[py, px]))
    m = float(np.mean(samples))
    assert m > 110.0 / 255.0, "scar path mean luminance %.3f - not lit skin" % m
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dx, dy = x1 - x0, y1 - y0
    t = np.clip(((xx - x0) * dx + (yy - y0) * dy) / (dx * dx + dy * dy), 0.0, 1.0)
    d = np.hypot(xx - (x0 + t * dx), yy - (y0 + t * dy))
    taper = 0.35 + 0.65 * np.clip(np.sin(np.pi * np.clip(t, 0.0, 1.0)), 0.0, 1.0) ** 0.6
    hw = half * taper
    core = np.clip(1.0 - d / hw, 0.0, 1.0)
    edge = np.clip(1.0 - (d - hw) / (hw * 1.6), 0.0, 1.0) * (d >= hw)
    dark = np.array([0.62, 0.42, 0.40], dtype=np.float32)
    pale = np.array([1.10, 0.94, 0.90], dtype=np.float32)
    out *= (1.0 + (pale - 1.0) * core[..., None])
    out *= (1.0 + (dark - 1.0) * edge[..., None])
    out = np.clip(out, 0, 1)
    assert not np.isnan(out).any()
    n = int((np.abs(out - a).max(axis=2) > 6 / 255.0).sum())
    assert n >= 100, "scar: only %d px changed" % n
    print("   scar: %d px changed, path lum %.2f" % (n, m))
    return out


# ---------------------------------------------------------------------------------------------------
def build_one(name, spec, sheets):
    T = cell(sheets["tpl"], 10, 7, spec["frame"][0], spec["frame"][1], CW, CH)
    Dn = cell(sheets["don"], 9, 4, spec["donor"][0], spec["donor"][1], DW, DH)
    assert T.shape == (CH, CW, 3) and Dn.shape == (DH, DW, 3)
    DON, fg = detect_donor(Dn)
    hl, chin, fw, dcx, top = DON["_box"]
    print("%-12s donor r%d c%d: hairline %d chin %d jaw width %d centre %.1f | pupils %s %s mouth %s..%s row %.0f nostril %.0f"
          % (name, spec["donor"][0], spec["donor"][1], hl, chin, fw, dcx,
             tuple(round(v, 1) for v in DON["pupil_l"]), tuple(round(v, 1) for v in DON["pupil_r"]),
             round(DON["mouth_l"][0], 1), round(DON["mouth_r"][0], 1), DON["mouth_c"][1], DON["nostril_c"][1]))

    # ---- skin colour match (multiplicative; an additive match lifts the pupils) ------------------
    ds = skin_mask(Dn)
    ds[:int(hl) + 6] = False
    ds[int(chin) - 2:] = False
    ds[:, :int(dcx - fw * 0.45)] = False
    ds[:, int(dcx + fw * 0.45):] = False
    ts = skin_mask(T)
    ts[:60] = False
    ts[130:] = False
    ts[:, :34] = False
    ts[:, 93:] = False
    ts &= lum(T) > 0.42
    dm = Dn[ds].mean(0)
    tm = T[ts].mean(0)
    Dm = np.clip(Dn * (tm / dm), 0, 1)
    soft = skin_mask(Dm)
    Dm[soft] = Dm[soft] * 0.75 + tm * 0.25

    # ---- donor foreground: the face inside the template outline, hairline down. The template keeps
    # its hair mass, ears, sides and neck. (Michael's donor was a small head whose hair sat inside the
    # cell; these heads run to the cell edge, and warping the whole foreground put a hard rectangle
    # of donor hair beside each temple; a donor-fringe ellipse over the template hair read as a cap.
    # The donor's own hairline still shapes the forehead: the polygon starts 5 rows above the
    # template hairline, so the donor's hair edge lands inside it and the mass above is recoloured
    # to the same brown.)
    from PIL import ImageDraw
    face_poly = Image.new("L", (CW, CH), 0)
    ImageDraw.Draw(face_poly).polygon(
        [TGT[k] for k in ("temple_l", "face_l_eye", "cheek_l", "jaw_l", "chin_l")] +
        [(TGT["chin_bottom"][0], TGT["chin_bottom"][1] + 3.0)] +
        [TGT[k] for k in ("chin_r", "jaw_r", "cheek_r", "face_r_eye", "temple_r")] +
        [(CX, TGT["hairline_c"][1] - 5.0)], fill=255)
    face_poly = np.array(face_poly).astype(np.float32) / 255.0
    face_poly = (blur(face_poly, 2) > 0.35).astype(np.float32)          # ~2 px dilation
    cy, cx = np.mgrid[0:CH, 0:CW]

    # ---- TPS warp, target -> donor ------------------------------------------------------------
    keys = list(TGT.keys())
    f = tps_fit([TGT[k] for k in keys], [DON[k] for k in keys])
    ty, tx = np.mgrid[0:CH, 0:CW]
    pts = np.stack([tx.ravel() + 0.5, ty.ravel() + 0.5], 1)
    src = f(pts) - 0.5
    warped = sample_bilinear(Dm, src).reshape(CH, CW, 3)
    wfg = sample_bilinear(fg.astype(np.float32)[..., None], src).reshape(CH, CW)
    inside = ((src[:, 0] > 1) & (src[:, 0] < DW - 2) & (src[:, 1] > 1) & (src[:, 1] < DH - 2)).reshape(CH, CW)
    wfg = (wfg > 0.5).astype(np.float32) * inside
    # above row 48 the donor contributes only where HE has skin (his forehead), so his temple hair
    # never lands inside the polygon's top corners as a block (seen); the template's hairline rules
    wskin = sample_bilinear(skin_mask(Dn).astype(np.float32)[..., None], src).reshape(CH, CW)
    keep = np.where(cy < 48, blur(wskin, 2) > 0.35, True).astype(np.float32)
    alpha = np.clip(blur(face_poly * wfg * keep, 4) * 1.3 - 0.12, 0, 1)

    # ---- shading transfer: the donor's low-frequency luminance is replaced by the template's, so
    # the patch carries the template's own side shadows and its border vanishes (the first two
    # previews showed every face as a lighter oval on the darker template cheeks)
    def lowpass(img, n=6):
        return blur(img, n)
    Lt = lowpass(lum(T)[..., None])
    Lw = lowpass(lum(warped)[..., None])
    gain = np.clip(Lt / np.maximum(Lw, 0.05), 0.55, 1.45)
    warped = np.clip(warped * (1.0 + (gain - 1.0) * alpha[..., None]), 0, 1)

    out = T.copy()
    out = out * (1 - alpha[..., None]) + warped * alpha[..., None]
    # forehead skin between fringe strands above row 36 -> shadowed (hair band rows 14-35 must read as hair)
    peek = (alpha > 0.5) & (cy <= 39) & skin_mask(out)
    ramp = 0.28 + 0.72 * np.clip((cy - 31) / 8.0, 0, 1)
    out[peek] = out[peek] * ramp[peek][:, None]
    # ---- hair: the template mass + the donor's hair edge, to the man's colour, luminance-preserving,
    # no strand brighter than lum 0.25 (the projection tool's hair band must be < 5 % 'skin' = warm
    # and lum > 0.30)
    HAIR = np.array(spec["hair"], np.float32)
    # the template's hair mass = its pixels between the near-black background (lum 0.04-0.08) and
    # its highlights, weighted SOFTLY by luminance (a hard mask left the brighter strands in the old
    # colour and a hard edge against the background - a flat brown dome, seen on the 4th preview)
    LT = lum(T)
    w = np.clip((LT - 0.05) / 0.05, 0, 1) * np.clip((0.40 - LT) / 0.12, 0, 1)
    w *= ~skin_mask(T) & (cx > 12) & (cx < 118)
    w *= np.clip((62 - cy) / 6.0, 0, 1)                                  # fades out toward the ear line
    side = np.clip((np.abs(cx - CX) - 30.0) / 8.0, 0, 1)                 # the side shadow beyond the hair mass...
    w *= 1 - side * np.clip((cy - 40) / 8.0, 0, 1)                      # ...below row 40 (soft, never a cut)
    w = np.maximum(w, ((alpha > 0.5) & (cy < 36)).astype(np.float32))
    w *= (1 - alpha) + alpha * (cy < 36)
    w = blur(w, 1)
    Lh = lum(out)
    hz = w > 0.02
    ref_l = float(np.median(Lh[w > 0.5])) if (w > 0.5).any() else 0.15
    Lc = Lh / max(ref_l, 1e-3)
    Lc = np.where(Lc > 1.0, 1.0 + (Lc - 1.0) * 0.35, Lc)          # highlights compressed, not clipped
    recol = HAIR[None, None, :] * Lc[..., None]
    # no strand brighter than lum 0.25 (the projection tool's hair band must be < 5 % 'skin' = warm
    # and lum > 0.30): compress above 0.25 to at most ~0.29
    Lr = lum(recol)
    recol = recol * np.where(Lr > 0.25, (0.25 + (Lr - 0.25) * 0.25) / np.maximum(Lr, 1e-3), 1.0)[..., None]
    out = out * (1 - w[..., None]) + recol * w[..., None]
    hair = hz
    sm = blur(out, 1)
    hm = blur(hair.astype(np.float32), 1)
    seam = ((alpha > 0.1) & (alpha < 0.9) & (cy < 50))[..., None] * hm[..., None]
    out = out * (1 - seam) + sm * seam

    # ---- the template's jaw outside the new outline -> background shadow ------------------------
    fill = T * 0.74
    wedge = (alpha < 0.5) & (cy >= 76) & (cy < 131) & (cx > 31) & (cx < 96) & (lum(T) > 0.47)
    wa = blur(wedge.astype(np.float32), 3)
    wa = np.clip(wa * 1.3, 0, 1) * (1 - alpha)
    out = out * (1 - wa[..., None]) + fill * wa[..., None]

    # ---- lip line deepened along the painted mouth, feathered ends -------------------------------
    lx0, lx1 = TGT["mouth_l"][0], TGT["mouth_r"][0]
    for y, k in ((104, 0.82), (105, 0.55), (106, 0.76)):
        xs = np.arange(CW)
        end = np.clip(np.minimum(xs - lx0 + 1.5, lx1 - xs + 1.5) / 3.0, 0, 1)
        out[y] = out[y] * (1 - end[:, None] * (1 - k))

    # ---- the lower-lip shadow (rows 108-117) lifted 55 % toward the chin skin: on a moustached man
    # the tool's 98-118 band reports the moustache as the mouth and searches the chin from +12, where
    # a donor's lower-lip shadow (row ~112, lum 0.30) out-darkened the chin crease at 128 and put the
    # chin 16 px high (measured on poilu_a before this)
    ref = out[119:124, 52:73].reshape(-1, 3).mean(0)
    for y in range(108, 118):
        k = 0.55 * np.clip(1.0 - abs(y - 112.5) / 5.5, 0, 1)
        xs = np.arange(48, 78)
        end = np.clip(np.minimum(xs - 48, 77 - xs) / 4.0, 0, 1) * k
        out[y, 48:78] = out[y, 48:78] * (1 - end[:, None]) + ref * end[:, None]

    # ---- symmetric lighting: mirror the lit half across the pupil axis (every template head is
    # lit symmetrically; the donors are lit from one side and the side quads streak a shadow jaw)
    L = lum(out)
    lit_left = L[62:120, 36:56].mean() >= L[62:120, 69:89].mean()
    mirrored = np.roll(out[:, ::-1], int(round(2 * CX)) - (CW - 1), axis=1)
    band = np.clip(((cx - CX) if lit_left else (CX - cx)) / 6.0, 0, 1)
    right = band * (alpha > 0.5) * np.clip((cy - 36) / 12.0, 0, 1) * (cy < 131)
    out = out * (1 - right[..., None]) + mirrored * right[..., None]
    # side-quad bands: vertical 5-tap blur on the near-edge columns (face rows only)
    for x0, x1 in ((34, 47), (78, 91)):
        b = out[60:131, x0:x1]
        v = b.copy()
        for _ in range(2):
            v = (np.roll(v, 1, 0) + v + np.roll(v, -1, 0)) / 3.0
        out[62:129, x0:x1] = v[2:-2]
    # jaw contour -> the under-ear shadow colour (a dark contour reads as a chinstrap beard at 75 px)
    L = lum(out)
    jaw = (alpha > 0.5) & (cy >= 98) & (cy < 131) & (L < 0.40) & (L > 0.06) & (((cx < 52) | (cx > 73)) | (cy >= 118))
    jaw &= ~((cy >= 102) & (cy <= 108) & (cx >= 50) & (cx <= 75))
    # toward the template's OWN pixels there (its jaw/neck shading), so the patch border vanishes:
    # a fixed shadow colour read as a beard line, a fixed lit colour as a pale chinstrap (both seen)
    out[jaw] = out[jaw] * 0.4 + T[jaw] * 0.6
    # nostril shadows: two small dark ellipses on the painted nostril row (the template's are lum
    # 0.31 against 0.45 skin; under a moustache that is not the darkest thing in the tool's band)
    for sgn in (-1, 1):
        r = np.sqrt(((cx - (CX + sgn * 6.5)) / 2.4) ** 2 + ((cy - 93.3) / 1.4) ** 2)
        k = np.clip(1.0 - r, 0, 1) * 0.55
        out = out * (1 - k[..., None])
    # nose-tip catch light (measure_cell's nose_tip = (highlight + nostril) / 2; a bridge ridge that
    # out-brightens the tip tilts the head's vertical affine)
    r = np.sqrt(((cx - 62.0) / 3.0) ** 2 + ((cy - 88.0) / 1.8) ** 2)
    tip = np.clip(1.0 - r, 0, 1) * 0.14
    out = np.clip(out * (1 + tip[..., None]), 0, 1)

    # ---- the man's own marks ------------------------------------------------------------------
    seed = sum(ord(c) for c in name)
    paint_age(out, spec["age"], seed)
    paint_stubble(out, spec["stubble"], seed + 1)
    if spec["moustache"]:
        paint_moustache(out, spec["moustache"], spec["hair"], seed + 2)
    if spec["scar"]:
        out = scar(out)

    # ---- irises + pupils + brows: measure_cell takes the darkest 3x3 in rows 55-80 as the pupil ---
    IRIS = np.array(spec["iris"], np.float32)
    for (px, py) in (TGT["pupil_l"], TGT["pupil_r"]):
        r = np.sqrt((cx - px) ** 2 + (cy - py) ** 2)
        iris = (r <= 2.6) & (lum(out) < 0.45) & (lum(out) > 0.08)
        Li = lum(out)[iris][:, None]
        out[iris] = np.clip(IRIS * (Li / 0.36), 0, 0.62)
        out[r <= 1.6] = np.minimum(out[r <= 1.6], 0.05)
    brow = (cy >= 58) & (cy <= 70) & (cx >= 34) & (cx <= 91) & (lum(out) < 0.11) & ~skin_mask(out)
    for (px, py) in (TGT["pupil_l"], TGT["pupil_r"]):
        brow &= np.sqrt((cx - px) ** 2 + (cy - py) ** 2) > 3.5
    out[brow] = out[brow] * (0.13 / np.maximum(lum(out)[brow], 1e-3))[:, None]
    return np.clip(out, 0, 1), T


def gates(name, a, spec):
    m = measure(a)
    errs = []
    for k, want in (("eye_l", (49, 73)), ("eye_r", (76, 73))):
        d = np.hypot(m[k][0] - want[0], m[k][1] - want[1])
        assert d <= 1.5, (name, k, m[k], want)
    assert 103 <= m["lip_y"] <= 108, (name, "lip", m["lip_y"])
    # the boy's scar edge crosses the mouth row 3 px outside the right corner and the crossing reads
    # there; the corners are a report in the projection tool, not an affine input
    tol = 4.0 if spec["scar"] else 2.0
    assert abs(m["mouth_l"] - 52.2) <= tol and abs(m["mouth_r"] - 72.1) <= tol, (name, m["mouth_l"], m["mouth_r"])
    assert 91 <= m["nostril_y"] <= 96, (name, "nostril", m["nostril_y"])
    assert 125 <= m["chin_y"] <= 133, (name, "chin", m["chin_y"])
    assert 34 <= m["hair_y"] <= 43, (name, "hairline", m["hair_y"])
    assert m["hair_band"]["lum"] < 0.2 and m["hair_band"]["skin"] < 0.05, (name, m["hair_band"])
    assert m["hair_dome"]["lum"] < 0.2 and m["hair_dome"]["skin"] < 0.05, (name, m["hair_dome"])
    assert m["under_ear_r"]["skin"] > 0.9 and m["under_ear_l"]["skin"] > 0.9, (name, m["under_ear_r"], m["under_ear_l"])
    assert m["neck"]["skin"] > 0.95 and m["neck"]["lum"] > 0.45, (name, m["neck"])
    assert m["ear_l_px"] > 300 and m["ear_r_px"] > 300, (name, m["ear_l_px"], m["ear_r_px"])
    return m


def main():
    sheets = dict(tpl=Image.open(SRC_TEMPLATE), don=Image.open(SRC_DONOR))
    cells = {}
    frames = {}
    for name, spec in CAST.items():
        out, T = build_one(name, spec, sheets)
        cells[name] = out
        frames[name] = T
        img = Image.fromarray((out * 255 + 0.5).astype(np.uint8))
        for tag, who in FILES.items():
            if who == name:
                p = os.path.join(OUT, "ww1_%s_face_cell.png" % tag)
                img.save(p)
        a = np.array(img.convert("RGB")).astype(np.float32) / 255.0
        m = gates(name, a, spec)
        print("   gates OK: eyes %s %s lip %d corners %.1f/%.1f nostril %d chin %d hairline %d brow %.1f | hair band lum %.3f"
              % (m["eye_l"], m["eye_r"], m["lip_y"], m["mouth_l"], m["mouth_r"], m["nostril_y"], m["chin_y"],
                 m["hair_y"], m["brow_y"], m["hair_band"]["lum"]))
    # DIFFERENT MEN: every pair of cells differs on most face pixels, and each differs from its own frame
    face = (slice(40, 131), slice(33, 97))
    names = list(cells)
    worst = 1.0
    for i in range(len(names)):
        for j in range(i + 1, len(names)):
            same = (np.abs(cells[names[i]][face] - cells[names[j]][face]).sum(2) < 8 / 255.0).mean()
            worst = min(worst, 1 - same)
            assert same < 0.45, ("cells too alike", names[i], names[j], same)
    for n in names:
        same = (np.abs(cells[n][face] - frames[n][face]).sum(2) < 8 / 255.0).mean()
        assert same < 0.45, ("cell still the template", n, same)
    print("DIFFERENT MEN: worst pairwise face-region difference %.0f%% (bar 55%%); every cell < 45%% identical to its frame" % (100 * worst))
    if PREVIEW:
        os.makedirs(SCRATCH, exist_ok=True)
        Z = 4
        sheet = Image.new("RGB", (len(names) * (CW * Z + 8), CH * Z * 2 + 8), (255, 255, 255))
        for i, n in enumerate(names):
            sheet.paste(Image.fromarray((frames[n] * 255 + 0.5).astype(np.uint8)).resize((CW * Z, CH * Z), Image.NEAREST), (i * (CW * Z + 8), 0))
            sheet.paste(Image.fromarray((cells[n] * 255 + 0.5).astype(np.uint8)).resize((CW * Z, CH * Z), Image.NEAREST), (i * (CW * Z + 8), CH * Z + 8))
        p = os.path.join(SCRATCH, "ww1_cells_frame_vs_new.png")
        sheet.save(p)
        print("preview (top: frame cells / bottom: new cells) ->", p)
    print("done - %d cells for %d files in %s" % (len(cells), len(FILES), OUT))


if __name__ == "__main__":
    main()
