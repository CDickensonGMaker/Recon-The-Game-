"""Generate the gib donor set for vc_guerilla_v2.blend from the dressed body.

Mirrors the us_grunt_v2 gib contract (gib_system.gd / Bible 09 / bead 1xqs):
  - per-region skinned meshes named grunt_<region> (engine name contract —
    'grunt' is the convention prefix, faction-agnostic)
  - gore cap meshes named cap_<region>: one sealing face on the BODY side of
    each cut, weighted to the anchor bone so it stays on the stump
  - donors hidden in viewport (engine re-applies that intent at runtime),
    renderable so they ship in the glb

Regenerate anytime the body mesh/materials change — deletes and rebuilds.
Run inside the open vc_guerilla_v2.blend (MCP) or:
    blender -b vc_guerilla_v2.blend -P tools/make_vc_gibs.py  (then save!)
"""
import bpy, bmesh
from mathutils import Vector

BODY = "Base_Human"
RIG = "PSXRig"

REGION_BONES = {
    "head":      ["mixamorig:Head", "mixamorig:HeadTop_End", "mixamorig:Neck"],
    "torso":     ["mixamorig:Spine", "mixamorig:Spine1", "mixamorig:Spine2", "mixamorig:Hips"],
    "uparm_l":   ["mixamorig:LeftArm", "mixamorig:LeftShoulder"],
    "uparm_r":   ["mixamorig:RightArm", "mixamorig:RightShoulder"],
    "forearm_l": ["mixamorig:LeftForeArm", "mixamorig:LeftHand"],
    "forearm_r": ["mixamorig:RightForeArm", "mixamorig:RightHand"],
    "leg_l":     ["mixamorig:LeftUpLeg", "mixamorig:LeftLeg", "mixamorig:LeftFoot", "mixamorig:LeftToeBase"],
    "leg_r":     ["mixamorig:RightUpLeg", "mixamorig:RightLeg", "mixamorig:RightFoot", "mixamorig:RightToeBase"],
}
# fingers/toes fold into their limb
PREFIX_FOLD = {"mixamorig:LeftHand": "forearm_l", "mixamorig:RightHand": "forearm_r",
               "mixamorig:LeftToe": "leg_l", "mixamorig:RightToe": "leg_r"}
CAP_ANCHOR = {"head": "mixamorig:Neck", "torso": "mixamorig:Hips",
              "uparm_l": "mixamorig:LeftShoulder", "uparm_r": "mixamorig:RightShoulder",
              "forearm_l": "mixamorig:LeftArm", "forearm_r": "mixamorig:RightArm",
              "leg_l": "mixamorig:Hips", "leg_r": "mixamorig:Hips"}

body = bpy.data.objects[BODY]
rig = bpy.data.objects[RIG]

def hx(h):
    h = h.lstrip('#')
    return tuple((int(h[i:i+2], 16) / 255) ** 2.2 for i in (0, 2, 4))
gore = bpy.data.materials.get("gore_cap_mat")
if gore is None:
    gore = bpy.data.materials.new("gore_cap_mat")
    gore.use_nodes = True
    b = next(n for n in gore.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs['Base Color'].default_value = (*hx("#5a0d08"), 1)
    b.inputs['Roughness'].default_value = 0.6
    gore.diffuse_color = (*hx("#5a0d08"), 1)

# vertex -> region by dominant group weight
gidx_to_region = {}
for g in body.vertex_groups:
    region = None
    for r, bones in REGION_BONES.items():
        if g.name in bones:
            region = r
            break
    if region is None:
        for pref, r in PREFIX_FOLD.items():
            if g.name.startswith(pref):
                region = r
                break
    gidx_to_region[g.index] = region

def vert_region(v):
    best, best_w = "torso", 0.0
    acc = {}
    for ge in v.groups:
        r = gidx_to_region.get(ge.group)
        if r:
            acc[r] = acc.get(r, 0.0) + ge.weight
    for r, w in acc.items():
        if w > best_w:
            best, best_w = r, w
    return best

me = body.data
vreg = [vert_region(v) for v in me.vertices]
def face_region(poly):
    acc = {}
    for vi in poly.vertices:
        acc[vreg[vi]] = acc.get(vreg[vi], 0) + 1
    return max(acc, key=acc.get)
freg = [face_region(p) for p in me.polygons]

# wipe previous generation
for o in list(bpy.data.objects):
    if o.name.startswith(("grunt_", "cap_")):
        bpy.data.objects.remove(o, do_unlink=True)

made = []
for region in REGION_BONES:
    # ---- donor piece: duplicate body, keep only this region's faces ----
    dup = body.copy()
    dup.data = body.data.copy()
    bpy.context.scene.collection.objects.link(dup)
    dup.name = f"grunt_{region}"
    bm = bmesh.new()
    bm.from_mesh(dup.data)
    bm.faces.ensure_lookup_table()
    kill = [f for f in bm.faces if freg[f.index] != region]
    bmesh.ops.delete(bm, geom=kill, context='FACES')
    # drop loose verts
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context='VERTS')
    bm.to_mesh(dup.data)
    bm.free()
    dup.hide_set(True)       # donor: hidden in viewport, ships in the glb
    dup.hide_render = False
    made.append((dup.name, len(dup.data.vertices)))

    # ---- gore cap: seal ring on the BODY side, anchored to the stump bone ----
    # ring = verts this region shares with any other region
    ring_ids = set()
    for p in me.polygons:
        if freg[p.index] != region:
            continue
        for vi in p.vertices:
            for p2_idx in range(len(me.polygons)):
                pass  # placeholder (adjacency below)
    # adjacency via edges instead (cheap on 203 verts)
    other = set()
    mine = set()
    for p in me.polygons:
        tgt = mine if freg[p.index] == region else other
        tgt.update(p.vertices)
    ring_ids = sorted(mine & other)
    if not ring_ids or region == "torso":
        continue  # torso is the core; no single cap ring
    coords = [me.vertices[i].co.copy() for i in ring_ids]
    c = sum(coords, Vector()) / len(coords)
    # order ring by angle around its centroid for a clean fan
    n = (coords[0] - c).cross(coords[1 % len(coords)] - c)
    if n.length < 1e-9:
        n = Vector((0, 0, 1))
    n.normalize()
    ref = (coords[0] - c).normalized()
    import math
    def ang(co):
        v = (co - c)
        v = v - n * v.dot(n)
        if v.length < 1e-9:
            return 0.0
        v.normalize()
        s = ref.cross(v).dot(n)
        return math.atan2(s, ref.dot(v))
    order = sorted(range(len(coords)), key=lambda i: ang(coords[i]))
    cme = bpy.data.meshes.new(f"cap_{region}")
    cme.from_pydata([tuple(coords[i]) for i in order], [], [tuple(range(len(order)))])
    cme.update()
    cap = bpy.data.objects.new(f"cap_{region}", cme)
    bpy.context.scene.collection.objects.link(cap)
    cme.materials.append(gore)
    cap.parent = rig
    cap.parent_type = 'OBJECT'
    vg = cap.vertex_groups.new(name=CAP_ANCHOR[region])
    vg.add(list(range(len(order))), 1.0, 'REPLACE')
    mod = cap.modifiers.new("Armature", 'ARMATURE')
    mod.object = rig
    cap.hide_set(True)
    cap.hide_render = False
    made.append((cap.name, len(order)))

print("generated:", made)
