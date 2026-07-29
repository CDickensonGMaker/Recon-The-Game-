# Synthesis — DEMO GAME (Arbiter's decree, 2026-07-29)

Council: tech_director, game_designer, devils_advocate (analysis/) + the parallel-systems audit
(reported to the Summoner; key findings recorded here per Pointer Law).

## The 14-parallel-systems investigation — CLOSED with findings

The 07-17 report is STALE. Consolidation genuinely happened: ONE canonical world-build path
(GameFlow → game_world.tscn(mission_seed) → plan_patrol_world → build_patrol_world), 20 subsystems
all mission-seed-derived or pure, TerrainZoning + GameplayGrid as single truth, guarded by
tests/test_placement_paths.gd. Remaining honest divergence:
- 6 off-seed positioners INSIDE the live path: AmbientWar (ambient_war.gd:11 unseeded),
  AirTraffic (air_traffic.gd:64 unseeded), FieldDirector hunters (field_director.gd:148-156 global
  RNG) + hunt vectors (:564 wall-clock), SiegeDirector + GarrisonDefender (position-hash streams).
- 7 bench worlds; ai_stress_arena (2,313 lines) is a full hand-wired world — SANCTIONED by decree
  (ADR-028 Amendment A cut Phase 3; arena stays a sterile bench, excluded from the probe).
- **D1 — LIVE BUG, main game, fix immediately:** paddy_stamper.gd:11-12 hardcodes CELL_SIZE_M=12.0
  but the real grid is 5.0m (1280m/256) → every paddy centroid & rice prop at 2.4x true coords,
  indices past ~106 land OFF-MAP, and these bad centroids steer village-anchor selection
  (mission_generator.gd:501-554). D2: its comment cites a test that does not exist (Pointer Law).
  D3: SitePlanner.stamp_lz has no shipping caller (fossil candidate — triage, don't blind-delete).

## DEMO GAME decree

- **512×512 slice** (RULED: 400 infeasible — 256m terrain chunks, firebase footprint ~299×222m at
  site_planner.gd:650; 512 = 2×2 chunks). The Summoner asked 200→400; measurements force 512.
- **Zero copied wiring (DA condition, binding):** compose the real parts — instance
  game_world.tscn with map_size=512 + fixed mission_seed, FieldDirector.setup, then
  MissionGenerator plan+build. NO direct SitePlanner calls from the demo
  (test_placement_paths.gd:17-20 fails CI by design).
- **Conflict resolved (TD "call stamps directly" vs probe law):** the demo plan is authored by a
  new `plan_demo_world()` INSIDE mission_generator.gd (a sanctioned caller) — handcrafted site
  list (firebase center-S, village NW, temple ruin NE), skipping the patrol planner whose
  280-540m bands collapse under ~900m. Stamping stays `build_patrol_world` unchanged.
- **Switchboard:** const block at the top of demo_game.gd, SKIP-ONLY (can exclude, never fork),
  every exclusion PRINTED at boot (DA condition). Campaign persistence sandboxed:
  CampaignState save_path → campaign_demo.cfg (mechanism at campaign_state.gd:7-13).
- **Arc (game_designer):** dusk arrival 0-2 min → exploration window 2-10 (rewarded, never
  required; fire-support grant) → probing attack 10-12 → forced d50 siege 12-18 (siege
  self-curtains at 480s, siege_director.gd:38-40) → dawn break + end card 18-20. End on
  exhausted "I held" — no fanfare, no relief column.
- **Honesty:** only LAYOUT + ARC are deterministic (6 off-seed positioners + 367 unseeded rand
  calls elsewhere). Claim no more.
- **Excluded from demo:** save/load, debrief/XP (sacrifice named: squad long-arc unsold —
  mitigated by named-roster end card), map pencil, fixed-wing.
- **Ship gates:** headless boot probe for the demo scene + a measured PERF_LEDGER row of the
  forced siege on the slice (the demo climaxes in the engine's known worst case) + Summoner
  playtest. First build this session: scene + world + arc stub; pacing tuned by his eyes.
