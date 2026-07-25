# THE PLAN — THE INHABITED WAR AND THE EMPTY WAR

**Drafted:** 2026-07-13 by the War Room · **Reframed by the Summoner:** the 40/60 split is not terrain,
it is **who lives there.**
**Status:** AWAITING RATIFICATION. Nothing below has been built.

---

## THE ROOT CAUSE — and it was never a rice paddy bug

```gdscript
# terrain/core/terrain_engine.gd
enum TerrainPreset {
    ROLLING_HILLS,      # Gentle Vietnam highlands
    STEEP_MOUNTAINS,
    RIVER_VALLEY,       # Low center with ridges     <- never run
    COASTAL_HILLS,      # Gradual slope to flat      <- never run. THIS IS PADDY COUNTRY.
    PLATEAU,            #                               never run
}

func _ready() -> void:
    set_preset(TerrainPreset.ROLLING_HILLS)   # hardcoded. forever.
```

**`set_preset()` is called from exactly one place in the codebase: `terrain_lab.gd`, the dev tool.
THE GAME NEVER CALLS IT.** It takes the `_ready()` default and has never looked back.

**Five terrain types exist. The game has only ever generated one** — *"gentle Vietnam highlands"* —
which is why the map floor is **87.9 m** and why a rice paddy has never once existed.

> **My previous Step 2 — "normalise the paddy band off the elevation range" — is CUT.** It would have
> painted a rice paddy onto a 90-metre hillside. The Summoner would have walked into one and known
> instantly it was fake.

---

## THE SUMMONER'S FRAME: 40 / 60, AND THE 40 IS *INHABITED*

> *"i think a good 40/60 but with the 40 percent of paddy, it doesnt just mean the rice paddies, its
> villages, its sparse jungle. its roads and we have living convoys doing their routines etc"*
> *"civilians on random walks with groups of eachother, evetually well get animals and stuff too"*

**This is not a terrain split. It is two different games out of one engine.**

| | **THE INHABITED WAR (40%)** | **THE EMPTY WAR (60%)** |
|---|---|---|
| **Ground** | delta / coastal plain. Flat. **0–25 m of relief across the whole 1.28 km AO.** | piedmont → highland → Annamite. **60–700 m of relief.** |
| **Water** | at the surface. Paddies are not a label — **they are what the ground IS.** | streams in every draw; creeks under canopy |
| **Cover** | treelines, bunds, hamlet walls. **The paddy itself has none.** | triple canopy. Cover everywhere, sightlines nowhere. |
| **Who is there** | **villagers, families, chickens, convoys on their routines** | nobody |
| **The rule** | **THERE ARE WITNESSES.** You cannot just shoot. Hearts-and-minds (ADR-019) and the witness rule (ADR-005) finally *mean* something. | no witnesses. Stealth is pure. |
| **The fear** | being *seen* | being *found* |

**Pillar 2 — "the war happens with or without you" — has never been true. This is how it becomes true.**

### What already exists (measured — most of the inhabited war is BUILT)
✅ **Villages** (`_plan_village`, VILLAGE_RAID) · ✅ **Civilians** (2–3/hamlet, WANDER/FLEE/COWER, one may
be an **informer**) · ✅ **Chickens** (*"live noise traps"* — the animals have already started) ·
✅ **Campfires at night** · ✅ **Ambient village guards** · ⚠️ **The road BUILDER exists**
(`engineering_system._build_road()` flattens terrain and cuts a surface) — **worldgen never calls it.**
❌ **Convoys: nothing.** ❌ **Civilians wander ALONE**, each to a private target — no families.

---

## STEPS 1–5 · CERTAIN, CHEAP, HEADLESS *(~1 day. Two close P0 GATE beads.)*

| # | STEP | PROOF | SIZE |
|---|---|---|---|
| **1** | **PLAY THE GAME.** `ida9` — decree item **ZERO**, created 07-10, **never run in four days**. Twenty minutes, a real mission, notes. *The boot log printed `0 rice billboards` on every single launch and nobody was at the screen. That is the whole lesson of today.* | Caleb's notes. **Only he can do this step.** | 20 min |
| **2** | **THE AO ARCHETYPE — the root fix.** Derive `LOWLAND` (40%) / `HIGHLAND` (60%) from the operation seed and **`set_preset()` before `generate()`** (`terrain_manager.gd:124`, one line, deterministic). Make **`height_scale` PER-PRESET** (it is a global `280.0` today — even the flat presets get scaled to 280 m). Add the two missing lowland profiles. | `test_ao_archetype`: over 20 seeds, **~40% of maps have a floor under 10 m**, and the LOWLAND relief across the AO is **< 25 m**. | ½ day |
| **3** | **THE PADDY EXISTS — naturally, on ground that is actually flat.** Now that low ground exists, the elevation gate works as authored. **One more line:** add `RICE_PADDY` to the riparian skip (`gameplay_grid.gd:213`) — today `_apply_riparian_belt()` converts any cell within 22 m of water with density < 0.55 into jungle, and **paddy density is 0.2**, so paddies could only survive where they could never be irrigated. | `test_paddy_exists`: **> 0 paddy cells** on a LOWLAND seed (it is **0/65,536** today), and **0** on a HIGHLAND seed. | ~5 lines |
| **4** | **DETERMINISM — a P0 GATE bead goes green for a DELETION.** Delete `gameplay_grid.has_line_of_sight()` (`:448-489`, **zero callers**) — it holds a per-frame `randf()` that poisons the RNG stream the exfil/surrender/escalation rolls draw from, making ADR-010's *"same seed, same war"* **a function of framerate**. Also seed: `gameplay_grid:291`, `civilian.gd:80` (flee-vs-cower!), `damage_system:254,262-265`, `terrain_manager:167` (`noise.seed = randi()`). Delete `poisson_sampler.gd` (124 dead lines). | `test_rng_discipline` + a worldgen **golden hash, UNCHANGED** — proving the deletions are a no-op. Closes **`5i8a`**. | 2 hrs |
| **5** | **DEAD MODEL PATHS + A LOUD GUARD.** `make_jungle_patches.py:978-980` still writes `res://assets/models/vegetation/` — **deleted by the restructure.** Regenerate `patches.json`. Add a `ResourceLoader.exists()` guard that **fails the layer loudly** instead of silently spawning nothing. | `test_manifest_paths`, zero tolerance. **RED before, PASS after.** | 1 hr |

---

## STEP 6 · THE HINGE — and **pre-commit to it before you see it**

| # | STEP | PROOF | SIZE |
|---|---|---|---|
| **6** | **A REAL FPS NUMBER (`mhfv`).** `rendering_method` is **unset**. `scaling_3d/scale = 0.77` → **59% of native pixels** → **every FPS number this project has ever quoted is void.** Set the method, set scale to **1.0**, profile the jungle **by layer** (billboards / patches / water / terrain). **Blender CLOSED** — a contended GPU is another lying number. | **A NUMBER** in canon, stated as *(FPS, scale, renderer, where)*. Layer deltas must **sum to the total** or the harness lies. | ½ day |

| Native FPS | What happens — **decided NOW, or the measurement is theatre** |
|---|---|
| **≥ 45** | Ship 7–10. Amend Charter §9. |
| **30–44** | Trunk colliders ship — measure the AI-pathing cost first. |
| **20–29** | **JUNGLE FEATURE FREEZE.** 8–10 cut. All further jungle work is *subtractive*. |
| **< 20** | **PLAN VOID.** Perf is the only project. |

---

## STEPS 7–10 · GATED ON THE NUMBER

| # | STEP | PROOF | SIZE |
|---|---|---|---|
| **7** | **FOSSIL PROBE LEARNS TO SEE `terrain/`.** `test_fossils.gd:6` is `SCAN_DIRS = ["res://scripts"]` — **my own probe has never looked at the terrain engine.** That is *why* its fossils survived. **AFTER the step-4 deletions**, or every commit goes red and the only exits are a delete-fest or the one forbidden move. | Canary: plant a dead func in `gameplay_grid.gd` → **suite goes RED.** | 30 min |
| **8** | **COMMENT PURGE REACHES `terrain/`.** `jungle_patch_layer.gd:10-11, 83, 316-320` are the exact tombstones that produced a false P0 today. **Stale comments in `terrain/` have now fooled two councils in two days.** | `test_comment_debt` — a shrink-only ratchet. | 1–2 hrs |
| **9** | **ONE CLASSIFIER.** `vegetation_manager._determine_terrain_type()` dies. Today the paddy you would **SEE** and the paddy you would **WADE** are decided by **two different classifiers that share no code.** | `test_one_classifier`: **0 disagreements / 10,000 positions.** | a day |
| **10** | **TRUNK COLLIDERS (`2v3t`) — "the most broken thing in the project."** *The tree you dive behind does not stop a bullet.* `PhysicsServer3D` chunk compounds on Jolt: 25 static body RIDs, **16 shared quantized `CylinderShape3D` RIDs**, `StaticCompoundShape` + BVH, **zero scene-tree nodes** (a `StaticBody3D` per tree = **32,000 nodes** for ~16,000 trees). **`body_set_shape_disabled()`, NEVER `body_remove_shape()`** — it reindexes and invalidates every index. | `test_trunk_collision`: **a ray from 40 m HITS the trunk.** The pillar, as one assertion. | a day |

**DESTRUCTION (the fall) IS NOT IN THIS PLAN.** Cut by the 07-12 council; stays cut. **Cover is the
pillar; destruction is the luxury.**

---

## THE INHABITED WAR — BEADED, NOT IN THIS PLAN

Step 2 builds the *ground* they stand on. These hang off it, and each is its own bead:

- **ROADS AT WORLDGEN.** The builder is written and nobody calls it. Roads are the spine the convoys
  run on and the enemy moves on.
- **CONVOYS ON THEIR ROUTINES.** New — but it is a patrol route on a road with trucks on it, and the
  patrol + lazy-group machinery already exists.
- **CIVILIANS IN FAMILIES.** They wander alone today. Give a family one shared target, orbit it
  loosely, move together. Small change to `civilian.gd`.
- **ANIMALS.** The chickens already exist as noise traps. Water buffalo, dogs, pigs.

---

## THE TRAPS THIS PLAN IS WRITTEN TO AVOID

1. **`is_water()` returns FIRST in the classifier.** Make a paddy wet and it classifies as **WATER, not
   RICE_PADDY** → zero paddies again, brand-new cause.
2. **The plan's slot indexing is OFF BY ONE.** `DESTRUCTIBLE_JUNGLE_PLAN §C2` says `(slot+1)/24`,
   0-based. **The shipped data is `slot/24.0`, 1-BASED.** Follow it literally and **you fell the
   neighbouring tree.**
3. **Two MultiMeshes per bucket** (near + `_far`). Flip one → the tree **vanishes up close and still
   stands at 60 m.**
4. **`water_map` is a 3-bit type + 0.5 m depth quantum**, and the **heightmap cell is 4 m.** *This is
   why the terracing/bund design was cut — it is not representable.*
5. **Widening the fossil probe too early reds the build.** Hence step 7, not step 1.
6. **A windowed FPS bench with Blender OPEN is a lying number — CONFIRMED 2026-07-17.** A jungle A/B ran
   with Blender open reported **GPU 224ms on the LOWEST geometry** (physically impossible) and CPU 3–4×
   baseline. Every future windowed FPS confirm MUST run with **Blender closed** and, for a jungle-GPU
   isolation, a **0-fighter arena** (the 18v18 AI cost — `ai/agents` 25–192ms, a 2026-07-16 figure since RETIRED as attribution-unknown per `production/war_room/2026-07-18_ai_consolidation_plan/synthesis.md:21` — swamps the ~10ms jungle
   signal). Headless-verifiable logic never needs the window; only a final FPS confirm does.

## WHAT IS SACRIFICED

- **The terraced paddy with hand-raised bunds.** Cut — the data structures cannot express it.
- **The felling.** He built it last night. It stays in the box until there is a frame budget.
- **Steps 7–10 may never happen.** That is what the pre-commit ladder *means*.
- **60% of operations will have no villages and no civilians at all** — that is the *point*, and it is
  the cost: the highland AO is deliberately lonely.
- **Step 1 costs him twenty minutes he would rather spend in Blender.** It is still the most valuable
  twenty minutes available, and the project has skipped it four days running.
