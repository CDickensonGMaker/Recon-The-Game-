# TECHNICAL DIRECTOR — DESTRUCTIBLE_JUNGLE_PLAN review

**Verdict: REWORK REQUIRED before any code is written.**

The Phase 2 shader trick is *technically sound on this renderer*. That is the good news and it is
about the only good news. Three things are wrong at the foundation:

1. **Phase 0B — the plan's flagship "one-word fix" — is a map-wide AI regression, and as written it
   does not even compile.**
2. **The §0 contract (C1/C2) is already wrong on disk.** The plan says slot `0..23` and
   `COLOR.b == (slot+1)/24`. The data says slot `1..5` and the baker writes `slot/24`. Following the
   document literally fells the wrong tree — the exact failure the baker's own error message warns of.
3. **The MultiMesh that Phase 2 writes its bitmask into is destroyed and re-created by the very
   explosions that fell the trees** — and the instance indices the registry keys on are re-shuffled
   in the process. Phase 2's verification test cannot pass against the code that exists today.

Everything below is evidence.

---

## THE NUMBERS (so we stop guessing)

| thing | value | source |
|---|---|---|
| AO | 1280 m | `scripts/levels/world_config.gd:7` `MAP_SIZE = 1280.0` |
| chunk | 256 m | `world_config.gd:8`; 5×5 = **25 chunks, ALL resident** (`terrain_manager.gd:208-226` loads `chunks_per_side²`, no streaming cull at this size) |
| tiles / chunk | `int(256/12)` = 21 → **441** | `jungle_patch_layer.gd:226` |
| fill | `fill_chance = 0.78`, slope cull 26° | `jungle_patch_layer.gd:80-82` |
| trees / patch | avg **2.2**, max **5** (`patch_vine_hall`) | `patches.json` (measured, all 23 patches) |
| **trunks / chunk** | **~570** | 441 × ~0.6 accepted × 2.2 |
| **trunks / AO** | **~14,000** | ×25 chunks |
| renderer | **Forward+** | `project.godot` `config/features=("4.7","Forward Plus")` |
| physics | **Jolt** | `project.godot:283` `3d/physics_engine="Jolt Physics"` |

Note `[rendering] scaling_3d/scale=0.77` + FSR is already on. We are **already GPU-bound and already
paying a resolution tax.** Any proposal that adds permanent per-vertex work is suspect on its face.

---

## Q1 — Does the INSTANCE_CUSTOM bitmask trick actually work in Godot 4.7?

**Yes, on this renderer. With four gotchas the plan does not mention, one of which is fatal.**

### It works
- `INSTANCE_CUSTOM` is a built-in `vec4` in the spatial **vertex** stage (and fragment). Available.
- We are **Forward+** (`project.godot` `config/features`). That is the RenderingDevice path:
  MultiMesh instance data lives in a float SSBO and `INSTANCE_CUSTOM` arrives as highp float32.
  A float32 has a 24-bit mantissa, so integers `0 .. 2^24` round-trip exactly. **The plan's precision
  claim holds — here.**
- It works with the **shared** `ShaderMaterial`. Every bucket in the game uses one
  `material_override` (`jungle_patch_layer.gd:476`, `_material` built once at `:157`). Custom data is
  per-*instance*, not per-material, so nothing has to be un-shared. This is genuinely the trick's
  best property and the plan is right to lean on it.

### Gotcha 1 — flag order. **This will silently do nothing if you get it wrong.**
`MultiMesh.instance_count` **clears and re-sizes the buffer**, and the engine documents that setting
the data format or flags *afterwards* has no effect. `_make_bucket()` currently runs:

```gdscript
# jungle_patch_layer.gd:466-472
var mm := MultiMesh.new()
mm.transform_format = MultiMesh.TRANSFORM_3D
mm.mesh = mesh
mm.instance_count = xforms.size()     # <-- buffer is allocated HERE
```

`mm.use_custom_data = true` **must be inserted before line 470**. Set it after and
`set_instance_custom_data()` errors or no-ops. Same for the far bucket. (The water bucket,
`:443-462`, does not need it.)

### Gotcha 2 — stop claiming 24 bits.
We only need **5** (max 5 trees per patch, `patch_vine_hall`). The "24 bits is exact in a float32"
line is true of the current Forward+ SSBO path but it is an *engine internal*, not an API guarantee,
and it would **not** survive a fallback to `gl_compatibility` — which, on an Intel UHD target running
Vulkan Forward+, is a fallback we may well need. **Cap the design at 8 bits, document it, and the
question never has to be answered.** A one-off round-trip test (write `2^23`, read it back in a
shader) is 20 minutes and I would rather have it than the assertion.

### Gotcha 3 — the guard must be on `INSTANCE_CUSTOM`, not just `COLOR.b`.
`vegetation_sway.gdshader:27-49` `vertex()` runs on **every vegetation vertex in the game** — grass,
fern, rice, bamboo, liana. Adding an unconditional slot decode there is the wrong place to spend ALU
on a GPU that is already at 0.77 render scale. Gate on the *mask* first:

```glsl
if (INSTANCE_CUSTOM.x > 0.0 && COLOR.b > 0.0) { ...decode, sink... }
```
The mask is `0.0` for essentially every instance in the world, so the branch is taken almost never
and is perfectly coherent across a whole draw. Cheap. Guarding on `COLOR.b` alone (as the plan says)
still pays the decode on every tree vertex, forever, even in a chunk where nothing has been felled.

### Gotcha 4 — **THE FATAL ONE. The bitmask must be applied to TWO MultiMeshes, not one.**
Every bucket emits a **NEAR** and a **FAR** `MultiMeshInstance3D` over the *same* instance list:

```gdscript
# jungle_patch_layer.gd:341-351
nodes.append(_make_bucket(..., _mesh[nm],     local, centre, 0.0, near_distance))
if _mesh_far.has(nm):
    nodes.append(_make_bucket(..., _mesh_far[nm], local, centre, near_distance, view_distance))
```

The far twin is *structure-only* — which means **the trees are in it** (`far_tris` is non-zero for
every tree-bearing patch), and `make_jungle_patches.py:149` explicitly re-indexes `far.tree` so the
far mesh carries a correct `COLOR.b`. So: flip the bit on the near MultiMesh only, and **the felled
tree pops back into existence the moment the player walks 46 m away** (`near_distance`, `:95`).

`TreeRegistry` must hold *both* MultiMesh handles per bucket and write the mask to both. The plan's
registry schema (`instance_idx + slot → {...}`, plan line 169) has no room for this.

---

## Q2 — One StaticBody3D per chunk with many CylinderShape3D children. Is it cheaper?

**In the steady state: yes — but only because we are on Jolt, and the plan does not know that's why.
In the mutation case — which is the entire point of Phase 2 — it is actively worse.**

### Why it's true (steady state)
`project.godot:283` = `"Jolt Physics"`. A Jolt body with >1 shape becomes a **StaticCompoundShape**,
which has its own internal BVH — so a ray into the body is O(log n) over its sub-shapes, and the
broadphase holds 25 bodies instead of 14,000. Good.

**Had we been on GodotPhysics this claim would be exactly backwards** (its ray test loops a body's
shapes linearly, so one 570-shape body means every bullet crossing the chunk does 570 shape tests
instead of the ~1 a per-trunk broadphase would give). The plan asserts the conclusion without the
premise. If anyone ever flips that setting, Phase 1 becomes a performance bomb with no warning.

### Why it's wrong (mutation)
**A Jolt compound shape is immutable.** Setting `CollisionShape3D.disabled = true` on one child forces
Godot's Jolt layer to **rebuild the entire compound — all ~570 sub-shapes — and re-insert it into the
broadphase.** Phase 2 disables exactly one trunk shape per tree death. A napalm run or a CBU that
fells 15 trees in a chunk = **15 full 570-shape rebuilds in a single frame.** That is a guaranteed
hitch, and it is caused by the very optimisation the plan chose to make things fast.

### Also: you cannot tell which tree you hit
`intersect_ray()` returns the **body** as `collider`. With one body per chunk, "which trunk did this
round hit?" has to come from `result.shape` (the shape index). That works — but **shape indices
renumber if a shape is ever removed.** So the rule is: *only ever disable, never `remove_child()` a
trunk `CollisionShape3D`* — and nothing in the plan says so.

### The fix is already sitting in the file
`jungle_patch_layer.gd:94` — `subcell_meters = 36.0`. The layer **already** buckets every tile into a
subcell (`:315-316`) and already emits one MultiMesh per `(subcell, patch_name)`.

**Put one StaticBody3D per SUBCELL, not per chunk.**
- 256/36 → 7×7 = **49 subcells/chunk**, ~11-12 trunks each.
- A tree death rebuilds a **12-shape** compound, not a 570-shape one. Non-event.
- Broadphase AABBs are 36 m, not 256 m — much tighter culling for every bullet in the game.
- ~1,225 static bodies AO-wide. Jolt eats that without blinking.
- **And the body maps 1:1 onto the MultiMesh bucket**, so `TreeRegistry` gets its key for free.

### One more, and it's a real bug
Phase 1 says "Transform each tree's local `(x, y)` by its tile's `Transform3D` — it inherits the
tile's 90° yaw." It **only mentions the yaw**. The tile also gets a **scale jitter**:

```gdscript
# jungle_patch_layer.gd:296
xf = xf.scaled(Vector3.ONE * rng.randf_range(0.92, 1.10))
```

Ignore it and a trunk at the tile edge is displaced by up to `6.0 × 0.10 = 0.6 m` — **larger than the
tree is wide (r = 0.20).** The collider misses the tree entirely: you shoot through the trunk and
your grenade bounces off thin air next to it. Build the collider from the **full** `Transform3D`,
scale included, and scale `r` and `h` by it too.

(Related: `tile_jitter` at `:76` is **dead code** — declared, never used — and the doc comment at
`:71-75` claims free rotation while `:290` does 90° steps. Whoever implements Phase 1 off those
comments will build the wrong transform.)

---

## Q3 — Trunks on layer 1 block bullets, grenades, AOE probes AND AI LOS. Is that all desirable?

Mostly yes. **One of them breaks the game.**

### Bullets — fine, that's the point.
`BulletSystem` masks 1. A trunk stops the round. Correct.

*But not `hard_surface`.* `bullet_system.gd:179-186` → `GunFX.impact(..., hard)` at `:163` → **sparks**.
`gun_range.gd:29` records that `hard_surface` has had **zero members in the entire game**, so trunks
would be its first — and **a bullet hitting a tree would throw sparks.** The plan explicitly asks for
this ("Put trunks in `hard_surface` for the spark impact FX and nothing else"). **Don't.** Leave them
out (the dirt-puff fallback reads far closer to wood chips) or add a third `wood` case.

### Grenade RigidBody — desirable, but it makes the collider bug above *unforgivable*.
A collider offset from the visible tree is cosmetic when only rays hit it. The moment grenades bounce
off it, a 0.6 m misalignment is a player bouncing a frag off *nothing* and eating it. See the scale
jitter.

### `_can_damage_multipoint()` — a cliff, not a falloff.
`combat_manager.gd:210-241` probes **8 points within ±0.3 m** of the target and masks layer 1. A 0.4 m
bole directly between blast and man can occlude **all eight** → the grenade does **exactly zero**
damage. Not reduced. Zero. Real frag sprays around a trunk. This is the plan's stated intent
("the trunk shadows the blast") but the implementation it lands on is binary. It should be a decree,
not a side-effect: either widen the probe offsets or convert the gate to a fractional reduction.

### AI line-of-sight — the *intent* layer survives; the *firing* layer will stutter.
`CombatManager.has_line_of_sight()` (`combat_manager.gd:306-317`) is a **single ray**, eye+1.5 →
target+1.0, mask 1. 14,000 trunks will flicker it constantly.

**The AI is already hardened against exactly this**, and whoever wrote it saw this coming:
`enemy_base.gd:1016-1026` debounces LOS into `contact_conf` (fills in 0.3 s, drains over 2.0 s) with
the comment *"LOS flicker can no longer flip a decision; only FIRING reads the raw boolean"*, and
`:1014` drains the exposure clock at 3× instead of hard-resetting for *"brief foliage blinks"*. Goals
will hold. Firing (`:1557, :1577, :1598, :1617, :1630` — all gate on the raw `has_line_of_sight`) will
stutter around trunks, which is arguably correct.

### But: we are now denying LOS **twice**, with no test.
`enemy_base._sight_cap()` (`:626-634`) already lerps `SIGHT_CAP_OPEN 140m → SIGHT_CAP_JUNGLE 45m`
straight off `vegetation_density`. That number **already models "the jungle blocks sight"**,
statistically. Phase 1 adds a **second, independent** physical denial on top of it. In heavy jungle
the enemy is capped to 45 m *and* now has ~2 boles per 12 m to shoot past inside that 45 m.
**Phase 1 silently retunes AI lethality across the entire game and there is no test for it.**
0C proposes calibrating the *art*. Calibrate the *stack-up*.

### ▲ AND HERE IS THE ONE THAT ACTUALLY BREAKS: **AI locomotion.**

`enemy_base._move_toward()` (`:1689-1720`) uses the navmesh **only when the agent AND the destination
are inside the same baked NavBaker box** (`:1703`). And NavBaker only bakes **70–140 m islands around
stamped sites** (`nav_baker.gd:28-30, 80-88, 109-111`) — it says so itself at `nav_baker.gd:18-21`:
*"NAMED TRADEOFF: no long-range pathfinding. An enemy 300m out in open jungle bee-lines."*

**So across ~95% of the 1280 m AO — i.e. the jungle — every enemy and every ally steers in a straight
line and relies on `move_and_slide()` to cope.** That works today for exactly one reason: **nothing in
the vegetation is solid.**

Drop 14,000 solid cylinders into that and:
- every enemy chasing you through jungle grinds along tree trunks;
- **your entire squad, following you, smears through the bush**;
- in a `patch_vine_hall` (5 boles per 12 m tile) or `patch_tangle` (4), agents wedge between trunks.

`NavigationAgent3D` avoidance is **agent-vs-agent**; it does not see static geometry. `_update_unstick()`
(`enemy_base.gd:152-155`) is a blunt sidestep timer, not obstacle steering. **The plan does not mention
this at all, and it is the single most likely "this feels broken" outcome of Phase 1.**

Mitigations, cheapest first: (a) give trunks a **separate physics layer** and have bullets/grenades
mask it but AI *bodies* not — you get ballistic cover without locomotion cost, at the price of
walking through trees; (b) keep layer 1 but add a short whisker-cast to `_move_toward()` that steers
around the nearest trunk; (c) bake nav over the whole AO — expensive and explicitly rejected already.
**(a) is the honest MVP and it is a design call, not a technical one. It must be made before Phase 1
is written.**

---

## Q4 — Is there a simpler approach the plan missed?

**Yes, and the plan is already building the asset it needs.**

### Stop baking the destructible trees into the patch mesh. Give them their own MultiMesh.

The plan's own §C3 has the Blender window producing `felled_tree.glb` — *"the full standing broadleaf
as a **standalone** mesh (today it only exists stamped inside patch meshes)"*. **That is precisely the
asset this approach needs, and the plan then declines to use it for the standing state.**

`patches.json` **already** declares `trees[]` with `at`, `r`, `h`, `slot`. Ask the Blender window for
two things — a flag, not a redesign:
1. **Omit** the broadleaf boles+crowns from the merged patch mesh and its `_far` twin.
2. Add each tree's local **yaw and scale** to `trees[]`.

Then `JunglePatchLayer` builds **one extra MultiMeshInstance3D of the standalone tree per subcell
bucket, where instance `i` IS one tree.** And:

| | bitmask plan | separate tree MultiMesh |
|---|---|---|
| destroy a tree | flip a bit, shader sinks the verts | drop the instance from the buffer |
| shader change | new decode on **every vegetation vertex in the game** | **none** |
| `use_custom_data` / `INSTANCE_CUSTOM` | required | not used |
| `COLOR.b` slot contract (C2) | required, cross-window, **already wrong on disk** | **not needed at all** |
| 24-slot ceiling, float precision | must be reasoned about | **does not exist** |
| near + far MM must both be flipped | yes (easy to miss → tree resurrects at 46 m) | one buffer |
| collider ↔ mesh ↔ registry key | 3 different indices to keep in step | **one index, by construction** |
| **cost of a dead tree** | **its ~600 tris are vertex-shaded forever** | **the tris are gone** |

That last row is the one that should decide it. **The bitmask can only ever HIDE a tree — the plan
says so itself.** Collapsed vertices produce degenerate triangles that the rasteriser discards, but
**the vertex shader still runs on every one of them, every frame, forever.** On an Intel UHD target
already running at 0.77 render scale, a mechanic whose *whole point* is felling hundreds of trees, and
whose implementation makes felled trees **permanently non-free**, is backwards. Rebuilding the tree
bucket's buffer actually *deletes* the work.

**Draw-call cost of the alternative:** within `view_distance = 128 m` (`:97`) that's ~50 subcell
buckets → ~50 extra MMIs. The layer today already emits *two* MMIs per `(subcell × patch name)` — a
few hundred in view. +50 is noise, and it buys back vertex throughput, which is the resource we are
actually short of.

**The honest objection** is authoring: vines are strung between the baked trees, so a felled tree
leaves lianas hanging in mid-air. **But the bitmask has that problem too** — it hides the tree and
leaves the vines. The composition argument does not favour the bitmask; it just means *both* designs
want a "this liana belongs to slot N" rule, which the existing `tree`-slot data already supports
either way.

**Coordination cost is real** — the Blender window is mid-flight on `COLOR.b`. Which is exactly why
this call has to be made **now**, before the shader, the registry and the contract are all written
against a thing that may not need to exist.

---

## Q5 — The single biggest technical risk

# The MultiMesh Phase 2 writes into is destroyed and re-created by the very explosions that fell the trees — and the instance indices the registry keys on are re-shuffled in the process.

This is not a hypothetical. It is a **live bug in shipping code**, and Phase 2 drives straight into it.

### The chain
1. `DamageSystem.apply_damage()` (`damage_system.gd:110`) — every grenade, rocket, bomb, arty round.
2. → `terrain_manager.modify_terrain()` (`damage_system.gd:145`) → `_rebuild_chunks_in_region()`
   → `_rebuild_chunk_immediate()` (`terrain_manager.gd:105-120`) → `clear_chunk_visuals()` +
   `_load_chunk()` → `vegetation_manager.generate_for_chunk()` → `_patch_layer.generate_for_chunk()`.
   **The chunk's patch MultiMeshes are freed and rebuilt as brand-new objects.**
3. **THEN** `vegetation_manager.clear_area()` runs (`damage_system.gd:149-155`), and for every
   affected chunk it does:

```gdscript
# vegetation_manager.gd:766-771
for chunk_coord in affected_chunks:
    clear_chunk_visuals(chunk_coord)          # -> _patch_layer.clear_chunk()  (:870-871)
    if heightmap:
        _materialize_vegetation(chunk_coord, heightmap)   # the LEGACY lone-tree path
        _materialize_grass(chunk_coord, heightmap)
```

**It never calls `_patch_layer.generate_for_chunk()` again.** And `_materialize_vegetation()` is called
**unconditionally**, regardless of `use_jungle_patches` — it materialises `_meshes[0]`, which is the
**procedural palm** (`vegetation_manager.gd:211`, built at `:903`) that the patch layer was explicitly
created to replace (`:315-322`).

### What that means, today, with no new code
**Throw one grenade and a 256 m chunk of authored jungle is deleted and replaced by sparse procedural
palm trees** — until streaming happens to reload it. And `SitePlanner` calls the same `clear_area()`
on every stamp (`site_planner.gd:87`), so **this fires at mission load, on every site, in every
mission.** This is arguably a bigger live bug than the `get_density_at` one the plan calls "the single
highest-value fix in this document," and it is sitting in the middle of Phase 2's blast path.

### Why it is fatal to Phase 2 specifically
- `TreeRegistry` caches `MultiMesh` references. Those nodes are **freed** by the above. Dangling.
- The plan keys the registry on `instance_idx + slot` (plan line 169). **`instance_idx` is a volatile
  key.** Bucket contents are rebuilt from RNG *and the current terrain byte array* — and `clear_area()`
  **mutates that array** (flipping bundles to `CLEAR`, `vegetation_manager.gd:757`). Tiles drop out of
  the bucket, and **every surviving tile's instance index shifts.** The first crater re-indexes the
  chunk and every dead-tree bit lands on the wrong tile.
- Phase 2's own acceptance test — *"M79 a tree: it dies **in this tile only**"* — runs straight through
  this path. It will produce a confusing, non-deterministic result. **The plan's warning about "a green
  test that proves nothing" applies to the plan.**

### What Phase 2 actually requires before it can work
1. **Fix `clear_area()`** to regenerate the patch layer instead of falling back to the dead lone-tree
   path. (Also fix the ordering in `DamageSystem.apply_damage()`: it clears vegetation *after* the
   rebuild that consumed the old vegetation state.)
2. **Persist destruction state OUTSIDE the MultiMesh**, keyed by something stable —
   `(chunk_coord, tile_cell_index, slot)` — and **re-apply it every time a bucket is built.** Never key
   on `instance_idx`.

Neither is in the plan. (Note the *separate tree MultiMesh* from Q4 does not escape this either — but
it can, because that MultiMesh would be owned by `TreeRegistry` and rebuilt from a persistent list of
*live trees*, rather than being a transient by-product of `JunglePatchLayer`'s regeneration.)

---

## BLOCKING OBJECTIONS

### ▲ BLOCK 1 — Phase 0B, the plan's flagship fix, is a map-wide AI regression. And it doesn't compile.

The plan is **right** that `get_density_at` does not exist and the guard is always false. It is
**wrong** about what happens when you fix it.

**(a) It does not compile as written.** The plan says: *"Fix: `get_density_at` → `get_vegetation_density`
(2 sites)."* But the real function is `get_vegetation_density(world_pos: Vector3)` —
**one Vector3** (`clearing_system.gd:266`). Both call sites pass **two floats**:

```gdscript
# gameplay_grid.gd:155  and  :581
clearing_system.get_density_at(world_x, world_z)
```
A blind rename is an argument-count error. The "one-word fix" is not one word.

**(b) Far worse — enabling site `:154` sets vegetation density to 1.0 across the entire AO.**

```gdscript
# clearing_system.gd:79-81
vegetation_map = Image.create(vegetation_size, vegetation_size, false, Image.FORMAT_RF)
vegetation_map.fill(Color(1.0, 1.0, 1.0, 1.0))  # Full vegetation
```
`vegetation_map` is filled with **1.0 everywhere** and is only ever written *down* inside a created
clearing zone (`:124, :137`). So the instant the guard at `gameplay_grid.gd:154` goes live,
**every cell in the AO that is not inside a ClearingSystem zone reads `vegetation_density = 1.0`.**

Consequences, all map-wide, all silent:
- `enemy_base._sight_cap()` (`:626-634`) lerps 140 m → 45 m on that number. Density 1.0 everywhere →
  **every enemy in the game is capped to 45 m sight — on bald hilltops, in rice paddies, standing in
  a river.** The AI goes half-blind across the whole map.
- `_apply_riparian_belt()` only raises density where `gallery > vegetation_density[n]`
  (`gameplay_grid.gd:249`), and `GALLERY_MAX` is **0.95 < 1.0**. **The gallery-forest system becomes a
  silent no-op.**
- `_roof_the_creeks()` uses `maxf()` (`:304`). **Also a silent no-op.**
- `_estimate_vegetation()` — which the file's own comment at `:192` calls **"THE ONE THAT MATTERS"** —
  is bypassed entirely, and density stops correlating with what the player *sees*. The file's own
  warning at `:195-196`: *"If they drift apart, the jungle lies."*

**The correct fix:**
- Site `:580` (`update_region`) — **yes**, rename *and* wrap the args as `Vector3(world_x, 0.0, world_z)`.
  Sites *do* create a CLEARED zone (`site_planner.gd:84-85`), so this genuinely makes LZs real. This half
  of 0B is good and should ship.
- Site `:154` (`build_from_terrain`) — **do NOT enable it.** Keep `_estimate_vegetation(ttype)` as the
  base. If you ever do enable it, take `minf(clearing_density, _estimate_vegetation(ttype))` so a zone
  can only ever *reduce* density, never blanket-raise the whole map to 1.0.

The plan calls 0B *"the single highest-value fix in this document"* and *"Nothing else is trustworthy
until this passes."* Applied as written, it is the single most destructive change in the document.

### ▲ BLOCK 2 — §0's contract is already wrong on disk. It will fell the wrong tree.

| | plan says (§0 C1/C2) | actually on disk |
|---|---|---|
| slot range | `0..23` | **`1..5`** — `patches.json`, every entry |
| `COLOR.b` | `(slot + 1) / 24.0` | **`slot / 24.0`** — `make_jungle_flora.py:213`: `b = 0.0 if slot <= 0 else float(slot) / float(Plant.MAX_TREES)` (`MAX_TREES = 24`, `:131`) |

The baker is **internally consistent** (1-based slot, 0 reserved for "not a tree", `b = slot/24`). The
*plan* is not. An implementer who follows C1/C2 literally — reads `slot = 1` from JSON, treats it as
0-based, sets bit 1; while the shader decodes `round(COLOR.b * 24.0) - 1 = 0` and tests bit 0 —
**checks the wrong bit and fells the wrong tree, or nothing at all.** That is precisely the failure the
baker's own guard-rail warns about (`make_jungle_flora.py:183-188`: *"COLOR.b would be misaligned and
the game would fell the WRONG TREE"*).

**Correct the document to the data before a line of GDScript is written:**
- `slot ∈ 1..24`, 1-based. `0` = not a tree.
- `COLOR.b = slot / 24.0`. Decode: `int s = int(round(COLOR.b * 24.0)); if (s >= 1) { bit = s - 1; }`
- `bit = slot - 1` → mask `0 .. 2^24-1`. (Using `bit = slot` needs 25 bits and walks up to the edge of
  float32's exact-integer window for no reason.)

### ▲ BLOCK 3 — see Q5. `clear_area()` deletes the patch layer and never puts it back.

Phase 2 cannot be built, let alone tested, on top of `vegetation_manager.gd:766-771` as it stands.

---

## RECOMMENDED SEQUENCE

1. **Fix `clear_area()`** (`vegetation_manager.gd:766-771`) to regenerate the patch layer. Prove it:
   throw a grenade in jungle, confirm the chunk is still authored patches and not procedural palms.
   **Do this before anything else. It is a live bug and it is the ground Phase 2 stands on.**
2. **Correct §0 C1/C2** to match `patches.json` + `make_jungle_flora.py:213`.
3. **Apply only the `update_region()` half of 0B**, with the `Vector3` wrap. Leave
   `build_from_terrain()`'s guard dead, or clamp it with `minf`. Keep the LZ regression test.
4. **Make the Q4 call — bitmask vs. separate tree MultiMesh — now**, while the Blender window can still
   act on it cheaply.
5. **Make the Q3 call — do trunks block AI bodies, or only ballistics?** Phase 1 cannot be scoped until
   somebody decides whether the squad is allowed to snag on trees.
6. Only then: Phase 1 (per-**subcell** StaticBody3D, full transform incl. scale jitter, not
   `hard_surface`), then Phase 2.

**Named tradeoff, since the Law requires one:** everything above delays the fun. Nobody gets to fell a
tree this week. What we buy is that when a tree does fall, it is the tree the player shot, it stays
fallen after the next grenade, the squad can still walk, and the AI can still see. The plan as written
delivers a tree that falls, and then a chunk of jungle that turns into palm trees, an enemy that is
blind everywhere, a squad stuck on a bole, and a 1-in-5 chance the wrong tree went down.
