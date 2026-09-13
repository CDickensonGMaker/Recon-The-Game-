"""refresh_th_michael_texture.py - swap the rebuilt Michael face atlas into the talking-heads file.

    "C:\Program Files\Blender Foundation\Blender 5.0\blender.exe" --background ^
        production/cinematics/talking_heads/talking_heads.blend --python tools/refresh_th_michael_texture.py -- [--save]

`cs_head_michael`'s face patch was SOLVED onto painted pixels (th_build.py: pupils (49,73)/(76,73),
lip line row 105, corners 52.2/72.1, nostril 93). tools/build_cow_michael_face_cell.py keeps those
landmark PIXELS, so the head's UVs stay valid and only the packed image needs refreshing - no
geometry rebuild, Gus's head and image untouched. The gate below reads the UVs back and measures the
patch verts against the NEW paint rather than trusting that statement.
"""
import bpy
import os
import sys
import numpy as np

D = bpy.data
ROOT = r"C:\Users\caleb\RECONgame"
ATLAS_PNG = os.path.join(ROOT, "assets", "us", "characters", "cow_michael_face_atlas.png")
CELL_PNG = os.path.join(ROOT, "assets", "us", "characters", "cow_michael_face_cell.png")
SAVE = "--save" in (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
FACE_COLS, FACE_ROWS = 10, 7
sys.path.insert(0, os.path.join(ROOT, "tools"))
import project_cow_head_uvs as P


def px(img):
    w, h = img.size
    a = np.empty(w * h * img.channels, dtype=np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(h, w, img.channels)


img = D.images["cow_michael_face_atlas"]
gus = D.images["cow_gus_face_atlas"]
gus_hash = px(gus).tobytes().__hash__()
rel = img.filepath
img.unpack(method='REMOVE')
img.filepath = ATLAS_PNG
img.reload()
img.pack()
img.filepath = rel
assert not img.is_float and img.packed_file is not None
assert px(gus).tobytes().__hash__() == gus_hash, "GUS IMAGE CHANGED"
# the packed pixels must equal the sidecar (bottom-up rows)
disk = D.images.load(ATLAS_PNG)
d = np.abs(px(disk)[..., :3] - px(img)[..., :3]).max()
D.images.remove(disk)
assert d < 1.5 / 255, "packed atlas differs from the sidecar by %.4f" % d
print("cow_michael_face_atlas repacked from the sidecar (max diff %.5f)" % d)

# paint gate: cs_head_michael's UVs against the NEW cell's landmarks
o = D.objects["cs_head_michael"]
me = o.data
uv = me.uv_layers.active.data
fi = [i for i, m in enumerate(me.materials) if m and m.name.startswith("face_atlas")]
W, H = img.size
A = P.pixels_topdown(img)
us, vs = [], []
for p in me.polygons:
    if p.material_index in fi:
        for li in p.loop_indices:
            us.append(uv[li].uv.x)
            vs.append(uv[li].uv.y)
col, row_b, x0, y0, cw, ch = P.cell_rect(us, vs, W, H)
feat = P.measure_cell(A[y0:y0 + ch, x0:x0 + cw])
print("cell col %d row_b %d; painted pupils %s %s mouth %s corners %.1f/%.1f nostril %d brow %.1f chin %d"
      % (col, row_b, feat["eye_l"], feat["eye_r"], feat["mouth"], feat["mouth_l"], feat["mouth_r"], feat["nostril_y"], feat["brow_y"], feat["chin_y"]))
# vertex -> cell pixel (per-vertex UV = the mean of its loops)
vpx = {}
for p in me.polygons:
    if p.material_index not in fi:
        continue
    for vi, li in zip(p.vertices, p.loop_indices):
        u, v = uv[li].uv
        vpx.setdefault(vi, []).append((u * W - x0, (1 - v) * H - y0))
pts = np.array([np.mean(v, axis=0) for v in vpx.values()])
def nearest(target):
    d = np.hypot(pts[:, 0] - target[0], pts[:, 1] - target[1])
    return float(d.min())
def loop_centre(target, r=8.0):
    """the eye is a loop AROUND the pupil (corners at +-6 px, lids -3.5/+2.5): gate its centroid, not its nearest vert"""
    d = np.hypot(pts[:, 0] - target[0], pts[:, 1] - target[1])
    c = pts[d <= r].mean(axis=0)
    return float(np.hypot(c[0] - target[0], c[1] - target[1]))
gate = {"pupil_l": loop_centre(feat["eye_l"]), "pupil_r": loop_centre(feat["eye_r"]),
        "corner_l": nearest((feat["mouth_l"], feat["mouth"][1])), "corner_r": nearest((feat["mouth_r"], feat["mouth"][1]))}
lip_rows = pts[(pts[:, 0] > feat["mouth_l"] + 1) & (pts[:, 0] < feat["mouth_r"] - 1)]
lip = lip_rows[np.argsort(np.abs(lip_rows[:, 1] - feat["mouth"][1]))[:5], 1]
gate["lip_line_rows"] = float(np.abs(lip - feat["mouth"][1]).mean())
print("paint gate (px, ~0.53 px/mm): %s" % {k: round(v, 2) for k, v in gate.items()})
assert gate["pupil_l"] <= 1.5 and gate["pupil_r"] <= 1.5 and gate["lip_line_rows"] <= 1.0 and gate["corner_l"] <= 1.5 and gate["corner_r"] <= 1.5, gate
if SAVE:
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_mainfile(filepath=D.filepath)
    print("SAVED", D.filepath)
else:
    print("DRY RUN")
