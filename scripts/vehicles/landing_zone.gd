## landing_zone.gd - LZ marker with threat assessment.
class_name LandingZone
extends Node3D

enum LZStatus { COLD, WARM, HOT }

@export var lz_name: String = "LZ"
@export var lz_radius: float = 15.0
@export var capacity: int = 1

const THREAT_CHECK_INTERVAL: float = 2.0
const THREAT_RADIUS: float = 100.0
const THREAT_DECAY: float = 0.1

var threat_level: float = 0.0
var helicopters_present: int = 0
var _check_timer: float = 0.0


func _physics_process(delta: float) -> void:
	_check_timer += delta
	threat_level = maxf(0.0, threat_level - THREAT_DECAY * delta)
	if _check_timer < THREAT_CHECK_INTERVAL:
		return
	_check_timer = 0.0
	var enemies: Array[Node] = CombatManager.get_enemies_in_range(global_position, THREAT_RADIUS)
	var live: int = 0
	var closest: float = THREAT_RADIUS
	for e in enemies:
		if e is EnemyBase and not (e as EnemyBase).is_dead():
			live += 1
			closest = minf(closest, (e as Node3D).global_position.distance_to(global_position))
	if live > 0:
		threat_level = minf(1.0, threat_level + 0.1 * float(live) + (0.3 if closest < 30.0 else 0.0))


func get_status() -> LZStatus:
	if threat_level >= 0.7:
		return LZStatus.HOT
	elif threat_level >= 0.3:
		return LZStatus.WARM
	return LZStatus.COLD


func is_hot() -> bool:
	return get_status() == LZStatus.HOT


func can_land() -> bool:
	return helicopters_present < capacity
