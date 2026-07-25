# GHOST-CODE AUDIT — 2026-07-25

Full-project sweep for code that wires to nothing. Six passes: baselined fossils, ghost pointers to buried systems, signal graph, unattached scripts, unreachable scenes/resources, stringly-typed dispatch. Every DEAD verdict re-verified against dynamic dispatch (`has_method`/`call`/`call_deferred`), group broadcasts, `.tscn` bindings, `.tres` bindings, string-built load paths, and the 10 `.bat` dev roots. **Audit only — nothing was edited or deleted.** Cleanup decisions go through War Room per ADR-023.

Verdict legend: **BUG** (live reader, missing writer — feature silently broken) · **FOSSIL** (superseded/expired, delete-eligible) · **GHOST POINTER** (reference to deleted system) · **UNFINISHED** (built ahead of wiring; the missing half is named) · **STALE BASELINE** (register entry no longer true) · **SEAM/OK** (intentional, documented here so nobody re-flags it).

---

## 1. BUGS — dead wiring behind live features (2)

| # | Evidence (2026-07-25) | Finding |
|---|---|---|
| 1.1 | `scripts/player/player.gd:454` + `:602` read group `temple_shrines`; **zero** `add_to_group("temple_shrines")` in any .gd or .tscn; site kind `"temple"` exists only in `scripts/world/world_config.gd:35` and no generator produces it | **Shrine-search intel feature can never fire.** The [F] SEARCH THE SHRINE prompt + the +1 intel/save/toast payoff are fully coded on the player side; no shrine ever joins the group and no temple site is ever generated. Doubly dead: needs both a temple site producer and the group add. |
| 1.2 | `scripts/main/mission_scope.gd:29-31` stops every node in group `wave_runners` on scene reset; **zero** writers repo-wide | **Coroutine leak-guard is a guaranteed no-op.** If any long-lived runner was supposed to self-register, the cleanup it relies on is silently disabled. Either wire registrants or delete the loop. |

## 2. STALE BASELINES — the registers have drifted (10 of 21 debt entries)

`tests/test_only_liveness_baseline.json` no longer reflects the tree (verified by grep 2026-07-25):

**Wired since baselined (4) — remove from register, they're alive:**
- `campaign_state.gd:61 roster_skill` → production caller `scripts/player/player.gd:509`
- `radio_handset.gd:53 take` → production caller `scripts/player/player.gd:351`
- `helicopter.gd:127 take_off` → production caller `scripts/ai/air_traffic.gd:277`
- `mission_generator.gd:11 CivilianScript` → used in-file at `mission_generator.gd:754`

**Points at already-deleted code (6) — remove from register:**
- `mission_state.gd`: `complete_objective`, `is_exfil_unlocked`, `register_objective` — zero hits in scripts/ (ADR-029 retired the objective loop)
- `location_planner.gd`: `apply_lifts`, `plan_locations` — file no longer exists
- `scripted_sequence.gd:85 abort` — lost even its test caller (`grep '\.abort('` = 0 hits); now a plain fossil

Ratchet opportunity: debt ceiling 21 → 11.

## 3. TRUE FOSSILS — delete-eligible under ADR-023

### 3a. From the fossil register (10 of 19 diagnosed FOSSIL)
| file:line | symbol | superseded by |
|---|---|---|
| `scripts/autoload/combat_manager.gd:306` | `clear_all_projectiles` | HoD leftover; only test fixture cleanup uses it |
| `scripts/player/health_system.gd:264` | `add_health_pack` | RECON has no health-pack pickup; only save/load touches the field |
| `scripts/player/weapon_holder.gd:162` | `BASE_VIEWMODEL_SCALE` | scale baked into viewmodel .tscn per doctrine |
| `scripts/squad/squad_system.gd:7` | signal `squad_changed` (3 emit sites) | HUD polls `squad.members` directly (`mission_hud.gd:246,326`) |
| `scripts/vehicles/helicopter.gd:6` | signal `arrived_at_destination` | consumers use `landed`/`took_off` + state |
| `scripts/vehicles/landing_zone.gd:57` | `get_landing_position` | `air_traffic.gd:264` flies to `lz.global_position` |
| `scripts/vehicles/seat_system.gd:18-19` | signals `seated`/`unseated` | boarding driven by direct calls |
| `terrain/core/gameplay_grid.gd:458` | `mark_cleared` | `rebuild_rect`/`update_region` path |
| `terrain/water/water_system.gd:465` | `get_water_type` | siblings have consumers; type query never did |
| `scripts/missions/mission_generator.gd:12` | `EnemyBaseScript` preload const | never used in file (from debt register) |

### 3b. One-shot diagnostic scenes whose purpose expired (9 scene+script pairs)
`tests/inspect_huey.tscn`, `tests/windowed_confirm_47225.tscn`, `tools/diag_body_gate_payoff.tscn`, `tools/diag_crater_scale.tscn`, `tools/diag_fsb.tscn`, `tools/diag_fsb_seat.tscn`, `tools/diag_veg_seat.tscn`, `tools/dump_spine2.tscn` (+`tools/dump_spine.gd`, which has no scene at all), `scenes/Objects/Radio_US.tscn` — the last superseded by `scenes/props/radio.tscn` (spawned at `scripts/world/site_planner.gd:663`) and sitting in a forbidden capitalized `Objects/` dir. Each verified zero inbound references; git shows each belongs to a shipped wave.

### 3c. Stray backup
`scripts/allies.zip` — 147 KB committed backup snapshot (checkpoint 90749a7a, 7/22). 39 files across six dirs: 29 identical to live tree, 10 **older** than live, 0 unique. Pure redundancy; conflicts with the standing no-backups law. Safe to delete (nothing references a zip path); needs a commit since it's tracked.

### 3d. Dead group bookkeeping (8 groups written, never read)
`friendly_patrol`, `hunters`, `landing_zones`, `mg_gunner`, `mission_triggers`, `player_hurtbox`, `scripted_sequences`, `village_animals` — each has `add_to_group` sites, zero queries repo-wide (dynamic-array readers checked). Also: `hitzone_builder.gd:540` sets meta `base_height` that nothing reads (siblings `base_radius`/`base_offset`/`rot_deg` are read by `hitzone_editor.gd`). Also: `gun_range.gd:45` adds to `nav_source` but gun_range never bakes a navmesh — inert add.

### 3e. Unreferenced data-file fossils (bless before deleting — Blender-pipeline owner's call)
- `assets/us/characters/gun_placements.json`, `helmet_item_slots.json`, `radioman_loadout.json` — from the 41fcdc85 helmet/variant wave, no current consumer
- `assets/world/building models/structures/ruins/ruin_set_templates.json` — `ai_stress_arena.gd:81` scans that dir for `.glb` only
- `assets/civilians/characters/caleb_cower_f20.json` — only `caleb_cower_pose.json` feeds `make_cower_from_pose.py`
- `assets/player/arms/grip_states/` — 17 jsons, zero code consumers; 4 name weapons with no in-repo model (`SKS`, `Thompson_Submachine_Gun`) or dormant ones (`RPG7`, `M72_LAW`)

## 4. GHOST POINTERS — references to deleted systems (all comments/dev tools; runtime load graph is CLEAN)

Every literal `preload`/`load` target in scripts/ + terrain/ exists on disk (240 checked). Zero surviving `HubBriefing`/`BriefingScreen`/`MissionSelectScreen`/`MissionOffers`/`show_briefing`/`launch_accepted`/`sprite_renderer` symbols in code. The ADR-029 burial was total. What remains:

| Where | Ghost |
|---|---|
| `tools/export_grunt.bat:5` | Runs Blender on `art_source/characters/base_psx/us_grunt_v2.blend` — **file does not exist** (verified 7/25); hard-fails when run. Sibling `export_us_grunt_v2.py` is fine (opens `us_base_v3.blend`). |
| `tools/make_soldier_lineup.py:10,14-17` | Points at `assets/models/characters` + `us_grunt_v2/_m60/_m79/_m14.glb` — none exist; `os.path.exists` guard means it silently produces an **empty lineup** every run. |
| `scripts/enemies/enemy_data.gd:47-48` | Doc comment describes the buried 8-directional billboard pipeline and `res://assets/NPCs/…` (dir doesn't exist). Fields themselves are LIVE (they key 3D ModelActor clips). Comment lies. |
| `terrain/systems/damage_system.gd:75`, `terrain/systems/clearing_system.gd:61` | `# set by terrain_lab` — terrain_lab is deleted; real setters are `game_world.gd:138` and `:140`. Actively misleading. |
| `scripts/main/mission_scope.gd:14` | Tombstone comment referencing the deleted terrain_lab subgraph. |
| `scripts/ui/screens/recon_ui.gd:123` | "offer tiles" — deleted hub-board vocabulary in a live style function's comment. Trivial. |

**Doc-side (uncorrected, non-archived):** worst is `production/war_room/analysis/audit_structure.md:258-259`, which instructs readers to open STATE_OF_PROJECT / MISSION_DESIGN_RESEARCH / RECON_ADAPTATION (all deleted on purpose 7/23). Also stale present-tense claims: `production/GAME_GUIDE.md:93` ("currently skips BriefingScreen"), `production/adr/ADR-008` (:23-24,48-49,82-83 cite `launch_accepted()`/BriefingScreen at line numbers that no longer hold them), `production/adr/ADR-010:24` (cites deleted `mission_offers.gd`), `production/DESTRUCTIBLE_JUNGLE_PLAN.md:88` (run terrain_lab.tscn), plus MISSION_DESIGN_RESEARCH citations in `production/research/batch_research_jungle_ai_heli_gore.md:146,165` and several non-archived war_room analyses.

## 5. UNFINISHED — built ahead of wiring (four feature clusters + strays)

These are the "more to it" findings: real subsystem halves waiting for their other half. Not delete-on-sight.

| Cluster | Dead symbols | Missing half |
|---|---|---|
| **Grenade-cook HUD** | `grenade_handler.gd:5 grenade_thrown`, `:6 grenade_cooking` (emitted every cook frame), `:120 get_cook_progress`, `:126 get_remaining_fuse` | HUD consumer. ADR-023:100-101 already names this the canonical Category-2 example. |
| **Heli insertion/extraction** | `seat_system.gd:266 board_squad`, `:253 unseat_all`, `site_planner.gd:698 stamp_lz` (all test-only callers) | Parked by ADR-029's foot-only slice. Dormant on purpose until the slice widens. |
| **Corpse-drag** | `model_actor.gd:674 ragdoll_bone`, `:682 wake_ragdoll` ("the drag mechanic grabs these") | The grab mechanic. No ADR decrees it; player.gd:47 only has the speed-multiplier hook. |
| **Downed/capture economy** | `health_system.gd:8 downed_started` (sibling `downed_ended` IS consumed, player.gd:830), `enemy_base.gd:2367 secure` (test-only) | Start-of-downed UI tell; player interaction path for the SECURE verb (fits ADR-019 hearts-and-minds). |
| Strays | `mission_trigger.gd:80 disarm` (+ uncalled `activate`) — external trigger-control API with no authored sequence; `skill_catalog.gd:43 buy_skill` — only writer of squad skill levels, no debrief/spend UI calls it (ADR-018 context); `enemy_squad.gd:38 HOT_CEILING` — clamp enforced only by its test; `sim_clock.gd:12 day_advanced` — day granularity unused (hour has 3 listeners); `sequence_bark` — see §6 | |

## 6. ScriptedSequence / MissionTrigger — protected, but three passes flagged it independently

`scripts/missions/scripted_sequence.gd` + `mission_trigger.gd` have **zero production instantiation** — alive solely via `tests/test_scripted_events.gd`. Three independent symptoms converge: `has_method("sequence_move_to"/"sequence_play_clip"/"sequence_hand_off")` guards (`scripted_sequence.gd:226,253,344`) whose only implementer is the test stub; group `scripted_sequences` written, never read; `connect("damaged")` (`:128`) where no production class declares `damaged` (deliberate — poll fallback documented at `:150`).

**Status: KEEP.** Both files carry "KEEP — RULED BY THE SUMMONER 2026-07-20, DO NOT DELETE" banners (commit 62256ec8). This is dormant infrastructure by ruling, not rot. Noted so future audits stop re-flagging it. The one register gap: several of its signals (`triggered`, `completed`, `interrupted`, `handed_off`, `sequence_signal`) plus `helicopter.landed`/`took_off` are test-only-listened but **absent** from the liveness register — the register under-counts this subsystem.

## 7. SEAM/OK — checked and cleared (so nobody re-audits them)

- **Unattached scripts: ZERO.** All 152 .gd under scripts/+terrain/ reachable (92 by path, 60 by verified class_name use). The 7/20 sweep (62256ec8) got the last three.
- **Dead signals/handlers: ZERO** of 84 signals / 70 `_on_` handlers. (9 emit-orphans are catalogued in §3a/§5; `vo_manager.gd:98 _on_cooldown` is a plainly-called predicate wearing the handler prefix — naming smell only.)
- **Orphaned .tres: ZERO** of 35 — weapons folder-scanned (`viewmodel_editor.gd:102`, `gun_range.gd:118`, bench, tests), all 12 projectiles explicitly loaded, theme + bus layout wired. Dormant content: `m72_law.tres`, `m79.tres`, `rpg7.tres` (+ their rockets) reachable only via scans/tests — staged for loadouts that don't exist yet.
- **Non-PATROL mission branches: ZERO.** All writers hardcode `"PATROL"`; readers display-only.
- **15 stranded probe scenes** (`tests/probe_perf_decay.tscn` + 14 `tools/probe_*.tscn`) — known category, `run_all_tests.ps1:22` globs `test_*.tscn` only; the suite-health INVOCATION register already tracks this class.
- **4 dev-only manual benches** kept: `scenes/levels/ps2_perf_probe.tscn`, `tests/perf_probe_cycle.tscn`, `tests/windowed_ao_look.tscn`, `tests/windowed_patrol_perf.tscn`.
- Piper TTS `.onnx.json` sidecars (11) and Blender pose-capture jsons (14) — functionally required / restore-on-demand per workflow. Not fossils.
- Oddity, not a bug: `player.gd:645` emits another node's signal (`prisoner.died.emit(prisoner)`).

---

---

# ROUND 2 — AI states, animation graph, enum/export sweep (same day)

Triggered by the report of unfinished crouch-related AI states. Three passes over the categories round 1 couldn't see: state-machine graphs, the anim-clip graph, and the declaration kinds `test_fossils.gd` doesn't scan (its regexes at `tests/test_fossils.gd:240-245,296-300` catch const/signal/func only — **enum members, @export vars, and member vars are invisible to the ratchet**).

## R2.1 THE CROUCH FINDING — the ally half of deferred Part B

The Wave-4 machinery (`_low_posture`, speed caps, `cover_to_stand`) and Part A's shared `CombatPosture` are fully wired and probed on both factions. The "unfinished crouch states" are AllyBase's missing half of the class merge (deferred per `production/AI_LIVING_WORLD_ROADMAP.md:62-69`):

- **AllyBase wires 4 of 9 AIStates.** `ALERT`, `SUPPRESSED`, `FLANKING`, `ADVANCING`, `RETREATING` are never entered and never handled ally-side; the `_execute` match (`ally_base.gd:653-659`) has **no default arm** — a leaked state produces a statue (aims, no behavior). Verified 2026-07-25.
- **Allies have no stand-to-push.** `CombatPosture` rows `ADVANCING/FLANKING/RETREATING → STAND` (`combat_posture.gd:18`) and `SUPPRESSED → CROUCH` (`:20`) are unreachable for allies; an ally in COMBAT is always CROUCH, so closing on a target happens at the 1.9 m/s crouch-walk cap (`ally_base.gd:478-483`) forever. Enemies stand and push via ADVANCING; the player's squad structurally can't. `tests/test_low_posture.gd:156-157` passes by hand-setting a state live ally code never reaches — it proves the table, not the wiring.
- Ally `intent_for` hardcodes `sneaking=false` (`ally_base.gd:408`) — the whole sneak clip family is unreachable for allies (also `is_crippled`/`is_surrendered` hardcoded false: no ally crippled/surrender visuals, likely by design).
- The cover-pose presentation layer (wall-lean `_wall_within`, arrival leap/roll, crouch hold/peek overrides, `ally_base.gd:804-948`) exists **only** in AllyBase; EnemyBase has none of it. Working, but one-sided — the other face of the same seam.
- `ai_stress_arena.gd:1951-1954` counts ally RETREAT goals — always 0 for the arena's whole life (allies can't hold RETREAT). Dead telemetry.
- `AIGoal.HOLD_POSITION` is write-only ally-side (only the `!= NONE` dwell gate reads it) — a label, not logic.

## R2.2 Bugs found in round 2

| # | Evidence | Finding |
|---|---|---|
| R2.2.1 | `save_manager.gd:30,185,194` | **`pending_hub` is loaded from the save file and never applied.** The comment claims GameFlow applies it "after the hub spawns"; nothing reads it. The hub section of every save is silently dropped. |
| R2.2.2 | `model_actor.gd:719-724` + `sprite_state_map.gd` MODEL_CLIP | **`idle_aiming__smg` is unreachable.** `play()` strips the `__smg` suffix BEFORE consulting MODEL_ALIASES; idle/aim map to the v1 name `rifle_aiming_idle`, so PPSh carriers land on plain `idle_aiming`. The authored SMG idle hold never plays for the highest-traffic intents (the other 8 `__smg` clips hit directly). |
| R2.2.3 | `ally_base.gd:234` | **`LOW_POSTURE_SUPPRESS` will fail the fossil suite on its next run** — const-kind, in scan scope, not in baseline. Superseded by `CombatPosture.CROUCH_SUPPRESS` (`combat_posture.gd:11`) in the 7/23 merge; enemy_base's copy was deleted, ally_base's wasn't. |
| R2.2.4 | `projectile_data.gd:25` | **`aoe_damage_falloff` is a dead knob under active tuning** — set in 11 projectile .tres files, read by zero code. Explosion falloff happens elsewhere; designers are turning a disconnected dial. |

## R2.3 Dead enum members (probe-invisible kind)

- `enums.gd:12-17` — **entire `Condition` enum** (NONE/BLEEDING/BURNING/SUPPRESSED/STUNNED): zero references repo-wide. The status-condition system was never built; bleed lives in GUT hitzone logic, suppression in `suppression_level`.
- `enums.gd:59` — `AIGoal.REGROUP`: never scored, set, or matched. The 7/23 council review already ruled "wire or cut" (`war_room/archive/2026-07-23_root_logs/COUNCIL_REVIEW.md:55`); neither happened.
- `cas_airplane.gd:9` — `Phase.RELEASE`: state machine uses a bool `_released` (:131) instead; the phase is never assigned or matched (`RELEASE_ALT` const is live).

## R2.4 Write-only / never-touched member vars (24)

Crouch/AI-relevant: `enemy_base.gd:27 state_timer` (+= but never read — while ally's IS read :844,:911: live-divergence), `enemy_base.gd:213 incoming_fire_timer` (set 0.5, never read/decayed), `enemy_base.gd:33 last_think_time` (the CLAUDE.md-documented half-buried fossil), `enemy_base.gd:93 move_target`, `enemy_base.gd:99 cover_quality` (3 writes, 0 reads), `camp_director.gd:39-40 patrol_anchor/has_patrol_anchor`, `weapon_holder.gd:39 is_firing` (assigned false at 4 sites, never true, never read).

Others: `field_director.gd:142 cas_budget`, `mission_state.gd:23 civilian_deaths` (incremented, no consequence system reads it — hearts-and-minds seam), `sim_clock.gd:20 debug_bt`, `ai_stress_arena.gd:234 _state_history`, `destructible_vehicle.gd:7 is_destroyed`, `helicopter.gd:114 traffic_flight_id`, `model_actor.gd:100 norm_k`, `radio_handset.gd:39 holder`, `civilian.gd:30 _timer`, `paddy_field.gd:9 centroid_local`, `terrain_chunk.gd:13 is_loaded`, `terrain_engine.gd:35 current_preset`, `tree_cover_layer.gd:56 _loaded` (unchecked — while `jungle_patch_layer.gd:84`'s IS checked: second live-divergence pair).

Also: `enemy_data.gd:8` + `weapon_data.gd:8` `description` exports set in .tres, read by nothing (probably intentional designer-doc fields — bless or delete).

## R2.5 Animation graph findings

Library ground truth: exactly **100 clips** in `assets/shared/anim_library.glb` (decoded from the imported .scn artifact; no static manifest exists). Nothing T-poses — every request resolves via `__` strip or alias. But:

- **~44 of 100 shipped clips are orphans** nothing requests (jump family, swim, turns, walk/run diagonals+backpedal, `brutal_assassination`, cockpit/pilot clips, `cover_to_stand_2`, `crouched_sneaking_l/r`, …). Matches the 7/12 audit's "AI uses ~13 of 100." Shipped weight, zero play paths. Note `tools/probe_anim_audit.gd:73-75` excludes `death*/walk*/*turn*` by prefix, so its own orphan count under-reports.
- Dead MODEL_CLIP intents: `"reload"`, `"flinch"`, `"strafe"` — `intent_for` never produces them, so **enemies never show a reload animation** (`reloading`/`reloading__smg` play only in the gore lab). `"start_walking"` token in `_to_crouch` match (`sprite_state_map.gd:101`) is a clip name where an intent belongs — never matches.
- `strafe_1` alias candidate (`sprite_state_map.gd:156`) can never match — clip renamed `strafe_2` at export (`export_anim_library.py:47-49`). `_CLIP_SPEED` (`model_actor.gd:773`) lists all three strafe names; none ever plays.
- `RUSH_CLIPS` (`ally_base.gd:250`): only element [0] is ever used (:883); elements 1-2 dead.
- Crouch coverage itself is SOUND — all six crouch intents + `cover_to_stand` resolve to real clips; no crouch state falls back to a standing clip. Genuine content gaps: **no crouch-fire clip** (low firing man holds static `idle_crouching_aiming`) and **no posture-aware death** (`_die` picks standing deaths; a crouched man pops upright to die; `death_crouching_headshot_front` reachable only via the random gore ladder). `crouched_sneaking_l/r` authored but bypassed (sneak uses `cover_sneak_l/r`).
- Soft edge: `cover_to_stand` has no MODEL_ALIASES entry — a rig missing it freezes pose 0.8 s instead of aliasing (currently masked by the shared library carrying it).
- No `__bolt`/`__mg`/`__launcher`/`__pistol` clip families exist — Mosin/RPD/RPG/M60/M79/M1911 carriers silently play rifle holds (known wishlist Batch 7 gap, silent by design).

## R2.6 Other round-2 fossils

- `scripts/ai/bt/bt_conditions.gd` (`BTCondition`) — preloaded at `civilian.gd:14`, `.new()` called nowhere; the civilian tree is BTActions only. The preload is the tombstone keeping it off zero-reference greps.
- `ActionType.NONE` write-only (`action_progress.gd:6`) — benign reset sentinel, not a fossil. Cleared.

## Recommended next actions (owner's call; all changes = War Room per standing law)

1. **Fix or kill the two BUGS** (§1): temple shrines (fix = generator + group add, or delete the player-side code), wave_runners (register runners or delete the no-op loop).
2. **Ratchet the stale registers** (§2): 10 debt entries removable; fossil register untouched (all 19 honest).
3. **One deletion wave** for §3: 10 register fossils + 9 expired diagnostics + allies.zip + 8 dead groups + `export_grunt.bat`/`make_soldier_lineup.py` (fix or delete) + the misleading comments in §4.
4. **Doc corrections** (§4 doc-side): banner or fix `audit_structure.md:258`, GAME_GUIDE.md:93, ADR-008/ADR-010 stale citations.
5. **§5 clusters are roadmap items**, not cleanup: grenade-cook HUD is the cheapest to finish; heli/seat cluster stays parked with ADR-029.
