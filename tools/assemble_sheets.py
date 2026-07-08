"""Assemble organized sprite-sheet folders from cached frame renders.

Reads:  art_source/characters/sprite_frames/<unit>/<weapon>/<action>_<dir>_<col>.png
        art_source/characters/sprite_frames/<unit>/<weapon>/_meta.json   (baked in Blender)
Writes: assets/NPCs/<faction>/<unit>/<weapon>/<action>/
          <action>_ALL.png     combined sheet (dir rows, frame cols)
          <action>_<dirlabel>.png   one horizontal strip per direction
          <action>.json        manifest: fps, loop, ground_row, muzzle_px, m_per_px

Only the 24-colour quantized art is written - the raw EXR-ish renders stay in the
frame cache as masters. No "_q" suffix: what ships IS the palette look.

Run:  blender -b -P assemble_sheets.py -- us_grunt
"""
import bpy, os, re, sys, json, glob
import numpy as np

sys.path.insert(0, r'C:\Users\caleb\RECONgame\tools')
from unit_registry import UNITS, SKIP_ACTIONS

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
UNIT = argv[0] if argv else 'us_grunt'
U = UNITS[UNIT]
WEAPON, FACTION = U['weapon'], U['faction']
BASE = rf"C:\Users\caleb\RECONgame\assets\NPCs\{FACTION}\{UNIT}\{WEAPON}"
TMP = rf"C:\Users\caleb\RECONgame\art_source\characters\sprite_frames\{UNIT}\{WEAPON}"
os.makedirs(BASE, exist_ok=True)

W, H, DIRS = 128, 160, 8
DIR_LABELS = ['front', 'front_right', 'right', 'back_right',
              'back', 'back_left', 'left', 'front_left']

PAL_HEX = ['4A5240','333A2C','6B7358','3E4A38','57584A','4A3826','A87858','6B4A34',
           '1A1A1A','33363A','8F7433','2E4030','4E6844','8A8A55','5C4632','9BA48C',
           'C99A76','D8AA82','7D8A5E','3F4E33','9A9C85','E8E2D2','7A7458','8A8C77']
PAL = np.array([[int(h[i:i+2],16)/255 for i in (0,2,4)] for h in PAL_HEX])

META = {}
mp = os.path.join(TMP, '_meta.json')
if os.path.exists(mp):
    with open(mp) as fp:
        META = json.load(fp)
else:
    print("WARNING: no _meta.json - manifests will lack muzzle/fps data", flush=True)


class BadFrame(Exception):
    pass

def load_px(path):
    if os.path.getsize(path) < 200:          # zero-byte frame (disk-full write)
        raise BadFrame(path)
    img = bpy.data.images.load(path)
    raw = np.array(img.pixels[:], dtype=np.float32)
    bpy.data.images.remove(img)
    if raw.size != H * W * 4:
        raise BadFrame(path)
    return raw.reshape(H, W, 4)  # row 0 = bottom (native)

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
    if name in SKIP_ACTIONS:
        print(f"SKIPPED (excluded action): {name}", flush=True)
        continue
    if info['dirs'] < DIRS:
        print(f"SKIP {name}: only {info['dirs']}/{DIRS} directions rendered", flush=True)
        continue
    outdir = os.path.join(BASE, name)
    os.makedirs(outdir, exist_ok=True)

    all_sheet = np.zeros((H * DIRS, W * cols, 4), dtype=np.float32)
    ok = True
    strips = []
    try:
        for d in range(DIRS):
            strip = np.zeros((H, W * cols, 4), dtype=np.float32)
            for i in range(cols):
                p = os.path.join(TMP, f"{name}_{d}_{i}.png")
                if not os.path.exists(p):
                    ok = False; break
                strip[:, i * W:(i + 1) * W] = to_srgb(load_px(p))
            if not ok: break
            strips.append(quantize(strip))
    except BadFrame as e:
        print(f"SKIP {name}: corrupt frame {os.path.basename(str(e))} - delete it and re-render", flush=True)
        continue
    if not ok:
        print(f"SKIP {name}: missing frames", flush=True)
        continue

    for d, strip in enumerate(strips):
        save_png(strip, os.path.join(outdir, f"{name}_{DIR_LABELS[d]}.png"))
        # dir 0 at TOP of combined sheet: bottom-up space -> band (DIRS-1-d)
        band = DIRS - 1 - d
        all_sheet[band * H:(band + 1) * H] = strip
    save_png(all_sheet, os.path.join(outdir, f"{name}_ALL.png"))

    am = META.get('actions', {}).get(name, {})
    manifest = {
        'action': name,
        'unit': UNIT, 'weapon': WEAPON, 'faction': FACTION,
        'cell': [W, H],
        'columns': cols,
        'directions': DIR_LABELS,
        'combined_row_order_top_to_bottom': DIR_LABELS,
        'strip_frame_order': 'left to right',
        'palette': 'vietnam24',
        # --- playback ---
        'fps': am.get('fps'),
        'loop': am.get('loop'),
        'hold_last_frame': am.get('hold_last_frame'),
        'source_frames': am.get('source_frames'),
        'duration_s': am.get('duration_s'),
        # --- world placement ---
        'm_per_px': META.get('m_per_px'),
        'character_height_m': META.get('character_height_m'),
        'ground_row': am.get('ground_row'),
        'ground_row_note': 'pixel row (0=top of cell) where the z=0 ground plane sits; '
                           'align this row to the NPC feet position',
        # --- gunplay ---
        'muzzle_px': am.get('muzzle_px'),
        'muzzle_px_note': 'muzzle_px[dir][col] = [x, y] pixel of the barrel tip within '
                          'the cell (y from top). Spawn tracers/muzzle flash here.',
    }
    with open(os.path.join(outdir, f"{name}.json"), 'w') as fp:
        json.dump(manifest, fp, indent=1)
    done.append(name)
    print(f"ASSEMBLED: {name} ({cols} cols, fps={am.get('fps')}, loop={am.get('loop')})", flush=True)

print("DONE:", len(done), "animations", flush=True)
