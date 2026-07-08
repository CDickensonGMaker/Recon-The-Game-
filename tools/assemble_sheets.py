"""Assemble organized sprite-sheet folders from cached frame renders.

Reads:  renders/sprites/sheets/_frames/<action>_<dir>_<col>.png
Writes: renders/sprites/sheets/<action>/
          <action>_ALL.png / _ALL_q.png          combined sheet (dir rows, frame cols)
          <action>_<dirlabel>.png / _q.png       one horizontal strip per direction
          <action>.json                          manifest

Run:  blender -b -P assemble_sheets.py
(Frame pixels are kept in Blender's native bottom-up row order throughout,
then written back the same way - no flips, no upside-down output.)
"""
import bpy, os, re, json, glob
import numpy as np

BASE = r"C:\Users\caleb\RECONgame\assets\characters\source\renders\sprites\sheets"
TMP = os.path.join(BASE, "_frames")
W, H, DIRS = 128, 160, 8
DIR_LABELS = ['front', 'front_right', 'right', 'back_right',
              'back', 'back_left', 'left', 'front_left']

PAL_HEX = ['4A5240','333A2C','6B7358','3E4A38','57584A','4A3826','A87858','6B4A34',
           '1A1A1A','33363A','8F7433','2E4030','4E6844','8A8A55','5C4632','9BA48C',
           'C99A76','D8AA82','7D8A5E','3F4E33','9A9C85','E8E2D2','7A7458','8A8C77']
PAL = np.array([[int(h[i:i+2],16)/255 for i in (0,2,4)] for h in PAL_HEX])

def load_px(path):
    img = bpy.data.images.load(path)
    px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)
    bpy.data.images.remove(img)
    return px  # row 0 = bottom (native)

def to_srgb(px):
    rgb = np.clip(px[:, :, :3], 0, 1) ** (1 / 2.2)
    a = (px[:, :, 3:] > 0.5).astype(np.float32)
    return np.concatenate([rgb, a], axis=2)

def quantize(img4):
    rgb = img4[:, :, :3]
    flat = rgb.reshape(-1, 3)
    d = ((flat[:, None, :] - PAL[None, :, :]) ** 2).sum(axis=2)
    q = PAL[d.argmin(axis=1)].reshape(rgb.shape).astype(np.float32)
    return np.concatenate([q, img4[:, :, 3:]], axis=2)

def save_png(arr4, path):
    h, w = arr4.shape[0], arr4.shape[1]
    im = bpy.data.images.new('tmp', w, h, alpha=True)
    im.pixels.foreach_set(np.ascontiguousarray(arr4, dtype=np.float32).ravel())
    im.filepath_raw = path
    im.file_format = 'PNG'
    im.save()
    bpy.data.images.remove(im)

# discover actions + frame counts from cached files
pat = re.compile(r'^(.+)_(\d+)_(\d+)\.png$')
actions = {}
for f in glob.glob(os.path.join(TMP, '*.png')):
    m = pat.match(os.path.basename(f))
    if not m: continue
    name, d, i = m.group(1), int(m.group(2)), int(m.group(3))
    a = actions.setdefault(name, {'dirs': 0, 'cols': 0})
    a['dirs'] = max(a['dirs'], d + 1)
    a['cols'] = max(a['cols'], i + 1)

done = []
for name, info in sorted(actions.items()):
    cols = info['cols']
    if info['dirs'] < DIRS:
        print(f"SKIP {name}: only {info['dirs']}/{DIRS} directions rendered", flush=True)
        continue
    outdir = os.path.join(BASE, name)
    os.makedirs(outdir, exist_ok=True)

    all_sheet = np.zeros((H * DIRS, W * cols, 4), dtype=np.float32)
    ok = True
    for d in range(DIRS):
        strip = np.zeros((H, W * cols, 4), dtype=np.float32)
        for i in range(cols):
            p = os.path.join(TMP, f"{name}_{d}_{i}.png")
            if not os.path.exists(p):
                ok = False; break
            strip[:, i * W:(i + 1) * W] = to_srgb(load_px(p))
        if not ok: break
        save_png(strip, os.path.join(outdir, f"{name}_{DIR_LABELS[d]}.png"))
        save_png(quantize(strip), os.path.join(outdir, f"{name}_{DIR_LABELS[d]}_q.png"))
        # dir 0 at TOP of combined sheet: bottom-up space -> band (DIRS-1-d)
        band = DIRS - 1 - d
        all_sheet[band * H:(band + 1) * H] = strip
    if not ok:
        print(f"SKIP {name}: missing frames", flush=True)
        continue

    save_png(all_sheet, os.path.join(outdir, f"{name}_ALL.png"))
    save_png(quantize(all_sheet), os.path.join(outdir, f"{name}_ALL_q.png"))
    with open(os.path.join(outdir, f"{name}.json"), 'w') as fp:
        json.dump({"action": name, "cell": [W, H], "columns": cols,
                   "directions": DIR_LABELS,
                   "combined_row_order_top_to_bottom": DIR_LABELS,
                   "strip_frame_order": "left to right"}, fp, indent=1)
    done.append(name)
    print(f"ASSEMBLED: {name} ({cols} cols)", flush=True)

print("DONE:", len(done), "animations", flush=True)

