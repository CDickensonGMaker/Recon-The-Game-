# DECREE — WORLD-BUILD UNIFICATION PHASE 2 (density / render / look)

**Arbiter:** recon-overseer · **Date:** 2026-07-17 · **Council:** merge_programmer, zoning_techart,
perf_devil (analyses in `analysis/phase2_*`). **Summoner:** Caleb (approved).

## The convergence
All three architects agree: the sparse look is a ZONING/DENSITY choice (the absolute 50m paddy gate is
dead on a 132m-floor map; 3 noise cutoffs tuned "balanced" give ~55% grassland+light). And all three
agree the FULL TreeCoverLayer switchover this phase is reckless — it detonates three landmines at once:
(1) deleting JunglePatchLayer parse-breaks the arena (`ai_stress_arena.gd:408`); (2) TreeCoverLayer
near-solid renders Caleb's broken dark-pyramid `broadleaf` .blends; (3) TreeCoverLayer creates ONE
resident `StaticBody3D` per cover instance with NO bound (`tree_cover_layer.gd:82-85`) → **30k–50k
permanent physics nodes** on the resident 1280m world, walked by every bullet ray.

## SHIP THIS PHASE (headless-proven; the DEFAULT live render is unchanged, so no dark pyramids ship)

1. **Zoning rewrite — dense-jungle-default-with-clearings** (`terrain_zoning.gd`, still the ONE pure
   classifier per 6od4; flows to BOTH the AI sight grid AND the JunglePatch visuals via the existing
   render). Starting constants (tune on 47225 via `print_stats`, never-guess): `PATCH_FREQUENCY
   0.012→0.010`, `OPEN −0.18→−0.37`, `LIGHT 0.05→−0.16`, `HEAVY 0.28→0.24`. Target histogram: paddy 5–8,
   GRASSLAND 13–15 (coherent clearings), LIGHT 18–20 (treelines), MEDIUM 38–42 (default cover), HEAVY
   18–22 (NOT dominant — carries the LOS roll + collider cost). This is the "distribution floor" the
   devil requires: dense-WITH-clearings, never uniform-heavy (which would collapse all firefights to
   sub-48m and trivialize stealth via `enemy_base:1450` auto-cover).
2. **Relative paddy gate** — DELETE the dead absolute `LOWLAND_MAX_H=50`. A per-map lowland ceiling
   (`min + 0.18·(max−min)` ≈ 146m on 47225) configured ONCE from the heightmap via
   `TerrainZoning.configure(heightmap)` (called in `terrain_manager.generate_terrain` before any chunk
   load), stored static, cleared by the existing `reset()`. Determinism: heightmap is seed-derived →
   ceiling deterministic; reset per mission; set before first classify (all three perf/devil concerns
   mitigated). Contiguous paddy fields via a low-freq noise threshold (DELETE `_paddy_roll`'s per-cell
   checkerboard + `PADDY_FRACTION`). Fixes the "0 rice cells" P0 — provable via histogram.
3. **Wire TreeCoverLayer live-CAPABLE behind a `CanopySource` flag** (default `JUNGLE_PATCH` = render
   UNCHANGED, no landmine ships). Build VM `_build_scatter(coord)` deriving a `{name,xf}` per-species
   scatter from `_chunk_terrain` + a new `const TYPE_SPECIES` (terrain-type → weighted individual-species
   pool, cover + concealment; all GLBs+cards exist on disk), seeded `hash([coord, mission_seed])`
   (ADR-010). Feed `TreeCoverLayer.generate_for_chunk` when the flag is `TREE_COVER`. The Phase-2 probe
   flips the flag and asserts scatter + near-solid + far-card + `collider_count()>0` — proving the
   mechanism is genuinely wired live-capable, not a fresh built-ahead-of-wiring fossil.
4. **Remove the redundant live VM procedural-grass layer** (`_materialize_grass`, `GRASS_ACCEPT`,
   `_grass_mesh`, grass cull, `_create_procedural_grass`, `_materialize_grass` call in `_rematerialize`):
   grass is materialized twice today (VM procedural 5-blade tufts + GroundClutter fans + patches). VM's
   is the redundant, worse-looking one and up to ~50k instances/AO — a real FPS win with negligible look
   loss (GroundClutter fans remain). Fossil-law + perf. Shrink baseline. (Flagged for the windowed look.)

## DEFER to the LOOK-CHECK SWITCHOVER (beaded; gated on Caleb's eyes + his broadleaf .blend fix)
- Flip `CanopySource` default to `TREE_COVER` (make it the live canopy).
- DELETE JunglePatchLayer + the VM lone-tree path (`_materialize_vegetation`, `_build_placement_cache`,
  `_create_procedural_tree`, `use_external_models`) — fossil burial bundled with the flag flip (deleting
  JunglePatch now also parse-breaks the arena until Phase 3).
- Replace TreeCoverLayer's resident-all colliders with a **player-keyed pooled ring** (~60–150 trunks,
  ~4Hz reposition, never per-frame, never create/free) — the ONLY safe resident-world collider bound.
- The broadleaf near-solid (dark-pyramid .blend — Caleb's domain).

## VERIFY (headless)
`print_stats` histogram on 47225 = jungle-dominant WITH clearings (matches target band); paddies now
present (relative gate); determinism still byte-identical (Phase-1 probe still PASS); the flag-flipped
probe proves TreeCoverLayer live-capable (scatter+near+far+colliders, and REPORTS the resident collider
count as evidence for the pooled-ring bead); 0 SCRIPT ERROR. Guardrails green (veg_cover, arena_patrol,
ai_stress_arena, test_tree_cover_lod, test_activity_tiering).

## TRADEOFFS NAMED
Denser world → AI sight cap sits near the ~45m floor in jungle (fair per ADR-005 — jungle IS concealment;
the clearings are where long shots live). VM-grass removal thins ground detail (GroundClutter fans
remain). The near-3D-collidable-cover Pillar-3 win is REAL but its live delivery is the look-check
switchover, not this phase — this phase lands everything up to that gate.

## GUARDRAILS
GATE (decree item, exempt) · fossil law · comment discipline · scoped commits · NO push · NO .blend
(flag broadleaf) · 4.7 only · headless only (windowed confirm batched with Phase-1 clutter).
