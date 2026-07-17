# ADR-027 — THE PS2 WORLD: settlement-first generation, flowing water, a smooth relief gradient

- **Status:** DRAFT — pending Summoner ratification. (Sets the world-gen rules; supersedes nothing until ratified. The freeze-to-disk decision below defers ADR-017's ProvinceState build, it does not repeal it.)
- **Date:** 2026-07-16
- **Deciders:** Summoner (Caleb) by plan (`eager-growing-turtle`); War Room council (technical-director/lead-programmer + devil's-advocate) advising; Overseer arbitrating.
- **Pillars touched:** 2 (atmosphere), 3 (freedom — open AO, water is an obstacle not a gate) — hence a council.
- **Related:** ADR-001 (PSX renderer), ADR-013 (≤2km no-streaming), ADR-015 (verification law), ADR-017 (persistent province — DEFERRED, not repealed), ADR-023 (fossil law), ADR-026 (PS2 graphics budget — inherited whole).

## Context

The current AO breaks the PS2 illusion in three ways the scouts traced to real culprits, not to
re-rolling (determinism is already a pure function of seed+coords):
1. **Water reads wrong** — priority-flood pit-filling with no cap produced "ugly creeks and massive
   reservoirs"; the realism shader (fresnel + procedural normal maps + specular) fights the low-poly look.
2. **Settlements clump and tilt** — village huts ring at 8–18m and each snaps to its own uneven ground
   with no shared foundation, so a cluster on a slope reads as offset/spinning.
3. **Terrain has no intended shape** — noise runs terrain-first with no zoned relief ramp; settlements
   land wherever, then fight the ground.

This ADR sets the rules; the build obeys them phase by phase (`eager-growing-turtle` Part 2).

## Decision

### A. Generation order is SETTLEMENT-FIRST
1. **Footprint by math** — building count × the 14–25m spacing → a footprint radius (villages,
   firebases, camps each compute their own).
2. **Place the settlements** spaced across the map at appropriate relief (villages + paddies on flat
   lowland), enforcing inter-settlement separation.
3. **Shape terrain AROUND them** — flatten each footprint and let rivers/roads conform. Settlement
   placement LEADS; terrain conforms. (`LocationPlanner` already does location-first + a heightmap lift.)

### B. Terrain feel — a smooth relief gradient
- **Flat rice plains → rolling jungle hills → jungle mountains.** SMOOTH; **no extreme sharp drops.**
  Real cliffs may exist but must be rare, never dominant. Tune the noise pipeline: lower
  ridged-multifractal blend, more smoothing, a zoned relief ramp, slope clamp so terrain never walls up.
- **No deep closed basins** — the gentle gradient + smoothing prevents enclosed pits (which is also what
  used to pond into reservoirs).

### C. Water — creeks & rivers ONLY, fordable, PS2 look (the headline rule)
- **NO lakes / reservoirs / swamps. Flowing channels only.** The pooling branch is disabled
  (`hydrology_map.min_lake_depth = INF`); the flow-traced creek/river tracer is independent and stays.
- **Fordable depth only (knee-to-chest, no swimming).** Creeks ~1.0m, rivers ~2.5m; with pooling gone,
  the deepest water is a river. Water is a **fording obstacle** — it slows you, breaks your scent trail,
  leeches — never a swim. No swim/wade system exists to break.
- **PS2 rendering.** One batched, back-face-culled sheet (`WaterSystem.CombinedWater`, already correct).
  The material is a **scrolling-UV murky-water pass + flat vietnam-palette tint** — no fresnel, no
  procedural normal maps, no per-pixel specular. Killing the pooling also removes a large transparent-fill
  GPU cost (a perf win, per ADR-026 Part A rule 5).

### D. Settlements — procedural, spaced out, flat, NO prefabs
- **≥14–25m between ANY two structures**, scattered (not a tight ring), across villages AND firebases
  AND enemy camps. A 1280m AO — use the space.
- **Flatten the footprint** so buildings sit level (the offset/tilt fix): level the ground under the
  (now larger) footprint + clear vegetation, so all buildings share one foundation.
- **Rice paddies +50%** in extent (flood-fill cluster / footprint + rice-prop scatter).
- **ONE village system.** The live path is `mission_generator` → PaddyStamper anchors →
  `SitePlanner.stamp_village`. The parallel `VillageSpawner` (data-only smoke) and test-only
  `LocationPlanner` are consolidated into that one path (Fossil Law) — a later phase, beaded.

### E. Roads & paths (LATER phase)
- Connect-the-dots over known positions: main road firebase→villages (star/MST), smaller paths
  village↔village, size scaled by village size; realize each edge with the existing strip-carve +
  `vegetation_manager.clear_area()` + a road-surface mesh + `TerrainType.ROAD`. Convoys and ambushes
  anchor to roads/fords/junctions (ADR-021 intent).

### F. Scale / draw — inherit ADR-026 whole
Fog-walled short draw, hard LOD snaps, low-poly vertex-lit, ≤8 real-time lights, uncapped fighters via
activity-tiered AI. World-gen obeys the same budget.

### G. REGEN, not freeze — the scope call
- **Keep deterministic regen; DEFER the Minecraft freeze-to-disk (ADR-017 ProvinceState).** Determinism
  already delivers "same world every time"; the illusion break is settlements + chunk-pop, not re-roll.
  Freeze-to-disk's only unique payoff is persisting **player-caused** change (destroyed villages stay
  destroyed, attrition, the persistent province) — not needed yet.
- **When we DO build freeze:** the moment permanent world change matters. That is ADR-017, a later epic.

## The sacrifice (council law — no free lunch)
- **Water loses its "wow."** No mirror lakes, no reflective river — a flat murky ribbon. Traded for the
  PS2 read, a fordable-everywhere obstacle economy, and a real transparent-fill GPU saving.
- **The map loses standing water as a landmark.** Navigation and ambush geometry now lean on channels,
  ridges, paddies and settlements, not a lake you can point to.
- **Deferring freeze means player-caused world change does NOT persist yet** — blow a village and it
  returns on regen. Accepted until the persistent province is the actual need (ADR-017).
- **Settlement-first re-order and one-village consolidation are large** — this ADR ratifies the rules;
  the terrain re-order, LocationPlanner adoption, chunk-pop and roads land in later beaded phases, not at
  ratification.

## Status of this wave (2026-07-16 — what shipped with the draft, measured)
Wave 1 executed the cheap, high-illusion parts and beaded the balloons:
- **Water:** pooling disabled (`min_lake_depth = INF`) -> channels only; PS2 scrolling-murky shader in;
  `water.gdshader` + `water_coastal.gdshader` deleted (unreferenced). Proven: `probe_water_channels`
  (3 seeds -> zero lake/pond/swamp bodies, all rivers, max depth 2.50m <= fordable) + `probe_water_once`
  x2 fresh processes byte-identical (per-process determinism).
- **Settlements:** village huts scatter >=14m apart on a flattened footprint - proven
  (`probe_settlement_spacing`, 3 seeds: min_sep 14.27-15.52m, hut Y-spread 3.3-5.9m, no per-building
  tilt, deterministic). `test_site_stamp` green (villages 15-16 nodes, firebases 42-47, no water,
  none floating). Paddies +50% at the real source (`gameplay_grid` lowland fraction 0.30->0.45);
  `test_paddy_stamper` green + deterministic. The >=14m rule governs the huts + centre feature;
  concealed VC props (cache behind a hut, spider holes, punji) are deliberately close/outside.
- **Thatch: NOT fixed - beaded.** It is a Blender GLB material regression (real thatch atlas orphaned),
  not an import fix; needs a Caleb re-export. A band-aid override would tile thatch over the walls.
- **Beaded for later:** thatch re-export; settlement-first terrain re-order + gradient (p7wx);
  one-village consolidation / VillageSpawner retirement (m34l); chunk-pop (n2ij); roads;
  determinism/global-RNG cleanup (cp3s); `water_swamp.gdshader` retirement; freeze-to-disk (ADR-017).

## Alternatives considered
- **Full freeze-to-disk now (Minecraft model).** REJECTED for this pass — determinism already gives a
  stable world; freeze's payoff (persistent player-caused change) is not the current need. Deferred to ADR-017.
- **Author prefab villages.** REJECTED by Summoner — fix procedural placement instead; no prefab models.
- **Keep the realism water shader, just cap lake size.** REJECTED — the shader itself fights the PS2 look;
  the batched sheet + flat scrolling tint is both cheaper and on-aesthetic.
