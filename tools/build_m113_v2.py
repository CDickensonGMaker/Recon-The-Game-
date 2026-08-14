"""Build the M113A1 ACAV armoured personnel carrier v2 from scratch and export it.

    blender -b --factory-startup --python tools/build_m113_v2.py -- [--export] [--render DIR]

FRAME CONTRACT (the v2 fleet pattern, tools/build_m151_v2.py / build_m35_v2.py):
  nose at Blender +Y  = Godot -Z          +Z up          real metres
  +X is the vehicle's RIGHT               all transforms applied

ORIGIN: the GROUND LINE (track contact patch), on the centreline, at the
longitudinal centre of the nose-to-ramp envelope. destructible_vehicle.gd:30-31
drops the node origin onto terrain height, so anything else buries or floats it.

THE ONE RELATIONSHIP THE SHIPPED MODEL HAD INVERTED. On a real M113 the HULL
SIDE sits just INBOARD of the outer face of a 0.381 m track, and hull + track
together are 2.686 m all-in. The shipped m113_apc.glb hung 0.120 m "bicycle
chain" tracks 0.19 m OUTBOARD of a 2.716 m hull - a hull that on its own is
wider than a real M113 is in total. Here the TRACK is the widest thing on the
vehicle at exactly +/-1.343, the hull side is 1.270, and the road wheels sit
between them at 1.303. Nothing else may reach 1.343.

THE SPONSON IS WHY THE HULL IS NOT ONE BOX. The upper hull (x +/-1.270) stops
at z 0.800 - it OVERHANGS the track, which is why the road wheels are visible
under it. Between the tracks the belly tub drops to the published 0.434 m
ground clearance. Two solids, and the seam between them is buried, never
coplanar (see the notes on coincident surfaces reading as dirt).
"""

import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

TAU = math.tau
PROJ = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT_DIR = os.path.join(PROJ, "assets", "us", "vehicles")

# ------------------------------------------------------------ real numbers
# en.wikipedia.org/wiki/M113_armored_personnel_carrier :
#   4.863 m long, 2.686 m wide, 2.5 m high, ground clearance 17.1 in (0.434 m)
#   on the A1, torsion bar, 5 road wheels, 5083 aluminium 28-44 mm.
# army-guide.com/eng/product1424.html : "five road wheels, DRIVE SPROCKET FRONT,
#   IDLER REAR, NO TRACK-RETURN ROLLERS", 63/64 track links.
# T130E1 track: 15 in (0.381 m) wide, 6 in (0.1524 m) pitch -> a 63-link loop is
#   9.601 m of track, which is asserted against the belt path this file builds.
#
# THE 2.5 m IS THE OVERALL HEIGHT, NOT THE HULL ROOF, and the commission brief
# had it as "height 2.5 m to hull roof". The reference refutes that: in the
# Puckapunyal walkaround the fitters standing beside the vehicle have their
# SHOULDERS at the roof line, so the roof is ~1.85 m and 2.5 m is over the
# commander's cupola. Built to 1.850 roof / 2.500 over the ACAV shield ring.
REAL_LENGTH = 4.863
REAL_WIDTH = 2.686              # OVER THE TRACKS - the widest point
REAL_HEIGHT = 2.500             # over the cupola / ACAV gunshield ring
REAL_ROOF_Z = 1.850             # hull roof
REAL_TRACK_W = 0.381            # 15 in
REAL_CLEARANCE = 0.434          # 17.1 in, M113A1
REAL_WHEEL_D = 0.610            # 24 in road wheel
REAL_TRACK_LOOP = 9.601         # 63 links x 6 in pitch

# ------------------------------------------------------------ design datum
HALF_W = REAL_WIDTH * 0.5       # 1.343 - the OUTER face of the track
TRACK_IN = HALF_W - REAL_TRACK_W        # 0.962 - inner face of the track
TRACK_C = (HALF_W + TRACK_IN) * 0.5     # 1.1525 - running-gear centreline
HULL_HW = 1.270                 # hull side plate, 73 mm inboard of the track
# The belly tub runs BETWEEN the tracks - but NOT flush with the track's inner
# face. At exactly TRACK_IN the tub's side wall and the track band's inner wall
# were the SAME PLANE over the whole length of the vehicle: two coplanar,
# opposite-facing surfaces, which Cycles renders as speckle and any engine
# z-fights. Backface culling hides it in Godot, which is precisely what makes
# it the kind of defect that ships. 32 mm inboard.
BELLY_HW = TRACK_IN - 0.032     # 0.930

FRONT = REAL_LENGTH * 0.5       # +2.4315, nose (trim-vane hinge plate)
REAR = -FRONT                   # -2.4315, ramp outer face

BELLY_Z = REAL_CLEARANCE        # 0.434
SPONSON_Z = 0.800               # underside of the upper hull, over the track
ROOF_Z = REAL_ROOF_Z            # 1.850
LFP_KNEE_Y = 1.870              # belly turns up into the lower front plate
LFP_TOP_Z = 1.000               # top of the lower front plate, at y = FRONT
GLACIS_TOP_Y = 1.450            # where the glacis meets the roof

# lower front plate as z -> y, used by every part bolted to the nose
LFP_SLOPE = (FRONT - LFP_KNEE_Y) / (LFP_TOP_Z - BELLY_Z)        # 0.9921
GLACIS_A = Vector((FRONT, LFP_TOP_Z))                           # foot
GLACIS_B = Vector((GLACIS_TOP_Y, ROOF_Z))                       # crest
GLACIS_L = (GLACIS_B - GLACIS_A).length
GLACIS_U = (GLACIS_B - GLACIS_A) / GLACIS_L                     # up the slope
GLACIS_N = Vector((GLACIS_U.y, -GLACIS_U.x))                    # out of the face


def lfp_y(z):
    """y of the lower front plate at height z."""
    return LFP_KNEE_Y + LFP_SLOPE * (z - BELLY_Z)


def glacis(s, off):
    """(y, z) a fraction s along the glacis, off metres out of its face."""
    p = GLACIS_A + GLACIS_U * (s * GLACIS_L) + GLACIS_N * off
    return p.x, p.y


# ---- running gear ---------------------------------------------------------
BAND_T = 0.038                  # track band thickness
WHEEL_R = REAL_WHEEL_D * 0.5    # 0.305
WHEEL_HW = 0.150
WHEEL_Z = 0.349                 # hub centre; wheel bottom rests on the band
WHEEL_BELT_R = WHEEL_Z - BAND_T # 0.311 -> band outer face lands exactly on z=0
WHEEL_Y = [1.275, 0.615, -0.045, -0.705, -1.365]        # front -> rear, 0.660

# The idler IS a road wheel on the M113. At r 0.290 against a belt inner
# radius of 0.322 it stood 32 mm clear of its own track and the floater
# probe convicted it once the probe was widened past the bodywork.
IDLER_Y, IDLER_Z, IDLER_R = -1.865, 0.360, 0.305
IDLER_BELT_R = IDLER_Z - BAND_T                          # 0.322
# The sprocket is raised and smaller, and its band wrap MUST stay under the
# sponson at 0.800 or the drive sprocket eats the hull side.
SPKT_Y, SPKT_Z, SPKT_R = 1.965, 0.500, 0.250
SPKT_BELT_R = 0.255
NS_WHEEL = 8                    # phased so a vertex lands on the ground line
NS_TUBE = 8
NS_CUPOLA = 12
NS_SHIELD = 10

# ---- superstructure -------------------------------------------------------
CUPOLA_Y = 0.300
CUPOLA_R = 0.380
CUPOLA_Z0, CUPOLA_Z1, CUPOLA_Z2 = ROOF_Z, 2.000, 2.180
SHIELD_R0, SHIELD_R1 = 0.600, 0.645
SHIELD_Z0, SHIELD_Z1 = 1.980, REAL_HEIGHT      # crown IS the published height
M60_X, M60_Y = 0.900, -0.950
RAMP_HW = 0.920                 # the ramp opening runs between the sponsons
RAMP_Z0, RAMP_Z1 = 0.460, 1.790
RAMP_FRONT = -2.3415            # buried in the hull; the outer face is REAR

MATS = {
    "od":     (0.243, 0.263, 0.196),   # Vietnam olive drab, the fleet chip
    "track":  (0.118, 0.108, 0.096),   # rusted steel track shoe
    "metal":  (0.105, 0.110, 0.105),
    "rubber": (0.042, 0.042, 0.045),
    "glass":  (0.320, 0.380, 0.400),   # vision blocks / periscopes
    "amber":  (0.760, 0.430, 0.075),
    "red":    (0.620, 0.070, 0.060),
}
MAT_NAMES = {
    "od": "M113_OliveDrab", "track": "M113_TrackSteel", "metal": "M113_MetalDark",
    "rubber": "M113_Rubber", "glass": "M113_VisionBlock",
    "amber": "M113_LensAmber", "red": "M113_LensRed",
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
        o = self.add_verts(pts)
        for i in range(1, len(pts) - 1):
            self.face((o, o + i, o + i + 1), tag)

    def cap(self, pts, outward, tag):
        """Fan a polygon with its normal FORCED to point along `outward`.
        Newell's normal decides the winding, not me - hand-winding an end cap
        is a coin flip and a wrong one renders as a black wedge."""
        n = Vector()
        for i in range(len(pts)):
            a, b = Vector(pts[i]), Vector(pts[(i + 1) % len(pts)])
            n.x += (a.y - b.y) * (a.z + b.z)
            n.y += (a.z - b.z) * (a.x + b.x)
            n.z += (a.x - b.x) * (a.y + b.y)
        self.poly(list(reversed(pts)) if n.dot(Vector(outward)) < 0.0 else pts, tag)

    def strip(self, A, B, tag):
        oa = self.add_verts(A)
        ob = self.add_verts(B)
        for i in range(len(A) - 1):
            self.face((oa + i, oa + i + 1, ob + i + 1, ob + i), tag)

    def ring_bridge(self, A, B, tag):
        n = len(A)
        oa = self.add_verts(A)
        ob = self.add_verts(B)
        for i in range(n):
            j = (i + 1) % n
            self.face((oa + i, oa + j, ob + j, ob + i), tag)

    FACES = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4),
             (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]

    def box(self, lo, hi, tag):
        (x0, y0, z0), (x1, y1, z1) = lo, hi
        # An inverted range builds the solid inside out and NOTHING in a
        # topology QC can see it. It is an error, not a tolerance.
        assert x1 > x0 and y1 > y0 and z1 > z0, \
            "box(%s, %s) has an inverted range - it would build inside out" % (lo, hi)
        self.hexa([(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                   (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], tag)

    def hexa(self, corners, tag):
        o = self.add_verts(corners)
        for f in Shell.FACES:
            self.face([i + o for i in f], tag)

    def prism(self, prof, x0, x1, tag):
        """Sweep a CLOSED, CCW (y, z) profile along x. Every side face gets its
        outward direction from the profile winding, so no face can flip."""
        n = len(prof)
        for i in range(n):
            y0, z0 = prof[i]
            y1, z1 = prof[(i + 1) % n]
            uy, uz = y1 - y0, z1 - z0
            L = math.hypot(uy, uz)
            if L < 1e-9:
                continue
            out = (0.0, uz / L, -uy / L)        # right of travel = outside a CCW loop
            self.cap([(x0, y0, z0), (x1, y0, z0), (x1, y1, z1), (x0, y1, z1)], out, tag)
        self.cap([(x1, y, z) for y, z in prof], (1, 0, 0), tag)
        self.cap([(x0, y, z) for y, z in prof], (-1, 0, 0), tag)

    def mirrored(self):
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
    p0, p1 = Vector(p0), Vector(p1)
    a = (p1 - p0).normalized()
    u, v = _basis(a)
    A = [tuple(p0 + (u * math.cos(TAU * i / n) + v * math.sin(TAU * i / n)) * r) for i in range(n)]
    B = [tuple(p1 + (u * math.cos(TAU * i / n) + v * math.sin(TAU * i / n)) * r) for i in range(n)]
    shell.ring_bridge(A, B, side_tag)
    shell.poly(list(reversed(A)), cap0_tag or side_tag)
    shell.poly(B, cap1_tag or side_tag)


# ================================================================ running gear
def wheel(shell, r, hw, hub_r=0.118, dish=0.045, n=NS_WHEEL,
          tyre_tag="rubber", hub_tag="metal"):
    """One dished road wheel centred on its own hub, spin axis = X.

    PHASE tau/4. A 10-sided ring's lowest vertex otherwise sits at
    sin(-72 deg) = -0.951 r and the whole vehicle floats 30 mm off the ground
    line. 12 and 8 get a bottom vertex for free; 10 does not."""
    PH = TAU * 0.25

    def ring(x, rr):
        return [(x, rr * math.cos(PH + TAU * i / n), rr * math.sin(PH + TAU * i / n))
                for i in range(n)]

    out_p, out_m = ring(hw, r), ring(-hw, r)
    hub_p = ring(hw - dish, hub_r)
    shell.ring_bridge(out_m, out_p, tyre_tag)      # tread band
    shell.ring_bridge(out_p, hub_p, hub_tag)       # outboard dish
    shell.poly(hub_p, hub_tag)                     # hub face, normal +X
    shell.poly(list(reversed(out_m)), hub_tag)     # inboard face, normal -X


def belt(circles, extra, step_deg=30.0):
    """Taut-belt contour around an ordered CCW list of (y, z, r) circles.

    Returns [(y, z, ny, nz)] - the point on the belt PITCH path and the unit
    outward normal there, so the caller can offset an inner and an outer skin
    from the same list. A circle may appear twice (the road wheels carry both
    the top and the bottom run) and its arc there is simply near-zero.

    This is the only honest way to draw a track that wraps a RAISED front
    sprocket, a rear idler and five road wheels the top run rests directly on:
    the loop is NOT convex, so a convex hull would pull the top run taut 0.16 m
    above the road wheels, which no M113 has ever done - it carries no return
    rollers (army-guide.com/eng/product1424.html)."""
    n = len(circles)
    tang = []
    for i in range(n):
        y0, z0, r0 = circles[i]
        y1, z1, r1 = circles[(i + 1) % n]
        dy, dz = y1 - y0, z1 - z0
        L = math.hypot(dy, dz)
        uy, uz = dy / L, dz / L
        # N . u = (r0 - r1) / L is the external-tangent condition; the
        # perpendicular component is the OUTSIDE of a CCW loop, rot(u, -90).
        sa = max(-1.0, min(1.0, (r0 - r1) / L))
        ca = math.sqrt(max(0.0, 1.0 - sa * sa))
        tang.append((uz * ca + uy * sa, -uy * ca + uz * sa))
    out = []
    for i in range(n):
        y, z, r = circles[i]
        nin = tang[(i - 1) % n]
        nout = tang[i]
        a0 = math.atan2(nin[1], nin[0])
        a1 = math.atan2(nout[1], nout[0])
        sweep = (a1 - a0) % TAU
        if sweep > 4.0:                      # a legitimate wrap never exceeds pi
            sweep -= TAU
        # A road wheel on a straight run has a sweep of a few TENTHS of a
        # milliradian, and its sign is float noise. Emitting both endpoints
        # then laid two 0.3 mm-apart quads on the same plane sharing no
        # vertex - 12 coincident seams the face probe convicted, on the top
        # and bottom runs beside the sprocket and the idler. One point.
        # sweep <= 0 means the two tangents CROSS before the circle - a
        # CONCAVE joint, which is what the top run does where it drops off
        # the raised sprocket onto the first road wheel. Emitting an arc
        # there walks BACKWARDS along the contour and folds the band over
        # itself: 12 coincident seams either end of the top run.
        if sweep < 0.02:
            a = a0 + sweep * 0.5
            ny, nz = math.cos(a), math.sin(a)
            out.append((y + r * ny, z + r * nz, ny, nz))
            continue
        k = max(1, int(math.ceil(abs(sweep) / math.radians(step_deg))))
        for j in range(k + 1):
            a = a0 + sweep * (j / k)
            ny, nz = math.cos(a), math.sin(a)
            out.append((y + r * ny, z + r * nz, ny, nz))
    clean = []
    for p in out:
        if not clean or math.hypot(p[0] - clean[-1][0], p[1] - clean[-1][1]) > 5e-4:
            clean.append(p)
    if math.hypot(clean[0][0] - clean[-1][0], clean[0][1] - clean[-1][1]) < 1e-4:
        clean.pop()
    if extra:
        pass
    return clean


def belt_length(path):
    L = 0.0
    for i in range(len(path)):
        a, b = path[i], path[(i + 1) % len(path)]
        L += math.hypot(b[0] - a[0], b[1] - a[1])
    return L


TRACK_CIRCLES = ([(SPKT_Y, SPKT_Z, SPKT_BELT_R)]
                 + [(y, WHEEL_Z, WHEEL_BELT_R) for y in WHEEL_Y]
                 + [(IDLER_Y, IDLER_Z, IDLER_BELT_R)]
                 + [(y, WHEEL_Z, WHEEL_BELT_R) for y in reversed(WHEEL_Y)])


def build_track(x0, x1):
    """One track run: a closed band swept across x. The band's OUTER skin is
    the widest and lowest surface on the vehicle - it defines both the 2.686 m
    width and the z = 0 ground line."""
    s = Shell()
    path = belt(TRACK_CIRCLES, None)
    n = len(path)
    for i in range(n):
        a, b = path[i], path[(i + 1) % n]
        ao = (a[0] + a[2] * BAND_T, a[1] + a[3] * BAND_T)
        bo = (b[0] + b[2] * BAND_T, b[1] + b[3] * BAND_T)
        ai, bi = (a[0], a[1]), (b[0], b[1])
        uy, uz = bo[0] - ao[0], bo[1] - ao[1]
        L = math.hypot(uy, uz) or 1.0
        out = (0.0, uz / L, -uy / L)
        s.cap([(x0, ao[0], ao[1]), (x1, ao[0], ao[1]),
               (x1, bo[0], bo[1]), (x0, bo[0], bo[1])], out, "track")
        s.cap([(x0, ai[0], ai[1]), (x1, ai[0], ai[1]),
               (x1, bi[0], bi[1]), (x0, bi[0], bi[1])],
              (0.0, -out[1], -out[2]), "track")
        s.cap([(x1, ao[0], ao[1]), (x1, bo[0], bo[1]),
               (x1, bi[0], bi[1]), (x1, ai[0], ai[1])], (1, 0, 0), "track")
        s.cap([(x0, ao[0], ao[1]), (x0, bo[0], bo[1]),
               (x0, bi[0], bi[1]), (x0, ai[0], ai[1])], (-1, 0, 0), "track")
    return s


# ====================================================================== hull
def build_hull_right():
    """Everything on the RIGHT half of the hull that is not on the centreline."""
    s = Shell()
    # --- hull side: one horizontal filler/weld strip and three stiffeners ----
    # Three distinct planes and no two the same: side 1.270, strip 1.286,
    # stiffener 1.278. Two details sharing an x makes their outer faces
    # coplanar and the render comes back speckled with what looks like dirt.
    s.box((1.240, -2.310, 1.286), (1.286, 1.330, 1.334), "od")
    for y0 in (-1.90, -0.60, 0.70):
        # x0 1.226, NOT the strip's 1.240 - the two inner faces were coplanar
        # where the stiffener crosses the strip. Buried inside the hull, so
        # backface culling hides it in Godot and only the probe sees it.
        s.box((1.226, y0, SPONSON_Z + 0.030), (1.278, y0 + 0.070, ROOF_Z - 0.030), "od")
    # fuel filler cap, aft on the side
    s.box((1.250, -1.500, 1.480), (1.292, -1.320, 1.640), "metal")
    # engine exhaust louvre, forward on the side
    s.box((1.250, 0.960, 1.030), (1.290, 1.310, 1.330), "metal")
    # --- sponson lip: a chamfer strip along the bottom edge of the hull side.
    #     Held 12 mm INBOARD of the side plate; flush made the two outer faces
    #     coplanar over their overlap band.
    s.box((1.200, -2.330, SPONSON_Z - 0.048), (1.258, 1.980, SPONSON_Z + 0.008), "od")

    # --- FINAL DRIVE HOUSING, a bulge on the lower front plate ---------------
    #     The first pass hung this at x 0.93..1.285, z 0.315..0.685 - out in the
    #     void between the belly tub and the track, ATTACHED TO NOTHING, the
    #     same defect class as the shipped model's floating `Shovel`. The
    #     floater probe in main() now convicts that automatically. It belongs
    #     inboard of the track, growing out of the sloped plate: buried at the
    #     top, protruding 0.14 m at the bottom.
    s.box((0.620, 1.860, 0.450), (0.905, 2.030, 0.720), "metal")

    # --- HEADLIGHT + RECTANGULAR BRUSH GUARD, upper outer corner of the glacis
    hy, hz = glacis(0.62, 0.0)
    oy, oz = 0.055 * GLACIS_N.x, 0.055 * GLACIS_N.y      # N is (y, z), not (x, y)
    s.box((0.860, hy - 0.150, hz - 0.020), (1.180, hy + 0.150, hz + 0.020), "od")   # boss
    lo = (0.900, hy + oy - 0.130, hz + oz - 0.130)
    hi = (1.140, hy + oy + 0.130, hz + oz + 0.130)
    s.box(lo, hi, "metal")                                                          # housing
    s.box((0.925, hi[1] - 0.012, lo[2] + 0.028), (1.115, hi[1] + 0.030, hi[2] - 0.028), "amber")
    gy = hi[1] + 0.055
    for bx in (0.932, 1.012, 1.092):                       # three vertical guard bars
        s.box((bx, hi[1] - 0.004, lo[2] - 0.052), (bx + 0.020, gy - 0.008, hi[2] + 0.052), "metal")
    s.box((0.900, hi[1] - 0.010, hi[2] + 0.030), (1.140, gy, hi[2] + 0.058), "metal")
    s.box((0.900, hi[1] - 0.010, lo[2] - 0.058), (1.140, gy, lo[2] - 0.030), "metal")

    # --- TOW SHACKLE, low on the lower front plate ---------------------------
    sz = 0.620
    sy = lfp_y(sz)
    s.box((0.380, sy - 0.020, sz - 0.075), (0.640, sy + 0.115, sz - 0.020), "metal")
    s.box((0.380, sy - 0.020, sz + 0.020), (0.640, sy + 0.115, sz + 0.075), "metal")
    s.box((0.395, sy + 0.075, sz - 0.062), (0.625, sy + 0.135, sz + 0.062), "metal")

    # --- rear: tail lamp and a lifting eye on the hull rear corner -----------
    s.box((0.980, REAR + 0.062, 1.520), (1.190, REAR + 0.150, 1.700), "metal")
    s.box((1.000, REAR + 0.030, 1.545), (1.170, REAR + 0.070, 1.675), "red")
    # --- roof: grab rail down the outer edge. ONE box per rail - the first
    #     pass built each as two stanchions plus a bar and spent 216 tris,
    #     9% of the whole vehicle, on handrails nobody sees at convoy range.
    for y0 in (-2.05, -0.95):
        s.box((1.086, y0, ROOF_Z - 0.020), (1.144, y0 + 0.655, ROOF_Z + 0.075), "metal")
    return s


def build_hull():
    s = Shell()
    # --- A: the upper hull. Its bottom at SPONSON_Z is the overhang the track
    #     and road wheels live under. CCW profile in (y, z).
    s.prism([(-2.3715, SPONSON_Z), (lfp_y(SPONSON_Z), SPONSON_Z), (FRONT, LFP_TOP_Z),
             (GLACIS_TOP_Y, ROOF_Z), (-2.3715, ROOF_Z)], -HULL_HW, HULL_HW, "od")
    # --- B: the belly tub between the tracks, down to the published clearance.
    #     Its top at 0.860 and its rear at -2.3515 are BURIED inside A; the two
    #     solids share no coplanar face anywhere.
    s.prism([(-2.3515, BELLY_Z), (LFP_KNEE_Y, BELLY_Z), (lfp_y(SPONSON_Z), SPONSON_Z),
             (lfp_y(SPONSON_Z), 0.860), (-2.3515, 0.860)], -BELLY_HW, BELLY_HW, "od")

    right = build_hull_right()
    s.merge(right)
    s.merge(right.mirrored())

    # --- roof: driver's hatch (front LEFT), engine deck (front RIGHT) --------
    # EVERY applied detail PENETRATES its parent; nothing butts. A butt joint
    # puts two faces on one plane and the coincident-face probe convicts it.
    s.box((-0.740, 0.920, ROOF_Z - 0.010), (-0.160, 1.400, ROOF_Z + 0.075), "od")
    s.box((-0.700, 1.362, ROOF_Z + 0.020), (-0.200, 1.446, ROOF_Z + 0.140), "metal")
    s.box((-0.655, 1.418, ROOF_Z + 0.048), (-0.245, 1.454, ROOF_Z + 0.112), "glass")
    s.box((0.180, 0.760, ROOF_Z - 0.044), (1.150, 1.410, ROOF_Z + 0.055), "od")
    for i in range(3):                                   # engine deck louvres
        y0 = 0.850 + i * 0.170
        s.box((0.240, y0, ROOF_Z + 0.028), (1.090, y0 + 0.058, ROOF_Z + 0.085), "metal")
    # --- roof: the big rear cargo hatch -------------------------------------
    s.box((-0.640, -1.980, ROOF_Z - 0.050), (0.640, -0.380, ROOF_Z + 0.070), "od")
    s.box((-0.560, -1.940, ROOF_Z + 0.042), (0.560, -1.880, ROOF_Z + 0.125), "metal")
    s.box((-0.140, -0.470, ROOF_Z + 0.042), (0.140, -0.400, ROOF_Z + 0.130), "metal")
    # --- PIONEER TOOLS, ON the roof and penetrating it. The shipped model's
    #     `Shovel` hung 0.32 m clear of the hull attached to nothing; these
    #     start 20 mm BELOW the roof plane and cannot float.
    s.box((-1.100, -0.300, ROOF_Z - 0.032), (-0.780, 0.620, ROOF_Z + 0.045), "metal")   # shovel blade
    s.box((-0.985, 0.550, ROOF_Z - 0.014), (-0.895, 1.480, ROOF_Z + 0.038), "od")       # haft, into it
    s.box((0.760, -2.180, ROOF_Z - 0.026), (0.860, -1.110, ROOF_Z + 0.038), "od")       # axe haft
    s.box((0.700, -1.180, ROOF_Z - 0.038), (0.930, -0.980, ROOF_Z + 0.055), "metal")    # axe head
    # --- rear: two stowage/tow lugs on the hull rear face --------------------
    for sgn in (-1.0, 1.0):
        x0, x1 = sorted((sgn * 0.560, sgn * 0.700))
        s.box((x0, REAR + 0.040, 1.740), (x1, REAR + 0.135, 1.830), "metal")
    return s


def build_trim_vane():
    """The TRIM VANE, folded flat on the glacis - the M113's single most
    recognisable front feature and the thing the shipped model had nothing of.
    Hinged at the bottom of the glacis, it swings up to make a bow wave board
    when the vehicle swims; stowed, it lies on the glacis under the headlights.
    Reference: the Puckapunyal walkaround, where a fitter lifts it clear."""
    s = Shell()
    S0, S1 = 0.060, 0.560                      # fraction of the glacis it covers
    OUT0, OUT1 = -0.020, 0.055                 # 20 mm INTO the glacis, 55 mm proud
    HW = 0.980
    a0 = glacis(S0, OUT0)
    a1 = glacis(S1, OUT0)
    b0 = glacis(S0, OUT1)
    b1 = glacis(S1, OUT1)
    s.prism([a0, a1, b1, b0], -HW, HW, "od")
    # the vane's stiffening rib, proud of its face and running its full width
    r0 = glacis(0.190, OUT1 - 0.020)
    r1 = glacis(0.300, OUT1 - 0.020)
    q0 = glacis(0.190, OUT1 + 0.038)
    q1 = glacis(0.300, OUT1 + 0.038)
    s.prism([r0, r1, q1, q0], -HW + 0.040, HW - 0.040, "od")
    # hinge lugs on the lower edge and the two stowed support arms
    for sgn in (-1.0, 1.0):
        x0, x1 = sorted((sgn * 0.560, sgn * 0.640))
        # The hinge lugs stand 85 mm off the glacis and must NOT be the front
        # extreme - at s = 0.020 they reached y 2.468 and blew the published
        # 4.863 m length by 56 mm. Started 60 mm further up the slope instead.
        h0 = glacis(0.075, -0.035)
        h1 = glacis(0.165, -0.035)
        g0 = glacis(0.075, 0.085)
        g1 = glacis(0.165, 0.085)
        s.prism([h0, h1, g1, g0], x0, x1, "metal")
        ax0, ax1 = sorted((sgn * 0.850, sgn * 0.915))
        p0 = glacis(0.120, OUT1 - 0.015)
        p1 = glacis(0.545, OUT1 - 0.015)
        p2 = glacis(0.545, OUT1 + 0.030)
        p3 = glacis(0.120, OUT1 + 0.030)
        s.prism([p0, p1, p2, p3], ax0, ax1, "metal")
    return s


def build_ramp():
    """The full-height rear ramp with its personnel door.

    FOUR STACKED PLANES, EACH PROUD OF THE LAST, AND NOTHING BUTTS. The first
    pass built the face as a picture frame of four boxes around a recessed
    door, and every one of them shared the head, sill or jamb plane with its
    neighbour: the coincident-face probe convicted eight seams down the rear of
    the vehicle. One slab, one proud door, ironwork proud of that. It is fewer
    triangles AND there is no seam left to get wrong. The REARMOST surface on
    the whole vehicle is the door's hinge strip and latch, at exactly REAR."""
    s = Shell()
    dx0, dx1, dz0, dz1 = -0.760, -0.120, 0.680, 1.560
    s.box((-RAMP_HW, REAR + 0.034, RAMP_Z0), (RAMP_HW, RAMP_FRONT, RAMP_Z1), "od")
    s.box((dx0, REAR + 0.012, dz0), (dx1, REAR + 0.070, dz1), "od")
    s.box((dx0 + 0.014, REAR, dz0 + 0.060), (dx0 + 0.084, REAR + 0.046, dz1 - 0.060), "metal")
    s.box((dx1 - 0.150, REAR, 1.060), (dx1 - 0.070, REAR + 0.046, 1.190), "metal")
    s.box((-0.906, REAR + 0.006, RAMP_Z1 - 0.030),
          (0.906, RAMP_FRONT - 0.020, RAMP_Z1 + 0.070), "od")
    # bottom hinge / actuator housings, one at each lower corner
    for sgn in (-1.0, 1.0):
        x0, x1 = sorted((sgn * 0.700, sgn * 0.860))
        s.box((x0, REAR + 0.004, RAMP_Z0 - 0.060), (x1, RAMP_FRONT + 0.090, RAMP_Z0 + 0.130), "metal")
    return s


def build_cupola():
    """Commander's cupola with the COMPLETE ACAV gunshield ring and the .50.
    The shipped model had three shield fragments clustered on ONE side of the
    cupola forming a partial arc; the Vietnam kit is a full ring."""
    s = Shell()
    PH = 0.0

    def ring(z, r, n):
        return [(r * math.cos(PH + TAU * i / n), r * math.sin(PH + TAU * i / n), z)
                for i in range(n)]

    z1 = CUPOLA_Z1 - CUPOLA_Z0
    z2 = CUPOLA_Z2 - CUPOLA_Z0
    n = NS_CUPOLA
    RB, RU = CUPOLA_R, CUPOLA_R - 0.030
    # base sleeve, then a closing SHOULDER annulus, then the upper sleeve. The
    # first pass butted a 0.380 sleeve onto a 0.350 sleeve and left an open
    # 30 mm annulus you could see into from above.
    s.ring_bridge(ring(-0.030, RB, n), ring(z1 + 0.020, RB, n), "od")
    s.ring_bridge(ring(z1 + 0.020, RB, n), ring(z1 + 0.020, RU, n), "od")
    # VISION BLOCKS ARE A BAND OF THE SLEEVE ITSELF, not a separate proud
    # sleeve: a 12 mm proud ring has two open rims and reads as a black slot.
    s.ring_bridge(ring(z1 - 0.020, RU, n), ring(z1 + 0.055, RU, n), "od")
    s.ring_bridge(ring(z1 + 0.055, RU, n), ring(z2, RU, n), "glass")
    s.poly(list(reversed(ring(z2, RU, n))), "od")
    # --- the ACAV gunshield ring: two concentric rings bridged, so no two
    #     plates share a face and the ring is genuinely closed.
    sz0, sz1 = SHIELD_Z0 - CUPOLA_Z0, SHIELD_Z1 - CUPOLA_Z0
    m = NS_SHIELD
    # THE GUN EMBRASURE. With a flat crown the .50's barrel ran straight
    # THROUGH the shield wall - visible in the first rear-quarter render as a
    # stick piercing solid plate. The two vertices either side of dead ahead
    # (+Y is 90 deg, and m = 10 puts vertices at 72 and 108) drop 0.16 m, so
    # the gun fires over a notch the way an ACAV shield is actually cut.
    tops = [sz1 - (0.160 if i in (2, 3) else 0.0) for i in range(m)]
    i0, o0 = ring(sz0, SHIELD_R0, m), ring(sz0, SHIELD_R1, m)
    i1 = [(p[0], p[1], tops[k]) for k, p in enumerate(ring(sz1, SHIELD_R0, m))]
    o1 = [(p[0], p[1], tops[k]) for k, p in enumerate(ring(sz1, SHIELD_R1, m))]
    s.ring_bridge(o0, o1, "od")                     # outer skin
    s.ring_bridge(i1, i0, "od")                     # inner skin
    s.ring_bridge(i1, o1, "od")                     # top edge
    s.ring_bridge(o0, i0, "od")                     # bottom edge
    for i in range(4):                              # brackets out to the cupola
        a = TAU * (i + 0.5) / 4.0
        cx, cy = math.cos(a), math.sin(a)
        px, py = -math.sin(a), math.cos(a)
        pts = []
        for rr, zz in ((CUPOLA_R - 0.020, sz0 - 0.090), (SHIELD_R0 + 0.020, sz0 - 0.090),
                       (SHIELD_R0 + 0.020, sz0 + 0.060), (CUPOLA_R - 0.020, sz0 + 0.060)):
            pts.append((rr * cx, rr * cy, zz))
        lo = [(p[0] - px * 0.045, p[1] - py * 0.045, p[2]) for p in pts]
        hi = [(p[0] + px * 0.045, p[1] + py * 0.045, p[2]) for p in pts]
        s.hexa([lo[0], lo[1], lo[2], lo[3], hi[0], hi[1], hi[2], hi[3]], "metal")
    # --- M2 HB .50 cal on the pintle, bore over the shield crown, muzzle +Y --
    bz = sz1 - 0.100
    s.box((-0.075, -0.180, bz - 0.130), (0.075, 0.060, bz + 0.020), "metal")      # pintle/cradle
    s.box((-0.062, -0.300, bz - 0.060), (0.062, 0.320, bz + 0.075), "metal")      # receiver
    s.box((-0.050, -0.430, bz - 0.030), (0.050, -0.290, bz + 0.096), "metal")     # backplate/grips
    cyl(s, (0.0, 0.255, bz), (0.0, 1.400, bz), 0.028, NS_TUBE, "metal")           # barrel
    cyl(s, (0.0, 0.268, bz), (0.0, 0.760, bz), 0.048, NS_TUBE, "metal")           # jacket
    s.box((-0.115, -0.140, bz - 0.230), (0.115, 0.140, bz - 0.120), "metal")      # ammo can
    return s


def build_acav_rear():
    """The two rear M60 positions, each with its own three-plate shield. The
    shipped model put ammo cans on the roof with NO guns and NO shields."""
    s = Shell()
    r = Shell()
    x, y = M60_X, M60_Y
    z0, z1 = ROOF_Z - 0.056, ROOF_Z + 0.430
    r.box((x - 0.060, y - 0.070, ROOF_Z - 0.068), (x + 0.060, y + 0.070, ROOF_Z + 0.180), "metal")
    # The two side plates PENETRATE the front plate and stop 4 mm inboard of
    # its x extent and 10 mm below its crown. Butted flush, the three plates
    # shared their +/-X and +Z planes and rendered as black strips down both
    # edges of every shield - the clearest thing in the first 3/4 render.
    r.box((x - 0.300, y + 0.300, z0), (x + 0.300, y + 0.345, z1), "od")     # front plate
    r.box((x + 0.250, y - 0.220, z0 - 0.006), (x + 0.306, y + 0.332, z1 - 0.010), "od")
    r.box((x - 0.306, y - 0.220, z0 - 0.006), (x - 0.250, y + 0.332, z1 - 0.010), "od")
    r.box((x - 0.045, y - 0.130, ROOF_Z + 0.148), (x + 0.045, y + 0.210, ROOF_Z + 0.275), "metal")
    cyl(r, (x, y + 0.150, ROOF_Z + 0.232), (x, y + 0.760, ROOF_Z + 0.232), 0.020, NS_TUBE, "metal")
    r.box((x - 0.050, y - 0.290, ROOF_Z + 0.150), (x + 0.050, y - 0.120, ROOF_Z + 0.255), "od")
    r.box((x - 0.190, y - 0.150, ROOF_Z - 0.074), (x - 0.075, y + 0.140, ROOF_Z + 0.140), "metal")
    s.merge(r)
    s.merge(r.mirrored())
    return s


def build_col_lower():
    s = Shell()
    s.box((-HALF_W, REAR, 0.0), (HALF_W, FRONT, ROOF_Z), "metal")
    return s


def build_col_upper():
    s = Shell()
    s.box((-SHIELD_R1, CUPOLA_Y - SHIELD_R1, ROOF_Z),
          (SHIELD_R1, CUPOLA_Y + SHIELD_R1, REAL_HEIGHT), "metal")
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
    b.inputs["Roughness"].default_value = 0.62 if tag != "glass" else 0.22
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


def empty(name, loc):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.12
    bpy.context.collection.objects.link(e)
    e.location = loc
    return e


def floaters(objs, tol=0.030):
    """Every disconnected lump of geometry must TOUCH something.

    The shipped m113_apc.glb carried a `Shovel` spanning x 1.690..1.710 with
    the hull's outer face at 1.367 - 0.32 m clear of the vehicle, welded to
    nothing, and a review had to find it by eye. My own first pass hung the
    final-drive housing in the void between the belly tub and the track. A
    topology QC cannot see either: both meshes are perfectly well formed.

    Split every mesh into connected islands in WORLD space, then ask the BVH
    of all OTHER geometry how far each island's nearest vertex is. Anything
    that cannot reach its neighbours inside `tol` is floating.
    Returns [(label, gap, centroid)]."""
    from mathutils.bvhtree import BVHTree

    islands = []            # (label, [world verts], [(a,b,c) tris into a global vert list])
    for ob in objs:
        me = ob.data
        me.calc_loop_triangles()
        M = ob.matrix_world
        co = [M @ v.co for v in me.vertices]
        parent = list(range(len(co)))

        def find(a):
            while parent[a] != a:
                parent[a] = parent[parent[a]]
                a = parent[a]
            return a

        for p in me.polygons:
            vs = list(p.vertices)
            for b in vs[1:]:
                ra, rb = find(vs[0]), find(b)
                if ra != rb:
                    parent[ra] = rb
        groups = {}
        for t in me.loop_triangles:
            groups.setdefault(find(t.vertices[0]), []).append(tuple(t.vertices))
        for k, tris in groups.items():
            used = sorted({i for t in tris for i in t})
            rm = {g: n for n, g in enumerate(used)}
            islands.append(("%s#%d" % (ob.name, len(islands)),
                            [co[i] for i in used],
                            [(rm[a], rm[b], rm[c]) for a, b, c in tris]))

    # THE TEST MUST BE SYMMETRIC. Measuring only my-vertices-to-their-surface
    # convicts every correctly PENETRATING detail: a 0.23 m box driven into a
    # 4.8 m hull plate has all eight of its corners outside its neighbours'
    # skins, and the hull prism's own ten corners are metres from anything.
    # The first run of this probe reported the main hull solid and a .50 cal
    # ammo can as floating - both were welded solid. An island is attached if
    # EITHER side can reach the other.
    def near(tree, verts):
        best = 1e9
        for v in verts:
            hit = tree.find_nearest(v)
            if hit[0] is not None:
                best = min(best, hit[3])
                if best <= tol:
                    break
        return best

    trees = [BVHTree.FromPolygons(v, t, all_triangles=True, epsilon=0.0)
             for _l, v, t in islands]
    bad = []
    for i, (lab, verts, _t) in enumerate(islands):
        ov, ot = [], []
        for j, (_l, v2, t2) in enumerate(islands):
            if j == i:
                continue
            o = len(ov)
            ov.extend(v2)
            ot.extend([(a + o, b + o, c + o) for a, b, c in t2])
        if not ot:
            continue
        gap = near(BVHTree.FromPolygons(ov, ot, all_triangles=True, epsilon=0.0), verts)
        if gap > tol:
            gap = min(gap, near(trees[i], ov))
        if gap > tol:
            c = sum(verts, Vector()) / len(verts)
            bad.append((lab, round(gap, 4), tuple(round(q, 3) for q in c)))
    return bad


def coincident(objs, plane_tol=0.0016, min_area=4.0e-4):
    """Find face pairs that share a plane and an area but share no vertex.

    THE LOW-POLY Z-FIGHT. Two solids whose skins land on the same plane over an
    overlapping patch render as black or speckled dirt in Cycles and z-fight in
    any engine - and because backface culling hides the opposite-facing case in
    Godot, it is exactly the defect that ships. The project ledger records this
    as a class no build-time check could see, only a render. It can be seen:

      parallel to 0.999 . within 1.6 mm of the same plane . overlapping area .
      AND SHARING NO VERTEX

    The last clause is not optional. Without it every quad's own two triangles,
    and every fan in a cap, report themselves and the output is unreadable."""
    tris = []
    for ob in objs:
        me = ob.data
        me.calc_loop_triangles()
        M = ob.matrix_world
        for t in me.loop_triangles:
            p = [M @ me.vertices[i].co for i in t.vertices]
            n = (p[1] - p[0]).cross(p[2] - p[0])
            if n.length < 1e-9:
                continue
            a = n.length * 0.5
            n = n.normalized()
            d = n.dot(p[0])
            if (n.x, n.y, n.z) < (-n.x, -n.y, -n.z):     # canonical: +n or -n
                n, d = -n, -d
            tris.append((n, d, p, a, ob.name))

    buckets = {}
    for i, (n, d, _p, a, _o) in enumerate(tris):
        if a < min_area:
            continue
        buckets.setdefault((round(n.x * 90), round(n.y * 90), round(n.z * 90)), []).append(i)

    def overlap(p, q, n):
        u = (p[1] - p[0]).normalized()
        v = n.cross(u)
        A = [(w.dot(u), w.dot(v)) for w in p]
        B = [(w.dot(u), w.dot(v)) for w in q]
        for poly in (A, B):                               # separating axis theorem
            for k in range(3):
                ex = poly[(k + 1) % 3][0] - poly[k][0]
                ey = poly[(k + 1) % 3][1] - poly[k][1]
                ax, ay = -ey, ex
                pa = [ax * s + ay * t for s, t in A]
                pb = [ax * s + ay * t for s, t in B]
                if min(pa) > max(pb) - 1e-9 or min(pb) > max(pa) - 1e-9:
                    return False
        return True

    hits = []
    for key, idx in buckets.items():
        idx.sort(key=lambda i: tris[i][1])
        for a in range(len(idx)):
            na, da, pa, _aa, oa = tris[idx[a]]
            for b in range(a + 1, len(idx)):
                nb, db, pb, _ab, ob_ = tris[idx[b]]
                if db - da > plane_tol:
                    break
                if abs(na.dot(nb)) < 0.999:
                    continue
                if any((x - y).length < 1e-5 for x in pa for y in pb):
                    continue
                if overlap(pa, pb, na):
                    c = (sum(pa, Vector()) + sum(pb, Vector())) / 6.0
                    hits.append(("n%s d%+0.3f %s|%s @%s"
                                 % (tuple(round(q, 2) for q in na), da,
                                    oa.replace("M113_", ""), ob_.replace("M113_", ""),
                                    tuple(round(q, 3) for q in c)),
                                 tuple(round(q / 0.05) for q in c)))
    # collapse to distinct 5 cm cells so one bad seam is one line, not fifty
    seen = {}
    for lab, cell in hits:
        seen[cell] = lab
    return sorted(seen.values())


def bounds(objs):
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    for ob in objs:
        for v in ob.data.vertices:
            w = ob.matrix_world @ v.co
            lo = Vector((min(lo[i], w[i]) for i in range(3)))
            hi = Vector((max(hi[i], w[i]) for i in range(3)))
    return lo, hi


WHEELS = ([("m113_wheel_l%d" % (i + 1), -TRACK_C, y, "road") for i, y in enumerate(WHEEL_Y)]
          + [("m113_wheel_r%d" % (i + 1), TRACK_C, y, "road") for i, y in enumerate(WHEEL_Y)]
          + [("m113_sprocket_l", -TRACK_C, SPKT_Y, "sprocket"),
             ("m113_sprocket_r", TRACK_C, SPKT_Y, "sprocket"),
             ("m113_idler_l", -TRACK_C, IDLER_Y, "idler"),
             ("m113_idler_r", TRACK_C, IDLER_Y, "idler")])
HUB_Z = {"road": WHEEL_Z, "sprocket": SPKT_Z, "idler": IDLER_Z}
HUB_R = {"road": WHEEL_R, "sprocket": SPKT_R, "idler": IDLER_R}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    do_export = "--export" in argv
    render_dir = argv[argv.index("--render") + 1] if "--render" in argv else None

    bpy.ops.wm.read_factory_settings(use_empty=True)

    hull = make_object("M113_Hull", build_hull())
    vane = make_object("M113_TrimVane", build_trim_vane())
    ramp = make_object("M113_Ramp", build_ramp())
    cupola = make_object("m113_cupola", build_cupola(), (0.0, CUPOLA_Y, CUPOLA_Z0))
    acav = make_object("M113_ACAV_Rear", build_acav_rear())
    tracks = [make_object("M113_Track_L", build_track(-HALF_W, -TRACK_IN)),
              make_object("M113_Track_R", build_track(TRACK_IN, HALF_W))]
    wheels = []
    for name, hx, hy, kind in WHEELS:
        w = Shell()
        hw = WHEEL_HW if kind == "road" else 0.120
        wheel(w, HUB_R[kind], hw,
              hub_r=0.118 if kind != "sprocket" else 0.150,
              tyre_tag="rubber" if kind == "road" else "metal")
        wheels.append(make_object(name, w, (hx, hy, HUB_Z[kind])))
    cols = [make_object("M113_Col_Lower-colonly", build_col_lower()),
            make_object("M113_Col_Upper-colonly", build_col_upper())]

    empty("seat_driver", (-0.450, 1.060, 0.960))
    empty("seat_commander", (0.000, CUPOLA_Y, 1.100))
    for i in range(5):
        y = -1.880 + i * 0.590
        empty("seat_troop_l_%d" % (i + 1), (-0.700, y, 0.920))
        empty("seat_troop_r_%d" % (i + 1), (0.700, y, 0.920))
    empty("seat_gunner_l", (-0.620, M60_Y, 1.150))
    empty("seat_gunner_r", (0.620, M60_Y, 1.150))
    empty("RAMP_PIVOT", (0.0, REAR, RAMP_Z0))

    visible = [hull, vane, ramp, cupola, acav] + tracks + wheels
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
    hull_lo, hull_hi = bounds([hull])
    loop = belt_length(belt(TRACK_CIRCLES, None))
    print("\n--- MEASURED vs REAL (object space, metres) ------------------")
    for lab, got, real in (("length", length, REAL_LENGTH),
                           ("width", width, REAL_WIDTH),
                           ("height", height, REAL_HEIGHT),
                           ("hull roof z", ROOF_Z, REAL_ROOF_Z),
                           ("track width", REAL_TRACK_W, REAL_TRACK_W),
                           ("ground clear", BELLY_Z, REAL_CLEARANCE),
                           ("road wheel D", 2 * WHEEL_R, REAL_WHEEL_D),
                           ("track loop", loop, REAL_TRACK_LOOP)):
        print("  %-13s %7.3f  real %6.3f  d %+0.3f  (%+0.1f%%)"
              % (lab, got, real, got - real, 100.0 * (got - real) / real))
    print("  bbox lo %s hi %s" % (tuple(round(c, 3) for c in lo), tuple(round(c, 3) for c in hi)))
    print("  ORIGIN = ground line (z 0 = track contact), centreline, longitudinal centre")
    print("  hull side |x| %.3f   track outer |x| %.3f   road wheel outer |x| %.3f"
          % (hull_hi.x, HALF_W, TRACK_C + WHEEL_HW))
    print("  hull nose y %+0.3f   sprocket band front y %+0.3f   OVERHANG %.3f m "
          "(shipped model: 0.730)"
          % (hull_hi.y, SPKT_Y + SPKT_BELT_R + BAND_T,
             hull_hi.y - (SPKT_Y + SPKT_BELT_R + BAND_T)))
    print("  road wheel hubs at y %s" % [round(y, 3) for y in WHEEL_Y])
    print("  TOTAL VISIBLE TRIS %d   collider tris %d"
          % (tris, sum(len(c.data.loop_triangles) for c in cols)))
    bodywork = [hull, vane, ramp, cupola, acav]
    body_t = sum(len(o.data.loop_triangles) for o in bodywork)
    track_t = sum(len(o.data.loop_triangles) for o in tracks)
    wheel_t = sum(len(o.data.loop_triangles) for o in wheels)
    body_share = 100.0 * body_t / tris
    print("  BODYWORK (hull+vane+ramp+cupola+ACAV) %d = %.1f%%   tracks %d = %.1f%%   "
          "wheels %d = %.1f%%"
          % (body_t, body_share, track_t, 100.0 * track_t / tris,
             wheel_t, 100.0 * wheel_t / tris))

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

    coin = coincident(visible)
    print("  COINCIDENT-FACE PROBE: %d seam%s %s"
          % (len(coin), "" if len(coin) == 1 else "s", coin[:14]))
    assert not coin, "coincident faces will z-fight at %d places: %s" % (len(coin), coin)

    float_bad = floaters(visible)
    print("  FLOATER PROBE over every visible mesh: %s"
          % ("none" if not float_bad else float_bad))
    assert not float_bad, "geometry attached to NOTHING: %s" % float_bad

    for ob in visible:
        assert len(ob.data.loop_triangles) != 1152, "%s is a default torus" % ob.name
    assert abs(lo.z) < 1e-6, "the tracks must touch z=0: ground line is %+0.4f" % lo.z
    assert abs(lo.x + hi.x) < 1e-6, "not laterally symmetric (%.5f)" % (lo.x + hi.x)
    assert abs(length - REAL_LENGTH) < 1e-6, "length %.4f" % length
    assert abs(width - REAL_WIDTH) < 1e-6, "width %.4f" % width
    assert abs(height - REAL_HEIGHT) < 1e-6, "height %.4f" % height
    # THE headline defect: the hull alone was wider than a real M113 is in total
    assert hull_hi.x <= HALF_W - 0.02, \
        "the hull side (%.3f) must sit INBOARD of the track's outer face (%.3f)" \
        % (hull_hi.x, HALF_W)
    assert 2.0 * hull_hi.x < REAL_WIDTH, "hull alone is %.3f wide" % (2 * hull_hi.x)
    # and the nose that overhung its own running gear by 0.73 m
    assert hull_hi.y - (SPKT_Y + SPKT_BELT_R + BAND_T) < 0.25, "the nose overhangs the sprocket"
    # the band wrap must clear the sponson or the sprocket eats the hull side
    assert SPKT_Z + SPKT_BELT_R + BAND_T <= SPONSON_Z + 1e-9, "sprocket wrap fouls the sponson"
    assert abs(loop - REAL_TRACK_LOOP) < 0.35, \
        "track loop %.3f m vs the 63-link T130E1 loop %.3f" % (loop, REAL_TRACK_LOOP)
    assert body_share >= 45.0, "bodywork carries only %.1f%% of the tris" % body_share
    for ob in visible + cols:
        assert all(abs(c - 1.0) < 1e-6 for c in ob.scale), "%s has unapplied scale" % ob.name
        assert all(abs(c) < 1e-6 for c in ob.rotation_euler), "%s carries rotation" % ob.name
    for ob in [hull, vane, ramp, acav] + tracks + cols:
        assert ob.location.length < 1e-6, "%s must be at identity, is at %s" % (ob.name, ob.location)
    for w, (name, hx, hy, kind) in zip(wheels, WHEELS):
        assert abs(w.location.x - hx) < 1e-6 and abs(w.location.y - hy) < 1e-6, \
            "%s hub is at %s" % (name, w.location)
        r = max(math.hypot(v.co.y, v.co.z) for v in w.data.vertices)
        assert abs(r - HUB_R[kind]) < 1e-6, "%s radius %.4f" % (name, r)
    print("  materials: %d -> %s" % (len(bpy.data.materials),
                                     sorted(m.name for m in bpy.data.materials)))
    assert len(bpy.data.materials) <= 8, "%d materials" % len(bpy.data.materials)
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
        blend = os.path.join(OUT_DIR, "m113_apc_v2.blend")
        glb = os.path.join(OUT_DIR, "m113_apc_v2.glb")
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
    skin = _flat("_datum_skin", (0.62, 0.47, 0.36))
    cloth = _flat("_datum_cloth", (0.28, 0.31, 0.22))
    x = 2.15
    parts = [("_datum_legs", (x - 0.17, -0.13, 0.00), (x + 0.17, 0.13, 0.86), cloth),
             ("_datum_torso", (x - 0.21, -0.15, 0.86), (x + 0.21, 0.15, 1.44), cloth),
             ("_datum_head", (x - 0.10, -0.10, 1.50), (x + 0.10, 0.10, DATUM_H), skin),
             ("_datum_neck", (x - 0.06, -0.06, 1.44), (x + 0.06, 0.06, 1.50), skin)]
    for n, lo, hi, m in parts:
        _prim(n, lo, hi, m)
    _prim("_datum_fwd", (-0.50, 3.20, 0.0), (0.50, 3.56, 0.12), _flat("_datum_green", (0.10, 0.62, 0.14)))
    _prim("_datum_aft", (-0.50, -3.56, 0.0), (0.50, -3.20, 0.12), _flat("_datum_red", (0.68, 0.09, 0.08)))
    _prim("_datum_ground", (-4.4, -4.6, -0.014), (4.4, 4.6, 0.0), _flat("_datum_dirt", (0.31, 0.28, 0.21)))


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
                                     math.sin(e))) * (span * 2.15)
        cam.rotation_euler = (tgt - Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(out_dir, "m113v2_%s.png" % name)
        bpy.ops.render.render(write_still=True)
        print("RENDER %s" % sc.render.filepath)

    add_datum()
    tgt = Vector((0.50, 0.0, 1.15))
    a, e = math.radians(36.0), math.radians(8.0)
    cam.location = tgt + Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a),
                                 math.sin(e))) * 13.0
    cam.rotation_euler = (tgt - Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(out_dir, "m113v2_datum.png")
    bpy.ops.render.render(write_still=True)
    print("RENDER %s" % sc.render.filepath)


if __name__ == "__main__":
    main()
