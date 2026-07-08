"""Repeatable head. Build once, reuse on every character.

    from head_builder import build_head
    head, ears = build_head(coll, face='us_black_headset', skin='5B4435',
                            height=0.228, at=(0, 0, 1.45))

Gives you:
  * a skull-proportioned head (jaw taper, wide temples, occipital bulge)
  * a FLAT front plane so the pixel-art face sheet maps cleanly
  * modeled ears on the ear line (not painted)
  * two material slots: HeadSkin (tunable colour) + FaceSheet (front only)
  * every face UV'd, so you can paint the detail atlas later if you want

Real adult skull, chin to crown: 228mm tall, 152 wide, 196 deep.
Ear canal sits 48% up from the chin; brow ridge 66%.

Face sheet grid: row 0 = 5 US faces, row 1 = 6 VC faces (UV v is bottom-up).
"""
import bpy, bmesh, math
from mathutils import Vector

SHEET = r"C:\Users\caleb\Desktop\recon game image ideas\mesh faces.png"

FACE_CELLS = {
    'us_scar': (0, 0, 5), 'us_young': (0, 1, 5), 'us_older': (0, 2, 5),
    'us_black_headset': (0, 3, 5), 'us_black': (0, 4, 5),
    'vc_male_short': (1, 0, 6), 'vc_male_moustache': (1, 1, 6),
    'vc_male_long': (1, 2, 6), 'vc_female_short': (1, 3, 6),
    'vc_female_bob': (1, 4, 6), 'vc_female_long': (1, 5, 6),
}

# t from chin -> (half-width scale, back-depth scale, back-shift)
PROFILE = [
    (0.00, 0.70, 0.80,  0.000),   # chin: narrow, short
    (0.28, 0.90, 0.95, -0.002),   # jaw / cheekbone
    (0.62, 1.00, 1.00,  0.004),   # brow + temple: widest
    (0.86, 0.97, 1.02,  0.010),   # parietal, occipital bulge
    (1.00, 0.80, 0.90,  0.008),   # crown
]

def _lerp(t):
    for i in range(len(PROFILE) - 1):
        a, b = PROFILE[i], PROFILE[i + 1]
        if a[0] <= t <= b[0]:
            f = (t - a[0]) / (b[0] - a[0]) if b[0] > a[0] else 0.0
            return tuple(a[j] + (b[j] - a[j]) * f for j in (1, 2, 3))
    return PROFILE[-1][1:]


def _hx(h):
    h = h.lstrip('#')
    return tuple((int(h[i:i+2], 16) / 255) ** 2.2 for i in (0, 2, 4))


def face_sheet_image():
    img = bpy.data.images.get('face_sheet')
    if img is None:
        img = bpy.data.images.load(SHEET)
        img.name = 'face_sheet'
    img.pack()
    return img


def cell_uv(face):
    row, col, ncols = FACE_CELLS[face]
    u0 = col / ncols
    u1 = (col + 1) / ncols
    v1 = 1.0 - row * 0.5
    v0 = v1 - 0.5
    return u0, v0, u1, v1


def _materials(skin_hex):
    skin = bpy.data.materials.get('HeadSkin')
    if skin is None:
        skin = bpy.data.materials.new('HeadSkin')
        skin.use_nodes = True
    b = next(n for n in skin.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs['Base Color'].default_value = (*_hx(skin_hex), 1)
    b.inputs['Roughness'].default_value = 0.88

    face = bpy.data.materials.get('FaceSheet')
    if face is None:
        face = bpy.data.materials.new('FaceSheet')
        face.use_nodes = True
        nt = face.node_tree; nt.nodes.clear()
        tx = nt.nodes.new('ShaderNodeTexImage'); tx.name = 'FaceTex'
        tx.image = face_sheet_image(); tx.interpolation = 'Closest'
        tx.location = (-320, 0)
        bs = nt.nodes.new('ShaderNodeBsdfPrincipled'); bs.location = (0, 0)
        bs.inputs['Roughness'].default_value = 0.9
        out = nt.nodes.new('ShaderNodeOutputMaterial'); out.location = (300, 0)
        nt.links.new(tx.outputs['Color'], bs.inputs['Base Color'])
        nt.links.new(bs.outputs['BSDF'], out.inputs['Surface'])
    return skin, face


def _bevel(ob, w, segs=3):
    m = ob.modifiers.new('Bevel', 'BEVEL')
    m.width = w; m.segments = segs
    m.limit_method = 'ANGLE'; m.angle_limit = 0.7


def build_head(coll, face='us_young', skin='9C6E4E', height=0.228,
               at=(0.0, 0.0, 1.45), name='head', ears=True, rows=4):
    """Chin sits at `at`. Returns (head_obj, [ear_objs])."""
    W, D, H = 0.152, 0.196, height
    cx, cy, chin = at
    skin_mat, face_mat = _materials(skin)

    bm = bmesh.new()
    grid = []                       # grid[row] = 4 verts, CCW from front-left
    for r in range(rows + 1):
        t = r / rows
        sw, sd, dy = _lerp(t)
        z = chin + t * H
        hw = W / 2 * sw
        front = cy - D / 2 * 0.98               # flat face plane, barely tapered
        back = cy + D / 2 * sd + dy * D
        ring = [bm.verts.new((cx - hw, front, z)),
                bm.verts.new((cx + hw, front, z)),
                bm.verts.new((cx + hw, back,  z)),
                bm.verts.new((cx - hw, back,  z))]
        grid.append(ring)

    front_faces = []
    for r in range(rows):
        lo, hi = grid[r], grid[r + 1]
        for i in range(4):
            j = (i + 1) % 4
            f = bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
            if i == 0:                            # the front (face) column
                front_faces.append(f)
    bm.faces.new(grid[0][::-1])                   # chin cap
    bm.faces.new(grid[-1])                        # crown cap
    bm.normal_update()

    uv = bm.loops.layers.uv.verify()
    u0, v0, u1, v1 = cell_uv(face)
    zs = [v.co.z for v in bm.verts]
    xs = [v.co.x for v in bm.verts]
    Z0, Z1 = min(zs), max(zs)
    X0, X1 = min(xs), max(xs)

    for f in bm.faces:
        is_front = f in front_faces
        f.material_index = 1 if is_front else 0
        for lo_ in f.loops:
            c = lo_.vert.co
            if is_front:
                a = (c.x - X0) / (X1 - X0)
                b_ = (c.z - Z0) / (Z1 - Z0)
                lo_[uv].uv = (u0 + a * (u1 - u0), v0 + b_ * (v1 - v0))
            else:
                lo_[uv].uv = (0.02, 0.5)

    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me)
    ob.data.materials.append(skin_mat)     # slot 0
    ob.data.materials.append(face_mat)     # slot 1
    coll.objects.link(ob)
    for p in me.polygons:
        p.use_smooth = True
    _bevel(ob, min(W, H) * 0.10, segs=3)
    es = ob.modifiers.new('EdgeSplit', 'EDGE_SPLIT')
    es.split_angle = math.radians(48)

    ear_objs = []
    if ears:
        ear_z = chin + H * 0.48                   # ear canal height
        sw, sd, _ = _lerp(0.48)
        hw = W / 2 * sw
        for s, p in ((1, 'l'), (-1, 'r')):
            bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=6, radius=1.0,
                                                 location=(cx + s * hw, cy + D * 0.03, ear_z))
            e = bpy.context.active_object
            e.name = f'{name}_ear_{p}'
            e.scale = (0.010, 0.018, 0.030)       # thin, tall, pinned to the skull
            bpy.ops.object.transform_apply(scale=True)
            e.data.materials.append(skin_mat)
            for pf in e.data.polygons:
                pf.use_smooth = True
            for c in list(e.users_collection):
                c.objects.unlink(e)
            coll.objects.link(e)
            ear_objs.append(e)

    return ob, ear_objs


def bind(objs, rig, bone='mixamorig:Head'):
    """Rigid-bind head/ears to the head bone, the method used across this project."""
    for ob in objs:
        ob.vertex_groups.clear()
        vg = ob.vertex_groups.new(name=bone)
        vg.add(range(len(ob.data.vertices)), 1.0, 'REPLACE')
        for m in list(ob.modifiers):
            if m.type == 'ARMATURE':
                ob.modifiers.remove(m)
        ob.modifiers.new('Armature', 'ARMATURE').object = rig
