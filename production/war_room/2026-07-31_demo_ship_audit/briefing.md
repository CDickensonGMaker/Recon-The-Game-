# BRIEFING — Full Audit: Demo vs Full Game, Ship-Readiness

**Date:** 2026-07-31
**Summoner:** Caleb
**Arbiter:** Wyrm

## The Query
Run a full audit of RECONgame comparing the DEMO slice against the FULL game.
Deliver:
1. Weaknesses of the game (where we are lacking the strongest)
2. Strong suits (what is really working)
3. A realistic verdict: can the DEMO reach shipping state by **end of next week (~2026-08-09)**?
   - No rush; goal is to show off what exists.
   - Summoner suspects **art blocks** are the main remaining barrier — verify or refute.

## Constraints (Pillars & Standing Law)
- Rule #1: FUN to walk + FEEL Vietnam; judged by the Summoner's EYES.
- World foundation LOCKED — improve, never rebuild.
- Demo ship gate (7/29): air spectacle + Huey landings + base blows up + VC overrun.
- Demo = 512m firebase-holdout slice via GameFlow.demo_mode; overrun is a GOAL bias, lane is the gate.
- Fossil law (ADR-023): never restore deleted systems.
- Period HUD deferred to final polish — never a blocker.
- Bottleneck on record (7/30): the Summoner's own playtest, not code volume.

## SUMMONING — Evidence Scouts (in flight)
1. **Demo slice auditor** — demo_mode wiring, stubs, dangling refs, handoff-doc open items
2. **Full-game systems auditor** — GAME_GUIDE/ADR promises vs code reality, dead wiring
3. **Art/asset auditor** — placeholder census, animation coverage, known art debt, audio state
4. **Production-state auditor** — todo docs, test-suite baseline, git momentum, ship checklists

## Architects to Wake (Phase 2, after scouts report)
- game-designer (is the demo a good SHOW-OFF piece?)
- technical-director (wiring risk, silent-freeze bug class, ship stability)
- devil's advocate (what the 1-week estimate sacrifices; what breaks in a stranger's hands)
- Arbiter weaves; producer lens folded into the weave (schedule realism).
