"""fix_pilot_chest.py - the rust band across both pilots' chests.

    blender -b -P tools/fix_pilot_chest.py -- [--apply]

The pilots' torsos carry a handful of faces assigned to the SKIN atlas
(face_atlas_mat / face_atlas_black_mat) with their UVs collapsed onto a single texel.
Collapsing UVs onto one texel is a normal PSX flat-colour trick and the boots use it
correctly - but these chest faces are pointed at a BROWN texel meant for boots, so a
rust band reads across an olive flight suit.

The fix is only a retarget: same trick, right colour. We measure the dominant colour
of the flight suit from the faces that already wear it, find the flattest texel in the
suit sheet matching that colour, and repoint the offending faces at it. No re-UV, no
new geometry, no material invented, and the boots are left alone.
"""
import bpy, sys
from mathutils import Vector

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
APPLY = "--apply" in ARGV
SRC = r"C:\Users\caleb\RECONgame\assets\us\characters\us_base_v3.blend"
DST = SRC if APPLY else SRC.replace(".blend", "_PILOTFIX.blend")

BODIES = ("us_grunt_joined_pointman.001", "us_grunt_joined_pilot_black")
TORSO_Z = (1.20, 1.50)        # below the neck, above the belt - never the boots
FLAT = 0.02                   # a UV span this small is a flat-colour lookup

bpy.ops.wm.open_mainfile(filepath=SRC)

try:
    import numpy as np
except ImportError:
    np = None


def sheet_of(mat):
    if not mat or not mat.use_nodes:
        return None
    for n in mat.node_tree.nodes:
        if n.type == 'TEX_IMAGE' and n.image:
            return n.image
    return None


def sample(img, arr, u, v):
    w, h = img.size
    x = min(w - 1, max(0, int(u * w)))
    y = min(h - 1, max(0, int(v * h)))
    i = (y * w + x) * 4
    return Vector((arr[i], arr[i + 1], arr[i + 2]))


for bn in BODIES:
    o = bpy.data.objects.get(bn)
    if o is None:
        print("%s ABSENT" % bn)
        continue
    me = o.data
    uvl = me.uv_layers.active
    slots = [s.material.name if s.material else None for s in o.material_slots]
    skin = {i for i, s in enumerate(slots) if s and "face_atlas" in s}
    suit = next((i for i, s in enumerate(slots) if s == "us_pilot_mat"), None)
    print("\n===== %s  slots=%s =====" % (bn, slots))
    if suit is None or not skin:
        print("  no suit/skin split - skipped")
        continue

    img = sheet_of(o.material_slots[suit].material)
    if img is None or np is None:
        print("  cannot read the suit sheet (img=%s numpy=%s)" % (img, np is not None))
        continue
    arr = np.empty(len(img.pixels), dtype=np.float32)
    img.pixels.foreach_get(arr)
    print("  suit sheet: %s %dx%d" % (img.name, img.size[0], img.size[1]))

    # what colour IS the flight suit? average what the suit faces already sample
    cols = []
    for p in me.polygons:
        if p.material_index != suit:
            continue
        c = (o.matrix_world @ p.center)
        if not (TORSO_Z[0] <= c.z <= TORSO_Z[1]):
            continue
        uvs = [uvl.data[li].uv for li in p.loop_indices]
        mid = Vector((sum(u.x for u in uvs) / len(uvs), sum(u.y for u in uvs) / len(uvs)))
        cols.append(sample(img, arr, mid.x, mid.y))
    if not cols:
        print("  no suit faces on the torso to learn from - skipped")
        continue
    want = sum(cols, Vector()) / len(cols)
    print("  flight-suit colour measured over %d faces: (%.3f, %.3f, %.3f)"
          % (len(cols), want.x, want.y, want.z))

    # the flattest texel matching it: scan a coarse grid, score by colour match and
    # by how uniform its 5x5 neighbourhood is (so we never land on a seam)
    w, h = img.size
    best, best_score = None, 1e9
    step = 8
    for yy in range(2, h - 2, step):
        for xx in range(2, w - 2, step):
            i = (yy * w + xx) * 4
            if arr[i + 3] < 0.9:
                continue
            c = Vector((arr[i], arr[i + 1], arr[i + 2]))
            d = (c - want).length
            if d > 0.12:
                continue
            var = 0.0
            for dy in (-2, 0, 2):
                for dx in (-2, 0, 2):
                    j = ((yy + dy) * w + (xx + dx)) * 4
                    var += (Vector((arr[j], arr[j + 1], arr[j + 2])) - c).length
            score = d + var * 0.5
            if score < best_score:
                best_score, best = score, (xx, yy, c)
    if best is None:
        print("  no matching flat texel found - skipped")
        continue
    xx, yy, c = best
    U, V = (xx + 0.5) / w, (yy + 0.5) / h
    print("  chosen texel (%d, %d) -> uv (%.4f, %.4f) colour (%.3f, %.3f, %.3f) score %.4f"
          % (xx, yy, U, V, c.x, c.y, c.z, best_score))

    # repoint the offenders
    n = 0
    for p in me.polygons:
        if p.material_index not in skin:
            continue
        z = (o.matrix_world @ p.center).z
        if not (TORSO_Z[0] <= z <= TORSO_Z[1]):
            continue
        uvs = [uvl.data[li].uv for li in p.loop_indices]
        span = max(max(u.x for u in uvs) - min(u.x for u in uvs),
                   max(u.y for u in uvs) - min(u.y for u in uvs))
        if span > FLAT:
            continue
        old = uvs[0].copy()
        for li in p.loop_indices:
            uvl.data[li].uv = (U, V)
        p.material_index = suit
        print("    face %-4d z=%.3f  (%.4f, %.4f) -> (%.4f, %.4f)  [%s -> us_pilot_mat]"
              % (p.index, z, old.x, old.y, U, V, slots[p.material_index] if False else "skin"))
        n += 1
    print("  %d torso faces repointed; boots and head untouched" % n)

bpy.ops.wm.save_as_mainfile(filepath=DST)
print("\nwrote %s" % DST)
