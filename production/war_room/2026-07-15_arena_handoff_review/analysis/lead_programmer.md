# Lead Programmer Analysis — AI Stress Arena Hand-off Review

## Code truth found during Summoning
- `ai_stress_arena.gd` already has a working telemetry HUD (`_update_telemetry()`, `_state_histogram()`, `_avg_suppression()`). It is per-frame and lacks a 30s summary log, but the plumbing exists.
- `_finish_agent_setup()` is the single place `hp_multiplier` is applied. That is the fossil point.
- `SquadSystem.pick_body_for_mos()` returns a random body from `WEAPON_BODY_POOLS`. Rifle roles can still return `us_grunt_v3`.
- `model_actor.gd` now hides donor duplicates at runtime. Clean re-export is tracked by bead x1bs.1.
- `GibSystem.gd` thresholds are global constants; no arena override exists.

## Suggested implementation order
1. **Telemetry summary:** add a 30s `print()` summary to `_process()` gated by `_sim_time % 30.0` and a flag. This is ~10 lines.
2. **Model selection:** add a static `ARENA_MOS_BODY` map in `AIStressArena` and pass the chosen body directly to `ally.set_sprite()` in `_spawn_us_squad()`. Avoid mutating `SquadSystem` so the campaign is untouched.
3. **Knob split:**
   - Replace `@export var hp_multiplier: float = 3.0` with the three new exports.
   - Update `_finish_agent_setup()` to use `ai_hp_multiplier`.
   - Add `player_damage_multiplier` application in `weapon_holder.gd` (player-only) or `DamageSystem`.
   - Apply `reserve_rate_multiplier` to `REINFORCE_INTERVAL_MIN/MAX` and/or reserve counts.
   - Remove the old `hp_multiplier` symbol entirely.
4. **Environment:** add cover/vegetation functions, ensure `nav_source` group membership.
5. **Suppression/gib tuning:** data changes after telemetry proves need.

## Code-quality notes
- Keep arena-only changes inside `AIStressArena`. Do not pollute `EnemyBase`/`AllyBase` with arena-mode branches.
- Any change to `GibSystem` constants affects the whole game. Prefer an optional arena override (e.g., `GibSystem.push_arena_thresholds(...)`) rather than lowering global constants if the campaign lethality contract (ADR-016) is already correct.
- `AllyBase.set_sprite()` must be idempotent and safe to call after spawn; verify before changing model selection.
