# BRIEFING — 2026-08-05 — FROM THE PLAYTEST ZONES TO THE WORLD

**Convened by:** the Summoner (Caleb), 2026-08-05.
**Arbiter:** the Overseer/Director.
**Council:** systems-designer · technical-director · level/world-architect · game-designer ·
devil's-advocate. Independent sight, code only, no cross-talk.

## The ask (verbatim)

> "Run the recon overseer on how to take the findings we made in the playtesting zones and how to
> apply it toward the demo and main game world. Declare everything that we would be migrating over
> and what it does."

Named specifically: **destructible trees and buildings in the gameworld**, **the ability to shoot
through materials in the gameworld**, **working RTO strikes with the newly tuned values**.

## The two zones

| Zone | File | What it is |
|---|---|---|
| Support-fire range | `scripts/levels/support_fire_range.gd` | The fire/RTO lab. Direct number keys 1–8 fire 60 m down the look axis; `[9]` runs assaults. His approved tuning loop for all fire support. |
| AI stress arena | `scripts/levels/ai_stress_arena.gd` | The combat/AI lab. 18v18, night jungle, 30-man survival waves, defensive zones, mirror mode. |

Both are **instruments, not levels** — ADR-029 Q5 ruled "lab scenes stay as instruments".
Nothing migrates by being in a lab; it migrates because it is a game system that happens to have
been built there first.

## Constraints binding this council

- **ADR-031 (destruction doctrine):** state-swap never fracture · one blast bus (`AgentRegistry.props`)
  · terrain holes throttled and **perf-gated behind a measured worst-frame** · permanence sacred
  inside the firefight radius · determinism from position + seed, never `Time`.
- **ADR-026 (PS2 budget):** ≤8 realtime lights, 0 dynamic shadows; the frame is **CPU-bound**;
  scale is uncapped, compute is budgeted.
- **ADR-033 (trunk collision ring):** physics only within 70 m of the player; 1280-body pool;
  candidates not bodies.
- **ADR-016:** damage values are law.
- **ADR-029:** one world one build; labs stay labs.
- **Demo scope:** ONE DAY, 30 MINUTES, four lighting acts, sun does not move.
- **Standing rulings honoured:** FEAR doctrine both sides · "I don't feel in danger" is the
  acceptance test · explosives defeat hard cover ~50% (blast path only) · munitions detonate on
  first real contact · gaze-based tree promotion REJECTED · segmented trees held for his verdict ·
  ADR-015 (feel is discharged only by his hands).

## Method

Every claim in this record was verified by reading the code. Where the briefing the Arbiter
carried in was wrong, the correction is recorded in `discussion.md §1` — the Pointer Law cuts
both ways.
