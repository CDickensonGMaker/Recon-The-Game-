# ADR-031 — The Destruction Doctrine: state-swap, one blast bus, perf-gated terrain

**Status:** ACCEPTED 2026-07-25 by the Summoner (Caleb's morning rulings).
**Date:** 2026-07-25 · **Pillars:** 1 (believable firefights), 2 (atmosphere), 3 (freedom — fell cover).
**Related:** ADR-001 (PSX renderer), ADR-026 (PS2 budget / Forward+ / the perf floor), ADR-023 (fossil law),
ADR-010 (determinism). **War room:** `production/war_room/2026-07-25_support_fire_room/synthesis.md`.

---

## Decision

Environmental destruction is CHEAP and STATE-BASED, never a physics fracture (ADR-001 forbids fracture).

1. **State-swap, not fracture.** A tree fells to a log to a stump; a hut swaps intact → damaged → rubble.
   What sells it: the mesh-swap hidden under an occluding `GunFX._spawn_explosion_visual` CPUParticle burst
   (`gun_fx.gd:163`, never gib RigidBody) + a distance-scaled screen shake + PERMANENCE.
2. **One blast bus.** All explosive damage to world objects rides the existing shared `AgentRegistry.props`
   bus (`combat_manager.gd:178-185`). A destructible REGISTERS on it and answers `take_damage` (ADR-003).
   No new call-sites, no second damage authority (ADR-023).
3. **Terrain: scar-first, holes throttled and perf-gated.** `DamageSystem`'s scar-decal + veg-clear is the
   cheap default that reads. The real heightmap hole (`modify_terrain`) is a MAIN-THREAD chunk rebuild and
   `MAX_DEFORMS` is a per-mission cap, not a per-frame throttle — real holes are throttled per-frame and gated
   behind the measured perf proof.
4. **Permanence is sacred within the active firefight radius**, recycling only far behind the patrol.
5. **Determinism (ADR-010):** all fell/rubble scatter seeds from position + operation seed, never `Time`.
6. **Fossil (ADR-023):** the general `Destructible` is the one destructible component; the arena's
   `DestructibleFortification` folds into it (now shared via `FireSupportBench`).

## The gate (binding)
**Terrain real-holes and building destruction ship only after the worst single-frame spike is measured** —
a napalm run + AC-47 + a live firefight, ship config, on the Intel-UHD floor (ADR-026: the frame is already
~19–23fps both-bound with Part B unshipped). The AI arena is that harness.

## Consequences (the sacrifice)
Most craters may down-tier to scar-only (no hole) to protect the frame; buildings buy atmosphere but no new
verb and carry the perf tail (built last); permanence is a rising per-patrol tax bounded by far-field recycle.

## Build state
**SHIPPED (local commit `1bc01c4b`, unpushed):** the shared `FireSupportBench` rig (extracted from the AI
arena), the support-fire range (`scripts/levels/support_fire_range.*`), WP/Willy Pete as a real fire kind
(bench-stocked only), and P3 tree felling (was `scripts/world/fellable_tree.gd`; superseded 2026-08-07 by
S29's `scripts/world/tree_break_system.gd` — banded break at hit height, state-swap, still never RigidBody).
Probe: `tests/test_support_fire_bench`. **P2 perf-proof, P4 terrain holes, P5 buildings: NOT built — held
behind the gate above.**

## Related
ADR-026 (the perf budget this obeys) · ADR-023 (one component, one bus) · `production/DESTRUCTIBLE_JUNGLE_PLAN.md`
(the prior plan — partly aged out: the blast bus already exists; TreeCoverLayer is per-instance, so the
merged-patch bitmask is not needed).
