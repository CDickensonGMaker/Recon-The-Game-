# RECONgame SCALE STANDARD — the numbers every model must match

**1 Blender unit = 1 meter. Always.** Everything below is in meters.

## THE number
| Thing | Value | Why it's canon |
|---|---|---|
| **Character height (top of helmet)** | **1.7132 m** | `ModelActor.TARGET_HEIGHT_M` (model_actor.gd:16) — matches the sprite manifests |
| Player eye height | 1.70 | Head node in player.tscn |

The engine auto-normalizes any character to 1.7132 (it rescales by AABB), so a
1.9m export won't *break* — but exporting AT 1.7132 means zero rescale and the
hitzones/eye-lines land exactly where authored. **Author to 1.7132.**

## Character export contract (unchanged)
Feet at world origin (0,0,0) · face **−Z** · 1.7132 tall · Mixamo rig, named
animations · sockets `MuzzlePoint / HandR / HandL / Head / Chest` · ~3–6k tris.

## Hitzone bands (where the body parts must sit on a 1.7132 model)
| Zone | Center height | Shape |
|---|---|---|
| HEAD | 1.65 | sphere r 0.15 |
| CHEST | 1.30 | capsule r 0.30, h 0.35 |
| GUT | 0.90 | capsule r 0.28, h 0.30 |
| ARMS | 1.00 | at ±0.35 x |
| LEGS | 0.40 | at ±0.12 x |

Keep the head centered ~1.60–1.70 and the waistline ~0.9 and locational damage
"just works" on any humanoid.

## Reference sizes (sanity checks for props)
- Rifle (M16 class): ~0.99 long · SOG Bowie: ~0.29 · Claymore on legs: ~0.19 tall
- Doorway clearance: ≥ 2.0 high × 0.9 wide (player capsule is ~1.8 × 0.8)
- Huey fuselage: ~13–17 long · gibs: real severed-part scale (arm ~0.6, head ~0.25)

## Gib set contract (`assets/models/gore/`)
`gib_arm.glb / gib_leg.glb / gib_head.glb / gib_chunk_1..3.glb` — origin at each
piece's center of mass, real scale per above, ~100–300 tris, shared gore texture.
