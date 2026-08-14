"""Build the A-1H/J Skyraider v2 airframe from scratch and export it.

    blender -b --factory-startup --python tools/build_a1_skyraider_v2.py -- [--export] [--render DIR]

Frame contract: nose at Blender +Y (Godot -Z) at identity, +Z up, real metres.
Origin sits on the ground line directly under the wing quarter-chord.
The propeller is its own object `A1_Prop` with IDENTITY rotation, so its Godot
local Z runs down the thrust line - the axis RotorSpin spins a PROP_HINTS node
about (scripts/vehicles/rotor_spin.gd:25,76).
"""

import bpy, bmesh, math, os, sys
from mathutils import Vector

TAU = math.tau
PROJ = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT_DIR = os.path.join(PROJ, "assets", "us", "aircraft")

# ---------------------------------------------------------------- real numbers
REAL_LENGTH = 11.84
REAL_SPAN = 15.25
REAL_PROP_D = 4.115

# ---------------------------------------------------------------- design datum
THRUST_Z = 1.42
NOSE_Y = 6.00
TAIL_Y = -5.84
HUB_Y = 5.45
WING_LE_ROOT = 1.40
WING_ROOT_CHORD = 3.35
WING_PLANE_Z = 0.86
HALF_SPAN = REAL_SPAN * 0.5
CRANK_X = 2.90
DIHEDRAL_OUT = math.radians(7.0)
NSIDE = 12


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


def ring(n, y, cz, hw, up, dn):
    pts = []
    for i in range(n):
        a = TAU * i / n
        s, c = math.sin(a), math.cos(a)
        pts.append((hw * c, y, cz + (up if s >= 0.0 else dn) * s))
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
    """Bridge equal-length rings into quads. Returns the base index of each ring."""
    n = len(rings[0])
    bases = [shell.add_verts(r) for r in rings]
    for k in range(len(rings) - 1):
        bridge(shell, n, bases[k], bases[k + 1], tag)
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
# Straight LE, all the taper in the TE, plus a short raked segment at the very
# tip for the rounded corner. Chords tuned so the gross area lands near the real
# 37.19 m2 - a pure root-to-tip trapezoid at 3.50 m root overshoots it by 7.6%.
WING_STATIONS = [
    (0.30, WING_LE_ROOT, WING_ROOT_CHORD, 0.40),
    (1.60, 1.39, 3.10, 0.37),
    (CRANK_X, 1.37, 2.86, 0.33),
    (5.20, 1.22, 2.16, 0.23),
    (7.30, 1.08, 1.50, 0.14),
    (HALF_SPAN, 1.02, 1.05, 0.09),
]


def wing_z(x):
    return WING_PLANE_Z + max(0.0, x - CRANK_X) * math.tan(DIHEDRAL_OUT)


def wing_at(x):
    for i in range(len(WING_STATIONS) - 1):
        x0, l0, c0, t0 = WING_STATIONS[i]
        x1, l1, c1, t1 = WING_STATIONS[i + 1]
        if x0 - 1e-6 <= x <= x1 + 1e-6:
            u = (x - x0) / (x1 - x0)
            return (l0 + (l1 - l0) * u, c0 + (c1 - c0) * u,
                    t0 + (t1 - t0) * u, wing_z(x))
    x1, l1, c1, t1 = WING_STATIONS[-1]
    return l1, c1, t1, wing_z(x1)


# ================================================================ the airframe
# Proportions scaled off the Dyess AFB left-side photo at 82.4 px/m (aircraft
# length 11.84 m spans 975 px), so the cowl length, fin height and canopy step
# are measured off the aeroplane rather than guessed.
FUSE_STATIONS = [
    (5.05, 1.36, 0.86, 0.84, 0.90),   # cowl lip
    (4.60, 1.36, 0.87, 0.85, 0.91),   # cowl max
    (3.90, 1.36, 0.87, 0.85, 0.91),
    (3.30, 1.36, 0.85, 0.83, 0.90),   # cowl flap trailing edge
    (3.16, 1.34, 0.72, 0.74, 0.86),   # firewall STEP - the barrel ends here
    (2.70, 1.32, 0.70, 0.72, 0.86),
    (2.10, 1.31, 0.71, 0.73, 0.87),
    (1.40, 1.30, 0.73, 0.75, 0.88),
    (0.60, 1.29, 0.73, 0.75, 0.87),
    (-0.30, 1.28, 0.70, 0.72, 0.83),
    (-1.40, 1.28, 0.63, 0.66, 0.72),
    (-2.60, 1.33, 0.52, 0.55, 0.54),
    (-3.70, 1.38, 0.41, 0.44, 0.40),
    (-4.70, 1.43, 0.29, 0.32, 0.27),
    (-5.30, 1.47, 0.18, 0.21, 0.17),
    (-5.60, 1.50, 0.09, 0.11, 0.09),
]


def build_airframe():
    s = Shell()

    # ---- fuselage barrel; nose left open, the cowl annulus closes it
    bases = loft(s, [ring(NSIDE, *st) for st in FUSE_STATIONS], "skin",
                 cap_first=False, cap_last=True)

    # ---- cowl inlet: annulus around the spinner, then a recessed duct
    lip = bases[0]
    inner = s.add_verts([(s.v[lip + i][0] * 0.60, 5.05,
                          1.34 + (s.v[lip + i][2] - 1.34) * 0.60) for i in range(NSIDE)])
    bridge(s, NSIDE, inner, lip, "skin")
    duct = s.add_verts([(s.v[lip + i][0] * 0.50, 4.60,
                         1.36 + (s.v[lip + i][2] - 1.36) * 0.50) for i in range(NSIDE)])
    bridge(s, NSIDE, duct, inner, "dark")
    fan_cap(s, duct, NSIDE, "dark")

    # ---- chin: oil-cooler / carburettor duct, the deepest mass up front
    chin = [(5.06, 0.62, 0.46, 0.22), (4.50, 0.50, 0.55, 0.34),
            (3.60, 0.48, 0.56, 0.35), (2.80, 0.52, 0.50, 0.31),
            (2.00, 0.68, 0.38, 0.20), (1.30, 0.84, 0.24, 0.10)]
    loft(s, [ring(8, y, cz, hw, hd, hd) for y, cz, hw, hd in chin], "skin")

    # ---- windscreen + canopy greenhouse. Lower edge is BURIED in the fuselage:
    # a canopy whose base floats above the spine reads as a roll bar, not a cockpit.
    loft(s, [ring(8, 2.66, 1.98, 0.40, 0.06, 0.30),
             ring(8, 2.20, 2.06, 0.41, 0.36, 0.36),
             ring(8, 1.70, 2.06, 0.45, 0.42, 0.36),
             ring(8, 0.55, 2.04, 0.45, 0.42, 0.36),
             ring(8, -0.05, 1.98, 0.36, 0.30, 0.30)], "glass")
    loft(s, [ring(8, -0.05, 1.95, 0.38, 0.22, 0.30),
             ring(8, -1.00, 1.88, 0.34, 0.12, 0.30),
             ring(8, -2.10, 1.78, 0.26, 0.06, 0.30)], "skin")

    # ---- wings
    for side in (1.0, -1.0):
        secs = [foil(le, ch, th, side * x, wing_z(x), True)
                for x, le, ch, th in WING_STATIONS]
        loft(s, secs, "skin")

    # ---- horizontal stabiliser
    stab = [(0.42, -3.45, 1.60, 0.19, 1.46),
            (1.32, -3.63, 1.32, 0.14, 1.50),
            (2.21, -3.80, 1.00, 0.08, 1.54)]
    for side in (1.0, -1.0):
        loft(s, [foil(le, ch, th, side * x, z, True) for x, le, ch, th, z in stab], "skin")

    # ---- vertical fin, scaled off the tail crop of the Dyess photo at 118.7 px/m:
    # root chord 2.31 m, tip chord 1.44 m, 1.66 m above the aft spine, LEADING EDGE
    # RAKED ONLY 29 deg. A 45 deg rake turns it into a shark fin - that was the
    # single biggest silhouette error in the first two passes. The rudder trailing
    # edge rakes slightly AFT going up, so the aftmost point is the fin tip.
    # The lowest station is buried in the boom so the dorsal fillet emerges from
    # the skin instead of being modelled separately.
    fin = [(1.50, -2.55, 3.24, 0.28), (1.85, -3.48, 2.31, 0.24),
           (2.40, -3.79, 2.02, 0.20), (2.95, -4.10, 1.73, 0.15),
           (3.30, -4.29, 1.56, 0.10), (3.44, -4.36, 1.50, 0.06),
           (3.49, -4.52, 1.30, 0.03)]
    loft(s, [foil(le, ch, th, z, 0.0, False, sym=True) for z, le, ch, th in fin], "skin")

    # ---- tailwheel bay / arrestor hook fairing
    box(s, 0.0, -3.95, 0.98, 0.13, 1.00, 0.30, "storegrey")

    # ---- exhaust stacks on the lower cowl sides
    for side in (1.0, -1.0):
        for k, y in enumerate((3.65, 3.25)):
            box(s, side * 0.72, y, 0.84 + k * 0.06, 0.22, 0.34, 0.20, "dark")

    # ---- 20 mm cannon muzzles in the wing leading edge
    for side in (1.0, -1.0):
        for x in (1.75, 2.45):
            le, ch, th, pz = wing_at(x)
            revolve(s, [(le - 0.08, 0.0), (le - 0.06, 0.055),
                        (le + 0.30, 0.050), (le + 0.32, 0.0)], 6, side * x, pz, "dark")
    return s


def build_stores():
    s = Shell()

    def pylon(x, y_off, depth, width, length):
        le, ch, th, pz = wing_at(abs(x))
        top = pz - th * 0.36
        cy = le - ch * 0.45 + y_off
        v = [(x - width, cy - length * 0.5, top), (x + width, cy - length * 0.5, top),
             (x + width, cy + length * 0.5, top), (x - width, cy + length * 0.5, top),
             (x - width * 0.6, cy - length * 0.34, top - depth),
             (x + width * 0.6, cy - length * 0.34, top - depth),
             (x + width * 0.6, cy + length * 0.40, top - depth),
             (x - width * 0.6, cy + length * 0.40, top - depth)]
        s.add(v, [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4),
                  (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], "dark")
        return top - depth

    # centreline 300 gal tank
    box(s, 0.0, -1.00, 0.42, 0.30, 1.60, 0.32, "dark")
    revolve(s, [(1.30, 0.0), (1.05, 0.20), (0.55, 0.33), (-1.35, 0.33),
                (-2.05, 0.22), (-2.35, 0.0)], 8, 0.0, 0.02, "storegrey")

    for side in (1.0, -1.0):
        z = pylon(side * 1.62, 0.05, 0.30, 0.075, 0.90)
        revolve(s, [(1.42, 0.0), (1.20, 0.17), (0.90, 0.24), (-0.95, 0.24),
                    (-1.28, 0.17), (-1.44, 0.0)], 8, side * 1.62, z - 0.24, "storegrey")
        z = pylon(side * 2.62, 0.02, 0.28, 0.070, 0.80)
        revolve(s, [(1.00, 0.0), (0.85, 0.14), (0.66, 0.22), (-0.98, 0.22),
                    (-1.02, 0.20), (-1.06, 0.0)], 8, side * 2.62, z - 0.22, "olive")
        for x in (3.55, 4.40, 5.20, 5.95, 6.65):
            pylon(side * x, 0.0, 0.17, 0.045, 0.44)
    return s


def build_prop():
    """Local origin at the hub; the spin axis is local Y (Godot local Z)."""
    s = Shell()
    revolve(s, [(0.56, 0.0), (0.46, 0.16), (0.24, 0.28),
                (-0.06, 0.30), (-0.12, 0.0)], 10, 0.0, 0.0, "dark")
    r_tip = REAL_PROP_D * 0.5
    for k in range(4):
        a = TAU * k / 4.0 + math.radians(45.0)   # X clock: no blade dead vertical
        ca, sa = math.cos(a), math.sin(a)
        secs = []
        for r, chord, thick, pitch in ((0.24, 0.32, 0.10, math.radians(34.0)),
                                       (0.78, 0.46, 0.075, math.radians(24.0)),
                                       (1.55, 0.42, 0.045, math.radians(13.0)),
                                       (r_tip, 0.22, 0.022, math.radians(8.0))):
            cp, sp = math.cos(pitch), math.sin(pitch)
            pts = []
            for fc, ft in ((-0.5, 0.0), (-0.2, 0.5), (0.25, 0.42),
                           (0.5, 0.0), (0.25, -0.42), (-0.2, -0.5)):
                u, w = fc * chord, ft * thick
                du = u * cp - w * sp
                dy = u * sp + w * cp
                pts.append((ca * r - sa * du, dy, sa * r + ca * du))
            secs.append(pts)
        loft(s, secs, "blade")
    return s


def skin_z(x, up, bias=0.022):
    """Wing skin height at half-span |x|, at ~52% chord where the insignia sits."""
    le, ch, th, pz = wing_at(abs(x))
    return pz + (th * 0.38 + bias if up else -th * 0.284 - bias)


def build_markings():
    s = Shell()

    def insignia(x, up):
        # EVERY vertex samples the wing skin. A flat decal spanning the dihedral
        # crank buries its outboard bar inside the wing - the outer bar of the
        # upper insignia vanished exactly that way on the first attempt.
        le, ch, _, _ = wing_at(abs(x))
        cy = le - ch * 0.52
        r_out, r_in = 0.50, 0.205
        pts = []
        for i in range(10):
            a = math.pi / 2 + TAU * i / 10.0
            rr = r_out if i % 2 == 0 else r_in
            px = x + rr * math.cos(a)
            pts.append((px, cy + rr * math.sin(a), skin_z(px, up, 0.028)))
        base = s.add_verts(pts + [(x, cy, skin_z(x, up, 0.028))])
        for i in range(10):
            t = (base + 10, base + i, base + (i + 1) % 10)
            s.face(t if up else (t[0], t[2], t[1]), "white")
        # ONE bar strip straight THROUGH the star, biased 0.006 under it so the
        # star wins the overlap. Two separate bars starting at the star's inner
        # radius left a notch that rendered as a black wedge, and building them as
        # mirrored strips flipped the winding on the outboard one.
        outer = r_out + 0.72
        edges = [x - outer + k * (2.0 * outer / 6.0) for k in range(7)]
        v = [s.add_verts([(a, cy - 0.19, skin_z(a, up, 0.022)),
                          (a, cy + 0.19, skin_z(a, up, 0.022))]) for a in edges]
        for k in range(6):
            b0, b1 = v[k], v[k + 1]
            q = (b0, b1, b1 + 1, b0 + 1)
            s.face(q if up else tuple(reversed(q)), "white")

    # Outboard of the fuselage AND of the inboard stores: at x = 2.05 the inner bar
    # ran back into the fuselage skin and the insignia read as a smear.
    insignia(-3.15, True)
    insignia(3.15, False)
    return s


# ==================================================================== materials
def srgb(r, g, b):
    def c(v):
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return (c(r), c(g), c(b), 1.0)


MATERIALS = [
    ("a1_sea_tan", srgb(0.66, 0.54, 0.40), 0.86),
    ("a1_sea_green_med", srgb(0.35, 0.40, 0.27), 0.88),
    ("a1_sea_green_dark", srgb(0.21, 0.27, 0.21), 0.88),
    ("a1_underside_grey", srgb(0.74, 0.74, 0.71), 0.82),
    ("a1_black", srgb(0.07, 0.07, 0.07), 0.80),
    ("a1_canopy_glass", srgb(0.16, 0.21, 0.22), 0.22),
    ("a1_marking_white", srgb(0.90, 0.90, 0.88), 0.75),
    ("a1_store_grey", srgb(0.62, 0.63, 0.62), 0.55),
    ("a1_store_olive", srgb(0.27, 0.29, 0.20), 0.80),
    ("a1_prop_blade", srgb(0.10, 0.10, 0.10), 0.62),
]

# Voronoi seeds in the (|x|, y) plan, queried through a two-octave wobble so the
# patch boundaries come out wavy. Seeds must NOT line up in y or the wings paint
# as spanwise stripes instead of blobs - that was the first camo pass.
# Seed spacing sets the patch size and the wobble must stay well under it, or the
# blobs fragment into a checkerboard - which is the "noise" the brief rules out.
# ~1.9 m along the fuselage, ~1.4 m across the wing.
CAMO_SEEDS = [
    (0.00, 5.10, "a1_sea_green_dark"), (0.15, 3.40, "a1_sea_tan"),
    (0.30, 1.40, "a1_sea_green_med"), (0.20, -0.60, "a1_sea_tan"),
    (0.30, -2.60, "a1_sea_green_dark"), (0.20, -4.30, "a1_sea_green_med"),
    (0.35, -5.50, "a1_sea_tan"),
    (1.80, 0.80, "a1_sea_tan"), (3.10, -0.80, "a1_sea_green_dark"),
    (4.50, 0.60, "a1_sea_green_med"), (5.90, -0.40, "a1_sea_tan"),
    (7.20, 0.40, "a1_sea_green_dark"),
]

TAG_MAT = {
    "dark": "a1_black", "glass": "a1_canopy_glass", "white": "a1_marking_white",
    "storegrey": "a1_store_grey", "olive": "a1_store_olive", "blade": "a1_prop_blade",
}


def camo_split(y):
    return 1.02 + 0.12 * math.sin(y * 1.55) + 0.06 * math.sin(y * 3.7 + 1.1)


def camo_for(p, n):
    # An UPWARD-facing polygon is never grey. Without this the wing upper surface
    # (z ~1.07) crosses the demarcation line and paints a white blob mid-wing.
    if n.z > 0.50:
        if 2.55 < p.y < 3.35 and abs(p.x) < 0.46 and p.z > 1.85:
            return "a1_black"          # antiglare deck ahead of the windscreen
    elif n.z < -0.35 or p.z < camo_split(p.y):
        return "a1_underside_grey"
    ax = abs(p.x)
    qx = ax + 0.45 * math.sin(p.y * 0.80 + ax * 0.55) + 0.15 * math.sin(p.y * 1.90 - ax * 1.10)
    qy = p.y + 0.45 * math.sin(ax * 0.75 - 0.60) + 0.15 * math.sin(ax * 1.80 + 1.70)
    best, bd = "a1_sea_tan", 1e9
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
    # flat one-sided decals and it re-orients them at random - which showed up as
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
            mn = camo_for(poly.center, poly.normal) if paint else "a1_sea_tan"
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
    # every "look at it" check silently judges a box. glTF still exports them:
    # export_scene.gltf's use_visible/use_renderable both default False.
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


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    do_export = "--export" in argv
    render_dir = argv[argv.index("--render") + 1] if "--render" in argv else None

    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = make_materials()

    air = realise("A1_Airframe", build_airframe(), mats, True)
    stores = realise("A1_Stores", build_stores(), mats, False)
    marks = realise("A1_Markings", build_markings(), mats, False, recalc=False)
    prop = realise("A1_Prop", build_prop(), mats, False)
    prop.location = (0.0, HUB_Y, THRUST_Z)

    cols = [
        collider("A1_Col_Hull-colonly",
                 [(0.0, 4.30, 1.34, 1.72, 1.60, 1.72),
                  (0.0, 1.60, 1.32, 1.45, 4.00, 1.58),
                  (0.0, -1.30, 1.30, 1.32, 2.10, 1.42),
                  (0.0, -3.95, 1.38, 0.86, 3.20, 1.00)]),
        collider("A1_Col_Wing-colonly", [(0.0, 0.05, 0.92, 15.25, 2.80, 0.46)]),
        collider("A1_Col_Aft-colonly",
                 [(0.0, -4.55, 2.95, 0.26, 2.70, 2.00),
                  (0.0, -4.25, 1.53, 4.42, 1.75, 0.22)]),
    ]

    visible = [air, stores, marks, prop]

    # ---- seat the model on its centre of mass.
    # x = centreline, y = wing quarter chord, z = fuselage centreline at the wing.
    # NOT the ground line: cas_airplane.gd:355 puts the strafe muzzle 1.2 m BELOW
    # the node origin ("slightly under the fuselage") and collision_table.gd:72
    # carries y_offset 0.30 for a box 5.1 m tall - both assume a centred origin.
    # The ground line is reported below so the model can still be parked.
    lo, _ = bounds(visible)
    qc_y = WING_LE_ROOT - WING_ROOT_CHORD * 0.25 - 0.10
    com_z = 1.29
    shift = Vector((0.0, -qc_y, -com_z))
    for ob in [air, stores, marks] + cols:
        for v in ob.data.vertices:
            v.co += shift
        ob.data.update()
    prop.location = (0.0, HUB_Y + shift.y, THRUST_Z + shift.z)

    # ---- measure
    tris = 0
    print("\n--- MESH INVENTORY -------------------------------------------")
    for ob in visible + cols:
        ob.data.calc_loop_triangles()
        t = len(ob.data.loop_triangles)
        ngons = sum(1 for p in ob.data.polygons if len(p.vertices) > 4)
        loose = sum(1 for v in ob.data.vertices if not any(
            v.index in p.vertices for p in ob.data.polygons)) if len(ob.data.vertices) < 400 else -1
        if not ob.name.endswith("-colonly"):
            tris += t
        print("  %-26s tris %5d verts %5d ngons %d loose %s loc %s"
              % (ob.name, t, len(ob.data.vertices), ngons, loose,
                 tuple(round(c, 3) for c in ob.location)))

    lo, hi = bounds(visible)
    alo, ahi = bounds([air])
    plo, phi = bounds([prop])
    # A 45-degree blade clock makes the bbox understate the disc: measure the true
    # tip radius in the plane normal to the thrust line instead.
    prop_d = 2.0 * max(math.hypot(v.co.x, v.co.z) for v in prop.data.vertices)
    length = hi.y - lo.y                       # spinner tip to rudder trailing edge
    fin_h = ahi.z - alo.z                       # fin top above the belly, level
    print("\n--- MEASURED vs REAL (object space, metres) ------------------")
    print("  span      %7.3f  real %6.3f  d %+0.3f" % (hi.x - lo.x, REAL_SPAN, hi.x - lo.x - REAL_SPAN))
    print("  length    %7.3f  real %6.3f  d %+0.3f" % (length, REAL_LENGTH, length - REAL_LENGTH))
    print("  prop dia  %7.3f  real %6.3f  d %+0.3f" % (prop_d, REAL_PROP_D, prop_d - REAL_PROP_D))
    print("  airframe fin-top-above-belly %6.3f  (4.780 is the 3-point gear-DOWN figure)" % fin_h)
    print("  full height incl. prop arc + stores %6.3f" % (hi.z - lo.z))
    print("  nose y %+0.3f  tail y %+0.3f  fin top z %+0.3f  belly z %+0.3f"
          % (hi.y, lo.y, ahi.z, alo.z))
    print("  bbox lo %s hi %s" % (tuple(round(c, 3) for c in lo), tuple(round(c, 3) for c in hi)))
    print("  origin = centre of mass (x=0, y=wing quarter chord, z=fuselage centreline)")
    print("  GROUND LINE at local z %+0.3f  (add this to park it)" % lo.z)
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
        # A1_Markings is deliberately a set of flat one-sided decals, so every one
        # of its edges is non-manifold. Every other object must be watertight.
        nonman = 0 if ob.name == "A1_Markings" else sum(
            1 for e in bm.edges if not e.is_manifold)
        zero = sum(1 for f in bm.faces if f.calc_area() < 1e-7)
        bm.free()
        print("  %-26s ngons %d loose %d doubles %d non-manifold-edges %d zero-area %d"
              % (ob.name, ng, loose, dbl, nonman, zero))
        if ng or loose or dbl or zero:
            bad.append(ob.name)
    # Decal facing: upper insignia (left wing, x<0) must face UP, lower (x>0) DOWN.
    # A backfacing decal renders as a black wedge and nothing else catches it.
    for p in marks.data.polygons:
        want = 1.0 if p.center.x < 0.0 else -1.0
        assert p.normal.z * want > 0.85, \
            "A1_Markings face at %s faces the wrong way (n.z %.2f)" % (
                tuple(round(c, 2) for c in p.center), p.normal.z)
    print("  marking decals: %d faces, all facing outward" % len(marks.data.polygons))
    mats_used = set()
    for ob in visible:
        for i, p in enumerate(ob.data.polygons):
            mats_used.add(ob.data.materials[p.material_index].name)
    print("  materials actually painted: %d -> %s" % (len(mats_used), sorted(mats_used)))
    for m in bpy.data.materials:
        b = m.node_tree.nodes["Principled BSDF"]
        assert b.inputs["Metallic"].default_value == 0.0, "%s is metallic" % m.name
    assert not bad, "QC FAILED on %s" % bad
    # wing area, as a check on the planform rather than just the span
    area = 0.0
    for i in range(len(WING_STATIONS) - 1):
        x0, _, c0, _ = WING_STATIONS[i]
        x1, _, c1, _ = WING_STATIONS[i + 1]
        area += (x1 - x0) * (c0 + c1) * 0.5
    area = 2.0 * (area + WING_STATIONS[0][0] * WING_STATIONS[0][2])
    print("  wing area (gross, incl. carry-through) %.2f m2   real 37.19" % area)
    print("  QC PASS")

    if render_dir:
        do_render(render_dir, lo, hi)

    if do_export:
        blend = os.path.join(OUT_DIR, "a1_skyraider_v2.blend")
        glb = os.path.join(OUT_DIR, "a1_skyraider_v2.glb")
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
# azimuth 0 = camera on +X (starboard beam), 90 = ahead of the nose (+Y).
VIEWS = [("side", 0.0, 2.0), ("front", 90.0, 4.0), ("threequarter", 46.0, 14.0),
         ("rear_quarter", 232.0, 12.0), ("underside", 40.0, -22.0),
         ("top", 20.0, 78.0)]


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
    for name, az, el in VIEWS:
        a, e = math.radians(az), math.radians(el)
        cam.location = tgt + Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a),
                                     math.sin(e))) * (span * 1.55)
        dv = tgt - Vector(cam.location)
        cam.rotation_euler = dv.to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(out_dir, "a1v2_%s.png" % name)
        bpy.ops.render.render(write_still=True)
        print("RENDER %s" % sc.render.filepath)


main()
