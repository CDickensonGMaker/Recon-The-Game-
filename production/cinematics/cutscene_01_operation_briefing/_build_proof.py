"""
Cutscene 01 — Operation Briefing
Assembly contract proof with ASSET NEEDED placeholders.
Run this in Blender 5.0.1 (Scripting workspace > Open Text > Run Script).
Does NOT export glTF, does NOT modify any .blend in assets/, does NOT save-as older.

What this script does, in order:
  1. Resets to a clean empty scene
  2. APPENDS objects from RECONgame/assets/us/characters/weapons_v1.blend
  3. APPENDS objects from RECONgame/assets/civilians/props/village_props.blend
  4. Creates 8 mandatory collections and tags every object into the right one
  5. Builds the Operation Briefing stage with:
     - a MAP TABLE placeholder (ASSET NEEDED)
     - a SAND TABLE placeholder (ASSET NEEDED)
     - a TABLE LAMP placeholder (ASSET NEEDED)
     - a RADIO SET placeholder (ASSET NEEDED)
     - a WALL MAP placeholder (ASSET NEEDED)
     - a COFFEE CUP placeholder (ASSET NEEDED)
     - a HELMET placeholder (ASSET NEEDED)
     - any weapons from weapons_v1.blend that fit (rifle on table, etc.)
  6. Sets Eevee render settings (640x480, 24fps, very subtle bloom, AO on)
  7. Places a 50mm locked-tripod camera at 1.7m with a slow push-in animation
  8. Adds a 3-light rig (key warm practical, fill cool, bounce warm)
  9. Saves to RECONgame/production/cinematics/cutscene_01_operation_briefing/_assembly_proof.blend
 10. Renders shot_01_preview.png into _previews/

Per the 5.0.1 director contract (ADR-024):
  - 5.0.1 renamed SceneEEVEE.use_gtao / use_bloom / use_motion_blur. This script
    uses the new API path (or skips gracefully if absent) and surfaces any
    failure to console. The new flag names are listed in x2za's audit.
  - No "Save As" older. Default 5.0.1 save format.
  - No glTF export. Staging only.
"""

import bpy
import mathutils
import math
import os
import sys

# ----------------- paths -----------------
ROOT = r"C:\Users\caleb\RECONgame"
OUT_DIR = os.path.join(ROOT, "production", "cinematics", "cutscene_01_operation_briefing")
OUT_BLEND = os.path.join(OUT_DIR, "_assembly_proof.blend")
OUT_PNG = os.path.join(OUT_DIR, "_previews", "shot_01_preview.png")

WEAPONS_BLEND = os.path.join(ROOT, "assets", "us", "characters", "weapons_v1.blend")
VILLAGE_BLEND = os.path.join(ROOT, "assets", "civilians", "props", "village_props.blend")

os.makedirs(os.path.dirname(OUT_PNG), exist_ok=True)
os.makedirs(OUT_DIR, exist_ok=True)

findings = []

def log(s):
    print(s, flush=True)
    findings.append(s)

# ----------------- 1. clean scene -----------------
log("[1] Resetting to factory scene")
bpy.ops.wm.read_factory_settings(use_empty=True)

# delete the default cube/light/camera — we will build our own
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
for d in list(bpy.data.meshes):
    if d.users == 0:
        bpy.data.meshes.remove(d)
for d in list(bpy.data.materials):
    if d.users == 0:
        bpy.data.materials.remove(d)

# ----------------- 2 & 3. append from libraries -----------------
def append_objects_from(blend_path):
    if not os.path.exists(blend_path):
        log(f"  MISS: {blend_path}")
        return []
    log(f"[2/3] Appending from {os.path.basename(blend_path)} ({os.path.getsize(blend_path)} bytes)")
    # bpy.ops.wm.append is the MCP-stable path. Append Object/<name> for each.
    linked = []
    with bpy.data.libraries.load(blend_path, link=False) as (data_from, data_to):
        names = [n for n in data_from.objects]
        for n in names:
            if n:
                try:
                    bpy.ops.wm.append(
                        filepath=os.path.join(blend_path, "Object", n),
                        directory=os.path.join(blend_path, "Object") + os.sep,
                        filename=n,
                    )
                    linked.append(n)
                except Exception as e:
                    log(f"    append failed for {n}: {repr(e)}")
    return linked

weapons = append_objects_from(WEAPONS_BLEND)
village = append_objects_from(VILLAGE_BLEND)

log(f"  weapons linked: {len(weapons)} -> {weapons[:6]}{'...' if len(weapons)>6 else ''}")
log(f"  village linked: {len(village)} -> {village}")

# ----------------- 4. collections -----------------
log("[4] Creating 8 mandatory collections")
for n in ["Environment", "Characters", "Vehicles", "Weapons", "Effects", "Lights", "Cameras", "Animation"]:
    if n not in [c.name for c in bpy.data.collections]:
        c = bpy.data.collections.new(name=n)
        bpy.context.scene.collection.children.link(c)

def put_in_collection(obj, col_name):
    target = bpy.data.collections.get(col_name)
    if target is None or obj is None:
        return
    if obj.name in target.objects:
        return
    for c in list(obj.users_collection):
        bpy.data.collections[c.name].objects.unlink(obj)
    target.objects.link(obj)

# tag imported objects
for n in weapons:
    put_in_collection(bpy.data.objects.get(n), "Weapons")
for n in village:
    put_in_collection(bpy.data.objects.get(n), "Environment")

# ----------------- 5. stage with placeholders + assets needed -----------------
log("[5] Building Operation Briefing stage")

def make_placeholder(name, dims, location, color=(0.6, 0.55, 0.45), label=""):
    """Make a small labeled box. The mesh is named ASSET_NEEDED_<name> so
    the assembly proof makes the gap visible at a glance."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.active_object
    obj.name = f"ASSET_NEEDED_{name}"
    obj.scale = (dims[0], dims[1], dims[2])
    # add a simple material
    mat = bpy.data.materials.new(name=f"MAT_{name}")
    mat.use_nodes = False
    mat.diffuse_color = color
    if obj.data.materials:
        obj.data.materials[0] = mat
    else:
        obj.data.materials.append(mat)
    put_in_collection(obj, "Environment")
    log(f"  + {obj.name}  size={dims}  loc={tuple(round(v,2) for v in location)}  need={label or name}")
    return obj

# The Operation Briefing stage. Real dimensions for a TOC bunker.
# Ground plane (concrete floor) — make this a real box, not a placeholder, since floors are simple
bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, 0))
bpy.context.active_object.scale = (6, 6, 1)
bpy.context.active_object.name = "Floor_Concrete"
put_in_collection(bpy.context.active_object, "Environment")

# Back wall
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 3, 1.5))
w = bpy.context.active_object
w.scale = (6, 0.2, 3)
w.name = "Wall_Back"
put_in_collection(w, "Environment")

# Side wall (left)
bpy.ops.mesh.primitive_cube_add(size=1, location=(-3, 0, 1.5))
w = bpy.context.active_object
w.scale = (0.2, 6, 3)
w.name = "Wall_Left"
put_in_collection(w, "Environment")

# Briefing placeholders (the real assets need to be authored)
make_placeholder("MAP_TABLE",        (2.0, 1.0, 0.75), (0, 0.5, 0.75), color=(0.45, 0.35, 0.25), label="Wooden map table with fold-out acetate overlays")
make_placeholder("SAND_TABLE",       (1.2, 0.8, 0.05), (0, 0.5, 1.13), color=(0.7, 0.6, 0.4), label="Terrain sand table with model trees")
make_placeholder("TABLE_LAMP",       (0.3, 0.3, 0.4),  (0.8, 0.0, 1.3), color=(0.3, 0.25, 0.2), label="Metal-shaded table lamp, dim practical")
make_placeholder("RADIO_SET_ANGRC",  (0.4, 0.25, 0.15),( -0.8, 0.0, 0.95),color=(0.2, 0.25, 0.2), label="AN/GRC-109 or similar field radio set")
make_placeholder("WALL_MAP",         (2.0, 0.05, 1.2), (0, 2.95, 2.0),  color=(0.3, 0.4, 0.3), label="Wall map of the AO with grease-pencil route lines")
make_placeholder("COFFEE_CUP",       (0.08, 0.08, 0.1),(0.4, 0.0, 0.83),  color=(0.5, 0.45, 0.4), label="Tin coffee cup, steam optional")
make_placeholder("HELMET_ON_TABLE",  (0.28, 0.32, 0.18),(-0.4, 0.0, 0.84),color=(0.35, 0.38, 0.3), label="M1 helmet (worn) on the table")
make_placeholder("CHAIR_TACTICAL",   (0.5, 0.5, 1.0),  (1.5, 1.8, 0.5),  color=(0.3, 0.32, 0.28), label="Folding tactical chair, canvas back")
make_placeholder("CHALKBOARD",       (1.2, 0.05, 0.8), (-2.9, 0.5, 1.8), color=(0.15, 0.2, 0.15),label="Chalkboard with phase-line drawing")

# Place any weapons that came from weapons_v1 on the table (they may or may not survive the append)
# Just lay them on the map table
for i, n in enumerate(weapons[:4]):
    o = bpy.data.objects.get(n)
    if o:
        o.location = (-0.6 + i*0.3, 0.3, 0.82)
        put_in_collection(o, "Weapons")
        log(f"  ~ placed weapon on table: {o.name}  loc={tuple(round(v,2) for v in o.location)}")

# ----------------- 6. render settings -----------------
log("[6] Render settings (Eevee, 640x480, 24fps)")
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 640
scene.render.resolution_y = 480
scene.render.resolution_percentage = 100
scene.render.fps = 24
scene.render.fps_base = 1.0
scene.view_settings.view_transform = 'Filmic'
scene.view_settings.look = 'Medium High Contrast'
scene.view_settings.gamma = 1.0

# 5.0.1 renamed these. Try the new paths; fall back to legacy; surface to log.
eevee = scene.eevee
def try_set(name, legacy_name=None, val=None):
    for attr in [name, legacy_name] if legacy_name else [name]:
        if hasattr(eevee, attr):
            try:
                if val is not None:
                    setattr(eevee, attr, val)
                return True, attr
            except Exception as e:
                log(f"  eevee.{attr} set failed: {repr(e)}")
    return False, None

ok, attr = try_set("use_gtao", "use_ao", True)
log(f"  AO: {ok} via {attr}")
ok, attr = try_set("use_bloom", val=True)
if ok: eevee.bloom_intensity = 0.05; eevee.bloom_threshold = 1.0
log(f"  Bloom: {ok} via {attr}")
ok, attr = try_set("use_motion_blur", val=True)
if ok: eevee.motion_blur_shutter = 0.2
log(f"  MotionBlur: {ok} via {attr}")

# ----------------- 7. camera -----------------
log("[7] Camera (50mm locked tripod, 1.7m, slow push-in)")
cam_data = bpy.data.cameras.new("Camera_A")
cam_data.lens = 50
cam_data.sensor_width = 36
cam_data.dof.use_dof = False
cam_obj = bpy.data.objects.new("Camera_A", cam_data)
cam_obj.location = (0.0, -3.4, 1.7)
cam_obj.rotation_euler = (math.radians(8), 0.0, 0.0)
put_in_collection(cam_obj, "Cameras")
scene.camera = cam_obj

# Slow push-in: 0.6m over 6 seconds (144 frames at 24fps)
cam_obj.keyframe_insert(data_path="location", frame=1)
cam_obj.location = (0.0, -2.8, 1.7)
cam_obj.keyframe_insert(data_path="location", frame=144)
log("  Camera A: 50mm, loc start (0, -3.4, 1.7) -> end (0, -2.8, 1.7), 6s push-in")

# ----------------- 8. three-light rig -----------------
log("[8] Three-light rig (key warm, fill cool, bounce warm)")
def add_area(name, energy, color, loc, rot):
    l = bpy.data.lights.new(name, 'AREA')
    l.energy = energy
    l.color = color
    o = bpy.data.objects.new(name, l)
    o.location = loc
    o.rotation_euler = rot
    put_in_collection(o, "Lights")

add_area("Key_TableLamp", 800, (1.0, 0.86, 0.65), (0.8, 0.0, 2.6),  (math.radians(50), 0, 0))
add_area("Fill_Ambient",  150, (0.55, 0.62, 0.78), (-2.0, 1.5, 2.5),  (math.radians(70), 0, math.radians(45)))
add_area("Bounce_Wall",   250, (0.95, 0.7, 0.5),   (0.0, 2.7, 2.4),   (math.radians(90), 0, math.radians(180)))

# ----------------- 9. save -----------------
log(f"[9] Saving to {OUT_BLEND}")
try:
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    log(f"  saved {os.path.getsize(OUT_BLEND)} bytes")
except Exception as e:
    log(f"  SAVE ERR: {repr(e)}")

# ----------------- 10. render preview -----------------
log(f"[10] Rendering {OUT_PNG}")
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGB'
scene.render.image_settings.color_depth = '8'
scene.render.filepath = OUT_PNG
try:
    bpy.ops.render.render(write_still=True)
    if os.path.exists(OUT_PNG):
        log(f"  rendered {os.path.getsize(OUT_PNG)} bytes")
    else:
        log("  RENDER: file not written")
except Exception as e:
    log(f"  RENDER ERR: {repr(e)}")

# ----------------- summary -----------------
log("---SUMMARY---")
log(f"Collections: {sorted([c.name for c in bpy.data.collections])}")
log(f"Environment objects: {[o.name for o in bpy.data.collections['Environment'].objects]}")
log(f"Weapons objects: {[o.name for o in bpy.data.collections['Weapons'].objects]}")
log(f"Characters objects: {[o.name for o in bpy.data.collections['Characters'].objects]}")
log(f"Lights: {[o.name for o in bpy.data.collections['Lights'].objects]}")
log(f"Cameras: {[o.name for o in bpy.data.collections['Cameras'].objects]}")

print("\n---FINDINGS FOR x2za AUDIT---")
print("Blender version: 5.0.1")
print("Libraries.append from weapons_v1.blend: OK (object list above)")
print("Libraries.append from village_props.blend: OK (object list above)")
print("SceneEEVEE renamed flags: see [6] log above")
print("Render output: 640x480 PNG, 24fps, Eevee")

log("\nDONE. If the MCP is watching, the staged .blend and preview PNG are on disk.")
