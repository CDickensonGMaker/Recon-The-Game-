# DEVIL'S ADVOCATE — the water does not render

**Date:** 2026-08-12 · **Charge:** refute the Arbiter's diagnosis.
Every assertion below carries a `file:line` or names the probe that produced it.

---

## 0. TL;DR

The Arbiter found a real symptom and named the wrong disease. The bank-sampling defect is
real and I confirm it. The "relative subtract preserves relief" framing is a **second-order
term**. The first-order term — which nobody in the briefing names — is that
**`_carve_riverbed` accumulates across overlapping path points and cuts the channels
~6.6× deeper than the constant says.**

New probe, written for this analysis: `tools/probe_carve_depth.gd` /
`tools/probe_carve_depth.tscn`. Seed 47225, same world the Arbiter probed, 4308 channel
points:

```
intended carve            1.20 m       (TerrainManager.CHANNEL_CARVE_DEPTH, terrain_manager.gd:31)
ACTUAL carve  mean 7.97 m   min 1.05   max 34.19
points carved deeper than 3.0 m: 3450 (80.1%)
bank(+-half_w) - bed  mean +0.449 m
bank(+-reach)  - bed  mean +3.270 m
points where bank == bed (within 5cm): 332 (7.7%)

get_water_level_at() - mesh y:  mean +7.07 m   max +33.49 m  (4308 pts)
```

The last line is the finding of the session. **The height the game reports for water and
the height the water mesh is actually at differ by seven metres on average and thirty-three
at worst.** Every consumer of `get_water_level_at()` — the wade gate, and the very viewer
the Summoner used — is pointed at empty air above an eight-metre gorge.

---

## 1. AUDIT OF THE ARBITER'S PROBE (`tools/probe_water_seat.gd`)

I was asked to assume it lies. It does not. It survives.

- **Faithful reproduction.** `probe_water_seat.gd:82-84` is character-for-character the
  seating decision at `water_system.gd:340-341`
  (`minf(bed + CHANNEL_WATER_DEPTH, minf(bank_l, bank_r) - RIVER_RECESS)`, then
  `maxf(y, bed + 0.05)`). `_path_perpendicular` is called on the real object
  (`probe_water_seat.gd:66` → `water_system.gd:389`), not reimplemented. The only
  divergence is a width guard (`probe_water_seat.gd:65` falls back to 4.0; the shipping
  code indexes `widths[i]` bare at `water_system.gd:329`) — inert, because
  `_trace_channel` appends one width per point in the same loop and one more at the lake
  break (`hydrology_map.gd:509-510`, `:532-533`), so the arrays are always equal length.

- **Same array, not a copy.** `terrain_manager.hydrology` is handed straight into
  `generate_water_bodies` (`game_world.gd:166`), stored as `_hydrology`
  (`water_system.gd:102`), and `_build_combined_water_mesh` iterates `hydro.rivers`
  (`water_system.gd:114`, `:258`). The probe reads `ws._hydrology.rivers`
  (`probe_water_seat.gd:29,35`). Identical object.

- **Sampling moment — the attack I expected to land, and it does not.** The probe samples
  the heightmap after `is_world_ready`; the mesh was built earlier at `game_world.gd:166`.
  That would matter if anything mutated the heightmap in between. **Nothing does.** A
  repo-wide sweep finds exactly two heightmap writers: initial generation
  (`terrain_manager.gd:159`) and the carve (`terrain_manager.gd:434`). In particular the
  briefing's claim at `briefing.md:59-60` — *"`site_planner`'s flatten raises ground
  AFTER"* — is **FALSE**. `site_planner.clear_and_flatten()` (`site_planner.gd:114-125`)
  clears vegetation, opens a `ClearingSystem` zone and pokes the gameplay grid. It never
  calls `set_cell`. The name is a lie; there is no terrain flatten in this codebase.
  **The probe's timing is sound and so is mine.**

**Verdict on the probe: clean.** The Arbiter's numbers are real. His *reading* of them is
what I contest.

---

## 2. THE ROOT CAUSE THE ARBITER MISSED: THE CARVE ACCUMULATES

`_carve_riverbed` (`terrain_manager.gd:407-434`) walks the path point by point. For each
point it stamps a disc of radius `reach = half_w + shoulder` (`:416-418`) and at
`:432-434` does:

```gdscript
var current: float = heightmap.get_cell(nx, nz)
var depth_normalized: float = heightmap.meters_to_norm(CHANNEL_CARVE_DEPTH * falloff)
heightmap.set_cell(nx, nz, maxf(0.0, current - depth_normalized))
```

It reads the *current* height — which the previous points already lowered — and subtracts
again. **Path points are 4 m apart** (`hydrology_map.gd:506`, `_hcell = cell_size *
downsample` at `:133`; measured downsample 1, cell 4 m, printed by the probe run). Discs
are 7.5–32 m in radius. So any given cell falls inside the disc of 4–16 consecutive points
and is carved 4–16 times over.

That is the whole story. Measured mean 7.97 m against a 1.20 m constant; 80.1 % of points
deeper than 3 m; worst 34.19 m where channels converge.

This defect is **independent of terrain relief**. It fires identically on a billiard table.
The Arbiter's defect #1 ("relative subtract preserves local relief", `briefing.md:32-36`)
is true but is worth ~0.5 m of the error; accumulation is worth ~6.8 m of it. **He
diagnosed the ripple and missed the wave.**

The Summoner's own words are the tell and we should have read them literally:
*"theres cuts in the ground for the water to be there"*. He is not describing a riverbed.
He is describing an eight-metre trench, because that is what is there.

---

## 3. DEFECT #2 — RIGHT CONCLUSION, WRONG MECHANISM

The Arbiter says the bank samples land "on arbitrary hillside — sometimes BELOW the bed"
(`briefing.md:38-42`). Measured: `bank(±half_w) − bed` mean **+0.449 m**, i.e. banks are on
average *above* the bed, not below it. The briefing's three bolded negative rows
(`briefing.md:22-24`) are cherry-picked from 4308 points; only 7.7 % of points have
`bank ≈ bed` within 5 cm.

The real mechanism is cleaner and worse, because it is **structural, not stochastic**:

`falloff = 1.0 - smoothstep(half_w, reach, dist_m)` (`terrain_manager.gd:431`).
`smoothstep(e0, e1, x) == 0` for `x <= e0`. Therefore **`falloff == 1.0 everywhere inside
±half_w`** — the carve is full-depth right out to the ribbon's own edge. `half_w` is not
the bank. It is the last full-depth ring of the excavation. `_append_river_strip` samples
its "banks" at exactly `±half_w` (`water_system.gd:331-338`) — inside the hole.

So `minf(bank_l, bank_r) - RIVER_RECESS` (`water_system.gd:340`, `RIVER_RECESS = 0.1` at
`:236`) subtracts 10 cm from a number that is *by construction* only marginally above the
bed. The mean headroom is 0.449 m; the seating needs 0.65 m to avoid the min() winning.
**It loses more often than it wins — hence 52.2 %.** The clamp at `water_system.gd:341`
then pins those verts to `bed + 0.05`: a five-centimetre film.

The number that fixes it is already measured: sampling at `reach` instead of `half_w`
gives **+3.270 m** of headroom, which clears `CHANNEL_WATER_DEPTH + RIVER_RECESS = 0.65`
comfortably. `reach` is trivially reconstructible in `water_system.gd` — it is
`half + maxf(half * 0.6, cell_size)`, mirroring `terrain_manager.gd:416-417`.

**Cost of that fix, named:** it duplicates the carve profile constant in a second file. If
the shoulder formula ever changes in `terrain_manager.gd` the water silently mis-seats
again, with no error. The honest version publishes the carve profile as one authority
(a `static func bank_reach(half_w, cell_size)` on `TerrainManager`) and has both callers
use it. Anything less plants a fresh drift generator in the exact place that just produced
this session.

---

## 4. DEFECT #3 IS FACTUALLY WRONG AS WRITTEN

`briefing.md:43-44`: *"The sheet is only half_w wide."* No. `_append_river_strip` emits
`left = p - perp * half` and `right = p + perp * half` (`water_system.gd:331-332`). The
ribbon spans `2 * half = width`, i.e. the **full** channel width, 6–40 m by the measured
histogram.

The conclusion he draws from it is nonetheless true, for a different reason: the *carve* is
`half_w + shoulder` wide — **1.6× wider than the water** for every channel above ~13 m — and
now ~8 m deep. So the visible object is a broad dry gorge with a full-width sheet lying on
the bottom of it, occluded by its own walls from any oblique angle. Correct verdict,
wrong arithmetic.

And the sheet, at `bed + 0.05`, bakes `d_mid = clampf(0.05 / 4.0, ...) ≈ 0.012`
(`water_system.gd:348`, `COMBINED_DEPTH_RANGE = 4.0` at `:234`) — fully "shallow" in the
vertex-colour contract, so the shader paints `col_shallow` at `alpha_shallow = 0.50`
(`water_static.gdshader:12,18`). **A 50 %-alpha grey-green film five centimetres above wet
mud is indistinguishable from wet mud.** Even standing in it, he would not call it water.
The shader is innocent and it is also incapable of saving this.

---

## 5. IS THE WATER REACHING THE SCREEN? — RULING OUT THE BORING EXPLANATIONS

I was told to suspect the viewer before the geometry. I did. Here is every alternative,
ruled in or out with evidence.

| Hypothesis | Verdict | Evidence |
|---|---|---|
| `water_view.gd` instantiates the world differently from `game_world.tscn` | **RULED OUT** | `water_view.gd:42` does `load("res://scripts/levels/game_world.gd").new()`. `scenes/levels/game_world.tscn` is a bare `Node3D` carrying only that script (whole file is 5 lines). Script-instantiation and scene-instantiation are *identical* here. Every child — sun, environment, terrain, water — is built in `_ready` (`game_world.gd:56-114`). |
| `CombinedWater` never added to the tree / container detached | **RULED OUT** | `_water_container` created and added in `WaterSystem._ready` (`water_system.gd:60-63`); `mi` added to it at `water_system.gd:282`; `WaterSystem` added to the world at `game_world.gd:112-114`. |
| Empty mesh (early return) | **RULED OUT** | `water_system.gd:261` returns only if `verts.is_empty()`. Probe counts 4308 river points → 12 924 ribbon verts. |
| Back-face culling / wrong winding | **RULED OUT** | `render_mode cull_back` (`water_static.gdshader:2`). Winding from `water_system.gd:352-375`: for `dir = +X`, `perp = +Z` (`:389-399`), triangle `l0,c0,c1` has geometric normal `+Y`. Front-facing from above. Consistent for all headings because `perp` co-rotates with `direction`. |
| No sun / black scene | **RULED OUT** | `DirectionalLight3D` named `"SunLight"` at `game_world.gd:56-61`; `water_view.gd:111` fetches it by that exact name. Ambient from sky at `game_world.gd:74-75`. |
| Fog hiding it | **RULED OUT** | `fog_density = 0.0065` (`game_world.gd:83`) — ~12 % extinction at 20 m. Cannot hide a sheet at 7 m. |
| Shader fails to compile silently | **NOT RULED OUT, but unlikely** | `water_common.gdshaderinc` exists in `terrain/water/`. `ALBEDO`/`ALPHA` are written (`water_static.gdshader:112-113`). A headless run cannot compile shaders, so this is unfalsifiable from here. **It is the one item on this list I could not close, and it should be closed by eye in the windowed viewer before any code lands.** |
| Alpha too low to see | **CONTRIBUTING** | See §4 — 0.50 alpha on a 5 cm film. |
| **The viewer aims the camera at a height where no water exists** | **CONFIRMED — and this is the amplifier** | `_frame_spot` puts the camera relative to `spot["pos"]`, whose `y` comes from `get_water_level_at` (`water_view.gd:216,235,167-174`). That function returns `_hydrology.water_surface_full` (`water_system.gd:511-521`), which is `_elev − CHANNEL_SURFACE_DROP` (`hydrology_map.gd:518-519`, `CHANNEL_SURFACE_DROP = 0.65` at `:53`) — a value derived from the *assumption* that the carve is 1.2 m deep. Measured divergence from the actual mesh: **+7.07 m mean, +33.49 m max.** `_find_water_spots` sorts by neighbour count (`water_view.gd:201`), so the top spots are the *widest* channels — precisely the ones with the deepest accumulated carve and the largest error. |

**So: the viewer is not the broken thing, but it is not innocent either.** It is a faithful
consumer of a broken contract, and it therefore stood the Summoner on the rim of a gorge,
looking at a point seven metres above the water, while the HUD line at `water_view.gd:160-161`
told him `water=YES depth=0.50m surface_y=<that phantom>`. That is *exactly* the report we
got: *"theres cuts in the ground for the water to be there but than no water appears."*
He was told water was there. It was — 7 m below his crosshair, 5 cm thick, at 50 % alpha,
at the bottom of a trench.

---

## 6. "NOT FOLLOWING THE NATURAL FLOW THAT GETS CUT" — PATH MISMATCH IS RULED OUT

I was asked to verify, not assume. Verified:

`_extract_and_carve_rivers` (`terrain_manager.gd:365-384`) smooths **first**
(`:378-379` → `_smooth_river_path` writes `path["points"] = smoothed` at `:401`, mutating
the dictionary **in place**), then carves (`:381-382`). `river_paths = hydro.rivers`
(`:375`) is the same `Array` of the same `Dictionary` objects that `game_world.gd:166`
passes to the water system and that `_build_combined_water_mesh` iterates
(`water_system.gd:258`). **The ditch and the ribbon use byte-identical point arrays.**

The Summoner's second sentence is therefore not a path-registration complaint. It is a
*vertical* complaint that reads like a horizontal one — the sheet is nowhere near the
bottom of the cut, and where it is, it is jagged, because the clamp fires on 52 % of verts
and not the other 48 %, so the surface hops between `bed+0.55` and `bed+0.05`
vertex-to-vertex.

---

## 7. WHAT THE FIXES SACRIFICE

**Making the carve non-accumulating** (the necessary fix — accumulate a per-cell depth mask
across all points, then apply `min` once, or `set_cell(nx,nz, base − maxf(existing_cut,
new_cut))`):

- Channels go from ~8 m gorges to 1.2 m grooves. **The AO loses its most dramatic terrain
  feature.** Eight-metre ravines are, unintentionally, excellent cover and excellent
  ambush geometry, and they are in every playtest impression the project has recorded of
  this seed family. Somebody will call the fixed version flat and boring. Name that now,
  before it is discovered post-hoc and mistaken for a regression.
- `GameplayGrid` reported *"15205 bank cells greened, 2461 creek cells roofed"* in the
  probe run — those counts are derived from terrain slope near water and **will move**. The
  22 m gallery-forest belt and AI sight ranges the briefing warns about (`briefing.md:63`)
  ride on that. Shallower banks = less steep slope = fewer "bank" cells = a different
  vegetation and sight-line map. This is not a water change; it is a world change.
- Village siting, nav bake and `HARD_FLOOR_VILLAGES` all read the heightmap. Raising 80 %
  of channel cells by ~6.8 m **opens land that was previously unbuildable**. Site counts
  will change on every existing seed. **Every seeded impression in the project's records —
  screenshots, playtest notes, the demo world — is invalidated by this fix.** That is the
  real price, and it is not small.

**Changing the bank sample from `half_w` to `reach`** (`water_system.gd:337-338`): cheap,
local, and the measured headroom (+3.27 m) says it works. Sacrifice: a duplicated carve
profile in a second file unless it is published as one authority (§3).

**Re-deriving `CHANNEL_SURFACE_DROP`** (`hydrology_map.gd:53`): it is a hardcoded 0.65 that
is only correct if the carve is exactly 1.2. Fix the carve and it becomes correct again for
free. Leave the carve broken and patch this instead, and you have two lies that cancel in
one place and diverge everywhere else. **Do not patch this constant.**

**The `generate_swamps = false` scar** (`water_system.gd:28`): I checked. There is **no ADR
about water at all** — `production/adr/` has no water, terrain or hydrology entry. The only
prior record is `production/war_room/2026-07-16_worldgen_wave1/briefing.md:24`, which
attributes the switch to swamps *"rendering as wet lakes"* — an appearance complaint, not
the sequencing story `briefing.md:59-60` invents for it. **The briefing manufactures
provenance for that flag.** Since `min_lake_depth = INF` (`hydrology_map.gd:45`) means no
static body of any kind is produced, the flag is currently inert either way.

---

## 8. WHERE THE ARBITER IS RIGHT, AND WHICH PART IS WEAKEST

He is right that the seating decision is broken, right that the clamp is firing on half the
mesh, right that the shader is not the problem, and right to distrust his own rewrite.

**Weakest part: defect #1's framing.** "Relative subtract preserves relief" is a true
sentence that points at the wrong line. The bug at `terrain_manager.gd:432-434` is not that
it subtracts from `current` instead of setting an absolute level — it is that it subtracts
from `current` **once per path point**, and there are a dozen path points over every cell.
A fix aimed at "make the carve level" would rewrite the carve to stamp an absolute bed
height and would, by accident, also fix accumulation — and the team would never learn which
defect it had killed, or that the same accumulation pattern is now sitting unexamined in
every other disc-stamping routine in the codebase.

**Second weakest: the claim that banks read below the bed.** Measured mean is +0.449 m. The
briefing generalises from three hand-picked rows. That is the same evidentiary sin the
POINTER LAW exists to prevent, committed inside a briefing that opens by invoking it.
