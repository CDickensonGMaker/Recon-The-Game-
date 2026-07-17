# GODOT SPECIALIST / TECHNICAL DIRECTOR — THE DESTRUCTIBLE JUNGLE

**Convened:** 2026-07-13 · **Engine:** Godot 4.7 stable, Forward+, **Jolt Physics** (`project.godot:287`)
**Law binding this analysis:** perf is the top systemic risk. I price everything before I design it.

---

## WHICH 4.7 SKILLS I LOADED

| Loaded | Why |
|---|---|
| `~/.claude/architect_knowledge/godot_4.7_features.md` | mandatory; the Summoner's standing order |
| `~/.claude/architect_knowledge/godot_standards.md` | strict typing, PackedArrays, `_exit_tree()` cleanup |
| `GodotPrompter/skills/godot-optimization/SKILL.md` | frame budget, draw calls, physics tuning, pooling |
| `GodotPrompter/skills/physics-system/SKILL.md` | body types, Jolt, shape cost table, **"never scale a collision shape"** |
| `GodotPrompter/skills/procedural-generation/SKILL.md` | seeded RNG law — "AVOID global `randf()`/`randi()`" |

**4.7/4.6 features that are actually load-bearing here** (named, not sprinkled):

1. **Jolt is the non-experimental default (4.6).** This is the feature the whole architecture rests on.
   Jolt puts static bodies in a **separate static quadtree** and compiles a many-shape body into a
   **`StaticCompoundShape` with an internal BVH**. That means *640 cylinder shapes on ONE body* costs a
   log-depth BVH descent per ray, not 640 narrowphase tests. On the old GodotPhysics this bet loses. On
   Jolt it wins. **This is the one I bet on.**
2. **"Import a 3D scene file directly as a single Mesh" (4.7).** Set the import type of
   `felled_trunk.glb` / `tree_stump.glb` to **Mesh**. `JunglePatchLayer._load_patch_mesh()` currently does
   `load() → instantiate() → recursive _first_mesh() → queue_free()` **46 times at boot** (23 near + 23
   far). The fallen-log and stump MultiMeshes must not repeat that dance.
3. **`Tween.tween_await()` (4.7).** Sequences the fall (rotate → await impact → damage sweep → commit log)
   with no callback chain and no manual timer.
4. **Per-axis 3D particle scale/rotation + local billboard alignment (4.7).** The impact dust/leaf burst.
5. **Shader Baker (4.5).** The sway shader gains a new variant. Bake at export or the *first felled tree
   in the mission hitches.*

**A 4.7 feature I am explicitly NOT selling you:** the brief recommends **`IN_SHADOW_PASS`** for vegetation.
**It buys this project ZERO.** Every patch bucket already sets
`cast_shadow = SHADOW_CASTING_SETTING_OFF` (`jungle_patch_layer.gd:434` and `:412`). **The jungle casts no
shadows. There is no shadow pass to skip.** That win is already banked. Also: **Vulkan raytracing (4.7) is
experimental — do not touch it.** And **AreaLight3D is the engine's most expensive light — never, on Intel
UHD.**

---

## 1. THE TREE COUNT — MEASURED, NOT ESTIMATED

### The 44 is not the number. 44 is how many trees he *authored*. The map stamps them ~365× each.

Counted from `assets/world/vegetation/patches/patches.json` and the code that consumes it:

| Fact | Value | Source |
|---|---|---|
| AO | 1280 m, chunk 256 m → **5×5 = 25 chunks, ALL RESIDENT** | `world_config.gd:7-8`; **ADR-013** ("chunk count never changes after `terrain_ready`") |
| tile size | 12.0 m | `patches.json: tile_m` |
| tiles per chunk | `cells = int(256/12) = 21` → **21 × 21 = 441** | `jungle_patch_layer.gd:202` |
| **candidate tiles in the AO** | **441 × 25 = 11,025** | — |
| `fill_chance` | **0.78** | `jungle_patch_layer.gd:59` |
| slope gate | ≤ 26° | `jungle_patch_layer.gd:57` |
| terrain-type gate | CLEAR gets no patch (`TYPE_DENSITY` has no `T_CLEAR`) | `jungle_patch_layer.gd:41-47` |

**Expected trees per placed patch**, derived from the `TYPE_DENSITY` weight pools × the measured per-patch
tree counts:

| terrain type | density pool (weighted) | E[trees] |
|---|---|---|
| GRASSLAND | open, open, light | **1.89** |
| LIGHT_JUNGLE | light, light, medium | **3.00** |
| MEDIUM_JUNGLE | medium ×2, light, dense | **2.75** |
| HEAVY_JUNGLE | dense ×2, wall, medium | **2.25** |
| RICE_PADDY | interior pans 0 trees; only `patch_paddy_edge` carries 2 | **~0.4** |

Weighted over a plausible AO mix → **E[trees | placed patch] ≈ 2.6**.

```
11,025 tiles × 0.85 (placeable type) × 0.78 (fill_chance) × 0.85 (slope pass) × 2.6 trees
```

# ≈ **16,000 STANDING DESTRUCTIBLE TREES IN ONE 1280 m AO.**
# ≈ **646 per chunk.** Sensitivity band: **11,000 – 21,000.**

There is no escape hatch. **ADR-013 says all 25 chunks stay resident for the whole mission** — you cannot
say "only the near chunks pay."

### What that means in physics bodies

| Approach | Scene-tree Nodes | Verdict |
|---|---|---|
| **A. `StaticBody3D` per tree** | 16,000 bodies + 16,000 `CollisionShape3D` = **32,000 Nodes** | **CATASTROPHIC.** At ~1.5–2 kB/node that is **~50–65 MB of pure node overhead**, and at ~15–25 µs per `add_child()`+tree-entry it is **~0.5–0.8 s of dead stall** bolted onto an already-long load. Jolt's static quadtree would actually *survive* 16k static bodies — **the scene tree is what dies, not the physics.** |
| **B. The plan's Phase 1** — one `StaticBody3D` per chunk, one `CollisionShape3D` child per tree | 25 bodies + **16,000 `CollisionShape3D` Nodes** | Halves it, and gives you `shape.disabled = true` for free. Still **16,000 nodes** that exist for no reason but to hold a radius and a transform. |
| **C. `PhysicsServer3D` direct** ← **MY BET** | **ZERO** | 25 body RIDs, **16 shared shape RIDs**, 16k shape *entries*. No `add_child()`, no tree notifications, no `NOTIFICATION_TRANSFORM_CHANGED` plumbing, no group scans. |

---

## 2. THE ARCHITECTURE — WHAT I BET ON, AND WHY THE REST LOSE

### THE BET: `PhysicsServer3D`-direct chunk compounds + a MultiMesh custom-data bitmask.

**Standing collision (Pillar 3 — "the tree you dive behind must stop a bullet", bead 2v3t):**

- **One static body RID per chunk.** `PhysicsServer3D.body_create()`, `BODY_MODE_STATIC`, layer 1
  (`world`), mask 0. **25 bodies in the whole AO.**
- **16 shared `CylinderShape3D` RIDs**, quantized. Measured tree ranges: `r` **0.259–0.427 m**,
  bole `h` **5.84–9.61 m**. Quantize to **4 radius × 4 height buckets** → max radial error **±2.5 cm on a
  30 cm trunk** (imperceptible) and **±0.5 m at the top of the bole** (where the canopy starts anyway).
  **This is why quantization, not scaling** — `physics-system` skill, §5: *"NEVER scale collision shapes.
  Scaled shapes produce incorrect collision results."*
- **`PhysicsServer3D.body_add_shape(body_rid, shape_rid, xform)`** per tree, at chunk build. `xform` is a
  pure translate + yaw (the tile's 90° quarter-turn, applied to the tree's local `at`). **No scale, ever.**
- **~646 shapes per body.** Jolt compiles that to a **`StaticCompoundShape` with an internal BVH**. A bullet
  ray costs one broadphase hit (25 AABBs) + one ~O(log 646) ≈ 10-node BVH descent. **That is cheaper than
  the 16,000-body broadphase, by a lot.**

**Felling a specific tree:**

- **`PhysicsServer3D.body_set_shape_disabled(body_rid, shape_idx, true)`.**
  **NOT `body_remove_shape()`** — removal *reindexes* every shape after it and would invalidate all 16,000
  stored indices in one call. `set_shape_disabled` keeps indices stable forever. This is the whole reason
  the architecture holds together.
- **Cost, named:** Godot's Jolt binding rebuilds the body's compound shape on a shape-disable. A ~646-shape
  compound rebuild is on the order of **0.2–1 ms**. Trees fall a handful of times a mission. **Acceptable.**
  If an airstrike fells 12 at once, **batch the disables and rebuild the compound once.**

**Hiding the standing tree (render side):**

- `mm.use_custom_data = true`; `set_instance_custom_data(i, Color(float(bitmask), 0, 0, 0))`.
- `MAX_TREES = 24` (`make_jungle_flora.py:131`) and a float32 represents every integer up to 2²⁴ **exactly**
  (2²⁴−1 = 16,777,215). **24 bits fit a float32 mantissa with zero slop.** The ceiling is not a guess; the
  Blender lane already `raise`s if a patch exceeds it.
- `vegetation_sway.gdshader` `vertex()`: decode the slot from `COLOR.b`, bit-test the mask, and **collapse
  the vertex to a single point** (`VERTEX = vec3(0.0)`) if its bit is set → every triangle of that tree
  becomes zero-area → rasterizes nothing. **Zero mesh surgery, zero extra draw calls, zero geometry
  upload.** Guard on `COLOR.b > 0.0` so grass, fern, bamboo, rice and liana are untouched.

### 🔴 THE PLAN'S CONTRACT C2 IS **OFF BY ONE**. It will fell the wrong tree.

`DESTRUCTIBLE_JUNGLE_PLAN.md` §C2 says:
> *"`COLOR.b == (slot + 1) / 24.0` → belongs to tree `slot`. `slot` is `0..23`."*

**The shipped data says otherwise.** `tools/make_jungle_flora.py:213`:
```python
b = 0.0 if slot <= 0 else float(slot) / float(Plant.MAX_TREES)   # slot / 24.0
```
and `make_jungle_patches.py:353`: `slot = len(patch.trees) + 1` — **1-based**. Verified in
`patches.json`: **`slot` ∈ [1, 5]. There is no slot 0.**

**THE TRUTH OF RECORD:**
```
COLOR.b == slot / 24.0,  slot ∈ 1..24.   COLOR.b == 0.0 → NOT A TREE.
decode:   int slot = int(round(COLOR.b * 24.0));
bit:      bit index = slot - 1   (bits 0..23)
```
Anyone who implements §C2 literally decodes `slot = round(b*24) - 1`, gets **0..4** where the registry
holds **1..5**, and **fells the neighbouring tree** — while the collider of the tree that visually fell
stays live. **This is precisely the "ships backwards" bug class the Blender lane's own comment warns
about.** Fix the plan document, do not fix the data.

### 🔴 SECOND TRAP THE PLAN DOES NOT MENTION: **there are TWO MultiMeshes per patch bucket.**

`jungle_patch_layer.gd:303` builds a **NEAR** bucket and `:311` a **`_far`** bucket, from the *same* `local`
transform array, so instance indices align — but they are **separate `MultiMesh` resources**. You must call
`set_instance_custom_data()` on **BOTH**, or the tree vanishes when you're close and **is still standing at
60 m.** (And the water bucket at `:321` is a third — leave it alone.) `TreeRegistry` must hold both
`MultiMesh` refs per bucket and `assert` their `instance_count` matches.

### WHY THE ALTERNATIVES LOSE

| Alternative | Why it loses |
|---|---|
| **Zero-scale the MultiMesh instance transform** | **A patch is ONE MERGED MESH** (`jungle_patch_layer.gd:2`: *"Each patch is ONE merged mesh"*). Zeroing an instance deletes the whole **12 m tile** — grass, ferns, bamboo, *and the other four trees*. One RPG would punch a 12 m hole of nothing in the jungle. **This is the exact `clear_area()` bug the council already caught once.** Dead on arrival. |
| **Shape-cast / ray query against the MultiMesh transform buffer instead of real bodies** | You must then intercept **every** physics query: `BulletSystem` aim rays, grenade `RigidBody3D`, `ProjectileData.hits_world`, `CombatManager._can_damage_multipoint()` — **and `CharacterBody3D.move_and_slide()`, which you cannot intercept.** The player would walk through every tree in the game. **Loses on player collision alone.** |
| **`RenderingServer` per-instance culling** | **There is no per-MultiMesh-instance visibility flag** in `RenderingServer`. The only lever is a degenerate transform → see row 1. |
| **`MultiMesh.visible_instance_count`** | Only truncates the **tail** of the buffer. Hiding an arbitrary instance means re-sorting → every instance's index changes → **the custom-data bitmask mapping and every stored `shape_idx` are invalidated on every fell.** Loses. |
| **`RigidBody3D` per tree, sleeping** | 16,000 sleeping bodies still pay broadphase + island bookkeeping, for a body that does nothing until it's felled — and 99.9% never are. Loses. |
| **Lazy / proximity collider activation around the player** | Tempting, and it **fails the pillar.** `enemy_base._sight_cap()` runs to **140 m in the open**. A bullet fired 140 m must be stopped by *every* trunk on its path, not just the ones near the player. With ~30 enemies + squad spread over 1280 m, "trees within 140 m of a combatant" is most of the map — you'd pay nearly full price **plus** a spawn/despawn state machine **plus** a guaranteed bug class where a round passes through a trunk whose collider hadn't materialized yet. **You'd be buying a bug with your savings.** Loses. |
| **Godot 4.7 Vulkan raytracing (BLAS/TLAS)** | The 4.7 brief: *"experimental, not production-ready; ignore for shipping games."* Loses. |

### WHAT THE BET COSTS (say it out loud)

- **RIDs are invisible to the scene tree.** No `Group`, no `set_meta()`, no `queue_free()`. Two consequences:
  1. **You MUST `PhysicsServer3D.free_rid()` every body and shape in `_exit_tree()`** or you leak 25 bodies
     + 16 shapes **per mission**. Under **ADR-010** this is a **MissionScope registration obligation, not a
     nicety.** A static without a MissionScope entry is a defect.
  2. **`nav_baker.gd:241` reads `get_tree().get_nodes_in_group("nav_blockers")`.** RIDs are not in groups.
     → **This is an improvement, not a loss.** NavBaker bakes **per-site boxes**, not the whole AO
     (`nav_baker.gd:80 should_bake()`; header: *"sites != chunks"*). A 60 m site box contains ~65 trees.
     Feed NavBaker a **spatial query into `TreeRegistry`** ("trees inside this AABB") instead of a
     **16,000-node group scan**. Ten lines, and strictly faster than what the plan proposed.
- **The bit-test lands in the game's hottest vertex shader.** See §5.

### STORAGE — PackedArrays, not Dictionaries (`godot_standards.md`, Performance Mandates)

The plan proposes `instance_idx + slot → { hp, world_pos, radius, collider_shape_idx }`. As a
Dictionary-of-Dictionaries that is 16,000 × ~500 B ≈ **8 MB** and a hash lookup per query.
**Parallel `PackedInt32Array` / `PackedFloat32Array` per chunk**: 16,000 × ~40 B ≈ **640 KB**, cache-linear.
**And drop `hp` entirely** — see §3.

---

## 3. THE FALL

### Trees take EXPLOSIVE damage only. They have no HP.

The plan gives each tree hit points. **Don't.** Canon lethality (CLAUDE.md / ADR-016): **M79 HE 150 ·
M26 frag 190 · LAW 250 · RPG-2 250 · RPG-7 290**, versus rifle rounds at **22–32**. A rifle does not fell a
tree, and it should not. So:

- **A tree is felled by, and only by, the explosion path** — `TreeRegistry.damage_area(pos, radius)`,
  called alongside the existing pair at the five sites the plan already identified (`grenade.gd:106`,
  `projectile_base.gd:361`, `claymore.gd:58`, `cas_airplane.gd:140`, `mission_director.gd:381`).
- **Bullets stop at trunks and do not damage them.** This is *honest ballistics* **and it deletes the
  per-bullet registry lookup entirely** — a bullet hitting layer 1 just stops. **That is a free perf win
  and a free simplification.** No HP field, no hit accounting, no 16k-entry HP array.
- Fell threshold: any blast whose damage-at-distance ≥ **~120** at the trunk. M79 and M26 fell in one; a
  rifle never does.

### The fall is a SCRIPTED HINGE, not a RigidBody3D. This is not a style preference — it is ADR-010.

**The log is PERMANENT COVER.** Its final resting transform *persists* and *affects gameplay*. ADR-010 §17:
*"Anything that persists, saves, scores, or affects generation must draw from the seeded stream."* A
`RigidBody3D`'s resting pose is a function of the **physics tick sequence and contact resolution order**,
which under a variable frame rate is **not reproducible**. **A physics-dropped tree is an ADR-010 violation
by construction.** It is also unpredictable (it will eventually launch one into the sky), and a 10 m capsule
with a huge inertia tensor tumbling into a 646-shape compound is expensive contact resolution on a machine
already at 19–25 FPS. **Three independent reasons. Scripted hinge.**

```
Tween on a hinge Node3D pivoted at the tree base:
  axis     = perpendicular to the blast direction, XZ only          <- the player can AIM the fall
  duration = 1.4 + th * 0.08 s                                      <- a taller tree takes longer. Free physics.
  ease     = TRANS_QUAD / EASE_IN                                   <- gravity-shaped
  sequence = tween_property(rotation) -> tween_await(impact) -> damage sweep -> commit  (4.7)
```
**Degenerate case named:** if the blast is dead-centre on the trunk, the direction vector is zero.
**Do not roll for it — hash it:** `hash(chunk_coord ^ inst_idx ^ slot)` → a stable azimuth. Same seed, same
tree, same fall. **Zero RNG draws anywhere in the fall path.**

### `th / 10.0` — the scale contract, verified

`tree_ref.height = 10.0`. Measured `th` across all 44: **8.11 – 13.35 m** → scale **0.811 – 1.335**.
`felled_tree.glb` and `felled_trunk.glb` **MUST** be scaled by `th / tree_ref.height`, or a 13.35 m tree dies
and a stock 10 m one falls over in its place. **`tree_ref.height` is read from the JSON, never hardcoded** —
a hardcoded `10.0` is exactly the fossil ADR-023 was written to kill.

### THE ATOMIC FELL — order matters

1. Set bit `(slot − 1)` in the chunk's per-instance mask → `set_instance_custom_data()` on **BOTH the NEAR
   and the `_far` MultiMesh**.
2. `PhysicsServer3D.body_set_shape_disabled(chunk_body, shape_idx, true)` — the trunk stops stopping bullets
   at the same instant it stops being visible. **Never let those two drift by a frame.**
3. Spawn **`tree_stump.glb`** — as an **instance in a shared stump MultiMesh**, not a node. Every stump in
   the AO = **one draw call**.
4. Spawn the **ONE transient falling `Node3D`** (`felled_tree.glb`, scaled `th/10`).
5. **On impact:** append to the **fallen-log MultiMesh** (`felled_trunk.glb`, scaled `th/10`); `body_add_shape()`
   ONE capsule onto **the same chunk body** (no new body); damage-sweep the arc via
   `CombatManager.apply_explosion_damage()` — **a falling tree kills**; dust + leaf burst; free the transient.
6. Drop `gameplay_grid.vegetation_density` locally; once a radius is clear, call `mark_cleared()`.
   **That is what makes a player-blown LZ real.**

### POOLING / MAX_LIVE

| pool | cap | overflow policy |
|---|---|---|
| **falling transients** | **`MAX_FALLING = 8`** | Beyond 8, **skip the animation and commit the log instantly.** An airstrike can fell a dozen at once; nobody watches 30 trees fall, and 30 concurrent tweens + 30 arc-sweeps is a frame spike. |
| **fallen logs** | **`MAX_LOGS = 128`** | 128 capsules spread over 25 chunk bodies ≈ 5 each — a rounding error — and **ONE draw call for all 128.** On overflow, **retire the oldest log that is > 80 m from every combatant.** If none qualifies, **fell without a log** (tree + stump only). |

**The plan is right that logs must NOT time out.** A 20-second log is a promise the game breaks while the
player is lying behind it. **The 80 m guard is the compromise: nothing ever evaporates in front of a human.**

**AI navigation around logs — the cheapest correct answer is to do nothing.** A settled log is ~0.6 m —
prone height. A soldier steps over it. `NavBaker` only bakes at site boxes anyway, so a log dropped in open
jungle would never trigger a re-bake. **Do not add a `NavigationObstacle3D` per log** — you would be paying
to make the AI *avoid* the cover you want it to *use*.

---

## 4. DETERMINISM — THE BRIEFING'S DIAGNOSIS IS WRONG, AND THE TRUTH IS WORSE

### The briefing says "UNSEEDED GLOBAL RNG." **The global RNG IS seeded.**

`scripts/main/game_flow.gd:184`:
```gdscript
seed(hash(int(offer.get("mission_seed", 0))))
```
That is ADR-010 §15 working exactly as written. **`randf()` at `gameplay_grid.gd:291` draws from the SEEDED
global stream.** Calling it "unseeded" is a misdiagnosis, and fixing the wrong thing would leave the real
break standing.

### The real break: **STREAM-POSITION CONTAMINATION.** ADR-010's promise is *already* false.

A seeded global stream is only reproducible if **the sequence of draws is identical**. It is not.

# 🔴 `gameplay_grid.gd:478` — `randf()` inside `has_line_of_sight()`.

```gdscript
elif cell_type == TerrainType.HEAVY_JUNGLE:
    if randf() < 0.3:  # 30% block chance per cell
        return false
```
**This is a RUNTIME, PER-FRAME, AI-DRIVEN draw sharing the stream with every generation and event roll.**

1. **It poisons the stream.** Every AI LOS check crossing a heavy-jungle cell **burns one draw**. The AI
   thinks on a **0.15 s wall-clock interval** (`CLAUDE.md`, THINK_INTERVAL) — so at **19 FPS you get a
   different number of think cycles than at 60 FPS**. The stream *position* at the moment of any later
   gameplay draw is therefore **a function of framerate**. Which later draws? The ones ADR-010 explicitly
   promises: **exfil-bird shootdown (35%), insertion crash, surrender/crippled rolls, hunter escalation,
   ordnance dispersion.** **ADR-010 §16 — "same seed = same world, same enemies, same EVENTS" — is a
   promise the codebase does not keep, and it has nothing to do with trees.**
2. **It is not idempotent, and that is a live gameplay bug.** Ask the same question about the same two
   points twice, get two answers. An AI re-checking LOS every 0.15 s through a 3-cell heavy-jungle band sees
   the player at **(1 − 0.3)³ = 34% per check** — **fresh roll every time.** That is not "jungle occludes."
   **That is a strobe light.** If jungle LOS has ever felt random and unfair, this is why.

**THE FIX — one change kills both problems.** Replace the roll with a **deterministic hash of the cell
coordinate + a per-mission salt derived from `world_seed`**. Same cell → same answer, forever. Zero RNG
draws. Reproducible. And the jungle stops flickering.

### Every other unseeded/contaminating draw in the worldgen + terrain path

| Site | What | Verdict |
|---|---|---|
| **`gameplay_grid.gd:478`** | `randf()` in `has_line_of_sight()` | 🔴 **P0.** Stream poison + LOS strobe. Hash the cell. |
| **`gameplay_grid.gd:291`** | `randf()` in `_determine_terrain_type()` — `RICE_PADDY if randf() < 0.3 else GRASSLAND` | 🔴 **P0.** *Technically* legal (worldgen may draw from the seeded stream), but **order-fragile**, and it is the line that makes paddies a **coin flip over the entire sub-50 m elevation band** — paddies exist where there is no water. **Derive paddy from the WaterSystem and DELETE the coin flip** (ADR-023: replace a system, bury the old one). |
| **`terrain/core/terrain_manager.gd:167`** | `noise.seed = randi()` in `_generate_fallback_terrain()` | 🟠 **The heightmap seed is drawn from the stream and stored NOWHERE.** If TerrainEngine is ever absent, the world is unreproducible *and* the stream is perturbed. Seed from `world_seed`. |
| **`terrain/core/terrain_engine.gd:215`** | `randomize_seed(): seed_value = randi()`, called by `generate(-1)` | 🟡 Legal **only** because `seed_value` is retained. **Verify `game_world.gd` always passes the mission's `world_seed`.** If it ever calls `generate()` bare, the AO heightmap is a lottery. |
| **`terrain/systems/damage_system.gd:254, 262–265`** | bare `randf()` for decal yaw + scorch scatter | 🟠 Cosmetic, and ADR-010 §17 permits cosmetic `randomize()` — **but these draw from the SHARED stream**, and explosions are player-driven and frame-timed. **A second contamination source.** Move to a dedicated `RandomNumberGenerator` seeded from `world_seed`. |
| **`terrain/vegetation/poisson_sampler.gd:36,37,45,53,54`** | bare `randf()` / `randi()` | ⚫ **FOSSIL.** `audit_dead_code.md`: 3/3 functions dead; the sole reference is an **unused `preload` const** at `terrain_lab.gd:8`. It cannot break determinism because nothing calls it. **Delete it (ADR-023).** It is a loaded gun on the table. |

**THE LAW THIS IMPLIES, and it should be an ADR:**
> **The global RNG stream is reserved for GENERATION and EVENT draws.** Any per-frame, per-query, or
> per-effect draw MUST use a dedicated seed-derived `RandomNumberGenerator` or a pure hash. A runtime draw
> on the global stream is a defect, because it moves the stream under everything that ADR-010 promised.

**The good news:** tree *placement* is already deterministic. `jungle_patch_layer.gd:198` does
`rng.seed = hash(chunk_coord) ^ 0x5EED` — a dedicated, chunk-seeded RNG. **The patch layer is the one file
in this path that already obeys the law.** And **the fall path I specified draws zero RNG.**

### 🔴 AND THE MODEL PATHS ARE DEAD — confirmed on disk

`patches.json: tree_ref` points at `res://assets/models/vegetation/*.glb`.
**`assets/models/` DOES NOT EXIST.** The files are at **`assets/world/vegetation/`** (verified:
`felled_tree.glb` 40 KB, `felled_trunk.glb` 13 KB, `tree_stump.glb` 5 KB, all dated Jul 12).
The dead path is baked into **shipped data**, not just `make_jungle_patches.py:978-980`. **Fix both, and add
a boot-time `ResourceLoader.exists()` assert on every path in `tree_ref` that `push_error`s loudly.** A path
that silently returns `null` is how you ship a jungle with no trees in it.

---

## 5. WHAT DOES IT COST — THE SACRIFICES

### 🔴 THE GATE: **this feature must not ship until there is a gating FPS number.**

**19–25 FPS was measured at `scaling_3d/scale = 0.77`** (`project.godot:295`) — **0.59× the pixels.** At
native that is plausibly **12–16 FPS.** *(And `scaling_3d/mode = 1` is **FSR 1.0**, which spends GPU time to
upscale. Godot 4.7's **nearest-neighbor 3D scaling filter** is both cheaper **and more PSX**. That is the
TD's lane, not mine — but it is free money sitting on the table.)*

**I am proposing to add all of the following to a game with no measured headroom:**

| Cost | Magnitude | Honest assessment |
|---|---|---|
| **A bit-decode + bit-test in `vegetation_sway.gdshader`'s `vertex()`** | ~**1.4 M triangles / ~700 k vertices** of jungle in view (near ≤46 m at ~11 k tris × ~40 patches; far ≤128 m at ~4 k tris × ~240 patches). 3 ALU + one bit test per vertex → **~0.1–0.3 ms on Intel UHD**. | **NOT free.** This is **the single hottest vertex shader in the game** and I am adding work to every vertex of every plant to serve 2.6 trees per tile. It is the cheapest option that exists — but it is not zero, and **it must be measured, not assumed.** |
| **~16,000 static cylinder shapes entering the Jolt world** | 25 compound bodies. Load-time compound BVH build. Memory ~2–5 MB. | Cheap **because it's Jolt.** Would be a different answer on GodotPhysics. |
| **`CharacterBody3D.move_and_slide()` now sweeps a capsule against a 646-shape compound every physics tick** | The jungle had **ZERO collision** before this. **Every player and every one of ~30 enemies now pays a narrowphase descent per tick that they did not pay yesterday.** | **This is the real recurring cost and the plan never names it.** It is inherent to the pillar — you cannot have "the tree stops a bullet" and "the tree doesn't exist to the physics engine." **Must be measured with 30 enemies moving.** |
| **Compound rebuild on fell** | 0.2–1 ms, a few times per mission | Fine. Batch multi-fells. |
| **`TreeRegistry`** | ~640 KB in PackedArrays | Free. **8 MB if someone builds it out of Dictionaries.** |

### THE SACRIFICES, NAMED

1. **The jungle can no longer be walked through.** That is the point — and it is also a **movement-feel
   regression the player will feel immediately.** Sixteen thousand 30 cm cylinders in a jungle you used to
   glide through. **Expect to widen the player capsule's tolerance or to cull colliders from bamboo-only
   patches.** The `trees[]` array is broadleaf-only by design (`record_tree()` refuses bamboo at r=0.03 and
   palm saplings at r=0.045), which is the correct call and buys most of this back — **but nobody has stood
   in `patch_tangle` (4 trees, 21 k tris) and tried to run through it.**
2. **Trees are immune to bullets.** A 200-round belt of M60 will not drop a tree. That is realistic and it
   is a deliberate simplification to delete the per-bullet registry lookup. **It also means the only way to
   make cover is with explosives you have to carry.** Pillar 3 says cover is an economy — **this makes it a
   *scarce* economy.** I think that is right. It is a design call and the game-designer should confirm it.
3. **The physics world is now half-invisible to the scene tree.** 16,000 colliders you cannot click in the
   remote inspector. **Debugging a "the bullet went through the tree" report gets meaningfully harder.**
   Mitigation: a debug draw that dumps the chunk compound to `ImmediateMesh`. Build it *first*, not after
   the first bug report.
4. **`_exit_tree()` becomes load-bearing.** Miss one `free_rid()` and you leak a body per mission, forever,
   and the leak is invisible (no node, no `Object Count` monitor tick). **MissionScope registration is
   mandatory (ADR-010 §19), with a probe.**
5. **The falling-tree animation is a lie, and I am fine with that.** It is a tween, not physics. It will
   clip through a hut. **Accepted:** a deterministic, readable, cheap fall beats a "correct" fall that is
   unreproducible, expensive, and occasionally launches a tree into orbit.
6. **A tree dropped on a slope will float or sink at one end.** The scripted hinge does not conform to
   terrain. Mitigation: sample the heightmap at the log's two ends and pitch the log to match. Cheap. **Do
   it, or every log on a hillside is a visible bug.**

### BUILD ORDER — and the first two are not the feature

> **0. FIX THE DEAD `tree_ref` PATHS** (data + `make_jungle_patches.py`) and add the boot-time
>    `ResourceLoader.exists()` assert. **Nothing below works until this is done.** ~30 min.
>
> **1. FIX `gameplay_grid.gd:478`.** The LOS strobe is a **live shipping bug** poisoning the RNG stream that
>    ADR-010 promises is clean. **It outranks the entire tree feature.** It is a hash, not a roll, and it is
>    a 5-line change that makes the jungle stop flickering AND restores the determinism contract. ~1 hr.
>
> **2. CORRECT `DESTRUCTIBLE_JUNGLE_PLAN.md` §C2** — `slot / 24.0`, 1-based, **not** `(slot+1)/24`.
>    Free. Do it before anyone writes the shader.
>
> **3. GET THE GATING FPS NUMBER.** At **native resolution**, with 30 enemies, standing in `patch_tangle`.
>    Then the trunk colliders, and **measure again.**
>
> **4. THEN, and only then**, the bitmask + the fall.

**If step 3 comes back under 30 FPS, the honest answer is: the trunk colliders ship and the destruction does
not.** Standing trunks alone deliver **Pillar 3's actual promise — "the tree you dive behind stops a
bullet"** — for one MultiMesh-custom-data-free, shader-untouched, zero-vertex-cost change. **Destruction is
the luxury. Cover is the pillar.** Ship the pillar first.

---

## APPENDIX — a correction to the briefing (BREAK 1)

The briefing states `jungle_patch_layer.gd:84` still parses `water` as the dead Dictionary format.
**It does not.** Line 127–131 reads:
```gdscript
if entry.has("water"):
    var pans := entry["water"] as Array          # <- an ARRAY. Correct.
    if not pans.is_empty():
        _water[nm] = pans
        _water_mesh[nm] = _build_pan_mesh(pans)
```
and `_build_pan_mesh()` (`:352`) correctly reads `half` as `[hx, hy]` **rectangular**. `_water` is a
`Dictionary` **keyed by patch name → Array of pans** — that is the right shape, and its type annotation is
what made it *look* stale. **BREAK 1 is already fixed in the code; only the file's own header comment
(`:11`) still documents the dead format.** That header is a **tombstone comment** (CLAUDE.md, COMMENT
DISCIPLINE) and it just cost the Arbiter a false finding. **Delete it.**

**The water parse works. The trees do not exist. Spend the day on the trees.**
