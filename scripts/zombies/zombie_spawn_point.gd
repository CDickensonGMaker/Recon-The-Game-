## zombie_spawn_point.gd - one place the dead come from.
##
## Zone-gated. ZombieWaveDirector asks is_active() before drawing a point, so a
## spawn behind a door the player has not bought stays silent. That gating IS the
## map's difficulty curve: opening a door buys you space and costs you a new
## direction to watch.
class_name ZombieSpawnPoint
extends Node3D

## Empty = always live (the starting room's own windows).
@export var zone: String = ""
## A spawn this close to the player pops a body in his face. The director skips it.
@export var min_player_distance: float = 12.0

var _forced_open: bool = false


func _ready() -> void:
	add_to_group("zombie_spawns")


func is_active() -> bool:
	if not _zone_open():
		return false
	var p: Node = GameManager.player
	if p != null and is_instance_valid(p) and p is Node3D:
		if global_position.distance_to((p as Node3D).global_position) < min_player_distance:
			return false
	return true


func _zone_open() -> bool:
	if zone.is_empty() or _forced_open:
		return true
	var econ: ZombieEconomy = ZombieEconomy.current
	# No economy means no run - a bench dropping zombies in should not be gated
	# behind a door system it never built.
	return econ == null or econ.opened_doors.values().size() >= 0 and _zone_bought(econ)


func _zone_bought(econ: ZombieEconomy) -> bool:
	for n in get_tree().get_nodes_in_group("zombie_doors"):
		var d := n as ZombieDoor
		if d != null and d.unlocks_zone == zone and d.is_open:
			return true
	return econ.opened_doors.has(zone)


func force_open() -> void:
	_forced_open = true
