# 03 — AI Detection & the LOD-Simulated World

**Status:** SEED (2026-07-16). The intended canonical home for the detection model and its interaction
with the LOD-tier simulation. Fills in as the systems are wired; canon still lives in the ADRs it cites.

## The Fairness Law (binding — the spine of detection)

Detection is NOT accuracy. A unit becoming *aware* of the player does not make its first rounds hit.

- **Awareness ≠ accuracy.** Accuracy ramps with *exposure* (how long, how openly the player is seen), not
  with the alert state flipping.
- **The first shot at an unaware player is a near-miss** — the war announces itself, it does not snipe you
  from concealment on frame one.
- **Every threat telegraphs:** muzzle flash, tracers, voices, and the crack of a passing round always
  precede lethality. Death comes from *situation* (Pillar 1), never from an unseen dice roll.

See DESIGN §4.2 (Living Fight Amendment 1) and the ADR-005 witness rule.

## The perception pipeline (as built)

The awareness accumulator + line-of-sight path drives PATROL → ALERT → COMBAT transitions through
`_update_perception`. Sight is capped by terrain/vegetation (the GameplayGrid `_sight_cap`, 45m under
canopy to ~140m in the open); foliage concealment and hard-cover LOS are the levers a stalking player
uses. (Arena caveat: the AI stress arena currently has no GameplayGrid, so every agent there sees a flat
~140m and foliage conceals nothing — arena detection does not yet exercise this pipeline. See the plan's
Track D.)

> **P0 determinism defect (open):** `randf()` inside `has_line_of_sight()` runs per-frame and poisons the
> shared RNG stream, making ADR-010 determinism framerate-dependent (bead `atov`). Detection is not
> deterministic until that `randf` leaves the LOS path.

## Detection across the LOD boundary

Detection cost is the reason the LOD-tier simulation exists (ADR-025). Awareness is a T0/T1 concern only —
a sleeping (T2) or data-only (T3) unit does not run perception; it resolves statistically. The Ambience
Law guarantees an off-AO unit's "detection" of the player can never silently cost the player: the instant
an off-screen outcome could matter, it has already become an offer through `DynamicMissionFactory`.

Tier bands, mechanism, and the phased build are specified in **ADR-025**. This file will absorb the
detection-specific rules (awareness decay by tier, re-materialization awareness state, patrol-node intel
decay) as ADR-025's phases land.

## Related
- **ADRs:** ADR-005 (witness rule) · ADR-010 (determinism) · ADR-021/022 (the intel loop — patrol to
  learn the ground, the observed/annotated map) · ADR-025 (LOD-tier simulation).
- **Beads:** `atov` (LOS `randf` determinism P0) · the LOD-sim implementation bead.
- **Files:** `scripts/enemies/enemy_base.gd` (`_update_perception`, `has_line_of_sight`),
  `terrain/core/gameplay_grid.gd` (`_sight_cap`).
