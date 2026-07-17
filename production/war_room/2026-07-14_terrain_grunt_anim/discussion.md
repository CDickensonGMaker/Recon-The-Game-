# Council Discussion — 2026-07-14

## Architects in attendance

- **technical-director** (terrain / engine)
- **level-designer** (terrain / playability)
- **lead-programmer** (characters / spawner)
- **technical-artist** (animation / rigs)
- **devils-advocate** (tradeoffs / scope guard)

## Agreements

### 1. Terrain: do not replace the engine

All architects agree the current engine is canon-aligned. Replacing it with Terrain3D/HTerrain would violate ADR-017 (seed-driven runtime generation), ADR-013 (5×5 chunked AO), TERRAIN_WORKFLOW.md §1–2, and would force a rewrite of live deformation, river hydrology, and vegetation classification.

**technical-director:** the real culprit is `_normalize_heightmap()` stretching every generated map to 100% of its preset `height_scale`, plus ridge/cliff/detail stages that are not relief-budget-aware.

**level-designer:** even with per-preset scales (60–460 m), the normalizer makes a 60 m coastal map use the full 60 m with artificial cliffs and ridges — too much for paddies/villages.

### 2. Terrain fix order

Consensus: tier-1 parameter clamp first, then tier-2 removal/replacement of the normalization ratchet. A verification probe (`test_terrain_relief_bounds`) must lock it in.

| Preset | Current scale | Consensus target | Ridge/cliff |
|---|---|---|---|
| COASTAL_HILLS | 60 m | 25–30 m | disable both |
| RIVER_VALLEY | 80 m | 40–50 m | disable or very mild |
| ROLLING_HILLS | 130 m | 80–100 m | reduce |
| STEEP_MOUNTAINS | 460 m | 250–350 m (measure) | keep dramatic |
| PLATEAU | 220 m | 150–200 m | keep cliff edges |

### 3. Grunt v3: already the fallback, not the squad reality

**lead-programmer:** `AllyBase.sprite_unit = "us_grunt_v3"`, but `SquadSystem.MOS_BODY` immediately overrides every squad member with a role-specific body.

**devils-advocate:** fully random bodies would break MOS readability (RTO radio, MG, grenadier weapon). The player must identify the RTO to understand fire-support gating.

**Consensus:** keep weapons/roles deterministic, but randomize the **rifleman pool** so POINTMAN/RIFLEMAN/MEDIC can appear as `us_grunt_v3` or other M16 bodies. MG/GRENADIER/MARKSMAN/RTO stay weapon-locked.

### 4. Animation manager already exists

**technical-artist + lead-programmer:** `ModelActor` is the character manager. It loads `anim_library.glb`, merges clips, sets loop modes, resolves aliases, and matches locomotion speed. The remaining risk is **export contract** (PSXRig naming, mesh-only exports).

**devils-advocate:** building a new manager would duplicate `ModelActor` and fragment the rig contract.

## Disagreements / tradeoffs

### How far to push "random grunt"

- **lead-programmer:** weapon-pooled randomness in `SquadSystem` only.
- **devils-advocate:** also use `GruntDresser` to add face/helmet/gear variety, but only after the animation probe proves every body works.

Resolution: phase 1 = weapon-pooled bodies. Phase 2 (bead) = `GruntDresser` variety once the probe is green.

### Whether to fix normalization now or only parameters

- **technical-director:** remove/replace normalization for durable fix.
- **level-designer:** parameter clamp is faster and may be enough if the probe passes.

Resolution: do both in one pass — parameter clamp is the immediate fix; replacing the normalizer with explicit amplitude scaling prevents regression.

## What is sacrificed

- **Extreme lowland presets will look flatter.** That is the point: paddies and villages need flat ground.
- **Some visual drama on highland maps** if STEEP_MOUNTAINS is pulled down to 250–350 m. Acceptable for playability.
- **Fully random grunt bodies** are cut; weapon-pooled randomness is the compromise.
- **A new character manager** is cut; export-hygiene work is the real remaining task.
