# DESTRUCTIBLE JUNGLE — plan for the CODE window

> **KEEP — Summoner's ruling, 2026-07-19.** Destructible terrain stays on the roadmap; this plan is
> live, not history. **But its diagnosis has partly aged out — re-verify before you build from it:**
>
> - ⛔ **FALSE NOW:** "`update_region()` … **runs its body never**" (§ below). `update_region` is
>   `terrain/core/gameplay_grid.gd:453` and is now **three lines that delegate to `rebuild_rect`**. The
>   `get_density_at` guard it described is gone. Do not plan around a no-op.
> - ⛔ **FALSE NOW:** the callers named as `SitePlanner.stamp_firebase()` / `stamp_outpost()` **do not
>   exist**. Real stamps: `scripts/world/site_planner.gd:208 stamp_village`, `:582 stamp_vc_camp`,
>   `:598 stamp_lz`.
> - ⛔ **STALE LINE NUMBER:** `mark_cleared()` is cited below as `:600`; it is
>   `terrain/core/gameplay_grid.gd:458`.
> - ✅ **STILL TRUE, and this is the residue worth keeping:** `mark_cleared()` has **zero callers
>   repo-wide** (grep over `scripts/ terrain/ tests/ tools/`, 2026-07-19 — the only other hit is a
>   comment in `tools/probe_riparian.gd:166`). The one function that writes `TerrainType.CLEAR` and
>   `vegetation_density = 0.0` is still called by nothing.
> - **Unverified this pass, do not treat as fact:** the downstream "every LZ is a lie" conclusion about
>   `enemy_base._sight_cap()` depended on the now-false no-op claim. Re-measure it before acting.

> **Two windows are working in parallel.**
> The **Blender window** owns `tools/make_jungle_*.py`, the GLB exports, and `patches.json`.
> **This window owns all GDScript.**
> They meet at three contracts (§0). Read those first — two of them have already changed on disk.

---

## §0 — THE CONTRACT

### C1. `assets/models/vegetation/patches/patches.json`

Produced by the Blender window. Consumed by `terrain/vegetation/jungle_patch_layer.gd`.

```jsonc
{
  "tile_m": 12.0,
  "patches": [{
    "name": "patch_canopy",
    "density": "medium",
    "tris": 12260, "far_tris": 5455,

    // *** BREAKING CHANGE, ALREADY ON DISK ***
    // Was a single Dictionary. Is now an ARRAY - patch_paddy_quad is
    // cross-bunded into FOUR pans, each its own sheet of water.
    "water": [ { "level": 0.055, "half": [5.8, 5.8], "at": [0.0, 0.0] } ],

    // *** NEW - the Blender window is adding this now ***
    "trees": [ { "at": [x, y], "r": 0.20, "h": 9.4, "slot": 0 } ]
  }]
}
```

- `water[].half` is `[hx, hy]` — **rectangular**. `patch_paddy_edge` is only wet on one side of the
  tile, so forcing it square shrank a 12 m paddy to a 4.8 m puddle.
- `trees[]` = **`broadleaf_tree` only** (bole radius 0.20 m = 40 cm across — a tree you can hide
  behind). **Never** bamboo (`r=0.03`) or `palm_sapling` (`r=0.045`). Those are not cover and must
  not get colliders — see Phase 1.
- `slot` is `0..23`, unique within a patch. Max trees in any patch today is **5**.

### C2. `COLOR.b` carries the tree slot

`tools/make_jungle_flora.py` writes `col.data[i].color = (s, s**3.0, 0.0, 1.0)`.
`.r` = sway mask (0 at roots → 1 at tips), `.g` = flutter mask. **Do not touch those** —
`vegetation_sway.gdshader` depends on them. `.b` is `0.0` today and read by nobody.

- **`COLOR.b == 0.0` → NOT a tree.** Grass, ferns, bamboo, rice, lianas. The shader must ignore them.
- **`COLOR.b == (slot + 1) / 24.0` → belongs to tree `slot`.** (+1 so slot 0 isn't 0.0.)

### C3. New GLBs arriving from the Blender window

- `assets/models/vegetation/felled_tree.glb` — the full standing broadleaf as a **standalone** mesh
  (today it only exists stamped inside patch meshes). The transient object that plays the fall.
- `assets/models/vegetation/felled_trunk.glb` — the settled state: bole + crushed canopy, cheap.
- `assets/models/vegetation/tree_stump.glb` — what's left in the ground.

---

## PHASE 0 — Verify, and fix a silent breakage. **Nothing else is trustworthy until this passes.**

### 0A. `jungle_patch_layer.gd` has been edited and NEVER RUN.

The Blender window made these changes and could not execute them:
- paddy **water spawning** — reads `water[]` per C1, builds one `ArrayMesh` of all pans per patch,
  renders with `terrain/water/water_swamp.gdshader`, one extra MultiMesh per chunk;
- paddy **height terracing** (`paddy_terrace_step`);
- paddy **edge-tile placement** (`_paddy_open_side()`, `INTERIOR_PADDIES`, `EDGE_PATCH`).

Run `terrain/scenes/terrain_lab.tscn`, generate a paddy region, confirm:
- pans render as **water** (ripples/muck) — not a black quad, not nothing;
- the `water` key parses as an **array** (it was a Dictionary until today — old parse code WILL break);
- bunds meet across tile seams with no gap;
- **no `paddy_edge` treeline standing in the middle of open water.**

### 0B. THE ONE-WORD BUG — the single highest-value fix in this document.

`terrain/core/gameplay_grid.gd:154` and `:580` both guard on:

```gdscript
if clearing_system and clearing_system.has_method("get_density_at"):
```

**`get_density_at` does not exist.** `ClearingSystem` exposes **`get_vegetation_density()`**
(`terrain/systems/clearing_system.gd:266`). `get_density_at` appears nowhere in the codebase.

The guard is therefore **always false**, which means:

1. `update_region()` — the function called after **every** `SitePlanner.stamp_lz()` /
   `stamp_firebase()` / `stamp_outpost()` — **runs its body never.** It emits `grid_updated` and
   changes nothing.
2. `mark_cleared()` (`:600`) — the **only** code that writes `TerrainType.CLEAR` and
   `vegetation_density = 0.0` — **is called by nothing.**
3. `build_from_terrain()` always falls through to `_estimate_vegetation(ttype)`, so density is a pure
   function of terrain type, which is a pure function of elevation + slope.

**Consequence: every LZ in the game is a lie.** `stamp_lz()` flattens the ground and deletes the
plants, so it *looks* like a clearing — but the gameplay grid still reports the **pre-clear jungle
density** there. `enemy_base._sight_cap()` (`:626`) reads that number and lerps
`SIGHT_CAP_OPEN 140m → SIGHT_CAP_JUNGLE 45m`. **The AI cannot see the clearing.** The player stands
in a bald 16 m disc and enemies behave as though he's under triple canopy.

Also: **`TerrainType.CLEAR` never exists at runtime anywhere on the map** —
`_determine_terrain_type()` (`:315`) is pure elevation/slope bands and cannot emit it.

**Fix:** `get_density_at` → `get_vegetation_density` (2 sites).
**Prove it:** stand in a stamped LZ; assert `gameplay_grid.get_vegetation(pos) ≈ 0.0` and
`enemy_base._sight_cap()` returns ~140, not ~45. **Keep this as a regression test.**

### 0C. Calibration — no code, but worth more than any flag.

Stand inside `patch_tangle`, look 45 m, see if a man-sized target is genuinely obscured. The AI is
*told* it can only see 45 m in heavy jungle. If the art doesn't back that up, the game lies to the
player — he thinks he's hidden and gets shot through a bush.

---

## PHASE 1 — Trunk colliders ("cover that lies")

**Nothing in the shipping game has collision on vegetation.** `VegetationManager`,
`JunglePatchLayer`, `BillboardVegetation` and `GroundClutter` are **all** pure
`MultiMeshInstance3D` with zero collision. You currently walk and shoot straight through every tree.
The tree you dive behind mid-chase does not stop a bullet.

- Read `trees[]` from `patches.json` (C1).
- Per chunk, spawn **one `StaticBody3D`** with a `CylinderShape3D` **child per tree instance** (many
  shapes on one body is far cheaper than many bodies). `collision_layer = 1` (world),
  `collision_mask = 0`.
- Transform each tree's local `(x, y)` by its tile's `Transform3D` — it inherits the tile's 90° yaw.
- **The recipe is already written and unused outside the lab:**
  `scripts/levels/gore_lab.gd:203 _add_trunk_collider()` — `StaticBody3D`, layer 1,
  `CylinderShape3D`, group `"nav_source"`.
- Group `"nav_blockers"` + `set_meta("nav_box", Vector3)` so `scripts/world/nav_baker.gd:241` carves
  the navmesh around trunks.

**Trunks are HARD cover — explicitly NOT in `"soft_cover"`.** The penetration probe measured soft
cover at ×0.79 / ×0.61 per layer with `soft_left = 2` (three layers of thatch stop the round). A
40 cm bole is not thatch; it stops the round outright. Put trunks in `"hard_surface"` for the spark
impact FX and nothing else.

**Bamboo gets no collider at all** — and that is the correct ballistics *for free*. Rounds pass
straight through, which is what bamboo does. Its concealment already lives in `vegetation_density`,
not in geometry. Same for palm saplings.

Layer 1 needs **no new plumbing**: `BulletSystem` aim rays mask `1`; grenade `RigidBody3D` masks `1`;
`ProjectileData.hits_world` ORs in `1`; and `CombatManager._can_damage_multipoint()` (`:210`)
raycasts against mask `1`. So a trunk instantly stops bullets, stops grenades, **and shadows blast.**

---

## PHASE 2 — Destructible trees

**The blocker:** a tree is not an object. Every patch bakes to **one merged mesh**, instanced ~40×
per chunk via MultiMesh. The tree you want to fell is a few hundred triangles welded into a
20,000-triangle tile. Destroy the geometry and you destroy **every copy in the chunk**.

**The way through: don't touch geometry.**

- `mm.use_custom_data = true`; per-instance `Color` whose `.r` carries a **bitmask of that
  instance's dead trees**. (A float32 represents a 24-bit integer exactly; max 5 trees per patch, so
  there's room to spare.)
- `terrain/shaders/vegetation_sway.gdshader`: read `INSTANCE_CUSTOM.x`, recover this vertex's slot
  from `COLOR.b` (C2), and **collapse the vertex** (sink it under the terrain) if its bit is set.
  **Guard on `COLOR.b > 0.0`** so grass, ferns, bamboo and rice are untouched.
- **Destroying a tree = flipping one bit on one instance.** Zero mesh surgery, zero extra draw calls,
  and a tree felled in one tile does **not** vanish from the other 40 copies of that tile.

New `terrain/vegetation/tree_registry.gd`:
- per chunk: `instance_idx + slot → { hp, world_pos, radius, collider_shape_idx }`
- entry point **`damage_area(world_pos, radius, damage)`**
- on death: flip the bit → `set_instance_custom_data()`; disable that trunk's `CollisionShape3D`;
  hand off to the fall (Phase 2b); and **drop `gameplay_grid.vegetation_density` locally** → once a
  radius is clear, call **`mark_cleared()`** (alive at last thanks to 0B). **This is what makes a
  player-made LZ real.**

**Wire the explosion path.** `CombatManager.apply_explosion_damage()` (`:133`) only walks its three
registered entity arrays (player / allies / enemies) and **structurally cannot see world objects**.
Rather than bend it, call `TreeRegistry.damage_area()` alongside the existing pair at every site:
- `scripts/combat/grenade.gd:106`
- `scripts/combat/projectile_base.gd:361` (`_apply_aoe_damage` — LAW / RPG-2 / RPG-7)
- `scripts/combat/claymore.gd:58`
- `scripts/vehicles/cas_airplane.gd:140` (bombs / napalm / CBU)
- `scripts/missions/mission_director.gd:381` (arty / mortars)

**Bug found en route:** `data/weapons/m79.tres` has `projectile_data_path = ""`, so the player's
**M79 currently fires a single hitscan bullet with no AOE and no crater** (150 dmg via
`BulletSystem`). The ally grenadier fakes it (`scripts/squad/squad_system.gd:265`). The M79 is the
**primary tree-felling tool the player carries** — it must become a real projectile.

---

## PHASE 2b — The fall, and the log it leaves

The bitmask can only ever **hide** a tree. It cannot animate anything and cannot leave anything
behind. So the fall is a separate object — and it should be. Same shape as the gib system: **the
moment of death is expensive and brief; what it leaves is cheap and permanent.**

| stage | what it is | cost |
|---|---|---|
| standing | baked in the patch MultiMesh | free — already there |
| **falling** | ONE transient `Node3D` with `felled_tree.glb`, ~2 s, then freed | one object, briefly |
| **fallen** | an instance in a shared **fallen-log MultiMesh** + capsule collider | one draw call for **all** of them |

New `scripts/world/falling_tree.gd`:
- **Scripted hinge, NOT RigidBody physics.** A real tree on a rigidbody is unpredictable and will
  eventually launch one into the sky. Rotate about the base with a gravity-like ease-in over
  1.5–2.5 s. Fully controllable, reads identically.
- **Fall direction = away from the blast.** The RPG that killed it decides which way it goes — so the
  player can *aim* it.
- **A falling tree kills.** Sweep its arc on impact and call
  `CombatManager.apply_explosion_damage()`. Standing under one you dropped should be fatal — and
  dropping one on an enemy position becomes a legitimate play.
- Impact: crash SFX, screen shake, dust burst, leaf scatter. **Reuse `scripts/combat/gib_system.gd`'s
  debris spawner** — do not write a second one.

**The log is permanent, and that is the point.**
- **HARD cover** (not `"soft_cover"`), prone height (~0.6 m) — you get down behind it.
- Capsule collider on layer 1; group `"nav_blockers"` + `nav_box` meta so `NavBaker` re-carves.
- **Cover for the AI too**, via the existing cover system — enemies will use what you made.
- **Do not time it out.** Cover that evaporates while the player is lying behind it is infuriating
  and unreadable; a 20-second log is a promise the game breaks. Permanent means the player can
  **build cover** — drop a tree across open ground and there's now a log to crawl behind that wasn't
  there before. **That is a new verb, and it's most of the reason to build this.**
- Cap ~96 per mission and recycle the oldest, purely as a safety valve. The settled state is a
  MultiMesh instance + one capsule, so 96 of them is a rounding error.

---

## PHASE 3 — LZ (blow your own)

**Already built and wired — do not rebuild:**
- `scripts/vehicles/helicopter.gd` — full state machine (`IDLE/FLYING/LANDING/LANDED/TAKING_OFF/
  CRASHING/DESTROYED`), `fly_to()`, `take_off()`, `shoot_down()`, terrain-following cruise at 30 m.
- `scripts/vehicles/landing_zone.gd` — `COLD/WARM/HOT`, `lz_radius = 15.0`, threat polled every 2 s.
- `scripts/missions/insertion_ride.gd` — board → fly → AA rolls → touchdown → dismount.
- `scripts/missions/objectives/exfil_zone.gd` — calls the bird from the map edge, rolls LZ-compromise
  (35% shoot-down if hot within 160 m), waves off to `fallback_pos`.

What's missing is **honesty**, and 0B supplies most of it.

1. After 0B, `mark_cleared()` works — so `stamp_lz()` finally writes `TerrainType.CLEAR` +
   density 0.0, and **existing LZs become real to the AI.**
2. `SitePlanner._footprint_valid()` (`:62`) **never reads vegetation** — a "valid site" today means
   only *flat and dry*. Add a vegetation/type check so the planner can **discover** genuine clearings
   instead of manufacturing them by fiat.
3. **Player-made LZ:** `LZFinder.can_land(pos, radius) -> bool`, reading the **live** grid density +
   `TreeRegistry`. Because Phase 2 fells trees and drops density, **blowing down the canopy genuinely
   creates a landable LZ.** Expose it to `ExfilZone` so the player can call the bird into a hole he
   made himself. **That is the mechanic.**

No `lz: true` flag is needed in `patches.json`. The grid drives it, and
`JunglePatchLayer.TYPE_DENSITY` has no `T_CLEAR` entry, so CLEAR ground already renders bare.

---

## PHASE 4 — Destructible buildings

Not a destruction engine. **BFBC2 was not procedural either** — Frostbite used **authored,
pre-fractured parts with hit points and a support graph.** The magic was in the authoring, not the
simulation. Same thing here — and **the art already exists**:

| intact (`assets/building models/structures/village/`) | destroyed (`…/structures/ruins/`) |
|---|---|
| `thatched_hut`, `stilt_house` | `burned_hut` |
| `three_room_house`, `communal_house` | `ruin_house_half`, `ruin_house_shell` |
| `bunker`, `barracks_bunker` | `destroyed_bunker` |
| walls | `wall_remnant`, `wall_corner_tall`, `wall_u_ruin` |
| — | `rubble_pile`, `brick_pile`, `rubble_heap_tall`, `rubble_debris_large/small`, `bomb_crater` |

### FIRST, KILL THE FILENAME FOOTGUN

Today a structure's ballistics are decided by `site_planner._SOFT_NAME_HINTS` doing **substring
matching on the GLB filename** (`hooch/hut/thatch/bamboo/fence/shack/lean_to/basket/drying/rack/
hedge/brush/crate/cart` → soft cover). Which means:

- **`vc_hut_bunker.glb` — a bunker — is shootable straight through**, because it contains "hut".
- **`stack_02.glb` — a haystack — is bulletproof**, because it contains nothing.

That is not a naming convention, it's a landmine — and Phase 4 is about to spawn a hundred models
onto it. Material properties must be **authored data**, not a guess about what somebody typed when
they saved the file.

Extend **`scripts/world/collision_table.gd`** — already ~120 entries, already keyed by model name,
already the single source of truth for structure collision:

```gdscript
"thatched_hut": { box: …, y_offset: …,         # existing
                  material: "thatch",           # NEW -> "soft_cover" group
                  hp: 40,                       # NEW -> one grenade
                  destroyed: "burned_hut",      # NEW
                  debris: ["rubble_scatter_tiny", "brick_pile"] }
```

`_SOFT_NAME_HINTS` demotes to a **fallback that `push_warning()`s** for any model not yet in the
table — so a gap is **loud** instead of silently bulletproof.

Keep the doctrine the penetration probe verified: soft = ×0.8 per layer, `soft_left = 2` (measured
×0.79 / ×0.61, third layer stops the round).

### The component

New `scripts/world/destructible.gd` — `class_name Destructible extends StaticBody3D`:
- `hp`, `take_damage(amount, source)`, `destroy()`
- on death: swap the mesh, scatter 2–4 `rubble_*` props, swap the collider, **reassign the cover
  group** (a `burned_hut` is charred posts and rubble — it is **no longer soft cover**; the swap must
  change the group, not just the mesh), mark nav dirty, and call
  `DamageSystem.apply_damage(pos, MEDIUM_EXPLOSION)` for the crater + scar.
- **HP by material, and a thatch hut should be pitiful:** hut ≈ one grenade; wall ≈ a few; bunker
  needs a LAW / satchel / direct M79. **A hooch that *survives* a grenade is what breaks immersion.**

Reuse:
- `scripts/world/site_planner.gd:112 place_structure()` — the spawn path; make it emit `Destructible`.
- `scripts/vehicles/destructible_vehicle.gd` — closest prior art, but note it has **no HP and no
  `take_damage`**; it must be *told* to die. `Destructible` should be the general version and
  `DestructibleVehicle` should eventually fold into it.
- Route damage through the same `damage_area()` call added in Phase 2 (physics query for group
  `"destructible"`), since `CombatManager` structurally cannot see world objects.

**Support graph is explicitly deferred** — it only earns its keep on multi-storey structures. We have
huts and bunkers.

### CRATERS: DO NOT BUILD

`terrain/systems/damage_system.gd` (autoload `DamageSystem`) **already** digs the heightmap
(`modify_terrain` + crater func), clears vegetation (`VegetationManager.clear_area`), regenerates
billboards, and spawns a scar `Decal` — with `DamageType` profiles for
`SMALL/MEDIUM/LARGE_EXPLOSION, NAPALM, BUNKER_COLLAPSE` and a `MAX_DEFORMS_PER_MISSION = 40` budget.
**Reuse it.** Also note `terrain/systems/engineering_system.gd` exists (9 operations: clear jungle,
flatten, dig trench, berm, foxhole, crater blast, det-cord…) and is **only** wired into the dev lab —
rich prior art if you need terrain shaping.

---

## VERIFICATION

- **0** — paddy field generates: swamp-shader water, bunds meeting across seams, no treeline in open
  water. Then stand in a stamped LZ: `get_vegetation() ≈ 0`, `_sight_cap() ≈ 140` (not 45). **Keep as
  a regression test.**
- **1** — stand behind a tree, get shot at, don't get hit. Grenade behind a trunk: the trunk shadows
  the blast. Navmesh carves around trunks.
- **2** — M79 a tree: it dies **in this tile only**; the same tile type elsewhere in the chunk is
  untouched. *That is the test the bitmask exists to pass.* Standing-tree draw-call count unchanged.
- **2b** — it falls **away from the blast**, lands with weight, and kills what's under it. The log is
  hard cover you can go prone behind, and it's still there ten minutes later.
  **Then the real test: drop a tree across open ground and use it to cross a field you couldn't cross
  before. If that isn't fun, the whole feature is decoration.**
- **3** — blow a canopy hole with RPG/M79, call exfil, the bird lands **in the hole you made**.
- **4** — one grenade turns `thatched_hut` into `burned_hut` + rubble; a bunker shrugs it off and
  needs a LAW. Then send **`vc_hut_bunker.glb` down the penetration row — it must now STOP the
  round.** That's the lane that proves material came off the filename.
- The penetration probe's own lesson, which applies to every test added here: **a green test that
  proves nothing is worse than a red one.** Its first run used `CombatManager.bullet_system` (it's
  `.bullets`), so no round ever fired — and two checks went green, because "the cover stopped it" is
  trivially true when the gun isn't firing. **Every new lane needs a control that fails loudly if the
  gun isn't firing.**
