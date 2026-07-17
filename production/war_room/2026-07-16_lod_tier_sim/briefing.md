# War Room — LOD-tier world simulation (ADR-025 / bead xdys)

## Query
Implement the built-ahead LOD/world-sim stubs (ADR-025) so they stop being fossils AND land a CPU-perf
win. Phase 0 fossil-law unification, Phase 1 node culling T0/T1/T2, Phase 2 materialize loop T3<->node,
Phase 3 statistical resolution. Design is ADR-025; every prior wave found doc errors — MEASURE.

## SUMMONING FACTS (verified from code this session, not the plan)
- `EnemyBase._set_tier(tier: AlertTier, witnessed)` ALREADY EXISTS (enemy_base.gd:816) and means "set
  ALERT tier" (RELAXED/SUSPICIOUS/ALERT/COMBAT). The arena calls `e._set_tier(AlertTier.COMBAT, false)`.
  => The ADR's proposed `set_tier(t)` for LOD is a NAMING COLLISION. Rename the LOD authority.
- `set_lod_live()`/`set_lod_abstract()` exist on BOTH EnemyBase (enemy_base.gd:115) and Civilian
  (civilian.gd:360). Because the frequency-fossil probe counts the identifier globally, TWO identical
  decls = freq 2 => NOT flagged as fossils. They are UNFINISHED (built ahead), zero-caller.
- Civilian has its OWN wired LOD: `lod_tier` + `_update_lod` (civilian.gd:45-55, 329) with 3 tiers
  (FULL/NEAR/FAR, radii 80/300, hysteresis 5m, recompute 2s). LOD_FAR skips physics via early return.
- Enemy `_update_think_lod` (enemy_base.gd:39) is a think-rate distance LOD: >150m=0.6s, >80m=0.3s,
  else 0.15s, recomputed every 2s. `MAX_THINK_TIME` (enemy_base.gd:220) is a dead const (in baseline).
- WorldSim already gets entities REGISTERED (mission_generator.gd:655 `WorldSim.register`) and
  `clear_if_needed` is live. But `update_player`/`materialize_near`/`dematerialize_far` are zero-caller.
- SimClock.advance() IS LIVE (sim_clock.gd:36 `_process` -> advance). ADR-025 Evidence is WRONG that it
  is zero-caller. hour_advanced/day_advanced/sim_event ARE connected (8 systems). Only
  `time_period_changed` + `clear_schedules` are dead SimClock symbols.
- offer_generated (dynamic_mission_factory.gd:15) is emitted but NOTHING connects (r4bk fossil).
  `_on_convoy_ambushed` is connected via convoy.ambushed, but the offer_generated signal itself is dead.
- FOSSIL PROBE GROUND TRUTH THIS SESSION: `fossils now: 95, baseline: 79, 18 NEW (BUILD RED), 2 buried`.
  The 18 new include: update_player, materialize_near, dematerialize_far, time_period_changed,
  waypoint_reached, route_finished, clear_schedules, offer_generated (LOD-thread) + air_traffic
  get_in_flight, ambient_war get_active, ambush_planner consts, squad_leader funcs, weapon_data
  get_bore_dir, paddy_stamper consts, convoy.resume (OTHER threads — out of scope).

## THE ARENA PREMISE — CONTEST THIS
- `test_arena_perf.gd` spawns NO player (`spawn_player=false`). Distance-to-player LOD has no reference.
- Arena is 200m. In hot_start, US at ~(-40,40), VC at ~(35,-35): all units within ~110m of each other,
  ~50m of centre. Even WITH a player at firebase overlook (-35,35), the far fight is <150m.
- => Distance-to-player node-culling likely saves ~0 in the arena perf probe (all T0), and may be a net
  LOSS from tick overhead. The real win is in the REAL GAME: player present, units spread across the
  <=2km AO, most enemies far. MEASURE before claiming the arena win.

## CONSTRAINTS (law)
Pillars 2/3/4; Ambience Law (Phase 3 never touches player/assets — surfaces as an offer); Fossil Law
(delete superseded in same change; never regen baseline); Comment Discipline; strict typed GDScript;
ADR-015 (each phase ships a probe); ADR-013 (<=2km never stream); ADR-010 (one seed). Perf floor: native
~27 FPS — the LOD tick must save more than it spends. Arena is on Mobile renderer (do not touch renderer).

## KEEP GREEN
test_arena_patrol, test_veg_cover, test_low_posture, test_mirror_match, test_flat_damage, perf_probe.
test_fossils must DROP (proof of real wiring).
