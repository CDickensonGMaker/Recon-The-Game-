# DECREE — The ear necklace

**Date:** 2026-07-28 · **Status:** Summoner's feature request, design read
**Summoner, verbatim:**

> *"on the idea of checking bodies i want to collect enemy ears and we should make that be a modeled
> piece that they can view and the more ears they collect the more thats on the necklace"*

---

## 1 · What it is

Taking ears from enemy dead as trophies, strung on a necklace the player can inspect. The modelled piece
grows as the count rises.

Historically documented and widely depicted in the Vietnam canon this game already draws on
(*Platoon*, *Apocalypse Now*, *Dispatches*). It belongs in a hardcore Vietnam simulator, and it is
exactly the kind of detail that makes the setting feel unsanitised rather than tourist-grade.

## 2 · It must COST something, or it is an endorsement

This is the one design note the council will not soften. A trophy system that only ever pays out reads
as the game approving of the act. A trophy system with consequences reads as the game depicting it —
which is what the Vietnam canon actually does.

**The consequence hooks already exist in this project. Use them, do not invent new ones:**

| Existing system | How ears feed it |
|---|---|
| **ADR-019 village sentiment** — stated in words, never a number | a villager who SEES the necklace, or sees you cutting, reacts to it. Hearts-and-minds is a live economy; this is the cheapest way to spend it badly |
| **ADR-022 witness rule** — a body you left is already a liability | a mutilated body is a worse liability, and a stronger lead for anyone reading the ground |
| **Squad reaction / barks** (ADR-018 point man precedent) | the squad has opinions. A veteran NCO seeing his rifleman cutting ears is a character beat that costs one bark and buys enormous tone |
| **Hunter teams** (`patrol_route_and_hunters.md` §2) | mutilation is evidence, and evidence is what hunters converge on. Taking trophies makes you easier to hunt |

**Decree:** the necklace is a visible statement about the man wearing it, and the world is allowed to
have an opinion. It is not a score.

## 3 · What is sacrificed

- **Ratings and storefront.** Depicted mutilation is a mature-content decision with real consequences
  for age ratings and for Steam's content survey. That is a business call, not a design one, and it is
  the Summoner's to make with open eyes — noted here so nobody is surprised at submission.
- **Tone risk.** Played as pure reward it becomes a kill-counter cosmetic and cheapens everything the
  game is reaching for. Played with consequence it is one of the strongest atmosphere beats available.
  The difference is entirely in §2.
- **Art cost.** A growing necklace is not one model; it is a mesh that changes with count.

## 4 · Build shape

**Data.** A single persisted count on `CampaignState` alongside `intel_points`
(`scripts/autoload/campaign_state.gd:32`) — saved, loaded, and reset with the campaign like every other
campaign value.

**Earn.** Folds into the existing corpse-loot verb, `player.gd:710-731`, which already gates on
`lootable_corpses`, a 2.5 m radius and a `looted` meta. This is an addition to a working system, NOT a
new pickup path.

**Art.** One necklace mesh with N ear instances driven by count, built to the existing viewmodel
contract — real-world scale, per-weapon FOV lens (ADR-034), exported through
`tools/export_all_viewmodels.py`. Bucket the visual growth (e.g. 1/3/6/10/15+) rather than modelling
every integer; a continuous mesh is art cost for no readable gain.

**View.** "A modelled piece they can view" is an inspect pose, which is the FP-arms pipeline —
the project's stated top priority (Claude memory: *FP pipeline is MAIN PRIORITY*). It should ride that
pipeline, not fork a second inspect system.

## TUNE (Summoner)

- Does taking an ear require a separate deliberate input, or come free with the body check —
- Growth buckets — 1/3/6/10/15+? —
- Can the squad refuse, comment, or think less of you —
- Do villagers who see it react, and how hard —
- Is there any mechanical benefit at all, or is it purely a statement —
