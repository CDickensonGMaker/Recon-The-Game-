"""build_necklace_kit.py - the trophy necklace: a cord with 15 hang slots and a charm library.

    "C:\\Program Files\\Blender Foundation\\Blender 5.0\\blender.exe" --background ^
        --python tools/build_necklace_kit.py

Writes  assets/us/characters/necklace_kit.blend        (cord + slots + charms + fit dummy)
        assets/us/characters/necklace_kit_tex.png      (512x512 palette sheet, one material)
        assets/us/characters/necklace_cord.glb         (cord + necklace_slot_01..15, Neck-bone-local)
        assets/us/characters/charms/charm_<name>.glb   (one per charm, origin = hang point)
        assets/us/characters/charms/charm_ear_<fresh|days|rotten|dried|old>.glb  (the decay ladder;
                                                        charm_ear.glb = the days stage, kept so the
                                                        dresser's append and old references still work)
        production/renders_conquest_of_worms/necklace_kit_sheet.png
        production/renders_conquest_of_worms/necklace_ears_sheet.png   (5 stages, front + cut, 1 m and 0.3 m)
        production/renders_conquest_of_worms/necklace_ears_worn.png    (the dummy in a mixed string of 15)

Decree 2026-09-11 (production/war_room/talking_heads_2026-09-11.md, addendum): the necklace
is the VISIBLE TROPHY LEDGER - a cord on the Neck bone with N hang slots, each item its own
tiny GLB snapped to a slot. Caleb's ruling the same day: FIFTEEN slots, so the top ear
bucket (15) is fifteen real ears; tight spacing, ears may overlap slightly; cord length
realistic so 15 ears fit collarbone to collarbone. Gus wears 5, centred (slots 06-10).

FIT. The cord is laid on the PSX body by MEASUREMENT: every centreline sample is ray-cast
onto `us_grunt_joined` (appended READ-ONLY from us_base_v3.blend as a fit dummy) and parked
one cord radius + 1 mm off the surface, so the cord rests on the collar at the nape, on the
shoulder tops at the sides and against the chest in front. Measured on the dummy (object
space, rig at origin, T-pose): neck ring r 0.062-0.070 at z 1.54-1.56, collar flare to
x +-0.119 at z 1.52, shoulder top z 1.531 at x 0.08, chest front y -0.081 at z 1.50 down to
-0.169 at z 1.30, nape y 0.062 at z 1.54. Neck bone head (0, 0.011, 1.501) world.

SLOT CONTRACT (what the engine reads). In the shipped GLB each `necklace_slot_NN` node's
local -Y is "down" for a hanging charm, +Z is outward from the chest, +X runs along the
cord, and its origin is ON the cord centreline. "Down" is gravity projected onto the chest
surface, because a charm on a string against a sloping chest lies ON the slope - a pure
world-down slot on the collarbone would put the ear's tip 4 cm inside the upper chest
(chest y -0.097 at z 1.48 vs -0.142 at z 1.42, measured). Charms are authored to the same
contract: origin at the hang point, body hanging down local -Y, display face toward +Z.
In this Blender file that is -Z down / -Y front; the glTF Y-up export maps one to the other.

BONE-LOCAL BAKE. The cord GLB carries no rig. Vertices and slot transforms are written in
`mixamorig:Neck` bone space (bone head origin, bone rest basis) exactly the way the shipped
chest gear is (assets/nva_vc/props/chest/bandolier_ammo.glb: positions y 0.065..0.129 /
z -0.123..0.339 = Spine2-local, hung on an IDENTITY BoneAttachment3D by
vc_nva_dresser.gd:440 `_hang`). ear_necklace.glb used the same bake. NOT verified in Godot
from here - the engine cannot run headless in this session.

Sizes (real-world; brief + standard specs): ear 63 mm tall fresh (male mean; 85/98/65/55 %
for days/rotten/dried/old, section 4a), dog tag 51x29 mm, 5.56x45 round 57.4 mm OAL / 44.7 mm case / 9.6 mm rim, P-38
38 x 15 mm, crucifix 40 x 25 mm, peace medallion 38 mm dia, molar 20 mm tall.
"""
import bpy
import os
import sys
import math
import numpy as np
from mathutils import Vector, Matrix

D = bpy.data
ROOT = r"C:\Users\caleb\RECONgame"
CHAR = os.path.join(ROOT, "assets", "us", "characters")
SRC = os.path.join(CHAR, "us_base_v3.blend")
OUT_BLEND = os.path.join(CHAR, "necklace_kit.blend")
OUT_TEX = os.path.join(CHAR, "necklace_kit_tex.png")
OUT_CORD = os.path.join(CHAR, "necklace_cord.glb")
OUT_CHARMS = os.path.join(CHAR, "charms")
RENDERS = os.path.join(ROOT, "production", "renders_conquest_of_worms")
SHEET = os.path.join(RENDERS, "necklace_kit_sheet.png")

N_SLOTS = 15
EAR_T_CLEAR = 0.010         # the ear's back (cut face) 10 mm off the surface under its tip;
                            # the 15-19 mm of relief stands OUTWARD of that, away from the chest
CORD_R = 0.00175            # 3.5 mm cord
CORD_CLEAR = 0.001
CORD_SAMPLES = 40           # 40 x 4 sides = 320 tris
NECK_BONE = "mixamorig:Neck"
SPINE_BONE = "mixamorig:Spine2"

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def log(*a):
    print(*a, flush=True)


# ---------------------------------------------------------------------------
# 0. fresh scene, fit dummy
# ---------------------------------------------------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0        # no .blend1, Caleb's law
SC = bpy.context.scene
assert os.path.abspath(bpy.data.filepath) != os.path.abspath(SRC)

with D.libraries.load(SRC, link=False) as (src, dst):
    dst.objects = ["PSXRig", "us_grunt_joined"]
for o in dst.objects:
    SC.collection.objects.link(o)
rig = D.objects["PSXRig"]
body = D.objects["us_grunt_joined"]
rig.data.pose_position = 'REST'
bpy.context.view_layer.update()
assert abs(math.degrees(rig.rotation_euler.x) - 90.0) < 1e-3, "rig is not upright as appended"
assert len(rig.data.bones) == 41

dg = bpy.context.evaluated_depsgraph_get()
ev = body.evaluated_get(dg)
BM = body.matrix_world
BMi = BM.inverted()


def ray(origin, direction):
    """object-space ray on the evaluated body; returns (world hit, world normal) or None."""
    ok, loc, nor, idx = ev.ray_cast(BMi @ Vector(origin), (BMi.to_3x3() @ Vector(direction)).normalized())
    if not ok:
        return None
    return BM @ loc, (BM.to_3x3() @ nor).normalized()


def closest(p):
    ok, loc, nor, idx = ev.closest_point_on_mesh(BMi @ Vector(p))
    w = BM @ loc
    n = (BM.to_3x3() @ nor).normalized()
    return w, n, (Vector(p) - w).length, (Vector(p) - w).dot(n)


neck_b = rig.data.bones[NECK_BONE]
neck_head_w = rig.matrix_world @ neck_b.head_local
log("NECK bone head world (%.4f, %.4f, %.4f)" % tuple(neck_head_w))

# ---------------------------------------------------------------------------
# 1. the cord centreline, measured onto the body
# ---------------------------------------------------------------------------
# t in [0,1): 0 = nape centre, 0.25 = left shoulder (+x), 0.5 = sternum low point, 0.75 = right.
Z_COLLAR = 1.536            # cord centre at the nape / shoulder crossing (shoulder top 1.531 + r + clear)
DROP = 0.130                # sternum low point z = Z_COLLAR - DROP  (15 ears at ~30 mm pitch)
RX_BACK, RY_BACK = 0.086, 0.070


def front_w(t):
    """0 on the back half, smooth 0->1->0 across the front (t 0.25..0.75)."""
    if not (0.25 <= t <= 0.75):
        return 0.0
    return 0.5 * (1.0 - math.cos(4.0 * math.pi * (t - 0.25)))


def centre(t):
    a = 2.0 * math.pi * t
    w = front_w(t)
    z = Z_COLLAR - DROP * w
    x = RX_BACK * math.sin(a)
    chest = ray((x, -0.6, z), (0, 1, 0)) if w > 0.0 else None
    if w == 0.0 or chest is None:
        # back half: horizontal ray toward the neck axis at this height, then rest on the
        # shoulder/collar top if that is higher.
        # start at r=0.16: outside the collar flare (0.119) but inside the T-pose arms,
        # which a ray from further out hits first (measured: the cord went 0.35 m wide)
        o = Vector((0.16 * math.sin(a), 0.16 * math.cos(a), z))
        hit = ray(o, (-o.x, -o.y, 0.0))
        assert hit, "back ray missed at t=%.3f" % t
        p, n = hit
        p = p + n * (CORD_R + CORD_CLEAR)
        # rest on the shoulder top where the cord crosses it; the ray starts just above
        # the collar (from 1.9 it hits the HEAD at the nape and the cord climbed to z 1.80)
        top = ray((p.x, p.y, 1.60), (0, 0, -1)) if abs(p.x) > 0.06 else None
        if top and top[0].z + CORD_R + CORD_CLEAR > p.z:
            p = Vector((p.x, p.y, top[0].z + CORD_R + CORD_CLEAR))
            n = top[1]
        return p, n
    # front half: lie on the chest at (x, z); ray from in front (above the shoulder top,
    # where that ray misses, the radial/top method above takes over)
    p, n = chest
    p = p + n * (CORD_R + CORD_CLEAR)
    # very near the shoulder crossing the chest ray can hit the collar top edge; keep the
    # cord from rising above the collar line there
    p.z = min(p.z, Z_COLLAR)
    return p, n


def settle(p, n):
    """the ray hit puts the centreline one radius off ONE face; at the collar/shoulder crease
    two faces meet and the tube's ring verts still cut the other one (measured 2.5 mm at
    t=0.657). Push off the nearest surface until the whole radius clears."""
    for _ in range(4):
        w, cn, dist, sign = closest(p)
        need = CORD_R * 1.5 + CORD_CLEAR
        if sign >= 0 and dist >= need:
            break
        p = w + cn * need
        n = cn
    return p, n


# dense sampling for arc length, then resample evenly
DENSE = 720
dense = [settle(*centre(i / float(DENSE))) for i in range(DENSE)]
pts = [p for p, n in dense]
seg = [(pts[(i + 1) % DENSE] - pts[i]).length for i in range(DENSE)]
cum = [0.0]
for s in seg:
    cum.append(cum[-1] + s)
L = cum[-1]
front_len = sum(seg[i] for i in range(DENSE) if 0.25 <= i / float(DENSE) < 0.75)
log("CORD length %.4f m total, front arc (shoulder to shoulder) %.4f m, low point z=%.4f"
    % (L, front_len, min(p.z for p in pts)))


def at_arc(s):
    s = s % L
    i = max(0, min(DENSE - 1, int(np.searchsorted(cum, s, side='right') - 1)))
    f = (s - cum[i]) / max(seg[i], 1e-9)
    p = pts[i].lerp(pts[(i + 1) % DENSE], f)
    n = dense[i][1].lerp(dense[(i + 1) % DENSE][1], f).normalized()
    return p, n, (i + f) / float(DENSE)


# even resample for the tube
samples = [at_arc(L * k / float(CORD_SAMPLES)) for k in range(CORD_SAMPLES)]
verts, faces = [], []
for k in range(CORD_SAMPLES):
    p, n, t = samples[k]
    q = samples[(k + 1) % CORD_SAMPLES][0]
    d = (q - p).normalized()
    side = d.cross(n).normalized()
    up = side.cross(d).normalized()
    ring = [p + side * CORD_R + up * CORD_R, p - side * CORD_R + up * CORD_R,
            p - side * CORD_R - up * CORD_R, p + side * CORD_R - up * CORD_R]
    verts += ring
# ring-level settle: the centreline clears, but a ring vert can still cut a second shell
# at the collar/shoulder crease (the joined body is overlapping shells there, 22 open edges
# at z 1.42-1.53). Shift the whole ring out along the offending vert's surface normal.
for k in range(CORD_SAMPLES):
    for _ in range(6):
        worst_v, worst_d, worst_n = None, 1e9, None
        for j in range(4):
            w, cn, dist, sign = closest(verts[4 * k + j])
            sd = dist if sign >= 0 else -dist
            if sd < worst_d:
                worst_v, worst_d, worst_n = j, sd, cn
        if worst_d >= 0.0005:
            break
        shift = worst_n * (0.0005 - worst_d + 0.0005)
        for j in range(4):
            verts[4 * k + j] = verts[4 * k + j] + shift
for k in range(CORD_SAMPLES):
    b = 4 * k
    c = 4 * ((k + 1) % CORD_SAMPLES)
    for j in range(4):
        faces.append((b + j, c + j, c + (j + 1) % 4, b + (j + 1) % 4))
cord_me = D.meshes.new("necklace_cord")
cord_me.from_pydata(verts, [], faces)
cord_me.update()
cord = D.objects.new("necklace_cord", cord_me)
SC.collection.objects.link(cord)

# skin: Neck everywhere, the front drape shares up to 35% with Spine2 so it stays on the
# chest when the head turns
vg_n = cord.vertex_groups.new(name=NECK_BONE)
vg_s = cord.vertex_groups.new(name=SPINE_BONE)
for k in range(CORD_SAMPLES):
    t = samples[k][2]
    ws = 0.35 * front_w(t)
    ids = [4 * k + j for j in range(4)]
    vg_n.add(ids, 1.0 - ws, 'REPLACE')
    vg_s.add(ids, ws, 'REPLACE')
# verts are authored in world (Z-up) space; the rig OBJECT carries a 90 deg X rotation, so
# the parent inverse must cancel it or the cord lies flat on the floor (measured: -1.37 m)
cord.parent = rig
cord.parent_type = 'OBJECT'
cord.matrix_parent_inverse = rig.matrix_world.inverted()
bpy.context.view_layer.update()
assert (cord.matrix_world - Matrix.Identity(4)).to_3x3().determinant() < 1e-9 and     cord.matrix_world.translation.length < 1e-6, "cord did not stay at world identity"
mod = cord.modifiers.new("Armature", 'ARMATURE')
mod.object = rig
bpy.context.view_layer.update()

# clearance gate: every cord vertex outside the body by >= 0.5 mm
worst = 1e9
inside = 0
for v in cord_me.vertices:
    w, n, dist, sign = closest(cord.matrix_world @ v.co)
    if sign < 0:
        inside += 1
        log("   INSIDE vert %d at (%.4f, %.4f, %.4f) by %.4f  (sample t=%.3f)"
            % (v.index, *(cord.matrix_world @ v.co), dist, samples[v.index // 4][2]))
    worst = min(worst, dist if sign >= 0 else -dist)
log("CORD %d verts / %d tris; body clearance min %.4f m, verts inside body: %d"
    % (len(cord_me.vertices), sum(len(f) - 2 for f in faces), worst, inside))
assert inside == 0 and worst >= 0.0005, "cord penetrates the body"

# ---------------------------------------------------------------------------
# 2. the 15 slots, by arc length across the front, and their frames
# ---------------------------------------------------------------------------
s_shoulder_l = cum[int(0.25 * DENSE)]
s_shoulder_r = cum[int(0.75 * DENSE)]
MARGIN = 0.025
usable = (s_shoulder_r - s_shoulder_l) - 2 * MARGIN
PITCH = usable / float(N_SLOTS - 1)
log("SLOTS front arc %.4f m, margin %.3f each end, pitch %.4f m (ear 36 mm wide -> overlap %.1f mm)"
    % (s_shoulder_r - s_shoulder_l, MARGIN, PITCH, (0.036 - PITCH) * 1000))
assert 0.024 <= PITCH <= 0.034, "pitch %.4f is not a tight string of ears" % PITCH

slots = []
for i in range(N_SLOTS):
    s = s_shoulder_l + MARGIN + PITCH * i
    p, n, t = at_arc(s)
    # the chest is a handful of flat faces; average the normal over +-20 mm of cord so one
    # crease face at the collar does not pitch a single slot 50 deg while its neighbours sit
    # at 25 (measured before this: slots 02/14 at 51.6 deg)
    n = Vector((0, 0, 0))
    for ds in np.linspace(-0.02, 0.02, 9):
        n += at_arc(s + ds)[1]
    n.normalize()
    # frame: Z = up along the surface (gravity projected onto the tangent plane),
    # Y = into the chest (-Y = outward = display face), X = Y x Z along the cord.
    # Then aim the hang at where the chest actually is 50 mm below the slot: at the
    # collar crease the surface under the slot is steeper than the face the slot sits on,
    # and a straight-down ear buried its tip 17 mm (63 of 450 verts inside, measured).
    g = Vector((0, 0, -1))
    down_s = (g - n * g.dot(n)).normalized()
    probe = p + down_s * 0.050
    w, cn, dist, sign = closest(probe)
    if sign > 0 and dist >= EAR_T_CLEAR:
        q = probe                       # convex chest: the ear hangs free, tip clear
    else:
        q = w + cn * EAR_T_CLEAR        # crease: the ear lies down the slope
        n = (n + cn).normalized()
    Zax = (p - q).normalized()
    Yax = -n
    Yax = (Yax - Zax * Yax.dot(Zax)).normalized()
    Xax = Yax.cross(Zax).normalized()
    M = Matrix((Xax, Yax, Zax)).transposed().to_4x4()
    M.translation = p
    e = D.objects.new("necklace_slot_%02d" % (i + 1), None)
    e.empty_display_type = 'ARROWS'
    e.empty_display_size = 0.012
    SC.collection.objects.link(e)
    e.parent = rig
    e.parent_type = 'BONE'
    e.parent_bone = NECK_BONE
    e.matrix_parent_inverse = Matrix.Identity(4)
    bpy.context.view_layer.update()
    e.matrix_world = M
    bpy.context.view_layer.update()
    err = (e.matrix_world.translation - p).length
    assert err < 1e-5, "slot %d landed %.2e off the cord" % (i + 1, err)
    tilt = math.degrees(math.acos(max(-1.0, min(1.0, Zax.dot(Vector((0, 0, 1)))))))
    slots.append((e, M, t, tilt))
    log("   slot %02d  arc %.3f  world (%.4f, %.4f, %.4f)  tilt from vertical %.1f deg  Neck %.2f / Spine2 %.2f"
        % (i + 1, s - s_shoulder_l, p.x, p.y, p.z, tilt, 1 - 0.35 * front_w(t), 0.35 * front_w(t)))

# ---------------------------------------------------------------------------
# 3. the palette sheet - one 256x256 material for cord and every charm
# ---------------------------------------------------------------------------
# Skin base taken off the project's face atlas (lower-cheek mean measured on face_atlas_v5
# donor cell, sRGB-encoded bytes as Image.pixels reports them): (0.62, 0.45, 0.32).
SKIN = np.array([0.62, 0.45, 0.32])
CELL = 64
rng = np.random.RandomState(7)


def cell_rgb(base, noise=0.04, shape=(CELL, CELL)):
    a = np.ones(shape + (3,)) * np.array(base)
    a += rng.uniform(-noise, noise, shape + (1,))
    return a


TEX = 512                   # grown from 256 on 2026-09-12 for the five ear stages; the old
                            # 64-px cells keep their pixel positions in the bottom-left quadrant
sheet = np.zeros((TEX, TEX, 4))
sheet[..., 3] = 1.0
CELLS = {}                  # name -> (x0, y0, size) in pixels, bottom-up like Image.pixels


def put(name, col, row, arr):
    """64-px palette cell at grid (col, row)."""
    y0, x0 = row * CELL, col * CELL
    sheet[y0:y0 + CELL, x0:x0 + CELL, :3] = np.clip(arr, 0, 1)
    CELLS[name] = (x0, y0, CELL)


def put_px(name, x0, y0, arr):
    """square cell of any size at pixel (x0, y0)."""
    s = arr.shape[0]
    sheet[y0:y0 + s, x0:x0 + s, :3] = np.clip(arr, 0, 1)
    CELLS[name] = (x0, y0, s)


# cord: dark oiled leather with lengthwise streaks
c = cell_rgb((0.12, 0.085, 0.06), 0.02)
for x in range(0, CELL, 5):
    c[:, x:x + 2] *= 0.75
put("cord", 0, 0, c)
# cells (1,0) and (2,0) held the old flat-disc ear; the five ear stages paint their own
# 128/64-px cells in section 4a (ear_fresh_front .. ear_old_cut)
# dog tag: matte steel with stamped rows
t = cell_rgb((0.44, 0.45, 0.44), 0.03)
for r, y in enumerate((14, 22, 30, 38, 46)):
    for x in range(8, 56, 3):
        if rng.uniform() > 0.25:
            t[y:y + 2, x:x + 2] *= 0.40
put("dogtag", 3, 0, t)
# ball chain: mid steel with bead dots
b = cell_rgb((0.50, 0.51, 0.50), 0.02)
for y in range(2, CELL, 6):
    b[y:y + 3, :] *= 1.15
put("chain", 0, 1, b)
# brass case / copper jacket / parkerized steel
put("brass", 1, 1, cell_rgb((0.72, 0.55, 0.22), 0.04))
put("copper", 2, 1, cell_rgb((0.62, 0.36, 0.22), 0.03))
put("parker", 3, 1, cell_rgb((0.20, 0.21, 0.18), 0.02))      # Parkerized mat (0.101,0.111,0.087) lin
# tarnished silver crucifix, ivory tooth crown, yellowed root
put("silver", 0, 2, cell_rgb((0.55, 0.56, 0.52), 0.05))
put("tooth", 1, 2, cell_rgb((0.86, 0.80, 0.62), 0.03))
put("root", 2, 2, cell_rgb((0.70, 0.60, 0.40), 0.04))
# peace medallion: brass disc with the sign as dark strokes, drawn to fill the cell
m = cell_rgb((0.70, 0.56, 0.26), 0.04)
yy, xx = np.mgrid[0:CELL, 0:CELL]
cx = cy = (CELL - 1) / 2.0
rr = np.hypot(xx - cx, yy - cy)
ring = (rr > 24) & (rr < 30)
stem = (np.abs(xx - cx) < 3) & (rr < 30)
legs = ((np.abs((yy - cy) - 0.75 * (xx - cx) * 1.0) < 3.2) | (np.abs((yy - cy) + 0.75 * (xx - cx)) < 3.2)) \
    & (yy < cy) & (rr < 30)
m[ring | stem | legs] = np.array([0.10, 0.08, 0.05])
put("peace", 3, 2, m)
mat = D.materials.new("necklace_kit_mat")
mat.use_nodes = True
nt = mat.node_tree
bsdf = nt.nodes["Principled BSDF"]
bsdf.inputs["Roughness"].default_value = 0.8
bsdf.inputs["Specular IOR Level"].default_value = 0.2
tex = nt.nodes.new("ShaderNodeTexImage")
tex.interpolation = 'Closest'
nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])


def write_sheet():
    """sRGB-encoded bytes go into a byte image (blender-image-pixels-are-srgb-bytes).
    Called once after every cell is painted (the ear cells land in section 4a)."""
    img = D.images.new("necklace_kit_tex", TEX, TEX, alpha=True)
    img.pixels.foreach_set(np.ascontiguousarray(sheet, dtype=np.float32).ravel())
    img.filepath_raw = OUT_TEX
    img.file_format = 'PNG'
    img.save()
    D.images.remove(img)
    img = D.images.load(OUT_TEX)
    img.name = "necklace_kit_tex"
    img.pack()
    tex.image = img
    log("TEXTURE %s %dx%d, %d KB" % (OUT_TEX, img.size[0], img.size[1], os.path.getsize(OUT_TEX) // 1024))
    return img


def cell_uv(name, u, v):
    """(u,v) in 0..1 inside the named cell -> sheet UV (1.5-px inset so Closest never bleeds)."""
    x0, y0, s = CELLS[name]
    inset = 1.5 / TEX
    return (x0 / TEX + inset + u * (s / TEX - 2 * inset), y0 / TEX + inset + v * (s / TEX - 2 * inset))


cord_me.materials.append(mat)
uvl = cord_me.uv_layers.new(name="UVMap")
for p in cord_me.polygons:
    for j, li in enumerate(p.loop_indices):
        uvl.data[li].uv = cell_uv("cord", (j % 2) * 0.9, ((j // 2) % 2) * 0.9)
    p.use_smooth = False

# ---------------------------------------------------------------------------
# 4. the charm library - each its own object, origin at the hang point,
#    hanging down -Z, display face toward -Y  (glTF: -Y down, +Z front)
# ---------------------------------------------------------------------------
charms = {}


def finish(name, vs, fs, uvs, mats, budget=(20, 80), register=True, no_ngons=False):
    """vs: list of Vector, fs: list of index tuples, uvs: per-face list of (u,v) per loop,
    mats: per-face cell name."""
    me = D.meshes.new(name)
    me.from_pydata(vs, [], fs)
    me.update()
    me.materials.append(mat)
    uvl = me.uv_layers.new(name="UVMap")
    for p, cellname, fuv in zip(me.polygons, mats, uvs):
        p.use_smooth = False
        for li, (u, v) in zip(p.loop_indices, fuv):
            uvl.data[li].uv = cell_uv(cellname, u, v)
    # consistent outward normals - the builders wind by hand, this catches a slip
    bpy.ops.object.select_all(action='DESELECT')
    o = D.objects.new(name, me)
    SC.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    bb = [Vector(c) for c in o.bound_box]
    mn = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    mx = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    assert budget[0] <= tris <= budget[1], "%s is %d tris, budget is %d-%d" % (name, tris, *budget)
    if no_ngons:                      # the ears; the plate charms are n-gon plates by design
        assert not any(len(p.vertices) > 4 for p in me.polygons), "%s has n-gons" % name
    assert mx.z <= 0.008 and mn.z < -0.015, "%s hang point is not at the top (z %.3f..%.3f)" % (name, mn.z, mx.z)
    assert mn.x < 0 < mx.x, "%s origin is not inside the charm in X" % name
    log("CHARM %-22s %3d tris  %2d v  size %.1f x %.1f x %.1f mm (w x depth x h)  z[%.3f,%.3f]"
        % (name, tris, len(me.vertices), (mx.x - mn.x) * 1000, (mx.y - mn.y) * 1000,
           (mx.z - mn.z) * 1000, mn.z, mx.z))
    if register:
        charms[name] = o
    return o


def planar_uv(cellname, vs, idx, axis=("x", "z"), pad=0.05):
    """UV for a set of verts by planar projection of two axes into the cell."""
    xs = [getattr(vs[i], axis[0]) for i in idx]
    zs = [getattr(vs[i], axis[1]) for i in idx]
    x0, x1, z0, z1 = min(xs), max(xs), min(zs), max(zs)
    out = []
    for i in idx:
        u = pad + (1 - 2 * pad) * (getattr(vs[i], axis[0]) - x0) / max(x1 - x0, 1e-9)
        v = pad + (1 - 2 * pad) * (getattr(vs[i], axis[1]) - z0) / max(z1 - z0, 1e-9)
        out.append((u, v))
    return out


def box(vs, fs, uvs, mats, c, sx, sy, sz, cellname, skip=()):
    """axis-aligned box, half sizes; faces named +x -x +y -y +z -z; skip hides faces."""
    b = len(vs)
    for dz in (-1, 1):
        for dy in (-1, 1):
            for dx in (-1, 1):
                vs.append(Vector((c[0] + dx * sx, c[1] + dy * sy, c[2] + dz * sz)))
    # index: dx + 2*dy + 4*dz with d in {0,1}
    F = {"-z": (0, 2, 3, 1), "+z": (4, 5, 7, 6), "-y": (0, 1, 5, 4), "+y": (2, 6, 7, 3),
         "-x": (0, 4, 6, 2), "+x": (1, 3, 7, 5)}
    for k, f in F.items():
        if k in skip:
            continue
        fs.append(tuple(b + i for i in f))
        uvs.append([(0.1, 0.1), (0.9, 0.1), (0.9, 0.9), (0.1, 0.9)])
        mats.append(cellname)


def tube(vs, fs, uvs, mats, rings, cellname, cap_top=True, cap_bot=True, cap_cell=None):
    """rings: list of (centre Vector, radius, sides) stacked top->bottom along -z."""
    b = len(vs)
    n = rings[0][2]
    for c, r, _ in rings:
        for j in range(n):
            a = 2 * math.pi * j / n
            vs.append(Vector((c.x + r * math.cos(a), c.y + r * math.sin(a), c.z)))
    for k in range(len(rings) - 1):
        for j in range(n):
            i0, i1 = b + k * n + j, b + k * n + (j + 1) % n
            i2, i3 = b + (k + 1) * n + (j + 1) % n, b + (k + 1) * n + j
            fs.append((i0, i3, i2, i1))
            u0, u1 = j / float(n), (j + 1) / float(n)
            uvs.append([(u0, 0.9), (u0, 0.1), (u1, 0.1), (u1, 0.9)])
            mats.append(cellname)
    if cap_top:
        fs.append(tuple(b + j for j in range(n)))
        uvs.append([(0.5 + 0.4 * math.cos(2 * math.pi * j / n), 0.5 + 0.4 * math.sin(2 * math.pi * j / n)) for j in range(n)])
        mats.append(cap_cell or cellname)
    if cap_bot:
        k = len(rings) - 1
        fs.append(tuple(b + k * n + j for j in reversed(range(n))))
        uvs.append([(0.5 + 0.4 * math.cos(2 * math.pi * j / n), 0.5 + 0.4 * math.sin(2 * math.pi * j / n)) for j in reversed(range(n))])
        mats.append(cap_cell or cellname)


# ---------------------------------------------------------------------------
# 4a. the severed ear and its five decay stages (Caleb 2026-09-12: "the cut off ears need to
#     be more realistic, as well as a few in various stages of decay" - fresh -> days ->
#     rotten -> dried -> old)
#
# Adult male auricle, anthropometry (Alexander et al. 2011 / Sforza 2009; PubMed 34821348,
# researchgate 325715107): height 63 mm, width 33 mm, lobe 18 x 19 mm, concha 27 mm long,
# projection ~17 mm. Landmarks traced off Gray's Anatomy plates 904 (front) and 905 (cartilage
# from behind, Wikimedia PD) and a colour photo of a living ear (Commons Earcov.JPG). Decay
# colours from the forensic mummification series (PMC10247854): green/grey discoloration,
# slippage and bloating in wet decay; yellow-orange parchment at 3-10 days; red-brown to black
# leather after ~6 days; ears, fingers and toes dry first. Shrink ratios are the brief's.
#
# Coordinates in mm: x across (tragus/face side = -x, helix = +x), z up, d = how far the
# surface stands FORWARD of the cut plane (y = -d). The cut plane (y = 0) is where the auricle
# attached: behind the concha (eminentia conchae), the tragus root and the lobe root. Origin =
# hang point = on the helix rim 5 mm below the crown, x under the crown.
# Five concentric rings: A outline, B helix crest (tragus / lobe surface at the front), C scapha
# groove, D antihelix crest, E concha floor; K = the cut face on the back (shares A8..A10).
# ---------------------------------------------------------------------------
EAR_A = [(2, 31.5, 10), (11, 27.5, 10.5), (16, 15, 10), (16.5, 1, 9.5), (13, -12, 8), (8, -23, 5.5),
         (1, -31.5, 3.5), (-6.5, -27, 1.5), (-8, -14, 1.5), (-15, -2, 3), (-12, 12, 0.5), (-7, 27.5, 7)]
EAR_B = [(2, 28, 15), (9, 24.5, 15.5), (12.5, 13.5, 15), (13, 1, 14), (10.5, -11, 12), (6, -21, 9),
         (1, -27.5, 7), (-4.5, -24, 5), (-6, -13.5, 5.5), (-11.5, -2, 6.5), (-9.5, 11, 5.5), (-4.5, 24.5, 11.5)]
EAR_C = [(1, 24.5, 10.5), (7, 20.5, 11), (9.5, 11, 10.5), (10, 1, 9.5), (8, -9, 8), (4, -17, 7),
         (0.5, -21, 6), (-3.5, -18, 4.5), (-5, -11.5, 4), (-8.5, -1, 3.5), (-7, 10, 4.5), (-2.5, 20, 7.5)]
EAR_D = [(1, 20, 13), (5, 16.5, 13.5), (7, 8, 13), (7.5, 0, 12.5), (6, -7.5, 11), (3, -13, 9),
         (0, -15, 6.5), (-2.5, -12, 5.5), (-4, -8, 5.5), (-6.5, -1, 4.5), (-5.5, 9, 5.5), (-2, 15, 10)]
EAR_E = [(1, 10, 2.5), (4, 3, 2.5), (3, -4, 2.5), (-1, -7, 2.5), (-4, -1, 1.5), (-2.5, 6, 2.5)]
EAR_K = [(-5, -20, 0), (4, -14, 0), (7, -1, 0), (5, 12, 0), (-3, 21, 0)]   # K3..K7; K0..2 = A10,A9,A8
K_POLY = [(-12, 12), (-15, -2), (-8, -14), (-5, -20), (4, -14), (7, -1), (5, 12), (-3, 21)]
EAR_HANG_X, EAR_HANG_Z = 1.0, 26.5      # origin in table space (crown at +5 mm)
HELIX_A = [11, 0, 1, 2, 3, 4, 5]        # outline verts that are helix cartilage (these curl)
HELIX_B = [11, 0, 1, 2, 3, 4]
# stage ladder: scale about the hang point / helix roll-in 0..1 / depth multiplier /
# mm of wet bloat along the normal / mm of shrivel jitter
EAR_STAGES = {
    "fresh":  dict(scale=1.00, curl=0.00, flat=1.00, swell=0.0, shrivel=0.0),
    "days":   dict(scale=0.85, curl=0.20, flat=0.92, swell=0.0, shrivel=0.0),
    "rotten": dict(scale=0.98, curl=0.05, flat=1.05, swell=1.0, shrivel=0.3),
    "dried":  dict(scale=0.65, curl=0.60, flat=0.65, swell=0.0, shrivel=0.45),
    "old":    dict(scale=0.55, curl=0.80, flat=0.50, swell=0.0, shrivel=0.75),
}
EAR_ORDER = ["fresh", "days", "rotten", "dried", "old"]
EAR_BUDGET = (90, 140)
# the front projection: ear (x, z) table space -> cell (u, v); one FIXED bbox (ring A) for every
# face so the paint lands on the geometry it describes (per-face bbox UVs smear a whole cell
# over each face - that is what made the old ear a flat disc)
FX0, FX1, FZ0, FZ1 = -16.0, 16.5, -31.5, 31.5
KX0, KX1, KZ0, KZ1 = -15.0, 7.0, -21.0, 21.0
UPAD = 0.04


def ear_topology():
    """verts (mm, base pose) + faces + per-face zone ('front' | 'back' | 'cut')."""
    vs = []
    for ring in (EAR_A, EAR_B, EAR_C, EAR_D, EAR_E, EAR_K):
        for (x, z, d) in ring:
            vs.append(Vector((x - EAR_HANG_X, -d, z - EAR_HANG_Z)))
    A, B, C, Dd, E, K3 = 0, 12, 24, 36, 48, 54
    fs, zone = [], []

    def ring_quads(r0, r1, n=12):
        for i in range(n):
            j = (i + 1) % n
            fs.append((r0 + i, r0 + j, r1 + j, r1 + i)); zone.append("front")
    ring_quads(A, B); ring_quads(B, C); ring_quads(C, Dd)
    for j in range(6):
        d0, d1, d2 = Dd + 2 * j, Dd + 2 * j + 1, Dd + (2 * j + 2) % 12
        e0, e1 = E + j, E + (j + 1) % 6
        fs.append((d0, d1, e0)); zone.append("front")
        fs.append((d1, d2, e1, e0)); zone.append("front")
    fs.append((E + 0, E + 1, E + 2, E + 5)); zone.append("front")
    fs.append((E + 5, E + 2, E + 3, E + 4)); zone.append("front")
    a = lambda i: A + i
    k = lambda i: K3 + (i - 3)
    back = [(a(10), a(11), k(7)), (a(11), a(0), k(6), k(7)), (a(0), a(1), k(6)), (a(1), a(2), k(5), k(6)),
            (a(2), a(3), k(5)), (a(3), a(4), k(4), k(5)), (a(4), a(5), k(4)), (a(5), a(6), k(3), k(4)),
            (a(6), a(7), k(3)), (a(7), a(8), k(3))]
    for f in back:
        fs.append(f); zone.append("back")
    for f in [(a(10), a(9), k(5), k(6)), (a(9), a(8), k(4), k(5)), (a(8), k(3), k(4)), (a(10), k(6), k(7))]:
        fs.append(f); zone.append("cut")
    return vs, fs, zone


def ear_stage_verts(base, normals, st, seed=3):
    """deform the base (mm) into a decay stage; returns Vectors in metres, back plane at y = 0."""
    r = np.random.RandomState(seed)
    out = [v.copy() for v in base]
    cx, cz = -EAR_HANG_X, -EAR_HANG_Z            # curl toward the concha centre (table 0, 0)
    for ring0, ids, inward, fwd in ((0, HELIX_A, 5.0, 4.0), (12, HELIX_B, 2.5, 2.0)):
        for i in ids:
            v = out[ring0 + i]
            to_c = Vector((cx - v.x, 0, cz - v.z))
            to_c = to_c.normalized() if to_c.length > 1e-6 else Vector((0, 0, 0))
            out[ring0 + i] = v + to_c * (inward * st["curl"]) + Vector((0, -fwd * st["curl"], 0))
    for i, v in enumerate(out):
        v.y *= st["flat"]
        if st["swell"]:
            v += normals[i] * st["swell"]
        if st["shrivel"]:
            j = r.uniform(-1, 1, 3)
            v += Vector((j[0] * 0.6, j[1] * 1.0, j[2] * 0.6)) * st["shrivel"]
        out[i] = v
    ymax = max(v.y for v in out)
    return [Vector((v.x, v.y - ymax, v.z)) * st["scale"] * 0.001 for v in out]


def inside_poly(px, pz, poly):
    """vectorised even-odd point-in-polygon; poly = [(x, z), ...]."""
    inside = np.zeros(px.shape, dtype=bool)
    n = len(poly)
    for i in range(n):
        x0, z0 = poly[i]
        x1, z1 = poly[(i + 1) % n]
        cond = (z0 > pz) != (z1 > pz)
        xint = (x1 - x0) * (pz - z0) / ((z1 - z0) if z1 != z0 else 1e-9) + x0
        inside ^= cond & (px < xint)
    return inside


def smooth_noise(size, cells, seed):
    """low-frequency noise 0..1: bilinear upsample of a coarse random grid."""
    r = np.random.RandomState(seed)
    g = r.uniform(0, 1, (cells + 1, cells + 1))
    ys = np.linspace(0, cells, size, endpoint=False)
    xs = np.linspace(0, cells, size, endpoint=False)
    yi, xi = np.floor(ys).astype(int), np.floor(xs).astype(int)
    yf, xf = (ys - yi)[:, None], (xs - xi)[None, :]
    a_, b_, c_, d_ = g[yi][:, xi], g[yi][:, xi + 1], g[yi + 1][:, xi], g[yi + 1][:, xi + 1]
    return a_ * (1 - xf) * (1 - yf) + b_ * xf * (1 - yf) + c_ * (1 - xf) * yf + d_ * xf * yf


# stage palettes, sRGB-encoded. fresh skin = face-atlas cheek tone (SKIN) warmed toward pink.
EAR_PAL = {
    "fresh":  dict(skin=(0.66, 0.46, 0.37), rim=(0.74, 0.46, 0.42), scapha=(0.56, 0.36, 0.30),
                   anti=(0.72, 0.50, 0.42), concha=(0.44, 0.27, 0.22), floor=(0.30, 0.16, 0.14),
                   lobe=(0.68, 0.46, 0.39), meat=(0.46, 0.06, 0.05), rimblood=(0.58, 0.09, 0.07),
                   cart=(0.86, 0.82, 0.72), back=(0.64, 0.45, 0.36), crust=None),
    "days":   dict(skin=(0.56, 0.41, 0.30), rim=(0.40, 0.25, 0.15), scapha=(0.50, 0.35, 0.24),
                   anti=(0.55, 0.39, 0.28), concha=(0.42, 0.28, 0.19), floor=(0.30, 0.18, 0.12),
                   lobe=(0.57, 0.42, 0.31), meat=(0.28, 0.11, 0.07), rimblood=(0.22, 0.08, 0.05),
                   cart=(0.66, 0.60, 0.46), back=(0.50, 0.35, 0.25), crust=(0.20, 0.09, 0.05)),
    "rotten": dict(skin=(0.44, 0.43, 0.31), rim=(0.38, 0.40, 0.29), scapha=(0.40, 0.39, 0.30),
                   anti=(0.47, 0.45, 0.34), concha=(0.26, 0.24, 0.20), floor=(0.14, 0.11, 0.10),
                   lobe=(0.52, 0.46, 0.40), meat=(0.24, 0.10, 0.09), rimblood=(0.62, 0.56, 0.46),
                   cart=(0.58, 0.52, 0.40), back=(0.46, 0.44, 0.34), crust=None),
    "dried":  dict(skin=(0.34, 0.21, 0.11), rim=(0.24, 0.14, 0.07), scapha=(0.30, 0.18, 0.10),
                   anti=(0.36, 0.22, 0.12), concha=(0.22, 0.13, 0.07), floor=(0.14, 0.08, 0.05),
                   lobe=(0.33, 0.20, 0.11), meat=(0.18, 0.09, 0.05), rimblood=(0.13, 0.07, 0.04),
                   cart=(0.52, 0.44, 0.31), back=(0.30, 0.18, 0.10), crust=(0.12, 0.06, 0.03)),
    "old":    dict(skin=(0.13, 0.09, 0.06), rim=(0.09, 0.06, 0.04), scapha=(0.11, 0.08, 0.05),
                   anti=(0.15, 0.10, 0.07), concha=(0.08, 0.05, 0.04), floor=(0.05, 0.03, 0.02),
                   lobe=(0.12, 0.08, 0.05), meat=(0.10, 0.06, 0.04), rimblood=(0.07, 0.04, 0.03),
                   cart=(0.30, 0.25, 0.18), back=(0.11, 0.07, 0.05), crust=(0.05, 0.03, 0.02)),
}


def paint_ear_front(stage, size=128):
    """the front cell: zones by ring membership in the same table space the mesh is built in."""
    p = EAR_PAL[stage]
    yy, xx = np.mgrid[0:size, 0:size]
    u, v = (xx + 0.5) / size, (yy + 0.5) / size
    x = FX0 + (u - UPAD) / (1 - 2 * UPAD) * (FX1 - FX0)
    z = FZ0 + (v - UPAD) / (1 - 2 * UPAD) * (FZ1 - FZ0)
    inA, inB, inC, inD, inE = [inside_poly(x, z, [(a_, b_) for (a_, b_, _) in r]) for r in (EAR_A, EAR_B, EAR_C, EAR_D, EAR_E)]
    img = np.ones((size, size, 3)) * np.array(p["skin"])
    img[inA & ~inB] = p["rim"]
    img[inB & ~inC] = p["scapha"]
    img[inC & ~inD] = p["anti"]
    img[inD & ~inE] = p["concha"]
    img[inE] = p["floor"]
    img[inA & (z < -15)] = p["lobe"]
    tragus = inA & ~inC & (x < -9) & (z > -9) & (z < 9)
    img[tragus] = np.array(p["anti"]) * 1.02
    img[np.hypot(x + 4, z + 1) < 3.2] = np.array(p["floor"]) * 0.55          # meatus
    depth = np.clip(1 - np.hypot((x + 1) / 10.0, (z - 1) / 14.0), 0, 1)
    img[inD] *= (1 - 0.25 * depth[inD])[:, None]
    img[np.hypot(x - EAR_HANG_X, z - EAR_HANG_Z) < 1.6] = (0.05, 0.03, 0.03)  # the cord hole
    n1 = smooth_noise(size, 6, 11 + len(stage))
    n2 = smooth_noise(size, 14, 23 + len(stage))
    if stage == "rotten":
        green, purple = np.array((0.36, 0.42, 0.28)), np.array((0.44, 0.34, 0.38))
        w = np.clip((n1 - 0.45) * 2.5, 0, 1)[..., None]
        img = img * (1 - 0.6 * w) + green * 0.6 * w
        w2 = np.clip((n2 - 0.6) * 3.0, 0, 1)[..., None]
        img = img * (1 - 0.5 * w2) + purple * 0.5 * w2
        vein = np.abs(np.sin(x * 0.9 + n2 * 6.0) * np.cos(z * 0.5 + n1 * 4.0)) > 0.985
        img[vein & inA] *= 0.7
        img[inA & ~inB & (n2 > 0.55)] = np.array(p["rimblood"])                # slipping skin
        sheen = ((inA & ~inB) | (inC & ~inD)) & (n2 > 0.72)
        img[sheen] = np.clip(img[sheen] * 1.25, 0, 1)
    elif stage == "fresh":
        sheen = ((inB & ~inC) | (inC & ~inD)) & (n2 > 0.70)
        img[sheen] = np.clip(img[sheen] * 1.18, 0, 1)
        run = inA & (x < -8) & (x > -15) & (z < 14) & (n2 > 0.5)                 # blood off the cut
        img[run] = np.array(p["meat"]) * 0.9 + img[run] * 0.1
    elif stage == "days":
        edge = inA & ~inC
        w = np.clip((n1 * 0.5 + 0.5) * edge.astype(float), 0, 1)[..., None]
        img = img * (1 - 0.5 * w) + np.array(p["rim"]) * 0.5 * w             # brown from the rim in
        img[inA & (x < -10) & (n2 > 0.5)] = p["crust"]
    else:
        img *= (0.85 + 0.3 * n2)[..., None]
        r = np.random.RandomState(5 if stage == "dried" else 9)
        for _ in range(8 if stage == "dried" else 14):
            cx0, cz0, ang, L = r.uniform(FX0, FX1), r.uniform(FZ0, FZ1), r.uniform(0, math.pi), r.uniform(6, 16)
            for t in np.linspace(0, L, int(L * 3)):
                px = cx0 + math.cos(ang) * t + math.sin(t * 1.3) * 0.6
                pz = cz0 + math.sin(ang) * t + math.cos(t * 1.1) * 0.6
                m = (np.abs(x - px) < 0.6) & (np.abs(z - pz) < 0.6)
                img[m] = np.array(p["crust"]) if stage == "dried" else np.array((0.03, 0.02, 0.015))
                if stage == "old":
                    m2 = (np.abs(x - px - 0.7) < 0.5) & (np.abs(z - pz) < 0.5)
                    img[m2] = np.clip(img[m2] * 1.35 + 0.015, 0, 1)
        if stage == "old":
            img *= (0.8 + 0.4 * (np.sin(x * 1.7 + z * 0.9 + n1 * 5) > 0.3))[..., None]
    img += rng.uniform(-0.03, 0.03, (size, size, 1))
    img[~inA] = np.array(p["rim"]) * 0.9
    return np.clip(img, 0, 1)


def paint_ear_cut(stage, size=64):
    """the cut face: meat inside a blood/crust rim, the concha cartilage plate seen edge-on as a
    pale arc, fat globules; K's own planar projection."""
    p = EAR_PAL[stage]
    yy, xx = np.mgrid[0:size, 0:size]
    u, v = (xx + 0.5) / size, (yy + 0.5) / size
    x = KX0 + (u - UPAD) / (1 - 2 * UPAD) * (KX1 - KX0)
    z = KZ0 + (v - UPAD) / (1 - 2 * UPAD) * (KZ1 - KZ0)
    inK = inside_poly(x, z, K_POLY)
    cx, cz = np.mean([q[0] for q in K_POLY]), np.mean([q[1] for q in K_POLY])
    inner = inside_poly(x, z, [(cx + (a_ - cx) * 0.78, cz + (b_ - cz) * 0.78) for a_, b_ in K_POLY])
    img = np.ones((size, size, 3)) * np.array(p["meat"])
    img[inK & ~inner] = p["rimblood"]
    n2 = smooth_noise(size, 8, 31 + len(stage))
    img *= (0.85 + 0.3 * n2)[..., None]
    for t in np.linspace(0, 1, 60):
        px, pz = -7 + 9 * math.sin(t * math.pi) + t * 0.5, 15 - 30 * t
        img[(np.abs(x - px) < 0.9) & (np.abs(z - pz) < 0.9) & inK] = p["cart"]
    r = np.random.RandomState(41)
    for _ in range(6):
        m = (np.hypot(x - r.uniform(-12, 3), z - r.uniform(-16, 16)) < 1.3) & inK
        img[m] = np.array(p["cart"]) * 0.75 + np.array(p["meat"]) * 0.25
    if stage in ("fresh", "rotten"):
        gl = inK & (n2 > 0.66)
        img[gl] = np.clip(img[gl] * 1.5 + 0.06, 0, 1)                           # wet gloss
    if stage == "rotten":
        img[inK & ~inner] = np.array(p["rimblood"]) * (0.9 + 0.2 * n2[inK & ~inner])[:, None]
    img[~inK] = np.array(p["rimblood"]) * 0.9
    return np.clip(img, 0, 1)


def paint_ear_back(stage, size=64):
    p = EAR_PAL[stage]
    a_ = cell_rgb(p["back"], 0.04, (size, size))
    n1 = smooth_noise(size, 5, 51 + len(stage))
    a_ *= (0.85 + 0.3 * n1)[..., None]
    if stage == "rotten":
        w = np.clip((n1 - 0.4) * 2.0, 0, 1)[..., None]
        a_ = a_ * (1 - 0.5 * w) + np.array((0.36, 0.42, 0.28)) * 0.5 * w
    if stage in ("dried", "old"):
        a_ *= (0.8 + 0.4 * (smooth_noise(size, 12, 7) > 0.55))[..., None]
    return np.clip(a_, 0, 1)


# ear cells: five 128-px fronts, 64-px backs and cuts, all outside the old 256 quadrant
EAR_FRONT_POS = [(256, 0), (384, 0), (256, 128), (384, 128), (0, 256)]
for i, stg in enumerate(EAR_ORDER):
    put_px("ear_%s_front" % stg, EAR_FRONT_POS[i][0], EAR_FRONT_POS[i][1], paint_ear_front(stg))
    put_px("ear_%s_back" % stg, 128 + 64 * i, 256, paint_ear_back(stg))
    put_px("ear_%s_cut" % stg, 128 + 64 * i, 320, paint_ear_cut(stg))
img = write_sheet()


def ear_face_uv(base_vs, face, z):
    out = []
    for vi in face:
        x, zz = base_vs[vi].x + EAR_HANG_X, base_vs[vi].z + EAR_HANG_Z
        if z == "cut":
            out.append((UPAD + (1 - 2 * UPAD) * (x - KX0) / (KX1 - KX0), UPAD + (1 - 2 * UPAD) * (zz - KZ0) / (KZ1 - KZ0)))
        else:
            out.append((UPAD + (1 - 2 * UPAD) * (x - FX0) / (FX1 - FX0), UPAD + (1 - 2 * UPAD) * (zz - FZ0) / (FZ1 - FZ0)))
    return out


def build_ears():
    """one base mesh (for winding + normals), five stages derived from it, plus `charm_ear`
    as an alias of the days stage so the dresser's append and the old GLB name keep working."""
    base_vs, fs, zone = ear_topology()
    me0 = D.meshes.new("ear_base")
    me0.from_pydata([v * 0.001 for v in base_vs], [], fs)
    me0.update()
    o0 = D.objects.new("ear_base", me0)
    SC.collection.objects.link(o0)
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = o0
    o0.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    faces = [tuple(p.vertices) for p in me0.polygons]
    front_ny = np.mean([me0.polygons[i].normal.y for i in range(len(fs)) if zone[i] == "front"])
    cut_ny = np.mean([me0.polygons[i].normal.y for i in range(len(fs)) if zone[i] == "cut"])
    assert front_ny < -0.5 and cut_ny > 0.9, "ear winding: front %.2f cut %.2f" % (front_ny, cut_ny)
    normals = [Vector(me0.vertex_normals[i].vector) for i in range(len(me0.vertices))]
    D.objects.remove(o0, do_unlink=True)
    D.meshes.remove(me0)
    out = {}
    for stg in EAR_ORDER:
        vs = ear_stage_verts(base_vs, normals, EAR_STAGES[stg])
        uvs = [ear_face_uv(base_vs, f, z) for f, z in zip(faces, zone)]
        mats = ["ear_%s_%s" % (stg, z) for z in zone]
        out[stg] = finish("charm_ear_" + stg, vs, faces, uvs, mats, budget=EAR_BUDGET, no_ngons=True)
    alias = D.objects.new("charm_ear", out["days"].data.copy())
    alias.data.name = "charm_ear"
    SC.collection.objects.link(alias)
    charms["charm_ear"] = alias
    return out


# --- charm_dogtags: two 51 x 29 mm tags on a ball-chain stub, the second tag hung a
# little lower and turned so the pair reads as two plates, not one thick one.
def build_dogtags():
    vs, fs, uvs, mats = [], [], [], []
    # chain stub: 2.4 mm ball chain, 4 sides, from the cord down 24 mm
    tube(vs, fs, uvs, mats, [(Vector((0, -0.002, 0.0)), 0.0012, 4),
                             (Vector((0, -0.002, -0.024)), 0.0012, 4)], "chain",
         cap_top=False, cap_bot=False)
    def tag(cx, cy, top, rot):
        # 0.6 mm plate: front and back are separate 8-gons on their own verts (a
        # zero-thickness double face shares every edge, is an invalid mesh, and the glTF
        # exporter silently dropped 12 of its 32 tris - measured on the first export)
        w, h = 0.0286, 0.0508
        prof = [(-w / 2 + 0.004, 0), (w / 2 - 0.004, 0), (w / 2, -0.004), (w / 2, -h + 0.004),
                (w / 2 - 0.004, -h), (-w / 2 + 0.004, -h), (-w / 2, -h + 0.004), (-w / 2, -0.004)]
        ca, sa = math.cos(rot), math.sin(rot)
        for side, dy in ((1, -0.0003), (-1, 0.0003)):
            b = len(vs)
            for (px, pz) in prof:
                vs.append(Vector((cx + px * ca, cy + px * sa + dy, top + pz)))
            order = list(range(8)) if side == 1 else list(reversed(range(8)))
            fs.append(tuple(b + i for i in order))
            uvs.append(planar_uv("dogtag", vs, [b + i for i in order]))
            mats.append("dogtag")
    tag(0.0, -0.0045, -0.020, math.radians(6))
    tag(0.004, -0.0012, -0.026, math.radians(-14))
    return finish("charm_dogtags", vs, fs, uvs, mats)


# --- charm_round_556: 5.56x45 ball, 57.4 mm OAL. Case 44.7 mm: rim 9.6, body to the
# shoulder at 36.5 mm, neck 6.4 mm dia, bullet 5.7 mm dia to a point. Hung by the rim
# (the cord ties in the extractor groove), tip down.
def build_round():
    vs, fs, uvs, mats = [], [], [], []
    y = -0.0055
    # the extractor groove is 1.5 mm of relief nobody sees at 1 m; rim -> shoulder -> neck
    rings = [(Vector((0, y, 0.0)), 0.0048, 6), (Vector((0, y, -0.0365)), 0.0045, 6),
             (Vector((0, y, -0.0400)), 0.0032, 6), (Vector((0, y, -0.0447)), 0.0032, 6)]
    tube(vs, fs, uvs, mats, rings, "brass", cap_top=True, cap_bot=False)
    bullet = [(Vector((0, y, -0.0447)), 0.00285, 6), (Vector((0, y, -0.0520)), 0.0024, 6),
              (Vector((0, y, -0.0574)), 0.0004, 6)]
    tube(vs, fs, uvs, mats, bullet, "copper", cap_top=False, cap_bot=True)
    return finish("charm_round_556", vs, fs, uvs, mats)


# --- charm_p38: the folded opener, 38 x 15 mm, 1 mm plate with the blade folded flat
# against it (a 4 mm bump) and the key-hole at the top where the cord goes.
def build_p38():
    vs, fs, uvs, mats = [], [], [], []
    box(vs, fs, uvs, mats, (0, -0.0025, -0.019), 0.0075, 0.0005, 0.019, "parker")
    box(vs, fs, uvs, mats, (0.0015, -0.0045, -0.026), 0.0045, 0.0012, 0.010, "parker", skip=("+y",))
    box(vs, fs, uvs, mats, (-0.0055, -0.0045, -0.014), 0.0018, 0.0010, 0.006, "parker", skip=("+y",))
    return finish("charm_p38", vs, fs, uvs, mats)


# --- charm_crucifix: 40 x 25 mm, 3.5 mm bars, a bail at the top. Two boxes; the join
# is hidden inside the upright, which is what a stamped tin cross looks like anyway.
def build_crucifix():
    vs, fs, uvs, mats = [], [], [], []
    tube(vs, fs, uvs, mats, [(Vector((0, -0.003, 0.000)), 0.0025, 4), (Vector((0, -0.003, -0.006)), 0.0025, 4)],
         "silver", cap_top=True, cap_bot=False)
    box(vs, fs, uvs, mats, (0, -0.003, -0.026), 0.00175, 0.0009, 0.020, "silver", skip=("+z",))
    box(vs, fs, uvs, mats, (0, -0.003, -0.019), 0.0125, 0.0008, 0.00175, "silver")
    return finish("charm_crucifix", vs, fs, uvs, mats)


# --- charm_peace_medallion: 38 mm brass disc, 2 mm thick, the sign painted on both
# faces (the texture cell IS the sign), bail at the top.
def build_medallion():
    vs, fs, uvs, mats = [], [], [], []
    tube(vs, fs, uvs, mats, [(Vector((0, -0.003, 0.000)), 0.0025, 4), (Vector((0, -0.003, -0.006)), 0.0025, 4)],
         "brass", cap_top=True, cap_bot=False)
    b = len(vs)
    n = 12
    R = 0.019
    cz = -0.006 - R
    for yy in (-0.004, -0.002):
        for j in range(n):
            a = 2 * math.pi * j / n
            vs.append(Vector((R * math.cos(a), yy, cz + R * math.sin(a))))
    fs.append(tuple(b + j for j in range(n)))                        # front (y=-0.004) faces -y
    uvs.append([(0.5 + 0.48 * math.cos(2 * math.pi * j / n), 0.5 + 0.48 * math.sin(2 * math.pi * j / n)) for j in range(n)])
    mats.append("peace")
    fs.append(tuple(b + n + j for j in reversed(range(n))))          # back
    uvs.append([(0.5 + 0.48 * math.cos(2 * math.pi * j / n), 0.5 + 0.48 * math.sin(2 * math.pi * j / n)) for j in reversed(range(n))])
    mats.append("peace")
    for j in range(n):
        k = (j + 1) % n
        fs.append((b + j, b + k, b + n + k, b + n + j))
        uvs.append([(0.1, 0.1), (0.9, 0.1), (0.9, 0.9), (0.1, 0.9)])
        mats.append("brass")
    return finish("charm_peace_medallion", vs, fs, uvs, mats)


# --- charm_tooth: a molar, 20 mm root tip to crown, 9 mm crown, two splayed roots.
# Tied by the roots, crown down.
def build_tooth():
    vs, fs, uvs, mats = [], [], [], []
    y = -0.005
    for rx in (-0.0025, 0.0025):
        tube(vs, fs, uvs, mats, [(Vector((rx * 1.4, y, 0.000)), 0.0010, 4),
                                 (Vector((rx, y, -0.009)), 0.0022, 4)], "root",
             cap_top=True, cap_bot=False)
    crown = [(Vector((0, y, -0.009)), 0.0044, 6), (Vector((0, y, -0.015)), 0.0050, 6),
             (Vector((0, y, -0.020)), 0.0040, 6)]
    tube(vs, fs, uvs, mats, crown, "tooth", cap_top=False, cap_bot=True)
    return finish("charm_tooth", vs, fs, uvs, mats)


ears = build_ears()
build_dogtags()
build_round()
build_p38()
build_crucifix()
build_medallion()
build_tooth()

# park the library in a row beside the dummy (OBJECT transforms only, verts stay at origin);
# the `charm_ear` alias shares the days mesh and is export-only, so it is not in the row
LIBRARY = [nm for nm in sorted(charms) if nm != "charm_ear"]
LIB_PITCH = 0.06
for i, nm in enumerate(LIBRARY):
    charms[nm].location = Vector((1.0 + LIB_PITCH * i, 0.0, 1.45))
charms["charm_ear"].location = Vector((1.0, 0.0, 1.30))

# ---------------------------------------------------------------------------
# 5. fit preview: 15 ears on the dummy, poke-through gate
# ---------------------------------------------------------------------------
preview = []


# the worn string: a realistic mix, mostly dried/old, two days, one rotten, two fresh, no
# neat order; odd slots are mirrored (a necklace holds left AND right ears - preview only,
# the shipped GLBs are one handedness and the engine can scale x = -1)
WORN_MIX = ["old", "dried", "old", "days", "dried", "old", "fresh", "dried", "rotten", "old",
            "dried", "days", "old", "dried", "fresh"]
assert len(WORN_MIX) == N_SLOTS
FIT_MESH = ears["rotten"].data          # the largest ear sets the slot contract


def ear_inside(M, me=None):
    me = me or FIT_MESH
    return sum(1 for v in me.vertices if closest(M @ v.co)[3] < 0)


for i, (e, M, t, tilt) in enumerate(slots):
    # last-mm fit: the ear is 33 mm wide and 19 mm deep and the chest is faceted, so a wing
    # can still clip a neighbouring face. Pitch the slot outward about its own X (the cord)
    # in 2 deg steps until every ear vert is clear; the correction becomes part of the contract.
    if ear_inside(M):
        # smallest pitch (about the cord) + yaw (about the ear's own up) that clears; a wing
        # clipping the collar at the shoulder crease needs yaw, pitch alone stalled at 24 deg
        cands = sorted(((abs(pt) + abs(yw), pt, yw) for pt in range(0, 26, 2) for yw in (0, -6, 6, -12, 12, -18, 18, -24, 24)))
        for _, pt, yw in cands:
            M2 = M @ Matrix.Rotation(math.radians(-pt), 4, 'X') @ Matrix.Rotation(math.radians(yw), 4, 'Z')
            if not ear_inside(M2):
                log("   slot %02d pitched %d deg out, yawed %d deg to clear the chest" % (i + 1, pt, yw))
                M = M2
                break
        e.matrix_world = M
        slots[i] = (e, M, t, tilt)
    inst = D.objects.new("preview_ear_%02d" % (i + 1), ears[WORN_MIX[i]].data)
    SC.collection.objects.link(inst)
    inst.matrix_world = M @ (Matrix.Scale(-1.0, 4, Vector((1, 0, 0))) if i % 2 else Matrix.Identity(4))
    preview.append(inst)
bpy.context.view_layer.update()
worst = 1e9
inside_total = 0
float_worst = 0.0
for inst in preview:
    vin = 0
    dmin = 1e9
    for v in inst.data.vertices:
        w, n, dist, sign = closest(inst.matrix_world @ v.co)
        if sign < 0:
            vin += 1
        dmin = min(dmin, dist if sign >= 0 else -dist)
    # the back face should lie close to the chest: nearest back vert within 12 mm
    back = [inst.matrix_world @ v.co for v in inst.data.vertices if v.co.y > -0.0005]
    gap = min(closest(p)[2] for p in back)
    float_worst = max(float_worst, gap)
    inside_total += vin
    worst = min(worst, dmin)
    if vin:
        log("   %s: %d verts inside, worst %.4f m" % (inst.name, vin, dmin))
log("EAR FIT 15 instances: verts inside body %d, min clearance %.4f m, largest back-face gap to chest %.4f m"
    % (inside_total, worst, float_worst))
assert inside_total == 0, "ears poke through the chest"

# ---------------------------------------------------------------------------
# 6. renders: the library at 1 m in 640x480, and the loaded cord on the dummy
# ---------------------------------------------------------------------------
os.makedirs(RENDERS, exist_ok=True)
SC.render.engine = 'BLENDER_EEVEE'          # 5.0 dropped the _NEXT name
SC.render.image_settings.file_format = 'PNG'
SC.view_settings.view_transform = 'Standard'
SC.view_settings.look = 'None'
wd = D.worlds.new("studio_grey")
wd.use_nodes = True
wd.node_tree.nodes["Background"].inputs[0].default_value = (0.24, 0.24, 0.25, 1.0)
wd.node_tree.nodes["Background"].inputs[1].default_value = 0.45
SC.world = wd


def add_light(name, loc, energy, size, rot):
    ld = D.lights.new(name, 'AREA')
    ld.energy = energy
    ld.size = size
    o = D.objects.new(name, ld)
    SC.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = rot
    return o


cam_data = D.cameras.new("cam")
cam = D.objects.new("cam", cam_data)
SC.collection.objects.link(cam)
SC.camera = cam


def render(path, res, cam_loc, look_at, ortho=None, lights=(), lens=50.0):
    for o in [o for o in D.objects if o.type == 'LIGHT']:
        D.objects.remove(o, do_unlink=True)
    for (loc, en, sz, rot) in lights:
        add_light("L", loc, en, sz, rot)
    cam.location = cam_loc
    d = (Vector(look_at) - Vector(cam_loc))
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    if ortho:
        cam_data.type = 'ORTHO'
        cam_data.ortho_scale = ortho
    else:
        cam_data.type = 'PERSP'
        cam_data.lens = lens
        cam_data.sensor_width = 36.0
    cam_data.clip_start = 0.02
    SC.render.resolution_x, SC.render.resolution_y = res
    SC.render.resolution_percentage = 100
    SC.render.filepath = path
    bpy.ops.render.render(write_still=True)


tmp1 = os.path.join(RENDERS, "_necklace_kit_library.png")
tmp2 = os.path.join(RENDERS, "_necklace_kit_worn.png")
# library: 7 charms at 1 m, 50 mm lens, 640x480 - the "does it read" test, no cheating
for o in D.objects:
    if o.type == 'MESH':
        o.hide_render = True
for nm in LIBRARY:
    charms[nm].hide_render = False
row_c = Vector((1.0 + LIB_PITCH * (len(LIBRARY) - 1) / 2.0, 0.0, 1.42))
LIB_LIGHTS = [(row_c + Vector((-0.6, -0.9, 0.7)), 60, 1.2, (math.radians(50), 0, math.radians(-35))),
              (row_c + Vector((0.7, -0.8, 0.2)), 25, 1.5, (math.radians(75), 0, math.radians(45))),
              (row_c + Vector((0.0, -0.6, -0.8)), 15, 1.5, (math.radians(-90), 0, 0))]
render(tmp1, (640, 480), row_c + Vector((0, -1.0, 0.05)), row_c, lights=LIB_LIGHTS)
tmp0 = os.path.join(RENDERS, "_necklace_kit_detail.png")
render(tmp0, (640, 480), row_c + Vector((0, -0.45, 0.02)), row_c, lights=LIB_LIGHTS)
# worn: body + cord + 15 ears, chest framed, 3/4 from the front
for o in D.objects:
    if o.type == 'MESH':
        o.hide_render = True
for o in [body, cord] + preview:
    o.hide_render = False
c = Vector((0, -0.08, 1.42))
render(tmp2, (640, 640), c + Vector((-0.9, -1.4, 0.35)), c, ortho=0.62,
       lights=[(c + Vector((-1.0, -1.5, 1.0)), 250, 2.0, (math.radians(52), 0, math.radians(-40))),
               (c + Vector((1.2, -1.2, 0.3)), 90, 2.5, (math.radians(78), 0, math.radians(52))),
               (c + Vector((0.3, 1.5, 1.2)), 120, 2.0, (math.radians(-58), 0, math.radians(178)))])
# the ear sheet: five stages in a row, front then cut face, at 1 m (50 mm) and 0.3 m (35 mm)
EAR_SHEET = os.path.join(RENDERS, "necklace_ears_sheet.png")
EAR_WORN = os.path.join(RENDERS, "necklace_ears_worn.png")
for o in D.objects:
    if o.type == 'MESH':
        o.hide_render = True
EAR_PITCH = 0.055
ear_c = Vector((3.0 + EAR_PITCH * 2, 0.0, 1.40))
ear_keep = {}
for i, stg in enumerate(EAR_ORDER):
    o = ears[stg]
    ear_keep[stg] = (o.location.copy(), o.rotation_euler.copy())
    o.location = Vector((3.0 + EAR_PITCH * i, 0.0, 1.43))
    o.hide_render = False
EAR_LIGHTS = [(ear_c + Vector((-0.6, -0.9, 0.7)), 60, 1.2, (math.radians(50), 0, math.radians(-35))),
              (ear_c + Vector((0.7, -0.8, 0.2)), 25, 1.5, (math.radians(75), 0, math.radians(45))),
              (ear_c + Vector((0.0, -0.6, -0.8)), 15, 1.5, (math.radians(-90), 0, 0))]
ear_tmp = [os.path.join(RENDERS, "_ears_%d.png" % k) for k in range(4)]
render(ear_tmp[0], (960, 300), ear_c + Vector((0, -1.0, 0.0)), ear_c, lights=EAR_LIGHTS)
render(ear_tmp[2], (960, 480), ear_c + Vector((0, -0.30, 0.0)), ear_c, lights=EAR_LIGHTS, lens=35.0)
for stg in EAR_ORDER:
    ears[stg].rotation_euler = (0, 0, math.pi)
render(ear_tmp[1], (960, 300), ear_c + Vector((0, -1.0, 0.0)), ear_c, lights=EAR_LIGHTS)
render(ear_tmp[3], (960, 480), ear_c + Vector((0, -0.30, 0.0)), ear_c, lights=EAR_LIGHTS, lens=35.0)
for stg in EAR_ORDER:
    ears[stg].location, ears[stg].rotation_euler = ear_keep[stg]
    ears[stg].hide_render = True
# worn: the mixed string, chest framed square-on and 3/4
for o in [body, cord] + preview:
    o.hide_render = False
worn_tmp = [os.path.join(RENDERS, "_worn_%d.png" % k) for k in range(2)]
c = Vector((0, -0.08, 1.42))
WORN_LIGHTS = [(c + Vector((-1.0, -1.5, 1.0)), 250, 2.0, (math.radians(52), 0, math.radians(-40))),
               (c + Vector((1.2, -1.2, 0.3)), 90, 2.5, (math.radians(78), 0, math.radians(52))),
               (c + Vector((0.3, 1.5, 1.2)), 120, 2.0, (math.radians(-58), 0, math.radians(178)))]
render(worn_tmp[0], (640, 640), c + Vector((0.0, -1.0, 0.05)), c, lights=WORN_LIGHTS)
render(worn_tmp[1], (640, 640), c + Vector((-0.9, -1.4, 0.35)), c, ortho=0.45, lights=WORN_LIGHTS)


# stack panels into contact sheets
def px_of(path):
    im = D.images.load(path)
    a = np.empty(im.size[0] * im.size[1] * 4, dtype=np.float32)
    im.pixels.foreach_get(a)
    a = a.reshape(im.size[1], im.size[0], 4)
    D.images.remove(im)
    return a


panels = [px_of(tmp1), px_of(tmp0), px_of(tmp2)]     # top: 1 m row; middle: 0.45 m; bottom: worn
W = max(p.shape[1] for p in panels)
H = sum(p.shape[0] for p in panels)
out = np.zeros((H, W, 4), dtype=np.float32)
out[..., 3] = 1.0
y = 0
for pnl in reversed(panels):                          # image rows are bottom-up
    out[y:y + pnl.shape[0], 0:pnl.shape[1]] = pnl
    y += pnl.shape[0]
sh = D.images.new("sheet", W, H, alpha=True)
sh.pixels.foreach_set(out.ravel())
sh.filepath_raw = SHEET
sh.file_format = 'PNG'
sh.save()
D.images.remove(sh)
for f in (tmp0, tmp1, tmp2):
    os.remove(f)
log("SHEET %s" % SHEET)


def stack(paths, out_path, side_by_side=False):
    panels = [px_of(p) for p in paths]
    if side_by_side:
        Wt = sum(p.shape[1] for p in panels)
        Ht = max(p.shape[0] for p in panels)
        out = np.zeros((Ht, Wt, 4), dtype=np.float32)
        out[..., 3] = 1.0
        x = 0
        for pnl in panels:
            out[0:pnl.shape[0], x:x + pnl.shape[1]] = pnl
            x += pnl.shape[1]
    else:
        Wt = max(p.shape[1] for p in panels)
        Ht = sum(p.shape[0] for p in panels)
        out = np.zeros((Ht, Wt, 4), dtype=np.float32)
        out[..., 3] = 1.0
        y = 0
        for pnl in reversed(panels):
            out[y:y + pnl.shape[0], 0:pnl.shape[1]] = pnl
            y += pnl.shape[0]
    sh = D.images.new("sheet", Wt, Ht, alpha=True)
    sh.pixels.foreach_set(out.ravel())
    sh.filepath_raw = out_path
    sh.file_format = 'PNG'
    sh.save()
    D.images.remove(sh)
    for p in paths:
        os.remove(p)
    log("SHEET %s" % out_path)


stack(ear_tmp, EAR_SHEET)                       # top: 1 m front, 1 m back, 0.3 m front, 0.3 m back
stack(worn_tmp, EAR_WORN, side_by_side=True)

# ---------------------------------------------------------------------------
# 6b. the slot table, as data: on the cord object (rides along with an append) and as a
#     JSON sidecar in both frames, so the cast dresser and the engine wiring read numbers
#     instead of parsing a GLB
# ---------------------------------------------------------------------------
import json
to_local = neck_b.matrix_local.inverted() @ rig.matrix_world.inverted()
table = {}
for (e, M, t, tilt) in slots:
    Mb = to_local @ M
    table[e.name] = {
        "rest_world": [list(r) for r in M],
        "neck_local": [list(r) for r in Mb],
        "weights": {NECK_BONE: round(1 - 0.35 * front_w(t), 4), SPINE_BONE: round(0.35 * front_w(t), 4)},
    }
cord["necklace_slots"] = json.dumps(table)
with open(os.path.join(CHAR, "necklace_slots.json"), "w") as fh:
    json.dump({"bone": NECK_BONE, "pitch_m": round(PITCH, 4), "cord_length_m": round(L, 4),
               "note": "rest_world = Blender world, rig at origin, T-pose, Z up. neck_local = "
                       "mixamorig:Neck bone space (head origin, rest basis, Y along the bone) - "
                       "the frame an identity BoneAttachment3D presents. Slot -Y(glTF)/-Z(Blender) "
                       "is down for a hanging charm, +Z(glTF)/-Y(Blender) is outward.",
               "slots": table}, fh, indent=1)
log("SLOT TABLE -> necklace_slots.json (%d slots)" % len(table))

# ---------------------------------------------------------------------------
# 7. save the kit
# ---------------------------------------------------------------------------
for o in D.objects:
    if o.type in ('CAMERA', 'LIGHT'):
        D.objects.remove(o, do_unlink=True)
for o in preview:
    o.hide_set(True)
    o.hide_render = True
body.hide_set(False)
os.makedirs(OUT_CHARMS, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND, compress=True)
log("SAVED %s (%.2f MB)" % (OUT_BLEND, os.path.getsize(OUT_BLEND) / 1048576.0))

# ---------------------------------------------------------------------------
# 8. export: cord + slots in Neck-bone-local space (no rig), charms at origin
# ---------------------------------------------------------------------------
cord_x = D.objects.new("necklace_cord_EXPORT", cord_me.copy())
cord_x.data.name = "necklace_cord"
SC.collection.objects.link(cord_x)
for v in cord_x.data.vertices:
    v.co = to_local @ (cord.matrix_world @ v.co)
cord_x.matrix_world = Matrix.Identity(4)
slot_x = []
for (e, M, t, tilt) in slots:
    ex = D.objects.new(e.name + "_EXPORT", None)
    ex.empty_display_size = 0.01
    SC.collection.objects.link(ex)
    ex.matrix_world = to_local @ M
    ex.parent = cord_x
    ex.matrix_parent_inverse = Matrix.Identity(4)
    slot_x.append(ex)
bpy.context.view_layer.update()
# the shipped names must be bare
cord.name = "necklace_cord_STUDIO"
for (e, M, t, tilt) in slots:
    e.name = e.name + "_STUDIO"
cord_x.name = "necklace_cord"
for ex in slot_x:
    ex.name = ex.name.replace("_EXPORT", "")
bb = [Vector(v.co) for v in cord_x.data.vertices]
log("CORD bone-local bbox x[%.4f,%.4f] y[%.4f,%.4f] z[%.4f,%.4f] (Neck head = origin)"
    % (min(v.x for v in bb), max(v.x for v in bb), min(v.y for v in bb), max(v.y for v in bb),
       min(v.z for v in bb), max(v.z for v in bb)))
assert max(v.length for v in bb) < 0.40
bpy.ops.object.select_all(action='DESELECT')
cord_x.select_set(True)
for ex in slot_x:
    ex.select_set(True)
bpy.context.view_layer.objects.active = cord_x
bpy.ops.export_scene.gltf(
    filepath=OUT_CORD, export_format='GLB', use_selection=True, export_apply=True,
    export_yup=True, export_animations=False, export_skins=False, export_morph=False,
    export_materials='EXPORT', export_cameras=False, export_lights=False,
    export_draco_mesh_compression_enable=False, export_extras=True)
log("SAVED %s (%.0f KB)" % (OUT_CORD, os.path.getsize(OUT_CORD) / 1024.0))
D.objects.remove(cord_x, do_unlink=True)
for ex in slot_x:
    D.objects.remove(ex, do_unlink=True)
cord.name = "necklace_cord"
for (e, M, t, tilt) in slots:
    e.name = e.name.replace("_STUDIO", "")

for nm, o in sorted(charms.items()):
    keep = o.location.copy()
    o.location = Vector((0, 0, 0))
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    path = os.path.join(OUT_CHARMS, nm + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=path, export_format='GLB', use_selection=True, export_apply=True,
        export_yup=True, export_animations=False, export_skins=False, export_morph=False,
        export_materials='EXPORT', export_cameras=False, export_lights=False,
        export_draco_mesh_compression_enable=False, export_extras=True)
    o.location = keep
    log("SAVED %s (%.0f KB)" % (path, os.path.getsize(path) / 1024.0))

# ---------------------------------------------------------------------------
# 9. read every GLB back
# ---------------------------------------------------------------------------
def readback(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    empties = [o for o in bpy.data.objects if o.type == 'EMPTY']
    out = []
    for o in meshes:
        t = sum(len(p.vertices) - 2 for p in o.data.polygons)
        bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
        out.append("%s %d tris uv=%s bbox x[%.3f,%.3f] y[%.3f,%.3f] z[%.3f,%.3f]"
                   % (o.name, t, bool(o.data.uv_layers), min(v.x for v in bb), max(v.x for v in bb),
                      min(v.y for v in bb), max(v.y for v in bb), min(v.z for v in bb), max(v.z for v in bb)))
    imgs = [(i.name, i.size[0], i.size[1], len(i.packed_file.data) if i.packed_file else 0)
            for i in bpy.data.images if i.size[0]]
    return out, [e.name for e in empties], imgs


out, empties, imgs = readback(OUT_CORD)
log("READBACK cord: %s | slots %d %s..%s | images %s" % (out, len(empties), min(empties) if empties else None,
                                                        max(empties) if empties else None, imgs))
assert len([e for e in empties if e.startswith("necklace_slot_")]) == N_SLOTS
for nm in sorted(charms):
    out, empties, imgs = readback(os.path.join(OUT_CHARMS, nm + ".glb"))
    log("READBACK %s: %s | images %s" % (nm, out, imgs))
    assert all(b <= 1_000_000 for _, _, _, b in imgs)
log("DONE")
