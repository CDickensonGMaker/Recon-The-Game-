"""Bake the painted 36-face sheet onto the US grunts - no mesh edits, no
re-exports. Each us_grunt GLB references its OWN face_atlas_v3 sidecar PNG
(assets/us/characters/us_grunt_<v>_face_atlas_v3.png), so a different painted
face per variant is a pixel paste into the rect that variant's head actually
samples (measured from the GLB, never assumed).

    blender -b --factory-startup -P tools/bake_us_faces.py

US grunts ONLY (Summoner 2026-07-29); VC/NVA keep face_atlas_v2 cells.
Source sheet: assets/us/characters/face_source/newfaceatlas.png (9x4 grid).
"""
import bpy
import os
import numpy as np

ROOT = r"C:\Users\caleb\RECONgame"
CHAR = os.path.join(ROOT, "assets", "us", "characters")
SHEET = os.path.join(CHAR, "face_source", "face_atlas_v4.png")
COLS, ROWS = 13, 10

# Sheet bands, counted from the TOP (row 0 = top): rows 0-3 black, 4-6 white,
# 7-9 Vietnamese. Cell index is row-major, so index = row * COLS + col.
# Spread the fireteam across the white and black bands so it reads as a squad
# of different men, not octuplets.
PICKS = {
    # us_grunt_v3 retired 2026-08-04 - its cell (row 4, col 0) is free again
    "us_grunt_rifleman": 4 * COLS + 3,
    "us_grunt_pointman": 5 * COLS + 7,
    "us_grunt_mg": 1 * COLS + 2,
    "us_grunt_grenadier": 6 * COLS + 5,
    "us_grunt_marksman": 5 * COLS + 11,
    "us_grunt_rto": 2 * COLS + 9,
}


def load_pixels(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    return img, px, w, h


sheet_img, sheet_px, SW, SH = load_pixels(SHEET)
cw, ch = SW // COLS, SH // ROWS

for variant, cell in PICKS.items():
    glb = os.path.join(CHAR, variant + ".glb")
    sidecar = os.path.join(CHAR, "%s_face_atlas_v3.png" % variant)
    if not (os.path.exists(glb) and os.path.exists(sidecar)):
        print("SKIP %s (missing glb or sidecar)" % variant, flush=True)
        continue

    # measure the face rect this variant actually samples
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb)
    # The LIVE head is the truth. Head-frag/splay meshes sample other spots
    # and blow a raw bbox up to half the atlas (measured: the first bake
    # stomped whole sidecars and was reverted) - so measure ONLY the primary
    # head mesh, and only polys facing the portrait (dominant cluster).
    cents = []
    cents_z = []          # 3D height of each face-material poly, to split head from hands
    head_names = ("grunt_head", "us_grunt_head", "head")
    meshes = [o for o in bpy.data.objects if o.type == "MESH"
              and any(h in o.name.lower() for h in head_names)
              and "frag" not in o.name.lower() and "splay" not in o.name.lower()
              and "cap" not in o.name.lower()]
    if not meshes:
        meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    for ob in meshes:
        me = ob.data
        if not me.uv_layers:
            continue
        uvl = me.uv_layers[0]
        for i, s in enumerate(ob.material_slots):
            if s.material is None or "face" not in s.material.name.lower():
                continue
            for p in me.polygons:
                if p.material_index != i:
                    continue
                us = [uvl.data[li].uv[0] for li in range(p.loop_start, p.loop_start + p.loop_total)]
                vs = [uvl.data[li].uv[1] for li in range(p.loop_start, p.loop_start + p.loop_total)]
                cents.append((sum(us) / len(us), sum(vs) / len(vs)))
                zs3 = [(ob.matrix_world @ me.vertices[vi].co).z for vi in p.vertices]
                cents_z.append(sum(zs3) / len(zs3))
    if not cents:
        print("SKIP %s (no face polys found)" % variant, flush=True)
        continue

    side_img, side_px, AW, AH = load_pixels(sidecar)
    # dominant cluster within one portrait-cell window (~0.12 x 0.16 UV)
    best, best_n = None, -1
    for cu, cv in cents:
        n = sum(1 for u, v in cents if abs(u - cu) < 0.09 and abs(v - cv) < 0.11)
        if n > best_n:
            best, best_n = (cu, cv), n
    inl_u = [u for u, v in cents if abs(u - best[0]) < 0.09 and abs(v - best[1]) < 0.11]
    inl_v = [v for u, v in cents if abs(u - best[0]) < 0.09 and abs(v - best[1]) < 0.11]
    x0, x1 = int(min(inl_u) * AW), int(max(inl_u) * AW) + 1
    y0, y1 = int(min(inl_v) * AH), int(max(inl_v) * AH) + 1
    x0, y0 = max(x0, 0), max(y0, 0)
    x1, y1 = min(x1, AW), min(y1, AH)
    tw, th = x1 - x0, y1 - y0
    if tw < 16 or th < 16 or tw > AW * 0.25 or th > AH * 0.25:
        print("SKIP %s (implausible face rect %dx%d, inliers %d/%d)"
              % (variant, tw, th, best_n, len(cents)), flush=True)
        continue

    # source cell (sheet is top-down in the file; flip to blender bottom-up)
    r, c = divmod(cell, COLS)
    sx0, sy0_top = c * cw, r * ch
    cell_px = np.flipud(np.flipud(sheet_px)[sy0_top:sy0_top + ch, sx0:sx0 + cw])

    # nearest-neighbor resize into the target rect (PSX-crisp on purpose)
    yi = (np.arange(th) * (ch / th)).astype(int).clip(0, ch - 1)
    xi = (np.arange(tw) * (cw / tw)).astype(int).clip(0, cw - 1)
    resized = cell_px[yi][:, xi]
    resized[:, :, 3] = 1.0

    side_px[y0:y1, x0:x1, :] = resized

    # The hands/neck/forearms sample a SKIN PATCH elsewhere in the same cell
    # (merge_face_skin_material.py). Baking only the portrait leaves that patch at
    # whatever tone it already was - which on a three-tone sheet ships "a white man's
    # head on a black man's arms". So repaint it to THIS face's own skin.
    # Split head from hands/neck in 3D, not in UV: a UV window wide enough to hold the
    # portrait also swallows the skin patch (the cell is only ~0.077 x 0.10), so a
    # UV-outlier test finds nothing. Height separates them cleanly - the head sits at the
    # top of the body, the hands hang at hip level in the T-pose.
    out_u, out_v = [], []
    if cents_z:
        zmax, zmin = max(cents_z), min(cents_z)
        if zmax - zmin > 0.15:                      # there really are two body regions
            cut = zmax - (zmax - zmin) * 0.35       # head = top third of the span
            for (u, v), z in zip(cents, cents_z):
                if z < cut:
                    out_u.append(u)
                    out_v.append(v)
    # MEASURED 2026-08-04: the hand/neck UVs are NOT in a separate corner of the cell -
    # they overlap the portrait rect almost exactly (face x 6-92 y 17-123, skin
    # x 6-92 y 17-111). So a bounding-box repaint floods the face with flat skin.
    # The whole source cell is pasted below, which means the hands sample whatever the
    # NEW sheet has at their UV spots. Report the tone they will actually pick up so a
    # mismatch is visible in the log instead of on a man's arms.
    if out_u:
        rgb = resized[:, :, :3]
        lum = rgb.mean(axis=2)
        warm = (rgb[:, :, 0] > rgb[:, :, 2]) & (lum > 0.18) & (lum < 0.92)
        tone = (np.median(rgb[warm], axis=0) if warm.sum() > 32
                else np.median(rgb.reshape(-1, 3), axis=0))
        print("   hands/neck sample this cell too; its median skin tone is %.3f %.3f %.3f"
              % (tone[0], tone[1], tone[2]), flush=True)

    side_img.pixels.foreach_set(np.ascontiguousarray(side_px).ravel())
    side_img.filepath_raw = sidecar
    side_img.file_format = "PNG"
    side_img.save()
    print("BAKED %s <- face cell %d into rect x %d-%d y %d-%d of %dx%d"
          % (variant, cell, x0, x1, y0, y1, AW, AH), flush=True)

print("ALL FACES BAKED", flush=True)


# ---------------------------------------------------------------------------
# REBUILD THE WHOLE SIDECAR SHEET from the new atlas.
#
# The sidecar IS the runtime atlas: GruntDresser slides uv1_offset across ITS
# 10x7 grid (grunt_dresser.gd:20-21), and every head's UV island is sized to one
# of ITS cells. So we do NOT retile the game to 13x10 - we repopulate the 10x7
# sheet with 70 of the 130 new faces. UVs, the dresser and the
# skin-follows-face guarantee all keep working untouched.
#
# Source cells are near-square (111x109); sheet cells are tall (96x128). Scaling
# square into tall stretches every face, so fit to WIDTH and pad the remainder
# with that face's own median skin tone - which is also what the hands sample.
# ---------------------------------------------------------------------------
DEST_COLS, DEST_ROWS = 10, 7          # must match grunt_dresser.gd FACE_COLS/ROWS

# His hand-built sheet is ALREADY 10x7 (assets/.../face_source/face_atlas_v5.png,
# 1296x1132). When source and destination share a grid, resample the WHOLE sheet -
# do NOT slice per cell. Cell-by-cell compositing drifted (SW/COLS is fractional),
# pulled in the rules between cells, and clipped the bottom row; a whole-sheet
# resample cannot do any of those because the grid never has to be reconstructed.
SHEET_10x7 = os.path.join(CHAR, "face_source", "face_atlas_v5.png")
if os.path.exists(SHEET_10x7):
    src_img, src_px, sw2, sh2 = load_pixels(SHEET_10x7)
    for variant in PICKS:
        sidecar = os.path.join(CHAR, "%s_face_atlas_v3.png" % variant)
        if not os.path.exists(sidecar):
            continue
        side_img, side_px, AW, AH = load_pixels(sidecar)
        yi = (np.arange(AH) * (sh2 / float(AH))).astype(int).clip(0, sh2 - 1)
        xi = (np.arange(AW) * (sw2 / float(AW))).astype(int).clip(0, sw2 - 1)
        out = src_px[yi][:, xi].copy()
        out[:, :, 3] = 1.0
        side_img.pixels.foreach_set(np.ascontiguousarray(out).ravel())
        side_img.filepath_raw = sidecar
        side_img.file_format = "PNG"
        side_img.save()
        print("SHEET RESAMPLED %s  %dx%d <- %dx%d (whole sheet, 10x7 preserved)"
              % (variant, AW, AH, sw2, sh2), flush=True)
    print("ALL SIDECARS RESAMPLED FROM face_atlas_v5", flush=True)
    raise SystemExit(0)

# 70 of the 130, spread so the squad mixes: black band (sheet rows 0-3),
# white band (4-6), Vietnamese band (7-9).
BANDS = [(0, 4), (4, 7), (7, 10)]        # black, white, Vietnamese (rows from TOP)
NEED = DEST_COLS * DEST_ROWS             # 70
picks = []
for bi, (r0, r1) in enumerate(BANDS):
    pool = [r * COLS + c for r in range(r0, r1) for c in range(COLS)]
    # how many from this band: split 70 evenly, remainder to the first bands
    want = NEED // len(BANDS) + (1 if bi < NEED % len(BANDS) else 0)
    # even spread THROUGH the band, not the first N of it
    idx = [int(round(i * (len(pool) - 1) / float(max(1, want - 1)))) for i in range(want)]
    picks.extend(pool[i] for i in dict.fromkeys(idx))
while len(picks) < NEED:
    picks.append(picks[-1])
picks = picks[:NEED]

for variant in PICKS:
    sidecar = os.path.join(CHAR, "%s_face_atlas_v3.png" % variant)
    if not os.path.exists(sidecar):
        continue
    side_img, side_px, AW, AH = load_pixels(sidecar)
    dcw, dch = AW // DEST_COLS, AH // DEST_ROWS
    for di, cell in enumerate(picks):
        dr, dc = divmod(di, DEST_COLS)
        r, c = divmod(cell, COLS)
        # FLOAT-ACCURATE cell edges. SW/COLS is 111.38, not 111 - slicing with the
        # integer drifts ~5px across a row and cuts every face in half.
        sx0 = int(round(c * SW / float(COLS)));  sx1 = int(round((c + 1) * SW / float(COLS)))
        sy0 = int(round(r * SH / float(ROWS)));  sy1 = int(round((r + 1) * SH / float(ROWS)))
        # the sheet draws a light rule between cells - step inside it or every
        # baked cell carries a stripe and a sliver of its neighbour
        INSET = 9
        sx0, sx1 = sx0 + INSET, sx1 - INSET
        sy0, sy1 = sy0 + INSET, sy1 - INSET
        # sheet_px is bottom-up (Blender). Flip to top-down, take rows sy0..sy1
        # counted from the TOP, then flip the slice back for the bottom-up sidecar.
        src = np.flipud(np.flipud(sheet_px)[sy0:sy1, sx0:sx1])
        sh_h, sh_w = src.shape[0], src.shape[1]

        # Fill the tall cell by HEIGHT and centre-crop the width. Fitting by width
        # left the face tiny inside a slab of padding (measured: 96x94 in a 96x128 cell).
        scale = dch / float(sh_h)
        full_w = max(1, int(round(sh_w * scale)))
        yi = (np.arange(dch) * (sh_h / float(dch))).astype(int).clip(0, sh_h - 1)
        xi = (np.arange(full_w) * (sh_w / float(full_w))).astype(int).clip(0, sh_w - 1)
        scaled = src[yi][:, xi]
        if full_w >= dcw:
            x_off = (full_w - dcw) // 2
            face_px = scaled[:, x_off:x_off + dcw]
        else:
            face_px = scaled
        fh, fw = face_px.shape[0], face_px.shape[1]

        rgb = face_px[:, :, :3]
        lum = rgb.mean(axis=2)
        warm = (rgb[:, :, 0] > rgb[:, :, 2]) & (lum > 0.18) & (lum < 0.92)
        tone = (np.median(rgb[warm], axis=0) if warm.sum() > 32
                else np.median(rgb.reshape(-1, 3), axis=0))

        dx0, dy0 = dc * dcw, dr * dch
        side_px[dy0:dy0 + dch, dx0:dx0 + dcw, 0] = tone[0]
        side_px[dy0:dy0 + dch, dx0:dx0 + dcw, 1] = tone[1]
        side_px[dy0:dy0 + dch, dx0:dx0 + dcw, 2] = tone[2]
        side_px[dy0:dy0 + dch, dx0:dx0 + dcw, 3] = 1.0

        oy = dy0 + (dch - fh) // 2
        ox = dx0 + (dcw - fw) // 2
        face_px = face_px.copy()
        face_px[:, :, 3] = 1.0
        side_px[oy:oy + fh, ox:ox + fw, :] = face_px

    side_img.pixels.foreach_set(np.ascontiguousarray(side_px).ravel())
    side_img.filepath_raw = sidecar
    side_img.file_format = "PNG"
    side_img.save()
    print("SHEET REBUILT %s  %dx%d  %d cells of %dx%d"
          % (variant, AW, AH, len(picks), dcw, dch), flush=True)

print("ALL SIDECAR SHEETS REBUILT", flush=True)
