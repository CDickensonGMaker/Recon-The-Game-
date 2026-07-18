"""export_fsb_main.py - THE fsb_main.glb pipeline (council decree 2026-07-18).

Faithful realization of ASSEMBLY_fsb_battery from
production/props_workshop/firebase_chunks.blend. The authored file is never
modified, never saved.

Method (why it looks this way - two prior exporters got it wrong):
  - The 2026-07-17 exporter realized chunks at marker world-Y while dropping the
    chunk collections' internal compensating offsets -> every cluster floated by
    its marker height (+4.8m gate greeting the player). `duplicates_make_real`
    broke transforms a second way. The only trustworthy source is the EVALUATED
    DEPSGRAPH: `object_instances` matrices are world truth by definition.
  - Isolation by view-layer exclusion: only the assembly is visible while the
    depsgraph is read, so no other scene instancing can leak into the export.
  - NO auto floor-snap. The council ordered snap+assert; measurement showed the
    authored data realizes grounded and only the TOOLS were broken - a silent
    auto-fixer would have masked exactly that. The contact-band ASSERT aborts
    the export instead; fix the scene or the tool, never the artifact.

Contract enforced:
  - per chunk-instance GROUP, world min-Z in [-1.5, +0.35] (dug-in pits ok)
  - flat export: every node a scene root
  - names: <base>_<NNN>[-col]; meshes carry -col at the END (Godot trimesh);
    SOCKET_A_001 / SOCKET_B_001 / FACE_OUT_001 realize exactly once
    (site_planner.fsb_gate_metrics reads these names)
  - ground-plane XZ recentered so the combined AABB center = origin

USAGE (the Summoner's 60 seconds): in firebase_chunks.blend, SELECT the chunk
markers that make up the shippable core base (the wire + gate + pads cluster -
NOT the far-flung planning markers 300-530m out; the runtime contract is
FSB_HALF 178x172.2 and the tool asserts the extent), then run this script.
With nothing selected it falls back to ASSEMBLY_fsb_battery + the scene-root
supply rows - which today includes the far markers and will FAIL the extent
assert on purpose.
"""
import bpy
import re
from mathutils import Vector

ASSEMBLY = "ASSEMBLY_fsb_battery"
TMP_COLL = "EXPORT_TMP_fsb"
EXPORT_PATH_DEFAULT = r"C:\Users\caleb\RECONgame\assets\building models\structures\firebase\fsb_main.glb"
GROUP_MIN_OK = (-1.5, 0.35)
SCAFFOLD_PREFIXES = ("INST_", "CH_")


def _sanitize(nm):
    is_col = "-col" in nm
    nm = nm.replace("-col", "")
    nm = re.sub(r"\.\d+$", "", nm)
    return nm.replace(".", "_"), is_col


def run(export_path=EXPORT_PATH_DEFAULT):
    scene = bpy.context.scene
    view_layer = bpy.context.view_layer
    selected = [o for o in bpy.context.selected_objects
        if o.type == 'EMPTY' and o.instance_type == 'COLLECTION' and o.instance_collection]
    if selected:
        markers = selected
        print("[EXPORT_FSB] using SELECTION: %d chunk markers" % len(markers))
    else:
        src = bpy.data.collections.get(ASSEMBLY)
        assert src is not None, "assembly collection '%s' missing" % ASSEMBLY
        markers = list(src.all_objects)
        for o in markers:
            assert o.type == 'EMPTY' and o.instance_type == 'COLLECTION' and o.instance_collection, \
                "assembly contract broken: non-instancer '%s' (%s)" % (o.name, o.type)
    # The supply-corner rows (hootches, sandbags, tents) live at SCENE ROOT in
    # the working file, not in the assembly - the shipped baseline includes
    # them. In fallback mode root collection-instancers ship; everything else at
    # root is parked (a stray SOCKET marker would double the gate contract, and
    # the master collection cannot be view-layer-excluded).
    root_parked = []
    for o in list(scene.collection.objects):
        if o in markers:
            continue
        if not selected and o.type == 'EMPTY' and o.instance_type == 'COLLECTION' and o.instance_collection:
            markers.append(o)
        else:
            root_parked.append(o)

    old = bpy.data.collections.get(TMP_COLL)
    if old is not None:
        for ob in list(old.objects):
            if ob.name.startswith("__exp") or "_FSBEXP" in ob.name:
                bpy.data.objects.remove(ob, do_unlink=True)
        bpy.data.collections.remove(old)
    tmp = bpy.data.collections.new(TMP_COLL)
    scene.collection.children.link(tmp)
    park = bpy.data.collections.new(TMP_COLL + "_park")
    scene.collection.children.link(park)
    for o in markers:
        tmp.objects.link(o)

    # isolate: only the tmp collection contributes to the depsgraph. The master
    # collection cannot be excluded, so root non-instancers move to the parked
    # (excluded) collection for the duration - restored in finally.
    prior = {}
    def _walk(lc):
        for child in lc.children:
            if child.collection is not tmp:
                prior[child] = child.exclude
                child.exclude = True
            _walk(child)
    created = []
    try:
        _walk(view_layer.layer_collection)
        for o in root_parked:
            scene.collection.objects.unlink(o)
            park.objects.link(o)
        # root instancers stay linked in master AND tmp - single depsgraph entry
        view_layer.update()
        deps = bpy.context.evaluated_depsgraph_get()

        # realize from depsgraph world truth
        specs = []   # (orig_name, data_or_None, matrix, group_key)
        for inst in deps.object_instances:
            if not inst.is_instance:
                continue
            ob = inst.instance_object
            par = inst.parent
            gkey = (par.original.name,
                tuple(round(v, 4) for v in par.matrix_world.translation)) if par else ("_", ())
            if ob.type == 'MESH':
                specs.append((ob.original.name, ob.original.data, inst.matrix_world.copy(), gkey))
            elif ob.type == 'EMPTY' and not ob.original.name.startswith(SCAFFOLD_PREFIXES) \
                    and ob.original.instance_type != 'COLLECTION':
                specs.append((ob.original.name, None, inst.matrix_world.copy(), gkey))
        assert len(specs) > 400, "suspiciously few realized instances (%d) - isolation broke" % len(specs)

        # runtime footprint contract: site_planner FSB_HALF is 178 x 172.2 and
        # the whole patrol economy (keep-out, plateau, density bands) hangs off
        # it. A selection that sweeps in the far planning markers fails HERE.
        ext_x, ext_y = [], []
        for nm, data, mw, _g in specs:
            if data is None:
                continue
            for c in [Vector(v) for v in _mesh_bounds(data)]:
                w = mw @ c
                ext_x.append(w.x)
                ext_y.append(w.y)
        span = (max(ext_x) - min(ext_x), max(ext_y) - min(ext_y))
        assert span[0] <= 400.0 and span[1] <= 390.0, \
            "EXPORT ABORTED - content spans %.0fx%.0fm; the core base contract is 356x344 " \
            "(FSB_HALF). Far planning markers are in the selection." % span

        # contact-band assert per chunk-instance group, BEFORE creating anything
        gmin = {}
        for nm, data, mw, gkey in specs:
            if data is None:
                continue
            lo = None
            for c in [Vector(v) for v in _mesh_bounds(data)]:
                z = (mw @ c).z
                lo = z if lo is None else min(lo, z)
            if lo is None:
                continue
            cur = gmin.get(gkey)
            gmin[gkey] = lo if cur is None else min(cur, lo)
        bad = sorted(((round(v, 3), k[0]) for k, v in gmin.items()
            if v < GROUP_MIN_OK[0] or v > GROUP_MIN_OK[1]), reverse=True)
        assert not bad, "EXPORT ABORTED - chunk groups outside contact band %s: %s" % (
            GROUP_MIN_OK, bad[:10])

        # create real objects
        for nm, data, mw, _g in specs:
            new = bpy.data.objects.new(nm + "_FSBEXP", data)
            new.matrix_world = mw
            tmp.objects.link(new)
            created.append(new)
        view_layer.update()

        # deterministic rename: stash bases from the ORIGINAL names
        stash = {ob: _sanitize(ob.name.replace("_FSBEXP", "")) for ob in created}
        for i, ob in enumerate(created):
            ob.name = "__exp_%05d" % i
        def order_key(ob):
            base, _ = stash[ob]
            l = ob.location
            return (base, round(l.x, 3), round(l.y, 3), round(l.z, 3))
        counters = {}
        for ob in sorted(created, key=order_key):
            base, is_col = stash[ob]
            n = counters.get(base, 0) + 1
            counters[base] = n
            want = "%s_%03d%s" % (base, n, "-col" if ob.type == 'MESH' else "")
            holder = bpy.data.objects.get(want)
            assert holder is None or holder in created, \
                "name '%s' held by non-export object - refusing to steal it" % want
            ob.name = want
            assert ob.name == want, "Blender rejected '%s' (got '%s')" % (want, ob.name)
        for key in ("SOCKET_A", "SOCKET_B", "FACE_OUT"):
            assert counters.get(key, 0) == 1, \
                "gate marker %s realized %d times (want exactly 1)" % (key, counters.get(key, 0))

        # recenter ground-plane XZ (Blender XY)
        xs, ys = [], []
        for ob in created:
            if ob.type != 'MESH':
                continue
            mw = ob.matrix_world
            for c in _mesh_bounds(ob.data):
                w = mw @ Vector(c)
                xs.append(w.x)
                ys.append(w.y)
        cx = (min(xs) + max(xs)) * 0.5
        cy = (min(ys) + max(ys)) * 0.5
        for ob in created:
            ob.location.x -= cx
            ob.location.y -= cy
        view_layer.update()

        # export
        bpy.ops.object.select_all(action='DESELECT')
        for ob in created:
            ob.select_set(True)
        bpy.context.view_layer.objects.active = created[0]
        bpy.ops.export_scene.gltf(
            filepath=export_path,
            use_selection=True,
            export_format='GLB',
            export_apply=True,
            export_animations=False,
            export_skins=False,
            export_morph=False,
            export_cameras=False,
            export_lights=False,
            export_extras=False,
        )
        n_meshes = sum(1 for ob in created if ob.type == 'MESH')
        result = {"groups": len(gmin), "meshes": n_meshes,
            "markers": len(created) - n_meshes, "export": export_path}
        print("[EXPORT_FSB] %s" % result)
        return result
    finally:
        for ob in created:
            bpy.data.objects.remove(ob, do_unlink=True)
        for o in root_parked:
            if o.name not in scene.collection.objects:
                scene.collection.objects.link(o)
        for lc, was in prior.items():
            try:
                lc.exclude = was
            except ReferenceError:
                pass
        for cname in (TMP_COLL + "_park", TMP_COLL):
            if cname in bpy.data.collections:
                bpy.data.collections.remove(bpy.data.collections[cname])
        view_layer.update()


_BOUNDS_CACHE = {}

def _mesh_bounds(data):
    key = data.name_full
    hit = _BOUNDS_CACHE.get(key)
    if hit is not None:
        return hit
    if len(data.vertices) == 0:
        box = [(0.0, 0.0, 0.0)]
    else:
        xs = [v.co.x for v in data.vertices]
        ys = [v.co.y for v in data.vertices]
        zs = [v.co.z for v in data.vertices]
        lo = (min(xs), min(ys), min(zs))
        hi = (max(xs), max(ys), max(zs))
        box = [(x, y, z) for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])]
    _BOUNDS_CACHE[key] = box
    return box


if __name__ == "__main__":
    run()
