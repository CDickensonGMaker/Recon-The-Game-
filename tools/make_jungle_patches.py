"""Jungle PATCHES - 20 pre-composed 12m tiles the level shuffles across the AO.

Rebuilt after the first pass read as a GRID: every tile kept its plants inside
its own square, so the seams showed and the jungle looked like blobs on graph
paper. Two structural fixes, plus a research pass on what Vietnamese jungle
actually IS:

  1. OVERHANG - plants are sampled out PAST the tile edge, so neighbouring tiles
     interlock and the seam disappears.
  2. POISSON-DISC spacing - pure random clumps and a grid reads as a grid.
     Dart-throwing with a minimum separation per species gives the even-but-
     irregular spacing real plants have, because they compete for light and root
     room. That single change is most of the "believability".

What the research changed (worldrainforests / UN-REDD Vietnam stratification):
  * A closed canopy takes 95-99% of the light, so PRIMARY forest floor is nearly
     BARE - big boles, deep shade, lianas hanging through. We had none of that;
     everything was uniformly thick. -> patch_understory.
  * The impenetrable stuff is SECONDARY GROWTH, where the canopy was broken
     (bomb, fire, farm) and light floods in. -> patch_secondary.
  * LIANAS are woody, "thick as a thigh", link multiple crowns and account for
     up to 40% of canopy leaf area - they are what makes the mid-levels read as
     tangled. Ours were string. -> F.liana, slung between every pair of crowns.
  * Paddies are defined by their earthen BUNDS holding 5-10cm of water; the
     bunds are the only dry footing. -> patch_paddy / patch_paddy_edge.

Each patch bakes to ONE mesh via a palette atlas (one draw call), plus a
structure-only `_far` twin for the LOD. Sway vertex-colours survive the merge.

    blender -b -P tools/make_jungle_patches.py
"""
import bpy, sys, os, math, json, random

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import make_jungle_flora as F

OUT_DIR = r"C:\Users\caleb\RECONgame\assets\models\vegetation\patches"
TILE = 12.0                      # metres square
SEED = 990012


# --------------------------------------------------------------- composition
class Patch(F.Plant):
    """A Plant that other Plants get stamped into.

    Every stamp is tagged STRUCTURE or DETAIL:
      structure = trees, bamboo, banana, logs, lianas, dikes  (reads at 150m)
      detail    = grass, fern, bush, moss, rice               (gone by 60m)
    We bake a full mesh and a structure-only `_far` twin; the game swaps by
    distance. Without it a chunk of solid jungle is ~4M triangles on screen.
    """

    def __init__(self, name):
        super().__init__(name)
        self.detail = []

    def stamp(self, plant, at=(0, 0, 0), yaw=0.0, scale=1.0, detail=False):
        base = len(self.verts)
        self.verts += F.place(plant.verts, yaw=yaw, origin=at, scale=scale)
        self.sway += list(plant.sway)
        pdet = getattr(plant, "detail", None)
        for i, f in enumerate(plant.faces):
            self.faces.append([base + j for j in f])
            self.mats.append(plant.mats[i])          # palette index
            own = bool(pdet[i]) if pdet and i < len(pdet) else False
            self.detail.append(detail or own)

    def add(self, verts, faces, mname, sway, detail=False):
        n0 = len(self.faces)
        super().add(verts, faces, mname, sway)
        self.detail += [detail] * (len(self.faces) - n0)

    def bake_far(self):
        keep = [f for f, d in zip(self.faces, self.detail) if not d]
        kept_mats = [m for m, d in zip(self.mats, self.detail) if not d]
        used = sorted({j for f in keep for j in f})
        remap = {j: i for i, j in enumerate(used)}
        far = F.Plant(self.name + "_far")
        far.verts = [self.verts[j] for j in used]
        far.sway = [self.sway[j] for j in used]
        far.faces = [[remap[j] for j in f] for f in keep]
        far.mats = kept_mats
        return far


def vine_bridge(patch, p0, p1, rng, sag=0.35, leaves=12):
    """A liana slung between two crowns. Catenary sag, leaves along the belly."""
    import mathutils
    a, b = mathutils.Vector(p0), mathutils.Vector(p1)
    span = (b - a).length
    if span < 0.5:
        return
    segs = max(6, int(span * 1.3))
    pts = []
    for i in range(segs + 1):
        t = i / segs
        p = a.lerp(b, t)
        p.z -= sag * span * math.sin(math.pi * t)
        p.x += math.sin(t * 4.0) * 0.14
        p.y += math.cos(t * 3.0) * 0.12
        pts.append(p)
    verts, faces, sway = [], [], []
    w = 0.055                                    # woody, not string
    for i, p in enumerate(pts):
        t = i / segs
        verts += [(p.x, p.y - w, p.z), (p.x, p.y + w, p.z),
                  (p.x, p.y, p.z - w * 1.6)]
        s = math.sin(math.pi * t)
        sway += [s, s, s]
        if i:
            k = (i - 1) * 3
            faces.append([k, k + 1, k + 4, k + 3])
            faces.append([k + 1, k + 2, k + 5, k + 4])
            faces.append([k + 2, k, k + 3, k + 5])
    patch.add(verts, faces, "liana", sway)
    for _ in range(leaves):
        t = rng.uniform(0.12, 0.88)
        p = pts[int(t * segs)]
        lv, lf, ls = F.paddle(rng.uniform(0.16, 0.28), 0.10, segs=2, curve=0.5)
        patch.add(F.place(lv, yaw=rng.uniform(0, math.tau),
                          tilt=rng.uniform(1.4, 2.6), origin=(p.x, p.y, p.z)),
                  lf, "leaf_mid" if rng.random() < .6 else "leaf_deep",
                  [math.sin(math.pi * t)] * len(ls), detail=True)


# ------------------------------------------------------------------- scatter
OVERHANG = 1.8
HALF = TILE * 0.5 + OVERHANG          # 7.8m: content spills into the neighbours


def scatter_pts(rng, n, min_dist, half=HALF, avoid=None, ring=None):
    """n points, no two closer than min_dist (Poisson-disc by dart throwing).
    `avoid` = [(x,y,r)] keep-out circles (a trail lane). `ring` = (in, out) to
    hug the rim instead of filling."""
    pts, tries, cap = [], 0, n * 60
    while len(pts) < n and tries < cap:
        tries += 1
        if ring:
            a = rng.uniform(0, math.tau)
            d = rng.uniform(ring[0], ring[1])
            x, y = d * math.cos(a), d * math.sin(a)
        else:
            x = rng.uniform(-half, half)
            y = rng.uniform(-half, half)
        if avoid and any((x - ax) ** 2 + (y - ay) ** 2 < ar * ar
                         for ax, ay, ar in avoid):
            continue
        if any((x - qx) ** 2 + (y - qy) ** 2 < min_dist * min_dist
               for qx, qy in pts):
            continue
        pts.append((x, y))
    return pts


# minimum spacing per species - what stops a patch looking like a pile
GAP = {
    "tree": 4.6, "bamboo": 2.6, "banana": 2.0, "sapling": 1.7, "log": 3.0,
    "bush": 1.5, "fern": 1.05, "grass": 0.72, "tall_grass": 0.80,
    "elephant": 0.85, "moss": 1.25, "rice": 0.70,
}

DETAIL_BUILDERS = (F.grass_tuft, F.fern, F.bush, F.moss_patch,
                   F.elephant_grass, F.palm_sapling, F.tall_grass, F.rice_clump)


def sow(patch, rng, builder, n, lo, hi, key, gap, detail=None, avoid=None,
        ring=None, scale=(0.85, 1.2)):
    if detail is None:
        detail = builder in DETAIL_BUILDERS
    for (x, y) in scatter_pts(rng, n, gap, avoid=avoid, ring=ring):
        pl = builder(rng, **{key: rng.uniform(lo, hi)})
        patch.stamp(pl, at=(x, y, 0.0), yaw=rng.uniform(0, math.tau),
                    scale=rng.uniform(*scale), detail=detail)


def trees(patch, rng, n, avoid=None, ring=None, lo=9.0, hi=13.5, dress=0.55,
          only=None):
    """Canopy trees. Returns crown points so lianas can be slung between them.
    `only(x, y) -> bool` rejects ground a tree must not stand on (a flooded
    paddy pan, say) BEFORE it gets planted."""
    tops = []
    for (x, y) in scatter_pts(rng, n * 3, GAP["tree"], avoid=avoid, ring=ring):
        if only is not None and not only(x, y):
            continue
        if len(tops) >= n:
            break
        h = rng.uniform(lo, hi)
        patch.stamp(F.broadleaf_tree(rng, height=h), at=(x, y, 0),
                    yaw=rng.uniform(0, math.tau))
        if rng.random() < dress:
            patch.stamp(F.trunk_vine(rng, height=h * rng.uniform(0.4, 0.7)),
                        at=(x, y, 0), yaw=rng.uniform(0, math.tau))
        tops.append((x, y, h * 0.72 * rng.uniform(0.8, 0.95)))
    return tops


def lianas(patch, rng, tops, chance=0.7):
    """Woody cables between crowns + free hangers. Not decoration: this is what
    makes the mid-level read as tangled."""
    for i in range(len(tops)):
        for j in range(i + 1, len(tops)):
            if rng.random() < chance:
                vine_bridge(patch, tops[i], tops[j], rng,
                            sag=rng.uniform(0.24, 0.44))
    for (tx, ty, tz) in tops:
        for _ in range(rng.randint(1, 3)):
            patch.stamp(F.liana(rng, length=rng.uniform(3.0, 7.0),
                                thick=rng.uniform(0.05, 0.10)),
                        at=(tx + rng.uniform(-1.6, 1.6),
                            ty + rng.uniform(-1.6, 1.6), tz),
                        yaw=rng.uniform(0, math.tau))


def bamboos(patch, rng, n, avoid=None, lo=5.0, hi=8.5):
    for (x, y) in scatter_pts(rng, n, GAP["bamboo"], avoid=avoid):
        patch.stamp(F.bamboo_stand(rng, height=rng.uniform(lo, hi)),
                    at=(x, y, 0), yaw=rng.uniform(0, math.tau))


def logs(patch, rng, n, avoid=None):
    for (x, y) in scatter_pts(rng, n, GAP["log"], avoid=avoid):
        patch.stamp(F.fallen_log(rng, length=rng.uniform(3.0, 5.2)),
                    at=(x, y, 0), yaw=rng.uniform(0, math.tau))


# ================================================================== OPEN (3)
def patch_open(p, rng):
    """Crater / burn / bare ground. The eye needs rest and a firefight needs
    somewhere to happen."""
    sow(p, rng, F.grass_tuft, 30, 0.4, 0.8, "height", GAP["grass"])
    sow(p, rng, F.bush, 3, 0.9, 1.3, "height", GAP["bush"], ring=(6.0, HALF))
    trees(p, rng, 1, ring=(6.5, HALF))
    logs(p, rng, 2)
    sow(p, rng, F.moss_patch, 5, 0.8, 1.6, "size", GAP["moss"])


def patch_clearing(p, rng):
    """Light gets in, so the floor answers: grass and scrub, trees at the rim."""
    sow(p, rng, F.grass_tuft, 40, 0.5, 0.9, "height", GAP["grass"])
    sow(p, rng, F.tall_grass, 12, 0.8, 1.3, "height", GAP["tall_grass"])
    sow(p, rng, F.fern, 6, 0.9, 1.4, "height", GAP["fern"], ring=(5.0, HALF))
    tops = trees(p, rng, 2, ring=(6.0, HALF))
    lianas(p, rng, tops, chance=0.4)
    logs(p, rng, 1)


def patch_grassfield(p, rng):
    """Open but TALL - chest-high field grass. Cross it standing and you are
    seen; crouch and you vanish."""
    sow(p, rng, F.tall_grass, 46, 1.1, 1.9, "height", GAP["tall_grass"])
    sow(p, rng, F.grass_tuft, 22, 0.5, 0.8, "height", GAP["grass"])
    sow(p, rng, F.elephant_grass, 8, 1.6, 2.1, "height", GAP["elephant"],
        ring=(4.5, HALF))
    trees(p, rng, 1, ring=(6.5, HALF))


# ================================================================= PADDY (2)
def patch_paddy(p, rng):
    """Bunds holding a shallow pan of water, rice transplanted in clumps. The
    dikes are the only dry footing - that is the tactical point of a paddy."""
    p.stamp(F.paddy_water(rng, size=TILE + 2.0), at=(0, 0, 0))
    for k in (-1, 1):
        p.stamp(F.paddy_dike(rng, length=TILE + 3.0), at=(0, k * TILE * 0.5, 0))
    p.stamp(F.paddy_dike(rng, length=TILE + 3.0), at=(TILE * 0.5, 0, 0),
            yaw=math.pi / 2)
    ripe = rng.random() < 0.4
    for (x, y) in scatter_pts(rng, 130, GAP["rice"], half=TILE * 0.46):
        p.stamp(F.rice_clump(rng, height=rng.uniform(0.55, 0.85), ripe=ripe),
                at=(x, y, 0.02), yaw=rng.uniform(0, math.tau),
                scale=rng.uniform(0.85, 1.2), detail=True)


def patch_paddy_edge(p, rng):
    """Where the paddy stops and the treeline starts - the classic killing
    ground: you are in the open, wet and slow, and they are in the green."""
    p.stamp(F.paddy_water(rng, size=TILE * 0.95), at=(0, -TILE * 0.26, 0))
    p.stamp(F.paddy_dike(rng, length=TILE + 3.0), at=(0, TILE * 0.16, 0))
    for (x, y) in scatter_pts(rng, 70, GAP["rice"], half=TILE * 0.44):
        if y > TILE * 0.10:
            continue
        p.stamp(F.rice_clump(rng, height=rng.uniform(0.55, 0.8)),
                at=(x, y, 0.02), yaw=rng.uniform(0, math.tau), detail=True)
    for _ in range(14):
        x, y = rng.uniform(-HALF, HALF), rng.uniform(TILE * 0.24, HALF)
        p.stamp(F.bush(rng, height=rng.uniform(1.2, 1.9)), at=(x, y, 0),
                yaw=rng.uniform(0, math.tau), detail=True)
    for _ in range(12):
        x, y = rng.uniform(-HALF, HALF), rng.uniform(TILE * 0.22, HALF)
        p.stamp(F.fern(rng, height=rng.uniform(1.0, 1.6)), at=(x, y, 0),
                yaw=rng.uniform(0, math.tau), detail=True)
    # trees ONLY on the dry bank - they were standing in the water
    tops = trees(p, rng, 4, ring=(TILE * 0.34, HALF),
                 only=lambda x, y: y > TILE * 0.20)
    lianas(p, rng, tops, chance=0.7)


# ================================================================= LIGHT (4)
def patch_understory(p, rng):
    """PRIMARY forest. The canopy takes 95-99% of the light so the floor is
    nearly BARE: big boles, deep shade, lianas hanging through. This is the
    jungle you can actually move in - and the old batch had none of it."""
    tops = trees(p, rng, 4, lo=11.0, hi=14.5, dress=0.9)
    lianas(p, rng, tops, chance=0.85)
    sow(p, rng, F.fern, 9, 0.9, 1.5, "height", GAP["fern"] * 1.6)
    sow(p, rng, F.grass_tuft, 10, 0.4, 0.7, "height", GAP["grass"] * 1.5)
    sow(p, rng, F.moss_patch, 12, 0.9, 1.9, "size", GAP["moss"])
    sow(p, rng, F.palm_sapling, 3, 1.6, 2.4, "height", GAP["sapling"])
    logs(p, rng, 2)


def patch_fern_floor(p, rng):
    """Fern carpet under a high canopy: thick at the knees, open at eye level."""
    sow(p, rng, F.fern, 26, 1.1, 1.8, "height", GAP["fern"])
    tops = trees(p, rng, 3, lo=10.0, hi=13.5)
    lianas(p, rng, tops, chance=0.6)
    sow(p, rng, F.grass_tuft, 14, 0.5, 0.8, "height", GAP["grass"])
    sow(p, rng, F.moss_patch, 9, 0.8, 1.7, "size", GAP["moss"])
    logs(p, rng, 1)


def patch_scrub(p, rng):
    """Knee-to-waist regrowth. Cover if you go prone, not if you stand."""
    sow(p, rng, F.grass_tuft, 30, 0.5, 0.9, "height", GAP["grass"])
    sow(p, rng, F.tall_grass, 14, 0.9, 1.5, "height", GAP["tall_grass"])
    sow(p, rng, F.fern, 12, 0.8, 1.3, "height", GAP["fern"])
    sow(p, rng, F.bush, 7, 0.9, 1.5, "height", GAP["bush"])
    sow(p, rng, F.palm_sapling, 4, 1.5, 2.2, "height", GAP["sapling"])
    tops = trees(p, rng, 2, ring=(5.0, HALF))
    lianas(p, rng, tops, chance=0.5)


def patch_trail(p, rng):
    """A lane you can actually walk, jungle crowding both shoulders, cables
    strung over the top."""
    lane = [(x, 0.0, 2.3) for x in (-6, -3, 0, 3, 6)]
    sow(p, rng, F.bush, 16, 1.2, 2.0, "height", GAP["bush"], avoid=lane)
    sow(p, rng, F.fern, 14, 1.0, 1.7, "height", GAP["fern"], avoid=lane)
    sow(p, rng, F.tall_grass, 10, 1.0, 1.6, "height", GAP["tall_grass"], avoid=lane)
    tops = trees(p, rng, 3, avoid=lane, ring=(4.0, HALF))
    lianas(p, rng, tops, chance=0.8)
    sow(p, rng, F.grass_tuft, 16, 0.35, 0.6, "height", GAP["grass"])
    sow(p, rng, F.moss_patch, 8, 0.8, 1.6, "size", GAP["moss"])


# ================================================================ MEDIUM (4)
def patch_canopy(p, rng):
    tops = trees(p, rng, 4, dress=0.8)
    lianas(p, rng, tops, chance=0.85)
    sow(p, rng, F.fern, 14, 1.0, 1.7, "height", GAP["fern"])
    sow(p, rng, F.bush, 9, 1.2, 1.8, "height", GAP["bush"])
    sow(p, rng, F.grass_tuft, 18, 0.5, 0.8, "height", GAP["grass"])
    sow(p, rng, F.moss_patch, 8, 0.8, 1.7, "size", GAP["moss"])
    logs(p, rng, 1)


def patch_deadfall(p, rng):
    logs(p, rng, 6)
    sow(p, rng, F.fern, 18, 1.0, 1.7, "height", GAP["fern"])
    sow(p, rng, F.bush, 9, 1.1, 1.7, "height", GAP["bush"])
    sow(p, rng, F.moss_patch, 14, 0.9, 1.9, "size", GAP["moss"])
    tops = trees(p, rng, 2, ring=(4.5, HALF))
    lianas(p, rng, tops, chance=0.6)
    sow(p, rng, F.grass_tuft, 16, 0.5, 0.8, "height", GAP["grass"])


def patch_palmgrove(p, rng):
    for (x, y) in scatter_pts(rng, 7, 2.4):
        p.stamp(F.palm_sapling(rng, height=rng.uniform(2.4, 3.6)), at=(x, y, 0),
                yaw=rng.uniform(0, math.tau), scale=rng.uniform(1.3, 2.2))
    sow(p, rng, F.banana, 5, 2.8, 3.8, "height", GAP["banana"])
    sow(p, rng, F.fern, 12, 1.0, 1.6, "height", GAP["fern"])
    sow(p, rng, F.grass_tuft, 20, 0.5, 0.8, "height", GAP["grass"])
    tops = trees(p, rng, 1, ring=(5.5, HALF))
    lianas(p, rng, tops, chance=0.5)


def patch_vine_hall(p, rng):
    """A ring of boles with cables criss-crossed overhead. You walk under it."""
    tops = trees(p, rng, 5, ring=(3.4, HALF), lo=10.5, hi=14.0, dress=1.0)
    lianas(p, rng, tops, chance=0.9)
    sow(p, rng, F.fern, 10, 1.0, 1.6, "height", GAP["fern"])
    sow(p, rng, F.bush, 5, 1.1, 1.6, "height", GAP["bush"])
    sow(p, rng, F.grass_tuft, 16, 0.5, 0.8, "height", GAP["grass"])
    sow(p, rng, F.moss_patch, 10, 0.9, 1.8, "size", GAP["moss"])


# ================================================================= DENSE (4)
def patch_grove(p, rng):
    """The thick mix: canopy, bamboo and bush all fighting for the same light."""
    tops = trees(p, rng, 3, dress=0.95)
    lianas(p, rng, tops, chance=0.8)
    bamboos(p, rng, 5)
    sow(p, rng, F.bush, 15, 1.3, 2.0, "height", GAP["bush"])
    sow(p, rng, F.fern, 13, 1.0, 1.7, "height", GAP["fern"])
    sow(p, rng, F.palm_sapling, 4, 1.8, 2.6, "height", GAP["sapling"])
    sow(p, rng, F.tall_grass, 10, 1.0, 1.6, "height", GAP["tall_grass"])
    sow(p, rng, F.grass_tuft, 16, 0.5, 0.8, "height", GAP["grass"])
    sow(p, rng, F.moss_patch, 8, 0.8, 1.7, "size", GAP["moss"])
    logs(p, rng, 1)


def patch_bamboo_grove(p, rng):
    tops = trees(p, rng, 2, ring=(4.0, HALF), dress=0.8)
    lianas(p, rng, tops, chance=0.7)
    bamboos(p, rng, 12)
    sow(p, rng, F.bush, 8, 1.2, 1.8, "height", GAP["bush"])
    sow(p, rng, F.fern, 10, 1.0, 1.6, "height", GAP["fern"])
    sow(p, rng, F.grass_tuft, 16, 0.5, 0.8, "height", GAP["grass"])
    sow(p, rng, F.moss_patch, 7, 0.8, 1.6, "size", GAP["moss"])


def patch_secondary(p, rng):
    """SECONDARY GROWTH - the canopy was broken (bomb, fire, farm), light floods
    in and the ground answers with a riot. THIS, not primary forest, is the
    jungle that eats patrols."""
    sow(p, rng, F.bush, 22, 1.4, 2.2, "height", GAP["bush"] * 0.9)
    sow(p, rng, F.tall_grass, 20, 1.2, 1.9, "height", GAP["tall_grass"])
    sow(p, rng, F.fern, 16, 1.1, 1.8, "height", GAP["fern"])
    sow(p, rng, F.palm_sapling, 8, 1.6, 2.6, "height", GAP["sapling"])
    bamboos(p, rng, 4, lo=4.5, hi=6.5)
    tops = trees(p, rng, 2, ring=(5.0, HALF), lo=8.0, hi=11.0)
    lianas(p, rng, tops, chance=0.6)
    sow(p, rng, F.grass_tuft, 18, 0.5, 0.9, "height", GAP["grass"])


def patch_elephant(p, rng):
    """Chest-high grass sea. You cannot see a crouching man in this."""
    sow(p, rng, F.elephant_grass, 40, 1.7, 2.5, "height", GAP["elephant"])
    sow(p, rng, F.tall_grass, 18, 1.1, 1.7, "height", GAP["tall_grass"])
    sow(p, rng, F.grass_tuft, 20, 0.5, 0.8, "height", GAP["grass"])
    trees(p, rng, 1, ring=(6.0, HALF))
    sow(p, rng, F.bush, 4, 1.2, 1.7, "height", GAP["bush"], ring=(5.0, HALF))


# ================================================================== WALL (3)
def patch_thicket(p, rng):
    """No sightlines. Where an ambush lives."""
    sow(p, rng, F.bush, 24, 1.4, 2.2, "height", GAP["bush"] * 0.85)
    sow(p, rng, F.fern, 18, 1.1, 1.8, "height", GAP["fern"] * 0.9)
    sow(p, rng, F.palm_sapling, 6, 1.8, 2.6, "height", GAP["sapling"])
    sow(p, rng, F.tall_grass, 14, 1.1, 1.7, "height", GAP["tall_grass"])
    sow(p, rng, F.grass_tuft, 20, 0.5, 0.8, "height", GAP["grass"])
    tops = trees(p, rng, 2, ring=(4.5, HALF))
    lianas(p, rng, tops, chance=0.7)
    sow(p, rng, F.moss_patch, 8, 0.8, 1.6, "size", GAP["moss"])


def patch_tangle(p, rng):
    """Maximum thickness. You cut through this, you do not walk it."""
    tops = trees(p, rng, 4, dress=1.0)
    lianas(p, rng, tops, chance=1.0)
    bamboos(p, rng, 7)
    sow(p, rng, F.bush, 24, 1.5, 2.2, "height", GAP["bush"] * 0.85)
    sow(p, rng, F.fern, 18, 1.1, 1.8, "height", GAP["fern"] * 0.9)
    sow(p, rng, F.elephant_grass, 12, 1.7, 2.3, "height", GAP["elephant"])
    sow(p, rng, F.palm_sapling, 6, 1.8, 2.6, "height", GAP["sapling"])
    sow(p, rng, F.tall_grass, 12, 1.1, 1.8, "height", GAP["tall_grass"])
    sow(p, rng, F.moss_patch, 10, 0.9, 1.8, "size", GAP["moss"])
    logs(p, rng, 2)


def patch_bamboo_wall(p, rng):
    """A bamboo brake you basically cannot push through."""
    bamboos(p, rng, 18, lo=5.5, hi=9.0)
    sow(p, rng, F.fern, 8, 0.9, 1.4, "height", GAP["fern"])
    sow(p, rng, F.bush, 6, 1.1, 1.6, "height", GAP["bush"])
    sow(p, rng, F.grass_tuft, 14, 0.5, 0.7, "height", GAP["grass"])
    sow(p, rng, F.moss_patch, 6, 0.8, 1.5, "size", GAP["moss"])


# name, builder, density class, role
PATCHES = [
    ("patch_open",         patch_open,         "open",   "crater / burn / bare ground"),
    ("patch_clearing",     patch_clearing,     "open",   "light gets in: grass + scrub, trees at the rim"),
    ("patch_grassfield",   patch_grassfield,   "open",   "chest-high field grass - crouch and vanish"),
    ("patch_paddy",        patch_paddy,        "paddy",  "rice paddy: bunds, water, transplanted clumps"),
    ("patch_paddy_edge",   patch_paddy_edge,   "paddy",  "paddy meets treeline - the killing ground"),
    ("patch_understory",   patch_understory,   "light",  "PRIMARY forest: big boles, bare floor, lianas"),
    ("patch_fern_floor",   patch_fern_floor,   "light",  "fern carpet under a high canopy"),
    ("patch_scrub",        patch_scrub,        "light",  "knee-to-waist regrowth"),
    ("patch_trail",        patch_trail,        "light",  "walkable lane, jungle on both shoulders"),
    ("patch_canopy",       patch_canopy,       "medium", "closed canopy, lianas strung between crowns"),
    ("patch_deadfall",     patch_deadfall,     "medium", "blowdown: crossed logs, ferns colonising"),
    ("patch_palmgrove",    patch_palmgrove,    "medium", "palms + banana"),
    ("patch_vine_hall",    patch_vine_hall,    "medium", "tree ring, lianas criss-crossed overhead"),
    ("patch_grove",        patch_grove,        "dense",  "THICK MIX: canopy + bamboo + bush"),
    ("patch_bamboo_grove", patch_bamboo_grove, "dense",  "bamboo woven through standing timber"),
    ("patch_secondary",    patch_secondary,    "dense",  "SECONDARY GROWTH: broken canopy, riot of light"),
    ("patch_elephant",     patch_elephant,     "dense",  "elephant grass sea"),
    ("patch_thicket",      patch_thicket,      "wall",   "no sightlines - where an ambush lives"),
    ("patch_tangle",       patch_tangle,       "wall",   "MAX THICK: cut through it"),
    ("patch_bamboo_wall",  patch_bamboo_wall,  "wall",   "bamboo brake, near-impassable"),
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


def main():
    F.clean()
    F.save_palette_png()
    os.makedirs(OUT_DIR, exist_ok=True)
    manifest, rows = [], []
    for i, (name, fn, density, desc) in enumerate(PATCHES):
        rng = random.Random(SEED + i * 101)
        p = Patch(name)
        fn(p, rng)
        ob = p.bake(flat=False)
        tris = sum(max(0, len(f) - 2) for f in p.faces)
        zs = [v[2] for v in p.verts]
        export(ob, os.path.join(OUT_DIR, name + ".glb"))
        pf = p.bake_far()
        far_tris = sum(max(0, len(f) - 2) for f in pf.faces)
        export(pf.bake(flat=False), os.path.join(OUT_DIR, name + "_far.glb"))
        manifest.append(dict(name=name, density=density, desc=desc, tile_m=TILE,
                             verts=len(p.verts), tris=tris, far_tris=far_tris,
                             height_m=round(max(zs) - min(zs), 2)))
        rows.append((name, density, len(p.verts), tris, far_tris,
                     round(max(zs), 1), desc))
        for o in list(bpy.data.objects):
            bpy.data.objects.remove(o, do_unlink=True)
    with open(os.path.join(OUT_DIR, "patches.json"), "w") as f:
        json.dump(dict(tile_m=TILE, patches=manifest), f, indent=2)
    print("\n%-19s %-7s %6s %6s %7s %6s  %s"
          % ("patch", "density", "verts", "tris", "fartris", "top_m", "role"))
    for r in rows:
        print("%-19s %-7s %6d %6d %7d %6.1f  %s" % r)
    print("\n%d patches -> %s" % (len(rows), OUT_DIR))
    print("near tris: %d (avg %d)   far tris: %d (avg %d, %.0f%% of near)" % (
        sum(r[3] for r in rows), sum(r[3] for r in rows) // len(rows),
        sum(r[4] for r in rows), sum(r[4] for r in rows) // len(rows),
        100.0 * sum(r[4] for r in rows) / max(1, sum(r[3] for r in rows))))


if __name__ == "__main__":
    main()
