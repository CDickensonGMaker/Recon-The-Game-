## grenade_handler.gd - Handles grenade cooking and throwing
class_name GrenadeHandler
extends Node3D

signal grenade_thrown
signal grenade_cooking(time: float)
signal grenade_exploded_in_hand

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

## Grenade viewmodel
var grenade_viewmodel: Node3D = null
const GRENADE_VIEWMODEL_PATH: String = "res://scenes/weapons/m26_grenade_viewmodel.tscn"
const GRENADE_HOLD_POSITION: Vector3 = Vector3(0.3, -0.3, -0.4)

func _ready() -> void:
	_load_grenade_viewmodel()


func setup(ctrl: CharacterBody3D, equip: EquipmentManager) -> void:
	controller = ctrl
	equipment_manager = equip


func _load_grenade_viewmodel() -> void:
	if ResourceLoader.exists(GRENADE_VIEWMODEL_PATH):
		var scene: PackedScene = load(GRENADE_VIEWMODEL_PATH)
		if scene:
			grenade_viewmodel = scene.instantiate()
			grenade_viewmodel.visible = false
			grenade_viewmodel.position = GRENADE_HOLD_POSITION
			grenade_viewmodel.scale = Vector3.ONE * 0.03  # Match weapon scale
			add_child(grenade_viewmodel)


func _show_grenade() -> void:
	if grenade_viewmodel:
		grenade_viewmodel.visible = true


func _hide_grenade() -> void:
	if grenade_viewmodel:
		grenade_viewmodel.visible = false


func _process(delta: float) -> void:
	if not is_cooking:
		return

	cook_timer += delta
	grenade_cooking.emit(cook_timer)

	# Check if grenade explodes in hand
	if cook_timer >= FUSE_TIME:
		_explode_in_hand()


## Start cooking the grenade (fuse begins)
func start_cooking() -> void:
	if not equipment_manager or equipment_manager.get_grenade_count() <= 0:
		return

	is_cooking = true
	cook_timer = 0.0
	_show_grenade()


## Throw the grenade
func throw() -> void:
	if not is_cooking:
		return

	is_cooking = false
	_hide_grenade()

	# Use grenade from inventory
	if not equipment_manager.use_grenade():
		return

	# Spawn grenade
	var grenade := Grenade.new()
	grenade.remaining_fuse = FUSE_TIME - cook_timer
	grenade.owner_entity = controller

	# Calculate throw direction and force
	var aim_dir: Vector3 = controller.get_aim_direction()
	var throw_dir: Vector3 = (aim_dir + Vector3.UP * THROW_UPWARD).normalized()
	grenade.initial_velocity = throw_dir * THROW_FORCE

	# Spawn at camera position
	get_tree().current_scene.add_child(grenade)
	grenade.global_position = controller.get_camera_position() + aim_dir * 0.5

	grenade_thrown.emit()

	# Auto-switch back to primary
	equipment_manager.switch_to_slot(0)


## Grenade explodes in hand (player held it too long)
func _explode_in_hand() -> void:
	is_cooking = false
	_hide_grenade()
	equipment_manager.use_grenade()

	# Damage player directly
	var health_system := controller.get_node_or_null("HealthSystem") as HealthSystem
	if health_system:
		health_system.take_damage(100, Enums.DamageType.EXPLOSIVE, controller)

	grenade_exploded_in_hand.emit()

	# Auto-switch back to primary (if still alive)
	equipment_manager.switch_to_slot(0)


## Get cook progress (0-1)
func get_cook_progress() -> float:
	if not is_cooking:
		return 0.0
	return cook_timer / FUSE_TIME


## Get remaining fuse time
func get_remaining_fuse() -> float:
	return maxf(0.0, FUSE_TIME - cook_timer)
