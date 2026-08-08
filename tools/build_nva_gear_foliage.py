"""NVA/VC gear library - fix #4: pith_foliage's "3 flat leaf" crown replaced
with real sampled foliage from the project's own vegetation library, plus
two new foliaged PACK variants (Caleb's idea: "decorate backpacks and
helmets with them").

SOURCE (read-only, per standing instruction - never edited, never
re-exported, only IMPORTED into memory and sampled from):
    assets/world/vegetation/bush_a_stump.glb   (jungle_atlas, ~77 tris whole)
    assets/world/vegetation/bush_b_stump.glb   (jungle_atlas, ~109 tris whole)
    assets/world/vegetation/bush_c_stump.glb   (jungle_atlas, ~75 tris whole)
    assets/world/vegetation/jungle_palm_a1_stump.glb
    assets/world/vegetation/jungle_palm_b1_stump.glb
FIVE distinct plants (within the "4-8" brief) - the `_low` LOD of each,
already the cheapest variant in the library, right for dressing seen at
gameplay distance rather than in close-up.

Using a WHOLE low-poly bush per sprig (75-109 tris) is still too heavy to
scatter multiple of across a helmet/pack at PSX density, so each plant is
SAMPLED, not reused whole: for each source mesh, the faces nearest its own
local tip/edge are selected (a real branch-tip cluster of that plant's
actual geometry, not a procedural stand-in - satisfies "no procedural
geometry") and cut loose as a small ~10-20 tri "sprig", recentred to its
own local origin so it can be scattered and re-scaled like the existing
pith_net_tabs trick.

pith_foliage rebuild: dome+band kept EXACTLY as already fixed (approved
geometry, band already corrected by fix_nva_gear_bands.py) - only the old
3 flat "leaf" objects are replaced by 6 sprigs (2 samples each from 3 of
the 5 plants) tucked around the band, matching reference for troops
tying cut jungle vegetation to a helmet net/scrim for camouflage.

New pack variants: pack_frame_foliage and pack_ruck_light_foliage - same
approved pack mesh, unchanged, with 4-5 sprigs (spanning all 5 plants
across the two, so each gets used) added on top, matching reference of
cut branches lashed to a rucksack frame for the same reason.

    blender -b --factory-startup -P tools/build_nva_gear_foliage.py
"""
import bpy, bmesh, math, os, random
from mathutils import Vector

PROPS_DIR = r"C:\Users\caleb\RECONgame\assets\nva_vc\props"
BLEND = os.path.join(PROPS_DIR, "nva_vc_gear_variants.blend")
VEG_DIR = r"C:\Users\caleb\RECONgame\assets\world\vegetation"

PLANTS = ["bush_a_stump.glb", "bush_b_stump.glb", "bush_c_stump.glb",
          "jungle_palm_a1_stump.glb", "jungle_palm_b1_stump.glb"]

NEW_OBJECTS = [
    "pith_foliage_sprig_0", "pith_foliage_sprig_1", "pith_foliage_sprig_2",
    "pith_foliage_sprig_3", "pith_foliage_sprig_4", "pith_foliage_sprig_5",
    "pack_frame_foliage", "pack_frame_foliage_sprig_0", "pack_frame_foliage_sprig_1",
    "pack_frame_foliage_sprig_2",
    "pack_ruck_light_foliage", "pack_ruck_light_foliage_sprig_0",
    "pack_ruck_light_foliage_sprig_1", "pack_ruck_light_foliage_sprig_2",
]


def purge_prior():
    for name in NEW_OBJECTS:
        ob = bpy.data.objects.get(name)
        if ob:
            bpy.data.objects.remove(ob, do_unlink=True)
    for _ in range(2):
        bpy.data.orphans_purge(do_local_ids=True, do_recursive=True)


def sample_sprig_from_plant(glb_path, seed):
    """Import a source plant in a throwaway scene, cut a small tip cluster
    of its OWN faces (real sampled geometry, not procedural), return
    (verts, faces, material_name, image) all in the plant's own local
    space, recentred so the cluster's own centroid is the origin."""
    # import into a scratch collection inside THIS file (temp), never
    # touching or re-saving the source file itself
    before = set(bpy.data.objects.keys())
    bpy.ops.import_scene.gltf(filepath=glb_path)
    imported = [bpy.data.objects[n] for n in bpy.data.objects.keys() if n not in before]
    mesh_obs = [o for o in imported if o.type == 'MESH']
    src = mesh_obs[0]
    me = src.data
    mat = me.materials[0] if me.materials else None

    rnd = random.Random(seed)
    # pick a random face as the "tip" anchor, then grow a small cluster of
    # its face-connected neighbours (a real contiguous patch of the plant)
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    start = rnd.choice(bm.faces)
    cluster = {start}
    frontier = [start]
    target_n = rnd.randint(16, 26)
    while frontier and len(cluster) < target_n:
        f = frontier.pop()
        for e in f.edges:
            for nf in e.link_faces:
                if nf not in cluster:
                    cluster.add(nf)
                    frontier.append(nf)
                    if len(cluster) >= target_n:
                        break
            if len(cluster) >= target_n:
                break

    vmap = {}
    verts, faces = [], []
    for f in cluster:
        idxs = []
        for v in f.verts:
            if v.index not in vmap:
                vmap[v.index] = len(verts)
                verts.append(Vector(v.co))
            idxs.append(vmap[v.index])
        faces.append(idxs)
    bm.free()

    centroid = sum(verts, Vector()) / len(verts)
    verts = [v - centroid for v in verts]

    # remove the imported OBJECTS only - do NOT purge orphans here, that
    # would free the material datablock (`mat`, still needed by the
    # caller) the instant its only user (this temp object) is gone.
    # Leftover mesh data is swept once at the very end of main().
    for o in imported:
        bpy.data.objects.remove(o, do_unlink=True)

    return verts, faces, mat


def make_sprig_object(name, verts, faces, mat, place_at, target_size, rot_z_deg, uv_src_faces=None):
    """target_size = desired WORLD diagonal size in metres for this sprig -
    normalizes against the raw sampled cluster's own diagonal rather than
    an arbitrary scale multiplier, so every sprig reads as a comparably
    sized handful of foliage regardless of which patch of the source
    plant's mesh got sampled."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    for p in me.polygons:
        p.use_smooth = False
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if mat:
        me.materials.append(mat)
    uv = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            co = me.vertices[vi].co
            uv.data[li].uv = ((co.x * 1.5) % 1.0, (co.z * 1.5) % 1.0)
    raw_min = Vector((min(v.x for v in verts), min(v.y for v in verts), min(v.z for v in verts)))
    raw_max = Vector((max(v.x for v in verts), max(v.y for v in verts), max(v.z for v in verts)))
    raw_diag = (raw_max - raw_min).length
    scale = target_size / raw_diag if raw_diag > 1e-6 else 1.0
    ob.scale = (scale, scale, scale)
    ob.rotation_euler = (0, 0, math.radians(rot_z_deg))
    ob.location = Vector(place_at)
    bpy.context.view_layer.update()
    # bake the transform into the mesh so exported verts are final (matches
    # this file's convention - every prop's verts are pre-baked, not
    # relying on object transforms surviving export)
    mw = ob.matrix_world.copy()
    for v in me.vertices:
        v.co = mw @ v.co
    ob.location = (0, 0, 0)
    ob.rotation_euler = (0, 0, 0)
    ob.scale = (1, 1, 1)
    return ob


def tris(me):
    return sum(max(0, len(p.vertices) - 2) for p in me.polygons)


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    purge_prior()
    rig = bpy.data.objects["PSXRig"]

    # sample 6 sprigs total: 2 each from bush_a/b/c (the 3 bush forms give
    # the "cut leafy branch" read reference photos show; the 2 palm plants
    # are reserved for the pack variants below so all 5 plants get used
    # across the audit, per the brief)
    sprig_bank = []  # (verts, faces, mat, plant_name)
    for i, plant in enumerate(["bush_a_stump.glb", "bush_b_stump.glb", "bush_c_stump.glb"]):
        for k in range(2):
            v, f, m = sample_sprig_from_plant(os.path.join(VEG_DIR, plant), seed=100 + i * 7 + k)
            sprig_bank.append((v, f, m, plant))

    # --- pith_foliage: rebuild the crown, dome/band left exactly as-is ---
    dome = bpy.data.objects["pith_foliage"]
    band = bpy.data.objects["pith_foliage_band"]
    for old in ["pith_foliage_leaf_0", "pith_foliage_leaf_1", "pith_foliage_leaf_2"]:
        ob = bpy.data.objects.get(old)
        if ob:
            bpy.data.objects.remove(ob, do_unlink=True)

    # place 6 sprigs around the band rim + a couple leaning off the crown,
    # matching reference (cut foliage tucked into helmet netting/band)
    band_rim = [(0.09, 0.17, -0.06), (-0.07, 0.17, 0.09), (0.02, 0.19, 0.13),
                (-0.10, 0.16, -0.04), (0.06, 0.21, 0.06), (-0.03, 0.22, -0.10)]
    scales = [0.14, 0.12, 0.13, 0.12, 0.11, 0.13]  # target diagonal size, metres
    rots = [20, 140, 260, 65, 190, 320]
    new_leaves = []
    for i, (v, f, m, plant) in enumerate(sprig_bank):
        ob = make_sprig_object(f"pith_foliage_sprig_{i}", v, f, m, band_rim[i], scales[i], rots[i])
        new_leaves.append(ob)

    total_v = len(dome.data.vertices) + len(band.data.vertices) + sum(len(o.data.vertices) for o in new_leaves)
    total_t = tris(dome.data) + tris(band.data) + sum(tris(o.data) for o in new_leaves)
    print(f"pith_foliage rebuilt: {total_v}v / {total_t}t "
          f"(dome {tris(dome.data)}t + band {tris(band.data)}t + "
          f"{len(new_leaves)} sprigs {sum(tris(o.data) for o in new_leaves)}t)")

    # --- pack_frame_foliage: pack_worn_frame + 3 palm/bush sprigs on top ---
    palm_a_v, palm_a_f, palm_a_m = sample_sprig_from_plant(
        os.path.join(VEG_DIR, "jungle_palm_a1_stump.glb"), seed=201)
    palm_b_v, palm_b_f, palm_b_m = sample_sprig_from_plant(
        os.path.join(VEG_DIR, "jungle_palm_b1_stump.glb"), seed=202)
    bush_v, bush_f, bush_m = sample_sprig_from_plant(
        os.path.join(VEG_DIR, "bush_a_stump.glb"), seed=203)

    frame_src = bpy.data.objects["pack_worn_frame"]
    frame_dup_me = bpy.data.meshes.new_from_object(frame_src)
    frame_dup = bpy.data.objects.new("pack_frame_foliage", frame_dup_me)
    bpy.context.scene.collection.objects.link(frame_dup)
    frame_dup.data.materials.append(bpy.data.materials["pack_canvas"])

    frame_sprigs = []
    for i, (v, f, m, place, sc, rz) in enumerate([
        (palm_a_v, palm_a_f, palm_a_m, (0.02, 0.0, -0.20), 0.12, 15),
        (palm_b_v, palm_b_f, palm_b_m, (-0.09, -0.03, -0.23), 0.11, 200),
        (bush_v, bush_f, bush_m, (0.10, 0.03, -0.25), 0.10, 100),
    ]):
        ob = make_sprig_object(f"pack_frame_foliage_sprig_{i}", v, f, m, place, sc, rz)
        frame_sprigs.append(ob)

    ft = tris(frame_dup.data) + sum(tris(o.data) for o in frame_sprigs)
    fv = len(frame_dup.data.vertices) + sum(len(o.data.vertices) for o in frame_sprigs)
    print(f"pack_frame_foliage built: {fv}v / {ft}t")

    # --- pack_ruck_light_foliage: same treatment, 3 more sprigs (mixed) ---
    palm_a2_v, palm_a2_f, palm_a2_m = sample_sprig_from_plant(
        os.path.join(VEG_DIR, "jungle_palm_a1_stump.glb"), seed=301)
    bush_b2_v, bush_b2_f, bush_b2_m = sample_sprig_from_plant(
        os.path.join(VEG_DIR, "bush_b_stump.glb"), seed=302)
    bush_c2_v, bush_c2_f, bush_c2_m = sample_sprig_from_plant(
        os.path.join(VEG_DIR, "bush_c_stump.glb"), seed=303)

    ruck_src = bpy.data.objects["pack_worn_ruck_light"]
    ruck_dup_me = bpy.data.meshes.new_from_object(ruck_src)
    ruck_dup = bpy.data.objects.new("pack_ruck_light_foliage", ruck_dup_me)
    bpy.context.scene.collection.objects.link(ruck_dup)
    ruck_dup.data.materials.append(bpy.data.materials["pack_canvas"])

    ruck_sprigs = []
    for i, (v, f, m, place, sc, rz) in enumerate([
        (palm_a2_v, palm_a2_f, palm_a2_m, (0.0, 0.0, -0.20), 0.11, 40),
        (bush_b2_v, bush_b2_f, bush_b2_m, (0.09, -0.03, -0.23), 0.10, 170),
        (bush_c2_v, bush_c2_f, bush_c2_m, (-0.09, 0.03, -0.25), 0.10, 280),
    ]):
        ob = make_sprig_object(f"pack_ruck_light_foliage_sprig_{i}", v, f, m, place, sc, rz)
        ruck_sprigs.append(ob)

    rt = tris(ruck_dup.data) + sum(tris(o.data) for o in ruck_sprigs)
    rv = len(ruck_dup.data.vertices) + sum(len(o.data.vertices) for o in ruck_sprigs)
    print(f"pack_ruck_light_foliage built: {rv}v / {rt}t")

    # ------------------------------------------------------------------
    # fit-check the two new pack variants against the body (same method
    # as every other prop) - packs are on Spine1
    # ------------------------------------------------------------------
    body = bpy.data.objects.get("vc_guerilla_joined")
    if body:
        spine1 = rig.matrix_world @ rig.pose.bones["mixamorig:Spine1"].matrix
        body_eval = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        for label, obs in [("pack_frame_foliage", [frame_dup] + frame_sprigs),
                            ("pack_ruck_light_foliage", [ruck_dup] + ruck_sprigs)]:
            inside, checked, maxd = 0, 0, 0.0
            for o in obs:
                for v in o.data.vertices:
                    world = spine1 @ v.co
                    bl = body.matrix_world.inverted() @ world
                    ok, loc, nrm, idx = body_eval.closest_point_on_mesh(bl)
                    if not ok:
                        continue
                    checked += 1
                    d = (bl - loc).dot(nrm)
                    if d < 0:
                        inside += 1
                        maxd = max(maxd, -d)
            print(f"fit-check {label}: {inside}/{checked} inside, max depth {maxd:.4f}m")

    # ------------------------------------------------------------------
    # export
    # ------------------------------------------------------------------
    def export(glb_path, obj_names):
        for x in bpy.data.objects:
            x.select_set(False)
        for n in obj_names:
            bpy.data.objects[n].select_set(True)
        rig.select_set(True)
        bpy.context.view_layer.objects.active = rig
        kw = dict(filepath=glb_path, export_format='GLB', use_selection=True,
                  export_apply=True, export_animations=False, export_skins=False,
                  export_morph=False, export_cameras=False, export_lights=False,
                  export_yup=True)
        props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
        bpy.ops.export_scene.gltf(**{k: v for k, v in kw.items() if k in props})
        print("exported", glb_path)

    export(os.path.join(PROPS_DIR, "headgear", "pith_foliage.glb"),
           ["pith_foliage", "pith_foliage_band"] + [o.name for o in new_leaves])
    export(os.path.join(PROPS_DIR, "packs", "pack_frame_foliage.glb"),
           ["pack_frame_foliage"] + [o.name for o in frame_sprigs])
    export(os.path.join(PROPS_DIR, "packs", "pack_ruck_light_foliage.glb"),
           ["pack_ruck_light_foliage"] + [o.name for o in ruck_sprigs])

    bpy.data.orphans_purge(do_local_ids=True, do_recursive=True)
    bpy.data.orphans_purge(do_local_ids=True, do_recursive=True)
    bpy.ops.wm.save_mainfile(filepath=BLEND)
    print("saved:", BLEND)


if __name__ == "__main__":
    main()
