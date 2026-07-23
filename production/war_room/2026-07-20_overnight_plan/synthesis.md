# WAR ROOM SYNTHESIS — THE OVERNIGHT RUN, 2026-07-20

**Status:** PLAN ONLY. Nothing in this document has been implemented.
**Arbiter:** RECONgame Overseer. **Council:** technical-director, gameplay-programmer, systems-designer, devil's-advocate.
**Governing directive:** Summoner, 2026-07-20 — *"clean up stale beads and stop making new beads but tackle the open ones tonight."*

---

## 0. THE MEASURED STARTING STATE (verified, not cited)

Every number below was measured during this planning pass. None is quoted from a bead.

| Fact | Measured value | How |
|---|---|---|
| Open beads | **143** (not 148, not 124) | `bd list --limit 0` → "Total: 143 issues (143 open, 0 in progress)" |
| Branch | `audit-fixes` @ `878e4de5`, **tracking `origin/audit-fixes`, fully pushed** | `git branch -vv` |
| Fossil register | ceiling 27 / count 27, self-consistent | `tests/fossil_baseline.json` |
| Fossil probe at HEAD | **RED — 12 new dead symbols** | `run_all_tests.ps1 -Filter fossils` → FAIL 3.3s |
| Suite discovery glob | `test_*.tscn` only | `run_all_tests.ps1:22`, `tools/overnight_suite_chunk.ps1:12` |

**Correction to the brief, recorded first because two agents today acted on the wrong number:** `bd` reports **143** open, not 148. The "389 unpushed commits" that `git log origin/HEAD..HEAD` returns is an artifact — `origin/HEAD` resolves to `origin/master`, a long-diverged branch. The working branch is pushed. **Nothing is at risk on the disk.** Bead `s1gy` is false and closes tonight.

---

## 1. THE FINDING THAT RESHAPES THE NIGHT

The brief proposed `u4h2` (P0 FORWARD+ PERF) as the strategic core, on the theory that it is blocked only by the Summoner's presence at the desk. **The council tested that theory against the code and it does not survive.**

`u4h2`'s own description names three remaining mechanical levers — "streaming off ≤2km, `MAX_THINK_TIME`, and the gating FPS number." Measured tonight:

- **Streaming off ≤2km — ALREADY SHIPPED.** `terrain/core/terrain_manager.gd:62` — *"ADR-013: streaming is disabled on <= 2km AOs - the world is fully resident"*; `:5` calls the streaming path dormant.
- **`MAX_THINK_TIME` — DOES NOT EXIST.** Zero hits repo-wide, `--include=*.gd`. The bead names a symbol that was never written.
- **Decal FIFO cap (absorbed from `mhfv`) — ALREADY SHIPPED.** `scripts/combat/gun_fx.gd:443` and `:534` FIFO-recycle against `MAX_BLOOD_DECALS` / `MAX_DECALS`.
- **The gating FPS number — still the Summoner's, still unset.**

**Therefore: `u4h2` has zero remaining look-invisible levers.** The only levers with measured mass are jungle patches (−12.26ms) and sun shadows (−12.17ms). Both change what the game looks like. Both are already parked behind the Summoner's eyes — `mok6` (ratify ADR-026's "one allowed dynamic shadow"), `4rd4` (look-check switchover), `vwfq` (blessing gate).

**The ruling:** the overnight run **measures** `u4h2` and **corrects** it. It does not close it and does not spend a lever. Pulling a look lever unsupervised would settle ADR-026 by accident — precisely the failure mode the brief forbids.

There is a second, quieter consequence. **We could measure all night and still not know whether we passed**, because the pass/fail line does not exist yet. That is the Devil's Advocate's opening and it is answered in §7, not dismissed.

---

## 2. THE SECOND FINDING: THE FOSSIL PROBE CANNOT BE MADE GREEN TONIGHT

Enumerated from the live probe run — all 12:

| Fossil | Owning bead | Why it is off-limits |
|---|---|---|
| `world_sim.gd:70/86/99` — `update_player`, `materialize_near`, `dematerialize_far` | `nohh` (WB) | WorldSim burial is decreed **Wave B** work. Deleting early front-runs a blessed wave. |
| `sim_clock.gd:79` — `clear_schedules` | AI decree | SimClock is ruled a **LIVE organ, DO NOT TOUCH**. |
| `squad_leader.gd:24/34` | `7doi` | "superseded, F4 bless needs **re-ruling**" — Summoner. |
| `convoy.gd:8/10/91` | `dqgx` | **Explicitly off the table** — wire-or-retire decision. |
| `weapon_data.gd:101` — `get_bore_dir` | `7ioa` / `grqx` | **Explicitly off the table** — live bench work. |
| `ambush_planner.gd:14` — `ROAD_NEAR_M` | `ld0y` | Unenforceable until a road network exists. Design. |
| `water_system.gd:523` — `get_water_at` | `zqlp` / `xx46` | Entangled with the rivers decision, which is his. |

**Every single one is either decreed to another wave, explicitly off-limits, or requires a ruling.** The fossil probe stays RED tonight and that is the correct outcome. `skro` and `j3ke` get **corrected** to carry this enumeration and reclassified as Summoner-gated — they are not closeable and no future agent should try.

**Consequence for the run:** any deletion in §4 can orphan further symbols and push the count past 12. Every code change tonight re-runs `test_fossils` and accounts for its delta. A rising fossil count is a stop condition, not a footnote.

---

## 3. RUN POLICY (Summoner directives, 2026-07-20, last words before bed)

### 3.0 — THE HARDEST CONSTRAINT: NO NEW SYSTEMS. WIRE WHAT EXISTS.

> *"i trust you but dont make any new systems just wiring into whats already there."*

**This overrides everything else in this document.** Where any item below conflicts with it, this wins.

**Allowed:** connecting an existing system to an existing consumer · repairing an existing thing so it performs its stated job · deleting dead code · correcting stale beads · tuning existing values · running existing instruments.

**Forbidden:** any new manager, director, server, layer, pool or bus · any new file that introduces a *concept* rather than connecting two that exist · rewriting a working system "properly."

**Probes are the one narrow exception** — they are instruments, not game systems, and he approved them explicitly. Keep them minimal, follow the existing ratchet pattern, invent no probe infrastructure.

*Why this is correct rather than merely cautious:* this project's signature defect is systems that get BUILT and never WIRED — `civilian_schedules`' undispatched BT root, `director.fire_support` never assigned, `AirTraffic`/`AmbientWar` rosters read by nothing, `GroupWalk` with zero call sites, `AmbushPlanner` output discarded, convoys with an empty vehicle array, `location_planner.gd` alive only by its test, and the 16 probe scenes in §7. **Building a new system unsupervised overnight is the single most likely way to add a 42nd finding.** Wiring is the correct mode of work for this codebase.

### 3.1 — The remaining standing rules

1. **NO NEW BEADS.** The single exception: the fix genuinely requires his ruling — taste, an ADR amendment, a provisional pillar, or an irreversible deletion he has not sanctioned.
2. **Default on contact is FIX, not FILE.** The "or bead it" branch of the NO MORE DRIFT law is closed tonight.
3. **Anything found that cannot be fixed and does not need his ruling goes in the MORNING REPORT.** The report is the release valve. Not the graph, and not silence.
4. **Scoreboard: open-bead count must go DOWN.** Start = **143** (measured). Report the end count and the delta.

**The council names the hazard in this policy plainly, because the Summoner asked us to.** A no-new-beads rule applies pressure toward two bad outcomes: hasty fixes, and quiet omission. The guard is that every item in §4–§6 ships a probe — a hasty fix fails its own probe — and that §7's report is mandatory, not optional.

---

## 4. THE RUN — PHASE 0: PRE-FLIGHT (headless, ~15 min, blocking)

### 0.1 — Restore the Forward+ renderer key. **DO THIS FIRST.**

`project.godot` is **dirty and uncommitted**, and the diff is pure damage:

```
-renderer/rendering_method="forward_plus"
-renderer/rendering_method.mobile="gl_compatibility"
 textures/canvas_textures/default_texture_filter=0
+renderer/rendering_method.mobile="gl_compatibility"
```

One line deleted, one reordered — the signature of a wrong-version editor rewrite, matching the recorded 4.6.2 incident. **The explicit Forward+ decree line (ADR-026 Amendment A, standing-decree item 2, marked ✅) is currently absent from the working tree.** Desktop Godot still defaults to Forward+, so behaviour is likely unchanged — but *no perf number measured tonight is trustworthy against a config whose renderer is implicit.*

Restore the line. Commit it alone, with the diff in the message.

> **STOP CONDITION:** if at run time `git diff project.godot` is anything other than exactly this 1-line deletion plus the reorder, **do not touch the file** and report it. The rest of the dirty tree is his live bench work.

### 0.2 — Scripted config guard.
Snapshot `project.godot` to the scratchpad before Phase 1 and restore it after. The PERF_LEDGER records that `scaling_3d/scale` was once "temporarily set to 1.0, then restored" by hand. A hand-restore that fails silently ships a wrong render scale into the morning. Script it; verify by diff.

### 0.3 — DIRECT-TO-PATROL BOOT. **This gates Phase 1 and it is for HIM, not for us.**

> *"if you need to spawn into the game just bypass the new game menu"* … *"and spawn directly into the game — cuz if you run a mcp i cant test it and tell you anything about the game."*

`scripts/main/game_flow.gd:23-25` boots to a menu with no autostart. A launched run therefore reaches no world and measures nothing — which is why today's runtime pass had to go the long way round, and why a bench run can land on a hillside with no firebase.

**The clarification changes who this serves.** A bypass living only inside a test harness serves agents and does nothing for him. When he launches tomorrow to playtest, he must land in the patrol — menu-clicking is friction in the only feedback loop that can settle the squad-feel numbers that shipped tonight.

**Therefore: make direct-to-patrol the DEFAULT boot for the project.**

- Wire the default entry to the **existing** `_begin_operation -> enter_hub()` chain (the genuine build path, `mission_generator.build_patrol_world:536`), on `DEFAULT_OPERATION_SEED = 47225` (`game_flow.gd:188`).
- **This is wiring, not construction** — an existing chain reached from an existing entry point. It sits inside §3.0. If a flag already exists for this, use it and add nothing.
- **ONE path serves both cases** — his windowed launch and any automated run. **Do not fork them.** Two entry paths for one job is precisely the competing-systems defect this project is riddled with.
- **Keep the menu reachable. Keep the change one-line reversible.** He said stop landing on it, not delete it. `main_menu.tscn` and everything it owns stay.

**Seed discipline — this is a correctness matter, not bookkeeping.** `tests/test_patrol_world.tscn` is the proven bypass route but hardcodes seed **31337**, while the real default is **47225**. Seed changes terrain, site layout and therefore frame cost — the two seeds measured **87.5 m vs 59.5 m of relief** today. **Every perf figure tonight is measured on 47225 and states its seed.** A number from 31337 does not describe the world he plays.

**Verification (windowed, legal tonight):** launch it and confirm you reach the firebase with squad and world built — `[SPAWN-TRUTH] delta=0.00`, firebase present, allies present. This is the same check that caught today's hillside-with-no-firebase error, which happened precisely because a scene was run that skipped this chain.

---

## 5. THE RUN — PHASE 1: THE WINDOWED BLOCK (the scarce resource — do it first)

Windowed Godot is legal only while he sleeps. This block cannot be recovered if the night is spent elsewhere.

**Note:** no `.bat` or `.ps1` in the repo launches `tests/perf_probe.tscn`. One must be written. `night_jungle_bench.bat` launches the **arena**, which is a frozen instrument and not the populated patrol world.

### 1.1 — `s7wo`: execute the repaired attribution probe. *It has never run.*
- `tests/perf_probe.gd` is verified clean of the `BillboardVegetation` phantoms; it now toggles `VegetationManager.patches_disabled` (`:95`), `TreeCoverLayer` (`:97-99`), `GroundClutter` (`:105-109`), and `push_error`s loudly when a phase cannot resolve (`:101`, `:111`).
- Windowed is **mandatory**: `RenderingServer.get_rendering_info` (`:79-84`), `Engine.get_frames_per_second` (`:74`), and a real framebuffer capture (`:116`) are all zero or meaningless under `RendererDummy`.
- Run against the **real populated patrol world at seed 47225** via the §0.3 boot — not the arena, and not seed 31337.
- **Sanctioned instrument change:** add a `no_sun_shadow` phase. Sun shadows are the second-largest measured lever and the probe cannot currently see them. *Measuring a lever is not deciding it* — evidence-gathering probes are GATE-exempt. **The default must not change.**
- **Deliverable:** raw stdout captured to a file + a new `PERF_LEDGER.md` row carrying render scale, renderer, seed, and hardware per the ledger's own measurement contract.

### 1.2 — `l9kh` (windowed half): the LazyGroup cost.
Measured facts to bench against, verified tonight: **8–9 LazyGroups, 28–51 bodies** (3 lazy villages `mission_generator.gd:540-542`, 3 lazy camps `:543-545`, 2–3 ambient patrols `:577-596`) — the bead's "26–40" undercounts because it omits the ambient patrols, which are also LazyGroups.
- Honour the **method debt** named in `u4h2`: a live firefight escalates while being measured. Use a **frozen scenario and A/B/A**, never a single-pass toggle.
- **Deliverable:** a ledger row. **Not** a fix — see 6.4 for why the fix is his.

> **HARD STOP after Phase 1: spend nothing.** Every remaining perf lever changes the look, and the look is his (`4rd4`, `vwfq`, `mok6`).

---

## 6. THE RUN — PHASE 2: HEADLESS WORK (each item ships a probe)

All four bugs below were verified at `file:line` tonight and all four are headless-verifiable.

### 6.1 — `bhu9`: hitzones never rebuild after a body swap. **FIX.**
`scripts/allies/ally_base.gd:278-290` — `set_sprite` frees the old `ModelActor` and calls `_setup_visual()` at `:290`, but **never `_setup_hurtbox()`** (the only call is at `:236`, `_ready`-time). `_hitzone_sync` keeps bone indices harvested against the OLD skeleton, and `:397-398` feeds them to the NEW one every tick. `HitzoneBuilder.sync` (`hitzone_builder.gd:175-199`) guards only on empty/null/valid — **nothing validates that the bone index belongs to this skeleton.** Live in the shipped game via `squad_system.gd:62`.
- Fix: `_setup_hurtbox()` after `:290`, plus teardown of the old zones (pattern exists at `civilian.gd:307`) — otherwise old `Hitzone` Area3Ds stay parented and you get the double-zone bug `test_actor_damage_contract.gd:105-110` already guards for the player. ~3–8 lines, one file.
- **No probe covers this today.** `test_actor_damage_contract.gd:94` is a *source-text* assert (`src.contains("HitzoneBuilder.build(")`) — it passes today and would keep passing after the bug. Write a runtime probe: assert every `entry[1] < new_skel.get_bone_count()`, bone name matches the zone's `region` meta, and child `Hitzone` count did not double.

### 6.2 — `2whe`: gibs drop the dressed face. **FIX.**
`scripts/combat/gib_system.gd:294-306` — `_spawn_gib` takes a bare `Mesh` and assigns `mi.mesh = mesh`. Godot stores surface overrides on the **MeshInstance3D**, not the Mesh, so the dressing set by `grunt_dresser.gd:119/197` and the tint set by `model_actor.gd:178` are lost. Call sites `:161`, `:166`, `:240` all discard the donor, which is in scope at `:156`.
- Fix: pass the donor `MeshInstance3D`, copy overrides after `:304`. ~10 lines, one file, 3 call sites.
- Probe: `gib_mi.get_surface_override_material(s) == donor_mi.get_surface_override_material(s)` — pure property compare, no render. Read `_live_gibs` (`:325`) **before** `MAX_LIVE_GIBS` trims at `:326-329`.
- *Whether the gib looks right in flight is eyes-work; whether the material survived is not.*

### 6.3 — `tsmj`: the surviving half. **FIX (deletion only), then NARROW the bead.**
Commit `53a82fbd` cleaned `_patrol_anchors` (`mission_generator.gd:164-193` is now clean). **`_enemy_anchors` survives untouched** at `mission_generator.gd:418-420`, reading `firebase_center` / `camp_center` / `village_center` — none of which is ever written. The plan writes `fsb_center` (`:452`), `village_centers` (`:498`), `camp_centers` (`:512`).
- **Critical distinction the run must respect:** deleting the dead loop removes a *lie*, it does not fix the *consequence*. The loop's uselessness starves `nav_baker.queue_sites(nav_sites, _enemy_anchors(p))` (`:610`) of anchors. **Choosing which anchors NavBaker should receive is a design decision — it is his.** Delete the dead code; report the starvation in the morning report; do not invent anchors.
- Probe: `_enemy_anchors` is `static` and pure — assert the singular keys are absent and `_enemy_anchors(p).size() == p.enemy_groups.size()`.
- Side finding for the report: `tests/test_world_minimap.gd:81-85` reads all three singular keys via `.get(..., Vector3.ZERO)` — it is silently drawing three markers at world origin.

### 6.4 — `l9kh` (headless half): prove the non-despawn. **FIX = a probe, not a change.**
`scripts/missions/lazy_group.gd` — `_spawned` has exactly four occurrences repo-wide, all in that file, and is **never reset** (`:35`, `:50`, `:65`, `:67`); `set_physics_process(false)` at `:100` is never paired. Zero `despawn`/`queue_free` hits. There is a distance cap on *activation* only (`:8`, default 120.0; 140.0 at `mission_generator.gd:586`) and **no count cap and no re-sleep distance**.
- Ship a headless census probe: walk a simulated patrol past every group, assert the permanently-spawned body count and that it never decreases.
- **Do NOT write the despawn.** A despawn radius is a *feel* decision — it governs whether the world stays populated behind you, which touches Pillar 2 (Atmosphere) and Pillar 3 (the seeded world generates the stories). **This is the one item in the run that earns a bead**, under the ruling exception. It goes to him with a measured number attached.

### 6.5 — `l9u8`: remove the dead objective/exfil scoring. **FIX.**
`mission_state.gd:21-27` `register_objective()` has zero production callers (only `tests/test_mission_state.gd:17-19`); `emergency_exfil` (`:15`) is never assigned `true`. So `debrief.gd:30` scores a permanent 0, `:36-37` never fires, `:71` prints `"OBJECTIVES: 0 / 0 (x100)"` to the player every patrol, and `:50`'s rank gate collapses so that "CLEAN SWEEP" is decided **solely** by `damage_taken < 30`.
- ADR-029 forbids objective counting, so removal is **decree-aligned, not a judgment call**.
- Footprint: 4 files, ~10 sites — `mission_state.gd`, `debrief.gd`, `tests/test_mission_state.gd` (goes red, must be deleted in the same change), `tools/probe_config.gd:35-36`.
- **Must also remove** `tests/test_only_liveness_baseline.json:12` (`mission_state.gd|register_objective`) or the register goes stale — the liveness probe is *already tracking this as debt*.
- No save path and no HUD reads these fields (grep across `*save*.gd`: no matches). `tests/test_patrol_aar.gd:45-56` already drives the real `DebriefScreen` headless and catches a construction break.
- *Whether the new AAR text reads well is eyes-work; whether it is correct is not.*

---

## 7. THE RUN — PHASE 3: THE PROBE CENSUS (`p7no`) — DONE SAFELY

**Correction to the bead, verified:** it claims four probes carry live assertions. **Fifteen of sixteen do.** `push_error` is not the only assertion mechanism — the runner judges on exit code (`run_all_tests.ps1:133`), and 15 of 16 call `quit(1)` on failure. The sole exception is `probe_perf_decay.gd`, which only ever exits 0 (`:99`) — a reporter, not a gate. It also reads `Performance.RENDER_*` (`:60-64`, `:90-95`), which is **zero under RendererDummy**, so it is fiction headless regardless.

**The naive move — rename all 16 into the glob — is rejected.** It would turn a broadly green suite red in up to 15 new places at once, with no way to tell a real bug from a stale probe, and would bury the signal the morning report depends on.

**The safe sequence:**
1. **Run all 16 in place, no rename**, invoking each `.tscn` directly. Record PASS/FAIL and the failure text. This changes nothing and learns everything.
2. **Rename only the green ones** to `test_*.tscn`, entering them into the glob.
3. For each red one: **fix it if the fix is mechanical** (default is FIX tonight). If a failure exposes a real defect whose fix needs his ruling — that is the bead exception. Otherwise it goes in the morning report.
4. Update `tests/test_health_baseline.json` (`count`/`ceiling` currently 17) **downward** for every probe adopted. The ratchet only shrinks.

**Start with `probe_autoload_reach`** — pure file I/O, ~1s, no world build, with a parser negative control (`:36-42`) and a matcher self-test (`:56-62`). It is the probe most often cited across this project as established ratchet machinery and it **has never once executed.** One rename.

Budget note: `probe_worldbuild_phase1` does 3 world builds (`:13-15`); `probe_settlement_spacing` and `probe_water_channels` do 3 seeds each. Slow, but the night is long.

---

## 8. THE RUN — PHASE 4: THE STALE-BEAD SWEEP

Verified tonight, ready to action — **no verification work required, this is execution**:

| Bead | Action | Evidence |
|---|---|---|
| `s1gy` | **CLOSE** | `audit-fixes` tracks `origin/audit-fixes` @ `878e4de5`, fully pushed. The 389 figure is vs `origin/master`, a diverged branch. |
| `skro` / `j3ke` | **CORRECT + reclassify Summoner-gated** | Register 27/27; 12 live fossils enumerated in §2; **all 12 off-limits**. Not closeable. |
| `tsmj` | **NARROW to `_enemy_anchors`**, then close when 6.3 lands | `_patrol_anchors` clean at `:164-193`; `_enemy_anchors` dead at `:418-420` |
| `u4h2` | **CORRECT the STILL-OWED list** | streaming already off (`terrain_manager.gd:62`), decal cap already shipped (`gun_fx.gd:443/534`), `MAX_THINK_TIME` does not exist |
| `p7no` | **CORRECT** | 15 of 16 carry build-breaking assertions, not 4 |
| `l9kh` | **CORRECT** | 8–9 groups / 28–51 bodies; the body-gate velocity check is `enemy_base.gd:524`, not `:528` |
| `1t6h` + `xx46` | **MERGE into `xx46`** | the creek fix was refused with better evidence; one cause, one bead. *The remedy stays his.* |
| `e9je` | **CORRECT the note** | closed bead still carries "PAUSED BY SUMMONER 2026-07-18" |
| Doc drift | **FIX** | `production/GAME_AUDIT_2026-07-19.md:38` and `production/COMPETING_SYSTEMS_2026-07-19.md:442` both cite `tests/perf_probe.gd:88` as a surviving `BillboardVegetation` reference. Now false. POINTER LAW. |
| Compiled piles `c3ea` `e1q6` `etvy` `gryl` `p85y` `s2fs` `imue` `lpib` | **VERIFY CONTENTS, close what is done** | aggregates from earlier audits; contents unverified against current code |

The `PERF_LEDGER.md` headline attribution ("billboards are the whole story") is itself measured against `BillboardVegetation` — the system `s7wo` says was retired. Phase 1.1's fresh row supersedes it; **annotate the old entry as superseded rather than deleting it** (ledgers are history, ADR-014).

---

## 9. WHAT THE RUN MUST NOT TOUCH

**Files — absolute prohibition:**
- `assets/us/characters/weapons_us.blend`, `assets/nva_vc/weapons_vc.blend`, `assets/weapons/world/`, `tools/export_world_guns.py`, `tools/weapon_builder.py`, `tools/build_weapons_vc.py`, `data/weapons/`, `data/projectiles/`, `viewmodel_editor.gd`
- `tests/test_height_authority.tscn` (dirty — his)
- `project.godot` — **except** the single Forward+ line in 0.1, under its stop condition

**Beads — off the table, unchanged from the brief:** `7ioa`, `ngp0`, `xx46`/`1t6h` (remedy), `p622`, `dqgx`, `v82k`, `oo38`, `6n0b`, `9f52`, `b6lr`, `8l06`, `4rd4`, `vwfq`, `mok6`, `7doi`.

**Decisions the run may not make:**
- **No new system of any kind** (§3.0) — no manager, director, server, layer, pool or bus; no file that introduces a concept. Probes only, minimal, on the existing ratchet pattern.
- No second entry path to the patrol (§0.3) — one boot serves him and the bench.
- No removal of `main_menu.tscn` or anything it owns.
- No perf figure reported without its seed; no figure from seed 31337.
- No perf lever that changes the look. No renderer change. No render-scale change that outlives Phase 1.
- No pillar settled — Pillar 4's anti-puppeteer clause stays PROVISIONAL.
- No ADR ratified or amended.
- No fossil deleted (§2 — all 12 are gated).
- No merge of `audit-fixes` to `master`.
- No despawn radius written (6.4).
- No NavBaker anchors invented (6.3).

---

## 10. THE ENTIRE AI-CONSOLIDATION CHAIN IS EXCLUDED. HERE IS WHY.

**Settled by decree before the council's reasoning is even needed:** §3.0 forbids new systems, and `akx8`'s **PerceptionServer is a new system** — a new server that owns behaviour. It is out of scope regardless of what this council concluded. Wave A is excluded on the Summoner's word alone.

The council's independent reasoning agreed, and is recorded because it names *which* parts would be unsafe if the constraint were ever lifted:

- `e9je` (W0) is **CLOSED** (commit `b6f2aa67`) and all seven preservation probes exist — `test_witness_rule`, `test_dormancy_clocks`, `test_think_budget`, `test_body_gate`, `test_spider_tunnel`, `test_activity_tiering`. `akx8` is genuinely unblocked. A2 (body gate) is already **DONE** (`630edd1a`). So the temptation is real.
- But `akx8` carries **a live, open blocker requiring an Overseer ruling**: a flat 60 rays/s cannot serve 65 engaged pairs at a 200ms floor (~325/s needed vs ~110/s measured). **You do not start a wave with an unresolved blocker inside it.**
- Worse, that blocker is not merely technical. Bending the ray floor changes *what gets investigated first* — which lands it inside the synthesis's own **FUN-LEVER GATE** (`synthesis.md:82-85`): *"Anything that changes WHO is shot at, HOW FAR pursuit goes, WHAT gets investigated first, HOW FAR the enemy sees, or HOW LONG he remembers is a FEATURE — it enters through the Summoner's eyes or not at all."*
- A4 (exposure ramp) is named outright as *"the A4 fun lever"* and *"it IS the live Fairness Law."* Categorically excluded.
- Threat-spread merged into the 2:1 rule is a **second un-ruled fun lever loitering in Wave A's scope** — it changes who is shot at.
- Even A3 (think budget + stagger), the most mechanical slice, carries the synthesis's own named cost: *"Staler decisions under think budgets."* Staleness is **felt in play**, and there is no playtest tonight.

Front-running a blessed wave badly is worse than not starting it. Wave A waits for morning.

---

## 11. STOP-AND-WAIT POINTS

The run halts and reports, rather than deciding, at any of these:

1. `git diff project.godot` is anything other than the exact 1-line renderer deletion (§0.1).
2. Restoring `project.godot` after a windowed run fails its verifying diff (§0.2).
3. The fossil count rises above 12 after any deletion (§2).
4. A previously-green suite test goes red from a probe adoption (§7).
5. Any windowed measurement suggests a look lever should be pulled — measure, record, **stop** (§5).
6. Any fix's correct answer turns out to depend on his taste — that is the bead exception (§3).

---

## 12. THE DEVIL'S ADVOCATE — THE OBJECTION THAT WAS NOT ANSWERED

> **"The marquee item of this run is a P0 that nothing done in this window can close, and you have known that since §1.**
>
> `u4h2` has now been measured four times — `365s`, `t5mo`, the 2026-07-18 spawn-view row, and now a fifth run tonight. It has been *spent* zero times. Every free lever it named turns out to be already shipped or to name a symbol that never existed, which means the bead has been carrying a fictional to-do list for days and nobody checked. A fifth attribution run is not progress; it is procrastination wearing a lab coat.
>
> And the trap underneath it: **there is still no gating FPS number.** You will produce beautifully instrumented rows tomorrow morning and still be unable to say whether the game passes, because the pass/fail line does not exist. You are proposing to spend the single scarcest resource in this project — the only hours in which windowed Godot is legal — generating evidence for a decision that cannot be made without a number only he can supply.
>
> **If every lever is his and the gate number is his, then `u4h2` is not a perf bead at all. It is BLOCKED ON THE SUMMONER, and the honest move is to say so in the graph rather than to keep grinding measurements against it.**"

**The Arbiter's answer — partial concession, which is what it deserves.**

The objection is upheld on classification and rejected on the run order.

*Upheld:* `u4h2` is reclassified. Phase 4 corrects its false to-do list, and the correction must state plainly that **the bead is blocked on two Summoner inputs — the gate number and the choice of look lever** — not on engineering effort. Pretending otherwise is exactly the drift this project keeps bleeding from.

*Rejected:* the conclusion that the windowed hours are therefore wasted. Two reasons.

First, `s7wo` is not a re-measurement. **The probe has never executed once.** Its previous incarnation named two phantoms and could not compile, which means the attribution rows in `PERF_LEDGER.md` — including the "billboards are the whole story" headline the whole perf strategy rests on — were produced by an instrument measuring a system that had already been buried. The night does not produce a fifth measurement of the same thing; it produces **the first honest one**, and it retires a false one.

Second, the gate number's absence cuts the other way. He cannot *set* a defensible gate number without knowing what the frame is actually made of. Handing him a ranked, honest attribution — canopy, clutter, sun shadow, and the LazyGroup body cost, each with a measured mass — is precisely the input that unblocks his decision. **Measuring is not the alternative to deciding; it is the precondition for it.**

*What is sacrificed, named plainly:* the night's headline deliverable is evidence, not frames. The morning FPS will be the same as tonight's FPS. Anyone hoping to wake to a game that hits 30 will be disappointed, and the plan should not pretend otherwise. What he wakes to instead is four real bug fixes, a probe suite that runs sixteen tests it has never run, a graph that shrank, and — for the first time — a true account of where the frame goes.

---

## 13. MORNING REPORT — MANDATORY CONTENTS

The report is the release valve for the no-new-beads rule. It must carry:

1. **Open-bead delta: 143 → N.** The honest scoreboard.
2. **What was WIRED** (not built) — every connection made between things that already existed.
3. Every item attempted, its probe or measurement, and its result.
4. **Confirmation that the §0.3 boot lands him in the patrol** — `[SPAWN-TRUTH] delta=0.00`, firebase present, allies present — and that the menu is still reachable and the change is one-line reversible.
5. The new `PERF_LEDGER` rows, with render scale, renderer, **seed (47225)**, and hardware.
6. The `p7no` census table: all 16 probes, PASS/FAIL, and what was done with each.
7. **Everything found that was neither fixed nor beaded**, stated plainly — including at minimum the NavBaker anchor starvation (§6.3) and the `test_world_minimap` origin-marker bug. *This is the release valve for the no-new-beads rule. A no-new-beads policy applies pressure toward hasty fixes and toward quiet omission; **neither is acceptable.** Anything that genuinely could not be fixed and genuinely does not need his ruling is spoken here, not buried and not filed.*
8. **The decisions waiting on him**, ranked: the gate FPS number · the look lever · the LazyGroup despawn radius · the `akx8` ray-budget blocker · the 12 gated fossils.

---

*Nothing above has been implemented. The Summoner holds final authority; the Council holds the pillars.*
