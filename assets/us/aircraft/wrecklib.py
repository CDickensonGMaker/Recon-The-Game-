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
def build_mound(name, half_x, half_y, nose_y, tail_y, berm_h, furrow_d,
                hull_hw=1.5, seed=5, tex=True, subdiv=1):
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
      the entry furrow open behind it (ref obs 5/6).
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

    mid_y = (nose_y + tail_y) / 2.0

    def f(p):
        # normalised crater coords
        u = (p.x - cx) / rx                       # -1..1
        v = (p.y - cy) / ry
        r = math.hypot(u, v)
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
        #     towards the nose where the plough was still deep
        ridge = berm_h * (0.62 + 0.48 * max(0.0, min(1.2, run)))
        h += ridge * math.exp(-(((ax - hull_hw * 1.55) / (hull_hw * 1.15)) ** 2)) \
             * math.exp(-max(0.0, (run - 1.25)) ** 2 * 3.0)

        # --- the pile thrown up ahead of the nose, the deepest part of the gouge
        dy = y - (nose_y + 1.90)
        h += berm_h * 1.30 * math.exp(-((dy / 1.70) ** 2) - ((x / (half_x * 0.72)) ** 2))

        # --- the SLOT the hull lies in. Without it the spoil closes over the top and
        #     the aeroplane vanishes: measured 60% of hull height buried and only 0.4 m
        #     proud. Earth must come up the SIDES of a ploughed-in airframe.
        if -0.30 < run < 1.40:
            h -= berm_h * 0.54 * math.exp(-((ax / (hull_hw * 1.45)) ** 2))

        # --- the entry furrow, open behind on the centreline
        behind = (tail_y - y) / max(1.0, half_y)
        if behind > 0.0:
            h -= furrow_d * math.exp(-(x * x) / (hull_hw * hull_hw * 3.2)) \
                 * min(1.0, behind * 2.2)

        # --- churn: the crater's OWN surface relief, kept small and scaled by its z key
        h += (0.5 - key) * 0.20
        h += 0.09 * math.sin(u * 5.1 + v * 3.3) * math.cos(v * 4.7 - u * 2.1)
        h += 0.055 * pnoise(x, y, seed)

        # --- taper to zero at the rim so there is no step against the terrain
        h *= max(0.0, 1.0 - max(0.0, (r - 0.70) / 0.34) ** 1.2)
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

    views = [("front", 90, 13), ("threequarter", 40, 20),
             ("side", 0, 11), ("high", 150, 42)]
    out = []
    for nm, az, el in views:
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


def verify_roundtrip(path, expect_empties):
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
    return n, lo, hi
