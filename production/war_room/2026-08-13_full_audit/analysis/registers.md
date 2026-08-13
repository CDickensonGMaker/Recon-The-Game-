# REGISTER AUDIT — defect registers & ratchets (2026-08-13 full audit)

Auditor beat: the grandfather registers, the viewmodel defect register, the --strict gate,
the AUDIT-12 leak class, PERF_LEDGER, and the two owner todo docs vs today's commits
(napalm scale `f6b323a6`, nav-truth `a5d077a7`). AUDIT ONLY — nothing was changed. Every
claim below carries a pointer or a measurement taken tonight. Zombie-protected entries
(Summoner standing order) were counted, never judged.

---

## 1. The grandfather registers — counts, ceilings, expired reasons

| register | count / ceiling | verdict |
|---|---|---|
| `tests/fossil_baseline.json` | 27 / 27 | CONSISTENT. 24 zombie (protected). 3 non-zombie re-verified dead tonight. |
| `tests/test_only_liveness_baseline.json` | debt 11 / 11 · seams 17 / 17 | CONSISTENT — but **4 debt entries are EXPIRED** (below). |
| `tests/parity_baseline.json` | 4 / 4 | VALID. `perf_probe.gd:205-217` carries exactly the four declared deviations and the default arm restores ship (`:216-217`) — RULE B holds. |
| `tests/test_health_baseline.json` | 2 / 2 | VALID. `tests/probe_gun_streams.tscn` + `tests/probe_perf_decay.tscn` both exist as probe_*; the gun_streams thread-hang reason (2026-08-07) still applies. |
| `tools/doc_pointer_baseline.json` | measured tonight: unpointered **0** / 12 · broken **94** / 97 | PASS both. **12 + 3 of unbanked ratchet ground** (below). |
| `tools/orphan_baseline.json` | 12 / 12 | All 12 are `zed_*.glb.import` — zombie-protected, not judged. |
| `tools/retired_refs_baseline.json` | — / 0 | Clean. The ideal register: empty at ceiling zero. |
| `tools/tool_path_baseline.json` | 53 / 53 (sum of per-file counts, added tonight) | Exact. |
| `tests/art_contract_baseline.json` | n/a | Not a ratchet — measured dy/dz contract values for 8 civ models. No ceiling, nothing to audit. |

### 1a. The three non-zombie fossils — reasons still valid
- `scripted_sequence.gd|signal|sequence_bark` — emitted at `scripts/missions/scripted_sequence.gd:276`, **connected nowhere** repo-wide. Still a fossil.
- `model_actor.gd|func|ragdoll_bone` (`scripts/visuals/model_actor.gd:950`) and `wake_ragdoll` (`:958`) — zero callers. Class UNFINISHED, not FOSSIL: the corpse-drag roadmap seed (`production/CALEB_TODO_7_22_updated.md:387-390`) names them as the built half of an unbuilt mechanic. Correctly held.

### 1b. DRIFT — four liveness debt entries have EXPIRED (production callers exist now)
The register says 11 debt; reality is **7**. All four went live this cycle:

| entry | production caller today |
|---|---|
| `scripts/vehicles/seat_system.gd\|board_squad` | `scripts/vehicles/heli_lift.gd:376` |
| `scripts/vehicles/seat_system.gd\|unseat_all` | `scripts/vehicles/heli_lift.gd:282` |
| `scripts/missions/friendly_patrol_group.gd\|is_pinned` | `scripts/world/ambient_encounters.gd:388` |
| `scripts/missions/friendly_patrol_group.gd\|living_count` | `scripts/world/ambient_encounters.gd:381,440` |

`heli_lift.gd`'s own header (`:3-6`) says it exists to be the consumer of exactly those seat
functions, and the ambient-encounters decree wired the patrol observers. The probe already
knows: `tests/test_test_only_liveness.gd:120` prints *"N debt entr(ies) now have production
callers - run --write-baseline to bank it"* on every run, and nobody has banked it. Not a
hidden defect — the probe cannot be fooled by it — but the ratchet is running 4 slack, and
"bank the win" is this project's own law. **Action: run `--write-baseline` (shrink-only by
construction), debt 11 → 7.**

Remaining 7 debt entries spot-verified still test-only tonight: `set_player_route`
(`field_director.gd:1224`, awaits patrol-contract P2), `scripted_sequence.abort`,
`nav_baker.queue_site` (`:190` — production uses `queue_sites`/`queue_site_with_colliders`),
`road_network.total_length` (`:362`), `site_planner.stamp_lz` (`:2172`),
`jungle_patch_layer.T_CLEAR` (`terrain/vegetation/jungle_patch_layer.gd:18`),
`water_system.get_water_level_at` (`terrain/water/water_system.gd:511` — the wade gate has
still never fired; matches the 8/12 water decree and tonight's nav-truth water scoping).

### 1c. DRIFT — doc-pointer ceilings hold unbanked ground
Probe run tonight (read-only): **unpointered 0 vs ceiling 12; broken 94 vs ceiling 97.**
The unpointered class is at ZERO — lowering that ceiling to 0 locks the class out forever,
and leaving it at 12 leaves room for twelve new unpointered claims to enter without a
grandfather reason. The probe itself says so on its PASS line. **Action: bank both (12→0,
97→94).**

### 1d. NOTE — CLAUDE.md's fossil count is of-its-time
CLAUDE.md (FOSSIL LAW section) still says the baseline reads "`ceiling` 3, `count` 3, as of
2026-07-31". It is 27/27 since the 2026-08-12 zombie grandfather. The line carries a date
banner so it is legal under the POINTER LAW, but CLAUDE.md is injected into every session —
correct it on next touch (NO MORE DRIFT: correct on contact).

---

## 2. The viewmodel defect register

### 2a. ADS `GRANDFATHERED` (tests/test_viewmodel_poses.gd:30) — 3 remain, all HIS
`["m1911", "rpd", "rpg2"]`. Verified in the .tres tonight: all three still carry the literal
placeholder `ads_position = Vector3(0, 0.05, 0.08)` (`m1911.tres:39`, `rpd.tres:36`,
`rpg2.tres:38`). Real ADS poses are bench aiming (Ctrl+S on the bench) — HIS side, no code
can produce them. `ak47` and `mosin` correctly left the list 2026-08-13; the register only
shrank. Non-gun items (bandage/flashlight/handset/knife/m26) are correctly exempt via the
`_arms_` convention (`:45-46`).

### 2b. SPAN `SPAN_GRANDFATHERED` (:26) — m60 / m79 / shotgun, all HIS
Spans recomputed from the current .tres tonight: **m60 35.7 m** (`m60.tres:39-40`),
**m79 11.4 m** (`m79.tres:38-39`), **shotgun 59.0 m** (`shotgun.tres:43-44`) — unchanged,
each still carrying an armory-ruler station in its hip pose. The suite prints all three
spans every run (`test_viewmodel_poses.gd:83`) and auto-detects the fix (`:86-87,90-91`).
Re-aim on the bench = HIS. Register healthy.

### 2c. test_viewmodel_contract — red is REAL and is FOUR guns wide, all HIS-side
Confirmed unchanged and enumerated by direct inspection tonight:
- **m72_law** — `data/weapons/m72_law.tres:38` `model_path = ""`, no `m72_law_fp.glb` on
  disk. Never authored/exported. HIS (Blender). Unchanged, exactly as registered.
- **rpg7** — `data/weapons/rpg7.tres:37` `model_path = ""`, no `rpg7_fp.glb` on disk, yet
  the manifest declares it under `guns` with 6 clips. **The morning report's item 6 names
  only the LAW; rpg7 fails the same load check** (`test_viewmodel_contract.gd:34-36`). HIS.
- **rpd + rpg2** — GLBs exist but hold **only `rifle_idle`** (read out of the glb JSON chunk
  tonight) against 6 declared clips each → clip-missing failures (`:44-47`). The blocker
  (RPG-2 0.95 vs measured 1.1995 failing the 15% gate) was fixed in `b618b8f4`
  (manifest 1.20), so `python tools/export_all_viewmodels.py rpd rpg2` is unblocked and
  listed as HIS export (morning report §4 item 4). Not silently-fixable by code — the fix
  is a driver run against his .blend, held HIS-side by the standing Blender-session law.
- `car15.tres:33` also has `model_path = ""` but car15 is not in the manifest — out of the
  contract's scope, correctly silent.

### 2d. DEFECT — the standing red is registered NOWHERE the machine reads
`$KnownRed` in `run_all_tests.ps1:33-37` is **EMPTY** ("kept empty rather than deleted so
the next known-red test has a home"). So `test_viewmodel_contract`'s four-gun red rides as
a bare FAIL among ~20 every run. Consequence: **a NEW contract break — m16 losing a clip in
a re-export, a MuzzlePoint dropped — produces zero scoreboard delta**, because the test is
already red. The runner's own doctrine ("the list is the scoreboard, not an excuse", with
the XPASS trip forcing removal on fix) says this red belongs in `$KnownRed`; today it lives
only in prose (morning report §4). The claim "this defect is guarded" is only half true:
the defect is *reported*, but regression inside the same test is *not guarded*.
**Severity: DEFECT (register gap).**

---

## 3. tools/viewmodel_manifest.json --strict state

- The driver hardwires the gate: `tools/export_all_viewmodels.py:43` passes `--strict` on
  every export (`export_viewmodel_clips.py:35,:114` pre-flight fails before writing a GLB).
  So **every GLB on disk passed the gate at its export time**: 12 of 14 manifest guns have
  `_fp.glb` (m16, ak, ppsh, m14, rpd, colt45, m60, mosin, m70, ithaca, m79, rpg2) plus all
  5 items + flashlight. **m72_law and rpg7 have never been through the gate** (no GLB).
- **`_debt` entries: NONE remain.** The last one (M14 stranded fittings, named in
  `production/OVERSEER_CHARTER.md:132` as of 2026-07-26) was discharged by
  `tools/fix_m14_fittings.py` + re-export (ART_Track_Log 2026-07-26 entry: validator PASS,
  `markers_under_gun: true` restored) and the key was removed rather than zeroed. The
  register is empty and honest; the charter line is dated and of-its-time.
- Two length declarations are deliberate, documented, and should not be "fixed": ithaca
  `real_length_m` 1.304 = the 1.30× Caleb-requested size (manifest `_note`), rpg2 1.20 =
  the loaded launcher (`_length_note`).

---

## 4. AUDIT-12 leak class — does anything NEW convict on the LEAK column?

**No. Nothing new depends on it, and the one attempted conviction this week was self-caught.**
- The runner cannot gate on it: LEAK requires `$ok` (exit 0, zero fatal lines) and never
  increments `$failed` (`run_all_tests.ps1:162,181,205,219`); a Graduated test cannot be
  marked REGRESS off a LEAK (`:177-182` — REGRESS fires only on `-not $ok`).
- `tools/overnight_suite_chunk.ps1:19` matches "LEAK" only to log the result line — no gate.
- The tree-break batching episode (2026-08-13 night): three tests read PASS→LEAK, this was
  first called "confirmed", then the reverted code reproduced the same leaks — the batching
  was never demonstrated guilty and the revert stands on content-first grounds instead
  (`2af46803`, morning report §0). The register carries the correction, and the
  "never convict on one reading" law is now in the START-HERE handoff and memory.
- DRIFT (one line): `run_all_tests.ps1:92` still says benign-leak results are "tracked in
  Beads" — beads was retired 2026-07-22. The leak debt actually lives in the AUDIT-12
  memory + morning report. Correct on next touch.

---

## 5. PERF_LEDGER.md — the newest entry is no longer the whole truth

- Newest entry is **2026-07-26** (the FPS deep dive, "NO NEW FPS ROW"); the file contains
  **zero 2026-08 content** (grepped).
- The probe DID gain the split: `tests/perf_probe.gd:50-53` + `:104-106`
  (`viewport_set_measure_render_time`) + `:152-158` (gpu/cpu sampling) + the `PERF MS` row
  per phase (`:300-301`), landed in `e2868da2` (2026-08-13 morning). The probe's own header
  (`:47-49`) says the gap "stood unfixed until 2026-08-13".
- **No number has landed.** The ledger has no new row; the backlog's 2026-08-13 rows are
  VFX sizes and a nav bake-ms figure, not frame milliseconds; morning report §4 item 8
  assigns "take the three perf poses" to HIM (windowed, his machine — headless renders
  fiction, per the ledger's own contract). So the honest answer to the brief's question:
  **the instrument gained the rows; no measurement exists yet; the ledger does not say the
  instrument was fixed.**
- DRIFT: the ledger's standing finding #1 (`PERF_LEDGER.md:968`: "perf_probe.gd reports NO
  MILLISECONDS... never calls viewport_set_measure_render_time") is now false as a
  statement about the instrument (still true that fsb_main's CPU/GPU split has never been
  *measured*), and its `:110/:112/:114` pointers are stale against the rewritten probe.
  By the ledger's own no-drift discipline it needs a one-line instrument note dated
  2026-08-13. The measurement contract prerequisite at `:1108` (restore
  `renderer/rendering_method` to project.godot before any bench) should be re-verified at
  that first run.

---

## 6. Owner docs vs this week's shipped work — entries to CLOSE (not edited by me)

### production/CALEB_TODO_7_22_updated.md (last commit 2026-08-04)
1. **§0b "YOUR NEW ART IS IN NO COMMIT — 531 untracked files"** — stale/complete. Working
   tree tonight: 8 untracked files, none of them the village set or `fsb_main_v3`
   (`git status --porcelain`). Close it.
2. **§2 HELICOPTER FLESH-OUT (all four boxes) + NEXT-UP #3 "HUEYS"** — completed by Huey v3
   (ART_Track_Log 2026-08-05: interior built, all 11 seat markers placed AND oriented incl.
   the never-before-existing `seat_pax_7`, M60 door mounts corrected to the facing law,
   nose +Y) and the 8/12 ship. Close; only his-eye passes remain.
3. **§3 items** — all four shipped and wired: tunnel-rat flashlight (`flashlight_fp.glb` +
   `flashlight.tres:12`), M26 hold+export (`m26_grenade_fp.glb`, poses test green as
   non-gun), "engine wiring for the 7 new viewmodels + shotgun.tres" (every shipped gun has
   its `*_arms_viewmodel.tscn` wired in its .tres; `shotgun.tres:40`), FP handset raise
   (`handset_fp.glb`, authored 2026-07-30 per manifest `_note`). Close all four.
4. **§6 patrol-loop verification checklist** — superseded as the session gate by the
   2026-08-06 EA/demo ruling (R4 deferred post-launch). Mark deferred, not open.
5. **NEXT-UP #4 NVA variants** — bodies shipped 2026-07-29 (`make_nva_variant.py`, 7 GLBs),
   gear library complete + spawner parity verified end-to-end 2026-08-08 (35 GLBs, gate 0
   failures). Still genuinely open inside it: the ZPU gunner. Close the model half.

### production/ART_Track_Log.md (last commit 2026-08-08)
6. **§4 "Ordnance mounting — 8 props exist, none attached to the F-4 or dropped"** — dead
   claim: the 9-drop napalm run is a shipped demo beat and its sizes were re-ruled today
   (`f6b323a6`: `cas_airplane.gd`, ladder re-anchored to canopy, nine drops × ~60 m). Close/correct.
7. **§3 "I want a new audit of what's there... 300+ animations"** — discharged 2026-08-02
   (orphan-clip War Room: 163 clips measured, 32 orphans classified, wiring shipped;
   library now 232 clips per `aba5ca53`). His §3 cover-seek observation ("taking cover a
   good 10 m before the wall") is the diagnosed cover-seek defect — measured 4-5 m, landing
   plan written, PARKED for his next watched session (nav-truth synthesis). Note it as
   diagnosed, not unknown.
8. **§5 "Building interiors for firebase, about half done"** — stale: 1,144 `fb_int_` nodes
   with 572 colonly twins shipped and now enter the bake (his furniture ruling implemented
   + verified 2026-08-13, `d46f2225`), plus the medical complex and chow hall. Village
   interiors remain HIS.
9. **§5 bunker firing slits "yet to get inside a bunker and shoot out of it"** — the
   verification half moved: **37/37 bunker fire points measured reachable**
   (`tools/probe_bunker_entry.tscn`, `f93e3e44`) and the entry blocker was reclassified
   physics-not-nav; nav-truth then cut capsule-blocked routes 19→4. His in-game shot from a
   slit is still owed — but the doc's framing predates all of it.

### production/MORNING_REPORT_2026-08-13.md — same-day staleness in the START-HERE doc
10. **§6 "Fossils not yet cut: `EXCLUDE_AIR_TRAFFIC`/`EXCLUDE_AMBIENT_WAR`...
    `tree_break_system.promote()` has zero callers"** — all three were resolved by
    `452ed393` at 01:08 the same night (EXCLUDE_* wired as real levers; promote buried —
    the function no longer exists in `tree_break_system.gd`, verified tonight). The
    handoff tells the next session to cut fossils already cut.
11. **"NEXT SESSION" open-items list** — "548 character-part colliders" (refuted: measured
    144, made soft in `a5d077a7`) and "the Chinook has no authored seat markers" (CH-47
    layout measured and keyed off `tandem_rotor`, `test_seat_system` PASS, same commit)
    were closed hours after the report was written. Only the napalm addendum was appended;
    the nav-truth wave was not. Anyone starting from §NEXT-SESSION re-does dead work.

### Loose ends found on disk while auditing (nobody's register holds them)
12. **DEFECT:** `assets/us/props/interior/fb_office_chair.glb` is COMMITTED but its texture
    `fb_office_chair_fb_canvas.png` is UNTRACKED (git status tonight). The sibling props
    (`fb_bench` etc.) track their `_fb_*.png` textures — a fresh clone gets an untextured
    chair. One `git add`. (Single-disk-risk class.)
13. NOTE: `tools/probe_mound_in_walk.gd/.tscn` untracked — a stranded probe from the
    nav-truth session. Commit or delete; an uncommitted probe is invisible to the suite and
    to the next session both.

---

## Severity roll-up

- **SHIP-BLOCKER:** none originating in the registers. (The demo gate re-opening after the
  honest re-bake is already recorded in DEMO_SHIP_BACKLOG and is the council's item, not a
  register defect.)
- **DEFECT:** §2d contract-test standing red unregistered in `$KnownRed` — new breaks on a
  4-gun-red test are invisible · §6.12 committed GLB with untracked texture.
- **DRIFT:** §1b four expired liveness debt entries unbanked (11→7) · §1c doc-pointer
  ceilings 12/97 vs measured 0/94 unbanked · §5 PERF_LEDGER's newest entry now misstates
  the instrument, no 8/13 note · §6.10-11 morning-report same-night staleness ·
  §4 runner comment "tracked in Beads" · the named CALEB_TODO/ART_Track_Log closables.
- **NOTE:** §1d CLAUDE.md fossil 3/3 dated line · rpg7 unnamed in the morning report's
  contract-red item · tool_path 53/53 exact · probe_gun_streams hang reason unchanged.
