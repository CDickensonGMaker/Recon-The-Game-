# ADR-018: Progression — rank gates AUTHORITY, never ABILITY. Player stats killed.
**Date:** 2026-07-12 · **Status:** Accepted (Summoner decree, THE LIVING WAR) · **Amends:** GAME_GUIDE §4.4 (squad XP + "St/Ag/Al" pool spend), DESIGN.md RPG layer · **Kills:** player stat progression

## Context

The Summoner asked the question directly, and it is the right question:

> *"this loops into the rpg element where your squad and you get skills improvements overtime — **or should
> we not even have this? should it be silent xp ranks for the AI only.** and even now as im writing this out
> i'm thinking maybe to live this hell let loose fantasy is there is a unlock level system for access to
> 'ranks' and more guns for the player. this way it creates the come back loop … bigger backpacks, different
> helmets … and with the higher levels more content is unlocked like larger airstrikes and artillery."*

Three candidate systems were on the table, and they were being treated as one. They are not. They serve
different masters and they get different answers.

The inherited design (GAME_GUIDE §4.4, from the RECON tabletop) has **learn-by-doing XP spent from a team
pool on St/Ag/Al + skills** — for the squad *and* the player. That directly threatens **Pillar 1**
("*death comes from situation — ambush asymmetry, exposure, volume of fire — never from hit-point math*").
A player-accuracy stat is hit-point math by another name.

Separately, the project has **no retention loop at all.** Nothing pulls a player back for mission twelve.

## Decision

### 1 · PLAYER STATS: **KILLED.**

**No player progression may touch accuracy, recoil, sway, handling, health, or stamina. Ever.**

Your aim is your aim, from mission one to mission one hundred. If a round misses because the character has
low Agility, then death came from a stat sheet and not from *situation* — the exact thing Pillar 1 forbids.
It also makes the opening ten hours feel bad in the worst available way (*"my guy can't shoot yet"*), which
is a fatal first impression for a game whose entire draw is that the gunplay is good.

### 2 · SQUAD XP: **KEPT — but SILENT and BEHAVIORAL.**

Squadmates improve by doing. **The improvement is never shown as a number.** It is shown as **competence**:

| Green | Veteran |
|---|---|
| The point man walks you into trip wires | He **stops, and holds up a fist, before you get there** |
| The pigman sprays and burns the belt | His suppression is tight and he reloads behind cover |
| Doc takes his time getting to you | Doc is on you fast, and he lives through it |
| Callouts are late and vague | Callouts are early, directional, and right |

**This is the teeth Pillar 4 has never had.** Losing a veteran must hurt *in the gut*, not on a spreadsheet
— and it only can if a free rookie is visibly, audibly, painfully worse at his job. (Today, loss is
costless: an instant free replacement, GAME_GUIDE §4.4.)

### 3 · PLAYER RANK: **NEW. It gates AUTHORITY, not ABILITY.**

In the real Army a PFC does not get to call an Arc Light. **Rank = trust = what you are allowed to have on
the net.** This is diegetically perfect, it is the HLL come-back loop the Summoner is reaching for, and it
never touches a bullet.

| Rank GATES | Rank NEVER gates |
|---|---|
| **Fire-support tier** — your own 60mm + a smoke marker → 105s → fast movers, napalm → Arc Light | accuracy, recoil, sway, handling |
| **What you are trusted with** — a new man is not handed a village raid; mission types unlock | health, stamina, bleed-out time |
| **The armory and the ruck** — better weapons *arrive with supply*; capacity grows | anything a bullet cares about |
| **Cosmetics** — helmet, gear, ruck (seen in the firebase, and on your own corpse) | — |

**THE LADDER LAW (binding — Devil's Advocate, upheld):** rank gates **how big**, never **whether**. A
hardcore-lethality game with *zero* fire support at rank 1 is not hardcore, it is miserable. Rank 1 has a
radio, a smoke marker, and his own 60mm mortars. **It is a ladder, never a wall.**

**ADR-011 stands unamended:** all fire support remains RTO-gated regardless of rank. Rank decides what is
*on the menu*; the RTO decides whether you can *order from it*. Lose him and rank buys you nothing.

## Consequences

**Bought:** a retention loop that is *also* diegesis — climbing from a nobody who can call smoke to a man
the brass will spend a B-52 on is the Vietnam career arc, told with zero cutscenes. Pillar 1 is protected
absolutely: this game's guns never get better and never get worse, so every death remains legible as
*something you did*. Pillar 4 finally gets consequences: a veteran squad is a measurably different squad,
and permadeath finally costs something. And the cosmetics are cheap fun with a real payoff surface (the
firebase, and the ragdoll).

**Sacrificed (no free lunches):**
- **The RECON tabletop's player-character advancement is dead.** The St/Ag/Al pool survives for the squad
  only. This is a real divergence from the tabletop backbone and it is named here rather than drifted into
  (GAME_GUIDE §5 requires the divergence be named in an ADR — this is that ADR).
- **Rank-gating mission types is a soft rail.** It restricts player freedom (Pillar 3) in the opening hours.
  Accepted, narrowly: the restriction is *diegetic* (the brass doesn't trust you yet), it is *temporary*, it
  never restricts **route or method** inside a mission, and it never gates stealth. **It may never grow into
  a linear unlock tree that dictates order of play.** The Arbiter guards this line.
- **Silent squad XP is hard to author and impossible to see.** Its whole value is felt, not read — which
  means it is the easiest system in the game to build and have nobody notice. It needs *behavior* budget
  (trap-spotting, callout quality, cover discipline), not a stats screen. **It violates the r4bk law on
  purpose** (a feature with no HUD affordance) — its affordance is the man himself, and if that isn't
  legible enough to feel, the system has failed and must be cut rather than papered over with a UI.
- Fire support becomes the **primary** power fantasy, which raises the stakes on ADR-011 actually being good.

**Work created:** rank + XP ledger in CampaignState/ProvinceState (save migration, ADR-007) · fire-support
tiers keyed to rank · armory/ruck unlock by rank · mission-type trust gate · squad veterancy *behaviors*
(the real work) · rookie-vs-veteran differentiation · cosmetic slots. Beaded under the LIVING WAR epic.

## Evidence

- Summoner deep-dive, 2026-07-12 (verbatim quotation above); decree at
  `production/war_room/synthesis_living_war.md` §5
- `production/GAME_GUIDE.md` §4.4 — the inherited "learn-by-doing squad XP + debrief pool spend (St/Ag/Al +
  skills)" and the admission that **"Loss is still costless (instant free rookies)"**
- `production/GAME_GUIDE.md` §1, Pillar 1 — "death comes from *situation* … never bullet sponges"
- **ADR-011** — fire support is RTO-gated with per-mission budgets rolled at briefing (the surface rank hangs on)

## Related

- **ADR-011** (fire-support ladder) — rank sets the menu; the RTO sets the access. Both must hold.
- **ADR-017** (persistent province) — rank and squad veterancy live in the province ledger
- **ADR-007** (saves) — another forcing function on the dead migration path (bead z90e)
- Pillars served: **1. Outstanding gunplay** (protected by *killing* a feature), **4. The squad is the RPG**
  (given teeth for the first time)
