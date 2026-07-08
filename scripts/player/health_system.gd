## health_system.gd - Player health with bleed-out mechanic
class_name HealthSystem
extends Node

signal health_changed(current: int, maximum: int)
signal health_pack_changed(count: int)
signal died
signal downed_started(bleed_seconds: float)
signal downed_ended(revived: bool)
signal healing_started
signal healing_progress(percent: float)
signal healing_interrupted
signal healing_finished
signal bleeding_started(bleed_time: float)
signal bleeding_progress(time_remaining: float)
signal bleeding_stopped

## Health stats
@export var max_hp: int = 100
var current_hp: int = 100

## Health pack system
var health_packs: int = 3
const HEAL_AMOUNT: int = 100  ## Full heal when you use a medkit
const HEAL_TIME: float = 3.0

## Healing state
var is_healing: bool = false
var heal_timer: float = 0.0

## Bleed-out system
var is_bleeding: bool = false
var bleed_timer: float = 0.0
var bleed_duration: float = 20.0  ## Seconds to heal before death
const MIN_BLEED_TIME: float = 10.0
const MAX_BLEED_TIME: float = 30.0

## Reference to player controller for movement check
var controller: Node = null

## Reference to equipment manager for auto-switch
var equipment_manager = null

## Medkit viewmodel
var medkit_viewmodel: Node3D = null
const MEDKIT_VIEWMODEL_PATH: String = "res://scenes/weapons/medkit_viewmodel.tscn"
const MEDKIT_HOLD_POSITION: Vector3 = Vector3(0.3, -0.3, -0.4)

func _ready() -> void:
	current_hp = max_hp


func _process(delta: float) -> void:
	if is_healing:
		_update_healing(delta)

	if is_bleeding and not is_healing:
		_update_bleeding(delta)


func setup(player_controller: Node, equip_manager) -> void:
	controller = player_controller
	equipment_manager = equip_manager
	_load_medkit_viewmodel()


func _load_medkit_viewmodel() -> void:
	if not controller:
		return
	# Get camera from controller (Player -> Head -> Camera3D)
	var camera: Camera3D = controller.get_node_or_null("Head/Camera3D")
	if not camera:
		return
	if ResourceLoader.exists(MEDKIT_VIEWMODEL_PATH):
		var scene: PackedScene = load(MEDKIT_VIEWMODEL_PATH)
		if scene:
			medkit_viewmodel = scene.instantiate()
			medkit_viewmodel.visible = false
			medkit_viewmodel.position = MEDKIT_HOLD_POSITION
			camera.add_child(medkit_viewmodel)


func _show_medkit() -> void:
	if medkit_viewmodel:
		medkit_viewmodel.visible = true


func _hide_medkit() -> void:
	if medkit_viewmodel:
		medkit_viewmodel.visible = false


## Start healing (called when player activates medkit from equipment)
func start_healing() -> void:
	if health_packs <= 0:
		return
	if is_healing:
		return
	if current_hp >= max_hp and not is_bleeding:
		return

	# Must be nearly stationary
	if controller and controller.is_moving():
		return

	is_healing = true
	heal_timer = 0.0
	_show_medkit()
	healing_started.emit()


## Cancel healing (called when player releases fire or moves)
func cancel_healing() -> void:
	if is_healing:
		_interrupt_healing()


func _update_healing(delta: float) -> void:
	# Check movement interrupt
	if controller and controller.is_moving():
		_interrupt_healing()
		return

	heal_timer += delta
	healing_progress.emit(heal_timer / HEAL_TIME)

	if heal_timer >= HEAL_TIME:
		_finish_healing()


func _interrupt_healing() -> void:
	is_healing = false
	_hide_medkit()
	healing_interrupted.emit()


func _finish_healing() -> void:
	is_healing = false
	_hide_medkit()
	health_packs -= 1

	# W37: a full medkit treatment clears limb wounds too.
	if controller and controller.has_method("clear_wounds"):
		controller.clear_wounds()

	# Stop bleeding and restore health
	is_bleeding = false
	bleeding_stopped.emit()

	current_hp = max_hp  ## Full heal

	healing_finished.emit()
	health_changed.emit(current_hp, max_hp)
	health_pack_changed.emit(health_packs)

	# Auto-switch back to primary
	if equipment_manager:
		equipment_manager.switch_to_slot(0)


func _update_bleeding(delta: float) -> void:
	bleed_timer -= delta
	bleeding_progress.emit(bleed_timer)

	if bleed_timer <= 0:
		_bleed_out()


func _bleed_out() -> void:
	is_bleeding = false
	current_hp = 0
	health_changed.emit(current_hp, max_hp)
	_die()


## Take damage - now triggers bleed state
func take_damage(amount: int, _damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL, _attacker: Node = null) -> int:
	if is_healing:
		_interrupt_healing()

	var actual_damage := amount
	current_hp -= actual_damage

	# Clamp HP
	if current_hp < 0:
		current_hp = 0

	health_changed.emit(current_hp, max_hp)

	# Check for instant death (massive damage or already critical)
	if current_hp <= 0:
		_die()
		return actual_damage

	# Start or reset bleeding
	if not is_bleeding:
		# Calculate bleed time based on remaining HP
		var hp_percent := float(current_hp) / float(max_hp)
		bleed_duration = lerp(MIN_BLEED_TIME, MAX_BLEED_TIME, hp_percent)
		is_bleeding = true
		bleed_timer = bleed_duration
		bleeding_started.emit(bleed_duration)
	else:
		# Already bleeding - reduce remaining time based on damage
		var time_reduction := amount * 0.5  # Lose 0.5 seconds per damage point
		bleed_timer = max(3.0, bleed_timer - time_reduction)  # Minimum 3 seconds
		bleeding_progress.emit(bleed_timer)

	return actual_damage


## Heal without using health pack (for future NPC resupply)
func heal(amount: int) -> int:
	var actual_heal := mini(amount, max_hp - current_hp)
	current_hp += actual_heal

	# Stop bleeding if healed to full
	if current_hp >= max_hp:
		is_bleeding = false
		bleeding_stopped.emit()

	health_changed.emit(current_hp, max_hp)
	return actual_heal


## Stabilize without full heal (stops bleeding but doesn't restore HP)
func stabilize() -> void:
	is_bleeding = false
	bleeding_stopped.emit()


## Downed/revive layer (W17). A revive handler (SquadSystem) may intercept
## death: player goes DOWNED and a medic gets a window to reach them.
var revive_handler: Node = null
var is_downed: bool = false
const DOWNED_BLEED_SECONDS: float = 30.0


## Die
func _die() -> void:
	if not is_downed and revive_handler != null and is_instance_valid(revive_handler) \
			and revive_handler.has_method("can_revive") and revive_handler.can_revive():
		is_downed = true
		is_bleeding = false
		downed_started.emit(DOWNED_BLEED_SECONDS)
		revive_handler.begin_revive(self)
		return
	force_death()


## The real end (no medic, timer out, or no handler).
func force_death() -> void:
	is_downed = false
	is_bleeding = false
	died.emit()
	GameManager.on_player_death()


## Medic completed the channel: back on your feet.
func revive(restored_hp: int) -> void:
	is_downed = false
	current_hp = mini(restored_hp, max_hp)
	is_bleeding = false
	bleeding_stopped.emit()
	health_changed.emit(current_hp, max_hp)
	downed_ended.emit(true)


## Check if dead
func is_dead() -> bool:
	return current_hp <= 0 and not is_downed


## Check if critically wounded (bleeding)
func is_critical() -> bool:
	return is_bleeding


## Add health pack to inventory
func add_health_pack(count: int = 1) -> void:
	health_packs += count
	health_pack_changed.emit(health_packs)


## Get health pack count
func get_health_pack_count() -> int:
	return health_packs


## Get bleed time remaining
func get_bleed_time_remaining() -> float:
	return bleed_timer if is_bleeding else 0.0
