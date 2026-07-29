"""Build the v3 M16A1 and the CAR-15 carbine into weapons_us.blend.

The v3 M16A1 is NOT modelled from scratch. The Summoner's ruling 2026-07-28:
"the shapes are good on the older one but theres weird misalignment problems."
So this CLONES the existing M16A1 shells and corrects only what is misaligned:

  - every part gets its ORIGIN on the bore line (bore datum law) instead of the
    30-odd scattered origins the old gun carries
  - one real <GUN>_root empty whose origin is the bore centre at the muzzle face
  - the 242mm upper receiver band is trimmed to match the lower, killing the
    overlap that ran it through the charge handle and into the buttstock

Lateral alignment is left ALONE - measurement says every shell already sits on
+3.0mm, and the off-centre ones (bolt catch left, forward assist / mag release /
port cover right, charge-handle latch) are deliberate.

The CAR-15 reuses the corrected M16A1 receiver group shifted forward, with a
short barrel and its own round handguard and collapsible stock - the two shapes
the M16A1 does not have.

Blueprints: assets/reference/blueprints/blueprint_us_rifles.md sections 2 / 2b.

Run inside the live session:
    exec(open(r'C:\\Users\\caleb\\RECONgame\\tools\\build_us_rifles_v3.py').read())
"""
import bpy
import math
import os
import sys
from mathutils import Matrix, Vector

sys.path.insert(0, r'C:\Users\caleb\RECONgame\tools')
from weapon_builder import build_weapon, MM

SRC = 'M16A1'                       # the old gun we borrow shapes from
M16 = 'M16A1v3'
CAR = 'CAR15'
COLL_NAME = 'PARTS_NEW'

# lanes: +0.30 in Y off the old gun, so each new gun overlays the reference photo
M16_LANE_Y = 0.30
CAR_LANE_Y = 0.30
CAR_LANE_Z = 0.5435                 # the photo's top-rifle bore line

# what each old shell actually is, measured 2026-07-28
ROLE = {
    'M16A1.013': 'hider_ring',   'M16A1.012': 'hider_rear',
    'M16A1.014': 'hider_slot_c', 'M16A1.015': 'hider_slot_l', 'M16A1.016': 'hider_slot_r',
    'M16A1.001': 'barrel',
    'M16A1.008': 'fsb_flat_a',   'M16A1.007': 'fsb_flat_b',   'M16A1.006': 'fsb_flat_c',
    'M16A1.005': 'fsb_flat_d',
    'M16A1.004': 'fsb_ear_l',    'M16A1.003': 'fsb_ear_r',    'M16A1.002': 'sight_post',
    'M16A1.009': 'handguard',    'M16A1.017': 'delta_ring',
    'M16A1':     'upper',        'M16A1.010': 'carry_handle', 'M16A1.011': 'rear_sight',
    'M16A1_cart_flap.019': 'port_cover',
    'M16A1.020': 'bolt_catch',   'M16A1.033': 'mag_catch_l',  'M16A1.025': 'mag_catch_r',
    'M16A1.029': 'magwell',      'M16A1.028': 'lower',
    'M16A1_magazine.001': 'mag_floor', 'M16A1_magazine.030': 'magazine',
    'M16A1.032': 'mag_release',  'M16A1.026': 'trigger_guard',
    'M16A1_trigger.034': 'trigger',
    'M16A1.021': 'receiver_rear', 'M16A1.018': 'fwd_assist',
    'M16A1.027': 'grip',
    'M16A1_charge_handle_slide_back': 'charge_handle',
    'M16A1_charge_handle_slide_back.001': 'charge_handle_t',
    'M16A1_charge_handle_slide_back.002': 'charge_handle_latch',
    'M16A1.022': 'stock',        'M16A1.023': 'buttplate',
}

# CAR-15: parts the carbine does not share with the rifle
CAR_DROP = {'handguard', 'stock', 'buttplate', 'barrel'}
# everything from the receiver back moves forward by this much (blueprint 2b)
CAR_SHIFT = -0.138


def mat(name, hexs, rough, metal):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    r, g, bl = (int(hexs[i:i + 2], 16) / 255 for i in (0, 2, 4))
    b.inputs['Base Color'].default_value = (r ** 2.2, g ** 2.2, bl ** 2.2, 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    return m


def world_bbox(objs):
    mn = Vector((1e9,) * 3); mx = Vector((-1e9,) * 3)
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            for i in range(3):
                mn[i] = min(mn[i], w[i]); mx[i] = max(mx[i], w[i])
    return mn, mx


def get_collection(name):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(c)
    return c


def source_parts():
    out = {}
    for o in bpy.data.objects:
        if o.type == 'MESH' and o.name in ROLE:
            out[ROLE[o.name]] = o
    missing = set(ROLE.values()) - set(out)
    if missing:
        print('  WARN missing source shells: %s' % sorted(missing))
    return out


def measure_bore(src):
    """The bore is defined by the flash hider ring - a symmetric shell on the axis."""
    ring = src['hider_ring']
    mn, mx = world_bbox([ring])
    return (mn.y + mx.y) / 2.0, (mn.z + mx.z) / 2.0


def clone(src_obj, newname, coll, offset):
    ob = src_obj.copy()
    ob.data = src_obj.data.copy()
    ob.name = newname
    ob.animation_data_clear()
    for c in list(ob.constraints):
        ob.constraints.remove(c)
    ob.parent = None
    ob.matrix_world = src_obj.matrix_world.copy()
    ob.location = ob.location + offset
    ob.hide_viewport = False
    ob.hide_render = False
    coll.objects.link(ob)
    return ob


def set_origin_on_bore(ob, bore_y, bore_z):
    """Bore datum law: a part's origin sits on the bore line, at its own x centre.

    Moves the origin without moving one vertex in world space: with basis B, an
    origin move O -> T needs the mesh translated by B^-1 @ (O - T).
    """
    mn, mx = world_bbox([ob])
    target = Vector(((mn.x + mx.x) / 2.0, bore_y, bore_z))
    delta = ob.matrix_world.translation - target
    ob.data.transform(Matrix.Translation(ob.matrix_world.to_3x3().inverted() @ delta))
    ob.data.update()
    ob.matrix_world.translation = target


def trim_x(ob, x0, x1):
    """Rescale a shell along X so it spans exactly [x0, x1] in world space."""
    mn, mx = world_bbox([ob])
    cur = mx.x - mn.x
    if cur <= 1e-9:
        return
    s = (x1 - x0) / cur
    M = ob.matrix_world.copy()
    Minv = M.inverted()
    for v in ob.data.vertices:
        w = M @ v.co
        w.x = x0 + (w.x - mn.x) * s
        v.co = Minv @ w
    ob.data.update()


# A1 pistol grip, side profile in gun-local mm: the back edge runs nearly
# straight while the front rakes back ~33 deg, with the swell just under the
# trigger-finger shelf. (z from bore, x from muzzle, half-width lateral)
GRIP_PROFILE = [
    (-39.0, 696.0, 740.0, 15.0),
    (-55.0, 699.0, 745.0, 15.5),
    (-70.0, 705.0, 749.0, 15.5),
    (-90.0, 714.0, 752.0, 15.0),
    (-110.0, 725.0, 755.0, 14.0),
    (-125.0, 734.0, 757.0, 13.0),
    (-133.0, 740.0, 757.0, 11.0),
]


def build_grip_mesh(gun, muzzle_x, bore_y, bore_z, x_shift=0.0):
    """Replace the cloned slab grip with a lofted A1 profile, in place.

    Rings are authored in WORLD space off the gun's own muzzle/bore datum, then
    pulled into the object's local basis - the object keeps its bore origin.
    """
    import bmesh
    ob = bpy.data.objects.get('%s_grip' % gun)
    if ob is None:
        return None
    keep_mat = ob.data.materials[0] if ob.data.materials else None
    inv = ob.matrix_world.inverted()

    def ring(bm, x_f, x_b, hw, z):
        xf, xb = x_f + x_shift, x_b + x_shift
        r = 0.30 * min(xb - xf, 2 * hw) / 2.0
        pts = [(xf + r, -hw), (xb - r, -hw), (xb, -hw + r), (xb, hw - r),
               (xb - r, hw), (xf + r, hw), (xf, hw - r), (xf, -hw + r)]
        out = []
        for px, py in pts:
            w = Vector((muzzle_x + px * MM, bore_y + py * MM, bore_z + z * MM))
            out.append(bm.verts.new(inv @ w))
        return out

    bm = bmesh.new()
    rings = [ring(bm, xf, xb, hw, z) for z, xf, xb, hw in GRIP_PROFILE]
    for a, b in zip(rings, rings[1:]):
        for k in range(8):
            j = (k + 1) % 8
            bm.faces.new((a[k], a[j], b[j], b[k]))
    bm.faces.new(rings[0][::-1])
    bm.faces.new(rings[-1])
    bm.normal_update()
    me = bpy.data.meshes.new('%s_gripMesh' % gun)
    bm.to_mesh(me)
    bm.free()
    if keep_mat:
        me.materials.append(keep_mat)
    # the loft is authored in gun-local mm; place it via the object's own basis
    old_me = ob.data
    ob.data = me
    if old_me.users == 0:
        bpy.data.meshes.remove(old_me)
    for p in ob.data.polygons:
        p.use_smooth = False
    return ob


def seat_magwell(gun):
    """magwell_<GUN> IS the magazine's seated transform. With origins on the bore
    that means the marker coincides with the magazine object's origin, so a reload
    can snap the mag straight onto it."""
    mag = bpy.data.objects.get('%s_magazine' % gun)
    mw = bpy.data.objects.get('magwell_%s' % gun)
    if mag and mw:
        mw.matrix_world = mag.matrix_world.copy()


def make_root(gun, muzzle_x, bore_y, bore_z, coll, children):
    old = bpy.data.objects.get('%s_root' % gun)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    root = bpy.data.objects.new('%s_root' % gun, None)
    root.empty_display_type = 'ARROWS'
    root.empty_display_size = 0.08
    root.location = (muzzle_x, bore_y, bore_z)
    coll.objects.link(root)
    bpy.context.view_layer.update()
    for ob in children:
        w = ob.matrix_world.copy()
        ob.parent = root
        ob.matrix_parent_inverse = root.matrix_world.inverted()
        ob.matrix_world = w
    return root


def make_markers(gun, marks, muzzle_x, bore_y, bore_z, coll):
    """marks: name -> (display_type, from_muzzle_mm, bore_off_mm, lateral_mm)"""
    made = []
    for key, (disp, fm, bo, lat) in marks.items():
        nm = '%s_%s' % (key, gun)
        old = bpy.data.objects.get(nm)
        if old:
            bpy.data.objects.remove(old, do_unlink=True)
        e = bpy.data.objects.new(nm, None)
        e.empty_display_type = disp
        e.empty_display_size = 0.02
        e.location = (muzzle_x + fm * MM, bore_y + lat * MM, bore_z + bo * MM)
        if key == 'eject':
            e.rotation_euler = (math.radians(-75), 0.0, math.radians(15))
        coll.objects.link(e)
        made.append(e)
    return made


def build_m16(coll):
    src = source_parts()
    bore_y, bore_z = measure_bore(src)
    mn, mx = world_bbox(list(src.values()))
    muzzle_x = mn.x
    offset = Vector((0.0, M16_LANE_Y - bore_y, 0.0))
    new_bore_y = M16_LANE_Y

    made = []
    for role, o in src.items():
        made.append(clone(o, '%s_%s' % (M16, role), coll, offset))
    bpy.context.view_layer.update()

    by_role = {o.name.split('_', 1)[1]: o for o in made}

    # THE OVERLAP FIX: the upper receiver band runs 242mm, through the charge
    # handle and 9mm into the buttstock. Trim it to the lower receiver's front
    # face and the rear-receiver join.
    low = by_role.get('lower')
    if low is not None and by_role.get('upper') is not None:
        lmn, lmx = world_bbox([low])
        trim_x(by_role['upper'], lmn.x, lmx.x)
        print('  upper receiver trimmed to the lower: %.1fmm' % ((lmx.x - lmn.x) * 1000))

    build_grip_mesh(M16, muzzle_x, new_bore_y, bore_z)

    for o in made:
        set_origin_on_bore(o, new_bore_y, bore_z)
    bpy.context.view_layer.update()

    marks = {
        'muzzle':          ('PLAIN_AXES',   0,     0,     0),
        # measured on geometry: post TIP and aperture CENTRE, both +46.0.
        # +52 is the FSB protective ears, not the sight picture - seating the
        # marker there is the 2026-07-28 ADS bug all over again.
        'sight_front':     ('PLAIN_AXES',   152.5, 46,    0),
        'sight_rear':      ('PLAIN_AXES',   701.5, 46,    0),
        'grip_LeftHand':   ('PLAIN_AXES',   340,   0,     0),
        'grip_RightHand':  ('PLAIN_AXES',   722,   -75,   0),
        'magwell':         ('ARROWS',       589,   -93,   0),
        'eject':           ('SINGLE_ARROW', 577,   -2,    18),
        'contact_chandle': ('PLAIN_AXES',   768,   19,    0),
        'contact_mag':     ('PLAIN_AXES',   589,   -100,  0),
    }
    mk = make_markers(M16, marks, muzzle_x, new_bore_y, bore_z, coll)
    seat_magwell(M16)
    root = make_root(M16, muzzle_x, new_bore_y, bore_z, coll, made + mk)
    print('%s: %d meshes + %d markers under %s_root' % (M16, len(made), len(mk), M16))
    return root, by_role, muzzle_x, new_bore_y, bore_z


def build_car(coll, m16_roles, m16_muzzle_x, bore_y, bore_z):
    """Carbine: the corrected M16 receiver group shifted forward, plus its own
    short barrel, round handguard and collapsible stock."""
    dz = CAR_LANE_Z - bore_z
    made = []
    for role, o in m16_roles.items():
        if role in CAR_DROP:
            continue
        shift = Vector((0.0, 0.0, dz))
        # everything from the delta ring back rides the 138mm forward shift
        mn, mx = world_bbox([o])
        if (mn.x - m16_muzzle_x) > 0.185:
            shift.x += CAR_SHIFT
        made.append(clone(o, '%s_%s' % (CAR, role), coll, shift))
    bpy.context.view_layer.update()

    car_muzzle_x = m16_muzzle_x
    car_bore_z = CAR_LANE_Z
    o = Vector((car_muzzle_x, bore_y, car_bore_z))

    PARK = bpy.data.materials.get('ParkerizedSteel')
    POLY = bpy.data.materials.get('BlackPolymer')
    ANOD = bpy.data.materials.get('AnodizedAlu')
    extra = [
        dict(name='moderator',  shape='cyl',  from_muzzle=50,   R=12,  L=100, mat=PARK, verts=8),
        dict(name='barrel',     shape='cyl',  from_muzzle=127,  R=6.5, L=56,  mat=PARK, verts=8),
        dict(name='barrelhg',   shape='cyl',  from_muzzle=290,  R=6.5, L=230, mat=PARK, verts=8),
        dict(name='handguard',  shape='cyl',  from_muzzle=292, bore_off=1.5, R=27.5, L=176,
             mat=POLY, verts=12),
        dict(name='buffertube', shape='cyl',  from_muzzle=665, bore_off=-2, R=16, L=150,
             mat=ANOD, verts=10),
        dict(name='stock',      shape='tbox', from_muzzle=673, bore_off=-7, L=160,
             H=42, W=38, H2=94, W2=38, drop=26, mat=POLY),
        dict(name='buttplate',  shape='box',  from_muzzle=750, bore_off=-33, L=6, H=94, W=38,
             mat=POLY, bev=1),
    ]
    made += build_weapon(CAR, extra, o, coll)
    bpy.context.view_layer.update()

    build_grip_mesh(CAR, car_muzzle_x, bore_y, car_bore_z, x_shift=CAR_SHIFT * 1000.0)

    # Summoner's ruling 2026-07-28: the carbine is uniformly metallic black.
    black = mat('CarbineBlack', '1A1A1C', 0.35, 0.90)
    for ob in made:
        ob.data.materials.clear()
        ob.data.materials.append(black)

    for ob in made:
        set_origin_on_bore(ob, bore_y, car_bore_z)
    bpy.context.view_layer.update()

    marks = {
        'muzzle':          ('PLAIN_AXES',   0,     0,     0),
        'sight_front':     ('PLAIN_AXES',   152.5, 46,    0),
        'sight_rear':      ('PLAIN_AXES',   563.5, 46,    0),
        'grip_LeftHand':   ('PLAIN_AXES',   292,   0,     0),
        'grip_RightHand':  ('PLAIN_AXES',   584,   -75,   0),
        'magwell':         ('ARROWS',       451,   -93,   0),
        'eject':           ('SINGLE_ARROW', 439,   -2,    18),
        'contact_chandle': ('PLAIN_AXES',   630,   19,    0),
        'contact_mag':     ('PLAIN_AXES',   451,   -100,  0),
    }
    mk = make_markers(CAR, marks, car_muzzle_x, bore_y, car_bore_z, coll)
    seat_magwell(CAR)
    make_root(CAR, car_muzzle_x, bore_y, car_bore_z, coll, made + mk)
    print('%s: %d meshes + %d markers under %s_root' % (CAR, len(made), len(mk), CAR))


def main():
    if bpy.context.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    coll = get_collection(COLL_NAME)

    for gun in (M16, CAR):
        for ob in [o for o in bpy.data.objects if o.name.startswith(gun)]:
            bpy.data.objects.remove(ob, do_unlink=True)

    root, roles, mx, by, bz = build_m16(coll)
    build_car(coll, roles, mx, by, bz)
    print('BUILD OK')


if __name__ == '__main__':
    main()
