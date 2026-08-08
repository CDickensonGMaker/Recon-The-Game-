"""NVA/VC gear library - fix #1: the pith/cap "band" objects read as a broken
strap crossing the crown instead of the horizontal trim band real pith
helmets wear around the base.

DIAGNOSIS (measured, not eyeballed - see production/blender_notes.md
2026-08-07 entry for the full readout): every `*_band` mesh
(pith_plain_band, pith_faded_band, pith_worn_band, pith_star_band,
pith_net_band, cap_cloth_band - all byte-identical 338-vert geometry) is a
disordered triangle fan connecting essentially random pairs of the dome's
OWN duplicated rim vertices. Its bounding box looked plausible in isolation
(Y range 0.0995-0.1468, narrower than the dome's own 0.139-0.237, i.e.
"below the dome" by pure range comparison) but a side-on render
(band_only_side.png, offset along +X) showed a TALL VERTICAL HOOP, not a
flat horizontal ring - the loop's plane runs through Y (vertical) and Z
(front-back), arcing from the front rim up OVER the crown to the back rim,
exactly like a chinstrap worn over the top of the head. That is the
"reads as broken geometry" defect Caleb flagged.

This script does NOT touch the dome geometry (approved, left alone) - it
only rebuilds each `*_band` object's mesh data in place (same object name,
same material, so nothing else that references it changes) as a proper
horizontal trim band that hugs the dome's own fluted/scalloped base rim -
the real thing a French-pattern pith helmet has: a leatherette or vinyl
strip glued around the lower edge of the shell, sitting flush and level.

Rim derivation (measured per dome, not assumed identical across variants
even though topology matches): the dome's base is a 10-point ZIGZAG
("fluted") edge, not a plain circle - confirmed by dumping the polygons
touching the dome's minimum-Y vertices: they are 20 triangles alternating
between a low ring (Y = dome ymin) and a high ring (Y = ymin + 0.0115),
i.e. 10 "down" points and 10 "up" points around the circumference. The
real trim band should hug that same scallop, not a smoothed circle - so
the rim loop below is taken directly from those 20 dome vertices, ordered
by angle, not resampled into a plain circle.

    blender -b --factory-startup -P tools/fix_nva_gear_bands.py
"""
import bpy, bmesh, math, os
from mathutils import Vector

PROPS_DIR = r"C:\Users\caleb\RECONgame\assets\nva_vc\props"
BLEND = os.path.join(PROPS_DIR, "nva_vc_gear_variants.blend")

# dome object -> band object -> export glb path (category dir)
PAIRS = [
    ("pith_plain", "pith_plain_band", "headgear/pith_plain.glb"),
    ("pith_faded", "pith_faded_band", "headgear/pith_faded.glb"),
    ("pith_worn",  "pith_worn_band",  "headgear/pith_worn.glb"),
    ("pith_star",  "pith_star_band",  "headgear/pith_star.glb"),
    ("pith_net",   "pith_net_band",   "headgear/pith_net.glb"),
    ("cap_cloth",  "cap_cloth_band",  "headgear/cap_cloth.glb"),
    ("pith_foliage", "pith_foliage_band", "headgear/pith_foliage.glb"),
]
# full parts list per glb (band is only ONE part of several - re-export the
# WHOLE prop each time, not just the band, so the glb stays complete)
GLB_PARTS = {
    "pith_plain.glb": ["pith_plain", "pith_plain_band"],
    "pith_faded.glb": ["pith_faded", "pith_faded_band"],
    "pith_worn.glb":  ["pith_worn", "pith_worn_band"],
    "pith_star.glb":  ["pith_star", "pith_star_band"],
    "pith_net.glb":   ["pith_net", "pith_net_band", "pith_net_scrim", "pith_net_tabs"],
    "cap_cloth.glb":  ["cap_cloth", "cap_cloth_band"],
    # pith_foliage.glb is intentionally NOT re-exported here - its export
    # (dome+band+sprigs) is owned by tools/build_nva_gear_foliage.py, run
    # immediately after this script; re-exporting here would ship it
    # without its foliage sprigs.
}


def rim_loop(dome_ob):
    """Return the dome's own 20-vertex fluted base rim, world-order by
    angle, as a list of (low_point, high_point) pairs walking the
    circumference (low = the dome's ymin ring, high = ymin+0.0115 ring -
    the two rings the base zigzag triangles connect)."""
    me = dome_ob.data
    # the second-ring height ABOVE the base varies per dome (pith family:
    # +0.01155; cap_cloth's shorter crown: +0.0094) - derive it from the
    # mesh's own two lowest distinct Y values instead of a hardcoded
    # offset (a hardcoded 0.01155 silently produced a 0-face cap_cloth_band
    # the first time this ran; caught by re-import validation, not assumed).
    distinct_ys = sorted(set(round(v.co.y, 4) for v in me.vertices))
    ymin, ymid = distinct_ys[0], distinct_ys[1]
    low = {}   # rounded (x,z) -> Vector, dedupe the duplicated verts
    high = {}
    for v in me.vertices:
        key = (round(v.co.x, 4), round(v.co.z, 4))
        if abs(v.co.y - ymin) < 0.0005:
            low[key] = v.co.copy()
        elif abs(v.co.y - ymid) < 0.0005:
            high[key] = v.co.copy()
    low_pts = list(low.values())
    high_pts = list(high.values())
    cx = sum(p.x for p in low_pts) / len(low_pts)
    cz = sum(p.z for p in low_pts) / len(low_pts)
    low_pts.sort(key=lambda p: math.atan2(p.z - cz, p.x - cx))
    high_pts.sort(key=lambda p: math.atan2(p.z - cz, p.x - cx))
    return low_pts, high_pts, Vector((cx, ymin, cz))


def build_band_mesh(name, dome_ob, mat):
    """A short vertical strip (2 rings) that follows the dome's own
    scalloped base rim, offset slightly outward in radius so it reads as
    a trim band glued around the shell, not embedded in it."""
    low_pts, high_pts, center = rim_loop(dome_ob)
    n = len(low_pts)
    OUT = 0.004     # radial standoff from the shell (a glued-on strip)
    DROP = 0.010    # how far the band hangs below the rim's low points

    def radial_out(p, extra_out, extra_y):
        d = Vector((p.x - center.x, 0, p.z - center.z))
        if d.length > 1e-6:
            d = d.normalized() * extra_out
        return Vector((p.x + d.x, p.y + extra_y, p.z + d.z))

    top_ring = [radial_out(p, OUT, 0.0) for p in high_pts]
    bot_ring = [radial_out(p, OUT * 1.15, -DROP) for p in low_pts]
    # both rings have n points (low/high rim rings are the same count,
    # scallop-aligned already since they came from the same triangle fan)
    verts = top_ring + bot_ring
    faces = []
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, j, n + j, n + i])
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    for p in me.polygons:
        p.use_smooth = False
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(mat)
    uv = ob.data.uv_layers.new(name="UVMap")
    for poly in ob.data.polygons:
        for li in poly.loop_indices:
            vi = ob.data.loops[li].vertex_index
            u = (vi % n) / n
            v = 0.0 if vi < n else 1.0
            uv.data[li].uv = (u, v)
    return ob


def tris(me):
    return sum(max(0, len(p.vertices) - 2) for p in me.polygons)


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    rig = bpy.data.objects["PSXRig"]
    report = {}

    for dome_n, band_n, glb_rel in PAIRS:
        dome_ob = bpy.data.objects[dome_n]
        old_band = bpy.data.objects[band_n]
        mat = old_band.data.materials[0]  # keep the SAME material (pith_band_cover)
        old_verts, old_tris = len(old_band.data.vertices), tris(old_band.data)

        old_mesh = old_band.data
        new_mesh_holder = build_band_mesh(band_n + "_NEW", dome_ob, mat)
        # swap mesh data into the ORIGINAL object so every other reference
        # (parts lists, the manifest, any prior selection) still points at
        # the same object name - only its geometry changes.
        old_band.data = new_mesh_holder.data
        old_band.data.name = band_n
        bpy.data.objects.remove(new_mesh_holder, do_unlink=True)
        bpy.data.meshes.remove(old_mesh)

        new_verts, new_tris = len(old_band.data.vertices), tris(old_band.data)
        report[band_n] = dict(old_verts=old_verts, old_tris=old_tris,
                               new_verts=new_verts, new_tris=new_tris)
        print(f"{band_n}: {old_verts}v/{old_tris}t -> {new_verts}v/{new_tris}t")

    bpy.data.orphans_purge(do_local_ids=True, do_recursive=True)
    bpy.data.orphans_purge(do_local_ids=True, do_recursive=True)

    # re-export every affected glb (whole prop, all its parts)
    for glb_name, parts in GLB_PARTS.items():
        for x in bpy.data.objects:
            x.select_set(False)
        for p in parts:
            ob = bpy.data.objects.get(p)
            if ob:
                ob.select_set(True)
        rig.select_set(True)
        bpy.context.view_layer.objects.active = rig
        subdir = "headgear"
        out_path = os.path.join(PROPS_DIR, subdir, os.path.basename(glb_name))
        kw = dict(filepath=out_path, export_format='GLB', use_selection=True,
                  export_apply=True, export_animations=False, export_skins=False,
                  export_morph=False, export_cameras=False, export_lights=False,
                  export_yup=True)
        props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
        bpy.ops.export_scene.gltf(**{k: v for k, v in kw.items() if k in props})
        print("exported", out_path)

    bpy.ops.wm.save_mainfile(filepath=BLEND)
    print("saved:", BLEND)
    import json
    with open(os.path.join(PROPS_DIR, "_band_fix_report.json"), "w") as f:
        json.dump(report, f, indent=2)


if __name__ == "__main__":
    main()
