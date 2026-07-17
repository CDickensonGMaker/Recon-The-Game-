# Implementation Plan — AI Combat Stress Test Arena

## Goal

Build a standalone arena scene `scenes/levels/ai_stress_arena.tscn` where US and VC/NVA squads fight autonomously. The arena stresses the existing enemy and ally AI, exposes what currently works, and provides honest telemetry. Visual quality is secondary; tactical readability is primary.

## Scope

**In scope for v1:**
- 120m x 120m flat arena with five zones:
  - **Firebase (SW):** US spawn, sandbag perimeter, defensive positions.
  - **Village (NE):** simple buildings, paths, defensive positions.
  - **Central combat zone:** open ground for long-range and flanking.
  - **Natural cover clusters:** trees, rocks, bushes scattered between zones.
  - **Rice fields (SE/NW):** flat open areas that create exposure risk.
- Configurable force counts (default 18 US vs 18 VC, scalable).
- US squads: SL, RTO, Medic, 2× Rifleman, Grenadier, MG.
- VC/NVA squads: SL, 2× Rifleman, Automatic Rifleman, Support Weapon (RPG), Grenadier.
- Reinforcement pools so the firefight sustains **3–5 minutes**.
- Allies use existing `AllyBase` AI with MOS roles and the new body-pool randomizer.
- Enemies use existing `EnemyBase` AI with squad IDs for coordination.
- Telemetry panel (CanvasLayer) showing live state counts, suppression, kills, sim time.
- Debug labels above every soldier (state, goal, target, cover, suppression).
- Player spawns as a neutral observer at firebase; can move and watch.
- Headless probe that runs for 15s and asserts basic AI activation.

**Out of scope for v1 (honest):**
- New squad tactics for allies (suppress-and-move, bounding overwatch). Ally AI stays as-is.
- Persistent soldier memory / story logging.
- Procedural terrain.
- Dedicated spectator camera (player just stands at firebase).
- Civilians.

## Architectural Decisions

### 1. Standalone arena, not a GoreLab subclass
`GoreLab` is a 44m combat bench with hardcoded waves and cover scatter. The stress arena needs a different layout, force structure, and telemetry. Creating a new `AIStressArena` script is lower risk than refactoring `GoreLab` into a base class. We will copy small builder patterns from Gore Lab where useful, but keep the new scene self-contained.

### 2. Reuse `AllyBase` + `EnemyBase` directly; do not drag in `GameWorld`/`MissionDirector`
`SquadSystem` and `MissionDirector` are built for generated campaign missions and pull in terrain, persistence, and toast systems. The arena will spawn allies with `AllyBase.spawn_ally()` and enemies with `EnemyBase.spawn_enemy()`, then assign roles/weapons manually. To avoid duplicating the body-pool logic we just shipped, we will extract two static helpers from `SquadSystem`:
- `static func weapon_for_mos(mos: String) -> String`
- `static func pick_body_for_mos(mos: String, rng: RandomNumberGenerator) -> String`

### 3. Flat floor + primitive structures
No procedural terrain. The arena floor is a `PlaneMesh` collider. Trenches, sandbags, buildings, and rocks are built from `BoxMesh` / `CylinderMesh` primitives and added to the `nav_source` group so the navmesh carves around them.

### 4. Navigation via `NavigationRegion3D`
Same pattern as Gore Lab: `SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN`, group name `nav_source`, agent radius 0.45, height 1.8.

### 5. Configurable force counts with reinforcement for 3–5 minute fights
Exported variables `@export var us_squads_active: int = 3`, `@export var vc_squads_active: int = 3`, `@export var men_per_squad: int = 6`. Default 18v18 on the field at start. Each side also has a **reserve pool** of squads that reinforce as active squads are destroyed. Reinforcements spawn at base areas after a cooldown, keeping the battle alive for the target 3–5 minute window.

### 6. Fight pacing levers
To hit 3–5 minutes without making combat feel bullet-spongey:
- Start forces ~90m apart (firebase SW vs village NE) so approach and positioning eat 30–60s.
- Reinforcements arrive staggered, not all at once.
- Cover density is high enough that units survive until flanked.
- No instant-kill headshot tuning; default weapon/HP values remain.
- Round hard-caps at 5 minutes and reports stats even if both sides still have men.

## File Changes

### New files
- `scripts/levels/ai_stress_arena.gd` — main arena controller.
- `scenes/levels/ai_stress_arena.tscn` — scene wrapper.
- `tests/test_ai_stress_arena.gd` — headless probe.
- `tests/test_ai_stress_arena.tscn` — headless test scene.

### Modified files
- `scripts/squad/squad_system.gd` — expose `weapon_for_mos` and `pick_body_for_mos` as static helpers so the arena can reuse the body-pool randomizer without dragging in the full mission system.

## Implementation Steps

1. **Extract SquadSystem helpers**
   - Move `MOS_WEAPON`, `WEAPON_BODY_POOLS`, `DETERMINISTIC_MOS_BODY` to `static const`.
   - Add `static func weapon_for_mos(mos)` and `static func pick_body_for_mos(mos, rng)`.
   - Update `setup()` to call the helpers; behavior unchanged.
   - Run `test_squad_body_pool.tscn` to confirm.

2. **Build arena environment**
   - `_build_floor()`: 120m plane with grid shader.
   - `_build_walls()`: perimeter walls to keep grenades in.
   - `_build_firebase()`: sandbag wall segments, fighting holes, spawn platform at SW.
   - `_build_village()`: 4-6 simple buildings, paths at NE.
   - `_build_cover_clusters()`: scattered rocks and sandbags between zones.
   - `_plant_vegetation()`: reuse `GroundClutter` to place rice patches, palm clusters, bushes as cover markers.
   - `_bake_navmesh()`: NavigationRegion3D over `nav_source` group.

3. **Spawn forces and reserves**
   - `_spawn_player()`: observer spawn at firebase.
   - `_spawn_us_squad(center, order)`: creates 6 allies with MOS roles and body-pool randomization.
   - `_spawn_vc_squad(center, data_paths)`: creates 6 enemies with squad_id set, mix of `vc_rifleman`, `vc_sapper`, `nva_regular`, `nva_rpg`.
   - Place initial firebase squads in HOLD/MOVE_TO defensive positions; place VC squads in village/north tree line with patrol or alert posture.
   - Reserve system: track `us_reserves_remaining` and `vc_reserves_remaining`; when an active squad is wiped, queue a replacement that spawns at the base after a 25–40s cooldown. Each side gets 2 reserve squads by default.

4. **Telemetry and debug UI**
   - CanvasLayer with `Label` panel top-right.
   - Live counts: US alive / total, VC alive / total, sim time, reserves left.
   - State histograms for enemies and allies.
   - Average suppression per side.
   - Total kills per side.
   - Debug labels above every agent showing state/goal/target/cover/suppression, similar to Gore Lab.

5. **Round lifecycle**
   - Round starts on `_ready()`.
   - Reinforcements feed in as squads die.
   - Round ends when one side has no living men **and** no reserves, **or** when 5-minute hard cap is reached.
   - HUD shows winner and stats; auto-restart after 8s or press `R`.
   - On restart, clear forces, reset reserve counters, respawn.

6. **Headless probe**
   - `tests/test_ai_stress_arena.tscn` loads the arena, runs for 15s.
   - Assertions:
     - No crash or error spam.
     - At least one VC enters `COMBAT` state.
     - At least one ally enters `COMBAT` state.
     - Average enemy suppression exceeds 0.1 at some point.
   - Prints summary and quits with exit code 0/1.

## Acceptance Criteria

- `ai_stress_arena.tscn` loads and runs without errors.
- Default 18v18 + 2 reserve squads per side sustains an active firefight for **3–5 minutes**.
- Telemetry panel updates every frame and shows honest state counts and reserve status.
- Debug labels render above agents.
- Headless probe passes: at least one enemy and one ally enter COMBAT, suppression activates.
- No regression in `test_squad_body_pool` or `test_model_actor_animations`.

## Risks and Tradeoffs

| Risk | Mitigation |
|------|------------|
| 36+ agents + reinforcements tank performance | Default 18v18; counts exported; enemy AI already has LOD throttle; reserves spawn only as needed. |
| Fight ends in under 3 minutes | Distance + cover density + reserves; tune reserve cooldown/cap after first run. |
| Fight drags past 5 minutes | Hard cap at 5 minutes; report stats regardless of survivors. |
| Duplicating Gore Lab builders | Keep builders tiny and primitive; refactor into shared `ArenaBuilder` only if a second arena follows. |
| Ally AI too shallow to look "soldier-like" | Scope v1 to expose the gap, not solve it. Follow-up task: extend ally goal machine. |
| Navmesh bake slow on 120m arena | Use flat floor + sparse colliders; bake at ready is one-time. |
| Determinism drifts between runs | Note in telemetry; fix global RNG seeding as follow-up if needed. |

## Council Consensus

Build the arena now with the existing AI, tuned for a 3–5 minute sustained firefight through distance, cover, and reserves. Use it to measure and expose behavior. Do not block on perfect squad AI or deterministic RNG. The arena's first job is to answer the spec's final question honestly.
