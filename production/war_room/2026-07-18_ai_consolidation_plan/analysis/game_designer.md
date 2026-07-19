# GAME-DESIGNER analysis — AI consolidation plan (2026-07-18)

**Lens:** Pillar 1 (gunplay feel) · Pillar 3 (freedom / stealth economy) · the fun clause (briefing law 5).
**Read:** briefing · SYNTHESIS.md · rtcw.md §3-5 · mohaa.md §2-6 · GAME_GUIDE §1/§4.2 · ADR-005 ·
ADR-020 §4 (Ambience Law) · ADR-025 · bible/03_AI_DETECTION.md · `scripts/combat/ai_marksmanship.gd` ·
`scripts/enemies/enemy_base.gd` (perception/witness/exposure paths, lines cited inline).

---

## 1 · FUN-LEVER DOSSIER

Ground truth first: **the Fairness Law is already live and already RTCW-shaped.**
`ai_marksmanship.gd` has the exposure ramp as a probe-able surface (`exposure_spread_mult`,
EXPOSURE_PEAK 2.0 → fresh shots fly a 3× cone, cap breathes 1.2°→3.6°), the first-shot mercy
(`_first_shot_nudge`, deliberate 5–9° high/wide crack), and the player/AI-vs-AI branch invariant.
`enemy_base.gd:995-1003` runs the exposure clock (build over `d_exposure_ramp` ≈2.5 s, drains at 3×
on LOS loss — a foliage blink keeps the ramp, ~0.8 s blind zeroes it). RTCW's
`AICast_GetAccuracy` (0.5–4 s aim-in, LOS break resets) is independent convergent evidence that our
law is the correct shape. So most of these levers are not additions — they are **re-platforming or
completing a law we already ship.** That changes the risk profile: the danger is regression, not design.

### A4 — Accuracy ramp / aim-in (Wave A, rides A1)
- **Player experience:** unchanged if done right — and that is the requirement. What A4 *adds* once
  vislist timestamps exist: RTCW reaction time (target must be continuously visible for
  `reactionTime` before it "counts"), 5 s target memory, and aim-at-last-visible-position. In jungle
  terms: dive behind a berm and the ramp resets, the man shoots your ghost for 5 s, and his squad
  hunts the breadcrumbs — survival-by-movement becomes systemic instead of per-feature. Pairs with
  shipped suppression and believed-position aiming.
- **Fairness Law:** *is* the Fairness Law. Strengthens it — the ramp currently keys off a raw
  per-agent raycast; timestamp math makes it cheaper AND gives it the memory half it never had.
- **Placement / scope:** Wave A. **LAUNCH MUST-HAVE (preservation-class).** The migration probe
  is non-negotiable: `test_ai_fairness` must pass unmodified, plus a new staleness-bound probe (§2 FM2).

### Duty-cycle fire (MoHAA SHOOT→HIDE, Americans 2–4 s / Germans 4–15 s)
- **Player experience:** THE biggest new feel lever on the menu. Under HLL lethality, 8 men firing
  continuously is a wall — no counterplay, only cover-camping. Duty-cycling means ~a third of a
  treeline is firing at any instant: fire comes in **rhythm** — burst, lull, move. The lull is the
  player's verb. This is the Normandy feel MoHAA shipped, and it is exactly Vietnam: contact,
  crackle, silence, crackle. It also hands us archetype identity for free as data: Local Force VC =
  long hides (shoot-and-scoot), NVA regulars = short hides (disciplined pressure). Pillar 4 bonus:
  your squad survives fights it currently shouldn't.
- **Fairness Law:** strengthens it at the *volume* layer — the law governs the accuracy of each
  shot; duty-cycle governs how many shots exist. Telegraphs (muzzle flash/tracer) get readable
  windows.
- **Fossil-law caution:** we already have TWO fire governors — 2:1 fire discipline and the
  hot-set (`_think_cheap_combat`: cold men spray wide, never ramp). Duty-cycle is a third. These
  must be specified as ONE fire-discipline stack (who may target → who thinks precisely → who may
  fire *now*), or the multiplied silences produce accidental easy mode. See §2 FM-floor rule.
- **Placement / scope:** its own small step inside Wave B (it is one timer per state + hide-time
  data). **LAUNCH MUST-HAVE** — cheapest big-battle feel on the menu — **pending the one Summoner
  question in §4** (it changes the under-fire feel he owns).

### Threat-spreading with attacker discount (cap 4)
- **Player experience:** nobody dog-piles. The player stops being the AO's only magnet — enemies
  distribute across the fireteam, which makes the squad feel *shot at* (Pillar 4) and caps
  simultaneous attackers on the player at ~4, which is the Fairness Law expressed at fight scale.
  MoHAA's "+ if player is aiming at me" reciprocity is free drama: scoping a man makes him yours.
- **Fairness Law:** strengthens. Complements 2:1 — same MoHAA lineage, independently invented here.
- **Placement / scope:** merge INTO the existing 2:1/`_target_score` path (extend, never a second
  selector — fossil law). Lands with duty-cycle. **LAUNCH must-have,** ranked just below duty-cycle
  because 2:1 already does half of it.

### Leash / tether (MoHAA 13 m default, pruned inside pathfinding)
- **Player experience:** fights stay where they start. Camps defend their camp; a treeline contact
  doesn't drain the whole AO onto you. For Pillar 3 this is the *mechanical guarantee of
  disengagement*: break contact, move 200 m, and the fight is over — escalation stays geographic,
  which is what "escalation, not fail-states" means in space. Also kills the "whole camp funnels
  through one gate" comedy.
- **PRESERVE-list interaction (the trap):** the shipped squad hunt net (EnemySquad `begin_hunt` /
  `reanchor_hunt`) and spider-hole/tunnel behaviors are deliberate leash *extensions*. A naive
  13 m spawn-tether kills BattleHunt. The design: leash is anchored to a **movable home** — patrol
  leash rides the route, hunt re-anchors to last-known (the code already re-anchors), and
  `_determination()` (enemy_base:853) is the stat that decides when the hunt goes home. Leash values
  are per-state data, not one constant.
- **Placement / scope:** Wave B (it is also the pathfinding-cost governor). **LAUNCH must-have.**

### Hearing priority ladder + awareness dice-roll (B2, AIEventBus)
- **Player experience:** enemies investigate the *right* thing — a footstep never overrides
  investigating gunfire; the awareness roll means a treeline ripples instead of pivoting in lockstep
  (the single most artificial-looking thing large AI groups do). For the stealth economy it prices
  the verbs: footstep 13 m makes crouch-discipline a real number; suppressed stays ~3 m misc noise.
- **Fairness / witness law:** the ladder rides NoiseBus, which is exactly ADR-005's "the AO itself
  witnesses a loud kill" channel. **Two guard-rails:** (1) the MoHAA radius table is SHAPE, not
  values — ADR-005 decreed GUNSHOT 150 m; MoHAA's 52 m must not silently "correct" the law.
  (2) A heard event may wake and escalate to ALERT, **never stamp the COMBAT beacon** (ADR-005:
  sound wakes the AO, sight confirms it). §2 FM4 assertion covers this.
- **Balance flag:** if B2 adds *player* footstep emission that does not exist today, that is a new
  stealth pressure — posture-scale it (crouch/prone quieter) and re-run the fresh-player stealth
  path before calling it neutral.
- **Placement / scope:** Wave B2 — it IS the dormancy wakeup path, so it ships with B whether or not
  we love it. The ladder + dice-roll are nearly free once the bus exists. **LAUNCH must-have.**

### Grenade token / drama pacer (C3; RTCW one-grenade-per-7 s level-wide)
- **Player experience:** grenades become punctuation, not weather. One "LUU DAN!" (shipped
  telegraph), one arc, one scramble — always readable, never two overlapping no-win blasts. Under
  ADR-016's 190-damage M26 economics, simultaneous grenades are unavoidable death; the token is the
  Fairness Law at the drama layer. RTCW proves the cooldown doubles as the perf cap.
- **Placement / scope:** the **token is LAUNCH must-have** (a few lines, guards fairness; token
  governs the ENEMY side — ally throws pace separately). The C3 closed-form ballistics is
  perf-scope; RTCW's iterative dummy-sim careful-aiming is **NICE / post-launch polish.**
- **Also nice / post-launch:** MoHAA player-look reciprocity (`m_fPlayerSightLevel`), RTCW's
  desynced sinusoidal aim wobble. Fun, not launch.

### Launch ranking (fun-first)
1. **A4 exposure-ramp re-platform** (preservation-class; the law itself rides on it)
2. **Duty-cycle fire** (biggest new feel per line of code; Summoner blessing on rhythm)
3. **Leash w/ movable-home + hunt re-anchor** (Pillar 3's disengagement guarantee)
4. **Hearing ladder + awareness roll** (rides B2; stealth-economy legibility)
5. **Grenade token** (one-line drama pacer)
6. **Threat-spread w/ attacker discount** (merged into 2:1, ships with #2)
Nice/post-launch: dummy-sim grenade aiming, player-look reciprocity, aim-wobble texture.

---

## 2 · STEALTH ECONOMY under PerceptionServer + tiers + event bus

The witness rule's current implementation is a **poll**: `_think()` runs `_update_perception()` +
`_check_corpse_discovery()` on EVERY unit at every tier — the comment at enemy_base:532-535 calls
this the guard-rail ("tiering never sheds the witness check"). Wave B's dormant tier deletes that
guard-rail *by design*. The rule must survive as **events + budget lanes**, and each failure mode
below is where it breaks if we're sloppy. Every rule is written as a probe-able assertion because
ADR-015 says "likely fixed" doesn't close anything.

### FM1 — The dormant camp never notices the corpse
Dormant = not in the tick list = `_check_corpse_discovery` never runs = bodies stop being a
liability = the stealth economy loses its price and half of ADR-005 dies silently.
**Design rule:** a corpse is a PerceptionServer *pair*, not a per-agent poll. RTCW's lane already
exists in the funnel: corpses are checked "once until sighted" at the lowest budget priority — and
corpse pairs are checked against DORMANT units too (a dormant unit's corpse-lane check is the ONE
perception it keeps; it is cheap because it fires only when a route brings someone inside
CORPSE_NOTICE_RANGE — a dist² gate before any ray).
**Assertion (probe):** *A patrol whose route passes within CORPSE_NOTICE_RANGE of an unreported
corpse reaches ALERT and stamps contact within 10 s of closest approach, regardless of the
patrol's tier at the moment of the kill.* Plus the inverse, all tiers: *an unwitnessed kill with an
undiscovered corpse never stamps the beacon* (extend `probe_witness` 11/11 across T-tiers).

### FM2 — Budget starvation blinds enemies mid-firefight (accidental easy mode)
50 rays/sec is a *global* budget. A 20-man fight + cold-fighter `_can_witness` checks + corpse lane
could starve engaged pairs → cached LOS goes stale → the exposure clock reads "LOS lost" → drains at
3× → **the cone never converges and suppression never lands.** The player face-tanks a platoon.
RTCW's own answer: engaged/hostile-unseen pairs run at 40 ms floors OUTSIDE the round-robin budget —
the budget throttles *acquisition and bookkeeping*, never the fight you are in.
**Design rule:** pairs in COMBAT with recent LOS are budget-exempt (or top-priority with a
guaranteed floor); the exposure clock may only drain on *actual geometric occlusion*, never on
staleness.
**Assertion (probe):** *A HOT enemy with unbroken geometric LOS to the player never experiences a
cached-LOS gap > 200 ms; time-to-converged-cone (exposure_t = 1.0) is identical ±10% with 2 vs 20
live enemies in the AO.*

### FM3 — Aggregate fireteams teleport into awareness
Two directions, both fantasy-breaking. (a) A dot promoted to nodes materializes already-alert — or
worse, fresh perception at close range ramps him to COMBAT before the player ever got a fair
telegraph: an ambush the *world* set, violating "the war announces itself." (b) The dot itself
"detects" the player statistically — the bible already forbids this (awareness is T0/T1-only) and
that stays law.
**Design rule — the materialization contract:** a promoted unit enters at the tier it demoted with
(default RELAXED), awareness toward the player = 0, exposure_t = 0, `_first_shot_fired` = false; it
climbs the same accumulator ladder as everyone. It may inherit a COMBAT beacon ONLY if that beacon
was witnessed-stamped before its demotion. Promotion distance stays > the max sight cap (140 m
open), so no unit materializes inside its own perception envelope — and no player ever watches a dot
become men (ADR-025's 500 m band already guarantees this; keep it law, not accident).
**Assertion (probe):** *No unit fires at the player within its exposure-ramp time of materializing,
and its first shot is always governed by exposure_t = 0 + force_first_miss, unless a
witnessed COMBAT beacon predates its demotion.*

### FM4 — The event bus becomes a beacon-stamping path
B2 makes hearing the wakeup mechanism. If a woken-dormant man stamps COMBAT off a heard event, loud
play jumps straight to "YOU'VE BEEN MADE" with no witness — ADR-005 regressed by plumbing.
**Design rule:** heard ≠ witnessed, at every tier. Sound wakes (DORMANT→LIVE), escalates to ALERT,
sets investigate-position; only surviving sight contact, a witnessed drop, heard-him-fall <10 m
w/ LOS, or corpse discovery stamps the beacon (exactly today's `_witness_check` semantics).
**Assertion (probe):** *No AIEventBus/NoiseBus delivery alone ever writes `last_combat_contact_ms`,
at any tier, for any event type on the ladder.*

### FM5 — Intel sharing outruns human speed (the AO becomes one brain)
RTCW copies vislists within 384u; MoHAA shares with a 0.75 s delay + plausibility confirm. If
consolidation wires sharing into dormant/aggregate members or drops the range gate, one witness arms
the whole AO — the witness rule bypassed at scale, and the ~30 s soft timer between "seen" and
"hunted" (the seconds that ARE the game per GAME_GUIDE §4.2) collapses.
**Design rule:** intel propagates at voice/radio range and human delay; sharing grants ALERT +
last-known, never COMBAT tier (current `_squad_sync` already does this — preserve it verbatim).
Radio/alarm-carrier remains the only long-range channel, and he remains killable counterplay.
**Assertion (probe):** *A unit beyond SHARE_RANGE of every witness holds tier < COMBAT and has no
last_known until an alarm carrier acts or noise reaches it.*

### FM-floor (fun guard, ties §1): three stacked fire governors go silent
2:1 + hot-set + duty-cycle can multiply into zero men firing — the opposite easy-mode of FM2.
**Design rule:** minimum-pressure floor — whenever ≥1 COMBAT enemy holds LOS, at least one attacker
is in its SHOOT phase.
**Assertion (probe):** *In a fight with ≥3 COMBAT enemies holding LOS, the gap between incoming
shots never exceeds 4 s (suppression/telegraph pressure never fully lapses).*

---

## 3 · THE 20-HOUR AMBIENCE LAW vs the aggregate tier

The law (ADR-020 §4): *the living world's job is to make the quiet feel OCCUPIED, not the war feel
BUSY; every ambient event safe to ignore.* Hour twenty must be dread, not dead air.

**Found while checking:** the ambience layer is currently DEAD machinery. `AmbientWar`
(scripts/ai/ambient_war.gd) rolls its distant artillery/tracer/gunship events off
`SimClock.hour_advanced` — and `SimClock.advance()` has zero callers (ADR-025 evidence). Eight
systems listen to a clock nobody winds. So the consolidation doesn't threaten the ambience — **B1's
wire-or-die decision on SimClock is what finally turns the ambience ON.** From this lens: wire it
(whichever body wins B1, the clock must tick), because the atmosphere pillar is currently unserved.

**Does an AGGREGATE dot still produce the atmosphere?** Yes, if the tier has an explicit emissions
contract. The geometry works in our favor: promotion at ~500 m, max sight cap 140 m, near-field
sound ≤150 m — everything the player can *inspect* is LIVE-tier by construction. The aggregate owns
the FAR field, which is exactly where distant-fire ambience lives. What it must still EMIT:

1. **Deterministic presence** — seeded position/schedule on the patrol route (ADR-010). The patrol
   the player timed through map intel (ADR-021/022) must arrive when the dot says. This is also the
   stealth economy: you can ambush a dot you have never seen, and it promotes into exactly where the
   data said it was.
2. **Far-field war signature** — when WorldSim statistically resolves a fight, that event enqueues
   an `AmbientWar`-consumable emission at its TRUE location (distant small-arms crackle, tracer
   lines, glow). Today AmbientWar invents fictional events at random bearings; under the Living War
   it should prefer REAL WorldSim events when they exist (fictional filler stays legal as pure
   texture). **Assertion:** *every statistical combat resolution within ~800 m of the player
   enqueues ≥1 audible/visible ambient emission at its location — safe to ignore, but present.*
3. **Night illumination schedule** — aggregate camps pop illum on their clock. Beyond 500 m this is
   horizon glow (cosmetic); inside the promotion band `IllumFlare.is_lit` already feeds the sight
   cap, so flare gameplay is LIVE-tier's job automatically.
4. **A wakeup surface (both directions)** — big events cross tiers INTO the aggregate: the player
   blowing a cache (explosion-class, 104 m+) must reach dots in radius and change their statistical
   behavior — surfacing later only as an *offer* (Ambience Law / ADR-025 Phase 3), never a silent cost.
5. **What it must NEVER emit:** per-man audio (footsteps/voices — promotion band makes this
   impossible by construction; keep it law), perception results against the player, or beacon stamps.

The real ambience risk is the quiet direction: statistical resolution making the AO *silent* — fights
resolving as data with no signature. Rule 2's assertion is the guard. And the Ambience Law's other
half already stands via ADR-025: nothing the aggregate does may cost the player invisibly.

---

## 4 · Open question for the Summoner (kept to the one true either/or)

**Q1 — The fire-rhythm dial (duty-cycle):** adopting MoHAA duty-cycled shooting deliberately makes
big fights *longer and survivable-by-rhythm* — bursts with lulls you move in, instead of the current
continuous-pressure wall. It touches the under-fire feel that Pillar 1 and your lethality decrees
own, and it cannot be A/B'd on paper. **Accept rhythm-based incoming fire as the game's under-fire
feel (with VC long-hide / NVA short-hide asymmetry as the tuning lever)?** This lens recommends
YES — it is the single biggest fun win on the menu and HLL lethality makes the lulls terrifying, not
merciful — but it is a feel change only you can bless.

Everything else on my desk is council-resolvable: the B1 WorldSim-vs-AIDirector body is explicitly
delegated to the council by the briefing; leash-vs-hunt is answered by existing canon (movable-home
leash + `determination` gives the hunt its reach); the hearing table conflict is settled by ADR-005
(150 m is law, MoHAA's 52 m is shape-not-values).

---

## Wave placement summary (this lens)

| Lever | Wave | Scope |
|---|---|---|
| A4 exposure-ramp re-platform (+reaction/memory) | A (rides A1) | LAUNCH — preservation-class |
| Duty-cycle fire | B (own step) | LAUNCH — pending Q1 |
| Threat-spread w/ attacker discount | B (merged into 2:1) | LAUNCH |
| Leash (movable home, per-state) | B | LAUNCH |
| Hearing ladder + awareness roll | B2 | LAUNCH (ships with wakeup anyway) |
| Grenade token | C3 (token first) | LAUNCH; dummy-sim aiming post-launch |
| Player-look reciprocity, aim wobble | — | post-launch nice |

**Preservation probes this lens demands:** `test_ai_fairness` unmodified · `probe_witness` extended
across tiers (FM1/FM4) · staleness-bound probe (FM2) · materialization contract probe (FM3) ·
share-speed probe (FM5) · minimum-pressure floor probe (FM-floor) · ambient-emission probe (§3.2).
