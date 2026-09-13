"""build_cow_michael_face_cell.py - Michael Crawford's painted face cell, off a DIFFERENT base head.

    python tools/build_cow_michael_face_cell.py [--preview]

Writes assets/us/characters/cow_michael_face_cell.png (130x162, the CoW cell format).

WHY (Caleb, 2026-09-12): "micheal and gus are sharing the same base face too" -> "give micheal a
different face" -> "i like the way gus face looks." Measured: the old Michael cell (face_atlas_v5 row 2
col 9) and Gus's (row 2 col 7) were 83% pixel-identical. EVERY light-skin cell on face_atlas_v4/v5 is
the same generated template head with different hair/moustache flecks, so no cell on those sheets can
be "a different base". The only sheet in face_source/ with genuinely distinct heads is
newfaceatlas.png (36 painted men, 9x4). Michael's base is its row 3 col 3 (0-based): short dark
tousled fringe on the forehead, low knitted brows, long straight nose with a broad tip, thin pressed
lips, lean cheeks - the closest of the 36 to what the Issue 1 panels draw (p4 eyes, p15 profile +
panic close-up, p16 "Flares").

WHAT STAYS FROM THE TEMPLATE CELL (row 2 col 9, the old Michael cell): the frame only - ears, neck,
warm-brown background and the outer hair mass. tools/project_cow_head_uvs.measure_cell asserts on
those regions (ear skin boxes, dark hair band/dome, skin under the ears, neck rows) and the head mesh's
FRONT affine is solved from the painted pupils / nostrils / mouth / chin / hairline / ear centroids.
So the donor face is WARPED (thin-plate spline, numpy, no scipy on this box) so that its landmarks
land on the OLD cell's landmark pixels: pupils (49,73)/(76,73), nostril row 93, mouth line 105 with
corners 52.2/72.1, chin shadow 128-131, hairline 38. Same feature placement => the game head's UVs and
the talking head's solved face patch (th_build.py) stay valid; only the paint changes.

Reworked to the bible / draft card (bible line 26: eyes BLUE, hair BROWN, 6'2" 155 lb, seventeen):
blue irises, hair recoloured to a brown lighter than Gus's, jaw pulled in (donor jaw 49 px at the
mouth row vs the template's 61), the template's square jaw outside the new outline shaded into the
background, the donor's chin-tuft shadow painted out (the panels draw a clean-shaven kid), mouth
corners a pixel down (worried). No freckles - those are Gus's mark (bible section 2).

Gates (all measured on the written PNG with a copy of measure_cell's arithmetic on sRGB bytes/255,
the same numbers Blender's Image.pixels hands the projection tool):
  pupils within 1.5 px of (49,73)/(76,73); mouth row 104-106; corners within 1.5 px of 52.2/72.1;
  nostril row 91-95; chin 126-133; hairline 34-42; hair band + dome lum < 0.2 and skin < 0.05;
  under-ear boxes skin > 0.9; neck skin > 0.95 lum > 0.45; both ear boxes > 300 skin px;
  and the new cell must differ from Gus's cell on > 60% of face pixels (the thing Caleb saw).
"""
import os
import sys
import numpy as np
from PIL import Image

ROOT = r"C:\Users\caleb\RECONgame"
CHAR = os.path.join(ROOT, "assets", "us", "characters")
SRC_TEMPLATE = os.path.join(CHAR, "face_source", "face_atlas_v5.png")     # 1296x1132, 10x7
SRC_DONOR = os.path.join(CHAR, "face_source", "newfaceatlas.png")         # 909x878, 9x4
OUT = os.path.join(CHAR, "cow_michael_face_cell.png")
GUS = os.path.join(CHAR, "cow_gus_face_cell.png")                         # READ ONLY - compared, never written
PREVIEW = "--preview" in sys.argv
SCRATCH = os.path.join(os.environ.get("TEMP", r"C:\Temp"), "cow_michael_cell_preview")

TEMPLATE_CELL = (2, 9)      # row_from_top, col on face_atlas_v5 - the old Michael cell = the FRAME
DONOR_CELL = (3, 3)         # row, col on newfaceatlas
CW, CH = 130, 162

# ---- donor landmarks, donor-cell pixels (101x220), read off a 10x zoom with a 5 px grid -----------
# (x, y). Pupils cross-checked by the darkest 3x3 in the eye windows (32,105) - the right window's
# argmin lands on the inner canthus shadow at 59, the pupil itself is at 64.5 by eye.
DON = {
    "pupil_l": (31.5, 106.5), "pupil_r": (64.5, 106.5),
    "brow_l": (31.5, 98.0), "brow_r": (64.5, 98.0),
    "brow_c": (48.0, 100.0),
    "brow_in_l": (40.0, 98.5), "brow_in_r": (57.0, 98.5),
    "lid_up_l": (31.5, 102.5), "lid_up_r": (64.5, 102.5),
    "lid_lo_l": (31.5, 110.0), "lid_lo_r": (64.5, 110.0),
    "nostril_c": (48.0, 142.0), "wing_l": (39.0, 141.0), "wing_r": (57.0, 141.0),
    "nose_bridge": (48.0, 122.0),
    # mouth: the dark line between the lips runs donor x 33-58 (12x zoom + luminance dump), centre
    # 45.5 - the donor's mouth sits 2.5 px LEFT of his pupil centre (48). Mapped by its own centre.
    "mouth_l": (33.0, 159.0), "mouth_r": (58.0, 159.0), "mouth_c": (45.5, 159.0),
    "lip_low": (45.5, 166.0),
    "chin_bottom": (47.5, 184.0), "chin_shadow": (47.5, 190.0),
    # left side: the donor's sideburn covers x 11-21 at eye level, so his SKIN edge is 22 (the
    # first pass used 17 and the warped cheek stopped 10 px short of the template's outline)
    "face_l_eye": (22.0, 106.0), "face_r_eye": (81.0, 106.0),
    "cheek_l": (21.0, 130.0), "cheek_r": (79.0, 130.0),
    "jaw_l": (22.0, 160.0), "jaw_r": (76.0, 160.0),
    "chin_l": (32.0, 180.0), "chin_r": (66.0, 180.0),
    "hairline_c": (48.0, 66.0), "temple_l": (22.0, 72.0), "temple_r": (75.0, 72.0),
    "hair_top": (48.0, 12.0), "hair_l": (13.0, 45.0), "hair_r": (83.0, 45.0),
}
# ---- targets, cell pixels (130x162): the OLD Michael cell's measured landmarks --------------------
CX = 62.5
TGT = {
    "pupil_l": (49.0, 73.0), "pupil_r": (76.0, 73.0),
    "brow_l": (49.0, 66.0), "brow_r": (76.0, 66.0),
    # inner brow ends lifted 1.5 px above the outer ones: the donor's flat, low, angry brows
    # become the raised-at-the-centre worried set the panels draw (p4, p15, p16)
    "brow_c": (CX, 66.0),
    "brow_in_l": (55.5, 64.5), "brow_in_r": (69.5, 64.5),
    # the eyes: the whole-face vertical squeeze (0.6) turned the donor's narrow eyes into slits;
    # the panels draw BIG wide eyes. Lids pinned 3.5 above / 3.5 below the pupil (7 px tall,
    # the donor's own 7.5), brow stays 7 above the pupil so measure_cell's brow band (3-11 px
    # above the pupil) still finds the brow, not the lid
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
HAIR_RGB = np.array([0.190, 0.135, 0.085], np.float32)     # brown, lighter+warmer than Gus's (0.119,0.087,0.060)
IRIS_RGB = np.array([0.30, 0.42, 0.56], np.float32)        # blue-grey iris (draft card: eyes BLUE)


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
    """Thin-plate spline mapping src (N,2) -> dst (N,2). Returns a callable on (M,2) points."""
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
    """img (H,W,C) float; xy (M,2) float coords (x, y) -> (M,C). Clamped at the edges."""
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


def measure(a):
    """Copy of tools/project_cow_head_uvs.measure_cell's arithmetic (the parts the FRONT affine and
    th_face use), on sRGB bytes/255 exactly as Blender's Image.pixels hands them over."""
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
    thr = 0.5 * (skin_l + line_l)
    mxc = int(round(f["mouth"][0]))

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


def build():
    T = cell(Image.open(SRC_TEMPLATE), 10, 7, TEMPLATE_CELL[0], TEMPLATE_CELL[1], CW, CH)
    Dn = cell(Image.open(SRC_DONOR), 9, 4, DONOR_CELL[0], DONOR_CELL[1], 101, 220)
    assert T.shape == (CH, CW, 3) and Dn.shape == (220, 101, 3)
    old = measure(T)
    print("template (old Michael cell) landmarks:", {k: old[k] for k in ("eye_l", "eye_r", "mouth", "mouth_l", "mouth_r", "nostril_y", "chin_y", "hair_y", "brow_y")})

    # ---- donor prep: paint out the chin tuft --------------------------------------------------
    # measured on a 12x zoom + a luminance dump: a dark soul-patch blob at donor x 40-52, y 166-172 (lum
    # 0.08 at its core), directly under the lower lip; clean chin skin (0.5) rows 174-178. Fill from 9 rows below.
    Dp = Dn.copy()
    y0, y1, x0, x1 = 163, 175, 36, 57
    yy, xx = np.mgrid[y0:y1, x0:x1]
    w = np.clip(2.2 - ((xx - 46) / 7.5) ** 2 - ((yy - 169) / 4.5) ** 2, 0, 1)[..., None]
    Dp[y0:y1, x0:x1] = Dn[y0:y1, x0:x1] * (1 - w) + Dn[y0 + 9:y1 + 9, x0:x1] * w
    assert lum(Dp[166:173, 41:51]).min() > 0.30, "chin tuft still dark: %.2f" % lum(Dp[166:173, 41:51]).min()
    # the donor's cheek scar/streak (a dark diagonal, donor x 22-29, y 121-130 on the 12x zoom):
    # fill from the smooth cheek 8 px to its right. Michael is unmarked.
    y0, y1, x0, x1 = 117, 135, 18, 33
    yy, xx = np.mgrid[y0:y1, x0:x1]
    w = np.clip(2.0 - ((xx - 25.5) / 5.5) ** 2 - ((yy - 126) / 7.0) ** 2, 0, 1)[..., None]
    Dp[y0:y1, x0:x1] = Dp[y0:y1, x0:x1] * (1 - w) + Dp[y0:y1, x0 + 8:x1 + 8] * w
    # under-chin shadow (donor rows 183-192, lum 0.14-0.2): hard enough that, mirrored and shrunk,
    # it read as a goatee outline. Halved toward the chin skin above it (the template's own chin
    # crease is 0.41 against 0.55 skin, and measure_cell still finds it as the darkest row 117-143)
    for y in range(182, 193):
        k = 0.5 * np.clip(1.0 - abs(y - 187) / 6.0, 0, 1)
        Dp[y, 28:70] = Dp[y, 28:70] * (1 - k) + Dp[178, 28:70] * k
    # chin cleft: a dark vertical line at donor x 45-48, rows 180-189 (lum 0.14-0.24) - fill
    # from the chin skin 5 px either side
    y0, y1, x0, x1 = 177, 190, 42, 52
    yy, xx = np.mgrid[y0:y1, x0:x1]
    w = np.clip(2.0 - ((xx - 46.5) / 3.5) ** 2 - ((yy - 183.5) / 6.0) ** 2, 0, 1)[..., None]
    Dp[y0:y1, x0:x1] = Dp[y0:y1, x0:x1] * (1 - w) + 0.5 * (Dp[y0:y1, x0 - 5:x1 - 5] + Dp[y0:y1, x0 + 5:x1 + 5]) * w
    # nasolabial folds (nose wing -> mouth corner, donor x 27-38 / 58-69, y 138-162): a weathered
    # sergeant's lines on a seventeen-year-old - blended 45% with a 5x5 blur of themselves
    sm5 = blur(Dp, 2)
    for x0, x1 in ((26, 39), (57, 70)):
        yy, xx = np.mgrid[136:164, x0:x1]
        w = np.clip(1.5 - ((xx - (x0 + x1) / 2.0) / 6.0) ** 2 - ((yy - 150) / 13.0) ** 2, 0, 1)[..., None] * 0.45
        Dp[136:164, x0:x1] = Dp[136:164, x0:x1] * (1 - w) + sm5[136:164, x0:x1] * w

    # ---- skin colour match: donor face skin stats -> template cheek stats ------------------------
    ds = skin_mask(Dn)
    ds[:100] = False
    ds[186:] = False
    ds[:, :17] = False
    ds[:, 82:] = False
    ts = skin_mask(T)
    ts[:60] = False
    ts[130:] = False
    ts[:, :34] = False
    ts[:, 93:] = False
    # template face skin, excluding the eyes/brows/lips (darker than skin)
    ts &= lum(T) > 0.42
    dm, dsd = Dp[ds].mean(0), Dp[ds].std(0)
    tm, tsd = T[ts].mean(0), T[ts].std(0)
    print("donor skin mean %s sd %s -> template mean %s sd %s" % (np.round(dm, 3), np.round(dsd, 3), np.round(tm, 3), np.round(tsd, 3)))
    # MULTIPLICATIVE (ratio of means per channel): an additive/std match lifted the pupils from
    # 0.04 to 0.26 and the eye detector lost them to the sideburns. Darks must stay dark.
    Dm = np.clip(Dp * (tm / dm), 0, 1)
    soft = skin_mask(Dm)
    Dm[soft] = Dm[soft] * 0.60 + tm * 0.40

    # ---- donor foreground (the head, ears cut off, collar cut off) -------------------------------
    # head = warm pixels (skin, brown hair) or near-black (hair core); the sheet's neutral grey
    # background and its faint halo (r-b within 0.01) fail both tests
    fg = (Dn[..., 0] - Dn[..., 2] > 0.035) | (lum(Dn) < 0.10)
    fg[189:] = False
    fg[:, :6] = False
    fg[:, 95:] = False
    yy, xx = np.mgrid[0:220, 0:101]
    fg &= ~((yy > 85) & ((xx < 17) | (xx > 81)))      # the donor's own ears: the template's are kept
    fg &= ~((yy > 150) & ((xx < 21) | (xx > 78)))
    fg &= ~((yy > 162) & ((xx < 25) | (xx > 74)))     # collar top + jaw-shadow corners
    fg &= ~((yy > 172) & ((xx < 30) | (xx > 68)))
    # the donor's sideburns STAY (a first pass cut them because they out-darkened the pupils in
    # measure_cell's eye windows; the pupils are now forced to 0.05 and the sideburns' 3x3 mean is
    # ~0.12, and cutting them left the template's lighter temple skin showing beside the forehead)

    # ---- TPS warp, target -> donor, sampled bilinearly --------------------------------------------
    keys = list(TGT.keys())
    f = tps_fit([TGT[k] for k in keys], [DON[k] for k in keys])
    ty, tx = np.mgrid[0:CH, 0:CW]
    pts = np.stack([tx.ravel() + 0.5, ty.ravel() + 0.5], 1)
    src = f(pts) - 0.5
    warped = sample_bilinear(Dm, src).reshape(CH, CW, 3)
    wmask = sample_bilinear(fg.astype(np.float32)[..., None], src).reshape(CH, CW)
    wmask = (wmask > 0.5).astype(np.float32)
    inside = (src[:, 0] > 1) & (src[:, 0] < 99) & (src[:, 1] > 1) & (src[:, 1] < 218)
    wmask *= inside.reshape(CH, CW)
    # keep the template's own ears / background / neck outside the head: clip the mask to the
    # region between the ear creases below the brow, and above the neck rows
    cy, cx = np.mgrid[0:CH, 0:CW]
    wmask[(cy > 60) & ((cx < 33) | (cx > 96))] = 0
    wmask[cy >= 131] = 0
    alpha = np.clip(blur(wmask, 2) * 1.15 - 0.05, 0, 1)
    # the donor head's sides are near-vertical lines; feather the hair rows wider so the seam
    # against the template's rounder hair mass does not read as a box
    soft_hair = blur(wmask, 5)
    alpha = np.where(cy < 62, soft_hair, alpha)

    # ---- hair: recolour the donor hair AND the template hair outside it to the same brown ---------
    out = T.copy()
    out = out * (1 - alpha[..., None]) + warped * alpha[..., None]
    # forehead skin between the fringe strands above row 36 -> hair (the hair band rows 14-35 must
    # be < 5% skin for the projection tool; a heavier fringe is also what p15 draws)
    # Ramped over rows 28-39 (0.28 -> 1.0) so it reads as the fringe's shadow, not a hard band.
    peek = (alpha > 0.5) & (cy <= 39) & skin_mask(out)
    ramp = 0.28 + 0.72 * np.clip((cy - 31) / 8.0, 0, 1)
    out[peek] = out[peek] * ramp[peek][:, None]
    hair_don = (alpha > 0.5) & (lum(out) < 0.30) & (cy < 50) & ~skin_mask(out)
    mean = out[hair_don].mean(0)
    out[hair_don] = np.clip(out[hair_don] * (HAIR_RGB / np.maximum(mean, 1e-3)), 0, 0.6)
    # the template's own hair mass (rows < 62, lum 0.08-0.30) sits on a near-black background
    # (lum 0.04-0.08) that a mean-ratio recolour would lift into a grey block - measured, it did.
    # Fixed gain = HAIR_RGB over the old cell's hair-band mean (0.165, 0.124, 0.088).
    hair_tpl = (alpha <= 0.5) & (cy < 62) & ~skin_mask(T) & (lum(T) < 0.30) & (lum(T) > 0.075) & (cx > 12) & (cx < 118)
    out[hair_tpl] = np.clip(out[hair_tpl] * (HAIR_RGB / np.array([0.165, 0.124, 0.088], np.float32)), 0, 0.6)
    # blend the seam between donor hair and template hair
    hm = blur((hair_don | hair_tpl).astype(np.float32), 1)
    sm = blur(out, 1)
    seam = ((alpha > 0.1) & (alpha < 0.9) & (cy < 50))[..., None] * hm[..., None]
    out = out * (1 - seam) + sm * seam

    # ---- the template's square jaw outside the new outline -> background shadow -----------------
    # (a flat fill read as a block; the template's own pixels x 0.74 keep their texture and land on
    # the same 0.40-0.43 luminance as its side shadow between the ear crease and the face edge)
    fill = T * 0.74
    wedge = (alpha < 0.5) & (cy >= 76) & (cy < 131) & (cx > 31) & (cx < 96) & (lum(T) > 0.47)
    wa = blur(wedge.astype(np.float32), 3)
    wa = np.clip(wa * 1.3, 0, 1) * (1 - alpha)
    out = out * (1 - wa[..., None]) + fill * wa[..., None]

    # ---- lip line: the donor's is shallow (0.28 against 0.40 skin; the old cell's was 0.20 against
    # 0.55) - at 75 px on the head it would vanish, and measure_cell's corner crossing wanders on
    # it. Deepen it along the painted mouth, feathered ends, so it reads and the corners pin.
    lx0, lx1 = TGT["mouth_l"][0], TGT["mouth_r"][0]
    for y, k in ((104, 0.80), (105, 0.55), (106, 0.75)):
        xs = np.arange(CW)
        end = np.clip(np.minimum(xs - lx0 + 1.5, lx1 - xs + 1.5) / 3.0, 0, 1)
        out[y] = out[y] * (1 - end[:, None] * (1 - k))

    # ---- symmetric lighting: the donor is lit from his right; his shadow side (viewer's right)
    # came out as a dark grey jaw in the first portrait, and the side quads stretched it into a
    # dirty streak. Every template head is lit symmetrically, so mirror the LIT half across the
    # pupil axis (x = 62.5: pupils 49/76) over the face rows; the fringe (rows < 45) keeps its own
    # asymmetry. 6 px feather at the centre line.
    mirrored = out[:, ::-1]                              # x -> 129 - x; pupil axis 62.5 -> 66.5
    shift = int(round(2 * CX)) - (CW - 1)                # 125 - 129 = -4: roll so 62.5 stays put
    mirrored = np.roll(mirrored, shift, axis=1)
    right = np.clip((cx - CX) / 6.0, 0, 1) * (alpha > 0.5) * np.clip((cy - 36) / 12.0, 0, 1) * (cy < 131)
    out = out * (1 - right[..., None]) + mirrored * right[..., None]
    # ---- side-quad bands: the head's side quads stretch ONE column 8 px inside the face outline
    # across 92 mm, so vertical variation in that column becomes horizontal stripes on the cheek.
    # Vertical 5-tap blur on the near-edge bands, face rows only.
    for x0, x1 in ((34, 47), (78, 91)):
        band = out[60:131, x0:x1]
        v = band.copy()
        for _ in range(2):
            v = (np.roll(v, 1, 0) + v + np.roll(v, -1, 0)) / 3.0
        out[62:129, x0:x1] = v[2:-2]

    # ---- jaw outline: the donor's jaw carries a 3-4 px dark contour (lum 0.2-0.3) from the mouth
    # corners round under the chin; mirrored and shrunk to 75 px it read as a chinstrap beard.
    # Lift everything darker than 0.40 in the lower-face bands to a flat 0.42 shadow, so the jaw
    # dissolves into the side shadow (0.41) and the chin reads by its lit skin alone.
    L = lum(out)
    jaw = (alpha > 0.5) & (cy >= 98) & (cy < 131) & (L < 0.40) & (L > 0.06) & (((cx < 52) | (cx > 73)) | (cy >= 118))
    jaw &= ~((cy >= 102) & (cy <= 108) & (cx >= 50) & (cx <= 75))       # not the lip line
    shadow = T[102:127, 98:113].reshape(-1, 3).mean(0)          # the template's under-ear shadow skin (0.54,0.38,0.27)
    out[jaw] = out[jaw] * 0.3 + shadow * 0.7                      # (a multiplicative lift went orange)

    # ---- nose-tip catch light: the donor is lit from his right, so the bridge ridge (rows 76-80,
    # 0.74) out-brightens the tip (row 88, 0.73) and measure_cell's nose_tip lands 6 px high and
    # tilts the head's vertical affine. The template cells carry a tip highlight; paint one.
    r = np.sqrt(((cx - 62.0) / 3.0) ** 2 + ((cy - 88.0) / 1.8) ** 2)
    tip = np.clip(1.0 - r, 0, 1) * 0.14
    out = np.clip(out * (1 + tip[..., None]), 0, 1)

    # ---- blue irises -----------------------------------------------------------------------------
    for (px, py) in (TGT["pupil_l"], TGT["pupil_r"]):
        r = np.sqrt((cx - px) ** 2 + (cy - py) ** 2)
        iris = (r <= 2.6) & (lum(out) < 0.45) & (lum(out) > 0.08)
        L = lum(out)[iris][:, None]
        out[iris] = np.clip(IRIS_RGB * (L / 0.36), 0, 0.62)
        # measure_cell takes the darkest 3x3 mean in the eye window (rows 55-80): the pupil must
        # out-darken the donor's heavy brows, which sit inside that window
        pupil = (r <= 1.6)
        out[pupil] = np.minimum(out[pupil], 0.05)
    brow = (cy >= 58) & (cy <= 70) & (cx >= 34) & (cx <= 91) & (lum(out) < 0.11) & ~skin_mask(out)
    for (px, py) in (TGT["pupil_l"], TGT["pupil_r"]):
        brow &= np.sqrt((cx - px) ** 2 + (cy - py) ** 2) > 3.5
    out[brow] = out[brow] * (0.13 / np.maximum(lum(out)[brow], 1e-3))[:, None]

    out = np.clip(out, 0, 1)
    img = Image.fromarray((out * 255 + 0.5).astype(np.uint8))
    img.save(OUT)
    print("wrote", OUT, img.size, "%.1f KB" % (os.path.getsize(OUT) / 1024.0))

    # ---- gates -----------------------------------------------------------------------------------
    a = np.array(Image.open(OUT).convert("RGB")).astype(np.float32) / 255.0
    m = measure(a)
    print("NEW landmarks:", {k: m[k] for k in ("eye_l", "eye_r", "mouth", "mouth_l", "mouth_r", "nostril_y", "nose_tip_y", "chin_y", "hair_y", "brow_y", "ear_l", "ear_r", "ear_l_px", "ear_r_px")})
    print("NEW regions:", {k: m[k] for k in ("hair_band", "hair_dome", "under_ear_l", "under_ear_r", "neck")})
    errs = []
    for k, want in (("eye_l", (49, 73)), ("eye_r", (76, 73))):
        d = np.hypot(m[k][0] - want[0], m[k][1] - want[1])
        errs.append((k, d))
        assert d <= 1.5, (k, m[k], want)
    assert 104 <= m["mouth"][1] <= 106, m["mouth"]
    assert abs(m["mouth_l"] - 52.2) <= 1.5 and abs(m["mouth_r"] - 72.1) <= 1.5, (m["mouth_l"], m["mouth_r"])
    assert 91 <= m["nostril_y"] <= 95, m["nostril_y"]
    assert 89 <= m["nose_tip_y"] <= 93, ("nose_tip (highlight+nostril)/2", m["nose_tip_y"])
    assert 126 <= m["chin_y"] <= 133, m["chin_y"]
    assert 34 <= m["hair_y"] <= 42, m["hair_y"]
    assert m["hair_band"]["lum"] < 0.2 and m["hair_band"]["skin"] < 0.05, m["hair_band"]
    assert m["hair_dome"]["lum"] < 0.2 and m["hair_dome"]["skin"] < 0.05, m["hair_dome"]
    assert m["under_ear_r"]["skin"] > 0.9 and m["under_ear_l"]["skin"] > 0.9, (m["under_ear_r"], m["under_ear_l"])
    assert m["neck"]["skin"] > 0.95 and m["neck"]["lum"] > 0.45, m["neck"]
    assert m["ear_l_px"] > 300 and m["ear_r_px"] > 300, (m["ear_l_px"], m["ear_r_px"])
    # hair colour: brown, lighter than Gus's, darker than the 0.2 gate
    g = np.array(Image.open(GUS).convert("RGB")).astype(np.float32) / 255.0
    hb_new, hb_gus = lum(a[14:35, 23:105]).mean(), lum(g[14:35, 23:105]).mean()
    print("hair band lum new %.3f vs gus %.3f (rgb new %s gus %s)" % (hb_new, hb_gus, np.round(a[14:35, 23:105].reshape(-1, 3).mean(0), 3), np.round(g[14:35, 23:105].reshape(-1, 3).mean(0), 3)))
    assert hb_new > hb_gus + 0.02, "Michael's hair must read lighter than Gus's"
    # different man: face-region pixel agreement with Gus's cell
    face = (slice(40, 131), slice(33, 97))
    same = (np.abs(a[face] - g[face]).sum(2) < 8 / 255.0).mean()
    print("face-region pixels identical to Gus's cell: %.1f%% (old Michael cell: %.1f%%)"
          % (100 * same, 100 * (np.abs(T[face] - g[face]).sum(2) < 8 / 255.0).mean()))
    assert same < 0.40, same
    # iris colour actually blue
    cy2, cx2 = np.mgrid[0:CH, 0:CW]
    for (px, py) in ((49, 73), (76, 73)):
        r = np.sqrt((cx2 - px) ** 2 + (cy2 - py) ** 2)
        ring = a[(r > 1.0) & (r <= 2.6)]
        ring = ring[(lum(ring) > 0.08) & (lum(ring) < 0.45)]
        assert len(ring) >= 6 and (ring[:, 2] - ring[:, 0]).mean() > 0.10, ("iris not blue", len(ring), np.round(ring.mean(0), 3))
    print("GATES PASS")

    if PREVIEW:
        os.makedirs(SCRATCH, exist_ok=True)
        Z = 4
        sheet = Image.new("RGB", (CW * Z * 3 + 16, CH * Z), (255, 255, 255))
        for i, arr in enumerate((T, a, g)):
            sheet.paste(Image.fromarray((arr * 255 + 0.5).astype(np.uint8)).resize((CW * Z, CH * Z), Image.NEAREST), (i * (CW * Z + 8), 0))
        import time
        p = os.path.join(SCRATCH, "michael_old_new_gus_%d.png" % int(time.time()))
        sheet.save(p)
        print("preview (old Michael | NEW Michael | Gus) ->", p)


if __name__ == "__main__":
    build()
