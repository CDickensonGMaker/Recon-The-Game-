"""READ-ONLY: what is actually in the firebase's merged card vegetation?

    blender --background --python tools/inspect_firebase_veg.py

scatter_veg() fuses every instance of a species into ONE mesh, so the per-instance transforms
are gone from the file. Replacing the cards with the real models means recovering them, and
this measures whether that is possible: how many quads each merged group holds, how they
cluster into instances, and what each instance's footprint and yaw are.

Opens the canon blend, writes nothing, saves nothing.
"""
import math
import os
import sys
from collections import defaultdict

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_firebase as gf          # noqa: E402

CANON_BLEND = os.path.join(gf.KIT_DIR, "firebase_v3.2.blend")
## Two quads of one crossed card share a centre; two different plants do not. The scatter
## jitters position by +/-2.5m, so anything this close is one plant.
CLUSTER_EPS = 0.35


def clusters(ob):
    """Face centroids grouped into plants. Returns [(centre, faces, zmin, zmax)]."""
    me = ob.data
    pts = []
    for p in me.polygons:
        c = Vector((0.0, 0.0, 0.0))
        for vi in p.vertices:
            c += me.vertices[vi].co
        c /= len(p.vertices)
        pts.append((c, p))
    out = []
    for c, p in pts:
        hit = None
        for g in out:
            if (Vector((g["c"].x - c.x, g["c"].y - c.y, 0.0))).length < CLUSTER_EPS:
                hit = g
                break
        if hit is None:
            out.append({"c": c, "faces": [p], "n": 1})
        else:
            hit["faces"].append(p)
            hit["c"] = (hit["c"] * hit["n"] + c) / (hit["n"] + 1)
            hit["n"] += 1
    return out


def main():
    bpy.ops.wm.open_mainfile(filepath=CANON_BLEND)
    sc = bpy.context.scene
    veg = sorted([o for o in sc.objects if o.type == 'MESH' and o.name.startswith("fb_veg_")],
                 key=lambda o: o.name)
    print("\n%-26s %6s %6s %8s %8s %8s %s" % (
        "group", "tris", "quads", "plants", "z-span", "footpr", "verdict"))
    total_cards = 0
    for ob in veg:
        me = ob.data
        tris = sum(len(p.vertices) - 2 for p in me.polygons)
        quads = len(me.polygons)
        cl = clusters(ob)
        zs = [v.co.z for v in me.vertices]
        span = (max(zs) - min(zs)) if zs else 0.0
        # Widest cluster footprint, a proxy for plant size.
        widest = 0.0
        for g in cl:
            for p in g["faces"]:
                for vi in p.vertices:
                    d = (me.vertices[vi].co - g["c"]).length
                    widest = max(widest, d)
        card = tris < 500
        if card:
            total_cards += 1
        print("%-26s %6d %6d %8d %8.2f %8.2f %s" % (
            ob.name, tris, quads, len(cl), span, widest,
            "CARD - swap" if card else "real mesh"))
    print("\n%d card group(s) of %d fb_veg_ groups" % (total_cards, len(veg)))
    print("cluster epsilon %.2fm - a plant is one cluster, a crossed card is 2+ faces in it"
          % CLUSTER_EPS)
    print("READ-ONLY: nothing written, blend not saved")


if __name__ == "__main__":
    main()
