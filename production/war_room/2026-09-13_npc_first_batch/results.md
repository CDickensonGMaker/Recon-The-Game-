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

## What remains, named

**STUCK (53 rows, ~24 men, every sample).** Same signature on every row: `tier 0`, `box 0`, on the
floor, 0.00-1.2 m off the navmesh, `_wander_target` on the post, velocity 0.00 for the whole 75 s
settle. The router logged five `[NAV-FALLBACK] ... no path - falling back to direct steering` for
garrison men (33-84 m to target); direct steering meets geometry and `move_and_slide` zeroes the
velocity every frame, so `_update_unstick`'s `wants_move` (0.5 m/s, read from that velocity) never
trips and the rescue snap never runs. **Pre-existing:** the same six detail men and both cooks stood
at 0.00 m/s at home in BEFORE (flagged WRONG-TARGET there only because the old jitter aimed them
1.5 m off the post). Cause class: no route from a man's quarters/spawn spot to his post (nav
connectivity / placement — N2, `probe_interior_nav` / `probe_chowhall_nav` are the instruments), plus
the unstick threshold that cannot see a wall-blocked man (bounded fix candidate: measure `wants_move`
from the wanted velocity, not the slid one). Sub-class: the two cooks and the diner DID walk 55-83 m
and stopped 2.7-4.3 m from their markers, stacked at 0.00-0.03 m — the chow-hall markers' nearest
mesh point is one spot, so exact stations expose an unmeshed interior the old 1.5 m jitter hid.

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
