# Devil's Advocate — DEMO GAME (firebase-attack demo scene)
Date: 2026-07-29. Code read at HEAD; every claim carries a pointer per the Pointer Law.

## 0. The frame I attack from

The briefing says "standalone scene, precedent: ai_stress_arena / support_fire_range." That precedent
is misleading. The arena and the range are BENCHES: 200m flat boxes with stubs
(`scripts/levels/ai_stress_arena.gd:11-51` — TerrainManagerStub, FlatHeightmap, ArenaGrid — three
hand-rolled fakes just to keep the autoloads from crashing). The demo wants the OPPOSITE of a bench:
real terrain, real firebase stamp, real village/temple stamps, real siege. That is not the bench
precedent. That is a second GameFlow. The council should say that sentence out loud before blessing
anything, because a second GameFlow is a second world-boot path, and this repo has documented what
parallel boot paths become.

## 1. DRIFT RISK — the demo scene is a fork of the boot path, and forks are this repo's disease

What game_flow/mission_generator actually do to boot a world is not "instantiate game_world.tscn."
It is a long, ordered, stateful liturgy:

- `GameWorld._on_terrain_ready` wires FOUR autoloads by hand: DamageSystem gets terrain+vegetation,
  ClearingSystem gets terrain, grid gets ClearingSystem+WaterSystem (`scripts/levels/game_world.gd:152-177`).
- `MissionGenerator.plan_patrol_world` / `build_patrol_world` set static module state
  (`_set_fsb_keepout`, `scripts/missions/mission_generator.gd:101-106, 516, 651`;
  `dynamic_factory_ref`, `:272`) and wire SimClock, WorldSim, CampDirectors, AirTraffic, AmbientWar,
  ConvoySpawner, NavBaker, TerrainWatchdog (`:208-266, 711-727`).
- `MissionScope.reset()` exists because statics and autoloads leak BETWEEN worlds
  (`scripts/main/mission_scope.gd:25-43` — nine distinct leak classes, each proven by probe).
  A demo scene that boots without calling it inherits whatever the last main-game session left in
  the autoloads — and a demo scene the main flow never tears down will leak INTO the main game when
  someone tests both in one editor session.

Every one of those wiring steps is a place where game_world/mission_generator will evolve and
demo_game.gd will not. The precedent already proves it: `damage_system.gd:107` crashes against the
arena's stub because a crater retune assumed a real heightmap (`production/PERF_LEDGER.md`,
2026-07-18 W0 row, "inherited errors"). The arena rotted the moment the main game moved. That is the
demo's future, except the demo rots IN PUBLIC.

**What prevents fossilhood (and what each costs):**
1. demo_game.gd must COMPOSE, not copy: instantiate the real GameWorld, call the real
   plan_patrol_world/build_patrol_world with a demo-sized map, call the real MissionScope.reset().
   Zero duplicated wiring lines is the acceptance test. *Sacrifice:* the demo inherits every
   main-game bug and every main-game boot cost; you cannot "surgically" hand-build a prettier slice.
   That is the price and it is worth paying.
2. A probe in the suite that BOOTS demo_game headless every run (the arena precedent has this shape
   already). A demo that breaks when game_world changes must break the build, not the trade show.
   *Sacrifice:* suite time, and per the no-headless-tests law the owner runs it — so drift detection
   latency is "whenever the suite last ran," not "on commit."
3. Fossil-law clause written into the ADR now: the day the demo stops being shown, demo_game.tscn is
   DELETED, not archived. Name the burial date condition before birth.

## 2. PERF — the demo deliberately combines the two measured worst cases, before any perf work

The ledger's honest numbers (`production/PERF_LEDGER.md`):
- Night 18v18 arena, Forward+ native: **18.8 fps** (25.5 Mobile native; 29.9 Mobile at 0.75 scale —
  "NOTHING CLEARS THE 30 FPS GATE IN THE NIGHT ARENA," 2026-07-17 headline). Forward+ is decreed, so
  the Mobile rows are not an escape hatch.
- Shipped patrol world, 0.75 scale, standing at spawn, no combat: ~34 fps baseline; canopy is the
  only lever above noise (+6.3); sun shadow already off (2026-07-20 ship-parity run).
- Headless CPU: at 65-67 live units the AI physics wall was 38-40 ms/tick on the W0 tree, ~14-15
  ms/tick at HEAD — and the wall is the BODY (hitzone sync + move_and_slide + anim), not thinking
  (W0 row). SiegeDirector fields up to LIVE_CAP=50 materialized men (`siege_director.gd:36`) PLUS
  the player's squad, garrison, villagers — the demo's climax IS the 60+ unit case.

The arc "explore by dusk → siege at night" walks the audience from the best-measured pose into the
worst-measured one, with mortar craters (terrain rebuilds, `game_world.gd:464-488`) landing on top.
There is no measured row for "populated patrol world + full d50 siege, windowed" — the closest
proxies say roughly 20 fps on the target hardware. A public 20-minute demo at 20 fps during its own
climax is not honest — it is an anti-demo: it shows strangers the game's worst frame exactly when it
shows its best content.

**Minimum perf scope the demo MUST include (nothing more):**
1. The briefing already says it: the demo slice IS the perf bench arena. So the FIRST deliverable is
   a measured row — demo seed, demo map size, full siege forced via `open_siege(50)`
   (`siege_director.gd:142`), windowed, ledger entry with scale+renderer+seed. Before the end card,
   before the switchboard grows a UI. If that row reads <25 native, the perf gate moves INSIDE the
   demo scope; no honest week-one claim survives skipping this.
2. The 400x400 slice is itself the perf lever: fewer chunks, fewer billboards, smaller grid. Do not
   add another one. Specifically NO tri-hunting (measured: 33% prim cut moved fps ~0, ledger
   2026-07-16 Phase 1) — if anything must be chased, it is draw calls/canopy.
*Sacrifice:* the demo may end up decreeing a lower siege LIVE_CAP or a smaller d50 for demo builds —
which means the public sees a smaller assault than the design document promises. Name that in the
decree if it happens; do not let the switchboard hide it.

## 3. SCOPE — the honest week-one cut line

The plan is five features: demo director + switchboard + 400m slice + boundary + end card. Week one
that is three too many.

**Week one (the skeleton that proves the thesis):**
- demo_game.tscn/gd: real GameWorld at map_size≈400, fixed seed, real plan/build pipeline, real
  MissionScope.reset, player seated at the firebase.
- The switchboard as a CONST DICTIONARY at the top of demo_game.gd (see §4) — not a UI, not a
  resource, not a config file.
- Siege forced deterministically via the existing public `open_siege(forced_strength)` path, ring
  distances overridden through the existing host-override vars (`siege_director.gd:72-77`) sized to
  the 400m slice. The dusk→night arc can initially be `SimClock.set_time` + MissionWeather, driven
  by a 50-line stub — NOT a new DemoDirector class hierarchy.
- The perf row from §2.

**Explicitly cut from week one:**
- End card: a `print` and a fade. It is one evening of work LATER; it is scope-bait NOW.
- Boundary handling: at 400m the player who sprints for the edge in a 20-min guided demo is
  hypothetical. Ship week one with the map edge clamp that already exists (`_passable_near` clamps
  to 80m margins, `mission_generator.gd:131-132`) and a diegetic radio nag as the eventual design.
  A soft turn-back system is a NEW player-controller feature — it does not belong in a scene skeleton.
- Relief/end-card phase of the arc, "probing attack" as a distinct phase (the d50 PROBE_MAX≤11 rule
  already produces probes; do not build a second probe system next to it — that is exactly a
  divergent parallel system).
*Sacrifice:* week one produces something only the Summoner can watch, not something shippable to
strangers. Correct. A demo shown one week early at 20 fps costs more than a demo shown three weeks
late at 30.

## 4. THE SWITCHBOARD — toggles are how the ~14 parallel systems happened; discipline or don't build it

The failure mode is precise: a toggle that EXCLUDES a system creates a configuration of the game
that no test runs and no player plays, and code then gets written against that configuration.
The repo's own history: build_terrain_on_ready (`game_world.gd:45`) and spawn_player_on_ready
(`:18`) are exactly such toggles, added for probes — benign only because probes are not shipped.
A PUBLIC demo config is shipped, so its excluded-systems combination becomes a second LIVE truth.

**Discipline (each rule exists because its absence is a documented incident):**
1. The switchboard may only SKIP a wiring call that game_flow makes; it may never REPLACE one with a
   demo variant. Skip or full — no third implementation. (This is the anti-"14 parallel world-build
   systems" rule.)
2. One const Dictionary, in demo_game.gd, every key defaulting to the MAIN-GAME value, with the
   excluded list PRINTED at boot. A silent exclusion is a lie in the log; the siege's own live-cap
   deferral prints for exactly this reason (`siege_director.gd:260-261`).
3. Every toggle names its restore condition in a comment-of-constraint ("OFF until save system
   survives X") or it does not ship. An open-ended OFF is a fossil with a birthday.
4. Hard cap the count. If the switchboard needs more than ~6 toggles, the demo is not a slice of the
   game, it is a different game, and the council should hear that as a design finding.
*Sacrifice:* rule 1 means some half-ready system either ships in the demo warts-on or is wholly
absent — no flattering demo-only facade. That is the Fairness Law applied to marketing.

## 5. DETERMINISM — "fixed seed, same demo every boot" is false today, and mostly unfixably so

What IS seeded: world layout. plan/build take explicit RNGs from the op seed
(`mission_generator.gd:487-488, 646-647`), SiegeDirector seeds its own RNG from the firebase center
(`siege_director.gd:99`), LazyGroups get derived seeds (`:908`). Terrain, sites, cell composition:
reproducible.

What is NOT seeded — the global RNG, which Godot randomizes per boot:
- Every enemy's PERSONALITY: char_aggression/accuracy/reaction/self_preservation/aim_speed are bare
  `randf_range` (`scripts/enemies/enemy_base.gd:313-329`), plus fire timers, strafe timers, grenade
  rolls, downed rolls (`:1397-1454, 2091-2166`). 367 bare rand* calls across 45 script files
  (grep, 2026-07-29) — ai_marksmanship, gun_fx, civilian, air_traffic, siege spawn jitter aside.
- Time-based logic: campfire flicker off `Time.get_ticks_msec()` (`mission_generator.gd:416`),
  GunFX sting cooldown on absolute ticks (documented leak, `mission_scope.gd:15-16`), ambience off
  bare `randf` (`game_world.gd:286, 307, 370-374` — cosmetic, fine).
- The siege GATE: `_maybe_open` rolls against CampaignState.threat_label() and MissionWeather.is_night
  (`siege_director.gd:118-138`) — campaign-coupled and probabilistic. The demo must bypass it with
  `open_siege(N)`, which also pins the d50 and the 2d6 sapper split through the seeded local RNG.

**The honest claim the ADR should make:** the demo is LAYOUT-deterministic and SCRIPT-deterministic
(same world, same arc beats, same siege strength), NOT simulation-deterministic (a firefight will
never replay frame-identical — physics ticks + player input see to that even if every randf were
seeded). Chasing full determinism means threading a seeded RNG through 45 files of live AI — a
main-game-wide refactor smuggled in under a demo scene, violating briefing constraint 5. Do not do
it. *Sacrifice:* rehearsed demo lines ("watch, the sapper always breaches HERE") are unavailable;
the presenter must play the game, not a tape. Given Pillar 3, that is arguably the feature.

## 6. Named sacrifices, collected

1. Composition-only demo → the demo inherits main-game bugs live on stage; no facade allowed.
2. Perf-row-first → week one may end with a decree that shrinks the public siege below the d50 doc.
3. Week-one cut → nothing showable to outsiders for weeks; end card and boundary are IOUs.
4. Switchboard discipline → half-ready systems appear ugly or not at all; no demo-only polish fork.
5. Honest determinism → no rehearsable script; presenter risk on stage.
6. Suite probe → owner-run latency on drift detection; between suite runs the demo can silently rot.

## Bless condition

I bless the skeleton IF AND ONLY IF: demo_game.gd contains zero copied wiring (real GameWorld +
real plan/build + real MissionScope.reset, verified by a headless boot probe in the suite), the
switchboard is skip-only with a printed exclusion list, the first deliverable is a measured
PERF_LEDGER row of the forced full siege in the slice, and the ADR names the demo's deletion
condition. Absent any one of those, this is the fifteenth parallel world-build system with a
marketing budget.
