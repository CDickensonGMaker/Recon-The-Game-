## exfil_zone.gd - The exfil gate (RTCW rule): refuses until required objectives
## are met (NS08). Until the exfil bird exists (NS15), complete_on_enter ends
## the mission directly.
class_name ExfilZone
extends Node3D

signal player_at_exfil(unlocked: bool)

@export var radius: float = 10.0
@export var complete_on_enter: bool = true

var director: MissionDirector
var _poll_timer: float = 0.0
var _refuse_cooldown: float = 0.0
var _done: bool = false


func register(mission_director: MissionDirector) -> void:
	director = mission_director


func _physics_process(delta: float) -> void:
	if _done or director == null:
		return
	_refuse_cooldown = maxf(0.0, _refuse_cooldown - delta)
	_poll_timer += delta
	if _poll_timer < 0.25:
		return
	_poll_timer = 0.0
	var player := GameManager.player as Node3D
	if player == null:
		return
	var flat_dist: float = Vector2(player.global_position.x - global_position.x,
		player.global_position.z - global_position.z).length()
	if flat_dist > radius:
		return
	var unlocked: bool = director.state.is_exfil_unlocked()
	if unlocked:
		_done = true
		player_at_exfil.emit(true)
		if complete_on_enter:
			director.finish_mission()
	elif _refuse_cooldown <= 0.0:
		_refuse_cooldown = 5.0
		director.toast.emit("OBJECTIVES REMAIN - EXFIL DENIED")
		player_at_exfil.emit(false)
