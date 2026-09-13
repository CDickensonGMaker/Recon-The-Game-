"""Stage 1 of the gore-pile pipeline: pull static, world-space, faction-scaled body parts
out of the READ-ONLY character files. Nothing here ever saves a donor file.

Every extracted part is a plain mesh (no rig, no vertex groups, transforms applied) whose
origin is its own bbox centre, facing +Y (the donor's face direction is measured, not
assumed) and standing in the donor's T-pose or in one of the authored limb bends.
"""
import bpy, bmesh, math
from mathutils import Vector, Matrix

ROOT = r"C:\Users\caleb\RECONgame"
US_BLEND = ROOT + r"\assets\us\characters\us_base_v3.blend"
NVA_BLEND = ROOT + r"\assets\nva_vc\props\nva_vc_gear_variants.blend"
HELM_BLEND = ROOT + r"\assets\us\characters\helmet_variants.blend"

PIECES = ["head", "torso", "uparm_l", "uparm_r", "forearm_l", "forearm_r", "leg_l", "leg_r"]

# region -> bones whose dominant weight puts a vertex in that region (make_vc_gibs.py table)
REGION_BONES = {
    "head":      ["Head", "HeadTop_End", "Neck"],
    "torso":     ["Spine", "Spine1", "Spine2", "Hips"],
    "uparm_l":   ["LeftArm", "LeftShoulder"],
    "uparm_r":   ["RightArm", "RightShoulder"],
    "forearm_l": ["LeftForeArm", "LeftHand"],
    "forearm_r": ["RightForeArm", "RightHand"],
    "leg_l":     ["LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase", "LeftToe_End"],
    "leg_r":     ["RightUpLeg", "RightLeg", "RightFoot", "RightToeBase", "RightToe_End"],
}
PREFIX_FOLD = {"LeftHand": "forearm_l", "RightHand": "forearm_r", "LeftToe": "leg_l", "RightToe": "leg_r"}

# authored limb bends, degrees about the bone's local X (sign resolved by measurement)
BENDS = {
    "straight": {},
    "bent": {"LeftLeg": 40, "RightLeg": 55, "LeftForeArm": 35, "RightForeArm": 50,
             "LeftHand": 25, "RightHand": -20, "LeftFoot": 20, "RightFoot": 25},
}


def _bone(rig, short):
    for sep in ("mixamorig_", "mixamorig:"):
        pb = rig.pose.bones.get(sep + short)
        if pb:
            return pb
    return None


def append(path, names):
    have = set(bpy.data.objects.keys())
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        missing = [n for n in names if n not in src.objects]
        if missing:
            raise RuntimeError("%s lacks %s" % (path, missing))
        dst.objects = list(names)
    got = []
    for o in bpy.data.objects:
        if o.name not in have:
            if o.name not in bpy.context.scene.collection.objects:
                bpy.context.scene.collection.objects.link(o)
            got.append(o)
    # map requested name -> object (appending may rename on collision: 'PSXRig.001')
    res = {}
    for n in names:
        cands = [o for o in got if o.name == n or o.name.startswith(n + ".")]
        if not cands:
            raise RuntimeError("appended but not found: %s" % n)
        res[n] = cands[0]
    return res


def facing_of(head_obj):
    """World-space unit vector the donor's face looks along: mean normal of the polys on
    the face-atlas material of the head, evaluated."""
    dg = bpy.context.evaluated_depsgraph_get()
    eo = head_obj.evaluated_get(dg)
    m = eo.to_mesh()
    fi = [i for i, mt in enumerate(m.materials) if mt and mt.name.startswith("face_atlas_mat")]
    nrm = head_obj.matrix_world.to_3x3().inverted().transposed()
    acc = Vector((0, 0, 0))
    for p in m.polygons:
        if p.material_index in fi:
            acc += (nrm @ p.normal)
    eo.to_mesh_clear()
    acc.z = 0
    return acc.normalized()


def zero_pose(rig):
    rig.data.pose_position = 'POSE'
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)


def apply_bend(rig, bend, facing):
    """Set the authored bends. Sign of a knee/elbow bend is resolved by measurement:
    a knee must carry the foot BACKWARD (away from facing), an elbow carries the hand
    FORWARD."""
    zero_pose(rig)
    bpy.context.view_layer.update()
    for short, deg in BENDS[bend].items():
        pb = _bone(rig, short)
        if pb is None:
            continue
        pb.rotation_mode = 'XYZ'
        want_forward = "ForeArm" in short or "Hand" in short
        tip = pb
        while tip.children:
            tip = tip.children[0]
        t0 = (rig.matrix_world @ tip.tail).copy()
        pb.rotation_euler = (math.radians(deg), 0, 0)
        bpy.context.view_layer.update()
        t1 = (rig.matrix_world @ tip.tail).copy()
        moved = (t1 - t0)
        moved.z = 0
        fwd = moved.dot(facing)
        if (fwd > 0) != want_forward and abs(fwd) > 1e-4:
            pb.rotation_euler = (math.radians(-deg), 0, 0)
            bpy.context.view_layer.update()
    bpy.context.view_layer.update()


def bake_static(obj, name, facing):
    """Evaluated world-space copy, rotated so the donor's facing becomes +Y, origin at
    bbox centre. Returns (mesh, centre, donor_name) WITHOUT creating an object: linking an
    object into the scene while evaluated meshes are being read races the depsgraph's
    threaded eval-copy in 5.0.1 and crashes non-deterministically. Objects are created
    afterwards by materialise()."""
    dg = bpy.context.evaluated_depsgraph_get()
    eo = obj.evaluated_get(dg)
    m = eo.to_mesh()
    ang = math.atan2(facing.x, facing.y)  # rotate facing onto +Y
    R = Matrix.Rotation(ang, 4, 'Z')
    M = R @ obj.matrix_world
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bm.from_mesh(m)
    bm.transform(M)
    bm.to_mesh(me)
    bm.free()
    # ORIGINAL materials, never the evaluated mesh's: m.materials are the depsgraph's
    # copy-on-write IDs and a slot pointing at one dangles after the next evaluation
    for mt in obj.data.materials:
        me.materials.append(mt.original if mt else None)
    eo.to_mesh_clear()
    vs = [v.co for v in me.vertices]
    c = Vector(((min(v.x for v in vs) + max(v.x for v in vs)) / 2,
                (min(v.y for v in vs) + max(v.y for v in vs)) / 2,
                (min(v.z for v in vs) + max(v.z for v in vs)) / 2))
    for v in me.vertices:
        v.co -= c
    return (me, c, obj.name)


def materialise(pending):
    """{name: (mesh, centre, donor)} -> {name: object}, linked into the scene."""
    out = {}
    for name, (me, c, donor) in pending.items():
        no = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(no)
        no.location = c
        no["donor"] = donor
        out[name] = no
    return out


def split_regions(body, rig):
    """Cut a joined body into the 8 gib regions by dominant vertex group. Returns
    {region: object} of NEW mesh objects still bound to the rig (armature modifier)."""
    groups = {g.index: g.name for g in body.vertex_groups}

    def region_of_group(gname):
        s = gname.split(":")[-1]
        if s.startswith("mixamorig_"):
            s = s[len("mixamorig_"):]
        for pre, r in PREFIX_FOLD.items():
            if s.startswith(pre):
                return r
        for r, bones in REGION_BONES.items():
            if s in bones:
                return r
        return None

    me = body.data
    vreg = []
    for v in me.vertices:
        best, bw = None, -1
        for g in v.groups:
            if g.weight > bw:
                bw, best = g.weight, g.group
        vreg.append(region_of_group(groups.get(best, "")) if best is not None else None)
    out = {}
    for region in PIECES:
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.verts.ensure_lookup_table()
        doomed = []
        for f in bm.faces:
            cnt = {}
            for v in f.verts:
                r = vreg[v.index]
                cnt[r] = cnt.get(r, 0) + 1
            top = max(cnt, key=cnt.get)
            if top != region:
                doomed.append(f)
        bmesh.ops.delete(bm, geom=doomed, context='FACES')
        nm = bpy.data.meshes.new("split_" + region)
        bm.to_mesh(nm)
        bm.free()
        for mt in me.materials:
            nm.materials.append(mt)
        no = bpy.data.objects.new("split_" + region, nm)
        bpy.context.scene.collection.objects.link(no)
        for g in body.vertex_groups:
            no.vertex_groups.new(name=g.name)
        md = no.modifiers.new("arm", 'ARMATURE')
        md.object = rig
        no.parent = body.parent
        no.matrix_parent_inverse = body.matrix_parent_inverse.copy()
        no.matrix_basis = body.matrix_basis.copy()
        out[region] = no
    return out


def extract_faction(faction):
    """Returns dict name -> static object for one faction, in T-pose ('straight') and
    bent variants. Names: <faction>_<piece>_<bend>, <faction>_cap_<piece>_<bend>,
    <faction>_hat, <faction>_headfrag_NN."""
    out = {}
    if faction == "us":
        names = ["PSXRig"] + ["grunt_" + p for p in PIECES] + ["cap_" + p for p in PIECES]
        objs = append(US_BLEND, names)
        rig = objs["PSXRig"]
        parts = {p: objs["grunt_" + p] for p in PIECES}
        caps = {p: objs["cap_" + p] for p in PIECES}
        frags = {}
        hat = None
    elif faction == "nva":
        names = ["PSXRig"] + ["grunt_" + p for p in PIECES] + \
                ["cap_" + p for p in PIECES if p != "torso"] + \
                ["head_frag_%02d" % i for i in range(1, 8)] + ["pith_helmet_worn"]
        objs = append(NVA_BLEND, names)
        rig = objs["PSXRig"]
        parts = {p: objs["grunt_" + p] for p in PIECES}
        caps = {p: objs["cap_" + p] for p in PIECES if p != "torso"}
        frags = {i: objs["head_frag_%02d" % i] for i in range(1, 8)}
        hat = objs["pith_helmet_worn"]
    elif faction == "vc":
        names = ["vc_sapper_PSXRig", "vc_sapper_joined", "PSXRig", "rice_hat"]
        objs = append(NVA_BLEND, names)
        rig = objs["vc_sapper_PSXRig"]
        body = objs["vc_sapper_joined"]
        parts = split_regions(body, rig)
        caps = {}
        frags = {}
        hat = objs["rice_hat"]
    else:
        raise ValueError(faction)

    zero_pose(rig)
    bpy.context.view_layer.update()
    facing = facing_of(parts["head"])
    print("[donors] %s facing %s  rig scale %s" % (faction, tuple(round(v, 3) for v in facing), tuple(round(v, 3) for v in rig.matrix_world.to_scale())))

    for bend in BENDS:
        apply_bend(rig, bend, facing)
        for p, o in parts.items():
            out["%s_%s_%s" % (faction, p, bend)] = bake_static(o, "%s_%s_%s" % (faction, p, bend), facing)
        for p, o in caps.items():
            out["%s_cap_%s_%s" % (faction, p, bend)] = bake_static(o, "%s_cap_%s_%s" % (faction, p, bend), facing)
        if bend == "straight":
            for i, o in frags.items():
                out["%s_headfrag_%02d" % (faction, i)] = bake_static(o, "%s_headfrag_%02d" % (faction, i), facing)
            if hat is not None:
                if faction == "vc":
                    # rice_hat hangs on the blueprint PSXRig, whose facing is the same
                    # measured direction (same file, same rig family)
                    hf = facing
                else:
                    hf = facing
                out["%s_hat" % faction] = bake_static(hat, "%s_hat" % faction, hf)
    doomed = {o.name for o in list(objs.values()) + list(parts.values())}
    for n in doomed:
        o = bpy.data.objects.get(n)
        if o is not None:
            bpy.data.objects.remove(o, do_unlink=True)
    return materialise(out)


def extract_us_helmet():
    objs = append(HELM_BLEND, ["helm_cover"])
    o = objs["helm_cover"]
    pend = {"us_hat": bake_static(o, "us_hat", Vector((0, 1, 0)))}
    bpy.data.objects.remove(o, do_unlink=True)
    return materialise(pend)["us_hat"]


def extract_all():
    allp = {}
    for f in ("us", "nva", "vc"):
        allp.update(extract_faction(f))
    allp["us_hat"] = extract_us_helmet()
    # orphan rigs/actions/meshes the append dragged in
    for coll in (bpy.data.objects,):
        for o in list(coll):
            if o.type == 'ARMATURE':
                bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.outliner.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)
    return allp


def clear_scene():
    """Empty the factory scene WITHOUT read_factory_settings(use_empty=True), which
    crashes 5.0.1's depsgraph on the first evaluation after a library append."""
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.outliner.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)


if __name__ == "__main__":
    clear_scene()
    allp = extract_all()
    for n, o in sorted(allp.items()):
        m = o.data
        tris = sum(len(p.vertices) - 2 for p in m.polygons)
        vs = [o.matrix_world @ v.co for v in m.vertices]
        mn = tuple(round(min(v[i] for v in vs), 3) for i in range(3))
        mx = tuple(round(max(v[i] for v in vs), 3) for i in range(3))
        print("  %-26s t%4d  min=%s max=%s mats=%s uv=%s" % (n, tris, mn, mx, [s.material.name if s.material else None for s in o.material_slots], m.uv_layers.active is not None))
