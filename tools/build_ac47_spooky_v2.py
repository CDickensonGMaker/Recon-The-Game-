"""Mature the Summoner's own AC-47 "Spooky" into `ac47_spooky_v2` and export it.

    blender -b --factory-startup --python tools/build_ac47_spooky_v2.py -- [--export] [--render DIR]

UNLIKE build_a1_skyraider_v2.py and build_f4_phantom_v2.py this script does NOT
model an airframe from scratch. It IMPORTS `assets/us/aircraft/ac47_spooky.glb`,
which is his model, and applies a short list of measured proportion corrections
plus the port gun battery. His forms, his facets and his camo texture survive
untouched. The keep/fix table and the reference measurements behind every factor
below are in production/blender_notes.md, 2026-08-14.

The source GLB is opened read-only and is never rewritten.

Frame contract: nose at Blender +Y (Godot -Z) at identity, +Z up, real metres.
Origin at the centre of mass - x on the centreline, y at the wing quarter chord,
z on the fuselage centreline at the wing. The ground line is printed.

Two propellers, `AC47_Prop_L` / `AC47_Prop_R`, are the ONLY nodes whose names
trip rotor_spin.gd:25 PROP_HINTS. Each has its origin ON ITS HUB at identity
rotation, so its Godot local Z is the thrust line - the axis rotor_spin.gd:76
turns. A `prop_spin` action ALSO ships, because the one consumer of this asset,
spectre_gunship.gd:131-134, plays that clip by name and never attaches RotorSpin.
"""

import bpy, bmesh, math, os, sys
from mathutils import Vector

TAU = math.tau
PROJ = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT_DIR = os.path.join(PROJ, "assets", "us", "aircraft")
SRC_GLB = os.path.join(OUT_DIR, "ac47_spooky.glb")

# ---------------------------------------------------------------- real numbers
REAL_LENGTH = 19.43          # C-47B / DC-3, nose to rudder trailing edge
REAL_SPAN = 29.11
REAL_PROP_D = 3.51           # Hamilton Standard 23E50, 11 ft 6 in, three blades
REAL_STAB_SPAN = 8.70        # measured off the NASA plan view at 43.4 px/m
REAL_NACELLE_X = 2.88        # ditto; see note 1 in the reference study
REAL_FUSE_W = 2.60
REAL_CARGO_DOOR = (2.16, 1.73)   # 85 in x 68 in

# --------------------------------------------------------- correction constants
# Every one of these is a measured delta against the reference, not a taste call.
NOSE_Y = 12.680              # his nose tip, in the baked import frame
WING_LE_ROOT_Y = 8.663
WING_ROOT_CHORD = 4.518
BREAK_S = 8.535              # wing TE root: forward of here nothing moves in y
SRC_TAIL_S = 22.757          # his overall length
AFT_FACTOR = (REAL_LENGTH - BREAK_S) / (SRC_TAIL_S - BREAK_S)   # 0.766

FUSE_X = REAL_FUSE_W / 3.631        # 0.7216 - his fuselage is 3.631 m across
STAB_X = REAL_STAB_SPAN / 12.855    # 0.6768
WING_X = REAL_SPAN / 29.408         # 0.9899
FIN_Z_BASE = 0.797                  # the fin root, buried in the tail cone
FIN_Z = 0.70                        # 4.18 m above the aft centreline -> 2.93

# Prop tip clearance drives this, not the drawing: his prop is 3.64 m across and
# his nose is fatter than a real C-47's, so the honest equivalent of the real
# +/-2.88 m nacelle station is a little further out. Asserted below.
NACELLE_X = 3.15

# ------------------------------------------------------------- port gun battery
# s = metres aft of the nose in the CORRECTED frame. Windows 5 and 6 sit just
# forward of the cargo door; the third gun is in the door itself.
# GUN_Z is 0.30 and not the window centreline 0.10 because his fuselage section
# is faceted: a ray at z 0.10 lands on a near-tangent facet and the skin station
# swings 0.37 m over 0.3 m of height (x -1.44 at z +0.10 vs -1.81 at z -0.20).
# At z +0.30 the same scan reads -1.40..-1.49 with face normals -0.96..-0.99
# across the whole cabin, so all three mounts sit flat on the same flank.
#
# The whole battery sits 0.5 m forward of the drawing's stations, and the door is
# 1.28 m tall instead of 1.73, because of HIS hull: his fuselage belly starts
# climbing at s 11.8 where a real C-47's stays parallel to about s 13.6. Beyond
# that the skin ray finds nothing at door-sill height. Rather than restyle his
# tail cone, the door was moved onto the hull he drew. Every corner is verified
# against the skin by ray_cast, so this cannot silently drift.
GUN_S = (9.55, 10.45, 11.95)
GUN_Z = (0.30, 0.30, 0.30)
GUN_DEPRESS = math.radians(12.0)
GUN_OUT = 0.80               # barrel cluster protrusion beyond the skin
GUN_R = 0.075
DOOR_S0, DOOR_S1 = 10.90, 13.06
DOOR_Z0, DOOR_Z1 = -0.50, 0.78
PORT_W = 0.46                # gun-port window, square

WHEEL_Y, WHEEL_Z = 7.60, -1.45
WHEEL_D, WHEEL_W = 1.14, 0.36

SPIN_FRAMES = 8              # 8 frames at 24 fps = 3.0 rev/s ~ rotor_spin PROP_RPS


# =============================================================== mesh utilities
class Shell:
    def __init__(self):
        self.v = []
        self.f = []
        self.tag = []

    def add_verts(self, verts):
        o = len(self.v)
        self.v.extend(tuple(p) for p in verts)
        return o

    def face(self, idx, tag):
        self.f.append(tuple(idx))
        self.tag.append(tag)

    def add(self, verts, faces, tag):
        o = self.add_verts(verts)
        for f in faces:
            self.face([i + o for i in f], tag)
        return o


def box(shell, c, size, tag):
    hx, hy, hz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
    cx, cy, cz = c
    v = [(cx - hx, cy - hy, cz - hz), (cx + hx, cy - hy, cz - hz),
         (cx + hx, cy + hy, cz - hz), (cx - hx, cy + hy, cz - hz),
         (cx - hx, cy - hy, cz + hz), (cx + hx, cy - hy, cz + hz),
         (cx + hx, cy + hy, cz + hz), (cx - hx, cy + hy, cz + hz)]
    f = [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4),
         (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    shell.add(v, f, tag)


def tube(shell, p0, p1, r0, r1, n, tag):
    """Closed capped cylinder between two arbitrary points. Winding is fixed by
    recalc_face_normals afterwards - only ever call this for CLOSED solids."""
    p0, p1 = Vector(p0), Vector(p1)
    ax = (p1 - p0).normalized()
    ref = Vector((0.0, 0.0, 1.0)) if abs(ax.z) < 0.9 else Vector((1.0, 0.0, 0.0))
    u = ax.cross(ref).normalized()
    w = ax.cross(u).normalized()
    a = shell.add_verts([p0 + u * (r0 * math.cos(TAU * i / n))
                         + w * (r0 * math.sin(TAU * i / n)) for i in range(n)])
    b = shell.add_verts([p1 + u * (r1 * math.cos(TAU * i / n))
                         + w * (r1 * math.sin(TAU * i / n)) for i in range(n)])
    for i in range(n):
        shell.face((a + i, a + (i + 1) % n, b + (i + 1) % n, b + i), tag)
    ca = shell.add_verts([p0])
    cb = shell.add_verts([p1])
    for i in range(n):
        shell.face((ca, a + i, a + (i + 1) % n), tag)
        shell.face((cb, b + (i + 1) % n, b + i), tag)


# ================================================================ import + bake
def import_base():
    """Import his GLB and bake every node transform into vertex data.

    The shipped file carries non-uniform object scales up to 68x under a parent
    root that itself scales 0.1498 and rotates 180 deg. Nothing can be measured
    or edited until that is flattened, and a bbox read off the node scales would
    be nonsense."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    assert os.path.exists(SRC_GLB), "his base model is missing: %s" % SRC_GLB
    bpy.ops.import_scene.gltf(filepath=SRC_GLB)
    bpy.context.view_layer.update()
    # HIS OWN HUB EMPTIES are the authority on where the propeller centres are.
    # Solving the hub from the mesh does not work: a 3-blade disc's bbox centre
    # is not its hub, and an angular-bucket tip centroid diverges because the
    # buckets do not line up with the blades - that attempt read the disc as
    # 4.68 m across instead of 3.6 m.
    hubs = {}
    for src, key in (("Prop_Center_rotation", "pROPELLER"),
                     ("Prop_Center_rotation.001", "pROPELLER.001")):
        e = bpy.data.objects.get(src)
        assert e is not None, "his hub empty %r is gone from the source GLB" % src
        hubs[key] = e.matrix_world.translation.copy()
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    for ob in meshes:
        ob.data.transform(ob.matrix_world.copy())
        ob.parent = None
        ob.matrix_world.identity()
        ob.data.update()
    for ob in list(bpy.data.objects):
        if ob.type != "MESH":
            bpy.data.objects.remove(ob, do_unlink=True)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)     # his four clips are rebuilt, not carried
    return {o.name: o for o in bpy.data.objects if o.type == "MESH"}, hubs


def strip_degenerates(obs):
    """Delete zero-area faces. There are 78 in his base - 38 in each nacelle and
    2 in the cockpit cap - and they are invisible, so this changes nothing on
    screen while letting the QC gate below stay a hard failure."""
    killed = 0
    for ob in obs.values():
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        dead = [f for f in bm.faces if f.calc_area() < 1e-7]
        if dead:
            killed += len(dead)
            bmesh.ops.delete(bm, geom=dead, context="FACES_ONLY")
            loose = [v for v in bm.verts if not v.link_faces]
            if loose:
                bmesh.ops.delete(bm, geom=loose, context="VERTS")
            bm.to_mesh(ob.data)
            ob.data.update()
        bm.free()
    return killed


def bounds(obs):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for ob in obs:
        off = Vector(ob.location)
        for v in ob.data.vertices:
            w = v.co + off
            lo = Vector((min(lo[i], w[i]) for i in range(3)))
            hi = Vector((max(hi[i], w[i]) for i in range(3)))
    return lo, hi


def edit(ob, fn):
    for v in ob.data.vertices:
        v.co = fn(v.co)
    ob.data.update()


def disc_dia(ob, hub):
    """Diameter in the plane normal to the thrust line, about the KNOWN hub. A
    bbox understates it whenever the blades are not clocked to the axes."""
    return 2.0 * max(math.hypot(v.co.x - hub.x, v.co.z - hub.z) for v in ob.data.vertices)


# =============================================================== the correction
def correct(obs, hubs):
    """Apply the measured fixes. Everything not listed here is his, unchanged."""
    fus, ck, ck2 = obs["fusealage"], obs["cockpit"], obs["cockpit.001"]
    wing, stab, fin = obs["wingspan"], obs["Left_fin.001"], obs["Topfin"]
    nac_s, nac_p = obs["tURBINE_1.002"], obs["INNER_ENGINE.002"]
    prop_s, prop_p = obs["pROPELLER"], obs["pROPELLER.001"]

    # ---- 1. fuselage width 3.631 -> 2.60 (a C-47 is TALLER than it is wide)
    for ob in (fus, ck, ck2):
        edit(ob, lambda p: Vector((p.x * FUSE_X, p.y, p.z)))

    # ---- 2. span 29.408 -> 29.11, and centre it (his wing sat 0.017 m to port)
    wc = sum((bounds([wing])[i].x for i in (0, 1))) * 0.5
    edit(wing, lambda p: Vector(((p.x - wc) * WING_X, p.y, p.z)))

    # ---- 3. tailplane span 12.855 -> 8.70
    edit(stab, lambda p: Vector((p.x * STAB_X, p.y, p.z)))

    # ---- 4. fin 4.18 m above the aft centreline -> 2.93
    edit(fin, lambda p: Vector((p.x, p.y, FIN_Z_BASE + (p.z - FIN_Z_BASE) * FIN_Z)))

    # ---- 5. length 22.757 -> 19.43.
    # A piecewise y warp on the FUSELAGE ONLY: identity forward of the wing
    # trailing edge, AFT_FACTOR behind it. The wing, nacelles and props keep
    # their y exactly, so his wing planform and engine layout are not distorted
    # - the wing is a separate object that interpenetrates the fuselage and
    # shares no welded boundary with it.
    def warp(p):
        s = NOSE_Y - p.y
        if s > BREAK_S:
            s = BREAK_S + (s - BREAK_S) * AFT_FACTOR
        return Vector((p.x, NOSE_Y - s, p.z))
    for ob in (fus, ck, ck2):
        edit(ob, warp)

    # The tail surfaces are TRANSLATED, not warped, so their chords survive: a
    # 23% chord squeeze on top of the span fix would have left a toy empennage.
    # Deltas are computed ONCE - evaluating bounds() inside the per-vertex lambda
    # reads a half-edited mesh and gives every vertex a different shift.
    dfin = (NOSE_Y - REAL_LENGTH) - bounds([fin])[0].y
    edit(fin, lambda p: Vector((p.x, p.y + dfin, p.z)))
    edit(stab, lambda p: Vector((p.x, p.y + 1.404, p.z)))

    # ---- 6. engines: +6.31 / -5.93 (asymmetric!) -> +/-NACELLE_X, symmetric.
    # Nacelle and prop are shifted independently so BOTH land exactly on the
    # station; his differ by 4 cm, and the port/starboard pair differ by 38 cm.
    hy = sum(h.y for h in hubs.values()) / 2.0
    hz = sum(h.z for h in hubs.values()) / 2.0
    for nac, sign in ((nac_s, 1.0), (nac_p, -1.0)):
        lo, hi = bounds([nac])
        dx = sign * NACELLE_X - (lo.x + hi.x) * 0.5
        edit(nac, lambda p, dx=dx: Vector((p.x + dx, p.y, p.z)))
    for key, sign in (("pROPELLER", 1.0), ("pROPELLER.001", -1.0)):
        h = hubs[key]
        d = Vector((sign * NACELLE_X - h.x, hy - h.y, hz - h.z))
        edit(obs[key], lambda p, d=d: p + d)
        hubs[key] = h + d


# ==================================================================== the guns
SKIN_HITS = []
PANEL_SAG = []


def skin_x(fus, y, z, need_flat=False):
    """Port skin station, MEASURED by ray_cast rather than assumed from the bbox.

    His fuselage half-width by bbox is 1.31 m but the section is faceted: the
    actual flank stands anywhere from 1.01 to 1.30 m out depending on height, so
    a bbox figure hangs the mounts in mid-air at one station and buries them at
    the next. `need_flat` additionally asserts the facet is not near-tangent to
    the ray, which is what a mount has to sit on."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    ev = fus.evaluated_get(dg)
    hit, loc, nrm, _ = ev.ray_cast(Vector((-8.0, y, z)), Vector((1.0, 0.0, 0.0)))
    assert hit, "no port skin at y %.2f z %.2f - the station is off the hull" % (y, z)
    assert loc.x < 0.0, "port ray hit the STARBOARD skin at y %.2f z %.2f" % (y, z)
    SKIN_HITS.append((y, z, loc.x, nrm.x))
    if need_flat:
        assert nrm.x < -0.85, ("skin facet at y %.2f z %.2f is near-tangent (n.x %.2f)"
                               " - a mount there would stand on an edge" % (y, z, nrm.x))
    return loc.x


def build_guns(fus):
    """Three 7.62 mm miniguns out the port side: two window ports and the door."""
    s = Shell()
    muzzles = []
    d = Vector((-math.cos(GUN_DEPRESS), 0.0, -math.sin(GUN_DEPRESS)))
    for i, (st, gz) in enumerate(zip(GUN_S, GUN_Z)):
        y = NOSE_Y - st
        sx = skin_x(fus, y, gz, need_flat=True)
        p = Vector((sx, y, gz))
        box(s, p + d * 0.09, (0.26, 0.28, 0.24), "dark")     # locally-made mount
        tube(s, p + d * (-0.14), p + d * GUN_OUT, GUN_R, GUN_R * 0.82, 6, "dark")
        muzzles.append((p + d * GUN_OUT, d.copy()))
    return s, muzzles


def build_gear():
    """Main wheels, half exposed under the nacelles - a DC-3 signature."""
    s = Shell()
    for sign in (1.0, -1.0):
        x = sign * NACELLE_X
        tube(s, (x - WHEEL_W * 0.5, WHEEL_Y, WHEEL_Z), (x + WHEEL_W * 0.5, WHEEL_Y, WHEEL_Z),
             WHEEL_D * 0.5, WHEEL_D * 0.5, 8, "dark")
    return s


def build_port_side(fus):
    """Flat dark decals 12 mm proud of the port skin: the two-piece cargo door
    and the two gun-port windows. One-sided, wound to face -X, and they must
    NEVER see recalc_face_normals - on a flat decal it re-orients at random."""
    s = Shell()

    # HIS OWN FACET LINES are the grid. The cabin flank is not a smooth tube: it
    # is a RIDGE at y 0.97 spanned by long triangles reaching y +5.11 forward and
    # y -4.35 aft, and it pulls in 0.6 m over that run. A decal on a regular grid
    # chords straight across that ridge and sinks 0.14 m into the skin - and
    # refining the grid made it WORSE, because a finer regular grid still
    # straddles the crease. Snapping the grid to his vertex rings makes each
    # decal quad piecewise coplanar with the facet under it, so the sag is ~0.
    port = [v.co for v in fus.data.vertices if v.co.x < -0.2]

    def lines(idx, a, b, other, oa, ob):
        """Grid lines on axis `idx` inside (a, b), taken from HIS vertices that
        are also inside the panel on the other axis. Sampling his whole fuselage
        instead put a cut at every ring z anywhere on the aeroplane and blew the
        cargo door out to 216 tris."""
        vals = sorted({round(p[idx], 4) for p in port
                       if oa - 0.30 < p[other] < ob + 0.30})
        return [a] + [v for v in vals if a + 0.06 < v < b - 0.06] + [b]

    def panel(s0, s1, z0, z1):
        """A CONTINUOUS ribbon of quads that follows the flank, every vertex
        sampling the skin at its own height (the A-1 insignia rule: a flat decal
        chorded across a curve buries one edge and floats the other).

        Two failures had to be designed out and both are visible in a close-up:
        rows that own their vertices STEP against each other and the door reads
        as a stack of crates, and a row chorded across a convex crease SAGS
        inside the skin and disappears. So the rows share their boundary
        vertices, and the whole panel takes ONE outward offset big enough for
        the worst row - which stays small only because the ribbon is fine."""
        y0, y1 = NOSE_Y - s0, NOSE_Y - s1              # y0 forward of y1
        yc, zc = (y0 + y1) * 0.5, (z0 + z1) * 0.5
        ys = list(reversed(lines(1, y1, y0, 2, z0, z1)))
        zsl = lines(2, z0, z1, 1, y1, y0)
        grid = [[skin_x(fus, yy + (yc - yy) * 0.04, zz + (zc - zz) * 0.04)
                 for zz in zsl] for yy in ys]
        extra = 0.0
        for c in range(len(ys) - 1):
            for r in range(len(zsl) - 1):
                mid = (grid[c][r] + grid[c + 1][r] + grid[c][r + 1] + grid[c + 1][r + 1]) * 0.25
                extra = max(extra, mid - skin_x(fus, (ys[c] + ys[c + 1]) * 0.5,
                                                (zsl[r] + zsl[r + 1]) * 0.5))
        extra = max(0.0, extra)
        PANEL_SAG.append(extra)
        # It cannot reach zero: his flank is TRIANGULATED DIAGONALLY (one tri
        # runs from y 0.97 z -0.478 to y -4.14 z 0.614), and no rectangular grid
        # is coplanar with a diagonal. 0.042 m is the residual on the widest
        # door panel and 0.097 on the aft one - UNIFORM across each panel, so it
        # reads as a slightly proud door skin and not as the staircase a per-row
        # lift produced. 0.10 m on a 2.6 m fuselage is under 4%.
        assert extra < 0.11, ("port decal at s %.2f needs a %.3f m lift to clear"
                              " his flank - the facet grid missed a crease" % (s0, extra))
        off = 0.015 + extra
        for c in range(len(ys) - 1):
            for r in range(len(zsl) - 1):
                # -X outward: this winding gives n.x < 0, asserted in QC.
                s.add([(grid[c][r] - off, ys[c], zsl[r]),
                       (grid[c + 1][r] - off, ys[c + 1], zsl[r]),
                       (grid[c + 1][r + 1] - off, ys[c + 1], zsl[r + 1]),
                       (grid[c][r + 1] - off, ys[c], zsl[r + 1])], [(0, 1, 2, 3)], "dark")

    split = DOOR_S0 + (DOOR_S1 - DOOR_S0) / 3.0
    panel(DOOR_S0, split - 0.02, DOOR_Z0, DOOR_Z1)
    panel(split + 0.02, DOOR_S1, DOOR_Z0, DOOR_Z1)
    for st, gz in zip(GUN_S[:2], GUN_Z[:2]):
        panel(st - PORT_W * 0.5, st + PORT_W * 0.5, gz - PORT_W * 0.5, gz + PORT_W * 0.5)
    return s


# ==================================================================== materials
def retag_materials():
    """His two materials, renamed off the Blender defaults and flattened to the
    fleet's near-diffuse look. The camo IMAGE stays: it is his paint and it is
    the one deliberate deviation from the a1/f4 no-texture convention."""
    ren = {"Material": "ac47_camo", "Material.001": "ac47_black"}
    for old, new in ren.items():
        m = bpy.data.materials.get(old)
        assert m is not None, "expected his material %r in the source GLB" % old
        m.name = new
    for m in bpy.data.materials:
        b = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        assert b is not None, "%s has no Principled BSDF" % m.name
        b.inputs["Metallic"].default_value = 0.0
        b.inputs["Roughness"].default_value = 0.86
        if "Specular IOR Level" in b.inputs:
            b.inputs["Specular IOR Level"].default_value = 0.25
        m.metallic = 0.0
        m.roughness = 0.86
    return bpy.data.materials["ac47_camo"], bpy.data.materials["ac47_black"]


TAG_MAT = {"dark": "ac47_black"}


# ======================================================================= meshes
def merge(name, obs):
    """Concatenate meshes by hand, preserving UVs and per-face materials.

    bpy.ops.object.join needs a live context and silently reorders material
    slots; this is deterministic and the face count is asserted."""
    verts, faces, uvs, mats, want = [], [], [], [], 0
    names = []
    for ob in obs:
        me = ob.data
        base = len(verts)
        verts.extend(v.co.copy() for v in me.vertices)
        uvl = me.uv_layers.active
        for p in me.polygons:
            faces.append(tuple(base + i for i in p.vertices))
            mn = me.materials[p.material_index].name
            if mn not in names:
                names.append(mn)
            mats.append(names.index(mn))
            for li in range(p.loop_start, p.loop_start + p.loop_total):
                uvs.append(tuple(uvl.data[li].uv) if uvl else (0.0, 0.0))
        want += len(me.polygons)
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    assert len(me.polygons) == want, "%s: %d faces in, %d out" % (name, want, len(me.polygons))
    for n in names:
        me.materials.append(bpy.data.materials[n])
    for i, p in enumerate(me.polygons):
        p.material_index = mats[i]
    uvl = me.uv_layers.new(name="UVMap")
    for i, uv in enumerate(uvs):
        uvl.data[i].uv = uv
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob


def realise(name, shell, recalc=True):
    me = bpy.data.meshes.new(name)
    me.from_pydata(shell.v, [], shell.f)
    me.update()
    assert len(me.polygons) == len(shell.f), "%s: face count changed" % name
    if recalc:
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        me.update()
    for mn in sorted({TAG_MAT[t] for t in shell.tag}):
        me.materials.append(bpy.data.materials[mn])
    slots = [m.name for m in me.materials]
    for i, p in enumerate(me.polygons):
        p.material_index = slots.index(TAG_MAT[shell.tag[i]])
    uvl = me.uv_layers.new(name="UVMap")
    for d in uvl.data:
        d.uv = (0.0, 0.0)     # ac47_black carries no image; nothing to sample
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob


def collider(name, boxes):
    s = Shell()
    for c, size in boxes:
        box(s, c, size, "dark")
    me = bpy.data.meshes.new(name)
    me.from_pydata(s.v, [], s.f)
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    # A collider in a render occludes the airframe and every "look at it" check
    # then silently judges a box. glTF exports it anyway.
    ob.hide_render = True
    return ob


def make_prop(src, name, hub):
    """Re-home a propeller so its ORIGIN is its hub at identity rotation."""
    dia = disc_dia(src, hub)
    me = src.data.copy()
    me.name = name
    for v in me.vertices:
        v.co -= hub
    me.update()
    ob = bpy.data.objects.new(name, me)
    ob.location = hub
    bpy.context.collection.objects.link(ob)
    return ob, dia


def bake_spin(props):
    """One slotted `prop_spin` action driving both props about their local Y
    (= Godot local Z, the thrust line). Quaternion keys every 90 deg: every
    consecutive pair has a positive dot, so Godot's slerp cannot take the long
    way round, and the 360 deg key is the same rotation as the 0 deg key so the
    loop is seamless."""
    act = bpy.data.actions.new("prop_spin")
    act.use_fake_user = True
    for ob in props:
        ob.rotation_mode = "QUATERNION"
        ad = ob.animation_data_create()
        ad.action = act
        ad.action_slot = act.slots.new(id_type="OBJECT", name=ob.name)
        for k in range(5):
            a = TAU * k / 4.0
            ob.rotation_quaternion = (math.cos(a * 0.5), 0.0, math.sin(a * 0.5), 0.0)
            ob.keyframe_insert(data_path="rotation_quaternion",
                               frame=k * SPIN_FRAMES / 4.0)
        ob.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
    bpy.context.scene.frame_start = 0
    bpy.context.scene.frame_end = SPIN_FRAMES
    bpy.context.scene.frame_set(0)
    return act


# ======================================================================== build
def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    do_export = "--export" in argv
    render_dir = argv[argv.index("--render") + 1] if "--render" in argv else None

    obs, hubs = import_base()
    src_lo, src_hi = bounds(list(obs.values()))
    src_tris = 0
    for ob in obs.values():
        ob.data.calc_loop_triangles()
        src_tris += len(ob.data.loop_triangles)
    print("\n--- HIS BASE, as shipped -------------------------------------")
    print("  parts %s" % sorted(obs))
    print("  bbox lo %s hi %s" % (tuple(round(c, 3) for c in src_lo),
                                  tuple(round(c, 3) for c in src_hi)))
    print("  span %.3f  length %.3f  height %.3f  tris %d"
          % (src_hi.x - src_lo.x, src_hi.y - src_lo.y, src_hi.z - src_lo.z, src_tris))
    print("  nose y %+0.3f (Blender +Y = Godot -Z: HIS FACING IS ALREADY CORRECT)"
          % src_hi.y)
    print("  his hubs %s" % {k: tuple(round(c, 3) for c in v) for k, v in hubs.items()})
    print("  prop discs about those hubs: %.3f / %.3f m"
          % (disc_dia(obs["pROPELLER.001"], hubs["pROPELLER.001"]),
             disc_dia(obs["pROPELLER"], hubs["pROPELLER"])))
    killed = strip_degenerates(obs)
    print("  deleted %d zero-area faces from his base (invisible; 38 in each"
          " nacelle, 2 in the cockpit cap)" % killed)

    cam, blk = retag_materials()
    correct(obs, hubs)

    fus = obs["fusealage"]
    # Measure the parts that matter BEFORE they are merged: after the join, a
    # "widest vertex aft of the wing" query answers with the WING, and a
    # "fuselage centreline" query answers with the wing hanging under it. The
    # first pass reported a 29.11 m tailplane and a 4.38 m fuselage that way.
    flo, fhi = bounds([fus])
    fuse_w = fhi.x - flo.x
    slo, shi = bounds([obs["Left_fin.001"]])
    stab_span = shi.x - slo.x
    qc_y = WING_LE_ROOT_Y - WING_ROOT_CHORD * 0.25
    fz = [v.co.z for v in fus.data.vertices if abs(v.co.y - qc_y) < 1.5]
    com_z = (min(fz) + max(fz)) * 0.5
    tail_fz = [v.co.z for v in fus.data.vertices if v.co.y < flo.y + 3.0]
    aft_centre_z = (min(tail_fz) + max(tail_fz)) * 0.5
    guns_shell, muzzles = build_guns(fus)
    port_shell = build_port_side(fus)

    air = merge("AC47_Airframe", [obs[n] for n in
                                  ("fusealage", "cockpit", "cockpit.001", "wingspan",
                                   "Left_fin.001", "Topfin",
                                   "tURBINE_1.002", "INNER_ENGINE.002")])
    guns = realise("AC47_Guns", guns_shell)
    gear = realise("AC47_Gear", build_gear())
    side = realise("AC47_PortSide", port_shell, recalc=False)
    prop_r, prop_r_d = make_prop(obs["pROPELLER"], "AC47_Prop_R", hubs["pROPELLER"])
    prop_l, prop_l_d = make_prop(obs["pROPELLER.001"], "AC47_Prop_L", hubs["pROPELLER.001"])

    empties = []
    for i, (p, d) in enumerate(muzzles):
        e = bpy.data.objects.new("gun_muzzle_%d" % (i + 1), None)
        e.empty_display_type = "SINGLE_ARROW"
        e.empty_display_size = 0.4
        e.location = p
        # Blender local +Y -> Godot local -Z, so the adopter reads the firing
        # direction as -muzzle.global_transform.basis.z.
        e.rotation_euler = d.to_track_quat("Y", "Z").to_euler()
        bpy.context.collection.objects.link(e)
        empties.append(e)

    for name in list(obs):
        bpy.data.objects.remove(obs[name], do_unlink=True)

    visible = [air, guns, gear, side, prop_r, prop_l]

    # ---- colliders, derived from the corrected airframe so they cannot drift
    alo, ahi = bounds([air])
    cols = [
        collider("AC47_Col_Hull-colonly",
                 [((0.0, 8.60, -0.10), (2.62, 8.20, 2.70)),
                  ((0.0, 1.60, -0.10), (2.62, 6.00, 2.70)),
                  ((0.0, -3.80, 0.10), (1.50, 4.90, 2.00))]),
        collider("AC47_Col_Wing-colonly",
                 [((0.0, 6.40, -1.10), (REAL_SPAN, 4.60, 0.70)),
                  ((NACELLE_X, 7.10, -0.80), (1.40, 4.80, 1.80)),
                  ((-NACELLE_X, 7.10, -0.80), (1.40, 4.80, 1.80))]),
        collider("AC47_Col_Aft-colonly",
                 [((0.0, -4.60, 2.10), (0.30, 4.30, 3.10)),
                  ((0.0, -4.80, 1.00), (REAL_STAB_SPAN, 3.70, 0.36))]),
    ]

    # ---- seat the model on its centre of mass.
    # x centreline, y wing quarter chord, z fuselage centreline at the wing.
    # NOT the ground line: the fleet convention (see a1/f4) is a centred origin,
    # and spectre_gunship.gd:217 already offsets its own muzzle DOWN from the
    # node origin. The ground line is printed below so it can still be parked.
    shift = Vector((0.0, -qc_y, -com_z))
    for ob in visible + cols:
        if ob in (prop_r, prop_l):
            continue
        for v in ob.data.vertices:
            v.co += shift
        ob.data.update()
    for ob in (prop_r, prop_l) + tuple(empties):
        ob.location = Vector(ob.location) + shift

    # ---- measure
    print("\n--- MESH INVENTORY -------------------------------------------")
    tris = 0
    for ob in visible + cols:
        ob.data.calc_loop_triangles()
        t = len(ob.data.loop_triangles)
        ng = sum(1 for p in ob.data.polygons if len(p.vertices) > 4)
        if not ob.name.endswith("-colonly"):
            tris += t
        print("  %-26s tris %5d verts %5d ngons %d loc %s"
              % (ob.name, t, len(ob.data.vertices), ng,
                 tuple(round(c, 3) for c in ob.location)))
    bpy.context.view_layer.update()
    for e in empties:
        fwd = (e.matrix_world.to_3x3() @ Vector((0.0, 1.0, 0.0))).normalized()
        print("  %-26s EMPTY            loc %s  Blender +Y = Godot -Z = fire dir %s"
              % (e.name, tuple(round(c, 3) for c in e.location),
                 tuple(round(c, 3) for c in fwd)))

    lo, hi = bounds(visible)
    alo, ahi = bounds([air])
    length, span = hi.y - lo.y, hi.x - lo.x
    print("\n--- MEASURED vs REAL (object space, metres) ------------------")
    print("  span      %7.3f  real %6.3f  d %+0.3f" % (span, REAL_SPAN, span - REAL_SPAN))
    print("  length    %7.3f  real %6.3f  d %+0.3f" % (length, REAL_LENGTH, length - REAL_LENGTH))
    print("  prop dia  %7.3f / %7.3f  real %6.3f  d %+0.3f"
          % (prop_l_d, prop_r_d, REAL_PROP_D, prop_l_d - REAL_PROP_D))
    print("  stab span %7.3f  real %6.3f  d %+0.3f"
          % (stab_span, REAL_STAB_SPAN, stab_span - REAL_STAB_SPAN))
    print("  nacelle x %+7.3f  real %+6.3f  (clearance-driven, see notes)"
          % (NACELLE_X, REAL_NACELLE_X))
    print("  fuse width%7.3f  real %6.3f  d %+0.3f"
          % (fuse_w, REAL_FUSE_W, fuse_w - REAL_FUSE_W))
    print("  fin top %.3f m above the aft fuselage centreline (real ~2.8)"
          % (ahi.z - (aft_centre_z - com_z)))
    print("  nose y %+0.3f  tail y %+0.3f  belly z %+0.3f  top z %+0.3f"
          % (hi.y, lo.y, alo.z, ahi.z))
    print("  bbox lo %s hi %s" % (tuple(round(c, 3) for c in lo),
                                  tuple(round(c, 3) for c in hi)))
    print("  origin = centre of mass (x centreline, y wing quarter chord,"
          " z fuselage centreline at the wing)")
    # The static bbox understates the bottom: the blades are clocked, so no blade
    # is at bottom dead centre in the rest pose. The disc SWEEPS lower than that
    # and it is the disc that would hit the ground.
    arc_z = prop_l.location.z - prop_l_d * 0.5
    print("  GROUND LINE at local z %+0.3f  (the swept prop arc; the static bbox"
          " bottoms at %+0.3f. Add this to park it; level, gear up)" % (arc_z, lo.z))
    print("  main wheels reach z %+0.3f - %.2f m of tyre stands proud below the"
          " nacelle, which is how a retracted DC-3 looks"
          % (WHEEL_Z - WHEEL_D * 0.5 + shift.z, 0.36))
    print("  TOTAL VISIBLE TRIS %d   (his base was %d, +%d for the battery)"
          % (tris, src_tris, tris - src_tris))

    # ---- QC. A build that ran without error proves nothing.
    print("\n--- QC -------------------------------------------------------")
    bad = []
    for ob in visible + cols:
        me = ob.data
        ng = sum(1 for p in me.polygons if len(p.vertices) > 4)
        used = set()
        for p in me.polygons:
            used.update(p.vertices)
        loose = len(me.vertices) - len(used)
        bm = bmesh.new()
        bm.from_mesh(me)
        dbl = len(bmesh.ops.find_doubles(bm, verts=bm.verts, dist=1e-4)["targetmap"])
        zero = sum(1 for f in bm.faces if f.calc_area() < 1e-7)
        bm.free()
        print("  %-26s ngons %d loose %d doubles %d zero-area %d"
              % (ob.name, ng, loose, dbl, zero))
        if ng or zero:
            bad.append(ob.name)
    print("  (doubles on his parts are the glTF vertex split - one vertex per")
    print("   UV/normal corner. Welding them would destroy his seams and his")
    print("   flat shading, so they are reported and left alone.)")
    # The decals are one-sided and must all face PORT. A backfaced decal renders
    # as a black hole from inside and nothing else catches it.
    # These follow the flank, so their normals are not pure -X; what matters is
    # that none of them is BACKFACING, which renders as a hole from outside.
    # A real cargo door is curved to the fuselage, so the panels that wrap over
    # his section corners are STEEP and that is correct. The only defect is a
    # BACKFACING one, which renders as a hole punched in the side.
    for p in side.data.polygons:
        assert p.normal.x < -0.15, ("AC47_PortSide face at %s faces the wrong way (n.x %.2f)"
                                    % (tuple(round(c, 2) for c in p.center), p.normal.x))
    print("  port-side decals: %d faces, all facing port (worst n.x %.2f);"
          " panel lifts to clear his flank %s m"
          % (len(side.data.polygons), max(p.normal.x for p in side.data.polygons),
             [round(x, 3) for x in PANEL_SAG]))
    print("  skin rays taken: %d, hit x %.3f..%.3f, facet normals %.2f..%.2f"
          % (len(SKIN_HITS), min(h[2] for h in SKIN_HITS), max(h[2] for h in SKIN_HITS),
             min(h[3] for h in SKIN_HITS), max(h[3] for h in SKIN_HITS)))
    for ob in (guns, gear):
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        nm = sum(1 for e in bm.edges if not e.is_manifold)
        bm.free()
        assert nm == 0, "%s is not watertight (%d non-manifold edges)" % (ob.name, nm)
    print("  AC47_Guns and AC47_Gear are watertight closed solids")
    # Prop tip clearance: the whole reason NACELLE_X is not the drawing's 2.88.
    # Measured at the PROP STATION, where the nose is still narrowing - the same
    # reason a real C-47 gets away with 2.88 m on a 2.6 m fuselage.
    hub_y_final = prop_l.location.y
    at_prop = max(abs(v.co.x) for v in air.data.vertices
                  if abs(v.co.y - hub_y_final) < 1.0 and abs(v.co.x) < 1.60)
    gap = NACELLE_X - prop_l_d * 0.5 - at_prop
    assert gap > 0.05, "prop disc cuts the fuselage (clearance %.3f m)" % gap
    print("  fuselage half-width at the prop station %.3f m; inboard prop tip"
          " clears it by %.3f m (real C-47 ~0.25)" % (at_prop, gap))
    # rotor_spin.gd:22-25 - only the two props may look like something that spins
    HINTS = ("prop", "spinner", "blade", "mainrotor", "rotor_hub", "new_blade",
             "rotor_flybar", "new_rotor", "tailrotor", "tailblade")
    for ob in visible + cols + empties:
        low = ob.name.lower()
        trips = any(h in low for h in HINTS)
        assert trips == (ob in (prop_l, prop_r)), \
            "%s: RotorSpin hint match %s is wrong" % (ob.name, trips)
    print("  only AC47_Prop_L / AC47_Prop_R trip a RotorSpin hint")
    for m in bpy.data.materials:
        b = m.node_tree.nodes["Principled BSDF"]
        assert b.inputs["Metallic"].default_value == 0.0, "%s is metallic" % m.name
    print("  materials: %s   image: %s"
          % (sorted(m.name for m in bpy.data.materials),
             [i.name for i in bpy.data.images if i.name != "Render Result"]))
    # His camo UVs must have survived the merge.
    uvl = air.data.uv_layers.active
    uniq = len({(round(d.uv[0], 4), round(d.uv[1], 4)) for d in uvl.data})
    assert uniq > 100, "AC47_Airframe UVs collapsed (%d unique) - his paint is lost" % uniq
    print("  AC47_Airframe carries %d unique UVs (his camo wrap survived)" % uniq)
    clo, chi = bounds(cols)
    assert clo.x <= alo.x + 0.10 and chi.x >= ahi.x - 0.10, "colliders miss the span"
    assert clo.y <= alo.y + 0.30 and chi.y >= ahi.y - 0.30, "colliders miss the length"
    print("  colliders span the airframe in plan (x %.2f..%.2f, y %.2f..%.2f)"
          % (clo.x, chi.x, clo.y, chi.y))
    assert not bad, "QC FAILED on %s" % bad
    print("  QC PASS")

    act = bake_spin((prop_l, prop_r))
    print("  baked action %r on %d slots (%.2f rev/s at 24 fps)"
          % (act.name, len(act.slots), 24.0 / SPIN_FRAMES))

    if render_dir:
        do_render(render_dir, lo, hi)
        for ob in list(bpy.data.objects):
            if ob.type in {"CAMERA", "LIGHT"}:
                bpy.data.objects.remove(ob, do_unlink=True)

    if do_export:
        blend = os.path.join(OUT_DIR, "ac47_spooky_v2.blend")
        glb = os.path.join(OUT_DIR, "ac47_spooky_v2.glb")
        bpy.context.preferences.filepaths.save_version = 0   # project law: no .blend1
        bpy.context.scene.frame_set(0)
        bpy.ops.wm.save_as_mainfile(filepath=blend, compress=False, check_existing=False)
        bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB",
                                  use_selection=False, export_apply=True,
                                  export_yup=True, export_materials="EXPORT",
                                  export_normals=True, export_animations=True,
                                  export_animation_mode="ACTIONS",
                                  export_cameras=False, export_lights=False,
                                  export_extras=False)
        print("EXPORTED %s" % glb)
        print("SAVED    %s" % blend)


# ====================================================================== renders
# azimuth 0 = camera on +X (starboard beam), 90 = ahead of the nose (+Y),
# 180 = the PORT beam, which on this aircraft is the whole point.
VIEWS = [("port", 180.0, 3.0, 1.50), ("threequarter", 214.0, 15.0, 1.50),
         ("front", 90.0, 4.0, 1.50), ("starboard", 0.0, 3.0, 1.50),
         ("rear_quarter", 320.0, 14.0, 1.55), ("underside", 200.0, -26.0, 1.55),
         ("top", 90.0, 86.0, 2.10), ("guns", 200.0, 10.0, 0.20)]
GUN_VIEW_AIM = Vector((-1.30, -5.50, 0.25))


def do_render(out_dir, lo, hi):
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 20
    sc.cycles.use_denoising = True
    sc.cycles.device = "CPU"
    sc.render.resolution_x, sc.render.resolution_y = 1000, 620
    w = bpy.data.worlds.new("W")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.40, 0.48, 0.58, 1.0)
    w.node_tree.nodes["Background"].inputs[1].default_value = 1.15
    sc.world = w
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.4
    sun.data.angle = math.radians(6.0)
    sun.rotation_euler = (math.radians(54.0), 0.0, math.radians(200.0))
    bpy.context.collection.objects.link(sun)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 60.0
    bpy.context.collection.objects.link(cam)
    sc.camera = cam
    tgt = (lo + hi) * 0.5
    span = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z)
    for name, az, el, mul in VIEWS:
        a, e = math.radians(az), math.radians(el)
        aim = GUN_VIEW_AIM if name == "guns" else tgt
        cam.location = aim + Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a),
                                     math.sin(e))) * (span * mul)
        cam.rotation_euler = (aim - Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(out_dir, "ac47v2_%s.png" % name)
        bpy.ops.render.render(write_still=True)
        print("RENDER %s" % sc.render.filepath)


main()
