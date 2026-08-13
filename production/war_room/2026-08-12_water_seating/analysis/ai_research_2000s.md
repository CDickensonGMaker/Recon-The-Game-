# AI RESEARCH ARCHITECT — the 2000s squad-AI canon, measured against RECONgame

**War Room 2026-08-12 · ANALYSIS ONLY, no file edited outside this one.**
**Summoner's charge:** *"maybe do more research on combat games of the 2000s and their ai and compare
and contrast what were doing to them and see besides the wiring we can do to make the squads read as
more alive and less as bullet fodder"*
**Governing constraint (his earlier ruling):** *"i want modern ai thinking with our units with our old
school feeling game"* — contemporary decision quality, deliberately retro presentation, **both factions**.

**Scope discipline.** Three sibling analyses already own the wiring, the expression layer and the
person-level aliveness: `ai_realism_systems.md` (mute channels, constants, ally parity),
`ai_realism_design.md` (VO, perceived bot-tells), `squads_alive.md` (individuation, continuity,
relationships). **This document does not re-litigate any of them.** My charge is the layer none of them
touched: **tactical architecture** — what decides, who decides it, and where men stand.

Every code claim carries `file:line` (POINTER LAW). Every canon claim carries a URL, and where a
famous claim has **no primary source I say so** rather than repeating it.

---

## 0 · VERDICT UP FRONT

**The most important research result overturns the premise of my own brief.**

The brief asked me to find the source for "F.E.A.R.'s AI was not unusually smart, but barks made players
rate it smart; mute the barks and players rated it dumb." **There is no such experiment.** It does not
exist. Orkin never ran it and never claimed it. What exists is better and more useful, and it is in §1.

The second research result is harder for this project to hear: **the only controlled measurement anyone
in the canon actually published says perceived AI intelligence is driven primarily by how DANGEROUS the
enemy is, not by how well it announces itself.** Bungie changed nothing but enemy toughness and
"Not Intelligent" went 72% → 0%.

**The biggest structural gap in RECONgame is not a missing planner.** Goal-scoring is adequate; F.E.A.R.
proves the tactical bar is far lower than its reputation. The gap is that **RECONgame has no squad-level
decision-maker in combat.** Every man scores his own goals in isolation against a shared *blackboard*
that never decides anything. Nobody is ever *assigned* a job. There is no "you suppress, you move."

And underneath that sits a defect I found that makes the whole fire-and-manoeuvre conversation moot:
**suppression in RECONgame is a one-way weapon.** Only the enemy emits it. The player and his squad
mechanically cannot pin anyone with small arms — and cover, which the AO already grades cell by cell, has
no effect on suppression in either direction. §5d.

**A third result deserves front billing because it is the Summoner's own ruling, arrived at
independently by two studios.** FSW's AI lead: friendlies *"have to be held to a higher standard, because
you're able to observe their behavior much more closely."* Vietcong's engine tooltip: *"use about 0.2 for
the enemies, 1 only for the PC team."* **The ally-heavy weighting is not a preference; it is the canon's
settled practice, and it should be an ADR line so nobody later "fixes" the asymmetry.**

---

## 1 · F.E.A.R. (2005) — the most important entry, and the most misreported

**Primary sources.** Orkin, *Three States and a Plan: The AI of F.E.A.R.*, GDC 2006 —
https://www.gamedevs.org/uploads/three-states-plan-ai-of-fear.pdf · Orkin, *Combat Dialogue in FEAR: The
Illusion of Communication*, Game AI Pro 2 ch.2 —
https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter02_Combat_Dialogue_in_FEAR_The_Illusion_of_Communication.pdf
· **Jacopin, *Game AI Planning Analytics*, AIIDE 2014** —
https://ojs.aaai.org/index.php/AIIDE/article/download/12728/12576/16245

### 1a. THE BARK-REMOVAL EXPERIMENT DOES NOT EXIST — do not put it in a decree

Traced to exhaustion by two independent researchers. Orkin's chapter contains **no playtest, no A/B, no
numbers**. The claim propagates through forum threads and YouTube explainers with no citation chain
terminating in a primary document. Rabin's retelling in Game AI Pro 3 cites only Orkin's chapter.

**What Orkin actually claims — which is stronger, and is first-party:**

> *"If the AI didn't say it, it didn't happen."*
> *"Dialogue can be used to create the illusion of behavior that has never even been implemented."*
> *"We never wrote any code for the AI to call in reinforcements, but the reviews said we did!"*
> *(fig. caption)* *"Dialogue works better than barks for conveying agent intelligence **or even
> intelligence that doesn't actually exist**."*

**If a citable experiment is ever needed**, the honest one is Al Enezi & Verbrugge, AIIDE 2023 —
https://ojs.aaai.org/index.php/AIIDE/article/view/27512 — which found contextual dialogue let a
**simple** AI behaviour match a **complex** one in player enjoyment. That is the real, measured version
of the thing the myth was gesturing at.

### 1b. The load-bearing mechanism: barks are POST-HOC NARRATION

From the GDC paper: barks are chosen ***"after the fact, once the squad behavior has decided what the
A.I. are going to do."*** The dialogue never feeds back into the decision. It is a **read-out of a
decision already made**.

**This is the single most transferable fact in this document** and it is *architectural*, not content.
It means the bark system must sit downstream of a decision layer that has something worth announcing.
RECONgame's men currently make six-verb decisions in isolation; there is very little worth narrating
because there is no *joint* intent. Wiring more barks onto isolated decisions produces chatter, not
communication. **Barks are the read-out of the squad layer. Build the layer, and the barks write
themselves.**

### 1c. How small F.E.A.R. actually was — the numbers that should calm this project down

Jacopin **instrumented the retail game**: 17 sessions, ~3h45m, 6,679 plans.

| Measured | Value |
|---|---|
| FSM states | **3** (Goto, Animate, UseSmartObject — the third is a specialised Animate) |
| Distinct actions ever fired | **55** (11 defensive, 16 offensive, 28 patrol/animation) |
| Typical plan length | **1–2 actions** |
| Most-used single action | `UseSmartObjectNode` — **26% of all occurrences** |
| `{GotoNode, UseSmartObjectNode}` | 2,355 / 6,679 = **35%** of all planning |
| Effect of action costs (the search heuristic) | **no observable effect** on which actions fired |
| Plans generated for one rat, after the player left | **393** |

**The celebrated planner's most common decision was "walk to a designer-placed node and play an
animation."** Jacopin suggests replacing a third of the planning with a hash table.

### 1d. The squad layer — five behaviours, and the flank was an accident

A global coordinator re-clustered AI into squads by proximity. Each squad ran **zero or one** behaviour
at a time, filling **slots**. The complete shipped list: **Get-to-Cover, Advance-Cover, Orderly-Advance,
Search** (corroborated against Monolith source `AIEnumActivityTypes.h`, five entries including
ExchangeWeapons).

Orkin, verbatim: *"The truth is, we actually did not have any complex squad behaviors at all in F.E.A.R."*

And the legendary flanking: *"It appears that the A.I. is flanking, but in fact this is just a side
effect of moving to the only available valid cover he is aware of."*

**Nobody wrote a flank. A bark announced an accident as a manoeuvre.**

*Caveat for the record:* the GitHub tree labelled "F.E.A.R. SDK 1.08" contains actions absent from
F.E.A.R. 1 (vehicles, tasers, Berserker) and is likely F.E.A.R.-2-era. Its ~135 actions / ~72 goals are
an upper bound — **Jacopin's 55 is the defensible figure.**

### 1e. What the illusion actually rested on

Post-hoc narration · dialogue for behaviour that was never implemented · **dialogue that excuses
failure** ("Get out of there!" / "I've got nowhere to go!" converts a stuck AI into a deliberate one) ·
**designer-placed nodes doing the tactical reasoning** · two voices implying a relationship, which
implies coordination.

**The failure-excusing bark is the cheapest trick in the entire canon and RECONgame has no equivalent.**
Rabin's rule (§4) is that players forgive everything *except* glaring mistakes. F.E.A.R.'s answer was to
make the AI *narrate its own dead ends*, converting a bug into characterisation. Note this against
RECONgame's `_bound_fail_count` / `_cover_fail_count` (`enemy_base.gd:1908`, `combat_goals.gd:35`) — the
project already **counts its own tactical failures** and says nothing when they happen.

---

## 2 · Halo (2001–2007) — the only hard perception numbers in the canon

**Primary source.** Butcher & Griesemer, *The Illusion of Intelligence: The Integration of AI and Level
Design in Halo*, GDC 2002 — https://www.jmeiners.com/shamans/papers/ai/the_illusion_of_intelligence.pdf

### 2a. THE PLAYTEST TABLE — "Tougher = Smarter"

**The AI code did not change. Only enemy toughness changed.**

| | Weak Enemy | Tough Enemy |
|---|---|---|
| Too hard | 12% | 7% |
| About right | 52% | **92%** |
| Too easy | 36% | 0% |
| **Very Intelligent** | **8%** | **43%** |
| Somewhat Intelligent | 20% | 57% |
| **Not Intelligent** | **72%** | **0%** |

This is the measured result the mythical F.E.A.R. experiment is standing in for, and it points somewhere
else entirely. Independently echoed in later academic work: multiple papers report a positive correlation
between perceived NPC **aggressiveness** and perceived **intelligence**.

**Direct consequence for RECONgame, and it is a comfortable one:** Pillar 1 already mandates HLL
lethality. The project's existing lethality doctrine is, by this measurement, *already* its single
largest perceived-intelligence asset. The danger is the inverse — see §5, where I show the player's squad
is on the wrong side of a lethality asymmetry it cannot answer.

### 2b. Halo's design goals, and the one that indicts subtlety

Stated goals: **Intelligible, Interactive, Unpredictable.** Under *Intelligible* → **"Transparent thought
process."** Under Communication of Intent: **"Discarded: Hidden States. Inform the Player"** via
**"Language, Posture, Gesture"** and **"Focus of Attention."**

**Randomness was explicitly discarded** as a source of unpredictability, as was a fuzzy emotion system.
Unpredictability was to come from an unpredictable *player*, unpredictable *situations*, and **analog
reactions varying in position and timing**.

**Things to Avoid: "Subtlety," "Looking Broken," "Insufficient Challenge."**

### 2c. Bungie's own verdict on barks contradicts Orkin — and both are right

Halo's combat dialogue: triggered from decisions and stimuli, evaluated "hundreds per second" by
priority / context / uniqueness / relevance, **nearby characters can reply**. Scale: **57 events, 166
dialogue types, 12 speaking characters, 5,147 recorded lines.**

Bungie's own label for all of it: **"Used for flavor only."**

**The honest synthesis, and the Arbiter should carry this into any decree:** Bungie built the same
reply-capable bark system as Valve and F.E.A.R., at 5,147 lines, and classified it as flavour — while
their *measured* perception swing came from toughness. Orkin says barks are the whole game. **Both are
true on different axes: toughness determines whether the player rates the AI competent; barks determine
whether the player can NAME what the AI just did.** Halo measured the first. F.E.A.R.'s reviews reflected
the second.

### 2d. The Halo 2 behaviour graph — smaller and blunter than its reputation

Isla, *Handling Complexity in the Halo 2 AI*, GDC 2005 —
https://www.gamedeveloper.com/programming/gdc-2005-proceeding-handling-complexity-in-the-i-halo-2-i-ai

- **Not a tree — a DAG**, ~50 behaviours in the core graph, one subtree reachable from several places.
- **Relevancy is BINARY, not scored.** Isla explicitly abandoned score-based child competition as
  unscalable. The dominant arbiter is a **prioritized list**: *"march down a prioritized list of the
  children. The first one that can run, does, but higher-priority siblings can always interrupt the
  winner on subsequent ticks."* By far the most commonly used scheme.
- **Impulses** are the key trick: pull the *condition* out of the behaviour and place it as a node in the
  priority list that references a behaviour living elsewhere. Stimulus behaviours are impulses inserted
  asynchronously by event callbacks, so rare conditions are not polled — but they must be inserted *into
  the tree*, so higher-priority behaviours still get their say first.
- **CORRECTION TO MY BRIEF: the word "blackboard" does not appear in Isla's paper.** The real knowledge
  structure is the **prop** — a per-object repository of perceptual information, whose purpose is to let
  belief diverge from truth: *"the actor can believe things that are not true, and we now enter the realm
  of AI that can be tricked, confused, surprised, disappointed."* The memory story is a pool allocator
  forced by a 192K budget on the original Xbox.
- **Squad control = masking, not reasoning.** Designers get **orders** (a set of placed firing positions
  plus scripted transitions) and **styles**: *"The style is really just a list of allowed and disallowed
  behaviors… a behavior cannot be considered unless it is explicitly allowed by the order's style."*

**How grunts read cowardly — and it is not a morale system.** Verbatim: *"grunts, the cowardly creatures
of Halo 2, will have an inordinate number of **retreat impulses**, whereas marines have extra
action-coordination behaviors."* Cowardice is **authored data density** — more high-priority flee entries
near the top of the same list — plus inherited numeric parameters. **Not a scalar, not a separate brain.**

### 2e. Halo 3 objectives (GDC **2008**, not 2009) — and Isla names the illusion himself

Slides: https://web.cs.wpi.edu/~rich/courses/imgd4000-b12/lectures/halo3.pdf ·
Recording: https://archive.org/details/GDC2008Isla

> *"The dance is about the illusion of strategic intelligence… Designer provides the strategic
> intelligence / AI acts smart within the confines of the plan provided by the designer."*

Halo 2 was imperative (designer-authored FSM transitions on `<75% alive?`, `<25% alive?` — *"Explicit
transitions → n² complexity"*). Halo 3 went **declarative**: designers enumerate *tasks that need doing*;
the system allocates squads. Tasks are self-describing (priority, activation script, capacity) and nest.
Isla's own description of the algorithm: *"Pour squads in at the top, allow them to filter down to the
most important tasks to be filling RIGHT NOW. **Basically, it's a plinko machine.**"* The distribution is
**greedy bin-packing**, minimising a cost that includes *the maximum* travel distance so squads move as a
body rather than each man taking his own nearest task.

**The canonical Halo encounter is a scripted retreat ladder:** occupy territory → fallback → last-stand →
break → finish. *"…plus a little 'spice': snipers, turrets, dropships."* That five-beat shape is the
design; the objectives system merely schedules it.

**Leadership — the closest thing to morale, and RECONgame already has the mechanism.** Leader death sets
the task to a **"broken" state**: no redistribution in or out while broken, and *"NPCs have 'broken'
behaviors"* (charge, flee, or clump). So Halo's famous "kill the Elite and the Grunts panic" is a
**task-state latch plus a swap to individual broken behaviours** — not a propagating morale simulation.
`EnemySquad.is_broken` (`enemy_squad.gd:158`) is structurally the same latch; what RECONgame lacks is the
**broken behaviours** to swap into.

Isla's own "Badness Summary" is worth recording: it required designer training, the squad was the wrong
granularity (*"give a guy a sniper rifle… shouldn't he then be allowed to occupy a 'sniper' task?"*),
there was no mid-encounter squad splitting, and *"Great for prototyping — became much more complicated as
we neared shippable encounter state."*

---

## 3 · Killzone, S.T.A.L.K.E.R., Ghost Recon, The Last of Us — the supporting cases

### 3a. Killzone (2004) — **the single most directly applicable system in the canon**

Primary: Beij & Straatman, *Killzone's AI: Dynamic Procedural Tactics*, GDC Europe 2005 —
https://www.guerrilla-games.com/media/News/Files/gdce05_killzone_ai.pdf · Verweij thesis, VU Amsterdam
2007 — https://www.guerrilla-games.com/media/News/Files/VUA07_Verweij_Hierarchically-Layered-MP-Bot_System.pdf
· Straatman et al., *Hierarchical AI for Multiplayer Bots in Killzone 3*, Game AI Pro ch.29 —
http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter29_Hierarchical_AI_for_Multiplayer_Bots_in_Killzone_3.pdf

Guerrilla's slide 4 names the approach it rejects: *"Common approach: level designer placed hints,
triggered scripted behavior."* Their answer: *"having the rules and concepts to dynamically compute
solutions to tactical problems."* **The graph and a visibility table are baked offline; the scoring runs
at runtime against live threats.**

**The entire tactical brain of Killzone's combat movement is a weighted sum with four integer weights:**

| Term | Weight |
|---|---|
| Proximity (nearby waypoints) | **20** |
| Line of fire to primary threat | **40 if partial cover, 20 otherwise** |
| Cover from secondary threats | **20** |
| Inside preferred fighting range | **10** |

*"Adding up all the annotations yields the most promising attack position."* Four integers. That is it.
The same evaluation is reused as **A\* link cost** (add cost for traversing a friendly line-of-fire, or
being under fire) — tactical pathfinding for free.

**Cover is a 64KB pessimistic lookup table, and this is the load-bearing trick.** *"Tactical decisions
involve hundreds of LoF checks. Ray casts typically expensive."* So: *"For every waypoint, per radial
sector, record the largest distance from where an attacker within that sector can fire at the waypoint.
**Inaccurate, but consistent.**"* **Killzone's LoF table for 4000 waypoints: 64KB.** Being *pessimistic*
means the AI occasionally hides behind cover it did not need — **which reads as caution, not as a bug.**

**Personality is the same function, reweighted.** The evaluator is parameterised by *Action* ("what kind
of position?") and *Personality* ("what factors are important?"), fed by *Current situation* and *Squad*.

**SUPPRESSION — Guerrilla's algorithm, and it is directly implementable in RECONgame:**

> *"Deny the threat use of good attack positions by shooting bursts at these positions… **Evaluate
> threat's attack positions from HIS perspective**, select those attack positions we can fire into."*

Concretely: take waypoints near the presumed threat, score **20/30** for offering the threat a line of
fire at you, **20** for offering him nearby cover from you, **select positions scoring ≥ 40**, then merge
targets that overlap in yaw and pitch so the burst reads as one sweep. **Suppression is the same position
evaluator run with the enemy as the subject.** See §6 A1/T3 — this is the missing executor.

Scale, from the conclusions slide: PS2, 2004, tactical position picking + tactical pathfinding +
infantry and mounted-MG suppression + indirect fire, **"up to 14 AI characters fighting simultaneously."**

**Killzone 1's decision layer was NOT a planner** — goals with heuristic relevancy scored at fixed
intervals, highest wins, decomposing into fixed predefined behaviours. Failure handling is instructive:
when an action fails (no pursuit position found), the behaviour aborts and **the goal takes a temporary
relevancy penalty**; *"there is no explicit communication between goals."* **That is architecturally what
RECONgame already has** — a scored goal arbiter with hysteresis — and RECONgame's `_cover_fail_count` /
`_bound_fail_count` (`combat_goals.gd:35`, `enemy_base.gd:1908`) are the same failure-penalty idea.

**Killzone 2's HTN swap changed only the top layer**; position picking, perception, body goals and the
virtual controller *"remained basically the same."* And its conflict resolution is confessedly trivial:
*"The planner will always select the highest / first branch for which the preconditions can be met… As a
result, there is no need for other conflict resolution mechanisms."* **Priority is branch order in a text
file** — architecturally the same commitment Isla made with the prioritized list. Replan rates:
**individuals 5×/s, squads 2×/s** — *"long plans tend to invalidate quickly."*

**RECONgame thinks at 6.7 Hz** (`enemy_base.gd` THINK_INTERVAL 0.15, LOD-scaled to 0.3/0.6 at range,
`:37-52`). **Faster than Killzone 2's individuals and faster than Killzone 3's 5 Hz.** Think rate is not
this project's problem.

### 3a-bis. THE MEASURED PLAYTEST — what sold intelligence and what destroyed it

Verweij §6.1.3: 24 Guerrilla staff, 18 responses, bots vs humans over 8 rounds. **The bots lost every
round** (30–51% score ratios) and respondents still called the difficulty "about right" and "tough but
beatable." Two findings matter enormously here:

- **What sold it: SPATIAL GROUPING.** *"All but one of the respondents noticed the bots' grouping
  behavior… Most respondents thought the grouping of the bots made their behavior look human like and/or
  intelligent."* One tester inferred a plan that did not exist: *"if we fended off an assault on a
  particular base… we could expect one of the others to be under attack shortly."*
- **What destroyed it: IDENTICAL SHARED PATHS.** *"The way the squads move was said to be **'ant like'**,
  as all squad members choose identical paths and end up walking directly behind each other in a long
  line."*

**This is a direct warning to RECONgame.** The follow formation is eight independently rolled offsets on
a ring around the player (`ally_base.gd:367`) walked through one shared router — and the patrol column is
an explicit staggered file (`FILE_SPACING 4.0`, `FILE_STAGGER 1.1`, `enemy_base.gd:138-139`). The
staggered weave exists *precisely* to avoid the ant-line, which is the right instinct; the finding says
**guard it**, and says that squad-level grouping — men visibly moving as a body — is the highest-value
readability signal measured anywhere in the canon.

Also measured: **accuracy was the most divisive single variable** (11 of 18 commented, splitting between
"very life like" and "unnaturally good"). Same bots, opposite verdicts, by player skill. Worth remembering
before any lethality tuning is declared correct.

### 3b. S.T.A.L.K.E.R. — the reputation-exceeds-implementation case study

Primary: Iassenev interview —
https://www.gamedeveloper.com/game-platforms/interview-inside-the-ai-of-i-s-t-a-l-k-e-r-i- · GSC mod
wiki — https://sdk.stalker-game.com/en/index.php?title=Smart_Terrain_Tutorial

- Two-tier switch. **Offline**: "the character does not play animations or sounds" — no pathfinding, no
  physics, a token on a graph. **Online**: full stack. **Switch radius ~150 m.**
- **A-Life did not simulate behaviour off-screen. It simulated OCCUPANCY AND JOB SLOTS.** Smart terrains
  have a `capacity`, capture NPCs, and assign jobs by state (day → patrol, night → rest). "The living
  world" is a scheduling system.
- The gap: players remember A-Life for emergent stories mostly produced by faction-vs-mutant encounters
  resolving *inside* the 150 m bubble where the player could witness them, plus the player's own
  narrative back-fill. **The offline layer contributed almost nothing observable.**

**RECONgame has already ruled on this and ruled correctly.** ADR-025 is SUPERSEDED — *"AIDirector
tick-list wins; WorldSim tiers die"* — on the measurement that only **2.8%** of the AO is off-AO from
spawn on a 1280 m map. **Do not reopen off-screen simulation.** STALKER's own record says the payoff is
attribution, not simulation, and RECONgame's map is too small for the bubble to matter.

Worth noting the shipped-combat contrast: STALKER earned its "they actually flank you" reputation
**without** a bark system, buying it instead with lethality and directional gunfire audio. Same lesson as
Bungie's table, from the opposite direction.

### 3c. Ghost Recon (2001) — lethality as a perceived-intelligence purchase

Manual: http://vztimg.exent.com/Prem/products/315250/manual.pdf

- Up to 9 men in **three fireteams** (Alpha/Bravo/Charlie), commanded through a **command map**.
- **The entire AI behavioural vocabulary is three Rules of Engagement: Recon, Suppress, Assault.**
- **One shot could kill**, in both directions.
- The reported experience: *"You'll get a radio message from a nearby fireteam telling you they've come
  under fire or have lost a man, but you often won't hear a shot."*

**Two mechanisms, both relevant.** (1) Extreme lethality removes the evidence — you die before you can
observe the AI being stupid. (2) It forces attribution — a single unexplained death gets narrated by the
player as "he flanked me," whether or not anyone flanked. **Three ROE states was enough** because the
player supplied the tactics and the AI supplied compliance.

**For Pillar 4 this is the encouraging finding:** a very small, legible order vocabulary outperformed a
large one, and RECONgame already ships FOLLOW / HOLD / MOVE-TO / FIRE-TOGGLE.

### 3d. The Last of Us (2013) — the modern answer, and the one worth copying

McIntosh, Game AI Pro 2 ch.34 —
http://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter34_Human_Enemy_AI_in_The_Last_of_Us.pdf

Outside the 2000s window but it is the direct descendant of everything above and it names the fix:

- **A Combat Coordinator** — a global arbiter handing out **roles**: Flanker, Approacher, Investigator,
  StayUpAndAimer, OpportunisticShooter. An NPC *requests* a role; **if unavailable, the request is
  rejected.** This is how you get one flanker instead of five — **legible tactics instead of a mob.**
- **Flanking is a cost function, not a pathfind result.** They abandoned exposure-map flanking because
  routes "could vary wildly from one frame to the next" — visually incoherent. Replaced with a
  **fixed-shape cost field relative to the current combat vector**, producing stable, readable arcs.
- Layering order, stated explicitly: *"Once the AI decision making was in place, dialog could be layered
  in."* **Same ordering as Orkin's post-hoc narration.**

**The Combat Coordinator is the thing RECONgame structurally lacks.** §5.

---

## 3.5 · THE SUPPRESSION CANON — BiA, FSW, CoH, SWAT 4, Vietcong, OFP

**Now verified.** Four of these six are readable at or near source level: Bohemia released the OFP engine
(https://github.com/BohemiaInteractive/CWR, June 2026), SWAT 4's v1.1 SDK shipped its UnrealScript AI,
Vietcong's Ptero-Engine II scripting SDK is effectively Pterodon's AI design document
(http://vcfiles.free.fr/files/scripting.html), and Company of Heroes' squad motion is published in full
as Chris Jurney, *AI Game Programming Wisdom 4* §2.1
(https://forum.arongranberg.com/uploads/short-url/rWod3K2KhNWcOEdjewnsLXQKU6A.pdf).

### 3.5a. Company of Heroes — the reference implementation, and it is one float

Suppression is a hidden meter **owned by the squad**, driven by **rounds fired, not hits**:

| | enter | exit |
|---|---|---|
| Suppressed | > **0.20** | < **0.15** |
| Pinned | > **0.60** | < **0.50** |

Baseline recovery **0.008/sec**. **Cover multiplies both sides**: recovery ×500 garrison, ×5 heavy, ×2.5
light, ×0.5 red; accrual ×0.1 green, ×0.5 yellow, ×1.5 red. **Net ~50× swing in time-to-pin across a
hedgerow — which is why moving four metres feels like a tactical epiphany.** Accrual carries an ~13 m,
×0.8 splash to neighbouring squads. Suppressed = output ×0.5; Pinned = ×0.1 and immobile. **After 4 s
pinned, received accuracy ×4** — a hard-coded mercy timer, then the lethality turns on.

Quinn Duffy on intent: *"When your squads were pinned, you wasn't taking any damage, so it gave you time
to make a plan."* Combat was deliberately slowed — ~**90 s** target fights at long range vs 10–15 s
close — and **the 90-second fight length is what makes the off-screen audio channel actionable**: a
panicked bark from out of frame is only feedback if you can still get there in time (~56,000 speech
lines).

**Jurney's three admissions are the most useful paragraphs in the whole dossier:**

> *"Occasionally, a leapfrog is performed even when there is no interesting feature, **just to keep the
> squads looking interesting**."*

> On drift: *"it will look a bit robotic because the combination of the fixed offsets, speed control, and
> obstacle avoidance code is **too good** at keeping units in their formation-mandated spots. To
> counteract this, we have each unit store a personal drift variable…"*

> **Soft leapfrog:** during a hurried move the element leader is sent to a point 80% of the way to cover,
> *"veering out of formation obviously toward cover and slowing a bit but never stopping. The effect is a
> very intelligent-looking unit who is in a hurry, but not so much as to totally ignore his own safety."*

**Randomness was added because the AI was too accurate to look alive.** Also: followers chase the
leader's position **~2 s predicted ahead**; each soldier **reserves his own cover slot** at the
destination; formation switches on terrain under the leader (wedge open, tight confined, staggered column
on roads); follower repath runs at ~**1.5 Hz**.

### 3.5b. Brothers in Arms — and the ruling that should govern this project's whole AI budget

Suppression is a scalar per enemy squad shown as **one circle**, red → transparent grey. Two team types
with doctrinal jobs (fire team fixes, assault team flanks). The Four Fs were taught by retired Col. John
Antal through a live Field Training Exercise. Orders are **physically situated** — Baker shouts and gives
the period hand signal, and *your own body position gates what you can order*.

**Squadmates refuse suicidal orders** — *"your squad is smart enough to refuse orders to directly charge a
machine gun nest or enemy tank."* Nothing sells self-preservation faster than a subordinate who says no.
And **the player is subject to suppression too**: Gearbox modelled erratic weapon accuracy and made
incoming fire disturb the player's own aim, which makes the mechanic empathetic rather than instrumental.

**The cheap trick: enemies in cover are effectively bulletproof from the front.** Frontal fire cannot
kill — it can only fill the suppression meter. The doctrine is enforced by an invulnerability rule, not by
ballistics.

**And the finding this project most needs to hear:** *Gearbox held back Road to Hill 30's enemy AI on
purpose* — the enemy "usually will not move under fire even when the player's flanking action has been
detected" — because it feared that teaching a whole new way of playing an FPS was hard enough without a
cutthroat opponent. **Earned in Blood** then switched repositioning on. **The first game shipped a
deliberately passive enemy so the player could learn the grammar; the sequel spent the AI budget only
after the grammar was internalised.**

Hell's Highway then **broke its own loop** by adding a third-person cover camera: *"Instead of constantly
flanking enemies I found myself going to cover and using my rifle zoomed in from behind cover to pick
enemies off."* **Giving the player a better aiming affordance dissolved the need to manoeuvre.**

### 3.5c. Full Spectrum Warrior — the asymmetry that validates the Summoner's ally weighting

There is no fire button, and the reason is doctrinal. Creative director Wil Stahl: *"if the squad leader
is firing his gun, it means he messed up."*

**AI lead Michael van Lent states RECONgame's own problem for it:**

> *"It's interesting that often the **friendly** characters have to be held to a higher standard, because
> you're able to observe their behavior much more closely, and you spend a lot more time looking at
> them"* — versus a shooter where *"an enemy character might be on the screen for a second and a half
> before you shoot it."*

**FSW inverted the normal AI budget and spent it on the units the camera never leaves.** That is exactly
the Summoner's ruling, arrived at independently in 2004, and it is the single strongest external support
for prioritising the ally side.

**The cheap tricks, both admitted.** Cover is **100% effective**, which buys three things at once: the
player's read can never be wrong, suppression becomes a state flip instead of a probability curve, and
squad AI collapses from a decision problem to a geometry problem. And **"Looking Dumb Range"** — level
designer Kristine Golus: *"the range at which the game started to look so dumb that it broke immersion…
he'll suddenly develop 100 percent accuracy."* Inside a radius the enemy stops being a simulated marksman
and becomes guaranteed lethality. Van Lent, pre-ship: *"They're also probably going to turn down the
effectiveness of the AI's weapons in firefights, so the firefights will last longer."* **Neither end of
that lethality curve is a simulation.**

### 3.5d. Vietcong (2003) — the closest relative RECONgame has, and it is a parameter sheet

**Correction for the record: there is no squadmate called "Bird."** Team A-216 is Hawkins (player),
**Le Duy Nhut — Pointman** (Vietnamese ex-Viet Minh defector), Defort (radio), Crocker (medic), Hornster
(MG), Bronson (engineer).

**31 tunable floats per man** (`s_SC_P_AI_props`) — the ones that matter:

| Field | Documented meaning |
|---|---|
| `boldness` | *"0.5 is very cautious, 2 is medium, 4 is high. **10 is almost suicidal**"* |
| `coveramount` | how far he runs for cover **as a ratio of distance to nearest enemy**, default 0.5 |
| `reaction_time` | **"Default 0 for the US, 1 for the VC"** |
| `hear_imprecision` | *"0 absolute hearing, 1 average, 5 very bad"* |
| `aimtime_max / _canshoot` | **0.7 s max, 0.1 s min — nobody snaps onto target** |
| `wounded_aimtime_mult_max`, `wounded_shoot_imprec_plus` | **wounded men aim slower and shoot worse, scaled by current HP** |
| `scout`, `berserk` | investigate first contact / attack without covering — **both default 0.0** |

Faction identity is a **preset of dispositions**, not different code — the same conclusion Killzone and
Halo reached by different roads.

**Grenades are problem-solving, not a timer:** *"AI uses the grenades when it knows about some enemy for
some time, **but cannot hit him normally** – ie enemy is sitting behind the obstacle."*

**Two-tier certainty, shared across the group:** `SC_P_Ai_GetEnemies` returns all known contacts
*"including the ones the AI is not sure about (just heard something)"*; `SC_P_Ai_GetSureEnemies` returns
only confirmed. **RECONgame's `contact_conf` debounce is the same idea and is already correct.**

**The single most relevant line in the entire dossier for a jungle game:**

> `SC_Ai_SetShootOnHeardEnemyColTest(BOOL)`: *"if enabled, AI will shoot **ONLY** if the target is
> hittable… so no shooting to the tree behind which is the target hided. **Use only in the underground or
> in the interior. By default it is set to FALSE.**"*

**Outdoors, Vietcong's default was: the AI shoots at where it BELIEVES you are, through the bush.** That
is suppression-by-accident, and it is the behaviour a Vietnam firefight needs. It is also the source of
the "they see me in pitch blackness" complaints — the trade is named.

**The pointman loop, and the gate that made it work.** The player interacts by looking at the man and
pressing USE — but it is gated on tactical silence by the official macro `PointTalkCheck`: **you cannot
talk to your pointman while he knows about enemies, or while either of you is mid-sentence.** The trap
loop is deliberately two-actor: pointman halts and warns → player must walk up and talk to learn what is
ahead → player crawls to the tripwire himself.

**Stealth mode is a squad-wide fire-discipline boolean that also changes the UI's voice:** *"all the
engine interaction texts will be in a **whispered mode**… the AI will not shoot until PC starts to shoot,
or the enemy discovers the team – they will just try to hide, aim, but not shoot."*

Speech is **tagged by register with a filename prefix** — radio `r`, scream `s`, whisper `w`, inner `i`,
megaphone `m` — each with its own audible and subtitle distance. ~6,950 dubbing clips.

**The cheap trick, and it is the cheapest tension generator ever documented.**
`SC_Ai_FakeEnemy_Add`: *"This will tell the AI that on the specified place there could be enemy and they
will try to stay in the cover. **If you will use NULL for the fake enemy position… they will assume enemy
is everywhere and they will move like under fire** until you switch the fake enemy off."* Whole stretches
of tense, crouching, bounding movement through empty jungle are **the designer lying to his own AI.**

And the pointman's most iconic beat is labelled by Pterodon itself: `SC_Ai_PointStopDanger` —
**"just eye candy, nothing more"** — it halts him and makes *"all other team members react slower."*
**The staggered reaction is an authored cue.**

**The budget ruling, again:** `shortdistance_fight` — *"Computing is very expensive, **use about 0.2 for
the enemies, 1 only for the PC team**."*

**Vietcong 2 replaced the pointman loop with a BiA-style two-verb suppress/flank system and lost the
pointman, the navigation loop, and the jungle.** Reviewers judged it sideways at best. **A cautionary
note against adopting BiA wholesale.**

### 3.5e. Operation Flashpoint — belief modelling, and the honest history of suppression

The decision core is a **task stack, each task carrying its own FSM** — not a tree, not a planner.
`CombatMode { CMCareless, CMSafe, CMAware, CMCombat, CMStealth }`; `Semaphore { Blue … Red }`, where
**RED literally spawns subgroups** — *"AI can form subgroups and break off to engage"* — which is the
mechanism behind "they split up and flanked me."

**The per-group belief record, in 2001, with an explicit error vector:** believed position, `posError`,
three independently-decaying confidences (presence ~30 s, identity 240 s, side 240 s), hard forget at
120 s. And the detail nobody writes about:

```cpp
if (target->isKnown && target->lastSeen < Glob.time - 10) {
    float minRadius = Glob.time - target->lastSeen;   // 1 m of uncertainty per second unseen
    target->posError = <random vector, radiusXZ = minRadius*2, ...>
```

**The AI's mental pin for a lost contact drifts outward a metre per second.** That is why fire lands where
you *were*. First contact is jittered by **±100 m**.

**Knowledge propagates at conversational speed through a named person:** `myDelay = 1.0×ability`
(1.0 optics / 1.5 eye / 2.5 sound-only), `groupDelay = 2.5×myDelay + 2.5` — **the squad learns later than
the man.** And side-wide propagation is gated on the leader being alive *and personally holding the
contact*: **killing the squad leader severs that squad from the side-wide intelligence net.**

Perception: *"moving observers see LESS"*; 45° peripheral cone, outside which `visibleAccuracy = 0`;
**hearing never identifies side** (hence "unknown"); `visibleSize` prone **0.10** vs sprinting 1.00.
Getting shot jumps `knowsAbout` **instantly to 1.5** at any range.

**The callouts are debug output with voice acting** — *"Two — enemy man, at eleven o'clock, two
hundred"* is assembled at runtime from the reporting unit's own belief record; when he calls a jeep a
"car" he has genuinely misidentified it. Near contacts get a clock bearing, distant ones a map grid.
**And the player's command menu is the AI's own message bus with a keyboard attached** — there is no
"player mode" of the AI to be caught out.

**Morale is one line:**
```cpp
void AIGroup::CalculateCourage() { _courage = Leader()->GetAbility(); }
```
**A squad's willingness to fight is literally its leader's skill value.** Medics are targeted first
because `cost = 8 // a medic; cost = 4 // an officer; cost = 1 // a grunt`.

**And the honest history: OFP had NO suppression.** Grepping the released engine for `suppress` returns
only audio ducking. Real suppression arrived in **ARMA 3 v1.42, April 2015** — *fourteen years later* —
and BI's own Ondrej Kuzel described its limits precisely: *"it is possible to fully suppress the AI with
about 5-10 bullets"*, *"**AI prioritizes cover that is not suppressed**"*, and crucially **"Note that this
update does not change the explicit AI behavior and decision making when under fire."** ARMA 3
suppression is an **aiming-error multiplier and a cover-preference term. It is not morale.**

> **The one-line summary: OFP's AI is not smarter than its contemporaries. It is *wronger*, and it says so
> out loud.**

Every competitor of 2001 gave the AI perfect information and hid it behind cone tests and reaction
delays. Bohemia spent its budget on a genuine decaying belief record with modelled propagation delay and
a spoken protocol that renders that belief back to the player continuously. **Perceived intelligence
turned out to be almost entirely a function of (a) visible uncertainty and (b) a legible channel through
which that uncertainty is communicated — not of decision sophistication.**

**This is the strongest possible endorsement of a system RECONgame already has and is currently
undermining.** The `EvidenceLedger` scatter (55 m on noise, 8 m on bodies), the breadcrumb hunt, the
witness rule and `contact_conf` are all Bohemia-shaped. And `ai_realism_systems.md` §2·0b already
documented that the *lossy* channel is switched off while the *telepathic* one is unbounded. OFP's source
says which way that ratio must point.

### 3.5f. SWAT 4 — fifteen behaviours and one float

Not a behaviour tree: a **hierarchical goal/action architecture with resource arbitration** (Abercrombie
& Atkin, GDC 2005). Resources are hierarchical body parts — `RU_HEAD=1, RU_ARMS=2, RU_LEGS=4` — so a
suspect can run, track you and shout as three separately arbitrated actions. Behaviours compete via a
float bid with **hard gates first, then a randomised bid inside a personality band** (passive suspects bid
flee 0.25–1.0, aggressive 0.0–0.75).

**The compliance latch is the whole design:**
```
RandomChance = 1.0 - FRand();
if (RandomChance >= GetCurrentMorale())  bWillComply = true;
bListeningForCompliance = false;   // only a NEGATIVE morale change re-arms this
```
**You cannot spam "GET DOWN!" to re-roll — you must do something to him first.** A random number
generator becomes a negotiation.

Two mechanics worth stealing outright: **approach angle is a weapon** (a 2-D dot against his aim
orientation, `SurprisedComplianceAngle=90°` — flank and shout for the biggest non-weapon modifier in the
game), and **surrender decays** (a surrendered suspect left unobserved regains nerve permanently and
stackingly, and `PickUpWeaponAction` is in his repertoire — which is what makes cuffing urgent).

**Cowardice is audible and per-individual:** `ScreamChance` = 0.65 low-skill / 0.5 medium / **0.2 high**.
And behaviour emerging from **failed navigation** is the cheapest realism in the game: wedge a door and he
barricades; block him enough times and he stops chasing.

> **Irrational spent the entire AI budget on one axis — *will this person surrender to me?* — and made
> every weapon, every approach angle and every second of eye contact a term in that one equation.**

---

## 4 · The illusion literature — what actually buys perceived intelligence

Rabin, *The Illusion of Intelligence*, Game AI Pro 3 ch.1 —
https://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter01_The_Illusion_of_Intelligence.pdf

> *"If you do not work on the illusion side of the equation, you are likely failing to do your job."*

Three mechanisms: **players want to believe** and are "incredibly forgiving **as long as the virtual
humans do not make any glaring mistakes**"; **anthropomorphism** (Waytz et al. 2010 — when people
encounter incomprehensible behaviour they apply human traits to make sense of it, i.e. **ambiguity is
converted into intent**); and **expectations physically alter experience**.

Levers relevant here, and their PSX verdict:

| Rabin lever | Verdict for RECONgame |
|---|---|
| **Reaction delay** — "fastest a hyperfocused human can react is 0.2 s, mental comparisons 0.4 s minimum. **Use these as the baseline to always delay the results of a decision**" | **Binding.** Already covered by `ai_realism_systems.md` R3; I note only that Rabin's floor *validates* that recommendation from the literature. |
| **Head-look / gaze** — the single highest-leverage cheap addition | **Discounted at PSX.** "Focus of attention" is hard to read on a low-poly head. Enemy gaze sweep already exists (`enemy_base.gd:1680-1686`). |
| **Movement speed as emotion** | **Fully intact and free.** Costs nothing at any fidelity. |
| **"Intelligent creatures sometimes stop, they reflect, they hesitate"** | **Directly applicable** — see §5's fire-and-movement cycle. |
| **Have a reason to exist** — "characters with nothing to do are a clear signal that the AI is fake" | Already served out of combat by `camp_role`/`work_clip` (`enemy_base.gd:143-151`). |
| **Deliberate ambiguity** | **A PSX ASSET, not a cost.** Low fidelity is a Façade raised eyebrow by default; the player fills the gap. |

**One finding deserves its own line, because it changes how much any of this is worth buying.** *What you
see is not what you get: Player perception of AI opponents* —
https://www.researchgate.net/publication/327530267 — finds assessment of a bot's human-likeness is **more
accurate from third-person than first-person**. **FPS players are the worst-positioned observers to judge
AI, which is precisely why the illusion is cheap to buy in an FPS.** RECONgame is first-person with iron
sights. This is a discount coupon on the entire illusion budget — and an argument for spending the saved
effort on the tactical layer instead.

---

## 5 · COMPARE AND CONTRAST — where RECONgame actually sits

### 5a. Is goal-scoring adequate? **Yes. Emphatically. Do not build a planner.**

`combat_goals.gd:68-173` is a scored goal arbiter with per-man temperament, doctrine gates, incumbent
hysteresis (`:160-173`), a 1 s dwell with class-A damage interrupts (`enemy_base.gd:1429-1438, 2435`) and
4 s committed flight (`:2544`).

Measured against the canon:

| | F.E.A.R. (measured) | Killzone 3 (measured) | RECONgame |
|---|---|---|---|
| Decision structure | GOAP, **plans 1–2 actions** | HTN, plans 2–5 | Scored goal arbiter, 1 verb |
| Distinct actions | **55** | 44 | 6 scored verbs + 2 branched |
| Think rate | — | **5 Hz** | **6.7 Hz** (`enemy_base.gd:37-52`) |
| Squad layer | 4 behaviours, **slot assignment** | — | **none in combat** |
| Top action | `UseSmartObjectNode` **26%** | `RememberActivePlan` **37%** | — |

**A GOAP planner whose plans are 1–2 actions long is a goal selector with extra machinery.** RECONgame
already has the goal selector, at a faster tick, with better hysteresis than F.E.A.R.'s cost heuristic
(which Jacopin measured as having *no observable effect*).

**Behaviour trees: also no.** The project already owns a BT kit (`scripts/ai/bt/`) — and it is hard-typed
to `Civilian` (`bt_node.gd:12` `func tick(civ: Civilian, ...)`), used only by `civilian.gd:855-863`.
Porting combatants to it would be a rewrite that buys nothing the scorer does not already do.

**One honesty item.** The scorer is repeatedly documented as a "nine-verb brain"
(`combat_goals.gd:6-7`, `ally_base.gd:901-903`). It scores **six**. `HOLD_POSITION` and `INVESTIGATE` are
set by hard branches upstream (`enemy_base.gd:1459-1463`) and `NONE` is not a verb. COMMENT DISCIPLINE.

**Framing worth stating plainly:** `enums.gd:40` documents the goal set as *"Quake 3 inspired"*. That is
honest and it is the right diagnosis — **RECONgame's combat brain is architecturally a 1999 bot goal
scorer.** What separates it from the 2000s canon is not the scorer's sophistication. It is that the
canon put a **coordinator above it**.

### 5b. THE STRUCTURAL GAP — there is no squad-level decision-maker in combat

`EnemySquad` is a **blackboard, not a brain.** It stores and brokers; it never decides:

| What it does | Pointer |
|---|---|
| Shared target + last-known + breadcrumbs | `enemy_squad.gd:244-260` |
| Covering-fire **census** ("did anyone fire in the last 1500 ms") | `:186-191` |
| Engagement **census** (who is shooting whom) | `:197-219` |
| Grenade broker (anti-spam) | `:224-236` |
| Strength / break state | `:119-162` |
| Hot-set compute budget | `:52-95` |

**Nowhere in that file does anything get assigned to anybody.** Compare TLOU's Combat Coordinator handing
out Flanker / Approacher / StayUpAndAimer with **rejection when the role is taken**, or F.E.A.R.'s squad
behaviours filling **slots**.

The consequence is visible in the scoring: `has_covering_fire` (`enemy_base.gd:1493`) asks *"did a
squadmate happen to shoot recently?"* — a **passive observation**. No man is ever *told* to lay down fire
so another can move. Fire and movement is an accident of timing, not a plan.

**And RECONgame already proves it can do the thing it is missing.** `EnemySquad.hunt_point`
(`:408-438`) assigns each searcher a **stable sector** of a coordinated expanding net, alternating
outward from the heading, explicitly designed to *"degrade gracefully as searchers are killed, and never
collapse men onto one flank."* That is genuine squad-level role arbitration with graceful degradation.
**It exists only in the SEARCH phase. Combat has no equivalent.**

The project's own constitution agrees: `GAME_GUIDE.md:166` and `OVERSEER_CHARTER.md:88` both list
**"EnemySquad coordinator"** as an *open keystone*. **The gap I am naming is already on the project's own
unbuilt list.** This document's contribution is the evidence for what it should be and what it should
not.

### 5c. Positional reasoning — the weakest layer in the codebase

**FLANK does not flank.** `_execute_flanking` (`enemy_base.gd:1850-1862`) in full: take the perpendicular
to the target, pick a random side once, blend 0.7 lateral + 0.5 forward, and walk. **No destination, no
candidate positions, no LOS evaluation, no reservation, no arc, no terminating condition.** It is a
strafe with a goal name on it.

TLOU abandoned exposure-map flanking *specifically because* incoherent routes read badly, and replaced it
with a **fixed-shape cost field** producing stable, readable arcs. RECONgame's version is one step below
the thing they rejected.

**Cover is a fixed 12-point offset ring.** `COVER_SEARCH_OFFSETS` (`enemy_base.gd:124-128`) — four at
3 m, four diagonal at 2.2 m, four at 6 m — sampled around the man's **own** position, accepted on a
single criterion: does a raycast to the threat hit something within 2.5 m (`:2100-2117`,
`COVER_BLOCKER_MAX_M :131`). Ranked by **distance + crowding only** (`:2116-2118`).

Nothing scores whether the spot lets him **shoot back**, whether it is **toward or away** from the enemy,
whether it is **near his squad**, whether the **ground between here and there is survivable**, or whether
it is **flanking**. Allies reuse the identical ring (`ally_base.gd:1657-1658`) with multi-criteria scoring
**only** on the RTO cord path (`_rto_cover_score :1609-1617`).

**Two concrete defects found in that system:**

1. **The cover-claim table is shared across factions.** `EnemyBase._cover_claims` is one static dict
   (`:122`) keyed on 2 m cells, and `ally_base.gd:1601` claims into it. An ally holding a rock **blocks an
   enemy from claiming that cell**, and `_crowding_cost` (`:2020-2028`) penalises a spot because an
   *enemy* stands near it. Cleared correctly at `mission_scope.gd:27`, so it is a live-fight interaction
   bug, not a leak.
2. **The AO already carries free cover data that combat never reads.** `GameplayGrid.COVER_VALUES`
   (`terrain/core/gameplay_grid.gd:39-47`) grades every cell CLEAR 0.0 → HEAVY_JUNGLE 0.8 → CLIFF 0.9.
   **One combat consumer exists in the entire codebase** (`ally_base.gd:1733`, a concealment fallback).
   The enemy cover search never touches it.

**And the project already knows how to score a position properly — at worldgen.** `AmbushPlanner`
(`ambush_planner.gd:50-85`) scores candidate sites on **cover × concealment × traffic proximity**, with
hard rejects for open ground and paddies, and an explicit standing rule that traffic must weight and
never gate. **That is exactly the multi-criteria tactical evaluation the canon uses at runtime.**
RECONgame has the technique, applies it once at world generation, and then fights with a 12-point ring.

### 5d. **SUPPRESSION IS A ONE-WAY WEAPON — the finding that moots the rest**

This is mine and it is not in any sibling analysis.

`_suppress_player_if_near` has **exactly one call site in the codebase**: `enemy_base.gd:2306`, inside
the enemy fire path. `SUPPRESS_ON_MISS` (`:2988`) and `NEAR_MISS_RADIUS` (`:2951`) are declared in
`enemy_base.gd` and nowhere else. The ally fire path (`ally_base.gd:1745-1800`) emits a `NoiseBus`
gunshot and a bullet, and **nothing else**. The player emits nothing; `player.gd:1918 add_suppression` is
**receive-only**.

**Neither the player nor any ally can suppress an enemy with small-arms fire.** Friendly suppression
reaches the enemy only through explosions (`combat_manager.gd:224, 359-380`).

The consequences cascade through systems that are otherwise correctly built:

- The ally `SUPPRESS_TARGET` goal (`combat_goals.gd:99-108`) scores a verb whose effect friendly bullets
  cannot produce.
- `c.target_suppressed` on the ally side (`ally_base.gd:927-928`) reads
  `(target as EnemyBase).suppression_level > 0.5` — **a value the squad's own fire never raises.** So the
  FEAR-doctrine gate (`combat_goals.gd:74`) and the suppress-before-moving term (`:106`) are, on the
  friendly side, permanently fed a false.
- The M60 has no distinct suppressive role. `ally_base.gd:101` documents *"the coward... suppressive
  fire"*; `fire_rate_mult` (`:237`) is a cadence bonus only.
- **`SUPPRESS_TARGET` has no distinct executor on either side.** `_update_state_for_goal` maps it to
  `AIState.COMBAT` — **the same state as ENGAGE** (`enemy_base.gd:1562-1563`). There is no longer burst,
  no wider cone, no fire at a last-known position, no sustained beat. Choosing to suppress changes
  nothing about what the man does.

**Now pair it with the reverse asymmetry.** Allies **stop firing entirely** above `suppression_level 0.5`
(`ally_base.gd:1342`). Enemies have no such gate — a pinned enemy merely shoots 25% worse
(`enemy_base.gd:1746`, and that term is inverted, as `ai_realism_systems.md` §3c already documented).

**So: incoming fire silences the player's squad, and the player's squad cannot silence anything.** That is
a mechanical description of bullet fodder. It is not a perception problem and no amount of VO will fix
it.

**Against the canon this is the whole ballgame.** Brothers in Arms made suppression *the* core mechanic
and made the **player** subject to it too; Company of Heroes made pinning legible at squad scale with one
float; Ghost Recon's entire AI vocabulary was three states and **one of them was Suppress**. RECONgame has
the suppression *model* — a genuinely good per-round perpendicular near-miss geometry
(`enemy_base.gd:2976-2988`), a three-band movement curve (`:1997-2006`), a posture ladder
(`combat_posture.gd:35-71`), a prone latch with three guaranteed exits (`:58-71`) — **and only one faction
can fire it.**

**Three specific gaps the verified canon exposes in RECONgame's otherwise-good model:**

1. **Accrual should not require near-miss geometry.** CoH accrues **per shot fired, hit or miss**, with an
   ~13 m ×0.8 splash to neighbours. RECONgame computes a perpendicular distance per round
   (`_near_miss_suppress`) — higher fidelity, and *narrower*: rounds that go nowhere near a man suppress
   nobody, so a squad taking wild fire from the treeline feels nothing. The volume-of-fire feeling that
   Pillar 1 names explicitly is exactly what the splash term buys.
2. **Cover does not modify suppression at all.** CoH's ~**50× swing** in time-to-pin across a hedgerow is
   what makes moving four metres a tactical epiphany. RECONgame already tracks `has_cover` on both
   factions and already grades every cell of the AO (`COVER_VALUES`) — and neither touches
   `apply_suppression` (`enemy_base.gd:2596-2597`, a bare add) or the decay
   (`ally_base.gd:662-663`, a flat rate).
3. **There is no pinned mercy window.** CoH gives 4 seconds pinned before received accuracy ×4 —
   Duffy: *"it gave you time to make a plan."* RECONgame's `_execute_suppressed` is a pure freeze with no
   protection, so being pinned is strictly a death sentence. **Against Pillar 5 (fail forward), a pin that
   only ever kills is the wrong shape.**

### 5e. Fire-and-movement: the cycle does not exist

`_execute_advancing` (`enemy_base.gd:1870-1920`) is a real, well-built **individual** bound: find a bound
point that genuinely gains ground (`_find_bound_point :2070-2095`), sprint it at a 1.6× accuracy penalty,
arrive, pause 0.8–1.6 s, fire 2–3 rounds, repeat, with a throttled ≤12-ray ≤1 Hz search and a
two-dry-search fallback.

**Every man runs this on his own timer.** There is no pairing, no alternation, no "I move when *you* are
shooting." `has_covering_fire` adds +0.2 to the ADVANCE score (`combat_goals.gd:127-128`) *if somebody
happened to fire within 1500 ms* — and on the ally side it is **never set at all** (`ally_base.gd:128`,
self-documented as unfinished).

A real bounding-overwatch cycle is: **A is assigned to fire, B is assigned to move, they swap.** That
requires §5b's coordinator. It is the same missing piece.

### 5f. Pinning as a win condition — absent, and currently impossible

Nothing in the codebase treats "the enemy is pinned" as an objective, a score, or a state to exploit.
Suppression is an input to individual goal scoring and nothing else. There is no squad-level notion of
"that position is suppressed, therefore we move."

Note also that the **firefight-length dial is inert in the shipping game**: `ai_vs_ai_cone_mult`
(`game_settings.gd:22`) defaults to 1.0 and its only writer is the stress arena
(`ai_stress_arena.gd:311`). So ally-vs-VC firefights — what the player watches for thirty minutes —
resolve at full mutual lethality with no lengthening, which is precisely the condition under which
*killing* dominates *pinning*.

### 5g. "Bullet fodder" — what the canon says makes men read as men, scored honestly

| Behaviour | Canon precedent | RECONgame status |
|---|---|---|
| Retreat / rout | Halo grunts; OFP | **Built, enemy only** (`enemy_base.gd:2522-2544`). No ally ever routs. |
| Surrender | SWAT 4 | **Built, enemy only, rare** (`:2882`) |
| Going prone under fire | universal | **Built, both, good** (`combat_posture.gd:58-71`) |
| Dragging wounded | — | **Built, enemy only** (`enemy_base.gd:2626-2694`, real: drags *away from believed threat*) |
| Down-not-dead | — | **Built, enemy only** (`:2606-2611`) |
| Refusing to advance | F.E.A.R.'s *"No f***ing way!"* | **Partially**: open-ground discipline damps ADVANCE ×0.15 under unanswered fire (`combat_goals.gd:131-132`) — **and says nothing when it fires** |
| Calling for help | F.E.A.R. reinforcements bark | **Absent** |
| Taking turns firing | BiA, FSW | **Absent** (§5e) |
| Announcing the dead end | F.E.A.R.'s *"I've got nowhere to go!"* | **Absent** — and `_cover_fail_count` / `_bound_fail_count` already count exactly this event |

**The pattern is stark and it is the same one `squads_alive.md` found from the person angle, arriving
independently from the tactical angle: every self-preservation behaviour in this game was built on the
enemy and never mirrored onto the squad the player is supposed to love.**

---

## 6 · RECOMMENDATIONS — ranked by impact per unit of work

**Perf constraint governing all of this.** The project is **CPU-bound with the frame in the AI** (18v18
stress arena: 14.0 → 23.1 fps after graphics cuts, `OVERSEER_CHARTER.md` Tech row). **Nothing below adds
a per-think O(n) sweep.** Two of them *remove* raycasts.

### (a) CHEAP THEATRE WITH OUTSIZED PAYOFF

**T1 — Bark the failures. *(hours; the single best ratio in this document)***
F.E.A.R.'s most transferable trick is dialogue that **excuses a dead end**. RECONgame already counts its
own tactical failures and is silent when they happen: `_cover_fail_count` (`combat_goals.gd:35`, incremented
`enemy_base.gd:1908`-adjacent) and `_bound_fail_count` (`:1908,1918`). When a man's second cover search
returns `Vector3.ZERO`, or his second bound fails, **say so** — the recorded orphan line
`enemy_no_cover` / `squad_moving` family, or the nearest equivalent.
**Reads as:** a man who knows he is pinned and says so. Sound + timing, both PSX-proof.
**Sacrifices:** nothing. This is narration of an event that already fires.
**Cost:** zero CPU — it is a branch on an existing counter.

**T2 — Announce open-ground refusal. *(hours)***
`combat_goals.gd:131-132` already implements the FEAR doctrine: under unanswered fire, without covering
fire, ADVANCE is multiplied by **0.15**. A man is *already deciding not to cross*. He says nothing.
Bark it once per decision, with a cooldown.
**Reads as:** *"No — not across there."* This is F.E.A.R.'s most-quoted moment and RECONgame has already
built the decision underneath it.
**Sacrifices:** nothing. **Cost:** zero.

**T3 — Give SUPPRESS_TARGET a distinct executor, on Vietcong's rule. *(small; theatre-tier cost, tactical payoff)***
`enemy_base.gd:1562-1563` maps SUPPRESS to `AIState.COMBAT` — the same state as ENGAGE. Give it: longer
bursts, a wider cone, a sustained cadence, and above all **fire at the BELIEVED position through
vegetation when LOS drops.** That last is Vietcong's shipped default outdoors —
`SC_Ai_SetShootOnHeardEnemyColTest` **FALSE**, *"no shooting to the tree behind which is the target
hided"* being the *interior-only* setting — and it is precisely the behaviour a jungle firefight needs.
RECONgame already tracks `last_known_target_pos` and already has the `contact_conf` debounce to gate it
honestly.
**If a target-selection rule is wanted later**, Killzone's is free and reuses A1's machinery: score
positions **from the enemy's perspective** — which spots offer *him* a line of fire at you and cover from
you — and shoot into the ones scoring above a threshold (§3a).
**Sacrifices:** ammunition consumption becomes conspicuous by its absence (`ai_realism_systems.md` R8 —
this makes that item more wanted, not less), and shooting through foliage at a believed position will
occasionally read as "he saw me through a bush." Vietcong shipped that trade knowingly; gate it on
`contact_conf` so it only fires on a genuinely recent contact.

**T4 — The fake threat. *(one function; the cheapest tension generator documented anywhere)***
Vietcong's `SC_Ai_FakeEnemy_Add` with a **NULL position**: *"they will assume enemy is everywhere and
they will move like under fire."* A patrol moving through empty jungle bounds, crouches and watches its
arcs because the designer lied to his own AI. RECONgame has every input this needs already —
`last_known_target_pos`, `apply_suppression`, the posture ladder — and an obvious trigger surface in the
`EvidenceLedger` and the `AmbushPlanner`'s unused sites. **Half the dread in a patrol comes free.**
**Sacrifices:** it can cry wolf; needs a cooldown and a decay so a squad does not spend the whole patrol
crouched.

**T5 — Break the unison, on Jurney's rule. *(small, and it is the one CoH admission most directly
transferable)***
> *"the combination of the fixed offsets, speed control, and obstacle avoidance code is **too good** at
> keeping units in their formation-mandated spots. To counteract this, we have each unit store a personal
> drift variable."*

Relic added randomness **because the AI looked robotic from being too accurate**, and separately performs
leapfrogs *"even when there is no interesting feature, just to keep the squads looking interesting."*
Verweij's measured playtest says the same thing from the failure side: **"ant like"** identical shared
paths were the single loudest intelligence-destroyer, while **spatial grouping was the single strongest
intelligence signal**.
`squads_alive.md` C1 already proposes per-man posture offsets; **this adds the external evidence and one
more item — a per-man lateral drift on the follow slot** (`ally_base.gd:1178`, `SLOT_TRACK_SPEED`) so the
squad stops tracking its ring in lockstep.
**Sacrifices:** formation tidiness, deliberately. Relic made that trade on purpose.

### (b) REAL ARCHITECTURAL ADDITIONS WORTH THE COST

**A1 — Make suppression bidirectional, and give cover a say in it. *(the highest-priority item in this document)***
Three parts, in order:
- **Lift `_near_miss_suppress` to a shared home** (`AIMarksmanship` or `CombatManager`) and call it from
  the **ally** and **player** fire paths. It is already written, correct and tuned
  (`enemy_base.gd:2976-2988`); it needs three call sites instead of one.
- **Add CoH's volume term.** Accrue a small amount **per shot fired toward a man's vicinity**, not only on
  a geometric near-miss, with a modest neighbour splash (CoH: ~13 m, ×0.8). This is what makes *volume of
  fire* — named in Pillar 1 — actually press a squad.
- **Let cover modulate accrual and recovery.** RECONgame already has `has_cover` on both bases and
  `COVER_VALUES` for every cell; CoH's ~50× swing across a hedgerow is the single mechanic that makes
  repositioning feel decisive. Today `apply_suppression` (`:2596-2597`) is a bare add and decay is flat.
**What it buys:** the squad's `SUPPRESS_TARGET` becomes real; `target_suppressed` starts telling the truth
on the friendly side; the FEAR doctrine gate works in both directions; the M60 becomes a suppression
weapon; **pinning becomes available to the player at all**; and cover acquires a second, legible purpose.
**Sacrifices, named honestly:** fights get *longer* and less lethal-feeling, which cuts against Bungie's
"Tougher = Smarter" (§2a) and Pillar 1's HLL lethality. **Tune, do not merely switch on** — re-run
`test_ai_fairness` and the stress arena. Pair it with a relaxation of the ally fire-gate
(`ally_base.gd:1342`), which silences a suppressed ally completely and is too harsh once fire goes both
ways. **And consider CoH's 4-second pinned mercy window** (received accuracy scales up only *after* it):
a pin that only ever kills is the wrong shape against Pillar 5.
**Cost:** near-zero CPU. It rides on rays already cast and on an existing per-cell array.

**A2 — A squad combat coordinator that assigns ROLES. *(the structural fix; the project's own open keystone)***
Not a planner. Not a behaviour tree. A small arbiter, on the model RECONgame already ships in
`EnemySquad.hunt_point` (`:408-438`) and TLOU ships as the Combat Coordinator: a squad holds a small set
of **role slots** — `SUPPRESSOR`, `MOVER`, `FLANKER` — men **request** them, and **a request for a taken
slot is rejected**. The role becomes a bias in `CombatGoals.Context` (a `role` field alongside
`assault_press`, which already proves the pattern at `combat_goals.gd:64,135-136`), never a hard override
— so Pillar 4 is preserved: the man still holds his own intent, he simply knows what his mates are doing.
**What it buys:** one flanker instead of five; a real fire-and-movement cycle (A suppresses, B bounds,
swap); `has_covering_fire` becomes a *promise* instead of an *observation*; and — per Orkin — **it
creates something worth barking.** T1/T2 are narration of individual decisions; this is what makes
"Cover me!" mean anything.
**Sacrifices:** genuine complexity in the one file the project most needs to keep legible; a new failure
mode (a man holding a slot he cannot act on — needs a TTL, exactly like `ENGAGE_TTL_MS :18`); and squads
will look *more* coordinated, which is a tuning change to difficulty. **Do not build it before A1** — a
coordinator that assigns SUPPRESSOR in a world where friendly suppression does nothing is a decoration.
**Cost:** dictionary writes at think rate, same shape as the existing engagement census (`:197-219`).
Perf-safe.

**A3 — Score cover positions on the free grid, and spend the saved rays on a real flank.**
Two halves, both net-negative on CPU:
- **Cheapen and improve cover.** Pre-score the 12 candidates with `GameplayGrid.COVER_VALUES`
  (`gameplay_grid.gd:39-47`) — an O(1) array read, no ray — plus terms for *does this face the threat*
  and *does it keep me near my squad*, on the model of `AmbushPlanner._cover_nearby`
  (`ambush_planner.gd:117-130`). Then raycast **only the top 2–3**, not all 12. That is a **~75% cut in
  `rays_cover`** (`enemy_base.gd:2085,2110`; instrumented at `combat_manager.gd:19`) *and* a better
  choice.
- **Make FLANK a destination.** Replace the blind strafe (`:1850-1862`) with a chosen arc position from
  the same scored candidate set, claimed through the existing broker (`_claim_cover :2031-2041`), with a
  terminating condition. Follow TLOU: a **fixed-shape offset relative to the combat vector**, stable
  frame to frame — *not* a recomputed exposure map.
**Sacrifices:** flanking becomes predictable in shape, deliberately (TLOU chose exactly this trade);
cover choice becomes less "nearest rock", so men will sometimes run further and look briefly exposed —
which is what the open-ground discipline term is for.
**Also fix while in there:** the shared-faction claim table (`enemy_base.gd:122` vs `ally_base.gd:1601`).

### (c) FAMOUS ELSEWHERE — DO NOT ADOPT

**X1 — GOAP / HTN planning.** Jacopin's instrumentation is decisive: F.E.A.R.'s plans were **1–2 actions**
and its cost heuristic had **no observable effect**; Killzone 3's most frequent action was bookkeeping at
37%. RECONgame's scorer already ticks faster than Killzone 3 and has better commitment semantics. **A
planner would buy nothing and cost the frame budget the project cannot spare.**

**X2 — Behaviour trees for combatants.** Halo's BTs solved *authoring scale* — dozens of designers,
hundreds of behaviours. RECONgame has six verbs. The existing kit is `Civilian`-typed (`bt_node.gd:12`)
and porting is a rewrite for zero behavioural gain. **Keep BTs where they are: civilians.**

**X3 — A-Life / off-screen simulation.** STALKER's own record says the offline layer contributed almost
nothing observable, and ADR-025 already killed this on a measurement (2.8% of the AO is off-AO from
spawn). **Ruled, correctly, and settled. Do not reopen.**

**X4 — Simulated emotion systems.** Bungie **explicitly discarded** a fuzzy emotion system; Rabin's sixth
lever is a direct attack on them (*"Players can only see an AI's behavior, not what is being
simulated"*). `squads_alive.md` B2 proposes a drifting nerve — that is a **behavioural** trajectory with
visible outputs and is not this. A hidden emotional model with no output channel would be.

**X5 — Player-facing tactical HUD / commanding the flank.** BiA's situational-awareness overlay and
Ghost Recon's command map are famous and **both violate Pillar 4** (*"you are IN it, not above it"*) —
and note Ghost Recon achieved its results with **three ROE states**, which RECONgame's existing F1–F4
already exceed. **The order vocabulary does not need to grow. The squad's internal coordination does.**
Two supporting warnings from the verified canon: Vietcong's own project leader kept orders to *attack,
retreat, hold* because *"soldiers of an elite Special Forces team… know independently what to do"* — and
**Vietcong 2 adopted the BiA suppress/flank order pair and lost the pointman, the navigation loop and the
jungle.** Do not import BiA's order model wholesale into a game whose Pillar 4 is the opposite.

**X6 — Cover as an invulnerability rule.** BiA made enemies in cover *bulletproof from the front* and FSW
made cover **100% effective**. Both bought enormous legibility with it. **Both are incompatible with
Pillar 1** ("death comes from *situation*… never bullet sponges") and with ADR-016's flat damage grammar.
Named here so nobody rediscovers it as a shortcut to making suppression matter: RECONgame must buy
legibility through the suppression *curve* (A1), not through invulnerability.

**X7 — Off-screen "Looking Dumb Range" accuracy cheats.** FSW's admitted LDR — inside a radius the enemy
"suddenly develop[s] 100 percent accuracy" — is a direct violation of the **Fairness Law** (*"AI accuracy
ramps with player exposure; first shot at an unaware player is a near-miss"*). RECONgame's exposure ramp
is the *opposite* policy and is the better one. **Do not adopt.**

---

## 7 · RECOMMENDED ORDER, AND THE ONE DEPENDENCY THAT MATTERS

1. **T1, T2, T4, T5** — bark the failures and refusals; the fake threat; break the unison. Hours each,
   zero risk, near-zero CPU, and every one narrates or varies something the game *already does*.
2. **A1** — suppression both ways, with cover in the loop. **Everything tactical is downstream of this.**
   Budget real tuning time against Pillar 1 lethality; re-run `test_ai_fairness` and the stress arena.
3. **T3** — a distinct suppress executor firing at the believed position (only meaningful once A1 lands).
4. **A3** — grid-scored cover and a real flank. Pays for itself in `rays_cover` on a CPU-bound frame.
5. **A2** — the squad coordinator. Last, because it is the largest, and because assigning a SUPPRESSOR
   role before A1 assigns a job that does nothing.

**The dependency: A1 BEFORE A2 AND T3, never the reverse.** A coordinator that tells a man to suppress,
in a game where friendly suppression has no effect, produces a soldier standing in the open shooting at
nothing while his mates advance into fire. That would read as the AI getting *worse*.

**And one ruling the Arbiter should consider making explicit, because two studios reached it
independently and one of them is RECONgame's own named influence.** Van Lent (FSW): friendlies *"have to
be held to a higher standard, because you're able to observe their behavior much more closely."*
Pterodon (Vietcong), in a tooltip: *"Computing is very expensive, **use about 0.2 for the enemies, 1 only
for the PC team**."* **The Summoner has already ruled the same way** (allies weighted heavier because the
squad is on screen for thirty minutes). **That deserves to be an ADR line rather than a session ruling,
so nobody "fixes" the asymmetry later on grounds of symmetry.**

**A second ruling worth putting on the record — the Gearbox sequencing.** Road to Hill 30 shipped a
deliberately passive enemy so players could learn fire-and-manoeuvre; Earned in Blood turned repositioning
on only afterwards. Van Lent expected FSW to *reduce* AI weapon effectiveness so fights lasted long enough
to be legible. **Both teams concluded legibility beats capability, and both were right.** If A1 and A2
land and the demo suddenly reads as *harder* rather than *smarter*, the canon's answer is to soften the
enemy first and keep the new grammar — not to roll back the systems.

---

## 8 · EIGHT CLAIMS TO KEEP OUT OF THE DECREE

1. **"F.E.A.R. playtests showed the AI rated far dumber with barks removed."** **No primary source
   exists.** Use Orkin's verbatim reinforcements anecdote (§1a), or Bungie's playtest table (§2a), or
   Al Enezi & Verbrugge 2023 if a controlled experiment is genuinely needed.
2. **"Bob Bates / Steve Rabin, *The Illusion of Intelligence*."** Rabin sole-authored it (Game AI Pro 3);
   Bates is unconnected. And the *title* is shared with Butcher & Griesemer's 2002 Halo talk — two
   different documents, both worth citing, easily conflated.
3. **"Halo 2 used a blackboard."** It did not — the word does not appear in Isla's paper. The knowledge
   structure is the per-object **prop**. Say "prop" or say "per-object belief record."
4. **"Halo 3 objectives, GDC 2009."** It was **GDC 2008**.
5. **"Killzone's AI is by Straatman, Verweij and Champandard (2004)."** The 2005 GDC Europe talk is
   **Beij & Straatman**; Verweij and Champandard belong to the Killzone 2/3 line. Verweij's thesis is
   **2007**, not the "[Verweij 06]" its own citation in Game AI Pro claims. And **large parts of the
   Killzone perception / order-priority / replanning sections in that thesis were written by J. van der
   Beek** — his companion MSc thesis could not be located and is flagged unretrieved.
6. **"Vietcong's scout is called Bird."** There is no Bird. The pointman is **Le Duy Nhut**, a Vietnamese
   ex-Viet Minh defector — not a Montagnard.
7. **"Operation Flashpoint modelled suppression."** It did not. Grepping the released engine returns only
   audio ducking. Suppression arrived in **ARMA 3 v1.42, April 2015**, and BI stated plainly that it
   *"does not change the explicit AI behavior and decision making when under fire."*
8. **"SWAT 4 used behaviour trees" / "the wound-then-shout exploit was patched."** Neither. It is a
   goal/action architecture with resource arbitration, and v1.1's changelog contains **zero** AI changes —
   the shot morale modifier is **0.0**; what actually happens is that being shot makes a suspect drop his
   weapon, which applies a *different* modifier and re-evaluates his behaviour.

**Still unverified and deliberately not quoted:** J. van der Beek's thesis; the AI Game Programming
Wisdom 3 Killzone chapter (print only); GDC Vault video recordings. **Halo 2/3 and Killzone 1/2/3 are now
verified from primary sources** (proceedings article, slide decks, thesis PDF, Game AI Pro chapter), as is
the full suppression canon.

---

## 9 · THE VERDICT IN ONE PARAGRAPH

RECONgame's combat brain is a competent 1999-vintage goal scorer running faster than Killzone 3 with
better commitment semantics than F.E.A.R.'s planner, and it does not need replacing — the canon is
*smaller* than its reputation almost everywhere you look: F.E.A.R.'s plans were 1–2 actions, Halo's
arbiter was a first-match-wins priority list, Killzone's celebrated tactics were four integer weights over
a deliberately inaccurate 64KB cover table, SWAT 4's famous suspects were fifteen behaviours and one
float, and OFP had no suppression at all for fourteen years. What the canon had that RECONgame does not is
**a layer above the individual that hands out jobs** — F.E.A.R.'s squad slots, TLOU's Combat Coordinator —
and RECONgame already proves it can build one, because `EnemySquad.hunt_point` is exactly that, in the
search phase only. Underneath that sits the finding that matters most: **suppression is emitted by one
faction, so the player's squad can be pinned and can pin nobody, while ceasing fire entirely above 0.5.**
The men read as bullet fodder because, mechanically, they are — they cannot perform the one verb the
entire suppression-era canon is built on, and cover, which the AO already grades cell by cell, has no say
in it. Fix the direction of suppression and let cover modulate it; give the squad someone to assign jobs;
spend the difference on the men the camera never leaves, exactly as Pandemic and Pterodon both ruled. Then
— per Orkin, and per Naughty Dog after him — the barks will finally have something true to announce.
