"""Gore piles - six static world props assembled from the real gib donors.

    blender -b --factory-startup --python tools/gore_piles/build_gore_piles.py -- [--norender] [--only us_small,...]

Stage 1 (donors.py) appends the READ-ONLY character files, evaluates the split grunt_* pieces,
cap_* cross-sections, head_frag_* and headgear into static, faction-scaled meshes. This file
heaps them by hand (LAYOUTS), settles every piece by measurement onto the ground or the pile,
opens a torso, spills viscera, lays the blood pool and the maggot patch, bakes every donor
material into ONE atlas per pile, exports the GLBs + a JSON manifest and renders each pile.

Writes:  assets/world/props/gore_piles.blend            (the studio file, all six piles)
         assets/world/props/gore_piles/<name>.glb        (six GLBs)
         assets/world/props/gore_piles/<name>_atlas.png  (baked atlas per pile)
         assets/world/props/gore_piles/maggots_a.png / maggots_b.png
         assets/world/props/gore_piles/gore_piles_manifest.json
         production/renders_conquest_of_worms/gore_pile_<name>_{4m,1p5m,top}.png
Never touches the donor files. Never opens a window.
"""
import bpy, bmesh, math, os, sys, json, random
from mathutils import Vector, Matrix, Euler

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import donors

ROOT = r"C:\Users\caleb\RECONgame"
OUT_DIR = os.path.join(ROOT, "assets", "world", "props", "gore_piles")
BLEND_OUT = os.path.join(ROOT, "assets", "world", "props", "gore_piles.blend")
RENDER_DIR = os.path.join(ROOT, "production", "renders_conquest_of_worms")
GORE_TEX = os.path.join(ROOT, "assets", "us", "characters", "recovered_gore_tex.png")

BUDGET = {"small": 900, "large": 1800}
ATLAS = {"small": 512, "large": 1024}

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
NORENDER = "--norender" in ARGS
ONLY = None
for a in ARGS:
    if a.startswith("--only"):
        ONLY = a.split("=", 1)[1].split(",") if "=" in a else ARGS[ARGS.index(a) + 1].split(",")

random.seed(7)


def shash(s):
    return sum(ord(c) * (i + 1) for i, c in enumerate(s)) & 0xffff


# ------------------------------------------------------------------ gore sheet cells
# 128x128 sheet, 4x4 wound discs of 32 px. Cell (col,row) with row 0 at the TOP of the image.
def disc_uv(col, row):
    return Vector((0.125 + 0.25 * col, 1.0 - (0.125 + 0.25 * row)))


FIELD_UV = Vector((0.25, 0.75))   # the dark #330808 field where four discs meet
DISC_R = 0.11                     # UV radius that stays inside a disc


# ------------------------------------------------------------------ helpers
def bounds(obj):
    vs = [obj.matrix_world @ v.co for v in obj.data.vertices]
    mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    mx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return mn, mx


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def copy_piece(src, name):
    me = src.data.copy()
    me.name = name
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def apply_xform(obj):
    me = obj.data
    M = obj.matrix_world.copy()
    me.transform(M)
    obj.matrix_world = Matrix.Identity(4)


def ensure_uv(me):
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    return me.uv_layers[0]


def gore_mat():
    m = bpy.data.materials.get("gore_cap_mat")
    if m is None:
        raise RuntimeError("gore_cap_mat did not come across with the US donors")
    return m


def planar_uv_to_disc(bm, faces, uv_lay, centre_uv, radius=DISC_R):
    """Project a set of coplanar-ish faces onto a wound disc: fit the plane from the mean
    normal, map the in-plane offset from the face-set centroid into a circle of `radius`."""
    if not faces:
        return
    n = Vector((0, 0, 0))
    c = Vector((0, 0, 0))
    k = 0
    for f in faces:
        n += f.normal * f.calc_area()
        c += f.calc_center_median()
        k += 1
    c /= k
    if n.length < 1e-9:
        n = Vector((0, 0, 1))
    n.normalize()
    a = Vector((1, 0, 0)) if abs(n.x) < 0.9 else Vector((0, 1, 0))
    u_ax = a.cross(n).normalized()
    v_ax = n.cross(u_ax).normalized()
    ext = 1e-6
    for f in faces:
        for l in f.loops:
            d = l.vert.co - c
            ext = max(ext, abs(d.dot(u_ax)), abs(d.dot(v_ax)))
    for f in faces:
        for l in f.loops:
            d = l.vert.co - c
            l[uv_lay].uv = (centre_uv.x + d.dot(u_ax) / ext * radius,
                            centre_uv.y + d.dot(v_ax) / ext * radius)


def orient_caps_outward(bm, faces, body_centroid):
    for f in faces:
        if f.normal.dot(f.calc_center_median() - body_centroid) < 0:
            f.normal_flip()


def cap_open_boundaries(obj, disc_seed=0):
    """Fill every open boundary loop of a severed piece with a gore cross-section on
    gore_cap_mat, planar-projected onto a wound disc. Returns the number of caps made."""
    me = obj.data
    gm = gore_mat()
    if gm.name not in [m.name for m in me.materials if m]:
        me.materials.append(gm)
    gi = [i for i, m in enumerate(me.materials) if m and m.name == gm.name][0]
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.edges.ensure_lookup_table()
    uv_lay = bm.loops.layers.uv.verify()
    boundary = [e for e in bm.edges if e.is_boundary]
    if not boundary:
        bm.free()
        return 0
    before = set(bm.faces)
    bmesh.ops.holes_fill(bm, edges=boundary, sides=0)
    new = [f for f in bm.faces if f not in before]
    cen = Vector((0, 0, 0))
    for v in bm.verts:
        cen += v.co
    cen /= max(1, len(bm.verts))
    # group new faces by connectivity (one hole -> one cap)
    caps = []
    seen = set()
    for f in new:
        if f in seen:
            continue
        stack, grp = [f], []
        while stack:
            g = stack.pop()
            if g in seen:
                continue
            seen.add(g)
            grp.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h in new and h not in seen:
                        stack.append(h)
        caps.append(grp)
    rnd = random.Random(disc_seed)
    for grp in caps:
        for f in grp:
            f.material_index = gi
        orient_caps_outward(bm, grp, cen)
        planar_uv_to_disc(bm, grp, uv_lay, disc_uv(rnd.randrange(4), rnd.randrange(4)))
    bm.to_mesh(me)
    bm.free()
    return len(caps)


def project_existing_caps(obj, disc_seed=0):
    """Donor caps that came without UVs (the NVA set): give every face a disc projection."""
    me = obj.data
    if me.uv_layers:
        return
    bm = bmesh.new()
    bm.from_mesh(me)
    uv_lay = bm.loops.layers.uv.verify()
    rnd = random.Random(disc_seed)
    # each connected island is one cut
    seen = set()
    for f in bm.faces:
        if f in seen:
            continue
        stack, grp = [f], []
        while stack:
            g = stack.pop()
            if g in seen:
                continue
            seen.add(g)
            grp.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h not in seen:
                        stack.append(h)
        planar_uv_to_disc(bm, grp, uv_lay, disc_uv(rnd.randrange(4), rnd.randrange(4)))
    bm.to_mesh(me)
    bm.free()


def open_torso(obj, depth=0.07):
    """Cut the belly open on a torso that is still in donor space (upright, facing +Y):
    delete the front belly faces and sink a gore pocket behind the hole."""
    me = obj.data
    gm = gore_mat()
    if gm.name not in [m.name for m in me.materials if m]:
        me.materials.append(gm)
    gi = [i for i, m in enumerate(me.materials) if m and m.name == gm.name][0]
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.normal_update()
    uv_lay = bm.loops.layers.uv.verify()
    zs = [v.co.z for v in bm.verts]
    z0, z1 = min(zs), max(zs)
    lo, hi = z0 + 0.14 * (z1 - z0), z0 + 0.50 * (z1 - z0)
    xs = [abs(v.co.x) for v in bm.verts]
    half_w = max(xs)
    doomed = []
    for f in bm.faces:
        c = f.calc_center_median()
        if lo < c.z < hi and abs(c.x) < 0.45 * half_w and f.normal.y > 0.35:
            doomed.append(f)
    if len(doomed) < 2:
        bm.free()
        raise RuntimeError("open_torso found only %d belly faces on %s" % (len(doomed), obj.name))
    bmesh.ops.delete(bm, geom=doomed, context='FACES_ONLY')
    bmesh.ops.delete(bm, geom=[e for e in bm.edges if e.is_wire], context='EDGES')
    rim = [e for e in bm.edges if e.is_boundary and lo - 0.05 < e.verts[0].co.z < hi + 0.05
           and e.verts[0].co.y > -0.02]
    hole_c = Vector((0, 0, 0))
    rim_verts = set()
    for e in rim:
        for v in e.verts:
            rim_verts.add(v)
    for v in rim_verts:
        hole_c += v.co
    hole_c /= max(1, len(rim_verts))
    ext = bmesh.ops.extrude_edge_only(bm, edges=rim)
    new_verts = [g for g in ext["geom"] if isinstance(g, bmesh.types.BMVert)]
    for v in new_verts:
        d = v.co - hole_c
        d.y = 0
        v.co = hole_c + d * 0.55 + Vector((0, -depth, 0))
    wall = [g for g in ext["geom"] if isinstance(g, bmesh.types.BMFace)]
    inner_edges = [e for e in bm.edges if e.is_boundary and e.verts[0] in new_verts and e.verts[1] in new_verts]
    before = set(bm.faces)
    bmesh.ops.holes_fill(bm, edges=inner_edges, sides=0)
    floor = [f for f in bm.faces if f not in before]
    bm.normal_update()
    pocket = wall + floor
    for f in pocket:
        f.material_index = gi
    # pocket faces must look INTO the cavity (toward +Y / the viewer), so flip anything
    # pointing away from the hole centre's outward direction
    for f in pocket:
        if f.normal.y < 0 and f in floor:
            f.normal_flip()
    for f in wall:
        # a wall face faces the pocket axis: its normal should point toward the hole centre
        cc = f.calc_center_median()
        toward = (hole_c + Vector((0, -depth * 0.5, 0))) - cc
        toward.y = 0
        if f.normal.dot(toward) < 0:
            f.normal_flip()
    planar_uv_to_disc(bm, floor, uv_lay, disc_uv(2, 1), DISC_R)
    planar_uv_to_disc(bm, wall, uv_lay, disc_uv(0, 2), DISC_R)
    bm.to_mesh(me)
    bm.free()
    obj["cavity_local"] = list(hole_c + Vector((0, -depth * 0.5, 0)))
    return hole_c


def make_tube(name, pts, radius, sides, mat, uv_cell, samples_per_seg=3, height_fn=None):
    """Low-poly rope along a Catmull-Rom through pts. UVs run u along the length inside a
    horizontal band through one wound disc, v around the ring."""
    def cr(p0, p1, p2, p3, t):
        t2, t3 = t * t, t * t * t
        return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
    P = [Vector(p) for p in pts]
    P = [P[0]] + P + [P[-1]]
    path = []
    for i in range(1, len(P) - 2):
        for s in range(samples_per_seg):
            path.append(cr(P[i - 1], P[i], P[i + 1], P[i + 2], s / samples_per_seg))
    path.append(P[-2])
    if height_fn is not None:
        path = [Vector((q.x, q.y, max(q.z, height_fn(q)))) for q in path]
    bm = bmesh.new()
    uv_lay = bm.loops.layers.uv.verify()
    rings = []
    prev_n = None
    for i, p in enumerate(path):
        t = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        if prev_n is None:
            a = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            n = a.cross(t).normalized()
        else:
            n = (prev_n - t * prev_n.dot(t))
            n = n.normalized() if n.length > 1e-6 else Vector((0, 0, 1)).cross(t).normalized()
        prev_n = n
        b = t.cross(n).normalized()
        ring = []
        for k in range(sides):
            a = 2 * math.pi * k / sides
            ring.append(bm.verts.new(p + n * math.cos(a) * radius + b * math.sin(a) * radius))
        rings.append(ring)
    bm.verts.ensure_lookup_table()
    L = len(rings)
    for i in range(L - 1):
        for k in range(sides):
            v0, v1 = rings[i][k], rings[i][(k + 1) % sides]
            v2, v3 = rings[i + 1][(k + 1) % sides], rings[i + 1][k]
            f = bm.faces.new((v0, v1, v2, v3))
            uu0 = (i / (L - 1))
            uu1 = ((i + 1) / (L - 1))
            # ping-pong across the disc so u never leaves it
            def U(x):
                x = (x * 3.0) % 2.0
                x = x if x < 1.0 else 2.0 - x
                return uv_cell.x - DISC_R * 0.9 + x * DISC_R * 1.8
            vv0 = uv_cell.y - 0.04 + 0.08 * (k / sides)
            vv1 = uv_cell.y - 0.04 + 0.08 * ((k + 1) / sides)
            for l, (uu, vv) in zip(f.loops, ((uu0, vv0), (uu0, vv1), (uu1, vv1), (uu1, vv0))):
                l[uv_lay].uv = (U(uu), vv)
    # end caps
    for ring in (rings[0], rings[-1][::-1]):
        f = bm.faces.new(ring)
        for l in f.loops:
            l[uv_lay].uv = (uv_cell.x, uv_cell.y)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def make_lump(name, centre, size, mat, uv_cell, seed=1):
    """A liver/lung lump: a 6x4 sphere squashed and jittered. ~44 tris."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=6, v_segments=4, radius=1.0)
    rnd = random.Random(seed)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0] / 2, v.co.y * size[1] / 2, v.co.z * size[2] / 2))
        v.co += Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * min(size) * 0.08
    uv_lay = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for l in f.loops:
            d = l.vert.co
            l[uv_lay].uv = (uv_cell.x + d.x / size[0] * DISC_R * 1.6, uv_cell.y + d.y / size[1] * DISC_R * 1.6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.location = Vector(centre)
    return o


def make_pool(name, centre, rx, ry, mat, seed=3):
    """Blood pool decal: a 10-gon, flat on the ground, 6 mm up, UVs pinned to the dark field."""
    bm = bmesh.new()
    uv_lay = bm.loops.layers.uv.verify()
    rnd = random.Random(seed)
    vs = []
    for k in range(10):
        a = 2 * math.pi * k / 10
        r = 1.0 + rnd.uniform(-0.18, 0.18)
        vs.append(bm.verts.new((centre[0] + math.cos(a) * rx * r, centre[1] + math.sin(a) * ry * r, 0.006)))
    f = bm.faces.new(vs)
    cell = disc_uv(0, 1)
    for l in f.loops:
        d = l.vert.co - Vector((centre[0], centre[1], 0))
        l[uv_lay].uv = (cell.x + d.x / rx * 0.118, cell.y + d.y / ry * 0.118)
    if f.normal.z < 0:
        f.normal_flip()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    pm = bpy.data.materials.get("gore_pool_mat")
    if pm is None:
        pm = mat.copy()
        pm.name = "gore_pool_mat"
    me.materials.append(pm)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


# ------------------------------------------------------------------ settling
def support_z_under(point, supports, ground=0.0):
    """Highest surface directly below `point` among `supports` (object-space ray_cast, per
    the ledger), or the ground."""
    best = ground
    # cast from 8 mm ABOVE the point: a ray that starts exactly on the face it is resting on
    # misses that face by rounding, hits the underside and reports "no contact"
    start = point + Vector((0, 0, 0.008))
    for s in supports:
        Mi = s.matrix_world.inverted()
        o = Mi @ start
        d = (Mi.to_3x3() @ Vector((0, 0, -1))).normalized()
        hit, loc, nrm, idx = s.ray_cast(o, d)
        if hit:
            wz = (s.matrix_world @ loc).z
            if wz <= point.z + 0.008 and wz > best:
                best = wz
    return best


def sample_points(obj):
    """World-space verts + edge midpoints + face centres: a limb lying across a curved torso
    can pass THROUGH it between two ring stations, so verts alone are not a contact test."""
    M = obj.matrix_world
    me = obj.data
    pts = [M @ v.co for v in me.vertices]
    for e in me.edges:
        pts.append(M @ ((me.vertices[e.vertices[0]].co + me.vertices[e.vertices[1]].co) * 0.5))
    for f in me.polygons:
        pts.append(M @ f.center)
    return pts


def settle(obj, supports, ground=0.0):
    """Drop (or lift) the piece vertically until its lowest clearance to what is under it is
    zero. Returns (drop, contact_point)."""
    bpy.context.view_layer.update()
    best_gap, best_pt = None, None
    for p in sample_points(obj):
        sz = support_z_under(p, supports, ground)
        gap = p.z - sz
        if best_gap is None or gap < best_gap:
            best_gap, best_pt = gap, p
    obj.location.z -= best_gap
    bpy.context.view_layer.update()
    return best_gap, best_pt


def contacts(obj, supports, ground=0.0, tol=0.006):
    out = []
    for p in sample_points(obj):
        sz = support_z_under(p, supports, ground)
        if p.z - sz <= tol:
            out.append(p)
    return out


def inside_count(obj, supports, tol=0.008):
    """Verts of obj deeper than tol inside any support (bbox-filtered)."""
    n = 0
    amn, amx = bounds(obj)
    for b in supports:
        bmn, bmx = bounds(b)
        if amx.x < bmn.x or bmx.x < amn.x or amx.y < bmn.y or bmx.y < amn.y or amx.z < bmn.z or bmx.z < amn.z:
            continue
        Mi = b.matrix_world.inverted()
        Mn = b.matrix_world.to_3x3().inverted().transposed()
        for v in obj.data.vertices:
            p = obj.matrix_world @ v.co
            if not (bmn.x <= p.x <= bmx.x and bmn.y <= p.y <= bmx.y and bmn.z <= p.z <= bmx.z):
                continue
            hit, loc, nrm, idx = b.closest_point_on_mesh(Mi @ p)
            if hit and (p - (b.matrix_world @ loc)).dot((Mn @ nrm).normalized()) < -tol:
                n += 1
    return n


def tilt_settle(obj, supports, ground=0.0, max_deg=35.0, step_deg=2.5):
    """A piece dropped onto a heap touches at one point and would rotate about it until a
    second point lands. Rotate about the horizontal axis through the contact, in the sense
    that lowers the centroid, re-dropping each step, until the contacts span >= 12 cm or
    the tilt limit is hit. Returns degrees tilted."""
    bpy.context.view_layer.update()
    tilted = 0.0
    while tilted < max_deg:
        cs = contacts(obj, supports, ground)
        if len(cs) >= 2:
            spread = max((a - b).length for a in cs for b in cs)
            if spread > 0.12:
                break
        c = cs[0] if cs else None
        if c is None:
            break
        M = obj.matrix_world
        cen = sum((M @ v.co for v in obj.data.vertices), Vector()) / len(obj.data.vertices)
        lever = cen - c
        lever.z = 0
        if lever.length < 0.02:
            break
        axis = Vector((0, 0, 1)).cross(lever).normalized()
        # rotating about `axis` through c by +angle lowers the centroid when the axis is
        # chosen as up x lever (right-hand rule): check numerically and flip if not
        R = Matrix.Rotation(math.radians(step_deg), 4, axis)
        T = Matrix.Translation(c)
        new_cen = T @ R @ T.inverted() @ cen
        if new_cen.z > cen.z:
            R = Matrix.Rotation(math.radians(-step_deg), 4, axis)
        before = inside_count(obj, supports)
        loc_before = obj.location.copy()
        obj.matrix_world = T @ R @ T.inverted() @ M
        bpy.context.view_layer.update()
        settle(obj, supports, ground)
        if inside_count(obj, supports) > before:
            # the swing pushed the piece INTO a neighbour: undo and stop here
            obj.matrix_world = M
            obj.location = loc_before
            bpy.context.view_layer.update()
            break
        tilted += step_deg
    return tilted


def place(src, name, rot_deg, at, supports, ground=0.0, z_bias=0.0, tilt=True):
    o = copy_piece(src, name)
    o.rotation_euler = Euler([math.radians(a) for a in rot_deg], 'XYZ')
    o.location = Vector((at[0], at[1], 1.0))
    bpy.context.view_layer.update()
    drop, pt = settle(o, supports, ground)
    compact = any(t in name for t in ("torso", "head", "hat"))
    deg = tilt_settle(o, supports, ground, max_deg=(22.0 if compact else 35.0)) if (tilt and supports) else 0.0
    drop, pt = settle(o, supports, ground)
    o.location.z += z_bias
    bpy.context.view_layer.update()
    o["contact"] = list(pt)
    o["tilted_deg"] = deg
    o["contacts"] = len(contacts(o, supports, ground))
    if "donor_key" in src:
        o["donor_key"] = src["donor_key"]
    return o


# ------------------------------------------------------------------ layouts
# Each entry: (donor key, rotation XYZ degrees applied to the upright +Y-facing donor, (x, y),
#              settle-on: "ground" | "pile", z_bias)
# Rotation cheat sheet (donor is upright, faces +Y, head at +Z):
#   torso on its BACK, head toward -Y   : (90, 0, yaw)
#   torso FACE DOWN, head toward +Y     : (-90, 0, yaw)
#   torso on its SIDE (right side down) : (0, 90, yaw)
#   a leg lying along the ground        : (90, 0, yaw)  foot toward +Y... then yaw
#   a head resting on its side          : (0, 90, yaw) / (0,-90,yaw); back of skull down (90,0,yaw)
# Donor frames: torso/head/legs are upright (long axis Z, face +Y). ARMS ARE T-POSE: their
# long axis is X, so an arm lies flat with Rx/Rz only and Ry stands it on end.
#   torso on its BACK, head toward -Y   : (90, 0, yaw)
#   torso FACE DOWN, head toward +Y     : (-90, 0, yaw)
#   torso on its SIDE                   : (0, +-90, yaw)
#   leg lying flat                      : (90, 0, yaw)   (knee bend then points DOWN: use (-90,..) for knee up)
#   head on its side                    : (0, +-90, yaw); face up (90,0,yaw); face down (-90,0,yaw)
#   arm lying flat, palm up/down        : (rx, 0, yaw)
# Order is build order: ground layer first, then what lies on it.
def _L(faction, size):
    F = faction
    hat = F + "_hat"
    if size == "small":
        return {
            "men": 2,
            "torso": (F + "_torso_straight", (90, 0, 12), (0.0, 0.0), "pile", 0.0),
            "parts": [
                (F + "_leg_r_straight", (90, 0, 100), (0.02, 0.20), "ground", 0.0),
                (F + "_leg_l_straight", (90, 0, 75), (0.06, -0.24), "ground", 0.0),
                (F + "_leg_l_bent", (-90, 0, 200), (0.48, 0.05), "ground", 0.0),
                (F + "_forearm_r_bent", (200, 0, 35), (-0.46, -0.18), "ground", 0.0),
                (F + "_uparm_r_straight", (30, 0, 250), (-0.15, -0.50), "ground", 0.0),
                (F + "_head_straight", (0, 90, 30), (-0.44, 0.22), "ground", 0.0),
                (hat, (180, 15, 60), (0.42, -0.42), "ground", 0.0),
                ("TORSO", None, None, None, None),
                (F + "_forearm_l_straight", (160, 0, 300), (0.04, -0.16), "pile", 0.0),
                (F + "_forearm_l_bent", (20, 0, 120), (0.30, 0.18), "pile", 0.0),
            ],
            "pool": 0.42,
        }
    return {
        "men": 5,
        "torso": (F + "_torso_straight", (90, 0, 8), (0.0, 0.0), "pile", 0.0),
        "parts": [
            (F + "_torso_straight", (-90, 0, 235), (-0.42, 0.42), "ground", 0.0),
            (F + "_torso_straight", (0, 90, 290), (0.55, -0.15), "ground", 0.0),
            (F + "_leg_r_straight", (90, 0, 100), (0.02, 0.20), "ground", 0.0),
            (F + "_leg_l_straight", (90, 0, 75), (0.06, -0.24), "ground", 0.0),
            (F + "_leg_l_bent", (-90, 0, 200), (0.50, 0.30), "ground", 0.0),
            (F + "_leg_r_bent", (-90, 0, 15), (-0.60, -0.15), "ground", 0.0),
            (F + "_leg_l_straight", (90, 0, 150), (-0.10, 0.62), "ground", 0.0),
            (F + "_forearm_r_bent", (200, 0, 35), (-0.46, -0.30), "ground", 0.0),
            (F + "_forearm_r_straight", (0, 0, 140), (0.30, -0.62), "ground", 0.0),
            (F + "_uparm_r_straight", (30, 0, 250), (-0.15, -0.55), "ground", 0.0),
            (F + "_uparm_l_straight", (0, 0, 160), (0.62, 0.55), "ground", 0.0),
            (F + "_head_straight", (0, 90, 30), (-0.50, 0.05), "ground", 0.0),
            (hat, (180, 15, 60), (0.40, -0.48), "ground", 0.0),
            (hat, (0, 0, 200), (-0.72, 0.50), "ground", 0.0),
            ("TORSO", None, None, None, None),
            (F + "_forearm_l_straight", (160, 0, 300), (0.04, -0.16), "pile", 0.0),
            (F + "_forearm_l_bent", (20, 0, 120), (0.32, 0.20), "pile", 0.0),
            (F + "_forearm_r_bent", (0, 0, 60), (-0.35, 0.50), "pile", 0.0),
            (F + "_uparm_r_straight", (0, 0, 85), (0.55, -0.35), "pile", 0.0),
            (F + "_head_straight", (90, 0, 190), (-0.28, -0.42), "pile", 0.0),
        ],
        "pool": 0.40,
    }


LAYOUTS = {"%s_%s" % (f, sz): _L(f, sz) for f in ("us", "nva", "vc") for sz in ("small", "large")}
# guts spill side (+X or -X of the hero torso)
for k in LAYOUTS:
    LAYOUTS[k]["guts_side"] = 1
# the NVA head frags dress the NVA piles
LAYOUTS["nva_small"]["parts"].append(("nva_headfrag_02", (90, 0, 140), (0.38, -0.30), "ground", 0.0))
LAYOUTS["nva_small"]["parts"] = [e for e in LAYOUTS["nva_small"]["parts"] if e[0] not in ("nva_forearm_l_bent", "nva_uparm_r_straight")]
LAYOUTS["nva_large"]["parts"] += [("nva_headfrag_02", (90, 0, 140), (0.20, -0.75), "ground", 0.0),
                                  ("nva_headfrag_05", (0, 0, 20), (0.75, 0.10), "ground", 0.0),
                                  ("nva_headfrag_07", (180, 0, 260), (-0.30, 0.78), "ground", 0.0)]


def cap_key_for(donor_key):
    """us_leg_l_bent -> us_cap_leg_l_bent (US: all 8; NVA: limbs+head, no torso; VC: none)."""
    f, rest = donor_key.split("_", 1)
    if rest.startswith("hat") or rest.startswith("headfrag"):
        return None
    ck = "%s_cap_%s" % (f, rest)
    return ck


# ------------------------------------------------------------------ maggot frames
def write_maggot_frames():
    """64x64, two frames: pale writhing specks on a wet dark field. Colours are pulled off
    the gore sheet itself (its darkest field and its palest fat/bone pixels), no new palette."""
    src = bpy.data.images.load(GORE_TEX, check_existing=True)
    px = list(src.pixels)
    w, h = src.size
    dark = None
    pale = None
    for i in range(0, len(px), 4):
        r, g, b = px[i], px[i + 1], px[i + 2]
        l = 0.2126 * r + 0.7152 * g + 0.0722 * b
        if dark is None or l < dark[0]:
            dark = (l, r, g, b)
        if pale is None or l > pale[0]:
            pale = (l, r, g, b)
    # the field between the discs (sheet corner texel) is the wet base, not the darkest pixel
    d = Vector((px[0], px[1], px[2]))
    p = Vector(pale[1:])
    outs = []
    rnd = random.Random(11)
    specks = [(rnd.uniform(2, 62), rnd.uniform(2, 62), rnd.uniform(0, math.pi), rnd.uniform(2.5, 4.0)) for _ in range(110)]
    for frame in range(2):
        img = bpy.data.images.new("maggots_%s" % "ab"[frame], 64, 64, alpha=False)
        buf = [0.0] * (64 * 64 * 4)
        for y in range(64):
            for x in range(64):
                n = rnd.uniform(0.85, 1.15)
                c = d * n
                i = (y * 64 + x) * 4
                buf[i:i + 3] = (min(1, c.x), min(1, c.y), min(1, c.z))
                buf[i + 3] = 1.0
        for (sx, sy, a, ln) in specks:
            # a maggot is a 1-px-wide pale grain ~3 px long that wriggles between frames
            a2 = a + (0.9 if frame else 0.0) + rnd.uniform(-0.2, 0.2)
            ox = 1.0 if frame else 0.0
            for s in range(int(ln * 2)):
                t = s / 2.0 - ln / 2
                for side in (0.0, 0.7):
                    x = int(sx + ox + math.cos(a2) * t - math.sin(a2) * side) % 64
                    y = int(sy + math.sin(a2) * t + math.cos(a2) * side) % 64
                    i = (y * 64 + x) * 4
                    k = (0.85 + 0.15 * math.cos(t)) * (1.0 if side == 0.0 else 0.8)
                    buf[i:i + 3] = (p.x * k, p.y * k * 0.95, p.z * k * 0.9)
        img.pixels = buf
        path = os.path.join(OUT_DIR, "maggots_%s.png" % "ab"[frame])
        img.filepath_raw = path
        img.file_format = 'PNG'
        img.save_render(path)
        outs.append(path)
    return outs


def maggot_material():
    m = bpy.data.materials.get("gore_pile_maggots")
    if m:
        return m
    m = bpy.data.materials.new("gore_pile_maggots")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.7
    bsdf.inputs["Specular IOR Level"].default_value = 0.0
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(os.path.join(OUT_DIR, "maggots_a.png"), check_existing=True)
    tex.interpolation = 'Closest'
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return m


def make_maggot_patch(name, centre, size, normal_hint=Vector((0, 0, 1))):
    """A 3x2 grid strip laid over the cavity, 6 mm proud of it. UV 0..1 = one frame."""
    bm = bmesh.new()
    uv_lay = bm.loops.layers.uv.verify()
    nx, ny = 3, 2
    grid = []
    for j in range(ny + 1):
        row = []
        for i in range(nx + 1):
            x = (i / nx - 0.5) * size[0]
            y = (j / ny - 0.5) * size[1]
            z = 0.012 * (1 - ((2 * i / nx - 1) ** 2 + (2 * j / ny - 1) ** 2) / 2)  # slight dome
            row.append(bm.verts.new((x, y, z)))
        grid.append(row)
    for j in range(ny):
        for i in range(nx):
            f = bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
            for l, (u, v) in zip(f.loops, ((i / nx, j / ny), ((i + 1) / nx, j / ny), ((i + 1) / nx, (j + 1) / ny), (i / nx, (j + 1) / ny))):
                l[uv_lay].uv = (u, v)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(maggot_material())
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.location = Vector(centre)
    z = Vector((0, 0, 1))
    n = normal_hint.normalized()
    o.rotation_euler = z.rotation_difference(n).to_euler()
    return o


# ------------------------------------------------------------------ pile assembly
def build_pile(key, lib):
    L = LAYOUTS[key]
    faction, size = key.split("_")
    bpy.context.view_layer.update()
    placed = []
    gm = gore_mat()

    torso = None
    parts = []
    for i, (dk, rot, at, on, zb) in enumerate(L["parts"]):
        if dk == "TORSO":
            tsrc = copy_piece(lib[L["torso"][0]], "tmp_torso_src")
            tsrc["donor_key"] = L["torso"][0]
            open_torso(tsrc)
            torso = place(tsrc, "%s_torso_open" % key, L["torso"][1], L["torso"][2], placed, 0.0, L["torso"][4])
            torso["cavity_local"] = list(tsrc["cavity_local"])
            bpy.data.objects.remove(tsrc, do_unlink=True)
            placed.append(torso)
            continue
        o = place(lib[dk], "%s_p%02d_%s" % (key, i, dk), rot, at, placed, 0.0, zb)
        placed.append(o)
        parts.append(o)
    if torso is None:
        raise RuntimeError("layout %s has no TORSO entry" % key)

    # every severed piece gets its cross-section: the donor cap where one exists, else the
    # open boundary loops are filled and projected onto a wound disc
    # The rig-bound cap_* donors are quads that sit INSIDE the skin at a bone and only look
    # right on a collapsed limb; on a static severed piece they read as floating panes
    # (measured: us cap_uparm_l is 2 polys spanning 0.345 m). The cross-section here is the
    # piece's own open boundary loop, filled and projected onto a wound disc of the same
    # gore_cap_mat sheet.
    caps = []
    for tgt in [torso] + parts:
        if cap_key_for(tgt["donor_key"]) is not None:
            tgt["gen_caps"] = cap_open_boundaries(tgt, disc_seed=shash(tgt.name))

    # viscera: intestine rope spilling from the cavity, liver lump beside it
    bpy.context.view_layer.update()
    cav = torso.matrix_world @ Vector(torso["cavity_local"])
    side = L["guts_side"]
    tmn, tmx = bounds(torso)
    rope_r = 0.03 if size == "small" else 0.034
    sides = 4 if size == "small" else 5
    R3 = torso.matrix_world.to_3x3()
    sidev = (R3 @ Vector((side, 0, 0))).normalized()   # over this edge of the torso
    fwd = -(R3 @ Vector((0, 0, 1))).normalized()          # toward the feet
    fwd.z = 0
    fwd.normalize()
    g = lambda a, b, z: Vector((cav.x, cav.y, 0)) + sidev * a + fwd * b + Vector((0, 0, z))
    pts = [
        cav + Vector((0, 0, -0.01)),
        Vector((cav.x, cav.y, cav.z)) + sidev * 0.07 + Vector((0, 0, 0.035)),
        Vector((cav.x, cav.y, cav.z)) + sidev * 0.17 + Vector((0, 0, 0.0)),
        g(0.28, 0.06, 0.05), g(0.40, 0.00, 0.034), g(0.44, -0.14, 0.034), g(0.34, -0.26, 0.034),
        g(0.22, -0.18, 0.07), g(0.30, -0.02, 0.075), g(0.42, 0.10, 0.034), g(0.54, 0.18, 0.034),
        g(0.62, 0.06, 0.034), g(0.56, -0.08, 0.07), g(0.46, 0.00, 0.10),
    ]
    if size == "small":
        pts = pts[:-2]
    # drape: every sampled point of the rope rides over whatever is already there, except
    # the first three (inside the cavity and over the torso's own edge)
    cav_xy = Vector((cav.x, cav.y, 0))
    def drape(q):
        if (Vector((q.x, q.y, 0)) - cav_xy).length < 0.16:
            return q.z
        return support_z_under(Vector((q.x, q.y, 3.0)), [o for o in placed if o is not torso], 0.0) + rope_r + 0.004
    guts = make_tube("%s_guts" % key, pts, rope_r, sides, gm, disc_uv(2, 2), samples_per_seg=2, height_fn=drape)
    for v in guts.data.vertices:          # a rope on the ground is flattened, not buried
        if v.co.z < 0.004:
            v.co.z = 0.004
    guts_rings_over_ground = None
    lv = g(0.30, -0.36, 0.0)
    liver = make_lump("%s_liver" % key, (lv.x, lv.y, 0.0), (0.20, 0.14, 0.09), gm, disc_uv(0, 1))
    settle(liver, [], 0.0)
    placed += [guts, liver]

    # blood pool under everything, slightly larger than the footprint
    mn, mx = bounds(torso)
    for o in parts:
        a, b = bounds(o)
        mn = Vector((min(mn.x, a.x), min(mn.y, a.y), min(mn.z, a.z)))
        mx = Vector((max(mx.x, b.x), max(mx.y, b.y), max(mx.z, b.z)))
    pf = L["pool"]
    pool = make_pool("%s_pool" % key, ((mn.x + mx.x) / 2, (mn.y + mx.y) / 2), (mx.x - mn.x) * pf, (mx.y - mn.y) * pf, gm)

    # maggot patch over the wettest cavity + fx anchors
    up = (torso.matrix_world.to_3x3() @ Vector((0, 1, 0))).normalized()  # donor +Y = belly out
    mag = make_maggot_patch("%s_maggot_mass" % key, cav + up * 0.02, (0.16, 0.11), up)
    anchors = []
    for i, off in enumerate([Vector((0, 0, 0)), Vector((0.10 * side, 0.05, -0.02)), Vector((0.05 * side, -0.16, -0.06))]):
        e = bpy.data.objects.new("%s_fx_maggots_%02d" % (key, i + 1), None)
        e.empty_display_type = 'SPHERE'
        e.empty_display_size = 0.04
        e.location = cav + off
        bpy.context.scene.collection.objects.link(e)
        anchors.append(e)
    fl = bpy.data.objects.new("%s_fx_flies_01" % key, None)
    fl.empty_display_type = 'SPHERE'
    fl.empty_display_size = 0.06
    fl.location = cav + Vector((0, 0, 0.25))
    bpy.context.scene.collection.objects.link(fl)
    anchors.append(fl)

    return {"torso": torso, "parts": parts, "caps": caps, "guts": guts, "liver": liver,
            "pool": pool, "maggots": mag, "anchors": anchors, "cavity": cav}


def attach_caps(pile, lib, key):
    """Donor caps are baked in the same donor pose as their limb, so the cap sits on the limb
    by applying the limb's world matrix to the cap's donor-space geometry."""
    out = []
    for c, tgt, capkey in pile["caps"]:
        src_piece = lib[tgt["donor_key"]]
        # donor-space of the piece: piece verts are (world_donor - piece_centre); the cap verts
        # are (world_donor - cap_centre). Shift by (cap_centre - piece_centre), then apply the
        # piece's placed matrix. Centres were recorded before the library was parked.
        delta = Vector(lib[capkey]["donor_centre"]) - Vector(src_piece["donor_centre"])
        c.data.transform(Matrix.Translation(delta))
        c.matrix_world = tgt.matrix_world.copy()
        c.parent = None
        out.append(c)
    pile["cap_objs"] = out
    return out


# ------------------------------------------------------------------ join + bake
def join_objects(objs, name):
    # bmesh-made meshes name their UV layer 'Float2' in 5.0, the donors say 'UVMap'; join()
    # merges UV layers BY NAME, so without this the generated parts land in a second layer
    # and bake as (0,0). One layer, one name, before the join.
    for o in objs:
        me = o.data
        while len(me.uv_layers) > 1:
            me.uv_layers.remove(me.uv_layers[-1])
        if not me.uv_layers:
            me.uv_layers.new(name="UVMap")
        me.uv_layers[0].name = "UVMap"
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    j = bpy.context.view_layer.objects.active
    j.name = name
    j.data.name = name
    apply_xform(j)
    return j


def clean_mesh(obj):
    """Doubles, loose geometry, degenerate faces; triangulate so the tri count we gate is
    the count that ships."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=0.0005)
    bmesh.ops.delete(bm, geom=[e for e in bm.edges if e.is_wire], context='EDGES')
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context='VERTS')
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method='BEAUTY', ngon_method='BEAUTY')
    # zero-area triangles: the glTF exporter silently drops them, so a count gated here would
    # disagree with the count that ships. Kill them at source.
    zero = [f for f in bm.faces if f.calc_area() < 1e-7]
    # duplicate faces (same three verts, either winding): holes_fill on a boundary loop that a
    # neighbouring fill already closed. The exporter drops them silently; count them here.
    seen = set()
    for f in bm.faces:
        k = tuple(sorted(v.index for v in f.verts))
        if k in seen:
            zero.append(f)
        seen.add(k)
    bmesh.ops.delete(bm, geom=list(set(zero)), context='FACES')
    bmesh.ops.delete(bm, geom=[e for e in bm.edges if e.is_wire], context='EDGES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def bake_atlas(obj, key, res):
    """Bake every donor material's diffuse colour into one atlas over a fresh UV layer, then
    swap the object onto a single Closest-sampled material."""
    me = obj.data
    src_uv = me.uv_layers[0]
    src_uv.name = "donor_uv"
    atlas_uv = me.uv_layers.new(name="atlas_uv")
    src_uv.active_render = True       # image nodes without a UV input sample THIS one
    me.uv_layers.active_index = me.uv_layers.find("atlas_uv")   # bake target

    for o in bpy.context.scene.objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    # the pool is one flat colour: keep it off the packer so it cannot eat 40% of the sheet
    pool_faces = set()
    pi = [i for i, m in enumerate(me.materials) if m and m.name == "gore_pool_mat"]
    for p in me.polygons:
        if p.material_index in pi:
            pool_faces.add(p.index)
    for p in me.polygons:
        p.select = p.index not in pool_faces
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.012, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    try:
        bpy.ops.uv.pack_islands(rotate=True, margin=0.01)
    except Exception as ex:
        print("[gore] pack_islands skipped:", ex)
    bpy.ops.object.mode_set(mode='OBJECT')
    auv = me.uv_layers["atlas_uv"].data
    for p in me.polygons:
        for li in p.loop_indices:
            u, v = auv[li].uv
            if p.index in pool_faces:
                # the pool keeps its disc projection, scaled into the top-right corner
                du = me.uv_layers["donor_uv"].data[li].uv
                cell = disc_uv(0, 1)
                auv[li].uv = (0.88 + (du.x - cell.x) / 0.118 * 0.115, 0.88 + (du.y - cell.y) / 0.118 * 0.115)
            else:
                auv[li].uv = (u * 0.76, v * 0.76)
    for p in me.polygons:
        p.select = False

    img = bpy.data.images.new("%s_atlas" % key, res, res, alpha=False)
    img.generated_color = (0.2, 0.03, 0.03, 1)
    nodes_added = []
    for slot in obj.material_slots:
        m = slot.material
        if m is None:
            continue
        if not m.use_nodes:
            m.use_nodes = True
        nt = m.node_tree
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.name = "BAKE_TARGET"
        nt.nodes.active = tex
        nodes_added.append((nt, tex))

    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 16
    sc.cycles.use_denoising = False
    sc.render.bake.use_pass_direct = False
    sc.render.bake.use_pass_indirect = False
    sc.render.bake.use_pass_color = True
    sc.render.bake.margin = 6
    sc.render.bake.use_clear = True
    bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, use_selected_to_active=False, margin=6)

    path = os.path.join(OUT_DIR, "%s_atlas.png" % key)
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    for nt, tex in nodes_added:
        nt.nodes.remove(tex)

    # one material
    mat = bpy.data.materials.new("%s_mat" % key)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Specular IOR Level"].default_value = 0.0
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    img2 = bpy.data.images.load(path, check_existing=False)
    img2.name = "%s_atlas_disk" % key
    tex.image = img2
    tex.interpolation = 'Closest'
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    me.materials.clear()
    me.materials.append(mat)
    for p in me.polygons:
        p.material_index = 0
    me.uv_layers.remove(me.uv_layers["donor_uv"])
    me.uv_layers["atlas_uv"].active_render = True
    bpy.data.images.remove(img)
    return path


def make_hull(obj, name):
    """Low convex hull as the -colonly collider: what a bullet asks 'soft or hard' of."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    res = bmesh.ops.convex_hull(bm, input=bm.verts)
    interior = [g for g in res["geom_interior"] if isinstance(g, bmesh.types.BMVert)]
    unused = [g for g in res["geom_unused"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.delete(bm, geom=interior + unused, context='VERTS')
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(18), verts=bm.verts, edges=bm.edges)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


# ------------------------------------------------------------------ gates
def gate_pile(key, mesh_obj, pieces, budget):
    report = {"tris": tri_count(mesh_obj), "budget": budget, "pieces": []}
    ok = report["tris"] <= budget
    for o in pieces:
        mn, mx = bounds(o)
        report["pieces"].append({"name": o.name, "min_z": round(mn.z, 4), "contact": [round(v, 3) for v in o.get("contact", (0, 0, 0))]})
        if mn.z < -0.002:
            ok = False
            report.setdefault("ground_violations", []).append(o.name)
    mn, mx = bounds(mesh_obj)
    report["footprint_m"] = [round(mx.x - mn.x, 3), round(mx.y - mn.y, 3)]
    report["height_m"] = round(mx.z - mn.z, 3)
    report["bbox_min"] = [round(v, 3) for v in mn]
    report["bbox_max"] = [round(v, 3) for v in mx]
    report["ok"] = ok
    return report


def penetration_report(pieces):
    """For every vertex of every piece, distance to the nearest other piece surface; count
    the ones that sit INSIDE another piece by more than 8 mm (proximity-filtered: only pairs
    whose bboxes overlap are tested)."""
    dg = bpy.context.evaluated_depsgraph_get()
    worst = 0.0
    inside = 0
    tested = 0
    pairs = {}
    bbs = {o.name: bounds(o) for o in pieces}
    for a in pieces:
        amn, amx = bbs[a.name]
        for b in pieces:
            if a is b:
                continue
            bmn, bmx = bbs[b.name]
            if amx.x < bmn.x or bmx.x < amn.x or amx.y < bmn.y or bmx.y < amn.y or amx.z < bmn.z or bmx.z < amn.z:
                continue
            Mi = b.matrix_world.inverted()
            Mn = b.matrix_world.to_3x3().inverted().transposed()
            for v in a.data.vertices:
                p = a.matrix_world @ v.co
                if not (bmn.x <= p.x <= bmx.x and bmn.y <= p.y <= bmx.y and bmn.z <= p.z <= bmx.z):
                    continue
                tested += 1
                hit, loc, nrm, idx = b.closest_point_on_mesh(Mi @ p)
                if not hit:
                    continue
                wl = b.matrix_world @ loc
                wn = (Mn @ nrm).normalized()
                d = (p - wl).dot(wn)
                if d < -0.008:
                    inside += 1
                    worst = min(worst, d)
                    n, w = pairs.get((a.name, b.name), (0, 0.0))
                    pairs[(a.name, b.name)] = (n + 1, min(w, d))
    top = sorted(pairs.items(), key=lambda kv: -kv[1][0])[:5]
    return {"verts_tested": tested, "verts_inside_gt_8mm": inside, "worst_m": round(worst, 4),
            "worst_pairs": [(a_, b_, n, round(w, 3)) for (a_, b_), (n, w) in top]}


# ------------------------------------------------------------------ render
def render_pile(key, objs, centre, extent):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sh = sc.display.shading
    sh.light = 'STUDIO'
    sh.color_type = 'TEXTURE'
    sh.show_shadows = True
    sh.shadow_intensity = 0.35
    sh.show_cavity = False
    sc.display.render_aa = 'FXAA'
    sc.render.resolution_x = 900
    sc.render.resolution_y = 700
    sc.render.film_transparent = False
    sc.world = sc.world or bpy.data.worlds.new("w")
    sc.world.color = (0.35, 0.36, 0.30)
    # ground plane in a dirt colour
    ground = bpy.data.objects.get("_render_ground")
    if ground is None:
        me = bpy.data.meshes.new("_render_ground")
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=6.0)
        bm.to_mesh(me)
        bm.free()
        ground = bpy.data.objects.new("_render_ground", me)
        gmat = bpy.data.materials.new("_ground_mat")
        gmat.diffuse_color = (0.30, 0.24, 0.16, 1)
        me.materials.append(gmat)
        bpy.context.scene.collection.objects.link(ground)
    ground.location = (centre.x, centre.y, -0.001)
    for o in sc.objects:
        o.hide_render = not (o in objs or o is ground)
    cam = bpy.data.objects.get("_render_cam")
    if cam is None:
        cam = bpy.data.objects.new("_render_cam", bpy.data.cameras.new("_render_cam"))
        bpy.context.scene.collection.objects.link(cam)
    sc.camera = cam
    cam.data.lens = 35
    look = Vector((centre.x, centre.y, 0.12))
    views = {
        "4m": Vector((centre.x + 1.4, centre.y - 3.75, 1.6)),
        "1p5m": Vector((centre.x + 1.15, centre.y - 0.95, 1.6)),
        "top": Vector((centre.x + 0.01, centre.y - 0.01, 1.6 + extent * 0.9)),
    }
    outs = []
    for tag, pos in views.items():
        cam.location = pos
        d = look - pos
        cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
        if tag == "1p5m":
            cam.data.lens = 32
        elif tag == "top":
            cam.data.lens = 30
        else:
            cam.data.lens = 40
        path = os.path.join(RENDER_DIR, "gore_pile_%s_%s.png" % (key, tag))
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        outs.append(path)
    for o in sc.objects:
        o.hide_render = False
    ground.hide_render = True
    ground.hide_viewport = True
    return outs


# ------------------------------------------------------------------ export
def export_glb(key, mesh_obj, maggots, hull, anchors):
    for o in bpy.context.scene.objects:
        o.select_set(False)
    sel = [mesh_obj, maggots, hull] + anchors
    # bare engine names for the export only; the studio file keeps them unique per pile
    saved = [(o, o.name) for o in sel]
    maggots.name = "maggot_mass"
    maggots.data.name = "maggot_mass"
    for a in anchors:
        a.name = "fx_" + a.name.split("_fx_", 1)[1]
    for o in sel:
        o.select_set(True)
    bpy.context.view_layer.objects.active = mesh_obj
    path = os.path.join(OUT_DIR, "%s.glb" % key)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True, export_materials='EXPORT',
                              export_animations=False, export_cameras=False, export_lights=False,
                              export_image_format='AUTO', export_texcoords=True, export_normals=True,
                              export_extras=False)
    for o in sel:
        o.select_set(False)
    for o, n in saved:
        o.name = n
    return path


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(RENDER_DIR, exist_ok=True)
    donors.clear_scene()
    lib = donors.extract_all()
    for k, o in lib.items():
        o["donor_key"] = k
        o["donor_centre"] = list(o.location)
    # NVA donor caps came with no UVs: project them onto discs
    for k, o in lib.items():
        if "_cap_" in k and not o.data.uv_layers:
            project_existing_caps(o, disc_seed=shash(k))
    # park the library well away from the piles
    for i, (k, o) in enumerate(sorted(lib.items())):
        o.location = Vector((40.0 + (i % 12) * 1.2, 40.0 + (i // 12) * 2.5, o.location.z))
        o.hide_render = True
    write_maggot_frames()
    # the M1 cover donor is 204 tris - a quarter of a small pile. Limited dissolve keeps its
    # UVs and silhouette; the count is gated below.
    hat = lib["us_hat"]
    md = hat.modifiers.new("dec", 'DECIMATE')
    md.decimate_type = 'COLLAPSE'
    md.ratio = 0.38
    md.use_collapse_triangulate = True
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    hm = hat.evaluated_get(dg).to_mesh()
    nm = bpy.data.meshes.new("us_hat_dec")
    hb = bmesh.new()
    hb.from_mesh(hm)
    hb.to_mesh(nm)
    hb.free()
    for mt in hat.data.materials:
        nm.materials.append(mt.original if mt else None)
    hat.evaluated_get(dg).to_mesh_clear()
    hat.modifiers.remove(md)
    old = hat.data
    hat.data = nm
    bpy.data.meshes.remove(old)
    print("[gore] us_hat decimated to %d tris" % tri_count(lib["us_hat"]), flush=True)

    manifest = {"contract": {}, "piles": {}}
    keys = [k for k in LAYOUTS if (ONLY is None or k in ONLY)]
    slot = 0
    for key in keys:
        faction, size = key.split("_")
        budget = BUDGET[size]
        origin = Vector((slot * 6.0, 0.0, 0.0))
        slot += 1
        pile = build_pile(key, lib)
        attach_caps(pile, lib, key)

        pieces = [pile["torso"]] + pile["parts"] + pile["cap_objs"] + [pile["guts"], pile["liver"]]
        pen = penetration_report([pile["torso"]] + pile["parts"] + [pile["guts"], pile["liver"]])
        ground_gate = []
        for o in [pile["torso"]] + pile["parts"] + [pile["guts"], pile["liver"], pile["pool"]]:
            mn, mx = bounds(o)
            ground_gate.append((o.name, round(mn.z, 4), o.get("tilted_deg", 0.0), o.get("contacts", 0)))

        NAME = "gore_pile_" + key
        mesh = join_objects(pieces + [pile["pool"]], NAME)
        clean_mesh(mesh)
        mag = pile["maggots"]
        clean_mesh(mag)
        # world-prop convention (medical_crate / m26_grenade): ground contact at z=0 and the
        # footprint centred on the origin in XY
        mn, mx = bounds(mesh)
        shift = Vector((-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, 0.0))
        mesh.data.transform(Matrix.Translation(shift))
        mesh.data.update()
        for o in [mag] + pile["anchors"]:
            o.location += shift
        pile["cavity"] = pile["cavity"] + shift
        bpy.context.view_layer.update()
        tris = tri_count(mesh)
        hull = make_hull(mesh, "%s_000-colonly" % NAME)
        atlas = bake_atlas(mesh, NAME, ATLAS[size])

        rep = gate_pile(key, mesh, [mesh], budget)
        # move the whole pile onto its slot in the studio file
        for o in [mesh, mag, hull] + pile["anchors"]:
            o.location += origin
        bpy.context.view_layer.update()

        rep["ground_gate"] = ground_gate
        rep["penetration"] = pen
        rep["tris_maggots"] = tri_count(mag)
        rep["tris_collider"] = tri_count(hull)
        rep["atlas"] = os.path.basename(atlas)
        rep["atlas_res"] = ATLAS[size]
        rep["men_worth"] = LAYOUTS[key]["men"]
        rep["anchors"] = {"fx_" + a.name.split("_fx_", 1)[1]: [round(v, 3) for v in (a.location - origin)] for a in pile["anchors"]}
        rep["cavity"] = [round(v, 3) for v in pile["cavity"]]

        # export from the origin: temporarily shift back
        for o in [mesh, mag, hull] + pile["anchors"]:
            o.location -= origin
        bpy.context.view_layer.update()
        glb = export_glb(NAME, mesh, mag, hull, pile["anchors"])
        rep["glb"] = os.path.relpath(glb, ROOT).replace("\\", "/")
        rep["glb_bytes"] = os.path.getsize(glb)
        if not NORENDER:
            mn, mx = bounds(mesh)
            rep["renders"] = [os.path.relpath(p, ROOT).replace("\\", "/") for p in
                              render_pile(key, [mesh, mag], Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, 0)), max(mx.x - mn.x, mx.y - mn.y))]
        for o in [mesh, mag, hull] + pile["anchors"]:
            o.location += origin
        bpy.context.view_layer.update()
        rep["materials"] = [m.name for m in mesh.data.materials] + [m.name for m in mag.data.materials]
        rep["nodes"] = [mesh.name, mag.name, hull.name] + [a.name for a in pile["anchors"]]
        manifest["piles"][key] = rep
        print("[gore] %-10s tris %4d/%d  footprint %s  height %.3f  pen %s  glb %.1f KB  ok=%s" % (
            key, rep["tris"], budget, rep["footprint_m"], rep["height_m"], pen, rep["glb_bytes"] / 1024.0, rep["ok"]), flush=True)

    manifest["contract"] = {
        "ballistics": "Placed by place_structure: CollisionTable.is_soft(<glb basename>) decides. Add to "
                      "scripts/world/collision_table.gd MATERIALS: \"<name>\": Mat.THATCH (soft, shoot-through) and "
                      "STRUCTURES: {box, y_offset, footprint, scale 1.0, mesh: true}. Inside a firebase GLB the "
                      "collider prefix must be in site_planner.FSB_SOFT_PREFIXES; none of the nine covers gore_pile_.",
        "destruction": "Add {\"prefix\": \"gore_pile_\", \"kind\": \"gore_pile\"} to site_planner.FSB_STRUCTURE_KINDS and "
                       "\"gore_pile\": <hp> to Destructible.HP_FOR. Both the placed path (_destructible_kind_for on the "
                       "glb basename) and the firebase walk (mesh name) match that prefix.",
        "collider": "<name>_000-colonly: convex hull trimesh of the pile (pool and maggots excluded).",
        "maggots": "maggot_mass mesh, material gore_pile_maggots, UV 0..1 = one 64x64 frame. Swap the albedo between "
                   "maggots_a.png and maggots_b.png at ~6 Hz for the crawl; both PNGs ship beside the GLBs.",
        "anchors": "Empties fx_maggots_01..03 (cavity centre + two spill points) and fx_flies_01 (0.25 m above the "
                   "cavity) - hang particle emitters here. Positions in the manifest are metres, Blender Z-up, "
                   "pile origin at ground centre.",
        "origin": "Ground contact at z=0, XY centred on the footprint like medical_crate / m26_grenade.",
    }
    with open(os.path.join(OUT_DIR, "gore_piles_manifest.json"), "w") as f:
        json.dump(manifest, f, indent=2)

    # studio file: the parked donor library still points at the packed 3600x5700 master
    # sheets. Quarter them in-memory before saving so the .blend is a few MB, not a third
    # copy of the masters (the piles themselves only reference their baked atlases).
    for img in bpy.data.images:
        if img.size[0] > 2048 or img.size[1] > 2048:
            img.scale(img.size[0] // 4, img.size[1] // 4)
            img.pack()
    bpy.context.preferences.filepaths.save_version = 0
    for o in list(bpy.data.objects):
        if o.name.startswith("_render"):
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.outliner.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT, compress=True, copy=False)
    b1 = BLEND_OUT + "1"
    if os.path.exists(b1):
        os.remove(b1)
    print("[gore] saved %s" % BLEND_OUT, flush=True)


if __name__ == "__main__":
    main()
