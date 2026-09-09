# GODOT SPECIALIST — the right technical shape for the morph/cut + placement tool

**Council:** 2026-09-09 firebase kit pivot · **Architect:** godot-specialist · **Engine:** Godot 4.7 stable, Forward+
**Method:** read-only. Nothing was run. Caleb is in the build (pid 13196); no process was touched, no window opened.
**Knowledge base loaded per project law:** `godot_4.7_features.md`, `godot_standards.md`,
GodotPrompter `addon-development`, `save-load`, `procedural-generation`.

Every claim below carries `file:line` or is marked **UNVERIFIED**.

---

## THE HEADLINE, BEFORE THE DETAIL

1. **An `EditorPlugin` is impossible here and the codebase decides it, not taste.** `scenes/levels/game_world.tscn`
   is **six lines and one empty `Node3D`**. The terrain node does not exist until `game_world.gd:_setup_terrain()`
   runs `TerrainManagerScript.new()` at runtime. In the editor there is nothing to sculpt. **In-game dev mode, forced.**
2. **The tool must output a DATA FILE, never a `.tscn`.** ADR-041 §3's ten contracts are the argument; ADR-028's
   one-path law is the law. And there is already a plan/build split in this codebase to hang it on —
   `plan_demo_world()` returns a Dictionary that `build_patrol_world()` stamps unchanged.
   **A hand-authored plan file is that same dict, written by hand instead of rolled.**
3. **"Morph and cut" cannot make a trench.** `WorldConfig.CELL_SIZE = 4.0` (`scripts/levels/world_config.gd:11`).
   A 4m grid cannot represent a 1.5m ditch. The code already says so in his own words at
   `site_planner.gd:1680`: *"A 4m heightmap cannot draw any of that at any setting."* **The cut is a SEAT; the
   trench shape is a MESH module.** This reframes the whole ask and it is the most important finding in this file.
4. **The expensive half of the terrain edit is vegetation, and a tool can just switch it off.** Of the measured
   81.5ms chunk rebuild, **42.5ms is `terrain.veg_generate`** (`production/PERF_LEDGER.md:1582-1586`). Suppress
   veg regen during a brush stroke and regen once on mouse-up: the single biggest edit-time win available, and
   it is free because it is legal only in a tool.

---

## 1 · WHAT ALREADY EXISTS

### 1.1 The public API for editing the heightmap

**It is not in `damage_system.gd`.** The read (the napalm agent's file was read, not touched) shows
`damage_system.gd:246` *calls* it; the function lives one layer down:

```
TerrainManager.modify_terrain(center: Vector3, radius_meters: float, modifier: Callable) -> void
    terrain/core/terrain_manager.gd:304
```

That is the whole public surface, and it is a good one. Under it:

| Entry | File:line | What it is |
|---|---|---|
| `modify_terrain(center, radius, modifier)` | `terrain/core/terrain_manager.gd:304` | The one edit door. Wraps edit + rebuild + signal. |
| `HeightmapStorage.modify_region(center_cell, radius_cells, modifier) -> Rect2i` | `terrain/core/heightmap_storage.gd:~133` | Applies the modifier per cell, returns the dirty rect. |
| the modifier signature | `heightmap_storage.gd:126-131` (doc comment) | `(height, falloff, world_x, world_z) -> float`. **World XZ is passed on purpose** so a modifier can vary with BEARING, not just distance — that is what let the firebase mound be reproduced rather than approximated. A trench brush needs exactly that. |
| `signal region_rebuilt(world_rect: Rect2)` | `terrain/core/terrain_manager.gd:16` | *"one terrain-change channel, every height consumer listens or floats."* Anything the tool places must listen or re-seat. |
| `get_height_at(world_pos) -> float` | `terrain/core/terrain_manager.gd:292` | O(1) bilinear, no physics. **This is the snap-to-terrain primitive — free.** |
| `get_normal_at(world_pos) -> Vector3` | `terrain/core/terrain_manager.gd:~297` | Free align-to-slope. |
| `meters_to_norm` / `norm_to_meters` | `heightmap_storage.gd:56, 61` | The one scale conversion. A brush that works in metres must go through these. |
| `ClearingSystem` zones | `terrain/systems/clearing_system.gd:14-49` | 4 stages; `CLEARED` carries `height_flattening: 0.7`, `FORTIFIED` carries `1.0`. |

**The one thing that matters architecturally: `modifier` is a `Callable`, and a `Callable` is not
serialisable.** A saved plan therefore cannot store the brush; it stores an **op kind + params**, and the
replayer maps kind → Callable from a fixed registry. This is not a limitation, it is the correct shape — it
is what makes a plan file diffable, reviewable and version-migratable.

### 1.2 What a chunk rebuild costs

Measured, `tests/stall_bench.tscn`, headless, seed 47225, recorded at `production/PERF_LEDGER.md:1582-1586`:

```
terrain.crater 81.6ms -> terrain.chunk_rebuild 81.5ms
    terrain.veg_generate   42.5ms   ( veg.tree_cover_mmi 21.6 + veg.build_scatter 20.9 )
    terrain.collision      20.1ms
    terrain.build_mesh     12.6ms
    terrain.heightmap_edit  0.1ms
```

The intent doc's "0.1ms edit, 80–94ms rebuild" is **confirmed**. But three refinements the intent doc does
not have, and they change the tool's design:

1. **There are two rebuild paths, not one.** `_rebuild_chunks_in_region` (`terrain_manager.gd:321`) tries
   `_patch_chunk_region` (`:356`) first and only falls back to the destroy-and-rebuild
   `_rebuild_chunk_immediate` (`:79`) when that chunk has no patch cache yet. **The first edit on a chunk is
   expensive; every later edit on the same chunk patches in place.** For an authoring session that means the
   first stroke on a chunk is the slow one and the rest are cheaper.
2. **The patch path still pays the vegetation bill.** `_patch_chunk_region` calls
   `vegetation_manager.generate_for_chunk` under `StallLedger.begin("terrain.veg_generate")`
   (`terrain_manager.gd:376-378`). So the 42.5ms does **not** go away by patching.
   **A brush that null-routes `terrain_manager.vegetation_manager` for the duration of a stroke and restores
   it on mouse-up drops the per-edit cost by roughly half.** The guard is already there —
   `if vegetation_manager:` at `:375`.
3. **`WorldConfig.TERRAIN_DEFORMS_PER_FRAME = 1`** (`scripts/levels/world_config.gd:46`, comment: *"raise to
   dig faster"*). That throttle is a runtime frame-rate protection. A tool raises it or bypasses the queue and
   calls `modify_terrain` directly, which is what `site_planner.gd:1686` already does.

**The intent doc's core claim stands and is stronger than it knew:** *"an authoring tool does not have to be
fast — the 80–94ms rebuild that is a defect at runtime is irrelevant at edit time."* Correct. 81ms is 12 fps;
suppress veg and it is ~33ms, about 30 fps, which is a usable brush. **UNVERIFIED: the patch path has never
been TIMED.** `tools/probe_chunk_patch.gd` proves the patched chunk is byte-identical to a full rebuild
(vertices, collision samples, 2000 ground rays) — it is a **correctness** probe, not a **cost** probe. The
81.5ms in the ledger is the FULL rebuild. **The cost of a patch is the single number this council does not
have, and it decides whether the brush is drag-continuous or click-stamp.** One `StallLedger` window in a
headless probe answers it in an hour.

### 1.3 Is the terrain data serialisable / persistable

**Technically trivial. Architecturally forbidden as a heightmap.**

- The field is `HeightmapStorage.data: PackedFloat32Array` (`heightmap_storage.gd:16`). Demo AO: `map_size`
  512 (`scripts/main/game_flow.gd:586`) ÷ `cell_size` 4.0 → 128×128 cells = **64 KB**. Full AO: `MAP_SIZE`
  1280 → 320×320 = **400 KB**. `store_var`, `Image.FORMAT_RF` + EXR, or raw floats — all fine.
- **Nothing serialises it today.** `grep terrain|heightmap scripts/autoload/save_manager.gd` returns **zero
  hits** across all 347 lines. ADR-028 and ADR-007/010 are why: *"there are no saved maps — saves regenerate
  the world from the seed."* **Craters do not survive a save/load today.**
- Therefore **shipping a baked heightmap file would create a second source of truth for the ground**, which
  is precisely the fracture ADR-028 exists to prevent. It would also silently invalidate itself the day the
  generator, a preset, or `TerrainConfig.WORLD_HEIGHT_MAX` changes — a 400 KB file with no way to know it is
  stale.

> **Verdict: persist the OPS, never the FIELD.** A list of deterministic edit ops replayed on top of the
> seed-generated terrain is smaller, diffable, self-healing across generator changes, and stays inside
> ADR-010/ADR-028. A baked heightmap is the ADR-023 fossil this project keeps having to delete.

---

## 2 · EDITOR PLUGIN vs IN-GAME DEV MODE

### VERDICT: IN-GAME DEV MODE. The question is not open — the codebase closed it.

**The deciding fact, verified by direct read:**

```
scenes/levels/game_world.tscn  (the entire file)
    [gd_scene load_steps=2 format=3 uid="uid://cgameworld0001"]
    [ext_resource type="Script" path="res://scripts/levels/game_world.gd" id="1_gw"]
    [node name="GameWorld" type="Node3D"]
    script = ExtResource("1_gw")
```

**Six lines. One empty `Node3D`. There is no terrain in the editor.**

Every world node is constructed in code at runtime:
- `game_world.gd:100-108` — `TerrainManagerScript.new()`, `.map_size = map_size`, `add_child()`.
- `game_world.gd:109-116` — `VegetationManagerScript.new()`.
- `game_world.gd:131` — `await terrain_manager.generate_terrain(mission_seed)`.
- `terrain_manager.gd:56-65` — `_ready()` builds the `HeightmapStorage` and grabs `/root/TerrainEngine`.

And **`TerrainEngine` is not a `@tool` script**. It is `extends Node` (`terrain/core/terrain_engine.gd:1`),
registered as an autoload (`project.godot:38`). Project-wide, `@tool` appears on exactly **three** files
(`scripts/combat/projectile_data.gd:2`, `scripts/enemies/enemy_data.gd:2`, `scripts/weapons/weapon_data.gd:2`)
— all three are data `Resource`s for inspector editing. **No world code runs in the editor.**
There is also **no `addons/` directory at all**, and `project.godot` has no `[editor_plugins]` section.

So an `EditorPlugin` would open `game_world.tscn`, see one empty node, and have:
- no heightmap to brush (`TerrainManager.heightmap` is null until `_ready`),
- no `TerrainEngine` autoload (autoloads do not run in the editor unless `@tool`),
- no navmesh, no `ClearingSystem`, no `GameplayGrid`, no vegetation,
- and no way to see the placement defects the whole exercise exists to catch.

**Making an EditorPlugin work would mean `@tool`-ing the world build path** — `terrain_engine.gd`,
`terrain_manager.gd`, `heightmap_storage.gd`, `terrain_chunk.gd`, `vegetation_manager.gd` — so the world
generates inside the editor process. That is a **second execution context for the protected foundation**,
which is ADR-028's named prohibition in a new costume, and it is how you get "works in the editor" bugs, the
exact class of divergence the arena used to hide. **Refused.**

### The second, independent reason — and it is his own ruling

ADR-041's context line: *"every expensive defect closed was a PLACEMENT defect — invisible in Blender,
obvious in Godot with a baked navmesh."* An `EditorPlugin` has **no baked navmesh either** — `NavBaker` runs
from the runtime build. So an editor plugin would be a third place where placement looks right and is wrong.
**In-game dev mode is the only context in which the thing being authored is the thing that ships.**

### The project already has the precedent, twice

1. **`tools/cursor_editor.gd`** — a real authoring tool, run as `godot --path . res://tools/cursor_editor.tscn`,
   which lets you click to place a value, nudges with arrow keys, and **writes a JSON file into `res://`**
   (`tools/cursor_editor.gd:263-267`, `JSON_PATH = "res://assets/ui/cursors/cursors.json"`). It is a
   standalone game-process tool that emits data. **That is the shape. Copy it.**
2. **The free camera already exists in the shipping player.** `scripts/player/player.gd:1576-1613` — photo
   mode: `_toggle_photo_mode()`, `_update_photo_fly()`, `PHOTO_FLY_SPEED = 9.0`, WASD + jump/crouch for
   vertical, hides the HUD and the weapon, saves and restores position, and correctly calls
   `reset_physics_interpolation()` on exit (`:1601`). **The single most expensive UX component of the tool is
   already written, shipped, and bound to a key.**

### What is sacrificed by choosing in-game

Named, per Law 2:
- **No inspector.** Every property the tool exposes must be a hand-built Control. Godot's free property
  editing is an editor-only gift and it is forfeited.
- **No `EditorNode3DGizmo`.** There is no runtime translate/rotate gizmo in Godot 4.7. Either write one
  (days) or use keyboard nudge (hours). **Recommend keyboard nudge** — see §5.
- **No editor undo integration.** But `UndoRedo` (not `EditorUndoRedoManager`) is a plain core class usable
  at runtime, so this costs almost nothing.
- **World boot time on every tool launch.** The tool sits behind the same loading screen the game does.
  Mitigation: fix the seed, and skip the enemy/garrison passes.

---

## 3 · WHAT THE TOOL MUST OUTPUT

### VERDICT: a JSON **site plan**. Not a `.tscn`. Not a baked heightmap. Not a `.glb`.

`ResourceSaver.save(PackedScene)` at runtime **would work** — this is not a technical impossibility, and
saying so honestly is required. The refusal is architectural.

### Why a composed `.tscn` is refused

ADR-041 §3 already names ten contracts that break when a composite goes through `place_structure()`
(`scripts/world/site_planner.gd:190-266`). I re-verified the two that decide it:

- **`test_placement_paths.gd` cannot see the failure.** `PLACEMENT_CALLS` (`tests/test_placement_paths.gd:12-15`)
  matches the six named entry points **by substring**. A composed scene instanced with
  `load(path).instantiate()` is invisible to it. ADR-041 §2 recorded this hole; it is still open, verified
  today at `:12-68`.
- **`SCAN_DIRS = ["res://scripts", "res://terrain"]`** (`tests/test_placement_paths.gd:38`). **`res://tools`
  is NOT scanned.** A tool script in `res://tools/` calling `place_structure(` would pass the probe silently.
  **That is a loophole, not a licence** — see §7 step 7.

### Why a plan file is right — and the codebase already works this way

This is the argument that settles it, and it is not mine, it is already in the code:

```
plan_demo_world(world, op_seed) -> Dictionary      scripts/missions/mission_generator.gd:697
build_patrol_world(world, director, p) -> Dictionary   scripts/missions/mission_generator.gd:877
```

`plan_demo_world`'s own docstring: *"the authored 512m-slice plan. Same dict contract as plan_patrol_world —
**build_patrol_world stamps it unchanged**"* (`:693-696`). And `build_patrol_world:891-898` walks
`p.sites` and matches on `site.kind`.

**The plan/build split ALREADY EXISTS. There is a Dictionary that describes a world and a builder that
stamps it. The tool does not need a new mechanism — it needs to write that dict by hand instead of rolling
it from a seed.** That is the cleanest possible reading of ADR-028: one build path, two ways of producing
its input.

### The file format, concretely

**Location:** `res://data/site_plans/<name>.json` (new directory; `data/` is neutral and neither `scripts/`
nor `terrain/`, so it never enters `test_placement_paths.SCAN_DIRS` by accident).

```jsonc
{
  "format": 1,                         // migrate-able; save-load skill §6
  "kind": "firebase",                  // must be in WorldConfig.NAV_SITE_KINDS if it needs a nav bake
  "name": "fsb_bravo",
  "authored_utc": "2026-09-09T21:40:00Z",
  "footprint_radius_m": 118.0,         // the anti-creep radius; ADR-041 §1

  // ORDERED. An ARRAY, never a Dictionary — replay order IS the contract.
  "terrain_ops": [
    {"op": "seat_plateau", "at": [0,0], "r": 118.0, "falloff": 0.107},
    {"op": "trough",       "at": [-40,12], "r": 9.0, "depth_m": 1.1},
    {"op": "berm",         "at": [0,0], "r": 96.0, "w": 8.0, "h": 1.22},
    {"op": "shell_hole",   "at": [22,-8], "r": 5.0, "depth_m": 1.6}
  ],

  // Local transforms, metres/degrees, relative to site centre. NEVER world position.
  "parts": [
    {"id": "fb_bunker_cp",  "pos": [-12.4, 0.0, 33.1], "yaw": 90.0, "seat": "terrain"},
    {"id": "fb_hooch_02",   "pos": [ 18.0, 0.0, -4.2], "yaw":  0.0, "seat": "terrain"},
    {"id": "fb_trench_str", "pos": [-40.0, 0.0, 12.0], "yaw": 45.0, "seat": "op:1"}
  ],

  "markers": [
    {"type": "work", "work": "cook", "pos": [ 4.0, 0.0, 11.2]},
    {"type": "spawn", "role": "bunk", "pos": [-1.6, 0.0, 32.1]}
  ],

  "flatten_profile": {"radius": 130.0, "strength": 0.7, "shoulder_m": 30.0}
}
```

**Five properties that are load-bearing, each answering a specific ADR clause:**

1. **`parts` carries `id`, not a path.** The id is the `CollisionTable` key and the destructible/ballistic
   prefix. Replay feeds each id through the ONE `place_structure()` factory, so every one of ADR-041 §3's
   ten contracts is satisfied **by construction** rather than re-implemented. This is the whole point: a
   plan of ids is a plan the existing builder can already execute.
2. **Local transforms only.** ADR-041 §1's anti-creep rule: *"it MAY NOT KNOW ITS OWN WORLD POSITION."*
   The planner keeps WHERE; the plan keeps WHAT-INSIDE-MY-FOOTPRINT.
3. **`terrain_ops` is an ARRAY.** JSON object key order survives a round-trip in Godot 4.7 but relying on it
   is a determinism bug waiting to happen. Order is the contract; use the type that guarantees it.
4. **`op` is a string key into a fixed registry**, because a `Callable` cannot be serialised (§1.1). The
   registry is the tool's and the replayer's shared vocabulary and it must live in ONE file that both read.
5. **`flatten_profile` is declared, not assumed** — ADR-041 §6's binding clause: *"an authored site ships
   with its own declared flatten profile … or it does not ship."*

**Markers stay in the plan, not in a `.tscn` and not in a GLB** — which is his own 2026-07-29 ruling,
recorded verbatim at `site_planner.gd:805-816`: *"those markers live in the SCENE, not in the GLB, so
re-exporting the GLB from Blender can never delete them."* A JSON plan has the same property and is
additionally **diffable in git**, which a `.tscn` full of `Transform3D` floats is not.

**A shipping bake is a separate, later question and should be refused for now.** If load time ever demands
it, the plan is the source and the bake is derived — never the other way round (ADR-023).

---

## 4 · TERRAIN EDITS AS DATA — surviving world regeneration

### The order, verified

`place_firebase_main` (`scripts/world/site_planner.gd:1645`) is the honest price list, and the briefing's
note is correct. Verified line by line:

```
1669-1673  # ORDER IS LOAD-BEARING. The vegetation clear runs FIRST, because clear_and_flatten ->
           # ClearingSystem CLEARED stage does its own height flatten toward the mean of a 140m disc.
           # Run after the sculpt it averages the authored mound back down ...
           # The sculpt must have the last word on this ground.
1674-1675  for disc in FSB_CLEAR_DISCS: clear_and_flatten(...)      <-- VEG CLEAR
1686-1688  _terrain.modify_terrain(center, FSB_FLATTEN_RADIUS, ...)  <-- SCULPT
1690-1691  if _grid: _grid.update_region(center, FSB_FLATTEN_RADIUS) <-- GRID RE-DERIVE
1692       _audit_one_ground(center, seat_y)                         <-- MEASURE THE CLAIM
1693-1701  load -> instantiate -> add_child -> global_position       <-- SEAT
1702-1712  _repair_glb_colliders / _wire_* / Ladder.build_from_markers  <-- WIRE (after seat)
```

`clear_and_flatten` (`:118`) stages a `ClearingSystem` zone whose `CLEARED` stage carries
`height_flattening: 0.7` (`terrain/systems/clearing_system.gd:37-39`), applied as a lerp toward the disc mean
(`:140-148`). It is a **height edit disguised as a vegetation call**, which is exactly why running it after
a sculpt destroys the sculpt.

**This ordering is not a detail. It is a bug that already shipped and was fixed**, recorded at
`site_planner.gd:2047-2049`: *"the vegetation clear ran after the sculpt and averaged the mound back down,
so the player walked in the gap between the terrain he collided with and the mound he could see."*

### THE REPLAY ORDER — binding

> **1. terrain generate (seed) → 2. veg clear discs → 3. REPLAY `terrain_ops` IN FILE ORDER →
> 4. `_grid.update_region` → 5. audit → 6. instantiate parts → 7. SEAT → 8. wire.**

Nothing may be inserted between 3 and 4. Nothing that flattens may run after 3. **The plan's terrain ops are
the last word on that ground, exactly as the sculpt is today.**

### Why this survives regeneration from a seed

Each op is `(kind, local_xz, radius, params)` — a pure function of the plan, replayed on whatever ground the
seed produced. It **does not encode absolute heights**, so a different seed, a different AO preset
(`terrain_manager.gd:~395 _derive_ao_preset`), or a re-tuned generator changes the ground under it and the
op still means the same thing. That is what "deterministic op" has to mean here, and it is why a baked
heightmap is the wrong artefact.

Two ops need care and I name them so nobody discovers them the hard way:

- **`seat_plateau` must compute its own seat height at replay time**, exactly as `place_firebase_main:1646-1653`
  does (7×7 samples averaged across the footprint). Storing the seat height in the file would pin the site to
  one seed. **Store the SAMPLING RULE, not the answer.**
- **Ops must be idempotent under re-run**, because `region_rebuilt` fires and consumers re-seat. A `trough`
  written as *"subtract 1.1m"* drifts on a second application; written as *"lerp toward (seat − 1.1m)"* it
  does not. **Every op must be expressed as a target, never as a delta.** The existing sculpt already gets
  this right — `lerpf(h, seat_norm, …)` at `:1688` is a target, not a subtraction.

### THE HARD FINDING: a trench is not a terrain op

`WorldConfig.CELL_SIZE = 4.0` (`scripts/levels/world_config.gd:11`). The heightmap samples the world every
**four metres**. A fire trench is 0.8–1.5m wide. **It cannot exist in this heightmap. At all. At any brush
setting.**

The codebase already knows this in two places:
- `site_planner.gd:1680`: *"A 4m heightmap cannot draw any of that at any setting."*
- The fighting step needed an **11m-wide band** to represent a 0.9m shelf, and says why:
  *"the heightmap's 4m cells need a band this wide to represent the shelf at all"* (`site_planner.gd:~1040`).

> **So the trench module is a MESH, seated into a shallow terrain trough that only has to be wide enough for
> the heightmap to express — the same "the model is the ground" ruling the firebase already runs under
> (`site_planner.gd:1676-1685`).** The terrain op's job is to make the mesh not float and not bury itself.
> The trench's floor, revetment, duckboard and firestep are all geometry.

**This is good news, not bad.** It means the tool's terrain half is small (seat, trough, berm, shell hole,
blend) and the WW1 payoff is real — a WW1 field is the same five ops with a different part list. But
**"morph and cut" as he pictures it — sculpting the trench itself out of the ground — is not available at
4m cells, and telling him that now is cheaper than telling him in week three.**
The alternative (drop `CELL_SIZE` to 1.0) multiplies every heightmap cell count by **16** — 400 KB → 6.4 MB,
and every chunk rebuild, collision refresh and grid derive scales with it, on a machine the memory calls
*"19–25 FPS on Intel UHD."* **Refused on the perf bench, not on principle.**

---

## 5 · THE PLACEMENT UX — what "godot model placement" means mechanically

### What Godot 4.7 and this codebase give FREE

| Need | Free from | Cost |
|---|---|---|
| Free-fly camera | **Already written** — `player.gd:1576-1613` photo mode, incl. `reset_physics_interpolation()` | ~0 |
| Ground snap | `TerrainManager.get_height_at()` (`terrain_manager.gd:292`), O(1), no physics | ~0 |
| Slope align | `get_normal_at()` (`terrain_manager.gd:~297`) | ~0 |
| Mouse → world picking | `Camera3D.project_ray_origin/normal` + `PhysicsDirectSpaceState3D.intersect_ray` | ~20 lines |
| Undo/redo | **`UndoRedo`** — a core class, runtime-usable (not the editor-only `EditorUndoRedoManager`) | ~40 lines to wire |
| Part palette UI | `ItemList` / `Tree`; 4.7 adds a **PopupMenu search bar** for filtering | ~80 lines |
| Save/load dialog | `FileDialog` at runtime | ~20 lines |
| Writing the file | `FileAccess` + `JSON.stringify(d, "\t", true)` — the `cursor_editor.gd:263-267` pattern | ~30 lines |
| Input | already-mapped actions in `project.godot` | ~0 |
| Selection highlight | 4.5 **stencil buffer** render modes (`stencil_write_mode`/`stencil_read_mode`) give a clean outline-through-geometry | ~1 shader |

### What must be WRITTEN

- **No runtime 3D gizmo exists in Godot 4.7.** `EditorNode3DGizmo` is editor-only. **Do not build one.**
  Keyboard nudge is a fraction of the cost and, for this job, better: arrow keys nudge 0.25m, shift-arrow
  1.0m, `Q`/`E` yaw by 15°, `shift+Q/E` by 1°, `G` toggles ground-snap. That is exactly the interaction
  `tools/cursor_editor.gd` already uses for hotspots (*"Arrows nudge by one source pixel, shift-arrows by
  five"*) and he has used it before.
- **Ghost preview** — instantiate the part at 40% alpha under the cursor before commit.
- **The brush** — radius/strength ring drawn with `ImmediateMesh` or a decal, and the op registry.
- **Veg suppression during a stroke** — null `terrain_manager.vegetation_manager`, restore on mouse-up,
  then one `generate_for_chunk` per touched chunk. (~42.5ms/edit saved, §1.2.)

### MVP line-of-code estimate

| Module | File | Lines |
|---|---|---|
| Dev-mode host (boot world, fixed seed, skip enemies, force photo cam) | `tools/site_forge.gd` | 120–160 |
| Terrain brush + op registry (5 ops: seat, trough, berm, shell hole, smooth) | `tools/site_forge_brush.gd` | 180–240 |
| Part palette + ghost + place/rotate/nudge/delete | `tools/site_forge_place.gd` | 220–280 |
| Plan I/O (write + read-back into the tool) | `tools/site_plan_io.gd` | 90–120 |
| UndoRedo wiring | in the above | 40–60 |
| HUD (palette list, op list, readouts, save/load) | `tools/site_forge.tscn` + ~120 lines | 120–160 |
| **Replay — the only part that touches game code** | `scripts/world/site_planner.gd` `stamp_site_plan()` | **150–220** |
| **TOOL TOTAL** | | **~920–1,240 lines** |

`stamp_site_plan()` is the only file under ADR-041's FROZEN list. Everything else is new files in
`res://tools/` and `res://data/`. That containment is deliberate and it is what makes this costable.

---

## 6 · DETERMINISM HAZARDS

ADR-041 §8's three, re-verified live:

1. **`_ready()` fires before the seat.** `place_firebase_main` adds at `:1696` and sets `global_position` at
   `:1701`; `Ladder.build_from_markers` is deliberately called **after** at `:1707` with the comment
   *"Ladder caches world positions off the markers, so building before the move would bake them at the wrong
   height."* **LAW: instantiate → seat → THEN wire.** A tool that places parts one at a time must obey the
   same order, per part.
2. **Bare `randf` outside `SEEDED_FILES`.** The whitelist is six files
   (`tests/test_placement_paths.gd:30-37`). `res://tools` is not scanned at all (`:38`). **The tool may use
   `randf` freely — it is authoring. The REPLAYER may not, and it must be added to `SEEDED_FILES` in the same
   change.**
3. **`AnimationPlayer` autoplay** starts at instance time and diverges the visual phase of two identical
   worlds. Convention is manual (`_play_idle`, `site_planner.gd:667-675`). Leave `autoplay` empty.

### Godot-4.7-specific hazards to add

4. **Typed-return override inheritance (4.7 breaking change).** An override of a method with a typed return
   now inherits that return type, and an override without an explicit `return` is a **compile error**. Any
   `@abstract`-style op base class the brush registry uses must return explicitly on every path.
5. **`packed_prop[i] = x` no longer fires the property setter (4.7 breaking change).** This is the exact code
   shape an authoring tool writes. `HeightmapStorage.data` is a bare `var` today (`heightmap_storage.gd:16`)
   so nothing breaks now — but **a future refactor that gives `data` a setter to auto-dirty chunks would
   silently stop firing**, and every edit would render stale with no error. Named here so it is never
   discovered from a screenshot.
6. **`JSON.stringify` writes empty dicts compactly as `{}` even with indent (4.7 change).** Only bites if a
   probe hashes or byte-diffs plan files to assert "replay produced the same plan". Compare **parsed
   structures**, not bytes.
7. **float32 → JSON text → float64 round-trip.** The heightmap is `PackedFloat32Array`; JSON floats are
   decimal text parsed to `float` (64-bit). A parameter written with too few digits will not reproduce the
   same cell values. **Quantise op params to centimetres (integers, or `"%.4f"`) and treat the quantised
   value as canonical.** This is the hazard most likely to produce "it was fine on my machine".
8. **Physics interpolation smear.** Any node the tool teleports — the camera, a part being nudged — needs
   `reset_physics_interpolation()` or it renders a one-frame streak. The shipping photo cam already does this
   (`player.gd:1601`); the placement code must too. This is the project's own PSX-smear bug class.
9. **`region_rebuilt` must be honoured by the tool itself.** `terrain_manager.gd:16` — *"one terrain-change
   channel, every height consumer listens or floats."* If the tool cuts terrain under an already-placed part,
   the part floats unless it re-seats on that signal. **UNVERIFIED: whether `place_structure`'d nodes
   currently subscribe.** Check before writing the brush, or the first thing he sees is a bunker in the air.
10. **`Dictionary` iteration order.** GDScript dictionaries are insertion-ordered and `JSON.parse_string`
    preserves file order — but this is an implementation property, not a documented guarantee. **Ops go in an
    Array. Full stop.**

---

## 7 · COST

Two separate bills. Conflating them is how this gets mis-costed.

### A · THE TOOL — engineering

| # | Step | Hours |
|---|---|---|
| 0 | **Time the patch path** (`StallLedger` window around a patched edit, headless). Decides drag-brush vs click-stamp. **Do this first; it is one hour and it can invalidate step 2.** | 1 |
| 1 | Dev-mode host: `tools/site_forge.tscn` + `.gd` — boot `game_world` at a fixed seed, skip enemy/garrison passes, force photo cam on, HUD off | 2–3 |
| 2 | Terrain brush + op registry (seat / trough / berm / shell hole / smooth) with veg suppression during a stroke | 3–4 |
| 3 | Part palette + ghost + place / yaw / nudge / delete / ground-snap | 4–5 |
| 4 | `UndoRedo` wiring across both brush and placement | 1.5–2 |
| 5 | Plan I/O — write JSON, read it back into the tool for a second session | 2 |
| 6 | **`stamp_site_plan()` in `site_planner.gd`** — veg clear → replay ops → grid update → per-part `place_structure` → seat → wire; site dict listing **every** part in `nodes` (ADR-041 §3 contract 10 and the `test_site_stamp` blind spot) | 4–6 |
| 7 | Probes: (a) **replay determinism** — same plan + same seed twice → identical heightmap and identical part transforms; (b) **marker-vs-navmesh** (ADR-041 §5's binding clause); (c) **add `res://tools` to `test_placement_paths.SCAN_DIRS`** or record the exemption explicitly | 3–4 |
| 8 | Integration + fixing what the probes find | 3–4 |
| | **TOOL TOTAL** | **23.5–31 h** |

A "just let me place things" version that skips steps 4, 7 and half of 6 lands at **12–16h** — and it is the
version ADR-041 §12 already warns will be tempted away. **Step 7 is not optional. Skipping the
marker-vs-navmesh probe is precisely how the chow-hall markers shipped broken** (commit `8e1129c7`: the fix
was 16 markers moved by hand, not code).

### B · THE KIT PARTS — art, not engineering, and NOT my estimate to own

Recorded so the total is honest. **UNVERIFIED — these are my rough shapes, not measured against the asset;
the Blender architect owns these numbers.**

| Work | Hours |
|---|---|
| Dissect `fsb_main_v3.glb` into contract-named parts + per-part `CollisionTable` entries | 10–16 |
| **Trench module — genuinely new** (straight / corner / T / end, plus revetment, duckboard, firestep) | 8–14 |
| Per-part work-point + spawn markers migrated onto the parts they belong to (kills the 488/23 mismatch by construction) | 4–6 |
| **KIT TOTAL** | **22–36 h** |

### C · CALEB'S AUTHORING — separate again

ADR-041 §12 priced village + temple at **6–12h** of his time. One firebase is comparable: **4–8h** for the
first, much less thereafter. **Not engineering hours. Do not add them to A.**

> **HONEST TOTAL FOR "a tool that builds one firebase from a kit": 45–67 engineering hours plus 4–8 of his.**
> The tool alone is 23.5–31. The tool without the kit builds nothing.

---

## 8 · TRADEOFFS — what building this during a ship window sacrifices

**Law 2. No free lunches. Named plainly.**

1. **23–31 hours of engineering that fix zero shipped defects.** The five observations in the briefing —
   the ladder trap, work-point stacking, the Huey dropoff, the convoys, the missing dirt roads — are **all
   still broken the day the tool is finished.** A tool is a multiplier on future work, and a multiplier on
   zero is zero. The demo playthrough (ADR-015) is the open gate.
2. **The tool is useless without the kit, and the kit is 22–36 hours of Blender work** that competes for the
   same art capacity the memory already calls *"the binding constraint."* **The failure mode is a finished
   tool with nothing to place** — the worst possible outcome, because it looks like progress.
3. **`site_planner.gd` is on ADR-041's FROZEN list and step 6 lands inside it.** Any version of this
   requires him to thaw a frozen file. There is no clever way around that and pretending otherwise is how
   scope walls stop working.
4. **A second authoring surface is a second thing that rots.** `tools/` already holds 489 files. When the
   part list changes, the plan format changes, or `CELL_SIZE` changes, the tool breaks — and it breaks
   silently, because nothing on the boot path loads a dev-only script. That exact failure is already
   recorded in this project: `FrameSentinel` never compiled and reported *"0 steps"* through two full bench
   runs (`production/PERF_LEDGER.md:1560-1565`). **The tool needs its own probe or it becomes a lying
   instrument.**
5. **"Morph and cut" will under-deliver against what he pictures.** At 4m cells he can seat, trough, berm
   and pock the ground. He cannot carve a trench. If that gap is discovered at the demo instead of now, the
   tool reads as broken when it is working exactly as the heightmap permits.
6. **In-game dev mode forfeits the inspector and gizmos permanently.** Every property he will ever want to
   tweak is a Control someone has to write. The tool's UI will grow forever, and every hour of it is an hour
   not spent on the game.
7. **The determinism surface widens.** Today the world is a pure function of one seed. After this it is a
   function of a seed **and** N plan files, each of which can go stale against a renamed part, a changed
   `CollisionTable` entry, or a re-tuned generator — and a stale plan fails as a floating bunker, not as an
   error.

### What I would say if asked for one sentence

**The shape is right, the evidence for in-game is overwhelming, the plan-file output is forced by ADR-028,
and the honest price is 45–67 engineering hours for something that fixes none of tonight's five defects —
so the correct move is to ratify the SHAPE now in an ADR and build nothing until the demo ships, exactly as
ADR-041 already ruled for villages.**

---

## SUMMARY OF WHAT I VERIFIED, AND WHAT I DID NOT

**Verified by direct read this session:**
`scenes/levels/game_world.tscn` (whole file, 6 lines) · `scripts/levels/game_world.gd:100-131` ·
`terrain/core/terrain_manager.gd:1-16, 56-65, 79, 98, 229, 240, 292, 304-320, 321-354, 356-381` ·
`terrain/core/heightmap_storage.gd` (whole file) · `terrain/core/terrain_engine.gd:1-10` ·
`terrain/systems/clearing_system.gd:1-60, 120-160` · `terrain/systems/damage_system.gd:225-248` (READ ONLY —
another agent owns this file) · `scripts/world/site_planner.gd:950-1050, 1645-1712, 2040-2075` ·
`scripts/missions/mission_generator.gd:619-700, 877-960` · `tests/test_placement_paths.gd:1-100` ·
`tools/probe_chunk_patch.gd:1-140` · `tools/cursor_editor.gd:1-40, 254-267` ·
`scripts/player/player.gd:1570-1640` · `scripts/levels/world_config.gd:9-11, 40, 45-46` ·
`scripts/main/game_flow.gd:586, 624` · `project.godot:17-45, 66` ·
`scripts/autoload/save_manager.gd` (grepped whole file for terrain/heightmap — zero hits) ·
`production/PERF_LEDGER.md:1560-1600`.

**UNVERIFIED, named so nobody treats it as measured:**
- **The cost of a PATCHED chunk edit.** Only the FULL rebuild (81.5ms) is in the ledger.
  `tools/probe_chunk_patch.gd` proves correctness, not cost. **This is the single biggest technical unknown
  and it is one hour of work to close.**
- Whether nodes placed by `place_structure()` currently subscribe to `region_rebuilt` and re-seat.
- The kit-parts hour estimates in §7B — mine, rough, and the Blender architect's to own.
- The 4m-cell trench conclusion is derived from `CELL_SIZE = 4.0` plus two in-code statements; it has not
  been demonstrated by cutting one and looking at it.

**A stale comment found in passing, recorded so it stops misleading readers:**
`site_planner.gd:1659-1662` says *"the terrain reproduces the model's OWN mound surface, exactly, from the
manifest"*. Twenty lines later `:1676-1680` says *"it does NOT reproduce the mound any more"*, and the actual
lambda at `:1686-1688` is a flat `lerpf(h, seat_norm, …)` plateau. `fsb_mound_height()` (`:998`) is now read
only by `_audit_one_ground` (`:2065`). **The second comment is the truth; the first is a fossil.** Anyone
costing the sculpt off the first paragraph will over-estimate it badly.
