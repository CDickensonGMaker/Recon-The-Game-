# ADR-010: Per-mission determinism + MissionScope reset registry
**Date:** 2026-07-10 · **Status:** Accepted (War Room audit #2) · **Supersedes/Amends:** Ratifies (retroactively) the unratified determinism/teardown work shipped in the long window (ROADMAP.md:7); amends CLAUDE.md's silence on RNG discipline; codifies lead_programmer.md canon items 7, 8, and 10 into law.

## Context
GameFlow builds mission after mission in one process (`scripts/main/game_flow.gd:1-4`). Two failure classes emerged from that architecture. First, **randomness scatter**: Godot auto-randomizes the global RNG at startup, and most gameplay draws from it — enemy personality, crippled/surrender rolls, exfil-bird shootdown, insertion crash, hunter escalation, ordnance dispersion (`game_flow.gd:96-101`). Unseeded, no mission was reproducible; the HARD-tier wheels-down checkpoint (`game_flow.gd:110-114`) is only a valid resume point because "offer + carried state" fully reconstructs a world, which requires the world to be a pure function of its seed. Second, **static leakage**: class statics and autoload state survive `_teardown_world()`, so mission 5 inherited mission 1's world — probe-proven leaks included `MissionDirector.any_fire_menu_open` killing every kit key for the session after dying with [T] open, `DamageSystem` craters floating over a different heightmap, `GunFX._sting_cooldown_until` muting the CONTACT drum for the first 25s of the next mission, and stale `EnemySquad` AABBs placing mission 5's enemies in mission 1's village (`scripts/main/mission_scope.gd:5-19,40`).

The fixes shipped mid-window without a council: `MissionOffers.roll(rng)` derives each offer's single `mission_seed` from a caller-supplied RNG — with a manual Fisher-Yates shuffle because `Array.shuffle()` draws from the global RNG, proven non-reproducible in probe_smoke_all section C (`scripts/missions/mission_offers.gd:11-24`) — and stamps `world_seed = mission_seed` under the R88 rule "ONE seed identifies ONE operation" (`mission_offers.gd:29-30`). `GameFlow.start_mission()` then seeds the global RNG from that one number (`game_flow.gd:107`) with an honest scope statement: same seed = same world, same enemies, same events — NOT the same bullet holes, because per-frame draws depend on frame timing (`game_flow.gd:103-106`). `MissionScope.reset()` (`mission_scope.gd:28-47`), called from `_teardown_world()` (`game_flow.gd:40`), is the single place that undoes a mission, each entry citing the probe that proved the leak.

Audit #2's drift finding is the reason this ADR exists now: this was load-bearing, unratified law living only in code — "the campaign-loop overhaul is entirely unratified" (lead_programmer.md:125-131). The lead programmer's adversarial pass verified MissionScope "genuinely correct" and named it "exemplary engineering... should be canonized as the mandatory pattern for any new static" (synthesis.md:25-26 verdict 1; lead_programmer.md:155-157). This record performs that canonization.

## Decision
Every mission derives ALL generation randomness from one mission seed; statics that outlive a mission MUST register teardown with MissionScope.

- **One seed per op.** A mission offer carries exactly one seed (`mission_seed`, mirrored as `world_seed` — R88, `mission_offers.gd:29-30`). All world generation, spawn placement, conditions, complications, and event rolls derive from it. No second seed may be introduced for any generated content.
- **Seed the global RNG at mission start, from the offer, nowhere else.** `start_mission()` calls `seed(hash(mission_seed))` (`game_flow.gd:107`). No other code may call `seed()` or `randomize()` on the global RNG during a campaign.
- **Honest scope is part of the contract.** Determinism covers generation and spawn. Per-frame draws (bullet spread, hit FX) remain timing-dependent by design. Same seed = same world/enemies/events, not same bullet holes (`game_flow.gd:103-106`). Do not promise, test, or debug beyond this scope.
- **Global `randomize()` is permitted ONLY for non-persistent cosmetic effects** and for dedicated RNG objects outside the mission scope (the only current use: `session_rng.randomize()` at menu level, `game_flow.gd:18`). Anything that persists, saves, scores, or affects generation must draw from the seeded stream or a seed-derived dedicated RNG.
- **Deterministic shuffle only.** `Array.shuffle()` and `pick_random()` on generation paths are banned where reproducibility matters — they draw from the global RNG at an uncontrolled point (`mission_offers.gd:11-12`). Use explicit `rng.randi()` Fisher-Yates.
- **MissionScope is the mandatory static registry.** Any class-level static (or autoload mutable state) that carries state across missions MUST register a reset in `MissionScope.reset()` (`mission_scope.gd:28-47`), with a comment naming the leak and, where cheap, the probe that proves it (pattern: `tests/probe_smoke_all.gd` sections B/D). A static without a MissionScope entry is a defect.
- **Deliberate exclusions must be documented in MissionScope itself**, as CampaignState, GameSettings, and WeaponHolder session stats already are (`mission_scope.gd:21-23`). Silence is not an exclusion.
- **Singleton doctrine:** autoloads for engine-lifetime services (12 registered in project.godot: SaveManager, GameManager, DamageSystem, ...); `class_name` statics ONLY where an autoload is overkill AND the MissionScope registration obligation is paid. Statics are a convenience with a tax, not a free autoload.

## Consequences
**Buys:** reproducible missions from the seed the debrief prints (bug reports become replayable); the HARD wheels-down checkpoint stays a two-value resume point (offer + carried state) instead of a full world snapshot; hub board and legacy MissionSelect can never drift because both call the one `MissionOffers.roll()` (`mission_offers.gd:1-3`); cross-mission leaks get one audit-of-record instead of N scattered fixes.

**Costs (named — no free lunches):** every new static now carries a registration tax and a probe expectation, which slows the cheapest kind of GDScript state; `MissionScope.reset()` is a central coupling point that must know about every subsystem it cleans; the honest-scope carve-out means "deterministic" can never be sold as full replay determinism, forfeiting demo-recording-style features without a redesign; HARD's same-seed re-run is a reload-and-memorize door (game_designer.md A9) — accepted under Pillar 5, monitored.

**Work created:** truth-law cleanup makes this ADR canon and cites it from CLAUDE.md/GAME_GUIDE (decree build-order item 7); the test-suite-eyes law (ADR-015 family) should extend probe_smoke_all with a same-seed-twice generation-equality assert — no bead existed at ratification time; file under the LAW & LEDGER epic when opened.

## Evidence
- `scripts/main/mission_scope.gd:1-47` — registry, probe citations, deliberate exclusions (verified).
- `scripts/main/game_flow.gd:40` — `MissionScope.reset()` called from `_teardown_world()` (verified).
- `scripts/main/game_flow.gd:95-114` — per-mission `seed(hash(mission_seed))`, honest-scope comment, HARD checkpoint dependency (verified).
- `scripts/main/game_flow.gd:18` — sole `randomize()` in scripts/, on a dedicated `session_rng` (verified by project-wide grep).
- `scripts/missions/mission_offers.gd:11-38` — single roll source, manual Fisher-Yates, R88 one-seed rule (verified).
- `ROADMAP.md:7` — "landed mission-seed determinism, MissionScope cross-mission teardown" (verified).
- `production/war_room/analysis/lead_programmer.md:125-131, 155-157, 231-239` — audit findings and canon items 7/8/10 (verified).
- `production/war_room/synthesis.md` — verdict 1 ("MissionScope... verified genuinely correct"), ratification context (verified).
- `tests/probe_smoke_all.gd` sections B/C/D — cited by the code as proof of the leaks and the shuffle non-reproducibility (cited in mission_scope.gd/mission_offers.gd; probe file not re-run for this record).

## Related
- **ADR-007** (save-tier ladder) — HARD wheels-down checkpoint is only sound because of this contract.
- **ADR-008** (walkable firebase hub) — operation seed = hub world seed rides the same one-seed rule.
- **ADR-015** (mechanical process laws) — the verification/truth laws that this ADR's probe obligations serve.
- **Pillars served:** 5 (Fail forward — deterministic resume makes failure recoverable, not arbitrary) and 4 (squad persistence depends on clean cross-mission state); indirectly 1 (session-long input bugs like the dead kit keys are gunplay killers).
