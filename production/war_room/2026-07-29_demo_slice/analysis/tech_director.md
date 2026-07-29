# Technical Director — DEMO GAME architecture (2026-07-29)

Every claim below is cited `file:line`. Read set: `game_world.gd`, `ai_stress_arena.gd`,
`support_fire_range.gd`, `mission_generator.gd`, `siege_director.gd`, `field_director.gd`,
`mission_scope.gd`, `game_flow.gd`, `site_planner.gd`, `terrain/core/terrain_manager.gd`,
`scripts/levels/world_config.gd`, `scripts/autoload/campaign_state.gd`, `scripts/squad/squad_roster.gd`.

---

## 1. The precedent: how standalone scenes boot today

Two patterns exist, and the demo wants the **third** point between them.

- **support_fire_range** (`scripts/levels/support_fire_range.gd:21-28`): pure hand-built —
  flat StaticBody ground, one light, player instanced directly, `GameManager.player = player`
  set by hand (`:78`), FieldDirector wired via `FireSupportBench.wire` (`:26`). No GameWorld,
  no terrain, no campaign. Launched as `godot --path . res://scenes/levels/support_fire_range.tscn`
  (`:9`) — the campaign root `scenes/main/main.tscn` (`project.godot:21`) is simply never loaded,
  so GameFlow never exists. **That is the whole standalone trick: bypass, not disable.**
- **ai_stress_arena** (`scripts/levels/ai_stress_arena.gd:287-338`): fakes the world contract —
  joins the `"game_world"` group itself (`:302`), builds an `ArenaGrid` (`:39-51, :630`), and plugs a
  `TerrainManagerStub` into DamageSystem (`:306-309`) because DamageSystem is an autoload that expects
  a terrain_manager. It proves SiegeDirector already runs outside the campaign: `_siege` driven on
  demand (`:279`, siege constants scaled into the 200m box `:84-89`).
- **game_world.gd is already a component, not a level**: `mission_seed`, `map_size`,
  `spawn_player_on_ready` are exports (`game_world.gd:15-18`), `build_terrain_on_ready` exists for
  probes (`:41-46`), and GameFlow itself instances it as a child and awaits `is_world_ready`
  (`game_flow.gd:438-443`). The demo does exactly what GameFlow does, minus GameFlow.

**The demo is NOT an arena-style fake.** It needs real terrain, real stamps, real siege — so it is a
thin re-implementation of `GameFlow.enter_hub()` (`game_flow.gd:410-542`) with the campaign organs
left out. That function is the boot-order document of record; copy its sequence, not its code.

## 2. Scene tree + boot order

`scenes/levels/demo_game.tscn` = one root Node3D with `demo_game.gd`. Everything else is built in
`_ready`, exactly like the range does. Proposed runtime tree:

```
DemoGame (Node3D, demo_game.gd)           ← switchboard consts live here
├── GameWorld (instanced game_world.tscn)  ← terrain/env/water/grid/player/HUD, untouched
│   ├── FieldDirector                      ← child of world, as in game_flow.gd:448-449
│   │   └── SiegeDirector                  ← attached by director.setup_patrol (field_director.gd:993,1260-1267)
│   ├── SquadSystem                        ← game_flow.gd:486-489 pattern
│   ├── MissionHUD                         ← game_flow.gd:496-499 pattern
│   ├── MissionWeather                     ← game_flow.gd:500-502 pattern
│   └── (stamped sites, LazyGroups, MGEmplacements…)
└── DemoDirector (Node, demo_director.gd)  ← the arc-clock stub; OUTSIDE the world so a
                                             world teardown/retry never kills the clock
```

**Boot order** (each step's campaign twin cited):

1. `MissionScope.reset()` — GameFlow calls it only in `_teardown_world` (`game_flow.gd:258`); the
   demo has no GameFlow, so it must sweep the statics itself (`mission_scope.gd:25-43`). Cheap
   insurance for editor F5 runs and any future "demo from menu" route.
2. **Campaign sandbox** (see coupling table §5): redirect `CampaignState.save_path` to
   `user://campaign_demo.cfg` and reset — the mechanism already exists for tests
   (`campaign_state.gd:7-13`, `TEST_SAVE_PATH`).
3. `SimClock.clear_schedules()` + `SimClock.set_time(day, 18.0)` (DUSK) — the generator does the
   same before wiring (`mission_generator.gd:211-246`).
4. Instance `game_world.tscn`: `mission_seed = DEMO_SEED`, `map_size = DEMO_MAP_M`,
   `spawn_player_on_ready = false` (`game_world.gd:15-18`); `add_child`; await `is_world_ready`
   (`game_flow.gd:442-443` polls the same flag).
5. `FieldDirector.new()` → `world.add_child` → `setup(world)` → `state.seed_value = DEMO_SEED`
   (`game_flow.gd:448-451`; `field_director.gd:17-30` needs only the world + autoloads).
6. **Demo plan** (§4) → stamp/build → `built` dict.
7. `world.spawn_player_at(...)` → `SquadSystem.setup(world, director, spawn)` →
   `director.squad_system = squad` → `director.setup_patrol(built)` — this last call is what
   attaches the siege (`field_director.gd:986-993`, `_attach_siege` `:1260-1267`).
8. MissionHUD (`setup(world, director, plan)` takes the plan dict, `game_flow.gd:498`),
   MissionWeather with fixed `("CLEAR","DUSK")` (`game_flow.gd:500-502`).
9. DemoDirector starts its phase clock.

## 3. Fixed seed

Determinism is already the house style: one const seed boots the same AO every launch
(`game_flow.gd:335` `DEFAULT_OPERATION_SEED := 47225`, `mission_generator.gd:57-73` derive
codename/weather from it, ADR-010). The demo does the identical thing with its own
`const DEMO_SEED: int` feeding `world.mission_seed` (vegetation `game_world.gd:107`, terrain
`:125`, grid `:173`) and every plan RNG. **Do not roll weather/time from the seed** — the demo arc
decrees DUSK; pass conditions explicitly instead of via `conditions_for` (which the campaign plan
calls at `mission_generator.gd:490`).

One determinism caveat: parts of spawn variance draw from the **global** RNG stream, not seeded RNGs
(the arena notes this at `ai_stress_arena.gd:193`, "combat spread itself draws from the global
stream"). World layout will be identical every boot; the fight itself will vary. That is fine for a
demo and matches the campaign's own determinism contract.

## 4. Generation reuse: compose the stamps, do not call the campaign plan

`plan_patrol_world` (`mission_generator.gd:486-642`) is tuned for a 1280m AO: villages 240–470m from
the gate (`:531`), camps 400–540m (`:560`), temples 320–560m (`:575`), `_passable_near` clamps
candidates to `80..map_size-80` (`:131-132`). On a ~500m slice those bands collapse onto the clamp —
you would get sites piled on the map edge, not a designed slice. **Do not fork the plan; author a
demo plan dict** in `demo_game.gd` with hand-chosen (still seed-jittered) site positions, in the
same shape (`seed/codename/weather/time/sites/enemy_groups/first_signs/...`), then reuse the
**build-side single implementations** unchanged:

- Firebase: `planner.place_firebase_main(center)` + `MissionGenerator._build_firebase_garrison`
  (`mission_generator.gd:653-655`, `:774-804` — garrison, MG posts via `MGEmplacement.create` `:816`).
  Pin `fsb_center` yourself; **do not call** `plan_firebase_main_center` (needs
  `FSB_HALF.x + FSB_EDGE_MARGIN = 209.3m` of clearance per side, `site_planner.gd:650,652,857-858`).
  Call `MissionGenerator._set_fsb_keepout(center)` first (`mission_generator.gd:101-106`) — the
  keep-out is a static consumed by every sampler.
- Village: `MissionGenerator._build_village_site(...)` — explicitly "ONE implementation" shared by
  all flows (`mission_generator.gd:819-857`): stamp + civilians + households + chickens + campfire.
- Temple: `planner.stamp_temple_shrine` (`:664`). Camp: `planner.stamp_vc_camp` (`:662`).
- Enemies: `MissionGenerator._spawn_enemy_groups(world, director, p, rng)` (`:898-919`) — LazyGroups
  for dormant, `director.spawn_tracked_enemy` for hot; single spawn authority preserved.
- Optional layers, each behind a switch: roads (`RoadNetwork.build` `:588-590` + corridor clear
  `:706-709`), NavBaker (`:711-721`, gated on `WorldConfig.NAV_ENABLED`), `_wire_systems`
  (`:723`) — **note `_wire_systems` is monolithic**: it spawns CampDirectors, convoy, AirTraffic,
  AmbientWar, DynamicMissionFactory in one call (`:208-266`). For switchboard granularity the demo
  calls its pieces directly (`_attach_camp_directors`, `AirTrafficScript.new()`…) rather than the
  bundle. GDScript has no privacy; calling these statics is composition, not forking — every
  implementation stays single-sourced (fossil law satisfied: zero copies).
- First-sign craters + `apply_veg_boosts` (`:665-669`, `:924-937`) — both position-driven, reusable
  as-is.

## 5. Coupling list — every place a reused system assumes the campaign exists

| # | Coupling | Pointer | Exclusion strategy |
|---|----------|---------|--------------------|
| 1 | **SquadRoster writes the real campaign file on boot** — `ensure_roster` reads `CampaignState.roster` and calls `save_campaign()` | `squad_roster.gd:168,201-202`; also `squad_system.gd:447,457` | **Sandbox, don't stub**: set `CampaignState.save_path = "user://campaign_demo.cfg"` + `reset_campaign()` in demo `_ready` before anything touches the roster. Exact mechanism tests already use (`campaign_state.gd:7-13`). Roster/rank/threat then run live inside the demo, harmlessly. |
| 2 | **FieldDirector banks patrols into the campaign** — wire-gate crossing calls `CampaignState.begin_mission` (`field_director.gd:1074`) and `_bank_patrol` runs `bank_reputation` / `on_mission_end` / `commit_mission` + `DebriefScreen.compute_score` (`:1398-1411`) | `field_director.gd:1066-1089,1398-1411` | Covered by #1's sandbox — leave it LIVE. Rep/rank toasts working in the demo is free flavor; forking the director to suppress them is the forbidden move. |
| 3 | **Fire-support allotment persists depot losses** — `CampaignState.depot_loss` + `save_campaign()` | `field_director.gd:1128-1133,1245-1254` | Sandbox (#1). |
| 4 | **Siege never opens on its own in a demo** — cadence gates on `MissionWeather.is_night` (`siege_director.gd:125`), `director.patrol_count >= 1` (`:133`), and a `CampaignState.threat_label()` chance roll (`:136`) | `siege_director.gd:118-138` | Demo arc drives `siege.open_siege(strength)` directly — public exactly for this ("probe drives the assault without fighting the RNG gate", `:141-142`). Probes = `open_siege(n <= PROBE_MAX 11)` (`:17`), main siege = forced d50. Ring geometry is override-able for small maps by design (`:68-76`); at ~500m the defaults (RING 300–500, `:20-21`) barely fit — set `ring_min/ring_max/rally_m/mortar_standoff_m` from the switchboard. |
| 5 | **Debrief / end screens are GameFlow's** — `_on_mission_ended` → `DebriefScreen`, hub return | `game_flow.gd:295-325` | Never instanced (no GameFlow). Demo connects `director.mission_failed` to its own end-card. DemoDirector owns relief/end card. |
| 6 | **Saves** — autosave on hub entry (`game_flow.gd:542`), pause-save (`:213-219`), `SaveManager.apply_pending_player` (`:509`) | `game_flow.gd` | Never runs — all GameFlow methods. Demo scene simply does not call SaveManager. Campaign persistence is OFF by construction, not by flag. |
| 7 | **Dynamic mission offers** — DynamicMissionFactory hooks convoy ambush | `mission_generator.gd:263-280` | Behind the CONVOY/OFFERS switch; simply not constructed. `_wire_convoy_to_factory` no-ops on a null static (`:277-280`). |
| 8 | **Static/autoload leakage between runs** — `MissionScope.reset()` is invoked only by `GameFlow._teardown_world` | `game_flow.gd:258`; `mission_scope.gd:25-43` | Demo calls it first thing in `_ready` (and on quit). |
| 9 | **`GameManager.player`** must be set for siege mortars / systems that read it | `siege_director.gd:313`; precedent `support_fire_range.gd:78` | `game_world.spawn_player_at` path already runs in-world; verify `GameManager.player` assignment happens (GameFlow doesn't set it explicitly — player.gd does; if not, one line per the range precedent). |
| 10 | **SimClock schedules outlive worlds** (autoload) | `mission_generator.gd:210-213` | `SimClock.clear_schedules()` + `set_time` in demo boot (§2 step 3). |

## 6. The switchboard: consts in demo_game.gd, not a resource

**Recommendation: a `const` block at the top of `demo_game.gd`.** Reasons, all local precedent:
`WorldConfig` is exactly this pattern and it works (`scripts/levels/world_config.gd:1-43`, "single
tuning point… edit + reboot"); consts are greppable and diff-reviewed (a `.tres` toggle is invisible
in review and becomes POINTER-LAW drift); the arena's `@export` toggles (`ai_stress_arena.gd:145-194`)
are for *per-run inspector fiddling*, which is not what "systems we might not be ready to share" means
— a share-gate must be committed text. Shape:

```gdscript
const DEMO_SEED: int = 62901
const DEMO_MAP_M: float = 512.0          # see §7 — 400 doesn't fit the firebase
const SYS_VILLAGE := true
const SYS_TEMPLE := true
const SYS_VC_CAMP := true
const SYS_ROADS := false                 # no convoy on a 500m slice
const SYS_CONVOY := false
const SYS_AIR_TRAFFIC := true            # ambience only
const SYS_AMBIENT_WAR := true
const SYS_CIV_SCHEDULES := true
const SYS_NAV := true
const SYS_RADIO_SUPPORT := true          # _grant_fire_support tiers
const SYS_FRIENDLY_PATROLS := false
const SYS_SAVES := false                 # documentary only — saves are off by construction (§5.6)
```

Each `SYS_*` gates one composition call in the build step — one line each, readable in one screen.

## 7. The 400×400 question — can TerrainEngine do it TODAY?

**Yes — nothing is hardcoded to 1280m, but 400 exactly is the wrong number.**

- `WorldConfig.MAP_SIZE = 1280.0` is a **const default**, not a limit (`world_config.gd:9`);
  `GameWorld.map_size` is an export defaulting to it (`game_world.gd:16`) and is passed straight into
  the manager (`:98`). `TerrainManager.map_size` is itself an export (`terrain_manager.gd:18`) and the
  heightmap is built from it (`:57`). The generator, grid (`game_world.gd:172`, 256 cells over
  `map_size`), water, and clearing mask (512 texels over the map, `terrain/systems/clearing_system.gd:57`;
  consumed as `map_size/512` at `game_world.gd:497-501`) are all resolution-relative. The
  `"terrain_size": 385` at `game_world.gd:138` is only the pre-generation placeholder, overwritten
  from the real heightmap at `:453-457`.
- **Two constraints pick the real number:**
  1. `chunks_per_side = ceil(map_size / chunk_size)` (`terrain_manager.gd:48`) with
     `CHUNK_SIZE = 256` (`world_config.gd:10`): 400 → 2 chunks → 512m of chunk grid over a 400m
     heightmap, i.e. 112m of edge chunks sampling past the heightmap. Use a multiple of 256.
  2. **The firebase itself is ~299m × 222m** (`FSB_HALF := Vector2(149.3, 111.2)`,
     `site_planner.gd:650`) with a 215m flatten radius (`:653`). A 400m map is barely one firebase
     wide; `plan_firebase_main_center` needs `2×(149.3+60) ≈ 419m` minimum (`:857-858,652`).
- **Ruling requested: DEMO_MAP_M = 512.0** (2×2 chunks, exact). Firebase pinned at center leaves a
  ~100–140m explorable band to the edge on each side — village and temple sit in it. If the council
  wants more air, 768 (3×3) is the next honest rung. The briefing's "~400" intent is met; 512 is
  simply the engine's nearest clean seam.
- **Edge handling**: `_passable_near` already clamps all generated content to `80..map_size-80`
  (`mission_generator.gd:131-132`), so nothing spawns at the rim. For the player: no walls (Freedom
  pillar) — propose a soft turn-back in DemoDirector (RTO bark "we're off the map, turn back" +
  the existing wildlife-duck/fog vocabulary at the last 30m); a physical proposal belongs to the
  designers, but the *mechanism* slot is a 1Hz distance poll in DemoDirector, nothing engine-side.

## 8. DemoDirector stub

`scripts/levels/demo_director.gd`, phases as a plain enum + clock:
`ARRIVE_DUSK → EXPLORE_PREP → PROBE → MAIN_SIEGE → RELIEF/END_CARD`. It owns only: SimClock time
pushes (via `SimClock.advance`, never `set_time` mid-run — the GameFlow dev-lens comment is the law,
`game_flow.gd:44-47`), `siege.open_siege(n)` calls (probe ≤11, main = forced strength; re-arm via
`nights_run = 0` per the dev lens `game_flow.gd:164-167`), edge turn-back poll, and the end card.
Pacing values are consts at its top, tuned by playtest later. It forks nothing: every verb it speaks
already exists as a public call.

## 9. What is sacrificed (named, per the law)

- **~500m, not 400×400**: the firebase's authored footprint (`site_planner.gd:650`) makes a literal
  400 slice impossible without shrinking the base — which would fork the one firebase. 512 it is.
- **No convoy/roads by default**: a 3–6 vehicle convoy (`mission_generator.gd:357-358`) has no room
  to drive on a 512m slice; the roads switch ships OFF.
- **Demo plan dict is demo-only code**: ~60 lines of authored site positions that the campaign never
  runs. It is data-shaped, not a system fork, but it is the one thing in this design with no campaign
  twin — flagging it so nobody later "unifies" it back into `plan_patrol_world`.
- **Global-RNG combat variance** (§3): the demo is layout-deterministic, not replay-deterministic.
