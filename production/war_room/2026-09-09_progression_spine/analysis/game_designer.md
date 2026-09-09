# GAME DESIGNER — THE PROGRESSION SPINE
**Session:** 2026-09-09 · **Lens:** loop, pacing, verbs, pillars · **Status:** independent analysis, no cross-talk

---

## 1 · DOES THE LADDER WORK AS A LOOP?

Yes at rungs 1, 2 and 5. It sags at 3 and it is actively dangerous at 4.

**Rung 1 — solo, no net (hours 0–4).** Moment to moment: walk, stop, listen, read sign, decide whether the thing ahead is worth being seen for. The verbs are *see first* and *leave*. This is already the ratified economy — ADR-006 pays +25 for contact avoided, ADR-021 §3 makes sign the primary income. Solo does not weaken that loop, it **completes** it: the reason the quiet patrol felt like a wasted evening is that you were walking it with five men who could have won the fight you were being paid to avoid. Alone, avoidance is not a choice against your own firepower — it is the only tool you have. Rung 1 is the strongest rung in the proposal and it is the one nobody will believe until they play it.

**Rung 2 — borrowing a stranger's RTO (hours 4–12).** Moment to moment: everything from rung 1, plus *the map now contains other Americans and they are a resource*. This changes routing — you plan patrols that pass within reach of an OP or a friendly element. **This is the best rung in the whole ladder** and it should be the longest. It is also the only rung that makes "a living world of other people's squads" mechanically load-bearing rather than scenery.

**Rung 3 — the RTO companion.** Sag. He gives you no verb you did not have at rung 2; he only makes it portable. What he adds is a **bodyguard job** — ADR-011's 10m leash means you now play the whole game with a man tethered to your elbow who dies to the first burst. That is a fine ten hours *if the game knows that is what it is* and prices it: he must be a named man with a face and a voice, he must be permanently losable, and losing him must drop you back to rung 2 for real. If he is a respawning utility, rung 3 is a downgrade dressed as a reward.

**Rung 4 — your own handheld radio.** This is the one I would fight. ADR-011's central law is *"the radio is a MAN… no bypass paths."* A pocket radio deletes the leash, the bodyguard job, rung 2's whole social geometry, and the reason ever to walk near another squad again. It is a rung that **removes friction**, and a rung that removes friction removes game.

**My ruling on rung 4:** the handheld exists, but it is a **PRC-25 you carry, not a radio you have.** It occupies the ruck, it weighs, and it is a **posture, not a possession**: to transmit you go static — down on a knee, antenna up, rifle slung, 8–12 seconds, no movement, no firing, and the animation is visible and audible to anything looking at you. ADR-011's `_radio_check()` gains a **second satisfier, not a bypass** — the leash stops being *"a man is within 10m"* and becomes *"a working set is within 10m"*, and your own set only works while you are kneeling in the open with a whip antenna over your head. The friction is conserved, the fiction is better, and ADR-011 does not have to be amended into a shape it cannot survive.

**Rung 5 — up to eight men.** A different game, correctly. See §6–§8.

---

## 2 · ADR-021 COLLISION — RULING

**ADR-021 survives. Its first row survives intact; its second row is superseded and must be named for deletion under ADR-023.**

Read ADR-021 §4 precisely. It has two rows, not one. Row 1 (**NEW IN COUNTRY → YOU FOLLOW**) is the tutorial: a cherry walking behind an NPC sergeant's patrol, learning trail sign and trip wires by being led. Row 2 (**TRUSTED → YOU LEAD**, "the squad follows YOU") is a *progression claim* — that rank hands you that same squad.

The solo pivot does not touch row 1. It **replaces row 2**, and with something better: rank no longer hands you the squad at hour two; it hands you a radio at hour four and a squad at hour twenty.

So the opening is neither "you are alone" nor "you lead men." It is: **you are a cherry attached to somebody else's patrol, and that squad is never yours.** At the end of the first patrol they walk back through the wire and go to their own hootch, and tomorrow you go out alone. That single change makes ADR-021's tutorial *pay for the solo pivot* — you have been shown what a squad is worth, on your first day, and then it is taken away. Twenty hours of ladder becomes a want, not a wait.

**Sacrificed:** ADR-021's cleanest line — *"if he dies before you are ready, you take over anyway"* — dies with row 2. There is no squad to take over. It must be named for deletion or it becomes a fossil inside an Accepted ADR. I would keep the sergeant's death and let it mean the opposite: he dies, his squad is folded into another platoon, and you are alone earlier than planned.

---

## 3 · SOLO IN A LETHAL GAME

A lone player dying repeatedly is **the point only if death is cheap and contact is avoidable.** Neither is true today, so the answer is: not yet, and here is the gate.

**The blocking dependency, stated as a dependency:** the solo pivot does not ship before **save-anywhere (ADR-007 Amendment A)**. ADR-040 already made this finding in a different costume — *"most of his problem is a save problem wearing a lethality costume."* Solo triples the exposure to that defect. Shipping solo before save-anywhere converts Pillar 5 into reload-and-memorise, which is a pillar breach, not a difficulty setting.

**The first three missions must install three survival verbs — none touching player ability (ADR-018), none gating stealth (Pillar 3):**

1. **SEE FIRST.** Solo is *harder to detect than a file of six* — fewer noise sources, one silhouette, no formation. This is not a buff to the player; it is a property of being one man, it rides the existing per-actor witness system (ADR-005), and it costs nothing to build. Say it out loud in the sergeant's mouth on day one: *"one man moves quieter than six. Remember that when we're not with you."*
2. **BREAK CONTACT.** Solo is unsurvivable unless pursuit gives up. Numbers I would hold to: lose line of sight in vegetation for **45s** and the pursuer drops to search-last-known; **90s** or **120m** and he quits and returns to his route. If THE HUNT never releases, one contact per patrol is a death spiral and the pivot dies on that alone. **This is the highest-risk item in the whole proposal**, and it is an AI tuning job, not a design job.
3. **READ SIGN.** ADR-021 §3's income must be findable *without a point man*.

**Mission 1** = ADR-021's follow patrol. **Mission 2** = solo, but inside the sound of friendly guns — a courier run to an OP where a firefight is audible and reachable. Nothing stops you going further; almost nobody will. **Mission 3** = solo, out of earshot, with ADR-020's authored-density guarantee weighted so the first encounter is a patrol you can sit still and let pass. Every beat refusable; no rails added.

**The expensive consequence nobody will want to name:** ADR-020's first-patrol guarantee contains a beat — *"a trip wire he catches before you walk into it"* — that **cannot exist without a point man.** Solo, it becomes a trip wire that kills you with nobody to blame. Either it moves onto the ADR-021 follow patrol (my choice), or it is replaced by sign the player finds himself — and "findable by an unaided newcomer" is an art-and-audio problem, not a systems one.

---

## 4 · PACING — MISSION 4–5 IS THE RIGHT DEPTH, THE WRONG UNIT

**Do not count missions.** ADR-029 patrols have no fixed length; "mission 4" is anywhere from 90 minutes to five hours, and the demo audit found **no onboarding at all**, so the real risk is not that the RTO arrives too early — it is that a fresh player never reaches patrol 4.

Trigger it on a **deed**, using the counter that already exists (`_bank_patrol`, `scripts/missions/field_director.gd:1797`):

> **The supplied-RTO patrol is offered on the first commit at the wire after (a) ≥3 committed excursions AND (b) one demonstrated failure the radio answers** — you witnessed a friendly element in contact you could not affect, or you broke contact under fire, or you found something too big to touch.

That lands for most players between hours 2 and 4 — roughly his 4th or 5th patrol, arrived at honestly. A player who tears through in 90 minutes has earned it early; a cautious player is not punished for walking slowly. Condition (b) means the radio always arrives as an **answer to a felt problem**, which is worth more than any tutorial ever written.

---

## 5 · BORROWING A STRANGER'S RTO

It must be the existing walk-up conversation, not a new prompt and not a menu.

- **Requires:** a living RTO in the other element; **you within ADR-011's unchanged 10m leash** (the leash function does not care whose radio it is — the cleanest possible extension); the **element leader's** permission, never the RTO's (you ask the man in charge — that is the whole social point); the net not busy; and your **rank** setting the tier you may ask for (ADR-018 untouched: rank gates how big, never whether).
- **Costs:** **their budget, not yours.** You spend another element's allotment. That element then walks its next contact one mortar mission short — and if they get hit, HQ and the platoon remember it (ADR-006 Amendment B's HQ opinion, ADR-038's factions). Borrowing has a memory, and the memory is social, not numeric.
- **Risks:** the antenna is the second most shot-at object in Vietnam. Standing at another squad's RTO makes you a target, and it puts you inside their danger-close radius for anything they call (45m, and the player-distance check already exists).
- **Under fire:** **refused by default**, and the refusal is a voice line, not a UI state — *"we're a little busy!"* It flips to yes if you have put rounds on their attacker in the last 30 seconds. **You earn the net by joining the fight.** That one rule is what stops it being a vending machine and turns it into the best scene in the game.
- **Three anti-vending guards:** one call per element per day · the element must be able to observe or mark the target (you cannot call on a grid they cannot see) · you queue behind their own calls.

**Sacrificed:** this makes fire support socially expensive and occasionally *unavailable when you did everything right*, which will read as unfair to some players. That is the correct trade and it must be defended, not softened.

---

## 6 · THE COMMAND VERBS

**Four is enough — because two of them are already shipped and one absorbs a fifth for free.**

Ground truth: `scripts/squad/squad_system.gd:281-291` already ships FOLLOW / HOLD / MOVE_TO / WEAPONS-FREE, and `_aim_ground_point()` (`squad_system.gd:328`, 250m reach, layer 1 only) already resolves the destination from **where the rifle is pointing**. **The period-HUD problem is already solved in code: the weapon IS the cursor.** No Brothers-in-Arms overlay is needed and none should be added. The proposal is a re-label of a shipped system, not new tech, and that is a strong argument in its favour.

What players will rage about, and where it goes:
- **"Cover that direction."** Absorbed: HOLD-AND-DEFEND takes the **player's aim vector at the instant of the order** as the watch-facing, ±60° sector. Free. No new verb, no new UI.
- **"Hold your fire."** Already shipped as weapons-tight, and it must **not** be deleted in the name of "four verbs." Keep it; it is a state, not an order.
- **"You — go there."** Refused. Pillar 4's anti-puppeteer clause forbids positioning individual men. All orders address the element; the medic already breaks on his own (RESCUE). **Sacrificed:** no *"pigman, set up on that treeline"* — a genuine tactical loss, and the thing squad-tactics veterans will miss most.

**HOLD AND DEFEND — the state machine:**

- **ARRIVE** — within 2.0m of `order_pos` (the existing threshold, `scripts/allies/ally_base.gd:1487`), then `_settle`.
- **ANCHOR** — occupy the best cover within 6m of the point. Watch-facing = the player's aim at order time; sector ±60°. (`scripts/allies/garrison_defender.gd` already holds a post with a defense_zone — reuse it; do not write a second one.)
- **HOLD** — engage into the sector while weapons-free; suppress; **never advance more than 8m from the anchor.** Hold is indefinite. There is no timer.
- **BREAKS — exactly four:** (1) the anchor becomes untenable (grenade within 8m, or accurate fire from behind the sector) → displace to a new anchor within 10m and re-hold; (2) the player goes DOWN → the **medic only** breaks; (3) REGROUP; (4) overrun (enemy inside 10m and outnumbering) → fall back 25m toward the player's last known position and re-hold.
- **NOT a break: the player walking away.** They hold. They hold until they are dead. At ~150m they call you once — one voice line, no HUD marker — and keep holding. **You can leave men on a hill, walk off, and hear them die.** That is what makes MOVE-HERE a commitment instead of a nav command, and it is the most important line in this section.

---

## 7 · THE AGGRESSIVE ATTACK

**ATTACK (unaimed):** fire and manoeuvre. Bound, use cover, go prone under fire, advance only when the target is suppressed (~0.6). Low exposure, low casualties — **and it will stall indefinitely against a dug-in position.** The stall is the design: it is the reason to escalate.

**AIMED ATTACK (ADS onto the thing, trigger held ~0.5s):** the element assaults *that* thing. Exactly what changes:
- suppression threshold to advance: **0.6 → 0.0** (they go regardless)
- bound length: **×2** (more open ground crossed per rush)
- time in cover between bounds: **~3s → ~1s**
- they **fire on the move** (accuracy penalty, volume up)
- they grenade at 25m
- they do **not** break for cover under fire until suppression exceeds **0.9**

**Expected price: 1–2 men out of 8** to take a dug-in MG that a normal ATTACK cannot take at all. It should feel like spending men because it *is* spending men, and the input is honest: **you aim at a thing and pull a trigger, and men die.**

Two guards. **It must be hard to give by accident** — ADS plus a held trigger plus a spoken acknowledgement that names the target (*"ON THAT BUNKER"*), and REGROUP always aborts the assault. And **men may refuse.** A green element that has already lost two will not cross the open ground; a veteran element goes. The refusal is where ADR-018's silent behavioural veterancy finally becomes *visible* — Pillar 4 with teeth, delivered by a verb instead of a stats screen.

---

## 8 · DOES IT DEGRADE?

Yes — and the honest answer is better than "yes": **the grammar does not degrade, it changes shape, because each rung has a different problem.**

- **Rung 2 (borrowed RTO):** zero command verbs. One social verb: *ask*.
- **Rung 3 (companion):** **one** verb — REGROUP. MOVE-HERE is actively *wrong* here: sending your radioman 60m away cuts your own net (ADR-011's 10m leash). Rung 3's game is not commanding, it is **protecting**. That is a feature; ship it as one and say so.
- **Rung 5 (eight men):** the full four.

**Does it make the player want the squad early?** Only if solo objectives ever require holding ground. So draw the line here and hold it:

> **THE SQUAD BUYS YOU GROUND YOU CAN HOLD. IT NEVER BUYS YOU GROUND YOU CAN REACH.**

Every place, cache, ville and tunnel mouth in the world must be reachable and usable by one man. The squad changes what happens *after* you get there. If a rung ever becomes required to enter a place, the ladder is a rail and Pillar 3 is broken.

---

## 9 · PILLAR CHECK

| Pillar | Score | Reasoning |
|---|---|---|
| **1 · Believable firefights** | **Strengthened** | Solo makes every round matter and touches no stat. ADR-016 and ADR-018 are untouched by the entire proposal. |
| **2 · Atmosphere** | **Strongest possible — with a real risk** | Loneliness *is* the *Apocalypse Now* target. The Devil's Advocate's "emptiness mistaken for atmosphere" charge is legitimate, and is answered only by re-weighting ADR-020's authored density for a soloist. |
| **3 · Freedom** | **Improved, one guard** | The ladder gates **capability, never content.** Guard it: no rung may ever be required to enter a place. |
| **4 · The squad is the RPG** | **RE-HOSTED, not deferred — conditionally** | See below. |
| **5 · Fail forward** | **Breached without save-anywhere; strong with it** | Hard dependency, §3. |

**Pillar 4, ruled properly.** Twenty hours of deferral is unacceptable *as stated* — 20 hours is longer than most players ever play, and a game whose pillar arrives after most of its audience has left does not have that pillar. But the pivot does not actually defer Pillar 4; it **re-hosts** it — the exact move ADR-006 Amendment B made with the score. Pillar 4's real content is *attachment to other men, and losing them.* From hour one the solo game is nothing but other men: the sergeant who leads you out on day one; the leader whose fires you borrow and whose men then die short a mortar mission; the RTO companion who dies for good; the element you watched get overrun from 300m and could not help. **Pillar 4 arrives earlier under this proposal, not later.**

What *is* deferred is the **roster fantasy** — named persistent teammates with MOS roles who improve, get wounded and rotate home (GAME_GUIDE §4.4).

**Named sacrifice, and it is the largest in this document:** the roster fantasy is a large part of what this game is sold on, and the pivot buries it behind twenty hours. The mitigation is §2's: ADR-021's follow patrol gives you a squad on day one and then takes it away. **You do not wait twenty hours for a thing you have never seen; you spend twenty hours earning back a thing you had on your first afternoon.** If that framing is not built, Pillar 4 *is* deferred by twenty hours, and I vote against the pivot.

---

## POSITIONS, IN ONE LINE EACH

1. The ladder works; rung 4 must become a posture, not a possession.
2. ADR-021 row 1 survives as the tutorial; row 2 is superseded and named for deletion (ADR-023).
3. Solo does not ship before save-anywhere, and break-contact must actually release.
4. Trigger the RTO on a deed, not a mission count.
5. Borrowing costs *their* budget, requires the leader, and is refused under fire unless you joined the fight.
6. Four verbs plus the shipped weapons-tight state; no individual tasking, ever.
7. The aimed attack is spending men, and green men may refuse.
8. The grammar changes shape per rung; the squad buys holding, never reaching.
9. Pillar 4 is re-hosted, not deferred — *only if* the opening squad is given and then taken away.
