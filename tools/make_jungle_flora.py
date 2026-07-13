"""Jungle flora batch - the full multi-tier undergrowth the palms were missing.

The first vegetation pass (make_jungle_vegetation.py) shipped 6 palms + 1 grass
card: a palm grove, not a jungle. Real Vietnam jungle is layered - canopy over
secondary growth over "bamboo, thorn thickets, shrubs, and vines, with grass
beneath all that", and visibility down to a few yards. THAT is what makes the
AI's vegetation-concealment and ambushes work (RECONgame-ge6g / n2ij).

Construction rules (studied from low-poly jungle packs):
  * plants are ROSETTES - leaves radiate from a centre, splayed by pitch+yaw,
    drooping under their own weight. Not flat cards.
  * silhouette variety beats leaf detail at PSX range. Different species must
    read differently in a black-on-fog silhouette.
  * 3 size variants per species (small/mid/large) so scatter never repeats.

Vertex colours carry SWAY WEIGHT (R=G=0 at the roots -> 1 at the tips), the
contract the existing sway shader + ground_clutter.gd already expect. Do not
repurpose them for tint; tint lives in the materials.

    blender -b -P tools/make_jungle_flora.py
"""
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix, Euler

OUT_DIR = r"C:\Users\caleb\RECONgame\assets\models\vegetation"
COL_ATTR = "Col"
UV_LAYER = "UVMap"
SEED = 20260712

# ------------------------------------------------------------------ palette
PALETTE = {
    "bark_dark":   (0.055, 0.042, 0.030),
    "bark_grey":   (0.105, 0.098, 0.082),
    "leaf_deep":   (0.035, 0.085, 0.030),   # shadowed understory green
    "leaf_mid":    (0.070, 0.150, 0.048),
    "leaf_bright": (0.130, 0.215, 0.062),   # sun-caught tips
    "leaf_olive":  (0.105, 0.135, 0.052),
    "frond":       (0.080, 0.160, 0.055),
    "bamboo":      (0.190, 0.220, 0.080),
    "grass_blade": (0.095, 0.155, 0.055),
    "grass_dry":   (0.190, 0.180, 0.085),   # elephant grass goes strawy
    "rot_wood":    (0.075, 0.062, 0.045),
    "moss":        (0.055, 0.105, 0.038),   # wet ground moss / litter
    "rice_green":  (0.165, 0.255, 0.070),   # young rice - the bright acid green
    "rice_ripe":   (0.255, 0.235, 0.090),   # ripening rice, strawy
    "paddy_water": (0.150, 0.205, 0.185),   # murky, but it reflects the sky
    "paddy_mud":   (0.185, 0.150, 0.105),   # sunlit bund earth
    "liana":       (0.070, 0.058, 0.040),   # woody climbing vine
}
PAL_ORDER = list(PALETTE.keys())
PAL_INDEX = {n: i for i, n in enumerate(PAL_ORDER)}
_mats = {}
_atlas = [None]


def _srgb(c):
    """Linear -> sRGB encode. The PALETTE is authored in LINEAR (same numbers a
    Principled Base Color takes), but the atlas is an sRGB image and BOTH
    Blender and Godot (`source_color` in the sway shader) will decode it back to
    linear when they sample it. Store the raw linear values and that decode
    darkens everything a second time - the whole jungle renders near-black."""
    return 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1.0 / 2.4)) - 0.055


def palette_image():
    """One texel per palette colour. Every plant then needs exactly ONE
    material and ONE surface -> one draw call per patch instead of eight.
    The sway shader already samples albedo_tex with filter_nearest, which is
    exactly what a palette atlas wants."""
    if _atlas[0] is not None:
        return _atlas[0]
    img = bpy.data.images.new("jungle_palette", len(PAL_ORDER), 1, alpha=True)
    img.colorspace_settings.name = 'sRGB'
    px = []
    for n in PAL_ORDER:
        r, g, b = PALETTE[n]
        px += [_srgb(r), _srgb(g), _srgb(b), 1.0]
    img.pixels = px
    img.pack()
    _atlas[0] = img
    return img


def palette_material():
    m = bpy.data.materials.get("jungle_atlas")
    if m:
        return m
    m = bpy.data.materials.new("jungle_atlas")
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs['Roughness'].default_value = 0.95
    b.inputs['Metallic'].default_value = 0.0
    tex = m.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image = palette_image()
    tex.interpolation = 'Closest'
    m.node_tree.links.new(tex.outputs['Color'], b.inputs['Base Color'])
    return m


def mat(name):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs['Base Color'].default_value = (*PALETTE[name], 1.0)
    b.inputs['Roughness'].default_value = 0.95
    b.inputs['Metallic'].default_value = 0.0
    _mats[name] = m
    return m


def clean():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for b in list(block):
            if b.users == 0:
                block.remove(b)
    _mats.clear()


# ------------------------------------------------------------------- canvas
class Plant:
    """Accumulates geometry + per-vertex sway weight, then bakes to an object."""

    def __init__(self, name):
        self.name = name
        self.verts = []
        self.faces = []
        self.mats = []
        self.sway = []
        self.matlist = []
        self.detail = []          # per-face: drop me from the far LOD
        self._mi = {}

    def _mat_index(self, mname):
        # index into the shared palette atlas, NOT a per-plant material slot
        return PAL_INDEX.get(mname, 0)

    def add(self, verts, faces, mname, sway, detail=False):
        """verts: [(x,y,z)], faces: [[local indices]], sway: [0..1] per vert.
        detail=True marks geometry that vanishes at distance (leaf sprays,
        small blades) so the far LOD can drop it and keep the silhouette."""
        base = len(self.verts)
        mi = self._mat_index(mname)
        self.verts += [tuple(v) for v in verts]
        self.sway += list(sway)
        for f in faces:
            self.faces.append([base + i for i in f])
            self.mats.append(mi)
            self.detail.append(detail)

    def bake(self, flat=False):
        me = bpy.data.meshes.new(self.name)
        me.from_pydata(self.verts, [], self.faces)
        me.update()
        me.materials.append(palette_material())
        n = float(len(PAL_ORDER))
        for poly in me.polygons:
            poly.material_index = 0
            poly.use_smooth = not flat
        uv = me.uv_layers.new(name=UV_LAYER)
        # every corner of a face points at that face's palette texel
        for poly, pal in zip(me.polygons, self.mats):
            u = (pal + 0.5) / n
            for li in poly.loop_indices:
                uv.data[li].uv = (u, 0.5)
        col = me.color_attributes.new(COL_ATTR, 'FLOAT_COLOR', 'POINT')
        for i, s in enumerate(self.sway):
            # vegetation_sway.gdshader contract:
            #   COLOR.r = master sway  (0 at the roots -> 1 at the tips)
            #   COLOR.g = flutter mask (frond TIPS / vine ends only, fast freq)
            # G must fall off far harder than R or whole trunks shimmy.
            #
            # WARNING - COLOR_0 IS NOT A COLOUR HERE. The glTF spec says COLOR_0
            # multiplies base colour, so any spec-abiding viewer (Blender's
            # importer included) renders this jungle with black roots and no
            # blue channel at all. Godot does NOT: the sway shader reads COLOR
            # only in vertex() and sets ALBEDO straight from the palette atlas.
            # If you preview these GLBs in Blender, bypass the vertex-colour
            # multiply on the material or you will "fix" a bug that isn't there.
            col.data[i].color = (s, s ** 3.0, 0.0, 1.0)
        me.color_attributes.active_color = col
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def place(pts, yaw=0.0, tilt=0.0, roll=0.0, origin=(0, 0, 0), scale=1.0):
    """Rotate a local point list into place.

    Leaf primitives are built VERTICAL (growing up +Z, arching out toward +X).
    `tilt` is the angle away from vertical: 0 = straight up, pi/2 = horizontal,
    > pi/2 = hanging below. `yaw` spins it around the plant's axis.
    """
    R = (Matrix.Rotation(yaw, 3, 'Z')
         @ Matrix.Rotation(tilt, 3, 'Y')
         @ Matrix.Rotation(roll, 3, 'X'))
    o = Vector(origin)
    return [tuple(o + (R @ (Vector(p) * scale))) for p in pts]


def _arc(length, segs, bend, ease=1.35):
    """Spine of a leaf: starts vertical, bends toward +X by `bend` radians at
    the tip. Integrated so the blade keeps its length however hard it arches."""
    pts, step = [(0.0, 0.0)], length / segs
    x = z = 0.0
    for i in range(1, segs + 1):
        a = bend * (i / segs) ** ease
        x += step * math.sin(a)
        z += step * math.cos(a)
        pts.append((x, z))
    return pts


# ------------------------------------------------------------- leaf shapes
def blade(length, width, segs=4, curve=0.55, taper=0.15, twist=0.0):
    """Grass/leaf blade: grows UP, arches over toward +X. `curve` 0..1 maps to
    a gentle spear (0.3) through a heavy flop-over (1.0)."""
    verts, faces, sway = [], [], []
    spine = _arc(length, segs, bend=curve * 1.9)
    for i, (x, z) in enumerate(spine):
        t = i / segs
        w = width * (1.0 - t ** 1.4 * (1.0 - taper))
        y = math.sin(twist * t) * w * 0.5
        verts += [(x, -w * 0.5 + y, z), (x, w * 0.5 + y, z)]
        sway += [t, t]
    for i in range(segs):
        a = i * 2
        faces.append([a, a + 1, a + 3, a + 2])
    return verts, faces, sway


def frond(length, width, leaflets=7, curve=0.5):
    """Pinnate fern frond: an arcing rib with leaflet pairs."""
    verts, faces, sway = [], [], []
    spine = _arc(length, leaflets, bend=curve * 1.7)
    for i, (x, z) in enumerate(spine):
        verts.append((x, 0.0, z))
        sway.append(i / leaflets)
    for i in range(1, leaflets):
        t = i / leaflets
        lw = width * (1.0 - t * 0.70) * (0.40 + 0.60 * math.sin(math.pi * t))
        bx, _, bz = verts[i]
        nx, _, nz = verts[i + 1]
        for side in (-1, 1):
            a = len(verts)
            # leaflet sweeps out sideways and slightly back down the rib
            verts += [(bx - lw * 0.20, side * lw, bz - lw * 0.30),
                      (nx, side * lw * 0.45, nz)]
            sway += [t, t + 0.05]
            faces.append([i, a, a + 1])
            faces.append([i, a + 1, i + 1])
    return verts, faces, sway


def paddle(length, width, fold=0.20, segs=3, curve=0.85):
    """Big banana/monstera paddle: rises, then flops over under its own weight,
    folded along the midrib."""
    verts, faces, sway = [], [], []
    spine = _arc(length, segs, bend=curve * 1.9)
    for i, (x, z) in enumerate(spine):
        t = i / segs
        w = width * math.sin(math.pi * (0.18 + 0.82 * t)) ** 0.7
        # midrib rides a little proud of the blade edges (the fold)
        lift = width * fold * math.sin(math.pi * t)
        verts += [(x, -w, z), (x + lift * 0.35, 0.0, z + lift * 0.5), (x, w, z)]
        sway += [t, t, t]
    for i in range(segs):
        a = i * 3
        faces.append([a, a + 3, a + 4, a + 1])
        faces.append([a + 1, a + 4, a + 5, a + 2])
    return verts, faces, sway


def culm(height, radius, nodes=5, sides=5, lean=0.06):
    """Bamboo culm: a thin faceted column with node rings."""
    verts, faces, sway = [], [], []
    rings = nodes + 1
    for r in range(rings + 1):
        t = r / rings
        z = height * t
        rr = radius * (1.0 - 0.30 * t)
        if r % 2 == 1:
            rr *= 1.18                      # swell at the node
        cx = lean * height * t * t
        for s in range(sides):
            a = math.tau * s / sides
            verts.append((cx + rr * math.cos(a), rr * math.sin(a), z))
            sway.append(t * t)              # stiff at the base, whips up top
    for r in range(rings):
        for s in range(sides):
            a = r * sides + s
            b = r * sides + (s + 1) % sides
            faces.append([a, b, b + sides, a + sides])
    return verts, faces, sway


def trunk(height, r0, r1, sides=6, lean=0.0, bend=0.0, segs=4):
    verts, faces, sway = [], [], []
    for i in range(segs + 1):
        t = i / segs
        z = height * t
        rr = r0 + (r1 - r0) * t
        cx = lean * height * t + bend * height * math.sin(math.pi * t) * 0.5
        for s in range(sides):
            a = math.tau * s / sides
            verts.append((cx + rr * math.cos(a), rr * math.sin(a), z))
            sway.append(0.10 * t * t)
    for i in range(segs):
        for s in range(sides):
            a = i * sides + s
            b = i * sides + (s + 1) % sides
            faces.append([a, b, b + sides, a + sides])
    return verts, faces, sway


# ---------------------------------------------------------------- TIER 1-2
def grass_tuft(rng, height=0.45, blades=13, spread=0.30):
    p = Plant("grass_tuft")
    for i in range(blades):
        yaw = rng.uniform(0, math.tau)
        h = height * rng.uniform(0.6, 1.25)
        v, f, s = blade(h, height * 0.060, segs=3,
                        curve=rng.uniform(0.45, 0.85), twist=rng.uniform(-0.5, 0.5))
        tilt = math.radians(rng.uniform(8, 38))             # splay out from centre
        o = (rng.uniform(-1, 1) * spread * 0.10, rng.uniform(-1, 1) * spread * 0.10, 0.0)
        p.add(place(v, yaw=yaw, tilt=tilt, origin=o), f,
              "grass_blade" if i % 3 else "leaf_bright", s)
    return p


def elephant_grass(rng, height=1.9, blades=16):
    """The Vietnam signature: chest-to-head high, razor blades arching over.
    This is what actually kills sightlines and makes ambush work."""
    p = Plant("elephant_grass")
    for i in range(blades):
        yaw = rng.uniform(0, math.tau)
        h = height * rng.uniform(0.62, 1.12)
        v, f, s = blade(h, height * 0.032, segs=5,
                        curve=rng.uniform(0.35, 0.75), twist=rng.uniform(-0.8, 0.8))
        tilt = math.radians(rng.uniform(4, 26))             # stands tall, tips flop
        o = (rng.uniform(-0.09, 0.09), rng.uniform(-0.09, 0.09), 0.0)
        p.add(place(v, yaw=yaw, tilt=tilt, origin=o), f,
              "grass_dry" if i % 4 == 0 else "grass_blade", s)
    return p


def fern(rng, height=0.75, fronds=8):
    p = Plant("fern")
    for i in range(fronds):
        yaw = math.tau * i / fronds + rng.uniform(-0.25, 0.25)
        h = height * rng.uniform(0.75, 1.2)
        v, f, s = frond(h, h * 0.28, leaflets=rng.randint(6, 9),
                        curve=rng.uniform(0.45, 0.75))
        tilt = math.radians(rng.uniform(25, 62))            # splayed rosette
        p.add(place(v, yaw=yaw, tilt=tilt, origin=(0, 0, height * 0.05)), f,
              "leaf_deep" if i % 2 else "leaf_mid", s)
    return p


def bush(rng, height=1.1, leaves=18):
    """Broadleaf thicket - the thing that stops you seeing 10 m."""
    p = Plant("bush")
    v, f, s = trunk(height * 0.30, 0.035, 0.022, sides=5)
    p.add(v, f, "bark_dark", s)
    for i in range(leaves):
        yaw = rng.uniform(0, math.tau)
        z = height * rng.uniform(0.15, 0.60)
        ll = height * rng.uniform(0.40, 0.70)
        v, f, s = paddle(ll, ll * rng.uniform(0.30, 0.42), segs=3,
                         curve=rng.uniform(0.6, 1.0))
        tilt = math.radians(rng.uniform(20, 70))
        p.add(place(v, yaw=yaw, tilt=tilt,
                    origin=(rng.uniform(-.05, .05), rng.uniform(-.05, .05), z)), f,
              ("leaf_deep", "leaf_mid", "leaf_olive")[i % 3], s)
    return p


def banana(rng, height=2.4, leaves=8):
    p = Plant("banana")
    v, f, s = trunk(height * 0.40, 0.075, 0.048, sides=6)
    p.add(v, f, "leaf_olive", s)
    for i in range(leaves):
        yaw = math.tau * i / leaves + rng.uniform(-0.2, 0.2)
        ll = height * rng.uniform(0.55, 0.80)
        v, f, s = paddle(ll, ll * 0.32, fold=0.30, segs=4,
                         curve=rng.uniform(0.7, 1.05))      # big leaves flop hard
        tilt = math.radians(rng.uniform(15, 55))
        p.add(place(v, yaw=yaw, tilt=tilt,
                    origin=(0, 0, height * rng.uniform(0.36, 0.44))), f,
              "leaf_mid" if i % 2 else "leaf_bright", s)
    return p


# ------------------------------------------------------------------ TIER 3
def bamboo_stand(rng, height=5.5, culms=6):
    """A clump of bamboo.

    FLATTENED FOR BUDGET. Bamboo is now planted across most of the jungle (it is the
    dominant woody plant in Vietnam), so its per-stand cost multiplies across the whole
    map - and the old stand was 858 tris, of which THE LEAVES WERE 55%. Six triangles to
    draw one leaf, at a range where nobody will ever count its curve.

    Four cuts, none of which touch the silhouette:

      1. CULM SIDES 5 -> 4. A culm is 30 mm across. At the distance you meet bamboo, a
         4-sided pole and a 5-sided pole are the same pole; this is a PS1-era game and
         its trees are prisms already.
      2. NODES 4-7 -> 3-5. The node swell is a nice touch nobody sees past 10 m.
      3. BLADE SEGMENTS 3 -> 2. A leaf goes from 6 tris to 4 - a 33% cut on the single
         most-repeated primitive in the whole jungle.
      4. LEAVES 10-16 -> 8-12 per culm.

    And the far LOD gets its own cut: only 4 of the 6 culms are STRUCTURE, so past 46 m a
    stand ships two-thirds of its poles. A bamboo brake at 50 m reads by its VERTICAL
    STRIPES; it does not matter how many stripes, only that they are there.

    Net: ~858 -> ~480 tris near, ~390 -> ~160 far. Same brake, half the bill.
    """
    p = Plant("bamboo")
    for i in range(culms):
        h = height * rng.uniform(0.55, 1.15)
        r = 0.030 * rng.uniform(0.8, 1.25)
        yaw = rng.uniform(0, math.tau)
        o = (rng.uniform(-0.30, 0.30), rng.uniform(-0.30, 0.30), 0.0)
        v, f, s = culm(h, r, nodes=rng.randint(3, 5), sides=4,
                       lean=rng.uniform(0.02, 0.12))
        # the first 4 poles hold the far read; the rest are close-range fill
        p.add(place(v, yaw=yaw, origin=o), f, "bamboo", s, detail=(i >= 4))
        # leaf sprays up the top third
        for _ in range(rng.randint(8, 12)):
            t = rng.uniform(0.45, 1.0)
            lz = h * t
            ly = rng.uniform(0, math.tau)
            ll = h * rng.uniform(0.14, 0.26)
            bv, bf, bs = blade(ll, ll * 0.16, segs=2, curve=0.9)
            p.add(place(bv, yaw=ly, tilt=math.radians(rng.uniform(45, 95)),
                        origin=(o[0] + lean_x(h, t), o[1], lz)), bf,
                  "leaf_mid" if rng.random() < .6 else "leaf_bright", bs,
                  detail=True)     # culms carry the far read, not the leaves
    return p


def lean_x(h, t):
    return 0.0     # culm lean is baked into the culm verts already


def palm_sapling(rng, height=1.6, fronds=7):
    p = Plant("palm_sapling")
    v, f, s = trunk(height * 0.28, 0.045, 0.032, sides=5, bend=0.05)
    p.add(v, f, "bark_dark", s)
    for i in range(fronds):
        yaw = math.tau * i / fronds + rng.uniform(-0.2, 0.2)
        ll = height * rng.uniform(0.60, 0.90)
        v, f, s = frond(ll, ll * 0.32, leaflets=rng.randint(7, 10),
                        curve=rng.uniform(0.55, 0.8))
        tilt = math.radians(rng.uniform(28, 65))
        p.add(place(v, yaw=yaw, tilt=tilt,
                    origin=(0, 0, height * 0.28)), f, "frond", s)
    return p


# ------------------------------------------------------------------ TIER 4
def broadleaf_tree(rng, height=9.0):
    """The silhouette the palms can't give us: a branching canopy tree."""
    p = Plant("broadleaf")
    th = height * 0.72                       # bare bole, then canopy on top
    v, f, s = trunk(th, 0.20, 0.10, sides=6, bend=rng.uniform(-0.04, 0.04))
    p.add(v, f, "bark_grey", s)
    # buttress roots - a fin: tall at the trunk, dying out at the ground.
    # jungle giants have them and they read hard at eye level.
    for i in range(4):
        yaw = math.tau * i / 4 + rng.uniform(-0.3, 0.3)
        bl = height * 0.11
        bh = height * 0.16
        t = 0.045
        bv = [(0, -t, 0), (0, t, 0), (bl, -t * 0.3, 0), (bl, t * 0.3, 0),
              (0, -t, bh), (0, t, bh)]
        bf = [[0, 2, 3, 1], [0, 4, 2], [1, 3, 5], [4, 5, 3, 2]]
        p.add(place(bv, yaw=yaw), bf, "bark_grey", [0.0] * 6)
    # branches + leaf clusters
    for i in range(rng.randint(5, 7)):
        yaw = rng.uniform(0, math.tau)
        bz = th * rng.uniform(0.72, 1.0)
        blen = height * rng.uniform(0.20, 0.32)
        tilt = rng.uniform(0.55, 1.05)       # up-and-out from the bole
        v, f, s = trunk(blen, 0.055, 0.028, sides=4)
        p.add(place(v, yaw=yaw, tilt=tilt, origin=(0, 0, bz)), f,
              "bark_grey", s)
        # cluster of leaf paddles at the branch end (same tilt = tip lands right)
        ex = math.sin(tilt) * blen
        tipx, tipy = ex * math.cos(yaw), ex * math.sin(yaw)
        tipz = bz + math.cos(tilt) * blen
        for _ in range(rng.randint(10, 14)):
            ly = rng.uniform(0, math.tau)
            ll = height * rng.uniform(0.10, 0.17)
            lv, lf, ls = paddle(ll, ll * 0.42, segs=2, curve=rng.uniform(0.5, 1.1))
            p.add(place(lv, yaw=ly, tilt=rng.uniform(0.3, 1.9),
                        origin=(tipx + rng.uniform(-.3, .3),
                                tipy + rng.uniform(-.3, .3),
                                tipz + rng.uniform(-.25, .45))), lf,
                  ("leaf_deep", "leaf_mid", "leaf_bright")[_ % 3],
                  [0.55 + 0.45 * x for x in ls])
    return p


# ------------------------------------------------------------------ TIER 5
def fallen_log(rng, length=3.2):
    p = Plant("fallen_log")
    r = rng.uniform(0.24, 0.38)
    v, f, s = trunk(length, r, r * 0.8, sides=7)
    # lay it down, wedge it slightly into the ground
    v = [(z, y, x * 0.06 + r * 0.75) for (x, y, z) in v]
    p.add(v, f, "rot_wood", [0.0] * len(v))
    for _ in range(rng.randint(2, 4)):     # stubs of snapped branches
        t = rng.uniform(0.15, 0.85)
        sv, sf, ss = trunk(rng.uniform(0.25, 0.5), 0.045, 0.02, sides=4)
        p.add(place(sv, yaw=rng.uniform(0, math.tau), tilt=rng.uniform(0.9, 1.6),
                    origin=(length * t, 0, r * 0.9)), sf, "rot_wood", ss)
    return p


def moss_patch(rng, size=1.1, clumps=9):
    """Moss / leaf-litter mat: flat, hugs the ground, breaks up bare dirt at
    the player's feet. Nearly free (2 tris a clump) and it stops the floor
    reading as a green bedsheet."""
    p = Plant("moss")
    for i in range(clumps):
        a = rng.uniform(0, math.tau)
        d = size * 0.5 * math.sqrt(rng.random())
        cx, cy = d * math.cos(a), d * math.sin(a)
        r = size * rng.uniform(0.14, 0.30)
        z = rng.uniform(0.004, 0.030)         # a hair off the ground, no z-fight
        n = 5
        verts = [(cx, cy, z + 0.01)]
        for k in range(n):
            aa = math.tau * k / n + rng.uniform(-0.3, 0.3)
            rr = r * rng.uniform(0.7, 1.25)
            verts.append((cx + rr * math.cos(aa), cy + rr * math.sin(aa), z))
        faces = [[0, k + 1, (k + 1) % n + 1] for k in range(n)]
        p.add(verts, faces, "moss" if i % 3 else "leaf_deep", [0.0] * len(verts))
    return p


def trunk_vine(rng, height=4.0, leaves=16):
    """A creeper CLIMBING a trunk - spirals up, leaves poking out. Stamp this
    onto a tree at its base to dress it."""
    p = Plant("trunk_vine")
    segs = max(8, int(height * 2.4))
    r = 0.22
    verts, faces, sway = [], [], []
    for i in range(segs + 1):
        t = i / segs
        a = t * math.tau * 1.7                       # ~1.7 turns up the bole
        cx, cy = r * math.cos(a), r * math.sin(a)
        z = height * t
        w = 0.018
        verts += [(cx - w, cy, z), (cx + w, cy, z)]
        s = t * 0.25                                 # gripping the trunk: barely moves
        sway += [s, s]
        if i:
            k = (i - 1) * 2
            faces.append([k, k + 1, k + 3, k + 2])
    p.add(verts, faces, "bark_dark", sway)
    for _ in range(leaves):
        t = rng.uniform(0.12, 1.0)
        a = t * math.tau * 1.7
        cx, cy = r * math.cos(a), r * math.sin(a)
        lv, lf, ls = paddle(rng.uniform(0.12, 0.22), 0.08, segs=2, curve=0.55)
        p.add(place(lv, yaw=a + rng.uniform(-0.8, 0.8),
                    tilt=rng.uniform(0.9, 1.9), origin=(cx, cy, height * t)), lf,
              "leaf_mid" if rng.random() < .5 else "leaf_deep",
              [t * 0.5 for _ in ls], detail=True)
    return p


def hanging_vine(rng, length=2.8, leaves=18):
    """'Wait-a-minute' vines - they hang into the canopy gaps and break up
    the vertical read."""
    p = Plant("vine")
    segs = 8
    v, f, s = [], [], []
    for i in range(segs + 1):
        t = i / segs
        z = -length * t
        x = math.sin(t * 3.1) * 0.10
        for dx in (-0.012, 0.012):
            v.append((x + dx, 0.0, z))
            s.append(t)
        if i:
            a = (i - 1) * 2
            f.append([a, a + 1, a + 3, a + 2])
    p.add(v, f, "bark_dark", s)
    for i in range(leaves):
        t = rng.uniform(0.1, 1.0)
        lv, lf, ls = paddle(rng.uniform(0.16, 0.26), 0.09, segs=2, curve=0.5)
        p.add(place(lv, yaw=rng.uniform(0, math.tau), tilt=rng.uniform(1.4, 2.6),
                    origin=(math.sin(t * 3.1) * 0.10, 0, -length * t)), lf,
              "leaf_mid" if i % 2 else "leaf_deep", [t] * len(ls), detail=True)
    return p


def tall_grass(rng, height=1.3, blades=22):
    """Upright field grass. Distinct from elephant_grass (which arches and
    slashes) - this stands straighter and packs denser. Comes in ankle, knee
    and chest heights so a field can grade."""
    p = Plant("tall_grass")
    for i in range(blades):
        yaw = rng.uniform(0, math.tau)
        h = height * rng.uniform(0.65, 1.2)
        v, f, s = blade(h, height * 0.028, segs=4,
                        curve=rng.uniform(0.25, 0.55),      # stands up
                        twist=rng.uniform(-0.7, 0.7))
        tilt = math.radians(rng.uniform(2, 20))
        o = (rng.uniform(-0.10, 0.10), rng.uniform(-0.10, 0.10), 0.0)
        p.add(place(v, yaw=yaw, tilt=tilt, origin=o), f,
              "grass_dry" if i % 5 == 0 else "grass_blade", s, detail=True)
    return p


def rice_clump(rng, height=0.75, stalks=14, ripe=False, keep=3):
    """A hill of rice. Farmers transplant in clumps, so a paddy reads as rows
    of little fountains, not a lawn.

    `keep` -- how many of the stalks are STRUCTURE (detail=False) and therefore
    survive bake_far() into the distant LOD.

    THIS IS NOT A TUNING KNOB, IT IS A BUG FIX. Every stalk used to be detail=True,
    so bake_far() threw away ALL of them: past the 46 m LOD line a rice paddy
    deflated from 0.87 m of standing crop to 0.37 m of bare mud, and stopped swaying
    while every plant around it kept moving. A paddy is 74% rice by vertex count -
    strip the rice and there is nothing left. (patch_paddy_edge got away with it
    because it also has dikes and a treeline to hold up its silhouette.)

    And a rice paddy is precisely the thing you look ACROSS at distance. The far LOD
    is where it LIVES, and that is where it was broken.

    Keeping a few stalks from EVERY clump - rather than keeping a few whole clumps -
    matters: drop whole clumps and the paddy visibly THINS as you back away, which is
    a density pop you cannot un-see. Thin each clump instead and the crop stays full
    to the horizon; at 46 m nobody is counting stalks."""
    p = Plant("rice")
    col = "rice_ripe" if ripe else "rice_green"
    for i in range(stalks):
        yaw = rng.uniform(0, math.tau)
        h = height * rng.uniform(0.75, 1.15)
        v, f, s = blade(h, height * 0.035, segs=3,
                        curve=rng.uniform(0.35, 0.7), twist=rng.uniform(-0.4, 0.4))
        tilt = math.radians(rng.uniform(6, 30))
        o = (rng.uniform(-0.06, 0.06), rng.uniform(-0.06, 0.06), 0.0)
        # the first `keep` stalks are the ones that stand at distance. They carry
        # their sway masks with them, so the far paddy still ripples in the wind.
        p.add(place(v, yaw=yaw, tilt=tilt, origin=o), f, col, s, detail=(i >= keep))
    return p


def liana(rng, length=6.0, thick=0.075, leaves=10):
    """A WOODY climbing vine - 'thick as a thigh', looping between trees like a
    living cable. Research says lianas are up to 40% of canopy leaf area and are
    what makes the mid-levels read as tangled. My old vines were string."""
    p = Plant("liana")
    segs = max(8, int(length * 2))
    verts, faces, sway = [], [], []
    sides = 4
    for i in range(segs + 1):
        t = i / segs
        # a slack, wandering hang
        x = math.sin(t * 5.0 + 1.0) * 0.35 * length * 0.18
        y = math.cos(t * 3.7) * 0.28 * length * 0.14
        z = -length * t
        r = thick * (1.0 - 0.35 * t)
        for k in range(sides):
            a = math.tau * k / sides
            verts.append((x + r * math.cos(a), y + r * math.sin(a), z))
            sway.append(t * 0.8)
        if i:
            b0 = (i - 1) * sides
            b1 = i * sides
            for k in range(sides):
                kn = (k + 1) % sides
                faces.append([b0 + k, b0 + kn, b1 + kn, b1 + k])
    p.add(verts, faces, "liana", sway)
    for _ in range(leaves):
        t = rng.uniform(0.15, 1.0)
        lx = math.sin(t * 5.0 + 1.0) * 0.35 * length * 0.18
        ly = math.cos(t * 3.7) * 0.28 * length * 0.14
        lv, lf, ls = paddle(rng.uniform(0.16, 0.28), 0.10, segs=2, curve=0.5)
        p.add(place(lv, yaw=rng.uniform(0, math.tau), tilt=rng.uniform(1.3, 2.5),
                    origin=(lx, ly, -length * t)), lf,
              "leaf_mid" if _ % 2 else "leaf_deep", [t] * len(ls), detail=True)
    return p


def paddy_dike(rng, length=11.0, width=0.9, height=0.34):
    """Earth bund. A paddy is DEFINED by these - they hold the 5-10cm of water
    in and double as the only footpath through a flooded field.

    THE ENDS MUST BE EXACT. A bund is only useful if tiles can be stacked into a field,
    and that means one tile's bund has to BUTT cleanly against its neighbour's. The
    wobble that keeps it from looking machine-made used to be a raw sine, which is zero
    at t=0 but lands at -7.5 cm at t=1 - so every bund ended 7.5 cm off its own line and
    no two ever met. The wobble is now enveloped to zero at BOTH ends: the middle still
    meanders like something a farmer piled up by hand, and the ends are dead on the mark.
    """
    p = Plant("dike")
    segs = 8
    verts, faces, sway = [], [], []
    for i in range(segs + 1):
        t = i / segs
        x = length * (t - 0.5)
        # sin(pi*t) is 0 at both ends and 1 in the middle - it pins the ends without
        # flattening the run.
        wob = math.sin(t * 4.0) * 0.10 * math.sin(math.pi * t)
        h = height * rng.uniform(0.85, 1.1)
        w = width * 0.5
        verts += [(x, wob - w, 0.0), (x, wob - w * 0.42, h),
                  (x, wob + w * 0.42, h), (x, wob + w, 0.0)]
        sway += [0.0, 0.0, 0.0, 0.0]
        if i:
            b = (i - 1) * 4
            for k in range(3):
                faces.append([b + k, b + k + 1, b + 4 + k + 1, b + 4 + k])
    p.add(verts, faces, "paddy_mud", sway)
    return p


def paddy_water(rng, size=11.0):
    """DEAD. Do not use. Kept only so an old call fails loudly instead of silently
    baking a black quad back into a paddy.

    This used to stamp a flat quad with the `paddy_water` palette colour into the patch
    mesh. That quad was then merged into the one big vegetation surface and rendered
    through vegetation_sway.gdshader - which is OPAQUE, alpha-scissored and lambert-lit.
    So it was not water. It was a dark leaf lying flat: no transparency, no depth, no
    ripple, no shore. A rice paddy read as a black hole in the ground.

    Water is now DECLARED by the patch (Patch.declare_water) and rendered by the game
    with terrain/water/water_swamp.gdshader - the terrain's own "shallow, vegetated
    wetland" shader, which is precisely what a paddy is. One source of truth for water.
    """
    raise RuntimeError(
        "paddy_water() is dead - it baked a black quad into the vegetation surface. "
        "Use Patch.declare_water(level, half, at) and let the terrain's water_swamp "
        "shader render the pan.")


# --------------------------------------------------------------------- main
SPECIES = [
    # (name, builder, base kwargs, [(suffix, scale)])
    ("grass_tuft",     grass_tuft,     dict(height=0.62),  [("_a", 0.75), ("_b", 1.0), ("_c", 1.35)]),
    ("elephant_grass", elephant_grass, dict(height=1.9),   [("_a", 0.8), ("_b", 1.0), ("_c", 1.25)]),
    ("fern",           fern,           dict(height=1.35),  [("_a", 0.8), ("_b", 1.0), ("_c", 1.3)]),
    ("bush",           bush,           dict(height=1.5),   [("_a", 0.8), ("_b", 1.05), ("_c", 1.35)]),
    ("banana",         banana,         dict(height=3.4),   [("_a", 0.85), ("_b", 1.2)]),
    ("bamboo",         bamboo_stand,   dict(height=5.5),   [("_a", 0.8), ("_b", 1.05), ("_c", 1.3)]),
    ("palm_sapling",   palm_sapling,   dict(height=2.1),   [("_a", 0.85), ("_b", 1.2)]),
    ("broadleaf",      broadleaf_tree, dict(height=11.0),  [("_a", 0.8), ("_b", 1.0), ("_c", 1.3)]),
    ("fallen_log",     fallen_log,     dict(length=3.2),   [("_a", 0.85), ("_b", 1.2)]),
    ("vine",           hanging_vine,   dict(length=2.8),   [("_a", 0.8), ("_b", 1.25)]),
    ("trunk_vine",     trunk_vine,     dict(height=4.0),   [("_a", 0.8), ("_b", 1.3)]),
    ("moss",           moss_patch,     dict(size=1.1),     [("_a", 0.8), ("_b", 1.3)]),
    ("tall_grass",     tall_grass,     dict(height=1.3),   [("_a", 0.68), ("_b", 1.0), ("_c", 1.38)]),
    ("rice",           rice_clump,     dict(height=0.75),  [("_a", 0.85), ("_b", 1.15)]),
    ("liana",          liana,          dict(length=6.0),   [("_a", 0.8), ("_b", 1.25)]),
]


def export(ob, path):
    for o in bpy.data.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    kwargs = dict(filepath=path, export_format='GLB', use_selection=True,
                  export_apply=True, export_animations=False, export_skins=False,
                  export_morph=False, export_cameras=False, export_lights=False,
                  export_yup=True, export_extras=False, export_tangents=False,
                  export_vertex_color='ACTIVE', export_all_vertex_colors=False,
                  export_active_vertex_color_when_no_material=True)
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    bpy.ops.export_scene.gltf(**{k: v for k, v in kwargs.items() if k in props})


def save_palette_png(path=None):
    path = path or os.path.join(OUT_DIR, "jungle_palette.png")
    img = palette_image()
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    print("palette ->", path, "(%d colours)" % len(PAL_ORDER))
    return path


def main():
    clean()
    os.makedirs(OUT_DIR, exist_ok=True)
    save_palette_png()
    rng = random.Random(SEED)
    rows = []
    for base, fn, kw, variants in SPECIES:
        for suffix, scale in variants:
            name = base + suffix
            kw2 = {k: v * scale for k, v in kw.items()}
            p = fn(rng, **kw2)
            p.name = name
            ob = p.bake(flat=(base in ("fallen_log", "bamboo")))
            tris = sum(max(0, len(f) - 2) for f in p.faces)
            zs = [v[2] for v in p.verts]
            h = max(zs) - min(zs)
            path = os.path.join(OUT_DIR, name + ".glb")
            export(ob, path)
            rows.append((name, len(p.verts), tris, round(h, 2)))
            for o in bpy.data.objects:
                bpy.data.objects.remove(o, do_unlink=True)
    print("\n%-18s %6s %6s %8s" % ("asset", "verts", "tris", "height_m"))
    for r in rows:
        print("%-18s %6d %6d %8.2f" % r)
    print("\n%d assets -> %s" % (len(rows), OUT_DIR))


if __name__ == "__main__":
    main()
