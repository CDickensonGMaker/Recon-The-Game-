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
	if exfil_zone != null:
		if Input.is_action_pressed("radio") and GameManager.can_player_act():
			_abort_hold += delta
			if _abort_hold >= 2.0 and not state.emergency_exfil and not state.is_exfil_unlocked():
				state.emergency_exfil = true
				exfil_zone.force_unlock = true
				toast.emit("ABORT ACKNOWLEDGED - EMERGENCY EXFIL AUTHORIZED")
		else:
			_abort_hold = 0.0
	if Input.is_action_just_pressed("cas_strike") and GameManager.can_player_act():
		request_cas_strike()
	if Input.is_action_just_pressed("mortar_strike") and GameManager.can_player_act():
		request_mortar_strike()
	if Input.is_action_just_pressed("supply_drop") and GameManager.can_player_act():
		request_supply_drop()


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


## W53: mortar fire mission - spotting round, then the volley walks on.
var mortar_budget: int = 2
var _mortar_cooldown: float = 0.0


func request_mortar_strike() -> void:
	if squad_system != null and is_instance_valid(squad_system) and not squad_system.is_rto_alive():
		toast.emit("RADIO IS DEAD - NO FIRE MISSIONS")
		return
	if mortar_budget <= 0:
		toast.emit("MORTARS DRY")
		return
	if _cas_cooldown > 0.0 or _mortar_cooldown > 0.0:
		toast.emit("TUBE BUSY - STAND BY")
		return
	var target := _cas_ground_target()
	if target == Vector3.ZERO:
		toast.emit("NO TARGET - AIM AT THE GROUND")
		return
	mortar_budget -= 1
	_mortar_cooldown = 20.0
	toast.emit("FIRE MISSION - SPOT ROUND OUT (%d left)" % mortar_budget)
	# Spotting round at 3s, volley of 3 walking on at 6/7/8s.
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		_mortar_impact(target + Vector3(randf_range(-15, 15), 0, randf_range(-15, 15)), 0.5))
	for i in range(3):
		get_tree().create_timer(6.0 + float(i)).timeout.connect(func() -> void:
			_mortar_impact(target + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8)), 1.0))
	get_tree().create_timer(10.0).timeout.connect(func() -> void: _mortar_cooldown = 0.0)


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


func request_cas_strike() -> void:
	# W19: no radioman, no fast movers.
	if squad_system != null and is_instance_valid(squad_system) and not squad_system.is_rto_alive():
		toast.emit("RADIO IS DEAD - NO COMMS, NO AIR")
		return
	if cas_budget <= 0:
		toast.emit("NO AIR SUPPORT REMAINING")
		return
	if _cas_cooldown > 0.0:
		toast.emit("AIRCRAFT REARMING - STAND BY")
		return
	var target := _cas_ground_target()
	if target == Vector3.ZERO:
		toast.emit("NO TARGET - AIM AT THE GROUND")
		return
	cas_budget -= 1
	# W28: FO/FAC skill shortens the turnaround.
	_cas_cooldown = maxf(10.0, 25.0 - 2.0 * float(CampaignState.player_skill("fo_fac")))
	var plane: CASAirplane = SKYRAIDER_SCENE.instantiate()
	world.add_child(plane)
	var ordnance := CASAirplane.Ordnance.NAPALM if randf() < 0.5 else CASAirplane.Ordnance.BOMB
	var run_dir := Vector3.ZERO
	if world.player:
		run_dir = target - world.player.global_position
	plane.call_strike(world.terrain_manager, target, ordnance, run_dir)
	toast.emit("FAST MOVER INBOUND - DANGER CLOSE (%d runs left)" % cas_budget)


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
