# DEVIL'S ADVOCATE — 2026-09-07 · SQUAD COHESION AS A COMBAT MECHANIC

**Charge:** argue that squad cohesion is a TRAP. Phase 2, independent sight. No cross-talk.
**Method:** read the code, not the plan (CLAUDE.md war-room law #2). Every claim below carries a pointer.

---

## 0 · THE ONE SENTENCE

**Squad cohesion is already a first-class combat mechanic in RECONgame. It shipped. It has a resource,
a decay, a recovery, a break threshold, a diegetic player verb, and behavioural consequences — and the
Summoner has never seen it, because the entry gate is undischarged and nobody has playtested it.
Designing it again is not design. It is the FOSSIL LAW in reverse: building a second system that means
the same thing as the first, which ADR-023 exists to forbid.**

---

## 1 · THE STRONGEST ARGUMENT — IT IS BUILT, AND HE HAS NEVER PLAYED IT

This is not a scoping objection. It is a factual one. Point by point against his §6 proposed shape
("cohesion as a resource the ambush SHATTERS and drills RESTORE, gating which orders function"):

| His proposed part | Already in code | Pointer |
|---|---|---|
| A cohesion **resource** | `_nerve_drift`, per man, moves during a contact | `scripts/allies/ally_base.gd:122` |
| The ambush **SHATTERS** it | `on_squadmate_down()` — `NERVE_LOSS_PER_CASUALTY` 0.12, floor −0.30, +0.2 pressure | `ally_base.gd:154-156`, `:124-128` |
| It **RESTORES** | `NERVE_RECOVER_PER_S` 0.02, **only in a real lull — nothing shooting at him** | `ally_base.gd:817-819` |
| A **squad-level** state, not just per-man | `break_state(live, peak, avg_courage)` → threshold slides on courage | `scripts/enemies/enemy_squad.gd:118-122` |
| The squad **shatters** as a unit | `_update_break()` — below ~45% of PEAK strength the squad breaks | `scripts/squad/squad_system.gd:554-580`, `enemy_squad.gd:107` |
| It **gates what the squad will do** | `squad_broken` gates closing distance, the hold band, cover anchoring, fire | `ally_base.gd:220, 227, 906, 1538, 1687` |
| A **player verb** that restores it | `RALLY_BONUS` +0.10 within `RALLY_RADIUS` 6 m — **and only when the player is BETWEEN the man and the threat** | `ally_base.gd:130-135, 160-173` |
| An **affordance** (r4bk) | toast `"SQUAD COMBAT INEFFECTIVE - BREAKING CONTACT"` / `"SQUAD BACK IN THE FIGHT"` + `VOManager.play_squad("fall_back", …)` | `squad_system.gd:573-580` |

And above all of that sits **`scripts/ai/squad_coordinator.gd`** — a whole per-side, per-squad fight
coordinator built by the 2026-08-24 War Room: **ONE suppressor slot** (the base of fire, preferring a
covered MG), **N exposure tokens** gating how many men may be out of cover at once, a per-squad
**covering-fire census**, **two-element bounding overwatch**, and per-faction **doctrine data**
(`data/ai/`). Allies run on it (`ally_base.gd:1067-1197`). Its own header states the design law that
answers half of tonight's question before it was asked:

> *"Orders are REFUSABLE by construction: the coordinator only shapes goal picks; survival verbs
> (SEEK_COVER / RETREAT) are never routed through it."* — `squad_coordinator.gd:11-13`

**That is squad cohesion as a combat mechanic. Bounding overwatch, base of fire, fire distribution,
nerve, break and rally.** It is the most sophisticated system in the project.

**So the honest diagnosis is not "there is a GAP" (his point 3). It is: THE BEST SYSTEM IN THIS GAME
HAS NEVER BEEN LOOKED AT BY THE MAN WHO OWNS IT.** The rally verb is the exact mechanic he is
reaching for — *lead from the front and your men steady* — and it is invisible, unmeasured, tuned by
nobody, and worth **+0.10 of courage**, a number no human being has ever felt. Its only presentation
is one toast string. **`grep squad_broken scripts/ui/` returns nothing.**

**Building a new cohesion layer on top of this is how you get two systems that mean the same thing —
and ADR-023's whole thesis is that the second one is not a bug, it is a lie in the map.** The next
agent will not be able to tell which one is load-bearing. That has already happened here five times in
one session (CLAUDE.md, THE FOSSIL LAW).

---

## 2 · "YOUR ORDERS STOP WORKING" IS THE WORST MECHANIC ANYONE HAS PROPOSED FOR THIS GAME

His §6 ends with cohesion **"gating which orders function."** Refuse this outright.

A player presses **F2 / H** and nothing happens. He cannot distinguish:
- a designed refusal,
- a bug,
- a keybind that did not take,
- a dead squad member,
- an order that fired and the AI ignored.

**This is bead r4bk.** The r4bk law was learned because squad orders reported "gone" when they had no
affordance. **The proposal re-creates the exact defect the law was born from, on purpose, and calls it
a feature.** A silent no-op is the single most expensive failure mode this project has already paid
for, and paying for it deliberately is not depth — it is the same bug wearing a design costume.

The ADR-018 §2 exemption does **not** cover it, and the difference is precise. Silent squad XP has an
affordance: **the man himself.** Green walks you into the wire; veteran holds up a fist. **The player
always sees SOMETHING happen.** A refused order is the absence of an event. *You cannot make absence
legible.* Nothing is a bad affordance for nothing.

**And there is a shipped answer already, in the same codebase, that gets the same feeling right:
REFUSABLE, not GATED.** `squad_coordinator.gd:11-13` shapes goal picks; the man still moves, still
answers, still does something you can watch. A shaken man who takes your order and executes it
*badly, late, from the wrong side of the log* teaches you everything a locked-out key does, and
teaches it **visibly**. That is Pillar 4's own text in CLAUDE.md: *"you suggest and call; the squad
holds its own AI intent."* **A suggestion cannot be locked. It can only be ignored — audibly.**

---

## 3 · PILLAR 3 — A MANAGEMENT LAYER IS A RAIL WEARING A RESOURCE COSTUME

ADR-020's governing law: **"A RAIL TAKES THE CONTROLS AWAY. A GUARANTEE DOES NOT."** Its binding
test: *can he leave, right now, unpunished?*

"Restore cohesion before you may flank" fails that test in the only way that matters. It does not
take the stick — it takes **the verb**. The player wanted to flank; the game says *first do this other
thing.* That is an ordering constraint imposed on an open AO, which is the definition of the thing
Pillar 3 forbids: *"any route, any order."* **Freedom is not only about where your feet may go.**

And the second-order cost is worse. A cohesion meter turns the fight into a **thing to be managed
rather than survived**. That is the Brothers in Arms disease he did *not* import: BiA's fights are
puzzles with a correct solution, and the correct solution is the order sequence. Vietnam, in his own
words, is *squad vs squad* — and a squad-vs-squad fight where you are stopping to top up a bar is a
strategy game shot from eye level.

---

## 4 · PILLAR 5 — THE UNRECOVERABLE STATE IS A RELOAD, AND THE RECOVERABLE ONE IS DECORATION

The fork is total and there is no third branch:

- **Shattered cohesion the player cannot recover from** → the fight is unwinnable → he reloads. Pillar
  5 exists to forbid exactly that (*"never reload-and-memorize"*). And it lands hardest here because
  **save-anywhere is PARKED** (ADR-007 Amendment A, ADR-039 §7): a reload today is a HARD save at the
  firebase, i.e. the whole day. A death spiral in a 30-minute demo is a quit, not a retry.
- **Cohesion he trivially restores** → a chore bar he tops up between contacts → decoration, and a
  new key to press for it.

The shipped system already threads this needle without a meter, and its threading is the interesting
part: **nerve recovers ONLY in a lull, and the player accelerates it by moving TOWARD the threat**
(`ally_base.gd:165` requires `_player_is_forward`). Recovery is not a button. It is **standing in
front of your men while you are being shot at.** That is the best possible version of his idea and it
is already written.

---

## 5 · THE SCOPE WALL — SAY IT OUT LOUD

- The Early Access target date was **2026-09-06. It passed YESTERDAY.**
- The §8.0 entry gate — **THE DEMO PLAYTHROUGH — is UNDISCHARGED.** He has not played the arc end to
  end. Not once.
- The 9/06 council closed **ZERO** playtest items and wrote its own warning into §0: a decree *"can
  become a date's alibi."*
- **Twenty-four hours later, the very next session opens a council on a new combat system.**

That warning was not a rhetorical flourish. It was a prediction, and this session is it coming true.

**And the disease has a name, given by the man in the chair:** *"expanding the content too much and
not making a good game"* (GAME_GUIDE §6.0). The scope law's question is never "can we have this," it
is **"what is the smallest version that ALREADY FEELS LIKE THIS?"** The answer here is unusually
cheap and unusually humiliating: **the smallest version is the one already compiled.**

**Gate ruling, stated honestly as the briefing requires:** any *new* cohesion system is a **feature
epic** and lands on the **WRONG side of the gate** — blocked, full stop. The only cohesion work that
is gate-EXEMPT is **presentation for an already-shipped system** (§9's named exemption) and
**evidence-gathering probes**. That exemption is not a loophole; it is the entire honest answer to
tonight's question.

---

## 6 · THE DISPLACEMENT — NAME WHAT DOES NOT GET BUILT

Budget: **13-19 art-days of ~26** (§8.1). Here is what a cohesion epic eats, by ship-order item:

- **§8.1 #1 — the perf baseline.** The suite (101/18/14, unverified since 07-27) and THE WALK / ONE
  DIG / THE BARRAGE **have never run.** *"Nothing below is trustworthy until this is done."* A new AI
  system added before the FPS number is taken is a system whose cost is unmeasurable — and
  `squad_coordinator` is per-think, per-man work on a call-bound project.
- **§8.1 #3 — enemy dressing.** `EnemyBase` **has no dresser call at all**: all 45 men in the climax
  are the same clone, and the art is already on disk. That is the first thing his eyes hit.
- **§8.1 #4 — the M101 crew.** ~497 authored animation channels, **zero readers**, off behind one
  guard at `site_planner.gd:822-823`. Costs zero art-days and **gives days back**.
- **§8.1 #5 — the final firebase export** + the 80-segment destructible contract. Everything stands
  on this one asset.
- **§8.1 #7 — the mounted MG does not fire.** In the demo whose climax is a firebase assault.
- **The 14 minutes of dead air** the 9/06 council measured (~850-1000 m of quests against 1184 s to
  dusk) — the one design question that was put to him and **is still unanswered.**

**Every one of those is a thing he will see in the first 30 minutes. Cohesion is a thing he would
feel in the second hour of a game whose first hour has never been played.**

---

## 7 · TURN HIS OWN LENS ON HIM — THE BiA ACCURACY FINDING

He handed the council the sharpest tool in the room and then did not point it at himself.

*"I shoot people and they don't die"* was **not a damage problem. It was an accuracy problem.** The
felt truth was real; **the named mechanism was the wrong system.**

Now: *"the cohesion of the unit is what wins the fight."* The felt truth is real — Vietnam firefights
were won by the side that got rounds downrange fastest and stayed a unit. **But "cohesion" is the
name for an OUTCOME, not for a system.** What produces that outcome is a stack of things this project
has already built:

| The feeling he names | The system that actually produces it | Pointer |
|---|---|---|
| "they reacted instantly, we didn't" | AI accuracy ramps on **exposure time**, not on alert | `enemy_base.gd:1443-1444, 2411`; the Fairness Law |
| "we got pinned and couldn't move" | suppression → posture, spread, `SUPPRESS_FIRE_CEILING` | `ally_base.gd:1616, 2303` |
| "nobody was covering anybody" | covering-fire census + the one suppressor slot | `squad_coordinator.gd:93-103, 196-199` |
| "we bunched up and got mowed down" | `COMBAT_SPACING_M` 3.0 — the follow ring governs patrol only | `ally_base.gd:2238-2257` |
| "they moved as one and we didn't" | exposure tokens + two-element bounding overwatch | `squad_coordinator.gd:116-180` |
| "the squad fell apart" | nerve drift, break state, rally | above, §1 |
| "I could hear it going wrong" | VO/barks, `play_squad("fall_back")` | `squad_system.gd:577-580` |

**The category error is exact.** He is proposing to build the *feeling*, when the machinery of the
feeling is built and only the **presentation and the tuning** are missing. In BiA the fix was a
number, not a system. Here the fix is **a HUD line, an audio pass, and a playtest** — not a system.

---

## 8 · HE IS A LINE GRUNT. A COHESION LAYER PROMOTES HIM.

GAME_GUIDE §1: **"You are a line grunt, not an operator."** CLAUDE.md's merged Pillar 4: *"the squad
is the RPG — **and you are IN it, not above it** … a design that has you positioning individual men
violates this."*

ADR-021 §4 is more damning still: **for the first patrols the player FOLLOWS.** An NPC sergeant sets
the waypoints. And the ADR names the follow phase as *"the closest this design comes to a rail,"*
adding: **"It may never be enforced. The Arbiter guards this."**

**A cohesion-management layer hands the cherry a squad-state dashboard on his first day in country.**
It is not merely off-fantasy; it is the *inverse* of the arc ADR-021 buys — a man who arrives already
above the squad has nothing left to be promoted into. It also lands hardest in the demo, which is a
single day: **there is no rank arc in 30 minutes, so the player would get the lieutenant's layer with
none of the earning.**

---

## 9 · THE PRESSURE ON THE INPUT MAP (ADR-012)

Four prime keys are already spent — **F1-F4 dual-bound to C/H/X/N**, and *"neither binding may be
removed."* A cohesion verb needs a fifth prime key **plus** a fifth secondary. Add to that ADR-022's
map/pencil verbs and ADR-040's proposed medic call from the down state, and the input budget for a
hardcore FPS is being spent on management rather than on fighting. **Any cohesion proposal that
introduces a key must say which of the four it is worth more than.** None of them is.

---

## 10 · THE HONEST CASE AGAINST MY OWN POSITION

A Devil's Advocate who cannot argue the other side is worthless, so here is the strongest version —
and one part of it I think actually wins.

1. **His diagnosis of the GAP is right even though his mechanism is wrong.** ADR-018 §2 pays squad
   competence into ATTACHMENT (a veteran is better, losing him hurts). Nothing in canon says the
   squad's *coordination* is a thing the player reads, reacts to, and influences moment to moment.
   The machinery exists; **the design intent for it was never written down.** No ADR governs
   `squad_coordinator.gd`. That is a genuine canon hole and it is his find.
2. **THE R4BK ARGUMENT CUTS AGAINST ME, AND HARDER.** By the project's own binding law, **a feature
   without a visible HUD affordance does not exist.** `squad_broken` has one toast and zero HUD.
   Rally is +0.10 with no feedback of any kind. **Under RECONgame's own law I am defending a system
   that, formally, does not exist.** My "it is already built" is therefore only 80% true: the
   simulation is built, the *game* is not. That is the concession, and it is a large one.
3. **A silent system nobody tuned is not obviously better than a new one.** `RALLY_BONUS` 0.10 on a
   0-1 courage scale, inside a 6 m radius, requiring the player forward of the man — a value nobody
   has ever felt, gating a branch (`may_close_distance` < 0.35) that a prior comment says was
   *unreachable* for a while. It may simply not work. A probe, not an argument, decides that.
4. **Vietnam-vs-WW2 is a real design difference and his point 4 is genuinely sharp.** SOP-driven
   react-to-contact vs order-driven Find/Fix/Flank/Finish is the correct read, and *"what the player
   commands is the RECOVERY, not the reaction"* is the single best sentence in the briefing.
5. **The break state's threshold is peak-relative** (`live/peak < ~0.45`), which in a 5-8 man squad
   means **3-4 men down before anything happens.** In a 30-minute demo that likely never fires. So
   the shipped cohesion system may be, in practice, *dead code that reads as live* — the FOSSIL LAW
   pointed at my own argument.

**Where that lands me:** the honest position is not "cohesion is a bad idea." It is **"cohesion is
already the game's best system and it is INVISIBLE, and the correct work is to SHOW it and MEASURE
it, which is gate-exempt and costs zero art-days."** The trap is not the subject. **The trap is
building it twice.**

---

## 11 · THE FIVE MANDATORY ANSWERS

### Q1 · Is cohesion a real mechanic, or a re-skin of suppression/morale we already have?

**It is REAL, it is ALREADY BUILT, and it is neither suppression nor morale — it is the third thing
that sits on top of both.** Suppression is per-man and instant (decays in ~3.3 s, `ally_base.gd:351`).
Nerve/courage is per-man and slow. **Cohesion is the SQUAD-level layer:** `break_state`
(`enemy_squad.gd:118`), the exposure tokens, the suppressor slot, the covering-fire census, bounding
elements (`squad_coordinator.gd`). A NEW cohesion system would be a re-skin. **The shipped one is the
real thing, and it has no ADR, no HUD, and no playtest.**

### Q2 · If real: what is the player-visible verb? (r4bk binds.)

**The verb already exists and it is not a key: LEAD FROM THE FRONT.** `effective_courage()` grants
`RALLY_BONUS` only when the player is inside 6 m **and between the man and the threat**
(`ally_base.gd:160-173`). It is diegetic, it costs no keybind (ADR-012 is untouched), it is a *risk*
rather than a menu, and it is Pillar 4 by geometry — you are IN the squad, not above it.

**What r4bk actually requires, and the whole of the work I would sanction:**
- the shaken man must be **readable on the man**: crouched, firing wild, head down, not moving up —
  ADR-018 §2's own doctrine, *"its affordance is the man himself"*;
- **voice**: the squad calling for you, and the callout changing when you arrive;
- **one HUD state**, not a bar: the existing `SQUAD BREAKING CONTACT` toast promoted into a persistent
  squad-state line while it holds.

No meter. No number. A number is optimised (the 9/06 §2.4 finding), and worse, a bar invites the
management layer this analysis exists to refuse.

### Q3 · What does it cost? Name the sacrifice.

**If we build a NEW system:** the perf baseline that has never been taken; enemy dressing (45 clones
in the climax); the M101 crew that gives days back; the firebase export everything stands on; the MG
that does not fire. **And the gate stays undischarged for another week** — which is the real price,
because the gate is the only thing standing between this project and a second missed date.

**If we do the PRESENTATION-ONLY version:** it is not free either. It costs **~1 day of UI/audio out
of §8.1 #7's single scoped legibility day** — a day already spoken for. It burns HUD real estate on a
project whose HUD is a declared minimum (ADR-030). And it risks the worst outcome of all: **making
the system visible reveals it does not fire in a 30-minute demo** (peak-relative threshold, 3-4 men
down). **That risk is a REASON TO PROBE IT, not a reason to skip it** — a probe costs an hour and can
run today, gate-exempt, and either result is worth more than any design argument in this room.

### Q4 · Where does it collide with an existing ADR?

| ADR / law | Collision |
|---|---|
| **r4bk law** | "Orders stop working" = a silent no-op = **the literal bug r4bk was named for.** Fatal to the gating proposal. |
| **ADR-012** | Four prime keys spent, dual-bound, neither removable. A cohesion verb needs a fifth pair. |
| **ADR-018** | Its §2 exemption is for silent **squad** competence whose affordance is the man. It does **not** license a silent *player-facing* gate. And a gate on which orders function edges toward ABILITY, not AUTHORITY. |
| **ADR-020** | Rail/guarantee law. "Restore cohesion before you may flank" removes a verb → a soft rail. Fails the binding test. |
| **ADR-021 §4** | Player FOLLOWS for the first patrols; the follow phase *"may never be enforced."* A cohesion layer promotes the cherry to commander. |
| **ADR-023 (FOSSIL LAW)** | **The direct hit.** A second cohesion system beside `squad_coordinator.gd` + `_update_break()` = two systems meaning the same thing = a lie in the map. |
| **ADR-015 / §8.0 GATE** | A new system is a feature epic. **Blocked.** Presentation for a shipped system and probes are exempt. |
| **ADR-016 / ADR-040** | Any cohesion effect that scales damage or player durability opens the parallel damage path ADR-040 was written to refuse. Accuracy/spread/posture only. |
| **ADR-030** | HUD buffer doctrine — a cohesion meter must justify its pixels against a declared-minimal HUD. |

### Q5 · His six points — CONFIRM / REFUTE, by number

1. **Pillar 1 mandates the BiA/HLL feel; the BiA inheritance is canon.** **PARTLY REFUTED.** Pillar 1
   is *HLL lethality* + *"death from SITUATION, never bullet sponges."* BiA is named in GAME_GUIDE §1
   **nowhere**; the tonal north stars are **Platoon · Hamburger Hill · Apocalypse Now**, and the
   gameplay references are Arma/OFP/SOCOM/Vietcong/Men of Valor. **BiA's ORDER-DRIVEN TACTICAL LAYER
   IS NOT CANON — it has never been canon.** He is importing it while believing he is citing it. That
   is the most consequential refutation in this document, because his whole §6 shape descends from
   BiA's order economy.
2. **Pillar 2 solves the WW2-spectacle problem by putting the grand war at the AMBIENT layer.**
   **CONFIRMED, and stronger than he stated.** Pillar 2 + **ADR-020's Ambience Law** ("safe to
   ignore") + his own diagnosis of the rival game (*"felt like Battlefield… you're not really the
   main character"*) already rule exactly this. Nothing to build; the law exists.
3. **THE GAP: Pillar 4 is ATTACHMENT, cohesion is WINNING FIGHTS, and no ADR covers it.**
   **HALF CONFIRMED, HALF REFUTED — and this is the important one.** The *canon* half is CONFIRMED:
   no ADR governs squad fight-coordination; `squad_coordinator.gd` is the largest un-ADR'd system in
   the project. The *code* half is **REFUTED**: it is built, shipped, and running on both sides. **The
   gap is not a design gap. It is a DOCUMENTATION gap and an r4bk gap.**
4. **BiA cohesion is ORDER-driven; Vietnam is SOP-driven; the player commands the RECOVERY, not the
   reaction.** **CONFIRMED — the best point in the briefing, and already the code's own doctrine.**
   `squad_coordinator.gd:11-13`: *"survival verbs (SEEK_COVER / RETREAT) are never routed through
   [the coordinator]"* — the squad's reaction is its own; orders only shape goal picks. **His design
   instinct and the shipped architecture agree, independently.** That convergence is the strongest
   signal this process produces (CLAUDE.md war-room law #1) — and it argues for *presenting* the
   system, not replacing it.
5. **In Vietnam you BEGIN already fixed; the enemy chose ground, time, and whether the fight happens.**
   **CONFIRMED and already law.** GAME_GUIDE §4.1's three-situation asymmetry (*"the ambushed side is
   penalized until in cover"*) is the lethality engine, and ADR-005's alert ladder + the Fairness
   Law's near-miss are the pre-fight economy. **This needs no new mechanic — it needs the near-miss
   hole ADR-040 named CLOSED** (it fires on the SHOOTER ENTERING COMBAT, not on the player being
   unaware, so a man already fighting your squad who swings onto you spends no warning shot). **That
   single bug fix is gate-exempt, cheap, and buys more of point 5's feeling than any new system.**
6. **Cohesion as a resource the ambush SHATTERS and drills RESTORE, gating which orders function.**
   **REFUTED — in three separate places, and the third is fatal.**
   - *"Resource the ambush shatters, lulls restore"* — **already built** (`_nerve_drift`,
     `on_squadmate_down`, lull-only recovery). Re-building it violates ADR-023.
   - *"Drills restore"* — **REFUTED by scope and by fantasy.** A drill is a training verb; a line
     grunt in contact does not run drills, and there is no place in a 30-minute one-day demo to teach
     one. The shipped restore verb — *lead from the front* — is better, is diegetic, and is free.
   - *"Gating which orders function"* — **REFUTED by the r4bk law, flatly.** A key that does nothing
     is the exact defect r4bk was named for. **Orders may be REFUSED VISIBLY AND AUDIBLY. They may
     never be silently disabled.**
   - The one clause worth keeping: **the near-miss as the recovery window is a genuinely good idea**
     — it makes the Fairness Law load-bearing instead of merely merciful. It is also **free**, because
     it is a reading of an existing mechanic rather than a new one, and it rides along with ADR-040's
     already-named near-miss fix.

---

## 12 · WHAT I WOULD ACTUALLY SANCTION TODAY (all gate-exempt, zero art-days)

1. **A probe, before any argument:** does `squad_broken` EVER fire in a full demo run? Does the rally
   bonus ever apply? Log every `_update_break` transition, every `RALLY_BONUS` grant, and per-man
   `_nerve_drift` minima across the arc. **One hour. It settles this entire council with a number.**
   Verification law: nothing is claimed that no probe proved.
2. **Write the missing ADR** — *Squad Cohesion: the coordinator is the mechanic; orders are refusable,
   never disabled.* Documentation of a shipped system, not a feature epic. It closes his real find
   (point 3) and it stops the next agent building it a second time.
3. **THEN the presentation pass**, folded into §8.1 #7's one legibility day — man-readable shaken
   state, voice, one squad-state line. No meter, no number, no new key.
4. **AND ONLY AFTER THE GATE IS DISCHARGED.** He has still not played the arc.

---

## 13 · THE CLOSING LINE

> **The question was "is squad cohesion a first-class combat mechanic in RECONgame?"**
> **The answer is yes — it has been for weeks, and nobody has ever seen it.**
> **The trap is not cohesion. The trap is a council that designs a system the codebase already
> shipped, on the day after a missed ship date, while the gate that would have revealed it stays
> undischarged.**

---

## PHASE 3 — RESPONSE TO THE REFRAME

**His words:** *"for the demo im not worried about the rotation effect of the squad AI. i just want
realistic feeling and looking combat coming from both the allied npcs and the enemy npcs. right now
its like 60 percent there, but not as smooth looking as a call of duty 1 or brothers in arms"*

I won the Phase 2 argument and it does not matter, because the target moved to something softer and
harder to kill. **A system with a state can be probed. An adjective cannot.** Here is the case.

---

### P3.1 · THE DISPLACEMENT — WHAT HE LOSES, RANKED

Budget: **13-19 art-days of ~26** (§8.1). The animator is the Summoner. Every art-day of a
60→85% animation pass comes out of the same pair of hands that owes **the store page, capsule art and
the trailer** — which §8.1 item 8 records verbatim as *"his days, and they were never budgeted."*
**The trailer is not budgeted and the animation pass would be spent from the same account.** Do the
arithmetic out loud: at his measured velocity (~1 large animation sequence per working day), a
"smoothness" pass across walk/run/strafe/crouch/aim/hit/death for **two factions** is not two days.
It is a fortnight, minimum, and it has no stopping rule (§P3.2). A fortnight is most of the float
between 13 and 26.

**Ranked by what he loses, worst first:**

1. **§8.1 #1 — THE PERF BASELINE AND THE THREE PROBES THAT HAVE STILL NEVER RUN.** THE WALK · ONE DIG
   · THE BARRAGE. The ship order's own words: *"Nothing below is trustworthy until this is done, and a
   red suite IS the day."* The suite last read **101 pass / 18 fail / 14 error on 2026-07-27, and has
   not been run since.** **He is proposing to polish the look of a 45-man climax whose frame time
   nobody has measured.** If the climax runs at 22 FPS, *every animation improvement is invisible* —
   smoothness is a function of frame pacing before it is a function of clips. **This is not merely
   displaced work; it is the work that tells you whether the animation pass can even be seen.**
2. **§8.1 #4 — THE M101 CREW.** ~497 authored animation channels, **zero readers**, dark behind one
   guard at `site_planner.gd:822-823`. **This is animation. It is already authored. It costs ZERO
   art-days and the ship order says it GIVES DAYS BACK.** Choosing to author new motion while ~497
   finished channels sit unwired is the single least defensible trade available today.
3. **§8.1 #3 — THE 45 CLONES.** `EnemyBase` has no dresser call, so every man in the climax is the
   same man. **And `scripts/visuals/vc_nva_dresser.gd` EXISTS ON DISK** — it is written; nothing on
   the enemy path calls it (the only live reference outside `scripts/visuals/` is `civilian.gd:816`).
   A 45-man assault of identical clones will read as cheaper than any animation defect he has named,
   and the fix is a call site plus art already on disk.
4. **§8.1 #5 — THE FIREBASE EXPORT.** The 80 exact-name destructible segments and **SiegeDirector's
   sight** both hang off it. A re-export without the regenerated JSON breaks all 80 and blinds the
   siege — in the demo whose climax *is* the siege.
5. **§8.1 #7 — THE MOUNTED MG DOES NOT FIRE.** In a firebase-defence finale. That is not a smoothness
   defect; that is a hole.

**Stated as one sentence:** he would trade the measurement that tells him whether anything he builds
is visible, ~497 already-authored animation channels, and a fix for 45 identical enemies — in order
to author more animation.

---

### P3.2 · "SMOOTHER" IS UNBOUNDED, AND ADR-015 CANNOT CLOSE IT

**Every item that has closed in this project closed on a number or a probe.** Atomic saves closed on
`save_manager.gd:100-131`. The witness rule closed on `probe_witness.tscn`, **11/11**. Character scale
closed on **k ∈ [0.8, 1.0]**, enforced. Damage closed on `tests/test_flat_damage.tscn`. The FOSSIL
LAW closed on a **ratcheting count**.

**"Smoother than 60%" has no probe, no number, no 100%, and no way to tell an agent it is finished.**
Under the verification law it is *structurally unclosable* — and an unclosable item does not fail
loudly. **It eats sessions quietly and reports progress every time.** This is the exact shape of
PLAYTEST R4: never discharged, in thirty documents.

**And "60 percent" is an impression, not a measurement — which matters, in one specific way.** An
impression is a perfectly valid *bug report* from the man who owns the game; his eye is the highest
authority this project has. It is **not** a valid *acceptance criterion*, because the same eye on a
different day returns a different number, and no agent can act on the difference. **The verdict is
real. The metric is not.**

**THE PROPOSED ACCEPTANCE TEST — and it is cheap, gate-exempt, and already half-built:**

I looked. **There is no `AnimationTree` anywhere in this project** (one comment in
`helicopter.gd:45` says a rig *would need* one). Every character plays through a bare
`AnimationPlayer` with a **fixed 0.18 s crossfade** (`model_actor.gd:1034`) and a genuinely clever
phase-preserving seek (`:1027-1039`). There is **no blend space** (speed-blended locomotion), **no
additive aim layer** (aim while moving), **no upper/lower split**. *That* is what separates this from
CoD1/BiA, and none of it is a clip.

Worse — and this is the finding that turns the adjective into a list — the resolver is **already
instrumented for its own gaps**:
- `model_actor.gd:992-998 _report_missing_family()` pushes a warning the first time a weapon-family
  clip is missing;
- `SpriteStateMap.MODEL_ALIASES` (`sprite_state_map.gd:298+`) is a table of **live degradations**,
  and one line is the whole thesis: **`"walk_forward": ["start_walking", "run_forward"], # v1 rigs
  have no walk loop`.** Men who should be walking are playing a **run** clip. Also
  `wounded_crawl → injured_walk_backwards`, `stand_to_cover → idle_crouching`.

> **THE PROBE: log every alias hop, every `__family` miss, and every clip switch with its blend, across
> one full demo run. Output = a RANKED LIST OF NAMED DEFECTS with counts.**
>
> **That list is the acceptance test.** "Smoother" becomes *"these fourteen substitutions, ranked by
> how often the player sees them, are gone."* Done is countable. It closes under ADR-015. It runs
> today, costs an hour of code, **zero art-days**, and it is gate-exempt as an evidence-gathering
> probe.

Without that list, an agent told "make it smoother" will author clips nobody sees while a run loop
plays at walking speed in the player's face all day.

---

### P3.3 · THE TIMING OBJECTION, SHARPENED

The EA date passed **2026-09-06**. The §8.0 gate — **the demo playthrough — is UNDISCHARGED.** Zero
playtest items closed. **He is commissioning a polish pass on combat he grades at 60%, without having
completed the playthrough that is the standing entry gate for judging it.**

Say it plainly: **the gate exists to produce exactly this verdict, under real conditions, end to end —
and it has not been run.** So "60 percent" is a verdict formed on fragments: arena sessions, a
mid-arc look, the odd firefight. It is very probably *directionally right* — his eye usually is. But
a full playthrough would tell him **which 40%**, and *which* is the entire question. The perf probes
would tell him whether the 40% is animation at all or frame pacing. **Discharging the gate is not a
delay to this work. It is the cheapest way to aim it**, and it is the one thing on the board that
only he can do.

---

### P3.4 · THE STEELMAN, MADE HONESTLY

**The Bible's Pillar 1 is "Believable firefights — AI that fights like soldiers AND weapons that kill
like weapons, NEITHER SUBORDINATE."** Not "AI that decides like soldiers." **Looking right is not
polish under that text; it is half the pillar.** And:

- **A store page is animation.** Trailer footage, capsule art, the GIF on the Steam page — all of it
  is men moving. A player deciding in four seconds whether to wishlist is judging *exactly the thing
  he named*, and none of the correct architecture underneath is visible in that four seconds. The
  best save-integrity in the world sells nothing.
- **DESIGN.md names the AI stress-test arena as Pillar 1's gate** — the project already agrees this
  is a first-class, gated concern, not garnish.
- **My own Phase 2 conclusion argues FOR him.** I said the fix for cohesion is *presentation, not
  systems* — the man must be **readable**: crouched, head down, firing wild. **That is animation.** I
  cannot demand a presentation pass in §11 and call one a trap in §P3.1 without saying which.
- **He is the only person who can judge it, and he just did.** Law 3: the Summoner holds final
  authority. He did not ask for a feature; he reported that his game looks wrong.

**MY VERDICT ON THE STEELMAN: it wins on WHAT, and loses on WHEN and HOW MUCH.**

He is right that this is the highest-value *domain* left — righter than the cohesion idea he came in
with. **He is wrong to spend ART-DAYS on it before the probe in §P3.2 and the perf number in §8.1 #1
exist**, because until both exist he cannot tell an authoring problem from a wiring problem from a
frame-time problem, and **all three feel identical from the chair.** The steelman justifies *doing the
work*. It does not justify *authoring first*.

---

### P3.5 · MY OBJECTION UNDER BOTH AUDIT OUTCOMES — STATED IN ADVANCE

Committing before the technical artist reports, so I cannot move the goalposts afterward:

- **IF THE AUDIT SAYS "MOSTLY ON DISK / UNWIRED / NO BLEND TREE" — I WITHDRAW MY OBJECTION ENTIRELY,
  AND I EXPECT THIS OUTCOME.** The evidence already points there: no AnimationTree, one fixed 0.18 s
  crossfade, no additive aim layer, an alias table of live degradations, **a walk intent resolving to
  a run clip**, and ~497 authored M101 channels with zero readers. Then this is **a code job costing
  ZERO ART-DAYS**, it is **presentation for already-shipped systems** — the §9 gate exemption, by
  name — and it is the best-value work on the board. **A blend tree and an aim layer would move
  "smooth" further in two days than a fortnight of new clips.** Under that outcome I am not merely
  neutral; I am for it.
- **IF THE AUDIT SAYS "IT NEEDS NEW CLIPS" — MY OBJECTION HARDENS AND I WOULD REFUSE IT.** New clips
  are art-days from the trailer's account, unbounded, unclosable, and post-gate work by any reading.
  The counter-offer is: **cut the ranked list to the top three defects the player sees most often, cap
  it at TWO art-days, and take the rest post-launch.** A cap is the only stopping rule an adjective
  will ever accept.
- **IF THE AUDIT IS MIXED (most likely in practice):** wire everything free first, re-measure with the
  probe, and let the *residue* — a list, with counts — decide whether any art-day is spent at all.

---

### P3.6 · WHAT I CHANGE FROM PHASE 2, EXPLICITLY

1. **§2 (the r4bk "orders stop working" objection) is MOOT.** He never asked for it. It stands
   unopposed and is withdrawn from the live debate — but **keep it in the record**, because "cohesion
   gates orders" is the kind of idea that comes back, and this is where it was refused.
2. **§3, §4, §8 (Pillar 3 rails, Pillar 5 reload spiral, the grunt-promoted-to-lieutenant) are
   WITHDRAWN as live objections.** They were aimed at a management layer nobody is building. They
   remain valid law for the next proposal.
3. **§1 (it is already built) is UNCHANGED and now applies TWICE.** It was true of cohesion. The
   evidence says it is about to be true of animation. **The pattern is the finding: this project's
   defects are overwhelmingly UNWIRED AND UNPRESENTED WORK, not missing work.** Two independent
   architects reached that on two different systems in one day — the convergence signal the war-room
   law names as the strongest this process produces.
4. **§5, §6 (the scope wall and the displacement) are UNCHANGED and STRONGER.** Cohesion was a design
   proposal that could be argued down. **An art pass cannot be argued down; it can only be capped**,
   and it draws from the trailer's unbudgeted account.
5. **NEW, and the one thing I would put in front of him tonight:** the alias/family/blend probe of
   §P3.2. It is the difference between an infinite session and a closable list, and it costs an hour.
6. **UNCHANGED, and I will keep saying it until it is done: HE HAS STILL NOT PLAYED THE DEMO END TO
   END.** Every question in this council — is it 60%? which 40%? is it clips or frame time? — is
   answered by the one task that only he can perform, and it has been open since the target date
   passed.

> **The trap was never cohesion, and it is not animation either. The trap is authoring before
> measuring — on a project whose last two audits both found the work already done and merely
> invisible.**
