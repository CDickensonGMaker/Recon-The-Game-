# War Room Decree — 2026-07-14

## Council verdict

### Terrain engine: REPAIR, do not replace

The current terrain engine is architecturally correct for the project (chunked, seed-driven, deformable). The "destroyed map" feeling comes from `_normalize_heightmap()` in `terrain/core/terrain_engine.gd:621-636`, which stretches every generated heightmap to 100% of the preset's `height_scale`, combined with ridge/cliff/detail stages that are not relief-budget-aware.

### Root causes

1. **Normalization ratchet.** Every map, gentle or steep, is remapped to `[0, height_scale]`.
2. **Preset parameters too aggressive for lowland maps.** COASTAL_HILLS and RIVER_VALLEY still run ridge and cliff processing.
3. **Shader scale mismatch.** `terrain_chunk.gd:158` hardcodes `height_scale = 280.0` in the shader while the mesh uses the per-preset scale.

### Decreed fix

1. **Per-preset relief budgets** (update `terrain_manager.gd:_preset_height_scale()`):
   - COASTAL_HILLS: 60 → 25 m
   - RIVER_VALLEY: 80 → 40 m
   - ROLLING_HILLS: 130 → 90 m
   - STEEP_MOUNTAINS: 460 → 300 m (measure before finalizing)
   - PLATEAU: 220 → 160 m
2. **Preset-aware parameter overrides** (update `terrain_engine.gd:preset_params`):
   - COASTAL_HILLS: `ridge_enabled = false`, `cliff_enabled = false`, `warp_strength = 8.0`, `detail_amplitude = 0.02`.
   - RIVER_VALLEY: `ridge_enabled = false`, `cliff_enabled = false`, `warp_strength = 12.0`, `detail_amplitude = 0.03`.
   - ROLLING_HILLS: `ridge_blend = 0.15`, `cliff_sharpness = 1.2`, `smoothing_passes = 4`.
3. **Replace `_normalize_heightmap()` with bounded scaling.** Instead of stretching to full `[0, 1]`, scale by a per-preset target amplitude so the relief budget is enforced, not manufactured. Keep deterministic output.
4. **Fix shader scale** in `terrain_chunk.gd:158` to use the actual chunk height scale.
5. **Write `tests/test_terrain_relief_bounds.tscn`.** Generate per preset, assert total relief, steep-cell %, and 32 m window roughness. This is the proof.

### Grunt v3 + random spawner

- `AllyBase` already defaults to `us_grunt_v3` (`ally_base.gd:154`).
- The problem is `SquadSystem.MOS_BODY` overriding every squad member with a deterministic MOS body.
- **Decree:** weapon-pooled randomness. RIFLEMAN/POINTMAN/MEDIC draw from a pool of M16 bodies including `us_grunt_v3`. MG/GRENADIER/MARKSMAN/RTO stay weapon/role-locked so the player can read the squad.
- **Implementation:** add body pools to `SquadSystem` keyed by weapon, pick randomly at spawn.
- **Do not** build a new character manager.

### Animation linking

- The "character manager" is `ModelActor`. It already merges `anim_library.glb`, fixes loop modes, resolves aliases, and matches locomotion speed.
- **Decree:** verify, do not rewrite. Build `tests/test_model_actor_animations.tscn` that iterates `ModelActor.all_units()` and proves idle/run/fire/death clips resolve and loop correctly.
- Fix any export that breaks the `PSXRig/Skeleton3D` contract (the medic exporter is already flagged in `ANIM_WISHLIST.md` as targeting `MixamoRig`).

## Tradeoffs named

- Lowland maps become flatter; that is required for paddies/villages.
- Highland maps lose some peak drama; necessary for playability.
- Squad bodies are not fully random; MOS readability is preserved.
- No shiny new terrain plugin or character manager; instead, the existing canon-aligned systems are made to work.

## Beads created from this decree

1. `RECONgame-p7wx` — terrain relief fix + relief-bounds probe
2. `RECONgame-11jm` — weapon-pooled grunt body randomizer
3. `RECONgame-mt1b` — ModelActor animation contract probe + export fixes

## Next step

Summoner ratifies this decree. No code is written until ratification.
