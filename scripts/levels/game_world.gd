## game_world.gd - Generated AO gameplay scene: terrain + water + vegetation +
## gameplay grid + player + HUD. Mission systems attach on top of this.
class_name GameWorld
extends Node3D


const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const TerrainManagerScript := preload("res://terrain/core/terrain_manager.gd")
const TerrainChunkScript := preload("res://terrain/core/terrain_chunk.gd")
const VegetationManagerScript := preload("res://terrain/vegetation/vegetation_manager.gd")
const WaterSystemScript := preload("res://terrain/water/water_system.gd")
const GameplayGridScript := preload("res://terrain/core/gameplay_grid.gd")

@export var mission_seed: int = 12345
@export var map_size: float = WorldConfig.MAP_SIZE
@export var spawn_position_override: Vector3 = Vector3.ZERO  ## zero = AO center
@export var spawn_player_on_ready: bool = true

var terrain_manager: TerrainManager
var vegetation_manager: VegetationManager
var water_system: WaterSystem
var gameplay_grid: GameplayGrid
var player: CharacterBody3D
var hud: HUD
var is_world_ready: bool = false

## Coalesced terrain-edit rect (meters). Craters arrive in bursts; one flush per frame.
var _dirty_terrain_rect: Rect2 = Rect2()
var _terrain_flush_queued: bool = false

## Safety net: re-seat the player if they end up under the terrain surface.
const RESEAT_DEPTH: float = 5.0
var _reseat_timer: float = 0.0


func _ready() -> void:
	add_to_group("game_world")
	_setup_environment()
	_setup_terrain()


func _setup_environment() -> void:
	var light := DirectionalLight3D.new()
	light.name = "SunLight"
	light.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	# Perf-first (Intel UHD class hardware): no dynamic shadows for now.
	light.shadow_enabled = false
	add_child(light)

	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.35, 0.46, 0.6)
	sky_material.sky_horizon_color = Color(0.7, 0.72, 0.65)
	sky_material.ground_bottom_color = Color(0.2, 0.22, 0.16)
	sky_material.ground_horizon_color = Color(0.65, 0.67, 0.6)

	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	# Short-draw jungle haze (ADR-026 A.2). Density stays UNDER the fairness floor:
	# an open-ground enemy at the 140m AI sight cap (enemy_base.SIGHT_CAP_OPEN) is
	# still a visible hazy silhouette at this density, so the fog never hides a
	# shootable target. MissionWeather reassigns fog_density/fog_light_color per
	# weather; it never touches the aerial/sky/scatter terms, so those survive.
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.78, 0.7)
	env.fog_density = 0.0065
	env.fog_aerial_perspective = 1.0
	env.fog_sky_affect = 0.5
	env.fog_sun_scatter = 0.1

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)


func _setup_terrain() -> void:
	terrain_manager = TerrainManagerScript.new()
	terrain_manager.name = "TerrainManager"
	terrain_manager.map_size = map_size
	terrain_manager.chunk_size = WorldConfig.CHUNK_SIZE
	terrain_manager.cell_size = WorldConfig.CELL_SIZE
	terrain_manager.load_distance = WorldConfig.LOAD_DISTANCE
	terrain_manager.unload_distance = WorldConfig.UNLOAD_DISTANCE
	add_child(terrain_manager)

	vegetation_manager = VegetationManagerScript.new()
	vegetation_manager.name = "VegetationManager"
	vegetation_manager.mission_seed = mission_seed
	vegetation_manager.canopy_source = (VegetationManagerScript.CanopySource.TREE_COVER
		if WorldConfig.USE_TREE_COVER else VegetationManagerScript.CanopySource.JUNGLE_PATCH)
	add_child(vegetation_manager)

	water_system = WaterSystemScript.new()
	water_system.name = "WaterSystem"
	add_child(water_system)

	terrain_manager.terrain_ready.connect(_on_terrain_ready)

	_setup_default_shader_textures()

	# Wire vegetation to terrain BEFORE generation (rice-paddy vertex coloring
	# happens during mesh build; water-proximity checks need the back-reference).
	terrain_manager.vegetation_manager = vegetation_manager
	vegetation_manager._terrain_manager = terrain_manager

	await terrain_manager.generate_terrain(mission_seed)


## Neutral shader textures MUST be bound before generation, or unbound samplers
## render the terrain white.
func _setup_default_shader_textures() -> void:
	var default_clear := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	default_clear.fill(Color(0, 0, 0, 0))
	var clear_tex := ImageTexture.create_from_image(default_clear)

	TerrainChunkScript._create_shared_material()
	TerrainChunkScript.set_shader_parameters({
		"clearing_texture": clear_tex,
		"terrain_size": 385,
		"cell_size": 4.0,
		"height_scale": TerrainConfig.WORLD_HEIGHT_MAX,
	})


func _on_terrain_ready() -> void:
	# 1. Damage + clearing systems (autoloads) get their terrain references.
	DamageSystem.set_terrain_manager(terrain_manager)
	DamageSystem.set_vegetation_manager(vegetation_manager)
	ClearingSystem.set_terrain_manager(terrain_manager)
	if ClearingSystem.has_signal("vegetation_updated"):
		ClearingSystem.vegetation_updated.connect(_on_vegetation_updated)

	# 2. Real shader textures now that the heightmap exists.
	_setup_terrain_shader_textures()

	# 3. Water BEFORE gameplay grid (grid needs accurate water cells).
	water_system.initialize(terrain_manager.heightmap)
	water_system.ocean_edges = WorldConfig.OCEAN_EDGES
	water_system.sea_level = WorldConfig.SEA_LEVEL
	water_system.generate_water_bodies(terrain_manager.hydrology)
	var wetness_tex: ImageTexture = water_system.generate_wetness_texture(16.0)
	if wetness_tex:
		TerrainChunkScript.set_shader_texture("wetness_texture", wetness_tex)

	# 4. Gameplay grid (site planning, spawn queries, LOS).
	gameplay_grid = GameplayGridScript.new(terrain_manager.map_size, 256)
	gameplay_grid.mission_seed = mission_seed
	gameplay_grid.set_heightmap(terrain_manager.heightmap)
	gameplay_grid.set_clearing_system(ClearingSystem)
	gameplay_grid.set_water_system(water_system)
	gameplay_grid.build_from_terrain()

	terrain_manager.region_rebuilt.connect(_on_terrain_region_rebuilt)

	# 5. Player, then vegetation cameras (they need the player camera).
	if spawn_player_on_ready:
		var spawn := spawn_position_override
		if spawn == Vector3.ZERO:
			spawn = Vector3(map_size * 0.5, 0.0, map_size * 0.5)
		spawn_player_at(spawn)

	_start_ambience()

	var clutter := GroundClutter.new()
	add_child(clutter)
	clutter.setup(self)

	_warm_effects()

	is_world_ready = true


## C2 pipeline pre-warm: render every combat-effect material once at world build,
## behind the loading screen, so first contact never pays the shader-compile
## hitch. Placed 60m downrange: in frustum (pipelines only compile for drawn
## objects) but past every effect's audio max_distance. Headless has no
## pipelines to compile - skip, and skip when no player camera exists.
func _warm_effects() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if player == null:
		return
	var cam := player.get_node_or_null("Head/Camera3D") as Camera3D
	if cam == null:
		return
	var root := Node3D.new()
	root.name = "FXWarm"
	add_child(root)
	var fwd: Vector3 = -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var pos: Vector3 = cam.global_position + fwd * 60.0
	pos.y = terrain_manager.get_height_at(pos) + 1.2
	root.global_position = pos
	GunFX.muzzle_flash(root, pos)
	GunFX.impact(root, pos, Vector3.UP, false)
	GunFX.impact(root, pos, Vector3.UP, true)
	GunFX.blood(root, pos, Vector3.UP, fwd, null)
	GunFX.blood_pool(root, pos)
	GunFX.bullet_hole(root, pos, Vector3.UP)
	GunFX._spawn_explosion_visual(root, pos)
	var bs: BulletSystem = CombatManager.bullets
	if bs != null:
		var tracer: MeshInstance3D = bs._visual_acquire(Color(1.0, 0.85, 0.4))
		if tracer != null:
			tracer.global_position = pos + Vector3.UP * 0.5
			tracer.visible = true
			get_tree().create_timer(0.25).timeout.connect(func() -> void:
				if is_instance_valid(tracer):
					tracer.visible = false)
	# Effects self-expire well inside 2s; the root sweeps up what persists (decals).
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_instance_valid(root):
			root.queue_free())


## Ambience is POSITIONAL: a quiet 2D floor (broadband insect hiss, which should
## be omnipresent) plus a ring of AudioStreamPlayer3D emitters around the player
## that drift and re-seat, each pitch-varied, so the sound comes FROM PLACES.
const AMBIENCE_EMITTERS: int = 4
const AMBIENCE_RING_MIN: float = 12.0
const AMBIENCE_RING_MAX: float = 45.0
var _amb_emitters: Array[AudioStreamPlayer3D] = []
var _amb_reseat_t: float = 0.0
## Everything WILDLIFE (birds/insects) - ducked while it rains, because rain
## silences the jungle. The distant-war bed is NOT wildlife and never ducks.
var _wildlife: Array[Node] = []
## An off-map artillery event this close hushes the birds.
const AMBIENT_WAR_HUSH_M: float = 400.0
var _world_noise_t: float = 0.0
var _duck_rain: bool = false
var _duck_war: bool = false
var _duck_state: bool = false

func _start_ambience() -> void:
	# The jungle bed streams from a RANDOM OFFSET so no two missions open on the same
	# minute. Dev asset, license unclear - falls back to the synth loop if absent.
	var bed: AudioStream = null
	if ResourceLoader.exists("res://assets/audio/ambience/jungle_day.mp3"):
		var mp3 := load("res://assets/audio/ambience/jungle_day.mp3") as AudioStreamMP3
		if mp3 != null:
			mp3.loop = true
			bed = mp3
	var floor_s := load("res://assets/audio/sfx/jungle_loop.wav") as AudioStreamWAV
	if floor_s != null:
		floor_s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		floor_s.loop_end = floor_s.data.size() / 2
	if bed == null:
		bed = floor_s
	if bed != null:
		var fp := AudioStreamPlayer.new()
		fp.stream = bed
		fp.volume_db = -14.0 if bed is AudioStreamMP3 else -22.0
		add_child(fp)
		fp.play(randf() * maxf(1.0, bed.get_length() - 60.0) if bed is AudioStreamMP3 else 0.0)
		fp.set_meta("base_db", fp.volume_db)
		_wildlife.append(fp)
	# Distant war stays 2D (it IS meant to be everywhere and directionless).
	var war_s := load("res://assets/audio/sfx/distant_war_loop.wav") as AudioStreamWAV
	if war_s != null:
		war_s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		war_s.loop_end = war_s.data.size() / 2
		var wp := AudioStreamPlayer.new()
		wp.stream = war_s
		wp.volume_db = -20.0
		add_child(wp)
		wp.play()
	# Synth bird emitters: only when the real recorded bed is absent.
	for i in range(AMBIENCE_EMITTERS if not (bed is AudioStreamMP3) else 0):
		var e := AudioStreamPlayer3D.new()
		e.stream = floor_s
		e.volume_db = -16.0
		e.unit_size = 14.0
		e.max_distance = AMBIENCE_RING_MAX + 20.0
		e.pitch_scale = randf_range(0.8, 1.5)   # each "voice" different
		add_child(e)
		_amb_emitters.append(e)
		e.set_meta("base_db", e.volume_db)
		_wildlife.append(e)
		e.play()
	_reseat_ambience()


## Rain silences the jungle: duck the wildlife fast when a squall opens (~3s),
## fade back slowly when it ends (~14s). Called by MissionWeather on transitions.
func set_wildlife_ducked(ducked: bool) -> void:
	_duck_rain = ducked
	_apply_wildlife_duck()


## Rain and the war duck the same emitters. Tracking the two causes separately stops
## a passing Huey from un-ducking a squall that is still falling.
func _apply_wildlife_duck() -> void:
	var ducked: bool = _duck_rain or _duck_war
	if ducked == _duck_state:
		return
	_duck_state = ducked
	for w in _wildlife:
		if not is_instance_valid(w):
			continue
		var base: float = float(w.get_meta("base_db", -16.0))
		var tw := create_tween()
		tw.tween_property(w, "volume_db", -58.0 if ducked else base, 3.0 if ducked else 14.0)


## The jungle hears what the sim rolled. AirTraffic and AmbientWar keep rosters of
## what is happening off-screen; anything close enough hushes the birds.
func _poll_world_noise() -> void:
	if player == null:
		return
	var here: Vector3 = player.global_position
	var loud: bool = false

	var at := get_node_or_null("AirTraffic") as AirTraffic
	if at != null:
		for f: Dictionary in at.get_in_flight():
			if (f.get("pos") as Vector3).distance_to(here) <= AirTraffic.OVERHEAD_M:
				loud = true
				break

	var aw := get_node_or_null("AmbientWar") as AmbientWar
	if not loud and aw != null:
		for e: Dictionary in aw.get_active():
			if (e.get("position") as Vector3).distance_to(here) <= AMBIENT_WAR_HUSH_M:
				loud = true
				break

	_duck_war = loud
	_apply_wildlife_duck()

## Drift the emitters onto a fresh ring around the player so the wildlife moves.
func _reseat_ambience() -> void:
	if player == null:
		return
	for e in _amb_emitters:
		if not is_instance_valid(e):
			continue
		var a: float = randf() * TAU
		var r: float = randf_range(AMBIENCE_RING_MIN, AMBIENCE_RING_MAX)
		var pos: Vector3 = player.global_position + Vector3(cos(a), 0.0, sin(a)) * r
		if terrain_manager != null:
			pos.y = terrain_manager.get_height_at(pos) + randf_range(2.0, 8.0)  # up in the canopy
		e.global_position = pos


## Called by GameFlow once the weather/time roll is known: crickets and frogs
## replace the jungle bed on NIGHT missions.
func start_night_ambience() -> void:
	var stream := load("res://assets/audio/sfx/night_insects_loop.wav") as AudioStreamWAV
	if stream == null:
		return
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -12.0
	add_child(p)
	p.play()
	p.set_meta("base_db", p.volume_db)
	_wildlife.append(p)  # crickets go quiet in the rain too


## Public: spawn the player at a position (mission insertion). Wires cameras+HUD.
func spawn_player_at(spawn: Vector3) -> void:
	if player != null:
		var gy: float = terrain_manager.get_height_at(spawn)
		player.global_position = Vector3(spawn.x, gy + 1.0, spawn.z)
		return
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	var ground_y: float = terrain_manager.get_height_at(spawn)
	player.global_position = Vector3(spawn.x, ground_y + 1.0, spawn.z)
	_wire_cameras(player.get_node("Head/Camera3D"))
	_setup_hud()


func _wire_cameras(cam: Camera3D) -> void:
	terrain_manager.set_camera(cam)
	vegetation_manager.set_camera(cam)
	vegetation_manager.set_chunk_size(terrain_manager.chunk_size)


func _setup_terrain_shader_textures() -> void:
	if not TerrainChunkScript.is_using_shader():
		return
	var params := {}
	if terrain_manager.heightmap:
		params["terrain_size"] = terrain_manager.heightmap.size
	params["cell_size"] = terrain_manager.cell_size
	if terrain_manager.heightmap:
		params["height_scale"] = terrain_manager.heightmap.height_scale
	var clear_tex: ImageTexture = ClearingSystem.get_clearing_texture()
	if clear_tex:
		params["clearing_texture"] = clear_tex
	TerrainChunkScript.set_shader_parameters(params)


func _on_terrain_region_rebuilt(world_rect: Rect2) -> void:
	if _dirty_terrain_rect.size == Vector2.ZERO:
		_dirty_terrain_rect = world_rect
	else:
		_dirty_terrain_rect = _dirty_terrain_rect.merge(world_rect)
	if _terrain_flush_queued:
		return
	_terrain_flush_queued = true
	_flush_terrain_dirty.call_deferred()


## Deferred, never synchronous: ClearingSystem emits from _apply_stage_changes, one
## call BEFORE it writes the clearing mask, so an immediate re-seat would read the
## old mask. Water re-seats FIRST - the grid's WATER type and wade passability are
## queries into WaterSystem, so a grid rebuilt before it would bake stale water.
func _flush_terrain_dirty() -> void:
	_terrain_flush_queued = false
	var rect: Rect2 = _dirty_terrain_rect
	_dirty_terrain_rect = Rect2()
	if rect.size == Vector2.ZERO:
		return
	if water_system != null:
		water_system.reseat_region(rect)
	if gameplay_grid != null:
		gameplay_grid.rebuild_rect(rect)


func _on_vegetation_updated(_region: Rect2i) -> void:
	var clear_tex: ImageTexture = ClearingSystem.get_clearing_texture()
	if clear_tex:
		TerrainChunkScript.set_shader_texture("clearing_texture", clear_tex)
	if gameplay_grid:
		var world_center := Vector3(
			(_region.position.x + _region.size.x / 2.0) * terrain_manager.map_size / 512.0,
			0,
			(_region.position.y + _region.size.y / 2.0) * terrain_manager.map_size / 512.0
		)
		var radius: float = maxf(_region.size.x, _region.size.y) * terrain_manager.map_size / 512.0
		gameplay_grid.update_region(world_center, radius)


func _setup_hud() -> void:
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	var health_system: HealthSystem = player.get_node("HealthSystem")
	var weapon_holder: WeaponHolder = player.get_node("Head/Camera3D/WeaponHolder")
	var equipment_manager: EquipmentManager = player.get_node("EquipmentManager")
	var grenade_handler: GrenadeHandler = player.get_node("Head/Camera3D/GrenadeHandler")
	hud.setup(health_system, weapon_holder, equipment_manager, grenade_handler)


var _fps_log_timer: float = 0.0


func _process(delta: float) -> void:
	if not _amb_emitters.is_empty():
		_amb_reseat_t += delta
		if _amb_reseat_t >= 6.0:   # re-seat every 6s so the treeline "moves"
			_amb_reseat_t = 0.0
			_reseat_ambience()
	_world_noise_t += delta
	if _world_noise_t >= 1.0:
		_world_noise_t = 0.0
		_poll_world_noise()
	if not WorldConfig.LOG_FPS or not is_world_ready:
		return
	_fps_log_timer += delta
	if _fps_log_timer >= WorldConfig.FPS_LOG_INTERVAL:
		_fps_log_timer = 0.0
		print("[PERF] FPS=%.0f" % Engine.get_frames_per_second())


func _physics_process(delta: float) -> void:
	if not is_world_ready or player == null:
		return
	_reseat_timer += delta
	if _reseat_timer < 2.0:
		return
	_reseat_timer = 0.0
	# Never re-seat a tunnel rat.
	if "_in_tunnel" in player and player._in_tunnel != null:
		return
	var ground_y: float = terrain_manager.get_height_at(player.global_position)
	if player.global_position.y < ground_y - RESEAT_DEPTH:
		player.global_position.y = ground_y + 1.0
		player.velocity = Vector3.ZERO
