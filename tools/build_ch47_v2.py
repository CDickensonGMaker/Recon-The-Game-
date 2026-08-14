"""Build the CH-47A Chinook v2 from scratch and export it.

    blender -b --factory-startup --python tools/build_ch47_v2.py -- [--export] [--render DIR]

FRAME CONTRACT (the v2 fleet pattern, tools/build_m151_v2.py / m35 / m113):
  nose at Blender +Y  = Godot -Z          +Z up          real metres
  +X is the aircraft's RIGHT              all transforms applied
ORIGIN: the GROUND LINE (wheel contact) on the centreline, at the longitudinal
centre of the AIRFRAME envelope (nose .. lowered ramp lip).

THE DEFECT THIS REBUILD EXISTS TO KILL. `ch47_chinook.glb` (2026-05-25) is
exported with its FUSELAGE ALONG X, nose at -X - ninety degrees off the fleet
convention, and `scenes/vehicles/chinook.tscn` carries no compensating rotation,
so the ship flies sideways. `tools/probe_chinook_dims.gd` measured its ramp lip
at root-space +X and `seat_system.gd`'s ch47 fallback layout was then authored
AROUND that defect (fuselage "x -4.05..4.05 ALONG X, nose -X"). It is also
roughly HALF SIZE: its rotors measure ~8.4 m across against a real 18.01, its
three blades are three different lengths, and its lowest point sits 0.60 m
BELOW its own origin.

THE ORIGIN IS CHOSEN SO helicopter.gd's RECENTRE IS INERT. `helicopter.gd:78-84`
finds `Fuselage`, takes its AABB centre and subtracts it from the model's x/z.
The Fuselage mesh here spans the whole airframe symmetrically about the origin
in plan, so that centre is (0, *, 0) and the recentre moves nothing. Anything
else silently shifts every socket in the file relative to the hull.

REFERENCE, and where each number came from, is in the block below.
"""

import bpy, bmesh, math, os, sys
from mathutils import Vector

TAU = math.tau
PROJ = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT_DIR = os.path.join(PROJ, "assets", "us", "vehicles")

# =========================================================== real numbers
# vertipedia.vtol.org/aircraft/getAircraft/aircraftID/284 (Boeing CH-47A):
#   rotor diameter 18.01 m (59 ft 1 in), 3 blades per rotor
#   overall length 29.90 m (98.1 ft, rotors turning) . height 5.68 m
#   fuselage 15.47 m long, 3.78 m wide
#   landing gear base 6.86 m . rear track 3.40 m . front track 3.20 m
#   cabin 9.30 x 2.29 x 1.98 m
# chinook-helicopter.com/standards/areas/main_cabin.html: cargo compartment
#   "366 inches long, 90 inches wide, and 78 inches high" = 9.296 x 2.286 x 1.981.
# flugzeuginfo.net/acdata_php/acdata_ch47_en.php (CH-47C): overall length 30.18,
#   rotor 18.29 - the D-model 60 ft blade. THE VIETNAM SHIP IS THE A, so the
#   18.01 / 29.90 pair is used and the brief's 18.3 / 30.2 is NOT.
#
# HUB SEPARATION IS DERIVED, NOT GUESSED. With one blade of each rotor pointing
# fore and aft, overall = radius + separation + radius, so
#   separation = 29.90 - 18.01 = 11.89 m
# and both published figures are then honoured by construction.
REAL_ROTOR_D = 18.01
REAL_LEN_TURNING = 29.90
REAL_FUS_LEN = 15.47
REAL_FUS_W = 3.78
REAL_HEIGHT = 5.68
REAL_WHEELBASE = 6.86
REAL_TRACK_FWD = 3.20
REAL_TRACK_AFT = 3.40
REAL_CABIN_L, REAL_CABIN_W, REAL_CABIN_H = 9.30, 2.29, 1.98

HUB_SEP = REAL_LEN_TURNING - REAL_ROTOR_D          # 11.89
ROTOR_R = REAL_ROTOR_D * 0.5                       # 9.005

# ---- WHERE THE HUBS SIT ALONG THE HULL: measured off the Wikimedia three-view
# (commons: File:Boeing_CH-47_Chinook_3-view_line_drawing.svg, CC BY 3.0,
# rendered at 1920 px). Side elevation, nose LEFT. Landmarks in that image:
#   nose 226 px . fwd rotor head 343 . aft rotor head 950 . pylon TE 1063
#   fwd wheel 545 . aft wheel 888 . ground line 342 . aft rotor head 50
# THREE INDEPENDENT SCALES AGREE, which is what makes the drawing usable:
#   hub separation 607 px / 11.887 m -> 51.06 px/m
#   aft rotor head height 290 px / 5.68 m -> 51.06 px/m
#   wheelbase 343.5 px / 6.86 m       -> 50.07 px/m
# At 51.0 px/m the forward hub is 2.30 m aft of the nose - it sits over the
# COCKPIT, which is what inetres.com/gp/military/ar/rotor/CH-47.html means by
# "one above the nose and one above the tail section". A remembered "fuselage
# station 240" would have put it at 4.8 m and was WRONG; the drawing overruled it.
D_FWD_HUB = 2.30
D_AFT_HUB = D_FWD_HUB + HUB_SEP                    # 14.19
D_PYLON_TE = 16.40                                 # 837 px nose->pylon TE = 16.41
D_FWD_GEAR = 6.25                                  # 319 px
D_AFT_GEAR = D_FWD_GEAR + REAL_WHEELBASE           # 13.11, published base exactly
D_RAMP_HINGE = REAL_FUS_LEN                        # the published 15.47 is the
                                                   # fuselage; the pylon overhangs

# ---- heights
Z_FWD_ROTOR = 4.20                                 # (342-128)/51.0
Z_AFT_ROTOR = 5.50
Z_AFT_HUB_TOP = REAL_HEIGHT                        # 5.68 IS the top of the aft head
Z_BELLY = 0.95
Z_ROOF = 3.55
Z_FLOOR = 1.15                                     # cabin floor, cargo deck
Z_CEIL = Z_FLOOR + REAL_CABIN_H                    # 3.13
SPONSON_X0, SPONSON_X1 = 1.05, REAL_FUS_W * 0.5    # 1.05 .. 1.89 - the 3.78 m width
# The pod bottom is 0.09 m BELOW the belly line and 0.20 m above the tyre, both
# read off the three-view: at 0.98 the stance came out leggy in the datum render
# with a third of a metre of bare oleo showing under every pod.
SPONSON_Z0, SPONSON_Z1 = 0.86, 1.92
HULL_HW = 1.22                                     # 2.44 over the cabin box
BAY_HW = 1.14                                      # 2.28 clear vs a published 2.29
WHEEL_R = 0.33                                     # 24.5 x 7.7 main wheel
# Mast radius is 25 mm UNDER the rotor hub's, so the mast's own vertices are
# provably inside the hub and the two islands read as attached. A thinner mast
# is a floating rotor as far as any surface-distance probe is concerned.
HUB_R = 0.26
MAST_R = HUB_R - 0.025
MAST_DECK_F, MAST_DECK_A = 3.92, 5.36              # flat pylon decks

# ---- the ramp, LOWERED. Deliberate: the game empties a Chinook out of the back
# (seat_system.gd:735-745) and nothing in Godot animates a ramp, so a closed one
# would be a wall the stick walks through. Vietnam Chinooks flew ramp-down.
RAMP_LEN, RAMP_ANG = 2.50, math.radians(18.0)
RAMP_HW = 1.10
D_RAMP_LIP = D_RAMP_HINGE + RAMP_LEN * math.cos(RAMP_ANG)
Z_RAMP_LIP = Z_FLOOR - RAMP_LEN * math.sin(RAMP_ANG)
AIRFRAME_L = D_RAMP_LIP                            # 17.754
Y_OFF = AIRFRAME_L * 0.5                           # nose +8.877, lip -8.877


def Y(d):
    """Blender y for a station d metres aft of the nose."""
    return Y_OFF - d


MATS = {
    "od":     (0.243, 0.263, 0.196),   # the fleet olive-drab chip (m113/m35 v2)
    "metal":  (0.105, 0.110, 0.105),
    "rubber": (0.042, 0.042, 0.045),
    "cglass": (0.088, 0.104, 0.108),   # cockpit greenhouse, dark and opaque
    "wglass": (0.130, 0.150, 0.155),   # cabin port lights
    "blade":  (0.062, 0.062, 0.064),
    "soot":   (0.055, 0.050, 0.048),
}
MAT_NAMES = {
    "od": "CH47_OliveDrab", "metal": "CH47_MetalDark", "rubber": "CH47_Rubber",
    "cglass": "CH47_CockpitGlass", "wglass": "CH47_WindowGlass",
    "blade": "CH47_RotorBlade", "soot": "CH47_ExhaustSoot",
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
        """Fan a polygon with its normal FORCED along `outward`. Newell decides
        the winding, not me - hand-winding a cap is a coin flip and a wrong one
        renders as a black wedge."""
        n = Vector()
        for i in range(len(pts)):
            a, b = Vector(pts[i]), Vector(pts[(i + 1) % len(pts)])
            n.x += (a.y - b.y) * (a.z + b.z)
            n.y += (a.z - b.z) * (a.x + b.x)
            n.z += (a.x - b.x) * (a.y + b.y)
        self.poly(list(reversed(pts)) if n.dot(Vector(outward)) < 0.0 else pts, tag)

    FACES = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4),
             (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]

    def box(self, lo, hi, tag):
        (x0, y0, z0), (x1, y1, z1) = lo, hi
        assert x1 > x0 and y1 > y0 and z1 > z0, \
            "box(%s, %s) has an inverted range - it would build inside out" % (lo, hi)
        self.hexa([(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                   (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], tag)

    def hexa(self, corners, tag):
        # AN INSIDE-OUT SOLID IS INVISIBLE, NOT WRONG-LOOKING. Shell.FACES only
        # produces outward normals if 0-3 wind one way and 4-7 sit above them.
        # The lowered ramp was authored hinge-first, i.e. with DECREASING y, and
        # every one of its faces pointed inward: it vanished from all five
        # renders while ngons, doubles, loose verts, the coincident probe and
        # the floater probe all reported it healthy. Signed volume catches it
        # for four lines, so it is checked on every hexahedron in this file.
        o = self.add_verts(corners)
        c = [Vector(p) for p in corners]
        vol = 0.0
        for f in Shell.FACES:
            for k in range(1, 3):
                a, b, d = c[f[0]], c[f[k]], c[f[k + 1]]
                vol += a.dot(b.cross(d))
        assert vol > 1e-9, \
            "hexa() is INSIDE OUT (signed volume %+0.6f) - its faces would all " \
            "point inward and the part would be invisible: %s" % (vol / 6.0, corners)
        for f in Shell.FACES:
            self.face([i + o for i in f], tag)

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


def cyl(shell, p0, p1, r, n, side_tag, phase=0.0):
    p0, p1 = Vector(p0), Vector(p1)
    a = (p1 - p0).normalized()
    u, v = _basis(a)
    A = [tuple(p0 + (u * math.cos(phase + TAU * i / n)
                     + v * math.sin(phase + TAU * i / n)) * r) for i in range(n)]
    B = [tuple(p1 + (u * math.cos(phase + TAU * i / n)
                     + v * math.sin(phase + TAU * i / n)) * r) for i in range(n)]
    for i in range(n):
        j = (i + 1) % n
        mid = (Vector(A[i]) + Vector(A[j]) + Vector(B[j]) + Vector(B[i])) / 4.0
        axis_pt = p0 + a * (mid - p0).dot(a)
        shell.cap([A[i], A[j], B[j], B[i]], tuple(mid - axis_pt), side_tag)
    shell.cap(A, tuple(-a), side_tag)
    shell.cap(B, tuple(a), side_tag)


def rrect(hw, b0, b1, rb, rt, seg=2, off=0.0):
    """A closed CCW rounded rectangle in a 2-D (a, b) plane, `off` shifting `a`.

    Returned CCW starting at the bottom, right of centre, so the LAST edge
    (point[-1] -> point[0]) is the flat bottom run. Dropping that one edge turns
    the ring into an open-bottomed U without renumbering anything."""
    pts = []

    def arc(ca, cb, r, a0, a1):
        for i in range(seg + 1):
            t = a0 + (a1 - a0) * i / seg
            pts.append((off + ca + r * math.cos(t), cb + r * math.sin(t)))

    arc(hw - rb, b0 + rb, rb, -math.pi * 0.5, 0.0)
    arc(hw - rt, b1 - rt, rt, 0.0, math.pi * 0.5)
    arc(-(hw - rt), b1 - rt, rt, math.pi * 0.5, math.pi)
    arc(-(hw - rb), b0 + rb, rb, math.pi, math.pi * 1.5)
    return pts


def loft_y(shell, stations, tag, cap_front=True, cap_back=True, inward=False):
    """Sweep equal-count closed (x, z) sections along y, front (largest y) first.

    Every side quad gets its outward direction from the SECTION winding, so no
    face can flip; `inward` builds a lining whose normals face the cabin."""
    s = -1.0 if inward else 1.0
    for k in range(len(stations) - 1):
        ya, pa = stations[k]
        yb, pb = stations[k + 1]
        n = len(pa)
        for i in range(n):
            j = (i + 1) % n
            dx, dz = pa[j][0] - pa[i][0], pa[j][1] - pa[i][1]
            L = math.hypot(dx, dz) or 1.0
            out = (s * dz / L, 0.0, -s * dx / L)
            q = [(pa[i][0], ya, pa[i][1]), (pa[j][0], ya, pa[j][1]),
                 (pb[j][0], yb, pb[j][1]), (pb[i][0], yb, pb[i][1])]
            if abs(q[0][0] - q[3][0]) < 1e-9 and abs(q[0][2] - q[3][2]) < 1e-9 \
                    and abs(q[1][0] - q[2][0]) < 1e-9 and abs(q[1][2] - q[2][2]) < 1e-9 \
                    and abs(ya - yb) < 1e-9:
                continue
            shell.cap(q, out, tag)
    if cap_front:
        ya, pa = stations[0]
        shell.cap([(p[0], ya, p[1]) for p in pa], (0.0, s, 0.0), tag)
    if cap_back:
        yb, pb = stations[-1]
        shell.cap([(p[0], yb, p[1]) for p in pb], (0.0, -s, 0.0), tag)


def loft_z(shell, stations, tag, cap_bot=True, cap_top=True):
    """Sweep equal-count closed (x, y) sections along z, lowest first."""
    for k in range(len(stations) - 1):
        za, pa = stations[k]
        zb, pb = stations[k + 1]
        n = len(pa)
        for i in range(n):
            j = (i + 1) % n
            dx, dy = pa[j][0] - pa[i][0], pa[j][1] - pa[i][1]
            L = math.hypot(dx, dy) or 1.0
            out = (dy / L, -dx / L, 0.0)
            shell.cap([(pa[i][0], pa[i][1], za), (pa[j][0], pa[j][1], za),
                       (pb[j][0], pb[j][1], zb), (pb[i][0], pb[i][1], zb)], out, tag)
    if cap_bot:
        za, pa = stations[0]
        shell.cap([(p[0], p[1], za) for p in pa], (0.0, 0.0, -1.0), tag)
    if cap_top:
        zb, pb = stations[-1]
        shell.cap([(p[0], p[1], zb) for p in pb], (0.0, 0.0, 1.0), tag)


def annulus(shell, y, outer, inner, outward, tag):
    """Close the gap between two equal-count rings in one y plane."""
    n = len(outer)
    for i in range(n):
        j = (i + 1) % n
        shell.cap([(outer[i][0], y, outer[i][1]), (outer[j][0], y, outer[j][1]),
                   (inner[j][0], y, inner[j][1]), (inner[i][0], y, inner[i][1])],
                  outward, tag)


# ==================================================================== the hull
# (d, hw, belly, roof, bottom radius, top radius). The nose station is a small
# ring rather than a point: a true point makes every nose quad a sliver.
HULL_STATIONS = [
    (0.00, 0.26, 1.55, 1.95, 0.13, 0.13),
    (0.40, 0.66, 1.20, 2.45, 0.28, 0.34),
    (1.00, 1.00, 1.02, 2.95, 0.32, 0.44),
    (1.80, 1.18, 0.96, 3.30, 0.34, 0.52),
    (3.00, 1.22, 0.95, 3.50, 0.32, 0.56),
    (6.00, 1.22, 0.95, Z_ROOF, 0.30, 0.56),
    (10.50, 1.22, 0.95, Z_ROOF, 0.30, 0.56),
    (13.60, 1.22, 0.95, Z_ROOF, 0.30, 0.56),
    (D_RAMP_HINGE, 1.20, 1.02, 3.48, 0.26, 0.50),
]
BAY_STATIONS = [
    (3.90, BAY_HW, Z_FLOOR, Z_CEIL, 0.22, 0.34),
    (D_RAMP_HINGE, BAY_HW, Z_FLOOR, Z_CEIL, 0.22, 0.34),
]


def _sect(row):
    d, hw, b0, b1, rb, rt = row
    return Y(d), rrect(hw, b0, b1, rb, rt)


def hull_section(d):
    """Linearly interpolated hull section parameters at station d."""
    rows = HULL_STATIONS
    if d <= rows[0][0]:
        return rows[0][1:]
    for a, b in zip(rows, rows[1:]):
        if d <= b[0]:
            t = (d - a[0]) / (b[0] - a[0])
            return tuple(a[i + 1] + t * (b[i + 1] - a[i + 1]) for i in range(5))
    return rows[-1][1:]


def skin(d, i, out=0.0):
    """3-D point i of the hull ring at station d, pushed `out` along its own
    outward normal. Every applied panel is placed with this rather than a typed
    coordinate, so nothing can be authored inside the skin."""
    hw, b0, b1, rb, rt = hull_section(d)
    pts = rrect(hw, b0, b1, rb, rt)
    n = len(pts)
    p = pts[i]
    nx = nz = 0.0
    for a, b in ((pts[(i - 1) % n], p), (p, pts[(i + 1) % n])):
        dx, dz = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dz) or 1.0
        nx += dz / L
        nz += -dx / L
    L = math.hypot(nx, nz) or 1.0
    return (p[0] + out * nx / L, Y(d), p[1] + out * nz / L)


def panel(shell, d0, d1, i0, i1, out, tag, step=0.16):
    """A glazing strip over hull ring indices i0..i1 between stations d0..d1,
    riding the skin. Each quad is emitted with the skin's own outward direction
    so a mirrored strip cannot reverse its winding.

    IT MUST BE SUBDIVIDED ALONG d. A single quad spanning 0.9 m of a nose that
    flares from 0.26 m to 1.00 m half-width is a CHORD across that curve, and
    the middle of the chord sits INSIDE the hull: the first pass drew the whole
    cockpit greenhouse and only the few centimetres nearest each end station
    ever emerged, so the nose rendered as bare olive with two dark slivers on
    it. Nothing in the tri count, the coincident probe or the floater probe can
    see that - only a close-up render can."""
    n = max(1, int(math.ceil(abs(d1 - d0) / step)))
    for k in range(n):
        da = d0 + (d1 - d0) * k / n
        db = d0 + (d1 - d0) * (k + 1) / n
        dm = 0.5 * (da + db)
        for i in range(i0, i1):
            q = [skin(da, i, out), skin(da, i + 1, out),
                 skin(db, i + 1, out), skin(db, i, out)]
            c = skin(dm, i, 0.0)
            nrm = Vector(skin(dm, i, 1.0)) - Vector(c)
            shell.cap(q, tuple(nrm), tag)


def build_hull():
    s = Shell()
    # --- outer skin, nose capped, OPEN at the ramp aperture
    loft_y(s, [_sect(r) for r in HULL_STATIONS], "od", cap_front=True, cap_back=False)
    # --- cargo bay lining. Its forward bulkhead faces AFT: it is the only face
    #     of it anyone ever sees, through the aperture.
    loft_y(s, [_sect(r) for r in BAY_STATIONS], "od",
           cap_front=True, cap_back=False, inward=True)
    # --- the aperture rim: one ring joining skin to lining. THIS is the ramp
    #     opening - 2.23 x 1.95 clear against a published cabin of 2.29 x 1.98.
    annulus(s, Y(D_RAMP_HINGE),
            rrect(*HULL_STATIONS[-1][1:]), rrect(*BAY_STATIONS[-1][1:]),
            (0.0, -1.0, 0.0), "od")

    # --- cockpit greenhouse and chin bubbles, both riding the skin -----------
    # Ring indices: 0-2 bottom-right, 3-5 right side up and over, 6-8 top-left
    # down, 9-11 bottom-left. 3..9 is the front/top band the windscreen sits on.
    # i1 is EXCLUSIVE of the last index but each step emits edge (i, i+1), so
    # (3, 8) covers edges 3-4 .. 7-8: five facets, symmetric about the 5-6 edge
    # on the centreline. (3, 9) added edge 8-9 with no mirror and wrapped the
    # greenhouse one facet further down the PORT side only - 0.52 m2 of extra
    # glass on one side of an aircraft that is symmetric to the last vertex, and
    # invisible in every render.
    panel(s, 0.03, 0.80, 3, 8, 0.026, "cglass")     # windscreen, wrapped
    panel(s, 0.24, 0.86, 0, 2, 0.024, "cglass")     # right chin bubble
    panel(s, 0.24, 0.86, 9, 11, 0.024, "cglass")    # left chin bubble
    # Cockpit side lights. The ring carries ONE vertex on each straight side, so
    # a part-height window cannot be expressed as a ring index at all - these
    # are placed on the side plane directly, sampling its half-width per station
    # so they cannot sink into a nose that is still flaring.
    for k in range(4):
        da = 0.86 + 0.25 * k
        db = da + 0.25
        for sgn in (-1.0, 1.0):
            xa = sgn * (hull_section(da)[0] + 0.022)
            xb = sgn * (hull_section(db)[0] + 0.022)
            s.cap([(xa, Y(da), 2.06), (xb, Y(db), 2.06),
                   (xb, Y(db), 2.72), (xa, Y(da), 2.72)], (sgn, 0.0, 0.0), "cglass")

    # --- cabin port lights: five a side, octagonal, proud of the skin ---------
    for d in (5.40, 7.00, 8.60, 10.20, 11.80):
        for sgn in (-1.0, 1.0):
            ring = [(sgn * 1.238,
                     Y(d) + 0.20 * math.cos(TAU * k / 8),
                     2.45 + 0.20 * math.sin(TAU * k / 8)) for k in range(8)]
            s.cap(ring, (sgn, 0.0, 0.0), "wglass")

    # --- sponsons: the fuel pods that make the 3.78 m width -------------------
    sp = Shell()
    xc = (SPONSON_X0 + SPONSON_X1) * 0.5
    xh = (SPONSON_X1 - SPONSON_X0) * 0.5
    sp_rows = [(4.20, 0.55, 0.30), (5.20, 1.00, 1.00),
               (12.60, 1.00, 1.00), (13.90, 0.55, 0.30)]
    st = []
    for d, kx, kz in sp_rows:
        zc = (SPONSON_Z0 + SPONSON_Z1) * 0.5
        zh = (SPONSON_Z1 - SPONSON_Z0) * 0.5 * kz
        st.append((Y(d), rrect(xh * kx, zc - zh, zc + zh, 0.16 * kz, 0.18 * kz,
                               seg=1, off=xc)))
    loft_y(sp, st, "od")
    # Walkway strip along the sponson top. It must PENETRATE the pod: the pod's
    # top-corner arc has already fallen 0.08 m by x 1.86, so a strip sitting at
    # the pod's flat-top height floats over its own outboard half - the floater
    # probe caught exactly that at 0.050 m clear.
    sp.box((1.40, Y(12.30), SPONSON_Z1 - 0.12),
           (1.86, Y(5.60), SPONSON_Z1 - 0.02), "metal")

    # --- landing gear. FOUR legs, no nose wheel: the forward pair is DUAL and
    #     the aft pair SINGLE (museum walkaround, both wheel types visible).
    #     The shipped model has a `Nose_Strut` and `Nose_Wheel_+/-`, which no
    #     Chinook has ever had.
    for d, track, dual in ((D_FWD_GEAR, REAL_TRACK_FWD, True),
                           (D_AFT_GEAR, REAL_TRACK_AFT, False)):
        x = track * 0.5
        sp.box((x - 0.075, Y(d) - 0.095, WHEEL_R - 0.02),
               (x + 0.075, Y(d) + 0.095, SPONSON_Z0 + 0.16), "metal")
        offs = (-0.135, 0.135) if dual else (0.0,)
        for o in offs:
            wheel(sp, x + o, Y(d), 0.075 if dual else 0.100)

    s.merge(sp)
    s.merge(sp.mirrored())

    # --- forward pylon and its mast ------------------------------------------
    # THE TOP OF EACH PYLON IS A FLAT DECK, and that is a floater-probe
    # requirement, not styling: a mast cylinder pushed into a SLOPING skin has
    # every one of its vertices tens of millimetres from any surface, so the
    # probe convicts a mast that is visibly buried. On a flat deck the mast's
    # bottom ring sits 0.02 m under the skin and is provably attached.
    fp = [(1.35, 0.60, 3.10, 3.38, 0.16, 0.14),
          (2.00, 0.66, 3.14, MAST_DECK_F, 0.18, 0.20),
          (2.62, 0.66, 3.18, MAST_DECK_F, 0.18, 0.20),
          (3.55, 0.56, 3.32, 3.74, 0.16, 0.16)]
    loft_y(s, [(Y(d), rrect(hw, b0, b1, rb, rt, seg=1))
               for d, hw, b0, b1, rb, rt in fp], "od")
    cyl(s, (0.0, Y(D_FWD_HUB), MAST_DECK_F - 0.02),
        (0.0, Y(D_FWD_HUB), Z_FWD_ROTOR - 0.06), MAST_R, 8, "metal")

    # --- aft pylon: a fin, lofted in Z so its sweep is one number per slice ---
    ap = [(3.20, 12.55, 16.28, 1.02),
          (4.00, 12.95, D_PYLON_TE, 0.86),
          (4.80, 13.35, D_PYLON_TE, 0.66),
          (MAST_DECK_A, 13.72, 16.05, 0.52)]
    loft_z(s, [(z, rrect(hw, Y(d1), Y(d0), 0.22, 0.22, seg=1))
               for z, d0, d1, hw in ap], "od")
    cyl(s, (0.0, Y(D_AFT_HUB), MAST_DECK_A - 0.02),
        (0.0, Y(D_AFT_HUB), Z_AFT_ROTOR - 0.06), MAST_R, 8, "metal")

    # --- engines, one each side of the aft pylon base -------------------------
    en = Shell()
    eng = [(12.75, 0.22, 3.42, 3.72), (13.30, 0.30, 3.30, 4.06),
           (15.05, 0.28, 3.36, 4.00), (15.55, 0.20, 3.48, 3.86)]
    loft_y(en, [(Y(d), rrect(hw, b0, b1, 0.10, 0.10, seg=1, off=1.00))
                for d, hw, b0, b1 in eng], "metal")
    cyl(en, (1.00, Y(15.42), 3.66), (1.00, Y(16.12), 3.90), 0.19, 8, "soot")
    s.merge(en)
    s.merge(en.mirrored())

    # --- drive-shaft tunnel down the spine, penetrating the roof -------------
    s.box((-0.20, Y(13.10), Z_ROOF - 0.06), (0.20, Y(2.90), Z_ROOF + 0.11), "od")

    # --- THE RAMP, lowered. Hinged at the cabin floor, lip near the ground.
    ca, sa = math.cos(RAMP_ANG), math.sin(RAMP_ANG)
    t = 0.09
    hy, hz = Y(D_RAMP_HINGE), Z_FLOOR
    ly, lz = Y(D_RAMP_LIP), Z_RAMP_LIP
    # the hinge end is pushed 0.12 m INTO the aperture so nothing butts
    hy += 0.12 * ca
    hz += 0.12 * sa
    # LIP FIRST, HINGE SECOND: hexa() winds 0-3 in increasing y, and the lip is
    # the aft (more negative y) end.
    x0, x1 = -RAMP_HW, RAMP_HW
    s.hexa([(x0, ly, lz - t), (x1, ly, lz - t), (x1, hy, hz - t), (x0, hy, hz - t),
            (x0, ly, lz), (x1, ly, lz), (x1, hy, hz), (x0, hy, hz)], "od")
    # The two side rails a stick actually walks between. INSET ALONG THE RAMP AT
    # BOTH ENDS: run flush and the rail's end cap lands on the same plane as the
    # deck's, touching along one edge, and the coincident-face probe convicts the
    # pair - a seam that would z-fight at the lip, which is the one part of this
    # aircraft a player stands next to.
    # ...and inset in x and SUNK into the deck. Run flush and the rail's outer
    # face shares the deck's x=+-1.10 plane while its underside shares the deck's
    # top plane. That coplanarity was invisible to the probe at first only
    # because the flush rail's corner vertices were bit-identical to the deck's,
    # and the probe excludes pairs that share a vertex - the moment the ends were
    # inset it reported seven seams down the ramp.
    iy, iz = 0.06 * ca, 0.06 * sa
    for sgn in (-1.0, 1.0):
        x0, x1 = sorted((sgn * (RAMP_HW - 0.17), sgn * (RAMP_HW - 0.02)))
        s.hexa([(x0, ly + iy, lz + iz - 0.035), (x1, ly + iy, lz + iz - 0.035),
                (x1, hy - iy, hz - iz - 0.035), (x0, hy - iy, hz - iz - 0.035),
                (x0, ly + iy, lz + iz + 0.060), (x1, ly + iy, lz + iz + 0.060),
                (x1, hy - iy, hz - iz + 0.060), (x0, hy - iy, hz - iz + 0.060)], "metal")
    return s


def wheel(shell, x, y, hw, n=6, r=WHEEL_R):
    """One wheel centred on its own hub, spin axis X. Phase tau/4 so a vertex
    lands on the ground line - a 6-gon without it floats the aircraft 0.04 m."""
    PH = TAU * 0.25
    hub = 0.115

    def ring(xx, rr):
        return [(xx, y + rr * math.cos(PH + TAU * i / n),
                 rr * math.sin(PH + TAU * i / n) + r) for i in range(n)]

    op, om = ring(x + hw, r), ring(x - hw, r)
    hp = ring(x + hw - 0.028, hub)
    for i in range(n):
        j = (i + 1) % n
        for A, B, tag in ((om, op, "rubber"), (op, hp, "metal")):
            mid = (Vector(A[i]) + Vector(A[j]) + Vector(B[j]) + Vector(B[i])) / 4.0
            axis = Vector((mid.x, y, r))
            shell.cap([A[i], A[j], B[j], B[i]], tuple(mid - axis), tag)
    shell.cap(hp, (1.0, 0.0, 0.0), "metal")
    shell.cap(om, (-1.0, 0.0, 0.0), "metal")


# ==================================================================== rotors
def build_rotor(clock_deg):
    """One three-blade rotor centred on its own mast, spin axis = local Z.

    helicopter.gd:167-170 calls rotate_y() on this node, and Godot Y is Blender
    Z, so the blades must lie in the object's own XY plane with the origin ON
    the mast. Blade root 0.20 m so it PENETRATES the 0.26 m hub - a root that
    stops short of the hub is a floating island and the probe says so."""
    s = Shell()
    cyl(s, (0.0, 0.0, -0.11), (0.0, 0.0, 0.18), HUB_R, 8, "metal")
    for k in range(3):
        a = math.radians(clock_deg + 120.0 * k)
        U = Vector((math.cos(a), math.sin(a), 0.0))
        C = Vector((-math.sin(a), math.cos(a), 0.0))
        c0, c1 = 0.35, 0.26          # root and tip half-chord
        # BLADE RADIUS is the published diameter / 2, measured to the tip along
        # the span - that is the definition both 18.01 and 29.90 are quoted on,
        # and it makes the fore/aft-clocked blades reproduce 29.90 exactly. The
        # swept circle through the TIP CORNERS is 8 mm larger (sqrt(R^2+c^2)),
        # which is why the diameter check carries a 30 mm band and the
        # rotors-turning check does not.
        u0, u1 = 0.20, ROTOR_R
        t = 0.045
        droop = -0.30                # 1.9 deg of coning; radius is unaffected

        def cor(u, c, w):
            return tuple(U * u + C * c + Vector((0.0, 0.0, w + droop * (u / u1))))

        s.hexa([cor(u0, -c0, -t), cor(u1, -c1, -t), cor(u1, c1, -t), cor(u0, c0, -t),
                cor(u0, -c0, t), cor(u1, -c1, t), cor(u1, c1, t), cor(u0, c0, t)],
               "blade")
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
    b.inputs["Roughness"].default_value = 0.30 if tag in ("cglass", "wglass") else 0.62
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


def empty(name, loc, rz_deg=0.0):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.2
    bpy.context.collection.objects.link(e)
    e.location = loc
    # A SOCKET EMPTY ROTATES ABOUT Z ONLY. glTF maps Blender local -Y onto Godot
    # local +Z, so rz=180 faces the nose and any X/Y euler lays the occupant on
    # his side (universal ledger, Huey v3, 2026-08-08).
    e.rotation_euler = (0.0, 0.0, math.radians(rz_deg))
    return e


def floaters(objs, tol=0.030):
    """Every disconnected lump of geometry must TOUCH something.

    Imported verbatim in behaviour from tools/build_m113_v2.py, where it
    convicted a final-drive housing hung in the void. THE TEST MUST BE
    SYMMETRIC: measuring only my-vertices-to-their-surface convicts every
    correctly PENETRATING detail. An island is attached if EITHER side can
    reach the other. Returns [(label, gap, centroid)]."""
    from mathutils.bvhtree import BVHTree

    islands = []
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
    """Face pairs that share a plane and an area but share no vertex.

    THE LOW-POLY Z-FIGHT: coplanar skins render as dirt in Cycles and z-fight in
    any engine, and backface culling hides the opposite-facing case in Godot,
    which is what makes it the defect that ships. Same probe as the M113's,
    where it found 181 seams in a model whose renders had already been passed."""
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
            if (n.x, n.y, n.z) < (-n.x, -n.y, -n.z):
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
        for poly in (A, B):
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
                                    oa.replace("CH47_", ""), ob_.replace("CH47_", ""),
                                    tuple(round(q, 3) for q in c)),
                                 tuple(round(q / 0.05) for q in c)))
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


# --- the seat contract. seat_system.gd:434-456 prefers REAL seat_* markers
#     found anywhere under the vehicle and only generates FALLBACK_LAYOUTS when
#     one is missing - so shipping these retires the ch47 fallback table, which
#     is presently authored around the OLD model's sideways frame and would put
#     every man outside a correctly-facing hull.
#     yaw: Godot local +Z is the occupant's facing, and that is Blender local
#     -Y, so rz 180 = facing the nose, rz -90 = facing Godot -X = the port side.
#     Every position below is (x, z, STATION AFT OF THE NOSE, yaw) - d, not y.
#     The first pass typed Blender y into the d slot and put both pilots four
#     metres aft of the cockpit, in the middle of the cargo bay, which is why
#     assert_seats() below measures every socket against the cabin envelope
#     instead of trusting the table.
SEAT_PAX_D = (6.20, 7.50, 8.80, 10.10)
SEAT_BENCH_D = (11.60, 12.90, 14.20)
SEATS = ([("seat_pilot_l", -0.55, 1.75, 2.10, 180.0),
          ("seat_pilot_r", 0.55, 1.75, 2.10, 180.0),
          ("seat_gunner_l", -0.90, 1.50, 4.60, -90.0),
          ("seat_gunner_r", 0.90, 1.50, 4.60, 90.0)]
         + [("seat_pax_%d" % (i + 1), -0.86, 1.60, d, 90.0)
            for i, d in enumerate(SEAT_PAX_D)]
         + [("seat_pax_%d" % (i + 5), 0.86, 1.60, d, -90.0)
            for i, d in enumerate(SEAT_PAX_D)]
         + [("seat_bench_%d" % (i + 1), -0.26, 1.60, d, -90.0)
            for i, d in enumerate(SEAT_BENCH_D)]
         + [("seat_bench_%d" % (i + 4), 0.26, 1.60, d, 90.0)
            for i, d in enumerate(SEAT_BENCH_D)])


def assert_seats():
    """Every socket must be INSIDE the space its occupant sits in.

    Cabin seats against the bay lining; the two pilots against the cockpit
    section, which is forward of the bay's own bulkhead and much smaller."""
    for name, x, z, d, yaw in SEATS:
        assert abs(yaw) in (90.0, 180.0) or yaw == 0.0, "%s odd yaw" % name
        if name.startswith("seat_pilot"):
            hw, b0, b1, _rb, _rt = hull_section(d)
            assert 1.4 <= d <= 3.6, "%s at station %.2f is not in the cockpit" % (name, d)
            assert abs(x) < hw - 0.20, "%s x %.2f vs cockpit half-width %.2f" % (name, x, hw)
            assert b0 + 0.30 < z < b1 - 0.60, "%s z %.2f vs section %.2f..%.2f" \
                % (name, z, b0, b1)
            continue
        assert 4.10 <= d <= 15.20, \
            "%s at station %.2f is outside the cargo bay (3.90 .. %.2f)" \
            % (name, d, D_RAMP_HINGE)
        assert abs(x) <= BAY_HW - 0.05, "%s x %.2f vs bay half-width %.2f" % (name, x, BAY_HW)
        assert Z_FLOOR + 0.10 <= z <= Z_CEIL - 0.40, \
            "%s z %.2f vs floor %.2f / ceiling %.2f" % (name, z, Z_FLOOR, Z_CEIL)


def build_col_lower():
    s = Shell()
    s.box((-REAL_FUS_W * 0.5, Y(AIRFRAME_L), 0.0),
          (REAL_FUS_W * 0.5, Y(0.0), 3.60), "metal")
    return s


def build_col_upper():
    s = Shell()
    s.box((-1.06, Y(D_PYLON_TE + 0.05), 3.60), (1.06, Y(12.50), REAL_HEIGHT), "metal")
    return s


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    do_export = "--export" in argv
    render_dir = argv[argv.index("--render") + 1] if "--render" in argv else None

    bpy.ops.wm.read_factory_settings(use_empty=True)

    fus = make_object("Fuselage", build_hull())
    # Blades clocked 60 deg apart between rotors, exactly as a real Chinook
    # interleaves them - and it also puts ONE blade dead ahead and ONE dead
    # astern, so the 29.90 m rotors-turning length is a measurable extreme
    # rather than a function of where the blades happened to be parked.
    front = make_object("FrontRotor", build_rotor(90.0),
                        (0.0, Y(D_FWD_HUB), Z_FWD_ROTOR))
    rear = make_object("RearRotor", build_rotor(270.0),
                       (0.0, Y(D_AFT_HUB), Z_AFT_ROTOR))
    cols = [make_object("CH47_Col_Lower-colonly", build_col_lower()),
            make_object("CH47_Col_Upper-colonly", build_col_upper())]
    for c in cols:
        c.hide_render = True      # a collider in the review render answers the
                                  # wrong question and feels like evidence

    assert_seats()
    for name, x, z, d, yaw in SEATS:
        empty(name, (x, Y(d), z), yaw)

    visible = [fus, front, rear]
    bpy.context.view_layer.update()

    # ---- measure -----------------------------------------------------------
    print("\n--- MESH INVENTORY -------------------------------------------")
    tris = 0
    for ob in visible + cols:
        ob.data.calc_loop_triangles()
        t = len(ob.data.loop_triangles)
        ngons = sum(1 for p in ob.data.polygons if len(p.vertices) > 4)
        used = set()
        for p in ob.data.polygons:
            used.update(p.vertices)
        if not ob.name.endswith("-colonly"):
            tris += t
        print("  %-26s tris %5d verts %5d ngons %d loose %d loc %s"
              % (ob.name, t, len(ob.data.vertices), ngons,
                 len(ob.data.vertices) - len(used),
                 tuple(round(c, 4) for c in ob.location)))

    lo, hi = bounds(visible)
    flo, fhi = bounds([fus])
    rot_r = max(max(math.hypot(v.co.x, v.co.y) for v in o.data.vertices)
                for o in (front, rear))
    print("\n--- MEASURED vs REAL (object space, metres) ------------------")
    for lab, got, real in (
            ("rotor dia", 2 * rot_r, REAL_ROTOR_D),
            ("len turning", hi.y - lo.y, REAL_LEN_TURNING),
            ("hub separation", front.location.y - rear.location.y, HUB_SEP),
            ("fuselage len", fhi.y - flo.y, REAL_FUS_LEN),
            ("fuselage width", fhi.x - flo.x, REAL_FUS_W),
            ("height", hi.z - lo.z, REAL_HEIGHT),
            ("wheelbase", REAL_WHEELBASE, REAL_WHEELBASE),
            ("cabin width", 2 * BAY_HW, REAL_CABIN_W),
            ("cabin height", Z_CEIL - Z_FLOOR, REAL_CABIN_H)):
        print("  %-15s %7.3f  real %6.3f  d %+0.3f  (%+0.1f%%)"
              % (lab, got, real, got - real, 100.0 * (got - real) / real))
    print("  NOTE fuselage len %.3f is nose -> LOWERED RAMP LIP; the published"
          % (fhi.y - flo.y))
    print("       15.47 m is nose -> ramp hinge (%.3f here) and the pylon"
          % D_RAMP_HINGE)
    print("       overhangs it to %.2f m." % D_PYLON_TE)
    print("  bbox lo %s hi %s" % (tuple(round(c, 3) for c in lo),
                                  tuple(round(c, 3) for c in hi)))
    print("  Fuselage bbox lo %s hi %s" % (tuple(round(c, 3) for c in flo),
                                           tuple(round(c, 3) for c in fhi)))
    print("  Fuselage AABB centre (%.4f, *, %.4f) -> helicopter.gd:82 recentre is INERT"
          % ((flo.x + fhi.x) * 0.5, (flo.z + fhi.z) * 0.5))
    print("  TOTAL VISIBLE TRIS %d   collider tris %d"
          % (tris, sum(len(c.data.loop_triangles) for c in cols)))
    rt = sum(len(o.data.loop_triangles) for o in (front, rear))
    print("  airframe %d = %.1f%%   rotors %d = %.1f%%"
          % (tris - rt, 100.0 * (tris - rt) / tris, rt, 100.0 * rt / tris))

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

    # NOTHING ON THIS AIRFRAME IS DELIBERATELY ASYMMETRIC, so say so and check
    # it. A one-facet asymmetry in the cockpit greenhouse (an off-by-one on a
    # ring index) survived five renders and every other probe in this file; a
    # bounding box cannot see it, because the extremes were still symmetric.
    print("\n  MIRROR SYMMETRY")
    for ob in visible:
        pts = {(round(v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4))
               for v in ob.data.vertices}
        odd = [p for p in pts if (round(-p[0], 4), p[1], p[2]) not in pts]
        print("    %-12s %5d verts, %d without a mirror" % (ob.name, len(pts), len(odd)))
        assert not odd, "%s is not mirror-symmetric about x=0: %s" % (ob.name, odd[:6])

    coin = coincident(visible)
    print("  COINCIDENT-FACE PROBE: %d seam%s %s"
          % (len(coin), "" if len(coin) == 1 else "s", coin[:14]))
    assert not coin, "coincident faces will z-fight at %d places: %s" % (len(coin), coin)

    fl = floaters(visible)
    print("  FLOATER PROBE over every visible mesh: %s" % ("none" if not fl else fl))
    assert not fl, "geometry attached to NOTHING: %s" % fl

    assert abs(2 * rot_r - REAL_ROTOR_D) < 0.03, "rotor diameter %.4f" % (2 * rot_r)
    assert abs((hi.y - lo.y) - REAL_LEN_TURNING) < 1e-3, \
        "rotors-turning length %.4f" % (hi.y - lo.y)
    assert abs(lo.z) < 1e-6, "the wheels must touch z=0: ground line is %+0.4f" % lo.z
    assert abs(hi.z - REAL_HEIGHT) < 1e-3, "height %.4f" % hi.z
    assert abs(lo.x + hi.x) < 1e-6, "not laterally symmetric (%.5f)" % (lo.x + hi.x)
    assert abs(fhi.x - flo.x - REAL_FUS_W) < 1e-6, \
        "fuselage width %.4f" % (fhi.x - flo.x)
    assert abs(flo.y + fhi.y) < 1e-6, \
        "Fuselage is not centred in y (%.5f) - helicopter.gd would shift the hull" \
        % (flo.y + fhi.y)
    assert front.location.y > 0 > rear.location.y, "rotors straddle the origin"
    assert front.location.z < rear.location.z, "the AFT rotor sits HIGHER"
    for ob in visible + cols:
        assert all(abs(c - 1.0) < 1e-6 for c in ob.scale), "%s unapplied scale" % ob.name
        assert all(abs(c) < 1e-6 for c in ob.rotation_euler), "%s carries rotation" % ob.name
    for ob in [fus] + cols:
        assert ob.location.length < 1e-6, "%s must be at identity" % ob.name
    print("  materials: %d -> %s" % (len(bpy.data.materials),
                                     sorted(m.name for m in bpy.data.materials)))
    assert len(bpy.data.materials) <= 8, "%d materials" % len(bpy.data.materials)
    for m in bpy.data.materials:
        assert m.node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value == 0.0
    assert not [i for i in bpy.data.images if i.name != "Render Result"], "textures leaked in"
    print("  QC PASS")

    if render_dir:
        do_render(render_dir, flo, fhi)

    if do_export:
        for ob in list(bpy.data.objects):
            if ob.type in {"CAMERA", "LIGHT"} or ob.name.startswith("_datum"):
                bpy.data.objects.remove(ob, do_unlink=True)
        blend = os.path.join(OUT_DIR, "ch47_chinook_v2.blend")
        glb = os.path.join(OUT_DIR, "ch47_chinook_v2.glb")
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
        for f in os.listdir(OUT_DIR):
            if f.startswith("ch47_chinook_v2") and f.endswith(".blend1"):
                os.remove(os.path.join(OUT_DIR, f))
                print("removed stray %s" % f)


# ====================================================================== renders
# (name, azimuth deg, elevation deg, pull-back multiple of the FUSELAGE span).
# Framed on the fuselage, never the 29.9 m rotor envelope: a global distance
# sized to the rotors renders a speck.
#
# k is a multiple of the fuselage span (17.75 m). With a 50 mm lens the frame is
# 0.69 x D wide, so a side elevation needs k >= 1.45 just to fit the airframe -
# the first pass at 1.30 cropped the nose AND the ramp off the only view that
# shows the profile. Each view carries its own k: the plan needs the most
# pull-back because a 16:10 frame puts the length on the SHORT axis.
VIEWS = [("side", 180.0, 6.0, 1.80), ("front", 90.0, 4.0, 1.25),
         ("threequarter", 44.0, 14.0, 1.75), ("rear_quarter", 232.0, 12.0, 1.55),
         ("top", 268.0, 78.0, 4.50)]

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
    skin_m = _flat("_datum_skin", (0.62, 0.47, 0.36))
    cloth = _flat("_datum_cloth", (0.28, 0.31, 0.22))
    x = 2.75
    y = Y(11.0)
    parts = [("_datum_legs", (x - 0.17, y - 0.13, 0.00), (x + 0.17, y + 0.13, 0.86), cloth),
             ("_datum_torso", (x - 0.21, y - 0.15, 0.86), (x + 0.21, y + 0.15, 1.44), cloth),
             ("_datum_head", (x - 0.10, y - 0.10, 1.50), (x + 0.10, y + 0.10, DATUM_H), skin_m),
             ("_datum_neck", (x - 0.06, y - 0.06, 1.44), (x + 0.06, y + 0.06, 1.50), skin_m)]
    for n, a, b, m in parts:
        _prim(n, a, b, m)
    _prim("_datum_fwd", (-0.60, Y(-1.6), 0.0), (0.60, Y(-2.2), 0.12),
          _flat("_datum_green", (0.10, 0.62, 0.14)))
    _prim("_datum_aft", (-0.60, Y(AIRFRAME_L + 2.2), 0.0), (0.60, Y(AIRFRAME_L + 1.6), 0.12),
          _flat("_datum_red", (0.68, 0.09, 0.08)))
    _prim("_datum_ground", (-9.0, Y(AIRFRAME_L + 4.0), -0.014), (9.0, Y(-4.0), 0.0),
          _flat("_datum_dirt", (0.31, 0.28, 0.21)))


def do_render(out_dir, flo, fhi):
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 24
    sc.cycles.use_denoising = True
    sc.cycles.device = "CPU"
    sc.render.resolution_x, sc.render.resolution_y = 1100, 660
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
    cam.data.lens = 50.0
    bpy.context.collection.objects.link(cam)
    sc.camera = cam

    tgt = Vector(((flo.x + fhi.x) * 0.5, (flo.y + fhi.y) * 0.5, 2.4))
    span = max(fhi.x - flo.x, fhi.y - flo.y, fhi.z - flo.z)
    for name, az, el, k in VIEWS:
        a, e = math.radians(az), math.radians(el)
        cam.location = tgt + Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a),
                                     math.sin(e))) * (span * k)
        cam.rotation_euler = (tgt - Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(out_dir, "ch47v2_%s.png" % name)
        bpy.ops.render.render(write_still=True)
        print("RENDER %s" % sc.render.filepath)

    # The cockpit is the whole front-end read and it is 2 m of a 30 m model, so
    # it gets its own shot: at the full-airframe distances the greenhouse is
    # about eight pixels and a review of it would be a guess.
    for name, tgt, az, el, dist in (
            ("nose", Vector((0.0, Y(0.9), 2.10)), 48.0, 8.0, 5.6),
            ("ramp", Vector((0.0, Y(16.6), 1.10)), 205.0, 12.0, 7.5)):
        a, e = math.radians(az), math.radians(el)
        cam.location = tgt + Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a),
                                     math.sin(e))) * dist
        cam.rotation_euler = (tgt - Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(out_dir, "ch47v2_%s.png" % name)
        bpy.ops.render.render(write_still=True)
        print("RENDER %s" % sc.render.filepath)

    add_datum()
    tgt = Vector((0.0, Y(9.0), 2.10))
    a, e = math.radians(38.0), math.radians(5.0)
    cam.location = tgt + Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a),
                                 math.sin(e))) * 30.0
    cam.rotation_euler = (tgt - Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(out_dir, "ch47v2_datum.png")
    bpy.ops.render.render(write_still=True)
    print("RENDER %s" % sc.render.filepath)


if __name__ == "__main__":
    main()
