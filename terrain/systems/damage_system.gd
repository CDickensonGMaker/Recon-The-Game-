extends Node
## Damage System - Physical terrain deformation from explosions, bombardment, etc.
## Creates craters, scarring, and persistent damage markers using Decals


enum DamageType {
	SMALL_EXPLOSION,    # Grenade, mortar - small crater
	MEDIUM_EXPLOSION,   # Artillery shell - medium crater
	LARGE_EXPLOSION,    # Bomb, large artillery - big crater
	NAPALM,             # Burns + slight depression
	BUNKER_COLLAPSE,    # Localized depression
}

## Depths/rims are METERS, divided by the live height_scale at apply time
## (Summoner-approved retune 2026-07-18; the old normalized values multiplied
## by height_scale 350 and dug 5-21m craters - grenade canyons). Real-world
## anchors: grenade/mortar scrape 0.3-1m, 105mm shell 1-2m, 750lb bomb ~9m
## deep x 14m wide. mission_generator._crater_keepout_grow derives from
## LARGE radius_cells - the safety envelope tracks this table automatically.
const DAMAGE_PROFILES: Dictionary = {
	DamageType.SMALL_EXPLOSION: {
		"radius_cells": 2,
		"depth_m": 0.6,
		"rim_m": 0.09,
		"falloff_power": 2.0,
		"scar_color": Color(0.2, 0.15, 0.1),
		"scar_type": "crater",
	},
	DamageType.MEDIUM_EXPLOSION: {
		"radius_cells": 3,
		"depth_m": 2.0,
		"rim_m": 0.3,
		"falloff_power": 1.8,
		"scar_color": Color(0.25, 0.18, 0.1),
		"scar_type": "crater",
	},
	DamageType.LARGE_EXPLOSION: {
		"radius_cells": 5,
		"depth_m": 8.0,
		"rim_m": 1.2,
		"falloff_power": 1.5,
		"scar_color": Color(0.3, 0.2, 0.12),
		"scar_type": "crater",
	},
	DamageType.NAPALM: {
		"radius_cells": 15,
		"depth_m": 0.3,
		"rim_m": 0.0,
		"falloff_power": 3.0,
		"scar_color": Color(0.05, 0.03, 0.02),  # Charred black
		"scar_type": "burn",
	},
	DamageType.BUNKER_COLLAPSE: {
		"radius_cells": 4,
		"depth_m": 1.5,
		"rim_m": 0.25,
		"falloff_power": 2.5,
		"scar_color": Color(0.4, 0.32, 0.22),
		"scar_type": "crater",
	},
}

var damage_zones: Array[Dictionary] = []
var scar_decals: Array[Decal] = []

## Aggregate per-mission ceiling on terrain deforms (the shipped cap is per-strike; this
## bounds chunk-rebuild spikes under sustained ordnance). Reset in clear_all_damage().
const MAX_DEFORMS_PER_MISSION: int = 40
var _deforms_this_mission: int = 0

# Reference to terrain manager (set by terrain_lab)
var terrain_manager: Node
var vegetation_manager: Node

var decal_container: Node3D

# Scar textures (procedurally generated)
var crater_scar_texture: ImageTexture
var burn_scar_texture: ImageTexture

const SCAR_TEXTURE_SIZE: int = 128


func _ready() -> void:
	decal_container = Node3D.new()
	decal_container.name = "ScarDecals"
	add_child(decal_container)
	_create_scar_textures()


func set_terrain_manager(manager: Node) -> void:
	terrain_manager = manager


func set_vegetation_manager(veg_manager: Node) -> void:
	vegetation_manager = veg_manager


func apply_damage(world_pos: Vector3, type: DamageType, intensity: float = 1.0) -> void:
	if not terrain_manager:
		push_warning("DamageSystem: TerrainManager not set - call set_terrain_manager()")
		return

	var profile: Dictionary = DAMAGE_PROFILES[type]
	var radius: int = maxi(1, int(profile.radius_cells * intensity))
	# Lab stubs (ai_stress_arena) carry no heightmap to ask.
	var height_scale: float = TerrainConfig.WORLD_HEIGHT_MAX
	var hm: Variant = terrain_manager.get("heightmap")
	if hm != null:
		height_scale = float(hm.height_scale)
	var depth: float = (profile.depth_m * intensity) / height_scale
	var rim_height: float = (profile.rim_m * intensity) / height_scale
	var falloff_power: float = profile.falloff_power

	var crater_func := func(current_height: float, falloff_amount: float) -> float:
		# Smooth crater profile: continuous depression + rim curves (no hard boundaries)
		# falloff_amount: 1.0 at center, 0.0 at edge

		# Depression curve: peaks at center, fades toward edges
		var depression: float = depth * smoothstep(0.3, 0.95, falloff_amount) * pow(falloff_amount, falloff_power * 0.5)

		# Rim curve: ring around crater, fades at both inner and outer edges
		# Uses inverted falloff (rim_dist) for intuitive positioning
		var rim_dist: float = 1.0 - falloff_amount
		var rim_factor: float = smoothstep(0.5, 0.75, rim_dist) * smoothstep(1.0, 0.85, rim_dist)
		var rim: float = rim_height * rim_factor

		return clampf(current_height - depression + rim, 0.0, 1.0)

	var cell_size: float = terrain_manager.cell_size
	var radius_meters: float = radius * cell_size

	# Apply to terrain manager's heightmap (this also rebuilds affected chunks). Past the
	# per-mission ceiling, skip the expensive dig but keep the cheap veg-clear + scar below.
	if _deforms_this_mission < MAX_DEFORMS_PER_MISSION:
		_deforms_this_mission += 1
		terrain_manager.modify_terrain(world_pos, radius_meters, crater_func)

	# Clear vegetation in damaged area. Pass heightmap so clear_area re-materializes
	# the surviving (non-cleared) bundles; otherwise the MultiMesh stays wiped.
	if vegetation_manager and vegetation_manager.has_method("clear_area"):
		vegetation_manager.clear_area(
			world_pos,
			radius_meters,
			terrain_manager.chunk_size,
			terrain_manager.heightmap,
		)

	var terrain_height: float = terrain_manager.get_height_at(world_pos)

	damage_zones.append({
		"position": world_pos,
		"type": type,
		"radius": radius_meters,
		"intensity": intensity,
		"time": Time.get_ticks_msec(),
	})

	_create_scar_decal(
		Vector3(world_pos.x, terrain_height, world_pos.z),
		radius_meters,
		profile.scar_color,
		profile.scar_type,
		intensity
	)



func _create_scar_textures() -> void:
	# Create crater scar texture (circular with darker center, brown rim)
	var crater_img := Image.create(SCAR_TEXTURE_SIZE, SCAR_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(SCAR_TEXTURE_SIZE / 2.0, SCAR_TEXTURE_SIZE / 2.0)
	var max_dist: float = SCAR_TEXTURE_SIZE / 2.0

	for y in range(SCAR_TEXTURE_SIZE):
		for x in range(SCAR_TEXTURE_SIZE):
			var pos := Vector2(x, y)
			var dist: float = pos.distance_to(center) / max_dist

			if dist > 1.0:
				crater_img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				var edge_falloff: float = smoothstep(0.7, 1.0, dist)
				var center_darkness: float = 1.0 - dist * 0.5

				var noise_val: float = sin(x * 0.3) * cos(y * 0.3) * 0.1

				var r: float = clampf(0.15 + dist * 0.15 + noise_val, 0.0, 1.0)
				var g: float = clampf(0.1 + dist * 0.1 + noise_val * 0.5, 0.0, 1.0)
				var b: float = clampf(0.05 + dist * 0.05, 0.0, 1.0)
				var a: float = (1.0 - edge_falloff) * center_darkness

				crater_img.set_pixel(x, y, Color(r, g, b, a))

	crater_scar_texture = ImageTexture.create_from_image(crater_img)

	# Create burn scar texture (charred black with irregular edges)
	var burn_img := Image.create(SCAR_TEXTURE_SIZE, SCAR_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)

	for y in range(SCAR_TEXTURE_SIZE):
		for x in range(SCAR_TEXTURE_SIZE):
			var pos := Vector2(x, y)
			var dist: float = pos.distance_to(center) / max_dist

			if dist > 1.0:
				burn_img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				var edge_falloff: float = smoothstep(0.6, 1.0, dist)

				var noise1: float = sin(x * 0.5 + y * 0.3) * 0.15
				var noise2: float = cos(x * 0.2 - y * 0.4) * 0.1
				var noise_combined: float = noise1 + noise2

				var r: float = clampf(0.03 + noise_combined * 0.02, 0.0, 0.1)
				var g: float = clampf(0.02 + noise_combined * 0.01, 0.0, 0.08)
				var b: float = clampf(0.01, 0.0, 0.05)
				var a: float = (1.0 - edge_falloff) * 0.9

				burn_img.set_pixel(x, y, Color(r, g, b, a))

	burn_scar_texture = ImageTexture.create_from_image(burn_img)


func _create_scar_decal(position: Vector3, radius: float, color: Color, scar_type: String, intensity: float) -> void:
	var decal := Decal.new()
	decal.name = "ScarDecal_%d" % scar_decals.size()

	decal.position = position + Vector3(0, 1, 0)

	# Size based on damage radius (decal size is half-extents, so multiply by 2)
	var decal_size: float = radius * 2.2 * intensity  # Slightly larger than crater
	decal.size = Vector3(decal_size, 10.0, decal_size)  # 10m height to project onto terrain

	if scar_type == "burn":
		decal.texture_albedo = burn_scar_texture
	else:
		decal.texture_albedo = crater_scar_texture

	decal.albedo_mix = 0.85 * intensity  # How much to blend with terrain
	decal.modulate = color  # Tint the texture
	decal.cull_mask = 1  # Only affect terrain layer
	decal.upper_fade = 0.1
	decal.lower_fade = 0.3

	decal.rotation.y = randf() * TAU

	decal_container.add_child(decal)
	scar_decals.append(decal)


## Clear all damage (for testing reset)
func clear_all_damage() -> void:
	damage_zones.clear()
	_deforms_this_mission = 0  # fresh crater budget each mission

	for decal in scar_decals:
		if is_instance_valid(decal):
			decal.queue_free()
	scar_decals.clear()
