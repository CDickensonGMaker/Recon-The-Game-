## weapon_holder.gd - Handles weapon firing, reload, ADS, and weapon switching
class_name WeaponHolder
extends Node3D

signal weapon_fired
signal weapon_reloaded
signal magazine_changed(current_ammo: int, spare_magazines: int)
signal weapon_switched(weapon_data: WeaponData)
signal ads_changed(is_aiming: bool)
signal reload_started
signal reload_progress(percent: float)
signal reload_cancelled
signal switch_started
signal switch_progress(percent: float)

## References
var camera: Camera3D
var controller: Node  # Player root node
var equipment_manager: EquipmentManager  # To check if on weapon slot

## Weapon slots
var primary_weapon: WeaponData = null
var secondary_weapon: WeaponData = null
var current_slot: int = 0  ## 0 = primary, 1 = secondary

## Ammo tracking per weapon [current_magazine, spare_magazines]
var primary_ammo: Array[int] = [30, 4]
var secondary_ammo: Array[int] = [7, 3]

## Current weapon state
var current_weapon: WeaponData = null
var current_ammo: int = 30
var spare_magazines: int = 4

## ADS state
var is_aiming: bool = false
var ads_transition: float = 0.0  ## 0 = hip, 1 = fully ADS
const ADS_SPEED: float = 10.0
const BASE_FOV: float = 75.0

## Firing state
var is_firing: bool = false
var can_fire: bool = true
var fire_timer: float = 0.0

## Reload state
var is_reloading: bool = false
var reload_timer: float = 0.0

## Weapon switch state
var is_switching: bool = false
var switch_timer: float = 0.0
const SWITCH_TIME: float = 0.5

## Weapon model
var weapon_model: Node3D = null

## Viewmodel pitch compensation (prevents floor clipping when looking down)
const PITCH_OFFSET_ENABLED: bool = true
const PITCH_OFFSET_START: float = -20.0  ## Start offsetting at this pitch (degrees)
const PITCH_OFFSET_MAX: float = -70.0  ## Maximum pitch before full offset
const PITCH_OFFSET_UP: float = 0.8  ## How much to move weapon up
const PITCH_OFFSET_FORWARD: float = 0.5  ## How much to move weapon forward

## Raycasting
var ray_origin: Vector3
var ray_end: Vector3

## Tracer settings
const TRACER_ENABLED: bool = true
const TRACER_COLOR: Color = Color(1.0, 0.85, 0.4, 1.0)  ## Yellow tracer

## Viewmodel scaling
const BASE_VIEWMODEL_SCALE: float = 0.1  ## Base scale applied to all viewmodels

func _ready() -> void:
	# Get references from parent hierarchy
	camera = get_parent() as Camera3D
	# Controller is the root Player node - go up: WeaponHolder -> Camera3D -> Head -> Player
	controller = get_parent().get_parent().get_parent()

	# Load default weapons
	primary_weapon = load("res://data/weapons/thompson.tres")
	secondary_weapon = load("res://data/weapons/m1911.tres")
	current_weapon = primary_weapon
	current_ammo = primary_ammo[0]
	spare_magazines = primary_ammo[1]
	magazine_changed.emit(current_ammo, spare_magazines)

	# Load initial weapon model
	_load_weapon_model(current_weapon)


func _process(delta: float) -> void:
	if not GameManager.can_player_act():
		return

	_handle_input()
	_update_ads(delta)
	_update_firing(delta)
	_update_reload(delta)
	_update_switch(delta)
	_update_weapon_position(delta)


func _handle_input() -> void:
	# Slot selection is owned by EquipmentManager (drives set_active_weapon_slot)

	# Can't do anything while switching
	if is_switching:
		return

	# Block input if not on weapon slot (grenade/medkit selected)
	var on_weapon_slot: bool = not equipment_manager or equipment_manager.is_weapon_slot()
	if not on_weapon_slot:
		is_aiming = false
		is_firing = false
		return

	# ADS input
	is_aiming = Input.is_action_pressed("aim") and not is_reloading

	# Fire input
	if Input.is_action_pressed("fire") and not is_reloading:
		_try_fire()
	else:
		is_firing = false

	# Reload input
	if Input.is_action_just_pressed("reload") and not is_reloading:
		_start_reload()


func _update_ads(delta: float) -> void:
	var target := 1.0 if is_aiming else 0.0
	ads_transition = lerp(ads_transition, target, delta * ADS_SPEED)

	# FOV stays constant at BASE_FOV for consistency with viewmodel editor
	# (ads_fov zoom disabled for now)
	if camera:
		camera.fov = BASE_FOV

	# Apply movement speed modifier to controller
	if controller and current_weapon:
		var speed_mult: float = lerpf(1.0, current_weapon.ads_move_mult, ads_transition)
		# Speed modifier is applied through equipment_manager


func _update_firing(delta: float) -> void:
	if fire_timer > 0:
		fire_timer -= delta
		if fire_timer <= 0:
			can_fire = true


func _try_fire() -> void:
	if not can_fire or is_reloading or is_switching:
		return

	if current_ammo <= 0:
		# Click sound / empty magazine
		return

	# Check firing mode
	match current_weapon.firing_mode:
		Enums.FiringMode.SEMI_AUTO:
			if not Input.is_action_just_pressed("fire"):
				return
			_fire_shot()
		Enums.FiringMode.FULL_AUTO:
			_fire_shot()
		Enums.FiringMode.BOLT_ACTION:
			if not Input.is_action_just_pressed("fire"):
				return
			_fire_shot()
		Enums.FiringMode.BURST:
			if not Input.is_action_just_pressed("fire"):
				return
			_fire_shot()


func _fire_shot() -> void:
	current_ammo -= 1
	can_fire = false
	fire_timer = current_weapon.get_fire_delay()

	# Calculate spread
	var spread := current_weapon.get_spread(ads_transition)
	var spread_rad := deg_to_rad(spread)

	# Get fire direction with spread
	var aim_dir: Vector3 = controller.get_aim_direction()
	var spread_x := randf_range(-spread_rad, spread_rad)
	var spread_y := randf_range(-spread_rad, spread_rad)

	var right: Vector3 = aim_dir.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(aim_dir).normalized()

	var final_dir: Vector3 = (aim_dir + right * tan(spread_x) + up * tan(spread_y)).normalized()

	# Raycast for hit detection
	var origin: Vector3 = controller.get_camera_position()
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + final_dir * current_weapon.max_range,
		1 | 4 | 64  # World, enemies, enemy hurtboxes
	)
	query.exclude = [controller]

	var result := space_state.intersect_ray(query)

	# Spawn bullet tracer
	if TRACER_ENABLED:
		var muzzle_pos: Vector3 = _get_muzzle_position()
		NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, muzzle_pos, 0)
		var tracer_end: Vector3
		if result:
			tracer_end = result.position
		else:
			tracer_end = origin + final_dir * current_weapon.max_range
		BulletTracer.spawn_tracer(get_tree().current_scene, muzzle_pos, tracer_end, TRACER_COLOR)

	if result:
		var hit_collider: Object = result.collider
		if hit_collider:
			# Check if it's an enemy, hitzone, or hurtbox
			var damage_target: Node = null
			var damage_multiplier: float = 1.0
			var zone_name: String = "BODY"

			# Check for hitzone (body part specific)
			if hit_collider is Hitzone:
				var hitzone := hit_collider as Hitzone
				damage_target = hitzone.owner_entity
				damage_multiplier = hitzone.get_damage_multiplier()
				zone_name = hitzone.get_zone_name()
			elif hit_collider is Node and (hit_collider as Node).is_in_group("enemies"):
				damage_target = hit_collider as Node
			elif hit_collider is Node and (hit_collider as Node).get_parent() and (hit_collider as Node).get_parent().is_in_group("enemies"):
				damage_target = (hit_collider as Node).get_parent()

			if damage_target and damage_target.has_method("take_damage"):
				var base_damage := current_weapon.roll_damage()
				var final_damage := int(base_damage * damage_multiplier)
				damage_target.take_damage(final_damage, current_weapon.damage_type, controller)

				# Print hit feedback (debug)
				if zone_name == "HEAD":
					print("[HIT] HEADSHOT! %d damage" % final_damage)
				else:
					print("[HIT] %s - %d damage" % [zone_name, final_damage])

		# TODO: Impact effect at result.position

	# Apply recoil
	var recoil_mult: float = lerpf(1.0, 0.5, ads_transition)  # Less recoil when ADS
	controller.apply_recoil(
		current_weapon.recoil_vertical * recoil_mult,
		current_weapon.recoil_horizontal * recoil_mult
	)

	# Update ammo tracking
	if current_slot == 0:
		primary_ammo[0] = current_ammo
	else:
		secondary_ammo[0] = current_ammo

	weapon_fired.emit()
	magazine_changed.emit(current_ammo, spare_magazines)


func _start_reload() -> void:
	if spare_magazines <= 0:
		return
	if current_ammo >= current_weapon.magazine_size:
		return

	is_reloading = true
	reload_timer = current_weapon.reload_time
	is_aiming = false
	reload_started.emit()


func _update_reload(delta: float) -> void:
	if not is_reloading:
		return

	reload_timer -= delta
	var progress: float = 1.0 - (reload_timer / current_weapon.reload_time)
	reload_progress.emit(progress)

	if reload_timer <= 0:
		_finish_reload()


func _finish_reload() -> void:
	is_reloading = false
	spare_magazines -= 1
	current_ammo = current_weapon.magazine_size

	# Update ammo tracking
	if current_slot == 0:
		primary_ammo[0] = current_ammo
		primary_ammo[1] = spare_magazines
	else:
		secondary_ammo[0] = current_ammo
		secondary_ammo[1] = spare_magazines

	weapon_reloaded.emit()
	magazine_changed.emit(current_ammo, spare_magazines)


## Called by EquipmentManager when the active slot changes to a weapon slot.
## EquipmentManager gates input during reload/heal, so no reload check here.
func set_active_weapon_slot(new_slot: int) -> void:
	if new_slot == current_slot or is_switching:
		return
	_start_weapon_switch(new_slot)


func _start_weapon_switch(new_slot: int) -> void:
	# Save current ammo state
	if current_slot == 0:
		primary_ammo[0] = current_ammo
		primary_ammo[1] = spare_magazines
	else:
		secondary_ammo[0] = current_ammo
		secondary_ammo[1] = spare_magazines

	is_switching = true
	switch_timer = SWITCH_TIME
	current_slot = new_slot
	is_aiming = false
	switch_started.emit()


func _update_switch(delta: float) -> void:
	if not is_switching:
		return

	switch_timer -= delta
	var progress: float = 1.0 - (switch_timer / SWITCH_TIME)
	switch_progress.emit(progress)

	if switch_timer <= 0:
		_finish_switch()


func _finish_switch() -> void:
	is_switching = false

	# Load new weapon data
	if current_slot == 0:
		current_weapon = primary_weapon
		current_ammo = primary_ammo[0]
		spare_magazines = primary_ammo[1]
	else:
		current_weapon = secondary_weapon
		current_ammo = secondary_ammo[0]
		spare_magazines = secondary_ammo[1]

	# Load the new weapon model
	_load_weapon_model(current_weapon)

	weapon_switched.emit(current_weapon)
	magazine_changed.emit(current_ammo, spare_magazines)


func _update_weapon_position(delta: float) -> void:
	if not weapon_model or not current_weapon:
		return

	# Lerp between hip and ADS positions
	var target_pos: Vector3 = current_weapon.hip_position.lerp(current_weapon.ads_position, ads_transition)
	var target_rot: Vector3 = current_weapon.hip_rotation.lerp(current_weapon.ads_rotation, ads_transition)

	# Apply pitch compensation to prevent floor clipping when looking down
	if PITCH_OFFSET_ENABLED and camera:
		# Get pitch from the Head node (camera's grandparent handles vertical look)
		var head_node: Node3D = camera.get_parent() as Node3D
		if head_node:
			var head_pitch: float = rad_to_deg(head_node.rotation.x)

			# Only offset when looking down past threshold
			if head_pitch < PITCH_OFFSET_START:
				# Calculate how far into the offset range we are (0-1)
				var offset_range: float = PITCH_OFFSET_START - PITCH_OFFSET_MAX
				var pitch_factor: float = clampf((PITCH_OFFSET_START - head_pitch) / offset_range, 0.0, 1.0)

				# Apply offset - move weapon up and forward
				target_pos.y += PITCH_OFFSET_UP * pitch_factor
				target_pos.z -= PITCH_OFFSET_FORWARD * pitch_factor

	weapon_model.position = weapon_model.position.lerp(target_pos, delta * ADS_SPEED)
	weapon_model.rotation_degrees = weapon_model.rotation_degrees.lerp(target_rot, delta * ADS_SPEED)


## Load a weapon model from the weapon data
func _load_weapon_model(weapon_data: WeaponData) -> void:
	# Remove old model
	if weapon_model:
		weapon_model.queue_free()
		weapon_model = null

	# Load new model if path exists
	if weapon_data and not weapon_data.model_path.is_empty():
		var scene := load(weapon_data.model_path)
		if scene:
			weapon_model = scene.instantiate()
			add_child(weapon_model)

			# Set initial position and rotation from weapon data
			weapon_model.position = weapon_data.hip_position
			weapon_model.rotation_degrees = weapon_data.hip_rotation
			# Scale is baked into viewmodel scene - don't override here


## Get current ADS amount for other systems
func get_ads_amount() -> float:
	return ads_transition


## Check if currently reloading
func is_weapon_reloading() -> bool:
	return is_reloading


## Check if currently switching weapons
func is_weapon_switching() -> bool:
	return is_switching


## Get reload progress (0-1)
func get_reload_progress() -> float:
	if not is_reloading:
		return 0.0
	return 1.0 - (reload_timer / current_weapon.reload_time)


## Get the muzzle position for tracer spawning
func _get_muzzle_position() -> Vector3:
	if weapon_model:
		# Try to find MuzzlePoint marker in the weapon model
		var muzzle: Node3D = weapon_model.get_node_or_null("MuzzlePoint")
		if muzzle:
			return muzzle.global_position

		# Fallback: estimate muzzle position in front of weapon
		return weapon_model.global_position + weapon_model.global_transform.basis.z * -0.5

	# Ultimate fallback: use camera position
	return controller.get_camera_position()
