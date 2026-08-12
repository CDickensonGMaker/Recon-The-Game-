## weapon_holder.gd - Handles weapon firing, reload, ADS, and weapon switching
class_name WeaponHolder
extends Node3D

signal weapon_reloaded
signal magazine_changed(current_ammo: int, spare_magazines: int)
signal weapon_switched(weapon_data: WeaponData)
signal reload_started
signal reload_progress(percent: float)
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
## Held-breath focus: the ADS FOV narrows by this much again while Shift is down.
const FOCUS_FOV_MULT: float = 0.72
const FOCUS_SPEED: float = 6.0
var _focus_t: float = 0.0  ## 0 = breathing, 1 = fully focused

## Firing state
var can_fire: bool = true
var fire_timer: float = 0.0

var is_jammed: bool = false
## Weapon condition 0-100. Fouling raises the jam chance, never lowers damage.
var weapon_condition: float = 100.0
var _condition_warned_60: bool = false
var _condition_warned_30: bool = false
var _clearing_jam: bool = false
signal weapon_jammed

var _sway_time: float = 0.0

## Captured enemy weapon in the primary slot: its gunshots emit on the enemy
## NoiseBus team, so they do not read as hostile by sound (visual still does).
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

## Mounted-gun state: the primary slot the emplacement borrowed, restored on dismount.
var _mounted_snapshot: Dictionary = {}


## Swap the rifle for a fixed mount's weapon (its OWN belt, not the player's mags).
## The emplacement drives this on man; unmount_gun() restores the rifle exactly.
func mount_gun(data: WeaponData) -> void:
	if data == null or not _mounted_snapshot.is_empty():
		return
	_mounted_snapshot = {
		"weapon": primary_weapon,
		"ammo": primary_ammo.duplicate(),
		"captured": primary_is_captured,
	}
	is_switching = false
	is_reloading = false
	is_aiming = false
	current_slot = 0
	primary_weapon = data
	primary_ammo = [data.magazine_size, 99]   # belt-fed: effectively fed by the post
	primary_is_captured = false
	current_weapon = data
	current_ammo = primary_ammo[0]
	spare_magazines = primary_ammo[1]
	_load_weapon_model(current_weapon)
	# A mount that produced no viewmodel is the "invisible gun" failure - it reads
	# as the mount working while the player holds nothing.
	if weapon_model == null:
		push_warning("[MG] mounted %s but no viewmodel loaded from '%s'" % [
			data.id, data.model_path])
	weapon_switched.emit(current_weapon)
	magazine_changed.emit(current_ammo, spare_magazines)


func unmount_gun() -> void:
	if _mounted_snapshot.is_empty():
		return
	primary_weapon = _mounted_snapshot["weapon"] as WeaponData
	primary_ammo = _mounted_snapshot["ammo"]
	primary_is_captured = bool(_mounted_snapshot["captured"])
	_mounted_snapshot = {}
	is_switching = false
	is_reloading = false
	is_aiming = false
	# Come off the gun with the rifle up (slot 0), matching equipment_manager.
	current_slot = 0
	current_weapon = primary_weapon
	current_ammo = primary_ammo[0]
	spare_magazines = primary_ammo[1]
	_load_weapon_model(current_weapon)
	weapon_switched.emit(current_weapon)
	magazine_changed.emit(current_ammo, spare_magazines)


## Reload state
var is_reloading: bool = false
var reload_timer: float = 0.0
var reload_duration: float = 0.0  ## what reload_timer started at, for progress

## Weapon switch state
var is_switching: bool = false
var switch_timer: float = 0.0
const SWITCH_TIME: float = 0.5

## Weapon model
var weapon_model: Node3D = null
var _vm_anim: AnimationPlayer = null  ## authored FP-arms clips inside the viewmodel GLB
var _vm_meshes: Array[MeshInstance3D] = []  ## lens-shaded meshes (ADR-034)

## Viewmodel pitch compensation (prevents floor clipping when looking down).
## Legacy-path only: the lens shader's depth squash makes floor clipping
## impossible, so the whole block dies with ViewmodelLens.ENABLED's escape hatch.
const PITCH_OFFSET_ENABLED: bool = true
const PITCH_OFFSET_START: float = -38.0  ## Start offsetting at this pitch (degrees)
const PITCH_OFFSET_MAX: float = -75.0  ## Maximum pitch before full offset
const PITCH_OFFSET_UP: float = 0.22  ## How much to move weapon up
const PITCH_OFFSET_FORWARD: float = 0.15  ## How much to move weapon forward

## Raycasting
var ray_origin: Vector3
var ray_end: Vector3


func _ready() -> void:
	camera = get_parent() as Camera3D
	# Hierarchy contract: WeaponHolder -> Camera3D -> Head -> Player (the root).
	controller = get_parent().get_parent().get_parent()

	primary_weapon = load("res://data/weapons/m16a1.tres")
	secondary_weapon = load("res://data/weapons/m1911.tres")
	current_weapon = primary_weapon
	current_ammo = primary_ammo[0]
	spare_magazines = primary_ammo[1]
	magazine_changed.emit(current_ammo, spare_magazines)

	_load_weapon_model(current_weapon)

	CombatManager.bullets.player_bullet_hit.connect(_on_player_bullet_hit)


func _on_player_bullet_hit(killed: bool, headshot: bool) -> void:
	session_hits += 1
	target_hit.emit(killed, headshot)


func _process(delta: float) -> void:
	if not GameManager.can_player_act():
		return

	_refresh_warhead()   # loaded tube vs empty tube (no-op on every other gun)

	# Quake 3 timestep cap: a frame hitch must not credit a burst of fire.
	var dt: float = minf(delta, 0.066)

	# Tick the action clock BEFORE input. fire_timer may go NEGATIVE; that
	# remainder is sub-frame credit toward the next round, and it is what keeps
	# average RPM framerate-independent.
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

	if is_switching:
		return

	if controller and "is_seated" in controller and controller.is_seated:
		is_aiming = false
		return

	# Both hands are on the rungs. Same guard as the seated ride.
	if controller and "is_climbing" in controller and controller.is_climbing:
		is_aiming = false
		return

	# A downed man does not return fire while waiting on Doc.
	if controller and controller.has_method("is_dead") and controller.is_dead():
		is_aiming = false
		return

	# Block input if not on weapon slot (grenade/medkit selected)
	var on_weapon_slot: bool = not equipment_manager or equipment_manager.is_weapon_slot()
	if not on_weapon_slot:
		is_aiming = false
		return

	# On the radio (fire-support menu open) OR holding the RTO's handset: the rifle
	# is down - no aim, no fire. Holding the handset costs you your rifle.
	var on_radio: bool = FieldDirector.any_fire_menu_open
	if controller and "holding_handset" in controller and controller.holding_handset:
		on_radio = true

	is_aiming = Input.is_action_pressed("aim") and not is_reloading and not on_radio

	if Input.is_action_pressed("fire") and not is_reloading and not on_radio:
		_try_fire()

	if Input.is_action_just_pressed("reload") and not is_reloading:
		_start_reload()


func _update_ads(delta: float) -> void:
	var target := 1.0 if is_aiming else 0.0
	ads_transition = lerp(ads_transition, target, delta * ADS_SPEED)

	# CAMERA CONTRACT (ADR-004): hip FOV is BASE_FOV 75; ADS uses the weapon's
	# own ads_fov from the .tres (<=10 means no zoom). viewmodel_editor.gd
	# mirrors this exactly - change one and you must change both.
	# FOCUS (hold breath, HLL-style): on the sights, Shift leans further into the
	# glass. The meter that limits it is the player's lungs - Player.breath_meter
	# owns the clock, this only reads the state it publishes.
	var focusing: bool = controller != null and "is_holding_breath" in controller \
		and controller.is_holding_breath
	_focus_t = lerpf(_focus_t, 1.0 if focusing else 0.0, delta * FOCUS_SPEED)

	if camera:
		var zoom_fov: float = BASE_FOV
		if current_weapon and current_weapon.ads_fov > 10.0:
			zoom_fov = current_weapon.ads_fov
		var focused_fov: float = zoom_fov * FOCUS_FOV_MULT
		camera.fov = lerpf(BASE_FOV, lerpf(zoom_fov, focused_fov, _focus_t), ads_transition)
		if ViewmodelLens.ENABLED and current_weapon and not _vm_meshes.is_empty():
			ViewmodelLens.set_fov(_vm_meshes,
				ViewmodelLens.effective_fov(current_weapon.viewmodel_fov, camera.fov))

	# Optical scope (M70 class): under the fullscreen scope view the gun itself
	# leaves the frame. ScopeOverlay shows at the same >=0.9 threshold.
	if weapon_model and current_weapon:
		var scoped_out: bool = current_weapon.scope_overlay != null \
			and is_aiming and ads_transition >= 0.9
		if weapon_model.visible == scoped_out:
			weapon_model.visible = not scoped_out


signal target_hit(killed: bool, headshot: bool)
var _burst_left: int = 0
## Rounds fired since the trigger was last idle. Drives first-shot kick and
## sustained muzzle climb. Reset by the idle guard in _process.
var _sustained_shots: int = 0

## Session marksmanship counters (reset by GameFlow per mission).
static var session_shots: int = 0
## Trigger cadence, for the first-settled-shot rule.
var _last_shot_ms: float = -9999.0

## ART CONTRACT: a launcher's warhead is hidden after firing by matching any
## surface whose MATERIAL NAME contains "warhead" - rename the material in the
## viewmodel and the rocket stops leaving the tube.
var _warhead_fired: bool = false
var _warhead_surfaces: Array = []   # [[MeshInstance3D, surface_idx], ...]
var _warhead_hidden: bool = false
static var _invisible_mat: StandardMaterial3D = null


static func _hide_material() -> StandardMaterial3D:
	if _invisible_mat == null:
		_invisible_mat = StandardMaterial3D.new()
		_invisible_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_invisible_mat.albedo_color = Color(0, 0, 0, 0)
		_invisible_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_invisible_mat.no_depth_test = false
	return _invisible_mat


## Find the warhead surfaces in whatever viewmodel just got loaded.
func _scan_warhead(root: Node) -> void:
	_warhead_surfaces.clear()
	_warhead_hidden = false
	_warhead_fired = false
	if root == null:
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			var mat: Material = mi.mesh.surface_get_material(s)
			if mat != null and str(mat.resource_name).to_lower().contains("warhead"):
				# Restore target = whatever the surface wears NOW (the lens override
				# under ADR-034, null on the legacy path) - restoring to null would
				# strip the lens off a reloaded launcher's warhead.
				_warhead_surfaces.append([mi, s, mi.get_surface_override_material(s)])


## Loaded launcher shows its warhead; a fired one shows an empty tube.
func _refresh_warhead() -> void:
	if _warhead_surfaces.is_empty():
		return
	var want_hidden: bool = _warhead_fired and not is_reloading
	if want_hidden == _warhead_hidden:
		return
	_warhead_hidden = want_hidden
	for entry in _warhead_surfaces:
		var mi: MeshInstance3D = entry[0]
		if is_instance_valid(mi):
			mi.set_surface_override_material(int(entry[1]),
				_hide_material() if want_hidden else entry[2])
static var session_hits: int = 0


## Burst continuation; timing lives in the _process accumulator.
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
			# fire_rate is authored as the practical bolt-CYCLE rate, so
			# get_fire_delay() already IS the bolt throw. Do not scale it again.
			_fire_shot()
			GunFX.play_bolt_2d(self, current_weapon)
			_play_vm_rack()
		Enums.FiringMode.BURST:
			if not Input.is_action_just_pressed("fire") or _burst_left > 0:
				return
			_burst_left = 3
			_fire_shot()
			_burst_left -= 1
			_play_vm_rack()


func _fire_shot() -> void:
	# EMPTY HANDS ARE A REAL STATE: the player can drop his primary and walk with the
	# slot empty. Everything below dereferences current_weapon unguarded.
	if current_weapon == null:
		can_fire = false
		return
	current_ammo -= 1
	can_fire = false
	# Accumulate, do NOT assign: the negative remainder from _process is the
	# sub-frame credit that keeps average RPM exact and framerate-independent.
	fire_timer += current_weapon.get_fire_delay()
	_sustained_shots += 1
	session_shots += 1
	var _prev_shot_ms: float = _last_shot_ms
	_last_shot_ms = float(Time.get_ticks_msec())

	var foul: float = 0.15 + (0.10 if MissionWeather.rain_active else 0.0)
	weapon_condition = maxf(0.0, weapon_condition - foul)
	if weapon_condition < 60.0 and not _condition_warned_60:
		_condition_warned_60 = true
		_hud_toast("WEAPON'S GETTING DIRTY - CLEAN IT WHEN YOU CAN [0]")
	if weapon_condition < 30.0 and not _condition_warned_30:
		_condition_warned_30 = true
		_hud_toast("WEAPON FOULED - IT WILL JAM. CLEAN IT AT THE FIREBASE.")
	# Jam chance is condition-driven: ~1-in-1000 on a clean weapon, ramping
	# quadratically once fouled below 75 (~0.6% at 50, ~3.8% at 10).
	# ADR-018: the rifle's state, never the player's stats. No progression may
	# lower this number.
	var fouled: float = maxf(0.0, 75.0 - weapon_condition) / 75.0
	var jam_chance: float = 0.001 + fouled * fouled * 0.05
	if randf() < jam_chance:
		is_jammed = true
		GunFX.play_click(self)
		_hud_toast("WEAPON JAMMED - HIT RELOAD TO CLEAR")
		weapon_jammed.emit()
		magazine_changed.emit(current_ammo, spare_magazines)
		return

	# ADR-018: spread is the weapon's, the stance's and the situation's. Never the
	# player's. Your aim is your aim, mission 1 to mission 100.
	var spread := current_weapon.get_spread(ads_transition)
	if controller:
		if "is_prone" in controller and controller.is_prone:
			spread *= 0.6
		if "wounded_arms" in controller and controller.wounded_arms:
			spread *= 1.35
		if "is_holding_breath" in controller and controller.is_holding_breath:
			spread *= 0.4
		if "suppression" in controller:
			spread *= 1.0 + controller.suppression * 0.9
	# THE FIRST SETTLED SHOT LANDS ON THE SIGHTS: fully aimed, standing still and
	# not spraying, the mechanical cone all but vanishes - every other source of
	# variance left is a system the player can read and control.
	var settled: bool = ads_transition > 0.9 \
		and float(Time.get_ticks_msec()) - _prev_shot_ms > 400.0 \
		and (controller == null or Vector3(controller.velocity.x, 0.0, controller.velocity.z).length() < 0.6)
	if settled:
		spread *= 0.12
	var spread_rad := deg_to_rad(spread)

	var aim_dir: Vector3 = controller.get_aim_direction()
	var right: Vector3 = aim_dir.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(aim_dir).normalized()

	# CENTER-WEIGHTED cone (polar + gaussian magnitude), never a uniform per-axis
	# square: rounds must cluster at the point of aim and thin toward the rim.
	var ang: float = randf() * TAU
	var mag: float = absf(randfn(0.0, 0.45))  # ~99% inside the cone
	mag = minf(mag, 1.0) * spread_rad
	var spread_x: float = cos(ang) * mag
	var spread_y: float = sin(ang) * mag

	# THE SIGHT LINE: where the shooter is LOOKING. Zero elevation must NOT be
	# applied here - it belongs to the launch, not to the eye.
	var final_dir: Vector3 = (aim_dir + right * tan(spread_x) + up * tan(spread_y)).normalized()

	# AIM RAY - no damage, no FX: the point the player is actually aiming at, so
	# the muzzle-spawned round converges onto it (muzzle and camera sit ~0.5m
	# apart; without this, close shots land low-right of the crosshair).
	var origin: Vector3 = controller.get_camera_position()
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + final_dir * 2000.0,
		# MASK LAW: world + hurtbox AREAS only. BODY capsules (ally layer 2, enemy
		# layer 3) must stay OUT - a capsule in the mask shadows the hitzones inside
		# it and every hit resolves flat 1.0x center-mass. Ally hurtboxes (32) are
		# IN: friendly fire is real. Civilians (512) are IN on every mask - the AI
		# masks carry 512 too, so a stray round finds a villager whoever fired it.
		1 | 32 | 64 | 512
	)
	# Godot: rays are bodies-only by default and hitzones are Area3D.
	query.collide_with_areas = true
	query.exclude = _self_exclusions()
	var aim_hit := space_state.intersect_ray(query)
	var aim_point: Vector3 = aim_hit.position if aim_hit else origin + final_dir * 2000.0

	var muzzle_pos: Vector3 = _get_muzzle_position()
	# A captured weapon reports on THEIR team's noise channel, not ours.
	var noise_team: int = 1 if (current_slot == 0 and primary_is_captured) else 0
	NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, muzzle_pos, noise_team)
	GunFX.play_shot_2d(self, current_weapon)
	# The flash is cosmetic: it must sit on the barrel AS DRAWN through the lens.
	# Rounds, noise and suppression above keep the true world muzzle.
	var flash_pos: Vector3 = muzzle_pos
	if ViewmodelLens.ENABLED:
		flash_pos = ViewmodelLens.apparent_point(camera, current_weapon.viewmodel_fov, muzzle_pos)
	GunFX.muzzle_flash(get_tree().current_scene, flash_pos)
	_punch = 1.0

	# SUPPRESSION: every shot that snaps past a man pushes him down. Bullets use the
	# shared near-miss geometry along the LANE - the area term is centred on the muzzle,
	# so on a rifle it only ever pressed men standing beside the shooter. Buckshot and
	# warheads keep the area, moved onto the aim point where the spray actually lands.
	var suppress_radius: float = _calc_suppress_radius()
	var suppress_amount: float = _calc_suppress_amount()
	var spreads_wide: bool = current_weapon.pellet_count > 1 \
		or not current_weapon.projectile_data_path.is_empty()
	if spreads_wide:
		if suppress_radius > 0.0 and suppress_amount > 0.0:
			CombatManager.apply_suppression_in_area(aim_point, suppress_radius, suppress_amount, controller)
	else:
		CombatManager.suppress_along_shot(origin, final_dir, controller, aim_hit)

	# DOWN THE SIGHTS = DOWN THE SIGHTLINE. Aimed rounds leave the CAMERA along
	# the crosshair ray, so a viewmodel's muzzle position can never bend an aimed
	# shot - viewmodel offsets stay purely cosmetic and are free to retune. Hip
	# fire spawns at the muzzle and converges on the aim point.
	var muzzle_dir: Vector3 = (aim_point - muzzle_pos).normalized()
	if ads_transition > 0.6:
		muzzle_pos = origin
		muzzle_dir = final_dir
	if not current_weapon.projectile_data_path.is_empty():
		var pdata: ProjectileData = load(current_weapon.projectile_data_path)
		if pdata != null:
			# LAUNCHER SIGHT: a rocket carries its OWN gravity (ProjectileData.
			# gravity_scale), so elevate for the ACTUAL range to the aim point -
			# never a fixed rifle zero.
			var g_eff: float = 9.8 * maxf(0.0, pdata.gravity_scale)
			var dist: float = muzzle_pos.distance_to(aim_point)
			var elev: float = 0.0
			if pdata.speed > 1.0 and g_eff > 0.0:
				elev = (g_eff * dist) / (2.0 * pdata.speed * pdata.speed)
			var rocket_dir: Vector3 = (muzzle_dir + up * tan(elev)).normalized()
			CombatManager.spawn_projectile(pdata, controller, muzzle_pos, rocket_dir)
			_warhead_fired = true   # the tube is empty until you reload it
		else:
			push_error("[WeaponHolder] %s names a projectile that will not load: %s" % [
				current_weapon.id, current_weapon.projectile_data_path])
	elif current_weapon.pellet_count > 1:
		_fire_pellet_cluster(origin, aim_dir, right, up)
	else:
		# SIGHT ZERO belongs HERE - on the round that flies, not the eye that aims:
		# the muzzle rides up so the falling round crosses the sightline at zero_range.
		var zeroed_dir: Vector3 = (muzzle_dir + up * tan(current_weapon.zero_elevation())).normalized()
		var show_tracer: bool = current_weapon.tracer_ratio > 0 \
			and (session_shots % current_weapon.tracer_ratio) == 0
		CombatManager.bullets.fire(current_weapon, controller, muzzle_pos, zeroed_dir,
			1 | 32 | 64 | 512, _self_exclusions(), show_tracer)

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

	if current_slot == 0:
		primary_ammo[0] = current_ammo
	else:
		secondary_ammo[0] = current_ammo

	magazine_changed.emit(current_ammo, spare_magazines)


## The muzzle sits INSIDE the player's own HEAD zone band (camera height): his
## rounds and aim ray must exclude his own body AND hitzone areas, or every
## trigger pull is a self-headshot.
func _self_exclusions() -> Array:
	var excl: Array = [controller]
	var hz_list: Variant = controller.get("hitzones")
	if hz_list is Array:
		for hz in hz_list:
			if is_instance_valid(hz):
				excl.append(hz)
	return excl


## N rays in a cone. base_damage is PER PELLET, and damage aggregates per
## target+region so one shell reads as ONE trauma event (gore thresholds and
## locational rules must see a single hit, not nine).
func _fire_pellet_cluster(origin: Vector3, aim_dir: Vector3, right: Vector3, up: Vector3) -> void:
	var space_state := get_world_3d().direct_space_state
	# pellet_spread_deg is the FULL cone angle - hence the half here.
	var cone: float = deg_to_rad(current_weapon.pellet_spread_deg * 0.5)
	var pellet_dmg: int = current_weapon.get_damage()
	var buckets: Dictionary = {}  # instance_id|zone -> [target, mult, zone, hits, dist_sum]
	var fx_budget: int = 4
	# DETERMINISTIC pattern (same aim = same result, not a slot machine): a fixed
	# star of 1 centre + 4 at 40% + 4 at the rim, jittered only by a hair.
	var star: Array[Vector2] = [Vector2.ZERO]
	for i in range(4):
		var a: float = TAU * float(i) / 4.0
		star.append(Vector2(cos(a), sin(a)) * 0.4)
	for i in range(4):
		var a2: float = TAU * (float(i) + 0.5) / 4.0
		star.append(Vector2(cos(a2), sin(a2)))
	for _i in range(current_weapon.pellet_count):
		var o: Vector2 = star[_i % star.size()] * cone
		var px := o.x + randf_range(-0.005, 0.005)
		var py := o.y + randf_range(-0.005, 0.005)
		var dir: Vector3 = (aim_dir + right * tan(px) + up * tan(py)).normalized()
		# World + enemy hurtboxes only (a body capsule in the mask would shadow the
		# zones inside it). Each pellet punches its own way through up to two
		# soft_cover layers, losing energy each time.
		var soft_left: int = 2
		var pellet_scale: float = 1.0
		var start: Vector3 = origin
		var r: Dictionary = {}
		while true:
			var query := PhysicsRayQueryParameters3D.create(
				start, origin + dir * current_weapon.max_range, 1 | 64 | 512)
			query.collide_with_areas = true
			query.exclude = _self_exclusions()
			r = space_state.intersect_ray(query)
			if not r:
				break
			var c0: Object = r.collider
			if c0 is Node and (c0 as Node).is_in_group("soft_cover") and soft_left > 0:
				soft_left -= 1
				pellet_scale *= 0.8
				if fx_budget > 0:
					GunFX.impact(get_tree().current_scene, r.position, r.normal, false)
					fx_budget -= 1
				start = (r.position as Vector3) + dir * 0.08   # out the far side
				continue
			break
		if not r:
			continue
		var target: Node = null
		var mult: float = 1.0
		var zone: String = "BODY"
		var col: Object = r.collider
		var region: String = ""
		if col is Hitzone:
			var hz := col as Hitzone
			target = hz.owner_entity
			mult = hz.get_damage_multiplier()
			zone = hz.get_zone_name()
			region = str(hz.get_meta("region", ""))
		elif col is Node and (col as Node).is_in_group("enemies"):
			target = col as Node
		if target != null and is_instance_valid(target) and target.has_method("take_damage"):
			# Bucket per REGION (not per 4-name zone) so a leg-full of buck is ONE
			# trauma event that can cross the gib threshold, on the correct leg.
			var key := "%d|%s" % [target.get_instance_id(), region if region != "" else zone]
			if not buckets.has(key):
				buckets[key] = [target, mult, zone, 0.0, 0.0, region]
			var b: Array = buckets[key]
			b[3] = float(b[3]) + pellet_scale   # brush eats energy, not the pellet
			b[4] = float(b[4]) + origin.distance_to(r.position)
			if fx_budget > 0:
				GunFX.blood(get_tree().current_scene, r.position, r.normal, dir, target)
				fx_budget -= 1
			# Buck penetrates men: the pellet carries through the first body at 65%
			# into whoever stands behind. ONE body deep; walls still stop lead.
			var q2 := PhysicsRayQueryParameters3D.create(
				r.position + dir * 0.35, origin + dir * current_weapon.max_range, 1 | 64)
			q2.collide_with_areas = true
			q2.exclude = _self_exclusions()
			var r2 := space_state.intersect_ray(q2)
			if r2 and r2.collider is Hitzone:
				var hz2 := r2.collider as Hitzone
				var t2: Node = hz2.owner_entity
				if t2 != null and is_instance_valid(t2) and t2 != target and t2.has_method("take_damage"):
					var reg2: String = str(hz2.get_meta("region", ""))
					var key2 := "%d|%s" % [t2.get_instance_id(), reg2 if reg2 != "" else hz2.get_zone_name()]
					if not buckets.has(key2):
						buckets[key2] = [t2, hz2.get_damage_multiplier(), hz2.get_zone_name(), 0.0, 0.0, reg2]
					var b2: Array = buckets[key2]
					b2[3] = float(b2[3]) + 0.65
					b2[4] = float(b2[4]) + origin.distance_to(r2.position)
					if fx_budget > 0:
						GunFX.blood(get_tree().current_scene, r2.position, r2.normal, dir, t2)
						fx_budget -= 1
		elif fx_budget > 0:
			GunFX.impact(get_tree().current_scene, r.position, r.normal, _surface_is_hard(col))
			fx_budget -= 1
	for key: String in buckets.keys():
		var b: Array = buckets[key]
		var target: Node = b[0]
		var n: float = float(b[3])  # penetration hits weigh 0.65
		var avg_dist: float = float(b[4]) / maxf(1.0, ceilf(n))
		var falloff: float = current_weapon.damage_multiplier_at(avg_dist)
		var final_damage: int = maxi(1, int(float(pellet_dmg) * n * falloff * float(b[1])))
		var zone: String = str(b[2])
		var region: String = str(b[5])
		var travel: float = avg_dist / maxf(1.0, current_weapon.projectile_speed)
		var wd: WeaponData = current_weapon
		var atk: Node = controller
		var pdir: Vector3 = aim_dir
		# Gore parity with BulletSystem: the aggregated bucket is ONE trauma event.
		if travel > 0.03:
			get_tree().create_timer(travel, false).timeout.connect(func() -> void:
				if is_instance_valid(target) and target.has_method("take_damage"):
					target.take_damage(final_damage, wd.damage_type, atk, zone)
					if region != "" and target.has_method("on_zone_hit"):
						target.on_zone_hit(region, final_damage, pdir))
		else:
			target.take_damage(final_damage, wd.damage_type, atk, zone)
			if region != "" and target.has_method("on_zone_hit"):
				target.on_zone_hit(region, final_damage, pdir)


func _start_reload() -> void:
	if is_jammed:
		is_jammed = false
		_clearing_jam = true
		is_reloading = true
		# ADR-018: the authored time, always. Handling is not a stat.
		reload_timer = current_weapon.jam_clear_time
		reload_duration = reload_timer
		is_aiming = false
		_play_vm_clip("jam", current_weapon.jam_clear_time)
		reload_started.emit()
		return
	if spare_magazines <= 0:
		return
	if current_ammo >= current_weapon.magazine_size:
		return

	_clearing_jam = false
	is_reloading = true
	var from_empty: bool = current_ammo == 0
	# ADR-018: the authored time, always. Handling is not a stat.
	var authored: float = current_weapon.reload_time
	if from_empty and current_weapon.empty_reload_time > 0.0:
		authored = current_weapon.empty_reload_time
	reload_timer = authored
	reload_duration = authored
	is_aiming = false
	_play_vm_clip("reload_empty" if from_empty else "reload", authored)
	GunFX.play_reload_2d(self, current_weapon)
	reload_started.emit()


func _update_reload(delta: float) -> void:
	if not is_reloading:
		return

	reload_timer -= delta
	var progress: float = 1.0 - (reload_timer / maxf(0.05, reload_duration))
	reload_progress.emit(progress)

	if reload_timer <= 0:
		_finish_reload()


func _finish_reload() -> void:
	is_reloading = false
	_play_vm_idle()
	_warhead_fired = false   # a fresh rocket goes down the tube
	if _clearing_jam:
		_clearing_jam = false
		weapon_reloaded.emit()
		magazine_changed.emit(current_ammo, spare_magazines)
		return

	spare_magazines -= 1
	current_ammo = current_weapon.magazine_size

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


var _punch: float = 0.0
## Stock-end z of the gun in weapon_model space (rifle_idle pose). Some GLBs
## park their geometry metres from the node origin (armory rack station baked
## into the idle), so a punch rotated about the origin see-saws the gun: butt
## drops, barrel stays pinned. The punch pivots about this z instead.
var _recoil_pivot_z: float = 0.0


func _update_weapon_position(delta: float) -> void:
	if not weapon_model or not current_weapon:
		return

	# Hip/ADS poses come from the .tres, never from a scene transform.
	var target_pos: Vector3 = current_weapon.hip_position.lerp(current_weapon.ads_position, ads_transition)
	var target_rot: Vector3 = current_weapon.hip_rotation.lerp(current_weapon.ads_rotation, ads_transition)

	# The lens magnifies every translation by its ratio on screen; feel constants
	# below (sway/punch/dips) are authored in pre-lens screen terms, so divide the
	# additive bumps back down. Poses above are tuned ON the bench and stay raw.
	var bump: float = 1.0
	if ViewmodelLens.ENABLED:
		bump = 1.0 / ViewmodelLens.magnification(current_weapon.viewmodel_fov)

	if not ViewmodelLens.ENABLED and PITCH_OFFSET_ENABLED and camera:
		# Pitch lives on the Head node (the camera itself carries no vertical look).
		var head_node: Node3D = camera.get_parent() as Node3D
		if head_node:
			var head_pitch: float = rad_to_deg(head_node.rotation.x)

			if head_pitch < PITCH_OFFSET_START:
				var offset_range: float = PITCH_OFFSET_START - PITCH_OFFSET_MAX
				var pitch_factor: float = clampf((PITCH_OFFSET_START - head_pitch) / offset_range, 0.0, 1.0)

				target_pos.y += PITCH_OFFSET_UP * pitch_factor
				target_pos.z -= PITCH_OFFSET_FORWARD * pitch_factor

	if controller and "is_sprinting" in controller and controller.is_sprinting:
		target_pos.y -= 0.08 * bump
		target_rot.x -= 12.0

	if FieldDirector.any_fire_menu_open:
		target_pos.y -= 0.30 * bump
		target_pos.z += 0.14 * bump
		target_rot.x -= 60.0

	_sway_time += delta
	# The ADS end is deliberately far below the hip figure: on the sights the sway
	# is a breathing hold, not a wander off the target.
	var sway_amp: float = lerpf(0.014, 0.0012, ads_transition) * bump
	if controller and "is_holding_breath" in controller and controller.is_holding_breath:
		sway_amp *= 0.15
	target_pos.x += sin(_sway_time * 1.3) * sway_amp
	target_pos.y += sin(_sway_time * 0.9) * sway_amp * 0.6

	# Viewmodel punch, scaled by the weapon's authored recoil (2.5 = the baseline
	# gun, so w == 1.0 there).
	_punch = maxf(0.0, _punch - delta * 9.0)
	var punch_amt: float = _punch * _punch  # ease-out curve
	var w: float = current_weapon.recoil_vertical / 2.5
	target_pos.z += punch_amt * 0.05 * w * bump
	target_pos.y += punch_amt * 0.012 * w * bump
	var punch_pitch: float = punch_amt * 3.5 * w
	target_rot.x += punch_pitch
	# Geometric re-seat of the rotation pivot, so it stays raw (no bump).
	target_pos += punch_pivot_comp(target_rot, punch_pitch, _recoil_pivot_z)

	weapon_model.position = weapon_model.position.lerp(target_pos, delta * ADS_SPEED)
	weapon_model.rotation_degrees = weapon_model.rotation_degrees.lerp(target_rot, delta * ADS_SPEED)


## Translation that moves the punch pitch's pivot from the node origin to the
## stock at local (0, 0, pivot_z): the stock holds its point in camera space
## and the muzzle arcs up, on every gun, regardless of where the GLB parked
## its geometry. Zero pivot_z or zero pitch degenerates to the origin pivot.
static func punch_pivot_comp(rot_deg: Vector3, pitch_deg: float, pivot_z: float) -> Vector3:
	if absf(pitch_deg) < 0.0001 or absf(pivot_z) < 0.0001:
		return Vector3.ZERO
	var stock := Vector3(0.0, 0.0, pivot_z)
	var punched := Basis.from_euler(Vector3(
		deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z)))
	var unpunched := Basis.from_euler(Vector3(
		deg_to_rad(rot_deg.x - pitch_deg), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z)))
	return unpunched * stock - punched * stock


## Rear-most gun-mesh z in weapon_model space, posed by rifle_idle. Arms and
## hand meshes are excluded so a trailing elbow cannot read as the stock;
## the result never sits forward of the origin (clamped to >= 0).
func _measure_recoil_pivot() -> float:
	if weapon_model == null or _vm_anim == null or not _vm_anim.has_animation("rifle_idle"):
		return 0.0
	_vm_anim.play("rifle_idle")
	_vm_anim.seek(0.0, true)
	var to_local: Transform3D = weapon_model.global_transform.affine_inverse()
	var zmax: float = 0.0
	var stack: Array[Node] = [weapon_model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		var nm: String = mi.name.to_lower()
		if nm.contains("arm") or nm.contains("hand") or nm.contains("finger") \
				or nm.contains("sleeve") or nm.contains("glove"):
			continue
		var aabb: AABB = mi.get_aabb()
		var xf: Transform3D = to_local * mi.global_transform
		for i in range(8):
			var corner: Vector3 = xf * (aabb.position + Vector3(
				aabb.size.x * float(i & 1),
				aabb.size.y * float((i >> 1) & 1),
				aabb.size.z * float((i >> 2) & 1)))
			zmax = maxf(zmax, corner.z)
	return zmax


## Play an authored viewmodel clip fitted to the gameplay timer. ADR-018: the
## timer is authoritative; the clip is presentation and stretches to match it.
func _play_vm_clip(clip: String, duration: float) -> void:
	if _vm_anim == null or not _vm_anim.has_animation(clip):
		return
	var clip_len: float = _vm_anim.get_animation(clip).length
	_vm_anim.speed_scale = clip_len / maxf(0.05, duration)
	_vm_anim.play(clip)


func _play_vm_idle() -> void:
	if _vm_anim == null:
		return
	_vm_anim.speed_scale = 1.0
	if _vm_anim.has_animation("rifle_idle"):
		_vm_anim.play("rifle_idle")


## Manual actions SHOW their cycle: the pump/bolt clip plays after every shot,
## stretched into the cycle time the fire_rate already enforces. Fire itself stays
## procedural (decree 2026-07-29) - the rack is the post-shot animation worth
## authoring, and until 2026-08-05 nothing ever called it outside the draw.
func _play_vm_rack() -> void:
	if _vm_anim == null or not _vm_anim.has_animation("charge_handle"):
		return
	var cycle: float = current_weapon.get_fire_delay() if current_weapon != null else 0.8
	_play_vm_clip("charge_handle", maxf(0.3, cycle * 0.85))
	if not _vm_anim.animation_finished.is_connected(_on_vm_rack_finished):
		_vm_anim.animation_finished.connect(_on_vm_rack_finished)


func _on_vm_rack_finished(anim_name: StringName) -> void:
	if anim_name != &"charge_handle":
		return
	if _vm_anim != null and _vm_anim.animation_finished.is_connected(_on_vm_rack_finished):
		_vm_anim.animation_finished.disconnect(_on_vm_rack_finished)
	_play_vm_idle()


## Drawing a rifle chambers it: rack the bolt once, then settle to idle.
func _play_vm_draw() -> void:
	if _vm_anim == null:
		return
	if not _vm_anim.has_animation("charge_handle"):
		_play_vm_idle()
		return
	_vm_anim.speed_scale = 1.0
	_vm_anim.play("charge_handle")
	if not _vm_anim.animation_finished.is_connected(_on_vm_draw_finished):
		_vm_anim.animation_finished.connect(_on_vm_draw_finished)


func _on_vm_draw_finished(anim_name: StringName) -> void:
	if anim_name != &"charge_handle":
		return
	if _vm_anim != null and _vm_anim.animation_finished.is_connected(_on_vm_draw_finished):
		_vm_anim.animation_finished.disconnect(_on_vm_draw_finished)
	_play_vm_idle()


## Load a weapon model from the weapon data
func _load_weapon_model(weapon_data: WeaponData) -> void:
	if weapon_model:
		weapon_model.queue_free()
		weapon_model = null
		_vm_anim = null
		_vm_meshes = []
		_recoil_pivot_z = 0.0

	if weapon_data and not weapon_data.model_path.is_empty():
		var scene := load(weapon_data.model_path)
		if scene:
			weapon_model = scene.instantiate()
			add_child(weapon_model)
			# THE VIEWMODEL LENS (ADR-034): real-scale mesh, drawn through its own
			# FOV by the lens shader. The bench goes through the same ViewmodelLens
			# calls, so what it shows is what ships by construction.
			if ViewmodelLens.ENABLED:
				_vm_meshes = ViewmodelLens.apply(weapon_model)
				ViewmodelLens.set_fov(_vm_meshes, ViewmodelLens.effective_fov(
					weapon_data.viewmodel_fov, camera.fov if camera else BASE_FOV))
			else:
				weapon_model.scale *= _lens_ratio(weapon_data)

			weapon_model.position = weapon_data.hip_position
			weapon_model.rotation_degrees = weapon_data.hip_rotation
			# Arms viewmodels need their idle clip played or the rig renders in bind pose.
			_vm_anim = weapon_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
			_recoil_pivot_z = _measure_recoil_pivot()
			_play_vm_draw()
			_scan_warhead(weapon_model)   # a fresh launcher comes loaded


func get_ads_amount() -> float:
	return ads_transition


func is_weapon_reloading() -> bool:
	return is_reloading


## AREA-SUPPRESSION RADIUS around the AIM POINT, for weapons whose effect is not one
## lane: buckshot 6m, warheads 8m.
func _calc_suppress_radius() -> float:
	if current_weapon == null:
		return 0.0
	if current_weapon.pellet_count > 1:
		return 6.0
	# Rockets / launchers. Bullets never reach here - they use the near-miss lane.
	return 8.0


## AREA-SUPPRESSION AMOUNT PER SHOT. Rockets and buckshot are heavy events.
func _calc_suppress_amount() -> float:
	if current_weapon == null:
		return 0.0
	if current_weapon.pellet_count > 1:
		return 0.35
	return 0.45


## How much bigger the gun reads when shot through its own (narrower) lens
## instead of the world's. 1.0 = no change; >1 = closer to the screen.
static func _lens_ratio(wd: WeaponData) -> float:
	if wd == null or wd.viewmodel_fov <= 1.0:
		return 1.0
	var world_half: float = tan(deg_to_rad(BASE_FOV) * 0.5)
	var vm_half: float = tan(deg_to_rad(wd.viewmodel_fov) * 0.5)
	return clampf(world_half / maxf(0.01, vm_half), 0.6, 2.2)


## Where hip-fired rounds spawn: the viewmodel's MuzzlePoint marker, falling
## back to the model's -Z, then to the camera.
func _get_muzzle_position() -> Vector3:
	if weapon_model:
		var muzzle: Node3D = weapon_model.find_child("MuzzlePoint", true, false) as Node3D
		if muzzle:
			return muzzle.global_position

		return weapon_model.global_position + weapon_model.global_transform.basis.z * -0.5

	return controller.get_camera_position()


## Cheap surface guess for impact FX: named/grouped hard surfaces spark, the
## rest puff dirt.
func _surface_is_hard(col: Object) -> bool:
	if col is Node:
		var n := col as Node
		if n.is_in_group("hard_surface"):
			return true
		var nm := str(n.name).to_lower()
		return "rock" in nm or "metal" in nm or "bunker" in nm or "vehicle" in nm or "truck" in nm
	return false
