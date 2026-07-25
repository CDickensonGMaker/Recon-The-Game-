# GAME-DESIGNER — THE PATROL CONTRACT

**Lens:** does the loop (author-your-route → dynamic route-anchored tasking → ground-covered grade →
overnight-OP setpiece → Level-2 forgiving orders) serve the five pillars and the north star
*"i just wanna leave the camp and go find problems"*? Judged against code, not the plan.

**What I read:** `field_director.gd` end-to-end (the loop engine), `topo_map.gd:132-157`
(the grease-pencil overlay), ADR-029, ADR-022, ADR-006, `BIBLE.md:84-95` (the pillars of record).

---

## THE CORE FINDING: this is an EVOLUTION of a pointer that already ships, not a new briefing loop

The single most important thing the council must internalize: **the tasking engine already anchors to a
player-chosen direction.** `_pick_patrol_location:1042-1044` reads
`pdir = world.player.global_position - patrol_gate_pos` — *where the player chose to walk out* — and
`:1053` picks the nearest living site inside a ±45° cone of that heading (`dot >= 0.707`). The drawn
route is not a new system; **it upgrades a single instantaneous push-vector into a persistent multi-point
polyline.** Framed that way, most of the ADR-029 §4 fear evaporates: we are not resurrecting a briefing,
we are giving the player a richer way to express the push direction the code already honors. That framing
should govern the whole build — every time the route feels like it's becoming a mission, the fix is to
make it behave more like the push-vector it replaces (a *bias*, never a script).

---

## Q1 — ROUTE-FREEDOM vs TASKING-COHERENCE: what's the honest ratio?

**Verdict: the route retains meaning IF command's override is a rare, diegetic, always-optional SPIKE —
which is exactly how the crisis path is already built.**

Trace the two tasking sources in code:

- **The baseline tasking** is `_pick_patrol_location` at the wire (`_poll_wire_gate:810`), fired ONCE per
  excursion. Today: push-direction. Tomorrow: route-proximity. This is the ~80-90% case — the standing
  sweep the player gets when he crosses the wire.
- **The crisis override** is `raise_crisis:886`. Critically, it is already gated three ways that *protect*
  route meaning: (1) it only retargets `if patrol_out` and the player is on the net (`_radio_check()`,
  `:891-894`) — **off-net, the word never reaches him and the sweep does not move** (`:884-885` comment,
  Fairness Law/ADR-005); (2) crises are event-driven from `DynamicMissionFactory`, not a steady tick —
  they are spikes, not a metronome; (3) answering is *physically optional* — RTB is always legal
  (`_bank_patrol` fires on any inward crossing, `:822`), so a crisis the player ignores just sits in the
  ring (`patrol_locations.push_front`, `:890`) and keeps until he chooses it.

**So the honest ratio is already right, and the danger is not "command overrides too much" — it is the
OPPOSITE two failures:**

1. **The baseline tasking becoming a waypoint checklist.** If route-anchored tasking degrades to "go to
   waypoint 3," the drawn line becomes an objective list and ADR-029 §4 is violated. **The guard (from
   ADR-022):** command references *living features near the line* ("check the village at your next
   marker"), never the abstract waypoint. The village exists in the persistent world (`patrol_locations`,
   populated at `setup_patrol:794-798` from villages/camps only); the waypoint is the player's own
   grease-pencil intent. Command reads the world, not your pencil. The waypoint **never checks off** —
   mirror the grease circle at `topo_map.gd:136-137` that "never checks off, never updates."

2. **The route having too LITTLE authority, making it busywork.** If the line does nothing mechanical,
   drawing it is hollow ceremony. **The fix:** the route must actually *replace push-direction* as the
   input to `_pick_patrol_location` — bias site selection toward proximity-to-the-drawn-line instead of
   proximity-to-the-instantaneous-heading. Then the line has real, felt influence (it changes which
   village Six points you at) without having authority (crises still override, and you can walk off it
   any time).

**The honest ratio, stated as a dial:** route biases ~100% of *baseline* taskings; crises override
~10-20% of the *time-in-field*, always diegetically and always optionally. That preserves route meaning
because the override is rare, earned (on the net), and reversible.

---

## Q2 — OP-HOLD PACING: tension setpiece or dead air?

**Verdict: it is a tension setpiece IF and ONLY IF threat comes from the LIVING world as a
probability-weighted window (design call #1 is correct), NOT a scripted wave. But 10 real minutes is the
sharpest usability risk in the whole build, and the "quiet hold" must be a designed outcome, not a bug.**

The substrate for a NON-scripted hold already exists and is proven:

- `_process_escalation:87` spawns hunters weighted by `field_mult` (`:98`, harder the longer you're out)
  from a **finite pool** (`_hunter_pool = 12`, `:74`) — you can bleed the AO dry. This is emergence, not a
  rail.
- `_maybe_launch_sappers:980` rolls ONCE per night against `SAPPER_CHANCE` keyed to the earned threat tier
  (`:737` — LOW 0.0 / MODERATE 0.2 / HIGH 0.45 / CRITICAL 0.7). **A LOW-tier night can be genuinely
  empty, and that is the design working** — not a missing wave.

The OP-hold should be built as a **third instance of this same probability pattern**, not a new
scripted-encounter system. During the hold: nearby living forces (patrols/camps already in the AO within
some radius) get a per-interval, threat-tier-weighted chance to path toward the OP. That satisfies design
call #1 exactly.

**Why it's fun without a wave (the pillars pay off here):**

- The tonal north star is literally *"boredom-then-terror"* (`BIBLE.md:101`). A hold that MIGHT be quiet
  is the mechanical expression of that line. Pillar 2 (Atmosphere) does the heavy lifting: SimClock night,
  weather, distant ambient contact you can hear but not see.
- The fun is front-loaded into the **decision and the set-up**, not the payoff: you *chose this ground*,
  you set your men with Level-2 orders (HOLD a direction, EYES-ON the likely approach), and the
  crouch/hold/suppression posture is already built to reward a squad that's set before contact.
- Fail-forward (Pillar 5): a cold OP is not a failure. The held sector still credits the patrol-quality
  grade. A quiet night that still "counts" is the anti-frustration valve.

**The risk I must name loudly:** 10 minutes of *real* time is a long time to ask a player to sit, and
OFP/Arma tolerance for it is a minority taste. Mitigations the Summoner must rule on: (a) let SimClock
*compress* the hold's clock so 10 mikes ≠ 10 wall-minutes; (b) the threat probability should **ramp**
across the window so an empty hold is rare at MODERATE+ but stays possible at LOW; (c) the OP needs
micro-texture (ambient ecology, the living world's distant war) or the quiet reads as "the game froze,"
not "the jungle is holding its breath." Without (a) or (c), the setpiece becomes the dead air the
briefing fears.

**The HUD reconciliation call:** the new OP-STATE element (hold-area + mikes remaining) is the ONE place
this loop legitimately puts a timer on screen. Keep it diegetic and quiet — a wristwatch glance, not a
mission-objective bar. It states a fact the player asked for ("how long have I held?"), it does not track
an objective.

---

## Q3 — GROUND-COVERED as a GRADE not a GATE: where's the line?

**Verdict: a silent, debrief-only grade computed from the ACTUAL WALKED PATH avoids both the
straight-line-march incentive AND the ADR-029 §4 tracking prohibition — PROVIDED it never surfaces before
the AAR and has a saturating ceiling.**

The AAR already exists as the single legal surfacing point: `_bank_patrol:1074` fires only on the inward
wire crossing, banks XP via `DebriefScreen.compute_score` (`:1078`), and emits the one closing toast
(`:1083`). ADR-006's payout has already moved here. Ground-covered belongs *inside this function and
nowhere else.*

**Draw the line precisely:**

| CAN measure (silent, at `_bank_patrol` only) | CANNOT become (violates ADR-029 §4) |
|---|---|
| Sectors swept — grid cells the player's actual path entered | An on-screen "3/5 sectors" counter mid-patrol |
| Features checked — villages/camps he got within observation range of | A floating objective marker over a feature |
| Taskings answered — crises he responded to (`_visited_locations`) | A waypoint that checks off / turns green |
| Route adherence (soft) — how much of the drawn line he actually walked | A progress bar toward "route complete" |

**Why it does NOT incentivize a straight-line march (the briefing's stated fear):** the grade scores the
path you *actually walked* (design call #3), not the line you drew. A straight beeline sweeps fewer
sectors and checks fewer features than a thoughtful patrol, so a beeline naturally scores *low* on a
quality grade — the incentive points toward real patrolling, which is the intent.

**Why it does NOT invert into aimless-wandering-to-farm-sectors:** cap the ceiling. The grade should
*saturate* at "answered what Six asked + checked the features near your route." Beyond that, diminishing
returns — you cannot farm it by wandering the empty map, and you cannot ace it by beelining. It is a
QUALITY grade with a natural top, not an accumulator.

**The ADR-029 §4 guard, stated as one law:** *ground-covered is computed continuously but revealed once,
at the wire, as a debrief line. If any part of it renders on the in-field HUD, it has become mission
tracking and must be cut.* That single rule keeps it a grade, not a gate.

---

## Q4 — LEVEL-2 ORDERS vs PILLAR 4 ("you suggest and call, not position individual men")

**Verdict: AREA/DIRECTION orders are on the RIGHT side of the line, and aim-and-press + always-confirm is
the correct defusal of "AI ignored me" rage — but MOVE-UP is the one order that can drift across the line,
and Pillar 4's second clause is PROVISIONAL (BIBLE.md:89-94), so this is a bet, not settled ground.**

Pillar 4 of record (`BIBLE.md:88`): *"you suggest movement, call targets, request support, and the squad
holds its own AI intent. A design that has you positioning individual men violates this pillar."*

The three proposed orders (HOLD / EYES-ON-or-SUPPRESS a direction / MOVE UP) sit on the correct side
because:

1. **They are AREA/DIRECTION, never point-precise.** You never tell a named man to stand at a coordinate.
   You bias the *collective* toward a bearing.
2. **They bias intent the AI already has.** The combat posture system (crouch-to-hold / stand-to-push /
   suppression) is the squad's autonomous behavior. An order nudges the collective's existing intent — it
   does not puppeteer a body. This is the exact distinction Pillar 4 draws.
3. **The order verb is the SAME aim-and-press grammar as fire missions** (`arm_fire_mission` →
   `_update_placement` → `commit_fire_mission`, `field_director.gd:276-307`). You aim at ground/a bearing
   and press. That verb is definitionally *a suggestion placed on the world*, not a unit dragged to a
   spot. Overloading it for squad orders keeps the input honest to the pillar.

**Does aim-and-press + always-confirm actually defuse the rage? Yes — and the briefing's diagnosis is
exactly right: half the "AI ignored me" feeling is missing feedback.** The confirm triad (radio bark +
compass order-line + roster change) means that even when the AI's *execution* is imperfect, the player
HEARS acknowledgment and SEES the order register. And because the orders are forgiving (area/direction),
**the AI has no precise failure state to visibly miss** — you said EYES-ON north, the squad was watching
its sectors anyway, now it biases north, and you got a "ROGER — EYES NORTH." The rage comes from *precise*
orders the AI *visibly* botches (go to that rock; he stands 3m off). Area orders eliminate the botch. This
is correct design.

**The two cautions I must name:**

1. **MOVE UP is the dangerous one.** "Move up" implies a destination, and a destination is one small step
   from positioning. Keep it a *direction bias* — "advance along my aim-bearing / toward that treeline as
   a group" — with the squad holding its own formation and spacing intent. If MOVE-UP becomes "go to this
   exact point," it has crossed into Pillar-4 violation. Build it as a heading, not a goal node.
2. **Pillar 4's anti-puppeteer clause is explicitly PROVISIONAL** (`BIBLE.md:89-94`): *"pillar 4 is open
   to changing as i play test more. if it makes more sense to try to be more tactical with the troopers i
   will take it that way."* Level-2 is therefore a **bet on the current pillar.** It is the right bet —
   it's the forgiving ceiling that keeps the AI looking obedient. But if the Summoner plays and wants
   MORE control (Level-3: position individual men), that is a pillar change he has pre-reserved the right
   to make, and the OP-hold + forgiving-orders design would need revisiting. Build Level-2 as the ceiling;
   flag that the ceiling is provisional.

---

## Q5 — THE SHARPEST PILLAR TENSION THE SUMMONER MUST RULE ON

**How much AUTHORITY does the drawn route have over the tasking engine? — because the same line that makes
route-drawing worth doing is the line that can quietly reconstitute the briefing loop ADR-029 exists to
kill.**

This is the knife-edge, and it is a Pillar-3-vs-Pillar-3 internal tension (Freedom-as-player-authorship
vs Freedom-as-no-rails / the-seeded-world-generates-the-stories):

- **If the route has too MUCH authority** — if the drawn line strongly determines what happens, where you
  go, and what you're graded on — then the world is on the *player's* rails, command is set-dressing, and
  the player has authored his own mission. That is the briefing loop by another name (ADR-029 Decree:
  *"no mission tracking that the player needs to worry about"*), and it betrays the north star: you didn't
  *find* problems, you *scheduled* them.
- **If the route has too LITTLE authority** — if the line changes nothing mechanical — then drawing it is
  busywork, the authoring fantasy is hollow, and players stop bothering. The whole new UI layer is dead
  weight.

**My recommended ruling (the Summoner decides):** the route is a **BIAS, never an authority.** Concretely:
it replaces the push-vector as the input to `_pick_patrol_location` (proximity-to-line instead of
proximity-to-heading); command references *living features* near the line, not the line itself; crises
override freely (`raise_crisis` unchanged); ground-covered grades the *actual walked path*, not adherence
to the line; and **no waypoint ever checks off.** Route has influence you can feel and zero authority that
tracks. That keeps it the grease-pencil intent ADR-022 already blessed — *"a plan, not a command"*
(ADR-022 §3) — rather than an objective list.

**What is sacrificed by that ruling (no free lunch):** players who WANT their plan to matter mechanically
— who draw a careful 5-point route and expect the game to honor it as a contract — will feel the line is
"just a suggestion the game ignores." That is the same complaint ADR-022 already accepts for the wrong-map
law: *"some players will read it as a bug... That is the design working."* We are choosing emergence over
authorship at the exact point they conflict, and a minority of planning-minded players will feel their
authored intent was cheap. The alternative — honoring the route as a contract — is a better feeling for
those players and a dead north star for the game. The Summoner must rule which player he is building for.

---

## SUMMARY TABLE — pillar service

| Element | Serves | Risk / guard |
|---|---|---|
| Author-your-route (grease-pencil, pre-wire) | P3 (author your war on paper), P4 (suggest not command) | Must stay a BIAS on the existing push-vector, never authority; ADR-022 §3 |
| Route-anchored baseline tasking | P3 (places, not rails) | Reference living features, never waypoints; never checks off (ADR-029 §4) |
| Crisis override | P5 (fail forward), P2 (living AO) | Already correctly gated: on-net only, optional, reversible (`raise_crisis:886`) |
| Ground-covered grade | P3 (stealth/patrol as economy, ADR-006) | Debrief-only at `_bank_patrol`; saturating ceiling; NEVER on in-field HUD |
| Overnight-OP hold | P1 (set squad, believable fight), P2 (dread), P5 (quiet counts) | Probability window not scripted wave; compress the clock; micro-texture the quiet |
| Level-2 area/direction orders | P4 (you're IN the squad), P1 (set before contact) | MOVE-UP must be a heading not a goal; P4 clause is provisional |

**Overall:** CONDITIONAL YES. The loop serves all five pillars *if* the route stays a bias not an
authority, ground-covered stays debrief-only, and the OP-hold's quiet is designed rather than accidental.
The architecture to do all three already exists in `field_director.gd` — this is an evolution, and the
guards are the same ones the code already enforces.
