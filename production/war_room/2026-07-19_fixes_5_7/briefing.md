# War Room — fixes 5–7 (patrol keep-out · crater clamp · dry rivers)

**Date:** 2026-07-19 · **Arbiter:** Overseer · **Scope:** bug fixes only (GATE-exempt under ADR-015;
`RECONgame-qrg6` remains open and untouched).

## Files owned this round
`scripts/missions/mission_generator.gd` · `terrain/core/heightmap_storage.gd` ·
`terrain/water/hydrology_map.gd` · `terrain/water/water_system.gd`.
`scripts/enemies/enemy_base.gd` is READ-ONLY this round.

## Measured baseline (before any edit)

`godot --headless res://tests/test_height_authority.tscn`, seed as authored:

```
[TerrainManager] Extracted 6 river paths
[WaterSystem] Water map: 2447/102400 cells (2.4%)
[D] carved channel vs water surface
  carved channel points: 347
  of those, WaterSystem reports water: 53 (15.3%)
  dry carved-groove examples: (128, 256), (132, 257), (136, 260), (140, 264), (144, 268)
  worst bed-vs-surface gap where both exist: 0.00 m
FAIL: only 15.3% of carved channel is wet
=== FAIL === (9 checks passed, 1 failure(s))
```

## The Arbiter's opening correction to the brief

The brief attributes the 15.3 % to `hydrology_map.gd:506` never writing `_surface_h[i]`.
**That cannot be the cause.** `WaterSystem.is_water()` (`water_system.gd:469-476`) returns
`water_map[i] > 0`, and `_build_water_map_from_hydrology` (`:394-412`) writes
`water_map[i] = t | depth<<3` for **any** `t != 0`. Channel cells are given a type at
`hydrology_map.gd:504`. A cell with a channel type is therefore wet whatever its surface says.

Two further consequences follow, and the second is the load-bearing one:

1. The missing `_surface_h` write is still a **real defect**, but its symptom is different from the
   one claimed: `get_water_level_at` (`water_system.gd:509-519`) returns `0.0` for every creek and
   river cell, and the depth nibble packs to 0. Channels lie about their level, not their existence.
2. **The "water sits on the bed to 0.00 m" evidence in the brief is vacuous.** The test guards that
   comparison with `surf > 0.0` (`test_height_authority.gd:259`) — which skips every channel cell
   *precisely because* the surface is 0. The 0.00 m figure was measured over lakes and swamps only.

So the 15.3 % is a disagreement about **where channels are**, between `RiverGenerator`
(`terrain_manager.gd:345-400`, carves 6 grooves) and `HydrologyMap` (`hydrology_map.gd:431-463`,
classifies channels behind `creek_threshold` 200.0 and `river_max_slope` 0.15). That is the
project's known divergent-systems disease, not a one-line omission.

## Questions put to the council
1. Systems architect — why do the two authorities disagree, and is closing the gap a bug fix or a
   Summoner-level design call?
2. Gameplay programmer — where does the routing keep-out belong so it covers every route, what
   clearance is derivable from an existing constant, and how does it degrade when the pool shrinks?
3. Devil's advocate — attack all three fixes; specifically, does the `_surface_h` write change water
   DEPTH and therefore passability? The Summoner has not ruled on river passability and any movement
   change is forbidden tonight.
