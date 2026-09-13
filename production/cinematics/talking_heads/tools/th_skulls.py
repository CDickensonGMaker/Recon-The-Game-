"""th_skulls.py - real teeth on the cutscene skulls, and the sniper's OWN head as the talking head (2026-09-12).

    "C:/Program Files/Blender Foundation/Blender 5.0/blender.exe" -b production/cinematics/talking_heads/talking_heads.blend ^
        --python production/cinematics/talking_heads/tools/th_skulls.py            # skull-only pass on the saved file
    th_build.py imports this and calls run() before its final save (full rebuild from nothing).

Zombie (cs_skull_zombie + cs_mandible_zombie, the CDmir cage skull): the cage's "tips" row was a ray-hit sawtooth
(ref z -1.089 / -1.215 / -1.138 / -1.037 / -0.948 across the front columns) with teeth PAINTED along it. Those 7 verts
now sit on the measured alveolar margin (th_spec.UP_MARGIN_Z) along the measured labial arch, the mandible ridge on the
measured crest (LO_CREST_Z, also removing a ray-miss notch at col 0), and both arches are tapered tooth BLOCKS
(5 quads each, open at the buried end) hung from / stood on those ridges, lower row inset behind the upper with an
overbite, two teeth missing, one snapped. Crown texels = the ivory patch on the zombie atlas.

Sniper (cs_skull_sniper + cs_mandible_sniper): his shipped game head (the head polys of vc_guerilla_joined, own
weights, own UVs on cow_sniper_sheet_1024.png) split on the painted mouth slit: a tooth band (skin edges above/below
the slit) is cut out between the corners, everything below it in front of the cheeks becomes a chin block on the `jaw`
bone (100% jaw), the head gets a dark cavity (roof, back and side walls) with the upper teeth hanging from the upper
skin edge, the block gets a dark floor with the lower teeth, plus its own back/side walls rising into the head so the
gap stays dark at every jaw angle. Tooth texels = his own painted teeth patch on the sheet.

Every tooth face carries the int face attribute `th_tooth` = 1 + its spec index (0 = bone) so the pass is re-runnable (old teeth deleted first)
and so the gates can test the bone cage without the teeth.
"""
import bpy, bmesh, math, os, sys, json
from mathutils import Vector, Matrix, Quaternion

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import th_spec as S

R = r"C:\Users\caleb\RECONgame"
OUT_DIR = os.path.dirname(HERE)
OUT = os.environ.get("TH_BLEND") or os.path.join(OUT_DIR, "talking_heads.blend")     # TH_BLEND: scratch copy for dry runs
TEX = os.path.join(OUT_DIR, "textures")
SNIPER = os.path.join(R, r"assets\nva_vc\characters\conquest_of_worms_sniper.blend")
SHEET = os.path.join(R, r"assets\nva_vc\characters\cow_sniper_sheet_1024.png")
HEAD_BONE = "mixamorig:Head"
MM = 0.001
SKULL_SCALE = 0.222 / 2.8517
SKULL_TOP_Z = 1.800
PSX_HEAD_Y_CENTRE = -0.0286
EPS = 1e-7


def _log(*a):
    print("[TH-SKULLS]", *a)


# ----------------------------------------------------------------------------------------------- geometry helpers
def lerp_rec(a, b, t):
    w = {}
    for k in set(a["w"]) | set(b["w"]):
        w[k] = a["w"].get(k, 0.0) * (1 - t) + b["w"].get(k, 0.0) * t
    return {"co": a["co"].lerp(b["co"], t), "uv": a["uv"].lerp(b["uv"], t), "w": w}


def clip_poly(poly, n, d):
    """Split a convex polygon of attribute records by the plane n.co = d. Returns (front, back); front keeps n.co >= d.
    Vertices on the plane go to both sides, so pieces share their cut vertices exactly."""
    front, back = [], []
    N = len(poly)
    for i in range(N):
        a, b = poly[i], poly[(i + 1) % N]
        da, db = n.dot(a["co"]) - d, n.dot(b["co"]) - d
        if abs(da) < EPS:
            da = 0.0
        if abs(db) < EPS:
            db = 0.0
        if da >= 0:
            front.append(a)
        if da <= 0:
            back.append(a)
        if (da > 0 and db < 0) or (da < 0 and db > 0):
            m = lerp_rec(a, b, da / (da - db))
            front.append(m); back.append(m)

    def clean(p):
        out = []
        for r in p:
            if not out or (r["co"] - out[-1]["co"]).length > EPS:
                out.append(r)
        if len(out) > 1 and (out[0]["co"] - out[-1]["co"]).length <= EPS:
            out.pop()
        return out if len(out) >= 3 else []
    return clean(front), clean(back)


def poly_area_normal(pts):
    n = Vector((0, 0, 0))
    for i in range(len(pts)):
        n += pts[i].cross(pts[(i + 1) % len(pts)])
    return n * 0.5


class MeshBuilder:
    """Collects faces as attribute records, welds vertices by position, fixes T-junctions, writes a Mesh."""

    def __init__(self):
        self.verts = []          # [{"co", "w"}]
        self.key = {}
        self.faces = []          # [(vert idx list, uv list, tooth_flag)]

    def vid(self, rec):
        k = tuple(round(c, 6) for c in rec["co"])
        if k not in self.key:
            self.key[k] = len(self.verts)
            self.verts.append({"co": rec["co"].copy(), "w": dict(rec["w"])})
        return self.key[k]

    def add(self, recs, tooth=0, want_normal=None):
        if len(recs) < 3:
            return
        pts = [r["co"] for r in recs]
        n = poly_area_normal(pts)
        if n.length < 1e-12:
            return
        if want_normal is not None and n.dot(want_normal) < 0:
            recs = recs[::-1]
        ids = [self.vid(r) for r in recs]
        if len(set(ids)) < 3:
            return
        self.faces.append((ids, [r["uv"].copy() for r in recs], tooth))

    def fix_t_junctions(self):
        cos = [v["co"] for v in self.verts]
        out = []
        for ids, uvs, tooth in self.faces:
            new_ids, new_uvs = [], []
            for i in range(len(ids)):
                a, b = ids[i], ids[(i + 1) % len(ids)]
                pa, pb = cos[a], cos[b]
                L = (pb - pa).length
                ins = []
                for c in range(len(cos)):
                    if c == a or c == b:
                        continue
                    pc = cos[c]
                    if (pc - pa).length + (pb - pc).length - L < 1e-6 and (pc - pa).length > 1e-6 and (pb - pc).length > 1e-6:
                        ins.append(((pc - pa).length / L, c))
                ins.sort()
                new_ids.append(a); new_uvs.append(uvs[i])
                for t, c in ins:
                    if c not in ids:
                        new_ids.append(c); new_uvs.append(uvs[i].lerp(uvs[(i + 1) % len(ids)], t))
            out.append((new_ids, new_uvs, tooth))
        self.faces = out

    def to_mesh(self, name, group_names):
        me = bpy.data.meshes.new(name)
        bm = bmesh.new()
        uv_lay = bm.loops.layers.uv.new("UVMap")
        dl = bm.verts.layers.deform.verify()
        tl = bm.faces.layers.int.new("th_tooth")
        gi = {g: i for i, g in enumerate(group_names)}
        bverts = []
        for v in self.verts:
            bv = bm.verts.new(v["co"])
            for g, w in v["w"].items():
                if w > 1e-4 and g in gi:
                    bv[dl][gi[g]] = w
            bverts.append(bv)
        made = 0
        for ids, uvs, tooth in self.faces:
            try:
                f = bm.faces.new([bverts[i] for i in ids])
            except ValueError:
                continue
            for l, uv in zip(f.loops, uvs):
                l[uv_lay].uv = uv
            f[tl] = tooth
            made += 1
        bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
        bm.to_mesh(me); bm.free()
        return me, made


# ----------------------------------------------------------------------------------------------- arches
def polyline_len(pts):
    return sum((pts[i + 1] - pts[i]).length for i in range(len(pts) - 1))


def polyline_at(pts, s):
    """Point and unit tangent at arc length s along a polyline (clamped)."""
    acc = 0.0
    for i in range(len(pts) - 1):
        seg = pts[i + 1] - pts[i]; L = seg.length
        if s <= acc + L or i == len(pts) - 2:
            t = 0.0 if L == 0 else max(0.0, min(1.0, (s - acc) / L))
            return pts[i] + seg * t, seg.normalized()
        acc += L
    return pts[-1].copy(), (pts[-1] - pts[-2]).normalized()


def offset_inward(pts, dist, interior):
    """Offset a 3D polyline (treated in XY) toward the interior point by dist."""
    out = []
    for i, p in enumerate(pts):
        d = Vector((0, 0, 0))
        if i > 0:
            d += (pts[i] - pts[i - 1]).normalized()
        if i < len(pts) - 1:
            d += (pts[i + 1] - pts[i]).normalized()
        d.z = 0
        if d.length < 1e-9:
            out.append(p.copy()); continue
        d.normalize()
        n = Vector((-d.y, d.x, 0.0))
        if n.dot(Vector((interior.x - p.x, interior.y - p.y, 0.0))) < 0:
            n = -n
        out.append(p + n * dist)
    return out


def point_at_azimuth(pts, origin, theta_deg):
    """Point on a left->right polyline where the azimuth about origin (0 = -y, + = +x) equals theta."""
    def az(p):
        return math.degrees(math.atan2(p.x - origin.x, -(p.y - origin.y)))
    for i in range(len(pts) - 1):
        a0, a1 = az(pts[i]), az(pts[i + 1])
        if (a0 - theta_deg) * (a1 - theta_deg) <= 0 and a0 != a1:
            t = (theta_deg - a0) / (a1 - a0)
            return pts[i].lerp(pts[i + 1], t)
    # past either end (the inward offset shortens the arch's azimuth span): extrapolate the end segment, at most 3 mm
    i = 0 if theta_deg < az(pts[0]) else len(pts) - 2
    a0, a1 = az(pts[i]), az(pts[i + 1])
    t = (theta_deg - a0) / (a1 - a0)
    p = pts[i].lerp(pts[i + 1], t)
    assert (p - (pts[0] if t < 0 else pts[-1])).length <= 3.0 * MM, f"azimuth {theta_deg} is {((p - (pts[0] if t < 0 else pts[-1])).length / MM):.1f} mm past the arch end"
    return p


def fit_teeth(specs, side_len, gap, k_min=0.82):
    """The largest run of specs (from the midline) whose widths, scaled to fill one side exactly, stay >= k_min of spec."""
    best = None
    for n in range(1, len(specs) + 1):
        k = (side_len - gap * (n - 1)) / sum(sp[1] * MM for sp in specs[:n])
        if k >= k_min:
            best = (specs[:n], k)
    assert best is not None, (side_len, specs[0])
    return best


def build_arch(mb, labial, z_attach, hang, specs, tip_z_of, interior, cells, weight, missing=(), broken=None, gap=None,
               sink=0.5 * MM, taper_w=0.78):
    """Tooth blocks along a left->right labial polyline (z ignored) at z_attach. hang=True: crowns go DOWN from the
    ridge (upper arch); False: UP (lower). specs per side from the midline; tip_z_of(side, i, spec) -> tip z.
    Returns the tooth list with their 6 bounding planes for hull tests."""
    gap = S.TOOTH_GAP_MM * MM if gap is None else gap
    broken = broken or {}
    # midline index (x closest to 0), per-side polylines from the midline outward
    mid = min(range(len(labial)), key=lambda i: abs(labial[i].x))
    sides = {-1: labial[:mid + 1][::-1], 1: labial[mid:]}
    teeth = []
    for side, pts in sides.items():
        L = polyline_len(pts)
        chosen, k = fit_teeth(specs, L, gap)
        s = 0.0
        for i, sp in enumerate(chosen):
            name, w_mm, d_mm, crown_mm, tip_mm = sp
            w = w_mm * MM * k; d = d_mm * MM; tip_d = min(tip_mm * MM, d)
            s0 = s; s1 = s + w; s = s1 + gap
            if (side, i) in missing:
                continue
            sc = 0.5 * (s0 + s1)
            P, T = polyline_at(pts, sc)
            T = Vector((T.x, T.y, 0.0)).normalized()
            Nin = Vector((-T.y, T.x, 0.0))
            if Nin.dot(Vector((interior.x - P.x, interior.y - P.y, 0.0))) < 0:
                Nin = -Nin
            z_tip = tip_z_of(side, i, sp)
            frac = broken.get((side, i), 1.0)
            z_base = z_attach + (sink if hang else -sink)
            z_tip = z_base + (z_tip - z_base) * frac
            wt = w * taper_w
            # 8 corners: base (buried end) rectangle and tip rectangle; labial face vertical
            bfl = Vector((P.x, P.y, z_base)) - T * (w / 2); bfr = Vector((P.x, P.y, z_base)) + T * (w / 2)
            bbl = bfl + Nin * d; bbr = bfr + Nin * d
            tfl = Vector((P.x, P.y, z_tip)) - T * (wt / 2); tfr = Vector((P.x, P.y, z_tip)) + T * (wt / 2)
            tbl = tfl + Nin * tip_d; tbr = tfr + Nin * tip_d
            u0, v0, u1, v1 = cells[len(teeth) % len(cells)]      # v0 = gum end, v1 = tip end
            um = u0 + 0.3 * (u1 - u0); vm = v1 - 0.15 * (v1 - v0)

            def rec(co, uv):
                return {"co": co, "uv": Vector(uv), "w": {weight: 1.0}}
            faces = [
                ([rec(bfl, (u0, v0)), rec(bfr, (u1, v0)), rec(tfr, (u1, v1)), rec(tfl, (u0, v1))], -Nin),             # labial
                ([rec(bbr, (u0, v0)), rec(bbl, (u1, v0)), rec(tbl, (u1, v1)), rec(tbr, (u0, v1))], Nin),              # lingual
                ([rec(bfr, (u0, v0)), rec(bbr, (um, v0)), rec(tbr, (um, v1)), rec(tfr, (u0, v1))], T),                # side
                ([rec(bbl, (u0, v0)), rec(bfl, (um, v0)), rec(tfl, (um, v1)), rec(tbl, (u0, v1))], -T),              # side
                ([rec(tfl, (u0, vm)), rec(tfr, (u1, vm)), rec(tbr, (u1, v1)), rec(tbl, (u0, v1))], Vector((0, 0, -1 if hang else 1))),  # tip
            ]
            for recs, want in faces:
                mb.add(recs, tooth=1 + i, want_normal=want)          # th_tooth = 1 + spec index (1..3 anterior, 4+ posterior)
            corners = [bfl, bfr, bbl, bbr, tfl, tfr, tbl, tbr]
            planes = []
            for recs, want in faces:
                pts3 = [r["co"] for r in recs]
                n = poly_area_normal(pts3).normalized()
                if n.dot(want) < 0:
                    n = -n
                planes.append((pts3[0].copy(), n))
            planes.append((bfl.copy(), Vector((0, 0, 1 if hang else -1))))       # the buried end
            teeth.append({"name": name, "side": side, "i": i, "centre": Vector((P.x, P.y, 0.5 * (z_base + z_tip))),
                          "corners": corners, "planes": planes, "w_mm": round(w / MM, 2), "d_mm": d_mm,
                          "crown_mm": round(abs(z_tip - z_attach) / MM, 2), "labial": P.copy(), "tip_z": z_tip,
                          "broken": frac < 1.0})
    return teeth


def lower_inset(upper_specs, crown_cap=None, clearance=0.8 * MM):
    """How far behind the upper labial line the lower labial line must sit: the upper anteriors' lingual faces slope
    from tip_d at the edge to d at the ridge, so at the overbite height they are thicker than the edge."""
    worst = 0.0
    for i, (name, w, d, crown, tip) in enumerate(upper_specs[:3]):
        c = crown if crown_cap is None else min(crown, crown_cap / MM)
        worst = max(worst, tip * MM + (d - tip) * MM * (S.OVERBITE_MM / c))
    return worst + clearance


def inside_hull(p, planes, eps=1e-6):
    return all((p - p0).dot(n) < -eps for p0, n in planes)


def hull_overlap(teeth_a, teeth_b):
    """Corners and edge midpoints of every tooth in A tested against every hull in B, and the reverse."""
    hits = []
    for A, B in ((teeth_a, teeth_b), (teeth_b, teeth_a)):
        for ta in A:
            samples = list(ta["corners"])
            c = ta["corners"]
            for i, j in ((0, 1), (2, 3), (4, 5), (6, 7), (0, 4), (1, 5), (2, 6), (3, 7), (0, 2), (1, 3), (4, 6), (5, 7)):
                samples.append((c[i] + c[j]) * 0.5)
            samples.append(ta["centre"])
            for tb in B:
                if any(inside_hull(p, tb["planes"]) for p in samples):
                    hits.append((ta["name"], ta["side"], tb["name"], tb["side"]))
    return hits


def min_dist_sets(pts, faces_obj):
    best = 1e9
    for p in pts:
        res, loc, nrm, idx = faces_obj.closest_point_on_mesh(p)
        if res:
            best = min(best, (p - loc).length)
    return best


# ----------------------------------------------------------------------------------------------- evaluation helpers
def eval_mesh_obj(o, name, keep_face=None):
    """Evaluated (posed) copy in WORLD space as a temp object; keep_face(poly, mesh) filters faces."""
    dg = bpy.context.evaluated_depsgraph_get()
    oe = o.evaluated_get(dg); me = oe.to_mesh()
    bm = bmesh.new(); bm.from_mesh(me)
    if keep_face is not None:
        tl = bm.faces.layers.int.get("th_tooth")
        kill = [f for f in bm.faces if not keep_face(f[tl] if tl else 0)]
        bmesh.ops.delete(bm, geom=kill, context='FACES')
    m2 = bpy.data.meshes.new(name); bm.to_mesh(m2); bm.free()
    m2.transform(oe.matrix_world)
    oe.to_mesh_clear()
    tmp = bpy.data.objects.new(name, m2)
    bpy.context.scene.collection.objects.link(tmp)
    bpy.context.view_layer.update()
    return tmp


def kill(tmp):
    me = tmp.data
    bpy.data.objects.remove(tmp, do_unlink=True)
    bpy.data.meshes.remove(me)


def inside_by_parity(obj, p_local, direction=Vector((0.37, 0.61, 0.70))):
    d = direction.normalized(); origin = p_local.copy(); n = 0
    for _ in range(64):
        hit, loc, nrm, idx = obj.ray_cast(origin, d)
        if not hit:
            break
        n += 1; origin = loc + d * 1e-5
    return n % 2 == 1


def set_jaw(rig, deg):
    """Key the angle at frame 0 and evaluate THERE: the saved file may sit on any frame of a keyed line, and a key on
    frame 0 changes nothing at frame 20 (the first dry run measured 0.0 mm of chin travel that way)."""
    sc = bpy.context.scene
    sc.frame_set(0)
    pb = rig.pose.bones["jaw"]
    pb.rotation_mode = 'QUATERNION'
    pb.rotation_quaternion = Quaternion(Vector(rig["jaw_axis"]), math.radians(deg))
    pb.keyframe_insert("rotation_quaternion", frame=0)
    sc.frame_set(0)
    bpy.context.view_layer.update()


def tri_count(o):
    o.data.calc_loop_triangles()
    return len(o.data.loop_triangles)


def swap_mesh(obj, me_new, group_names, name):
    """Replace an object's mesh. Vertex-group NAMES live on the mesh datablock (Blender >= 3.0), so a fresh mesh has
    none and the deform layer's indices point at nothing - the armature then deforms NOTHING (measured: 0.0 mm of
    chin travel at 25 deg). Recreate the groups in the deform layer's order."""
    old = obj.data
    me_new.materials.append(old.materials[0])
    obj.data = me_new
    assert len(obj.vertex_groups) == 0
    for g in group_names:
        obj.vertex_groups.new(name=g)
    bpy.data.meshes.remove(old)
    me_new.name = name
    assert [g.name for g in obj.vertex_groups] == list(group_names), [g.name for g in obj.vertex_groups]


# ----------------------------------------------------------------------------------------------- zombie
def zombie(log, REPORT):
    sk = bpy.data.objects["cs_skull_zombie"]; md = bpy.data.objects["cs_mandible_zombie"]
    rig = bpy.data.objects["PSXRig_zombie"]
    assert sk.data.users == 1 and md.data.users == 1, "zombie skull meshes are still shared (delete the sniper skull objects first)"
    s = SKULL_SCALE
    z0 = SKULL_TOP_Z - 1.0687 * s
    y0 = PSX_HEAD_Y_CENTRE - ((-1.0644 + 1.4822) / 2.0) * s

    def to_local(x, y, z):
        return Vector((x * s, y * s + y0, z * s + z0))
    for o in (sk, md):                                       # the linked-duplicate pass left a duplicate, empty group on each mesh
        for vg in list(o.vertex_groups):
            if vg.name.endswith(".001"):
                o.vertex_groups.remove(vg)
    before = {"skull_tris": tri_count(sk), "mandible_tris": tri_count(md)}
    # upper labial arch (local), mirrored from the +x half
    up = [to_local(x, y, S.UP_MARGIN_Z) for x, y in S.UP_LABIAL]
    labial_up = [Vector((-p.x, p.y, p.z)) for p in up[::-1][:-1]] + up
    interior = to_local(0.0, -0.60, S.UP_MARGIN_Z)
    inset = lower_inset(S.UPPER_TEETH)
    labial_lo = offset_inward(labial_up, inset, interior)
    z_margin = z0 + S.UP_MARGIN_Z * s; z_crest = z0 + S.LO_CREST_Z * s
    for p in labial_lo:
        p.z = z_crest
    # ---- skull: strip old teeth, lift the tips row onto the margin
    bm = bmesh.new(); bm.from_mesh(sk.data)
    tl = bm.faces.layers.int.get("th_tooth") or bm.faces.layers.int.new("th_tooth")
    old = [f for f in bm.faces if f[tl] >= 1]
    bmesh.ops.delete(bm, geom=old, context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bm.verts.ensure_lookup_table()
    nc = len(S.CR_COLS); names = [r[0] for r in S.CR_ROWS]; tips_i = names.index("tips")
    C = to_local(*S.CR_CENTRE)
    ridge_up = offset_inward(labial_up, 1.0 * MM, interior)
    moved = []
    for th in S.CR_COLS:
        if abs(th) > S.TEETH_COL:
            continue
        v = bm.verts[tips_i * nc + S.CR_COLS.index(th)]
        p = point_at_azimuth(ridge_up, C, th)
        new = Vector((p.x, p.y, z_margin))
        moved.append((th, round((new - v.co).length / MM, 1), round((v.co.z - z0) / s, 3)))
        v.co = new
    me_tmp = bpy.data.meshes.new("_zb_skull_tmp"); bm.to_mesh(me_tmp); bm.free()
    log("zombie skull tips row -> alveolar margin (col, moved mm, old ref z):", moved)
    # rebuild the skull mesh through MeshBuilder so the teeth weld/attribute logic is shared
    mb = MeshBuilder()
    gnames = [g.name for g in sk.vertex_groups]
    uvl = me_tmp.uv_layers.active
    for p in me_tmp.polygons:
        recs = []
        for li, vi in zip(p.loop_indices, p.vertices):
            v = me_tmp.vertices[vi]
            recs.append({"co": v.co.copy(), "uv": Vector(uvl.data[li].uv), "w": {gnames[g.group]: g.weight for g in v.groups}})
        mb.add(recs)
    x0, y0p, x1, y1 = S.ZB_TOOTH_PATCH_PX
    cell = [(x0 / S.ATLAS, 1 - y0p / S.ATLAS, x1 / S.ATLAS, 1 - y1 / S.ATLAS)]
    up_tip = {}

    def up_tip_z(side, i, sp):
        z = z_margin - sp[3] * MM
        up_tip[(side, i)] = z
        return z
    upper = build_arch(mb, labial_up, z_margin, True, S.UPPER_TEETH, up_tip_z, interior, cell, HEAD_BONE,
                       missing={(sd, i) for a, sd, i in S.ZB_MISSING if a == "upper"},
                       broken={(sd, i): f for (a, sd, i), f in S.ZB_BROKEN.items() if a == "upper"})
    me_new, made = mb.to_mesh("cs_skull", gnames)
    swap_mesh(sk, me_new, gnames, "cs_skull"); bpy.data.meshes.remove(me_tmp)
    # ---- mandible: ridge onto the crest along the lower labial line, then the lower teeth
    bm = bmesh.new(); bm.from_mesh(md.data)
    tl = bm.faces.layers.int.get("th_tooth") or bm.faces.layers.int.new("th_tooth")
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f[tl] >= 1], context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bm.verts.ensure_lookup_table()
    M = to_local(*S.MD_AXIS)
    ridge_lo = offset_inward(labial_lo, 1.0 * MM, interior)
    moved = []
    for ci, th in enumerate(S.MD_COLS):
        if abs(th) > S.TEETH_COL:
            continue
        p = point_at_azimuth(ridge_lo, M, th)
        t = math.radians(th); dirh = Vector((math.sin(t), -math.cos(t), 0.0))
        vo, vi_ = bm.verts[ci * 5 + 0], bm.verts[ci * 5 + 4]
        new_o = Vector((p.x, p.y, z_crest)); new_i = new_o - dirh * (S.MD_THICK * s)
        moved.append((th, round((new_o - vo.co).length / MM, 1)))
        vo.co = new_o; vi_.co = new_i
    me_tmp = bpy.data.meshes.new("_zb_mand_tmp"); bm.to_mesh(me_tmp); bm.free()
    log("zombie mandible ridge -> crest (col, moved mm):", moved)
    mb = MeshBuilder()
    gnames_m = [g.name for g in md.vertex_groups]
    uvl = me_tmp.uv_layers.active
    for p in me_tmp.polygons:
        recs = []
        for li, vi in zip(p.loop_indices, p.vertices):
            v = me_tmp.vertices[vi]
            recs.append({"co": v.co.copy(), "uv": Vector(uvl.data[li].uv), "w": {gnames_m[g.group]: g.weight for g in v.groups}})
        mb.add(recs)

    def lo_tip_z(side, i, sp):
        zu = up_tip.get((side, i), z_margin - S.UPPER_TEETH[min(i, len(S.UPPER_TEETH) - 1)][3] * MM)
        if i < 3:
            return zu + S.OVERBITE_MM * MM
        zc = up_tip.get((side, 2), z_margin - S.UPPER_TEETH[2][3] * MM)      # the canine's edge: posteriors stay in its overbite zone
        return min(zu - 0.5 * MM, zc + S.OVERBITE_MM * MM)
    lower = build_arch(mb, labial_lo, z_crest, False, S.LOWER_TEETH, lo_tip_z, interior, cell, "jaw",
                       missing={(sd, i) for a, sd, i in S.ZB_MISSING if a == "lower"})
    me_new, made_m = mb.to_mesh("cs_mandible", gnames_m)
    swap_mesh(md, me_new, gnames_m, "cs_mandible"); bpy.data.meshes.remove(me_tmp)
    for o in (sk, md):
        o.material_slots[0].link = 'OBJECT'; o.material_slots[0].material = bpy.data.materials["cs_skull_zombie_mat"]
    bpy.context.view_layer.update()
    # ---- measurements
    def arch_stats(teeth, tag):
        def at(name):
            return [t for t in teeth if t["name"] == name]
        mol = at("M") or at("m"); can = at("C") or at("c"); inc = at("I1") or at("i1")
        d = {"teeth": len(teeth), "names": [t["name"] + ("-" if t["side"] < 0 else "+") + ("*" if t["broken"] else "") for t in teeth],
             "tris": 10 * len(teeth)}
        if len(mol) == 2:
            d["molar_labial_width_mm"] = round(abs(mol[0]["labial"].x - mol[1]["labial"].x) / MM, 1)
        if len(can) == 2:
            d["canine_labial_width_mm"] = round(abs(can[0]["labial"].x - can[1]["labial"].x) / MM, 1)
        if inc and mol:
            d["arch_depth_mm"] = round(abs(inc[0]["labial"].y - mol[0]["labial"].y) / MM, 1)
        d["incisor_w_mm"] = inc[0]["w_mm"] if inc else None
        d["incisor_crown_mm"] = inc[0]["crown_mm"] if inc else None
        return d
    rep = {"before": before, "after": {"skull_tris": tri_count(sk), "mandible_tris": tri_count(md)},
           "upper": arch_stats(upper, "upper"), "lower": arch_stats(lower, "lower"),
           "ref_mm": {"molar_centre_width": round(2 * 0.392 * s / MM, 1), "canine_centre_width": round(2 * 0.233 * s / MM, 1),
                      "arch_depth_centres": round((0.913 - 0.433) * s / MM, 1), "margin_to_incisal_edge": round((1.24 - 1.093) * s / MM, 1)},
           "lower_inset_mm": round(inset / MM, 2), "hull_overlaps_rest": hull_overlap(upper, lower)}
    u1 = [t for t in upper if t["name"] == "I1"]; l1 = [t for t in lower if t["name"] == "i1"]
    if u1 and l1:
        rep["overjet_labial_to_labial_mm"] = round((l1[0]["labial"].y - u1[0]["labial"].y) / MM, 2)
        rep["overjet_upper_edge_to_lower_labial_mm"] = round((l1[0]["labial"].y - (u1[0]["labial"].y + u1[0]["d_mm"] * 0 + S.UPPER_TEETH[0][4] * MM)) / MM, 2)
        rep["overbite_mm"] = round((l1[0]["tip_z"] - u1[0]["tip_z"]) / MM, 2)
    rep["tri_delta"] = {"skull": rep["after"]["skull_tris"] - before["skull_tris"], "mandible": rep["after"]["mandible_tris"] - before["mandible_tris"]}
    REPORT["teeth_zombie"] = rep
    log("zombie teeth:", json.dumps(rep, default=str))
    assert not rep["hull_overlaps_rest"], rep["hull_overlaps_rest"]
    assert rep["tri_delta"]["skull"] + rep["tri_delta"]["mandible"] <= 260, rep["tri_delta"]
    return sk, md, rig


# ----------------------------------------------------------------------------------------------- sniper
def sniper(log, REPORT):
    rig = bpy.data.objects["PSXRig_sniper"]
    assert "jaw" in rig.pose.bones and "jaw_axis" in rig, "sniper rig has no jaw bone (run th_build.py first)"
    for n in ("cs_skull_sniper", "cs_mandible_sniper"):
        o = bpy.data.objects.get(n)
        if o:
            me = o.data; bpy.data.objects.remove(o, do_unlink=True)
            if me.users == 0:
                bpy.data.meshes.remove(me)
    old_mat = bpy.data.materials.get("cs_skull_sniper_mat")           # the generated skull atlas is dead
    if old_mat:
        for n in old_mat.node_tree.nodes:
            if n.type == 'TEX_IMAGE' and n.image and n.image.users <= 1:
                bpy.data.images.remove(n.image)
        bpy.data.materials.remove(old_mat)
    # his shipped body, read-only source: the head is the polys whose verts all sit above the neck
    before_objs = set(bpy.data.objects); before_mats = set(bpy.data.materials); before_imgs = set(bpy.data.images)
    with bpy.data.libraries.load(SNIPER, link=False) as (src, dst):
        assert "vc_guerilla_joined" in src.objects, src.objects
        dst.objects = ["vc_guerilla_joined"]
    body = dst.objects[0]
    bpy.context.scene.collection.objects.link(body)
    me = body.data; uv = me.uv_layers.active
    gnames = {g.index: g.name for g in body.vertex_groups}
    head_polys = [p for p in me.polygons if all(me.vertices[i].co.y > 1.55 for i in p.vertices)]
    assert len(head_polys) == 62, len(head_polys)

    def vrec(vi, li):                                       # game data is Y-up (x, up, front); the talking-head frame is Z-up, face -y
        v = me.vertices[vi]
        return {"co": Vector((v.co.x, -v.co.z, v.co.y)), "uv": Vector(uv.data[li].uv), "w": {gnames[g.group]: g.weight for g in v.groups}}
    tris = [[vrec(vi, li) for vi, li in zip(p.vertices, p.loop_indices)] for p in head_polys]
    src_tris = tri_count(body)
    W = 1024.0

    def px_to_uv(px, py):
        return Vector((px / W, 1.0 - py / W))

    def surface_at_px(px, py):
        """3D point whose UV is the given sheet pixel (inverse of the tri's UV map)."""
        q = px_to_uv(px, py)
        for t in tris:
            a, b, c = t[0]["uv"], t[1]["uv"], t[2]["uv"]
            den = (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
            if abs(den) < 1e-12:
                continue
            l0 = ((b.y - c.y) * (q.x - c.x) + (c.x - b.x) * (q.y - c.y)) / den
            l1 = ((c.y - a.y) * (q.x - c.x) + (a.x - c.x) * (q.y - c.y)) / den
            l2 = 1 - l0 - l1
            if min(l0, l1, l2) >= -1e-6:
                return t[0]["co"] * l0 + t[1]["co"] * l1 + t[2]["co"] * l2
        return None
    cx, cy = S.SN_MOUTH_PX
    pm = surface_at_px(cx, cy); pl = surface_at_px(cx - S.SN_MOUTH_HALF_PX, cy); pr = surface_at_px(cx + S.SN_MOUTH_HALF_PX, cy)
    assert pm is not None and pl is not None and pr is not None, (pm, pl, pr)
    z_m = pm.z; x_c = 0.5 * (abs(pl.x) + abs(pr.x))
    z_u = z_m + S.SN_BAND_UP_MM * MM; z_l = z_m - S.SN_BAND_DOWN_MM * MM
    y_b = S.SN_CAVITY_BACK_Y
    mouth = {"bite_line_z": round(z_m, 4), "mouth_centre_y": round(pm.y, 4), "corner_L": [round(c, 4) for c in pl], "corner_R": [round(c, 4) for c in pr],
             "corner_z_dev_mm": round(max(abs(pl.z - z_m), abs(pr.z - z_m)) / MM, 2), "x_c": round(x_c, 4), "mouth_width_mm": round(2 * x_c / MM, 1),
             "z_u": round(z_u, 4), "z_l": round(z_l, 4)}
    log("sniper painted mouth in 3D:", mouth)
    # ---- split every head tri: outside the box -> head; inside below z_l -> chin block; the band -> gone
    head_mb, mand_mb = MeshBuilder(), MeshBuilder()
    band, mand_polys = [], []
    for t in tris:
        a, b = clip_poly(t, Vector((1, 0, 0)), -x_c); head_mb.add(b)          # x < -x_c
        a, b = clip_poly(a, Vector((-1, 0, 0)), -x_c); head_mb.add(b)         # x > x_c
        a, b = clip_poly(a, Vector((0, 0, -1)), -z_u); head_mb.add(b)         # above the upper skin edge
        a, b = clip_poly(a, Vector((0, -1, 0)), -y_b); head_mb.add(b)         # behind the cavity back
        a, b = clip_poly(a, Vector((0, 0, -1)), -z_l)                          # a: chin block skin ; b: the tooth band
        if a:
            mand_polys.append(a)
            mand_mb.add([{"co": r["co"], "uv": r["uv"], "w": {"jaw": 1.0}} for r in a])
        if b:
            band.append(b)
    # skin edges of the band, left -> right
    def edge_pts(z):
        pts = {}
        for poly in band:
            for r in poly:
                if abs(r["co"].z - z) < 1e-6:
                    pts[tuple(round(c, 6) for c in r["co"])] = r["co"].copy()
        out = sorted(pts.values(), key=lambda p: p.x)
        return out
    U, Lw = edge_pts(z_u), edge_pts(z_l)
    assert len(U) >= 3 and len(Lw) >= 3 and abs(U[0].x + x_c) < 1e-6 and abs(U[-1].x - x_c) < 1e-6, (U, Lw)
    dark_uv = px_to_uv(0.5 * (S.SN_DARK_PX[0] + S.SN_DARK_PX[2]), 0.5 * (S.SN_DARK_PX[1] + S.SN_DARK_PX[3]))
    cells = [(a / W, 1 - b / W, c / W, 1 - d / W) for a, b, c, d in S.SN_TOOTH_CELLS_PX]
    interior = Vector((0.0, y_b, z_m))

    def dk(co, w):
        return {"co": co, "uv": dark_uv.copy(), "w": w}
    # ---- head cavity: roof from the upper skin edge back to the back wall, back wall + side walls down to the ring
    z_ring = 1.576
    hw = {HEAD_BONE: 1.0}
    for i in range(len(U) - 1):
        a, b = U[i], U[i + 1]
        head_mb.add([dk(a, hw), dk(b, hw), dk(Vector((b.x, y_b, z_u)), hw), dk(Vector((a.x, y_b, z_u)), hw)], want_normal=Vector((0, 0, -1)))
        head_mb.add([dk(Vector((a.x, y_b, z_u)), hw), dk(Vector((b.x, y_b, z_u)), hw), dk(Vector((b.x, y_b, z_ring)), hw), dk(Vector((a.x, y_b, z_ring)), hw)],
                    want_normal=Vector((0, -1, 0)))
    # the side walls' front edges follow the block's cut edge at x = +-x_c (the chin skin recedes 11 mm between the
    # mouth corner and the jaw line: a rectangular wall poked out of the lower cheek as a dark bar in the first render)
    def chain(side, z_top, z_min):
        pts = {}
        for poly in band + mand_polys:
            for r in poly:
                if abs(r["co"].x - side * x_c) < 1e-6 and r["co"].z <= z_top + 1e-6 and r["co"].z >= z_min - 1e-6:
                    pts[tuple(round(c, 6) for c in r["co"])] = r["co"].copy()
        pts = list(pts.values())
        start = max(pts, key=lambda p: (p.z, -p.y))
        out = [start]; rest = [p for p in pts if p is not start]
        while rest:
            nxt = min(rest, key=lambda p: (p - out[-1]).length)
            out.append(nxt); rest.remove(nxt)
        return out
    for side, corner in ((-1, U[0]), (1, U[-1])):
        xw = side * (x_c - 0.3 * MM)
        ch = [Vector((xw, p.y, p.z)) for p in chain(side, z_u, z_l - 15 * MM)]
        poly = [dk(p, hw) for p in ch] + [dk(Vector((xw, y_b, ch[-1].z)), hw), dk(Vector((xw, y_b, z_u)), hw)]
        head_mb.add(poly, want_normal=Vector((-side, 0, 0)))
    labial_up = offset_inward(U, 0.5 * MM, interior)
    up_tip = {}
    crown_up = (z_u - z_m) + S.OVERBITE_MM * MM

    def up_tip_z(side, i, sp):
        z = z_u - min(sp[3] * MM, crown_up)
        up_tip[(side, i)] = z
        return z
    upper = build_arch(head_mb, labial_up, z_u, True, S.UPPER_TEETH, up_tip_z, interior, cells, HEAD_BONE)
    # ---- chin block: floor from the lower skin edge back, back + side walls rising into the head, lower teeth
    jw = {"jaw": 1.0}
    z_wall = z_u + 30 * MM
    for i in range(len(Lw) - 1):
        a, b = Lw[i], Lw[i + 1]
        mand_mb.add([dk(a, jw), dk(b, jw), dk(Vector((b.x, y_b, z_l)), jw), dk(Vector((a.x, y_b, z_l)), jw)], want_normal=Vector((0, 0, 1)))
        mand_mb.add([dk(Vector((a.x, y_b, z_l)), jw), dk(Vector((b.x, y_b, z_l)), jw), dk(Vector((b.x, y_b, z_wall)), jw), dk(Vector((a.x, y_b, z_wall)), jw)],
                    want_normal=Vector((0, -1, 0)))
    for side, corner in ((-1, Lw[0]), (1, Lw[-1])):
        xw = side * x_c
        ch = chain(side, z_l, -1e9)                              # the block's whole cut edge: skin down the chin, back along the underside
        poly = [dk(p, jw) for p in ch] + [dk(Vector((xw, y_b, ch[-1].z)), jw), dk(Vector((xw, y_b, z_wall)), jw), dk(Vector((xw, corner.y, z_wall)), jw)]
        mand_mb.add(poly, want_normal=Vector((-side, 0, 0)))
    inset = lower_inset(S.UPPER_TEETH, crown_cap=crown_up)
    labial_lo = offset_inward(labial_up, inset, interior)
    for p in labial_lo:
        p.z = z_l
    n_up_side = max(t["i"] for t in upper) + 1

    def lo_tip_z(side, i, sp):
        if i < 3 and (side, i) in up_tip:
            return up_tip[(side, i)] + S.OVERBITE_MM * MM
        return min(up_tip.values()) - 0.5 * MM                     # posteriors, or no upper opposite: under the upper edge
    lower = build_arch(mand_mb, labial_lo, z_l, False, S.LOWER_TEETH, lo_tip_z, interior, cells, "jaw")
    # ---- meshes, objects, material (ONE material: his sheet, nearest)
    groups_h = sorted({g for v in head_mb.verts for g in v["w"]} | {HEAD_BONE})
    head_mb.fix_t_junctions(); mand_mb.fix_t_junctions()
    me_h, made_h = head_mb.to_mesh("cs_skull_sniper", groups_h)
    me_m, made_m = mand_mb.to_mesh("cs_mandible_sniper", ["jaw"])
    img = bpy.data.images.load(SHEET, check_existing=True)
    img.pack()
    mat = bpy.data.materials.get("cs_sniper_head_mat")
    if mat is None:
        mat = bpy.data.materials.new("cs_sniper_head_mat"); mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Roughness"].default_value = 0.9; bsdf.inputs["Specular IOR Level"].default_value = 0.0
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage"); tex.image = img; tex.interpolation = 'Closest'
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    template = bpy.data.objects["cs_skull_zombie"]
    objs = {}
    for me_, nm, groups in ((me_h, "cs_skull_sniper", groups_h), (me_m, "cs_mandible_sniper", ["jaw"])):
        me_.materials.append(mat)
        o = bpy.data.objects.new(nm, me_); bpy.context.scene.collection.objects.link(o)
        for g in groups:
            o.vertex_groups.new(name=g)
        o.parent = rig; o.parent_type = 'OBJECT'; o.matrix_parent_inverse = Matrix.Identity(4)
        o.location = (0, 0, 0); o.rotation_euler = template.rotation_euler.copy(); o.scale = (1, 1, 1)
        am = o.modifiers.new("Armature", 'ARMATURE'); am.object = rig
        objs[nm] = o
    # drop the appended body and everything it dragged in
    bpy.data.objects.remove(body, do_unlink=True)
    for o in set(bpy.data.objects) - before_objs - set(objs.values()):
        bpy.data.objects.remove(o, do_unlink=True)
    for m in set(bpy.data.materials) - before_mats - {mat}:
        bpy.data.materials.remove(m)
    for i in set(bpy.data.images) - before_imgs - {img}:
        bpy.data.images.remove(i)
    for m_ in list(bpy.data.meshes):
        if m_.users == 0:
            bpy.data.meshes.remove(m_)
    bpy.context.view_layer.update()
    sk, md = objs["cs_skull_sniper"], objs["cs_mandible_sniper"]
    # ---- gates in the rest pose (rig-local Z-up = mesh local; both objects share the transform)
    unweighted = sum(1 for v in me_h.vertices if not v.groups or sum(g.weight for g in v.groups) < 0.99)
    bad_m = sum(1 for v in me_m.vertices if not (len(v.groups) == 1 and abs(v.groups[0].weight - 1.0) < 1e-6))
    used = set()
    for p in me_h.polygons:
        used.update(p.vertices)
    rep = {"source": "vc_guerilla_joined head polys of conquest_of_worms_sniper.blend", "source_head_tris": src_tris, "mouth": mouth,
           "head": {"verts": len(me_h.vertices), "tris": tri_count(sk), "faces": len(me_h.polygons), "ngons": sum(1 for p in me_h.polygons if len(p.vertices) > 4),
                    "verts_weight_sum_lt_0.99": unweighted, "loose_verts": len(me_h.vertices) - len(used), "materials": [m.name for m in me_h.materials]},
           "mandible": {"verts": len(me_m.vertices), "tris": tri_count(md), "faces": len(me_m.polygons), "ngons": sum(1 for p in me_m.polygons if len(p.vertices) > 4),
                        "verts_not_100pct_jaw": bad_m},
           "upper": {"teeth": len(upper), "names": [t["name"] + ("-" if t["side"] < 0 else "+") for t in upper], "widths_mm": [t["w_mm"] for t in upper],
                     "crown_mm": upper[0]["crown_mm"] if upper else None},
           "lower": {"teeth": len(lower), "names": [t["name"] + ("-" if t["side"] < 0 else "+") for t in lower], "widths_mm": [t["w_mm"] for t in lower],
                     "crown_mm": lower[0]["crown_mm"] if lower else None},
           "arch_depth_mm": round(abs(U[0].y - U[len(U) // 2].y) / MM, 1), "lower_inset_mm": round(inset / MM, 2),
           "hull_overlaps_rest": hull_overlap(upper, lower)}
    u1 = [t for t in upper if t["name"] == "I1" and t["side"] > 0]; l1 = [t for t in lower if t["name"] == "i1" and t["side"] > 0]
    if u1 and l1:
        rep["overjet_labial_to_labial_mm"] = round((l1[0]["labial"].y - u1[0]["labial"].y) / MM, 2)
        rep["overjet_upper_edge_to_lower_labial_mm"] = round((l1[0]["labial"].y - (u1[0]["labial"].y + S.UPPER_TEETH[0][4] * MM)) / MM, 2)
        rep["overbite_mm"] = round((l1[0]["tip_z"] - u1[0]["tip_z"]) / MM, 2)
    REPORT["sniper_head"] = rep
    log("sniper head:", json.dumps(rep, default=str))
    assert rep["head"]["ngons"] == 0 and rep["mandible"]["ngons"] == 0
    assert unweighted == 0 and bad_m == 0 and rep["head"]["loose_verts"] == 0, (unweighted, bad_m)
    assert not rep["hull_overlaps_rest"], rep["hull_overlaps_rest"]
    assert tri_count(sk) + tri_count(md) <= 450, (tri_count(sk), tri_count(md))
    return sk, md, rig


# ----------------------------------------------------------------------------------------------- posed gates
def jaw_gates(tag, rig, sk, md, closed_cage, log, REPORT):
    """0 and 25 deg, evaluated through the armature in world space. Tooth faces carry their spec index, so the cage
    test excludes them and the clearance is measured per class: lower ANTERIOR tooth verts -> upper tooth faces (the
    incisors, 90-100 mm from the hinge, are what opens the mouth), and the posteriors (60-65 mm out) separately."""
    out = {}
    for deg in (0.0, 25.0):
        set_jaw(rig, deg)
        cage = eval_mesh_obj(sk, "_cage", keep_face=lambda t: t == 0)
        up_t = eval_mesh_obj(sk, "_upteeth", keep_face=lambda t: t >= 1)
        mand = eval_mesh_obj(md, "_mand")
        lo_ant = eval_mesh_obj(md, "_loant", keep_face=lambda t: 1 <= t <= 3)
        lo_post = eval_mesh_obj(md, "_lopost", keep_face=lambda t: t >= 4)
        mv = [v.co.copy() for v in mand.data.vertices]
        inside = 0
        if closed_cage:
            inv = cage.matrix_world.inverted()
            inside = sum(1 for p in mv if inside_by_parity(cage, inv @ p))
        ant = [v.co.copy() for v in lo_ant.data.vertices]; post = [v.co.copy() for v in lo_post.data.vertices]
        has_up = len(up_t.data.polygons) > 0
        ant_clear = min_dist_sets(ant, up_t) if ant and has_up else None
        post_clear = min_dist_sets(post, up_t) if post and has_up else None
        body_clear = min_dist_sets(mv, cage)
        chin = min(mv, key=lambda p: p.z)
        out["rest" if deg == 0 else "open25"] = {
            "deg": deg, "mandible_verts_inside_cage": inside,
            "lower_anterior_to_upper_teeth_min_mm": round(ant_clear / MM, 2) if ant_clear is not None else None,
            "lower_posterior_to_upper_teeth_min_mm": round(post_clear / MM, 2) if post_clear is not None else None,
            "mandible_to_head_min_mm": round(body_clear / MM, 2), "chin_world": [round(c, 4) for c in chin]}
        for t in (cage, up_t, mand, lo_ant, lo_post):
            kill(t)
    set_jaw(rig, 0.0)
    out["chin_travel_mm"] = round((Vector(out["rest"]["chin_world"]) - Vector(out["open25"]["chin_world"])).length / MM, 1)
    REPORT[f"jaw_gate_{tag}"] = out
    log(f"jaw gate {tag}:", json.dumps(out))
    if closed_cage:
        assert out["rest"]["mandible_verts_inside_cage"] == 0 and out["open25"]["mandible_verts_inside_cage"] == 0, out
    assert out["open25"]["lower_anterior_to_upper_teeth_min_mm"] >= 30.0, out["open25"]
    if out["open25"]["lower_posterior_to_upper_teeth_min_mm"] is not None:
        assert out["open25"]["lower_posterior_to_upper_teeth_min_mm"] >= 20.0, out["open25"]
    assert out["chin_travel_mm"] > 20.0, out
    return out


def run(REPORT, log=_log):
    sk_s, md_s, rig_s = sniper(log, REPORT)          # first: it frees the shared zombie meshes
    sk_z, md_z, rig_z = zombie(log, REPORT)
    jaw_gates("zombie", rig_z, sk_z, md_z, True, log, REPORT)
    jaw_gates("sniper", rig_s, sk_s, md_s, False, log, REPORT)
    # the skull atlas the sniper no longer uses must be gone from the file too
    for i in list(bpy.data.images):
        if i.name.startswith("cs_skull_sniper_atlas"):
            bpy.data.images.remove(i)
    REPORT["objects"] = sorted(o.name for o in bpy.data.objects)
    REPORT["images"] = sorted((i.name, tuple(i.size), bool(i.packed_file)) for i in bpy.data.images)
    REPORT["materials"] = sorted(m.name for m in bpy.data.materials)
    return REPORT


if __name__ == "__main__":
    if bpy.data.filepath.lower() != OUT.lower():
        bpy.ops.wm.open_mainfile(filepath=OUT)
    rp = os.environ.get("TH_REPORT") or os.path.join(OUT_DIR, "build_report.json")
    REPORT = json.load(open(rp)) if os.path.exists(rp) else {}
    run(REPORT)
    bpy.context.scene.frame_set(0)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=OUT, copy=False)
    _log("SAVED", OUT, "%.1f MB" % (os.path.getsize(OUT) / 1e6))
    with open(rp, "w") as fh:
        json.dump(REPORT, fh, indent=1, default=str)
    _log("REPORT written")
