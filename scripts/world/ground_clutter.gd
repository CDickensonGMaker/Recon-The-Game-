## ground_clutter.gd - Resident near-ground cover: grass tufts, rocks, fallen logs, bushes.
## Scattered ONCE across the AO behind the loading screen and bucketed per sub-cell, each
## bucket carrying a visibility_range so only the near ring ever draws (ADR-013 resident
## world; ADR-010 deterministic from mission_seed).
##
## EVERY LAYER IS A REAL 3D MESH (Summoner, 2026-09-08: "no more 2d terrain cards, or 3d
## plane spliced cards or whatever. all 3d blender models only in game" - sharpened the
## next day to "no swamp logs, no bushes that arent 3d models etc"). Seven of the eight
## layers here used to be `QuadMesh` billboards with CULL_DISABLED and the eighth rode the
## 6-triangle `grass_fan.glb` star-fan. A flat picture of a rock inside a 42 m draw radius
## is the worst offender in the game and it is gone. ADR-001 Amendment A is the law;
## barbwire is the single exemption and it does not live here.
##
## NO QUAD MAY COME BACK AS AN OPTIMISATION. If a distance cannot afford these meshes the
## answer is a lower-poly real MESH.
class_name GroundClutter
extends Node3D

## Sub-cell edge, metres. visibility_range culls a whole bucket by its CENTRE, so this dials
## LOD granularity against node count. NEAR_END is the bucket draw radius (the near ring the
## player sees), tuned to the old moving-ring reach so the near look is unchanged.
const SUBCELL: float = 32.0
const NEAR_END: float = 42.0
const NEAR_FADE: float = 8.0

## Per-sub-cell instance counts are the LAYERS ring-counts scaled by area from the old 45m
## ring, so resident density matches what the moving ring used to show at any instant.
const RING_AREA: float = 6361.73  # PI * 45 * 45

const SWAY_SHADER_PATH := "res://terrain/shaders/vegetation_sway.gdshader"

const VEG_DIR := "res://assets/world/vegetation/"
const ROCK_DIR := "res://assets/world/rocks/"

## SWAY IS GATED ON PAINTED VERTEX COLOURS, and that is not decoration. The shader masks
## displacement by COLOR.r (lean) and COLOR.g (flutter). A mesh with no COLOR_0 attribute
## reads white, i.e. mask 1.0 everywhere INCLUDING the base, so the whole plant would slide
## off its roots. Every mesh listed with sway=true below was verified to carry COLOR_0.
## The orphaned lp_* set does NOT carry it - do not add one here without checking.
##
## mesh path, ring-count, y_sink (m), jungle-only, sway
const LAYERS := [
	[VEG_DIR + "grass_tuft_c.glb", 160, 0.05, false, true],
	[VEG_DIR + "grass_tuft_a.glb", 90, 0.05, false, true],
	[VEG_DIR + "grass_tuft_b.glb", 70, 0.05, false, true],
	[VEG_DIR + "bush_a.glb", 18, 0.02, true, true],
	[VEG_DIR + "bush_c.glb", 12, 0.02, true, true],
	[ROCK_DIR + "rock_small_a.glb", 8, 0.04, false, false],
	[ROCK_DIR + "rock_small_b.glb", 7, 0.04, false, false],
	[ROCK_DIR + "rock_cluster_a.glb", 4, 0.05, false, false],
	[ROCK_DIR + "rock_half_buried_a.glb", 3, 0.12, false, false],
	[VEG_DIR + "tree_stump.glb", 10, 0.06, true, false],
]

## THE "SWAMP LOG" IS NOT FIXED, AND THIS IS THE HONEST STATE OF IT.
## The obvious replacement for the old `swamp_fallen` billboard was `fallen_log_a/b.glb`.
## MEASURED 2026-09-08 (GLB geometry audit): those two are themselves flat. fallen_log_a
## is 184 tris but only 12 distinct face normals, with 90.9% of its triangle area facing
## near-vertically and 69% on ONE downward sheet; fallen_log_b is worse at 97.1% horizontal
## area and a 4:1 flat mid-span cross-section. They are ribbons lying on the ground, not
## cylinders. Swapping a log card for a log ribbon is not the ruling.
## The only genuinely volumetric deadwood in the project is `felled_trunk.glb` (8.37 m long)
## and `felled_tree.glb` (a whole 9.3 m tree) - both far too large for ground clutter - and
## `tree_stump.glb` (1.75 m, 21 normals, real volume), which is what this layer now draws.
## OWED ART: a correctly-scaled ~2-3 m volumetric fallen log. Until it exists this layer is
## stumps, not logs. Note fallen_log_a/b are ALSO planted by TreeCoverLayer as COVER_TRUNK
## cover-givers with a 0.45 m collider - flat geometry the player is invited to hide behind.

## OWED ART, named rather than left as a quad: the old `mushroom` (12/ring) and
## `blue_flower` (14/ring) layers had NO 3D model anywhere in the project. They are not
## substituted with something else and they are not left as billboards - they are simply
## not drawn until a real mesh exists. `terrain/textures/clutter/` still holds their
## textures plus the retired grassland_*/rock/herb_bush/swamp_fallen sheets.

var world: GameWorld
var _templates: Array = []
## subcell -> Array[MultiMeshInstance3D] (one per layer that produced instances)
var _buckets: Dictionary = {}
## subcell -> PackedVector3Array of placed WORLD-space origins (probe truth: the
## Y each instance actually received; MultiMesh read-back is blind headless)
var placed_origins: Dictionary = {}
var _dirty_subcells: Dictionary = {}
var _flush_pending: bool = false


## Shared PSX wind material: sway masked by vertex color (R lean / G flutter), scissor +
## cull off + nearest. gore_lab.gd and ai_stress_arena.gd call this - keep the signature.
static func make_sway_material(tex: Texture2D, wind_strength: float = 0.35,
		flutter_strength: float = 0.06, alpha_scissor: float = 0.4) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(SWAY_SHADER_PATH)
	if tex != null:
		mat.set_shader_parameter("albedo_tex", tex)
	mat.set_shader_parameter("wind_strength", wind_strength)
	mat.set_shader_parameter("flutter_strength", flutter_strength)
	mat.set_shader_parameter("alpha_scissor", alpha_scissor)
	return mat


## First MeshInstance3D mesh inside a GLB scene (null if missing/empty). Reused by callers.
static func load_glb_mesh(path: String, as_foliage: bool = true) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var inst: Node = packed.instantiate()
	var mesh: Mesh = null
	var stack: Array[Node] = [inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var mi := n as MeshInstance3D
		if mi != null and mi.mesh != null:
			mesh = mi.mesh
			break
		for c in n.get_children():
			stack.push_back(c)
	inst.free()
	return MaterialBudget.foliage(mesh) if as_foliage else MaterialBudget.solid(mesh)


## The GLB's own albedo, so a sway material keeps the mesh's authored texture instead of
## an unrelated clutter sheet. Null is survivable - make_sway_material skips the uniform.
static func _albedo_of(mesh: Mesh) -> Texture2D:
	if mesh == null or mesh.get_surface_count() == 0:
		return null
	var m := mesh.surface_get_material(0) as BaseMaterial3D
	return m.albedo_texture if m != null else null


func setup(game_world: GameWorld) -> void:
	world = game_world

	# One shared mesh (+ optional sway material) per layer; every bucket reuses them.
	for layer: Array in LAYERS:
		var path: String = String(layer[0])
		var sway: bool = bool(layer[4])
		var mesh: Mesh = load_glb_mesh(path, sway)
		if mesh == null:
			push_warning("[CLUTTER] %s missing - that layer draws nothing. It is NOT "
				% path + "falling back to a billboard.")
			continue
		var override_mat: Material = null
		if sway:
			override_mat = make_sway_material(_albedo_of(mesh), 0.18, 0.05)
		var per_cell: int = int(ceil(float(int(layer[1])) * (SUBCELL * SUBCELL) / RING_AREA))
		_templates.append({
			"mesh": mesh, "override": override_mat,
			"y_sink": float(layer[2]), "jungle_only": bool(layer[3]), "per_cell": per_cell,
		})

	var subcells: int = int(ceil(world.map_size / SUBCELL))
	for sz in range(subcells):
		for sx in range(subcells):
			_scatter_subcell(Vector2i(sx, sz))
	world.terrain_manager.region_rebuilt.connect(_on_region_rebuilt)


## Deterministic per-subcell scatter (ADR-010: hash([subcell, layer, seed])).
## RNG draws are UNCONDITIONAL per candidate so a flipped accept (crater cleared
## a veg cell) never shifts the stream - untouched plants keep their transforms.
func _scatter_subcell(sc: Vector2i) -> void:
	_clear_subcell(sc)
	var origin_x: float = sc.x * SUBCELL
	var origin_z: float = sc.y * SUBCELL
	var centre := Vector3(origin_x + SUBCELL * 0.5, 0.0, origin_z + SUBCELL * 0.5)
	centre.y = world.terrain_manager.get_height_at(centre)
	var nodes: Array = []
	var origins := PackedVector3Array()
	for li in range(_templates.size()):
		var t: Dictionary = _templates[li]
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([sc, li, world.mission_seed])
		var xforms: Array[Transform3D] = []
		for _i in range(int(t.per_cell)):
			var pos := Vector3(origin_x + rng.randf() * SUBCELL, 0.0, origin_z + rng.randf() * SUBCELL)
			var ang: float = rng.randf_range(0.0, TAU)
			var plant_scale: float = rng.randf_range(0.75, 1.3)
			if not _accept(pos, bool(t.jungle_only)):
				continue
			# Real meshes are authored at world scale with their origin at the feet,
			# so they seat on the ground directly - no half-height nudge, which only
			# existed to centre a quad on its own face.
			var plant_basis := Basis(Vector3.UP, ang).scaled(Vector3.ONE * plant_scale)
			pos.y = world.terrain_manager.get_height_at(pos) - float(t.y_sink)
			origins.append(pos)
			xforms.append(Transform3D(plant_basis, pos - centre))
		if not xforms.is_empty():
			nodes.append(_add_bucket(t, xforms, centre))
	if not nodes.is_empty():
		_buckets[sc] = nodes
		placed_origins[sc] = origins


func _clear_subcell(sc: Vector2i) -> void:
	if _buckets.has(sc):
		for n in _buckets[sc]:
			if is_instance_valid(n):
				(n as Node).queue_free()
		_buckets.erase(sc)
	placed_origins.erase(sc)


## Coalesced deferred re-seat: build stamps fire 12-18 modify_terrain calls in one
## synchronous stretch (6 on the same fsb subcells), and clear_and_flatten updates
## the gameplay grid AFTER modify_terrain - so re-scattering synchronously would
## both waste work and read stale water/veg state in _accept. One flush, next frame.
func _on_region_rebuilt(world_rect: Rect2) -> void:
	var min_sc := Vector2i(int(floor(world_rect.position.x / SUBCELL)),
		int(floor(world_rect.position.y / SUBCELL)))
	var max_sc := Vector2i(int(floor(world_rect.end.x / SUBCELL)),
		int(floor(world_rect.end.y / SUBCELL)))
	for sz in range(min_sc.y, max_sc.y + 1):
		for sx in range(min_sc.x, max_sc.x + 1):
			_dirty_subcells[Vector2i(sx, sz)] = true
	if not _flush_pending:
		_flush_pending = true
		_flush_dirty.call_deferred()


func _flush_dirty() -> void:
	_flush_pending = false
	var dirty: Array = _dirty_subcells.keys()
	_dirty_subcells.clear()
	var subcells: int = int(ceil(world.map_size / SUBCELL))
	StallLedger.begin("clutter.flush")
	for sc: Vector2i in dirty:
		if sc.x < 0 or sc.y < 0 or sc.x >= subcells or sc.y >= subcells:
			continue
		_scatter_subcell(sc)
	StallLedger.end()


## Water is never clutter; jungle-only layers need real jungle density (matches the old ring).
func _accept(pos: Vector3, jungle_only: bool) -> bool:
	if world.gameplay_grid == null:
		return true
	if world.gameplay_grid.is_water(pos):
		return false
	if jungle_only and world.gameplay_grid.get_vegetation(pos) < 0.3:
		return false
	return true


func _add_bucket(t: Dictionary, xforms: Array[Transform3D], centre: Vector3) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = t.mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if t.override != null:
		mmi.material_override = t.override
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.position = centre
	mmi.visibility_range_end = NEAR_END
	mmi.visibility_range_end_margin = NEAR_FADE
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mmi)
	return mmi
