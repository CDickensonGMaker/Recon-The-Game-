# BRIEFING — Playtest bundle (7 items), 2026-07-19

Summoner-approved bundle. ONE council for all seven. Do not sprawl beyond them.

## CONSTRAINTS (binding)
- Godot 4.7 ONLY. Headless probes only — never spawn windowed Godot on the owner's desktop.
- Every item needs a NEGATIVE-CONTROLLED probe: prove the probe fails when the fix is reverted.
- Comment discipline (no history narration). Fossil law ADR-023 (delete what you replace).
- OUT OF SCOPE: squadmate-glued-to-player (akx8/WA), the W0/WA/WB/WC/WD chain, terrain conform,
  firebase elevation, any Blender/art work, texture repairs, the `ggct` tag deletion.

## RECON FINDINGS (measured this session — do not re-derive)

### Item 1 — RTO / fire mission. THE BRIEFED PREMISE IS FALSE.
The RTO chain is **already wired end to end**. Bead `f0kv` does NOT block it:
- `squad_roster.gd:64,169-174` guarantees an RTO slot; `squad_system.gd:93-94`
  `DETERMINISTIC_MOS_BODY = {"RTO": "us_grunt_rto"}` always gives the RTO the radio-bearing body.
- `model_actor.gd:319` `CARRIES_RADIO = ["us_grunt_rto"]`; `:329-330` `_apply_optional_gear` returns
  EARLY for that unit, so the PRC-25 is baked in and never hidden. Promotion cannot fail.
- `grunt_randomizer.gd:128-131` `_radio_legal` pre-filters, so the `grunt_dresser.gd:79-84`
  warning branch is unreachable in live play (test-only).
- `f0kv` is about the **cosmetic 35% radio roll** on rifleman/pointman flavour spawns
  (`grunt_randomizer.gd:19` RADIO_CHANCE) — not the RTO role, not fire support.

**THE ACTUAL DEFECT (new, measured):** `director.fire_support` is **never assigned from any plan**.
`grep -rn "\.fire_support\s*=" scripts/` returns ZERO hits. `mission_generator.gd:437`
(`"fire_support": {"mortar": 1}`) is dead data nothing reads. So the live budget is forever the
hardcoded default at `field_director.gd:194`:
`{"bombs":0, "napalm":0, "arty":0, "mortar":2, "spooky":0, "cbu":0}`.
Consequence: the player opens the net (T) and **five of six verbs answer "NONE AVAILABLE"**.
Only mortar (key 4) has stock. That is almost certainly what the owner hit.

Secondary, confirmed: `cbu_strike` and `place_claymore` are BOTH bound to physical keycode 54
(`project.godot:146-149` vs `:191-194`). `radio_handset.gd`/`radio_cord.gd` are FOSSILS (zero
callers, zero .tscn refs, `"radio"`/key G bound but never read) — already in `fossil_baseline.json:30-35`.
Known gap (ADR-011 amendment, still open): `_danger_close_to_squad` (`field_director.gd:320-328`)
never checks the PLAYER's own distance.

### Item 2 — completion verb. THERE IS A CANON CONFLICT. Council must resolve.
- `mission_state.gd` objective API is complete and tested but **DEAD**: `register_objective` (:21-27)
  and `complete_objective` (:30-35) have exactly ONE caller each — `tests/test_mission_state.gd`.
- **ADR-029 (open patrol simulator, DRAFT but its code is LIVE) forbids exactly this**:
  "No player-facing mission tracking, ever… Objective tracking dies… Floating objective markers are
  forbidden." `game_flow.gd:305-306` and `mission_hud.gd:251-253` implement that deletion.
- So wiring the tunnel into `mission_state` builds on a system current canon declared dead, and
  nothing would display it. **This is a War-Room-shaped decision, not a code question.**
- Tunnels ARE wired as interactables: `site_planner.gd:185-186` adds group `tunnel_entrances`;
  `player.gd:207-251` handles enter/loot/exit. No HUD prompt exists (r4bk risk).
- `demolitions` skill (`skill_catalog.gd:10`) is a purchasable, levelled skill backing **zero code** —
  no charge, no inventory item, no plant verb. Nearest reusable shape is `sapper_charge.gd` (enemy).
- Interact patterns available: centralized group-scan (`player.gd:212-317`) or self-contained
  hold-to-act with a world Label3D prompt (`armorers_bench.gd:18,56-64,75-83`).

### Item 3 — patrols static at range (`cvej`). THE BRIEFED PREMISE IS ALSO WRONG.
"Activity-tiering keeps out-of-range units cheap" is **not** why they look static.
- **Distance NEVER stops movement.** `_execute(capped_delta)` runs every physics frame
  unconditionally (`enemy_base.gd:500`); `_execute_patrol` (:1887-1915) advances waypoints and sets
  velocity regardless of range. A far patroller walks at full fidelity.
- **ADR-026 hot-set tiering only applies to units already in COMBAT** (`enemy_base.gd:584-590`,
  `enemy_squad.gd:37-38` HOT_CAP 12 / CEILING 16). The code comment at :584 says it outright:
  "Non-combat units are never tiered." Patrol/idle men never touch that budget.
- The only distance scaling is `_update_think_lod` (:40-55): think cadence 0.15 → 0.3 (>80m) →
  0.6s (>150m). That throttles goal re-evaluation, **not locomotion.**

**THE THREE REAL CAUSES:**
1. **They do not exist yet.** `LazyGroup.activation_range` defaults to **120.0**
   (`lazy_group.gd:8`) for village/camp garrisons (`mission_generator.gd:654-663` never overrides
   it); ambient corridor patrols get **140.0** (`mission_generator.gd:582`). Beyond that, the men
   are not spawned at all. Nothing can look alive when nothing is there.
2. **Garrisons spawn as SENTRIES, not patrollers.** `LazyGroup.force_spawn` (:59-90) only hands out
   `patrol_route` + `patrol_file_slot` when `group_tag` starts with `"ambient_patrol"` (:63-89).
   Village/camp garrisons therefore stand still by construction.
3. **The body gate freezes stationary men.** `_body_gate_open()` (`enemy_base.gd:523-538`) skips
   `move_and_slide`, hitzone sync and `_update_sprite` (:512-514, :452-459, :1298-1299) unless the
   unit is perceivable — `CombatManager.perceivable()` (`combat_manager.gd:45-58`,
   `PERCEIVE_RANGE = 150.0`). A standing sentry past 150m has his animation refreshed only by a
   300ms heartbeat (`BODY_HEARTBEAT_MS`, :147).
   **Crucially, `velocity.length_squared() > 0.01` re-opens the gate on the very next frame (:528).**

**So the cheap, correct lever is to make garrison men MOVE** — a moving man self-opens the body
gate and needs no perf concession at all. `work_pos` already drives idle walking
(`_execute_idle`, :1350-1359) and `CampDirector` writes it (`camp_director.gd:85-120`), but
patrol/sleep/guard roles get `work_pos = Vector3.ZERO` (:100-101) so those men never walk.

**PERF NUMBERS (measured, `PERF_LEDGER.md:265-284`, 65-67 live units):** think = 1.2-1.28ms (~3%);
move_and_slide 8.8-9.1ms (~23%); hitzone sync 9.9-10.4ms (~26%); anim/execute remainder
17.6-19.0ms (~48%). **The BODY is ~95-97% of AI cost, the BRAIN ~3%.** Therefore raising
`activation_range` is the EXPENSIVE lever (it creates bodies) and is where the tradeoff must be
named. Only 9.4% of units were gated at hub start (`PERF_LEDGER.md:333-347`) precisely because
LazyGroups had not materialized.
Headcounts: 4-7 defenders/village, 4-6/camp (`mission_generator.gd:538,541`), 2-4 men × 2-3 ambient
patrol groups (:572,580).

### Item 4 — flinch / death theater (slice of `8l06` ONLY).
- Non-fatal hit today = 0.1s red flash (`enemy_base.gd:2124-2131`) + 0.25s fire stall
  (`:2159-2161`, comment says "Flinch" but no pose changes) + optional forced SUPPRESSED crouch
  (`:2163-2167`, `apply_stagger` :2279). **No flinch clip, no procedural reaction.**
- `sprite_state_map.gd:138` maps `"flinch"` → `rifle_aiming_idle`, and **nothing ever emits the
  "flinch" intent** — dead dict entry.
- Death: `_die()` (`:2344`) → ragdoll by default (`:2383-2385`); performance clips only on gibbed
  kills (`:2386-2398`), chosen by a **binary left/right** test. No hitzone or stance awareness.
  `death_from_the_left` does not exist (`ANIM_WISHLIST.md:12`).
- Design intent (`ANIM_WISHLIST.md:16,57`): flinch is **procedural** (spine-punch
  SkeletonModifier3D), explicitly NOT new authored clips. Beads xphx/ylma were absorbed into open
  epic 8l06, never built.
- DO NOT open barks/tracers/QRF — those amendments are pending ratification.

### Item 5 — punji traps (`yevg`).
`punji_trap.gd` (68 lines) is a plain `Node3D`: no Area3D, no collision, no health, no
`take_damage`. It 5Hz-polls `TRIGGER_RANGE = 1.4` (:42-57) and springs for 35 damage (:60-67).
`CombatManager.apply_explosion_damage` (`combat_manager.gd:138-220`) iterates exactly FOUR
registries — player, `AgentRegistry.allies`, `.civilians`, `.enemies` — so blast cannot reach a
trap. Reuse the civilian hitzone path (`civilian.gd:22,124-125`, layer 512;
`hitzone_builder._build_static` :559). **Do not invent a second damage router.**
Note: this council DEFERRED traps this morning (F6) as "a feature, not polish." The Summoner has
now explicitly thawed it.

### Item 6 — informer (`1x5a`).
- `civilian.gd:159-165` starts the inform clock on **distance alone (<15m), no LOS** — the one
  perception system that never learned ADR-005.
- `civilian.gd:312-330` `_transform_to_vc` writes `director.state.flags["informer_transformed"]`
  and `["informer_last_pos"]`, with a comment claiming a director handler reads them.
  **Nothing reads either flag** — `state.flags` (`mission_state.gd:18`) is write-only debrief data
  copied out by `build_result` (:93-97). The comment is a truth-law violation.
- The canonical LOS helper is `CombatManager.has_line_of_sight(from, to, exclude)`
  (`combat_manager.gd:288-300`) — used by `enemy_base._can_witness` (:740-754), `_witness_check`
  (:771-772), `ally_base.gd:491`, `mission_trigger.gd:187`. Use it; never a camera-look fake.
- Handler shape to copy: `_check_detection()` (`field_director.gd:70-77`), a one-shot-guarded poll
  driven from `_process_escalation`. Spawn helper exists: `spawn_tracked_enemy` (:30-44).

### Item 7 — squad nameplate (owner: appears upper-left; wants it above the man's head).
**Root cause found.** `squad_nameplate.gd:22` calls `set_anchors_preset(Control.PRESET_CENTER)` on a
Control that is never given a size. With `keep_offsets=false` the call preserves the node's CURRENT
rect — default `(0,0,0,0)` — so anchors move to centre while offsets compensate to keep it pinned at
the origin. Parent is `MissionHUD extends CanvasLayer` (`mission_hud.gd:4`), added bare at `:31`, so
there is no parent Control rect either. The inner VBox sits at `position = Vector2(0,48)`
(`:26,28`), which exactly reproduces "upper left, a bit down."
`_process` (:51-64) **never computes a screen position at all** — the 3D chest point is used for the
angle/LOS test then discarded.
Every sibling HUD child uses the same CanvasLayer parenting but escapes the bug by following the
preset with an explicit `.position` (compass :40-44, toasts :49-51, slot slider :57-59, fire panel
:83-85, squad panel :187-189). The nameplate is the ONLY one trusting the preset alone.
House projection pattern to copy: `mission_hud.gd:254-283` `_update_markers` —
`cam.is_position_behind(pos)` guard, then `cam.unproject_position(pos)`, then write
`label.position`, parented under a `PRESET_FULL_RECT` Control (`_marker_box`, :35-38).
Anchors: `AllyBase.global_position` is FEET; `ModelActor.TARGET_HEIGHT_M = 1.7132` (:18,64-65) is
the canonical head-top (ADR-002). Name data lives in `AllyBase.member` (`ally_base.gd:102`);
rank via `SquadRoster.rank_for`. There is no head marker node on AllyBase.

**LOCKED BY THE SUMMONER (narrowed mid-session):** `LOOK_RANGE = 5.0` and `LOOK_CONE_DEG = 12.0`
are NOT to be widened. Classic-CoD behaviour: close, and looking straight at him. ALLIES ONLY holds
(Pillar 3 — reading an NVA name off his chest is free intel). The ONLY change is where it draws.
If world-space at 5m/12° feels wrong, REPORT it — do not loosen the cone or range to fix it.

## QUESTIONS FOR THE COUNCIL
1. Item 2 is the real decision: ADR-029 forbids objective tracking, yet the owner demands a legible
   "the area is finished" signal. What satisfies BOTH the owner and Pillar 3 (no rails, no quest
   log)? Does the answer use `mission_state` at all, or a diegetic route (toast + world state)?
2. Item 1: is the fix simply to inject budgets, and what budget is honest for an open patrol sim
   with no briefing? Naming a budget is a balance decision.
3. Item 4: procedural spine-punch vs. clip-based flinch, given the art debt and PS2 perf budget.
4. Item 3: what is the honest perf tradeoff for visible mid-range life, and what number gates it?
5. Item 5: does a destructible trap need hitzones at all, or is a single body + health enough?
6. Which of these seven can be probed HONESTLY headless, and which cannot (and must be reported as
   unverified rather than claimed)?
