"""Build the US Army helicopter pilot (UH-1 / AH-1 crew, late war 1970-72).

Per reference_us_aircrew.md. The three cues that must survive to 32px:
  1. SPH-4 helmet - huge protruding earcups, brow visor shelf
  2. Chicken plate - smooth convex slab squaring the chest, standing off the body
  3. No mask, no harness, no G-suit (that's the fixed-wing pilot)

Geometry is rounder than the grunt: 4-segment bevels, wider bevel widths,
auto-smooth shading, and tapered limbs with no hard shoulder corners.

Parts bind rigidly (one vertex group per part at weight 1.0 + armature modifier),
the same method proven on the VC variants.

Run: blender -b "unit_us_pilot.blend" -P build_pilot_helo.py
"""
import bpy, bmesh, sys, math
import numpy as np
from mathutils import Vector

sys.path.insert(0, r'C:\Users\caleb\RECONgame\tools')
import vc_builder as V

OUT = r"C:\Users\caleb\RECONgame\art_source\characters\us units\unit_us_pilot_helo.blend"

# Streamlined = MORE bevel segments at the SAME width. Widening the bevel (an
# earlier attempt used 1.35x) eats the part's volume and turns it into a blob.
def _bevel_smooth(ob, w, segs=4):
    if w <= 0: return
    b = ob.modifiers.new('Bevel', 'BEVEL')
    b.width = w
    b.segments = segs
    b.limit_method = 'ANGLE'
    b.angle_limit = 0.7
V._bevel = _bevel_smooth

# ------------------------------------------------------------------ scene reset
rig = bpy.data.objects['MixamoRig']
for ob in list(bpy.data.objects):
    if ob.type == 'MESH':
        bpy.data.objects.remove(ob, do_unlink=True)
rig.data.pose_position = 'REST'
if rig.animation_data:
    rig.animation_data.action = None
bpy.context.view_layer.update()

coll = bpy.context.scene.collection

# ------------------------------------------------------------------ materials
hx = V.hx
FLIGHTSUIT = V.worn_mat('Nomex_OG106', '5A5C3E', '6E7050', scale=30.0)   # OG-106 nomex
SKIN       = V.flat_mat('PilotSkin', 'C99A76', rough=0.72)
GLOVE_BACK = V.flat_mat('GloveNomex', '5F6446', rough=0.85)
GLOVE_PALM = V.flat_mat('GloveLeather', 'B39A72', rough=0.7)
HELMET     = V.worn_mat('SPH4_Shell', '3E4433', '4C5240', scale=18.0)
BROW       = V.flat_mat('SPH4_Housing', '333A2C', rough=0.55)
EARCUP     = V.flat_mat('SPH4_Earcup', '2E332A', rough=0.6)
PLATE      = V.worn_mat('ChickenPlate', '4C5138', '565C40', scale=22.0)
WEBBING    = V.flat_mat('PlateWebbing', '3A4030', rough=0.95)
VEST       = V.flat_mat('SRU21P', '4E5239', rough=0.95)
BOOT_LEAT  = V.flat_mat('BootLeather', '2A2622', rough=0.55)
BOOT_NYL   = V.flat_mat('BootNylon', '4E5238', rough=0.95)
BLACKRUB   = V.flat_mat('BlackRubber', '232323', rough=0.85)
MICCAP     = V.flat_mat('MicCapsule', '2E2E2E', rough=0.7)
LEATHER    = V.flat_mat('HolsterLeather', '1E1A18', rough=0.5)
STEEL      = V.flat_mat('SteelBits', '9A9C99', rough=0.4)

# tinted visor: dark, glossy, slightly transmissive
VISOR = bpy.data.materials.new('SPH4_Visor')
VISOR.use_nodes = True
_vb = VISOR.node_tree.nodes['Principled BSDF']
_vb.inputs['Base Color'].default_value = (*hx('2B2E2C'), 1)
_vb.inputs['Roughness'].default_value = 0.08
_vb.inputs['Metallic'].default_value = 0.25

FACE = V.face_tex('face_pilot', 'C99A76')

# ------------------------------------------------------------------ body
D = V.build_body(coll, px=0.0, height=1.80, slim=1.0,
                 shirt=FLIGHTSUIT, trouser=FLIGHTSUIT, skin=SKIN,
                 sleeves='long', legs='long', feet='boots',
                 face_mat=FACE, sole_mat=BOOT_LEAT)
sz, sw = D['sz'], D['sw']
def Z(v): return v * sz
def W(v): return v * sw
HEAD_Z0, HEAD_TOP = D['head_z0'], D['head_top']
HEAD_MID = (HEAD_Z0 + HEAD_TOP) / 2

# jungle-boot shafts get the olive nylon upper (silhouette differentiator)
for p in ('l', 'r'):
    sh = bpy.data.objects[f'{p}_bootshaft']
    sh.data.materials.clear()
    sh.data.materials.append(BOOT_NYL)

# two-tone Nomex gloves replace bare hands
for s, p in [(1, 'l'), (-1, 'r')]:
    h = bpy.data.objects[f'{p}_hand']
    h.data.materials.clear()
    h.data.materials.append(GLOVE_BACK)
    # gauntlet cuff riding up onto the forearm
    V.tbox_x(coll, f'{p}_gauntlet', 0.0 + s * W(0.555), 0.0 + s * W(0.625),
             W(0.048), W(0.044), W(0.042), W(0.038), D['arm_z'] - Z(0.025),
             GLOVE_BACK, bev=0.016)

# ------------------------------------------------------------------ SPH-4 helmet
# Measure the head box we just built and wrap the helmet around it, rather than
# guessing offsets: the shell must swallow the skull, leaving only the face.
_h = bpy.data.objects['head']
_hb = [Vector(c) for c in _h.bound_box]
HW = max(v.x for v in _hb)          # head half-width
HD = max(v.y for v in _hb)          # head half-depth
HZ0 = min(v.z for v in _hb)         # chin
HZ1 = max(v.z for v in _hb)         # crown
BROW_Z = HZ0 + (HZ1 - HZ0) * 0.62   # eyeline-ish

# shell: dome seated so its equator is at the brow and its crown clears the skull
V.half_dome(coll, 'sph4_shell', HELMET, (0.0, W(0.006), BROW_Z),
            r=HW * 1.30, squash=(1.0, 1.10, 0.92))

# shell skirt: rings the head from brow down past the ears
V.prim(coll, 'sph4_skirt', 'cyl', HELMET,
       (0.0, W(0.006), BROW_Z - Z(0.030)),
       r=HW * 1.30, depth=Z(0.060), verts=20, bev=0.004)

# brow visor housing: broad cowl projecting forward over the eyes
V.tbox(coll, 'sph4_brow', BROW_Z - Z(0.004), BROW_Z + Z(0.030),
       HW * 1.22, HD * 1.16, HW * 1.16, HD * 1.20,
       cx=0.0, cy=-W(0.008), mat=BROW, bev=0.014)

# the visor, dropped over the eyes: a shallow wrap across the face
V.tbox(coll, 'sph4_visor', BROW_Z - Z(0.048), BROW_Z - Z(0.002),
       HW * 1.05, HD * 1.15, HW * 1.14, HD * 1.17,
       cx=0.0, cy=-W(0.006), mat=VISOR, bev=0.010)

# THE silhouette cue: earcups standing proud of the shell
EAR_X = HW * 1.30
for s, p in [(1, 'l'), (-1, 'r')]:
    V.prim(coll, f'sph4_earcup_{p}', 'cyl', EARCUP,
           (s * (EAR_X + W(0.010)), W(0.008), BROW_Z - Z(0.026)),
           rot=(0, math.radians(90), 0), r=HW * 0.62, depth=W(0.026), verts=16, bev=0.006)

# chin strap under the jaw
V.tbox(coll, 'sph4_chinstrap', HZ0 + Z(0.004), HZ0 + Z(0.022),
       HW * 1.02, HD * 1.02, HW * 1.02, HD * 1.02, cx=0.0, mat=BLACKRUB, bev=0.004)

# boom mic: swan-neck arm from the LEFT earcup, capsule at the corner of the mouth
V.prim(coll, 'boom_arm', 'cyl', BLACKRUB,
       (EAR_X * 0.72, -HD * 0.78, BROW_Z - Z(0.048)),
       rot=(math.radians(70), 0, math.radians(34)), r=W(0.0045), depth=W(0.115), verts=8)
V.prim(coll, 'boom_mic', 'cyl', MICCAP,
       (EAR_X * 0.30, -HD * 1.28, HZ0 + Z(0.052)),
       rot=(math.radians(90), 0, 0), r=W(0.012), depth=W(0.018), verts=10)

# ------------------------------------------------------------------ chicken plate
# convex slab: build a box, then bow the front face forward so it reads curved
plate = V.tbox(coll, 'chicken_plate', Z(0.955), Z(1.395),
               W(0.170), W(0.128), W(0.178), W(0.132), cx=0.0, mat=PLATE, bev=0.030)
bpy.context.view_layer.update()
me = plate.data
for v in me.vertices:
    if v.co.y < 0:                       # front face only
        t = 1.0 - abs(v.co.x) / W(0.185)     # 1 at centre, 0 at the edges
        v.co.y -= W(0.030) * max(t, 0.0) ** 1.4   # bow it out
        v.co.z += Z(0.004) * max(t, 0.0)
# chamfer the top corners so it doesn't read as a fridge
for v in me.vertices:
    if v.co.z > Z(1.37) and abs(v.co.x) > W(0.14):
        v.co.x *= 0.90
        v.co.z -= Z(0.012)

# carrier: shoulder straps over the traps, waistband wrapping the belly
for s, p in [(1, 'l'), (-1, 'r')]:
    V.tbox(coll, f'plate_shoulder_{p}', Z(1.33), Z(1.44),
           W(0.030), W(0.105), W(0.030), W(0.100), cx=s * W(0.088), mat=WEBBING, bev=0.008)
V.tbox(coll, 'plate_waistband', Z(0.960), Z(1.020),
       W(0.168), W(0.126), W(0.168), W(0.126), cx=0.0, mat=WEBBING, bev=0.012)

# survival vest collar peeking out from under the armour
V.tbox(coll, 'vest_collar', Z(1.395), Z(1.445),
       W(0.150), W(0.112), W(0.140), W(0.106), cx=0.0, mat=VEST, bev=0.014)

# ------------------------------------------------------------------ sidearm rig
# low-slung thigh holster, right leg - the Army aviator's buscadero rig
V.tbox(coll, 'holster_belt', Z(0.905), Z(0.945), W(0.170), W(0.122),
       W(0.170), W(0.122), cx=0.0, mat=LEATHER, bev=0.010)
V.tbox(coll, 'holster_body', Z(0.640), Z(0.860), W(0.040), W(0.038),
       W(0.044), W(0.042), cx=-W(0.118), cy=-W(0.020), mat=LEATHER, bev=0.016)
V.prim(coll, 'holster_grip', 'cube', BLACKRUB,
       (-W(0.118), -W(0.030), Z(0.878)), rot=(0, 0, math.radians(6)),
       scale=(W(0.016), W(0.012), Z(0.028)), bev=0.006)
V.tbox(coll, 'holster_tiedown', Z(0.600), Z(0.650), W(0.052), W(0.050),
       W(0.052), W(0.050), cx=-W(0.118), mat=LEATHER, bev=0.006)

# ------------------------------------------------------------------ shading
# Smooth the bevel rounds, keep the flat panels flat: mark faces smooth, then let
# EdgeSplit re-harden anything meeting at more than 40deg. Bevel modifiers are
# evaluated first, so this smooths the new rounded corners only.
for ob in bpy.data.objects:
    if ob.type != 'MESH':
        continue
    for f in ob.data.polygons:
        f.use_smooth = True
    es = ob.modifiers.new('EdgeSplit', 'EDGE_SPLIT')
    es.split_angle = math.radians(40)
    es.use_edge_sharp = False

# ------------------------------------------------------------------ rigid bind
MAP = {
    'hem': 'Hips', 'waist': 'Spine', 'torso': 'Spine2', 'neck': 'Neck', 'head': 'Head',
    'l_thigh': 'LeftUpLeg', 'l_shin': 'LeftLeg', 'l_bootfoot': 'LeftFoot', 'l_bootshaft': 'LeftLeg',
    'r_thigh': 'RightUpLeg', 'r_shin': 'RightLeg', 'r_bootfoot': 'RightFoot', 'r_bootshaft': 'RightLeg',
    'l_shoulder': 'LeftArm', 'l_uparm': 'LeftArm', 'l_loarm': 'LeftForeArm',
    'l_hand': 'LeftHand', 'l_gauntlet': 'LeftForeArm',
    'r_shoulder': 'RightArm', 'r_uparm': 'RightArm', 'r_loarm': 'RightForeArm',
    'r_hand': 'RightHand', 'r_gauntlet': 'RightForeArm',
    # flight gear
    'sph4_shell': 'Head', 'sph4_skirt': 'Head', 'sph4_brow': 'Head', 'sph4_visor': 'Head',
    'sph4_earcup_l': 'Head', 'sph4_earcup_r': 'Head', 'sph4_chinstrap': 'Head',
    'boom_arm': 'Head', 'boom_mic': 'Head',
    'chicken_plate': 'Spine2', 'plate_shoulder_l': 'Spine2', 'plate_shoulder_r': 'Spine2',
    'plate_waistband': 'Spine', 'vest_collar': 'Spine2',
    'holster_belt': 'Hips', 'holster_body': 'RightUpLeg',
    'holster_grip': 'RightUpLeg', 'holster_tiedown': 'RightUpLeg',
}

bound, unbound = 0, []
for ob in bpy.data.objects:
    if ob.type != 'MESH':
        continue
    bone = MAP.get(ob.name)
    if bone is None:
        unbound.append(ob.name)
        continue
    ob.vertex_groups.clear()
    vg = ob.vertex_groups.new(name=f'mixamorig:{bone}')
    vg.add(range(len(ob.data.vertices)), 1.0, 'REPLACE')
    for m in list(ob.modifiers):
        if m.type == 'ARMATURE':
            ob.modifiers.remove(m)
    ob.modifiers.new('Armature', 'ARMATURE').object = rig
    bound += 1

print(f"bound {bound} parts; UNBOUND: {unbound}", flush=True)

tris = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == 'MESH')
print(f"parts={bound} faces={tris}", flush=True)

for a in bpy.data.actions:
    a.use_fake_user = True

bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("HELO PILOT SAVED:", OUT, flush=True)
