# DEAD CODE AUDIT — RECONgame
**Date:** 2026-07-13
**Scope:** `scripts/` (game), `terrain/` (vendored TerrainEngine), `data/`, `tests/`, `tools/`
**Method:** Static analysis. Every `func` / `signal` / `const` / `@export` / member var was indexed, then every identifier was searched across all `.gd` (comment-stripped), `.tscn`, `.tres`, `.godot`, `.cfg`. Transitive reachability was computed from roots (Godot lifecycle virtuals, `.tscn`-connected methods, top-level references). `has_method()` / `call()` / `call_deferred()` string-dispatch names were enumerated separately and cross-checked.

**No files were modified. This is an audit only.**

---

## HEADLINE NUMBERS

| Metric | Count | Notes |
|---|---|---|
| Total `func` definitions | 1,906 | |
| **Transitively dead functions** | **157 (8.2%)** | terrain/ 71 · scripts/ 43 · data/ 43 |
| Total signals | 142 | |
| **Dead signals** | **52 (36.6%)** | 4 never emitted + 48 emitted-into-the-void |
| Dead consts | 16 | |
| Dead `@export`s | 9 | |
| Dead member vars | 11 | |
| Unreachable statement blocks | 1 (~55 lines) | |
| Permanently-true guards | 1 | |
| Large commented-out code blocks | **0** | clean |
| **Fully dead files** | **3 (1,538 lines)** | |

---

## 1. UNCALLED FUNCTIONS

### 1A. FULLY DEAD FILES — highest impact

These files' entry points have **zero references anywhere in the repo** (checked `.gd`, `.tscn`, `.tres`, `.godot`). Everything inside them is dead by transitivity.

| File | Lines | Symbol | Why dead |
|---|---|---|---|
| `data/vietnam/vietnam_weapon_data.gd` | **994** | `class_name VietnamWeaponData` | The class name appears **exactly once in the repo: on its own declaration line (`:1`)**. Nothing loads it, nothing extends it, no `.tres` uses `script_class="VietnamWeaponData"`. All 10 funcs dead (`get_weapon:853`, `_init_definitions:131`, `calculate_accuracy:916`, `get_projectile_config:883`…). The live weapon class is `scripts/weapons/weapon_data.gd` (`WeaponData`) — every `.tres` in `data/weapons/` declares `script_class="WeaponData"`. |
| `data/vietnam/vietnam_unit_data.gd` | **420** | `class_name VietnamUnitData` | Referenced **only by itself**. The 4 public entry points (`get_unit_data:352`, `get_all_us_units:394`, `get_all_vc_units:405`, `get_all_nva_units:414`) have zero external callers, so all 15 `create_*` factories (`create_rifle_platoon:60` … `create_forward_observer:328`) are transitively dead. 19/19 funcs dead. |
| `terrain/vegetation/poisson_sampler.gd` | **124** | `sample_2d:16`, `_set_grid_cell:87`, `_is_valid_point:95` | 3/3 funcs dead. The **only** reference in the repo is `terrain/scenes/terrain_lab.gd:11` — `const PoissonSamplerClass := preload(...)` — and **that const is itself never used** (see §3). Reachable from nothing. |

**Combined: 1,538 lines of vendored RTS-heritage code that cannot execute.**

### 1B. `data/vietnam/game_enums.gd` — 14 of 15 funcs dead

The `GameEnums` autoload is 722 lines. Only **four** members are ever touched: `UnitType` (28 refs), `FearType` (24), `WeaponClass` (22), `Faction` (18). Every helper function is dead:

| file:line | symbol |
|---|---|
| `data/vietnam/game_enums.gd:609` | `is_us_faction` |
| `data/vietnam/game_enums.gd:612` | `is_enemy_faction` |
| `data/vietnam/game_enums.gd:615` | `get_faction_name` |
| `data/vietnam/game_enums.gd:626` | `get_terrain_speed_modifier` |
| `data/vietnam/game_enums.gd:641` | `get_firebase_slots` |
| `data/vietnam/game_enums.gd:650` | `get_suppression_state` |
| `data/vietnam/game_enums.gd:662` | `get_suppression_effects` |
| `data/vietnam/game_enums.gd:667` | `get_training_modifier` |
| `data/vietnam/game_enums.gd:673` | `get_morale_state` |
| `data/vietnam/game_enums.gd:685` | `get_fear_value` |
| `data/vietnam/game_enums.gd:690` | `get_fear_aoe` |
| `data/vietnam/game_enums.gd:695` | `get_cover_damage_reduction` |
| `data/vietnam/game_enums.gd:700` | `get_cover_suppression_modifier` |
| `data/vietnam/game_enums.gd:705` | `terrain_to_cover` |

A whole suppression/morale/cover rules layer exists as an autoload and is never consulted.

### 1C. `CombatManager.apply_bullet_damage` — the damage funnel nobody uses

| file:line | symbol | why dead |
|---|---|---|
| `scripts/autoload/combat_manager.gd:76` | `apply_bullet_damage` | **Zero callers.** The live bullet path is `scripts/combat/bullet_system.gd:141`, which calls `target.take_damage(...)` **directly**, bypassing CombatManager entirely. |

This is the highest-consequence single dead function in `scripts/`, because **two signals emit only from inside it** and therefore can never fire:

- `damage_dealt` (emitted at `combat_manager.gd:94` — inside the dead func)
- `entity_killed` (emitted at `combat_manager.gd:97` — inside the dead func)

It also means `GameManager.on_enemy_killed()` at `combat_manager.gd:99` is unreachable via this path, and the knockback helper `_apply_knockback:104` only runs from the dead function.

### 1D. `GameplayGrid` — the tactical query API is write-only

The grid is built and stamped, and four narrow readers are used (`is_position_passable`, `is_water`, `get_terrain_type`, `get_vegetation`). The **entire rich tactical query API has zero callers**:

| file:line | symbol |
|---|---|
| `terrain/core/gameplay_grid.gd:412` | `grid_to_world` |
| `terrain/core/gameplay_grid.gd:458` | `get_movement_cost` |
| `terrain/core/gameplay_grid.gd:470` | `get_cover` |
| `terrain/core/gameplay_grid.gd:476` | `get_defense_bonus` |
| `terrain/core/gameplay_grid.gd:494` | `is_cell_passable` |
| `terrain/core/gameplay_grid.gd:520` | `get_water_flow` |
| `terrain/core/gameplay_grid.gd:527` | `is_wadeable` |
| `terrain/core/gameplay_grid.gd:533` | `requires_boat` |
| `terrain/core/gameplay_grid.gd:539` | `get_elevation_advantage` |
| `terrain/core/gameplay_grid.gd:638` | **`mark_cleared`** |

**`mark_cleared` (`:638`) is called by NOTHING** — and the file's own comment at `:211` admits it: *"update_region() ran its body NEVER, mark_cleared() was called by NOTHING."* The `update_region` half was fixed (see §4); `mark_cleared` was not. Consequence: when the player blows down jungle, `vegetation_manager.clear_area()` removes the **visuals**, but no code path marks those grid cells `TerrainType.CLEAR`. The grid's cover/passability/movement-cost data never learns the jungle is gone.

Note the flow-query chain is dead all the way down through a `has_method` indirection: `get_water_flow:520` → `water_system.get_flow_at:492` → `water_body_data.get_flow_at:116`. All three are dead because the head of the chain is.

Also: `scripts/player/player.gd:691` reads `GameplayGrid.MOVEMENT_COSTS[...]` **directly** rather than calling `get_movement_cost()` — the function that exists to do exactly that is bypassed.

### 1E. Dead terrain/water subsystems

| file:line | symbol | why dead |
|---|---|---|
| `terrain/water/pond_detector.gd:47` | `detect_depressions` | Zero callers. `water_system.gd:203` instantiates `PondDetectorClass` but only uses `cells_to_polygon` / `simplify_polygon` / the `Depression` inner class. The **pond-detection algorithm itself never runs** — dragging `_find_local_minima:82`, `_is_local_minimum:96`, `_flood_fill_depression:111` dead with it. |
| `terrain/water/river_generator.gd:174` | `extract_rivers` | Zero callers → `_trace_river_paths:298` dead too. |
| `terrain/water/river_generator.gd:396` | `paths_to_cells` | Zero callers. |
| `terrain/water/water_system.gd:431/460/474/492/500/511/583` | `get_water_type`, `get_water_level_at`, `get_water_at`, `get_flow_at`, `get_water_in_chunk`, `get_water_near`, `get_distance_to_water` | 7 of 27 funcs. The water query API is almost entirely unconsumed. |
| `terrain/water/water_body_data.gd:62/90/106/116/142/161/173` | `is_static`, `contains_point`, `get_depth_at`, `get_flow_at`, `_point_near_path`, `_closest_point_on_segment`, `_point_in_polygon` | 7 of 12 funcs — including the whole point-in-body geometry stack. |

### 1F. Superseded duplicates left behind

| file:line | symbol | why dead |
|---|---|---|
| `terrain/core/terrain_manager.gd:199` | `_load_initial_chunks` | Superseded by `_load_initial_chunks_async:209`, which is what `:165` actually awaits. The sync version is a stranded twin. |
| `terrain/vegetation/vegetation_manager.gd:359` | `_generate_chunk_vegetation` | Zero callers; `_generate_chunk_grass:454` dead with it. |
| `terrain/ui/terrain_lab_ui.gd:222` | `_on_regenerate_pressed` | **Not connected.** `terrain_lab.tscn:410` wires `pressed` → `_on_regenerate` (no `_pressed` suffix), on the scene root (`to="."` = `terrain_lab.gd`). This handler is orphaned, and the `regenerate_requested` signal it emits is connected at `terrain_lab.gd:286` — so the signal is live but *this emitter* is unreachable. |

### 1G. Other confirmed-dead functions in `scripts/`

Grouped; all have zero callers in `.gd`/`.tscn`/`.tres` and are not dynamic-dispatch targets.

**Player / combat accessors nobody reads (r4bk Law relevance — see §2):**
| file:line | symbol |
|---|---|
| `scripts/player/grenade_handler.gd:129` | `get_cook_progress` |
| `scripts/player/grenade_handler.gd:136` | `get_remaining_fuse` |
| `scripts/player/weapon_holder.gd:956` | `is_weapon_switching` |
| `scripts/player/weapon_holder.gd:961` | `get_reload_progress` |
| `scripts/player/equipment_manager.gd:161` | `is_slot_switching` |
| `scripts/player/health_system.gd:246` | `stabilize` |
| `scripts/player/health_system.gd:294` | `is_critical` |
| `scripts/player/health_system.gd:299` | `add_health_pack` |
| `scripts/player/health_system.gd:305` | `get_health_pack_count` |
| `scripts/player/health_system.gd:310` | `get_bleed_time_remaining` |
| `scripts/player/player.gd:767` | `get_current_speed` |
| `scripts/player/player.gd:846` | `get_health_system` |

**Autoloads / systems:**
| file:line | symbol |
|---|---|
| `scripts/autoload/combat_manager.gd:289` | `get_closest_enemy` |
| `scripts/autoload/combat_manager.gd:329` | `spawn_projectile_at_target` |
| `scripts/autoload/combat_manager.gd:337` | `clear_all_projectiles` |
| `scripts/autoload/enums.gd:71` | `get_damage_type_name` |
| `scripts/autoload/game_manager.gd:77` | `set_total_enemies` |
| `scripts/autoload/game_manager.gd:83` | `reset_level` |
| `scripts/autoload/save_manager.gd:236` | `has_any_save` |
| `scripts/combat/gun_fx.gd:65` | `shot_stream_for` |
| `scripts/combat/hitzone.gd:88` | `is_critical_zone` |
| `scripts/combat/projectile_data.gd:66` | `get_damage_string` |
| `scripts/weapons/weapon_data.gd:131` | `get_damage_string` |
| `scripts/combat/projectile_pool.gd:25` | `warm_pool` |
| `scripts/combat/projectile_pool.gd:66` | `spawn_at_target` |
| `scripts/combat/projectile_pool.gd:95` | `get_active_count` |
| `scripts/combat/projectile_pool.gd:100` | `get_pooled_count` |
| `scripts/gameplay/radio_handset.gd:66` | `can_take` |
| `scripts/gameplay/radio_handset.gd:71` | `take` |
| `scripts/levels/game_world.gd:424` | `get_ground_height` |
| `scripts/levels/gore_dummy.gd:149` | `current_clip` |
| `scripts/missions/mission_director.gd:508` | `register_scripted_event` |
| `scripts/missions/mission_trigger.gd:79` | `disarm` |
| `scripts/missions/mission_trigger.gd:85` | `is_spent` |
| `scripts/squad/squad_system.gd:100` | `is_rto_alive` |
| `scripts/ui/action_progress.gd:103` | `cancel_action` |
| `scripts/vehicles/landing_zone.gd:54` | `can_land` |
| `scripts/vehicles/landing_zone.gd:58` | `get_landing_position` |
| `scripts/visuals/model_actor.gd:490` | `ragdoll_bone` |
| `scripts/visuals/model_actor.gd:498` | `wake_ragdoll` |
| `scripts/visuals/sprite_manifest.gd:131` | `frame_count` |
| `scripts/world/site_planner.gd:103` | `_is_soft_cover` (static, zero callers) |

**Terrain systems (remainder):**
| file:line | symbol |
|---|---|
| `terrain/core/heightmap_storage.gd:41` | `init_flat` |
| `terrain/core/heightmap_storage.gd:122` | `world_to_chunk` |
| `terrain/core/heightmap_storage.gd:156` | `get_river_accumulation` |
| `terrain/core/quality_settings.gd:175` | `get_current_settings` |
| `terrain/core/terrain_chunk.gd:266` | `get_world_bounds` |
| `terrain/core/terrain_engine.gd:701` | `get_normal_at` |
| `terrain/core/terrain_manager.gd:349` | `get_normal_at` |
| `terrain/core/terrain_manager.gd:404` | `get_loaded_chunks` |
| `terrain/core/terrain_manager.gd:412` | `get_loaded_chunk_count` |
| `terrain/core/terrain_manager.gd:417` | `get_chunk` |
| `terrain/core/terrain_manager.gd:422` | `load_all_chunks` |
| `terrain/systems/clearing_system.gd:104` | `advance_clearing` |
| `terrain/systems/clearing_system.gd:288` | `remove_zone` |
| `terrain/systems/construction_markers.gd:156` | `place_progress_ring` |
| `terrain/systems/construction_markers.gd:193` | `place_line_markers` |
| `terrain/systems/construction_markers.gd:227` | `remove_marker` |
| `terrain/systems/construction_markers.gd:236` | `clear_all_markers` |
| `terrain/systems/construction_markers.gd:278` | `_create_progress_ring` |
| `terrain/systems/damage_system.gd:290` | `apply_bombardment` |
| `terrain/systems/damage_system.gd:315` | `get_damage_count` |
| `terrain/systems/damage_system.gd:320` | `get_damage_zones` |
| `terrain/systems/engineering_system.gd:260` | `is_linear_in_progress` |
| `terrain/systems/engineering_system.gd:265` | `get_linear_start` |
| `terrain/systems/terrain_vfx.gd:263` | `stop_effect` |
| `terrain/systems/terrain_vfx.gd:339` | `play_line_effect` |
| `terrain/ui/terrain_lab_ui.gd:241` | `is_clearing_mode` |
| `terrain/vegetation/billboard_vegetation.gd:465` | `get_total_billboard_count` |
| `terrain/vegetation/vegetation_manager.gd:792` | `blocks_los` |
| `terrain/vegetation/vegetation_manager.gd:844` | `get_movement_multiplier_at` |
| `terrain/vegetation/vegetation_manager.gd:851` | `set_terrain_type_at` |
| `terrain/water/river_mesh.gd:120` | `set_water_material` |
| `terrain/water/river_mesh.gd:127` | `get_water_material` |

> `vegetation_manager.blocks_los:792` deserves a callout: **line-of-sight through vegetation is implemented and never asked.** Enemy sight checks do not consult it.

---

## 2. DEAD SIGNALS

**52 of 142 signals (36.6%) are dead.** This is the single biggest concentration of drift in the codebase and maps directly onto the **r4bk Law** ("a feature without a visible HUD affordance does not exist").

### 2A. NEVER EMITTED (4) — declared, zero `emit`, pure fiction

| file:line | signal | note |
|---|---|---|
| `scripts/player/weapon_holder.gd:9` | `ads_changed(is_aiming: bool)` | Zero emits, zero connects. ADS state change is never broadcast. |
| `scripts/player/weapon_holder.gd:12` | `reload_cancelled` | Zero emits, zero connects. |
| `terrain/core/heightmap_storage.gd:6` | `generation_complete` | Zero emits, zero connects. |
| `scripts/ui/screens/main_menu.gd:6` | `start_pressed` | **Worst case: it IS connected** (`scripts/main/game_flow.gd:128` — `menu.start_pressed.connect(show_select)`) but **never emitted**. That connection is permanently inert — a listener wired to a signal that cannot fire. |

### 2B. EMITTED BUT NEVER CONNECTED (48) — fires into the void

No listener exists anywhere (`.gd` or `.tscn`). Every `emit` is wasted work.

**Player / combat — the r4bk-relevant ones:**
| file:line | signal | emits |
|---|---|---|
| `scripts/player/weapon_holder.gd:5` | `weapon_fired` | 1 |
| `scripts/player/grenade_handler.gd:5` | `grenade_thrown` | 1 |
| `scripts/player/grenade_handler.gd:6` | `grenade_cooking` | 1 |
| `scripts/player/grenade_handler.gd:7` | `grenade_exploded_in_hand` | 1 |
| `scripts/player/health_system.gd:8` | `downed_started` | 1 |
| `scripts/autoload/combat_manager.gd:5` | `damage_dealt` | 1 (unreachable — see §1C) |
| `scripts/autoload/combat_manager.gd:6` | `entity_killed` | 1 (unreachable — see §1C) |

> **The grenade cook-off has no HUD affordance.** `grenade_cooking`, `grenade_exploded_in_hand`, and the two getters `get_cook_progress:129` / `get_remaining_fuse:136` are *all* dead. The HUD (`scripts/ui/hud.gd:63-97`) connects reload, switch, bleed, health-pack, magazine, and jam — but **nothing for cooking a grenade**. A player cooking a frag gets zero feedback. Same for `downed_started`: the DOWNED/revive state broadcasts and nobody renders it.

**Game state / mission:**
| file:line | signal | emits |
|---|---|---|
| `scripts/autoload/game_manager.gd:4` | `game_paused` | 1 |
| `scripts/autoload/game_manager.gd:5` | `game_resumed` | 1 |
| `scripts/autoload/game_manager.gd:7` | `level_complete` | 1 |
| `scripts/autoload/campaign_state.gd:5` | `threat_changed` | 2 |
| `scripts/missions/mission_director.gd:7` | `objective_completed` | 1 |
| `scripts/missions/objectives/photo_objective.gd:6` | `photo_progress` | 2 |
| `scripts/missions/objectives/plant_charge.gd:6` | `plant_progress` | 2 |
| `scripts/missions/objectives/survive_waves.gd:7` | `wave_cleared` | 1 |
| `scripts/missions/scripted_sequence.gd:43` | `sequence_bark` | 1 |
| `scripts/levels/game_world.gd:7` | `world_ready` | 1 |
| `scripts/squad/squad_system.gd:7` | `squad_changed` | 2 |
| `scripts/world/nav_baker.gd:25` | `site_nav_ready` | 1 |
| `scripts/world/nav_baker.gd:26` | `all_nav_ready` | 2 |

> **`world_ready` is a textbook case.** It is emitted at `game_world.gd:180`. Nobody connects it. Instead, **23 call sites across `tests/`, `tools/`, and `game_flow.gd` busy-poll the `is_world_ready` bool** in `while not world.is_world_ready` loops (`game_flow.gd:231`, `:412`, and every sim test). The signal exists; the codebase spins on a flag instead.

> **`objective_completed` (`mission_director.gd:7`) has no listener** — but `toast` (`:11`, 24 emits) *is* connected. Objective completion reaches the player only if the director separately fires a toast.

**Entities / vehicles / world:**
| file:line | signal | emits |
|---|---|---|
| `scripts/allies/ally_base.gd:7` | `state_changed` | 2 |
| `scripts/enemies/enemy_base.gd:7` | `state_changed` | 2 |
| `scripts/combat/grenade.gd:5` | `exploded` | 1 |
| `scripts/combat/projectile_base.gd:5` | `hit_target` | 2 |
| `scripts/combat/projectile_base.gd:6` | `expired` | 1 |
| `scripts/gameplay/radio_handset.gd:35` | `handset_taken` | 1 |
| `scripts/gameplay/radio_handset.gd:36` | `handset_returned` | 1 |
| `scripts/gameplay/radio_handset.gd:37` | `cord_snapped` | 1 |
| `scripts/gameplay/radio_handset.gd:38` | `cord_taut` | 2 |
| `scripts/vehicles/cas_airplane.gd:8` | `run_complete` | 2 |
| `scripts/vehicles/helicopter.gd:7` | `arrived_at_destination` | 1 |
| `scripts/vehicles/seat_system.gd:28` | `seated` | 1 |
| `scripts/vehicles/seat_system.gd:29` | `unseated` | 1 |

> The **entire radio-handset cord feature** (`cord_snapped`, `cord_taut`, `handset_taken`, `handset_returned`) broadcasts to nobody — and its `can_take:66` / `take:71` functions are also dead (§1G). The feature is inert end to end.

**Terrain (vendored) — 15 more:**
`gameplay_grid.gd:7 grid_updated` (3 emits) · `terrain_chunk.gd:5 mesh_ready` · `terrain_engine.gd:7 terrain_updated` · `terrain_manager.gd:13 chunk_unloaded` · `clearing_system.gd:5/6/7 clearing_started`/`clearing_progress`/`clearing_completed` · `construction_markers.gd:5/6 marker_placed`(4 emits)/`marker_removed` · `damage_system.gd:6 terrain_scarred` · `engineering_system.gd:5 operation_started` · `terrain_vfx.gd:6/7 effect_started`/`effect_completed` · `water_system.gd:11/12 water_generated`/`water_body_added`

> `grid_updated` is emitted 3× (including from `mark_cleared`, which never runs) and has **no listener** — so even if `mark_cleared` were wired up, nothing would react to the grid changing.

---

## 3. DECLARED-BUT-UNUSED

### 3A. CONSTS (16)

| file:line | const | why it matters |
|---|---|---|
| `scripts/levels/world_config.gd:14` | **`VEGETATION_DENSITY_MULT`** | **See §4 — the perf escape hatch is inert.** |
| `scripts/levels/world_config.gd:15` | **`BILLBOARD_DISTANCE_MULT`** | **See §4.** |
| `scripts/enemies/enemy_base.gd:236` | **`MAX_THINK_TIME`** | **CONFIRMED DEAD — see §4.** |
| `scripts/enemies/enemy_base.gd:234` | `ALERT_RANGE` | Superseded. `enemy_base.gd:290` comment: *"was a hardcoded ALERT_RANGE*2"* — replaced by data-driven `enemy_data.alert_range`. Const left behind. |
| `scripts/enemies/enemy_base.gd:235` | `AGGRO_RANGE` | Same — superseded by `enemy_data`, never read. |
| `scripts/player/health_system.gd:24` | `HEAL_AMOUNT` | Documented *"Full heal when you use a medkit"* — never read. Sibling `HEAL_TIME` / `BANDAGE_TIME` **are** used, so this is a genuine orphan, not a whole-feature stub. |
| `scripts/player/weapon_holder.gd:127` | `BASE_VIEWMODEL_SCALE` | Documented *"Base scale applied to all viewmodels"* — never applied. |
| `terrain/core/gameplay_grid.gd:194` | `GALLERY_MIN` | Riparian gallery-forest density band — never read. |
| `terrain/core/gameplay_grid.gd:195` | `GALLERY_MAX` | Same. |
| `data/vietnam/game_enums.gd:459` | `SUPPRESSION_THRESHOLDS` | Dead with the rest of GameEnums (§1B). |
| `data/vietnam/game_enums.gd:572` | `COVER_STEALTH_BONUS` | Same. |
| `data/vietnam/game_enums.gd:598` | `MORALE_THRESHOLDS` | Same. |
| `terrain/scenes/terrain_lab.gd:11` | `PoissonSamplerClass` | Unused preload — the sole reason `poisson_sampler.gd` isn't orphaned on disk. |
| `tests/test_flat_damage.gd:33` | `HP_BANDS` | Test-local, unused. |
| `tests/test_nav_path.gd:23` | `HUT_HALF_EXTENT` | Test-local, unused. |
| `tools/probe_silhouette.gd:17` | `MAX_BODY_PARTS` | Tool-local, unused. |

### 3B. `@export` never referenced (9)

Exports are settable in the Inspector, so an unreferenced export is a **dial that does nothing** — a designer can turn it and see no effect.

| file:line | export |
|---|---|
| `data/vietnam/vietnam_unit_data.gd:18` | `run_speed` (dead file) |
| `data/vietnam/vietnam_unit_data.gd:20` | `rotation_speed` (dead file) |
| `data/vietnam/vietnam_unit_data.gd:27` | `armor` (dead file) |
| `data/vietnam/vietnam_unit_data.gd:37` | `max_ammo` (dead file) |
| `data/vietnam/vietnam_unit_data.gd:38` | `ammo_consumption_rate` (dead file) |
| `data/vietnam/vietnam_unit_data.gd:54` | `reinforcement_cost` (dead file) |
| `scripts/vehicles/landing_zone.gd:8` | **`lz_name`** — live file. LZs can be named; the name is never read or displayed. |
| `terrain/vegetation/jungle_patch_layer.gd:75` | **`tile_jitter`** — live file. A vegetation tiling knob that is never applied. |

### 3C. Member vars never read (11)

| file:line | var | note |
|---|---|---|
| `scripts/enemies/enemy_base.gd:38` | **`last_think_time`** | The companion to `MAX_THINK_TIME`. Never assigned, never read — **the AI think-budget feature is a const + a var and zero lines of logic.** |
| `scripts/missions/mission_director.gd:163` | `cas_budget` | Declared `int = 0`, never incremented, never checked. CAS strikes are not budget-limited despite the field. |
| `scripts/allies/ally_base.gd:101` | `max_follow_distance` | Allies have no follow-distance cap in practice. |
| `scripts/player/weapon_holder.gd:120` | `ray_origin` | Vestigial. |
| `scripts/player/weapon_holder.gd:121` | `ray_end` | Vestigial. |
| `terrain/core/heightmap_storage.gd:21` | `is_generating` | Threading state never consulted. |
| `terrain/core/heightmap_storage.gd:22` | `generation_thread` | `Thread` declared, never started — pairs with the never-emitted `generation_complete` signal. **Async heightmap generation was designed and never built.** |
| `terrain/vegetation/billboard_vegetation.gd:35` | `_tree_materials` | Never populated/read. |
| `terrain/vegetation/billboard_vegetation.gd:36` | `_bush_material` | Never populated/read. |
| `terrain/water/river_generator.gd:45` | `num_rivers` | Declared `= 8`, never read — river count is not actually controlled by this. |
| `tools/probe_silhouette.gd:19` | `_violations` | Tool-local. |

---

## 4. KNOWN LEAD — `MAX_THINK_TIME` (and what's next to it)

### VERDICT: **CONFIRMED DEAD.** The charter is correct.

`scripts/enemies/enemy_base.gd:236`
```
const MAX_THINK_TIME: float = 0.2  # Cap think time (like Quake 3's 200ms)
```

Repo-wide search for `MAX_THINK_TIME` returns **exactly one code hit** — the declaration itself. Every other occurrence (13 of them) is prose in `production/*.md` war-room documents *complaining that it is unused*. No `if`, no comparison, no clamp, no accumulator.

Worse, the feature is **doubly stubbed**: its companion state variable `last_think_time` (`enemy_base.gd:38`) is **also never assigned and never read**. There is no think-time measurement at all — the const has nothing to cap. The AI frame budget is not "declared but unwired"; it is **entirely unimplemented**, and the const is the only evidence anyone intended it.

### OTHERS LIKE IT — the same pattern (a documented dial with no wire)

I found **three more**, and two are more consequential than `MAX_THINK_TIME`:

**#1 — `WorldConfig` perf escape hatch is inert. (HIGHEST IMPACT)**

`scripts/levels/world_config.gd:1-3` states the project's emergency perf plan:
```
## NS04 perf-gate fallback ladder: if FPS < 30 sustained ->
##   1) VEGETATION_DENSITY_MULT 0.6   2) MAP_SIZE 1024 + BILLBOARD_DISTANCE_MULT 0.7
```
Both named dials are **dead**:
- `world_config.gd:14` `VEGETATION_DENSITY_MULT` — **zero reads**
- `world_config.gd:15` `BILLBOARD_DISTANCE_MULT` — **zero reads**

Every *other* `WorldConfig` const is properly wired (`MAP_SIZE`, `CHUNK_SIZE`, `CELL_SIZE`, `LOAD_DISTANCE`, `UNLOAD_DISTANCE`, `SEA_LEVEL`, `OCEAN_EDGES`, `LOG_FPS`, `FPS_LOG_INTERVAL`, `NAV_ENABLED`, `NAV_SITE_KINDS`). Exactly the two emergency rungs are the dead ones.

**Consequence:** the project is FPS-gated (war-room docs cite a 19–25 FPS baseline, with the GATE held closed partly on perf). If someone follows the documented ladder and sets `VEGETATION_DENSITY_MULT = 0.6`, **nothing will happen.** Rung 1 of the perf fallback ladder is a no-op, and half of rung 2 is too (`MAP_SIZE` works; `BILLBOARD_DISTANCE_MULT` does not). This is the same class of defect as `MAX_THINK_TIME` but sitting on the critical path of the perf gate.

**#2 — `ALERT_RANGE` / `AGGRO_RANGE` (`enemy_base.gd:234-235`)** — dead consts in the *same block* as `MAX_THINK_TIME`. These were genuinely superseded (the code moved to data-driven `enemy_data.alert_range`, per the comment at `:290`), so they are cleanup debris rather than an unbuilt feature — but they are three lines below the known lead and nobody noticed.

**#3 — `heightmap_storage.gd` async generation** — `generation_thread: Thread` (`:22`), `is_generating: bool` (`:21`), and `signal generation_complete` (`:6`) form a complete threading contract that is never started, never set, and never emitted. Designed, never built.

---

## 5. UNREACHABLE / STRANDED CODE

### 5A. Code after an unconditional `return` — 1 site, ~55 lines

**`scripts/ui/screens/mission_select.gd:17`**
```gdscript
func roll_offers(rng: RandomNumberGenerator) -> void:
	# Single source of truth: the same roll the HQ-tent board uses.
	offers = MissionOffers.roll(rng)
	return                      # <-- line 17

	var types := [...]          # <-- line 19: UNREACHABLE from here
	...                         #     through line ~73
```
Lines **19–73** (up to the next declaration at `:68`/next func at `:75`) are unreachable: the full legacy offer-rolling implementation — a Fisher–Yates shuffle, seed derivation, and offer-dictionary construction — including its detailed bug-fix comments (R88 seed unification, the `Array.shuffle()` global-RNG determinism fix). The logic was correctly relocated to `MissionOffers.roll()`, but the old body was left in place behind an early `return` instead of being deleted. **This is the only genuine unreachable-statement block in the codebase.**

### 5B. Permanently-true condition — 1 site

**`terrain/core/gameplay_grid.gd:618`** — `if true:`

This is a **scar from a real bug fix**, and the comment immediately above it (`:614-617`) explains it:
> *"Re-sample vegetation. THIS BODY HAS NEVER RUN until today - the guard it used to sit behind tested for a method that does not exist, so every stamp_lz() / stamp_firebase() / stamp_outpost() emitted grid_updated and changed nothing at all."*

**Verified:** the old guard tested `clearing_system.has_method("get_density_at")`, and I confirmed `get_density_at` **does not exist anywhere in the repo** (only in comments describing the bug). The permanently-false guard was neutralized by replacing it with `if true:` rather than removing the conditional. The body now runs. It is **not dead code** — but it is a vestigial always-true branch and a pointless indentation level, and it is the visible half of a bug whose *other* half (`mark_cleared`, §1D) was never fixed.

### 5C. Commented-out code blocks — **NONE**

I scanned all 219 `.gd` files for runs of ≥4 consecutive comment lines matching code shapes (`# var`, `# if`, `# func`, `# return`, assignments, calls). **Zero hits.** The codebase's comments are genuine prose documentation, often extensive. On this axis the project is clean — there is no commented-out-code rot.

### 5D. Stub functions (bodies that are only `pass`/`return`)

Benign, listed for completeness: `projectile_pool.gd:17 _ready`, `equipment_manager.gd:29 _ready`, `engineering_system.gd:112 _ready` (empty lifecycle overrides), and `tests/test_seat_system.gd:21/:27` (test doubles).

---

## 6. DUPLICATED LOGIC

### 6A. FOUR competing `DamageType` enums

| file:line | enum | status |
|---|---|---|
| `scripts/autoload/enums.gd:6` | `DamageType {PHYSICAL, EXPLOSIVE, FIRE}` | **The live one** — 187 `Enums.` references |
| `data/vietnam/game_enums.gd:406` | `DamageType` | GameEnums autoload; this member is never used (only `UnitType`/`FearType`/`WeaponClass`/`Faction` are) |
| `data/vietnam/vietnam_weapon_data.gd:27` | `DamageType` | In a fully dead file |
| `terrain/systems/damage_system.gd:8` | `DamageType {…SMALL_EXPLOSION…}` | **Legitimately different domain** (terrain cratering, not entity damage). Not a duplicate — ruled out. |

Three entity-damage enums, one used. And **three copies of `get_damage_type_name()`** — `scripts/autoload/enums.gd:71`, `data/vietnam/vietnam_weapon_data.gd:967`, plus `game_enums.gd`'s faction/cover helpers — **all three are dead** (§1B, §1G). Nobody names a damage type anywhere.

Similarly **two copies of `get_damage_string()`** — `scripts/combat/projectile_data.gd:66` and `scripts/weapons/weapon_data.gd:131` — **both dead.**

### 6B. The `scripts/` ↔ `terrain/` seam: the damage path forks

This is the seam the charge asked about, and it is real:

- **Entity damage** (`scripts/`): `bullet_system.gd:141` → `target.take_damage(...)` **directly**.
- **Entity damage, the other way** (`scripts/`): `CombatManager.apply_bullet_damage:76` → `target.take_damage(...)` + knockback + `damage_dealt`/`entity_killed` signals. **Dead — zero callers (§1C).**
- **Terrain damage** (`terrain/`): `DamageSystem.apply_damage(...)` — live, called from `claymore.gd:59`, `grenade.gd:117`, `projectile_base.gd:376`.

So there are **two entity-damage funnels and one is abandoned**. Explosions are worse: `CombatManager.apply_explosion_damage:133` (live) and `DamageSystem.apply_damage` (live) are called *back-to-back* from the same sites (`grenade.gd:106` then `:117`) — that's correct layering (entities vs terrain), not duplication. But `apply_bullet_damage` is a genuine orphaned twin of the `bullet_system` path, and it is the reason two CombatManager signals can never fire.

### 6C. Two D8 flow-accumulation implementations (`terrain/water/`)

| file:line | func |
|---|---|
| `terrain/water/hydrology_map.gd:284` | `_compute_flow_accumulation()` — operates on member state (`_flow`, `_accum`, `_hsize`), uses `DIR8` |
| `terrain/water/river_generator.gd:247` | `_compute_flow_accumulation(flow_dir, map_size) -> PackedFloat32Array` — parameterized, uses `DIR_OFFSETS` |

Same algorithm (Kahn's topological-order flow accumulation over a D8 grid, `fill(1.0)` seed, in-degree counting), two independent implementations with two different direction-offset constants. **Both are live and both run during world generation** — `terrain_manager.gd:445` constructs `RiverGenerator`; `water_system.gd:91` constructs `HydrologyMap`. The map pays for flow accumulation twice, with two chances to diverge.

Related: `river_generator.extract_rivers:174` / `_trace_river_paths:298` / `paths_to_cells:396` are **dead** (§1E) — suggesting river extraction migrated to `HydrologyMap` and the `RiverGenerator` half was only partly retired.

### 6D. Duplicate `get_normal_at` — both dead

`terrain/core/terrain_engine.gd:701` and `terrain/core/terrain_manager.gd:349`. Two implementations of the same surface-normal query; **neither has any caller.**

### 6E. `_load_initial_chunks` vs `_load_initial_chunks_async`

`terrain/core/terrain_manager.gd:199` (sync, **dead**) vs `:209` (async, live — awaited at `:165`). Classic superseded twin.

### 6F. `ally_base.gd` ↔ `enemy_base.gd` — parallel AI (noted, NOT flagged)

Eight function names appear in both with similar roles: `_execute`, `_execute_idle`, `_find_cover_point`, `get_muzzle_position`, `get_muzzle_visual`, `_update_unstick`, `apply_wound`, `is_dead`. This is a substantial parallel-implementation surface (two AI brains that don't share a base class). I am **not** calling it dead code — both are live and the bodies differ — but it is the largest *behavioral* duplication in `scripts/` and a natural home for future divergence bugs. Flagging for awareness only; out of scope for this audit.

---

## 7. FALSE POSITIVES I RULED OUT

Showing the work. Each of these *looked* dead to a naive grep and is **not**.

| Candidate | Count | Why it is NOT dead |
|---|---|---|
| **`_initialize()` in `tools/*.gd`** | **17** | `tools/probe_config.gd`, `dump_mesh_names.gd`, `probe_ballistics.gd`, `probe_anim_audit.gd`, `probe_civilian.gd`, `probe_drift_scale.gd`, `probe_hitbox_coverage.gd`, `probe_hitzone_fit.gd`, `probe_hurtbox_size.gd`, `probe_lying_height.gd`, `probe_physics_ab.gd`, `probe_render_height.gd`, `probe_rig_compare.gd`, `probe_silhouette.gd`, `probe_worn_gear.gd`, `probe_zone_shapes.gd`, `dump_viewmodel_nodes.gd`. **Verified `extends SceneTree`** — `_initialize()` is the `MainLoop` engine virtual and is the *entry point* for `godot --headless --script`. Called by the engine, invisible to grep. |
| **`_process_modification()`** | 1 | `scripts/visuals/severed_bones_modifier.gd:20`. **Verified `extends SkeletonModifier3D` (`:10`)** — this is the engine virtual the whole class exists to override. It is the hottest path in the dismemberment system. |
| **All `_on_*` handlers connected in `.tscn`** | many | e.g. `hud.gd:287 _on_restart_pressed` ← `scenes/ui/hud.tscn:271`. I parsed `[connection signal="…" method="…"]` out of every `.tscn` and treated those methods as roots. |
| **`noise_emitted` signal** | 1 | My **first** connect-detection regex had a lookbehind bug that wrongly excluded `a.b.connect(...)` and reported ~all 142 signals as unconnected. I caught it, rewrote the matcher, and re-ran. `NoiseBus.noise_emitted` **is** connected — `enemy_base.gd:318` and `mission_trigger.gd:66`. **Every signal finding in §2 is from the corrected pass and was additionally spot-verified by direct grep.** |
| **HUD-connected signals** | ~20 | `health_changed`, `health_pack_changed`, `died`, `healing_*`, `bleeding_*`, `magazine_changed`, `weapon_switched`, `weapon_jammed`, `reload_started/progress`, `switch_started/progress`, `slot_changed`, `grenade_count_changed`, `target_hit` — all genuinely connected at `scripts/ui/hud.gd:63-97`. Not dead. (Note `hud.gd:89`'s own comment — *"R09 emitted this into the void"* — shows this class of bug has been hunted before.) |
| **`gun_fx.play_shot_3d` / `play_explosion_3d`** | 2 | Look like duplicates of `AudioManager`'s. **They are an intentional, documented facade** — `gun_fx.gd:77` body is literally `AudioManager.play_shot_3d(pos, data, volume_db)`, with a comment saying so. Thin delegate, not duplicated logic. |
| **`while true:` loops** | 3 | `weapon_holder.gd:615`, `hydrology_map.gd:225`/`:487`, `river_generator.gd:354`. Flagged by my constant-condition scan; all are **legitimate loop-with-`break`** idioms, not unreachable-code markers. |
| **`terrain/systems/damage_system.gd:8 enum DamageType`** | 1 | Looks like a 4th duplicate. It is a **different domain** — terrain cratering types (`SMALL_EXPLOSION`, etc.), not entity damage types. Correctly separate. |
| **`get_flow_at` via `has_method`** | 2 | `water_system.gd:492` / `water_body_data.gd:116` are reached through a **dynamic** `has_method("get_flow_at")` call at `gameplay_grid.gd:521` — exactly the kind of indirection static analysis misses. I chased it: the *only* caller of that guard is `gameplay_grid.get_water_flow:520`, which **itself has zero callers**. So the chain is transitively dead after all. **Kept in the dead list, but only after verifying the dynamic path.** |
| **All `has_method()` / `call()` / `call_deferred()` string names** | 47 | I enumerated every string-dispatched method name in the repo (`take_damage`, `apply_damage`, `clear_area`, `can_revive`, `is_dead`, `on_zone_hit`, `sequence_*`, `report_contact`, `refresh_after_load`, …) and cross-checked the full dead list against it. **No function in this report is reachable via string dispatch**, except the `get_flow_at` case above, which I resolved explicitly. |
| **`_on_regenerate_pressed`** | 1 | Tempting to rule out as "connected in a `.tscn`". It is **not**: `terrain_lab.tscn:410` wires `pressed` → method **`_on_regenerate`** (different name), on the scene root. `_on_regenerate_pressed` at `terrain_lab_ui.gd:222` is genuinely orphaned. **Kept as dead.** |
| **`tests/` and `tools/` entry points** | all | `.tscn`-backed test scenes and `SceneTree` probes are launched by CLI, not by game code. Treated as roots; their internals are live. Nothing in `tests/` is reported as dead except three unused local constants (§3A). |
| **`PondDetector`** | — | Almost ruled the whole file live because `water_system.gd:203` instantiates it. But it only uses `cells_to_polygon` / `simplify_polygon` / the `Depression` inner class. The **detection algorithm** (`detect_depressions:47` and its 3 helpers) is dead. Partial-file deadness, correctly split. |

---

## APPENDIX — CONFIDENCE

**High confidence (mechanically verified, zero references of any kind):** the 3 fully dead files, all 52 dead signals, `MAX_THINK_TIME` + `last_think_time`, the two `WorldConfig` perf dials, `CombatManager.apply_bullet_damage`, `GameplayGrid.mark_cleared`, and the `mission_select.gd:17` unreachable block. These were each confirmed by direct repo-wide grep after the automated pass.

**Medium confidence:** the long tail of unused accessors (§1G). Each has zero static callers and is not a string-dispatch target, so they are unreachable *today* — but many are plainly intended as public API for HUD/UI work that hasn't landed. They are dead, not necessarily *wrong*.

**Deliberately excluded:** Godot lifecycle virtuals, `SceneTree`/`MainLoop` virtuals, `SkeletonModifier3D` virtuals, `.tscn`-connected handlers, `.tres`-referenced classes, and `tests/`+`tools/` entry points.
