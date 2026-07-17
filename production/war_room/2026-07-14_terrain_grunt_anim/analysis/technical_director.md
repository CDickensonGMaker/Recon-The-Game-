# Technical-Director Analysis — Terrain Relief

**Architect:** technical-director  
**Date:** 2026-07-14  
**Query:** Terrain highs/lows are too strong and "destroying the map" every generation. Owner is open to replacing the terrain engine.

---

## 1. Exact mechanism in `terrain_engine.gd` that causes extreme relief regardless of preset

The relief is not a single bug; it is a **cascade of amplitude amplifiers** followed by a **hard normalization** that guarantees every amplifier reaches its configured ceiling. Even when `TerrainManager` chooses a gentle preset, the engine still runs the full stack and then stretches the result to fill `[0, height_scale]`.

### The normalization trap (`terrain_engine.gd:621-636`)

```gdscript
func _normalize_heightmap() -> void:
    var min_h: float = 1.0
    var max_h: float = 0.0
    for h in heightmap_data:
        min_h = min(min_h, h)
        max_h = max(max_h, h)
    var range_h: float = max_h - min_h
    ...
    for i in range(heightmap_data.size()):
        heightmap_data[i] = (heightmap_data[i] - min_h) / range_h
```

This remaps the output to **0–1 always**, based on whatever the processing stack produced. It means:

- The final heightmap **always occupies 100% of `height_scale`**, whatever the preset intended.
- A "gentle" preset cannot produce a gentle map unless its raw noise stack is already gentle; the normalizer will stretch even a tiny bump to the full per-preset height.

### The amplitude amplifiers applied before normalization

1. **Domain warping (`terrain_engine.gd:264-290`)**  
   `sample_x += warp_x`, `sample_y += warp_y` where `warp_x/y = noise(x,y) * warp_strength`.  
   This folds and shears the noise field, creating sudden ridges and basins. `warp_strength` is 20–50 cells (40–100 m) depending on preset, which is large relative to a 60 m coastal scale.

2. **Ridged multifractal (`terrain_engine.gd:292-325`)**  
   The ridge transform is intentionally extreme:
   ```gdscript
   ridge = abs(ridge)
   ridge = 1.0 - ridge
   ridge = pow(ridge, ridge_sharpness)
   ```
   This converts smooth noise into sharp, near-vertical spines. Then it blends in:
   ```gdscript
   heightmap_data[idx] = base_height + ridge * blend * 0.3
   ```
   `ridge_blend` is 0.3–0.6 and `ridge_sharpness` is 2.0–4.0. Even with `blend * 0.3`, the operation can add a normalized 0.3 spike on top of the base height. After normalization, that spike becomes part of the full height range.

3. **Cliff enhancement / terracing (`terrain_engine.gd:340-376`)**  
   Computes gradient with central differences, then quantizes heights into terraces:
   ```gdscript
   var levels: float = 8.0 + sharpness * 2.0
   var level_h: float = round(h * levels) / levels
   heightmap_data[idx] = lerp(h, level_h, blend * 0.4)
   ```
   This deliberately creates near-vertical steps wherever the gradient exceeds `cliff_threshold * 0.5`. It is enabled for every preset except the one that disables it (`COASTAL_HILLS` sets `ridge_enabled = false`, but `cliff_enabled` remains true via the default params).

4. **Detail noise (`terrain_engine.gd:327-338`)**  
   Adds ±4% detail (`detail_amplitude = 0.08`, centered around 0). On a 60 m coastal scale that is ±2.4 m of surface roughness on ground that should be nearly flat for paddies.

### Why the preset does not protect you

`set_preset()` only changes parameters. It does **not** change the pipeline or the final normalizer. Every preset still runs warping → ridges → detail → cliffs → smooth → normalize. The normalizer at the end is a ratchet: it takes whatever the stack produced and stretches it to fill `[0, height_scale]`. Therefore a preset that intends 60 m of relief still produces 60 m of **locally cliffed, ridged, warped** relief, which reads as broken valleys/peaks.

### Secondary issue: shader scale mismatch

`terrain_chunk.gd:158` hardcodes `height_scale` shader parameter to `280.0`, while the actual mesh is built with the per-preset scale passed at `terrain_manager.gd:259`. This can desync parallax, texture steepness, or any shader-based height effect for low-relief presets.

---

## 2. Does `terrain_manager.gd` already try to solve this? Is it working?

Yes, it tries. No, it is not enough.

### What is already implemented

- **`_derive_ao_preset()` (`terrain_manager.gd:371-382`)** derives a preset deterministically from the operation seed using the 40/60 inhabited/empty split.
- **`_preset_height_scale()` (`terrain_manager.gd:385-407`)** maps each preset to a max height in meters:
  - COASTAL_HILLS: 60 m
  - RIVER_VALLEY: 80 m
  - ROLLING_HILLS: 130 m
  - STEEP_MOUNTAINS: 460 m
  - PLATEAU: 220 m
- **`generate_terrain()` (`terrain_manager.gd:123-126`)** calls `set_preset(preset)` and then `terrain_generator.height_scale = preset_scale` before generation.

### Why it still fails

1. **Normalization in the engine overrides intent.** Setting `height_scale = 60` only changes the ceiling the normalizer stretches to; it does not change the fact that the whole 60 m is used and heavily processed.

2. **The preset parameters are still too aggressive for lowland maps.**
   - `RIVER_VALLEY` and `ROLLING_HILLS` keep `ridge_enabled = true` and `cliff_enabled = true`. On an 80–130 m scale, a `cliff_sharpness` of 2.0–2.5 creates clearly artificial cliffs.
   - `COASTAL_HILLS` disables ridges but still leaves cliffs on, and `warp_strength = 20.0` at 60 m scale is 1/3 of the map's total relief budget.

3. **THE_PLAN.md says the AO archetype is "AWAITING RATIFICATION" and "nothing below has been built,"** yet the code in `terrain_manager.gd` already contains it. This is a divergence between plan state and code state. The code path exists, but the broader canon (determinism, paddy existence, classifier unification) has not been ratified around it. So the per-preset scale is mechanically present but not yet validated against the actual gameplay requirements (e.g., paddy fields need < 25 m AO relief per THE_PLAN §2 proof).

### Verdict

The manager solved the **wrong** layer of the problem: it scaled the global amplitude ceiling, but the engine still normalizes to that ceiling and still applies ridge/cliff processing to every preset. Relief is therefore still extreme in shape, even when the numbers are smaller.

---

## 3. Concrete code fixes, smallest to largest

### Tier 1 — parameter tuning (minutes to hours)

1. **Lower per-preset `height_scale` values in `_preset_height_scale()` (`terrain_manager.gd:385-407`).**
   - COASTAL_HILLS: 60 → 25–30 m (THE_PLAN §47 says 0–25 m relief for inhabited war).
   - RIVER_VALLEY: 80 → 40–50 m.
   - ROLLING_HILLS: 130 → 80–100 m.
   - STEEP_MOUNTAINS: 460 may be acceptable but should be measured; 350 is safer.

2. **Disable or reduce ridge/cliff processing for lowland presets in `preset_params` (`terrain_engine.gd:83-151`).**
   - COASTAL_HILLS already disables `ridge_enabled`; explicitly set `cliff_enabled = false`.
   - RIVER_VALLEY: set `ridge_enabled = false`, or reduce `ridge_blend` to 0.1 and `cliff_sharpness` to 1.0.
   - ROLLING_HILLS: reduce `ridge_blend` to 0.15, `cliff_sharpness` to 1.5, increase `smoothing_passes` to 4–5.

3. **Reduce `warp_strength` for low-relief presets.** A 20–50 cell warp on a 25 m coastal map is disproportionate. Scale `warp_strength` with `height_scale` or set lowland presets to 5–10.

4. **Reduce `detail_amplitude` or make it scale-aware.** On lowland maps, ±2–3 m of detail breaks paddy flatness. Use 0.02–0.03 for inhabited presets.

5. **Fix the shader scale mismatch (`terrain_chunk.gd:158`)** by passing the actual chunk height scale to the shader instead of hardcoding 280.0.

### Tier 2 — algorithm change (hours to a day)

1. **Replace the final normalization with explicit amplitude scaling.**  
   Instead of `_normalize_heightmap()` stretching to `[0, 1]`, compute the raw standard deviation or peak-to-peak and scale by a per-preset target amplitude. This prevents the normalizer from manufacturing relief.

2. **Add a post-generation relief compressor/curvature filter.**  
   After the noise stack but before normalization, apply a power curve or histogram remapping that clamps extreme slopes and reduces the tails. This preserves macro shape while killing the "destroying the map" spikiness.

3. **Make the ridge/cliff stages preset-aware in amplitude, not just on/off.**  
   Currently they add normalized deltas. Pass the desired relief budget into each stage so a 60 m preset cannot create a 30 m local cliff.

4. **Move `detail_noise` application behind a slope threshold.**  
   Add detail only where the local gradient is low; skip it on steep faces to reduce aliased cliffs.

### Tier 3 — engine replacement or major refactor (days)

1. **Replace the custom engine with a simpler noise stack.**  
   Drop ridged multifractal and cliff terracing entirely; use layered FBM with domain warping only, plus optional erosion. This sacrifices some "dramatic peak" visual variety but is far more controllable.

2. **Swap to Terrain3D or HTerrain (see §4).**

---

## 4. What swapping to Terrain3D/HTerrain would cost and what canon it would violate

### What the plugins offer

GPU clipmap terrain, texture splatting, editor sculpting, and usually better rendering performance for large open worlds.

### Direct costs

1. **Runtime procedural generation from seed.**  
   Both Terrain3D and HTerrain are designed around authored heightmaps saved to disk. Generating a 3 km × 3 km heightmap from a seed at runtime, carving rivers, applying craters, and rebuilding it on demand is not their primary path. You would need to write a bridge that builds their internal data structures from your noise stack.

2. **Live deformation (craters/clearing).**  
   `damage_system.gd` and `clearing_system.gd` modify the heightmap live. Plugin terrain data may require rebuilds or texture updates after deformation; the current `heightmap_storage.gd` + `modify_region()` API is cheap and purpose-built.

3. **River hydrology integration.**  
   `terrain/water/river_generator.gd` runs on `HeightmapStorage`. Porting priority-flood, D8 flow accumulation, and river carving to a plugin heightfield would be non-trivial and risks reintroducing the water bugs already fixed (TERRAIN_WORKFLOW.md §5).

4. **Vegetation grid coupling.**  
   `gameplay_grid.gd` and `jungle_patch_layer.gd` query the heightmap through `TerrainManager.get_height_at()`. A plugin would need a compatible height-query API and a way to expose the raw heightmap for gameplay classification.

5. **Chunk streaming rewrite.**  
   `terrain_manager.gd` owns chunk loading/unloading around the camera. A clipmap plugin replaces that entire logic; you lose the deterministic, seed-driven streaming boundary.

6. **Dependency risk.**  
   Godot 4.7 plugin compatibility is not guaranteed. Locking the project to a third-party C++ module adds build and update fragility.

### Canon violations

| Canon document | Rule | Violation risk |
|---|---|---|
| **ADR-017 persistent province** | World generated from province seed and rebuilt on demand. | High. Plugins expect saved terrain assets, not runtime seed regeneration. |
| **ADR-013 AO loading** | 1.5 km AO loads as 5×5 chunks. | High. Clipmaps replace chunked mesh generation with continuous LOD; the 5×5 contract disappears. |
| **TERRAIN_WORKFLOW.md §2** | Hand-sculpted/author-first terrain kills the design. | Medium. The plugin's editor sculpt tools do not force hand-authoring, but the workflow pressure is real and the doc already forbade the equivalent Blender path. |
| **TERRAIN_WORKFLOW.md §1** | "Code-generated heightmap is correct." | Direct. Option A is declared correct; plugins are listed as fighting everything below. |
| **ADR-023 fossil law** | Delete the old system when replaced. | N/A until replacement happens, but a plugin swap would be a massive deletion requiring the fossil probe to be updated first. |

### Verdict on replacement

Swapping is a **last resort**, not a fix for this bug. The current engine is architecturally aligned with the project's procedural, deformable, seed-driven canon. The problem is the **noise stack and normalizer**, not the chunked-mesh approach. Fix the engine first; replace it only if performance or artist workflow demands it after the relief issue is resolved.

---

## 5. Verification probe I would write

A headless test that runs the full generation pipeline for a representative seed set and asserts per-preset relief bounds.

### Probe: `test_terrain_relief_bounds`

For each preset, generate 20 deterministic seeds and measure:

1. **AO relief:** `max(heightmap_data) - min(heightmap_data)` in meters (i.e., after applying `height_scale`).
2. **Average absolute slope:** central-difference gradient across the map, in meters per cell (2 m cell size).
3. **Steep-cell percentage:** fraction of cells where slope exceeds a preset-specific threshold (e.g., 30° for highland, 8° for lowland).
4. **Local peak-to-valley roughness:** standard deviation of a 32×32 m moving window, averaged across the map.

### Assertions

- **COASTAL_HILLS:** total relief ≤ 30 m; steep-cell percentage ≤ 5%; window roughness ≤ 2 m.
- **RIVER_VALLEY:** total relief ≤ 50 m; steep-cell percentage ≤ 10%; window roughness ≤ 3 m.
- **ROLLING_HILLS:** total relief ≤ 100 m; steep-cell percentage ≤ 20%; window roughness ≤ 6 m.
- **STEEP_MOUNTAINS / PLATEAU:** keep current thresholds but assert no more than X% of cells are unplayable cliffs (calibrated by gameplay).

### Additional regression checks

- **Determinism:** same seed produces identical `PackedFloat32Array` hash before and after the fix.
- **Paddy existence (ties to THE_PLAN Step 3):** on a LOWLAND seed, gameplay_grid reports > 0 rice-paddy cells; on a HIGHLAND seed, 0.
- **River carving sanity:** after `_extract_and_carve_rivers()`, no river cell is more than 5 m below its neighbors outside the carve radius.

### Where it lives

Add to the existing test suite under `tests/terrain/`. The probe must run headless so CI can enforce it, and it should fail the build if any preset exceeds its relief budget. This is the only way to prove the fix is real and stays real across future preset edits.

---

## Tradeoff summary

- **Parameter tuning is cheap** but leaves the normalization ratchet in place; it will regress the moment someone edits noise parameters.
- **Replacing normalization with explicit amplitude scaling is the durable fix** but changes the engine's contract and requires updating the test suite.
- **Engine replacement with Terrain3D/HTerrain looks modern** but violates the project's core procedural/deformable/seed-driven pillars and costs days of integration.
- **The fastest honest path** is tier-1 parameter clamp plus tier-2 normalization removal, followed by the relief-bounds probe to lock it in.
