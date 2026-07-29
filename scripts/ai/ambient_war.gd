## ambient_war.gd - distant war audio/visual events that play in the background
## regardless of the player. On each SimClock.hour_advanced, roll 1-3 events for
## the hour. Each: position 200-800m from the player, positional audio; the
## explosion-type kinds add a FAKE emissive fireball + smoke column (GunFX, no
## real light - ADR-026). Audio lifetime 5-30 seconds; the flash self-expires.
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
		# 400m floor: at 200m the theater reads as a REAL engagement with no
		# enemy (playtest 07-29: a gunship visibly strafing nothing). Distant
		# war is a horizon, not a neighbor.
		var dist: float = rng.randf_range(400.0, 800.0)
		var pos: Vector3 = center + Vector3(cos(bearing), 0.0, sin(bearing)) * dist
		var life_s: float = rng.randf_range(5.0, 30.0)
		_active.append({
			"kind": kind,
			"position": pos,
			"lifetime_s": life_s,
			"born_ms": Time.get_ticks_msec(),
			"node": _spawn_audio(kind, pos),
		})
		_spawn_visual(kind, pos)


## The war was rolled but never heard. Give each event a positioned source so it
## arrives from a bearing instead of out of the flat distant_war_loop.
func _spawn_audio(kind: String, pos: Vector3) -> AudioStreamPlayer3D:
	var path: String = "res://assets/audio/sfx/shot_distant.wav"
	if kind == "artillery" or kind == "mortar":
		path = "res://assets/audio/sfx/explosion.wav"
	var stream := load(path) as AudioStream
	if stream == null:
		return null
	var src := AudioStreamPlayer3D.new()
	src.stream = stream
	src.unit_size = 220.0
	src.max_distance = 1200.0
	src.volume_db = -8.0
	add_child(src)
	src.global_position = pos
	src.play()
	return src


## Distant war gets a horizon flash: reuse the shared explosion visual (fake
## emissive fireball + smoke, self-expiring) enlarged so it reads at 200-800m.
## Shares GunFX's MAX_EXPLOSIONS budget - tolerable: 1-3 rolls per sim-hour, each
## flash frees in a few seconds. tracers stay audio-only (no distant streak VFX).
func _spawn_visual(kind: String, pos: Vector3) -> void:
	if kind == "tracers":
		return
	GunFX._spawn_explosion_visual(self, pos, 12.0, 2.5)


## Events expire. The roster only ever grew, and every entry it held was a live
## audio source.
func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	for i in range(_active.size() - 1, -1, -1):
		var e: Dictionary = _active[i]
		var age_s: float = float(now - int(e.get("born_ms", now))) / 1000.0
		if age_s < float(e.get("lifetime_s", 0.0)):
			continue
		var node := e.get("node") as AudioStreamPlayer3D
		if node != null and is_instance_valid(node):
			node.queue_free()
		_active.remove_at(i)


func get_active() -> Array:
	return _active
