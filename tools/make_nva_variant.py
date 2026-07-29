"""Build ONE NVA/VC variant from the VC master and export it, headless.

    blender -b assets/nva_vc/characters/vc_guerilla_v2.blend -P tools/make_nva_variant.py -- <variant>

Variants (gun, face cell, nva cloth?) are in VARIANTS below. The prelude here
retargets the shared faction sheet (ref_factions.002) and swaps headgear; the
export itself is export_vc_guerilla.py run unchanged (mesh_only - clips come
from the shared anim library), so the engine contract cannot drift.

CLOTH: the body's cloth UVs sample the VIET CONG row of the faction sheet. An
NVA variant maps each cloth poly onto the NVA row garment directly above it.
Rects below are MEASURED (probe_rows_islands.py segmentation, 2026-07-29), not
eyeballed. Polys sampling the skin-circle area are left alone on purpose.

PITH: gear_library.blend is gone (recon_paths.py:130), so the NVA pith helmet
is built here - low-poly dome + brim seated where the rice hat sat, UV'd onto
the sheet's pith photo.
"""
import bpy
import bmesh
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

VARIANTS = {
    "nva_regular":  dict(gun="ppsh_world", face="nva_1", nva=True),
    "nva_rifleman": dict(gun="ak47_world", face="nva_2", nva=True),
    "nva_mg":       dict(gun="rpd_world", face="nva_1", nva=True),
    "nva_marksman": dict(gun="mosin_world", face="nva_2", nva=True),
    "nva_officer":  dict(gun="ppsh_world", face="nva_2", nva=True),
    "nva_medic":    dict(gun="ak47_world", face="nva_1", nva=True),
    "vc_medic":     dict(gun="ppsh_world", face="vnm_mid", nva=False),
}

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
NAME = argv[0] if argv else "nva_regular"
SPEC = VARIANTS[NAME]

W, H = 3600.0, 5700.0
# (x0, y0, x1, y1) image px, top-down. Source VC row -> target NVA row.
# NVA garment fabric rects (measured; inset applied in code so every sample
# lands on cloth, never the black background or the patch/label strips).
NVA_SHIRT = (62, 3162, 626, 3679)
NVA_SLEEVES = [(659, 3176, 820, 3674), (858, 3130, 1065, 3674)]
NVA_TROUSERS = [(1078, 3133, 1392, 3672), (1417, 3127, 1660, 3673), (1683, 3127, 1929, 3672)]
FABRIC_INSET = 0.26
PITH_RECT = (2888, 3133, 3381, 3459)


def uv_from_px(x, y):
    return (x / W, 1.0 - y / H)


def _patch_uvs(uvl, me, loops, rect, seed: int) -> None:
    """Map this poly's UV bbox onto a hashed sub-patch of the rect's fabric
    interior - guaranteed cloth, with photographic variety per poly."""
    ix0 = rect[0] + (rect[2] - rect[0]) * FABRIC_INSET
    ix1 = rect[2] - (rect[2] - rect[0]) * FABRIC_INSET
    iy0 = rect[1] + (rect[3] - rect[1]) * FABRIC_INSET
    iy1 = rect[3] - (rect[3] - rect[1]) * FABRIC_INSET
    span_x, span_y = ix1 - ix0, iy1 - iy0
    h1 = (seed * 2654435761) & 0xFFFF
    h2 = (seed * 40503 + 9973) & 0xFFFF
    pw, ph = span_x * 0.45, span_y * 0.45
    px0 = ix0 + (h1 / 65535.0) * (span_x - pw)
    py0 = iy0 + (h2 / 65535.0) * (span_y - ph)
    us = [uvl.data[li].uv[0] for li in loops]
    vs = [uvl.data[li].uv[1] for li in loops]
    u0, u1, v0, v1 = min(us), max(us), min(vs), max(vs)
    du = max(u1 - u0, 1e-6)
    dv = max(v1 - v0, 1e-6)
    for li in loops:
        u, v = uvl.data[li].uv
        a = (u - u0) / du
        b = (v - v0) / dv
        uvl.data[li].uv = uv_from_px(px0 + a * pw, py0 + ph - b * ph)


def remap_cloth_to_nva() -> None:
    """Position-driven: each cloth poly picks its NVA garment by where it sits
    on the BODY (arm -> sleeve, above hips -> shirt, below -> trousers). The VC
    UV layout is impressionistic slop that only worked black-on-black - the
    source UVs carry no usable garment meaning, so the 3D mesh is the truth.
    Leg polys of the SKIN material (the VC bare-calf look) become trousers:
    an NVA regular is fully uniformed. Hands and feet stay skin."""
    body = bpy.data.objects["vc_guerilla_joined"]
    # body Z/X frame in world space; the gib donors sit at their body-part
    # positions and are judged against the SAME frame, so a flying arm wears
    # the same cloth as the arm it left.
    wz, wx = [], []
    for v in body.data.vertices:
        w = body.matrix_world @ v.co
        wz.append(w.z)
        wx.append(abs(w.x))
    z0, z1 = min(wz), max(wz)
    xw = max(wx)

    targets = [body] + [o for o in bpy.data.objects
                        if o.type == "MESH" and o.name.startswith("grunt_")]
    moved, legged = 0, 0
    for ob in targets:
        me = ob.data
        if not me.uv_layers:
            continue
        uvl = me.uv_layers[0]
        cloth = next((i for i, s in enumerate(ob.material_slots)
                      if s.material and s.material.name in ("BlackPajama", "NVA_Uniform")), None)
        skin = next((i for i, s in enumerate(ob.material_slots)
                     if s.material and s.material.name == "Skin_VC"), None)
        if cloth is None:
            continue
        for p in me.polygons:
            c = ob.matrix_world @ p.center
            z01 = (c.z - z0) / (z1 - z0)
            x01 = abs(c.x) / xw
            if p.material_index == cloth:
                if x01 > 0.30 and z01 > 0.5:
                    rect = NVA_SLEEVES[p.index % len(NVA_SLEEVES)]
                elif z01 > 0.52:
                    rect = NVA_SHIRT
                else:
                    rect = NVA_TROUSERS[p.index % len(NVA_TROUSERS)]
                _patch_uvs(uvl, me, list(range(p.loop_start, p.loop_start + p.loop_total)), rect, p.index)
                moved += 1
            elif skin is not None and p.material_index == skin \
                    and z01 < 0.5 and 0.06 < z01 and x01 < 0.35:
                p.material_index = cloth
                rect = NVA_TROUSERS[p.index % len(NVA_TROUSERS)]
                _patch_uvs(uvl, me, list(range(p.loop_start, p.loop_start + p.loop_total)), rect, p.index)
                legged += 1
        me.update()
    bpy.data.materials["BlackPajama"].name = "NVA_Uniform"
    print("cloth remap: %d cloth polys + %d leg polys onto NVA fabric across %d meshes"
          % (moved, legged, len(targets)), flush=True)


def build_pith() -> None:
    rig = bpy.data.objects["PSXRig"]
    hat = bpy.data.objects.get("rice_hat")
    if hat is None:
        print("!! no rice_hat to seat against", flush=True)
        return
    anchor = hat.matrix_world.copy()
    bpy.data.objects.remove(hat, do_unlink=True)

    mesh = bpy.data.meshes.new("pith_helmet")
    bm = bmesh.new()
    # dome: 10 segments x 4 rings, squashed hemisphere
    bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=0.145)
    for v in list(bm.verts):
        if v.co.z < -0.01:
            bm.verts.remove(v)
    for v in bm.verts:
        v.co.z *= 0.62
    # brim: outward ring of the open edge
    rim = [e for e in bm.edges if e.is_boundary]
    ring_verts = {v for e in rim for v in e.verts}
    res = bmesh.ops.extrude_edge_only(bm, edges=rim)
    new_verts = [g for g in res["geom"] if isinstance(g, bmesh.types.BMVert)]
    for v in new_verts:
        out = v.co.copy()
        out.z = 0.0
        out.normalize()
        v.co += out * 0.045
        v.co.z -= 0.012
    bm.to_mesh(mesh)
    bm.free()

    ob = bpy.data.objects.new("pith_helmet_worn", mesh)
    bpy.context.scene.collection.objects.link(ob)
    # planar-project UVs into the pith photo rect
    uvl = mesh.uv_layers.new(name="UVMap")
    xs = [v.co.x for v in mesh.vertices]
    ys = [v.co.y for v in mesh.vertices]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    for p in mesh.polygons:
        for li in range(p.loop_start, p.loop_start + p.loop_total):
            c = mesh.vertices[mesh.loops[li].vertex_index].co
            a = (c.x - x0) / (x1 - x0)
            b = (c.y - y0) / (y1 - y0)
            uvl.data[li].uv = uv_from_px(PITH_RECT[0] + a * (PITH_RECT[2] - PITH_RECT[0]),
                                         PITH_RECT[3] - b * (PITH_RECT[3] - PITH_RECT[1]))
    mat = bpy.data.materials.get("NVA_Uniform") or bpy.data.materials.get("BlackPajama")
    mesh.materials.append(mat)

    ob.parent = bpy.data.objects["PSXRig"]
    ob.parent_type = "BONE"
    ob.parent_bone = "mixamorig:Head"
    # seat on the rice hat's anchor, dropped to hug the skull
    ob.matrix_world = anchor
    ob.matrix_world.translation += anchor.to_3x3() @ __import__("mathutils").Vector((0, 0, -0.02))
    _ = rig
    print("pith helmet built + seated", flush=True)


print("=== VARIANT PRELUDE: %s ===" % NAME, flush=True)
if SPEC["nva"]:
    remap_cloth_to_nva()
    build_pith()

# hand off to the proven exporter, argv rewritten for it
sys.argv = ["blender", "--", SPEC["gun"], NAME, SPEC["face"], "mesh_only"]
export_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "export_vc_guerilla.py")
exec(compile(open(export_path).read(), export_path, "exec"))
