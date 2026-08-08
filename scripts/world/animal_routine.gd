## animal_routine.gd - day/night ambience for one village animal: graze between the
## graze_* markers by day, bed down at the home_<species> marker by night, bolt from
## gunfire. Pure Node3D drift on terrain height - animals are dressing (no physics
## body, no nav agent), same law as village props. One animal, one clip, no phase-lock.
class_name AnimalRoutine
extends Node

const THINK_INTERVAL: float = 0.7
const ARRIVE_M: float = 0.8
const GRAZE_DRIFT_M: float = 3.5
const HOME_SETTLE_M: float = 2.5
const PANIC_S: float = 5.0
const PANIC_RUN_M: float = 12.0
const TURN_SPEED: float = 4.0

enum Mode { LOITER, TRAVEL, PANIC }

var _body: Node3D
var _anim: AnimationPlayer
var _terrain: TerrainManager
var _rng := RandomNumberGenerator.new()

var _home: Vector3
var _graze: Array[Vector3] = []
var _day_clips: Array[StringName] = []    ## idle variants + Peck
var _night_clips: Array[StringName] = []  ## idle variants only
var _walk_clip: StringName = &""
var _run_clip: StringName = &""

var _mode: int = Mode.LOITER
var _target: Vector3 = Vector3.ZERO
var _think: float = 0.0
var _hold: float = 0.0
var _panic_left: float = 0.0
var _walk_speed: float = 0.6
var _run_speed: float = 2.8
var _current_clip: StringName = &""


static func attach(animal: Node3D, species: String, home: Vector3,
		grazing: Array, terrain: TerrainManager) -> void:
	var r := AnimalRoutine.new()
	r.name = "AnimalRoutine"
	animal.add_child(r)
	r._setup(species, home, grazing, terrain)


func _setup(species: String, home: Vector3, grazing: Array, terrain: TerrainManager) -> void:
	_body = get_parent() as Node3D
	_terrain = terrain
	_home = home
	_anim = _body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim == null or _terrain == null:
		set_process(false)
		return
	# Seeded off the spawn spot (ADR-010: never Time, never an unseeded roll).
	_rng.seed = hash(Vector2(_body.global_position.x, _body.global_position.z)) + hash(species)
	for g in grazing:
		var allowed: Array = g.get("species", [])
		if allowed.is_empty() or allowed.has(species):
			_graze.append(g.pos as Vector3)
	var slows: Array[StringName] = []
	var walks: Array[StringName] = []
	var runs: Array[StringName] = []
	for anim_name in _anim.get_animation_list():
		var low: String = String(anim_name).to_lower()
		if low.contains("idle"):
			_night_clips.append(StringName(anim_name))
			_day_clips.append(StringName(anim_name))
		elif low.contains("peck"):
			_day_clips.append(StringName(anim_name))
		elif low.contains("walkslow"):
			slows.append(StringName(anim_name))
		elif low.contains("walk"):
			walks.append(StringName(anim_name))
		elif low.contains("run"):
			runs.append(StringName(anim_name))
	var walk_pool: Array[StringName] = slows if not slows.is_empty() else walks
	if not walk_pool.is_empty():
		_walk_clip = walk_pool[_rng.randi() % walk_pool.size()]
	if not runs.is_empty():
		_run_clip = runs[_rng.randi() % runs.size()]
	if species == "chicken":
		_walk_speed = 0.45
		_run_speed = 1.8
	_hold = _rng.randf_range(1.0, 6.0)
	if _run_clip != &"":
		NoiseBus.noise_emitted.connect(_on_noise)


func _process(delta: float) -> void:
	_think += delta
	if _think >= THINK_INTERVAL:
		_think = 0.0
		_think_tick()
	match _mode:
		Mode.TRAVEL:
			_step(delta, _walk_speed)
		Mode.PANIC:
			_panic_left -= delta
			_step(delta, _run_speed)
			if _panic_left <= 0.0:
				_settle()


func _think_tick() -> void:
	if _mode != Mode.LOITER:
		return
	_hold -= THINK_INTERVAL
	if _hold > 0.0:
		return
	var pos: Vector3 = _body.global_position
	if MissionWeather.is_night:
		if Vector2(pos.x - _home.x, pos.z - _home.z).length() > HOME_SETTLE_M:
			_go(_home)
		else:
			_hold = _rng.randf_range(6.0, 12.0)
			_play_pool(_night_clips)
		return
	if _graze.is_empty() or _rng.randf() < 0.55:
		_hold = _rng.randf_range(3.0, 8.0)
		_play_pool(_day_clips)
	else:
		var g: Vector3 = _graze[_rng.randi() % _graze.size()]
		_go(g + Vector3(_rng.randf_range(-GRAZE_DRIFT_M, GRAZE_DRIFT_M), 0.0,
			_rng.randf_range(-GRAZE_DRIFT_M, GRAZE_DRIFT_M)))


func _step(delta: float, speed: float) -> void:
	var pos: Vector3 = _body.global_position
	var to := Vector3(_target.x - pos.x, 0.0, _target.z - pos.z)
	var dist: float = to.length()
	if dist <= ARRIVE_M:
		_settle()
		return
	var dir: Vector3 = to / dist
	var next: Vector3 = pos + dir * minf(speed * delta, dist)
	next.y = _terrain.get_height_at(next)
	_body.global_position = next
	_body.rotation.y = lerp_angle(_body.rotation.y, atan2(dir.x, dir.z), TURN_SPEED * delta)


func _settle() -> void:
	_mode = Mode.LOITER
	_hold = _rng.randf_range(3.0, 8.0)
	_play_pool(_night_clips if MissionWeather.is_night else _day_clips)


func _go(dest: Vector3) -> void:
	_target = dest
	_mode = Mode.TRAVEL
	_play(_walk_clip)


func _on_noise(type: int, position: Vector3, radius: float, _team: int) -> void:
	if type != NoiseBus.NoiseType.GUNSHOT and type != NoiseBus.NoiseType.EXPLOSION:
		return
	var pos: Vector3 = _body.global_position
	if pos.distance_to(position) > radius:
		return
	var away := Vector3(pos.x - position.x, 0.0, pos.z - position.z)
	if away.length() < 0.01:
		away = Vector3.FORWARD
	_target = pos + away.normalized() * PANIC_RUN_M
	_panic_left = PANIC_S + _rng.randf_range(0.0, 2.0)
	_mode = Mode.PANIC
	_play(_run_clip)


func _play_pool(pool: Array[StringName]) -> void:
	if not pool.is_empty():
		_play(pool[_rng.randi() % pool.size()])


func _play(clip: StringName) -> void:
	if clip == &"" or (_current_clip == clip and _anim.is_playing()):
		return
	_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_anim.play(clip, 0.25)
	_current_clip = clip
