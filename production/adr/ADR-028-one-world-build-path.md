# ADR-028: One world-build path — the arena is a slice of it, never a parallel copy
**Date:** 2026-07-17 · **Status:** Accepted (War Room, world-build unification Phase 1) · **Summoner:** Caleb (approved, phased) · **Relates:** ADR-010 (determinism), ADR-013 (streaming/residency), ADR-023 (fossil law), ADR-025 (LOD tiers)

## Context
The AO was assembled by ~14 independent, player-window-keyed systems, each with its own RNG and its own
copy of "where things are," and the AI stress arena (`scripts/levels/ai_stress_arena.gd`) was a 15th,
fully hand-wired parallel world that referenced none of TerrainManager/VegetationManager/mission_generator.
That fragmentation is the root cause of the recurring world bugs — pop-in (streaming unload/reload;
clutter re-scatter every 22m), non-determinism (placement RNG that never folded `mission_seed`; a static
noise field leaking across missions), and a divergence the arena HID ("works in the arena" measured the
wrong thing, because the arena was not the game). This is the exact synchronous-world-streaming / parallel-
world bug class that sank the Catacombs project.

## Decision
**The AO is built by ONE resident, deterministic pass from `mission_seed`, behind the loading screen:
terrain → TerrainZoning → vegetation (with LOD) → paddies → sites → clutter → tiered enemies. The arena
is a thin wrapper that instantiates that same build; it is a SLICE of the world, never a parallel copy.**

Binding consequences:
- **Determinism (ADR-010):** every world-placement RNG folds `mission_seed` via the pure
  `hash([cell_or_chunk, mission_seed])` pattern — no global `seed()`, no reliance on stream/iteration
  order. Same seed → byte-identical world. No static world state survives mission teardown.
- **Residency (ADR-013):** on maps ≤ 2km the whole grid is built once and stays resident; chunk count is
  invariant after `terrain_ready`. Clutter is baked resident with `visibility_range` LOD, not re-scattered
  per frame.
- **One placement path (ADR-023):** a superseded placer/planner/scatterer is DELETED, not left standing.
  Enforced by the fossil probe plus a structural probe (beaded) that fails CI if (1) more than one live
  world-content placement path exists, (2) the arena does not instantiate the shared WorldBuilder, or
  (3) any world-placement RNG does not fold `mission_seed`. Assertion (2) lands with the Phase-3 arena
  wrapper.
- **Supersedes the stabilize-freeze** for the world-build systems (terrain/veg/clutter/zoning) only: this
  unification IS the stabilization, so it is not blocked by the "no new systems" freeze for those systems.

## Protected foundation (Summoner's law, 2026-07-17)
Caleb's verdict on the unified world, after seeing it populated with 3D veg: *"this full game world
needs to be improved but never CHANGED."* The unified game world — the resident deterministic build
(WorldBuilder pass), the populated AO (`MissionGenerator`), the TREE_COVER individual-3D-species veg,
the one classifier — is now the **PROTECTED FOUNDATION**. All future work **IMPROVES/refines it in
place**: tune density, fix materials, add life, wire the pooled-ring colliders, swap in Caleb's authored
assets. No future work may **rebuild, replace, re-fragment, or add a parallel world-build/veg/placement
system** — that is the exact fracture (14 divergent systems + a hand-wired arena) this ADR exists to
end. A "better idea" that means a second world path is **out of bounds**; improve the one path instead.
This is not aspiration — it is what the structural probe (beaded) mechanically enforces: >1 live
world-placement path, or an arena not on the shared build, or unseeded placement RNG, FAILS CI.

## Tradeoff (named)
Folding `mission_seed` into placement RNG means **existing seeds now generate different-looking worlds.**
Accepted: there are no saved maps — saves regenerate the world from the seed (ADR-007/010), so the cost is
cosmetic-only, and it closes a standing ADR-010 compliance gap. Fully-resident ≤2km worlds keep memory and
draw ceiling whole-map (no reclaim when the player huddles in a corner) — already accepted under ADR-013.

## Execution (phased; Summoner keeps each phase in the loop)
1. **Phase 1 (this ADR's shipping slice):** residency guard; resident+deterministic clutter; seed the veg/
   clutter/zoning RNG; delete the VegManager fossil pair. Structure + determinism + residency only.
2. **Phase 2:** wire TreeCoverLayer live + fold into one veg system; dense-jungle-with-clearings zoning;
   relative-elevation paddy gate (fixes the absolute-50m "0 rice cells" P0 — see pre-check below).
3. **Phase 3:** arena becomes a thin wrapper over the shared build; delete its hand-wired stubs.
4. **Phase 4:** confirm activity-tiered AI across the full populated world; soften steepness.

## Evidence (Phase-1 pre-check, seed 47225)
Map floor 132.3m (min 132.3 / max 207.3 / relief 75m) — entirely above the classifier's absolute
`LOWLAND_MAX_H=50m` gate, so 0% paddy / 0% clear; the spawn chunk zones ~75% jungle (GRASSLAND 25.5 /
LIGHT 29.8 / MEDIUM 29.9 / HEAVY 14.8). The sparse look is therefore a render/density problem (Phase 2),
not a classification problem, and "0 rice cells" is the absolute-height gate (Phase 2 relative-elevation
fix). Probe: `tests/probe_spawn_zoning.tscn`.

## Related
Pillars served: 2 (Atmosphere — the world stops popping and diverging), 3 (Freedom — the same dense world
at scale, no rails), and via the removed hitch, 1 (gunplay on a stable frame). Beads: world-build epic +
Phase-1 task + Phase-2/3/4 carry-overs + structural-probe + out-of-scope determinism debt.
