# THE DECREE — demo-scope audit, 2026-08-12

**Council:** technical-director (arc) · systems-designer (four systems) · lead-programmer (AI/combat) ·
technical-artist (silent defects) · godot-specialist (post-export verification).
Five architects, parallel, no cross-talk. Analyses in `production/war_room/analysis/*_2026-08-12.md`.

**Method note:** every claim below carries a `file:line`. The export lane worked from the decompressed
import cache (`.godot/imported/fsb_main_v3.glb-*.scn`, current at 22:27), so its numbers are
post-import truth, not predictions.

**Standing constraint honoured:** Caleb was live in Blender (`firebase_v3.2.blend`) and the game was
running. No `.blend` touched, no GLB re-exported, no game process killed. The audit made exactly one
write outside its own analyses: the drift correction to the `recon-destructible-export` skill doc,
under the NO MORE DRIFT law.

---

## THE HEADLINE — three checklist premises were wrong, and each was steering work the wrong way

1. **HOT_CAP is already 50** (`scripts/enemies/enemy_squad.gd:42`, ceiling 64 at `:43`, raised
   2026-07-28 by `8074af38`). The planned change to 26 is a **24-slot regression**. Because
   `SIEGE_STRENGTH = 45` (`scripts/levels/demo_game.gd:87`) is *under* the cap, **there is no cold set
   in the demo — all 45 men run the full brain.** The "33 men read as furniture" risk does not exist.
   Cold men were never furniture regardless: they animate, fall, `move_and_slide`, path, think at the
   same rate, perceive, witness, shoot and die (`enemy_base.gd:830-832, 781, 796, 37-52, 887-890,
   930-948`); they lose only target-scan, the LOS ray and the goal stack.

2. **`[FSB] 0 concave shape(s) forced double-sided` can never print 0.** `backface_collision` is a
   Godot runtime flag defaulting to `false`, and glTF cannot express it. Expect **~2048**. The comment
   at `site_planner.gd:1402-1406` promising 0 after the re-export is **unachievable by construction**
   and is itself a live drift generator. The causal chain in the checklist is also false:
   `_force_backface_collision` (`:1407-1418`) flips one bool and renames/reparents/frees nothing, so it
   cannot break the name-based destructible contract; and `siege_director.gd:66` states outright that
   parapet destruction is spectacle and nothing reads a breach.

3. **The surgeon is not drawn twice.** No duplicate spawn exists. `apron_front` is 0.634 m tall and
   clears the second-body probe's `box.y >= 0.6` test at `model_actor.gd:579`, which has no upper
   bound — a torso *garment* counted as a torso. Three ledger rows carry this as a 0.5-day art job and
   are wrong.

---

## P0 — BLOCKS THE PLAYTHROUGH

| # | Finding | Pointer | Cost |
|---|---|---|---|
| 1 | **B4 root cause.** The authored spawn arm has **no floor check**; the fallback arm does. Authored always wins because `firebase_main.tscn:9-13` ships `spawn_bunk_01/02` — the validated arm is dead code in the demo. Three patches hardened the path the demo never takes. | `game_flow.gd:176-184` vs `:206-217` | ~1 h |
| 2 | **B4's two halves are ONE bug.** Fall through a collider-less hootch → the 2 s fall-catcher rescues with `surface_y` → lands you on the roof. "Under the world" and "on the roof" are the same defect. | `game_world.gd:583-591` | with #1 |
| 3 | **A FOURTH, UNNAMED PATCH — fires mid-siege.** Terrain-dirty reseat, `surface_y`, 0.5 m tolerance, rect merged across all regions. Assault mortars crater the compound → an indoor player is teleported onto a roof **during the attack**. | `game_world.gd:522-525` | **1 line** |
| 4 | **Mounted MG fires from ~15 m up-and-behind (B5 CONFIRMED).** `hip_position (11.37, 9.20, −32.92)` vs rig root `(0,0,−36)`, used verbatim as the world muzzle. | `data/weapons/m60.tres:39` → `weapon_holder.gd:1067` → `:1116-1120` | 15 min |
| 5 | **Same class in 3 more shipped weapons:** `m1911.tres` **55.9 m** off, `m70.tres` **23.9 m**, `shotgun.tres` **5.3 m**. `ppsh41`/`m79` suspect. | as above | 30 min |
| 6 | **9 character GLBs render their full donor set + 8 gore caps inside the live body.** Meshes are prefixed with the unit id, so `begins_with` matching fails, `has_donors` stays false and `:520` returns before hiding anything. Bind-space donors over a rest-scale body coincide at rest and **shear apart on movement** — this is the "legs clipping trousers" report. Broken units: `vc_sapper`, `nva_sapper`, `nva_rpg`, `vc_rpg`, `nva_rto`, 3 mortar crew — **the cast of the night assault** (`siege_director.gd:23`). 12 more render a second bare head. | `model_actor.gd:509-521`, `:541-542` | 3–4 h |
| 7 | **The instrument for #6 is dead on exactly the broken units.** `_report_second_body()` is called at `:548`, downstream of the `:520` early return. | `model_actor.gd:548` | with #6 |
| 8 | **New content shipped without the naming contract.** `medical_complex` = one mesh, one collider: **bulletproof + invulnerable + roof bakes walkable**; `fb_aid_station` matches zero nodes. Chow hall identical — a canvas tent that stops 7.62. **242 `fb_hwall_*` hooch walls are hard** while their screen/roof siblings are soft. | `nav_baker.gd:508-510`; GLB node names | 1–2 h |
| 9 | **Today's roof cull is defeated for 3 of its 5 targets.** `_adopt_structure` reparents bunker colliders onto an unnamed `Destructible`, so `owner_name` matches no cull prefix. **790.6 of 989 m² of roof still bakes walkable — including the MG bunker just made mannable.** Fix: `d.name = mi.name`. | `site_planner.gd:1772-1811` + `nav_baker.gd:482`, `:507-509` | ~6 lines |

---

## P1 — VISIBLY DAMAGES THE DEMO

| # | Finding | Pointer | Cost |
|---|---|---|---|
| 10 | **Mortars fire onto the end card.** The siege check returns *before* `_next_fire` is rescheduled, so the timer runs through the assault and a 3-shell volley lands within 1 s of `siege_ended`. Also no `is_night` check despite the comment at `:129` claiming one. Cadence itself is sane (0.23–1.75 rds/min). | `camp_mortar.gd:130-131` vs `:132` | ~4 lines |
| 11 | **S28 soft-lock, and it silently kills a second system.** Neither phase has a timeout; `_lose()` exists at `:209-214` and nothing calls it on a clock. A stuck pilot suppresses **all** ambient encounters for the rest of the run. Symptom reads as "the dice are boring." | `pilot_recovery.gd:177-198` + `ambient_encounters.gd:181-182` | ~10 lines |
| 12 | **A *live* ambient encounter is gated by nothing.** `_tick_live` runs before any check, so a contact started at 1370 s runs to ~1790 s — **through the 45-man assault**. Start-gates are excellent (11 guards); the live path has none. | `ambient_encounters.gd:145-147`, `:26` | ~6 lines |
| 13 | **~960 full-chunk vegetation rebuilds inside the assault.** `_settle` calls `vm.rebuild_chunk` once per tree with no dedup; the CBU beat (3 cans × 16 bomblets) can queue them at ~1645 s. | `tree_break_system.gd:444`; `fire_plan.gd:35,42` | ~5 lines |
| 14 | **Rockets fuze on undergrowth.** `_is_bush` is used only in blast budgeting, never in `query_ahead` — an RPG detonates on a 0.93 m bush. Pillar 1. | `tree_break_system.gd:61-63`, `:153-163` | 2 lines |
| 15 | **40% of work markers (194 of 487) fall to `off_duty`.** `_ensure_fsb_markers` strips **one** trailing ordinal; names like `work_hooch_sleep_0_001` carry two. Same bug strands **both mortar pits** (`work_mortar_0_gunner` → unmapped), so the mortar clips have no caller — this is the "artillery crew built and stranded" mystery, and it is a string-parsing bug. Howitzers *do* crew. | `site_planner.gd:1042-1045`, `:982` | 1–2 h |
| 16 | **RPD and RPG-2 hold only `rifle_idle`.** Both GLBs mtime 2026-07-11 22:33; siblings hold six clips. Missing and actually played: `reload`, `reload_empty`, `jam`, `charge_handle`. Silent because `weapon_holder.gd:986` early-returns on a missing clip. Player sees 7.0 s / 6.5 s of a frozen pose. **The export will die on gun two:** `rpg2` declares `real_length_m = 0.95` vs 1.1995 m measured (26% drift) and `export_viewmodel_clips.py:147-149` refuses above 15%. `rpd` is clean at 0.7%. | `viewmodel_manifest.json:347` | 10 min + ~2 h bench |
| 17 | **Cover-seek stops 4–5 m short** (not 10). Three additive terms: `COVER_BLOCKER_MAX_M` 2.5, arrival epsilon ~1.5, 3.0 m nav restake dead-band. Candidates are a ring around the man, never a wall *face*. **Proof it is real:** the leap clip is gated on `_wall_within(1.2)`, so a short man silently skips his arrival animation. The 8/07 fix IS in the code — it fixed bogus cover *selection*, a different bug, and was closed against the wrong defect. | `enemy_base.gd:133`, `:1834`, `:2137-2145`; `nav_router.gd:118` | 1–2 h |

---

## P2 — INSTRUMENTS AND DRIFT (cheap, and each one hid a defect above)

| # | Finding | Pointer | Cost |
|---|---|---|---|
| 18 | **No probe validates `hip_position` against the GLB rig root.** Four weapons wrong, suite green. Worth more than fixes #4–5 combined. | `tests/test_viewmodel_poses.gd:30` | ~1 h |
| 19 | **`perf_probe.gd` still reports no milliseconds.** Reads prims/calls/objects, never calls `viewport_set_measure_render_time`. The CPU-vs-GPU split has **never** been measured at `fsb_main`. The 07-26 ledger finding has not drifted — it is still true. | `tests/perf_probe.gd:131-135` | ~10 lines |
| 20 | **THE WALK · ONE DIG · THE BARRAGE have never been run**, in the project's entire history. | `GAME_GUIDE.md:136`, `AUDIT_2026-08-06.md:262` | his run |
| 21 | **The brassard probe went silent on an unfixed defect.** The 8/8 re-export nudged albedo to `[0.86,0.85,0.82]`, just under `WHITE_ALBEDO_MIN = 0.9`. Still no red cross; material still named `medic_brassard_white`. The **mask** at `[0.86,0.84,0.79]` is chosen bone-white and is correct. | `model_actor.gd:627` | 1 h Blender + 20 min code |
| 22 | **Orphan probe: 12, all `zed_*`, reported NEW against ceiling 0.** An alarm agreed to be ignored will hide the 13th. Grandfather with a reason. | `tools/probe_orphan_files.py` | 5 min |
| 23 | **Fossil: `EXCLUDE_AIR_TRAFFIC` / `EXCLUDE_AMBIENT_WAR` exclude nothing** — read only by the boot print at `:97`, while `:22-23` promises they work. Found 2026-07-30. | `demo_game.gd:26-27` | 15 min |
| 24 | **Fossil: `tree_break_system.promote()` has zero callers.** | `tree_break_system.gd:239` | 5 min |
| 25 | **Handoff items to strike:** FIX 0d already fixed (`terrain_watchdog.gd:60`); FIX 3's `demo_game.gd:262` pointer is wrong (real call `:287`, open jungle, `surface_y` correct there); node count 1,259 → **5,475**. | — | done here |

---

## WHAT IS ACTUALLY HEALTHY — stated plainly, because it is most of the arc

- **Arc arithmetic is exact.** 12.5 h ÷ 38 = 1184.2 s · +616 s × 20 = 3 h 25 m · ends **22:25** ·
  1184 + 616 = **1800 s = the decreed 30 minutes**. The seam gates on `MissionWeather.is_night`
  (`demo_game.gd:415`), the same authority the siege rolls on. Supper lands 19:30, two minutes before
  the probe — the garrison day and the arc do line up.
- **45 men materialise, unclamped.** `LIVE_CAP = 50` (`siege_director.gd:35`), margin 5,
  `_enforce_live_cap` never fires. `reinforce(34)` grows strength and peak.
- **No rogue siege.** `_maybe_open` hard-returns on `demo_mode` (`siege_director.gd:172`) — without it a
  random roll could have degraded the authored probe.
- **Gunships are signal-driven on both arms** (`:466`, `:471`). The real pacing ceiling is
  `MAX_DURATION_S = 480` from probe open → hard end ~1875 s ≈ 31 min, **825 s before** the 2700 s
  backstop. The backstop's only live path is `d.siege == null`.
- **All four handoff nav fixes are live:** FIX 0 (`nav_baker.gd:453-465` seeds from
  `FSB_NAV_GEOM_GROUP`), FIX 0b (`project.godot:312-314`, `roundf` climb at `nav_baker.gd:325`),
  FIX 0c (sibling scan `site_planner.gd:1791-1795`, premise confirmed — 4,761 of 8,098 nodes are root
  children), FIX 0d (`terrain_watchdog.gd:60`).
- **The gate is not a choke:** SOCKET_A↔SOCKET_B = **9.00 m**, ~8 m walkable after erosion.
  `door_*` leaves carry **zero** colliders — the screen-door contract is intact.
- **The chow hall is genuinely wired.** Commit `aba5ca53` superseded the handoff's "no friendly work
  director" claim: `FSB_WORK_OCCUPATION` (`site_planner.gd:871-916`) maps every `chow_*` and `med_*`
  type, `civilian.gd:641+` plays the diner clips, `civilian_schedules.gd:202-212` gives two sittings.
- **Tree-break naming is CORRECT** — `_stump`/`_stem`/`_crown` in code and in all 20 species of
  `data/veg_break_bands.json`. Physics bodies are bounded (12+8 per blast, ~2 s life).
- **The export is a real win:** nodes 1,259 → **5,475**, colliders 365 → **2,368**, work markers
  191 → **487**, interior props 178 → **572**, parapet manifest **80/80, 0 absent**, and the chow hall
  and medical complex are in the game for the first time.

---

## THE FOUR SYSTEMS — the cut lever is not needed

Per the standing rule (*fails → flag off, don't debug, unless the fix is under half a day*): **all four
are FIX-CHEAP and all four should be KEPT.** No flag-off is required. Flag-off instructions are
recorded in `analysis/systems_designer_four_systems_2026-08-12.md` should he want them anyway:
`camp_mortar.gd:14 HOLD_FIRE_S → 99999.0` · `pilot_recovery.gd:16 HOLD_FIRE_S → 99999.0` ·
`ambient_encounters.gd:19 EVENT_CHANCE → 0.0` · `tree_break_system.gd:17-18` caps → 0 (partial).

Reachability in a 30-minute run: camp mortar **guaranteed** · tree break **certain and heavy** ·
ambient encounters **moderate** (584 s window) · pilot recovery **low/coin-flip** (needs a Skyraider
nearest a camp ZPU, then a 0.35 roll).

---

## WHAT IS SACRIFICED (Law 2 — no free lunches)

- **Fixing #6 (donor hiding) risks the civilians.** Adding `HumanoidBase_NotOverlapping` blindly makes
  all ten civilians invisible — it *is* their live body. Gate on height vs `TARGET_HEIGHT_M`. The
  prefixed names likely also defeat `GibSystem`'s `find_child()`, so `test_gib_contract_all` must be
  green before it ships.
- **Fixing #8 makes the medical complex and chow hall destructible** — which means they can now be
  destroyed during the assault, and nothing has ever been playtested in that state.
- **Fixing #9 removes ~790 m² of walkable roof.** Any AI currently pathing over a bunker roof will
  re-route; garrison posts seated up there will need re-seating.
- **Fixing #15 wakes 194 sleeping markers at once.** That is 194 more animating men in the compound —
  a perf cost that lands precisely where #19 says we cannot yet measure.
- **Not fixing #17 (cover stop-short) keeps a Pillar 1 defect visible in every firefight.** Fixing it
  moves men 4–5 m closer to walls, which changes every sightline the siege was tuned against.

---

## THE RECORD — recommended order

**Tonight, mechanical, no playtest needed:** #3 (1 line) · #4+#5 (45 min) · #9 (6 lines) · #14 (2 lines)
· #10 · #12 · #23 · #24 · #22.
**Next, needs care:** #1+#2 (B4) · #6+#7 (the assault cast) · #8 (the contract) · #15 (the markers).
**Instruments before measurement:** #18 · #19, then #20 — his three poses, taken with nothing else
running.
**His calls only:** the `START_HOUR` pacing question (DAY currently snaps at **T+47 s**, 37 s after the
squad order; `5.733` lands it at T+120 s but moves the night seam) · the `rpg2` declared length before
any viewmodel re-export · whether the medical complex and chow hall should be destructible at all.
