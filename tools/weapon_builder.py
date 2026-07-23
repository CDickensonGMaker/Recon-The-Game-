"""Blueprint-driven weapon builder for v2 realistic weapons.

Convention: each weapon is built muzzle-at-origin, bore axis along +X
(muzzle tip x=0, stock end x=+total_length), bore line at z=0.
Part positions come straight from blueprint tables:
  from_muzzle : mm, distance of part CENTER from muzzle tip
  bore_off    : mm, vertical offset of part center from bore line (+up)
All dims in mm; world scale = 1/1000.

Part dict keys:
  name, shape ('box'|'tbox'|'cyl'|'cone'|'ring'|'spike'|'belt'), from_muzzle,
  bore_off, L,H,W (mm), mat, angle (deg pitch, +muzzle-down), bev (mm),
  tbox extras: L,H,W = inner end, H2,W2 = outer end, drop (mm, outer end sinks)
  cyl/cone: R (radius mm), R2 (cone tip radius)
  ring: R (outer radius), R2 (inner radius), L (length along bore) -- open both
        ends, so the sight post inside stays visible through it
  spike: R (half-width at base), L (length), blades (4=cruciform); tapers to a
         point toward -X, i.e. deployed forward
  belt: R (cartridge radius), L (cartridge length), pitch (mm between links),
        links (count), rise (mm the run climbs over its length)
"""
import bpy, bmesh
from math import radians, sin, cos, pi
from mathutils import Vector

MM = 0.001

def _link(ob, coll):
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    coll.objects.link(ob)
    return ob

def _bevel(ob, w_mm, segs=2):
    if w_mm <= 0: return
    b = ob.modifiers.new('Bevel', 'BEVEL')
    b.width = w_mm * MM; b.segments = segs
    b.limit_method = 'ANGLE'; b.angle_limit = 0.7

def build_part(coll, wname, p, origin):
    """origin: Vector world position of the muzzle tip. +X toward stock."""
    n = f"{wname}_{p['name']}"
    x = origin.x + p['from_muzzle'] * MM
    y = origin.y + p.get('lat', 0) * MM
    z = origin.z + p.get('bore_off', 0) * MM
    ang = radians(p.get('angle', 0))
    shape = p.get('shape', 'box')
    mat = p['mat']
    bev = p.get('bev', 2)

    if shape in ('box',):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z), rotation=(0, ang, 0))
        ob = bpy.context.active_object
        ob.scale = (p['L'] * MM, p['W'] * MM, p['H'] * MM)
        bpy.ops.object.transform_apply(scale=True, rotation=True)
    elif shape == 'cyl':
        bpy.ops.mesh.primitive_cylinder_add(vertices=p.get('verts', 10), radius=p['R'] * MM,
                                            depth=p['L'] * MM, location=(x, y, z),
                                            rotation=(0, radians(90) + ang, 0))
        ob = bpy.context.active_object
        bpy.ops.object.transform_apply(rotation=True)
    elif shape == 'cone':
        # cone pointing toward muzzle (-X)
        bpy.ops.mesh.primitive_cone_add(vertices=p.get('verts', 10), radius1=p['R'] * MM,
                                        radius2=p.get('R2', 0) * MM, depth=p['L'] * MM,
                                        location=(x, y, z), rotation=(0, radians(-90) + ang, 0))
        ob = bpy.context.active_object
        bpy.ops.object.transform_apply(rotation=True)
    elif shape == 'ring':
        mesh = bpy.data.meshes.new(n); bm = bmesh.new()
        ro, ri = p['R'] * MM, p['R2'] * MM
        x0, x1 = x - p['L'] * MM / 2, p['L'] * MM / 2 + x
        nv = p.get('verts', 12)
        rows = []
        for xx in (x0, x1):
            o_ring, i_ring = [], []
            for k in range(nv):
                a = 2 * pi * k / nv
                o_ring.append(bm.verts.new((xx, y + ro * sin(a), z + ro * cos(a))))
                i_ring.append(bm.verts.new((xx, y + ri * sin(a), z + ri * cos(a))))
            rows.append((o_ring, i_ring))
        (fo, fi), (bo, bi) = rows
        for k in range(nv):
            j = (k + 1) % nv
            bm.faces.new((fo[k], fo[j], fi[j], fi[k]))
            bm.faces.new((bi[k], bi[j], bo[j], bo[k]))
            bm.faces.new((fo[k], bo[k], bo[j], fo[j]))
            bm.faces.new((fi[j], bi[j], bi[k], fi[k]))
        bm.to_mesh(mesh); bm.free()
        ob = bpy.data.objects.new(n, mesh)
        coll.objects.link(ob); ob.data.materials.append(mat)
        return ob
    elif shape == 'notch':
        mesh = bpy.data.meshes.new(n); bm = bmesh.new()
        hl, hh, hw = p['L'] * MM / 2, p['H'] * MM / 2, p['W'] * MM / 2
        gap, dep = p['gap'] * MM / 2, p['depth'] * MM
        def slab(y0, y1, z0, z1):
            vs = [bm.verts.new((x + sx * hl, y + sy, z + sz)) for sx, sy, sz in
                  [(-1, y0, z0), (1, y0, z0), (1, y1, z0), (-1, y1, z0),
                   (-1, y0, z1), (1, y0, z1), (1, y1, z1), (-1, y1, z1)]]
            for f in [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]:
                bm.faces.new([vs[i] for i in f])
        slab(-hw, -gap, -hh, hh)
        slab(gap, hw, -hh, hh)
        slab(-hw, hw, -hh, hh - dep)
        bm.to_mesh(mesh); bm.free()
        ob = bpy.data.objects.new(n, mesh)
        coll.objects.link(ob); ob.data.materials.append(mat)
        _bevel(ob, bev)
        return ob
    elif shape == 'spike':
        mesh = bpy.data.meshes.new(n); bm = bmesh.new()
        r, ln = p['R'] * MM, p['L'] * MM
        blades = p.get('blades', 4)
        ca, sa = cos(ang), sin(ang)
        def put(lx, ly, lz):
            return bm.verts.new((x + lx * ca + lz * sa, y + ly, z - lx * sa + lz * ca))
        base, mid = [], []
        for k in range(blades):
            a = 2 * pi * k / blades + pi / 4
            base.append(put(0.0, r * sin(a), r * cos(a)))
            mid.append(put(-ln * 0.85, r * 0.28 * sin(a), r * 0.28 * cos(a)))
        tip = put(-ln, 0.0, 0.0)
        for k in range(blades):
            j = (k + 1) % blades
            bm.faces.new((base[k], mid[k], mid[j], base[j]))
            bm.faces.new((mid[k], tip, mid[j]))
        bm.faces.new(base[::-1])
        bm.to_mesh(mesh); bm.free()
        ob = bpy.data.objects.new(n, mesh)
        coll.objects.link(ob); ob.data.materials.append(mat)
        _bevel(ob, bev)
        return ob
    elif shape == 'belt':
        mesh = bpy.data.meshes.new(n); bm = bmesh.new()
        r, ln = p['R'] * MM, p['L'] * MM
        pitch, links = p['pitch'] * MM, p['links']
        rise = p.get('rise', 0) * MM
        for i in range(links):
            cx = x + i * pitch
            cz = z + (rise * i / max(1, links - 1))
            ring_v = []
            for e, xe in ((0, cz + ln / 2), (1, cz - ln / 2)):
                row = []
                for k in range(6):
                    a = 2 * pi * k / 6
                    row.append(bm.verts.new((cx + r * cos(a), y + r * sin(a), xe)))
                ring_v.append(row)
            for k in range(6):
                j = (k + 1) % 6
                bm.faces.new((ring_v[0][k], ring_v[0][j], ring_v[1][j], ring_v[1][k]))
            bm.faces.new(ring_v[0]); bm.faces.new(ring_v[1][::-1])
            lk = p.get('link_w', 3.0) * MM
            for sy in (-1, 1):
                vs = [bm.verts.new((cx + sx * pitch * 0.42, y + sy * (r + lk), cz + sz * r * 0.55))
                      for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
                bm.faces.new(vs)
        bm.to_mesh(mesh); bm.free()
        ob = bpy.data.objects.new(n, mesh)
        coll.objects.link(ob); ob.data.materials.append(mat)
        return ob
    elif shape == 'tbox':
        # tapered box along X: inner (muzzle side) LxHxW -> outer H2xW2, outer end drops by 'drop'
        mesh = bpy.data.meshes.new(n); bm = bmesh.new()
        x0 = x - p['L'] * MM / 2; x1 = x + p['L'] * MM / 2
        h0, w0 = p['H'] * MM / 2, p['W'] * MM / 2
        h1, w1 = p.get('H2', p['H']) * MM / 2, p.get('W2', p['W']) * MM / 2
        drop = p.get('drop', 0) * MM
        # slant: pulls the inner end's BOTTOM edge rearward so the face is cut
        # on a diagonal with the top leading -- the PPSh compensator profile
        sl = p.get('slant', 0) * MM
        vi = [Vector((x0 + (sl if sz < 0 else 0), y + sy * w0, z + sz * h0))
              for sy, sz in [(-1, -1), (1, -1), (1, 1), (-1, 1)]]
        vo = [Vector((x1, y + sy * w1, z - drop + sz * h1)) for sy, sz in [(-1, -1), (1, -1), (1, 1), (-1, 1)]]
        verts = [bm.verts.new(v) for v in vi + vo]
        for f in [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]:
            bm.faces.new([verts[i] for i in f])
        bm.to_mesh(mesh); bm.free()
        ob = bpy.data.objects.new(n, mesh)
        coll.objects.link(ob)
        ob.data.materials.append(mat)
        _bevel(ob, bev)
        return ob
    ob.name = n
    ob.data.materials.append(mat)
    _bevel(ob, bev)
    return _link(ob, coll)

def build_weapon(name, parts, origin, coll=None):
    coll = coll or bpy.context.scene.collection
    made = []
    for p in parts:
        ob = build_part(coll, name, p, Vector(origin))
        if p.get('hide'):
            ob.hide_viewport = True
            ob.hide_render = True
        made.append(ob)
    print(f"{name}: {len(made)} parts")
    return made

def build_markers(name, marks, origin, coll=None):
    """marks: {'sight_front'|'sight_rear'|'grip_L'|'grip_R'|'muzzle':
               (from_muzzle, bore_off[, lateral])} in mm.

    export_viewmodel.py renames sight_front/sight_rear/muzzle to
    SightFront/SightRear/MuzzlePoint; viewmodel_editor reads POSITION only,
    never the empty's orientation.
    """
    coll = coll or bpy.context.scene.collection
    o = Vector(origin)
    made = []
    for key, v in marks.items():
        fm, bo = v[0], v[1]
        lat = v[2] if len(v) > 2 else 0.0
        e = bpy.data.objects.new(f"{key}_{name}", None)
        e.empty_display_type = 'PLAIN_AXES'
        e.empty_display_size = 0.02
        coll.objects.link(e)
        e.location = (o.x + fm * MM, o.y + lat * MM, o.z + bo * MM)
        made.append(e)
    print(f"{name}: {len(made)} markers")
    return made
