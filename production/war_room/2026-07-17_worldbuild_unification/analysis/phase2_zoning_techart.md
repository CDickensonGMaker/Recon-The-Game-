# Phase 2 Zoning — Tech-Artist / Game-Designer Sight

**Seed 47225 facts (probe):** heightmap min 132.3m / max 207.3m, range **74.9m**. height_scale=280,
so normalized data lives in **[0.4725, 0.7404]** — a thin highland band.

---

## THE ROOT BUG (why it renders sparse) — the absolute gate is DEAD

`classify()` line 47: `if height < LOWLAND_MAX_H` with `LOWLAND_MAX_H = 50.0`.

On 47225 the LOWEST cell is 132.3m. **Nothing is ever below 50m.** The lowland branch NEVER fires:
zero paddies, zero grassland-from-lowland. Every walkable cell falls through to the patch-noise
gradient. So the entire map's look is decided by three noise cutoffs — and those cutoffs are tuned
"balanced," not "jungle-dominant."

Approximate single-octave SIMPLEX_SMOOTH output ≈ Normal(0, ~0.36). Current cutoffs
OPEN −0.18 / LIGHT 0.05 / HEAVY 0.28 yield roughly:

| Type | ~% (current) | Reads as |
|------|------|------|
| GRASSLAND | ~31% | open |
| LIGHT_JUNGLE (d=0.5) | ~24% | thin, empty-ish |
| MEDIUM_JUNGLE (d=0.7) | ~23% | cover |
| HEAVY_JUNGLE (d=0.95) | ~22% | thick |

**~55% of the map (grassland + light) reads open/sparse**, and LIGHT at density 0.5 with broken/sparse
tree assets looks like a field. That is the "renders sparse" complaint — not a render bug, a
*zoning* choice. The owner wants MEDIUM to be the floor, not the middle.

---

## 1. THE DENSITY MODEL — dense-default with coherent clearings

**Target histogram** (the classify() verdict, BEFORE ClearingSystem carves villages/CLEAR and BEFORE
the riparian belt over-writes banks). "Dense but traversable, varied":

| Type | Target % | Role |
|------|------|------|
| RICE_PADDY | ~5–8% | valley floors (Q2 gate) |
| GRASSLAND | ~13–15% | **coherent clearings**, meadows, paddy margins |
| LIGHT_JUNGLE | ~18–20% | **treelines** — the ring around each clearing |
| MEDIUM_JUNGLE | ~38–42% | **THE DEFAULT COVER you move through** |
| HEAVY_JUNGLE | ~18–22% | thickets / hard cover, NOT dominant |

Jungle total ~78%, but the MODE is MEDIUM, not HEAVY. Keeping HEAVY ~20% matters three ways:
Pillar-2 (uniform-heavy is monotonous), Pillar-3 (HEAVY carries the 30% LOS-block roll in
`has_line_of_sight` — a HEAVY-dominant map turns sight into dice), and perf (HEAVY drives the densest
scatter + most trunk colliders). "Dense, NOT uniform-heavy" = MEDIUM baseline.

**Concrete constant changes** (`terrain_zoning.gd`, keep it pure — only constants move):

```
PATCH_FREQUENCY : 0.012  -> 0.010     # ~100m clearings: readable openings, not salt-and-pepper
OPEN_THRESHOLD  : -0.18  -> -0.37     # GRASSLAND ~15% (was ~31%) -> clearings, not default
LIGHT_THRESHOLD :  0.05  -> -0.16     # LIGHT ~19% -> a treeline BAND ringing clearings
HEAVY_THRESHOLD :  0.28  ->  0.24     # HEAVY ~20% (roughly held); MEDIUM absorbs the rest ~40%
```

Derivation: shifting OPEN/LIGHT well negative moves the whole gradient's mass into MEDIUM; the band
between OPEN and LIGHT (−0.37→−0.16) is the LIGHT_JUNGLE treeline that a smooth field naturally
forms as a ring around every GRASSLAND basin — treelines emerge for free. Lowering frequency to
0.010 makes those basins ~100m across so they read as places you path *through*, not noise.

**These are STARTING values, not gospel.** Distribution std is an estimate. The honest move
(never-guess law): after the change, run `GameplayGrid.print_stats()` headless on 47225 and nudge the
three cutoffs until the histogram hits the table above. It's a cheap, pure, headless probe — measure,
don't ship-and-hope. Do NOT touch `_estimate_vegetation` (0.3/0.5/0.7/0.95) — it's correct; the lever
is *which type each cell gets*, and making MEDIUM (0.7) the baseline is what makes the AO read dense.

---

## 2. RELATIVE PADDY GATE — per-map ceiling, configured once, seed-derived

`classify()` is pure and can't scan the heightmap. Follow the EXACT pattern `_noise` already uses:
a static computed once per seed, cleared by `reset()` at mission teardown. Determinism (ADR-010)
holds because the heightmap is itself seed-derived — same seed → same heights → same percentile →
same ceiling, forever.

```
static var _lowland_ceiling: float = INF     # INF until configured -> lowland branch simply never fires

static func configure_lowland(min_h: float, max_h: float) -> void:
    _lowland_ceiling = min_h + 0.18 * (max_h - min_h)   # fraction-of-range: simple, robust fallback

# reset(): also set _lowland_ceiling = INF
# classify(): replace `if height < LOWLAND_MAX_H` with `if height < _lowland_ceiling`
# DELETE the const LOWLAND_MAX_H (fossil law — it's the dead 50m gate).
```

**Fraction / percentile choice.** Paddies belong on valley FLOORS — the lowest sliver, not "the
bottom half."
- **Fraction-of-range 0.18** → ceiling = 132.3 + 0.18·74.9 = **~145.8m**. Everything under ~146m is
  lowland candidate. Simple, one min/max scan.
- **15th-percentile height** (preferred) → directly pins lowland to ~15% of cells regardless of how
  bottom-heavy the terrain is. Fraction-of-range gives too much paddy on a bowl-shaped map and too
  little on a plateau; percentile is shape-robust. Compute once in the same configure call.

Either way the ceiling is fed from the heightmap min/max/percentile the caller already has, once,
during mission setup (alongside `mission_seed`), and cleared on reset. Recommend **15th percentile,
fraction-of-range 0.18 as fallback.**

**Flag — the paddy field is incoherent (`_paddy_roll`).** Inside lowland, PADDY_FRACTION=0.45 is a
per-cell `randf()`: a checkerboard of paddy/grassland cells, not terraced fields. For paddies that
read as real fields, gate on **low ground AND a coherent low-freq band** (reuse `_patch_noise`, or a
dedicated paddy field) so paddies form contiguous valley-floor blocks:

```
if height < _lowland_ceiling:
    var p := _patch_noise(world_seed).get_noise_2d(world_x, world_z)
    return RICE_PADDY if p < 0.0 else GRASSLAND    # contiguous paddy floors, grassy margins; kill _paddy_roll
```

That drops the salt-and-pepper and keeps it pure. `_paddy_roll` then becomes a fossil — delete it.

---

## 3. THE DARK-PYRAMID CRUX — the atmosphere call

The standing 2026-07-17 veg-LOD decree GATES the live-canopy switchover on a windowed look-check
*specifically because broadleaf near-solid = broken dark pyramids.* The owner now wants TreeCoverLayer
wired live. These are reconcilable — the decree gates the VISUAL swap, not the MECHANISM.

**RIGHT CALL — Option C (species-gated live wiring):** Wire TreeCoverLayer LIVE this phase for:
- **Trunk colliders — ALL cover species, broadleaf included.** This is the Pillar-3 win the owner is
  actually chasing (real cover you hide behind). A cheap `CylinderShape3D` carries no visual — a
  broken .blend still yields an honest trunk. Ship it.
- **Far impostor CARDS — all species.** The decree confirms the cards are proper impostor GLBs, a
  *better* far-field than the procedural billboards. Only the near SOLID is broken. Cards are safe.
- **Near SOLID MultiMesh — GOOD species only:** bamboo, jungle_palm, banana, and the deadfall solids
  (fallen_log/felled_tree/felled_trunk/tree_stump) render fine — render them near.
- **Broadleaf near SOLID — SUPPRESSED.** Skip the near `_multimesh` call for broadleaf_a/b/c; keep
  their trunk collider and far card. **JunglePatchLayer stays the near broadleaf VISUAL** until the
  look-check clears the fixed .blend.

Concretely in `generate_for_chunk`: for a broadleaf name, still emit `_trunk_body` and the far card,
but do NOT emit the 0→near_distance `_multimesh`. One `if name in BROADLEAF: skip near-solid` branch.

**Pillar-2 damage per option:**
- **Option C (recommended):** risk = a canopy SEAM where JunglePatch broadleaf (near) meets
  TreeCoverLayer cards (far) at ~46m, plus double-render cost in the overlap. Mild, reversible, and
  it's *exactly* what the deferred look-check exists to judge. Cost: a temporary dual broadleaf
  canopy — UNFINISHED (built-ahead), not a fossil; flag it and retire JunglePatch broadleaf at the
  look-check. Pillar-3 win banked NOW; zero dark pyramids seen.
- **Option B (switch fully, flag dark pyramids known-broken):** CATASTROPHIC Pillar-2 loss and a
  direct violation of the standing decree's gate. The whole game is "dense jungle you press against
  and move through" — the near field is the ONE thing the player stares at. Black pyramids there is
  the single most atmosphere-destroying state the renderer can produce. A "known-broken flag" doesn't
  soften a look the player cannot un-see. **Reject.**
- **Defer everything (do nothing live):** Pillar-3 cost — real cover, the point of the whole veg-LOD
  epic, slips another cycle for no atmosphere gain. The colliders are invisible; there is no reason to
  hold them hostage to a broadleaf mesh.

Option C threads the decree: mechanism + cover + cards go live, only the broadleaf near-VISUAL waits
for eyes. Nobody sees a dark pyramid; the player gets trunk cover today.
