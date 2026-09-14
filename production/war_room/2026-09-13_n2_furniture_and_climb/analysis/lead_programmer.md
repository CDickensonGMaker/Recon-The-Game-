# Lead Programmer / Godot Specialist — N2 furniture and climb (2026-09-13, late)

Lens: the code and the engine. Everything below carries a `file:line` or the probe that measured it.
Instruments this session: `evidence/stuck_rows_run14.md`, `census_after15.log` (scratchpad), and one
read-only probe I ran against the live demo bake (`scratchpad/probe_furniture_mesh.gd`, run via
`-s`, no game file touched; log `scratchpad/fprobe.log`). No game file was edited.

## 0. The premise the briefing was built on is wrong, and the code's own comments are the fossil

- `project.godot:317-319` **HAS** a `[navigation]` section: `3d/default_cell_height=0.2`. The map's
  cell height is **0.2**, not the 0.25 default. Cell SIZE is 0.25.
- Every bake line in run 15 and in my probe reads `cell=0.250 h=0.200 climb=0.40`
  (`census_after15.log:575`, `fprobe.log:619`). The baked climb is **0.40 m = exactly 2 voxels of
  0.2**. There is no 0.5 m climb. `roundf(0.4/0.2)*0.2` at `nav_baker.gd:402-403` does what its
  comment says; the engine then floors `0.4f/0.2f = 2.0` exactly (float32 0.4 is 2× float32 0.2 bit
  for bit), so `walkableClimb = 2`.
- The two comments that misled the Arbiter are drift and must be corrected on contact (NO MORE DRIFT):
  `nav_baker.gd:389-394` ("project.godot has no [navigation] section ... the map runs at the 0.25
  default") and `nav_baker.gd:763-766` ("With no [navigation] section ... silently floors to 0.25").
  Both describe a project.godot that no longer exists.

So the climb theory needs restating: **the mesh walks over furniture at a 0.4 m climb, not 0.5**, and
the reason it clears 0.51 m cots is staircase geometry, below.

## 1. What the engine actually does (verified against the engine's behaviour, not assumed)

**`agent_max_climb` in Recast terms.** Godot's generator hands Recast
`walkableClimb = floor(agent_max_climb / cell_height)` voxels (2 here). Recast uses it in three
places: (a) `rcFilterLowHangingWalkableObstacles` promotes a non-walkable span (a cot's vertical
side, rejected by the 45° slope test) to walkable when it sits ≤ climb above a walkable span;
(b) the compact heightfield connects two neighbouring cells when their floor tops differ by ≤ climb;
(c) `rcFilterLedgeSpans` marks a span unwalkable only if a neighbour DROPS by more than climb.
Triangle tops are rasterised with `ceil` into 0.2 m voxels, so a 0.51 m cot top is 2 or 3 voxels
above the floor depending on where the floor falls in the voxel phase — and every cot carries a side
rail at +0.30-0.35 m (the census `contact` column: `evidence/stuck_rows_run14.md`, `census_after15.log
:1025-1299`), which is a 2-voxel step, after which the mattress is one more voxel. **A cot is a
two-step staircase to Recast.** That is why 0.51 m cots (all 88 are 0.51 m: `fprobe.log:898`),
0.86 m radio chairs with a 0.45 m seat (`:904`) and 0.88-1.08 m sandbag skirts (`:918`, 61 of 181
parts) all bake as floor. The erosion never fires at a step edge because a connected neighbour is not
a boundary, so the cot top is a plateau joined to the floor exactly like a crater rim would be.

Measured on the live bake (`fprobe.log:898-925`): mesh sits >0.2 m above the base of **60/88 cots,
68/88 lockers, 5/11 radio chairs, 33/44 chairs, 11/12 bunker-step blocks, 61/181 sandbag parts, 2/4
pit decks**; 0/11 tables (0.75 m, no intermediate step → correctly an obstacle). 25 polygons of 8,036
have their centroid over a cot or locker top.

**`CharacterBody3D` has no step-up.** `floor_max_angle` (default 45°, nothing in the three movers
overrides it: grep of `civilian.gd`, `ally_base.gd`, `enemy_base.gd`) classifies a contact by its
normal; every stuck row reports `normal.y 0.00` — a wall. `move_and_slide` projects velocity onto the
wall plane, the forward component dies, the mover re-lerps it next frame (`civilian.gd:1049-1051`,
`ally_base.gd:2174-2175`, `enemy_base.gd:2702-2703`) and it dies again: `v 0.00` every sample.
`floor_snap_length` (default 0.1) only pulls DOWN within 0.1 m; it never lifts. The capsule's real
"step" is its bottom hemisphere: a 0.3 m sphere (`civilian.gd:351-352`; allies/enemies 0.4,
`ally_base.gd:2557`, `enemy_base.gd:3758`) rolls over a sharp ledge only while the edge contact
normal stays inside 45°, i.e. ledge height ≤ r(1−cos45°) = **0.088 m** for the civilian, 0.117 m for
the soldiers. So: mesh climbs 0.40 m, body climbs 0.09 m. The band between is every row in the census.

**`NavigationAgent3D.path_height_offset`** is SUBTRACTED from every path point
(`get_next_path_position` returns `point − (0, offset, 0)`, and the "reached this point" test is a
3-D distance against the same lowered point). `civilian.gd:370-376` has the sign right; +0.45 brings
the points down to the feet. It is a bandage on the symptom (mesh 0.05-0.85 m up) and it exists in
the civilian only — the ally and enemy agents run at 0.0 (`ally_base.gd:2564-2573`,
`enemy_base.gd:3765-3774`): three agents on one mesh with two different vertical contracts. If the
mesh comes back down to the floor, the 0.45 becomes a fossil in the same change (Fossil Law).

**`add_projected_obstruction(vertices, elevation, height, carve)`** marks the footprint's cells
`RC_NULL_AREA`. With `carve = false` it is marked BEFORE `rcErodeWalkableArea`, so the agent radius
erodes around it for free; with `carve = true` it is marked AFTER erosion — exact footprint, no
margin. `nav_baker.gd:1039` passes `true` and inflates by hand (`AGENT_RADIUS + 0.15`, `:1029`),
which is why the comment at `:1023-1028` says Godot "does NOT erode around a carved projected
obstruction". Consistent with the engine; noted because fix 2's sealing risk is that 0.65 m.

**Bake cost.** `agent_max_climb` is a filter; it changes NO heightfield dimension. Lowering
`cell_height` would (memory and rasterise time scale with voxels per column) — and is unnecessary,
0.2 is already the map's value. Today's firebase bake: 2,436 colliders, 7,921 polys, 2,259-2,356 ms
on the Recast thread (`fprobe.log:619`, `census_after15.log:575`) plus ~1.5 s of sliced collect
(`nav_baker.gd:296-306`). The breach re-bake pays the same and is unchanged by any of fixes 1-4 except
fix 2 (adds ~250 obstruction marks, negligible).

## 2. The 26 rows are TWO defects, not one

Sorting run 15's `off-mesh` column (`census_after15.log`, extracted in `fprobe` session):

**Class A — on the mesh, mesh over his head (off-mesh 0.05-0.47 m, dy +0.34 to +0.72).** Cots,
lockers, the pit deck. ~13 rows. His route is a straight 2-point line to a target that the resolver
clamped ONTO a furniture top (`civilian.gd:1443-1450` → `nav_router.gd:62-75`
`map_get_closest_point`). The mesh's fault (§1).

**Class B — OFF the mesh by 0.9-1.2 m (off-mesh 0.91, 1.07, 1.10, 1.12, 1.19, 1.20).** ~10 rows:
`@3931` radio chair, `@3985` cot/locker, `@4021` cot, `@4327` cot, `@4345` tent-frame pole. He is
standing inside the 0.5 m erosion ring or a carved pocket — where `place_for_current_hour`
(`civilian.gd:1389-1400`) teleported him on his FIRST physics tick, before the bake existed
(`nav_router.gd:120-124`: "the navmesh is baked AFTER they spawn"; `nearest_mesh_point` returns the
raw point when `box_index_at < 0` or `map_get_iteration_id <= 0`, `nav_router.gd:64-68`). From there
`NavRouter.step` has no start polygon, the path fails, and the one escape hatch — walk back toward the
mesh — is gated by `OFF_MESH_M = 1.2` (`nav_router.gd:36`, `:130-134`): at 1.10-1.20 m he is judged
"on the mesh" and handed DIRECT steering into the cot. `_rescue_snap` uses the same 1.2 m gate
(`civilian.gd:269-278`) and refuses him too. **Both hatches refuse exactly the men who need them.**
This class is fixed without touching the bake. It is the thing the Arbiter's read missed.

**Class C** (`@4309` latrine, 3 rows): on floor, on mesh, `agent pathing 34 pts`, next point
`dy +3.15` — a path over a roof or a tower. Not furniture; F08 family; not this council.

## 3. The four fixes, from the code

### Fix 1 — tell the bake the truth about climb (BACKED, with two riders)
Change: `nav_baker.gd:48` `AGENT_MAX_CLIMB 0.4 → 0.2` (one voxel; `:402-403` needs no edit, it
snaps to `cell_height`). Correct the two fossil comments (`:389-394`, `:763-766`) in the same edit.
Effect: cot rail 0.30-0.35 → 2 voxels > 1 → the cot is an obstacle; lockers 0.38 → obstacle; chair
seats 0.45 → obstacle; sandbag bag-steps → walls; the 0.35 m pit lip → wall; 0.45 m bunker risers →
sealed. Bake time: unchanged (filter only). Determinism: unchanged (same input, same Recast).
**Rider A — islands.** Tops that no longer connect become walkable ISLANDS unless dropped:
a cot top is ~3×7 = 21 cells and `region_min_size` defaults to 2 → 4 cells (it is a SIDE and Godot
squares it — his own recorded trap). A bunk marker ON a cot would then clamp to the island and the
man gets `NO ROUTE` — the same stuck row with a new label. Set `nav.region_min_size = 5` (25 cells,
1.25 m square) in `_start_bake` beside `:406`. Verify with the polygon diff that tower platforms
(≈90 cells) survive; nothing walkable in the compound is legitimately under 1.25 m square.
**Rider B — fossil.** `civilian.gd:376 path_height_offset = 0.45` → delete or 0.1 in the same
commit; with the mesh at the floor it pushes path points 0.45 m under his feet (still passes the
0.7 m 3-D test, but it is a lie with a comment).
What it sacrifices: (i) the 12 `fb_bunker_steps` blocks (0.92-2.66 m tall on 1.4-3.65 m runs,
`fprobe.log:913-917` ≈ 0.45 m risers) seal for the MESH. They are already sealed for the BODY — a
0.45 m riser is five times the capsule's 0.09 m — so today's 37 `work_bunker` posts are reached only
by the `place_for_current_hour` teleport, never on foot. "Bunker steps stay floor" protects a
fiction; the honest fix is a ramp wedge collider on each stair (model, `gen_firebase_v3.py`, or a
runtime `ConvexPolygonShape3D` wedge the way `site_planner._remesh_collider` rebuilds vegetation)
that mesh and body agree on at ≤45°. (ii) Crater rims: the bake never sees craters
(`nav_baker.gd:16`, `:61-63` — craters do not re-bake; only structures do), so `AGENT_MAX_CLIMB 0.4
exists so a crater rim is not a cliff` (`:399-401`) protects nothing measurable. (iii) Sandbag skirts
stop being staircases for the mesh (61 parts today) — routes that went OVER a parapet now go through
the breach or around; that is the direction the 9/11 siege work wants. (iv) The unknown: any 0.2-0.4 m
ledge in the ground-of-record (mound skirt to the 4 m terrain sheet, the gate gap) becomes a cut the
census cannot see because it only reads civilians inside the wire — this is the riskiest edit, §6.

### Fix 2 — carve furniture as obstructions (REJECTED)
Requires site_planner to tag ~250 GLB `StaticBody3D`s (88 cots, 88 lockers, 44 chairs, 11 tables,
11 radio sets — colliders survive the fold, `interior_prop_fold.gd:44-47`, probe confirms) into
`nav_blockers` with a `nav_box` meta from each collider's AABB, then `_add_structures`
(`nav_baker.gd:1005-1040`) carves each at footprint + 0.65 m per side. A 0.75×1.9 m cot becomes a
2.05×3.2 m hole; two cots and two lockers erase a hooch's floor; `nearest_mesh_point` sends every
bunk to the doorway; the census overlap count goes red. Strictly dominated by fix 1, which makes the
SAME trimesh an obstacle with Recast's own 0.5 m erosion and no tagging. Only if fix 1 were refused
would this be worth a `carve = false` variant (engine erodes for free, drop `:1029-1031`).

### Fix 3 — a step-up in the movers (NOT NOW)
Mechanics: on a wall contact with `_want_speed > 0`, `test_move(up h)` → `test_move(forward)` →
commit → snap down. Cost only on wall-hit frames: ~3 capsule casts, Jolt broadphase-cheap; 85 bodies
worst case ≈ 0.1-0.2 ms/frame. Deterministic. But it must be ONE helper (a static on `NavRouter`),
not three copies — `civilian.gd:1039`, `ally_base.gd:2169`, `enemy_base.gd:2693` — or the Fossil Law
gets a fourth mover. What it breaks: it changes ENEMY and ALLY behaviour on the shared mesh. With
the mesh climbing 61/181 sandbag parts at 0.4, a 0.4-0.5 m step-up lets the 45-man assault follow the
mesh OVER the parapet instead of through the satchel breach (`destructible.gd:250` → `breach_at`) —
a pillar-1 regression and it hollows out the breach re-bake. A 0.2 m step-up would be consistent
with fix 1's mesh (one climb number, both sides) and clears nothing measured here (lockers 0.38, lip
0.35, cots 0.51); keep it in the pocket ONLY if the connectivity probe finds a 0.1-0.2 m ledge at the
mound seam that fix 1's mesh crosses and the body cannot.

### Fix 4 — keep placement out of the furniture (BACKED as the cheap second)
`_resolve_target` (`civilian.gd:1443-1450`) and `_seated` (`:1406-1409`) already own everything
needed: accept a candidate only if `nearest_mesh_point(c).y − director.world.floor_y(c) < 0.25`
(the mesh point is on the FLOOR, not on a cot), else advance the golden angle from the name hash
(deterministic, ADR-010). One `floor_y` probe per candidate, at schedule changes only. Sacrifice:
none measurable; it moves destinations, never routes — so without fix 1 a man still walks a straight
2-point line over a cot to reach a good spot.

### The one the briefing did not list — the router's 1.2 m gate (BACKED, first)
`nav_router.gd:36 OFF_MESH_M 1.2 → 0.5` (the agent radius; the value is compared XZ-flat at `:131-
134`, so slopes cannot trip it — the comment's "reads a little off on a slope" is about Y, which is
zeroed). Same constant feeds `civilian.gd:275`, `ally_base.gd:93`, `enemy_base.gd:404`, `:2146`.
Effect: a man 0.5-1.2 m off the mesh walks BACK onto it before routing, and `_rescue_snap` can snap
him. Cost: zero (the closest-point query is already on the failure path and cached per metre).
Changes allies/enemies too: an enemy at a cover point 0.6 m off the mesh with a failed path now steps
0.6 m back onto it before steering direct — benign, arguably better. This removes Class B alone.

## 4. Answers to the briefing's questions

- **Order:** (1) router gate 1.2 → 0.5 [Class B, no bake change] → (2) `AGENT_MAX_CLIMB` 0.2 +
  `region_min_size` 5 + delete `path_height_offset` 0.45 + fix the two fossil comments [Class A] →
  (3) fix 4's floor test in `_resolve_target` → (4) pit ramp and bunker-stair wedges as content.
  The ONE change with the most of the 26 for the least risk is the climb (Class A ≈ 13 rows and it
  also stops class B men being sent to cot tops); the one with ZERO risk is the router gate.
- **Is the climb theory right?** Half. Cots are NOT under the climb (0.51 > 0.40); they are two
  0.3 m steps. The bake did not lose any furniture: all 88 cots / 88 lockers / 11 radio sets have
  live colliders in the tree, `fb_int_` is not in `NAV_IGNORE_PREFIXES` (`nav_baker.gd:826`), the
  fold removes only `MeshInstance3D`s (`interior_prop_fold.gd:44-47`, `:117-124`), and the probe
  finds mesh ON them. The 0.90 m radio chair is the same: 0.45 seat then 0.41 back.
- **The mortar pit:** `MC_pit_floor` is an 18.8 m × 0.74 m BOX (`fprobe.log:906-910`) whose top
  stands 0.35 m above the mound where the rest/off-duty men stand (census `contact +0.33 top +0.35`,
  `normal.y 0.00`). Mesh 1.05-1.50 m over its base = the deck. Crews are teleported onto it; anyone
  walking to it meets a 0.35 m kerb. Neither a lower climb (deck becomes an island; `work_gun` posts
  unreachable on foot) nor a post move (the crew's posts ARE on the deck) fixes it: it needs a ramp
  the mesh and the body agree on — a ≤45° wedge at the pit entrance, model-side, or a runtime wedge
  collider like `_remesh_collider`. Until then, keep the rest/off-duty markers ON the deck.
- **Enemies and allies:** fix 1 changes their mesh (furniture and sandbag skirts become obstacles —
  routes go around/through breaches; sappers at the wire unchanged, the wire is already carved;
  follow slots are outdoors and unaffected; breach re-bake cost unchanged). The router gate changes
  their off-mesh recovery (benign). Fix 3 is the only one that changes what their BODIES can do, and
  it is the regression (parapet vaulting). Fix 4 is civilian-only.
- **Cheapest probe:** the bake line's `polys=` (free; 7,921 today) for the sanity diff; my
  `probe_furniture_mesh.gd` (60 s; must read cots on_top 0/88, lockers 0/88 — today 60 and 68) as
  the direct instrument; `probe_interior_nav` (60 s; hooches must not read SEALED) for the island
  and erosion risk; then the census (5 min) as the gate. Add to the furniture probe one
  `map_get_path` from a point outside the wire to the TOC, each pit and each bunker door — the seam
  check nothing else runs.

## 5. Secondary, recorded, not this council
- The chow hall's frame centre returns a mesh point 3.59 m over the frame's base at dxz 0.00
  (`fprobe.log:911`) — walkable mesh at roof/ridge height inside a culled family. F08 / roof-cull
  family; `probe_chowhall_nav` is the instrument.
- Three agents, two `path_height_offset` contracts on one mesh (§1).
- `Ladder` is player-only (`ladder.gd:146` `collision_mask = 2`); "towers stay climbable" is not an
  NPC property and no fix here touches it. Tower platforms are islands the men are teleported onto.

## 6. The single riskiest edit
`AGENT_MAX_CLIMB 0.4 → 0.2`. Not for the furniture — for the ground-of-record: any 0.2-0.4 m ledge
where the mound trimesh meets the 4 m terrain sheet, at the gate gap, or at a berm cut becomes a
disconnect that severs the compound from the AO, and the census cannot see it (it reads civilians
inside the wire; a sapper with no route simply steers direct and the siege looks "fine" on a bench).
Ship it only behind the outside-to-inside `map_get_path` check, with `region_min_size 5` in the same
commit, and read the roof report for anything new.
