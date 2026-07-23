# CODE AUDIT — 2026-07-08

Method: mechanical reachability analysis over all 100 `.gd` files in `scripts/` + `terrain/`, cross-referenced against `.tscn`, `.tres`, and `project.godot`. Every finding below carries `file:line` evidence and was independently re-verified before being written down. Claims in `WAVE3_REPORT.md`, `NIGHTSHIFT_REPORT.md`, `PLAYER_MANUAL.md`, and `STATE_OF_PROJECT.md` were checked against the code rather than taken on faith.

Tracked in Beads as `AUDIT-01` … `AUDIT-11`.

---

## 1. THE HEADLINE: two shipped features are no-ops

### 1a. Enemies do not pathfind. `R16` is a no-op. (Beads `ctz` — REOPENED)

Commit `2321323` states: *"enemies now actually use the baked chunk navmesh to chase/investigate instead of bee-lining into walls."*

They do not.

- `terrain/core/terrain_chunk.gd:261` — `bake_navigation()` is fully implemented and is **the only place** `nav_region.navigation_mesh` is ever assigned (line 282).
- `terrain/core/terrain_manager.gd:291` — its only call site: `# chunk.bake_navigation()`. **Still commented out.**
- `scripts/levels/game_world.gd` — the live level. Zero references to nav or navigation.
- No live `.tscn` contains a `NavigationRegion3D`. The only one is in `scenes/levels/test_arena.tscn`, which nothing loads.

So `enemy_base.gd:1025-1028` runs a `NavigationAgent3D` against an **empty navigation map**:

```gdscript
if nav_agent != null:
    if nav_agent.target_position.distance_squared_to(pos) > 4.0:
        nav_agent.target_position = pos
    if not nav_agent.is_navigation_finished():        # ← true immediately, no map
        direction = nav_agent.get_next_path_position() - global_position   # ← never runs
```

With no navmesh, `is_navigation_finished()` returns true at once, the branch never executes, and `direction` falls through to the raw bee-line vector — exactly the pre-"fix" behavior. The `## R16:` comment at `enemy_base.gd:1021` describes behavior that does not occur.

**Fix:** uncomment `terrain_manager.gd:291`, async-ify the bake for chunks near AI, re-verify with an actual enemy walking around a hut.

*(The rest of Sweep 1's AI work is real: alert tiers, NoiseBus, the cover-claim broker at `enemy_base.gd:1044`, and trail patrols with sentry boredom at `:1109` were all verified working.)*

### 1b. The Barracks can only ever sell you one skill (Beads `AUDIT-01`)

`campaign_state.gd:17` hardcodes `player_data.mos = "RIFLEMAN"`.
`barracks.gd:60` derives **one** purchasable skill per person from MOS:
```gdscript
var skill_id: String = str(SkillCatalog.MOS_SKILL.get(mos, "small_arms"))
```
`skill_catalog.gd:26` — `MOS_SKILL["RIFLEMAN"] = "small_arms"`.

The player can never buy `fo_fac`, `demolitions`, `silent_movement`, `medic`, `detect_ambush`, or `sniping`. Four of the six `player_skill()` read sites are therefore **structurally pinned at zero forever**:

| Read site | Reads | Can ever be > 0? |
|---|---|---|
| `weapon_holder.gd:257`, `:246` | `small_arms` | ✅ yes |
| `player.gd:426` | `silent_movement` | ❌ not in `MOS_SKILL` at all — nobody can buy it |
| `mission_generator.gd:352` | `demolitions` | ❌ GRENADIER's slot; read queries `player_data` |
| `plant_charge.gd:28` | `demolitions` | ❌ same — you never spot trap wires |
| `mission_director.gd:196` | `fo_fac` | ❌ RTO's slot; read queries `player_data` |
| `squad_system.gd:151` | `medic` | ✅ the only correctly cross-wired one (reads the medic's own dict) |

Also: `detect_ambush` is buyable by POINT but **read nowhere** (`squad_system.gd:181` uses raw `al`). `sniping` (`skill_catalog.gd:13`) is neither buyable nor read — pure fiction.

`WAVE3_REPORT.md:17` and `PLAYER_MANUAL.md:32` both claim *"every purchase does something real."* The plumbing is well-written; it queries a dictionary that can only ever hold `small_arms`.

---

## 2. DEAD SUBSYSTEMS — complete, well-formed, zero runtime entry point

### 2a. The projectile system (Beads `AUDIT-03`, blocks `7ks`)
`combat_manager.gd:26-28` constructs a `ProjectilePool` and `add_child()`s it on every boot; its `_ready()` allocates 50 `ProjectileBase` nodes. The three entry points have **zero callers repo-wide**: `spawn_projectile` (`:294`), `spawn_projectile_at_target` (`:302`), `clear_all_projectiles` (`:310`). No `ProjectileData` `.tres` exists. `weapon_data.gd:37 projectile_data_path` is never read and unset in all 8 weapon resources.

Everything is hitscan: `weapon_holder.gd:289`, `enemy_base.gd:1161`, `ally_base.gd:413`.

### 2b. The damage pipeline (Beads `AUDIT-02`)
`combat_manager.gd:66 apply_bullet_damage()` — **zero callers.** Everything downstream is unreachable:
- `signal damage_dealt` (`:5`, emitted `:84`) — no global damage feed possible
- `signal entity_killed` (`:6`, emitted `:87`)
- `_apply_knockback` — Quake3 knockback never happens
- `GameManager.on_enemy_killed()` → `signal level_complete` (`game_manager.gd:7`, emitted `:73`) — **never connected**

This is the original *"kill-all-enemies signal into the void"* bug from `STATE_OF_PROJECT.md §1`. It was never fixed — it was **orphaned in place** when `MissionDirector` took over. The live win condition (`mission_director.gd:8` → `game_flow.gd:135`) works fine.

All real damage goes direct: `weapon_holder.gd:337`, `enemy_base.gd:1198`, `ally_base.gd:441` each call `target.take_damage()`.

### 2c. The `data/vietnam/` tables + the `GameEnums` autoload (Beads `AUDIT-06`)
`project.godot [autoload]` loads `GameEnums` on every boot. The **only** references to `GameEnums.*` anywhere are inside `vietnam_unit_data.gd` and `vietnam_weapon_data.gd` — and those two files have **zero inbound references** themselves.

~1400 lines (24 weapon defs, full US/ARVN/VC/NVA rosters, suppression/morale/cover tables) loaded and unreachable. `STATE_OF_PROJECT.md §3` called these the *"highest-value carry-overs."* They were imported in NS05 and never wired.

---

## 3. DATA THAT DOESN'T DO ANYTHING

### 3a. `EnemyData` — 10 dead exports (Beads `AUDIT-04`, blocks `R17`)
`enemy_base.gd:187-193` is the only consumer and reads exactly four fields: `max_hp`, `move_speed`, `preferred_range`, `weapon_path`. Ignored:

| Field | Why it's inert |
|---|---|
| `:14 alert_range` | Detection uses `enemy_base`'s own `AlertTier` constants |
| `:18 accuracy_modifier` | **Shadowed** — `enemy_base.gd:119` declares its own, overwritten at `:867/:871/:874` |
| `:19 aggression` | **Shadowed** by `char_aggression`, randomized at `:219/:225/:231` |
| `:22 uses_cover` | Never read. All enemies use cover. |
| `:23 flanks` | Never read. All enemies flank (`enemy_base.gd:687`) |
| `:24 retreats_when_hurt` | Never read |
| `:25 retreat_hp_threshold` | Never read. Hardcoded `< 0.25` at `enemy_base.gd:701` |
| `:28 model_path`, `:29 color`, `:6-8 id/display_name/description` | Never read |

**You cannot differentiate enemy archetypes today.** VC militia and NVA regular can only differ in HP, speed, range, and weapon. This blocks `R17` outright, and `model_path` is exactly where a sprite-sheet reference would naturally live.

### 3b. No damage falloff by range (Beads `AUDIT-05`)
`weapon_data.gd:32 effective_range` — *"Meters - full damage range"* — is **never read**. `weapon_holder.gd:284`, `enemy_base.gd:1156`, `ally_base.gd:408` all raycast to `max_range` and apply full `roll_damage()` at any distance inside it. **An M16 does identical damage at 5 m and 95 m.**

Falloff math exists only in the dead `vietnam_weapon_data.gd:924`.

Also dead in `weapon_data.gd`: `:41 viewmodel_scale` (never applied — `weapon_holder.gd:547-555` sets position/rotation, never scale, so editing it does nothing), `:8 description`, `:6 id`.

`damage_type` **is** passed through — but every `take_damage()` implementation (`health_system.gd:192`, `enemy_base.gd:1250`, `ally_base.gd:445`) names the parameter `_damage_type` and ignores it. The value travels and dies.

---

## 4. FEATURES THAT FIRE INTO THE VOID

Signals emitted with no listener — the feature runs, nothing observes it.

| Signal | Emitted | Inert functionality |
|---|---|---|
| `weapon_holder.gd:50 weapon_jammed` | `:251` | Your gun jams (R09 shipped) and **the HUD never tells you.** You just see the round not leave. |
| `health_system.gd:8 downed_started` | `:260` | No downed vignette / bleed timer driven by it |
| `grenade_handler.gd:5,6,7` | `:105,:62,:122` | The entire cook/throw loop. Cooking a grenade to death in your hand produces no dedicated UI. |
| `plant_charge.gd:6 plant_progress` | `:55,:64` | Demo charge progress computed, emitted, never drawn |
| `photo_objective.gd:6 photo_progress` | `:30,:37` | Same |
| `mission_director.gd:7 objective_completed` | `:96` | Per-objective events go nowhere; HUD learns via an adjacent `toast.emit()` |
| `squad_system.gd:7 squad_changed` | `:98,:252` | `mission_hud.gd:218` re-reads squad HP every frame instead |
| `campaign_state.gd:5 threat_changed` | `:49,:82` | `insertion_ride.gd:215` polls instead |
| `cas_airplane.gd:8 run_complete` | `:54` | Nothing knows when a CAS run finishes |

**Declared but never emitted:** `weapon_holder.gd:9 ads_changed`, `weapon_holder.gd:12 reload_cancelled` (so interrupting a reload leaves the HUD ring with no cancel path), `heightmap_storage.gd:6,7`.

**Related:** `ActionProgress` (`scenes/ui/hud.tscn:145`) — `start_action()`, `update_progress()`, `cancel_action()` all have zero callers. Only `finish_action()` is called (`hud.gd:116`). The widget is only ever *stopped*, never started. The circular action-progress ring described in `STATE_OF_PROJECT.md` **never appears.** (Beads `AUDIT-07`)

**Binoculars "mark targets"** (`PLAYER_MANUAL.md:19`): `player.gd:114` sets `enemy.set_meta("marked", true)` and parents a red `Label3D`. Grep for `"marked"` returns only `player.gd:113/114/126`. Nothing on the squad, HUD, topo map, or AI reads it. It's a floating character with a 10-second timer. (Beads `AUDIT-10`)

**HARDCORE "faster bleed"** (`game_settings.gd:9` comment): does not exist. `DOWNED_BLEED_SECONDS` is `const 30.0` (`health_system.gd:251`) with no hardcore branch. Only compass/markers are actually stripped (`mission_hud.gd:242-244`).

---

## 5. ORPHANED FILES (Beads `AUDIT-11`)

**Hard orphans** — zero references of any kind, all in `terrain/water/`:
`coastal_detector.gd`, `swamp_detector.gd`, `water_coastal_mesh.gd`, `water_static_mesh.gd`, `water_swamp_mesh.gd`

*(Trap: `water_system.gd:219` preloads `water_static.gdshader` — a shader, not `water_static_mesh.gd`.)*

**Dead subgraph 1 — `test_arena`** (main scene is `main.tscn`; nothing loads this):
`scenes/levels/test_arena.tscn`, `scripts/levels/test_arena.gd`, `tools/ww2_map_generator.gd`, `data/enemies/german_rifleman.tres`, `data/enemies/german_smg.tres`

Inside `ww2_map_generator.gd`, the 2D TileMap branch is dead even if revived: `:83 target_tilemap` is never assigned (test_arena.tscn has no TileMap node), so `_apply_to_tilemap()` (`:535`) always early-returns.

**Dead subgraph 2 — `terrain_lab`** (editor scratch scene, not runtime):
`terrain/scenes/terrain_lab.tscn`+`.gd`, `terrain/ui/terrain_lab_ui.gd`, `terrain/systems/engineering_system.gd`, `terrain/systems/terrain_vfx.gd`, `terrain/systems/construction_markers.gd`, `terrain/vegetation/poisson_sampler.gd`, `terrain/core/quality_settings.gd`

*Keep `terrain_lab` if you still tune terrain by hand — just know it isn't shipped code.*

### `QualitySettings` prints a lie (Beads `AUDIT-08`)
It detects your GPU, picks a preset (POTATO→ULTRA), writes `load_distance`/`near_tree_distance`/`billboard_distance`, and prints `[QualitySettings] Applied preset: %s` — which is why it looks live. **Nothing reads the results.** `grep near_tree_distance|billboard_distance` outside that file returns zero hits. Consumers use hardcoded constants (`billboard_vegetation.gd:461`) or `WorldConfig` (`game_world.gd:81`). And it's only ever instantiated inside the dead `terrain_lab` subgraph, so in the shipping game the preset table doesn't even run. Blocks `R46`.

---

## 6. THREE THINGS `STATE_OF_PROJECT.md` GOT WRONG

Worth correcting, because these were listed as cleanup tasks that don't exist:

1. **`fps_controller.gd` does not exist.** `find -iname "*fps_controller*"` → nothing. There is no duplicate player controller. Nothing to delete.
2. **Hitbox/Hurtbox are not dead code.** There is no `hitbox.gd` or `hurtbox.gd`. The real component is `scripts/combat/hitzone.gd`, and it is **live** — constructed 6× per enemy (`enemy_base.gd:254-263`) and per ally (`ally_base.gd:103-112`), consumed on hit at `weapon_holder.gd:324-328`. Headshot multipliers work.
3. **`weapon_holder` and `equipment_manager` are not competing.** They're cleanly layered. `EquipmentManager` is the sole reader of slot input (`:66-77`) and calls `weapon_holder.set_active_weapon_slot()` (`:113`). `weapon_holder.gd:136` even documents the boundary. Nothing to consolidate.

---

## 7. DOC DRIFT (Beads `AUDIT-09`)

`WAVE3_REPORT.md:32` claims `PLAYER_MANUAL.md` "documents every key." Undocumented but working: **V** hold_breath (`player.gd:80`), **P** photo_mode (`:476`), **Esc** pause (`game_manager.gd:25`), mouse-wheel slot cycling (`equipment_manager.gd:75-77`).

Wrong: the manual says **T = "Call CAS strike."** T opens a *fire-support menu* (`mission_director.gd:145-162`) where 1–5 select bombs / napalm / **artillery** / mortar / **Spooky gunship**. Artillery and the AC-47 are entire undocumented systems.

Prompt/binding mismatch: `mission_director.gd:297` emits `"CRATE DOWN - [E] TO RESUPPLY"` and `game_flow.gd:118` tips `"LOOT THE DEAD [E]"` — but both are handled by `interact`, bound to **F** (`player.gd:538`). Only `insertion_ride.gd:107` genuinely accepts E.

Minor: `WAVE3 §F` calls POW RESCUE the "6th mission type" — there are **five** (`mission_generator.gd:6`). `NIGHTSHIFT:31` says village CAS budget = 1; actual is 1 bomb + 1 napalm = 2 (`mission_generator.gd:238`).

---

## 8. WHAT'S ACTUALLY SOLID

Verified working, so you know where the floor is:

- **All 5 mission types** build, offer, run, and replay by seed. ANTI-AA's campaign payoff is real (`campaign_state.gd:69-72`, −0.25 threat for 3 missions).
- **All 16 named systems** exist and are live: `CampaignState`, `GameSettings`, `NoiseBus`, `MissionDirector`, `SitePlanner`, `TerrainWatchdog`, `LazyGroup`, `FireHazard`, `DestructibleVehicle`, `EnemyMortarTeam`, `ReconUI`, `GunFX`, `BulletTracer`, `TopoMap`, `ServiceRecord`, `Barracks`.
- **NoiseBus is genuinely wired** — connected at `enemy_base.gd:204` and `civilian.gd:48`. Radii match the manual (gunshot 55, sprint 16, suppressed 3), and monsoon halves them (`mission_weather.gd:16` → `noise_bus.gd:22,30`).
- **MOS abilities work**, with one caveat. RTO gating covers CAS/arty/napalm/mortar/Spooky (`mission_director.gd:182`) *and* resupply (`:251`). Doc's revive chain is fully implemented (`squad_system.gd:117-160`). Pigman's `fire_rate_mult = 1.6` is consumed (`ally_base.gd:390`). Thumper auto-M79s on 3+ clustered enemies at 30–80 m (`squad_system.gd:191-219`).
  - *Caveat:* Point man only scans `lazy_groups`. Village defenders, POW guards, AA crews, spider holes, and hunter patrols spawn awake and **never trigger his warning.**
- **Alert tiers, cover-claim broker, trail patrols, prone, ADS zoom, smoke LOS blocking, Chieu Hoi surrender, corpse looting, tunnel caches, Iron Man wipe, shoot-down + fallback LZ, AA rolls en route** — all verified real.
- **All 23 regression tests named in `WAVE3_REPORT.md` exist in `tests/`.**

---

## PRIORITY ORDER

1. **`ctz`** — enable the navmesh bake. It's one uncommented line plus an async pass. Every AI behavior above it (cover, flanking, investigation, patrol) is currently steering blind.
2. **`AUDIT-01`** — the Barracks. The RPG pillar is the hallucination; the reads are all written and correct, they just query a dict pinned to one skill.
3. **`AUDIT-04`** — `EnemyData`'s dead exports. Blocks archetypes (`R17`) and is where sprite refs belong.
4. **`AUDIT-10`** — connect `weapon_jammed`. Cheapest player-facing fix in the list.
5. **`AUDIT-02` / `AUDIT-03` / `AUDIT-06`** — decide: wire or delete. Right now you boot 50 dead projectile nodes and a 1400-line unreachable autoload.
6. **`AUDIT-05`** — no damage falloff. Design call, not a bug, but the docs claim otherwise.
