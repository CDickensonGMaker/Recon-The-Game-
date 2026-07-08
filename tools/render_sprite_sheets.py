"""Batch-render 8-direction sprite sheets for every action in unit_us_grunt.blend.

Run headless:
  blender -b unit_us_grunt.blend -P render_sprite_sheets.py

Output per action (in assets/characters/source/renders/sprites/sheets/):
  usgrunt_<action>_sheet.png       raw render sheet   (rows = 8 directions, cols = frames)
  usgrunt_<action>_sheet_q.png     palette-quantized sheet
  usgrunt_<action>.json            manifest (frames, source range, cell size)
"""
import bpy, os, math, json
import numpy as np

OUT = r"C:\Users\caleb\HellOfDuty\assets\characters\source\renders\sprites\sheets"
TMP = os.path.join(OUT, "_frames")
os.makedirs(OUT, exist_ok=True)
os.makedirs(TMP, exist_ok=True)

W, H = 128, 160
DIRS = 8
MAX_FRAMES = 8          # sample long clips down to at most this many columns
ORTHO = 2.3

PAL_HEX = ['4A5240','333A2C','6B7358','3E4A38','57584A','4A3826','A87858','6B4A34',
           '1A1A1A','33363A','8F7433','2E4030','4E6844','8A8A55','5C4632','9BA48C',
           'C99A76','D8AA82','7D8A5E','3F4E33','9A9C85','E8E2D2','7A7458','8A8C77']
PAL = np.array([[int(h[i:i+2],16)/255 for i in (0,2,4)] for h in PAL_HEX])

sc = bpy.context.scene
rig = bpy.data.objects['SpriteRig']
cam = bpy.data.objects['SpriteCam']
arm = bpy.data.objects['MixamoRig']

cam.data.type = 'ORTHO'
cam.data.ortho_scale = ORTHO
sc.camera = cam
sc.render.engine = 'BLENDER_EEVEE'
sc.render.film_transparent = True
sc.render.resolution_x = W
sc.render.resolution_y = H
sc.render.filter_size = 0.01
sc.view_settings.view_transform = 'Standard'

def track_hips():
    """Keep character horizontally centered (neutralize root motion, keep falls)."""
    hips = arm.matrix_world @ arm.pose.bones['mixamorig:Hips'].head
    rig.location = (hips.x, hips.y, 0)

def quantize(rgb):
    flat = rgb.reshape(-1, 3)
    d = ((flat[:, None, :] - PAL[None, :, :]) ** 2).sum(axis=2)
    return PAL[d.argmin(axis=1)].reshape(rgb.shape)

results = []
for act in sorted(bpy.data.actions, key=lambda a: a.name):
    name = act.name
    arm.animation_data.action = act
    if len(act.slots):
        arm.animation_data.action_slot = act.slots[0]
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    n = f1 - f0 + 1
    count = min(MAX_FRAMES, n)
    frames = [f0 + round(i * (n - 1) / max(count - 1, 1)) for i in range(count)]

    sheet = np.zeros((H * DIRS, W * count, 4), dtype=np.float32)
    for d in range(DIRS):
        rig.rotation_euler = (0, 0, math.radians(45 * d))
        for i, f in enumerate(frames):
            sc.frame_set(f)
            bpy.context.view_layer.update()
            track_hips()
            path = os.path.join(TMP, f"{name}_{d}_{i}.png")
            sc.render.filepath = path
            bpy.ops.render.render(write_still=True)
            img = bpy.data.images.load(path)
            px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)
            bpy.data.images.remove(img)
            row = DIRS - 1 - d   # row 0 (top) = direction 0
            sheet[row * H:(row + 1) * H, i * W:(i + 1) * W] = px

    # raw sheet (linear -> sRGB approx)
    rgb = np.clip(sheet[:, :, :3], 0, 1) ** (1 / 2.2)
    a = (sheet[:, :, 3:] > 0.5).astype(np.float32)

    def save_img(arr_rgb, suffix):
        out = np.concatenate([arr_rgb, a], axis=2)
        im = bpy.data.images.new('tmp_sheet', W * count, H * DIRS, alpha=True)
        # numpy row 0 = bottom in blender; flip so our row order lands top-down
        im.pixels.foreach_set(np.flipud(out).ravel())
        im.filepath_raw = os.path.join(OUT, f"usgrunt_{name}{suffix}.png")
        im.file_format = 'PNG'
        im.save()
        bpy.data.images.remove(im)

    save_img(rgb, '_sheet')
    save_img(quantize(rgb), '_sheet_q')

    manifest = {"action": name, "cell": [W, H], "directions": DIRS,
                "columns": count, "source_frames": frames,
                "source_range": [f0, f1], "row0": "facing camera, rotates 45deg CW per row"}
    with open(os.path.join(OUT, f"usgrunt_{name}.json"), 'w') as fp:
        json.dump(manifest, fp, indent=1)
    results.append((name, count))
    print(f"SHEET DONE: {name} ({count} cols)", flush=True)

print("ALL SHEETS COMPLETE:", len(results), flush=True)
