# War Room Briefing: AI Stress Arena Hand-off Review
**Date:** 2026-07-15 · **Declared project:** RECONgame (`C:\Users\caleb\RECONgame`)

## Query from the Summoner
> "Whip up the Recongame project and use the war room to review the last hand off document we made and what we're trying to fix."

## Source of record
Hand-off document: `production/war_room/handoff_ai_stress_arena_2026-07-14.md`  
Memory pointer: `memory/recongame-ai-arena-handoff-2026-07-14.md`

## Context already fixed (2026-07-14)
- `us_grunt_v3.glb` duplicate-gear rendering patched in `scripts/visuals/model_actor.gd`.
- Arena navmesh two-frame wait + explicit VC nav-agent map binding.
- Suppression movement wiring in `enemy_base.gd` / player-fire suppression in `weapon_holder.gd`.
- Viewmodel hip/ADS independent zero system.
- NAV error downgraded to warning.

## Unsolved problems the Council must review and route
1. **Wrong US models spawning** — `SquadSystem.WEAPON_BODY_POOLS` still pulls `us_grunt_v3` for rifle roles in the arena; role-specific bodies exist (pointman, rifleman, mg, grenadier, rto).
2. **Not enough LOS-breaking cover** — 28 small rocks over a 120m arena; no central ridgeline, no tree line, no compound walls.
3. **No real 3D vegetation** — 12 palms + 2 rice patches; nothing breaks sight lines or provides concealment.
4. **US kills VC ~2× as fast** — symmetric `hp_multiplier = 3.0` plus US RPM/accuracy advantage.
5. **Suppression does not slow the fight** — small radius, fast decay, threshold too high.
6. **Player combat spongy** — `hp_multiplier = 3.0` makes VC 210 HP; ~8 M16 chest hits to kill.
7. **No gib / blow-apart deaths** — bullet kills fall back to ragdoll; thresholds rarely met.

## Systemic issue flagged by the hand-off
A single `hp_multiplier` controls AI-vs-AI balance, player feel, gib frequency, and fight duration all at once. The hand-off recommends splitting it into:
- `ai_hp_multiplier`
- `player_damage_multiplier`
- `reserve_rate_multiplier`

## Suggested order from the hand-off
1. Add telemetry.
2. Fix US model selection.
3. Rebuild environment (cover, ridge, vegetation).
4. Split HP/damage multipliers and tune for 3–5 minute fight.
5. Make suppression aggressive enough to visibly slow movement.
6. Tune gib thresholds / verify donor meshes.
7. Run headless probe.

## Binding constraints for this Council
- **Pillar 1 (Outstanding gunplay):** death from situation, never bullet sponges. The current 210 HP VC with 8-hit M16 kills violates this.
- **Pillar 2 (Atmosphere):** dense jungle / vegetation / cover readability matters.
- **ADR-001:** 3D PSX models are the renderer; `us_grunt_v3` duplicate cleanup is a band-aid, re-export is the clean fix.
- **ADR-016:** flat damage × zone grammar; do not introduce randomness or hidden modifiers.
- **ADR-023 (Fossil Law):** when replacing a system, delete the predecessor. Splitting `hp_multiplier` must include removing the old single-knob code path.
- **ADR-015 (Verification Law):** nothing closes without a probe, measurement, or verified playtest. Telemetry is a prerequisite for tuning beads.

## Standing build order context (GAME_GUIDE §8)
Current standing entry gate is **PLAYTEST R3 (bead ida9)** — the session entry point. The arena is a dev/probe environment, not the campaign loop, but fixes that touch core systems (damage, AI, cover) still gate on R3 or must be exempt as bug-fix/probe work.

## Files to examine
- `scripts/levels/ai_stress_arena.gd` — environment, forces, telemetry
- `scripts/squad/squad_system.gd` — MOS → body/weapon mapping
- `scripts/enemies/enemy_base.gd` — combat loop, suppression, death/gib routing
- `scripts/allies/ally_base.gd` — ally combat loop, death
- `scripts/combat/gib_system.gd` — gore thresholds
- `scripts/player/weapon_holder.gd` — player suppression application
- `scripts/visuals/model_actor.gd` — model setup, duplicate cleanup

## Request to the Council
The Summoner asks for a review: confirm the problem list, judge whether the suggested split-the-knob systemic fix is the right first move, name the tradeoffs, and produce an actionable decree with beads for the next work block.
