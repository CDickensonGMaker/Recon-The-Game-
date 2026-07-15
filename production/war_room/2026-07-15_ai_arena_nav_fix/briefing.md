# War Room Briefing — AI Stress Arena NAV Fix + Playtest Prep
**Date:** 2026-07-15
**Declared project:** RECONgame (`C:\Users\caleb\RECONgame`)
**Author:** recon-overseer (Arbiter, War Room summoned)
**Status of canon:** GAME_GUIDE.md + 15 ADRs; standing decree per OVERSEER_CHARTER §8
**GATE:** ACTIVE (seven P1s open including playtest ida9); arena work is **exempt** (bead 0623 is the AI North Star, build item; not gated by playtest P1s per OVERSEER_CHARTER §8)

---

## Summoner's directive (2026-07-15)
"open the RECONgame project, find the bead and continue working on the Ai Stress Test scene"

## Open beads in scope
- **RECONgame-0623 (P1, parent epic — OPEN):** AI North Star: smart enemies
- **RECONgame-0623.1 (P1, OPEN, UNBLOCKED):** AI stress arena — NAV warning fix
  - *Context:* one VC spawn logs `[NAV] enemy inside baked region -1, ~67.8m to target, no path`. Downgraded from `push_error` to `push_warning` in `enemy_base.gd:1544`. Need clean probe.
- **RECONgame-0623.2 (P1, OPEN, depends on six closed children):** AI stress arena — verify 3–5 minute sustained US-vs-VC firefight end-to-end
  - *Context:* Council 2026-07-15: closes on **Summoner playtest** (no automated headless end-to-end required). Verify 3–5 minute run with telemetry showing survival/suppression/withdrawal, not sponginess.

## What this council must decide
1. The fix for the `_move_toward` nav path that fires the warning when `is_navigation_finished()` returns true but the agent is still 67.8m from the target. The "clamp target to navmesh closest point OR retry" is a bead-given hint; council picks the binding approach.
2. Whether the fix is arena-only (because that's where the symptom appears) or upstream in `enemy_base.gd` (because the bug is structural and could surface in any lab/arena scene).
3. What probe/measurement counts as "fixed" per ADR-015 (verification law) — not "mitigated" or "likely fixed."
4. Playtest prep for 0623.2 — what minimum sanity check we run to confirm the arena is in a good state for the Summoner.

## Hard constraints (re-stated)
- Godot 4.7.1 strict GDScript, per `godot_standards.md`.
- DRIFT-9 is open: probe scenes must not be empty; if I write a probe scene, it must have a scene attached.
- 0623.1 is the only nav/AI code change authorized. **No scope creep** into other P0s (perf, drift, LW epic) unless the council explicitly decrees it.
- Probe must be deterministic per LW-1 determinism probe rules.
- ADR-023 fossil law: if I delete code, delete cleanly; `tests/test_fossils` will catch dead code.
- No tombstone comments (comment discipline, Summoner decree 2026-07-13).

## Existing code facts (read, not theorized)
- `scripts/levels/ai_stress_arena.gd:579-593` — `_bake_navmesh()` adds a `NavigationRegion3D` in the `lab_navmesh` group, bakes synchronously, prints polygon count. Two physics frames are awaited after `_bake_navmesh()` returns (lines 131-132).
- `scripts/levels/ai_stress_arena.gd:684-688` — VC spawn explicitly calls `nav_agent.set_navigation_map(_nav_region.get_navigation_map())` to bind the agent to the arena's map.
- `scripts/enemies/enemy_base.gd:245-247,253` — `_lab_nav` flag is `true` when ANY node is in the `lab_navmesh` group; the arena is in that group, so all arena enemies take the `_lab_nav = true` branch in `_move_toward()`.
- `scripts/enemies/enemy_base.gd:1525-1545` — `_move_toward()`:
  - sets `use_nav = true` when `_lab_nav` is set;
  - calls `nav_agent.target_position = pos` whenever the requested target has moved >3m;
  - checks `is_navigation_finished()` and falls through to direct steering;
  - if `direction.length() > 5m` and `is_navigation_finished()` is true in debug builds, logs `push_warning("[NAV] enemy inside baked region %d, %.1fm to target, no path" % [_nav_box, direction.length()])` once per agent.
- `scripts/enemies/enemy_base.gd:498-499` — `_think()` refreshes `_nav_box` from `NavBaker.box_index_at(global_position)`, which returns -1 for the arena (no NavBaker sites are stamped in the arena). The lab navmesh covers the whole arena, so `_nav_box = -1` is harmless and `use_nav` should route off `_lab_nav` only — but the warning text reports `-1` for cosmetic clarity.
- `scripts/world/nav_baker.gd:114-116` — comment confirms `NavigationServer3D.map_get_closest_point(map, to_point)` is the right API to project a world position onto the navmesh.
- `godot_4.7_features.md` + `skills/ai-navigation/SKILL.md` — the closest-point API is `NavigationServer3D.map_get_closest_point(map, to_point)`.

## The actual bug (read, not theorized)
The warning fires when **two conditions** are both true:
1. `is_navigation_finished()` returns true (the agent thinks the path is complete).
2. The agent is more than 5m from the requested target (the path is **clearly not** complete).

The most common root cause is that **the requested target sits just off the navmesh** (e.g., on top of a cover berm, inside a building footprint, or on a vertex that the navmesh eroded). The agent projects its target, computes a path, reaches the projected endpoint, and `is_navigation_finished()` becomes true — even though the original target is meters away. The agent then logs the warning and falls back to direct steering, which usually works (the agent still moves toward the target) but logs the false alarm.

A second, less-common cause is that the agent is on the navmesh but the requested target is **on the other side of a permanent obstacle** (the agent cannot reach it via navmesh at all). The fix for this case is **retry with the closest point** — clamp the target to the navmesh first; if still no path, the agent degrades to direct steering without complaint.

## The fix (hypothesis to test)
In `enemy_base.gd:_move_toward()`, after `nav_agent.target_position = pos` and before checking `is_navigation_finished()`, **clamp the target to the navmesh's closest reachable point** using `NavigationServer3D.map_get_closest_point(map, pos)`. This projects `pos` onto the navmesh. If the projected point is more than some threshold (e.g., 4m) from the original `pos`, the original target is unreachable — log a different (and quieter) warning, fall back to direct steering without complaining about the navmesh.

For the arena specifically, this is almost always the case where the target is a player's last-known position or a cover point placed near a building. The arena spawns both US and VC on the floor; their target `last_known_target_pos` may sit on a berm, in a building, or on the other side of a wall. The closest-point clamp resolves this.

## Architects summoned
- **lead-programmer** (nav/AI specialist)
- **ai-specialist** (gameplay loop integrity)
- **systems-designer** (loop / beacon consistency)
- **devil's-advocate** (fossil law, scope creep, "is the warning actually a bug?")

## What is NOT in scope
- Any change to `ai_stress_arena.gd` (the arena is correct; the bug is in `enemy_base.gd`).
- Any perf work (decoded mhfv).
- Any LW epic work (decoded p3f4, 6mba, clm4, 5i8a, k77e).
- Any DRIFT work (s14j, bgfq, t6z9, yu8b, ohun).
- Any new probe scene (the existing `tests/test_ai_stress_arena.tscn` is the test of record; if we need a closer-to-the-bug probe, we can extend it, but we do not write a new one — DRIFT-9).

## Beads to update
- 0623.1: claim, apply fix, run probe, close with proof.
- 0623.2: NOT closed by this council (per Summoner playtest rule); we update notes to record arena compile status and a deterministic dry-run of the existing `tests/test_ai_stress_arena.tscn`.
