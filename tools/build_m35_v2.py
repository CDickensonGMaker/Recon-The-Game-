"""Build the M35A2 "deuce and a half" cargo truck v2 from scratch and export it.

    blender -b --factory-startup --python tools/build_m35_v2.py -- [--export] [--render DIR]

FRAME CONTRACT (the v2 fleet pattern, tools/build_m151_v2.py / build_a1_skyraider_v2.py):
  nose at Blender +Y  = Godot -Z          +Z up          real metres
  +X is the vehicle's RIGHT               all transforms applied

ORIGIN: the GROUND LINE, on the centreline, at the longitudinal centre of the
bumper-to-tailgate envelope. Same reasoning the M151 v2 recorded, same consumers:
  * destructible_vehicle.gd:30-31 sets `global_position = (x, terrain.get_height_at(p), z)`
    - the node origin is dropped ONTO the terrain surface. A centred origin would
      bury the truck to its bed floor.
  * collision_table.gd:154 gives m35_deuce_truck `y_offset 1.60` - half of a 3.2 m
    box, i.e. exactly a box resting on a ground-line origin. (Its `box.y` reads 3.3,
    which is the 5 cm the authored table is out with itself; see the notes.)

WHEELS are six separate nodes. The two front wheels are single tyres; the four
rear nodes are DUAL PAIRS, because on a real deuce a dual pair is bolted to one
hub and turns as one body - one node per hub is the physically correct split and
it is also the cheap one. Mesh centred on the hub, identity rotation and scale,
translation to the hub: Godot local X is the spin axis, local Y the steer axis.
Everything else is at full identity.

THE TARP IS ONE SKIN AND THE BOWS ARE NOT MODELLED. The shipped truck put its
BowRails 7 cm ABOVE Canvas_Top, so it wore a metal cage over its own cover. On a
real deuce the bows are inside and invisible under a fitted tarp, so the only
honest low-poly answer is to build the arc the bows make and nothing else. There
is no geometry above the tarp for a future edit to get wrong.
"""

import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

TAU = math.tau
PROJ = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT_DIR = os.path.join(PROJ, "assets", "us", "vehicles")

# ------------------------------------------------------------ real numbers
# en.wikipedia.org/wiki/M35_series_2%C2%BD-ton_6%C3%976_cargo_truck :
#   274-3/4 in (6.98 m) long no winch, 96 in (2.44 m) wide, 111-112 in (2.82 m)
#   to the cab roof, cargo bed 8 ft x 12 ft, 9.00x20 tyres, dual-wheel tandem.
# truck-encyclopedia.com/coldwar/us/M35-truck.php : 274-3/4 / 93 / 111 in, and
#   "the bonnet LACKED LOUVRES", "the radiator grille was meshed with separated
#   bars", open cab with solid metal doors and a CANVAS roof, folding windscreen.
# generalequipment.info/M35A2.htm : bed height from ground 50 in (1.27 m),
#   9.00x20 8-ply, ground clearance 12-1/2 in under axle.
# WHEELBASE AND BOGIE ARE MEASURED, NOT QUOTED - no source I could reach
# publishes them and the two that mention a wheelbase disagree (142 vs 154 in).
# Measured off the walkaround (Pit Stop For Patriots M35A2, see the notes) using
# the 9.00x20 tyre OD as the scale datum: rear axle centres are 1.076 tyre-OD
# apart -> 1.134 m, i.e. the 44 in tandem; and the bed runs 1.39 tyre-OD aft of
# the last axle -> 1.47 m, which is only consistent with the 154 in wheelbase.
REAL_LENGTH = 6.98
REAL_WIDTH = 2.438              # 96 in / the 8 ft bed, which IS the widest point
REAL_HEIGHT_CAB = 2.82          # 111 in to the cab roof
REAL_HEIGHT_TARP = 3.00         # bows + fitted cargo cover
REAL_WHEELBASE = 3.912          # 154 in, front axle -> centre of the rear bogie
REAL_BOGIE = 1.118              # 44 in, tandem axle spacing
REAL_TYRE_OD = 1.054            # 9.00-20 NDT
REAL_TRACK_F = 1.645            # 64.75 in
REAL_BED_L = 3.658              # 12 ft
REAL_BED_W = 2.438              # 8 ft
REAL_BED_FLOOR_Z = 1.27         # 50 in

# ------------------------------------------------------------ design datum
HW = REAL_WIDTH * 0.5           # 1.219 - the BED half width, the widest point
CAB_HW = 1.100                  # cab and front fenders: 90% of the bed. The
                                # shipped truck's cab was 1.05 m WIDE against a
                                # 2.10 m bed - half. That is the whole defect.
FRONT_EXT = REAL_LENGTH * 0.5   # +3.490, bumper front face
REAR_EXT = -FRONT_EXT           # -3.490, tailgate outer face

BUMPER_Y0, BUMPER_Y1 = 3.390, 3.490
FRONT_PANEL_Y = 3.300           # radiator surround / grille plane
HOOD_Y0, HOOD_Y1 = 1.480, 3.300 # 1.82 m bonnet
CAB_Y0, CAB_Y1 = 0.400, 1.480
BED_Y1 = 0.228                  # bed floor front edge
BED_Y0 = BED_Y1 - REAL_BED_L    # -3.430
BED_FRONT_WALL_Y = BED_Y1 + 0.060

FRONT_AXLE_Y = 2.540            # 0.95 m of front overhang, measured off the ref
BOGIE_C_Y = FRONT_AXLE_Y - REAL_WHEELBASE       # -1.372
MID_AXLE_Y = BOGIE_C_Y + REAL_BOGIE * 0.5       # -0.813
REAR_AXLE_Y = BOGIE_C_Y - REAL_BOGIE * 0.5      # -1.931

TYRE_R = REAL_TYRE_OD * 0.5     # 0.527
TYRE_HW = 0.114                 # half of the 9.00 in section
RIM_R = 0.290
HUB_F = REAL_TRACK_F * 0.5      # 0.8225
DUAL_C = 0.885                  # dual-pair centre; outer tyre face lands 1.154,
                                # 6.5 cm inboard of the bed side, as in the ref
DUAL_HALF = 0.155               # each tyre of the pair sits +/- this off the hub

FRAME_Z0, FRAME_Z1 = 0.620, 0.900
HOOD_BOT = 1.050
HOOD_TOP_R, HOOD_TOP_F = 1.680, 1.600
FENDER_Y0, FENDER_Y1 = 1.950, 3.288    # 12 mm shy of the front panel at 3.300
GRILLE_Z0, GRILLE_Z1 = 1.020, 1.620
LAMP_Z = 1.420
CAB_SILL_Z = 1.020
CAB_FLOOR_Z = 1.100
DOOR_TOP_Z = 1.660
WIN_TOP_Z = 2.100
WS_BOT_Z, WS_TOP_Z = 1.950, 2.560
CAB_ROOF_Z = REAL_HEIGHT_CAB    # 2.820
BED_FLOOR_BOT = 1.200
BED_FLOOR_TOP = REAL_BED_FLOOR_Z
BED_RAIL_Z = 1.960
TAILGATE_HW = 1.060             # the gate drops between the two corner posts
TARP_TOP_Z = REAL_HEIGHT_TARP

WS_HINGE_Y, WS_HINGE_Z = 1.480, 1.900
WS_RAKE_DEG = 6.0
WS_HW = 1.020

NS_TYRE = 10
NS_LAMP = 10
NS_TUBE = 8

# The tarp's cross-section, half the truck, from the bed rail to the crown.
# Mirrored to make the full arc. These ARE the bows - nothing else models them.
TARP_PROFILE = [(1.219, BED_RAIL_Z), (1.219, 2.520), (1.175, 2.760),
                (1.020, 2.930), (0.660, 2.985), (0.000, TARP_TOP_Z)]
# stations down the bed: bows at the full section, mid-bays sagging 20 mm
TARP_STATIONS = [(BED_FRONT_WALL_Y, 0.000), (-0.464, 0.010), (-1.216, 0.000),
                 (-1.968, 0.010), (-2.720, 0.000), (REAR_EXT, 0.000)]

MATS = {
    "od":     (0.243, 0.263, 0.196),   # Vietnam olive drab, same chip as the M151
    "canvas": (0.276, 0.284, 0.222),   # tarp + cab soft top: OD but lighter/greyer
    "metal":  (0.105, 0.110, 0.105),
    "rubber": (0.042, 0.042, 0.045),
    "glass":  (0.560, 0.630, 0.640),
    "amber":  (0.860, 0.520, 0.060),
    "red":    (0.620, 0.070, 0.060),
}
MAT_NAMES = {
    "od": "M35_OliveDrab", "canvas": "M35_Canvas", "metal": "M35_MetalDark",
    "rubber": "M35_Rubber", "glass": "M35_Glass",
    "amber": "M35_LensAmber", "red": "M35_LensRed",
}


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

    def cap(self, pts, outward, tag):
        """Fan a convex polygon with its normal FORCED to point along `outward`.

        Winding an end cap by eye is the commonest way a hand-built shell ends
        up with a black hole in it, and eyeballing it is exactly what went
        wrong on the first pass here: the tarp's front and rear caps and both
        fender caps were all inverted, and every one of them rendered as a
        black wedge. Newell's normal decides it instead of me."""
        n = Vector()
        for i in range(len(pts)):
            a, b = Vector(pts[i]), Vector(pts[(i + 1) % len(pts)])
            n.x += (a.y - b.y) * (a.z + b.z)
            n.y += (a.z - b.z) * (a.x + b.x)
            n.z += (a.x - b.x) * (a.y + b.y)
        self.poly(list(reversed(pts)) if n.dot(Vector(outward)) < 0.0 else pts, tag)

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
    # shared corners makes edges 4-sided - it silently flips faces there.
    FACES = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4),
             (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]

    def box(self, lo, hi, tag):
        (x0, y0, z0), (x1, y1, z1) = lo, hi
        # An inverted range silently builds the solid inside out: the "top"
        # corner ring ends up BELOW the bottom one and all twelve faces point
        # inward. The hood-crease strip was written with z 1.640 -> 1.600 and
        # rendered as a bright flipped-normal slab beside each headlight, and
        # nothing else in the QC pass could see it. It is an error, not a
        # tolerance to be sorted away.
        assert x1 > x0 and y1 > y0 and z1 > z0, \
            "box(%s, %s) has an inverted range - it would build inside out" % (lo, hi)
        self.hexa([(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                   (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], tag)

    def hexa(self, corners, tag):
        """8-corner solid: 0-3 the bottom ring CCW seen from +Z, 4-7 the top."""
        o = self.add_verts(corners)
        for f in Shell.FACES:
            self.face([i + o for i in f], tag)

    def mirrored(self):
        """A copy across x=0 with every face reversed. Building the left side by
        negating a sign leaves every face on it pointing INTO the body."""
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


def tyre(shell, xc=0.0, n=NS_TYRE):
    """One road wheel centred on xc, spin axis = X.

    PH puts a vertex at the bottom of the ring. Without it a 10-sided tyre's
    lowest vertex sits at sin(-72 deg) = -0.951 r, the model floats 26 mm and
    the ground-line assertion fails. 12 divides 360 into a bottom vertex for
    free, which is why the M151 never needed this; 10 does not."""
    PH = TAU * 0.25
    def ring(x, r):
        return [(x, r * math.cos(PH + TAU * i / n), r * math.sin(PH + TAU * i / n))
                for i in range(n)]
    out_p, out_m = ring(xc + TYRE_HW, TYRE_R), ring(xc - TYRE_HW, TYRE_R)
    rim_p, rim_m = ring(xc + TYRE_HW, RIM_R), ring(xc - TYRE_HW, RIM_R)
    shell.ring_bridge(out_m, out_p, "rubber")          # tread band
    shell.ring_bridge(out_p, rim_p, "rubber")          # outboard sidewall
    shell.ring_bridge(rim_m, out_m, "rubber")          # inboard sidewall
    shell.poly(rim_p, "metal")                         # outboard rim face
    shell.poly(list(reversed(rim_m)), "metal")


# ====================================================================== build
def build_front_right():
    """Everything on the RIGHT of the truck's nose. Mirrored for the left."""
    s = Shell()
    # --- frame rail --------------------------------------------------------
    # The rail runs all the way to the rear crossmember. Stopping it at -3.20
    # left the rear step hanging in space with nothing under it.
    s.box((0.360, -3.430, FRAME_Z0), (0.460, 3.300, FRAME_Z1), "metal")
    # --- bumper + tow shackle ---------------------------------------------
    s.box((0.000, BUMPER_Y0, 0.620), (1.050, BUMPER_Y1, 0.790), "metal")
    s.box((0.240, FRONT_PANEL_Y, 0.600), (0.360, BUMPER_Y1, 0.720), "metal")

    # --- the FRONT FENDER: a round-topped crown flanking the hood ----------
    # profile is (x, z of the crown); the skirt drops from the last point
    # The inner edge tucks 50 mm UNDER the hood side (x 0.520) rather than
    # sitting flush with it, and FENDER_Y1 stops 12 mm behind the front panel.
    # Flush on either seam made the two surfaces coplanar and the render came
    # back with a bright wedge beside each headlight.
    prof = [(0.470, 1.550), (0.720, 1.500), (0.920, 1.420),
            (1.060, 1.280), (CAB_HW, 1.140)]
    SKIRT = 1.040                    # skirt bottom, level with the tyre crown
    TOPS = [(x, FENDER_Y0, z) for x, z in prof]
    TOPF = [(x, FENDER_Y1, z) for x, z in prof]
    BOTS = [(x, FENDER_Y0, SKIRT) for x, _ in prof]
    BOTF = [(x, FENDER_Y1, SKIRT) for x, _ in prof]
    s.strip(TOPS, TOPF, "od")                      # the crown
    s.strip(BOTF, BOTS, "od")                      # underside
    s.cap([TOPS[-1], TOPF[-1], BOTF[-1], BOTS[-1]], (1, 0, 0), "od")     # outer skirt
    s.cap([BOTS[0], BOTF[0], TOPF[0], TOPS[0]], (-1, 0, 0), "od")        # inner wall
    s.cap(TOPS + [BOTS[-1], BOTS[0]], (0, -1, 0), "od")                  # rear cap
    s.cap(TOPF + [BOTF[-1], BOTF[0]], (0, 1, 0), "od")                   # front cap

    # --- radiator surround, mesh grille, separated bars, brush guard -------
    s.box((0.000, 3.260, GRILLE_Z0), (0.560, FRONT_PANEL_Y, GRILLE_Z1), "od")
    s.box((0.000, 3.240, 1.060), (0.460, 3.268, 1.580), "metal")   # mesh recess
    for i in range(3):                          # SEPARATED VERTICAL BARS
        x0 = 0.055 + i * 0.170
        s.box((x0, 3.264, 1.060), (x0 + 0.055, 3.304, 1.580), "od")
    s.box((0.000, 3.258, 1.580), (0.500, 3.310, 1.640), "od")      # top rail
    s.box((0.000, 3.258, 0.980), (0.500, 3.310, 1.030), "od")      # bottom rail
    # brush guard: a horizontal rail across the nose + two uprights
    s.box((0.000, 3.340, 1.600), (0.720, 3.380, 1.660), "metal")
    for bx in (0.200, 0.520):
        s.box((bx, 3.340, 0.790), (bx + 0.048, 3.380, 1.660), "metal")

    # --- lamps: headlight in the grille shoulder, marker on the fender -----
    c = (0.660, 3.255, LAMP_Z)
    cyl(s, c, (c[0], 3.365, c[2]), 0.115, NS_LAMP, "metal", "metal", "amber")
    m = (0.945, 3.230, 1.395)
    cyl(s, m, (m[0], 3.300, m[2]), 0.058, NS_TUBE, "metal", "metal", "amber")
    s.box((0.585, 3.060, 1.548), (0.700, 3.150, 1.610), "metal")   # blackout lamp
    return s


def build_body():
    """Chassis, nose, bonnet, fenders and the FULL-WIDTH CAB. The single most
    damaging error on the shipped truck was a 1.05 m cab beside a 2.10 m bed;
    CAB_HW is 1.10 against a 1.219 bed half-width, which is the real ratio."""
    s = Shell()
    right = build_front_right()
    s.merge(right)
    s.merge(right.mirrored())

    # --- the bonnet: long, flat, drooping to the grille, NO LOUVRES --------
    # truck-encyclopedia: "The bonnet lacked louvres, opening in the centre
    # along a twin hinged system." The review's spec asked for side louvre
    # panels; the reference says the deuce has none and the walkaround agrees.
    s.hexa([(-0.520, HOOD_Y0, HOOD_BOT), (0.520, HOOD_Y0, HOOD_BOT),
            (0.520, HOOD_Y1, HOOD_BOT - 0.030), (-0.520, HOOD_Y1, HOOD_BOT - 0.030),
            (-0.520, HOOD_Y0, HOOD_TOP_R), (0.520, HOOD_Y0, HOOD_TOP_R),
            (0.520, HOOD_Y1, HOOD_TOP_F), (-0.520, HOOD_Y1, HOOD_TOP_F)], "od")

    # --- the CAB ------------------------------------------------------------
    s.box((-CAB_HW, CAB_Y0, CAB_SILL_Z), (CAB_HW, CAB_Y1, CAB_FLOOR_Z), "od")
    s.box((-CAB_HW + 0.060, CAB_Y0, CAB_FLOOR_Z),
          (CAB_HW - 0.060, CAB_Y0 + 0.060, 2.200), "od")           # rear panel
    s.box((-CAB_HW + 0.060, CAB_Y1 - 0.060, CAB_FLOOR_Z),
          (CAB_HW - 0.060, CAB_Y1, 1.900), "od")                   # cowl / dash
    for sgn in (1.0, -1.0):
        xo, xi = sorted((sgn * CAB_HW, sgn * (CAB_HW - 0.060)))
        s.box((xo, CAB_Y0, CAB_FLOOR_Z), (xi, CAB_Y1, DOOR_TOP_Z), "od")   # door
        s.box((xo, CAB_Y0, DOOR_TOP_Z), (xi, CAB_Y0 + 0.070, WIN_TOP_Z), "od")
        s.box((xo, CAB_Y1 - 0.070, DOOR_TOP_Z), (xi, CAB_Y1, WIN_TOP_Z), "od")
        s.box((xo, CAB_Y0, WIN_TOP_Z), (xi, CAB_Y1, WIN_TOP_Z + 0.070), "od")
        xg, xh = sorted((sgn * (CAB_HW - 0.018), sgn * (CAB_HW - 0.042)))
        s.box((xg, CAB_Y0 + 0.070, DOOR_TOP_Z), (xh, CAB_Y1 - 0.070, WIN_TOP_Z), "glass")
        # step plate under the door
        s.box((min(sgn * 0.960, sgn * 1.140), 0.760, 0.720),
              (max(sgn * 0.960, sgn * 1.140), 1.040, 0.780), "metal")
        # canvas side curtain, sill of the soft top up to the roof
        xc, xd = sorted((sgn * (CAB_HW - 0.020), sgn * (CAB_HW - 0.075)))
        s.box((xc, CAB_Y0, WIN_TOP_Z + 0.070), (xd, CAB_Y1, 2.720), "canvas")
    s.box((-CAB_HW + 0.075, CAB_Y0, 2.200), (CAB_HW - 0.075, CAB_Y0 + 0.055, 2.720),
          "canvas")                                                # rear curtain
    # the soft top itself: a slightly domed slab, its crown IS the cab height
    s.hexa([(-CAB_HW + 0.020, CAB_Y0 - 0.020, 2.700), (CAB_HW - 0.020, CAB_Y0 - 0.020, 2.700),
            (CAB_HW - 0.020, CAB_Y1 + 0.030, 2.700), (-CAB_HW + 0.020, CAB_Y1 + 0.030, 2.700),
            (-CAB_HW + 0.090, CAB_Y0 + 0.040, CAB_ROOF_Z),
            (CAB_HW - 0.090, CAB_Y0 + 0.040, CAB_ROOF_Z),
            (CAB_HW - 0.090, CAB_Y1 - 0.030, CAB_ROOF_Z),
            (-CAB_HW + 0.090, CAB_Y1 - 0.030, CAB_ROOF_Z)], "canvas")

    # --- fuel tank (left) and the vertical exhaust stack (right) -----------
    s.box((-1.010, 0.560, 0.760), (-0.560, 1.360, 1.120), "metal")
    cyl(s, (0.985, 0.520, 1.300), (0.985, 0.520, 2.900), 0.056, NS_TUBE, "metal")
    return s


def build_windscreen():
    """Two-pane folding windscreen filling its own frame, full cab width, plus
    the mirrors. The M151's lesson: a mirror hung proud of the widest point
    blows the published width, so these are held inboard of the 1.219 bed line."""
    s = Shell()
    s.box((-WS_HW, -0.026, WS_BOT_Z - 0.060), (WS_HW, 0.026, WS_BOT_Z), "od")
    s.box((-WS_HW, -0.026, WS_TOP_Z), (WS_HW, 0.026, WS_TOP_Z + 0.070), "od")
    for sgn in (1.0, -1.0):
        xo, xi = sorted((sgn * WS_HW, sgn * (WS_HW - 0.062)))
        s.box((xo, -0.026, WS_BOT_Z), (xi, 0.026, WS_TOP_Z), "od")
    s.box((-0.032, -0.026, WS_BOT_Z), (0.032, 0.026, WS_TOP_Z), "od")   # centre post
    for x0, x1 in ((-(WS_HW - 0.062), -0.032), (0.032, WS_HW - 0.062)):
        s.box((x0, -0.009, WS_BOT_Z), (x1, 0.009, WS_TOP_Z), "glass")
    for sgn in (1.0, -1.0):
        ax0, ax1 = sorted((sgn * WS_HW, sgn * 1.160))
        s.box((ax0, -0.016, 2.300), (ax1, 0.016, 2.330), "metal")       # arm
        mx0, mx1 = sorted((sgn * 1.145, sgn * 1.200))
        s.box((mx0, -0.024, 2.215), (mx1, 0.024, 2.415), "metal")       # head
    # rake it back about the cowl hinge, then bake the rotation into the verts
    R = Matrix.Rotation(math.radians(-WS_RAKE_DEG), 3, "X")
    piv = Vector((0.0, 0.0, WS_HINGE_Z))
    s.v = [tuple(R @ (Vector(p) - piv) + piv + Vector((0.0, WS_HINGE_Y, 0.0))) for p in s.v]
    return s


def build_bed():
    """Ribbed steel cargo bed, drop tailgate, tandem mudguards, tail lamps.
    The ribs are the OUTER surface at +/-HW and the panels are recessed 20 mm
    behind them - that keeps the ribbed read without the ribs pushing the truck
    past its published 2.438 m width."""
    s = Shell()
    s.box((-HW, BED_Y0, BED_FLOOR_BOT), (HW, BED_Y1, BED_FLOOR_TOP), "od")
    right = Shell()
    # Recessed side panel. THREE DISTINCT PLANES down the bed side and no two
    # the same: panel 1.189, ribs 1.209, rails HW = 1.219. Every time two of
    # them shared an x the render came back with a grid of black speckles -
    # coincident faces, the same defect the A-1 wreck's buried wing has.
    right.box((HW - 0.060, BED_Y0, BED_FLOOR_TOP), (HW - 0.030, BED_Y1, BED_RAIL_Z), "od")
    # Vertical stake ribs. They stop 10 mm SHY of HW while the two horizontal
    # rails below reach HW. Ribs and rails at the same x made their outer faces
    # COPLANAR wherever they crossed, and Cycles picked between them per sample:
    # a grid of black speckles down the whole bed side in every render.
    for i in range(6):
        y0 = BED_Y0 + 0.130 + i * (REAL_BED_L - 0.320) / 5.0
        right.box((HW - 0.060, y0, BED_FLOOR_TOP), (HW - 0.010, y0 + 0.090, BED_RAIL_Z), "od")
    # top rail and the lower belt rail - these carry the width
    right.box((HW - 0.070, BED_Y0, BED_RAIL_Z - 0.075), (HW, BED_Y1, BED_RAIL_Z), "od")
    right.box((HW - 0.070, BED_Y0, 1.430), (HW, BED_Y1, 1.500), "od")
    # rear corner post - the tail lamp lives HERE, not on the tailgate, so it
    # does not travel with a dropped gate
    right.box((TAILGATE_HW, REAR_EXT, BED_FLOOR_TOP), (HW, BED_Y0, BED_RAIL_Z), "od")
    # tandem mudguard, a flat plate under the bed edge
    right.box((0.600, -3.100, 1.140), (HW, -0.200, BED_FLOOR_BOT), "od")
    # tail lamp
    # Kept a full lamp radius inboard of HW. At HW-0.040 the 78 mm lamp put the
    # truck 2.514 m wide (+3.1%) and the width assertion convicted it - the same
    # way the M151's mirror blew ITS published width.
    c = (HW - 0.084, REAR_EXT, 1.520)
    cyl(right, (c[0], REAR_EXT + 0.060, c[2]), c, 0.070, NS_TUBE, "metal", "metal", "red")
    s.merge(right)
    s.merge(right.mirrored())
    # front wall and the drop tailgate
    s.box((-HW, BED_Y1, BED_FLOOR_TOP), (HW, BED_FRONT_WALL_Y, BED_RAIL_Z), "od")
    # Tailgate top is FLUSH with the bed rail. At 1.86 it left a 100 mm slot
    # between the gate and the tarp's rear flap, and the render looked straight
    # into the unlit inside of the cover through a black letterbox.
    s.box((-TAILGATE_HW, REAR_EXT, 1.240), (TAILGATE_HW, BED_Y0, BED_RAIL_Z), "od")
    s.box((-0.320, REAR_EXT, 0.760), (0.320, BED_Y0, 0.830), "metal")   # rear step
    return s


def build_tarp():
    """The bow-and-canvas top as ONE smooth skin. TARP_PROFILE is the arc the
    bows make; no bow object exists, so nothing can end up sitting on top of the
    cover the way BowRail_+-0.93 sat 7 cm above Canvas_Top on the shipped truck."""
    s = Shell()
    half = TARP_PROFILE
    # full must run MONOTONICALLY -1.219 .. 0 .. +1.219 across the truck. The
    # first pass reversed the left half as well as the right, so the section
    # read -0.66, -1.02, -1.22, 0.0, +0.66 ... - a self-intersecting bowtie.
    # The swept skin still bridged cleanly, which is why it looked almost right,
    # and only the END CAPS showed it: a black wedge in every render.
    full = [(-x, z) for x, z in half[:-1]] + [half[-1]] + list(reversed(half[:-1]))
    xs = [p[0] for p in full]
    # non-DEcreasing: the two vertical side segments legitimately repeat an x
    assert all(b >= a for a, b in zip(xs, xs[1:])), "tarp section is not monotonic: %s" % xs
    def station(y, sag):
        return [(x, y, z - (sag if z > BED_RAIL_Z + 0.4 else 0.0)) for x, z in full]
    rings = [station(y, sag) for y, sag in TARP_STATIONS]
    for a, b in zip(rings[:-1], rings[1:]):
        s.strip(a, b, "canvas")
    s.cap(rings[0], (0, 1, 0), "canvas")             # front face, against the cab
    s.cap(rings[-1], (0, -1, 0), "canvas")           # rear flap, laced shut
    return s


def build_col_lower():
    s = Shell()
    s.box((-HW, REAR_EXT, 0.0), (HW, FRONT_EXT, BED_RAIL_Z), "metal")
    return s


def build_col_upper():
    s = Shell()
    s.box((-HW, REAR_EXT, BED_RAIL_Z), (HW, CAB_Y1 + 0.020, TARP_TOP_Z), "metal")
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
    e.empty_display_size = 0.12
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


# wheel node name -> (hub x, hub y, is a dual pair)
WHEELS = [("m35_wheel_fl", -HUB_F, FRONT_AXLE_Y, False),
          ("m35_wheel_fr", HUB_F, FRONT_AXLE_Y, False),
          ("m35_wheel_ml", -DUAL_C, MID_AXLE_Y, True),
          ("m35_wheel_mr", DUAL_C, MID_AXLE_Y, True),
          ("m35_wheel_rl", -DUAL_C, REAR_AXLE_Y, True),
          ("m35_wheel_rr", DUAL_C, REAR_AXLE_Y, True)]


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    do_export = "--export" in argv
    render_dir = argv[argv.index("--render") + 1] if "--render" in argv else None

    bpy.ops.wm.read_factory_settings(use_empty=True)

    body = make_object("M35_Body", build_body())
    wscr = make_object("M35_Windscreen", build_windscreen())
    bed = make_object("M35_CargoBed", build_bed())
    tarp = make_object("M35_Tarp", build_tarp())
    wheels = []
    for name, hx, hy, dual in WHEELS:
        w = Shell()
        if dual:
            tyre(w, -DUAL_HALF)
            tyre(w, DUAL_HALF)
        else:
            tyre(w, 0.0)
        wheels.append(make_object(name, w, (hx, hy, TYRE_R)))
    cols = [make_object("M35_Col_Lower-colonly", build_col_lower()),
            make_object("M35_Col_Upper-colonly", build_col_upper())]

    # Sockets kept from m35_rigged.blend (2026-07-29): its seat vocabulary is
    # already correct - seat_driver sits at -x, which IS the vehicle's left with
    # +Y forward and +Z up, i.e. left-hand drive. Only its WHEEL and BED-WALL
    # L/R names were inverted, and those are rebuilt here rather than inherited.
    empty("seat_driver", (-0.420, 0.950, CAB_FLOOR_Z + 0.360))
    empty("seat_passenger", (0.420, 0.950, CAB_FLOOR_Z + 0.360))
    for i in range(5):
        y = BED_Y0 + 0.500 + i * 0.680
        empty("seat_troop_l_%d" % (i + 1), (-0.860, y, BED_FLOOR_TOP + 0.410))
        empty("seat_troop_r_%d" % (i + 1), (0.860, y, BED_FLOOR_TOP + 0.410))
    empty("TAILGATE_PIVOT", (0.0, BED_Y0, 1.240))

    visible = [body, wscr, bed, tarp] + wheels
    # matrix_world is STALE until the depsgraph runs. Without this the wheels
    # measure as if they were at the origin and the ground line reads negative.
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
    length, width, height = hi.y - lo.y, hi.x - lo.x, hi.z - lo.z
    cab_hi = bounds([body])[1]
    bedlo, bedhi = bounds([bed])
    print("\n--- MEASURED vs REAL (object space, metres) ------------------")
    for lab, got, real in (("length", length, REAL_LENGTH),
                           ("width", width, REAL_WIDTH),
                           ("height(tarp)", height, REAL_HEIGHT_TARP),
                           ("height(cab)", CAB_ROOF_Z, REAL_HEIGHT_CAB),
                           ("wheelbase", FRONT_AXLE_Y - BOGIE_C_Y, REAL_WHEELBASE),
                           ("bogie", MID_AXLE_Y - REAR_AXLE_Y, REAL_BOGIE),
                           ("track(f)", 2 * HUB_F, REAL_TRACK_F),
                           ("tyre OD", 2 * TYRE_R, REAL_TYRE_OD),
                           ("bed floor L", BED_Y1 - BED_Y0, REAL_BED_L),
                           ("bed width", bedhi.x - bedlo.x, REAL_BED_W),
                           ("bed floor z", BED_FLOOR_TOP, REAL_BED_FLOOR_Z)):
        print("  %-12s %7.3f  real %6.3f  d %+0.3f  (%+0.1f%%)"
              % (lab, got, real, got - real, 100.0 * (got - real) / real))
    print("  bbox lo %s hi %s" % (tuple(round(c, 3) for c in lo), tuple(round(c, 3) for c in hi)))
    print("  ORIGIN = ground line (z 0 = tyre contact), centreline, longitudinal centre")
    print("  ground line at z %+0.4f   bogie centre at y %+0.4f" % (lo.z, BOGIE_C_Y))
    print("  CAB half width %.3f vs BED half width %.3f  -> cab is %.0f%% of the bed"
          % (CAB_HW, HW, 100.0 * CAB_HW / HW))
    print("  bed OUTER y %+0.3f..%+0.3f (%.3f, incl. tailgate + front wall)"
          % (bedlo.y, bedhi.y, bedhi.y - bedlo.y))
    print("  highest point forward of the bed: %.3f (exhaust stack; cab roof %.3f)"
          % (cab_hi.z, CAB_ROOF_Z))
    print("  TOTAL VISIBLE TRIS %d   collider tris %d"
          % (tris, sum(len(c.data.loop_triangles) for c in cols)))
    body_share = 100.0 * (len(body.data.loop_triangles) + len(bed.data.loop_triangles)
                          + len(tarp.data.loop_triangles)) / tris
    wheel_share = 100.0 * sum(len(w.data.loop_triangles) for w in wheels) / tris
    print("  BODYWORK (body+bed+tarp) %.1f%%   wheels %.1f%%" % (body_share, wheel_share))

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
        bm.free()
        print("  %-26s ngons %d loose %d doubles %d zero-area %d"
              % (ob.name, ng, loose, dbl, zero))
        if ng or loose or dbl or zero:
            bad.append(ob.name)
    assert not bad, "QC FAILED on %s" % bad

    for ob in visible:
        assert len(ob.data.loop_triangles) != 1152, "%s is a default torus" % ob.name
    assert abs(lo.z) < 1e-6, "the tyres must touch z=0: ground line is %+0.4f" % lo.z
    assert abs(lo.x + hi.x) < 1e-6, "not laterally symmetric (%.5f)" % (lo.x + hi.x)
    assert abs(length - REAL_LENGTH) < 1e-6, "length %.4f" % length
    assert abs(width - REAL_WIDTH) < 1e-6, "width %.4f" % width
    # THE defect the review named first: a cab half the width of its own bed
    assert CAB_HW / HW > 0.85, "the cab is only %.0f%% of the bed" % (100 * CAB_HW / HW)
    # and the second: a bow rail sitting on top of the cover
    assert hi.z - TARP_TOP_Z < 1e-6, \
        "something stands proud of the tarp crown (max z %.4f)" % hi.z
    assert body_share >= 45.0, "bodywork carries only %.1f%% of the tris" % body_share
    for ob in visible + cols:
        assert all(abs(c - 1.0) < 1e-6 for c in ob.scale), "%s has unapplied scale" % ob.name
        assert all(abs(c) < 1e-6 for c in ob.rotation_euler), "%s carries rotation" % ob.name
    for ob in [body, wscr, bed, tarp] + cols:
        assert ob.location.length < 1e-6, "%s must be at identity, is at %s" % (ob.name, ob.location)
    for w, (name, hx, hy, _d) in zip(wheels, WHEELS):
        assert abs(w.location.x - hx) < 1e-6 and abs(w.location.y - hy) < 1e-6, \
            "%s hub is at %s" % (name, w.location)
    print("  materials: %d -> %s" % (len(bpy.data.materials),
                                     sorted(m.name for m in bpy.data.materials)))
    for m in bpy.data.materials:
        assert m.node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value == 0.0
    assert not [i for i in bpy.data.images if i.name != "Render Result"], "textures leaked in"
    print("  QC PASS")

    if render_dir:
        for c in cols:
            c.hide_render = True
        do_render(render_dir, lo, hi)
        for c in cols:
            c.hide_render = False

    if do_export:
        for ob in list(bpy.data.objects):
            if ob.type in {"CAMERA", "LIGHT"} or ob.name.startswith("_datum"):
                bpy.data.objects.remove(ob, do_unlink=True)
        blend = os.path.join(OUT_DIR, "m35_deuce_truck_v2.blend")
        glb = os.path.join(OUT_DIR, "m35_deuce_truck_v2.glb")
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


# ====================================================================== renders
# azimuth 0 = camera on +X (the vehicle's right), 90 = ahead of the nose (+Y).
VIEWS = [("side", 180.0, 4.0), ("front", 90.0, 6.0),
         ("threequarter", 42.0, 15.0), ("rear_quarter", 236.0, 13.0)]

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
    """A 1.7132 m grunt block beside the truck, plus the review's render
    convention: a GREEN slab at +Y (ratified forward) and a RED slab at -Y."""
    skin = _flat("_datum_skin", (0.62, 0.47, 0.36))
    cloth = _flat("_datum_cloth", (0.28, 0.31, 0.22))
    x = 2.05
    parts = [("_datum_legs", (x - 0.17, -0.13, 0.00), (x + 0.17, 0.13, 0.86), cloth),
             ("_datum_torso", (x - 0.21, -0.15, 0.86), (x + 0.21, 0.15, 1.44), cloth),
             ("_datum_head", (x - 0.10, -0.10, 1.50), (x + 0.10, 0.10, DATUM_H), skin),
             ("_datum_neck", (x - 0.06, -0.06, 1.44), (x + 0.06, 0.06, 1.50), skin)]
    for n, lo, hi, m in parts:
        _prim(n, lo, hi, m)
    _prim("_datum_fwd", (-0.50, 4.00, 0.0), (0.50, 4.36, 0.12), _flat("_datum_green", (0.10, 0.62, 0.14)))
    _prim("_datum_aft", (-0.50, -4.36, 0.0), (0.50, -4.00, 0.12), _flat("_datum_red", (0.68, 0.09, 0.08)))
    _prim("_datum_ground", (-5.4, -5.6, -0.014), (5.4, 5.6, 0.0), _flat("_datum_dirt", (0.31, 0.28, 0.21)))


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
                                     math.sin(e))) * (span * 2.05)
        cam.rotation_euler = (tgt - Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(out_dir, "m35v2_%s.png" % name)
        bpy.ops.render.render(write_still=True)
        print("RENDER %s" % sc.render.filepath)

    add_datum()
    tgt = Vector((0.55, 0.0, 1.35))
    a, e = math.radians(36.0), math.radians(8.0)
    cam.location = tgt + Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a),
                                 math.sin(e))) * 16.0
    cam.rotation_euler = (tgt - Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(out_dir, "m35v2_datum.png")
    bpy.ops.render.render(write_still=True)
    print("RENDER %s" % sc.render.filepath)


main()
