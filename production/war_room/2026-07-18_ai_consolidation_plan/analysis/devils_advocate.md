# DEVIL'S ADVOCATE — AI Consolidation Plan (2026-07-18)
*Every claim below re-verified in live code this session. File:line citations are from today's tree.*

---

## 1. THE "DEAD" SYSTEMS — one of the four verdicts is WRONG, and it's the lethal one

### SimClock.advance() — **LIVE ORGAN. The survey verdict is false.**
`scripts/autoload/sim_clock.gd:33-36`: `_process(delta)` calls `advance(delta)` **every frame** unless
paused. The clock ticks itself. "Zero callers" is only true for *external* callers — a distinction the
survey does not make and the synthesis (D3: "SimClock.advance() (zero callers) — wire or delete,
council picks") actively erases. The signal net is not idle wiring; at `real_to_sim_ratio = 60.0`
(`sim_clock.gd:18`), `hour_advanced` fires **every real minute** into subscribers that
`mission_generator._wire_systems` instantiates in the live patrol world (`mission_generator.gd:16-21,
201-243`):

| Subscriber | What dies if advance() is deleted |
|---|---|
| `CampDirector` per VC cluster (`camp_director.gd:48-51`) | garrison role rotation — the "living camp" (cook/sleep/talk/guard swaps) |
| `AmbientWar` (`ambient_war.gd:15-18`) | distant-war ambience events, 1-3/hour |
| `AirTraffic` (`air_traffic.gd:19-38`) | scheduled helicopters/flare ships (`sim_event`) |
| `WeatherDirector` (`weather_director.gd:22-25`) | weather re-rolls on `day_advanced` |
| `ConvoySpawner` (`convoy_spawner.gd:13-16`) | convoys → `DynamicMissionFactory` ambush hooks |
| Civilians (`civilian.gd:321-325`) + `civilian_schedules` | time-of-day routines (walk home, work) |

A council member who takes the survey's "zero callers" at face value and picks "delete" kills camp
life, air traffic, weather, convoys, and civilian schedules **in one stroke — and no probe goes red**,
because none of these have behavioral probes. The decree must state: **SimClock is wired and live;
the only fossil is the survey sentence.** Strike the wire-or-delete question entirely.

### WorldSim — tiers truly dead, registry NOT free to delete
- `update_player` / `materialize_near` / `dematerialize_far` (`world_sim.gd:70,86,99`): definitions
  only, zero callers, no string dispatch. **Truly dead. Confirmed.**
- BUT the registry half is live-written: `mission_generator.gd:188-193` calls `WorldSim.clear_if_needed()`
  + `WorldSim.register({...})` for every spawned enemy, and `world_sim.gd:34-38` runs a real `_process`
  advancing abstract cells every 60s. Readers: `test_world_alive.gd:370-411` (a probe). So WorldSim is
  a write-only store with a live writer, a live timer, and a probe reader. "Delete" is a small
  migration (mission_generator, test_world_alive — autoload-name references are parse errors, not
  silent no-ops), not a free `rm`. The B1 keep/kill table must carry those three touch points.

### set_lod_live / set_lod_abstract (`enemy_base.gd:118-125`, `civilian.gd:360-366`)
Definitions only. No caller, no `.call("set_lod...")` dispatch anywhere (verified against every
`.call(`/`callv`/`has_method` site in scripts/). **Truly dead. Confirmed.** One poison pill though:
the stub's SHAPE is wrong for Wave A2/B1 semantics — `set_lod_abstract` does
`set_physics_process(false)`, and `_physics_process` contains the THINK accumulator
(`enemy_base.gd:478-481`) and all decay clocks (`:475`). Anyone who "wires the existing hook" gets
RTCW's body gate WRONG — it kills the brain too. Delete the stubs *before* A2 so nobody reuses them.

### CombatManager.apply_bullet_damage (`combat_manager.gd:74`)
Definition only; bullets resolve via `BulletSystem._impact` → `target.take_damage` directly
(`bullet_system.gd:132`). No string dispatch. **Truly dead. Safe to delete.** Do not confuse with
`DamageSystem.apply_damage` (grenade.gd:111, projectile_base.gd:367) — that one is live.

**Scorecard: survey went 3-for-4. The one miss is the one whose deletion is silent and probe-less.**

---

## 2. THE MEASUREMENT — the 25-192ms number is triply compromised

1. **It comes from a run the ADR itself voids.** ADR-026:166-175: the `ai/agents = 25-192ms` figure
   was captured in the A/B run whose header reads "**The fps/ms numbers are void — measured with
   Blender open, GPU/CPU contended**... CPU times ran 3-4× the historical baseline." The ADR salvages
   only the *direction* (CPU-bound) as "robust to contention." The synthesis then quotes the voided
   *magnitude* as "measured, not guessed" and Wave A's payoff is scaled to it.
2. **The bucket is a remainder, and it's the WRONG remainder.** `arena_perf_overlay.gd:173`:
   `ai/agents = maxf(0.0, process_ms - itemised)` where `process_ms` is `Performance.TIME_PROCESS`
   and the only itemised buckets are the arena's own four (`ai_stress_arena.gd:295-298`: patrol,
   reinforce, telemetry, debug_vis). So the bucket labeled "ai/agents" actually contains **every
   un-itemised `_process` script in the tree** — vegetation frustum cull (10Hz over all chunks),
   gun_fx, tracers, HUD, audio, civilians, SimClock — and **excludes the AI's actual home**:
   `enemy_base._physics_process` (`:442`) — think, perception raycasts, `move_and_slide`,
   `HitzoneBuilder.sync` — all of which land in `TIME_PHYSICS_PROCESS`, a *different* monitor
   (`:120`). The wall is real (CPU 44.35ms night-arena; the +65% GPU wave stalled at a ~41ms CPU
   wall), but the label on it is fiction by construction.
3. **The raycast math doesn't support A1's payoff story.** 30-58 live units × 6.7Hz think = 200-390
   perception rays/second ≈ **7-13 rays per frame at 30fps**. A single `intersect_ray` against the
   world BVH is microseconds. The perception rays are plausibly **<1ms of a 40ms wall**. The
   likelier occupants of that wall: N × `move_and_slide` + physics broadphase with ~40
   CharacterBody3D and hundreds of hitzone Area3D, N × AnimationTree, `HitzoneBuilder.sync`
   O(N×zones) bone-pose reads every physics frame (`:451`), and raw GDScript interpreter time in a
   2469-line think. If that's right, **A2 (body gate) is the payoff and A1 (ray budget) is mostly
   architecture** — worth doing for A4 and the god-class cut, but not the wave that moves the bench.

**Demand — cheap, BEFORE blessing Wave A's payoff numbers (half a day, ~40 lines total):**
- **Raycast counter (~20 lines):** static counters at `CombatManager.has_line_of_sight`,
  `_update_perception`, `_can_witness`, cover search, bullet segments; print per-frame in the overlay.
  If perception rays/frame is single-digit, A1's perf claim dies before it costs a build-wave.
- **Physics-side buckets:** `ticks_usec` accumulation around enemy/ally `_physics_process` bodies and
  inside `HitzoneBuilder.sync`, reported via the already-existing `report_cpu_bucket` plumbing. This
  splits the wall into think / move / hitzone-sync / anim for the first time.
- **One clean night-bench re-run, Blender closed** (THE_PLAN's own rule), to replace the voided
  25-192 range with a number of record. The `tiering_enabled` A/B switch (`enemy_squad.gd:41`)
  already exists as the pattern to copy.
Sequencing consequence: if the counters say hitzone/anim/move dominate, the wave order inside A
should be **A2 first**, A1 second — the synthesis currently sells them as one indivisible wave, which
guarantees the attribution stays unknown even after it "works."

---

## 3. THE PRESERVATION TRAP — what silently regresses, per wave

### TRAP 1 (worst): ADR-005 witness rule under A1 — guarded only by a probe A1 deletes
The witness heartbeat is `_update_perception()` + `_check_corpse_discovery()` before the tier branch
(`enemy_base.gd:532-535`). Its ONLY guard is `test_activity_tiering._test_witness_before_branch`
(`tests/test_activity_tiering.gd:119-134`) — which is a **source-text grep** for the literal strings
`"_update_perception("` and `"_check_corpse_discovery("` in enemy_base.gd. Wave A1 replaces both
call sites with PerceptionServer timestamp reads: the probe either goes red and gets "updated to
match" (verifying nothing), or the strings survive in a comment and the probe passes on a corpse.
Additional cadence hazards inside A1 itself: the funnel's **"corpses once"** per-pair floor
contradicts live behavior — `_check_corpse_discovery` re-scans `unreported_corpses` every think, so a
patrol that walks past a body *later* still finds it; "once" means a failed first check = corpse
never discovered = silent-kill escalation dead. And `_can_witness(last_known_target_pos)`
(`enemy_base.gd:587`) is a **position** raycast — an entity-pair vislist cannot cache it; A1's design
must name where position queries live or cold fighters lose their honest-witness fire gate.
**Probe status: does not exist behaviorally. Required BEFORE A1:** headless scene — silent kill with
no witness ⇒ camp stays RELAXED; witnessed kill ⇒ escalation; corpse dropped, patroller routed past
it 20s later ⇒ discovery fires. That probe survives any internal rewiring; the text-grep does not.

### TRAP 2: death clocks and accumulators freeze under B1 dormancy
All of these live in `_physics_process`: suppression decay (`enemy_base.gd:498-500`), **gut-bleed
damage** (`:501-509`), the **downed bleed-out clock** (`:454-467`), fire_timer and damage-decay
(`:511-519`). MoHAA-style DORMANT = "not in the tick list at all" stops every one of them: a
gut-shot man stops bleeding out the moment the player leaves (ADR-016 bleed behavior regression), a
downed dying man becomes immortal until observed, a suppressed unit wakes still-pinned minutes later.
RTCW's answer (catch-up: simulate elapsed time on wake) must be IN the B1 plan, not discovered after.
**Probe status: none.** `test_downed_enemy` covers downed behavior, not downed-while-dormant.
Required: unit with active bleed → force dormant → advance clock → wake ⇒ he is dead (or the
catch-up applied). Cheap headless probe, must ship with B1.

### TRAP 3: the hot-set broker and the engagement census assume think-rate freshness — A3 breaks both
- **Promote-on-death is pull-based**: a freed hot slot is only refilled when a cold fighter's
  `_think()` happens to run `request_hot` (`enemy_base.gd:542`, `enemy_squad.gd:70-82`). Under A3's
  4-full-thinks/frame budget with 30+ units, cold-think latency stretches → hot slots sit empty right
  after casualties → **the fight goes quiet exactly when it should surge**. Fun regression, invisible
  to any current probe (`test_activity_tiering` tests the broker synchronously).
- **The 2:1 / target-spread census rots**: `report_engagement` is written at think rate and
  `count_engaging` discards entries older than `ENGAGE_TTL_MS = 3000` (`enemy_squad.gd:186-208`).
  If budgeted thinks stretch past ~3s for cold men, the census undercounts → everyone reads "target
  uncrowded" → pile-on; the shipped spread discipline dissolves under exactly the load A3 exists for.
  (`has_covering_fire` is safe — written per trigger pull on the execute side, `:165-180`.)
- Cheap-combat disengage counts think-intervals, not wall time (`enemy_base.gd:580`), so budgeted
  thinks stretch the 8s disengage in real time — mild, but name it.
**Probe status: partial** (broker math only, synchronous). Required with A3: firefight sim under the
think budget asserting (a) hot-slot refill latency < 500ms after a death, (b) `count_engaging`
census error bounded (ENGAGE_TTL vs measured worst-case think latency), (c) staggered spawn ⇒ no
aligned think spikes (the actual point of A3 — assert it).

### TRAP 4 (lower): cover_to_stand / roll under A2 — pop, not deadlock
Verified: `cover_to_stand` is a **wall-clock window**, not animation-signal-gated
(`_cover_exit_until_ms = now + clip_len` at `enemy_base.gd:1710-1715`, consumed every frame in
`_update_sprite`, `:386-390`). The ally dive-roll is likewise cooldown/window brokered
(`ally_base.gd:709-730`). So the A2 nightmare (brain waits forever on a gated animation) does NOT
exist — the windows expire regardless. Real risks: (a) visual pop when a gated soldier enters the
screen mid-window (acceptable, RTCW shipped it); (b) the big one already covered above — implementing
the gate as `set_physics_process(false)` kills think/decay/hearing (the dead stub's shape). A2's
"unseen+still ⇒ gate" trigger list must ALSO ungate for `_cover_exit_until_ms`-active and
`is_downed` units. **Probe status: `test_low_posture` + `test_ally_cover_roll` exist and are
behavioral — good. Add one assertion: an off-screen gated unit still accumulates think ticks.**

---

## 4. THE ARENA TRAP — what Phase-3 "thin wrapper" actually puts at risk

Read against `ai_stress_arena.gd` (1819 lines), the arena is not just a map; it is the project's
**instrument**. Capabilities with no game-path equivalent today:

1. **`hot_start`** (`:107`, `:1135-1147`, `:1235-1247`) — spawn both sides in instant contact with
   `contact_conf = 1.0`. The game path develops contact only via real perception at distance-gated
   spawns; it cannot express "the fight is already on." Every combat-AI probe and bench depends on it.
2. **Patrol/move-to-contact mode + awareness injection** (`:108-151`, `_update_patrol_contact:1399`)
   — feeds in-arc US contact into the enemy's OWN awareness accumulator so the Fairness-Law ramp is
   exercised deterministically. This is the fairness test seam; `game_world` has no injection port.
3. **Telemetry** (`_wire_telemetry:1548`, `_update_telemetry:1580`) — per-side shot counts (player
   shots included), LOS-block %, 30s cadence logs, plus the four `report_cpu_bucket` feeds the
   overlay's attribution depends on (`:295-298`). The PERF_LEDGER's evidentiary chain runs through
   these hooks.
4. **The hand-stamped benchmark map** — contact-zone ruins/rubble/fallen logs with the central ridge
   kept clear (`:720-748`), vegetation sight-cap tuned at the contact approaches (`:870`), flares
   pre-burning (`:504`). The control experiment already shows ±10% swing on *identical* rows; if the
   wrapper regenerates this via SitePlanner/mission_generator, the fixed benchmark stops being fixed
   and **every before/after number across the remaining waves is noise**. Same for the fun benchmark:
   rule #1 says the arena is the fun/look standard — change its geometry mid-consolidation and there
   is no stable referent left to judge "behavior-preserving" against.
5. Forced break-contact for arena VC (`:1301`), reinforcement waves, `set_characters_active` /
   `set_debug_vis_active` seams the overlay's F4/F5 call by name (`arena_perf_overlay.gd:225-230`).

**Demand:** Phase 3 must be LAST and gated on a capability checklist (the five above, explicitly),
the wrapper must reproduce the identical map (hand-stamps preserved as data, seeded), and the arena
stays frozen as the measuring stick until every wave's before/after is banked. A "thin wrapper" that
lands mid-plan destroys the instrument the plan uses to prove itself.

---

## 5. SCOPE CREEP — feature changes wearing plumbing coats

The synthesis smuggles at least six behavior changes inside "validated" or "free byproduct" framing.
Each is a FUN-LEVER decision (briefing law 5) needing its own line in the decree, not silent inclusion:

1. **Threat-score target spreading, cap 4** ("extend with..." — SYNTHESIS 'Also validated'). Changes
   WHO the enemy shoots. `count_engaging` exists; the discount curve and cap do not. Feature.
2. **Leash (MoHAA 13m)**. Nothing like it is live, and it collides head-on with the shipped hunt net,
   which deliberately advances its anchor up to **130m** down your trail (`enemy_squad.gd:301-304`).
   A leash guts the hunt — the single most praised AI behavior. If proposed at all, propose it as a
   hunt-interaction design question for the Summoner.
3. **Hearing priority ladder + awareness dice-roll (B2)**. Changes investigation priorities and makes
   reaction stochastic — `test_los_determinism` exists precisely because determinism was a decision.
   Feature, and a probe-conflicting one.
4. **Fog-as-sight-cap** ("PS2 fog literally becomes the perception budget"). Live caps are
   `SIGHT_CAP_OPEN 140` / jungle 45 (`enemy_base.gd:72-73`); fog wall is ~90m. Adopting it silently
   cuts open-terrain detection 140→~90 — a stealth/difficulty change dressed as a perf idiom.
5. **RTCW reaction time + 5s target memory as "free byproducts" of A1**. Live `TARGET_MEMORY` is
   **8.0s** (`enemy_base.gd:911`). Importing RTCW's 5s silently makes every enemy more forgetful.
   A4's accuracy ramp is correctly flagged as a fun lever; its riders must be too.
6. **MoHAA one-grenade token at 7s** vs live `GLOBAL_GRENADE_SPACING_MS 5000` + squad 12s
   (`enemy_squad.gd:15-16`) — a pacing retune, small but not plumbing.
7. **B1 AGGREGATE tier** (distant fireteam = one dot at 1Hz) is not behavior-preserving for anything
   the player doubles back on — positions quantize, contact reforms differently. Probably right, but
   it must be NAMED as a sacrifice per Law 2, with the wake-fidelity contract written down.

The clean rule for the decree: **anything that changes who is shot at, how far pursuit goes, what
gets investigated first, how far the enemy sees, or how long he remembers is a FEATURE — it enters
through the fun-lever gate with the Summoner's eyes on it, or it does not enter.**

---

## Sacrifices this critique itself accepts (Law 2)
Hardening the measurement costs ~half a day before Wave A starts; the behavioral witness probe and
the dormancy probe cost roughly another day. That is the price of not deleting a live organ
(SimClock), not shipping a wave whose payoff was estimated off a voided, mislabeled number, and not
finding out in playtest that dormant men stopped bleeding and squads stopped spreading fire.
