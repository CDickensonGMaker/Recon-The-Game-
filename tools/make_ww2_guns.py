# make_ww2_guns.py - procedural PSX builds of the WW2-era smallarms roster
# (Caleb: "identify any other WW2 era weapons called in the project and
# continue to make them within this window").
# Armory conventions (weapons_us.blend / weapons_v1.blend): muzzle at LOW X,
# butt at HIGH X, ~100-260 verts/gun, shared material palette
# (Parkerized/Walnut/BluedSteel/AluMag/gunmetal), GripL empty marks the
# support hand (Caleb's convention, adopted 2026-07-11).
# Usage (in-session): exec(open(r"...\make_ww2_guns.py").read()); build_thompson()
import bpy
import bmesh
import math
from mathutils import Vector


def _mat(name, fallback_rgba):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Base Color"].default_value = fallback_rgba
            bsdf.inputs["Roughness"].default_value = 0.6
    return m


def _palette():
    return {
        "metal": _mat("Parkerized", (0.10, 0.10, 0.11, 1)),
        "blued": _mat("BluedSteel", (0.06, 0.07, 0.09, 1)),
        "wood": _mat("Walnut", (0.24, 0.13, 0.06, 1)),
        "mag": _mat("AluMag", (0.35, 0.35, 0.36, 1)),
        "dark": _mat("gunmetal", (0.15, 0.15, 0.16, 1)),
    }


class GunBuilder:
    def __init__(self, name):
        self.name = name
        self.verts = []
        self.faces = []
        self.mats = []          # per-face material KEY
        self.palette = _palette()

    def box(self, cx, cy, cz, sx, sy, sz, mat, skew_rear_z=0.0, taper_rear=1.0, rake_x=0.0):
        """Axis-aligned box centered (cx,cy,cz); optional rear (high-x) skew
        down + y-taper for stocks; rake_x pushes the BOTTOM face back (+x)
        for raked pistol grips."""
        b = len(self.verts)
        hx, hy, hz = sx / 2.0, sy / 2.0, sz / 2.0
        for xi, x in ((0, cx - hx), (1, cx + hx)):
            ty = hy * (taper_rear if xi else 1.0)
            dz = skew_rear_z if xi else 0.0
            for y in (cy - ty, cy + ty):
                for z in (cz - hz + dz, cz + hz + dz):
                    xx = x + (rake_x if (z - cz - dz) < 0 else 0.0)
                    self.verts.append((xx, y, z))
        # faces (quads) - consistent winding good enough for PSX flat shade
        f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 2, 6, 4), (1, 5, 7, 3), (0, 4, 5, 1), (2, 3, 7, 6)]
        for q in f:
            self.faces.append([b + i for i in q])
            self.mats.append(mat)

    def profile(self, pts, y_half, mat, taper_y=1.0):
        """Extrude a side-silhouette polygon (list of (x,z), CCW) across Y.
        THE tool for curved gun furniture - stocks/receivers get their real
        silhouette instead of skewed boxes (Caleb: 'way more curvature and a
        complex top'). taper_y narrows the rear half slightly."""
        b = len(self.verts)
        n = len(pts)
        xs = [p[0] for p in pts]
        x_min, x_max = min(xs), max(xs)
        span = max(x_max - x_min, 1e-6)
        for side, ysign in ((0, -1.0), (1, 1.0)):
            for (x, z) in pts:
                t = (x - x_min) / span
                y = ysign * y_half * (1.0 + (taper_y - 1.0) * t)
                self.verts.append((x, y, z))
        # two silhouette ngons (Blender tessellates) + side walls
        self.faces.append(list(range(b, b + n))[::-1])
        self.mats.append(mat)
        self.faces.append(list(range(b + n, b + 2 * n)))
        self.mats.append(mat)
        for i in range(n):
            j = (i + 1) % n
            self.faces.append([b + i, b + j, b + n + j, b + n + i])
            self.mats.append(mat)

    def cyl_y(self, cx, y0, y1, cz, r, mat, seg=8):
        """Cylinder along Y (drum magazines: a disc facing sideways)."""
        b = len(self.verts)
        for y in (y0, y1):
            for i in range(seg):
                a = i / seg * math.tau
                self.verts.append((cx + math.cos(a) * r, y, cz + math.sin(a) * r))
        for i in range(seg):
            j = (i + 1) % seg
            self.faces.append([b + i, b + j, b + seg + j, b + seg + i])
            self.mats.append(mat)
        self.faces.append([b + i for i in range(seg)])
        self.mats.append(mat)
        self.faces.append([b + seg + i for i in range(seg - 1, -1, -1)])
        self.mats.append(mat)

    def cyl_x(self, x0, x1, cy, cz, r, mat, seg=6):
        """Cylinder along X between x0..x1."""
        b = len(self.verts)
        for x in (x0, x1):
            for i in range(seg):
                a = i / seg * math.tau
                self.verts.append((x, cy + math.cos(a) * r, cz + math.sin(a) * r))
        for i in range(seg):
            j = (i + 1) % seg
            self.faces.append([b + i, b + j, b + seg + j, b + seg + i])
            self.mats.append(mat)
        self.faces.append([b + i for i in range(seg)])
        self.mats.append(mat)
        self.faces.append([b + seg + i for i in range(seg - 1, -1, -1)])
        self.mats.append(mat)

    def realize(self, rack_pos, grip_l=None):
        me = bpy.data.meshes.new(self.name)
        mat_keys = list(dict.fromkeys(self.mats))
        for k in mat_keys:
            me.materials.append(self.palette[k])
        idx = {k: i for i, k in enumerate(mat_keys)}
        me.from_pydata([Vector(v) for v in self.verts], [], self.faces)
        for p, k in zip(me.polygons, self.mats):
            p.material_index = idx[k]
        me.update()
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        ob.location = rack_pos
        if grip_l is not None:
            e = bpy.data.objects.new(self.name + "_GripL", None)
            e.empty_display_size = 0.03
            bpy.context.scene.collection.objects.link(e)
            e.parent = ob
            e.location = grip_l
        print("[WW2] built %s: %d verts, %d faces at %s" % (self.name, len(self.verts), len(self.faces), tuple(rack_pos)))
        return ob


def build_thompson():
    """Thompson M1A1 - the Vietnam-correct model (ARVN/advisors/SF; VC carried
    captures). Research-proportioned: 813mm overall, 248mm exposed barrel,
    310mm receiver slab (deep + tall), trigger at 58% from muzzle, mag just
    ahead of the guard, 30rd stick 180mm below frame, heel drop ~80mm below
    bore, separate 27deg-raked grip = the double-hump silhouette. Fins/bolt/
    port are texture-tier (silhouette law) - not modeled."""
    g = GunBuilder("Thompson_SMG")
    BORE = 0.062
    g.cyl_x(0.00, 0.252, 0, BORE, 0.0115, "blued")                    # smooth barrel (M1A1)
    g.box(0.014, 0, BORE + 0.020, 0.016, 0.007, 0.020, "blued")       # front sight blade
    g.box(0.155, 0, BORE - 0.030, 0.175, 0.046, 0.036, "wood")        # horizontal forend
    g.box(0.403, 0, 0.055, 0.310, 0.041, 0.058, "metal")              # receiver slab 7.5:1
    g.box(0.472, 0, 0.010, 0.180, 0.038, 0.036, "metal")              # lower frame/trigger group
    g.box(0.435, 0.030, 0.058, 0.026, 0.018, 0.015, "metal")          # charging knob RIGHT side
    g.box(0.545, 0, 0.092, 0.024, 0.030, 0.014, "metal")              # L-sight with ears
    g.box(0.405, 0, -0.098, 0.040, 0.025, 0.185, "mag")               # 30rd stick, just ahead of guard
    g.box(0.475, 0, -0.020, 0.065, 0.010, 0.010, "metal")             # trigger guard bar
    g.box(0.468, 0, 0.000, 0.009, 0.007, 0.026, "metal")              # trigger @58%
    g.box(0.520, 0, -0.052, 0.042, 0.030, 0.078, "wood", rake_x=0.040)  # raked grip (separate hump)
    g.box(0.678, 0, 0.030, 0.245, 0.044, 0.058, "wood",
          skew_rear_z=-0.062, taper_rear=0.85)                        # buttstock, REAL droop
    g.box(0.806, 0, -0.034, 0.016, 0.046, 0.062, "metal")             # buttplate
    return g.realize(Vector((0.0, 4.0, 0.15)), grip_l=Vector((0.155, 0.0, 0.025)))


def _thompson_stock(g, x0):
    """The REAL Thompson buttstock silhouette: dropped comb, curved belly,
    deep heel. Traced CCW from the front-top."""
    g.profile([
        (x0, 0.076),                 # front top at receiver rear
        (x0 + 0.055, 0.062),         # comb dip begins
        (x0 + 0.150, 0.040),         # comb slope (the drop)
        (x0 + 0.235, 0.026),         # heel
        (x0 + 0.248, -0.008),        # butt face upper
        (x0 + 0.243, -0.052),        # toe
        (x0 + 0.180, -0.036),        # belly curve rising
        (x0 + 0.095, -0.010),        # belly toward wrist
        (x0 + 0.030, 0.008),         # wrist underside
        (x0, 0.020),                 # front bottom
    ], 0.021, "wood", taper_y=0.85)
    g.box(x0 + 0.244, 0, -0.015, 0.012, 0.044, 0.075, "metal")   # buttplate


def _thompson_receiver(g, x0):
    """Receiver with the COMPLEX TOP: raised rear hump over the grip area,
    stepped top line, deep slab sides. x0 = receiver front."""
    g.profile([
        (x0, 0.084),                  # front top
        (x0 + 0.180, 0.084),          # flat top run
        (x0 + 0.190, 0.096),          # step UP (rear hump)
        (x0 + 0.300, 0.096),          # hump top
        (x0 + 0.310, 0.072),          # rear face chamfer
        (x0 + 0.310, 0.030),          # rear bottom
        (x0 + 0.190, 0.026),          # frame underside
        (x0, 0.032),                  # front bottom
    ], 0.0205, "metal")


def build_thompson_1928():
    """Thompson M1928 'Tommy gun' - the iconic config (Britannica reference):
    50rd L-drum tucked in the receiver rails, vertical foregrip, Cutts comp,
    top knob, tall Lyman sight, CURVED stock. 857mm overall."""
    g = GunBuilder("Thompson_1928")
    BORE = 0.062
    g.box(0.019, 0, BORE, 0.038, 0.028, 0.028, "metal")               # Cutts compensator
    g.cyl_x(0.038, 0.295, 0, BORE, 0.0122, "blued")                   # barrel (fins painted)
    g.box(0.052, 0, BORE + 0.020, 0.014, 0.007, 0.018, "blued")       # front sight
    # vertical foregrip with a curved front edge (profile, not box)
    g.profile([
        (0.185, 0.036), (0.228, 0.036), (0.240, -0.020), (0.246, -0.062),
        (0.222, -0.066), (0.208, -0.030), (0.196, 0.000),
    ], 0.016, "wood")
    _thompson_receiver(g, 0.295)
    g.box(0.472, 0, 0.104, 0.018, 0.013, 0.016, "blued")              # TOP charging knob
    g.box(0.575, 0, 0.108, 0.018, 0.028, 0.022, "metal")              # tall Lyman sight
    # 50rd L-drum: 168mm dia, ~50mm thin, tucked tight under the rails just
    # AHEAD of the trigger, 12 sides (the signature deserves the segments)
    g.cyl_y(0.442, -0.0265, 0.0235, -0.042, 0.084, "mag", seg=12)
    g.box(0.508, 0, -0.014, 0.060, 0.009, 0.009, "metal")             # trigger guard
    g.box(0.500, 0, 0.004, 0.008, 0.006, 0.024, "metal")              # trigger
    # rear pistol grip: curved profile, steep rake
    g.profile([
        (0.545, 0.026), (0.585, 0.026), (0.618, -0.058), (0.628, -0.088),
        (0.600, -0.092), (0.578, -0.052), (0.558, -0.008),
    ], 0.015, "wood")
    _thompson_stock(g, 0.607)
    return g.realize(Vector((0.0, 4.25, 0.55)), grip_l=Vector((0.216, 0.0, -0.03)))


def build_bar():
    """BAR M1918A2 - US automatic rifle. 1.21m, 20rd mag, folded bipod."""
    g = GunBuilder("BAR_M1918")
    g.cyl_x(0.00, 0.42, 0, 0.06, 0.014, "blued")
    g.box(0.03, 0, 0.088, 0.02, 0.008, 0.024, "blued")        # front sight
    g.box(0.05, 0.02, -0.02, 0.30, 0.008, 0.008, "dark")      # bipod leg R (folded back)
    g.box(0.05, -0.02, -0.02, 0.30, 0.008, 0.008, "dark")     # bipod leg L
    g.box(0.45, 0, 0.045, 0.22, 0.05, 0.06, "wood")           # forend
    g.box(0.68, 0, 0.058, 0.26, 0.055, 0.095, "metal")        # receiver
    g.box(0.77, 0, 0.115, 0.03, 0.032, 0.02, "metal")         # rear sight
    g.box(0.60, 0, -0.075, 0.055, 0.028, 0.16, "mag")         # 20rd mag
    g.box(0.72, 0, -0.04, 0.075, 0.012, 0.012, "metal")       # trigger guard
    g.box(0.712, 0, -0.015, 0.01, 0.008, 0.03, "metal")       # trigger
    g.box(0.98, 0, 0.02, 0.42, 0.05, 0.085, "wood", skew_rear_z=-0.04, taper_rear=0.92)  # stock w/ grip line
    return g.realize(Vector((0.0, 4.5, 0.15)), grip_l=Vector((0.45, 0.0, 0.015)))


def build_kar98k():
    """Kar98k - VC captured bolt rifle. 1.11m, full wood stock, bolt knob."""
    g = GunBuilder("Kar98k")
    g.cyl_x(0.00, 0.36, 0, 0.062, 0.011, "blued")
    g.box(0.025, 0, 0.085, 0.018, 0.008, 0.022, "blued")      # front sight hood
    g.box(0.42, 0, 0.048, 0.62, 0.045, 0.055, "wood")         # full-length stock fore
    g.box(0.40, 0, 0.085, 0.05, 0.03, 0.018, "metal")         # rear sight leaf
    g.box(0.585, 0, 0.075, 0.16, 0.04, 0.045, "metal")        # receiver/bolt housing
    g.box(0.615, 0.042, 0.065, 0.03, 0.045, 0.012, "blued")   # bolt handle out right
    g.box(0.63, 0.075, 0.05, 0.014, 0.02, 0.02, "blued")      # bolt knob
    g.box(0.56, 0, -0.005, 0.06, 0.03, 0.05, "metal")         # fixed mag well bump
    g.box(0.65, 0, -0.02, 0.07, 0.012, 0.012, "metal")        # trigger guard
    g.box(0.645, 0, 0.002, 0.01, 0.008, 0.026, "metal")       # trigger
    g.box(0.90, 0, 0.025, 0.42, 0.048, 0.08, "wood", skew_rear_z=-0.045, taper_rear=0.9)  # butt
    return g.realize(Vector((0.0, 5.0, 0.15)), grip_l=Vector((0.35, 0.0, 0.02)))


def build_nagant():
    """Nagant M1895 - VC revolver. 0.235m, 7-shot cylinder."""
    g = GunBuilder("Nagant_M1895")
    g.cyl_x(0.00, 0.115, 0, 0.032, 0.008, "blued")            # barrel
    g.box(0.008, 0, 0.048, 0.01, 0.006, 0.014, "blued")       # front sight
    g.cyl_x(0.118, 0.162, 0, 0.028, 0.019, "metal", seg=7)    # 7-shot cylinder
    g.box(0.175, 0, 0.032, 0.055, 0.024, 0.038, "metal")      # frame/hammer housing
    g.box(0.205, 0, 0.052, 0.012, 0.008, 0.018, "metal")      # hammer spur
    g.box(0.155, 0, -0.008, 0.05, 0.01, 0.01, "metal")        # trigger guard
    g.box(0.152, 0, 0.006, 0.008, 0.006, 0.02, "metal")       # trigger
    g.box(0.205, 0, -0.032, 0.045, 0.026, 0.07, "wood", skew_rear_z=-0.018)  # grip
    return g.realize(Vector((0.0, 5.4, 0.12)), grip_l=None)   # pistols: no support-hand node


def build_sks():
    """SKS - 1945 VC carbine. 1.02m, fixed 10rd mag, wood stock (bayonet omitted)."""
    g = GunBuilder("SKS")
    g.cyl_x(0.00, 0.30, 0, 0.058, 0.011, "blued")
    g.box(0.02, 0, 0.082, 0.016, 0.008, 0.024, "blued")       # front sight post
    g.box(0.38, 0, 0.042, 0.52, 0.044, 0.052, "wood")         # stock fore
    g.box(0.30, 0, 0.078, 0.045, 0.028, 0.016, "metal")       # rear sight
    g.box(0.565, 0, 0.068, 0.17, 0.042, 0.05, "metal")        # receiver + dust cover
    g.box(0.52, 0, -0.012, 0.075, 0.034, 0.055, "mag")        # fixed 10rd mag bump
    g.box(0.615, 0, -0.022, 0.07, 0.012, 0.012, "metal")      # trigger guard
    g.box(0.61, 0, 0.0, 0.01, 0.008, 0.026, "metal")          # trigger
    g.box(0.845, 0, 0.022, 0.35, 0.046, 0.078, "wood", skew_rear_z=-0.04, taper_rear=0.9)  # butt
    return g.realize(Vector((0.0, 5.8, 0.15)), grip_l=Vector((0.32, 0.0, 0.02)))


ALL = {"thompson": build_thompson, "bar": build_bar, "kar98k": build_kar98k,
       "nagant": build_nagant, "sks": build_sks}

if __name__ == "__main__":
    pass  # in-session use: call build_<gun>() individually
