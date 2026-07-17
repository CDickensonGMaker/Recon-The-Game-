# BRIEFING — World-Build Unification (Phase 1 of 4)

**Convened:** 2026-07-17 · **Arbiter:** recon-overseer · **Summoner:** Caleb (APPROVED the refactor)

## The query
Caleb approved unifying the ~14 divergent LIVE world-build systems (+ the hand-wired arena as a 15th
parallel world) into ONE deterministic resident WorldBuilder shared by arena + game. This is executed
PHASED. **Phase 1 only this run:** structure + determinism + residency. NOT density/look (Phase 2),
NOT arena wrapper (Phase 3), NOT AI tiering/steepness (Phase 4).

## Root-cause diagnosis (from the approved plan)
The world is assembled by many parallel systems each with its own RNG + copy of "where things are,"
keyed to the player window. Symptoms: pop-in (streaming unload/reload, clutter re-scatter every 22m),
non-determinism (placement RNG that doesn't fold mission_seed; a static noise field that leaks across
missions), and an arena that is a parallel hand-wired world hiding the game's divergence.

## Phase 1 scope (what the Summoner ordered)
1. **ADR-013 residency guard** — skip `_stream_chunks_around_camera` when `map_size <= 2000`
   (terrain_manager.gd:59-66). After `terrain_ready`, chunk count is invariant. Amend the stale
   "3km/streams" header (Truth law).
2. **Kill GroundClutter re-scatter** — bake clutter ONCE, resident; remove the 22m/_process rebuild
   (ground_clutter.gd:108-155); keep only `visibility_range` LOD.
3. **Seed everything from mission_seed** — JunglePatchLayer (jungle_patch_layer.gd:198,
   `hash(chunk)^0x5EED` — no seed), GroundClutter (:124, `hash(cell)` — no seed); register
   `TerrainZoning._noise` in `MissionScope.reset()` (fix the static cross-mission leak).
4. **Fossil-law:** VegManager `_generate_chunk_vegetation`/`_generate_chunk_grass` are confirmed dead
   duplicates (grandfathered in fossil_baseline.json). A non-seeded dead path is a determinism liability.

## STEP 0 — the architecture to ratify (ADR)
"ONE world-build path; the arena is a slice of it, never a parallel copy." Amend ADR-023 or new ADR.
Record that this supersedes the stabilize-freeze for the world-build systems and aligns ADR-010/013/027.
Name the determinism tradeoff (existing seeds will generate different-looking worlds — fine, no saved maps).

## The questions for the council
- **TD lens:** Is the residency guard (`map_size > 2000` gate on the stream call) correct + sufficient
  to make chunk count invariant, without breaking explosion-rebuild (`_rebuild_chunks_in_region`) or
  `clear_area`? Any determinism hole in Phase 1's seed folding? Is registering `TerrainZoning._noise`
  reset in `MissionScope.reset()` the right leak fix?
- **Perf/programmer lens:** What is the safest perf-neutral way to make GroundClutter resident (no
  `_process` re-scatter) while keeping near-only LOD? The moving 45m ring (~408 instances) vs a resident
  scatter — how do we not blow the frame (FPS is the top systemic risk) or the node count?
- **Devil's advocate:** What breaks? Arena (still parallel until Phase 3) — does seeding JunglePatch/
  clutter shift it? MissionScope re-run determinism across missions 1..N? The felled-tree/clear_area
  interaction? What is sacrificed?

## Guardrails
GATE + fossil law + comment discipline · scoped commits · NO push · NO .blend edits · NO terrain MESH
asset edits · 4.7 only · headless only (flag before any windowed/MCP run).
