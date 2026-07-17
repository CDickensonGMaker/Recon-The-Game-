# War Room Decree — WORLD-GEN WAVE 1 (2026-07-16)

Arbiter: Overseer. Council: technical-director/lead-programmer + devil's-advocate (read code, not plan).
Both returned independently; the codebase beat the plan doc twice (thatch, paddies).

## What the council changed about the plan (trust code over plan)
1. **THATCH is NOT an import bug.** A Jul-9 Blender re-export regressed each hut's material to a flat
   beige-plaster swatch (`beige_wall_001.005`); the real thatch texture (`thatched_hut_tmpcz_ih86y.jpg`,
   727KB) is orphaned beside the GLB. Import-param fiddling re-links the same wrong image. The `_tmp`
   files are load-bearing (external URI) — do NOT delete. Fix = Blender re-export (Caleb's chair):
   reassign thatch, split roof/wall into ≥2 surfaces, embed textures. → BEADED, not band-aided (a
   material override would tile thatch over the walls — a lie, and a future fossil).
2. **PADDIES: the plan named the wrong file.** `paddy_stamper.gd` is READ-ONLY on RICE_PADDY cells;
   growing its footprint only scatters props on dry land. Paddy EXTENT is set upstream in
   `gameplay_grid._determine_terrain_type` (lowland paddy fraction). → grew it there (0.30→0.45 = +50%);
   rice props auto-scale with cluster size. Re-ran the paddy floor probe.
3. **VILLAGE huts have NO water check today** — they only pass because they sit inside `find_site`'s
   dry 26m disc. A larger scatter footprint needs per-hut water rejection (added), or structures land in
   water (`test_site_stamp` would go RED).
4. **FLATTEN is cheap** — `clear_and_flatten` already routes through `TerrainManager.modify_terrain`
   (levels the heightmap + rebuilds chunks). `stamp_village` just never called it. One-line add.

## Decree (executed this wave)
- **ADR-027 drafted** (PS2 world design rules), pending Caleb's ratification.
- **Water:** pooling disabled (`min_lake_depth = INF`) → creeks/rivers only; PS2 scrolling-murky
  palette shader replaces the realism shader; 2 fossil shaders deleted. `water_swamp.gdshader` KEPT
  (live in `jungle_patch_layer.gd`) — its retirement beaded with the jungle/paddy epic.
- **Settlements:** villages scatter huts ≥14m apart over a flattened footprint (guaranteed count,
  per-hut water rejection, deterministic); paddies +50%. Firebase left as an authored tight compound
  (a firebase IS compact; ≥14m between sandbags is incoherent) — interior-spacing pass beaded if wanted.

## The sacrifice (named)
- Water loses reflection/glint; the map loses standing-water landmarks (see ADR-027).
- `clear_and_flatten` on villages paints an exposed-dirt disc + costs 8–10 synchronous chunk rebuilds at
  gen time, and is a 70% lerp (not a perfect plane).
- Deferred (beaded, not done): thatch re-export, settlement-first terrain re-order + relief gradient
  (p7wx), one-village unification (m34l), chunk-pop (n2ij), roads, determinism/global-RNG cleanup (cp3s),
  water_swamp retirement, freeze-to-disk (ADR-017).

## Verification (ADR-015)
- `probe_water_channels`: zero lake/pond/swamp bodies, all rivers, max depth 2.50m ≤ fordable.
- `probe_water_once` ×2 (separate processes): byte-identical → per-process determinism proven.
- `test_site_stamp`: villages 13–16 nodes, firebases 45–46, no water, none floating — GREEN.
- `probe_settlement_spacing` / `test_paddy_stamper`: see run log.
- One MCP screenshot each for water + a spaced village.
