# War Room Session — 2026-07-14 AI Stress Arena Planning

**Query:** Implement the AI Combat Stress Test Arena using Gore Lab as foundation; firefight must last 3–5 minutes.

**Council:** game-designer, systems-designer, ai-programmer, lead-programmer, ux-designer, devils-advocate.

## Files

- [briefing.md](./briefing.md) — query and constraints
- [THE_PLAN.md](./THE_PLAN.md) — concrete implementation plan

## Plan in Brief

- New standalone scene `scenes/levels/ai_stress_arena.tscn` (120m arena, 5 zones).
- Default 18 US vs 18 VC on field, plus 2 reserve squads per side for reinforcement.
- Forces start ~90m apart (firebase SW vs village NE) and reinforcements feed in as squads die to sustain a 3–5 minute firefight.
- Extract `weapon_for_mos` / `pick_body_for_mos` static helpers from `SquadSystem` so the arena reuses the new body-pool randomizer.
- Telemetry panel + debug labels + headless probe.
- Out of scope for v1: new ally squad tactics, persistent memory, procedural terrain, spectator camera, civilians.

## Summoner Approval Gate

Plan is ready for review. No code will be written until approved.
