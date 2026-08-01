# TECHNICAL-DIRECTOR — Individual Sight, Demo Ship Audit (2026-07-31)

Lens: ship stability + wiring risk for ~2026-08-09. Spot-checked 2 of 3 allowed points: `scripts/autoload/sim_clock.gd:92` (dedup key IS `day-hour-kind` — one event per kind per hour, confirmed) and `scripts/main/game_flow.gd:29` (`start_default_operation()` runs unconditionally in `_ready`; `demo_mode` static at :545 forks later — double build confirmed).

## 1. Risk ranking — likelihood-of-embarrassment in a stranger's hands

| # | Risk | Embarrassment odds | Why |
|---|------|--------------------|-----|
| 1 | **No export preset / never a .exe** | CERTAIN if unaddressed | There is no demo without it. Everything else is conditional on this existing. |
| 2 | **EXCLUDE_DEBRIEF inert — player death freezes the arc** (`demo_game.gd:244-245`) | HIGH | This is a d50/2d6 night siege; a stranger WILL die. Death → world teardown → demo_game returns forever. Textbook silent-freeze: game "looks alive" (siege audio, ambient), arc is dead. |
| 3 | **Undismissable end card over live captured game** | HIGH | Every run ends here. Mouse captured, no pause, Esc builds PauseMenu UNDER the card. Stranger's last memory is a softlock. Pairs with #8. |
| 4 | **SimClock air-dedup swallows scheduled air + day-rollover kills ambient air at t≈213s** | MEDIUM-HIGH | "Air spectacle" is a ship-gate pillar. TRANSITS_PER_HOUR=3 is effectively 1; after rollover, 0. Partially masked by the demo's own 42s cadence — which is exactly why it's a silent-freeze cousin: the sky slowly empties and nobody can say when it broke. |
| 5 | **End card at t≈500s vs dawn card at 420s, siege still live** | MEDIUM | 80s window where "you survived the night" plays over an ongoing assault. Reads as broken scripting to any observer. |
| 6 | **512m siege-geometry override landmine** (bodies off heightmap, mortar 700m out) | MEDIUM | Flagged in DEMO_PERF_PLAN §0.4, never exercised. If it fires it fires every run. |
| 7 | **Double world-build per boot** (`game_flow.gd:29`) | LOW-MEDIUM | Wasted seconds + doubled boot-time hitch on unknown stranger hardware; also a state-leak vector (anything the thrown-away build registers in autoloads survives). Cheap to fix, cheap to leave. |
| 8 | **HeliLift never run in-game / BOARD_CLIPS empty** | MEDIUM | Huey landings are a ship-gate pillar and the whole chain is statically clean but dynamically UNPROVEN. Embark teleport is the known bug-class signature. |
| 9 | **reinforce() double "STAND TO" at t=60s** | LOW | Audible duplicate, not a freeze. |
| 10 | **M60 hip_position 0,0,0 → rounds 50m out** | LOW-CONDITIONAL | Only if M60 is in the demo loadout. If it is: HIGH — first trigger pull is visibly insane. Decide loadout, then it's minutes on the bench. |
| 11 | **Never perf-measured demo scene; LIVE_CAP 50 vs ADR-035's 18; uncapped `_physics_process` delta** | UNKNOWN | Unknown-unknown. One profiled run answers it. Uncapped delta violates this project's own Quake-3 timestep law (CLAUDE.md) — a hitch during the assault spike can tunnel physics. |

## 2. Fix sizes + verification cost

- **#1 export**: 0.5–1 day to first .exe, +0.5 day smoke fixes (see §3). Verifiable by me/Godot MCP up to "boots and runs"; FEEL needs Caleb.
- **#2 death freeze**: 2–4h. Either honor EXCLUDE_DEBRIEF with a demo restart/respawn path, or minimum-viable: death → end card ("YOU DIDN'T MAKE IT") → same dismiss path as #3. Verifiable headlessly by killing the player via debug; final pass = Caleb (ADR-015).
- **#3 end card**: 2–3h. `get_tree().paused = true`, mouse visible, "press any key → quit/restart", card on a CanvasLayer above PauseMenu. Fixes #5 for free if the card also silences/pauses the siege. Self-verifiable.
- **#4 SimClock**: 3–4h. Suffix the dedup key with a per-event serial (or key on the schedule entry, not kind), and make ambient bookings day=-1. Regression-testable in isolation; sky-density judgment = Caleb.
- **#5 timing**: 1h once #3 pauses the world; otherwise clamp siege end to ≤ dawn card.
- **#6 geometry landmine**: 2–6h depending on whether it fires; needs one instrumented 512m run to even observe. CANNOT be signed off without a full arc run — Caleb or a long observed MCP run.
- **#7 double build**: 1–2h (gate `_ready`'s default op behind `not demo_mode`). Low regression risk but touches the boot path — retest normal boot too.
- **#8 HeliLift**: 0h code until observed. One observed run; if embark teleports, accept it for demo (teleport-into-seat is ugly, not a freeze) — do NOT open animation work this week.
- **#10 M60**: bench session, <1h, ONLY if in loadout — else cut from loadout, 5 minutes.
- **#11 perf**: 0.5 day instrumented run. Frame-feel verdict = Caleb.

**Caleb-only verifications (ADR-015):** the full 45-min DEMO_PLAYTEST_SCRIPT pass, air-spectacle feel, Huey landing look, frame feel, and every "does it read as alive" judgment. Nothing above substitutes for it; several items (#6, #8, #11) can't even be OBSERVED without a full arc run.

## 3. The export unknown — first .exe in Godot 4.7

This project has never exported. Typical first-export breakage, in likely order here:
1. **Missing/mismatched export templates** for the exact 4.7 build — install before anything.
2. **Debug-gated paths**: `OS.is_debug_build()` branches and debug keys ([J], [O], observer fly) vanish or, worse, leave arcs reachable only via debug keys. The demo arc clock is claimed release-safe; the export is the first real test of that claim.
3. **Resource inclusion**: export presets default-include res:// but `load()` on string-built paths (ModelActor's `unit_id` resolution!) can miss files the scanner never saw referenced; check `.txt`/`.json` data files (fossil_baseline, manifests) are in the include filter if read at runtime.
4. **Autoload init order + `user://` paths**: demo save dir behavior differs from editor; first-run empty `user://`is the fresh-player-law case.
5. **Shader compilation stutter** on first sight of each material (Forward+; no material precompile pass has ever been done).
6. res:// case sensitivity: non-issue on Windows target — but that means it's silently latent, not absent.
7. **GDExtension/plugin leakage**: editor-only plugins must not ship.

**First-export smoke pass must cover:** cold boot on a machine (or at least a profile) with empty `user://` → main menu → demo entry WITHOUT F6 (needs a launch path: `--demo` arg or menu button — this is real code, ~1-2h) → full arc to end card → death path → quit cleanly. Run it twice (second-boot save/config path differs from first).

## 4. Tech cut-line and day-count

Minimum non-embarrassing build = **#1 export + demo launch path, #2 death path, #3 end card (buys #5), #10 loadout decision, one instrumented full-arc run (answers #6/#8/#11), #7 boot gate.** #4 SimClock only if the instrumented run shows an empty sky Caleb's eyes catch. Everything else is out.

**Realistic count: 3–4 working days of code+export**, leaving 2–3 days for Caleb's playtest passes before 8/9. That is tight but honest — provided art D1 (wire ring) runs in parallel on his bench, since it's his hands, not mine.

**Baseline staleness:** the suite reads 101/18/14 from 7/27 across ~40 commits — the safety net is UNKNOWN, not green. Per project law I don't run it while coding; the honest statement is that every fix above lands with only its local verification until the owner runs `run_all_tests.ps1`. Ask for one suite run BEFORE the fix batch (fresh baseline) and one after — two runs, his machine, and confidence stops being a memory of last week.

*Tradeoff named:* this cut-line ships a demo whose Huey embark may visibly teleport and whose sky may thin late in the arc. Both are ugly; neither is a freeze; both are what one week buys.
