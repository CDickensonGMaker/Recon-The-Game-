## equipment_manager.gd - Manages the 5-slot equipment system
class_name EquipmentManager
extends Node

signal slot_changed(slot_index: int, slot_type: Enums.SlotType)
signal grenade_count_changed(count: int)

## SLOT CONTRACT (every system indexes on these):
## 0 = primary weapon · 1 = secondary weapon · 2 = grenade · 3 = medkit · 4 = knife
## SLOT_COUNT is the ONE place the wheel and the HUD agree on how many there are.
const SLOT_COUNT: int = 5

var current_slot: int = 0
var grenade_count: int = 2

## References
var controller: CharacterBody3D
var weapon_holder: WeaponHolder
var health_system: HealthSystem
var grenade_handler: Node  # Forward reference

## Switch state
var is_switching: bool = false
var switch_timer: float = 0.0
const SWITCH_TIME: float = 0.5
var pending_slot: int = -1

func _ready() -> void:
	pass


func setup(ctrl: CharacterBody3D, wpn: WeaponHolder, hp: HealthSystem, gren: Node = null) -> void:
	controller = ctrl
	weapon_holder = wpn
	health_system = hp
	grenade_handler = gren


func _process(delta: float) -> void:
	if not GameManager.can_player_act():
		return

	_handle_input()
	_update_switch(delta)


func _handle_input() -> void:
	if is_switching:
		return

	# On a fixed gun the kit is frozen on the mount - a slot key must not swap it off.
	if controller and "is_manning_mg" in controller and controller.is_manning_mg:
		return

	if weapon_holder and weapon_holder.is_weapon_reloading():
		return

	if health_system and health_system.is_healing:
		return

	# Fire-support menu owns the number keys while open.
	if FieldDirector.any_fire_menu_open:
		return

	if Input.is_action_just_pressed("slot_1") and current_slot != 0:
		_start_switch(0)
	elif Input.is_action_just_pressed("slot_2") and current_slot != 1:
		_start_switch(1)
	elif Input.is_action_just_pressed("slot_3") and current_slot != 2:
		_start_switch(2)
	elif Input.is_action_just_pressed("slot_4") and current_slot != 3:
		_start_switch(3)
	# Mouse wheel cycles the kit.
	elif Input.is_action_just_pressed("wheel_down"):
		_start_switch((current_slot + 1) % SLOT_COUNT)
	elif Input.is_action_just_pressed("wheel_up"):
		_start_switch((current_slot + SLOT_COUNT - 1) % SLOT_COUNT)

	_handle_slot_action()


func _handle_slot_action() -> void:
	match current_slot:
		0, 1:  # Weapons - handled by weapon_holder
			pass
		2:  # Grenade
			if grenade_handler:
				if Input.is_action_pressed("fire") and not grenade_handler.is_cooking:
					grenade_handler.start_cooking()
				elif Input.is_action_just_released("fire") and grenade_handler.is_cooking:
					grenade_handler.throw()
		3:  # Medkit - hold FIRE or INTERACT [F]
			if health_system:
				var heal_held: bool = Input.is_action_pressed("fire") or Input.is_action_pressed("interact")
				if heal_held and not health_system.is_healing:
					health_system.start_healing()
				elif not heal_held and health_system.is_healing:
					health_system.cancel_healing()
		4:  # Knife - FIRE stabs. [K] also stabs from any slot (see MeleeVerb).
			if Input.is_action_just_pressed("fire") and controller != null:
				MeleeVerb.strike(controller)


func _start_switch(new_slot: int) -> void:
	is_switching = true
	switch_timer = SWITCH_TIME
	pending_slot = new_slot

	if current_slot == 3 and health_system and health_system.is_healing:
		health_system.cancel_healing()

	# Weapon slots: drive the holder's swap now so both timers run concurrently
	if new_slot <= 1 and weapon_holder:
		weapon_holder.set_active_weapon_slot(new_slot)


func _update_switch(delta: float) -> void:
	if not is_switching:
		return

	switch_timer -= delta
	if switch_timer <= 0:
		_finish_switch()


func _finish_switch() -> void:
	is_switching = false

	current_slot = pending_slot
	pending_slot = -1

	slot_changed.emit(current_slot, get_slot_type(current_slot))


func get_slot_type(slot: int) -> Enums.SlotType:
	match slot:
		0, 1:
			return Enums.SlotType.WEAPON
		2:
			return Enums.SlotType.GRENADE
		3:
			return Enums.SlotType.MEDKIT
		4:
			return Enums.SlotType.MELEE
		_:
			return Enums.SlotType.WEAPON


func get_current_slot_type() -> Enums.SlotType:
	return get_slot_type(current_slot)


## Force switch to a slot (used for the auto-switch after grenade/medkit).
func switch_to_slot(slot: int) -> void:
	if current_slot == slot:
		return
	_start_switch(slot)


func add_grenade(count: int = 1) -> void:
	grenade_count += count
	grenade_count_changed.emit(grenade_count)


## Use grenade (called by grenade_handler)
func use_grenade() -> bool:
	if grenade_count <= 0:
		return false
	grenade_count -= 1
	grenade_count_changed.emit(grenade_count)
	return true


func get_grenade_count() -> int:
	return grenade_count


func is_weapon_slot() -> bool:
	return current_slot <= 1


func get_current_slot() -> int:
	return current_slot
