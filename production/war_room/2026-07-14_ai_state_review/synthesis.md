# War Room Synthesis — State of AI in RECONgame

## Decree: Current AI State

| System | Status | Notes |
|--------|--------|-------|
| Enemy AI state machine | **Functional** | IDLE/ALERT/COMBAT/SUPPRESSED/SEEKING_COVER/FLANKING/ADVANCING/RETREATING/DEAD all wired and executing. |
| Enemy goal scoring | **Functional** | Quake-3-style goal scoring with incumbent hysteresis; maps cleanly to states. |
| Enemy perception | **Functional** | Alert tiers, awareness, LOS, last-known, corpse discovery, noise reaction, spider-hole ambush. |
| Enemy squad coordination | **Functional** | `EnemySquad` static registry: shared target, breadcrumbs, hunt, covering fire, engagement census, grenade broker. |
| Ally individual AI | **Functional** | IDLE/COMBAT/SEEKING_COVER/DEAD; orders FOLLOW/HOLD/MOVE_TO. |
| Ally squad tactics | **Missing** | No suppression, flanking, advancing, retreat, or covering-fire coordination between allies. |
| Navigation | **Partial** | Works in Gore Lab via `lab_navmesh`; outside lab relies on `NavBaker` boxes with direct steering fallback. |
| Determinism | **Broken** | `randf()` inside `CombatManager.has_line_of_sight` poisons RNG every frame (bead `RECONgame-atov`, P0). |
| Cover validity | **Weak** | Cover search uses radial offsets and cell claims; no raycast proof that cover actually blocks LOS. |
| Civilian AI | **Missing** | Models exist; no behavior state machine (bead `RECONgame-jlo4`). |

## What the AI Combat Stress Test Arena Should Be

A **Gore Lab-derived scenario runner** that exposes enemy archetypes to controlled combat conditions and reports honest metrics.

### v1 Scope
- Four designed scenarios spawned on the existing 44m arena:
  1. **CQB breach** — VC in cover at 15-25m, player pushes from south.
  2. **Open-field advance** — NVA squad north, player in the open, tests suppression/retreat.
  3. **Ambush from spider hole** — sapper triggers at 7m, tests reaction time.
  4. **Fireteam demo** — 5-man US squad present (SquadSystem if possible, or ally fallbacks), tests ally survivability.
- Telemetry panel: alive by archetype, state histogram, average time-to-first-shot, player damage taken, wave clear time.
- Assertions via a headless probe: each scenario runs for N seconds and checks that enemies enter COMBAT, use cover, and do not get stuck.

### Blockers to Acknowledge
- P0 determinism bug makes repeated runs non-identical. Fix in parallel (bead `RECONgame-atov`).
- Ally squad tactics are out of scope for v1.
- True cover validation needs a separate geometry probe, not the arena itself.

### Next Action
Convene a focused War Room session to design and implement the AI Combat Stress Test Arena. Scope is enemy behavior + metrics on Gore Lab foundation; allies present but not the primary stress target.
