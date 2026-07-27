"""Generate the jungle temple set for RECON: five DISTINCT Indochina building types.

    blender -b -P tools/gen_temples.py

The first pass built one parametric box and varied its numbers, so everything read the
same. Real Cham/Khmer sites are made of different building types, and that is where the
silhouette variety comes from:

  kalan    tall slender brick sanctuary tower, 6-7 strongly receding tiers, tall finial.
           Vertical pilaster bands up every face. The classic My Son skyline.
  mandapa  square cella + tower with a long low PORCH hall attached to the entrance -
           reads as an L from any angle, never a cube.
  kosagrha the "fire house": low rectangular hall under a saddle/boat-keel roof with
           the ridge running long-ways and the ends kicked up. Nothing else looks like it.
  gopura   broad low gate pavilion you walk THROUGH - aligned doorways front and back,
           flanking wings, a squat tower over the passage.
  terrace  stepped temple-mountain platform, 3 receding terraces with a small shrine on
           top and a monumental stair up one face.

Detail follows period practice: tympanum + lintel over every doorway, blind (false)
doors on the other cardinal faces, colonettes with molded rings, antefixes on each roof
step. Ruins lose tiers and break walls to jagged remnants with debris.

The generator builds STONE ONLY. Every plant on these models is a real mesh from
assets/world/vegetation, copied in and exported alongside the stone - so a temple's
overgrowth is made of the same species as the jungle it stands in.

Everything is boxes and wedges - PSX discipline - and cellas stay hollow so the GLB's
trimesh collision is walkable. Doorway >= 1.25m x 2.05m, chamber >= 2.6m square.
"""
import bpy, bmesh, math, random, os, json
from mathutils import Vector, Euler, Matrix

OUT_DIR = r"C:\Users\caleb\RECONgame\assets\world\building models\structures\temple"
BUDGET = 900

STONE = {
    "temple_sandstone": ((0.44, 0.40, 0.31, 1.0), 0.88),
    "temple_laterite":  ((0.31, 0.22, 0.16, 1.0), 0.95),
    "temple_moss":      ((0.19, 0.26, 0.14, 1.0), 0.96),
}
MAT_INDEX = {n: i for i, n in enumerate(STONE)}
SIDES = {0: (0, -1), 1: (1, 0), 2: (0, 1), 3: (-1, 0)}


TEX_DIR = os.path.join(OUT_DIR, "tex")
# Poly Haven CC0, downscaled to 512 for PSX discipline. Key = material name.
TEX_FILE = {
    "temple_sandstone": "temple_sandstone.png",     # large_sandstone_blocks
    "temple_laterite": "temple_laterite.png",       # coral_stone_wall - porous, laterite-like
    "temple_moss": "temple_moss.png",               # mossy_brick
}


def ensure_materials():
    mats = []
    for name, (col, rough) in STONE.items():
        m = bpy.data.materials.get(name)
        if m is None:
            m = bpy.data.materials.new(name)
            m.use_nodes = True
            nt = m.node_tree
            bsdf = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
            if bsdf:
                bsdf.inputs["Base Color"].default_value = col
                bsdf.inputs["Roughness"].default_value = rough
                path = os.path.join(TEX_DIR, TEX_FILE.get(name, ""))
                if os.path.exists(path):
                    img = bpy.data.images.load(path, check_existing=True)
                    tex = nt.nodes.new("ShaderNodeTexImage")
                    tex.image = img
                    tex.location = (-420, 220)
                    tex.interpolation = 'Closest'      # crunchy, period-correct
                    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        m.diffuse_color = col
        mats.append(m)
    return mats


def box_project_uvs(mesh, tile=2.2):
    """Box-project every face onto its dominant axis.

    The whole model is axis-aligned blocks, so a planar projection per face gives
    clean, consistently-scaled tiling with no unwrap cost and no visible seams -
    and it means texel density matches across a 12m terrace and a 0.2m antefix.
    """
    uv = mesh.uv_layers.get("UVMap") or mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        n = poly.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for li in poly.loop_indices:
            co = mesh.vertices[mesh.loops[li].vertex_index].co
            if ax == 0:
                u, v = co.y, co.z
            elif ax == 1:
                u, v = co.x, co.z
            else:
                u, v = co.x, co.y
            uv.data[li].uv = (u / tile, v / tile)


def box(bm, centre, size, mat="temple_sandstone", rot=None, taper=1.0):
    cx, cy, cz = centre
    sx, sy, sz = size[0] / 2.0, size[1] / 2.0, size[2] / 2.0
    tx, ty = sx * taper, sy * taper
    pts = [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz),
           (-tx, -ty, sz), (tx, -ty, sz), (tx, ty, sz), (-tx, ty, sz)]
    if rot is not None:
        R = Euler(rot).to_matrix()
        pts = [R @ Vector(p) for p in pts]
    vs = [bm.verts.new((p[0] + cx, p[1] + cy, p[2] + cz)) for p in pts]
    idx = MAT_INDEX[mat]
    for f in [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]:
        try:
            bm.faces.new([vs[i] for i in f]).material_index = idx
        except ValueError:
            pass


def saddle_roof(bm, centre, size, mat="temple_sandstone", kick=0.35):
    """Boat-keel roof - the kosagrha read, and NOT a European gable.

    A straight ridge with flat slopes is a church nave. The Cham saddle roof instead
    SAGS at mid-span and kicks up hard at both ends, the eaves sweep up to follow, and
    horn finials terminate the ridge. That upswept curve is the whole identity.
    """
    cx, cy, cz = centre
    hx, hy, hz = size[0] / 2.0, size[1] / 2.0, size[2]
    idx = MAT_INDEX[mat]
    SEG = 5

    def ridge_z(t):                       # t in -1..1 along the length
        return hz * 0.86 + (hz * 0.62 + kick) * (abs(t) ** 2.2)

    def eave_z(t):
        return (hz * 0.30) * (abs(t) ** 2.6)          # eaves sweep up at the ends too

    def half_w(t):
        return hx * (1.0 + 0.16 * (abs(t) ** 2))      # and flare outward

    rows = []
    for i in range(SEG + 1):
        t = -1.0 + 2.0 * i / SEG
        y = t * hy
        w = half_w(t)
        rows.append((
            bm.verts.new((cx - w, cy + y, cz + eave_z(t))),
            bm.verts.new((cx, cy + y, cz + ridge_z(t))),
            bm.verts.new((cx + w, cy + y, cz + eave_z(t))),
        ))
    for i in range(SEG):
        a, b = rows[i], rows[i + 1]
        for pair in ((0, 1), (1, 2)):
            p, q = pair
            try:
                bm.faces.new((a[p], a[q], b[q], b[p])).material_index = idx
            except ValueError:
                pass
    for r in (rows[0], rows[-1]):          # close the gable ends
        try:
            bm.faces.new(r).material_index = idx
        except ValueError:
            pass
    # horn finials terminating the ridge
    for t in (-1.0, 1.0):
        box(bm, (cx, cy + t * hy, cz + ridge_z(t) + 0.22), (0.16, 0.34, 0.52), mat,
            rot=(t * 0.45, 0, 0), taper=0.35)


def plinth(bm, w, d, rng, steps=2):
    z = 0.0
    for i in range(steps):
        h = 0.34 - i * 0.04
        pad = 1.7 - i * 0.8
        box(bm, (0, 0, z + h / 2), (w + pad, d + pad, h), "temple_laterite", taper=0.97)
        z += h
    return z, (w + 1.7) / 2.0, (d + 1.7) / 2.0


def doorway_wall(bm, w, d, floor_z, wall_h, side, rng, blind=False, thru=False):
    """One cella face. blind=False cuts a real opening; blind=True gets a false door."""
    t, dw, dh = 0.45, 1.35, 2.15
    nx, ny = SIDES[side]
    if blind:
        if nx == 0:
            box(bm, (0, ny * (d - t) / 2.0, floor_z + wall_h / 2), (w, t, wall_h))
            box(bm, (0, ny * (d / 2.0 + 0.07), floor_z + wall_h * 0.44),
                (dw * 0.78, 0.14, dh * 0.82), taper=0.94)
            box(bm, (0, ny * (d / 2.0 + 0.10), floor_z + dh * 0.86), (dw * 0.95, 0.18, 0.26))
        else:
            box(bm, (nx * (w - t) / 2.0, 0, floor_z + wall_h / 2), (t, d, wall_h))
            box(bm, (nx * (w / 2.0 + 0.07), 0, floor_z + wall_h * 0.44),
                (0.14, dw * 0.78, dh * 0.82), taper=0.94)
            box(bm, (nx * (w / 2.0 + 0.10), 0, floor_z + dh * 0.86), (0.18, dw * 0.95, 0.26))
        return
    span = w if nx == 0 else d
    side_w = (span - dw) / 2.0
    for sgn in (-1, 1):
        if nx == 0:
            box(bm, (sgn * (dw + side_w) / 2.0, ny * (d - t) / 2.0, floor_z + wall_h / 2),
                (side_w, t, wall_h))
        else:
            box(bm, (nx * (w - t) / 2.0, sgn * (dw + side_w) / 2.0, floor_z + wall_h / 2),
                (t, side_w, wall_h))
    lint = wall_h - dh
    if lint > 0.05:
        if nx == 0:
            box(bm, (0, ny * (d - t) / 2.0, floor_z + dh + lint / 2), (dw, t, lint))
            box(bm, (0, ny * (d / 2.0 + 0.11), floor_z + dh + 0.12), (dw + 0.6, 0.22, 0.26))
            box(bm, (0, ny * (d / 2.0 + 0.09), floor_z + dh + 0.42), (dw + 0.2, 0.16, 0.34),
                taper=0.6)                                   # tympanum
            # kala: fierce head on the lintel, upper jaw only - no lower jaw, by rule
            box(bm, (0, ny * (d / 2.0 + 0.17), floor_z + dh + 0.40), (0.46, 0.16, 0.34),
                taper=0.7)
            for tx in (-0.13, 0.13):
                box(bm, (tx, ny * (d / 2.0 + 0.20), floor_z + dh + 0.26), (0.09, 0.10, 0.14),
                    taper=0.3)
        else:
            box(bm, (nx * (w - t) / 2.0, 0, floor_z + dh + lint / 2), (t, dw, lint))
            box(bm, (nx * (w / 2.0 + 0.11), 0, floor_z + dh + 0.12), (0.22, dw + 0.6, 0.26))
            box(bm, (nx * (w / 2.0 + 0.09), 0, floor_z + dh + 0.42), (0.16, dw + 0.2, 0.34),
                taper=0.6)
            box(bm, (nx * (w / 2.0 + 0.17), 0, floor_z + dh + 0.40), (0.16, 0.46, 0.34),
                taper=0.7)
            for ty in (-0.13, 0.13):
                box(bm, (nx * (w / 2.0 + 0.20), ty, floor_z + dh + 0.26), (0.10, 0.09, 0.14),
                    taper=0.3)
    for sgn in (-1, 1):                                      # colonettes + molded rings
        if nx == 0:
            c = (sgn * (dw / 2 + 0.13), ny * (d / 2.0 + 0.07))
        else:
            c = (nx * (w / 2.0 + 0.07), sgn * (dw / 2 + 0.13))
        box(bm, (c[0], c[1], floor_z + dh / 2), (0.17, 0.17, dh), taper=0.88)
        for k in (0.3, 0.7):
            box(bm, (c[0], c[1], floor_z + dh * k), (0.23, 0.23, 0.09))


def pilasters(bm, w, d, floor_z, wall_h, count=1):
    """Vertical bands up each face - what stops a wall reading as a flat slab."""
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(bm, (sx * w / 2.0, sy * d / 2.0, floor_z + wall_h / 2),
                (0.32, 0.32, wall_h), taper=0.92)
    for i in range(count):
        f = (i + 1) / float(count + 1)
        for ny in (-1, 1):
            box(bm, (0, ny * (d / 2.0 + 0.05), floor_z + wall_h * f * 0.0 + wall_h / 2),
                (0.26, 0.12, wall_h), taper=0.95)
        for nx in (-1, 1):
            box(bm, (nx * (w / 2.0 + 0.05), 0, floor_z + wall_h / 2),
                (0.12, 0.26, wall_h), taper=0.95)


def spire(bm, w, d, z, tiers, rng, ruin=0, slender=0.80, antefix=True):
    keep = tiers if ruin == 0 else max(1, tiers - rng.randint(1, max(1, tiers - 1)))
    box(bm, (0, 0, z + 0.17), (w + 0.36, d + 0.36, 0.34))            # cornice
    cz, cw, cd = z + 0.34, w * 0.94, d * 0.94
    for i in range(keep):
        th = 0.62 * (0.90 ** i)
        tilt = None
        if ruin and i == keep - 1 and rng.random() < 0.55:
            tilt = (rng.uniform(-0.15, 0.15), rng.uniform(-0.15, 0.15), 0.0)
        box(bm, (0, 0, cz + th / 2), (cw, cd, th), rot=tilt, taper=0.92)
        if antefix and i < 3:
            for sx in (-1, 1):
                for sy in (-1, 1):
                    box(bm, (sx * cw / 2.1, sy * cd / 2.1, cz + th * 0.86),
                        (0.22, 0.22, 0.34), rot=tilt, taper=0.45)
        cz += th
        cw *= slender
        cd *= slender
    if ruin == 0:
        box(bm, (0, 0, cz + 0.34), (cw * 0.7, cd * 0.7, 0.68), taper=0.3)
        cz += 0.68
    return cz


def stairway(bm, floor_z, out_x, out_y, side, rng, ruin=0, width=0.80):
    steps, run = 5, 0.36
    rise = floor_z / steps
    nx, ny = SIDES[side]
    edge = out_y if nx == 0 else out_x
    prof = []
    for i in range(steps + 1):
        u, z = i * run, floor_z - i * rise
        prof.append((u, z))
        if i < steps:
            prof.append((u + run, z))
    prof.append((steps * run, 0.0))
    prof.append((0.0, 0.0))

    def place(u, z, lat):
        dist = edge + u
        return (lat, ny * dist, z) if nx == 0 else (nx * dist, lat, z)

    idx = MAT_INDEX["temple_laterite"]
    a = [bm.verts.new(place(u, z, -width)) for (u, z) in prof]
    b = [bm.verts.new(place(u, z, width)) for (u, z) in prof]
    try:
        bm.faces.new(a).material_index = idx
    except ValueError:
        pass
    try:
        bm.faces.new(list(reversed(b))).material_index = idx
    except ValueError:
        pass
    for i in range(len(a)):
        j = (i + 1) % len(a)
        try:
            bm.faces.new((a[i], a[j], b[j], b[i])).material_index = idx
        except ValueError:
            pass
    flight = steps * run
    pitch = math.atan2(floor_z, flight)
    for s in (-1, 1):
        if ruin >= 2 and rng.random() < 0.45:
            continue
        for k in range(2):
            f = 0.25 + 0.50 * k
            c = place(flight * f, floor_z * (1.0 - f) + 0.22, s * (width + 0.10))
            rot = (pitch if nx == 0 else 0.0, 0.0 if nx == 0 else -pitch, 0.0)
            size = (0.28, flight * 0.52, 0.34) if nx == 0 else (flight * 0.52, 0.28, 0.34)
            box(bm, c, size, rot=rot)
        box(bm, place(flight, 0.30, s * (width + 0.10)), (0.34, 0.34, 0.46), taper=0.6)


def breach(bm, w, d, floor_z, wall_h, side, rng):
    """Collapse a wall to a jagged remnant and spill its blocks outward."""
    nx, ny = SIDES[side]
    span = w if nx == 0 else d
    t = 0.45
    for k in range(3):
        frac = (k - 1) * 0.32
        h = wall_h * rng.uniform(0.20, 0.60)
        if nx == 0:
            box(bm, (frac * span, ny * (d - t) / 2.0, floor_z + h / 2),
                (span * 0.34, t, h), rot=(0, rng.uniform(-0.07, 0.07), 0))
        else:
            box(bm, (nx * (w - t) / 2.0, frac * span, floor_z + h / 2),
                (t, span * 0.34, h), rot=(rng.uniform(-0.07, 0.07), 0, 0))
    for k in range(4):
        s = rng.uniform(0.34, 0.62)
        off = rng.uniform(0.6, 2.1)
        lat = rng.uniform(-span * 0.55, span * 0.55)
        pos = (lat, ny * (d / 2 + off)) if nx == 0 else (nx * (w / 2 + off), lat)
        box(bm, (pos[0], pos[1], s * 0.3), (s, s * rng.uniform(0.7, 1.2), s * 0.6),
            "temple_moss", rot=(rng.uniform(-.4, .4), rng.uniform(-.4, .4), rng.uniform(0, 3.1)))


# ------------------------------------------------------------- the families --
def fam_kalan(bm, rng, ruin, door):
    """Tall slender Cham sanctuary tower - height ~2.4x its base."""
    w = rng.uniform(3.9, 4.6)
    d = w * rng.uniform(0.95, 1.05)
    wall_h = rng.uniform(3.4, 4.0)
    fz, ox, oy = plinth(bm, w, d, rng)
    for s in range(4):
        if ruin >= 2 and s == (door + 2) % 4 and rng.random() < 0.6:
            breach(bm, w, d, fz, wall_h, s, rng)
        else:
            doorway_wall(bm, w, d, fz, wall_h, s, rng, blind=(s != door))
    pilasters(bm, w, d, fz, wall_h, count=1)
    top = spire(bm, w, d, fz + wall_h, rng.randint(6, 7), rng, ruin, slender=0.82)
    stairway(bm, fz, ox, oy, door, rng, ruin)
    return w, d, fz, fz + wall_h


def fam_mandapa(bm, rng, ruin, door):
    """Cella + tower with a long low porch hall on the entrance side -> L silhouette."""
    w = rng.uniform(4.2, 5.0)
    d = w * rng.uniform(0.95, 1.05)
    wall_h = rng.uniform(3.0, 3.4)
    fz, ox, oy = plinth(bm, w, d, rng)
    for s in range(4):
        if ruin >= 2 and s == (door + 2) % 4 and rng.random() < 0.6:
            breach(bm, w, d, fz, wall_h, s, rng)
        else:
            doorway_wall(bm, w, d, fz, wall_h, s, rng, blind=(s != door))
    pilasters(bm, w, d, fz, wall_h)
    top = spire(bm, w, d, fz + wall_h, rng.randint(4, 5), rng, ruin, slender=0.84)
    # the porch: a hall projecting off the doorway face
    nx, ny = SIDES[door]
    plen = rng.uniform(3.2, 4.4)
    pw = w * 0.66
    ph = wall_h * 0.62
    cx = nx * (w / 2 + plen / 2)
    cy = ny * (d / 2 + plen / 2)
    size = (pw, plen, ph) if nx == 0 else (plen, pw, ph)
    if not (ruin >= 3 and rng.random() < 0.5):
        box(bm, (cx, cy, fz + ph / 2), size, taper=0.98)
        rsz = (pw + 0.4, plen + 0.3, 0.30) if nx == 0 else (plen + 0.3, pw + 0.4, 0.30)
        box(bm, (cx, cy, fz + ph + 0.15), rsz)
        for s2 in (-1, 1):     # porch colonettes
            px = cx + (s2 * pw / 2.4 if nx == 0 else nx * plen / 2.6)
            py = cy + (ny * plen / 2.6 if nx == 0 else s2 * pw / 2.4)
            box(bm, (px, py, fz + ph / 2), (0.20, 0.20, ph), taper=0.9)
    stairway(bm, fz, ox + (plen if nx else 0), oy + (plen if not nx else 0), door, rng, ruin)
    return w, d, fz, fz + wall_h


def fam_kosagrha(bm, rng, ruin, door):
    """Fire house: low rectangular hall under a saddle roof. No tower at all."""
    w = rng.uniform(3.4, 4.0)
    d = w * rng.uniform(1.7, 2.2)
    wall_h = rng.uniform(2.7, 3.1)
    fz, ox, oy = plinth(bm, w, d, rng, steps=1)
    for s in range(4):
        if ruin >= 2 and s == (door + 2) % 4 and rng.random() < 0.55:
            breach(bm, w, d, fz, wall_h, s, rng)
        else:
            doorway_wall(bm, w, d, fz, wall_h, s, rng, blind=(s != door))
    pilasters(bm, w, d, fz, wall_h, count=2)
    if not (ruin >= 3 and rng.random() < 0.6):
        box(bm, (0, 0, fz + wall_h + 0.16), (w + 0.5, d + 0.5, 0.32))
        saddle_roof(bm, (0, 0, fz + wall_h + 0.32), (w + 0.3, d + 0.3, 1.15), kick=0.30)
    stairway(bm, fz, ox, oy, door, rng, ruin)
    return w, d, fz, fz + wall_h


def fam_gopura(bm, rng, ruin, door):
    """Gate pavilion: you walk THROUGH it. Aligned openings, wings, squat tower."""
    w = rng.uniform(3.2, 3.8)
    d = w * rng.uniform(0.85, 1.0)
    wall_h = rng.uniform(3.0, 3.5)
    fz, ox, oy = plinth(bm, w, d, rng, steps=1)
    thru = (door, (door + 2) % 4)
    for s in range(4):
        doorway_wall(bm, w, d, fz, wall_h, s, rng, blind=(s not in thru))
    pilasters(bm, w, d, fz, wall_h)
    # flanking wings
    nx, ny = SIDES[(door + 1) % 4]
    for s2 in (-1, 1):
        wl = rng.uniform(2.4, 3.6)
        wh = wall_h * 0.55
        cx = s2 * nx * (w / 2 + wl / 2) if nx else 0.0
        cy = s2 * ny * (d / 2 + wl / 2) if ny else 0.0
        if nx == 0:
            cx = s2 * (w / 2 + wl / 2)
        else:
            cy = s2 * (d / 2 + wl / 2)
        size = (wl, d * 0.8, wh) if nx == 0 else (w * 0.8, wl, wh)
        if ruin >= 2 and rng.random() < 0.5:
            continue
        box(bm, (cx, cy, fz + wh / 2), size, taper=0.97)
        rsz = (wl + 0.3, d * 0.8 + 0.3, 0.26) if nx == 0 else (w * 0.8 + 0.3, wl + 0.3, 0.26)
        box(bm, (cx, cy, fz + wh + 0.13), rsz)
    spire(bm, w, d, fz + wall_h, rng.randint(3, 4), rng, ruin, slender=0.80)
    stairway(bm, fz, ox, oy, door, rng, ruin, width=1.0)
    return w, d, fz, fz + wall_h


def fam_terrace(bm, rng, ruin, door):
    """Temple-mountain: receding terraces, monumental stair, small shrine on top."""
    base = rng.uniform(8.0, 10.0)
    z = 0.0
    cur = base
    for i in range(3):
        h = rng.uniform(0.85, 1.15)
        box(bm, (0, 0, z + h / 2), (cur, cur, h), "temple_laterite", taper=0.95)
        for sx in (-1, 1):     # corner blocks read the terrace edges
            for sy in (-1, 1):
                box(bm, (sx * cur / 2.3, sy * cur / 2.3, z + h + 0.14),
                    (0.5, 0.5, 0.28), "temple_laterite")
        z += h
        cur *= 0.72
    w = cur * 0.9
    d = w
    wall_h = rng.uniform(2.5, 3.0)
    for s in range(4):
        if ruin >= 2 and s == (door + 2) % 4 and rng.random() < 0.6:
            breach(bm, w, d, z, wall_h, s, rng)
        else:
            doorway_wall(bm, w, d, z, wall_h, s, rng, blind=(s != door))
    pilasters(bm, w, d, z, wall_h)
    spire(bm, w, d, z + wall_h, rng.randint(3, 4), rng, ruin, slender=0.82)
    nx, ny = SIDES[door]
    steps = 9
    run, rise = 0.34, z / steps
    for i in range(steps):
        dist = base / 2 + 0.2 + i * run
        c = (0, ny * dist) if nx == 0 else (nx * dist, 0)
        sz = (2.2, run + 0.02, rise) if nx == 0 else (run + 0.02, 2.2, rise)
        box(bm, (c[0], c[1], z - i * rise - rise / 2), sz, "temple_laterite")
    return w, d, z, z + wall_h


FAMILIES = {"kalan": fam_kalan, "mandapa": fam_mandapa, "kosagrha": fam_kosagrha,
            "gopura": fam_gopura, "terrace": fam_terrace}


def build_temple(name, family, seed, ruined):
    rng = random.Random(seed)
    ruin = 0 if not ruined else rng.randint(1, 3)
    door = rng.randint(0, 3)
    bm = bmesh.new()
    w, d, floor_z, top = FAMILIES[family](bm, rng, ruin, door)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.0005)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in ensure_materials():
        me.materials.append(m)
    box_project_uvs(me)
    ob = bpy.data.objects.new(name, me)
    ob["door_dir"] = door
    ob["family"] = family
    ob["cw"], ob["cd"] = w, d
    ob["floor_z"], ob["wall_top"] = floor_z, top
    ob["ruin"] = ruin
    bpy.context.collection.objects.link(ob)
    return ob


def build_statue(name, kind, seed):
    rng = random.Random(seed)
    bm = bmesh.new()
    if kind == "guardian":
        box(bm, (0, 0, 0.14), (0.78, 0.72, 0.28), "temple_laterite")
        box(bm, (0, 0, 0.80), (0.44, 0.36, 1.04), taper=0.86)
        box(bm, (0, 0, 1.42), (0.34, 0.30, 0.32), taper=0.7)
        box(bm, (0, 0, 1.66), (0.20, 0.20, 0.20), taper=0.4)
        for s in (-1, 1):
            box(bm, (s * 0.28, 0.02, 1.00), (0.14, 0.14, 0.68), rot=(0, s * 0.12, 0))
    elif kind == "seated":
        box(bm, (0, 0, 0.13), (1.00, 0.90, 0.26), "temple_laterite")
        box(bm, (0, 0, 0.46), (0.86, 0.70, 0.40), taper=0.8)
        box(bm, (0, 0, 0.86), (0.52, 0.44, 0.60), taper=0.85)
        box(bm, (0, 0, 1.26), (0.32, 0.30, 0.30), taper=0.75)
        box(bm, (0, 0, 1.50), (0.16, 0.16, 0.24), taper=0.3)
    elif kind == "naga":
        # multi-headed serpent - heads ALWAYS an odd number by convention
        box(bm, (0, 0, 0.12), (0.60, 0.90, 0.24), "temple_laterite")
        box(bm, (0, 0.10, 0.55), (0.34, 0.50, 0.70), rot=(-0.22, 0, 0), taper=0.8)
        for i, s in enumerate((-2, -1, 0, 1, 2)):            # five heads
            fan = s * 0.22
            box(bm, (fan, 0.24, 1.02 - abs(s) * 0.07), (0.16, 0.24, 0.36),
                rot=(-0.38, 0, s * 0.20), taper=0.55)
    elif kind == "naga_rail":
        # a length of serpent balustrade - the body rail with a reared head at one end
        box(bm, (0, 0, 0.14), (0.46, 2.60, 0.28), "temple_laterite")
        box(bm, (0, 0, 0.46), (0.34, 2.40, 0.36), taper=0.9)
        for k in range(4):
            box(bm, (0, -1.0 + k * 0.66, 0.70), (0.26, 0.22, 0.22), taper=0.7)
        box(bm, (0, 1.32, 0.86), (0.40, 0.44, 0.80), rot=(-0.3, 0, 0), taper=0.8)
        for s in (-2, -1, 0, 1, 2):
            box(bm, (s * 0.19, 1.50, 1.30 - abs(s) * 0.06), (0.15, 0.22, 0.34),
                rot=(-0.4, 0, s * 0.2), taper=0.55)
    elif kind == "singha":
        # temple lion: seated on haunches flanking the steps, roaring
        box(bm, (0, 0, 0.15), (0.78, 0.86, 0.30), "temple_laterite")
        box(bm, (0, -0.06, 0.62), (0.50, 0.62, 0.64), taper=0.9)      # haunches
        box(bm, (0, 0.20, 1.06), (0.42, 0.34, 0.62), taper=0.88)      # chest
        box(bm, (0, 0.26, 1.48), (0.40, 0.40, 0.34), taper=0.85)      # head
        box(bm, (0, 0.44, 1.40), (0.26, 0.16, 0.20), taper=0.7)       # muzzle, open
        for s in (-1, 1):
            box(bm, (s * 0.24, 0.34, 0.66), (0.14, 0.16, 0.72), taper=0.85)   # forelegs
            box(bm, (s * 0.20, 0.30, 1.62), (0.13, 0.13, 0.16), taper=0.5)    # ears
    elif kind == "garuda":
        # bird-man: legs, torso, outspread wings, beaked head
        box(bm, (0, 0, 0.14), (0.86, 0.72, 0.28), "temple_laterite")
        box(bm, (0, 0, 0.74), (0.42, 0.34, 0.92), taper=0.86)
        box(bm, (0, 0.06, 1.34), (0.32, 0.30, 0.32), taper=0.8)
        box(bm, (0, 0.24, 1.32), (0.14, 0.22, 0.16), taper=0.4)       # beak
        for s in (-1, 1):
            box(bm, (s * 0.52, -0.02, 1.06), (0.72, 0.18, 0.52),
                rot=(0, s * -0.35, 0), taper=0.6)                     # wings
            box(bm, (s * 0.18, 0, 0.30), (0.16, 0.20, 0.44), taper=0.8)
    elif kind == "apsara":
        # celestial dancer in relief on a slab - a wall panel, not a free figure
        box(bm, (0, 0, 0.12), (1.05, 0.40, 0.24), "temple_laterite")
        box(bm, (0, 0, 1.15), (0.95, 0.26, 2.06), taper=0.97)         # the slab
        box(bm, (0, -0.16, 1.10), (0.30, 0.14, 1.10), taper=0.85)     # body in relief
        box(bm, (0, -0.18, 1.78), (0.24, 0.13, 0.26), taper=0.8)      # head
        box(bm, (0, -0.18, 1.98), (0.30, 0.12, 0.22), taper=0.5)      # headdress
        for s in (-1, 1):
            box(bm, (s * 0.26, -0.15, 1.34), (0.14, 0.11, 0.52),
                rot=(0, 0, s * 0.5), taper=0.7)                       # arms
    elif kind == "stele":
        # inscribed foundation stone, often leaning after centuries
        box(bm, (0, 0, 0.13), (0.92, 0.72, 0.26), "temple_laterite")
        box(bm, (0, 0, 0.94), (0.66, 0.24, 1.36), rot=(rng.uniform(-0.12, 0.12), 0, 0),
            taper=0.96)
        box(bm, (0, 0, 1.66), (0.66, 0.24, 0.18), taper=0.6)
    elif kind == "stupa":
        # bell-form reliquary on a square base
        box(bm, (0, 0, 0.16), (1.10, 1.10, 0.32), "temple_laterite")
        box(bm, (0, 0, 0.50), (0.86, 0.86, 0.36), taper=0.88)
        box(bm, (0, 0, 0.92), (0.68, 0.68, 0.48), taper=0.78)
        box(bm, (0, 0, 1.34), (0.48, 0.48, 0.40), taper=0.7)
        box(bm, (0, 0, 1.70), (0.30, 0.30, 0.34), taper=0.55)
        box(bm, (0, 0, 2.02), (0.14, 0.14, 0.38), taper=0.3)          # spire
    elif kind == "altar":
        # offering table with a pair of votive lamps
        box(bm, (0, 0, 0.10), (1.30, 0.86, 0.20), "temple_laterite")
        for sx in (-1, 1):
            for sy in (-1, 1):
                box(bm, (sx * 0.50, sy * 0.30, 0.36), (0.16, 0.16, 0.32))

        box(bm, (0, 0, 0.60), (1.36, 0.92, 0.16))
        for sx in (-1, 1):
            box(bm, (sx * 0.42, 0, 0.76), (0.22, 0.22, 0.16), taper=0.7)
    else:
        box(bm, (0, 0, 0.11), (0.86, 0.86, 0.22), "temple_laterite")
        box(bm, (0, 0, 0.32), (0.62, 0.62, 0.20), taper=0.92)
        box(bm, (0, 0, 0.66), (0.30, 0.30, 0.48), taper=0.9)
    if rng.random() < 0.5:
        box(bm, (rng.uniform(-.4, .4), rng.uniform(-.4, .4), 0.08), (0.3, 0.3, 0.16),
            "temple_moss", rot=(0, 0, rng.uniform(0, 3.0)))
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.0005)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in ensure_materials():
        me.materials.append(m)
    box_project_uvs(me, tile=1.1)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob


VEG_DIR = r"C:\Users\caleb\RECONgame\assets\world\vegetation"
VEG_LIB = {}


def veg_source(name):
    """Import a vegetation GLB once and keep it off-camera as a template."""
    if name in VEG_LIB:
        return VEG_LIB[name]
    before = {o.name for o in bpy.data.objects}
    try:
        bpy.ops.import_scene.gltf(filepath=os.path.join(VEG_DIR, name + ".glb"))
    except Exception as e:
        print("   veg import failed:", name, e)
        VEG_LIB[name] = None
        return None
    new = [bpy.data.objects[n] for n in {o.name for o in bpy.data.objects} - before]
    meshes = [o for o in new if o.type == 'MESH']
    for o in new:
        if o not in meshes:
            bpy.data.objects.remove(o, do_unlink=True)
    if not meshes:
        VEG_LIB[name] = None
        return None
    src = meshes[0]
    src.name = "VEGSRC_" + name
    src.hide_render = True
    src.location = (0, 0, -500)          # parked far away; never exported
    VEG_LIB[name] = src
    return src


def veg_bounds(src):
    """Local-space bounds of a source plant, so placement is measured, never guessed."""
    pts = [v.co for v in src.data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    rad = max(max(abs(lo[0]), abs(hi[0])), max(abs(lo[1]), abs(hi[1])))
    return lo[2], hi[2], rad


CANOPY = ["broadleaf_a", "broadleaf_b", "broadleaf_c"]
UNDER = ["fern_a", "fern_b", "fern_c", "bush_a", "bush_b", "bush_c"]
GROUND = ["moss_a", "moss_b", "grass_tuft_a", "grass_tuft_b", "grass_tuft_c"]
# Pivot decides the anchor: hangers run 0..-len (hang from the top), climbers 0..+len.
HANGERS = ["vine_a", "vine_b", "liana_a", "liana_b"]
CLIMBERS = ["trunk_vine_a", "trunk_vine_b"]
CELLA = ["palm_sapling_a", "palm_sapling_b", "banana_a", "bamboo_a"]
FLOOR_DEBRIS = ["fallen_log_a", "fallen_log_b", "tree_stump"]


def face_point(side, w, d, out, lat):
    """A point `out` metres off the given cardinal face, `lat` along it."""
    nx, ny = SIDES[side]
    if nx:
        return (nx * (w / 2.0 + out), lat)
    return (lat, ny * (d / 2.0 + out))


def bake_vegetation(name, w, d, floor_z, top, ruin, door, rng):
    """Dress the temple with REAL jungle meshes from assets/world/vegetation.

    Copied in as separate objects so they keep their own alpha-card materials and ride
    inside the temple's GLB. They carry NO '-col' suffix, so Godot gives them no
    collision - you walk through the ferns and into the stone. Canopy trunks are the
    exception and are handed back for the collision twin.

    Returns (objects, trunks) where trunks is [(x, y, radius, height)] in temple space.
    """
    out, trunks = [], []
    half = max(w, d) * 0.5

    def drop(src_name, pos, rotz, scale, tilt=0.0):
        src = veg_source(src_name)
        if src is None:
            return None
        cp = src.copy()
        cp.data = src.data.copy()
        cp.name = f"{name}_veg_{len(out):02d}_{src_name}"
        cp.hide_render = False
        cp.location = pos
        cp.rotation_euler = (math.cos(rotz) * tilt, math.sin(rotz) * tilt, rotz)
        cp.scale = (scale, scale, scale)
        bpy.context.collection.objects.link(cp)
        out.append(cp)
        return cp

    def fit(src_name, target_h):
        """Scale that makes a plant `target_h` tall, clamped so it stays plausible."""
        src = veg_source(src_name)
        if src is None:
            return None, 1.0
        lo, hi, _ = veg_bounds(src)
        span = hi - lo
        if span <= 0.01:
            return src, 1.0
        return src, max(0.28, min(2.0, target_h / span))

    def hang(side, lat, from_z, want):
        """A vine off the wall head, hugging the face, never reaching past the plinth."""
        nm = rng.choice(HANGERS)
        src, s = fit(nm, want)
        if src is None:
            return
        _, _, rad = veg_bounds(src)
        x, y = face_point(side, w, d, rad * s * 0.55, lat)
        drop(nm, (x, y, from_z), rng.uniform(0, math.tau), s)

    # --- the tree that took the temple: canopy at grade, overhanging the stone -------
    if ruin:
        side = rng.choice([s for s in SIDES if s != door])
        nm = rng.choice(CANOPY if ruin >= 2 else CANOPY[:2])
        src, s = fit(nm, top + rng.uniform(2.2, 5.0))
        if src is not None:
            _, _, rad = veg_bounds(src)
            lat = rng.uniform(-0.55, 0.55) * (d if SIDES[side][0] else w) * 0.5
            # canopy over the roof, trunk clear of the plinth's 0.85m skirt
            x, y = face_point(side, w, d, max(1.0, rad * s * 0.42 + 0.35), lat)
            drop(nm, (x, y, 0.0), rng.uniform(0, math.tau), s,
                 tilt=rng.uniform(0.03, 0.10))
            trunks.append((x, y, 0.34 * s + 0.10, top * 0.9))
            for _ in range(2):             # its vines pouring down that same face
                hang(side, lat + rng.uniform(-1.2, 1.2), top - rng.uniform(0.0, 0.5),
                     (top - floor_z) * rng.uniform(0.45, 0.9))

    # --- the strangler grip: climbers up one corner, vines off the head above it -----
    if ruin or rng.random() < 0.4:
        side = rng.choice([s for s in SIDES if s != door])
        base_lat = rng.uniform(-0.7, 0.7) * (d if SIDES[side][0] else w) * 0.5
        for _ in range(rng.randint(2, 3)):
            nm = rng.choice(CLIMBERS)
            src, s = fit(nm, top * rng.uniform(0.75, 1.02))
            if src is None:
                continue
            _, _, rad = veg_bounds(src)
            lat = base_lat + rng.uniform(-0.6, 0.6)
            x, y = face_point(side, w, d, rad * s * 0.5, lat)
            drop(nm, (x, y, floor_z), rng.uniform(0, math.tau), s,
                 tilt=rng.uniform(0.0, 0.08))
        for _ in range(rng.randint(1, 2)):
            hang(side, base_lat + rng.uniform(-0.9, 0.9), top - rng.uniform(0.0, 0.6),
                 (top - floor_z) * rng.uniform(0.4, 0.85))

    # --- undergrowth crowding the base ----------------------------------------------
    for _ in range(rng.randint(3, 5) if ruin else rng.randint(2, 3)):
        a = rng.uniform(0, math.tau)
        r = half + rng.uniform(0.5, 2.4)
        drop(rng.choice(UNDER), (math.cos(a) * r, math.sin(a) * r, 0.0),
             rng.uniform(0, math.tau), rng.uniform(0.7, 1.2))

    # --- growth taking the plinth and terraces ---------------------------------------
    # Sampled on the plinth RECTANGLE. A radial sample walks off the narrow axis of a
    # long temple and leaves the plant standing on air.
    for _ in range(rng.randint(1, 3)):
        drop(rng.choice(UNDER + GROUND),
             (rng.uniform(-1, 1) * (w / 2.0 + 0.55), rng.uniform(-1, 1) * (d / 2.0 + 0.55),
              floor_z), rng.uniform(0, math.tau), rng.uniform(0.5, 0.9))

    # --- what got in through the broken roof, and what fell in the yard ---------------
    if ruin >= 2:
        nm = rng.choice(CELLA)
        src, s = fit(nm, rng.uniform(1.4, 2.6))
        if src is not None:
            drop(nm, (rng.uniform(-w * 0.15, w * 0.15), rng.uniform(-d * 0.15, d * 0.15),
                      floor_z), rng.uniform(0, math.tau), s)
    if ruin:
        a = rng.uniform(0, math.tau)
        r = half + rng.uniform(0.8, 2.6)
        drop(rng.choice(FLOOR_DEBRIS), (math.cos(a) * r, math.sin(a) * r, 0.0),
             rng.uniform(0, math.tau), rng.uniform(0.8, 1.2))
    return out, trunks


def make_collision(ob, name, trunks):
    """A '-col' twin carrying the stonework plus a stub for every canopy trunk.

    Godot builds trimesh collision from -col nodes (68 other GLBs in this project use
    the same convention). Leaves get no collision so you can push through them; a tree
    you can walk through is the failure this stub prevents. The cella stays hollow.
    """
    me = ob.data.copy()
    if trunks:
        bm = bmesh.new()
        bm.from_mesh(me)
        for x, y, rad, h in trunks:
            bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=rad,
                                  radius2=rad * 0.8, depth=h,
                                  matrix=Matrix.Translation((x, y, h / 2.0)))
        bm.to_mesh(me)
        bm.free()
    col = bpy.data.objects.new(name + "-col", me)
    bpy.context.collection.objects.link(col)
    return col


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def measure(ob):
    pts = [ob.matrix_world @ v.co for v in ob.data.vertices]
    return ([min(p[i] for p in pts) for i in range(3)],
            [max(p[i] for p in pts) for i in range(3)])


def export(obs, path):
    if not isinstance(obs, (list, tuple)):
        obs = [obs]
    for o in bpy.data.objects:
        o.select_set(False)
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True, export_animations=False,
                              export_materials='EXPORT',
                              export_draco_mesh_compression_enable=False)


# 10 ruined + 4 intact, spread across the five families
PLAN = [("prasat_ruin_01", "kalan", True), ("prasat_ruin_02", "kalan", True),
        ("prasat_ruin_03", "mandapa", True), ("prasat_ruin_04", "mandapa", True),
        ("prasat_ruin_05", "kosagrha", True), ("prasat_ruin_06", "kosagrha", True),
        ("prasat_ruin_07", "gopura", True), ("prasat_ruin_08", "gopura", True),
        ("prasat_ruin_09", "terrace", True), ("prasat_ruin_10", "terrace", True),
        ("prasat_intact_01", "kalan", False), ("prasat_intact_02", "mandapa", False),
        ("prasat_intact_03", "kosagrha", False), ("prasat_intact_04", "terrace", False)]


def main():
    bpy.ops.wm.read_homefile(use_empty=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    manifest, rows = {}, []
    for i, (n, fam, ruined) in enumerate(PLAN):
        rows.append((n, build_temple(n, fam, 3300 + i * 37, ruined),
                     "ruined" if ruined else "intact", fam))
    for kind, cnt in (("guardian", 2), ("seated", 1), ("naga", 1), ("lingam", 1),
                      ("singha", 2), ("garuda", 1), ("apsara", 2), ("stele", 1),
                      ("stupa", 1), ("altar", 1), ("naga_rail", 1)):
        for j in range(cnt):
            n = f"temple_statue_{kind}" + (f"_{j+1:02d}" if cnt > 1 else "")
            rows.append((n, build_statue(n, kind, 700 + hash(kind) % 100 + j), "statue", "-"))

    print(f"{'name':<26}{'family':<10}{'tris':>6}{'verts':>7}   size (m)")
    for n, ob, kind, fam in rows:
        mn, _ = measure(ob)
        for v in ob.data.vertices:
            v.co.z -= mn[2]
        mn, mx = measure(ob)
        t = tri_count(ob)
        size = [round(mx[k] - mn[k], 2) for k in range(3)]
        over = "  OVER" if t > BUDGET else ""
        group = [ob]
        if kind != "statue":
            plants, trunks = bake_vegetation(n, float(ob["cw"]), float(ob["cd"]),
                                             float(ob["floor_z"]), float(ob["wall_top"]),
                                             int(ob["ruin"]), int(ob["door_dir"]),
                                             random.Random(hash(n) % 99991))
            group.append(make_collision(ob, n, trunks))
            group += plants
            veg_n = len(plants)
            veg_t = sum(tri_count(p) for p in plants)
        else:
            veg_n = veg_t = 0
        print(f"{n:<26}{fam:<10}{t:>6}{len(ob.data.vertices):>7}   {size}"
              f"  veg={veg_n} (+{veg_t} tris){over}")
        export(group, os.path.join(OUT_DIR, n + ".glb"))
        manifest[n] = {"kind": kind, "family": fam, "tris": t, "veg": veg_n,
                       "veg_tris": veg_t,
                       "verts": len(ob.data.vertices), "size": size,
                       "footprint": [size[0], size[1]], "height": size[2],
                       "door_dir": ob.get("door_dir", -1)}
    json.dump(manifest, open(os.path.join(OUT_DIR, "temple_set.json"), "w"), indent=1)
    print(f"\n{len(manifest)} models, {sum(m['tris'] for m in manifest.values())} tris -> {OUT_DIR}")


main()
