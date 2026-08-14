"""Build the F-4 Phantom II v2 airframe from scratch and export it.

    blender -b --factory-startup --python tools/build_f4_phantom_v2.py -- [--export] [--render DIR]

Frame contract: nose at Blender +Y (Godot -Z) at identity, +Z up, real metres.
Origin sits at the centre of mass - x on the centreline, y at the wing quarter
MAC, z on the fuselage centreline at the wing. NOT the ground line:
cas_airplane.gd:355 spawns the strafe muzzle 1.2 m BELOW the node origin.

This is a JET. Nothing on it spins, so no node may carry a name that
rotor_spin.gd:23-25 treats as a rotor or propeller hint, and no action ships.

Geometry is measured off the dimensioned manual three-view (top view 100.05
px/m, side view 97.0 px/m - the two views are drawn at different scales). See
production/blender_notes.md, 2026-08-14, for the ten form observations and for
why this is the 19.2 m F-4E-proportioned airframe rather than the 17.76 m C/D.
"""

import bpy, bmesh, math, os, sys
from mathutils import Vector

TAU = math.tau
PROJ = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT_DIR = os.path.join(PROJ, "assets", "us", "aircraft")

# ---------------------------------------------------------------- real numbers
REAL_LENGTH = 19.20          # F-4E, pitot tip to rudder/stabilator trailing edge
REAL_SPAN = 11.71
REAL_STAB_SPAN = 4.92        # the drawing's "5.0m" tail dimension
REAL_FIN_TOP_AGL = 4.98      # ground line to fin top, GEAR DOWN - see note below
REAL_WING_AREA = 49.24

# Set to 1.45 to build an F-4C/D instead: that is the whole length difference
# between the two marks and all of it is in the radome/gun bay.
NOSE_CUT = 0.0

# --------------------------------------------------------------- design datum
# Stations are metres aft of the pitot tip; Blender y = -station, so the nose
# sits at y 0 and the tail at y -19.2. z 0 is the fuselage centreline at the
# wing, which the drawing puts 2.05 m above the ground line.
GROUND_Z = -2.05
NSIDE = 12
FOLD_X = 4.205               # dogtooth AND dihedral break, both at this station
DIHEDRAL_OUT = math.radians(12.0)
DROOP_IN = math.radians(1.0)
ANHEDRAL_STAB = math.radians(23.0)
WING_ROOT_Z = -0.20


def ST(s):
    """Station (m aft of the pitot tip) -> Blender y."""
    return -(s - NOSE_CUT if s > 3.70 else s * (3.70 - NOSE_CUT) / 3.70)


# =============================================================== mesh utilities
class Shell:
    def __init__(self):
        self.v = []
        self.f = []
        self.tag = []

    def add_verts(self, verts):
        o = len(self.v)
        self.v.extend(verts)
        return o

    def face(self, idx, tag):
        self.f.append(tuple(idx))
        self.tag.append(tag)

    def add(self, verts, faces, tag):
        o = self.add_verts(verts)
        for f in faces:
            self.face([i + o for i in f], tag)
        return o


def ring(n, y, cz, hw, up, dn, cx=0.0):
    pts = []
    for i in range(n):
        a = TAU * i / n
        s, c = math.sin(a), math.cos(a)
        pts.append((cx + hw * c, y, cz + (up if s >= 0.0 else dn) * s))
    return pts


def rrect(y, x0, x1, z0, z1, k=0.30):
    """Eight-point rounded rectangle in the XZ plane, counterclockwise from +x.
    Used for the intake trunks, whose section is a slab, not a circle."""
    cx, hw = (x0 + x1) * 0.5, (x1 - x0) * 0.5
    cz, hh = (z0 + z1) * 0.5, (z1 - z0) * 0.5
    p = [(hw, hh * k), (hw * k, hh), (-hw * k, hh), (-hw, hh * k),
         (-hw, -hh * k), (-hw * k, -hh), (hw * k, -hh), (hw, -hh * k)]
    return [(cx + a, y, cz + b) for a, b in p]


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


def loft(shell, rings, tag, cap_first=True, cap_last=True, tags=None):
    """Bridge equal-length rings into quads. `tags` overrides tag per band."""
    n = len(rings[0])
    bases = [shell.add_verts(r) for r in rings]
    for k in range(len(rings) - 1):
        bridge(shell, n, bases[k], bases[k + 1], tags[k] if tags else tag)
    if cap_first:
        fan_cap(shell, bases[0], n, tag)
    if cap_last:
        fan_cap(shell, bases[-1], n, tag)
    return bases


def revolve(shell, profile, n, axis_x, axis_z, tag):
    """Body of revolution about a line parallel to +Y. profile = [(y, r), ...]."""
    kinds = []
    for y, r in profile:
        if r <= 1e-5:
            kinds.append(("pt", shell.add_verts([(axis_x, y, axis_z)])))
        else:
            kinds.append(("ring", shell.add_verts(
                [(axis_x + r * math.cos(TAU * i / n), y,
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


CAMBER = [(0.00, 0.00), (0.25, 0.50), (0.70, 0.30),
          (1.00, 0.00), (0.70, -0.22), (0.25, -0.38)]
SYMMET = [(0.00, 0.00), (0.25, 0.44), (0.70, 0.30),
          (1.00, 0.00), (0.70, -0.30), (0.25, -0.44)]


def foil(le, chord, thick, span_at, plane, along_x, sym=False):
    """Six-point aerofoil section. Chord runs from the LE toward -Y."""
    pts = []
    for fc, ft in (SYMMET if sym else CAMBER):
        y = le - chord * fc
        t = plane + thick * ft
        pts.append((span_at, y, t) if along_x else (t, y, span_at))
    return pts


def box(shell, cx, cy, cz, sx, sy, sz, tag):
    hx, hy, hz = sx * 0.5, sy * 0.5, sz * 0.5
    v = [(cx - hx, cy - hy, cz - hz), (cx + hx, cy - hy, cz - hz),
         (cx + hx, cy + hy, cz - hz), (cx - hx, cy + hy, cz - hz),
         (cx - hx, cy - hy, cz + hz), (cx + hx, cy - hy, cz + hz),
         (cx + hx, cy + hy, cz + hz), (cx - hx, cy + hy, cz + hz)]
    f = [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4),
         (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    shell.add(v, f, tag)


# =================================================================== wing table
# (half-span x, LE station, chord, thickness). Leading edge traced off the top
# view: 51.5 deg inboard of the fold, 54 deg outboard, with the 0.28 m FORWARD
# step at x 4.205 that is the dogtooth. The two stations either side of the
# break are 0.01 m apart so the loft builds the notch as a real vertical face.
WING_STATIONS = [
    (0.95, 7.22, 6.21, 0.34),
    (1.80, 8.29, 5.34, 0.30),
    (2.60, 9.30, 4.51, 0.26),
    (3.40, 10.29, 3.73, 0.22),
    (FOLD_X - 0.005, 11.30, 2.90, 0.18),
    (FOLD_X + 0.005, 11.02, 3.19, 0.18),
    (5.00, 12.13, 2.30, 0.14),
    (5.55, 12.90, 1.65, 0.10),
    (5.855, 13.42, 1.15, 0.07),
]


def wing_z(x):
    """Inner panel droops 1 deg, outer panel kicks up 12 deg at the fold."""
    ax = abs(x)
    z = WING_ROOT_Z - min(ax, FOLD_X) * math.tan(DROOP_IN)
    return z + max(0.0, ax - FOLD_X) * math.tan(DIHEDRAL_OUT)


def wing_at(x):
    ax = abs(x)
    for i in range(len(WING_STATIONS) - 1):
        x0, l0, c0, t0 = WING_STATIONS[i]
        x1, l1, c1, t1 = WING_STATIONS[i + 1]
        if x0 - 1e-6 <= ax <= x1 + 1e-6:
            u = (ax - x0) / (x1 - x0) if x1 > x0 else 0.0
            return (l0 + (l1 - l0) * u, c0 + (c1 - c0) * u,
                    t0 + (t1 - t0) * u, wing_z(ax))
    x1, l1, c1, t1 = WING_STATIONS[-1]
    return l1, c1, t1, wing_z(x1)


# ================================================================ the airframe
# (station, centre z, half-width, up, down). The radome centre sits 0.55 m below
# the fuselage centreline and climbs to it by the windscreen - that IS the
# droop, and it is why a straight-cone nose never looks like a Phantom. The
# half-widths aft of station 15.3 are the measured BOOM: 0.68 at 15.4, 0.44 at
# 16.4. Everything from the fin, the stabilators and the rudder hangs off it.
FUSE_STATIONS = [
    (1.00, -0.60, 0.06, 0.06, 0.06),   # radome tip, drooped
    (1.35, -0.57, 0.26, 0.25, 0.25),
    (1.90, -0.50, 0.40, 0.39, 0.39),
    (2.50, -0.39, 0.49, 0.48, 0.48),
    (3.20, -0.26, 0.54, 0.53, 0.53),
    (3.70, -0.16, 0.57, 0.60, 0.55),   # windscreen base
    (4.40, -0.08, 0.62, 0.70, 0.60),
    (5.10, -0.03, 0.68, 0.74, 0.64),
    (5.90, 0.00, 0.76, 0.76, 0.68),
    (6.90, 0.00, 0.83, 0.76, 0.72),
    (8.20, 0.00, 0.90, 0.75, 0.75),
    (9.80, 0.00, 0.96, 0.75, 0.75),
    (11.40, 0.00, 1.02, 0.75, 0.75),
    (13.00, 0.01, 1.08, 0.74, 0.75),
    (14.30, 0.02, 1.13, 0.72, 0.73),
    (15.30, 0.05, 1.06, 0.66, 0.66),   # nozzle exit plane - the wide body ENDS
    (15.55, 0.11, 0.64, 0.46, 0.43),   # boom
    (16.40, 0.19, 0.45, 0.37, 0.34),
    (17.60, 0.27, 0.35, 0.30, 0.28),
    (18.70, 0.33, 0.24, 0.22, 0.20),
    (19.15, 0.36, 0.10, 0.10, 0.09),
]

# The fin. (z, LE station, chord, thickness). Leading edge rakes 62 deg from
# vertical; the lowest station is buried in the spine so the dorsal fillet
# emerges from the skin instead of being modelled.
FIN_STATIONS = [
    (0.50, 13.60, 5.20, 0.26),
    (1.10, 14.70, 4.20, 0.22),
    (1.70, 15.90, 3.30, 0.17),
    (2.30, 17.05, 2.28, 0.12),
    (2.75, 17.90, 1.45, 0.08),
    (2.93, 18.30, 0.95, 0.04),
]

# The stabilator: one-piece slab, 23 deg anhedral, mounted LOW on the boom.
STAB_STATIONS = [
    (0.36, 16.45, 2.22, 0.14),
    (1.40, 17.55, 1.44, 0.09),
    (2.46, 18.60, 0.62, 0.04),
]
STAB_ROOT_Z = 0.26


def stab_z(x):
    return STAB_ROOT_Z - (abs(x) - STAB_STATIONS[0][0]) * math.tan(ANHEDRAL_STAB)


def build_airframe():
    s = Shell()

    # ---- fuselage
    loft(s, [ring(NSIDE, ST(st), cz, hw, up, dn) for st, cz, hw, up, dn in FUSE_STATIONS],
         "skin", cap_first=True, cap_last=True)

    # ---- nose probe. Not decoration: the 19.2 m length dimension on the manual
    # three-view starts at the PROBE TIP (measured, top view x 57 px), so an
    # airframe that starts at the radome is 1 m short of its own spec.
    revolve(s, [(ST(0.12), 0.0), (ST(0.22), 0.022), (ST(0.90), 0.032),
                (ST(1.06), 0.055), (ST(1.12), 0.0)], 6, 0.0, -0.60, "dark")

    # ---- chin fairing under the nose (M61 bay on the E, seeker fairing on the D).
    # This shallow lobe is what makes the forward fuselage read heavy; without it
    # the nose is a bare cone and the aeroplane looks like a trainer.
    loft(s, [ring(8, ST(st), cz, hw, up, dn)
             for st, cz, hw, up, dn in ((1.70, -0.72, 0.16, 0.10, 0.10),
                                        (2.40, -0.78, 0.27, 0.15, 0.16),
                                        (3.30, -0.80, 0.30, 0.17, 0.18),
                                        (4.20, -0.76, 0.29, 0.16, 0.17),
                                        (4.90, -0.66, 0.22, 0.11, 0.12))], "skin")

    # ---- tandem canopy. Lower edge BURIED in the spine - a canopy floating above
    # the deck reads as a roll bar (the A-1 build hit exactly this).
    loft(s, [ring(8, ST(3.58), 0.48, 0.26, 0.06, 0.30),
             ring(8, ST(4.00), 0.60, 0.36, 0.44, 0.44),
             ring(8, ST(4.35), 0.68, 0.43, 0.62, 0.50),
             ring(8, ST(4.95), 0.69, 0.46, 0.66, 0.50),
             ring(8, ST(5.55), 0.69, 0.47, 0.65, 0.50),
             ring(8, ST(6.35), 0.68, 0.46, 0.62, 0.50),
             ring(8, ST(7.05), 0.66, 0.41, 0.54, 0.48),
             ring(8, ST(7.60), 0.60, 0.30, 0.30, 0.42)], "glass")
    # spine fairing aft of the canopy - the step DOWN onto the long flat deck
    loft(s, [ring(8, ST(7.55), 0.56, 0.34, 0.28, 0.40),
             ring(8, ST(8.60), 0.48, 0.34, 0.24, 0.36),
             ring(8, ST(10.20), 0.40, 0.30, 0.16, 0.30)], "skin")

    # ---- intake trunks. Slab section, outer face at 1.41 m half-width - the
    # widest thing on the forward aircraft.
    for side in (1.0, -1.0):
        secs = [rrect(ST(st), side * min(xi, xo), side * max(xi, xo), z0, z1)
                for st, xi, xo, z0, z1 in ((5.55, 0.70, 1.24, -0.58, 0.40),
                                           (6.10, 0.74, 1.40, -0.68, 0.50),
                                           (6.90, 0.80, 1.43, -0.70, 0.50),
                                           (8.10, 0.88, 1.41, -0.70, 0.42),
                                           (9.60, 0.95, 1.26, -0.62, 0.22))]
        if side < 0.0:
            secs = [list(reversed(p)) for p in secs]
        loft(s, secs, "skin")
        # recessed intake mouth: a dark slab set back inside the lip
        m = [rrect(ST(5.62), side * 0.76, side * 1.20, -0.52, 0.34),
             rrect(ST(6.30), side * 0.80, side * 1.14, -0.44, 0.28)]
        if side < 0.0:
            m = [list(reversed(p)) for p in m]
        loft(s, m, "dark")
        # splitter plate standing off the fuselage side on its bleed gap
        box(s, side * 0.665, ST(5.85), -0.08, 0.05, 0.90, 1.06, "skin")

    # ---- wings
    for side in (1.0, -1.0):
        loft(s, [foil(ST(le), ch, th, side * x, wing_z(x), True)
                 for x, le, ch, th in WING_STATIONS], "skin")

    # ---- stabilator
    for side in (1.0, -1.0):
        loft(s, [foil(ST(le), ch, th, side * x, stab_z(x), True)
                 for x, le, ch, th in STAB_STATIONS], "skin")

    # ---- fin
    loft(s, [foil(ST(le), ch, th, z, 0.0, False, sym=True)
             for z, le, ch, th in FIN_STATIONS], "skin")

    # ---- engine nozzles: twin round cans under the boom, the aft identity
    for side in (1.0, -1.0):
        revolve(s, [(ST(14.60), 0.0), (ST(14.60), 0.50), (ST(15.10), 0.47),
                    (ST(15.42), 0.43), (ST(15.46), 0.34), (ST(15.46), 0.0)],
                10, side * 0.55, -0.02, "nozzle")
        revolve(s, [(ST(15.62), 0.0), (ST(15.47), 0.31), (ST(15.44), 0.0)],
                10, side * 0.55, -0.02, "dark")
    return s


def build_stores():
    s = Shell()

    def pylon(x, y_off, depth, width, length):
        le, ch, th, pz = wing_at(x)
        top = pz - th * 0.34
        cy = ST(le) - ch * 0.42 + y_off
        v = [(x - width, cy - length * 0.5, top), (x + width, cy - length * 0.5, top),
             (x + width, cy + length * 0.5, top), (x - width, cy + length * 0.5, top),
             (x - width * 0.6, cy - length * 0.34, top - depth),
             (x + width * 0.6, cy - length * 0.34, top - depth),
             (x + width * 0.6, cy + length * 0.40, top - depth),
             (x - width * 0.6, cy + length * 0.40, top - depth)]
        s.add(v, [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4),
                  (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], "dark")
        return top - depth

    # centreline 600 gal tank on its shallow fuselage pylon
    box(s, 0.0, ST(10.6), -0.86, 0.34, 2.10, 0.30, "dark")
    revolve(s, [(ST(8.30), 0.0), (ST(8.55), 0.24), (ST(9.10), 0.40),
                (ST(12.70), 0.40), (ST(13.40), 0.26), (ST(13.70), 0.0)],
            8, 0.0, -1.28, "storegrey")

    for side in (1.0, -1.0):
        # inboard pylon + a pair of slick 500 lb bombs
        z = pylon(side * 2.35, 0.05, 0.34, 0.085, 1.40)
        for dx in (-0.24, 0.24):
            revolve(s, [(ST(10.20), 0.0), (ST(10.40), 0.14), (ST(10.80), 0.19),
                        (ST(12.30), 0.19), (ST(12.70), 0.12), (ST(12.85), 0.0)],
                    6, side * 2.35 + dx, z - 0.22, "olive")
        # outboard pylon, clean
        pylon(side * 4.10, 0.02, 0.26, 0.065, 0.86)
        # aft Sparrow well, half buried in the belly - very Phantom, very cheap
        revolve(s, [(ST(11.30), 0.0), (ST(11.55), 0.11), (ST(12.10), 0.15),
                    (ST(14.60), 0.15), (ST(14.95), 0.09), (ST(15.10), 0.0)],
                6, side * 0.62, -0.72, "storegrey")
    return s


def skin_z(x, up, bias=0.020):
    """Wing skin height at half-span |x| near mid-chord, where the insignia sits."""
    le, ch, th, pz = wing_at(x)
    return pz + (th * 0.38 + bias if up else -th * 0.284 - bias)


def build_markings():
    s = Shell()

    def insignia(x, up):
        # EVERY vertex samples the wing skin, so a decal that straddles the
        # dihedral crank does not bury its outboard bar inside the wing.
        le, ch, _, _ = wing_at(x)
        cy = ST(le) - ch * 0.55
        r_out, r_in = 0.58, 0.250
        pts = []
        for i in range(10):
            a = math.pi / 2 + TAU * i / 10.0
            rr = r_out if i % 2 == 0 else r_in
            pxx = x + rr * math.cos(a)
            pts.append((pxx, cy + rr * math.sin(a), skin_z(pxx, up, 0.026)))
        base = s.add_verts(pts + [(x, cy, skin_z(x, up, 0.026))])
        for i in range(10):
            t = (base + 10, base + i, base + (i + 1) % 10)
            s.face(t if up else (t[0], t[2], t[1]), "white")
        # ONE bar strip straight THROUGH the star, biased under it so the star
        # wins the overlap; two separate bars leave a notch that reads black.
        outer = r_out + 0.56
        edges = [x - outer + k * (2.0 * outer / 6.0) for k in range(7)]
        v = [s.add_verts([(a, cy - 0.165, skin_z(a, up, 0.020)),
                          (a, cy + 0.165, skin_z(a, up, 0.020))]) for a in edges]
        for k in range(6):
            b0, b1 = v[k], v[k + 1]
            q = (b0, b1, b1 + 1, b0 + 1)
            s.face(q if up else tuple(reversed(q)), "white")

    insignia(-3.05, True)
    insignia(3.05, False)
    return s


# ==================================================================== materials
def srgb(r, g, b):
    def c(v):
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return (c(r), c(g), c(b), 1.0)


MATERIALS = [
    ("f4_sea_tan", srgb(0.66, 0.54, 0.40), 0.86),
    ("f4_sea_green_med", srgb(0.35, 0.40, 0.27), 0.88),
    ("f4_sea_green_dark", srgb(0.21, 0.27, 0.21), 0.88),
    ("f4_underside_grey", srgb(0.74, 0.74, 0.71), 0.82),
    ("f4_black", srgb(0.07, 0.07, 0.07), 0.80),
    ("f4_canopy_glass", srgb(0.16, 0.21, 0.22), 0.22),
    ("f4_marking_white", srgb(0.90, 0.90, 0.88), 0.75),
    ("f4_store_grey", srgb(0.62, 0.63, 0.62), 0.55),
    ("f4_store_olive", srgb(0.27, 0.29, 0.20), 0.80),
    ("f4_nozzle_steel", srgb(0.26, 0.25, 0.24), 0.58),
]

# Voronoi seeds in the (|x|, y) plan. Seeds must NOT line up in y or the wings
# paint as spanwise stripes, and the wobble amplitude must stay well under the
# seed spacing or the blobs fragment into a checkerboard. ~2.4 m along the
# fuselage, ~1.8 m across the wing - the F-4 is a big aeroplane and the 558th
# TFS photo shows single patches covering a third of the fin.
CAMO_SEEDS = [
    (0.10, -1.60, "f4_sea_green_dark"), (0.45, -4.10, "f4_sea_tan"),
    (0.10, -6.50, "f4_sea_green_med"), (0.50, -9.00, "f4_sea_tan"),
    (0.15, -11.40, "f4_sea_green_dark"), (0.55, -13.80, "f4_sea_green_med"),
    (0.10, -16.20, "f4_sea_tan"), (0.40, -18.40, "f4_sea_green_dark"),
    (1.80, -10.20, "f4_sea_tan"), (3.40, -12.30, "f4_sea_green_dark"),
    (5.00, -12.60, "f4_sea_green_med"),
    (1.40, -17.60, "f4_sea_green_med"), (2.30, -18.90, "f4_sea_tan"),
]

TAG_MAT = {
    "dark": "f4_black", "glass": "f4_canopy_glass", "white": "f4_marking_white",
    "storegrey": "f4_store_grey", "olive": "f4_store_olive",
    "nozzle": "f4_nozzle_steel",
}


def camo_split(y):
    """Waterline of the grey/camo demarcation, wavy along the fuselage."""
    return -0.40 + 0.17 * math.sin(y * 1.05) + 0.07 * math.sin(y * 2.60 + 1.1)


def camo_for(p, n):
    # The radome is BLACK on a SEA-camo Phantom and it is a third of what makes
    # the nose read. Station 3.35 back from the tip, and only the nose cone.
    if p.y > ST(3.35) and p.z < 0.30:
        return "f4_black"
    if n.z > 0.50:
        # antiglare deck from the radome base to the windscreen
        if ST(3.72) > p.y > ST(3.10) and abs(p.x) < 0.60 and p.z > -0.30:
            return "f4_black"
    elif n.z < -0.35 or p.z < camo_split(p.y):
        return "f4_underside_grey"
    ax = abs(p.x)
    qx = ax + 0.40 * math.sin(p.y * 0.70 + ax * 0.50) + 0.13 * math.sin(p.y * 1.70 - ax * 1.00)
    qy = p.y + 0.40 * math.sin(ax * 0.65 - 0.60) + 0.13 * math.sin(ax * 1.60 + 1.70)
    best, bd = "f4_sea_tan", 1e9
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

    # recalc_face_normals only knows "outward" on a CLOSED shell. Run it on the
    # flat one-sided decals and it re-orients them at random, which renders as
    # black wedges inside the star. Those carry their winding from the builder.
    if recalc:
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        me.update()
        assert len(me.polygons) == len(shell.f), "%s: recalc changed face count" % name

    names = [m.name for m in mats]
    for m in mats:
        me.materials.append(m)
    for i, poly in enumerate(me.polygons):
        tag = shell.tag[i]
        if tag == "skin":
            mn = camo_for(poly.center, poly.normal) if paint else "f4_sea_tan"
        else:
            mn = TAG_MAT[tag]
        poly.material_index = names.index(mn)

    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob


def collider(name, boxes):
    s = Shell()
    for b in boxes:
        box(s, *b, "dark")
    me = bpy.data.meshes.new(name)
    me.from_pydata(s.v, [], s.f)
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    # Colliders must never appear in a render or they occlude the airframe and
    # every "look at it" check silently judges a box. glTF still exports them.
    ob.hide_render = True
    return ob


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


def wing_geometry():
    """Gross area and the quarter point of the mean aerodynamic chord."""
    area = 0.0
    mac_num = 0.0
    y_num = 0.0
    for i in range(len(WING_STATIONS) - 1):
        x0, l0, c0, _ = WING_STATIONS[i]
        x1, l1, c1, _ = WING_STATIONS[i + 1]
        dx = x1 - x0
        if dx <= 0.0:
            continue
        a = dx * (c0 + c1) * 0.5
        area += a
        mac_num += dx * (c0 * c0 + c0 * c1 + c1 * c1) / 3.0
        # STATIONS run aft-POSITIVE, so the quarter-chord point is LE + c/4.
        # Subtracting it (which is what the A-1 script does, correctly, because
        # it works in aft-NEGATIVE Blender y) puts the origin at the wing root
        # leading edge and hands the model a nose-heavy 2.4 m origin error.
        y_num += a * ((l0 + c0 * 0.25) + (l1 + c1 * 0.25)) * 0.5
    x_root, l_root, c_root, _ = WING_STATIONS[0]
    area_c = x_root * c_root
    gross = 2.0 * (area + area_c)
    mac = mac_num / area if area else 0.0
    qc_station = (y_num + area_c * (l_root + c_root * 0.25)) / (area + area_c)
    return gross, mac, qc_station


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    do_export = "--export" in argv
    render_dir = argv[argv.index("--render") + 1] if "--render" in argv else None

    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = make_materials()

    air = realise("F4_Airframe", build_airframe(), mats, True)
    stores = realise("F4_Stores", build_stores(), mats, False)
    marks = realise("F4_Markings", build_markings(), mats, False, recalc=False)

    cols = [
        collider("F4_Col_Hull-colonly",
                 [(0.0, ST(3.0), -0.30, 1.10, 4.40, 1.40),
                  (0.0, ST(7.6), -0.05, 2.70, 3.60, 1.70),
                  (0.0, ST(11.6), 0.00, 2.10, 4.40, 1.60),
                  (0.0, ST(14.9), 0.03, 2.00, 2.40, 1.40)]),
        collider("F4_Col_Wing-colonly", [(0.0, ST(11.2), -0.22, 11.71, 4.80, 0.44)]),
        collider("F4_Col_Aft-colonly",
                 [(0.0, ST(16.6), 1.55, 0.30, 5.40, 3.10),
                  (0.0, ST(17.9), -0.05, 4.92, 2.00, 1.30),
                  (0.0, ST(17.2), 0.26, 0.80, 3.60, 0.70)]),
    ]

    visible = [air, stores, marks]

    # ---- seat the model on its centre of mass.
    # NOT the ground line: cas_airplane.gd:355 puts the strafe muzzle 1.2 m BELOW
    # the node origin and calls it "slightly under the fuselage", and
    # collision_table.gd:131 carries y_offset 2.29 on a box 4.5 m tall - both
    # assume a centred origin. The ground line is reported below so it can be
    # parked. z 0 is already the fuselage centreline at the wing, so only y moves.
    gross, mac, qc_station = wing_geometry()
    shift = Vector((0.0, -ST(qc_station), 0.0))
    for ob in [air, stores, marks] + cols:
        for v in ob.data.vertices:
            v.co += shift
        ob.data.update()

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

    lo, hi = bounds(visible)
    alo, ahi = bounds([air])
    length = hi.y - lo.y
    print("\n--- MEASURED vs REAL (object space, metres) ------------------")
    print("  span      %7.3f  real %6.3f  d %+0.3f"
          % (hi.x - lo.x, REAL_SPAN, hi.x - lo.x - REAL_SPAN))
    print("  length    %7.3f  real %6.3f  d %+0.3f"
          % (length, REAL_LENGTH, length - REAL_LENGTH))
    stab_span = 2.0 * STAB_STATIONS[-1][0]
    print("  stab span %7.3f  real %6.3f  d %+0.3f"
          % (stab_span, REAL_STAB_SPAN, stab_span - REAL_STAB_SPAN))
    print("  wing area %7.2f  real %6.2f   MAC %.3f at quarter-chord station %.3f"
          % (gross, REAL_WING_AREA, mac, qc_station))
    print("  fin top above belly %6.3f  (the published %.2f m is a GEAR-DOWN"
          " three-point height and does NOT apply to this level, gear-up model)"
          % (ahi.z - alo.z, REAL_FIN_TOP_AGL))
    print("  outer panel dihedral %.1f deg, stabilator anhedral %.1f deg,"
          " dogtooth step %.3f m at x %.3f"
          % (math.degrees(DIHEDRAL_OUT), math.degrees(ANHEDRAL_STAB),
             WING_STATIONS[4][1] - WING_STATIONS[5][1], FOLD_X))
    print("  nose y %+0.3f  tail y %+0.3f  fin top z %+0.3f  belly z %+0.3f"
          % (hi.y, lo.y, ahi.z, alo.z))
    print("  bbox lo %s hi %s" % (tuple(round(c, 3) for c in lo),
                                  tuple(round(c, 3) for c in hi)))
    print("  origin = centre of mass (x centreline, y wing quarter MAC,"
          " z fuselage centreline)")
    print("  GROUND LINE at local z %+0.3f  (add this to park it)"
          % (GROUND_Z))
    print("  TOTAL VISIBLE TRIS %d" % tris)

    # ---- QC gates. A build that "ran without error" proves nothing.
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
        # F4_Markings is deliberately a set of flat one-sided decals, so every one
        # of its edges is non-manifold. Every other object must be watertight.
        nonman = 0 if ob.name == "F4_Markings" else sum(
            1 for e in bm.edges if not e.is_manifold)
        zero = sum(1 for f in bm.faces if f.calc_area() < 1e-7)
        bm.free()
        print("  %-26s ngons %d loose %d doubles %d non-manifold-edges %d zero-area %d"
              % (ob.name, ng, loose, dbl, nonman, zero))
        if ng or loose or dbl or zero:
            bad.append(ob.name)
    for p in marks.data.polygons:
        want = 1.0 if p.center.x < 0.0 else -1.0
        assert p.normal.z * want > 0.85, \
            "F4_Markings face at %s faces the wrong way (n.z %.2f)" % (
                tuple(round(c, 2) for c in p.center), p.normal.z)
    print("  marking decals: %d faces, all facing outward" % len(marks.data.polygons))
    mats_used = set()
    for ob in visible:
        for p in ob.data.polygons:
            mats_used.add(ob.data.materials[p.material_index].name)
    print("  materials actually painted: %d -> %s" % (len(mats_used), sorted(mats_used)))
    for m in bpy.data.materials:
        b = m.node_tree.nodes["Principled BSDF"]
        assert b.inputs["Metallic"].default_value == 0.0, "%s is metallic" % m.name
    # This is a JET: no node may look like a rotor to rotor_spin.gd.
    HINTS = ("prop", "spinner", "blade", "mainrotor", "rotor_hub", "new_blade",
             "rotor_flybar", "new_rotor", "tailrotor", "tailblade")
    for ob in visible + cols:
        low = ob.name.lower()
        assert not any(h in low for h in HINTS), \
            "%s trips a RotorSpin hint - a jet must spin nothing" % ob.name
    print("  no node trips a RotorSpin hint (rotor_spin.gd:23-25)")
    assert not bad, "QC FAILED on %s" % bad
    print("  QC PASS")

    if render_dir:
        do_render(render_dir, lo, hi)

    if do_export:
        blend = os.path.join(OUT_DIR, "f4_phantom_v2.blend")
        glb = os.path.join(OUT_DIR, "f4_phantom_v2.glb")
        for ob in bpy.data.objects:
            if ob.type in {"CAMERA", "LIGHT"}:
                bpy.data.objects.remove(ob, do_unlink=True)
        bpy.context.preferences.filepaths.save_version = 0   # project law: no .blend1
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
# azimuth 0 = camera on +X (starboard beam), 90 = ahead of the nose (+Y),
# 270 = astern. The rear view is not optional on this aeroplane: the X made by
# the drooped stabilator against the raised outer wing panels is the giveaway.
VIEWS = [("side", 0.0, 2.0, 1.95), ("front", 90.0, 4.0, 1.95),
         ("threequarter", 48.0, 14.0, 1.95), ("rear", 270.0, 6.0, 1.95),
         ("rear_quarter", 236.0, 16.0, 2.05), ("underside", 40.0, -24.0, 2.05),
         ("top", 90.0, 86.0, 3.15)]


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
    sun.rotation_euler = (math.radians(54.0), 0.0, math.radians(36.0))
    bpy.context.collection.objects.link(sun)

    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 60.0
    bpy.context.collection.objects.link(cam)
    sc.camera = cam

    tgt = (lo + hi) * 0.5
    span = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z)
    for name, az, el, k in VIEWS:
        a, e = math.radians(az), math.radians(el)
        cam.location = tgt + Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a),
                                     math.sin(e))) * (span * k)
        dv = tgt - Vector(cam.location)
        cam.rotation_euler = dv.to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(out_dir, "f4v2_%s.png" % name)
        bpy.ops.render.render(write_still=True)
        print("RENDER %s" % sc.render.filepath)


main()
