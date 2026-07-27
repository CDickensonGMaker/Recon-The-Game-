"""Generate the Vietnamese village set for RECON: distinct rural building TYPES.

    python tools/gen_village_textures.py     (once - writes tex/)
    blender -b -P tools/gen_village.py

Replaces nine RTS-derived models built for a camera 50m up - a 15x11m communal house
made of 160 triangles, 1024x1024 photo maps with temp-file names. In an FPS you walk
into these, so they are rebuilt at walking distance and made ENTERABLE.

Variety comes from BUILDING TYPES, not from varying numbers on one box - the same
lesson gen_temples.py learned. Rural lowland Vietnam, 1960s:

  nha_tranh   the basic thatch house. LOW walls under a huge deep hipped roof carried
              almost to the ground. The roof is the building; walls barely show.
  nha_san     stilt house. Deck up 1.5-2m on posts, notched-log ladder, open beneath -
              that dark under-floor space is cover you can crawl into.
  nha_ruong   three-bay timber frame with a fired-TILE roof and masonry footing. Reads
              wealthier because the roof MATERIAL differs, not because it is bigger.
  bo_lua      rice granary. Tiny deck on four staddle posts with disc rat-guards under
              a tall roof - unmistakable silhouette at any range.
  dinh        communal house. The biggest roof in the village, strongly upswept tiled
              corners over an open colonnade on a raised platform.
  chua        pagoda shrine. Receding tiled tiers over a small cella, altar out front.
  plus the lived-in clutter: lean-to kitchen, buffalo shed, pigsty, drying rack,
  bamboo hedge, village gate, ancestor tomb.

THREE CONTRACTS THIS SET HONOURS (all pre-existing - none invented here):

  ENTERABLE   doorways are >= DOOR_W x DOOR_H, clear of the player capsule (r=0.4,
              h=1.8, scenes/player/player.tscn). Interiors stay HOLLOW and the '-col'
              twin carries walls only, so trimesh collision lets you walk in.
  work_*      empties named work_<type> carry a work_type custom property. This is the
              contract site_planner._collect_stations() already walks (:454-465) - it
              only ran on props before, so buildings never offered a station.
  prop_*      empties named prop_<slot> carry a prop_class custom property naming what
              belongs there. Interior props anchor to these instead of being scattered
              into radial annuli, which is why village dressing floated free of the
              buildings it was meant to furnish.

ORIENTATION: in Godot an empty's LOCAL +Z is the facing direction (seat_system.gd:9).
Godot local +Z is Blender local -Y (measured, make_huey_interior.py:22-23), so a marker
meant to look along world angle `a` gets rotation_euler.z = a + 90 deg. Do not introduce
a second convention, and do not "fix" that 90 by eye.
"""
import bpy, bmesh, math, random, os, json
from mathutils import Vector, Euler, Matrix

OUT_DIR = r"C:\Users\caleb\RECONgame\assets\world\building models\structures\village"
TEX_DIR = os.path.join(OUT_DIR, "tex")
VEG_DIR = r"C:\Users\caleb\RECONgame\assets\world\vegetation"
BUDGET = 800

# Player capsule r=0.4 h=1.8 (scenes/player/player.tscn:9-11). A door you have to
# crouch through is a door players think is scenery, so stand-up clearance is the rule.
DOOR_W, DOOR_H = 1.05, 1.95

MATS = {
    "vil_thatch":  ((0.59, 0.49, 0.29, 1.0), 0.95),
    "vil_bamboo":  ((0.53, 0.56, 0.33, 1.0), 0.82),
    "vil_wattle":  ((0.57, 0.48, 0.38, 1.0), 0.94),
    "vil_timber":  ((0.41, 0.31, 0.20, 1.0), 0.88),
    "vil_tile":    ((0.54, 0.32, 0.24, 1.0), 0.86),
    "vil_masonry": ((0.50, 0.36, 0.28, 1.0), 0.93),
    "vil_char":    ((0.17, 0.15, 0.14, 1.0), 0.97),
}
MAT_INDEX = {n: i for i, n in enumerate(MATS)}
SIDES = {0: (0, -1), 1: (1, 0), 2: (0, 1), 3: (-1, 0)}


def ensure_materials():
    mats = []
    for name, (col, rough) in MATS.items():
        m = bpy.data.materials.get(name)
        if m is None:
            m = bpy.data.materials.new(name)
            m.use_nodes = True
            nt = m.node_tree
            bsdf = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
            if bsdf:
                bsdf.inputs["Base Color"].default_value = col
                bsdf.inputs["Roughness"].default_value = rough
                path = os.path.join(TEX_DIR, name + ".png")
                if os.path.exists(path):
                    img = bpy.data.images.load(path, check_existing=True)
                    tex = nt.nodes.new("ShaderNodeTexImage")
                    tex.image = img
                    tex.location = (-420, 220)
                    tex.interpolation = 'Closest'
                    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        m.diffuse_color = col
        mats.append(m)
    return mats


def box_project_uvs(mesh, tile=1.8):
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


def box(bm, centre, size, mat="vil_timber", rot=None, taper=1.0):
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


def hip_roof(bm, centre, w, d, h, mat, ridge_frac=0.34, sag=0.0):
    """Four-sided hipped roof - the thatch read. A gable would be the wrong country.

    ridge_frac is the ridge length as a fraction of depth; 0 gives a pyramid (bo_lua),
    0.34 the short ridge of a hut, 0.7 the long ridge of a hall.
    """
    cx, cy, cz = centre
    hw, hd = w / 2.0, d / 2.0
    rl = hd * ridge_frac
    idx = MAT_INDEX[mat]
    e = [bm.verts.new(p) for p in [(cx - hw, cy - hd, cz), (cx + hw, cy - hd, cz),
                                   (cx + hw, cy + hd, cz), (cx - hw, cy + hd, cz)]]
    top = cz + h
    r0 = bm.verts.new((cx, cy - rl, top - sag))
    r1 = bm.verts.new((cx, cy + rl, top - sag))
    for f in [(e[0], e[1], r0), (e[2], e[3], r1),
              (e[1], e[2], r1, r0), (e[3], e[0], r0, r1)]:
        try:
            bm.faces.new(f).material_index = idx
        except ValueError:
            pass


def upswept_roof(bm, centre, w, d, h, mat, kick=0.75):
    """The dinh/chua roof: heavy tile, ridge sagging at mid-span, corners thrown UP.

    That upswept corner is the whole silhouette. A straight-sloped hip reads as a barn.
    """
    cx, cy, cz = centre
    hw, hd = w / 2.0, d / 2.0
    idx = MAT_INDEX[mat]
    SEG = 6
    rows = []
    for i in range(SEG + 1):
        t = -1.0 + 2.0 * i / SEG
        y = cy + t * hd
        flare = 1.0 + 0.22 * (abs(t) ** 2)
        eave = cz + kick * (abs(t) ** 2.4)
        ridge = cz + h * (0.88 + 0.30 * (abs(t) ** 2.3))
        rows.append((bm.verts.new((cx - hw * flare, y, eave)),
                     bm.verts.new((cx, y, ridge)),
                     bm.verts.new((cx + hw * flare, y, eave))))
    for i in range(SEG):
        a, b = rows[i], rows[i + 1]
        for p, q in ((0, 1), (1, 2)):
            try:
                bm.faces.new((a[p], a[q], b[q], b[p])).material_index = idx
            except ValueError:
                pass
    for r in (rows[0], rows[-1]):
        try:
            bm.faces.new(r).material_index = idx
        except ValueError:
            pass


def wall_run(bm, w, d, z0, h, side, mat, door=False, thick=0.16):
    """One wall face. door=True leaves a DOOR_W x DOOR_H opening you can walk through."""
    nx, ny = SIDES[side]
    span = d if nx else w
    off = (w / 2.0 if nx else d / 2.0)
    cx = nx * off
    cy = ny * off
    if not door:
        box(bm, (cx, cy, z0 + h / 2.0),
            (thick, span, h) if nx else (span, thick, h), mat)
        return
    side_w = (span - DOOR_W) / 2.0
    for s in (-1.0, 1.0):
        c = s * (DOOR_W / 2.0 + side_w / 2.0)
        box(bm, (cx, cy + c, z0 + h / 2.0) if nx else (cx + c, cy, z0 + h / 2.0),
            (thick, side_w, h) if nx else (side_w, thick, h), mat)
    if h > DOOR_H:                                 # lintel over the opening
        box(bm, (cx, cy, z0 + DOOR_H + (h - DOOR_H) / 2.0),
            (thick, DOOR_W, h - DOOR_H) if nx else (DOOR_W, thick, h - DOOR_H), mat)


def posts(bm, w, d, z0, h, mat, n=3, r=0.11, door=None):
    """Corner and intermediate posts - a wall plane with no frame reads as cardboard.

    door=<side> drops any post standing in that side's opening. The intermediate post
    lands on the wall midpoint, which is exactly where wall_run() leaves the door gap.
    """
    dx = dy = None
    if door is not None:
        nx, ny = SIDES[door]
        dx, dy = nx * w / 2.0, ny * d / 2.0
    for i in range(n):
        for j in range(n):
            if 0 < i < n - 1 and 0 < j < n - 1:
                continue
            x = -w / 2.0 + w * i / float(n - 1)
            y = -d / 2.0 + d * j / float(n - 1)
            if dx is not None and math.hypot(x - dx, y - dy) < DOOR_W * 0.72:
                continue
            box(bm, (x, y, z0 + h / 2.0), (r * 2, r * 2, h), mat)


def rafters(bm, w, d, z, mat, n=7, out=0.22, r=0.06):
    """Exposed rafter ends poking out under the eave, all four sides.

    This is the single detail that separates a built roof from an extruded prism at
    walking distance - you read the repetition long before you read the thatch.
    """
    for i in range(n):
        f = -0.5 + i / float(n - 1)
        box(bm, (w * f, -(d / 2.0 + out * 0.5), z), (r * 2, out * 2.4, r * 2), mat)
        box(bm, (w * f, (d / 2.0 + out * 0.5), z), (r * 2, out * 2.4, r * 2), mat)
    for i in range(max(3, n - 3)):
        f = -0.5 + i / float(max(3, n - 3) - 1)
        box(bm, (-(w / 2.0 + out * 0.5), d * f, z), (out * 2.4, r * 2, r * 2), mat)
        box(bm, ((w / 2.0 + out * 0.5), d * f, z), (out * 2.4, r * 2, r * 2), mat)


def battens(bm, w, d, z0, h, side, mat, n=3, t=0.05):
    """Horizontal battens strapping a wattle or bamboo panel to its frame."""
    nx, ny = SIDES[side]
    span = (d if nx else w) * 0.96
    off = (w / 2.0 if nx else d / 2.0) + 0.09
    for i in range(n):
        z = z0 + h * (i + 0.6) / (n + 0.4)
        box(bm, (nx * off, ny * off, z),
            (t * 2, span, t * 2) if nx else (span, t * 2, t * 2), mat)


def ridge_cap(bm, w, d, z, mat, ridge_frac=0.34, r=0.11):
    """Capping bundle along the ridge, with the stubby finials at each end."""
    ln = d * ridge_frac * 2.0 + 0.3
    box(bm, (0, 0, z), (r * 2.4, ln, r * 2), mat)
    for s in (-1, 1):
        box(bm, (0, s * ln / 2.0, z + 0.06), (r * 2.0, r * 2.0, r * 3.2), mat, taper=0.4)


def door_frame(bm, w, d, z0, side, mat, h=None):
    """Jambs, lintel and a raised threshold - reads as a door, not a hole."""
    h = h or DOOR_H
    nx, ny = SIDES[side]
    off = (w / 2.0 if nx else d / 2.0)
    cx, cy = nx * off, ny * off
    for s in (-1.0, 1.0):
        c = s * (DOOR_W / 2.0 + 0.06)
        box(bm, (cx, cy + c, z0 + h / 2.0) if nx else (cx + c, cy, z0 + h / 2.0),
            (0.22, 0.12, h) if nx else (0.12, 0.22, h), mat)
    box(bm, (cx, cy, z0 + h + 0.07), (0.24, DOOR_W + 0.24, 0.14) if nx
        else (DOOR_W + 0.24, 0.24, 0.14), mat)
    box(bm, (cx, cy, z0 + 0.04), (0.26, DOOR_W, 0.08) if nx
        else (DOOR_W, 0.26, 0.08), mat)


def braces(bm, w, d, z_top, mat, r=0.05):
    """Diagonal knee braces on the stilts - a post grid with no bracing reads as pipes."""
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(bm, (sx * w * 0.34, sy * d * 0.36, z_top * 0.72),
                (w * 0.30, r * 2, r * 2), mat, rot=(0, sx * 0.55, 0))


def beam_between(bm, p0, p1, thick, mat, rng=None):
    """A beam spanning two explicit points - so a fallen rafter starts at the wall head
    it came off and ends where it hit the ground, instead of floating at a random pitch."""
    dx, dy, dz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
    ln = math.sqrt(dx * dx + dy * dy + dz * dz)
    if ln < 0.05:
        return
    yaw = math.atan2(dy, dx)
    pitch = -math.asin(max(-1.0, min(1.0, dz / ln)))
    box(bm, ((p0[0] + p1[0]) / 2.0, (p0[1] + p1[1]) / 2.0, (p0[2] + p1[2]) / 2.0),
        (ln, thick, thick), mat, rot=(0, pitch, yaw))


def rubble_mound(bm, x, y, z, r, rng, mat="vil_char", n=4):
    """A heap of collapse debris. Stacked flattened slabs, biggest at the bottom -
    a beam end with nothing under it reads as staged, not fallen."""
    for i in range(n):
        f = 1.0 - i / float(n + 1)
        rr = r * f * rng.uniform(0.75, 1.1)
        box(bm, (x + rng.uniform(-r, r) * 0.28, y + rng.uniform(-r, r) * 0.28,
                 z + 0.055 + i * 0.10),
            (rr * 2.0, rr * 1.5 * rng.uniform(0.7, 1.2), 0.13), mat,
            rot=(rng.uniform(-.12, .12), rng.uniform(-.12, .12), rng.uniform(0, math.tau)))


def burned_frame(bm, w, d, z0, wall_h, rng, door, deck=0.0):
    """What a burned house leaves standing: a charred skeleton, not a pile of sticks.

    Fire takes the thatch and the wattle infill first; the hardwood frame chars and
    stays up. Keeping the posts full height and one ragged wall preserves the
    silhouette - a husk you recognise as a house from 60m and can still take cover in.
    """
    top = z0 + wall_h
    for i in range(3):                                   # wall-head plate fragments
        if rng.random() < 0.45:
            continue
        s2 = rng.choice([0, 1, 2, 3])
        nx, ny = SIDES[s2]
        span = (d if nx else w) * rng.uniform(0.35, 0.8)
        box(bm, (nx * w / 2.0, ny * d / 2.0, top - rng.uniform(0.0, 0.25)),
            (0.13, span, 0.13) if nx else (span, 0.13, 0.13), "vil_char")
    for s2 in range(4):                                  # one or two ragged part-walls
        if s2 == door or rng.random() < 0.5:
            continue
        h = wall_h * rng.uniform(0.35, 0.62)
        nx, ny = SIDES[s2]
        span = (d if nx else w) * rng.uniform(0.5, 0.9)
        box(bm, (nx * w / 2.0, ny * d / 2.0, z0 + h / 2.0),
            (0.14, span, h) if nx else (span, 0.14, h), "vil_char")
    floor = z0 + deck
    # The collapse heap FIRST, so the beams have something to lie across.
    rubble_mound(bm, rng.uniform(-w * 0.16, w * 0.16), rng.uniform(-d * 0.16, d * 0.16),
                 floor, min(w, d) * 0.36, rng, n=5)
    for _ in range(rng.randint(2, 3)):
        rubble_mound(bm, rng.uniform(-w * 0.34, w * 0.34), rng.uniform(-d * 0.34, d * 0.34),
                     floor, min(w, d) * rng.uniform(0.14, 0.24), rng, n=3)
    for _ in range(rng.randint(4, 6)):                   # rafters fallen wall-head -> heap
        s2 = rng.randint(0, 3)
        nx, ny = SIDES[s2]
        lat = rng.uniform(-0.55, 0.55)
        head = (nx * w / 2.0 + (lat * w * 0.5 if nx == 0 else 0.0),
                ny * d / 2.0 + (lat * d * 0.5 if ny == 0 else 0.0),
                floor + wall_h * rng.uniform(0.72, 1.0))
        # the low end lands ON the heap, not on bare dirt
        rest = (rng.uniform(-w * 0.24, w * 0.24), rng.uniform(-d * 0.24, d * 0.24),
                floor + rng.uniform(0.28, 0.55))
        beam_between(bm, head, rest, 0.13, "vil_char", rng)
        rubble_mound(bm, rest[0], rest[1], floor, rng.uniform(0.35, 0.6), rng, n=2)
    for _ in range(rng.randint(3, 4)):                   # scorched thatch spilled outward
        a = rng.uniform(0, math.tau)
        r = max(w, d) * rng.uniform(0.45, 0.62)
        box(bm, (math.cos(a) * r, math.sin(a) * r, z0 + 0.05),
            (rng.uniform(0.8, 1.5), rng.uniform(0.6, 1.2), 0.10), "vil_char",
            rot=(rng.uniform(-.1, .1), rng.uniform(-.1, .1), rng.uniform(0, math.tau)))


def ladder(bm, x, y, z_top, yaw, mat):
    """Notched-log ladder up to a stilt deck. Built as a shallow ramp so it is
    actually climbable - a rung ladder is scenery the player bounces off."""
    run = z_top * 1.5
    steps = max(3, int(z_top / 0.28))
    for i in range(steps):
        f = (i + 0.5) / steps
        bx = x + math.cos(yaw) * run * (1.0 - f)
        by = y + math.sin(yaw) * run * (1.0 - f)
        box(bm, (bx, by, z_top * f), (0.62, 0.62, 0.10), mat, rot=(0, 0, yaw))


# ------------------------------------------------------------------- markers --
MARKERS = []


def marker(name, pos, face=0.0, **props):
    """An empty the game reads by name. `face` is the world-XY direction ANGLE it
    should look along (atan2(dy, dx)), not a Blender euler - build_markers converts."""
    MARKERS.append({"name": name, "pos": pos, "face": face, "props": props})


## Godot local +Z == Blender local -Y (measured, tools/make_huey_interior.py:22-23), and
## seat_system.gd:9 makes local +Z the facing axis. Blender local -Y under rotation_euler
## (0,0,t) points at (sin t, -cos t), so a marker meant to face (cos a, sin a) needs
## t = a + 90 deg. Getting this wrong silently aims every prop and station sideways.
def _face_to_euler_z(a):
    return a + math.pi / 2.0


def build_markers(parent, name, dz=0.0):
    """dz matches the mesh's sit-on-zero shift in main(); markers must ride with it."""
    out = []
    for m in MARKERS:
        e = bpy.data.objects.new(m["name"], None)
        e.empty_display_type = 'ARROWS'
        e.empty_display_size = 0.35
        e.location = (m["pos"][0], m["pos"][1], m["pos"][2] + dz)
        e.rotation_euler = (0.0, 0.0, _face_to_euler_z(m["face"]))
        for k, v in m["props"].items():
            e[k] = v
        e.parent = parent
        bpy.context.collection.objects.link(e)
        out.append(e)
    return out


# ------------------------------------------------------------------ families --
def fam_nha_tranh(bm, rng, dmg):
    """Thatch house: LOW walls, huge deep hipped roof down to head height."""
    w = rng.uniform(4.6, 6.2)
    d = rng.uniform(3.6, 4.8)
    wall_h = rng.uniform(1.75, 2.05)
    mat_w = "vil_char" if dmg >= 2 else "vil_wattle"
    mat_r = "vil_char" if dmg >= 2 else "vil_thatch"
    door = rng.randint(0, 3)
    wood = "vil_char" if dmg >= 2 else "vil_timber"
    box(bm, (0, 0, 0.06), (w + 0.5, d + 0.5, 0.12), "vil_masonry")     # packed earth pad
    posts(bm, w, d, 0.0, wall_h + 0.1, wood, n=3, door=door)
    for s in range(4):
        if dmg >= 2 and s == (door + 2) % 4:
            continue                                                    # burned-out wall
        wall_run(bm, w, d, 0.12, wall_h, s, mat_w, door=(s == door))
        if dmg < 2 and s != door:
            battens(bm, w, d, 0.12, wall_h, s, "vil_bamboo", n=3)
    if dmg < 2:
        door_frame(bm, w, d, 0.12, door, "vil_timber")
        rh = rng.uniform(1.5, 1.9)
        # the roof IS the building: 1.4x overhang, eaves carried down to ~1.3m
        hip_roof(bm, (0, 0, wall_h + 0.12), w * 1.34, d * 1.44, rh, mat_r,
                 ridge_frac=0.34, sag=0.12 * dmg)
        rafters(bm, w * 1.34, d * 1.44, wall_h + 0.16, "vil_timber", n=7)
        ridge_cap(bm, w, d * 1.44, wall_h + 0.12 + rh - 0.12 * dmg, mat_r)
        if dmg == 1:
            for _ in range(3):                                          # shell holes
                box(bm, (rng.uniform(-w / 3, w / 3), rng.uniform(-d / 3, d / 3),
                         wall_h + rng.uniform(0.5, 1.3)),
                    (rng.uniform(0.5, 0.9),) * 2 + (0.3,), "vil_char",
                    rot=(rng.uniform(-.4, .4), rng.uniform(-.4, .4), 0))
    else:
        burned_frame(bm, w, d, 0.12, wall_h, rng, door)
    nx, ny = SIDES[door]
    marker("door_main", (nx * (w / 2 + 0.6), ny * (d / 2 + 0.6), 0.12),
           math.atan2(-ny, -nx), door_width=DOOR_W)
    if dmg < 2:
        marker("work_cookfire", (-w * 0.30, -d * 0.28, 0.12), rng.uniform(0, math.tau),
               work_type="cook")
        marker("prop_hearth", (-w * 0.30, -d * 0.28, 0.12), 0.0, prop_class="hearth")
        marker("prop_sleep", (w * 0.28, d * 0.26, 0.12), 0.0, prop_class="sleep")
        marker("prop_store_a", (w * 0.30, -d * 0.28, 0.12), 0.0, prop_class="storage")
        marker("prop_altar", (0.0, d * 0.32, 0.12), math.atan2(-1, 0), prop_class="altar")
        marker("home_chicken", (-(w * 0.5 + 0.9), d * 0.34, 0.0), 0.0, species="chicken")
    return w, d, 0.12, wall_h, door


def fam_nha_san(bm, rng, dmg):
    """Stilt house: deck up on posts, ladder, open underneath."""
    w = rng.uniform(4.8, 6.4)
    d = rng.uniform(3.8, 5.0)
    deck = rng.uniform(1.55, 1.95)
    wall_h = rng.uniform(1.95, 2.2)
    mat_w = "vil_char" if dmg >= 2 else "vil_bamboo"
    mat_r = "vil_char" if dmg >= 2 else "vil_thatch"
    door = rng.randint(0, 3)
    # The posts, deck and joists are built before the damage branch, so they MUST take
    # the charred material too - otherwise a burned-out house is rendered in fresh wood.
    wood = "vil_char" if dmg >= 2 else "vil_timber"
    posts(bm, w, d, 0.0, deck, wood, n=3, r=0.13)
    braces(bm, w, d, deck, wood)
    box(bm, (0, 0, deck - 0.09), (w, d, 0.18), wood)                    # the deck itself
    for i in range(5):                                                  # deck joists showing
        box(bm, (0, -d / 2.0 + d * i / 4.0, deck - 0.22), (w + 0.2, 0.08, 0.12), wood)
    if dmg < 2:
        posts(bm, w, d, deck, wall_h, "vil_timber", n=3, r=0.09, door=door)
        for s in range(4):
            if dmg >= 1 and s == (door + 1) % 4:
                continue
            wall_run(bm, w, d, deck, wall_h, s, mat_w, door=(s == door))
            if s != door:
                battens(bm, w, d, deck, wall_h, s, "vil_timber", n=2)
        door_frame(bm, w, d, deck, door, "vil_timber")
        rh = rng.uniform(1.4, 1.8)
        hip_roof(bm, (0, 0, deck + wall_h), w * 1.28, d * 1.36, rh, mat_r,
                 ridge_frac=0.38, sag=0.1 * dmg)
        rafters(bm, w * 1.28, d * 1.36, deck + wall_h + 0.04, "vil_timber", n=5)
        ridge_cap(bm, w, d * 1.36, deck + wall_h + rh - 0.1 * dmg, mat_r, ridge_frac=0.38)
    else:
        posts(bm, w, d, deck, wall_h * 0.7, "vil_char", n=3, r=0.09, door=door)
        burned_frame(bm, w, d, deck, wall_h * 0.7, rng, door)
        # A stilt house burns from the top down and the wreckage falls THROUGH the deck.
        # Debris that stops at deck level leaves clean ground under a gutted house.
        for _ in range(rng.randint(3, 4)):
            rubble_mound(bm, rng.uniform(-w * 0.42, w * 0.42), rng.uniform(-d * 0.42, d * 0.42),
                         0.0, rng.uniform(0.45, 0.85), rng, n=3)
        for _ in range(rng.randint(2, 3)):               # beams that punched through
            a = rng.uniform(0, math.tau)
            beam_between(bm, (math.cos(a) * w * 0.42, math.sin(a) * d * 0.42,
                              deck - rng.uniform(0.1, 0.4)),
                         (rng.uniform(-w * 0.2, w * 0.2), rng.uniform(-d * 0.2, d * 0.2),
                          rng.uniform(0.16, 0.34)), 0.13, "vil_char", rng)
    nx, ny = SIDES[door]
    lx, ly = nx * (w / 2 + 0.1), ny * (d / 2 + 0.1)
    ladder(bm, lx, ly, deck, math.atan2(ny, nx), wood)
    marker("door_main", (nx * (w / 2 + 0.5), ny * (d / 2 + 0.5), deck),
           math.atan2(-ny, -nx), door_width=DOOR_W)
    marker("prop_under", (0.0, 0.0, 0.0), 0.0, prop_class="storage_low")
    # under the deck is exactly where village poultry actually shelters
    marker("home_chicken", (w * 0.22, -d * 0.22, 0.0), 0.0, species="chicken")
    marker("work_underfloor", (w * 0.2, d * 0.2, 0.0), rng.uniform(0, math.tau),
           work_type="tend")
    if dmg < 2:
        marker("prop_hearth", (-w * 0.28, -d * 0.26, deck), 0.0, prop_class="hearth")
        marker("prop_sleep", (w * 0.26, d * 0.24, deck), 0.0, prop_class="sleep")
        marker("prop_store_a", (w * 0.28, -d * 0.26, deck), 0.0, prop_class="storage")
    return w, d, deck, wall_h, door


def fam_nha_ruong(bm, rng, dmg):
    """Three-bay timber house under a TILE roof on a masonry footing."""
    w = rng.uniform(7.4, 9.2)
    d = rng.uniform(4.6, 5.6)
    wall_h = rng.uniform(2.15, 2.45)
    mat_w = "vil_char" if dmg >= 2 else "vil_wattle"
    door = rng.randint(0, 3)
    for i in range(2):                                                  # stepped footing
        box(bm, (0, 0, 0.10 + i * 0.16), (w + 0.9 - i * 0.4, d + 0.9 - i * 0.4, 0.20),
            "vil_masonry")
    z0 = 0.34
    posts(bm, w, d, z0, wall_h, "vil_timber", n=4, r=0.11, door=door)
    for s in range(4):
        wall_run(bm, w, d, z0, wall_h, s, mat_w, door=(s == door), thick=0.2)
    for i in range(4):                                                  # veranda colonnade
        x = -w / 2.0 + w * i / 3.0
        box(bm, (x, -(d / 2.0 + 0.85), z0 + wall_h / 2.0), (0.18, 0.18, wall_h), "vil_timber")
    box(bm, (0, -(d / 2.0 + 0.85), z0 + wall_h), (w, 0.2, 0.16), "vil_timber")
    door_frame(bm, w, d, z0, door, "vil_timber")
    rh = rng.uniform(1.5, 1.8)
    upswept_roof(bm, (0, 0, z0 + wall_h), w * 1.18, d * 1.55, rh,
                 "vil_char" if dmg >= 2 else "vil_tile", kick=0.42)
    rafters(bm, w * 1.18, d * 1.55, z0 + wall_h + 0.05, "vil_timber", n=9)
    box(bm, (0, 0, z0 + wall_h + rh * 0.9), (0.3, d * 1.5, 0.18),
        "vil_char" if dmg >= 2 else "vil_tile")
    if dmg >= 1:
        for _ in range(4):
            box(bm, (rng.uniform(-w / 2.4, w / 2.4), rng.uniform(-d / 2.4, d / 2.4),
                     z0 + wall_h + rng.uniform(0.4, 1.2)),
                (rng.uniform(0.6, 1.1), rng.uniform(0.6, 1.1), 0.28), "vil_char",
                rot=(rng.uniform(-.5, .5), rng.uniform(-.5, .5), 0))
    nx, ny = SIDES[door]
    marker("door_main", (nx * (w / 2 + 0.7), ny * (d / 2 + 0.7), z0),
           math.atan2(-ny, -nx), door_width=DOOR_W)
    marker("prop_altar", (0.0, d * 0.34, z0), math.atan2(-1, 0), prop_class="altar")
    marker("prop_table", (0.0, 0.0, z0), 0.0, prop_class="furniture")
    marker("prop_store_a", (-w * 0.34, -d * 0.28, z0), 0.0, prop_class="storage")
    marker("prop_store_b", (w * 0.34, -d * 0.28, z0), 0.0, prop_class="storage")
    marker("prop_sleep", (w * 0.34, d * 0.28, z0), 0.0, prop_class="sleep")
    marker("work_veranda", (0.0, -(d / 2.0 + 0.8), z0), math.atan2(-1, 0), work_type="sit")
    return w, d, z0, wall_h, door


def fam_bo_lua(bm, rng, dmg):
    """Rice granary: small deck on four staddle posts with disc rat-guards."""
    w = rng.uniform(2.0, 2.6)
    d = rng.uniform(1.8, 2.3)
    deck = rng.uniform(1.05, 1.35)
    body = rng.uniform(1.5, 1.85)
    for sx in (-1, 1):
        for sy in (-1, 1):
            px, py = sx * w * 0.36, sy * d * 0.36
            box(bm, (px, py, deck / 2.0), (0.16, 0.16, deck), "vil_timber")
            box(bm, (px, py, deck - 0.1), (0.5, 0.5, 0.07), "vil_timber")   # rat-guard disc
    box(bm, (0, 0, deck + 0.07), (w, d, 0.14), "vil_timber")
    box(bm, (0, 0, deck + 0.14 + body / 2.0), (w, d, body),
        "vil_char" if dmg >= 2 else "vil_bamboo", taper=0.94)
    hip_roof(bm, (0, 0, deck + 0.14 + body), w * 1.5, d * 1.6, rng.uniform(1.1, 1.4),
             "vil_char" if dmg >= 2 else "vil_thatch", ridge_frac=0.0)
    marker("prop_grain", (0.0, 0.0, deck + 0.2), 0.0, prop_class="storage")
    marker("work_granary", (0.0, -(d * 0.5 + 0.7), 0.0), math.atan2(-1, 0),
           work_type="carry")
    return w, d, 0.0, deck + body, 0


def fam_dinh(bm, rng, dmg):
    """Communal house: the biggest roof in the village, open colonnade, upswept tile."""
    w = rng.uniform(11.0, 13.5)
    d = rng.uniform(7.0, 8.6)
    wall_h = rng.uniform(2.7, 3.1)
    for i in range(2):
        box(bm, (0, 0, 0.14 + i * 0.22), (w + 1.6 - i * 0.7, d + 1.6 - i * 0.7, 0.28),
            "vil_masonry")
    z0 = 0.46
    for i in range(6):                                       # open colonnade, front + back
        x = -w / 2.0 + w * i / 5.0
        for sy in (-1, 1):
            box(bm, (x, sy * d / 2.0, z0 + wall_h / 2.0), (0.26, 0.26, wall_h), "vil_timber")
    for s in (1, 3):                                         # only the ends are walled
        wall_run(bm, w, d, z0, wall_h, s, "vil_wattle", door=(s == 1), thick=0.24)
    box(bm, (0, 0, z0 + wall_h + 0.1), (w, d, 0.2), "vil_timber")        # tie-beam plate
    rh = rng.uniform(2.4, 2.9)
    upswept_roof(bm, (0, 0, z0 + wall_h + 0.2), w * 1.16, d * 1.5, rh, "vil_tile", kick=0.95)
    rafters(bm, w * 1.16, d * 1.5, z0 + wall_h + 0.26, "vil_timber", n=11)
    box(bm, (0, 0, z0 + wall_h + 0.2 + rh * 0.9), (0.36, d * 1.45, 0.22), "vil_tile")
    for s2 in (-1, 1):                                     # ridge finials, the dinh's crown
        box(bm, (0, s2 * d * 0.72, z0 + wall_h + 0.2 + rh * 0.95), (0.3, 0.3, 0.55),
            "vil_tile", taper=0.35)
    marker("door_main", (w / 2.0 + 0.9, 0.0, z0), math.pi, door_width=DOOR_W)
    marker("prop_altar", (0.0, d * 0.34, z0), math.atan2(-1, 0), prop_class="altar")
    marker("prop_table", (-w * 0.2, 0.0, z0), 0.0, prop_class="furniture")
    marker("prop_bench_a", (w * 0.2, -d * 0.2, z0), 0.0, prop_class="furniture")
    marker("prop_bench_b", (w * 0.2, d * 0.2, z0), 0.0, prop_class="furniture")
    marker("work_meeting", (0.0, 0.0, z0), 0.0, work_type="sit")
    return w, d, z0, wall_h, 1


def fam_chua(bm, rng, dmg):
    """Pagoda shrine: receding tiled tiers over a small cella, altar out front."""
    w = rng.uniform(4.2, 5.2)
    d = rng.uniform(4.0, 4.8)
    wall_h = rng.uniform(2.3, 2.6)
    box(bm, (0, 0, 0.16), (w + 1.2, d + 1.2, 0.32), "vil_masonry")
    z0 = 0.32
    for s in range(4):
        wall_run(bm, w, d, z0, wall_h, s, "vil_masonry", door=(s == 0), thick=0.26)
    z = z0 + wall_h
    for t in range(rng.randint(2, 3)):                       # receding tiers
        f = 1.0 - t * 0.20
        th = rng.uniform(0.85, 1.05)
        upswept_roof(bm, (0, 0, z), w * (1.30 * f), d * (1.42 * f), th, "vil_tile", kick=0.5)
        rafters(bm, w * 1.30 * f, d * 1.42 * f, z + 0.04, "vil_timber", n=6)
        z += th * 0.62
    ax = w * 0.42 + 0.55                                  # altar stands OFF the door axis
    box(bm, (ax, -(d / 2.0 + 1.0), z0 + 0.28), (1.1, 0.7, 0.56), "vil_masonry")
    marker("door_main", (0.0, -(d / 2.0 + 0.7), z0), math.pi / 2.0, door_width=DOOR_W)
    marker("prop_altar", (0.0, d * 0.3, z0), math.atan2(-1, 0), prop_class="altar")
    marker("prop_incense", (0.0, -(d / 2.0 + 1.1), z0 + 0.56), 0.0, prop_class="offering")
    marker("work_shrine", (0.0, -(d / 2.0 + 1.9), 0.0), math.atan2(1, 0), work_type="pray")
    return w, d, z0, wall_h, 0


def fam_lean_to(bm, rng, dmg):
    """Kitchen lean-to: open one side, smoke-blackened, the village's cooking point."""
    w = rng.uniform(2.6, 3.4)
    d = rng.uniform(2.0, 2.6)
    h = rng.uniform(1.9, 2.2)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(bm, (sx * w * 0.45, sy * d * 0.45, h / 2.0), (0.12, 0.12, h), "vil_timber")
    for s in (1, 2, 3):
        wall_run(bm, w, d, 0.0, h * 0.86, s,
                 "vil_char" if dmg >= 1 else "vil_bamboo", thick=0.1)
    for i in range(5):                                       # single-pitch thatch
        f = i / 4.0
        box(bm, (0, -d / 2.0 + d * f, h + 0.34 - 0.42 * f), (w * 1.25, d / 4.2, 0.13),
            "vil_thatch", rot=(-0.30, 0, 0))
    marker("work_cookfire", (0.0, d * 0.2, 0.0), math.atan2(-1, 0), work_type="cook")
    marker("prop_hearth", (0.0, d * 0.2, 0.0), 0.0, prop_class="hearth")
    marker("prop_store_a", (-w * 0.3, -d * 0.2, 0.0), 0.0, prop_class="storage")
    return w, d, 0.0, h, 0


def fam_buffalo_shed(bm, rng, dmg):
    w, d, h = rng.uniform(3.4, 4.4), rng.uniform(2.6, 3.2), rng.uniform(2.0, 2.3)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(bm, (sx * w * 0.46, sy * d * 0.46, h / 2.0), (0.14, 0.14, h), "vil_timber")
    wall_run(bm, w, d, 0.0, h * 0.8, 2, "vil_bamboo", thick=0.1)
    for s in (1, 3):                                          # half-height rails
        for k in range(2):
            wall_run(bm, w, d, 0.35 + k * 0.55, 0.12, s, "vil_bamboo", thick=0.08)
    hip_roof(bm, (0, 0, h), w * 1.24, d * 1.3, 0.9, "vil_thatch", ridge_frac=0.45)
    marker("work_buffalo", (0.0, -(d * 0.5 + 0.8), 0.0), math.atan2(-1, 0), work_type="tend")
    marker("prop_trough", (0.0, d * 0.28, 0.0), 0.0, prop_class="furniture")
    marker("home_water_buffalo", (0.0, 0.0, 0.0), math.atan2(-1, 0), species="water_buffalo")
    marker("home_cow", (w * 0.26, 0.0, 0.0), math.atan2(-1, 0), species="cow")
    return w, d, 0.0, h, 0


def fam_pigsty(bm, rng, dmg):
    w, d, h = rng.uniform(2.4, 3.0), rng.uniform(2.0, 2.4), 1.05
    box(bm, (0, 0, 0.09), (w, d, 0.18), "vil_masonry")
    for s in range(4):
        wall_run(bm, w, d, 0.18, h, s, "vil_masonry", door=(s == 0), thick=0.16)
    for i in range(4):
        f = i / 3.0
        box(bm, (0, -d / 2.0 + d * f, h + 0.42 - 0.3 * f), (w * 0.7, d / 3.4, 0.11),
            "vil_thatch", rot=(-0.24, 0, 0))
    marker("work_pigs", (0.0, -(d * 0.5 + 0.7), 0.0), math.atan2(-1, 0), work_type="tend")
    marker("home_pig", (0.0, d * 0.16, 0.18), math.atan2(-1, 0), species="pig")
    return w, d, 0.18, h, 0


def fam_drying_rack(bm, rng, dmg):
    w, d, h = rng.uniform(2.8, 3.6), 1.0, rng.uniform(1.7, 2.0)
    for sx in (-1, 1):
        box(bm, (sx * w * 0.46, 0, h / 2.0), (0.12, 0.12, h), "vil_timber")
        box(bm, (sx * w * 0.46, 0, h * 0.55), (0.1, d * 1.6, 0.1), "vil_timber")
    for k in range(3):
        box(bm, (0, -d * 0.5 + d * k / 2.0, h - 0.12 * k), (w, 0.07, 0.07), "vil_bamboo")
    marker("work_drying", (0.0, -d * 1.1, 0.0), math.atan2(-1, 0), work_type="dry")
    marker("prop_mat", (0.0, 0.0, 0.0), 0.0, prop_class="floor")
    return w, d, 0.0, h, 0


def fam_hedge(bm, rng, dmg):
    """Bamboo hedge - the real Vietnamese village boundary, and genuine cover."""
    ln, h = 8.0, rng.uniform(2.2, 2.8)
    for i in range(26):
        x = -ln / 2.0 + ln * i / 25.0 + rng.uniform(-0.1, 0.1)
        hh = h * rng.uniform(0.78, 1.12)
        box(bm, (x, rng.uniform(-0.22, 0.22), hh / 2.0), (0.13, 0.13, hh), "vil_bamboo",
            rot=(rng.uniform(-.05, .05), rng.uniform(-.05, .05), 0))
    return ln, 0.6, 0.0, h, 0


def fam_gate(bm, rng, dmg):
    w, h = rng.uniform(3.0, 3.8), rng.uniform(2.4, 2.8)
    for sx in (-1, 1):
        box(bm, (sx * w / 2.0, 0, h / 2.0), (0.24, 0.24, h), "vil_timber")
    box(bm, (0, 0, h + 0.12), (w + 0.8, 0.3, 0.24), "vil_timber")
    for i in range(5):
        box(bm, (0, 0, h + 0.36 + i * 0.02), (w * (1.0 - i * 0.12), 0.5, 0.1), "vil_thatch",
            rot=(0.10, 0, 0))
    marker("door_main", (0.0, 0.0, 0.0), 0.0, door_width=w * 0.8)
    return w, 0.6, 0.0, h, 0


def fam_tomb(bm, rng, dmg):
    """Ancestor tomb at the paddy edge - low masonry, waist-high cover."""
    w, d = rng.uniform(1.9, 2.5), rng.uniform(1.5, 2.0)
    box(bm, (0, 0, 0.12), (w + 0.7, d + 0.7, 0.24), "vil_masonry")
    box(bm, (0, 0, 0.24 + 0.34), (w, d, 0.68), "vil_masonry", taper=0.9)
    box(bm, (0, -d * 0.4, 1.06), (w * 0.5, 0.16, 0.72), "vil_masonry")   # stele
    for sx in (-1, 1):
        box(bm, (sx * w * 0.4, d * 0.4, 1.0), (0.2, 0.2, 0.4), "vil_masonry", taper=0.5)
    marker("prop_offering", (0.0, -(d * 0.5 + 0.5), 0.24), math.atan2(1, 0),
           prop_class="offering")
    marker("work_tomb", (0.0, -(d * 0.5 + 1.2), 0.0), math.atan2(1, 0), work_type="pray")
    return w, d, 0.0, 1.4, 0


def fam_well(bm, rng, dmg):
    """Village well: octagonal masonry curb, shear-legs and a windlass over it.

    The centre-of-village landmark people gather at - and the reason a village sits
    where it sits. Kept as its own type because the stamp draws centre pieces from a
    different pool than huts.
    """
    r = rng.uniform(0.85, 1.05)
    curb = rng.uniform(0.62, 0.78)
    for i in range(8):                                   # octagonal curb ring
        a = math.tau * i / 8.0
        box(bm, (math.cos(a) * r, math.sin(a) * r, curb / 2.0),
            (r * 0.86, 0.22, curb), "vil_masonry", rot=(0, 0, a + math.pi / 2.0))
    box(bm, (0, 0, 0.06), (r * 2.6, r * 2.6, 0.12), "vil_masonry")    # apron
    for sx in (-1, 1):                                   # shear legs
        box(bm, (sx * (r + 0.12), 0, 1.15), (0.14, 0.14, 2.3), "vil_timber",
            rot=(0, -sx * 0.10, 0))
    box(bm, (0, 0, 2.28), (r * 2.6, 0.16, 0.16), "vil_timber")        # windlass beam
    box(bm, (0, 0, 2.28), (0.5, 0.26, 0.26), "vil_timber")            # drum
    box(bm, (0, 0, 1.62), (0.1, 0.1, 1.1), "vil_bamboo")              # rope
    box(bm, (0, 0, 1.02), (0.32, 0.32, 0.34), "vil_timber", taper=0.8)  # bucket
    marker("work_water", (0.0, -(r + 0.9), 0.0), math.pi / 2.0, work_type="water")
    marker("prop_jars", (r + 0.8, 0.0, 0.0), 0.0, prop_class="storage")
    return r * 2.2, r * 2.2, 0.0, 2.4, 0


def fam_bell_tower(bm, rng, dmg):
    """Open bell frame - the village alarm. Tall, skeletal, visible over the thatch."""
    w = rng.uniform(1.5, 1.9)
    h = rng.uniform(3.6, 4.3)
    box(bm, (0, 0, 0.12), (w + 1.0, w + 1.0, 0.24), "vil_masonry")
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(bm, (sx * w / 2.0, sy * w / 2.0, 0.24 + h / 2.0), (0.17, 0.17, h),
                "vil_timber", rot=(0, -sx * 0.035, sy * 0.035))
    for k in range(2):                                   # cross bracing between legs
        z = 0.24 + h * (0.34 + k * 0.33)
        for s2 in range(4):
            nx, ny = SIDES[s2]
            box(bm, (nx * w / 2.0, ny * w / 2.0, z),
                (0.09, w, 0.09) if nx else (w, 0.09, 0.09), "vil_timber")
    box(bm, (0, 0, 0.24 + h), (w + 0.3, w + 0.3, 0.14), "vil_timber")   # head frame
    hip_roof(bm, (0, 0, 0.24 + h + 0.14), (w + 1.2), (w + 1.2), 0.75, "vil_thatch",
             ridge_frac=0.0)
    box(bm, (0, 0, 0.24 + h - 0.42), (0.44, 0.44, 0.62), "vil_timber", taper=1.35)  # bell
    marker("work_bell", (0.0, -(w / 2.0 + 0.8), 0.0), math.pi / 2.0, work_type="alarm")
    return w, w, 0.0, h, 0


def fam_fence_run(bm, rng, dmg):
    """Low bamboo fence - pens the animals and divides the plots. The hedge is the
    village boundary; this is everything inside it."""
    ln = 6.0
    h = rng.uniform(0.95, 1.25)
    n = 7
    for i in range(n):
        x = -ln / 2.0 + ln * i / float(n - 1)
        box(bm, (x, 0, h / 2.0), (0.11, 0.11, h), "vil_timber",
            rot=(rng.uniform(-.04, .04), rng.uniform(-.04, .04), 0))
    for k in range(2):
        box(bm, (0, 0, h * (0.42 + k * 0.42)), (ln, 0.07, 0.07), "vil_bamboo")
    return ln, 0.4, 0.0, h, 0


def fam_haystack(bm, rng, dmg):
    """Straw rick on a raised base - rice straw kept for the buffalo through the dry."""
    r = rng.uniform(1.1, 1.5)
    h = rng.uniform(1.9, 2.5)
    box(bm, (0, 0, 0.09), (r * 2.3, r * 2.3, 0.18), "vil_timber")
    for i in range(4):                                    # stacked tapering courses
        f = 1.0 - i * 0.19
        box(bm, (rng.uniform(-.08, .08), rng.uniform(-.08, .08), 0.18 + h * (i + 0.5) / 4.0),
            (r * 2 * f, r * 2 * f, h / 4.0), "vil_thatch", taper=0.88,
            rot=(0, 0, rng.uniform(0, 1.5)))
    box(bm, (0, 0, 0.18 + h + 0.12), (0.16, 0.16, 0.5), "vil_bamboo")   # centre pole
    marker("work_straw", (0.0, -(r + 0.8), 0.0), math.pi / 2.0, work_type="carry")
    marker("home_chicken", (r + 0.5, 0.0, 0.0), 0.0, species="chicken")
    return r * 2, r * 2, 0.0, h, 0


def fam_ox_cart(bm, rng, dmg):
    """Two-wheel buffalo cart. Reads as a working village from any distance, and it is
    waist-high cover parked in the open."""
    bw, bl = rng.uniform(1.25, 1.5), rng.uniform(2.1, 2.6)
    axle = rng.uniform(0.62, 0.74)
    box(bm, (0, 0, axle + 0.14), (bw, bl, 0.16), "vil_timber")          # bed
    for sy in (-1, 1):                                                   # side boards
        box(bm, (sy * bw / 2.0, 0, axle + 0.38), (0.09, bl, 0.42), "vil_bamboo")
    box(bm, (0, bl / 2.0, axle + 0.38), (bw, 0.09, 0.42), "vil_bamboo")  # tailboard
    for sy in (-1, 1):                                                   # spoked wheels
        for k in range(6):
            a = math.pi * k / 6.0
            box(bm, (sy * (bw / 2.0 + 0.11), 0, axle),
                (0.1, axle * 1.7, 0.1), "vil_timber", rot=(a, 0, 0))
        box(bm, (sy * (bw / 2.0 + 0.11), 0, axle), (0.16, 0.3, 0.3), "vil_timber")
    for sy in (-1, 1):                                                   # shafts
        box(bm, (sy * bw * 0.3, -(bl / 2.0 + 0.75), axle + 0.2),
            (0.1, 1.7, 0.1), "vil_timber", rot=(0.10, 0, 0))
    marker("work_cart", (0.0, -(bl / 2.0 + 1.9), 0.0), math.pi / 2.0, work_type="carry")
    marker("prop_cartbed", (0.0, 0.0, axle + 0.22), 0.0, prop_class="storage")
    marker("home_water_buffalo", (0.0, -(bl / 2.0 + 2.6), 0.0), math.pi / 2.0,
           species="water_buffalo")
    return bw + 0.5, bl + 1.6, 0.0, axle + 0.8, 0


def fam_paddy_bund(bm, rng, dmg):
    """A worked paddy edge: earth bunds holding the water, rice standing in the plot.
    The thing that makes a village look like it feeds itself."""
    ln = 8.0
    wd = 5.0
    for sy in (-1, 1):                                    # long bunds
        box(bm, (0, sy * wd / 2.0, 0.11), (ln, 0.55, 0.22), "vil_masonry",
            rot=(0, 0, rng.uniform(-.02, .02)))
    for sx in (-1, 1):
        box(bm, (sx * ln / 2.0, 0, 0.11), (0.55, wd, 0.22), "vil_masonry")
    box(bm, (0, 0, 0.03), (ln - 0.5, wd - 0.5, 0.06), "vil_masonry")     # wet plot floor
    marker("work_paddy", (0.0, -(wd / 2.0 + 0.9), 0.0), math.pi / 2.0, work_type="farm")
    for i, sx in enumerate((-1, 1)):
        marker(f"graze_{i+1:02d}", (sx * ln * 0.3, 0.0, 0.06), rng.uniform(0, math.tau),
               graze_for="water_buffalo,cow")
    return ln, wd, 0.0, 0.25, 0


FAMILIES = {"nha_tranh": fam_nha_tranh, "fence_run": fam_fence_run,
            "haystack": fam_haystack, "ox_cart": fam_ox_cart,
            "paddy_bund": fam_paddy_bund, "well": fam_well, "bell_tower": fam_bell_tower, "nha_san": fam_nha_san, "nha_ruong": fam_nha_ruong,
            "bo_lua": fam_bo_lua, "dinh": fam_dinh, "chua": fam_chua,
            "lean_to": fam_lean_to, "buffalo_shed": fam_buffalo_shed,
            "pigsty": fam_pigsty, "drying_rack": fam_drying_rack,
            "hedge": fam_hedge, "gate": fam_gate, "tomb": fam_tomb}


def build_model(name, family, seed, dmg):
    global MARKERS
    MARKERS = []
    rng = random.Random(seed)
    bm = bmesh.new()
    w, d, floor_z, top, door = FAMILIES[family](bm, rng, dmg)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.0005)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in ensure_materials():
        me.materials.append(m)
    box_project_uvs(me)
    ob = bpy.data.objects.new(name, me)
    ob["family"] = family
    ob["damage"] = dmg
    ob["door_dir"] = door
    ob["cw"], ob["cd"] = w, d
    ob["floor_z"], ob["wall_top"] = floor_z, top
    bpy.context.collection.objects.link(ob)
    return ob


# --------------------------------------------------------------- vegetation --
VEG_LIB = {}


def veg_source(name):
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
    src.location = (0, 0, -500)
    VEG_LIB[name] = src
    return src


def veg_bounds(src):
    pts = [v.co for v in src.data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    return lo[2], hi[2], max(max(abs(lo[0]), abs(hi[0])), max(abs(lo[1]), abs(hi[1])))


YARD = ["banana_a", "banana_b", "bush_a", "bush_b", "bush_c"]
GROUND = ["grass_tuft_a", "grass_tuft_b", "grass_tuft_c", "moss_a"]
HEDGE_VEG = ["bamboo_a", "bamboo_b", "bamboo_c"]


def bake_vegetation(name, family, w, d, rng):
    """Household planting: banana clumps against the walls, scrub in the yard.

    Same convention as the temple set - real meshes from assets/world/vegetation,
    no '-col' suffix so leaves are not solid.
    """
    out = []
    half = max(w, d) * 0.5

    def drop(src_name, pos, rotz, scale):
        src = veg_source(src_name)
        if src is None:
            return
        cp = src.copy()
        cp.data = src.data.copy()
        cp.name = f"{name}_veg_{len(out):02d}_{src_name}"
        cp.location = pos
        cp.rotation_euler = (0, 0, rotz)
        cp.scale = (scale, scale, scale)
        bpy.context.collection.objects.link(cp)
        out.append(cp)

    if family == "hedge":
        for _ in range(2):
            drop(rng.choice(HEDGE_VEG), (rng.uniform(-3.6, 3.6), rng.uniform(-0.3, 0.3), 0.0),
                 rng.uniform(0, math.tau), rng.uniform(0.7, 1.1))
        return out
    if family in ("drying_rack", "gate", "tomb"):
        for _ in range(rng.randint(1, 2)):
            a = rng.uniform(0, math.tau)
            drop(rng.choice(GROUND), (math.cos(a) * half * 1.3, math.sin(a) * half * 1.3, 0.0),
                 rng.uniform(0, math.tau), rng.uniform(0.6, 1.0))
        return out
    for _ in range(rng.randint(1, 2)):                     # banana clump at the gable end
        a = rng.uniform(0, math.tau)
        r = half + rng.uniform(0.6, 1.8)
        drop(rng.choice(YARD), (math.cos(a) * r, math.sin(a) * r, 0.0),
             rng.uniform(0, math.tau), rng.uniform(0.7, 1.05))
    for _ in range(rng.randint(2, 4)):
        a = rng.uniform(0, math.tau)
        r = half + rng.uniform(0.4, 2.2)
        drop(rng.choice(GROUND), (math.cos(a) * r, math.sin(a) * r, 0.0),
             rng.uniform(0, math.tau), rng.uniform(0.6, 1.0))
    return out


def make_collision(ob, name):
    """'-col' twin: the structure only. Interiors stay hollow so you can walk in."""
    me = ob.data.copy()
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
    for o in bpy.data.objects:
        o.select_set(False)
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True, export_animations=False,
                              export_materials='EXPORT', export_extras=True,
                              export_draco_mesh_compression_enable=False)


PLAN = [("nha_tranh_01", "nha_tranh", 0), ("nha_tranh_02", "nha_tranh", 1),
        ("nha_tranh_03", "nha_tranh", 2),
        ("nha_san_01", "nha_san", 0), ("nha_san_02", "nha_san", 1),
        ("nha_san_03", "nha_san", 2),
        ("nha_ruong_01", "nha_ruong", 0), ("nha_ruong_02", "nha_ruong", 1),
        ("bo_lua_01", "bo_lua", 0), ("bo_lua_02", "bo_lua", 1),
        ("dinh_01", "dinh", 0), ("chua_01", "chua", 0),
        ("lean_to_01", "lean_to", 0), ("lean_to_02", "lean_to", 1),
        ("buffalo_shed_01", "buffalo_shed", 0), ("pigsty_01", "pigsty", 0),
        ("drying_rack_01", "drying_rack", 0),
        ("bamboo_hedge_01", "hedge", 0), ("village_gate_01", "gate", 0),
        ("ancestor_tomb_01", "tomb", 0),
        ("village_well_01", "well", 0), ("bell_frame_01", "bell_tower", 0),
        ("fence_run_01", "fence_run", 0), ("haystack_01", "haystack", 0),
        ("ox_cart_01", "ox_cart", 0), ("paddy_bund_01", "paddy_bund", 0)]


def main():
    bpy.ops.wm.read_homefile(use_empty=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    manifest = {}
    print(f"{'name':<20}{'family':<14}{'tris':>6}{'veg':>5}{'mk':>4}   size (m)")
    for i, (n, fam, dmg) in enumerate(PLAN):
        ob = build_model(n, fam, 8800 + i * 53, dmg)
        mn, _ = measure(ob)
        dz = -mn[2]
        for v in ob.data.vertices:
            v.co.z += dz
        mn, mx = measure(ob)
        t = tri_count(ob)
        size = [round(mx[k] - mn[k], 2) for k in range(3)]
        marks = build_markers(ob, n, dz)
        plants = bake_vegetation(n, fam, float(ob["cw"]), float(ob["cd"]),
                                 random.Random(hash(n) % 99991))
        group = [ob, make_collision(ob, n)] + marks + plants
        veg_t = sum(tri_count(p) for p in plants)
        over = "  OVER" if t > BUDGET else ""
        print(f"{n:<20}{fam:<14}{t:>6}{len(plants):>5}{len(marks):>4}   {size}"
              f"  (+{veg_t} veg tris){over}")
        export(group, os.path.join(OUT_DIR, n + ".glb"))
        manifest[n] = {
            "family": fam, "damage": dmg, "tris": t, "veg": len(plants),
            "veg_tris": veg_t, "size": size, "footprint": [size[0], size[1]],
            "height": size[2], "door_dir": int(ob["door_dir"]),
            # A burned husk is a lattice of fallen rafters - correctly impassable, and
            # it carries no interior markers. Saying so beats "fixing" the debris away.
            "enterable": dmg < 2 and fam in ("nha_tranh", "nha_san", "nha_ruong",
                                             "dinh", "chua"),
            "homes": sorted({m["props"]["species"] for m in MARKERS
                             if "species" in m["props"]}),
            "markers": [{"name": m["name"], "pos": [round(v, 3) for v in m["pos"]],
                         "face": round(m["face"], 4), **m["props"]} for m in MARKERS],
        }
    json.dump(manifest, open(os.path.join(OUT_DIR, "village_set.json"), "w"), indent=1)
    tot = sum(m["tris"] for m in manifest.values())
    mk = sum(len(m["markers"]) for m in manifest.values())
    print(f"\n{len(manifest)} models, {tot} structure tris, {mk} markers -> {OUT_DIR}")


main()
