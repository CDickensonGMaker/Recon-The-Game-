# OVERNIGHT PLAN — 2026-08-06 → 08-07

Companion to `production/AUDIT_2026-08-06.md`. Every item below cites the audit finding it
closes. **Nothing here needs the Summoner awake.** Anything that does is in §6, parked.

**Standing constraints this plan obeys**
- His running game is never killed. No Godot instance is attached to; the suite runs headless in its own process.
- **No Blender.** His live window is his; Blender work is his hands or a daytime agent (§6).
- PLAYTEST R4 is still the session entry gate — so this plan is **repairs, deletions, ratchets and instruments**, not gated feature work.
- Fossil law: every replacement buries its predecessor in the same change.
- Verification law: no item closes without a probe, a measurement, or a diff. "Looks right" closes nothing.

---

## WAVE 0 — 15 minutes, do before anything else

| # | Work | Closes | Gate |
|---|---|---|---|
| 0.1 | `git add -A; git commit; git push`. 44 uncommitted paths: 20 zombie `.blend`/`.glb` deletions, 6 modified textures, `vc_nva_dresser.gd`, `nva_vc_soldiers.blend`, `assets/nva_vc/props/`, 3 zed JSON logs. | AUDIT P0-1 | `git status` reads "up to date with origin". **If this fails, STOP the overnight** — every wave below writes code. |
| 0.2 | Tag the pre-overnight commit (`pre-overnight-2026-08-06`) so the whole night is one revertible range. | — | tag exists |
| 0.3 | Run the full suite headless, capture to `test_results/suite_2026-08-06_pre.log`. | AUDIT P0-2 | a number exists. This is the **baseline every later wave is diffed against** — do not skip it because it is slow. |

> **If 0.3 comes back redder than 101/18/14 (the last recorded figure, 2026-07-27), the night's
> job changes: fix the suite, run no other wave.** A red baseline makes every "still green"
> claim below meaningless.

---

## WAVE 1 — the drift that costs nothing to fix (≈1h)

Mechanical, low-risk, each one a small diff.

| # | Work | Evidence | Verify |
|---|---|---|---|
| 1.1 | **One structure-HP table.** Promote `site_planner.gd:1553-1557` to the single authority; `fire_support_bench.gd:49-54` and `ai_stress_arena.gd:75-77` import it. Reconcile the two entries that differ: bench has `bwire_card`/60 and `fb_sbg_seg_`/140 that site_planner lacks; site_planner has `fb_sleeping_bunker_i`/260 that bench lacks. **Union them, do not drop either.** | AUDIT §3 LOOSE | `test_destructible`, `test_support_fire_bench`, `test_siege` still green vs 0.3 |
| 1.2 | **`civilian_deaths` into `_base_result()`**; delete the hand-patch at `field_director.gd:210`. | AUDIT §1.5 / §3 | new assert in `test_patrol_aar.gd`: bank a patrol with a civ death, read the key back non-zero |
| 1.3 | **`on_atrocity_witnessed`** — implement on `Civilian` or delete the call at `player.gd:249-250`. Recommend: implement, it is 6 lines and it feeds 1.2's number. | AUDIT §3 | probe: shoot a corpse in view of a civ, assert `state.civilian_deaths` moves |
| 1.4 | **Delete `site_planner.gd:140 _is_soft_cover()`** — one self-reference, zero callers. | AUDIT §3 ORPHANED | grep returns 0; suite green |
| 1.5 | **M-2 · world structures get HP — REDESIGNED, see below.** The decree's version is a no-op. | AUDIT T-2 | see 1.5 note |

### 1.5 note — M-2's premise is wrong, and shipping it as written would be a silent no-op

The 8/5 decree says: *"call `_wire_structure_destructibles`/`_adopt_structure`
(`site_planner.gd:1561-1615`) from `place_structure` (`:162`). Matches by mesh-name prefix, no
Blender re-export. Straight lift."*

**It is not a straight lift.** `_wire_structure_destructibles` matches against
`FSB_STRUCTURE_KINDS` — `fb_bunker_fighting_i`, `fb_bunker_mg_i`, `fb_sleeping_bunker_i`,
`fb_tower_i`, `fb_sandbag_stack_i`. The models `place_structure` actually receives are named
`nha_tranh_01`, `nha_san_02`, `dinh_01`, `chua_01`, `sandbag_bunker`, `observation_tower`,
`ancestor_tomb_01` (`collision_table.gd:12-76`). **Not one of them begins with `fb_`.**

Wiring the call as written compiles, runs, logs nothing, and changes nothing — while reading in
the backlog as "world destruction: done." That is the exact defect class this audit exists to
catch.

**Corrected design (do this instead):**
1. Add a **world-side kind table keyed by CollisionTable model name**, not by `fb_` prefix — `nha_tranh_*` → hootch/soft, `sandbag_bunker` → bunker 260, `observation_tower` → tower 180, etc. `place_structure` already has `model_name` in hand at `:166`.
2. **`place_structure` builds a plain `StaticBody3D` (`:169`); `Destructible` IS a `StaticBody3D`.** Build a `Destructible` directly when the model has an HP entry — far cleaner than `_adopt_structure`'s reparent dance, which exists only because the firebase meshes arrive pre-parented inside one GLB.
3. **WATCH THE GROUP COLLISION.** `Destructible._ready()` (`destructible.gd:29-30`) adds `soft_cover`/`hard_surface` off its own `kind`, and `place_structure` calls `tag_ballistics()` off `CollisionTable.is_soft()`. Two authorities on one node. Resolve **before** writing the code — one of them must yield, and the answer is probably that `Destructible` should not self-tag when a placer has already tagged it.
4. Gate: a village hootch must still be shoot-through **after** it becomes a `Destructible`, and destroyed rubble must drop **both** groups (`destructible.gd:86-87` already does).

**Effort is now medium, not small, and item 3 is a genuine design decision.** It stays in W1
only if the group conflict resolves cleanly; otherwise it moves to its own wave with a probe.

---

## WAVE 2 — the 517-line fossil (≈45m)

| # | Work | Evidence |
|---|---|---|
| 2.1 | Delete `scripts/missions/mission_trigger.gd` (194 ln), `scripts/missions/scripted_sequence.gd` (323 ln), `tests/test_scripted_events.gd`/`.tscn` and their `.uid` files. ADR-029 deleted the loop these served; the only external references are each other and that one test. | AUDIT §3 ORPHANED |
| 2.2 | **Shrink both registers in the same change.** `tests/fossil_baseline.json` loses `scripts/missions/scripted_sequence.gd\|signal\|sequence_bark` → count/ceiling 3→2. `tests/test_only_liveness_baseline.json` loses `scripted_sequence.gd\|abort` from `debt` (11→10) and `scripted_sequence.gd\|is_running` from `seams` (14→13). **Use `--write-baseline`, never a hand-edit** — the probes audit count/ceiling before consulting the register. | CLAUDE.md:322-328 |
| 2.3 | Re-run `test_fossils` and `test_test_only_liveness`. Both must pass at the *new lower* ceilings. | verification law |

**Do NOT touch in this wave:** `vc_nva_dresser.gd` (§4 — live work, not a fossil) and
`zombie_audio.gd` (§6 — needs his ruling).

---

## WAVE 3 — VC/NVA dressing: finish the third leg (≈2h)

**This is the correction to the audit.** The audit called `vc_nva_dresser.gd` "unwired new
work." It is narrower and better than that: the dresser is *complete*, and **three specific
things are missing around it.** The wider finding is worse:

> **`EnemyBase` has no dresser call at all.** Allies dress at `ally_base.gd:398`, civilians at
> `civilian.gd:262`, zombies at `zombie_wave_director.gd:158`. **Enemies dress nowhere.**
> Every VC and NVA man in the game today wears the face he was exported with. All 14 GLBs and
> all 14 `*_face_atlas_v2.png` are on disk — the art is done and the game never slides it.

| # | Work | Evidence | Verify |
|---|---|---|---|
| 3.1 | **Emit `assets/nva_vc/characters/vc_nva_manifest.json`.** `VcNvaDresser.MANIFEST:29` points at it; `Test-Path` = **False**, so `faces_for()` silently returns `FALLBACK_FACES:32-34` — row 6 only, **10 faces for the entire enemy force**. Emit `face_pools` from the builder, per-unit, across the whole 10×7 atlas. | `vc_nva_dresser.gd:29, 68-94` | `manifest()` non-empty; `faces_for("nva_officer")` ≠ `faces_for("vc_guerilla")` |
| 3.2 | **Write `scripts/visuals/vc_nva_randomizer.gd`**, same shape as `grunt_randomizer.gd` and `zombie_randomizer.gd`: `roles()`, `is_dressable()`, `dress_actor()`, `spawn()`, `next_bench_seed()`, `reset_bench()`. This is the missing seam — the dresser has no wrapper, which is why nothing calls it. | `zombie_randomizer.gd:50` is the closest template | new `tests/test_vc_nva_dressing.gd` mirroring `test_ally_dressing.gd` |
| 3.3 | **Call it from `EnemyBase`**, at the point `ally_base.gd:389-398` calls its own. Guard with `is_dressable(ma.unit)` so a unit without art is untouched. Seed from the mission RNG so a seed reproduces the same force (`vc_nva_dresser.gd:97`). | `ally_base.gd:380-398` | spawn 12 `nva_regular`, assert ≥8 distinct `uv1_offset` values |
| 3.4 | **Clean up the US-side leak:** `test_ally_dressing.gd:87` asks `GruntRandomizer.is_dressable("vc_guerilla")`. Once 3.2 exists, VC belongs to the VC randomizer. Move or delete that assertion. | AUDIT drift class | suite green |
| 3.5 | Run the dresser's own two warnings as a gate: `[VCNVA] %d skin material(s) do NOT sample the face atlas` (`:171`) and `no atlas surface found to slide` (`:176`). **A clean run must print neither.** If either fires, that body needs the face/skin merge pass — log which unit and STOP; that is Blender work, §6. | `vc_nva_dresser.gd:170-177` | zero warnings across all 14 units |

> **Headgear caution.** `_rehang_headgear:199-251` adds a `BoneAttachment3D` named
> `HeadgearSocket` per man and re-parents the mesh. Confirm it runs **once** per actor —
> a double-dress would hang two hats. Add the idempotence assert to 3.2's test.

---

## WAVE 4 — the doc ratchets (≈1.5h, zero gameplay risk)

`python tools/probe_doc_pointers.py` currently **exits 1**. Getting it green is the cheapest
drift kill in the repo, and CLAUDE.md:346-366 makes it law.

| # | Work | Evidence |
|---|---|---|
| 4.1 | **Renumber `ADR-035-the-route-the-pencil-and-the-hunters.md` → ADR-037.** 037 is free. Update every citation. Open since 2026-07-28. | AUDIT §1.4 |
| 4.2 | **`GAME_GUIDE.md:401,404`** — remove the ADR-024 and ADR-027 index rows (no such files). **`:408`** — "31 ADRs" → the real count. | AUDIT §3 PHANTOM |
| 4.3 | **Drive broken pointers down from 97.** `ADR-011` (16) + `ADR-012` (13) = 30% of the total and both name the same dead file, `mission_director.gd`. Repoint to `field_director.gd` where the behaviour actually moved, or mark the line as of-its-time with a date banner. **Then `--write-baseline` the ceiling down.** Target: under 60 by morning. | AUDIT §1.3 |
| 4.4 | **Clear the 3 over-ceiling unpointered assertions** so the probe exits 0. Cheapest three of the 15 in `README.md`(4) / `DESIGN.md`(3) / `AGENTS.md`(1) / `CHANGELOG.md`(1). Do **not** raise the ceiling. | AUDIT §1.3 |
| 4.5 | **Mark the four already-fixed items in `DEMO_SHIP_BACKLOG.md`'s migration decree** — M-1 (ceiling is 400, `damage_system.gd:98`), M-5 (restored, `ai_stress_arena.gd:2083-2085`), M-6 (hook deleted, 0 hits), and the `post_anchor` half of the ruling-7 blocker (0 hits). A drift warning that has itself drifted. | AUDIT §3 DRIFT |
| 4.6 | **Correct the defensive-zone claim** — the backlog says full-game integration is "not done"; `garrison_defender.gd:64-65,175-176` does it. Only the **enemy** side is absent. | AUDIT §2 |
| 4.7 | **`OVERSEER_CHARTER.md §8/§10.3`** still mandates driving `bd`, which `CLAUDE.md:401-408` retired and forbids. Repo law wins. | self-reported, uncorrected |

---

## WAVE 5 — instruments, if the night still has hours (≈1h)

Not fixes — the measurements that price the *next* session. All three are named in the 8/5
decree and none has ever been run.

| # | Probe | What it settles |
|---|---|---|
| 5.1 | **THE WALK** — zero new code, walk the shipped AO and log frametime. | The first honest jungle-sightline number this project has ever had (`PERF_LEDGER.md:968-975`). |
| 5.2 | **ONE DIG** — time a single crater end to end. One crater = a 256m chunk rebuild, 4,225 verts, ~24,576 `SurfaceTool` calls, synchronous. Likely the direct cause of *"its def laggy with everything going on."* | Whether the crater path needs a cheaper dig. |
| 5.3 | **THE BARRAGE SPIKE** — the standing ADR-031 gate, open since 2026-07-25. | Whether destruction can ship at all. |

Write results to `PERF_LEDGER.md` with the date banner. **Measure only — change no value.**

---

## WAVE 6 — SAVE/LOAD INVESTIGATION (his ask, added 2026-08-06 22:35)

The audit read save/load statically and called it "fully-wired." A 5-minute probe already
found **two of GAME_GUIDE §4.7's three named gaps still open**, one of them a bug class that
has already cost him real money in another project. This wave is an investigation with a
report, not a rewrite — but 6.1 is a fix, and it is small.

| # | Finding (already confirmed) | Evidence |
|---|---|---|
| **6.1** | **WRITES ARE NOT ATOMIC.** `save_game()` opens the real slot path `FileAccess.WRITE` and `store_string`s straight into it. No temp file, no rename, no `.bak`. **A crash or power loss mid-write destroys the save it was writing** — and `AUTOSAVE_INTERVAL_S = 30.0` means it does this every 30 seconds of play, to slot 8. This is the **Viper `state fsync crash` bug class verbatim** (NUL state file after power loss). GAME_GUIDE §4.7 has listed "atomic writes" as a need since 2026-07-25. | `save_manager.gd:99-107`, `:20-22` |
| **6.2** | **NO FUTURE-VERSION REJECTION.** `load_game` migrates when `version < SCHEMA_VERSION` (`:177-178`) but a save from a *newer* build falls straight through and is applied as-is. `SaveData.is_valid()` checks `version >= 1` with **no upper bound**. GAME_GUIDE §4.7 names this too. | `save_manager.gd:177`, `save_data.gd:8,43` |

**FIX 6.1 THE STANDARD WAY:** write to `<slot>.tmp`, `flush()`, close, then rename over the
real path; keep the previous file as `.bak` and self-heal from it when the primary fails to
parse. That is the same shape that fixed Viper.

**FIX 6.2:** reject `version > SCHEMA_VERSION` in `is_valid()` with a visible message, never a
silent partial apply.

**THEN INVESTIGATE (report, do not fix without a ruling):**
- **The demo sandbox restore path.** `demo_game.gd:82-96` repoints `CampaignState.save_path` and `SaveManager.save_dir`, `_exit_tree:119-124` restores them. **What happens if the demo crashes, or is killed from the taskbar, before `_exit_tree` runs?** The comment at `:86-89` says a demo session was already once writing into his REAL slots. Confirm the hole is fully closed on the abnormal-exit path, not just the clean one.
- **Autosave vs. the 30s interval.** Slot 8 every 30s + slot 9 on exit + `game_flow.gd:732` writing autosave on "FIREBASE". Is anything writing while the world is mid-teardown?
- **`apply_pending_player` Y-restore.** `game_flow.gd:692-696` re-seats a restored player's Y because "a stale saved height puts the player under the ground." Is that a save-format problem (Y should never be persisted) rather than a load-time patch?
- **Tier consequences.** ADR-007's REGULAR/HARD/IRONMAN — `can_manual_save()` and `tier()` exist (`:79-97`); is the tier actually stated in the settings UI, per §4.7's third gap?
- **Run `tests/test_save_roundtrip.tscn`** and report what it does and does not cover. Specifically: does anything test a *corrupt* or *truncated* save?

**Gate:** 6.1 and 6.2 land with a probe that writes a save, truncates it, and proves the loader
survives. No probe, no close (verification law).

---

## §6 — PARKED: needs him, do NOT do overnight

| Item | Why it is parked |
|---|---|
| **`ai_stress_arena` → rebuild on `game_world.tscn`** (AUDIT T-1) | The single biggest item in the audit, and it is a **judgement call, not a repair**: merging costs arena boot time and buys ship parity. His quote at `game_flow.gd:211` reads as "proof over speed," but that was about the sapper bench specifically. **Ask him; do not decide it at 3am.** |
| **`zombie_audio.gd`** (AUDIT D-3) | Zero callers, but zombies are under active work this week. Fossil or tomorrow's wiring — only he knows. |
| **ADR-019 Hearts & Minds** (AUDIT F-3) | Either build the two scoped hooks or amend `GAME_GUIDE.md:279` so THE SLICE stops naming a system that does not exist. **Amending canon is his signature.** |
| **Enemy defensive zones** (AUDIT F-4) | Council work (his own words in the 8/5 decree: deferred on depth-over-breadth). |
| **Any Blender** — VC/NVA face/skin merge if 3.5 fires, segmented trees, M60 mounted FPS placement | His window, his hands, or a daytime agent. Never unattended. |
| **PLAYTEST R4** | Discharged only by his verified playtest (ADR-015). Gated feature work stays parked until then. |

---

## Morning handoff — what he should find

1. `git log pre-overnight-2026-08-06..HEAD` — one revertible range, one commit per wave.
2. `test_results/suite_2026-08-06_pre.log` and `_post.log`, **diffed**, with any new failure named and owned.
3. `probe_doc_pointers.py` exiting **0**, with the broken-pointer ceiling ratcheted down and the number stated.
4. A dozen VC and NVA men on a bench with a dozen different faces — **the first time the enemy force has not been clones.**
5. Three perf numbers that have never existed, or an honest line saying which of the three did not run and why.
6. §6 as his decision queue for the morning — glossed, in plain words, no wave codes.
