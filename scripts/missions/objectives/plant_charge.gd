## plant_charge.gd - Objective: hold interact near the target to plant a
## demolition charge (NS08). The vulnerability-window beat.
class_name PlantCharge
extends ObjectiveSensor

signal plant_progress(fraction: float)
signal charge_planted(at_position: Vector3)

@export var interact_radius: float = 3.5
@export var plant_seconds: float = 4.0

## W52: some targets are wired. The point man calls it; Demolitions defuses
## as part of the plant. Undetected trap = it goes off in your face.
var is_trapped: bool = false
var trap_detected: bool = false

var _progress: float = 0.0
var _trap_checked: bool = false


func _check_trap() -> void:
	if _trap_checked:
		return
	_trap_checked = true
	if not is_trapped:
		return
	# Point man nearby spots the wire; Demolitions skill always spots it.
	var spotted: bool = CampaignState.player_skill("demolitions") > 0
	if not spotted:
		for a in get_tree().get_nodes_in_group("allies"):
			var ally := a as AllyBase
			if ally and not ally.is_dead() and str(ally.member.get("mos", "")) == "POINT" \
					and ally.global_position.distance_to(global_position) < 20.0:
				spotted = true
				break
	if spotted:
		trap_detected = true
		plant_seconds += 2.0  # careful hands
		if director:
			director.toast.emit("WIRE ON THE TARGET - CUTTING IT FIRST")


func _physics_process(delta: float) -> void:
	if is_complete():
		set_physics_process(false)
		return
	var player := _find_player()
	if player == null:
		return
	var in_range: bool = player.global_position.distance_to(global_position) <= interact_radius
	if in_range and Input.is_action_pressed("interact") and GameManager.can_player_act():
		advance_plant(delta)
	elif _progress > 0.0:
		_progress = 0.0
		plant_progress.emit(0.0)


## Extracted so tests/autopilots can drive planting without input injection.
func advance_plant(delta: float) -> void:
	if is_complete():
		return
	_check_trap()
	_progress += delta / plant_seconds
	plant_progress.emit(clampf(_progress, 0.0, 1.0))
	if _progress >= 1.0:
		# W52: sprung trap - it still completes, but you pay for it.
		if is_trapped and not trap_detected:
			var player := _find_player()
			if player and player.has_method("take_damage"):
				player.take_damage(40, Enums.DamageType.EXPLOSIVE, null)
			NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, global_position, 1)
			if director:
				director.toast.emit("BOOBY TRAP! CHECK YOURSELF-")
		charge_planted.emit(global_position)
		complete()
		set_physics_process(false)
