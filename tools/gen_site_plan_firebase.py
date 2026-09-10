"""gen_site_plan_firebase.py - author the FSB KIT ALPHA site plan (ADR-043).

A site plan is AUTHORED DATA (scripts/world/site_plan.gd). This script is the authoring
aid, not a runtime path: it writes data/site_plans/fsb_kit_alpha.json once, and the file it
writes is the artefact. Run it again only to re-derive the layout after changing a number
here; hand edits made in tools/kit_editor.tscn (CTRL+S) overwrite it and that is correct.

  python tools/gen_site_plan_firebase.py            # write the plan
  python tools/gen_site_plan_firebase.py --dry-run  # print the census, write nothing

WHY THE PART Y OFFSETS ARE NOT ZERO, and it is a MEASURED art gap, not a preference.
KIT_PART_CONTRACT section 2.1 requires the origin at the ground contact point. Measured off
the GLBs 2026-09-09 (tools/measure_kit_glb.py):

    fb_bunker_fighting  minY -0.97, 205 verts at y=0.0   -> ground plane IS y=0.  offset 0.00
    fb_bunker_mg        minY -1.02, 229 verts at y=0.0   -> ground plane IS y=0.  offset 0.00
    fb_gate_assembly    minY  0.00                       -> contract met.         offset 0.00
    fb_emplacement_m101 minY -1.97 (a buried crew rig)   -> pit floor at -0.39.   offset 0.00
    fb_sandbag_heavy    Y -0.54..+0.54  SYMMETRIC        -> centre origin.        offset 0.54
    fb_sandbag_light    Y -0.44..+0.44  SYMMETRIC        -> centre origin.        offset 0.44
    fb_FoxholeSandbags  Y -0.18..+0.18  SYMMETRIC        -> centre origin.        offset 0.18

The three symmetric parts were exported with the Blender object origin at the geometry
centre, so at y=0 half the sandbag wall is underground. The plan compensates. When those
three masters are re-exported to the contract, set OFFSET_Y for them to 0.0 here and the
walls will not move.

YAW, from site_planner.stamp_site_plan()'s part.rotation.y = deg_to_rad(yaw_deg):
    local +X -> world ( cos a, -sin a)      so a wall's length lies along an edge at
                                            a = atan2(-u.z, u.x)
    local +Z -> world ( sin a,  cos a)      so a bunker embrasure (measured at +Z: the mg
                                            bunker's m60_pintle sits at z=+1.55) faces an
                                            outward normal n at a = atan2(n.x, n.z)
"""
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "site_plans", "fsb_kit_alpha.json")

PLAN_NAME = "fsb_kit_alpha"
FLATTEN_RADIUS = 36.0
FLATTEN_STRENGTH = 1.0
FLATTEN_SHOULDER = 12.0

OFFSET_Y = {
    "fb_sandbag_heavy": 0.54,
    "fb_sandbag_light": 0.44,
    "fb_FoxholeSandbags": 0.18,
}

# Footprint half-lengths along the part's own +X, used for wall spacing and for the gaps a
# strongpoint cuts in the parapet. Measured, not guessed.
HALF_X = {
    "fb_sandbag_heavy": 1.14,
    "fb_sandbag_light": 1.07,
    "fb_FoxholeSandbags": 1.16,
    "fb_bunker_fighting": 2.05,
    "fb_bunker_mg": 2.65,
}
# Oriented half-extents (along the part's own local +X and +Z) used by the seal pass.
HALF_XZ = {
    "fb_sandbag_heavy": (1.14, 0.585),
    "fb_sandbag_light": (1.07, 0.24),
    "fb_FoxholeSandbags": (1.16, 0.72),
    "fb_bunker_fighting": (2.05, 1.80),
    "fb_bunker_mg": (2.65, 2.25),
}
WALL_STEP = 2.24          # 2.28 m bag wall, 4 cm of overlap so no seam shows
# A hole in the parapet narrower than this is not a way in: NavBaker bakes at
# AGENT_RADIUS 0.40, so a man needs 0.80 m of clear width. Anything wider than
# SEAL_TOL gets a bag wall dropped into it by the seal pass, because a perimeter with
# twelve one-metre gaps beside its own bunkers is not a perimeter and the gate that
# stands in it means nothing.
SEAL_TOL = 0.55
GATE_TOWER_X = -6.66      # fb_gate_tower's centre in the gate assembly's own local X
M101_PIT_OFFSET = 3.75    # the pit's centre lies this far along the gun's line of fire

# THE PERIMETER. Six sides, deliberately irregular - his ask was "less a circle". Long open
# south face for the road and the gate, tight north face where the ground falls away.
# Local metres from the site centre, X east / Z south (Godot).
PERIMETER = [
    (-25.0, 10.0),    # 0  W
    (-14.0, 24.0),    # 1  SW
    (10.0, 25.0),     # 2  S
    (26.0, 10.0),     # 3  SE
    (18.0, -18.0),    # 4  NE
    (-12.0, -22.0),   # 5  NW
]


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1])


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def scale(a, s):
    return (a[0] * s, a[1] * s)


def norm(a):
    m = math.hypot(a[0], a[1])
    return (a[0] / m, a[1] / m) if m > 0 else (0.0, 0.0)


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1]


def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def yaw_along(u):
    """Part's local +X lies along direction u."""
    return math.degrees(math.atan2(-u[1], u[0])) % 360.0


def yaw_facing(n):
    """Part's local +Z faces direction n."""
    return math.degrees(math.atan2(n[0], n[1])) % 360.0


CENTROID = (sum(p[0] for p in PERIMETER) / len(PERIMETER),
            sum(p[1] for p in PERIMETER) / len(PERIMETER))


def outward(at, u):
    """The edge normal that points away from the compound centre."""
    n = (-u[1], u[0])
    return n if dot(n, sub(at, CENTROID)) > 0.0 else (u[1], -u[0])


class Plan:
    def __init__(self):
        self.parts = []
        self.blocks = []   # (pos, radius) - ground the parapet must leave alone
        self.solids = []   # (pos, yaw_deg, half_x, half_z) - what actually stops a man

    def add(self, pid, xz, yaw_deg=0.0, block=0.0, solid=True):
        self.parts.append({"id": pid,
                           "pos": [round(xz[0], 3), round(OFFSET_Y.get(pid, 0.0), 3),
                                   round(xz[1], 3)],
                           "yaw_deg": round(yaw_deg % 360.0, 2)})
        if block > 0.0:
            self.blocks.append((xz, block))
        # A fighting bay is 0.35 m tall - a man steps over it, so it seals nothing and is
        # not counted here whatever its footprint says.
        if solid and pid in HALF_XZ and pid != "fb_FoxholeSandbags":
            hx, hz = HALF_XZ[pid]
            self.solids.append((xz, yaw_deg, hx, hz))

    def free(self, xz):
        return all(dist(xz, b[0]) > b[1] for b in self.blocks)

    def census(self):
        out = {}
        for p in self.parts:
            out[p["id"]] = out.get(p["id"], 0) + 1
        return out


def build():
    p = Plan()

    # ---- 1. THE GUN. It is why the firebase exists, so it is placed first and everything
    # else is laid out around its pit. Laid north-east, off the gate's axis so the crew are
    # not firing over the road.
    gun_face = norm((0.55, -0.84))
    pit_centre = (2.0, -4.0)
    gun_origin = sub(pit_centre, scale(gun_face, M101_PIT_OFFSET))
    p.add("fb_emplacement_m101", gun_origin, yaw_facing(scale(gun_face, -1.0)))

    # ---- 2. THE GATE, on the long south face, two thirds of the way east so the approach
    # road runs up past the west wall under the guns rather than straight at the gun pit.
    e_start, e_end = PERIMETER[1], PERIMETER[2]
    u = norm(sub(e_end, e_start))
    gate_at = add(e_start, scale(u, dist(e_start, e_end) * 0.58))
    n_out = outward(gate_at, u)
    # Two yaws lay the gate along the wall; take the one that puts the tower's local +Z
    # INSIDE the wire. A watchtower stands behind its own gate, not in front of it.
    yaw_a = yaw_along(u)
    a = math.radians(yaw_a)
    local_z = (math.sin(a), math.cos(a))
    if dot(local_z, n_out) > 0.0:
        yaw_a = (yaw_a + 180.0) % 360.0
        a = math.radians(yaw_a)
    # The tower rides at local X = -6.66; local +X maps to (cos a, -sin a).
    tower_at = add(gate_at, scale((math.cos(a), -math.sin(a)), GATE_TOWER_X))
    p.add("fb_gate_assembly", gate_at, yaw_a, block=4.6)
    p.blocks.append((tower_at, 2.6))
    # The gate part is two solids, not one box: the shut leaves and posts across the road
    # (local X -2.8..+2.8) and the tower off on its own at local X -6.66. Registered by hand
    # so the seal pass does not try to wall up the roadway or leave the tower's flanks open.
    p.solids.append((gate_at, yaw_a, 2.8, 0.30))
    p.solids.append((tower_at, yaw_a, 1.41, 1.64))

    # ---- 3. STRONGPOINTS. A bunker or a fighting bay on every corner, plus two machine
    # guns sited to graze rather than to stare: one enfilades the gate approach from up the
    # south wall, one covers the open north-west ground.
    corners = {
        0: "fb_bunker_fighting",
        1: "fb_FoxholeSandbags",
        2: "fb_bunker_fighting",
        3: "fb_FoxholeSandbags",
        4: "fb_bunker_fighting",
        5: "fb_bunker_fighting",
    }
    n = len(PERIMETER)
    for i in sorted(corners.keys()):
        pid = corners[i]
        prev_u = norm(sub(PERIMETER[i], PERIMETER[(i - 1) % n]))
        next_u = norm(sub(PERIMETER[(i + 1) % n], PERIMETER[i]))
        bisect = norm(add(outward(PERIMETER[i], prev_u), outward(PERIMETER[i], next_u)))
        if pid == "fb_FoxholeSandbags":
            # A FIGHTING BAY STANDS BEHIND THE PARAPET, NOT IN IT. The bay is 0.35 m tall
            # and NavBaker's agent_max_climb is 0.40 - a bay left in the wall line is a
            # step-over, and five of them would make the gate meaningless. Set it back
            # 2.2 m, leave the bag wall unbroken in front of it (block 0), and the man in
            # it shoots over a chest-high parapet the way he should.
            at = add(PERIMETER[i], scale(bisect, -2.2))
            p.add(pid, at, yaw_along((-bisect[1], bisect[0])))
        else:
            # A bunker IS the perimeter where it stands: on the wall line, embrasure out,
            # bag wall butted into both flanks. Set back, its own parapet would blind it.
            p.add(pid, PERIMETER[i], yaw_facing(bisect), block=HALF_X[pid] + 1.24)

    def on_edge(i, t, inset):
        s, e = PERIMETER[i], PERIMETER[(i + 1) % n]
        eu = norm(sub(e, s))
        at = add(s, scale(eu, dist(s, e) * t))
        no = outward(at, eu)
        return add(at, scale(no, -inset)), no, eu

    # MG covering the gate: 11 m west of it on the same face, embrasure out.
    mg1_at, mg1_n, _mg1_u = on_edge(1, 0.28, 0.0)
    p.add("fb_bunker_mg", mg1_at, yaw_facing(mg1_n), block=HALF_X["fb_bunker_mg"] + 1.24)
    # MG on the north-west face, the open approach.
    mg2_at, mg2_n, _mg2_u = on_edge(5, 0.5, 0.0)
    p.add("fb_bunker_mg", mg2_at, yaw_facing(mg2_n), block=HALF_X["fb_bunker_mg"] + 1.24)

    # Fighting bays behind the parapet on the three long unwatched runs.
    for edge, t in ((3, 0.5), (4, 0.45), (0, 0.5)):
        at, _no, eu = on_edge(edge, t, 2.2)
        p.add("fb_FoxholeSandbags", at, yaw_along(eu))

    # ---- 4. THE PARAPET. Bag wall run along every side, broken by whatever is already
    # standing on that ground. The breaks ARE the fire positions.
    for i in range(n):
        s, e = PERIMETER[i], PERIMETER[(i + 1) % n]
        eu = norm(sub(e, s))
        length = dist(s, e)
        count = max(1, int(math.ceil(length / WALL_STEP)))
        step = length / count
        for k in range(count):
            at = add(s, scale(eu, (k + 0.5) * step))
            if not p.free(at):
                continue
            p.add("fb_sandbag_heavy", at, yaw_along(eu))

    # ---- 5. INSIDE THE WIRE. The gate has to mean something, so the road through it is a
    # chicane: two light revetments staggered across the entry, a truck's width apart. A
    # vehicle must slow to a walk and everything on the south wall is looking at it.
    gate_in = norm(scale(n_out, -1.0))
    across = (-gate_in[1], gate_in[0])
    for step_m, side in ((5.0, 1.0), (10.5, -1.0)):
        at = add(add(gate_at, scale(gate_in, step_m)), scale(across, 3.1 * side))
        p.add("fb_sandbag_light", at, yaw_along(across))

    # Ready-round revetment: a horseshoe of light bags behind the gun, between the pit and
    # the gate, so a round landing in the compound does not take the ammunition with it.
    for ang in range(-60, 61, 30):
        d = math.radians(ang)
        r = 8.6
        off = (math.sin(d), math.cos(d))
        at = add(pit_centre, scale(off, r))
        p.add("fb_sandbag_light", at, yaw_along((off[1], -off[0])))

    # Blast traverse across the open middle, between the gun and the gate: the one piece of
    # cover a man crossing the compound under mortars can get behind.
    for k in (-1, 0, 1):
        at = add((6.0, 11.0), scale((1.0, 0.16), k * 2.2))
        p.add("fb_sandbag_heavy", at, yaw_along(norm((1.0, 0.16))))

    sealed = seal(p)
    print("[PLAN] seal pass: %d shoulder revetment(s) closing gaps wider than %.2f m"
          % (sealed, SEAL_TOL))
    return p


def seal(p):
    """Close every walkable hole left in the parapet.

    MEASURED, not assumed: the first stamp of this plan baked a navmesh a man could walk
    straight through beside every corner bunker - the bunker is 4.1 m wide, the gap its
    footprint cut in the bag wall was 5.4 m, and the metre left on each flank is wider than
    NavBaker's 0.80 m agent. The probe found it by pathing from outside the wire to the gun
    pit with the gate SHUT and arriving anyway. A perimeter with twelve holes in it does not
    make its gate mean anything, so the shoulders get revetted.
    """
    n = len(PERIMETER)
    added = 0
    for i in range(n):
        s, e = PERIMETER[i], PERIMETER[(i + 1) % n]
        eu = norm(sub(e, s))
        length = dist(s, e)
        spans = []
        for (pos, yaw, hx, hz) in p.solids:
            ang = math.radians(yaw)
            px = (math.cos(ang), -math.sin(ang))
            pz = (math.sin(ang), math.cos(ang))
            rel = sub(pos, s)
            t = dot(rel, eu)
            perp = abs(rel[0] * eu[1] - rel[1] * eu[0])
            half_perp = (abs(hx * (px[0] * eu[1] - px[1] * eu[0]))
                         + abs(hz * (pz[0] * eu[1] - pz[1] * eu[0])))
            if perp > half_perp + 0.7:
                continue          # too far off this wall line to be part of it
            half_along = abs(hx * dot(px, eu)) + abs(hz * dot(pz, eu))
            spans.append((t - half_along, t + half_along))
        spans.sort()
        gaps = []
        cursor = 0.0
        for (a0, a1) in spans:
            if a0 > cursor + SEAL_TOL:
                gaps.append((cursor, min(a0, length)))
            cursor = max(cursor, a1)
            if cursor >= length:
                break
        if cursor < length - SEAL_TOL:
            gaps.append((cursor, length))
        for (g0, g1) in gaps:
            width = g1 - g0
            if width <= SEAL_TOL:
                continue
            count = max(1, int(math.ceil(width / 2.0)))
            for k in range(count):
                at = add(s, scale(eu, g0 + (k + 0.5) * width / count))
                p.add("fb_sandbag_light", at, yaw_along(eu))
                added += 1
    return added


def main():
    p = build()
    doc = {
        "version": 1,
        "name": PLAN_NAME,
        "flatten": {"radius": FLATTEN_RADIUS, "strength": FLATTEN_STRENGTH,
                    "shoulder": FLATTEN_SHOULDER},
        "parts": p.parts,
    }
    census = p.census()
    worst = max(math.hypot(q["pos"][0], q["pos"][2]) for q in p.parts)
    print("[PLAN] %s: %d parts, furthest %.1f m from centre, pad radius %.0f m (core %.0f m)"
          % (PLAN_NAME, len(p.parts), worst, FLATTEN_RADIUS, FLATTEN_RADIUS * 0.9))
    for k in sorted(census):
        print("   %-22s %d" % (k, census[k]))
    if worst > FLATTEN_RADIUS * 0.9:
        print("   WARNING: a part stands outside the flat core - it will sit on the shoulder")
    if "--dry-run" in sys.argv:
        return
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        json.dump(doc, f, indent="\t")
        f.write("\n")
    print("[PLAN] wrote %s" % OUT)


if __name__ == "__main__":
    main()
