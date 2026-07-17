# LEVEL DESIGNER / TECHNICAL ARTIST — THE WORLD

**Council:** THE JUNGLE IS NOT PLUGGED IN · 2026-07-13
**Charge:** paddy water, the bunds, what the player feels, the destructible fantasy, the sacrifices.

---

## 0 · CORRECTIONS TO THE BRIEFING (I read the code, not the plan)

Two of the Arbiter's measurements are stale or incomplete. Both change the shape of the answer.

**BREAK 1 IS NOT A BREAK.** `jungle_patch_layer.gd` **already parses the new contract.** Line 127–131
reads `entry["water"] as Array`, `_build_pan_mesh(pans)` loops the list, `half` is read as `[hx, hy]`
rectangular, and `patch_paddy_quad`'s four pans bake into one mesh. `_paddy_open_side()`, the terrace
quantiser, and the paddy-never-skips rule are all live. What is stale is the **doc comment on line 83**
(`## name -> {level, half, at}`) — a tombstone, not a bug. **The pans render.** Bead `en75`'s warning was
heeded; only its comment was not updated.

**BREAK 4 IS BIGGER THAN STATED — AND IT IS THE REAL STORY.** The Arbiter says the patch layer is fed by
`gameplay_grid`. It is not.

> `TERRAIN_WORKFLOW.md` §6 states, as its central claim:
> *"GameplayGrid is the source of truth, and jungle_patch_layer.gd reads it to choose the art… you
> cannot desync them, because you never hand-place vegetation at all."*
>
> **That is FALSE.** `JunglePatchLayer.generate_for_chunk()` is called by `VegetationManager`, which
> passes **its own** `_chunk_terrain` — built by **`VegetationManager._determine_terrain_type()`**
> (`vegetation_manager.gd:299`), a **SECOND, INDEPENDENT CLASSIFIER** with its own patch noise, its own
> RNG, and its own water test. `VegetationManager` holds **no reference to `GameplayGrid` or
> `WaterSystem` at all** (grep: zero hits).

**There are FOUR water/paddy truths in this game, and no two of them talk:**

| # | System | What it decides | Where its "water" comes from |
|---|---|---|---|
| 1 | `TerrainManager.river_paths` + `near_water_mask` | **the ART's** paddies | `RiverGenerator.extract_rivers_fast()` — **gradient descent, NOT D8** — dilated 16 m |
| 2 | `WaterSystem.water_map` | **the GAMEPLAY's** `WATER` cells, the meshes, the wetness texture | Priority-Flood → D8 → accumulation → ponds (**the real hydrology**) |
| 3 | `GameplayGrid.terrain_type` | **the WADE, the drag, the sight cap, the leeches** | **NEITHER.** An elevation lottery. |
| 4 | `patches.json` `water[]` pans | **what you SEE** | Authored, tile-local, `tile_h + 0.055`. Told about nothing. |

The Summoner's instinct is exactly right, and it is worse than he thinks. **The paddies do not inherit
water from the game because nothing in this game inherits water from the game.**

---

## 1 · WHERE PADDY WATER SHOULD COME FROM — **MY RULING**

### The physical truth first

A rice paddy is **not low flat ground.** It is a **machine for holding water**: a farmer cut a terrace,
threw up a **bund** (an earth dyke, 30–50 cm), and fed it from a stream by gravity. It is the single most
**man-made** thing in this AO — more deliberate than a village, because a village can be anywhere and a
paddy **cannot**. A paddy exists at the exact intersection of *someone lives here* and *water can be led
to here.* It is a fingerprint of civilisation on the terrain.

That is why every heuristic in this codebase is wrong. **`height < 5.0 and slope < 0.1` describes a
swamp, not a paddy.** A swamp is where water *ends up*. A paddy is where water was *taken*.

### The three failures, measured

**(a) The riparian belt DELETES exactly the paddies that hydrology justifies.**
`_apply_riparian_belt()` (`gameplay_grid.gd:180`) runs **after** typing, BFS-dilates 22 m out from every
`WATER` cell, and overwrites any cell whose density is below the gallery ramp (**0.55 → 0.95**):

```gdscript
if gallery > vegetation_density[n]:
    vegetation_density[n] = gallery
    terrain_type[n] = HEAVY_JUNGLE / MEDIUM_JUNGLE / LIGHT_JUNGLE
```

`RICE_PADDY` density is **0.2** (`_estimate_vegetation`). **0.55 > 0.2 always.** The belt skips `CLIFF`
and `WATER` — it does **not** skip `RICE_PADDY`.

> **Therefore: every paddy cell within 22 m of a watercourse is converted to jungle.**
> What survives is the `randf() < 0.3` speckle out on the dry ground above 5 m.
>
> **The gameplay grid currently guarantees that paddies exist ONLY where they could never be irrigated.**
> It is a perfect inversion of reality, and it is a two-line consequence nobody wrote on purpose.

**(b) The field is a DITHER, not a field.**
The art's paddy is a per-**8 m-bundle** coin flip: `paddy_chance = 0.7 if near_water else 0.15`. So a
"field" is **30 % holes**, and — worse — `_paddy_open_side()` calls a tile an EDGE if **any** 4-neighbour
is not paddy. With p = 0.7:

- P(interior) = 0.7⁴ ≈ **24 %**
- **≈ 76 % of paddy tiles render as `patch_paddy_edge`** — the TREELINE tile.
- `patch_paddy_quad` — the four-pan tile he is proudest of — appears on **24 % × 1/5 ≈ 5 %** of paddy tiles.

**He will look at his own paddies and see a forest of treelines standing in disconnected puddles, and
almost never the quad.** His art is correct. The *placement* is a coin flip.

*(Sub-bug: the neighbour probe steps **one bundle = 8 m**, but tiles are **12 m**. It asks about a point
inside its own tile's skirt, not the adjacent tile. Even a perfect field would mis-edge.)*

**(c) The pan is 5.5 cm of shader with no depth behind it.**
Pans render at the tile's **terrace-quantised** height + 0.055 m. But `get_water_depth()` reads
`WaterSystem`, which has **never heard of the paddy** → it returns **0.0 everywhere in a paddy.** So:

- Nothing that keys off *depth* can fire in a paddy — no splash, no wade VFX, no capsule drop, no swim.
- `_grid.is_water()` (checked **first** in `_play_footstep_sound`) is **false** in every paddy. The wade
  sound only plays because of a **second, separate** `if t == RICE_PADDY` fallback on the *label*.
- Each tile's sheet sits on **its own** quantised ground, so a field's water **steps tile-to-tile** rather
  than lying as one flat sheet across a terrace. **Water is not flat, and water is the one thing in nature
  that is always flat.**

### ⚖ THE RULING

> **The WaterSystem is the ONE water oracle. It is READ to site the paddy, and it is WRITTEN by the
> paddy. Both — and in that order. A paddy is not a cell type. It is a SITE.**

**Delete the paddy from both classifiers.** No elevation band, no `randf()`, no `near_water` coin flip
picks a paddy ever again. Instead, a **PADDY FIELD PASS** runs once at generation, after `WaterSystem`
and **before** chunk meshing:

**1 · SITE (hydrology permits — the system READS the water).**
Candidate ground = within *N* m of a **watercourse** (`water_map`, the real D8 network — not
`near_water_mask`, which only knows the gradient-descent rivers and is blind to every pond, lake and
swamp), slope under ~4°, above the waterline, below the highland band. **Flood-fill contiguous
polygons.** A field is **3–12 tiles**, one connected shape with a real perimeter — never a dither.
Seeded from the province seed, which **kills the ADR-010 `randf()` violation as a side effect** rather
than as a separate chore.

**2 · STAMP (the paddy MAKES its water — the system WRITES the water).**
Each field terraces to `paddy_terrace_step` (the layer already quantises; now the *ground* does too), and
then **writes back into `water_map`**: the pan cells become water, `get_water_depth()` returns a real
**0.25–0.40 m**, the wetness texture picks it up for free, `terrain_type` = `RICE_PADDY`. **The paddy is
the reason there is water there — exactly like the farmer.** `WaterSystem` remains the single oracle; it
simply gains a **second client that writes into it**, precisely the way `ClearingSystem` already writes
into vegetation density. There is no new source of truth. There is one truth with one more author.

**3 · The riparian belt EXEMPTS the paddy.** One condition. A maintained paddy has no gallery forest in
it — *that is the entire point of a paddy.* The belt should break **around** a field, not through it,
and the treeline it deposits on the field's rim is `patch_paddy_edge` **doing its authored job**: the
paddy meeting the jungle. *The killing ground.*

**4 · The pan's Y comes from `water_system.get_water_level_at()`, not `tile_h + 0.055`.** One flat sheet
per terrace. Water is flat.

**Source of truth, stated once:** the **heightmap** owns WHERE the ground is · the **WaterSystem** owns
WHETHER IT IS WET (and the paddy pass is one of its authors) · the **patch** owns WHAT IT LOOKS LIKE.
`patches.json`'s `water[]` pans stop being a fourth truth and become the **renderer of a fact the
WaterSystem holds.**

---

## 2 · THE BUNDS

### Do they exist?

**As geometry: yes.** `patch_paddy_quad` is cross-bunded into four 2.75 m pans with dry ground between —
he built them.

**As anything the player can touch: no.** Patch meshes are **MultiMesh instances and carry no collision
at all** (`TERRAIN_WORKFLOW.md` §7, the Fairness Law — correct for leaves). The player walks on the
**heightmap**, which is **flat under the whole tile**. The bund is therefore **a painted line on the
floor.** You walk through it. You cannot stand on it, cannot go prone behind it, and cannot tell a wet
pan from a dry dyke by where your feet are — because your feet do not know.

### Why this is a Pillar 3 failure, not a visual one

A paddy with real dykes is a **route decision** — an economy, which is exactly what Pillar 3 demands:

| Route | Speed | Sound | Exposure |
|---|---|---|---|
| **Walk the BUND** | full | dry footfall, no wake | **silhouetted on the only raised line in an open field** |
| **Slog the PAN** | **÷1.8** (55 %) | wade, **noise ×2.2**, leeches | 40 cm lower — **you can go prone** |

That is a genuine, legible, physical trade: *speed and quiet, bought with your silhouette.* Today there
is **no choice at all** — the tile is one flat mud sheet and the player slogs, always. A paddy the player
can only wade is a **punishment**. A paddy with dykes is a **decision**. Pillar 3 says it must be the
second one.

### 🔨 THE FIX — AND IT IS THE HIGHEST-LEVERAGE LINE IN THIS ANALYSIS

> **The bund must be TERRAIN, not a prop. Write it into the HEIGHTMAP at field-stamp time.**

Raise the bund lines **+0.35–0.45 m** and drop the pans **−0.25–0.35 m** below them, in the same pass that
stamps the water — the same way `damage_system` and `clearing_system` already deform the ground.

Everything falls out for free:
- **Collision:** free. It is ground. The trimesh collider cooks it with the chunk.
- **Prone cover:** free. The pan is genuinely lower than the dyke.
- **AI pathing / navmesh:** free. It sees the ground it always saw.
- **The water holds:** free — the pan is *actually* a depression now, so the sheet has a basin.
- **Draw calls added: ZERO. Colliders added: ZERO.**

**Ordering is the sharp edge:** the paddy pass must run **before** chunk meshes are built and colliders
cooked. Run it late and the bunds are ghosts you walk through — the exact bug we are fixing, with extra
steps.

---

## 3 · WHAT THE PLAYER SHOULD FEEL (vs what he feels now)

**The paddy must be the most exposed 100 m in the game.** The thing you stand at the treeline and
*dread*. You look across it, you look at the treeline on the far side, and you decide whether you are
willing.

### What is already right (credit where due)

- **The drag is real.** `player.gd:708` — `current_speed /= 1.8`. **55 % speed.** Good. It is a bog.
- **The noise is real.** `_in_rice_paddy` → `quiet_mult *= 2.2`. You throw a wake and they hear it. Good.
- **The exposure is real** — but *not* via the cover table. Density 0.2 → the sight cap is near-open, so
  the AI genuinely sees you across a paddy. **This works.**
- **The leech is a great instinct.** Wrong implementation (below), right idea.

### What is missing

**(a) No depth. No wake. No splash.** `get_water_depth()` is 0 in every paddy (§1c). There is no water in
the water. The single most-earned image in this game — **a man wading a paddy, dragging a V of ripples
behind him that an enemy can see at 80 m** — is impossible today because the game does not know he is wet.
Ripples that spread from your legs are a **diegetic detection affordance**: it satisfies the r4bk law, it
satisfies the Fairness Law (**the telegraph goes both ways — you can see THEIR wake**), and it is Pillar 2's
best free image. `water_swamp.gdshader` already has `ripple_strength` / `ripple_speed` uniforms and a
`v_shore_distance` varying. **It is one wader position uniform away.**

**(b) NO SHINE. This is the crime.** At night a flooded paddy is a **mirror** — a black field with the
moon lying flat on it, and you a silhouette walking across the moon. `water_swamp.gdshader` has
`specular_strength = 0.15` and **no sky/moon reflection at all.** It is authored as *stagnant swamp muck*
(`muck_intensity 0.4`, `water_color 0.18,0.20,0.12`), which is right for a creek under canopy and
**exactly wrong for a paddy under open sky.** A paddy is not muck; it is a **sheet of sky lying on the
ground.** This is Pillar 2 (Atmosphere), it is the picture on the box, and it costs a uniform and a
reflection term. **Paddy water and swamp water must not share a material.**

**(c) The leech is a step-counter, not a timer, and it has no HUD.** `_wade_timer += 0.5` per footstep and
decays 1.0 per dry step — so it is **40 wet footsteps**, not "20 seconds", and one dry pace-count erases
it. It costs 3 HP and prints a toast. Under the **r4bk law that is not a feature.** The leech should not
be damage; **the leech should be TIME** — you must stop, in the open, and burn them off. That is a
tactical cost in the only place in the game where standing still is fatal. *That* is a Vietnam mechanic.

**(d) `get_cover()` IS A FOSSIL (ADR-023).** `COVER_VALUES` and `DEFENSE_BONUS` are defined in
`gameplay_grid.gd` and **read by nothing** — grep for `get_cover(` returns exactly one file: the one that
declares it. So the paddy's famous "cover 0.1 / defense 0.95" **does nothing.** Concealment comes entirely
from `vegetation_density`. Under the Fossil Law: **triage and delete, or wire it.** It is currently a lie
in the map that reads as load-bearing — the precise failure mode ADR-023 exists to kill.

---

## 4 · THE DESTRUCTIBLE FANTASY — MINIMUM VIABLE

### The point, named

44 trees across 18 patches, each `{at, r, h, th, slot}` + a `tree_ref` with three models. **The `slot`
field means the art already knows which MultiMesh instance a tree occupies** — he anticipated the
hard part.

**The path bug is real but trivial.** `tree_ref` points at `res://assets/models/vegetation/…` (deleted by
`615ddd0`). The files **exist** — I looked: `felled_tree.glb`, `felled_trunk.glb`, `tree_stump.glb` are
all present in `assets/world/vegetation/`. One-line fix in `tools/make_jungle_patches.py:978-980` + regen.

**Now the fantasy, in the order it is worth money:**

1. **The tree I dive behind stops the bullet.**
2. **The tree I dive behind stops *stopping* bullets.** An M60 burst or an RPG chews it down. **This is the
   only reason destruction earns its keep: it turns cover from a FIXTURE into an ECONOMY.** Pillar 3.
3. **The tree that falls becomes new cover.** The trunk lies down; you get prone behind it.
4. Napalm / Arc Light remakes the grove.

### ⚠ THE FANTASY IS #1, AND #1 IS NOT DESTRUCTION AT ALL — IT IS A COLLIDER.

**90 % of the value here is `TERRAIN_WORKFLOW.md` §9(2), and it does not need one line of destruction
code.** Ship that first, alone, and the game is better. Destruction is the *second* increment.

### Minimum viable, priced against 19–25 FPS

**PHASE 1 — TRUNK COLLIDERS ON A ROLLING RING (ship this; it is the whole fantasy).**
44 trees / 18 patches ≈ **2.4 boles per patch.** A 1280 m AO is ~107×107 = **11,400 tiles.** Spawning a
collider per tree across the AO is **~27,000 static bodies. Do not.**

> **Spawn colliders only inside a rolling ring around the player, pooled and recycled.**
> And set the ring radius to **the local sight cap** — *not* a constant.
> - In jungle the cap is **45 m** → ring ≈ (90/12)² ≈ 56 tiles × 2.4 ≈ **135 capsules.**
> - In the open the cap is **140 m** → but open ground **has almost no trees**, so the count stays tiny.
>
> **The lie is therefore never visible: a bullet can only pass through a bole you cannot see.** That is
> elegant, it is cheap, and it is self-balancing. ~150–300 capsules live, recycled on movement. At
> 19–25 FPS the bottleneck is **draw calls and triangles**, not physics bodies. **This is free.**

**PHASE 2 — FELLING, ON A HARD FIFO.**
Each live collider carries `hp` derived from `r`/`th` (a 0.32 m bole ≈ a few hundred rounds; a LAW/RPG
kills it outright). On death: **zero the MultiMesh instance** (`set_instance_transform` with a zero-scale
basis at index `slot` — **costs nothing, adds no draw call**), spawn **one** horizontal `felled_tree.glb`
+ a lying capsule on layer 1. **Global FIFO cap ≈ 24 felled trees**; the oldest recycles to a stump.
**That FIFO cap is the entire perf story of destruction.** Bounded by construction.

### ✂ CUT — this is the gold-plating, name it and kill it

- **RigidBody physics falls.** A tipping animation on a timer is indistinguishable at 25 FPS and costs nothing.
- **Directional falling that hits other trees. Chain-felling.** A year of bugs for one screenshot.
- **Per-branch damage. Splintering VFX. Bark decals.**
- **Persistent felled trees across the whole AO.** The FIFO forgets. Nobody walks back.
- **Writing felled trees back into `vegetation_density` at full fidelity.** Tempting, wrong, and it will
  desync the fourth table.
- **Napalm / Arc Light remaking terrain — DO NOT BUILD THIS.** `ClearingSystem` **already exists and
  already deforms the heightmap and vegetation.** Wire the felled-tree FIFO *to it*. Building a second
  terrain-remaker is how this project gets a fifth source of truth. **(ADR-023: the loser gets deleted.
  Do not create a new one to delete later.)**

---

## 5 · SACRIFICES — no free lunches

1. **HE WILL SEE FEWER PADDIES, NOT MORE.** This is the one he needs to hear. Siting paddies properly
   makes them **rare and deliberate** — near water, near villages. Some missions will have **no paddy at
   all.** That is correct and it is what a province looks like. **The compensation:** the ones he sees will
   be *real fields* — contiguous, bunded, one flat sheet of water — and `patch_paddy_quad` will finally
   appear instead of showing up on 5 % of tiles.

2. **GENERATION ORDER GETS BRITTLE, AND THIS IS THE SHARPEST EDGE IN MY RULING.** The paddy pass must run
   after `WaterSystem` and **before** chunk meshing/collider cooking. Get it wrong and the bunds are
   ghosts — the exact bug we set out to fix, now with a new system to blame. It also lengthens worldgen
   and adds a stage that must be seeded from the province seed or ADR-010 breaks again.

3. **THE BUND WILL BE FAT AND SOFT.** The heightmap cell is **2 m**. A 60 cm dyke cannot be expressed on a
   2 m grid — we will get a **2 m-wide, 0.4 m-high mound.** Believable; not crisp. The alternatives are a
   finer heightmap (perf) or real colliders (the thing I just said not to do). **I accept the fat bund.**

4. **THE BUND GIVES COVER IN THE MOST EXPOSED PLACE IN THE GAME — and that partially undoes the dread I
   just spent §3 demanding.** I accept it **deliberately**: without it the paddy is not a decision, it is
   a punishment, and Pillar 3 forbids that. But the bund must be **BAD** cover — prone-only, 40 cm, and
   **standing on it silhouettes you against an open field.** If the bund ever becomes the safe way across,
   I have failed and it must be cut back.

5. **TRUNK COLLIDERS MAKE THE JUNGLE SLOWER AND CATCHIER TO MOVE THROUGH.** You will bump into trees you
   used to ghost through. Some players will hate it. **It is correct** — cover that does not collide is
   cover that lies, and in an E&E run that lie is a death.

6. **AND THE ONE I CANNOT FIX FROM THIS CHAIR:** as long as **`VegetationManager` and `GameplayGrid` each
   run their own `_determine_terrain_type()`**, the art and the rules will drift **forever**. The paddy is
   merely where the drift became visible. **The real fix is: `GameplayGrid` becomes the sole classifier,
   `VegetationManager` reads it, and VegMgr's classifier is DELETED (ADR-023).** That is a bigger change
   than the paddy and it is not mine to decree — but every paddy fix that leaves two classifiers standing
   is a patch on a fault line, and `TERRAIN_WORKFLOW.md` §6 will still be lying to the next architect who
   reads it.
