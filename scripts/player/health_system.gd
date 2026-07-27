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
const HEAL_TIME: float = 3.0

## Bandage vs medkit: one item, the context picks the treatment. Bleeding but not
## critical -> quick bandage (partial heal, wounds stay). Otherwise full treatment.
const BANDAGE_TIME: float = 1.3
const BANDAGE_HEAL_FRAC: float = 0.55
var _is_bandage: bool = false
var _heal_time_this: float = HEAL_TIME

## Healing state
var is_healing: bool = false
var heal_timer: float = 0.0

## Bleed-out system
var is_bleeding: bool = false
var bleed_timer: float = 0.0
var bleed_duration: float = 25.0  ## Seconds to heal before death
## The floor is a design invariant: even a low-HP first hit must leave a real
## window (~30s) to reach cover and patch up.
const MIN_BLEED_TIME: float = 25.0
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
	_is_bandage = is_bleeding and float(current_hp) / float(max_hp) > 0.35
	_heal_time_this = BANDAGE_TIME if _is_bandage else HEAL_TIME
	_show_medkit()
	healing_started.emit()


## Cancel healing (called when player releases fire or moves)
func cancel_healing() -> void:
	if is_healing:
		_interrupt_healing()


func _update_healing(delta: float) -> void:
	if controller and controller.is_moving():
		_interrupt_healing()
		return

	heal_timer += delta
	healing_progress.emit(heal_timer / _heal_time_this)

	if heal_timer >= _heal_time_this:
		_finish_healing()


func _interrupt_healing() -> void:
	is_healing = false
	_hide_medkit()
	healing_interrupted.emit()


func _finish_healing() -> void:
	is_healing = false
	_hide_medkit()
	health_packs -= 1

	# Stop bleeding either way - that's the point of reaching for it.
	is_bleeding = false
	bleeding_stopped.emit()

	if _is_bandage:
		# Quick bandage: partial heal, limb wounds stay.
		current_hp = maxi(current_hp, int(float(max_hp) * BANDAGE_HEAL_FRAC))
	else:
		# Full treatment: full heal, and it clears limb wounds.
		current_hp = max_hp
		if controller and controller.has_method("clear_wounds"):
			controller.clear_wounds()

	healing_finished.emit()
	health_changed.emit(current_hp, max_hp)
	health_pack_changed.emit(health_packs)
	if controller and controller.has_method("_field_toast"):
		controller._field_toast("BANDAGED - BLEEDING STOPPED" if _is_bandage else "FULL TREATMENT - BACK IN THE FIGHT")

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


## Take damage; starts or pressures the bleed clock.
func take_damage(amount: int, _damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL, _attacker: Node = null, zone: String = "BODY") -> int:
	if is_healing:
		_interrupt_healing()

	# A headshot is final (Summoner's ruling 2026-07-27, ADR-016 Amendment D).
	# It bypasses the difficulty scalar AND the medic revive window: force_death,
	# never _die, or a headshot would merely put the player in bleed-out.
	if Hitzone.zone_name_is_fatal(zone):
		var lethal: int = current_hp
		current_hp = 0
		health_changed.emit(current_hp, max_hp)
		force_death()
		return lethal

	var actual_damage := int(float(amount) * GameSettings.player_damage_mult())
	current_hp -= actual_damage

	if current_hp < 0:
		current_hp = 0

	health_changed.emit(current_hp, max_hp)

	if current_hp <= 0:
		_die()
		return actual_damage

	if not is_bleeding:
		var hp_percent := float(current_hp) / float(max_hp)
		bleed_duration = lerp(MIN_BLEED_TIME, MAX_BLEED_TIME, hp_percent)
		is_bleeding = true
		bleed_timer = bleed_duration
		bleeding_started.emit(bleed_duration)
	else:
		# Further hits pressure the clock, but it can NEVER collapse below a
		# heal-able window (the bandage channel alone is 1.3s).
		var time_reduction := amount * 0.15
		bleed_timer = max(8.0, bleed_timer - time_reduction)
		bleeding_progress.emit(bleed_timer)

	return actual_damage


## Downed/revive layer. A revive handler (SquadSystem) may intercept death: the
## player goes DOWNED and a medic gets a window to reach him.
var revive_handler: Node = null
var is_downed: bool = false
const DOWNED_BLEED_SECONDS: float = 30.0


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


## Medic completed the channel: back on your feet AT FULL HEALTH, moving
## (Summoner decree 2026-07-18 - a half-restored revive reads as still-dead).
func revive() -> void:
	is_downed = false
	current_hp = max_hp
	is_bleeding = false
	bleeding_stopped.emit()
	health_changed.emit(current_hp, max_hp)
	downed_ended.emit(true)


func is_dead() -> bool:
	return current_hp <= 0 and not is_downed
