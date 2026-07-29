"""Build an M101A1 105mm howitzer and its 4-man PSX crew.

    blender -b -P tools/gen_artillery_crew.py

Writes assets/us/artillery/us_artillery_m101.blend.

DIMENSIONS ARE THE REAL GUN: 5.94 m long, 2.21 m wide, 1.73 m high, 2.31 m
barrel (M101A1). Trails are spread to firing position, so the built footprint is
longer and wider than the towed spec - that is correct for a gun in action.

THE CREW ARE THE REAL TROOP PARTS, NOT Base_Human. A finished US grunt in
us_base_v3.blend is ~40 separate meshes; `Base_Human` is the underlying base
body and using it puts the mannequin on screen with the wrong UVs. The body is
grunt_torso / grunt_head / grunt_leg_* / grunt_forearm_* / grunt_uparm_* on
us_grunt_mat + face_atlas_mat, with the cap_* gore caps.

THE CREW CARRY NOTHING. Summoner's spec: no rifle, no helmet, no backpack. A gun
crew works the piece in fatigues.

CLEARING THE ACTION DOES NOT CLEAR THE POSE. An appended rig keeps whatever bone
channels were last evaluated, so every pose bone is reset to identity or the
mesh renders as shattered spikes.
"""
import bpy
import math
import os
from mathutils import Vector

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO, 'assets', 'us', 'characters', 'us_base_v3.blend')
OUT = os.path.join(REPO, 'assets', 'us', 'artillery', 'us_artillery_m101.blend')
DONOR = 'rifleman'

WIDTH, HEIGHT = 2.21, 1.73
BARREL_LEN, BARREL_R = 2.31, 0.0525
WHEEL_R, WHEEL_W = 0.57, 0.16
TRAIL_LEN = 3.20
SHIELD_W, SHIELD_H = 1.60, 1.05
TUBE_Z = 1.06                      # bore axis height

# the body, and nothing that is worn or carried
BODY = ('grunt_torso', 'grunt_head', 'grunt_leg_l', 'grunt_leg_r',
        'grunt_forearm_l', 'grunt_forearm_r', 'grunt_uparm_l', 'grunt_uparm_r',
        'cap_torso', 'cap_head', 'cap_leg_l', 'cap_leg_r',
        'cap_forearm_l', 'cap_forearm_r', 'cap_uparm_l', 'cap_uparm_r')


def mesh(name, verts, faces, coll):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.validate()
    me.update()
    o = bpy.data.objects.new(name, me)
    coll.objects.link(o)
    return o


def tube(name, r0, r1, length, coll, seg=12, axis='Y'):
    """Tapered tube - a real gun tube is thicker at the breech."""
    v, f = [], []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        c, s = math.cos(a), math.sin(a)
        if axis == 'Y':
            v += [(c * r0, 0, s * r0), (c * r1, length, s * r1)]
        else:
            v += [(0, c * r0, s * r0), (length, c * r1, s * r1)]
    for i in range(seg):
        a, b = 2 * i, 2 * ((i + 1) % seg)
        f.append((a, b, b + 1, a + 1))
    f.append(tuple(range(0, 2 * seg, 2)))
    f.append(tuple(range(2 * seg - 1, 0, -2)))
    return mesh(name, v, f, coll)


def box(name, sx, sy, sz, coll, centre_x=False):
    x0 = -sx / 2 if centre_x else 0.0
    x1 = x0 + sx
    v = [(x0, -sy / 2, -sz / 2), (x1, -sy / 2, -sz / 2), (x1, sy / 2, -sz / 2), (x0, sy / 2, -sz / 2),
         (x0, -sy / 2, sz / 2), (x1, -sy / 2, sz / 2), (x1, sy / 2, sz / 2), (x0, sy / 2, sz / 2)]
    f = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    return mesh(name, v, f, coll)


def wheel(name, coll, seg=16):
    """Rim + tyre + hub, so it reads as a gun wheel rather than a disc."""
    v, f = [], []
    for ring, (r, w) in enumerate(((WHEEL_R, WHEEL_W), (WHEEL_R * 0.62, WHEEL_W * 0.75),
                                   (WHEEL_R * 0.20, WHEEL_W * 1.15))):
        base = len(v)
        for i in range(seg):
            a = 2 * math.pi * i / seg
            c, s = math.cos(a) * r, math.sin(a) * r
            v += [(-w / 2, c, s), (w / 2, c, s)]
        for i in range(seg):
            a, b = base + 2 * i, base + 2 * ((i + 1) % seg)
            f.append((a, b, b + 1, a + 1))
        if ring == 2:
            f.append(tuple(range(base, base + 2 * seg, 2)))
            f.append(tuple(range(base + 2 * seg - 1, base, -2)))
    return mesh(name, v, f, coll)


def build_gun(coll):
    p = []
    # tube: tapered, with a muzzle band and a breech ring
    t = tube('m101_barrel', BARREL_R * 1.35, BARREL_R, BARREL_LEN, coll, 12, 'Y')
    t.location = (0, 0.42, TUBE_Z)
    p.append(t)
    mz = tube('m101_muzzle', BARREL_R * 1.18, BARREL_R * 1.18, 0.10, coll, 12, 'Y')
    mz.location = (0, 0.42 + BARREL_LEN - 0.10, TUBE_Z)
    p.append(mz)
    br = tube('m101_breechring', BARREL_R * 2.0, BARREL_R * 2.0, 0.30, coll, 12, 'Y')
    br.location = (0, 0.10, TUBE_Z)
    p.append(br)
    bb = box('m101_breechblock', 0.20, 0.13, 0.22, coll, centre_x=True)
    bb.location = (0, -0.02, TUBE_Z)
    p.append(bb)
    # recoil sleeve above the tube, counter-recoil below
    for nm, dz, r in (('m101_recoil_upper', 0.105, 0.052), ('m101_recoil_lower', -0.105, 0.045)):
        rc = tube(nm, r, r, 1.15, coll, 8, 'Y')
        rc.location = (0, 0.30, TUBE_Z + dz)
        p.append(rc)
    # cradle + trunnions
    cr = box('m101_cradle', 0.40, 0.70, 0.26, coll, centre_x=True)
    cr.location = (0, 0.30, TUBE_Z - 0.20)
    p.append(cr)
    for side, sx in (('L', 1), ('R', -1)):
        tr = tube('m101_trunnion_%s' % side, 0.05, 0.05, 0.16, coll, 8, 'X')
        tr.location = (sx * 0.20, 0.28, TUBE_Z - 0.10)
        p.append(tr)
    # shield: centre plate plus angled wings
    sh = box('m101_shield', 1.00, 0.035, SHIELD_H, coll, centre_x=True)
    sh.location = (0, 0.62, HEIGHT - SHIELD_H / 2)
    p.append(sh)
    for side, sx in (('L', 1), ('R', -1)):
        wg = box('m101_shield_wing_%s' % side, 0.34, 0.035, SHIELD_H * 0.86, coll)
        wg.location = (sx * 0.50, 0.62, HEIGHT - SHIELD_H / 2 - 0.05)
        wg.rotation_euler = (0, 0, math.radians(-22 * sx))
        if sx < 0:
            wg.rotation_euler = (0, 0, math.radians(180 + 22))
        p.append(wg)
    # axle, wheels
    ax = tube('m101_axle', 0.05, 0.05, WIDTH - 2 * WHEEL_W, coll, 8, 'X')
    ax.location = (-(WIDTH - 2 * WHEEL_W) / 2, 0, WHEEL_R)
    p.append(ax)
    for side, sx in (('L', 1), ('R', -1)):
        w = wheel('m101_wheel_%s' % side, coll)
        w.location = (sx * (WIDTH / 2 - WHEEL_W / 2), 0, WHEEL_R)
        p.append(w)
    # split trails, spread; each with a spade and a lifting handle
    for side, ang in (('L', 18.0), ('R', -18.0)):
        a = math.radians(-90.0 + ang)
        tl = box('m101_trail_%s' % side, TRAIL_LEN, 0.15, 0.20, coll)
        tl.location = (0, -0.12, 0.40)
        tl.rotation_euler = (0, 0, a)
        p.append(tl)
        sp = box('m101_spade_%s' % side, 0.22, 0.20, 0.42, coll)
        sp.location = (math.cos(a) * TRAIL_LEN, -0.12 + math.sin(a) * TRAIL_LEN, 0.21)
        sp.rotation_euler = (0, 0, a)
        p.append(sp)
        hd = box('m101_handle_%s' % side, 0.30, 0.05, 0.05, coll)
        hd.location = (math.cos(a) * (TRAIL_LEN - 0.45), -0.12 + math.sin(a) * (TRAIL_LEN - 0.45), 0.56)
        hd.rotation_euler = (0, 0, a)
        p.append(hd)
    # gunner's furniture
    for nm, loc in (('m101_elev_wheel', (0.46, 0.02, 0.86)), ('m101_trav_wheel', (0.46, -0.20, 0.72))):
        hw = tube(nm, 0.14, 0.14, 0.04, coll, 10, 'X')
        hw.location = loc
        p.append(hw)
    st = box('m101_sight', 0.10, 0.10, 0.28, coll, centre_x=True)
    st.location = (0.42, 0.24, 1.20)
    p.append(st)
    return p


def append_troop():
    """Append one finished troop's body parts + its rig, gear excluded."""
    d = SRC + os.sep + 'Object' + os.sep
    rig_name = 'PSXRig_%s' % DONOR
    bpy.ops.wm.append(directory=d, filename=rig_name)
    rig = bpy.data.objects.get(rig_name)
    parts = []
    for base in BODY:
        nm = '%s_%s' % (base, DONOR)
        bpy.ops.wm.append(directory=d, filename=nm)
        o = bpy.data.objects.get(nm)
        if o:
            parts.append(o)
    # every appended mesh brings its own rig copy; keep one
    strays = [o for o in bpy.data.objects
              if o.type == 'ARMATURE' and o is not rig and o.name.startswith('PSXRig')]
    keep = None
    for o in parts:
        if o.parent and o.parent.type == 'ARMATURE':
            keep = o.parent
            break
    if keep is not None and keep is not rig:
        bpy.data.objects.remove(rig, do_unlink=True)
        rig = keep
    for s in strays:
        if s is not rig:
            bpy.data.objects.remove(s, do_unlink=True)
    for o in parts:
        o.parent = rig
        o.matrix_parent_inverse.identity()
        for m in o.modifiers:
            if m.type == 'ARMATURE':
                m.object = rig
    return rig, parts


def rest(rig):
    """An appended rig keeps its last evaluated pose; wipe it."""
    from mathutils import Matrix
    if rig.animation_data:
        rig.animation_data.action = None
        rig.animation_data_clear()
    rig.data.pose_position = 'POSE'
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)


def gun_bounds(parts):
    out = []
    for g in parts:
        w = [g.matrix_world @ Vector(v) for v in g.bound_box]
        out.append((Vector((min(q.x for q in w), min(q.y for q in w), min(q.z for q in w))),
                    Vector((max(q.x for q in w), max(q.y for q in w), max(q.z for q in w)))))
    return out


def declash(rig, body, gunbb, step=0.06, limit=40):
    """Push a crewman straight out from the gun centre until nothing overlaps."""
    def body_bb():
        pts = []
        for o in body:
            pts += [o.matrix_world @ Vector(v) for v in o.bound_box]
        return (Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))),
                Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts))))
    out = Vector((rig.location.x, rig.location.y, 0.0))
    if out.length < 1e-6:
        out = Vector((1, 0, 0))
    out.normalize()
    for _ in range(limit):
        bpy.context.view_layer.update()
        lo, hi = body_bb()
        hit = False
        for glo, ghi in gunbb:
            if (min(hi.x, ghi.x) > max(lo.x, glo.x) and min(hi.y, ghi.y) > max(lo.y, glo.y)
                    and min(hi.z, ghi.z) > max(lo.z, glo.z)):
                hit = True
                break
        if not hit:
            return True
        rig.location = rig.location + out * step
    bpy.context.view_layer.update()
    return False


STATIONS = {
    'gunner':  (Vector((1.55, 0.30, 0)), -80.0),
    'agunner': (Vector((-1.50, 0.10, 0)), 80.0),
    'loader':  (Vector((-1.30, -1.10, 0)), 45.0),
    'ammo':    (Vector((0.55, -2.30, 0)), 15.0),
}


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scn = bpy.context.scene
    gc = bpy.data.collections.new('M101_HOWITZER')
    cc = bpy.data.collections.new('M101_CREW')
    scn.collection.children.link(gc)
    scn.collection.children.link(cc)

    parts = build_gun(gc)
    root = bpy.data.objects.new('m101_howitzer', None)
    root.empty_display_type = 'ARROWS'
    gc.objects.link(root)
    for p in parts:
        p.parent = root
    bpy.context.view_layer.update()
    gunbb = gun_bounds(parts)

    rig, body = append_troop()
    rest(rig)
    for o in [rig] + body:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        cc.objects.link(o)
    bpy.context.view_layer.update()

    made = []
    for st, (pos, yaw) in STATIONS.items():
        bpy.ops.object.select_all(action='DESELECT')
        rig.select_set(True)
        for b in body:
            b.select_set(True)
        bpy.context.view_layer.objects.active = rig
        bpy.ops.object.duplicate(linked=False)
        new = list(bpy.context.selected_objects)
        nr = next(o for o in new if o.type == 'ARMATURE')
        nb = [o for o in new if o.type == 'MESH']
        nr.name = 'PSXRig_%s' % st
        for o in nb:
            o.name = o.name.split('.')[0].replace('_%s' % DONOR, '') + '_%s' % st
        nr.location = pos
        nr.rotation_euler = (0, 0, math.radians(yaw))
        rest(nr)
        clear = declash(nr, nb, gunbb)
        made.append((st, nr, nb, clear))

    for o in [rig] + body:
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.view_layer.update()

    dg = bpy.context.evaluated_depsgraph_get()
    print('%-9s %-14s %-8s %-8s %-7s %s' % ('station', 'pos', 'height', 'feet z', 'parts', 'clear'))
    for st, nr, nb, clear in made:
        pts = []
        for o in nb:
            e = o.evaluated_get(dg)
            m = e.to_mesh()
            pts += [o.matrix_world @ v.co for v in m.vertices]
            e.to_mesh_clear()
        lo = min(p.z for p in pts)
        hi = max(p.z for p in pts)
        print('%-9s %-14s %-8.3f %-8.3f %-7d %s'
              % (st, '%.2f,%.2f' % (nr.location.x, nr.location.y), hi - lo, lo, len(nb),
                 'yes' if clear else 'NO'))
    tris = 0
    for p in parts:
        p.data.calc_loop_triangles()
        tris += len(p.data.loop_triangles)
    print('howitzer: %d parts, %d tris' % (len(parts), tris))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=OUT)
    print('SAVED %s' % OUT)


main()
