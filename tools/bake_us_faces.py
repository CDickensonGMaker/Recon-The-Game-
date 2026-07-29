"""Bake the painted 36-face sheet onto the US grunts - no mesh edits, no
re-exports. Each us_grunt GLB references its OWN face_atlas_v3 sidecar PNG
(assets/us/characters/us_grunt_<v>_face_atlas_v3.png), so a different painted
face per variant is a pixel paste into the rect that variant's head actually
samples (measured from the GLB, never assumed).

    blender -b --factory-startup -P tools/bake_us_faces.py

US grunts ONLY (Summoner 2026-07-29); VC/NVA keep face_atlas_v2 cells.
Source sheet: art_source/characters/base_psx/newfaceatlas.png (9x4 grid).
"""
import bpy
import os
import numpy as np

ROOT = r"C:\Users\caleb\RECONgame"
CHAR = os.path.join(ROOT, "assets", "us", "characters")
SHEET = os.path.join(ROOT, "art_source", "characters", "base_psx", "newfaceatlas.png")
COLS, ROWS = 9, 4

# variant -> face cell index (row-major). Spread across the sheet so the
# fireteam reads as seven different men.
PICKS = {
    "us_grunt_v3": 0,
    "us_grunt_rifleman": 4,
    "us_grunt_pointman": 8,
    "us_grunt_mg": 10,
    "us_grunt_grenadier": 15,
    "us_grunt_marksman": 21,
    "us_grunt_rto": 25,
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
    side_img.pixels.foreach_set(np.ascontiguousarray(side_px).ravel())
    side_img.filepath_raw = sidecar
    side_img.file_format = "PNG"
    side_img.save()
    print("BAKED %s <- face cell %d into rect x %d-%d y %d-%d of %dx%d"
          % (variant, cell, x0, x1, y0, y1, AW, AH), flush=True)

print("ALL FACES BAKED", flush=True)
