# THE DECREE — RECONgame demo-state audit, 2026-09-07

**AUDIT ONLY. Nothing was fixed. Nothing was committed.** Two files were created as evidence:
`tests/probe_fsb_extent.gd` / `.tscn` (a new measurement probe) and this folder.

---

## 1 · THE HONEST STATE, IN SIX LINES

- **It boots.** Main scene `--headless --quit-after 900`: **0 SCRIPT ERROR**. Demo scene
  (`scenes/levels/demo_game.tscn`, seed 29072026, 512m): **0 SCRIPT ERROR**, 26 warnings,
  world built, player seated, squad ordered to the gate at T+10s.
- **A mission starts with no console.** Title splash → main menu (DEPLOY / NEW TOUR / SOLDIER /
  SERVICE RECORD / OPTIONS / EXIT, `main_menu.gd:59-66`) → world. The demo build boots straight
  to the arc via the `demo` feature override (`project.godot:22`).
- **The player can move, shoot, win and lose.** ADR-016 flat damage grammar **PASS**
  (`test_flat_damage`, 15 weapons). Night sight **PASS** (13/13). End card exists and names the
  outcome: `"FIREBASE HELD"` / `"YOU FELL BEFORE DAWN"` / `"THE WIRE BROKE BEFORE DAWN"`
  (`demo_game.gd:546,571-576`).
- **The frame cost is GPU-led and it is the biggest single risk.** Recorded floor-box numbers
  (Intel UHD, 1280x720, 0.75 scale, `PERF_LEDGER` 2026-08-14 evening): **quiet 33.9 avg / 9 min ·
  assault_in 27.4 / 5 · assault_on_wire 22.6 / 5.** This session's headless CPU-only re-run
  reproduces the doctrine: **quiet 104.2 avg / 7 min · assault_in 57.2 / 4 · assault_on_wire
  88.0 / 39** — the wire's 5 fps dips are GPU (39 fps floor on CPU alone), but **arrival carries
  a real CPU floor of 4 fps**, and 121 `+232 clips from shared anim library` loads fired after
  the siege opened, which is the known ~35 ms/man instantiation drip.
- **Placeholders that a stranger will see:** untextured white surfaces on `us_medic`
  (`medic_brassard`) and `us_surgeon` (`mask_face`), both garrison/aid-station fixtures on the
  walked path; the surgeon can never wear any of the 15 authored helmets; bolt/MG/launcher
  carriers hold their weapons like rifles (three whole animation families missing); mortar pits
  are untextured white boxes and shells float in the gun pits (`ART_WORKLIST_2026-08-28.md`,
  items 13/16, untouched since).
- **Nothing crashed in any run.** The one `SCRIPT ERROR` seen all session was the perf probe's
  own headless screenshot (`perf_probe.gd:283`) — an instrument fault, not the game.

---

## 2 · THE GAP TABLE

Demo-blocking = the stranger's session fails without it, under the *amended* definition
(briefing §"The Arbiter's challenge"). Cost is engineering-hours unless marked ART-DAYS.

| # | Gap | Evidence | Demo-blocking? | Cost | Sacrificed if skipped |
|---|---|---|---|---|---|
| 1 | **No in-game onboarding of any kind.** No controls legend anywhere in the runtime; the topo-map hint `[M] STOW…` (`topo_map.gd:427-428`) only shows *after* the map is open; pause menu has no keybind list (`pause_menu.gd:67-85`); `PLAYER_MANUAL.md` has a full control table but **zero code references it** (`grep -rn "PLAYER_MANUAL" --include=*.gd` = 0 hits) and it flags itself stale at lines 3-5 | **YES** | 4-8 h | The stranger cannot act. This is r4bk at the top level: the whole input doctrine (ADR-012) has no visible affordance |
| 2 | **The payoff is at minute 23-24 and no contact before it is guaranteed.** `PROBE_AT_S 1395` / `SIEGE_AT_S 1440` (`demo_game.gd:70-71`); backstop 2700. Pre-siege contact = one fixed 3-4-man group at 165-185m (`mission_generator.gd:812-813`, `lazy:false`) plus 2-3 lazy patrols at 140m activation (`:932-950`). A player who stays inside the wire meets nobody for 23 minutes | **YES for a 15-min window; NO for his 30-min arc** | 0 h to re-time; **a ruling, not a fix** | Either the arc's length or the stranger's window. Only he can pick |
| 3 | **The siege forms up OFF THE MAP.** `RING_MIN 300.0` / `RING_MAX 500.0` (`siege_director.gd:19-20`), `MORTAR_TUBE_STANDOFF 700.0` (`:50`) on a **512 m** map (`game_flow.gd:586`, boot log `Map: 512m (2x2 chunks)`) with the firebase near centre (player spawn 254,288). Measured: **1,057 `floor_y` no-collider misses** in one siege run, at coordinates like (573,180), (275,629), (631,-75) — outside 0..512. 885 of the 901 warnings in the run are this | **YES** (climax integrity + a `push_warning` per man per tick) | 2-6 h (clamp the ring to the map) | The demo's climax; attackers walk ~200 m on nothing before they reach rendered ground |
| 4 | **10 stray prop meshes sit ~900 m from the firebase origin.** NEW measurement, `tests/probe_fsb_extent.tscn`: merged AABB 996.96 m; drop the 10 and it is **271.90 m — inside the [250..300] band.** Named: `fb_ammo_crate_stack`, `fb_field_range`, `fb_hanging_bulb`, `fb_wash_drum`, `fb_water_can`, `fb_jerry_can`, `fb_mermite`, `fb_folding_table`, `fb_bench`, `fb_c_ration_case` | **YES** (they render ~650 m off-map unless the 40 m interior cull catches them) | 0.25 ART-DAY (delete a donor shelf in the `.blend`, re-export) | Closes `test_asset_probe`'s oldest red, open since 2026-08-14, triaged then as "post-demo unless a band was wrong" — **the band was right; the model is wrong** |
| 5 | **Untextured white surfaces on units the player walks past.** `us_medic` `medic_brassard[0]:medic_brassard_white`, `us_surgeon` `mask_face[0]:SurgeonMask2` — fired at demo boot (`recon_demo_boot.txt:82,134`), detector `model_actor.gd:642-653`. Both spawn in the demo: `civilian.gd:203-205` (MEDIC MOS), `:279` (GARRISON_MEN), `:287` (aid-station `us_surgeon`) | **YES** ("nothing renders as a placeholder") | 0.5-1 ART-DAY | Pillar 2 on the first thing he walks past inside the wire |
| 6 | **Three weapon-family animation sets do not exist.** `no '__bolt' / '__mg' / '__launcher' weapon-family clips in anim_library` (`model_actor.gd:997`) — every bolt-action, MG and launcher carrier in the 45-man assault holds his weapon like a rifle | **YES** (it is the climax, at close range) | 3 ART-DAYS | Pillar 1 believability in the one fight the demo is built around |
| 7 | **`us_surgeon` has no `helmet_shell_worn` mesh** — `[DRESSER]` warning at boot; none of the 15 authored helmet variants can be hung on him | No (one unit) | 0.25 ART-DAY | Repetition in the aid station |
| 8 | **ADR-005 witness rule is HALF FAILING.** `test_witness_rule` FAIL (b) witness not anchored on the killer — `lkp=(200.0, 0.0005, 0.0)` vs killer at (140,1,0), **60 m off**; FAIL (c) finder not anchored on the corpse — `lkp` = the finder's own spawn point, never set. He escalates to ALERT correctly; he does not know **where to look** | No for the demo; **YES for the law** | 2-4 h | A constitutional law of this project is red, and `OVERSEER_CHARTER.md:130` claims it "✅ DONE… probe `test_witness_rule`". The charter cites a probe that fails |
| 9 | **Player-callable fire support is unreachable.** `test_fire_support_grant` 13 FAIL: *"napalm granted 0 on a HIGH AO, expected 1 — the verb is still unreachable"*, same for CBU and Spectre; mortar 2 vs 3; bombs 0 vs 1 at every threat tier. The demo's spectacle strikes bypass this entirely via `d.authored_strike` (`demo_game.gd:180-186`) | No (spectacle still fires); **yes for r4bk** | 4-8 h | The [T] fire menu is a HUD affordance that grants nothing — the exact r4bk inversion |
| 10 | **19 negative-controlled probes from the 9/06 fix waves are invoked by NOTHING.** `test_suite_health` FAIL, 19 of 685 checks; each says *"a probe that never runs proves nothing"* (`probe_daylight_death`, `probe_hooch_path`, `probe_auto_crouch`, `probe_flare_stays_put`, `probe_siege_fields_men`, …). **My own `probe_fsb_extent` makes it 20** | No | 2-3 h | Every 9/06 fix ships with no regression guard |
| 11 | **`hunters` and `zpu_guns` are written and never read.** `test_group_contract` FAIL x2. Writers `field_director.gd:192`, `lazy_group.gd:95`, `zpu_gun.gd:71,96`; zero readers. The comment at `field_director.gd:190-191` claims `live_enemy_count("hunters")` counts them — **that call does not exist anywhere** | No | 1-2 h | ADR-023; and a false comment (Truth law) |
| 12 | **Squad roster never refills.** `test_squad` FAIL `"roster not refilled (7)"`. MOVE orders pass in the same run | No for one night | 2-4 h | Pillar 4 across a tour; invisible in a one-day demo |
| 13 | **Water surface sits 26.71 m off its carved bed** (tol 2.50). `test_height_authority` FAIL, 9 checks pass | Unknown — needs eyes | 2-4 h | A visible water seam if the demo's 14 hydrology channels surface anywhere the player walks |
| 14 | **12 broken `.import` source refs + 3 stale.** All 12 are `assets/zombies/characters/zed_*.glb` (parked mode); stale = `recovered_bugjuice_label.001/002.png`, `USM4A3Sherman.obj`. `test_import_refs` FAIL | No (zombies parked) | 1 h | A red test that hides a future real one |
| 15 | **`ac47_spooky_v2.glb` — the gunship actually flown (`spectre_gunship.gd:11`) — has no tight scale band.** The probe fails loudly on the retired v1 (4.34 m vs [26..32]) while the live model falls through to a >60 m/<0.05 m backstop | No | 0.5 h | ADR-002 has no guard on the airframe that flies |
| 16 | **The 40 new VC/NVA face atlases are UNTRACKED in git**, plus `data/ai/doctrine_us.tres` modified-uncommitted. They ARE imported (`.godot/imported/…-*.ctex`, Sep 6 14:38), so they work on this box and would vanish from a clean checkout | **YES for shipping** | 0.25 h | The demo on disk is not the demo in the repo |
| 17 | **The build on disk is 5 weeks stale.** `build/RECON_Demo.exe`, **2026-07-31**, 1.47 GB. Nothing from the 9/06 fix waves (20+ commits) is in it | **YES** | 1 h (his export) | There is no artefact a stranger can be handed |
| 18 | **Air traffic asks for ground outside the map.** 20 of the run's `SURFACE_Y` misses come from `air_traffic.gd:526 _ground_at`, at coords up to (814, 77) on a 512 m map. Harmless to gameplay; pure log noise that buries real warnings | No | 1 h | Signal-to-noise in the only diagnostic channel there is |

---

## 3 · SHORTEST PATH TO DEMO — ordered, with the gate that proves each done

The standing decree (`GAME_GUIDE §8.1`) is honoured: this is that order, re-cut against measurement.

**Step 0 — THE ONE RULING ONLY HE CAN MAKE (blocks nothing else, decides step 4).**
*Is the demo a 15-minute sit-down or his 30-minute arc?* The code says 30 (`demo_game.gd:38-45,70-71`).
If a stranger gets 15, the probe/siege clocks must move or a guaranteed first contact must be
authored inside 5 minutes. **Do not build against a guess.**
*Gate:* his word, recorded in `GAME_GUIDE §8`.

**Step 1 — THE STRANGER CAN ACT (gap 1).** One controls surface. Cheapest honest version: a
controls page in the pause menu (`pause_menu.gd` already builds rows) plus a first-boot card, both
generated from the actual `InputMap` so they cannot drift.
*Gate:* a probe that asserts every action in `project.godot [input]` appears in the rendered
control list, and that the list is reachable from the pause menu in ≤2 clicks.

**Step 2 — THE CLIMAX FITS ON THE MAP (gap 3).** Clamp `RING_MIN/RING_MAX` and
`MORTAR_TUBE_STANDOFF` to the live `world.map_size` rather than to constants written for 1280 m.
*Gate:* re-run `demo_game.tscn -- --perf-probe --perf-siege`; **`[SURFACE_Y] no collider`
count from `floor_y` must fall from 1,057 to 0**, and `probe_siege_fields_men` must still field
30 of 30.

**Step 3 — NOTHING WHITE ON THE WALKED PATH (gaps 4, 5, 7).** The 10 stray props deleted and
`fsb_main_v3.glb` re-exported (**re-generate `firebase_v3_destructibles.json` in the same change
or all 80 parapet segments break and SiegeDirector goes blind** — `site_planner.gd:1993`);
`medic_brassard` and `SurgeonMask2` textured; `helmet_shell_worn` added to `us_surgeon`.
*Gate:* `test_asset_probe` PASS on `fsb_main_v3.glb` (expect ~271.90 m), and a demo boot with
**zero `[MODEL] … DEFAULT WHITE` and zero `[DRESSER] … no helmet_shell_worn`** warnings.

**Step 4 — THE ARC HE RULED IN STEP 0.** Whatever he picks, re-time in `demo_game.gd` only.
*Gate:* a headless arc run that reaches `_phase 3` and prints the end-card title.

**Step 5 — THE GATING FPS NUMBER, FINALLY TAKEN.** The proposal has waited **24 days**:
*assault_on_wire ≥ 20 fps average, ≥ 10 fps minimum at 0.75 scale on the UHD floor*
(`PERF_LEDGER` 2026-08-14). Today it passes on average (22.6) and **fails the minimum (5)**.
*Gate:* his ratification, then a windowed `--perf-probe --perf-siege` run recorded in
`PERF_LEDGER.md`. Nothing below this is trustworthy until it exists (`GAME_GUIDE:415`).

**Step 6 — THE THREE ANIMATION FAMILIES (gap 6).** `__bolt`, `__mg`, `__launcher`.
*Gate:* demo boot with zero `no '__*' weapon-family clips` warnings.

**Step 7 — RESTORE THE GUARDS (gaps 8, 9, 10, 11).** Witness anchoring, fire-support grants, the
19 orphan probes wired into `test_*.tscn`, the two write-only groups.
*Gate:* `test_witness_rule`, `test_fire_support_grant`, `test_suite_health`, `test_group_contract`
all green — and `OVERSEER_CHARTER.md:130` corrected either way.

**Step 8 — SHIP THE ARTEFACT (gaps 16, 17).** Commit the 40 face atlases and `doctrine_us.tres`;
re-export; three playthroughs on the floor box.
*Gate:* `git status` clean on `assets/` and `data/`; a `build/RECON_Demo.exe` dated after the
last commit; his verified playtest — **which is the standing entry gate and discharges nothing
until he plays it (ADR-015).**

---

## 4 · CONTRADICTIONS FOUND — named plainly

1. **My own operating instructions are stale.** The agent prompt says *"PLAYTEST R4 is the
   standing session entry gate."* `GAME_GUIDE:400` replaced it on 2026-08-06 with **THE DEMO
   PLAYTHROUGH**; R4 is explicitly *deferred post-launch, never discharged*. Canon outranks the
   prompt (ADR-014). The prompt should be corrected.
2. **`OVERSEER_CHARTER.md` §8 and §9 are two epochs out of date.** §8 still names
   *"MAIN PRIORITY … the Blender→Godot FP gun/arms PIPELINE"* (2026-07-25); §9 still says
   *"Feature gate: ACTIVE, held by PLAYTEST R4"* — contradicting §8 item 0 in the same file.
3. **`OVERSEER_CHARTER.md:130` claims the stealth bundle "✅ DONE … probe `test_witness_rule`".
   That probe FAILS today**, twice, on anchoring.
4. **`OVERSEER_CHARTER.md:151` records the perf doctrine as *"now CPU-bound in the AI"*.**
   REFUTED by `PERF_LEDGER` 2026-08-14 and re-confirmed by this session's headless run: the
   frame is **GPU-led** on the floor box (39 fps CPU floor at the wire vs 5 fps real).
5. **`GAME_GUIDE:136` and `:415` say the gating FPS number "has never been taken".** Half wrong:
   **THE WALK · ONE DIG · THE BARRAGE still have no rows**, but the demo's own siege poses were
   measured on 2026-08-14 and a gate was *proposed*. What is missing is his **ratification**, not
   the measurement.
6. **`PLAYTEST_FINDINGS_2026-08-28.md`, item 31, is stale on two counts.** It says *"there is not
   one `*_face_atlas_viet.*` file on disk"* and *"Godot has never seen it"*. There are **40 such
   files on disk**, and `.godot/imported/*.ctex` for them is dated **Sep 6 14:38**. The import ran.
   Only his eye is still owed.
7. **`field_director.gd:190-191`'s comment claims `live_enemy_count("hunters")` counts the group.
   That call site does not exist** anywhere in the repo (Truth law).
8. **BROKEN INSTRUMENT — every `PERF AI think_ms` row ever printed is meaningless.**
   `perf_probe.gd:168` samples `CombatManager.ai_usec_think` as a per-frame cost, but that counter
   is a monotonic accumulator (`enemy_base.gd:834`, `ally_base.gd:860`, `+=` only) and the probe
   never deltas it — the arena does (`ai_stress_arena.gd:406`), the probe does not. This session's
   run reads 258.88 → 1329.90 → 3774.65 ms, rising with elapsed time. **Do not cite this row.**
9. **BROKEN INSTRUMENT — `--perf-probe` emits a `SCRIPT ERROR` under `--headless`.**
   `perf_probe.gd:283` calls `save_png` on a null image. Harmless, but it trips this project's own
   definitive validation check (`--headless` + grep "SCRIPT ERROR").
10. **A council claim refuted on contact, this session.** A lens reported that *"100% of jungle
    canopy trees are a single untextured procedural placeholder with no code path to load an
    authored tree"* (`vegetation_manager.gd:206-214`). **REFUTED.** `world_config.gd:21`
    `USE_TREE_COVER = true`, so `_rematerialize` (`vegetation_manager.gd:482`) takes the
    `TREE_COVER` branch and the canopy is real per-species GLBs with impostor cards
    (`tree_cover_layer.gd:158-169,192-226`). The procedural tree is the dead `else` branch — but
    its boot line `[VegetationManager] Using procedural tree as primary mesh` prints
    unconditionally, which is how the lens was misled. **The log line is the defect, not the trees.**
11. **`DEMO_SHIP_BACKLOG.md`'s last dated entry is 2026-08-14** despite a Sep 6 mtime, and it
    contains no live P0 list. `PLAYTEST_FINDINGS_2026-08-28.md` is the operative tracking doc.
12. **The EA target date has passed.** `GAME_GUIDE:377` — *"STEAM EARLY ACCESS, 2026-09-06."*
    Today is 2026-09-07 and the entry gate (his playthrough) is undischarged.
