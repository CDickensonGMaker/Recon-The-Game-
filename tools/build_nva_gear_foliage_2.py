"""NVA/VC gear library - foliage pass #2, sibling to tools/build_nva_gear_foliage.py
(mirrors its approach, naming and export conventions exactly - do not diverge).

Caleb's ask: "bushes and long grass bundles etc attached to props in variety" - the
first pass (build_nva_gear_foliage.py) used only bush_a/b/c + jungle_palm_a1/b1
sprigs. This pass adds LONG-GRASS SHEAF sprigs (sampled from grass_tuft_a/b/c.glb,
same "cut a real contiguous face-cluster" technique, no procedural geometry) mixed
with bush sprigs, so tied-on grass bundles read as horizontal sheaves next to the
bush sprigs' branch-tuck read, per the brief.

SOURCE (read-only, per standing instruction - never edited, never re-exported, only
IMPORTED into memory and sampled from):
    assets/world/vegetation/bush_a_stump.glb, bush_b_stump.glb, bush_c_stump.glb
    assets/world/vegetation/grass_tuft_a.glb, grass_tuft_b.glb, grass_tuft_c.glb

NEW variants, three families that had zero foliage coverage before this pass
(headgear already had pith_foliage; packs already had pack_frame_foliage +
pack_ruck_light_foliage from pass #1 - both untouched here):
  - rice_hat_foliage   (headgear) - grass sheaves tucked under the rice hat's own
    brim tie-cord line, bush sprig at the crown apex.
  - chest_rig_ak_foliage (chest)  - branches tucked under the AK chest rig's
    shoulder straps + a grass sheaf laid across the central pouch row.
  - bandolier_ammo_foliage (chest) - one grass sheaf tied across the bandolier
    strap (small item, one sprig is enough at this budget).

SKIPPED, flagged rather than guessed: helmet_foliage (steel pot helmet) already
exists in this file as orphaned WIP - 3 flat, untextured, procedural-looking
"leaf" cones (HelmFoliage/.001/.002 materials, no image, no jungle_atlas sampling)
sitting on helmet_plain_cover/helmet_plain_band. Neither helmet_plain NOR
helmet_foliage has ever been exported or entered into nva_vc_gear.json's headgear
list - the steel helmet is not a wired headgear archetype at all yet. Upgrading
its 3 placeholder leaves to real sampled sprigs (the fix pass #1 gave pith_foliage)
would be trivial geometry work, but it is not an "add a foliage variant to an
existing family" job - it is "stand up a whole new headgear archetype's manifest
entry", a bigger, un-asked-for scope decision. Left untouched; noted for Caleb.

    blender -b --factory-startup -P tools/build_nva_gear_foliage_2.py
"""
import bpy, bmesh, math, os, random
from mathutils import Vector

PROPS_DIR = r"C:\Users\caleb\RECONgame\assets\nva_vc\props"
BLEND = os.path.join(PROPS_DIR, "nva_vc_gear_variants.blend")
VEG_DIR = r"C:\Users\caleb\RECONgame\assets\world\vegetation"

NEW_OBJECTS = [
    "rice_hat_foliage",
    "rice_hat_foliage_sprig_0", "rice_hat_foliage_sprig_1", "rice_hat_foliage_sprig_2",
    "chest_rig_ak_foliage",
    "chest_rig_ak_foliage_sprig_0", "chest_rig_ak_foliage_sprig_1",
    "chest_rig_ak_foliage_sprig_2", "chest_rig_ak_foliage_sprig_3",
    "bandolier_ammo_foliage",
    "bandolier_ammo_foliage_sprig_0",
]


def purge_prior():
    for name in NEW_OBJECTS:
        ob = bpy.data.objects.get(name)
        if ob:
            bpy.data.objects.remove(ob, do_unlink=True)
    for _ in range(2):
        bpy.data.orphans_purge(do_local_ids=True, do_recursive=True)


def sample_sprig_from_plant(glb_path, seed):
    """Identical technique to build_nva_gear_foliage.py's function of the same
    name: import a source plant in a throwaway scene, cut a small tip cluster of
    its OWN faces (real sampled geometry, not procedural), return (verts, faces,
    material) in the plant's own local space, recentred to the cluster centroid."""
    before = set(bpy.data.objects.keys())
    bpy.ops.import_scene.gltf(filepath=glb_path)
    imported = [bpy.data.objects[n] for n in bpy.data.objects.keys() if n not in before]
    mesh_obs = [o for o in imported if o.type == 'MESH']
    src = mesh_obs[0]
    me = src.data
    mat = me.materials[0] if me.materials else None

    rnd = random.Random(seed)
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

    for o in imported:
        bpy.data.objects.remove(o, do_unlink=True)

    return verts, faces, mat


def make_sprig_object(name, verts, faces, mat, place_at, target_size, rot_z_deg):
    """Identical technique to build_nva_gear_foliage.py's function of the same
    name - target_size normalises against the sampled cluster's own diagonal,
    transform is baked into the mesh (this file's convention: verts are final)."""
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
    mw = ob.matrix_world.copy()
    for v in me.vertices:
        v.co = mw @ v.co
    ob.location = (0, 0, 0)
    ob.rotation_euler = (0, 0, 0)
    ob.scale = (1, 1, 1)
    return ob


def tris(me):
    return sum(max(0, len(p.vertices) - 2) for p in me.polygons)


def dup_with_material(src_name, new_name, mat_name):
    src = bpy.data.objects[src_name]
    me = bpy.data.meshes.new_from_object(src)
    ob = bpy.data.objects.new(new_name, me)
    bpy.context.scene.collection.objects.link(ob)
    if mat_name:
        ob.data.materials.append(bpy.data.materials[mat_name])
    return ob


def fit_check(label, obs, rig, bone_name, body):
    if not body:
        return
    pose_mat = rig.matrix_world @ rig.pose.bones[bone_name].matrix
    body_eval = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    inside, checked, maxd = 0, 0, 0.0
    for o in obs:
        for v in o.data.vertices:
            world = pose_mat @ v.co
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


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    purge_prior()
    rig = bpy.data.objects["PSXRig"]
    body = bpy.data.objects.get("vc_guerilla_joined")

    def sample(plant_file, seed):
        return sample_sprig_from_plant(os.path.join(VEG_DIR, plant_file), seed)

    # ------------------------------------------------------------------
    # rice_hat_foliage - headgear, grass sheaves under the brim tie + one
    # bush sprig at the crown apex (mix per the brief)
    # ------------------------------------------------------------------
    hat = dup_with_material("rice_hat_plain", "rice_hat_foliage", "rice_hat_plain_cover")
    g0v, g0f, g0m = sample("grass_tuft_a.glb", seed=401)
    g1v, g1f, g1m = sample("grass_tuft_b.glb", seed=402)
    b0v, b0f, b0m = sample("bush_a_stump.glb", seed=403)
    hat_sprigs = []
    for i, (v, f, m, place, sc, rz) in enumerate([
        (g0v, g0f, g0m, (0.18, 0.13, 0.05), 0.14, 30),   # grass sheaf, brim right
        (g1v, g1f, g1m, (-0.16, 0.13, -0.08), 0.13, 210),  # grass sheaf, brim left-back
        (b0v, b0f, b0m, (0.02, 0.25, 0.02), 0.10, 100),  # bush sprig, crown apex
    ]):
        hat_sprigs.append(make_sprig_object(f"rice_hat_foliage_sprig_{i}", v, f, m, place, sc, rz))
    ht = tris(hat.data) + sum(tris(o.data) for o in hat_sprigs)
    hv = len(hat.data.vertices) + sum(len(o.data.vertices) for o in hat_sprigs)
    print(f"rice_hat_foliage built: {hv}v / {ht}t")
    fit_check("rice_hat_foliage", [hat] + hat_sprigs, rig, "mixamorig:Head", body)

    # ------------------------------------------------------------------
    # chest_rig_ak_foliage - chest, branches tucked under the shoulder
    # straps + one grass sheaf laid across the central pouch row
    # ------------------------------------------------------------------
    rig_dup = dup_with_material("chest_rig_ak", "chest_rig_ak_foliage", "pack_canvas")
    b1v, b1f, b1m = sample("bush_b_stump.glb", seed=411)
    b2v, b2f, b2m = sample("bush_c_stump.glb", seed=412)
    g2v, g2f, g2m = sample("grass_tuft_c.glb", seed=413)
    b3v, b3f, b3m = sample("bush_a_stump.glb", seed=414)
    rig_sprigs = []
    # placements verified against vc_guerilla_joined's ACTUAL surface via
    # closest_point_on_mesh through the Spine2 pose transform (the same
    # method fit_check uses) - a grid scan of the chest volume found the
    # dead-centre area sits INSIDE the body at every Y/Z tried (the joined
    # mesh's chest front sits proud of the rig there), while the outer
    # thirds (|X| >= 0.14) clear it cleanly at every Z in the rig's own
    # 0.20-0.28 height band. First pass guessed absolute coords and drove
    # 2 of 4 sprigs up to 9.2cm into the body; this pass places every
    # sprig only at grid points that measured positive clearance.
    for i, (v, f, m, place, sc, rz) in enumerate([
        (b1v, b1f, b1m, (0.14, -0.07, 0.15), 0.10, 45),      # right strap, upper chest
        (b2v, b2f, b2m, (-0.14, -0.07, 0.14), 0.10, 300),    # left strap, upper chest
        (g2v, g2f, g2m, (-0.16, -0.07, -0.05), 0.13, 90),    # grass sheaf, lower left edge
        (b3v, b3f, b3m, (0.096, -0.023, -0.087), 0.09, 170),  # bush sprig, lower right pouch
    ]):
        rig_sprigs.append(make_sprig_object(f"chest_rig_ak_foliage_sprig_{i}", v, f, m, place, sc, rz))
    ct = tris(rig_dup.data) + sum(tris(o.data) for o in rig_sprigs)
    cv = len(rig_dup.data.vertices) + sum(len(o.data.vertices) for o in rig_sprigs)
    print(f"chest_rig_ak_foliage built: {cv}v / {ct}t")
    fit_check("chest_rig_ak_foliage", [rig_dup] + rig_sprigs, rig, "mixamorig:Spine2", body)

    # ------------------------------------------------------------------
    # bandolier_ammo_foliage - chest, one grass sheaf tied across the strap
    # (small item, one sprig matches its own modest tri budget)
    # ------------------------------------------------------------------
    band_dup = dup_with_material("bandolier_ammo", "bandolier_ammo_foliage", "pack_canvas")
    g3v, g3f, g3m = sample("grass_tuft_a.glb", seed=421)
    # same grid-scan-against-the-real-body method as chest_rig_ak_foliage's
    # fix, on Spine2 too (bandolier crosses the collarbone diagonally) -
    # the first guess sat on the strap centreline where the body clips
    # through it (100% embedded); the near-collar upper strap edge clears
    band_sprigs = [make_sprig_object("bandolier_ammo_foliage_sprig_0", g3v, g3f, g3m,
                                      (-0.10, -0.25, 0.12), 0.10, 60)]
    bt = tris(band_dup.data) + sum(tris(o.data) for o in band_sprigs)
    bv = len(band_dup.data.vertices) + sum(len(o.data.vertices) for o in band_sprigs)
    print(f"bandolier_ammo_foliage built: {bv}v / {bt}t")
    fit_check("bandolier_ammo_foliage", [band_dup] + band_sprigs, rig, "mixamorig:Spine2", body)

    # ------------------------------------------------------------------
    # export - same conventions as build_nva_gear_foliage.py
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

    export(os.path.join(PROPS_DIR, "headgear", "rice_hat_foliage.glb"),
           ["rice_hat_foliage"] + [o.name for o in hat_sprigs])
    export(os.path.join(PROPS_DIR, "chest", "chest_rig_ak_foliage.glb"),
           ["chest_rig_ak_foliage"] + [o.name for o in rig_sprigs])
    export(os.path.join(PROPS_DIR, "chest", "bandolier_ammo_foliage.glb"),
           ["bandolier_ammo_foliage"] + [o.name for o in band_sprigs])

    bpy.data.orphans_purge(do_local_ids=True, do_recursive=True)
    bpy.data.orphans_purge(do_local_ids=True, do_recursive=True)
    bpy.ops.wm.save_mainfile(filepath=BLEND)
    print("saved:", BLEND)


if __name__ == "__main__":
    main()
