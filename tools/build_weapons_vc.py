"""Build v2 communist-bloc weapons into weapons_vc.blend.

AK-47/Type 56, Mosin-Nagant 91/30, PPSh-41, RPD, RPG-2 (+PG-2 rocket).
Data from blueprint_soviet_rifles.md + blueprint_soviet_support.md.
Rows along Y (0.5 m apart), muzzle at x=0, bore z=0.3 — same armory
layout as weapons_us.blend.

Run:  blender -b --factory-startup -P build_weapons_vc.py
"""
import bpy, sys, math
from mathutils import Vector

import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recon_paths import WEAPONS_VC_OUT
from weapon_builder import build_weapon, build_part, build_markers, MM

# ---------- clean scene (skipped in LIVE mode: building alongside v1 guns) ----------
LIVE = globals().get('LIVE', False)
if not LIVE:
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)

# ---------- materials ----------
def mat(name, hexs, rough, metal):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    r = int(hexs[0:2], 16) / 255; g = int(hexs[2:4], 16) / 255; bl = int(hexs[4:6], 16) / 255
    b.inputs['Base Color'].default_value = (r**2.2, g**2.2, bl**2.2, 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    return m

def wood_mat(name, hex1, hex2):
    """Wave-grain wood like the US Walnut: color ramp between two tones."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes['Principled BSDF']
    b.inputs['Roughness'].default_value = 0.45
    tex = nt.nodes.new('ShaderNodeTexWave')
    tex.inputs['Scale'].default_value = 3.0
    tex.inputs['Distortion'].default_value = 4.0
    tex.inputs['Detail'].default_value = 1.0
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    def rgb(h):
        return tuple((int(h[i:i+2],16)/255)**2.2 for i in (0,2,4)) + (1,)
    ramp.color_ramp.elements[0].color = rgb(hex1)
    ramp.color_ramp.elements[1].color = rgb(hex2)
    nt.links.new(tex.outputs['Color'], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], b.inputs['Base Color'])
    return m

BLUED  = mat('BluedSteelVC', '2B2B30', 0.55, 0.85)
WORN   = mat('WornBlue',     '4A4A52', 0.5,  0.8)
BRIGHT = mat('BrightSteel',  '8E8E96', 0.35, 0.9)
BANDS  = mat('SteelBands',   '3A3A40', 0.5,  0.7)
GAS    = mat('GasTubeTint',  '5A5248', 0.6,  0.6)
HEAT   = mat('HeatSteel',    '1F1F22', 0.7,  0.7)
OLIVE  = mat('WarheadOD',    '4A5D3A', 0.6,  0.1)
DRUMOL = mat('DrumOlive',    '4C5844', 0.65, 0.3)
MATTE  = mat('MatteBlackVC', '1E1E20', 0.9,  0.1)
# Wood hexes hold red:blue near 2:1. The previous set ran 4:1 ('7A3E1E' etc.)
# and read as orange-red under the Standard view transform this scene forces.
W_T56  = wood_mat('WoodT56',   '4A3526', '5C4433')
W_SOV  = wood_mat('WoodSoviet','6A5138', '7C6044')
W_BIRCH= wood_mat('WoodBirch', '8A6E45', '9C8055')
W_RPD  = wood_mat('WoodRPD',   '5E4A33', '6E5940')
W_RPG  = wood_mat('WoodRPG',   '4C3D2B', '5E4E39')
BAKE   = mat('Bakelite',     '4A2C1A', 0.35, 0.0)

Z = 0.3   # bore height

# =====================================================================
# AK-47 / Type 56  (row y = 0)   OAL 870
# =====================================================================
AK = [
 dict(name='muzzlenut', shape='cyl', from_muzzle=7,  R=8.5, L=14, mat=BLUED),
 dict(name='barrel',    shape='cyl', from_muzzle=91, R=7.5, L=182, mat=BLUED),          # 0-182 covers stub+exposed
 dict(name='fsb',       shape='box', from_muzzle=43, bore_off=12, L=38, H=48, W=24, mat=MATTE, bev=3),
 dict(name='fs_post',   shape='box', from_muzzle=43, bore_off=40, L=4,  H=18, W=3,  mat=MATTE, bev=0),
 # T56 tell: FULL circle around the post, not the Soviet AK's open ears
 dict(name='fs_hood',   shape='ring', from_muzzle=43, bore_off=48, R=13, R2=10, L=22, mat=MATTE, verts=12),
 dict(name='gasblock',  shape='tbox', from_muzzle=139, bore_off=13, L=38, H=46, W=22, H2=40, W2=22, drop=-6, mat=MATTE, bev=2, angle=-14),
 dict(name='gastube',   shape='cyl', from_muzzle=166, bore_off=27, R=9, L=17, mat=GAS),
 dict(name='hg_cap',    shape='box', from_muzzle=165, bore_off=1,  L=15, H=70, W=34, mat=BANDS, bev=2),
 dict(name='hg_upper',  shape='box', from_muzzle=250, bore_off=27, L=150, H=22, W=30, mat=W_SOV, bev=4),
 dict(name='hg_lower',  shape='box', from_muzzle=264, bore_off=-16, L=178, H=36, W=40, mat=W_SOV, bev=5),
 dict(name='rs_base',   shape='tbox', from_muzzle=398, bore_off=22, L=62, H=24, W=34, H2=34, W2=34, drop=-5, mat=MATTE, bev=2),
 # leaf top must land on the sight line (bore_off 48) or ADS is not level
 dict(name='rs_leaf',   shape='notch', from_muzzle=421, bore_off=41, L=22, H=14, W=26, gap=5, depth=6, mat=MATTE, bev=0),
 dict(name='receiver',  shape='box', from_muzzle=485, bore_off=-7, L=265, H=62, W=32, mat=BLUED, bev=2),
 dict(name='dustcover', shape='box', from_muzzle=491, bore_off=22, L=253, H=12, W=30, mat=WORN, bev=4),
 dict(name='chandle',   shape='box', from_muzzle=440, bore_off=8,  L=25, H=15, W=44, mat=BLUED, bev=2),
 # 30-rd banana mag: 3 chained segments approximating the 160R arc
 dict(name='mag1', shape='box', from_muzzle=437, bore_off=-72,  L=76, H=62, W=24, mat=BLUED, angle=-80, bev=2),
 dict(name='mag2', shape='box', from_muzzle=424, bore_off=-128, L=74, H=60, W=24, mat=BLUED, angle=-62, bev=2),
 dict(name='mag3', shape='box', from_muzzle=399, bore_off=-180, L=72, H=58, W=24, mat=BLUED, angle=-44, bev=2),
 dict(name='trigguard', shape='box', from_muzzle=534, bore_off=-62, L=78, H=6, W=12, mat=BLUED, bev=1),
 dict(name='tg_front',  shape='box', from_muzzle=499, bore_off=-50, L=7, H=24, W=10, mat=BLUED, bev=1),
 dict(name='grip',      shape='box', from_muzzle=600, bore_off=-83, L=42, H=95, W=32, mat=W_T56, angle=-30, bev=4),
 # stock: wrist + comb, straight top slight drop
 dict(name='stock',     shape='tbox', from_muzzle=744, bore_off=-21, L=252, H=50, W=38, H2=122, W2=42, drop=68, mat=W_SOV, bev=5),
 dict(name='buttplate', shape='box', from_muzzle=865, bore_off=-89, L=10, H=122, W=40, mat=BANDS, bev=1),
 dict(name='cleanrod',  shape='cyl', from_muzzle=65, bore_off=-15, R=2.3, L=110, mat=BRIGHT),
 # milled-receiver lightening cut, blueprint_soviet_rifles.md:47 (80x20 at X 380-460)
 dict(name='millcut',   shape='box', from_muzzle=420, bore_off=-2, lat=16, L=80, H=20, W=3, mat=MATTE, bev=1),
 dict(name='millcut_r', shape='box', from_muzzle=420, bore_off=-2, lat=-16, L=80, H=20, W=3, mat=MATTE, bev=1),
 # large right-side selector blade, blueprint_soviet_rifles.md:50 (90x12 at X 460-550)
 dict(name='selector',  shape='box', from_muzzle=505, bore_off=6, lat=18, L=90, H=12, W=5, mat=BLUED, bev=1),
 dict(name='sel_paddle',shape='box', from_muzzle=468, bore_off=16, lat=18, L=18, H=26, W=4, mat=BLUED, bev=1),
 # spike bayonet built FOLDED back under the barrel (carry state); rotate the
 # part 180deg about Y at the hinge to deploy it forward
 dict(name='bayonet',   shape='spike', from_muzzle=60, bore_off=-26, R=6, L=315, mat=BRIGHT, blades=4, bev=0, angle=180),
 dict(name='bay_hinge', shape='cyl', from_muzzle=62, bore_off=-24, R=6, L=16, mat=MATTE, verts=8),
]

# =====================================================================
# Mosin-Nagant 91/30  (row y = 0.5)   OAL 1232
# =====================================================================
MOSIN = [
 dict(name='fs_hood',   shape='ring', from_muzzle=16, bore_off=25, R=10, R2=7, L=22, mat=BLUED, verts=10),
 dict(name='fs_post',   shape='box', from_muzzle=16, bore_off=18, L=3, H=14, W=3, mat=BLUED, bev=0),
 dict(name='barrel',    shape='cone', from_muzzle=352, R=11, R2=7.2, L=705, mat=BLUED, verts=12),
 dict(name='nosecap',   shape='box', from_muzzle=77, bore_off=-17, L=15, H=34, W=42, mat=BANDS, bev=2),
 dict(name='cleanrod',  shape='cyl', from_muzzle=330, bore_off=-21, R=2.5, L=600, mat=BRIGHT),
 dict(name='band_f',    shape='box', from_muzzle=186, bore_off=-11, L=12, H=48, W=46, mat=BANDS, bev=2),
 dict(name='band_r',    shape='box', from_muzzle=501, bore_off=-11, L=12, H=52, W=48, mat=BANDS, bev=2),
 dict(name='handguard', shape='box', from_muzzle=377, bore_off=11, L=365, H=20, W=40, mat=W_BIRCH, bev=5),
 dict(name='rs_base',   shape='tbox', from_muzzle=610, bore_off=6, L=75, H=13, W=25, H2=18, W2=25, drop=-3, mat=BLUED, bev=2),
 dict(name='rs_leaf',   shape='notch', from_muzzle=638, bore_off=19, L=20, H=12, W=24, gap=4.5, depth=5, mat=BLUED, bev=0),
 # one-piece stock: fore-end + action + wrist + butt (4 segments)
 dict(name='forend',    shape='tbox', from_muzzle=387, bore_off=-22, L=635, H=36, W=44, H2=40, W2=48, drop=3, mat=W_BIRCH, bev=5),
 dict(name='midstock',  shape='tbox', from_muzzle=837, bore_off=-30, L=265, H=44, W=50, H2=52, W2=44, drop=4, mat=W_BIRCH, bev=5),
 dict(name='buttstock', shape='tbox', from_muzzle=1121, bore_off=-34, L=222, H=58, W=42, H2=124, W2=40, drop=64, mat=W_BIRCH, bev=5),
 dict(name='buttplate', shape='box', from_muzzle=1227, bore_off=-98, L=10, H=126, W=40, mat=BANDS, bev=1),
 dict(name='receiver',  shape='cyl', from_muzzle=817, R=15, L=225, mat=BLUED, verts=12),
 dict(name='bolt',      shape='cyl', from_muzzle=810, bore_off=2, R=9, L=120, mat=BRIGHT, verts=10),
 dict(name='cockpiece', shape='cyl', from_muzzle=942, R=11, L=25, mat=BLUED, verts=10),
 dict(name='mag',       shape='tbox', from_muzzle=785, bore_off=-72, L=90, H=40, W=24, H2=34, W2=24, drop=-6, mat=BLUED, bev=2),
 dict(name='trigguard', shape='box', from_muzzle=885, bore_off=-70, L=70, H=6, W=12, mat=BLUED, bev=1),
 dict(name='tg_front',  shape='box', from_muzzle=853, bore_off=-59, L=7, H=20, W=10, mat=BLUED, bev=1),
 dict(name='tg_rear',   shape='box', from_muzzle=916, bore_off=-59, L=7, H=20, W=10, mat=BLUED, bev=1),
 # STRAIGHT bolt handle sticking out horizontally - the 91/30 tell (a bent
 # handle would make this a PU sniper, blueprint_soviet_rifles.md:103)
 dict(name='bolthandle',shape='box', from_muzzle=872, bore_off=1, lat=36, L=13, H=13, W=58, mat=BRIGHT, bev=2),
 dict(name='boltknob',  shape='cyl', from_muzzle=872, bore_off=1, lat=68, R=11, L=16, mat=BRIGHT, verts=8, angle=90),
 # sling SLOTS through the stock, not swivels (blueprint_soviet_rifles.md:102)
 dict(name='slingslot_f',shape='box', from_muzzle=505, bore_off=-30, L=34, H=11, W=52, mat=MATTE, bev=0),
 dict(name='slingslot_r',shape='box', from_muzzle=1105, bore_off=-52, L=34, H=11, W=46, mat=MATTE, bev=0),
 # socket spike bayonet: a detachable accessory, so it is built hidden and the
 # rifle measures its true 1232mm. Unhide to mount it.
 dict(name='bayonet',   shape='spike', from_muzzle=-8, bore_off=0, R=7, L=430, mat=BRIGHT, blades=4, bev=0, hide=True),
 dict(name='bay_socket',shape='ring', from_muzzle=14, bore_off=0, R=15, R2=11, L=44, mat=BRIGHT, verts=10, hide=True),
]

# =====================================================================
# PPSh-41  (row y = 1.0)   OAL 843
# =====================================================================
PPSH = [
 # jacket runs PAST the muzzle and its front face is cut on a diagonal with the
 # TOP leading - that angled cut IS the compensator
 dict(name='shroud',    shape='tbox', from_muzzle=136, bore_off=3.5, L=272, H=40, W=34, H2=43, W2=36, drop=0, slant=26, mat=BLUED, bev=4),
 # barrel muzzle sits recessed inside the jacket
 dict(name='barrel',    shape='cyl', from_muzzle=160, bore_off=3.5, R=8, L=240, mat=BLUED, verts=8),
 dict(name='fs_base',   shape='box', from_muzzle=52, bore_off=27, L=18, H=12, W=18, mat=BLUED, bev=1),
 dict(name='fs_post',   shape='box', from_muzzle=52, bore_off=36, L=3, H=10, W=3, mat=BLUED, bev=0),
 dict(name='fs_hood',   shape='ring', from_muzzle=52, bore_off=40, R=11, R2=8, L=16, mat=BLUED, verts=10),
 # cooling vents, 3 per side (blueprint_soviet_rifles.md:131)
 dict(name='vent_l1',   shape='box', from_muzzle=120, bore_off=6, lat=-18, L=48, H=12, W=3, mat=MATTE, bev=0),
 dict(name='vent_l2',   shape='box', from_muzzle=180, bore_off=6, lat=-18, L=48, H=12, W=3, mat=MATTE, bev=0),
 dict(name='vent_l3',   shape='box', from_muzzle=240, bore_off=6, lat=-18, L=48, H=12, W=3, mat=MATTE, bev=0),
 dict(name='vent_r1',   shape='box', from_muzzle=120, bore_off=6, lat=18, L=48, H=12, W=3, mat=MATTE, bev=0),
 dict(name='vent_r2',   shape='box', from_muzzle=180, bore_off=6, lat=18, L=48, H=12, W=3, mat=MATTE, bev=0),
 dict(name='vent_r3',   shape='box', from_muzzle=240, bore_off=6, lat=18, L=48, H=12, W=3, mat=MATTE, bev=0),
 dict(name='receiver',  shape='box', from_muzzle=428, bore_off=-1.5, L=313, H=57, W=42, mat=BLUED, bev=4),
 dict(name='chandle',   shape='box', from_muzzle=345, bore_off=5, lat=22, L=35, H=14, W=16, mat=WORN, bev=2),
 dict(name='bolt',      shape='cyl', from_muzzle=330, bore_off=3.5, R=15, L=150, mat=BRIGHT, verts=8),
 dict(name='rs_base',   shape='box', from_muzzle=447, bore_off=27, L=28, H=12, W=24, mat=BLUED, bev=1),
 dict(name='rs_notch',  shape='notch', from_muzzle=447, bore_off=34, L=18, H=12, W=24, gap=4.5, depth=5, mat=BLUED, bev=0),
 # 71-rd drum: squat cylinder, axis across the gun (built inline below)
 dict(name='feedtower', shape='box', from_muzzle=360, bore_off=-45, L=70, H=30, W=26, mat=BLUED, bev=2),
 dict(name='trigguard', shape='box', from_muzzle=517, bore_off=-80, L=75, H=6, W=12, mat=BLUED, bev=1),
 dict(name='tg_front',  shape='box', from_muzzle=483, bore_off=-66, L=7, H=26, W=10, mat=BLUED, bev=1),
 dict(name='tg_rear',   shape='box', from_muzzle=551, bore_off=-66, L=7, H=26, W=10, mat=BLUED, bev=1),
 # stock: nose chin under receiver -> wrist -> dropped butt
 dict(name='stocknose', shape='tbox', from_muzzle=435, bore_off=-45, L=300, H=30, W=40, H2=36, W2=42, drop=4, mat=W_BIRCH, bev=4),
 dict(name='wrist',     shape='tbox', from_muzzle=622, bore_off=-33, L=75, H=52, W=40, H2=58, W2=40, drop=6, mat=W_BIRCH, bev=5),
 dict(name='buttstock', shape='tbox', from_muzzle=751, bore_off=-48, L=183, H=64, W=42, H2=120, W2=40, drop=52, mat=W_BIRCH, bev=5),
 dict(name='buttplate', shape='box', from_muzzle=838, bore_off=-112, L=10, H=120, W=42, mat=BANDS, bev=1),
]

# =====================================================================
# RPD  (row y = 1.5)   OAL 1037
# =====================================================================
RPD = [
 dict(name='barrel',    shape='cone', from_muzzle=165, R=10, R2=7.5, L=330, mat=BLUED, verts=10),
 dict(name='fsb',       shape='box', from_muzzle=37, bore_off=14, L=35, H=34, W=22, mat=MATTE, bev=2),
 dict(name='fs_post',   shape='box', from_muzzle=37, bore_off=40, L=4, H=16, W=3, mat=MATTE, bev=0),
 dict(name='fs_hood',   shape='ring', from_muzzle=37, bore_off=48, R=12, R2=9, L=20, mat=MATTE, verts=10),
 # cooling fins along the exposed barrel - a silhouette priority for the RPD
 dict(name='fin1',      shape='ring', from_muzzle=196, R=15, R2=10, L=7, mat=HEAT, verts=10),
 dict(name='fin2',      shape='ring', from_muzzle=222, R=15, R2=10, L=7, mat=HEAT, verts=10),
 dict(name='fin3',      shape='ring', from_muzzle=248, R=15, R2=10, L=7, mat=HEAT, verts=10),
 dict(name='fin4',      shape='ring', from_muzzle=274, R=15, R2=10, L=7, mat=HEAT, verts=10),
 dict(name='fin5',      shape='ring', from_muzzle=300, R=15, R2=10, L=7, mat=HEAT, verts=10),
 dict(name='bipodhinge',shape='cyl', from_muzzle=47, bore_off=-8, R=13, L=25, mat=MATTE, verts=8),
 # legs rake back and out from the hinge; feet reach the ground plane at -183
 dict(name='bipodleg_l',shape='box', from_muzzle=110, bore_off=-96, lat=-42, L=10, H=214, W=10, mat=MATTE, angle=35, bev=1),
 dict(name='bipodleg_r',shape='box', from_muzzle=110, bore_off=-96, lat=42, L=10, H=214, W=10, mat=MATTE, angle=35, bev=1),
 dict(name='bipodfoot_l',shape='box', from_muzzle=170, bore_off=-181, lat=-42, L=38, H=7, W=11, mat=MATTE, bev=1),
 dict(name='bipodfoot_r',shape='box', from_muzzle=170, bore_off=-181, lat=42, L=38, H=7, W=11, mat=MATTE, bev=1),
 dict(name='gasblock',  shape='box', from_muzzle=147, bore_off=-12, L=35, H=25, W=22, mat=MATTE, bev=2),
 dict(name='gastube',   shape='cyl', from_muzzle=250, bore_off=-26, R=6.5, L=170, mat=HEAT),
 dict(name='hg_band',   shape='box', from_muzzle=337, bore_off=-19, L=14, H=80, W=50, mat=BANDS, bev=2),
 dict(name='handguard', shape='box', from_muzzle=405, bore_off=-19, L=150, H=78, W=55, mat=W_RPD, bev=6),
 dict(name='receiver',  shape='box', from_muzzle=635, bore_off=-12.5, L=310, H=85, W=38, mat=BLUED, bev=2),
 dict(name='feedhump',  shape='tbox', from_muzzle=565, bore_off=30, L=150, H=16, W=36, H2=10, W2=32, drop=4, mat=BLUED, bev=4),
 dict(name='rs_base',   shape='tbox', from_muzzle=775, bore_off=26, L=60, H=12, W=25, H2=18, W2=25, drop=-3, mat=MATTE, bev=2),
 dict(name='rs_leaf',   shape='notch', from_muzzle=778, bore_off=41, L=20, H=14, W=26, gap=5, depth=6, mat=MATTE, bev=0),
 dict(name='chandle',   shape='box', from_muzzle=725, bore_off=-10, L=70, H=12, W=50, mat=WORN, bev=2),
 dict(name='drumbracket',shape='box', from_muzzle=575, bore_off=-65, L=90, H=20, W=30, mat=BLUED, bev=2),
 dict(name='trigguard', shape='box', from_muzzle=787, bore_off=-88, L=65, H=6, W=12, mat=BLUED, bev=1),
 dict(name='tg_front',  shape='box', from_muzzle=758, bore_off=-72, L=7, H=28, W=10, mat=BLUED, bev=1),
 dict(name='grip',      shape='box', from_muzzle=830, bore_off=-105, L=45, H=100, W=32, mat=W_RPD, angle=-20, bev=4),
 dict(name='stock',     shape='tbox', from_muzzle=922, bore_off=-15, L=230, H=52, W=42, H2=110, W2=42, drop=45, mat=W_RPD, bev=6),
 dict(name='buttplate', shape='box', from_muzzle=1032, bore_off=-60, L=10, H=110, W=42, mat=BANDS, bev=1),
 dict(name='cleanrod',  shape='cyl', from_muzzle=300, bore_off=-40, R=2.4, L=210, mat=BRIGHT),
 # 7.62x39 belt: shorter, stubbier rounds than the M60's 7.62x51, tighter links.
 # Runs up out of the TOP of the drum and into the left-side feed port.
 dict(name='belt',      shape='belt', from_muzzle=548, bore_off=-96, lat=-14,
      R=6.2, L=29, pitch=13, links=7, rise=74, link_w=2.6, mat=BRIGHT),
]

# =====================================================================
# RPG-2 + PG-2  (row y = 2.0)   tube 950, rocket nose at -250
# =====================================================================
RPG2 = [
 dict(name='tube',      shape='ring', from_muzzle=475, R=22, R2=20, L=950, mat=BLUED, verts=12),
 dict(name='ring_f',    shape='cyl', from_muzzle=10, R=24, L=20, mat=BLUED, verts=12),
 dict(name='ring_r',    shape='cyl', from_muzzle=937, R=24, L=25, mat=BLUED, verts=12),
 dict(name='fs_base',   shape='box', from_muzzle=70, bore_off=24, L=20, H=8, W=12, mat=MATTE, bev=1),
 dict(name='fs_post',   shape='box', from_muzzle=70, bore_off=48, L=4, H=44, W=3, mat=MATTE, bev=0),
 dict(name='rs_base',   shape='box', from_muzzle=407, bore_off=24, L=25, H=8, W=14, mat=MATTE, bev=1),
 dict(name='rs_leaf',   shape='notch', from_muzzle=407, bore_off=52, L=6, H=36, W=30, gap=5, depth=7, mat=MATTE, bev=1),
 # stepped range ladder (~150m); the tick numerals bake to texture
 dict(name='rs_step1',  shape='box', from_muzzle=407, bore_off=42, L=6, H=3, W=26, mat=MATTE, bev=0),
 dict(name='rs_step2',  shape='box', from_muzzle=407, bore_off=34, L=6, H=3, W=22, mat=MATTE, bev=0),
 dict(name='rs_hinge',  shape='cyl', from_muzzle=407, bore_off=26, R=5, L=22, mat=MATTE, verts=8),
 dict(name='fs_hinge',  shape='cyl', from_muzzle=70, bore_off=26, R=4, L=16, mat=MATTE, verts=8),
 dict(name='wood',      shape='ring', from_muzzle=630, R=31, R2=23, L=360, mat=W_RPG, verts=12),
 dict(name='band_f',    shape='cyl', from_muzzle=452, R=33, L=12, mat=BANDS, verts=12),
 dict(name='band_r',    shape='cyl', from_muzzle=796, R=33, L=12, mat=BANDS, verts=12),
 dict(name='trighouse', shape='box', from_muzzle=530, bore_off=-38, L=100, H=33, W=22, mat=BLUED, bev=2),
 dict(name='grip',      shape='box', from_muzzle=545, bore_off=-88, L=36, H=105, W=30, mat=BAKE, angle=-15, bev=4),
 dict(name='trigger',   shape='box', from_muzzle=505, bore_off=-49, L=8, H=27, W=6, mat=BLUED, bev=0),
 dict(name='hammer',    shape='box', from_muzzle=595, bore_off=-33, L=30, H=25, W=12, mat=BLUED, angle=20, bev=2),
 # PG-2 rocket
 dict(name='pg2_fin_t', shape='box', from_muzzle=30, bore_off=15, L=70, H=2, W=26, mat=BLUED, bev=0),
 dict(name='pg2_fin_b', shape='box', from_muzzle=30, bore_off=-15, L=70, H=2, W=26, mat=BLUED, bev=0),
 dict(name='pg2_fin_l', shape='box', from_muzzle=30, lat=-15, L=70, H=26, W=2, mat=BLUED, bev=0),
 dict(name='pg2_fin_r', shape='box', from_muzzle=30, lat=15, L=70, H=26, W=2, mat=BLUED, bev=0),
 dict(name='pg2_boom',  shape='cyl', from_muzzle=80, R=19, L=120, mat=BLUED, verts=8),
 dict(name='pg2_tip',   shape='cone', from_muzzle=-242, R=10, R2=6, L=15, mat=BLUED, verts=8),
 dict(name='pg2_ogive', shape='cone', from_muzzle=-162, R=41, R2=10, L=145, mat=OLIVE, verts=12),
 dict(name='pg2_band',  shape='cyl', from_muzzle=-60, R=41, L=60, mat=OLIVE, verts=12),
 dict(name='pg2_boat',  shape='cone', from_muzzle=-5, R=20, R2=41, L=50, mat=OLIVE, verts=12),
]

# sight_front/sight_rear MUST share bore_off or the ADS line is not level.
# Sightline-above-bore and sight radius per blueprint_soviet_rifles.md:166-177.
MARKS = {
 'AK47':   dict(sight_front=(43, 48),  sight_rear=(421, 48),
                grip_L=(264, -34), grip_R=(600, -62), muzzle=(0, 0)),
 'Mosin':  dict(sight_front=(16, 25),  sight_rear=(638, 25),
                grip_L=(400, -38), grip_R=(900, -42), muzzle=(0, 0)),
 'PPSh41': dict(sight_front=(52, 40),  sight_rear=(447, 40),
                grip_L=(360, -44), grip_R=(622, -36), muzzle=(0, 0)),
 'RPD':    dict(sight_front=(37, 48),  sight_rear=(778, 48),
                grip_L=(405, -42), grip_R=(830, -74), muzzle=(0, 0)),
 'RPG2':   dict(sight_front=(70, 70),  sight_rear=(407, 70),
                grip_L=(500, -44), grip_R=(545, -74), muzzle=(0, 0)),
}
ROWS = [('AK47', AK, 0.0), ('Mosin', MOSIN, 0.5), ('PPSh41', PPSH, 1.0),
        ('RPD', RPD, 1.5), ('RPG2', RPG2, 2.0)]
for name, parts, y in ROWS:
    build_weapon(name, parts, (0.0, y, Z))
    build_markers(name, MARKS[name], (0.0, y, Z))

# PPSh drum + RPD drum: squat cylinders with axis across the gun (Y axis)
def drum(name, x_mm, y_row, z_center_mm, R_mm, TH_mm, material):
    bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=R_mm*MM, depth=TH_mm*MM,
        location=(x_mm*MM, y_row, Z + z_center_mm*MM), rotation=(0, math.radians(90), 0))
    ob = bpy.context.active_object
    ob.name = name
    bpy.ops.object.transform_apply(rotation=True)
    ob.data.materials.append(material)
    b = ob.modifiers.new('Bevel', 'BEVEL'); b.width = 3*MM; b.segments = 2
    b.limit_method = 'ANGLE'; b.angle_limit = 0.7
    return ob

drum('PPSh41_drum', 358, 1.0, -108, 76, 34, BLUED)
drum('RPD_drum',    575, 1.5, -140, 85, 75, DRUMOL)

# ---------- camera + sun (same armory setup as weapons_us) ----------
cam = bpy.data.objects.get('ArmoryCam')
if cam is None:
    cam_data = bpy.data.cameras.new('ArmoryCam')
    cam = bpy.data.objects.new('ArmoryCam', cam_data)
    bpy.context.scene.collection.objects.link(cam)
cam.data.type = 'ORTHO'
cam.data.ortho_scale = 1.45
cam.data.clip_start = 1.85
cam.data.clip_end = 2.2
cam.rotation_euler = (math.radians(90), 0, 0)
sun = bpy.data.objects.get('ArmorySun')
if sun is None:
    sun_data = bpy.data.lights.new('ArmorySun', 'SUN')
    sun = bpy.data.objects.new('ArmorySun', sun_data)
    bpy.context.scene.collection.objects.link(sun)
sun.data.energy = 4.0
sun.rotation_euler = (math.radians(65), 0, 0)
w = bpy.context.scene.world
if w is None:
    w = bpy.data.worlds.new('World'); bpy.context.scene.world = w
w.use_nodes = True
bg = w.node_tree.nodes['Background']
bg.inputs['Color'].default_value = (0.32, 0.32, 0.32, 1)
bg.inputs['Strength'].default_value = 0.9

sc = bpy.context.scene
# 'BLENDER_EEVEE' is the 3.x id and raises on 4.2+; this project runs Blender 5.0
_engines = sc.bl_rna.properties['render'].fixed_type.properties['engine'].enum_items.keys() \
    if hasattr(sc.render, 'engine') else []
for _e in ('BLENDER_EEVEE_NEXT', 'BLENDER_EEVEE'):
    try:
        sc.render.engine = _e
        break
    except TypeError:
        continue
# Standard clips per channel and red clips first, turning warm wood pure red
sc.view_settings.view_transform = 'AgX'
sc.camera = cam

if not LIVE:
    bpy.ops.wm.save_as_mainfile(filepath=WEAPONS_VC_OUT)
print('WEAPONS_VC BUILT' + ('' if LIVE else ' + SAVED'), flush=True)
print('ALL VC RENDERS DONE', flush=True)
