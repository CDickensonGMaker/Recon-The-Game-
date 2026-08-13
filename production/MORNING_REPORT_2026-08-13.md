# MORNING REPORT — the demo audit night, 2026-08-13

---

## ADDENDUM, 2026-08-13 day session — the scale-pipeline job below is DONE (awaiting your eye)

The napalm/bench job in the next section was measured, war-roomed (4 architects,
`war_room/2026-08-13_napalm_scale/`) and shipped. Short version: **the metre agreed all along —
the instrument lied** (god camera 950 m out, one drop instead of nine, no treeline in frame), and
`_KIND_SCALE` napalm 111 drew each of the 9 canisters as a ~513 m fireball with a 1 km shock
ring. Now: napalm ~60 m/drop with its own composition (no ring, bounded climb), heavy ~46 m,
mortar ~28 m, and **hut deaths were firing the napalm-size fireball too** (`destructible.gd:42-44`)
— your nuke night had two sources. `support_fire_range` is the ruling bench: world fog, night,
SHIFT+number = 210 m demo range, **`[`/`]` sweeps the size live** — no code edit needed for your
taste pass. Full ledger + your decision queue: `DEMO_SHIP_BACKLOG.md` §2026-08-13. Ratchet
registers all green this session. Everything below this block is the overnight report as written.

---

## NEXT SESSION STARTS HERE

**16 commits, all pushed, `master` in sync. Nothing is stranded.**

### The job he asked for and I have not started
**The bench/test scene is a different SCALE from the game world.** His words: the napalm *"comes
off like a nuclear bomb"*, and *"the scene I've been testing them in isn't the right scale as to
what the game world scale is, so there's discrepancies between those tools and the pipeline to
the real thing."* If true, **every VFX size tuned on the bench reads wrong in game** — which makes
it a pipeline defect, not a napalm defect, and nudging the napalm scalar would paper over it.

**Measure before touching any scalar.** There is precedent: the explosion size ladder was inert
once already because the number being tuned was disconnected from what actually draws
(`godot-billboard-discards-node-scale` — Godot billboards discard node scale). Establish first
whether the bench and the world agree on a metre, then whether the VFX size input reaches the
drawn quad at all.

### Open, his side (Blender / bench — I cannot do these)
- **Ladder MESH** for the four tower `ladder_bottom`/`ladder_top` pairs, 7.4 m apart. The climb
  works; **no ladder mesh exists anywhere in the project.** He saw the bare markers in play.
- **HQ**, **village interiors and cabinets**, and the **non-gun handheld exports** with proper
  hit-placement markers.
- **M72 LAW has no viewmodel at all** — `m72_law.tres` has `model_path = ""` and `m72_law_fp.glb`
  was never exported. That is why `test_viewmodel_contract` is red. The manifest declares
  `RIG_M72_LAW`.
- **Re-export RPD and RPG-2** — `python tools/export_all_viewmodels.py rpd rpg2`. The manifest now
  passes the `--strict` gate (0.95 → 1.20 on the RPG-2).
- **Re-aim m60 / m79 / shotgun on the bench** — hip and ADS are 35.69 / 11.37 / 59.03 m apart.
  The suite prints those spans every run and they are grandfathered until fixed.
- **Blender renames**: the med/chow soft+destructible ruling, and the 242 hard `fb_hwall_*` hooch
  walls whose own screens and roofs are soft.

### Open, code side
- **His bunker-entry blocker is PHYSICS, not nav.** Measured: **37 of 37** bunker fire points
  reachable (`tools/probe_bunker_entry.tscn`). He is a 0.4 m capsule and nav erodes 0.5 m from
  every wall, so anywhere reachable already fits him. Look for colliders **solid to physics and
  invisible to pathing** — `fb_veg_` and `fb_hootch_roof_` are still in that state by design.
- **Cover-seek stops 4–5 m short.** ~1–2 h, but it moves men closer to every wall the siege was
  tuned against — do it while he can watch.
- **548 character-part colliders** tagged `hard_surface` — men who stop rounds with no hit
  reaction and carve navmesh.
- **`test_height_authority` is the only REGRESS left**, and it is the **water** geometry defect:
  *"water surface sits 26.71 m off the carved bed (tol 2.50)"*, 9 of its 10 checks pass.
- **The Chinook still has no authored seat markers** — it runs on the auto-generated UH-1 fallback
  layout, which is the wrong size for that airframe even though the dismount now works.

### Things NOT to re-learn (each cost real time this session)
- **HOT_CAP is 50**, not 20 — the 45-man assault has no cold set at all.
- **`[FSB] 0 concave shape(s)` can never print 0.** It prints **2048**, verified live. Strike it
  from every checklist.
- **The `model_actor` donor-prefix diagnosis was REFUTED** — parse the asset before writing a fix.
- **The AUDIT-12 leak column is flaky**: LEAK, LEAK, PASS on byte-identical code. Never convict a
  change on a single leak reading; FAIL/PASS is the stable signal.

---

---

## 0. SECOND WAVE (written after he woke and said "keep working on everything we didn't finish")

**`test_nav_path` was never hanging, and the nav bake was never slow. TIMEOUT 420s → PASS 10.8s.**
The test assigned `enemy._nav_box`, a field the AI consolidation deleted — the nav box lives on
the shared `NavRouter` now (`nav_router.gd:13`, `refresh_box` at `:54`). GDScript raises on the
assignment, which aborted `_run()` before it reached `_finish()` — and `_finish()` is the only
caller of `get_tree().quit()`. So the process sat at 120 FPS printing PERF lines until the 420s
box killed it. **It reads as "the bake broke when FIX 0 landed" and has nothing to do with the
bake.** That one test was eating 70% of a full suite run, which is why no clean scoreboard could
be produced.

**Both named REGRESSIONS are now closed:**
- `test_squad_break` → PASS. The real failure was the thrash guard, and the guard was right:
  `COVER_FAIL_LOCKOUT_MS` arrived in `63b4fe6f` yesterday, so two failed cover hunts suppress the
  trip only until the window passes. The test left `_cover_fail_ms` at 0, which reads as long
  expired. The test was asserting yesterday's contract. Also hardened `squad_system.gd:475`,
  which read `global_position` off a man who may not be in the tree — identity plus an engine
  error, so the fall-back callout would have played from the world origin.
- `test_seat_system` → PASS, **and the failure was the design succeeding.** The seat clips are
  `play_first` chains written so the authored postures would land unassisted "the moment the
  export does". `aba5ca53` shipped them (209 → 232 clips), the chain picked them up, and the test
  went red only because it had hardcoded `"sitting"`. It now reads
  `seat_pax_1 sit_lip_outboard_b` / `seat_pax_6 sit_lip_outboard_a` — the a/b alternation so a
  full stick does not sit in unison. **Your "troops ride the lip" ruling, visible in a probe for
  the first time.**

**Your `fb_int_` ruling is IMPLEMENTED and verified.** 1,144 `fb_int_` nodes ship 572 `-colonly`
twins, and every one now enters the bake, so the furniture is real to physics and to pathing
instead of contradicting itself. Verified against the aisle-sealing risk, before and after:
`probe_interior_nav` 30 reachable / 5 SEALED of 35 → **identical**; `probe_compound_nav` 8/8
bearings reach, 0 CUT → **identical**. Nothing sealed, the compound did not become an island.
(The 5 sealed interiors are pre-existing and unrelated.)

**Two alarms that could not see the defect they were built for:**
- The parapet reconciliation only looked one way. A manifest entry with no mesh is loud; **a mesh
  with no manifest entry is invulnerable and invisible to the check** — `fb_sbg_seg_046_001`
  shipped that way and the boot line reported a clean 80/0 over it. Now counted and named.
- No albedo threshold can separate the unfinished brassard (0.82) from the *correct* bone-white
  surgeon's mask (0.79) — so the probe was silent on a real defect. It now also reports an
  untextured surface whose material NAME still says `_white`/`_placeholder`/`_todo`/`_wip`/`_temp`.

**Also corrected:** the second-body probe could not tell a surgeon's apron (0.394 × 0.634) from a
torso donor (0.391 × 0.652) — the same box to within 2 cm — which is why `us_surgeon` read as
"two men" and three ledger rows carried half an art day that did not exist. Gated on a whole man
(1.53 × 1.71) now, in a gap where nothing lives.

**THE LEAK COLUMN CANNOT BE TRUSTED AT SINGLE-RUN RESOLUTION — and this is the finding of the
second wave.** The suite's AUDIT-12 "resources leaked at exit" check is FLAKY. Measured
2026-08-13: `test_bullet_flight`, three consecutive runs, byte-identical code →
**LEAK, LEAK, PASS.** `test_firefight_len` and `test_mission_state` read LEAK inside a full
suite run and PASS in isolation. 20 of 143 results are LEAK and that column has been read as a
standing debt register; it is partly noise.

It caught me out directly: two batched versions of the tree-break chunk rebuild appeared to move
three tests PASS → LEAK, I called it confirmed on one run each, and re-running the *reverted*
code reproduced the same leaks. The batching was never demonstrated guilty. **I reverted it
anyway** — on your content-first-optimise-later rule, because the ~960 rebuilds is a static
estimate never measured on a frame, and an optimisation with unmeasured benefit and
undemonstrable safety should not ship the week of a demo. `perf_probe` reports ms now, so the
assault frame can finally be measured; if the cost is real, batch it on the VegetationManager
side, which owns the chunk lifetime.

**CLEAN SUITE SCOREBOARD (first uninterrupted run since the audit): 103 PASS / 20 LEAK /
20 FAIL / 0 TIMEOUT, of 143.** Baseline was 106 / 14 / 23 / 1. Fails 23 → 20, the timeout gone,
and `test_squad_break` off the regression list — `test_height_authority` (water) is the only
REGRESS left. The PASS/LEAK movement is inside the noise described above.

**Still open and unchanged:** the Chinook (`chinook.tscn` has two nodes and **no seat sockets at
all**, so `door_staging_pos()` falls through to the airframe origin and men unseat inside the
fuselage — `test_seat_system` drives the Huey and does not cover it) · cover-seek stopping 4–5 m
short · the 548 character-part colliders tagged `hard_surface` · everything in §4 that needs
Blender or the bench.

---

**Written while you slept. Everything here carries a `file:line` or a measured number.**
Council record: `production/war_room/synthesis_demo_audit_2026-08-12.md` + five analyses in
`production/war_room/analysis/`.

**Nothing touched Blender, no GLB was re-exported, your game was never killed.**
Four commits, all pushed. `master` is in sync with `origin/master`.

---

## 1. READ THIS FIRST — three things you believed that are not true

**1. HOT_CAP is already 50, not 20.** `scripts/enemies/enemy_squad.gd:42`, raised 2026-07-28 by
`8074af38`. **Your planned change to 26 would have cut 24 slots.** And because `SIEGE_STRENGTH = 45`
is *under* the cap, the demo has **no cold set at all** — all 45 men run the full brain. The "33 men
read as furniture" risk you ranked as the top threat to the combat feel **does not exist**. I did
not make the change.

**2. `[FSB] 0 concave shape(s) forced double-sided` can never print 0.** `backface_collision` is a
Godot *runtime* flag and glTF cannot express it, so every export produces a non-zero count forever.
Expect **~2048**. The comment at `site_planner.gd:1402-1406` promising 0 after the re-export is
unachievable by construction. The claimed consequence — 80 broken segments, a blinded SiegeDirector
— does not hold either: that function flips one bool and renames nothing, and `siege_director.gd:66`
says outright that nothing reads a breach. **Strike that item from the checklist.**

**3. The surgeon is not drawn twice.** No duplicate spawn exists. `apron_front` is 0.634 m tall and
clears the second-body probe's `box.y >= 0.6` test at `model_actor.gd:579`, which has no upper bound
— a torso *garment* counted as a torso. One line, 30 minutes. Three ledger rows carry this as a
half-day art job and are wrong.

---

## 2. WHAT I FIXED AND PUSHED

### `b618b8f4` — five mechanical defects, and the mortar crew finally crews
- **A fourth spawn-height patch nobody had named.** `game_world.gd:522-525` re-seated the player with
  `surface_y` on every terrain-dirty flush. Cratering marks rects dirty, so a player **inside a
  hootch during the assault** was lifted onto the roof over his head. Now `floor_y`. **1 line.**
- **Adopted structures were anonymous.** NavBaker matches its prefix contracts against the *shape's
  parent* name (`nav_baker.gd:482`), and `_adopt_structure` reparents every shape onto an unnamed
  `Destructible` — so yesterday's roof cull missed **three of its five targets**, ~790 of 989 m² of
  roof still baking walkable, **including the MG bunker you just made mannable.** Fixed with
  `d.name = mi.name`.
- **Both mortar pits seated nobody.** `_arty_pits` matched `wt == "mortar"`, but the export ships
  `work_mortar_<pit>_<gunner|dropper|runner>` and the marker strip removed only one trailing ordinal,
  so it never reduced to `mortar`. **Your `mortar_gunner`/`dropper`/`runner` clips had no caller at
  all.** That is the "artillery crew built and stranded" mystery — a string-parsing bug.
- **The howitzers were always fine.** 24 `work_gun` markers resolve correctly. `gun` and `mortar` are
  kept *out* of `FSB_WORK_OCCUPATION` **deliberately** (`site_planner.gd:865-870`) because a served
  gun is a crew, not a round-robin seat. The other session's "unmapped on purpose" note was right
  about the table and did not notice the arty path was also missing them.
- **The strip now repeats.** `work_hooch_sleep_0.001` arrives as `hooch_sleep_0_001`; one strip left
  `hooch_sleep_0`, unlisted, reaching `off_duty` **by accident**. The table's own comment warns about
  exactly this. **All 487 markers now resolve** except `med_root`, which is an anchor.
  - **Correction to what the audit first told you:** 194 markers *did* land unmapped, but **187 were
    hooch billets that belong at `off_duty` anyway**. The real damage was **6 markers**, not 194.
    Waking them does not populate the compound — there is no meaningful frame cost.
- **Rockets fuzed on weeds.** `_is_bush` gated the blast budget but not `query_ahead`, so an RPG
  detonated on a 0.93 m `bush_c` instead of the man behind it. Pillar 1. 2 lines.
- **RPG-2 manifest 0.95 → 1.20.** The declared length failed the 15% `--strict` gate against a
  measured 1.1995, so the re-export that restores reload/jam **could never run**. 1.20 is the loaded
  launcher — tube plus the PG-2 on the nose, the only state the player sees.

### `e2868da2` — the four unverified systems, and the perf probe gets a GPU/CPU split
**None of the four needed flagging off. Your cut lever stays unspent.** All were 4–12 lines.
- **Mortars fired onto your end card.** The siege gate returned *before* `_next_fire` was rescheduled,
  so a three-shell volley landed within a second of `siege_ended` — on the flight of gunships that is
  supposed to be the last image.
- **The pilot had no clock, and it killed a second system.** Neither phase could end on its own;
  `_lose()` existed and nothing called it on a timer. Because `encounter_active()` suppresses the
  ambient dice, **a pilot you never walked out to silently stopped all ambient encounters for the
  rest of the run** — and it reads as "the encounters are boring", not "a system is stuck". Both
  phases now time out at 420 s.
- **A live encounter was gated by nothing.** `_try_roll` has eleven guards and refuses to open one
  during the assault; `_tick_live` ran before any check. A contact opened at 1370 s runs past 1790 s,
  through the 45-man siege.
- **~960 chunk rebuilds inside the assault.** Every felled tree called `rebuild_chunk` itself and the
  CBU beat can queue hundreds at ~1645 s. Now deferred and deduped to one per chunk per frame —
  deferred, not skipped, so every tree's `add_fell_entries` lands first.
- **`perf_probe` never measured milliseconds.** It read counters and never called
  `viewport_set_measure_render_time`, so the CPU-vs-GPU split has **never** been measured at
  `fsb_main` — `PERF_LEDGER.md` recorded that on 2026-07-26 and it was still true last night.
  **THE WALK / ONE DIG / THE BARRAGE can now be taken properly.** New `PERF MS` row per phase.

### `cc851e32` — the probe that was missing, and five poses stop being read as unaimed
- **The assert nothing had.** No test compared a gun's hip pose to its ADS pose for *scale*.
  Measured across every shipped gun: healthy spans **0.32–0.42 m** (ppsh41 0.32, m16a1 0.41, m70
  0.42); broken ones **m79 11.37, m60 35.69, shotgun 59.03**. The 1.0 m gate sits in an empty gap two
  orders of magnitude wide. The three are grandfathered and **print their span every run**.
- **`test_viewmodel_poses` is GREEN again.** Five equipment items — bandage, flashlight, handset,
  knife, m26_grenade — have no sights, so `hip == ads` is the authored answer. The stub test had been
  red on all five since the equipment shipped. Gated on your own ADR-034 convention: guns are
  `{weapon}_arms_viewmodel.tscn`, non-gun items drop the `_arms_`.
- **`ak47` and `mosin` now have real ADS poses** and left `GRANDFATHERED`. The register only shrinks.
- **Orphan probe is GREEN.** The 12 `zed_*.glb.import` were reported NEW against a ceiling of 0 — an
  alarm you would stop reading, and it would have swallowed the thirteenth. Grandfathered with the
  reason.

---

## 3. WHAT I REFUSED TO DO, AND WHY

**I did not write the weapon poses.** The audit said four weapons were wrong. **Two of them are
fine** — `m1911` hip is `(0.052, 0, -0.136)` and `m70` is `(0.02, 0, -0.15)`, small and sane. The
"55.9 m and 23.9 m off" claim came from assuming hip should *equal* the GLB rig root; it should not.
The armory ruler parks each GLB at its own station down −Z (m60 −36, m79 −12, m70 −24, colt45 −56)
and the idle clip brings it back. The genuinely broken three are M60, M79 and shotgun, and the
correct pose is **bench work** — inventing numbers would violate your own standing law. The probe
now names them every run.

**I did not touch `model_actor.gd`.** The audit claimed nine character GLBs prefix their meshes with
the unit id, defeating the donor-hiding match, and called it the "legs clipping trousers" defect.
**I checked the GLBs directly and it is false.** `vc_sapper.glb` ships `vc_sapper_joined`,
`grunt_forearm_l`, `cap_head` — exactly the names the code expects. The contract triggers and the
donors hide. **"Legs clipping trousers" remains undiagnosed** and is most likely genuine skinning, on
your side. Acting on that diagnosis would have risked making all ten civilians invisible for nothing.

**I did not remove `fb_int_` from `NAV_IGNORE_PREFIXES`**, despite your ruling that props should
become real obstacles. **`test_nav_path` now TIMES OUT at 420 s** (see below). Adding 572 collider
carves to a nav bake that already cannot finish, unsupervised, overnight, is exactly the "improvising
around a blocker at 3am" your own overnight rules forbid. **This is the first job once the bake
timeout is understood**, and it is still your ruling — I have only deferred it.

---

## 4. WHAT NEEDS YOU

| # | Item | Why it is yours |
|---|---|---|
| 1 | ~~**`test_nav_path` TIMES OUT at 420 s**~~ **RESOLVED in the second wave — see §0.** A fossil field reference, not the bake. PASS in 10.8 s. Nothing was ever wrong with FIX 0. | — |
| 2 | **Blender rename for the med/chow contract** (your soft+destructible ruling). `medical_complex` and the chow hall are single meshes with no prefix: **bulletproof, invulnerable, roofs walkable**. I added `medical_complex` to the roof-cull list; **the chow hall cannot have an entry** because its parts (`tent_roof_chowhall`, `WB_chowhall_backwall`) share no leading token. | Blender only. |
| 3 | **242 `fb_hwall_*` hooch walls are hard** while their own screens and roofs are soft. One string. | Blender only. |
| 4 | **Re-export RPD and RPG-2** — `python tools/export_all_viewmodels.py rpd rpg2`. The manifest now passes the gate. Both currently hold only `rifle_idle`; the player sees 7.0 s / 6.5 s of a frozen pose because `weapon_holder.gd:986` early-returns on a missing clip. | Your export. |
| 5 | **Re-aim M60, M79, shotgun on the bench.** Spans 35.69 / 11.37 / 59.03 m. The M60 is defect B5 — the mounted MG. | Bench only. |
| 6 | **The M72 LAW has no viewmodel at all.** `m72_law.tres` has `model_path = ""` and `m72_law_fp.glb` was never exported, which is why `test_viewmodel_contract` is red. The manifest declares `RIG_M72_LAW`. | Blender export. |
| 7 | **Medic brassard still has no red cross** — material still named `medic_brassard_white`. The 8/8 re-export nudged its albedo to 0.86, just under `WHITE_ALBEDO_MIN = 0.9` (`model_actor.gd:627`), **so the probe now stays silent on an unfixed defect.** The *mask* at 0.86 is chosen bone-white and is correct. | Blender + a threshold nudge. |
| 8 | **Take the three perf poses** with nothing else running. `PERF MS` rows now exist. | Your eyes, your rule. |
| 9 | **`START_HOUR` pacing.** DAY snaps at **T+47 s**, 37 s after the squad moves out, while you are still in the wire. `5.733` lands it at T+120 s but moves the night seam. You ruled "leave it and judge by eye" — flagged so you watch that beat. | Your call. |

---

## 5. THE SUITE

**Baseline, one uninterrupted run before the night's work: 106 pass / 14 leak / 23 fail /
1 timeout, of 143.**

**I do not have a clean AFTER scoreboard, and I am not going to pretend otherwise.** Two attempts
to re-run the full suite were cut off at the harness's ten-minute cap, and **both died in the same
place — `test_nav_path` burning its full 420-second box.** One test is eating 70% of the budget for
a whole suite run. Until that is fixed, nobody on this project gets a full green-to-green comparison,
which is a second, quieter cost of item #1 below.

**What I validated directly instead**, after every change landed: `test_fossils` PASS ·
`test_trunk_ring` PASS · `test_veg_cover` PASS · `test_world_boot` PASS · `test_worldbuild_phase1` PASS ·
`test_support_fire_bench` PASS · `test_viewmodel_poses` **FAIL → PASS** · `test_viewmodel_sync_contract`
PASS · `test_demo_planner` LEAK (pre-existing AUDIT-12, leaked before the night too).
**No test that was green went red.**

Known, and not caused by this session:
- **`test_height_authority` REGRESSED** — but 9 of its 10 checks pass and the single failure is
  **water: "water surface sits 26.71 m off the carved bed (tol 2.50)"**. That is your known
  water-is-a-geometry-defect item surfacing in the harness, not a spawn-height problem.
- **`test_squad_break` REGRESSED** — `Condition "!is_inside_tree()" is true`, a use-before-parenting.
- **`test_seat_system` FAILS** — very likely the Chinook stranding its passengers (handoff §2a):
  `chinook.tscn` has two nodes and **no seat sockets at all**, so `door_staging_pos()` falls through
  to the airframe origin and men are unseated inside the fuselage.
- 14 LEAK results are the long-standing AUDIT-12 class.

---

## 6. STILL OPEN FROM THE AUDIT, NOT DONE

- **Cover-seek stops 4–5 m short** (not 10). Three additive terms: `COVER_BLOCKER_MAX_M` 2.5
  (`enemy_base.gd:133`), arrival epsilon ~1.5 (`:1834`), 3.0 m nav restake dead-band
  (`nav_router.gd:118`). Candidates are a ring around the man, never a wall *face*. **Proof it is
  real:** the leap clip is gated on `_wall_within(1.2)`, so a short man silently skips his arrival
  animation. The 8/07 fix IS in the code — it fixed bogus cover *selection*, a different bug, and was
  closed against the wrong defect. Right fix: snap to `hit.position` in `cover_blocked_from`
  (`enemy_base.gd:2137-2145`). **1–2 h**, but it moves men closer to every wall the siege was tuned
  against — worth doing while you can watch it.
- **548 character-part colliders** tagged `hard_surface` — men who stop rounds with no hit reaction
  *and carve navmesh*.
- **A stray 81st parapet segment** (`fb_sbg_seg_046_001`) sits invulnerable among 80 destructible
  twins, and `absent=0` structurally cannot see it.
- **Fossils not yet cut:** `EXCLUDE_AIR_TRAFFIC` / `EXCLUDE_AMBIENT_WAR` (`demo_game.gd:26-27`)
  exclude nothing — read only by the boot print; `tree_break_system.promote()` has zero callers.
- **The destructible-export skill doc drift was corrected** — 14 pointers rewritten, three
  substantive errors, two new failure modes.
