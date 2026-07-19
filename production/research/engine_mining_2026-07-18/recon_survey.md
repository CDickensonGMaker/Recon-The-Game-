# RECONgame — Performance & Complexity Architecture Survey
*(agent survey, 2026-07-18 — the "our side" baseline for the engine-mining comparison)*

Godot 4.7 stable, Forward+ (ratified, ADR-026 Amendment A), GDScript strict-typed. Map ≤2km fully resident (ADR-013). 14 autoloads (`project.godot:26-46`), all with live `_process`. Total ~37.6k lines GDScript; `scripts/enemies/enemy_base.gd` (2469) and `scripts/levels/ai_stress_arena.gd` (1819) dominate.

Note up front: **there is no `WorldBuilder` class.** ADR-028's "shared WorldBuilder" is aspirational — the only `WorldBuilder` hits are in `RECONgame_BACKUP_2026-07-16\` and `.cursor\` extensions. The "unified build" is actually static funcs in `mission_generator.gd` + `game_world.gd` + `site_planner.gd`. The arena is still a separate hand-wired world.

---

## 1. AI — actors, scheduling, perception, pathing, suppression, tiering

**Actor classes**
- `scripts/enemies/enemy_base.gd` — `EnemyBase extends CharacterBody3D` (2469 lines). The one enemy brain for all VC/NVA (rifleman, farmer, sapper, RPG, NVA regular — resource-driven via `EnemyData`). God class: perception, goal FSM, cover, patrol, firing, spider-holes, tunnel retreat, corpse/witness, hitzone sync, gore.
- `scripts/allies/ally_base.gd` — `AllyBase` (1012), squad mates. Mirror of enemy think/execute but **no distance LOD throttle** and **not activity-tiered**.
- `scripts/world/civilian.gd` — `Civilian` (483), villagers/informers, its **own** `lod_tier` system.
- `scripts/enemies/enemy_squad.gd` — `EnemySquad extends RefCounted` (476), static per-squad registry + the hot-set compute broker.
- `scripts/squad/squad_system.gd` (356) — player squad manager (revive, point-man scan, grenadier).
- Support: `camp_director.gd` (134), `patrol_generator.gd` (82), `ambush_planner.gd` (84), `squad_leader.gd` (38, mostly fossil consts per ADR-025), `ai_marksmanship.gd` (89). `scripts/ai/bt/` is a 5-file behavior-tree kit used only by civilians.

**Think scheduling (Quake-3 split, confirmed live)**
- `enemy_base.gd:32` `THINK_INTERVAL = 0.15` (6-7 Hz). `_physics_process` (`:442`) caps `capped_delta = minf(delta, 0.066)` (`:470`), accumulates `think_timer`, calls `_think()` at `_think_interval_current` (`:478-481`), then `_execute(delta)` every frame (`:483`).
- **Distance LOD on think rate only** — `_update_think_lod` (`:39-54`) runs every 2s (`:41`): >150m → 0.6s, >80m → 0.3s, ≤80m → 0.15s. That is the ONLY live distance LOD on enemies.
- **No explicit think staggering** — all units init `think_timer = 0.0`; only spawn-frame drift de-phases them. Frame-alignment spikes possible when many spawn together (LazyGroup spawns a whole group in one frame).
- `ally_base.gd:22` `THINK_INTERVAL = 0.15`, fixed, no LOD (`:369-374`). Allies are the un-throttled side.

**Goal/state machine**
- `_think()` (`:526`): runs the **witness heartbeat first, untiered** — `_update_perception()` + `_check_corpse_discovery()` on EVERY unit every think (`:534-535`), THEN the tier gate. `AlertTier {RELAXED,SUSPICIOUS,ALERT,COMBAT}` (`:64`), orthogonal `AIGoal`/`AIState` FSM. `awareness` accumulator 0-1 (`:66`), `AWARENESS_DECAY 0.25` (`:67`), `SUSPICIOUS_THRESHOLD 0.45` (`:68`).
- Goal scoring: `_evaluate_goals` → `_local_force_ratio()` (`:1179`) which **iterates all `enemies` group** (O(N)) each hot think.

**Activity-tiering — BUILT (ADR-026 Part B)**
- `EnemySquad` hot-set: `HOT_CAP = 12`, `HOT_CEILING = 16`, `tiering_enabled = true` (`enemy_squad.gd:37-41`). `is_hot`/`request_hot`/`release_hot` (`:59-89`), promote-on-death via `_prune_hot` (`:47`).
- Gate in `_think()` (`:541-546`): COMBAT units either `_think_full_combat()` (`:559` — target acq, LOS raycast, cover, grenades) if hot, else `_think_cheap_combat()` (`:572` — reads squad-shared target dict, one `_can_witness` raycast, no scan). **Guard-rail:** perception + corpse-discovery are never tiered (the ADR-005 witness beacon).

**Target acquisition / vision (raycast frequency)**
- `_update_perception` (`:769`): nearest candidate (player-weighted `:773-776`), sight caps `SIGHT_CAP_OPEN 140`, `SIGHT_CAP_JUNGLE 45` (`:72-73`), FOV cone unless COMBAT, then **1 `CombatManager.has_line_of_sight` raycast** (`:814`). Runs for **every live unit every think** → O(N) raycasts/think floor.
- `_update_line_of_sight` (`:984`): 1 raycast, hot units only. `_find_best_target` (`:939`) `RETARGET_INTERVAL 2.0`, `TARGET_MEMORY 8.0` (`:910-911`), distance-only scoring (no player bias, `:917`).
- `CombatManager.has_line_of_sight` (`combat_manager.gd:301`) = single `intersect_ray` vs world layer 1. Explosions use `_can_damage_multipoint` = **8 rays** (`:205-236`, Quake-3 CanDamage).
- Cover search: `_find_cover_point` (`:1756`) / `_find_bound_point` (`:1730`) cast **12 rays** (`COVER_SEARCH_OFFSETS`, `:94-98`) when seeking cover — hot units only.
- `_witness_check` (`:715`) on each death iterates all enemies (O(N)); `_check_corpse_discovery` (`:746`) scans `unreported_corpses` per think.

**Pathfinding** — `NavigationAgent3D` (`enemy_base.gd:82`, `get_node_or_null`), baked by `scripts/world/nav_baker.gd` (267). `WorldConfig.NAV_ENABLED = true` (`world_config.gd:34`) is the kill-switch; off → direct steer. Nav baked per-site via `nav_baker.queue_sites`.

**Suppression** — `suppression_level` 0-1, decays `SUPPRESSION_DECAY` in `_update_decay` (`:498-500`); `CombatManager.apply_suppression_in_area` (`:240`) loops `active_enemies`; high suppression forces `_execute_suppressed` (`:1426`). Squad fire-and-maneuver brokers in `EnemySquad`: covering-fire window 1500ms, grenade cooldowns (`:14-17`), the "hunt" net (`:288-441`).

**How many alive** — Patrol world (`mission_generator.plan_patrol_world:427`): 4 villages × `rng(4,7)` + 3 camps × `rng(4,6)` + 2-3 ambient patrols × `rng(2,4)` ≈ **32-58 authored enemies**, but all except the nearest village are `LazyGroup` (spawn when player within `activation_range` 120-140m). **No simultaneous-live cap and no despawn** — once spawned, an enemy lives forever (only think-throttled). Hot combat-AI capped at 12/16. Arena target: 18v18 = 36 + reinforcement waves (16+1d10 each) → 60+ bodies (the ADR-026 "30v30" scene).

---

## 2. Frame budget — what runs per-frame and how it scales

Per-frame nodes (30 `_physics_process`, 29 `_process` scripts). Scaling-with-actor-count work:

- **Per enemy** (`enemy_base._physics_process:442`): gravity, `_update_decay`, `_update_think_lod`, think (throttled), `_execute`, `_update_unstick`, `move_and_slide`. **Plus `HitzoneBuilder.sync(...)` EVERY physics frame for every live model** (`:451`; 6 Hz only for corpses `:447`) — O(N × zones) skeletal sync per tick, untiered.
- **Per ally** (`ally_base._physics_process:~355`): same stack, no LOD, un-tiered.
- **Per civilian** (`civilian._physics_process:119`): own `lod_tier`; `LOD_FAR` early-returns and `set_physics_process(false)` (`:123,354`).
- **Per bullet** (`bullet_system._physics_process:66`): 1 segment `intersect_ray` per live round per tick (`:82`), capped `MAX_BULLETS 128`.
- **Per LazyGroup** (`lazy_group._physics_process:44`): polls player distance at 1 Hz (`:48`), self-disables after spawn (`:90`).
- **CombatManager** (`:39`): `_cleanup_invalid_entities` every 5s (`CLEANUP_INTERVAL 21`).
- **VegetationManager** (`:137`): frustum cull at 10 Hz (`FRUSTUM_UPDATE_INTERVAL 0.1`, `:100`), loops all chunk instances (`:173-189`).
- **TerrainManager** (`:62`): rebuild queue with `REBUILD_BUDGET_MS 8.0` (`:46,83`); streaming disabled ≤2km (`:72`) — resident.
- **GameWorld** (`_process:357` ambience reseat every 6s; `_physics_process:371` player reseat every 2s).
- **SquadSystem** (`:227`): point-man scan + grenadier at 0.4s (`:236,242`); thumper target scan is a **nested `enemies × enemies` loop** (`:291-300`, O(N²)).

**Measured verdict (ADR-026 / PERF_LEDGER): the frame is CPU-bound on AI, not GPU-bound on jungle.** Overlay `ai/agents` bucket = 25-192 ms is the wall; jungle GPU barely moves (~32 ms) across −22% prims.

Timers vs polling: mostly interval-gated timers (good), but the untiered per-unit perception raycast + per-frame hitzone sync are the polling costs that scale with body count.

---

## 3. World / entity lifecycle

- **Top scene** `scenes/main/main.tscn`; `GameWorld` (`game_world.gd`) builds terrain → veg → water → gameplay grid → player → clutter (`_on_terrain_ready:139`). Sun shadow **OFF** (`:45`), fog `density 0.0065` (`:69`). **No `WorldSim.update_player` call anywhere** — WorldSim is dead-wired.
- **WorldBuilder (ADR-028)** — does not exist as a class. Build path = `mission_generator.plan_patrol_world` (`:427`) / `build_patrol_world` (`:546`) static funcs + `SitePlanner` (`site_planner.gd`, 602) + `game_world.gd`. `_wire_systems` resets `WorldSim` per mission (`world_sim.clear_if_needed:139`). ADR-028 structural probe ("arena instantiates shared WorldBuilder") is explicitly deferred to unbuilt "Phase-3 arena wrapper."
- **Patrol world (ADR-029)** — `FieldDirector` (`field_director.gd`, 576) is the surviving MissionDirector. Wire gate `_poll_wire_gate` (`:474`): cross `WIRE_GATE_M 120` outward → pick a living location in push direction; re-cross `WIRE_RETURN_M 95` → `_bank_patrol` AAR (`:546`). Diegetic pointer only, no objective markers.
- **Distance spawn/despawn** — only `LazyGroup` (`lazy_group.gd`): dormant node, `activation_range` 120-140m, 1 Hz poll, spawns whole group then disables. **No despawn** for enemies. Civilians self-cull via `lod_tier` (`LOD_FAR` at range, `:337-354`).
- **Vegetation (alpha-card impostors)** — `vegetation_manager.gd` (741): `CanopySource.TREE_COVER` (individual 3D species, `WorldConfig.USE_TREE_COVER = true`) vs legacy `JunglePatchLayer` merged 12m patches. `TREE_CANDIDATES_PER_CHUNK 1200` (`:85`, cut from RTS 2000), one `MultiMesh` per chunk (`:361-377`). Frustum-cull AABBs per chunk at 10 Hz (`:157-189`). `tree_cover_layer.gd` (179) near-solid/far-card hard LOD; billboard range shipped 350m (fog wall ~90m). `ground_clutter.gd` (172) grass <60m. Chunking: `MAP_SIZE 1280`, `CHUNK_SIZE 256` → 5×5 = 25 resident chunks (`world_config.gd:9-10`). No occlusion culling configured beyond frustum + fog.

---

## 4. Combat event flow

- **Small arms are raycast, not nodes** — `BulletSystem` (`bullet_system.gd`, 261): "one manager loop steps every live round; NO Node per bullet." Spawned at muzzle, gravity-integrated, **segment `intersect_ray` each physics tick** (`:66-102`) so 900 m/s rounds can't tunnel. `MAX_BULLETS 128`, `MAX_TRACERS 48`, `MAX_TRAVEL 1200`, `MAX_AGE 4.0` (`:25-29`). Damage resolves at arrival (`_impact:108`): falloff × zone mult × penetration; **one damage path for every shooter**, calls `target.take_damage(...)` directly.
- **Rockets/grenades are projectile nodes** — `ProjectileBase` (Area3D overlap) via `ProjectilePool` (`projectile_pool.gd`): true pool, `DEFAULT_POOL_SIZE 50`, `MAX_ACTIVE 30` (`:6-7`), lazy-grown.
- **The fossil router** — `CombatManager.apply_bullet_damage` (`combat_manager.gd:74`) is the dead damage router CLAUDE.md flags; bullets route around it via `BulletSystem._impact`.
- **Tracers** — pooled MeshInstance3D in `BulletSystem._visual_pool` (`:192-218`), the streak IS the round.
- **Impact FX / decals** — `gun_fx.gd` (552): **cap-and-FIFO, instantiate-on-demand, NOT pre-pooled.** `MAX_FLASHES 8`, `MAX_IMPACTS 12`, `MAX_EXPLOSIONS 6`, `MAX_DECALS 48`, `MAX_BLOOD_DECALS 24`, `MAX_BLOOD_POOLS 12` (`:58-61, 316-318`); over cap → `queue_free` oldest (`:443-446`). Muzzle flash = fake emissive sprite + capped OmniLight (ADR-026 fairness exemption).
- **Gore** — `gib_system.gd` (342), `gib_lifetime_s` (arena 25s); severed-limb via `on_zone_hit`/`apply_wound` (`bullet_system.gd:150-154`).
- **Audio** — `AudioManager` (391) pooled distance-layered voices; `NoiseBus` autoload for AI hearing.
- **Object pooling summary:** true pools = ProjectilePool (rockets), BulletSystem tracers. Cap-and-recycle (not pooled) = all gun_fx decals/blood/flashes. No pooling for enemy/character nodes.

---

## 5. Complexity hot spots

**Biggest scripts:** `enemy_base.gd` 2469 · `ai_stress_arena.gd` 1819 · `ally_base.gd` 1012 · `player.gd` 995 · `vietnam_weapon_data.gd` 994 · `weapon_holder.gd` 927 · `viewmodel_editor.gd` 831 · `model_actor.gd` 777 · `vegetation_manager.gd` 741 · `mission_generator.gd` (30k chars) · `field_director.gd` (22k) · `site_planner.gd` 602.

- **`enemy_base.gd` god class** — one 2469-line file owns perception, goal FSM, cover broker (static `_cover_claims`), patrol circuits, firing, spider-holes, tunnels, corpse/witness ledger, hitzone sync, gore, unstick watchdog. The single largest simplification target; `ally_base.gd` duplicates ~40% of it (think/execute/unstick/low-posture copied, not shared).
- **Parallel-world history (ADR-028)** — the doc names "~14 independent player-window-keyed systems + a 15th hand-wired arena." Current state: consolidation is **partial**. `ai_stress_arena.gd` still hand-wires its own `TerrainManagerStub`, `FlatHeightmap`, `ArenaGrid`, veg, clutter, lights (`:11-52, 245`) — a separate world-build path from `game_world.gd`. ADR-028 Phase 3 (arena → thin wrapper) and the structural probe are **not built**.
- **Overlapping LOD authorities (ADR-025 fossil hazard, unresolved)** — five notions coexist: `enemy_base._update_think_lod`, `civilian.lod_tier`, `EnemySquad` hot-set, the zero-caller `set_lod_live`/`set_lod_abstract` stubs (`enemy_base.gd:118-124`), and the fully-built-but-unwired `WorldSim` T3 tiers. ADR-025 Phase 0 unification into one `set_tier()` is not done.
- **Dead/unwired systems (fossils that read load-bearing):** `WorldSim.update_player`/`materialize_near`/`dematerialize_far` — zero callers (`world_sim.gd:70,86,99`); `SimClock.advance()` — zero callers though 8 systems subscribe; `CombatManager.apply_bullet_damage` — routed around; `world_config` FPS ladder — `VEGETATION_DENSITY_MULT` is a manual const dial read by veg only, the documented auto-fallback ladder is unbuilt.
- **O(N)/O(N²) registry scans:** `_local_force_ratio` (`enemy_base.gd:1181`, O(N)/hot-think), `EnemySquad._strength` (`enemy_squad.gd:124`, O(N), cached 1s), `squad_system` thumper scan (nested O(N²), `:291-300`), `CombatManager` explosion/suppression loops over `active_*`.
- **Signal/registry duplication:** entities tracked in BOTH engine groups (`enemies`/`allies`) AND `CombatManager.active_enemies/active_allies` — two sources of truth kept in sync by a 5s cleanup timer.

---

## 6. Perf instrumentation & measured numbers

**Harnesses:**
- `scripts/levels/ps2_perf_probe.gd` (185) — fixed-camera windowed probe, prints machine-readable `[PS2PROBE] SUMMARY` (avg/median fps, cpu/gpu-ms, draw calls). CLI: `--scale --mode --no-lights --no-shadows --seconds --warmup`. Fixed pose `CAM_POS (-70,6,70)`.
- `scripts/levels/arena_perf_overlay.gd` (239) — live HUD: frame-ms, real CPU/GPU split (`viewport_get_measured_render_time_gpu`), draw calls/prims/objects, spike catcher, per-system CPU buckets, F1-F6 toggles (jungle/clutter/lights/characters/debug/shadows). `SPIKE_MS 25`, `TARGET_MS 33.3`.
- Bench scenes: `tests/perf_probe.tscn`, `tests/overnight_bench.tscn`, `tests/windowed_patrol_perf.tscn`, `night_jungle_bench.bat`, `ps2_perf_probe.tscn`.
- **FPS fallback ladder** — `world_config.gd`: `VEGETATION_DENSITY_MULT`, `BILLBOARD_DISTANCE_MULT`, `NAV_ENABLED`, `USE_TREE_COVER` are manual const dials (edit + reboot). No runtime auto-ladder.

**Measured numbers of record** (`production/PERF_LEDGER.md`, `ADR-026`):
- Native `game_world` (open daytime, Forward+, scale 1.0, Intel UHD): **~27 fps** (24-29), 25 chunks, ~13k billboards. Billboards = 40% of prims / 66% of draw calls; off → **+8.2 fps → 32.5** (clears 30 alone at that pose).
- Night 18v18 arena (the adversarial scene): **Forward+ native 18.8 fps** (GPU 51.94 / CPU 44.35 ms, 911 draws, 806k prims); shipped 0.75/mode5 → 22.3; Mobile native 25.5; Mobile shipped **29.9**. **Nothing clears the 30 fps gate in the night arena.**
- Jungle patches toggle = **−12.26 ms GPU, −572,438 prims (71% of frame geometry)** — the biggest GPU line, but STANDS only as geometry; the arena frame is **CPU-bound** (`ai/agents` 25-192 ms).
- **14 → 23.1 fps (+65%)** — ADR-026 cheap-GPU-wins wave (frame 71 → 43 ms), then stalls at the ~41 ms CPU wall → why Part B (activity-tiering) is "the real FPS lever."
- Control experiment: identical arena rows swing ±10% fps / +25% draw calls because "the arena is a live firefight that escalates while you measure it" — toggle-diffs are contaminated.
- Patrol world first honest row (2026-07-18, native Forward+, spawn view seed 47225): **28.8 fps, 217 draws, 116k prims** (spawn-interior view, not a jungle sightline or firefight).
- Renderer ratified `forward_plus` (ADR-026 Amendment A); shadows off in ship; `scaling_3d/scale 0.75`, `mode 5` nearest.

---

## Top 10 perf / complexity liabilities (ranked by likely frame-time / code cost)

1. **Untiered per-unit perception raycast + per-frame hitzone sync = the CPU wall.** Every live unit runs `_update_perception` (up to 1 LOS `intersect_ray`) + `_check_corpse_discovery` every think, and `HitzoneBuilder.sync` every physics frame (`enemy_base.gd:451,534-535`). The hot-set (12) does NOT reduce this floor. On a resident 30-58-enemy world this is O(N) raycasts/think + O(N×zones)/tick — matches the measured `ai/agents` 25-192 ms wall. **Biggest single frame-time cost.**
2. **No T2-sleep / T3-despawn — enemies never stop simulating.** `WorldSim` tiers (`world_sim.gd:70,86,99`) and `set_lod_live/abstract` (`enemy_base.gd:118`) are built but **zero-caller**; `game_world` never calls `WorldSim.update_player`. Every spawned enemy stays full-physics forever (think-throttle only). The one lever that would cap live-AI cost is unwired. ADR-025 Phase 1/2 unbuilt.
3. **Jungle GPU fill.** `TREE_CANDIDATES_PER_CHUNK 1200` × 25 chunks + billboards = 71% of frame geometry / −12.26 ms GPU. Secondary to CPU in the arena but the primary GPU cost in open `game_world`; the only tuning is a manual const.
4. **`enemy_base.gd` god class (2469 lines).** Perception + FSM + cover + patrol + firing + spider-holes + tunnels + corpse + hitzone + gore in one file, with ~40% duplicated into `ally_base.gd`. Highest code-complexity cost; every AI change touches it.
5. **Duplicate world-build paths (ADR-028 incomplete).** `ai_stress_arena.gd` (1819) hand-wires a parallel terrain/veg/clutter world (stubs at `:11-52`) distinct from `game_world.gd`; no shared `WorldBuilder` exists. Phase-3 wrapper + structural probe unbuilt — the exact fracture ADR-028 was filed to close is still open.
6. **Five overlapping LOD authorities (ADR-025 Phase 0 not done).** `_update_think_lod`, `civilian.lod_tier`, `EnemySquad` hot-set, `set_lod_live/abstract` stubs, `WorldSim` tiers. An agent cannot tell which is load-bearing; `MAX_THINK_TIME` fossil still baselined. Real churn risk on live AI.
7. **Per-hot-think O(N) group scans.** `_local_force_ratio` (`enemy_base.gd:1181`) walks all enemies each hot think; `EnemySquad._strength` (`:124`) O(N) cached 1s; `squad_system` thumper scan is nested O(N²) (`:291-300`). Grows with body count exactly when the frame is already hot.
8. **Dead damage router + dead SimClock.** `CombatManager.apply_bullet_damage` (`combat_manager.gd:74`) — bullets bypass it; `SimClock.advance()` — zero callers though 8 systems subscribe to its signals. Fossils that read load-bearing and mislead edits (the exact FOSSIL LAW hazard).
9. **gun_fx decals are cap-and-FIFO instantiate, not pooled.** `MAX_DECALS 48`, blood 24/12, flashes 8 (`gun_fx.gd:58-61,316`) — over cap → `Decal.new()` / `queue_free()` churn every hit during sustained fire, node-alloc pressure. The one FX subsystem without a real pool.
10. **Dual entity registries + no think staggering.** Entities live in both engine groups and `CombatManager.active_*` (synced by a 5s cleanup timer) — two truths; and all units init `think_timer = 0.0` with no phase offset, so a LazyGroup that spawns 4-7 men in one frame can align their 0.15s think spikes. Cheap to fix (round-robin stagger), meaningful spike relief.

**Bottom line:** the borrowed id-Tech-3 patterns (timestep cap, 6-7 Hz think/execute split, goal-driven AI, suppression, hot-set budget) are genuinely in place and correct. The gap versus Quake 3 / RTCW is that Q3's PVS/area culling and dormant-entity model have **no live equivalent here** — the resident world simulates every spawned actor at full perception cost, and the two mechanisms that would fix it (WorldSim T2/T3 tiers, the unified LOD authority) are built-but-unwired or unbuilt. The measured evidence agrees: the frame is CPU-bound on AI, and the AI cost floor is the untiered witness heartbeat, not the jungle.
