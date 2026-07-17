# AI Programmer — State of AI Code

## Enemy AI (`scripts/enemies/enemy_base.gd`)

**States implemented:** IDLE, ALERT, COMBAT, SUPPRESSED, SEEKING_COVER, FLANKING, ADVANCING, RETREATING, DEAD.

**Goal brain operational:** `_think()` runs at LOD-throttled cadence (0.15s close, 0.3s mid, 0.6s far). `_evaluate_goals()` scores ENGAGE_TARGET, SEEK_COVER, SUPPRESS_TARGET, FLANK_TARGET, ADVANCE, RETREAT, INVESTIGATE, HOLD_POSITION. `_update_state_for_goal()` maps the winning goal to the low-level state. `_execute(delta)` dispatches by state. This is a real two-tier AI.

**Perception stack:** AlertTier (RELAXED/SUSPICIOUS/ALERT/COMBAT), awareness accumulator, line-of-sight via `CombatManager.has_line_of_sight`, last-known position, contact confidence debounce, corpse discovery, noise reaction through `NoiseBus`. Spider-hole ambush and tunnel retreat are wired.

**Tactical brokers:** cover claim map (`_cover_claims`), squad engagement census, covering-fire window, grenade cooldown broker through `EnemySquad`.

**Live blockers:**
- `randf()` inside `has_line_of_sight` (bead `RECONgame-atov`) poisons the global RNG stream every frame — this is a P0 determinism bug.
- Navigation is partly stubbed: `_nav_box = NavBaker.box_index_at(...)` is read but `_move_toward` falls back to direct steering; true navmesh pathing is only guaranteed in Gore Lab via the `lab_navmesh` group.
- EnemyBase has no real cover-finder raycasts; cover search uses fixed radial offsets and claims cells, which can place men behind nothing.

## Ally AI (`scripts/allies/ally_base.gd`)

**States implemented:** IDLE, COMBAT, SEEKING_COVER, DEAD.

**Orders implemented:** FOLLOW, HOLD, MOVE_TO. The squad system can order all allies at once.

**Goal brain minimal:** only ENGAGE_TARGET, SEEK_COVER, HOLD_POSITION. No suppression, flanking, advancing, or retreat for allies.

**Targeting:** nearest enemy within 60m; no prioritization by threat or player call-outs.

## Spawning / Arena Foundation (`scripts/levels/gore_lab.gd`)

Gore Lab already builds a 44m arena, bakes a navmesh, spawns cover, vegetation, player, optional allies, and auto-respawning 7-man waves. It has live AI debug overlays (state, goal, target, LOS, cover, suppression). This is the correct foundation for the AI Combat Stress Test Arena.
