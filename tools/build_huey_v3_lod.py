"""Build assets/us/vehicles/huey_v3_lod.glb from the SHIPPING huey_v3.glb.

    blender -b --factory-startup --python build_huey_v3_lod.py

Never opens or writes huey_v3.blend. Reads huey_v3.glb, rebuilds the four objects
that carry 93.5% of its triangles, bakes the marking art down to textured quads,
merges the static hull by material, and re-exports with the SAME gltf settings
tools/export_huey_v3.py uses, so the result is a drop-in swap.

WHERE THE 60,354 TRIANGLES WERE (measured off the shipping GLB, re-import count):
    MARK_ARMY_l_M / _r_M   12,000 tris EACH - a 0.69 m "ARMY" decal shrinkwrapped
                           onto the boom. 39.8% of the airframe.
    pintle_l_m60 / _r_m60  10,552 tris EACH, 8 materials each. 35.0%.
    V[ABC]_* marking text   6,710 across 18 objects. 11.1%.
    rack_m16_* / rack_m79   2,638 - cabin weapon rack, 11 more materials.
    fuselage_fwd/aft        3,464 - the only geometry that is actually the Huey.
Everything else - hull panels, skids, doors, rotors, seats, cockpit - is 2,438
tris across 73 objects, mostly 12-tri boxes that cannot be improved.

MARKINGS ARE AUTHORED IDENTITY, NOT CLUTTER (Caleb's call, via the coordinator):
helicopter.gd::_pick_markings shows exactly one VARIANT set per ship so a flight
of slicks does not read as the same airframe repeated. So every marking is
rebuilt as a 2-tri TEXTURED quad in the same plane, position and size as the
original, sampling one baked alpha atlas (huey_v3_lod_markings.png). 22 decals
cost 44 triangles instead of 30,710 and the art survives.

THE NAME CONTRACT was established by scanning every .gd/.tscn/.tres in the repo
for each of the 156 object names as a BARE SUBSTRING (not a quoted literal - the
quoted search MISSED heli_lift.gd's `_door_l`, which is real). 31 names are
referenced; see REFERENCED below. Those stay separate objects. Meshes hanging off
a node that code drives stay where they are. Everything else merges by material.
"""
import bpy, bmesh, os, sys, json, math
from mathutils import Vector

REPO = r"C:\Users\caleb\RECONgame"
SRC = os.path.join(REPO, "assets", "us", "vehicles", "huey_v3.glb")
OUT = os.path.join(REPO, "assets", "us", "vehicles", "huey_v3_lod.glb")
TEX = os.path.join(REPO, "assets", "us", "vehicles", "huey_v3_lod_markings.png")
SCRATCH = os.path.dirname(os.path.abspath(__file__))

# ---- names the game code looks up (bare-substring scan, 2026-09-11) ----------
REFERENCED = {
    "MainRotorMast", "TailRotorMast", "New_Blade_1", "New_Blade_2", "New_Rotor_Hub",
    "New_TailBlade_2_002", "VARIANT_A", "VARIANT_B", "VARIANT_C",
    "door_l", "door_r", "fuselage_aft", "fuselage_fwd",
    "seat_bench_1", "seat_bench_2", "seat_bench_3", "seat_bench_4", "seat_bench_5",
    "seat_bench_6", "seat_gunner_l", "seat_gunner_r", "seat_pax_1", "seat_pax_2",
    "seat_pax_3", "seat_pax_4", "seat_pax_5", "seat_pax_6", "seat_pax_7",
    "seat_pax_8", "seat_pilot_l", "seat_pilot_r",
}
# Nodes whose transform game code drives. Any mesh under one of these must stay
# under it - merging it into a world-static batch would stop it moving.
DRIVEN = {"New_Blade_1", "New_TailBlade_2_002", "door_l", "door_r",
          "pintle_l_traverse", "pintle_r_traverse", "pintle_l_GunPivot",
          "pintle_r_GunPivot", "VARIANT_A", "VARIANT_B", "VARIANT_C"}

BOX = ["rack_m16_1", "rack_m16_2", "rack_m16_3", "rack_m79", "Center Bench"]
M60 = ["pintle_l_m60", "pintle_r_m60"]
MARK_ROOT = ["MARK_ARMY_l", "MARK_ARMY_r", "MARK_ARMY_l_M", "MARK_ARMY_r_M"]
DECIMATE = {
    "fuselage_fwd": 850,
    "door_l": 40, "door_r": 40,
    "skid_rail_l": 32, "skid_rail_r": 32,
    "door_frame_l": 24, "door_frame_r": 24,
    "antenna_fm_aft": 10, "antenna_fm_fwd": 10, "antenna_vhf_belly": 10, "pitot_tube": 10,
    "exhaust_stack": 12, "mast_fairing": 16,
    "gunner_stool_l_pad": 12, "gunner_stool_l_post": 12,
    "gunner_stool_r_pad": 12, "gunner_stool_r_post": 12,
    "glass_greenhouse_upper": 20, "glass_chin_l": 12, "glass_chin_r": 12,
    "door_window_l": 8, "door_window_r": 8, "glass_cockpit_l": 8, "glass_cockpit_r": 8,
}
ATLAS = 512
CELL_COLS, CELL_ROWS = 2, 11          # 22 cells, 256 x 46 px each
SS = 3                                 # supersample factor for the bake


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons) if ob.type == 'MESH' else 0


def local_bbox(ob):
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    for v in ob.data.vertices:
        for i in range(3):
            lo[i] = min(lo[i], v.co[i])
            hi[i] = max(hi[i], v.co[i])
    return lo, hi


def world_area_by_material(objs):
    out = {}
    for ob in objs:
        if ob.type != 'MESH':
            continue
        mw = ob.matrix_world
        mats = [ms.material.name if ms.material else "__none__" for ms in ob.material_slots] or ["__none__"]
        for poly in ob.data.polygons:
            key = mats[min(poly.material_index, len(mats) - 1)]
            vs = [mw @ ob.data.vertices[i].co for i in poly.vertices]
            a = 0.0
            for i in range(1, len(vs) - 1):
                a += (vs[i] - vs[0]).cross(vs[i + 1] - vs[0]).length * 0.5
            out[key] = out.get(key, 0.0) + a
    return out


# =============================================================== marking bake ==
def rasterize(ob, cw_max, ch_max, ss=SS):
    """Coverage mask of the object's triangles projected onto its two widest
    LOCAL axes, fitted inside a cw_max x ch_max cell preserving aspect.
    Returns (mask rows bottom-up, cw, ch, axis_a, axis_b)."""
    lo, hi = local_bbox(ob)
    ext = [hi[i] - lo[i] for i in range(3)]
    thin = ext.index(min(ext))
    a, b = [i for i in range(3) if i != thin]
    da, db = max(ext[a], 1e-9), max(ext[b], 1e-9)
    if da / db >= float(cw_max) / float(ch_max):
        cw, ch = cw_max, max(1, int(round(cw_max * db / da)))
    else:
        ch, cw = ch_max, max(1, int(round(ch_max * da / db)))
    W, H = cw * ss, ch * ss
    buf = [0.0] * (W * H)
    vs = ob.data.vertices
    for poly in ob.data.polygons:
        idx = list(poly.vertices)
        for k in range(1, len(idx) - 1):
            tri = [vs[idx[0]].co, vs[idx[k]].co, vs[idx[k + 1]].co]
            p = [((c[a] - lo[a]) / da * (W - 1), (c[b] - lo[b]) / db * (H - 1)) for c in tri]
            x0 = max(0, int(math.floor(min(q[0] for q in p))))
            x1 = min(W - 1, int(math.ceil(max(q[0] for q in p))))
            y0 = max(0, int(math.floor(min(q[1] for q in p))))
            y1 = min(H - 1, int(math.ceil(max(q[1] for q in p))))
            (ax, ay), (bx, by), (cx, cy) = p
            den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
            if abs(den) < 1e-12:
                continue
            inv = 1.0 / den
            for py in range(y0, y1 + 1):
                fy = py + 0.5
                row = py * W
                for px in range(x0, x1 + 1):
                    fx = px + 0.5
                    w0 = ((by - cy) * (fx - cx) + (cx - bx) * (fy - cy)) * inv
                    if w0 < -1e-9:
                        continue
                    w1 = ((cy - ay) * (fx - cx) + (ax - cx) * (fy - cy)) * inv
                    if w1 < -1e-9:
                        continue
                    if w0 + w1 > 1.0 + 1e-9:
                        continue
                    buf[row + px] = 1.0
    # box downsample
    mask = [0.0] * (cw * ch)
    inv_n = 1.0 / float(ss * ss)
    for y in range(ch):
        for x in range(cw):
            s = 0.0
            for dy in range(ss):
                r = (y * ss + dy) * W + x * ss
                for dx in range(ss):
                    s += buf[r + dx]
            mask[y * cw + x] = s * inv_n
    return mask, cw, ch, thin, a, b


def bake_markings(marking_objs, mark_colour):
    """One RGBA atlas for every decal. RGB = the original MarkingWhite colour
    (LINEAR - Blender encodes to sRGB on save), A = rasterised coverage.
    Returns {obj_name: (u0, v0, u1, v1, thin, a, b)}."""
    px = [0.0] * (ATLAS * ATLAS * 4)
    cw_max = ATLAS // CELL_COLS
    ch_max = ATLAS // CELL_ROWS
    uvs = {}
    for i, ob in enumerate(marking_objs):
        col, row = i % CELL_COLS, i // CELL_COLS
        cx0, cy0 = col * cw_max, row * ch_max
        mask, cw, ch, thin, a, b = rasterize(ob, cw_max - 2, ch_max - 2)
        ox = cx0 + 1 + (cw_max - 2 - cw) // 2
        oy = cy0 + 1 + (ch_max - 2 - ch) // 2
        for y in range(ch):
            for x in range(cw):
                m = mask[y * cw + x]
                if m <= 0.0:
                    continue
                o = ((oy + y) * ATLAS + (ox + x)) * 4
                px[o] = mark_colour[0]
                px[o + 1] = mark_colour[1]
                px[o + 2] = mark_colour[2]
                px[o + 3] = m
        uvs[ob.name] = (ox / ATLAS, oy / ATLAS, (ox + cw) / ATLAS, (oy + ch) / ATLAS,
                        thin, a, b)
        print("[LOD]   baked %-16s -> cell(%d,%d) %dx%d px  cover=%.1f%%"
              % (ob.name, col, row, cw, ch,
                 100.0 * sum(1 for v in mask if v > 0.5) / max(1, cw * ch)))
    img = bpy.data.images.new("huey_v3_lod_markings", ATLAS, ATLAS, alpha=True)
    img.colorspace_settings.name = 'sRGB'
    img.pixels.foreach_set(px)
    img.filepath_raw = TEX
    img.file_format = 'PNG'
    img.save()
    print("[LOD] wrote %s  %.1f KB" % (TEX, os.path.getsize(TEX) / 1024.0))
    mat = bpy.data.materials.new("huey_lod_markings")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = 'Closest'          # PSX house style: nearest filtering
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    # ALPHA SCISSOR, NOT BLEND. Measured with probe_alpha.py on Blender 5.0.1:
    # linking Image.Alpha straight into Principled.Alpha exports alphaMode=BLEND
    # every time, and `Material.surface_render_method` does not exist in 5.0.1 at
    # all (hasattr on the type returns nothing) so setting it is a silent no-op.
    # Inserting a Math node is what makes the exporter write alphaMode=MASK.
    # MASK matters here: BLEND puts 4 sorted transparent draws on every airframe
    # and stops the decals writing depth, on a job whose whole point is frames.
    thr = nt.nodes.new("ShaderNodeMath")
    thr.operation = 'GREATER_THAN'
    thr.inputs[1].default_value = 0.5
    nt.links.new(tex.outputs["Alpha"], thr.inputs[0])
    nt.links.new(thr.outputs[0], bsdf.inputs["Alpha"])
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.9
    mat.use_backface_culling = False
    return img, mat, uvs


def marking_quad(ob, rec, mat):
    """2-tri quad on the decal's own plane, UV'd to its atlas cell."""
    u0, v0, u1, v1, thin, a, b = rec
    lo, hi = local_bbox(ob)
    mid = (lo[thin] + hi[thin]) * 0.5

    def pt(ua, ub):
        v = [0.0, 0.0, 0.0]
        v[thin] = mid
        v[a] = ua
        v[b] = ub
        return tuple(v)

    me = bpy.data.meshes.new(ob.name + "_quad")
    me.from_pydata([pt(lo[a], lo[b]), pt(hi[a], lo[b]), pt(hi[a], hi[b]), pt(lo[a], hi[b])],
                   [], [(0, 1, 2), (0, 2, 3)])
    me.update()
    uvl = me.uv_layers.new(name="UVMap")
    corner = {0: (u0, v0), 1: (u1, v0), 2: (u1, v1), 3: (u0, v1)}
    for poly in me.polygons:
        for li in poly.loop_indices:
            uvl.data[li].uv = corner[me.loops[li].vertex_index]
    ob.data = me
    ob.data.materials.clear()
    ob.data.materials.append(mat)


# ================================================================ mesh surgery ==
def make_box(bm, lo, hi):
    x0, y0, z0 = lo
    x1, y1, z1 = hi
    vs = [bm.verts.new((x, y, z)) for x in (x0, x1) for y in (y0, y1) for z in (z0, z1)]
    for f in [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1),
              (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]:
        bm.faces.new([vs[i] for i in f])


def replace_with_boxes(ob, boxes, keep_slot=0, force_mat=None):
    bm = bmesh.new()
    for lo, hi in boxes:
        make_box(bm, lo, hi)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(ob.data.name + "_lod")
    bm.to_mesh(me)
    bm.free()
    mat = force_mat if force_mat is not None else (
        ob.material_slots[keep_slot].material if ob.material_slots else None)
    ob.data = me
    ob.data.materials.clear()
    if mat is not None:
        ob.data.materials.append(mat)


def m60_proxy(ob):
    """Barrel + receiver + butt, fitted to the donor's OWN mesh-local bbox.
    Bore runs -Y (pintle_*_MuzzlePoint sits at local y -0.6105)."""
    lo, hi = local_bbox(ob)
    xc, zc = (lo.x + hi.x) * 0.5, (lo.z + hi.z) * 0.5
    hx, hz = (hi.x - lo.x) * 0.5, (hi.z - lo.z) * 0.5
    ln = hi.y - lo.y

    def seg(y0f, y1f, fx, fz):
        return (Vector((xc - hx * fx, lo.y + ln * y0f, zc - hz * fz)),
                Vector((xc + hx * fx, lo.y + ln * y1f, zc + hz * fz)))

    replace_with_boxes(ob, [seg(0.00, 0.55, 0.16, 0.16),
                            seg(0.50, 0.80, 0.38, 0.45),
                            seg(0.78, 1.00, 0.30, 0.60)])


def _eval_tris(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    n = sum(len(p.vertices) - 2 for p in me.polygons)
    bpy.data.meshes.remove(me)
    return n


def decimate_to(ob, target, protect=None):
    """Collapse-decimate to `target` TRIANGLES (solved, not guessed).

    protect = (axis, lo, hi): verts inside that slab keep full density.
    fuselage_fwd and fuselage_aft are SEPARATE objects sharing an open boundary
    at y = -0.815. Decimating them independently walks that boundary apart and
    leaves a visible STEP at the boom root.

    TRAP: the Decimate vertex group runs the OTHER WAY from the obvious reading.
    A vertex's weight is how much it IS decimated - weight 0 means UNTOUCHED, so
    a naive "protect" group protected the whole mesh (2998 -> 2960).
    invert_vertex_group=True is what actually pins the slab.
    """
    cur = tris(ob)
    if cur <= target:
        return cur
    mod = ob.modifiers.new("LODDecimate", 'DECIMATE')
    mod.decimate_type = 'COLLAPSE'
    if protect is not None:
        axis, plo, phi = protect
        vg = ob.vertex_groups.new(name="lod_keep")
        idx = [v.index for v in ob.data.vertices if plo <= v.co[axis] <= phi]
        vg.add(idx, 1.0, 'REPLACE')
        mod.vertex_group = vg.name
        mod.invert_vertex_group = True
        mod.vertex_group_factor = 1.0
        print("[LOD]   %s: pinning %d/%d verts in the junction slab"
              % (ob.name, len(idx), len(ob.data.vertices)))
    ratio = float(target) / float(cur)
    for _ in range(10):
        mod.ratio = min(1.0, max(0.005, ratio))
        got = _eval_tris(ob)
        if abs(got - target) <= max(2, int(target * 0.04)) or got <= 0:
            break
        ratio *= float(target) / float(got)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    ob.modifiers.clear()
    ob.data = me
    return tris(ob)


# ====================================================================== merge ==
def ancestors(ob):
    out = []
    p = ob.parent
    while p is not None:
        out.append(p.name)
        p = p.parent
    return out


def merge_group(objs, name, parent=None):
    """Weld a set of mesh objects into ONE object, one surface per material.
    World transforms are BAKED into the vertices; verts are not welded across
    faces, so the triangle count is exactly preserved (this is the gate)."""
    mats = []
    verts, faces, uvs, midx, smooth = [], [], [], [], []
    for ob in objs:
        mw = ob.matrix_world
        flip = mw.determinant() < 0.0      # negative scale reverses winding
        slots = [ms.material for ms in ob.material_slots] or [None]
        uvl = ob.data.uv_layers.active
        for poly in ob.data.polygons:
            m = slots[min(poly.material_index, len(slots) - 1)]
            if m not in mats:
                mats.append(m)
            mi = mats.index(m)
            idx = list(poly.vertices)
            loops = list(poly.loop_indices)
            for k in range(1, len(idx) - 1):
                tri = [(idx[0], loops[0]), (idx[k], loops[k]), (idx[k + 1], loops[k + 1])]
                if flip:
                    tri = tri[::-1]
                base = len(verts)
                for vi, li in tri:
                    verts.append(mw @ ob.data.vertices[vi].co)
                    uvs.append(tuple(uvl.data[li].uv) if uvl else (0.0, 0.0))
                faces.append((base, base + 1, base + 2))
                midx.append(mi)
                smooth.append(poly.use_smooth)
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    for m in mats:
        me.materials.append(m)
    uvl = me.uv_layers.new(name="UVMap")
    for i, poly in enumerate(me.polygons):
        poly.material_index = midx[i]
        poly.use_smooth = smooth[i]
        for j, li in enumerate(poly.loop_indices):
            uvl.data[li].uv = uvs[i * 3 + j]
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if parent is not None:
        ob.parent = parent
    return ob


# ========================================================================= run ==
bpy.ops.wm.read_factory_settings(use_empty=True)
print("[LOD] blender %s" % bpy.app.version_string)
bpy.ops.import_scene.gltf(filepath=SRC)

before = {o.name: tris(o) for o in bpy.data.objects}
before_total = sum(before.values())
baseline_mw = {o.name: [list(r) for r in o.matrix_world] for o in bpy.data.objects}
src_area = world_area_by_material(list(bpy.data.objects))
print("[LOD] source %s : %d objects, %d tris"
      % (os.path.basename(SRC), len(before), before_total))

missing_ref = sorted(REFERENCED - set(before))
if missing_ref:
    print("[LOD] FATAL: referenced names absent from the source: %s" % missing_ref)
    sys.exit(1)

textured = {m.name for m in bpy.data.materials
            if m.use_nodes and any(n.type == 'TEX_IMAGE' for n in m.node_tree.nodes)}
print("[LOD] textured materials in the source: %s" % sorted(textured))

variant_kids = {v: sorted(c.name for c in bpy.data.objects[v].children)
                for v in ("VARIANT_A", "VARIANT_B", "VARIANT_C")}
marking_names = list(MARK_ROOT) + [n for v in variant_kids for n in variant_kids[v]]
print("[LOD] %d marking objects, %d tris of text"
      % (len(marking_names), sum(before[n] for n in marking_names)))

clash = [n for n in set(BOX) | set(M60)
         for ms in bpy.data.objects[n].material_slots
         if ms.material is not None and ms.material.name in textured]
if clash:
    print("[LOD] FATAL: box replacement would destroy UVs on %s" % clash)
    sys.exit(1)
print("[LOD] UV-safety gate PASS - no box-replaced object uses a textured material")

# ---- 1. bake the markings ---------------------------------------------------
mw_mat = bpy.data.materials.get("MarkingWhite")
mark_colour = (1.0, 1.0, 1.0)
if mw_mat is not None and mw_mat.use_nodes:
    b = mw_mat.node_tree.nodes.get("Principled BSDF")
    if b is not None:
        mark_colour = tuple(b.inputs["Base Color"].default_value)[:3]
print("[LOD] MarkingWhite base colour (linear) = %s" % (tuple(round(c, 4) for c in mark_colour),))
img, mark_mat, mark_uvs = bake_markings([bpy.data.objects[n] for n in marking_names], mark_colour)
for n in marking_names:
    marking_quad(bpy.data.objects[n], mark_uvs[n], mark_mat)

# ---- 2. the rest of the geometry -------------------------------------------
# The rack weapons are 12-tri BOXES now, not his donor guns, so carrying a donor
# gun material (BlackAlu.002, Walnut) on them buys nothing and costs two extra
# surfaces and two stray materials in a shipped file. They take an existing Huey
# palette material instead. Flagged for Caleb - it is a small art change.
RACK_MAT = "huey_panel_black"
for n in BOX:
    ob = bpy.data.objects[n]
    fm = bpy.data.materials.get(RACK_MAT) if n.startswith("rack_") else None
    replace_with_boxes(ob, [local_bbox(ob)], force_mat=fm)
for n in M60:
    m60_proxy(bpy.data.objects[n])
decimate_to(bpy.data.objects["fuselage_fwd"], DECIMATE.pop("fuselage_fwd"),
            protect=(1, -1.115, -0.515))
for n, t in DECIMATE.items():
    decimate_to(bpy.data.objects[n], t)

pre_merge = {o.name: tris(o) for o in bpy.data.objects}
pre_surfaces = sum(max(1, len([m for m in o.data.materials if m]))
                   for o in bpy.data.objects if o.type == 'MESH')
print("[LOD] before merge: %d objects, %d tris, %d surfaces"
      % (len(pre_merge), sum(pre_merge.values()), pre_surfaces))

# ---- 3. merge -------------------------------------------------------------
for v in ("VARIANT_A", "VARIANT_B", "VARIANT_C"):
    kids = [bpy.data.objects[n] for n in variant_kids[v]]
    merge_group(kids, v + "_markings", parent=bpy.data.objects[v])
    for k in kids:
        bpy.data.objects.remove(k, do_unlink=True)
merge_group([bpy.data.objects[n] for n in MARK_ROOT], "MARK_ARMY")
for n in MARK_ROOT:
    bpy.data.objects.remove(bpy.data.objects[n], do_unlink=True)

mergeable, kept = [], []
for o in list(bpy.data.objects):
    if o.type != 'MESH' or o.name.endswith("_markings") or o.name == "MARK_ARMY":
        continue
    if o.name in REFERENCED or (set(ancestors(o)) | {o.name}) & DRIVEN:
        kept.append(o.name)
    else:
        mergeable.append(o)
print("[LOD] merge: %d meshes mergeable, %d meshes kept separate" % (len(mergeable), len(kept)))
print("[LOD]   kept: %s" % sorted(kept))

by_mat = {}
for o in mergeable:
    key = tuple(sorted(ms.material.name if ms.material else "__none__"
                       for ms in o.material_slots)) or ("__none__",)
    by_mat.setdefault(key[0] if len(key) == 1 else "cargo", []).append(o)
for key, objs in sorted(by_mat.items()):
    merge_group(objs, "huey_lod_%s" % key)
    print("[LOD]   merged %-22s <- %2d objects, %5d tris"
          % (key, len(objs), sum(tris(o) for o in objs)))
for o in mergeable:
    bpy.data.objects.remove(o, do_unlink=True)

# ---- 4. gates --------------------------------------------------------------
after = {o.name: tris(o) for o in bpy.data.objects}
after_total = sum(after.values())
surfaces = sum(max(1, len([m for m in o.data.materials if m]))
               for o in bpy.data.objects if o.type == 'MESH')
print("\n[LOD] BLENDER TRIS %d -> %d  (%.1f%% of source)"
      % (before_total, after_total, 100.0 * after_total / before_total))
print("[LOD] SURFACES %d -> %d   OBJECTS %d -> %d"
      % (pre_surfaces, surfaces, len(before), len(after)))

dropped = sorted(set(before) - set(after))
added = sorted(set(after) - set(before))
kept_ref = sorted(REFERENCED & set(after))
print("[LOD] referenced names kept: %d/%d" % (len(kept_ref), len(REFERENCED)))
lost_ref = sorted(REFERENCED - set(after))
if lost_ref:
    print("[LOD] FATAL: referenced names DROPPED: %s" % lost_ref)
    sys.exit(1)
print("[LOD] names dropped (all unreferenced): %d %s" % (len(dropped), dropped))
print("[LOD] names added: %s" % added)

worst = 0.0
worst_n = ""
for o in bpy.data.objects:
    if o.name not in baseline_mw:
        continue
    b = baseline_mw[o.name]
    for r in range(4):
        for c in range(4):
            d = abs(o.matrix_world[r][c] - b[r][c])
            if d > worst:
                worst, worst_n = d, o.name
print("[LOD] max world-transform delta on surviving nodes = %.3e (%s)" % (worst, worst_n))

# geometry-preservation gate for the merge: world surface area per material
lod_area = world_area_by_material(list(bpy.data.objects))
print("[LOD] world surface area m2 by material (source -> lod):")
for k in sorted(set(src_area) | set(lod_area)):
    print("      %-22s %9.3f -> %9.3f" % (k, src_area.get(k, 0.0), lod_area.get(k, 0.0)))

# ---- 5. export, mirroring tools/export_huey_v3.py --------------------------
for o in bpy.data.objects:
    o.hide_viewport = False
    o.hide_set(False)
    o.select_set(True)
bpy.context.view_layer.objects.active = bpy.data.objects[0]
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format='GLB', use_selection=True, export_apply=True,
    export_yup=True, export_animations=False, export_materials='EXPORT',
    export_cameras=False, export_lights=False,
)
print("[LOD] wrote %s  %.3f MB" % (OUT, os.path.getsize(OUT) / 1048576.0))
json.dump({"before": before, "after": after, "dropped": dropped, "added": added,
           "surfaces_before": pre_surfaces, "surfaces_after": surfaces},
          open(os.path.join(SCRATCH, "huey_lod_counts.json"), "w"), indent=1)
