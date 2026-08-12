# WAR ROOM BRIEFING — THE WATER DOES NOT RENDER

**Convened:** 2026-08-12
**Summoner's report:** *"theres cuts in the ground for the water to be there but than no water appears"* and *"or if it is its not following the natural flow that gets cut in the terrain"*

This is the Summoner's EYE GATE verdict on the 2026-08-12 water rewrite. It is a FAIL.

## THE MEASUREMENT (probe: `tools/probe_water_seat.tscn`, seed 47225, 106 channels, 4308 ribbon verts)

```
CONTRACT     carve 1.20 - water 0.55 = drop 0.65
intended     water sits 0.55m above bed, 0.65m below grade
ACTUAL       water sits 0.252m above bed  (min 0.050, max 0.550)
ACTUAL       water sits 3.669m below grade
CLAMPED      2250 / 4308 verts (52.2%) hit the bed+0.05 floor
```

Sampled rows from the biggest channel (237 points):

| i | width | bed | bank_l | bank_r | grade | y |
|---|---|---|---|---|---|---|
| 76 | 33.33 | 157.72 | 164.51 | 160.25 | 166.05 | 158.27 |
| 57 | 27.17 | 163.46 | **159.82** | 163.15 | 166.52 | 163.51 |
| 171 | 40.00 | 141.42 | **136.62** | 143.64 | 148.53 | 141.47 |

Note the bolded banks: **`bank_l` reads BELOW the bed** — up to 5m below.

## THE ARBITER'S PRELIMINARY DIAGNOSIS (challenge it — do not assume it)

Three coupled defects, first causing the other two:

1. **The carve is relative, not level.** `terrain/core/terrain_manager.gd:434` does
   `heightmap.set_cell(nx, nz, maxf(0.0, current - depth_normalized))` — it SUBTRACTS 1.2m
   from existing terrain. It preserves all local relief. Channels reach 40m wide over terrain
   with ~6m of relief across that span, so the "flat floor for the sheet to sit in" that the
   8/12 rewrite intended DOES NOT EXIST.

2. **Therefore the bank samples are garbage.** `terrain/water/water_system.gd:337-340` samples
   `bank_l`/`bank_r` at ±half_w. On a 40m channel that is ±20m, landing on arbitrary hillside —
   sometimes BELOW the bed. `y = minf(bed + 0.55, minf(bank_l, bank_r) - 0.1)` then drives the
   surface underground, and `maxf(y, bed + 0.05)` catches it on 52% of verts.

3. **The ribbon is buried in its own banks.** The sheet is only half_w wide, so its edge verts
   sit where terrain is often metres HIGHER than the water surface. Terrain occludes the sliver.
   Surface height also jumps vertex-to-vertex between bed+0.55 and bed+0.05 depending on which
   way the clamp fired — a jagged sheet, not a flowing plane.

## WHAT IS ALREADY KNOWN (2026-08-12 terrain session, verified)

- The shader rewrite (`terrain/water/water_static.gdshader`) is COMMITTED and probably fine.
  SPECULAR 0.5, ROUGHNESS 0.12-0.28, ripple normals written to `NORMAL` (never `NORMAL_MAP` —
  the mesh has NO `ARRAY_TANGENT`), fresnel, shore foam, per-channel flow from `COLOR.b`.
  **We may have been fixing the paint on a boat that was not in the water.**
- `hydrology_map.gd:519` now writes `_surface_h[i]` (was the "wade gate never fired" bug).
- `min_lake_depth = INF` (`hydrology_map.gd:45`) — pooling is OFF. All 106 water bodies are
  channels. No pond, no lake, no deep water anywhere.
- `get_water_depth()` returns 0.5m everywhere (quantised `int(depth*2.0)` at
  `water_system.gd:422`). `WADE_DEPTH_M = 1.2` (`gameplay_grid.gd:154`) can never fire.
- The water mesh is built ONCE and never rebuilt, but terrain is not: `site_planner`'s flatten
  raises ground AFTER. This is the likely origin of the `generate_swamps = false` scar.
- **DO NOT restore hydrology pooling.** It eats paddies -> villages -> breaches
  `HARD_FLOOR_VILLAGES = 4`, submerges units (`get_height_at` has no water term), and dilates
  the 22m gallery-forest belt which silently collapses AI sight range.

## YOUR CHARGE

Read the CODE, not this briefing. Three times in one day here the codebase has beaten the document.

Answer, with `file:line` for every assertion (POINTER LAW):

1. **Is the diagnosis right?** Which of the three defects is real, which is not, and what did the
   Arbiter miss? If the true root cause is elsewhere, say so plainly.
2. **What is the minimum change that makes water visible and channel-following?** Name the exact
   edits. Prefer the smallest correct fix over the most elegant one.
3. **What does changing the carve break?** The heightmap feeds village siting, nav baking,
   `HARD_FLOOR_VILLAGES`, the 22m gallery belt, and unit ground-clamping. Name every downstream
   consumer you can find with a pointer, and say which ones a level cut would disturb.
4. **Should the water plane be wider than the channel?** i.e. should the ribbon extend to where
   the water surface actually intersects the carved banks, rather than stopping at ±half_w?
5. **Sequencing:** water mesh is built once; terrain is mutated later by site flattening. Does the
   fix need a rebuild hook, or an ordering change?

## THE LAWS THAT BIND YOU

- **POINTER LAW** — an assertion with no `file:line` is an opinion. Cite or date it.
- **FOSSIL LAW (ADR-023)** — if you replace a system, the predecessor is DELETED in the same change.
- **COMMENT DISCIPLINE** — no narration, no tombstones, no history in source.
- **NAME WHAT IS SACRIFICED** — no free lunches. Every recommendation states its cost.
- **Pillar 2 is ATMOSPHERE.** Water in a Vietnam jungle sim is not decoration.
- Godot 4.7 stable, GDScript, strict typing (`minf`/`maxf`/`lerpf`, never `min`/`max`/`lerp`).

## OUTPUT

Write your FULL analysis to `production/war_room/2026-08-12_water_seating/analysis/<your_role>.md`.
Return to the Arbiter ONLY a short verdict — under 400 words. The Arbiter's context must survive.
