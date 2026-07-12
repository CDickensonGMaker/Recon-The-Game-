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

### Amendment (2026-07-12): non-combatants may declare their own height
1.7132 is the **combatant** standard and every soldier on the roster still obeys
it. It cannot be universal: the normalizer rescales *every* skeleton to its
target, so under one global number a child is not a child — he is a 1.71 m adult
wearing a child's mesh, and a stooped elder stands up straight. A village of
grunt-sized "kids" is the failure this prevents.

A unit that is not a soldier declares its authored height in
`ModelActor.UNIT_HEIGHT_M`; anything absent from that table falls back to 1.7132,
so adding a model never silently changes its scale.

| Unit | Height | Source |
|---|---|---|
| every combatant (US, VC, NVA, aircrew) | 1.7132 | helmet top — aircrew's flight helmet is the top of the silhouette, same as a steel pot |
| `civ_farmer_m` | 1.62 | 1960s–70s rural Vietnamese adult male |
| `civ_farmer_f` | 1.52 | adult female |
| `civ_elder` | 1.55 | with a stoop |
| `civ_kid` | 1.26 | ~9 years old |

**Author each civilian AT its declared height**, same rule as before — matching
the target means zero rescale, and the hitzones land where authored.

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
