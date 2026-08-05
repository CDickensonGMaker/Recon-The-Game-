# DISCUSSION — 2026-08-04 FULL AUDIT — the debate record

Six independent analyses, no cross-talk. The debate below is the Arbiter's cross-examination of the
verdicts, with conflicts adjudicated by direct code read. Full analyses in `analysis/`.

## 1. THE CENTRAL CONFLICT — and its adjudication

**game-designer:** "No §8 ruling contradicted. R2/R3/R10 wired clean." (arc constants read as intended)
**devils-advocate:** "The 06:30 start never happens — the demo runs a DUSK 17:30 clock."

**ARBITER'S ADJUDICATION — the Devil's Advocate is RIGHT. Verified by direct read:**
- `demo_game.gd:100` calls `_flow._begin_operation(DEMO_SEED, DEMO_NAME)` **without `await`**.
- `_begin_operation` suspends at the world-ready loop (`game_flow.gd:591-592`), returning control.
- `demo_game.gd:103` `SimClock.set_time(1, START_HOUR)` therefore executes **BEFORE the build** —
  while its own comment (`demo_game.gd:101-102`) claims "AFTER the build". **That comment is drift
  inside code shipped under the no-drift law, one day old.**
- On world-ready, `_begin_operation` resumes; `game_flow.gd:677-679` runs
  `weather.setup(world, ..., str(patrol_plan.time))` with the demo plan's fossil
  `"time": "DUSK"` (`mission_generator.gd:673`), and `mission_weather.gd:51` unconditionally sets
  `SimClock.sim_hour = 17.5`.

**Consequence chain (devils-advocate's arithmetic, unrefuted):** night at ~2:22 real, midnight
rollover mid-run (re-arms a second siege roll `siege_director.gd:171-174` and the fire-support
allotment), the "night assault" at 1440s plays in daylight, sun rises mid-demo. The 8/3 decree's
four-lighting-event spine is broken at the root. The game-designer's clean bill covered the
CONSTANTS; the defect is in the BOOT ORDER — both reads were honest, one looked deeper.

## 2. CONVERGENCES (independent arrival = the strongest signal this process produces)

**C1 — The radio handoff can eat the medic (3/6 architects, independently).**
`squad_system.gd:588-601` `_hand_off_radio` picks the NEAREST living man and **overwrites his MOS**
(`:601`). If the medic inherits, `member_by_mos("MEDIC")` fails and `can_revive()`
(`squad_system.gd:224-226`) dies silently — ruling R3's entire fail-forward economy deleted by one
RTO death, behind a positive-sounding toast, persisted to the campaign save. Found by game-designer,
ai-architect, devils-advocate.

**C2 — Ruled items recorded as wired that are NOT in code (3/6).**
The backlog's 8/4 section reads as "the rescope, wired"; the code disagrees on at least five:
- Hunter pool top-up (§2.9 RULED): pool still 12, zero refill hooks (`field_director.gd:106`,
  ai-architect: three repo hits, no top-up; game-designer: `field_director.gd:1219-1234`).
- §2.8's night arithmetic (45 − hunters_killed − tunnel): **zero hooks exist**.
- Informer forced to 100%: still a coin flip (`mission_generator.gd:1010`).
- §2.11 ally items 1–4: ALL unshipped — courage still flat `randf()` (`ally_base.gd:295`), no
  scorer feed (`:781-801`), no concealment term (`:1298-1303`), thumper automatic
  (`squad_system.gd:456-489`). Squad still owns 1 spendable verb of 5.
- "hunters" tagging of the ambient cell: absent.
The codebase beats the backlog — again, and this time the overclaim is OURS (the 8/4 record).

**C3 — The ruled ending is a freeze-frame, not circling gunships (2/6).**
game-designer: 12s hold minus ~9.2s inbound (330+130m at 50 m/s, `helicopter.gd:12`) leaves **2–3s
of visible orbit**; `_dispatch_gun_orbit` can be cut to zero ships by its own ceiling
(`air_traffic.gd:272-275`). devils-advocate independently: the +12s pause freezes the ending as a
still of ARRIVAL (`demo_game.gd:410,445`). R1's last image, as wired, is not what was ruled.

**C4 — The time arithmetic is wrong in a second, independent way (2/6).**
Even with the clock race fixed, game-designer computed NIGHT actually falls at sim 19.0
(`sim_clock.gd:57-64`) ≈ **1184s**, not the 1380s seam the wiring assumed — the speed switch, probe
and siege timings are ~3 real minutes late relative to darkness. And 1-in-20 boots roll a rogue
random d50 siege before the scripted one (`siege_director.gd:168-188`, `:20-21`).

**C5 — The measurement plan is itself broken (2/6).**
technical-director: **`--print-fps` does not exist** — sole occurrence is a comment
(`site_planner.gd:859`) — so M-2/M-3 are unrunnable as specified, and `--perf-probe` null-crashes an
exported build (`game_flow.gd:713` loads excluded `res://tests/perf_probe.tscn`). devils-advocate:
four load-bearing assumptions carry NO measurement at all → new M-6..M-9. ai-architect adds M-AI-1
(forced-cap thaw test). The verification plan needs repair before it can verify anything.

## 3. SECONDARY DISAGREEMENTS

- **technical-director** ("bounding discipline near-total, 15 families capped") vs **ai-architect**
  (thaw path double-spends headroom, proximity `materialize()` has no cap check,
  `siege_director.gd:448-479`, `marching_cell.gd:89-90`): compatible — the code is BOUNDED but the
  new thaw logic may be WRONG, and the demo can never execute it (45 < LIVE_CAP 50), so its first
  run lands in the full game unmeasured. Both stand.
- **art-director** vs **ART_Track_Log**: log convicted twice (chow clips ARE merged; site_planner
  maps seven chow types, not two). Codebase beats the log; log to be corrected on contact.
- **systems-designer** vs 7/31 audit: "rank gates nothing" is STALE — the armory tier gate works
  (`armorers_bench.gd:50` + 7 tiered .tres). One 7/31 weakness retired by verification.

## 4. WHAT SURVIVED EVERY ATTACK (all six lenses touched these; none drew blood)

- The witness→evidence→hunt-net stealth economy (`enemy_base.gd:970-1051`,
  `field_director.gd:146-174`) — a genuinely closed loop.
- Siege escalation logic (probe→assault reinforce, broken-probe re-open, `siege_director.gd:192-249`).
- Save sandboxing both directions (`demo_game.gd:81-95`, `:112-117`).
- Death paths: every one lands on a verified terminal screen with named men
  (`demo_game.gd:431-469` via `health_system.gd:267` → `field_director.gd:201`).
- The revive economy per R3 (`squad_system.gd:222-348`) — complete and legible, IF the medic survives C1.
- The open-patrol loop cycles (`field_director.gd:1214-1237, 1586-1610`); campaign memory breadth
  (`campaign_state.gd:298-377`); the shared anim library (182 clips, 143 wired, one contract,
  `model_actor.gd:280-310`); 31/31 character GLBs resolve; fossil ratchet intact at 3.

## 5. FULL-GAME THREADS (systems-designer lead, corroborated)

- **The siege banks no AAR** — comment at `field_director.gd:1466-1468` claims "the night banks its
  own AAR" above a handler (`:1469-1478`) that banks nothing. A siege fought at home writes no
  butcher's bill. The machinery sits ~120 lines away. (Also a comment-discipline conviction.)
- **Hearts & minds: ADR-019 Accepted, zero code** — `allegiance` exists in two comments; civilian
  murder is free via an intentionally-empty hook (`civilian.gd:4-7`).
- **No sleep verb** — the night economy is built with no player-facing consumer
  (`game_flow.gd:51-94` dev key only; 68 bunks are spawn markers).
- **ADR-029 — the game's entire shape — is still DRAFT**, with two ratified amendments hanging off
  an unratified base.
- **MARKSMAN still absent from `MOS_ORDER`** (`squad_roster.gd:64`); its comment promises an
  "alternate draw" that never existed.
- **`_thaw_held_cells` first executes in the full game**, never the demo — specify M-AI-1 before
  any siege-strength tuning.

## 6. NEW TECHNICAL FINDINGS ACCEPTED INTO THE RECORD

- **Air-transit burst**: `sim_clock.gd:86,91` truncates fractional hours → all staggered transits
  (`air_traffic.gd:105`) fire on ONE frame per hour crossing — up to ~14 airframes instantiated in a
  single frame every ~95s wall at 38x, on a call-bound project.
- **Baked drops may render 1.81m underground** (`world_weapon.gd:143,186-192` + the .tscn burial
  offset) — the accumulator fix may have traded a leak for invisible pickups. Eyes-on check ordered.
- **17 systems built-and-unverified** since the last verified playtest (ledger in
  `analysis/technical_director.md`); M-1..M-5 (as repaired) discharge 12.
- `_fired_event_keys` never prunes (`sim_clock.gd:24,98`) — trivial rate, noted, not scheduled.
