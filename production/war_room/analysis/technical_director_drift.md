# TECHNICAL-DIRECTOR — SCENE DRIFT ANALYSIS (2026-07-17)

Read-only code audit. Question: which scenes are canon, which are lab instruments, which are
divergent game paths. All cites verified in source.

## 1. What actually boots
- `project.godot:21` — `run/main_scene="res://scenes/main/main.tscn"`.
- `scenes/main/main.tscn:3-6` — one Node running `scripts/main/game_flow.gd`. No other scene is a boot path.
- Canonical flow (game_flow.gd): menu (123) → NEW/CONTINUE → `enter_hub()` (405, loads game_world.tscn:416,
  `MissionGenerator.build_hub`:428) → TOC briefing (`hub_controller.gd:47-91`, real BriefingScreen) →
  board bird → `launch_accepted()` (395) → `start_mission()` (172) → `_run_mission()` (226, same
  game_world.tscn:227 + MissionGenerator.plan/build:242-248) → debrief (333) → back to hub (342).
  ONE world scene, both hub and mission; hub content stamps through the shared SitePlanner
  (`mission_generator.gd:898-924`, `site_planner.gd:430+` — Chinook/hootch/jeep GLBs are ART drift, not scene drift).

## 2. Scene inventory & classification
| scene | class | world-build path | drift risk | verdict |
|---|---|---|---|---|
| scenes/main/main.tscn | a | GameFlow only | none | KEEP |
| scenes/levels/game_world.tscn | a | TerrainManager+VegetationManager+GameplayGrid.build_from_terrain (game_world.gd:80-181) + MissionGenerator/SitePlanner | none — IS canon | KEEP |
| scenes/levels/ai_stress_arena.tscn | **c** | 100% hand-wired: stub terrain (11-20), ArenaGrid override (39-51), hand firebase/village/ridge/veg/nav (342-1097), own force spawner (1126-1260) | **SEVERE** | FOLD → thin wrapper over shared build (qjf0/dlox open) |
| scenes/levels/gore_lab.tscn | b | hand 44m box (gore_lab.gd:50-80), real agents | low (small, labeled) | KEEP as lab; fold onto shared arena base when qjf0 lands |
| scenes/levels/gun_range.tscn | b | hand lane (gun_range.gd:41), docile GoreDummy targets | low | KEEP |
| scenes/levels/ps2_perf_probe.tscn | b | wraps arena (ps2_perf_probe.gd:52) | inherits arena's | KEEP (instrument) |
| scenes/weapons/viewmodel_editor.tscn | b | none — tuning bench writing .tres | low | KEEP |
| scenes/tools/hitzone_editor.tscn, grunt_viewer.tscn | b | none | low | KEEP |
| tools/patrol_lab.tscn | b | flat plane (patrol_lab.gd:66); ghost joins "player" group (:97); drives REAL EnemyBase/EnemySquad | low-med | KEEP |
| tools/sight_lab.tscn | b | patch field; calibration only | low | KEEP |
| terrain/scenes/terrain_lab.tscn | b | real TerrainManager but OLD-ERA (RTS camera, engineering/construction systems) | med — old-era fossil-adjacent | KILL or archive; canon has windowed_confirm_47225 for eyeballing |
| tests/overnight_bench.tscn | b | wraps arena (overnight_bench.gd:46) | inherits arena's | KEEP |
| tests/windowed_confirm_47225 / windowed_ao_look / veg_lod_lookcheck | b | REAL game_world.tscn seed 47225 (windowed_confirm_47225.gd:22) | none — the RIGHT bench pattern | KEEP |
| tests/* probes, tools/probe_* | b | mostly real game_world.tscn (28+ files load it) | none | KEEP |
| game_flow show_select/MissionSelectScreen path | **c** (code, not scene) | bypasses hub: start_mission without from_hub | med | KILL connect or re-charter as test-only API |

Enemy/ally/weapon spawns outside canon flow: ai_stress_arena (both sides + player), gore_lab (VC waves),
gun_range (docile dummies + full armory), patrol_lab (real VC squads vs ghost), sight_lab (static men),
headless tests. Only the arena is playable-as-the-game with player+HUD+firefight (`night_jungle_bench.bat`
double-click boots it directly).

## 3. The three most dangerous divergences
**D1 — ai_stress_arena is a second, hand-built game.** 1,816 lines; ~800 (342-1097) rebuild by hand what
game_world derives from seed: floor vs generate_terrain (game_world.gd:110), ArenaGrid + hand-stamped
density (39-51, 529-571) vs build_from_terrain (game_world.gd:160-165), hand firebase/village (633/653)
vs SitePlanner.stamp_firebase (site_planner.gd:430), synthetic all-HEAVY jungle fill (407-429) vs seeded
VegetationManager, own navmesh bake (1078), own squads/reinforcement economy (73-90, 1126-1381) vs
SquadSystem+MissionGenerator. `_build_night_env` (367-394) *copies mission_weather.gd's NIGHT numbers as
literals* — the comment admits it; any weather retune silently un-syncs the bench. And it
`add_to_group("game_world")` (234) — the exact group player.gd:469 and enemy_base.gd:293 resolve the
sight grid from — so core AI perception runs against an impostor grid. Bead qjf0 ("thin wrapper over
shared WorldBuilder") and probe dlox are OPEN; WorldBuilder exists in ADR-028/beads only, in zero .gd files.
Measured distance: arena shares AGENTS and ASSETS, derives 0% of world/sites/forces from the shared path.

**D2 — the bench tunes the game with levers the game doesn't have.** `ai_hp_multiplier: float = 1.5`
DEFAULT (ai_stress_arena.gd:121): every arena fight runs 1.5x-HP agents; campaign runs 1.0x. The arena is
also the declared feel benchmark (RULE #1) and the tuning lab for THE firefight dial
(`GameSettings.ai_vs_ai_cone_mult` pushed at :230). Balance conclusions drawn there are systematically off
on durability, and it mutates shared autoload state at boot: GibSystem.gib_lifetime_s (:228),
DamageSystem.set_terrain_manager(stub) (:238-241), MissionWeather.is_night=true (:350),
EnemySquad.tiering_enabled=false (:227). Process-scoped today, but every autoload write is a leak vector
for any harness that later instantiates game systems in the same process (overnight_bench/ps2_perf_probe do).

**D3 — the legacy select→briefing entry is a wired second front door.** `game_flow.gd:128`
`menu.start_pressed.connect(show_select)  # legacy path` → MissionSelectScreen → BriefingScreen →
start_mission with NO from_hub: skips hub, TOC, checkpoint save (189-191 gated on from_hub), insertion
economy framing. Unreachable from UI — `main_menu.gd:6` declares `start_pressed`, nothing emits it — but
alive in code and exercised by tests (test_full_loop.gd:45, test_seed_replay.gd:8). ADR-008:18,76-77
already convicted it. Under fossil law it is UNFINISHED-or-FOSSIL: either delete the connect + screens'
menu role (keep offer_for_seed as a static test API) or charter it explicitly as harness-only.

## 4. Verdict summary
The scene population is healthier than feared: exactly ONE playable canon path, and the probe fleet
overwhelmingly boots the real game_world (28+ files) — the right pattern already dominates. The drift is
concentrated in ONE scene (the arena) plus one dead menu wire and one old-era lab. Priority: land qjf0 +
dlox (arena on shared build, structural probe), zero the arena's default HP multiplier or surface it
on-screen, kill the start_pressed connect, archive terrain_lab.
