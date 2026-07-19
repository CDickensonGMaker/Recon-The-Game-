# DECREE — patrol-world vegetation: floating clutter + range-culled jungle
2026-07-18 evening · Arbiter: recon-overseer · Council: technical-director, devils-advocate
(analyses in ./analysis/ — both read code and ran numbers; DA independently re-ran the
pre-flatten probe)

## Root causes (measured, converged)
**A — GroundClutter is the one veg system outside the terrain-rebuild path.** Built once at
`_on_terrain_ready`, height baked per plant, BEFORE `build_patrol_world` moves the ground
(fsb R=215 flatten, clear discs, village stages, sign craters — 12–18 `modify_terrain` calls
per build, all verified). Nothing re-seats it; TerrainManager has no terrain-changed signal.
Measured magnitude at 47225: pre-flatten relief 189.0–205.8 vs seat 199.69 → 22% of the
full-seat disc drops >2m; quad bases hang up to 4.4m above the player's EYE; NEAR_END 42m
puts them in his face. The low side buries instead (invisible). Fourth divergent-system
instance this week. TreeCover/patches DO re-seat (DA verified the whole chain); veg boosts
run post-flatten with current heights (clean).

**B — visibility_range is per-NODE against the transformed AABB, and TreeCover's nodes are
chunk-sized.** With `view_distance=80` a neighbor chunk's card MMI can never pass the range —
the jungle beyond the player's own chunk is culled wholesale (solids are chunk-quantized the
same way at 46). 99,770 instances exist and render almost nowhere. The current culling works
at all only by the undocumented AABB-center semantics (godot #79471). Also found: TreeCover
cards cast shadows (GroundClutter disables; TreeCover forgot — free money), and the
`_rebuild_queue` machinery in TerrainManager is a fossil nothing feeds.

## The decree
1. **FIX A:** `TerrainManager.region_rebuilt(world_rect: Rect2)` emitted from
   `modify_terrain` with the cell-accurate affected rect. GroundClutter: templates become
   members; buckets indexed by subcell; on signal, accumulate dirty subcells and flush ONCE
   via call_deferred (correctness: `clear_and_flatten` updates grid/veg AFTER modify_terrain
   — a sync handler reads stale state). Re-scatter re-runs `_accept` against the live grid.
   RNG draws become unconditional per candidate (fixed stream → untouched plants keep
   bit-identical transforms). Bucket node origins seat at terrain height (stop leaning on
   undocumented AABB-center behavior). ADR-010 holds: same seed structure, deterministic.
2. **FIX B:** TreeCover generation buckets per 64m subcell (per species/LOD/bucket MMIs,
   origin at bucket-center terrain height) — distance error ±45m instead of ±181m; solids
   `near_distance` 46→65 (arena-parity ring, trunk cap unchanged); cards `view_distance`
   80→350 (fog transmittance ≤10% at 350 in the thinnest weather — DA verified the table)
   with `visibility_range_end_margin` 8 hysteresis; cards `cast_shadow` OFF. A `--card-dist=N`
   CLI lever ships for the windowed A/B (ps2_perf_probe harness).
   **Rule-#1 gate: FIX B is NOT blessed headless. The Summoner's windowed look+perf pass
   (80 vs 350, plus the GroundClutter.visible=false attribution toggle the DA demanded)
   is the blessing gate.** If UHD tanks, the dial-back is one number (350→200 keeps 27%
   transmittance).
3. **PROBE** (`tools/diag_veg_seat`): system-owned placed-origin arrays (filled in the same
   loop that fills the MultiMesh, world space) + the DA's independent channel: (a) instrument
   validity — heightmap.sample_world vs physics ray at random points ±ε; (b) placement
   honesty — ray at each origin, |hit.y − placed_y| ≤ 0.5 within 300m of spawn; (c) census —
   per-bucket instance_count == stored array length; (d) canopy_source == TREE_COVER +
   instance floor near spawn + range consts. Header states the honest limit: proves data
   seating, never pixels. MultiMesh transform read-back is BLIND in this build
   (tools/diag_mm_readback.gd) — no probe may use it.
4. **Fossils buried in the same change:** `_rebuild_queue`/`REBUILD_BUDGET_MS` machinery
   (dead — nothing appends); the `heightmap` shader upload into a uniform no shader declares
   (game_world) — verify then delete; scaffolding probes (diag_veg_seat2/3,
   diag_preflatten_delta) deleted after their findings were recorded here.
   diag_mm_readback STAYS — it documents the instrument gotcha that blinded two probes.

## Named sacrifices (Law 2)
- FIX B fills 46–350m with flat cards — a visibility fix wearing a jungle-look costume; the
  mid-range is cardboard until a future solid tier. Priced `near=65` softens it. Caleb's eyes
  decide; headless green does NOT bless the look.
- Perf on Intel UHD is a RISK not a measurement until the windowed A/B (~28× card instances
  in range; no shadow pass — sun shadows are off; est. +3–12ms). The lever ships with the fix.
- Runtime veg-clears that move no terrain emit no signal — jungle-only clutter lingers on
  late-mission scorched ground past MAX_DEFORMS (heights unchanged, nothing floats; named).
- Re-scattered clutter around runtime craters re-rolls only affected subcells; plants there
  are new individuals (deterministic, but not the same tufts — invisible in practice).

## Beads (THE RECORD)
- P1 NEW: water system never re-seats after terrain edits (bakes ONE mesh + is_water grid
  pre-flatten; creeks in the R=215 ring float/drown; is_water lies forever) — 5th instance.
- P1 NEW: GameplayGrid stale after plateau flatten + craters (update_region runs only for
  clear discs/villages) — feeds AI sight and passability; data desync, most dangerous.
- annotate y879 (sign craters under villages): DA confirmed live, crater band 170–280
  overlaps village band 240–470, huts seat once.
- P3 NEW: liana_a/b solids hang below origin (render underground where scattered at ground
  height; their cards stand) — species-set art call.
