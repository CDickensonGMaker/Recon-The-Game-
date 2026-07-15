# Analysis — ai-specialist (gameplay loop integrity)
**Reading:** `scripts/levels/ai_stress_arena.gd` (full) and `scripts/enemies/enemy_base.gd:1500-1560` (combat movement).

## What the AI was doing when the warning fired
The arena's VC squads spawn in two waves (initial + reserves) at the village corner and the north tree line. The first-spawned squad has its `last_known_target_pos` set to a point in the central contact zone (`ai_stress_arena.gd:679`). That target is **inside the central berm, in a gap between wrecked-cover boxes, or on the contact line itself** — exactly the zone where the navmesh is densest but also the zone most likely to have navmesh erosion from the berm and the 0.45m agent radius (line 587).

The agent's first `_move_toward()` call:
1. Computes `direction = target - global_position` — could be 60-80m.
2. Sets `use_nav = true` (lab navmesh exists).
3. Sets `nav_agent.target_position = pos`.
4. The server has not yet processed the new target; `is_navigation_finished()` returns `true` because there is no path at all.
5. `direction.length_squared() > 25.0` and the warning fires once per agent.

The agent then **does** path correctly on subsequent frames, but the warning is a false alarm: the path was just slow to compute, not missing. The agent's `velocity` is also zero on this frame (no path), so it doesn't even move in the wrong direction.

## Impact on the firefight
- **Behaviorally:** zero impact. The agent continues to behave correctly on frame 2+.
- **Telemetry noise:** the warning pollutes the headless probe output and obscures legitimate navmesh-miss cases (e.g., a target truly outside the navmesh, a perception bug, a spawn race). When the council later has to diagnose "why did the agent not move?" we will see a wall of false warnings and lose signal.
- **Player-facing:** zero. The warning is `push_warning`, not `push_error`, and not shown to the player.
- **Test stability:** `tests/test_ai_stress_arena.gd` is the only existing test. It does not check for warnings, but the headless probe's `PASS` is silent on warnings — a regression that floods the log with `[NAV]` warnings would not fail any test today.

## Why this matters for the AI North Star
The AI North Star (`RECONgame-0623`) requires the council to ship **patrol routes, search, teamwork, fire cohesion, and determination**. None of those behaviors is blocked by this warning. The warning is a **diagnostic noise** that hides future real failures.

The right fix is to **reduce the diagnostic noise** (so future real failures are visible) AND **clamp the target** (so the common off-mesh-target case is handled silently, exactly as the agent's fallback to direct steering was designed to do).

## Loop integrity check
- **Does the fix change the AI's decision-making?** No. `_move_toward()` still falls through to direct steering when the path is missing; the clamp just makes the path more often findable.
- **Does the fix affect combat feel?** No. The agent reaches the same target by the same path; the clamp only projects targets onto the navmesh.
- **Does the fix interact with the 30s telemetry log?** No. The log reads `_us_kills`, `_vc_kills`, suppression levels, distances — none of which depend on the nav path.
- **Does the fix interact with the hunt doctrine (`EnemyData.determination`, hunt_point/hunt_radius)?** No. The hunt is a goal-level decision; the nav path is a movement-level execution. The clamp helps hunt wedges (which project last-known-positions onto the navmesh) reach their search points.
- **Does the fix interact with the personality spectrum (courage, skill, presence)?** No.

## What I would NOT change
- I would NOT touch `ai_stress_arena.gd`. The arena is correct; the bug is in the agent's pathing.
- I would NOT add a new "is target on navmesh" check elsewhere in `enemy_base.gd`. The clamp inside `_move_toward()` is the single chokepoint for nav-routed movement; doing it there keeps the rest of the agent unaware of navmesh details.
- I would NOT remove the `_nav_warned` once-per-agent guard. The guard is a feature, not a bug — if a real failure repeats every frame, the warning still fires on the first frame and gives a diagnostic.

## What I would add (verification)
- A one-line assertion in `tests/test_ai_stress_arena.gd` that **counts `push_warning` calls with the `[NAV]` prefix**. Before the fix: 1+ per first-spawn VC. After the fix: 0 in the default configuration.
- This is a regression guard, not a behavior test. It catches future agents that re-introduce the bug (e.g., a new enemy type that doesn't bind to the lab navmesh, or a target that's deliberately 50m off the navmesh).

## Verdict
**APPROVE the lead-programmer's fix.** It is a structural improvement (clamp + reduce noise) that:
- Does not change AI behavior.
- Reduces diagnostic noise.
- Helps future hunt-wedge and search-after-LOS-loss behaviors whose targets sit on berms and inside building footprints.
- Is gated by a deterministic probe (`tests/test_ai_stress_arena.tscn` with seed 20260714).

**Additional ask:** add a one-line `push_warning` counter to the existing probe. This is the verification law made manifest — "mitigated" never closes a bead; the counter is the proof.
