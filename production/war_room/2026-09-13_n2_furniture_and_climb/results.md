# GATE RESULTS — N2 first case (2026-09-13, late)

Instrument: `tools/probe_npc_census.gd` (`--npc-census --test-save`), shipped seed, four samples; the
census now counts, per sample, post-bound men within 0.7 m of their resolved post (ARRIVED) and
farther than 2 m (AWAY). Baseline = run 15 (the tree at `5ddf69be`, `census_after15.log`); AFTER =
the decree's build (`census_n2a.log`). Run 15 predates the ARRIVED/AWAY column, so its arrivals are
read off its rows by the same rule (post distance ≤ 0.7 / > 2.0 on post-bound rows); that reading is
approximate and is labelled so.

| | run 15 (before) | after the N2 build |
|---|---|---|
| wrong-target | 0 | 0 |
| stuck rows | 26 | **14** |
| still walking | 23 | 24 |
| overlaps | 12 | **19** (up) |
| roofs | 0 | 0 |
| `SCRIPT ERROR` | 0 | 0 |
| `[NAV-FALLBACK]` | 6 | 4 |
| arrived (census column) | — | 61 |
| away (census column) | — | 38 |
| arrived / away by the row rule (approximate) | 69 / 65 | 63 / 51 |

**Read:** stuck halved; away down about a fifth; arrivals flat within the rule's noise; overlaps up
seven. The overlaps are the cost the decree named: more men now reach the same station rings and the
chow-hall's one mesh point, and a man stepping onto a cot stands where another already sits.

**What is still stuck (14 rows):** the cots whose mattress is a second step (tops 0.47-0.53 m; one
0.4 m step reaches the rail — `fb_int_cot_m1/m2`, contact +0.30 then +0.43), the radio table (a hole,
tops 0.76-0.80; two rows), one man against the berm face. The cot-top A/B the decree deferred
(`region_min_size 5` vs a 0.3 m carve of cots, lockers and radio furniture, judged by
`probe_interior_nav`) is the next move for these.

## What shipped (one change on `BaseGame-V1`, fast-forwarded into `RPG-build`)

- `NavRouter.OFF_MESH_M` 1.2 → 0.5 (`nav_router.gd:36`).
- `Civilian._step_up_if_blocked()`: after the slide, when the mover wanted ≥ 0.3 m/s and the slide
  returned < 0.05 m/s on the floor, `test_move` up `NavBaker.AGENT_MAX_CLIMB` then forward 0.25 m
  along the wanted direction; take the step if both are clear. Civilians only.
- `Civilian._clear_spot()`: a home-spread candidate is refused when the mesh snap moved it > 0.3 m XZ
  or the ray under it lands on an `fb_int_` collider; the angle walks the golden step, up to eight
  tries (`HOME_SPREAD_TRIES`). `_rescue_snap` refuses a furnished landing the same way (snap limit
  waived; the snap is a long move by definition). Physics-frame only; a test scene without a world
  refuses nothing.
- `nav_baker.gd:389-393` fossil corrected: the map's cell height is 0.2 from `project.godot`, the
  climb is 0.40.
- Census: ARRIVED / AWAY per sample and in the summary.

## Smoke and tests

See the section the build appends below when they land: `--stress=assault` (siege opens, no
`SCRIPT ERROR`, `[NAV-FALLBACK]` count), and `test_bt_civilian`, `test_schedule_placement`,
`test_offview_liveness`, `test_fossils`.

## Smoke and tests (landed)

- `--stress=assault`, 240 s cap: the siege opens, reserve stocked (12 sappers, 37 regulars), 4 squads on 150 deg, reinforced to 45 men (peak 45); `SCRIPT ERROR` 0 after fixing the first smoke's five (the batch's gate-order loop cast a squad member before checking he was alive; the stress frees the dead) - `demo_game.gd` validity-first in both loops; `[NAV-FALLBACK]` 5.
- `test_bt_civilian`, `test_schedule_placement`, `test_offview_liveness`, `test_fossils`: all PASS, 0 errors.
- Gate verdict: SHIPPED. Stuck 26 -> 14, away down about a fifth, arrivals flat, overlaps 12 -> 19 (named cost), wrong-target 0, roofs 0.
