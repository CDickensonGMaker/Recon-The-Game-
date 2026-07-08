"""Add 3 new units to sprite_stage.blend:
  us_grunt_black + M60      (skin + face texture darkened, own rig copy)
  vc3_sapper     + RPD
  vc6_heavy      + RPG-2

Guns are joined into single meshes and floated in front of each unit at chest
height. The user places them into the hands; anchor_guns.py then constrains them.

Run: blender -b sprite_stage.blend -P add_variants.py
"""
import bpy, numpy as np
from mathutils import Vector

CHAR = r"C:\Users\caleb\RECONgame\art_source\characters"
GUER = CHAR + r"\vc and nva units\unit_vc_guerilla.blend"
WUS  = CHAR + r"\us units\weapons_us.blend"
WV1  = CHAR + r"\us units\weapons_v1.blend"
SC = bpy.context.scene

def link(ob):
    if ob.name not in [o.name for o in SC.objects]:
        SC.collection.objects.link(ob)
    return ob

# ===================== 1. BLACK GRUNT + M60 =====================
src_mesh = bpy.data.objects['US_Grunt_Rigged']
src_rig  = bpy.data.objects['MixamoRig']

rig2 = src_rig.copy()                 # shares armature data, own pose/transform
rig2.name = 'RigUSM60'
link(rig2)
if rig2.animation_data:
    rig2.animation_data.action = None

m2 = src_mesh.copy()
m2.data = src_mesh.data.copy()
m2.name = 'US_Grunt_M60_Rigged'
link(m2)
m2.parent = rig2
m2.matrix_parent_inverse = src_mesh.matrix_parent_inverse.copy()
for mod in m2.modifiers:
    if mod.type == 'ARMATURE':
        mod.object = rig2

# --- darker skin material ---
skin_dark = bpy.data.materials['Skin'].copy()
skin_dark.name = 'Skin_Black'
bsdf = next(n for n in skin_dark.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
bsdf.inputs['Base Color'].default_value = (0.105, 0.055, 0.032, 1.0)   # deep brown (linear)
bsdf.inputs['Roughness'].default_value = 0.62

# --- darker face texture: per-channel gain preserves eyes/stubble contrast ---
src_img = bpy.data.images['face_tex']
w, h = src_img.size
px = np.array(src_img.pixels[:], dtype=np.float32).reshape(h, w, 4)
rgb = px[:, :, :3]
lum = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
skin_px = rgb[lum > 0.35]                    # the tan face area, not eyes/brows
if len(skin_px):
    mean = skin_px.mean(axis=0)
    target = np.array([0.42, 0.27, 0.19], dtype=np.float32)   # sRGB deep brown
    gain = np.clip(target / np.maximum(mean, 1e-4), 0.0, 1.0)
else:
    gain = np.array([0.5, 0.5, 0.55], dtype=np.float32)
new_img = bpy.data.images.new('face_tex_black', w, h, alpha=True)
out = px.copy()
out[:, :, :3] = np.clip(rgb * gain, 0, 1)
new_img.pixels.foreach_set(np.ascontiguousarray(out, dtype=np.float32).ravel())
print(f"face gain {tuple(round(float(g),3) for g in gain)}", flush=True)

face_dark = bpy.data.materials['FaceTex'].copy()
face_dark.name = 'FaceTex_Black'
for n in face_dark.node_tree.nodes:
    if n.type == 'TEX_IMAGE':
        n.image = new_img

for i, m in enumerate(m2.data.materials):
    if m and m.name.startswith('Skin'):
        m2.data.materials[i] = skin_dark
    elif m and m.name.startswith('FaceTex'):
        m2.data.materials[i] = face_dark

rig2.location.x = src_rig.location.x - 3.0
print("black grunt built at x", round(rig2.location.x, 2), flush=True)

# ===================== 2. VC3 + VC6 =====================
farmer_map = {}
for ob in bpy.data.collections['VC1_Farmer'].objects:
    if ob.type == 'MESH' and ob.vertex_groups:
        farmer_map[ob.name.split('.')[0]] = ob.vertex_groups[0].name

def keyword_bone(base):
    b = base.lower()
    side = 'Left' if b.startswith('l_') else ('Right' if b.startswith('r_') else '')
    if 'pith' in b or 'brim' in b or 'nonla' in b: return 'mixamorig:Head'
    if 'bootshaft' in b:  return f'mixamorig:{side}Leg'
    if 'bootfoot' in b:   return f'mixamorig:{side}Foot'
    if b in ('l_short', 'r_short'): return f'mixamorig:{side}UpLeg'
    if 'pouch' in b or 'canteen' in b: return 'mixamorig:Hips'
    if any(k in b for k in ('satchel', 'strap', 'rack', 'spare', 'ruck', 'chicom', 'riceroll')):
        return 'mixamorig:Spine2'
    return None

PARTS = [('l_uparm','mixamorig:LeftArm'), ('l_loarm','mixamorig:LeftForeArm'),
         ('r_uparm','mixamorig:RightArm'), ('r_loarm','mixamorig:RightForeArm'),
         ('torso','mixamorig:Spine2'), ('head','mixamorig:Head'),
         ('l_thigh','mixamorig:LeftUpLeg'), ('r_thigh','mixamorig:RightUpLeg')]

def part_center(coll, base):
    for ob in bpy.data.collections[coll].objects:
        if ob.name.split('.')[0] == base:
            cs = [ob.matrix_world @ v.co for v in ob.data.vertices]
            return sum(cs, Vector()) / len(cs)

def bone_mid(rig, bname):
    b = rig.data.bones[bname]
    return rig.matrix_world @ ((b.head_local + b.tail_local) / 2)

def unit_bbox(coll):
    mn = Vector((1e9,)*3); mx = Vector((-1e9,)*3)
    for ob in bpy.data.collections[coll].objects:
        if ob.type != 'MESH': continue
        for c in ob.bound_box:
            wv = ob.matrix_world @ Vector(c)
            mn = Vector(map(min, mn, wv)); mx = Vector(map(max, mx, wv))
    return mn, mx

with bpy.data.libraries.load(GUER) as (df, dt):
    dt.collections = ['VC3_Sapper', 'VC6_Heavy']

rigF = bpy.data.objects['MixamoRig_VC1']
fmn, fmx = unit_bbox('VC1_Farmer')
f_h = fmx.z - fmn.z

for cn, rign, xpos in [('VC3_Sapper', 'RigVC3', 7.5), ('VC6_Heavy', 'RigVC6', 10.5)]:
    coll = bpy.data.collections[cn]
    SC.collection.children.link(coll)
    mn, mx = unit_bbox(cn)
    ratio = (mx.z - mn.z) / f_h
    # move the body parts to the unit's own lane first
    dx = xpos - (mn.x + mx.x) / 2
    for ob in coll.objects:
        ob.location.x += dx
    bpy.context.view_layer.update()

    rig = rigF.copy(); rig.name = rign; link(rig)
    rig.scale = rigF.scale * ratio
    rig.location = (xpos, rigF.location.y, rigF.location.z)
    bpy.context.view_layer.update()

    unbound = []
    for ob in coll.objects:
        if ob.type != 'MESH': continue
        base = ob.name.split('.')[0]
        bone = farmer_map.get(base) or keyword_bone(base)
        if bone is None:
            unbound.append(ob.name); continue
        ob.vertex_groups.clear()
        vg = ob.vertex_groups.new(name=bone)
        vg.add(range(len(ob.data.vertices)), 1.0, 'REPLACE')
        for m in list(ob.modifiers):
            if m.type == 'ARMATURE': ob.modifiers.remove(m)
        ob.modifiers.new('Armature', 'ARMATURE').object = rig

    # align the rig to the body (the fix that saved VC2/VC5)
    offs = []
    for base, bone in PARTS:
        pc = part_center(cn, base)
        if pc: offs.append(pc - bone_mid(rig, bone))
    rig.location += sum(offs, Vector()) / len(offs)
    bpy.context.view_layer.update()
    worst = max((part_center(cn, b) - bone_mid(rig, bn)).length for b, bn in PARTS)
    print(f"{cn}: {rign} ratio={ratio:.3f} unbound={unbound} worst_residual={worst*100:.1f}cm", flush=True)

    if rig.animation_data:
        rig.animation_data.action = None

# ===================== 3. GUNS, joined + floated =====================
def append_join(blend, prefix, new_name):
    with bpy.data.libraries.load(blend) as (df, dt):
        dt.objects = [n for n in df.objects if n.startswith(prefix)]
    parts = []
    for ob in bpy.data.objects:
        if ob.name.startswith(prefix) and ob.type == 'MESH' and not ob.users_collection:
            link(ob); parts.append(ob)
    if not parts:
        print(f"!! no parts for {prefix}", flush=True); return None
    bpy.ops.object.select_all(action='DESELECT')
    for ob in parts:
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.convert(target='MESH')   # bake bevel modifiers
    bpy.ops.object.select_all(action='DESELECT')
    for ob in parts: ob.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    gun = bpy.context.view_layer.objects.active
    gun.name = new_name
    print(f"{new_name}: joined {len(parts)} parts, {len(gun.data.vertices)} verts", flush=True)
    return gun

def float_in_front(gun, x, z=1.05):
    """Put the gun's muzzle-end at x-0.45, bore at height z, in front of the unit."""
    mn = min((gun.matrix_world @ Vector(c)).x for c in gun.bound_box)
    mid_y = sum((gun.matrix_world @ Vector(c)).y for c in gun.bound_box) / 8
    mid_z = sum((gun.matrix_world @ Vector(c)).z for c in gun.bound_box) / 8
    gun.location.x += (x - 0.45) - mn
    gun.location.y += -0.55 - mid_y
    gun.location.z += z - mid_z

m60 = append_join(WUS, 'M60_', 'M60_MG')
if m60: float_in_front(m60, bpy.data.objects['RigUSM60'].location.x)
rpd = append_join(WV1, 'RPD_', 'RPD_MG')
if rpd: float_in_front(rpd, 7.5)
rpg = append_join(WV1, 'RPG2_', 'RPG2_Launcher')
if rpg: float_in_front(rpg, 10.5)

# ===================== 4. pose everyone for placement =====================
act = bpy.data.actions.get('rifle_aiming_idle')
for rign in ('RigUSM60', 'RigVC3', 'RigVC6'):
    rig = bpy.data.objects[rign]
    if rig.animation_data is None: rig.animation_data_create()
    rig.animation_data.action = act
    if len(act.slots): rig.animation_data.action_slot = act.slots[0]
SC.frame_set(15)
bpy.context.view_layer.update()

bpy.ops.wm.save_mainfile()
print("VARIANTS ADDED + SAVED", flush=True)
