"""Build production/cinematics/talking_heads/talking_heads.blend from scratch, headless.

    "C:/Program Files/Blender Foundation/Blender 5.0/blender.exe" -b --factory-startup --python th_build.py

Decree: production/war_room/talking_heads_2026-09-11.md. Sources are READ-ONLY and only ever appended from.
Milestones save the ONE output file in place (no .blend1). Every gate prints a number; a failed hard gate raises.
"""
import bpy, bmesh, math, os, sys, json, time
from mathutils import Vector, Matrix, Quaternion

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import th_spec as S

R = r"C:\Users\caleb\RECONgame"
OUT_DIR = os.path.join(R, r"production\cinematics\talking_heads")
OUT = os.path.join(OUT_DIR, "talking_heads.blend")
TEX = os.path.join(OUT_DIR, "textures")
CAST = os.path.join(R, r"assets\us\characters\conquest_of_worms_us_cast.blend")
USBASE = os.path.join(R, r"assets\us\characters\us_base_v3.blend")
SNIPER = os.path.join(R, r"assets\nva_vc\characters\conquest_of_worms_sniper.blend")
HELMETS = os.path.join(R, r"assets\us\characters\helmet_variants.blend")
HELMET_JSON = os.path.join(R, r"assets\us\props\helmets\helmets.json")
SKULL_OBJ = r"C:\Users\caleb\_reference\skeleton_study\raw\skull_cdmir\skull-obj\skull-Low4K.obj"

FPS, NFRAMES = 24, 72
SKULL_SCALE = 0.222 / 2.8517           # vertex-to-menton 222 mm (real adult male ~215-230 mm); ref skull is 2.8517 tall
SKULL_TOP_Z = 1.800                     # PSX head crown z (grunt_head vert 21 = 1.7999)
PSX_HEAD_Y_CENTRE = -0.0286             # grunt_head y span -0.1317..+0.0745
HEAD_BONE = "mixamorig:Head"
LINEUP_X = {"michael": 0.0, "gus": 1.5, "sniper": 3.0, "zombie": 4.5}
REPORT = {}


def log(*a):
    print("[TH]", *a)


def save(tag):
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=OUT, copy=False)
    log("SAVED", tag, "->", OUT, "%.1f MB" % (os.path.getsize(OUT) / 1e6))


def link(o):
    if o.name not in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.link(o)


def append_objects(path, names):
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        missing = [n for n in names if n not in src.objects]
        if missing:
            raise RuntimeError(f"{path}: missing objects {missing}")
        dst.objects = list(names)
    for o in dst.objects:
        link(o)
    bpy.context.view_layer.update()
    return {o.name: o for o in dst.objects}


def world_verts(o, evaluated=True):
    if evaluated:
        dg = bpy.context.evaluated_depsgraph_get()
        oe = o.evaluated_get(dg)
        me = oe.to_mesh()
        vs = [oe.matrix_world @ v.co for v in me.vertices]
        oe.to_mesh_clear()
        return vs
    return [o.matrix_world @ v.co for v in o.data.vertices]


def tri_count(o):
    o.data.calc_loop_triangles()
    return len(o.data.loop_triangles)


def ngons(o):
    return sum(1 for p in o.data.polygons if len(p.vertices) > 4)


def set_closest(mat):
    if mat and mat.node_tree:
        for n in mat.node_tree.nodes:
            if n.type == 'TEX_IMAGE':
                n.interpolation = 'Closest'


def new_image_material(name, png, colour=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.9
    bsdf.inputs["Specular IOR Level"].default_value = 0.0
    if png:
        img = bpy.data.images.load(png, check_existing=True)
        img.pack()
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.interpolation = 'Closest'
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    elif colour:
        bsdf.inputs["Base Color"].default_value = (*colour, 1.0)
    return mat


# ----------------------------------------------------------------------------------------------- 0. scene
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.fps = FPS
sc.frame_start, sc.frame_end = 0, NFRAMES - 1
os.makedirs(OUT_DIR, exist_ok=True)

# ----------------------------------------------------------------------------------------------- 1. append
cast = append_objects(CAST, ["PSXRig_michael", "grunt_head_michael", "PSXRig_gus_ears", "grunt_head_gus_ears", "grunt_head_gus_arrival"])
base = append_objects(USBASE, ["PSXRig"])
rig_zombie = base["PSXRig"]; rig_zombie.name = "PSXRig_zombie"
snip = append_objects(SNIPER, ["PSXRig"])
rig_sniper = snip["PSXRig"]; rig_sniper.name = "PSXRig_sniper"
rig_michael, rig_gus = cast["PSXRig_michael"], cast["PSXRig_gus_ears"]
rig_gus.name = "PSXRig_gus"
helm = append_objects(HELMETS, ["m1_ace_socket_head", "m1_ace_cover", "m1_ace_band", "m1_ace_card_ace"])
# gus_arrival's head was appended without its rig: it exists only to be compared and deleted
head_arrival = cast["grunt_head_gus_arrival"]
for rig in (rig_michael, rig_gus, rig_zombie, rig_sniper):
    rig.location = (0, 0, 0)
    rig.hide_viewport = False; rig.hide_render = True; rig.hide_set(False)
bpy.context.view_layer.update()
for rig in (rig_michael, rig_gus, rig_zombie, rig_sniper):
    b = rig.data.bones[HEAD_BONE]
    log(f"rig {rig.name}: mode={rig.rotation_mode} quat={tuple(round(x,3) for x in rig.rotation_quaternion)} parent={rig.parent}")
    log(f"rig {rig.name}: bones={len(rig.data.bones)} rot={tuple(round(math.degrees(a),1) for a in rig.rotation_euler)} "
        f"delta_rot={tuple(round(math.degrees(a),1) for a in rig.delta_rotation_euler)} scale={tuple(round(x,3) for x in rig.scale)} "
        f"Head world head={tuple(round(x,4) for x in (rig.matrix_world @ b.head_local))}")
# the two Gus states: is one head enough?
def mesh_sig(o):
    uv = o.data.uv_layers.active
    return ([tuple(round(x, 6) for x in v.co) for v in o.data.vertices],
            [tuple(round(x, 6) for x in uv.data[l].uv) for l in range(len(o.data.loops))],
            [tuple(p.vertices) for p in o.data.polygons])
sa, sb = mesh_sig(head_arrival), mesh_sig(cast["grunt_head_gus_ears"])
uv_px = max((Vector(a) - Vector(b)).length for a, b in zip(sa[1], sb[1])) * 1296     # atlas px; the two heads were projected separately
gus_identical = sa[0] == sb[0] and sa[2] == sb[2] and uv_px < 0.01
log("gus_arrival vs gus_ears head: verts identical", sa[0] == sb[0], "uvs max dev %.4f px" % uv_px, "polys identical", sa[2] == sb[2])
REPORT["gus_states_identical"] = gus_identical
REPORT["gus_states_uv_max_dev_px"] = round(uv_px, 4)
bpy.data.objects.remove(head_arrival, do_unlink=True)
save("M0 appended")


# ----------------------------------------------------------------------------------------------- 2. human cutscene heads
# the 4 front quads become the animated face patch (th_face.py): rows/columns solved onto the PAINTED features of the
# cell via the same affine+shear tools/project_cow_head_uvs.py uses, mouth loops + cavity + teeth + tongue, 9 visemes.
sys.path.insert(0, os.path.join(R, "tools"))
import project_cow_head_uvs as P
import th_face as F


def luminance_sampler(img):
    w, h = img.size
    px = img.pixels[:]
    ch = img.channels

    def lum(u, v):
        x = min(w - 1, max(0, int(u * w))); y = min(h - 1, max(0, int(v * h)))
        i = (y * w + x) * ch
        return 0.2126 * px[i] + 0.7152 * px[i + 1] + 0.0722 * px[i + 2]
    return lum


def paint_gate(obj, idx, rows, S, name):
    """Read the loops' UVs back as cell pixels and compare with the painted features: the whole chain, not the intent."""
    me = obj.data
    uvl = me.uv_layers.active
    fi = [i for i, m in enumerate(me.materials) if m and m.name.startswith("face_atlas")]
    W, H, x0, y0 = S["W"], S["H"], S["x0"], S["y0"]
    vpx = {}
    for p in me.polygons:
        if p.material_index not in fi:
            continue
        for li, vi in zip(p.loop_indices, p.vertices):
            u, v = uvl.data[li].uv
            vpx.setdefault(vi, []).append((u * W - x0, (1.0 - v) * H - y0))

    def at(nm):
        pts = vpx[idx[nm]]
        return sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts)
    mm_x, mm_y = 1000.0 / S["sx"], 1000.0 / S["sz"]
    lip_dev = [abs(at(n)[1] - rows["lip_py"]) * mm_y for n in F.UPPER_EDGE + F.LOWER_EDGE[1:4]]
    eyes = {}
    for sd in ("L", "R"):
        c = [at(f"c2ll_{sd}"), at(f"c2ul_{sd}")]
        cxp, cyp = 0.5 * (c[0][0] + c[1][0]), 0.5 * (c[0][1] + c[1][1])
        ex, ey = rows[f"eye_{sd}"]
        eyes[sd] = dict(loop_centre_px=(round(cxp, 2), round(cyp, 2)), pupil_px=(ex + 0.5, ey + 0.5),
                        dev_mm=(round((cxp - ex - 0.5) * mm_x, 2), round((cyp - ey - 0.5) * mm_y, 2)))
    corners = {sd: round((at(f"L1_{sd}")[0] - (S["feat"]["mouth_l"] if sd == "L" else S["feat"]["mouth_r"])) * mm_x, 2) for sd in ("L", "R")}
    res = dict(lip_line_dev_mm_max=round(max(lip_dev), 2), lip_line_dev_mm_mean=round(sum(lip_dev) / len(lip_dev), 2),
               lip_line_z=round(me.vertices[idx["U0c"]].co.z, 4), painted_lip_row=rows["lip_py"],
               mouth_corner_dev_mm=corners, eyes=eyes, nostril_row_dev_mm=round((at("T2b_L")[1] - rows["nostril_py"]) * mm_y, 2),
               brow_row_px={sd: round(at(f"c2br_{sd}")[1], 2) for sd in ("L", "R")}, painted_brow_row=rows["brow_y_painted"] + 0.5)
    REPORT[f"paint_gate_{name}"] = res
    log(f"  {name} paint gate: {res}")
    assert res["lip_line_dev_mm_max"] <= 2.0, res
    for sd in ("L", "R"):
        assert abs(eyes[sd]["dev_mm"][0]) <= 2.0 and abs(eyes[sd]["dev_mm"][1]) <= 2.0, eyes[sd]
    return res


def build_cs_head(src, name, rig):
    me = src.data.copy(); me.name = f"cs_head_{name}"
    obj = bpy.data.objects.new(f"cs_head_{name}", me)
    link(obj)
    obj.parent = rig; obj.parent_type = src.parent_type
    obj.matrix_parent_inverse = src.matrix_parent_inverse.copy()
    obj.location, obj.rotation_euler, obj.scale = src.location, src.rotation_euler, src.scale
    for m in src.modifiers:
        if m.type == 'ARMATURE':
            am = obj.modifiers.new("Armature", 'ARMATURE'); am.object = rig
    for vg in src.vertex_groups:
        obj.vertex_groups.new(name=vg.name)
    bpy.context.view_layer.update()
    mouth_mat = bpy.data.materials.get("cs_mouth_interior") or new_image_material("cs_mouth_interior", os.path.join(TEX, "cs_mouth_interior.png"))
    if mouth_mat.name not in [m.name for m in me.materials if m]:
        me.materials.append(mouth_mat)
    S = P.solve_front(src, src.name)
    log(f"{name}: paint - mouth row {S['feat']['mouth'][1]} corners {S['feat']['mouth_l']:.2f}/{S['feat']['mouth_r']:.2f} "
        f"nostril {S['feat']['nostril_y']} eyes {S['feat']['eye_l']} {S['feat']['eye_r']} brow {S['feat']['brow_y']} chin {S['feat']['chin_y']}; "
        f"affine sx {S['sx']:.1f} sz {S['sz']:.1f} cx {S['cx']:.2f} K {S['K']:.1f}")
    idx, rows, ctx, n_cav = F.build_face(obj, src, S, mouth_mat, log, REPORT, name)
    REPORT[f"layout_{name}"] = rows
    # neck clamp: any loop sampling the black band of the atlas cell is lifted onto skin (the chin fan touches it)
    face_mat_index = [i for i, m in enumerate(me.materials) if m and m.name.startswith("face_atlas")][0]
    img = [n.image for n in me.materials[face_mat_index].node_tree.nodes if n.type == 'TEX_IMAGE' and n.image][0]
    lum = luminance_sampler(img)
    uvl = me.uv_layers.active
    lifted, found = 0, []
    for p in me.polygons:
        if p.material_index != face_mat_index:
            continue
        for li in p.loop_indices:
            u, v = uvl.data[li].uv
            L0 = lum(u, v)
            if v < 0.04 and L0 < 0.10:
                v2 = v
                for _ in range(12):
                    v2 += 1.0 / img.size[1]
                    if lum(u, v2) >= 0.16:
                        break
                v2 += 1.0 / img.size[1]
                found.append((me.loops[li].vertex_index, round(u, 4), round(v, 4), round(L0, 3), round(v2, 4)))
                uvl.data[li].uv = (u, v2); lifted += 1
    REPORT[f"neck_uv_{name}"] = {"loops_lifted": lifted, "samples": found[:12]}
    log(f"{name}: neck/black-band loops lifted: {lifted}")
    # full-cell projection (Caleb's ruling 2026-09-11) on the finished patch, then the paint read-back gate
    bpy.context.view_layer.update()
    proj = P.project_mesh(obj, obj.name)
    g = proj["groups"]
    assert (g["TOP"], g["HAIR"], g["LOWER"], g["EAR"]) == (4, 6, 2, 6) and g["SIDE"] >= 6 and "NECK" not in g, g
    REPORT[f"projection_{name}"] = proj
    paint_gate(obj, idx, rows, S, name)
    # shape keys + viseme measurements
    F.add_shape_keys(obj, idx, ctx, log, REPORT, name)
    F.measure_visemes(obj, idx, log, REPORT, name)
    obj["th_vert_index"] = json.dumps(idx)
    # gates ----------------------------------------------------------------------------------------------------
    dev = max((me.vertices[i].co - src.data.vertices[i].co).length for i in F.NECK_RING)
    dev_all = max((me.vertices[i].co - src.data.vertices[i].co).length for i in range(len(src.data.vertices)))
    tris = tri_count(obj)
    face_tris = sum(len(p.vertices) - 2 for p in me.polygons if p.material_index == face_mat_index)
    cav_tris = sum(len(p.vertices) - 2 for p in me.polygons if p.material_index != face_mat_index)
    poly_sizes = {}
    for p in me.polygons:
        poly_sizes[len(p.vertices)] = poly_sizes.get(len(p.vertices), 0) + 1
    info = {"verts": len(me.vertices), "verts_added": len(me.vertices) - len(src.data.vertices), "tris": tris,
            "face_material_tris": face_tris, "cavity_tris": cav_tris, "polys_by_size": poly_sizes,
            "ngons": ngons(obj), "neck_ring_max_dev_m": dev, "all_orig_verts_max_dev_m": dev_all, "cavity_faces": n_cav}
    REPORT[f"head_{name}"] = info
    log(name, info)
    assert dev == 0.0, f"neck ring moved: {dev}"
    assert info["ngons"] == 0
    assert tris <= 450, tris
    for k, mm in REPORT[f"shape_keys_{name}"].items():
        assert k == "X" or mm >= 2.0, f"{name}.{k} moves only {mm} mm"
    assert REPORT[f"shape_keys_{name}"]["X"] == 0.0
    unweighted = sum(1 for v in me.vertices if not v.groups or sum(g.weight for g in v.groups) < 0.99)
    log(f"  {name}: verts with weight sum < 0.99: {unweighted}")
    assert unweighted == 0
    used = set()
    for p in me.polygons:
        used.update(p.vertices)
    loose = len(me.vertices) - len(used)
    assert loose == 0, loose
    for m in me.materials:
        set_closest(m)
    return obj


cs_michael = build_cs_head(cast["grunt_head_michael"], "michael", rig_michael)
cs_gus = build_cs_head(cast["grunt_head_gus_ears"], "gus", rig_gus)
for o in (cast["grunt_head_michael"], cast["grunt_head_gus_ears"]):
    o.hide_render = True; o.hide_set(True)      # gameplay heads kept in-file as the swap reference, hidden
save("M1 human heads")


# ----------------------------------------------------------------------------------------------- 3. the skull
def load_reference():
    before = set(bpy.data.objects)
    bpy.ops.wm.obj_import(filepath=SKULL_OBJ)
    ref = [o for o in bpy.data.objects if o not in before][0]
    bpy.ops.object.select_all(action='DESELECT'); ref.select_set(True); bpy.context.view_layer.objects.active = ref
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bm = bmesh.new(); bm.from_mesh(ref.data); bm.verts.ensure_lookup_table()
    comp = {}; cid = 0; seen = set()
    for v in bm.verts:
        if v.index in seen: continue
        stack = [v]; zs = []
        members = []
        while stack:
            c = stack.pop()
            if c.index in seen: continue
            seen.add(c.index); members.append(c.index); zs.append(c.co.z)
            for e in c.link_edges:
                ov = e.other_vert(c)
                if ov.index not in seen: stack.append(ov)
        comp[cid] = (members, max(zs)); cid += 1
    sizes = sorted(comp.items(), key=lambda kv: -len(kv[1][0]))
    cranium_id, mandible_id = sizes[0][0], sizes[1][0]
    upper_ids = {c for c, (m, zmax) in comp.items() if c not in (cranium_id, mandible_id) and zmax > -1.10}
    lower_ids = {c for c, (m, zmax) in comp.items() if c not in (cranium_id, mandible_id) and zmax <= -1.10}
    vert_comp = {}
    for c, (m, _) in comp.items():
        for i in m: vert_comp[i] = c
    def part(name, keep):
        b = bmesh.new(); b.from_mesh(ref.data); b.verts.ensure_lookup_table()
        bmesh.ops.delete(b, geom=[v for v in b.verts if vert_comp[v.index] not in keep], context='VERTS')
        m = bpy.data.meshes.new(name); b.to_mesh(m); b.free()
        o = bpy.data.objects.new(name, m); link(o); return o
    cr = part("_ref_cranium", {cranium_id} | upper_ids)
    md = part("_ref_mandible", {mandible_id} | lower_ids)
    bm.free()
    bpy.data.objects.remove(ref, do_unlink=True)
    bpy.context.view_layer.update()
    log(f"reference split: cranium+upper teeth {len(cr.data.vertices)} v, mandible+lower teeth {len(md.data.vertices)} v")
    return cr, md


def ray_in(obj, target, direction, dist=4.0):
    """Cast from outside (target + direction*dist) back toward target; returns hit point or None."""
    d = Vector(direction).normalized()
    hit, loc, nrm, idx = obj.ray_cast(Vector(target) + d * dist, -d)
    return loc.copy() if hit else None


def build_skull_meshes(rig):
    cr, md = load_reference()
    C = Vector(S.CR_CENTRE); s = SKULL_SCALE
    z0 = SKULL_TOP_Z - 1.0687 * s
    y0 = PSX_HEAD_Y_CENTRE - ((-1.0644 + 1.4822) / 2.0) * s
    T = Vector((0.0, y0, z0))
    REPORT["skull_placement"] = {"scale": s, "y0": y0, "z0": z0}
    def to_world(p):
        return Vector(p) * s + T
    # ---- cranium cage
    rows = []
    for name, kind, val in S.CR_ROWS:
        if kind == "phi":
            phi = math.radians(val)
        else:
            phi = math.atan2(-(S.CR_FRONT_Y) + C.y, val - C.z)     # angle from +Z to the front point at this z
        rows.append((name, phi))
    cage = {}                # (row_i, col_i) -> Vector (ref units)
    depth_report = {}
    for ri, (rname, phi) in enumerate(rows):
        for ci, th in enumerate(S.CR_COLS):
            t = math.radians(th)
            d = Vector((math.sin(phi) * math.sin(t), -math.sin(phi) * math.cos(t), math.cos(phi)))
            p = ray_in(cr, C, d)
            if p is None:
                res, loc, nrm, idx = cr.closest_point_on_mesh(C + d * 1.2)
                p = loc.copy(); depth_report[(rname, th)] = "MISS->closest"
            cage[(ri, ci)] = p
    # nasal aperture: the centre column at the nasal row becomes a hole floor
    nasal_ri = [r[0] for r in S.CR_ROWS].index("nasal")
    c0 = S.CR_COLS.index(0)
    p = cage[(nasal_ri, c0)]; cage[(nasal_ri, c0)] = Vector((0.0, -0.70, p.z))
    top = ray_in(cr, C, Vector((0, 0, 1)))
    bot = ray_in(cr, C, Vector((0, 0, -1)))
    orb = {f"{k[0]}@{k[1]}deg": round(cage[([r[0] for r in S.CR_ROWS].index(k[0]), S.CR_COLS.index(k[1]))].y, 3) for k in
           (("orbU", 16), ("orbU", 25), ("orbL", 16), ("orbL", 25), ("brow", 16), ("cheek", 25), ("orbU", 8), ("orbU", 34), ("orbU", 0))}
    log("orbit depths (ref y; front skin ~ -0.95, socket floor ~ -0.50):", orb)
    REPORT["orbit_depths_ref"] = orb
    me = bpy.data.meshes.new("cs_skull")
    bm = bmesh.new(); uv_lay = bm.loops.layers.uv.new("UVMap")
    V = {}
    for k, p in cage.items():
        V[k] = bm.verts.new(to_world(p))
    vtop = bm.verts.new(to_world(top)); vbot = bm.verts.new(to_world(bot))
    nc = len(S.CR_COLS); nr = len(rows)
    def u_of(ci, wrap_right):
        th = S.CR_COLS[ci]
        if th == 180 and not wrap_right:
            return 0.0
        return S.cr_u(th)
    faces = []
    for ci in range(nc):
        cj = (ci + 1) % nc
        seam = (cj == 0)          # face between col 180 (ci=last) and col -125 (cj=0)
        uc = u_of(ci, wrap_right=not seam); uj = u_of(cj, wrap_right=True) if not seam else S.cr_u(S.CR_COLS[0])
        if seam:
            uc = 0.0
        # top fan
        f = bm.faces.new((vtop, V[(0, ci)], V[(0, cj)])); faces.append(f)
        f.loops[0][uv_lay].uv = ((uc + uj) / 2, S.CR_V_TOP); f.loops[1][uv_lay].uv = (uc, S.cr_ring_v(0)); f.loops[2][uv_lay].uv = (uj, S.cr_ring_v(0))
        for ri in range(nr - 1):
            f = bm.faces.new((V[(ri, ci)], V[(ri + 1, ci)], V[(ri + 1, cj)], V[(ri, cj)])); faces.append(f)
            f.loops[0][uv_lay].uv = (uc, S.cr_ring_v(ri)); f.loops[1][uv_lay].uv = (uc, S.cr_ring_v(ri + 1))
            f.loops[2][uv_lay].uv = (uj, S.cr_ring_v(ri + 1)); f.loops[3][uv_lay].uv = (uj, S.cr_ring_v(ri))
        f = bm.faces.new((vbot, V[(nr - 1, cj)], V[(nr - 1, ci)])); faces.append(f)
        f.loops[0][uv_lay].uv = ((uc + uj) / 2, S.CR_V_BOT); f.loops[1][uv_lay].uv = (uj, S.cr_ring_v(nr - 1)); f.loops[2][uv_lay].uv = (uc, S.cr_ring_v(nr - 1))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me); bm.free()
    skull = bpy.data.objects.new("cs_skull", me); link(skull)
    # ---- mandible cage
    M = Vector(S.MD_AXIS)
    md_pts = {}
    for ci, th in enumerate(S.MD_COLS):
        t = math.radians(th); dirh = Vector((math.sin(t), -math.cos(t), 0.0))
        ztop = S.MD_TOP_Z.get(abs(th), S.MD_TOP_Z_BODY)
        # lowest z with a horizontal hit
        zbot = None
        z = -1.85
        while z < ztop:
            if ray_in(md, Vector((M.x, M.y, z)), dirh) is not None:
                zbot = z; break
            z += 0.01
        assert zbot is not None, th
        zmid = 0.5 * (ztop + zbot)
        outer = []
        for z in (ztop, zmid, zbot + 0.02):
            p = ray_in(md, Vector((M.x, M.y, z)), dirh)
            if p is None:
                res, loc, nrm, idx = md.closest_point_on_mesh(Vector((M.x, M.y, z)) + dirh * 0.7); p = loc.copy()
            outer.append(p)
        if abs(th) == 78:                                   # condyle column: pin the top to the measured condyle
            outer[0] = Vector((math.copysign(S.CONDYLE[0], th), S.CONDYLE[1], S.CONDYLE[2]))
        inner_bot = outer[2] - dirh * S.MD_THICK
        inner_top = outer[0] - dirh * S.MD_THICK
        md_pts[ci] = [outer[0], outer[1], outer[2], inner_bot, inner_top]
    me2 = bpy.data.meshes.new("cs_mandible")
    bm = bmesh.new(); uv_lay = bm.loops.layers.uv.new("UVMap")
    MV = {(ci, ri): bm.verts.new(to_world(p)) for ci, pts in md_pts.items() for ri, p in enumerate(pts)}
    for ci in range(len(S.MD_COLS) - 1):
        cj = ci + 1
        uc, uj = S.md_u(S.MD_COLS[ci]), S.md_u(S.MD_COLS[cj])
        for ri in range(5):
            rj = (ri + 1) % 5
            f = bm.faces.new((MV[(ci, ri)], MV[(cj, ri)], MV[(cj, rj)], MV[(ci, rj)]))
            vr, vj = S.MD_ROW_V[ri], S.MD_ROW_V[rj]
            if rj == 0: vj = -0.02                                 # closing strip inner_top -> outer_top (bite surface): wraps below
            f.loops[0][uv_lay].uv = (uc, vr); f.loops[1][uv_lay].uv = (uj, vr); f.loops[2][uv_lay].uv = (uj, vj); f.loops[3][uv_lay].uv = (uc, vj)
    for ci in (0, len(S.MD_COLS) - 1):
        verts = [MV[(ci, ri)] for ri in range(5)]
        f = bm.faces.new(verts if ci == 0 else verts[::-1])
        for l in f.loops:
            l[uv_lay].uv = (S.md_u(S.MD_COLS[ci]), 0.10)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me2); bm.free()
    mand = bpy.data.objects.new("cs_mandible", me2); link(mand)
    for o in (cr, md):
        bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.meshes):
        if m.users == 0: bpy.data.meshes.remove(m)
    bpy.context.view_layer.update()
    # proportions (mesh-local = Z-up world with rig at origin)
    def dims(o):
        vs = [v.co for v in o.data.vertices]
        return (max(v.x for v in vs) - min(v.x for v in vs), max(v.y for v in vs) - min(v.y for v in vs), max(v.z for v in vs) - min(v.z for v in vs))
    W, L, H = dims(skull); mW, mL, mH = dims(mand)
    zs = [v.co.z for v in skull.data.vertices] + [v.co.z for v in mand.data.vertices]
    Htot = max(zs) - min(zs)
    orbU = [r[0] for r in S.CR_ROWS].index("orbU"); orbL = [r[0] for r in S.CR_ROWS].index("orbL")
    oc_l = (cage[(orbU, S.CR_COLS.index(-16))] + cage[(orbU, S.CR_COLS.index(-25))] + cage[(orbL, S.CR_COLS.index(-16))] + cage[(orbL, S.CR_COLS.index(-25))]) / 4
    oc_r = (cage[(orbU, S.CR_COLS.index(16))] + cage[(orbU, S.CR_COLS.index(25))] + cage[(orbL, S.CR_COLS.index(16))] + cage[(orbL, S.CR_COLS.index(25))]) / 4
    orbit_spacing = (oc_r - oc_l).x * s
    prop = {"cranium_W_m": W, "cranium_L_m": L, "cranium_H_m": H, "total_H_m": Htot, "W_over_Htot": W / Htot, "L_over_Htot": L / Htot,
            "W_over_L": W / L, "orbit_centre_spacing_m": orbit_spacing, "orbit_spacing_over_W": orbit_spacing / W,
            "ref_W_over_Htot": 1.9205 / 2.8517, "ref_L_over_Htot": 2.5467 / 2.8517, "ref_orbit_spacing_over_W": 0.72 / 1.9205,
            "skull_tris": tri_count(skull), "skull_verts": len(skull.data.vertices), "mandible_tris": tri_count(mand), "mandible_verts": len(mand.data.vertices),
            "ngons": ngons(skull) + ngons(mand)}
    REPORT["skull_proportions"] = prop
    log("skull proportions", {k: (round(v, 4) if isinstance(v, float) else v) for k, v in prop.items()})
    return skull, mand, to_world(Vector(S.CONDYLE)), to_world(Vector((-S.CONDYLE[0], S.CONDYLE[1], S.CONDYLE[2])))


skull, mand, condyle_r, condyle_l = build_skull_meshes(rig_zombie)
hinge = (condyle_r + condyle_l) / 2
REPORT["jaw_hinge_world_m"] = tuple(round(x, 4) for x in hinge)
log("jaw hinge (Z-up, rig at origin):", REPORT["jaw_hinge_world_m"])


def attach_to_rig(obj, rig, template):
    """Parent like the rig's own head mesh does (rotation -90 X child of a +90 X rig; vertex data Z-up)."""
    obj.parent = rig; obj.parent_type = 'OBJECT'
    obj.matrix_parent_inverse = Matrix.Identity(4)
    obj.location = (0, 0, 0); obj.rotation_euler = template; obj.scale = (1, 1, 1)
    am = obj.modifiers.new("Armature", 'ARMATURE'); am.object = rig


def add_jaw_bone(rig, hinge_local, mesh_obj):
    """hinge_local is in the skull mesh's local (Z-up) space; route it through the MESH object's world matrix so a scaled
    rig (VC/NVA 0.952) gets the bone exactly where its skull's condyle sits."""
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active = rig
    inv = rig.matrix_world.inverted()
    hinge_world = mesh_obj.matrix_world @ hinge_local
    tail_world = mesh_obj.matrix_world @ (hinge_local + Vector((0.0, -0.06, -0.03)))
    bpy.ops.object.mode_set(mode='EDIT')
    eb = rig.data.edit_bones
    if "jaw" in eb:
        eb.remove(eb["jaw"])
    j = eb.new("jaw")
    j.head = inv @ hinge_world
    j.tail = inv @ tail_world
    j.parent = eb[HEAD_BONE]; j.use_connect = False; j.roll = 0.0
    bpy.ops.object.mode_set(mode='OBJECT')
    rig.data.pose_position = 'POSE'
    pb = rig.pose.bones["jaw"]; pb.rotation_mode = 'QUATERNION'
    # world +X expressed in the bone's rest-local frame = the hinge axis
    axis_local = (rig.matrix_world @ rig.data.bones["jaw"].matrix_local).to_3x3().inverted() @ Vector((1, 0, 0))
    axis_local.normalize()
    log(f"{rig.name}: jaw bone added at world {tuple(round(x,4) for x in hinge_world)}; bones={len(rig.data.bones)}; hinge axis in bone space={tuple(round(x,3) for x in axis_local)}")
    return axis_local


def jaw_quat(axis_local, deg):
    return Quaternion(axis_local, math.radians(deg))


def skin_100(obj, group):
    vg = obj.vertex_groups.get(group) or obj.vertex_groups.new(name=group)
    vg.add(list(range(len(obj.data.vertices))), 1.0, 'REPLACE')


template_rot = cast["grunt_head_michael"].rotation_euler.copy()
attach_to_rig(skull, rig_zombie, template_rot); attach_to_rig(mand, rig_zombie, template_rot)
skin_100(skull, HEAD_BONE); skin_100(mand, "jaw")
jaw_axis = {}
jaw_axis["zombie"] = add_jaw_bone(rig_zombie, hinge, mand)
rig_zombie["jaw_axis"] = list(jaw_axis["zombie"])
# sniper: linked duplicates of the same mesh data under his own (0.952) rig
skull_s = bpy.data.objects.new("cs_skull_sniper", skull.data); link(skull_s)
mand_s = bpy.data.objects.new("cs_mandible_sniper", mand.data); link(mand_s)
attach_to_rig(skull_s, rig_sniper, template_rot); attach_to_rig(mand_s, rig_sniper, template_rot)
# vertex-group INDICES live in the shared mesh, group NAMES live on the object: create the sniper objects' groups in the
# same order as the zombie objects'. NEVER remove a group on a linked duplicate - that strips the weights from the shared mesh.
for src_o, dst_o in ((skull, skull_s), (mand, mand_s)):
    for vg in src_o.vertex_groups:
        dst_o.vertex_groups.new(name=vg.name)
jaw_axis["sniper"] = add_jaw_bone(rig_sniper, hinge, mand_s)
rig_sniper["jaw_axis"] = list(jaw_axis["sniper"])
skull.name, mand.name = "cs_skull_zombie", "cs_mandible_zombie"
bpy.context.view_layer.update()


def key_identity_pose(rig, frame=0):
    for pb in rig.pose.bones:
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0); pb.scale = (1, 1, 1)
        pb.keyframe_insert("rotation_quaternion", frame=frame); pb.keyframe_insert("location", frame=frame)


for rig in (rig_michael, rig_gus, rig_zombie, rig_sniper):
    rig.data.pose_position = 'POSE'
    key_identity_pose(rig, 0)
bpy.context.view_layer.update()


def inside_by_parity(obj, p_local, direction=Vector((0.37, 0.61, 0.70))):
    """Closed-mesh inside test: odd number of surface crossings along a ray = inside. Immune to the nearest-face edge trap."""
    d = direction.normalized(); origin = p_local.copy(); n = 0
    for _ in range(64):
        hit, loc, nrm, idx = obj.ray_cast(origin, d)
        if not hit:
            break
        n += 1; origin = loc + d * 1e-5
    return n % 2 == 1


def eval_copy(o, name):
    dg = bpy.context.evaluated_depsgraph_get()
    oe = o.evaluated_get(dg); me = oe.to_mesh()
    tmp = bpy.data.objects.new(name, me.copy()); link(tmp); tmp.matrix_world = oe.matrix_world.copy()
    oe.to_mesh_clear(); bpy.context.view_layer.update()
    return tmp


def jaw_gate(rig, skull_o, mand_o, axis_local, deg):
    pb = rig.pose.bones["jaw"]
    pb.rotation_quaternion = jaw_quat(axis_local, deg); pb.keyframe_insert("rotation_quaternion", frame=0)
    bpy.context.view_layer.update()
    tmp = eval_copy(skull_o, "_tmp_skull_eval")
    inv = tmp.matrix_world.inverted(); scl = tmp.matrix_world.to_scale().x
    mv = world_verts(mand_o, evaluated=True)
    inside_list = []; tooth_clear = 1e9; body_clear = 1e9
    tips_i = [r[0] for r in S.CR_ROWS].index("tips"); alv_i = tips_i - 1
    # upper tooth strip faces = cage quads between rows alv and tips within |theta| <= TEETH_COL: test distance to those only
    for vi, p in enumerate(mv):
        col, row = S.MD_COLS[vi // 5], S.MD_ROWS[vi % 5]
        pl = inv @ p
        if inside_by_parity(tmp, pl):
            inside_list.append((col, row))
        res, loc, nrm, idx = tmp.closest_point_on_mesh(pl)
        dist = (pl - loc).length * scl
        if row == "outer_top" and abs(col) <= S.TEETH_COL:
            tooth_clear = min(tooth_clear, dist)
        body_clear = min(body_clear, dist)
    chin = min(mv, key=lambda v: v.z)
    bpy.data.objects.remove(tmp, do_unlink=True)
    return {"deg": deg, "mandible_verts_inside_skull": len(inside_list), "inside_list": inside_list,
            "lower_tooth_row_to_skull_min_mm": round(tooth_clear * 1000, 2), "any_vert_to_skull_min_mm": round(body_clear * 1000, 2),
            "chin_world": tuple(round(x, 4) for x in chin)}


def push_out_of_cage(skull_o, mand_o):
    """The condyle sits in the glenoid fossa, i.e. inside the coarse cage: move any mandible vert that tests inside onto the cage
    surface + 3 mm along its normal (mesh-local = Z-up). Reports what moved."""
    moved = []
    for vi, v in enumerate(mand_o.data.vertices):
        if inside_by_parity(skull_o, v.co):
            res, loc, nrm, idx = skull_o.closest_point_on_mesh(v.co)
            new = loc + nrm * 0.003
            moved.append((S.MD_COLS[vi // 5], S.MD_ROWS[vi % 5], round((new - v.co).length * 1000, 1)))
            v.co = new
    mand_o.data.update()
    log("   mandible verts pushed out of the cage (col, row, mm):", moved)
    REPORT["mandible_verts_pushed_out"] = moved
    return moved


bpy.context.view_layer.update()
push_out_of_cage(skull, mand)

for tag, rig, sk_o, md_o in (("zombie", rig_zombie, skull, mand), ("sniper", rig_sniper, skull_s, mand_s)):
    rest = jaw_gate(rig, sk_o, md_o, jaw_axis[tag], 0.0)
    open25 = jaw_gate(rig, sk_o, md_o, jaw_axis[tag], 25.0)
    drop = (Vector(rest["chin_world"]) - Vector(open25["chin_world"])).length
    REPORT[f"jaw_gate_{tag}"] = {"rest": rest, "open25": open25, "chin_travel_mm": round(drop * 1000, 1)}
    log(f"jaw gate {tag}: rest {rest} | open25 {open25} | chin travel {drop*1000:.1f} mm")
    assert open25["mandible_verts_inside_skull"] == 0, "open jaw intersects the skull"
    assert rest["mandible_verts_inside_skull"] == 0, "rest jaw intersects the skull"
    assert open25["lower_tooth_row_to_skull_min_mm"] > 3.0, "open jaw does not clear the upper teeth"
    assert drop > 0.02, "jaw did not open"
    rig.pose.bones["jaw"].rotation_quaternion = (1, 0, 0, 0); rig.pose.bones["jaw"].keyframe_insert("rotation_quaternion", frame=0)
save("M2 skull")


# ----------------------------------------------------------------------------------------------- 4. dressings + helmet
mat_sn = new_image_material("cs_skull_sniper_mat", os.path.join(TEX, "cs_skull_sniper_atlas.png"))
mat_zb = new_image_material("cs_skull_zombie_mat", os.path.join(TEX, "cs_skull_zombie_atlas.png"))
for me_ in (skull.data, mand.data):
    me_.materials.clear(); me_.materials.append(mat_zb)
for o in (skull, mand):
    o.material_slots[0].link = 'OBJECT'; o.material_slots[0].material = mat_zb
for o in (skull_s, mand_s):
    o.material_slots[0].link = 'OBJECT'; o.material_slots[0].material = mat_sn
# helmet: m1_ace (the comic's beat is an ace in the band, Issue 1 back cover) on the ZOMBIE skull, socket placed by helmets.json
sock = helm["m1_ace_socket_head"]
parts = [helm["m1_ace_cover"], helm["m1_ace_band"], helm["m1_ace_card_ace"]]
rel = {p.name: sock.matrix_world.inverted() @ p.matrix_world for p in parts}
meta = json.load(open(HELMET_JSON))["socket"]
mb = Matrix([list(r) for r in meta["matrix_basis"]])
sock.parent = rig_zombie; sock.parent_type = 'BONE'; sock.parent_bone = meta["bone"]
sock.matrix_parent_inverse = Matrix.Identity(4); sock.matrix_basis = mb
bpy.context.view_layer.update()
sock_world = sock.matrix_world.translation.copy()
log("helmet socket world (json route):", tuple(round(x, 4) for x in sock_world), " expected from FIT_socket in helmet_variants: (0.002, -0.041, 1.752)")
REPORT["helmet_socket_world"] = tuple(round(x, 4) for x in sock_world)
if (sock_world - Vector((0.002, -0.041, 1.752))).length > 0.01:
    log("json route disagrees with the FIT truth by >10 mm -> placing on the FIT truth position, same orientation")
    sock.matrix_world = Matrix.Translation(Vector((0.002, -0.041, 1.752))) @ sock.matrix_world.to_3x3().to_4x4()
    bpy.context.view_layer.update()
for p in parts:
    p.parent = sock; p.parent_type = 'OBJECT'; p.matrix_parent_inverse = Matrix.Identity(4)
    p.matrix_basis = rel[p.name]
    p.name = "cs_zombie_" + p.name.replace("m1_ace_", "helmet_")
bpy.context.view_layer.update()
cover = bpy.data.objects["cs_zombie_helmet_cover"]
card = bpy.data.objects["cs_zombie_helmet_card_ace"]
clubs = new_image_material("HelmCardClubs", os.path.join(TEX, "helmet_card_ace_clubs.png"))
for i, slot in enumerate(card.material_slots):
    slot.link = 'OBJECT'; slot.material = clubs
for p in parts:
    for m in p.data.materials: set_closest(m)
# helmet fit gate (ray from the cranium centre through each skull vert): a cover hit BEYOND the vert = covered with that
# clearance; a cover hit BEFORE the vert = the skull pokes through; no hit = not under the helmet footprint (face, jaw).
ROW_Z = {name: SKULL_TOP_Z - 1.0687 * SKULL_SCALE + (val if kind == "z" else 0.0) * SKULL_SCALE for name, kind, val in S.CR_ROWS}
centre_w = skull.matrix_world @ (Vector(S.CR_CENTRE) * SKULL_SCALE + Vector((0.0, REPORT["skull_placement"]["y0"], REPORT["skull_placement"]["z0"])))


def helmet_fit(tag):
    covt = eval_copy(cover, "_tmp_cover_eval")
    inv = covt.matrix_world.inverted()
    through, covered, clear = 0, 0, []
    for p in world_verts(skull, evaluated=True):
        d = p - centre_w; L = d.length; dn = d / L
        o = inv @ centre_w; dl = (inv.to_3x3() @ dn).normalized()
        hits = []; org = o.copy()
        for _ in range(8):
            hit, loc, nrm, idx = covt.ray_cast(org, dl)
            if not hit: break
            hits.append((covt.matrix_world @ loc - centre_w).length); org = loc + dl * 1e-4
        if not hits: continue
        covered += 1
        before = [t for t in hits if t < L - 1e-4]
        if before:
            through += 1
        else:
            clear.append(min(hits) - L)
    cov_vs = world_verts(cover, evaluated=False)
    ymin = min(v.y for v in cov_vs)
    brim_front_z = min(v.z for v in cov_vs if v.y < ymin + 0.03)
    crown_z = max(v.z for v in cov_vs); skull_top = max(v.z for v in world_verts(skull, evaluated=True))
    supraorbital_z = REPORT["skull_placement"]["z0"] + (-0.03) * SKULL_SCALE
    bpy.data.objects.remove(covt, do_unlink=True)
    res = {"skull_verts_through_shell": through, "skull_verts_under_helmet": covered,
           "clearance_mm_min_max": (round(min(clear) * 1000, 1), round(max(clear) * 1000, 1)) if clear else None,
           "brim_front_z": round(brim_front_z, 4), "supraorbital_margin_z": round(supraorbital_z, 4),
           "brim_minus_supraorbital_mm": round((brim_front_z - supraorbital_z) * 1000, 1),
           "crown_z": round(crown_z, 4), "crown_over_skull_top_mm": round((crown_z - skull_top) * 1000, 1)}
    REPORT[f"helmet_fit_{tag}"] = res
    log(f"helmet fit [{tag}]", res)
    return res


canon = helmet_fit("canonical_psx_head_seat")
dz = (canon["supraorbital_margin_z"] + 0.003) - canon["brim_front_z"]
sock.matrix_world = Matrix.Translation(Vector((0.0, 0.0, dz))) @ sock.matrix_world
bpy.context.view_layer.update()
REPORT["helmet_raise_applied_mm"] = round(dz * 1000, 1)
log(f"helmet raised {dz*1000:.1f} mm from the gameplay PSX-head seat so the brim sits at the skull's supraorbital margin")
seated = helmet_fit("seated_brim_at_brow")
assert seated["skull_verts_through_shell"] == 0, "skull pokes through the helmet shell"
save("M3 dressings + helmet")


# ----------------------------------------------------------------------------------------------- 5. actions
# No flap test: mouths are driven from recorded lines by th_lipsync.py (Rhubarb cues -> viseme keys / jaw angle).
# Each rig keeps ONE action holding its keyed identity pose at frame 0; lipsync keys into the same actions.
for tag, rig in (("michael", rig_michael), ("gus", rig_gus), ("sniper", rig_sniper), ("zombie", rig_zombie)):
    rig.animation_data.action.name = f"anim_{tag}"
    log(f"{tag}: rig action {rig.animation_data.action.name}, jaw bone {'jaw' in rig.pose.bones}")
sc.frame_set(0)

# ----------------------------------------------------------------------------------------------- 6. lineup + save
for tag, rig in (("michael", rig_michael), ("gus", rig_gus), ("sniper", rig_sniper), ("zombie", rig_zombie)):
    rig.location.x = LINEUP_X[tag]
bpy.context.view_layer.update()
for o in list(bpy.data.objects):
    if o.name.startswith("_") or o.name == "Icosphere" or o.name == "PSXRig_gus_arrival":   # glTF bone-display furniture; the compare head's rig
        bpy.data.objects.remove(o, do_unlink=True)
# the appended rigs drag their whole Mixamo library along on NLA tracks; a cutscene head file needs only its talk tests
for rig in (rig_michael, rig_gus, rig_zombie, rig_sniper):
    ad = rig.animation_data
    if ad:
        for t in list(ad.nla_tracks):
            ad.nla_tracks.remove(t)
keep = {"anim_michael", "anim_gus", "anim_sniper", "anim_zombie"}
for a in list(bpy.data.actions):
    if a.name not in keep:
        a.use_fake_user = False
        bpy.data.actions.remove(a)
for m in list(bpy.data.meshes):
    if m.users == 0: bpy.data.meshes.remove(m)
for m in list(bpy.data.materials):
    if m.users == 0: bpy.data.materials.remove(m)
for i in list(bpy.data.images):
    if i.users == 0 or i.name.startswith("Skull-Low"):
        bpy.data.images.remove(i)
for k in list(bpy.data.armatures):
    if k.users == 0: bpy.data.armatures.remove(k)
REPORT["objects"] = sorted(o.name for o in bpy.data.objects)
REPORT["actions"] = sorted(a.name for a in bpy.data.actions)
REPORT["images"] = sorted((i.name, tuple(i.size), bool(i.packed_file)) for i in bpy.data.images)
REPORT["materials"] = sorted(m.name for m in bpy.data.materials)
save("M4 final")
with open(os.path.join(OUT_DIR, "build_report.json"), "w") as fh:
    json.dump(REPORT, fh, indent=1, default=str)
log("REPORT written")
