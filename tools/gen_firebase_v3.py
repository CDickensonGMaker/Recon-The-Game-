"""FSB v3 - a firebase that fits its ground, and whose revetment can be blown apart.

What the research changed against v2.1 (sources in production/firebase_research_1967_70.md):

  shape     "Firebases on flatter terrain were usually round, and those on ridges generally
            were rectangular due to terrain." v2.1 was a perfect circle. v3 sits on a ridge:
            the perimeter is an elongated, harmonically-perturbed closed curve, and the
            ground under it is a real mound so the berm stands proud of the terrain.
  battery   A six-gun 105 battery deployed in a STAR - base piece at the centre, the other
            five on the points. v2.1 had them on an even arc, which is not a firing layout.
  scale     FSB Kramer: ~250 m across, four-foot earth berm, wire ~20 m beyond it.

Destruction: the parapet is emitted as SEGMENTS, one object per ~6 m, each with a box and an
HP in firebase_v3_destructibles.json. Godot spawns one Destructible per row onto the
AgentRegistry.props blast bus (combat_manager.gd:178-185). v2.1's parapet was a single mesh
for the whole perimeter - one grenade would have levelled the entire base.
"""
import bpy, bmesh, math, os, sys, json, random
from mathutils import Vector, Matrix, Euler

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fb_kit
import gen_firebase as gf

## Where the exported GLB lands. Used at :917 and :942 but never defined here - so this
## module raised NameError on IMPORT and could not be run at all, which is why the firebase
## had not been re-exported since 2026-07-26. fb_kit is the one authority for the path.
ROOT = fb_kit.ROOT

SEED = 90210
R0 = 66.0                 # mean perimeter radius; ~150 m across the short axis
RIDGE_STRETCH = 1.28      # long axis of the ridge
MOUND_H = 3.4             # how far the base platform stands above the surrounding ground
MOUND_FALL = 34.0         # metres of slope from the platform edge down to grade
BERM_W, BERM_H = 3.2, 1.22
SEG_LEN = 6.0             # one destructible parapet segment
SEG_HP = 140
GATE_BEARING = math.radians(206.0)
GATE_HALF = math.radians(7.5)


# ------------------------------------------------------------------ perimeter --

def perimeter(n=180, r0=R0):
    """Organic closed outline. Three harmonics plus a ridge stretch - never a circle."""
    pts = []
    for i in range(n):
        a = math.tau * i / n
        r = r0 * (1.0 + 0.155 * math.sin(2 * a + 0.7)
                       + 0.085 * math.sin(3 * a + 2.1)
                       + 0.045 * math.sin(5 * a + 4.3))
        pts.append((math.cos(a) * r * RIDGE_STRETCH, math.sin(a) * r))
    return pts


def offset_closed(path, d):
    """Miter-offset a closed polyline outward by d."""
    out = []
    n = len(path)
    for i in range(n):
        p = Vector(path[i])
        a = Vector(path[(i - 1) % n])
        b = Vector(path[(i + 1) % n])
        n0 = Vector(((p - a).y, -(p - a).x)).normalized()
        n1 = Vector(((b - p).y, -(b - p).x)).normalized()
        m = (n0 + n1)
        if m.length < 1e-6:
            m = n1
        m.normalize()
        k = 1.0 / max(math.sqrt(max((1.0 + n0.dot(n1)) / 2.0, 1e-6)), 0.4)
        out.append((p.x + m.x * d * k, p.y + m.y * d * k))
    return out


def bearing_of(p):
    return math.atan2(p[1], p[0])


def in_gate(a):
    return abs((a - GATE_BEARING + math.pi) % math.tau - math.pi) < GATE_HALF


def platform_z(x, y):
    """Height of the ground mound at (x,y).

    The top is NOT flat. A dead-level plateau put every parapet segment at exactly 4.62 m and
    the crest read as machined; real ground rolls, and the berm and the revetment follow it.
    """
    a = math.atan2(y, x)
    r = math.hypot(x / RIDGE_STRETCH, y)
    edge = R0 * (1.0 + 0.155 * math.sin(2 * a + 0.7)
                      + 0.085 * math.sin(3 * a + 2.1)
                      + 0.045 * math.sin(5 * a + 4.3)) + BERM_W
    top = (MOUND_H
           + 1.05 * math.sin(x * 0.042 + 0.6) * math.cos(y * 0.036 - 0.3)
           + 0.55 * math.sin(y * 0.021 - 0.9)
           + 0.30 * math.cos(x * 0.075 + y * 0.055 + 1.7))
    if r <= edge:
        return top
    t = min(1.0, (r - edge) / MOUND_FALL)
    return top * (1.0 - t) ** 2 * (1.0 - 0.35 * t)


# --------------------------------------------------------------------- pieces --

## The mound surface is authored HERE and consumed by Godot: site_planner sculpts the terrain
## to it so there is exactly ONE ground under the base. Godot must therefore know these
## numbers, and a hand-copied `MOUND_H = 3.4` in GDScript is a divergent-systems seed - the
## day this file changes, the terrain silently keeps the old shape and the 07-29 playtest bug
## (two floors, one of them invisible, the player standing on air) comes straight back.
##
## So the constants ship WITH the model, rewritten on every export. Same pattern as
## temple_set.json. site_planner.gd::fsb_mound_height() is the only reader.
MOUND_MANIFEST = "fsb_main_v3_mound.json"


def write_mound_manifest(path):
    doc = {
        "_source": "tools/gen_firebase_v3.py :: platform_z(). REWRITTEN ON EVERY EXPORT by "
                   "export_firebase(). Do not hand-edit - edit the generator.",
        "_axes": "Blender model space. Godot: x = local_x, y (blender) = -local_z, "
                 "height = result.",
        "r0": R0, "ridge_stretch": RIDGE_STRETCH, "mound_h": MOUND_H,
        "mound_fall": MOUND_FALL, "berm_w": BERM_W, "berm_h": BERM_H,
        "edge_harmonics": [[0.155, 2.0, 0.7], [0.085, 3.0, 2.1], [0.045, 5.0, 4.3]],
        "top_xy": [1.05, 0.042, 0.6, 0.036, -0.3],
        "top_y": [0.55, 0.021, -0.9],
        "top_xy2": [0.30, 0.075, 0.055, 1.7],
        # THE FIGHTING STEP. Raised in TERRAIN by site_planner, not modelled here - the mound
        # plate is COL_NONE and the terrain is the collider, so the banquette is ground rather
        # than geometry. Measured: the parapet lip is berm 1.22 + 9 courses x 0.13 = 2.39m over
        # the compound floor, against a ~1.6m eye. A 0.9m shelf puts him 0.11m over his own
        # wall standing and fully behind it crouched, and gives the VC a way over the berm once
        # the sandbags are blown.
        #
        # If you ever MODEL the step in Blender, zero step_h here or the two will stack.
        "step_h": 0.9,
        "step_gap_m": 3.0,
        "step_width_m": 11.0,
    }
    with open(path, "w") as f:
        json.dump(doc, f, indent=2)
    return doc


def new_obj(name, bm, extra_mats=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in gf.ensure_materials():
        me.materials.append(m)
    gf.box_project_uvs(me)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob


def edge_at(a):
    """Perimeter radius at bearing a, in the same unstretched space perimeter() uses."""
    return R0 * (1.0 + 0.155 * math.sin(2 * a + 0.7)
                     + 0.085 * math.sin(3 * a + 2.1)
                     + 0.045 * math.sin(5 * a + 4.3))


def fall_at(a):
    """How far the skirt runs out at this bearing. Varying it is what stops the mound
    reading as a giant circle bolted onto an organic base."""
    return MOUND_FALL * (0.62 + 0.30 * math.sin(3 * a + 1.1)
                              + 0.18 * math.sin(5 * a + 3.4)
                              + 0.10 * math.sin(2 * a - 0.5))


## Shell craters worked into the outer skirt: (x, y, radius, depth).
CRATERS = []


def crater_field(rng, n=22):
    CRATERS.clear()
    for i in range(n):
        a = math.tau * i / n + rng.uniform(-0.09, 0.09)
        e, fa = edge_at(a), fall_at(a)
        r_local = e + fa * rng.uniform(-0.10, 0.85)
        x = math.cos(a) * r_local * RIDGE_STRETCH
        y = math.sin(a) * r_local
        CRATERS.append((x, y, rng.uniform(4.5, 10.0), rng.uniform(0.7, 1.9)))
    return CRATERS


def crater_delta(x, y):
    d = 0.0
    for cx, cy, r, depth in CRATERS:
        dist = math.hypot(x - cx, y - cy)
        if dist < r:
            d -= depth * (1.0 - (dist / r) ** 2)          # bowl
        elif dist < r * 1.5:
            t = (dist - r) / (r * 0.5)
            d += depth * 0.22 * (1.0 - t) ** 2            # thrown-up lip
    return d


def base_z(x, y):
    """Plateau height with no craters - what the buildings and berm sit on."""
    return platform_z(x, y)


def ground_z(x, y):
    return platform_z(x, y) + crater_delta(x, y)


def terrain_mound(rng):
    """The ground the base sits on, cratered, with a skirt that follows the base outline.

    The first pass swept a circle of fixed radius and only varied the HEIGHT, so an organic
    perimeter sat inside a giant round pad. The outline now drives the skirt too.
    """
    bm = bmesh.new()
    rings, seg = 46, 152
    plateau_frac = 0.66
    grid = []
    for ri in range(rings + 1):
        row = []
        t = ri / rings
        for si in range(seg):
            a = math.tau * si / seg
            e, fa = edge_at(a), fall_at(a)
            if t <= plateau_frac:
                r_local = e * (t / plateau_frac)
            else:
                r_local = e + fa * (t - plateau_frac) / (1.0 - plateau_frac)
            x = math.cos(a) * r_local * RIDGE_STRETCH
            y = math.sin(a) * r_local
            z = ground_z(x, y) + (rng.uniform(-0.06, 0.06) if 0 < ri < rings else 0.0)
            if ri == rings:
                z = 0.0                       # the toe meets grade cleanly
            row.append(bm.verts.new((x, y, z)))
        grid.append(row)
    idx = gf.MAT_INDEX["fb_earth"]
    for ri in range(rings):
        for si in range(seg):
            s2 = (si + 1) % seg
            try:
                # Radial-then-tangential winding: r_hat x theta_hat = +Z. The reverse order
                # gives every face a DOWNWARD normal, and Godot's ConcavePolygonShape3D has
                # backface_collision off - a down-facing ground is walked through from above.
                f = bm.faces.new((grid[ri][si], grid[ri + 1][si], grid[ri + 1][s2], grid[ri][s2]))
                f.material_index = idx
            except ValueError:
                pass
    return new_obj("fb_terrain_mound", bm)


def berm(path, rng):
    """Continuous earth berm swept along the perimeter - the mound he wants standing proud."""
    inner = offset_closed(path, -BERM_W * 0.5)
    outer = offset_closed(path, BERM_W * 0.5)
    bm = bmesh.new()
    idx = gf.MAT_INDEX["fb_earth"]
    n = len(path)
    ci, co, cc = [], [], []
    for i in range(n):
        zi = platform_z(*inner[i])
        zo = platform_z(*outer[i])
        h = BERM_H + rng.uniform(-0.09, 0.09)
        ci.append(bm.verts.new((inner[i][0], inner[i][1], zi)))
        co.append(bm.verts.new((outer[i][0], outer[i][1], zo)))
        cc.append(bm.verts.new((path[i][0], path[i][1], max(zi, zo) + h)))
    for i in range(n):
        j = (i + 1) % n
        ## Wound so both flanks face UP and OUT. Reversed, all 360 faces point down and the
        ## berm becomes a trimesh you walk through - the same defect as terrain_mound.
        for quad in ((ci[i], cc[i], cc[j], ci[j]), (cc[i], co[i], co[j], cc[j])):
            try:
                bm.faces.new(quad).material_index = idx
            except ValueError:
                pass
    return new_obj("fb_berm_ring", bm)


def resample_closed(path, step):
    """Even stations by arc length around a closed path."""
    n = len(path)
    cum, total = [0.0], 0.0
    for i in range(n):
        total += (Vector(path[(i + 1) % n]) - Vector(path[i])).length
        cum.append(total)
    cnt = max(4, int(round(total / step)))
    out, j = [], 0
    for k in range(cnt):
        d = total * k / cnt
        while j < n and cum[j + 1] < d:
            j += 1
        seg = cum[j + 1] - cum[j]
        t = 0.0 if seg < 1e-9 else (d - cum[j]) / seg
        p = Vector(path[j]).lerp(Vector(path[(j + 1) % n]), t)
        out.append((p.x, p.y))
    return out


def parapet_segments(path, rng):
    """Sandbag revetment on the berm crest, cut into destructible segments.

    Stations are shared between neighbouring segments (the +1 slice). Cutting on strict
    ranges instead left a gap at every joint and the perimeter read as a dashed line.
    """
    per_seg = 6
    st = resample_closed(path, SEG_LEN / per_seg)
    m = len(st)
    nseg = m // per_seg

    objs, rows = [], []
    for s in range(nseg):
        sub = [st[(s * per_seg + k) % m] for k in range(per_seg + 1)]
        if in_gate(bearing_of(sub[len(sub) // 2])):
            continue
        z = max(platform_z(*p) for p in sub) + BERM_H
        bm = bmesh.new()
        fb_kit.build_sandbag_wall(path=sub, courses=9, base_z=z, side=1.0,
                                  seed=rng.randint(0, 1 << 20), into=bm)
        if not bm.faces:
            bm.free()
            continue
        name = f"fb_sbg_seg_{len(objs):03d}"
        ob = new_obj(name, bm)
        c = sum((Vector(p) for p in sub), Vector((0.0, 0.0))) / len(sub)
        objs.append(ob)
        rows.append({"name": name, "pos": [round(c.x, 3), round(c.y, 3), round(z, 3)],
                     "box": [round((Vector(sub[-1]) - Vector(sub[0])).length + 0.6, 2),
                             round(fb_kit.THICKNESS + 0.12, 2), round(9 * fb_kit.BAG_H, 2)],
                     "kind": "sandbag_wall", "hp": SEG_HP})
    return objs, rows


def wire(path, rng):
    before = set(bpy.data.objects.keys())
    bpy.ops.import_scene.gltf(filepath=gf.WIRE_GLB)
    new = [bpy.data.objects[k] for k in set(bpy.data.objects.keys()) - before]
    card = next((o for o in new if o.type == 'MESH' and o.name.startswith("bwire_card")
                 and "colonly" not in o.name), None)
    src = card.data.copy() if card else None
    mat = src.materials[0] if src is not None and src.materials else None
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
    if src is None:
        return None
    # The card ships as alpha BLEND, which sorts and costs overdraw on ~450 cards ringing the
    # base. The spec is alpha-test cutout; HASHED is that in 4.2+ (CLIP was removed).
    if mat is not None and getattr(mat, "blend_method", None) == 'BLEND':
        mat.blend_method = 'HASHED'
    bm = bmesh.new()
    cards = 0
    for off in (20.0, 17.0, 8.0):                     # Kramer: wire ~20 m beyond the berm
        ring = offset_closed(path, off)
        m = len(ring)
        acc = 0.0
        for i in range(m):
            p0, p1 = Vector(ring[i]), Vector(ring[(i + 1) % m])
            seg = (p1 - p0).length
            acc += seg
            if acc < 2.70:
                continue
            acc = 0.0
            a = math.atan2(p1.y - p0.y, p1.x - p0.x)
            if in_gate(bearing_of(p0)):
                continue
            mat4 = (Matrix.Translation((p0.x, p0.y, platform_z(p0.x, p0.y)))
                    @ Euler((rng.uniform(-.05, .05), rng.uniform(-.07, .07),
                             a)).to_matrix().to_4x4())
            tmp = src.copy()
            tmp.transform(mat4)
            bm.from_mesh(tmp)
            bpy.data.meshes.remove(tmp)
            cards += 1
    me = bpy.data.meshes.new("bwire_card_ring")
    bm.to_mesh(me)
    bm.free()
    if mat is not None:
        me.materials.append(mat)
    ob = bpy.data.objects.new("bwire_card_ring", me)
    bpy.context.collection.objects.link(ob)
    bpy.data.meshes.remove(src)
    print(f"   wire cards: {cards}")
    return ob


def ribbon(pts, width, mat, z_lift=0.03, name="fb_ribbon", closed=False, jitter=0.0,
           rng=None):
    """A flat strip laid on the mound - roads, tracks, duckboard runs, mud."""
    bm = bmesh.new()
    idx = gf.MAT_INDEX[mat]
    n = len(pts)
    L, R = [], []
    for i in range(n):
        p = Vector(pts[i])
        a = Vector(pts[(i - 1) % n]) if (closed or i > 0) else Vector(pts[i + 1])
        b = Vector(pts[(i + 1) % n]) if (closed or i < n - 1) else Vector(pts[i - 1])
        d = (b - a)
        if d.length < 1e-6:
            d = Vector((1.0, 0.0))
        d.normalize()
        nv = Vector((d.y, -d.x))
        w = width * 0.5 + (rng.uniform(-jitter, jitter) if rng and jitter else 0.0)
        for store, s in ((L, -1.0), (R, 1.0)):
            q = p + nv * (w * s)
            store.append(bm.verts.new((q.x, q.y, platform_z(q.x, q.y) + z_lift)))
    rng_n = n if closed else n - 1
    for i in range(rng_n):
        j = (i + 1) % n
        try:
            bm.faces.new((L[i], L[j], R[j], R[i])).material_index = idx
        except ValueError:
            pass
    return new_obj(name, bm)


def mud_blob(centre, width, rng, name="fb_mud_patch", style="splat", angle=None):
    """One churn of mud. Every patch gets its own harmonics, so no two are the same shape.

    The first pass used one jittered-radius routine for all of them and they read as four
    identical dark polygons.
    """
    bm = bmesh.new()
    idx = gf.MAT_INDEX["fb_mud"]
    seg = 30
    if angle is None:
        angle = rng.uniform(0.0, math.tau)
    stretch = {"splat": 1.0, "pool": rng.uniform(2.1, 3.4), "puddle": rng.uniform(1.0, 1.4)}[style]
    amps = {"splat": (0.26, 0.17, 0.10), "pool": (0.12, 0.09, 0.06),
            "puddle": (0.20, 0.12, 0.05)}[style]
    ph = [rng.uniform(0, math.tau) for _ in range(3)]
    ks = rng.sample([2, 3, 4, 5, 6, 7], 3)

    ca, sa = math.cos(angle), math.sin(angle)
    cz = platform_z(centre[0], centre[1]) + 0.02
    hub = bm.verts.new((centre[0], centre[1], cz))
    rim = []
    for i in range(seg):
        t = math.tau * i / seg
        r = width * 0.5 * (1.0 + amps[0] * math.sin(ks[0] * t + ph[0])
                                + amps[1] * math.sin(ks[1] * t + ph[1])
                                + amps[2] * math.sin(ks[2] * t + ph[2]))
        lx, ly = math.cos(t) * r * stretch, math.sin(t) * r
        x = centre[0] + lx * ca - ly * sa
        y = centre[1] + lx * sa + ly * ca
        rim.append(bm.verts.new((x, y, platform_z(x, y) + 0.02)))
    for i in range(seg):
        try:
            bm.faces.new((hub, rim[i], rim[(i + 1) % seg])).material_index = idx
        except ValueError:
            pass
    return new_obj(name, bm)


## Footprints already claimed this build. A placement that would land on one is walked out
## along a golden-angle spiral until it finds air - the first pass placed by hand-picked
## coordinates and put the mess hall inside a gun pit.
OCCUPIED = []


def footprint_r(master):
    """Circumscribed radius. max(dx,dy)/2 under-measures a square across its diagonal, which
    is how a 15 m helipad kept clipping a bunker that the check called clear."""
    d = master.dimensions
    return math.hypot(d.x, d.y) * 0.5


def free_spot(x0, y0, r, rng, tries=72, clearance=0.82):
    for k in range(tries):
        if k == 0:
            x, y = x0, y0
        else:
            ang = k * 2.3999632
            rad = 2.2 * math.sqrt(k)
            x, y = x0 + math.cos(ang) * rad, y0 + math.sin(ang) * rad
        if all(math.dist((x, y), (ox, oy)) >= (r + orr) * clearance
               for ox, oy, orr in OCCUPIED):
            return x, y
    return None


def place(master, pos, bearing, rng, jitter=0.0, claim=True, must_fit=True):
    """Instance a master. Ground-sitting is the mesh's job - the families already model
    their own excavation, so subtracting an extra sink here dug everything in twice."""
    x = pos[0] + rng.uniform(-jitter, jitter)
    y = pos[1] + rng.uniform(-jitter, jitter)
    r = footprint_r(master)
    if must_fit:
        spot = free_spot(x, y, r, rng)
        if spot is None:
            return None
        x, y = spot
    if claim:
        OCCUPIED.append((x, y, r))
    ob = bpy.data.objects.new(master.name.split(".")[0] + "_i", master.data)
    ob.location = (x, y, platform_z(x, y))
    ob.rotation_euler = (0.0, 0.0, bearing + math.pi / 2.0 + rng.uniform(-0.06, 0.06))
    bpy.context.collection.objects.link(ob)
    return ob


def polar(r, a):
    return (math.cos(a) * r * RIDGE_STRETCH, math.sin(a) * r)


VEG_DIR = r"C:\Users\caleb\RECONgame\assets\world\vegetation"

## Cards for anything leafy (the impostor decree, war room 2026-07-17); logs and stumps stay
## solid because the player takes cover behind them.
VEG_GROUPS = {
    # file list, band as a fraction of the skirt, count, scale range
    "stump":  (["tree_stump.glb"], (-0.05, 0.55), 90, (0.75, 1.45)),
    "log":    (["fallen_log_a.glb", "fallen_log_b.glb", "felled_trunk.glb"],
               (-0.02, 0.62), 46, (0.85, 1.40)),
    "felled": (["felled_tree.glb"], (0.05, 0.55), 16, (0.90, 1.25)),
    "shrub":  (["cards/bush_a_card.glb", "cards/bush_b_card.glb", "cards/bush_c_card.glb",
                "cards/fern_a_card.glb", "cards/fern_b_card.glb", "cards/fern_c_card.glb"],
               (0.22, 1.10), 150, (0.80, 1.45)),
    "grass":  (["cards/elephant_grass_a_card.glb", "cards/tall_grass_a_card.glb",
                "cards/grass_tuft_b_card.glb"], (0.10, 1.20), 130, (0.75, 1.35)),
    "tree":   (["cards/jungle_palm_a1_card.glb", "cards/jungle_palm_a2_card.glb",
                "cards/jungle_palm_b1_card.glb", "cards/jungle_palm_b3_card.glb",
                "cards/palm_sapling_a_card.glb"], (0.72, 1.45), 80, (0.85, 1.30)),
}


def _load_mesh(path):
    before = set(bpy.data.objects.keys())
    bpy.ops.import_scene.gltf(filepath=path)
    new = [bpy.data.objects[k] for k in set(bpy.data.objects.keys()) - before]
    src = [o for o in new if o.type == 'MESH' and 'colonly' not in o.name.lower()]
    me = None
    if src:
        me = src[0].data.copy()
        me.transform(src[0].matrix_world)
        for m in me.materials:
            if m is not None and getattr(m, "blend_method", None) == 'BLEND':
                m.blend_method = 'HASHED'
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
    return me


def scatter_veg(rng):
    """Cut-over ground running out into jungle: stumps and logs where the engineers
    cleared fields of fire, scrub and palms further out where they stopped cutting."""
    made = []
    for group, (files, band, count, scale) in VEG_GROUPS.items():
        per_file = {}
        for fn in files:
            me = _load_mesh(os.path.join(VEG_DIR, fn.replace("/", os.sep)))
            if me is not None:
                per_file[fn] = (me, bmesh.new())
        if not per_file:
            continue
        for _ in range(count):
            a = rng.uniform(0.0, math.tau)
            if in_gate(a) and rng.random() < 0.85:
                continue                                  # keep the road out of the wire clear
            e, fa = edge_at(a), fall_at(a)
            r_local = e + fa * rng.uniform(band[0], band[1])
            x = math.cos(a) * r_local * RIDGE_STRETCH + rng.uniform(-2.5, 2.5)
            y = math.sin(a) * r_local + rng.uniform(-2.5, 2.5)
            fn = rng.choice(list(per_file))
            me, bm = per_file[fn]
            s = rng.uniform(*scale)
            m = (Matrix.Translation((x, y, ground_z(x, y) - 0.05))
                 @ Euler((rng.uniform(-0.06, 0.06), rng.uniform(-0.06, 0.06),
                          rng.uniform(0.0, math.tau))).to_matrix().to_4x4()
                 @ Matrix.Scale(s, 4))
            tmp = me.copy()
            tmp.transform(m)
            bm.from_mesh(tmp)
            bpy.data.meshes.remove(tmp)
        for fn, (me, bm) in per_file.items():
            if not bm.faces:
                bm.free()
                bpy.data.meshes.remove(me)
                continue
            stem = os.path.splitext(os.path.basename(fn))[0].replace("_card", "")
            out = bpy.data.meshes.new(f"fb_veg_{stem}")
            bm.to_mesh(out)
            bm.free()
            for mat in me.materials:
                out.materials.append(mat)
            ob = bpy.data.objects.new(f"fb_veg_{stem}", out)
            bpy.context.collection.objects.link(ob)
            made.append(ob)
            bpy.data.meshes.remove(me)
    return made


def scorch_marks(rng):
    """Burnt ground in and around the craters - the mud shader doubles as scorch."""
    out = []
    for cx, cy, r, _d in CRATERS:
        out.append(mud_blob((cx, cy), r * rng.uniform(1.5, 2.3), rng,
                            name="fb_scorch", style="splat"))
    return out


def redress(seed=SEED):
    """Rebuild ONLY the ground dressing in the CURRENT scene: mound, craters, scorch and
    vegetation. Buildings are left exactly where they are - they get hand-moved."""
    rng = random.Random(seed)
    doomed = [o for o in bpy.context.scene.objects
              if o.name.startswith(("fb_terrain_mound", "fb_veg_", "fb_scorch"))]
    for o in doomed:
        bpy.data.objects.remove(o, do_unlink=True)
    crater_field(rng)
    mound = terrain_mound(rng)
    veg = scatter_veg(rng)
    sc = scorch_marks(rng)
    tris = sum(len(p.vertices) - 2 for p in mound.data.polygons)
    vtris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in veg)
    print(f"redress: removed {len(doomed)} old | mound {tris} tris | craters {len(CRATERS)} "
          f"| veg {len(veg)} meshes {vtris} tris | scorch {len(sc)}")
    return mound, veg


## NPC anchors. The contract is site_planner.gd:541-566: markers export as plain Node3D
## (never Marker3D), are found by NAME PREFIX, and work_type falls back to whatever follows
## "work_" when the glTF carries no extras. Encoding the type in the name means these survive
## an export with Custom Properties off, which is what the kit spec asks for.
##
## There is no "idle_" prefix in the game - nothing reads one. Idling is a work_type here
## rather than a second parallel convention nobody consumes.
STATION_PLAN = {
    "fb_gun_pit":          [("gun", 2, 2.2, 3.6), ("ammo", 2, 4.2, 5.4)],
    "fb_mortar_pit":       [("mortar", 2, 1.4, 2.4), ("ammo", 1, 3.4, 4.2)],
    "fb_bunker_mg":        [("mg", 1, 0.0, 0.6), ("watch", 1, 2.6, 3.4)],
    "fb_bunker_fighting":  [("watch", 2, 2.2, 3.2)],
    "fb_sleeping_bunker":  [("rest", 2, 2.4, 3.4)],
    "fb_tower":            [("watch", 1, 0.0, 0.8)],
    "fb_toc":              [("radio", 3, 3.2, 4.6), ("plot", 2, 2.4, 3.2)],
    "fb_aid_station":      [("medic", 3, 2.6, 3.8)],
    "fb_mess":             [("cook", 3, 2.8, 4.0), ("mess", 6, 4.4, 6.2)],
    "fb_gp_tent":          [("supply", 3, 3.4, 5.0)],
    "fb_supply_dump":      [("supply", 2, 2.6, 4.0)],
    "fb_sandbag_stack":    [("dig", 2, 1.8, 3.0), ("rest", 1, 2.2, 3.2)],
    "fb_water_point":      [("wash", 3, 1.6, 2.6)],
    "fb_latrine":          [("latrine", 1, 1.6, 2.4)],
    "fb_burn_barrel":      [("burn", 1, 1.4, 2.2)],
    "fb_hootch":           [("rest", 3, 3.0, 4.6), ("smoke", 1, 3.4, 4.4)],
    "fb_helipad":          [("pad", 4, 6.0, 8.5)],
    "fb_gate_gap":         [("guard", 3, 3.0, 5.0)],
    "fb_howitzer":         [],          # the pit already carries the gun stations
}


def _empty(name, pos, yaw, size=0.5, props=None):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = 'SINGLE_ARROW'
    e.empty_display_size = size
    e.location = pos
    # Godot local +Z is Blender local -Y (gen_firebase.py:40-42). Never re-derive it.
    e.rotation_euler = (0.0, 0.0, yaw + math.pi / 2.0)
    for k, v in (props or {}).items():
        e[k] = v
    bpy.context.collection.objects.link(e)
    return e


def npc_points(seed=SEED + 11):
    """Stamp work stations around every placed piece IN THE CURRENT SCENE.

    Reads the instances where they actually are, so hand-moved buildings keep their
    stations. Also re-emits each family's own baked markers (GUN_POINT, mg_fire_point,
    door_main, prop_bunk) into world space - build_piece computes them per family and the
    layout was throwing them away.
    """
    rng = random.Random(seed)
    sc = bpy.context.scene
    for o in [o for o in sc.objects if o.type == 'EMPTY']:
        bpy.data.objects.remove(o, do_unlink=True)

    # harvest each family's own model-space markers without building geometry
    fam_markers = {}
    for fam, fn in gf.FAMILIES.items():
        gf.reset_markers()
        try:
            fn(bmesh.new(), random.Random(1))
        except Exception:
            continue
        fam_markers[fam] = list(gf.MARKERS)

    made = {}
    for o in list(sc.objects):
        if o.type != 'MESH':
            continue
        fam = o.name.split(".")[0].replace("_i", "")
        if fam not in STATION_PLAN and fam not in fam_markers:
            continue
        M = o.matrix_world
        base_yaw = o.rotation_euler.z

        for m in fam_markers.get(fam, []):
            wp = M @ Vector(m["pos"])
            nm = m["name"]
            if nm.startswith("prop_"):
                out = _empty(nm, wp, base_yaw + m["face"], 0.35,
                             {"prop_class": m["props"].get("prop_class", "")})
            elif nm.upper() == "GUN_POINT" or nm.startswith("work_"):
                wt = m["props"].get("work_type", "gun")
                out = _empty(f"work_{wt}", wp, base_yaw + m["face"], 0.5)
            elif "fire_point" in nm:
                out = _empty(f"work_{m['props'].get('work_type', 'mg')}", wp,
                             base_yaw + m["face"], 0.5)
            else:
                out = _empty(nm, wp, base_yaw + m["face"], 0.4)
            made[out.name.split(".")[0]] = made.get(out.name.split(".")[0], 0) + 1

        for wtype, count, r0, r1 in STATION_PLAN.get(fam, []):
            for _ in range(count):
                a = rng.uniform(0.0, math.tau)
                r = rng.uniform(r0, r1)
                p = M.translation + Vector((math.cos(a) * r, math.sin(a) * r, 0.0))
                p.z = ground_z(p.x, p.y) + 0.02
                # face the piece it belongs to
                out = _empty(f"work_{wtype}", p, math.atan2(M.translation.y - p.y,
                                                            M.translation.x - p.x), 0.5)
                made[f"work_{wtype}"] = made.get(f"work_{wtype}", 0) + 1
    return made


## The garrison contract. site_planner.gd:674-707 looks these names up BY EXACT STRING, and
## :685-686 says a post whose marker is absent is SKIPPED, never relocated. Miss one and that
## post simply has nobody standing on it; miss them all and the firebase has no garrison.
## FSB_GARRISON_QUARTERS reuses FOOTPRINT_* as where off-shift men sleep, so those belong on
## hootches - NOT on the ground-contact ring the v1 comment described them as.
LEGACY_MARKERS = [
    ("SOCKET_A_001",        "rename", "SOCKET_A"),
    ("SOCKET_B_001",        "rename", "SOCKET_B"),
    ("FACE_OUT_001",        "rename", "FACE_OUT"),
    ("APPROACH_001",        "rename", "APPROACH"),
    ("mg_fire_point_001",   "at",     "fb_bunker_mg"),
    ("bunker_los_point_001", "rename", "bunker_los_point"),
    ("tower_los_point_001", "rename", "tower_los_point"),
    ("GUN_POINT_001",       "at",     "fb_gun_pit"),
    ("USSupplyDepot_001",   "at",     "fb_supply_dump"),
    ("USSupplyDepot_007",   "at",     "fb_supply_dump"),
    ("FOOTPRINT_001",       "at",     "fb_hootch"),
    ("FOOTPRINT_002",       "at",     "fb_hootch"),
    ("FOOTPRINT_003",       "at",     "fb_toc"),
    ("FOOTPRINT_004",       "at",     "fb_hootch"),
    ("FOOTPRINT_007",       "at",     "fb_hootch"),
    ("APPROACH_002",        "at",     "fb_mess"),
]


def refresh_family_meshes(names):
    """Rebuild a family's mesh and swap it onto every instance already in the scene.

    Placements are hand-tuned by now, so re-running main() to pick up a family edit would
    throw them away. This changes the geometry under them and touches nothing else.
    """
    swapped = {}
    for i, name in enumerate(names):
        inst = [o for o in bpy.context.scene.objects
                if o.type == 'MESH' and o.name.split(".")[0].replace("_i", "") == name]
        if not inst:
            continue
        ob, _, _ = gf.build_piece(name, 7700 + sorted(gf.FAMILIES).index(name) * 37)
        new_me = ob.data
        old = {o.data for o in inst}
        for o in inst:
            o.data = new_me
        bpy.data.objects.remove(ob, do_unlink=True)
        for me in old:
            if me.users == 0:
                bpy.data.meshes.remove(me)
        swapped[name] = len(inst)
    print("refreshed family meshes:", swapped)
    return swapped


def legacy_garrison_markers():
    """Emit the exact marker names site_planner's garrison plan looks up."""
    sc = bpy.context.scene
    for o in list(sc.objects):
        if o.type == 'EMPTY' and o.name.split(".")[0] in {k for k, _, _ in LEGACY_MARKERS}:
            bpy.data.objects.remove(o, do_unlink=True)

    used_hosts = set()
    report = []
    for key, mode, src in LEGACY_MARKERS:
        pos = yaw = None
        if mode == "rename":
            cand = [o for o in sc.objects if o.type == 'EMPTY' and o.name.split(".")[0] == src]
            if cand:
                pos, yaw = cand[0].location.copy(), cand[0].rotation_euler.z
        else:
            hosts = [o for o in sc.objects if o.type == 'MESH'
                     and o.name.split(".")[0].replace("_i", "") == src
                     and o.name not in used_hosts]
            if hosts:
                h = hosts[0]
                used_hosts.add(h.name)
                pos = h.matrix_world.translation.copy()
                pos.z = ground_z(pos.x, pos.y) + 0.02
                yaw = h.rotation_euler.z
        if pos is None:
            report.append((key, "MISSING"))
            continue
        e = bpy.data.objects.new(key, None)
        e.empty_display_type = 'ARROWS'
        e.empty_display_size = 1.2
        e.location = pos
        e.rotation_euler = (0.0, 0.0, yaw)
        sc.collection.objects.link(e)
        report.append((key, "ok"))
    missing = [k for k, s in report if s != "ok"]
    print(f"legacy garrison markers: {len(report) - len(missing)}/{len(report)} placed")
    if missing:
        print("  MISSING (these garrison posts would be silently skipped):", missing)
    return missing


## Godot builds collision from glTF nodes whose name ENDS WITH `-colonly`. Blender's `.001`
## duplicate suffix lands AFTER the name, so `fb_hootch-colonly.001` exports as
## `fb_hootch-colonly_001` and no longer ends with the suffix - it would import as a silent
## invisible mesh with no collision. Every twin here is numbered BEFORE the suffix instead.

## Alpha cards and ground decals: the player walks through leaves and over mud.
## door_ leaves are VISUAL ONLY and must never receive a collider. A box hull here bricks
## up the doorway it hangs in, and the leaf would also join nav_blockers - both fatal to the
## screen door, which is deliberately always passable so a hooch interior can never become a
## player safe room (Pillar 1: "if the firebase ever gets over run you can hide in the hooch
## and enemies can come in"). ScreenDoor swings it off an Area3D; nothing ever collides with it.
COL_NONE = ("fb_mud_patch", "fb_scorch", "fb_road_", "fb_duckboard",
            "fb_veg_bush", "fb_veg_fern", "fb_veg_elephant", "fb_veg_tall_grass",
            "fb_veg_grass", "fb_veg_jungle_palm", "fb_veg_palm_sapling",
            "door_")

## scatter_veg MERGES every instance of a card into ONE object spanning the whole treeline
## ring, so the solid veg cannot take the default box hull: a box around 90 merged stumps is a
## 300m slab from the ground to the tallest one. Four of those were stacked over the base -
## invisible floors with walkable tops - and are what the player kept getting stuck on.
COL_VEG_SOLID = ("fb_veg_tree_stump", "fb_veg_fallen_log", "fb_veg_felled_trunk",
                 "fb_veg_felled_tree")

## Anything with a doorway, a pit, a walkable surface OR A HOLE YOU SHOOT THROUGH needs the
## REAL shape. The else-branch of make_collision() wraps an object in an axis-aligned BOX,
## and a box fills every opening in the mesh it wraps - it would seal the bunkers shut and
## brick up every firing slit.
##
## fb_sbg_seg_ (the perimeter parapet) joined this list on 2026-07-29 so lead goes through the
## cracks between courses and through any embrasure cut into a segment. Its box hull was also
## a flat 6 m slab at the crest - a clean ledge to stand on, on a perimeter nobody should be
## able to stand on.
## MEASURE THE COST: ~50 segments of 9-course bag geometry going box -> trimesh, on a project
## whose PERF_LEDGER says it is call-bound. If it bites, the answer is NOT to go back to
## boxes; it is to author a low-poly `-colonly` PROXY per segment with the slit cut into it.
COL_TRIMESH = COL_VEG_SOLID + (
               # THE GROUND. fb_terrain_mound is the walkable surface of the whole compound -
               # the terrain is levelled to its toe and stops there, so this trimesh is what
               # the player and every AI actually stand on. It must be one continuous, welded,
               # outward-facing surface with nothing steeper than ~40 degrees where a man
               # crosses: see FIREBASE_BLENDER_HANDOFF.md §00 for the export contract and the
               # slope-check script. A box hull here would flatten the craters into a lid.
               "fb_terrain_mound",
               "fb_sbg_seg_",
               "fb_berm_ring", "fb_helipad", "fb_tower", "fb_gun_pit",
               # fb_bunker_steps joined 2026-08-12. The stairs are 28-33 degrees, well inside
               # agent_max_slope, but a BOX hull over a staircase is a solid ramp-shaped block:
               # men walked over the top instead of down into the bunker, and the entrance the
               # steps exist to provide was sealed. Same failure as a box over a doorway.
               "fb_bunker_steps",
               "fb_mortar_pit", "fb_trench_run", "fb_gate_gap", "fb_toc", "fb_mess",
               "fb_hootch", "fb_gp_tent", "fb_aid_station", "fb_bunker_mg",
               "fb_bunker_fighting", "fb_sleeping_bunker", "bwire_card_ring")


def make_collision():
    """Emit a `-colonly` twin per solid object. Returns the created objects."""
    sc = bpy.context.scene
    made, boxes, tris, skipped = [], 0, 0, 0
    for i, o in enumerate(list(sc.objects)):
        if o.type != 'MESH' or o.name.endswith("-colonly"):
            continue
        base = o.name.split(".")[0]
        if base.startswith(COL_NONE):
            skipped += 1
            continue
        name = f"{base}_{i:03d}-colonly"
        if base.startswith(COL_TRIMESH):
            col = bpy.data.objects.new(name, o.data)      # shares the mesh; one copy in the file
            tris += 1
        else:
            vs = [v.co for v in o.data.vertices]
            if not vs:
                continue
            x0, x1 = min(v.x for v in vs), max(v.x for v in vs)
            y0, y1 = min(v.y for v in vs), max(v.y for v in vs)
            z0, z1 = min(v.z for v in vs), max(v.z for v in vs)
            bm = bmesh.new()
            bmesh.ops.create_cube(bm, size=1.0)
            for v in bm.verts:
                v.co.x = x0 + (v.co.x + 0.5) * max(x1 - x0, 0.02)
                v.co.y = y0 + (v.co.y + 0.5) * max(y1 - y0, 0.02)
                v.co.z = z0 + (v.co.z + 0.5) * max(z1 - z0, 0.02)
            me = bpy.data.meshes.new(name)
            bm.to_mesh(me)
            bm.free()
            col = bpy.data.objects.new(name, me)
            boxes += 1
        col.matrix_world = o.matrix_world.copy()
        sc.collection.objects.link(col)
        made.append(col)
    print(f"collision: {len(made)} -colonly twins ({tris} trimesh, {boxes} box), "
          f"{skipped} left passable")
    return made


def clear_collision():
    n = 0
    for o in list(bpy.context.scene.objects):
        if o.name.endswith("-colonly") or "-colonly." in o.name:
            bpy.data.objects.remove(o, do_unlink=True)
            n += 1
    return n


def export_firebase(glb=None):
    """Collision twins are an EXPORT artefact: generated, exported, stripped. Keeping them
    in the .blend would double every object in the outliner and they would drift out of sync
    with the meshes the moment anything moved."""
    sc = bpy.context.scene
    glb = glb or os.path.join(ROOT, "fsb_main_v3.glb")

    clear_collision()
    make_collision()
    bpy.context.view_layer.update()
    # ARMATURE joined this set 2026-08-12. Without it the staged crews - the surgery, the
    # officers, the tended wounded - exported as skinned meshes with no skeleton, so Godot
    # fell back to the BIND pose and every figure in the compound stood in a T-pose. The
    # exporter says so out loud ("Armature must be the parent of skinned mesh"); nine of
    # those warnings were in the log and read as noise. glTF stores each joint's CURRENT
    # transform, so exporting the armature carries the staged pose with it.
    for o in sc.objects:
        o.select_set(o.type in {'MESH', 'EMPTY', 'ARMATURE'})
    bpy.context.view_layer.objects.active = next(o for o in sc.objects if o.type == 'MESH')
    bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True, export_cameras=False,
                              export_lights=False, export_extras=False, export_tangents=False)
    size = os.path.getsize(glb) / 1048576.0
    write_mound_manifest(os.path.join(os.path.dirname(glb), MOUND_MANIFEST))
    clear_collision()
    # THE EXPORT DOES NOT WRITE THE ARTIST'S FILE. This used to purge every zero-user
    # mesh/material/image and then save_as_mainfile over the source blend - and zero users
    # is not the same as garbage: anything held only by a temporarily unlinked collection,
    # or by a workbench that is not exported, has zero users at this moment. That purge and
    # save is what destroyed the medical complex on 2026-07-31. The GLB is already written
    # above; the collision twins are an export artefact and clear_collision() has just
    # removed them from the live session. Saving is the artist's call, in Blender, with undo.
    print(f"exported {glb} ({size:.2f} MB); source blend untouched")
    return size


ROOT_GLB = ROOT


# ----------------------------------------------------------------------- main --

def main():
    bpy.ops.wm.read_homefile(use_empty=True)
    rng = random.Random(SEED)
    fb_kit.build_wall_texture()
    fb_kit.build_mud_texture()

    masters = {}
    for i, name in enumerate(sorted(gf.FAMILIES)):
        ob, _, _ = gf.build_piece(name, 7700 + i * 37)
        ob.location = (0.0, 0.0, -900.0)
        masters[name] = ob

    path = perimeter()
    OCCUPIED.clear()
    crater_field(rng)
    terrain_mound(rng)
    berm(path, rng)
    segs, rows = parapet_segments(path, rng)
    wire(path, rng)

    n = 0
    # The bunker line is placed FIRST and holds its ground: it is fixed to the berm, and
    # everything softer gets walked out of its way instead.
    line = offset_closed(path, -5.0)
    fams = ["fb_bunker_mg", "fb_bunker_fighting", "fb_bunker_fighting", "fb_sleeping_bunker"]
    step = max(1, len(line) // 13)
    for k in range(0, len(line), step):
        p = line[k]
        if in_gate(bearing_of(p)):
            continue
        if place(masters[fams[(k // step) % 4]], p, bearing_of(p), rng, 0.7,
                 must_fit=False):
            n += 1
    trench_line = offset_closed(path, -11.5)
    for k in range(0, len(trench_line), max(1, len(trench_line) // 8)):
        p = trench_line[k]
        if in_gate(bearing_of(p)):
            continue
        if place(masters["fb_trench_run"], p, bearing_of(p), rng, 0.5):
            n += 1
    claymore_line = offset_closed(path, 13.0)
    for k in range(0, len(claymore_line), max(1, len(claymore_line) // 16)):
        p = claymore_line[k]
        if in_gate(bearing_of(p)):
            continue
        if place(masters["fb_claymore"], p, bearing_of(p), rng, 1.4, claim=False,
                 must_fit=False):
            n += 1

    place(masters["fb_gate_gap"], polar(R0 - 2.0, GATE_BEARING), GATE_BEARING, rng); n += 1
    # the road out through the gate
    ribbon([polar(R0 - 7.0, GATE_BEARING), polar(R0 + 4.0, GATE_BEARING),
            polar(R0 + 26.0, GATE_BEARING)], 5.0, "fb_mud", 0.04, "fb_road_gate", rng=rng)

    # SIX-GUN BATTERY IN A STAR: base piece centre, five on the points (research).
    # The howitzer belongs INSIDE its pit, so it neither claims a footprint nor gets moved.
    bc = Vector((-8.0, 6.0))
    guns = []
    if place(masters["fb_gun_pit"], (bc.x, bc.y), 0.3, rng, must_fit=False):
        guns.append(((bc.x, bc.y), 0.3)); n += 1
    for i in range(5):
        a = math.tau * i / 5 + 0.55
        p = (bc.x + math.cos(a) * 30.0, bc.y + math.sin(a) * 30.0)
        if place(masters["fb_gun_pit"], p, a, rng, 0.8, must_fit=False):
            guns.append((p, a)); n += 1
    for p, a in guns:
        place(masters["fb_howitzer"], p, a, rng, 0.4, claim=False, must_fit=False); n += 1
        # ammo niche, clear of the parapet ring rather than inside it
        if place(masters["fb_supply_dump"], (p[0] + math.cos(a + 1.5) * 12.5,
                                             p[1] + math.sin(a + 1.5) * 12.5), a, rng, 0.6):
            n += 1
    for i in range(2):
        a = 2.2 + i * 1.1
        if place(masters["fb_mortar_pit"],
                 (bc.x + math.cos(a) * 44.0, bc.y + math.sin(a) * 44.0), a, rng, 0.6):
            n += 1

    if place(masters["fb_toc"], (bc.x + 3.0, bc.y - 30.0), 1.2, rng):
        n += 1

    # living line, strung along the ridge axis rather than on a ring
    camp = ["fb_hootch", "fb_hootch", "fb_gp_tent", "fb_hootch", "fb_mess", "fb_hootch",
            "fb_aid_station", "fb_hootch", "fb_gp_tent", "fb_hootch", "fb_hootch"]
    camp_pts = []
    for i, fam in enumerate(camp):
        t = i / (len(camp) - 1.0)
        p = (-58.0 + t * 104.0, -34.0 + math.sin(t * 4.2) * 9.0)
        ob = place(masters[fam], p, math.pi * 0.5 + math.sin(t * 3.0) * 0.4, rng, 1.6)
        if ob:
            # the walkway follows where the hootch ENDED UP, not where it was asked for
            camp_pts.append((ob.location.x, ob.location.y))
            n += 1
    # planks in the ground: duckboard spine down the camp, and a spur to the TOC
    if len(camp_pts) > 2:
        ribbon(camp_pts, 1.1, "fb_timber", 0.06, "fb_duckboard_camp", rng=rng, jitter=0.05)
        mid = camp_pts[len(camp_pts) // 2]
        toc_p = (bc.x + 3.0, bc.y - 30.0)
        ribbon([mid, ((mid[0] + toc_p[0]) * 0.5, (mid[1] + toc_p[1]) * 0.5), toc_p],
               1.1, "fb_timber", 0.06, "fb_duckboard_toc")

    # LOGISTICS yard - dumps, drums, water, and the burn/trash pits downwind
    yard = (52.0, 22.0)
    for i in range(5):
        a = math.tau * i / 5
        if place(masters["fb_supply_dump"], (yard[0] + math.cos(a) * 11.0,
                                             yard[1] + math.sin(a) * 11.0), a, rng, 1.0):
            n += 1
    for i in range(6):
        a = math.tau * i / 6 + 0.4
        if place(masters["fb_sandbag_stack"], (yard[0] + math.cos(a) * 18.0,
                                               yard[1] + math.sin(a) * 18.0), a, rng, 1.5):
            n += 1
    ribbon([(yard[0] - 22.0, yard[1] - 7.0), yard, (yard[0] + 12.0, yard[1] + 10.0)],
           4.6, "fb_mud", 0.03, "fb_road_yard", rng=rng, jitter=0.4)

    # LATRINES - downwind of the camp, off on their own, never among the hootches
    for p in [(-64.0, -52.0), (-55.0, -56.0), (30.0, -50.0), (39.0, -46.0)]:
        if place(masters["fb_latrine"], p, rng.uniform(0, math.tau), rng, 0.8):
            n += 1
    for p in [(-60.0, -44.0), (34.0, -40.0), (yard[0] + 8.0, yard[1] - 16.0)]:
        if place(masters["fb_burn_barrel"], p, rng.uniform(0, math.tau), rng, 1.0):
            n += 1
    for p in [(-46.0, -40.0), (22.0, -38.0), (yard[0] - 12.0, yard[1] + 4.0)]:
        if place(masters["fb_water_point"], p, rng.uniform(0, math.tau), rng, 1.0):
            n += 1

    for a in (GATE_BEARING - 0.5, GATE_BEARING + 0.5, GATE_BEARING + math.pi, 1.9):
        if place(masters["fb_tower"], polar(R0 - 7.0, a), a, rng):
            n += 1

    pad_ob = place(masters["fb_helipad"], (12.0, 46.0), 0.6, rng)
    pad = (pad_ob.location.x, pad_ob.location.y) if pad_ob else (12.0, 46.0)
    if pad_ob:
        n += 1
    ribbon([pad, ((pad[0] + yard[0]) * 0.5, (pad[1] + yard[1]) * 0.5 - 3.0),
            (yard[0] - 15.0, yard[1] + 2.0)], 4.2, "fb_mud", 0.03, "fb_road_pad",
           rng=rng, jitter=0.35)

    # Churn where traffic actually collects. Mixed sizes and shapes: broad splats at the
    # hubs, long pools along the ruts, and a scatter of small puddles.
    for p, w in [(pad, 24.0), (yard, 19.0), ((bc.x, bc.y), 17.0),
                 (polar(R0 - 13.0, GATE_BEARING), 15.0)]:
        mud_blob(p, w, rng, style="splat")
    for a in (0.6, 2.4, 4.1, 5.2):
        p = polar(R0 * rng.uniform(0.3, 0.72), a)
        mud_blob(p, rng.uniform(5.0, 9.0), rng, style="pool", angle=a + 1.4)
    for _ in range(16):
        a = rng.uniform(0, math.tau)
        p = polar(R0 * rng.uniform(0.12, 0.86), a)
        mud_blob(p, rng.uniform(1.6, 4.2), rng, style="puddle")

    for m in masters.values():
        bpy.data.objects.remove(m, do_unlink=True)

    out_json = os.path.join(gf.KIT_DIR, "firebase_v3_destructibles.json")
    json.dump({"segment_len": SEG_LEN, "hp": SEG_HP, "count": len(rows),
               "segments": rows}, open(out_json, "w"), indent=1)

    sc = bpy.context.scene
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons)
               for o in sc.objects if o.type == 'MESH')
    print(f"parapet segments: {len(segs)}  placements: {n}  objects: {len(sc.objects)}  "
          f"tris: {tris}")
    print("destructible manifest:", out_json)
    # DRY RUN BY DEFAULT, like every other blend-writing tool here
    # (merge_chowhall_to_firebase.py:180, gen_chowhall_crew.py:478, gen_medical_crew.py:759).
    # This wrote firebase_v3.blend unconditionally and by a HARDCODED name, so a bare run
    # resurrected a file the kit has since moved past.
    if "--save" in sys.argv:
        blend = os.path.join(gf.KIT_DIR, "firebase_v3.blend")
        bpy.ops.wm.save_as_mainfile(filepath=blend, compress=True)
        print("saved", blend, round(os.path.getsize(blend) / 1048576.0, 2), "MB")
    else:
        print("dry run - pass --save to write the kit blend")


if __name__ == "__main__":
    main()
