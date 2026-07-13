# ADR-021: Patrols — routes that rotate, and the promotion that is the tutorial
**Date:** 2026-07-12 · **Status:** Accepted (Summoner decree, THE LIVING WAR) · **Depends on:** ADR-017 (the province ledger the nodes live in), ADR-018 (rank), ADR-019 (allegiance), ADR-020 (the authored threshold) · **Closes:** bead 0623 gap #1 (patrol routes)

## Context

Bead 0623 is the Summoner's make-or-break AI directive, and its first gap has stood open since 2026-07-08:
*"they need **patrol routes**, a tough searching mechanism when you are evading them, teamwork and firing
cohesion."* Today `EnemyBase.spawn_enemy` drops a man at a point with no route and no sentry facing. The
AO is a set of ambush boxes waiting for the player, not a place where people **live**.

Separately, the project had no answer to two hard questions:
1. **What does a "quiet" patrol pay?** A 30-minute walk with no contact is a wasted evening, and the
   Ambience Law (ADR-020 §4) does not save it — "safe to ignore" is a rule for *events*, not for *missions*.
2. **What is the tutorial?** The game has none, and a scripted one violates Pillar 3 outright.

The Summoner answered all three at once, from his own RTS work:

> *"just like i did in the vietnam rts game where i was setting up supply nodes, that would then generate
> travel paths. we generate 5 to 10 patrol points that are in various distances that zig zag across the map
> and the unit loops those patrol points for a set few days then a new set of nodes appear in a different
> pattern. and we could also make patrols that the player goes out on in the same way, where that can be an
> evolution of the missions with rank over time too. **the player is following the squad the first few
> patrols because you're new to the jungle**, but the higher rank you are, then **you are setting the patrol
> routes** (the allies switch from going to the nodes to just following you) but that role gives the player
> 4-5 locations… and you hit them in any order… sometimes there's contact along the way, sometimes there
> isn't, and make your way back to base."*

## Decision

### 1 · VC PATROL NODES — the war has a routine, and the routine can be learned

- Each district carries **5–10 patrol nodes** in the province ledger (ADR-017), placed at **various
  distances and zig-zagging** across the ground — never a ring around a base.
- **Nodes anchor to province FEATURES, not to random points**: a cache, a ville (tax collection), a trail
  junction, a river ford, high ground. A route that connects *things* is a route a player can learn,
  predict, and exploit — which is the entire point.
- A unit **loops its route** on the campaign clock. Patrols are a schedule, not a spawn.

### 2 · ROUTES ROTATE — on a clock, AND when they are burned

- **Time:** a node set expires after a handful of campaign days and a new pattern replaces it. Intel decays;
  recon is never *finished*.
- **Compromise (the important one):** hit a patrol hard on a route and the VC **know that route is burned,
  and change it.**

  > **A SUCCESSFUL AMBUSH COSTS YOU YOUR INTEL.** You cannot farm a kill zone. You spent map knowledge to
  > buy those kills; now go earn it again.

- **Allegiance decides whether your recon holds value at all** (ADR-019): a hostile district *tells them you
  were out there scouting*, and they rotate early. A cooperative district does not.

### 3 · THE QUIET PATROL PAYS IN GROUND

**A patrol with no contact must never be a wasted evening.** Its currency is not kills — kills pay zero
(ADR-006). Its currency is **the map**:

- Finding **sign** — a cold cookfire, a cache, fresh boot prints, a wired trail — **reveals VC patrol nodes**.
- Seeing them without being seen **already pays +25 each** (ADR-006) — this decree makes that the *primary
  income* rather than an odd tax.
- Civilians met on the way move allegiance (ADR-019).

> **PATROL TO LEARN THE GROUND. USE THE GROUND TO KILL THEM.**
>
> This is the RECON fantasy, and it resolves the standing contradiction the Summoner and the Arbiter found
> on 2026-07-12: *the game paid you to avoid the only part of it that was finished.* It pays you to avoid
> contact because **avoiding contact is how you learn where they will be** — and that is how you set the
> ambush that kills them next week. The ghost run and the gun run are the same run, a week apart.

### 4 · THE PROMOTION IS THE TUTORIAL (rank changes your ROLE, not your rifle)

The purest possible expression of ADR-018 ("rank gates authority, never ability"). **Rank decides who is in
charge of the walk.**

| Rank | Your role | What it teaches | What it *is* |
|---|---|---|---|
| **New in country** | **YOU FOLLOW.** An NPC sergeant sets the waypoints; the point man walks you through the jungle. | trail sign, trip wires, letting a patrol pass, that the war predates you | **THE TUTORIAL — diegetic, unscripted, and exactly how a cherry actually learned.** ADR-020's authored threshold is delivered *here*, while you are being LED. No popups. No rails. |
| **Trusted** | **YOU LEAD.** You get 4–5 locations (high ground, ruins, villes, roads, fords) and hit them **in any order, by any route.** The squad follows YOU. | everything, all at once | the game |

**The arc this buys, for free:** the boring patrol stops being boring at the exact moment you are promoted —
because now, **if you walk your men into an ambush, it was your route.** Same walk, same jungle, entirely
different meaning. The NPC sergeant you follow is the man you are eventually replacing; **if he dies before
you are ready, you take over anyway.** Nobody has to write that scene.

**Pillar 3 is NOT violated by the follow phase.** You may wander off at any time. The squad continues without
you; the point man may bark. Nothing stops you, nothing punishes you, and if you get yourself killed alone in
the green that is entirely your business. (ADR-020's binding test: *can he leave, right now, unpunished?*
**Yes.**)

## Consequences

**Bought:** the AO becomes a place where people **live** rather than a set of ambush boxes. A tutorial that is
not a tutorial. A reason for a quiet mission to exist. An income for stealth that makes ADR-006 finally
coherent. An anti-farming rule that emerges from the fiction instead of being imposed on it. And an arc for
the player that no writer wrote — the cherry who follows, and the sergeant who leads.

**Sacrificed (no free lunches):**
- **The follow phase is a soft rail and must be watched.** It restricts *authority*, never *movement* — but
  it is the closest this design comes to a rail, and it will tempt someone to enforce it "just a little."
  It may never be enforced. The Arbiter guards this.
- **Rotation is a knife-edge.** Too fast and recon is worthless; too slow and the province is solved. It will
  need real playtest tuning, and the honest failure mode is "my intel is always stale, why bother scouting."
- **"Sometimes there isn't contact" is still a design risk**, even paid in intel. If finding sign is not
  *fun to find*, the quiet patrol is dead and no economy saves it. Sign must be readable, physical, and
  worth stopping for — a job for art and audio, not systems.
- **An NPC sergeant is a character**, and characters are content. He needs a name, a voice, and a death.
- **Player patrol nodes are a second, parallel node system** to the VC one. They should share the generator.

**Work created:** VC patrol node generation (anchored to province features) · route looping on the campaign
clock · rotation by timer + by compromise + by allegiance · sentry posts with real facings · SIGN as a
findable world object that reveals nodes · player patrol missions (FOLLOW and LEAD variants) · the NPC
sergeant · rank→role gate. Beaded under the LIVING WAR epic (LW-10) and 0623.

## Evidence

- Summoner deep-dive 2026-07-12 (verbatim above)
- Bead **0623** gap #1: "PATROL ROUTES — trail-following exists (R18) but bare `EnemyBase.spawn_enemy` has
  no route; the mission generator should assign routes + sentry posts with real facings"
- **ADR-006** — kills pay zero; +25/contact avoided (shipped 2026-07-12, `debrief.gd`)
- **ADR-018** — rank gates authority, never ability. This is its flagship expression.
- **ADR-020** — the authored threshold; the binding test the follow phase must pass (it does)
- `scripts/enemies/enemy_squad.gd` — THE HUNT (shipped 2026-07-12) is what a *broken* patrol turns into

## Related

- **ADR-017** (province) — the nodes live in the ledger; rotation runs on the campaign clock
- **ADR-019** (hearts & minds) — a hostile district burns your recon early
- **ADR-018** (rank) — FOLLOW → LEAD is what rank *means*
- **ADR-020** (authored threshold) — delivered inside the follow phase, where it belongs
- Pillars served: **3. Freedom** (learn the ground, take any route), **2. Atmosphere** (the war has a
  routine), **4. The squad is the RPG** (the sergeant you replace), **1. Outstanding gunplay** (the ambush
  you set with what you learned)
