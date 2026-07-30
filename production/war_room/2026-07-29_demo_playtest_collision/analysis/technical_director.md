# TECHNICAL DIRECTOR — the two grounds are measured, not suspected

## Finding T1: the firebase has two ground colliders at different heights

**The terrain floor.** `scripts/world/site_planner.gd:667-681` (`place_firebase_main`) does a
two-tier terrain stamp: the outer ring is levelled to `seat_y`, and the interior is raised to
`seat_y + FSB_MOUND_TOP`. `FSB_MOUND_TOP = 2.87` (site_planner.gd:659), and its comment says
where the number came from — the `fb_gate_gap` MARKER's y in the v3 GLB.

**The model floor.** The GLB carries its own full-compound ground plate, `fb_terrain_mound`
(`tools/gen_firebase_v3.py:201`), and that object is on the trimesh collision list
(gen_firebase_v3.py:779), so Godot imports it as a `-colonly` trimesh StaticBody covering the
entire base.

**They do not agree.** The plate's surface is `platform_z` (gen_firebase_v3.py:78-95):

```
top = MOUND_H + 1.05*sin(...)*cos(...) + 0.55*sin(...) + 0.30*cos(...)
MOUND_H = 3.4                                    # gen_firebase_v3.py:28
```

So the model's collision floor rolls between **~1.5 m and ~5.3 m**, mean 3.4 m. The terrain
floor is a flat **2.87 m**. Over most of the compound the model plate stands **0.5–2.4 m
above the visible terrain**, and in the dips it sinks below it.

This single fact explains three of the Summoner's six complaints:

- **"Two layers of collision"** — literally two. Terrain heightmap collider + GLB trimesh plate.
- **"Jump up and float on top of the firebase… invisible wall"** — he jumped, landed on the
  plate, and stood on a surface with nothing rendered under it. The plate's rim is the wall.
- **"Alignment issues with the main firebase mound"** — every structure is authored seated on
  `platform_z`. Where `platform_z < 2.87` the raised terrain swallows the building's feet.

The 2.87 constant was picked to solve a REAL and correctly-diagnosed problem (the 07-29
comment in place_firebase_main: the player was pinned at an unwalkable 3 m dirt wall and
could not enter the base from any bearing). The remedy was right in kind and wrong in value:
it matched the terrain to a MARKER instead of to the mound SURFACE FUNCTION.

## Finding T2: the mound face is not the only steep thing

`nav.agent_max_slope = 50.0` (nav_baker.gd) but a `CharacterBody3D`'s own floor limit is what
gates walking. The authored outer slope is `MOUND_H / MOUND_FALL = 3.4 / 34.0` ≈ **5.7°** —
perfectly walkable. The pin the 07-29 comment describes was NOT the authored skirt; it was
the discontinuity where the flat terrain plateau meets the plate's edge. Reproducing
`platform_z` in the terrain removes the discontinuity and keeps the gentle authored ramp.

## Recommendation

**One ground.** Make the terrain reproduce the model's own mound surface, and delete the
model's ground-plate collider (ADR-023: the replaced system is deleted, not left dark).

- Terrain: evaluate `platform_z` in GDScript inside the `modify_terrain` callback, using the
  Blender→Godot axis map (Blender +Y = Godot −Z, per the vehicle facing convention).
- Model: `fb_terrain_mound` moves from `COL_TRIMESH` to `COL_NONE` in gen_firebase_v3.py.
  Interim, without a re-export: strip its collider at runtime in `place_firebase_main`, the
  same pattern already used for the huey's duplicate fuselage.

**Named tradeoff.** The authored craters (`crater_delta`) are a ±1.2 m detail on a 4 m
heightmap. Under one-ground they become visual dishes you walk over rather than step into.
That is a cheap price for deleting a floating invisible floor across the whole compound.
