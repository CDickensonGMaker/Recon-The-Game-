## pilot_recovery.gd - The downed-pilot chain (S28, his 8/7 ruling): the ZPU's
## kill roll comes here, a transiting Skyraider dives trailing smoke, the wreck
## and its smoke column stand where it hit, a surviving pilot waits beside it
## with a lazy VC picket nearby, and walking him back to the wire banks him.
##
## Period HUD decree: NO marker, NO objective text - the smoke column IS the
## waypoint; toasts are the radio, the same surface CampMortar uses.
## ONE airframe, ONE event per day - the S28 tripwire against the POW loop.
class_name PilotRecovery
extends Node

const WRECK_MODEL: String = "res://assets/us/aircraft/a1_skyraider_crashed.glb"
const PILOT_UNITS: Array[String] = ["us_pilot_white", "us_pilot_black"]
const PILOT_WEAPON: String = "res://data/weapons/m1911.tres"
## No event while the player finds his feet - same hold as CampMortar.HOLD_FIRE_S.
const HOLD_FIRE_S: float = 600.0
## The wreck lands a walk ahead of the dying plane, never on the compound.
const CRASH_AHEAD_M: float = 220.0
const WRECK_BURN_S: float = 1500.0
## He stands up for the man who came for him, not for a passer-by at 40m.
const WAKE_M: float = 12.0
const HOME_M: float = 30.0
## THE UNCONDITIONAL CLOCK. Neither phase had one, and encounter_active() suppresses every
## ambient encounter while this chain is live - so a pilot the player never walked out to
## silently killed the walking dice for the whole rest of the run, and the symptom read as
## "the encounters are boring", not "a system is stuck".
const WAIT_TIMEOUT_S: float = 420.0
const ESCORT_TIMEOUT_S: float = 420.0

enum Phase { IDLE, WAIT, ESCORT, DONE }

var director: FieldDirector = null
var world: GameWorld = null

var _phase: Phase = Phase.IDLE
var _elapsed: float = 0.0
## When the CURRENT phase began, so each one can time out on its own.
var _phase_since: float = 0.0
var _poll: float = 0.0
var _used: bool = false
var _pilot: AllyBase = null
var _column: Node3D = null
## Unseeded on purpose: the shoot-down is ambient life, not replayable layout
## (same exemption as AmbientWar/AirTraffic, demo_game.gd:9-11).
var _rng := RandomNumberGenerator.new()


static func attach(game_world: GameWorld, field_director: FieldDirector) -> PilotRecovery:
	var pr := PilotRecovery.new()
	pr.name = "PilotRecovery"
	pr.director = field_director
	pr.world = game_world
	game_world.add_child(pr)
	pr.add_to_group("pilot_recovery")
	return pr


## The ZPU's kill roll lands here; this node owns every gate that is about the
## DAY rather than the gun. Returns false when the flight escapes.
func request_down(plane: CASAirplane) -> bool:
	if _used or _elapsed < HOLD_FIRE_S:
		return false
	if plane == null or not is_instance_valid(plane) \
			or not plane.in_transit() or plane.is_shot_down():
		return false
	if director == null or not is_instance_valid(director) \
			or director.fsb_center == Vector3.ZERO:
		return false
	if director.siege != null and is_instance_valid(director.siege) and director.siege.active:
		return false
	# One ambient event at a time, AO-wide: the walking-dice encounters and this
	# chain share a single exclusivity gate (AmbientEncounters.encounter_active).
	for n in get_tree().get_nodes_in_group("ambient_encounters"):
		if n is AmbientEncounters and (n as AmbientEncounters).encounter_active():
			return false
	var ahead: Vector3 = plane.global_position + plane.run_dir() * CRASH_AHEAD_M
	var crash: Vector3 = MissionGenerator._passable_near(world, _rng, ahead, 40.0, 140.0, 90,
		SitePlanner.FSB_SITE_CLEARANCE)
	if crash == Vector3.ZERO:
		return false
	crash = MissionGenerator._seat(world, crash)
	_used = true
	plane.crashed.connect(_on_crashed, CONNECT_ONE_SHOT)
	plane.shoot_down(crash)
	director.toast.emit("SANDY'S HIT - HE'S GOING DOWN OVER THE TREES")
	print("[PILOT] skyraider downed at %.0fs, falling toward %s" % [_elapsed, crash])
	return true


## The other half of the shared gate: while the pilot chain is mid-flight,
## AmbientEncounters rolls nothing.
func encounter_active() -> bool:
	return _phase == Phase.WAIT or _phase == Phase.ESCORT


func _on_crashed(pos: Vector3) -> void:
	# ONE placement path (ADR-028): this file may not drive a stamp itself.
	var wreck: Node3D = MissionGenerator.place_event_prop(
		world, WRECK_MODEL, pos, _rng.randf_range(0.0, 360.0))
	_light_wreck_fires(wreck, pos)
	_column = _build_column(pos)
	var anchor: Node3D = wreck.find_child("pilot_anchor", true, false) as Node3D \
		if wreck != null else null
	_spawn_pilot(anchor.global_position if anchor != null else Vector3.ZERO, pos)
	_spawn_pickets(pos)
	_phase = Phase.WAIT
	_phase_since = _elapsed
	director.toast.emit("SMOKE COLUMN TO THE %s - THAT'S WHERE HE WENT IN"
		% _bearing8(director.fsb_center, pos))
	print("[PILOT] wreck at %s, pilot waiting" % pos)


## Tall black column over the jungle - the diegetic waypoint. Same GunFX sheet
## primitives as FireHazard's pillar (fire_hazard.gd:61-81), pushed taller.
func _build_column(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	world.add_child(root)
	root.global_position = pos
	if DisplayServer.get_name() == "headless":
		return root
	var smoke := GPUParticles3D.new()
	smoke.amount = 32
	smoke.lifetime = 12.0
	smoke.local_coords = false
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = 1.5
	proc.direction = Vector3.UP
	proc.spread = 6.0
	proc.initial_velocity_min = 4.0
	proc.initial_velocity_max = 7.0
	proc.gravity = Vector3(0.0, 0.6, 0.0)
	proc.scale_min = 3.0
	proc.scale_max = 6.0
	proc.color = Color(0.10, 0.09, 0.08)
	proc.color_ramp = GunFX._smoke_fade_ramp()
	smoke.process_material = proc
	smoke.draw_pass_1 = GunFX._fx_quad("crash_column_quad", 3.2,
		GunFX._sheet_mat("crash_column_mat", "sheets/smoke_loop_sheet", 4, 4, false))
	smoke.position.y = 2.0
	root.add_child(smoke)
	return root


## The wreck GLBs author their fire points and a swept pilot anchor (2026-08-13
## commission): fire_socket_* sit ON the wreck itself so danger lives inside the
## flames, and pilot_anchor is measured clear of every fire on open ground - his
## rescue doctrine ("high chance the AI will just have them run into the fire and
## it moots the point of saving them"). Both degrade to the old behavior on a
## wreck that ships without them.
func _light_wreck_fires(wreck: Node3D, pos: Vector3) -> void:
	var lit: int = 0
	if wreck != null:
		for i in range(1, 4):
			var sock := wreck.find_child("fire_socket_%d" % i, true, false) as Node3D
			if sock != null:
				FireHazard.create_at(world, sock.global_position, 2.5, WRECK_BURN_S)
				lit += 1
	if lit == 0:
		FireHazard.create_at(world, pos, 3.5, WRECK_BURN_S)


func _spawn_pilot(authored: Vector3, pos: Vector3) -> void:
	var seat: Vector3 = authored
	if seat == Vector3.ZERO:
		seat = MissionGenerator._passable_near(world, _rng, pos, 6.0, 14.0, 60)
	if seat == Vector3.ZERO:
		seat = pos + Vector3(6.0, 0.0, 0.0)
	seat = MissionGenerator._seat(world, seat) + Vector3.UP * 0.5
	_pilot = AllyBase.spawn_ally(world, seat)
	_pilot.squad_member = false
	_pilot.director = director
	_pilot.member = SquadRoster.generate_member(_rng, "RIFLEMAN")
	_pilot.weapon_data = load(PILOT_WEAPON) as WeaponData
	_pilot.set_sprite(PILOT_UNITS[_rng.randi() % PILOT_UNITS.size()], "m1911")
	_pilot.set_order(AllyBase.OrderMode.HOLD)


func _spawn_pickets(pos: Vector3) -> void:
	var at: Vector3 = MissionGenerator._passable_near(world, _rng, pos, 25.0, 60.0, 60)
	if at == Vector3.ZERO:
		return
	var lg := LazyGroup.new()
	lg.enemy_count = 3
	lg.group_tag = "wreck_pickets"
	lg.activation_range = 140.0
	lg.spread = 10.0
	lg.setup(director, hash(Vector2i(int(pos.x), int(pos.z))))
	world.add_child(lg)
	lg.global_position = MissionGenerator._seat(world, at)


func _physics_process(delta: float) -> void:
	_elapsed += minf(delta, 0.066)
	_poll += delta
	if _poll < 1.0:
		return
	_poll = 0.0
	match _phase:
		Phase.WAIT:
			_tick_wait()
		Phase.ESCORT:
			_tick_escort()
		_:
			pass


func _tick_wait() -> void:
	if _pilot == null or not is_instance_valid(_pilot) or _pilot.is_dead():
		_lose()
		return
	if _elapsed - _phase_since > WAIT_TIMEOUT_S:
		_lose()
		return
	var player: Node3D = GameManager.player as Node3D
	if player == null or not is_instance_valid(player):
		return
	if player.global_position.distance_to(_pilot.global_position) > WAKE_M:
		return
	_phase = Phase.ESCORT
	_phase_since = _elapsed
	_pilot.set_order(AllyBase.OrderMode.FOLLOW)
	director.toast.emit("GET ME BACK TO THE WIRE - I'LL KEEP UP")


func _tick_escort() -> void:
	if _pilot == null or not is_instance_valid(_pilot) or _pilot.is_dead():
		_lose()
		return
	if _elapsed - _phase_since > ESCORT_TIMEOUT_S:
		_lose()
		return
	if _pilot.global_position.distance_to(director.fsb_center) > HOME_M:
		return
	_recover()


func _recover() -> void:
	_phase = Phase.DONE
	_pilot.set_order(AllyBase.OrderMode.MOVE_TO, _ward_pos())
	director.state.flags["pilot_recovered"] = 1
	director.toast.emit("PILOT DELIVERED TO THE AID STATION - THAT'S ONE THEY DON'T GET")
	_clear_column()
	print("[PILOT] recovered at %.0fs" % _elapsed)


func _lose() -> void:
	_phase = Phase.DONE
	director.state.flags["pilot_lost"] = 1
	director.toast.emit("THE PILOT DIDN'T MAKE IT")
	_clear_column()
	print("[PILOT] lost at %.0fs" % _elapsed)


func _clear_column() -> void:
	if _column != null and is_instance_valid(_column):
		_column.queue_free()
	_column = null


## The aid-station cot from the same plan the garrison spawns from - one medical
## truth source, never a second marker.
func _ward_pos() -> Vector3:
	var plan: Dictionary = SitePlanner.fsb_garrison_plan(director.fsb_center)
	for occ in ["medic", "litter"]:
		for entry in (plan.get("posts", []) as Array):
			var post: Dictionary = entry
			if str(post.get("occupation", "")) == occ:
				return MissionGenerator._seat(world, post.get("pos", director.fsb_center) as Vector3)
	return director.fsb_center


static func _bearing8(from: Vector3, to: Vector3) -> String:
	var names: Array[String] = ["EAST", "SOUTHEAST", "SOUTH", "SOUTHWEST",
		"WEST", "NORTHWEST", "NORTH", "NORTHEAST"]
	var a: float = atan2(to.z - from.z, to.x - from.x)
	var idx: int = int(roundf(a / (TAU / 8.0))) % 8
	if idx < 0:
		idx += 8
	return names[idx]
