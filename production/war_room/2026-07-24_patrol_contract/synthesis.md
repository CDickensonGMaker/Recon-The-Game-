# DECREE — THE PATROL CONTRACT (core loop)

**Session:** 2026-07-24 · **Arbiter:** recon-overseer · **Status:** PROPOSED — awaits Summoner blessing.
Upstream of the period-HUD decree (`../2026-07-24_period_hud/synthesis.md`). Nothing built or blessed.

## Council verdicts (full analyses in ./analysis/)
- **Systems:** EXTENSION, not a new system — FieldDirector already holds ~85%. Route replaces tier-2
  push-direction in `_pick_patrol_location:1042`; re-tasking reuses `raise_crisis:886` retarget on the 0.5s
  poll; ground-covered = 25m grid cells on MissionState (ADR-010-clean, banked at `_bank_patrol:1075`, scored
  in `compute_score`); OP-hold = SimClock countdown + generalized `_poll_firebase_threat:907` ring + hunter
  cadence, NO wave spawner; orders extend `SquadSystem._unhandled_input`. **Biggest risk: a new
  `RouteManager`/`TaskingSystem`/`GroundCoveredTracker` node = the fossil — everything hangs on
  FieldDirector/MissionState; no third aim-and-press path.**
- **Game-designer:** CONDITIONAL YES, all five pillars — *evolution, not a new briefing*. Route = BIAS not
  authority. Ground-covered surfaces ONLY at the AAR (silent, saturating). OP-hold = probability window not
  scripted wave. Level-2 area/direction orders are on the right side of Pillar 4; aim-and-press + confirm
  defuses "AI ignored me." **Sharpest tension: how much authority the route holds — the authority that makes
  it worth drawing is what could reconstitute the briefing loop ADR-029 killed.**
- **Devil's-advocate:** the §4 guard is too thin (add: command may NOT name the player's own waypoints; the
  route may NOT drive selection unless all clauses are machine-enforced). Route tasking must REPLACE the
  push-direction picker, not stand beside it (else a 15th divergent world-system, ADR-023). OP-hold has no
  home in compressed SimClock. Confirm-barks on unproven AI manufacture rage. **MVP: playtest first; ship
  richer `raise_crisis` tasking + silent ground-covered; defer route UI / OP / confirm-bark until earned.**
- **UX:** ONE map, no separate planning screen (a pre-wire screen resurrects the briefing loop — REJECT).
  Route authoring = click-to-place pencil on the existing `topo_map._overlay` (LMB place / Backspace undo /
  Delete clear / M close, no "commit"); green polyline vs the CO's red circle; numbered 1–5 as IDENTITY not
  progress. Loop adds ZERO persistent HUD elements. **Biggest UX risk: with no floating marker, the
  order-line MUST always name an ORDINAL ("your 3rd mark") or observed FEATURE ("the village") — never a
  bare bearing.**

## ARBITER RESOLUTIONS

### R1 — Route authority (the sharpest tension, resolved)
The route is **INPUT/BIAS to the ONE existing selector**, never authority, never a second picker. Concretely:
`_pick_patrol_location` takes the route as its selection input **replacing** push-direction; **push-direction
becomes the no-route fallback** (walking = a degenerate 1-point route). ONE picker (kills the fossil + the
devil's "second world-system"). The route orders WHICH living feature command references; **a live crisis
always outranks it** (systems + game agree). Enough weight to be worth drawing; never a rail. **Sacrifice
NAMED and accepted:** planning-minded players will feel their route is "just a suggestion" — the correct side
of Pillar 3 (freedom > authored plan).

### R2 — The §4 boundary: FOUR machine-enforced clauses (binding, each probed)
This is what keeps the loop from becoming the briefing/objective loop ADR-029 condemned:
1. **Waypoints never check off** — no per-waypoint completion state (the `topo_map.gd:136` sweep-circle
   precedent: "never checks off, never updates").
2. **Ground-covered is debrief-only** — accrues silently on MissionState, surfaces ONLY at `_bank_patrol`;
   **never an in-field HUD counter or bar** (the instant it's on-screen it IS the tracking §4 forbids).
3. **Command references FEATURES or ORDINALS** ("the village", "your 3rd mark") — **never a briefing-style
   objective pin/label** ("proceed to Bravo — objective secured"). (UX ordinal/feature rule = devil's
   no-waypoint-naming rule.)
4. **The route is INPUT to the one selector** — never a second picker, never a spawner-on-the-line (design
   call #1; ADR-029 "the gate is a pointer, never a spawner").
A structural probe enforces all four (no waypoint-completion field; no in-field ground-covered node; the
tasking-string builder emits only feature/ordinal; exactly one location selector).

### R3 — Route authoring is the EXISTING map in a pencil mode (NO separate screen)
Definitively resolves the parked "pre-patrol planning screen": there is **no new screen**. Route authoring is
the `topo_map` you already have, in a click-to-place pencil mode, available anytime (pre-wire AND in-field,
ADR-022 redraw-freely). A separate pre-wire briefing screen is REJECTED.

### R4 — OP-hold runs on REAL time, not compressed sim-time (design gate)
The devil's concrete catch: "10 mikes" under compressed SimClock = seconds. **Ruling:** the OP-hold is a
**real-time tension window** (target ~3–5 real minutes presented diegetically as "the watch"), OR SimClock
drops toward 1:1 for the hold. Either way it is REAL minutes of tension, never sim-compressed. **This gates
the OP-setpiece phase** — confirm the actual SimClock ratio before building it.

### R5 — HUD re-slot (deliverable b): the loop adds ZERO persistent HUD elements
The period-HUD's four persistent elements STAND. The loop clarifies what they are FOR:
- **Compass + order-line = command's tasking voice** — now LOAD-BEARING (the loop's primary command channel).
  Must always name a feature/ordinal (R2.3) and **survive `hardcore`/SPARSE as an event tell** (`mission_hud.gd:302`).
- **Roster = squad state + order confirmation** (header flip / status cell on an order — the anti-rage channel).
- **Ammo, reticle** — unchanged. **Map (topo_map)** = route authoring + memory (the modal M-map, not a 5th
  persistent element). **OP-state** = a NEW TRANSIENT (top-right, 8px in the buffer) during the setpiece only.
The loop **pulls forward from the HUD's parked Phase-4 into core:** map-as-object (#4), the report verb (#3 =
the squad-order verb), and **dissolves the pre-patrol planning screen (#5) into the map**. Keyed radio
submenus (#2) may not be needed for the loop MVP (tasking is inbound; the player's outbound is aim-and-press
+ the existing fire-menu). Researched identifiers (#1) stays pure polish. **Still-pending HUD decisions
(buffer resolution 640×480 vs 512×448 vs 320×240; the Phase-0 blit spike) are UNAFFECTED and still await Caleb.**

## THE PHASED PLAN — sequenced by RISK (honors the vision, gates the unproven)
- **Phase 1 — THE SPINE (low risk, pure extension; buildable now).** Route as INPUT to the one selector
  (replacing push-direction, push-direction → no-route fallback) + multi-waypoint radio tasking reusing
  `raise_crisis` (`_advance_route_tasking` on the 0.5s poll) + **silent ground-covered** on MissionState
  (25m cells, debrief-only) + the FOUR §4 probes (R2). NO new UI. This IS the devil's "zero new UI" MVP plus
  the route-as-input spine.
- **Phase 2 — THE ROUTE PENCIL (medium risk).** Click-to-place green polyline on `topo_map._overlay` (R3).
  **Gate:** a playtest proves the drawn route changes tasking meaningfully (answers "is it worth drawing?").
- **Phase 3 — LEVEL-2 SQUAD ORDERS (gated on AI reliability).** 2–3 area/direction orders on SquadSystem,
  aim-and-press (report verb), VO + order-line + roster confirm trifecta. Built but **enabled only when the
  ambient squad provably holds/pushes on command in a playtest** (the devil's rage guard).
- **Phase 4 — THE OP-HOLD SETPIECE (gated on R4).** Real-time tension window on the generalized threat-ring +
  crouch/hold posture + suppression; no scripted wave. Blocked on the SimClock ruling.
The whole loop epic is subject to THE GATE (feature epics blocked while playtest P1s are open). Each risky
phase carries its own playtest gate — the devil's caution sequenced INTO the vision, not against it.

## NEW / AMENDED ADR (deliverable d)
- **Ratify ADR-029 (currently DRAFT) + add Amendment C — The Patrol Contract:** the route-as-input layer, the
  four §4 clauses (binding + probed), ground-covered (debrief-only grade), the OP-hold setpiece (gated on
  R4), Level-2 forgiving squad orders (gated on AI reliability). PROPOSED; ratified on Caleb's blessing.
- **Amends ADR-006** (scoring economy): ground-covered joins the wire-AAR payout.
- **Touches ADR-022** (route = the player grease-pencil layer, canonized), **ADR-010** (ground-covered is
  deterministic from the walked path given the op seed), **ADR-023** (ONE selector, NO manager node — probed).

## TRADEOFFS NAMED
Crisis outranks route → a loud AO can make the drawn line cosmetic (systems) · planning players feel the route
is "just a suggestion" (game) · confirm-barks on unreliable AI make rage worse, hence the Phase-3 gate (devil)
· the §4 line is fine and only holds if machine-enforced (devil) · the OP-hold is dead air unless real-time +
textured (all) · route authoring adds friction before "leave camp and find problems" — mitigated by making it
optional (no route = today's push-direction behavior, unchanged).

## BUILD LOG — PHASE 1 SPINE (2026-07-24, autonomous session, LOCAL commit, unpushed)
Caleb blessed spine-first + granted overnight autonomy. Phase 1 built, zero new UI. Files changed:
- `scripts/missions/mission_state.gd` — ground-covered accumulator (`_covered_cells`, 25m cells,
  `mark_covered`/`ground_covered_sectors`), `waypoints_reached`; both banked into `build_result` (AAR-only).
- `scripts/missions/field_director.gd` — `patrol_route` (PackedVector3Array) + `_route_idx` +
  `set_patrol_route`; `_route_anchor`/`_nearest_location_to`/`_advance_route_tasking`;
  `_pick_patrol_location` now takes the route as its input (push-direction stays as the no-route fallback —
  ONE selector, no new node); 0.5s poll runs `_advance_route_tasking` + `mark_covered`; `_bank_patrol`
  resets `_route_idx`.
- `scripts/ui/screens/debrief.gd` — one AAR line "GROUND COVERED: N SECTORS" (debrief-only, not scored;
  the ADR-006 payout hook stays unratified).
- `tests/test_patrol_contract.{gd,tscn}` — behavioral (route-as-input selection, bare-mark→area,
  ground-covered accumulator) + the FOUR ratcheting §4 probes (see below). NOT run by Wyrm (Caleb runs the suite).
The route path is DORMANT until a route is fed (game_flow never calls `set_patrol_route` yet) — normal play
is byte-for-byte the existing push-direction behavior. The P2 pencil becomes the UI that populates
`set_patrol_route`. No fossil created; no `class_name` added (no reimport needed).

## OPEN DECISIONS FOR THE SUMMONER
1. **Route authority** — bless "route = input/bias to the one selector; crises always override; orders
   tasking but never gates it" (accepting the "just a suggestion" feel)?
2. **OP-hold time model** — bless the OP setpiece running on REAL-time tension (or SimClock→1:1 for the hold),
   not compressed sim-time? Confirm the SimClock ratio. (Gates Phase 4.)
3. **Phase sequencing** — bless the risk-order (P1 spine now; P2 pencil, P3 orders, P4 OP each behind a
   playtest/ruling gate)? Or pull the route pencil (P2) earlier as the centerpiece?
4. **Squad-orders gate** — bless building the confirm trifecta but enabling orders only once the AI provably
   obeys area/direction in a playtest?
5. **No separate planning screen** — confirm route authoring is the existing M-map in a pencil mode (this also
   closes HUD open-decision #2 definitively).
6. **(Restated, still open, unaffected by the loop)** HUD authoring-buffer resolution (640×480 / 512×448 /
   320×240) and the Phase-0 blit spike — still awaiting your ruling.
