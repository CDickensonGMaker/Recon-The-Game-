# 10-Part Implementation Plan — RECONgame terrain + grunt + animation fixes

**Ratified from:** `synthesis.md` (War Room decree 2026-07-14)
**Goal:** implement beads `RECONgame-p7wx`, `RECONgame-11jm`, `RECONgame-mt1b` in a single ordered pass, with a verification gate after every phase.

---

## Part 1 — Write the terrain relief-bounds probe

**Files to touch:**
- `tests/test_terrain_relief_bounds.gd` (new)
- `tests/test_terrain_relief_bounds.tscn` (new)

**What it does:**
1. Instantiate `TerrainEngine`.
2. For each of the 5 presets, generate 5 deterministic seeds.
3. Measure:
   - total relief = `(max - min) * height_scale`
   - average absolute slope (central differences, degrees)
   - steep-cell % (slope > threshold per preset)
   - 32 m window roughness (std dev of 16×16 cell windows)
4. Assert per-preset budgets:
   - COASTAL_HILLS: relief ≤ 30 m, steep ≤ 5 %, roughness ≤ 2 m
   - RIVER_VALLEY: relief ≤ 50 m, steep ≤ 10 %, roughness ≤ 3 m
   - ROLLING_HILLS: relief ≤ 110 m, steep ≤ 20 %, roughness ≤ 6 m
   - STEEP_MOUNTAINS: relief ≤ 350 m, steep ≤ 45 %, roughness ≤ 20 m
   - PLATEAU: relief ≤ 200 m, steep ≤ 35 %, roughness ≤ 12 m
5. Assert determinism: same seed → identical `heightmap_data` hash twice.

**Exit gate:** the probe runs and fails (expected — current code exceeds budgets). It must not crash.

---

## Part 2 — Implement per-preset relief budgets in `TerrainManager`

**Files to touch:**
- `terrain/core/terrain_manager.gd:385-407` (`_preset_height_scale()`)

**Changes:**
```gdscript
0: return 25.0   # COASTAL_HILLS
1: return 40.0   # RIVER_VALLEY
2: return 90.0   # ROLLING_HILLS
3: return 300.0  # STEEP_MOUNTAINS
4: return 160.0  # PLATEAU
```

**Exit gate:** probe still runs; total relief numbers drop but remain too high because the normalizer stretches to the new ceilings. Slope/roughness still red.

---

## Part 3 — Disable ridge/cliff for lowland presets and tune warp/detail

**Files to touch:**
- `terrain/core/terrain_engine.gd:83-151` (`preset_params`)

**Changes:**
- COASTAL_HILLS:
  - `warp_strength: 8.0`
  - `cliff_enabled: false`
  - `detail_amplitude: 0.02`
- RIVER_VALLEY:
  - `ridge_enabled: false`
  - `cliff_enabled: false`
  - `warp_strength: 12.0`
  - `detail_amplitude: 0.03`
  - `smoothing_passes: 3`
- ROLLING_HILLS:
  - `ridge_blend: 0.15`
  - `cliff_sharpness: 1.2`
  - `smoothing_passes: 4`
- STEEP_MOUNTAINS / PLATEAU: leave dramatic, but lower `warp_strength` to 70 % of current.

**Exit gate:** steep-cell % and roughness should drop for lowland presets. Total relief still stretched to 100 % of budget.

---

## Part 4 — Replace the normalization ratchet with bounded amplitude scaling

**Files to touch:**
- `terrain/core/terrain_engine.gd:621-636` (`_normalize_heightmap()`)
- `terrain/core/terrain_manager.gd:123-126` (how `height_scale` is passed)

**Approach:**
1. Rename `_normalize_heightmap()` to `_scale_heightmap()`.
2. Instead of remapping min→0 and max→1, compute raw range and standard deviation, then scale by a per-preset **target amplitude**.
3. Preserve the existing API: `heightmap_data` stays in 0–1-ish range for downstream code, but the mapping is controlled, not stretched.
4. Pass the target amplitude from `TerrainManager` via a new `TerrainEngine.target_relief` property, set alongside `height_scale`.

**Pseudo-code:**
```gdscript
# in terrain_engine.gd
var target_relief: float = 1.0  # normalized target peak-to-valley

func _scale_heightmap() -> void:
    var mean: float = 0.0
    var min_h: float = INF
    var max_h: float = -INF
    for h in heightmap_data:
        mean += h
        min_h = min(min_h, h)
        max_h = max(max_h, h)
    mean /= heightmap_data.size()
    var variance: float = 0.0
    for h in heightmap_data:
        variance += (h - mean) * (h - mean)
    variance /= heightmap_data.size()
    var std: float = sqrt(variance)
    var raw_range: float = max_h - min_h
    if raw_range < 0.001 or std < 0.001:
        return
    # Scale so the bulk of the distribution fits target_relief, but allow outliers
    var scale: float = target_relief / (std * 2.0)
    scale = clampf(scale, target_relief / raw_range, target_relief / (std * 1.0))
    for i in range(heightmap_data.size()):
        heightmap_data[i] = (heightmap_data[i] - mean) * scale + 0.5
    # Clamp to [0,1] to avoid downstream overflow
    for i in range(heightmap_data.size()):
        heightmap_data[i] = clampf(heightmap_data[i], 0.0, 1.0)
```

**Exit gate:** total relief now tracks the target budget. Probe begins to turn green for lowland presets.

---

## Part 5 — Fix terrain shader scale mismatch

**Files to touch:**
- `terrain/core/terrain_chunk.gd:158`
- `terrain/core/terrain_chunk.gd:45` (`build_mesh` signature)
- `terrain/core/terrain_manager.gd:259` (`chunk.build_mesh()` call)

**Changes:**
1. Change `build_mesh(...)` to accept `shader_height_scale: float` alongside `h_scale`.
2. In `_create_shared_material()`, use the passed scale instead of hardcoded `280.0`.
3. In `TerrainManager._load_chunk()`, pass `heightmap.height_scale` for the shader parameter.

**Exit gate:** no visual/parallax discontinuity when switching presets in `terrain_lab` or during gameplay.

---

## Part 6 — Iterate probe until green + add paddy-existence regression

**Files to touch:**
- `tests/test_terrain_relief_bounds.gd`

**Changes:**
1. Run probe; tune Part 3/4 constants until all 5 presets pass.
2. Add a second deterministic check: on LOWLAND seeds (`COASTAL`/`RIVER`), `GameplayGrid` must report `> 0` `RICE_PADDY` cells; on HIGHLAND seeds, `0`.
3. Add slope histogram logging so future councils can read the output.

**Exit gate:** `tests/test_terrain_relief_bounds.tscn` passes headlessly. Bead `RECONgame-p7wx` closes.

---

## Part 7 — Write the ModelActor animation contract probe

**Files to touch:**
- `tests/test_model_actor_animations.gd` (new)
- `tests/test_model_actor_animations.tscn` (new)

**What it does:**
1. Iterate `ModelActor.all_units()`.
2. For each unit:
   - instantiate `ModelActor`, call `setup(unit_id)`, assert returns true.
   - assert `PSXRig/Skeleton3D` exists.
   - for each canonical clip `idle`, `run_forward`, `firing_rifle`, `death_forward`:
     - call `play(clip, true)`, assert returns true.
     - assert clip exists via `has_clip()`.
   - assert `idle` and `run_forward` loop; `death_forward` does not.
   - assert shared library clips were merged (clip count > bare GLB count).
3. Log failures with unit name and missing clips.

**Exit gate:** probe runs; some units may fail (expected if exports are contract-breaking). No crashes.

---

## Part 8 — Fix any export contract breakers the probe finds

**Files to touch:**
- `tools/export_us_squad.py` or equivalent exporter scripts
- `assets/shared/anim_library.glb` if clips are missing
- Possibly `tools/export_medic.py` if `us_medic.glb` still targets `MixamoRig`

**Approach:**
1. Run the probe and collect the failure list.
2. For each failing unit, inspect the GLB in-engine or via Blender to find:
   - wrong armature node name (must be `PSXRig`)
   - missing `Skeleton3D` child
   - missing clips in `anim_library.glb`
3. Fix the exporter; re-export; re-run probe.

**Exit gate:** `test_model_actor_animations` passes for every US character GLB. Bead `RECONgame-mt1b` closes.

---

## Part 9 — Implement weapon-pooled grunt body randomizer

**Files to touch:**
- `scripts/squad/squad_system.gd:59-67` (`MOS_BODY`)
- `scripts/squad/squad_system.gd:39-46` (spawn loop)

**Changes:**
1. Replace the single `MOS_BODY` mapping with two structures:
   - `MOS_WEAPON`: maps MOS → weapon string.
   - `WEAPON_BODY_POOLS`: maps weapon string → array of compatible GLB unit IDs.
2. Example pools:
   ```gdscript
   const WEAPON_BODY_POOLS: Dictionary = {
       "m16a1": ["us_grunt_v3", "us_grunt_rifleman", "us_grunt_pointman", "us_grunt_rto", "us_medic"],
       "m60":   ["us_grunt_mg"],
       "m79":   ["us_grunt_grenadier"],
       "m70":   ["us_grunt_marksman"],
   }
   ```
3. In `setup()`, after resolving MOS weapon, pick a random body from the pool using the existing roster RNG or a sub-seed.
4. RTO body choice: keep `us_grunt_rto` so the PRC-25 is always visible; do not put RTO in the generic pool.
5. Keep MG fire-rate bonus keyed on MOS.

**Exit gate:** repeated squad spawns on the same roster seed produce different rifleman bodies; MG/grenadier/marksman/rto remain stable.

---

## Part 10 — Full integration: run test suite, headless boot, commit

**Commands:**
1. `godot --headless --path . --quit-after 300` and grep for `SCRIPT ERROR`.
2. `run_all_tests.ps1` or equivalent test harness.
3. `bd update RECONgame-p7wx --status done` (when probe green)
4. `bd update RECONgame-mt1b --status done` (when probe green)
5. `bd update RECONgame-11jm --status done` (when randomizer verified)
6. `git add -A && git commit -m "terrain relief, grunt randomizer, anim contract probes"`
7. `git push`

**Exit gate:** all tests green, headless boot clean, beads closed, changes pushed.

---

## Dependencies / order

```
Part 1 → Part 2 → Part 3 → Part 4 → Part 5 → Part 6
                                          ↓
                                    Part 7 → Part 8
                                          ↓
                                    Part 9
                                          ↓
                                    Part 10
```

Parts 7–8 (animation) can run in parallel with Parts 2–5 (terrain tuning) once Part 1 is done, but Part 10 is the final gate for all three beads.

## Risk notes

- Part 4 changes the heightmap amplitude contract. Any code assuming the full 0–1 range is occupied (e.g., water level placement) must be checked. `HeightmapStorage` and river carving read normalized data; they should adapt automatically if scale is applied consistently.
- Part 9 uses random body selection. Ensure the chosen body exists on disk (`ModelActor.model_exists`) before calling `set_sprite`; otherwise it falls back to capsule.
- Part 8 may require Blender re-exports. If a unit is missing from `anim_library.glb`, the fix may be in the shared library export, not the character export.
