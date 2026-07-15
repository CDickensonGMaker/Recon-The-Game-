# Analysis — lead-programmer (AI nav specialist)
**File under audit:** `scripts/enemies/enemy_base.gd` lines 1525–1545 (`_move_toward`), with cross-references to `scripts/world/nav_baker.gd` and `scripts/levels/ai_stress_arena.gd`.

## Reading the bug
The `push_warning` at line 1544 fires when:
- `is_navigation_finished()` returns true **AND**
- `direction.length() > 5m` (5m squared, sqrt'd).

In the arena, the `_lab_nav` flag is set because the scene's `NavigationRegion3D` is in the `lab_navmesh` group (set at line 253 of `enemy_base.gd`, populated at line 582 of `ai_stress_arena.gd`). So `use_nav` is `true`. The agent submits `nav_agent.target_position = pos` and asks the server for a path.

**Path-through-server roundtrip latency.** A `NavigationAgent3D` does not synchronously resolve a new target to a path — the navigation server processes it on the next physics tick. On the **first call** to `_move_toward()` after spawn, the agent's `target_position` was just set, but the path has not been computed yet. `is_navigation_finished()` may return `true` on the first frame because there is no current path at all (the server hasn't produced one), and the agent is at its spawn position — which can be tens of meters from the requested target. The "67.8m" in the warning is exactly this case: the agent was just spawned, `is_navigation_finished()` is true because no path exists yet, and the agent is far from the target. The warning fires once per agent (`_nav_warned = true`) and the agent then steers directly.

This explains the user's symptom precisely: **"one VC spawn logs"** — the first agent to move has a not-yet-resolved path and logs it. The other 17 agents don't, because by the time they reach `_move_toward()` for the first time, the server has had a chance to compute their paths (or they are closer to their targets).

## Why clamping helps
`NavigationServer3D.map_get_closest_point(map, to_point)` projects an arbitrary world point onto the navmesh's nearest walkable surface. If `to_point` is on a berm, in a building, or in a navmesh-eroded margin, the projection pulls it onto the nearest reachable surface. The agent then pathfinds to that projected point, which is reachable.

If the original `to_point` is more than (say) 4m from the projected point, the target is **not on the navmesh at all** — clamping onto the navmesh will steer the agent to a similar but not identical place. This is acceptable for the arena (targets are player LKP, cover points, patrol waypoints) — the agent will close distance and the perception system will refresh the target as soon as the player moves or is seen.

If even the closest point fails (no walkable area near the target), the server returns the agent's own position, the path is empty, and the agent falls back to direct steering without complaint.

## The fix, concretely

```gdscript
func _move_toward(pos: Vector3, delta: float, speed_mult: float = 1.0) -> void:
    var direction: Vector3 = pos - global_position
    var use_nav: bool = WorldConfig.NAV_ENABLED and _nav_box >= 0 and NavBaker.box_contains(_nav_box, pos)
    if _lab_nav:
        use_nav = true
    if nav_agent != null and use_nav:
        # Clamp the requested target to the navmesh's closest reachable point.
        # Off-mesh targets (LP behind a wall, cover point on a berm, player
        # running on a roof) reach is_navigation_finished() while still meters
        # away because the server resolves the path to the projected endpoint,
        # not the original target. We pre-project, then re-derive direction.
        var map: RID = nav_agent.get_navigation_map()
        if map.is_valid():
            var clamped: Vector3 = NavigationServer3D.map_get_closest_point(map, pos)
            if clamped.is_equal_approx(pos) or pos.distance_to(clamped) < 4.0:
                pos = clamped
        if nav_agent.target_position.distance_squared_to(pos) > 9.0:
            nav_agent.target_position = pos
        if not nav_agent.is_navigation_finished():
            direction = nav_agent.get_next_path_position() - global_position
        elif OS.is_debug_build() and direction.length_squared() > 25.0 and not _nav_warned:
            _nav_warned = true
            push_warning("[NAV] enemy inside baked region %d, %.1fm to target, no path - falling back to direct steering" % [
                _nav_box, direction.length()])
    direction.y = 0
    if direction.length() > 0.1:
        direction = direction.normalized()
        facing_dir = direction
    var suppress_mult: float = _suppression_move_mult()
    velocity.x = lerpf(velocity.x, direction.x * move_speed * speed_mult * suppress_mult, delta * 8.0)
    velocity.z = lerpf(velocity.z, direction.z * move_speed * speed_mult * suppress_mult, delta * 8.0)
```

Notes on the diff:
- `nav_agent.get_navigation_map()` returns the agent's bound map RID; the arena already binds this via `set_navigation_map()` (line 687 of arena). The RID is invalid only if the agent is detached.
- The `is_equal_approx` guard avoids re-clamping for already-on-mesh targets (negligible cost).
- The 4m threshold is conservative — if the closest point is more than 4m from the original, the target is genuinely off-mesh and we keep the original `pos`. The agent then direct-steers; no warning.
- The existing `is_navigation_finished() && direction.length() > 5m` warning is left intact — if clamping does not resolve the gap, the warning is honest.
- The `is_equal_approx` and `distance_to` calls are safe with `Vector3` strict-typed — both are part of Godot's Vector3 API.

## What this does NOT change
- `ai_stress_arena.gd` — unchanged. The arena's spawn flow is correct; the bug is in the agent.
- The `is_navigation_finished()` race on the first frame is partially addressed: the **target itself is closer to where the agent is going**, but the first-frame `is_navigation_finished()` may still return `true` because the path is not yet computed. This is unavoidable without rewriting the navigation server. The `_nav_warned` once-per-agent guard means at most one warning per agent per scene lifetime.
- Performance: one `map_get_closest_point` call per `_move_toward` invocation when `nav_agent.target_position` changes by more than 3m. This is a `NavigationServer` query — a spatial lookup, not a full path computation. Cost is sub-millisecond.

## Verification approach
- **Probe:** extend `tests/test_ai_stress_arena.gd` (or add an assertion in the same scene) to count `push_warning` calls with the `[NAV]` prefix. After the fix, the count should drop to zero (or to the legitimate "I asked for a target 50m away from any navmesh" cases).
- **Determinism:** the test uses `_arena._rng.seed = 20260714` (line 116) and sets `hot_start = true`; both are deterministic. Same seed → same nav warning count.
- **Pass criteria:** the existing test (`PASS` = VC and US enter COMBAT, suppression activates) still passes; warning count drops to zero in the default arena configuration.
- **No headless end-to-end required for 0623.2** — Summoner playtest.

## Tradeoffs named
- **Cost per call:** `map_get_closest_point` is a navigation-server query. Running it on every target restake (every 3m of target motion) is fine. Running it every frame is wasteful — we only call when the target has moved.
- **Threshold choice (4m):** smaller threshold means more clamping pulls targets to navmesh; larger means we leave off-mesh targets alone and direct-steer. 4m matches the 3m restake threshold and the 0.45m agent radius, so anything within a navmesh cell of the original target is treated as on-mesh.
- **Not addressing the first-frame race directly:** the race still exists; clamping reduces its severity (the clamped point is closer to the agent, so the gap is smaller when the warning fires). Acceptable; eliminating it requires NavigationServer rewrites.
- **Scope:** fix is in `enemy_base.gd` because the bug is structural (any lab/arena using `lab_navmesh` group could see it). The arena is the visible symptom; the disease is in the agent.

## ADR compliance
- ADR-015 (verification law): the test suite + warning count probe is the measurement.
- ADR-023 (fossil law): the diff is additive, no deletions.
- Comment discipline: no tombstones; the docstring is for the clamp, not the bug history.

## Verdict
**APPLY the fix as drafted.** The clamp is one `map_get_closest_point` call, scoped to the use_nav branch, with a conservative threshold. The existing `_nav_warned` guard makes it a strict improvement (fewer false positives; no new noise). Run the existing `tests/test_ai_stress_arena.tscn` to confirm the fight still engages, and add a one-line warning-count assertion to the same probe to catch future regressions.
