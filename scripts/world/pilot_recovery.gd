## pilot_recovery.gd - The downed-aircraft chain (S28, his 8/7 ruling; the slick, his 9/14
## ruling): the ZPU's kill roll comes here, an airframe goes in trailing fire, the wreck and its
## smoke column stand where it hit, the men who lived wait beside it, and walking them back to
## the wire banks them.
##
## Two airframes, one chain. The open world's Skyraider carries one pilot and the kill is the
## gun's 35% roll. The demo's slick is the 11:30 pad cycle with its own aircrew and stick aboard
## (HeliLift); it is TAKEN, the roll is who lives - pilots one or two of two, pax one to four of
## the stick - seeded from the mission so the same day loses the same men, and the survivors
## FOLLOW the player home at the slowest man's pace. Nobody is minted at the wreck: the men who
## walk in are the men who were seated on the ship.
##
## Period HUD decree: NO marker, NO objective text - the smoke column IS the waypoint; toasts
## are the radio, the same surface CampMortar uses. ONE airframe, ONE event per day - the S28
## tripwire against the POW loop.
class_name PilotRecovery
extends Node

## Preloaded, not by class_name: a global class is not registered until the editor rescans.
const HmLedgerS := preload("res://scripts/world/hm_ledger.gd")

const WRECK_MODEL: String = "res://assets/us/aircraft/a1_skyraider_crashed.glb"
const SLICK_WRECK_MODEL: String = "res://assets/us/aircraft/huey_crashed.glb"
## The slick's cargo - the mail sack - thrown clear of the hull. DealerTable's dealer/sack.
const SLICK_SACK_MODEL: String = "res://assets/us/props/interior/fb_c_ration_case.glb"
const SLICK_SACK_OFF_M: float = 5.0
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
## A led group of wounded men walks slower than one pilot; the escort clock allows for it.
const SLICK_ESCORT_TIMEOUT_S: float = 720.0

## The slick's crash site: this fraction of the camp's distance from the firebase, turned this
## far off the camp's bearing - out of the gun's own yard, inside its reach, on the side of the
## AO the day's walk faces. The site is then the nearest passable ground outside the wire's
## clearance, seeded (ADR-010).
const SLICK_SITE_FRAC: float = 0.85
const SLICK_SITE_TURNS_DEG: Array[float] = [50.0, 65.0, 80.0, 95.0, 110.0]
const SLICK_SITE_MIN_M: float = 200.0
const SLICK_SITE_MAX_M: float = 340.0
## Inside the gun's reach (420 m) so the tracers are real, outside the camp's own yard so the
## men who lived are not standing in its guards' sight: the wreck is a walk from the camp, not
## a room of it.
const SLICK_SITE_GUN_MIN_M: float = 150.0
## The group holds when the player outruns it - they do not chase him across the AO - and
## says so once before it does.
const SLICK_LAG_M: float = 40.0
const SLICK_HOLD_M: float = 60.0
## The living are put down this far from the hull, past the airframe's blast (10 m) and its
## fires, on the anchor's side of the wreck; the dead fall where they sat.
const SURVIVOR_STANDOFF_M: float = 16.0
## A led man the player cannot see, who has not moved for this long while his slot is out of
## reach, is MOVED behind the player - the squad's own catch-up (SquadSystem._catchup_tick),
## worn by men who are not squad. The wounded are not exempt: a man stuck on the berm all
## afternoon is a worse lie than a man who was behind the tree the whole time.
const STUCK_SNAP_S: float = 8.0
const STUCK_SPEED_MPS: float = 0.3
const STUCK_SLOT_M: float = 6.0
## Wounded bands: HIT / CRIT, as hp fractions and walking pace.
const WOUND_HP: Array[float] = [1.0, 0.55, 0.30]
const WOUND_SPEED: Array[float] = [1.0, 0.6, 0.35]
## Pickets at the wreck by the nearest village's reading of the player: quiet / wary / hostile.
const PICKETS_BY_BAND: Dictionary = {&"quiet": 2, &"wary": 3, &"hostile": 5}

const TASKING_ID: String = "hq/downed_bird"

## The radio and the men, in period voice. Every line is a subject, never a quantity
## (ADR-038 section 2a); tests/test_hearts_felt greps this table like FieldDirector.HM_LINES.
const CRASH_LINES: Dictionary = {
	"hit": "PINK PANTHER: GRAPE, PINK PANTHER, TAKING FIRE FROM THE VILLE. MULTI-BARREL. WE'RE HIT, WE'RE HIT.",
	"going_in": "PINK PANTHER: SMOKE IN THE CABIN. I'M LOSING HER. GOING IN SOUTH OF THE PADDIES.",
	"souls": "GRAPE: PINK PANTHER, GRAPE. SAY SOULS ON BOARD. PINK PANTHER, GRAPE, HOW COPY.",
	"any_station": "GRAPE: ANY STATION THIS NET. SLICK DOWN SOUTH OF THE VILLE. NEAREST GROUND ELEMENT, SOUND OFF.",
	"tasking": "GRAPE: YOUR ELEMENT IS CLOSEST. GET TO THAT BIRD. BRING ME EVERYBODY WHO'S BREATHING.",
	"no_dustoff": "GRAPE: DUSTOFF WON'T COME IN ON A HOT SITE. YOU'RE THE RIDE HOME. GRAPE OUT.",
	"pilot": "PILOT: I PUT HER DOWN. I PUT HER DOWN. WHERE'S MY CREW CHIEF.",
	"copilot": "COPILOT: SHE WAS FINE. SHE WAS FINE ALL MORNING.",
	"gunner": "GUNNER: THE GUN'S STILL GOOD. THEY'LL COME FOR THE BIRD. THEY ALWAYS COME FOR THE BIRD.",
	"pax": "PAX: I AIN'T EVEN BEEN TO MY UNIT YET.",
	"lag": "PILOT: GO ON. LEAVE ME THE PISTOL. I'LL SIT HERE AND WAIT ON DUSTOFF.",
	"stayed": "PILOT: THEN GET UNDER MY ARM AND DON'T STOP FOR ANYTHING.",
	"ville": "GUNNER: THAT GUN CAME OUT OF THE VILLE. SOMEBODY DUG THE HOLE FOR IT. YOU TELL ME WHO.",
	"home": "TOC: THAT'S ONE THEY DON'T GET. GET THE CREW TO THE DOC.",
	"rest": "TOC: THEY'RE INSIDE THE WIRE. THE REST ARE STILL OUT THERE.",
	"lost": "THE PILOT DIDN'T MAKE IT.",
}

enum Phase { IDLE, WAIT, ESCORT, DONE }

var director: FieldDirector = null
var world: GameWorld = null

var _phase: Phase = Phase.IDLE
var _elapsed: float = 0.0
## When the CURRENT phase began, so each one can time out on its own.
var _phase_since: float = 0.0
var _poll: float = 0.0
var _used: bool = false
var _column: Node3D = null
## The men beside the wreck: one pilot for the Skyraider, the roll's survivors for the slick.
var _men: Array[AllyBase] = []
var _slick: bool = false
var _slick_heli: Helicopter = null
var _planned_site: Vector3 = Vector3.ZERO
var _planned: bool = false
var _holding: bool = false
var _lag_said: bool = false
var _ville_said: bool = false
var _registered: int = 0
var _escort_timeout: float = ESCORT_TIMEOUT_S
var _still_s: Dictionary = {}
## The incident, one record: what was aboard, who lived, who walked in. Read by the end card,
## the probe and the observatory; never a HUD number.
var incident: Dictionary = {}
## The mail sack at the wreck until a man picks it up (DealerTable.pick_up_sack).
var crash_sack: Node3D = null
## Unseeded on purpose: the Skyraider shoot-down is ambient life, not replayable layout
## (same exemption as AmbientWar/AirTraffic, demo_game.gd:9-11).
var _rng := RandomNumberGenerator.new()
## The slick is authored: its site, its roll and its men repeat per mission seed (ADR-010).
var _slick_rng := RandomNumberGenerator.new()


static func attach(game_world: GameWorld, field_director: FieldDirector) -> PilotRecovery:
	var pr := PilotRecovery.new()
	pr.name = "PilotRecovery"
	pr.director = field_director
	pr.world = game_world
	game_world.add_child(pr)
	pr.add_to_group("pilot_recovery")
	pr._slick_rng.seed = hash(game_world.mission_seed) ^ hash("huey/day1")
	return pr


## Every gate that is about the DAY rather than the gun, shared by both airframes.
func _day_allows() -> bool:
	if _used or _elapsed < HOLD_FIRE_S:
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
	return true


## The ZPU's kill roll lands here; returns false when the flight escapes.
func request_down(plane: CASAirplane) -> bool:
	if not _day_allows():
		return false
	if plane == null or not is_instance_valid(plane) \
			or not plane.in_transit() or plane.is_shot_down():
		return false
	var ahead: Vector3 = plane.global_position + plane.run_dir() * CRASH_AHEAD_M
	var crash: Vector3 = MissionGenerator._passable_near(world, _rng, ahead, 40.0, 140.0, 90,
		SitePlanner.FSB_SITE_CLEARANCE)
	if crash == Vector3.ZERO:
		return false
	crash = MissionGenerator._seat(world, crash)
	_used = true
	_slick = false
	plane.crashed.connect(_on_crashed, CONNECT_ONE_SHOT)
	plane.shoot_down(crash)
	director.toast.emit("SANDY'S HIT - HE'S GOING DOWN OVER THE TREES")
	print("[PILOT] skyraider downed at %.0fs, falling toward %s" % [_elapsed, crash])
	return true


## ---- THE SLICK (demo mode) ----

## Where the demo's slick will fall, or ZERO when this day has no such event: not the demo,
## already used, no camp gun to take it, or no passable ground on the bearing. AirTraffic
## flies the pad cycle's inbound leg over this point; the gun sees the leg and calls here.
func planned_crash_site() -> Vector3:
	if not GameFlow.demo_mode or _used:
		return Vector3.ZERO
	if _planned:
		return _planned_site
	_planned = true
	if director == null or not is_instance_valid(director) or director.fsb_center == Vector3.ZERO \
			or world == null:
		return Vector3.ZERO
	var gun: Vector3 = _camp_gun_pos()
	if gun == Vector3.ZERO:
		return Vector3.ZERO
	var fsb: Vector3 = director.fsb_center
	var to_gun := Vector3(gun.x - fsb.x, 0.0, gun.z - fsb.z)
	if to_gun.length() < 1.0:
		return Vector3.ZERO
	var radius: float = clampf(to_gun.length() * SLICK_SITE_FRAC, SLICK_SITE_MIN_M, SLICK_SITE_MAX_M)
	var site: Vector3 = Vector3.ZERO
	for turn in SLICK_SITE_TURNS_DEG:
		var dir: Vector3 = to_gun.normalized().rotated(Vector3.UP, deg_to_rad(turn))
		var want: Vector3 = fsb + dir * radius
		var found: Vector3 = MissionGenerator._passable_near(world, _slick_rng, want, 10.0, 60.0, 90,
			SitePlanner.FSB_SITE_CLEARANCE)
		if found == Vector3.ZERO:
			continue
		if Vector2(found.x - gun.x, found.z - gun.z).length() < SLICK_SITE_GUN_MIN_M:
			continue
		site = found
		break
	if site == Vector3.ZERO:
		print("[PILOT] no passable ground for the slick off the gun at %s - no shoot-down today" % gun)
		return Vector3.ZERO
	_planned_site = MissionGenerator._seat(world, site)
	print("[PILOT] the slick will fall at %s (%.0fm from the wire, off the gun at %s)"
		% [_planned_site, fsb.distance_to(_planned_site), gun])
	return _planned_site


func _camp_gun_pos() -> Vector3:
	for n in get_tree().get_nodes_in_group("zpu_guns"):
		var zg := n as ZpuGun
		if zg != null and is_instance_valid(zg) and not zg.ambient:
			return zg.global_position
	return Vector3.ZERO


## The gun asks before it rolls: this ship, today?
func wants_slick(heli: Helicopter) -> bool:
	if heli == null or not is_instance_valid(heli) or heli.is_shot_down():
		return false
	if heli.state != Helicopter.State.FLYING:
		return false
	if heli.get_node_or_null("HeliLift") == null:
		return false
	if planned_crash_site() == Vector3.ZERO:
		return false
	return _day_allows()


func request_down_heli(heli: Helicopter) -> bool:
	if not wants_slick(heli):
		return false
	var site: Vector3 = planned_crash_site()
	_used = true
	_slick = true
	_slick_heli = heli
	_escort_timeout = SLICK_ESCORT_TIMEOUT_S
	heli.crashed.connect(_on_slick_crashed, CONNECT_ONE_SHOT)
	heli.shoot_down(site)
	director.toast.emit(String(CRASH_LINES["hit"]))
	_say_later("going_in", 4.0)
	_say_later("souls", 9.0)
	print("[PILOT] slick hit at %.0fs, doomed toward %s" % [_elapsed, site])
	return true


func _say_later(key: String, delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if is_instance_valid(self) and director != null and is_instance_valid(director):
			director.toast.emit(String(CRASH_LINES[key])))


## The other half of the shared gate: while the chain is mid-flight, AmbientEncounters rolls
## nothing.
func encounter_active() -> bool:
	return _phase == Phase.WAIT or _phase == Phase.ESCORT


## ---- THE WRECK ----

func _on_crashed(pos: Vector3) -> void:
	# ONE placement path (ADR-028): this file may not drive a stamp itself.
	var wreck: Node3D = MissionGenerator.place_event_prop(
		world, WRECK_MODEL, pos, _rng.randf_range(0.0, 360.0))
	_light_wreck_fires(wreck, pos)
	_column = _build_column(pos)
	var anchor: Node3D = wreck.find_child("pilot_anchor", true, false) as Node3D \
		if wreck != null else null
	_spawn_pilot(anchor.global_position if anchor != null else Vector3.ZERO, pos)
	_spawn_pickets(pos, 3)
	_begin_wait(pos)
	director.toast.emit("SMOKE COLUMN TO THE %s - THAT'S WHERE HE WENT IN"
		% _bearing8(director.fsb_center, pos))
	print("[PILOT] wreck at %s, pilot waiting" % pos)


func _on_slick_crashed(pos: Vector3) -> void:
	var heli: Helicopter = _slick_heli
	var lift: HeliLift = heli.get_node_or_null("HeliLift") as HeliLift \
		if heli != null and is_instance_valid(heli) else null
	var aboard: Array[Civilian] = lift.aboard() if lift != null else []
	var crew_n: int = lift.crew_count() if lift != null else 0
	var yaw: float = rad_to_deg(heli.rotation.y) if heli != null and is_instance_valid(heli) else 0.0
	var wreck: Node3D = MissionGenerator.place_event_prop(world, SLICK_WRECK_MODEL, pos, yaw)
	_light_wreck_fires(wreck, pos)
	_column = _build_column(pos)
	var anchor_node: Node3D = wreck.find_child("pilot_anchor", true, false) as Node3D \
		if wreck != null else null
	var anchor: Vector3 = anchor_node.global_position if anchor_node != null \
		else MissionGenerator._seat(world, pos + Vector3(6.0, 0.0, 0.0))
	_roll_survivors(heli, aboard, crew_n, anchor, pos)
	place_crash_sack(pos, yaw)
	if lift != null:
		lift.mark_crashed()
	if heli != null and is_instance_valid(heli):
		heli.queue_free.call_deferred()
	_slick_heli = null
	var band: StringName = _nearest_village_band(pos)
	_spawn_pickets(pos, int(PICKETS_BY_BAND.get(band, 3)))
	_begin_wait(pos)
	director.toast.emit("SMOKE COLUMN TO THE %s - THAT'S WHERE SHE WENT IN"
		% _bearing8(director.fsb_center, pos))
	_say_later("any_station", 6.0)
	_say_later("no_dustoff", 16.0)
	CampaignState.issue_tasking(TASKING_ID, "hq", SimClock.sim_hour)
	director.raise_crisis({"pos": pos, "kind": "downed_bird"})
	print("[PILOT] slick wreck at %s: aboard %d, alive %d (%d wounded), dead %d, band %s, pickets %d"
		% [pos, int(incident.aboard), int(incident.alive), int(incident.wounded),
			int(incident.dead), String(band), int(PICKETS_BY_BAND.get(band, 3))])


## The sack lies off the tail, seated on the ground; incident.crash_sack_pos is where.
func place_crash_sack(pos: Vector3, yaw: float) -> Node3D:
	if world == null or crash_sack != null:
		return crash_sack
	var back: Vector3 = Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, deg_to_rad(yaw)) * SLICK_SACK_OFF_M
	var at: Vector3 = MissionGenerator._seat(world, pos + back)
	crash_sack = MissionGenerator.place_event_prop(world, SLICK_SACK_MODEL, at, yaw)
	incident["crash_sack_pos"] = at
	return crash_sack


## The roll (his ruling 2026-09-14): pilots one or two of the two aboard, pax one to four of the
## stick, wounded among the living. Seeded per mission: the same day loses the same men. The
## dead fall where the ship did; the living are the ship's own men, promoted in place
## (GarrisonDefender: one hand-off, no second body), holding by the wreck.
func _roll_survivors(heli: Helicopter, aboard: Array[Civilian], crew_n: int,
		anchor: Vector3, pos: Vector3) -> void:
	var lift: HeliLift = heli.get_node_or_null("HeliLift") as HeliLift 		if heli != null and is_instance_valid(heli) else null
	var seats: SeatSystem = lift.cabin() if lift != null else null
	var pilots: Array[Civilian] = []
	var pax: Array[Civilian] = []
	for i in aboard.size():
		if i < crew_n:
			pilots.append(aboard[i])
		else:
			pax.append(aboard[i])
	var pilots_alive: int = mini(pilots.size(), 1 + (1 if _slick_rng.randf() < 0.5 else 0))
	var pax_alive: int = 0
	if not pax.is_empty():
		pax_alive = _slick_rng.randi_range(1, mini(4, pax.size()))
	var alive_n: int = pilots_alive + pax_alive
	var wounded_n: int = _slick_rng.randi_range(0, maxi(0, alive_n - 1))
	var crit_slot: int = _slick_rng.randi_range(0, maxi(0, wounded_n - 1)) if (alive_n >= 3 and wounded_n > 0) else -1
	incident = {"id": "huey/day1", "crash_pos": pos, "aboard": aboard.size(),
		"pilots_aboard": pilots.size(), "pilots_alive": pilots_alive, "pax_alive": pax_alive,
		"alive": alive_n, "wounded": wounded_n, "dead": aboard.size() - alive_n,
		"walked_in": 0, "phase": "wait"}
	director.state.flags["crash_aboard"] = aboard.size()
	director.state.flags["crash_alive"] = alive_n
	director.state.flags["crash_kia"] = aboard.size() - alive_n
	var ordered: Array[Civilian] = []
	ordered.append_array(pilots)
	ordered.append_array(pax)
	var roles: Array[String] = []
	for i in pilots.size():
		roles.append("pilot" if i == 0 else "copilot")
	for i in pax.size():
		roles.append("gunner" if i == 0 else "pax")
	var wounded_left: int = wounded_n
	var alive_seen: int = 0
	# On the HOME side of the hull: the wreck's collider is a 20 m box with no navmesh around
	# it, so the men must never have the airframe between them and the man who comes for them.
	var out_dir := Vector3(director.fsb_center.x - pos.x, 0.0, director.fsb_center.z - pos.z)
	if out_dir.length() < 0.5:
		out_dir = Vector3(anchor.x - pos.x, 0.0, anchor.z - pos.z)
	out_dir = out_dir.normalized() if out_dir.length() > 0.5 else Vector3(1.0, 0.0, 0.0)
	var standoff: Vector3 = pos + out_dir * SURVIVOR_STANDOFF_M
	for i in ordered.size():
		var civ: Civilian = ordered[i]
		if civ == null or not is_instance_valid(civ):
			continue
		var lives: bool = (i < pilots.size() and i < pilots_alive) \
			or (i >= pilots.size() and i - pilots.size() < pax_alive)
		var ground: Vector3
		if lives:
			var a: float = TAU * float(alive_seen) / float(maxi(alive_n, 1))
			ground = standoff + Vector3(cos(a), 0.0, sin(a)) * 1.6
		else:
			ground = pos + out_dir.rotated(Vector3.UP, 0.8 * float(i)) * 3.0
		ground = MissionGenerator._seat(world, ground)
		var seat_name: StringName = seats.seat_of(civ) if seats != null else &""
		if seat_name != &"":
			seats.unseat(civ, ground)
		else:
			print("[PILOT] %s was aboard but not seated (seats %s) - put down by hand" % [civ.name, str(seats != null)])
			civ.global_position = ground
		# The ride out is over whatever the seat or the watchdog left switched off.
		civ.set_physics_process(true)
		civ.set_process(true)
		civ.visible = true
		if not lives:
			director.state.flags["crash_kia_placed"] = int(director.state.flags.get("crash_kia_placed", 0)) + 1
			civ.take_damage(999, Enums.DamageType.PHYSICAL, null)
			continue
		var ally: AllyBase = GarrisonDefender.promote(civ, director, director.fsb_center)
		if ally == null:
			print("[PILOT] a survivor could not be stood up (garrison %s, state %d, physics %s, puppet %s)"
				% [str(civ.is_garrison), int(civ.state), str(civ.is_physics_processing()), str(civ.puppet)])
			continue
		ally.director = director
		ally.set_meta("crash_role", roles[i])
		if roles[i] == "pilot" or roles[i] == "copilot":
			ally.weapon_data = load(PILOT_WEAPON) as WeaponData
			var unit: String = str(ally.get_meta("garrison_unit", ""))
			if not unit.is_empty():
				ally.set_sprite(unit, "m1911")
		var band: int = 0
		if wounded_left > 0:
			band = 2 if alive_seen == crit_slot else 1
			wounded_left -= 1
		ally.set_meta("crash_wound", band)
		if band > 0:
			ally.current_hp = maxi(1, int(float(ally.max_hp) * WOUND_HP[band]))
			ally.move_speed *= WOUND_SPEED[band]
		ally.file_slot = _men.size() + 1
		ally.point_slot = false
		ally.defense_zone = ally.global_position
		ally.set_order(AllyBase.OrderMode.HOLD, ally.global_position)
		print("[PILOT] %s stands %.1f m off the hull at %s (put down at %s)"
			% [roles[i], pos.distance_to(ally.global_position), ally.global_position, ground])
		_men.append(ally)
		alive_seen += 1


func _begin_wait(_pos: Vector3) -> void:
	_phase = Phase.WAIT
	_phase_since = _elapsed
	_holding = false


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
	var pilot: AllyBase = AllyBase.spawn_ally(world, seat)
	pilot.squad_member = false
	pilot.director = director
	pilot.member = SquadRoster.generate_member(_rng, "RIFLEMAN")
	pilot.weapon_data = load(PILOT_WEAPON) as WeaponData
	pilot.set_sprite(PILOT_UNITS[_rng.randi() % PILOT_UNITS.size()], "m1911")
	pilot.set_meta("crash_role", "pilot")
	pilot.set_meta("crash_wound", 0)
	pilot.set_order(AllyBase.OrderMode.HOLD)
	_men.append(pilot)
	incident = {"id": "sandy", "crash_pos": pos, "aboard": 1, "alive": 1, "wounded": 0,
		"dead": 0, "walked_in": 0, "phase": "wait"}


func _spawn_pickets(pos: Vector3, count: int) -> void:
	if count <= 0:
		return
	var at: Vector3 = MissionGenerator._passable_near(world, _rng, pos, 25.0, 60.0, 60)
	if at == Vector3.ZERO:
		return
	var lg := LazyGroup.new()
	lg.enemy_count = count
	lg.group_tag = "wreck_pickets"
	lg.activation_range = 140.0
	lg.spread = 10.0
	lg.setup(director, hash(Vector2i(int(pos.x), int(pos.z))))
	world.add_child(lg)
	lg.global_position = MissionGenerator._seat(world, at)


func _nearest_village_band(pos: Vector3) -> StringName:
	var best: Vector3 = Vector3.ZERO
	var best_d: float = INF
	for n in AgentRegistry.civilians:
		var civ: Civilian = n as Civilian
		if civ == null or not is_instance_valid(civ) or civ.village_center == Vector3.ZERO:
			continue
		var d: float = pos.distance_to(civ.village_center)
		if d < best_d:
			best_d = d
			best = civ.village_center
	if best == Vector3.ZERO:
		return HmLedgerS.BAND_QUIET
	return CampaignState.hearts.band(HmLedgerS.place_key(best))


## ---- THE WAIT AND THE WALK ----

## Ledger span for this script's whole physics step - the 2026-09-11 audit read 100+ of 150
## physics steps over 20 ms mid-assault with the named spans summing to ~3 ms of them.
## The step name is per script on purpose: a shared virtual name would let a subclass's
## body be dispatched from its parent's wrapper.
func _physics_process(delta: float) -> void:
	StallLedger.begin("phys.pilot_recovery")
	_physics_step_pilot_recovery(delta)
	StallLedger.end()


func _physics_step_pilot_recovery(delta: float) -> void:
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


func _prune_dead() -> void:
	for i in range(_men.size() - 1, -1, -1):
		var m: AllyBase = _men[i]
		if m == null or not is_instance_valid(m) or m.is_dead():
			_men.remove_at(i)


func _player() -> Node3D:
	var player: Node3D = GameManager.player as Node3D
	if player == null or not is_instance_valid(player):
		return null
	return player


func _tick_wait() -> void:
	_prune_dead()
	if _men.is_empty():
		_lose()
		return
	if _elapsed - _phase_since > WAIT_TIMEOUT_S:
		_lose()
		return
	var player: Node3D = _player()
	if player == null:
		return
	var near: bool = false
	for m in _men:
		if player.global_position.distance_to(m.global_position) <= WAKE_M:
			near = true
			break
	if not near:
		return
	_phase = Phase.ESCORT
	_phase_since = _elapsed
	incident["phase"] = "escort"
	_follow_all()
	if _slick:
		var first: AllyBase = _men[0]
		director.toast.emit(String(CRASH_LINES.get(str(first.get_meta("crash_role", "pax")), CRASH_LINES["pax"])))
	else:
		director.toast.emit("GET ME BACK TO THE WIRE - I'LL KEEP UP")


func _follow_all() -> void:
	_holding = false
	for i in _men.size():
		var m: AllyBase = _men[i]
		m.file_slot = i + 1
		m.set_order(AllyBase.OrderMode.FOLLOW)


func _hold_all() -> void:
	_holding = true
	for m in _men:
		m.set_order(AllyBase.OrderMode.HOLD, m.global_position)


func _tick_escort() -> void:
	_prune_dead()
	if _men.is_empty():
		if _registered > 0:
			_recover()
		else:
			_lose()
		return
	if _elapsed - _phase_since > _escort_timeout:
		_lose()
		return
	var player: Node3D = _player()
	if player == null:
		return
	# The walk-in: a man inside the wire is handed back to the camp, one at a time.
	for i in range(_men.size() - 1, -1, -1):
		var m: AllyBase = _men[i]
		if m.global_position.distance_to(director.fsb_center) <= HOME_M:
			_register(m)
			_men.remove_at(i)
	if _men.is_empty():
		_recover()
		return
	# The group walks at its slowest man and never chases a sprinting player across the AO.
	var far: float = 0.0
	var near: float = INF
	for m in _men:
		var d: float = player.global_position.distance_to(m.global_position)
		far = maxf(far, d)
		near = minf(near, d)
	if _holding:
		if far <= SLICK_LAG_M:
			_follow_all()
			if _slick and _lag_said and int(incident.get("wounded", 0)) > 0:
				director.toast.emit(String(CRASH_LINES["stayed"]))
		return
	if far > SLICK_HOLD_M:
		_hold_all()
		return
	_catch_up(player)
	if _slick and far > SLICK_LAG_M and not _lag_said and int(incident.get("wounded", 0)) > 0:
		_lag_said = true
		director.toast.emit(String(CRASH_LINES["lag"]))
	if _slick and not _ville_said and _elapsed - _phase_since > 30.0:
		_ville_said = true
		for m in _men:
			if str(m.get_meta("crash_role", "")) == "gunner":
				director.toast.emit(String(CRASH_LINES["ville"]))
				break


func _catch_up(player: Node3D) -> void:
	if not GameManager.can_player_act():
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	var back: Vector3 = player.global_transform.basis.z
	back.y = 0.0
	var behind: Vector3 = back.normalized() if back.length() > 0.1 else Vector3.BACK
	for i in _men.size():
		var m: AllyBase = _men[i]
		if m.order_mode != AllyBase.OrderMode.FOLLOW or m.target != null:
			_still_s[m.get_instance_id()] = 0.0
			continue
		var dist: float = m.global_position.distance_to(player.global_position)
		var still: float = float(_still_s.get(m.get_instance_id(), 0.0))
		still = still + 1.0 if (m.velocity.length() < STUCK_SPEED_MPS and dist > STUCK_SLOT_M) else 0.0
		_still_s[m.get_instance_id()] = still
		var unseen: bool = cam == null or cam.is_position_behind(m.global_position) 			or DisplayServer.get_name() == "headless"
		if not unseen:
			continue
		if still < STUCK_SNAP_S and dist <= SLICK_LAG_M:
			continue
		var dest: Vector3 = player.global_position + behind * (6.0 + 1.5 * float(i + 1))
		if director.squad_system != null and is_instance_valid(director.squad_system):
			dest = director.squad_system._catchup_ground(m, dest)
		else:
			dest = MissionGenerator._seat(world, dest) + Vector3.UP * 0.5
		m.global_position = dest
		m.velocity = Vector3.ZERO
		m.reset_physics_interpolation()
		m.reset_follow_slot()
		_still_s[m.get_instance_id()] = 0.0
		print("[PILOT] %s was stuck %.0fs out of sight - moved up behind the player"
			% [str(m.get_meta("crash_role", "man")), still])


## The hand-back: the same swap the garrison's dawn uses. A wounded man goes to the ward as a
## patient, a walking man to the off-duty roster; the pilot keeps his face through the unit
## meta. The Skyraider's minted pilot has no garrison snapshot and goes to the ward as before.
func _register(m: AllyBase) -> void:
	_registered += 1
	incident["walked_in"] = _registered
	var wound: int = int(m.get_meta("crash_wound", 0))
	if wound > 0:
		director.state.flags["friendly_wia"] = int(director.state.flags.get("friendly_wia", 0)) + 1
	if not m.has_meta("garrison_occupation"):
		m.set_order(AllyBase.OrderMode.MOVE_TO, _ward_pos())
		return
	m.set_meta("garrison_occupation", "patient" if wound > 0 else "off_duty")
	var civ: Civilian = GarrisonDefender.stand_down(m, director)
	if civ != null:
		civ.add_to_group("crash_survivors")
		civ.working_point_pos = _ward_pos() if wound > 0 else civ.working_point_pos


func _recover() -> void:
	_phase = Phase.DONE
	incident["phase"] = "recovered"
	director.state.flags["pilot_recovered"] = 1
	director.state.flags["crash_walked_in"] = _registered
	if _slick:
		var left: int = int(incident.get("alive", 0)) - _registered
		director.toast.emit(String(CRASH_LINES["rest" if left > 0 or int(incident.get("dead", 0)) > 0 else "home"]))
		CampaignState.settle_tasking(TASKING_ID, CampaignState.TASKING_CLOSED,
			"%d walked in, %d in bags" % [_registered, int(incident.get("dead", 0))])
	else:
		director.toast.emit("PILOT DELIVERED TO THE AID STATION - THAT'S ONE THEY DON'T GET")
	_clear_column()
	print("[PILOT] recovered at %.0fs (%d walked in)" % [_elapsed, _registered])


func _lose() -> void:
	_phase = Phase.DONE
	incident["phase"] = "lost"
	director.state.flags["pilot_lost"] = 1
	director.toast.emit(String(CRASH_LINES["lost"]))
	if _slick:
		CampaignState.settle_tasking(TASKING_ID, CampaignState.TASKING_REFUSED, "nobody walked in")
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


## Read-only for the probe and the observatory.
func men() -> Array[AllyBase]:
	return _men


func phase_name() -> String:
	return String(incident.get("phase", "idle"))


static func _bearing8(from: Vector3, to: Vector3) -> String:
	var names: Array[String] = ["EAST", "SOUTHEAST", "SOUTH", "SOUTHWEST",
		"WEST", "NORTHWEST", "NORTH", "NORTHEAST"]
	var a: float = atan2(to.z - from.z, to.x - from.x)
	var idx: int = int(roundf(a / (TAU / 8.0))) % 8
	if idx < 0:
		idx += 8
	return names[idx]
