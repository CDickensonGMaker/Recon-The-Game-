# Level-Designer Analysis — Terrain Playability

## The symptom in player terms

The Summoner feels the terrain is "destroying the map every generation." Translated: the ground is producing unplayable geometry — sheer peaks, deep pits, or relief so strong that the intended AO (patrol routes, paddy fields, village sites, exfil LZs) cannot be placed on it.

## What the numbers say

- `terrain/core/terrain_engine.gd:18-19`: default `cell_size = 2.0`, `height_scale = 280.0`.
- `terrain/core/terrain_engine.gd:621-636`: `_normalize_heightmap()` remaps the generated noise to the full 0–1 range, **then** multiplies by `height_scale`.
- `terrain/core/terrain_manager.gd:385-407`: per-preset scales were already added (COASTAL 60 m, RIVER 80 m, ROLLING 130 m, STEEP 460 m, PLATEAU 220 m).

The per-preset scales are a good instinct, but they fight the normalizer: the normalizer guarantees every map uses 0–100% of its preset scale, so **the relative relief is identical every time**. A "gentle" lowland map and a "dramatic" mountain map differ only in absolute meters, not in how rugged they feel.

## Why this breaks the design

1. **Paddies and villages need flat ground.** `THE_PLAN.md` Step 2 defines lowland relief as <25 m across the whole 1.28 km AO. If the normalizer stretches even low-frequency noise to the full 80 m scale, the ground is still too folded for irrigated paddies.
2. **E&E sightlines.** TERRAIN_WORKFLOW.md §10 notes that wading a creek gives 92 m visibility because the creek is narrow and roofed. That only works if the surrounding terrain is *gently* sloped. Extreme relief creates vertical canyons that make the concealment readouts lie.
3. **Firebase inside the AO.** ADR-017 / THE_PLAN.md put the firebase in the AO. If the spawn area lands on a 60° slope or in a basin below "sea level," the hub is unplayable.
4. **Choke points become walls.** The 1.28 km AO is not large enough to absorb 460 m of relief without producing impassable ridges. 60–130 m of total relief is plenty for Vietnam highlands at this scale.

## Recommendation

Do **not** swap the engine. The problem is not FastNoiseLite or the chunked mesh pipeline; it is the normalization step and the default parameter values. The fix is:

1. Make `_normalize_heightmap()` optional or replace it with a bounded remap that preserves the authored distribution.
2. Add a **relief target** per preset (e.g., LOWLAND 8–18 m peak-to-valley, ROLLING 40–80 m, STEEP 150–250 m) and generate until the raw noise falls inside that band, or post-process to compress outliers.
3. Keep the per-preset `height_scale` but treat it as a **soft ceiling**, not a mandatory span.
4. Author flat terraces for the inhabited 40% (COASTAL/RIVER) explicitly, rather than hoping noise produces them.

## Sacrifice

- Swapping to Terrain3D/HTerrain would give prettier sculpting but would break ADR-017 (procedural province) and ADR-013 (≤2 km load-whole). Keep the current engine.
- Extreme mountain presets will become less dramatic. That is the cost of playability.
