"""gen_duckboard_plan.py - the ambient floorboard paths of the firebase, as a site plan.

Reads the compound's baked GLB, finds every structure door (`door_main*` markers - children of
the bunkers and the TOC, or baked at the root beside the hooches and the mess), and lays a run of
duckboard sections out from each door along the door's outward direction, plus one approach line
from each hooch row to the chow hall's queue. Writes `data/site_plans/fsb_main_duckboards.json`
in the parapet plan's shape, so `SitePlanner` stamps it with the same `stamp_site_plan` the wire
uses. Plan coordinates ARE GLB coordinates.

    python tools/gen_duckboard_plan.py            # write the plan
    python tools/gen_duckboard_plan.py --dry      # print a summary

Caleb, 2026-09-14: "add more ambient floorboard paths around the firebase".
"""
import json
import math
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GLB = ROOT / "assets/world/building models/structures/firebase/fsb_main_v3.glb"
OUT = ROOT / "data/site_plans/fsb_main_duckboards.json"

PART_ID = "fb_duckboard"
SECTION_M = 2.40           # the part's long axis (+X forward at yaw 0)
DOOR_GAP_M = 0.45          # first board starts this far outside the threshold
APRON_SECTIONS = 3         # boards out from every door
CHOW_QUEUE = (-21.0, -39.9)  # work_chow_* cluster, plan XZ
CHOW_APPROACH_FROM = [(-3.0, 27.0), (-33.0, 25.0)]  # the two hooch rows' inner ends
SKIP_OWNER_PREFIXES = ("fb_latrine",)  # a board into a latrine door reads wrong
# A root door belongs to the nearest of these; outward is from that owner's centre.
OWNER_PREFIXES = ("fb_hootch", "fb_hwall", "fb_mess", "fb_gp_tent", "fb_toc", "fb_bunker",
                  "WB_bunker", "medical_complex", "fb_supply", "fb_latrine", "fb_sleeping")
OWNER_REACH_M = 9.0


def load_glb_json(path: Path) -> dict:
    b = path.read_bytes()
    ln = struct.unpack("<I", b[12:16])[0]
    return json.loads(b[20:20 + ln])


def quat_to_mat(q):
    x, y, z, w = q
    return [
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ]


def mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def mat_vec(m, v):
    return [sum(m[i][k] * v[k] for k in range(3)) for i in range(3)]


def world_transform(nodes, parent, i):
    """Rotation matrix and translation of node i in GLB world space (TRS)."""
    chain = []
    k = i
    while k is not None:
        chain.append(k)
        k = parent.get(k)
    rot = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
    pos = [0.0, 0.0, 0.0]
    for k in reversed(chain):
        n = nodes[k]
        t = n.get("translation", [0, 0, 0])
        r = quat_to_mat(n.get("rotation", [0, 0, 0, 1]))
        s = n.get("scale", [1, 1, 1])
        pos = [pos[a] + sum(rot[a][b] * t[b] for b in range(3)) for a in range(3)]
        rot = mat_mul(rot, r)
        if any(abs(v - 1.0) > 1e-6 for v in s):
            rot = [[rot[a][b] * s[b] for b in range(3)] for a in range(3)]
    return rot, pos


def main() -> int:
    dry = "--dry" in sys.argv
    j = load_glb_json(GLB)
    nodes = j["nodes"]
    parent = {}
    for i, n in enumerate(nodes):
        for c in n.get("children", []):
            parent[c] = i
    # Structure centres, for the root doors.
    owners = []
    for i, n in enumerate(nodes):
        name = n.get("name", "")
        if "mesh" in n and name.startswith(OWNER_PREFIXES) and "colonly" not in name:
            _, pos = world_transform(nodes, parent, i)
            owners.append((name, pos))
    parts = []
    doors = 0
    skipped = 0
    for i, n in enumerate(nodes):
        name = n.get("name", "")
        if not name.startswith("door_main") or "mesh" in n:
            continue
        rot, door = world_transform(nodes, parent, i)
        owner_name = ""
        owner_pos = None
        p = parent.get(i)
        if p is not None:
            owner_name = nodes[p].get("name", "")
            _, owner_pos = world_transform(nodes, parent, p)
        else:
            best = OWNER_REACH_M
            for oname, opos in owners:
                d = math.hypot(opos[0] - door[0], opos[2] - door[2])
                if d < best:
                    best = d
                    owner_name, owner_pos = oname, opos
        if owner_name.startswith(SKIP_OWNER_PREFIXES):
            skipped += 1
            continue
        out = [0.0, 0.0, 0.0]
        if owner_pos is not None:
            out = [door[0] - owner_pos[0], 0.0, door[2] - owner_pos[2]]
        length = math.hypot(out[0], out[2])
        if length < 0.3:
            fz = mat_vec(rot, [0.0, 0.0, 1.0])
            out = [fz[0], 0.0, fz[2]]
            length = math.hypot(out[0], out[2])
            if length < 1e-6:
                skipped += 1
                continue
        out = [out[0] / length, 0.0, out[2] / length]
        yaw = math.degrees(math.atan2(-out[2], out[0]))  # +X forward, Godot yaw about +Y
        doors += 1
        for s in range(APRON_SECTIONS):
            d = DOOR_GAP_M + SECTION_M * (s + 0.5)
            parts.append({
                "id": PART_ID,
                "pos": [round(door[0] + out[0] * d, 4), round(door[1], 4), round(door[2] + out[2] * d, 4)],
                "yaw_deg": round(yaw, 3),
            })
    for start in CHOW_APPROACH_FROM:
        dx = CHOW_QUEUE[0] - start[0]
        dz = CHOW_QUEUE[1] - start[1]
        run = math.hypot(dx, dz)
        ux, uz = dx / run, dz / run
        yaw = math.degrees(math.atan2(-uz, ux))
        n_sections = int((run - 3.0) // SECTION_M)
        for s in range(n_sections):
            d = SECTION_M * (s + 0.5)
            parts.append({
                "id": PART_ID,
                "pos": [round(start[0] + ux * d, 4), 3.0, round(start[1] + uz * d, 4)],
                "yaw_deg": round(yaw, 3),
            })
    plan = {
        "version": 1,
        "name": "fsb_main_duckboards",
        "flatten": {"radius": 0.0, "strength": 0.0, "shoulder": 0.0},
        "note": "Generated by tools/gen_duckboard_plan.py from fsb_main_v3.glb's door_main markers: "
                "%d doors x %d sections (%d doors skipped) + the chow-hall approach. "
                "Plan coordinates are GLB coordinates." % (doors, APRON_SECTIONS, skipped),
        "parts": parts,
    }
    text = json.dumps(plan, indent=1)
    if dry:
        print("%d parts from %d doors (%d skipped), %d owners known" % (len(parts), doors, skipped, len(owners)))
        return 0
    OUT.write_text(text, encoding="utf-8")
    print("wrote %s: %d parts from %d doors (%d skipped)" % (OUT.relative_to(ROOT), len(parts), doors, skipped))
    return 0


if __name__ == "__main__":
    sys.exit(main())
