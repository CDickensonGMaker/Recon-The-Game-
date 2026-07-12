"""Jungle PATCHES - 10 pre-composed 12m tiles the level can shuffle and repeat.

Per-plant scatter always looks like noise. Composed patches look authored: a
bamboo grove reads as a grove, a deadfall reads as a blowdown, a canopy stand
has vines actually strung BETWEEN its trees. Ten of them, dropped in random
order and rotation (they're designed to survive 0/90/180/270), give a jungle
that never repeats visibly.

Each patch bakes down to ONE mesh (shared material set) = one draw call per
material, and the sway vertex-colours survive the merge, so the wind shader
still works on every leaf.

The dense near-player grass carpet is NOT in here - ground_clutter.gd already
instances that around the camera. Patches carry the structure: trees, bamboo,
thickets, elephant grass, deadfall, vines.

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

    Verts are shared across the whole stamped plant (not re-emitted per face) -
    a 30k-vert tile drops to ~10k, which matters when 30 tiles are on screen.

    Every stamp is tagged STRUCTURE or DETAIL:
      structure = trees, bamboo, banana, palms, logs, vines  (reads at 150m)
      detail    = grass, fern, bush, moss                    (invisible at 60m)
    We bake both a full mesh and a structure-only `_far` mesh, and the game
    swaps between them by distance. Without this a chunk of solid jungle is
    ~4M triangles on screen, which is not a budget - it is a crash.
    """

    def __init__(self, name):
        super().__init__(name)
        self.detail = []          # per-face: is this throwaway-at-distance?

    def stamp(self, plant, at=(0, 0, 0), yaw=0.0, scale=1.0, detail=False):
        base = len(self.verts)
        self.verts += F.place(plant.verts, yaw=yaw, origin=at, scale=scale)
        self.sway += list(plant.sway)
        pdet = getattr(plant, "detail", None)
        for i, f in enumerate(plant.faces):
            self.faces.append([base + j for j in f])
            self.mats.append(plant.mats[i])      # already a palette index
            # a plant can mark its own throwaway bits (bamboo leaf sprays, vine
            # leaflets); the stamp can mark the WHOLE plant throwaway (grass).
            own = bool(pdet[i]) if pdet and i < len(pdet) else False
            self.detail.append(detail or own)

    def add(self, verts, faces, mname, sway, detail=False):
        n0 = len(self.faces)
        super().add(verts, faces, mname, sway)
        self.detail += [detail] * (len(self.faces) - n0)

    def bake_far(self):
        """Structure-only twin: drop every detail face, drop orphaned verts."""
        keep = [f for f, d in zip(self.faces, self.detail) if not d]
        kept_mats = [m for m, d in zip(self.mats, self.detail) if not d]
        used = sorted({j for f in keep for j in f})
        remap = {j: i for i, j in enumerate(used)}
        far = F.Plant(self.name + "_far")
        far.verts = [self.verts[j] for j in used]
        far.sway = [self.sway[j] for j in used]
        far.faces = [[remap[j] for j in f] for f in keep]
        far.mats = kept_mats
        far.matlist = list(self.matlist)
        return far


def spot(rng, r=TILE * 0.5, edge=0.0):
    """Random point in the tile. `edge` biases toward the rim."""
    a = rng.uniform(0, math.tau)
    d = r * (edge + (1 - edge) * math.sqrt(rng.random()))
    return (d * math.cos(a), d * math.sin(a), 0.0)


def vine_bridge(patch, p0, p1, rng, sag=0.35, leaves=14):
    """A vine slung between two tree tops - the signature jungle read. Catenary
    sag, leaves hanging off the low point."""
    import mathutils
    a, b = mathutils.Vector(p0), mathutils.Vector(p1)
    span = (b - a).length
    segs = max(6, int(span * 1.4))
    pts = []
    for i in range(segs + 1):
        t = i / segs
        p = a.lerp(b, t)
        p.z -= sag * span * math.sin(math.pi * t)      # the droop
        p.x += math.sin(t * 4.0) * 0.12                # a little slack wander
        pts.append(p)
    # ribbon
    verts, faces, sway = [], [], []
    for i, p in enumerate(pts):
        t = i / segs
        w = 0.030
        verts += [(p.x, p.y - w, p.z), (p.x, p.y + w, p.z)]
        s = math.sin(math.pi * t)                       # slack sways, ends pinned
        sway += [s, s]
        if i:
            k = (i - 1) * 2
            faces.append([k, k + 1, k + 3, k + 2])
    patch.add(verts, faces, "bark_dark", sway)
    # leaves + trailing tendrils hanging off the vine
    for _ in range(leaves):
        t = rng.uniform(0.12, 0.88)
        i = int(t * segs)
        p = pts[i]
        lv, lf, ls = F.paddle(rng.uniform(0.14, 0.24), 0.08, segs=2, curve=0.5)
        patch.add(F.place(lv, yaw=rng.uniform(0, math.tau),
                          tilt=rng.uniform(1.5, 2.7), origin=(p.x, p.y, p.z)),
                  lf, "leaf_mid" if rng.random() < .6 else "leaf_deep",
                  [math.sin(math.pi * t)] * len(ls), detail=True)
    for _ in range(rng.randint(2, 4)):                  # dangling tendrils
        t = rng.uniform(0.2, 0.8)
        p = pts[int(t * segs)]
        v = F.hanging_vine(rng, length=rng.uniform(1.4, 2.8), leaves=7)
        patch.stamp(v, at=(p.x, p.y, p.z), yaw=rng.uniform(0, math.tau))


# ------------------------------------------------------------------ recipes
def _trees(patch, rng, n, kinds, edge=0.25, record=None, dress=0.45):
    """Plant n canopy trees, remembering their tops for vine bridges.
    `dress` = chance each tree gets a creeper climbing its bole."""
    for _ in range(n):
        kind = rng.choice(kinds)
        at = spot(rng, r=TILE * 0.42, edge=edge)
        h = rng.uniform(9.0, 13.0)
        if kind == "broadleaf":
            pl = F.broadleaf_tree(rng, height=h)
            top = h * 0.72
        else:
            pl = F.bamboo_stand(rng, height=rng.uniform(5.0, 7.5))
            top = 0.0
        yaw = rng.uniform(0, math.tau)
        patch.stamp(pl, at=at, yaw=yaw)
        if top and rng.random() < dress:                 # creeper up the trunk
            patch.stamp(F.trunk_vine(rng, height=h * rng.uniform(0.35, 0.62)),
                        at=at, yaw=rng.uniform(0, math.tau))
        if record is not None and top:
            record.append((at[0], at[1], top * rng.uniform(0.80, 0.95)))


def _moss(patch, rng, n):
    """Moss/litter mats over the bare ground."""
    for _ in range(n):
        patch.stamp(F.moss_patch(rng, size=rng.uniform(0.8, 1.8)),
                    at=spot(rng), yaw=rng.uniform(0, math.tau), detail=True)


# these vanish past ~60m; everything else is structure that must survive to 150m
DETAIL_BUILDERS = (F.grass_tuft, F.fern, F.bush, F.moss_patch,
                   F.elephant_grass, F.palm_sapling)


def _scatter(patch, rng, builder, n, kw_lo, kw_hi, key, edge=0.0, r=TILE * 0.5):
    is_detail = builder in DETAIL_BUILDERS
    for _ in range(n):
        val = rng.uniform(kw_lo, kw_hi)
        pl = builder(rng, **{key: val})
        patch.stamp(pl, at=spot(rng, r=r, edge=edge), yaw=rng.uniform(0, math.tau),
                    scale=rng.uniform(0.85, 1.2), detail=is_detail)


def patch_canopy(p, rng):
    """Big trees with vines strung between them. The hero patch."""
    tops = []
    _trees(p, rng, 3, ["broadleaf"], edge=0.30, record=tops)
    for i in range(len(tops)):
        for j in range(i + 1, len(tops)):
            if rng.random() < 0.85:
                vine_bridge(p, tops[i], tops[j], rng,
                            sag=rng.uniform(0.22, 0.40))
    _scatter(p, rng, F.fern,   10, 1.0, 1.7, "height")
    _scatter(p, rng, F.bush,    6, 1.2, 1.8, "height")
    _scatter(p, rng, F.grass_tuft, 18, 0.5, 0.8, "height")
    _scatter(p, rng, F.fallen_log, 1, 3.0, 4.0, "length")
    _moss(p, rng, 7)


def patch_bamboo(p, rng):
    for _ in range(9):
        pl = F.bamboo_stand(rng, height=rng.uniform(5.0, 8.5))
        p.stamp(pl, at=spot(rng, r=TILE * 0.46), yaw=rng.uniform(0, math.tau))
    _scatter(p, rng, F.fern, 8, 0.9, 1.4, "height")
    _scatter(p, rng, F.grass_tuft, 22, 0.5, 0.8, "height")


def patch_thicket(p, rng):
    """No sightlines. Where an ambush lives."""
    _scatter(p, rng, F.bush, 20, 1.2, 2.0, "height")
    _scatter(p, rng, F.fern, 16, 1.0, 1.7, "height")
    _scatter(p, rng, F.palm_sapling, 5, 1.8, 2.6, "height")
    _scatter(p, rng, F.grass_tuft, 24, 0.5, 0.8, "height")
    _trees(p, rng, 1, ["broadleaf"], edge=0.55)
    _moss(p, rng, 8)


def patch_elephant(p, rng):
    """Chest-high grass sea. You cannot see a crouching man in this."""
    _scatter(p, rng, F.elephant_grass, 42, 1.7, 2.4, "height")
    _scatter(p, rng, F.grass_tuft, 26, 0.5, 0.8, "height")
    _trees(p, rng, 1, ["broadleaf"], edge=0.70)
    _scatter(p, rng, F.bush, 3, 1.2, 1.7, "height", edge=0.6)


def patch_deadfall(p, rng):
    """A blowdown: crossed logs, ferns colonising them."""
    for _ in range(5):
        pl = F.fallen_log(rng, length=rng.uniform(3.0, 5.0))
        p.stamp(pl, at=spot(rng, r=TILE * 0.40), yaw=rng.uniform(0, math.tau))
    _scatter(p, rng, F.fern, 18, 1.0, 1.6, "height")
    _scatter(p, rng, F.bush, 7, 1.1, 1.6, "height")
    _scatter(p, rng, F.grass_tuft, 20, 0.5, 0.8, "height")
    _trees(p, rng, 1, ["broadleaf"], edge=0.6)
    _moss(p, rng, 9)


def patch_palm(p, rng):
    for _ in range(5):
        pl = F.palm_sapling(rng, height=rng.uniform(2.2, 3.4))
        p.stamp(pl, at=spot(rng, r=TILE * 0.44), yaw=rng.uniform(0, math.tau),
                scale=rng.uniform(1.4, 2.4))          # grown palms
    _scatter(p, rng, F.palm_sapling, 6, 1.6, 2.4, "height")
    _scatter(p, rng, F.fern, 10, 1.0, 1.6, "height")
    _scatter(p, rng, F.grass_tuft, 20, 0.5, 0.8, "height")


def patch_banana(p, rng):
    _scatter(p, rng, F.banana, 9, 2.8, 4.0, "height", r=TILE * 0.44)
    _scatter(p, rng, F.fern, 10, 1.0, 1.6, "height")
    _scatter(p, rng, F.bush, 5, 1.2, 1.7, "height")
    _scatter(p, rng, F.grass_tuft, 20, 0.5, 0.8, "height")


def patch_clearing(p, rng):
    """Relief. Sightlines open up - this is where a firefight can breathe."""
    _scatter(p, rng, F.grass_tuft, 40, 0.5, 0.9, "height")
    _scatter(p, rng, F.elephant_grass, 6, 1.6, 2.1, "height", edge=0.55)
    _scatter(p, rng, F.fern, 5, 0.9, 1.4, "height", edge=0.6)
    _trees(p, rng, 2, ["broadleaf"], edge=0.80)
    _scatter(p, rng, F.fallen_log, 1, 3.0, 4.5, "length")


def patch_mixed(p, rng):
    tops = []
    _trees(p, rng, 2, ["broadleaf"], edge=0.35, record=tops)
    if len(tops) == 2:
        vine_bridge(p, tops[0], tops[1], rng, sag=rng.uniform(0.25, 0.42))
    for _ in range(3):
        pl = F.bamboo_stand(rng, height=rng.uniform(5.0, 7.0))
        p.stamp(pl, at=spot(rng, r=TILE * 0.45), yaw=rng.uniform(0, math.tau))
    _scatter(p, rng, F.bush, 10, 1.2, 1.8, "height")
    _scatter(p, rng, F.fern, 12, 1.0, 1.6, "height")
    _scatter(p, rng, F.elephant_grass, 10, 1.7, 2.2, "height")
    _scatter(p, rng, F.banana, 2, 2.8, 3.6, "height")
    _scatter(p, rng, F.grass_tuft, 22, 0.5, 0.8, "height")
    _scatter(p, rng, F.fallen_log, 1, 3.0, 4.0, "length")
    _moss(p, rng, 8)


def patch_edge(p, rng):
    """Transition tile: thick along -X, open toward +X. Place these where the
    jungle meets a trail, paddy, or clearing."""
    for _ in range(16):
        x = -TILE * 0.5 + abs(rng.gauss(0, 0.28)) * TILE * 0.5
        y = rng.uniform(-TILE * .48, TILE * .48)
        pl = F.bush(rng, height=rng.uniform(1.3, 2.0))
        p.stamp(pl, at=(x, y, 0), yaw=rng.uniform(0, math.tau), detail=True)
    for _ in range(10):
        x = -TILE * 0.5 + abs(rng.gauss(0, 0.40)) * TILE * 0.6
        y = rng.uniform(-TILE * .48, TILE * .48)
        pl = F.fern(rng, height=rng.uniform(1.0, 1.6))
        p.stamp(pl, at=(x, y, 0), yaw=rng.uniform(0, math.tau), detail=True)
    _trees(p, rng, 2, ["broadleaf"], edge=0.85)
    for _ in range(26):
        x = rng.uniform(-TILE * .48, TILE * .48)
        y = rng.uniform(-TILE * .48, TILE * .48)
        pl = F.grass_tuft(rng, height=rng.uniform(0.5, 0.8))
        p.stamp(pl, at=(x, y, 0), yaw=rng.uniform(0, math.tau), detail=True)


def patch_vine_hall(p, rng):
    """Four trees ringing an open middle, vines criss-crossed overhead. You
    walk under it."""
    tops = []
    for i in range(4):
        a = math.tau * i / 4 + rng.uniform(-0.25, 0.25)
        r = TILE * rng.uniform(0.34, 0.44)
        at = (r * math.cos(a), r * math.sin(a), 0.0)
        h = rng.uniform(10.0, 13.5)
        p.stamp(F.broadleaf_tree(rng, height=h), at=at, yaw=rng.uniform(0, math.tau))
        tops.append((at[0], at[1], h * 0.72 * rng.uniform(0.82, 0.95)))
    for i in range(4):
        vine_bridge(p, tops[i], tops[(i + 1) % 4], rng, sag=rng.uniform(0.28, 0.45))
    vine_bridge(p, tops[0], tops[2], rng, sag=rng.uniform(0.35, 0.5))   # the crossing
    _scatter(p, rng, F.fern, 8, 1.0, 1.5, "height", r=TILE * 0.30)
    _scatter(p, rng, F.grass_tuft, 20, 0.5, 0.8, "height")
    _moss(p, rng, 8)


def patch_trail(p, rng):
    """A walkable lane down the middle, jungle crowding both sides. String
    these to build a trail the player can actually follow."""
    for side in (-1, 1):
        for _ in range(11):
            y = side * (TILE * 0.20 + abs(rng.gauss(0, 0.9)))
            x = rng.uniform(-TILE * .48, TILE * .48)
            if abs(y) > TILE * .48:
                continue
            pl = (F.bush(rng, height=rng.uniform(1.3, 2.0)) if rng.random() < .6
                  else F.fern(rng, height=rng.uniform(1.0, 1.6)))
            p.stamp(pl, at=(x, y, 0), yaw=rng.uniform(0, math.tau), detail=True)
    tops = []
    for side in (-1, 1):
        at = (rng.uniform(-4, 4), side * rng.uniform(4.5, 5.6), 0.0)
        h = rng.uniform(10.0, 12.5)
        p.stamp(F.broadleaf_tree(rng, height=h), at=at, yaw=rng.uniform(0, math.tau))
        tops.append((at[0], at[1], h * 0.72 * 0.9))
    vine_bridge(p, tops[0], tops[1], rng, sag=rng.uniform(0.30, 0.45))  # over the trail
    for _ in range(18):        # sparse grass in the lane itself
        p.stamp(F.grass_tuft(rng, height=rng.uniform(0.4, 0.65)),
                at=(rng.uniform(-TILE*.48, TILE*.48), rng.uniform(-2.2, 2.2), 0),
                yaw=rng.uniform(0, math.tau), detail=True)


def patch_scrub(p, rng):
    """Light regrowth - knee-to-waist. Cover if you go prone, not if you stand."""
    _scatter(p, rng, F.grass_tuft, 34, 0.5, 0.9, "height")
    _scatter(p, rng, F.fern, 12, 0.8, 1.3, "height")
    _scatter(p, rng, F.bush, 5, 0.9, 1.4, "height")
    _scatter(p, rng, F.palm_sapling, 3, 1.5, 2.1, "height")
    _trees(p, rng, 1, ["broadleaf"], edge=0.75)


def patch_fern_floor(p, rng):
    """Shaded understory: fern carpet under a high canopy. Open at eye level,
    thick at the knees - you see the enemy's head, not his legs."""
    _scatter(p, rng, F.fern, 30, 1.1, 1.8, "height")
    _trees(p, rng, 3, ["broadleaf"], edge=0.45)
    _scatter(p, rng, F.grass_tuft, 16, 0.5, 0.8, "height")
    _scatter(p, rng, F.fallen_log, 1, 3.0, 4.0, "length")
    _moss(p, rng, 10)


def patch_bamboo_wall(p, rng):
    """A bamboo brake you basically cannot push through."""
    for _ in range(16):
        pl = F.bamboo_stand(rng, height=rng.uniform(5.5, 9.0))
        p.stamp(pl, at=spot(rng, r=TILE * 0.47), yaw=rng.uniform(0, math.tau))
    _scatter(p, rng, F.fern, 6, 0.9, 1.3, "height")
    _scatter(p, rng, F.grass_tuft, 14, 0.5, 0.7, "height")


def patch_open(p, rng):
    """Near-bare. Bomb crater, paddy edge, burnt ground. The eye needs rest and
    the firefight needs somewhere to happen."""
    _scatter(p, rng, F.grass_tuft, 26, 0.4, 0.75, "height")
    _scatter(p, rng, F.bush, 2, 0.9, 1.3, "height", edge=0.75)
    _trees(p, rng, 1, ["broadleaf"], edge=0.90)
    _scatter(p, rng, F.fallen_log, 2, 2.8, 4.2, "length")


def patch_grove(p, rng):
    """THE thick mix: canopy trees, bamboo clumps and bush all layered together,
    vines strung between the trees and creeping up their trunks."""
    tops = []
    _trees(p, rng, 3, ["broadleaf"], edge=0.30, record=tops, dress=0.9)
    for i in range(len(tops)):
        for j in range(i + 1, len(tops)):
            if rng.random() < 0.7:
                vine_bridge(p, tops[i], tops[j], rng, sag=rng.uniform(0.25, 0.42))
    for _ in range(5):
        p.stamp(F.bamboo_stand(rng, height=rng.uniform(5.0, 7.5)),
                at=spot(rng, r=TILE * 0.45), yaw=rng.uniform(0, math.tau))
    _scatter(p, rng, F.bush, 14, 1.3, 2.0, "height")
    _scatter(p, rng, F.fern, 12, 1.0, 1.7, "height")
    _scatter(p, rng, F.palm_sapling, 4, 1.8, 2.6, "height")
    _scatter(p, rng, F.grass_tuft, 22, 0.5, 0.8, "height")
    _moss(p, rng, 8)
    _scatter(p, rng, F.fallen_log, 1, 3.0, 4.0, "length")


def patch_tangle(p, rng):
    """Maximum thickness. Trees + bamboo + bush + hanging vines. You do not
    walk through this, you cut through it."""
    tops = []
    _trees(p, rng, 4, ["broadleaf"], edge=0.22, record=tops, dress=1.0)
    for i in range(len(tops) - 1):
        vine_bridge(p, tops[i], tops[i + 1], rng, sag=rng.uniform(0.30, 0.48))
    for _ in range(7):
        p.stamp(F.bamboo_stand(rng, height=rng.uniform(5.5, 8.0)),
                at=spot(rng, r=TILE * 0.46), yaw=rng.uniform(0, math.tau))
    _scatter(p, rng, F.bush, 22, 1.4, 2.1, "height")
    _scatter(p, rng, F.fern, 18, 1.1, 1.8, "height")
    _scatter(p, rng, F.elephant_grass, 12, 1.7, 2.3, "height")
    _scatter(p, rng, F.palm_sapling, 5, 1.8, 2.6, "height")
    _moss(p, rng, 10)
    for _ in range(6):                                   # free-hanging vines
        at = spot(rng, r=TILE * 0.42)
        p.stamp(F.hanging_vine(rng, length=rng.uniform(2.0, 3.6)),
                at=(at[0], at[1], rng.uniform(5.0, 8.0)),
                yaw=rng.uniform(0, math.tau))
    _scatter(p, rng, F.grass_tuft, 18, 0.5, 0.8, "height")
    _scatter(p, rng, F.fallen_log, 2, 3.0, 4.5, "length")


def patch_bamboo_grove(p, rng):
    """Bamboo woven through standing timber - the two structures fighting for
    the same light."""
    tops = []
    _trees(p, rng, 2, ["broadleaf"], edge=0.40, record=tops, dress=0.8)
    if len(tops) == 2:
        vine_bridge(p, tops[0], tops[1], rng, sag=rng.uniform(0.28, 0.44))
    for _ in range(11):
        p.stamp(F.bamboo_stand(rng, height=rng.uniform(5.0, 8.5)),
                at=spot(rng, r=TILE * 0.46), yaw=rng.uniform(0, math.tau))
    _scatter(p, rng, F.bush, 9, 1.2, 1.8, "height")
    _scatter(p, rng, F.fern, 10, 1.0, 1.6, "height")
    _moss(p, rng, 7)
    _scatter(p, rng, F.grass_tuft, 18, 0.5, 0.8, "height")


# name, builder, density class, role
#   density: open < light < medium < dense < wall  (level code biases by this)
PATCHES = [
    ("patch_open",        patch_open,       "open",   "near-bare: crater / paddy edge / burn"),
    ("patch_clearing",    patch_clearing,   "open",   "sightlines, firefight room"),
    ("patch_scrub",       patch_scrub,      "light",  "knee-to-waist regrowth"),
    ("patch_trail",       patch_trail,      "light",  "walkable lane, jungle crowding both sides"),
    ("patch_fern_floor",  patch_fern_floor, "light",  "fern carpet under high canopy"),
    ("patch_palm",        patch_palm,       "medium", "palm cluster"),
    ("patch_banana",      patch_banana,     "medium", "banana grove"),
    ("patch_deadfall",    patch_deadfall,   "medium", "crossed fallen logs, ferns colonising"),
    ("patch_canopy",      patch_canopy,     "medium", "3 big trees, vines strung between them"),
    ("patch_vine_hall",   patch_vine_hall,  "medium", "4-tree ring, vines criss-crossed overhead"),
    ("patch_edge",        patch_edge,       "medium", "thick on -X, open on +X: jungle boundary"),
    ("patch_grove",       patch_grove,      "dense",  "THICK MIX: trees + bamboo + bush, vined"),
    ("patch_bamboo_grove", patch_bamboo_grove, "dense", "bamboo woven through standing timber"),
    ("patch_bamboo",      patch_bamboo,     "dense",  "bamboo grove"),
    ("patch_elephant",    patch_elephant,   "dense",  "chest-high elephant grass sea"),
    ("patch_mixed",       patch_mixed,      "dense",  "everything at once"),
    ("patch_thicket",     patch_thicket,    "wall",   "no sightlines - where an ambush lives"),
    ("patch_tangle",      patch_tangle,     "wall",   "MAX THICK: trees+bamboo+bush+vines, cut through it"),
    ("patch_bamboo_wall", patch_bamboo_wall, "wall",  "bamboo brake, near-impassable"),
]


def main():
    F.clean()
    os.makedirs(OUT_DIR, exist_ok=True)
    manifest, rows = [], []
    for i, (name, fn, density, desc) in enumerate(PATCHES):
        rng = random.Random(SEED + i * 101)
        p = Patch(name)
        fn(p, rng)
        ob = p.bake(flat=False)
        tris = sum(max(0, len(f) - 2) for f in p.faces)
        zs = [v[2] for v in p.verts]
        F.export(ob, os.path.join(OUT_DIR, name + ".glb"))
        # structure-only twin for the far LOD
        pf = p.bake_far()
        far_tris = sum(max(0, len(f) - 2) for f in pf.faces)
        obf = pf.bake(flat=False)
        F.export(obf, os.path.join(OUT_DIR, name + "_far.glb"))
        manifest.append(dict(name=name, density=density, desc=desc, tile_m=TILE,
                             verts=len(p.verts), tris=tris, far_tris=far_tris,
                             height_m=round(max(zs) - min(zs), 2)))
        rows.append((name, density, len(p.verts), tris, far_tris,
                     round(max(zs), 1), desc))
        for o in list(bpy.data.objects):
            bpy.data.objects.remove(o, do_unlink=True)
    with open(os.path.join(OUT_DIR, "patches.json"), "w") as f:
        json.dump(dict(tile_m=TILE, patches=manifest), f, indent=2)
    print("\n%-18s %-7s %6s %6s %7s %6s  %s"
          % ("patch", "density", "verts", "tris", "fartris", "top_m", "role"))
    for r in rows:
        print("%-18s %-7s %6d %6d %7d %6.1f  %s" % r)
    print("\n%d patches -> %s" % (len(rows), OUT_DIR))
    print("near tris: %d (avg %d)   far tris: %d (avg %d, %.0f%% of near)" % (
        sum(r[3] for r in rows), sum(r[3] for r in rows) // len(rows),
        sum(r[4] for r in rows), sum(r[4] for r in rows) // len(rows),
        100.0 * sum(r[4] for r in rows) / max(1, sum(r[3] for r in rows))))


if __name__ == "__main__":
    main()
