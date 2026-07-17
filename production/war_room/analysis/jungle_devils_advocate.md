# DEVIL'S ADVOCATE — THE JUNGLE IS NOT PLUGGED IN

**Convened:** 2026-07-13 · **Seat:** Devil's Advocate · **Law obeyed:** read the code and the data, never the plan.

> ## THE HARDEST TRUTH, FIRST
> **The briefing that summoned this council contains a false P0 finding, and it is false for the exact
> reason this project wrote ADR-023 and the comment-discipline law: the Arbiter read the COMMENTS, not
> the CODE.**
>
> The 07-12 council made the same class of error — it decreed a BUILD item against an array that does
> not exist, because a Game Designer read a *description string*.
>
> **The War Room has now been fooled by prose twice in two days, and the second time it was the
> Arbiter's own briefing.** Everything below is downstream of that.

---

## 0 · THE BRIEFING IS WRONG — BREAK 1 DOES NOT EXIST

The briefing states, as a measured finding, under a heading that says *"the bead PREDICTED this and
nobody listened"*:

> **❌ BREAK 1 — THE PADDY WATER FORMAT.** *"The art shipped the new contract. The parse code was never
> updated."* … *"`jungle_patch_layer.gd:84` — `var _water: Dictionary = {}` — and its own header still
> documents `"water": {level, half, at}`, the **dead** format."*

**This is false. Verified on disk.**

`terrain/vegetation/jungle_patch_layer.gd`:

```gdscript
:125	# Flooded pans, declared by the patch and rendered with the terrain's water.
:126	# A LIST: patch_paddy_quad is cross-bunded into FOUR pans, each its own sheet.
:127	if entry.has("water"):
:128		var pans := entry["water"] as Array          # <-- PARSES THE ARRAY. TODAY.
:129		if not pans.is_empty():
:130			_water[nm] = pans                         # <-- Dictionary is name -> Array[pans]
:131			_water_mesh[nm] = _build_pan_mesh(pans)   # <-- LOOPS the pans
```

And the rectangular `half` the bead warned about — **handled, with a comment saying so**:

```gdscript
:367	# half is [hx, hy] - a paddy that is only wet on one side of the tile has a
:368	# RECTANGULAR pan, not a square one.
:369	var hh: Array = pan.get("half", [6.0, 6.0])
:370	var hx := float(hh[0])
:371	var hy := float(hh[1])
```

And the pans are instanced per chunk (`:320-323`), with their own `water_swamp.gdshader`
(`_make_water_bucket`, `:400`).

**The paddy water contract is FULLY IMPLEMENTED.** `patch_paddy_quad`'s four pans work.
`patch_paddy_edge`'s rectangular pan works. The pans render.

`var _water: Dictionary = {}` at `:84` is a **`name -> pans` map** — the Dictionary is the *container
keyed by patch name*, not the dead per-patch format. The Arbiter saw the word `Dictionary`, saw the
stale header comment at `:10-11` and the stale annotation at `:83`, and inferred a break.

### What is ACTUALLY wrong: two comment lines.

```gdscript
:10	## A patch declares its flooded pan in patches.json ("water": {level, half, at}) and it is
:11	## rendered here with the terrain's own water shader -- one source of truth for water.
:83	## name -> {level: float, half: float, at: [x, y]} for patches that declare a flooded pan.
```

Three lines of stale prose. **They cost this council a P0-shaped finding and a `bd` bead's worth of
credibility.** CLAUDE.md, written *yesterday*, in this repo, says it in one sentence:

> *"A stale CLAUDE.md is not a wrong note — it is a **DRIFT GENERATOR**."*

It is not only CLAUDE.md. **It is any stale comment, including in a war-room briefing.** The comment
purge (`37ob`) is not hygiene. **It is a correctness bead**, and this is its second confirmed casualty
in 24 hours.

**And line 11 is worse than stale — it is a TRUTH-LAW violation on its face:** *"one source of truth
for water."* There are **three** (§4). The comment asserts the exact property the codebase does not have.

---

## 1 · SHOULD WE BUILD THIS AT ALL

**No. And the reason is not the queue — it is that the last council already answered this question and
its answer was never executed.**

### The honest state of the standing decree (Charter §8):

| # | Item | Bead | State, measured today |
|---|---|---|---|
| **0** | **PLAYTEST R3 — "session entry gate; NOTHING NEW SHIPS UNTIL IT VERIFIES"** | `ida9` | **OPEN. Created 07-10. Four days. Never run.** |
| **1** | Stealth/witness bundle — *"the biggest single wound"* | `o18o`→`pwu5` | `o18o` **closed as "Superseded… NOT FIXED"** — the close reason itself says the bug is live at `enemy_base.gd:1821` |
| **2** | Trust-restoration day (perf) | `mhfv` | **OPEN, P0.** Partially done; `rendering_method` still unset; **still no gating FPS number** |
| **6** | Jungle feel pass | `ge6g` | **This request** |

**Item 6 is being asked for while item 0 has never been run, item 1's headline bug is live and its bead
was closed with the words "NOT FIXED", and item 2 — the perf bead — is a P0 that has sat untouched
while the project poured triangles into the thing it says is its top systemic risk.**

This is the **fifth** queue jump. The GATE (`97u3`) is ACTIVE and lists `ida9` among its blockers.

### The classification, honestly:

The request contains **three different things**, and lumping them is how a feature sneaks through:

| Ask | Class | Ruling |
|---|---|---|
| *"is the jungle terrain wired?"* | — | **YES. It is live.** `[JunglePatch] 23 patches across 6 density classes`. Working. |
| *"is the destructible terrain wired?"* | **FEATURE — ALREADY CUT** | **CUT by the 07-12 decree.** See §2. Wiring it is a **thaw**, and a thaw requires a decree, not a question. |
| *"rice paddies should inherit water"* | **PART BUG, PART FEATURE** | The *visual* water already works (§0). The *gameplay* water is a **3-system unification** (§4) sitting on **unseeded `randf()`** (§5). |

**The one legitimately exempt, decree-ordered, already-approved thing in this entire domain is
`2v3t` — TRUNK COLLIDERS — and it is still OPEN.**

> **The 07-12 council told him exactly what to build in the jungle. It was not built. And the answer to
> "is it wired?" is being treated as a new design question instead of an unexecuted order.**

**And the Summoner enjoying the art is legitimate and I will not sneer at it.** He authored 23 patches
and 44 trees and he wants to see them work. That is a real and good motive. **But the GAME does not
need destructible trees this week.** It needs a tree that stops a bullet (`2v3t`), a playtest that has
never been run (`ida9`), and an honest FPS number (`mhfv`/`t90s`). None of those are art. All of them
are already decreed.

---

## 2 · WHAT THE 07-12 COUNCIL ALREADY CUT — AND WHAT IT GOT WRONG

`production/war_room/synthesis_destructible_jungle.md`. Its decree, verbatim:

> **"BUILD THE BUG FIXES. CUT THE FEATURES."**

### ❌ THE CUT LIST — this is what the current request re-thaws

| # | Item | The decree's reason |
|---|---|---|
| **2** | **Destructible trees (bitmask + `TreeRegistry`)** | *"Feature epic behind a **red P0 GATE**. Not in THE SLICE."* |
| **2b** | The fall · the killing tree · the permanent log | *"Fell four trees and you have built a 360° Alamo the AI cannot path into… **Pillar 5, dead.**"* |
| **3** | Player-made LZ | *"**IT DELETES THE THIRD ACT OF EVERY MISSION.**"* |
| **4** | The `Destructible` component itself | *"Feature. Gated."* |

**"Wire the 44 destructible trees" IS item 2.** It was killed 24 hours ago, by a council the Summoner
convened, on grounds that have not changed. **It is additionally blocked by a named, beaded
precondition — `vtiz`, THE CONCEALMENT READOUT** — whose bead says in plain text:

> **"BLOCKS: any thaw of destructible-jungle Phase 2."**

`vtiz` is **OPEN**. **The block is live.** Nothing about today's request satisfies it.

### ✅ THE BUILD LIST — and its execution record

| # | Item | Shipped? |
|---|---|---|
| **0B** | Density **merge** (`min(biome, clearing)`) | ✅ **SHIPPED** — `gameplay_grid.gd:174-177` |
| **VEG** | `clear_area()` must rebuild the patch layer | ✅ **SHIPPED** — `_rematerialize()`, `vegetation_manager.gd:722-731`, one branch |
| **1** | **TRUNK COLLIDERS** — *"THE MOST BROKEN THING IN THE PROJECT"* | ❌ **`2v3t` OPEN** |
| **1b** | **`logs[]` from `patch_deadfall`** | ❌ **THE ARRAY DOES NOT EXIST** |

### ⚠ AND THE 07-12 DECREE'S ITEM 1b IS FALSE — I am not sparing my own predecessors

The decree ordered, as a BUILD item:

> **1b — `logs[]` from `patch_deadfall`** — *"it already exists on disk ('blowdown: crossed logs') with
> **zero collision**… **Prone hard cover ships for one array.**"*

**There is no array.** The string `logs` appears in `patches.json` **exactly once**, and here is the
entire context:

```json
{ "name": "patch_deadfall",
  "desc": "blowdown: crossed logs, ferns colonising",   <-- THIS. A DESCRIPTION STRING.
  "trees": [ {...r:0.364...}, {...r:0.311...} ] }       <-- no "logs" key. anywhere.
```

**The Game Designer read the `desc` field, the Arbiter ratified it into a decree, and "ships for one
array" entered the record as a build order.** `patch_deadfall` has two trees and zero logs.

**That is the same failure as §0. Prose was mistaken for data, twice, by two different councils.**

### ⚠ A second, smaller error in the same decree

The decree celebrates: *"Bamboo and palm get **none** — correct ballistics for free."* Measured: **all 44
entries in `trees[]` have `r ≥ 0.20`.** Zero are below it. **The filter is a no-op** — bamboo was never
*in* `trees[]`. The win is real but it is not a *choice*, and a spec written around a filter that
filters nothing is a spec nobody has checked against the data.

---

## 3 · THE PERF NUMBER NOBODY HAS

**Nobody in this council has a number. I am going to state the arithmetic out loud, because once it is
said, the proposal cannot survive it un-amended.**

### What the jungle ALREADY costs — measured from the shipping constants

`billboard_vegetation.gd:8` — `BILLBOARDS_PER_CHUNK := 3000`. Boot log: **~1400 actually generated per
chunk.** `world_config.gd` — `MAP_SIZE 1280` / `CHUNK_SIZE 256` → **25 chunks**.
`billboard_vegetation.gd:131` — **`plane_count := 5`.**

| | |
|---|---|
| Billboards in the AO | 1,400 × 25 = **35,000** |
| Each is a **5-plane cross** | 35,000 × 5 = **175,000 quads** |
| **Triangles** | **350,000** |
| **…every one of them ALPHA-TESTED** | **This is pure overdraw.** |

**On an Intel UHD iGPU.** Alpha-tested overdraw is the single worst load you can put on a tile-based
integrated GPU — it defeats early-Z, and every layer of leaf pays full fragment cost. **35,000
five-plane alpha cards is a textbook fillrate bomb, and it is already in the build.**

**Add the patch layer on top:** 355 patches/chunk (`(256/12)² × fill_chance 0.78`), each instanced
**TWICE** (near MMI + far MMI, `:303` and `:311`), `probe_jungle_patches` says **2.24M tris worst case**.

### And every FPS number this project owns is a lie about the resolution

```
project.godot:294   scaling_3d/mode=1        (FSR)
project.godot:295   scaling_3d/scale=0.77
```

**0.77 linear = 0.77² = 59.3% of native pixels.** The renderer is drawing **fewer than six pixels in
ten**. `19-25 FPS` (Charter §9) and `40-41 FPS` (`mhfv` notes) were **both** measured there.
Bead `t90s` says it plainly: *"EVERY FPS NUMBER THIS PROJECT HAS EVER QUOTED… WAS MEASURED AT 77%
RESOLUTION, AND NO DOCUMENT SAYS SO."*

**A fillrate-bound scene scales with pixel count.** If the jungle's alpha overdraw is the bottleneck —
and 350,000 alpha-tested triangles on an iGPU says it is — then **40 FPS at 0.77 is roughly 24 FPS at
native.** The project may never have been above 30 at all.

### THE KILLER QUESTION

> **The project is about to add cost to the exact system that is most likely already causing the
> 19–25 FPS — and it has never once profiled that system.**

Not one measurement isolates the jungle. `mhfv` (P0) would have produced the number. **It has sat since
07-10.** `t90s` (the 77% lie) was filed *today* and is untouched.

### The collider bill — measured, not guessed

| | |
|---|---|
| Patches per chunk | (256/12)² × 0.78 = **355** |
| Collider-bearing trees per patch (avg, from `patches.json`) | **1.91** |
| Trunk colliders **per chunk** | **679** |
| **TRUNK COLLIDERS IN THE AO** | **≈ 17,000** |

*(The TD's independent 07-12 estimate was ~14,000. Two methods, same order. **The number is real.**)*

**~17,000 `StaticBody3D` + `CylinderShape3D` pairs = ~34,000 new SceneTree nodes**, in a game that
cannot hit 30 FPS at 59% resolution.

And `2v3t` already carries the warning the last council raised and nobody has answered:

> *"`enemy_base._move_toward()` (:1703) only uses the navmesh **INSIDE NavBaker's 70–140m site
> islands** — across **~95% of the AO** enemies AND **the player's own squad** bee-line on
> `move_and_slide()`. **14k cylinders may grind them.** This is the risk that decides whether Phase 1
> ships as-is."*

**Nobody measured it. The bead says "MEASURE BEFORE SHIPPING" in asterisks. It was not measured.**

### THE HONEST RULING

**MEASURE BEFORE YOU BUILD.** Not as ceremony — as the cheapest possible action:

1. **Set `scaling_3d/scale = 1.0`. Re-measure. State the scale in the number.** *(Minutes.)*
2. **Toggle `use_jungle_patches` off, then `BillboardVegetation` off. Record FPS at each step.**
   *(Minutes. This is the number nobody has: **what fraction of the frame is the jungle?**)*
3. **Set `rendering_method`. Set a gating FPS number.** *(That is `mhfv`. It is item 2 of the decree.)*

**If the jungle is already 60% of the frame, then every line of destructible-tree code written this week
is written on top of the bug.** And if it is *not* — then we finally have the number, and Phase 1 can be
priced honestly for the first time. **Either outcome is worth more than the feature.**

---

## 4 · THE PADDY WATER TRAP

*"Rice paddies should be inheriting water from the game as well."* One sentence. **It is the largest
change in this briefing, and it is disguised as a data fix.**

### THERE ARE THREE INDEPENDENT SOURCES OF TRUTH FOR WATER. VERIFIED.

| # | Source | Owns | Knows about the others? |
|---|---|---|---|
| **1** | **`WaterSystem.water_map`** (`terrain/water/water_system.gd:31`) — `PackedByteArray`, built by `_build_water_map_from_hydrology()` | rivers, lakes, **the wade check**, `get_water_depth()` | **Knows nothing about paddies.** Hydrology does not flood a rice terrace. |
| **2** | **`GameplayGrid.TerrainType.RICE_PADDY`** — a **LABEL** on a 256-cell grid | the **footstep sound**, AI terrain cost, `JunglePatchLayer`'s tile choice | **Not water.** A label. |
| **3** | **`JunglePatchLayer._water[]`** — authored pans, `water_swamp.gdshader`, own MMI | **the visible sheet of water** | **Purely visual. Nothing queries it. Ever.** |

### THE PLAYER STANDS IN A PADDY RIGHT NOW AND THE GAME DISAGREES WITH ITSELF

`player.gd`:

```gdscript
:175	if _grid.is_water(global_position):     # -> water_system.is_water()  == SOURCE 1
:179		if _wade_timer > 20.0:                # LEECHES  <- hydrology only
...
:189	if t == GameplayGrid.TerrainType.RICE_PADDY:
:190		stream = STEP_WATER                   # SPLASH   <- the LABEL == SOURCE 2
```

And `gameplay_grid.gd:409-412`:
```gdscript
func is_water(world_pos: Vector3) -> bool:
	if water_system and water_system.has_method("is_water"):
		return water_system.is_water(world_pos.x, world_pos.z)   # SOURCE 1 ONLY
```

**So today, in a flooded authored paddy, the player: SPLASHES (source 2), SEES WATER (source 3), and
DOES NOT WADE, DOES NOT SLOW, AND CANNOT GET LEECHES (source 1 says dry).** The Summoner is right that
something is broken. **He is wrong about what.** It is not a parse failure — **it is three systems that
have never been introduced to each other.**

### WHY "just make the paddies water" IS NOT SMALL

Unifying them touches, minimum:

- **worldgen** — who decides a paddy is wet? (and see §5 — **`randf()` decides today**)
- **`WaterSystem`** — `water_map` is built *from hydrology*; paddies are *not hydrological*. Stamping
  paddies into `water_map` makes the hydrology map **no longer a hydrology map** — a new fossil-shaped
  lie, straight into ADR-023's teeth.
- **AI** — `is_water` / terrain cost feed pathing and the sight model. Flooding ~every low-slope cell
  changes enemy movement across the AO. **Unmeasured.**
- **Movement + sound + the leech economy** — currently keyed off two *different* sources.
- **The water shader** — source 3 is `water_swamp.gdshader`, source 1 is `water_static.gdshader`
  (`water_system.gd:212`). **Two water shaders.** Unify the data and you now have two renderers for one
  concept: **an ADR-023 fossil the day it ships.**

**And the perf tail:** `is_water()` and `get_water_depth()` become hot per-frame queries against a
larger wet set. Every extra wet cell is a `water_static` quad **and** a `water_swamp` pan, both
transparent, **both fighting the same alpha overdraw budget that §3 says is already the suspect.**

### The trap, stated plainly

> **"Make the paddies wet" is a request to collapse three subsystems into one. It looks like a data fix
> because the *visual* half already works — which is precisely what makes it dangerous. It will be
> scoped as an afternoon and it is a week.**

**The correct minimum move — and it is genuinely small — is the opposite of unification:**
**make `is_water()` also consult the paddy label**, so the player wades where he splashes. One function,
one source consulted, no schema change, no new shader, no worldgen surgery. **That is a bug fix, it is
GATE-EXEMPT, and it delivers the Summoner's actual felt complaint.** Everything past it is a feature.

---

## 5 · DETERMINISM OUTRANKS THE WHOLE JUNGLE

**Yes. It is a bigger deal than the entire destructible feature, and I will argue it as the highest
finding in this council that is not a comment.**

`terrain/core/gameplay_grid.gd` — **the live worldgen path**:

```gdscript
:291	return TerrainType.RICE_PADDY if randf() < 0.3 else TerrainType.GRASSLAND
:478	if randf() < 0.3:   # 30% block chance per cell
```

**Bare, unseeded, GLOBAL `randf()`.** ADR-010: *one seed per operation; the province must rebuild
bit-identical.* `5i8a` — **P0, GATE bead** — says *"Persistence is a LIE unless generation is
bit-identical… **nothing in LW-2+ ships until it is green.**"*

### AND NOW READ LINE 291 AGAIN, WITH TODAY'S REQUEST IN HAND

**Line 291 is the line that decides WHERE THE RICE PADDIES ARE.**

**The Summoner is asking to wire water into the paddies. The paddies are placed by an unseeded coin
flip.**

> **Wire water to `randf()` and you have wired water to a coin flip. The player saves, quits, reloads —
> and the water is somewhere else.**

`5i8a`'s own bead names this exact failure mode:

> *"a province that comes back SUBTLY wrong ('wasn't there a tree here?') is worse than no province at
> all, **and it is a week to find**."*
> *"Get this wrong and **the player comes back to find the WRONG HUT BURNED**."*

**Change one word and it is a description of today's request: the player comes back to find the WRONG
FIELD FLOODED.** And a *destructible* jungle multiplies it — `TreeRegistry` keys on
`instance_idx`, and the instance indices come out of the same nondeterministic grid.

**This is not a tax on the jungle feature. It is a precondition for it, and for `k77e` (THE LIVING WAR,
P0), which is the largest decision this project has made.** `5i8a` is the gate on all of it, it is
**OPEN**, and it is **two `randf()` calls and a `RandomNumberGenerator` away from green.**

**The cheapest P0 in the graph is sitting one afternoon away, underneath the exact feature being
requested, and it has not been done.**

---

## 6 · THE BILL — what every path costs, and what it sacrifices

**No free lunches. The law binds me too.**

### If we do what I recommend

| Action | Cost | **SACRIFICED** |
|---|---|---|
| **Delete 3 stale comments** (`jungle_patch_layer.gd:10-11, 83`) — incl. the false *"one source of truth for water"* | **5 min** | Nothing. **This is the cheapest correctness fix in the project and it already cost us a council.** |
| **Correct the record**: BREAK 1 is false; decree item 1b (`logs[]`) is false | 15 min | **The Arbiter's pride.** Worth it. A canon that carries two invented findings is a canon nobody can trust. |
| **`5i8a` — seed worldgen** (`gameplay_grid:291,478` → owned `RandomNumberGenerator`; `game_flow.gd:184/198`) + the hash probe | **~1 day** | **A different-looking map.** Seeding *changes the world you have been looking at.* Someone will say "the jungle looked better before." **It did not — it was just different, and it was never the same twice.** |
| **`mhfv`/`t90s` — MEASURE** (scale→1.0, jungle A/B toggle, `rendering_method`, gating number) | **~1 day** | **The comfortable 40-41 FPS number.** It will probably become ~24, and that will hurt. **A number that hurts is worth more than a number that lies.** |
| **`2v3t` — TRUNK COLLIDERS**, to the TD spec (one body per subcell, tile scale jitter 0.92–1.10), **and MEASURE the AI-pathing cost** | **~2 days** | **~17,000 colliders of unknown physics cost, and possibly the whole approach** — if 95% of the AO has no navmesh and the squad grinds, Phase 1 does not ship as specced. **That is what measuring is for.** |
| **`is_water()` consults the paddy label** — the Summoner's real complaint, minimally | **~2 hrs** | **The elegant unification.** We get a *correct* game and an *inelegant* map of water. **Correct beats elegant while perf is the top risk.** |
| **`ida9` — RUN THE PLAYTEST** | **1 session** | **A day of building.** It is decree item **ZERO** and it is **four days late.** |

### If we build destructible trees now instead

| | |
|---|---|
| **Cost** | ~17,000 colliders + shader bitmask + `TreeRegistry` + fall system + navmesh churn, **priced against an FPS number that is a lie**, **keyed to instance indices that are nondeterministic**, **blocked by `vtiz` which is OPEN**, **cut by a decree that is 24 hours old**, and **on top of `felled_tree.glb` paths that are dead in the shipped `patches.json`.** |
| **SACRIFICED** | **The gate. The decree. The 07-12 council. And the fifth consecutive confirmation that this project's process does not bind its own Arbiter.** |

---

## THE VERDICT

**The jungle IS wired. The water DOES parse. The pans DO render.** The briefing's headline break is a
stale comment.

**The destructible trees are CUT — 24 hours ago, by a council he called, on grounds that still hold,
behind a block (`vtiz`) that is still open.** Wiring them is a thaw, and a thaw needs a decree.

**The one thing in this domain that IS ordered, IS exempt, and IS unbuilt is `2v3t` — the tree that
stops a bullet.** Build that. Measure it while you build it.

**And before any of it: seed the worldgen (`5i8a`) and get one honest FPS number (`mhfv`/`t90s`).**
Both are P0. Both are ~a day. **Both sit underneath the very feature being asked for.**

> **The Summoner asked "is it wired?" The honest answer is: *mostly — and the last council already told
> you what to fix, and it was not done.***

*The Council advises. The Summoner decides.*
