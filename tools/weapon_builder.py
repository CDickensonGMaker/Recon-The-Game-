"""Blueprint-driven weapon builder for v2 realistic weapons.

Convention: each weapon is built muzzle-at-origin, bore axis along +X
(muzzle tip x=0, stock end x=+total_length), bore line at z=0.
Part positions come straight from blueprint tables:
  from_muzzle : mm, distance of part CENTER from muzzle tip
  bore_off    : mm, vertical offset of part center from bore line (+up)
All dims in mm; world scale = 1/1000.

Part dict keys:
  name, shape ('box'|'tbox'|'cyl'|'cone'), from_muzzle, bore_off,
  L,H,W (mm), mat, angle (deg pitch, +muzzle-down), bev (mm),
  tbox extras: L,H,W = inner end, H2,W2 = outer end, drop (mm, outer end sinks)
  cyl/cone: R (radius mm), R2 (cone tip radius)
"""
import bpy, bmesh
from math import radians
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
    y = origin.y
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
    elif shape == 'tbox':
        # tapered box along X: inner (muzzle side) LxHxW -> outer H2xW2, outer end drops by 'drop'
        mesh = bpy.data.meshes.new(n); bm = bmesh.new()
        x0 = x - p['L'] * MM / 2; x1 = x + p['L'] * MM / 2
        h0, w0 = p['H'] * MM / 2, p['W'] * MM / 2
        h1, w1 = p.get('H2', p['H']) * MM / 2, p.get('W2', p['W']) * MM / 2
        drop = p.get('drop', 0) * MM
        vi = [Vector((x0, y + sy * w0, z + sz * h0)) for sy, sz in [(-1, -1), (1, -1), (1, 1), (-1, 1)]]
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
    made = [build_part(coll, name, p, Vector(origin)) for p in parts]
    print(f"{name}: {len(made)} parts")
    return made
