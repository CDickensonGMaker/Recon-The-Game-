## cas_airplane.gd - Close air support run: 4-phase dive-bomb, or a fast flyby.
## CRATER CAP: BOMB = 1 terrain deformation; the NAPALM strip deforms only its
## centre drop. Drops are staggered to spread the chunk rebuilds.
class_name CASAirplane
extends Node3D


## GUNS is a strafing pass; GUNS_NAPALM strafes in and pickles the strip at the bottom of it -
## the Summoner's own picture: "a sky flyby that is a machinegun run and a few napalm canisters
## dropped." Both fire REAL ROUNDS, see _fire_strafe_burst.
enum Ordnance { BOMB, NAPALM, CBU, GUNS, GUNS_NAPALM }
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

## ---- THE GUN RUN ----
## Rounds are REAL: muzzle spawn on the airframe, gravity, segment-raycast per tick, damage
## resolved at arrival through the same BulletSystem every rifle in the game uses.
##
## This replaces the older lie. SpectreGunship._fire_vulcan picks a point on the ground, paints
## three decorative tracers at it and applies a small explosion there - so the tracers carry no
## damage, and a man behind the berm is spared by a visibility guess rather than by the berm.
## Meanwhile the Spectre's Bofors already fires real arcing shells, so one aircraft held two
## different ideas of what a round is. Ruling, 2026-07-29: "what if we made the rounds from all
## planes real projectiles that travel from their points of origin."
##
## The strafe walks itself: rounds are aimed at the ground STRAFE_LEAD_M ahead of the aircraft,
## so impacts march up the run line as it closes, through the target, and past it.
const STRAFE_WEAPON: String = "res://data/weapons/aircraft_20mm.tres"
const STRAFE_OPEN_M: float = -260.0     ## `along` at which the guns open (negative = short)
const STRAFE_CLOSE_M: float = 50.0      ## and where they cease
const STRAFE_INTERVAL: float = 0.08
const STRAFE_ROUNDS_PER_BURST: int = 3
const STRAFE_LEAD_M: float = 160.0      ## slant point ahead the burst is aimed at
const STRAFE_SPREAD_M: float = 4.0      ## lateral scatter of the beaten path
## US airframe: world, enemy bodies, enemy hitzones and civilians - the same mask an ally
## rifle uses, so a strafing run is as indiscriminate as any other fire in this war.
const STRAFE_MASK: int = 1 | 32 | 64 | 512

static var _strafe_wd: WeaponData = null
var _gun_timer: float = 0.0


const JET_LOOP := preload("res://assets/audio/sfx/aircraft/jet_loop.wav")

var _engine: AudioStreamPlayer3D = null


## Built in _ready so every entry path gets it: call_strike, call_flyby and the
## AirTraffic transit overflight. A fast mover that arrives in silence is the
## single loudest hole in the air war.
func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_engine = AudioStreamPlayer3D.new()
	_engine.stream = JET_LOOP
	_engine.bus = "Vehicles" if AudioServer.get_bus_index("Vehicles") >= 0 else "SFX"
	_engine.max_distance = 1800.0
	_engine.unit_size = 85.0
	_engine.volume_db = 0.0
	_engine.max_db = 0.0
	_engine.attenuation_filter_cutoff_hz = 4000.0
	# Doppler is the whole drama of a low pass; Godot needs the physics tracker
	# because this node is moved from _physics_process.
	_engine.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	add_child(_engine)
	_engine.play()


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
		# GUNS FIRST. The strafe opens well short of the target and walks in, so by the time the
		# canisters leave the rack the ground is already being chewed.
		if _guns_hot():
			_gun_timer -= delta
			if _gun_timer <= 0.0 and along >= STRAFE_OPEN_M and along <= STRAFE_CLOSE_M:
				_gun_timer = STRAFE_INTERVAL
				_fire_strafe_burst()
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
		Ordnance.NAPALM, Ordnance.GUNS_NAPALM:
			_drop_napalm_strip()
		Ordnance.CBU:
			_drop_cluster()
		Ordnance.GUNS:
			pass          # the guns ARE the ordnance; nothing leaves the rack


func _guns_hot() -> bool:
	return _ordnance == Ordnance.GUNS or _ordnance == Ordnance.GUNS_NAPALM


## One burst of real rounds down the run line. Aimed at the ground ahead of the aircraft rather
## than at the target itself, so the beaten path WALKS as the plane closes - which is what makes
## a strafing run read as a strafing run instead of a stationary explosion.
func _fire_strafe_burst() -> void:
	if CombatManager.bullets == null:
		return
	if _strafe_wd == null:
		_strafe_wd = load(STRAFE_WEAPON) as WeaponData
	if _strafe_wd == null:
		push_warning("[CAS] %s missing - the gun run has no weapon card and fires nothing"
			% STRAFE_WEAPON)
		return
	# Muzzle on the nose, slightly under the fuselage.
	var muzzle: Vector3 = global_position + _run_dir * 4.0 + Vector3(0.0, -1.2, 0.0)
	var aim: Vector3 = global_position + _run_dir * STRAFE_LEAD_M
	aim.y = terrain.get_height_at(aim) if terrain != null else aim.y
	var across := Vector3(-_run_dir.z, 0.0, _run_dir.x)
	for i in range(STRAFE_ROUNDS_PER_BURST):
		var scatter: Vector3 = across * randf_range(-STRAFE_SPREAD_M, STRAFE_SPREAD_M) \
			+ _run_dir * randf_range(-STRAFE_SPREAD_M, STRAFE_SPREAD_M)
		var dir: Vector3 = ((aim + scatter) - muzzle).normalized()
		CombatManager.bullets.fire(_strafe_wd, self, muzzle, dir, STRAFE_MASK, [self], true)
	GunFX.muzzle_flash(get_tree().current_scene, muzzle)
	NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, aim, 0, 160.0)


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
		# Visual FIRST so a throw in the terrain/veg damage step can never abort the
		# fireball (the "plane flew by, no explosion" bug). Suppression is no longer
		# called here: apply_explosion_damage now suppresses for EVERY explosive, at the
		# same 16m -> 40m relationship this drop used to be the only one to get.
		GunFX.play_explosion_3d(get_tree().current_scene, impact, "explosion_heavy")
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
