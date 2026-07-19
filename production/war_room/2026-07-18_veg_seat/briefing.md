# WAR ROOM 2026-07-18 (evening) — patrol-world vegetation: floating cards + missing 3D jungle

## Symptoms (Summoner playtest, after the FSB fix was confirmed)
A) 2D vegetation cards floating above player eye level.
B) The 3D jungle the ai_stress_arena benchmark shows is NOT appearing in the patrol world.

## MEASURED evidence (headless, clean runs, 47225 — instrument validity checked)
- Canopy source truth: patrol world runs CanopySource.TREE_COVER; TreeCoverLayer exists
  (4725 children = exactly ONE generation pass), JunglePatchLayer NULL. Not a source fork.
- Generation truth (instance_count reads are valid): 99,770 TreeCover instances across all 25
  chunks; nearest chunks to spawn carry 2,782–4,018 instances; zoning around spawn is dense
  jungle (type4:336 type5:162 type3:169 cells). THE JUNGLE EXISTS IN DATA.
- **Instrument finding: `MultiMesh.get_instance_transform`/.buffer read back EMPTY/identity in
  this 4.7 headless build** (tools/diag_mm_readback.gd proves it) — any probe reading instance
  transforms is blind. Probes must use system-owned placement data.
- Card meshes are ground-anchored (tools/diag_veg_cards.gd: all 40 cards base y=0.00, matching
  solids) — card-pivot theory dead. (Side find: liana_a/b SOLIDS hang −4.8/−7.6..0 below origin;
  scattered at ground height they render underground while their cards stand. Art bead.)

## ROOT CAUSES (code-order facts)
**A — GroundClutter is the one vegetation system outside the terrain-rebuild path.**
`game_world._on_terrain_ready` builds it ONCE (line 176), sampling `get_height_at` at setup —
BEFORE `build_patrol_world` runs the fsb plateau flatten (R=215), clear_and_flatten discs,
village stamps, and sign craters. `modify_terrain` → `_rebuild_chunks_in_region` re-runs
VegetationManager.generate_for_chunk (TreeCover re-seats) but NOTHING re-seats clutter — no
signal exists (TerrainManager emits only terrain_ready/chunk_unloaded). Where the flatten
lowered terrain to the seat, clutter plants (alpha-scissor billboard quads + grass fans,
NEAR_END 42m so always in the player's face) hang metres in the air. Divergent-systems
signature, third instance today. Runtime craters desync it the same way, forever.

**B — TreeCoverLayer renders NOTHING beyond 80m.** near_distance 46 (solids+colliders),
view_distance 80 (cards), no third tier — and the spawn plateau is veg-cleared ~60–100m by
design, so from the wire virtually every tree in sight is a far-card or culled. The arena
benchmark scatters raw GLBs at 65m visibility PLUS a merged-patch canopy to the fog line. The
patrol world's 7/17 blessing was eyes-in-a-village (inside the solid ring); the mid/far look
was never eyeballed. 99,770 instances exist; they are range-culled into invisibility.

## Proposed decree (critique)
1. FIX A: `TerrainManager` gains `region_rebuilt(world_rect)` emitted from
   `_rebuild_chunks_in_region`; GroundClutter refactors to per-subcell buckets indexed by
   Vector2i, connects, and deterministically re-scatters ONLY affected subcells (same
   hash([subcell, layer, seed]) → ADR-010 safe). Covers build-time flattens AND runtime
   craters in one mechanism. No new placement path.
2. FIX B: view_distance 80 → 350 (fog transmittance ~10% at 350m; the retired billboard system
   used the same fog-hides-cards argument). near_distance stays 46. PERF CAVEAT: card fill on
   Intel UHD needs a windowed A/B — flagged to the Summoner; shipping an invisible jungle
   fails rule #1 harder than a measured FPS risk we can dial back with one number.
3. PROBE: system-owned placement data (each system stores its placed origins;
   probe asserts placed-Y vs terrain-now within 0.5m at 300m of spawn + canopy source ==
   TREE_COVER + per-chunk instance floor near spawn). Never reads MultiMesh transforms.
Constraints: ADR-028 improve-don't-fork; ADR-023 fossil law; ADR-010 determinism; rule #1.
