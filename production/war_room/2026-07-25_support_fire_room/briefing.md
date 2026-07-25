# War Room Briefing — THE SUPPORT FIRE TEST ROOM (design + plan + audit)

**Convened:** 2026-07-25 · Arbiter: recon-overseer · Summoner: Caleb (dropped as a queued DESIGN+PLAN
request). **Deliverable = SPEC + PHASED PLAN + AUDIT. Do NOT blind-build the big destruction systems.**
Planning gate. No headless suite, no windowed Godot, nothing pushed, ADRs stay PROPOSED.

## What Caleb asked for
A controlled test scene — PLAYER + an RTO worker — with access to EVERY fire-support type, to verify
(a) explosions/fire-support effects work, and (b) they DESTROY trees, terrain, buildings. If destructible
trees/buildings/terrain don't exist, this room is where we add them. Like the AI arena, but a
destruction/fire-support benchmark.

## AUDIT — the Arbiter's grounded starting picture (VERIFY it, cite file:line, don't trust this)
`production/DESTRUCTIBLE_JUNGLE_PLAN.md` is a detailed prior audit+plan — its banner says "re-verify before
building." Confirmed so far:
- **Fire-support roster is BUILT** (`scripts/missions/field_director.gd`): `fire_support` dict =
  bombs (Snake Eye, A-1 Skyraider dive) · napalm (F-4 flyby) · arty (105mm, 6-round sheaf) · mortar
  (81mm, spot+sheaf) · spectre (AC-47/gunship — `SpectreGunship`, and `ac47_spooky.glb` is the model,
  UNCOMMITTED) · cbu (cluster, F-4). Player-carried: M79 HE, M72 LAW, M26 frag, claymore, satchel, smoke,
  illum flare. Enemy: RPG-2/RPG-7. Aim-and-press call grammar (`arm_fire_mission`/`commit_fire_mission`).
- **Terrain craters are BUILT — REUSE, DO NOT BUILD:** `terrain/systems/damage_system.gd` (autoload
  `DamageSystem`) digs the heightmap + spawns scar Decals, `DamageType` = SMALL/MEDIUM/LARGE_EXPLOSION,
  NAPALM, BUNKER_COLLAPSE, `MAX_DEFORMS_PER_MISSION = 40`. Also `terrain/systems/engineering_system.gd`
  (9 shaping ops, dev-lab only).
- **Tree cover/colliders BUILT:** `terrain/vegetation/tree_cover_layer.gd` (near-solid MultiMesh + trunk
  collider per cover instance, far-card LOD; `COVER_TRUNK` includes felled_tree/felled_trunk/tree_stump).
  Its own comment: MECHANISM, "do NOT wire live without eyes on the new look" — may not be live yet.
- **Fall assets EXIST:** `assets/world/vegetation/{felled_tree,felled_trunk,tree_stump}.glb`.
- **Building destruction ART EXISTS** (per DESTRUCTIBLE_JUNGLE_PLAN §Phase 4): intact in
  `structures/village/`, destroyed in `structures/ruins/` (burned_hut, ruin_house_half/shell,
  destroyed_bunker, wall_remnant, rubble_*, bomb_crater). `scripts/world/collision_table.gd` (~120 entries,
  keyed by model name) is the material/HP data home. `scripts/vehicles/destructible_vehicle.gd` = closest
  prior art (NOTE: no HP, no take_damage — must be told to die).
- **NOT BUILT (designed only):** `scripts/world/destructible.gd`, `terrain/vegetation/tree_registry.gd`,
  `scripts/world/falling_tree.gd` — the tree-fell bitmask registry, the fall, and the building state-machine.
- **THE EXPLOSION→WORLD-OBJECT GAP:** `CombatManager.apply_explosion_damage()` walks only player/allies/
  enemies arrays — it STRUCTURALLY CANNOT see world objects. Destruction must be routed by a `damage_area()`
  call added at every explosion site (grenade, projectile_base AOE, claymore, cas_airplane, field_director
  arty/mortar). VERIFY current line numbers.
- **KNOWN BUGS:** `data/weapons/m79.tres` `projectile_data_path=""` → M79 fires hitscan, no AOE/crater (the
  primary player tree-feller). `collision_table` material-by-filename-substring footgun (`_SOFT_NAME_HINTS`)
  → a "hut"-named bunker is shootable through. UNCOMMITTED: `ac47_spooky.*`, `scripts/world/mg_emplacement.gd`.

## Binding constraints
ADR-026 PS2 budget / Forward+ (perf is the top systemic risk; deep-night 18v18 ~19-23fps, BOTH-bound) ·
ADR-001 PSX low-poly · ADR-023 fossil law (fold `DestructibleVehicle` into the general `Destructible`;
retire the filename footgun; TreeCoverLayer retires the merged-patch/billboard paths on switchover) ·
ADR-010 determinism (crater/fell must be deterministic) · world-foundation-locked (improve the one world,
don't fork it) · Pillar 1 (believable firefights), 2 (atmosphere), 3 (freedom — "build cover by felling a
tree across open ground" is a named new verb).

## Your charge (lens below). Deliverable is DESIGN, not built destruction code.
Read the CODE + `DESTRUCTIBLE_JUNGLE_PLAN.md` for your lens, load your Godot skill folder (destruction /
particles-vfx / godot-optimization / hud-system as relevant), write full analysis to `analysis/<role>.md`
(cite file:line), return ONLY a ≤180-word verdict naming what is sacrificed.
