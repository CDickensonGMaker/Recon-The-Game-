# DESTRUCTIBLE JUNGLE — GAME DESIGNER'S ANALYSIS
**Architect:** Game Designer · **Date:** 2026-07-12 · **Subject:** `production/DESTRUCTIBLE_JUNGLE_PLAN.md`
**Lens:** Is it fun, and does it serve the Five Pillars?

---

## VERDICT IN ONE LINE

**The plan's best idea is buried under its worst one.** Phase 1 (trunk colliders) is the highest-value
item in this project's entire backlog and needs *none* of the machinery below it. Phase 2's core tension —
**you can burn down your own cover** — is the most on-thesis mechanic anyone has proposed for this game
and it is a **trap in its current form**, because it changes a number the player cannot see. And Phase 2b's
stated make-or-break test is Minecraft, not Vietnam, and it is steering the whole feature into a ditch.

---

## 1 · THE CRUX — "the player can burn down his own cover"

### It is a great tension. It is the best idea in the document.

Name what it does that nothing else in this game does: **it puts a price on firepower that is not ammo.**

In every other shooter an RPG is pure upside. Here, every explosion you fire thins the one thing keeping you
alive. `vegetation_density` is the single number the AI reads; drop it and the sight cap walks from 45m
toward 140m. Your own high explosive is a *defoliant*. That is not a mechanic — **that is the American war
in Vietnam, expressed as a rule.** We stripped the jungle to find them and then we were the ones standing in
the open. Pillar 2 (Atmosphere) has never been served this hard by a systems idea, and Pillar 1's
"death comes from *situation*" gets a new, permanent, self-inflicted situation.

Against THE HUNT it is better still. Today, evading the net, the player has exactly one bad move: **make
noise.** Noise is transient — it decays, you move, it's gone. Destructible jungle adds a second and far
crueller class of mistake: **make a hole.** A hole does not decay. It is a mistake that *outlives the
moment that made it.* No other system in this game does that, and games are made of mistakes you can point
at afterwards.

### It is ALSO a trap, today, and here is exactly why.

**Ask when the player actually fells trees.** The plan is written as if he chooses to. He mostly won't.
His tree-felling tools are the M79 and the LAW/RPG — **weapons he fires during a firefight, at men.**
So the overwhelmingly common case is **incidental** destruction: he shoots at a bunker, three trees go
down, and forty seconds later he is seen and killed from 110m by a man who could not have seen him before
he pulled the trigger.

**He will never connect those two events.** Not once. Not in a hundred hours.

That is not tension. That is an invisible stat mugging him. It offends the *spirit* of the Fairness Law
("muzzle flash / tracers / vocalizations **always telegraph**") — the state change is not telegraphed
because **the state was never legible in the first place.**

And that is the real indictment, which is bigger than this plan:

> **`vegetation_density` is THE number the enemy AI reads, and the player has no affordance for it whatsoever.**
> Not a pip, not a readout, not a sound, not a vignette. **The r4bk Law says a feature without a visible HUD
> affordance does not exist.** By that law, *concealment does not currently exist* — and this plan proposes
> to let the player destroy it.

You cannot ship "you can destroy your own concealment" into a game that never told him he had any.

Note this also indicts the one-word fix in **0B** all by itself: fixing `get_density_at` →
`get_vegetation_density` makes every LZ real, which makes the game **harder** — enemies suddenly see the
player at 140m in clearings where they used to be blind. That is *correct*. It is also, to the player, an
unannounced difficulty spike in the two most memorable moments of a mission (insertion and exfil). Fix the
bug today. But it wants the readout too.

### RULING (Q1)

**GREAT TENSION. BLOCKED ON LEGIBILITY.** Ship a concealment readout **with or before** the first felled
tree. Not a bar with a number — a *state* the player feels: the detection pip (DESIGN §4.10, unshipped after
two decrees), plus an ambient/audio cue for **"you are IN it"** vs **"you are exposed."** Diegetic-first, per
§4.11. This is not a nice-to-have attached to the jungle feature. **It is Phase 0, it is code, and the
feature is a trap without it.**

Two corollaries the plan does not name:

**(a) THE HOLE IS SIGN.** A blown canopy hole is the loudest possible "an American was here" mark in the
world. It should feed **ADR-021's route-compromise** (they know that route is burned — they rotate), be
stampable on **ADR-022's OBSERVED layer**, and give patrols something to *find and investigate*. The
TreeRegistry already knows where every hole is. This costs almost nothing and it is the difference between
destruction being a **graphics feature** and destruction being part of **the LIVING WAR**.

**(b) THE ENEMY DEFOLIATES TOO — AND NOBODY HAS NOTICED.** `mission_director.gd:381` is on the plan's
`damage_area()` call list. That call site is `_arty_impact()`, and per GAME_GUIDE §4.5 **enemy mortars use
the same system** — the walking mortars that stalk your last-known position during THE HUNT. So the moment
Phase 2 lands, **the net does not merely chase you. It walks a mortar barrage into the jungle you are hiding
in and STRIPS IT OFF YOU.** The cover thins, the sight cap climbs, and you have to move — which lays
breadcrumbs, which moves the net. That is a terrifying, emergent, thematically perfect escalation and it is
**already free in the plan as written.** It is the single strongest argument for building this at all.
It is also a fairness knife-edge: mortars must strip **slowly** (they are walking a pattern, not
clear-cutting). Decide it deliberately — do not let it arrive by accident.

---

## 2 · THE NEW VERBS, RANKED BY HOW OFTEN A REAL PLAYER USES THEM (20–60 min mission)

| # | Verb | Uses/mission | Phase | Honest note |
|---|---|---|---|---|
| **1** | **Put a trunk between you and the rifle** | **dozens** | 1 | Not a new verb — **the repair of a lie.** See §5. |
| **2** | **Break blast with a trunk** | several | 1 | Free with layer 1: the trunk shadows grenade AOE. Life-saving in the E&E. |
| **3** | **Go prone behind a log** | several | **1 (see below!)** | Players will use **found** logs 10× more than **made** ones. |
| **4** | *Accidentally strip your own concealment* | 3–8 | 2 | **Not a verb — a consequence.** And the most interesting thing here. |
| **5** | **Drop a tree across a trail** (denial / herding) | 0–1 | 2b | **The plan does not have this verb. It should.** See §3. |
| **6** | **Blow your own LZ** | ≤1 | 3 | Frequency is the wrong metric for a **climax**. See §4. |
| **7** | **Drop a tree on an enemy position** | ~0.3 | 2b | A highlight-reel move, not a habit. Build if free; never cost-justify on it. |
| **8** | **Grenade a hooch** | 0 on PATROL, many on RAID | 4 | Good — and **a different feature wearing this plan's coat.** |
| **9** | **Fell a tree to cross a field** | **≈0** | 2b | The plan's own acceptance test. It is the weakest verb here. See §3. |

### THE FINDING THAT CHANGES THE ORDER

**`patch_deadfall` ALREADY EXISTS.** `tools/make_jungle_patches.py:701`, `patches.json:440` —
*"blowdown: crossed logs, ferns colonising."* It is stamped in the world right now. And like everything else
in the vegetation system, **it has no collision.** There are already logs all over this jungle and you walk
straight through them.

So verb #3 — *go prone behind a log*, the verb the plan says is **"most of the reason to build" Phase 2b** —
**can ship this week for the cost of one more array in C1** (`logs[]` alongside `trees[]`, capsule instead of
cylinder). Zero bitmask. Zero shader. Zero new GLB. Zero Blender window.

**That is not a nice-to-have. That is the cheapest possible test of Phase 2b's entire thesis.**
If crawling behind found deadfall isn't fun, the log you *make* won't be either — and you will have learned
it for a day's work instead of three weeks'. **Phase 1 must include deadfall logs.**

---

## 3 · "DROP A TREE ACROSS OPEN GROUND TO CROSS A FIELD" — Vietnam, or Minecraft?

### Minecraft. Unambiguously. And it is the most dangerous line in the document, because the plan has bet the whole feature on it: *"If that isn't fun, the whole feature is decoration."*

Four reasons it's dead on arrival:

1. **It is a builder's mental loop, not a grunt's.** It requires the player to stop, in front of ground he
   cannot cross, and take a *deliberate construction action to modify terrain to enable traversal.* A grunt
   does not think "I shall place a log." A grunt thinks **"I am not crossing that."**
2. **The game already solved this, better.** *WATER BREAKS TRAIL.* Gallery forest gives a **55m-capped
   concealed corridor** along the creek versus 140m in the open. The Vietnam answer to open ground is: **you
   don't cross it — you go around, you wait for dark, you use the creek.** That answer is period-correct,
   atmospheric, already shipped, and *free*. Phase 2b proposes to solve a solved problem with a worse tool.
3. **The physics of the fantasy don't work.** A felled tree is 10–20m against a field 100m+ across. It
   doesn't *cross* anything. It gives you one prone island in the middle of open ground — **a place to die,
   not a route.**
4. **The trade is transparently awful and every player will see it in one attempt.** To make that log you
   fire an explosive: GUNSHOT-class noise (55→150m, ALERT), plus the loudest object in the game hitting the
   dirt — **and you strip the density on the far side, raising the sight cap exactly where you are about to
   be.** You have paid concealment *and* noise to buy a 15m log in the open. Nobody does that twice.

### But the same object is EXCELLENT when it is a CONSEQUENCE instead of a plan.

The tree the RPG knocked down *during the firefight* is now a log you dive behind. **That** is a grunt
fantasy: the battlefield is being wrecked around you and you fight in the wreckage. Emergent, not
constructed. Keep the log. **Kill the test.**

### REPLACE THE ACCEPTANCE TEST

> ~~"Drop a tree across open ground and use it to cross a field you couldn't cross before."~~
>
> **NEW:** *A firefight in the jungle physically changes the ground, and you fight the second half of that
> firefight in the wreckage of the first half.* And: **you are being HUNTED, you have no cover, you drop a
> tree between you and the net — and it saves your life.**

### AND ADD THE VERB THE PLAN IS MISSING: **DROP A TREE ACROSS A TRAIL.**

*This* is period-correct — abatis, road-cutting, denial; it is what soldiers have actually done with trees for
three thousand years. ADR-021 anchors VC patrol nodes to **trails, fords, and junctions**. Fell a tree across
one and you have **denied a route, or forced them around it — into the ground you chose.** That is
**herding the enemy**, and it plugs straight into ADR-021's routes and ADR-022's AMBUSH mark. It is the same
code as "cross a field" and it is a fantasy worth building. *That* is what the fall is for.

---

## 4 · BLOWING YOUR OWN LZ (Phase 3) — BOTH SIDES

### FOR — it may be the single best moment in the game.

- **It is literally the owner's fantasy.** MACV-SOG E&E: chased by a thousand men with six in your squad, and
  **there is no LZ — you make one.** Blowing your own extraction hole is not a game-design invention; it is
  the source story. On pure fidelity: yes, this is the climax.
- **It is the biggest Pillar 3 (Freedom) win available in this document.** Exfil is currently the *least
  free* moment in the game: a marker the generator chose. This converts it from a **place you run to** into a
  **place you make.** Nothing is on rails — including the way out.
- **The tension is exquisite and self-balancing.** To make the hole you must fire loud explosives (the net
  converges on the noise), and the hole itself is bald ground at a **140m sight cap with no concealment.**
  **You have built the exact terrain that will kill you, and now you must hold it while the bird comes in.**
  Pillar 1 (situation kills), Pillar 2 (a last stand in a hole you blew), Pillar 5 (it goes hot, the bird
  waves off, you run again). And the systems for that last stand are **already built** —
  `landing_zone.gd` COLD/WARM/HOT, `exfil_zone.gd`'s 35% shoot-down inside 160m. This feature is the missing
  *input* to a climax that already exists.

### AGAINST — and this case is real.

- **The current E&E climax is a CHASE. This turns it into a SIEGE.** "Sprinting for a hole in the canopy with
  a net closing" is a **movement** fantasy — momentum, breath, the creek, the trail. "Stop in one place, blow
  a hole, hold it" is a **static** fantasy — and every shooter already has that one. **If blowing your own LZ
  becomes the default exfil, you have deleted the owner's stated fantasy in the act of serving it.**
- **It deletes geography from the ending.** ADR-017: *mission length is GEOGRAPHY, not a dial.* The run to
  exfil is the last piece of geography in the mission — the thing that makes the creek and the ridge and the
  gallery forest *matter*. **An exfil you can conjure anywhere is a fast-travel button with a cooldown of one
  RPG round.**
- **It is a get-out-of-jail card.** The correct answer to "the net is closing" becomes *"stop and make a
  hole"* rather than *"outthink them with the ground."* A mechanical answer to a positional problem is always
  the weaker game — and it is exactly the answer ADR-021 exists to make the player *stop* reaching for.
- **The tuning is a knife-edge with two bad ends.** 6 rockets to clear a canopy → nobody ever does it. 2 →
  everybody always does it. There is not much room in between.

### RULING (Q4) — both are true, and the resolution is a law.

> ## **YOU DO NOT MAKE AN LZ BECAUSE IT IS CONVENIENT. YOU MAKE AN LZ BECAUSE YOU ARE OUT OF GROUND.**

Build it, under four binding conditions:

1. **EXPENSIVE.** It costs your explosives — *all* of them. And you needed those for the fight you are losing.
2. **LOUD BEYOND LOUD.** Every round is a 150m ALERT beacon and the falling tree is louder still. Making an LZ
   is **the most detectable act in the game.** You are lighting a signal fire and inviting them to it.
3. **THE BIRD IS SLOW, AND `LZFinder.can_land()` IS CHECKED ON ARRIVAL, NOT ON CALL.** You must **hold the
   hole you made** — the hole with a 140m sight cap and nothing in it.
4. **THE GAME NEVER SUGGESTS IT.** No prompt, no highlight, no "suitable LZ site" affordance, ever. It is
   *discovered*, and it is a last resort. (Pillar 3 — and the Grease-Pencil Law: *the player* may mark it;
   the game never does.)

Under those four, it does not replace the chase. **It is what you do when the chase has failed** — and it is
the story you tell afterward. The chase stays the default; the hole stays the legend.

---

## 5 · THE ONE THING — **PHASE 1. TRUNK COLLIDERS. (+ deadfall logs.)**

It is not close.

> *"Nothing in the shipping game has collision on vegetation. You currently walk and shoot straight through
> every tree. The tree you dive behind mid-chase does not stop a bullet."*

**The jungle — this game's signature asset, the whole of Pillar 2, the entire physical basis of the E&E
fantasy — is a hologram.** The player is *already* diving behind trees. He is already doing it in the hunt,
already doing it under fire, already trusting the one object the whole game is made of. **And it does nothing.**

That is the worst possible **Pillar 1** violation. Pillar 1 says death comes from *situation*, never from
cheapness — and there is nothing cheaper than cover that lies. The Fairness Law promises the player that the
game telegraphs honestly. **A tree is a promise, and we are breaking it dozens of times a mission.**

And the owner's fantasy — *"being chased by 1000 men with 6 people in their squad. AND MAKING IT OUT
ALIVE"* — is **physically impossible today**, because during the hunt there is nothing solid between the
player and the net. Only a probability number. Density breaks line of sight; **only a trunk stops the round.**
You cannot make it out alive behind cover that isn't there.

**Cost:** near zero. One `StaticBody3D` per chunk with a cylinder per tree. **The recipe is already written**
(`scripts/levels/gore_lab.gd:203`). It needs no bitmask, no shader, no new GLB, no registry, no Blender
window, and no Phase 2. And it comes with grenade-shadowing, navmesh carving, and AI cover **for free**,
because layer 1 is already plumbed through `BulletSystem`, grenades, `ProjectileData.hits_world`, and
`CombatManager._can_damage_multipoint()`.

**Extend it with `logs[]` for `patch_deadfall`** (§2) and you also get the prone-cover verb — and a real,
cheap answer to whether Phase 2b's thesis holds, *before* you build Phase 2b.

**(0B, the one-word bug, is not a competitor — it is a one-word fix that should be done in the next five
minutes. But note it makes the game harder in a way the player cannot perceive, so it wants the concealment
readout too.)**

---

## 6 · WHAT IS DECORATION

| Item | Ruling |
|---|---|
| **"Cross a field on a felled tree"** (2b acceptance test) | **Worse than decoration — a MISLEADING NORTH STAR** that will steer the whole feature toward Minecraft. **Cut the test, keep the log.** |
| **PHASE 4 — destructible buildings** | **A different feature wearing this plan's coat.** It shares nothing with Phases 1–3 but one call site. It is *good* — but bundling it means **the jungle cannot ship until the buildings do.** **SPLIT IT.** It belongs to VILLAGE RAID, not to the jungle. |
| ↳ *except* the **filename footgun** (`collision_table.gd`) | **NOT decoration — a live bug.** `vc_hut_bunker.glb` is shootable-through because its name contains "hut." **Fix it today, on its own, regardless of everything else in this plan.** |
| **The falling tree kills what's under it** | Cool. Will happen **approximately never** — the AI moves, the fall is 2s, the arc is narrow. Build it *only* because the sweep + `apply_explosion_damage()` is nearly free. **Never spend a day tuning it. Never cite it as justification.** *(But it MUST be able to kill your own squad. That is worth more than every enemy it will ever crush — see §7.)* |
| **96-log cap + recycling** | Premature. Cap it; don't build recycling. A player who fells 96 trees has a different problem. |
| **Craters** — already marked DO NOT BUILD | **Agreed, loudly.** And extend the ruling: keep `engineering_system.gd`'s nine terrain ops **in the lab.** Digging a trench is an **RTS verb inherited from the ancestor project.** It is not a grunt verb. |
| **The transient `felled_tree.glb` fall** | **Earns its keep — keep it.** The fall is not spectacle, **it is the TEACHER.** Without a visible fall the tree just *vanishes* and the player never learns the rule that is about to kill him. |

---

## 7 · WHAT THE PLAN MISSES

**A. THE CONCEALMENT READOUT — blocking prerequisite (r4bk).** §1. Not calibration. **Code.** Phase 0.

**B. DOES THE JUNGLE REGROW? DECIDE BEFORE PHASE 2 SHIPS.**
ADR-017: *"Destruction is temporary; attrition is permanent. Bases rebuild; men don't."* **Nobody has asked
whether that law covers trees, and it is a campaign-killing question.** If felled trees persist in the
province ledger, then across 40 missions the province is **progressively deforested** — sight caps climb
everywhere, and by hour 20 the AO is a parking lot and the E&E fantasy has died of a thousand RPG rounds.
**My ruling: THE JUNGLE REGROWS over campaign days — except ground you HOLD** (the engineers keep the
firebase LZ clear). One line in `ProvinceState`. But it must be decided **now**, because it determines
whether `TreeRegistry` writes to the ledger at all.

**C. PILLAR 4 IS ABSENT FROM THIS PLAN. THE SQUAD IS NOWHERE IN IT.** Cheap fixes:
- The point man **calls the fall** — a bark, and a good one.
- The squad **uses the logs you made** as cover (the plan already says AI cover — good, hold it there).
- **A tree you dropped can kill your own medic.** The sweep already calls `apply_explosion_damage()` against
  all registered entities. **Let it.** *"Your rocket killed Vasquez"* is worth more to this game than every
  enemy that tree will ever crush — Pillar 4 (attachment), Pillar 5 (fail forward), and the Platoon /
  Apocalypse Now register in one accident. **Do not gate it. Do not warn him. Let it happen.**

**D. PRAISE, WHERE EARNED.** *"The moment of death is expensive and brief; what it leaves is cheap and
permanent."* That is not just good engineering — **it is good design**, because it means **the world's memory
is cheap.** A world that can afford to remember what you did to it is the whole premise of the LIVING WAR.
And *"do not time it out — cover that evaporates while the player is lying behind it is infuriating"* is
exactly right and should be a law: **the game may never take back cover it gave.**

---

## 8 · PILLAR SCORECARD

| Pillar | Verdict |
|---|---|
| **1 · Outstanding gunplay** | **Phase 1: enormous.** Cover that lies is the deepest possible Pillar-1 violation and it is in the shipping build. Phase 2/2b: modest positive. |
| **2 · Atmosphere** | **Phase 2's thesis is the most on-theme systems idea this project has produced.** You strip your own jungle. That is the war. |
| **3 · Freedom** | **Phase 3 is the biggest freedom win available** (the exfil stops being a marker) — *if* it stays desperate, never planned. **Phase 2b's "build your route" is FAKE freedom: a construction rail.** |
| **4 · The squad is the RPG** | **Untouched. A miss — and a cheap one to fix.** §7C. |
| **5 · Fail forward** | **Strong.** The hot LZ you blew, the bird that waves off, the hole you couldn't hold. And the permanent canopy scar is itself a fail-forward artifact the campaign remembers. |

---

## 9 · THE BUILD ORDER I WOULD ARGUE FOR

1. **0B** — the one-word fix. Five minutes. Regression test. *(Today.)*
2. **The filename footgun** (`collision_table.gd`). It is a live bug, not Phase 4. *(Today.)*
3. **PHASE 1 + `logs[]` for `patch_deadfall`.** Trunks and logs are solid. **The jungle stops being a
   hologram.** *(This is the ship-alone item. If nothing else in this document is ever built, the game is
   still substantially better.)*
4. **THE CONCEALMENT READOUT.** r4bk. Everything below this line is a trap without it.
5. **PHASE 2 + 2b** — with the trail-denial verb, with the enemy-mortar defoliation decided **deliberately**,
   with the "cross a field" test replaced, and with the regrowth question answered.
6. **PHASE 3** — under the four conditions of §4.
7. **PHASE 4** — as its own feature, on the VILLAGE RAID track, where it belongs.

---

*"Patrol to learn the ground. Use the ground to kill them."* — ADR-021

**This feature's whole worth is measured against that line.** A trunk that stops a bullet **is ground you can
use.** A hole you blew in the canopy **is ground you destroyed.** And the plan, as written, is far more
excited about the second one than the first.
