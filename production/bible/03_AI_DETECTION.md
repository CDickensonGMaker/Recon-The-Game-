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

See the ADR-005 witness rule (`../adr/ADR-005-detection-beacon-witness-rule.md`) and the Fairness law in
`../../CLAUDE.md`. *(The old `DESIGN §4.2` / "Living Fight Amendment 1" pointer is dead — `DESIGN.md` has
no numbered sections and no amendments.)*

## The perception pipeline (as built)

The awareness accumulator + line-of-sight path drives PATROL → ALERT → COMBAT transitions through
`_update_perception`. Sight is capped by terrain/vegetation (the GameplayGrid `_sight_cap`, 45m under
canopy to ~140m in the open); foliage concealment and hard-cover LOS are the levers a stalking player
uses. (Arena caveat: the AI stress arena currently has no GameplayGrid, so every agent there sees a flat
~140m and foliage conceals nothing — arena detection does not yet exercise this pipeline. See the plan's
Track D.)

> **Determinism: FIXED (verified 2026-07-24).** The heavy-jungle LOS block is seeded per `(cell, mission)` —
> `los_rng.seed = hash([Vector2(x, z), mission_seed])` (`terrain/core/gameplay_grid.gd:407-409`) — so a given
> LOS query returns the same block decision at any framerate (ADR-010). Guarded by
> `tests/test_los_determinism.gd`.

## Detection across the LOD boundary

Detection cost is the reason AI runs on activity tiers at all. Awareness is a hot-tier concern only — a
dormant or data-only unit does not run perception; it resolves statistically. The Ambience Law guarantees
an off-AO unit's "detection" of the player can never silently cost the player: the instant an off-screen
outcome could matter, it has already become an offer through `DynamicMissionFactory`.

> **Tier authority (2026-07-20):** ADR-025's four-tier LOD scheme is **SUPERSEDED — never ratified**
> (`ADR-025-lod-tier-simulation.md:3`). The live tier model is the AI-consolidation decree — *"AIDirector
> tick-list wins; WorldSim tiers die"*
> (`production/war_room/2026-07-18_ai_consolidation_plan/synthesis.md:12-16`, BLESSED). Cite that decree,
> not ADR-025, for tier bands and the phased build.

## Related
- **ADRs:** ADR-005 (witness rule) · ADR-010 (determinism) · ADR-021/022 (the intel loop — patrol to
  learn the ground, the observed/annotated map) · ADR-025 (LOD-tier simulation — **SUPERSEDED 2026-07-20**;
  tier authority is `production/war_room/2026-07-18_ai_consolidation_plan/synthesis.md:12-16`).
- **Files:** `scripts/enemies/enemy_base.gd` (`_update_perception`, and `_can_witness` — the perception/
  witness LOS via `CombatManager.has_line_of_sight`), `terrain/core/gameplay_grid.gd` (`_sight_cap`; the
  seeded heavy-jungle LOS block at `:407-409`).
