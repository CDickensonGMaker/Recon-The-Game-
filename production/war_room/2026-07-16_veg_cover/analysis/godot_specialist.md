# Godot-Specialist / Technical-Director verdict — veg cover wiring

**(1) Offset trap — subclass override is correct & minimal.** Every reader routes through
`world_to_grid` (gameplay_grid.gd:324): `get_vegetation`:397, `get_terrain_type`:363 (→`get_cover`:385,
`is_water`:419 fallback — arena has no water_system so it DOES fall back), `get_elevation`:346,
`has_line_of_sight`:456. Override `world_to_grid` alone and all of them shift. Use `world_size*0.5`
as the offset, **not** an ARENA constant — `world_size` is already stored (init line 76).
**Gotcha:** do NOT add an `_init` to the subclass. If you do, you MUST `super(world_size, cells)` or
the base's `resize/fill` (81-91) never runs and `get_vegetation` indexes an empty array. Pure
method-override + `ArenaGrid.new(ARENA, cells)` calling the inherited `_init` is clean and safe.

**(2) Mask "inconsistency" is a NON-ISSUE for trunks.** Trunks are layer 1 (arena:639); LOS mask 1,
cover 1|32, bullet 1|32|64 all contain bit 1. The 32/64 bits only add hurtbox layers (6/7),
irrelevant to static vegetation. Nothing to reconcile. Do not fabricate a fix.

**(3) Scaled child collider — fine, and rays stop.** Tree scale is **uniform** `Vector3.ONE*s`
(arena:452, palm 633) — a uniform-scaled CylinderShape3D stays a valid cylinder in Jolt (r0.255–0.375,
h2.55–3.75), and matching visual size is desirable, not distortion. A ray tests the target body's
**layer**, not the body's mask — so layer-1 `mask=0` StaticBody (640) is hit by the bullet ray
(1|32|64) AND the LOS ray (1). `mask=0` is correct for an inert obstacle. Bodies + default
`collide_with_bodies=true` → both rays block.

**(4) Perf — a few hundred static bodies is trivial for a lab.** Jolt eats thousands of static
bodies. The 16k-tree main-map problem (bead eaqv) is body-count + navmesh bake at scale; do NOT drag
that optimization into the lab.

**Also required for the wiring to take:** enemy fetch (enemy_base.gd:290-292) needs the arena
(a) in group `game_world` and (b) exposing a `gameplay_grid` var — grep shows the arena has **neither**
today. Add both or `_grid` stays null and `_sight_cap` returns `SIGHT_CAP_OPEN` (602-609) forever.

**ONE risk/sacrifice:** overriding `world_to_grid` but leaving `grid_to_world` (332),
`build_from_terrain`, `update_region`, `mark_cleared` at 0-origin creates a half-consistent grid — a
silent wrong-origin trap the moment anyone calls those on ArenaGrid. Fossil-law smell. Mitigate:
either also override `grid_to_world`, or comment ArenaGrid as read-only-veg for the lab.
