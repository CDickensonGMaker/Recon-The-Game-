# DECREE — ONE WORLD-BUILD PATH (Phase 1: resident + deterministic)

**Arbiter:** recon-overseer · **Date:** 2026-07-17 · **Summoner:** Caleb (APPROVED the refactor, phased).
**Council:** technical_director, perf_programmer, devils_advocate (analyses in `analysis/`).
**Supersedes-freeze:** this refactor IS the stabilization of the divergent world-build systems, so it
supersedes the "no new systems" stabilize-freeze **for the world-build systems only** (terrain/veg/
clutter/zoning). Aligns ADR-010 (determinism), ADR-013 (residency), ADR-027 (world design).

## THE LAW RATIFIED (→ ADR-028)
**One world-build path. The arena is a slice of it, never a parallel copy.** The AO is built by ONE
resident deterministic pass from `mission_seed`, behind the loading screen. Enforced going forward by the
fossil law (ADR-023) plus a structural probe (beaded; its arena-assertion lands with Phase 3).

**Determinism tradeoff, named:** folding `mission_seed` into the veg/clutter placement RNG means existing
seeds now generate different-looking worlds. Accepted — there are no saved maps (saves regenerate the
world from the seed, ADR-007/010); the cost is cosmetic-only, and it CLOSES an ADR-010 compliance gap.

## PRE-CHECK (seed 47225) — corrects the plan's premise
The map floor is **132.3m** (min 132.3 / max 207.3 / relief 75m), entirely **above** the classifier's
absolute `LOWLAND_MAX_H=50m` gate → **0% paddy, 0% clear**; the spawn chunk zones as **75% jungle**
(GRASSLAND 25.5 / LIGHT 29.8 / MEDIUM 29.9 / HEAVY 14.8). So seed 47225 is NOT "open lowland" — the
sparse look is a **render/density** problem (Phase 2), and the "0 rice cells" P0 is the **absolute-height
gate** (Phase 2: relative-elevation paddy). Phase-1 leaves the look untouched; this is Phase-2 intel.

## THE DECREE — Phase 1 build (structure + determinism + residency ONLY)

1. **ADR-013 residency guard.** Gate the stream call only: `if camera and map_size > 2000.0:` in
   `terrain_manager._process` (`:66`). `_process_rebuild_queue()` stays UNGATED so explosion/clear
   rebuilds still repaint (`_rebuild_chunk_immediate` erases+re-adds the same coord → chunk-count delta
   zero, invariant preserved). Do NOT touch `unload_distance` (skipping the call makes it dead input;
   bumping it muddies which mechanism is load-bearing). Amend the stale 3km header (Truth law).

2. **Clutter → resident (a rewrite, done properly).** GroundClutter's `_process` re-scatter is the
   pop-in source (re-randomizes on movement). Replace the moving 45m ring with a **resident, per-chunk
   bucketed scatter** built ONCE in `setup()` (called from `_on_terrain_ready`, where `gameplay_grid` and
   the heightmap are ready), seeded from `mission_seed`, with per-bucket `visibility_range` for near-only
   LOD. Numbers (perf architect): **subcell 32m, visibility_range_end 42m + 8m fade, near-only.** Drawn
   count stays ≈ the old ring (±30%); resident node count is JunglePatch-scale (which already ships
   ~thousands of bucket-nodes at 25–40 FPS, so node count is NOT the blocker). Delete `_process`,
   `_last_center`, `_poll`, `RESCATTER_DIST` in the same change (else 3 new fossils). Look near the
   player is preserved; clutter simply stops re-randomizing and never pops.
   - **HONEST CAVEAT (flag to Summoner):** FPS delta of resident clutter cannot be measured headless
     (GPU-ms reads 0 headless). This rides the plan's required one-windowed-confirm-per-phase.

3. **Seed everything.** Fold `mission_seed` via the proven `hash([chunk_coord, mission_seed])` pattern
   (already live in `_build_placement_cache`/`gameplay_grid`/`terrain_zoning`):
   - JunglePatchLayer `:198` `hash(chunk)^0x5EED` → `hash([chunk_coord, mission_seed])`. Requires adding
     a `mission_seed` field to JunglePatchLayer AND wiring `_patch_layer.mission_seed = mission_seed` in
     VegetationManager (`:105-107`) — else the fold is a silent no-op (Devil's catch). Fold into the
     dedicated `rng.seed`, never global `seed()`.
   - GroundClutter `:124` `hash(cell)` → fold `world.mission_seed`.
   - `TerrainZoning`: add a `static func reset()` nulling `_noise`/`_noise_seed`; call it from
     `MissionScope.reset()`. (Self-heals via the seed-guard in practice — this is ADR-010 law-hygiene,
     stated honestly, not a live bug.)

4. **Fossil law (ADR-023).** Delete VegManager `_generate_chunk_vegetation` + `_generate_chunk_grass`
   (confirmed dead duplicates of the `_materialize_*` cache path; an un-seeded dead path is a determinism
   liability). Shrink `fossil_baseline.json` (remove the `_generate_chunk_vegetation` entry).

## VERIFY (headless, ratcheting)
Same seed twice → byte-identical world (placement transforms hash-equal); chunk count invariant after
`terrain_ready` (== 25) across a camera traverse; no `_process` re-scatter exists; boot 0 SCRIPT ERROR.
FPS delta of clutter → flagged for windowed confirm (unmeasurable headless).

## OUT-OF-SCOPE DEBT (beaded, NOT fixed this phase)
- `terrain_manager.gd:172` `randi()` fallback terrain (only when TerrainEngine autoload absent — not the
  live path) and `weather_director` unseeded RNG — ADR-010 debt, Phase-2+.
- Full structural-registry probe (>1 live placement path fails CI; arena-instantiates-WorldBuilder
  assertion) — needs the Phase-3 arena wrapper to assert #2. Beaded.
- Fold clutter into the chunk-lifecycled veg pass (perf's preferred end-state) — Phase 2, once the
  WorldBuilder owns build ordering.

## GUARDRAILS
GATE (stabilization, exempt) · fossil law · comment discipline · scoped commits · NO push · NO .blend
edits · NO terrain MESH edits · 4.7 only · headless only (windowed confirm flagged, deferred).
