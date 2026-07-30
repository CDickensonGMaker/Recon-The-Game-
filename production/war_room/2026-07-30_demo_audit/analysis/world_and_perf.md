# DEMO AUDIT — WORLD BUILD, DUPLICATION, PERFORMANCE (512 m slice)

Date: 2026-07-30. Method: code read + glTF/JSON parse only. **The game was not launched and Blender
was not opened.** Every number below is a static count, a parse of a shipped asset, or arithmetic
over a constant in the tree. Anything I could not prove that way is marked **UNPROVEN**.

Scope: `scripts/world/site_planner.gd`, `nav_baker.gd`, `road_network.gd`, `paddy_stamper.gd`,
`mortar_pit.gd`, `destructible.gd`, `scripts/missions/mission_generator.gd`,
`scripts/levels/{demo_game,game_world,world_config}.gd`, `scripts/missions/siege_director.gd`,
`scripts/vehicles/heli_lift.gd`, `scripts/ai/air_traffic.gd`, `scripts/missions/terrain_watchdog.gd`,
`scenes/world/firebase_main.tscn`, `fsb_main_v3.glb` + `fsb_main_v3_mound.json` +
`kit/firebase_v3_destructibles.json`.

---

## MEASURED BASELINE FACTS (verified this pass, quote these freely)

Parsed out of `assets/world/building models/structures/firebase/fsb_main_v3.glb`:

| quantity | value |
|---|---|
| glTF nodes | 1,259 |
| visible mesh nodes | 430 |
| visible surfaces | **826** |
| triangles | **318,056** |
| `-colonly` collider nodes | 365 |
| `fb_int_` props | **178** nodes / **368** surfaces / **11,936** tris |
| `fb_veg_` merged veg | 19 nodes / 19 surfaces / 28,646 tris |
| everything else | 233 nodes / 439 surfaces / 277,474 tris |
| materials / textures | 34 / 32 |
| materials with `alphaMode:"BLEND"` | **15** (zero `MASK`) |
| materials with `doubleSided:true` | **34 / 34** |

**The interior-cull comment at `site_planner.gd:1108-1117` is numerically CORRECT** — 826 surfaces,
178 `fb_int_`, 368 surfaces, 11,936 of 318,056 tris. It reproduces exactly. See finding 8 for the
one claim in it that does not.

`fsb_main_v3_mound.json`: `mound_h 3.4`, `mound_fall 34.0`, `r0 66.0`, `berm_w 3.2`, **`step_h 0.0`**.

Character models (glTF parse, visible mesh nodes / surfaces):

| model | mesh nodes | surfaces |
|---|---:|---:|
| `vc_guerilla.glb` | 25 | **59** |
| `vc_guerilla_mosin/ppsh` | 25 | 55 |
| `vc_guerilla_rpd/rpg` | 25 | 58 / 57 |
| `us_grunt_rifleman.glb` | 61 | **78** |
| `us_grunt_marksman.glb` | 61 | 81 |
| `us_grunt_mg/pointman` | 51 | 71 |
| `huey.glb` | 27 | 27 |
| `f4_phantom.glb` | 16 | 16 |

> **PERF_LEDGER:988-990 is STALE on this point.** It records "VC / civilians / water — 3 nodes/13
> calls · already one mesh+material (not a target)". The shipped VC carries **25 mesh nodes and
> 55–59 surfaces**. Every draw-call budget in this ledger that leaned on "VC = 13 calls" is wrong by
> ~4×. Correct it on contact (NO-DRIFT law).

---

## FINDINGS, RANKED

### 1. P0 — EVERY RUNTIME PROP AND MAN INSIDE THE COMPOUND IS SEATED ~3 m UNDER THE FLOOR

`site_planner.place_firebase_main` sculpts the terrain to a **flat plateau at `seat_y`**
(`site_planner.gd:1031-1033` — `lerpf(h, seat_norm, …)`, one term, no mound term). The model is then
seated with `origin.y = seat_y` (`:1043`) and **keeps its own mound trimesh as the ground**
(`:1156-1161`). The mound manifest says the plate stands `mound_h = 3.4 m` (plus harmonics, so
~1.5–5.3 m) over its own toe, and the GLB's own markers confirm it: every compound marker parsed out
of the GLB carries a model-space **y between 1.9 and 4.1 m** (e.g. `GUN_POINT_001` y=3.4,
`FOOTPRINT_003` y=3.4, `USSupplyDepot_001` y=3.2, `APPROACH_001` y=2.9).

So inside the wire: **walkable floor = `seat_y` + ~3 m; `terrain_manager.get_height_at()` =
`seat_y`.** Anything seated on `get_height_at` is buried by ~3 m.

Placers that do exactly that, all inside the mound (r < ~70 m from compound centre):

| what | file:line | radius from centre | burial |
|---|---|---:|---:|
| garrison men (24 of them) | `mission_generator.gd:894` (`+0.5`) | 10–92 m | ~2.7 m |
| their `working_point_pos` | `mission_generator.gd:899` | same | ~3.2 m |
| their `home` (quarters) | `mission_generator.gd:903` | 32–68 m | ~3 m |
| the mannable M60 | `mission_generator.gd:921` | 10 m | ~3.4 m |
| **the mortar pit** | `mission_generator.gd:795` | 10 m | ~3.4 m |
| the armorer's bench (ADR-018) | `mission_generator.gd:786` | ~47 m | ~3 m |
| the boot-up field radio | `site_planner.gd:1413` | ~57 m | ~3 m |
| `gate_pos` / `spawn_pos` | `site_planner.gd:1061-1062` | 79 m / 57 m | ~2.9 m / ~3.4 m |

`fsb_garrison_plan` (`site_planner.gd:899-937`) **deliberately throws the authored marker Y away**
(`p.y = 0.0`, "y left at 0 for the caller to seat on terrain") — and the caller then seats on the
wrong surface. `fsb_gate_metrics` does the same (`:953`).

`GameWorld.surface_y()` (`game_world.gd:404-419`) is the correct source and its own header comment
names this exact failure ("get_height_at() alone buries anyone spawned inside the firebase"). It is
used by `game_flow.gd:227/272`, `field_director.gd:46`, `squad_system.gd:52`, `marching_cell.gd:169`,
`demo_game.gd:135` — **and by nothing in `mission_generator.gd`.**

Failure scenario: boot the demo. The player wakes on the bunk marker (correct — authored Y, from
`firebase_main.tscn`). He walks out of the hootch. There is no radio to hear the broadcast from and
no armorer's bench (both ~3 m under the mud). The mortar pit and the M60 are not there. Twenty-four
garrison Civilians are somewhere inside the trimesh; whether they get squeezed out or stay stuck is
**UNPROVEN without a run** — but see finding 2 for why they cannot recover.

Note `spawn_pos = gate_pos - out * 22.0` (`site_planner.gd:954`) puts the seat **22 m INSIDE** the
wire (r≈57 m from centre, well inside the mound). Three comments claim the opposite —
`mission_generator.gd:171` "the player's seat sits 22m outside the wire", and the `site_planner.gd:504`
pointer in it is dead (that line is `_stable_animals`). One of the code or the comments is wrong;
the geometry says the code puts him inside.

**Fix shape:** `mission_generator` and `_stamp_radio` must call `world.surface_y()`, or
`fsb_garrison_plan`/`fsb_gate_metrics` must stop zeroing the authored Y.

---

### 2. P0 — `TerrainWatchdog` CANNOT RESCUE ANYONE IN THE COMPOUND, AND BURIES THEM ON RESUME

`scripts/missions/terrain_watchdog.gd` is the recovery net, and it uses the same wrong height source:

- `:55` on resume from distance-suspension: `body.global_position.y = terrain.get_height_at(...) + 0.5`
  → teleports the man **~2.9 m under the mound floor.**
- `:59-61` fall-through re-seat: `ground_y = terrain.get_height_at(...)`; a man under the mound is
  *not* below `ground_y - 5.0`, so the check never fires; and if it did it would re-seat him to
  `ground_y + 0.5`, i.e. **back under the mound.** The recovery system is a burial loop inside the wire.

Compounding, on a 512 m map: `SUSPEND_DIST = 240`, `RESUME_DIST = 210`. The compound is ~190 m
across and the demo's authored village is ~165 m from its centre (finding 5). Walk to the village and
garrison men on the far side of the base are 250–290 m away → **`body.visible = false` and physics
off**. The player looks back at his own firebase and part of the garrison has vanished; when he
returns they teleport in ~3 m underground.

Also: neither teleport calls `reset_physics_interpolation()`, and `project.godot:307` has
`physics_interpolation=true`. Every suspend/resume streaks the body across the screen for a frame.
(`player.gd` calls it 8 times, `enemy_base.gd:2586` once — the pattern exists, the watchdog missed it.)

Third-order, and the reason it matters for the siege: siege cells spawn at `ring_min 190`/`ring_max 235`
(`demo_game.gd:193-194`). If the player is on the *far* side of the compound from the assault sector
(up to ~90 m off centre), attackers at 235 m are 325 m from him → **suspended, invisible, physics
frozen.** The assault stalls at the ring until he turns around. Magnitude **UNPROVEN** (depends on
whether `MarchingCell` re-enables its men), but the mechanism is in the file.

---

### 3. P0 — THE 80-SEGMENT PARAPET IS WIRED OUT OF THE NAVMESH

`site_planner._wire_parapet_destructibles` (`:1301-1346`) adds each `Destructible` to **`_parent`**
(= `GameWorld`, `:1323`) and then `mi.reparent(d, true)` (`:1339`) moves the wall mesh with it. All 80
segments (verified: `kit/firebase_v3_destructibles.json` `count`/`segments` = 80, names
`fb_sbg_seg_000`…`fb_sbg_seg_079`, box `6.6 × 0.37 × 1.17`, hp 140) therefore leave the firebase
scene subtree **before** `NavBaker` runs.

`NavBaker._queue_firebase` (`nav_baker.gd:126-136`) passes `site.nodes[0]` — the firebase root — as
the collider source, and `_add_colliders` (`:292-317`) only walks that subtree. `Destructible` never
joins `nav_blockers` and carries no `nav_box` meta, so `_add_structures` cannot see it either.

Result: **the perimeter revetment contributes zero geometry to the firebase navmesh.** The berm ring
underneath it (`fb_berm_ring_000-colonly`) *is* still in the subtree and is carved, and
`nav.agent_max_slope = 50.0` (`:196`) with the berm's ~37° inner face means Recast will mark the berm
crest and its outer face **walkable**. Besiegers get a navmesh that says they may walk over the wire
before a single sandbag is blown; they will path there and grind on the collider.

Ordering is the proof: `place_firebase_main` runs the parapet wiring at `site_planner.gd:1047`;
`nav_baker.queue_sites` runs at `mission_generator.gd:819`, later in the same build.

**Everything else about the parapet wiring does check out.** I traced it against today's re-mesh:
`_repair_glb_colliders` frees the `fb_sbg_seg_*` box-hull `StaticBody3D` and `_remesh_collider`
rebuilds it as `mi.create_trimesh_collision()` — a `StaticBody3D` **child of the MeshInstance3D**.
`_wire_parapet_destructibles` then walks `mi.get_children()` for a `StaticBody3D`, steals its
`CollisionShape3D` onto the `Destructible` and frees the body. Name-stripping is correct
(`fb_sbg_seg_079_080` → stem `fb_sbg_seg_079` → the mesh). `Destructible._do_destroy` (`:70-74`)
only walks *direct* children, and after `reparent` the mesh and the shape are both direct children,
so hide+disable both land. **The destruction path works; only the nav source is broken.**

---

### 4. P0 — THE FIREBASE KEEP-OUT COVERS THE ENTIRE 512 m MAP (the kilometre-AO assumption, #5)

`SitePlanner.FSB_HALF = Vector2(149.3, 111.2)` (`site_planner.gd:662`). `_set_fsb_keepout`
(`mission_generator.gd:103-106`) builds that rect around the compound centre, and every site/spawn
sampler grows it by `FSB_SITE_CLEARANCE = 40` → half-extents **189.3 × 151.2**.

The demo puts the firebase at the exact map centre (`mission_generator.gd:674-675`, `half = 256`).
`_passable_near` clamps every candidate to `[80, map_size - 80] = [80, 432]`
(`mission_generator.gd:131-132`) **before** the keep-out test (`:133`).

Arithmetic:
- keep-out x span = `[66.7, 445.3]` — the clamp span `[80, 432]` is **entirely inside it.**
- keep-out z span = `[104.8, 407.2]` — clamp span `[80, 432]` escapes only in `z ∈ [80, 104.8]` and
  `z ∈ [407.2, 432]`.

**So the only ground on the whole demo map that `_passable_near(..., FSB_SITE_CLEARANCE)` will accept
is two 25 m-tall strips at the map's north and south clamp edges.** There is no way out via x at all.

Consequences I traced through the demo plan (bearings computed from the GLB's own SOCKET/FACE_OUT
markers: `gate_out = (-0.883, 0.469)`, so `v_dir = (0.954, 0.298)` and `t_dir = (0.286, -0.958)`):

- **The village never uses its intended site.** Base = centre + `(176.5, 55.2)`, which is inside the
  grown keep-out; every escape needs `x_off > 189.3`, but the clamp caps `x_off` at 176. All 90
  attempts fail, the fallback point is also inside the keep-out, `_passable_near` returns
  `Vector3.ZERO`, and `mission_generator.gd:699-701` takes the emergency branch:
  `village = fsb_center + v_dir * 165.0` → centre + `(157.4, 49.2)`. **The demo village is always the
  fallback**, 165 m out instead of ~185–200 m, hard against the model's own authored treeline
  (which runs to ~149 m) and inside the keep-out the code was trying to respect. With
  `VILLAGE_FOOTPRINT_RADIUS = 34` (`site_layouts.gd:69`) and `clear_and_flatten(centre, r + 6)`, the
  village clears a 40 m disc reaching 125–205 m from the compound centre — straight through the
  authored 140–149 m treeline blend band.
- **The ambient VC patrols mostly do not spawn.** `mission_generator.gd:766` samples
  `_passable_near(mid, 30, 120, 60, FSB_SITE_CLEARANCE)` where `mid` is between the gate and the
  village — i.e. near the compound. Escape needs `|z_off| > 151.2` from a base at `z_off ≈ 38`, so a
  candidate needs a >112 m offset out of a 30–120 m radius: a thin sliver of the annulus. Most
  attempts return ZERO and `:769` does `continue`. **The demo loses most of its 2–3 ambient VC
  patrols silently.** Friendly patrols (`:849`, radius 40–150) fare better but not reliably.
- `_patrol_anchors` (`:176-185`) drops the village from the anchor pool because it is inside
  `route_keepout`. The one authored landmark in the demo is excluded from every patrol circuit.
- The temple is fine by luck: base = centre + `(53.0, -177.2)`, `|z_off| = 177 > 151.2`, accepted
  first try — but it lands within ~30 m of the map's south clamp edge.

This is the single highest-leverage structural defect in the demo world build: **the keep-out rect is
sized for a 1,280 m AO and is larger than the usable 512 m map.**

---

### 5. P1 — DUPLICATION: THINGS BAKED INTO THE GLB *AND* PLACED AT RUNTIME

I dumped every node name in `fsb_main_v3.glb`, resolved world translations up the parent chain, and
cross-checked each against the runtime placers. Full census:

| baked in the GLB | count | runtime placer | verdict |
|---|---:|---|---|
| `fb_mortar_pit_i` | **2** (at r=53.3 m and r=51.4 m) | `MortarPit.create` — `mission_generator.gd:796`, at `centre + pit_dir*10` = r≈10 m | **CONFIRMED DUPLICATE.** Three mortar pits in one compound; the runtime one is a full scene (nest + M29 + crates + 3 crew stations) and it is the *only* one AI can claim (`mortar_pits` group). The two authored pits are dead art. It is also buried ~3.4 m (finding 1). |
| `fb_howitzer_i` | 6 | none | clean — but see below |
| `fb_gun_pit_i` | 6 | — | — |
| `GUN_POINT_001` marker | 1, at **(-8.0, 3.4, -6.0)** | `_place_firebase_mg` → `MGEmplacement.create` at `post_pos + outward*1.0` (`mission_generator.gd:916-922`) | **CONFIRMED COLLISION.** `fb_howitzer_i` sits at **(-7.8, 3.3, -6.2)** — **0.29 m from the marker.** The one `gun_crew` post in `FSB_GARRISON_POSTS` builds a sandbagged mannable M60 emplacement *inside a 105 mm howitzer pit, on top of the gun*, and stands 2 men in it. |
| `fb_claymore_i` | **17** | `_wire_claymores` (`site_planner.gd:1367`) | **clean, and the best-behaved placer in the file** — it reads `mi.global_position` (authored, mound-correct), reparents the authored mesh under the mine and frees the stand-in. Note the comment says 16; the GLB carries 17 meshes and 17 `-colonly` nodes. `Claymore` uses a `_physics_process` cone scan, not an `Area3D`, so `for c in mine.get_children(): c.queue_free()` (`:1393-1394`) does **not** disarm the trigger. Verified. |
| `fb_supply_dump_i` | 11 | none (the 13 `USSupplyDepot*` markers only seat quartermaster **men**) | clean |
| `fb_sandbag_stack_i` | 6 | none | clean |
| `fb_water_point_i` | 3 | none | clean |
| `fb_latrine_i` | 4 | none | clean |
| `fb_bunker_mg_i` | 3 | none (`work_mg` maps to `sentry`, not `gun_crew` — `site_planner.gd:822`) | clean, deliberately |
| `fb_sbg_seg_*` | 80 | adopted in place, no new geometry | clean |
| `fb_tower_i` | 4 | `SirenTower.build_from_markers` adopts | clean |
| `ladder_bottom/top` | 4 pairs | `Ladder.build_from_markers` adopts | clean |
| `fb_int_*` | 178 | nothing — `_furnish_interior` is village-only (`SiteLayouts.INTERIOR_PROPS`), and `gen_fb_interior.py:390` says so explicitly ("Baked in, not furnished at runtime … running BOTH would double every prop") | clean |

**So the divergent-systems count for the firebase is two, not one:** the mortar pit (known) and the
M60-inside-the-howitzer (new). Both are also mis-seated by finding 1.

---

### 6. P1 — TWO OVERLAPPING NAVIGATION REGIONS IN THE DEMO, WHICH `nav_baker` ITSELF FORBIDS

`NavBaker.FSB_HALF = 185.0` (`nav_baker.gd:43`) → the firebase box spans centre ±185 m. On the demo
map that is x/z `[71, 441]`.

The demo village lands at centre + `(157.4, 49.2)` (finding 4) → **inside the firebase box.**
`_box_for(village_centre, 34+8)` clamps its half to `HALF_MAX = 70` → a 140 m box entirely inside the
firebase box. `queue_sites` (`:104-120`) routes the firebase through `_queue_firebase` and
`continue`s — **deliberately excluding it from `_merge`** (`:110-112`) — and `_merge` (`:146-159`) only
merges among the remaining boxes. So the two overlapping boxes are never merged.

`nav_baker.gd:143-145` is the file's own verdict on this: *"Overlapping, non-coincident regions
produce no edge connections and `map_get_closest_point()` picks arbitrarily — paths teleport between
layers."*

Worse, inside the overlap the two regions **disagree about the huts**: the firebase bake uses
`_add_colliders` (GLB colliders only) and never runs `_add_structures`, so `nav_blockers` are not
carved there; the village region carves them via `add_projected_obstruction`. Same ground, two
answers.

`should_bake` passes for the village because `village_defenders_0` is an anchor at its centre
(`mission_generator.gd:718-719`).

**Navmesh coverage answer for the demo:** the firebase region (370 × 370 m, terrain sampled at
`GRID_STEP = 4.0` → 92 × 92 quads = **16,928 triangles**) covers 52% of the 512 m map area and both
authored sites fall inside it. The temple gets **no region of its own** — nearest enemy anchor is the
treeline group at centre + `(37, 186)`, ~185 m from the temple, far outside `radius + 60 = 74`
(`should_bake`, `:93-101`). So the temple is inside the firebase box but its ruins are not carved
there, and the player's squad steers directly into the stonework. Answer to "can a besieger path at
all": yes, but on a mesh that omits the wire and overlaps a second region.

---

### 7. P1 — PERF: WHAT THE DEMO ACTUALLY ADDS, IN CALLS AND MILLISECONDS

Baseline of record (`PERF_LEDGER:896-904`): **1,368–1,481 total draw calls, 411–464 with the canopy
hidden, 30.7 fps at the seeded spawn pose**, seed 47225, scale 0.75, Forward+, Intel UHD.

**7a. Characters are the demo's dominant new call cost, and NOTHING culls them by distance.**
`visibility_range_end` is set in exactly 8 places repo-wide (`site_planner` ×2, `ground_clutter`,
`tree_cover_layer` ×1, `jungle_patch_layer` ×2, `spectre_gunship`) — **no character model anywhere
gets one.** Godot submits one draw call per surface per instance and never batches across
`GeometryInstance3D` (PERF_LEDGER:1010-1011).

Population at siege peak, from the constants:

| group | men | source |
|---|---:|---|
| siege attackers | **45** | `demo_game.gd:34` `SIEGE_STRENGTH` (cap `LIVE_CAP = 50`, `siege_director.gd:36`) |
| firebase garrison | **24** | 17 curated (`FSB_GARRISON_POSTS` sums to 17) + `clampi(24-17, 0, 12) = 7` work posts |
| …grown by the pad | **+4** | `HeliLift.ESTABLISHMENT = 28` (finding 9) |
| player squad | ~8 | squad roster |
| village defenders (not lazy) | 3–4 | `mission_generator.gd:718` |
| ambient/friendly patrols | 0–20 | mostly fail to spawn, finding 4 |
| **≈ total live bodies** | **~84** | |

Draw calls from bodies alone, at measured surface counts:

```
45 VC      × 55 surfaces = 2,475
36 US      × 70 surfaces = 2,520   (28 garrison + 8 squad)
                          ------
                            4,995 draw calls of characters
```

Against a **measured whole-frame budget of 1,368–1,481**. Even if only a quarter survive frustum
culling — and a night siege points the camera at the one 60° sector every attacker is in
(`SECTOR_DEG`, `siege_director.gd:266-268`) — that is **~1,250 calls of men, roughly 3× the entire
measured non-canopy frame.** This is the number to act on, and the cheap lever is the one already in
the file for structures: a `visibility_range_end` on character meshes.

**7b. The air package is uncapped for its first 95 seconds.** `AIR_MAX_IN_SKY = 14`
(`demo_game.gd:83`) and `flights_in_air()` returns `_in_flight.size()`, which is **one entry per
airframe** (`air_traffic.gd:215` rosters each wingman). But `_tick_air` (`:149-154`) runs the authored
opening in a branch that **`return`s before the cap check**. Six launches are booked at t = 3, 14, 26,
48, 70, 95 s; `FORMATION_SIZES` (`air_traffic.gd:39`) puts 6–9 ships on a `huey` and 3–5 on an `f4`;
`MAX_FLIGHT_SECONDS = 240` means none has been reaped yet. Worst case at t = 95 s:

```
9 huey + 1 huey(lz) + 5 f4 + 9 huey + 2 skyraider + 1 chinook = 27 airframes
27 × 27 surfaces (huey.glb)                                   ≈ 729 draw calls
```

…on top of a 411–464-call non-canopy frame, in the first minute and a half, before the siege. After
the opening the cap applies but is checked *before* a launch, so a single `huey` launch at 13 in the
air can reach **22 airframes ≈ 594 calls**.

**7c. The 60 → 30 Hz physics move is what makes the siege peak arithmetically possible.** Verified
`project.godot:304 common/physics_ticks_per_second=30` and `:307 physics_interpolation=true`. Using
the honest per-unit AI figure from `PERF_LEDGER:338-339` (0.214–0.218 ms per unit per physics frame,
post-body-gate):

```
84 units × 0.216 ms  = 18.1 ms per physics tick
at 30 Hz: 18.1 × 30  = 0.545 s of CPU per wall second   (~55% of one thread)
at 60 Hz: 18.1 × 60  = 1.09  s of CPU per wall second   (saturated — over budget)
```

So the tick change buys the siege ~0.54 s/s of headroom and is load-bearing, not cosmetic. **Caveat,
UNPROVEN:** that 0.216 figure came from a headless arena with no renderer and no siege geometry, and
`PERF_LEDGER:1056-1057` notes the render-frame hitzone sync is counted **nowhere**, so true cost is
higher than this arithmetic.

**7d. Destructibles and claymores are cheap, measured.** 80 `Destructible` nodes add zero surfaces
(they adopt existing meshes) and have no `_process`/`_physics_process` — destruction drains through
`Destructible.drain(n)` at `WorldConfig.STRUCTURE_LEVELS_PER_FRAME = 2`, and rubble is **one shared
MultiMesh / one draw call** (`destructible.gd:12-16`). 17 claymores scan at 2 Hz over the `enemies`
group: `17 × 50 × 2 = 1,700` distance tests per second. Negligible.

**7e. The demo map is nearly flat, and that is a RULE #1 problem before it is a perf one.**
`FSB_FLATTEN_RADIUS = 215` with `FSB_PLATEAU_FALLOFF = 0.107` means full seat out to `0.796 × 215 =
171 m` and a blend shoulder to 215 m. On a 512 m map centred at 256: **π·171² = 91,900 m² is dead
flat (35% of the map), and 145,200 m² (55%) is inside the modified radius.** Both authored sites are
in it — the temple at 170 m is fully flattened (falloff 0.137 > 0.107 → lerp weight 1.0), the fallback
village at 165 m likewise. Only a ~41 m border strip and the four corners keep any relief. The demo's
walkable world is a table top.

---

### 8. P2 — THE INTERIOR CULL IS SAFE, BUT ITS HEADLINE CLAIM IS NOT MEASURED

**Safety: verified, no exterior `fb_int_` prop exists.** `tools/gen_fb_interior.py:343-405`
(`INTERIOR_LAYOUT`) emits `fb_int_*` for exactly eight hosts — `fb_hootch`, `fb_mess`, `fb_toc`,
`fb_aid_station`, `fb_gp_tent`, `fb_sleeping_bunker`, `fb_bunker_mg`, `fb_bunker_fighting` — and
every prop is placed in that host's **local** frame through `M @ Vector((lx, ly, 0))` with z between
the host's own `floor` and `ceil - 1.72`. There is no outdoor layout, so nothing that should stay
visible at range is culled. The four remaining doubts and their answers:
- `fb_gp_tent` is canvas; its 5 crate stacks are inside it. 40 m is well past readable.
- `fb_bunker_mg` / `fb_bunker_fighting` are open-embrasure positions, but the props sit 0.9–1.7 m
  inside; they are occluded by the bunker roof from any exterior angle.
- `fb_int_fb_hanging_bulb` ×30 is hung at `ceil - 1.72` — under the roof by construction.
- No `fb_int_` node's collider changes: `_cull_interior_props` touches `visibility_range_end` only.

**Cannot be mistaken for destruction: verified.** `visibility_range_end` never writes `.visible`, and
the only readers/writers of `.visible` on world bodies are `destructible.gd:72` (direct children of a
`Destructible`; no `fb_int_` prop is one) and `terrain_watchdog.gd:46/54` (CharacterBody3D in the
`enemies`/`allies`/`civilians` groups only). No `is_destroyed()`/cover query reads `.visible`. Clean.

**The claim that is not proven:** `site_planner.gd:1108` — *"THE INTERIORS COST 45% OF THE COMPOUND'S
DRAW CALLS FOR 4% OF ITS GEOMETRY."* 368/826 = 44.6% of the GLB's **surfaces**, and 11,936/318,056 =
3.75% of its tris — both reproduce exactly. But 368 surfaces cannot be 45% of the compound's *draw
calls* when the measured non-canopy frame is only **411–464 calls total** for the whole world
including terrain, water, characters and every other structure. Most of those 368 were already being
frustum- or occlusion-culled. Under the ledger's own binding rule (`PERF_LEDGER:1066-1068`: no FPS
delta accepted unless the call delta has the right sign and a plausible magnitude), the cull's
benefit is **UNPROVEN** and should be re-worded to "45% of the model's surfaces" until a windowed
A/B/A run prints the call delta. The change itself is free and correct; only the headline overclaims.

---

### 9. P2 — TWO GARRISON CEILINGS THAT DISAGREE, AND THE PAD BREAKS THE DOCUMENTED ONE

`SitePlanner.FSB_GARRISON_MAX_MEN = 24` (`site_planner.gd:830`) is described as *"THE garrison
ceiling … Guarded by `tests/test_firebase_garrison.gd`, which reads THIS constant."* Its own comment
at `:836-840` warns that *"holding both as independent constants is how the compound came to hold 17
curated + 12 work = 29 men against a documented ceiling of 24."*

`HeliLift.ESTABLISHMENT = 28` (`heli_lift.gd:23`) is a third such constant. `_choose_mission` (`:96`)
compares live garrison to 28, so at boot (24 men) **every landing Huey delivers**:
`room = 28 - 24 = 4`, `n = min(4, randi(3,6))` = 3–4 men (`:176-178`). The demo books two `lz_cycle`
landings in the opening (`demo_game.gd:74, 77`), so **the compound reaches 28 men — 4 over the
documented ceiling the garrison test asserts.** Each is a full US body (~70 surfaces, finding 7a).

---

### 10. P2 — PADDY FIELDS ARE STAMPED BEFORE THE FIREBASE SCULPTS THE GROUND UNDER THEM

`plan_demo_world` calls `PaddyStamper.stamp(...)` at `mission_generator.gd:665-666`, which **builds
real `PaddyField` nodes into the world at plan time** (props + water at the then-current terrain Y).
`place_firebase_main` runs later (`:741`) and (a) `clear_and_flatten(centre, 140)` and (b)
`modify_terrain(centre, 215, → seat_norm)`.

Any paddy whose cells fall within 215 m of the compound centre has its ground moved out from under
it while its water plane and rice props stay put — floating or drowned. On the 1,280 m map the
firebase is placed off-centre so this is a lottery; **in the demo the firebase is at the exact map
centre and the sculpt covers 55% of the map area** (finding 7e), so the odds are high rather than
incidental. Magnitude per paddy is **UNPROVEN** without a run (it depends on where seed 29072026 puts
rice), but the ordering defect is unconditional.

Good news on the demo's side: `plan_demo_world` passes `village_floor = 0` (`:666`), so the
`push_error` at `paddy_stamper.gd:71-76` about "AO is malformed" correctly does not fire on a slice.

---

### 11. P3 — THE FIGHTING STEP THE 07-29 DECREE PROMISED DOES NOT EXIST (already known, confirming)

`site_planner.gd:752-762` `_fighting_step` reads `step_h` from the manifest; the shipped
`fsb_main_v3_mound.json` has `"step_h": 0.0` with a note that the step was turned **off by ruling on
2026-07-29** and belongs in Blender. So `_fighting_step` returns 0 and no banquette exists in the
heightmap. That much is a decision, not a bug.

The **drift** is that `site_planner.gd:733-762` still carries 25 lines of comment asserting the
opposite as current fact ("Since the one-ground decree the TERRAIN is the collider under the
base … a banquette raised in the heightmap is real ground a man can walk up … He clears it by ~0.11 m
standing"). None of that is true of the shipped build, and it is the kind of claim that gets acted on.
Related: `fsb_mound_height` (`:706-730`) now has exactly **one caller** — `_audit_one_ground` at
`:1226` — and that audit's one-way test (`terrain − model_y > 0.6`) can never fail while the terrain
is a flat seat and the model stands 1.5–5.3 m proud of it. **The instrument that is supposed to catch
finding 1 passes trivially and prints "terrain sits under the model everywhere".** Correct it or the
next reader trusts it. (`production/war_room/2026-07-30_interior_first_firebase/` reached the
`step_h = 0` half of this independently; the dead-audit half is new here.)

---

### 12. P3 — `SPECTRE_KEEP_OUT_M = 420` CANNOT BE SATISFIED ON A 512 m MAP

`air_traffic.gd:227` pushes a Spectre orbit centre 420 m off the firebase, then clamps it to
`[40, map_size - 40] = [40, 472]` (`:283-284`). From a centre at 256, the furthest reachable point is
216 m away — **always inside the 420 m keep-out.** The push silently fails and the orbit lands
~216 m from the compound with `ORBIT_RADIUS 160`, i.e. its beaten zone reaches back over the base.
`AIR_ROTATION` (`demo_game.gd:84`) contains no `spectre`, but `EXCLUDE_AIR_TRAFFIC = false` leaves the
sim schedule live, so **whether the demo can book one is UNPROVEN** — the geometry failure is not.
Same class of defect as finding 4: a constant sized for a kilometre AO.

---

## VERIFIED-CLEAN (checked, nothing wrong — recorded so nobody re-checks)

- `Destructible` parapet wiring end-to-end after today's re-mesh: name stripping, shape theft,
  `reparent`, hide+disable on destroy, `AgentRegistry.register`, `fsb_parapet` group. Works.
- `_cull_interior_props` cannot hide an exterior object and cannot be read as destruction (finding 8).
- `_wire_claymores` — authored positions, authored meshes kept, trigger not freed.
- `NAV_IGNORE_PREFIXES` still matches after the re-mesh: `create_trimesh_collision()` names the new
  body `<mesh>_col`, so `fb_veg_*_col` and `fb_int_*` colliders are still skipped by `_add_colliders`.
- `WorldConfig.NAV_SITE_KINDS` contains `firebase_main` (the dead-`"firebase"`-string bug is fixed).
- `paddy_stamper` reads grid geometry from the live grid, not the stale 256/12.0 const pair.
- `demo_game._open_siege` correctly escalates the probe via `reinforce()` instead of returning early.
- `road_network.build` on one village is well-formed; roads only thin vegetation.

---

## RANKED FIX ORDER (my recommendation to the Arbiter)

1. Route every in-compound placer through `GameWorld.surface_y()`, or stop zeroing the authored
   marker Y — findings 1 + 2. Everything else in the compound is downstream of this.
2. Fix `TerrainWatchdog`'s height source and add `reset_physics_interpolation()` — finding 2.
3. Scale the keep-out to the map (or clamp `FSB_HALF`-derived rects by `map_size`) — finding 4.
   This one silently deletes content, which is worse than breaking loudly.
4. Feed the parapet into the nav bake — keep the `Destructible` under the firebase root, or add it to
   `nav_blockers` with a `nav_box` — finding 3.
5. Put the firebase box into `_merge`, or shrink the village box when it is inside it — finding 6.
6. `visibility_range_end` on character meshes — finding 7a. Biggest measured-arithmetic perf win
   available in the demo.
7. Delete the runtime `MortarPit.create` or delete the two baked pits; move `GUN_POINT_001` off the
   howitzer or stop building an MG there — finding 5.
8. Reconcile 24 vs 28 — finding 9. Then the comment corrections: findings 8 and 11.
