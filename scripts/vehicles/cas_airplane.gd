## cas_airplane.gd - Close air support run: 4-phase dive-bomb, or a fast flyby.
## CRATER CAP: BOMB = 1 terrain deformation; the NAPALM strip deforms only its
## centre drop. Drops are staggered to spread the chunk rebuilds.
class_name CASAirplane
extends Node3D


enum Ordnance { BOMB, NAPALM, CBU }
enum Phase { APPROACH, DIVE, CLIMB, DONE }

const APPROACH_ALT: float = 80.0
const RELEASE_ALT: float = 30.0
const SPEED: float = 120.0
const DROP_STAGGER: float = 0.4

# F-4 fast horizontal flyby profile (call_flyby).
const F4_SPEED: float = 250.0
const FLYBY_ALT: float = 34.0
const FLYBY_SPAWN_DIST: float = 200.0
const CLOUD_DECK_Y: float = 185.0
## How far into the fall the dispenser splits open.
const CBU_OPEN_FRAC: float = 0.45

const BOMB_SHELL: String = "res://data/projectiles/snakeye_bomb.tres"
const NAPALM_SHELL: String = "res://data/projectiles/napalm_canister.tres"
const CBU_SHELL: String = "res://data/projectiles/cbu_canister.tres"
const CBU_BOMBLET: String = "res://data/projectiles/cbu_bomblet.tres"

var terrain: TerrainManager
var phase: Phase = Phase.APPROACH
var _target: Vector3 = Vector3.ZERO
var _run_dir: Vector3 = Vector3.FORWARD
var _ordnance: Ordnance = Ordnance.BOMB
var _released: bool = false
var _climb_time: float = 0.0
var _flyby: bool = false
var _transit: bool = false
var _transit_agl: float = 60.0
var _transit_speed: float = SPEED


func call_strike(terrain_manager: TerrainManager, target: Vector3, ordnance: Ordnance, run_dir: Vector3 = Vector3.ZERO) -> void:
	terrain = terrain_manager
	_target = target
	_target.y = terrain.get_height_at(target)
	_ordnance = ordnance
	_run_dir = run_dir
	if _run_dir.length() < 0.1:
		_run_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	_run_dir.y = 0.0
	_run_dir = _run_dir.normalized()
	global_position = _target - _run_dir * 900.0 + Vector3(0, APPROACH_ALT, 0)
	global_position.y = maxf(global_position.y, terrain.get_height_at(global_position) + 40.0)
	look_at(global_position + _run_dir, Vector3.UP)
	phase = Phase.APPROACH


## Spawns FLYBY_SPAWN_DIST out, comes in low and fast, pickles on the pass, then
## climbs out into the cloud deck.
func call_flyby(terrain_manager: TerrainManager, target: Vector3, ordnance: Ordnance, run_dir: Vector3 = Vector3.ZERO) -> void:
	terrain = terrain_manager
	_target = target
	_target.y = terrain.get_height_at(target)
	_ordnance = ordnance
	_flyby = true
	_run_dir = run_dir
	if _run_dir.length() < 0.1:
		_run_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	_run_dir.y = 0.0
	_run_dir = _run_dir.normalized()
	global_position = _target - _run_dir * FLYBY_SPAWN_DIST + Vector3(0, FLYBY_ALT, 0)
	global_position.y = maxf(global_position.y, terrain.get_height_at(global_position) + FLYBY_ALT)
	look_at(global_position + _run_dir, Vector3.UP)
	phase = Phase.DIVE


## Ambient overflight for AirTraffic: crosses the AO from `from` to `to` holding
## `agl` above the ground, then despawns past the far end. Releases nothing —
## this airframe is transiting, not on a fire mission.
func call_transit(terrain_manager: TerrainManager, from: Vector3, to: Vector3,
		agl: float, speed: float) -> void:
	terrain = terrain_manager
	_transit = true
	_transit_agl = agl
	_transit_speed = speed
	_target = to
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	_run_dir = flat.normalized() if flat.length() > 0.1 else Vector3.FORWARD
	global_position = from
	look_at(global_position + _run_dir, Vector3.UP)


func _fly_transit(delta: float) -> void:
	global_position += _run_dir * _transit_speed * delta
	if terrain != null:
		var desired_y: float = terrain.get_height_at(global_position) + _transit_agl
		global_position.y = lerpf(global_position.y, desired_y, 1.5 * delta)
	if (global_position - _target).dot(_run_dir) > 0.0:
		phase = Phase.DONE
		queue_free()


func _physics_process(delta: float) -> void:
	if _transit:
		_fly_transit(delta)
		return
	if _flyby:
		_fly_flyby(delta)
		return
	match phase:
		Phase.APPROACH, Phase.DIVE:
			_fly_run(delta)
		Phase.CLIMB:
			global_position += (_run_dir * SPEED + Vector3(0, 30, 0)) * delta
			_climb_time += delta
			if _climb_time > 8.0:
				phase = Phase.DONE
				queue_free()
		Phase.DONE:
			pass


func _fly_run(delta: float) -> void:
	var flat_dist: float = Vector2(global_position.x - _target.x, global_position.z - _target.z).length()
	var desired_y: float = _target.y + APPROACH_ALT
	if flat_dist < 450.0:
		phase = Phase.DIVE
		desired_y = _target.y + RELEASE_ALT
	global_position += _run_dir * SPEED * delta
	global_position.y = lerpf(global_position.y, desired_y, 2.0 * delta)
	if phase == Phase.DIVE and not _released and flat_dist < 40.0:
		_released = true
		_release_ordnance()
		phase = Phase.CLIMB


## Flat, fast, low: pickle on the pass, then climb out and despawn into the cloud deck.
func _fly_flyby(delta: float) -> void:
	global_position += _run_dir * F4_SPEED * delta
	var along: float = (global_position - _target).dot(_run_dir)  # signed dist past target
	if phase != Phase.CLIMB:
		var desired_y: float = (terrain.get_height_at(global_position) + FLYBY_ALT) if terrain else global_position.y
		global_position.y = lerpf(global_position.y, desired_y, 3.0 * delta)
		if not _released and along >= -6.0:  # pickle just as it reaches the target
			_released = true
			_release_ordnance()
		if along > 20.0:  # past the target -> climb out
			phase = Phase.CLIMB
	else:
		global_position.y += 60.0 * delta
		if along > 100.0 and global_position.y >= CLOUD_DECK_Y:  # 100m+ past, into the clouds -> gone
			phase = Phase.DONE
			queue_free()


func _release_ordnance() -> void:
	match _ordnance:
		Ordnance.BOMB:
			_drop_bomb()
		Ordnance.NAPALM:
			_drop_napalm_strip()
		Ordnance.CBU:
			_drop_cluster()


## Seat a point on the ground and give the fall time from this aircraft down to it.
func _drop_solution(pos: Vector3) -> Dictionary:
	var ground := pos
	ground.y = terrain.get_height_at(pos) if terrain else pos.y
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var h: float = maxf(2.0, global_position.y - ground.y)
	return {"ground": ground, "time": sqrt(2.0 * h / g)}


func _release(shell_path: String, pos: Vector3, terminal: Callable) -> ProjectileBase:
	var data: ProjectileData = load(shell_path) as ProjectileData
	if data == null:
		return null
	var sol: Dictionary = _drop_solution(pos)
	return Ballistics.fire_arc(data, global_position, sol.ground, sol.time, terrain, terminal)


func _drop_bomb() -> void:
	_release(BOMB_SHELL, _target, func(impact: Vector3) -> void:
		# Visual + suppression FIRST so a throw in the terrain/veg damage step can
		# never abort the fireball (the "plane flew by, no explosion" bug).
		GunFX.play_explosion_3d(get_tree().current_scene, impact, "explosion_heavy")
		CombatManager.apply_suppression_in_area(impact, FirePlan.BOMB_SUPPRESS_M, 1.0)
		CombatManager.apply_explosion_damage(impact, 220, 60, FirePlan.BOMB_BLAST_M, null)
		DamageSystem.apply_damage(impact, DamageSystem.DamageType.LARGE_EXPLOSION, 1.0))


func _drop_napalm_strip() -> void:
	for i in range(FirePlan.NAPALM_DROPS):
		@warning_ignore("integer_division")
		var offset: float = float(i - FirePlan.NAPALM_DROPS / 2) * FirePlan.NAPALM_SPACING
		var pos := _target + _run_dir * offset
		@warning_ignore("integer_division")
		var is_center: bool = (i == FirePlan.NAPALM_DROPS / 2)
		# The rack pickles in sequence, and the aircraft has moved between each one.
		get_tree().create_timer(float(i) * DROP_STAGGER).timeout.connect(func() -> void:
			if not is_instance_valid(self):
				return
			_release(NAPALM_SHELL, pos, func(impact: Vector3) -> void:
				CombatManager.apply_explosion_damage(impact, 90, 30, FirePlan.NAPALM_BLAST_M, null)
				FireHazard.create_at(get_tree().current_scene, impact, FirePlan.NAPALM_BLAST_M, FirePlan.NAPALM_BURN_S)
				GunFX.play_explosion_3d(get_tree().current_scene, impact, "explosion_heavy")
				_ignite_nearby_structures(impact)
				if is_center:
					DamageSystem.apply_damage(impact, DamageSystem.DamageType.NAPALM, 1.0)))


## CBU dispenser: one canister off the rack that OPENS in the air, scattering
## bomblets across an ellipse along the run. One crater (honors the crater cap).
func _drop_cluster() -> void:
	var canister: ProjectileBase = _release(CBU_SHELL, _target, func(_p: Vector3) -> void: pass)
	if canister == null:
		return
	var sol: Dictionary = _drop_solution(_target)
	get_tree().create_timer(float(sol.time) * CBU_OPEN_FRAC).timeout.connect(func() -> void:
		if is_instance_valid(canister) and canister.is_active:
			_open_cluster(canister.global_position)
			canister.expire_now())


func _open_cluster(from: Vector3) -> void:
	var data: ProjectileData = load(CBU_BOMBLET) as ProjectileData
	if data == null:
		return
	var side := _run_dir.cross(Vector3.UP).normalized()
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	for i in range(FirePlan.CBU_BOMBLETS):
		var ang := TAU * float(i) / float(FirePlan.CBU_BOMBLETS) + randf() * 0.6
		var rad := FirePlan.CBU_SPREAD * sqrt(randf())
		var pos := _target + _run_dir * (rad * cos(ang)) + side * (rad * FirePlan.CBU_CROSS_FRAC * sin(ang))
		var ground := pos
		ground.y = terrain.get_height_at(pos) if terrain else pos.y
		var t: float = sqrt(2.0 * maxf(2.0, from.y - ground.y) / g)
		var is_first := (i == 0)
		Ballistics.fire_arc(data, from, ground, t, terrain, func(impact: Vector3) -> void:
			CombatManager.apply_explosion_damage(impact, 55, 15, FirePlan.CBU_BOMBLET_BLAST_M, null)
			GunFX.play_explosion_3d(get_tree().current_scene, impact, "explosion_grenade")
			if is_first:
				DamageSystem.apply_damage(impact, DamageSystem.DamageType.MEDIUM_EXPLOSION, 0.7))


## Nearby thatch huts catch too: a bigger, longer-lived blaze at the structure.
func _ignite_nearby_structures(impact: Vector3) -> void:
	for s in get_tree().get_nodes_in_group("flammable_structures"):
		var structure := s as Node3D
		if structure == null or structure.has_meta("burned"):
			continue
		if structure.global_position.distance_to(impact) > 14.0:
			continue
		structure.set_meta("burned", true)
		FireHazard.create_at(get_tree().current_scene, structure.global_position, 6.0, 40.0)
