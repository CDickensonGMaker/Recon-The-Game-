## ambient_war.gd - distant war audio/visual events that play in the background
## regardless of the player. On each SimClock.hour_advanced, roll 1-3 events for
## the hour. Each: position 200-800m from the player, a particle column, a
## directional light flash, audio source. Lifetime 5-30 seconds.
class_name AmbientWar
extends Node

## A fired event: {kind, position, lifetime_s, scheduled_remove_ms, ...}
var _active: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
const KINDS: Array = ["artillery", "mortar", "tracers", "burning", "gunship_attack"]


func _ready() -> void:
	if SimClock != null:
		var cb := Callable(self, "_on_hour")
		if not SimClock.hour_advanced.is_connected(cb):
			SimClock.hour_advanced.connect(cb)


func _on_hour(_sim_hour: int) -> void:
	_roll_events()


func _roll_events() -> void:
	# 1-3 events per hour. The player position is queried lazily; if no player
	# exists (e.g. unit tests), we use the origin.
	var player := GameManager.player as Node3D
	var center: Vector3 = Vector3.ZERO
	if player != null:
		center = player.global_position
	var n: int = rng.randi_range(1, 3)
	for i in range(n):
		var kind: String = KINDS[rng.randi() % KINDS.size()]
		var bearing: float = rng.randf_range(0.0, TAU)
		var dist: float = rng.randf_range(200.0, 800.0)
		var pos: Vector3 = center + Vector3(cos(bearing), 0.0, sin(bearing)) * dist
		var life_s: float = rng.randf_range(5.0, 30.0)
		_active.append({
			"kind": kind,
			"position": pos,
			"lifetime_s": life_s,
			"born_ms": Time.get_ticks_msec(),
		})


func get_active() -> Array:
	return _active
