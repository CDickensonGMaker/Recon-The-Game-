# URGENT — SUMMONER INPUT WHILE COUNCIL IS IN FLIGHT

**Time:** 23:23 · **Convened by:** §10 Director · **Status:** in-flight architects, do not panic.

The Summoner has added two scope decisions to this session before the council has finished
deliberating. They MUST be ingested by every architect before their analysis lands. If you are
mid-write, **stop, read this, and incorporate.**

---

## DECISION S1 — FIREBASE SCOPE: Modular, not bespoke

> *"I think the answer for the firebase is to make things in Blender and make a few more solid
> chunks of what a firebase is and let that become more modular when making the firebase."*

**Interpretation:** The Summoner is **rejecting** the P3 Firebase-Designer dream (`222e`).
He is **adopting** the RealVietnamRTS-style "kit of solid chunks, snap them together" approach.
This is a **scope cut + a content direction**, not a new feature.

**Architects — your verdicts must reflect:**
- **Game Designer (222e verdict):** close as **superseded by Summoner scope call**; or amend to
  "modular kit" if you read the new wording that way. Owner intent: built from Blender chunks.
- **Level Designer (firebase placeholder complaint, finding #2):** the placeholder must be
  **shrunk** so it does not oversell a system that is now a kit, not a designed-base. The shipped
  firebase should be **a small set of reusable chunks** that the campaign hub instantiates — not
  a hand-placed compound that implies bespoke design.
- **Godot Specialist / Lead Programmer:** the hub's geometry must be data-driven (a chunk list,
  not a `.tscn` monolith) so adding new chunks in Blender is a content change, not a code change.
  This is a small, contained wiring change.

**Constraint (binding):** the firebase kit MUST be **permitted under the GATE** because it is
**content + presentation for an already-shipped system** (the hub, ratified). It does NOT
require the campaign home-base hub (`ace` M8) to ship first — it is the hub geometry itself.

---

## DECISION S2 — 40/60 TERRAIN ARCHETYPE ACTIVATED (RECONgame-5r4y)

> *"I want to transition the terrain into a 40/60 type terrain. With 40 percent more lowlands
> and paddies with villages and random convoys of villagers and other army vehicles etc. And
> then 60 percent will be the more highlands with the forest and everything."*

**This is a major scope decision. It activates `5r4y` (P1, OPEN, never sequenced) and
recomposes it:**

| Slot | % | Composition |
|------|---|-------------|
| **LOWLANDS** | **40%** | Rice paddies (per v58s ruling) · villages (k2p: civilians flee/cower) · random convoys of **villagers** (civilian traffic) · random convoys of **army vehicles** (r3q unknown — see below) |
| **HIGHLANDS** | **60%** | Forest (per en75 ruling) · everything else the highlands support |

**The composition implies at least five new work items, all of which the council MUST bead:**

1. **Civilian traffic / convoy system** — a "random convoy of villagers" needs a model kit, a
   pathing system, a despawn rule, and a tactical consequence (Pillar 3: civvies are not gates,
   they are noise/cover/escape, never a fail-state).
2. **Army vehicle traffic on the AO** — distinct from the FROZEN `driveable vehicles` (per
   OVERSEER_CHARTER §3). These are **NPCs on rails/paths**, not player-driveable. Likely
   reconciles with the existing "ambient enemy traffic" or "patrol" systems.
3. **Village kit** — Blender chunks (huts, walls, gates, well, market, paths). This is the
   same modular approach as the firebase.
4. **AO archetype distribution** — the prior decree said "Paddy as a site" (rare, deliberate,
   real). The 40/60 promotion means paddies become **a third of all tiles** in lowland slots.
   This is a *density change*, not a per-site change. The council must reconcile.
5. **Civilian count and behavior** — k2p is P3 OPEN ("Civilians flee/cower + consequences");
   promoting it to P1 lands it inside the 40/60 scope. The 5r4y epic must own the bead and
   the dependency chain.

**Architects — your verdicts must reflect:**

- **Level Designer:** this is YOUR headline. The 40/60 is an AO archetype distribution table.
  Draft it. The paddy-as-site ruling must be re-examined: are paddies still rare sites, or
  does 40% lowland make them a **density band** with a few real "site" paddies marked for
  objectives? **Both can be true** — dense 40% paddies with 1–2 of them being tactically
  significant. State which.
- **Game Designer:** Pillar 3 audit. Does the 40/60 distribution create rails? Are civilians
  ever gates? Are convoys ever forced encounters? Are villages ever required? **All must be
  no, with explicit mechanics to keep them no.**
- **Godot Specialist / Lead Programmer:** the AO archetype must be **derived from the operation
  seed** (`xo7i` already established this pattern: "derive the AO archetype from the operation
  seed and call set_preset()"). The 40/60 distribution is the next layer: per-tile lowland/
  highland assignment from a *second* seeded pass. **The council must sequence this AGAINST
  the GATE** — does it preempt `v58s` (paddy as site) and `xo7i` (one terrain preset), or
  does it ride on top of them? The honest read: 40/60 is the **direction** `v58s` + `xo7i`
  were always going; promoting it gives Phase 2 of the prior decree more teeth.
- **Animator:** the firebase + village + vehicle kits are Blender chunks. **You are not the
  bottleneck for those** — the bottleneck is owner time in Blender. State which kit pieces
  Caleb needs to author first; do not assume they ship fast. The Prioritization Law: chunks
  that unlock more **findings** ship first (the village kit is probably the unlock for `4x7`'s
  civilian convoy system, so village kit → civilian traffic → army traffic in that order).

**Constraint (binding):** the 40/60 is **NOT** a feature epic. It is a **scope re-anchoring
of `5r4y`**. The council must:
- amend `5r4y` to reflect the new composition (40 lowlands+paddies+villages+convoys / 60 highlands+forest);
- add a new epic ("THE INHABITED WAR") that owns the civilians + convoys + villages kit;
- add a new epic ("THE FIREBASE KIT") that owns the modular chunks;
- sequence both against the GATE: each must be either **standing-decree-exempt** (presentation
  for shipped system) or sequenced **after** the playtest P1s clear.

---

## TENSION RECALIBRATION

The prior briefing named T1–T4. The Summoner's two decisions add:

- **T5 — Is 40/60 a new feature, or a re-anchoring of an open epic?** The council must decide
  which bead to amend and which to open. Recommendation: amend `5r4y`, open a new "INHABITED
  WAR" epic, open a new "FIREBASE KIT" epic. Confirm or correct.
- **T6 — The vehicle traffic question.** Vehicles are FROZEN per OVERSEER_CHARTER §3
  ("driveable vehicles" is post-core). The Summoner's "army vehicles" might mean NPC vehicles
  on rails. **The council must clarify before sequencing.** Recommendation: a literal read of
  "convoys of army vehicles" = NPC traffic = compatible with launch scope; driveable = DLC.
  Confirm or correct.
- **T7 — Does the firebase kit preempt `222e` (firebase designer)?** Yes. `222e` is the
  **custom-design dream**; the firebase kit is **the parts the custom-design dream would
  have snapped together**. Closing `222e` and opening the firebase-kit epic is the honest move.

---

## CRITICAL CONTEXT (just discovered) — `5r4y` IS A MUCH DEEPER BEAD THAN IT LOOKED

`bd show 5r4y` reveals the epic was opened with **substantially more spec than the title suggests**.
The Summoner's 2026-07-13 note in the bead body mirrors today's voice almost exactly:

> *"a good 40/60 but with the 40 percent of paddy, it doesnt just mean the rice paddies, its
> villages, its sparse jungle. its roads and we have living convoys doing their routines etc"*
> *"civilians on random walks with groups of eachother, evetually well get animals too"*

**Already shipped (per the bead's own audit):**
- `villages` (`_plan_village`, `VILLAGE_RAID`) ✓
- Civilians 2-3/hamlet with WANDER/FLEE/COWER + informers ✓
- Chickens ("live noise traps") ✓
- Night campfires ✓
- Ambient guards ✓

**The gap (verbatim from the bead):**
- ROADS — `engineering_system._build_road()` exists; worldgen never calls it.
- CONVOYS — patrol + LazyGroup machinery exists; needs a road to run on.
- FAMILIES — civilian.gd each wanders solo; needs shared-target orbits.
- ANIMALS — buffalo, dogs, pigs (chickens prove the pattern).
- `civilian.gd:80` — bare `randf()` for flee-vs-cower, **another** unseeded RNG, joins the determinism sweep.

**This means: the 40/60 epic is NOT net-new work. It is the activation of a 4-month-dormant
bead whose dependencies have been quietly shipping while nobody spoke to it.** The council's
job is sequencing, not design. The "INHABITED WAR" structure already exists in the bead body.

**Architects — re-anchor your analysis on this.** The five new beads the council needs are
NOT "design these systems from scratch" — they are **wire up the existing systems, sequence
them against the GATE, and decide which the Summoner is willing to author content for.**

---

## COUNCIL RULES REMINDER

- Do not relitigate yesterday's synthesis. The paddy-as-site ruling, the determinism fix, the
  Phase 0 measurement, the trunk-colliders-ships / destruction-defers ruling all stand.
- Cite beads. Cite code lines. Cite asset paths.
- Name what is sacrificed.
- Read the code, not the plan. Three councils have been fooled by prose.

---

**Director out. Architects — keep writing, incorporate S1 + S2, return when done.**
