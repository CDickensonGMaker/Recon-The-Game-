# DEVIL'S ADVOCATE — N2 furniture and climb (2026-09-13, late)

Read: briefing, `evidence/stuck_rows_run14.md`, `census_after15.log` (26 stuck, 4 samples, complete),
`census_before/after..after14.log`, the prior council's `results.md`/`synthesis.md`, `nav_baker.gd`,
`nav_router.gd`, `civilian.gd`, `ally_base.gd`, `enemy_base.gd`, `interior_prop_fold.gd`,
`site_planner.gd`, the three probes, `project.godot`, ADR-041/043. One headless measurement of my own
(scratchpad `da_furniture_probe.gd`, output `da_probe.log`, 7.5 s after the bake, `--test-save`).

## 1. The Arbiter's arithmetic is wrong, and the code comment it trusted is a fossil

- **`project.godot:317-319` HAS a `[navigation]` section: `3d/default_cell_height=0.2`.** Every bake in
  every census log prints it: `[NavBaker] bake done: ... cell=0.250 h=0.200 climb=0.40` (all 16 logs,
  identical). The briefing's "cell height is the engine default 0.25 ... round(1.6)*0.25 = 0.5 m" is
  false. **The climb is 0.40 m, not 0.50.** The comment at `nav_baker.gd:389-393` ("project.godot has
  no [navigation] section, so the map runs at the 0.25 default") and the one at `:1093-1095` are stale
  — the POINTER LAW case: a drift generator that mis-aimed this council's opening claim. Correct them
  in whatever change lands (no-drift law).
- Consequence: the briefing's "check whether any top is over 0.5 m, then the bake lost THAT one" is
  the wrong threshold. Run 15's tops: pit lip +0.22..+0.39, lockers +0.28..+0.39, tent beam contact
  +0.30 — **under 0.40, climb theory holds exactly**. Cots +0.43..+0.72 and the radio chair +0.90
  are **over 0.40** and need a different explanation (section 2).

## 2. What I measured: three different furniture behaviours, not one

`da_furniture_probe.gd` walked all 203 colliders the census named (88 cots, 88 lockers, 11 radio
chairs, 11 radio tables, 4 `MC_pit_floor`, 1 `tent_frame_chowhall`) and asked the map for the
closest polygon to each prop's top-centre:

| prop | polygon inside its own footprint? | where |
|---|---|---|
| `fb_int_cot_*` (88) | **yes, ~80 of 88**, `dxz` 0.24-0.55 m, **`dy_vs_top +0.21`** (one 0.2 cell up) | the mesh RIDES the cot top |
| `fb_int_locker_*` (88) | mostly yes, `dxz` 0.04-0.39, `dy_vs_top +0.34/+0.35` | a polygon over the locker at the neighbouring cot's height |
| `fb_int_radiochair_*` (11) | **no** — nearest polygon `dxz` 0.83-1.05 m away, 0.26-0.31 BELOW its top | a HOLE: the chair (0.86 tall) punched the mesh and agent-radius erosion ate ~1 m around it |
| `fb_int_radiotable_*` (11) | **no** — `dxz` 1.04 m | same hole |
| `MC_pit_floor_*` (4) | yes — the mesh is continuous across the 0.34 lip | rides the lip |
| `tent_frame_chowhall` | 13.6 × 13.7 m AABB, ground beam at +0.30 | rides the beam |

So the Arbiter's "the mesh walks over furniture" is **proven for cots, lockers, the pit lip and the
tent beam** (rail at +0.30-0.35 then canvas at +0.43-0.55 is a two-step staircase under a 0.40
climb once each span is rounded UP to a 0.2 cell), and **wrong for the radio set** — those two
props are holes, and the two radio rows (off-mesh 1.10 m, `contact +0.50/+0.54 top +0.90`) are men
placed in the eroded gap beside a hole, not men blocked by a step. Two mechanisms, two fixes.

**The bake did not lose anything.** `interior_prop_fold.gd:118-135` removes MeshInstances only; the
colliders are sibling `StaticBody3D`s (its own header says so, and the census's `test_move` hits them
by name). `_walk_step` (`nav_baker.gd:539-555`) keeps every enabled in-box shape not in
`NAV_IGNORE_PREFIXES`; `fb_int_` is not in that list (`:826`). The 0.42 m mean is not "the mesh
riding on cot tops" either — see next.

**Corrected finding on the +0.42 m column:** under 24 civilians standing ON a polygon (snap < 0.3 m XZ)
the mesh sits **+0.21 min / +0.39 median / +0.52 max above the physics floor** — on open ground, no
furniture involved. That is the compound-wide baseline (0.2-cell up-rounding plus the 4 m terrain
grid vs the mound trimesh), so the census's `dy` column cannot discriminate furniture from floor and
must not be cited as evidence of riding. `path_height_offset 0.45` (`civilian.gd:376`) is
compensating a global offset, which is fine, but any "is this spot on the floor" test built on mesh
height has a 0.2 m band to work with (cot-top polygons sit at floor +0.72, baseline max +0.52).

**MC_pit_floor is not the mortar pit.** Four instances (2256/2358/2460/2562), 18.8 m plates whose
floor ray hits `m101_breech&cannon_*` — these are the HOWITZER pits (`gun_crew_arty`,
`site_planner.gd:1257,1730`). The mortar pit is `scenes/world/mortar_pit.tscn` with a
`CollisionTable` box (`collision_table.gd:154`). The briefing's row 5 names the wrong pit.

**The one measurement that separates the hypotheses** (for the census, one line): for the collider
`test_move` names, `map_get_closest_point(blocker AABB top-centre)` and print `dxz` vs the half-width
and `dy` vs the top. RIDES (`dxz` inside, `dy` ≈ +0.2) = climb; BESIDE (`dxz` > half-width) = hole;
UNDER (inside, `dy` ≈ floor) = absent from the bake. My probe is that measurement, run once.

## 3. The gate: 53 → 26 is mostly reclassification

- The census counts a man `walking` when planar speed > 0.3 m/s (`probe_npc_census.gd:29,149-151`).
  A man sidestepping at `UNSTICK_SPEED 1.6` for 0.6 s of every ~1.6 s (`civilian.gd:239-262`) is
  "walking" at roughly a third of the samples. **Walking rows: runs 3-13 mean ≈ 8; run 14 = 20; run
  15 = 23. Stuck+walking: run 13 = 50, run 14 = 46, run 15 = 49.** The sidestep moved men from one
  column to the other.
- The number that matters is arrival. Counted from the logs' own `post Xm` column, post-bound rows
  (`->work/cook/fish/walk_paddy`) within 2 m of the post, four samples summed:
  **run 3: 45 at / 42 away · run 13: 48 / 33 · run 14: 57 / 35 · run 15: 58 / 36.** The unstick edit
  bought ~10 real arrivals (probably grazes freed by one sidestep); the "away" count is flat at
  33-36. The demo blocker — the cook aims at the stove and stands in his hooch — is unchanged in size.
- Run-to-run noise with no behaviour change (runs 3-7, then 9-13): 53, 49, 38, 45, 53 / 48, 45, 44,
  39, 41 — SD ≈ 6. One run cannot show a 5-row effect. A real gate: **count `away` (bound, > 2 m,
  after the 75 s settle) not `stuck`; a man whose post is < 80 m away (1.1 m/s × 75 s) and still
  "walking" counts as away; N ≥ 3 runs per arm on the shipped seed plus one other seed; call a change
  real only past 2 SD.**
- Instrument defect: the 10 cm `test_move` is horizontal from the current transform, so on a 2-4°
  upslope it reports the FLOOR (`@4021`: `HITS 'fb_terrain_mound_1473' normal.y 1.00 contact +0.00`).
  Filter `normal.y > 0.5` before naming a blocker, or that row lies.
- Threshold edge: `_rescue_snap` fires only past `OFF_MESH_M 1.2` (`civilian.gd:269-277`,
  `nav_router.gd:37`). Seven of run 15's 26 rows sit at 1.07-1.20 m off-mesh — inside the band by
  centimetres, never rescued. Do NOT "fix" that by lowering the threshold: the snap goes to the
  nearest polygon, which in a hooch is a cot top; `_seated` then stands him ON the cot.

## 4. Each fix, and what it breaks (law 2)

**Fix 1 — tell the bake the truth about climb.** Not implementable as written: `agent_max_climb =
maxf(cell_height, round(0.4/h)*h)` (`nav_baker.gd:400-401`) floors at one cell = 0.2 m, not 0.1.
At 0.2 climb, Recast connects neighbour spans only when their tops differ ≤ climb, so any slope with
per-cell rise > 0.2 over a 0.25 cell — **steeper than 38.7°** — becomes a mesh cliff while
`floor_max_angle` 45° (`:404-407`) lets the body walk it: the inverse fiction band the comment
warns about, opened for berms, the mound's skirts and crater walls. It reverses the crater ruling
(`:399-401`, "0.4 exists so a crater rim is not a cliff") and his 2026-08-13 "walk all the real
geometry" decree. To lower climb honestly you lower `cell_size` to match (0.2 climb → 0.2 cells,
1.56× columns; 0.1 → 6.25×) on the biggest bake in the game (370 m box, 2.2-2.4 s today), paid again
by every breach re-bake mid-siege (`REBAKE_MAX_WAIT_S 6.0`, `:70`). **And it does not free the men:**
a cot that is no longer a step is a hole with 0.5 m of erosion — the radio chair rows show exactly
what a hole does (man off-mesh 1.1 m, no rescue). Fix 1 converts "walked over" into "shredded".
It also changes the assault: 45 men who today route over sub-0.4 sandbag lips would route around.
**Refuse.**

**Fix 2 — carve furniture as obstructions.** Mechanically it is "put `fb_int_` back in
`NAV_IGNORE_PREFIXES` AND add each to `nav_blockers` with `nav_box`" — the first half alone is the
pre-ruling state (`:821-826`); only the carve keeps it "real in both". Facts for the carve:
`body.global_position` equals the AABB centre for every `fb_int_`/`MC_pit` body (my probe: offset
0.00 m), so `_add_structures` (`:1010-1040`) would carve in the right place — **except
`tent_frame_chowhall` (offset 2.30 m, AABB 13.6 × 13.7 m): carving it seals the chow hall**, the
same 16/48 sealed markers `probe_chowhall_nav` found once. Carving `MC_pit_floor` (18.8 m plates)
deletes the four gun pits. **Eleven hooches hold 88 cots + 88 lockers = 8 of each per hooch**; at
`AGENT_RADIUS + 0.15 = 0.65` m inflation (`:1029`) a 1.05 × 2.0 cot carves 2.35 × 3.3 — eight of
them empty the interior, every `hooch_sleep` home snaps to the doorway, and 88 men sleep in the door
or outside. Without inflation the path hugs the cot edge and the body jams (the reason inflation
exists, `:1024-1028`). Decidable ONLY by `probe_interior_nav` ("can a man walk inside?") after a
trial bake with a civilian-radius inflation (0.3). Cost either way: bake time is unchanged, but the
hooch interior polygon count and every `home` position move. **Only with the probe, and never for
the tent frame or the pit plates.**

**Fix 3 — give the body the step the mesh promises.** The one fix that makes mesh and physics agree
without touching the bake, and the ONLY one of the four that frees the 7 pit-lip rows (+0.34 lip,
capsule radius 0.3 steps ≈ 0.08 m: `acos((r-h)/r)` crosses 45° at h ≈ 0.09). Costs: a man walks
over a bunk (0.51 m) in a hooch and over the aid-station cots that hold patients (`med_cot`,
`site_planner.gd:1675-1695` — patients are pinned, medics walk); a 2-3 `test_move` cost per BLOCKED
frame on top of the slide budget the 9/11 perf wave fought (`civilian.gd:484-496`); and if it goes
into the shared movers (`ally_base.gd:2169`, `enemy_base.gd:2693`) sappers step over any lip ≤ 0.4
including the wire if `bwire_card` is under 0.4 m — **measure the wire card's AABB before any enemy
step-up** (I did not; nobody has). Gate it: civilians only, `_want_speed > 0.5` and planar velocity
< 0.05 and `is_on_floor()`, up ≤ `NavBaker.AGENT_MAX_CLIMB`, forward 0.2, then floor-snap. It does
nothing for hole rows (radio set, off-mesh 1.1 m).

**Fix 4 — keep placement out of the furniture.** As briefed ("first metre free") it is too weak: the
hooch men's problem is the route OUT, not the first metre. But the right form is cheap and is the
only one that addresses the hole rows: in `_resolve_target` (`civilian.gd:1443-1450`) accept a
candidate only if `nearest_mesh_point` moved it < 0.3 m XZ **and the support under the snapped point
(one ray, layer 1) is not an `fb_int_` collider** — support identity, not height, because the
baseline +0.21..+0.52 overlaps a cot top at +0.72 within 0.2 m. Golden-angle step otherwise. This is
handoff §5.2's "floor/support identity" (`DEMO_40MIN_HANDOFF_2026-09-13.md:344`) scoped to one
call — not the `PlacementRequest` the briefing forbids designing here. Sacrifice: a man whose every
candidate fails stands at the quarters marker (today's behaviour); none of the pit or tent rows move.

## 5. The ruling of 2026-08-13 ("real in both", `nav_baker.gd:821-826`)

Honoured: fix 3 (both say "step") and fix 4 (orthogonal). Honoured in spirit only if written as a
carve: fix 2 — the `NAV_IGNORE_PREFIXES` half alone is the exact pre-ruling contradiction. Quietly
reversed: fix 1 at 0.2 climb reverses the crater half of the same day's decree. Note the ruling's own
premise was "the navmesh said walkable, the collider said no" — that is STILL the state for every cot
and lip today; putting the furniture in the bake made it ridden instead of ignored. The ruling was
right; its execution assumed a 0.1 m climb the code never had.

## 6. Cheaper first moves the Arbiter did not list

1. **Fix the census before fixing the game** (one evening, no game file): arrival column, normal-y
   filter, the blocker-vs-polygon line from section 2. Without it every fix is scored on noise.
2. **Move the seven pit posts, not the mesh**: `gun_crew_arty` rest/talk resolve to the gun marker
   inside the lip (decree table, `civilian.gd:1412-1415`). A rest spot on the plate's INSIDE (they
   are already in the pit at spawn) or a `work_gun` marker outside the lip costs a marker edit in the
   scene (ADR-041's legal path) and zero code.
3. **The tent beam**: a 0.30 m ground beam on a canvas frame is a `-colonly` choice; drop the beam
   from the frame collider in the export (`recon-destructible-export`) and the cook's row closes
   with no nav change.
4. Correct the two fossil comments (`:389-393`, `:1093-1095`) in the same change, whatever lands.

## 7. Verdict

Combination that survives: **census first (6.1), then fix 4 in its support-identity form + fix 3 for
civilians only**, both cheap, both leave the bake alone, both leave enemies/allies untouched;
fix 2 only after `probe_interior_nav` says a 0.3 m-inflated carve leaves the hooch walkable, and
never for the tent frame or pit plates; fix 1 refused. Riskiest edit: any climb/cell change
(fix 1) — it re-bakes the connectivity of the whole compound and the assault's approach, then hands
the men holes instead of steps. Second: a step-up in the shared enemy mover before the wire card is
measured. What the read missed: the cell height is 0.2 and the climb 0.40 (the log prints it every
bake), the +0.42 m is the mesh's baseline over the whole floor, `MC_pit_floor` is the howitzer pits,
and 53 → 26 is the sidestep moving rows into `walking` while arrivals moved ~10 and "away" did not.
