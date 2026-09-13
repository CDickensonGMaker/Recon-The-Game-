"""build_cow_face_cell.py - a painted CoW face cell for a NEW man, off a distinct base head.

    python tools/build_cow_face_cell.py --who mccleary [--preview] [--landmarks]
    python tools/build_cow_face_cell.py --who champs   [--preview] [--landmarks]

Writes assets/us/characters/cow_<who>_face_cell.png (130x162, the CoW cell format).

The generalisation of tools/build_cow_michael_face_cell.py (2026-09-12). Same idea: a TEMPLATE
cell off face_atlas_v5 supplies the FRAME (ears, neck, background, outer hair mass) that
tools/project_cow_head_uvs.measure_cell asserts on, and a DONOR head off face_source/
newfaceatlas.png (36 genuinely distinct painted men, 9x4, 101x220 px) is thin-plate-spline
warped so its landmarks land on the frame's landmark pixels. Michael's builder had the donor
landmarks hand-read off a zoom; this one DETECTS them (pupils = dark blob on a bright ring,
lip line, nostril row, chin/collar transition, hairline, face outline by walking out from the
centre until the skin stops) and writes an overlay with --landmarks so the read can be checked
by eye. Per-man overrides go in WHO[...]["don_override"].

Caleb's rulings 2026-09-13 (verbatim): "McCleary is a larger and bulkier dude with large
forarms and a larger jaw always chewing on a cigar and has a bandana on most the time but
someitmes has a helmet. Lt Champs is a younger but sharp black guy with a real cool head on
his shoulders."

  mccleary  donor newfaceatlas row 1 col 0 (0-based): square heavy jaw, buzz cut, hard level
            eyes, closed mouth (the page, Issue 2 p4: heavy furrowed brow, narrowed eyes, big
            broad nose, deep nasolabial folds, wide clenched mouth, stubble on the wide jaw).
            Frame = face_atlas_v5 (2,9), the same light-skin frame as Michael. Edits: jaw
            targets pushed 3 px out each side and the chin corners 3.5 px (the "larger jaw"),
            stubble noise over the jaw/chin, grey flecks in the temples (he is 30s, older than
            the grunts), brows lowered 1.5 px at the inner ends (the page's furrow), lip line
            deepened and the right corner (viewer's left) opened a shade for the cigar mesh that
            sits there, brown irises, hair dark brown.
  champs    donor newfaceatlas row 0 col 1: young Black man, cropped hair, level brows, steady
            eyes, closed mouth, clean-shaven. Frame = face_atlas_v5 (0,2), a Black template
            cell (dark ears / neck / under-ear skin, so the hands and neck rows the body samples
            off this cell come out the same tone as the face). Edits: none to the expression
            ("real cool head": level brows, closed mouth, steady eyes are what the donor has),
            near-black irises, black hair.

Gates (measure() below is a copy of project_cow_head_uvs.measure_cell's arithmetic on sRGB
bytes/255 - exactly what Blender's Image.pixels hands the projection tool - INCLUDING the
adaptive skin threshold added 2026-09-13 for dark cells): pupils within 1.5 px of the frame's
pupils; mouth row 103-107; corners within 2 px of the frame's; nostril row 90-96; chin 125-134;
hairline 33-43; hair band + dome lum < 0.2 and skin < 0.05; under-ear boxes skin > 0.9; neck
skin > 0.95; both ear boxes > 300 skin px; the cell must differ from Michael's AND Gus's on
> 60% of face pixels (four men, not two).
"""
import os
import sys
import json
import numpy as np
from PIL import Image, ImageDraw

ROOT = r"C:\Users\caleb\RECONgame"
CHAR = os.path.join(ROOT, "assets", "us", "characters")
SRC_TEMPLATE = os.path.join(CHAR, "face_source", "face_atlas_v5.png")     # 1296x1132, 10x7
SRC_DONOR = os.path.join(CHAR, "face_source", "newfaceatlas.png")         # 909x878, 9x4
OTHERS = {"michael": os.path.join(CHAR, "cow_michael_face_cell.png"),      # READ ONLY
          "gus": os.path.join(CHAR, "cow_gus_face_cell.png")}
ARGV = sys.argv[1:]
WHO_ARG = ARGV[ARGV.index("--who") + 1] if "--who" in ARGV else None
PREVIEW = "--preview" in ARGV
LANDMARKS = "--landmarks" in ARGV
SCRATCH = os.path.join(os.environ.get("TEMP", r"C:\Temp"), "cow_face_cell_preview")
CW, CH = 130, 162
DW, DH = 101, 220
CX = 62.5

# The frame's landmark pixels (cell px). Measured on face_atlas_v5 (2,9) for Michael's build;
# the whole light-skin band and the Black band of v5 are the same aligned template so the
# frame pixels hold for every cell (asserted on the chosen frame cell by measure() at build).
TGT_BASE = {
    "pupil_l": (49.0, 73.0), "pupil_r": (76.0, 73.0),
    "brow_l": (49.0, 66.0), "brow_r": (76.0, 66.0), "brow_c": (CX, 66.0),
    "brow_in_l": (55.5, 66.0), "brow_in_r": (69.5, 66.0),
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

WHO = {
    "mccleary": dict(
        template=(2, 9), donor=(1, 0),
        hair_rgb=(0.120, 0.085, 0.058),          # dark brown
        iris_rgb=(0.30, 0.20, 0.12),             # brown
        tgt_override={"jaw_l": (35.5, 106.0), "jaw_r": (89.5, 106.0),
                      "chin_l": (44.0, 124.5), "chin_r": (81.0, 124.5),
                      "cheek_l": (34.0, 90.0), "cheek_r": (91.0, 90.0),
                      "brow_in_l": (55.5, 67.5), "brow_in_r": (69.5, 67.5),   # furrowed inner ends
                      "lip_low": (62.2, 110.0)},
        stubble=True, grey_temples=False, cigar_corner="r", dark=False,
        skin_pull=0.40,
        # read off the luminance dump (tools/build_cow_face_cell.py --landmarks overlay + a 2 px
        # text map): sclera at x 29/35 and 56/62 on row 86, pupils between
        don_override={"pupil_l": (32.0, 86.0), "pupil_r": (60.0, 86.0)}),
    "champs": dict(
        template=(0, 2), donor=(0, 1),
        hair_rgb=(0.045, 0.036, 0.030),          # black
        iris_rgb=(0.14, 0.09, 0.06),             # near-black brown
        tgt_override={},
        stubble=False, grey_temples=False, cigar_corner=None, dark=True,
        skin_pull=0.35,
        # sclera at x 28/34 and 58/66 on row 88, pupils between (the dump)
        don_override={"pupil_l": (31.0, 87.5), "pupil_r": (62.0, 87.5)}),
}


# --------------------------------------------------------------------------------------------
# helpers (numpy only - no scipy on this box)
# --------------------------------------------------------------------------------------------
def cell(sheet, cols, rows, r, c, w, h):
    W, H = sheet.size
    x0, y0 = int(round(c * W / cols)), int(round(r * H / rows))
    return np.array(sheet.crop((x0, y0, x0 + w, y0 + h)).convert("RGB")).astype(np.float32) / 255.0


def lum(a):
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


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


def skin_thr(a):
    """Adaptive skin luminance threshold - the 2026-09-13 rule shared with
    project_cow_head_uvs.measure_cell: 0.30 on a light cell, 0.6 x the neck luminance on a
    dark one (a Black cell's neck reads 0.28, under the old fixed 0.30)."""
    neck = float(lum(a)[131:150, 38:90].mean())
    return min(0.30, 0.6 * neck), neck


def skin_mask(a, thr=0.30):
    return (lum(a) > thr) & (a[..., 0] > a[..., 2] + 0.08)


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


# --------------------------------------------------------------------------------------------
# the projection tool's detector, copied (with the adaptive threshold) so the gates here are the
# gates there
# --------------------------------------------------------------------------------------------
def measure(a):
    l = lum(a)
    ls = box3(l)
    thr, neck_l = skin_thr(a)
    skin = skin_mask(a, thr)
    f = {"skin_thr": round(thr, 3)}
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
    cb = ls[my + 12: my + 38, 55:75].mean(axis=1)
    f["chin_y"] = my + 12 + int(cb.argmin())
    nb = ls[int(ey) + 5: my - 8, 60:71]
    iy, ix = np.unravel_index(nb.argmax(), nb.shape)
    hi_y = int(ey) + 5 + iy
    r0, r1 = int(ey) + 12, my - 9
    nband = ls[r0:r1, 54:72].mean(axis=1)
    nostril_y = r0 + int(nband.argmin())
    f["nose_tip_y"] = (hi_y + nostril_y) / 2.0
    f["nostril_y"] = nostril_y
    mrow = ls[my - 1:my + 2, :].mean(axis=0)
    skin_l, line_l = float(mrow[xm0 - 12:xm0 - 4].mean()), float(mrow[xm0:xm1].min())
    t = 0.5 * (skin_l + line_l)
    mxc = int(round(f["mouth"][0]))

    def cross(step):
        x = mxc
        while 3 < x < CW - 4 and mrow[x] < t:
            x += step
        p, q = mrow[x - step], mrow[x]
        return x - step + step * (t - p) / (q - p) if q != p else float(x)
    f["mouth_l"], f["mouth_r"] = cross(-1), cross(1)
    bys = []
    for (ex, ey_) in eyes:
        colp = ls[ey_ - 11:ey_ - 3, ex - 1:ex + 2].mean(axis=1)
        bys.append(ey_ - 11 + int(colp.argmin()))
    f["brow_y"] = (bys[0] + bys[1]) / 2.0
    col = ls[:, 55:75].mean(axis=1)
    hair_t = 0.28 * min(1.0, neck_l / 0.50)
    f["hair_y"] = int(np.argmax(col > hair_t))
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


# --------------------------------------------------------------------------------------------
# donor landmark detection (donor cell px, 101x220)
# --------------------------------------------------------------------------------------------
def donor_fg(Dn):
    """head = warm pixels or near-black (hair core); the sheet's neutral grey background and its
    halo fail both. Collar (green: g > r) excluded."""
    fg = ((Dn[..., 0] - Dn[..., 2] > 0.035) | (lum(Dn) < 0.10)) & ~(Dn[..., 1] > Dn[..., 0] + 0.02)
    return fg


def detect_donor(Dn, override=None):
    """Landmarks on a newfaceatlas cell. Every number here is checked by --landmarks (overlay) and
    by the gates on the finished cell; the priors only choose the search windows."""
    L = lum(Dn)
    Ls = box3(L)
    fg = donor_fg(Dn)
    warm = (Dn[..., 0] > Dn[..., 2] + 0.06)
    d = {}
    # pupils = the dark pixel BETWEEN the two sclera highlights of one eye (the two brightest
    # points 3-7 px either side on the same row). Holds for a light head (McCleary's donor: 29/35
    # bright, 32 dark) and a dark one (Champs': sclera 28/34 and 58/66 are the brightest things
    # in the eye region). Blob-on-ring, side-contrast and two-minima profiles were each tried on
    # 2026-09-13 and each found corners, nostrils or brow ends on one of the two donors.
    fx_l = next(x for x in range(2, DW // 2) if warm[95, x] and Ls[95, x] > 0.12)
    fx_r = next(x for x in range(DW - 3, DW // 2, -1) if warm[95, x] and Ls[95, x] > 0.12)
    fw = fx_r - fx_l
    cand = {"l": [], "r": []}
    for side, (f0, f1) in (("l", (0.10, 0.42)), ("r", (0.58, 0.90))):
        x0, x1 = int(fx_l + f0 * fw), int(fx_l + f1 * fw)
        for y in range(70, 112):
            for x in range(x0, x1):
                bl = float(L[y - 1:y + 2, x - 7:x - 2].max())
                br = float(L[y - 1:y + 2, x + 3:x + 8].max())
                dk = float(Ls[y, x])
                if min(bl, br) < dk + 0.08:
                    continue
                cand[side].append((min(bl, br) - dk - 0.3 * abs(bl - br), x, y))
    best, bs = {}, -1e9
    for sl, xl, yl in sorted(cand["l"], reverse=True)[:80]:
        for sr, xr, yr in sorted(cand["r"], reverse=True)[:80]:
            if abs(yl - yr) <= 2 and 24 <= xr - xl <= 42 and sl + sr > bs:
                bs, best = sl + sr, {"l": (float(xl), float(yl)), "r": (float(xr), float(yr))}
    assert best, "no sclera pair found"
    if override:
        for k in ("pupil_l", "pupil_r"):
            if k in override:
                best[k[-1]] = override[k]
    d["pupil_l"], d["pupil_r"] = best["l"], best["r"]
    ey = (d["pupil_l"][1] + d["pupil_r"][1]) / 2.0
    exl, exr = d["pupil_l"][0], d["pupil_r"][0]
    cx = (exl + exr) / 2.0
    # lip line: darkest 3-row band between the pupils' columns, 35-70 px under the eyes
    xm0, xm1 = int(exl) + 4, int(exr) - 4
    r0 = int(ey) + 35
    band = Ls[r0:int(ey) + 70, xm0:xm1].mean(axis=1)
    my = r0 + int(band.argmin())
    mrow = Ls[my - 1:my + 2, :].mean(axis=0)
    skin_l, line_l = float(mrow[xm0 - 10:xm0 - 3].mean()), float(mrow[xm0:xm1].min())
    t = 0.5 * (skin_l + line_l)
    mxc = int(round(cx))

    def cross(step):
        x = mxc
        while 4 < x < DW - 5 and mrow[x] < t:
            x += step
        p, q = mrow[x - step], mrow[x]
        return x - step + step * (t - p) / (q - p) if q != p else float(x)
    ml, mr = cross(-1), cross(1)
    d["mouth_l"], d["mouth_r"], d["mouth_c"] = (ml, float(my)), (mr, float(my)), ((ml + mr) / 2.0, float(my))
    d["lip_low"] = ((ml + mr) / 2.0, my + 7.0)
    # nostril row: darkest band under the nose, centre columns
    n0, n1 = int(ey) + 15, my - 8
    nb = Ls[n0:n1, int(cx) - 8:int(cx) + 9].mean(axis=1)
    ny = n0 + int(nb.argmin())
    d["nostril_c"] = (cx, float(ny))
    d["wing_l"], d["wing_r"] = (cx - 9.0, ny - 1.0), (cx + 9.0, ny - 1.0)
    d["nose_bridge"] = (cx, ey + 15.0)
    # chin: the under-chin shadow is the darkest centre-column band 15-45 px under the lip line
    # (walking down "while skin" runs straight through the neck to the collar - measured)
    cb = Ls[my + 15:my + 45, int(cx) - 5:int(cx) + 6].mean(axis=1)
    shadow_y = my + 15 + int(cb.argmin())
    chin = shadow_y - 4
    d["chin_bottom"] = (cx, float(chin))
    d["chin_shadow"] = (cx, float(shadow_y))
    # hairline: from the top, first row where the centre columns are warm skin
    colw = warm[:, int(cx) - 4:int(cx) + 5].mean(axis=1)
    coll = Ls[:, int(cx) - 4:int(cx) + 5].mean(axis=1)
    hl = next(y for y in range(5, int(ey)) if colw[y] > 0.6 and coll[y] > 0.6 * coll[int(ey) - 20])
    d["hairline_c"] = (cx, float(hl))
    # hair top / sides
    fgc = fg[:, int(cx) - 3:int(cx) + 4].mean(axis=1)
    d["hair_top"] = (cx, float(next(y for y in range(DH) if fgc[y] > 0.5)))
    hy = int(d["hair_top"][1]) + 33
    row = np.nonzero(fg[hy])[0]
    d["hair_l"], d["hair_r"] = (float(row.min()), float(hy)), (float(row.max()), float(hy))
    # brows: darkest 3-row band above each pupil
    for side, ex in (("l", exl), ("r", exr)):
        colp = Ls[int(ey) - 16:int(ey) - 4, int(ex) - 1:int(ex) + 2].mean(axis=1)
        by = int(ey) - 16 + int(colp.argmin())
        d["brow_" + side] = (ex, float(by))
    d["brow_c"] = (cx, (d["brow_l"][1] + d["brow_r"][1]) / 2.0 + 2.0)
    d["brow_in_l"] = (exl + (cx - exl) * 0.5, d["brow_l"][1] + 0.5)
    d["brow_in_r"] = (exr - (exr - cx) * 0.5, d["brow_r"][1] + 0.5)
    for side, ex in (("l", exl), ("r", exr)):
        d["lid_up_" + side] = (ex, ey - 3.5)
        d["lid_lo_" + side] = (ex, ey + 3.5)

    # face outline = the head SILHOUETTE (fg mask) per row minus the ear allowance: these heads
    # have no dark crease between cheek and ear (measured on (1,0)), and a gradient search lands on
    # the ear's outer edge. Ears span the eye row to the nose base and are 9-11 px wide on this
    # sheet (Michael's donor: sideburn+ear x 11-21), so: eye row -10, nostril row -9, mouth row
    # and chin-corner row are below the ears (-1 / -2 for the jaw shadow). --landmarks writes the
    # overlay; a wrong edge is corrected in WHO[who]["don_override"].
    def sil(y, lit=False):
        m = fg[int(y), 4:DW - 4]
        if lit:                      # below the ears the jaw shadow is warm too: keep the lit skin only
            m = m & (Ls[int(y), 4:DW - 4] > 0.5 * float(Ls[int(y), 4:DW - 4].max()))
        # the run through the face axis, tolerating gaps up to 8 px (the eyes' neutral grey and
        # their catch lights fail the warm-or-black test and punch holes in the row - measured on
        # (1,0) row 86); an ear lobe is a separate island further out than any gap
        def run(x, step):
            while 0 < x < len(m) - 1:
                nxt = x + step
                if m[nxt]:
                    x = nxt
                elif any(m[nxt + step * k] for k in range(1, 9) if 0 <= nxt + step * k < len(m)):
                    x = nxt
                else:
                    break
            return x
        x = int(cx) - 4
        lo, hi = run(x, -1), run(x, 1)
        return float(lo + 4), float(hi + 4)
    sl, sr = sil(ey)
    fl_, fr_ = sl + 10.0, sr - 10.0
    d["face_l_eye"], d["face_r_eye"] = (fl_, ey), (fr_, ey)
    sl, sr = sil(ny)
    d["cheek_l"], d["cheek_r"] = (sl + 9.0, float(ny)), (sr - 9.0, float(ny))
    sl, sr = sil(my - 3, lit=True)          # 3 rows above the lip line: the run must start on lit skin
    d["jaw_l"], d["jaw_r"] = (sl + 1.0, float(my)), (sr - 1.0, float(my))
    cy_ = int(chin) - 5
    # chin corners: 22% of the jaw width in from each jaw corner (the silhouette at this row runs
    # into the ear lobes and the jaw shadow on both donors - measured)
    jw = d["jaw_r"][0] - d["jaw_l"][0]
    d["chin_l"], d["chin_r"] = (d["jaw_l"][0] + 0.22 * jw, float(cy_)), (d["jaw_r"][0] - 0.22 * jw, float(cy_))
    sk_ref = float(L[int(ey) + 25:int(ey) + 35, int(cx) - 12:int(cx) + 12].mean())
    # temples: hairline at the face-edge columns
    for side, fx in (("l", d["face_l_eye"][0]), ("r", d["face_r_eye"][0])):
        xcol = int(fx) + (4 if side == "l" else -4)
        cw_ = warm[:, xcol - 2:xcol + 3].mean(axis=1)
        cl_ = Ls[:, xcol - 2:xcol + 3].mean(axis=1)
        ty = next((y for y in range(5, int(ey)) if cw_[y] > 0.6 and cl_[y] > 0.5 * sk_ref), hl + 6)
        d["temple_" + side] = (float(xcol), float(ty))
    if override:
        d.update(override)
    return d


def overlay(img, pts, z, path, color=(0, 255, 0)):
    H, W = img.shape[:2]
    big = Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)).resize((W * z, H * z), Image.NEAREST)
    dr = ImageDraw.Draw(big)
    for x in range(0, W, 10):
        dr.line([(x * z, 0), (x * z, H * z)], fill=(0, 90, 0), width=1)
    for y in range(0, H, 10):
        dr.line([(0, y * z), (W * z, y * z)], fill=(0, 90, 0), width=1)
    for k, (x, y) in pts.items():
        X, Y = (x + 0.5) * z, (y + 0.5) * z
        dr.ellipse([X - 3, Y - 3, X + 3, Y + 3], outline=color, width=2)
        dr.text((X + 4, Y - 4), k, fill=(255, 255, 0))
    big.save(path)


# --------------------------------------------------------------------------------------------
def build(who):
    cfg = WHO[who]
    OUT = os.path.join(CHAR, "cow_%s_face_cell.png" % who)
    T = cell(Image.open(SRC_TEMPLATE), 10, 7, cfg["template"][0], cfg["template"][1], CW, CH)
    Dn = cell(Image.open(SRC_DONOR), 9, 4, cfg["donor"][0], cfg["donor"][1], DW, DH)
    assert T.shape == (CH, CW, 3) and Dn.shape == (DH, DW, 3)
    tm_ = measure(T)
    print("frame cell %s landmarks:" % (cfg["template"],), {k: tm_[k] for k in ("eye_l", "eye_r", "mouth", "mouth_l", "mouth_r", "nostril_y", "chin_y", "hair_y", "brow_y", "skin_thr")})
    print("frame regions:", {k: tm_[k] for k in ("hair_band", "under_ear_l", "under_ear_r", "neck")})
    # the frame must carry the pupils/mouth where TGT says (the template family is aligned)
    for k, want in (("eye_l", TGT_BASE["pupil_l"]), ("eye_r", TGT_BASE["pupil_r"])):
        assert np.hypot(tm_[k][0] - want[0], tm_[k][1] - want[1]) <= 3.0, ("frame pupil off TGT", k, tm_[k], want)
    TGT = dict(TGT_BASE)
    # the frame's own feature rows (the Black template head is aligned a little differently from
    # the light one: pupils row 72, mouth 103, nostril 90, hairline 42 on (0,2) vs 73/105/93/38)
    dxl, dxr = tm_["eye_l"][0] - 49.0, tm_["eye_r"][0] - 76.0
    dy_e = (tm_["eye_l"][1] + tm_["eye_r"][1]) / 2.0 - 73.0
    dy_m = tm_["mouth"][1] - 105.0
    dy_n = tm_["nostril_y"] - 93.0
    dy_h = tm_["hair_y"] - 38.0
    for k in ("pupil_l", "brow_l", "brow_in_l", "lid_up_l", "lid_lo_l"):
        TGT[k] = (TGT[k][0] + dxl, TGT[k][1] + dy_e)
    for k in ("pupil_r", "brow_r", "brow_in_r", "lid_up_r", "lid_lo_r"):
        TGT[k] = (TGT[k][0] + dxr, TGT[k][1] + dy_e)
    TGT["brow_c"] = (TGT["brow_c"][0], TGT["brow_c"][1] + dy_e)
    TGT["face_l_eye"] = (TGT["face_l_eye"][0], TGT["face_l_eye"][1] + dy_e)
    TGT["face_r_eye"] = (TGT["face_r_eye"][0], TGT["face_r_eye"][1] + dy_e)
    for k in ("mouth_l", "mouth_r", "mouth_c", "lip_low", "jaw_l", "jaw_r"):
        TGT[k] = (TGT[k][0], TGT[k][1] + dy_m)
    for k in ("nostril_c", "wing_l", "wing_r"):
        TGT[k] = (TGT[k][0], TGT[k][1] + dy_n)
    TGT["nose_bridge"] = (TGT["nose_bridge"][0], TGT["nose_bridge"][1] + 0.5 * (dy_e + dy_n))
    for k in ("hairline_c", "temple_l", "temple_r"):
        TGT[k] = (TGT[k][0], TGT[k][1] + dy_h)
    TGT.update(cfg["tgt_override"])
    DON = detect_donor(Dn, cfg.get("don_override"))
    print("donor %s detected landmarks:" % (cfg["donor"],))
    for k in sorted(DON):
        print("   %-12s (%.1f, %.1f)" % (k, DON[k][0], DON[k][1]))
    if LANDMARKS:
        os.makedirs(SCRATCH, exist_ok=True)
        overlay(Dn, DON, 5, os.path.join(SCRATCH, "%s_donor_landmarks.png" % who))
        overlay(T, TGT, 4, os.path.join(SCRATCH, "%s_frame_targets.png" % who), color=(0, 200, 255))
        print("landmark overlays ->", SCRATCH)

    thr_t, neck_t = skin_thr(T)
    # ---- skin colour match: donor face skin stats -> frame cheek stats (multiplicative) ---------
    ds = donor_fg(Dn) & (Dn[..., 0] > Dn[..., 2] + 0.06)
    ds[:int(DON["brow_c"][1]) + 4] = False
    ds[int(DON["chin_bottom"][1]) - 2:] = False
    ds[:, :int(DON["face_l_eye"][0]) + 2] = False
    ds[:, int(DON["face_r_eye"][0]) - 1:] = False
    dl = lum(Dn)
    ds &= dl > np.percentile(dl[ds], 35)                 # skin, not the eyes/brows/lips/nostrils
    ts = skin_mask(T, thr_t)
    ts[:60] = False
    ts[130:] = False
    ts[:, :34] = False
    ts[:, 93:] = False
    tl = lum(T)
    ts &= tl > np.percentile(tl[ts], 35)
    dm, tm = Dn[ds].mean(0), T[ts].mean(0)
    print("donor skin mean %s -> frame skin mean %s" % (np.round(dm, 3), np.round(tm, 3)))
    Dm = np.clip(Dn * (tm / dm), 0, 1)
    soft = donor_fg(Dn) & (Dm[..., 0] > Dm[..., 2] + 0.06) & (lum(Dm) > 0.5 * float(lum(Dm)[ds].mean()))
    Dm[soft] = Dm[soft] * (1 - cfg["skin_pull"]) + tm * cfg["skin_pull"]

    # ---- donor foreground: the head, its own ears and collar cut off --------------------------
    fg = donor_fg(Dn)
    fg[int(DON["chin_bottom"][1]) + 4:] = False
    fg[:, :6] = False
    fg[:, DW - 6:] = False
    yy, xx = np.mgrid[0:DH, 0:DW]
    fl, fr = DON["face_l_eye"][0], DON["face_r_eye"][0]
    ey_d = DON["pupil_l"][1]
    fg &= ~((yy > ey_d - 20) & ((xx < fl - 1) | (xx > fr + 1)))        # the donor's ears: the frame's are kept
    jl, jr = DON["jaw_l"][0], DON["jaw_r"][0]
    fg &= ~((yy > DON["mouth_c"][1] - 6) & ((xx < jl - 1) | (xx > jr + 1)))
    cl, cr = DON["chin_l"][0], DON["chin_r"][0]
    fg &= ~((yy > DON["chin_l"][1] - 3) & ((xx < cl - 2) | (xx > cr + 2)))

    # ---- TPS warp, target -> donor, sampled bilinearly ------------------------------------------
    keys = [k for k in TGT if k in DON]
    f = tps_fit([TGT[k] for k in keys], [DON[k] for k in keys])
    ty, tx = np.mgrid[0:CH, 0:CW]
    pts = np.stack([tx.ravel() + 0.5, ty.ravel() + 0.5], 1)
    src = f(pts) - 0.5
    warped = sample_bilinear(Dm, src).reshape(CH, CW, 3)
    wmask = sample_bilinear(fg.astype(np.float32)[..., None], src).reshape(CH, CW)
    wmask = (wmask > 0.5).astype(np.float32)
    inside = (src[:, 0] > 1) & (src[:, 0] < DW - 2) & (src[:, 1] > 1) & (src[:, 1] < DH - 2)
    wmask *= inside.reshape(CH, CW)
    cy, cx = np.mgrid[0:CH, 0:CW]
    wmask[(cy > 60) & ((cx < 33) | (cx > 96))] = 0
    wmask[cy >= 131] = 0
    alpha = np.clip(blur(wmask, 2) * 1.15 - 0.05, 0, 1)
    if cfg.get("keep_template_hair", True):
        # a buzz cut / cropped donor has no fringe worth keeping and its hair warps into a flat
        # block over the frame's rounder hair mass (measured on (1,0)); blend the donor in from
        # the hairline down and leave the frame's hair alone
        hl_y = TGT["hairline_c"][1]
        alpha *= np.clip((cy - (hl_y + 1)) / 7.0, 0, 1)
    else:
        soft_hair = blur(wmask, 5)
        alpha = np.where(cy < 62, soft_hair, alpha)

    out = T.copy()
    out = out * (1 - alpha[..., None]) + warped * alpha[..., None]
    skin_o = skin_mask(out, thr_t)
    # forehead skin between fringe strands above row 36 -> hair (hair band rows 14-35 must be < 5% skin)
    peek = (alpha > 0.5) & (cy <= 37) & skin_o
    ramp = 0.28 + 0.72 * np.clip((cy - 29) / 8.0, 0, 1)
    out[peek] = out[peek] * ramp[peek][:, None]
    HAIR_RGB = np.array(cfg["hair_rgb"], np.float32)
    hair_don = (alpha > 0.5) & (lum(out) < max(0.30, thr_t + 0.02)) & (cy < 50) & ~skin_mask(out, thr_t)
    if hair_don.sum() > 20:
        mean = out[hair_don].mean(0)
        out[hair_don] = np.clip(out[hair_don] * (HAIR_RGB / np.maximum(mean, 1e-3)), 0, 0.6)
    band_mean = T[14:35, 23:105].reshape(-1, 3).mean(0)
    hair_tpl = (alpha <= 0.5) & (cy < 62) & ~skin_mask(T, thr_t) & (lum(T) < 0.30) & (lum(T) > 0.075) & (cx > 12) & (cx < 118)
    out[hair_tpl] = np.clip(out[hair_tpl] * (HAIR_RGB / np.maximum(band_mean, 1e-3)), 0, 0.6)
    hm = blur((hair_don | hair_tpl).astype(np.float32), 1)
    sm = blur(out, 1)
    seam = ((alpha > 0.1) & (alpha < 0.9) & (cy < 50))[..., None] * hm[..., None]
    out = out * (1 - seam) + sm * seam

    # ---- the frame's jaw outside the new outline -> side shadow ------------------------------
    fill = T * (0.62 if cfg["dark"] else 0.74)
    wedge = (alpha < 0.5) & (cy >= 76) & (cy < 131) & (cx > 31) & (cx < 96) & (lum(T) > (0.85 * neck_t if cfg["dark"] else 0.47))
    wa = blur(wedge.astype(np.float32), 3)
    wa = np.clip(wa * 1.3, 0, 1) * (1 - alpha)
    out = out * (1 - wa[..., None]) + fill * wa[..., None]

    # ---- lip line: deepen along the painted mouth so it reads at 75 px and the corners pin -----
    lx0, lx1 = TGT["mouth_l"][0], TGT["mouth_r"][0]
    for y, k in (((104, 0.88), (105, 0.72), (106, 0.85)) if cfg["dark"] else ((104, 0.80), (105, 0.55), (106, 0.75))):
        xs = np.arange(CW)
        end = np.clip(np.minimum(xs - lx0 + 1.5, lx1 - xs + 1.5) / 3.0, 0, 1)
        out[y] = out[y] * (1 - end[:, None] * (1 - k))

    # ---- symmetric lighting: mirror the lit half across the pupil axis over the face rows ------
    lit_left = float(lum(out)[80:100, 38:50].mean()) > float(lum(out)[80:100, 76:88].mean())
    mirrored = out[:, ::-1]
    shift = int(round(2 * CX)) - (CW - 1)
    mirrored = np.roll(mirrored, shift, axis=1)
    if lit_left:
        side_w = np.clip((cx - CX) / 6.0, 0, 1)
    else:
        side_w = np.clip((CX - cx) / 6.0, 0, 1)
    right = side_w * (alpha > 0.5) * np.clip((cy - 36) / 12.0, 0, 1) * (cy < 131)
    out = out * (1 - right[..., None]) + mirrored * right[..., None]
    # ---- side-quad bands: vertical 5-tap blur on the near-edge columns, face rows only ---------
    for x0, x1 in ((34, 47), (78, 91)):
        band = out[60:131, x0:x1]
        v = band.copy()
        for _ in range(2):
            v = (np.roll(v, 1, 0) + v + np.roll(v, -1, 0)) / 3.0
        out[62:129, x0:x1] = v[2:-2]

    # ---- jaw contour: lift the donor's dark jaw outline into the frame's side shadow ----------
    Lo = lum(out)
    shadow = T[102:127, 98:113].reshape(-1, 3).mean(0)
    jaw = (alpha > 0.5) & (cy >= 98) & (cy < 131) & (Lo < 0.75 * float(Lo[skin_o & (cy > 80) & (cy < 100)].mean())) & (Lo > 0.06) & (((cx < 52) | (cx > 73)) | (cy >= 118))
    jaw &= ~((cy >= 102) & (cy <= 108) & (cx >= 50) & (cx <= 75))
    if not cfg["dark"]:
        out[jaw] = out[jaw] * 0.3 + shadow * 0.7
    else:
        # on a dark cell the frame's under-ear shadow is LIGHTER than the jaw skin and that lift
        # painted a pale block on Champs' jaw; and left alone his jaw/under-chin contour read as a
        # goatee. Lift it toward the cell's OWN cheek skin at 70% brightness (a soft shadow).
        own = out[(alpha > 0.5) & (cy > 80) & (cy < 100) & skin_mask(out, thr_t)].reshape(-1, 3).mean(0) * 0.70
        out[jaw] = out[jaw] * 0.35 + own * 0.65

    # ---- stubble (McCleary): a SMOOTH 9% darkening of the jaw/chin zone with 3% fine noise.
    # Dots were tried first (26% density, x0.84) and read as a rash on the 900 px portrait render
    # - the same lesson as Gus's freckles (blender_notes 2026-09-09): at ~25 px per cheek a
    # dot is a lesion. Shadow, not stipple.
    if cfg["stubble"]:
        rng = np.random.default_rng(19670814)
        noise = rng.random((CH, CW)).astype(np.float32)
        half_w = 24.0 - np.clip((cy - 108) / 22.0, 0, 1) * 9.0          # jaw 24 px half-width -> chin 15
        zone = (alpha > 0.5) & (cy >= 100) & (cy < 130) & (np.abs(cx - CX) < half_w)
        zone &= ~((cy >= 102) & (cy <= 108) & (cx >= 50) & (cx <= 75))     # not the lips
        zone &= ~((cy < 108) & (np.abs(cx - CX) < 12))                     # not the philtrum
        zw = blur(zone.astype(np.float32), 3)
        out = out * (1 - ((0.09 + 0.03 * (noise - 0.5)) * zw)[..., None])
    # ---- grey temples (McCleary, 30s): the frame's own sideburn hair, a third of its pixels lifted
    if cfg["grey_temples"]:
        rng = np.random.default_rng(1944)
        noise = rng.random((CH, CW)).astype(np.float32)
        tz = (cy >= 38) & (cy <= 60) & ((cx < 38) | (cx > 92)) & (cx > 22) & (cx < 106) & ~skin_mask(out, thr_t) & (lum(out) < 0.22) & (lum(out) > 0.06)
        g = tz & (noise < 0.20)
        out[g] = np.clip(out[g] * 1.35 + 0.02, 0, 0.26)
    # ---- cigar corner (McCleary): the lips part a shade where the cigar mesh enters -----------
    if cfg["cigar_corner"]:
        xcorner = lx1 - 2.0 if cfg["cigar_corner"] == "r" else lx0 + 2.0
        r = np.sqrt(((cx - xcorner) / 3.0) ** 2 + ((cy - 105.5) / 1.8) ** 2)
        k = np.clip(1.0 - r, 0, 1) * 0.55
        out = out * (1 - k[..., None])

    # ---- tone match: the composited face's skin mean -> the frame's face skin mean (the donor's
    # skin is greyer than the frame's on the Black band - measured 2026-09-13 on the preview)
    fm = (alpha > 0.5) & (cy > 76) & (cy < 100) & skin_mask(out, thr_t)
    tm2 = T[(cy > 76) & (cy < 100) & skin_mask(T, thr_t) & (cx > 36) & (cx < 90)].reshape(-1, 3).mean(0)
    om = out[fm].reshape(-1, 3).mean(0)
    gain = np.clip(tm2 / np.maximum(om, 1e-3), 0.7, 1.4)
    print("tone match: face skin mean %s -> frame %s (gain %s)" % (np.round(om, 3), np.round(tm2, 3), np.round(gain, 3)))
    fa = (alpha > 0.5)[..., None] * (cy > 40)[..., None]
    out = np.clip(out * (1 - fa) + out * gain * fa, 0, 1)

    # ---- nose-tip catch light ------------------------------------------------------------------
    r = np.sqrt(((cx - 62.0) / 3.0) ** 2 + ((cy - 88.0) / 1.8) ** 2)
    tip = np.clip(1.0 - r, 0, 1) * 0.14
    out = np.clip(out * (1 + tip[..., None]), 0, 1)

    # ---- irises + pupils + brows ---------------------------------------------------------------
    IRIS = np.array(cfg["iris_rgb"], np.float32)
    for (px, py) in (TGT["pupil_l"], TGT["pupil_r"]):
        r = np.sqrt((cx - px) ** 2 + (cy - py) ** 2)
        iris = (r <= 2.6) & (lum(out) < 0.45) & (lum(out) > 0.08)
        L = lum(out)[iris][:, None]
        out[iris] = np.clip(IRIS * (L / max(0.2, float(lum(IRIS)))), 0, 0.62)
        pupil = (r <= 1.6)
        out[pupil] = np.minimum(out[pupil], 0.05)
    brow = (cy >= 58) & (cy <= 70) & (cx >= 34) & (cx <= 91) & (lum(out) < 0.11) & ~skin_mask(out, thr_t)
    for (px, py) in (TGT["pupil_l"], TGT["pupil_r"]):
        brow &= np.sqrt((cx - px) ** 2 + (cy - py) ** 2) > 3.5
    out[brow] = out[brow] * (0.13 / np.maximum(lum(out)[brow], 1e-3))[:, None]

    out = np.clip(out, 0, 1)
    img = Image.fromarray((out * 255 + 0.5).astype(np.uint8))
    img.save(OUT)
    print("wrote", OUT, img.size, "%.1f KB" % (os.path.getsize(OUT) / 1024.0))

    # ---- gates ----------------------------------------------------------------------------------
    a = np.array(Image.open(OUT).convert("RGB")).astype(np.float32) / 255.0
    m = measure(a)
    print("NEW landmarks:", {k: m[k] for k in ("eye_l", "eye_r", "mouth", "mouth_l", "mouth_r", "nostril_y", "nose_tip_y", "chin_y", "hair_y", "brow_y", "ear_l", "ear_r", "ear_l_px", "ear_r_px", "skin_thr")})
    print("NEW regions:", {k: m[k] for k in ("hair_band", "hair_dome", "under_ear_l", "under_ear_r", "neck")})
    for k, want in (("eye_l", TGT["pupil_l"]), ("eye_r", TGT["pupil_r"])):
        dd = np.hypot(m[k][0] - want[0], m[k][1] - want[1])
        assert dd <= 1.5, (k, m[k], want)
    assert abs(m["mouth"][1] - tm_["mouth"][1]) <= 2, (m["mouth"], tm_["mouth"])
    assert abs(m["mouth_l"] - TGT["mouth_l"][0]) <= 2.0 and abs(m["mouth_r"] - TGT["mouth_r"][0]) <= 2.0, (m["mouth_l"], m["mouth_r"])
    assert abs(m["nostril_y"] - tm_["nostril_y"]) <= 3, (m["nostril_y"], tm_["nostril_y"])
    assert abs(m["nose_tip_y"] - (tm_["nostril_y"] - 2.5)) <= 3.5, ("nose_tip", m["nose_tip_y"], tm_["nostril_y"])
    assert abs(m["chin_y"] - tm_["chin_y"]) <= 5, (m["chin_y"], tm_["chin_y"])
    assert abs(m["hair_y"] - tm_["hair_y"]) <= 5, (m["hair_y"], tm_["hair_y"])
    assert 100 < m["mouth"][1] < 110 and 88 <= m["nostril_y"] <= 96 and 123 <= m["chin_y"] <= 134 and 32 <= m["hair_y"] <= 46
    assert m["hair_band"]["lum"] < 0.2 and m["hair_band"]["skin"] < 0.05, m["hair_band"]
    assert m["hair_dome"]["lum"] < 0.2 and m["hair_dome"]["skin"] < 0.05, m["hair_dome"]
    assert m["under_ear_r"]["skin"] > 0.9 and m["under_ear_l"]["skin"] > 0.9, (m["under_ear_r"], m["under_ear_l"])
    assert m["neck"]["skin"] > 0.95, m["neck"]
    assert m["neck"]["lum"] > (0.20 if cfg["dark"] else 0.45), m["neck"]
    assert m["ear_l_px"] > 300 and m["ear_r_px"] > 300, (m["ear_l_px"], m["ear_r_px"])
    face = (slice(40, 131), slice(33, 97))
    for nm, p in OTHERS.items():
        g = np.array(Image.open(p).convert("RGB")).astype(np.float32) / 255.0
        same = (np.abs(a[face] - g[face]).sum(2) < 8 / 255.0).mean()
        corr = np.corrcoef(lum(a[face]).ravel(), lum(g[face]).ravel())[0, 1]
        print("face-region pixels identical to %s's cell: %.1f%%  (luminance corr %.3f)" % (nm, 100 * same, corr))
        assert same < 0.40, (nm, same)
    if who != "champs" and os.path.exists(os.path.join(CHAR, "cow_champs_face_cell.png")):
        g = np.array(Image.open(os.path.join(CHAR, "cow_champs_face_cell.png")).convert("RGB")).astype(np.float32) / 255.0
        same = (np.abs(a[face] - g[face]).sum(2) < 8 / 255.0).mean()
        print("face-region pixels identical to champs's cell: %.1f%%" % (100 * same))
        assert same < 0.40
    if cfg["dark"]:
        # the body's hands/neck sample this cell: the neck rows and the skin under the ears must be
        # the same dark tone as the face, not the light template's
        fl = float(lum(a)[80:100, 40:85].mean())
        nl = m["neck"]["lum"]
        print("dark cell: face lum %.3f, neck lum %.3f, under-ear lum %.3f" % (fl, nl, m["under_ear_r"]["lum"]))
        assert fl < 0.42 and abs(fl - nl) < 0.12, (fl, nl)
    print("GATES PASS")
    def jl(v):
        if isinstance(v, (tuple, list)):
            return [float(x) for x in v]
        if isinstance(v, dict):
            return {k: jl(x) for k, x in v.items()}
        return float(v) if isinstance(v, (np.floating, np.integer, float, int)) else v
    with open(os.path.join(CHAR, "cow_%s_face_cell.json" % who), "w") as fh:
        json.dump({"who": who, "template_cell_row_col": cfg["template"], "donor_cell_row_col": cfg["donor"],
                   "donor_landmarks": {k: jl(v) for k, v in DON.items()},
                   "targets": {k: jl(v) for k, v in TGT.items()},
                   "measured": {k: jl(v) for k, v in m.items()}}, fh, indent=1)
    if PREVIEW:
        os.makedirs(SCRATCH, exist_ok=True)
        Z = 4
        cells = [T, a] + [np.array(Image.open(p).convert("RGB")).astype(np.float32) / 255.0 for p in OTHERS.values()]
        sheet = Image.new("RGB", (CW * Z * len(cells) + 8 * (len(cells) - 1), CH * Z), (255, 255, 255))
        for i, arr in enumerate(cells):
            sheet.paste(Image.fromarray((arr * 255 + 0.5).astype(np.uint8)).resize((CW * Z, CH * Z), Image.NEAREST), (i * (CW * Z + 8), 0))
        p = os.path.join(SCRATCH, "%s_frame_new_michael_gus.png" % who)
        sheet.save(p)
        print("preview (frame | NEW | michael | gus) ->", p)


if __name__ == "__main__":
    if WHO_ARG not in WHO:
        raise SystemExit("usage: --who mccleary|champs")
    build(WHO_ARG)
