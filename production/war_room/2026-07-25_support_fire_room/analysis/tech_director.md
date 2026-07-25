# Technical Director / Godot-Specialist — Support Fire Test Room

**Lens:** destructible-environment architecture (trees / buildings / terrain) vs Forward+, the
Intel-UHD perf floor (ADR-026, deep-night 18v18 ~19–23fps BOTH-bound), PSX aesthetic. Cheap,
state-based, NOT physics fracture. Every file cited was read this pass.

---

## 1. TREES — the bitmask/shader-collapse approach

### Is it the right cheap approach on Forward+? Mostly yes — but it targets an architecture we may be retiring.

The DESTRUCTIBLE_JUNGLE_PLAN bitmask (`DESTRUCTIBLE_JUNGLE_PLAN.md:169-207`) exists to solve **one
specific problem**: in `jungle_patch_layer.gd`, "every patch bakes to one merged mesh, instanced ~40×
per chunk" (`:171-173`) — a tree is a few hundred welded triangles inside a 20k-tri tile, so you
cannot delete geometry without deleting all 40 copies. The bitmask (`use_custom_data`, `.r` = dead-tree
bitmask, `COLOR.b` = slot, shader sinks the vertex) is a **clever workaround for that welded-mesh
constraint**. It is correct and it does cost ~0 draw calls.

**But `terrain/vegetation/tree_cover_layer.gd` — the LIVE cover mechanism — does not weld trees.**
Each tree is already an **individual MultiMesh instance with its own `Transform3D`**
(`tree_cover_layer.gd:159-181`) and its own trunk `StaticBody3D` (`:184-195`). On THIS path felling a
tree is even cheaper than the bitmask: **sink that one instance's transform** via
`mm.set_instance_transform(idx, collapsed)` and `queue_free()` its one trunk body. No shader edit, no
`COLOR.b` slot contract, no float32-bitmask packing. The briefing itself says TreeCoverLayer "retires
the merged-patch / procedural-billboard paths on switchover" (`tree_cover_layer.gd:8-11`,
briefing ADR-023 note). **If TreeCoverLayer wins, the entire bitmask machinery is aimed at a corpse.**
This is a fork-in-the-road the plan predates — flag it to the Arbiter. My recommendation: build the
feller against TreeCoverLayer's per-instance model, keep the bitmask in reserve ONLY if the
merged-patch path survives for dense background canopy.

### Does the custom-data + shader-collapse actually cost ~0 draw calls? Yes.

Per-instance custom data is a second per-instance attribute in the **same GPU buffer** as the
transforms — it adds 4 floats/instance to an existing buffer, zero extra draw calls, and the
vertex-shader collapse (`if bit set: VERTEX.y -= large`) is a branch on hardware that already runs the
sway vertex program (`vegetation_sway.gdshader:27-53`). The sink is free GPU work. Draw-call count for
standing trees is **unchanged** — that is exactly the VERIFICATION test the plan names
(`DESTRUCTIBLE_JUNGLE_PLAN.md:360`).

### 4.7 gotchas (INSTANCE_CUSTOM, use_custom_data)

- **Order of operations:** set `mm.use_custom_data = true` **before** setting `instance_count` /
  transforms. Toggling it after allocation reallocates and can zero the custom buffer. `TreeCoverLayer`
  currently never sets it (`:159-181`) — it must be added at build time.
- **Shader access:** the per-instance color arrives as `INSTANCE_CUSTOM` (a `vec4`) in the vertex
  stage in 4.7. That is a **different channel from `COLOR`** (the baked vertex color carrying the sway
  masks + the proposed `.b` slot). The plan correctly keeps them separate (`:181-184`).
- **Float precision:** a float32 stores a 24-bit integer exactly, max 5 trees/patch — ample
  (`:177-179`). Fine.
- **Sway shader must guard `COLOR.b > 0.0`** so grass/fern/bamboo/rice are never collapsed
  (`:181-182`); `vegetation_sway.gdshader` currently reads only `.r`/`.g` (`:6-9`), so `.b` is free.

### felled GLBs — CONFIRMED present

`assets/world/vegetation/{felled_tree,felled_trunk,tree_stump,fallen_log_a,fallen_log_b}.glb` all
exist on disk (glob this pass). `TreeCoverLayer.COVER_TRUNK` already registers them with collider radii
(`tree_cover_layer.gd:25-26`). The fall's three states are ready: transient `felled_tree.glb` Node3D
(scripted hinge, NOT RigidBody — a rigidbody tree eventually launches into the sky, plan `:222-224` is
right), settled `felled_trunk.glb` in a **shared fallen-log MultiMesh** = one draw call for all of them
(`:216-221`). **Trees are the cheapest layer and are affordable now.**

---

## 2. BUILDINGS — Destructible StaticBody3D state-swap

### The swap itself is nearly free; the scatter and the burst are the cost.

Swapping `intact → damaged → rubble` = reassigning a `MeshInstance3D.mesh` and swapping one
`CollisionShape3D` — trivial, no draw-call growth (one mesh replaces one mesh). Cover-group
reassignment (`burned_hut` is no longer soft cover — plan `:322-325`) is a group edit. All cheap.

**The real costs, in order:**

1. **Rubble-prop scatter.** 2–4 `rubble_*` props per building — if each is its own
   `MeshInstance3D`/`StaticBody3D`, that is **+2–4 draw calls per destroyed building, permanent.** One
   hut is nothing; an **arty 6-round sheaf, a CBU cluster, or an F-4 napalm run flattening a
   whole 20-hut village in one pass** is +40–80 draw calls **plus** 20 state-swaps **plus** 20
   DamageSystem craters **plus** 20 veg-clears **plus** 20 scar decals — **in a small number of frames.**
   That is a frame-time cliff on the Intel-UHD floor. **Mitigation: rubble props go into a shared
   per-AO rubble MultiMesh (like the fallen-log pool), NOT individual bodies.** Then 80 rubble piles =
   1 draw call.
2. **Simultaneous count.** Single-building demolition (grenade → hut, LAW → bunker) is affordable at
   any realistic firefight rate — the player physically cannot level more than a few per engagement.
   The danger is **exclusively area-effect ordnance hitting a cluster.** Cap it: **defer/queue the
   state-swaps and craters over N frames**, don't process a whole napalm footprint in one tick.

### Reuse `destructible_vehicle.gd`

`DestructibleVehicle.create()` (`destructible_vehicle.gd:10-36`) is already the exact spawn skeleton
the general `Destructible` needs: it reads `CollisionTable.get_entry()`, builds the visual + a
`BoxShape3D` collider from authored `entry.box`, registers `"nav_blockers"` + `nav_box` meta so
`NavBaker` re-carves (`:27-28`), and grounds to `terrain.get_height_at()` (`:33`). **Fold it into
`Destructible` per ADR-023 (fossil law) and add what it lacks: `hp`, `take_damage(amount, source)`,
`destroy()`** — the briefing correctly notes it has "no HP, no take_damage, must be told to die"
(briefing `:33`). On `destroy()`: swap mesh, scatter into the shared rubble MultiMesh, swap collider,
reassign cover group, mark nav dirty, and call `DamageSystem.apply_damage(pos, MEDIUM_EXPLOSION)` for
the crater (plan `:320-325`). **Buildings are affordable with the batching caution above; do not ship
per-prop bodies.**

---

## 3. TERRAIN — DamageSystem craters. THIS IS THE ONE TO PROVE.

### Confirmed: DamageSystem already does full crater deformation.

`terrain/systems/damage_system.gd` is the autoload. `apply_damage()` (`:99`) computes a metres-based
crater profile (retuned 2026-07-18 to real anchors — grenade 0.6 m, arty 2.0 m, bomb 8.0 m;
`:20-61`), calls **`terrain_manager.modify_terrain(world_pos, radius_meters, crater_func)`**
(`:137`) which the code's own comment says **"also rebuilds affected chunks"** (`:133`), clears
vegetation (`:141-147`), and spawns a scar `Decal` (`:159-165`). `DamageType` =
SMALL/MEDIUM/LARGE_EXPLOSION, NAPALM, BUNKER_COLLAPSE. **Reuse it — do not build a second one.**

### The chunk-rebuild spike, and why the 40-cap does NOT fully protect the frame.

`modify_terrain` rebuilds the ArrayMesh(es) of every chunk the crater radius touches — a large crater
straddling a chunk seam rebuilds 2–4 chunks. **A chunk rebuild is a full mesh regeneration (vertex +
normal recompute + collision reshape) on the main thread** — the single most expensive terrain
operation in the game.

`MAX_DEFORMS_PER_MISSION = 40` (`:68`) is an **aggregate per-mission ceiling** — its own comment says
it "bounds chunk-rebuild spikes under sustained ordnance" (`:66-67`). **But it does NOT throttle
per-frame cost.** Nothing stops **all 40 from firing in a handful of frames**: an arty 6-round sheaf =
up to 6 craters (→ 6–24 chunk rebuilds) in one salvo; a CBU cluster or napalm run can burn the whole
budget in under a second. The cap protects the mission total and prevents unbounded map cratering — it
does **not** protect the frame during a burst. On the Intel-UHD floor already at ~19–23fps, a
multi-chunk rebuild spike in one frame is a visible hitch.

### Cheapest terrain-destruction that reads

**Tier the cost to what the player perceives:**
- **Small/medium (grenade, mortar, M79, single arty round):** the player does not gameplay-read a
  0.6–2.0 m depression mid-firefight — he reads the **scar decal + charred veg-clear**. Ship those
  (both already cheap in DamageSystem: decal + `clear_area`) and **skip the heightmap dig**, or apply
  only a shallow collision bump. This kills the rebuild spike for the *common* case.
- **Large (bomb, LAW-into-dirt, satchel):** keep the real heightmap dig — a bomb crater you climb into
  and use as cover is a genuine verb and worth the one rebuild.
- **Under burst ordnance:** **queue deforms and apply ~1 heightmap dig per frame**, letting the decal
  + veg-clear land instantly so the burst still *looks* right while the expensive rebuilds amortize.
  This is the single most important addition to the shipped DamageSystem.

### Verdict on the Intel-UHD floor

**Live heightmap deform is affordable for isolated, player-driven single craters. It is NOT proven
affordable under a single area-effect salvo, and the 40-cap does not bound that per-frame cost.** This
is the layer that **must be measured in the test room before Caleb blesses shipping the fire-support
suite** — the whole point of the room is arty/napalm/CBU/spectre, which are exactly the burst callers
that stress this path. Bench: fire a 6-round arty sheaf and a CBU pattern on the Intel-UHD target, read
the frame-time spike, and confirm the tier/queue mitigation holds it under the floor.

---

## 4. VFX — reuse the explosion/particle path. CONFIRMED, with one correction.

`GunFX.play_explosion_3d()` (`gun_fx.gd:108`) → `_spawn_explosion_visual()` (`:118`) **already**
spawns the full cheap kit: an unshaded emissive billboard fireball quad (`:131-145`, FAKE light per
ADR-026), a rising smoke `CPUParticles3D` (`:147-161`), and a **dirt/debris `CPUParticles3D`**
(`:163-176`) — capped by `MAX_EXPLOSIONS` with freed-node pruning (`:121-124`). **This is the debris
spawner to reuse for tree-fall dust and building rubble bursts. Do not write a second one.** Call
`GunFX.play_explosion_3d()` (or a thin `_spawn_explosion_visual` wrapper with a dust tint) at the
tree-impact and building-destroy sites.

**Correction to the plan:** `DESTRUCTIBLE_JUNGLE_PLAN.md:231-232` says "reuse `gib_system.gd`'s debris
spawner." **`gib_system.gd` is the WRONG spawner** — it builds `RigidBody3D` gibs
(`gib_system.gd:261, 321`), i.e. real physics bodies for corpse dismemberment. Spawning rigidbody
debris on every tree-fall and building collapse is exactly the physics cost this whole design avoids.
**Use the `CPUParticles3D` debris in `gun_fx.gd`, not the rigidbody gibs.** One debris path, and it is
GunFX.

---

## 5. BLUNT PERF VERDICT

| Layer | Cheap architecture | Affordable now? |
|---|---|---|
| **Trees** | Per-instance transform-sink on TreeCoverLayer (or bitmask+shader-collapse if merged-patch survives); scripted-hinge transient fall; shared fallen-log MultiMesh (1 draw call for all). felled GLBs exist. | **YES — cheapest layer, ship it.** |
| **Buildings** | `Destructible` = `DestructibleVehicle.create()` + hp/take_damage/destroy; mesh-swap + shared rubble MultiMesh + DamageSystem crater. | **YES — but ONLY with rubble batched into one MultiMesh and area-effect leveling deferred over frames. Per-prop bodies = a cliff.** |
| **Terrain deform** | Tier: scar+veg-clear for small/medium (skip the dig), real heightmap dig only for bomb craters, queue 1 dig/frame under bursts. | **NOT PROVEN. The chunk-rebuild spike under one arty sheaf / CBU / napalm run is unmeasured, and MAX_DEFORMS=40 is a per-mission aggregate, not a per-frame throttle.** |

**What is sacrificed:** the cheap architecture buys itself by giving up fidelity where the player
won't read it — trees *hide/sink* rather than shatter (no branch-break geometry); buildings snap
intact→rubble through at most one damaged state (no progressive chunk-by-chunk collapse, no support
graph — correctly deferred, plan `:337-338`); and terrain, to stay on the Intel-UHD floor, must
**down-tier most craters to a decal + veg-scorch with no real hole**, reserving true diggable craters
for heavy ordnance. The grenade that scrapes a 0.6 m dish becomes a scorch mark, not a foxhole.

**The one layer that must be perf-proven before it ships: TERRAIN heightmap-deform.** The test room is
the correct place to measure it — its entire reason for existing is the burst fire-support callers that
stress exactly this path.
