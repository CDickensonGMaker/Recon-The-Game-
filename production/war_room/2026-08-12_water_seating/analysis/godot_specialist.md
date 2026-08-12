# GODOT SPECIALIST — the mesh and the rendering

**Convened:** 2026-08-12 · lens: is the water invisible for a RENDERING reason on top of the geometry reason?

**ANSWER: YES. And the rendering reason is sufficient on its own.**
Every river ribbon triangle is wound BACKWARDS. `water_static.gdshader:2` was flipped to
`cull_back` in the 8/12 rewrite. Under `cull_back` the ribbon is culled from every
above-ground viewing angle. **The water sheet renders only when the camera is under it.**

---

## 1. THE RIBBON IS BACKFACING — the root cause (DECISIVE)

### The evidence chain

**a) The shader now culls.** `terrain/water/water_static.gdshader:2`
```
render_mode cull_back, depth_draw_always;
```
The 8/12 note said CULL_DISABLED "should flip to CULL_BACK". It HAS been flipped. That is
the state now, in the committed file.

**b) The predecessor did not cull.** `terrain/water/water_swamp.gdshader:2`
```
render_mode depth_draw_always, cull_disabled;
```
This is the shader the jungle paddy layer still uses (`terrain/vegetation/jungle_patch_layer.gd:14`).
The ribbon geometry in `_append_river_strip` was authored and eyeballed against a
`cull_disabled` material. **Its winding was never load-bearing until 8/12.** Flipping the
render_mode without re-deriving the index order is the regression.

**c) This project's front-face sign, established from two meshes that demonstrably render.**

Work in the ground plane `(u, v) = (world x, world z)` and take the signed cross
`(B−A) × (C−B)` for the first triangle of each mesh.

| mesh | file:line | triangle (u,v) | sign |
|---|---|---|---|
| terrain chunk (renders, `cull_back`) | `terrain/core/terrain_chunk.gd:85-95` | v0(0,0), v1(1,0), v2(0,1) → (1,0)×(−1,1) | **+1** |
| static water quads | `terrain/water/water_system.gd:303-315` | (0,0), (cs,0), (cs,cs) → (1,0)×(0,1) | **+1** |
| **river ribbon** | **`terrain/water/water_system.gd:374`** | **l0(0,−h), c0(0,0), c1(s,0) → (0,h)×(s,0)** | **−1** |

The terrain shader carries no `render_mode` line at all
(`terrain/shaders/terrain.gdshader:1` — first directive is `shader_type spatial;`), so it
runs Godot's default `cull_back`, and it renders. That fixes `+1` as this project's
front-facing-up sign empirically, with no appeal to any winding convention document.

**The ribbon is `−1`. It is the only one of the three that is opposite.**

**d) All four ribbon triangles share the defect,** `water_system.gd:374-375`:

| triangle | verts (u,v) | cross | |
|---|---|---|---|
| `l0, c0, c1` | (0,−h),(0,0),(s,0) | −h·s | backfacing |
| `l0, c1, l1` | (0,−h),(s,0),(s,−h) | −(s)·h | backfacing |
| `c0, r0, r1` | (0,0),(0,h),(s,h) | −h·s | backfacing |
| `c0, r1, c1` | (0,0),(s,h),(s,0) | −h·s | backfacing |

`left`/`right` are fixed-handedness (`water_system.gd:330-332`: `perp = Vector2(-dir.y, dir.x)`,
`left = p - perp*half`, `right = p + perp*half`), so this sign is **rotation-invariant** — it does
not depend on which way the channel runs. Every one of the 4308 probe verts' triangles is wrong,
on every channel, at every heading.

**e) It matters because pooling is off.** `terrain/water/hydrology_map.gd:45` `min_lake_depth = INF`
and `water_system.gd:28` `generate_swamps = false` mean `_append_static_quads` contributes
**zero** triangles (`water_system.gd:250-256` skips every static body). The combined mesh is
100% ribbon. The one correctly-wound path in the file emits nothing, so nothing masks the bug.

### The fix — minimum change, one line
`terrain/water/water_system.gd:374-375`, reverse each triple:
```gdscript
indices.append_array([l0, c1, c0, l0, l1, c1])
indices.append_array([c0, r1, r0, c0, c1, r1])
```
Verified: `l0,c1,c0` → (s,h)×(−s,0) = +h·s → **+1**, matching terrain and the static quads.

Do NOT "fix" it by reverting `water_static.gdshader:2` to `cull_disabled`. That hides a real
geometry defect behind a render_mode, doubles the ribbon's fragment cost on a transparent
surface, and leaves the mesh lying about its own facing to every future consumer (decals,
shadow, any depth pass).

**Sacrificed:** nothing measurable. Correct winding costs zero. The only loss is the accidental
grace `cull_disabled` gave: a player whose camera dips below the sheet in a deep channel will
now see nothing instead of a back-face. That is correct behaviour and the shader is not
authored for an underwater view anyway (no underwater tint, no `BACKLIGHT`, no `FRONT_FACING`
branch anywhere in `water_static.gdshader:75-117`).

---

## 2. IS THE MESH REACHING THE SCENE TREE? — yes, cleanly. Not the bug.

- `_water_container` is created in `_ready()` (`water_system.gd:60-63`) and `add_child`ed to the
  WaterSystem node. It is never freed; `clear()` only reparents its children
  (`water_system.gd:466-471`).
- `WaterSystem extends Node` (`water_system.gd:1`) with a `Node3D` container child. Legal in
  Godot 4 — a Node3D under a plain Node resolves the nearest Viewport's `World3D` and renders
  at identity. No offset is introduced: `GameWorld` is a bare `Node3D` with no transform
  (`scenes/levels/game_world.tscn:5`), and the ribbon verts are already world-space
  (`water_system.gd:352-364` append raw `p.x / p.y`).
- Ordering is sound: `add_child(water_system)` at `scripts/levels/game_world.gd:114` runs
  `_ready()` synchronously, long before `generate_water_bodies` at `game_world.gd:166`.
- The `MeshInstance3D` is constructed and parented at `water_system.gd:278-282` with default
  `visible = true`; only `cast_shadow` is disabled (`:281`). `ArrayMesh` computes its own AABB
  from `ARRAY_VERTEX`, so there is no custom-AABB culling trap.
- The single early-out is `if verts.is_empty(): return` (`water_system.gd:261-262`), and the
  probe's 4308 ribbon verts prove that branch is not taken.

**Ruling: `CombinedWater` IS built, IS parented, IS visible. It is drawn and then discarded by
the rasteriser at the culling stage.** This is exactly the failure signature the Summoner
reported — cuts in the ground, no water — and it is why no log line and no probe caught it:
**every CPU-side measurement of this system is correct. The defect lives one stage past the
last thing GDScript can see.**

---

## 3. Z-FIGHTING AND OCCLUSION — real, second in line, and it survives the culling fix

Two independent mechanisms bury the sheet even once it faces the right way.

### 3a. The rendered terrain is ABOVE the sampled terrain — quantified

`heightmap.sample_world` is **bilinear** (`terrain/core/heightmap_storage.gd:65-89`). The chunk
mesh is **two triangles per cell** split on the anti-diagonal
(`terrain/core/terrain_chunk.gd:85-107`: tri1 = v0,v1,v2; tri2 = v1,v3,v2 — the shared edge is
v1(x+1,z) → v2(x,z+1)).

At the cell centre the two disagree by the bilinear twist term:
```
rendered(centre) = (h10 + h01) / 2          (midpoint of the shared diagonal edge)
sampled (centre) = (h00 + h10 + h01 + h11) / 4
error            = (h10 + h01 - h00 - h11) / 4
```
Zero at the four corners and along the diagonal; **maximum at the cell centre**; positive
(rendered ABOVE sampled) wherever the anti-diagonal corners sit higher than the main diagonal.

Grid is 4m (`scripts/levels/world_config.gd:11` `CELL_SIZE = 4.0`). The carve subtracts up to
1.2m (`terrain/core/terrain_manager.gd:31`) with a `smoothstep` shoulder ramping to grade over
`maxf(half_w*0.6, cell_size)` (`terrain_manager.gd:416`) — i.e. the channel wall drops its full
1.2m across **one to a few 4m cells**, plus whatever natural relief the carve preserved
(`terrain_manager.gd:434` subtracts, it does not level).

Take a modest wall cell with a 0.6m spread between the diagonal pairs: error = 0.6/4 = **0.15m**.
A steep one with 1.2m spread: **0.30m**.

**The clamp floor is `bed + 0.05` (`water_system.gd:341`) — 5cm.** The probe reports **2250 of
4308 verts (52.2%)** sitting on that floor. On every one of those, the rendered ground is above
the water by 0.10–0.25m over most of the cell interior, and coincident within float precision
near the corners.

**Ruling: on the clamped half of the ribbon the water is inside the terrain triangles by up to
~0.3m, and z-fights along the corner seams where the error crosses zero.** 5cm is not a
clearance on a 4m grid — it is inside the discretisation error of the ground it is measured
against. The floor must be at least ~0.35m to clear the twist term, and that only papers over
defect 3b.

### 3b. Three verts across a 40m ribbon — the chord cuts through the bed

`_append_river_strip` emits exactly **three** verts per station: `left`, centre, `right`
(`water_system.gd:352-365`). Channel widths run to 40m
(`terrain/water/hydrology_map.gd:64` `river_width_max = 40.0`, widths computed at `:507-508`).
So a single straight chord spans **up to 20m** from centreline to edge, over a bed the carve
explicitly did not flatten.

Longitudinally the ribbon is fine: path points are one hydrology cell apart
(`hydrology_map.gd:133` `_hcell = cell_size * downsample`; downsample = 1 on this map —
`hydrology_map.gd:116`, `water_system.gd:133` and `terrain_manager.gd:370` both compute
`maxi(1, round(size/450))` and 1280m/4m gives size 321), so ~4–5.7m segments. **The defect is
purely lateral.** Across the width, 3 verts is 1970s geometry: any bed relief between centreline
and edge pokes straight through the sheet.

Fix: subdivide the cross-section — emit `ceili(width / cell_size) + 1` verts per station instead
of 3, interpolating `left → right`, and seat each at its own `bed_i + depth`. That also makes the
`shore` term in `COLOR.r` (`water_system.gd:355/360/365`, consumed at `water_static.gdshader:102`)
mean something: today it is a hard 0 / 1 / 0 across up to 40m, so the shore-foam `smoothstep`
at `:102` and the edge alpha at `:110` fade over a 20m half-width. **The foam band is currently
20m wide.** That is not a shoreline, it is a gradient across the whole river.

**Sacrificed:** vert count. At 4m lateral spacing a 40m channel goes 3 → 11 verts/station, so the
4308-vert mesh grows to roughly 12–16k. Irrelevant — it is still ONE draw call
(`water_system.gd:272-282`) and one material, and the mesh is built once at load. Cost is a few
extra ms in `_build_combined_water_mesh`, behind the loading screen.

---

## 4. TRANSPARENCY AND RENDER ORDER — not the cause, but two live hazards

`water_static.gdshader:113` writes `ALPHA`. Godot 4 auto-detects that and puts the material on
the **transparent** pipeline: drawn after opaque, alpha-blended, depth-tested against the opaque
depth buffer. That depth test is what makes §3 fatal — where the terrain is in front, the
fragment is discarded, and there is no partial credit.

Two hazards worth naming, neither of which causes the invisibility:

1. **`depth_draw_always` (`water_static.gdshader:2`) on a transparent surface.** It forces depth
   writes from a blended pass. Because the whole map's water is a single mesh
   (`water_system.gd:278`) with no intra-mesh sorting, overlapping ribbons — and there ARE
   overlaps, 106 channels that confluence — will punch each other out in draw order rather than
   blending. It also clips any transparent effect drawn afterwards (smoke, tracers, the alpha
   foliage cards). `depth_draw_opaque` is the safer default; keep `always` only if the water must
   occlude particles, and then accept the self-overlap artefacts.
   **Sacrificed by switching to `opaque`:** at confluences two overlapping sheets double-blend
   and read slightly darker. Cheap price.
2. **One AABB for the whole map.** The combined mesh spans the entire AO, so its transparent
   sort key is the map centre and its bounds never cull. Every frame, from anywhere, the full
   ribbon is submitted. Acceptable at 4308 verts; worth revisiting if §3b's subdivision is
   combined with a much larger map. Not a correctness issue.

---

## 5. `ARRAY_TANGENT`, `NORMAL_MAP`, and the flow UV — all three CLEAN

- **No tangents.** `water_system.gd:265-270` sets exactly `ARRAY_VERTEX`, `ARRAY_NORMAL`,
  `ARRAY_TEX_UV`, `ARRAY_COLOR`, `ARRAY_INDEX`. `ARRAY_TANGENT` is never assigned, in this
  function or anywhere in the file. **Confirmed.**
- **The shader never touches `NORMAL_MAP`.** Zero occurrences in
  `terrain/water/water_static.gdshader` (whole file read, 117 lines). It writes `NORMAL` directly
  at `:85`, and correctly converts world → view space via `VIEW_MATRIX` before the write —
  `NORMAL` in a Godot 4 fragment shader is view-space, and `water_ripple_normal` returns world
  space (`:45-66`). The stated contract at `:10-11` matches the code. **Confirmed correct.**
- **The flow UV is consumed.** Baked at `water_system.gd:346` (`flow01`, biased into 0.02–0.98)
  into `COLOR.b` at `:355`, `:360`, `:365`. Read into `v_flow` at `water_static.gdshader:72`,
  and used at `:78-80` to reconstruct the heading and pick `flow_speed` over `still_speed`.
  **Confirmed wired end to end.**
  One tolerance check I ran because the `step(0.001, v_flow)` test at `:78` is a magic-number
  discriminator: `ARRAY_COLOR` quantises to RGBA8, so the 0.02 floor becomes 5/255 = 0.0196 —
  still six times the threshold, and the worst-case heading error from 8-bit quantisation is
  ~0.7°. The discriminator is safe. Noting it only so nobody later "tidies" the 0.02 bias out;
  at 0.004 it would collapse into the standing-water branch.

**Ruling: the shader rewrite is sound work. It is paint on a boat that is not in the water —
and the culling flip in its own `render_mode` line is what pulled the boat out.**

---

## 6. THE CARVE-VS-RIBBON PATH — the Arbiter's lead hypothesis is FALSE

The charge was that the ribbon might use a different or re-smoothed path than the carve. **It
does not. They are the same `PackedVector2Array`, on the same `Dictionary` object, in the same
`Array`.** Traced:

1. `terrain/core/terrain_manager.gd:375` — `river_paths = hydro.rivers`. GDScript `Array`
   assignment is **by reference**; this is an alias, not a copy.
2. `terrain_manager.gd:378-379` — `for path in river_paths: _smooth_river_path(path)`.
   `Dictionary` is likewise a reference type, and `_smooth_river_path` mutates in place via
   `path["points"] = smoothed` (`terrain_manager.gd:401`). The mutation lands on
   `hydro.rivers[i]["points"]`.
3. `terrain_manager.gd:381-382` — `for path in river_paths: _carve_riverbed(path)`. **A separate
   loop, after the smoothing loop completes.** The carve therefore reads the SMOOTHED points
   (`terrain_manager.gd:408`).
4. `terrain_manager.gd:374` — `hydrology = hydro`, the same object retained.
5. `scripts/levels/game_world.gd:166` — `water_system.generate_water_bodies(terrain_manager.hydrology)`
   passes that object; `water_system.gd:95-102` takes it as `prebuilt` and skips the fallback
   re-solve at `:96-101`; `:114` hands `hydro.rivers` to `_build_combined_water_mesh`, which
   reaches `_append_river_strip(r["points"], ...)` at `:259`.

**Smoothing happens BEFORE the carve, and the water receives the smoothed version. There is no
divergence.** Chase closed.

The one residual lateral offset is sub-cell and benign: the carve stamps at
`heightmap.world_to_cell(p.x, p.y)` (`terrain_manager.gd:419`), snapping to the 4m grid, while
the ribbon uses the exact float `p` (`water_system.gd:352-364`). Worst case ≈2.8m — but
`carve_radius` has a floor of 2 cells = 8m (`terrain_manager.gd:418`) and the full-depth zone
extends to `half_w` before the shoulder begins (`:431`), so the snap is fully covered.
**Not a defect. Do not spend a change on it.**

### What the Summoner is actually seeing when he says "not following the natural flow"

Given §1, the honest reading is that he is seeing **no sheet at all** and describing the ditch.
But three real effects would make even a correctly-wound sheet fail to read as flowing water:

- **The vertical jitter.** `y = maxf(minf(bed+0.55, minf(bank_l, bank_r)-0.1), bed+0.05)`
  (`water_system.gd:340-341`) has the clamp firing on 52.2% of stations and not on the other
  47.8%, station to station, at 4m spacing. The surface steps between `bed+0.55` and `bed+0.05`
  along the run — a 50cm sawtooth every few metres. Water does not do that. **Even fixed for
  culling, this reads as broken, not as a river.**
- **`bank_l` / `bank_r` are not banks.** Sampled at exactly `±half_w` (`water_system.gd:331-332`,
  `:337-338`), which the carve cuts at FULL depth — `falloff = 1.0 - smoothstep(half_w, reach,
  dist_m)` is 1.0 at `dist_m == half_w` (`terrain_manager.gd:431`). So the "bank" sample is bed
  height plus preserved relief, i.e. arbitrary hillside. The Arbiter's defect #2 is **confirmed
  by the falloff arithmetic**, not merely by the probe. The probe's `bank_l` reading 5m BELOW the
  bed is the expected output of that formula, not an anomaly.
- **The 20m foam band** from §3b, which washes the entire surface toward `col_foam`
  (`water_static.gdshader:102-105`).

---

## 7. SEQUENCING — a real second-order defect, not the cause

The mesh is built exactly once, at `scripts/levels/game_world.gd:166`. Later terrain edits route
through `_flush_terrain_dirty` (`game_world.gd:499-507`), which calls
`water_system.reseat_region(rect)` — and `reseat_region` (`water_system.gd:438-463`) touches
**only `water_map`**, the O(1) byte grid. It never rebuilds `CombinedWater`. Its own docstring
is honest about this (`water_system.gd:436-437`).

So firebase flattening and craters move the ground under a sheet that cannot respond. The
`region_rebuilt` wire exists and is connected (`game_world.gd:179`) — it just has no mesh
consumer.

**Recommendation: defer.** Do not add a mesh-rebuild hook in this change. Rebuilding the ribbon
per-crater means re-running `_append_river_strip` for every channel touching the rect and
re-committing the whole ArrayMesh (there is one mesh, not per-region meshes) — that is a
full-map rebuild per explosion. Correct order of work is: fix culling, fix seating, fix cross-
section; THEN, if the firebase demonstrably sits on a channel, either split the combined mesh
into per-chunk surfaces so a rect rebuild is local, or forbid site flattening within a channel's
`reach`.
**Sacrificed by deferring:** a crater or a flattened pad that intersects a creek will show the
old sheet floating over new ground until reload. Bounded and rare — `generate_swamps = false`
and `min_lake_depth = INF` mean water is confined to narrow channels, and site planning already
prefers flat dry ground.

---

## 8. RULING — ordered, with costs

| # | change | file:line | why | sacrificed |
|---|---|---|---|---|
| **1** | Reverse ribbon index winding to `[l0,c1,c0, l0,l1,c1]` / `[c0,r1,r0, c0,c1,r1]` | `water_system.gd:374-375` | **THE bug.** Every ribbon triangle is backfacing under the `cull_back` at `water_static.gdshader:2` | nothing; an under-sheet camera correctly sees nothing |
| **2** | Level the carve floor (write an absolute bed, not `current - depth`) | `terrain_manager.gd:434` | Kills defects 2 and 3 at the source: real banks, a real floor, one surface height per station | heightmap consumers — the terrain-track architects own this call, it is not mine to price |
| **3** | Subdivide the ribbon cross-section to ~`cell_size` spacing | `water_system.gd:352-365` | 3 verts across 40m chords straight through the bed; also makes `COLOR.r` shore/foam mean something | ~3× verts (4.3k → ~14k), still one draw call, built once behind the loading screen |
| **4** | Raise the clamp floor from `0.05` to ≥ `0.35` | `water_system.gd:341` | 5cm is inside the 0.10–0.30m bilinear-vs-triangle error of a 4m grid | shallower-looking creeks; a mitigation, not a fix — obsolete once #2 lands |
| **5** | `depth_draw_always` → `depth_draw_opaque` | `water_static.gdshader:2` | transparent depth writes punch out overlapping ribbons at confluences and clip later transparents | confluence overlaps double-blend slightly darker |
| **6** | Mesh rebuild on `region_rebuilt` | `game_world.gd:179` / `water_system.gd:438` | flattening moves ground under a mesh built once | **DEFER** — a full-map rebuild per crater is worse than the artefact |

**If only one change ships, ship #1.** It is one line, it is provably the difference between a
drawn surface and a culled one, and it explains the Summoner's report exactly.

**#1 alone is not enough for the EYE GATE.** It will put a jagged, 20m-foam-washed, half-buried
sheet in the ditch — visible, but not water. #1 + #3 + #4 gets a defensible sheet without
touching the heightmap. #2 is the correct fix and the only one that makes `bank_l`/`bank_r` mean
what their names claim, but its blast radius is the terrain track's to price, not mine.

## 9. THE LESSON

`render_mode` was edited; the geometry that feeds it was not re-derived. Nothing in GDScript can
observe a culling decision, so **every CPU-side probe in this investigation reported healthy
numbers about a surface that was never rasterised.** `tools/probe_water_seat.gd` measured the
seating perfectly and could not have caught this. When a render_mode flips from `cull_disabled`
to `cull_back`, the winding of every mesh that material touches becomes load-bearing for the
first time — and that mesh may have been built years earlier by someone who correctly did not
care.
