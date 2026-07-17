# Systems Designer Analysis — AI Stress Arena Hand-off Review

## The core disease
`AIStressArena.hp_multiplier` is a global scalar applied to every agent after spawn. It simultaneously controls:
1. AI-vs-AI time-to-kill.
2. Player-perceived enemy durability.
3. Likelihood of gib-level overkill on killing blows.
4. Effective reinforcement cadence (because fewer deaths = slower churn).

This is the classic "one variable, four jobs" anti-pattern. The fix is to split responsibilities into separate, named levers.

## Proposed new levers
- `ai_hp_multiplier`: scales `max_hp` / `current_hp` for all arena agents. Controls AI-vs-AI TTK independent of player.
- `player_damage_multiplier`: multiplies damage dealt by the player only (or, equivalently, makes player projectiles do more damage). Separates player feel from AI durability.
- `reserve_rate_multiplier`: scales reinforcement interval (`REINFORCE_INTERVAL_MIN/MAX`) and/or reserve squad counts. Controls macro fight duration.

## Fossil Law requirement (ADR-023)
We must delete the old `hp_multiplier` code path. Leaving it as a fourth "legacy" knob creates a fossil. The migration path:
1. Add the three new exports.
2. Replace every `_finish_agent_setup()` reference to `hp_multiplier`.
3. Remove the `hp_multiplier` export and any callers.
4. Run the test suite; a new fossil fails the build.

## Arena vs. campaign boundary
These levers live in `AIStressArena` only. They must not leak into `SquadSystem`, `EnemyBase`, or campaign mission setup. If we later want similar tuning in the campaign, that is a new ADR, not a default.

## Telemetry contract
Before tuning, the arena must emit every 30 seconds:
- US alive / VC alive
- US kills / VC kills
- Avg suppression per side
- Avg distance to target
- Rounds fired per side
- Fight duration at round end

Without this data, no knob move is evidence-based.

## Risks
- Suppression changes can create feedback loops (more suppression → less movement → longer fights). Need to measure, not assume.
- Increasing cover density changes navmesh baking and pathing; must verify with headless probe.
- Reserve pacing interacts with reinforcement trigger thresholds; changing one changes the other.
