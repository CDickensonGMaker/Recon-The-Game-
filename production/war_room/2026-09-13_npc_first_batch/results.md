# GATE RESULTS — NPC first batch (2026-09-13 evening)

Instrument: `tools/probe_npc_census.gd` via `--npc-census --test-save`, shipped seed (29072026), four
samples (spawn 6.93h, then 10.5h / 14.5h / 19.7h by clock jump, 75 s settle each, clock paused).
BEFORE = the five batch files (`civilian.gd`, `friendly_patrol_group.gd`, `garrison_defender.gd`,
`gun_crew_performance.gd`, `demo_game.gd`) at `daf621cd`, same instrument. AFTER = the tree as committed.
Logs: `census_before.log`, `census_after3.log` (session scratch; per-row tables are in them).

| sample | BEFORE wrong-target / stuck / overlaps | AFTER wrong-target / stuck / overlaps |
|---|---|---|
| spawn 6.93h | 12 / 0 / 21 | 0 / 5 / 4 |
| 10.5h | 17 / 1 / 18 | 0 / 13 / 2 |
| 14.5h | 18 / 1 / 20 | 0 / 18 / 9 |
| 19.7h | 14 / 0 / 5 | 0 / 17 / 10 |
| **total** | **61 / 2 / 64**, 0 roofs | **0 / 53 / 25**, 0 roofs, 0 `SCRIPT ERROR` |

The census exits 1 on AFTER (stuck + overlaps remain). Every remaining row is named below (decree gate:
"or every remaining row named with a cause").

## What the batch fixed, as measured

- **Wrong place → right target.** Every mess_cook, sentry, detail, off_duty and mess_hall man now aims
  at the place his action binds him to (`tgt` = `post` on every row). BEFORE, the cooks' targets were
  their own hooch (`tgt 0.9-1.8 m` at 2.4 m from home, 57-84 m from the range) — the owner's symptom.
- **The replacements walked off the map** (found by the census, fixed as item 9 below): every man the
  resupply Huey delivered aimed 213-297 m away at his flight-origin "home", because his target was
  resolved before `_deliver()` handed him a bunk. BEFORE 12 such rows over four samples, AFTER 0.
- **The squad stacked at the gate** (found by the census, fixed as item 8): the demo's move-out sent all
  eight men to ONE point; six arrived and stood at 0.00 m for the whole run (15 of the 21 overlap pairs
  at every sample). AFTER they file out at 2.5 m intervals; the pairs are gone.
- **Overlaps 64 → 25**, none at the gate.
- Run 1 of AFTER threw 21 `SCRIPT ERROR`s from `gun_crew_performance.gd:97` writing the renamed
  `_last_clip` at every stand-to promotion — the rename had missed one caller. Fixed; runs 2-3 are clean.

## What remains, named — and then measured to the prop (runs 4-14, same evening)

**STUCK (53 rows, ~24 men, every sample in run 3).** Same signature on every row: `tier 0`,
`box 0`, on the floor, aimed at the post, velocity 0.00 for the whole 75 s settle. **Pre-existing:**
the same six detail men and both cooks stood at 0.00 m/s at home in BEFORE (flagged WRONG-TARGET
there only because the old jitter aimed them 1.5 m off the post).

Eleven more census runs, each adding one column to the STUCK row, walked the cause down:

| column (run) | what it showed |
|---|---|
| navmesh route from the man to his target (4) | 43 of 49 rows HAVE a route (2-34 points); "no route out of quarters" was wrong for most |
| agent state + slide contact (5) | 16 rows: agent has a path, no wall contact, velocity 0; 13 rows: agent reports FINISHED with the target 3-107 m away; 9 rows blocked by two named sandbag hooches and the radio chair |
| router step, tree speed, in-box (6) | every stuck man is handed a non-zero step (0.3-107 m) at a non-zero speed toward a target inside his box — the mover is not starved |
| mesh height under the feet (7) | the navmesh sits +0.05 to +0.85 m (mean +0.42) ABOVE the floor the men stand on; 49 of 53 next path points were unreachable in 3D within `path_desired_distance` 0.7 |
| `path_height_offset` -0.45 → +0.45 (8, 9) | the agent SUBTRACTS the offset (negative raised the points 0.45 further, stuck 53 → 59); +0.45 puts the points at the feet (next dy ±0.2) — and frees nobody (48) |
| steepest slide contact by angle (10) | most stuck men rest on `fb_terrain_mound` at 1-4°; only the sandbag-hooch three are at 90° |
| mover counters (11) | `want` 1.10, velocity 0.22 before the slide (rebuilt from zero every frame), **0.00 after `move_and_slide`**, every tick slides |
| seat teleports on `floor_y` + overlap probe (12) | nothing overlaps any stuck man's capsule; the seat (spawner's own rule, now on both teleports) leaves stuck at 39, off-floor rows gone |
| **`test_move` 10 cm toward the target (13)** | **names the blocker on every row: `fb_int_cot_m1/m2`, `fb_int_locker_p0/m0`, `fb_int_radiotable`, `tent_frame_chowhall`, `MC_pit_floor` — vertical faces (normal.y ≈ 0)** |
| unstick reads the WANTED speed (14) | **stuck 53 → 26** (per sample 4 / 7 / 6 / 9 against 5 / 13 / 18 / 17), 20 rows now counted walking across the four samples, wrong-target 0, overlaps 15, roofs 0, script errors 0; the 26 left still `test_move` into cots (`m1/m2/p1`), a locker, the radio chair, the tent frame and `MC_pit_floor` — a sidestep does not get a man out of a furnished hooch, and the rescue snap waits until nobody can see him |

**The stall, in one sentence:** a man's home spread or exact post puts him against interior
furniture (cots, lockers, the radio table), the chow-hall tent frame or the mortar-pit lip; the
navmesh is not carved for those props, so the agent's route runs straight through them; the body
cannot, `move_and_slide` cancels the motion every frame, and `_update_unstick` read that cancelled
velocity as "does not want to move", so the sidestep and the rescue snap never ran. The +0.42 m mesh
height and the agent-vs-server "finished with a route" disagreement are real and recorded, but
neither was the stall.

**Shipped from this (same change):** `_update_unstick` reads `_want_speed` (what `_step_toward`
asked for) instead of the slid velocity, so a man walking into furniture sidesteps after one second
and rescue-snaps after three flips when unseen; `path_height_offset` +0.45 (measured geometry, not
the stall); both teleports (`place_for_current_hour`, `_rescue_snap`) seat on `floor_y` + 0.5 like
the spawner. **Not shipped (N2/N3):** carve `fb_int_*`, the tent frames and the pit lip into the nav
bake or keep the quarters spread clear of them; the chow-hall markers whose nearest mesh point is one
spot (cooks + diner stacked at 0.00-0.03 m, 2.7-4.3 m from their markers — the old jitter hid it).

**OVERLAPS (25 pairs).** The chow-hall stack above (3 pairs × 2 samples); heli replacements arriving
in file to neighbouring bunks (`@9712/@9731/@9750`, 3 pairs × 2 samples); a shared-quarters spread
pair 0.41 m apart in every sample (`@3803/@4273` — name-hash spread without exclusion, N3); squad men
hemmed in at spawn standing in a sentry's quarters (`@3841/@6677`, `@3985/@6677`, `@6730/@6892`);
transient walking pairs. None at the gate.

**Squad move-out arrivals:** 5/8 (run 3), 6/8 (runs 1-2 and BEFORE) — two or three men spawn
"2/4 dirs blocked" in the bunk area and never path out; boot-to-boot variation is the ambient
positioners' own RNG. Pre-existing (N2 spawn placement).

**Roofs: 0** in every sample, BEFORE and AFTER.

## The instrument, corrected while running it

- Run 1 promoted 40+1+5 garrison civilians to defenders between samples one and two (a wire poll,
  not the clock jump), so samples two and three measured an EMPTY civilian roster and read clean.
  `FieldDirector.stand_to_held` (set only by the census) now holds the alarm for the run.
- Rows carry `tgt` (XZ to `_wander_target`), `tier`, `box`, `v`; a STUCK row carries its off-mesh
  distance and floor state; skipped men print their reason (`puppet` / `boarding` / `no physics` /
  `far` / `state N`); a post whose marker is off the mesh is named and counted apart.

## Tests (`run_all_tests.ps1 -Filter`, serial, `--test-save`)

| test | result | note |
|---|---|---|
| test_bt_civilian | PASS | after fixing `%s" % keys()` (an Array on the right of `%` is an argument list) in the new sweep; fractional sweep + cook-at-range assertions green |
| test_schedule_placement | PASS | |
| test_offview_liveness | PASS | |
| test_fossils | PASS | |
| test_group_walk | FAIL — household closed 4.1 m (want > 5) | **HEAD (old code, old test): 4.0 m.** Pre-existing red. |
| test_friendly_patrols | FAIL — 14 `SCRIPT ERROR` | `TerrainWatchdog` → `floor_y` → `HeightmapStorage.sample_bilinear` index 0 on an empty heightmap. **HEAD: identical.** Pre-existing. |
| test_firebase_garrison | REGRESS per the runner's register | 57 garrison men (want ≤ 40), 17 of them at one spot ~650 m out. **HEAD: identical.** The register's "was GREEN" is stale — the reinforce pre-warm of 9/11 (`f3747496`) parks its men off-map in `firebase_garrison`. Not this batch. |

## Items beyond the decree's seven (all in the same change)

8. `demo_game.gd` gate order: each squad man gets `FriendlyPatrolGroup.file_slot(i, gate, fsb_center)`
   (the helper is now static — one file, two callers); arrival is per slot.
9. `civilian.gd` `_bt_tick`: re-resolve when `home` / `working_point_pos` change, not only when the
   action does (`resolved_home` / `resolved_post` in the blackboard).
10. `gun_crew_performance.gd:97` `_last_clip` → `_anim_key` (the rename's missed caller).
11. `FieldDirector.stand_to_held` + the census columns above.

## Next demo blocker (from this evidence)

The "cannot leave quarters" class: the cook now aims at the stove and still stands at his hooch. Its
root is N2 (placement + nav connectivity per quarters marker); the cheapest instrument is to walk
`map_get_path(quarters → post)` for every garrison man at the end of the bake and name the empty ones.
