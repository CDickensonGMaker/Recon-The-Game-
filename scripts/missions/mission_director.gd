## mission_director.gd - Owns MissionState, tracked spawning (the kill-count fix:
## every kill counts via EnemyBase.died, never CombatManager's broken path),
## objective completion, mission end states (NS07).
class_name MissionDirector
extends Node

signal objective_completed(index: int, title: String)
signal mission_completed(result: Dictionary)
signal mission_failed(result: Dictionary)
signal enemy_killed(enemy: EnemyBase, group_tag: String)
signal toast(text: String)

var state := MissionState.new()
var world: GameWorld
var _ended: bool = false
var _live_enemies: Array[EnemyBase] = []


func setup(game_world: GameWorld) -> void:
	world = game_world
	state.start_time_ms = Time.get_ticks_msec()
	if not GameManager.player_died.is_connected(_on_player_died):
		GameManager.player_died.connect(_on_player_died)
	state.objective_met.connect(_on_objective_met)


## Spawn an enemy seated on terrain and wire its death into mission counters.
func spawn_tracked_enemy(pos: Vector3, data_path: String, group_tag: String = "") -> EnemyBase:
	var seated := pos
	if world and world.terrain_manager:
		seated.y = world.terrain_manager.get_height_at(pos) + 0.5
	var parent: Node = world if world != null else get_parent()
	var enemy: EnemyBase = EnemyBase.spawn_enemy(parent, seated, data_path)
	enemy.died.connect(_on_enemy_died.bind(group_tag))
	_live_enemies.append(enemy)
	return enemy


func _on_enemy_died(enemy: EnemyBase, group_tag: String) -> void:
	state.record_kill()
	_live_enemies.erase(enemy)
	enemy_killed.emit(enemy, group_tag)
	# Escalation (PT): first blood wakes the AO - hunter patrols start converging.
	if not _escalation_active:
		_escalation_active = true
		_hunter_timer = randf_range(70.0, 110.0)


## Hunter escalation: after first contact, patrols move in looking for you.
## Finite pool - you can bleed the AO dry.
var _escalation_active: bool = false
var _hunter_timer: float = 0.0
var _hunter_pool: int = 12


func _process_escalation(delta: float) -> void:
	if not _escalation_active or _hunter_pool <= 0 or _ended or world == null or world.player == null:
		return
	_hunter_timer -= delta
	if _hunter_timer > 0.0:
		return
	_hunter_timer = randf_range(100.0, 160.0)
	var count: int = mini(_hunter_pool, randi_range(2, 4))
	_hunter_pool -= count
	var a: float = randf_range(0.0, TAU)
	var base: Vector3 = world.player.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(180.0, 230.0)
	base.x = clampf(base.x, 60.0, world.map_size - 60.0)
	base.z = clampf(base.z, 60.0, world.map_size - 60.0)
	for i in range(count):
		var pos := base + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
		var hunter := spawn_tracked_enemy(pos, "res://data/enemies/nva_regular.tres", "hunters")
		hunter.add_to_group("hunters")
		# They come looking: seed their search at your last position.
		hunter.last_known_target_pos = world.player.global_position
		hunter.target_last_seen_time = 0.0
		hunter._set_tier(EnemyBase.AlertTier.ALERT)
	toast.emit("MOVEMENT IN THE TREES - THEY'RE LOOKING FOR YOU")


func live_enemy_count(group_tag: String = "") -> int:
	if group_tag.is_empty():
		return _live_enemies.size()
	var count: int = 0
	for e in _live_enemies:
		if is_instance_valid(e) and e.is_in_group(group_tag):
			count += 1
	return count


func complete_objective(index: int) -> void:
	state.complete_objective(index)


func _on_objective_met(index: int) -> void:
	var title: String = str(state.objective_titles.get(index, "OBJECTIVE"))
	objective_completed.emit(index, title)
	toast.emit("OBJECTIVE COMPLETE: %s" % title)
	if state.is_exfil_unlocked():
		toast.emit("ALL OBJECTIVES COMPLETE - PROCEED TO EXFIL")


func finish_mission() -> void:
	if _ended:
		return
	_ended = true
	mission_completed.emit(state.build_result(true))


func fail_mission(reason: String) -> void:
	if _ended:
		return
	_ended = true
	mission_failed.emit(state.build_result(false, reason))


func _on_player_died() -> void:
	fail_mission("KIA")


## ABORT: hold the radio key 2s anywhere -> emergency exfil (fail-forward).
## CAS: press T while aiming at ground -> Skyraider run (budget-limited).
const SKYRAIDER_SCENE := preload("res://scenes/vehicles/skyraider.tscn")

var exfil_zone: ExfilZone
var cas_budget: int = 0
var _abort_hold: float = 0.0
var _cas_cooldown: float = 0.0


func _process(delta: float) -> void:
	if _ended:
		return
	_cas_cooldown = maxf(0.0, _cas_cooldown - delta)
	_process_escalation(delta)
	if exfil_zone != null:
		if Input.is_action_pressed("radio") and GameManager.can_player_act():
			_abort_hold += delta
			if _abort_hold >= 2.0 and not state.emergency_exfil and not state.is_exfil_unlocked():
				state.emergency_exfil = true
				exfil_zone.force_unlock = true
				toast.emit("ABORT ACKNOWLEDGED - EMERGENCY EXFIL AUTHORIZED")
		else:
			_abort_hold = 0.0
	# Fire-support menu (T opens, 1-5 selects while open, Y = mortar shortcut).
	if Input.is_action_just_pressed("cas_strike") and GameManager.can_player_act():
		fire_menu_open = not fire_menu_open
		fire_menu_changed.emit(fire_menu_open)
	if fire_menu_open and GameManager.can_player_act():
		if Input.is_action_just_pressed("slot_1"):
			request_fire_support("bombs")
		elif Input.is_action_just_pressed("slot_2"):
			request_fire_support("napalm")
		elif Input.is_action_just_pressed("slot_3"):
			request_fire_support("arty")
		elif Input.is_action_just_pressed("slot_4"):
			request_fire_support("mortar")
		elif Input.is_action_just_pressed("wheel_up") or Input.is_action_just_pressed("wheel_down"):
			pass  # keep wheel for kit even with menu open
		elif Input.is_action_just_pressed("pop_flare"):
			pass
		elif Input.is_action_just_pressed("throw_smoke"):
			request_fire_support("spooky")  # 5 = Spooky while menu is open
	if Input.is_action_just_pressed("mortar_strike") and GameManager.can_player_act():
		request_fire_support("mortar")
	if Input.is_action_just_pressed("supply_drop") and GameManager.can_player_act():
		request_supply_drop()


## Unified call-for-fire (PT): budgets per mission, all RTO-gated.
signal fire_menu_changed(open: bool)
static var any_fire_menu_open: bool = false  ## input guard for kit keys
var fire_menu_open: bool = false:
	set(value):
		fire_menu_open = value
		any_fire_menu_open = value
var fire_support: Dictionary = {"bombs": 0, "napalm": 0, "arty": 0, "mortar": 2, "spooky": 0}


func request_fire_support(kind: String) -> void:
	fire_menu_open = false
	fire_menu_changed.emit(false)
	if squad_system != null and is_instance_valid(squad_system) and not squad_system.is_rto_alive():
		toast.emit("RADIO IS DEAD - NO FIRE SUPPORT")
		return
	if int(fire_support.get(kind, 0)) <= 0:
		toast.emit("%s: NONE AVAILABLE" % kind.to_upper())
		return
	if _cas_cooldown > 0.0:
		toast.emit("NET BUSY - STAND BY")
		return
	var target := _cas_ground_target()
	if target == Vector3.ZERO:
		toast.emit("NO TARGET - AIM AT THE GROUND")
		return
	fire_support[kind] = int(fire_support[kind]) - 1
	_cas_cooldown = maxf(10.0, 25.0 - 2.0 * float(CampaignState.player_skill("fo_fac")))
	match kind:
		"bombs":
			_launch_cas(target, CASAirplane.Ordnance.BOMB)
			toast.emit("FAST MOVER INBOUND - SNAKE EYE (%d left)" % fire_support[kind])
		"napalm":
			_launch_cas(target, CASAirplane.Ordnance.NAPALM)
			toast.emit("NAPALM RUN INBOUND - GET BACK (%d left)" % fire_support[kind])
		"arty":
			toast.emit("BATTERY FIRE MISSION - SHOT OUT (%d left)" % fire_support[kind])
			for i in range(6):
				get_tree().create_timer(4.0 + float(i) * 0.7).timeout.connect(
					_arty_impact.bind(target + Vector3(randf_range(-18, 18), 0, randf_range(-18, 18)), i % 3 == 0))
		"mortar":
			_run_mortar_mission(target)
		"spooky":
			SpookyGunship.call_in(world, world.terrain_manager, target)
			toast.emit("SPOOKY ON STATION - 30 SECONDS OF RAIN (%d left)" % fire_support[kind])


func _launch_cas(target: Vector3, ordnance: CASAirplane.Ordnance) -> void:
	var plane: CASAirplane = SKYRAIDER_SCENE.instantiate()
	world.add_child(plane)
	var run_dir := Vector3.ZERO
	if world.player:
		run_dir = target - world.player.global_position
	plane.call_strike(world.terrain_manager, target, ordnance, run_dir)


func _arty_impact(pos: Vector3, deform: bool) -> void:
	if world == null:
		return
	var ground := pos
	ground.y = world.terrain_manager.get_height_at(pos)
	CombatManager.apply_explosion_damage(ground, 200, 60, 14.0, null)
	if deform:  # crater cap: 2 of 6 rounds deform
		DamageSystem.apply_damage(ground, DamageSystem.DamageType.MEDIUM_EXPLOSION, 0.9)
	GunFX.play_explosion_3d(get_tree().current_scene, ground)
	NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, ground, 0)


func _run_mortar_mission(target: Vector3) -> void:
	toast.emit("FIRE MISSION - SPOT ROUND OUT (%d left)" % fire_support["mortar"])
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		_mortar_impact(target + Vector3(randf_range(-15, 15), 0, randf_range(-15, 15)), 0.5))
	for i in range(3):
		get_tree().create_timer(6.0 + float(i)).timeout.connect(func() -> void:
			_mortar_impact(target + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8)), 1.0))


## W60: RTO-called resupply - pop smoke, bird drops a crate on it.
var supply_used: bool = false


func request_supply_drop() -> void:
	if squad_system != null and is_instance_valid(squad_system) and not squad_system.is_rto_alive():
		toast.emit("RADIO IS DEAD - NO RESUPPLY")
		return
	if supply_used:
		toast.emit("RESUPPLY ALREADY FLOWN")
		return
	if world == null or world.player == null:
		return
	# Needs your smoke on the ground nearby.
	var smoke_pos := Vector3.ZERO
	for cloud in SmokeCloud.active_clouds:
		if is_instance_valid(cloud) and cloud.global_position.distance_to(world.player.global_position) < 20.0:
			smoke_pos = cloud.global_position
			break
	if smoke_pos == Vector3.ZERO:
		toast.emit("POP SMOKE [5] FIRST - THE BIRD NEEDS A MARK")
		return
	supply_used = true
	toast.emit("RESUPPLY INBOUND ON YOUR SMOKE - 20 SECONDS")
	get_tree().create_timer(20.0).timeout.connect(func() -> void:
		_drop_supply_crate(smoke_pos))


func _drop_supply_crate(pos: Vector3) -> void:
	var crate := StaticBody3D.new()
	crate.collision_layer = 1
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 1.0, 1.2)
	col.shape = box
	col.position = Vector3(0, 0.5, 0)
	crate.add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 1.0, 1.2)
	mesh.mesh = bm
	mesh.position = Vector3(0, 0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.4, 0.28)
	mesh.material_override = mat
	crate.add_child(mesh)
	crate.add_to_group("supply_crates")
	world.add_child(crate)
	var ground := pos
	ground.y = world.terrain_manager.get_height_at(pos)
	crate.global_position = ground
	toast.emit("CRATE DOWN - [E] TO RESUPPLY")


func _mortar_impact(pos: Vector3, intensity: float) -> void:
	if world == null:
		return
	var ground := pos
	ground.y = world.terrain_manager.get_height_at(pos)
	CombatManager.apply_explosion_damage(ground, int(140 * intensity), 40, 10.0, null)
	if intensity >= 1.0:
		DamageSystem.apply_damage(ground, DamageSystem.DamageType.SMALL_EXPLOSION, intensity)
	GunFX.play_explosion_3d(get_tree().current_scene, ground)
	NoiseBus.emit_noise(NoiseBus.NoiseType.EXPLOSION, ground, 0)


var squad_system: SquadSystem = null


## March the camera ray onto the terrain surface.
func _cas_ground_target() -> Vector3:
	if world == null or world.player == null:
		return Vector3.ZERO
	var cam: Camera3D = world.player.get_node("Head/Camera3D")
	var origin: Vector3 = cam.global_position
	var dir: Vector3 = -cam.global_transform.basis.z
	for i in range(1, 60):
		var p := origin + dir * (float(i) * 8.0)
		var ground: float = world.terrain_manager.get_height_at(p)
		if p.y <= ground:
			return Vector3(p.x, ground, p.z)
	return Vector3.ZERO


func is_ended() -> bool:
	return _ended
