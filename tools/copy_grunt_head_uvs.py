"""copy_grunt_head_uvs.py - put the game's canonical grunt head wrap on a cast head, in its own cell.

    "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" --background ^
        assets/ww1/characters/conquest_of_worms_ww1.blend --python tools/copy_grunt_head_uvs.py -- --tags a,b,c [--save]

Caleb's ruling 2026-09-12 (night): "fix all the uv wraps to match the grunts." The roster's heads are
what he sees every session; the CoW full-cell projection (tools/project_cow_head_uvs.py) is a
different wrap. This tool copies the ROSTER wrap onto each named head, poly by poly, by POSITION:

  source (read-only, appended from us_base_v3.blend and removed again before any save):
    grunt_head_rifleman        30 head polys, face_atlas cell col 0 row_b 0
    us_grunt_joined_rifleman   the joined body: 30 head polys + 20 neck polys + 62 hand/forearm
                               polys on the face material, cell col 0 row_b 4
  target: us_grunt_joined_<tag> (body) and grunt_head_<tag> (gib donor), any cast built on them.

Every face-material poly of the target whose centre is in the head region (z > 1.45 rig-local,
|x| < 0.12) takes the UVs of the SAME poly (centre within 12 mm, loops by vertex within 5 mm) of
grunt_head_rifleman if it has one, else of the joined body; unmatched polys are left alone and
reported. The UVs are shifted from the source cell to the target's own cell (measured from where
its island already sits: (col/10, row_b/7) origins), so each man keeps sampling his own painted
cell. Hands/forearms on the face material are not touched.

Gates: no vertex moves (coordinate hash), poly/loop counts unchanged, every written loop inside the
target's cell rect, untouched loops bit-identical, per head: 30 head polys matched (26+ from
grunt_head), 20 neck polys matched from the body, residuals printed (max centre distance, max loop
vertex distance).
"""
import bpy
import os
import sys
import math
import hashlib
from mathutils import Vector

D = bpy.data
ROOT = r"C:\Users\caleb\RECONgame"
SRC = os.path.join(ROOT, "assets", "us", "characters", "us_base_v3.blend")
FACE_COLS, FACE_ROWS = 10, 7
ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SAVE = "--save" in ARGV
TAGS = next((a.split("=", 1)[1] if "=" in a else ARGV[ARGV.index(a) + 1] for a in ARGV if a.startswith("--tags")), "")
TAGS = [t for t in TAGS.split(",") if t]
CENTRE_TOL = 0.012
LOOP_TOL = 0.005


def coord_hash(me):
    h = hashlib.sha1()
    for v in me.vertices:
        h.update(("%.7f %.7f %.7f" % tuple(v.co)).encode())
    return h.hexdigest()[:12]


def rig_frame(o):
    off = o.parent.matrix_world.translation.copy() if o.parent else Vector((0, 0, 0))
    M = o.matrix_world
    return lambda v: M @ v - off


def face_polys(o):
    me = o.data
    fi = {i for i, m in enumerate(me.materials) if m and m.name.startswith("face_atlas")}
    assert fi, o.name + ": no face_atlas material"
    return [p for p in me.polygons if p.material_index in fi]


def head_polys(o):
    co = rig_frame(o)
    out = []
    for p in face_polys(o):
        c = co(p.center)
        if c.z > 1.45 and abs(c.x) < 0.12:
            out.append(p)
    return out


def cell_origin(o, polys):
    uv = o.data.uv_layers.active.data
    us = [uv[l].uv.x for p in polys for l in p.loop_indices]
    vs = [uv[l].uv.y for p in polys for l in p.loop_indices]
    col = int(math.floor(sum(us) / len(us) * FACE_COLS))
    row_b = int(math.floor(sum(vs) / len(vs) * FACE_ROWS))
    return col, row_b, Vector((col / FACE_COLS, row_b / FACE_ROWS))


def source_table(o):
    """(centre, [(vertex_pos, uv)...]) per head poly, rig frame."""
    co = rig_frame(o)
    uv = o.data.uv_layers.active.data
    me = o.data
    tab = []
    for p in head_polys(o):
        loops = [(co(me.vertices[me.loops[l].vertex_index].co), uv[l].uv.copy()) for l in p.loop_indices]
        tab.append((co(p.center), loops, p.index))
    return tab


def append_sources():
    names = ["grunt_head_rifleman", "us_grunt_joined_rifleman", "PSXRig_rifleman"]
    with bpy.data.libraries.load(SRC, link=False) as (src, dst):
        missing = [n for n in names if n not in src.objects]
        assert not missing, "us_base_v3 lacks %s" % missing
        dst.objects = names
    got = {}
    for o in dst.objects:
        o.name = "_SRC_" + o.name
        bpy.context.scene.collection.objects.link(o)
        got[o.name] = o
    # the meshes' parents are the appended rig; the append keeps the parent relation
    bpy.context.view_layer.update()
    return got


def remove_sources(got):
    for o in list(got.values()):
        data = o.data
        D.objects.remove(o, do_unlink=True)
        if data is not None and data.users == 0:
            (D.meshes if isinstance(data, bpy.types.Mesh) else D.armatures).remove(data)


def copy_onto(target, tabs, label):
    me = target.data
    uv = me.uv_layers.active.data
    co = rig_frame(target)
    heads = head_polys(target)
    assert len(heads) in (30, 50), "%s: %d head polys" % (label, len(heads))
    col, row_b, origin = cell_origin(target, heads)
    before = coord_hash(me)
    n_polys, n_loops = len(me.polygons), len(me.loops)
    untouched = {l: uv[l].uv.copy() for p in me.polygons for l in p.loop_indices if p not in heads}
    stats = dict(gh=0, jb=0, none=0, max_c=0.0, max_l=0.0, unmatched=[])
    for p in heads:
        c = co(p.center)
        best = None
        for src_name, tab, src_origin in tabs:
            for (sc, loops, si) in tab:
                d = (sc - c).length
                if d <= CENTRE_TOL and (best is None or d < best[0]):
                    best = (d, src_name, loops, src_origin, si)
            if best is not None:
                break                                   # grunt_head first, the body only as a fallback
        if best is None:
            stats["none"] += 1
            stats["unmatched"].append((p.index, tuple(round(v, 3) for v in c)))
            continue
        d, src_name, loops, src_origin, si = best
        stats[src_name] += 1
        stats["max_c"] = max(stats["max_c"], d)
        for l in p.loop_indices:
            vpos = co(me.vertices[me.loops[l].vertex_index].co)
            lv, luv = min(loops, key=lambda t: (t[0] - vpos).length)
            dl = (lv - vpos).length
            assert dl <= LOOP_TOL, "%s: poly %d loop %.1f mm off its partner" % (label, p.index, dl * 1000)
            stats["max_l"] = max(stats["max_l"], dl)
            new = luv - src_origin + origin
            uv[l].uv = new
    # gates
    assert coord_hash(me) == before, label + ": VERTEX DATA CHANGED"
    assert (len(me.polygons), len(me.loops)) == (n_polys, n_loops)
    for l, old in untouched.items():
        assert uv[l].uv == old, label + ": untouched loop %d moved" % l
    outside = 0
    for p in heads:
        for l in p.loop_indices:
            u, v = uv[l].uv
            # the roster wrap itself reaches v 0.1435 in a 0.1429-tall cell (0.7 px past the top edge,
            # inherited); one texel of tolerance
            tol = 1.0 / 1132.0
            if not (origin.x - tol <= u <= origin.x + 1.0 / FACE_COLS + tol and origin.y - tol <= v <= origin.y + 1.0 / FACE_ROWS + tol):
                outside += 1
    assert outside == 0, "%s: %d loops outside cell col %d row_b %d" % (label, outside, col, row_b)
    neck = [p for p in heads if max(co(me.vertices[i].co).z for i in p.vertices) < 1.60]
    print("%-28s cell col %d row_b %d | %d head polys: %d from grunt_head, %d from the joined body, %d unmatched | "
          "residual centre max %.2f mm, loop vertex max %.2f mm | neck polys %d"
          % (label, col, row_b, len(heads), stats["gh"], stats["jb"], stats["none"],
             stats["max_c"] * 1000, stats["max_l"] * 1000, len(neck)))
    if stats["unmatched"]:
        print("   unmatched:", stats["unmatched"])
    assert stats["gh"] >= 26 and stats["none"] == 0, (label, stats)
    return stats


def run():
    assert bpy.context.mode == 'OBJECT'
    got = append_sources()
    gh = got["_SRC_grunt_head_rifleman"]
    jb = got["_SRC_us_grunt_joined_rifleman"]
    gh_tab = source_table(gh)
    jb_tab = source_table(jb)
    _, _, gh_origin = cell_origin(gh, head_polys(gh))
    _, _, jb_origin = cell_origin(jb, head_polys(jb))
    print("source: grunt_head_rifleman %d head polys (cell origin %s), us_grunt_joined_rifleman %d (origin %s)"
          % (len(gh_tab), tuple(round(v, 4) for v in gh_origin), len(jb_tab), tuple(round(v, 4) for v in jb_origin)))
    tabs = [("gh", gh_tab, gh_origin), ("jb", jb_tab, jb_origin)]
    results = {}
    for tag in TAGS:
        for name in ("us_grunt_joined_" + tag, "grunt_head_" + tag):
            o = D.objects.get(name)
            assert o is not None, "MISSING " + name
            results[name] = copy_onto(o, tabs, name)
    remove_sources(got)
    assert not [o for o in D.objects if o.name.startswith("_SRC_")]
    return results


if __name__ == "__main__":
    assert TAGS, "--tags a,b,c required"
    run()
    if SAVE:
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_mainfile(filepath=D.filepath)
        print("SAVED", D.filepath)
    else:
        print("DRY RUN (no --save)")
