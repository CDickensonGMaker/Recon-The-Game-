# WATER READABILITY ARCHITECT — analysis

**Convened:** 2026-08-12 · water seating council · four owner questions
**Method:** code read only, no edits. Every assertion carries `file:line` (POINTER LAW).
**Reference geometry used for the numbers below**
- `terrain/core/terrain_manager.gd:20` `cell_size = 2.0` m
- `terrain/core/heightmap_storage.gd:22-23` `size = ceil(map/cell)` rounded up to a multiple of 64
- Demo AO (512 m, `scenes/levels/demo_game.tscn`): `heightmap.size = 256`
- Full AO (3072 m): `heightmap.size = 1536`
- Hydrology downsample `terrain/core/terrain_manager.gd:100` `= max(1, round(size/450))`
  → **1 on the demo (hydrology cell = 2.0 m), 3 on the full AO (hydrology cell = 6.0 m)**
- `water_map_cell_size = heightmap.cell_size = 2.0` (`terrain/water/water_system.gd:70`)

---

## Q1 — DOES THE PLAYER HAVE SWIMMING?

**No. MISSING FEATURE (ADR-023 triage).** Not a fossil, not unfinished — nothing was ever built.

Repo-wide there is no swim state, no buoyancy, no water-entry transition, no encumbrance term,
no weapon-overhead pose. The only `swim` token in the entire codebase is a loop-name prefix in
the animation player:

- `scripts/visuals/model_actor.gd:338`
  `const _LOOP_PREFIXES: Array[String] = ["idle", "run", "walk", "sprint", "strafe", "swim", "firing"]`
  — a string in a loop-detect list. No clip named `swim*` is ever requested. This is a
  **FOSSIL string**, not evidence of a system.

### The player's ENTIRE water awareness, in full

`scripts/player/player.gd:305-333` — `_play_footstep_sound()`. That is the whole of it:

| line | what it does |
|---|---|
| `player.gd:309` | `if _grid.is_water(global_position):` — swaps the footstep WAV to `STEP_WATER` |
| `player.gd:311-318` | `_wade_timer += 0.5`; past 20 accumulated steps → toast `"LEECHES. GODDAMN LEECHES."` and `take_damage(3, PHYSICAL)` |
| `player.gd:319` | out of water, the leech timer bleeds back down |
| `player.gd:322-326` | dry `RICE_PADDY` also plays `STEP_WATER` and sets `_in_rice_paddy` |

Note this fires **from the footstep callback only** — it is a cosmetic/attrition hook hung off
the walk cycle. It is not a state, it is not consulted by movement, and it has no exit condition
other than not stepping.

### What happens if he walks into water deeper than he is tall

The character controller does not consult water at any point:

- `scripts/player/player.gd:1601-1603` — `_handle_gravity()`:
  ```
  func _handle_gravity(delta: float) -> void:
      if not is_on_floor():
          velocity.y -= gravity * delta
  ```
  Unconditional. No buoyancy term, no water check, no drag.
- `scripts/player/player.gd:1593-1598` — `_handle_gravity(capped_delta)` then `move_and_slide()`.
  A plain `CharacterBody3D` step.
- Terrain collision is real and on the world layer:
  `terrain/core/terrain_chunk.gd:222-231` builds a `StaticBody3D` with
  `collision_layer = 1` (world) from `create_trimesh_shape()`.
- The water mesh has **no collider at all** — `water_system.gd:278-282` builds a bare
  `MeshInstance3D` named `CombinedWater` with `cast_shadow = OFF`. No `StaticBody3D`, no `Area3D`.
  The water is a decal in 3D. Nothing can detect entering it.

**So: the player WALKS ALONG THE BED.** He clips through the ribbon, keeps walking at
`WALK_SPEED`, and surfaces on the far bank. The camera sits at head height 1.7 m above the bed
while the sheet sits `bed + 0.05 … bed + 0.55` (`water_system.gd:340-341`) — i.e. **the water is
around his shins even in the deepest channel on the map**, because the surface is pinned to the
bed rather than to a level.

The one saving grace, and it is an accident: because `_carve_riverbed` accumulates (measured mean
7.97 m against the 1.20 m constant, `terrain/core/terrain_manager.gd:433-434`), walking into a
channel currently drops the player 8 m into a dry trench with a shin-deep puddle at the bottom.
That is worse for readability than no water at all.

**There is also no NPC/AI equivalent.** `scripts/enemies/enemy_base.gd:1007` is the only enemy
water line and it only suppresses scent crumbs:
`var leaves_sign: bool = _grid == null or not _grid.is_water(target.global_position)`.

---

## Q2 — CAN THE PLAYER FORD DEEP WATER?

**No fording exists. No depth-dependent behaviour reaches the player at all.** The wade gate is
UNFINISHED (built ahead of its wiring) — and worse than the briefing states, because it is now
*firing* and still changing nothing.

### The briefing's premise is STALE — correct it

Briefing line 58 asserts `get_water_depth()` returns 0.5 m everywhere. **That was true before
`terrain/water/hydrology_map.gd:519` was added; at current HEAD it is false.** The chain:

1. `hydrology_map.gd:519` — `_surface_h[i] = _elev[i] - CHANNEL_SURFACE_DROP` (0.65 m,
   `hydrology_map.gd:53`). `_elev` is **pre-carve** grade: `terrain_manager.gd:379` runs
   `hydro.generate(heightmap)` and only then `:382` runs `_carve_riverbed(path)`.
2. `hydrology_map.gd:545-564` `_upsample_outputs()` copies `_surface_h → water_surface_full`
   (`:552` for downsample 1, `:564` otherwise). Verified — the surface *is* propagated.
3. `water_system.gd:420-422` computes
   `depth = max(0, water_surface_full[i] - current_terrain)`
   `depth_index = clampi(int(depth * 2.0), 0, 31)`

Substituting: `depth = (grade − 0.65) − (grade − carve_accum) = carve_accum − 0.65`.
With the probe's measured mean carve of **7.97 m** → depth ≈ **7.32 m** → index 14 → 
`get_water_depth()` returns **7.0 m**. With the max carve of 34.19 m → index saturates at 31 →
**15.5 m**.

**So the wade gate at `terrain/core/gameplay_grid.gd:136-139` DOES now fire, on essentially every
channel cell, and it is reporting the CARVE BUG as WATER DEPTH.** It is not measuring water. It is
measuring how far `_carve_riverbed` over-subtracted.

### And it still does nothing, because `is_passable` has one reader

`gameplay_grid.gd:139` writes `is_passable[idx] = 0`. Repo-wide readers of that array:

- `scripts/missions/mission_generator.gd:144` —
  `if world.gameplay_grid.is_position_passable(p) and not world.gameplay_grid.is_water(p):`
  **It already ANDs with `not is_water`.** Water is rejected by the second clause whether or not
  the wade gate fired. The gate is provably inert at its only call site.
- `tools/probe_riparian.gd:69` and `:132` — a diagnostic tool, not gameplay.

Nothing else. No nav bake, no AI, no player. `WADE_DEPTH_M` is **UNFINISHED: a gate wired to a
flag nobody acts on.**

### `MOVEMENT_COSTS[WATER]` — the prior architect's claim is REFUTED

The claim was that `road_network.gd:163` is the only reader. There are **three** readers of
`GameplayGrid.MOVEMENT_COSTS` (`terrain/core/gameplay_grid.gd:27-36`, `WATER: 99.0` at `:34`):

| reader | what it does with WATER |
|---|---|
| `scripts/world/road_network.gd:163-167` | reads `MOVEMENT_COSTS.get(ttype)` then **immediately overrides**: `if ttype == WATER: base = WATER_COST` (24.0, `road_network.gd:40`). The 99 is discarded. Roads ford. |
| `scripts/enemies/patrol_generator.gd:71-75` | `_is_walkable()` — `cost = MOVEMENT_COSTS.get(tt, 99.0)`, `return cost <= WALKABLE_COST_MAX`. This one **honours 99**: enemy patrol waypoints avoid water. It is the only live consumer of the 99. |
| `scripts/player/player.gd:1708` | reads **only** `MOVEMENT_COSTS[RICE_PADDY]`. Never indexes WATER. |

So the value is not dead, but it never reaches the player.

### The paddy/creek inversion — CONFIRMED, and it is exactly backwards

`scripts/player/player.gd:1706-1708`:
```
# A flooded rice paddy drags at your legs.
if _grid != null and _grid.get_terrain_type(global_position) == GameplayGrid.TerrainType.RICE_PADDY:
    current_speed /= float(GameplayGrid.MOVEMENT_COSTS[GameplayGrid.TerrainType.RICE_PADDY])
```
That is a **÷1.8, i.e. a 44 % speed loss**, and it is the only terrain speed modifier the player
has. `RICE_PADDY` comes from `TerrainZoning.classify()` (`terrain/core/terrain_zoning.gd:74-77`)
— a *noise band under a height ceiling*. It is a DRY classification. There is no water test on it
anywhere.

Meanwhile `TerrainType.WATER` **overrides** the zoning result before it is ever stored
(`gameplay_grid.gd:270-279`: the `is_water` branch returns first), so a cell that is real water is
never `RICE_PADDY` and never hits the `:1707` branch.

**Verdict: the DRY paddy halves your speed. The WET creek is free.** The comment on `:1706`
("A flooded rice paddy drags at your legs") describes water that is not there, while the water
that *is* there costs nothing. This is the single most legible gameplay defect in the water stack
and it is a two-line fix.

---

## Q3 — ARE PLANTS / PROPS PREVENTED FROM SPAWNING UNDER WATER?

**Partially, and the half that is protected is the half that matters least.** The complete list of
`is_water` callers repo-wide (grep, whole tree, `--include=*.gd`) is the authority here — anything
absent from it does not check:

```
scripts/autoload/audio_manager.gd:132        (footstep audio)
scripts/enemies/enemy_base.gd:1007           (scent crumbs)
scripts/missions/mission_generator.gd:144    (patrol/spawn point picking)
scripts/player/player.gd:309                 (footstep audio + leeches)
scripts/ui/topo_map.gd:82 / topo_sheet.gd:109 (map render)
scripts/world/ground_clutter.gd:204          (clutter scatter)  <-- the ONLY scatter system
scripts/world/site_planner.gd:102,483,630,646,1190
tests/…, tools/water_view.gd                 (probes)
```

### The scatter systems, one by one

| system | water check? | pointer |
|---|---|---|
| **`terrain/vegetation/vegetation_manager.gd`** — the 117-species GLB canopy, TREE_COVER path | **NONE. Places blind.** | `_determine_terrain_type()` at `:273-278` returns `CLEAR` on steep slope else `TerrainZoning.classify(...)`. `TerrainZoning` has **no water branch** — `terrain/core/terrain_zoning.gd:10-11` states outright *"WATER/CLIFF (6/7) are pathing-only overrides the callers apply BEFORE calling classify()"*. `VegetationManager` is a caller that **does not apply the override**. It holds no `water_system` reference at all. |
| **`terrain/vegetation/tree_cover_layer.gd`** | **NONE.** Zero occurrences of `water` in the file. It consumes `_build_scatter()` (`vegetation_manager.gd:498`) which is derived from the same water-blind `_chunk_terrain` grid. | `vegetation_manager.gd:483-485` |
| **`terrain/vegetation/jungle_patch_layer.gd`** — the authored jungle patches | **NONE, and the code comment lies about it.** `:250-252` `if not TYPE_DENSITY.has(ttype): continue  # CLEAR / water: bare`. `TYPE_DENSITY` (`:41-47`) keys only 1–5. But the `terrain` byte array it is handed comes from `vegetation_manager.gd:260-261` and **can never hold 6 (WATER)**. The "water: bare" arm is unreachable — a **tombstone comment describing a guard that does not exist**. | `jungle_patch_layer.gd:251-252` |
| **`scripts/world/ground_clutter.gd`** — the 8 clutter layers | **YES.** `_accept()` at `:201-208`: `if world.gameplay_grid.is_water(pos): return false`. Correct, and re-evaluated on terrain edits via the deferred flush (`:176-197`). | `ground_clutter.gd:204` |
| **`scripts/world/site_planner.gd`** — sites, villages, huts, props, FSB siting | **YES, five gates.** `:102` site-validity ring samples; `:483` `_prop_point()`; `:630` `_scatter_huts()`; `:646` `_dry_point()`; `:1190` FSB scoring (`score -= 10.0` — soft, not a veto). | as listed |
| **`scripts/world/road_network.gd`** | **No `is_water`.** Routes on `_grid.get_terrain_type_at()` (`:156`) and deliberately **fords** water at cost 24 (`:164-167`). Intentional, documented at `:37-39`. Not a defect, but it means roads run through channels. | `road_network.gd:163-167` |
| **`scripts/world/ambient_encounters.gd`** | **Indirect — SAFE.** All four placements go through `MissionGenerator._passable_near` (`:102, :114, :242, :405`), which checks water at `mission_generator.gd:144`. | |
| **`scripts/world/paddy_stamper.gd`** | No water check, but it flood-fills `RICE_PADDY` cells only (`:55, :109`), and a real water cell is never classified `RICE_PADDY` (`gameplay_grid.gd:270-274` returns WATER first). Safe by construction. | |
| rocks / logs / mushrooms | These are clutter LAYERS (`ground_clutter.gd:30-32`), covered by `:204`. There is no separate 3D-rock scatter system in `scripts/` or `terrain/`. | |

**Summary: trees are the whole problem.** Grass, huts, props and villages are gated. The canopy —
the tall thing whose silhouette actually tells the player "this is a riverbed" or doesn't — is the
one system with no gate anywhere in its path.

### THE MASK IS A HAIRLINE — quantify the exposure

Even a correct `is_water()` check only protects a stripe. `hydrology_map.gd:495-513` traces the
channel and writes `_type_h[i]` **for the single D8 flow-path cell**. The width `w`
(`:507-508`, `river_width_base 2.0` + `scale·√accum`, clamped to `river_width_max = 40.0`,
`hydrology_map.gd:62-64`) is appended to `widths` — which is consumed **only** by the render
ribbon (`water_system.gd:319-330`) and by the carve (`terrain_manager.gd:411-413`).
**Width is never rasterised into the type grid.** `_upsample_outputs()` (`:545-564`) then simply
blows that one hydrology cell up to `downsample²` heightmap cells.

Therefore the gameplay water mask is exactly **one hydrology cell wide**:

| AO | hydrology cell | mask width | rendered ribbon | **unprotected fraction of the ribbon** |
|---|---|---|---|---|
| Demo 512 m (downsample 1) | 2.0 m | **2.0 m** | 2.0 – 40.0 m | 0 % on a headwater trickle → **95 % on a trunk river** |
| Full AO 3072 m (downsample 3) | 6.0 m | **6.0 m** | 2.0 – 40.0 m | 0 % → **85 % on a trunk river** |
| typical 6 m creek | 2.0 / 6.0 m | 2.0 / 6.0 m | 6.0 m | **67 % / 0 %** |

And the **carved trench is wider still**: `terrain_manager.gd:414-418` sets
`shoulder = max(half_w·0.6, cell_size)`, `reach = half_w + shoulder`,
`carve_radius = clamp(ceil(reach/cell_size), 2, 14)` — up to **14 cells = 28 m radius, a 56 m-wide
trench**. So on a trunk river the ground is visibly gouged across 56 m, the water sheet spans 40 m,
and the mask that any system could consult covers 2–6 m of it.

**Net: on a trunk river, grass is correctly culled from a 2–6 m stripe and happily planted across
the remaining ~34 m of open water; trees are planted across all 40 m regardless.**

### THE INVERSE — is the 22 m gallery belt pushing vegetation INTO the waterline?

`gameplay_grid.gd:151-153`: `RIPARIAN_M = 22.0`, `GALLERY_MIN = 0.55`, `GALLERY_MAX = 0.95`.
`_apply_riparian_belt()` (`:177-226`) BFS-dilates from every WATER cell and at `:219-223` sets
density `lerpf(0.55, 0.95, t)` — **densest at distance 1 cell from the water** — and *rewrites the
terrain type* to `HEAVY_JUNGLE` at ≥0.85. `_roof_the_creeks()` (`:232-267`) then closes a canopy
over the water cells themselves.

**But this belt is invisible.** It writes to `GameplayGrid.vegetation_density` /
`GameplayGrid.terrain_type`, and **no visual system reads either array.** `VegetationManager`
derives its own grid from `TerrainZoning.classify()` (`vegetation_manager.gd:273-278`) and never
touches `GameplayGrid`. `JunglePatchLayer` is handed *that* grid (`vegetation_manager.gd:485-488`).

So the load-bearing comment at `gameplay_grid.gd:148-150` —
> *"JunglePatchLayer.TYPE_DENSITY and VegetationManager.TYPE_PROPS map the SAME verdict to visuals
> — so the jungle the AI reads is the jungle the player sees"*

— is **true for the base zoning and FALSE for the riparian belt and the creek roof**, which are
`GameplayGrid`-only post-passes with no visual counterpart. **DRIFT: correct this comment on
contact.** The measurable consequence is the inverse of the owner's fear:

- the AI's `_sight_cap()` sees a 22 m wall of 0.55–0.95 gallery forest along every channel and
  clamps sight toward 45 m,
- the player sees ordinary noise-zoned jungle with no bank treeline at all,
- **and the trees he does see are placed with no idea the river exists.**

Both halves are wrong, in opposite directions, from the same missing link.

---

## Q4 — DO CREEK / RIVER BEDS GET A SAND OR MUD TEXTURE?

**No bed texture exists, and there is no splat system to hang one on.** MISSING FEATURE.

### What the terrain material actually is

`terrain/shaders/terrain.gdshader` — **there is no splatmap anywhere in this project**
(grep `splat` across `*.gd` + `*.gdshader` returns only blood-decal hits in
`scripts/combat/gun_fx.gd`). The material is:

| layer | pointer | occupied by |
|---|---|---|
| ONE tiled ground texture set | `:4-6` `ground_diffuse` / `ground_normal` / `ground_roughness` | `jungle_floor_diff.jpg` / `_normal.jpg` / `_rough.jpg`, bound at `terrain/core/terrain_chunk.gd:130-150` |
| vertex COLOR | `:57`, `:70` | `terrain_chunk.gd:195-211` `_get_terrain_color()` — branches on **only two** types: `1 RICE_PADDY → (0.42,0.58,0.22)` and `5 HEAVY_JUNGLE → (0.10,0.22,0.07)`, else a flat base green. It reads the `vegetation_terrain` bundle array, which **never contains 6 (WATER)** (same root cause as Q3). |
| `clearing_texture` (RGBA, mixed by its own alpha) | `:15`, `:100-101` | `ClearingSystem`, bound at `scripts/levels/game_world.gd:525` |
| `wetness_texture` (R8) | `:18-20`, `:107-114` | the water system — see below |

Only **three** textures exist under `terrain/textures/`: `grass_base.png` and the three
`jungle_floor_*` maps. There is **no sand, mud, silt, gravel or riverbed tile in the project.**
(`fb_mud.png` under `assets/world/building models/structures/firebase/tex/` is a *building* UV
atlas for the firebase kit, not a terrain tile.)

### The wetness texture IS wired — and it is a tint, not a bed

The chain the prior session's log line came from, end to end:

1. `terrain/water/water_system.gd:526-573` `generate_wetness_texture(fade)` — builds
   `Image.FORMAT_R8`, size `water_map_size × water_map_size` (`:527`), R = 1.0 on water cells
   (`:533-534`), then a brute distance-field fade outward (`:541-567`). Prints at `:570`.
2. `scripts/levels/game_world.gd:167-169` — `generate_wetness_texture(16.0)` →
   `TerrainChunkScript.set_shader_texture("wetness_texture", wetness_tex)`.
   (This is the source of the `320x320, fade 16.0m` log the prior session saw.)
3. `terrain_chunk.gd:175-180` `set_shader_texture()` → `shared_material.set_shader_parameter`.
4. `terrain.gdshader:107-114` consumes it:
   ```
   float wetness = texture(wetness_texture, uv).r * wetness_strength;
   if (wetness > 0.01) {
       vec3 wet_color = mix(color, wet_tint.rgb, wetness * 0.7);
       wet_color *= 1.0 - wetness * 0.3;
       color = wet_color;
   }
   ```

**So it is live, not a fossil.** The UV is sound: `:96` `uv = world_pos.xz / (terrain_size *
cell_size)`, and `game_world.gd:476-477` sets both uniforms from `heightmap.size` /
`terrain_manager.cell_size` at `_setup_terrain_shader_textures()` (`game_world.gd:160`), which runs
**before** the wetness bind at `:169`. The early placeholder bind at `game_world.gd:136-139`
(`terrain_size: 385, cell_size: 4.0`) is overwritten. Image is `size × size`, UV normaliser is
`size · cell` — they agree to within a half-texel.

**But what it produces is not a riverbed.** Three reasons it cannot read as sand or mud:

1. **It is a global darken toward one flat colour.** `wet_tint = (0.15, 0.12, 0.08)`
   (`terrain.gdshader:20`), `wetness_strength` default 0.6 (`:19`, never overridden — it is not
   in the `params` dict at `game_world.gd:474-482`). Peak effect is `mix(…, 0.42)` plus an 18 %
   darken. No texture change, no roughness change, no normal change. It reads as *shadow*, not
   as *wet silt*.
2. **It is painted from the same hairline mask.** It is built from `water_map` (`:533`), so its
   core is the 2–6 m stripe of Q3. On a 40 m river the "wet" core covers 5–15 % of the surface
   and the 16 m fade smears symmetrically over both banks — i.e. the tint is applied *more* to
   the dry banks than to the bed.
3. **It cannot distinguish bed from bank at all.** One scalar, monotone with distance. Bed and
   bank at the same distance get the same value.

### What it would take to add a bed texture

There is no splat channel to spend, because there is no splat. Three routes, cheapest first:

- **(a) Reuse the wetness texture as a two-channel mask — no new asset, no new draw.**
  Promote `Image.create(..., Image.FORMAT_R8)` (`water_system.gd:527`) to `FORMAT_RGBA8`, keep
  the fade in R, and write a hard bed mask in G (built from the channel polylines + `widths`,
  which the water system already holds at `_create_river_body`, `water_system.gd:143-153`, but
  currently only uses for the ribbon). B and A are then still free for future use. Add ONE new
  sampler + one `mix()` to `terrain.gdshader`. This is the only route that also *fixes the width
  problem for the visual*, because it can rasterise `widths` even while `_type_h` stays a
  centreline.
- **(b) A vertex-colour case.** Add `6: return <silt brown>` to `terrain_chunk.gd:195-211`.
  Zero shader cost — but it is dead until the `vegetation_terrain` bundle array can carry
  WATER, which is the same missing plumbing as Q3. Also quantised to the bundle grid
  (12 m tiles) — far too coarse for a 6 m creek.
- **(c) A real splat pass.** New RGBA control texture + 2–4 extra samplers. Correct long-term,
  clearly out of scope for a readability fix, and it would want an art dependency (an actual
  wet-silt / river-gravel tile) that does not exist in the tree.

---

# RECOMMEND — ordered, with cost and with what is sacrificed

The premise of every item below is that the **geometry fix lands first** (level cut instead of
relative subtract in `terrain_manager.gd:434`, and a channel width that is not 40 m). None of this
reads correctly on top of an 8 m trench. These are the additional things that must be true.

---

### R1 — RASTERISE `widths` INTO `_type_h`. *The single highest-value change on this list.*
**Where:** `terrain/water/hydrology_map.gd:495-513` — inside `_trace_channel`, stamp a disc of
radius `w/2` into `_type_h` (and `_surface_h`) instead of the single cell at `:513`.
**Why it is first:** every other item on this list is downstream of it. The clutter gate
(`ground_clutter.gd:204`), the terrain-type gate, the mud tint, the AI's riparian belt, a future
tree gate and a future wade gate all read the same mask, and today that mask is 2–6 m wide under a
40 m river. Fixing one consumer while the mask is a hairline fixes 5–15 % of the problem.
**Cost:** O(channel cells × w²) at generation, once, behind the loading screen. On the demo the
whole hydrology pass is a 256² grid — negligible. On the full AO, ~106 channels × ~200 points ×
up to a 20-cell radius disc; low hundreds of thousands of byte writes. Under 100 ms.
**Sacrificed:** the water footprint in `GameplayGrid` grows by roughly the ribbon area. That
**expands the 22 m riparian belt outward from a wider source** (`gameplay_grid.gd:177-226`), which
raises `vegetation_density` over more cells and therefore **lowers the AI sight cap over more of
the map**. This is the exact failure mode the briefing warns about at line 63 for pooling, arriving
by a different door. It must be measured with `tools/probe_riparian.gd` before and after, and
`RIPARIAN_M` may have to come down from 22 m to hold the sight budget.

---

### R2 — GATE THE CANOPY ON WATER. *The readability fix the owner actually asked for.*
**Where:** `terrain/vegetation/vegetation_manager.gd:273-278`. Give `VegetationManager` the
`water_system` reference its own comment at `:93` already claims it holds
(*"TerrainManager reference for water proximity checks"* — a **FOSSIL comment: delete or make
true**), and apply the override `TerrainZoning` explicitly delegates to its callers
(`terrain_zoning.gd:10-11`): return `6 (WATER)` before calling `classify()`.
Then the unreachable arm at `jungle_patch_layer.gd:251-252` (`# CLEAR / water: bare`) becomes
live for free, and `_build_scatter()` (`:498`) starves `TreeCoverLayer` of water bundles with no
change to that file.
**Cost:** one `is_water()` call per bundle at chunk build — the same call `ground_clutter.gd:204`
already makes per clutter instance, at a fraction of the rate. Effectively free.
**Sacrificed:** the bundle grid is coarse (12 m tiles, `jungle_patch_layer.gd:54`). A 6 m creek
will either lose a whole 12 m tile of canopy or none of it — expect either a chunky bald corridor
or leakage, and the fix is sub-bundle sampling, which is not free. Also: **fewer trees is fewer
tris but also less concealment**, and the AI's sight cap will not know (see R6). Do R2 and R6 in
the same change or the divergence gets worse, not better.

---

### R3 — MAKE THE WET CREEK COST MORE THAN THE DRY PADDY.
**Where:** `scripts/player/player.gd:1706-1708`. Add a water branch above the paddy branch. The
data is already there — `_grid.get_water_depth()` exists (`gameplay_grid.gd:370-373`) and now
returns real metres (Q2).
**Why:** this is the cheapest thing on the list that the player will *feel*. Right now the only
terrain speed penalty in the game is a 44 % tax on **dry ground**, and stepping into a river is
free. Nothing else needs to change for water to start reading as an obstacle.
**Cost:** ~6 lines. One grid query per physics frame, already being made at `:1707`.
**Sacrificed:** it will feel wrong until R1 lands — the penalty will snap on and off across a
2–6 m stripe in the middle of a 40 m river. **Sequence R1 before R3, or ship R3 keyed off
`is_water` only (binary) and add the depth ramp after R1.** Also: any speed tax on water makes
channels tactically expensive, which cuts against Pillar 3 (Freedom) if the multiplier is set
anywhere near the paddy's 1.8. Recommend ~1.3 at wading depth.

---

### R4 — DECIDE WHAT `get_water_depth()` MEANS, THEN EITHER WIRE OR CUT `WADE_DEPTH_M`.
**Where:** `terrain/water/water_system.gd:420-422` and `terrain/core/gameplay_grid.gd:136-139`.
Today the function returns `carve_accumulation − 0.65` (Q2) — it reports the carve bug as depth,
and it saturates at 15.5 m. Once the carve is level-cut it will return ≈ `CHANNEL_WATER_DEPTH`
(0.55 m) everywhere, which is below `WADE_DEPTH_M = 1.2` — **so after the geometry fix, the wade
gate goes back to never firing, permanently.** That is the honest outcome given
`min_lake_depth = INF` (`hydrology_map.gd:45`): *there is no deep water anywhere in the AO*.
**The ADR-023 call:** `WADE_DEPTH_M` and the `gameplay_grid.gd:137-139` branch are **UNFINISHED**.
Its only reader (`mission_generator.gd:144`) already ANDs with `not is_water` and is unaffected by
it. Either give the AO deep water (a channel-depth term keyed to `widths`, so trunk rivers are
genuinely unfordable) — **or delete the branch and the constant** and let `is_water` alone carry
the meaning.
**Cost:** deletion is free and removes a lie from the map. Wiring it means a depth model.
**Sacrificed:** deleting it forecloses "this river is too deep to cross" as a level-design lever
until swimming exists. Given Q1, that lever has nothing behind it anyway.

---

### R5 — GIVE THE BED A DIFFERENT SURFACE, via the mask that already exists.
**Where:** `terrain/water/water_system.gd:527` (`FORMAT_R8 → FORMAT_RGBA8`, bed mask in G) +
`terrain/shaders/terrain.gdshader:18` (one new `bed_diffuse` sampler, one `mix` near `:107-114`).
Route (a) from Q4. Needs one art asset — a wet-silt / river-gravel tile — which **does not exist in
`terrain/textures/` and must be authored.**
**Why after R1–R3:** a bed texture on correctly-seated, correctly-masked, correctly-costed water
is the finish. A bed texture on today's geometry paints a brown stripe down the middle of a dry
trench.
**Cost:** one texture sample per terrain fragment (the shader already takes 5). One new asset.
**Sacrificed:** GPU budget on the largest-area material in the game, on a low-end target. Also
`wetness_strength` is currently never set (`game_world.gd:474-482` omits it) and defaults to 0.6 —
whatever is authored will be fighting an unowned tint. Set it explicitly in the same change or
the bed will read as mud-under-shadow.

---

### R6 — CLOSE THE AI/VISUAL RIPARIAN DIVERGENCE, or delete the belt.
**Where:** `terrain/core/gameplay_grid.gd:145-153` (`_apply_riparian_belt`) and `:232-267`
(`_roof_the_creeks`) write density and terrain type that **no visual system reads** (Q3, inverse).
The comment at `gameplay_grid.gd:148-150` asserts the opposite and is **DRIFT — correct it in
whatever change touches this file, per the standing law.** Either have `VegetationManager` consult
`GameplayGrid.get_vegetation()` for a bank-density boost so a gallery treeline is actually built,
or accept that the belt is an AI-only concealment field and say so in one honest line.
**Cost:** the honest-comment version is free. The build-the-treeline version is a real feature and
should be its own council.
**Sacrificed:** building the visible belt puts *more* trees near water — directly opposed to R2 —
so the two must be designed together: **no trees IN the channel, a dense treeline ON the bank.**
That combination is also, not coincidentally, the thing that would make a river read as a river
from 100 m out. It is the right end state and it is the most expensive item here.

---

## THE ONE-LINE ANSWER

Water in this build is a **texture-less, collider-less, cost-less decal**, seated to a bed that
accumulated ~8 m of carve, masked for gameplay by a 2–6 m hairline down the centre of a 40 m
ribbon, with the tall vegetation that would tell the player where the river is placed by a system
that has never been told rivers exist — while the only terrain that slows him down is a **dry**
rice paddy.
