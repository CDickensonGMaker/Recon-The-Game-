"""repaint_cow_michael_face.py - put a rebuilt Michael cell into the cast file and re-project his head.

    "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" --background ^
        assets/us/characters/conquest_of_worms_us_cast.blend --python tools/repaint_cow_michael_face.py -- [--save]

ONE Blender session, ONE save: the cast file is shared with whoever is editing Gus in it, so the
open -> write window is kept to seconds and nothing but Michael's atlas image and Michael's head UVs
is touched. Does, in order:
  1. reads assets/us/characters/cow_michael_face_cell.png (tools/build_cow_michael_face_cell.py)
  2. paints it into EVERY cell any Michael-family mesh samples on the packed `cow_michael_face_atlas`
     image (the visible joined body's cell AND the grunt_head gib donor's cell - the two-trap lesson
     of 2026-09-09, same arithmetic as build_cow_cast.face_cells / build_face_sheet)
  3. writes the sidecar cow_michael_face_atlas.png (8-bit reload, then re-packs it - a float
     buffer ships as a 16-bit PNG and busts the 1 MB law)
  4. runs tools/project_cow_head_uvs.py for the michael tag only (its gates + residual print)
  5. saves in place with save_version = 0 (no .blend1)
Gates: cell 130x162; every painted cell reads back bit-exact; the image is a byte buffer; Gus's images
untouched (pixel hash before == after).
"""
import bpy
import os
import sys
import hashlib
import numpy as np

D = bpy.data
ROOT = r"C:\Users\caleb\RECONgame"
CHAR = os.path.join(ROOT, "assets", "us", "characters")
CELL = os.path.join(CHAR, "cow_michael_face_cell.png")
ATLAS_PNG = os.path.join(CHAR, "cow_michael_face_atlas.png")
FACE_COLS, FACE_ROWS = 10, 7          # grunt_dresser.gd:20-21
ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SAVE = "--save" in ARGV
TAG = "michael"


def px(img):
    w, h = img.size
    a = np.empty(w * h * img.channels, dtype=np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(h, w, img.channels)


def phash(img):
    return hashlib.md5(px(img).tobytes()).hexdigest()


def face_cells(o):
    me = o.data
    out = {}
    if not me.uv_layers:
        return out
    uv = me.uv_layers.active.data
    for mi, m in enumerate(me.materials):
        if not m or "face_atlas" not in m.name:
            continue
        us, vs = [], []
        for p in me.polygons:
            if p.material_index != mi:
                continue
            for li in p.loop_indices:
                us.append(uv[li].uv[0])
                vs.append(uv[li].uv[1])
        if not us:
            continue
        # HEAD polys only: the body's hands/forearms sit on one neck-fix texel of the same cell,
        # and the head's re-projected island spans the whole cell, so take the centroid of all
        cu, cv = sum(us) / len(us), sum(vs) / len(vs)
        col = min(FACE_COLS - 1, max(0, int(cu * FACE_COLS)))
        row = min(FACE_ROWS - 1, max(0, int(cv * FACE_ROWS)))
        span_u, span_v = max(us) - min(us), max(vs) - min(vs)
        assert span_u <= 1.0 / FACE_COLS + 1e-3 and span_v <= 1.0 / FACE_ROWS + 1e-3, (o.name, span_u, span_v)
        out[(col, row)] = o.name
    return out


def main():
    assert bpy.context.mode == 'OBJECT'
    family = [o for o in D.objects if o.type == 'MESH' and o.name.endswith("_" + TAG)]
    assert family, "no meshes tagged _" + TAG
    img = D.images["cow_michael_face_atlas"]
    assert img.packed_file is not None, "atlas is not packed"
    assert not img.is_float, "atlas must be a byte buffer"
    gus_before = {n: phash(D.images[n]) for n in ("cow_gus_face_atlas",) if n in D.images}
    W, H = img.size
    a = px(img)                                             # bottom-up
    cell_img = D.images.load(CELL)
    c = px(cell_img)
    assert (c.shape[1], c.shape[0]) == (130, 162), c.shape
    cells = {}
    for o in family:
        for k, name in face_cells(o).items():
            cells.setdefault(k, []).append(name)
    assert cells, "no Michael mesh samples the face atlas"
    for (col, row), owners in sorted(cells.items()):
        x0, x1 = int(round(col * W / FACE_COLS)), int(round((col + 1) * W / FACE_COLS))
        y0, y1 = int(round(row * H / FACE_ROWS)), int(round((row + 1) * H / FACE_ROWS))
        th, tw = y1 - y0, x1 - x0
        src = c
        if (src.shape[0], src.shape[1]) != (th, tw):
            yi = (np.arange(th) * (src.shape[0] / float(th))).astype(int).clip(0, src.shape[0] - 1)
            xi = (np.arange(tw) * (src.shape[1] / float(tw))).astype(int).clip(0, src.shape[1] - 1)
            src = src[yi][:, xi]
        a[y0:y1, x0:x1, :3] = src[:, :, :3]
        a[y0:y1, x0:x1, 3] = 1.0
        cells[(col, row)] = (owners, src[:, :, :3].copy())
        print("painted cell col=%d row_from_bottom=%d (px x%d-%d y%d-%d) <- %s" % (col, row, x0, x1, y0, y1, sorted(owners)), flush=True)
    D.images.remove(cell_img)
    # sidecar on disk via a temp image, then reload the 8-bit file into the packed datablock
    tmp = D.images.new("cow_michael_face_atlas_tmp", W, H, alpha=True)
    tmp.pixels.foreach_set(np.ascontiguousarray(a, dtype=np.float32).ravel())
    tmp.filepath_raw = ATLAS_PNG
    tmp.file_format = 'PNG'
    tmp.save()
    D.images.remove(tmp)
    img.unpack(method='REMOVE')
    img.filepath = ATLAS_PNG
    img.reload()
    img.pack()
    assert not img.is_float and img.packed_file is not None, (img.is_float, img.packed_file)
    b = px(img)
    for (col, row), (owners, src) in cells.items():
        x0, y0 = int(round(col * W / FACE_COLS)), int(round(row * H / FACE_ROWS))
        blk = b[y0:y0 + src.shape[0], x0:x0 + src.shape[1], :3]
        d = np.abs(blk - src).max()
        assert d <= 1.5 / 255, "cell (%d,%d) read back off by %.4f" % (col, row, d)
    print("atlas %dx%d repainted, %d cells bit-exact on read-back, %.2f MB on disk"
          % (W, H, len(cells), os.path.getsize(ATLAS_PNG) / 1048576.0), flush=True)
    for n, h in gus_before.items():
        assert phash(D.images[n]) == h, "GUS IMAGE CHANGED: " + n
    # head projection, Michael only
    sys.argv = [sys.argv[0], "--", "--tags", TAG]
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import project_cow_head_uvs as P
    P.run()
    if SAVE:
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_mainfile(filepath=D.filepath)
        print("SAVED", D.filepath, flush=True)
    else:
        print("DRY RUN (no --save)", flush=True)


main()
