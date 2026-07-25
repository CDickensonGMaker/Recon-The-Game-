# GAME-DESIGNER — W5: ROE / Noncombatant-Death Ledger

**Council:** 2026-07-24 ROE ledger (Arbiter: recon-overseer)
**Read from code, not plan.** Pointers below verified this session.

---

## What the code actually is right now

- **The hook exists and is CALLED, and is EMPTY on purpose.** `scripts/world/civilian.gd:378`
  calls `_record_noncombatant_death(attacker)` on every civilian death; `:382-386` is an
  intentionally-empty stub whose own comment says: *"The attach point for a future ROE / war-crime
  ledger. Nothing scores noncombatant deaths today - do not add scoring here without a decree; that
  system is explicitly out of scope."* So: the plumbing is laid, the water is off, and turning it on
  requires exactly this council.

- **The economy that DOES exist prices DISCIPLINE, never morality.** `debrief.gd:32-42`
  `compute_score()` — the static is still LIVE, called at `field_director.gd:1070` even though the
  DEBRIEF *screen* was deleted by ADR-029. It pays: `contacts_avoided ×+25`, `contacts_detected
  ×-25`, `-damage_taken`, `+50` fast, `+75` ghost/weapons-discipline, `-100` POW lost. **Kills earn
  NOTHING** (`debrief.gd:24-27`, `:75` reports `ENEMY KIA … (no XP - you were seen)`). The design
  DNA already established: *the game counts bodies and pays them zero.* Reporting ≠ scoring is a
  pattern this codebase already ships.

- **The shipped AAR is a toast, not a screen.** `field_director.gd:1066-1076` `_bank_patrol()` —
  `"BACK INSIDE THE WIRE - PATROL %d LOGGED, %d KILLS"`. The rich AAR panel is dead UI. Whatever we
  surface has one narrow, transient channel today.

- **A death already has a SEEN/UNSEEN dimension, and the sim already reacts to it.**
  ADR-005 witness rule: the global COMBAT beacon stamps only on *witnessed* contact — LOS or NoiseBus
  hit by a living other-than-victim. Civilians also carry `is_informer` and a `_transform_to_vc()`
  faction-flip path (`civilian.gd:395-404`). So a witnessed noncombatant death already has a native
  channel to *escalate the world* — informers, alarm, hunter pool — with no scoreboard involved.

- **The re-host is reserved.** ADR-006 `:4-15`: whether/how the ±25 economy re-hosts into the
  open-patrol AAR is *"an open question for the Summoner, not settled here."* A NEW ledger line is
  even more reserved than the old economy's re-host.

---

## (1) In-scope, or scope-creep?

**TRACKING a count is in-scope and cheap. SCORING it is scope-creep and pillar-violating.** These
are two different acts and the code already separates them: enemy KIA is *tracked and reported* while
buying nothing. A noncombatant count is the same act — the game may honestly know how many died.

The line is bright and it is the one the stub's own author drew: **the moment the count acquires a
point value, a penalty, a karma sign, or gates anything, it stops being information and becomes a
grade on the player's conduct.** That is the out-of-scope system the comment forbids without a decree,
and — crucially — it is out of scope *by pillar*, not merely by process.

## (2) SAFE surface vs UNSAFE surface under Pillar 5

**SAFE — information, zero teeth on the scoreboard:**
- A neutral count fed to the AAR exactly as `ENEMY KIA … (no XP)` is fed — e.g.
  `NONCOMBATANTS: %d` — **with no point value, no color-coded scold, no rank penalty.** It states a
  fact the recon element would honestly know. It informs; it does not judge. This is the *only*
  surfacing that clears Pillar 5's "not a sadism simulator" and Pillar 3's "no moralizing."
- **Better than a number: let the SIM carry the consequence, not the scoreboard.** A *witnessed*
  noncombatant death should feed the existing ADR-005 escalation machinery — surviving witnesses/
  informers raise the heat, the AO reacts. That is Pillar 5 fail-forward in its purest form
  (escalation, not a fail-state) and it reuses shipped systems rather than inventing an economy. The
  world punishes carelessness by *becoming more dangerous*, which is the game's native language, not
  by printing a lower number on a report card.

**UNSAFE — every one of these is a Pillar-5/Pillar-3 violation, do not build:**
- A war-crime / atrocity meter, a −N per civilian score line, a "clean hands" rank tier, a KIA-civ
  fail state or mission abort, a persisting guilt/reputation stat, or any red "WAR CRIME" toast.
  Each converts death-matters into a scold, makes the game *about* the player's morality, and turns
  the AAR into the sadism-simulator confessional Pillar 5 explicitly disowns. A penalty also
  perversely rewards *hiding* bodies over not making them — gamifying exactly the wrong verb.

## (3) Does hearts-and-minds / escalation-bias belong here?

**Split it in two:**
- **The escalation channel (witnessed death → the AO gets hotter) BELONGS and is pillar-native.**
  It is not a new economy; it is ADR-005's witness rule pointed at a new event type. This council can
  legitimately recommend wiring the empty hook to *nothing but* a count plus (optionally) an
  escalation feed through existing perception/NoiseBus/informer paths. No score touches the player.
- **A hearts-and-minds / karma / village-reputation SYSTEM does NOT belong here — it is a separate
  Summoner decision,** in the same class as ADR-006's reserved re-host. It is a new persistent
  economy that moralizes and can gate content; enacting it in a W5 council would be exactly the
  unilateral scope-grab the stub comment forbids. Surface it to the Summoner as a *question*, do not
  decree it.

---

## What is sacrificed (no free lunches)

- **A pure-information line has no teeth — it can be ignored.** Pillar 3's answer is that teeth
  should come from *the world*, not the scoreboard; but if the Summoner wants the death to *matter*
  mechanically and declines the escalation route, an information-only line will feel toothless. That
  is the accepted cost of refusing to moralize.
- **Routing consequence through witness/escalation inherits ADR-005's accepted cost:** a
  noncombatant killed where no one survives to witness pays *nothing* — perfect-silent play clears
  content with zero pressure. This is the same trade ADR-005 already accepted for silent kills; we
  are consistent, not novel. Alarm carriers/informers/patrol density remain the pacing levers.
- **Declining the karma meter sacrifices any authored moral arc / consequence narrative.** Accepted:
  Pillar 3 says the seeded world generates the stories, not authored setpieces, and a morality
  scoreboard is precisely the authored moralizing both pillars forbid. If the Summoner wants that
  arc, it is his to author — and it is a bigger decision than a ledger.
- **Leaving the stub empty vs wiring a bare count is itself a fossil-law question.** An empty
  intentionally-called stub is a documented UNFINISHED node, not a fossil — legitimate. But do not
  ship a *half* scoring path (a count that feeds a number that feeds nothing): that is the unfinished-
  ahead-of-wiring smell the FOSSIL LAW flags. Either keep it empty, or wire it fully to
  count+escalation with no scoreboard hook.

---

## Verdict (game-designer lens)

Track: yes, a count, in-scope, cheap, honest. Score/penalize/moralize/gate: no — that is the
out-of-scope war-crime meter the stub forbids and Pillars 5 and 3 both bar. Safe surface = a neutral
AAR information line with zero point value, twinned with (optionally) feeding *witnessed* deaths into
the existing ADR-005 escalation machinery so the **world**, not the scoreboard, carries the
consequence. Hearts-and-minds karma is a separate Summoner decision, reserved like ADR-006's re-host
— surface it as a question, don't decree it.
