# Devil's Advocate — LOD-tier world sim (ADR-025 / bead xdys)

Read the code, not the plan. Evidence cited to file:line. No free lunch.

---

## 1. Phase 2 capture/apply — the lossy seam is worse than the ADR admits, AND the ADR lies about what exists

ADR-025:57 orders `_capture_state`/`_apply_state` to preserve "position, hp, **squad_id + membership**,
**morale, objective/ETA**, patrol index." I checked EnemyBase for those fields:

- `current_hp` (enemy_base.gd:13) — exists.
- `squad_id` (enemy_base.gd:230) — exists (an int coordination group).
- `alert_tier` (enemy_base.gd:65), `awareness` (enemy_base.gd:66) — exist.
- `patrol_route` (enemy_base.gd:100), `_patrol_index` (enemy_base.gd:101) — exist.
- **`morale` — DOES NOT EXIST as state.** grep finds it only at enemy_base.gd:2087, a *comment* over a
  break-ladder that is **recomputed at every hit** from `enemy_data.courage`, `threat_level`,
  `current_hp`, and a live `randf()` (enemy_base.gd:2089-2094). There is no `var morale`. You cannot
  "preserve" a value that is never stored — it is re-derived each frame from inputs that themselves
  reset when the node is destroyed.
- **`objective`/`ETA` — DO NOT EXIST on the node.** They live on the T3 *data dict* (world_sim.gd:20
  header: `{kind, position, velocity, schedule, ...}`; ADR-025:44 "route/dest/ETA"). They are the data
  tier's own bookkeeping — they never round-trip THROUGH a node, so a node capture neither can nor
  needs to preserve them.

**Verdict:** ADR-025:57's capture list is **scope creep built on a phantom.** Two of its six items
(morale, objective/ETA) are not node state. Instructing an implementer to "preserve morale" invites
one of two bad outcomes: (a) they *invent* a `morale` field to have something to capture — new state,
new fossil, new divergence from the live break-ladder; or (b) they capture the transient inputs
(`threat_level`, `awareness`) and quietly reset the rest, and nobody notices because there was never a
field to diff. This is exactly the CLAUDE.md drift pattern: a doc line makes an architect "verify" a
requirement that does not exist.

**Minimum honest capture** (what actually round-trips without lying):
`position, current_hp, max_hp, squad_id, alert_tier, awareness, patrol_route, _patrol_index,
camp_role`. That's it. Everything else on an EnemyBase is either per-frame scratch
(`accuracy_modifier`, `_cand_intent`, `strafe_timer`) that SHOULD reset, or derived. The
bit-exact round-trip probe (ADR-025:76) must assert **on this explicit list** — and must *also*
assert that a captured→destroyed→re-materialized unit is byte-identical on those fields AND that its
squad pointer re-resolves (squad_id is an int, but the `EnemySquad` object it names may have been GC'd
while the unit was at T3 — the ADR says "membership" but there is no membership-rejoin code anywhere,
and `_attach_camp_directors` groups by `squad_id` at spawn only, mission_generator.gd:734). **Squad
re-join across the T3 boundary is unimplemented and unspecified. That is the real seam, and the ADR
buries it under two phantom fields.**

---

## 2. Phase 3 Ambience Law — `offer_generated` connects to NOTHING, and wiring it is where the Ambience Law gets violated

grep for `offer_generated` across all of scripts/ returns exactly THREE lines:
- dynamic_mission_factory.gd:15 — `signal offer_generated`
- dynamic_mission_factory.gd:59 — `offer_generated.emit(offer)`
- mission_generator.gd:718 — `dynamic_factory_ref.has_signal("offer_generated")` — a **guard**, not a
  `.connect()`. It checks the signal *exists* before wiring the *convoy's* `ambushed` signal into the
  factory's `_on_convoy_ambushed` handler (mission_generator.gd:716-720).

**So the offer pipeline is one-ended.** `emit_offer` (dynamic_mission_factory.gd:52) fires
`offer_generated` into the void. Nothing on the far side turns an offer into a mission-board entry, a
toast, a marker, anything. The DMF header (dynamic_mission_factory.gd:6-10) *claims* offers "are pushed
to a `source = "SIM_EVENT"` channel" — **that channel does not exist in code.** `offer_for` builds a
dict with `"source": "SIM_EVENT"` (dynamic_mission_factory.gd:43) and emits it; no consumer reads it.

**The Ambience Law trap:** ADR-025:63-65 says T2 statistical resolution stays legal *because* a
player-relevant outcome "has already become an offer surfaced through DynamicMissionFactory, never a
silent loss." But an offer emitted to a dead signal **IS a silent loss** — the fiction resolved a
fight, the code fired a signal, and the player saw nothing. Phase 3 does not satisfy the Ambience Law;
it *names* a mechanism (the offer) that is itself a fossil (r4bk). **To make Phase 3 legal you must
first build the offer CONSUMER** — the SIM_EVENT mission channel the DMF header lies about. That is a
whole mission-surfacing feature (board entry, dedup vs `MissionOffers.roll`, player notification), not
a signal wire. It is **not reachable this session** and pretending otherwise ships a law violation
dressed as compliance.

Second Ambience risk even once wired: an off-AO statistical collision that promotes into an offer near
the player can still *touch assets transitively* — e.g. `convoy_ambushed → PATROL` offer
(dynamic_mission_factory.gd:29-30) at a `payload.position` (dynamic_mission_factory.gd:45) that happens
to be inside the live AO would spawn a mission on top of the player's current fight. The Law says
"never touches the player/assets directly"; a position-carrying offer with no AO-distance guard is an
indirect touch. Needs a "resolution site must be > AO_RADIUS from player" assertion.

**Verdict: BEAD Phase 3 for a follow-up wave.** It depends on (a) the offer consumer being built and
(b) `SimClock.advance()` being wound (Phase 3 driver, ADR-025:61) — two features, not a wire. Shipping
it this session ships either dead emits or a law violation.

---

## 3. The arena win claim — Phase 1 is perf theatre in the probe it's measured by

The briefing's own SUMMONING FACTS (lines 32-38) demolish the arena premise, and the code confirms it:
`test_arena_perf.gd` spawns no player (`spawn_player=false`), so distance-to-player node-LOD has **no
reference point** — `WorldSim.update_player` (world_sim.gd:70) is never called with a real player pos,
every cell stays `current_ao=false` or defaults, and `_tick_node_lod` has nothing to demote against a
200m arena where all units are <110m apart. **Node-LOD saves ~0 there.** Worse: the round-robin
scheduler tick (ADR-025:54) *adds* per-frame cost against a native ~27 FPS floor (ADR-025:86). In the
arena probe, Phase 1 is a **net perf LOSS measured as the headline win.**

**The honest position:** Phase 1's real payoff is in the live game (player present, units spread across
≤2km, most enemies past the 45-140m sight cap) — but **there is no probe for that scenario**, and
ADR-025:98 pins the floor to the arena/PERF_LEDGER number. So the wave cannot *demonstrate* the win it
claims; it can only assert it. Asserting an unmeasured perf win is precisely the "fake perf claim" the
charge warns against.

**Smallest honest deliverable that drops fossils without a perf lie:** ship **Phase 0 + Phase 1 as a
CORRECTNESS/wiring change, not a perf win.** The probe should assert *behavior* — "a unit at 600m has
`physics_process` off and `visible=false`; the same unit at 50m is live" (a state assertion, cheap and
true) — NOT a frame-rate delta the arena cannot produce. If a perf number is claimed at all, it must
come from a **new player-present spread-AO probe**, and if that probe isn't built this wave, the honest
report is "Phase 1 wires the LOD authority; perf impact unmeasured, follow-up bead 365s owns the truth
pass." Anything else is theatre.

---

## 4. Fossil count honesty — which of the 18 this wave can legitimately green

From the briefing (lines 26-30) and ADR-025:100-109, the 18 split hard:

**Legitimately greenable THIS wave (LOD thread, actually wired by Phase 0-2):**
- `set_lod_live`/`set_lod_abstract` — discharged by Phase 0 collapse into `set_tier` + Phase 1 callers.
  (These are freq-2 twins, enemy_base.gd:115/120 + civilian.gd:360 — currently NOT even baselined as
  fossils per briefing:13-14, so greening them is invisible to the count. Watch this.)
- `MAX_THINK_TIME` — deleted by Phase 0 (baselined, fossil_baseline.json:28) → real -1.
- `WorldSim.update_player`/`materialize_near`/`dematerialize_far` — wired by Phase 1/2 → -3, **IF the
  callers are real** (see §3 — an arena with no player may leave them technically called-once-in-a-test
  but dead in practice; the probe must call them for the wiring to be honest).

**Must be BEADED — other threads, "silencing not wiring" risk if touched:**
- `AmbushPlanner` consts → ADR-021/022 ambush intel loop (LW-10). Out of scope (ADR-025:105-108).
- `PaddyStamper` consts → village/paddy thread. Out of scope.
- `air_traffic get_in_flight`, `ambient_war get_active`, `squad_leader funcs`,
  `weapon_data get_bore_dir`, `convoy.resume` — all OTHER threads (briefing:30). Touching them to green
  the count is **silencing, not wiring.**

**The genuine trap (charge #4):**
- `SimClock.advance` + its 4 signals, `time_period_changed`, `clear_schedules` — ADR-025:61 assigns
  these to **Phase 3**. If Phase 3 is beaded (see §2), these **stay RED this wave.** Do not wind
  `advance()` just to green them — winding the clock without the Phase 3 resolution consumer is exactly
  "silencing not wiring": eight systems (ADR-025:94) start receiving `hour_advanced` at 60× real time
  with no LOD scheduler consuming it, changing live behavior (camp role swaps, weather re-rolls) as a
  **side effect of a fossil-count cosmetic.** That is a behavior regression disguised as cleanup.
- `Convoy.waypoint_reached`/`route_finished` — Phase 2 convoy registration OR cut (ADR-025:104). If
  Phase 2 convoy-register isn't built this wave, these must be **beaded or honestly cut**, not left
  half-wired.

**Honest greenable count this wave: ~4 (MAX_THINK_TIME + 3 WorldSim fns), contingent on real callers.**
Not 18. Claiming more means silencing.

---

## 5. THE NAMED SACRIFICE (the whole wave)

> **To ship a real fossil-count drop this session, you sacrifice the perf CLAIM and the Ambience-Law
> feature. Phase 0+1 delete three working LOD paths (live enemy + civilian AI churn, ADR-025:81) and
> wire one authority — but the arena probe that measures it CANNOT see the win (no player, §3), so the
> deliverable is honest *wiring* whose *performance is unmeasured*. Phase 2's capture list is a phantom
> (morale/objective/ETA don't exist, §1) and its squad-rejoin seam is unspecified. Phase 3 is
> unreachable — its Ambience-Law safety valve, `offer_generated`, emits into a dead signal (§2), so
> either it's beaded or the wave ships a silent loss wearing the Law's badge.**

The free lunch on offer is: "green 18 fossils + land a CPU-perf win." The bill: you can honestly green
~4, you cannot measure the perf win in the probe you own, and reaching for the other 14 or the perf
headline forces you to either invent phantom state, wind a clock with no consumer, or emit offers no
one hears — three flavors of the same lie ADR-023 exists to kill. **Ship Phase 0 + Phase 1-as-wiring.
Bead Phase 2 (after a squad-rejoin spec) and Phase 3 (after the offer consumer). Report "wiring done,
perf unmeasured," not "perf win."**
