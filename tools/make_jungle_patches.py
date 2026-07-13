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
        # DECLARED WATER VOLUMES, not baked geometry. A LIST - a paddy tile split into
        # four pans by a cross-bund has four separate sheets of water, each held by its
        # own ring. See declare_water().
        self.water = []
        # DECLARED TREES the game can collide with and fell. See record_tree().
        self.trees = []

    def declare_water(self, level, half, at=(0.0, 0.0)):
        """This patch has a flooded pan. DO NOT bake a water quad into the mesh.

        The old paddies stamped a flat quad with a `paddy_water` palette colour straight
        into the patch. That quad then got merged into the one big vegetation surface and
        rendered through vegetation_sway.gdshader - which is OPAQUE, alpha-scissored and
        lambert-lit. So the "water" was not water. It was a dark leaf lying flat: no
        transparency, no depth, no ripple, no shore. That is why a rice paddy read as a
        black hole in the ground.

        Meanwhile terrain/water/water_swamp.gdshader already exists and is described, in
        its own header, as "shallow, vegetated wetland" - with ripples, muck, depth fade
        and a shore fade. That IS a rice paddy. We were shipping a black quad next to the
        exact shader we needed.

        So the patch now DECLARES its water and the game renders it with the terrain's
        own water. One source of truth for water in the whole game.

        Call it ONCE PER PAN. A tile cross-bunded into four smaller pans holds four
        separate sheets of water, each at its own level inside its own ring - which is
        why this appends instead of assigning.

        level -- surface height above the tile floor, metres
        half  -- half-extent. A number for a square pan, or (hx, hy) for a rectangular
                 one. patch_paddy_edge is only wet on ONE SIDE of the tile, so its pan is
                 a long rectangle, not a square - forcing it square shrank it to 4.8 m in
                 a 12 m tile and left most of the paddy dry.
        at    -- pan centre within the tile, metres
        """
        try:
            hx, hy = float(half[0]), float(half[1])
        except TypeError:
            hx = hy = float(half)
        self.water.append(dict(level=round(level, 3),
                               half=[round(hx, 3), round(hy, 3)],
                               at=[round(at[0], 3), round(at[1], 3)]))

    def stamp(self, plant, at=(0, 0, 0), yaw=0.0, scale=1.0, detail=False, tree_slot=0):
        """tree_slot > 0 tags every vertex of this plant as belonging to destructible
        tree `tree_slot`. It rides COLOR.b out to the game (see Plant.bake). Note this
        method does NOT go through Plant.add(), so the slot list has to be extended by
        hand here - miss it and COLOR.b goes out of step with the vertices, and the game
        fells the wrong tree."""
        base = len(self.verts)
        self.verts += F.place(plant.verts, yaw=yaw, origin=at, scale=scale)
        self.sway += list(plant.sway)
        self.tree += [tree_slot] * len(plant.verts)
        pdet = getattr(plant, "detail", None)
        for i, f in enumerate(plant.faces):
            self.faces.append([base + j for j in f])
            self.mats.append(plant.mats[i])          # palette index
            own = bool(pdet[i]) if pdet and i < len(pdet) else False
            self.detail.append(detail or own)

    def record_tree(self, x, y, radius, bole_h, tree_h, slot):
        """Declare a tree the GAME can collide with and blow down.

        BROADLEAF ONLY. Its bole is F.TRUNK_RADIUS - 64 cm across at the reference height -
        a tree you can genuinely put your body behind. Bamboo culms are 0.03 m and palm
        saplings 0.045 m: they are NOT cover, and giving them colliders would be a lie in
        the other direction (a rifle round goes through bamboo, and the game should let it).

        WHAT THE GAME DOES WITH EACH FIELD:
          at    where it stands in the tile
          r     the trunk COLLIDER radius (a CylinderShape3D on layer 1)
          h     the BOLE height - how tall that collider is
          th    the WHOLE TREE's height. The game scales felled_tree.glb by
                th / tree_ref.height, so the tree that falls is the tree that was standing.
                Miss this and a 13 m tree dies and a stock 10 m one falls over in its place.
          slot  which bit to flip to make this tree, and only this tree, collapse
        """
        if len(self.trees) >= F.Plant.MAX_TREES:
            raise RuntimeError(
                "%s wants more than %d destructible trees. The game packs one BIT PER "
                "TREE into a float32 of MultiMesh custom data, so %d is a hard ceiling."
                % (self.name, F.Plant.MAX_TREES, F.Plant.MAX_TREES))
        self.trees.append(dict(at=[round(x, 3), round(y, 3)],
                               r=round(radius, 3), h=round(bole_h, 2),
                               th=round(tree_h, 2), slot=slot))

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
        # The far LOD keeps a SUBSET of the vertices, so the slot list has to be
        # re-indexed with them. Forget this and COLOR.b goes out of step in the far mesh:
        # the game would fell a tree at distance and watch a fern disappear.
        far.tree = [self.tree[j] for j in used]
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

## Where the edge feather begins, as a fraction of HALF.
##
## The obvious value is (TILE*0.5)/HALF = 0.77 - "start fading exactly at the tile line".
## It is too late. It leaves the inner 77% of the tile at full density, so an isolated
## patch is still a hard-edged box with a soft rim painted on it - and you can see the
## square from across the valley.
##
## 0.58 puts the fade well INSIDE the tile, so the density is already falling before it
## reaches the boundary and the patch has no edge to speak of. That does NOT thin a tiled
## field, because neighbouring tiles overlap by OVERHANG*2 = 3.6 m and their ramps
## overlap in the same world space - so the middle of a jungle stays thick and only the
## OUTSIDE of the whole mass feathers away. Which is exactly what a treeline does.
CORE = 0.58
## How hard the boundary is warped by noise. This is what turns a soft SQUARE into an
## irregular blob - without it the falloff is radial and you have just rounded the corners
## of the box you were trying to get rid of.
EDGE_WARP = 0.30

## Set once per patch in main(). Every scatter in a patch reads the SAME clump field, so
## a thicket has trees AND bush AND grass in it, and the gaps between them are genuinely
## open. Give each species its own noise and you get three independent clouds that average
## back out to the uniform mush we are trying to get rid of.
_CLUMP_SEED = [0.0]


def _noise2(x, y, seed):
    """Deterministic smooth 2D field, 0..1. Three detuned sines - no dependencies, and at
    a 12 m tile the eye cannot tell it from Perlin."""
    v = (math.sin(x * 0.37 + y * 0.21 + seed) * 0.50
         + math.sin(x * 0.19 - y * 0.44 + seed * 1.7 + 2.1) * 0.30
         + math.sin(x * 0.71 + y * 0.13 + seed * 0.6 + 4.3) * 0.20)
    return 0.5 + 0.5 * v


def scatter_pts(rng, n, min_dist, half=HALF, avoid=None, ring=None,
                feather=True, clump=0.55):
    """n points, no two closer than min_dist (Poisson-disc by dart throwing).

    `avoid` = [(x,y,r)] keep-out circles (a trail lane). `ring` = (in, out) to hug the rim.

    ------------------------------------------------------------------------------------
    THE BOX PROBLEM. This used to sample UNIFORMLY in a square and space the results
    EVENLY (Poisson). So every patch was a uniformly dense square of vegetation. The 1.8 m
    overhang hid the seam between two full tiles - but the FOOTPRINT was still a hard
    square, and the moment a tile sat next to an empty one (which `fill_chance` guarantees)
    you got a straight edge of jungle across open ground. Put one lone tree on it and it
    read as exactly what it was: a box with a tree on the corner. In a 12 m grid stretching
    to the horizon, that is unmissable.

    Two fixes, and they are the same fix - stop pretending vegetation is uniform:

    FEATHER (`feather`) - density ramps linearly to zero across the overhang band. The ramp
      is complementary: tile A's outer band and tile B's outer band overlap in the same
      world space and SUM BACK TO FULL, so a tiled field is seamless and even. But a tile
      with no neighbour keeps its soft, ragged edge - so an isolated patch is an organic
      blob, not a box.

    CLUMP (`clump`) - a low-frequency noise field modulates local density, so the interior
      grows THICKETS AND GAPS instead of an even carpet. Real plants compete for light and
      root room; they do not sit on a lattice. This is also the single biggest thing that
      makes a patch look grown rather than stamped.

    Set `feather=False` for anything whose extent is deliberate and must not be softened -
    a paddy's bund ring, for instance, which has to butt exactly against its neighbour.
    """
    pts, tries, cap = [], 0, n * 140    # rejection sampling needs more darts
    seed = _CLUMP_SEED[0]
    while len(pts) < n and tries < cap:
        tries += 1
        if ring:
            a = rng.uniform(0, math.tau)
            d = rng.uniform(ring[0], ring[1])
            x, y = d * math.cos(a), d * math.sin(a)
        else:
            x = rng.uniform(-half, half)
            y = rng.uniform(-half, half)

        # --- feather the edge so the tile has no hard boundary
        if feather and not ring:
            # Chebyshev distance (the square's own metric), then WARPED BY NOISE so the
            # boundary is an irregular curve. Skip the warp and you have merely rounded
            # the corners of the box you were trying to get rid of.
            r = max(abs(x), abs(y)) / half
            r += EDGE_WARP * (_noise2(x * 1.15, y * 1.15, seed + 9.0) - 0.5)
            if r > CORE:
                keep = 1.0 - (r - CORE) / (1.0 - CORE)
                if rng.random() > max(0.0, keep):
                    continue

        # --- clump the interior: thickets and gaps, not a carpet
        if clump > 0.0:
            c = _noise2(x, y, seed)
            if rng.random() > (1.0 - clump) + clump * c:
                continue

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
    "cogon": 0.78, "reed": 0.95,
}

DETAIL_BUILDERS = (F.grass_tuft, F.fern, F.bush, F.moss_patch,
                   F.elephant_grass, F.palm_sapling, F.tall_grass, F.rice_clump,
                   F.cogon_grass, F.reed_bed)


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

        # This tree gets a SLOT. Everything it is made of - bole, buttress roots, canopy -
        # is tagged with it, so the game can collapse the whole tree by flipping one bit
        # and nothing else in the tile so much as twitches.
        slot = len(patch.trees) + 1          # 1-based; 0 means "not a tree"
        patch.stamp(F.broadleaf_tree(rng, height=h), at=(x, y, 0),
                    yaw=rng.uniform(0, math.tau), tree_slot=slot)

        # The vine strangling the trunk belongs to the tree and falls with it.
        if rng.random() < dress:
            patch.stamp(F.trunk_vine(rng, height=h * rng.uniform(0.4, 0.7)),
                        at=(x, y, 0), yaw=rng.uniform(0, math.tau), tree_slot=slot)

        # The COLLIDER is the bole, and the trunk THICKENS WITH THE TREE - so read the
        # radius from the one place that defines it rather than hardcoding it a third time.
        # `th` (the whole tree's height) is what the game scales felled_tree.glb by, so
        # THE TREE THAT FALLS IS THE TREE THAT WAS STANDING.
        patch.record_tree(x, y,
                          radius=F.TRUNK_RADIUS * (h / F.TREE_REF_HEIGHT),
                          bole_h=h * F.BOLE_FRACTION,
                          tree_h=h,
                          slot=slot)

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


def bamboos(patch, rng, n, avoid=None, ring=None, lo=5.0, hi=8.5, only=None):
    """Bamboo stands.

    BAMBOO IS NOT A GARNISH IN VIETNAM. It is the dominant woody plant across a huge
    share of the country's forest, and it OWNS disturbed ground - burn a patch, bomb it,
    farm it and walk away, and bamboo is what comes back, because it grows from rhizome
    and outruns everything else to the light. So the patches that should be thickest with
    it are exactly the ones that had none: `secondary` (the canopy was broken), `thicket`
    (the ambush ground) and `trail` (bamboo crowds every path).

    `only(x, y) -> bool` rejects ground it must not stand on - a flooded pan, say. Same
    contract as trees(), which bamboos() was missing, so it could not be used on any patch
    that has water in it.
    """
    placed = 0
    for (x, y) in scatter_pts(rng, n * 3, GAP["bamboo"], avoid=avoid, ring=ring):
        if only and not only(x, y):
            continue
        patch.stamp(F.bamboo_stand(rng, height=rng.uniform(lo, hi)),
                    at=(x, y, 0), yaw=rng.uniform(0, math.tau))
        placed += 1
        if placed >= n:
            break


def logs(patch, rng, n, avoid=None):
    for (x, y) in scatter_pts(rng, n, GAP["log"], avoid=avoid):
        patch.stamp(F.fallen_log(rng, length=rng.uniform(3.0, 5.2)),
                    at=(x, y, 0), yaw=rng.uniform(0, math.tau))


# ================================================================== OPEN (3)
def patch_open(p, rng):
    """Crater / burn / bare ground. The eye needs rest and a firefight needs
    somewhere to happen."""
    # cogon is the weed that owns burned ground - a crater grows it back first
    sow(p, rng, F.cogon_grass, 7, 1.6, 2.4, "height", GAP["cogon"])
    sow(p, rng, F.grass_tuft, 30, 0.4, 0.8, "height", GAP["grass"])
    sow(p, rng, F.bush, 3, 0.9, 1.3, "height", GAP["bush"], ring=(6.0, HALF))
    trees(p, rng, 1, ring=(6.5, HALF))
    logs(p, rng, 2)
    sow(p, rng, F.moss_patch, 5, 0.8, 1.6, "size", GAP["moss"])


def patch_clearing(p, rng):
    """Light gets in, so the floor answers: grass and scrub, trees at the rim."""
    sow(p, rng, F.cogon_grass, 9, 1.8, 2.5, "height", GAP["cogon"])
    sow(p, rng, F.grass_tuft, 40, 0.5, 0.9, "height", GAP["grass"])
    sow(p, rng, F.tall_grass, 12, 0.8, 1.3, "height", GAP["tall_grass"])
    sow(p, rng, F.fern, 6, 0.9, 1.4, "height", GAP["fern"], ring=(5.0, HALF))
    tops = trees(p, rng, 2, ring=(6.0, HALF))
    lianas(p, rng, tops, chance=0.4)
    logs(p, rng, 1)


def patch_grassfield(p, rng):
    """Open but TALL - chest-high field grass. Cross it standing and you are
    seen; crouch and you vanish."""
    sow(p, rng, F.cogon_grass, 12, 1.9, 2.6, "height", GAP["cogon"])
    sow(p, rng, F.tall_grass, 46, 1.1, 1.9, "height", GAP["tall_grass"])
    sow(p, rng, F.grass_tuft, 22, 0.5, 0.8, "height", GAP["grass"])
    sow(p, rng, F.elephant_grass, 8, 1.6, 2.1, "height", GAP["elephant"],
        ring=(4.5, HALF))
    trees(p, rng, 1, ring=(6.5, HALF))


# ================================================================= PADDY (5)
HALF_BUND = 0.45          # two tiles butt -> a 0.9 m footpath between neighbouring pans


def paddy_ring(p, rng, half_bund=HALF_BUND):
    """The closed bund ring EVERY paddy variant must have to stack into a field.

    Factored out on purpose: a paddy tile only tiles if its ring obeys three rules, and
    a variant that reinvents its own bunds will quietly break all three. Build the ring
    here, once, and every variant inherits a tile that stacks.

    1. ALL FOUR EDGES, so the ring is 4-fold symmetric. jungle_patch_layer rotates every
       tile by a random 90-degree step; a symmetric ring maps onto itself, so the bunds
       still meet their neighbours whichever way the tile landed.
    2. EACH TILE OWNS HALF A BUND, inset just inside its own edge. Butt two tiles and the
       half-bunds meet into one double-width bund - which is what the fat bund between two
       real pans IS: the footpath. (Bunding the boundary LINE would put two tiles'
       geometry in the same place and z-fight.)
    3. EXACTLY TILE LONG. No overhang, so the ends meet at the corner and stop.

    Returns the pan's inner half-extent - i.e. how much water and rice the ring can hold.
    """
    inset = TILE * 0.5 - half_bund * 0.5
    for k in (-1, 1):
        p.stamp(F.paddy_dike(rng, length=TILE, width=half_bund), at=(0, k * inset, 0))
        p.stamp(F.paddy_dike(rng, length=TILE, width=half_bund),
                at=(k * inset, 0, 0), yaw=math.pi / 2)
    return TILE * 0.5 - half_bund


def sow_rice(p, rng, n, cx, cy, half, ripe):
    """Transplanted clumps inside one pan. NEVER pass detail=True to the stamp - stamp()
    ORs its flag over the plant's own, which would throw away the structure stalks that
    rice_clump keeps so the crop still stands (and sways) past the 46 m LOD line."""
    # NO FEATHER, LIGHT CLUMP. A paddy is a planted crop inside a bund ring: its
    # extent is deliberate, and softening it would thin the rice against the bund and
    # leave a dry margin. Farmers transplant in rows, not thickets - but not on a
    # perfect lattice either, so keep a little clump.
    for (x, y) in scatter_pts(rng, n, GAP["rice"], half=half, feather=False, clump=0.18):
        p.stamp(F.rice_clump(rng, height=rng.uniform(0.55, 0.85), ripe=ripe),
                at=(cx + x, cy + y, 0.02), yaw=rng.uniform(0, math.tau),
                scale=rng.uniform(0.85, 1.2))


def patch_paddy(p, rng):
    """Bunds holding a shallow pan of water, rice transplanted in clumps. The
    dikes are the only dry footing - that is the tactical point of a paddy.

    THIS TILE IS BUILT TO BE STACKED. A single paddy is not a thing you find in the
    world; a paddy FIELD is - a mosaic of bunded pans stitched across a flat valley
    floor. So the tile has to survive being laid next to copies of itself.

    Three rules make that work, and the old tile broke all three:

    1. A CLOSED RING, ON ALL FOUR EDGES. The old tile bunded only three (two on Y, one
       on +X), so the fourth side was open and the water had nowhere to be held. It also
       meant the tile was NOT 4-fold symmetric - and jungle_patch_layer rotates every
       tile by a random 90-degree step, so the missing side landed in a different place
       each time. Now every edge has a bund, so a rotation maps the ring onto itself.

    2. EACH TILE OWNS HALF A BUND. Each bund is INSET to sit in the strip just inside
       its own tile edge. Butt two tiles together and their half-bunds meet at the
       boundary to form one bund of double width - which is exactly what a real paddy
       field looks like: the fat bund between two pans IS the footpath. The outer rim of
       the field is left a single width, which is also right: nobody walks the outside.
       (Bunding the tile's own boundary line instead would put two tiles' geometry in
       the same place and z-fight.)

    3. NOTHING OVERHANGS. The old bunds were TILE + 3.0 m long on a 12 m tile - a 1.5 m
       overhang at each end, so stacked tiles grew a lattice of crossing bund stubs.
       They are exactly TILE long now, so ends meet at the corner and stop.
    """
    inner = paddy_ring(p, rng)
    # water stops just under the bund's inner foot, so there is no dry seam at the edge
    p.declare_water(level=0.055, half=inner + 0.25, at=(0.0, 0.0))
    # rice stays INSIDE the ring - rice does not grow on the footpath
    sow_rice(p, rng, 130, 0.0, 0.0, inner - 0.25, rng.random() < 0.4)


def patch_paddy_quad(p, rng):
    """ONE TILE, FOUR PANS. A cross-bund splits the tile into four smaller paddies.

    Real paddy fields are not a regular grid of identical squares - pan size follows the
    land and the family that owns it, so a big pan sits next to four small ones. Dropping
    this variant in among patch_paddy is what stops a generated field reading as graph
    paper.

    It is also the more DANGEROUS tile to cross: twice as many bunds means twice as much
    dry footing, so it channels movement - and anything that channels movement is where
    an ambush goes.

    The interior cross-bund is FULL width (0.9 m). It is not shared with a neighbouring
    tile, so it does not get halved - it is a whole footpath in its own right. The outer
    ring is still half-width, so the tile stacks exactly like every other paddy."""
    inner = paddy_ring(p, rng)
    cross_w = HALF_BUND * 2.0
    p.stamp(F.paddy_dike(rng, length=TILE, width=cross_w), at=(0, 0, 0))
    p.stamp(F.paddy_dike(rng, length=TILE, width=cross_w), at=(0, 0, 0),
            yaw=math.pi / 2)
    # four pans, one per quadrant, between the cross-bund and the ring
    lo = cross_w * 0.5
    pan_half = (inner - lo) * 0.5
    pan_c = lo + pan_half
    ripe = rng.random() < 0.4
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = sx * pan_c, sy * pan_c
            p.declare_water(level=0.055, half=pan_half + 0.20, at=(cx, cy))
            sow_rice(p, rng, 28, cx, cy, pan_half - 0.25, ripe)


def patch_paddy_fallow(p, rng):
    """A pan gone to seed. Nobody has worked this one in a season: the rice has thinned
    and weeds, reeds and grass have taken the water. The bunds have grown over.

    Tactically this is the one that MATTERS. A worked paddy is shin-deep and empty - you
    are naked in it. A fallow one is chest-high in reeds, so it is the only paddy you can
    actually cross unseen. It also breaks the read: a field of identical worked pans is a
    farm, and a field with a couple of fallow ones is a PLACE."""
    inner = paddy_ring(p, rng)
    p.declare_water(level=0.055, half=inner + 0.25, at=(0.0, 0.0))
    sow_rice(p, rng, 34, 0.0, 0.0, inner - 0.3, ripe=True)     # what is left, and it is ripe
    # reeds and grass have taken the water
    # REEDS. This tile exists to be the ONE paddy a man can cross unseen, and reeds
    # are what makes that literally true - dead-vertical, chest-to-head high, growing
    # straight out of the water. Without them a fallow paddy is ankle-deep and naked.
    sow(p, rng, F.reed_bed, 26, 2.0, 3.0, "height", GAP["reed"], ring=(0.0, inner - 0.5))
    sow(p, rng, F.tall_grass, 26, 0.9, 1.5, "height", GAP["grass"], ring=(0.0, inner - 0.4))
    sow(p, rng, F.elephant_grass, 10, 1.3, 1.9, "height", GAP["elephant"],
        ring=(0.0, inner - 0.8))
    # and the bunds have grown over - the footpath is disappearing
    for _ in range(10):
        s = rng.choice((-1, 1))
        a = rng.uniform(-inner, inner)
        x, y = (a, s * inner) if rng.random() < 0.5 else (s * inner, a)
        p.stamp(F.bush(rng, height=rng.uniform(0.7, 1.3)), at=(x, y, 0.1),
                yaw=rng.uniform(0, math.tau), detail=True)


def patch_paddy_grove(p, rng):
    """A worked pan with the farm's trees standing on its bunds - palms and banana over
    the footpath, the way a real field has shade and fruit along every walkable line.

    This is the paddy tile with a SKYLINE. A field of nothing but flat pans has no
    cover and nothing to break sightlines, which makes the whole valley read as a
    parking lot. A few of these scattered through it give the player something to move
    between - and give the VC somewhere to be."""
    inner = paddy_ring(p, rng)
    p.declare_water(level=0.055, half=inner + 0.25, at=(0.0, 0.0))
    sow_rice(p, rng, 100, 0.0, 0.0, inner - 0.3, rng.random() < 0.4)
    # trees stand ON the bunds - the only dry ground there is
    corners = [(inner, inner), (-inner, inner), (inner, -inner), (-inner, -inner)]
    rng.shuffle(corners)
    for (x, y) in corners[:rng.randint(2, 3)]:
        jx, jy = x + rng.uniform(-0.8, 0.8), y + rng.uniform(-0.8, 0.8)
        if rng.random() < 0.55:
            p.stamp(F.palm_sapling(rng, height=rng.uniform(3.4, 5.2)), at=(jx, jy, 0.15),
                    yaw=rng.uniform(0, math.tau))
        else:
            p.stamp(F.banana(rng, height=rng.uniform(2.6, 3.6)), at=(jx, jy, 0.15),
                    yaw=rng.uniform(0, math.tau))
    for _ in range(8):
        s = rng.choice((-1, 1))
        a = rng.uniform(-inner, inner)
        x, y = (a, s * inner) if rng.random() < 0.5 else (s * inner, a)
        p.stamp(F.bush(rng, height=rng.uniform(0.6, 1.1)), at=(x, y, 0.12),
                yaw=rng.uniform(0, math.tau), detail=True)


def patch_paddy_edge(p, rng):
    """Where the paddy stops and the treeline starts - the classic killing
    ground: you are in the open, wet and slow, and they are in the green.

    It carries the SAME bund ring as every other paddy tile, so it butts cleanly against
    them - it is the wall of the field, not a different kind of object.

    EVERYTHING STAYS INSIDE THE RING. The old version scattered its trees, bushes and
    ferns out to HALF (6.0 m) - but the bund occupies 5.55-6.0 m, so the treeline grew
    straight THROUGH its own bund and the lianas were strung across it. A tree standing
    in a dike is not a treeline, it is a mistake. The dry bank is the ground INSIDE the
    ring on the far side of the divider; that is where the jungle gets to grow.
    """
    inner = paddy_ring(p, rng)
    # Wet on ONE side only, dry bank on the other - so the pan is a RECTANGLE spanning the
    # full width of the tile and a bit over half its depth. (It used to be forced square,
    # which shrank a 12 m paddy to a 4.8 m puddle with dry mud all round it.)
    bank = 0.5                        # where the water stops and the dry bank begins
    hy = (bank + inner) * 0.5
    cy = (bank - inner) * 0.5
    p.declare_water(level=0.055, half=(inner + 0.25, hy + 0.25), at=(0.0, cy))

    # THE DIVIDER. A full-width bund holding the water off the bank - and it is the only
    # dry line across the field. This IS the killing ground: the one path out of the
    # water runs along it, in the open, straight at the treeline.
    p.stamp(F.paddy_dike(rng, length=TILE, width=HALF_BUND * 2.0), at=(0, bank, 0))

    for (x, y) in scatter_pts(rng, 70, GAP["rice"], half=inner - 0.3, feather=False, clump=0.18):
        if y > bank - HALF_BUND - 0.3:
            continue                  # no rice on the divider or the bank
        p.stamp(F.rice_clump(rng, height=rng.uniform(0.55, 0.85)),
                at=(x, y, 0.02), yaw=rng.uniform(0, math.tau),
                scale=rng.uniform(0.85, 1.2))

    # the dry bank: the strip between the divider and the far bund. Everything here is
    # clamped INSIDE the ring so nothing grows out of a dike.
    b0 = bank + HALF_BUND + 0.4
    b1 = inner - 0.5
    xr = inner - 0.5
    for _ in range(14):
        p.stamp(F.bush(rng, height=rng.uniform(1.2, 1.9)),
                at=(rng.uniform(-xr, xr), rng.uniform(b0, b1), 0),
                yaw=rng.uniform(0, math.tau), detail=True)
    for _ in range(12):
        p.stamp(F.fern(rng, height=rng.uniform(1.0, 1.6)),
                at=(rng.uniform(-xr, xr), rng.uniform(b0, b1), 0),
                yaw=rng.uniform(0, math.tau), detail=True)
    # reeds crowd the waterline where the pan meets the bank - the last thing you have
    # to break cover from before the open water
    for _ in range(10):
        p.stamp(F.reed_bed(rng, height=rng.uniform(1.8, 2.6)),
                at=(rng.uniform(-xr, xr), rng.uniform(bank - 1.4, bank - 0.5), 0.03),
                yaw=rng.uniform(0, math.tau), detail=True)
    # the treeline itself - standing ON the bank, not in the dike
    tops = trees(p, rng, 4, ring=(0.0, xr), only=lambda x, y: b0 < y < b1)
    lianas(p, rng, tops, chance=0.7)
    # and bamboo, because in Vietnam the treeline usually IS bamboo
    bamboos(p, rng, 3, ring=(0.0, xr), only=lambda x, y: b0 < y < b1)


# ================================================================= LIGHT (4)
def patch_understory(p, rng):
    """PRIMARY forest. The canopy takes 95-99% of the light so the floor is
    nearly BARE: big boles, deep shade, lianas hanging through. This is the
    jungle you can actually move in - and the old batch had none of it."""
    # even under a closed primary canopy there are bamboo clumps in the light gaps
    bamboos(p, rng, 3, lo=6.5, hi=9.5)
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
    sow(p, rng, F.cogon_grass, 8, 1.5, 2.2, "height", GAP["cogon"])
    bamboos(p, rng, 4, lo=3.5, hi=5.5)
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
    bamboos(p, rng, 4, lo=6.0, hi=9.0)
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
    bamboos(p, rng, 8)
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
    sow(p, rng, F.cogon_grass, 10, 1.7, 2.4, "height", GAP["cogon"])
    # THE BIG ONE. Secondary growth is ground where the canopy was BROKEN - bombed,
    # burned, farmed and abandoned. Bamboo owns that ground: it spreads by rhizome
    # and outruns every tree to the light, so a cut-over hillside in Vietnam comes
    # back as bamboo, not as forest. This patch had ZERO.
    bamboos(p, rng, 11, lo=5.0, hi=8.0)
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
    # Two grasses, not one. Elephant grass arches into a soft mound; cogon stands
    # HEAD HIGH and dead straight. At PSX range silhouette is all you get, so two
    # grasses that arch the same way are one grass with two names - and this tile
    # is supposed to be the one a patrol vanishes into.
    sow(p, rng, F.cogon_grass, 20, 2.0, 2.8, "height", GAP["cogon"])
    sow(p, rng, F.elephant_grass, 40, 1.7, 2.5, "height", GAP["elephant"])
    sow(p, rng, F.tall_grass, 18, 1.1, 1.7, "height", GAP["tall_grass"])
    sow(p, rng, F.grass_tuft, 20, 0.5, 0.8, "height", GAP["grass"])
    trees(p, rng, 1, ring=(6.0, HALF))
    sow(p, rng, F.bush, 4, 1.2, 1.7, "height", GAP["bush"], ring=(5.0, HALF))


# ================================================================== WALL (3)
def patch_thicket(p, rng):
    """No sightlines. Where an ambush lives."""
    # THICKET = AMBUSH GROUND, and in Vietnam that is a bamboo brake. Bamboo grows
    # in dense clumps you cannot see through OR push through - which is the entire
    # point of this tile, and it had none.
    bamboos(p, rng, 8, lo=4.5, hi=7.0)
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
    bamboos(p, rng, 11)          # tangle: you cut through this, and it is bamboo you cut
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
    ("patch_paddy",        patch_paddy,        "paddy",  "rice paddy: one worked pan, bunds, transplanted clumps"),
    ("patch_paddy_quad",   patch_paddy_quad,   "paddy",  "four small pans on a cross-bund - twice the dry footing, channels movement"),
    ("patch_paddy_fallow", patch_paddy_fallow, "paddy",  "gone to seed: reeds and grass in the water, bunds overgrown - the ONE paddy you can cross unseen"),
    ("patch_paddy_grove",  patch_paddy_grove,  "paddy",  "worked pan with palms and banana on the bunds - the paddy tile with a skyline"),
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
        # ONE clump field per patch, shared by every species in it. That is the whole
        # point: a thicket has trees AND bush AND grass in it, and the gaps between the
        # thickets are genuinely open. Give each species its own noise and you get three
        # independent clouds that average straight back out to the uniform mush we are
        # trying to get rid of.
        _CLUMP_SEED[0] = rng.uniform(0.0, 100.0)
        p = Patch(name)
        fn(p, rng)
        ob = p.bake(flat=False)
        tris = sum(max(0, len(f) - 2) for f in p.faces)
        zs = [v[2] for v in p.verts]
        export(ob, os.path.join(OUT_DIR, name + ".glb"))
        pf = p.bake_far()
        far_tris = sum(max(0, len(f) - 2) for f in pf.faces)
        export(pf.bake(flat=False), os.path.join(OUT_DIR, name + "_far.glb"))
        entry = dict(name=name, density=density, desc=desc, tile_m=TILE,
                     verts=len(p.verts), tris=tris, far_tris=far_tris,
                     height_m=round(max(zs) - min(zs), 2))
        if p.water:
            # The game reads these and renders the pans with the TERRAIN's swamp water.
            # No water geometry ships in the patch mesh. A LIST - a cross-bunded tile
            # holds four separate sheets.
            entry["water"] = p.water
        if p.trees:
            # The game spawns a trunk COLLIDER per tree (so the tree you dive behind
            # actually stops a bullet - today nothing in the jungle has any collision at
            # all) and gives each one hit points, so an RPG can fell it. `slot` indexes
            # the bit the game flips to make this tree, and only this tree, collapse.
            entry["trees"] = p.trees
        manifest.append(entry)
        rows.append((name, density, len(p.verts), tris, far_tris,
                     round(max(zs), 1), desc))
        for o in list(bpy.data.objects):
            bpy.data.objects.remove(o, do_unlink=True)
    with open(os.path.join(OUT_DIR, "patches.json"), "w") as f:
        json.dump(dict(
            tile_m=TILE,
            # THE REFERENCE TREE. felled_tree.glb / felled_trunk.glb / tree_stump.glb are
            # authored at exactly these numbers. The game scales them by
            #     tree["th"] / tree_ref["height"]
            # so THE TREE THAT FALLS IS THE TREE THAT WAS STANDING. Without this the game
            # has to guess what the GLB was authored at, and the day the guess is wrong a
            # 13 m tree dies and a stock 10 m one falls over in its place.
            tree_ref=dict(height=F.TREE_REF_HEIGHT,
                          bole_h=round(F.TREE_REF_HEIGHT * F.BOLE_FRACTION, 3),
                          trunk_r=F.TRUNK_RADIUS,
                          model="res://assets/models/vegetation/felled_tree.glb",
                          trunk_model="res://assets/models/vegetation/felled_trunk.glb",
                          stump_model="res://assets/models/vegetation/tree_stump.glb"),
            patches=manifest), f, indent=2)
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
