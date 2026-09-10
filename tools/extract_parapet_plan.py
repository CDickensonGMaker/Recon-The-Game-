"""extract_parapet_plan.py - lift the firebase parapet out of the monolith as a SITE PLAN.

    python tools/extract_parapet_plan.py [--dry-run]

ADR-043 section 2 migrates the firebase one FAMILY at a time: re-export the monolith minus
family F, stamp F from the kit. This is the read half for F = the parapet, and it is run ONCE
- the JSON it writes is authored data from then on, editable in tools/kit_editor.tscn.

WHY IT READS THE GLB AND NOT THE MANIFEST. `firebase_v3_destructibles.json` already carries
all 80 wall positions and the game already reads it - but it carries NO YAW. Every one of its
80 `box` entries is the same [6.6, 0.37, 1.17], which is the segment's LOCAL extent, so the
manifest cannot tell a wall running north from one running east. A plan built off it would
stand the whole perimeter axis-aligned. The orientation only exists in the vertices.

WHY YAW COMES FROM THE VERTICES AND NOT THE NODE. 80 of the 81 parapet nodes carry NO node
transform at all - the geometry is baked into the vertex data, which is what
site_planner.gd:2525 already says. The one exception (fb_sbg_seg_046.001) does carry a TRS, so
both paths are handled: the node TRS is applied first, then the cloud is measured.

WHY THE TILING IS PER-SEGMENT AND ADAPTIVE. The kit's fb_sandbag_heavy is 2.283 m long; the
bake's segments are NOT uniform - measured 2.36 to 6.04 m, because a real perimeter has short
filler pieces at its corners. (The manifest's identical [6.6, 0.37, 1.17] box on all 80 entries
is the generator's NOMINAL master size, not a per-segment measurement; do not read it as one.)
So each segment is tiled with round(its own length / 2.283) walls, at least one, spread along
its own measured axis. Every wall inherits that segment's yaw and its own ground height, so the
perimeter keeps its curve and its slope instead of being re-derived from a polyline nobody
authored. One part per segment would leave a 3.7 m hole in the wire every 6 m.

THE COORDINATE SPACE IS THE COMPOUND'S, AND THAT IS WHY THIS WORKS AT ALL. ADR-043 P1 already
put a seated `FirebaseCompound` wrapper around the bake with the GLB root added at IDENTITY
(site_planner.gd, place_firebase_main). So a GLB vertex coordinate IS a compound-local
coordinate, and the plan needs no re-basing.

THE ORIGIN CONVENTION IS THE KIT'S, NOT THE BAKE'S. KIT_PART_CONTRACT 2.1 puts a part's origin
at its ground contact point, and `fb_sandbag_heavy` is exported with the origin at the geometry
CENTRE instead (Y -0.54..+0.54, symmetric). tools/gen_site_plan_firebase.py compensates with
the same OFFSET_Y and says so; this script takes the same number from the same place, so when
that master is re-exported to the contract BOTH plans fix in one edit.
"""
import json
import math
import os
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GLB = os.path.join(ROOT, "assets", "world", "building models", "structures",
                   "firebase", "fsb_main_v3.glb")
MANIFEST = os.path.join(ROOT, "assets", "world", "building models", "structures",
                        "firebase", "kit", "firebase_v3_destructibles.json")
OUT = os.path.join(ROOT, "data", "site_plans", "fsb_main_parapet.json")

PLAN_NAME = "fsb_main_parapet"
PREFIX = "fb_sbg_seg_"
PART_ID = "fb_sandbag_heavy"
## The kit wall's own length, measured off fb_sandbag_heavy.glb (node scale 0.01 and a -90 deg
## X rotation, so this is world metres): 2.283 long x 1.081 tall x 1.174 thick.
KIT_WALL_M = 2.283
# See the docstring: the master's origin is at the geometry centre, not the ground.
OFFSET_Y = 0.54
# THE PLAN DOES NOT SEAT ITS OWN GROUND. place_firebase_main() has already levelled the pad and
# seated the compound; a second flatten from the parapet would cut a disc through a base that
# is already standing on one. ADR-041 section 6 makes declaring this BINDING, so it is declared.
FLATTEN_RADIUS = 0.0


def read_glb(path):
    d = open(path, "rb").read()
    assert d[:4] == b"glTF", "not a glb: %s" % path
    off, js, binc = 12, None, None
    while off < len(d):
        clen, ctype = struct.unpack("<II", d[off:off + 8])
        off += 8
        chunk = d[off:off + clen]
        off += clen
        if ctype == 0x4E4F534A:
            js = json.loads(chunk.decode("utf-8"))
        elif ctype == 0x004E4942:
            binc = chunk
    return js, binc


def accessor_vec3(js, binc, idx):
    acc = js["accessors"][idx]
    assert acc["type"] == "VEC3" and acc["componentType"] == 5126, acc
    bv = js["bufferViews"][acc["bufferView"]]
    base = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = bv.get("byteStride", 12)
    return [struct.unpack_from("<fff", binc, base + i * stride)
            for i in range(acc["count"])]


def node_yaw_translation(n):
    """A parapet segment may only be rotated about Y. SitePlan carries yaw_deg and nothing
    else, on purpose - a tilted part no longer meets the ground it is seated on - so pitch or
    roll on a source node is REPORTED rather than silently dropped."""
    t = n.get("translation", [0.0, 0.0, 0.0])
    x, y, z, w = n.get("rotation", [0.0, 0.0, 0.0, 1.0])
    if abs(x) > 1e-4 or abs(z) > 1e-4:
        print("  WARN %s carries pitch/roll (%.4f, %.4f) - only yaw is kept"
              % (n.get("name"), x, z))
    return 2.0 * math.atan2(y, w), t


def measure(js, binc, n):
    """Centroid, ground contact, long axis and length of one segment, in compound-local space."""
    pts = []
    for prim in js["meshes"][n["mesh"]]["primitives"]:
        pts.extend(accessor_vec3(js, binc, prim["attributes"]["POSITION"]))
    nyaw, nt = node_yaw_translation(n)
    ca, sa = math.cos(nyaw), math.sin(nyaw)
    w = [(px * ca + pz * sa + nt[0], py + nt[1], -px * sa + pz * ca + nt[2])
         for (px, py, pz) in pts]

    cx = sum(p[0] for p in w) / len(w)
    cz = sum(p[2] for p in w) / len(w)
    miny = min(p[1] for p in w)
    # PRINCIPAL AXIS of the XZ cloud. Exact for a box, and a wall IS a box: the dominant
    # eigenvector of the 2x2 covariance is the wall's length direction.
    sxx = syy = sxy = 0.0
    for p in w:
        dx, dz = p[0] - cx, p[2] - cz
        sxx += dx * dx
        syy += dz * dz
        sxy += dx * dz
    theta = 0.5 * math.atan2(2.0 * sxy, sxx - syy)
    ux, uz = math.cos(theta), math.sin(theta)
    along = [p[0] * ux + p[2] * uz for p in w]
    across = [-p[0] * uz + p[2] * ux for p in w]
    length = max(along) - min(along)
    thick = max(across) - min(across)
    # The covariance names an AXIS, not a direction, so it can return the short one when a
    # segment is nearly square in plan. Swap rather than trust it.
    if length < thick:
        ux, uz, length, thick = -uz, ux, thick, length
        along = [p[0] * ux + p[2] * uz for p in w]

    # THE MIDPOINT IS NOT THE CENTROID, and tiling about the centroid is how the first version
    # of this script widened the gateway by 4.3 m. A sandbag wall's vertices are not evenly
    # distributed along it - the sculpted bags bunch - so the mean sits off the middle of the
    # extent, and walls laid out symmetrically about the mean under-reach one end. Measured
    # against the bake's own ring the largest hole went 11.5 deg -> 14.8 deg, which the
    # per-segment coverage gate could not see because every segment was covered ABOUT THE
    # WRONG POINT. Return the offset from the centroid to the true axis midpoint.
    mid_off = (max(along) + min(along)) * 0.5 - (cx * ux + cz * uz)
    return cx, cz, miny, ux, uz, length, thick, mid_off


def main():
    dry = "--dry-run" in sys.argv
    js, binc = read_glb(GLB)
    segs = [n for n in js["nodes"]
            if n.get("name", "").startswith(PREFIX) and "colonly" not in n.get("name", "")]
    print("%d visual %s node(s) in the bake" % (len(segs), PREFIX))
    if not segs:
        # This script reads the PRE-migration export, so running it on a bake that has already
        # been through the drop finds nothing and would happily write an EMPTY plan - which is
        # a firebase with no wire and no error. Refuse, and say how to get back.
        raise SystemExit("\n".join([
            "the bake carries no parapet - it has already been migrated.",
            "This script reads the PRE-migration export. To re-derive the plan:",
            "    git checkout -- 'assets/world/building models/structures/firebase/"
            "fsb_main_v3.glb'",
            "    python tools/extract_parapet_plan.py",
            "    blender --background --python tools/reexport_firebase_v3.py -- "
            "--drop-prefix fb_sbg_seg_",
        ]))

    rows, dropped = [], []
    for n in segs:
        name = n["name"]
        # The Blender .001 duplicate ADR-043 named. It has no manifest entry, so
        # _wire_parapet_destructibles never wired it and it ships INVULNERABLE on top of a
        # real twin. Dropping it here is the migration fixing it for free.
        if "." in name:
            dropped.append(name)
            continue
        cx, cz, miny, ux, uz, length, thick, mid_off = measure(js, binc, n)
        rows.append({"name": name, "x": cx + ux * mid_off, "z": cz + uz * mid_off,
                     "miny": miny, "ux": ux, "uz": uz, "len": length, "thick": thick,
                     "mid_off": mid_off})

    if dropped:
        print("dropped %d Blender duplicate(s), invulnerable in the bake: %s"
              % (len(dropped), ", ".join(dropped)))
    print("%d segment(s): length %.2f..%.2f m, thickness %.2f..%.2f m, ground %.2f..%.2f m"
          % (len(rows), min(r["len"] for r in rows), max(r["len"] for r in rows),
             min(r["thick"] for r in rows), max(r["thick"] for r in rows),
             min(r["miny"] for r in rows), max(r["miny"] for r in rows)))

    # WHAT THE MANIFEST IS AND IS NOT GOOD FOR, measured rather than assumed.
    #
    # The first version of this script GATED on the manifest's positions agreeing with the
    # art, and refused to write. It was checking something the game does not rely on: the
    # manifest supplies only NAME -> kind/hp, and _wire_parapet_segment ADOPTS the mesh the
    # GLB already ships and seats the Destructible at that mesh's own AABB centre. The
    # manifest's `pos` is never used to place anything.
    #
    # Which is just as well, because it has DRIFTED: worst 1.84 m against the art, measured
    # both ways (vertex centroid and world AABB centre) on 2026-09-10. Recorded as a finding,
    # not enforced - the ART is the ring, and the ring is what gets reproduced here.
    man = {s["name"]: s for s in json.load(open(MANIFEST))["segments"]}
    worst, worst_name, missing = 0.0, "", []
    for r in rows:
        m = man.get(r["name"])
        if m is None:
            missing.append(r["name"])
            continue
        # BLENDER IS Z-UP AND THE GLB IS Y-UP: blender (x, y, z) -> gltf (x, z, -y). Comparing
        # gltf z against blender y directly reports 133 m of disagreement on a ring that has
        # not moved at all, which is what the first run of this script did.
        d = math.hypot(r["x"] - m["pos"][0], r["z"] + m["pos"][1])
        if d > worst:
            worst, worst_name = d, r["name"]
    print("manifest position drift vs the art: worst %.2f m (%s) - NOT enforced, the art is "
          "the ring" % (worst, worst_name))
    print("centroid-to-midpoint offset: worst %.2f m - tiling about the centroid would move "
          "the wire by this much" % max(abs(r["mid_off"]) for r in rows))
    if missing:
        # A segment with no manifest entry gets no kind and no hp, so it ships INVULNERABLE
        # and nothing raises an error. The migration gives every wall the kit's own kind, so
        # this list is a set of defects the migration closes.
        print("NOT IN THE MANIFEST (%d - these are INVULNERABLE in the bake today): %s"
              % (len(missing), ", ".join(missing)))

    # RE-TILE. yaw_deg follows stamp_site_plan's convention: it applies
    # part.rotation.y = deg_to_rad(yaw_deg), under which local +X maps to world
    # (cos a, -sin a) - so a wall running along u needs a = atan2(-u.z, u.x). Same convention
    # tools/gen_site_plan_firebase.py documents.
    parts = []
    counts = []
    for r in sorted(rows, key=lambda q: q["name"]):
        yaw_deg = math.degrees(math.atan2(-r["uz"], r["ux"]))
        # CEIL, NOT ROUND. Rounding down left a 1.12 m hole in a 3.40 m segment - the gate
        # below caught it. A wall too many overlaps; a wall too few is a gap in the wire.
        n_walls = max(1, int(math.ceil(r["len"] / KIT_WALL_M)))
        step = r["len"] / float(n_walls)
        counts.append(n_walls)
        for k in range(n_walls):
            t = (float(k) - (n_walls - 1) * 0.5) * step
            parts.append({
                "id": PART_ID,
                "pos": [round(r["x"] + r["ux"] * t, 4),
                        round(r["miny"] + OFFSET_Y, 4),
                        round(r["z"] + r["uz"] * t, 4)],
                "yaw_deg": round(yaw_deg, 3),
            })

    # THE GATE THAT MATTERS: no hole in the wire. Each segment's walls must span at least the
    # segment they replace, or the re-skin opens a gap an enemy walks through and nothing says
    # so. Checked per segment against its own measured length.
    worst_gap, gap_name = 0.0, ""
    for r, n_walls in zip(sorted(rows, key=lambda q: q["name"]), counts):
        covered = (n_walls - 1) * (r["len"] / float(n_walls)) + KIT_WALL_M
        if r["len"] - covered > worst_gap:
            worst_gap, gap_name = r["len"] - covered, r["name"]
    print("worst uncovered span on any segment: %.3f m (%s)" % (worst_gap, gap_name))
    if worst_gap > 0.05:
        raise SystemExit("the re-tile leaves a %.2f m hole in the wire at %s"
                         % (worst_gap, gap_name))

    plan = {"version": 1, "name": PLAN_NAME,
            "flatten": {"radius": FLATTEN_RADIUS, "strength": 0.0, "shoulder": 0.0},
            "parts": parts}
    print("%d segment(s) -> %d kit wall(s), %d..%d per segment, mean spacing %.2f m"
          % (len(rows), len(parts), min(counts), max(counts),
             sum(r["len"] for r in rows) / float(len(parts))))
    if dry:
        print("--dry-run: not writing %s" % OUT)
        return
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(plan, f, indent="\t")
    print("wrote %s" % OUT)


if __name__ == "__main__":
    main()
