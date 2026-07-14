# THE DECREE — THE JUNGLE IS NOT PLUGGED IN

**Convened:** 2026-07-13 · **Architects:** Godot Specialist · Lead Programmer · Level Designer · Devil's Advocate

---

## 0. THE ARBITER WAS WRONG, AND THE WAY HE WAS WRONG IS THE FINDING

My briefing's headline was **"BREAK 1 — the paddy water parse is stale."** **It is not.**
`jungle_patch_layer.gd:128` reads `entry["water"] as Array`, loops all four of `patch_paddy_quad`'s
pans, and handles the rectangular `half` at `:369-371`. **The pans render.** The `_water: Dictionary`
I cited is the *outer* map (patch name → pans).

**I got it from a stale comment** (`:10-11`, `:83`) — in a briefing whose **Law #1 was "read the code,
never the plan,"** in a repo whose CLAUDE.md — which *I wrote this morning* — says a stale comment
**"is not a wrong note, it is a DRIFT GENERATOR."** It generated drift in the Arbiter eight hours later.

**And the 07-12 council did the same thing.** Its decree item 1b ordered *"prone cover ships for one
array — `logs[]` already exists on disk."* **There is no `logs` array.** The word appears once in
`patches.json`, inside `"desc": "blowdown: crossed logs"`. **A description string became a build
order. Two councils, two days, both fooled by prose.**

> **The COMMENT DISCIPLINE law is hereby upgraded from hygiene to a P0 defect class.** A stale comment
> in this repo has now produced two false P0s and one bogus build order. The purge must extend to
> `terrain/` — and see §5, because the fossil probe cannot even see it.

---

## 1. THE ANSWER TO THE SUMMONER'S QUESTION

### THE JUNGLE PATCHES: ✅ **WIRED AND LIVE.** 23 patches, 6 density classes, rendering.

### THE RICE PADDIES: ❌ **THERE ARE ZERO OF THEM. NOT ONE, ON ANY MAP, EVER.**

Measured by booting the world: **0 of 65,536 cells.** The cause is one number:

> **The map's lowest point is 87.9 m.** Every paddy branch is gated on elevation:
> `GameplayGrid` `h < 5` and `h < 50` · `VegetationManager` `h < 30`.
> **The paddy is gated on an elevation band that does not exist.**

His five paddy patches, the four-pan quad, `_paddy_open_side`, the wade drag, the ×2.2 noise wake,
the leech timer — **all correct, all tested, never once executed.** The boot log has printed
`0 rice billboards` on every run since it shipped, and nobody read it.

**And the inversion:** `_apply_riparian_belt()` overwrites any cell within 22 m of water whose density
is below 0.55. **Paddy density is 0.2.** It skips CLIFF and WATER — not PADDY. So even with the
elevation gate fixed, **every paddy near water becomes jungle.** A paddy could only survive where it
could never be irrigated.

### THE DESTRUCTIBLE TREES: ❌ **44 authored, ZERO lines of code.** The Blender lane is complete; the
code lane was never built. And `tree_ref`'s model paths in the **shipped data** point at
`assets/models/vegetation/` — deleted by the restructure. Wire it today and every tree fails to load.

---

## 2. CONVERGENCE — the strongest signal this process makes

| Finding | Who found it, independently |
|---|---|
| **The water parse WORKS; the Arbiter read a comment** | LP, LD, DA — **3/3** |
| **Trunk colliders ship; DESTRUCTION waits on a perf number** | Godot Specialist, LD, DA — **3/3** |
| **Nobody has ever profiled the jungle** | Godot Specialist, DA — 2/2 |

---

## 3. THE PERF BILL — and it is the reason for the whole decree

- **~16,000 standing trees** in a 1280m AO (not 44 — that is 44 *per patch-type authoring set*).
  Counted: 21×21 tiles/chunk × 25 chunks × 0.78 fill × 2.6 trees/patch.
- A `StaticBody3D` per tree = **32,000 scene-tree nodes, 50–65 MB, a 0.5–0.8 s load stall.** *The scene
  tree dies, not the physics.*
- **The jungle ALREADY costs:** ~1,400 billboards/chunk × 25 chunks × 5 planes ≈ **350,000
  alpha-tested triangles of overdraw** — on an **Intel UHD**.
- **And every FPS number is a lie.** `scaling_3d/scale = 0.77` → **59.3% of native pixels.** The
  "19–25 FPS" and the "40 on 4.7" were both measured at 59% resolution. **Native is likely 12–16 FPS.**
- Water is **178 draw calls per chunk**, not the "ONE" its comment claims.

**NOBODY HAS EVER PROFILED THE JUNGLE.** The project is about to add cost to the exact system most
likely already causing the frame time.

---

## 4. THE DECREE

### PHASE 0 — **MEASURE. Nothing ships before this.** (bead `mhfv`)
Set `rendering_method`. Set `scaling_3d/scale = 1.0` and **re-measure at native resolution.** Profile
the jungle specifically (billboards vs patches vs water vs terrain). **Set a gating FPS number.**
Every number this project has quoted for weeks is void until this runs.

### PHASE 1 — **DETERMINISM. Two lines, and it nearly closes a P0 GATE bead (`5i8a`).**
The Arbiter's diagnosis was wrong; the truth is worse. The global RNG **is** seeded
(`game_flow.gd:184`). The break is **`gameplay_grid.gd:478` — `randf()` inside `has_line_of_sight()`,
a PER-FRAME AI call.** It poisons the shared RNG stream that the exfil / surrender / escalation rolls
draw from — so **ADR-010's "same seed, same events" is a function of FRAMERATE.** It is also
non-idempotent: jungle LOS is a **strobe light**, re-rolling 30% per cell on every single check.
**FIX: hash the cell, don't roll it.** Kills both bugs. Same for `:291`.
*(`has_line_of_sight()` has **zero callers** — LP. Under ADR-023 it may simply die.)*

### PHASE 2 — **THE PADDY BECOMES A SITE, NOT A GUESS.** (the Summoner's actual ask)
**RULING (LD + LP converge): `WaterSystem` is the ONE water oracle — READ to site the paddy, WRITTEN
by the paddy.** A paddy is not a cell type; **it is a site, and it is the reason there is water there
— exactly like the farmer.**
Run a **seeded field pass** after `WaterSystem`, before chunk meshing: flood-fill contiguous 3–12 tile
polygons on gentle ground **near the real D8 network**, then **stamp**: terrace the heightmap, raise
the bunds, drop the pans, and **write water back into `water_map`** so `get_water_depth()` finally
returns 0.25–0.40 m.
**BUNDS GO IN THE HEIGHTMAP, NOT IN COLLIDERS** (LD). Collision, prone cover, navmesh and the basin
all come free, at **zero draw calls** — and the paddy becomes a *decision* (dry bund: fast, quiet,
silhouetted · pan: 55% speed, ×2.2 noise, prone-able) instead of a punishment. **Pillar 3.**
**DIES (ADR-023):** both worldgen `randf()`s · `VegetationManager._determine_terrain_type` (the
*second, independent* classifier — LD proved `TERRAIN_WORKFLOW §6`'s "you cannot desync them" is
**false**) · `near_water_mask` · 11 dead water functions.

### PHASE 3 — **TRUNK COLLIDERS SHIP. DESTRUCTION DOES NOT.** (3/3 architects)
> *"90% of the fantasy is a collider, not destruction."* — Level Designer
> *"Standing trunks alone deliver Pillar 3's promise for zero vertex cost. Destruction is the luxury;
> cover is the pillar."* — Godot Specialist

Bead **`2v3t`** — trunk colliders, *"the most broken thing in the project"* — is **still OPEN**, and it
is the decree's own flagship. **The tree you dive behind does not stop a bullet.** That is a Pillar 3
violation shipping today.

**THE ARCHITECTURE (Godot Specialist, Godot 4.7 / Jolt):** `PhysicsServer3D`-direct **chunk
compounds**. 25 static body RIDs; **16 shared, quantized `CylinderShape3D` RIDs** (quantize into 4×4
radius/height buckets — **never scale a shape**). Jolt compiles ~646 shapes per chunk into a
`StaticCompoundShape` with an internal BVH: one broadphase hit, O(log n) descent per bullet.
**Zero scene-tree nodes.**
Fell = **`body_set_shape_disabled()`** — ***never*** `body_remove_shape()`, which reindexes and
invalidates all 16k indices.

**DESTRUCTION IS DEFERRED** until Phase 0 produces a number. It was **CUT 24 hours ago** by the
07-12 council (blocked by `vtiz`, still OPEN) — and re-thawing it now would be the fifth feature to
jump the queue.

---

## 5. LANDMINES FOUND (each one would have shipped)

1. **THE PLAN'S SLOT INDEXING IS OFF BY ONE.** `DESTRUCTIBLE_JUNGLE_PLAN §C2` says
   `COLOR.b = (slot+1)/24`, slots 0..23. **The shipped data is `slot/24.0`, slot 1-BASED (1..5).**
   Implement the plan literally and **you fell the neighbouring tree.**
2. **TWO MULTIMESHES PER BUCKET** (near + `_far`). Flip the bit on one and the tree **vanishes up
   close and still stands at 60 m.**
3. **`test_fossils.gd` NEVER SCANS `terrain/`.** *(`SCAN_DIRS = ["res://scripts"]`.)* That is the
   Arbiter's own probe, and it is **why the terrain fossils survived.** Fix the probe.
4. **The pan sits 5.5 cm above ground, on slopes up to 26°.** The first paddy that spawns will have
   **dirt punching up through the water.** The ground must be **flattened**, not merely terraced.
5. **`_paddy_open_side`** calls any tile with a non-paddy neighbour an EDGE → **76% of paddy tiles
   would render as the treeline tile**, and `patch_paddy_quad` on ~5%. His art is right; **the
   placement is a dither.**
6. **`get_cover()` is a FOSSIL** — declared, read by nothing. The paddy's `cover = 0.1` does nothing.

---

## 6. WHAT IS SACRIFICED (the law binds the Arbiter too)

- **The Summoner gets FEWER paddies** — rare, deliberate, real ones with quads. Some missions will
  have none. That is the cost of a paddy being a *site* and not a coin flip.
- **Deferring destruction costs him the thing he built last night.** It is the honest call: the game
  cannot afford it until it has a frame-time number, and the *cover* half — which is the pillar —
  ships now.
- **Trunk colliders are not free.** Every `move_and_slide()` now sweeps a 646-shape compound each
  tick. The jungle had **zero** collision before. Phase 0 must price this too.
- **Worldgen order becomes brittle** — the paddy pass must precede collider cooking or the bunds are
  ghosts.
- **The bund gives cover in the most exposed place in the game.** Accepted deliberately — but it must
  stay *bad* cover.
