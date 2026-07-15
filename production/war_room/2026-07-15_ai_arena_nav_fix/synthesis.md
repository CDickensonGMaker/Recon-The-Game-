# War Room Synthesis — AI Stress Arena NAV Fix + Playtest Prep
**Date:** 2026-07-15
**Declared project:** RECONgame (`C:\Users\caleb\RECONgame`)
**Authority:** `production/OVERSEER_CHARTER.md` + `production/GAME_GUIDE.md` + the 15 ADRs
**Beads in scope:** RECONgame-0623.1, RECONgame-0623.2
**GATE compliance:** 0623.1 is a bug fix (exempt per OVERSEER_CHARTER §8); 0623.2 is a playtest (exempt; Summoner closes it).

---

## The Decree

The Council approves the **structural fix** to the nav path in `scripts/enemies/enemy_base.gd:_move_toward()`. The fix clamps the requested target to the navmesh's closest reachable point using `NavigationServer3D.map_get_closest_point()` before submitting it to the `NavigationAgent3D`. This addresses the false-positive `[NAV] enemy inside baked region -1, ~67.8m to target, no path` warning that fires once per first-spawned VC in the arena (and would fire in any future lab/arena scene using the `lab_navmesh` group).

The Council further directs the Arbiter to **extend the existing probe** at `tests/test_ai_stress_arena.tscn` with a `push_warning` counter that asserts the `[NAV]` warning count is zero in the default arena configuration. This is the verification-law proof that closes the bead (per ADR-015, "mitigated" never closes a bead; a passing probe with explicit assertion does).

The Council **does not close 0623.2**. That bead closes on the Summoner's 3-5 minute playtest per the 2026-07-15 ruling (no automated headless end-to-end required). The Council's job for 0623.2 is to **prep**: confirm the arena compiles headless, the existing probe still passes after the fix, and the build is ready for play.

---

## Binding decisions

### 1. Fix in `enemy_base.gd`, not `ai_stress_arena.gd`
The bug is structural. The arena is the visible symptom (one VC spawn, 67.8m gap), but the disease is in the agent's pathing. Any future lab/arena scene would re-introduce the warning without the structural fix.

### 2. The fix, concretely
In `scripts/enemies/enemy_base.gd:_move_toward()`, between the `use_nav` determination and the `nav_agent.target_position = pos` assignment, add:

```gdscript
# Clamp the target to the navmesh. Off-mesh points (LP behind a wall,
# cover point on a berm, agent on a navmesh-eroded vertex) reach
# is_navigation_finished() while still meters from the original target.
var map: RID = nav_agent.get_navigation_map()
if map.is_valid():
    var clamped: Vector3 = NavigationServer3D.map_get_closest_point(map, pos)
    if pos.distance_to(clamped) < 4.0:
        pos = clamped
```

- The 4m threshold is conservative: anything within a navmesh cell of the original target is treated as on-mesh.
- If the closest point is more than 4m from the original target, the target is genuinely off-mesh — the agent direct-steers without complaint. The existing `is_navigation_finished() && direction.length() > 5m` warning still fires (the warning is honest in that case).
- Cost: one `NavigationServer3D.map_get_closest_point` call per `_move_toward` invocation when the target has moved by more than 3m. Sub-millisecond.

### 3. The probe extension
Add to `tests/test_ai_stress_arena.gd`:

```gdscript
var _nav_warnings: int = 0


func _collect_metrics() -> void:
    # ... existing code ...
    # Count NAV warnings; the fix targets 0 in default configuration.
    _nav_warnings = Engine.get_main_loop().get_child(0).get_meta("nav_warn_count", 0)
```

And in `_finish()`:
```gdscript
if _nav_warnings > 0:
    _failures += 1
    print("FAIL: %d [NAV] warnings fired during the probe (expected 0 after fix)" % _nav_warnings)
```

The counter is wired through a small helper that intercepts `push_warning` calls with the `[NAV]` prefix. This is the regression guard for future agents that re-introduce the bug.

### 4. Comment discipline
The 3-line comment is a **constraint the code cannot show** (the off-mesh contract). The comment is **not** a tombstone (it does not narrate history or explain the change). It stays.

### 5. Out of scope
- No change to `ai_stress_arena.gd`.
- No change to `ai_hp_multiplier`, `ai_accuracy_mult`, `ai_retreat_hp`, `reserve_rate_multiplier`.
- No new probe scene (DRIFT-9).
- No HUD affordance.
- No perf work (mhfv).
- No LW work (decoded k77e, 5i8a, 6mba, clm4, p3f4).
- No drift work (s14j, bgfq, t6z9, yu8b, ohun).

### 6. Bead updates
- **0623.1:** claim, apply fix, run probe, close with proof.
- **0623.2:** update notes to record "arena compiles headless; existing probe passes; ready for Summoner playtest" — **do not close**.

### 7. Tradeoffs named
- **Cost per call:** one `map_get_closest_point` per target restake. Acceptable; sub-millisecond.
- **Threshold choice (4m):** matches the 3m restake threshold + 0.45m agent radius. Smaller = more clamping; larger = more off-mesh direct-steering. 4m is the floor that treats "one navmesh cell away" as on-mesh.
- **First-frame race:** the race still exists; the warning still fires if the target is genuinely off-mesh on the first frame. The once-per-agent `_nav_warned` guard prevents log spam. Eliminating the race requires NavigationServer rewrites (out of scope).
- **Arena-only vs structural:** structural wins. The bug is in the agent; the arena is just where the user noticed it.
- **Per-call-site vs chokepoint fix:** chokepoint wins. All nav-routed movement flows through `_move_toward()`; future goals get the fix for free.

---

## Execution plan (Arbiter, in order)

1. `bd update RECONgame-0623.1 --claim` (claim the bead)
2. `bd update RECONgame-0623.1 --notes "Applying fix to enemy_base.gd:_move_toward(): clamp target to navmesh closest point before navigation agent submission. See production/war_room/2026-07-15_ai_arena_nav_fix/synthesis.md for council decree."`
3. Edit `scripts/enemies/enemy_base.gd:_move_toward()` per the diff above
4. Edit `tests/test_ai_stress_arena.gd` to add the `push_warning` counter
5. Run the headless probe: `godot --headless --path . res://tests/test_ai_stress_arena.tscn`
6. Verify the probe passes AND `[NAV]` warning count is 0
7. `bd close RECONgame-0623.1 --reason "Fix applied: scripts/enemies/enemy_base.gd:_move_toward() clamps target to navmesh closest point via NavigationServer3D.map_get_closest_point(). Probe at tests/test_ai_stress_arena.tscn passes with 0 [NAV] warnings (seed 20260714, hot_start=true, 15s). 0623.2 remains open for Summoner playtest."`
8. `bd update RECONgame-0623.2 --notes "Arena compiles headless; existing probe passes; ready for Summoner 3-5 minute playtest. Per 2026-07-15 council ruling, this bead closes on Summoner playtest only."`
9. `git add` the changed files, commit with the standard footer, `git push`
10. Report status back to the coordinator

---

## Canonical design inputs
- `production/war_room/handoff_ai_stress_arena_2026-07-14.md`
- `production/war_room/2026-07-15_arena_handoff_review/synthesis.md`
- `production/war_room/synthesis_ai_goals.md` (AI GOAL DOCTRINE)
- `production/adr/ADR-015-verification-and-gate-law.md`
- `production/adr/ADR-023-the-fossil-law.md`
- `RECONgame-0623` (AI North Star, parent epic)
- `RECONgame-0623.1` (open, the fix)
- `RECONgame-0623.2` (open, the playtest)
- `scripts/enemies/enemy_base.gd` (the fix site)
- `tests/test_ai_stress_arena.gd` (the probe)
- `~/.claude/architect_knowledge/GodotPrompter/skills/ai-navigation/SKILL.md` (NavigationServer3D API)
