"""Build the M151A2 MUTT gun jeep v2 from scratch and export it.

    blender -b --factory-startup --python tools/build_m151_v2.py -- [--export] [--render DIR]

FRAME CONTRACT (the v2 fleet pattern, tools/build_a1_skyraider_v2.py):
  nose at Blender +Y  = Godot -Z          +Z up          real metres
  +X is the vehicle's RIGHT               all transforms applied

ORIGIN: the GROUND LINE, on the centreline, at the longitudinal centre of the
bumper-to-bumper envelope. This is NOT the aircraft convention and the reason is
in the consumers:
  * destructible_vehicle.gd:30-31 sets `global_position = (x, terrain.get_height_at(p), z)`
    - the node origin is dropped ONTO the terrain surface. A centred origin would
      bury the jeep to its waist.
  * collision_table.gd:57 gives m151_mutt_gun_jeep `box (1.8, 1.8, 3.5)` with
    `y_offset 0.9` - a box half its own height above the node, i.e. exactly a box
    resting on the ground when the origin is on the ground line.
The axle midpoint lands 0.041 m forward of that origin; both readings are satisfied.

WHEELS are separate nodes `m151_wheel_fl/fr/rl/rr`, mesh centred on the hub, with
identity rotation and scale and a translation to the hub. Their Godot local X is
the spin axis and their local Y is the steer axis. Same idea as A1_Prop.
`M151_Gun` is likewise a node at the traverse pivot so a future mount can yaw it.
Everything else is at full identity.
"""

import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

TAU = math.tau
PROJ = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT_DIR = os.path.join(PROJ, "assets", "us", "vehicles")

# ------------------------------------------------------------ real numbers
# en.wikipedia.org/wiki/M151_jeep : 132.7 in / 64.3 in / 71 in top up,
# 53 in reducible, 85 in wheelbase.  warwheels.net M151A2 data sheet:
# wheel tread 53 in (1.346 m), ground clearance 9.4 in, tyres 7.00x16.
REAL_LENGTH = 3.371
REAL_WIDTH = 1.633
REAL_HEIGHT_TOP_UP = 1.803
REAL_WHEELBASE = 2.159
REAL_TRACK = 1.346
REAL_TYRE_OD = 0.780          # 7.00-16 NDT
REAL_CLEARANCE = 0.239

# ------------------------------------------------------------ design datum
HW = REAL_WIDTH * 0.5          # 0.81650 - body half width, the widest point
SIDE_T = 0.030                 # sheet thickness of the body side slab
HW_IN = HW - SIDE_T

FRONT_EXT = REAL_LENGTH * 0.5  # +1.6855, front bumper face
REAR_EXT = -FRONT_EXT          # -1.6855, rear bumperette / pintle face
BODY_NOSE_Y = 1.590            # grille panel front face
BODY_TAIL_Y = -1.570           # rear panel outer face

FRONT_AXLE_Y = 1.1305          # 0.5550 front overhang
REAR_AXLE_Y = FRONT_AXLE_Y - REAL_WHEELBASE     # -1.0285

TYRE_R = REAL_TYRE_OD * 0.5    # 0.390
TYRE_HW = 0.090                # half of the 7.00 in section
RIM_R = 0.205
RIM_HW = 0.076
HUB_X = REAL_TRACK * 0.5       # 0.673

ROCKER_Z = 0.420               # body underside / floor pan bottom
FLOOR_Z = 0.450                # tub floor top surface
TUB_RIM_Z = 0.830              # the body line - the crisp horizontal top edge
FENDER_TOP_Z = 0.875           # flat-top fender shelf
HOOD_TOP_Z = 0.900
COWL_Y0, COWL_Y1 = 0.600, 0.700
HOOD_HW = 0.420                # half width of the bonnet between the fenders

ARCH_HALF = 0.445              # wheel-arch cutout half length
ARCH_CROWN = 0.800             # arch crown, 20 mm clear of the 0.780 tyre top

WS_HINGE_Y, WS_HINGE_Z = 0.675, 0.875     # fold-flat windscreen hinge line
WS_TOP_Z = 1.575
WS_HW = 0.748
WS_RAKE_DEG = 5.0

GUN_Y = -0.450                 # pedestal centre, on the tub centreline
GUN_PIVOT_Z = 1.560            # traverse ring top = the gun node origin
GUN_COL_R = 0.068              # a 0.055 column rendered as a lamppost

NS_TYRE = 12
NS_LAMP = 10
NS_TUBE = 8

# flattened wheel-arch profile: (t in -1..1 across the opening, 0..1 of the rise)
ARCH_PROFILE = [(-1.00, 0.00), (-0.90, 0.42), (-0.70, 0.76), (-0.42, 0.95),
                (0.00, 1.00), (0.42, 0.95), (0.70, 0.76), (0.90, 0.42), (1.00, 0.00)]

MATS = {
    "od":     (0.243, 0.263, 0.196),   # Vietnam olive drab
    "metal":  (0.105, 0.110, 0.105),
    "rubber": (0.042, 0.042, 0.045),
    "glass":  (0.560, 0.630, 0.640),
    "amber":  (0.860, 0.520, 0.060),
    "red":    (0.620, 0.070, 0.060),
    "canvas": (0.330, 0.305, 0.215),
}
MAT_NAMES = {k: "M151_" + k.capitalize() for k in MATS}
MAT_NAMES["od"] = "M151_OliveDrab"
MAT_NAMES["metal"] = "M151_MetalDark"
MAT_NAMES["amber"] = "M151_LensAmber"
MAT_NAMES["red"] = "M151_LensRed"


# =============================================================== mesh utilities
class Shell:
    def __init__(self):
        self.v = []
        self.f = []
        self.tag = []

    def add_verts(self, pts):
        o = len(self.v)
        self.v.extend([(float(p[0]), float(p[1]), float(p[2])) for p in pts])
        return o

    def face(self, idx, tag):
        self.f.append(tuple(idx))
        self.tag.append(tag)

    def poly(self, pts, tag):
        """Convex polygon, fanned into triangles."""
        o = self.add_verts(pts)
        for i in range(1, len(pts) - 1):
            self.face((o, o + i, o + i + 1), tag)

    def strip(self, A, B, tag):
        """Bridge two equal-length open polylines into quads."""
        oa = self.add_verts(A)
        ob = self.add_verts(B)
        for i in range(len(A) - 1):
            self.face((oa + i, oa + i + 1, ob + i + 1, ob + i), tag)

    def ring_bridge(self, A, B, tag):
        """Bridge two equal-length CLOSED rings."""
        n = len(A)
        oa = self.add_verts(A)
        ob = self.add_verts(B)
        for i in range(n):
            j = (i + 1) % n
            self.face((oa + i, oa + j, ob + j, ob + i), tag)

    # Every face below is wound outward BY HAND and no recalc_face_normals runs
    # on the result. recalc needs a manifold, and welding independent solids at
    # shared corners makes edges 4-sided - it silently flips faces there. Hand
    # winding is deterministic and survives the weld.
    FACES = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4),
             (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]

    def box(self, lo, hi, tag):
        (x0, y0, z0), (x1, y1, z1) = lo, hi
        self.hexa([(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                   (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], tag)

    def hexa(self, corners, tag):
        """8-corner solid: 0-3 the bottom ring CCW seen from +Z, 4-7 the top."""
        o = self.add_verts(corners)
        for f in Shell.FACES:
            self.face([i + o for i in f], tag)

    def mirrored(self):
        """A copy across x=0 with every face reversed, so the left-hand panel is
        wound outward too. Building the left side by negating a sign leaves every
        face on it pointing INTO the body."""
        m = Shell()
        m.v = [(-p[0], p[1], p[2]) for p in self.v]
        m.f = [tuple(reversed(f)) for f in self.f]
        m.tag = list(self.tag)
        return m

    def merge(self, other):
        o = len(self.v)
        self.v.extend(other.v)
        for f, t in zip(other.f, other.tag):
            self.face([i + o for i in f], t)


def _basis(a):
    ref = Vector((0.0, 0.0, 1.0)) if abs(a.z) < 0.9 else Vector((1.0, 0.0, 0.0))
    u = a.cross(ref).normalized()
    return u, a.cross(u).normalized()


def cyl(shell, p0, p1, r, n, side_tag, cap0_tag=None, cap1_tag=None):
    """Closed n-sided cylinder from p0 to p1. Caps default to the side tag."""
    p0, p1 = Vector(p0), Vector(p1)
    a = (p1 - p0).normalized()
    u, v = _basis(a)
    A = [tuple(p0 + (u * math.cos(TAU * i / n) + v * math.sin(TAU * i / n)) * r) for i in range(n)]
    B = [tuple(p1 + (u * math.cos(TAU * i / n) + v * math.sin(TAU * i / n)) * r) for i in range(n)]
    shell.ring_bridge(A, B, side_tag)
    shell.poly(list(reversed(A)), cap0_tag or side_tag)
    shell.poly(B, cap1_tag or side_tag)


def tyre(shell, n=NS_TYRE):
    """A road wheel centred on its own origin, spin axis = X."""
    def ring(x, r):
        return [(x, r * math.cos(TAU * i / n), r * math.sin(TAU * i / n)) for i in range(n)]
    out_p, out_m = ring(+TYRE_HW, TYRE_R), ring(-TYRE_HW, TYRE_R)
    rim_p, rim_m = ring(+RIM_HW, RIM_R), ring(-RIM_HW, RIM_R)
    shell.ring_bridge(out_m, out_p, "rubber")          # tread band
    shell.ring_bridge(out_p, rim_p, "rubber")          # outboard sidewall
    shell.ring_bridge(rim_m, out_m, "rubber")          # inboard sidewall
    shell.poly(rim_p, "metal")                         # outboard rim face
    shell.poly(list(reversed(rim_m)), "metal")


# ------------------------------------------------------------ body profiles
def side_top(y):
    if y <= COWL_Y0:
        return TUB_RIM_Z
    if y >= COWL_Y1:
        return FENDER_TOP_Z
    t = (y - COWL_Y0) / (COWL_Y1 - COWL_Y0)
    return TUB_RIM_Z + (FENDER_TOP_Z - TUB_RIM_Z) * t


def side_bot(y):
    z = ROCKER_Z
    for axle in (FRONT_AXLE_Y, REAR_AXLE_Y):
        t = (y - axle) / ARCH_HALF
        if -1.0 <= t <= 1.0:
            f = 0.0
            for i in range(len(ARCH_PROFILE) - 1):
                t0, f0 = ARCH_PROFILE[i]
                t1, f1 = ARCH_PROFILE[i + 1]
                if t0 <= t <= t1:
                    k = (t - t0) / (t1 - t0) if t1 > t0 else 0.0
                    f = f0 + (f1 - f0) * k
                    break
            z = max(z, ROCKER_Z + (ARCH_CROWN - ROCKER_Z) * f)
    return z


def side_stations():
    ys = {BODY_TAIL_Y, BODY_NOSE_Y, COWL_Y0, COWL_Y1}
    for axle in (FRONT_AXLE_Y, REAR_AXLE_Y):
        for t, _ in ARCH_PROFILE:
            ys.add(round(axle + t * ARCH_HALF, 6))
    return sorted(y for y in ys if BODY_TAIL_Y <= y <= BODY_NOSE_Y)


def body_side(shell):
    """The one-piece RIGHT body side: a 30 mm slab whose TOP face is the tub rim
    and the flat-top fender, and whose BOTTOM face is the rocker with the two
    wheel arches cut into it. This single panel IS the M151's identity. The left
    side is Shell.mirrored() of it, never a re-run with a negative sign."""
    xo, xi = HW, HW_IN
    ys = side_stations()
    OT = [(xo, y, side_top(y)) for y in ys]
    OB = [(xo, y, side_bot(y)) for y in ys]
    IT = [(xi, y, side_top(y)) for y in ys]
    IB = [(xi, y, side_bot(y)) for y in ys]
    shell.strip(OB, OT, "od")        # outer skin
    shell.strip(IT, IB, "od")        # inner skin
    shell.strip(OT, IT, "od")        # top rim / fender crown
    shell.strip(IB, OB, "od")        # rocker + arch lip
    shell.poly([OB[0], OT[0], IT[0], IB[0]], "od")
    shell.poly([IB[-1], IT[-1], OT[-1], OB[-1]], "od")


# ====================================================================== build
def build_body():
    s = Shell()
    right = Shell()
    body_side(right)
    s.merge(right)
    s.merge(right.mirrored())

    # floor pan / underbody, one slab closing the whole hull bottom
    s.box((-HW_IN, BODY_TAIL_Y + SIDE_T, ROCKER_Z), (HW_IN, BODY_NOSE_Y - SIDE_T, FLOOR_Z), "od")
    # rear panel, cowl bulkhead, dash
    s.box((-HW_IN, BODY_TAIL_Y, ROCKER_Z), (HW_IN, BODY_TAIL_Y + SIDE_T, TUB_RIM_Z), "od")
    s.box((-HW_IN, COWL_Y0, FLOOR_Z), (HW_IN, COWL_Y0 + 0.040, FENDER_TOP_Z), "od")
    s.box((-0.620, COWL_Y1 - 0.060, 0.650), (0.620, COWL_Y1 + 0.030, FENDER_TOP_Z), "od")

    # bonnet: flat, creased proud of the fenders, drooping slightly to the grille
    s.hexa([(-HOOD_HW, COWL_Y1 - 0.060, HOOD_TOP_Z - 0.030),
            (HOOD_HW, COWL_Y1 - 0.060, HOOD_TOP_Z - 0.030),
            (HOOD_HW, BODY_NOSE_Y - 0.030, HOOD_TOP_Z - 0.048),
            (-HOOD_HW, BODY_NOSE_Y - 0.030, HOOD_TOP_Z - 0.048),
            (-HOOD_HW, COWL_Y1 - 0.060, HOOD_TOP_Z),
            (HOOD_HW, COWL_Y1 - 0.060, HOOD_TOP_Z),
            (HOOD_HW, BODY_NOSE_Y - 0.030, HOOD_TOP_Z - 0.018),
            (-HOOD_HW, BODY_NOSE_Y - 0.030, HOOD_TOP_Z - 0.018)], "od")

    for sgn in (+1.0, -1.0):
        lo_x, hi_x = sorted((sgn * HOOD_HW, sgn * HW_IN))
        # flat-top fender shelf, hood side to body side, one continuous crown
        s.box((lo_x, COWL_Y1 - 0.060, FENDER_TOP_Z - 0.030),
              (hi_x, BODY_NOSE_Y - 0.030, FENDER_TOP_Z), "od")
        # inner fender / engine bay wall - without it you see straight through
        # the front wheel arch and out the other side
        s.box((sgn * HOOD_HW - 0.015, COWL_Y1 - 0.060, FLOOR_Z),
              (sgn * HOOD_HW + 0.015, BODY_NOSE_Y - 0.030, FENDER_TOP_Z - 0.030), "od")
        # rear wheel-arch hump inside the tub, closing the arch cutout
        s.box((min(sgn * 0.545, sgn * HW_IN), REAR_AXLE_Y - 0.420, FLOOR_Z),
              (max(sgn * 0.545, sgn * HW_IN), REAR_AXLE_Y + 0.420, 0.815), "od")

    # ---- the front: horizontal-slat grille, headlights IN the panel ----------
    s.box((-HW, BODY_NOSE_Y - 0.030, ROCKER_Z), (HW, BODY_NOSE_Y, FENDER_TOP_Z), "od")
    s.box((-0.330, BODY_NOSE_Y - 0.004, 0.495), (0.330, BODY_NOSE_Y + 0.002, 0.828), "metal")
    for i in range(5):                       # HORIZONTAL slats - not a Willys 7-slot
        z0 = 0.505 + i * 0.065
        s.box((-0.330, BODY_NOSE_Y, z0), (0.330, BODY_NOSE_Y + 0.016, z0 + 0.035), "od")
    for sgn in (+1.0, -1.0):
        c = (sgn * 0.600, BODY_NOSE_Y, 0.680)
        cyl(s, c, (c[0], BODY_NOSE_Y + 0.040, c[2]), 0.095, NS_LAMP, "metal", "metal", "amber")
        # M151A2 tell: big combination turn / blackout lamps ON the fender tops
        f = (sgn * 0.655, 1.330, FENDER_TOP_Z - 0.010)
        cyl(s, f, (f[0], f[1], FENDER_TOP_Z + 0.072), 0.052, NS_TUBE, "metal", "metal", "amber")

    s.box((-HW, BODY_NOSE_Y, 0.440), (HW, FRONT_EXT, 0.545), "od")          # front bumper
    for sgn in (+1.0, -1.0):                                                # tow eyes: BOXES
        s.box((sgn * 0.300 - 0.050, BODY_NOSE_Y + 0.020, 0.362),
              (sgn * 0.300 + 0.050, FRONT_EXT, 0.445), "metal")

    # ---- the tail ------------------------------------------------------------
    for sgn in (+1.0, -1.0):
        c = (sgn * 0.620, BODY_TAIL_Y, 0.720)
        cyl(s, c, (c[0], BODY_TAIL_Y - 0.038, c[2]), 0.055, NS_TUBE, "metal", "metal", "red")
        s.box((sgn * 0.600 - 0.100, REAR_EXT, 0.440),
              (sgn * 0.600 + 0.100, BODY_TAIL_Y, 0.545), "od")
    s.box((-0.048, REAR_EXT, 0.470), (0.048, BODY_TAIL_Y, 0.560), "metal")   # pintle

    # ---- crew station --------------------------------------------------------
    for cx in (-0.350, 0.350):
        s.box((cx - 0.185, 0.140, FLOOR_Z), (cx + 0.185, 0.500, 0.565), "canvas")
        s.box((cx - 0.185, 0.072, 0.565), (cx + 0.185, 0.148, 0.945), "canvas")
    col0 = Vector((-0.350, 0.648, 0.700))
    col1 = Vector((-0.350, 0.398, 0.930))
    cyl(s, col0, col1, 0.020, 6, "metal")
    axis = (col1 - col0).normalized()
    ctr = col1 + axis * 0.022
    u, v = _basis(axis)
    RW, TW, NSEG = 0.165, 0.018, 10
    prev = None
    first = None
    for i in range(NSEG + 1):
        th = TAU * i / NSEG
        c = ctr + (u * math.cos(th) + v * math.sin(th)) * RW
        w = (u * math.cos(th) + v * math.sin(th))
        quad = [tuple(c + w * TW + axis * TW), tuple(c - w * TW + axis * TW),
                tuple(c - w * TW - axis * TW), tuple(c + w * TW - axis * TW)]
        if prev is not None:
            s.ring_bridge(prev, quad, "metal")
        else:
            first = quad
        prev = quad
    for i in range(3):                              # three spokes, thin boxes
        th = TAU * i / 3 + 0.4
        w = (u * math.cos(th) + v * math.sin(th))
        a, b = ctr, ctr + w * RW
        cyl(s, tuple(a), tuple(b), 0.013, 4, "metal")
    return s


def build_windscreen():
    """Full-width fold-flat frame with glass filling it edge to edge - the
    review's Defect 3 was a 0.60 m pane inside a 1.30 m frame."""
    s = Shell()
    s.box((-WS_HW, -0.020, WS_HINGE_Z), (WS_HW, 0.020, WS_HINGE_Z + 0.060), "od")
    s.box((-WS_HW, -0.020, WS_TOP_Z - 0.060), (WS_HW, 0.020, WS_TOP_Z), "od")
    for sgn in (+1.0, -1.0):
        s.box((sgn * WS_HW - 0.056, -0.020, WS_HINGE_Z), (sgn * WS_HW, 0.020, WS_TOP_Z), "od")
    s.box((-(WS_HW - 0.056), -0.007, WS_HINGE_Z + 0.060),
          (WS_HW - 0.056, 0.007, WS_TOP_Z - 0.060), "glass")
    # Left-hand mirror off the A-post. Its outer face is held flush with the body
    # side (x = -HW): a mirror hung 6 cm proud put the model 3.8% over the
    # published 1.633 m width, which is how the shipped jeep measured 1.740.
    s.box((-0.790, -0.014, 1.290), (-WS_HW, 0.014, 1.318), "metal")
    s.box((-HW, -0.020, 1.256), (-0.752, 0.020, 1.352), "metal")
    # rake it back about the hinge, then bake the rotation into the vertices so
    # the exported node stays at identity
    R = Matrix.Rotation(math.radians(-WS_RAKE_DEG), 3, "X")
    piv = Vector((0.0, 0.0, WS_HINGE_Z))
    s.v = [tuple(R @ (Vector(p) - piv) + piv + Vector((0.0, WS_HINGE_Y, 0.0))) for p in s.v]
    return s


def build_gun_mount():
    s = Shell()
    s.box((-0.190, GUN_Y - 0.190, FLOOR_Z), (0.190, GUN_Y + 0.190, FLOOR_Z + 0.030), "metal")
    cyl(s, (0.0, GUN_Y, FLOOR_Z + 0.030), (0.0, GUN_Y, GUN_PIVOT_Z - 0.050),
        GUN_COL_R, NS_TUBE, "metal")
    cyl(s, (0.0, GUN_Y, GUN_PIVOT_Z - 0.050), (0.0, GUN_Y, GUN_PIVOT_Z),
        0.112, NS_TUBE, "metal")
    for sgn in (+1.0, -1.0):                       # two braces off the base plate
        cyl(s, (sgn * 0.165, GUN_Y, FLOOR_Z + 0.030), (sgn * 0.040, GUN_Y, 1.060),
            0.022, 4, "metal")
    return s


def build_gun():
    """M60 on the pedestal. Local origin = the traverse pivot; +Y is the bore."""
    s = Shell()
    s.box((-0.070, -0.055, 0.000), (0.070, 0.055, 0.058), "metal")        # cradle
    s.box((-0.038, -0.280, 0.058), (0.038, 0.160, 0.148), "metal")        # receiver
    s.box((-0.040, -0.020, 0.148), (0.040, 0.160, 0.178), "metal")        # feed cover
    s.box((-0.032, -0.450, 0.078), (0.032, -0.280, 0.138), "od")          # buttstock
    s.box((-0.022, -0.278, 0.000), (0.022, -0.218, 0.058), "od")          # pistol grip
    cyl(s, (0.0, 0.160, 0.103), (0.0, 0.590, 0.103), 0.017, NS_TUBE, "metal")
    cyl(s, (0.0, 0.160, 0.103), (0.0, 0.345, 0.103), 0.027, NS_TUBE, "metal")   # gas cyl
    cyl(s, (0.0, 0.590, 0.103), (0.0, 0.650, 0.103), 0.026, NS_TUBE, "metal")   # flash hider
    s.box((-0.020, 0.100, 0.178), (0.020, 0.200, 0.205), "metal")         # carry handle
    s.box((-0.015, -0.070, 0.178), (0.015, -0.026, 0.205), "metal")       # rear sight
    s.box((-0.135, -0.090, 0.010), (-0.045, 0.090, 0.120), "od")          # ammo can, left feed
    return s


def build_col_tub():
    s = Shell()
    s.box((-HW, REAR_EXT, 0.0), (HW, FRONT_EXT, FENDER_TOP_Z), "metal")
    return s


def build_col_upper():
    s = Shell()
    s.box((-WS_HW, GUN_Y - 0.230, FENDER_TOP_Z), (WS_HW, WS_HINGE_Y + 0.120, 1.790), "metal")
    return s


# ============================================================ scene assembly
def material(tag):
    name = MAT_NAMES[tag]
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    r, g, bl = MATS[tag]
    b.inputs["Base Color"].default_value = (r, g, bl, 1.0)
    b.inputs["Metallic"].default_value = 0.0
    b.inputs["Roughness"].default_value = 0.62 if tag != "glass" else 0.18
    return m


def make_object(name, shell, location=(0.0, 0.0, 0.0)):
    me = bpy.data.meshes.new(name)
    me.from_pydata(shell.v, [], shell.f)
    me.update()
    tags = sorted(set(shell.tag))
    for t in tags:
        me.materials.append(material(t))
    idx = {t: i for i, t in enumerate(tags)}
    for p, t in zip(me.polygons, shell.tag):
        p.material_index = idx[t]
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    ob.location = location
    # Weld and drop degenerate faces. NO recalc_face_normals - see Shell.FACES.
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bad = [f for f in bm.faces if f.calc_area() < 1e-9]
    if bad:
        bmesh.ops.delete(bm, geom=bad, context="FACES")
    bm.to_mesh(me)
    bm.free()
    me.update()
    return ob


def empty(name, loc, parent=None):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.08
    bpy.context.collection.objects.link(e)
    e.location = loc
    if parent is not None:
        e.parent = parent
        e.matrix_parent_inverse = parent.matrix_world.inverted()
    return e


def bounds(objs):
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    for ob in objs:
        for v in ob.data.vertices:
            w = ob.matrix_world @ v.co
            lo = Vector((min(lo[i], w[i]) for i in range(3)))
            hi = Vector((max(hi[i], w[i]) for i in range(3)))
    return lo, hi


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    do_export = "--export" in argv
    render_dir = argv[argv.index("--render") + 1] if "--render" in argv else None

    bpy.ops.wm.read_factory_settings(use_empty=True)

    body = make_object("M151_Body", build_body())
    wscr = make_object("M151_Windscreen", build_windscreen())
    mount = make_object("M151_GunMount", build_gun_mount())
    gun = make_object("M151_Gun", build_gun(), (0.0, GUN_Y, GUN_PIVOT_Z))
    spare = make_object("M151_SpareTyre", build_spare())
    wheels = []
    for tag, sx, sy in (("fl", -1.0, 1.0), ("fr", 1.0, 1.0), ("rl", -1.0, -1.0), ("rr", 1.0, -1.0)):
        w = Shell()
        tyre(w)
        wheels.append(make_object("m151_wheel_" + tag, w,
                                  (sx * HUB_X, FRONT_AXLE_Y if sy > 0 else REAR_AXLE_Y, TYRE_R)))
    cols = [make_object("M151_Col_Tub-colonly", build_col_tub()),
            make_object("M151_Col_Upper-colonly", build_col_upper())]

    empty("seat_driver", (-0.350, 0.320, 0.565))
    empty("seat_passenger", (0.350, 0.320, 0.565))
    empty("seat_gunner", (0.0, -0.030, FLOOR_Z))
    empty("MuzzlePoint", (0.0, 0.650, 0.103), gun)

    visible = [body, wscr, mount, gun, spare] + wheels
    # matrix_world is STALE until the depsgraph runs. Without this the wheels
    # measure as if they were at the origin and the ground line reads -0.390.
    bpy.context.view_layer.update()

    # ---- measure ------------------------------------------------------------
    tris = 0
    print("\n--- MESH INVENTORY -------------------------------------------")
    for ob in visible + cols:
        ob.data.calc_loop_triangles()
        t = len(ob.data.loop_triangles)
        ngons = sum(1 for p in ob.data.polygons if len(p.vertices) > 4)
        used = set()
        for p in ob.data.polygons:
            used.update(p.vertices)
        loose = len(ob.data.vertices) - len(used)
        if not ob.name.endswith("-colonly"):
            tris += t
        print("  %-26s tris %5d verts %5d ngons %d loose %d loc %s"
              % (ob.name, t, len(ob.data.vertices), ngons, loose,
                 tuple(round(c, 4) for c in ob.location)))

    lo, hi = bounds(visible)
    blo, bhi = bounds([body])
    length, width, height = hi.y - lo.y, hi.x - lo.x, hi.z - lo.z
    axle_mid = (FRONT_AXLE_Y + REAR_AXLE_Y) * 0.5
    print("\n--- MEASURED vs REAL (object space, metres) ------------------")
    for lab, got, real in (("length ", length, REAL_LENGTH),
                           ("width  ", width, REAL_WIDTH),
                           ("height ", height, REAL_HEIGHT_TOP_UP),
                           ("wheelbase", FRONT_AXLE_Y - REAR_AXLE_Y, REAL_WHEELBASE),
                           ("track  ", 2 * HUB_X, REAL_TRACK),
                           ("tyre OD", 2 * TYRE_R, REAL_TYRE_OD)):
        print("  %-9s %7.3f  real %6.3f  d %+0.3f  (%+0.1f%%)"
              % (lab, got, real, got - real, 100.0 * (got - real) / real))
    print("  bbox lo %s hi %s" % (tuple(round(c, 3) for c in lo), tuple(round(c, 3) for c in hi)))
    print("  ORIGIN = ground line (z 0 = tyre contact), centreline, longitudinal centre")
    print("  ground line at z %+0.4f   axle midpoint at y %+0.4f" % (lo.z, axle_mid))
    print("  body-only bbox z %+0.3f..%+0.3f   windscreen top %+0.3f"
          % (blo.z, bhi.z, WS_TOP_Z))
    print("  TOTAL VISIBLE TRIS %d   collider tris %d"
          % (tris, sum(len(c.data.loop_triangles) for c in cols)))

    # ---- QC. A build that "ran without error" proves nothing. ---------------
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
        dbl = len(bmesh.ops.find_doubles(bm, verts=bm.verts, dist=1e-5)["targetmap"])
        zero = sum(1 for f in bm.faces if f.calc_area() < 1e-8)
        nonman = sum(1 for e in bm.edges if not e.is_manifold)
        bm.free()
        print("  %-26s ngons %d loose %d doubles %d zero-area %d non-manifold-edges %d"
              % (ob.name, ng, loose, dbl, zero, nonman))
        if ng or loose or dbl or zero:
            bad.append(ob.name)
    assert not bad, "QC FAILED on %s" % bad

    # the defect the whole fleet has: a donut where a box belongs
    for ob in visible:
        assert len(ob.data.loop_triangles) != 1152, "%s is a default torus" % ob.name
    assert bhi.y > 1.6 and blo.y < -1.6, "body does not span the full length"
    assert abs(lo.z) < 1e-6, "the tyres must touch z=0: ground line is %+0.4f" % lo.z
    assert abs(lo.x + hi.x) < 1e-6, "not laterally symmetric (%.5f)" % (lo.x + hi.x)
    # every polygon must face away from the solid it bounds; a hand-wound cap
    # that got inverted shows up as a face whose normal points back at the hull
    inward = 0
    for ob in visible:
        c = sum(((ob.matrix_world @ v.co) for v in ob.data.vertices),
                Vector()) / len(ob.data.vertices)
        for p in ob.data.polygons:
            n = ob.matrix_world.to_3x3() @ p.normal
            if n.dot((ob.matrix_world @ p.center) - c) < -1e-6:
                inward += 1
    print("  faces whose normal points back at their own hull: %d "
          "(nonzero is expected where solids interpenetrate)" % inward)
    for ob in visible + cols:
        assert all(abs(c - 1.0) < 1e-6 for c in ob.scale), "%s has unapplied scale" % ob.name
        assert all(abs(c) < 1e-6 for c in ob.rotation_euler), "%s carries rotation" % ob.name
    for ob in [body, wscr, mount, spare] + cols:
        assert ob.location.length < 1e-6, "%s must be at identity, is at %s" % (ob.name, ob.location)
    for w, tag in zip(wheels, ("fl", "fr", "rl", "rr")):
        want_x = (-1.0 if tag[1] == "l" else 1.0) * HUB_X
        want_y = FRONT_AXLE_Y if tag[0] == "f" else REAR_AXLE_Y
        assert abs(w.location.x - want_x) < 1e-6 and abs(w.location.y - want_y) < 1e-6, \
            "%s hub is at %s" % (w.name, w.location)
    print("  materials: %d -> %s" % (len(bpy.data.materials),
                                     sorted(m.name for m in bpy.data.materials)))
    for m in bpy.data.materials:
        assert m.node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value == 0.0
    assert not [i for i in bpy.data.images if i.name != "Render Result"], "textures leaked in"
    print("  QC PASS")

    if render_dir:
        # The -colonly boxes are opaque geometry. Left visible they wrap the
        # whole jeep and the render shows two grey slabs and nothing else.
        for c in cols:
            c.hide_render = True
        do_render(render_dir, lo, hi)
        for c in cols:
            c.hide_render = False

    if do_export:
        for ob in list(bpy.data.objects):
            if ob.type in {"CAMERA", "LIGHT"} or ob.name.startswith("_datum"):
                bpy.data.objects.remove(ob, do_unlink=True)
        blend = os.path.join(OUT_DIR, "m151_mutt_gun_jeep_v2.blend")
        glb = os.path.join(OUT_DIR, "m151_mutt_gun_jeep_v2.glb")
        bpy.context.preferences.filepaths.save_version = 0     # project law: no .blend1
        bpy.ops.wm.save_as_mainfile(filepath=blend, compress=False, check_existing=False)
        bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB",
                                  use_selection=False, export_apply=True,
                                  export_yup=True, export_materials="EXPORT",
                                  export_normals=True, export_animations=False,
                                  export_cameras=False, export_lights=False,
                                  export_extras=False)
        print("EXPORTED %s" % glb)
        print("SAVED    %s" % blend)


def build_spare():
    """Spare wheel, stood UPRIGHT INSIDE THE BODY ON THE LEFT, immediately behind
    the driver, breaking the body line by ~0.40 m. That is where the walkaround
    reference carries it - not on the tail, which is where the commission brief
    assumed. Kept inboard of the tub wall so it cannot blow the 1.633 m width;
    the shipped jeep measured 1.740 because its spare hung outside the body."""
    s = Shell()
    tyre(s)
    off = Vector((-0.645, -0.150, 0.845))
    s.v = [tuple(Vector(p) + off) for p in s.v]
    s.box((-0.787, -0.190, 0.900), (-0.700, -0.110, 0.960), "metal")   # mount bracket
    return s


# ====================================================================== renders
# azimuth 0 = camera on +X (the vehicle's right), 90 = ahead of the nose (+Y).
VIEWS = [("side", 180.0, 4.0), ("front", 90.0, 6.0),
         ("threequarter", 42.0, 16.0), ("rear_quarter", 236.0, 14.0)]

DATUM_H = 1.7132     # ModelActor.TARGET_HEIGHT_M, GAME_SCALE_STANDARD.md:8


def _flat(name, col):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (col[0], col[1], col[2], 1.0)
    b.inputs["Metallic"].default_value = 0.0
    return m


def _prim(name, lo, hi, mat):
    s = Shell()
    s.box(lo, hi, "od")
    me = bpy.data.meshes.new(name)
    me.from_pydata(s.v, [], s.f)
    me.update()
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob


def add_datum():
    """A 1.7132 m grunt block beside the jeep, plus the ratified-forward markers:
    a GREEN slab at +Y and a RED slab at -Y (the review's render convention)."""
    skin = _flat("_datum_skin", (0.62, 0.47, 0.36))
    cloth = _flat("_datum_cloth", (0.28, 0.31, 0.22))
    # The grunt must stand on the SAME side as the datum camera. At x -1.42 he
    # was behind the jeep and all that reached the frame was the top of his head.
    x = 1.55
    parts = [("_datum_legs", (x - 0.17, -0.13, 0.00), (x + 0.17, 0.13, 0.86), cloth),
             ("_datum_torso", (x - 0.21, -0.15, 0.86), (x + 0.21, 0.15, 1.44), cloth),
             ("_datum_head", (x - 0.10, -0.10, 1.50), (x + 0.10, 0.10, DATUM_H), skin),
             ("_datum_neck", (x - 0.06, -0.06, 1.44), (x + 0.06, 0.06, 1.50), skin)]
    for n, lo, hi, m in parts:
        _prim(n, lo, hi, m)
    _prim("_datum_fwd", (-0.34, 2.10, 0.0), (0.34, 2.34, 0.10), _flat("_datum_green", (0.10, 0.62, 0.14)))
    _prim("_datum_aft", (-0.34, -2.34, 0.0), (0.34, -2.10, 0.10), _flat("_datum_red", (0.68, 0.09, 0.08)))
    _prim("_datum_ground", (-3.2, -3.4, -0.012), (3.2, 3.4, 0.0), _flat("_datum_dirt", (0.31, 0.28, 0.21)))


def do_render(out_dir, lo, hi):
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 28
    sc.cycles.use_denoising = True
    sc.cycles.device = "CPU"
    sc.render.resolution_x, sc.render.resolution_y = 1000, 640
    sc.view_settings.view_transform = "Standard"

    w = bpy.data.worlds.new("W")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.50, 0.60, 1.0)
    w.node_tree.nodes["Background"].inputs[1].default_value = 1.10
    sc.world = w

    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.2
    sun.data.angle = math.radians(7.0)
    sun.rotation_euler = (math.radians(52.0), 0.0, math.radians(38.0))
    bpy.context.collection.objects.link(sun)

    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 52.0
    bpy.context.collection.objects.link(cam)
    sc.camera = cam

    tgt = (lo + hi) * 0.5
    span = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z)
    for name, az, el in VIEWS:
        a, e = math.radians(az), math.radians(el)
        cam.location = tgt + Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a),
                                     math.sin(e))) * (span * 2.35)
        cam.rotation_euler = (tgt - Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(out_dir, "m151v2_%s.png" % name)
        bpy.ops.render.render(write_still=True)
        print("RENDER %s" % sc.render.filepath)

    add_datum()
    tgt = Vector((0.35, 0.0, 0.86))
    a, e = math.radians(34.0), math.radians(9.0)
    cam.location = tgt + Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a),
                                 math.sin(e))) * 9.2
    cam.rotation_euler = (tgt - Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(out_dir, "m151v2_datum.png")
    bpy.ops.render.render(write_still=True)
    print("RENDER %s" % sc.render.filepath)


main()
