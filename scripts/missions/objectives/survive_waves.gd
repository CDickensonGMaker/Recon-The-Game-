## survive_waves.gd - HOLD objective: survive N assault waves on a position (NS12).
## Waves spawn lazily at passable ring points with clear approach lanes.
class_name SurviveWaves
extends ObjectiveSensor

signal wave_started(wave_number: int, total: int, direction_text: String)
signal wave_cleared(wave_number: int)

@export var wave_count: int = 3
@export var per_wave_min: int = 5
@export var per_wave_max: int = 8
@export var ring_min: float = 150.0
@export var ring_max: float = 250.0
@export var lull_seconds: float = 20.0
@export var initial_delay: float = 12.0

const DATA_PATHS: Array[String] = [
	"res://data/enemies/vc_rifleman.tres",
	"res://data/enemies/nva_regular.tres",
]

var world: GameWorld
var _rng := RandomNumberGenerator.new()
var _current_wave: int = 0
var _wave_live: int = 0
var _running: bool = false


func start(game_world: GameWorld, rng_seed: int) -> void:
	world = game_world
	_rng.seed = rng_seed
	director.enemy_killed.connect(_on_enemy_killed)
	_running = true
	_run_waves()


## Every await below can resume on a node whose world GameFlow already freed.
## stop() had zero callers before MissionScope existed.
func _run_waves() -> void:
	add_to_group("wave_runners")
	# W58: prep phase toast (claymores out, sectors set).
	if director and initial_delay > 20.0:
		director.toast.emit("PREP THE LINE - CLAYMORES [6], SMOKE [5] - %ds TO CONTACT" % int(initial_delay))
	await get_tree().create_timer(initial_delay).timeout
	if not _alive():
		return
	for wave in range(1, wave_count + 1):
		_current_wave = wave
		var sector_angle: float = _rng.randf_range(0.0, TAU)
		_spawn_wave(wave, sector_angle)
		wave_started.emit(wave, wave_count, _direction_text(sector_angle))
		if director:
			director.toast.emit("WAVE %d INBOUND - %s" % [wave, _direction_text(sector_angle)])
		# Wait for the wave to die.
		while _wave_live > 0 and _running:
			await get_tree().create_timer(0.5).timeout
			if not _alive():
				return
		if not _alive():
			return
		wave_cleared.emit(wave)
		if director and wave < wave_count:
			director.toast.emit("WAVE %d REPELLED" % wave)
			await get_tree().create_timer(lull_seconds).timeout
			if not _alive():
				return
	if director:
		director.toast.emit("FINAL WAVE REPELLED - FIREBASE HELD")
	complete()


func _spawn_wave(wave: int, sector_angle: float) -> void:
	var count: int = _rng.randi_range(per_wave_min, per_wave_max)
	var tag := "wave_%d" % wave
	var spawned: int = 0
	var attempts: int = 0
	while spawned < count and attempts < 120:
		attempts += 1
		var a: float = sector_angle + _rng.randf_range(-0.6, 0.6)
		var r: float = _rng.randf_range(ring_min, ring_max)
		var pos := global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)
		if not _lane_passable(pos):
			continue
		var data: String = DATA_PATHS[_rng.randi() % DATA_PATHS.size()]
		var enemy := director.spawn_tracked_enemy(pos, data, tag)
		enemy.add_to_group(tag)
		# W57: final wave brings sappers - fast crawlers with satchel charges.
		if wave == wave_count and _rng.randf() < 0.3:
			enemy.move_speed *= 1.35
			enemy.max_hp = int(enemy.max_hp * 0.6)
			enemy.current_hp = enemy.max_hp
			var sapper := SapperCharge.new()
			enemy.add_child(sapper)
			sapper.setup(global_position, director)
		spawned += 1
	if spawned == 0:
		# Emergency: spawn close, guaranteed (never soft-lock the wave).
		for i in range(count):
			var a2: float = sector_angle + float(i)
			var pos2 := global_position + Vector3(cos(a2), 0, sin(a2)) * 100.0
			var enemy2 := director.spawn_tracked_enemy(pos2, DATA_PATHS[0], tag)
			enemy2.add_to_group(tag)
			spawned += 1
	_wave_live = spawned


func _lane_passable(spawn_pos: Vector3) -> bool:
	if world == null:
		return true
	var grid := world.gameplay_grid
	if grid.is_water(spawn_pos) or not grid.is_position_passable(spawn_pos):
		return false
	# March the straight lane toward the firebase in 25m steps.
	var to_center := global_position - spawn_pos
	var steps: int = int(to_center.length() / 25.0)
	for i in range(1, steps):
		var p := spawn_pos + to_center * (float(i) / float(steps))
		if grid.is_water(p):
			return false
	return true


func _on_enemy_killed(_enemy: EnemyBase, tag: String) -> void:
	if tag == "wave_%d" % _current_wave:
		_wave_live = maxi(0, _wave_live - 1)


func _direction_text(angle: float) -> String:
	var dirs := ["EAST", "SOUTHEAST", "SOUTH", "SOUTHWEST", "WEST", "NORTHWEST", "NORTH", "NORTHEAST"]
	var idx: int = int(roundf(angle / (TAU / 8.0))) % 8
	return dirs[idx]


func stop() -> void:
	_running = false


## The node may have been freed while a SceneTreeTimer held a reference to this
## coroutine. is_inside_tree() is false the moment queue_free() lands.
func _alive() -> bool:
	return _running and is_instance_valid(self) and is_inside_tree()
