"""Race/face swap a finished character into a new .blend.

Everything is shared - rig, mesh, gear, animations. Only the head's face changes:
  * the FaceSheet UV island slides to a different cell of the sheet
  * HeadSkin is resampled from that face's own skin pixels
  * the head_detail atlas (ears, nape) is re-based onto the new tone, keeping shading

The island is remapped PROPORTIONALLY, so any hand-tuning of the face position
inside its cell carries over to the new face.

Run:
  blender -b <source>.blend -P make_pilot_variant.py -- <face_name> <out_path>
"""
import bpy, sys, os
import numpy as np

FACE_CELLS = {   # name -> (row, col, ncols_in_row)
    'us_scar': (0, 0, 5), 'us_young': (0, 1, 5), 'us_older': (0, 2, 5),
    'us_black_headset': (0, 3, 5), 'us_black': (0, 4, 5),
    'vc_male_short': (1, 0, 6), 'vc_male_moustache': (1, 1, 6),
    'vc_male_long': (1, 2, 6), 'vc_female_short': (1, 3, 6),
    'vc_female_bob': (1, 4, 6), 'vc_female_long': (1, 5, 6),
}

def cell_box(name):
    row, col, ncols = FACE_CELLS[name]
    u0, u1 = col / ncols, (col + 1) / ncols
    v1 = 1.0 - row * 0.5
    return u0, v1 - 0.5, u1, v1      # u0, v0, u1, v1  (v is bottom-up)

def which_cell(cu, cv):
    """Identify the cell a UV centre falls inside."""
    for name in FACE_CELLS:
        u0, v0, u1, v1 = cell_box(name)
        if u0 <= cu <= u1 and v0 <= cv <= v1:
            return name
    return None

def sample_skin(img, box):
    """Median skin colour inside a cell: warm pixels, mid luminance."""
    W, H = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)
    u0, v0, u1, v1 = box
    cell = px[int(v0 * H):int(v1 * H), int(u0 * W):int(u1 * W), :3]
    h, w = cell.shape[:2]
    core = cell[int(h * 0.28):int(h * 0.80), int(w * 0.20):int(w * 0.80)].reshape(-1, 3)
    r, b = core[:, 0], core[:, 2]
    lum = core @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    sel = core[((r - b) > 0.06) & (lum > 0.16) & (lum < 0.62)]
    if not len(sel):
        sel = core
    return np.median(sel, axis=0)


argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
if len(argv) < 2:
    raise SystemExit("usage: -- <face_name> <out_path>")
face, out_path = argv[0], argv[1]
if face not in FACE_CELLS:
    raise SystemExit(f"unknown face '{face}'; options: {sorted(FACE_CELLS)}")

head = bpy.data.objects['head']
me = head.data
slot = [i for i, m in enumerate(me.materials) if m and m.name == 'FaceSheet']
if not slot:
    raise SystemExit("head has no FaceSheet material slot")

uvl = me.uv_layers.active
loops = [li for p in me.polygons if p.material_index in slot for li in p.loop_indices]
us = [uvl.data[li].uv[0] for li in loops]
vs = [uvl.data[li].uv[1] for li in loops]
cu, cv = (min(us) + max(us)) / 2, (min(vs) + max(vs)) / 2
src_face = which_cell(cu, cv)
if src_face is None:
    raise SystemExit(f"face island centre ({cu:.3f},{cv:.3f}) is not inside any cell")
print(f"source face: {src_face}  ->  target: {face}", flush=True)

su0, sv0, su1, sv1 = cell_box(src_face)
tu0, tv0, tu1, tv1 = cell_box(face)
for li in loops:
    u, v = uvl.data[li].uv
    nu = (u - su0) / (su1 - su0)          # position within the source cell
    nv = (v - sv0) / (sv1 - sv0)
    uvl.data[li].uv = (tu0 + nu * (tu1 - tu0), tv0 + nv * (tv1 - tv0))
me.update()
print(f"  UV island remapped ({len(loops)} loops), proportional tuning preserved", flush=True)

img = bpy.data.images['face_sheet']
srgb = sample_skin(img, cell_box(face))
hexs = ''.join(f'{int(round(c * 255)):02X}' for c in srgb)
lin = tuple(float(c) ** 2.2 for c in srgb)
skin = bpy.data.materials['HeadSkin']
b = next(n for n in skin.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
b.inputs['Base Color'].default_value = (*lin, 1.0)
print(f"  HeadSkin -> #{hexs}", flush=True)

if 'head_detail' in bpy.data.images:
    d = bpy.data.images['head_detail']
    S = d.size[0]
    dp = np.array(d.pixels[:], dtype=np.float32).reshape(S, S, 4)
    old = dp[:, :, :3]
    oldlum = old @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    ref = np.median(oldlum[oldlum > 0.02])
    scale = (oldlum / max(float(ref), 1e-4))[..., None]
    dp[:, :, :3] = np.clip(srgb[None, None, :] * scale, 0, 1)
    d.pixels.foreach_set(np.ascontiguousarray(dp, dtype=np.float32).ravel())
    d.pack()
    print("  head_detail atlas re-based (ear/nape shading preserved)", flush=True)

os.makedirs(os.path.dirname(out_path), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=out_path)
print(f"VARIANT SAVED: {out_path}", flush=True)
print("actions:", sorted(a.name for a in bpy.data.actions), flush=True)
