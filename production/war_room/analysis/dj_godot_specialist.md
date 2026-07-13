# DESTRUCTIBLE_JUNGLE_PLAN — code-claim verification
**Godot Specialist / Lead Programmer · RECONgame War Room**
Verified against working tree, 2026-07-12. Godot 4.7, GDScript strict typing.

Method: every claim read against source. Line numbers below are **current on disk**, not as
quoted in the plan. `gameplay_grid.gd` was edited today (riparian belt + creek roofing);
its cited line numbers nevertheless still land, because the new code was appended at
`:160-161` and in a block below `_estimate_vegetation()`.

---

## VERDICT TABLE

| # | Claim | Verdict | Evidence |
|---|---|---|---|
| 1 | `gameplay_grid.gd:154`/`:580` guard on `has_method("get_density_at")`, which does not exist; `ClearingSystem` exposes `get_vegetation_density()` | **TRUE** (bug real) — but **"one-word fix" is FALSE** | `terrain/core/gameplay_grid.gd:154-155`, `:580-581`; `terrain/systems/clearing_system.gd:266`. See §1 — signature AND semantics both differ. |
| 2 | `mark_cleared()` is called by nothing | **TRUE** | Defined `terrain/core/gameplay_grid.gd:600`. Repo-wide grep for `mark_cleared` returns only that definition + the plan .md. Zero call sites. |
| 3 | `TerrainType.CLEAR` never exists at runtime; `_determine_terrain_type()` is pure elevation/slope and cannot emit it | **TRUE** (with one nuance) | `terrain/core/gameplay_grid.gd:315-346`. Every `return` is WATER/CLIFF/RICE_PADDY/GRASSLAND/LIGHT/MEDIUM/HEAVY_JUNGLE. No `CLEAR`. Nuance: it is not *purely* elevation/slope — it takes `wx, wz` and consults `water_system.is_water()` first (`:317-319`), and rolls `randf()` at `:339`. Neither can emit CLEAR, so the conclusion holds. Only two sites write `TerrainType.CLEAR`: `:586` (inside the dead guard) and `:612` (`mark_cleared`, uncalled). **CLEAR is genuinely unreachable at runtime.** |
| 4 | Nothing in the shipping game has collision on vegetation | **TRUE** | `terrain/vegetation/vegetation_manager.gd:2`, `terrain/vegetation/jungle_patch_layer.gd:18`, `terrain/vegetation/billboard_vegetation.gd:1` all `extends Node3D`; `scripts/world/ground_clutter.gd:29,78` is `Array[MultiMeshInstance3D]`. Grep for `StaticBody3D|CollisionShape3D|collision_layer` across `terrain/vegetation/` returns **zero hits**. |
| 5 | `scripts/levels/gore_lab.gd:203 _add_trunk_collider()` exists as the recipe | **TRUE** | `scripts/levels/gore_lab.gd:203-213`. Exactly as described: `StaticBody3D`, `collision_layer = 1`, `collision_mask = 0`, `CylinderShape3D(r=0.3, h=3.0)`, `add_to_group("nav_source")`. Note it uses group `"nav_source"`, **not** `"nav_blockers"` — plan already calls for adding the latter. |
| 6 | `data/weapons/m79.tres` has `projectile_data_path = ""` → hitscan, no AOE, no crater | **TRUE** | `data/weapons/m79.tres:27` → `projectile_data_path = ""`. Contrast `m72_law.tres:27`, `rpg2.tres:26`, `rpg7.tres:27`, all → `res://data/projectiles/rpg2_rocket.tres`. **Side finding:** `m79.tres` `base_damage = 150`, but ADR-016's value of record for M79 is **44**. Whoever makes the M79 a real projectile must reconcile that with ADR-016 or `tests/test_flat_damage.tscn` will go red. |
| 7 | `CombatManager.apply_explosion_damage()` only walks player/allies/enemies and structurally cannot see world objects | **TRUE** | `scripts/autoload/combat_manager.gd:133` (signature), `:144` player, `:161-170` allies, `:194` enemies. No physics query for world bodies; the only space-state use is `_can_damage_multipoint()` (`:210`) for LOS occlusion. Confirmed: no path by which a `StaticBody3D` receives explosion damage. |
| 8 | `terrain/systems/damage_system.gd` digs the heightmap, clears vegetation, spawns a scar Decal, has `MAX_DEFORMS_PER_MISSION` | **TRUE** (all four) | `MAX_DEFORMS_PER_MISSION: int = 40` at `:68`; crater func `:122`; `terrain_manager.modify_terrain(...)` at `:145` gated by the budget at `:143`; `vegetation_manager.clear_area(...)` `:149-155`; `billboard_vegetation.clear_chunk` + `generate_for_chunk` `:158-169`; `Decal.new()` `:259`. `DamageType` enum `:8-14` = SMALL/MEDIUM/LARGE_EXPLOSION, NAPALM, BUNKER_COLLAPSE. Reuse is correct. |
| 9 | `scripts/world/collision_table.gd` is ~120 entries keyed by model name | **TRUE** | `scripts/world/collision_table.gd:9` — `const STRUCTURES := {}`, keyed by GLB basename, ~125 lines of entries. Schema today: `{box: Vector3, y_offset: float, footprint: Vector2, scale: float}`. It is genuinely the single source of truth and the right place to hang `material`/`hp`/`destroyed`/`debris`. |
| 10 | `site_planner._SOFT_NAME_HINTS` substring-matches GLB filenames, so `vc_hut_bunker.glb` would be shootable through | **MECHANISM TRUE / EXAMPLES FALSE** | `scripts/world/site_planner.gd:98-108`. The substring match is exactly as described and is a real footgun. **But `vc_hut_bunker.glb` and `stack_02.glb` do not exist in this repo** (repo-wide `find` returns nothing). The plan's two showcase examples are fabricated. See §2 for the *real* collisions. |

---

## §1 — CLAIM 1 IS THE ONE THAT CHANGES THE PLAN

The plan calls 0B "THE ONE-WORD BUG… the single highest-value fix in this document" and prescribes:

> **Fix:** `get_density_at` → `get_vegetation_density` (2 sites).

**Do not do this.** It is wrong twice over, and applying it as written would ship a worse game
than the bug does.

### (a) The signature does not match — it would not even run.

```gdscript
# terrain/core/gameplay_grid.gd:155  and  :581
clearing_system.get_density_at(world_x, world_z)      # two floats
```
```gdscript
# terrain/systems/clearing_system.gd:266
func get_vegetation_density(world_pos: Vector3) -> float:   # ONE Vector3
```

A pure rename produces a call with 2 args to a 1-arg function. `clearing_system` is typed
`Node` (`gameplay_grid.gd:71`), so this is a duck-typed call — GDScript will **not** catch it at
parse time. It fails at runtime with *"Too many arguments for 'get_vegetation_density()' call"*,
once per cell, inside a 2-deep loop over the whole grid. The rename must also wrap the args:

```gdscript
clearing_system.get_vegetation_density(Vector3(world_x, 0.0, world_z))
```

### (b) Worse: the semantics are inverted. The naive fix blinds the AI everywhere.

`ClearingSystem._init_vegetation_map()` (`terrain/systems/clearing_system.gd:78-80`):

```gdscript
vegetation_map = Image.create(vegetation_size, vegetation_size, false, Image.FORMAT_RF)
vegetation_map.fill(Color(1.0, 1.0, 1.0, 1.0))  # Full vegetation
```

**The map is 1.0 everywhere by default and is only ever *lowered*, inside a clearing zone.**
It is a *clearing mask*, not an absolute density.

`build_from_terrain()` runs at map-gen, before any zone exists. So a "working" fix at `:155`
sets `vegetation_density[idx] = 1.0` for **every cell on the map**. Consequences:

- `_estimate_vegetation(ttype)` (`:349-356`) — which spreads 0.2 paddy → 0.95 heavy jungle — is
  **bypassed entirely**. Every cell reads 1.0.
- `enemy_base._sight_cap()` lerps `SIGHT_CAP_OPEN 140m → SIGHT_CAP_JUNGLE 45m` on that number.
  At 1.0 everywhere, **every enemy in the game is capped at 45 m, on open ground, in a paddy,
  on a bare hilltop.** That is a far bigger regression than the LZ bug it fixes.
- It also **overwrites the work committed today.** `_apply_riparian_belt()` and
  `_roof_the_creeks()` (`:160-161`) exist precisely to give watercourses a density distinct from
  their surroundings. Set the base to a flat 1.0 and the gallery-forest gradient has nothing to
  be distinct *from* — the creek-as-escape-route mechanic dies the same day it shipped.

`update_region()` (`:580`) has the same defect in miniature: it sweeps a **square** region but a
zone is a **circle**, so the corner cells — outside the zone, still 1.0 in the mask — would be
stamped to density 1.0 and frozen at their current (jungle) terrain type.

### The correct fix

The clearing mask must **modulate** the estimate, not replace it:

```gdscript
# gameplay_grid.gd:153-158
var base: float = _estimate_vegetation(ttype)
if clearing_system and clearing_system.has_method("get_vegetation_density"):
    var mask: float = clearing_system.get_vegetation_density(Vector3(world_x, 0.0, world_z))
    vegetation_density[idx] = base * mask     # mask 1.0 = untouched; 0.05 = cleared
else:
    vegetation_density[idx] = base
```

and the same shape at `:580`, reclassifying terrain type off the *product*. This preserves the
riparian belt, preserves `_estimate_vegetation`'s spread, and makes a stamped LZ read ~0.05·base
≈ 0 — which is the actual goal of 0B.

Two further prerequisites the plan does not mention, both of which must hold or the fix is inert:

1. `ClearingSystem.get_vegetation_density()` returns a hard `1.0` if `terrain_manager` is null
   (`clearing_system.gd:267-268`). Wiring exists — `scripts/levels/game_world.gd:142`
   `set_terrain_manager()` and `:161` `set_clearing_system()` — but **ordering matters**: if the
   grid builds before `set_terrain_manager()` lands, every cell silently gets mask 1.0 and the
   fix does nothing. Assert this ordering.
2. `SitePlanner.stamp_*` does create the zone — `scripts/world/site_planner.gd:84-85`
   (`ClearingSystem.create_zone` + `set_zone_stage(..., CLEARED)`) and then calls
   `_grid.update_region(center, radius)` at `:89`. So the plumbing behind 0B is real and the
   payoff is real. `CLEARED` paints density **0.05**, not 0.0 (`clearing_system.gd:43`), so
   `update_region`'s `if density < 0.1 → CLEAR` threshold (`:585`) does clear it. Good — but note
   that under the *multiply* fix the product is `0.05 * base`, comfortably under 0.1. Still good.

**Net: 0B is still the highest-value fix in the document. It is not a one-word fix, and the
one-word version is a regression. Budget it as a small, careful change with a test, not a typo
correction.**

---

## §2 — CLAIM 10: right footgun, invented ammunition

The mechanism is real: `site_planner.gd:98-108` lowercases the GLB basename and returns
`true` (soft cover) on the first substring hit from
`["hooch","hut","thatch","bamboo","fence","shack","lean_to","leanto","basket","drying","rack","hedge","brush","crate","cart"]`.

But `vc_hut_bunker.glb` and `stack_02.glb` **are not in this repo.** If the plan goes to the
council with those as the motivating examples, the first person to `find` for them will conclude
the whole section is invented. Replace them with the real ones. Actual files whose names trip a
hint today:

| real file | hint hit | should be |
|---|---|---|
| `assets/building models/structures/barracks_bunker.glb` | `rack` (in "bar**rack**s") | **HARD** — it is a bunker |
| `assets/building models/structures/firebase/quonset_hut.glb` | `hut` | **HARD** — corrugated steel |
| `assets/building models/structures/barracks.glb` | `rack` | HARD (timber barracks) |
| `assets/building models/structures/colonial/french_barracks.glb` | `rack` | HARD (colonial masonry) |
| `assets/building models/structures/ruins/burned_hut.glb` | `hut` | debatable — charred posts, per the plan's own Phase 4 rule it should *stop* being soft |
| `assets/building models/structures/ruins/bomb_crater.glb` | `rack`? no — clean | — |
| `assets/building models/structures/village/thatched_hut.glb` | `hut`, `thatch` | SOFT — correct by luck |

**`barracks_bunker.glb` is the headline: a sandbagged bunker that is currently shootable straight
through because the word "barracks" contains "rack".** That is a better example than the invented
one, because it is on disk and can be sent down the penetration lane today. `quonset_hut.glb`
(steel) is the second. The plan's argument survives; only its examples need replacing.

None of these are in `collision_table.gd` under those names, so the `push_warning()` fallback the
plan proposes would fire on them — which is exactly right.

---

## §3 — `vegetation_sway.gdshader` and the INSTANCE_CUSTOM read

**Exists:** `terrain/shaders/vegetation_sway.gdshader` (2482 bytes).
**Reads `COLOR.r` / `COLOR.g`:** **TRUE**, exactly as C2 describes.
- `:35` — `vec3 sway = vec3(wdir.x, 0.0, wdir.y) * (lean * wind_strength * COLOR.r);`
- `:40` — `sway += vec3(wdir.x, -0.5, wdir.y) * (f * flutter_strength * COLOR.g);`

`COLOR.b` is read by nobody in the shader. Confirmed safe to claim.

**C2 is already satisfied on disk.** `tools/make_jungle_flora.py:214` writes
`col.data[i].color = (s, s ** 3.0, b, 1.0)` — the `b` channel is **live**, not a pending change.
And `patches.json` **already has `trees[]`** on 16+ patches and `water` as an **array**. The plan
describes both as "the Blender window is adding this now"; they have landed. Phase 0's premise is
therefore stale in the plan's favour — the contract is real, go verify it in `terrain_lab`.

*(Doc nit: the shader header comment at `:4` credits `tools/make_jungle_vegetation.py` for the
vertex colors; the file that actually writes them for patches is `make_jungle_flora.py`. Both
tools exist. Fix the comment or the next reader chases the wrong file.)*

### What the INSTANCE_CUSTOM read costs

Small — the shader is the easy part. Sketch:

```glsl
uniform float tree_slots = 24.0;

void vertex() {
    // ... existing sway ...

    // COLOR.b == 0 -> grass/fern/bamboo/rice. Never a tree. Leave it alone.
    if (COLOR.b > 0.0) {
        int slot = int(round(COLOR.b * tree_slots)) - 1;      // (slot+1)/24 -> slot
        int mask = int(INSTANCE_CUSTOM.x);                    // exact for < 2^24
        if ((mask >> slot) & 1) {
            VERTEX.y -= 100.0;                                // collapse under terrain
        }
    }
}
```

Four things must be true for that to work, and **three are not true today**:

1. **`mm.use_custom_data = true` + `mm.custom_data_format = MultiMesh.CUSTOM_DATA_FLOAT`.**
   Not set anywhere. `terrain/vegetation/jungle_patch_layer.gd:445-449` and `:467-471` set only
   `transform_format`. Must be added in both bucket builders. This is a real (small) memory cost:
   +16 bytes/instance.
2. **The bit must be flipped on BOTH MultiMeshes.** Each patch is instanced **twice** — a near
   bucket and a far/LOD bucket, `_make_bucket(..., range_begin, range_end)` called at
   `jungle_patch_layer.gd:341` and `:349`. A fell that flips the bit on the near MMI only will
   have the tree **pop back into existence when the player backs off**. The plan never mentions
   the LOD pair; `TreeRegistry` must hold both MMI refs per chunk-patch.
3. **The far/LOD mesh must also carry `COLOR.b`.** If `make_jungle_flora.py` writes the slot
   channel to the near mesh but the decimated `far_tris` mesh loses or averages vertex colors,
   the far LOD's `COLOR.b` will be garbage and the slot recovery will target the wrong tree — or,
   worse, `round()` a smeared value into a valid-looking slot. **Verify the far mesh's vertex
   colors before trusting the bitmask.** This is the single most likely way Phase 2 silently
   half-works.
4. `INSTANCE_CUSTOM` is `vec4(0)` on a plain `MeshInstance3D`. The same shader is used on
   `gore_lab.gd`'s non-MultiMesh palms — mask 0 = nothing dead, so they render normally. Safe.

`round()` not `floor()` on the slot recovery: `COLOR.b` is a float32 through a GLB import and a
vertex interpolator; `(slot+1)/24.0` will not survive as an exact value. `floor()` will
off-by-one at the boundaries.

---

## §4 — smaller corrections, no plan impact

- Plan `:92` says `mark_cleared()` is "the **only** code that writes `TerrainType.CLEAR`".
  Not quite — `update_region()` also writes it (`gameplay_grid.gd:586`). But that write sits
  *inside the dead guard*, so the operative conclusion (CLEAR is unreachable) is unaffected.
- Plan `:99` cites `enemy_base._sight_cap()` at `:626`. The file is at
  `scripts/enemies/enemy_base.gd` (the plan implies `scripts/ai/`). Path only.
- All five AOE call sites in Phase 2 are **confirmed at the cited lines**:
  `scripts/combat/grenade.gd:106`, `scripts/combat/projectile_base.gd:361` (`_apply_aoe_damage`),
  `scripts/combat/claymore.gd:58`, `scripts/vehicles/cas_airplane.gd:140`,
  `scripts/missions/mission_director.gd:381`. Every one is a
  `CombatManager.apply_explosion_damage(...)` call, most already paired with
  `DamageSystem.apply_damage(...)` — so adding a third `TreeRegistry.damage_area(...)` beside them
  is a clean, mechanical edit. The plan's approach here is sound.
- `scripts/world/nav_baker.gd:241` — `for n in get_tree().get_nodes_in_group("nav_blockers"):`,
  and `:248` `body.get_meta("nav_box", Vector3.ZERO)`. **Confirmed exactly as the plan describes.**
  Trunk colliders joining `"nav_blockers"` + `set_meta("nav_box", …)` will carve, no new plumbing.
- `SitePlanner._footprint_valid()` (`:62`) — confirmed it samples center + ring points for
  slope/water only and **never reads vegetation**. Plan's Phase 3.2 is correct.

---

## BOTTOM LINE

9 of 10 claims are true as stated. The codebase is in better shape than the plan assumes in one
place (C2 and `trees[]` have already landed) and in worse shape in another (the LOD pair, the far
mesh's vertex colors).

**The one claim that must be corrected before anyone writes code is Claim 1.** The bug is real and
the payoff is real, but "change one word in two places" would (a) not run, and (b) if made to run,
flatten every vegetation density in the game to 1.0 — capping every enemy's sight at 45 m on open
ground and erasing the riparian-belt work committed today. It is a *modulation*, not a
*replacement*. Fix the plan's §0B before it is executed as written.
