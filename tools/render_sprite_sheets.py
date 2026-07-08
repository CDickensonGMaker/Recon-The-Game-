"""Batch-render 8-direction sprite FRAMES for every action, and bake the
Blender-only scene knowledge that is lost once frames exist:

  muzzle_px   [dir][col] -> [x, y] pixel of the barrel tip inside the cell
  ground_row  pixel row (from top) of the z=0 ground plane
  m_per_px    metres per pixel, so the sprite scales to world units
  fps / loop  per action, derived from the real action length

Run headless (unit name after --):
  blender -b sprite_stage.blend -P render_sprite_sheets.py -- us_grunt

Frames cache to art_source/characters/sprite_frames/<unit>/<weapon>/
(existing frames are skipped, so re-runs are cheap and only the meta is rebuilt).
Layout/strips/palette live in assemble_sheets.py.
"""
import bpy, os, sys, math, json
import numpy as np
from bpy_extras.object_utils import world_to_camera_view

sys.path.insert(0, r'C:\Users\caleb\RECONgame\tools')
from unit_registry import UNITS, HOLD_LAST, SKIP_ACTIONS

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
UNIT = argv[0] if argv else 'us_grunt'
if UNIT not in UNITS:
    raise SystemExit(f"unknown unit {UNIT}; known: {list(UNITS)}")
U = UNITS[UNIT]
WEAPON = U['weapon']
TMP = rf"C:\Users\caleb\RECONgame\art_source\characters\sprite_frames\{UNIT}\{WEAPON}"
os.makedirs(TMP, exist_ok=True)

W, H = 128, 160
DIRS = 8
MAX_FRAMES = 8          # sample long clips down to at most this many columns
ORTHO = 2.3

sc = bpy.context.scene
rig = bpy.data.objects['SpriteRig']
cam = bpy.data.objects['SpriteCam']
arm = bpy.data.objects[U['rig']]
gun = bpy.data.objects.get(U['gun'])

cam.data.type = 'ORTHO'
cam.data.ortho_scale = ORTHO
sc.camera = cam
sc.render.engine = 'BLENDER_EEVEE'
sc.render.film_transparent = True
sc.render.resolution_x = W
sc.render.resolution_y = H
sc.render.resolution_percentage = 100
sc.render.filter_size = 0.01
sc.view_settings.view_transform = 'Standard'

# ---- isolate this unit: hide every other unit's meshes and guns ----
def unit_objects(u):
    d = UNITS[u]
    obs = []
    m = d['meshes']
    if isinstance(m, str):
        c = bpy.data.collections.get(m)
        if c: obs += [o for o in c.objects if o.type == 'MESH']
    else:
        obs += [bpy.data.objects[n] for n in m if n in bpy.data.objects]
    g = bpy.data.objects.get(d['gun'])
    if g: obs.append(g)
    return obs

mine = {o.name for o in unit_objects(UNIT)}
hidden = []
for other in UNITS:
    if other == UNIT: continue
    for o in unit_objects(other):
        if o.name not in mine:
            o.hide_render = True
            hidden.append(o.name)
for o in unit_objects(UNIT):
    o.hide_render = False
print(f"UNIT={UNIT} WEAPON={WEAPON} RIG={U['rig']} hid {len(hidden)} objects", flush=True)

# ---- muzzle tip in the gun's local space (guns are built muzzle-first along +X) ----
muzzle_local = None
if gun and gun.type == 'MESH':
    vs = gun.data.vertices
    muzzle_local = min((v.co for v in vs), key=lambda c: c.x).copy()
    print(f"muzzle local {tuple(round(v,3) for v in muzzle_local)}", flush=True)

def px_of(world_pt):
    """world point -> (x, y) pixel inside the 128x160 cell, y measured from TOP."""
    co = world_to_camera_view(sc, cam, world_pt)
    return [round(co.x * W, 2), round((1.0 - co.y) * H, 2)]

def track_hips():
    """Keep character horizontally centered (neutralize root motion, keep falls)."""
    hips = arm.matrix_world @ arm.pose.bones['mixamorig:Hips'].head
    rig.location = (hips.x, hips.y, 0)

meta = {
    'unit': UNIT, 'weapon': WEAPON, 'faction': U['faction'],
    'cell': [W, H], 'directions': DIRS,
    'ortho_scale_m': ORTHO,
    'm_per_px': round(ORTHO / H, 6),        # ortho_scale spans the LONGER axis (height)
    'scene_fps': sc.render.fps,
    'actions': {},
}

# character height in metres, for the importer to sanity-check scale
zs = []
for o in unit_objects(UNIT):
    if o.type == 'MESH' and o.name != U['gun']:
        zs += [(o.matrix_world @ v.co).z for v in o.data.vertices]
if zs:
    meta['character_height_m'] = round(max(zs) - min(zs), 4)

results = []
for act in sorted(bpy.data.actions, key=lambda a: a.name):
    name = act.name
    if name in SKIP_ACTIONS:
        print(f"SKIPPED (not rendered): {name}", flush=True)
        continue
    arm.animation_data.action = act
    if len(act.slots):
        arm.animation_data.action_slot = act.slots[0]
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    n = f1 - f0 + 1
    count = min(MAX_FRAMES, n)
    frames = [f0 + round(i * (n - 1) / max(count - 1, 1)) for i in range(count)]

    # real clip duration -> the fps the sampled strip must play at to match it
    duration_s = n / sc.render.fps
    play_fps = round(count / duration_s, 3) if duration_s > 0 else 12.0

    muzzle = [[None] * count for _ in range(DIRS)]
    ground_rows = []

    for d in range(DIRS):
        rig.rotation_euler = (0, 0, math.radians(45 * d))
        for i, f in enumerate(frames):
            sc.frame_set(f)
            bpy.context.view_layer.update()
            track_hips()
            bpy.context.view_layer.update()

            if muzzle_local is not None:
                muzzle[d][i] = px_of(gun.matrix_world @ muzzle_local)
            ground_rows.append(px_of(rig.matrix_world.translation)[1])

            path = os.path.join(TMP, f"{name}_{d}_{i}.png")
            if os.path.exists(path) and os.path.getsize(path) > 200:
                continue                      # resume: reuse good frames
            sc.render.filepath = path
            bpy.ops.render.render(write_still=True)

    meta['actions'][name] = {
        'columns': count,
        'source_frames': n,
        'duration_s': round(duration_s, 4),
        'fps': play_fps,
        'loop': name not in HOLD_LAST,
        'hold_last_frame': name in HOLD_LAST,
        'ground_row': round(sum(ground_rows) / len(ground_rows), 2),
        'muzzle_px': muzzle,
    }
    results.append((name, count))
    print(f"FRAMES DONE: {name} ({count} cols x {DIRS} dirs, {play_fps} fps, loop={name not in HOLD_LAST})", flush=True)

with open(os.path.join(TMP, '_meta.json'), 'w') as fp:
    json.dump(meta, fp, indent=1)
print("ALL FRAMES COMPLETE:", len(results), flush=True)
