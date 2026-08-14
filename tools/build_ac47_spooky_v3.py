"""Build the AC-47D "Spooky" v3 airframe FROM PURE REFERENCE and export it.

    blender -b --factory-startup --python tools/build_ac47_spooky_v3.py -- [--export] [--render DIR]

Nothing is imported. `ac47_spooky.glb` (his) and `ac47_spooky_v2.glb` (the
donor-derived variant) are never opened by this script; the verifier md5s both.

Frame contract, identical to the rest of the fleet: nose at Blender +Y (Godot -Z)
at identity, +Z up, real metres, origin at the centre of mass (x centreline,
y wing quarter chord, z fuselage centreline at the wing).

Every station is measured off the NASA C-47 3-view line drawing (see the
2026-08-14 reference study in production/blender_notes.md). Design coordinates
are `s` = metres aft of the nose and `z` = metres from the CABIN WINDOW LINE,
which is the one datum the side and front views agree on. Longitudinal stations
are scaled by KS so the total length lands on the fleet's 19.43 m; the drawing
itself is 19.634 m, which is Wikipedia's AC-47D figure.

The two propellers, `AC47_Prop_L` / `AC47_Prop_R`, are the only nodes whose names
trip rotor_spin.gd:25 PROP_HINTS. Each has its origin ON ITS HUB at identity
rotation, so its Godot local Z is the thrust line - the axis rotor_spin.gd:76
turns. A slotted `prop_spin` action also ships, because the one consumer,
spectre_gunship.gd:131-134, plays that clip by name and never attaches RotorSpin.
"""

import bpy, bmesh, math, os, sys
from mathutils import Vector

TAU = math.tau
PROJ = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT_DIR = os.path.join(PROJ, "assets", "us", "aircraft")

# ---------------------------------------------------------------- real numbers
REAL_LENGTH = 19.43          # C-47B / DC-3, nose to rudder trailing edge
REAL_SPAN = 29.11
REAL_PROP_D = 3.51           # Hamilton Standard 23E50, 11 ft 6 in, three blades
REAL_STAB_SPAN = 8.54        # measured off the plan view at 63.00 px/m
REAL_FUSE_W = 2.55
REAL_FUSE_H = 2.905
REAL_WING_AREA = 91.87       # 988.9 sq ft, gross
REAL_CARGO_DOOR = (2.16, 1.73)   # 85 in x 68 in

DRAWN_LENGTH = 19.634        # what the NASA drawing is actually drawn to
KS = REAL_LENGTH / DRAWN_LENGTH  # 0.98961 - longitudinal correction

# ------------------------------------------------------------- design geometry
NSIDE = 16                   # fuselage ring sides
WING_LE_ROOT = 4.87          # station of the wing leading edge at the centreline
WING_TE_ROOT = 9.24
WING_ROOT_CHORD = WING_TE_ROOT - WING_LE_ROOT
WING_PLANE_Z = -0.85         # chord plane at the root, from the window line
CENTRE_SECTION = 3.66        # half-span of the straight, unswept centre section
LE_SWEEP = math.radians(14.5)
DIHEDRAL = math.radians(5.4)
HALF_SPAN = REAL_SPAN * 0.5

NACELLE_X = 2.82
THRUST_Z = -1.49
PROP_S = 2.75
COWL_D = 1.35

WINDOW_S0, WINDOW_PITCH, WINDOW_N = 4.41, 1.015, 7
WINDOW_SIZE = 0.46
DOOR_S0, DOOR_S1 = 10.33, 12.49
DOOR_Z0 = -1.20
DOOR_Z1 = DOOR_Z0 + REAL_CARGO_DOOR[1]

# Guns: windows 5 and 6 (Wikipedia) == the last two windows aft of the port wing
# (theAviationist). Both descriptions resolve to the same pair on the drawing's
# window ladder. The third fires from the forward half of the cargo door.
GUN_S = (WINDOW_S0 + 4 * WINDOW_PITCH, WINDOW_S0 + 5 * WINDOW_PITCH, 10.90)
GUN_Z = 0.0                  # on the window line - the guns ARE in the windows
GUN_DEPRESS = math.radians(12.0)
GUN_OUT = 0.55               # barrel cluster protrusion beyond the skin
GUN_R = 0.075

WHEEL_S, WHEEL_Z = 4.85, -2.28
WHEEL_D, WHEEL_W = 1.14, 0.36
TAILWHEEL_S, TAILWHEEL_Z, TAILWHEEL_D = 18.35, -0.72, 0.42

SPIN_FRAMES = 8              # 8 frames at 24 fps = 3.0 rev/s ~ rotor_spin PROP_RPS

# Origin: wing quarter chord, fuselage centreline at the wing.
QC_S = WING_LE_ROOT + 0.25 * WING_ROOT_CHORD
NOSE_Y = QC_S * KS
COM_Z = -0.2375              # (crown + keel) / 2 at the wing station


def Y(s):
    """Design station (m aft of the nose) -> Blender y."""
    return NOSE_Y - s * KS


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


def ring(n, s, cx, cz, hw, up, dn):
    """Elliptical ring in the x-z plane at station s, different upper/lower radii."""
    pts = []
    y = Y(s)
    for i in range(n):
        a = TAU * i / n
        sa, ca = math.sin(a), math.cos(a)
        pts.append((cx + hw * ca, y, cz + (up if sa >= 0.0 else dn) * sa))
    return pts


def bridge(shell, n, a0, b0, tag):
    for i in range(n):
        shell.face((a0 + i, a0 + (i + 1) % n, b0 + (i + 1) % n, b0 + i), tag)


def fan_cap(shell, base, n, tag):
    c = [0.0, 0.0, 0.0]
    for i in range(n):
        p = shell.v[base + i]
        for k in range(3):
            c[k] += p[k] / n
    ci = shell.add_verts([tuple(c)])
    for i in range(n):
        shell.face((ci, base + i, base + (i + 1) % n), tag)


def loft(shell, rings, tag, cap_first=True, cap_last=True):
    n = len(rings[0])
    bases = [shell.add_verts(r) for r in rings]
    for k in range(len(rings) - 1):
        bridge(shell, n, bases[k], bases[k + 1], tag)
    if cap_first:
        fan_cap(shell, bases[0], n, tag)
    if cap_last:
        fan_cap(shell, bases[-1], n, tag)
    return bases


def revolve(shell, profile, n, axis_x, axis_z, tag, ymap=Y):
    """Body of revolution about a line parallel to +Y. profile = [(s, r), ...].
    `ymap` converts the profile's first coordinate to a Blender y; pass
    `lambda v: v` when building in an object's own LOCAL space (a propeller),
    or the station mapping silently throws the part metres up the fuselage."""
    kinds = []
    for s, r in profile:
        if r <= 1e-5:
            kinds.append(("pt", shell.add_verts([(axis_x, ymap(s), axis_z)])))
        else:
            kinds.append(("ring", shell.add_verts(
                [(axis_x + r * math.cos(TAU * i / n), ymap(s),
                  axis_z + r * math.sin(TAU * i / n)) for i in range(n)])))
    for k in range(len(kinds) - 1):
        (ta, a), (tb, b) = kinds[k], kinds[k + 1]
        if ta == "ring" and tb == "ring":
            bridge(shell, n, a, b, tag)
        elif ta == "pt":
            for i in range(n):
                shell.face((a, b + i, b + (i + 1) % n), tag)
        else:
            for i in range(n):
                shell.face((b, a + (i + 1) % n, a + i), tag)


# NACA 2215-ish at the root, thinning outboard. fc = fraction of chord aft of the
# LE, ft = fraction of the thickness parameter.
CAMBER = [(0.00, 0.00), (0.22, 0.52), (0.62, 0.36),
          (1.00, 0.00), (0.62, -0.20), (0.22, -0.36)]
SYMMET = [(0.00, 0.00), (0.22, 0.46), (0.62, 0.32),
          (1.00, 0.00), (0.62, -0.32), (0.22, -0.46)]


def foil(le, chord, thick, span_at, plane, along_x, sym=False):
    """Six-point aerofoil. Chord runs aft from the LE station (toward -Y)."""
    pts = []
    for fc, ft in (SYMMET if sym else CAMBER):
        y = Y(le + chord * fc)
        t = plane + thick * ft
        pts.append((span_at, y, t) if along_x else (t, y, span_at))
    return pts


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
    """Closed capped cylinder between two arbitrary points, wound outward."""
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


# ================================================================ measured body
# (station, crown z, keel z, half width) - all off the de-rotated side view and
# the plan view. The crown apex at s 3.35 is the cockpit; the taper aft of the
# wing is almost entirely in the KEEL, which is the C-47's profile signature.
FUSE_PROFILE = [
    (0.00, -0.39, -0.39, 0.000),
    (0.30,  0.00, -0.76, 0.340),
    (0.60,  0.20, -0.98, 0.570),
    (1.00,  0.37, -1.11, 0.720),
    (1.50,  0.82, -1.24, 0.870),
    (2.00,  1.08, -1.36, 0.990),
    (2.50,  1.17, -1.45, 1.090),
    (3.00,  1.28, -1.52, 1.145),
    (3.35,  1.38, -1.56, 1.170),
    (4.00,  1.27, -1.62, 1.200),
    (4.50,  1.235, -1.655, 1.220),
    (5.50,  1.225, -1.700, 1.250),
    (6.50,  1.205, -1.725, 1.260),
    (7.50,  1.185, -1.740, 1.270),
    (8.50,  1.165, -1.740, 1.275),
    (9.50,  1.145, -1.725, 1.275),
    (10.50, 1.125, -1.690, 1.270),
    (11.50, 1.100, -1.630, 1.250),
    (12.50, 1.075, -1.550, 1.220),
    (13.50, 1.050, -1.440, 1.135),
    (14.50, 1.040, -1.300, 1.050),
    (15.50, 1.030, -1.130, 0.940),
    (16.50, 1.015, -0.930, 0.800),
    (17.50, 0.980, -0.720, 0.620),
    (18.50, 0.900, -0.490, 0.410),
    (19.30, 0.760, -0.300, 0.190),
    (19.634, 0.620, -0.200, 0.070),
]

FUSE_RINGS = [0.14, 0.45, 0.90, 1.45, 2.05, 2.65, 3.20, 3.70, 4.35, 5.20, 6.20,
              7.30, 8.50, 9.70, 10.90, 12.10, 13.30, 14.50, 15.70, 16.90, 18.10,
              19.10, 19.634]


def fuse_at(s):
    """(crown, keel, half-width) interpolated from the measured profile."""
    tab = FUSE_PROFILE
    if s <= tab[0][0]:
        return tab[0][1], tab[0][2], tab[0][3]
    if s >= tab[-1][0]:
        return tab[-1][1], tab[-1][2], tab[-1][3]
    for i in range(len(tab) - 1):
        a, b = tab[i], tab[i + 1]
        if a[0] <= s <= b[0]:
            u = (s - a[0]) / (b[0] - a[0])
            return (a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u,
                    a[3] + (b[3] - a[3]) * u)
    raise AssertionError(s)


def fuse_ring(s):
    top, bot, hw = fuse_at(s)
    cz = (top + bot) * 0.5
    return ring(NSIDE, s, 0.0, cz, hw, top - cz, cz - bot)


def skin_x(s, z):
    """|x| of the ANALYTIC fuselage surface at (station, height). Exact - this
    build owns the surface, so nothing has to be ray-cast off a faceted donor."""
    top, bot, hw = fuse_at(s)
    cz = (top + bot) * 0.5
    r = (top - cz) if z >= cz else (cz - bot)
    t = (z - cz) / r
    if abs(t) >= 1.0:
        return 0.0
    return hw * math.sqrt(1.0 - t * t)


# Any decal vertex placed at skin_x + DECAL_LIFT is outside the analytic surface,
# and the faceted mesh is everywhere INSIDE that surface, so it cannot sink. The
# v2 build had to ray-cast his hull and then fight a per-row sagitta for this.
DECAL_LIFT = 0.030


# ==================================================================== the wing
def wing_le(x):
    return WING_LE_ROOT + max(0.0, abs(x) - CENTRE_SECTION) * math.tan(LE_SWEEP)


def wing_z(x):
    return WING_PLANE_Z + max(0.0, abs(x) - CENTRE_SECTION) * math.tan(DIHEDRAL)


# (half-span, LE station, chord, t/c). Outboard of 13 m the TE cuts forward to
# round the tip off; inboard the TE is dead straight, as the drawing shows.
# Stations every 1 m outboard rather than every 2: the camo is assigned PER FACE,
# so the spanwise station pitch sets the smallest paint blob the wing can carry.
# At a 2 m pitch the top view read as a row of rectangles.
WING_STATIONS = []
for _x in (0.0, CENTRE_SECTION, 4.4, 5.2, 6.1, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0):
    _le = wing_le(_x)
    WING_STATIONS.append((_x, _le, WING_TE_ROOT - _le, 0.15 - 0.055 * (_x / 13.0)))
WING_STATIONS += [
    (14.00, 7.560, 1.460, 0.090),
    (14.30, 7.760, 1.030, 0.075),
    (HALF_SPAN, 8.050, 0.400, 0.060),
]


def wing_at(x):
    ax = abs(x)
    for i in range(len(WING_STATIONS) - 1):
        x0, l0, c0, t0 = WING_STATIONS[i]
        x1, l1, c1, t1 = WING_STATIONS[i + 1]
        if x0 - 1e-6 <= ax <= x1 + 1e-6:
            u = (ax - x0) / (x1 - x0)
            return (l0 + (l1 - l0) * u, c0 + (c1 - c0) * u,
                    t0 + (t1 - t0) * u, wing_z(ax))
    x1, l1, c1, t1 = WING_STATIONS[-1]
    return l1, c1, t1, wing_z(x1)


def wing_skin_z(x, up, bias=0.020):
    """Wing surface height at ~52% chord, where the insignia sits."""
    le, ch, tc, pz = wing_at(x)
    th = tc * ch / 0.88
    return pz + (th * 0.36 + bias if up else -th * 0.20 - bias)


# ============================================================== the nacelles
# (station, centre z, half width, upper radius, lower radius). The bottom
# deepens aft because the main wheel retracts into it.
NACELLE = [
    (2.95, -1.490, 0.600, 0.600, 0.600),
    (3.20, -1.490, 0.675, 0.675, 0.675),
    (3.70, -1.490, 0.690, 0.650, 0.790),
    (4.30, -1.510, 0.685, 0.615, 0.900),
    (4.90, -1.540, 0.670, 0.585, 0.990),
    (5.50, -1.550, 0.560, 0.545, 0.980),
    (6.05, -1.520, 0.390, 0.410, 0.760),
    (6.50, -1.470, 0.150, 0.170, 0.330),
]

# (station, LE station, chord, thickness) for the fin, keyed on height above the
# window line. The lowest section is buried in the tail cone so the dorsal
# fillet emerges from the skin instead of being modelled as its own part.
# The leading edge is taken from where the side view's upper silhouette leaves
# the crown: (16.00, 1.58) (16.60, 2.54) (17.20, 3.36) (17.75, 3.58). An earlier
# pass raked it 52 deg from vertical instead of 34 and turned a modest C-47 fin
# into a shark fin - the same error the A-1 build called its biggest.
FIN = [
    (1.05, 13.20, 6.15, 0.30),
    (1.60, 16.02, 3.36, 0.27),
    (2.10, 16.32, 3.06, 0.23),
    (2.60, 16.62, 2.76, 0.19),
    (3.10, 16.98, 2.38, 0.15),
    (3.40, 17.30, 2.00, 0.10),
    (3.58, 17.75, 1.45, 0.05),
]

# The wing root fillet, sized off the plan view: the outline there reads 1.468 m
# half-width at s 8.5-9.5 against a 1.275 m fuselage, so the fairing stands
# 0.19 m proud of the skin. (station, top of the fillet on the flank, outboard
# extent, height of its outboard edge). A DC-3 without this reads as a wing
# jammed through a tube.
FILLET = [
    (4.60, -0.560, 1.330, -0.582),
    (6.00, -0.420, 1.410, -0.582),
    (7.50, -0.270, 1.460, -0.582),
    (9.24, -0.110, 1.470, -0.582),
    (10.40, -0.360, 1.380, -0.640),
    (11.60, -0.780, 1.240, -0.760),
]

STAB = [
    (0.00, 16.45, 2.93, 0.30, -0.060),
    (1.50, 16.72, 2.66, 0.26, -0.008),
    (3.00, 17.35, 2.03, 0.20, +0.045),
    (4.00, 17.90, 1.24, 0.13, +0.080),
    (4.27, 18.30, 0.75, 0.07, +0.089),
]


# ================================================================ the airframe
def build_airframe():
    s = Shell()

    # ---- fuselage: one continuous loft. The nose closes to a POINT at s 0, not
    # to a fan cap on the first ring - a fan cap sits at that ring's own station
    # and quietly costs 0.14 m of overall length.
    bases = loft(s, [fuse_ring(st) for st in FUSE_RINGS], "skin", cap_first=False)
    top0, bot0, _ = fuse_at(0.0)
    tip = s.add_verts([(0.0, Y(0.0), (top0 + bot0) * 0.5)])
    for i in range(NSIDE):
        s.face((tip, bases[0] + (i + 1) % NSIDE, bases[0] + i), "skin")

    # ---- wing: ONE continuous loft tip to tip THROUGH the fuselage. Two
    # mirrored lofts would each own a copy of the x = 0 root section, which is
    # 7 duplicate vertices per surface and two buried caps for nothing.
    secs = []
    for x, le, ch, tc in reversed(WING_STATIONS[1:]):
        secs.append(foil(le, ch, tc * ch / 0.88, -x, wing_z(x), True))
    for x, le, ch, tc in WING_STATIONS:
        secs.append(foil(le, ch, tc * ch / 0.88, x, wing_z(x), True))
    loft(s, secs, "skin")

    # ---- nacelles, slung under the wing and below the fuselage centreline
    for side in (1.0, -1.0):
        cx = side * NACELLE_X
        # reuse the loft's own first ring as the cowl lip. Building a second
        # coincident ring leaves 12 duplicate verts and 24 boundary edges per
        # nacelle, which the QC gate reports as doubles + non-manifold.
        bases = loft(s, [ring(12, st, cx, cz, hw, up, dn)
                         for st, cz, hw, up, dn in NACELLE], "skin",
                     cap_first=False, cap_last=True)
        # cowl inlet: an annulus round the hub, then a recessed dark duct
        lip = bases[0]
        inner = s.add_verts([(cx + (s.v[lip + i][0] - cx) * 0.52, s.v[lip + i][1],
                              THRUST_Z + (s.v[lip + i][2] - THRUST_Z) * 0.52)
                             for i in range(12)])
        bridge(s, 12, inner, lip, "skin")
        duct = s.add_verts([(cx + (s.v[lip + i][0] - cx) * 0.44, Y(3.35),
                             THRUST_Z + (s.v[lip + i][2] - THRUST_Z) * 0.44)
                            for i in range(12)])
        bridge(s, 12, duct, inner, "dark")
        fan_cap(s, duct, 12, "dark")
        # exhaust collector, low and outboard - the walkaround's most obvious
        # nacelle detail after the cowl ring
        box(s, (cx + side * 0.52, Y(4.55), -2.10), (0.16, 1.10, 0.20), "dark")

    # ---- wing root fillet: a closed triangular-section fairing in the corner
    # between the flank and the wing upper surface. Closed sections keep the
    # airframe manifold, and only the outer face of each is ever visible.
    for sidex in (1.0, -1.0):
        secs = []
        for st, zh, xw, zw in FILLET:
            a = (sidex * skin_x(st, zh), Y(st), zh)
            b = (sidex * xw, Y(st), zw)
            c = (sidex * skin_x(st, zw), Y(st), zw)
            secs.append([a, b, c] if sidex > 0 else [a, c, b])
        loft(s, secs, "skin")

    # ---- vertical fin with its dorsal fillet buried in the tail cone
    loft(s, [foil(le, ch, th, z, 0.0, False, sym=True) for z, le, ch, th in FIN],
         "skin")

    # ---- tailplane, one loft tip to tip for the same reason
    stab = [foil(le, ch, th, -x, z, True, sym=True)
            for x, le, ch, th, z in reversed(STAB[1:])]
    stab += [foil(le, ch, th, x, z, True, sym=True)
             for x, le, ch, th, z in STAB]
    loft(s, stab, "skin")
    return s


def build_glazing():
    """Cockpit glazing as a ribbon lying ON the fuselage surface. The C-47's
    windscreen wraps INTO the nose contour and carries right over the
    centreline - it is not a greenhouse sitting on the spine."""
    s = Shell()
    lift = 0.014

    def band(stations, a0, a1, steps):
        rows = []
        for st in stations:
            top, bot, hw = fuse_at(st)
            cz = (top + bot) * 0.5
            row = []
            for k in range(steps + 1):
                a = math.radians(a0 + (a1 - a0) * k / steps)
                sa, ca = math.sin(a), math.cos(a)
                r = (top - cz) if sa >= 0 else (cz - bot)
                row.append(((hw + lift) * ca, Y(st), cz + (r + lift) * sa))
            rows.append(s.add_verts(row))
        for i in range(len(rows) - 1):
            for k in range(steps):
                s.face((rows[i] + k, rows[i] + k + 1,
                        rows[i + 1] + k + 1, rows[i + 1] + k), "glass")

    band([1.85, 2.20, 2.55], 32.0, 148.0, 8)      # windscreen, over the top
    band([2.55, 3.05, 3.55], 22.0, 58.0, 3)       # starboard side windows
    band([2.55, 3.05, 3.55], 122.0, 158.0, 3)     # port side windows
    return s


def flat_panel(shell, side, s0, s1, z0, z1, ns, nz, tag):
    """A quad ribbon on the fuselage flank. Every vertex samples the ANALYTIC
    skin at its own station and height and is lifted clear of it, so a panel
    cannot sink into a facet the way a chorded quad does on a curved flank."""
    rows = []
    for i in range(ns + 1):
        st = s0 + (s1 - s0) * i / ns
        row = []
        for k in range(nz + 1):
            z = z0 + (z1 - z0) * k / nz
            row.append((side * (skin_x(st, z) + DECAL_LIFT), Y(st), z))
        rows.append(shell.add_verts(row))
    for i in range(ns):
        for k in range(nz):
            q = (rows[i] + k, rows[i] + k + 1, rows[i + 1] + k + 1, rows[i + 1] + k)
            # wound so the normal faces OUTBOARD on whichever side it sits
            shell.face(q if side > 0 else tuple(reversed(q)), tag)


def build_windows():
    """Cabin windows, both sides. On the port side windows 5 and 6 are the gun
    ports and window 7 is inside the cargo door aperture."""
    s = Shell()
    h = WINDOW_SIZE * 0.5
    for k in range(WINDOW_N):
        st = WINDOW_S0 + k * WINDOW_PITCH
        for side in (1.0, -1.0):
            port_gun = (side < 0 and k in (4, 5))
            if side < 0 and k == 6:
                continue                       # swallowed by the cargo door
            g = 0.06 if port_gun else 0.0      # gun ports are cut a touch larger
            flat_panel(s, side, st - h - g, st + h + g, -h - g, h + g, 2, 2,
                       "dark")
    return s


def build_port_side():
    """The two-piece cargo door - port only, and the one thing on this aeroplane
    that is not symmetric besides the battery."""
    s = Shell()
    split = DOOR_S0 + (DOOR_S1 - DOOR_S0) / 3.0
    flat_panel(s, -1.0, DOOR_S0, split - 0.03, DOOR_Z0, DOOR_Z1, 1, 3, "dark")
    flat_panel(s, -1.0, split + 0.03, DOOR_S1, DOOR_Z0, DOOR_Z1, 2, 3, "dark")
    return s


def build_guns():
    """Three 7.62 mm miniguns out the port side, depressed 12 deg so the pylon
    turn puts the beaten zone under the left wing."""
    s = Shell()
    muzzles = []
    d = Vector((-math.cos(GUN_DEPRESS), 0.0, -math.sin(GUN_DEPRESS)))
    for st in GUN_S:
        p = Vector((-skin_x(st, GUN_Z), Y(st), GUN_Z))
        box(s, tuple(p + d * 0.10), (0.30, 0.30, 0.26), "dark")
        tube(s, p + d * (-0.16), p + d * GUN_OUT, GUN_R, GUN_R * 0.80, 6, "dark")
        muzzles.append((p + d * GUN_OUT, d.copy()))
    return s, muzzles


def build_gear():
    """Main wheels half exposed under the nacelles - a DC-3 signature from every
    angle below the horizon - plus the tailwheel."""
    s = Shell()
    for side in (1.0, -1.0):
        x = side * NACELLE_X
        tube(s, (x - WHEEL_W * 0.5, Y(WHEEL_S), WHEEL_Z),
             (x + WHEEL_W * 0.5, Y(WHEEL_S), WHEEL_Z),
             WHEEL_D * 0.5, WHEEL_D * 0.5, 10, "tyre")
    tube(s, (-0.09, Y(TAILWHEEL_S), TAILWHEEL_Z),
         (0.09, Y(TAILWHEEL_S), TAILWHEEL_Z),
         TAILWHEEL_D * 0.5, TAILWHEEL_D * 0.5, 8, "tyre")
    return s


def build_markings():
    """One star-and-bar on the upper PORT wing - where the real one goes. Every
    vertex samples the wing skin: a flat decal spanning the dihedral crank
    buries its outboard bar inside the wing."""
    s = Shell()
    x0 = -8.60
    le, ch, _, _ = wing_at(x0)
    cs = le + ch * 0.50
    r_out, r_in = 0.62, 0.255
    pts = []
    for i in range(10):
        a = math.pi / 2 + TAU * i / 10.0
        rr = r_out if i % 2 == 0 else r_in
        px = x0 + rr * math.cos(a)
        pts.append((px, Y(cs - rr * math.sin(a)), wing_skin_z(px, True, 0.026)))
    base = s.add_verts(pts + [(x0, Y(cs), wing_skin_z(x0, True, 0.026))])
    for i in range(10):
        s.face((base + 10, base + i, base + (i + 1) % 10), "white")
    # ONE bar strip straight THROUGH the star, biased under it so the star wins
    # the overlap. Built as a single strip through the centre so no half can
    # inherit a reversed winding.
    outer = r_out + 0.86
    edges = [x0 - outer + k * (2.0 * outer / 6.0) for k in range(7)]
    v = [s.add_verts([(a, Y(cs - 0.235), wing_skin_z(a, True, 0.020)),
                      (a, Y(cs + 0.235), wing_skin_z(a, True, 0.020))])
         for a in edges]
    for k in range(6):
        b0, b1 = v[k], v[k + 1]
        # (b0, b1, b1+1, b0+1) walks bottom-left -> top-left -> top-right, which
        # is CLOCKWISE seen from +Z and gives a DOWN normal. Reversed, the bar
        # faces up like the star. Nothing but an explicit normal check catches
        # this: the mesh stays manifold and the decal just renders black.
        s.face(tuple(reversed((b0, b1, b1 + 1, b0 + 1))), "white")
    return s


def build_prop():
    """Local origin at the hub; the spin axis is local Y (Godot local Z).
    Three blades, Hamilton Standard 23E50, yellow tips."""
    s = Shell()
    revolve(s, [(0.34, 0.0), (0.24, 0.16), (0.06, 0.235),
                (-0.16, 0.245), (-0.24, 0.0)], 10, 0.0, 0.0, "blade",
            ymap=lambda v: v)
    r_tip = REAL_PROP_D * 0.5
    for k in range(3):
        # Clocked so NO blade sits at bottom dead centre: if one did, the static
        # bbox would equal the swept arc and the ground-line figure would stop
        # meaning anything.
        a = TAU * k / 3.0 + math.radians(90.0)
        ca, sa = math.cos(a), math.sin(a)
        secs = []
        for r, chord, thick, pitch in ((0.22, 0.30, 0.085, math.radians(38.0)),
                                       (0.70, 0.40, 0.060, math.radians(26.0)),
                                       (1.30, 0.36, 0.036, math.radians(14.0)),
                                       (r_tip - 0.22, 0.28, 0.022, math.radians(9.0)),
                                       (r_tip, 0.16, 0.014, math.radians(8.0))):
            cp, sp = math.cos(pitch), math.sin(pitch)
            pts = []
            for fc, ft in ((-0.5, 0.0), (-0.2, 0.5), (0.25, 0.42),
                           (0.5, 0.0), (0.25, -0.42), (-0.2, -0.5)):
                u, w = fc * chord, ft * thick
                du = u * cp - w * sp
                dy = u * sp + w * cp
                pts.append((ca * r - sa * du, dy, sa * r + ca * du))
            secs.append(pts)
        # ONE loft, tagged per bridge: splitting it into two lofts duplicates the
        # shared section (18 doubles, 36 boundary edges across three blades).
        bases = [s.add_verts(r) for r in secs]
        for i in range(len(secs) - 1):
            bridge(s, 6, bases[i], bases[i + 1], "tip" if i == len(secs) - 2 else "blade")
        fan_cap(s, bases[0], 6, "blade")
        fan_cap(s, bases[-1], 6, "tip")
    return s


# ==================================================================== materials
def srgb(r, g, b):
    def c(v):
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return (c(r), c(g), c(b), 1.0)


# T.O. 1-1-4 South East Asia scheme as worn by the gunships: the usual FS 36622
# light grey underside was replaced in-theatre with FS 17038 BLACK for night work.
MATERIALS = [
    ("ac47_sea_tan", srgb(0.506, 0.416, 0.314), 0.86),        # FS 30219
    ("ac47_sea_green_med", srgb(0.357, 0.412, 0.298), 0.88),  # FS 34102
    ("ac47_sea_green_dark", srgb(0.220, 0.260, 0.180), 0.88), # FS 34079
    ("ac47_night_black", srgb(0.058, 0.058, 0.060), 0.80),    # FS 17038
    ("ac47_glass", srgb(0.150, 0.190, 0.205), 0.24),
    ("ac47_marking_white", srgb(0.880, 0.880, 0.860), 0.76),
    ("ac47_exhaust_stain", srgb(0.150, 0.145, 0.130), 0.90),
    ("ac47_prop_blade", srgb(0.095, 0.095, 0.095), 0.62),
    ("ac47_prop_tip", srgb(0.720, 0.600, 0.110), 0.68),
]

TAG_MAT = {
    "dark": "ac47_night_black", "glass": "ac47_glass",
    "white": "ac47_marking_white", "tyre": "ac47_prop_blade",
    "blade": "ac47_prop_blade", "tip": "ac47_prop_tip",
    "stain": "ac47_exhaust_stain",
}

# Voronoi seeds in the (|x|, y) plan. Spacing ~2.8 m against a 0.95 m peak
# wobble - ratio 0.34, under the 0.4 at which the blobs fragment into a
# chequerboard (A-1 lesson). Seeds are spread laterally as well as
# longitudinally or the fuselage paints as transverse bands.
CAMO_SEEDS = [
    (0.10, 5.40, "ac47_sea_green_dark"), (0.35, 3.00, "ac47_sea_tan"),
    (0.15, 0.60, "ac47_sea_green_med"), (0.40, -1.90, "ac47_sea_tan"),
    (0.20, -4.40, "ac47_sea_green_dark"), (0.45, -6.90, "ac47_sea_green_med"),
    (0.15, -9.30, "ac47_sea_tan"), (0.40, -11.60, "ac47_sea_green_dark"),
    (2.20, 1.20, "ac47_sea_tan"), (3.60, -1.30, "ac47_sea_green_med"),
    (5.20, 0.90, "ac47_sea_green_dark"), (6.80, -1.10, "ac47_sea_tan"),
    (8.40, 0.70, "ac47_sea_green_med"), (10.00, -1.00, "ac47_sea_green_dark"),
    (11.60, 0.60, "ac47_sea_tan"), (13.20, -0.80, "ac47_sea_green_med"),
]


def camo_split(st):
    """Demarcation height, as a fraction of the LOCAL fuselage depth rather than
    a fixed z. A constant-z line runs off the bottom of an upswept tail cone and
    leaves the last four metres with no black on it at all."""
    top, bot, _ = fuse_at(max(0.0, min(19.6, st)))
    return bot + 0.32 * (top - bot) + 0.11 * math.sin(st * 0.55) \
        + 0.05 * math.sin(st * 1.35 + 0.7)


def camo_for(p, n):
    st = (NOSE_Y - p.y) / KS
    # Gun-gas soot streaking aft from the battery. It must be pinned to the
    # near-vertical FLANK: without the normal and |x| clauses this rule also
    # caught the whole aft half of the port wing's upper surface and painted a
    # black rectangle across it that no scalar in the build would have reported.
    # Starts AFT of the first gun and hugs the demarcation, so the mounts stand
    # against camo instead of against their own soot and stop reading.
    if -1.45 < p.x < -0.90 and n.x < -0.45 and 9.0 < st < 13.6 \
            and -0.55 < p.z < 0.02:
        return "ac47_exhaust_stain"
    # Engine exhaust: a streak aft of each nacelle on BOTH surfaces. On the
    # upper surface it is a dirt mark; on the black underside it is the only
    # tonal relief there is, and without it the whole lower half of a night
    # gunship renders as one unbroken silhouette.
    if 2.20 < abs(p.x) < 3.45 and st > 5.2 and (n.z > 0.5 or n.z < -0.35) \
            and st < 11.0 + (abs(p.x) - 2.82) * 0.0:
        return "ac47_exhaust_stain"
    if n.z < -0.35 and st > 6.0 and abs(p.x) < 1.30 and st < 13.0:
        return "ac47_exhaust_stain"
    if n.z > 0.5:
        if 0.55 < st < 1.95 and abs(p.x) < 0.55 and p.z > -0.10:
            return "ac47_night_black"        # antiglare deck ahead of the screen
    elif n.z < -0.35 or p.z < camo_split(st):
        return "ac47_night_black"
    ax = abs(p.x)
    qx = ax + 0.70 * math.sin(p.y * 0.62 + ax * 0.45) \
        + 0.25 * math.sin(p.y * 1.55 - ax * 0.95)
    qy = p.y + 0.70 * math.sin(ax * 0.58 - 0.60) + 0.25 * math.sin(ax * 1.40 + 1.70)
    best, bd = "ac47_sea_tan", 1e9
    for sx, sy, name in CAMO_SEEDS:
        d = (qx - sx) ** 2 + (qy - sy) ** 2
        if d < bd:
            bd, best = d, name
    return best


def make_materials():
    out = []
    for name, col, rough in MATERIALS:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = col
        b.inputs["Metallic"].default_value = 0.0
        b.inputs["Roughness"].default_value = rough
        if "Specular IOR Level" in b.inputs:
            b.inputs["Specular IOR Level"].default_value = 0.25
        m.roughness = rough
        m.metallic = 0.0
        out.append(m)
    return out


def realise(name, shell, mats, paint, recalc=True):
    me = bpy.data.meshes.new(name)
    me.from_pydata(shell.v, [], shell.f)
    me.update()
    assert len(me.polygons) == len(shell.f), "%s: face count changed" % name

    # recalc_face_normals only knows "outward" on a CLOSED shell. Run it over the
    # one-sided decals and it re-orients them at random, which shows up as black
    # wedges. Those carry their winding from the builder.
    if recalc:
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        me.update()
        assert len(me.polygons) == len(shell.f), "%s: recalc changed faces" % name

    names = [m.name for m in mats]
    for m in mats:
        me.materials.append(m)
    for i, poly in enumerate(me.polygons):
        tag = shell.tag[i]
        mn = camo_for(poly.center, poly.normal) if (paint and tag == "skin") \
            else (TAG_MAT[tag] if tag != "skin" else "ac47_sea_tan")
        poly.material_index = names.index(mn)

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
    # then silently judges a box. glTF exports it anyway (use_visible defaults
    # False), so the collision mesh still ships.
    ob.hide_render = True
    return ob


def make_prop(name, side, mats):
    ob = realise(name, build_prop(), mats, False)
    ob.location = (side * NACELLE_X, Y(PROP_S), THRUST_Z - COM_Z)
    return ob


def bake_spin(props):
    """One slotted `prop_spin` action driving both props about their local Y
    (= Godot local Z, the thrust line). Quaternion keys every 90 deg: every
    consecutive pair has a positive dot so Godot's slerp cannot take the long way
    round, and the 360 deg key is the same rotation as the 0 deg key."""
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
def bounds(objs):
    a = Vector((1e9, 1e9, 1e9))
    b = Vector((-1e9, -1e9, -1e9))
    for ob in objs:
        off = Vector(ob.location)
        for v in ob.data.vertices:
            w = v.co + off
            a = Vector((min(a[i], w[i]) for i in range(3)))
            b = Vector((max(b[i], w[i]) for i in range(3)))
    return a, b


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    do_export = "--export" in argv
    render_dir = argv[argv.index("--render") + 1] if "--render" in argv else None

    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = make_materials()

    guns_shell, muzzles = build_guns()

    air = realise("AC47_Airframe", build_airframe(), mats, True)
    glaz = realise("AC47_Glazing", build_glazing(), mats, False, recalc=False)
    guns = realise("AC47_Guns", guns_shell, mats, False)
    gear = realise("AC47_Gear", build_gear(), mats, False)
    side = realise("AC47_PortSide", build_port_side(), mats, False, recalc=False)
    wins = realise("AC47_Windows", build_windows(), mats, False, recalc=False)
    marks = realise("AC47_Markings", build_markings(), mats, False, recalc=False)
    prop_r = make_prop("AC47_Prop_R", 1.0, mats)
    prop_l = make_prop("AC47_Prop_L", -1.0, mats)

    # ---- colliders, in design coordinates; shifted with everything else below
    cols = [
        collider("AC47_Col_Hull-colonly",
                 [((0.0, Y(2.2), -0.20), (2.10, 4.30, 2.60)),
                  ((0.0, Y(8.0), -0.29), (2.55, 7.40, 2.90)),
                  ((0.0, Y(14.0), -0.14), (2.20, 5.00, 2.55)),
                  ((0.0, Y(18.0), 0.10), (1.00, 3.20, 1.60))]),
        collider("AC47_Col_Wing-colonly",
                 [((0.0, Y(7.05), -0.85), (12.0, 4.40, 0.80)),
                  ((0.0, Y(7.60), -0.30), (REAL_SPAN, 3.20, 0.70)),
                  ((NACELLE_X, Y(4.70), -1.75), (1.40, 3.60, 1.90)),
                  ((-NACELLE_X, Y(4.70), -1.75), (1.40, 3.60, 1.90))]),
        collider("AC47_Col_Aft-colonly",
                 [((0.0, Y(17.6), 2.30), (0.34, 4.10, 2.90)),
                  ((0.0, Y(18.0), -0.02), (REAL_STAB_SPAN, 2.90, 0.30))]),
    ]

    visible = [air, glaz, guns, gear, side, wins, marks, prop_r, prop_l]
    fixed = [air, glaz, guns, gear, side, wins, marks]

    # ---- seat the model on its centre of mass. y is already the wing quarter
    # chord by construction (Y() is defined from it); only z has to move.
    shift = Vector((0.0, 0.0, -COM_Z))
    for ob in fixed + cols:
        for v in ob.data.vertices:
            v.co += shift
        ob.data.update()
    bpy.context.view_layer.update()

    # ---- measure
    tris = 0
    print("\n--- MESH INVENTORY -------------------------------------------")
    for ob in visible + cols:
        ob.data.calc_loop_triangles()
        t = len(ob.data.loop_triangles)
        ngons = sum(1 for p in ob.data.polygons if len(p.vertices) > 4)
        if not ob.name.endswith("-colonly"):
            tris += t
        print("  %-26s tris %5d verts %5d ngons %d loc %s"
              % (ob.name, t, len(ob.data.vertices), ngons,
                 tuple(round(c, 3) for c in ob.location)))
    for e_name, (p, d) in zip(("gun_muzzle_1", "gun_muzzle_2", "gun_muzzle_3"),
                              muzzles):
        print("  %-26s EMPTY  loc %s  bore %s"
              % (e_name, tuple(round(c, 3) for c in (p + shift)),
                 tuple(round(c, 3) for c in d)))

    lo, hi = bounds(visible)
    alo, ahi = bounds([air])
    prop_d = 2.0 * max(math.hypot(v.co.x, v.co.z) for v in prop_r.data.vertices)
    length = hi.y - lo.y
    span = hi.x - lo.x
    # measure the parts BEFORE anything is merged: after a join, "widest vertex
    # aft of the wing" answers with the WING and "fuselage centreline" answers
    # with the wing hanging under it.
    # A width query must name its band AND say why nothing else lives there.
    # s 8.5 is the widest fuselage station; the wing spans that y too, so the
    # |x| < 1.6 clause is what keeps this from answering "29.11" (it did).
    fuse_w = 2.0 * max(abs(v.co.x) for v in air.data.vertices
                       if abs(v.co.y - Y(8.5)) < 0.5 and abs(v.co.x) < 1.60)
    fuse_h = max(t - b for _, t, b, _ in FUSE_PROFILE)
    # aft of s 16.0 the only things wider than the tail cone are the tailplane
    # tips; the fin is in the x = 0 plane and contributes |x| < 0.16.
    stab_span = 2.0 * max(abs(v.co.x) for v in air.data.vertices
                          if v.co.y < Y(16.0))
    arc_z = prop_r.location.z - REAL_PROP_D * 0.5

    # Prop/fuselage clearance, swept over HEIGHT. Measuring it at the widest
    # fuselage station "proves" a clash that does not exist, because the engines
    # are slung 1.2 m below the fuselage centreline (reference obs 10).
    gap, gap_z = 1e9, 0.0
    for i in range(161):
        z = THRUST_Z - REAL_PROP_D * 0.5 + i * REAL_PROP_D / 160.0
        dz = z - THRUST_Z
        if abs(dz) >= REAL_PROP_D * 0.5:
            continue
        inboard = NACELLE_X - math.sqrt((REAL_PROP_D * 0.5) ** 2 - dz * dz)
        d = inboard - skin_x(PROP_S, z)
        if d < gap:
            gap, gap_z = d, z

    area = 0.0
    for i in range(len(WING_STATIONS) - 1):
        x0, _, c0, _ = WING_STATIONS[i]
        x1, _, c1, _ = WING_STATIONS[i + 1]
        area += (x1 - x0) * (c0 + c1) * 0.5
    area *= 2.0

    print("\n--- MEASURED vs REAL (object space, metres) ------------------")
    print("  span        %7.3f  real %6.3f  d %+0.3f" % (span, REAL_SPAN, span - REAL_SPAN))
    print("  length      %7.3f  real %6.3f  d %+0.3f" % (length, REAL_LENGTH, length - REAL_LENGTH))
    print("  fuselage W  %7.3f  real %6.3f  (at s 8.5, the widest station)" % (fuse_w, REAL_FUSE_W))
    print("  fuselage H  %7.3f  real %6.3f  TALLER THAN WIDE by %.2f%%"
          % (fuse_h, REAL_FUSE_H, 100.0 * (fuse_h / fuse_w - 1.0)))
    print("  tailplane   %7.3f  real %6.3f" % (stab_span, REAL_STAB_SPAN))
    print("  prop dia    %7.3f  real %6.3f" % (prop_d, REAL_PROP_D))
    print("  wing area   %7.2f  real %6.2f m2 (gross, incl. carry-through)" % (area, REAL_WING_AREA))
    print("  nacelle x  +/-%.3f  (drawing +/-2.82)" % NACELLE_X)
    print("  min prop-tip / fuselage clearance %.3f m, worst at z %+0.2f - swept"
          % (gap, gap_z - COM_Z))
    print("             over HEIGHT, because the engines hang 1.20 m below the")
    print("             fuselage centreline and a widest-station test lies")
    print("  fin top above the aft crown %.3f  (real ~2.48)"
          % (ahi.z - (fuse_at(16.5)[0] - COM_Z)))
    print("  height belly-to-fin-top %.3f  (fuselage keel, not the nacelles; the"
          % (ahi.z - (min(b for _, _, b, _ in FUSE_PROFILE) - COM_Z)))
    print("             published 5.16 m is GROUND to fin top with the tail DOWN")
    print("             on its gear, which is not this pose)")
    print("  nose y %+0.3f  tail y %+0.3f" % (hi.y, lo.y))
    print("  bbox lo %s hi %s" % (tuple(round(c, 3) for c in lo),
                                  tuple(round(c, 3) for c in hi)))
    print("  origin = centre of mass (x=0, y=wing quarter chord s %.3f, "
          "z=fuselage centreline at the wing)" % QC_S)
    print("  GROUND LINE at local z %+0.3f  (the SWEPT prop arc; the static "
          "bbox bottoms at %+0.3f)" % (arc_z, lo.z))
    print("  TOTAL VISIBLE TRIS %d" % tris)

    # ---- QC gates. A build that ran without error proves nothing.
    print("\n--- QC -------------------------------------------------------")
    bad = []
    open_shells = {"AC47_Glazing", "AC47_PortSide", "AC47_Windows", "AC47_Markings"}
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
        nonman = 0 if ob.name in open_shells else sum(
            1 for e in bm.edges if not e.is_manifold)
        zero = sum(1 for f in bm.faces if f.calc_area() < 1e-7)
        bm.free()
        print("  %-26s ngons %d loose %d doubles %d non-manifold %d zero-area %d"
              % (ob.name, ng, loose, dbl, nonman, zero))
        if ng or loose or dbl or zero:
            bad.append(ob.name)

    # every port-side panel must face outboard to PORT, or it renders as a hole
    for ob in (side, guns):
        assert max(v.co.x for v in ob.data.vertices) < 0.0, \
            "%s has geometry on the starboard side" % ob.name
    worst = max(p.normal.x for p in side.data.polygons)
    assert worst < -0.05, "AC47_PortSide has a backfacing panel (worst n.x %.2f)" % worst
    print("  port side: %d faces, worst n.x %.2f - none backfacing"
          % (len(side.data.polygons), worst))
    for p in wins.data.polygons:
        want = 1.0 if p.center.x > 0.0 else -1.0
        assert p.normal.x * want > 0.05, \
            "AC47_Windows face at %s is backfacing" % tuple(round(c, 2) for c in p.center)
    print("  cabin windows: %d faces, all facing outboard" % len(wins.data.polygons))
    for p in marks.data.polygons:
        assert p.normal.z > 0.85, \
            "AC47_Markings face at %s does not face up (n.z %.2f)" \
            % (tuple(round(c, 2) for c in p.center), p.normal.z)
    print("  wing insignia: %d faces, all facing up" % len(marks.data.polygons))

    # a decal that has sunk into the skin is invisible in every scalar
    sunk = 0
    for ob in (side, wins):
        for v in ob.data.vertices:
            st = (NOSE_Y - v.co.y) / KS
            if abs(v.co.x) < skin_x(st, v.co.z + COM_Z) + 0.5 * DECAL_LIFT:
                sunk += 1
    assert sunk == 0, "%d decal vertices are inside the skin" % sunk
    print("  decal proud-of-skin check: 0 of %d vertices sunk"
          % (len(side.data.vertices) + len(wins.data.vertices)))

    assert abs(lo.x + hi.x) < 1e-4, "not laterally symmetric (%.5f)" % (lo.x + hi.x)
    assert fuse_h > fuse_w, "the fuselage must be taller than wide"
    assert gap > 0.10, "inboard prop tip clearance %.3f m" % gap
    mats_used = set()
    for ob in visible:
        for p in ob.data.polygons:
            mats_used.add(ob.data.materials[p.material_index].name)
    print("  materials actually painted: %d -> %s" % (len(mats_used), sorted(mats_used)))
    for m in bpy.data.materials:
        b = m.node_tree.nodes["Principled BSDF"]
        assert b.inputs["Metallic"].default_value == 0.0, "%s is metallic" % m.name
    assert not [i for i in bpy.data.images if i.name != "Render Result"], \
        "this build ships NO textures - a1/f4 do not either"
    assert not bad, "QC FAILED on %s" % bad
    print("  QC PASS")

    empties = []
    for i, (p, d) in enumerate(muzzles):
        e = bpy.data.objects.new("gun_muzzle_%d" % (i + 1), None)
        e.empty_display_type = "SINGLE_ARROW"
        e.empty_display_size = 0.4
        e.location = p + shift
        # Blender local +Y -> Godot local -Z, so the adopter reads the firing
        # direction as -muzzle.global_transform.basis.z. Z-only rotation would
        # not express the 12 deg depression, so this one is a track-quat and the
        # verifier asserts the exported basis rather than the euler.
        e.rotation_euler = d.to_track_quat("Y", "Z").to_euler()
        bpy.context.collection.objects.link(e)
        empties.append(e)
    bpy.context.view_layer.update()
    for e in empties:
        fwd = (e.matrix_world.to_3x3() @ Vector((0.0, 1.0, 0.0))).normalized()
        print("  %-14s loc %s  Blender +Y = Godot -Z = bore %s (%.1f deg down)"
              % (e.name, tuple(round(c, 3) for c in e.location),
                 tuple(round(c, 3) for c in fwd), math.degrees(math.asin(-fwd.z))))

    act = bake_spin((prop_l, prop_r))
    print("  baked action %r on %d slots (%.2f rev/s at 24 fps)"
          % (act.name, len(act.slots), 24.0 / SPIN_FRAMES))

    if render_dir:
        do_render(render_dir, lo, hi)
        for ob in list(bpy.data.objects):
            if ob.type in {"CAMERA", "LIGHT"}:
                bpy.data.objects.remove(ob, do_unlink=True)

    if do_export:
        blend = os.path.join(OUT_DIR, "ac47_spooky_v3.blend")
        glb = os.path.join(OUT_DIR, "ac47_spooky_v3.glb")
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
        for f in os.listdir(OUT_DIR):
            if f.endswith(".blend1"):
                os.remove(os.path.join(OUT_DIR, f))
        print("EXPORTED %s" % glb)
        print("SAVED    %s" % blend)


# ====================================================================== renders
# azimuth 0 = camera on +X (starboard beam), 90 = ahead of the nose (+Y),
# 180 = the PORT beam, which on this aeroplane is the whole point.
# Deliberately IDENTICAL to build_ac47_spooky_v2.py's table, so `ac47v3_*` and
# `ac47v2_*` can be flicked between as a fair comparison. Only the gun close-up
# aims at each model's own battery, because they sit at different stations.
VIEWS = [("port", 180.0, 3.0, 1.50), ("threequarter", 214.0, 15.0, 1.50),
         ("front", 90.0, 4.0, 1.50), ("starboard", 0.0, 3.0, 1.50),
         ("rear_quarter", 320.0, 14.0, 1.55), ("underside", 200.0, -26.0, 1.55),
         ("top", 90.0, 86.0, 2.10), ("guns", 200.0, 10.0, 0.20)]


def do_render(out_dir, lo, hi):
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 24
    sc.cycles.use_denoising = True
    sc.cycles.device = "CPU"
    sc.render.resolution_x, sc.render.resolution_y = 1000, 620
    sc.view_settings.view_transform = "AgX"
    w = bpy.data.worlds.new("W")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.40, 0.48, 0.58, 1.0)
    w.node_tree.nodes["Background"].inputs[1].default_value = 1.35
    sc.world = w
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 4.2
    sun.data.angle = math.radians(6.0)
    sun.rotation_euler = (math.radians(52.0), 0.0, math.radians(205.0))
    bpy.context.collection.objects.link(sun)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 60.0
    bpy.context.collection.objects.link(cam)
    sc.camera = cam
    tgt = (lo + hi) * 0.5
    gun_aim = Vector((-1.35, Y(GUN_S[1]), 0.05))
    span = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z)
    for name, az, el, mul in VIEWS:
        a, e = math.radians(az), math.radians(el)
        aim = gun_aim if name == "guns" else tgt
        cam.location = aim + Vector((math.cos(e) * math.cos(a),
                                     math.cos(e) * math.sin(a),
                                     math.sin(e))) * (span * mul)
        cam.rotation_euler = (aim - Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(out_dir, "ac47v3_%s.png" % name)
        bpy.ops.render.render(write_still=True)
        print("RENDER %s" % sc.render.filepath)


main()
