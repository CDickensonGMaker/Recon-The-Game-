# DEVIL'S ADVOCATE — The Random Grunt Spawner

**Seat:** Devil's Advocate (mandatory, Charter §Council)
**Date:** 2026-07-13
**Query:** "A random grunt spawner that takes the different elements and creates them in different arrangements every time but following to the code of the roles." + "Change the code to fix the model names and not the other way around."

**Everything below is MEASURED, not asserted.** I parsed the six GLB JSON chunks directly. Where the briefing I was handed disagrees with the bytes on disk, **the bytes win and I say so.**

---

## 0. THE HARDEST TRUTH, FIRST

**`us_grunt_rifleman.glb` and `us_grunt_rto.glb` are the same soldier.**

| | rifleman | rto |
|---|---|---|
| live triangles | 7,996 | 7,996 |
| live draw calls | 31 | 31 |
| materials | 28 | 28 |
| weapon mesh | `m16a1_world` | `m16a1_world` |
| radio | `prc25_antenna`, `prc25_handset`, `prc25_pack` | `prc25_antenna`, `prc25_handset`, `prc25_pack` |
| file size | 11,414,248 B | 11,414,236 B |

**Twelve bytes apart.** Identical geometry, identical materials, identical radio, identical rifle.

The RTO gates the **entire fire-support ladder** (ADR-011; `squad_system.gd:is_rto_alive()` → `member_by_mos("RTO")`; `mission_director.gd:228 RTO_RADIO_RANGE = 10.0` — you must be within 10m of the *living* RTO to call anything).

**The single most important man in the squad has no silhouette.** And the council is about to build a machine that *randomizes* him.

---

## 1. SHOULD WE BUILD THIS AT ALL

### The gate ruling

Charter §8 exempts: *"bug fixes, presentation for already-shipped systems, standing-decree items, and evidence-gathering probes/measurements."*

Split the request in two, because it is two things wearing one coat:

| Work | Ruling |
|---|---|
| **Give the shipped MOS system correct, legible bodies** (strip the radio from the five who shouldn't have it; make roles read at silhouette) | **EXEMPT.** This is presentation for a shipped system, and it is a **bug fix** — a live gameplay system (ADR-011 fire support) is currently broken by an art defect. Build it. |
| **A randomizer** — new appearance-generation logic, per-spawn arrangement rules, a variety system | **GATED. This is new feature work.** It is not presentation *of* a shipped system; it is a new system that *generates* presentation. It serves no pillar that is currently bleeding. |

**The council must not let the second ride in on the first's exemption.** That is precisely how ~95 commits of art shipped while decree item 0 sat untouched.

### And the gate gates nothing

`bd list` confirms it: **97u3 blocks only `36pk`, `4i60`, `ooel`.** `k77e` — *THE LIVING WAR*, a **P0 epic** — sits at top level, **unblocked, unlinked**. The GATE is theater. It is a bead with children, not a mechanism. Anyone invoking "the gate allows it" is quoting a law with no enforcement, and anyone invoking "the gate forbids it" is bluffing.

**This is why the Devil's Advocate seat is mandatory: the only thing actually gating this project is whether someone in the room says no.**

### Where the game actually is

- **Decree item 0 — `ida9`, PLAYTEST R3.** Created 07-10. *"NOTHING NEW SHIPS UNTIL IT VERIFIES."* **Never run.**
- **Decree item 1 — the witness rule** (`o18o`). The Charter's own words: *"the biggest single wound... voids Pillar 3's whole economy."* A silent kill still screams YOU'VE BEEN MADE. **Unbuilt.**
- **Decree item 2 — `mhfv`, perf.** *"the top systemic risk."* **No gating FPS number.** Unbuilt.

**Honest ruling:** The Summoner spent today making art and enjoyed it. That is legitimate and I will not sneer at it — it is his hobby and his evening. **But the GAME does not need a variety spawner right now.** The game needs a playtest that has been pending for three days, a stealth economy that currently does not exist, and a frame-rate number that nobody has honestly measured.

**What the game DOES need from today's art is the bug fix — because the art shipped a gameplay bug.** Take that. Leave the randomizer.

---

## 2. THE PERF NUMBER NOBODY HAS

The council is about to add cost to a system it has **never honestly measured.** Here is the number. I am the only one in this room holding one.

### Per-grunt, live (after `ModelActor._apply_gib_rig_contract()` hides donors)

| model | live tris | **live draw calls** | dead-but-shipped |
|---|---|---|---|
| rifleman | 7,996 | **31** | 776 tris / 20 submeshes |
| rto | 7,996 | **31** | 776 / 20 |
| marksman | 5,420 | **33** | 776 / 20 |
| pointman | 4,632 | **33** | 776 / 20 |
| mg | 3,976 | **33** | 776 / 20 |
| grenadier | 3,188 | **29** | 776 / 20 |

### Where a rifleman's 7,996 triangles actually go

| part | tris | share |
|---|---|---|
| **`m16a1_world`** | **5,032** | **63%** |
| `webbing_worn` | 692 | 8.7% |
| `canteen_worn` | 540 | 6.8% |
| `us_grunt_joined` (**the man**) | **434** | **5.4%** |
| `Base_Human` (**a second man**) | **402** | **5.0%** |
| `helmet_shell_worn.001` | 300 | 3.8% |
| `ruck_pack_worn` | 272 | 3.4% |
| **PRC-25 radio** (3 meshes) | **312** | **3.9%** |
| `pouch_belt_worn.001` | 12 | 0.2% |

**The soldier is 5% of the soldier.** The rifle is 63%. The canteen outweighs the man.

### THREE FINDINGS THE COUNCIL DOES NOT HAVE

**(a) The M16 is 5,032 triangles.** The briefing said 2,400. **It is more than twice that** — a baked Bevel modifier, eleven-and-a-half times the 434-tri body it is held by. This is the **free lunch nobody has ordered**: one decimate pass on `m16a1_world` reclaims ~4,600 tris/rifleman at zero gameplay cost. Do this before anything else in this document.

**(b) EVERY GRUNT RENDERS TWO BODIES.** `Base_Human` (402 tris) **and** `us_grunt_joined` (434 tris) both survive the hide contract — `Base_Human` doesn't start with `grunt_`/`cap_`/`head_frag_`, and it isn't in `gib_system.gd:21`'s gear list (`["helmet_camo_shell", "helmet_bugjuice"]`). **It renders.** This is a **new, unbeaded, x1bs-class bug** in the brand-new exports.

**(c) The briefing I was given is wrong about the helmets, and I will say so.** x1bs claims "every grunt renders 2 helmets — STILL PRESENT." **Measured: it is not.** `helmet_bugjuice` and `helmet_camo_shell` are both in the gear list and both get hidden; only `helmet_shell_worn.001` renders. **The helmet half of x1bs appears fixed in code and the bead is stale.** The body half (finding **b**) is live and worse. *If this council had trusted its own briefing instead of measuring, it would have fixed the wrong bug.*

### The firefight

`squad_roster.gd:7` — 5-man squad. `mission_generator.gd:531` — patrols `randi_range(2,4)`. `lazy_group.gd:6` — default 3. Villages garrison more. A contested ville with patrols converging is easily **~15 enemies**.

**5 squad + 1 player + ~15 VC = ~21 characters × ~31 draw calls = ~650 draw calls of PEOPLE ALONE**, before one tree, one hut, one tracer. ~150k triangles of characters.

### And every FPS number this project owns is a lie

`t90s`, measured: **`scaling_3d/scale = 0.77` since commit `c17c1fe`.** The Charter's 19–25 FPS, and `mhfv`'s "40–41 on 4.7" — **every one of them was measured at 77% resolution, and no document says so.** `rendering_method` is **still unset.** There is **still no gating FPS number** — that is `mhfv` item 6, decree item 2, *unbuilt*.

> **THE DEMAND: the number BEFORE the feature.**
> No new per-character cost lands until `mhfv` item 6 ships a gating FPS number measured at **100% render scale**. The Charter's own working agreement (§7): *"Perf first — a gating FPS number beats any feature."* The council is about to violate its own first guardrail, and variety is the **single most anti-perf feature it could have picked**: 28–30 materials per man, per-spawn uniqueness, **zero batching, zero instancing, zero MultiMesh.** Variety is, definitionally, the enemy of the draw-call.

---

## 3. THE RTO MUST BE LEGIBLE (SILHOUETTE BEFORE FLAVOR)

**Measured: `prc25_antenna`, `prc25_handset`, and `prc25_pack` are present on ALL SIX MODELS.** The rifleman, the marksman, the pointman, the machine-gunner, the grenadier — every man in the United States Army is carrying the RTO's PRC-25.

This is not an art nitpick. **An art bug has broken a gameplay system.**

- **ADR-011:** fire support is RTO-gated. Kill the RTO, lose the ladder.
- **`mission_director.gd:228`:** `RTO_RADIO_RANGE = 10.0` — the player must physically stay near the *living* RTO.
- Therefore **the player must be able to protect him** → he must be identifiable at a glance.
- Therefore **the enemy must be able to target him** → he must be identifiable at a glance.
- **Fairness Law (DESIGN §4.2):** the game telegraphs. Always.

**Right now the player sees five radiomen and the enemy sees five radiomen.** The highest-stakes death in the squad is invisible. The tactical texture ADR-011 exists to create — *guard the radio, hunt the radio* — **does not exist in the fiction the player can see.**

### Randomizing this makes it actively worse

The request is to "create them in different arrangements every time." Applied to a squad whose roles are **already visually ambiguous**, randomization is **noise poured on a signal that is already at zero.** You cannot make an unreadable silhouette readable by shuffling it. You make it *less* readable, and you make the bug *harder to see*, because now every wrong-looking man has an alibi: *"that's just the randomizer."*

> **THE LAW I DEMAND: SILHOUETTE BEFORE FLAVOR.**
> A role's read is **load-bearing** and must be **invariant**. Flavor is **decorative** and may vary.
>
> | Layer | Rule |
> |---|---|
> | **INVARIANT (role-bearing)** | The radio is on the **RTO and no one else** — by construction, not by discipline. The M60 is on the pig. The M79 is on the thumper. The medic's bag is on Doc. **The randomizer is FORBIDDEN from touching these.** |
> | **VARIABLE (flavor)** | Helmet cover, face, cigarettes, bug-juice bottle, sleeve roll, canteen placement, grime, boonie-vs-steel-pot. **Randomize freely.** |
>
> A randomizer that can put a radio on a rifleman is not a variety system. **It is a bug generator with a design document.**

---

## 4. WHERE "RANDOM" BREAKS PILLAR 4

**Pillar 4: "The squad is the RPG — named persistent men who improve, wound, rotate home, and die for real."**

`squad_roster.gd:generate_member()` stores the man: `name`, `nick`, `mos`, `st`/`ag`/`al`, `skills`, `skill_uses`, `xp`, `kills`, `missions`, `alive`. **He is persistent DATA.** He is not persistent *flesh* — he has no stored appearance at all.

**Take the request literally — "different arrangements EVERY TIME" — and Doc's face rerolls on every insert.**

- He is not a person. **He is a spawn wearing his own name tag.**
- You cannot mourn a man you have never seen twice.
- Permadeath means nothing if the corpse is a stranger.
- **Pillar 4 is not violated by randomness. It is violated by *impermanence*.** The two are being conflated in the request, and the council must un-conflate them.

**And it breaks the determinism contract too.** ADR-010: one seed per operation. `5i8a`/LW-1: *"the province must rebuild bit-identical."* A per-spawn `randf()` is **unseeded, unreproducible state** injected straight into the render path of a game whose GATE bead is a determinism probe. **The literal request is not merely un-canonical; it is un-buildable under ADR-010.**

### The split that saves it

| Who | Rule | Why |
|---|---|---|
| **YOUR SQUAD** (named, persistent) | Appearance rolled **ONCE at recruitment**, stored as an **`appearance_seed: int`** on the member dict, replayed deterministically forever after. Doc looks like **Doc**, every mission, until he dies. | Pillar 4. ADR-010. |
| **THE ENEMY** (anonymous, disposable) | Per-spawn variety, derived from the **mission seed**. Never the same ville twice; same seed → bit-identical. | Pillar 2 (atmosphere). ADR-010 holds. |

**This is not a compromise. It is the only version that is both what he wants and legal.** He wants variety. Variety belongs to the faceless. **Identity belongs to the named.** One `int` on the member dict buys both.

---

## 5. THE BILL

No decision is free. Here is what every fix on this table costs — **including the ones this council will want to pretend are free.**

### 5.1 The MOS rename — THIS IS A SAVE-BREAKING CHANGE AND NOBODY HAS SAID SO

The Summoner ruled: *"change the code to fix the model names."* Here is what that actually means.

| Code (`squad_roster.gd:7` — **5** slots) | Art on disk (**6** files) |
|---|---|
| `POINT` | `us_grunt_pointman` |
| `RTO` | `us_grunt_rto` |
| `MEDIC` | *(no new model — `us_medic.glb` is a separate, older asset)* |
| `PIGMAN` | `us_grunt_mg` |
| `GRENADIER` | `us_grunt_grenadier` |
| *(no MOS)* | **`us_grunt_rifleman`** |
| *(no MOS)* | **`us_grunt_marksman`** |

**This is not a rename. It is a squad-composition change wearing a rename's clothes.** Executed naively it:

1. **Renames `POINT`→`POINTMAN` and `PIGMAN`→`MG`.** `member["mos"]` is a **persisted string**.
2. **Deletes the MEDIC** (no art in the batch) — who owns `MOS_SKILL["MEDIC"] = "medic"` and the **revive path** (`squad_system.gd`: `_health.revive_handler = self`). **Amputating a live gameplay system to match a filename.**
3. **Adds RIFLEMAN and MARKSMAN** to a fireteam with **five slots and six models**. Charter §5 / ADR-012: *"5-man MOS fireteam."* Growing to six touches `MOS_ORDER`, the F1–F4 order UI, and the save schema. **That is a canon change and requires the Summoner, not a council.**
4. *(Fossil note: `skill_catalog.gd:MOS_SKILL` already carries a dangling `"RIFLEMAN": "small_arms"` that is **not in `MOS_ORDER`** — one of the 79 grandfathered dead symbols under ADR-023.)*

**AND THE SAVE MIGRATION IS A NO-OP.** `z90e`, verbatim: *"campaign_state.gd:202 `_migrate()` is called for real at :183... and its entire body is a `push_warning`. Old saves 'migrate' by doing nothing."* Its own closing line: ***"Write it BEFORE the next save-format change, not after."***

**THIS IS THAT CHANGE.**

Ship the rename without `z90e` and **every existing campaign veteran with `mos = "PIGMAN"` silently**:
- misses `MOS_BODY["PIGMAN"]` → **loses his M60 body**, degrades to a generic grunt
- misses `MOS_SKILL["PIGMAN"]` → **his role skill row orphans**
- returns `null` from `member_by_mos("PIGMAN")` → **forever**

**Pillar 4 says these men persist. The rename quietly kills them and writes a warning to a log nobody reads.**

**One mercy, measured:** `"RTO"` is spelled identically in code and art. `is_rto_alive()` and the fire-support ladder **survive** the rename. That is luck, not design.

> **`z90e` IS A HARD BLOCKER ON THE RENAME.** `bd dep add` it. If the council does not link it, the council has learned nothing from the GATE that gates nothing.

### 5.2 The full bill

| Fix | Cost | **What is sacrificed** |
|---|---|---|
| **Decimate `m16a1_world`** (5,032 → ~400) | One Blender pass | **Nothing. This is the free lunch.** Do it first. |
| **Hide `Base_Human`** (double-body, finding *b*) | One line in `model_actor.gd` — or, per `qnth`, **fix it at the exporter** | Exporter fix is right and slower. In-engine fix is fast and adds a name to a hide-list that will rot. |
| **Strip PRC-25 from 5 of 6** | Re-export 5 GLBs | **An evening of the Summoner's art gets reopened.** He liked today. Say so out loud — this is a real cost, not a rounding error. |
| **MOS rename** | **`z90e` first** (write a real `_migrate`) | **A day of save-migration plumbing before ANY of this lands** — or silent corruption of every veteran. **No third option.** |
| **6 models / 5 slots** | A **Summoner decision**, not a council one | Grow to 6 = ADR-012 + order UI + save schema. Cut one = wasted art. Keep MEDIC on old art = the batch is inconsistent forever. |
| **The spawner itself** | Draw calls, materials, memory | **Perf — the #1 systemic risk — on a system with no honest number.** |
| **Doing all of the above** | The whole session | **`ida9` sits unrun for a fourth day. The witness rule stays unbuilt. Decree items 0, 1, 2 rot for one more day.** *This is the real bill, and it is the one nobody will put on the table.* |

### 5.3 The architecture nobody proposed — and it is what he actually asked for

**Read the request again:** *"takes the different **elements** and creates them in **different arrangements**."*

**HE ASKED FOR A MODULAR KIT.** He did not ask for six monolithic men. **The six GLBs are the wrong shape for the Summoner's own request** — and the measurements prove it: **the six files are ~90% identical geometry**, 11.2–11.4 MB each, **~68 MB** total, with the same 7 textures re-embedded six times, to deliver **one 434-triangle body** and six weapons.

The right build — which is *cheaper*, *more varied*, and *role-legible by construction*:

```
ONE shared body mesh (434 tris, instanced across every grunt in the world)
  + weapon socket      → m16 / m60 / m79 / m70 / ithaca   (role-bound, INVARIANT)
  + radio attachment   → RTO ONLY, by construction        (role-bound, INVARIANT)
  + medic bag          → MEDIC ONLY                        (role-bound, INVARIANT)
  + helmet variants    → cover / bugjuice / cigs / boonie (flavor, RANDOM)
  + face / grime       → atlas index                       (flavor, RANDOM)
```

- **Less memory:** one body, N small props — not six 11 MB near-duplicates.
- **More variety:** combinatorial, not six fixed poses.
- **Role-legible:** *the rifleman cannot have a radio, because the rifleman is not given one.* The bug becomes **structurally impossible** instead of being a thing we promise to remember.
- **Perf-sane:** a shared body mesh is the only version of this that can ever be instanced or MultiMeshed.

**A spawner that shuffles six 11 MB monoliths is not the feature he asked for. It is the feature the current art shape forces on us.** Fix the shape.

---

## 6. THE DEVIL'S DECREE

1. **`m16a1_world` is 5,032 triangles — 63% of a soldier, 11.5× the man it belongs to. Decimate it today.** Free.
2. **Every grunt renders two bodies** (`Base_Human` + `us_grunt_joined`). **New bug, unbeaded.** File it.
3. **The x1bs helmet claim is stale — measured false.** Correct the bead. *This council was one unmeasured assumption away from fixing a bug that was already fixed.*
4. **Every one of the six carries the PRC-25.** An art bug has broken **ADR-011**. **Fix this before anything else, because it is the only part of today's request the GAME actually needs.**
5. **SILHOUETTE BEFORE FLAVOR.** Role-bearing gear is **invariant and randomizer-forbidden**. Flavor is free. A randomizer that can put a radio on a rifleman is a bug generator with a design document.
6. **"Random every time" violates Pillar 4 AND ADR-010.** Squad = `appearance_seed` stored once at recruitment. Enemies = variety from the mission seed. **Identity for the named; variety for the faceless.**
7. **`z90e` blocks the MOS rename.** `bd dep add` it, or silently kill every veteran in every existing save.
8. **6 models, 5 slots. That is a Summoner decision, not a council one.** Do not let a council quietly resize the fireteam to match a filename.
9. **THE NUMBER BEFORE THE FEATURE.** No new per-character cost until `mhfv` item 6 lands a gating FPS number **at 100% render scale**. Every FPS figure this project owns was measured at 77% (`t90s`) and no document admits it.
10. **And when all of that is done — `ida9` is still unrun, four days on, and the witness rule is still unbuilt.** The Charter says *"NOTHING NEW SHIPS UNTIL IT VERIFIES."* **Today would be a fine day to finally obey it.**

---

*The Devil's Advocate ratifies nothing. Every number in this document was measured from the bytes on disk. Where the briefing and the bytes disagreed, I reported the bytes — twice, and in the council's disfavour both times.*
