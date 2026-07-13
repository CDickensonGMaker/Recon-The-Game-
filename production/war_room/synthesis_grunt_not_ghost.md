# DECREE — **THE GRUNT, NOT THE GHOST**

**2026-07-13** · Summoner: Caleb · Arbiter: recon-overseer · Council: Game Designer · Devil's Advocate
**Status: AWAITING SUMMONER RATIFICATION. Nothing shipped.**

---

## 1 · YOUR INSTINCT WAS A BUG REPORT

You said stealth shouldn't be the core focus. **The Devil's Advocate found out why it felt wrong, and it is
worse than a design disagreement — it is a defect:**

> **`mission_director.gd:49` calls `register_group` AT SPAWN.**
>
> So ADR-006 pays **+25 for every group the player NEVER SAW.**
>
> ## **THE OPTIMAL ADR-006 PLAYER IS A MAN WHO HIDES AT THE LZ.**
>
> **It rewards ABSENCE, not stealth.**

You didn't dislike the stealth game. **You disliked a scoreboard that paid you for not playing.**

---

## 2 · THE CONTRADICTION I COULDN'T RESOLVE — **IT RESOLVES**

*"Find and fight"* vs ADR-019's *"body count is a losing strategy."* The Devil's Advocate went and **read
the hostility table**, which I had not:

> ADR-019 lists **arson · civilian deaths · livestock · executions · careless artillery.**
> ***"Killed armed VC in a treeline" appears NOWHERE on it.***
>
> And §1 says every VC killed **permanently drains a finite pool**, with the win condition:
> *"their strength is broken **AND** the districts do not hate you."*
>
> **KILLING ARMED VC IS HALF THE WIN CONDITION.**

**Attrition and conduct are ORTHOGONAL AXES.** You kill armed men (attrition). How you treat the ville sets
the pool's **refill rate** (conduct).

> # **Kill every VC and still lose — because you made more than you killed.**
>
> *That is the American war in one line, and it was already in the design.*

### ⚠ THREE BINDING CONDITIONS, or it collapses back into a contradiction

1. **`allegiance` may NEVER read the kill counter. Conduct only.** *(The one-line
   `allegiance -= kills * k` is sitting right there, and it would make ADR-019 devour the core fantasy.)*
2. **Clean attrition must visibly outrun clean regen** — or the gun is a lie.
3. **TURKEY SHOOT pays FLAT PER ENGAGEMENT, NEVER PER CORPSE** — or `kills × 10` walks back in wearing a
   ghillie suit.

---

## 3 · THE AXIS IS **FOUR** TERMS, NOT THREE — the council beat the Arbiter

My proposal had three. It was wrong in two places, and both fixes matter.

| Verdict per group | Score | |
|---|---|---|
| **TURKEY SHOOT** — you initiated | **+50 flat** | ≥1 casualty in the opening 5s *(kills the 300m-potshot farm)*. **Flat. Never per corpse.** |
| **STAND-UP WAR** — mutual | **0** | |
| **★ OBSERVED-UNSEEN** — **you found them; they never found you** | **+25** | **THE MISSING TERM.** |
| **AMBUSHED** — they initiated | **0 TODAY** | ⚠ see below |
| SLIPPED PAST (never observed either) | **+10** | *(not +25 — and it must be **observed**, not merely spawned)* |
| SIGN FOUND | +15 ea | ADR-021's intel income, kept |
| **KILLS** | **ZERO** | unchanged |

### ★ Why OBSERVED-UNSEEN is the whole answer

It is **your** *"element rewarding sneakier playing"* — precisely. It **kills the hide-at-the-LZ exploit**
(you must actually *find* them to score). And it makes ADR-021's promise **literally true**: *the ghost run
and the gun run are the same run, a week apart.* You watched them, you learned their route, you didn't
shoot **today**.

### ⚠ AMBUSHED pays 0, not −50 — and the Fairness Law demands it

> **Do not scold a man for a tell the game never drew.**

An ambush is *by definition* the thing he could not see. Punishing him for it is **victim-blaming disguised
as design** — **until sign is findable.** Turn the penalty on only when the player can actually read the
ground. **And cap it below the turkey-shoot reward, always.**

### And I missed a cash prize for pacifism

**`_ghost_bonus()` pays +75 for finishing an objective in ≤15 rounds** — *larger than any contact line in
the game.* My proposal walked straight past it. **Replace it with FIRE DISCIPLINE:** +75 for hits/shots ≥
0.35 with no civilian casualties. *Rewards the marksman, not the coward.*

---

## 4 · HOW "WHO INITIATED" IS HONESTLY DETECTED — *(the crux, and it's cheap)*

> **The engine cannot see the player's eyes and must never pretend to.**

**The honest signal is the GROUP'S ALERT TIER at the instant the first round landed** — sampled once, frozen.

| | |
|---|---|
| Player's round lands while the group is **≤ SUSPICIOUS** | **you initiated** |
| Group is **≥ ALERT** | **mutual** |
| Enemy `_stamp_contact()` **and fires first** | **you were ambushed** |

Both hooks already ship (`enemy_base.gd:861`, `mission_director.gd:54`), and `mission_state.gd:70` is
**already a per-group dictionary.** **This is ONE ENUM on an existing dict. No new rays.**

*Rejected:* `contact_conf` (per-enemy, flickers, nondeterministic on the same seed) and the global beacon
(not per-group).

**Anti-cheese:** a cold sentry at 8m you reflex-shoot is **not an ambush**. Gate on **range ≥25m OR
stationary ≥3s.**

---

## 5 · IS THE STEALTH WORK WASTED? **~85% PRESERVED — and CONSUMED, not deleted**

The witness rule is not an escape clause. **It is the PRECONDITION of a turkey shoot.** And
`MissionState._detected_groups` is *already the exact classifier the new axis needs.*

**ADR-006 is not deleted. It becomes the SF DLC's scoring ADR — which is what it always was.**

**What IS lost, and I bill it honestly:** **THE HUNT IS DEMOTED** — from the core loop to a failure-state
consequence (Pillar 5). **We built the SF DLC's spine on day one of the grunt game.** It is excellent, it is
probed, and it is now garnish until the DLC.

---

## 6 · ⚠ THE TRAP — and it is a hard dependency

> **Initiative-scoring without ADR-021's schedule-driven patrol routes is literally "shoot first, win."
> A CORRIDOR SHOOTER.**

You only get to *set* an ambush if the enemy is **going somewhere on a schedule you can learn.** Today
`EnemyBase.spawn_enemy` still drops men at a point with no route *(bead 0623 gap #1, open since 07-08 —
the in-mission circuits shipped, the province-level rotation did not)*.

**The scoring rework is worthless without it. Do not ship one without the other.**

---

## 7 · THE DEVIL'S ADVOCATE'S CLOSING SHOT, AND THE ARBITER UPHOLDS IT

> **Three scoring decrees in four days. Zero playtests.**
>
> The squad command controls are **gone** (`r4bk`). The player still isn't seated in the Huey (`a2qb`).
>
> **Ship the minimum. Build nothing behind the gate. Then close `ida9`.**
> **The next scoring ADR cites a playtest, or it does not get written.**

---

## 8 · THE DECREE (pending ratification)

**AMEND ADR-006** → new ADR: **initiative, not avoidance.** Four terms. Flat per engagement. Kills zero.
`_ghost_bonus` → fire discipline. AMBUSHED = 0 until sign is findable. **Fix `register_group`-at-spawn — a
group you never saw scores NOTHING.**
**ADR-019 survives intact**, under the three binding conditions in §2.
**ADR-006 is re-homed as the SF DLC's scoring ADR.**
**Hard dependency: patrol routes (0623) ship first, or this is a corridor shooter.**
**Hard requirement: the "being noticed" pip** — *without it, a turkey shoot is a coin flip, not a decision.*

**~2 hours of code. Gate-permitted (decree item + a bug fix).**

*The Summoner holds final authority.*
