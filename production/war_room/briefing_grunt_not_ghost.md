# WAR ROOM BRIEFING — **THE GRUNT, NOT THE GHOST**

**Convened:** 2026-07-13 · **Summoner:** Caleb · **Arbiter:** recon-overseer
**Status:** COUNCIL IN SESSION. Analyses land in `war_room/analysis/grunt_*.md`.
**This is a PILLAR-TOUCHING correction. Nothing ships on it until the council reports and the Summoner
ratifies.**

---

## THE CORRECTION (Summoner, verbatim)

> *"For this slice of proof-of-concept I don't want to worry too much about sneaking and stealth as the
> main focus, because **US Army patrols were more looking to FIND AND FIGHT the enemy.** There should be an
> element rewarding sneakier playing, but **the core game fantasy is the US Army patrolling the woods.**
> The DLC later content is full Special Forces E&E."*

---

## WHAT THIS CONTRADICTS — and it is SHIPPED CODE, not a plan

**ADR-006 (shipped, live in `debrief.gd`):**
- **+25 per contact AVOIDED**
- **−25 per contact DETECTED**
- **kills pay ZERO**

> ## **ADR-006 ENCODES THE SOG FANTASY, NOT THE GRUNT FANTASY.**
>
> It is the scoring of a reconnaissance team whose job is **to not be there.** The Summoner is telling us
> the player is a **line infantry patrol whose job is to find and fight** — and the game currently
> **penalises him −25 for doing his job.**

**This is the exact contradiction the Arbiter flagged at the top of the 2026-07-12 session** and could not
resolve:

> *"The game pays you to avoid the only part of it that is actually finished."*

**The Summoner has now answered it.** He is not a ghost. He is a grunt.

---

## ⚠ THE ARBITER'S PROPOSED RESOLUTION — *the council is instructed to ATTACK it, not agree with it*

**The fix is NOT "pay for kills."** ADR-019 deliberately makes body count a **losing** strategy — burn a
village, raise their recruitment, the war grinds against you — and **that must survive.** It is the best
idea in the project.

**The real axis was already in the design, and it has NEVER BEEN BUILT.**

`GAME_GUIDE:119` calls it **"the design's lethality engine."** `VISION_READOUT:69`:

> *Every firefight is a **STAND-UP WAR**, a **TURKEY SHOOT** (you set the ambush — the only time full
> effectiveness applies), or an **AMBUSHED** scramble (heavy penalty until you reach cover).*

**Grep confirms it: never implemented. Not one line.**

### > **THE SCORE REWARDS INITIATIVE, NOT AVOIDANCE.**

| Situation | Meaning | Score |
|---|---|---|
| **TURKEY SHOOT** | **You saw them first. You opened.** | **big reward** |
| **STAND-UP WAR** | mutual contact, nobody had the drop | neutral |
| **AMBUSHED** | **They saw you first. They opened.** | **penalty** |

**Stealth stays valuable — because it is HOW YOU EARN THE TURKEY SHOOT.** But *slipping past the enemy
entirely* stops being the win condition, **because for a line grunt it isn't one.**

This is the Summoner's "element rewarding sneakier playing" — and it does it **without making the ghost run
the optimal strategy.**

---

## WHAT THE COUNCIL MUST ANSWER

**The sharpest contradiction (put to the Devil's Advocate):**
> *"Find and fight" + "body count is a LOSING strategy" (ADR-019) — **are these even compatible?** A patrol
> that finds and fights generates a body count. ADR-019 says body count raises VC recruitment. **Is the
> player now punished for doing exactly what we just told him his job is?** Resolve it, or say plainly
> that it cannot be resolved.*

**And the crux (put to the Game Designer):**
> *How is **"who initiated"** honestly DETECTED in code?* The pieces exist — alert tiers, the witness rule,
> the detection beacon, `contact_conf` — but which is the **honest** signal? Get this wrong and the game
> misreads a firefight and scores the player for something he did not do.

**Also on the table:** the fairness of an AMBUSHED penalty (the player is punished for something he *by
definition* could not see — is that design or victim-blaming?); what an **empty patrol** scores (it must not
be a failure — sometimes the woods are empty — but nor may "walk in circles avoiding everything" become
optimal again); and the opportunity cost of reworking scoring with **37 open P1s and a red GATE.**

---

## IS THE LAST DAY'S WORK WASTED? — the Arbiter's position, for the council to test

**No — it is REPOSITIONED, and it may be worth more where it now sits.**

| Built 2026-07-12 | Was | **Becomes** |
|---|---|---|
| The witness rule (an unwitnessed kill is silent) | the stealth economy | **how you EARN the turkey shoot** |
| Bodies are a liability | a stealth tax | the price of a sloppy ambush |
| **THE HUNT** — a net that chases at **169m/min**, NVA for 84s | the core threat | **PILLAR 5: FAIL FORWARD.** The thing that happens *when it goes wrong.* The "oh no" moment, not the default loop. |
| **Water breaks trail** | the escape route | the escape route — **and the SF DLC's spine** |
| Gallery forest, roofed creeks | concealment | concealment — *for the ambush you are about to spring* |

**The E&E systems are not the core loop. They are the FAILURE STATE of the core loop — and the DLC's
foundation, already built and probed.** *That is a better place for them than where they were.*

---

*Analyses: `war_room/analysis/grunt_game_designer.md`, `grunt_devils_advocate.md`.
Synthesis to follow. **The Summoner holds final authority.***
