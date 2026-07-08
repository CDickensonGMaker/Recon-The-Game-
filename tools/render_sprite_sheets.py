"""Batch-render 8-direction sprite FRAMES for every action in a unit blend.

Run headless (unit name after --):
  blender -b art_source/characters/blends/unit_us_grunt.blend -P render_sprite_sheets.py -- us_grunt
Then assemble organized per-animation folders:
  blender -b -P assemble_sheets.py -- us_grunt

Frames cache to art_source/characters/sprite_frames/<unit>/<action>_<dir>_<col>.png
(cached: existing frames are skipped, so re-runs are cheap).
Layout/strips/palette live in assemble_sheets.py.
"""
import bpy, os, sys, math, json
import numpy as np

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
UNIT = argv[0] if argv else 'us_grunt'
RIG_NAME = argv[1] if len(argv) > 1 else 'MixamoRig'
HIDE = argv[2].split(',') if len(argv) > 2 else []
TMP = rf"C:\Users\caleb\RECONgame\art_source\characters\sprite_frames\{UNIT}"
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
arm = bpy.data.objects[RIG_NAME]

# hide the other unit(s): names may be collections or objects
for h in HIDE:
    if h in bpy.data.collections:
        for ob in bpy.data.collections[h].objects:
            ob.hide_render = True
    if h in bpy.data.objects:
        bpy.data.objects[h].hide_render = True
print(f"UNIT={UNIT} RIG={RIG_NAME} hidden={HIDE}", flush=True)

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

    for d in range(DIRS):
        rig.rotation_euler = (0, 0, math.radians(45 * d))
        for i, f in enumerate(frames):
            path = os.path.join(TMP, f"{name}_{d}_{i}.png")
            if os.path.exists(path):    # resume: reuse frames from prior runs
                continue
            sc.frame_set(f)
            bpy.context.view_layer.update()
            track_hips()
            sc.render.filepath = path
            bpy.ops.render.render(write_still=True)

    results.append((name, count))
    print(f"FRAMES DONE: {name} ({count} cols x {DIRS} dirs)", flush=True)

print("ALL FRAMES COMPLETE:", len(results), flush=True)

