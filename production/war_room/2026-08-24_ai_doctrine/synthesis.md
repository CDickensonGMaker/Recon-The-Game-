# SYNTHESIS — Combat AI doctrine: hold cover, suppress, move as a unit (Arbiter's weave, 2026-08-24)

Inputs: `analysis/systems_cartographer.md` (as-built map + bounce diagnosis, all file:line) and
`analysis/research_advanced_ai.md` (F.E.A.R./TLOU/Halo/Killzone/CoH/Arma mechanisms, sourced).
The two converged without cross-talk: the cartographer found the exact holes the research's
cheapest techniques fill.

## The finding that frames everything
The Summoner asked to "sync them together but maintain the asynchronistic versions." The map says:
**already half-true.** EnemyBase and AllyBase run ONE shared core (CombatGoals / CombatPosture /
AIMarksmanship / NavRouter, one cover-claim broker); garrison defenders reuse AllyBase. What
diverged is the SHELLS: perception, targeting, commitment, and squad intel are parallel
implementations (ally targeting is nearest-wins with zero stickiness at 6.7 Hz,
`ally_base.gd:880-917`; the covering-fire census is per-squad for enemies but one GLOBAL STATIC
for every US soldier, `ally_base.gd:188-190`). And **neither side has a squad-level coordinator
object at all** — the siege director hands out objectives, never roles. "Moving as a unit" cannot
emerge from men who share no squad state.

## Why they bounce (measured, not felt)
1. **Ungated panic interrupts.** Every hit taken, witnessed casualty, and pin-lift force-expires
   the current goal (`goal_timer = 99.0` — `enemy_base.gd:2494,1090`; `ally_base.gd:1984,988`),
   so under fire the 8/4 dwell/cooldown machinery is held open and men re-plan every 150–1000 ms.
   The 8/4 decree undershot NOT because its constants were wrong but because these side doors
   bypass them.
2. **Cover leased per-goal, not per-fight.** Dwell starts once at arrival and never renews
   (`ally_base.gd:1580,1020`); target death strips enemy cover via INVESTIGATE
   (`enemy_base.gd:1464-1485`); a 1.5–3 s ally LOS blink flips COMBAT→IDLE and releases the claim
   (`ally_base.gd:1500-1502,1845-1853`). Nothing says "hold the rock until the fight ends."
3. **Flickering inputs.** Covered men shed suppression at 0.9/s vs 0.12/crack gained, so the FEAR
   gate (>0.25) toggles every burst cycle and ADVANCE/FLANK scores swing ~6.7×/s
   (`combat_posture.gd:23-26`, `combat_goals.gd:74/116/131`). Ally `incoming_pressure` memory
   exists and is never fed to the scorer (`ally_base.gd:1041`).
4. **SUPPRESS_TARGET has no executor on either side** — it silently maps to COMBAT, which only
   fires with LOS. Deliberate suppressing fire does not exist in this game today.

## THE DECREE-SHAPE (three phases, each independently shippable, perf-priced)

**PHASE 1 — STOP THE BOUNCE (tuning + ~20-line wiring; near-zero CPU).**
Interrupt debounce (Class-A interrupts respect a short refractory window instead of force-expiring
goals) · fight-scoped renewable cover commitment (dwell refreshes while the fight is live; claims
survive target death and LOS blinks) · suppression decay rebalanced so the gate holds between
bursts · feed `incoming_pressure` into the scorer · incumbent-margin + sustained-challenger goal
hysteresis, scoring against debounced aggregates (the TLOU cure for exactly our per-frame score
swing) · ally target stickiness (kill nearest-wins retarget churn). This phase alone attacks
"they bounce around too much."

**PHASE 2 — THE SQUAD COORDINATOR (small new system; one autoload per side, 1–2 Hz squad tick,
O(1) per man).** Roles + fire tokens, F.E.A.R.-slot style: per squad ONE suppressor slot (finally
gives SUPPRESS_TARGET an executor — fires at last-known cells, writes area suppression, no LOS
required), N exposure tokens gating who may leave cover at once (the CoD/Halo trick: limiting
simultaneous attackers IS what reads as life-preservation), and the cover-claim table folded in.
Fixes the global-static census bug by construction (per-squad state both sides). Suppression
drives the scorer both ways, CoH-style: suppressed multiplies reposition down; pinned locks churn.

**PHASE 3 — MOVING AS A UNIT (medium; sits on Phase 2).** Two-element bounding overwatch:
elements alternate suppress/move via refusable coordinator orders, moves staggered across thinks,
O(element) per bound. This is the visible "they work together" payoff.

**THE DOCTRINE LAYER (data-only, zero CPU) — the "sync but asymmetric" answer.** One shared core;
US / NVA / VC become .tres doctrine files weighting the SAME knobs: cover dwell, token counts,
press thresholds, suppression sensitivity, bound distances. US reads methodical base-of-fire;
NVA presses disciplined; VC ambush-and-fade (high initial aggression, early break-contact).
`AIPersonality` folds into it. The siege stays sacred: `assault_press` doctrine sets exposure
tokens ≈ ∞ so 45 men still press the wire (the 7/30 ruling survives by data, not exception code).

## Rejected as unaffordable (Law 2 — named, not hidden)
Full GOAP · TLOU-scale raycast/pathfind budgets · Killzone visibility LUT (bake-at-world-stamp
flagged as a future idea). The frame is already CPU-bound in AI; everything adopted above is
O(1) per man per think or squad-tick-rate.

## Sacrifices
- Phase 1 touches the hottest AI files 13 days from the EA target — but the ruled siege test
  (after body-swap → ammo) will judge the exact feel the Summoner convicted, so testing the siege
  with the bounce unfixed measures a build we already intend to change.
- Phase 2/3 add the first squad-state object; a new failure class (stuck tokens) — mitigated by
  token TTLs. Phase 3 without real footage-grade movement polish can read as robotic relay races;
  staging/randomization budgeted in.
- Unifying ally/enemy shells is refactor risk near ship; Phase 1 deliberately does NOT unify —
  it fixes both shells in place with the same constants. Full unification is post-EA hygiene.

## Sequencing recommendation (for the Summoner)
Phase 1 lands BEFORE the ruled siege test (it is tuning-class, exempt-eligible, and the siege
test is his acceptance test for exactly this feel). Phases 2–3 build after the siege test reads
Phase 1's effect — or post-EA if the date tightens. His call; the ruled build queue
(body-swap → ammo → siege test) is not otherwise disturbed.
