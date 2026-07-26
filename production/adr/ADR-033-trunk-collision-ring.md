# ADR-033: Trunk Collision Ring — physics only within 70m of the player

**Status:** PROPOSED
**Date:** 2026-07-25

## Ruling

Caleb, 2026-07-25, verbatim: **"the physics should only apply to trees within a 70m radius
of the player."**

This is the player-keyed pooled trunk ring that `terrain/vegetation/tree_cover_layer.gd`'s
own cap comment had named as its successor (bead 503b) since the TREE_COVER switchover.

## The problem, measured

- Full-AO census (seed 47225): **3,689 trunk StaticBody3D of 3,715 total bodies** — the
  resident AO (ADR-013) held a physics body per cover trunk, and trunks were ~99% of all
  bodies, capped only by `MAX_TRUNKS_PER_CHUNK = 150`.
- Uncapped candidate truth (measured 2026-07-25, same seed, whole AO through
  `VegetationManager._build_scatter`): **26,493 COVER_TRUNK instances** — the 150 cap was
  silently dropping ~86% of jungle cover.
- Blast rebuilds (`terrain/systems/damage_system.gd:145-151` →
  `terrain/vegetation/vegetation_manager.gd:403-420` `clear_area` →
  `_rematerialize:425-436` → `TreeCoverLayer.generate_for_chunk`) freed old bodies with
  `queue_free` (deferred) while building replacements same-frame — barrage tests stacked
  live+dying bodies past **Jolt's 32,768 body cap** and killed `tests/test_patrol_world.tscn`.

## Decision

One pooled collision ring keyed to the player replaces resident trunk bodies entirely:

- **Chunks store candidates, not bodies.** `generate_for_chunk` records COVER_TRUNK
  positions/radii as packed arrays in `_chunk_trunks`
  (`terrain/vegetation/tree_cover_layer.gd:136-150`). Rebuilds are body-free — the Jolt
  churn class is structurally gone.
- **`RING_RADIUS = 70.0`** (`tree_cover_layer.gd:37`) — Caleb's number; the solid render
  ring is 65m (`near_distance`, `:45`), so collision always covers what looks solid.
- **Pool of `POOL_MAX = 1280` StaticBody3D** (`:40`), built lazily, never freed. Measured
  worst 70m-ring demand: **453** candidates naturally, **919** with mission density boosts
  (`scripts/missions/mission_generator.gd:883-892` values stacked worst-case at the densest
  spot) → 1280 = ~40% headroom. `CylinderShape3D` resources are shared per distinct
  COVER_TRUNK radius (`_shape_for`, `:287-294`) — 3 distinct shapes in practice on this
  seed's pools, ≤7 possible (`COVER_TRUNK`, `:20-28`). Parked bodies: `collision_layer = 0`
  + parked at `PARK_POS` (`:280-283`).
- **Delta update** in `_physics_process` (`:177-186`): every 0.25s or on >2m center
  movement; releases candidates that left the ring, bodies ones that entered
  (`_update_ring`, `:200-246`). Ring center = `ring_center_override` (test seam, `:70`),
  else `GameManager.player` (`:189-195`), else **no bodies at all**. Demand beyond the pool
  assigns nearest-first and warns once per session (`:229-234`) — no silent cap.
- **`MAX_TRUNKS_PER_CHUNK` is DELETED** (fossil law, ADR-023). Candidates are pure data
  and need no cap.

## Consequences

- **ACCEPTED: beyond 70m, bullets do not strike trunk colliders.** Concealment and AI
  sight stay on the density grid (`scripts/ai/sight_cap.gd:32-39`), which never used
  bodies. If long-range trunk hits ever matter, the named future option is density-based
  probabilistic occlusion for bullet paths past the ring — revisit then, not now.
- **Gameplay change: dense jungle inside the ring now gets FULL cover density.** The 150
  cap is gone, so where the player stands, every cover trunk collides (measured up to ~919
  at once vs the old per-chunk 150). Cover got MORE honest near the player, not less.
- Total physics bodies at a dense center measured **478** (was 3,715 resident) —
  `tests/test_trunk_ring.gd` holds the line at <5,000.
- `tests/test_patrol_world.tscn` runs clean with no Jolt body-limit error (verified
  2026-07-25).

## Alternatives considered

- **Churn queue** (throttle body destroy/create across frames on rebuild): treats the
  symptom, keeps 3,689+ resident bodies, and still pays full-AO body cost forever. Dropped.
- **Raising the per-chunk cap**: linear trade of crash-margin vs missing cover; the census
  shows no number both honest (26k candidates) and safe (32,768 Jolt cap). Dropped.

## Probes

- `tests/test_trunk_ring.tscn` — candidates-without-bodies, assignment ≤ POOL_MAX, shared
  shapes, 200m release/reassign, clear_chunk release, blast rebuild = zero net new bodies.
- `tests/test_tree_cover_lod.tscn` / `tests/test_tree_cover_wired.tscn` — pre-existing
  cover probes, re-anchored on `ring_center_override`.
