"""Shared builder for VC/NVA unit variants - import inside Blender.

Body proportions derive from the proven US grunt build, scaled by height/slimness.
Each variant lives in its own collection, offset along +X for side-by-side review.
"""
import bpy, bmesh
import numpy as np
from mathutils import Vector

# ---------- materials ----------
def hx(h):
    h = h.lstrip('#')
    return tuple((int(h[i:i+2], 16) / 255) ** 2.2 for i in (0, 2, 4))

def flat_mat(name, hexc, rough=0.95):
    m = bpy.data.materials.get(name)
    if m: return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    b = nt.nodes.new('ShaderNodeBsdfPrincipled'); o = nt.nodes.new('ShaderNodeOutputMaterial')
    nt.links.new(b.outputs['BSDF'], o.inputs['Surface'])
    b.inputs['Base Color'].default_value = (*hx(hexc), 1)
    b.inputs['Roughness'].default_value = rough
    return m

def worn_mat(name, base_hex, fade_hex, scale=25.0):
    m = bpy.data.materials.get(name)
    if m: return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    b = nt.nodes.new('ShaderNodeBsdfPrincipled')
    n1 = nt.nodes.new('ShaderNodeTexNoise'); n1.inputs['Scale'].default_value = scale
    n2 = nt.nodes.new('ShaderNodeTexNoise'); n2.inputs['Scale'].default_value = 4.0
    mx = nt.nodes.new('ShaderNodeMix'); mx.data_type = 'RGBA'
    mx.inputs['A'].default_value = (*hx(base_hex), 1)
    mx.inputs['B'].default_value = (*hx(fade_hex), 1)
    m1 = nt.nodes.new('ShaderNodeMath'); m1.operation = 'MULTIPLY_ADD'
    nt.links.new(n2.outputs['Fac'], m1.inputs[0]); m1.inputs[1].default_value = 0.5; m1.inputs[2].default_value = 0.0
    m2 = nt.nodes.new('ShaderNodeMath'); m2.operation = 'MULTIPLY_ADD'
    nt.links.new(n1.outputs['Fac'], m2.inputs[0]); m2.inputs[1].default_value = 0.22
    nt.links.new(m1.outputs['Value'], m2.inputs[2])
    nt.links.new(m2.outputs['Value'], mx.inputs['Factor'])
    nt.links.new(mx.outputs['Result'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 0.95
    nt.links.new(b.outputs['BSDF'], out.inputs['Surface'])
    return m

def checker_mat(name, hex_a, hex_b, scale=60.0):
    m = bpy.data.materials.get(name)
    if m: return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    b = nt.nodes.new('ShaderNodeBsdfPrincipled')
    ck = nt.nodes.new('ShaderNodeTexChecker')
    ck.inputs['Color1'].default_value = (*hx(hex_a), 1)
    ck.inputs['Color2'].default_value = (*hx(hex_b), 1)
    ck.inputs['Scale'].default_value = scale
    nt.links.new(ck.outputs['Color'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 1.0
    nt.links.new(b.outputs['BSDF'], out.inputs['Surface'])
    return m

# ---------- geometry helpers ----------
def _link(ob, coll):
    coll.objects.link(ob)
    return ob

def _bevel(ob, w, segs=3):
    if w <= 0: return
    b = ob.modifiers.new('Bevel', 'BEVEL')
    b.width = w; b.segments = segs
    b.limit_method = 'ANGLE'; b.angle_limit = 0.7

def tbox(coll, name, z0, z1, w0, d0, w1, d1, cx=0.0, cy=0.0, mat=None, bev=0.02, shift=(0, 0)):
    mesh = bpy.data.meshes.new(name); bm = bmesh.new()
    vb = [Vector((cx + sx * w0, cy + sy * d0, z0)) for sx, sy in [(-1, -1), (1, -1), (1, 1), (-1, 1)]]
    vt = [Vector((cx + shift[0] + sx * w1, cy + shift[1] + sy * d1, z1)) for sx, sy in [(-1, -1), (1, -1), (1, 1), (-1, 1)]]
    verts = [bm.verts.new(v) for v in vb + vt]
    for f in [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]:
        bm.faces.new([verts[i] for i in f])
    bm.to_mesh(mesh); bm.free()
    ob = bpy.data.objects.new(name, mesh)
    if mat: ob.data.materials.append(mat)
    _bevel(ob, bev)
    return _link(ob, coll)

def tbox_x(coll, name, xi, xo, hi, di, ho, do, cz, mat, cy=0.0, bev=0.022, czo=None):
    czo = cz if czo is None else czo
    mesh = bpy.data.meshes.new(name); bm = bmesh.new()
    vi = [Vector((xi, cy + sy * di, cz + sz * hi)) for sy, sz in [(-1, -1), (1, -1), (1, 1), (-1, 1)]]
    vo = [Vector((xo, cy + sy * do, czo + sz * ho)) for sy, sz in [(-1, -1), (1, -1), (1, 1), (-1, 1)]]
    verts = [bm.verts.new(v) for v in vi + vo]
    for f in [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]:
        bm.faces.new([verts[i] for i in f])
    bm.to_mesh(mesh); bm.free()
    ob = bpy.data.objects.new(name, mesh)
    ob.data.materials.append(mat)
    _bevel(ob, bev)
    return _link(ob, coll)

def prim(coll, name, kind, mat, loc, rot=(0, 0, 0), scale=(1, 1, 1), bev=0.0, **kw):
    if kind == 'cube':
        bpy.ops.mesh.primitive_cube_add(size=2, location=loc, rotation=rot)
    elif kind == 'cyl':
        bpy.ops.mesh.primitive_cylinder_add(vertices=kw.get('verts', 12), radius=kw.get('r', 1),
                                            depth=kw.get('depth', 1), location=loc, rotation=rot)
    elif kind == 'cone':
        bpy.ops.mesh.primitive_cone_add(vertices=kw.get('verts', 12), radius1=kw.get('r1', 1),
                                        radius2=kw.get('r2', 0), depth=kw.get('depth', 1),
                                        location=loc, rotation=rot)
    elif kind == 'sphere':
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=kw.get('r', 1),
                                             location=loc, rotation=rot)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = scale
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    ob.data.materials.append(mat)
    _bevel(ob, bev)
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    return _link(ob, coll)

def half_dome(coll, name, mat, loc, r, squash=(1, 1, 0.8), bev=0.0):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=8, radius=r, location=loc)
    ob = bpy.context.active_object; ob.name = name
    bm = bmesh.new(); bm.from_mesh(ob.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.005], context='VERTS')
    bm.to_mesh(ob.data); bm.free()
    ob.scale = squash
    bpy.ops.object.transform_apply(scale=True)
    ob.data.materials.append(mat)
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    return _link(ob, coll)

def sling_strap(coll, name, mat, px, sz, sw, from_shoulder=1, depth_f=None, depth_b=None):
    """Two flat strips hugging the torso: from shoulder (side +1/-1) diagonally to opposite hip."""
    import math as _m
    d_f = depth_f if depth_f is not None else 0.118 * sw   # just proud of chest front
    d_b = depth_b if depth_b is not None else 0.118 * sw
    s = from_shoulder
    x0, z0 = px + s * 0.07 * sw, 1.40 * sz     # shoulder point
    x1, z1 = px - s * 0.13 * sw, 0.92 * sz     # opposite hip
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    length = _m.hypot(x1 - x0, z1 - z0) / 2
    ang = _m.atan2(x1 - x0, z1 - z0)
    for suffix, dy in (('_f', -d_f), ('_b', d_b)):
        prim(coll, name + suffix, 'cube', mat, (cx, dy, cz),
             rot=(0, -ang, 0), scale=(0.024 * sw, 0.006, length), bev=0.0)

# ---------- face texture ----------
def face_tex(name, skin_hex, female=False, headband_hex=None, hair_hex='141414'):
    S = 64
    rng = np.random.default_rng(hash(name) % 9999)
    def h2(h): return np.array([int(h.lstrip('#')[i:i+2], 16) / 255 for i in (0, 2, 4)])
    skin = h2(skin_hex); dark = h2('2A2018'); brow = h2('3A2A1C')
    shadow = skin * 0.72
    img = np.zeros((S, S, 4)); img[:, :, :3] = skin; img[:, :, 3] = 1.0
    for y in range(S):
        t = y / S
        if t < 0.22: img[y, :, :3] = skin * 0.87
        if t > 0.86: img[y, :, :3] = h2(hair_hex)          # hairline
        elif t > 0.80: img[y, :, :3] = skin * 0.6           # brow shadow
    if headband_hex:
        hb = h2(headband_hex)
        img[int(0.74 * S):int(0.86 * S), :, :3] = hb
    ey = int(0.52 * S)
    for cx in (int(0.34 * S), int(0.66 * S)):
        img[ey - 1:ey + 2, cx - 3:cx + 3, :3] = dark
        img[ey + 3:ey + 4 + (0 if female else 1), cx - 4:cx + 4, :3] = brow
        img[ey - 3:ey - 1, cx - 3:cx + 3, :3] = shadow
    nx = S // 2
    img[int(0.42 * S):ey, nx - 1:nx + 1, :3] = shadow
    img[int(0.30 * S):int(0.32 * S), int(0.40 * S):int(0.60 * S), :3] = skin * 0.55
    img[int(0.3 * S):int(0.6 * S), :int(0.10 * S), :3] = skin * 0.9
    img[int(0.3 * S):int(0.6 * S), int(0.90 * S):, :3] = skin * 0.9
    im = bpy.data.images.get(name) or bpy.data.images.new(name, S, S, alpha=True)
    im.pixels.foreach_set(img.ravel().astype(np.float32))
    im.pack()
    m = bpy.data.materials.get('M_' + name) or bpy.data.materials.new('M_' + name)
    m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    tx = nt.nodes.new('ShaderNodeTexImage'); tx.image = im; tx.interpolation = 'Closest'
    b = nt.nodes.new('ShaderNodeBsdfPrincipled'); o = nt.nodes.new('ShaderNodeOutputMaterial')
    b.inputs['Roughness'].default_value = 0.9
    nt.links.new(tx.outputs['Color'], b.inputs['Base Color'])
    nt.links.new(b.outputs['BSDF'], o.inputs['Surface'])
    return m

def map_head_uv(head_ob, cx, zmin, zmax, half_w):
    bm = bmesh.new(); bm.from_mesh(head_ob.data)
    uv = bm.loops.layers.uv.new('UVMap')
    centers = [(f, f.calc_center_median().y) for f in bm.faces]
    fy = min(c[1] for c in centers)
    for f, cy in centers:
        if abs(cy - fy) < 1e-6:
            for lo in f.loops:
                co = lo.vert.co
                lo[uv].uv = ((co.x - cx + half_w) / (2 * half_w), (co.z - zmin) / (zmax - zmin))
        else:
            for lo in f.loops:
                lo[uv].uv = (0.06, 0.40)
    bm.to_mesh(head_ob.data); bm.free()

# ---------- body ----------
def build_body(coll, px, height=1.65, slim=0.85, shirt=None, trouser=None, skin=None,
               sleeves='long', legs='long', feet='sandals', face_mat=None,
               sole_mat=None, female=False):
    """Build T-pose body at x-offset px. Returns dict of key dims."""
    sz = height / 1.80          # vertical scale vs grunt
    sw = slim                   # width scale
    def Z(v): return v * sz
    def W(v): return v * sw
    chest_top = Z(1.42)

    # GoldenEye-style torso: hips -> pinched waist -> broad chest, generous rounding
    tbox(coll, 'hem', Z(0.80), Z(0.92), W(0.165), W(0.115), W(0.148), W(0.10), cx=px, mat=shirt, bev=0.04)
    tbox(coll, 'waist', Z(0.92), Z(1.10), W(0.148), W(0.10), W(0.155), W(0.105), cx=px, mat=shirt, bev=0.04)
    tbox(coll, 'torso', Z(1.10), chest_top, W(0.155), W(0.105), W(0.195) * (0.90 if female else 1), W(0.115), cx=px, mat=shirt, bev=0.05)
    tbox(coll, 'neck', chest_top, Z(1.50), W(0.048), W(0.048), W(0.044), W(0.044), cx=px, mat=skin, bev=0.016)
    head = tbox(coll, 'head', Z(1.47), Z(1.66), W(0.08), W(0.094), W(0.084), W(0.096), cx=px,
                mat=face_mat or skin, bev=0.036)
    if face_mat:
        map_head_uv(head, px, Z(1.47), Z(1.66), W(0.088))

    # legs
    tr_len = Z(0.45) if legs == 'long' else Z(0.62)   # shorts end higher
    for s, p in [(1, 'l'), (-1, 'r')]:
        cx = px + s * W(0.095)
        if legs == 'long':
            tbox(coll, p + '_thigh', Z(0.45), Z(0.80), W(0.078), W(0.09), W(0.09), W(0.105), cx=cx, mat=trouser, bev=0.035)
            tbox(coll, p + '_shin', Z(0.10), Z(0.45), W(0.06), W(0.068), W(0.075), W(0.085), cx=cx, mat=trouser, bev=0.03)
        else:  # shorts
            tbox(coll, p + '_short', Z(0.55), Z(0.80), W(0.085), W(0.10), W(0.095), W(0.11), cx=cx, mat=trouser, bev=0.035)
            tbox(coll, p + '_thigh', Z(0.40), Z(0.55), W(0.07), W(0.08), W(0.078), W(0.09), cx=cx, mat=skin, bev=0.03)
            tbox(coll, p + '_shin', Z(0.08), Z(0.40), W(0.05), W(0.06), W(0.064), W(0.074), cx=cx, mat=skin, bev=0.026)
        # feet
        if feet == 'sandals':
            tbox(coll, p + '_foot', Z(0.025), Z(0.10) if legs == 'long' else Z(0.08),
                 W(0.055), W(0.11), W(0.05), W(0.06), cx=cx, cy=-W(0.035), shift=(0, W(0.035)),
                 mat=skin, bev=0.012)
            tbox(coll, p + '_sole', 0.0, Z(0.025), W(0.06), W(0.115), W(0.058), W(0.112),
                 cx=cx, cy=-W(0.035), mat=sole_mat, bev=0.006)
        elif feet == 'boots':
            tbox(coll, p + '_bootshaft', Z(0.08), Z(0.17), W(0.052), W(0.062), W(0.057), W(0.067), cx=cx, mat=sole_mat, bev=0.014)
            tbox(coll, p + '_bootfoot', 0.0, Z(0.08), W(0.057), W(0.12), W(0.055), W(0.065),
                 cx=cx, cy=-W(0.038), shift=(0, W(0.038)), mat=sole_mat, bev=0.016)
        else:  # bare
            tbox(coll, p + '_foot', 0.0, Z(0.07), W(0.055), W(0.115), W(0.05), W(0.06),
                 cx=cx, cy=-W(0.035), shift=(0, W(0.035)), mat=skin, bev=0.012)

    # arms - sloped shoulders (outer end drops), continuous taper to wrist
    arm_z = Z(1.345)
    drop = Z(0.025)
    for s, p in [(1, 'l'), (-1, 'r')]:
        a0 = px + s * W(0.16)
        sh_mat = skin if sleeves == 'bare' else shirt
        tbox_x(coll, p + '_shoulder', a0, px + s * W(0.25), W(0.075), W(0.07), W(0.055), W(0.055),
               arm_z + Z(0.012), sh_mat, czo=arm_z - drop, bev=0.03)
        up_mat = skin if sleeves == 'bare' else shirt
        tbox_x(coll, p + '_uparm', px + s * W(0.25), px + s * W(0.42), W(0.055), W(0.055), W(0.044), W(0.044),
               arm_z - drop, up_mat, bev=0.026)
        lo_mat = shirt if sleeves == 'long' else skin
        lw = W(0.044) if sleeves == 'long' else W(0.038)
        tbox_x(coll, p + '_loarm', px + s * W(0.42), px + s * W(0.60), lw, lw, W(0.034), W(0.034),
               arm_z - drop, lo_mat, bev=0.024)
        tbox_x(coll, p + '_hand', px + s * W(0.60), px + s * W(0.69), W(0.036), W(0.032), W(0.032), W(0.028),
               arm_z - drop, skin, bev=0.018)

    return {'sz': sz, 'sw': sw, 'head_top': Z(1.66), 'head_z0': Z(1.47),
            'chest_top': chest_top, 'arm_z': arm_z, 'px': px}
