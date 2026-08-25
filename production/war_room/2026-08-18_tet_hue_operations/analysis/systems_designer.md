# SYSTEMS-DESIGNER — Independent Sight: Tet/Hue Operations
**Date:** 2026-08-18 · **Phase:** Individual Sight (no cross-talk) · **Scope:** post-demo roadmap shaping
**Probed:** game_flow.gd · mission_generator.gd · siege_director.gd · marching_cell.gd · field_director.gd · save_manager.gd · campaign_state.gd · helicopter.gd · heli_lift.gd · air_traffic.gd · nav_baker.gd · ADR-028

---

## 0. Position on the fiction↔history dial (required)

**Dial position: "1968 as WEATHER, not as SCRIPT."** Tet should enter the game as a campaign-clock
state that recolors the systems we already run (threat tiers, siege cadence, ambient encounters, air
traffic), and Hue should enter as a *fictional city in the Hue style* — the way the firebase is a
fictional FSB in the real pattern. The code is on this side of the dial already: escalation is a
threat-label pipeline (`campaign_state.gd:207-225`, consumed at `field_director.gd:1448-1511`), not a
date table. A hard-dated historical campaign would require a second, parallel progression authority
and would break the seeded-tour premise the 7/28 decree protects. Systems verdict: history supplies
the *intensity curve and the set dressing*; the fiction supplies names, units, and dates.

---

## 1. Handcrafted op maps vs the locked one-WorldBuilder path (ADR-028)

### What the code actually is

There is ONE world entry: `enter_hub()` instantiates `game_world.tscn`, sets `mission_seed`, and the
only fork in the entire pipeline is which **plan dictionary** feeds the builder:

```
var patrol_plan: Dictionary = MissionGenerator.plan_demo_world(world, op_seed) \
    if demo_mode else MissionGenerator.plan_patrol_world(world, op_seed)
var built: Dictionary = MissionGenerator.build_patrol_world(world, director, patrol_plan)
```
(`scripts/main/game_flow.gd:627-629`)

`plan_demo_world` (`scripts/missions/mission_generator.gd:697-874`) is **already a hand-authored
map expressed as data**: the firebase is pinned dead-center (`:719-720`), the village and temple sit
on authored bearings (`v_dir = out_v.rotated(UP, 2.35)`, `:739-740`), ruins on authored
bearing/radius tables (`ruin_bearings/ruin_radii`, `:773-774`), the camp on an authored flank
(`:825-827`), ambient AA on authored bearings (`:855-856`). The demo IS a handcrafted consistent map
that every player shares — built by the same `build_patrol_world` stamp pass, same dict contract
(comment at `:692-696`). ADR-028's decree ("the arena is a SLICE of it, never a parallel copy",
`production/adr/ADR-028-one-world-build-path.md`) has a second living precedent here: the demo is a
slice with an authored plan.

### Option 1A — Authored PLAN per operation (extend the demo precedent)

Each op ships a `plan_op_<name>()` (or better: a data resource — bearings, radii, site kinds, enemy
groups, heightmap directives) consumed by the same `build_patrol_world`. Fixed seed per op → ADR-010
determinism makes it byte-identical for every player *for free*.

- **Buys:** zero ADR amendment beyond a note; all stamping/destructible/nav/enemy wiring inherited;
  fossil-law safe (no second builder); consistent-for-all-players falls out of ADR-010.
- **Costs:** authoring expressiveness is bounded by what SitePlanner can stamp. A Hue-flavored city
  (street grid, dense blocks, a citadel wall, a river) is not in the current stamp vocabulary —
  the real work is new **stamp kinds** (city_block, street, canal/river, compound wall), not a new
  builder. Terrain itself is still noise-driven; an authored heightmap needs a heightmap-input hook
  in TerrainManager.

### Option 1B — Authored HEIGHTMAP + authored plan (same builder, authored inputs)

Feed TerrainManager an authored heightmap image for op seeds (flat river plain for the city op,
a valley for an LZ-hold) and drive sites from the authored plan. Terrain becomes an input, the
builder stays singular.

- **Buys:** real control of the ground (a city needs FLAT ground; the generator's jungle relief
  fights urban stamping); still one path.
- **Costs:** a heightmap-source branch inside TerrainManager — small but it is the first "authored
  world data" the terrain pipeline has ever taken; ADR-028's "deterministic pass from mission_seed"
  needs an amendment clause: *"or from an authored op manifest, through the same pass."*

### Option 1C — Authored SCENE slices (a .tscn city stamped whole, arena-style)

Ship the op map as an authored scene the builder places, the way `firebase_main` is already an
authored GLB stamped by `place_firebase_main` (`mission_generator.gd:885`) with its own navmesh
special case (`nav_baker.gd:42-43`).

- **Buys:** maximum authorial control — Blender/editor-built streets, verticality, sightlines. The
  firebase proves the whole chain (colliders, destructibles JSON, nav parse of `-colonly`
  trimeshes) works for a large authored structure cluster.
- **Costs:** the firebase is ~300m across and is *already* the nav special case; a 600-900m city
  scene is the firebase problem ×4. Every authored scene is content that bypasses the seeded
  systems (paddies, roads, ambush planner) — those must be re-authored per map or skipped.

### My position

**1B + 1C hybrid, no parallel builder:** ops = fixed op-seed + authored heightmap + authored plan,
where the plan's site list may include large authored scene stamps (city blocks as kit pieces, the
way `firebase_main` stamps today). This honors ADR-028 with a one-clause amendment ("authored op
manifests are legal builder input; the pass stays singular") and reuses every downstream system.
**What is sacrificed:** the 7/28 decree's per-op random maps — replay variety inside an op is gone;
variety must come from the enemy layer (seeded enemy_groups can still vary per tour if we split
"map seed" from "force seed" — the plan dict already separates sites from enemy_groups,
`mission_generator.gd:504-509`, so this split is cheap and I recommend it).

---

## 2. Operation lifecycle and what carries

### What exists

- **The whole loop already runs through one teardown/build cycle:** `_teardown_world()` commits the
  campaign (`CampaignState.commit_mission()`, `game_flow.gd:422`) and `enter_hub()` rebuilds. The
  debrief already returns to the hub when an operation seed exists (`game_flow.gd:483-485`).
- **What persists today, engine-verified:** roster (squad members as dicts), `kia_total`,
  `ward_wounded`, threat level + timed modifiers, reputation/rank titles, intel, rack/weapon
  condition, depot loss — all in `campaign.cfg` (`scripts/autoload/campaign_state.gd:22-120`).
  Player section (position, weapon state) via `SaveData.PlayerSection`
  (`scripts/data/save_data.gd:64`), applied post-spawn (`save_manager.gd:223-231`). Weapon
  condition explicitly persists across missions (`game_flow.gd:718-725`).
- **Save-layer law check:** `SaveManager.context` is `"menu" | "hub" | "mission"`
  (`save_manager.gd:27`); IRONMAN and HARD tiers save **only at the hub** — the comment already
  names the fiction: *"the wheels-down"* save (`save_manager.gd:7-8`). Autosave fires on hub entry
  (`game_flow.gd:761`).

### The lifecycle, mapped to code

1. **Assignment (diegetic):** radio/RTO event at the firebase. The toast/VO plumbing exists
   (`director.toast`, `field_director.gd:1510-1511` already radios "BATTALION RELEASED AIR TO US").
   Mechanically: an op-offer state on FieldDirector, surfaced by walking to the RTO/TOC —
   *encountered*, never menu'd (open-sim pivot). No new UI.
2. **Transit:** see §4.
3. **The fight:** an op world entered through the same `enter_hub`-shaped function with
   `op_manifest` instead of the home seed. `SaveManager.context = "mission"` — HARD/IRONMAN get no
   mid-op saves, which is *correct* and already enforced (`save_manager.gd:61-95`).
4. **Exfil:** diegetic — reach the LZ, board (SeatSystem.board_squad exists and HeliLift consumes
   it, `heli_lift.gd:3-6, 51`). Exfil-refusal = the patrol's fail-forward: death/abandon routes
   through the existing `fail_mission → _on_mission_ended` pipeline (`game_flow.gd:377-380, 456-473`).
5. **Return:** `enter_hub()` on the home `operation_seed` — the persistent AO rebuilds byte-identical
   (ADR-010), campaign deltas already committed.

**What must carry and already can:** squadmates (roster dicts), wounds (`ward_wounded` + WIA/KIA
flow, `campaign_state.gd:56-74`), rank (reputation/titles), casualty ledger, weapon condition.
**What cannot yet:** *world-state deltas at the home AO* (a blown parapet, a cleared camp) are
rebuilt fresh each entry — fine today (one continuous session per day), but a Tet campaign that
alternates hub↔ops makes "did my firebase remember the siege damage" a real question. That is the
one genuinely NEW save-layer system an ops loop demands: a **world-delta section** (destroyed
Destructible IDs, cleared garrisons) applied post-build. Cheap version: don't persist it, fiction
says engineers repaired the wire while you were gone. I endorse the cheap version for v1 — it is
also the honest reading of `HubSection` (`save_data.gd:128`), which persists seed and name only.

---

## 3. Tet as a SYSTEM

### The mechanism that already exists

Escalation is a scalar with timed modifiers: `threat_level` + `add_threat_modifier(delta, missions,
reason)` (`campaign_state.gd:22-23, 225`), read as LOW/MODERATE/HIGH/CRITICAL
(`threat_label()`, `:214`). Consumers today: patrol escalation + air release
(`field_director.gd:1448-1511`), siege probability per night (`SiegeDirector.NIGHT_CHANCE`,
`siege_director.gd:12`), siege strength d50 with probe threshold (`:16-17`), 3-night runs
(`MAX_RUN_NIGHTS`, `:13`), live cap 50 (`:35`). Ambient encounters carry per-day caps and dice
(`ambient_encounters.gd:19-27`). Air traffic is a scheduler with formation sizes
(`air_traffic.gd:14-41`).

### Option 3A — CHEAP: Tet as a threat-modifier event

A campaign-clock trigger (N missions in, or a sim-date) pushes a large multi-mission
`add_threat_modifier(+0.5, …, "TET")`. Everything downstream inflames itself: nightly siege chance
hits the CRITICAL 0.45, patrols escalate, air releases. Add one override — during Tet the siege
roll floor is raised past `PROBE_MAX` so every night is a real assault, and `NIGHT_CHANCE` is
bypassed to ~1.0 for the offensive's first nights.

- **Buys:** days of work, not weeks; zero new systems; the offensive *is felt* at the firebase.
- **Costs:** Tet reads as "a hard week," not an event with a shape. No daylight fighting, no
  narrative arc, ambient world unchanged by day.

### Option 3B — MID: a campaign-clock phase machine

`CampaignState` gains a `campaign_phase` (PRE_TET → TET_NIGHT_ONE → HIGH_TET → EBB) advanced by the
sim-day counter (`SimClock.sim_day` exists, `game_flow.gd:131`). Each phase is a tuning table over
existing knobs: siege NIGHT_CHANCE/strength floor, ambient encounter DAY_CAPS and EVENT_CHANCE,
air_traffic sortie rate and formation frequency, ambient AA activity, radio/VO flavor. Ops
availability keys off phase (city ops unlock during TET). The intensity curve is authored once,
shared by all players; the *content* of each night still rolls off the seed.

- **Buys:** Tet has a beginning, a crescendo, an ebb — the historical shape without dates or real
  units. Every knob it turns is measured, shipping code. This is my recommended core.
- **Costs:** a phase table is a new canon surface (needs an ADR); playtest cost — four phases ×
  night sieges is a lot of nights to verify; the demo's one-day scope never exercises it (correctly
  ships post-EA).

### Option 3C — DEEP: Tet touches the daylight world

Phase additionally flips daytime ambience: `ambient_encounters` "never at night" and per-day caps
(`ambient_encounters.gd:5-27`) get a TET table (daytime contacts common, friendly columns moving,
refugee civilian flow on the roads), villages change garrison posture, the siege gains a DAYLIGHT
probe variant, and the firebase runs continuous stand-to (garrison schedule override).

- **Buys:** the one thing 3A/3B can't — "the whole AO is at war" between sieges; strongest
  Rule-One payoff.
- **Costs:** every "never during the day/siege" guard in ambient/pilot/mortar systems was placed
  deliberately (exclusivity gates, `ambient_encounters.gd:5-7`); loosening them multiplies live-body
  count against the perf wall (bodies are ~94% of AI cost, `marching_cell.gd:4-6`). Needs
  MarchingCell-style deferral applied to daytime ambient columns before it is affordable.

**Position:** 3B is the spine; 3A is its first shippable milestone; 3C is a per-phase add-on gated
on perf measurement. **Sacrificed:** a literal calendar ("January 30, 1968") — the phase machine
runs on tour-days, keeping the fictional-unit premise intact.

---

## 4. Helicopter transit tech

### What exists (more than the briefing assumes)

- `Helicopter` is a kinematic state machine: terrain-following cruise, LANDING/LANDED/TAKING_OFF,
  code-driven rotors with spool (`scripts/vehicles/helicopter.gd:1-35`).
- `SeatSystem` offers seat/unseat/board_squad; `HeliLift` is the consumer that boards AI pax, runs
  doors, and plays six distinct disembark clips verified in `anim_library.glb`
  (`scripts/vehicles/heli_lift.gd:3-6, 36-51`).
- `AirTraffic` flies LZ_CYCLE landing cycles to the firebase pad and 6-9-ship Huey formations
  (`scripts/ai/air_traffic.gd:6-41`).
- Sequence GLBs exist: `assets/us/vehicles/heli_approach_land.glb`, `heli_casualty_load.glb`
  (verified on disk) — plus troops-disembark clips in the shared anim library.
- The player already has a seat pathway precedent (spawn *seated* on the bunk,
  `game_flow.gd:644-651, 671`).

### Option 4A — Scripted ride, loading-hidden swap (recommended v1)

Player boards via SeatSystem at the pad → doors shut → lift-off flown by the existing Helicopter
state machine over the HOME AO (real, no fakery) → at AO edge, fade + loading screen (the WarFacts
screen, `game_flow.gd:586-603`, already owns this moment) → op world builds → the *approach and
landing* are flown by the same state machine INTO the op world → doors open, disembark clips play,
you step off. The ride is real at both ends; the swap hides only the build.

- **Buys:** every component exists; the world build needs a loading screen anyway (the home AO
  takes one, `game_flow.gd:587`); formation ships alongside you (AirTraffic) sell the 6-9-ship
  lift for free. Door-gunner v1: you sit; the crew's M60s are ambient VFX.
- **Costs:** a cut mid-flight. Mitigated by making the cut diegetic (cloud/treeline flash, radio
  chatter continues over the load — audio is an autoload and survives the world swap).

### Option 4B — Seamless simulated flight

No swap: op terrain streams in around the flight.

- **Costs kill it:** ADR-028/ADR-013 explicitly bind residency — the whole grid builds once behind
  a loading screen and chunk count is invariant (`ADR-028`, Residency clause). Streaming a second
  AO under a flying player is the parallel-world/streaming bug class the ADR names as what "sank
  the Catacombs project." This is not an amendment, it is a rebuild. **Off the table.**

### Option 4C — Door-gunner participation (v2 layer on 4A)

During the scripted approach into a hot LZ, hand the player the door M60 (the weapon systems are
seat-agnostic; the M60 viewmodel exists) for the final run-in; ambient tracers/AA
(`ambient_aa` points exist in the plan contract, `mission_generator.gd:854-866`) shoot back.

- **Buys:** the COD-blend set-piece the tone reference asks for, inside our systems.
- **Costs:** shooting from a moving parent breaks assumptions (recoil pivot, projectile origin
  velocity, hit registration vs terrain streaming under the flight path); AI on the ground during
  the approach = bodies at range — needs the MarchingCell deferral trick airborne. Real work;
  do not promise it for the first op.

**Position:** 4A now, 4C as the second-op showpiece, 4B never.

---

## 5. City-fighting systems cost (the real cost, per the decree)

### What the navmesh actually does today

`NavBaker` bakes **per-site islands** with `HALF_MAX: 70.0` m half-extent (`nav_baker.gd:26-28`);
the firebase is the singular special case at 185m half-extent that parses real `-colonly` trimeshes
instead of the `nav_blockers` group (`:30-43`). **Named tradeoff in the file header: no long-range
pathfinding — a man 300m out bee-lines** (`:18-21`). Breach re-bakes exist and are debounced
(`:60-73`). Agent metrics: radius 0.5, height 1.8, max_climb 0.4 (`:45-48`).

A Hue-flavored map inverts every assumption:

1. **Island model breaks.** A city is one continuous structured surface, not stamped islands in
   passable jungle. Everything between islands falls to bee-line steering — in a street grid that
   means men walking into walls "with full confidence" (the exact defect `nav_baker.gd:38-40`
   names). **Need:** either the FSB-style trimesh parse scaled to district-sized regions (bake cost
   scales with Recast heightfield area — the reason chunks were rejected, `:2-7`), or a street-graph
   layer: navmesh islands per block/interior + a road-network-style graph for street movement
   (`RoadNetwork` exists and already routes around blockers, `mission_generator.gd:650-653` — the
   closest thing we own to a street graph).
2. **Verticality.** `max_climb 0.4` handles stairs geometrically, but nothing in the AI reasons
   about floors: sight checks, cover scoring, and grenade multi-point visibility (8 points,
   CLAUDE.md pattern) are built for one ground plane. Second-story shooters need at minimum
   navmesh that carries upper floors (Recast does this free if the geometry parses) and a
   cover-scoring tweak so a window is cover. **Cheap version: single-story city.** Ruined Hue-style
   rubble reads *better* in PSX than intact two-story blocks, and rubble is a ground-plane problem.
3. **Interior combat.** The decree says art is proven (modular buildings). The systems gap is
   room-clearing AI: CombatGoals' cover/flank vocabulary is open-terrain. Cheap: interiors as
   garrison anchor points (defenders hold rooms, `lazy` groups as today,
   `mission_generator.gd:621-623`) — the player clears, AI defends but does not maneuver indoors.
   Deep: indoor flank/fallback graphs — weeks of AI work, and I'd cut it.
4. **Destructibles are an asset, not a cost.** The naming-contract pipeline (recon-destructible-export)
   plus breach re-bake (`nav_baker.gd:60-73`) means shot-through walls and satchel-opened buildings
   already work — city fighting is the best consumer this system will ever have. Siege overrun logic
   is already per-bearing, not radial (`siege_director.gd:69-74`) — it generalizes to a defended
   city block ("hold the compound" ops) with modest work.
5. **Perf.** Dense colliders + many defenders in a small volume. MarchingCell deferral works for
   approach; indoors, everyone is inside materialize range at once. **The city cap is lower than the
   siege's 50** — plan force sizes around a measured cap, not the open-field one.

**Position:** the decree is right that AI/navmesh is the cost, and the honest cheap path is:
**single-story, rubble-heavy, block-island city with street-graph movement, defenders-hold /
player-clears interiors, ~30-man engagements.** That is Hue's *texture* (walls, craters, rubble,
short sightlines) at maybe 20% of the cost of a general urban-combat AI. Sacrificed: upper-floor
snipers and indoor maneuver AI — name them roadmap, not scope.

---

## Summary of positions

| Question | Position | Sacrificed |
|---|---|---|
| Fiction dial | 1968 as weather; fictional city in the Hue style | The literal calendar/named units |
| Map authorship | Authored op manifest (heightmap+plan+scene stamps) into the ONE builder; one-clause ADR-028 amendment | Per-op random maps (recover variety via split force-seed) |
| Lifecycle | Reuse enter_hub/teardown/debrief cycle; wheels-down saves already enforced by tier | Persistent home-AO battle damage (v1: engineers repaired it) |
| Tet | Phase machine over existing threat/siege/ambient/air knobs (3B), 3A as milestone 1 | Daylight-war phase (3C) until perf-measured |
| Heli | Scripted ride + loading-hidden swap (4A); door-gunner later | Seamless streaming flight (ADR-028 forbids; Catacombs scar) |
| City | Single-story rubble city, block islands + street graph, defend-only interior AI | Verticality, indoor maneuver AI |
