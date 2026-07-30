# DEMO AUDIT — BOOT PATH AND ARC CLOCK
Date: 2026-07-30. Method: static read only (no launch, no Blender). Every claim carries a
`file:line`. Anything I could not prove by reading is marked **UNPROVEN**.

Scope read: `scenes/levels/demo_game.tscn`, `scripts/levels/demo_game.gd`,
`scripts/main/game_flow.gd`, `scripts/missions/mission_generator.gd` (plan_demo_world,
build_patrol_world, _wire_systems), `scripts/levels/game_world.gd`,
`scripts/autoload/sim_clock.gd`, `scripts/autoload/campaign_state.gd`,
`scripts/autoload/save_manager.gd`, `scripts/missions/siege_director.gd`,
`scripts/world/mission_weather.gd`, `scripts/ai/air_traffic.gd`,
`tests/test_placement_paths.gd`, `project.godot`.

Only defects are listed. Ranked.

---

## P0-1 — THE NIGHT SIEGE IS FOUGHT IN BROAD DAYLIGHT, AND THE "DAWN" CARD FIRES AT 11:30

The arc clock counts REAL seconds (`demo_game.gd:168` `_clock += delta`). The world's clock runs
at **60x** (`sim_clock.gd:17` `real_to_sim_ratio = 60.0`) — one sim-hour per real minute. Nothing in
the demo changes that ratio.

Start hour: `plan_demo_world` sets `"time": "DUSK"` (`mission_generator.gd:661`);
`MissionWeather.setup` writes `SimClock.sim_hour = TIME_ID_START_HOUR["DUSK"] = 17.5`
(`mission_weather.gd:51`, table at `:40`). Period bounds: `sim_clock.gd:57-64`.

| real t | sim hour | period | arc beat |
|---|---|---|---|
| 0 | 17:30 | DUSK | boot, air opening |
| 90 | 19:00 | NIGHT | — |
| 600 | 03:30 | NIGHT | probe, 11 men (`demo_game.gd:26,173-175`) |
| **690** | **05:00** | **DAWN — sun comes up** | probe still running |
| **720** | **05:30** | DAWN | **main assault, 45 men** (`demo_game.gd:27,177-179`) |
| **780** | **06:30** | DAWN | **napalm/gun run "DANGER CLOSE"** (`demo_game.gd:105`) |
| 810 | 07:00 | DAY | full daylight |
| **1080** | **11:30** | DAY | **"DAWN. YOU HELD." end card** (`demo_game.gd:28,216-219`) |

Failure scenario: the player watches the 45-man assault, the illumination rounds
(`siege_director.gd:354-363`) and the napalm run happen under a risen sun, and is then told it is
dawn at half past eleven. `MissionWeather.is_night` flips false at t=690 (`mission_weather.gd:80-95`),
so night sight caps also drop mid-fight while the cells are still crossing the 220 m materialize ring
(`demo_game.gd:197`) — the exact "cells pop into view in daylight" artefact `game_flow.gd:301-305`
warns about for the `[J]` dev lens.

Fix directions (pick one, they are not compatible): drive the arc off `SimClock.sim_hour` instead of
real seconds; or start the demo at `"NIGHT"` (21:00 → dawn at real t=480, still before the assault);
or slow `real_to_sim_ratio` for the demo so 20 real minutes is one night.

## P0-2 — AFTER THE PROBE BREAKS, THE 45-MAN ASSAULT CAN NEVER BREAK, AND ITS KILL COUNT READS 0

`SiegeDirector.open_siege` only refreshes `run_peak` on the *roll* branch
(`siege_director.gd:192-198`): if `run_strength > 0 and nights_run != 0` it takes the `elif` and sets
`run_strength = forced_strength` **while leaving `run_peak` at the probe's value**.

State: probe opens at t=600 with strength 11 (`demo_game.gd:175`), `run_peak = 11`. The player kills
6 of 11 inside the next two minutes → `break_state(5, 11, …)` with `BREAK_BASE_RATIO 0.575`
(`siege_director.gd:30,296`) trips → `_break_siege("broken")`, which sets `run_strength = survivors`
(5) and leaves `nights_run = 1` (`:583-585`).

At t=720 `_open_siege(45)` sees `siege.active == false` (`demo_game.gd:201`) so it calls
`open_siege(45)` → `run_strength = 45`, **`run_peak` stays 11**. Consequences, all in `_run_siege`:
- `killed_count() = maxi(0, 11 - live)` (`:309-310`) → **0 for the entire assault**.
- `break_state(live=45, peak=11, …)` — ratio 4.09, never below 0.575 → the assault **cannot break**;
  it runs the full `MAX_DURATION_S 480` from 720 → dawn break at **t=1200**, 120 s *after* the demo
  has already shown the "FIREBASE HELD" card at t=1080.
- The eventual toast is `"FIRST LIGHT - THEY'VE MELTED AWAY (0 OF 11 DOWN)"`
  (`field_director.gd:1416`) — a visibly false number, printed behind an opaque end card.

The "wiped" path is fine (`:584` sets `run_strength = 0`, so the roll branch runs and peak = 45); the
`reinforce` path is fine (`:233-234` grows both). **Only the partial-break path is broken, and it is
the likeliest playthrough** — 6 kills in 120 s against 11 men in the open.

Fix: `open_siege` should set `run_peak = run_strength` whenever it takes the forced-strength branch
(or `maxi(run_peak, run_strength)`), and `_break_siege` should zero `run_peak` with `run_strength`.

## P0-3 — THE DEMO WRITES THE PLAYER'S REAL SAVE SLOTS, AND HIJACKS "CONTINUE"

`EXCLUDE_SAVES` only redirects the campaign `.cfg` (`demo_game.gd:46-47`). It does **not** touch
`SaveManager.save_dir`, which is sandboxed only for the headless suite
(`save_manager.gd:15,36-37`). So during a demo run:
- `enter_hub` writes slot 8 on entry: `SaveManager.save_game(SaveManager.AUTOSAVE_SLOT, "FIREBASE")`
  (`game_flow.gd:683`, `AUTOSAVE_SLOT = 8` at `save_manager.gd:17`).
- the 30 s autosave keeps writing slot 8 (`save_manager.gd:51-60`, `context == "hub"`).
- quitting writes slot 9 (`save_manager.gd:43-48`).
- F5 writes slot 0 (`save_manager.gd:63-69`).

Every one of those snapshots carries `hub_snapshot = {operation_seed: 29072026}`
(`game_flow.gd:483-485`, `demo_game.gd:51`) and `CampaignState.to_dict()`
(`save_manager.gd:110-117`).

Failure scenario: the owner plays the demo, then boots `main.tscn` and presses CONTINUE.
`latest_slot()` picks by timestamp (`save_manager.gd:243-250`) → the demo's slot 8 →
`load_from_slot` → `enter_hub` with `operation_seed = 29072026` and `demo_mode == false`, i.e. a
**900 m `plan_patrol_world` AO on the demo seed** — a world neither the demo nor the shipped
operation (47225, `game_flow.gd:466`) has ever been tested on. His real campaign entry point is gone
and the shipped AO is unreachable from CONTINUE.

Fix: in `demo_game._ready`, also set `SaveManager.save_dir = "user://saves_demo"` (and restore it in
`_exit_tree`), or gate `SaveManager.save_game` on `GameFlow.demo_mode`.

## P0-4 — THE DEMO INHERITS THE REAL CAMPAIGN (SANDBOX SWITCHES TOO LATE)

`CampaignState` is an autoload (`project.godot [autoload]`), so its `_ready` runs **before the main
scene exists** and calls `load_campaign()` against `DEFAULT_SAVE_PATH`
(`campaign_state.gd:191-196,13`). `demo_game._ready` only redirects `save_path` afterwards
(`demo_game.gd:46-47`).

Failure scenario: the demo boots with the owner's live `threat_level`, `reputation`, `roster`,
`missions_played`, `kia_total`, `ward_wounded`, `bags_unlifted`, `rack_condition` and `depot_loss`
already in memory. Concretely: `armorers_bench.gd:152` racks by
`CampaignState.title_tier()`, so the demo's available weapons depend on his campaign rank;
`rack_condition` means the demo can hand him a fouled rifle; `depot_loss` docks demo fire support for
a breach that happened in the real campaign. The sandbox only protects the *write* direction, and
`demo_game.gd:19`'s comment ("campaign writes go to a sandbox file") is accurate but incomplete —
nothing states the reads leak.

Fix: `demo_game` must call `CampaignState.reset_campaign()` (or `load_campaign()` after repointing
`save_path`) once it owns the sandbox path.

---

## P1-5 — THE ARC BOOTS THE WORLD TWICE, WITH THE WRONG SEED FIRST

`GameFlow._ready` unconditionally calls `start_default_operation()` (`game_flow.gd:24-29`), and
`demo_game._ready` creates the flow with `add_child` — which runs `_ready` synchronously — *then*
calls `_begin_operation(DEMO_SEED, …)` (`demo_game.gd:49-51`).

Trace: `add_child(_flow)` → `enter_hub()` #1 with `op_seed = 47225`, `_world_entry = 1`
(`game_flow.gd:538,546-551`); it instantiates `game_world.tscn` and `add_child`s it
(`:574-579`), whose `_ready` kicks off the detached terrain coroutine
(`game_world.gd:48-52`, `await terrain_manager.generate_terrain` at `:125`), then parks on
`while not world.is_world_ready: await …` (`game_flow.gd:580-583`). Control returns to
`demo_game._ready`, which calls `_begin_operation(29072026)` → `enter_hub()` #2 → `_world_entry = 2`
→ `_teardown_world()` frees world #1 mid-terrain-generation (`:374-381`) and builds world #2. The
stale coroutine bails on `entry != _world_entry` (`:582-585`), so no second FieldDirector — that
guard works.

Cost/failure: one full `game_world` instantiate plus a started terrain generation thrown away on
every demo boot, plus a `_teardown_world()`/`CampaignState.commit_mission()` before anything exists.
Whether world #1's coroutine can reach `DamageSystem.set_terrain_manager` / 
`ClearingSystem.set_terrain_manager` (`game_world.gd:153-156`) *after* world #2 has set its own — and
so leave the autoload singletons pointing at a freed terrain — is **UNPROVEN**: it depends on whether
the coroutine resumes before the deferred `queue_free` lands. If it can, it is a P0.

Fix: the demo should not let `GameFlow._ready` auto-start. Give `GameFlow` a `bool auto_start = true`
set to false before `add_child`, or have `demo_game` set a static "operation override" that
`start_default_operation()` reads.

## P1-6 — THE END CARD IS AN OPAQUE, UNDISMISSABLE OVERLAY OVER A STILL-RUNNING GAME

`_dawn()` builds the card on `ReconUI.make_screen_root()` (`demo_game.gd:222`), which is a
full-rect background texture plus a 72 %-opacity scrim (`recon_ui.gd:50-64`), on a `CanvasLayer` with
`layer = 90` (`demo_game.gd:239-242`). Nothing pauses, nothing releases the mouse (still
`MOUSE_MODE_CAPTURED` from `game_flow.gd:682`), and nothing accepts input to dismiss it.

Failure scenario: at t=1080 the screen goes opaque while the siege is still fighting underneath
(see P0-2) and the demo cannot be exited except by Alt+F4 — `Esc` still reaches
`GameFlow._unhandled_input` (`:32-41`) and builds a `PauseMenu` under the demo's `layer = 90` card,
so the pause menu is invisible. (That the PauseMenu uses a lower layer is **UNPROVEN** — I did not
read `pause_menu.gd`; if it is layer > 90 the menu is usable.)

## P1-7 — THREE OF THE FOUR SWITCHBOARD FLAGS ARE READ BY NOTHING

Repo-wide grep for `EXCLUDE_` (`--include=*.gd`) returns only `demo_game.gd:19-22` (declarations),
`:42-45` (the print loop) and `:46,58` (`EXCLUDE_SAVES`). So:

- `EXCLUDE_DEBRIEF := true` (`:20`) is **inert**. `enter_hub` connects
  `director.mission_failed` → `_on_mission_ended` (`game_flow.gd:634`), which runs the full
  campaign debrief pipeline: `squad.on_mission_end()`, `bank_reputation`,
  `CampaignState.on_mission_end`, Iron-Man `reset_campaign`, then `DebriefScreen` after 3 s
  (`game_flow.gd:426-456`). Failure scenario: the player dies at t=800 mid-assault → he gets the AAR
  screen the switchboard says was excluded, `_teardown_world` frees the world, and
  `demo_game._physics_process` stalls on `_flow.director == null` (`demo_game.gd:166`) with `_clock`
  frozen at 800 and `_phase = 2`. Pressing CONTINUE re-enters the hub (`:453-455`, seed non-zero),
  and the arc resumes from 800 s into a brand-new world: no air opening (`_air_next` is already past
  the table, `:149`), both napalm beats already flagged done (`:108-109`), and `_dawn()` firing 280 s
  later on a firebase that was never attacked.
- `EXCLUDE_AIR_TRAFFIC` / `EXCLUDE_AMBIENT_WAR` (`:21-22`) are read by nothing either. Both are
  currently `false`, so no live defect — but flipping either to `true` prints
  `[DEMO] EXCLUDED: air_traffic` and changes nothing, while `AirTraffic`/`AmbientWar` are still
  created unconditionally in `_wire_systems` (`mission_generator.gd:254-259`). Worse, if
  `EXCLUDE_AIR_TRAFFIC` were ever honoured, `_tick_air`'s `get_node_or_null("AirTraffic")` returns
  null and the whole air arc silently vanishes with no warning (`demo_game.gd:144-147`) — the
  "skip leaves a null reference" bug class, latent.

The header claims the switchboard "may EXCLUDE systems" and that "a flag flipped true prints at boot
so an excluded system is never a mystery" (`:17-18`). It prints; it does not exclude.

## P1-8 — FRESH-EVER BOOT LEAVES THE AID STATION EMPTY, AND THE BUTCHER'S BILL IS READ BY NOTHING

Two halves of the same finding.

a) `WARD_SEED_ON_NEW_TOUR = 2` is applied **only** in `reset_campaign()`
(`campaign_state.gd:65,458-462`). On a first-ever boot `load_campaign()` hits
`ERR_FILE_NOT_FOUND` and returns early (`:330-341`), leaving the field initialisers — so
`ward_wounded = 0` (`:60`). Failure scenario: virgin install (or first demo run, once P0-4 is fixed
and the sandbox is genuinely empty) → the aid station is empty, which is precisely the fresh-player
failure the comment at `:458-462` says the seed exists to prevent. The seed only fires after an
Iron-Man wipe (`game_flow.gd:442`) or an explicit reset.

b) Grep repo-wide (`--include=*.gd --include=*.tscn`) for `kia_total|ward_wounded|bags_unlifted|
WARD_BEDS_MAX|WIA_PER_KIA` outside `campaign_state.gd` returns exactly one hit, and it is a comment:
`heli_lift.gd:16`. **Nothing reads these three fields.** They are accumulated
(`campaign_state.gd:255-270`), persisted (`:320-322`), snapshotted (`:405-407`) and reset
(`:456-462`) — and no stretcher, body bag or ward prop anywhere consumes them. As written today the
butcher's bill is a write-only ledger; the visible aid station his 2026-07-30 decree describes does
not exist yet. (Whether that art/prop work is simply unfinished is out of my slice, but the fields
are currently fossil-shaped: written, never read.)

---

## P2-9 — THE AMBIENT AIR/EVENT SCHEDULE DIES 6.5 REAL MINUTES INTO THE DEMO

`AirTraffic._seed_default_schedule` books events for **`SimClock.sim_day` only**
(`air_traffic.gd:86-93`), and `_tick_schedules` requires `s_day == -1 or s_day == sim_day`
(`sim_clock.gd:87-88`). The demo starts at 17:30 on day 1, so only hours 18–23 can ever match. The
day rolls at real t = (24 − 17.5) × 60 = **390 s** (`sim_clock.gd:46-48`), after which **no scheduled
flight can ever fire again** for the rest of the run.

In the demo the arc's own 42 s cadence masks it (`demo_game.gd:80,155-162`), so the visible symptom
is only that the sky's variety collapses to `AIR_ROTATION`. In the *real* game this is a plain bug:
all ambient air traffic stops permanently at the first midnight.

Also: `AIR_MAX_IN_SKY = 14` gates only the demo's own launches (`demo_game.gd:159`), never the
scheduled ones, so during the first 390 s the sky can exceed the stated cap. Call-bound project
(`:81-83`), so worth knowing the cap is not a cap.

## P2-10 — THE OPENING HOUR IS SET TWICE, TO TWO DIFFERENT HOURS, AND EATS ONE SCHEDULED FLIGHT

`_wire_systems` sets `SimClock.set_time(sim_day, 18.0)` for `"DUSK"`
(`mission_generator.gd:238-246`), and `set_time` fires `_tick_schedules` immediately
(`sim_clock.gd:100-104`). `MissionWeather.setup`, which runs later in `enter_hub`
(`game_flow.gd:641-643`), then rewinds the clock to **17.5** (`mission_weather.gd:40,51`).

Failure: the hour-18 `air_traffic` event fires *during world build* and its key is recorded in
`_fired_event_keys` (`sim_clock.gd:92-95`), so when the clock legitimately crosses 18:00 thirty real
seconds later it is skipped. Two authorities for the opening hour, disagreeing by 30 sim-minutes.

## P2-11 — `reinforce()` RE-EMITS `siege_began`, SO THE GARRISON STANDS TO TWICE

`reinforce` ends with `siege_began.emit(...)` (`siege_director.gd:247`), wired to
`_on_siege_began` (`field_director.gd:1367`), which calls `_garrison_stand_to()` and, for a
non-probe, `_sound_siren()` (`:1372-1383`). At t=720 the probe→assault escalation therefore replays
stand-to and sounds the siren on a garrison that has been stood-to since t=600. Cosmetic/audio, but
it is a second "STAND TO" toast on top of the demo's own "HERE THEY COME" (`demo_game.gd:179`).

## P2-12 — `to_dict()`/`from_dict()` DO NOT MIRROR WHAT `save_campaign()` PERSISTS

The comment at `campaign_state.gd:387-388` claims the slot snapshot "mirrors exactly what the cfg
persists, so the two stores can never disagree". It does not: `save_campaign` writes
`reported_marks`, `lifetime_intel`, `next_stash_at` and `ears_taken` (`:316-319`), and none of the
four appear in `to_dict` (`:389-408`) or `from_dict` (`:411-432`). This is the same defect the
comment at `:424-426` records having fixed for `field_marks`.

Failure scenario: player loads a slot older than his `.cfg`. `from_dict` restores the old
reputation/roster/marks but leaves the *newer* `reported_marks` and `ears_taken` in memory, and the
following `save_campaign()` (`save_manager.gd:191`) writes that mixture back. The third ink survives
a rollback it should not have survived. Low impact, but the two stores demonstrably disagree.

## P3-13 — SAVE_VERSION NOT BUMPED FOR THE 2026-07-30 FIELDS: SAFE, WITH ONE CAVEAT

Judgement: **safe as written.** `kia_total`/`ward_wounded`/`bags_unlifted` are additive keys read
through `cfg.get_value(..., 0)` (`campaign_state.gd:369-371`), so a pre-07-30 v1 file loads with
zeroes (the stated intent, `:367-368`), and an old build reading a new file sees `version == 1`,
takes neither the refuse branch nor the migrate branch (`:343-349`), and ignores the unknown keys.
No corruption path exists in either direction.

Caveat: because there is no version boundary, `_migrate` can never distinguish "a save that predates
the butcher's bill" from "a save whose bill is genuinely zero" — which is exactly the distinction
P1-8(a) needs if the ward seed is ever applied to existing tours. The cost of not bumping is not
corruption, it is that the fix for P1-8(a) has nowhere to hook.

## P3-14 — MINOR / FOSSIL-SHAPED

- `demo_game.gd:188-189` `if d.siege == null: d._attach_siege()` is dead: `setup_patrol` already
  attaches the siege (`field_director.gd:1088`), and `setup_patrol` is called at
  `game_flow.gd:631`, before the arc ever ticks. The follow-up `if d.siege == null` at
  `demo_game.gd:198-200` is likewise unreachable.
- `demo_game.gd:165-168` `_physics_process` does not cap `delta` (project pattern:
  `minf(delta, 0.066)`, CLAUDE.md). A long hitch advances the arc by the whole stall.
- `demo_game.gd:144` resolves `world.get_node_or_null("AirTraffic")` every physics frame instead of
  caching it once.
- `plan_demo_world` reaches into `SitePlanner` privates — `planner._reserved` (`:671`) and
  `planner._fsb_rect` (`:684`) — mirroring `plan_patrol_world` (`:507,517`). Not a defect, but two
  call sites now depend on a private field.

---

## THINGS I CHECKED AND FOUND CLEAN (no action)

- **Placement-path contract (audit item 4).** The demo does boot the real flow: `demo_game` only
  sets `demo_mode`, and the fork is one ternary inside `enter_hub` (`game_flow.gd:594-596`).
  `plan_demo_world` lives in `mission_generator.gd`, which is in
  `test_placement_paths.CALLER_MANIFEST` (`tests/test_placement_paths.gd:17-20`), and there is still
  exactly one `build_patrol_world` definition (`:86-98`). No second placement path, no second
  orchestrator. `plan_demo_world` draws only from a seeded local `rng` (`mission_generator.gd:655-656`),
  satisfying the SEEDED_FILES rule (`:30-37`).
- **Double-FieldDirector re-entrancy.** The `_world_entry` generation guard
  (`game_flow.gd:538,582-585`) correctly kills the stale coroutine from P1-5.
- **Beat ordering on the arc.** `_tick_napalm`'s `if/elif` (`demo_game.gd:116-126`) cannot fire both
  strikes in one frame, and the two are 620 s apart. The `match _phase` ladder
  (`:171-183`) needs one frame per transition but every threshold is ≥120 s apart, so no beat is
  swallowed by an earlier guard.
- **Spontaneous siege before the arc.** `_maybe_open` is blocked by `director.patrol_count < 1`
  (`siege_director.gd:180`) and the player starts inside the wire, so the RNG cadence cannot
  pre-empt the authored probe.
- **`demo_mode` leak.** `_exit_tree` clears the static and restores `DEFAULT_SAVE_PATH`
  (`demo_game.gd:56-59`), and Godot propagates `_exit_tree` children-first, so the flow's teardown
  writes still land in the sandbox. (Ordering is from engine semantics, not a pointer — **UNPROVEN**
  by reading this repo alone; the P0-3 slot leak is the real save hazard regardless.)
