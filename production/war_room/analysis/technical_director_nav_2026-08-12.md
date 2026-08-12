# TECHNICAL DIRECTOR — Why allies get stuck, spawn badly, and fail to navigate

**War Room 2026-08-12 · read from code, not docs · every claim carries a `file:line` or a measured number**

Method note: I traced the code paths and I measured `fsb_main_v3.glb` directly out of its glTF
JSON chunk (node table, parenting, transforms, per-mesh triangle counts). Where I inferred a
runtime outcome from geometry + engine defaults without watching a bake, I mark it **SUSPECTED**
and say what would settle it. Everything marked **CONFIRMED** is a code path I followed end to end.

---

## 0 · THE ONE-PARAGRAPH ANSWER

The firebase navmesh is baked from *the colliders still hanging under the firebase root at bake
time*. Two "repair" passes that run earlier — the collider remesh and the destructible wiring —
between them **move all 80 perimeter parapet colliders out of that root**, and the bake never
sees them. The navmesh therefore describes a compound with **no perimeter wall**, and routes men
straight into 92,480 triangles of sandbag revetment they cannot pass. The stuck watchdog cannot
save them, because they are standing *on* valid navmesh — the mesh is simply wrong. Underneath
that sit three amplifiers: an `agent_max_climb` silently quantized from 0.4 m to **0.25 m**, a
**second buried walkable layer** under the mound because raw terrain is fed in alongside the mound
trimesh with every Recast filter off, and a LOD watchdog that **re-seats allies onto roofs** using
the very function the codebase already documented as the roof bug.

---

## 1 · ROOT CAUSES, RANKED

### R1 — CONFIRMED · The entire 80-segment perimeter parapet is absent from the navmesh

The chain, in execution order inside `place_firebase_main`:

1. `site_planner.gd:1265` — `_repair_glb_colliders(root)`.
   At `:1403-1408` every `StaticBody3D` whose name starts with a `REMESH_COLLIDER_PREFIXES`
   entry (`:1325` = `fb_veg_` and **`fb_sbg_seg_`**) is queued for deletion; `:1409-1411` deletes
   it; `:1412-1414` calls `_remesh_collider`.
2. `site_planner.gd:1481-1490` — `_remesh_collider` strips the export ordinal and calls
   **`mi.create_trimesh_collision()`** on the *visual* mesh. Godot's API contract: this adds a
   `StaticBody3D` **as a child of the MeshInstance3D**. The collider that used to be a *sibling*
   at the GLB root is now a **child of the wall mesh**.
3. `site_planner.gd:1267` — `_wire_parapet_destructibles(root)`. At `:1612` it creates a
   `Destructible` and parents it to **`_parent`** — that is GameWorld, **not** the firebase root.
   At `:1617-1627` it walks `mi.get_children()`, finds the freshly-created `StaticBody3D`, and
   **moves the `CollisionShape3D` onto the Destructible**. At `:1628` `mi.reparent(d, true)` moves
   the wall mesh too.
4. `mission_generator.gd:956` — `nav_baker.queue_sites(...)` runs *after* all of that.
5. `nav_baker.gd:150-159` — `_queue_firebase` takes `site["nodes"][0]` (the firebase root) as the
   sole `colliders` root.
6. `nav_baker.gd:374-399` — `_add_colliders` walks a stack seeded **only** with that root.

The parapet now lives under GameWorld. **The walk never reaches it.**

**Measured cost** (from the GLB): the shipped `-colonly` parapet twins are **12 triangles each**
(80 × 12 = 960 tris — i.e. box hulls; the `COL_TRIMESH` listing at `tools/gen_firebase_v3.py:841-853`
has *not* landed in the shipped asset, which is why the runtime remesh still fires). The remesh
rebuilds them from the visual meshes: **92,480 triangles, 1,156 per segment**. That is the single
largest solid structure in the compound and **none of it reaches the bake**.

This is precisely the failure the firebase collider path was written to prevent —
`nav_baker.gd:36-41`: *"Baked that way the mesh would run flat through every bunker and berm, and
the men would path INTO walls with full confidence — worse than no navmesh, because it would look
deliberate."* It is happening, just to the berm instead of the bunkers.

**Why the stuck watchdog cannot rescue it.** `ally_base.gd:59-79` sidesteps, flips direction three
times, then calls `_rescue_snap` (`:86-95`). `_rescue_snap` asks `NavRouter.nearest_mesh_point`,
which returns the man's own position because **he is standing on valid navmesh** — the mesh runs
right through the parapet footprint. `off.length() <= OFF_MESH_M` at `:92` returns early. He
sidesteps forever against a wall the router insists is open ground. That is the observed
"allies get stuck on things."

**Second-order:** `Destructible._do_destroy` (`destructible.gd:180-182`) disables the shapes and
`:193-195` calls `breach_at`. The re-bake (`nav_baker.gd:229-236`) re-runs `_add_colliders` on the
**same firebase root**, which still cannot see the parapet. A blown wire changes nothing in the
navmesh because the wire was never in it. The comment at `destructible.gd:176-179` asserting the
mesh "is correct the moment it is rebuilt" is **false for the parapet**.

---

### R2 — CONFIRMED · Bunkers, towers and sandbag stacks are never adopted; destroyed ones stay solid forever

Measured from the GLB: **all 1,259 nodes are flat at the scene root** — every one of the 365
`-colonly` nodes is a **sibling** of its visual mesh, never a child.

`_adopt_structure` (`site_planner.gd:1706-1718`) does `for c in mi.get_children(): var body := c as StaticBody3D`.
A bunker's visual mesh (`fb_bunker_mg_i`) has **no children** — its collider is the sibling
`fb_bunker_mg_i_082-colonly`. The loop matches nothing. **No shape is ever moved.**

Consequences:
- **Nav (benign today):** the collider stays under the firebase root, so bunkers/towers *are*
  correctly baked into the initial navmesh. This is luck, not design.
- **Destruction (broken):** `_do_destroy` (`destructible.gd:178-182`) iterates `get_children()` on
  a Destructible that owns **no CollisionShape3D**. Nothing is disabled. A "destroyed" bunker,
  MG bunker, sleeping bunker, tower or sandbag stack **keeps stopping rounds and keeps blocking
  movement**, and the breach re-bake carves it exactly as before. The comment at
  `site_planner.gd:1704-1705` — *"A shape left nested under the mesh's auto-generated body survives
  the blast, and the 'destroyed' bunker keeps stopping rounds"* — describes the bug it did not fix.

Affected count from the GLB: 7 `fb_bunker_fighting_i` + 3 `fb_bunker_mg_i` + 3 `fb_sleeping_bunker_i`
+ 4 `fb_tower_i` + 6 `fb_sandbag_stack_i` = **23 structures**.

*(Note the asymmetry: `_adopt_structure` carefully preserves `shape.global_transform` at `:1714,1717`
while `_wire_parapet_destructibles` at `:1625-1626` does not. The parapet gets away with it only
because all 80 `fb_sbg_seg_*` nodes carry **identity transforms** — measured. Any future segment
with a real transform would be silently displaced.)*

---

### R3 — CONFIRMED (the value) / SUSPECTED (the consequence) · `agent_max_climb` is 0.25 m, not 0.4 m

`nav_baker.gd:264-270` reads cell metrics from the server and snaps the agent metrics:

```gdscript
nav.agent_max_climb = floorf(0.4 / nav.cell_height) * nav.cell_height
```

`project.godot` has **no `[navigation]` section** (verified: sections present are `animation`,
`application`, `audio`, `autoload`, `debug`, `display`, `editor`, `filesystem`, `input`,
`layer_names`, `physics`, `rendering` — no navigation). So the map runs Godot's default
`cell_height = 0.25`, and:

- `agent_radius = ceil(0.5/0.25)*0.25 = 0.50` — exact, no loss.
- `agent_height = ceil(1.8/0.25)*0.25 = 1.80` — exact, no loss.
- **`agent_max_climb = floor(0.4/0.25)*0.25 = 0.25`** — **37.5 % of the intended step allowance
  thrown away**, and it is the one metric that is *floored*.

A 0.25 m step limit on the compound's authored ground — the mound whose entire artistic point is
"destroyed earth, shell holes, thrown-up lips" (`site_planner.gd:1243-1245`) — turns every crater
rim, duckboard edge, trench lip and sandbag course into an unwalkable cliff. Recast then drops the
resulting sub-`region_min_size` fragments. This is the classic mechanism behind
*"allies 5 m from their post could not path to it"* already recorded at `nav_baker.gd:361-363`.

**SUSPECTED**, because I did not dump the baked polygon islands. Settled cheaply: the bake already
prints `verts/polys` at `nav_baker.gd:308-309`; bake once at climb 0.25 and once at 0.40 and compare
polygon counts and island counts.

---

### R4 — SUSPECTED (high confidence) · A second, buried walkable layer under the whole mound

`_add_terrain` (`nav_baker.gd:326-344`) synthesises a 4 m-step heightmap grid across the **entire
370 × 370 m** firebase box and adds it as source faces. `_add_colliders` then adds
`fb_terrain_mound` — **13,984 triangles**, the compound's real walkable ground
(`gen_firebase_v3.py:841-847`, `site_planner.gd:1396-1402`: *"This trimesh IS the walkable ground now"*).

But the terrain under the compound is **flattened to the mound's TOE** (`site_planner.gd:1241-1253`).
From the mound manifest (`fsb_main_v3_mound.json`, read directly): `mound_h = 3.4`, `berm_h = 1.22`,
top harmonics ±~1.9 m — so the mound surface stands **~1.5 m to ~6.5 m above the flat terrain plate**
across the compound.

`nav.agent_height = 1.8`. Everywhere the mound is more than 1.8 m proud, the buried terrain plate
has legal headroom and bakes as a **second walkable layer under the ground the men stand on**.
Nothing suppresses it: `nav_baker.gd:258-273` sets only `cell_size`, `cell_height`, the three agent
metrics, `border_size` and `filter_baking_aabb`. Godot's three Recast filters —
`filter_low_hanging_obstacles`, `filter_ledge_spans`, **`filter_walkable_low_height_spans`** — all
default to `false` and are never touched.

Why it hurts: `NavRouter` clamps both the target (`nav_router.gd:110-114`) and the agent's own
footing (`:132-135`) with `map_get_closest_point`, which is a nearest-polygon query with no layer
preference. At the **mound skirt** — 1.5–3 m of separation, exactly where the gate is and where men
walk in and out — the two layers are close enough that the query can pick either. `nav_baker.gd:167-169`
already names this exact hazard for overlapping *regions* (*"map_get_closest_point() picks
arbitrarily — paths teleport between layers"*); here it exists **inside one region**, because two
grounds were fed into it.

Also a straight cost: the box is 370 m at `cell_size 0.25` = a **1,480 × 1,480 Recast heightfield**
(2.19 M columns), larger than the 1,024² the file header calls "the wrong unit" at `nav_baker.gd:3-5`,
and it is being asked to voxelise a redundant second ground.

**SUSPECTED.** Settled by printing `nav.get_polygon_count()` with and without the terrain grid on
the firebase job.

---

### R5 — CONFIRMED · The LOD watchdog re-seats allies onto roofs

`terrain_watchdog.gd:48-57`: whenever a suspended body re-enters `RESUME_DIST` (210 m) it does

```gdscript
body.global_position.y = world.surface_y(body.global_position) + 0.5
```

`surface_y` (`game_world.gd:404-423`) fires a ray from `ground + SURFACE_PROBE_UP` **downward** and
takes the **first hit**. `SURFACE_PROBE_UP = 18.0` (`game_world.gd:428`) — well above every hootch
(2.5 m), every bunker and most of the 9 m towers. Inside the wire, the first hit under that ray is
almost always a **roof**.

The codebase already knows this. `game_world.gd:431-435`: *"surface_y's top-down ray stood every
covered garrison post — and the whole squad, ringed around an indoor bunk — ON THE ROOFS (his
playtest, 2026-08-04)"*, which is why `floor_y` exists at `:436`. `squad_system.gd:71-75` and
`mission_generator.gd:1027-1087` were converted to `floor_y`. **The watchdog was not.**

Who it hits: `terrain_watchdog.gd:38-39` exempts only `squad_member` allies. **Garrison defenders
and friendly patrols are not exempt** — they are precisely the men who cross the 240/210 m boundary
every time the player patrols out and walks back. They resume standing on a hootch roof, off the
navmesh; `nav_router.gd:132-139` then returns a horizontal "get back on the mesh" vector, and the man
walks off the roof or grinds against the ridge. This is a *fossil of a fix*: the correct helper was
built and one caller was left behind.

*(Related drift, POINTER LAW: `game_world.gd:400-403` asserts the firebase "reaches y=14.5
(site_planner.gd)". The mound manifest says `mound_h 3.4` with a max of roughly 6.5 m including
berm and harmonics, and no `14.5` appears in `site_planner.gd`. `SURFACE_PROBE_UP = 18.0` was sized
off that stale number, and the oversized probe is what makes the roof hit near-certain.)*

---

### R6 — CONFIRMED (contract) · The nav ignore list is a **name** contract on the collider's parent

`nav_baker.gd:371`: `NAV_IGNORE_PREFIXES = ["fb_veg_", "fb_int_"]`, tested at `:386-392` against
**`cs.get_parent().name`**.

Measured against the GLB, this is currently correct and load-bearing:
- ~178 `fb_int_*-colonly` props (cots, footlockers, hanging bulbs) — skipped. Without the skip they
  shred every interior into unreachable slivers.
- 5 merged `fb_veg_*-colonly` solids (90 stumps, 46 logs) — skipped, and still skipped after the
  remesh because `create_trimesh_collision` names the new body `fb_veg_tree_stump_col`, which still
  begins with `fb_veg_`.

The fragility: this depends on a Godot naming convention (`<mesh>_col`) plus a Blender export
convention (`{base}_{i:03d}-colonly`, `gen_firebase_v3.py:867`) plus `_fixstr` stripping. Any rename
in Blender silently changes what the navmesh contains, with **no error**. `air_traffic.gd:61-64`
already records one such rename break from the v3 re-export.

---

### R7 — CONFIRMED (mechanism) · Colliders authored at the model origin defeat the box test

`_add_colliders` accepts a shape only if `NavBaker._xz_contains(box, cs.global_position)`
(`nav_baker.gd:384`) — an **origin** test, not a bounds test.

Measured: **88 of the 365 `-colonly` nodes carry no transform at all** (geometry baked into
model space) — including `fb_terrain_mound`, `fb_berm_ring`, all 80 `fb_sbg_seg_*` and the 5 veg
solids. Their `global_position` is the firebase root origin. `FSB_AABB_CENTER = Vector3.ZERO`
(`site_planner.gd:695`), so the root origin lands dead centre in the box and they all pass — today.

It is a coin balanced on its edge: if the model origin ever moves outside a bake box (a smaller
site, a re-authored pivot, a second compound), **the entire 370 m ground plate silently drops out of
the navmesh** and the log prints a happy "bake done". Nothing warns.

---

## 2 · WHAT THE BAKE ACTUALLY INCLUDES AND EXCLUDES

Measured directly from `assets/world/building models/structures/firebase/fsb_main_v3.glb`:

| | count | tris |
|---|---|---|
| glTF nodes (all flat at scene root) | **1,259** | — |
| meshes | 506 | — |
| visible geometry | 894 nodes | 318,056 |
| `-colonly` collision twins | **365** | 148,330 |

**Fed to the firebase navmesh today** (`_add_colliders`, after every skip and every reparent):

| family | colliders | tris | in navmesh? |
|---|---|---|---|
| `fb_terrain_mound` | 1 | 13,984 | **yes** — the compound's ground |
| `fb_gun_pit_i` | 6 | 29,160 | yes |
| `fb_bunker_fighting_i` | 7 | 20,608 | yes |
| `fb_hootch_i` | 8 | 20,576 | yes |
| `fb_tower_i` | 4 | 17,392 | yes |
| `fb_bunker_mg_i` | 3 | 11,580 | yes |
| `fb_sleeping_bunker_i` | 3 | 9,222 | yes |
| `fb_toc_i`, `fb_mortar_pit_i`, `fb_aid_station_i`, `fb_gp_tent_i`, `fb_gate_gap_i`, `fb_trench_run_i`, `fb_mess_i`, `fb_berm_ring`, `bwire_card_ring`, `fb_latrine`, `fb_water_point`, `fb_burn_barrel`, `fb_supply_dump`, `fb_helipad`, `fb_howitzer`, `fb_claymore` | ~90 | ~22,000 | yes |
| **`fb_sbg_seg_` (perimeter parapet)** | **80** | **92,480 after remesh** | **NO — R1** |
| `fb_int_*` interior dressing | ~178 | ~1,200 | **no — deliberate** (`nav_baker.gd:365`) |
| `fb_veg_*` merged solids | 5 | ~27,600 after remesh | **no — deliberate** (`nav_baker.gd:359-363`) |
| synthesised terrain grid | — | ~17,000 | yes — **and it should not be, R4** |

**Prefix census of the whole node table** (top families): `fb_int` 356 · `fb_sbg` 160 ·
`fb_claymore` 34 · `prop_storage` 26 · `fb_mud` 24 · `fb_veg` 24 · `fb_supply` 22 · `fb_bunker` 20 ·
`fb_trench` 16 · `fb_hootch` 16 · `fb_gun` 12 · `fb_howitzer` 12 · `fb_sandbag` 12 · `fb_tower` 8 ·
`fb_latrine` 8 · plus marker nodes (`tower_los`, `bunker_los`, `SOCKET_A/B`, `FACE_OUT`, `fb_helipad`).

### Can a single 1,259-node GLB produce a good navmesh at all?

**Yes — the asset is not the problem, and this deserves saying plainly.** The export contract is
sound and unusually disciplined:

- Every collider is an explicit authored `-colonly` twin (`gen_firebase_v3.py:857-892`), so *nothing*
  about what is solid is inferred at runtime.
- `COL_NONE` (`:818-820`) correctly makes leaf cards, mud, scorch, roads and duckboards passable.
- `COL_TRIMESH` (`:841-853`) correctly gives the ground, bunkers, hootches, TOC, towers, gun pits,
  trenches and the gate gap their **real shape**, so doorways and firing slits survive.
- The mound is a single welded surface with a published slope contract
  (`FIREBASE_BLENDER_HANDOFF.md §00`, referenced at `site_planner.gd:1249-1250`).
- The whole thing weighs **148 k collision triangles** — Recast eats that without complaint.

The problems are all **downstream of the GLB**, in what runtime code does to it. One caveat that
*is* the asset's: `fb_sbg_seg_` colliders shipped as **12-tri box hulls** despite being listed in
`COL_TRIMESH` — the re-export has not landed. Landing it deletes the remesh (`site_planner.gd:1403-1414`)
and, with it, the mechanism that lets the parapet be stolen from the nav root at all.

**Recommendation: do not blame the GLB and do not split it to fix nav.** Split it for authoring
ergonomics or draw calls if you like, but R1–R5 are all code.

---

## 3 · ARE INTERIORS NAVIGABLE TODAY?

**Partially — the geometry allows it, three things stop it.** This is more optimistic than
`ai_stress_arena.gd:1204-1206` ("walkable interiors are future work"), which is a statement about
the *stress lab's* AABB-box ruins (`_place_ruin` → `_add_aabb_collider`), **not** about the firebase.
The firebase is a different and much better case.

**What is already right:**
- Hootches, TOC, mess, aid station, bunkers and the gate gap are all `COL_TRIMESH`
  (`gen_firebase_v3.py:841-853`), so doorways exist in the collision. `collision_table.gd:88-89`
  states the same doctrine for temples: *"Trimesh so the cella interiors stay walkable — a box hull
  here would seal them shut."*
- Interior clutter is excluded from the bake by name (`nav_baker.gd:365,371`), so cots and
  footlockers do not shred the floor.
- The floor is the mound trimesh, which is fed in and is continuous.
- `floor_y` (`game_world.gd:436-445`) exists specifically so an authored interior point seats on its
  own floor, and `spawn_player_at`'s `seat_on_surface=false` path (`:448-452`) trusts an authored Y.

**What blocks it:**

1. **`agent_max_climb = 0.25 m` (R3).** A hootch threshold, a duckboard, a sandbag course or a
   bunker step over 25 cm is a wall to Recast. Interiors are exactly where 25–40 cm steps live.
2. **`agent_radius = 0.5 m` erosion vs. doorway width.** Recast erodes the walkable border by the
   full agent radius. A doorway needs **> 1.0 m clear** after erosion, quantised to 0.25 m cells,
   to leave any connecting polygon at all. Nothing in the pipeline measures doorway clearance, and
   nothing warns when a room bakes as an isolated island. **SUSPECTED** — settled by baking and
   counting disconnected regions inside each `fb_hootch_i` footprint.
3. **The second layer (R4).** Interior floors sit on the mound; the buried terrain plate sits under
   them. Inside a building the vertical gap is small enough that `map_get_closest_point` can clamp
   an indoor target onto the plate below the floor.

**Verdict:** interiors are *one bake-parameter change and one measurement away* from working, not a
rewrite. Fix R3 and R4 first, then measure doorways before authoring anything new.

---

## 4 · SEPARATE GODOT SCENES INSTEAD OF ONE BAKED GLB — NAV AND SPAWN ONLY

### What gets better

- **The bake stops depending on one root.** `_queue_firebase` (`nav_baker.gd:150-159`) currently
  hangs everything on `site["nodes"][0]`, and R1 is the direct cost of that single point of failure.
  Per-building scenes force an explicit list — and `queue_site_with_colliders` (`nav_baker.gd:146-148`)
  already takes a root, so the extension is small.
- **R7 evaporates.** Today 88 colliders share the model origin, so `_xz_contains` (`nav_baker.gd:384`)
  is an all-or-nothing coin flip for them. Per-building scenes give each collider a real world
  position and the box test becomes meaningful.
- **R2 fixes itself.** `_adopt_structure`'s `mi.get_children()` loop (`site_planner.gd:1706`) works
  correctly when a building scene carries its collider as a child of its mesh — which is the normal
  Godot scene shape. Destroyed bunkers would finally stop blocking.
- **Per-building `NavigationObstacle3D`** becomes available, replacing the hand-walked shape parser
  entirely for the non-ground structures.

### What breaks

- **`NAV_IGNORE_PREFIXES` is a name contract on the collider's PARENT** (`nav_baker.gd:386`).
  Repackaging into scenes will rename nodes. If interior props stop presenting a parent named
  `fb_int_*`, **178 cots and hanging bulbs re-enter the bake** and fragment every interior — with
  no error, exactly the failure `nav_baker.gd:359-363` records for vegetation. **This is the single
  biggest regression risk of a split.** Any split must ship a test asserting the ignore count.
- **The mound must NOT be split.** `fb_terrain_mound` is one welded 13,984-tri surface and it is the
  ground for the whole compound (`site_planner.gd:1396-1402`, export contract
  `gen_firebase_v3.py:842-847`). Cut it into per-building floor tiles and every seam gets eroded by
  `agent_radius` on both sides → islands. Keep the ground as one asset no matter what happens to
  the buildings.
- **Marker lookups are `find_child(name, recursive)` by name**, from several owners:
  `Ladder.build_from_markers` and `SirenTower.build_from_markers` (`site_planner.gd:1271-1276`),
  `_wire_parapet_destructibles` (`:1603`), the helipad prefixes (`air_traffic.gd:64`), the work
  markers, `fb_gate_gap`. Each survives only if its marker stays a descendant of the searched root
  with its name intact. `air_traffic.gd:61-64` already documents one rename break from the v3
  re-export; a split multiplies that surface by the number of scenes.
- **The mound manifest coupling stays.** `fsb_mound_height` (`site_planner.gd:742`) is the terrain
  sculpt's authority and is a line-for-line port of the generator. Splitting buildings does not
  touch it, but re-authoring the ground would invalidate it and re-open the two-grounds bug the
  whole 2026-07-29 decree closed.
- **N roots means N chances to forget one.** A building whose scene never reaches the bake is
  solid and invisible to nav — the *identical* failure mode to R1, just distributed. Mitigation:
  one group (`&"fsb_nav_source"`), joined in `_ready`, and a bake that walks the group rather than
  a hand-passed root.

### Spawn side

Largely indifferent. `surface_y` / `floor_y` (`game_world.gd:404,436`) are raycasts against
collision layer 1 — they do not care how the scene tree is arranged. `SURFACE_PROBE_UP = 18.0`
(`:428`) is tied to the mound's authored height, not to GLB packaging. The one real spawn coupling
is marker naming, covered above.

**Net:** a split is a legitimate authoring decision and it would make R2 and R7 go away for free,
but it does **not** fix R1, R3, R4 or R5, and it introduces a real silent-regression risk on the
ignore-prefix contract. **Do not split to fix navigation.**

---

## 5 · THE THREE CHEAPEST HIGH-CONFIDENCE FIXES

### FIX 1 — Feed the reparented colliders back into the firebase bake *(fixes R1; ~8 lines)*

The Destructibles already join a group: `FSB_PARAPET_GROUP = &"fsb_parapet"`
(`site_planner.gd:1587`, joined at `:1632`). Seed the collider walk with that group as well as the
root.

In `nav_baker.gd:374-379`, change the stack seed:

```gdscript
func _add_colliders(source: NavigationMeshSourceGeometryData3D, root: Node3D, box: AABB) -> int:
	var added: int = 0
	var stack: Array[Node] = [root]
	# The parapet and the adopted structures were reparented onto Destructibles under
	# GameWorld before this bake ran; the root walk cannot reach them.
	for d in get_tree().get_nodes_in_group(&"fsb_parapet"):
		stack.append(d)
```

`_add_colliders` already skips `cs.disabled` (`:382`), so a blown segment drops out on the very next
`breach_at` re-bake and the hole becomes walkable — which is what `destructible.gd:176-179` claims
today and does not deliver. Add `_adopt_structure` (`site_planner.gd:1720`) to the same group so
bunkers and towers ride the same path once FIX 2 gives them shapes.

**Verify:** `nav_baker.gd:307-309` already prints the collider count. It must rise by 80.

### FIX 2 — Adopt the *sibling* collider, not a child that does not exist *(fixes R2; ~6 lines)*

`site_planner.gd:1706-1718` (`_adopt_structure`) walks `mi.get_children()`. The GLB is flat — the
collider is `mi.get_parent().find_child(mi.name + "_<ord>-colonly")`, i.e. a sibling
`StaticBody3D` whose name is the mesh name plus the export ordinal. Match on
`String(body.name).begins_with(String(mi.name))` among siblings, and keep the existing
`global_transform` preservation at `:1714,1717` (bunkers and towers **do** carry transforms —
measured: 277 of 365 `-colonly` nodes have one).

Do the same in `_wire_parapet_destructibles` (`:1617-1627`) **and add the transform preservation it
is missing** — it works today only because all 80 parapet nodes happen to be identity.

**Verify:** blow a bunker in the sapper bench and walk through the rubble. Today you cannot.

### FIX 3 — Give the baker back its step height and stop feeding it two grounds *(fixes R3, mitigates R4; 3 lines)*

**3a.** Add to `project.godot`:
```ini
[navigation]
3d/default_cell_height=0.2
```
`floor(0.4/0.2)*0.2 = 0.40` — exact, no loss. `nav_baker.gd:264-265` reads cell metrics from the
**server**, so the region stays consistent with the map automatically and the guard at `:275-278`
keeps holding. Nothing else changes.

**3b.** In `nav_baker.gd:272`, next to `border_size`:
```gdscript
nav.filter_walkable_low_height_spans = true
```
This deletes the buried terrain layer wherever the mound gives it less than `agent_height` of
clearance — most of the compound.

**3c (follow-on, not free).** For the firebase job only, lift `_add_terrain`'s samples to the mound
surface rather than the toe: `SitePlanner.fsb_mound_height(p.x - center.x, p.z - center.z)`
(`site_planner.gd:742`) is already a public static and is the exact function the terrain sculpt uses.
One surface, no layers, and `map_get_closest_point` stops having a choice to get wrong.

**Verify:** `nav_baker.gd:308-309` prints `verts`/`polys` per bake. Record before/after. A large drop
in polygons with unchanged or improved reachability is the buried layer disappearing.

### Honourable mention — one-line, ships with any of the above

`terrain_watchdog.gd:57`: `world.surface_y(...)` → `world.floor_y(...)` *(fixes R5)*. The correct
helper has existed since 2026-08-04 (`game_world.gd:436`) and every other caller was converted.
This one was missed, and it is the only code path that actively **teleports** a live ally onto a roof.

---

## 6 · WHAT WAS ALREADY FIXED AND STILL HOLDS (verified, not assumed)

Checked against the 8/11 playtest list:

- **LZ pile-up — HOLDS.** `seat_system.gd:417-436` (`unseat_all`) fans passengers across a 140°
  arc at increasing radius (`EXIT_PUSH_M + 0.9*i`, capped at 7 m). No two men share an exit point.
- **Squad teleport catch-up — HOLDS, and is correctly guarded.** `squad_system.gd:633-639`
  (`_catchup_ground`) nav-clamps **only inside a baked box**, with the reason stated at `:631-632`.
  This is the guarded nav-clamp law applied properly; `heli_lift.gd:334-344` (`_bunk_on_nav`) uses
  the same pattern and cites it.
- **Corpse snap-up — HOLDS.** `ally_base.gd:1997-2001` guarantees a flat corpse 1.5 s after death if
  no ragdoll started, and it was correctly lifted out of the fallback branch so explosive deaths are
  covered too.
- **Stuck NPCs — PARTIALLY.** The watchdog + `_rescue_snap` (`ally_base.gd:59-95`) is sound
  *machinery*, but it is defeated by R1 (he is on valid mesh, so the rescue early-returns at `:92`)
  and undone by R5 (the LOD resume puts him back on a roof). The symptom will persist until R1 and
  R5 land, regardless of how the watchdog is tuned.

Also worth recording: `ally_base.gd:2039-2040` sets `collision_layer = 2, collision_mask = 1`.
Allies collide with the **world only** — never with each other or the player. Physical pile-ups are
impossible by construction; if men look stacked, it is a *placement* bug, never a push-out failure.
This is worth knowing before anyone "fixes" crowding with avoidance — and note
`ally_base.gd:2036` explicitly disables RVO with a reason.

---

## 7 · DRIFT FOUND WHILE READING (corrected on contact, per the standing law)

Recording these rather than editing mid-analysis; each is a claim in the source that is no longer
true and that a future reader would act on:

1. `destructible.gd:176-179` — *"the navmesh is correct the moment it is rebuilt"*. **False for the
   parapet** (R1) and **false for every adopted structure** (R2).
2. `site_planner.gd:1704-1705` — *"A shape left nested under the mesh's auto-generated body survives
   the blast, and the 'destroyed' bunker keeps stopping rounds."* Describes the bug the code below
   it does **not** fix (R2).
3. `game_world.gd:400-403` — *"reaches y=14.5 (site_planner.gd)"*. The mound manifest says
   `mound_h 3.4`, max ≈ 6.5 m with berm and harmonics; `14.5` appears nowhere in `site_planner.gd`.
   `SURFACE_PROBE_UP = 18.0` (`:428`) was sized off this stale figure and is what makes the roof hit
   near-certain (R5).
4. `site_planner.gd:1293-1296` — *"When the re-exported GLB lands both counts come back 0 and this
   whole function is deleted (ADR-023)."* Measured: `fb_sbg_seg_` colliders are still **12-tri box
   hulls** in the shipped GLB. The re-export has not landed, the repair still fires — **and the
   repair is the mechanism that lets R1 happen.** Landing the re-export closes R1 as a side effect.
5. `ai_stress_arena.gd:1204-1206` — *"walkable interiors are future work"* is true of the stress
   lab's AABB-boxed ruins but reads as a statement about the project. The firebase's interiors are
   trimeshed and clutter-excluded; see §3.

---

*Technical Director, 2026-08-12. Measurements taken directly from `fsb_main_v3.glb` and
`fsb_main_v3_mound.json`; every code claim carries a `file:line`.*
