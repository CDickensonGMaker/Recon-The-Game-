# DEMO-ARC AUDIT — the 30-minute day, beat by beat
2026-08-13 full-project audit · DEMO-ARC AUDITOR · AUDIT ONLY, nothing changed.
Product: `scenes/levels/demo_game.tscn` → `scripts/levels/demo_game.gd` (switchboard + arc clock), 512m map, EA target 2026-09-06.

Every claim below carries a pointer. Statically unverifiable items are named as such with the runtime check that closes them.

---

## VERDICT PER BEAT

| Beat | Status | Anchor |
|---|---|---|
| Boot seated on the bunk | PASS | game_flow.gd:151-219, :636-663 |
| Squad moves out T+10s | PASS | demo_game.gd:348-409 |
| Day on the garrison schedule | PASS (arc wiring) | field_director.gd:1423-1427, :1480-1489; heli_lift.gd:151-154 |
| Night seam + ratio drop | PASS | demo_game.gd:437-441; sim_clock.gd:62-69; mission_weather.gd:80-95 |
| Probe at the wire (1395s) | PASS w/ NOTE N-3 | demo_game.gd:442-446; siege_director.gd:195-232 |
| The 45-man assault (1440s) | PASS w/ DEFECT D-2 | demo_game.gd:447-495; siege_director.gd:246-267 |
| Siege air show | PASS w/ N-4/N-5/N-6 | demo_game.gd:258-299; field_director.gd:617-673 |
| Gunships + ending | PASS | demo_game.gd:498-543; air_traffic.gd:218-318, :404-408 |
| End card, player lives | PASS w/ DEFECT D-1 | demo_game.gd:546-601; game_manager.gd:23-27 |

No SHIP-BLOCKER found in the arc code. Two DEFECTS (one stranger-reachable, one seed-conditional), two DRIFTs, seven NOTEs.

---

## DEFECTS

### D-1 · DEFECT (high) — QUIT TO MENU is an open door out of the demo into a broken half-arc
The demo runs in the hub context (`_in_mission=false`, game_flow.gd:750). Esc opens the pause menu, and the hub build always includes QUIT TO MENU (pause_menu.gd:61-62). From there:

- `_pause_quit` → `show_menu()` (game_flow.gd:383-385, :417-427) tears the world down and raises the real main menu INSIDE the running demo scene.
- NEW GAME → `start_default_operation()` → `_begin_operation(47225)` (game_flow.gd:493-501). `GameFlow.demo_mode` is still true (only `demo_game._exit_tree` clears it, demo_game.gd:181), so `enter_hub` builds a **512m plan_demo_world on seed 47225** (game_flow.gd:602, :619-620) — not the shipped DEMO_SEED world. CONTINUE does the same via the sandbox autosave (`enter_hub` saves one at :752).
- DemoGame's one-shot state survives: `_clock` resumes where it stopped (only freezes while `director == null`, demo_game.gd:413), `_gate_order_issued` / `_napalm_early_done` / `_night_ratio_set` / `_air_next` stay spent, and `SimClock.set_time(1, 6.5)` never re-runs — MissionWeather re-seeds 05:30 (mission_weather.gd:51), so the arc's constants no longer describe the clock. A player who quits at minute 20 and re-enters gets the probe ~3 minutes in, in daylight, with no opening beats.
- Worst of it: `_death_routed` is already true (demo_game.gd:415-426), so the NEW director's `mission_failed` stays wired to `_flow._on_mission_ended` (game_flow.gd:684) — death in the leaked world runs the REAL debrief/AAR pipeline the switchboard exists to exclude (`EXCLUDE_DEBRIEF`, demo_game.gd:25).

This needs no dev keys — two clicks any stranger can make. Fix shape (for the council, not applied): demo build of the pause menu drops QUIT TO MENU or routes it to `get_tree().reload_current_scene()` / quit, same verbs as the end card.

### D-2 · DEFECT (conditional, seed-dependent) — materialize distance is measured to the BENCH, not the compound center; 120m may not clear the far wall
- The siege objective is `siege_aim` = the armorer's bench (field_director.gd:1154-1157, :1283-1285), placed at `spawn_pos - gate_out*10` = **32m inside the gate on the gate bearing** (mission_generator.gd:956-961; spawn = gate − 22·out, site_planner.gd:1211).
- A dormant cell materializes when its distance **to the objective** ≤ `materialize_m` (marching_cell.gd:86-90). The demo sets `cell_materialize_m = 120.0` with the stated math "the parapet reaches 96.1m radius … 120m clears the widest face" (demo_game.gd:470-474) — that math is **center-based**, but the measure is **bench-based**.
- On lanes roughly opposite the gate, the materialize point sits at ~`120 − (gate_face_radius − 32)` metres from the center. The parapet runs 49.3-96.1m (siege_director.gd:70-75); for a gate face anywhere in 60-96m the far-side clearance is 56-92m from center — **inside** any far wall wider than that. Bodies can pop into existence inside the wire — the 2026-07-28 class the 120m constant was set to kill. The `_seen_outside` guard (siege_director.gd:599-624) correctly suppresses the false OVERRUN call, so it would not trip the siren — it presents as men appearing inside the compound, the quieter and worse version.
- Whether the shipped demo actually hits it depends on the seeded `sector_bearing` (deterministic: `hash(Vector2i(256,256)) ^ 0x51E6E`, siege_director.gd:147) and the GLB's gate radius — neither computable statically. **Runtime check:** print `|siege_aim − fsb_center|` and `sector_bearing` on the DEMO_SEED boot; exposure exists if any assault lane within sector±75° (SQUAD_SPREAD 150°, siege_director.gd:296) opposes the bench offset by enough that `120 − offset·cos(angle)` < wall radius on that bearing. Fix shape: measure materialize distance to `fsb_center` (or set demo `cell_materialize_m = 120 + |siege_aim − fsb_center|`).

---

## DRIFT

### DR-1 · DRIFT — END_AT_S survives in the docs of record after the ending was redesigned
The constant is gone: gunships fire on `siege_ended` with `END_BACKSTOP_S: 2700` as failure backstop only (demo_game.gd:60-73, :507-513; his ruling 2026-08-07 quoted at :60). Still citing END_AT_S as the live trigger:
- `CLAUDE.md:422` — the SESSION ENTRY GATE checklist itself ("gunships on station at `END_AT_S`").
- `production/GAME_GUIDE.md:418` — "every beat is tuned around `END_AT_S`", inside an open question queued for him.
The top of the canon hierarchy misdescribes how the shipped demo ends. Pointer-law correction on next touch.

### DR-2 · DRIFT — two stale pointers inside demo_game.gd's own comments
- demo_game.gd:39-40 claims the lighting boundary table `{5.5, 10.0, 17.5, 21.0}` lives at `mission_weather.gd:40`. That line is `TIME_ID_START_HOUR` — the **boot hour per briefing roll**. The boundaries that actually flip the lighting and `is_night` are `sim_clock.period_at` `[5, 7, 17, 19]` (sim_clock.gd:62-69 → mission_weather.gd:80-95). The arithmetic the demo depends on (seam at 19.0 → ~1184s) is correct; the citation is not.
- demo_game.gd:52 cites the `_granted_day` exploit comment at `field_director.gd:1240-1245`; it now sits at field_director.gd:1446-1453.

---

## NOTES

### N-1 · VERIFIED FIXED — mortars-on-end-card, held by two independent locks
1. The ranging walk runs only inside `_run_siege` while `active` (siege_director.gd:374-392); `_break_siege` clears `active` **before** emitting `siege_ended` (siege_director.gd:745-773), so mortars are dead before the demo even hears the raid ended.
2. `_show_end_card` → `GameManager.pause_game()` → `get_tree().paused = true` (demo_game.gd:560, game_manager.gd:23-27); the world subtree is PAUSABLE (game_flow.gd:599) and SiegeDirector lives under FieldDirector under world (field_director.gd:1657-1658) — the backstop path (siege still active) freezes with everything else. The card itself is `PROCESS_MODE_ALWAYS` layer 90 (demo_game.gd:587-589).
Preemption guards all hold: `_on_raid_ended` returns at `_phase >= 3` (:508), `_ending` yields to an existing death card (:541-542), `_show_end_card` is idempotent (:557). Death during the gunship wait: death card wins, ending loop exits on `_card != null`. Correct at every beat.

### N-2 · VERIFIED — one boot path, no drift; nav-truth change touches nothing hard-coded
- `project.godot:22` `run/main_scene.demo` → demo_game.tscn; `demo_mode` set before `GameFlow.new()` (demo_game.gd:117-118); GameFlow._ready early-returns on demo_mode (game_flow.gd:31-35); single branch to `plan_demo_world` (game_flow.gd:619-620). `test_range.gd:52` and `tools/probe_*.gd` consume the planner/scene as benches, not boot paths. `plan_demo_world` pins `"weather": "CLEAR", "time": "DAWN"` (mission_generator.gd:706) so `is_night` cannot be true at boot and the seam latch (demo_game.gd:437-441) cannot pre-fire.
- Grep of demo_game.gd + siege_director.gd + game_flow.gd for literal 174/175 heights: **zero hits** (only demo_game.gd:261's `175.0` — an air-beat RANGE, not a height). Spawn Y comes from authored `spawn_bunk*` markers used as-placed (game_flow.gd:151-184) with the 5.5m floor-reach fallback (:148); everything else flows through `surface_y`/`get_height_at`. The navmesh-rides-the-mound change breaks no demo position.

### N-3 · NOTE — the probe's announced identity is the mortar volley; probe bodies barely precede the assault toast
`_walk_mortars` has no `is_probe` gate (illum and press do, siege_director.gd:491-516): the first 3-round volley fires within the first siege tick of 1395s, bench-aimed at 50m dispersion, 140/40 damage (siege_director.gd:642-650, :45-53). Meanwhile probe cells spawn at ring 190-235 and march dormant at 2.2 m/s to the ~120m materialize line — first bodies ~1430-1450s, straddling the 1440s "HERE THEY COME" toast. So the beat the player experiences at "probe" is *incoming 81mm*, and the two toasts land ~45s apart with rifle contact starting after the second. Deliberate per the ILLUM comment ("the mortars still announce the night themselves", siege_director.gd:88-90) — but the Summoner should confirm the probe reads as a beat and not as the assault arriving twice.

### N-4 · NOTE — pending siege air beats keep firing for up to ~25s after the raid resolves
`_tick_siege_air` gates on clock and index only, never `_phase` (demo_game.gd:283-287). A raid broken early leaves later beats (+150/+205/+255/+300) firing through the gunship fly-in window (`GUNSHIP_WAIT_MAX_S` 25.0, :522) until the card's pause stops the tick. "LAST PASS - EVERYTHING THEY HAVE" can toast after "GUNSHIPS ON STATION". Bounded and arguably in-fiction; a `_phase < 3` guard would silence it.

### N-5 · NOTE — the 260m "away" BOMB beat can stage past the 512m map edge
Beat 1 targets 260m out on `sector+PI` (demo_game.gd:259, :293-297); the fsb sits 256m from every edge, so bearings within ~10° of a map axis (~22% of the compass, seed-fixed) put the target off-map. Heightmap sampling clamps to the edge cell (heightmap_storage.gd:72-79) so it degrades to a rim-height flash ~460m+ from the player at night — no crash, plausibly invisible. All other beats verified on-map at their worst case: napalm strip extreme point ~sqrt(210²+88²)+30 ≈ 258m < 362m corner reach and inside 512 on axis bearings; CBU extreme ~250m.

### N-6 · NOTE — pure-GUNS beats self-cancel when the player fights at the wire on the attack side
Every gun axis passes through the target (sample span −100..+210m of it, field_director.gd:628-643); if the player is within ~69m of a 165m-out target no rotation clears `GUN_STANDOFF_M` 120 and the beat is refused outright (:670-672) — GUNS_NAPALM degrades to napalm instead (:666-669). Beats 3 and 6 (demo_game.gd:261, :264) can silently vanish at the climax if he holds the parapet on the sector bearing. This is his own 2026-07-30 discipline working as ruled; named so nobody later reads the missing passes as a stuck system (the pilot-encounter precedent).

### N-7 · NOTE — AIR_OPENING beats can be swallowed by the airframe ceiling
`_dispatch` binds `MAX_IN_FLIGHT` 14 on every caller (air_traffic.gd:517-521) and a huey "transit" is a 6-9 ship pack (:39). The opening fires six launches in 95s (demo_game.gd:200-207) and `_air_next` advances whether or not the launch flew (:324-327) — beats 3-6 can be silently dropped on a crowded sky. The 2026-08-04 audit's ask (print `_in_flight.size()` at the ending) still stands as the measurement.

### N-8 · NOTE — backstop path crosses sim midnight; harmless under current gates
Backstop at 2700s puts sim ~03:25 next day (20x from the 19:00 seam) — `sim_day` increments, `_granted_day` re-arms (field_director.gd:1450-1453), and the demo allotment (3 bombs, :1480-1489) could be re-granted on a wire re-cross. The rogue second siege is already gated (`_maybe_open` demo return, siege_director.gd:169-172). The backstop is practically unreachable anyway: with any siege attached, `MAX_DURATION_S` 480 counting from the PROBE's open (reinforce deliberately keeps `_elapsed`, siege_director.gd:246) hard-ends the raid by ~1875s (re-opened-after-break case: ~1920s) — "dawn" reason → ending fires from `siege_ended`, ~14 minutes before the backstop.

### N-9 · NOTE — debug dev-keys are live inside the demo on debug builds
[U] clock-speed cycle / [O]/[I] time skips (game_flow.gd:68-124) would shred the arc's constants mid-run. Gated by `OS.is_debug_build()` — inert in the release export the demo ships as. Worth remembering during debug-build playtests: a stray [U] is a broken arc, not a bug report.

---

## TIMING LEDGER (all re-derived, all consistent)
- Seam: 06:30 at 38x → NIGHT 19.0 at **1184.2s** (demo_game.gd:46-48 claim ✓). M-6 spot-check: +60s = 07:08 ✓ (:429-432).
- Probe 1395s (sim ~20:10) > seam ✓; assault 1440s (sim ~20:25); both same night, no midnight crossing on the normal path (raid cap 1875-1920s → sim ≤ ~23:00; comment's "~22:25" at :54 assumed an 1800s end — the "same sim day" claim it exists for still holds).
- Assault window 1440→≤1875 = 435s ≈ the "360 s of it" the beat table assumes (:58); last air beat at +300 (=1740s) lands inside it ✓.
- Escalation ledger: reinforce grows strength AND peak (siege_director.gd:246-267); broken-probe re-open handled by the `elif forced_strength` branch (:206-213); the raid-end watch arms on BOTH the reinforce and open paths at `_phase==2` only (demo_game.gd:487-495, :500-505), so a probe that breaks at phase 1 cannot end the demo ✓.
- Geometry vs the 512m map (fsb at 256/256, mission_generator.gd:719-720): ring 190-235 on-map at every bearing (235 < 256); rally 150 on-map; mortar tube standoff 170 on-map (audio position only, siege_director.gd:677-681); REAP_RADIUS 600 unreachable → reap resolves by rally-arrival or the 90s timeout (:779-803), no ghost leak.
- Napalm vs today's ~60m/drop visuals (FirePlan: 9 drops × 22m spacing, 30m blast/fire radius — fire_plan.gd:31-34): at NAPALM_RANGE_M 210 the nearest flame is ~180m from center, ≥84m clear of a player at the widest (96.1m) parapet; the ~236m strip stays on-map on every bearing. Late beats at 195 (sector) put fire from ~165m out — behind the wire, on/behind the 190-235 ring, as authored. **210 still stages clear and inside view; no change needed for the new visual size.** Benches agree (vfx_range.gd:51, support_fire_range.gd:581).
- Early napalm bearing PI*0.5 (+Z, demo_game.gd:277): "opposite the gate" is consistent with the planner treating +Z as the treeline flank (`treeline_watchers` at +Z·190, mission_generator.gd:814-819) but the gate bearing lives in GLB markers (site_planner.gd:1197-1211) — unverifiable statically. The boot print (":.0f deg" line, demo_game.gd:313) answers it on any run; safe regardless (min ~84m flame clearance above).

## DEATH PATHS (EXCLUDE_DEBRIEF true) — verified per phase
`mission_failed` is re-routed once, precondition-gated on the real wire existing (demo_game.gd:415-426; wire lands at game_flow.gd:684, same synchronous block as the spawn — no exposed frame). Death at ANY phase → `_on_demo_death` → phase 3 → "YOU FELL BEFORE DAWN" card → pause; siege/air/mortars freeze with the tree; later `siege_ended`/backstop cannot preempt (guards in N-1). Pause-menu ABANDON is absent in hub build ✓; SAVE goes to the sandbox ✓ (`campaign_demo.cfg` / `saves_demo`, demo_game.gd:100-109, restored at :183-188). The one leak is D-1's menu door.

## SUPPRESSION-CLASS WATCHLIST (the pilot-encounter precedent)
- S28 pilot chain is a conditional ladder: camp placed (has fallback + warning, mission_generator.gd:825-844) → `zpu_crew` tag → passable gun point → `ZpuGun.attach` + `PilotRecovery.attach` (mission_generator.gd:916-925). Any rung failing on the shipped seed kills the encounter silently except one push_warning. End card reads the flags either way (demo_game.gd:576-581). Runtime check on DEMO_SEED boot log: `[DEMO]` camp line + ZPU attach.
- Ambient encounters flag is stamped (`p["ambient_encounters"] = true`, mission_generator.gd:873) and consumed at :953-954 ✓.
- Demo hunter-pool floor 6 (field_director.gd:1423-1427) and heli EXTRACT→ROTATE (heli_lift.gd:151-154) both alive ✓.
