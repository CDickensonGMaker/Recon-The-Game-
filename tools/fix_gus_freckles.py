"""fix_gus_freckles.py - heal the painted freckle blotches off Gus's face cell and re-scatter real ones.

    python tools/fix_gus_freckles.py [--footprint <json dump from the projection tool>] [--dry]

Caleb 2026-09-12: "fix gus face than re add the frekles." The 2026-09-09 freckles were hard 1-2 px dark
blotches (lum 65-100 on 150 skin) scattered x 29-98, y 80-107 - straight across the columns the SIDE quads of
tools/project_cow_head_uvs.py stretch over 92 mm, so in profile they read as two brown streaks.

1. FLECKS: a fleck is a hard-edged dark pixel (9x9 median - lum > 30 and max-8-neighbour - lum > 25) inside the
   face zone (x 28-99, y 80-103) plus the blotch painted over the left ear lobe; ear creases (x <= 34 / >= 93 at
   rows 80-84), lobe under-shadows, nostrils, the mouth line and lip shadow are soft ramps and are excluded.
   The mask grows by the antialiased rim (neighbours > 12 below the median). Healed by iterative normalised 3x3
   fill from unmasked skin - per pixel, from its own neighbours, so the cheek/jaw shading survives.
2. FRECKLES: only inside the FRONT quads' UV footprint (cell px, from the projection tool) and >= 3 px from every
   SIDE polygon; rows 82-101; never on the eyes (y < 82), nostrils (x 55-73, y 93-100), lips (y > 100 at x 48-80).
   Density: gaussian on the nose bridge + upper cheeks, thinning outward. Dots are 1-2 px, warm brown = the local
   skin multiplied by 0.50-0.76 with a red bias, so each dot carries the shading under it.
3. Writes the cell and composites it into every atlas cell that held the OLD cell (both the joined body's and the
   gib donor's), atlas size unchanged.
Deterministic (seed 20260912). Re-running on its own output re-heals and re-paints the same scatter.
"""
import json
import os
import sys
import numpy as np
from PIL import Image, ImageFilter

R = r"C:\Users\caleb\RECONgame"
CELL = os.path.join(R, r"assets\us\characters\cow_gus_face_cell.png")
ATLAS = os.path.join(R, r"assets\us\characters\cow_gus_face_atlas.png")
ARGS = sys.argv[1:]
DRY = "--dry" in ARGS
FOOT = ARGS[ARGS.index("--footprint") + 1] if "--footprint" in ARGS else None
SEED = 20260912
# FRONT / SIDE polygons in cell px, measured 2026-09-12 with tools/project_cow_head_uvs.py on all four Gus
# meshes (body + donor, both states; identical to 0.01 px). --footprint overrides with a fresh dump.
FRONT = [[(64.09, 42.48), (97.01, 46.96), (94.42, 26.82), (64.09, 19.23)],
         [(64.09, 129.87), (80.86, 124.37), (90.84, 93.38), (64.09, 95.06)],
         [(64.09, 95.06), (90.84, 93.38), (97.01, 46.96), (64.09, 42.48)],
         [(64.09, 42.48), (64.09, 19.23), (33.77, 26.82), (31.18, 46.96)],
         [(64.09, 129.87), (64.09, 95.06), (37.35, 93.38), (47.33, 124.37)],
         [(64.09, 95.06), (64.09, 42.48), (31.18, 46.96), (37.35, 93.38)]]
SIDE = [[(80.86, 124.37), (74.65, 118.89), (83.95, 85.18), (90.84, 93.38)],
        [(90.84, 93.38), (83.95, 85.18), (89.03, 45.43), (97.01, 46.96)],
        [(97.01, 46.96), (89.03, 45.43), (89.03, 24.89), (94.42, 26.82)],
        [(47.33, 124.37), (37.35, 93.38), (44.23, 85.18), (53.54, 118.89)],
        [(37.35, 93.38), (31.18, 46.96), (39.16, 45.43), (44.23, 85.18)],
        [(31.18, 46.96), (33.77, 26.82), (39.16, 24.89), (39.16, 45.43)]]
if FOOT:
    fp = json.load(open(FOOT))
    first = next(iter(fp.values()))
    FRONT = [[tuple(p) for p in q["px"]] for q in first["polys"] if q["group"] == "FRONT"]
    SIDE = [[tuple(p) for p in q["px"]] for q in first["polys"] if q["group"] == "SIDE"]
    for k, v in fp.items():
        assert [[tuple(p) for p in q["px"]] for q in v["polys"] if q["group"] == "FRONT"] == FRONT, k + ": FRONT footprint differs"


def lum_of(a):
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


def label8(m):
    H, W = m.shape
    lab = np.zeros(m.shape, dtype=int)
    n = 0
    for y in range(H):
        for x in range(W):
            if m[y, x] and lab[y, x] == 0:
                n += 1
                st = [(y, x)]
                lab[y, x] = n
                while st:
                    cy, cx = st.pop()
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < H and 0 <= nx < W and m[ny, nx] and lab[ny, nx] == 0:
                                lab[ny, nx] = n
                                st.append((ny, nx))
    return lab, n


def dilate(m):
    p = np.pad(m, 1)
    H, W = m.shape
    o = np.zeros_like(m)
    for dy in range(3):
        for dx in range(3):
            o |= p[dy:dy + H, dx:dx + W]
    return o


def point_in_poly(px, py, poly):
    inside = False
    n = len(poly)
    for i in range(n):
        (x0, y0), (x1, y1) = poly[i], poly[(i + 1) % n]
        if (y0 > py) != (y1 > py):
            xi = x0 + (py - y0) / (y1 - y0) * (x1 - x0)
            if px < xi:
                inside = not inside
    return inside


def dist_poly(px, py, poly):
    if point_in_poly(px, py, poly):
        return 0.0
    best = 1e9
    n = len(poly)
    for i in range(n):
        (x0, y0), (x1, y1) = poly[i], poly[(i + 1) % n]
        dx, dy = x1 - x0, y1 - y0
        t = max(0.0, min(1.0, ((px - x0) * dx + (py - y0) * dy) / (dx * dx + dy * dy)))
        best = min(best, ((px - x0 - t * dx) ** 2 + (py - y0 - t * dy) ** 2) ** 0.5)
    return best


def find_flecks(a):
    lum = lum_of(a)
    H, W = lum.shape
    ys, xs = np.mgrid[0:H, 0:W]
    p = np.pad(lum, 1, mode='edge')
    nmax = np.max(np.stack([p[dy:dy + H, dx:dx + W] for dy in range(3) for dx in range(3) if not (dy == 1 and dx == 1)]), axis=0)
    hard = nmax - lum
    med = np.asarray(Image.fromarray(lum.astype(np.uint8)).filter(ImageFilter.MedianFilter(9))).astype(float)
    seed = ((med - lum) > 30) & (hard > 25)
    zone = (ys >= 80) & (ys <= 103) & (xs >= 33) & (xs <= 99)
    zone &= ~((ys <= 84) & ((xs <= 34) | (xs >= 93)))          # the ear/cheek crease columns (soft, but tall)
    zone &= ~((ys >= 99) & (xs >= 98))                          # right lobe under-shadow ramp (rows 99+ at x 98-103)
    lobes = ((ys >= 104) & (ys <= 108) & (xs >= 28) & (xs <= 32) & ((med - lum) > 30))   # blotch over the left lobe
    core = (seed & zone) | lobes
    rim = dilate(core) & ((med - lum) > 12) & ~core & (zone | ((ys >= 104) & (ys <= 108) & (xs >= 28) & (xs <= 32)))
    mask = core | rim
    return mask, core, med, lum


def heal(a, mask):
    out = a.copy()
    known = ~mask
    H, W = mask.shape
    todo = mask.copy()
    while todo.any():
        pk = np.pad(known, 1)
        po = np.pad(out, ((1, 1), (1, 1), (0, 0)))
        acc = np.zeros_like(out)
        cnt = np.zeros(mask.shape)
        for dy in range(3):
            for dx in range(3):
                w = 1.0 if (dy == 1 or dx == 1) else 0.7071
                k = pk[dy:dy + H, dx:dx + W]
                acc += po[dy:dy + H, dx:dx + W] * (k * w)[..., None]
                cnt += k * w
        ready = todo & (cnt >= 2.0)
        if not ready.any():
            ready = todo & (cnt > 0)
        out[ready] = acc[ready] / cnt[ready][:, None]
        known |= ready
        todo &= ~ready
    return out


def paint_freckles(a, rng):
    H, W = a.shape[:2]
    ys, xs = np.mgrid[0:H, 0:W]
    ok = np.zeros((H, W), dtype=bool)
    for y in range(78, 106):
        for x in range(28, 102):
            cx, cy = x + 0.5, y + 0.5
            if not any(point_in_poly(cx, cy, q) for q in FRONT):
                continue
            if min(dist_poly(cx, cy, q) for q in SIDE) < 3.0:
                continue
            ok[y, x] = True
    ok &= (ys >= 82) & (ys <= 101)
    ok &= ~((xs >= 55) & (xs <= 73) & (ys >= 93) & (ys <= 100))      # nostrils / nose base
    ok &= ~((ys > 100) & (xs >= 48) & (xs <= 80))                     # lips
    fx = np.nonzero(ok)
    foot = dict(x0=int(fx[1].min()), x1=int(fx[1].max()), y0=int(fx[0].min()), y1=int(fx[0].max()), px=int(ok.sum()))
    # density: nose bridge + upper cheeks, thinning outward/downward
    dens = (np.exp(-(((xs - 64.0) / 6.0) ** 2 + ((ys - 87.0) / 4.5) ** 2))            # bridge
            + 1.0 * np.exp(-(((xs - 52.0) / 6.5) ** 2 + ((ys - 92.0) / 5.5) ** 2))    # left upper cheek
            + 1.0 * np.exp(-(((xs - 76.0) / 6.5) ** 2 + ((ys - 92.0) / 5.5) ** 2))    # right upper cheek
            + 0.25 * np.exp(-(((xs - 64.0) / 20.0) ** 2 + ((ys - 90.0) / 9.0) ** 2)))  # thin outer haze
    dens *= ok
    # thin toward the edge of the allowed footprint so the scatter has no straight border
    edge = ok.copy()
    for _ in range(4):
        edge = edge & ~dilate(~edge)
        dens[ok & ~edge] *= 0.55
    cand = list(zip(*np.nonzero(ok)))
    wts = np.array([dens[y, x] for y, x in cand])
    wts /= wts.sum()
    out = a.copy()
    taken = np.zeros((H, W), dtype=bool)
    dots = []
    target = 44
    tries = 0
    while len(dots) < target and tries < 4000:
        tries += 1
        y, x = cand[rng.choice(len(cand), p=wts)]
        shape = rng.choice(["1", "2h", "2v", "2x2"], p=[0.40, 0.22, 0.22, 0.16])
        cells = {"1": [(0, 0)], "2h": [(0, 0), (0, 1)], "2v": [(0, 0), (1, 0)], "2x2": [(0, 0), (0, 1), (1, 0), (1, 1)]}[shape]
        pts = [(y + dy, x + dx) for dy, dx in cells]
        if not all(ok[py, px] for py, px in pts):
            continue
        # keep a 1-px gap between dots so they never merge into a blotch
        if any(taken[max(0, py - 1):py + 2, max(0, px - 1):px + 2].any() for py, px in pts):
            continue
        k = rng.uniform(0.50, 0.76)
        for i, (py, px) in enumerate(pts):
            kk = k if i == 0 or shape != "2x2" else min(0.92, k + rng.uniform(0.05, 0.18))
            skin = a[py, px]
            out[py, px] = np.clip(skin * np.array([kk + 0.05, kk - 0.02, kk - 0.06]), 0, 255)
            taken[py, px] = True
        dots.append(dict(x=int(x), y=int(y), shape=shape, k=round(float(k), 2)))
    return out, dots, foot, ok


def main():
    rng = np.random.default_rng(SEED)
    im = Image.open(CELL).convert("RGB")
    a = np.asarray(im).astype(float)
    mask, core, med, lum = find_flecks(a)
    lab, n = label8(core)
    comps = []
    for i in range(1, n + 1):
        m = lab == i
        yy, xx = np.nonzero(m)
        comps.append(dict(n=int(m.sum()), x0=int(xx.min()), y0=int(yy.min()), x1=int(xx.max()), y1=int(yy.max()),
                          lum=round(float(lum[m].mean()), 1), skin=round(float(med[m].mean()), 1)))
    cy, cx = np.nonzero(mask)
    print("flecks: %d hard blotches (%d core px, %d px with the antialiased rim), bbox x %d-%d y %d-%d"
          % (n, int(core.sum()), int(mask.sum()), cx.min(), cx.max(), cy.min(), cy.max()))
    for c in sorted(comps, key=lambda c: (c["y0"], c["x0"])):
        print("   ", c)
    healed = heal(a, mask)
    # gate: every healed pixel sits within 25 lum of the clean skin around it (mean of the unmasked 9x9)
    hl = lum_of(healed)
    pk = np.pad((~mask).astype(float), 4)
    pl = np.pad(lum * ~mask, 4)
    Hh, Ww = mask.shape
    num = sum(pl[dy:dy + Hh, dx:dx + Ww] for dy in range(9) for dx in range(9))
    den = sum(pk[dy:dy + Hh, dx:dx + Ww] for dy in range(9) for dx in range(9))
    ref = num / np.maximum(den, 1)
    worst = float(np.abs(hl[mask] - ref[mask]).max())
    print("   heal: max |healed - clean 9x9 skin mean| = %.1f lum" % worst)
    # 38 measured 2026-09-12 and inspected: the nose-bridge highlight (63-64,90) and the two px where the right-lobe
    # blotch meets the lobe under-shadow (98-99,98) - both heal toward their true neighbours, not the 9x9 mean
    assert worst < 40, "healed pixel off the local skin tone"
    painted, dots, foot, ok = paint_freckles(healed, rng)
    print("freckles: %d dots (%s), footprint x %d-%d y %d-%d, %d allowed px"
          % (len(dots), {s: sum(1 for d in dots if d["shape"] == s) for s in ("1", "2h", "2v", "2x2")},
             foot["x0"], foot["x1"], foot["y0"], foot["y1"], foot["px"]))
    # gate: every painted pixel is >= 3 px from every SIDE poly and inside a FRONT poly
    diff = np.any(painted != healed, axis=2)
    dy_, dx_ = np.nonzero(diff)
    for y, x in zip(dy_, dx_):
        assert any(point_in_poly(x + 0.5, y + 0.5, q) for q in FRONT), (x, y)
        assert min(dist_poly(x + 0.5, y + 0.5, q) for q in SIDE) >= 3.0, (x, y)
    print("   painted px %d, bbox x %d-%d y %d-%d, all inside FRONT and >= 3 px from SIDE" % (len(dy_), dx_.min(), dx_.max(), dy_.min(), dy_.max()))
    untouched = ~mask & ~diff
    assert np.array_equal(painted[untouched], a[untouched]), "a pixel outside the fleck/freckle masks changed"
    if DRY:
        out = Image.fromarray(np.round(painted).astype(np.uint8))
        out.save(os.path.join(os.environ.get("TEMP", "."), "gus_cell_dry.png"))
        Image.fromarray(np.round(healed).astype(np.uint8)).save(os.path.join(os.environ.get("TEMP", "."), "gus_cell_healed_dry.png"))
        print("DRY: wrote %TEMP%/gus_cell_dry.png and gus_cell_healed_dry.png, nothing in the repo touched")
        return
    out = Image.fromarray(np.round(painted).astype(np.uint8))
    out.save(CELL)
    at = Image.open(ATLAS)
    mode = at.mode
    A = np.asarray(at.convert("RGB")).astype(int)
    W, H = at.size
    cw, ch = W / 10.0, H / 7.0
    old = np.asarray(im).astype(int)
    hits = []
    for col in range(10):
        for row in range(7):
            x0, y0 = int(round(col * cw)), int(round(row * ch))
            blk = A[y0:y0 + 162, x0:x0 + 130]
            if blk.shape[:2] == (162, 130) and np.abs(blk - old).mean() < 0.5:
                hits.append((col, 6 - row, x0, y0))
    assert len(hits) == 2, "expected the body cell and the donor cell, found %s" % hits
    at2 = at.copy()
    for col, row_b, x0, y0 in hits:
        at2.paste(out.convert(mode), (x0, y0))
    assert at2.size == at.size and at2.mode == mode
    at2.save(ATLAS)
    print("wrote", CELL, "and", ATLAS, "cells", hits, "(col, row_from_bottom, x0, y0)")
    json.dump(dict(flecks=comps, fleck_px=int(mask.sum()), dots=dots, footprint=foot, atlas_cells=hits),
              open(os.path.join(os.path.dirname(CELL), "cow_gus_face_cell_freckles.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
