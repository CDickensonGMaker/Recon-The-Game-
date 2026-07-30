## grenade_handler.gd - Handles grenade cooking and throwing
class_name GrenadeHandler
extends Node3D

signal grenade_cooking(time: float)

## Grenade configuration
const FUSE_TIME: float = 4.0
const THROW_FORCE: float = 15.0
const THROW_UPWARD: float = 0.3

## State
var is_cooking: bool = false
var cook_timer: float = 0.0

## References
var controller: CharacterBody3D
var equipment_manager: EquipmentManager

## Grenade viewmodel. Driven by the shared ItemViewmodel so the clips an authored GLB
## carries actually PLAY - this used to be a bare Node3D toggled `visible`, which renders
## even a perfect export in its bind pose.
var grenade_viewmodel: ItemViewmodel = null
const GRENADE_VIEWMODEL_PATH: String = "res://scenes/weapons/m26_grenade_viewmodel.tscn"
const GRENADE_HOLD_POSITION: Vector3 = Vector3(0.3, -0.3, -0.4)
## Pin and throw are separate beats of gameplay - hold to cook, release to throw - so the
## item vocabulary's single `fire` cannot express both. `fire` is the pin pull.
const CLIP_THROW: StringName = &"throw"
## The grenade slot in the EquipmentManager contract.
const SLOT: int = 2

func _ready() -> void:
	_load_grenade_viewmodel()


func setup(ctrl: CharacterBody3D, equip: EquipmentManager) -> void:
	controller = ctrl
	equipment_manager = equip
	# _ready ran before setup, so the viewmodel was built without a camera for the lens.
	if grenade_viewmodel == null:
		_load_grenade_viewmodel()
	if equip != null and not equip.slot_changed.is_connected(_on_slot_changed):
		equip.slot_changed.connect(_on_slot_changed)


func _on_slot_changed(slot_index: int, _slot_type: Enums.SlotType) -> void:
	if slot_index == SLOT:
		on_slot_entered()
	else:
		on_slot_exited()


func _load_grenade_viewmodel() -> void:
	var cam: Camera3D = controller.get_node_or_null("Head/Camera3D") as Camera3D 		if controller != null else null
	grenade_viewmodel = ItemViewmodel.create(self, GRENADE_VIEWMODEL_PATH,
		GRENADE_HOLD_POSITION, cam, "m26_grenade")


## Selecting the slot brings the grenade UP, the way drawing a rifle does. It used to
## appear only once you already held the fire button, so the deploy was never seen.
func on_slot_entered() -> void:
	if grenade_viewmodel != null and equipment_manager != null 			and equipment_manager.get_grenade_count() > 0:
		grenade_viewmodel.deploy()


func on_slot_exited() -> void:
	if grenade_viewmodel != null and not is_cooking:
		grenade_viewmodel.stow()


func _show_grenade() -> void:
	if grenade_viewmodel == null:
		return
	if not grenade_viewmodel.visible:
		grenade_viewmodel.deploy()
	# `fire` is the pin pull; the cook pose is wherever it leaves the hand.
	grenade_viewmodel.play_action()


func _hide_grenade() -> void:
	if grenade_viewmodel == null:
		return
	# The grenade has left the hand: play the throw out and then put the hand away,
	# never settle back to a held-grenade idle.
	grenade_viewmodel.play_action_then_stow(CLIP_THROW)


func _process(delta: float) -> void:
	if not is_cooking:
		return

	cook_timer += delta
	grenade_cooking.emit(cook_timer)

	if cook_timer >= FUSE_TIME:
		_explode_in_hand()


## Start cooking the grenade (fuse begins)
func start_cooking() -> void:
	if not equipment_manager or equipment_manager.get_grenade_count() <= 0:
		return

	is_cooking = true
	cook_timer = 0.0
	_show_grenade()


func throw() -> void:
	if not is_cooking:
		return

	is_cooking = false
	_hide_grenade()

	if not equipment_manager.use_grenade():
		return

	# The fuse keeps running: only the time left after cooking is thrown with it.
	var grenade := Grenade.new()
	grenade.remaining_fuse = FUSE_TIME - cook_timer
	grenade.owner_entity = controller

	var aim_dir: Vector3 = controller.get_aim_direction()
	var throw_dir: Vector3 = (aim_dir + Vector3.UP * THROW_UPWARD).normalized()
	grenade.initial_velocity = throw_dir * THROW_FORCE

	get_tree().current_scene.add_child(grenade)
	grenade.global_position = controller.get_camera_position() + aim_dir * 0.5

	# Auto-switch back to primary.
	equipment_manager.switch_to_slot(0)


## Grenade explodes in hand (player held it too long)
func _explode_in_hand() -> void:
	is_cooking = false
	_hide_grenade()
	equipment_manager.use_grenade()

	var health_system := controller.get_node_or_null("HealthSystem") as HealthSystem
	if health_system:
		health_system.take_damage(100, Enums.DamageType.EXPLOSIVE, controller)

	# Auto-switch back to primary, if still alive.
	equipment_manager.switch_to_slot(0)


## Cook progress, 0-1. Drives the HUD fuse ring.
func get_cook_progress() -> float:
	if not is_cooking:
		return 0.0
	return cook_timer / FUSE_TIME
