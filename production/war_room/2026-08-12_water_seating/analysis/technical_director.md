# TECHNICAL DIRECTOR — terrain generation and the blast radius of changing it

**Convened:** 2026-08-12 · **Lens:** terrain generation, heightmap consumers, sequencing
**Method:** read the code. Every assertion carries `file:line` (POINTER LAW).
**Verified map geometry:** `MAP_SIZE 1280.0` (`scripts/levels/world_config.gd:9`), `CELL_SIZE 4.0`
(`:11`) → `heightmap.size == 321`, so `TerrainManager._extract_and_carve_rivers`'s
`downsample = maxi(1, int(round(321.0/450.0))) == 1` (`terrain/core/terrain_manager.gd:370`).
**The hydrology grid IS the heightmap grid on the shipping map: `_hcell == 4.0 m`, `_hsize == 321`.**
Every number below is computed on those figures, not assumed.

---

## 1. VERDICT ON THE ARBITER'S DIAGNOSIS

| Arbiter's claim | Verdict |
|---|---|
| #1 the carve is relative, not level (`terrain_manager.gd:434`) | **TRUE, and it is a real defect** — but it is a *symptom amplifier*, not the root cause |
| #2 bank samples at ±half_w are garbage (`water_system.gd:337-340`) | **TRUE, and it is the proximate cause of the buried sheet** |
| #3 the ribbon is buried in its own banks | **TRUE**, and worse than stated — see §1.3 |
| implied: fixing the carve fixes the water | **FALSE.** A level cut at the current widths is the most dangerous change on the table (§4) |

### 1.1 The root cause is a WIDTH that nothing else in the pipeline agrees with

There are **three different widths for the same channel**, and no code path reconciles them:

| Quantity | Where | Value on a trunk channel |
|---|---|---|
| **Render ribbon width** | `water_system.gd:329` (`half = widths[i] * 0.5`) | up to **40 m** (`hydrology_map.gd:64` `river_width_max = 40.0`) |
| **Carve reach** | `terrain_manager.gd:416-418` (`reach = half_w + max(half_w*0.6, cell_size)`) | up to **32 m** each side (clamped to 14 cells = 56 m, `:418`) |
| **Gameplay water MASK** | `hydrology_map.gd:513` — `_trace_channel` writes `_type_h[i]` **for the traced cell only** | **one hydrology cell = 4 m** |

That third row is the finding the briefing does not contain. **Width is never rasterised into the
type grid.** `_classify_cells` (`hydrology_map.gd:343-369`) only ever writes LAKE and SWAMP;
`_extract_rivers` (`:439-472`) computes a per-cell `is_channel` but discards it; `_trace_channel`
(`:493-539`) marks exactly the cells it walks. `_upsample_outputs` (`:545-564`) is a nearest-neighbour
copy and with `downsample == 1` it is a straight `duplicate()` (`:550-553`). So:

- `WaterSystem._build_water_map_from_hydrology` (`water_system.gd:408-427`) builds a **4 m-wide**
  water map for a **40 m-wide** rendered river.
- `GameplayGrid._determine_terrain_type` (`terrain/core/gameplay_grid.gd:272-274`) therefore
  classifies a 4 m stripe as WATER under a 40 m sheet — **36 m of the visible river is walkable
  dry-land TerrainType to the AI**, and the AI walks on top of the sheet.
- `is_water()` (`water_system.gd:483-490`), `SitePlanner`'s water rejection
  (`scripts/world/site_planner.gd:102, 483, 630, 646, 1190`) and `RoadNetwork.WATER_COST`
  (`scripts/world/road_network.gd:40, 164-167`) all inherit that 4 m lie.

**The generator believes it made a creek. The renderer draws a river. The carve digs a ditch
somewhere between the two.** That is the system-level answer to *"its not following the natural flow
that gets cut in the terrain"*.

### 1.2 The 40 m width is a runaway accumulation — and it is not even dimensionally sound

`hydrology_map.gd:507-508`:

```gdscript
var w: float = clampf(river_width_base + river_width_scale * sqrt(_accum[i]),
        river_width_base, river_width_max)
```

`_accum` is a **cell count** (`_compute_flow_accumulation`, `:293-337`, seeded `fill(1.0)` at `:296`),
not a drainage *area*. Consequences, both measured against the shipping grid:

- **Width saturates at 40 m on a drainage basin of 11,796 cells** — solve
  `2.0 + 0.35*sqrt(a) = 40` → `a = 11,796`. At `_hcell = 4.0 m` that is **0.189 km²**. A real 40 m-wide
  waterway drains hundreds of km². The formula reaches its ceiling on **11.4 % of a 1280 m map**, so on
  any AO with a single dominant valley the trunk is pinned at the 40 m clamp for its whole length.
  The probe's row `i=171, width 40.00` is that clamp, not a measurement.
- **Width is resolution-dependent.** Halve `CELL_SIZE` and the same physical basin yields 4× the cell
  count → 2× the width, for identical terrain. Nothing in the formula divides out `_hcell`
  (`hydrology_map.gd:133` sets it and `:507` ignores it). Any future change to `WorldConfig.CELL_SIZE`
  (`world_config.gd:11`) silently doubles every river in the game.
- **`creek_threshold = 200.0`** (`hydrology_map.gd:59`) is likewise cells → **3,200 m²** of drainage
  spawns a channel. That is a hillside gully. It is why the probe found **106 channels**.

**40 m trunks are runaway accumulation, not intent.** The comment at `:61` calls it
"base + scale * sqrt(accumulation)" and never states the unit; the unit is the bug.

### 1.3 The flatness gate certifies 4 m and authorises 40 m

`_extract_rivers` rejects steep cells with `_local_slope(...) > river_max_slope` (`hydrology_map.gd:456`,
`river_max_slope = 0.15` at `:69`). But `_local_slope` (`:372-383`) samples **one hydrology cell = 4 m**
in each of 8 directions. So the "valley floor only" gate certifies gentleness over a **4 m window**
and then licenses a **40 m ribbon** and a **56 m carve** across ground it never looked at.

This is why the probe sees `bank_l` 5 m BELOW `bed`: at `i=171`, `grade 148.53` vs `bed 141.42` is a
**7.1 m cross-section drop over the 40 m span** — a hillside, on a centreline whose 4 m neighbourhood
was gentle enough to pass `:456`. **The gate's window is 10× narrower than the thing it approves.**

Fix the width and this gate becomes honest for free. At `half_w = 5 m`, the ±5 m bank samples sit inside
the full-depth zone of the carve (`falloff == 1` for `dist_m <= half_w`, `terrain_manager.gd:431`) and
the worst-case cross-relief the 0.15 gate permits over 10 m is **1.5 m**, not 7.1 m.

### 1.4 What the Arbiter missed — a latent uphill-flowing water surface

`hydrology_map.gd:519` writes the channel surface as `_surface_h[i] = _elev[i] - CHANNEL_SURFACE_DROP`.
**`_elev` is the raw terrain and is NOT monotone along the flow path.** The channel is traced along D8
on `_filled` (`:521`, directions computed on `_filled` at `:269-287`), and `_filled` **is** monotone
decreasing downstream by construction of the priority-flood + epsilon (`:198`). Wherever a pit was
filled — and with `min_lake_depth = INF` (`:45`) pits are **never** promoted to LAKE (`:358`), so
channels routinely cross filled pits — `_elev < _filled` and the reported water surface **dips into the
hole and climbs back out**. `get_water_level_at` (`water_system.gd:511-521`) serves that non-monotone
profile to every caller.

**`_filled[i]`, not `_elev[i]`, is the correct surface datum, and it is already computed.**

### 1.5 The clamp is not "catching" errors, it is manufacturing a saw-tooth

`water_system.gd:340-341`:
```gdscript
var y: float = minf(bed + CHANNEL_WATER_DEPTH, minf(bank_l, bank_r) - RIVER_RECESS)
y = maxf(y, bed + 0.05)
```
`y` is chosen **per point** from whichever of three unrelated samples happens to be lowest. Adjacent
points switch branches, so the sheet alternates between `bed+0.55` and `bed+0.05` — the probe's 52.2 %
clamp rate is that alternation. **This is also why the shader looks wrong: a 0.5 m vertex-to-vertex
sawtooth destroys the flat-plane fresnel and the ripple normals the 8/12 rewrite added to
`terrain/water/water_static.gdshader`.** The briefing's suspicion — *"fixing the paint on a boat that
was not in the water"* — is confirmed; the boat is also being sawn in half.

---

## 2. CHARGE #3 — DOES THE HYDROLOGY ALREADY CARRY THE PER-POINT SURFACE ELEVATION?

**YES. It is computed, it is correct, and it is thrown away before `TerrainManager` can see it.**

- `_filled` (`hydrology_map.gd:100`) — per hydrology cell, meters, **monotone downstream**.
- `_elev` (`:99`) — per hydrology cell, meters, pre-carve grade.
- `_surface_h` (`:104`) — written for channel cells at `:518-519`, upsampled to `water_surface_full`
  at `:545-564`, and read back by `get_water_level_at` (`water_system.gd:521`).
- `_trace_channel` has `i`, `_elev[i]` and `_filled[i]` **in hand** at the exact point it appends
  `points` and `widths` (`:509-510`).
- But the river dictionary it emits carries **only** `{ points, widths }` (`:539`), and
  `TerrainManager._carve_riverbed` unpacks exactly those two (`terrain_manager.gd:408-409`).

**The channel's own downhill surface profile exists one line above the append and is discarded.**
Carrying it is a three-line change (§5, edit A). No new solve, no extra pass, no cost.

---

## 3. CHARGE #3 — EVERY DOWNSTREAM CONSUMER OF THE HEIGHTMAP

Ordered by blast radius. "Carve-sensitive" = a level cut changes its answer.

| # | Consumer | Pointer | Carve-sensitive? |
|---|---|---|---|
| 1 | **NavBaker source geometry** — synthesises nav triangles from `get_height_at` on a 4 m lattice | `scripts/world/nav_baker.gd:338-341` | **CRITICAL — see §4** |
| 2 | NavBaker agent gates — `agent_max_slope = 50.0`, `agent_max_climb = 0.4` | `nav_baker.gd:270-271` | **CRITICAL** |
| 3 | `TerrainManager.get_height_at` — the universal ground clamp for every unit, corpse, prop, projectile | `terrain/core/terrain_manager.gd:277-280` | YES (by design) |
| 4 | Chunk mesh + raycast collision | `terrain_manager.gd:210-227` | YES (by design) |
| 5 | `GameplayGrid` slope → CLIFF at `slope_val > 0.7` | `gameplay_grid.gd:130-131, 275-276` | YES, but **survives** — see §4.2 |
| 6 | `GameplayGrid` WATER type ← `water_system.is_water` | `gameplay_grid.gd:272-274` | **NO** — mask is pre-carve hydrology |
| 7 | 22 m gallery belt `RIPARIAN_M` — multi-source BFS from WATER cells | `gameplay_grid.gd:151, 177-216, 446-450` | **NO** — see §4.3 |
| 8 | Wade gate `WADE_DEPTH_M = 1.2` vs `get_water_depth` | `gameplay_grid.gd:138, 154`; `water_system.gd:494-506` | **YES — see §4.4** |
| 9 | `PaddyStamper` → RICE_PADDY clusters → village anchors | `scripts/world/paddy_stamper.gd:55, 60-64` | **NO** — see §4.3 |
| 10 | `HARD_FLOOR_VILLAGES = 4` hard `push_error` | `paddy_stamper.gd:17, 70-75` | **NO** (inherits #9) |
| 11 | Paddy world-Y from terrain | `paddy_stamper.gd:116-140` | YES (cosmetic) |
| 12 | `SitePlanner` site test — `is_water`, WATER/CLIFF type, `get_slope > MAX_SLOPE` | `scripts/world/site_planner.gd:100-109` | YES via slope only |
| 13 | `SitePlanner.place_structure` ground clamp | `site_planner.gd:193-194` | YES (cosmetic) |
| 14 | `SitePlanner.clear_and_flatten` → `ClearingSystem` height flatten, **mutates the heightmap after water is built** | `site_planner.gd:116-126`, ordering note `:1234-1240` | **the §6 sequencing hazard** |
| 15 | `RoadNetwork` pathing cost, `WATER_COST = 24.0` | `scripts/world/road_network.gd:40, 164-167` | NO (inherits the 4 m mask) |
| 16 | `WaterSystem` bed/bank sampling | `water_system.gd:336-338` | **YES — this is the bug** |
| 17 | `WaterSystem` depth quantisation `int(depth*2.0)` | `water_system.gd:420-423` | YES (inherits #8) |
| 18 | `WaterSystem.reseat_region` vs `_gen_terrain` snapshot, `RETIRE_RISE_M = 1.0` | `water_system.gd:438-463`, `:53-57` | YES |
| 19 | `TerrainZoning.configure` lowland ceiling from map min/max | `terrain/core/terrain_zoning.gd:51-61` | **NO — runs at `terrain_manager.gd:127`, BEFORE the carve at `:132`** |
| 20 | `GroundClutter` region-rebuild hook | `scripts/world/ground_clutter.gd:120, 176, 204` | YES |
| 21 | `HydrologyMap` itself | solved at `terrain_manager.gd:373`, **before** the carve at `:382` | **NO — no feedback loop** |
| 22 | `topo_map.gd`, `mission_scope.gd`, `field_director.gd`, `convoy.gd`, `helicopter.gd`, `air_traffic.gd`, `animal_routine.gd`, `punji_trap.gd`, `projectile_base.gd`, `destructible_vehicle.gd`, `fire_preview.gd`, `squad_system.gd`, `siege_director.gd`, `cas_airplane.gd`, `spectre_gunship.gd` | all via `get_height_at` (27 files matched) | YES (all inherit #3) |

---

## 4. WHAT A LEVEL CUT ACTUALLY BREAKS

### 4.1 THE SINGLE MOST DANGEROUS CONSUMER: NavBaker

`nav_baker.gd:338-341` builds the nav source geometry by sampling `get_height_at` on a **4 m** lattice.
`nav_baker.gd:270` sets `agent_max_climb = floorf(0.4 / cell_height) * cell_height` — **0.4 m** — and
`:271` sets `agent_max_slope = 50.0`.

A level cut to an absolute floor **at the current 40 m width** removes, at the probe's own measured
cross-section, **7.1 m of earth at the channel edge** (`grade 148.53` vs `bed 141.42`, row `i=171`).
Smeared across one 4 m nav sample that is a **60.6° face** — past `agent_max_slope` — and a **7.1 m
step** — 17× `agent_max_climb`. Result: **an unwalkable ribbon down the length of every channel**, and
because `NavBaker` bakes per-site islands (`mission_generator.gd:947-956`), any site that straddles a
channel gets its navmesh **severed**, not merely dented. Squads stop pathing between halves of their
own firebase.

This is the failure mode that must gate the decision. **At 40 m width, the level cut is a
game-breaking change. At ≤10 m width it is a 1.3 m step — still over `agent_max_climb`, but confined
to a 10 m band the nav lattice can ramp across in 2–3 samples.**

**Therefore: the width fix is a PREREQUISITE of the level cut, not an alternative to it.**

### 4.2 GameplayGrid CLIFF — survives, narrowly

`slope_val = 1.0 - normal.y` (`gameplay_grid.gd:130`), CLIFF at `> 0.7` (`:275-276`) → normal.y < 0.3 →
**~72.5°**. A 7.1 m step over the 4 m heightmap spacing is 60.6° → `normal.y ≈ 0.49` → `slope_val ≈ 0.51`.
**Below the CLIFF threshold.** So the AI grid does *not* wall off the channels — it just makes them
brutally expensive to cross while nav says they are impassable. **Divergence between the two pathing
authorities is worse than either being wrong consistently.** This is the `recongame-divergent-systems`
pattern again.

### 4.3 Villages, paddies and the 22 m gallery belt are NOT at risk from the carve

Contrary to the briefing's warning list, all three are **carve-independent**:

- `TerrainZoning.configure` runs at `terrain_manager.gd:127`, the carve at `:132`. The lowland ceiling
  and therefore RICE_PADDY classification are computed on **pre-carve** heights.
- `GameplayGrid`'s WATER cells come from `water_system.is_water` (`gameplay_grid.gd:272-274`) → the
  water map → `hydro.water_type_full` (`water_system.gd:414`) → `_type_h`, all solved pre-carve.
- `_apply_riparian_belt` BFSs out from WATER cells (`gameplay_grid.gd:177-216`), so the 22 m belt is
  anchored to the pre-carve 4 m mask and never moves when the ground does.
- `PaddyStamper` reads RICE_PADDY from the grid (`paddy_stamper.gd:55`), so `HARD_FLOOR_VILLAGES = 4`
  (`:17, 70-75`) is safe.

**The briefing's #63-65 fear is correctly aimed at restoring POOLING, and wrongly generalised to the
carve.** Do not let it veto the carve fix.

**BUT — the belt becomes a real hazard the moment anyone "fixes" the 4 m mask by rasterising true
width.** A 40 m mask + 22 m reach = an 84 m gallery band per channel, ×106 channels. If width is
rasterised, `RIPARIAN_M` (`gameplay_grid.gd:151`) must be re-tuned in the same change. **Name it in the
decree so a future session does not walk into it.**

### 4.4 The wade gate flips from never-fires to always-fires

Today `get_water_depth` returns a constant 0.5 m (`water_system.gd:505-506`, `depth_index` from
`int(depth*2.0)` at `:422`), so `WADE_DEPTH_M = 1.2` (`gameplay_grid.gd:154`) can never fire — the
briefing has this right. A level cut writes the true depth. Because the water mask is only the 4 m
centreline (§1.1), the cells that get a real depth are exactly the deepest ones. If the level floor is
set at `surface - CHANNEL_WATER_DEPTH` the depth lands at **0.55 m** → still under 1.2 → wade gate
still never fires, which is the *desired* outcome (water as a fording obstacle, `hydrology_map.gd:44`).
**If instead the floor is set from the pre-carve grade at the deepest bank, depth can exceed 1.2 m and
106 channels become impassable to the AI overnight.** Seat the floor off the *surface*, never off the
grade.

---

## 5. THE MINIMUM CHANGE I ENDORSE

Four edits, all inside files that already exist. Ordered; each is independently testable.

**A — carry the surface profile** (`terrain/water/hydrology_map.gd:493-539`)
In `_trace_channel`, add a third parallel array `surfaces: PackedFloat32Array`, appending
`_filled[i] - CHANNEL_SURFACE_DROP` alongside `points`/`widths` at `:509-510`; emit it in the dict at
`:539`. Change `:519` to write the same value into `_surface_h[i]` (replacing `_elev[i]`), which fixes
the non-monotone / uphill surface of §1.4 in the same edit. Also propagate it in the lake/coastal
terminator at `:532-533`.

**B — make width physical and sane** (`hydrology_map.gd:64, 507-508`)
`river_width_max: 40.0 -> 10.0`, and divide the accumulation by cell area so width stops being
resolution-dependent: `sqrt(_accum[i] * _hcell * _hcell)` with `river_width_scale` re-scaled to keep
creeks at ~2–4 m. This is the edit that makes every other one safe (§4.1).

**C — seat the sheet off the profile, delete the bank guesswork**
(`terrain/water/water_system.gd:336-341`)
Replace the `bed`/`bank_l`/`bank_r` sampling and both clamps with `var y: float = surfaces[i]`.
Keep `bed` only to compute `d_mid`/`d_l`/`d_r` vertex colours (`:348-350`). Under FOSSIL LAW (ADR-023)
**`RIVER_RECESS` (`water_system.gd:237`) has no remaining caller and is DELETED in the same change**,
as is the `maxf(y, bed + 0.05)` floor.

**D — level cut** (`terrain/core/terrain_manager.gd:407-434`)
Unpack `surfaces` alongside `points`/`widths` (`:408-409`). Replace the relative subtract at `:432-434`
with an absolute floor that **can only remove earth**:
```gdscript
var target: float = surfaces[i] - CHANNEL_WATER_DEPTH   # absolute, meters
var goal: float = heightmap.meters_to_norm(lerpf(current_m, target, falloff))
heightmap.set_cell(nx, nz, maxf(0.0, minf(current, goal)))
```
The `minf(current, goal)` is load-bearing: it guarantees the carve is **monotonically subtractive**, so
the cut can never *raise* ground into a valley, never fill a crater, and never invalidate a previously
sited structure upward. It bounds the failure mode to one direction, which is what makes the change
auditable.

`CHANNEL_WATER_DEPTH` lives in `water_system.gd:238` and `CHANNEL_CARVE_DEPTH` in
`terrain_manager.gd:31`; with an absolute floor, `CHANNEL_CARVE_DEPTH` becomes an unread const —
**delete it and correct the contract comment at `:28-31` and `hydrology_map.gd:51-53` in the same
change** (FOSSIL LAW + the no-more-drift rule).

### What I explicitly do NOT endorse

- **Widening the ribbon past the carved banks (charge #4).** It cannot help: with edits A–D the
  surface is already flat and level across the channel, and the terrain rises above it monotonically —
  the sheet is *already* fully visible out to where it meets ground. Widening only adds verts that
  z-fight against the bank. **The ribbon should stay at `widths[i]`; the fix is that `widths[i]` is
  now honest.**
- **Rasterising true channel width into `_type_h`.** Correct in principle, but it detonates the 22 m
  gallery belt (§4.3) and the road-cost field in the same commit. **Separate change, separate playtest.**
- **Restoring pooling** (`hydrology_map.gd:45`). Agreed with the briefing, for the reasons the
  briefing gives.

---

## 6. CHARGE #5 — SEQUENCING: REBUILD HOOK, OR ORDERING?

**The hazard is real and I can pin every hop of it.**

1. `game_world.gd:166` — `water_system.generate_water_bodies(terrain_manager.hydrology)`
2. → `water_system.gd:114` — `_build_combined_water_mesh(...)`. **Called from exactly one place. The
   mesh is built ONCE and there is no rebuild path anywhere in the file.**
3. Later, `mission_generator.plan_demo_world` / `plan_patrol_world` /`build_patrol_world`
   (`scripts/missions/mission_generator.gd:666, 484, 852`) call `SitePlanner.clear_and_flatten`
   (`site_planner.gd:116`, invoked at `:229, 1240, 1854, 1911`) which runs `ClearingSystem`'s height
   flatten toward a disc mean — **mutating the heightmap under the finished water mesh.**
4. → `region_rebuilt` (`terrain_manager.gd:296`) → `game_world._on_terrain_region_rebuilt` (`:486`) →
   `_flush_terrain_dirty` (`:501`) → `water_system.reseat_region(rect)` (`:508`).
5. `reseat_region` (`water_system.gd:438-463`) updates **only `water_map`**. It never touches the mesh.
   Its own docstring at `:437` says it deliberately does not re-run hydrology.

**Net effect: after a flatten, the gameplay water map retires cells the rendered sheet still draws, and
the sheet stays at its old Y under ground that has risen. This is almost certainly the origin of the
`generate_swamps = false` scar (`water_system.gd:28`) — swamps sat in exactly the flat lowland the
firebase and villages get stamped into, so they were the first bodies to be buried, and the fix applied
was to stop generating them.**

### Ordering vs rebuild hook

**Ordering is safer, and it is available cheaply because the two halves have different dependencies:**

- The water **MAP** must exist before `gameplay_grid.build_from_terrain` (`game_world.gd:177`), because
  the grid's WATER type is a query into it (`gameplay_grid.gd:272-274`), and the grid must exist before
  `PaddyStamper` (`mission_generator.gd:511`) and before `SitePlanner`'s water rejection
  (`site_planner.gd:102`). **The map is carve- and flatten-independent** (§4.3) — it comes off
  pre-carve hydrology — so leaving it early is correct.
- The water **MESH** is the only part that reads current terrain, and nothing reads the mesh.

**Recommendation:** split `_build_combined_water_mesh` (`water_system.gd:114`) out of
`generate_water_bodies` into a public `build_water_mesh()`, retain `static_bodies`/`rivers` on the
instance, and call it once after `build_patrol_world` returns. Then **also** wire it into the existing
coalescer at `game_world.gd:501-508`, immediately after `reseat_region`.

The rebuild hook is *not* expensive — the probe measured **4,308 ribbon verts** for the whole map, so a
full `ArrayMesh` rebuild is a sub-millisecond operation and `_flush_terrain_dirty` already coalesces
bursts (`game_world.gd:487-494`). **Do both.** Ordering fixes the systemic case (site stamping);
the hook fixes craters and makes the system self-healing, which is what stops this defect class
recurring.

**Hazard to guard:** if the mesh build is moved out of `generate_water_bodies`, any scene path that
builds a world without running a mission generator — `build_terrain_on_ready` bare worlds
(`game_world.gd:45`), `tools/probe_water_seat.tscn`, `ai_stress_arena.gd`, `test_range.gd` — gets **no
water at all**, silently. The call must be guaranteed by `GameWorld` (a deferred once-only build tied
to world-ready), not by the mission generator alone.

---

## 7. WHAT IS SACRIFICED (no free lunches)

| Recommendation | Cost |
|---|---|
| **B — width max 40 m → 10 m** | **The AO loses its wide rivers.** Every waterway becomes a creek or a small stream. Pillar 2 (Atmosphere) pays for this directly — a Vietnam sim with no river you have to think about is a poorer place. This is a **design ruling the Summoner must make**, not a technical one. The technical position is only: *40 m is not currently supported by anything else in the pipeline, and supporting it costs a nav rework.* |
| **D — level cut** | Removes up to `grade − surface + 0.55` m of earth per channel. Bounded to ~1.3 m once B lands; **unbounded and game-breaking (7 m, §4.1) if B does not land first.** Also permanently changes the AO's silhouette — existing seeds will not reproduce their old terrain. ADR-010's "same seed → same world" contract is **broken by this change**; that is unavoidable for any carve fix and should be stated in the decree rather than discovered later. |
| **A — `_filled` instead of `_elev` at `:519`** | Water surfaces sit slightly higher wherever pits were filled — visually water in shallow depressions rather than following the dip. That is physically correct and reads better, but it is a **change to `get_water_level_at`'s answers** and any tuning done against the old (broken) values is invalidated. |
| **C — delete bank sampling + `RIVER_RECESS`** | Loses the (illusory) safety net that was hiding the seating bug. If A or D is wrong, the sheet will now float or sink **visibly and loudly** instead of being clamped into a saw-tooth. **That is the point** — but it means the fix must land as a set, not piecemeal. |
| **§6 — split the mesh build** | A new load-order contract, and a new class of silent failure (a scene that never calls it has no water). Mitigated only by putting the guarantee in `GameWorld`, which is one more thing to keep true. |
| **Not rasterising true width (§5)** | The 4 m gameplay mask survives this change. AI will still walk on top of the visible sheet at its edges, and roads will still cross rivers cheaply. **The visual defect is fixed; the gameplay defect is deferred.** This is a deliberate scope cut to keep the 22 m belt and `HARD_FLOOR_VILLAGES` out of the blast radius, and it must be recorded as open debt, not treated as done. |

---

## 8. POINTER APPENDIX — claims I could NOT find a pointer for

Per the no-more-drift rule, the gaps are the finding:

- **No test covers water seating.** No `tests/test_water*` exists; the only instrument is
  `tools/probe_water_seat.gd`, which is a probe, not a gate. A fix of this size should land with a
  headless assertion (surface monotone downstream; every vertex above bed; zero clamp events).
- **`generate_swamps = false` (`water_system.gd:28`) carries no ADR and no date.** Its comment asserts
  "swamps were rendering as wet lakes" with no pointer. On the evidence of §6 the real cause was
  burial by site flattening, i.e. **the flag may be a workaround for the bug this council is fixing.**
  Re-test it after the sequencing fix before treating it as a permanent decision.
- `terrain_manager.gd:28-31` and `hydrology_map.gd:51-53` both assert the three-constant contract
  (`CHANNEL_CARVE_DEPTH − CHANNEL_WATER_DEPTH = CHANNEL_SURFACE_DROP`). The arithmetic holds
  (1.2 − 0.55 = 0.65) but **nothing enforces it** — no test, no assert. Edit D retires the contract;
  if it is kept in any form, it needs a machine.
