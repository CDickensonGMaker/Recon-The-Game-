"""US firebase interior props, 1969.

These exist because the furnishing system already works and has nothing American to place:
SiteLayouts.INTERIOR_PROPS (site_layouts.gd:94-103) maps every prop_class to a Vietnamese
village market asset, so a prop_radio marker in a TOC resolves to nothing.

Kit rules inherited from gen_firebase.py: the nine+two material slots in their fixed order,
box-projected UVs at 1.6 m, point filtering, flat shading, origin at base centre on Z=0,
`fb_` lowercase names. Diffuse only - no PBR, no bevels, no support loops.

Budgets (Caleb's spec): micro kit part 20-100 tris, small prop 60-200, medium 150-400.
"""
import bpy, bmesh, math, os, sys, random
from mathutils import Vector, Euler, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_firebase as gf

OUT_DIR = r"C:\Users\caleb\RECONgame\assets\us\props\interior"


def box(bm, centre, size, mat="fb_timber", rot=None, taper=1.0):
    gf.box(bm, centre, size, mat, rot, taper)


def cyl(bm, centre, r, h, mat="fb_gunmetal", seg=8, axis='Z', rot=None):
    cx, cy, cz = centre
    idx = gf.MAT_INDEX[mat]
    ring0, ring1 = [], []
    for i in range(seg):
        a = math.tau * i / seg
        u, v = math.cos(a) * r, math.sin(a) * r
        if axis == 'Z':
            p0, p1 = (u, v, -h / 2.0), (u, v, h / 2.0)
        elif axis == 'X':
            p0, p1 = (-h / 2.0, u, v), (h / 2.0, u, v)
        else:
            p0, p1 = (u, -h / 2.0, v), (u, h / 2.0, v)
        if rot is not None:
            R = Euler(rot).to_matrix()
            p0 = R @ Vector(p0)
            p1 = R @ Vector(p1)
        ring0.append(bm.verts.new((p0[0] + cx, p0[1] + cy, p0[2] + cz)))
        ring1.append(bm.verts.new((p1[0] + cx, p1[1] + cy, p1[2] + cz)))
    for i in range(seg):
        j = (i + 1) % seg
        try:
            bm.faces.new((ring0[i], ring0[j], ring1[j], ring1[i])).material_index = idx
        except ValueError:
            pass
    for ring, flip in ((ring0, True), (ring1, False)):
        try:
            f = bm.faces.new(list(reversed(ring)) if flip else ring)
            f.material_index = idx
        except ValueError:
            pass


# --------------------------------------------------------------- command / TOC --

def fb_field_desk(bm, rng):
    """Plywood field desk. Nothing at a firebase was furniture; it was cut on site."""
    box(bm, (0, 0, 0.74), (1.30, 0.62, 0.045), "fb_timber")
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(bm, (sx * 0.58, sy * 0.25, 0.36), (0.06, 0.06, 0.72), "fb_timber")
    box(bm, (0, 0.28, 0.44), (1.24, 0.035, 0.34), "fb_timber")          # modesty panel
    box(bm, (-0.30, -0.02, 0.63), (0.52, 0.52, 0.16), "fb_crate")       # drawer box
    box(bm, (-0.30, -0.28, 0.63), (0.48, 0.03, 0.12), "fb_timber")
    return 1.30, 0.62, 0.78


def fb_field_chair(bm, rng):
    box(bm, (0, 0, 0.44), (0.44, 0.42, 0.035), "fb_canvas")
    box(bm, (0, 0.20, 0.66), (0.44, 0.035, 0.40), "fb_canvas")
    for sx in (-1, 1):
        box(bm, (sx * 0.20, -0.02, 0.22), (0.035, 0.52, 0.035), "fb_gunmetal",
            rot=(math.radians(14), 0, 0))
        box(bm, (sx * 0.20, 0.02, 0.22), (0.035, 0.52, 0.035), "fb_gunmetal",
            rot=(math.radians(-14), 0, 0))
        box(bm, (sx * 0.20, 0.20, 0.66), (0.035, 0.035, 0.42), "fb_gunmetal")
    return 0.44, 0.46, 0.86


def fb_radio_prc25(bm, rng):
    """PRC-25 manpack sitting on its base, whip stub folded. The handset hangs off it."""
    box(bm, (0, 0, 0.19), (0.28, 0.13, 0.38), "fb_olive")
    box(bm, (0, -0.075, 0.30), (0.24, 0.02, 0.16), "fb_gunmetal")       # control face
    box(bm, (0, 0, 0.05), (0.30, 0.16, 0.10), "fb_olive")               # battery box
    cyl(bm, (0.10, 0.03, 0.52), 0.010, 0.28, "fb_gunmetal", seg=6)      # antenna base
    box(bm, (-0.10, -0.10, 0.30), (0.07, 0.05, 0.16), "fb_gunmetal")    # handset
    return 0.30, 0.16, 0.66


def fb_radio_shelf(bm, rng):
    """A bank of sets on a plank shelf - what an FDC actually looked like."""
    box(bm, (0, 0, 0.80), (1.50, 0.44, 0.05), "fb_timber")
    box(bm, (0, 0, 0.40), (1.50, 0.40, 0.04), "fb_timber")
    for sx in (-1, 1):
        box(bm, (sx * 0.72, 0, 0.41), (0.06, 0.42, 0.82), "fb_timber")
    for i, x in enumerate((-0.46, 0.0, 0.46)):
        box(bm, (x, 0, 0.96), (0.34, 0.30, 0.28), "fb_olive")
        box(bm, (x, -0.16, 0.96), (0.28, 0.02, 0.20), "fb_gunmetal")
    box(bm, (0.30, 0, 0.52), (0.40, 0.28, 0.20), "fb_crate")
    return 1.50, 0.44, 1.10


def fb_field_phone(bm, rng):
    """TA-312 in its canvas case."""
    box(bm, (0, 0, 0.09), (0.23, 0.16, 0.18), "fb_canvas")
    box(bm, (0, -0.09, 0.11), (0.19, 0.02, 0.12), "fb_gunmetal")
    box(bm, (0, 0.02, 0.21), (0.19, 0.06, 0.05), "fb_gunmetal")         # handset on top
    return 0.23, 0.16, 0.24


def fb_plotting_board(bm, rng):
    """Firing chart on a tilted stand - the FDC's whole job."""
    box(bm, (0, 0, 0.55), (0.90, 0.70, 0.03), "fb_timber",
        rot=(math.radians(-22), 0, 0))
    for sx in (-1, 1):
        box(bm, (sx * 0.40, 0.22, 0.28), (0.05, 0.05, 0.56), "fb_timber")
        box(bm, (sx * 0.40, -0.20, 0.24), (0.05, 0.05, 0.48), "fb_timber",
            rot=(math.radians(12), 0, 0))
    box(bm, (0, -0.06, 0.63), (0.76, 0.52, 0.006), "fb_canvas",
        rot=(math.radians(-22), 0, 0))
    return 0.90, 0.74, 0.72


def fb_map_board(bm, rng):
    """Plywood sheet with acetate, leaned against a wall."""
    box(bm, (0, 0, 0.62), (1.10, 0.04, 1.24), "fb_timber", rot=(math.radians(8), 0, 0))
    box(bm, (0, -0.035, 0.66), (0.94, 0.006, 1.00), "fb_canvas",
        rot=(math.radians(8), 0, 0))
    return 1.10, 0.22, 1.26


# ------------------------------------------------------------------- living --

def fb_cot(bm, rng):
    """Canvas folding cot. The X-frame is the silhouette; the canvas sags."""
    box(bm, (0, 0, 0.42), (1.88, 0.64, 0.035), "fb_canvas")
    for sy in (-1, 1):
        box(bm, (0, sy * 0.31, 0.44), (1.90, 0.045, 0.045), "fb_gunmetal")
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(bm, (sx * 0.78, sy * 0.20, 0.21), (0.04, 0.04, 0.44), "fb_gunmetal",
                rot=(math.radians(sy * 16), 0, 0))
    box(bm, (0.62, 0, 0.47), (0.46, 0.56, 0.07), "fb_olive")            # rolled liner
    return 1.90, 0.64, 0.50


def fb_footlocker(bm, rng):
    box(bm, (0, 0, 0.17), (0.80, 0.40, 0.34), "fb_timber")
    box(bm, (0, 0, 0.355), (0.82, 0.42, 0.04), "fb_timber")             # lid
    for sx in (-1, 1):
        box(bm, (sx * 0.28, -0.205, 0.30), (0.09, 0.02, 0.06), "fb_gunmetal")
        box(bm, (sx * 0.41, 0, 0.20), (0.02, 0.16, 0.08), "fb_gunmetal")
    return 0.82, 0.42, 0.38


def fb_ammo_crate_stack(bm, rng):
    """Ammo crates as furniture - the standard firebase chair, table and shelf."""
    h = 0.0
    for i in range(4):
        w, d, t = 0.92, 0.36, 0.26
        box(bm, (rng.uniform(-0.05, 0.05), rng.uniform(-0.04, 0.04), h + t / 2.0),
            (w, d, t), "fb_crate", rot=(0, 0, rng.uniform(-0.06, 0.06)))
        h += t
    return 0.98, 0.42, h


def fb_c_ration_case(bm, rng):
    box(bm, (0, 0, 0.13), (0.44, 0.30, 0.26), "fb_crate")
    return 0.44, 0.30, 0.26


def fb_hanging_bulb(bm, rng):
    cyl(bm, (0, 0, 0.86), 0.004, 1.72, "fb_gunmetal", seg=4)            # drop wire
    cyl(bm, (0, 0, 0.06), 0.030, 0.09, "fb_gunmetal", seg=6)            # socket
    cyl(bm, (0, 0, 0.005), 0.038, 0.07, "fb_canvas", seg=6)             # bulb
    return 0.08, 0.08, 1.72


# --------------------------------------------------------------------- mess --

def fb_field_range(bm, rng):
    """M59 field range - the chow hall's whole reason to exist."""
    box(bm, (0, 0, 0.46), (0.86, 0.60, 0.30), "fb_gunmetal")
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(bm, (sx * 0.36, sy * 0.24, 0.155), (0.05, 0.05, 0.31), "fb_gunmetal")
    for sx in (-1, 1):
        cyl(bm, (sx * 0.20, 0, 0.625), 0.15, 0.05, "fb_gunmetal", seg=10)
    cyl(bm, (0, 0.24, 0.86), 0.05, 0.52, "fb_corrugated", seg=6)        # flue
    box(bm, (0, -0.31, 0.46), (0.70, 0.02, 0.18), "fb_gunmetal")
    return 0.86, 0.62, 1.12


def fb_mermite(bm, rng):
    """Insulated food container. Chow arrives in these and nothing else."""
    cyl(bm, (0, 0, 0.22), 0.20, 0.44, "fb_olive", seg=10)
    cyl(bm, (0, 0, 0.455), 0.21, 0.05, "fb_olive", seg=10)              # lid
    for sx in (-1, 1):
        box(bm, (sx * 0.21, 0, 0.30), (0.03, 0.12, 0.09), "fb_gunmetal")
    return 0.44, 0.42, 0.48


def fb_folding_table(bm, rng):
    box(bm, (0, 0, 0.73), (1.80, 0.76, 0.04), "fb_timber")
    for sx in (-1, 1):
        box(bm, (sx * 0.76, 0, 0.36), (0.05, 0.66, 0.05), "fb_gunmetal",
            rot=(math.radians(90), 0, 0))
        for sy in (-1, 1):
            box(bm, (sx * 0.76, sy * 0.32, 0.36), (0.05, 0.05, 0.72), "fb_gunmetal")
    return 1.80, 0.76, 0.75


def fb_bench(bm, rng):
    box(bm, (0, 0, 0.44), (1.80, 0.30, 0.04), "fb_timber")
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(bm, (sx * 0.74, sy * 0.11, 0.22), (0.05, 0.05, 0.44), "fb_timber")
        box(bm, (sx * 0.74, 0, 0.20), (0.04, 0.28, 0.04), "fb_timber")
    return 1.80, 0.30, 0.46


def fb_wash_drum(bm, rng):
    """Cut 55-gallon drum on a timber frame - the immersion-heater wash line."""
    cyl(bm, (0, 0, 0.74), 0.29, 0.44, "fb_corrugated", seg=12)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(bm, (sx * 0.24, sy * 0.24, 0.26), (0.07, 0.07, 0.52), "fb_timber")
    box(bm, (0, 0, 0.50), (0.62, 0.62, 0.05), "fb_timber")
    return 0.62, 0.62, 0.96


# ----------------------------------------------------------------------- aid --

def fb_litter(bm, rng):
    """Canvas litter on two stands - the aid station's operating table."""
    box(bm, (0, 0, 0.72), (2.00, 0.56, 0.03), "fb_canvas")
    for sy in (-1, 1):
        box(bm, (0, sy * 0.30, 0.73), (2.20, 0.05, 0.05), "fb_timber")
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(bm, (sx * 0.70, sy * 0.26, 0.36), (0.05, 0.05, 0.72), "fb_timber",
                rot=(math.radians(sy * 10), 0, 0))
        box(bm, (sx * 0.70, 0, 0.40), (0.04, 0.50, 0.04), "fb_timber")
    return 2.20, 0.60, 0.76


def fb_medical_chest(bm, rng):
    box(bm, (0, 0, 0.19), (0.62, 0.34, 0.38), "fb_olive")
    box(bm, (0, 0, 0.395), (0.64, 0.36, 0.04), "fb_olive")
    box(bm, (0, -0.175, 0.22), (0.20, 0.02, 0.20), "fb_canvas")         # painted cross panel
    box(bm, (0, 0.18, 0.30), (0.14, 0.02, 0.05), "fb_gunmetal")
    return 0.64, 0.36, 0.42


# ------------------------------------------------------------------ storage --

def fb_jerry_can(bm, rng):
    box(bm, (0, 0, 0.235), (0.34, 0.16, 0.47), "fb_olive")
    for sx in (-1, 0, 1):
        box(bm, (sx * 0.10, 0, 0.49), (0.05, 0.10, 0.04), "fb_olive")   # triple handle
    box(bm, (0.13, 0, 0.45), (0.07, 0.07, 0.06), "fb_gunmetal")         # spout cap
    return 0.34, 0.16, 0.51


def fb_water_can(bm, rng):
    cyl(bm, (0, 0, 0.24), 0.14, 0.48, "fb_olive", seg=10)
    cyl(bm, (0, 0, 0.50), 0.05, 0.05, "fb_gunmetal", seg=6)
    box(bm, (0, 0, 0.50), (0.22, 0.03, 0.03), "fb_gunmetal")
    return 0.28, 0.28, 0.52


PROPS = {
    "fb_field_desk": fb_field_desk, "fb_field_chair": fb_field_chair,
    "fb_radio_prc25": fb_radio_prc25, "fb_radio_shelf": fb_radio_shelf,
    "fb_field_phone": fb_field_phone, "fb_plotting_board": fb_plotting_board,
    "fb_map_board": fb_map_board,
    "fb_cot": fb_cot, "fb_footlocker": fb_footlocker,
    "fb_ammo_crate_stack": fb_ammo_crate_stack, "fb_c_ration_case": fb_c_ration_case,
    "fb_hanging_bulb": fb_hanging_bulb,
    "fb_field_range": fb_field_range, "fb_mermite": fb_mermite,
    "fb_folding_table": fb_folding_table, "fb_bench": fb_bench,
    "fb_wash_drum": fb_wash_drum,
    "fb_litter": fb_litter, "fb_medical_chest": fb_medical_chest,
    "fb_jerry_can": fb_jerry_can, "fb_water_can": fb_water_can,
}

## Which prop_class each one answers. site_planner._furnish_interior reads prop_class off the
## marker and picks from the pool; these are the US pool that did not exist.
PROP_CLASSES = {
    # fb_ammo_crate_stack is NOT a seat and NOT a table: it is 1.04 m of stacked crates, and
    # putting it in those pools is how a mess hall furnished itself with legless blocks.
    "furniture":  ["fb_field_desk", "fb_folding_table"],
    "seat":       ["fb_field_chair", "fb_bench"],
    "sleep":      ["fb_cot"],
    "radio":      ["fb_radio_prc25", "fb_radio_shelf", "fb_field_phone"],
    "plot":       ["fb_plotting_board", "fb_map_board"],
    "storage":    ["fb_footlocker", "fb_c_ration_case", "fb_jerry_can", "fb_water_can"],
    "storage_low": ["fb_c_ration_case", "fb_ammo_crate_stack"],
    "cook":       ["fb_field_range", "fb_mermite"],
    "wash":       ["fb_wash_drum"],
    "medic":      ["fb_litter", "fb_medical_chest"],
    "light":      ["fb_hanging_bulb"],
}

BUDGET = [("micro", 20, 100), ("small", 60, 200), ("medium", 150, 400)]


## Props that hang from the overhead rather than stand on the deck: their origin is the
## attach point, so they are exempt from the seat-to-floor pass.
HANGING = {"fb_hanging_bulb"}


def build(name, seed=0):
    rng = random.Random(seed)
    bm = bmesh.new()
    dims = PROPS[name](bm, rng)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.0004)
    if name not in HANGING:
        # Rotated leg frames dip below the deck; the contract is origin at base centre ON Z=0.
        low = min((v.co.z for v in bm.verts), default=0.0)
        if abs(low) > 1e-4:
            bmesh.ops.translate(bm, verts=bm.verts[:], vec=Vector((0.0, 0.0, -low)))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in gf.ensure_materials():
        me.materials.append(m)
    gf.box_project_uvs(me)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob, dims


## AUTHORED layouts, in building-local metres: (prop, x, y, yaw_deg, z_offset).
## Randomly scattering class picks into a circle at the room's centre is what produced a mess
## hall of crate stacks with no table and a hootch with one cot in the middle. A room is a
## layout, not a bag of props.
INTERIOR_LAYOUT = {
    # 4.4 x 7.2. Cots down both revetted walls, footlocker at the foot of each row.
    "fb_hootch": [
        ("fb_cot", -1.35, -2.30, 90, 0), ("fb_cot", -1.35, -0.30, 90, 0),
        ("fb_cot", -1.35, 1.70, 90, 0),
        ("fb_cot", 1.35, -2.30, 90, 0), ("fb_cot", 1.35, -0.30, 90, 0),
        ("fb_cot", 1.35, 1.70, 90, 0),
        ("fb_footlocker", -1.35, 2.95, 90, 0), ("fb_footlocker", 1.35, 2.95, 90, 0),
        ("fb_c_ration_case", 0.00, 3.10, 0, 0),
        ("fb_hanging_bulb", 0.00, -1.60, 0, 0), ("fb_hanging_bulb", 0.00, 1.80, 0, 0),
    ],
    # 5.0 x 8.0. Tables and benches are built into fam_mess; this is the serving line.
    "fb_mess": [
        ("fb_field_range", -1.05, 3.35, 0, 0), ("fb_field_range", 1.05, 3.35, 0, 0),
        ("fb_mermite", -0.90, 2.80, 0, 0.93), ("fb_mermite", 0.90, 2.80, 0, 0.93),
        ("fb_water_can", 2.00, 2.10, 0, 0),
        ("fb_c_ration_case", -2.00, 2.10, 0, 0),
        ("fb_hanging_bulb", 0.00, -1.60, 0, 0), ("fb_hanging_bulb", 0.00, 1.10, 0, 0),
    ],
    # 8.1 x 6.7 outer, dug in. Desk and radios against opposite walls, boards facing in.
    "fb_toc": [
        ("fb_field_desk", -1.80, -1.40, 0, 0),
        ("fb_field_chair", -1.80, -0.55, 180, 0),
        ("fb_field_phone", -1.45, -1.40, 0, 0.78),
        ("fb_radio_shelf", 1.95, 0.00, 90, 0),
        ("fb_field_chair", 1.15, 0.00, 270, 0),
        ("fb_plotting_board", 0.00, 1.45, 0, 0),
        ("fb_map_board", -2.55, 0.80, 90, 0),
        ("fb_hanging_bulb", 0.00, -1.50, 0, 0), ("fb_hanging_bulb", 0.00, 1.00, 0, 0),
    ],
    # 6.3 x 5.2, dug in. Two litters down the middle, chests against the back wall.
    "fb_aid_station": [
        ("fb_litter", 0.00, -1.00, 0, 0), ("fb_litter", 0.00, 0.80, 0, 0),
        ("fb_medical_chest", -2.10, 1.75, 0, 0), ("fb_medical_chest", 2.10, 1.75, 0, 0),
        ("fb_water_can", 2.25, -1.70, 0, 0),
        ("fb_hanging_bulb", 0.00, 0.00, 0, 0),
    ],
    # 7.3 x 10.1 supply tent: crate rows down the walls, a check-in table at the door.
    "fb_gp_tent": [
        ("fb_ammo_crate_stack", -2.40, -3.20, 0, 0),
        ("fb_ammo_crate_stack", -2.40, -1.60, 0, 0),
        ("fb_ammo_crate_stack", -2.40, 0.00, 0, 0),
        ("fb_ammo_crate_stack", 2.40, -3.20, 0, 0),
        ("fb_ammo_crate_stack", 2.40, -1.60, 0, 0),
        ("fb_c_ration_case", -1.20, 3.40, 0, 0), ("fb_c_ration_case", 0.00, 3.40, 0, 0),
        ("fb_c_ration_case", 1.20, 3.40, 0, 0),
        ("fb_jerry_can", 2.60, 2.40, 0, 0), ("fb_water_can", 2.60, 1.60, 0, 0),
        ("fb_folding_table", 0.00, 1.00, 0, 0),
        ("fb_hanging_bulb", 0.00, -2.00, 0, 0), ("fb_hanging_bulb", 0.00, 2.20, 0, 0),
    ],
    # 5.9 x 4.5, dug in.
    "fb_sleeping_bunker": [
        ("fb_cot", -1.50, -0.70, 90, 0), ("fb_cot", 1.50, -0.70, 90, 0),
        ("fb_footlocker", -1.50, 1.20, 0, 0), ("fb_footlocker", 1.50, 1.20, 0, 0),
        ("fb_hanging_bulb", 0.00, 0.00, 0, 0),
    ],
    "fb_bunker_mg": [
        ("fb_ammo_crate_stack", -1.70, 1.15, 0, 0),
        ("fb_c_ration_case", 1.70, 1.25, 0, 0),
    ],
    "fb_bunker_fighting": [
        ("fb_ammo_crate_stack", -1.15, 0.90, 0, 0),
    ],
}

## Reverse of PROP_CLASSES, for stamping the prop_<class> marker beside each placed prop.
PROP_CLASS_OF = {}

## The kit bakes object-named prop markers; the game keys on the CLASS. Rename on contact.
PROP_MARKER_ALIAS = {"prop_bunk": "prop_sleep", "prop_cot": "prop_sleep",
                     "prop_map": "prop_plot"}


def furnish_firebase(seed=771):
    """Place interior props inside every enterable building IN THE CURRENT SCENE, and drop a
    prop_<class> marker at each one.

    Baked in, not furnished at runtime: the runtime path needs the four code changes in
    production/firebase_interior_wiring.md, and running BOTH would double every prop.
    """
    rng = random.Random(seed)
    sc = bpy.context.scene

    for o in list(sc.objects):
        if o.name.startswith("fb_int_"):
            bpy.data.objects.remove(o, do_unlink=True)
    for o in sc.objects:
        base = o.name.split(".")[0]
        if base in PROP_MARKER_ALIAS:
            o.name = o.name.replace(base, PROP_MARKER_ALIAS[base], 1)

    PROP_CLASS_OF.clear()
    for cls, names in PROP_CLASSES.items():
        for n in names:
            PROP_CLASS_OF.setdefault(n, cls)

    masters = {}
    wanted = {p for lay in INTERIOR_LAYOUT.values() for (p, _x, _y, _r, _z) in lay}
    for i, n in enumerate(sorted(wanted)):
        ob, _ = build(n, 300 + i * 13)
        ob.location = (0.0, 0.0, -900.0)
        masters[n] = ob

    bpy.context.view_layer.update()      # host matrices must be current before we read them
    placed, made = 0, {}
    for o in list(sc.objects):
        if o.type != 'MESH':
            continue
        fam = o.name.split(".")[0].replace("_i", "")
        layout = INTERIOR_LAYOUT.get(fam)
        if not layout:
            continue
        vs = [o.matrix_world @ v.co for v in o.data.vertices]
        floor = min(v.z for v in vs)
        ceil = max(v.z for v in vs)
        M = o.matrix_world
        yaw0 = o.rotation_euler.z
        for pick, lx, ly, lyaw, lz in layout:
            m = masters.get(pick)
            if m is None:
                continue
            # local -> world through the host's own transform, so a rotated building keeps
            # its cots against ITS walls rather than against world north.
            wp = M @ Vector((lx, ly, 0.0))
            z = (ceil - 1.72) if pick == "fb_hanging_bulb" else floor + lz
            inst = bpy.data.objects.new(f"fb_int_{pick}", m.data)
            inst.location = (wp.x, wp.y, z + 0.005)
            inst.rotation_euler = (0.0, 0.0, yaw0 + math.radians(lyaw)
                                   + rng.uniform(-0.035, 0.035))
            sc.collection.objects.link(inst)
            cls = PROP_CLASS_OF.get(pick, "storage")
            mk = bpy.data.objects.new(f"prop_{cls}", None)
            mk.empty_display_type = 'PLAIN_AXES'
            mk.empty_display_size = 0.25
            mk.location = inst.location
            mk.rotation_euler = (0.0, 0.0, inst.rotation_euler.z + math.pi / 2.0)
            sc.collection.objects.link(mk)
            placed += 1
            made[pick] = made.get(pick, 0) + 1

    for m in masters.values():
        bpy.data.objects.remove(m, do_unlink=True)
    print(f"furnished {placed} props across the enterable buildings")
    for k in sorted(made):
        print(f"   {k:24} x{made[k]}")
    return placed


def main(clear=True):
    if clear:
        bpy.ops.wm.read_homefile(use_empty=True)
    names = sorted(PROPS)
    print(f"{'prop':24}{'tris':>6}   dims (m)                class")
    cls_of = {}
    for c, lst in PROP_CLASSES.items():
        for p in lst:
            cls_of.setdefault(p, []).append(c)
    x, y, row_h, total = 0.0, 0.0, 0.0, 0
    for i, n in enumerate(names):
        ob, dims = build(n, 41 + i * 7)
        t = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        total += t
        ob.location = (x + dims[0] / 2.0, y, 0.0)
        x += dims[0] + 0.9
        row_h = max(row_h, dims[1])
        if x > 9.0:
            x, y, row_h = 0.0, y - row_h - 1.6, 0.0
        zs = [v.co.z for v in ob.data.vertices]
        seated = abs(min(zs)) < 0.005
        print(f"{n:24}{t:6}   {dims[0]:.2f} x {dims[1]:.2f} x {dims[2]:.2f}"
              f"{'  ON Z=0' if seated else '  !! ORIGIN OFF FLOOR'}"
              f"   {','.join(cls_of.get(n, ['-']))}")
    print(f"\n{len(names)} props, {total} tris, avg {total // len(names)}")
    over = []
    return over


if __name__ == "__main__":
    main()
