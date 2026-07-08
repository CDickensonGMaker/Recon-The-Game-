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

## R09: rare stoppage - a bad round jams the action. No bang, needs a manual
## clear (tap reload) instead of a normal fire cycle.
var is_jammed: bool = false
var _clearing_jam: bool = false
signal weapon_jammed

## R52: idle weapon sway, tightened by ADS and killed almost entirely by
## holding your breath (player.gd: is_holding_breath).
var _sway_time: float = 0.0

## R57: a captured enemy weapon in the primary slot sounds friendly to their
## side at range (NoiseBus team match) - visual detection still works fine.
var primary_is_captured: bool = false


func equip_captured_weapon(data: WeaponData) -> void:
	if data == null:
		return
	primary_weapon = data
	primary_ammo = [data.magazine_size, 3]
	primary_is_captured = true
	if current_slot == 0:
		current_weapon = primary_weapon
		current_ammo = primary_ammo[0]
		spare_magazines = primary_ammo[1]
		_load_weapon_model(current_weapon)
		weapon_switched.emit(current_weapon)
		magazine_changed.emit(current_ammo, spare_magazines)

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

	# Load default weapons. Default primary is the Thompson: its viewmodel is the
	# one that's actually rigged, and the .45 report/bolt-clatter audio matches it.
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

	# Quake 3 timestep cap: a frame hitch must not credit a burst of fire.
	var dt: float = minf(delta, 0.066)

	# Tick the action clock BEFORE input. fire_timer may go negative; the
	# remainder is sub-frame credit toward the next round, which is what makes
	# average RPM framerate-independent (the old model quantized every shot to a
	# frame boundary and dropped the remainder, collapsing every full-auto to
	# ~600 RPM at 60fps).
	if fire_timer > 0.0:
		fire_timer -= dt
	can_fire = fire_timer <= 0.0
	if fire_timer < -0.35:
		fire_timer = 0.0          # trigger idle: drop stale credit + climb
		_sustained_shots = 0

	_handle_input()
	_update_ads(dt)
	_update_burst()
	_update_reload(dt)
	_update_switch(dt)
	_update_weapon_position(dt)


func _handle_input() -> void:
	# Slot selection is owned by EquipmentManager (drives set_active_weapon_slot)

	# Can't do anything while switching
	if is_switching:
		return

	# Seated in the bird (W05): weapon down, no firing this version.
	if controller and "is_seated" in controller and controller.is_seated:
		is_aiming = false
		is_firing = false
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

	# W40: ADS FOV zoom re-enabled (per-weapon ads_fov; 0 = no zoom).
	if camera:
		var zoom_fov: float = BASE_FOV
		if current_weapon and current_weapon.ads_fov > 10.0:
			zoom_fov = current_weapon.ads_fov
		camera.fov = lerpf(BASE_FOV, zoom_fov, ads_transition)

	# Apply movement speed modifier to controller
	if controller and current_weapon:
		var speed_mult: float = lerpf(1.0, current_weapon.ads_move_mult, ads_transition)
		# Speed modifier is applied through equipment_manager


signal target_hit(killed: bool)
var _burst_left: int = 0
## Rounds fired since the trigger was last idle. Drives first-shot kick and
## sustained muzzle climb. Reset by the idle guard in _process.
var _sustained_shots: int = 0

## W75: session marksmanship counters (reset by GameFlow per mission).
static var session_shots: int = 0
static var session_hits: int = 0


## Burst (W40) continuation. Timing lives in _process's accumulator now.
func _update_burst() -> void:
	if _burst_left > 0 and fire_timer <= 0.0 and current_ammo > 0 and not is_reloading:
		_fire_shot()
		_burst_left -= 1


func _try_fire() -> void:
	if is_jammed:
		if Input.is_action_just_pressed("fire"):
			GunFX.play_click(self)
		return
	if not can_fire or is_reloading or is_switching:
		return

	if current_ammo <= 0:
		if Input.is_action_just_pressed("fire"):
			GunFX.play_click(self)
		return

	# Check firing mode (W40: real bolt-cycle + 3-round burst)
	match current_weapon.firing_mode:
		Enums.FiringMode.SEMI_AUTO:
			if not Input.is_action_just_pressed("fire"):
				return
			_fire_shot()
		Enums.FiringMode.FULL_AUTO:
			# Accumulator catch-up: if the frame was long enough to owe more than
			# one round, fire them (capped, so a hitch can't dump the mag).
			var fired: int = 0
			while fire_timer <= 0.0 and fired < 2 and current_ammo > 0:
				_fire_shot()
				fired += 1
		Enums.FiringMode.BOLT_ACTION:
			if not Input.is_action_just_pressed("fire"):
				return
			# fire_rate is authored as the practical bolt-CYCLE rate (~1.5s), so
			# get_fire_delay() already IS the bolt throw. No *2.5 patch.
			_fire_shot()
			GunFX.play_bolt_2d(self, current_weapon)
		Enums.FiringMode.BURST:
			if not Input.is_action_just_pressed("fire") or _burst_left > 0:
				return
			_burst_left = 3
			_fire_shot()
			_burst_left -= 1


func _fire_shot() -> void:
	current_ammo -= 1
	can_fire = false
	# Accumulate, do NOT assign: the negative remainder from _process is the
	# sub-frame credit that keeps average RPM exact and framerate-independent.
	fire_timer += current_weapon.get_fire_delay()
	_sustained_shots += 1
	session_shots += 1

	# R09: rare stoppage - the round fails to feed. Costs the round, no shot.
	var jam_chance: float = 0.015 / (1.0 + 0.05 * float(CampaignState.player_skill("small_arms")))
	if randf() < jam_chance:
		is_jammed = true
		GunFX.play_click(self)
		_hud_toast("WEAPON JAMMED - HIT RELOAD TO CLEAR")
		weapon_jammed.emit()
		magazine_changed.emit(current_ammo, spare_magazines)
		return

	# Calculate spread (W28: Small Arms skill tightens the cone)
	var spread := current_weapon.get_spread(ads_transition)
	spread *= 1.0 / (1.0 + 0.06 * float(CampaignState.player_skill("small_arms")))
	# Sniping: extra steadiness, but only while aiming down sights - it rewards
	# the patient long shot, not hip spray. Scales with ads_transition so it fades
	# in as you settle onto the glass. (Was buyable-but-never-read before Step 7.)
	spread *= 1.0 / (1.0 + 0.08 * float(CampaignState.player_skill("sniping")) * ads_transition)
	# W34/W37: prone steadies, arm wounds shake.
	if controller:
		if "is_prone" in controller and controller.is_prone:
			spread *= 0.6
		if "wounded_arms" in controller and controller.wounded_arms:
			spread *= 1.35
		# R52: holding your breath while aiming cuts spread hard, briefly.
		if "is_holding_breath" in controller and controller.is_holding_breath:
			spread *= 0.4
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

	# Shot feedback: sound, flash, viewmodel punch (RTCW-tight, R06/R07/R31)
	var muzzle_pos: Vector3 = _get_muzzle_position()
	# R57: firing their own captured weapon doesn't read as hostile on sound alone.
	var noise_team: int = 1 if (current_slot == 0 and primary_is_captured) else 0
	NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, muzzle_pos, noise_team)
	GunFX.play_shot_2d(self, current_weapon)
	GunFX.muzzle_flash(get_tree().current_scene, muzzle_pos)
	_punch = 1.0

	# Spawn bullet tracer
	if TRACER_ENABLED:
		var tracer_end: Vector3
		if result:
			tracer_end = result.position
		else:
			tracer_end = origin + final_dir * current_weapon.max_range
		BulletTracer.spawn_tracer(get_tree().current_scene, muzzle_pos, tracer_end, TRACER_COLOR)

	# Impact effects at whatever we hit.
	if result:
		var flesh: bool = (result.collider is Hitzone) or (result.collider is Node and (result.collider as Node).is_in_group("enemies"))
		if not flesh:
			GunFX.impact(get_tree().current_scene, result.position, result.normal, false)

	# Damage resolves against the world the player SAW (the ray above), but the
	# consequence is delayed by the round's flight time (W36: projectile_speed is
	# no longer dead data). Favor-the-shooter: at 735 m/s a 100 m hit lands ~136ms
	# after the flash, which is why long-range duels feel like duels.
	if result:
		var travel: float = origin.distance_to(result.position) / maxf(1.0, current_weapon.projectile_speed)
		if travel > 0.03:
			var hit: Dictionary = result.duplicate()
			var wd: WeaponData = current_weapon
			var atk: Node = controller
			get_tree().create_timer(travel, false).timeout.connect(
				func() -> void: _resolve_hit(hit, origin, wd, atk))
		else:
			_resolve_hit(result, origin, current_weapon, controller)

	# Apply recoil (W-feel: first shot kicks hardest, sustained fire climbs,
	# per-weapon recovery snaps the view back).
	var recoil_mult: float = lerpf(1.0, 0.5, ads_transition)  # Less recoil when ADS
	if _sustained_shots <= 1:
		recoil_mult *= current_weapon.recoil_first_shot_mult
	else:
		var climb: float = 1.0 + current_weapon.recoil_climb_per_shot * float(_sustained_shots - 1)
		recoil_mult *= minf(climb, current_weapon.recoil_climb_max)
	if controller and "is_prone" in controller and controller.is_prone:
		recoil_mult *= 0.55
	controller.apply_recoil(
		current_weapon.recoil_vertical * recoil_mult,
		current_weapon.recoil_horizontal * recoil_mult,
		current_weapon.recoil_recovery
	)

	# Update ammo tracking
	if current_slot == 0:
		primary_ammo[0] = current_ammo
	else:
		secondary_ammo[0] = current_ammo

	weapon_fired.emit()
	magazine_changed.emit(current_ammo, spare_magazines)


## Apply damage from a resolved raycast. Split out of _fire_shot so it can be
## deferred by projectile travel time. Distance falloff scales the dice roll
## before the hitzone multiplier, so a headshot stays a headshot at any range.
func _resolve_hit(hit: Dictionary, origin: Vector3, weapon: WeaponData, attacker: Node) -> void:
	var hit_collider: Object = hit.get("collider")
	if hit_collider == null or not is_instance_valid(hit_collider):
		return

	var damage_target: Node = null
	var damage_multiplier: float = 1.0
	var zone_name: String = "BODY"

	if hit_collider is Hitzone:
		var hitzone := hit_collider as Hitzone
		damage_target = hitzone.owner_entity
		damage_multiplier = hitzone.get_damage_multiplier()
		zone_name = hitzone.get_zone_name()
	elif hit_collider is Node and (hit_collider as Node).is_in_group("enemies"):
		damage_target = hit_collider as Node
	elif hit_collider is Node and (hit_collider as Node).get_parent() and (hit_collider as Node).get_parent().is_in_group("enemies"):
		damage_target = (hit_collider as Node).get_parent()

	if damage_target and is_instance_valid(damage_target) and damage_target.has_method("take_damage"):
		var falloff: float = weapon.damage_multiplier_at(origin.distance_to(hit.position))
		var base_damage: int = weapon.roll_damage()
		var final_damage: int = maxi(1, int(float(base_damage) * falloff * damage_multiplier))
		damage_target.take_damage(final_damage, weapon.damage_type, attacker)

		# W38: hitmarker feedback (HUD flash + tick; kill = deeper tone).
		var killed: bool = damage_target.has_method("is_dead") and damage_target.is_dead()
		session_hits += 1
		target_hit.emit(killed)

		if zone_name == "HEAD":
			print("[HIT] HEADSHOT! %d damage" % final_damage)


func _start_reload() -> void:
	if is_jammed:
		# R09: clearing a jam is a quick tap-rack, not a full mag swap.
		is_jammed = false
		_clearing_jam = true
		is_reloading = true
		reload_timer = 1.1
		is_aiming = false
		reload_started.emit()
		return
	if spare_magazines <= 0:
		return
	if current_ammo >= current_weapon.magazine_size:
		return

	_clearing_jam = false
	is_reloading = true
	# W29: Agility speeds reloads (cap at 60% of book time).
	var ag: float = float(CampaignState.player_data.get("ag", 100))
	reload_timer = current_weapon.reload_time * clampf(1.0 - (ag - 100.0) * 0.003, 0.6, 1.1)
	is_aiming = false
	GunFX.play_reload_2d(self, current_weapon)
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
	if _clearing_jam:
		_clearing_jam = false
		weapon_reloaded.emit()
		magazine_changed.emit(current_ammo, spare_magazines)
		return

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


func _hud_toast(text: String) -> void:
	var hud_node := get_tree().get_first_node_in_group("mission_hud")
	if hud_node and hud_node.has_method("show_toast"):
		hud_node.show_toast(text)


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


var _punch: float = 0.0


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

	# W72: weapon lowers while sprinting (readability + feel).
	if controller and "is_sprinting" in controller and controller.is_sprinting:
		target_pos.y -= 0.08
		target_rot.x -= 12.0

	# R52: idle sway - tighter aiming, nearly gone while holding your breath.
	_sway_time += delta
	var sway_amp: float = lerpf(0.014, 0.004, ads_transition)
	if controller and "is_holding_breath" in controller and controller.is_holding_breath:
		sway_amp *= 0.15
	target_pos.x += sin(_sway_time * 1.3) * sway_amp
	target_pos.y += sin(_sway_time * 0.9) * sway_amp * 0.6

	# Viewmodel fire punch (R07): sharp kick back+up, fast recovery. Scaled by
	# the weapon's authored recoil so the M60 shoves the model far harder than
	# the M1911 (2.5 = the old implicit baseline for every gun).
	_punch = maxf(0.0, _punch - delta * 9.0)
	var punch_amt: float = _punch * _punch  # ease-out curve
	var w: float = current_weapon.recoil_vertical / 2.5
	target_pos.z += punch_amt * 0.05 * w
	target_pos.y += punch_amt * 0.012 * w
	target_rot.x += punch_amt * 3.5 * w

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
