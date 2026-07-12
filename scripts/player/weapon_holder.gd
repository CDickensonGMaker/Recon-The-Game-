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
## Survival v1: weapon condition 0-100. Fouling from firing (worse in rain)
## multiplies the jam chance - the RIFLE gets unreliable, you don't lose damage.
var weapon_condition: float = 100.0
var _condition_warned_60: bool = false
var _condition_warned_30: bool = false
var _clearing_jam: bool = false
signal weapon_jammed

## R52: idle weapon sway, tightened by ADS and killed almost entirely by
## holding your breath (player.gd: is_holding_breath).
var _sway_time: float = 0.0

## R57: a captured enemy weapon in the primary slot sounds friendly to their
## side at range (NoiseBus team match) - visual detection still works fine.
var primary_is_captured: bool = false


## Re-sync transient state after a load or a hub clean (SaveManager calls this).
func refresh_after_load() -> void:
	_condition_warned_60 = weapon_condition < 60.0
	_condition_warned_30 = weapon_condition < 30.0
	if current_slot == 0:
		current_weapon = primary_weapon
		current_ammo = primary_ammo[0]
		spare_magazines = primary_ammo[1]
	else:
		current_weapon = secondary_weapon
		current_ammo = secondary_ammo[0]
		spare_magazines = secondary_ammo[1]
	_load_weapon_model(current_weapon)
	weapon_switched.emit(current_weapon)
	magazine_changed.emit(current_ammo, spare_magazines)


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

## Viewmodel pitch compensation (prevents floor clipping when looking down).
## Retuned for the full ARMS rigs (Caleb, gore lab): the old 0.8m lift from
## -20 deg was gun-only-era tuning - at close range (looking down at a target)
## it yanked the arms to the top of the screen.
const PITCH_OFFSET_ENABLED: bool = true
const PITCH_OFFSET_START: float = -38.0  ## Start offsetting at this pitch (degrees)
const PITCH_OFFSET_MAX: float = -75.0  ## Maximum pitch before full offset
const PITCH_OFFSET_UP: float = 0.22  ## How much to move weapon up
const PITCH_OFFSET_FORWARD: float = 0.15  ## How much to move weapon forward

## Raycasting
var ray_origin: Vector3
var ray_end: Vector3

## Tracers are data-driven per weapon now (WeaponData.tracer_ratio/color, nx9n)
## and the streak IS the round (BulletSystem, 7ks).

## Viewmodel scaling
const BASE_VIEWMODEL_SCALE: float = 0.1  ## Base scale applied to all viewmodels

func _ready() -> void:
	# Get references from parent hierarchy
	camera = get_parent() as Camera3D
	# Controller is the root Player node - go up: WeaponHolder -> Camera3D -> Head -> Player
	controller = get_parent().get_parent().get_parent()

	# Default primary: the M16A1 (flat 28 — ADR-016, derived from the retired
	# RECON 5d10 average). The WW2 Thompson holdover left the default loadout (audit).
	primary_weapon = load("res://data/weapons/m16a1.tres")
	secondary_weapon = load("res://data/weapons/m1911.tres")
	current_weapon = primary_weapon
	current_ammo = primary_ammo[0]
	spare_magazines = primary_ammo[1]
	magazine_changed.emit(current_ammo, spare_magazines)

	# Load initial weapon model
	_load_weapon_model(current_weapon)

	# Hitmarker feed: bullets resolve at ARRIVAL now (7ks), so the HUD tick
	# comes back from the BulletSystem when a player round actually lands.
	CombatManager.bullets.player_bullet_hit.connect(_on_player_bullet_hit)


func _on_player_bullet_hit(killed: bool, headshot: bool) -> void:
	session_hits += 1
	target_hit.emit(killed, headshot)


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

	# On the radio (handset up): the rifle is down - no aiming, no firing. You're
	# committed to the call and exposed. The whole point of "getting on the net".
	var on_radio: bool = MissionDirector.any_fire_menu_open

	# ADS input
	is_aiming = Input.is_action_pressed("aim") and not is_reloading and not on_radio

	# Fire input
	if Input.is_action_pressed("fire") and not is_reloading and not on_radio:
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


signal target_hit(killed: bool, headshot: bool)
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

	# Fouling: every round dirties the action; monsoon rain is worse.
	# Clean it with a kit [0] or free at the firebase.
	var foul: float = 0.15 + (0.10 if MissionWeather.rain_active else 0.0)
	weapon_condition = maxf(0.0, weapon_condition - foul)
	if weapon_condition < 60.0 and not _condition_warned_60:
		_condition_warned_60 = true
		_hud_toast("WEAPON'S GETTING DIRTY - CLEAN IT WHEN YOU CAN [0]")
	if weapon_condition < 30.0 and not _condition_warned_30:
		_condition_warned_30 = true
		_hud_toast("WEAPON FOULED - IT WILL JAM. FIELD-STRIP IT [0]")
	# Stoppage (Caleb gore-lab retune 2026-07-10): a clean weapon effectively
	# never jams (~1 in 1000); jams are CONDITION-DRIVEN, ramping quadratically
	# once fouled below 75 (~0.6% at 50, ~1.9% at 30, ~3.8% at 10). Old curve
	# jammed 1-in-67 on a CLEAN gun - felt broken, not hardcore.
	var fouled: float = maxf(0.0, 75.0 - weapon_condition) / 75.0
	var jam_chance: float = 0.001 + fouled * fouled * 0.05
	jam_chance /= 1.0 + 0.05 * float(CampaignState.player_skill("small_arms"))
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
		# R11: being suppressed blooms the cone - you cannot hold a bead while
		# rounds are cracking past. Makes suppression a real pressure, not decor;
		# the answer is the same as the fantasy: get down and out of the fire.
		if "suppression" in controller:
			spread *= 1.0 + controller.suppression * 0.9
	var spread_rad := deg_to_rad(spread)

	# Get fire direction with spread
	var aim_dir: Vector3 = controller.get_aim_direction()
	var spread_x := randf_range(-spread_rad, spread_rad)
	var spread_y := randf_range(-spread_rad, spread_rad)

	var right: Vector3 = aim_dir.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(aim_dir).normalized()

	var final_dir: Vector3 = (aim_dir + right * tan(spread_x) + up * tan(spread_y)).normalized()

	# AIM RAY - no damage, no FX. The crosshair's truth: find the point the
	# player is actually aiming at so the muzzle-spawned round converges onto
	# it (muzzle and camera are ~half a meter apart; without convergence every
	# close shot lands low-right of the crosshair). Same FULL-REALISM FRIENDLY
	# FIRE mask as the round itself: ally hurtboxes (32) are in - your rounds
	# hurt your men. Ally BODY capsules (layer 2) stay out on purpose: they
	# would shadow the hitzones (the 3-shot-headshot bug class).
	var origin: Vector3 = controller.get_camera_position()
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + final_dir * 2000.0,
		1 | 4 | 32 | 64  # World, enemies, ally hurtboxes, enemy hurtboxes
	)
	# THE sponge fix: hitzones are Area3D and rays default to bodies-only, so the
	# HEAD/GUT/LIMB zones were NEVER hittable - every shot landed 1.0x center mass.
	query.collide_with_areas = true
	query.exclude = [controller]
	var aim_hit := space_state.intersect_ray(query)
	var aim_point: Vector3 = aim_hit.position if aim_hit else origin + final_dir * 2000.0

	# Shot feedback: sound, flash, viewmodel punch (RTCW-tight, R06/R07/R31)
	var muzzle_pos: Vector3 = _get_muzzle_position()
	# R57: firing their own captured weapon doesn't read as hostile on sound alone.
	var noise_team: int = 1 if (current_slot == 0 and primary_is_captured) else 0
	NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, muzzle_pos, noise_team)
	GunFX.play_shot_2d(self, current_weapon)
	GunFX.muzzle_flash(get_tree().current_scene, muzzle_pos)
	_punch = 1.0

	# REAL PROJECTILES (7ks, Summoner decree - hitscan is dead): rockets fly
	# through ProjectileBase (so a captured RPG-2 finally fires a rocket, bead
	# vfnt), buckshot keeps the pellet-cluster grammar (ADR-016 Amendment A),
	# and every bullet is a live BulletSystem round - drop, travel time, and
	# arrival damage/FX. Impact feedback happens when the round LANDS.
	var muzzle_dir: Vector3 = (aim_point - muzzle_pos).normalized()
	if not current_weapon.projectile_data_path.is_empty():
		var pdata: ProjectileData = load(current_weapon.projectile_data_path)
		if pdata != null:
			CombatManager.spawn_projectile(pdata, controller, muzzle_pos, muzzle_dir)
		else:
			push_error("[WeaponHolder] %s names a projectile that will not load: %s" % [
				current_weapon.id, current_weapon.projectile_data_path])
	elif current_weapon.pellet_count > 1:
		_fire_pellet_cluster(origin, aim_dir, right, up)
	else:
		var show_tracer: bool = current_weapon.tracer_ratio > 0 \
			and (session_shots % current_weapon.tracer_ratio) == 0
		CombatManager.bullets.fire(current_weapon, controller, muzzle_pos, muzzle_dir,
			1 | 4 | 32 | 64, [controller], show_tracer)

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


## PELLET CLUSTER (ADR-016 amendment / war-room quick 2026-07-10): N rays in a
## cone; base_damage is per pellet; damage AGGREGATES per target+zone so the
## locational grammar and the gore single-hit thresholds (limb-off >= ~45) see
## one hit event - point-blank buckshot takes the arm, rim pellets sting.
func _fire_pellet_cluster(origin: Vector3, aim_dir: Vector3, right: Vector3, up: Vector3) -> void:
	var space_state := get_world_3d().direct_space_state
	var cone: float = deg_to_rad(current_weapon.pellet_spread_deg)
	var pellet_dmg: int = current_weapon.get_damage()
	var buckets: Dictionary = {}  # instance_id|zone -> [target, mult, zone, hits, dist_sum]
	var fx_budget: int = 4
	for _i in range(current_weapon.pellet_count):
		var px := randf_range(-cone, cone)
		var py := randf_range(-cone, cone)
		var dir: Vector3 = (aim_dir + right * tan(px) + up * tan(py)).normalized()
		var query := PhysicsRayQueryParameters3D.create(
			origin, origin + dir * current_weapon.max_range, 1 | 4 | 64)
		query.collide_with_areas = true
		query.exclude = [controller]
		var r := space_state.intersect_ray(query)
		if not r:
			continue
		var target: Node = null
		var mult: float = 1.0
		var zone: String = "BODY"
		var col: Object = r.collider
		if col is Hitzone:
			var hz := col as Hitzone
			target = hz.owner_entity
			mult = hz.get_damage_multiplier()
			zone = hz.get_zone_name()
		elif col is Node and (col as Node).is_in_group("enemies"):
			target = col as Node
		if target != null and is_instance_valid(target) and target.has_method("take_damage"):
			var key := "%d|%s" % [target.get_instance_id(), zone]
			if not buckets.has(key):
				buckets[key] = [target, mult, zone, 0, 0.0]
			var b: Array = buckets[key]
			b[3] = int(b[3]) + 1
			b[4] = float(b[4]) + origin.distance_to(r.position)
			if fx_budget > 0:
				GunFX.blood(get_tree().current_scene, r.position, r.normal, dir, target)
				fx_budget -= 1
		elif fx_budget > 0:
			GunFX.impact(get_tree().current_scene, r.position, r.normal, _surface_is_hard(col))
			fx_budget -= 1
	for key: String in buckets.keys():
		var b: Array = buckets[key]
		var target: Node = b[0]
		var n: int = int(b[3])
		var avg_dist: float = float(b[4]) / maxf(1.0, float(n))
		var falloff: float = current_weapon.damage_multiplier_at(avg_dist)
		var final_damage: int = maxi(1, int(float(pellet_dmg * n) * falloff * float(b[1])))
		var zone: String = str(b[2])
		var travel: float = avg_dist / maxf(1.0, current_weapon.projectile_speed)
		var wd: WeaponData = current_weapon
		var atk: Node = controller
		if travel > 0.03:
			get_tree().create_timer(travel, false).timeout.connect(func() -> void:
				if is_instance_valid(target) and target.has_method("take_damage"):
					target.take_damage(final_damage, wd.damage_type, atk, zone))
		else:
			target.take_damage(final_damage, wd.damage_type, atk, zone)


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

	# On the radio: rifle drops right out of the fight - you've raised the handset.
	# Deeper than the sprint-lower so it reads unmistakably as "on the net, exposed".
	if MissionDirector.any_fire_menu_open:
		target_pos.y -= 0.30
		target_pos.z += 0.14
		target_rot.x -= 60.0

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
			# Arms viewmodels carry a posed idle clip - play it or the rig renders
			# in bind pose (the invisible-arms bug was ALSO this + facing +Z).
			var vm_anim := weapon_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if vm_anim != null and vm_anim.has_animation("rifle_idle"):
				vm_anim.play("rifle_idle")


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
		var muzzle: Node3D = weapon_model.find_child("MuzzlePoint", true, false) as Node3D
		if muzzle:
			return muzzle.global_position

		# Fallback: estimate muzzle position in front of weapon
		return weapon_model.global_position + weapon_model.global_transform.basis.z * -0.5

	# Ultimate fallback: use camera position
	return controller.get_camera_position()


## Cheap surface guess for impact flavour: named/grouped hard surfaces spark,
## everything else puffs dirt. A full material-tag pass is a later item.
func _surface_is_hard(col: Object) -> bool:
	if col is Node:
		var n := col as Node
		if n.is_in_group("hard_surface"):
			return true
		var nm := str(n.name).to_lower()
		return "rock" in nm or "metal" in nm or "bunker" in nm or "vehicle" in nm or "truck" in nm
	return false
