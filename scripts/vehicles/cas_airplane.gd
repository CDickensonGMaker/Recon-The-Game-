## cas_airplane.gd - Close air support run: 4-phase dive-bomb (NS16).
## Kinematic; concepts from the RTS airplane system, original implementation.
## Crater cap (council rule): BOMB = 1 terrain deformation; NAPALM strip
## deforms only its center drop. Drops staggered to spread chunk rebuilds.
class_name CASAirplane
extends Node3D

signal run_complete

enum Ordnance { BOMB, NAPALM }
enum Phase { APPROACH, DIVE, RELEASE, CLIMB, DONE }

const APPROACH_ALT: float = 80.0
const RELEASE_ALT: float = 30.0
const SPEED: float = 120.0
const NAPALM_DROPS: int = 5
const NAPALM_SPACING: float = 15.0
const DROP_STAGGER: float = 0.4

var terrain: TerrainManager
var phase: Phase = Phase.APPROACH
var _target: Vector3 = Vector3.ZERO
var _run_dir: Vector3 = Vector3.FORWARD
var _ordnance: Ordnance = Ordnance.BOMB
var _released: bool = false
var _climb_time: float = 0.0


func call_strike(terrain_manager: TerrainManager, target: Vector3, ordnance: Ordnance, run_dir: Vector3 = Vector3.ZERO) -> void:
	terrain = terrain_manager
	_target = target
	_target.y = terrain.get_height_at(target)
	_ordnance = ordnance
	_run_dir = run_dir
	if _run_dir.length() < 0.1:
		_run_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	_run_dir.y = 0.0
	_run_dir = _run_dir.normalized()
	global_position = _target - _run_dir * 900.0 + Vector3(0, APPROACH_ALT, 0)
	global_position.y = maxf(global_position.y, terrain.get_height_at(global_position) + 40.0)
	look_at(global_position + _run_dir, Vector3.UP)
	phase = Phase.APPROACH


func _physics_process(delta: float) -> void:
	match phase:
		Phase.APPROACH, Phase.DIVE:
			_fly_run(delta)
		Phase.CLIMB:
			global_position += (_run_dir * SPEED + Vector3(0, 30, 0)) * delta
			_climb_time += delta
			if _climb_time > 8.0:
				phase = Phase.DONE
				run_complete.emit()
				queue_free()
		Phase.DONE:
			pass


func _fly_run(delta: float) -> void:
	var flat_dist: float = Vector2(global_position.x - _target.x, global_position.z - _target.z).length()
	var desired_y: float = _target.y + APPROACH_ALT
	if flat_dist < 450.0:
		phase = Phase.DIVE
		desired_y = _target.y + RELEASE_ALT
	global_position += _run_dir * SPEED * delta
	global_position.y = lerpf(global_position.y, desired_y, 2.0 * delta)
	if phase == Phase.DIVE and not _released and flat_dist < 40.0:
		_released = true
		_release_ordnance()
		phase = Phase.CLIMB


func _release_ordnance() -> void:
	match _ordnance:
		Ordnance.BOMB:
			_drop_bomb()
		Ordnance.NAPALM:
			_drop_napalm_strip()


func _drop_bomb() -> void:
	var impact := _target
	# Fall delay, then the bang.
	get_tree().create_timer(0.8).timeout.connect(func() -> void:
		CombatManager.apply_explosion_damage(impact, 220, 60, 16.0, null)
		DamageSystem.apply_damage(impact, DamageSystem.DamageType.LARGE_EXPLOSION, 1.0)
		CombatManager.apply_suppression_in_area(impact, 40.0, 1.0))


func _drop_napalm_strip() -> void:
	for i in range(NAPALM_DROPS):
		var offset: float = float(i - NAPALM_DROPS / 2) * NAPALM_SPACING
		var pos := _target + _run_dir * offset
		var is_center: bool = (i == NAPALM_DROPS / 2)
		var delay: float = 0.8 + float(i) * DROP_STAGGER
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			var ground := pos
			ground.y = terrain.get_height_at(pos) if terrain else pos.y
			CombatManager.apply_explosion_damage(ground, 90, 30, 10.0, null)
			FireHazard.create_at(get_tree().current_scene, ground, 10.0, 15.0)
			_ignite_nearby_structures(ground)  # R71: thatch huts catch fire
			if is_center:
				DamageSystem.apply_damage(ground, DamageSystem.DamageType.NAPALM, 1.0))


## R71: any nearby thatch hut catches fire too - a bigger, longer-lived blaze
## right at the structure instead of just the ground patch.
func _ignite_nearby_structures(impact: Vector3) -> void:
	for s in get_tree().get_nodes_in_group("flammable_structures"):
		var structure := s as Node3D
		if structure == null or structure.has_meta("burned"):
			continue
		if structure.global_position.distance_to(impact) > 14.0:
			continue
		structure.set_meta("burned", true)
		FireHazard.create_at(get_tree().current_scene, structure.global_position, 6.0, 40.0)
