"""hash_gate_blend.py - "you may add, you may not alter what's there" as a measurement.

    blender -b <file.blend> --python tools/hash_gate_blend.py -- --snapshot <out.json>
    blender -b <file.blend> --python tools/hash_gate_blend.py -- --verify <in.json> [--allow name,name]

or, from another headless script:  from hash_gate_blend import snapshot, verify

Fingerprints every OBJECT (mesh: per-index vertex coords, polygon/material table, active UV
layer, vertex-group weights; armature: bone count + rest matrices + pose-bone basis; all:
matrix_world, parent, parent_type/bone, hide_get/hide_viewport/hide_render, material slot
names, collection membership) and every IMAGE (size, is_float, packed, md5 of the pixel
buffer). verify() reports CHANGED / MISSING / ADDED by name; changed or missing fail the gate
unless the name is in the allow list. Added is reported, never failed - adding is the job.

Written 2026-09-13 for the McCleary/Champs build in conquest_of_worms_us_cast.blend, a file
Caleb saved himself with his own edits in it. Reused as-is for any shared .blend.
"""
import bpy
import sys
import json
import hashlib
import numpy as np

D = bpy.data


def _h(s):
    return hashlib.md5(s.encode() if isinstance(s, str) else s).hexdigest()[:16]


def mesh_fp(me):
    hv = hashlib.md5()
    for v in me.vertices:
        hv.update(("%.6f %.6f %.6f;" % tuple(v.co)).encode())
    hp = hashlib.md5()
    for p in me.polygons:
        hp.update(("%d:%s;" % (p.material_index, ",".join(map(str, p.vertices)))).encode())
    hu = hashlib.md5()
    if me.uv_layers and me.uv_layers.active:
        for l in me.uv_layers.active.data:
            hu.update(("%.6f %.6f;" % tuple(l.uv)).encode())
    hw = hashlib.md5()
    for v in me.vertices:
        for g in v.groups:
            hw.update(("%d:%d:%.5f;" % (v.index, g.group, g.weight)).encode())
    return dict(v=hv.hexdigest()[:16], p=hp.hexdigest()[:16], uv=hu.hexdigest()[:16], w=hw.hexdigest()[:16],
                nv=len(me.vertices), np=len(me.polygons), mats=[m.name if m else None for m in me.materials])


def arm_fp(o):
    hb = hashlib.md5()
    for b in o.data.bones:
        hb.update(b.name.encode())
        for r in b.matrix_local:
            hb.update(("%.5f %.5f %.5f %.5f;" % tuple(r)).encode())
    hp = hashlib.md5()
    for pb in o.pose.bones:
        for r in pb.matrix_basis:
            hp.update(("%.5f %.5f %.5f %.5f;" % tuple(r)).encode())
    return dict(bones=len(o.data.bones), rest=hb.hexdigest()[:16], pose=hp.hexdigest()[:16],
                pose_position=o.data.pose_position)


def obj_fp(o):
    d = dict(type=o.type,
             mw=_h(";".join("%.5f %.5f %.5f %.5f" % tuple(r) for r in o.matrix_world)),
             parent=o.parent.name if o.parent else None, ptype=o.parent_type,
             pbone=o.parent_bone if o.parent_type == 'BONE' else "",
             hide=[o.hide_get(), o.hide_viewport, o.hide_render],
             colls=sorted(c.name for c in o.users_collection),
             data=o.data.name if o.data else None)
    if o.type == 'MESH':
        d["mesh"] = mesh_fp(o.data)
        # lists, not tuples: a tuple round-trips through JSON as a list and the verify reads
        # every modifier stack as CHANGED (327 false fails on the first self-test, 2026-09-13)
        d["mods"] = [[m.type, getattr(m, "object", None).name if getattr(m, "object", None) else None] for m in o.modifiers]
        d["vgroups"] = [g.name for g in o.vertex_groups]
    elif o.type == 'ARMATURE':
        d["arm"] = arm_fp(o)
    return d


def img_fp(im):
    if im.size[0] == 0:
        return dict(size=[0, 0])
    w, h = im.size
    a = np.empty(w * h * im.channels, dtype=np.float32)
    im.pixels.foreach_get(a)
    return dict(size=[w, h], ch=im.channels, float=im.is_float, packed=im.packed_file is not None,
                px=hashlib.md5(a.tobytes()).hexdigest()[:16])


def snapshot():
    if bpy.context.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    return dict(objects={o.name: obj_fp(o) for o in D.objects},
                images={im.name: img_fp(im) for im in D.images},
                materials=sorted(m.name for m in D.materials),
                collections=sorted(c.name for c in D.collections))


def verify(snap, allow=()):
    if bpy.context.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    now = snapshot()
    changed, missing, added = [], [], []
    for kind in ("objects", "images"):
        for name, fp in snap[kind].items():
            if name not in now[kind]:
                missing.append("%s:%s" % (kind, name))
            elif now[kind][name] != fp:
                diff = [k for k in fp if fp.get(k) != now[kind][name].get(k)]
                changed.append("%s:%s (%s)" % (kind, name, ",".join(diff)))
        for name in now[kind]:
            if name not in snap[kind]:
                added.append("%s:%s" % (kind, name))
    bad = [x for x in changed + missing if x.split(" ")[0].split(":", 1)[1] not in allow]
    print("HASH GATE: %d objects + %d images fingerprinted before; now %d + %d. changed=%d missing=%d added=%d"
          % (len(snap["objects"]), len(snap["images"]), len(now["objects"]), len(now["images"]),
             len(changed), len(missing), len(added)), flush=True)
    for x in changed:
        print("   CHANGED  " + x, flush=True)
    for x in missing:
        print("   MISSING  " + x, flush=True)
    for x in added:
        print("   added    " + x, flush=True)
    return bad, changed, missing, added


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--snapshot" in argv:
        out = argv[argv.index("--snapshot") + 1]
        s = snapshot()
        with open(out, "w") as f:
            json.dump(s, f)
        print("SNAPSHOT %s: %d objects, %d images" % (out, len(s["objects"]), len(s["images"])), flush=True)
    elif "--verify" in argv:
        src = argv[argv.index("--verify") + 1]
        allow = argv[argv.index("--allow") + 1].split(",") if "--allow" in argv else []
        with open(src) as f:
            s = json.load(f)
        bad, *_ = verify(s, allow)
        if bad:
            print("HASH GATE FAIL (%d)" % len(bad), flush=True)
            sys.exit(1)
        print("HASH GATE PASS", flush=True)
    else:
        raise SystemExit("usage: -- --snapshot out.json | --verify in.json [--allow a,b]")
