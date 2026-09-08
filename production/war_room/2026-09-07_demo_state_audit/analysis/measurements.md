# RAW MEASUREMENTS — 2026-09-07, all headless, one Godot at a time

Godot `v4.7.stable.official.5b4e0cb0f`. Logs in the session scratchpad as `recon_*.txt`.

## Boots
| Run | SCRIPT ERROR | Warnings | Note |
|---|---|---|---|
| `main.tscn --quit-after 900` | 0 | 0 | Output is 2 lines: the title splash waits for a click, so headless never reaches the world. |
| `demo_game.tscn --quit-after 1200` (30 s wall) | 0 | 26 | World built, player seated, squad ordered out. |

Demo boot facts: `Map: 512m (2x2 chunks)` · heightmap 128x128 · 14 hydrology channels ·
`GameplayGrid` built in **628 ms** · `NavBaker` main bake **2,330 ms** ·
`[FSB] 1,416 collider(s) >3 m above the terrain heightmap` · `[FSB] 545 interior prop(s) culled past 40 m` ·
`[FSB] 81 destructible parapet segments on the blast bus` (so the destructibles manifest IS present —
none of `site_planner.gd`'s 13 export-drift warnings fired) ·
`[SPAWN-TRUTH] seed=29072026 spawn=254,288 physics_y=179.86 array_y=173.66 delta=6.20 top_hit=fb_hootch_roof_m2_453 player_y=178.18` ·
`[AIR] load SATURATED - 7 fighting, 45.8 ms process`.

## The 13 gate tests (serial, `-- --test-save`)
| Test | Verdict | Failure text |
|---|---|---|
| `test_flat_damage` | **PASS** | ADR-016, 15 weapons |
| `test_night_sight` | **PASS** | 13/13 — this **contradicts** the 2026-09-06 failure list |
| `test_placement_paths` | **PASS** | (was red 9/06; the `pilot_recovery` fix holds) |
| `test_doc_hygiene` | **PASS** | |
| `test_witness_rule` | FAIL x2 | witness not anchored on killer `lkp=(200.0,0.0005,0.0)`; finder not anchored on corpse `lkp=(15.0,0.891,0.0)` |
| `test_group_contract` | FAIL x2 | `hunters` and `zpu_guns` written but NEVER READ |
| `test_height_authority` | FAIL x1 | water surface 26.71 m off the carved bed (tol 2.50), 9 pass |
| `test_squad` | FAIL x1 | roster not refilled (7) |
| `test_asset_probe` | FAIL x6 | `fsb_main_v3.glb` 996.96 m OUT-OF-BAND [250..300]; 4x heli staged clips 67.30 m SUSPICIOUS; `ac47_spooky.glb` 4.34 m OUT-OF-BAND [26..32] |
| `test_fire_support_grant` | FAIL x13 | napalm/CBU/Spectre granted 0 at every tier — "the verb is still unreachable"; mortar 2 vs 3; bombs 0 vs 1 |
| `test_import_refs` | FAIL | 12 broken source refs (all `assets/zombies/zed_*.glb`) + 3 stale |
| `test_playtest_bundle` | FAIL x1 | mortar stock 2, expected >=3 (same root as fire_support_grant) |
| `test_suite_health` | FAIL x19 of 685 | 19 `probe_*` scenes invoked by nothing |

## Demo siege study — `-- --perf-probe --perf-siege` (HEADLESS = CPU truth, GPU reads 0)
```
PERF TABLE scale=0.75 renderer=forward_plus seed=29072026
quiet            fps_avg=104.2  fps_min= 7.0   n=6657
assault_in       fps_avg= 57.2  fps_min= 4.0   n=3637   live_avg=20.1 live_max=35
assault_on_wire  fps_avg= 88.0  fps_min=39.0   n=5776   live_avg=37.4 live_max=43
```
`[PERF] siege opened at strength 50 in 11 cells` — the assault fires and fields its men.

Read against the recorded real-renderer rows (Intel UHD, same scale, `PERF_LEDGER` 2026-08-14
evening: quiet 33.9/9 · assault_in 27.4/5 · assault_on_wire 22.6/5), the GPU-led doctrine holds:
the wire's 5 fps minimum is **not** CPU (39 fps CPU floor). **But `assault_in`'s 4 fps minimum IS
CPU** — 121 `+232 clips from shared anim library` loads fired after the siege opened, the known
~35 ms/man instantiation drip.

Run totals: **1 SCRIPT ERROR** (`perf_probe.gd:283` `save_png` on null — the probe's own headless
screenshot, not the game) · **901 warnings, 885 of them one class**:
`[SURFACE_Y] no collider found probing down from …`, **1,057 from `game_world.gd:456 floor_y`**
(caller `marching_cell.gd:243 _seat_on_terrain`) and 20 from `air_traffic.gd:526 _ground_at`.

## NEW PROBE — `tests/probe_fsb_extent.tscn` (written this session)
```
MESHES=2131
MERGED AABB size=(271.90, 18.47, 996.96)  largest=996.96 m
 900.01m  fb_ammo_crate_stack      900.00m  fb_jerry_can
 900.01m  fb_field_range           900.00m  fb_mermite
 900.00m  fb_hanging_bulb          900.00m  fb_folding_table
 900.00m  fb_wash_drum             900.00m  fb_bench
 900.00m  fb_water_can             900.00m  fb_c_ration_case
 (next furthest: m60_002 at 172.61 m)
--- dropping 10 mesh node(s) past 200m ---
NEAR AABB largest=271.90 m
```
**The firebase's real footprint is 271.90 m — inside its band.** The 24-day-old red is ten donor
props parked at ~900 m in the source `.blend`.
