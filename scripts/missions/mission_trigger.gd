## mission_trigger.gd - Configurable trigger volume for scripted events.
##
## KEEP - RULED BY THE SUMMONER 2026-07-20. Unreached by production today: the
## only thing naming this is its own test, which is the mutual-alibi shape the
## fossil law normally eats. He wants scripted events and has not started on
## them yet. DO NOT DELETE as an unwired system. Pairs with scripted_sequence.gd.
##
## Modes:
##   ENTER - a body (player / ally / enemy per filter) physically enters the volume
##   SIGHT - the player has genuine raycast LOS to `sight_marker` within range
##           (CombatManager.has_line_of_sight - NEVER a camera-look fake)
##   NOISE - a NoiseBus event lands within `noise_radius` of this trigger
##   TIMER - fires `timer_seconds` after activation (armed at _ready or via activate())
##
## HONESTY LAW (Pillar 3): this node only OBSERVES and emits `triggered`. It never
## spawns, teleports, wakes or mutates entities, and there is deliberately no spawn
## helper here - consumers must draw any cast from the AO's live, finite population.
class_name MissionTrigger
extends Area3D

signal triggered(context: Dictionary)

enum Mode { ENTER, SIGHT, NOISE, TIMER }
enum ActivatorFilter { PLAYER, ALLIES, ENEMIES, ANY }

const SIGHT_POLL_INTERVAL: float = 0.15
const EYE_HEIGHT: float = 1.6

@export var mode: Mode = Mode.ENTER  ## set BEFORE adding to the tree
@export var activator_filter: ActivatorFilter = ActivatorFilter.PLAYER
@export var one_shot: bool = true
@export var cooldown: float = 0.0  ## repeatable only: re-arm wait after firing
@export var fuse_delay: float = 0.0  ## seconds between condition met and firing
@export var armed: bool = true  ## false = dormant until activate()

@export_group("Sight")
@export var sight_marker: NodePath = NodePath()  ## what must be seen (falls back to self)
@export var sight_range: float = 60.0
@export var sight_dwell: float = 0.0  ## continuous seconds of LOS required

@export_group("Noise")
@export var noise_radius: float = 30.0  ## how far this trigger can hear
## Empty = any NoiseBus.NoiseType; else only the listed types register.
@export var noise_types: Array[int] = []

@export_group("Timer")
@export var timer_seconds: float = 5.0

var fire_count: int = 0
var _spent: bool = false
var _cooldown_left: float = 0.0
var _fuse_left: float = -1.0
var _pending_context: Dictionary = {}
var _timer_left: float = -1.0
var _sight_poll: float = 0.0
var _sight_dwell_acc: float = 0.0


func _ready() -> void:
	add_to_group("mission_triggers")
	monitorable = false
	monitoring = true
	collision_layer = 0
	# Layer 2 = player (allies ride it too), layer 3 = enemies.
	collision_mask = 2 | 4
	body_entered.connect(_on_body_entered)
	NoiseBus.noise_emitted.connect(_on_noise_emitted)
	if mode == Mode.TIMER and armed:
		_timer_left = timer_seconds


## Wake a dormant trigger (armed=false at author time). For TIMER mode this
## (re)starts the countdown - "arms after N seconds once activated".
func activate() -> void:
	armed = true
	if mode == Mode.TIMER:
		_timer_left = timer_seconds


func disarm() -> void:
	armed = false
	_fuse_left = -1.0
	_pending_context = {}


func is_spent() -> bool:
	return _spent


func _physics_process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)
	# Burning fuse: the condition was met; fire when it runs out.
	if _fuse_left >= 0.0:
		_fuse_left -= delta
		if _fuse_left <= 0.0:
			_fuse_left = -1.0
			var ctx := _pending_context
			_pending_context = {}
			_fire(ctx)
		return
	match mode:
		Mode.TIMER:
			if armed and not _spent and _timer_left >= 0.0:
				_timer_left -= delta
				if _timer_left <= 0.0:
					_timer_left = -1.0
					if _can_consider():
						_schedule({})
		Mode.SIGHT:
			_poll_sight(delta)


func _can_consider() -> bool:
	return armed and not _spent and _cooldown_left <= 0.0 and _fuse_left < 0.0


func _on_body_entered(body: Node3D) -> void:
	if mode != Mode.ENTER or not _can_consider():
		return
	if not _matches_filter(body):
		return
	_schedule({"activator": body})


func _matches_filter(node: Node) -> bool:
	match activator_filter:
		ActivatorFilter.PLAYER:
			return node.is_in_group("player")
		ActivatorFilter.ALLIES:
			return node.is_in_group("allies")
		ActivatorFilter.ENEMIES:
			return node.is_in_group("enemies")
		ActivatorFilter.ANY:
			return node.is_in_group("player") or node.is_in_group("allies") \
				or node.is_in_group("enemies")
	return false


## NoiseBus teams: 0 = friendly (player AND allies - the bus cannot tell them
## apart), 1 = enemy. PLAYER/ALLIES filters therefore both accept team 0.
func _noise_team_matches(source_team: int) -> bool:
	match activator_filter:
		ActivatorFilter.PLAYER, ActivatorFilter.ALLIES:
			return source_team == 0
		ActivatorFilter.ENEMIES:
			return source_team == 1
		ActivatorFilter.ANY:
			return true
	return false


func _on_noise_emitted(type: int, position: Vector3, radius: float, source_team: int) -> void:
	if mode != Mode.NOISE or not _can_consider():
		return
	if not noise_types.is_empty() and not noise_types.has(type):
		return
	if not _noise_team_matches(source_team):
		return
	var dist: float = global_position.distance_to(position)
	# Honest hearing: the sound must both carry this far (event radius) and be
	# within this trigger's own listening radius.
	if dist > noise_radius or dist > radius:
		return
	_schedule({
		"noise_type": type,
		"noise_position": position,
		"noise_radius": radius,
		"source_team": source_team,
	})


## Distance window + a real world-geometry raycast from eye height, held for
## `sight_dwell` continuous seconds.
func _poll_sight(delta: float) -> void:
	if not _can_consider():
		return
	_sight_poll -= delta
	if _sight_poll > 0.0:
		return
	_sight_poll = SIGHT_POLL_INTERVAL
	var player := GameManager.player as Node3D
	if player == null or not is_instance_valid(player):
		_sight_dwell_acc = 0.0
		return
	var marker := get_node_or_null(sight_marker) as Node3D
	var target_pos: Vector3 = marker.global_position if marker != null else global_position
	if player.global_position.distance_to(target_pos) > sight_range:
		_sight_dwell_acc = 0.0
		return
	var eye: Vector3 = player.global_position + Vector3.UP * EYE_HEIGHT
	if not CombatManager.has_line_of_sight(eye, target_pos, [player]):
		_sight_dwell_acc = 0.0
		return
	_sight_dwell_acc += SIGHT_POLL_INTERVAL
	if _sight_dwell_acc >= sight_dwell:
		_sight_dwell_acc = 0.0
		_schedule({"activator": player, "sighted_position": target_pos})


func _schedule(extra: Dictionary) -> void:
	var mode_name: String = str(Mode.keys()[mode])
	var context: Dictionary = {
		"mode": mode_name,
		"trigger": self,
		"position": global_position,
		"activator": null,
		"fire_count": fire_count + 1,
		"time_ms": Time.get_ticks_msec(),
	}
	context.merge(extra, true)
	if fuse_delay > 0.0:
		_pending_context = context
		_fuse_left = fuse_delay
	else:
		_fire(context)


func _fire(context: Dictionary) -> void:
	fire_count += 1
	if one_shot:
		_spent = true
		set_deferred("monitoring", false)
		set_physics_process(false)
	else:
		_cooldown_left = cooldown
		if mode == Mode.TIMER:
			_timer_left = timer_seconds  # repeatable timer re-arms itself
	triggered.emit(context)
