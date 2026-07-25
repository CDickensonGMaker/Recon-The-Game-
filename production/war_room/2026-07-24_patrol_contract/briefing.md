# War Room Briefing — THE PATROL CONTRACT (core-loop decree)

**Convened:** 2026-07-24 · **Arbiter:** recon-overseer · **Summoner:** Caleb (vision blessed).
**Upstream of** the 2026-07-24 period-HUD decree (the loop defines what the HUD is FOR — reconcile them).
Planning gate — NO code until the Summoner blesses.

## The vision (Caleb's, blessed — stress-test it, don't rubber-stamp)
- **Before the wire, the player AUTHORS THEIR OWN ROUTE** — draws ~5 points on the tactical map. That is
  the plan. This is the parked "pre-patrol planning screen", reframed as YOUR-OWN-MAP ROUTE PLANNING
  (grease-pencil intent, ADR-022 player-marked layer), NOT a briefing/objectives screen.
- **Out the wire, COMMAND TASKS THE PLAYER DYNAMICALLY OVER THE RADIO, anchored to the route** ("check the
  village at your next marker"; "set up an overnight OP at Bravo, hold 10 mikes"). Tasks arrive IN THE
  FIELD over the net, never in a menu.
- **Dynamic EVENTS fire at/along the points** (ambush, large patrol, civilians from the treeline).
- **"Ground covered" accumulates** from the route as a soft patrol metric.
- **The overnight-OP / hold-an-area** is a tension setpiece (ties to the crouch/hold posture + suppression
  AI already built + SimClock/duty-cycle pacing).

## Three design calls Caleb BLESSED (build on these; council may stress-test)
1. **PERSISTENT WORLD, not spawn-on-route.** Villages/trails/streams/paddies already sit on the map; the
   player routes THROUGH them; command's taskings reference features actually near the drawn line. Route
   choice must matter (safe trail vs cutting the valley). Do NOT spawn locations on an arbitrary drawn line
   (gamey; guts world-foundation-locked).
2. **"GROUND COVERED" IS A PATROL-QUALITY SCORE, not a hard win condition** (sectors swept / features
   checked / taskings answered). RTB always legal (open-sim); the score just grades the patrol. No boring
   straight-line-march incentive.
3. **ROUTE = SUGGESTION, not a rail.** Command can pull the player off-line; ground-covered accrues from
   where they ACTUALLY walk; command reacts to deviation.

## Squad depth — LEVEL 2 (settled with Caleb)
Ambient squad that fights itself (existing combat posture: crouch-to-hold / stand-to-push / suppression) +
**2–3 FORGIVING orders that are AREA/DIRECTION, never point-precise** (HOLD / EYES-ON-or-SUPPRESS a
direction / MOVE UP), **aim-and-press** (the OpFlashpoint report verb). Orders MUST confirm via **radio
bark + compass order-line + roster change** — half the "AI ignored me" feeling is missing feedback. The
fear to guard: deep command + unreliable AI = rage; keep command shallow and orders forgiving so the AI
ALWAYS looks like it obeyed (area/direction orders bias intent the AI already had).

## What already exists (READ IT — this is an EVOLUTION, don't invent)
- **`scripts/missions/field_director.gd`** — the loop engine. Wire gate out 120m/back 95m
  (`_poll_wire_gate:801`); picks a LIVING location from `patrol_locations` (villages/camps) in the PUSH
  DIRECTION the player walked (`_pick_patrol_location:1030`, dot≥0.707); tiered fire-support grant
  (`_grant_fire_support:838`); "SIX WANTS US SWEEPING <bearing> <dist>M OUT" bark (`rebark_patrol:869`);
  dynamic crisis retarget over the net, off-net = no word (`raise_crisis:886`); escalation/hunters
  (`_process_escalation:87`); AAR banks + rank-clock + XP at the wire (`_bank_patrol:1074`); the report
  verb is ALREADY the aim-and-press fire-mission grammar (`arm_fire_mission`/`commit_fire_mission`).
- **`scripts/ui/topo_map.gd`** — the AO map (contours/water/roads/grid), draws the CO's grease-pencil
  sweep circle that NEVER checks off (`_draw_overlay:132`, comment `:136`), player green arrow, M-toggle,
  re-barks on open. THIS is where route authoring lives. ADR-022 two-layer law governs marks.
- **`scripts/squad/squad_system.gd`** — the squad (members, weapons_free, MOS roles) — the orders hook.
- **`scripts/autoload/sim_clock.gd`** + duty-cycle + combat posture (crouch-to-hold/suppression) — the OP
  setpiece substrate.
- **ADR-029 (DRAFT)** open patrol sim: one living world, gate is a pacing POINTER never a spawner,
  **§4 "No player-facing mission tracking, ever; floating objective markers forbidden"**, foot-only,
  Living War hooks PARKED. **ADR-022** the map is your memory (two layers: observed vs player grease-pencil).
  **ADR-006** scoring economy (payout moved to the wire AAR). **ADR-021** patrols. **ADR-020** authored
  threshold. **ADR-005** witness rule (fairness). **ADR-010** one seed per operation.

## The genuinely-NEW layer (the build)
Route-planner UI (draw ~5 grease-pencil points pre-wire) · ground-covered accumulator (silent grade from
ACTUAL walked path) · route-anchored tasking (select living features by proximity to the next waypoint,
replacing/augmenting push-direction) · overnight-OP setpiece pacing · Level-2 squad orders + confirm feedback.

## Tensions to name HONESTLY (do not gloss)
- route freedom vs tasking coherence (if command always overrides the route, why draw it?)
- OP-hold pacing: boredom (10 min of nothing) vs brutality vs a scripted-wave rail (freedom violation)
- persistent-world vs distance-gated spawns (a route waypoint with NO living feature nearby)
- **ADR-029 §4 boundary:** does a drawn route + ground-covered quietly become mission tracking / a
  resurrected briefing loop? (Guard: waypoints never check off; ground-covered is debrief-only, never an
  on-screen progress bar.)
- failure/abort semantics (RTB always legal; ground-covered = grade not gate; unwalked waypoints just
  don't accrue) · the "AI ignored me" rage even with forgiving orders.

## HUD reconciliation (the loop re-slots the period-HUD decree)
The loop PULLS FORWARD 4 of the 5 "parked" HUD items into the core build because they ARE the loop's
surface: the MAP (route authoring + memory), the COMPASS ORDER-LINE (command's tasking voice), the
overloaded REPORT VERB (aim+press = call+mark = also the squad-order verb), map-as-object. Only researched
identifiers stays pure polish. New HUD surface: an OP-STATE element (hold-area + mikes remaining) during
the setpiece. Say how the four persistent HUD elements + the map serve THIS loop.

## Your charge
Read the CODE for your lens, load your Godot skill folder, write full analysis to `analysis/<role>.md`
(cite file:line / ADR), return ONLY a ≤200-word verdict naming what is sacrificed.
