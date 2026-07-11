"""Head fracture chunks for the HEAD BURST gib variant (bead rc55, art half).

Cuts the grunt_head gib donor into 6-9 chunks with deterministic
bmesh.ops.bisect_plane cuts (Cell Fracture is a UI addon - unavailable
headless - and planar cracks read better at PSX fidelity anyway). Chunks:
  * named head_frag_01..NN - engine contract: GibSystem.dismember_head_burst
    collects head_frag_* meshes, ModelActor hides them via the donor contract
  * interior cut faces sealed (bmesh.ops.holes_fill) and assigned to the gore
    material - gore_cap_mat, the same material the cap_* stumps use
  * skinned RIGID to the head: single vertex group mixamorig:Head at 1.0 +
    armature modifier on PSXRig, so chunks sit in the skull until they fly
  * exterior faces keep the head donor's materials/UVs EXACTLY as authored

Importable step for both character exporters (runs before export; a rig
without grunt_head skips cleanly):
    from make_head_frags import build_head_frags
    build_head_frags()

Standalone dry run (report only - NEVER saves the .blend):
    blender -b <character.blend> -P tools/make_head_frags.py
"""
import random

import bpy
import bmesh
from mathutils import Vector

HEAD = "grunt_head"
RIG = "PSXRig"
HEAD_BONE = "mixamorig:Head"
TARGET_CHUNKS = 7      # rc55 wants 6-12; the bisect tree lands 6-9
SEED = 20260711        # deterministic cracks - re-exports reproduce chunks
MIN_FACES = 2          # reject sliver halves below this
GORE_LAYER = "gore"    # bmesh int face layer marking interior cut faces


def _gore_material():
    m = bpy.data.materials.get("gore_cap_mat")
    if m is not None:
        return m
    for m in bpy.data.materials:
        if "gore" in m.name.lower():
            return m
    for o in bpy.data.objects:  # last resort: whatever the stumps use
        if o.type == 'MESH' and o.name.startswith("cap_"):
            for s in o.material_slots:
                if s.material is not None:
                    return s.material
    return None


def _strip_deform(bm):
    """Drop inherited body weights - chunks get ONE rigid group instead."""
    dl = bm.verts.layers.deform.active
    if dl is None:
        return
    try:
        bm.verts.layers.deform.remove(dl)
    except (AttributeError, RuntimeError):
        for v in bm.verts:
            v[dl].clear()


def _split(big, co, no):
    """Bisect one chunk into two sealed halves. Returns [bm, bm] or None if
    either half degenerates (plane missed or sliced off a sliver)."""
    halves = []
    for clear_inner, clear_outer in ((False, True), (True, False)):
        bm = big.copy()
        res = bmesh.ops.bisect_plane(
            bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:],
            plane_co=co, plane_no=no, dist=1e-5,
            clear_inner=clear_inner, clear_outer=clear_outer)
        cut = [e for e in res['geom_cut'] if isinstance(e, bmesh.types.BMEdge)]
        if cut:
            gl = bm.faces.layers.int[GORE_LAYER]
            fill = bmesh.ops.holes_fill(bm, edges=cut, sides=0)
            for f in fill['faces']:
                f[gl] = 1
        loose = [v for v in bm.verts if not v.link_faces]
        if loose:
            bmesh.ops.delete(bm, geom=loose, context='VERTS')
        halves.append(bm)
    if any(len(bm.faces) < MIN_FACES for bm in halves):
        for bm in halves:
            bm.free()
        return None
    return halves


def build_head_frags(head_name=HEAD, rig_name=RIG, target=TARGET_CHUNKS, seed=SEED):
    """Fracture head_name into head_frag_* donor objects. Returns the list of
    created object names ([] when the rig is off-contract - callers skip)."""
    head = bpy.data.objects.get(head_name)
    rig = bpy.data.objects.get(rig_name)
    if head is None or head.type != 'MESH' or rig is None:
        print(f"[FRAG] no {head_name}/{rig_name} in this scene - head frags skipped", flush=True)
        return []
    gore = _gore_material()
    if gore is None:
        print("[FRAG] no gore material found - head frags skipped", flush=True)
        return []
    bone = HEAD_BONE if HEAD_BONE in rig.data.bones else HEAD_BONE.replace(":", "_")
    if bone not in rig.data.bones:
        print(f"[FRAG] rig has no {HEAD_BONE} bone - head frags skipped", flush=True)
        return []
    rng = random.Random(seed)

    # wipe any previous generation (idempotent, like make_vc_gibs)
    for o in list(bpy.data.objects):
        if o.name.startswith("head_frag_"):
            me = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            if me is not None and me.users == 0:
                bpy.data.meshes.remove(me)

    # working copy of the donor mesh; make sure it carries the gore slot
    src = head.data.copy()
    src.name = "_head_frag_src"
    gore_idx = next((i for i, m in enumerate(src.materials) if m == gore), None)
    if gore_idx is None:
        src.materials.append(gore)
        gore_idx = len(src.materials) - 1

    bm0 = bmesh.new()
    bm0.from_mesh(src)
    _strip_deform(bm0)
    bm0.faces.layers.int.new(GORE_LAYER)

    # crack tree: always split the chunk with the most faces, planes through
    # its centroid at varied (seeded) angles, until the target count holds
    chunks = [bm0]
    stall = 0
    while len(chunks) < target and stall < 16:
        chunks.sort(key=lambda b: len(b.faces), reverse=True)
        big = chunks[0]
        c = sum((v.co for v in big.verts), Vector()) / max(len(big.verts), 1)
        no = Vector((rng.uniform(-1.0, 1.0), rng.uniform(-1.0, 1.0), rng.uniform(-1.0, 1.0)))
        if no.length < 1e-3:
            stall += 1
            continue
        no.normalize()
        co = c + no * rng.uniform(-0.008, 0.008)
        halves = _split(big, co, no)
        if halves is None:
            stall += 1
            continue
        chunks.pop(0)
        big.free()
        chunks.extend(halves)
        stall = 0

    made = []
    for i, bm in enumerate(chunks):
        gl = bm.faces.layers.int.get(GORE_LAYER)
        uvl = bm.loops.layers.uv.active
        for f in bm.faces:
            if gl is None or f[gl] != 1:
                continue
            f.material_index = gore_idx
            if uvl is not None:  # scatter interior UVs mid-texture on gore_tex
                u0, v0 = rng.uniform(0.25, 0.65), rng.uniform(0.25, 0.65)
                for j, l in enumerate(f.loops):
                    l[uvl].uv = (u0 + 0.1 * (j % 2), v0 + 0.1 * ((j // 2) % 2))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = src.copy()
        me.name = f"head_frag_{i + 1:02d}"
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(me.name, me)
        bpy.context.scene.collection.objects.link(ob)
        ob.parent = rig
        ob.parent_type = 'OBJECT'
        vg = ob.vertex_groups.new(name=bone)
        vg.add(list(range(len(me.vertices))), 1.0, 'REPLACE')
        mod = ob.modifiers.new("Armature", 'ARMATURE')
        mod.object = rig
        ob.hide_set(True)        # donor intent; the engine re-applies it anyway
        ob.hide_render = False
        made.append((ob.name, len(me.vertices), len(me.polygons)))

    bpy.data.meshes.remove(src)
    stats = ", ".join(f"{n}({v}v/{f}f)" for n, v, f in made)
    print(f"[FRAG] {len(made)} head fragments from {head_name}: {stats}", flush=True)
    return [n for n, _, _ in made]


if __name__ == "__main__":
    build_head_frags()
    print("[FRAG] standalone dry run complete (blend NOT saved)", flush=True)
