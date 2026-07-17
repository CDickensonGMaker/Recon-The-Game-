# War Room — WORLD-GEN WAVE 1 (2026-07-16)

## Query
Execute the PS2 World Design plan's Wave 1: (1) a DRAFT ADR capturing the PS2 world-design rules,
(2) WATER FIX (kill lakes/reservoirs → creeks & rivers only, PS2 scrolling water shader, retire fossil
shaders), (3) SETTLEMENT fixes (≥14–25m building spacing, flatten footprint, fix hut thatch textures,
+50% rice paddies). Pillar 2 (Atmosphere) + world-defining → council required (CLAUDE.md law).

## Constraints (canon)
- Fossil Law (ADR-023): delete replaced systems; a NEW fossil fails the build. water_swamp.gdshader is
  LIVE (jungle_patch_layer.gd:14) — NOT a fossil. water.gdshader + water_coastal.gdshader unreferenced.
- Comment Discipline: no history/tombstone comments.
- ADR-015: nothing closes without a probe/measurement.
- ADR-026: PS2 graphics budget inherited.
- Scope guard: do water + spacing + thatch + paddies SOLID; BEAD the balloons (settlement-first terrain
  re-order, LocationPlanner adoption / village-system unification, chunk-pop, roads, full terrain gradient).

## As-built truth (traced from code, not the plan)
- Live world boot = game_world.gd; it calls VillageSpawner.sample_world = DATA-only smoke PRINT, stamps
  NO structures. Live structure placement = mission_generator.gd → PaddyStamper anchors → SitePlanner.stamp_village.
- THREE parallel village-position systems: PaddyStamper anchors (live), VillageSpawner (smoke data,
  unfinished), LocationPlanner (test-only). Unifying = balloon → bead.
- Water: hydrology_map.min_lake_depth already 6.0 (plan said 0.4). River/creek cells never write _surface_h
  so per-cell water_map depth ~0; real depth is body.depth (creek 1.0 / river 2.5). generate_swamps=false,
  ocean_edges=0 already.
- stamp_village rings huts at VILLAGE_RING_RADIUS 8–18m (tight clump) and NEVER flattens.
- Probes that must stay green: test_site_stamp (village ≥7 nodes, firebase ≥20, no water, <4m float,
  sites ≥200m apart), probe_smoke_all, test_paddy_stamper (HARD_FLOOR_VILLAGES=8, determinism),
  test_world_alive, test_fossils, test_flat_damage.
