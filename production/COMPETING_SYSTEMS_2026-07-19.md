# COMPETING SYSTEMS AUDIT — 2026-07-19

**Status:** DECISION SHEET. Read-only audit. Nothing was changed, deleted, or beaded.
**Method:** 5 parallel read-only code hunters + Overseer verification. Code was the authority;
where a document or a bead disagreed with the code, the code won (three times, below).
**Owner's ruling required.** Each group ends with a RECOMMENDATION, not an action taken.

**26 competing groups found.** Ranked by *how much wrong work each would cause*, not by size.

> ## CORRECTION BANNER — re-measured 2026-07-19, later the same day
>
> **This is a correction, not a rewrite. The remaining 22 groups still stand and the Summoner has ruled
> on none of them.** Four entries were fixed in the hours after the audit was written and are now
> **CLOSED — do not act on them:**
>
> | Entry | Status now | Pointer |
> |---|---|---|
> | `height_scale` split authority | **CLOSED** — all readers on `TerrainConfig.WORLD_HEIGHT_MAX` | `terrain/core/heightmap_storage.gd:12,19` · `terrain/core/terrain_chunk.gd:15,44` · `scripts/levels/game_world.gd:128` |
> | Night authority | **CLOSED** — one authority | `scripts/world/mission_weather.gd:53,93` |
> | `TerrainEngine` duplicate height | **CLOSED** — it no longer declares `get_height_at`; the only real one is `terrain/core/terrain_manager.gd:267` (the other hit is a local test stub, `scripts/levels/ai_stress_arena.gd:16`) | grep `func get_height_at`, 2 hits |
> | **THE META-FINDING below** (the fossil-probe mutual alibi) | **CLOSED** — `_judge()` now subtracts declarations from occurrences, so N competing dead implementations can no longer vouch for each other | `tests/test_fossils.gd:272-277` |
>
> The meta-finding's *diagnosis* remains the best explanation of how the blind spot formed — read it as
> history, not as a live defect.

---

## THE META-FINDING: why the fossil probe cannot see any of this

`tests/test_fossils.gd:256-258` — `_judge()` decides a symbol is dead when
`freq[sym] <= 1`, where `freq` is a **repo-wide count keyed on the bare symbol name**.

> When two files each define `get_height_at`, each declaration counts as the other's
> reference. `freq == 2`. **Neither is ever flagged.**

**Competing implementations mutually alibi each other.** The probe is not merely blind to this
class — it is *inverted* by it: the more duplicates of a name exist, the safer every one of them
looks. This is the structural reason the divergent-systems blindspot survived 124 grandfathered
fossils and a ratcheting gate.

The same mechanism hides: `_determine_terrain_type`, `take_damage`, `_die`, `is_dead`,
`get_normal_at`, `modify_region`, `is_water`, `get_water_depth`, `has_line_of_sight`,
`register_player`, `get_damage`, `setup` (20 definitions).

**A detector that WOULD see it** (run against `scripts/ terrain/ data/`): report every `func` name
defined in 2+ files, minus Godot virtuals. That one query produced most of this document.

---

# TIER 1 — CANON ACTIVELY POINTS THE WRONG WAY

These are worst because the *documentation instructs the mistake*.

## 1. `sprite_state_map.gd` — ADR-001 tells you to delete the live animation spine
**Job:** map AI state → animation intent → clip name.

- `scripts/visuals/sprite_state_map.gd` — `intent_for()` :32, `MODEL_ALIASES` :153,
  `model_clip_for()` :179, `clip_for()` :199.
- **LIVE, and load-bearing for the entire cast.** Callers: `enemy_base.gd:344,405,429,2259,2334,2398,2429`;
  `ally_base.gd:227,336,349,1032`; `model_actor.gd:691,726` defers to `MODEL_ALIASES` rather than
  keeping its own table.
- **ADR-001 declares the sprite renderer DEAD.** The filename says `sprite`. The class says
  `SpriteStateMap`. Every instinct — and the fossil law itself — says delete it.
- **Concrete failure:** deleting it per ADR-001 breaks animation for *every enemy and ally in the
  game*. It was repurposed into the live 3D intent→clip resolver and never renamed.
- Compounding: `enemy_base.gd:226` / `ally_base.gd:186` declare `var sprite_actor` which holds a
  **ModelActor** (83 occurrences). The variable name is a fossil of the killed renderer.
- Also: `SpriteActor` the class **no longer exists on disk**. ADR-001's stated fallback chain
  "ModelActor → SpriteActor → capsule" is stale; real chain is ModelActor → `CapsuleMesh`
  (`enemy_base.gd:348-359`).

**RECOMMENDATION: RENAME, do not retire.** `sprite_state_map.gd` → `actor_clip_map.gd`,
`SpriteStateMap` → `ActorClipMap`, `sprite_actor` → `model_actor`. Then amend ADR-001 with an
explicit carve-out naming this file as surviving and why. **OWNER DECISION** — this is a
wide mechanical rename across two 1000+ line files and touches ADR canon.

## 2. `GameEnums` vs `Enums` — same enum name, different integers, both resident
**Job:** define shared enums.

- `scripts/autoload/enums.gd:2` — `class_name Enums`. **LIVE**: 178 `Enums.` references.
  `DamageType { PHYSICAL=0, EXPLOSIVE=1, FIRE=2 }` (:6-10).
- `data/vietnam/game_enums.gd` — **registered as an autoload**, `project.godot:32`
  (`GameEnums="*res://data/vietnam/game_enums.gd"`). 722 lines.
  `DamageType { SMALL_ARMS=0, HEAVY_MG=1, EXPLOSIVE=2, ... }` (:406-414).
- 92 `GameEnums` references exist — but every one resolves to `game_enums.gd` itself or to
  `vietnam_unit_data.gd` / `vietnam_weapon_data.gd`, **both of which are dead** (group 3).
  So the autoload is parsed into memory every boot and consumed by nothing live.

**`EXPLOSIVE` is 1 in `Enums` and 2 in `GameEnums`.** Same name. Different integer. Both loaded.

- **Concrete failure:** an agent sees `GameEnums` in the autoload list, reasonably concludes it is
  canonical, and wires new code to `GameEnums.DamageType.EXPLOSIVE` (=2). Downstream
  `take_damage`/hitzone code expects `Enums.DamageType.EXPLOSIVE` (=1). **Silent wrong branch —
  no crash, no error, wrong damage type forever.** This is the single most dangerous latent item
  in the audit.

**RECOMMENDATION: RETIRE `GameEnums`** — remove the autoload line and delete
`data/vietnam/game_enums.gd`, together with group 3. If any constant in it is wanted, port it into
`Enums` deliberately. **OWNER DECISION** on whether the 722 lines contain anything worth keeping.

## 3. `data/vietnam/` — 1,414 lines of dead data tables carrying WRONG canon values
**Job:** weapon and unit stat tables.

- `data/vietnam/vietnam_weapon_data.gd` (994 lines, `class_name VietnamWeaponData`) —
  **:266 declares `m79.damage = 80.0`.** Canon (ADR-016) is 150.
- `data/vietnam/vietnam_unit_data.gd` (420 lines, `class_name VietnamUnitData`).
- **Both DEAD, verified past the zero-grep-hit rule:** no `.tscn`/`.tres` carries
  `script_class="VietnamWeaponData"`; no `load()`/`preload()` of the paths anywhere; not autoloaded;
  no `.new()` call. Their only references are each other and `game_enums.gd`.
- **THE LIVE TABLE:** `data/weapons/*.tres` (15 files) + `scripts/weapons/weapon_data.gd`.
  Proof: `weapon_holder.gd:123-124` `load("res://data/weapons/m16a1.tres")`;
  `bullet_system.gd:136-147` calls `wd.get_damage()` / `wd.damage_multiplier_at(dist)`.
  `data/weapons/m79.tres:14` → `base_damage = 150`. ✅ canon.
- No third hardcoded table: swept `weapon_holder`, `enemy_base`, `bullet_system`, `gun_fx`,
  `ai_marksmanship` for damage/rpm/range literals — none.
- Unit equivalent: `data/enemies/*.tres` + `scripts/enemies/enemy_data.gd` is live
  (`enemy_base.gd:2464 spawn_enemy`).

- **Concrete failure:** an agent told "the M79 does too much damage" finds the 994-line file with a
  `class_name`, edits `80.0`, tests, sees no change, and edits harder.

**RECOMMENDATION: RETIRE the whole `data/vietnam/` folder** (all three files, with group 2).
`data/weapons/*.tres` and `weapon_data.gd` are PROTECTED and untouched by this.
**Note:** the folder contains `game_enums.gd` which IS autoloaded — retiring is a 3-file atomic
change, not a folder delete. **OWNER DECISION.**

---

# TIER 2 — TWO LIVE SYSTEMS, BOTH RUNNING, SILENTLY FIGHTING

## 4. Two HUDs instantiated simultaneously in the live mission
**Job:** draw player status.

- `scripts/ui/hud.gd` + `scenes/ui/hud.tscn` — instantiated unconditionally by
  `game_world.gd:404-411 _setup_hud()`, called from `spawn_player_at()` (:330-340).
- `scripts/ui/mission_hud.gd` — instantiated by `game_flow.gd:307-310`, `MissionHUD.new()`.
- **Both are live siblings under `world` in the real mission path.** `game_flow.gd:294-296` even
  acknowledges the first (`world.hud.managed_by_flow = true`) then builds the second 12 lines later.
- **Proven overlap:** `hud.gd:12-13` `grenade_label`/`medkit_label` vs
  `mission_hud.gd:136-140 _show_slot_slider()` which independently reads `equip.grenade_count`
  and `hs.health_packs`. **Same data, two independent read sites, both on screen.**
- `recon_ui.gd` is NOT a third HUD — it is a styling helper library. `topo_map.gd` and
  `squad_nameplate.gd` are owned solely by `mission_hud.gd`. No minimap survives in the game
  (`tests/test_world_minimap.gd` is self-declared test-only) — ADR-021/022 upheld.
- **Concrete failure:** fix the grenade counter in one, the other still shows the stale number.

**RECOMMENDATION: MERGE — one HUD.** Prior independent audit already called this
(`production/war_room/analysis/ux_designer.md:141-142`: "hud.tscn is the scene-built HoD-legacy
HUD… everything newer is code-built"). Likely direction: fold `hud.gd`'s HP/ammo/weapon rows into
`MissionHUD` and retire `hud.tscn`. **Blocked-by:** bead `gryl` (HUD decree remnants) and `r4bk`
law — do not front-run. **OWNER DECISION on which HUD survives.**

## 5. `WeatherDirector` vs `MissionWeather` — two live appliers racing on one `WorldEnvironment`
**Job:** apply weather/time-of-day.

- `scripts/world/weather_director.gd` — built at `mission_generator.gd:221-225` (inside
  `build_patrol_world`). Sets fog on `world/WorldEnvironment`. **Self-subscribes to
  `SimClock.day_advanced`** (:21-25) and re-rolls from its own 4-entry `WEATHER_TABLE` (:9-14)
  every sim-day.
- `scripts/world/mission_weather.gd` — built at `game_flow.gd:311-313`, i.e. **after**
  `build_patrol_world` returns. Stamps the **same** `WorldEnvironment` — and additionally owns the
  statics gameplay actually reads: `sight_mult` (:53, read `enemy_base.gd:692`),
  `NoiseBus.radius_multiplier` (:54), `is_night` (:55), `rain_active` (:84, read
  `weapon_holder.gd:348`). **`WeatherDirector` touches none of these.**
- `MissionWeather` has **zero SimClock subscription** — verified, no `day_advanced` hookup.
- **Concrete failure, two directions:**
  1. Tuning `WeatherDirector._apply()` produces **zero visible effect** — `MissionWeather`
     always runs later and re-stamps the same Environment.
  2. On day rollover, `WeatherDirector` silently re-fogs the world while `sight_mult`,
     `is_night`, `rain_active` and noise radius stay frozen at mission-start values. **Fog says
     RAIN; AI sight, noise and rain-VFX say CLEAR.** A visual telegraph that disagrees with the
     sim is a Fairness-Law problem, not a cosmetic one.

**RECOMMENDATION: MERGE into `MissionWeather`** (it owns the gameplay statics), giving it the
`day_advanced` subscription and `WeatherDirector`'s roll table; then retire `weather_director.gd`.
**OWNER DECISION** — needs a ruling on whether multi-day weather re-rolling is wanted at all.

## 6. Two night authorities, and the live one is frozen
**Job:** answer "is it night?"

- `scripts/autoload/sim_clock.gd:9,60-67` — `Period { DAWN, DAY, DUSK, NIGHT }`, `period_at(hour)`,
  signal `time_period_changed`. **Advances correctly with sim time.**
  **`time_period_changed` and `period_at` have ZERO consumers repo-wide.** Verified.
- `scripts/world/mission_weather.gd:10` — `static var is_night`, set **once** at
  `setup()` (:55) and never updated.
- **`is_night` is what the game actually reads:** `bullet_system.gd:218` and
  `bullet_tracer.gd:37` set tracer emission `4.5 if is_night else 2.0`; `game_flow.gd:314` gates
  night ambience.
- **Concrete failure:** a patrol that starts at 16:00 and runs into darkness keeps daylight tracer
  brightness and daytime ambience forever, because nothing connects SimClock's night to
  `MissionWeather.is_night`. Tracers are a Fairness-Law telegraph (ADR-005 family) — they are
  supposed to read correctly at night.
- Aggravating: `ai_stress_arena.gd:376,1537` **writes the global static** (`MissionWeather.is_night = true/false`),
  leaking bench state into a global consumed by the game.

**RECOMMENDATION: MERGE — SimClock becomes the sole night authority**, `is_night` becomes a
derived read of `SimClock.period_at()`. **SimClock is PROTECTED — do not modify it**; wire
`MissionWeather` to *subscribe*, do not touch the clock. **Blocked-by:** brushes Wave B (`nohh`).
**OWNER DECISION.**

## 7. `height_scale` — one number, four copies, two live bugs
**Job:** the world's vertical scale contract.

| Site | Value |
|---|---|
| `terrain/core/terrain_manager.gd:22` `WORLD_HEIGHT_MAX` | **350.0** ← intended truth |
| `terrain/core/terrain_manager.gd:23` `@export height_scale` "(legacy)" | **280.0** |
| `terrain/shaders/terrain.gdshader:23` uniform default | **280.0** |
| `terrain/core/terrain_chunk.gd:159` hardcoded, comment "Match TerrainManager.WORLD_HEIGHT_MAX" | **350.0** |

**LIVE BUG A — riverbeds carve 25% too deep.**
`terrain_manager.gd:464` `_carve_riverbed`: `depth_normalized = (carve_depth_meters * falloff) / height_scale`
uses the **legacy 280.0**, while the heightmap decodes at 350.0
(`heightmap_storage.gd:64`, set from `WORLD_HEIGHT_MAX` at `terrain_manager.gd:115`).
Intended 1.8 m → actual **2.25 m**.

**LIVE BUG B — terrain texture banding computed against the wrong world height.**
`terrain.gdshader:71` `height_factor = clamp(world_pos.y / height_scale, 0.0, 1.0)`.
Write order verified: `game_world.gd:125-130` sets 280 → `terrain_manager.gd:118` sets 350 during
generation → **`game_world.gd:356` `params["height_scale"] = terrain_manager.height_scale` (280) runs
LAST**, inside `_setup_terrain_shader_textures()`, called at `_on_terrain_ready()` step 2
(`game_world.gd:142`). **280 wins.** Everything above 280 m on a 350 m world clamps to `1.0` —
the top 20% of terrain renders as one flat texture band. A Pillar-2 look bug with a numeric cause.
- `game_world.gd:125-130` additionally hardcodes `terrain_size: 385` and `cell_size: 4.0`,
  competing with `TerrainManager`'s real values.

**RECOMMENDATION: MERGE to one constant.** Delete the legacy `@export height_scale`, point
`_carve_riverbed` and the `game_world` shader params at `WORLD_HEIGHT_MAX`, make the shader
uniform default match. **This is a bug fix, GATE-exempt.** Note the carve change alters terrain
output → **ADR-010 determinism**: existing seeds will produce different riverbeds. **OWNER DECISION**
on accepting the seed shift.

## 8. `LocationPlanner` vs `SitePlanner` — a complete, orphaned, undisclosed alternate pipeline
**Job:** choose where villages / firebase / camps go.

- `scripts/world/site_planner.gd` (602 lines, `class_name SitePlanner`) — **LIVE.**
  `mission_generator.gd:420,539`. Chooses positions dynamically against already-generated
  terrain/water/grid.
- `scripts/world/location_planner.gd` (150 lines, `class_name LocationPlanner`) — **ORPHANED.**
  Its only caller repo-wide is `tests/test_world_alive.gd:23,64-75`. A complete independent
  algorithm: own RNG stream (`mission_seed + 31337`), ring layout (villages 350-500 m, camps
  600-800 m), own `VillageSize` enum, and an `apply_lifts()` that **physically raises the
  heightmap** and expects the water system re-run afterward — a fundamentally different pipeline
  *order* than the game uses.
- **Why this is dangerous rather than merely dead:** `test_world_alive.gd:15` carries the
  disclaimer ("TEST-ONLY… nothing here is wired into the main game"). **`location_planner.gd`
  carries no disclaimer at all** — it reads as clean, well-documented, load-bearing design. It is
  *shorter and better commented* than the live one. An agent asked to "add a new location type"
  and doing a targeted read will pick it.
- `site_layouts.gd`, `working_point_resolver.gd`, `paddy_stamper.gd` — all live, no conflict.

**RECOMMENDATION: RETIRE `location_planner.gd`** and port `test_world_alive.gd` onto
`MissionGenerator`, or — if that test's location-first pipeline has value — move the file under
`tests/` where its status is self-evident. **OWNER DECISION** on which. Minimum viable fix if
retirement is refused: a header disclaimer.

## 9. `TerrainEngine.get_height_at` — an always-resident autoload holding a frozen pre-edit snapshot
**Job:** answer "how high is the ground here?"

Every height answer in the game, mapped:

| Implementation | Status |
|---|---|
| `heightmap_storage.gd:61 sample_world()` | **THE TRUTH** — backing array |
| `terrain_manager.gd:288 get_height_at()` | **LIVE** — pure passthrough; ~30 gameplay callers |
| `gameplay_grid.gd:334 get_elevation()` | legitimate O(1) cache, rebuilt via `region_rebuilt` |
| `terrain_engine.gd:663 get_height_at()` | **ZERO game callers** — a second, independent bilinear sampler over its own `heightmap_data` |
| `ai_stress_arena.gd:16` stub / `:26` `FlatHeightmap` | bench-only, always returns `0.0` |
| `game_world.gd get_ground_height` | already grandfathered in `fossil_baseline.json` |

**The mechanism that makes `TerrainEngine` a landmine:** `terrain_manager.gd:112` does
`heightmap.data = terrain_generator.heightmap_data.duplicate()` — **a one-time copy.** From then
on every edit (FSB R=215 flatten, village discs, craters) lands in `HeightmapStorage` only.
`TerrainEngine.heightmap_data` is a **frozen pre-edit snapshot that still answers plausibly.**

- `TerrainEngine` is an **autoload** (`project.godot:41`) — globally reachable as
  `TerrainEngine.get_height_at(pos)`, which is exactly what a new agent would type.
- It survives the fossil probe by name-collision with `TerrainManager.get_height_at` (meta-finding).
- **Concrete failure:** anything seated via `TerrainEngine` floats over or sinks under the FSB
  plateau, every village, every crater — a returned value that is confidently, silently wrong.

**RECOMMENDATION: RETIRE `TerrainEngine.get_height_at()` and `get_normal_at()`** (the generation
half of `TerrainEngine` is live and stays — it is called via string dispatch at
`terrain_manager.gd:57` `get_node_or_null("/root/TerrainEngine")`, invisible to grep). This is a
2-function deletion, not a file deletion. `tests/test_terrain_relief_bounds.gd` is the only caller
and is an isolated raw-noise probe. **OWNER DECISION.**

---

# TIER 3 — DUPLICATED LOGIC IN PARALLEL CLASSES

`enemy_base.gd` (2,525 lines) and `ally_base.gd` (1,067 lines) are duck-typed twins with **no
shared base class**. Verified same-name pairs: `take_damage`, `on_zone_hit`, `apply_suppression`,
`get_muzzle_position`, `get_muzzle_visual`, `is_dead`, `_die`, `_think`. Every one is invisible to
the fossil probe by mutual alibi.

## 10. Ally vs enemy perception — different sight models
- `enemy_base.gd:691-698 _sight_cap()` — lerps **140 m open → 45 m jungle** by vegetation density
  × weather × flare light, plus an FOV cone (`_fov_deg()` :723-730) outside COMBAT tier.
- `ally_base.gd:458-479 _find_target()` — **a flat `closest_dist = 60.0`**. No FOV cone. No
  vegetation term. LOS ray only *after* the target is picked by raw distance (:482-501).
- **Concrete failure:** tune `SIGHT_CAP_JUNGLE` to fix a concealment bug and allies are unaffected
  — allies keep engaging through jungle the enemy cannot see the player through. **No test covers
  ally spotting** (`test_witness_rule`, `test_detection`, `probe_witness` all spawn `EnemyBase`
  only), so the drift is silent.
- Good news: the **witness rule (ADR-005) is single-sourced and correct** in `enemy_base.gd`
  (beacon :232, `_set_tier(…, witnessed)` :918-936, `take_damage` passes `false` :2144,
  `_witness_check` :760-787). Allies never touch the beacon, so they cannot violate it.
  ADR-005's own "NOT implemented" status note is **stale** — the bundle shipped
  (`noise_bus.gd:18` GUNSHOT = 150.0 confirms).
- Third variant: `civilian.gd:161-164` informer — 15 m + raw LOS, no cone, no veg. Correctly
  fixed today (proximity-only bug is gone, verified), but it is a third bespoke sight rule.

**RECOMMENDATION: MERGE — but BLOCKED-BY-DECREE.** Wave WA / bead `akx8` `PerceptionServer` owns
exactly this, and its plan already names `ally_base.gd:491` as a migration target. **Do not act.**
Confirmed status: not started, zero files, no `perception_server.gd`. Report only.

## 11. Ally vs enemy damage — allies ignore hit zone entirely
- `enemy_base.gd:2097` `take_damage(amount, type, attacker, zone)` — uses `zone`: HEAD →
  `amount = current_hp + 999` (:2108); GUT → bleed + crippled (:2133).
- `ally_base.gd:974` — signature matches, but parameters are `_attacker` and **`_zone`**:
  underscore-prefixed, **unused**. Allies get no HEAD-fatal, no GUT bleed, no zone logic at all.
- Player: `player.gd:848-865` also takes `_zone` unused, forwards to
  `health_system.take_damage(amount, type, attacker)` — **3 params, no zone**. The x4.0 HEAD
  multiplier is applied upstream in `bullet_system.gd:146`.
- **Verdict: the player's path is DOCUMENTED intent** — ADR-003 scopes HEAD-fatal to enemies, and
  `test_actor_damage_contract.gd:32-34` explicitly exempts `HealthSystem`. Legitimate coexistence.
  **The ally path is not documented anywhere.**

**RECOMMENDATION: OWNER DECISION** — is an ally headshot supposed to be fatal? If yes this is a
bug; if no it should be a comment stating the constraint. Do not "fix" silently either way.

## 12. Hitzone lethality — a formal override system the combat code never consults
- `scripts/combat/hitzone.gd:31-32,92-96` — `fatal_override` (-1 default / 0 forced non-fatal /
  1 forced fatal), read through `is_fatal_zone()`. Documented as ADR-016 Amendment B's mechanism
  "for a future helmeted heavy."
- Authoring path is **fully wired**: `hitzone_builder.gd:519-523` reads
  `data/hitzones/<unit>.tres`; `hitzone_editor.gd:384` (`F` key) toggles it; `:550` displays
  FATAL vs multiplier.
- **`is_fatal_zone()` has ZERO game callers** — only `hitzone_editor.gd:384,550` (bench) and
  `test_hitzones.gd:205,219`. The live kill logic hardcodes a string check instead
  (`enemy_base.gd:2108 if zone == "HEAD"`).
- `data/hitzones/` exists but is empty → **latent, not yet firing.**
- **Concrete failure:** the moment someone authors a helmeted heavy with `fatal_override = 0` —
  the exact use case the feature was built for — **the bench reports "not FATAL" and the game
  kills him anyway.** A lying instrument.

**RECOMMENDATION: MERGE — make `enemy_base.gd:2108` consult `is_fatal_zone()`.** Small, contained.
**Blocked-by:** overlaps bead `7ioa` (P0 "BENCH LIE: viewmodel_editor calibration steers nothing")
— *the same failure pattern, a second instance.* Worth telling the owner these two are one class of
bug: **benches that write values the game never reads.**

## 13. `CombatManager.apply_bullet_damage` — the known fossil, re-confirmed
- `combat_manager.gd:82-106`. **Zero callers**, including no `call("…")` string dispatch.
- Live paths bypass it entirely: `bullet_system.gd:147`, `weapon_holder.gd:635,639` (pellet
  cluster), `projectile_base.gd:304,312` (direct hits) all call `target.take_damage(...)` directly.
- Its embedded `GameManager.on_enemy_killed()` (:104) is therefore also unreachable — so
  `GameManager.enemies_killed`/`total_enemies` are dead too. The live kill counter is
  `MissionState.record_kill()` via `field_director.gd:55`.
- **`apply_explosion_damage` (:138-231) is LIVE and must NOT be swept up with it** — 12 real game
  callers (`grenade.gd:101`, `claymore.gd:58`, `sapper_charge.gd:31`, `projectile_base.gd:359`,
  `field_director.gd:376,459`, `squad_system.gd:321`, `cas_airplane.gd:138,152,172`,
  `helicopter.gd:156`). CLAUDE.md's fossil note damns only the bullet router.

**RECOMMENDATION: RETIRE `apply_bullet_damage` + `GameManager.on_enemy_killed`/`enemies_killed`/
`total_enemies`.** Already-known debt. **Blocked-by:** ADR-023 Amendment A (bead `6n0b`,
"delete the system AND every caller") is still DRAFT awaiting ratification.

**Good news — no competing damage grammar.** ADR-003's dice core is fully purged from code
(`roll_damage`, `dice_count`, `[N,10,0]` — zero hits). ADR-016 flat base × zone is sole law.
`test_flat_damage.gd` is a guard test, not a second implementation. **Note: this Overseer's own
charter still says "RECON dice, no flat modifiers" — that line is stale.** ADR-003's header
already records it as superseded by ADR-016.

---

# TIER 4 — REAL, LOWER BLAST RADIUS

## 14. `ai_stress_arena.gd` — the hand-wired parallel world, still hand-wired
Confirmed still true: own `TerrainManagerStub` (:11-20, height always `0.0`), own `FlatHeightmap`
(:25-30), own `ArenaGrid` GameplayGrid subclass (:39-51), own veg-density hand-stamping
(:556-597) that **never calls `TerrainZoning.classify()`**, own `JunglePatchLayer` driving
(:434-456), own MultiMesh clutter scatter (:475-507). References none of `TerrainManager`,
`VegetationManager`, `WaterSystem`, `MissionGenerator`, `SitePlanner`.
**This is not a violation — ADR-028 Phase 3 has simply not shipped.**
**RECOMMENDATION: NONE. BLOCKED-BY-DECREE** — bead `qjf0` / `b6lr` own it. Report only.

## 15. `DamageSystem` — one singleton, two different terrain backends by scene
`game_world.gd:135` gives it the real `TerrainManager`; `ai_stress_arena.gd:243` gives it a
`terrain_stub` whose `get_height_at` returns `0.0`. The arena never wires `ClearingSystem` at all.
Autoload state is mutated per-scene, last loader wins.
Also: `clearing_system.gd:64` and `damage_system.gd:72` both still comment
"set by terrain_lab" — **`terrain_lab` was deleted.** Tombstone comments pointing at a corpse.
**RECOMMENDATION: KEEP BOTH** (a bench legitimately needs a stub) + **delete the two stale
comments**. Low priority.

## 16. `RiverGenerator` vs `HydrologyMap` — two hydrology algorithms, never reconciled
- `terrain/water/river_generator.gd` via `terrain_manager.gd:407-425` — D8 gradient descent
  (`min_river_length=50`, `base_width=6.0`), then **physically carves the heightmap** (:445-465).
- `terrain/water/hydrology_map.gd` via `water_system.gd:87-121` — a **separate** priority-flood +
  D8 flow-accumulation pass (`creek_threshold=200.0`, different width formula) deciding where
  water actually renders and where `is_water()` returns true.
- Two different algorithms, different parameters, different times, **no reconciliation step**. A
  carved groove with no water in it, or water with no groove, is structurally possible.
- Related name-collision pair: `is_water` / `get_water_depth` defined in **both**
  `gameplay_grid.gd` and `water_system.gd`.
- **Could not determine** how often they actually disagree — needs a runtime comparison probe.

**RECOMMENDATION: OWNER DECISION / needs a probe first.** Do not restructure water on a static
read. A cheap measurement (sample N points, compare carved-groove presence vs `is_water()`) would
settle whether this is theoretical or live.

## 17. `QualitySettings` — a complete, dead, parallel graphics-config authority
`terrain/core/quality_settings.gd` (`class_name QualitySettings`): **zero references repo-wide**,
not autoloaded. Defines `vegetation_density` (MEDIUM=0.5), `load_distance`, `shadow_distance`,
`fog_density` — a full parallel knob set to the LIVE `world_config.gd` (`VEGETATION_DENSITY_MULT`
= 1.0). Different semantics, different values, and they would collide the moment anyone builds a
graphics-options menu and reaches for the file literally named `QualitySettings`.
**RECOMMENDATION: RETIRE** — or, if a settings menu is imminent, MERGE deliberately into
`WorldConfig`. **OWNER DECISION.**
*Correction to CLAUDE.md:* the "`world_config`'s FPS-fallback ladder is read by nothing" line is
**STALE** — 12 of 13 consts now have external readers. Only `VEGETATION_DENSITY_MULT` (:16) is
still unread.

## 18. `WorldSim` — half-live, running a pointless tick forever
`register()` / `clear_if_needed()` ARE called (`mission_generator.gd:189,193`), but
`update_player`, `materialize_near`, `dematerialize_far`, `count_live` have **zero callers**. Its
`_process` (`world_sim.gd:34-38`, 60 s accumulator) advances abstract cells on entities whose
velocity is always `Vector3.ZERO`.
Also: `register` is a name-collision pair with `agent_registry.gd`'s `register`.
**RECOMMENDATION: NONE. BLOCKED-BY-DECREE** — Wave B / bead `nohh` decrees WorldSim tiers die and
B1 = AIDirector. Report only.

## 19. Two `player` registries
`GameManager.register_player` (`game_manager.gd:65`) and `CombatManager.register_player`
(`combat_manager.gd:77`) both store `player`, both called back-to-back from `player.gd:479-480`.
Benign today; divergent if any future path registers one and not the other.
**RECOMMENDATION: KEEP BOTH** (low value to churn) or fold into `AgentRegistry` when Wave B
touches registries. Note only.

## 20. `BillboardVegetation` — deleted from source, still referenced in tests
No `.gd` file, no `class_name` anywhere. Surviving references: `tests/perf_probe.gd:88`
(`world.billboard_vegetation`), `test_world_alive.gd:438,448`
(`get_node_or_null("BillboardVegetation")`, degrades gracefully). An agent grepping the name finds
hits and concludes it is a real system.
**RECOMMENDATION: RETIRE the stale test references.** Trivial, but it is exactly the "lie in the
map" the fossil law targets.

> **PARTIALLY CORRECTED 2026-07-20 (overnight sweep).** The `tests/perf_probe.gd:88` pointer above is
> now **false**: that file contains zero occurrences of `BillboardVegetation` (verified by grep,
> 2026-07-20), and `:88` now reads `RenderingServer.get_rendering_info(...)`. The probe was repaired
> and has executed.
> **STILL TRUE and still owed:** `tests/test_world_alive.gd:438,448` retain the
> `get_node_or_null("BillboardVegetation")` lookup — a check that can never succeed. It degrades
> gracefully (`push_warning`, not caught by the runner's error scan), so it is benign but remains a
> lie in the map. Also `tests/probe_perf_decay.gd:5` names the class in a doc comment.

## 21. `DestructibleVehicle` — a class name promising behaviour that does not exist
`scripts/vehicles/destructible_vehicle.gd`: declares `is_destroyed` (never read or written again),
and has **no `take_damage`, no health, no `destroy()`**. Never registers with `AgentRegistry`, so
`apply_explosion_damage`'s prop loop never reaches it.
Triage: **MISSING FEATURE**, not fossil. Risk is that an agent assumes
`DestructibleVehicle.take_damage()` exists and hand-rolls a second implementation in place.
**RECOMMENDATION: OWNER DECISION** — build it or rename the class to what it is (a static
collision prop). **Could not determine** whether this is beaded.

## 22. Asset duplicates
| Pair | Note |
|---|---|
| `assets/us/characters/gear_armory.blend` (52.8 MB) vs `assets/us/props/gear_armory.blend` (53.2 MB) | props = truth. `props/gear_armory.blend1` is byte-size identical to `characters/gear_armory.blend` → active churn between the two, not a clean fork |
| `assets/building models/structures/airfield/fuel_depot.glb` (1.93 MB) vs `.../converted/fuel_depot.glb` (304 KB) | **Both orphaned.** Only `collision_table.gd:76,202` keys `"fuel_depot"` — no `load()` of either path. MISSING FEATURE (unbuilt airfield), not fossil |

`_v2`/`_v3` sweep: clean — `us_base_v3.blend`, `vc_guerilla_v2.blend` etc. have no un-suffixed
twin; the versioned name IS the current name. True backups already correctly isolated under
`assets/us/characters/_archive/`.
**Note:** `.blend` files are never loaded by Godot (no `.blend.import` exists) — the armory pair is
an **artist-workflow** risk (which file to edit), not a runtime risk. `fuel_depot.glb` WOULD be a
runtime risk once wired.
**RECOMMENDATION: OWNER DECISION** on the armory pair (PROTECTED — active work). **DO NOT create
.blend backups** (standing rule). `fuel_depot` — owner call: wire or cut.

## 23. `BTSequence` / `BTConditions` — framework built ahead of its wiring
The behaviour-tree framework **IS live**, but only for `Civilian`: `civilian.gd:337-366` builds a
real `BTSelector` tree of `BTAction` leaves dispatched via `civilian_schedules.gd:25`.
`BTSequence` and `BTConditions` are defined but **never instantiated anywhere**.
Enemies (`enemy_base._think` :569) and allies (`ally_base._think` :440) run their own state
machines with **zero BT usage** — three different actor kinds, one brain each. **Not competing.**
**RECOMMENDATION: KEEP** — triage is UNFINISHED (framework completeness), not FOSSIL. Note only.

## 24. Stale OPEN beads describing already-fixed bugs
The re-seat cohort **has been fixed** and two P1 beads have not caught up. Verified:
`terrain_manager.gd:303` emits `region_rebuilt`; `game_world.gd:363-387` coalesces it and calls
`water_system.reseat_region(rect)` **then** `gameplay_grid.rebuild_rect(rect)` — with the ordering
constraint correctly documented as a real invariant (water first, because the grid's WATER type
queries WaterSystem). Both functions exist (`water_system.gd:429`, `gameplay_grid.gd:497`).
- **`t5ne`** (P1 OPEN, "WaterSystem never re-seats… 5th divergent instance") — **appears FIXED.**
- **`15ow`** (P1 OPEN, "GameplayGrid stale after plateau flatten + craters") — **appears FIXED.**

*Process note:* the Overseer sent a mid-task correction to a hunter based on these beads and the
2026-07-18 devil's-advocate analysis; **the hunter read the code and pushed back, correctly.**
Third instance today of the codebase beating the document.
**RECOMMENDATION: verify with a probe, then CLOSE both beads** per ADR-015 (no closing on
"appears fixed"). An open bead describing a fixed bug is a fossil in the task graph.

## 25. `squad_leader.gd` — status confirmed, no action
`class_name SquadLeader extends EnemyBase`, fully formed. Preloaded once at
`mission_generator.gd:15`; **zero `.new()` calls repo-wide**, no `.tscn`, no test reference.
**Unchanged. Still FORK F4, owner-parked. BLOCKED — no recommendation.**

## 26. Docs that outlived their subject
- `SPRITE_INTEGRATION_PLAN.md` still at repo root — ADR-001:47 explicitly ordered it
  "retired from the repo root (delete or move to archive)." Not done.
- ADR-005's "NOT implemented" status note is stale — the bundle shipped.
- ADR-001's "ModelActor → SpriteActor → capsule" chain is stale — `SpriteActor` no longer exists.
- This Overseer's charter says ADR-003 "RECON dice" — superseded by ADR-016.
**RECOMMENDATION: OWNER DECISION** — a doc-truth pass. Note another agent is concurrently writing
`production/DOC_AUDIT_2026-07-19.md`; these should be reconciled, not duplicated.

---

# WHAT I COULD NOT DETERMINE — honest list

1. **`RiverGenerator` vs `HydrologyMap` real-world disagreement rate.** Two independent algorithms
   proven; whether they actually diverge in a built world needs a runtime probe. Do not act on
   the static read alone.
2. **Whether `test_terrain_desync.gd` and `test_one_classifier.gd` currently PASS.** Read-only
   audit — nothing was executed. The wiring they depend on exists and is structurally sound.
3. **Whether the re-seat fix (item 24) is complete or partial.** The `region_rebuilt` path is
   wired and correctly ordered; I did not prove every edit site routes through `modify_terrain`.
4. **Whether `TreeCoverLayer` re-seats after runtime terrain edits.** No `region_rebuilt`
   subscription found inside `tree_cover_layer.gd`; the only re-scatter path found is
   density-center-driven (`vegetation_manager.gd:505-521`). Asserting neither way.
5. **Full extent of `hud.gd` vs `mission_hud.gd` overlap.** Grenade/medkit proven duplicated.
   HP/ammo appear only in `hud.gd`, compass/objectives only in `mission_hud.gd`. Not every label
   pair was diffed.
6. **Whether `gear_armory.blend`'s two copies differ in CONTENT.** Only filesystem metadata was
   compared — the binaries were not opened.
7. **Whether `DestructibleVehicle` and `fuel_depot.glb` are beaded/known.** No bead reference or
   TODO found in either.
8. **Whether `CombatManager`'s legacy `active_*` roster migration (bead `e9je`) is 100% complete.**
   `agent_registry.gd` is clean; historical `CombatManager` internals were not exhaustively audited.
9. **`.tscn` `uid://` references.** Path-string greps would miss a UID-only reference. Low risk
   (Godot usually stores both), not exhaustively ruled out.

---

# WHAT CAME BACK CLEAN — verified non-competing

Recorded so the next audit does not re-litigate these.

- **ONE terrain classifier.** Bead `6od4` is genuinely CLOSED. `gameplay_grid.gd:284-293` and
  `vegetation_manager.gd:277-281` are both one-line delegates to `TerrainZoning.classify()`; old
  bodies deleted (fossil law honoured). `test_one_classifier.gd` proves it over 10,000 samples —
  a real regression guard, not a doc claim. *(The arena bypasses the classifier entirely — item 14.)*
- **ONE world-build entry point.** `build_patrol_world` is the only such function repo-wide.
  `game_flow.gd:258` is the only non-test instantiation of `game_world.tscn`.
- **ONE spawner per actor kind**, all funnelling through one factory each: `EnemyBase.spawn_enemy`
  (:2464), `AllyBase.spawn_ally` (:1050), `CivilianScript.new()`, `Convoy.new()`. The arena uses
  the *same* enemy factory — it just skips mission bookkeeping, which is correct for a bench.
- **ONE damage grammar** — ADR-016 flat × zone. Dice fully purged.
- **ONE AOE resolver** — `CombatManager.apply_explosion_damage`.
- **ONE sim-time authority** — SimClock. No rival day/night clock exists. *(Its Period half has no
  consumers — item 6.)*
- **ONE save owner** — `CampaignState`; `save_data.gd`/`save_manager.gd` are explicitly brokers,
  and `mission_scope.gd:20-22` documents the ownership boundary as a load-bearing contract.
- **Clean audio division** — `NoiseBus` (AI signal) / `AudioManager` (SFX) / `VOManager` (VO). All
  5 gunshot broadcasts route through `NoiseBus`. No ad-hoc alert-radius loop.
- **ADR-002 scale contract intact** — `1.7132` appears only in `model_actor.gd:18` (+ comments).
  No second height constant. `MAP_SIZE 1280` defined once (`world_config.gd:9`).
  `SIGHT_CAP_OPEN/JUNGLE` defined once (`enemy_base.gd:73-74`).
- **No minimap survives** — ADR-021/022 upheld; `test_world_minimap.gd` is self-declared test-only.
- **`MissionDirector` → `FieldDirector` rename is complete** — zero code hits for the old name.
- **Only one surviving hitscan path** — `weapon_holder.gd:521-641` pellet cluster, shotgun-gated.
  Everything else routes through `BulletSystem`. Matches the 2026-07-11 decree exactly.
- **`GruntDresser.dress()` now HAS game callers** — via `ally_base.gd:284` →
  `GruntRandomizer.dress_actor()` → `GruntDresser.dress()`. **Bead `37mj`'s "zero game call sites"
  is out of date.**

---

# SUGGESTED ORDER OF RULING

**Cheap, contained, high value — likely YES:**
items 3 + 2 (`data/vietnam/` + `GameEnums`, one atomic change), 20 (BillboardVegetation refs),
15 (stale `terrain_lab` comments), 24 (probe + close two stale beads).

**Needs a real decision:**
1 (rename vs ADR-001 amendment), 4 (which HUD survives), 5 (weather merge), 7 (accepts a seed
shift under ADR-010), 8 (LocationPlanner), 9 (TerrainEngine height accessors), 11 (is an ally
headshot fatal?), 12 + `7ioa` together (the "lying bench" class), 17 (QualitySettings).

**Do not touch — decree owns them:**
10 (`akx8`), 14 (`qjf0`/`b6lr`), 18 (`nohh`), 25 (FORK F4), 13 (`6n0b` DRAFT).

**Worth its own ruling:** the meta-finding. A name-collision detector added to the suite would
close the structural blindspot permanently — the fossil probe cannot be repaired for this class,
because mutual-alibi is inherent to counting bare symbol names.
