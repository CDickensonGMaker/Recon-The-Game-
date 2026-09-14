# Systems Designer — N2 furniture and climb (2026-09-13, late)

Lens: the SYSTEM of places, bodies and the mesh. Code read, not the plan. Where the briefing and the
code disagree, the code is cited and the briefing's line is named as drift.

## 0. What the code actually says (three corrections to the briefing)

1. **The map cell height is 0.2, not 0.25.** `project.godot:317-319` has a `[navigation]` section:
   `3d/default_cell_height=0.2`. Run 15's bake line confirms it: `cell=0.250 h=0.200 climb=0.40`
   (`census_after15.log:575`). So `nav_baker.gd:402-403` quantises `AGENT_MAX_CLIMB` 0.4 to
   `round(2.0)*0.2 = 0.40`, **two voxels**, not 0.5. The comment at `nav_baker.gd:390-391`
   ("project.godot has no [navigation] section") and at `:764` ("floor(0.4/h)") are both drift; the
   briefing repeated the first. Whoever touches nav_baker.gd fixes both in the same change (no-drift law).
2. **A 0.4 climb passes tops up to ~0.6 m.** Recast floors every span top to its voxel and connects two
   neighbouring cells when their top-voxel difference is <= walkableClimb (2). A cot whose top is 0.43-0.55 m
   over a floor lands 2 voxels up in most columns, so the mesh rides over it. That is the measured band:
   cots **0.43 / 0.45 / 0.47 / 0.50 / 0.52 / 0.55**, lockers **0.28-0.39**, pit floor **0.22-0.39**
   (`census_after15.log`, tally of `top +` on 26 rows). The climb theory holds for every cot but one.
3. **The same two voxels are what keep a 45-degree slope connected.** At `cell_size` 0.25 a 45-degree face
   rises 0.25 m per cell = 1.25 voxels, floor-quantised to 1 or 2. `agent_max_slope = 45` (`:407`) is only
   true while climb >= 2 voxels. Lower climb to one voxel (0.2) and the effective walkable slope collapses to
   ~39 degrees with quantisation noise: berm faces fragment into islands, crater rims turn into the cliffs
   `:399-401` exists to prevent, and `fb_bunker_steps` (kept walkable on purpose, `:848-850`) go with them.
   **Fix 1 is not a knob; it is the slope contract.**

The exception in (2): `fb_int_cot_m1_101` top **+0.72** (row 4327, 10.5h). That cot is above the band, so the
bake did NOT route over it - it eroded 0.5 m around it - and the man is **0.91 m off the mesh**, walked into
the eroded ring by direct steering. Same mechanism as the radiochair rows (top +0.90, off-mesh 1.10-1.11).
The bake did not lose any furniture: `_walk_step` (`nav_baker.gd:520-535`) keeps every enabled shape not in
`NAV_IGNORE_PREFIXES` (`:827`), `fb_int_` is not there, and the prop fold (`interior_prop_fold.gd:150-170`)
removes MeshInstance3Ds only - the StaticBody3D colliders it names at `:48-51` stay siblings in the GLB.

## 1. The two mechanisms behind the 26 rows (run 14 = run 15, same 26)

Classification of the 26 STUCK rows in `evidence/stuck_rows_run14.md` by blocker and position:

| class | rows | where he is | evidence |
|---|---|---|---|
| A. cot/locker/chair in HIS OWN QUARTERS, post 10-110 m away | **15** | home 1.3-3.9 m | 4237 x2, 4255 x3, 4327 x3, 3985 x2, 4021 x2, 4273, 3803, 3841 |
| B. radiochair at the radio post | 2 | post 2.4 m, home 36 m | 3931 x2 |
| C. `MC_pit_floor` lip, off-duty at the pit | 5 | post 3-45 m (rest/talk) | 9406 x2, 12734, 16420, 16477 |
| D. latrine, next path point **+3.15 m up** (a layer, not furniture) | 3 | - | 4309 x3 |
| E. chow-hall tent frame pole | 1 | - | 4345 |

Class A+B is 17/26. It has TWO mechanisms, and the second is the one the briefing did not name:

**Mechanism 1 - the step fiction.** Mesh over the cot top (band above), body cannot climb it: a 0.3 m capsule
(`civilian.gd:350-352`) hitting a vertical face above ~0.09 m gets `normal.y 0.00` (every furniture row) and
`floor_max_angle` 45 calls it a wall. `move_and_slide` (`:579`) zeroes him; `_update_unstick` (`:239-263`)
sidesteps 0.6 s at 1.6 m/s, alternately; `_rescue_snap` (`:269-279`) refuses unless he is > `OFF_MESH_M`
(1.2 m, `nav_router.gd:41`) off the mesh AND unseen.

**Mechanism 2 - the cot top CAPTURES the nearest-point query.** Every "NO ROUTE" and "route 2 pts" row
(11 of the 15 class-A rows) has `dy +0.25..+0.72` under "off-mesh": the nearest mesh point to the man is
ABOVE his feet - it is the polygon on the cot top beside him. `map_get_closest_point` is what
`NavRouter.nearest_mesh_point` (`nav_router.gd:69`), the self-clamp (`:139`) and the agent's own start
polygon all use. A cot-top polygon that Recast connected in some columns and not others is a fragment; when
the man's start polygon is that fragment, `map_get_path` returns 2 points (start = closest reachable point
to a 60 m target), the agent reads FINISHED, `step()` falls through to `return direct` (`:171`), and direct
steering marches him into the very cot. `path_height_offset` 0.45 (`civilian.gd:376`) lowered the agent's
path points; it could not change which polygon the server picks as his start. **Removing the polygons on
furniture tops fixes mechanism 1 and 2 with one edit; a body step-up fixes only mechanism 1.**

Also measured and NOT explained by furniture: **8 of 26 rows stand 0.89-1.20 m off the mesh** (tally:
0.89 x2, 0.91, 1.07, 1.10 x2, 1.12 x2, 1.19, 1.20). That is the band in which `step()` treats a man as ON the
mesh (`off.length() > OFF_MESH_M` at `nav_router.gd:145` never fires) and `_rescue_snap` refuses
(`civilian.gd:275`). `OFF_MESH_M` is an XZ distance (`:143` zeroes y); the comment at `:39-40` justifies
1.2 with the mesh sitting a cell-height UNDER the ground, which is a Y excuse for an XZ number. A man on the
mesh hugging an eroded wall reads ~0.1 m off in XZ. 1.2 m is two agent radii of "not on the mesh, not
rescued either". Secondary to this council's question, but it is in the same 26 and costs one constant.

## 2. The four fixes, judged from the code

### Fix 2 - carve furniture. BACKED, FIRST. The one change that removes the most for the least risk.

What it removes: class A+B (17/26) by both mechanisms, plus the placement capture in `_resolve_target`
(`civilian.gd:1443-1450`: `nearest_mesh_point(home + 1-3 m spread)` currently lands men ON cot tops;
`_seated` (`:1406-1409`) then raycasts down with mask 1 (`game_world.gd:448-456`), hits the cot top and
stands him on the mattress at spawn).

How, and one gotcha the Arbiter's shape has: **do not route this through `nav_blockers` + `nav_box` meta.**
`_add_structures` (`nav_baker.gd:1005-1035`) carves at `body.global_position` with `global_rotation.y` and a
meta size. The furniture colliders are `-colonly` StaticBody3D siblings in a flat GLB
(`interior_prop_fold.gd:48-51`); their node origin is wherever the artist left it, and the whole compound is
yawed to the gate axis (`mission_generator.gd:1001`), so an axis-aligned box from a meta would over-carve
every rotated cot's corners by |sin yaw|. Build the footprint from the SHAPE, which the baker already has in
world space: in `_begin_shape` (`:594-612`) `wv` is the world-space triangle list; project to XZ,
`Geometry2D.convex_hull`, `Geometry2D.offset_polygon` by the inflation, store it on the face-cache entry
(`_face_cache`, `:353-358`) next to `fwd`/`flip`, and in phase 4 (`:465-472`) call
`source.add_projected_obstruction(hull, base_y - 0.5, (top_y - base_y) + 1.0, true)`. Elevation must sit
BELOW the floor span or a cot on modelled legs carves nothing (the obstruction only marks spans inside
[elevation, elevation+height]). A `NAV_CARVE_PREFIXES` list in nav_baker.gd, sibling of `NAV_IGNORE_PREFIXES`
(`:827`) and `NAV_ROOF_CULL_PREFIXES` (`:843`), names the families: `fb_int_cot`, `fb_int_locker`,
`fb_int_radiotable`, `fb_int_radiochair`, and any other solid `fb_int_` family whose top is over ~0.25 m
(a first bake can print the per-family max height the same way `_report_roof_misses` prints misses -
ADR-042 clause 1, a prefix list must name what it missed). Skip `add_faces` for carve families: 545 prop
shapes of the 2,436 walked (`census_after15.log:575`) leave the collect and the Recast solve gets lighter,
not heavier. Rebake cost (`_tick_rebakes`, `:271-318`): ~200 `rcMarkConvexPolyArea` calls, each a bbox scan
of a 2x3 m footprint - noise against the 2,356 ms firebase bake.

Inflation: `_add_structures` uses `AGENT_RADIUS + 0.15 = 0.65` (`:1024`). For furniture use `AGENT_RADIUS`
(0.5): a carved edge is not eroded (`:1019-1023`), a 0.4 body hugging it keeps 0.1 m; the 0.15 hair was
bought for hut walls where a jam is a stuck squad, and here each 0.15 costs 0.3 m of hooch corridor. A hooch
with cots along both long walls keeps a corridor of (interior width - 2 x (cot + 0.5)); at a 3.6 m interior
that is 1.2 m = 4-5 cells. A hooch narrower than ~2.6 m inside, or two cots nose-to-nose under 1.0 m apart,
seals. That is the named risk and the instrument for it is below.

What it sacrifices (law 2): (a) the quarters spread converges - three men whose 1-3 m spread lands in
carved footprints all snap to the same hole edge, so the census OVERLAP count (12-15 today) can rise until
fix 4 lands; (b) the mesh no longer models "a man could sit on a cot" for any future sit-on-bunk behaviour -
those become seat sockets, not nav; (c) a sealed hooch is possible and must be proven absent, not assumed.

Effect on enemies/allies: the shared mesh changes for everyone. Sappers inside the wire path AROUND cots
and lockers instead of over them - correct, and it removes a stall class from the assault, not adds one.
The squad's boot on the bunk inside `fsb_main` and the "2/4 dirs blocked" spawns in the bunk area are the
same capture bug seen from the ally side; `nearest_mesh_point` from a carved footprint now returns the
edge, which is where a man beside a bunk stands. No mover changes.

### Fix 3 - step-up in the body, capped at `AGENT_MAX_CLIMB`. BACKED, SECOND, civilians only.

What it removes: class C (5 rows, `MC_pit_floor` tops 0.22-0.39) and any locker the carve list misses
(0.28-0.39). The rule that makes it honest: **one number.** The bake's climb is `NavBaker.AGENT_MAX_CLIMB`
(0.4); give the body that same step and CARVE everything taller. Then the only fiction left is Recast's
quantisation band (0.4-0.6), and the things in that band - cots - are carved by name. Sandbag skirts at
0.4-0.6 stay in the band; the census will name them if they matter.

Where: `_step_toward` (`civilian.gd:1039-1055`) sets velocity; the slide happens at `:578-579` behind
`_slide_due`. The step goes AFTER `move_and_slide`, only when `_want_speed > UNSTICK_WANTS_MOVE` and
`is_on_wall()`: `test_move(up 0.4)` free -> `test_move(forward 0.15)` free -> `test_move(down 0.4)` hits
-> `global_position += the three offsets`. Three shape casts on wall frames only; a man at his post pays
nothing (the "a man who is not moving does not slide" rule at `:484-500` is untouched). Do not gate it on
the agent's next-point height: `path_height_offset` 0.45 (`:376`) is subtracted from every path point, so
the point's Y is not the mesh's Y any more.

Not for enemies and allies in THIS council. Their movers are separate (`ally_base.gd:2170`,
`enemy_base.gd:2694`, capsules 0.4 at `ally_base.gd:2556-2559`, `enemy_base.gd:3757`), the far assault
bypasses the mesh entirely (`enemy_base.gd:2284-2290`, "gravity and move_and_slide already carry him"),
and the wire cards (`bwire_card`, soft at `site_planner.gd:2295`, IN the bake) have no measured height in
this evidence. A step-up that clears the wire is a sapper who no longer needs a satchel. Measure the wire
first; extend the helper (a static on NavRouter, pure function of the body) only after. The siege-stall
fixes of 09-11 are eleven days old; the assault mover is not where a garrison bug gets fixed.

What it sacrifices: a man visibly "stepping" 0.4 m onto a locker top if a locker is not carved - which is
why lockers ARE on the carve list and the step exists for earthworks (pit lip, crater rim, bunker step).

### Fix 4 - placement accepts only a free candidate. BACKED, THIRD, cheap.

`_resolve_target` (`civilian.gd:1443-1450`) is already deterministic (name hash, ADR-010). Step the angle by
the golden angle until `test_move` from `_seated(candidate)` toward the post is free for 1 m; cap the
attempts (8) and fall through to today's value. It runs on the first physics tick (`:509-513`) when the
collider is live, and again on each hour's `place_for_current_hour` (`:1389-1400`): ~60 men x 8 casts, once
an hour of sim time. What it removes: the post-carve convergence (sacrifice (a) above) and men spawned
boxed in. What it cannot do: a post that is BEHIND a cot (the radioman's, class B) - that is fix 2's job.

### Fix 1 - change the climb or the cell height. REJECTED for this council.

Section 0.3 is the reason: at `cell_size` 0.25 the two-voxel climb IS the 45-degree slope guarantee. The
only way to a ~0.1 m climb that keeps 45-degree slopes is `cell_size` 0.1, which takes the 370 m firebase
heightfield from 1480^2 to 3700^2 columns (x6.25): a 2.4 s bake becomes ~15 s, and every breach rebake
mid-siege (`REBAKE_DEBOUNCE_S`/`REBAKE_MAX_WAIT_S`, `:59-60`) pays it. `cell_height` 0.1 alone (climb 0.3,
three voxels) is cheaper (rows, not columns) and blocks cots at 0.43+, but still passes lockers and the pit
lip at 0.28-0.39 and leaves the body's 0.09 m step 0.2-0.4 m short of what the mesh promises. It does not
touch mechanism 2 for anything under 0.3 m. A global bake parameter for a local furniture problem, when a
local carve exists, is the wrong altitude. Keep 0.4; let the body match it (fix 3); carve above it (fix 2).

## 3. The mortar pit

`MC_pit_floor_2256/2358` is a raised slab: top 0.22-0.39 m over the surrounding mound, contact normals
0.00 (vertical edge), one row at 0.27 (a bevel). The crew markers (`work_mortar_<pit>_<role>`,
`site_planner.gd:1375-1400`) sit ON the slab and the crews are seeded there whole (`:1712-1725`), so the
slab must stay walkable - carving it (option: "post not behind the lip") would clamp the gunner to the lip
and unman the tube. A ramp in the GLB is the art answer and both mesh and body would agree on it, at the
cost of an export. Fix 3 at 0.4 is the systems answer today and costs no art: every measured lip is under
0.4. If the eye later objects to a 0.39 m step, add the ramp; the step-up keeps working.

## 4. Enemies and allies - which of 1-4 touches them

- Fix 1: everyone, everywhere - berms, rims, steps, rebake budget. Regression by construction.
- Fix 2: everyone, inside buildings only. Correct for sappers (path around, not over); correct for follow
  slots (`nearest_mesh_point` stops returning cot tops). Rebake: +~200 cheap marks. No mover change.
- Fix 3: civilians only as proposed. Extending to enemies is gated on the wire-card height.
- Fix 4: civilians only.

## 5. The cheapest probe that proves it

1. **The census on the shipped seed** (`--npc-census --test-save`, `probe_npc_census.gd`): stuck count
   26 -> expected <= 5 after fix 2 (classes C, D, E remain), <= 1 after fix 3 (D), and grep the rows for
   `dy +0.3` and over under "off-mesh" - the count of men whose nearest mesh point is above their feet must
   go to ~0. That is mechanism 2's own instrument and needs no new code.
2. **The bake line** (`[NavBaker] bake done ... polys=7921`, `census_after15.log:575`): fewer polygons is
   expected (cot-top fragments gone); a drop over ~15% flags sealed interiors.
3. **`probe_interior_nav.gd`** for the sealed-hooch risk. Note its limit: one sample per structure at the
   origin +0.4 m with a 1.6 m tolerance (`:16-19`, `:64-66`). A hooch carved down its centre could still
   read "reachable" from an edge polygon. If the census shows a hooch's men all "NO ROUTE" after the carve,
   that hooch is sealed regardless of what this probe says.
4. Not needed: a polygon diff tool or a new probe. The census already prints every number above.

## 6. The single riskiest edit

**Anything under fix 1** - `AGENT_MAX_CLIMB`, `3d/default_cell_height`, `cell_size`. One constant re-shapes
every slope in the compound and the siege's rebake clock, and the bake refuses to merge a region whose cell
size differs from the map's, silently (`nav_baker.gd:388-392`, `:411-414`). Second: the carve inflation -
0.65 seals corridors a 0.5 leaves open; prove hooches with the census before taking the hair.

## 7. Drift to correct in the same change (no-drift law)

- `nav_baker.gd:390-391` "project.godot has no [navigation] section" - false, `project.godot:319`.
- `nav_baker.gd:764` "climb ... floor(0.4/h)" - the code rounds (`:402-403`).
- `nav_router.gd:39-40` justifies an XZ threshold with a Y argument.
- The briefing's "0.25 default / 0.5 m" arithmetic, when it is archived.

## Verdict (for the Arbiter)

Order: **2 -> 3 -> 4; not 1.** Carve furniture from the shape's world hull, inflate by 0.5, drop its faces;
then a 0.4 step-up for civilians matching `AGENT_MAX_CLIMB`; then the golden-angle free-candidate check.
Riskiest edit: any climb/cell change. Missed: cell height is 0.2 (`project.godot:319`), climb is 0.40 = two
voxels, and those two voxels are the 45-degree slope contract; and the cot tops are not just walkable
fiction - they capture `map_get_closest_point`, which is why 11 of the 15 quarters rows read NO ROUTE.
