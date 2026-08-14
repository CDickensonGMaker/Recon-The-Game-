"""Shared surgery kit for the RECONgame crashed-aircraft wrecks.

Every wreck is DERIVED: airframes come from the shipped donor GLBs, the dirt mound
comes from the shipped bomb_crater mesh. Nothing here invents a form from parameters -
it duplicates known-good geometry and moves vertices.

Contract this file enforces, because all three defaults fail silently:
  nose = Blender +Y (== Godot -Z)     lowest z = 0 at the mound's toe
  every collider name ENDS with `-colonly`     no `.` in any exported name
"""
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix, Euler

ROOT = r"C:\Users\caleb\RECONgame"
ART = os.path.join(ROOT, "assets")
AIR = os.path.join(ART, "us", "aircraft")
RUINS = os.path.join(ART, "world", "building models", "structures", "ruins")
FB_TEX = os.path.join(ART, "world", "building models", "structures", "firebase", "tex")

CRATER_GLB = os.path.join(RUINS, "bomb_crater.glb")

SOOT = (0.055, 0.048, 0.043, 1.0)      # rubble_field_wide's own `charred` value, darkened
EARTH_TINT = (0.42, 0.31, 0.21, 1.0)


# ----------------------------------------------------------------- scene basics
def wipe():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.context.scene.unit_settings.system = 'METRIC'


def meshes():
    return [o for o in bpy.context.scene.objects if o.type == 'MESH']


def by_name(name):
    return bpy.context.scene.objects.get(name)


def deselect():
    for o in bpy.context.scene.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = None


def import_glb(path, flatten=True):
    """Import and (by default) bake every parent/object transform into the vertices,
    so all later maths happens in one space. A glTF import parents meshes under an
    axis-correction empty; ignoring that is how edits land in the wrong place."""
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.context.scene.objects if o not in before]
    if flatten:
        deselect()
        for o in new:
            if o.type == 'MESH':
                o.select_set(True)
        if any(o.type == 'MESH' for o in new):
            bpy.context.view_layer.objects.active = next(o for o in new if o.type == 'MESH')
            bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
            # Single-user the mesh data first. huey_v3 shares one datablock between its
            # two M60s, two medical crates and three M16s, and transform_apply refuses
            # multi-user data outright ("Cannot apply to a multi user") - it aborts the
            # whole call, so NOTHING gets flattened and every later edit lands in the
            # donor's un-baked space.
            for o in new:
                if o.type == 'MESH' and o.data.users > 1:
                    o.data = o.data.copy()
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        # rebuild the kept list BEFORE deleting: a removed Object leaves a dead
        # StructRNA in any list still holding it, and touching `.type` then raises.
        keep = [o for o in new if o.type == 'MESH']
        for o in [o for o in new if o.type != 'MESH']:
            bpy.data.objects.remove(o, do_unlink=True)
        new = keep
    deselect()
    return {o.name: o for o in new}


def drop(*objs):
    for o in objs:
        if o is None:
            continue
        if isinstance(o, str):
            o = by_name(o)
        if o is not None:
            bpy.data.objects.remove(o, do_unlink=True)


def keep_only(names):
    keep = set(names)
    for o in list(meshes()):
        if o.name not in keep:
            bpy.data.objects.remove(o, do_unlink=True)


# ----------------------------------------------------------------- measurement
def verts(obj):
    return [obj.matrix_world @ v.co for v in obj.data.vertices]


def bbox(objs):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        for p in verts(o):
            for i in range(3):
                lo[i] = min(lo[i], p[i])
                hi[i] = max(hi[i], p[i])
    return lo, hi


def tris(objs=None):
    objs = objs if objs is not None else meshes()
    n = 0
    for o in objs:
        o.data.calc_loop_triangles()
        n += len(o.data.loop_triangles)
    return n


def vcount(objs=None):
    objs = objs if objs is not None else meshes()
    return sum(len(o.data.vertices) for o in objs)


# ----------------------------------------------------------------- surgery
def edit_verts(obj, fn):
    """fn(world_position) -> new world position. Object matrices are identity after
    import_glb(flatten=True), but compose them anyway so this is safe anywhere."""
    mw = obj.matrix_world
    inv = mw.inverted()
    for v in obj.data.vertices:
        v.co = inv @ fn(mw @ v.co)
    obj.data.update()


def face_centres(obj):
    mw = obj.matrix_world
    return [mw @ p.center for p in obj.data.polygons]


def split_faces(obj, pred, newname):
    """Cut `obj` in two along existing edges. Faces whose CENTRE satisfies `pred` move
    to a new object. Classify per polygon, never per vertex - a per-vertex test leaks
    across the seam and takes neighbouring faces with it."""
    new = obj.copy()
    new.data = obj.data.copy()
    new.name = newname
    new.data.name = newname
    bpy.context.scene.collection.objects.link(new)

    for target, want in ((new, True), (obj, False)):
        mw = target.matrix_world
        bm = bmesh.new()
        bm.from_mesh(target.data)
        bm.faces.ensure_lookup_table()
        kill = [f for f in bm.faces if (pred(mw @ f.calc_center_median()) is not want)]
        if kill:
            bmesh.ops.delete(bm, geom=kill, context='FACES')
        bm.to_mesh(target.data)
        bm.free()
        target.data.update()
    if len(new.data.polygons) == 0:
        bpy.data.objects.remove(new, do_unlink=True)
        return None
    return new


def cut_at(obj, axis, at, newname, fill=True):
    """Bisect a piece on a PLANE. `obj` keeps the positive side, `newname` the negative.

    split_faces() cannot do this and fails silently when asked. It classifies EXISTING
    faces by their centre, so it can only cut where a face boundary already runs. A Huey
    rotor blade is one six-face box spanning 7.3 m - every long face has its centre at
    mid-span, so a centre test hands both halves nearly the whole blade. Measured: asking
    for a 3.9 m stub returned a 7.79 m stub and a 7.23 m fragment, and both objects then
    passed every downstream check because each was a perfectly valid blade.
    """
    new = obj.copy()
    new.data = obj.data.copy()
    new.name = newname
    new.data.name = newname
    bpy.context.scene.collection.objects.link(new)
    n = Vector((0.0, 0.0, 0.0))
    n[axis] = 1.0
    co = Vector((0.0, 0.0, 0.0))
    co[axis] = at
    for target, keep_pos in ((obj, True), (new, False)):
        bm = bmesh.new()
        bm.from_mesh(target.data)
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:],
                               dist=1e-5, plane_co=co, plane_no=n,
                               clear_inner=keep_pos, clear_outer=not keep_pos)
        if fill:
            bmesh.ops.holes_fill(bm, edges=bm.edges[:], sides=8)
        bm.to_mesh(target.data)
        bm.free()
        target.data.update()
    if len(new.data.polygons) == 0:
        bpy.data.objects.remove(new, do_unlink=True)
        return None
    return new


def split_material(obj, name_sub, newname):
    """Split off every face carrying a material whose name contains `name_sub`.
    Exact, unlike matching face-centre coordinates between two bmesh builds."""
    idxs = {i for i, m in enumerate(obj.data.materials) if m and name_sub in m.name}
    if not idxs:
        return None
    new = obj.copy()
    new.data = obj.data.copy()
    new.name = newname
    new.data.name = newname
    bpy.context.scene.collection.objects.link(new)
    for target, want in ((new, True), (obj, False)):
        bm = bmesh.new()
        bm.from_mesh(target.data)
        bm.faces.ensure_lookup_table()
        kill = [f for f in bm.faces if ((f.material_index in idxs) is not want)]
        if kill:
            bmesh.ops.delete(bm, geom=kill, context='FACES')
        bm.to_mesh(target.data)
        bm.free()
        target.data.update()
    if len(new.data.polygons) == 0:
        bpy.data.objects.remove(new, do_unlink=True)
        return None
    return new


def tear_seam(obj, plane_axis, plane_at, band=0.10, amp=0.075, seed=1):
    """Ragged the cut edge. Aluminium never parts on a clean plane (ref: every surviving
    panel at the fighter site is an irregular torn sheet), and a straight cut is the tell
    that reads as 'sliced in Blender'."""
    rng = random.Random(seed)
    def f(p):
        if abs(p[plane_axis] - plane_at) <= band:
            q = p.copy()
            q[plane_axis] += rng.uniform(-amp, amp * 1.6)
            q[(plane_axis + 1) % 3] += rng.uniform(-amp, amp) * 0.6
            q[2] += rng.uniform(-amp, amp) * 0.5
            return q
        return p
    edit_verts(obj, f)


def crush(obj, floor_z, k_at, widen=0.30, y_axis=1):
    """Proportional vertical collapse about `floor_z`. `k_at(y)` returns the surviving
    height fraction at that station, so the nose can be flattened while the tail is not.
    Squashed mass has to go somewhere - `widen` bulges it sideways, which is what makes
    this read as CRUSHED rather than merely scaled."""
    def f(p):
        k = k_at(p[y_axis])
        q = p.copy()
        q[2] = floor_z + (p[2] - floor_z) * k
        q[0] = p[0] * (1.0 + widen * (1.0 - k))
        return q
    edit_verts(obj, f)


def buckle(obj, hinge_y, angle_deg, hinge_z=0.0, only_aft=True):
    """Kink the airframe over a station - the fuselage folds at the wing box, it does
    not bend in a smooth arc.

    `hinge_z` MUST be the keel line, not 0. Folding about z=0 swings the aft belly far
    below the airframe, and any later 'sit it on the ground' pass then lifts the whole
    wreck by that error - which is how a crushed aeroplane ends up taller than it started.
    Positive angle raises the tail (nose-in, tail-up: the plough-in silhouette).
    """
    a = math.radians(angle_deg)
    ca, sa = math.cos(a), math.sin(a)
    def f(p):
        aft = (p[1] < hinge_y) if only_aft else (p[1] > hinge_y)
        if not aft:
            return p
        dy = p[1] - hinge_y
        dz = p[2] - hinge_z
        return Vector((p[0], hinge_y + dy * ca - dz * sa, hinge_z + dy * sa + dz * ca))
    edit_verts(obj, f)


def rigid(obj, translate=(0, 0, 0), rot_deg=(0, 0, 0), pivot=None):
    """Move a piece without reshaping it. A thrown wing keeps its planform - it is a
    stiff box structure and lands intact."""
    piv = Vector(pivot) if pivot is not None else sum(
        (p for p in verts(obj)), Vector()) / max(1, len(obj.data.vertices))
    m = Euler([math.radians(a) for a in rot_deg], 'XYZ').to_matrix().to_4x4()
    t = Vector(translate)
    def f(p):
        return (m @ (p - piv)) + piv + t
    edit_verts(obj, f)


def bend_blades(obj, hub, radial_axes=(0, 2), span_axis=1, sweep=0.45, curl=0.35,
                shorten=0.12, rmin=0.35):
    """Sweep propeller/rotor blades AFT as a function of radius, with a curled tip.

    NTSB wreckage language for an engine making power at impact: multiple aft bends,
    ~45 deg at the tip, tips curled, twisted toward low pitch. A straight blade is the
    signature of an engine that was ALREADY STOPPED - wrong for a burning fresh crash.
    """
    ra, rb = radial_axes
    pts = verts(obj)
    R = max(math.hypot(p[ra] - hub[ra], p[rb] - hub[rb]) for p in pts)
    def f(p):
        dr = math.hypot(p[ra] - hub[ra], p[rb] - hub[rb])
        if dr <= rmin or R <= rmin:
            return p
        t = (dr - rmin) / (R - rmin)
        q = p.copy()
        q[span_axis] = p[span_axis] - (sweep * R * t * t) - (curl * R * max(0.0, t - 0.72) ** 2 * 6.0)
        s = 1.0 - shorten * t * t
        q[ra] = hub[ra] + (p[ra] - hub[ra]) * s
        q[rb] = hub[rb] + (p[rb] - hub[rb]) * s
        return q
    edit_verts(obj, f)


def dent(obj, centre, radius, depth, seed=3):
    """Push a local region in along -Z-ish, for intake/nose crumple."""
    rng = random.Random(seed)
    c = Vector(centre)
    def f(p):
        d = (p - c).length
        if d >= radius:
            return p
        w = (1.0 - d / radius) ** 2
        q = p.copy()
        q[2] -= depth * w
        q[1] += depth * w * 0.5
        q[0] += rng.uniform(-0.04, 0.04) * w
        return q
    edit_verts(obj, f)


def crumple(obj, amp=0.05, seed=7):
    """Low-amplitude per-vertex noise. Panel skin is never flat after a crash - but keep
    it small or the PSX silhouette turns to mush."""
    rng = random.Random(seed)
    def f(p):
        return p + Vector((rng.uniform(-amp, amp), rng.uniform(-amp, amp),
                           rng.uniform(-amp, amp)))
    edit_verts(obj, f)


# ----------------------------------------------------------------- orientation
def principal_axes(obj):
    """Vertex-cloud principal axes, longest first: [(extent, unit Vector)] x3.

    The THIN axis is a flat piece's plate normal, and it is the only honest way to ask
    which way a panel faces. A bounding box cannot answer it once the piece has been
    rotated, and an author-side Euler cannot either once two rotations have composed.
    """
    import numpy as np
    P = np.array([[p.x, p.y, p.z] for p in verts(obj)])
    if len(P) < 4:
        return None
    C = P - P.mean(axis=0)
    _, _, vt = np.linalg.svd(C, full_matrices=False)
    out = []
    for i in range(3):
        proj = C @ vt[i]
        out.append((float(proj.max() - proj.min()), Vector(vt[i])))
    out.sort(key=lambda t: -t[0])
    return out


def plate_tilt(obj):
    """(tilt_deg, is_plate). tilt 0 = the piece lies flat, 90 = it stands on its edge.

    THE defect this exists to catch, because every seating number passed while it shipped:
    `min clearance -0.10 m` is equally true of a panel lying half-buried in the dirt and
    of one driven into the ground like a signpost. Clearance measures CONTACT.
    Orientation is a different question and needs its own measurement.
    """
    ax = principal_axes(obj)
    if ax is None:
        return None, False
    return (math.degrees(math.acos(min(1.0, abs(ax[2][1].z)))),
            ax[2][0] < 0.28 * ax[1][0])


def lay_flat(obj, tilt_deg=0.0, tilt_dir_deg=0.0, spin_deg=0.0):
    """Rotate a thin piece about its own centroid until its plate faces the sky, then
    apply a deliberate residual tilt.

    Solves for the piece's MEASURED normal rather than composing Eulers, so it is immune
    both to the donor's part orientation and to whatever rotations already ran on it.
    """
    ax = principal_axes(obj)
    if ax is None:
        return None
    n = ax[2][1]
    if n.z < 0.0:
        n = -n
    m = n.rotation_difference(Vector((0.0, 0.0, 1.0))).to_matrix().to_4x4()
    a = math.radians(tilt_dir_deg)
    m = (Matrix.Rotation(math.radians(tilt_deg), 4,
                         Vector((math.cos(a), math.sin(a), 0.0)))
         @ Matrix.Rotation(math.radians(spin_deg), 4, 'Z') @ m)
    piv = sum((p for p in verts(obj)), Vector()) / len(obj.data.vertices)
    edit_verts(obj, lambda p: (m @ (p - piv)) + piv)
    return plate_tilt(obj)[0]


def place_at(obj, x, y, z=None):
    """Translate a piece so its centroid lands at a chosen plan position. An offset
    composed against the donor's own coordinates is unreadable, and it silently moves the
    moment any earlier edit shifts the part."""
    pts = verts(obj)
    c = sum((p for p in pts), Vector()) / len(pts)
    edit_verts(obj, lambda p: p + Vector((x - c.x, y - c.y,
                                          0.0 if z is None else z - c.z)))


def bend_mid(obj, angle_deg, frac=0.55, toward=None):
    """Kink a long piece upward about a station along its own longest axis. A thrown rotor
    blade is always bent; a straight one lying on flat ground reads as a dropped ruler.

    `toward` (an x,y direction) picks WHICH END rises, and passing it is not optional
    housekeeping: an SVD eigenvector's sign is arbitrary, so without it the kink lifts a
    coin-flip end. It flattened a deliberately tilted blade back to a dead-level plank and
    every clearance number still read healthy.
    """
    ax = principal_axes(obj)
    if ax is None:
        return
    L = Vector((ax[0][1].x, ax[0][1].y, 0.0))
    if L.length < 1e-6:
        return
    L.normalize()
    if toward is not None and L.dot(Vector((toward[0], toward[1], 0.0))) < 0.0:
        L = -L
    pts = verts(obj)
    piv = sum((p for p in pts), Vector()) / len(pts)
    s = [(p - piv).dot(L) for p in pts]
    cut = min(s) + (max(s) - min(s)) * frac
    # axis = L turned -90 deg in plan, so a POSITIVE angle lifts the outboard end
    rot = Matrix.Rotation(math.radians(angle_deg), 4, Vector((L.y, -L.x, 0.0)))
    hinge = piv + L * cut
    def f(p):
        return p if (p - piv).dot(L) <= cut else (rot @ (p - hinge)) + hinge
    edit_verts(obj, f)


def assert_lying_flat(names, mound, limit=25.0, min_contact=0.25, near=0.10):
    """SUPERSEDED by assert_debris_grounded(). Live only for the A-1 and the F-4, which
    have not been rebuilt on the derived gate (2026-08-14). Delete it when they are.

    Two numbers, because each hides a defect the other passes:
      tilt    - a plank standing on its end still seats at negative clearance, which is
                how a door and a rotor blade shipped as sign-boards
      contact - fraction of the piece within `near` of the ground. seat_on_mound() drops a
                piece until its LOWEST vertex touches, so one corner on a berm scores a
                perfect clearance while the rest hangs in daylight. A deliberately KINKED
                piece still passes this, where a max-gap test would convict it.

    Its fatal flaw is not either number: it is that `names` is written by hand. Three
    pieces were listed, the scene held twenty-nine, and the ones nobody thought to type
    were never measured at all.
    """
    bad = []
    for entry in names:
        # an entry may carry its own limit: a thrown WING legitimately lands on edge
        # (ref obs 8) where a door or a blade never does
        nm, lim = entry if isinstance(entry, tuple) else (entry, limit)
        o = by_name(nm)
        if o is None:
            continue
        t, is_plate = plate_tilt(o)
        cl = [p.z - mound_height_at(mound, p.x, p.y) for p in verts(o)]
        con = sum(1 for c in cl if c < near) / float(len(cl))
        print("   flat check %-30s tilt %5.1f /%4.0f  clearance %6.2f..%5.2f  "
              "contact %3.0f%%  %s" % (nm, t, lim, min(cl), max(cl), con * 100.0,
                                       "PLATE" if is_plate else "rod"))
        if is_plate and t > lim:
            bad.append((nm, "tilt %.1f" % t))
        if con < min_contact:
            bad.append((nm, "contact %.0f%%" % (con * 100.0)))
    if bad:
        raise SystemExit("FATAL: thrown debris not lying on the ground: %s" % bad)


# --------------------------------------------------- the derived debris gate
def ground_clear(obj, mound, reach=1.6):
    """Per-vertex clearance above the mound surface as a numpy array.

    Vectorised twin of mound_height_at(), same inverse-distance-squared weighting and
    the same `reach` cut-off to bare terrain. The gate samples EVERY vertex of EVERY
    piece in the scene; the scalar version is O(piece verts x mound verts) in Python.

    Deliberately builds the mound array on every call. Caching it is a silent-wrong-
    answer trap: edit_verts() mutates the mound in place, so the vertex COUNT never
    changes and no cheap cache key can tell a stale array from a live one.
    """
    import numpy as np
    M = np.array([[p.x, p.y, p.z] for p in verts(mound)])
    P = np.array([[p.x, p.y, p.z] for p in verts(obj)])
    d = np.sqrt((P[:, None, 0] - M[None, :, 0]) ** 2
                + (P[:, None, 1] - M[None, :, 1]) ** 2)
    w = np.where(d < reach, 1.0 / np.maximum(0.08, d) ** 2, 0.0)
    den = w.sum(axis=1)
    gz = np.where(den > 0.0, (w * M[None, :, 2]).sum(axis=1) / np.maximum(den, 1e-12), 0.0)
    gz = np.where(d.min(axis=1) >= reach, 0.0, gz)
    return P[:, 2] - gz


def surface_gap(a, b, samples=300):
    """Smallest distance from b's vertices to a's SURFACE, in world units.

    Vertex-to-vertex is not good enough here: a skid rail and the fuselage it is bolted
    to are separate meshes whose nearest VERTICES can be half a metre apart across a
    single large triangle, and the pair then reads as unconnected.
    """
    inv = a.matrix_world.inverted()
    pts = verts(b)
    step = max(1, len(pts) // samples)
    best = 1e9
    for p in pts[::step]:
        try:
            ok, hit, _n, _i = a.closest_point_on_mesh(inv @ p)
        except RuntimeError:
            return 1e9          # hidden object: no evaluated mesh, do not guess
        if ok:
            best = min(best, ((a.matrix_world @ hit) - p).length)
    return best


def touch_clusters(objs, gap=0.30):
    """Group pieces that TOUCH, derived from geometry alone - no names, no hand list.

    This is what makes the debris gate impossible to slip past. `wreck_soft_boom_tail_fin`
    stands at 76 deg and legitimately so: it is bolted to a boom that reaches the ground.
    A thrown blade at 76 deg is a defect. The only honest difference between them is
    whether the piece is part of an assembly that is holding it up - so measure THAT,
    rather than trusting whoever typed the list to know which is which.
    """
    n = len(objs)
    parent = list(range(n))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    box = [bbox([o]) for o in objs]
    for i in range(n):
        for j in range(i + 1, n):
            if find(i) == find(j):
                continue
            (li, hi_), (lj, hj) = box[i], box[j]
            if any(li[k] - gap > hj[k] or lj[k] - gap > hi_[k] for k in range(3)):
                continue        # AABBs cannot touch - cheap reject
            # AABB overlap is NOT contact. A 7 m blade lying diagonally has a bounding
            # box that swallows half the scatter; confirm against the real surface.
            big, small = ((objs[i], objs[j])
                          if len(objs[i].data.vertices) >= len(objs[j].data.vertices)
                          else (objs[j], objs[i]))
            if surface_gap(big, small) <= gap:
                parent[find(j)] = find(i)
    out = {}
    for i, o in enumerate(objs):
        out.setdefault(find(i), []).append(o)
    return sorted(out.values(), key=lambda g: -len(g))


def assert_debris_grounded(mound, view_az=(), limit=25.0, min_contact=0.25, near=0.10,
                           gap=0.30, excuse=(), plank_deg=22.0, plank_aspect=6.0,
                           strict=True):
    """THE debris gate. Enumerates every exported piece FROM THE SCENE and measures all
    of them, then decides what each one is allowed to do from its own connectivity.

    Replaces a hand list of three names that a scene of twenty-nine pieces walked past.
    A hand list can only ever check what somebody remembered to type, and the pieces
    that ship wrong are by definition the ones nobody thought about.

    Three convictions, and the third is the one numbers alone kept missing:
      ungrounded  - a cluster whose lowest point never reaches the ground is floating,
                    whatever its tilt says. Applies to assemblies too.
      lying down  - a LONE plate must lie flat and touch over a real fraction of itself.
                    A piece inside a grounded assembly is exempt: a tail fin at 76 deg is
                    bolted to a boom, and convicting it would be measuring the wrong thing.
      end-on      - a long thin piece whose plan heading points at a render camera
                    projects to a vertical bar and READS as a standing plank even when it
                    is measurably flat on the ground. Both thrown Huey blades passed tilt
                    at 3.3 and 5.5 deg while lying within 13 deg of the threequarter
                    camera's azimuth, and the render was judged - correctly - as showing a
                    plank on end. Geometry that is right and reads wrong is still wrong.
    """
    ex = dict(excuse)
    objs = [o for o in meshes() if not o.name.endswith("-colonly") and o is not mound]
    groups = touch_clusters(objs, gap=gap)
    print("   debris gate: %d pieces enumerated from the scene -> %d clusters %s"
          % (len(objs), len(groups), [len(g) for g in groups]))
    print("   %-32s %3s %5s %5s %5s %7s %7s %6s %6s  %s"
          % ("piece", "cl", "tilt", "lim", "cont", "clr_lo", "clr_hi", "headg",
             "aspct", "verdict"))
    bad = []
    for ci, grp in enumerate(groups):
        cl = {o.name: ground_clear(o, mound) for o in grp}
        grounded = min(float(v.min()) for v in cl.values()) <= near
        if not grounded:
            bad.append(("cluster %d %s" % (ci, [o.name for o in grp]),
                        "floating, lowest point %.2f m above ground"
                        % min(float(v.min()) for v in cl.values())))
        for o in sorted(grp, key=lambda x: x.name):
            t, is_plate = plate_tilt(o)
            ax = principal_axes(o)
            asp = ax[0][0] / max(1e-6, ax[1][0])
            head = math.degrees(math.atan2(ax[0][1].y, ax[0][1].x)) % 180.0
            c = cl[o.name]
            con = float((c < near).mean())
            lim = ex.get(o.name, limit)
            v = []
            if not grounded:
                v.append("FLOATING")
            if len(grp) == 1:
                # a lone piece has nothing holding it up, so it answers for itself
                if is_plate and t > lim:
                    v.append("TILT")
                    bad.append((o.name, "tilt %.1f > %.0f" % (t, lim)))
                if con < min_contact:
                    v.append("CONTACT")
                    bad.append((o.name, "contact %.0f%%" % (con * 100.0)))
                if asp >= plank_aspect and view_az:
                    m = min(abs(((head - a + 90.0) % 180.0) - 90.0) for a in view_az)
                    if m < plank_deg:
                        v.append("END-ON %.0f" % m)
                        bad.append((o.name, "heading %.0f is %.0f deg off a render "
                                            "azimuth - reads as a standing plank"
                                    % (head, m)))
            print("   %-32s %3d %5.1f %5.0f %4.0f%% %7.2f %7.2f %6.1f %6.1f  %s"
                  % (o.name, ci, t, lim if len(grp) == 1 else 0, con * 100.0,
                     float(c.min()), float(c.max()), head, asp,
                     " ".join(v) if v else ("ok" if len(grp) == 1 else "assembly")))
    if bad:
        msg = "FATAL: debris gate: %s" % bad
        if strict:
            raise SystemExit(msg)
        print("   REPORT-ONLY %s" % msg)


# ----------------------------------------------------------------- materials
def flat_mat(name, colour, rough=0.9):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs['Base Color'].default_value = colour
    b.inputs['Roughness'].default_value = rough
    if 'Metallic' in b.inputs:
        b.inputs['Metallic'].default_value = 0.0
    m.diffuse_color = colour
    return m


def image_mat(name, png, colour, scale=1.6):
    """Box-projected image material at the firebase kit's own texel density."""
    m = flat_mat(name, colour)
    if not os.path.exists(png):
        return m
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    img = bpy.data.images.get(os.path.basename(png))
    if img is None:
        img = bpy.data.images.load(png, check_existing=True)
    img.pack()
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = img
    tex.projection = 'BOX'
    tex.projection_blend = 0.35
    tex.extension = 'REPEAT'
    tex.interpolation = 'Closest'
    co = nt.nodes.new('ShaderNodeTexCoord')
    mp = nt.nodes.new('ShaderNodeMapping')
    mp.inputs['Scale'].default_value = (1.0 / scale, 1.0 / scale, 1.0 / scale)
    nt.links.new(co.outputs['Object'], mp.inputs['Vector'])
    nt.links.new(mp.outputs['Vector'], tex.inputs['Vector'])
    nt.links.new(tex.outputs['Color'], b.inputs['Base Color'])
    return m


def scorch(objs, centres, radius, seed=11, mat=None, core=0.34):
    """Assign a soot material to faces near the burn seats. Fresh burn is SOOT ON METAL,
    not rust and not overgrowth - the whole point of Caleb's brief.

    DITHERED, not a hard disc. A distance cutoff turns the whole nose solid black,
    because the donor's triangle density is concentrated exactly where the fire seats
    are - the first pass sooted 2,556 of 2,754 faces and the aeroplane stopped reading
    as an aeroplane. Probability falls off with distance, so the burn speckles out into
    the camo, which is also the cheapest PSX-correct gradient there is.
    """
    mat = mat or flat_mat("wreck_soot", SOOT, rough=0.95)
    rng = random.Random(seed)
    cs = [Vector(c) for c in centres]
    touched, total = 0, 0
    for o in objs:
        if mat.name not in [m.name for m in o.data.materials if m]:
            o.data.materials.append(mat)
        idx = [i for i, m in enumerate(o.data.materials) if m and m.name == mat.name][0]
        mw = o.matrix_world
        for p in o.data.polygons:
            total += 1
            c = mw @ p.center
            d = min((c - k).length for k in cs)
            if d >= radius:
                continue
            t = 1.0 - d / radius
            prob = 1.0 if t > (1.0 - core) else t ** 0.75
            if rng.random() < prob:
                p.material_index = idx
                touched += 1
        o.data.update()
    return touched, total


def pnoise(x, y, seed=0):
    """Deterministic value noise keyed on POSITION, in -1..1.

    Never use random.uniform() to displace a mesh: it is drawn per call, so two
    coincident vertices of an unwelded surface receive different offsets and the mesh
    tears. A positional hash gives identical vertices identical displacement.
    """
    s = math.sin(x * 12.9898 + y * 78.233 + seed * 3.71) * 43758.5453
    return (s - math.floor(s)) * 2.0 - 1.0


# ----------------------------------------------------------------- the mound
def _lobe(th, lobes):
    """Bearing-dependent radius multiplier, capped at 1.0.

    `lobes` is a list of (harmonic, amplitude, phase_deg). The cap matters: the profile is
    tapered to zero at `1.04 * lobe` of the crater donor's OWN half-extent, so a multiplier
    above 1.0 would push the zero contour past the last ring of vertices and the mound
    would end in a cliff instead of a toe.
    """
    if not lobes:
        return 1.0
    tot = sum(abs(a) for _, a, _ in lobes)
    return 1.0 - tot + sum(a * math.cos(k * (th - math.radians(ph)))
                           for k, a, ph in lobes)


def build_mound(name, half_x, half_y, nose_y, tail_y, berm_h, furrow_d,
                hull_hw=1.5, seed=5, tex=True, subdiv=1,
                lobes=(), ridge_rear=0.62, ridge_fwd=1.196, rear_fade=None,
                nose_gain=1.30, nose_reach=1.90, nose_sig=1.70, nose_wx=0.72,
                nose_skew=0.0, furrow_w=1.0, centre_y=None, churn=1.0, rim_noise=0.0):
    """Sculpt the plough scar out of the shipped `bomb_crater` mesh.

    The crater supplies the geometry, the topology, the churn and the material - this
    moves its vertices onto a plough profile. Three things had to be learned the hard
    way, all of them visible only in a render:

    * `bomb_crater` is a CLOSED VOLUME (bowl + underside skirt, 840 v / 396 t). Flatten
      the bowl and the two surfaces land on top of each other, and the mound renders
      covered in bright hairline slivers of z-fighting. Keep the top sheet only.
    * Re-keying the crater's OWN z into a berm height cannot survive the edge taper and
      the walkability clamp - it flattens to a pancake disc and the aeroplane ends up
      lying ON the ground instead of in it. The relief has to be driven explicitly from
      the airframe's own geometry; the crater's z is kept only as surface churn.
    * The berm is not a ring. Ejecta piles ahead of and beside the airframe and leaves
      the entry furrow open behind it (ref obs 5/6). The flank ridges therefore have to
      DIE OUT behind the tail (`ridge_rear`, `rear_fade`) - carried at full height the
      whole length they meet round the back and the wreck reads as a plane in a mud
      puddle, which is defect 5's exact wording.
    * The outline must not be a circle or a smooth oval either. `lobes` warps the taper
      radius by bearing so the rim carries 2-3 asymmetric bulges; without it every angle
      shows the same ellipse. Verified by `rim_report`, not by eye alone.
    """
    got = import_glb(CRATER_GLB)
    src = next(iter(got.values()))
    src.name = name
    src.data.name = name

    bm = bmesh.new()
    bm.from_mesh(src.data)
    skirt = [f for f in bm.faces if f.normal.z <= 0.05]
    if skirt:
        bmesh.ops.delete(bm, geom=skirt, context='FACES')
    # WELD FIRST, and this is not housekeeping - it is the fix.
    # bomb_crater ships UNWELDED: 840 verts / 396 tris with 840 boundary edges, i.e.
    # a soup of separate triangles whose corners merely coincide. Displacing that with
    # any per-VERTEX random term hands two coincident duplicates different offsets, the
    # triangles tear apart, and the mound renders shot through with bright hairline
    # slivers and black gaps. Weld, then displace by a function of POSITION only.
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.004)
    for _ in range(subdiv):
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True)
    bm.to_mesh(src.data)
    bm.free()
    src.data.update()
    print("  mound donor after weld/subdiv: %d tris, %d verts" %
          (len(src.data.polygons), len(src.data.vertices)))

    pts = verts(src)
    lo = Vector((min(p[i] for p in pts) for i in range(3)))
    hi = Vector((max(p[i] for p in pts) for i in range(3)))
    cx = (lo.x + hi.x) / 2.0
    cy = (lo.y + hi.y) / 2.0
    rx = (hi.x - lo.x) / 2.0
    ry = (hi.y - lo.y) / 2.0
    z_lo, z_hi = lo.z, hi.z

    mid_y = centre_y if centre_y is not None else (nose_y + tail_y) / 2.0

    def f(p):
        # normalised crater coords
        u = (p.x - cx) / rx                       # -1..1
        v = (p.y - cy) / ry
        r = math.hypot(u, v)
        th = math.atan2(v, u)
        # z as a 0..1 depth key: 0 at the rim crest, 1 at the pit floor
        key = (z_hi - p.z) / max(1e-6, (z_hi - z_lo))

        x = u * half_x
        y = mid_y + v * half_y
        ax = abs(x)

        # how far along the ploughed run this point is: 1 at the nose, 0 at the tail
        run = (y - tail_y) / max(0.5, nose_y - tail_y)

        # --- the bed the airframe lies in: a low apron under and beside the hull, so
        #     earth comes UP THE SIDES rather than over the top
        h = berm_h * 0.10 * math.exp(-((ax / (hull_hw * 2.6)) ** 2))

        # --- flanking spoil ridges, shouldered out either side of the hull and taller
        #     towards the nose where the plough was still deep. They must fall away aft
        #     or they join behind the tail and close the berm into a ring.
        g = ridge_rear + (ridge_fwd - ridge_rear) * max(0.0, min(1.0, run / 1.2))
        if rear_fade is not None and run < 0.0:
            g *= math.exp(-((run / rear_fade) ** 2))
        ridge = berm_h * g
        h += ridge * math.exp(-(((ax - hull_hw * 1.55) / (hull_hw * 1.15)) ** 2)) \
             * math.exp(-max(0.0, (run - 1.25)) ** 2 * 3.0)

        # --- the pile thrown up ahead of the nose, the deepest part of the gouge, and
        #     the one lobe that has to dominate: ejecta is thickest along the travel
        #     direction, and `nose_skew` throws it to one side so it is not a crescent
        dy = y - (nose_y + nose_reach)
        h += berm_h * nose_gain * math.exp(
            -((dy / nose_sig) ** 2) - (((x - nose_skew) / (half_x * nose_wx)) ** 2))

        # --- the SLOT the hull lies in. Without it the spoil closes over the top and
        #     the aeroplane vanishes: measured 60% of hull height buried and only 0.4 m
        #     proud. Earth must come up the SIDES of a ploughed-in airframe.
        if -0.30 < run < 1.40:
            h -= berm_h * 0.54 * math.exp(-((ax / (hull_hw * 1.45)) ** 2))

        # --- the entry furrow, open behind on the centreline
        behind = (tail_y - y) / max(1.0, half_y)
        if behind > 0.0:
            h -= furrow_d * math.exp(-(x * x) / (hull_hw * hull_hw * 3.2 * furrow_w)) \
                 * min(1.0, behind * 2.2)

        # --- churn: the crater's OWN surface relief, kept small and scaled by its z key
        # `churn` scales the two NOISE terms only. Scaling the crater's own z key with it
        # inflates a broad smooth apron across the whole footprint instead, and the mound
        # reads as a flat brown puddle with the wreck sitting on top of it.
        h += (0.5 - key) * 0.20
        h += 0.09 * churn * math.sin(u * 5.1 + v * 3.3) * math.cos(v * 4.7 - u * 2.1)
        h += 0.055 * churn * pnoise(x, y, seed)

        # --- taper to zero at the rim so there is no step against the terrain, on a
        #     radius that wobbles with bearing so the outline is not an oval
        # rim_noise only ever pulls the toe INWARD, so the taper can never finish outside
        # the donor's last ring of vertices and end in a cliff
        lb = _lobe(th, lobes) * (1.0 - rim_noise
                                 * (0.5 + 0.5 * pnoise(x * 0.55, y * 0.55, seed + 3)))
        t0, t1 = 0.70 * lb, 1.04 * lb
        h *= max(0.0, 1.0 - max(0.0, (r - t0) / (t1 - t0)) ** 1.2)
        return Vector((x, y, max(-furrow_d, h)))

    edit_verts(src, f)
    clean_mesh(src)
    limit_slope(src, 27.0, iters=90)
    src.data.materials.clear()
    if tex:
        src.data.materials.append(image_mat(
            "wreck_earth", os.path.join(FB_TEX, "fb_earth.png"), EARTH_TINT, scale=2.2))
    else:
        src.data.materials.append(flat_mat("wreck_earth", EARTH_TINT))
    return src


def clean_mesh(obj, merge=0.025):
    """Weld and drop zero-area faces.

    Re-profiling the crater squashes its 3 m pit wall almost flat, which leaves rings of
    near-degenerate triangles. They render as bright hairline slivers scattered over the
    whole mound and read as cracks in the ground - a defect that is invisible in every
    number the build prints and obvious in the first render.
    """
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=merge)
    kill = [f for f in bm.faces if f.calc_area() < 1e-5]
    if kill:
        bmesh.ops.delete(bm, geom=kill, context='FACES')
    # NEVER recalc_face_normals on this mesh. The mound is an OPEN sheet, and the
    # "make normals consistent" solver has no outside to point away from - it orients
    # each island arbitrarily, so patches of ground flip downward and render as black
    # holes in the earth. A heightfield has an exact rule instead: up is up.
    for f in bm.faces:
        if f.normal.z < 0.0:
            f.normal_flip()
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def seat_on_mound(obj, mound, bury=0.06):
    """Drop a loose piece until it rests on the mound's ACTUAL surface.

    Debris was placed at a fixed world z before the mound existed, so anything landing on
    the berm hung in mid-air. Sample the ground, then seat - never assume z=0 is ground
    once you have built terrain of your own.
    """
    # Sample the ground UNDER EVERY VERTEX and use the smallest clearance, not the
    # height under the bbox centre. A thrown wing lying diagonally has its centre over
    # the berm and its ends out on flat ground; seating it by the centre leaves the
    # whole panel hanging in the air with daylight under it.
    clear = min(p.z - mound_height_at(mound, p.x, p.y) for p in verts(obj))
    d = -(clear + bury)
    edit_verts(obj, lambda p: p + Vector((0, 0, d)))
    return d


def seat_group_on_mound(objs, mound, bury=0.06):
    """Seat several pieces as one rigid assembly - a tail boom and its fin/rotor must
    keep their relative geometry while landing on the ground together."""
    clear = min(p.z - mound_height_at(mound, p.x, p.y) for o in objs for p in verts(o))
    d = -(clear + bury)
    for o in objs:
        edit_verts(o, lambda p, d=d: p + Vector((0, 0, d)))
    return d


def limit_slope(obj, deg, iters=26):
    """Relax any edge steeper than `deg` by pulling its ends together in Z.

    A mound men cannot walk onto is a wall, and Caleb's brief says they must be able to
    get up it. The crater donor's own interior wall is far steeper than an agent can
    climb, so re-profiling alone is not enough - this is measured and enforced.
    """
    tan = math.tan(math.radians(deg))
    me = obj.data
    edges = [(e.vertices[0], e.vertices[1]) for e in me.edges]
    for _ in range(iters):
        worst = 0.0
        for a, b in edges:
            va, vb = me.vertices[a].co, me.vertices[b].co
            run = math.hypot(va.x - vb.x, va.y - vb.y)
            if run < 1e-5:
                continue
            rise = va.z - vb.z
            lim = run * tan
            if abs(rise) > lim:
                worst = max(worst, abs(rise) / run)
                fix = (abs(rise) - lim) * 0.5 * (1.0 if rise > 0 else -1.0)
                me.vertices[a].co.z -= fix
                me.vertices[b].co.z += fix
        if worst == 0.0:
            break
    me.update()


def mound_height_at(mound, x, y, reach=1.6):
    """Sample the mound's own surface, inverse-distance weighted over nearby vertices.

    Returns 0.0 (bare terrain) when the point is further than `reach` from any mound
    vertex. Snapping to the nearest vertex regardless of distance is what left the thrown
    wing hanging in the air: the piece sat well outside the scar, and the nearest mound
    vertex was a 1 m berm crest, so it was "seated" a metre above the ground it was
    supposed to be lying on.
    """
    num, den, near = 0.0, 0.0, 1e9
    for p in verts(mound):
        d = math.hypot(p.x - x, p.y - y)
        near = min(near, d)
        if d < reach:
            w = 1.0 / max(0.08, d) ** 2
            num += p.z * w
            den += w
    if den <= 0.0 or near >= reach:
        return 0.0
    return num / den


def slope_report(mound, walk_limit=45.0):
    """A mound men cannot climb is a wall. Report the DISTRIBUTION, not just the max -
    a single 48 deg sliver on an otherwise gentle berm is not the same defect as a berm
    that is steep all over, and only the histogram tells them apart."""
    mw = mound.matrix_world.to_3x3()
    sl = []
    for p in mound.data.polygons:
        n = (mw @ p.normal).normalized()
        sl.append(math.degrees(math.acos(min(1.0, abs(n.z)))))
    sl.sort()
    over = sum(1 for a in sl if a > walk_limit)
    return {"max": sl[-1], "p95": sl[int(len(sl) * 0.95)], "median": sl[len(sl) // 2],
            "over_limit": over, "faces": len(sl)}


def max_slope_deg(mound):
    return slope_report(mound)["max"]


def rim_report(mound, bins=36, prominence=0.055, visible_z=0.06):
    """Does the outline read as a CIRCLE? Radius by bearing, NORMALISED BY THE BEST-FIT
    ELLIPSE, plus a count of the local bulges.

    Two traps, both of which return a confident wrong answer:
    * Raw min/max radius is worthless here. A 5.2 x 7.2 m ellipse scores 0.72 and still
      shows a smooth oval from every angle - which is exactly what shipped. Only LOCAL
      wobble breaks the read, so normalise by the fitted ellipse and count the bulges.
    * The mound mesh always spans the full donor footprint; the taper zeroes the HEIGHT,
      not the geometry. Measuring every vertex therefore measures the flat skirt, reports
      a smooth ellipse whatever the profile does, and is blind to the lobes entirely.
      Only vertices above `visible_z` are part of the silhouette.
    """
    lo, hi = bbox([mound])
    cx, cy = (lo.x + hi.x) / 2.0, (lo.y + hi.y) / 2.0
    pts = [p for p in verts(mound) if p.z > visible_z]
    if not pts:
        return {"k": [], "spread": 0.0, "bulges": 0, "rmin": 0.0, "rmax": 0.0}
    a = max(abs(p.x - cx) for p in pts)
    b = max(abs(p.y - cy) for p in pts)
    rad = [0.0] * bins
    for p in pts:
        i = int(((math.degrees(math.atan2(p.y - cy, p.x - cx)) + 360.0) % 360.0)
                / (360.0 / bins)) % bins
        rad[i] = max(rad[i], math.hypot(p.x - cx, p.y - cy))
    k = []
    for i in range(bins):
        th = math.radians((i + 0.5) * 360.0 / bins)
        re = 1.0 / math.sqrt((math.cos(th) / a) ** 2 + (math.sin(th) / b) ** 2)
        k.append(rad[i] / re)
    s = [(k[(i - 1) % bins] + k[i] * 2.0 + k[(i + 1) % bins]) / 4.0 for i in range(bins)]
    floor = min(s)
    n = sum(1 for i in range(bins)
            if s[i] > s[(i - 1) % bins] and s[i] >= s[(i + 1) % bins]
            and (s[i] - floor) > prominence)
    return {"k": s, "spread": max(s) - min(s), "bulges": n,
            "rmin": min(rad), "rmax": max(rad)}


def matte(objs=None, rough=0.88, spec=0.16):
    """Flatten every material to near-diffuse. PSX materials do not sparkle.

    This is not a render-only fix: metallic/roughness export into the GLB, so a donor's
    glossy value follows the wreck into Godot. At 28 Cycles samples with no denoiser a
    metallic surface also throws firefly speckle, which is what the F-4 intake was doing.
    """
    objs = objs if objs is not None else meshes()
    seen = set()
    for o in objs:
        for m in o.data.materials:
            if m is None or m.name in seen or not m.use_nodes:
                continue
            seen.add(m.name)
            if hasattr(m, "surface_render_method"):
                m.surface_render_method = 'DITHERED'
            for b in m.node_tree.nodes:
                if b.type != 'BSDF_PRINCIPLED':
                    continue
                # a metal's base colour is a SPECULAR albedo. Zero the metallic and that
                # same 0.8 grey becomes a diffuse albedo, and a sooty drop tank turns into
                # a bright white cylinder - brighter than the gloss we set out to remove.
                mi = b.inputs.get('Metallic')
                bc = b.inputs.get('Base Color')
                if (mi is not None and not mi.is_linked and mi.default_value > 0.5
                        and bc is not None and not bc.is_linked):
                    c = bc.default_value
                    bc.default_value = (c[0] * 0.45, c[1] * 0.45, c[2] * 0.45, c[3])
                for nm, val in (('Metallic', 0.0), ('Specular IOR Level', spec),
                                ('Specular', spec), ('Coat Weight', 0.0),
                                ('Sheen Weight', 0.0), ('Roughness', rough),
                                ('Transmission Weight', 0.0), ('Transmission', 0.0),
                                ('Alpha', 1.0)):
                    i = b.inputs.get(nm)
                    if i is None:
                        continue
                    # a LINKED input must be cut, not overwritten. The F-4's
                    # `green_metal_rust` drives Metallic and Roughness from a map, so
                    # setting the default value changes nothing at all and the intake
                    # goes on sparkling.
                    for lk in list(i.links):
                        m.node_tree.links.remove(lk)
                    i.default_value = max(val, i.default_value) if nm == 'Roughness' \
                        else val
    print("  matte: %d materials flattened to diffuse" % len(seen))


# ----------------------------------------------------------------- sockets
def socket(name, loc, rz=0.0, size=0.6):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = 'PLAIN_AXES'
    e.empty_display_size = size
    e.location = Vector(loc)
    # A socket empty gets rotation about Z ONLY. glTF maps Blender local -Y onto Godot
    # local +Z; any X/Y euler here silently points the socket at the floor.
    e.rotation_euler = Euler((0.0, 0.0, math.radians(rz)), 'XYZ')
    bpy.context.scene.collection.objects.link(e)
    return e


# ----------------------------------------------------------------- collision
def make_colonly(trimesh_names=(), skip=()):
    """`{base}_{i:03d}-colonly` twins. The suffix MUST be last: Blender's `.001` lands
    after the name, which stops it ending with `-colonly`, and Godot then imports a
    silent invisible mesh with no collision at all."""
    made, boxes, tri_n = [], 0, 0
    for i, o in enumerate(list(meshes())):
        if o.name.endswith("-colonly") or o.name in skip:
            continue
        base = o.name.split(".")[0]
        nm = "%s_%03d-colonly" % (base, i)
        if any(base.startswith(t) for t in trimesh_names):
            col = bpy.data.objects.new(nm, o.data)
            tri_n += 1
        else:
            pts = [v.co for v in o.data.vertices]
            if not pts:
                continue
            lo = Vector((min(p[i2] for p in pts) for i2 in range(3)))
            hi = Vector((max(p[i2] for p in pts) for i2 in range(3)))
            bm = bmesh.new()
            bmesh.ops.create_cube(bm, size=1.0)
            for v in bm.verts:
                v.co = Vector((lo[k] + (v.co[k] + 0.5) * (hi[k] - lo[k]) for k in range(3)))
            me = bpy.data.meshes.new(nm)
            bm.to_mesh(me)
            bm.free()
            col = bpy.data.objects.new(nm, me)
            boxes += 1
        col.matrix_world = o.matrix_world.copy()
        bpy.context.scene.collection.objects.link(col)
        made.append(col)
    print("  collision: %d -colonly twins (%d trimesh, %d box)" % (len(made), tri_n, boxes))
    return made


# ----------------------------------------------------------------- ship
def zero_to_ground(objs=None, centre_xy=True):
    """Origin at the footprint centre, lowest EARTH point at z=0. place_structure() drops
    the GLB origin straight onto terrain height, so a mound whose toe is not at 0 either
    floats or sinks."""
    objs = objs if objs is not None else meshes()
    lo, hi = bbox(objs)
    dx = -(lo.x + hi.x) / 2.0 if centre_xy else 0.0
    dy = -(lo.y + hi.y) / 2.0 if centre_xy else 0.0
    for o in bpy.context.scene.objects:
        o.location = o.location + Vector((dx, dy, 0.0))
    bpy.context.view_layer.update()
    return Vector((dx, dy, 0.0))


def assert_names():
    bad = [o.name for o in bpy.context.scene.objects if "." in o.name]
    if bad:
        raise SystemExit("FATAL: '.' in exported name(s): %s" % bad)
    for o in meshes():
        if "colonly" in o.name and not o.name.endswith("-colonly"):
            raise SystemExit("FATAL: collider suffix not final: %s" % o.name)


def export_glb(path):
    assert_names()
    sc = bpy.context.scene
    deselect()
    for o in sc.objects:
        o.select_set(o.type in {'MESH', 'EMPTY'})
    bpy.context.view_layer.objects.active = next(o for o in sc.objects if o.type == 'MESH')
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True, export_cameras=False,
                              export_lights=False, export_extras=False,
                              export_tangents=False)
    return os.path.getsize(path) / 1048576.0


def save_blend(path):
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=path, copy=False)
    # Blender writes .blend1 on save regardless of intent; the project forbids them.
    b1 = path + "1"
    if os.path.exists(b1):
        os.remove(b1)
        print("  removed %s" % os.path.basename(b1))


# ----------------------------------------------------------------- look at it
# ONE definition of the angles this asset is judged from. The debris gate's end-on test
# reads the same tuple render_views() shoots, so a new camera angle cannot appear without
# the gate learning about it.
VIEWS = (("front", 90, 13), ("threequarter", 40, 20), ("side", 0, 11), ("high", 150, 42))
VIEW_AZ = tuple(v[1] for v in VIEWS)


def render_views(outdir, tag, radius=None, samples=28, res=(760, 470)):
    os.makedirs(outdir, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = samples
    sc.cycles.use_denoising = False
    sc.cycles.max_bounces = 3
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent = False
    sc.world = sc.world or bpy.data.worlds.new("W")
    sc.world.use_nodes = True
    bg = sc.world.node_tree.nodes.get('Background')
    if bg:
        bg.inputs[0].default_value = (0.42, 0.46, 0.52, 1.0)
        bg.inputs[1].default_value = 1.1

    # A GROUND PLANE, or the render cannot answer the question being asked of it.
    # Without one, every thrown piece is silhouetted against empty sky and reads as
    # floating even when its measured clearance to the ground is zero - and a piece that
    # really IS airborne looks identical. Both wrecks were mis-judged this way.
    gbm = bmesh.new()
    bmesh.ops.create_grid(gbm, x_segments=1, y_segments=1, size=90.0)
    gme = bpy.data.meshes.new("REF_GROUND")
    gbm.to_mesh(gme)
    gbm.free()
    ground = bpy.data.objects.new("REF_GROUND", gme)
    gme.materials.append(flat_mat("REF_GROUND_MAT", (0.30, 0.30, 0.21, 1.0)))
    ground.location.z = -0.02
    sc.collection.objects.link(ground)

    sun = bpy.data.objects.new("SUN", bpy.data.lights.new("SUN", 'SUN'))
    sun.data.energy = 3.2
    sun.data.angle = math.radians(6)
    sun.rotation_euler = Euler((math.radians(52), 0, math.radians(38)), 'XYZ')
    sc.collection.objects.link(sun)

    shown = [o for o in meshes() if not o.name.endswith("-colonly")
             and o.name != "REF_GROUND"]
    lo, hi = bbox(shown)
    ctr = (lo + hi) / 2.0
    span = max(hi.x - lo.x, hi.y - lo.y, 3.0)
    r = radius or span * 1.15

    for o in meshes():
        o.hide_render = o.name.endswith("-colonly")

    cam_d = bpy.data.cameras.new("C")
    cam_d.lens = 40
    cam = bpy.data.objects.new("C", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam

    out = []
    for nm, az, el in VIEWS:
        a = math.radians(az)
        e = math.radians(el)
        pos = ctr + Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e),
                            math.sin(e))) * r
        pos.z = max(pos.z, ctr.z + 0.9)
        cam.location = pos
        d = (ctr - pos)
        cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
        p = os.path.join(outdir, "%s_%s.png" % (tag, nm))
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        out.append(p)
        print("  render %s" % p)
    drop(sun, cam, ground)
    for o in meshes():
        o.hide_render = False
    return out


def verify_roundtrip(path, expect_empties, socket_reach=2.5, anchor_fire_min=8.0,
                     anchor_hull=(4.0, 7.0)):
    """Re-import the shipped file INTO AN EMPTY SCENE and prove it.

    The empty scene is the whole point. Re-importing alongside the objects that were just
    exported makes Blender mint `foo.001` for every single node - so every socket reads as
    MISSING and every `-colonly` collider reads as un-suffixed, and the verification
    convicts a file that is perfectly fine. A round-trip check that shares a namespace
    with its source measures the namespace, not the file.
    """
    wipe()
    bpy.ops.import_scene.gltf(filepath=path)
    new = list(bpy.context.scene.objects)
    got_e = {o.name for o in new if o.type == 'EMPTY'}
    got_m = [o for o in new if o.type == 'MESH']
    missing = [e for e in expect_empties if e not in got_e]
    lo = Vector((1e9, 1e9, 1e9)); hi = Vector((-1e9, -1e9, -1e9))
    n = 0
    for o in got_m:
        o.data.calc_loop_triangles()
        n += len(o.data.loop_triangles)
        for p in verts(o):
            for i in range(3):
                lo[i] = min(lo[i], p[i]); hi[i] = max(hi[i], p[i])
    col = [o.name for o in got_m if o.name.endswith("-colonly")]
    print("  ROUNDTRIP: %d mesh (%d colonly), %d tris, %d empties" %
          (len(got_m), len(col), n, len(got_e)))
    print("    reimported bbox lo %s hi %s" %
          ([round(x, 2) for x in lo], [round(x, 2) for x in hi]))
    if missing:
        raise SystemExit("FATAL: sockets missing from the GLB: %s (got %s)"
                         % (missing, sorted(got_e)))
    if not col:
        raise SystemExit("FATAL: no `-colonly` collider survived the export")
    # Facing, asserted on the SHIPPED file rather than on the donor. The project
    # convention is nose = Blender +Y == Godot -Z; a re-imported glTF puts +Y back where
    # it started, so front-of-aircraft parts must still out-rank tail parts in Y.
    def mean_y(subs):
        v = [p.y for o in got_m for p in verts(o)
             if any(k in o.name for k in subs) and "colonly" not in o.name]
        return sum(v) / len(v) if v else None
    fwd = mean_y(("engine", "nose", "fuselage"))
    aft = mean_y(("tail", "boom", "stab"))
    if fwd is not None and aft is not None:
        print("    facing: forward parts mean y %.2f, aft parts mean y %.2f -> nose %s"
              % (fwd, aft, "+Y (Godot -Z) OK" if fwd > aft else "**REVERSED**"))
        if fwd <= aft:
            raise SystemExit("FATAL: exported nose is not +Y; look_at() would fly it "
                             "backwards and the .tscn would need a compensating flip")

    # NAMING IS THE API, asserted on the shipped file. A mesh or collider that loses its
    # `wreck_hard_`/`wreck_soft_` prefix in export ships invulnerable and silent -
    # ballistics reads the collider name, destruction reads the mesh name.
    unpref = [o.name for o in got_m
              if not o.name.startswith(("wreck_hard_", "wreck_soft_"))]
    if unpref:
        raise SystemExit("FATAL: exported mesh/collider without a wreck_ prefix, would "
                         "ship bulletproof: %s" % unpref)

    # Socket geometry, re-measured against the file rather than the build scene.
    vis = [o for o in got_m if not o.name.endswith("-colonly")]
    wp = [p for o in vis if "mound" not in o.name for p in verts(o)]
    hull = [p for o in vis if o.name.startswith("wreck_hard")
            and "mound" not in o.name for p in verts(o)]
    fires = [o for o in bpy.context.scene.objects
             if o.type == 'EMPTY' and o.name.startswith("fire_socket")]
    for f in sorted(fires, key=lambda o: o.name):
        loc = f.matrix_world.translation
        d = min((loc - p).length for p in wp)
        print("    %s: %.2f m to nearest wreck surface (max %.1f)"
              % (f.name, d, socket_reach))
        if d > socket_reach:
            raise SystemExit("FATAL: %s is %.2f m off the wreck. Danger lives INSIDE the "
                             "flames, so a socket out on the approach ground walks the "
                             "rescue AI into fire." % (f.name, d))
    anc = next((o for o in bpy.context.scene.objects
                if o.type == 'EMPTY' and o.name == "pilot_anchor"), None)
    if anc is not None and fires and hull:
        a = anc.matrix_world.translation
        dh = min(math.hypot(a.x - p.x, a.y - p.y) for p in hull)
        df = min(math.hypot(a.x - f.matrix_world.translation.x,
                            a.y - f.matrix_world.translation.y) for f in fires)
        print("    pilot_anchor: %.2f m off the hull in plan (want %.1f..%.1f), "
              "%.2f m to nearest fire socket (min %.1f)"
              % (dh, anchor_hull[0], anchor_hull[1], df, anchor_fire_min))
        if not (anchor_hull[0] <= dh <= anchor_hull[1]):
            raise SystemExit("FATAL: pilot_anchor %.2f m off the hull" % dh)
        if df < anchor_fire_min:
            raise SystemExit("FATAL: pilot_anchor only %.2f m from a fire socket" % df)
    return n, lo, hi
