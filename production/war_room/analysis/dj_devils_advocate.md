# DEVIL'S ADVOCATE — DESTRUCTIBLE JUNGLE

**Matter:** `production/DESTRUCTIBLE_JUNGLE_PLAN.md` (355 lines, 5 phases)
**Verdict:** **BUILD A SUBSET — and the subset is composed *entirely* of bug fixes.** Everything in this
plan that is a FEATURE must be cut, and it must be cut on procedural grounds before we even argue design.

---

## 0 · THE THING NOBODY SAID OUT LOUD

The plan is **355 lines long and cites the canon ZERO times.**

Not one ADR. Not THE SLICE. Not a pillar. Not the GATE. It is a superb engineering document that was
written as though `production/adr/` does not exist. That is not a small thing — ADR-014 makes the
GAME_GUIDE and the ADRs **canon**, and a plan that never once tests itself against them has not been
scoped. It has been *designed*.

And when I test it against them, it fails on the first check.

---

## 1 · THE KILL SHOT: THIS PLAN IS MECHANICALLY FORBIDDEN RIGHT NOW

Not "out of scope." Not "premature." **Forbidden**, by a standing P0 bead the team built on purpose to
stop exactly this document.

**`RECONgame-97u3` — "GATE: playtest P1s block feature epics (ADR-015 mechanical gate)" · P0 · OPEN**

> *"Every new feature epic is blocked by the GATE bead at creation... Consequence: `bd ready` physically
> hides feature work while any playtest P1 is open. **Exempt**: bug fixes; presentation/HUD work for
> already-shipped systems; items explicitly ordered by a standing decree."*
> — ADR-015 §1, and the bead's own description

**The GATE is blocked by SIX open P1s right now:** `a2qb`, `e6qc`, `ida9`, `n2ij`, `r4bk`, `zet2`.

`GAME_GUIDE §8.0` states it in plain language as build-order item **zero**:
> **"PLAYTEST R3 is the session entry point (ida9) — nothing NEW ships until it verifies a2qb/r4bk."**

Destructible jungle is NEW. It is a feature epic. **It is behind the gate, and the gate is red.**

### And we have done this exact thing before, and ADR-015 exists *because* we did it

ADR-015's Context section is a confession, and it reads like a prophecy of this document:

> *"Audit #1's decree adopted a playtest-gate law in markdown: no new features while playtest P1 bugs are
> open. The law was violated within the same working session — **BLOOD v2, a new system, landed at 18:36**
> with three playtest P1s still open... **Measured half-life of a markdown law: ~2 hours.**"*

**DESTRUCTIBLE JUNGLE IS BLOOD V2 IN A NEW COAT.** Same shape: a genuinely cool system, technically
excellent, arriving while the playtest board is on fire. The gate was made *mechanical* precisely so that
the next time this happened, it would be caught by a dependency edge instead of a paragraph. This is the
next time. **The mechanism works. Let it work.**

If the Council approves Phases 2/2b/3/4 as written, the honest summary of this session is: *the team built
a mechanical gate to stop itself from doing this, and then did this.* The gate's half-life would then be
**two days**, and we may as well delete ADR-015, because we will have proven a bead is as weak as a
markdown line.

---

## 2 · THE SCOPE CASE — Q1: "IS THIS THE DISEASE HE DIAGNOSED?" · YES

The Summoner's own words, quoted in `GAME_GUIDE §6.0` as the reason THE SLICE exists:
> *"expanding the content too much and not making a good game."*

THE SLICE, in full:
> *One province. One firebase, inside the AO, running its clock. A VC organization living in that same
> province — bases, patrols, and a night attack that can come to your wire. **Three mission types:
> PATROL / VILLAGE RAID / BASE ASSAULT.** Village allegiance. Rank.*

**Destructible jungle is not in it. Destructible buildings are not in it. Player-made LZs are not in it.**
Nothing in §6.0 becomes *impossible* without them. Nothing in §6.0 is even *harder* without them.

And §6.0 supplies the test the Arbiter is supposed to apply:
> **"The question is never 'can we have all this' — it is what is the smallest version that ALREADY FEELS
> LIKE THIS?"**

Run the test honestly. **A player who patrols out the wire, gets ambushed, loses a named man, and limps
back to a firebase that remembers — has he noticed that the trees don't fall over?** No. He has noticed
that they don't stop bullets (Phase 1 — a *bug*), and he has noticed that his squad won't take orders
(`r4bk` — a *bug*), and he has noticed the LZ is a lie to the AI (§0B — a *bug*).

**Everything the player would actually notice in this document is a bug. Everything that is new, he
wouldn't miss.** That is the whole finding, and I could stop here.

### The BFBC2 tell

Phase 4 opens by invoking Battlefield: Bad Company 2 and Frostbite. That reference is the plan's own
confession. **Frostbite's destruction cost DICE a AAA studio, a proprietary engine, and years.** The plan
correctly notes the magic was in the *authoring*, not the simulation — and then quietly proposes that we
do the authoring. We are one man and two Claude windows building a game whose squad-order keys are
currently broken. **Reaching for BFBC2 as a north star while `r4bk` is open is the disease with a
citation.**

---

## 3 · Q2 — "DROP A TREE TO CROSS A FIELD YOU COULDN'T CROSS BEFORE." THIS IS A FANTASY.

The plan stakes the whole feature on this sentence and knows it:
> *"That is a new verb, and it's most of the reason to build this."*
> *"If that isn't fun, the whole feature is decoration."*

**It isn't a verb. Here are five reasons, four of them measured from the shipping code.**

### (a) THE VERB EATS ITSELF. Every felling tool is a bang.
The plan's own damage-wiring list (§2) is the complete set of things that can fell a tree:
**M79 · LAW/RPG · grenade · claymore · CAS · artillery.** There is no saw. No axe. No machete. No timed
charge. **You cannot fell a tree quietly.**

Now recall what the team just shipped: the **witness rule (ADR-005)** and **GUNSHOT audibility raised
55 → 150m** (GAME_GUIDE §8.1). The stealth economy is the crown jewel of this build.

So the verb reads, in full: *"To sneak across ground you couldn't sneak across, first detonate a 40 mm
grenade."* **The cover you build costs you the exact thing you were building it for.** A stealth verb
whose only actuator is the loudest object in the player's inventory is not a verb. It is a contradiction
with a nice sentence wrapped around it.

### (b) There is no field you couldn't cross. The terrain is a heightmap.
The game's world is heightmap terrain. **There are no ravines, no chasms, no unfordable rivers, no
overhangs.** The paddy water in the contract (C1) is `"level": 0.055` — **5.5 centimetres deep.** You can
walk through it in boots.

**There is no impassable ground in RECONgame.** There is only ground you *didn't want* to cross. The
sentence "a field you couldn't cross before" is describing an obstacle **that does not exist in the game.**

### (c) The competing option is free, silent, already shipped, and better.
`scripts/player/player.gd:52` — `PRONE_HEIGHT = 0.5`, and `:94` — `SUPPRESS_DECAY_LOW = 1.3` *("per
second, prone/crouched — **reward getting down**")*. The player can already go prone, at night, in
concealment the density grid already models, for **zero rounds and zero noise.**

The log costs one M79 round (of maybe 8–12 carried), a 4-second reload, and a bang heard at 150 m — and
buys **9.4 metres** of prone cover (C1: `"h": 9.4`). A 40 m paddy therefore costs **four rounds and four
bangs**, i.e. half your basic load and an alerted province, to cross something you could have crawled.

**A verb that is strictly dominated by a free action the player already has is not used. It is
demonstrated once in a trailer.**

### (d) The AI will not use it. The plan's claim is FALSE against shipped code.
Phase 2b asserts:
> *"**Cover for the AI too**, via the existing cover system — enemies will use what you made."*

`scripts/enemies/enemy_base.gd`, `_find_cover_point()`:
```gdscript
var query := PhysicsRayQueryParameters3D.create(
    candidate + Vector3.UP * 1.3, threat_pos + Vector3.UP * 1.0, 1 | 32)
```
**The cover test is a raycast at 1.3 m.** The plan's log is **~0.6 m** ("prone height"). A 0.6 m log
**cannot block a 1.3 m ray.** It will fail the cover test every single time. The AI has no prone state.

**Enemies will walk straight past the log. Every time. Forever.** The one line that sells the log as a
*world* object rather than a *player toy* is wrong, and it is wrong in a way that cannot be fixed without
either (i) building AI prone — not in the plan, not in scope — or (ii) making the log 1.3 m tall, which a
40 cm-diameter bole physically is not.

### (e) So: what percentage of missions use it?
**As a planned play: effectively zero.** As an accident ("huh, that tree fell, I'll lie behind it"):
common, and pleasant, and **entirely satisfied by Phase 1's static trunk collider plus a handful of
hand-placed deadfall props** — which cost a day, not a month.

**The honest, defensible use of a felled tree is the one the plan mentions in passing and does not build
around: dropping it on an enemy position mid-firefight, when noise is already free.** That is a good
moment. It is one moment. It is not a pillar, and it does not justify a shader bitmask, a tree registry,
a fall system, a permanent-log MultiMesh, and six new damage call sites.

---

## 4 · Q3 — PHASE 3 IS THE MOST DANGEROUS PHASE IN THE DOCUMENT. IT DELETES THE THIRD ACT.

Phase 3: *"blowing down the canopy genuinely creates a landable LZ... call the bird into a hole he made
himself. **That is the mechanic.**"*

Read what exfil actually IS today, in `scripts/missions/objectives/exfil_zone.gd`:

- **Exfil is a PLACE.** A fixed point you must physically reach (`:73-77`) with every enemy you woke
  behind you. **The run back to the LZ is the third act of every mission.** It is where "fail forward"
  (Pillar 5) grows its teeth — the heat you generated is the bill, and the walk to exfil is you paying it.
- **`:63-70` — the compromise roll.** Bird inbound, within 160 m, LZ hot → 35 % shoot-down, else wave-off.
- **`:161-193` — the wave-off → `fallback_pos`, and `_is_final = true`.** Your LZ got burned. Now cross the
  AO to a fallback, and **there is no second chance** — the bird commits. That is one of the best pieces of
  design in this codebase.

**Phase 3 sets all of it on fire.**

If the player can manufacture a landable LZ wherever he is standing, then:
1. **The exfil run is deleted.** Finish the last objective → step into the treeline → fire three M79 rounds
   → the bird lands **on the objective.** No run, no heat, no bill. The best twenty minutes of the mission
   is replaced by a reload animation.
2. **The wave-off is toothless.** Waved off? Fine — walk 200 m, blow another hole, call again. The
   `fallback_pos` machinery, `_is_final`, the *"FALLBACK LZ IS YOUR ONLY WAY OUT"* toast — **all of it
   becomes advisory.** You cannot have a *final* LZ in a world where the player prints LZs.
3. **The 35 % shoot-down never fires**, because of a number nobody has looked at:
   `scripts/vehicles/landing_zone.gd:27` — `THREAT_DECAY = 0.1` per second, `threat_level` capped at 1.0.
   **A maximally HOT LZ goes fully COLD in ten seconds.** Today that's survivable because the LZ's position
   is fixed and the enemy comes *to it*. Give the player a movable LZ and the exploit is trivial:
   **kill everything within the 100 m THREAT_RADIUS, count to ten, land anywhere.** The LZ is now always
   cold, by construction. Heat-scaled exfil is over.
4. **It sabotages Pillar 3 by accident.** "Freedom" means *any route, any order* — it does not mean
   *no route*. An exfil you can summon is not freedom; it is a fast-travel button with a grenade launcher
   for a UI.

**And the load-bearing beam under Phase 3 is a P1 bug.** Phase 3 opens: *"Already built and wired — do not
rebuild: `helicopter.gd` ... `insertion_ride.gd`."* It is **not** wired:

> **`RECONgame-a2qb` · P1 · OPEN — "PLAYTEST: player still not seated inside the Huey; two heli models
> visible (green + white)"**

The bird the plan wants to land in a hole you blew **currently renders as two helicopters and the player
cannot sit in it.** `a2qb` is one of the six P1s holding the GATE red. Phase 3 proposes building the second
storey while the first floor is on fire, and it does so by asserting the fire is out.

---

## 5 · Q4 — THE EXPLOIT IS NOT A WALL. IT IS AN ALAMO THE AI CANNOT PATH INTO.

Everyone imagining this exploit pictures a player boxing himself in. He doesn't need to. **He needs four
trees and a knoll.**

Stack the plan's own properties for the permanent log:

| Property | Source | Consequence |
|---|---|---|
| **HARD cover**, layer 1 | Phase 2b | stops bullets |
| layer 1 → grenade `RigidBody3D` masks 1, `_can_damage_multipoint()` raycasts mask 1 | Phase 1, verbatim | **stops grenades AND SHADOWS BLAST** |
| group `"nav_blockers"` + `nav_box` meta → `NavBaker` re-carves | Phase 2b | **the AI's navmesh is carved AROUND it** |
| AI cover test raycasts at **1.3 m**; log is **0.6 m** | `enemy_base.gd` `_find_cover_point()` | **the AI can never use it** |
| **"Do not time it out." Permanent.** | Phase 2b | forever |
| supply: **96 per mission, recycled** | Phase 2b | effectively unlimited |

Compose them. **The player fells four trees into a star around himself and has built a 360° hard-cover
firing position that the AI cannot path into, cannot shelter behind, and cannot grenade.** He did not wall
himself in — he **broke the paths**, which is cheaper and better. Then he farms the QRF from inside it with
an M16 while enemies pile up on a navmesh seam.

- **Pillar 5 (fail forward) requires escalation to have teeth.** *Escalation that cannot reach the player is
  not escalation. It is scenery.*
- **Pillar 1 (death comes from situation, never bullet sponges).** Fine — but the corollary is that the
  *situation* must be able to kill you. A player-built position the AI is architecturally incapable of
  assaulting is the most durable "bullet sponge" in the game, and the sponge is the terrain.

### And the safety valve is worse than the problem

> *"Cap ~96 per mission and recycle the oldest, purely as a safety valve."*

**Recycling the oldest log means the log you are lying behind can vanish because you felled a tree 400 m
away.** The plan spends a paragraph forbidding exactly this:

> *"Cover that evaporates while the player is lying behind it is infuriating and unreadable; a 20-second
> log is a promise the game breaks."*

**The plan breaks its own promise in its own safety valve, four lines later.** A 96-log budget is a
20-second log with extra steps and a worse trigger — because at least a timer is *predictable*.

---

## 6 · Q5 — THE KILLING TREE: THREE FAILURE MODES, ONE OF THEM A SOFT-LOCK

> *"**A falling tree kills.** Sweep its arc on impact and call `CombatManager.apply_explosion_damage()`."*

### (a) It violates the Fairness Law, in writing.
`GAME_GUIDE §1`, **The Fairness Law (binding, DESIGN §4.2)**:
> *"muzzle flash / tracers / vocalizations **always telegraph**."*

A 9.4 m tree on a scripted hinge, arcing over 1.5–2.5 s, killing whatever is beneath it — with **no
warning crack, no shout, no arc preview, no counterplay** — is an untelegraphed instant kill. The plan
specifies the fall, the SFX, the shake, the dust, and the debris. **It specifies no telegraph.** The law
does not carve out "unless the thing killing you is scenery."

### (b) It kills your own squad, permanently, from an arc the player cannot read.
**Pillar 4 — "named persistent teammates who improve, get wounded, rotate home, and die for real."** That
pillar carries the entire emotional payload of the game.

Fall direction is *"away from the blast"* — which is **away from the player** — which is **exactly where
your flanking element is**, because that is where you sent them. Squadmates path autonomously. At 30 m,
through canopy, the player **cannot see where his men are standing** relative to a tree he is about to
drop, and the plan gives him no way to find out.

**I will concede the strongest version of the counter-argument, because it is genuinely strong:** *"I killed
Doc with a tree"* is a **Platoon**-grade story, and Pillar 5 says failure should generate story. Fine. But
**fail forward forgives failure the player chose. It does not manufacture failure out of geometry the
player was structurally unable to read.** A permanent named death from an unpreviewable arc will not read
as tragedy. It will read as **a bug**, and the player will be right, and he will reload — which is the one
thing Pillar 5 exists to prevent (*"Never reload-and-memorize"*).

### (c) THE SOFT-LOCK: a permanent 9.4 m capsule lands on the objective.
This is the one that ships a broken build.

- A felled log is **permanent by explicit decree** ("do not time it out").
- It carries a **capsule collider on layer 1**.
- It is **9.4 m long**, it is dropped by an explosion, and its arc is decided by blast geometry.
- There is **no way to move it. No chainsaw, no despawn, no cleanup.**

So: a log across a **weapons cache**, a **tunnel mouth** (in scope *today* per §6.0!), a **body you must
search**, a **document to grab**, an **interact volume**, or **the LZ you just blew** — can block the
prompt, the approach, or the landing check. **Permanently. In a mission you cannot complete.**

The plan's single best design instinct — *permanence* — is precisely what converts an annoyance into an
**unrecoverable soft-lock class**. And note the cruelty of the ordering: the one recovery mechanism a
lesser design would have had (*let it despawn*) is **explicitly forbidden by the plan, for good reasons.**
There is no version of this where both instincts are right.

Nothing in 355 lines addresses log-vs-objective. Nothing addresses log-vs-LZ. Nothing addresses
log-vs-doorway.

---

## 7 · Q6 — THE OPPORTUNITY COST, AND IT IS OBSCENE

`bd ready`, today. **This is what does not get built:**

| Bead | P | What it is |
|---|---|---|
| `5i8a` | **P0** | **LW-1 GATE: determinism probe — the province must rebuild bit-identical** |
| `6mba` | **P0** | **LW-2 ProvinceState ledger + save migration** |
| `clm4` | **P0** | **LW-3 The firebase moves INSIDE the AO — patrol = walk out the wire** |
| `p3f4` | **P0** | **LW-5 HEARTS AND MINDS: allegiance drives VC manpower (the story engine)** |
| `mhfv` | **P0** | DECREE#2-2 Trust-restoration day: measured perf + two visual P0 root causes |
| `ida9` | P1 | **PLAYTEST R3 — the session entry point. GAME_GUIDE §8 item ZERO.** |
| `r4bk` | P1 | **SQUAD COMMAND CONTROLS ARE GONE.** |
| `a2qb` | P1 | Player not seated in the Huey; two helicopters render. |
| `z90e` | P1 | **Save migration is a LIVE no-op.** |
| `ybf7` | P1 | Campaign is flat; 2 mission types ship 1 objective (canon says 2–4). |

**Four of the five P0s ARE THE SLICE.** `clm4` — *the firebase moves inside the AO, patrol = walk out the
wire* — is the sentence THE SLICE is built out of. `p3f4` is called **"the story engine"** in its own
title. `5i8a` is a **GATE**. These are not nice-to-haves; they are the game.

And then there is the line I want read aloud in the Council:

> ## **`RECONgame-r4bk` · P1 · OPEN — "PLAYTEST: squad command controls gone." F1–F4 do nothing.**
>
> ## **PILLAR 4 IS "THE SQUAD IS THE RPG." THE PLAYER CANNOT COMMAND HIS SQUAD.**
> ## **AND WE ARE DEBATING A SHADER BITMASK FOR FELLING TREES.**

There is a law in this project **named after that bead** — the **r4bk Law**, GAME_GUIDE §1:
> *"A feature without a visible HUD affordance does not exist. Simulation without presentation is
> unfinished work, not shipped work."*

We learned that lesson **twice**, we carved it into the guide, we named it after this exact bug — **and the
bug is still open**, and the proposal on the table is to build a simulation of falling timber.

**The opportunity cost of Phases 2 + 2b + 3 + 4 is: the game.**

---

## 8 · WHAT I WILL NOT ATTACK — and why that makes it more dangerous

Let the record show the Devil's Advocate concedes the following, without reservation:

**This is one of the best engineering documents in the project.**
- The **`COLOR.b` slot / `INSTANCE_CUSTOM.x` bitmask** is genuinely elegant. "Don't touch geometry, flip a
  bit" is the correct insight and it is correctly reasoned (a float32 holds 24 bits exactly).
- The **reuse discipline is exemplary**: *reuse `gib_system`'s debris spawner · **CRATERS: DO NOT BUILD**,
  `DamageSystem` already digs the heightmap · `collision_table` is already the source of truth · support
  graph explicitly deferred.* Most plans in most projects do not say "do not build" once. This one says it
  in a header.
- **It found four real bugs**, and I verified every one of them:
  1. **§0B — `get_density_at` does not exist.** `gameplay_grid.gd:154,:580` call it;
     `clearing_system.gd:266` defines **`get_vegetation_density`**. The guard is **always false**.
     `mark_cleared()` (`:600`) is **called by nothing** — I grepped; the only callers in the codebase are
     `update_region`, from `site_planner.gd:89` and `game_world.gd:376`, and its body never runs.
     **Every LZ in the game is a lie to the AI.** ✅ TRUE.
  2. **§1 — no vegetation in the game has any collision.** ✅ TRUE.
  3. **§2 — `data/weapons/m79.tres:27` `projectile_data_path = ""`.** The player's grenade launcher fires
     a **hitscan bullet**. ✅ TRUE — **and it is worse than the plan says:** `:15` reads
     `base_damage = 150`, while **ADR-016 fixes the M79 at 44**. It is a canon violation *and* a wiring bug.
  4. **§4 — the filename footgun.** `vc_hut_bunker.glb` is soft cover because it contains the substring
     "hut". ✅ TRUE (`site_planner.gd:103` `_is_soft_cover()`).

**And that is precisely why it is dangerous.**

> ### **A bad plan gets rejected on sight. A brilliant plan for the wrong feature is how you lose a year.**

The technical excellence of this document is the *mechanism* by which scope creep would win here. Nobody
gets talked into a year of destructible-jungle work by a sloppy proposal. They get talked into it by one
this good — one that is *right about everything except whether to do it.*

---

## 9 · THE DECREE I ARGUE FOR

### ✅ BUILD — and note that **every item is GATE-EXEMPT as a bug fix.** This is not a coincidence. It is the tell.

| # | Item | Why it is exempt |
|---|---|---|
| **0A** | Run + fix the paddy water/terracing code that was **edited and never executed** | Unrun code on disk is a **bug**, and leaving it is worse than removing it. |
| **0B** | **`get_density_at` → `get_vegetation_density` (2 sites). DO THIS TODAY.** | **A two-token typo fix that repairs every LZ in the game.** Right now `enemy_base._sight_cap()` reports **45 m** in a bald 16 m clearing instead of **140 m** — the AI is *blind inside every LZ we ship.* This is a **Pillar 1 + Pillar 2 bug**, live, today. Ship it with the regression test the plan already specifies. |
| **0C** | Calibration: stand in `patch_tangle`, look 45 m | Free. No code. **Pillar 2.** |
| **1** | **Trunk colliders.** `broadleaf_tree` only (r=0.20). Hard cover, layer 1, nav_source. | **In a jungle game, the tree you dive behind does not stop a bullet.** That is not a missing feature — it is **Pillar 1 (Outstanding gunplay) failing in the single most common cover situation in the game**, and it is the game *lying to the player* about what cover is. **This is the most broken thing in the project.** |
| **2-M79** | `m79.tres`: real `projectile_data_path`, **`base_damage 150 → 44` per ADR-016** | Two bugs, one of them a **canon violation**. Exempt. |
| **4-DATA** | **`collision_table.gd`: add `material` (+`hp` field, unused for now). Demote `_SOFT_NAME_HINTS` to a `push_warning()` fallback.** | **A bunker you can shoot through because its filename contains "hut" is a Pillar 1 bug.** It is a data table. It is cheap. VILLAGE RAID is 1 of the 3 slice mission types, so this lives *inside* the slice. **Do NOT build `Destructible` yet — just make the material honest and make the gaps LOUD.** |

**That is the subset. It is maybe three days. It fixes four real bugs, repairs two pillars, ships zero new
systems, and passes the gate without amending a single ADR.** And note what remains true afterward: **the
jungle now has cover that does not lie.** That is 90 % of what a player would have *felt* from this entire
document.

### ❌ CUT — outright, until THE SLICE is proven
| # | Item | The single reason |
|---|---|---|
| **2** | Destructible trees (bitmask + `TreeRegistry`) | Feature epic behind a **red P0 GATE**. Not in THE SLICE. |
| **2b** | The fall · the killing tree · the permanent log | **The verb eats itself** (§3); **the AI can't use the log** (`1.3 m` ray vs `0.6 m` log); **the killing tree breaks the Fairness Law and soft-locks objectives**; the Alamo exploit (§5). |
| **3** | Player-made LZ | **It deletes the third act of every mission** (§4), voids `fallback_pos`/`_is_final`, and is built on the open P1 `a2qb`. **This is the most damaging idea in the document and it is presented as the payoff.** |
| **4** | `Destructible` component + mesh swap | Feature. **Gated.** *(See below — this is the FIRST thing I would thaw, not the last.)* |

### 🔓 THE FIRST THAW, when the gate goes green
**Not trees. `Destructible` huts (Phase 4 minus the data fix, which ships now).**

Judged strictly by *atmosphere-per-hour* — Pillar 2, and the tonal north star of **Platoon** — a hooch that
takes a grenade and becomes `burned_hut` + rubble is **worth more than every falling tree in this document,
costs a fraction of the machinery** (no shader work, no bitmask, no registry, no fall system, no
navmesh churn), **and the art already exists on disk.** VILLAGE RAID is 1 of the 3 slice mission types.
**The Zippo raid is the iconic image of this war. A tree falling over is not.**

If the Council insists on thawing *something* from this plan the moment the board is green, thaw **that** —
and make the destructible-tree epic **wait behind it.**

---

## 10 · WHAT IS SACRIFICED BY MY OWN RULING (no free lunches — the law applies to me)

I do not get to pretend my verdict is costless.

1. **We give up a genuinely great moment: dropping a tree on a bunker.** It is a real fantasy, it is
   period-correct, and the plan is right that it would be memorable. **I am killing it. I know I am.**
2. **The bitmask insight will rot.** It is elegant, it is in one man's head and one markdown file, and by
   the time the gate is green the vegetation pipeline may have moved under it. **Cost of deferral: this
   plan will have to be partly re-derived.** Mitigation: keep the doc, bead the insight, do not build it.
3. **Trunk colliders are NOT free, and I have argued for them anyway.** ~5 trees/patch × ~40 patches/chunk
   is a large number of new static bodies and `nav_blockers`. **Every AI path, every squad follow, and the
   169 m/min chasing hunt now has to navigate around solid trees for the first time in this project's life.**
   Expect pathing regressions, expect nav-bake cost, expect the hunt to need retuning. **I am accepting a
   real perf-and-pathing bill to buy Pillar 1.** It is worth it — but somebody will spend a week on it, and
   that week is not in anybody's estimate. *(This is the honest counterweight to my own §7: my subset is not
   actually free either.)*
4. **The Blender window is mid-flight.** `patches.json` has *already* had a breaking change land on disk
   (C1: `water` Dictionary → Array), and `trees[]` is being written **right now**. My ruling means the
   `trees[]` array gets produced and then used for **colliders only** — the Blender window will have done
   work whose payoff is deferred. **That is a real cost and a real morale hit, and it must be said out loud
   rather than discovered.** *(It is, notably, not wasted: `trees[]` is exactly the input Phase 1 needs.)*
5. **Somebody will read this ruling as "the Council says no to cool things."** It doesn't. It says the cool
   thing is queued behind the game.

---

## 11 · CLOSING

The plan asks, in its own verification section:
> *"Drop a tree across open ground and use it to cross a field you couldn't cross before. **If that isn't
> fun, the whole feature is decoration.**"*

**I accept the plan's test, and I return its own verdict.**

There is no field you couldn't cross — the terrain is a heightmap and the paddies are 5.5 cm deep. The only
tool that fells the tree announces you at 150 m. The log buys 9.4 m of a 40 m crossing. The AI cannot see
it, cannot use it, and cannot path past it. And the player already has a free, silent, shipped alternative
called **prone**.

**By the plan's own test: it is decoration.**

Beautiful, elegant, well-engineered decoration, in a game where **the squad won't take orders**, **the
Huey renders twice**, **the AI is blind inside every LZ**, and **the province cannot yet remember what the
player did to it.**

> ## **Fix the four bugs. Give the trees collision. Then go build the game.**

---

*Filed by the Devil's Advocate. The Arbiter holds the line, or the line was never there.*
