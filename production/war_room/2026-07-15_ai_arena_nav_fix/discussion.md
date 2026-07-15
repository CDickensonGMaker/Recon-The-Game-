# War Room Discussion — AI Stress Arena NAV Fix + Playtest Prep
**Date:** 2026-07-15
**Attendees:** lead-programmer (nav specialist), ai-specialist, systems-designer, devil's-advocate
**Reading the analyses in** `analysis/`

## Convergence

All four architects **converged on the same fix** without seeing each other's drafts first.

1. **The warning is a false positive on the first frame after spawn** (lead-programmer, ai-specialist). The arena's VC first-spawn lands at a point 60-80m from its `last_known_target_pos`. The path is not yet computed when the first `_move_toward()` runs; `is_navigation_finished()` returns `true` because no path exists at all. The agent is far from the target. The warning fires once per agent (`_nav_warned` guard) and the agent direct-steers correctly on frame 2+.

2. **The fix is structural** (systems-designer, lead-programmer, ai-specialist). The bug is in the agent's pathing, not the arena. Any future lab/arena scene using the `lab_navmesh` group would see the same warning without the structural fix.

3. **The fix is a `map_get_closest_point` clamp inside `_move_toward()`** (lead-programmer). When the target is on a berm, in a building, or in a navmesh-eroded margin, the projection pulls it onto the nearest reachable surface. The agent then pathfinds to that surface. The existing `is_navigation_finished() && direction.length() > 5m` warning is left intact for genuine off-mesh cases.

4. **The probe must assert a `[NAV]` warning count** (ai-specialist, devil's-advocate). ADR-015 (verification law) requires proof, not "mitigated." A one-line `push_warning` counter in the existing `tests/test_ai_stress_arena.tscn` is the regression guard.

## Divergences (resolved)

- **Comment verbosity (devil's-advocate).** Lead-programmer drafted a 4-line comment explaining the clamp. Devil's-advocate argued this is a constraint the code cannot show (the off-mesh-target contract) but should be 3 lines, not 4. **Resolved:** accept 3 lines.
- **Scope (systems-designer, devil's-advocate).** Is the fix arena-only or structural? Both agreed structural — the bug is in the agent, not the arena. **Resolved:** apply in `enemy_base.gd`, not in `ai_stress_arena.gd`.
- **The cosmetic "-1" in the warning text** (devil's-advocate). The phrase "inside baked region -1" reads confusingly. **Resolved:** leave the text alone — rephrasing is tombstone-comment territory.
- **First-frame race** (lead-programmer, ai-specialist). The race still exists after the fix; the warning will still fire if the target is genuinely off-mesh on the first frame. **Resolved:** acceptable. The once-per-agent `_nav_warned` guard prevents log spam. Eliminating the race requires NavigationServer rewrites (out of scope).

## Out-of-scope decisions (reaffirmed)

- **No change to** `ai_stress_arena.gd` (the arena is correct; the bug is in the agent).
- **No change to** `ai_hp_multiplier`, `ai_accuracy_mult`, `ai_retreat_hp`, `reserve_rate_multiplier` (tuning is Phase C; 0623.1 is Phase B cleanup).
- **No new probe scene** (DRIFT-9; we extend the existing one).
- **No HUD affordance** (the r4bk law is for player-visible systems; warnings are diagnostic).
- **No perf work** (mhfv is its own decree).
- **No LW work** (decoded k77e, 5i8a, 6mba, clm4, p3f4).

## Open questions

None. The fix is small, structural, and gated by a deterministic probe. The bead 0623.1 closes when the probe PASSES (existing assertions + new warning-count assertion). The bead 0623.2 does not close on this council's work; it closes on the Summoner's 3-5 minute playtest per the 2026-07-15 ruling.

## What the Arbiter will do

1. Apply the fix to `scripts/enemies/enemy_base.gd:_move_toward()` with the 3-line comment.
2. Extend `tests/test_ai_stress_arena.gd` with a `push_warning` counter that fails the test if any `[NAV]` warning fires during the 15s probe.
3. Run the existing `tests/test_ai_stress_arena.tscn` headless to verify the fix.
4. Update 0623.1 notes with the probe output and close the bead.
5. Update 0623.2 notes to reflect "ready for Summoner playtest" — NOT close.
6. `git add` the changed files, commit, push.
7. Report status back to the coordinator.
