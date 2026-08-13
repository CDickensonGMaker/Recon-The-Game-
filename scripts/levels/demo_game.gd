## demo_game.gd - DEMO GAME: the 30-minute ONE-DAY arc, dawn spawn to the night attack
## (War Room 2026-08-03, production/war_room/2026-08-03_demo_day_scope/, which rescoped the
## 2026-07-29 seven-minute slice).
##
## Boots the REAL flow (GameFlow.demo_mode -> plan_demo_world on a 512m map) -
## one world-build path, never a parallel copy (ADR-028). This scene owns only
## the SWITCHBOARD and the ARC CLOCK.
##
## Determinism honesty: layout and arc are seed-fixed; ambient positioners
## (AmbientWar, AirTraffic, hunter spawns) roll their own RNG, so moment-to-
## moment life varies between boots by design.
class_name DemoGame
extends Node

## Preloaded, not by class_name: a global class is not registered until the editor
## rescans, so a fresh script fails every headless run.
const TITLE_SPLASH := preload("res://scripts/ui/screens/title_splash.gd")

const DEMO_SEED: int = 29072026
const DEMO_NAME := "FIREBASE HOLDOUT"

## ---- THE SWITCHBOARD (skip-only: it may EXCLUDE systems, never fork them; a
## flag flipped true prints at boot so an excluded system is never a mystery) --
const EXCLUDE_SAVES := true          ## campaign writes go to a sandbox file
const EXCLUDE_DEBRIEF := true        ## death/dawn -> end card, no AAR screen
const EXCLUDE_AIR_TRAFFIC := false
const EXCLUDE_AMBIENT_WAR := false

## ---- THE ARC (seconds; pacing knobs for the Summoner's playtest) ----
## dawn spawn -> the day out -> dusk return -> night stand-to -> probe -> assault -> gunships.
##
## HIS RESCOPE 2026-08-03 (council `war_room/2026-08-03_demo_day_scope/`): the demo is ONE
## DAY, 30 real minutes, ending on the night attack. This REVERSES his 2026-07-30 ruling
## ("the assault should happen within 60 seconds"), deliberately: the day is the only thing
## that turns on the garrison schedule, the chow hall and the hunt net, none of which a
## seven-minute slice can show.
##
## THE ENGINE'S HARDEST LIMIT IS THE OPENING BEAT. The sun does not move - lighting is a
## four-state table that only changes on a period boundary (`mission_weather.gd:40` holds
## {5.5, 10.0, 17.5, 21.0}), so a day cannot be RENDERED as a day. It is sold instead as
## four hard lighting events, and spawning at 06:30 rather than 07:00 means DAY SNAPPING
## ON *IS* THE PLAYER CLEARING THE GATE.
const START_HOUR: float = 6.5

## 06:30 at 38x reaches NIGHT (sim 19.0, sim_clock.period_at) at ~1184s. The ratio seam
## below tracks MissionWeather.is_night - the same authority the siege rolls on - so the
## slow-down lands when night actually falls, wherever the boot put the clock.
const DAY_RATIO: float = 38.0

## NIGHT RUNS SLOW, and for the opposite reason the briefing assumed. Acceleration past
## midnight breaks three things: it re-arms a second siege roll, it unlatches the
## fire-support allotment through `_granted_day` (an exploit named in its own comment at
## `field_director.gd:1240-1245`), and it RAISES THE SUN during the night attack. At 20x
## the ~616 s from the 19:00 seam cover ~3h25m and the arc ends ~22:25 - same sim day.
const NIGHT_RATIO: float = 20.0

const PROBE_AT_S: float = 1395.0     ## first contact on the wire, just after stand-to
const SIEGE_AT_S: float = 1440.0     ## the assault - 360 s of it, the tuning SIEGE_AIR_BEATS assumes

## THE RAID ENDS THE DEMO, NOT A STOPWATCH (his ruling 2026-08-07: "there shouldn't really be
## a dead cut off time, it's just like whenever the end of the firebase raid happened").
##
## END_AT_S used to fire the gunships on the clock whether the assault was resolved or not, so
## a wave that broke early left the player standing in a won fight waiting for a timer, and one
## that ran long got its ending cut across it. SiegeDirector already announces the answer -
## `siege_ended` carries the reason, the killed count and the peak - and the arena has listened
## to it since the survival waves. The demo now does too.
##
## This is a BACKSTOP, not the pacing. It only fires if the assault never resolves at all -
## every cell dead-ended, or a break that cannot compute - because an unbounded demo is worse
## than an early one. Generous on purpose: at ~24 min to the assault it leaves a 21-minute
## fight before it ever bites.
const END_BACKSTOP_S: float = 2700.0

## THE DAWN CARD IS DEAD (Law 2, and his ruling Q1). Making the sun genuinely come up costs
## the three exploits above, so the demo no longer claims it. The last image is a flight of
## Huey gunships circling the wire, and THE PLAYER LIVES.
##
## The survive/die choice was delegated to the Arbiter and is deliberately ONE FLAG: if his
## playthrough says the ending lands flat, flip this and the flight circles his body instead.
const ENDING_PLAYER_SURVIVES: bool = true
const PROBE_STRENGTH: int = 11
## Total men on the wire after the escalation, NOT an increment. 45 and not 50: LIVE_CAP
## is 50 materialized men, and an assault authored at the cap freezes its late cells at
## the ring - the 2026-07-28 trickle failure. 45 is the largest number where every man
## the roll describes is actually on screen.
const SIEGE_STRENGTH: int = 45

var _flow: GameFlow = null
var _clock: float = 0.0
var _phase: int = 0   ## 0 explore, 1 probed, 2 siege, 3 ended (dawn or KIA)
var _card: CanvasLayer = null


func _ready() -> void:
	for x in [["saves", EXCLUDE_SAVES], ["debrief", EXCLUDE_DEBRIEF],
			["air_traffic", EXCLUDE_AIR_TRAFFIC], ["ambient_war", EXCLUDE_AMBIENT_WAR]]:
		if x[1]:
			print("[DEMO] EXCLUDED: %s" % x[0])
	if EXCLUDE_SAVES:
		# THE DEMO MUST NOT TOUCH HIS TOUR, and it must not inherit one either:
		# CampaignState is an AUTOLOAD whose _ready already loaded his REAL campaign
		# into memory, and a killed demo session leaves its sandbox files on disk.
		# Repoint both stores, burn the stale sandbox, start VIRGIN (fresh-player law).
		CampaignState.save_path = "user://campaign_demo.cfg"
		SaveManager.save_dir = "user://saves_demo"
		DirAccess.make_dir_recursive_absolute(SaveManager.save_dir)
		_wipe_demo_sandbox()
		CampaignState.reset_campaign()
	SimClock.real_to_sim_ratio = DAY_RATIO
	# THE TITLE CARD FIRST, same as the campaign. The demo builds its world behind it, so
	# the card covers the terrain streaming in rather than being a wait bolted in front of
	# it. Probe runs skip it: a headless gate must never sit waiting for a click.
	if not _is_probe_run():
		var splash: Control = TITLE_SPLASH.new()
		add_child(splash)
	GameFlow.demo_mode = true
	_flow = GameFlow.new()
	add_child(_flow)
	# `--demo-seed=N` re-rolls the layout for measurement only. The shipped demo is DEMO_SEED.
	var boot_seed: int = DEMO_SEED
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--demo-seed="):
			boot_seed = int(a.get_slice("=", 1))
	_flow._begin_operation(boot_seed, DEMO_NAME)
	# The build seeds its own hour from the plan (mission_weather.gd:51), so the arc's clock
	# can only be set AFTER the world is up - _in_world is the last latch enter_hub flips.
	# START_HOUR must stay inside the plan's DAWN period (5-7, sim_clock.period_at): set_time
	# does not emit time_period_changed, so a cross-period jump here would desync the sun.
	while _flow != null and is_instance_valid(_flow) and not _flow._in_world:
		await get_tree().process_frame
	if _flow == null or not is_instance_valid(_flow) or not is_inside_tree():
		return
	SimClock.set_time(1, START_HOUR)
	_apply_ambient_exclusions()
	print("[DEMO] booted seed %d, %dm slice, %02d:%02d start, day %.0fx / night %.0fx, arc probe@%ds siege@%ds backstop@%ds" % [
		boot_seed, int(GameFlow.DEMO_MAP_SIZE), int(START_HOUR), int(fmod(START_HOUR, 1.0) * 60.0),
		DAY_RATIO, NIGHT_RATIO, int(PROBE_AT_S), int(SIEGE_AT_S), int(END_BACKSTOP_S)])


## The other half of the switchboard. EXCLUDE_AIR_TRAFFIC and EXCLUDE_AMBIENT_WAR were read
## by nothing but the boot print above, so flipping either to true printed "EXCLUDED" and
## excluded nothing - the one thing the switchboard's own contract forbids. Both systems are
## built by mission_generator (:263-268) under fixed names, and both seed their schedules off
## SimClock in _ready, so removing the node is what "exclude" means for them.
func _apply_ambient_exclusions() -> void:
	if not (EXCLUDE_AIR_TRAFFIC or EXCLUDE_AMBIENT_WAR):
		return
	var world: Node = _flow.world if _flow != null else null
	if world == null or not is_instance_valid(world):
		return
	for pair in [["AirTraffic", EXCLUDE_AIR_TRAFFIC], ["AmbientWar", EXCLUDE_AMBIENT_WAR]]:
		if not bool(pair[1]):
			continue
		var n: Node = world.find_child(String(pair[0]), false, false)
		if n != null:
			n.queue_free()
		else:
			push_warning("[DEMO] EXCLUDE_%s is set but no such node was built" % String(pair[0]).to_upper())


## Any probe/automation flag means nobody is at the keyboard to dismiss a splash.
func _is_probe_run() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.ends_with("-probe"):
			return true
	return false


func _wipe_demo_sandbox() -> void:
	var dir := DirAccess.open(SaveManager.save_dir)
	if dir == null:
		return
	for fname: String in dir.get_files():
		dir.remove(fname)


func _exit_tree() -> void:
	GameFlow.demo_mode = false   # never leak demo state into a normal boot
	SimClock.real_to_sim_ratio = 60.0   # the demo's fast night must not follow him home
	if EXCLUDE_SAVES:
		CampaignState.save_path = CampaignState.DEFAULT_SAVE_PATH
		SaveManager.save_dir = SaveManager.DEFAULT_SAVE_DIR
		# Put his own tour back in memory: the sandbox campaign is still loaded at this point,
		# and leaving it there would show demo progress in the real main menu.
		CampaignState.load_campaign()


## ---- THE AIR PACKAGE (ship gate, 2026-07-29) ----
## "More Hueys and jets flying around... that constant movement of the choppers will really
## sell this scene." The sim schedule books ONE movement per sim-hour, which is an AO's
## background weather, not an opening. So the demo flies its own sky on the arc clock, through
## AirTraffic.launch() - the same dispatch the schedule uses, so formations, routes and the
## flight reaper all still apply. Nothing here is a second air system.
##
## Beats, in seconds from boot. The first is at 3s: the player is still finding his feet on
## the cot and the sky is already working.
const AIR_OPENING: Array = [
	[3.0, "huey", "transit"],     # a pack crosses low - FORMATION_SIZES puts 6-9 up
	[14.0, "huey", "lz_cycle"],   # one peels off and puts down on the pad
	[26.0, "f4", "transit"],      # fast movers high, 3-5 abreast
	[48.0, "huey", "transit"],
	[70.0, "skyraider", "transit"],
	[95.0, "chinook", "lz_cycle"],  # the heavy brings a load in
]
## After the opening, keep the sky alive on this cadence (seconds between launches).
const AIR_CADENCE_S: float = 42.0
## ...but never past this many airframes at once. PERF_LEDGER: this project is CALL-BOUND, and
## a nine-ship pack is nine sets of rotor meshes. Spectacle stops at the frame budget.
const AIR_MAX_IN_SKY: int = 14
const AIR_ROTATION: Array = ["huey", "f4", "huey", "skyhawk", "huey", "skyraider"]

var _air_next: int = 0
var _air_timer: float = 0.0
var _air_rotation_i: int = 0

## ---- THE NAPALM BEATS ----
## "a napalm strike either in the treeline behind the firebase assault or even at one point a
## sky flyby that is a machinegun run and a few napalm canisters dropped" - the Summoner's own
## pick for the biggest remaining visual win.
##
## Two runs, deliberately different jobs:
##   EARLY, at 35s, on a bearing AWAY from the base - pure spectacle while nothing threatens
##   him. The player watches somebody else's war burn on the horizon.
##   LATE, one minute into the main assault, laid across the treeline the attack is coming out
##   of. Same beat, but now it is ON his side and it is the answer to being overrun.
##
## Distances are measured against the model: the authored treeline runs out to ~149m and the
## siege rallies at 150m, so 210m puts the strip in the trees BEHIND the assault, not on top of
## the wire - and well clear of the garrison, who take blast like anyone else.
const NAPALM_EARLY_S: float = 35.0
const NAPALM_RANGE_M: float = 210.0

var _napalm_early_done: bool = false

## ---- THE SIEGE AIR SHOW ----
## The assault runs from SIEGE_AT_S until the raid resolves - about six minutes - and it used to carry exactly ONE
## air beat (the GUNS_NAPALM at +60). The climax of the demo was the quietest sky in it.
##
## Each beat is [seconds after SIEGE_AT_S, ordnance, metres out, bearing source]. They walk
## the compass with the assault instead of hitting one spot, and they ESCALATE: a standoff
## pass first, then guns, then the heavy stuff as the wire is reached.
##
## Bearing sources: "sector" = the axis the siege chose (`d.siege.sector_bearing`), so the
## steel lands on the men actually coming; "flank" = 60 deg off it, which reads as a second
## aircraft working a different problem; "away" = opposite the assault, pure horizon.
##
## SAFETY IS NOT HANDLED HERE. `authored_strike` rotates a gun run through 12 bearings to
## miss the player by GUN_STANDOFF_M, drops to napalm-only when no axis clears him, and
## refuses a pure gun run outright - every beat below goes through it with danger_close
## FALSE (his 2026-07-30 ruling: air can kill him, but it never deliberately runs on him
## unless he calls it with [G]).
##
## PERF: each beat is ONE airframe on a pass that flies out and reaps itself, against
## AIR_MAX_IN_SKY 14. Spacing is >= 35 s so two never overlap on the frame budget.
const SIEGE_AIR_BEATS: Array = [
	[25.0, CASAirplane.Ordnance.BOMB, 260.0, "away", "FAST MOVERS WORKING THE VALLEY"],
	[60.0, CASAirplane.Ordnance.GUNS_NAPALM, 210.0, "sector", "GUN RUN AND NAPALM - DANGER CLOSE"],
	[105.0, CASAirplane.Ordnance.GUNS, 175.0, "flank", "GUNS ON THE FLANK"],
	[150.0, CASAirplane.Ordnance.NAPALM, 195.0, "sector", "NAPALM ON THE TREELINE"],
	[205.0, CASAirplane.Ordnance.CBU, 240.0, "flank", "CBU IN THE TREES"],
	[255.0, CASAirplane.Ordnance.GUNS, 165.0, "sector", "STRAFING THE APPROACH"],
	[300.0, CASAirplane.Ordnance.GUNS_NAPALM, 185.0, "sector", "LAST PASS - EVERYTHING THEY HAVE"],
]
var _siege_air_next: int = 0


func _tick_napalm() -> void:
	var d: FieldDirector = _flow.director
	if d == null or d.fsb_center == Vector3.ZERO:
		return
	if not _napalm_early_done and _clock >= NAPALM_EARLY_S:
		_napalm_early_done = true
		# A bearing the player is not standing on: opposite the gate, out over the jungle.
		_strike_at(d, d.fsb_center, PI * 0.5, "SOMEBODY ELSE'S WAR - NAPALM ON THE TREELINE")
	_tick_siege_air(d)


## Walk the siege beat table. One beat per call at most, so two passes can never launch on
## the same frame however far the clock jumped.
func _tick_siege_air(d: FieldDirector) -> void:
	if _siege_air_next >= SIEGE_AIR_BEATS.size() or _clock < SIEGE_AT_S:
		return
	var beat: Array = SIEGE_AIR_BEATS[_siege_air_next]
	if _clock < SIEGE_AT_S + float(beat[0]):
		return
	_siege_air_next += 1
	# The assault's own axis, so the steel lands on the men who are actually coming.
	var sector: float = d.siege.sector_bearing if d.siege != null else 0.0
	var bearing: float = sector
	match String(beat[3]):
		"flank":
			bearing = sector + deg_to_rad(60.0)
		"away":
			bearing = sector + PI
	_strike_at(d, d.fsb_center, bearing, String(beat[4]),
		beat[1] as CASAirplane.Ordnance, float(beat[2]))


## Lay the strip across the player's view rather than along it: the run axis is TANGENTIAL to
## the bearing, so the length of the strip reads at a glance instead of vanishing to a point.
func _strike_at(d: FieldDirector, centre: Vector3, bearing: float, toast: String,
		ordnance: CASAirplane.Ordnance = CASAirplane.Ordnance.NAPALM,
		range_m: float = NAPALM_RANGE_M) -> void:
	var outward := Vector3(cos(bearing), 0.0, sin(bearing))
	var at: Vector3 = centre + outward * range_m
	at.y = _flow.world.surface_y(at) if _flow.world != null else at.y
	var across := Vector3(-outward.z, 0.0, outward.x)
	d.authored_strike(at, ordnance, across)
	d.toast.emit(toast)
	print("[DEMO] air beat: %s at %.0f,%.0f (%.0fm out on bearing %.0f deg)" % [
		CASAirplane.Ordnance.keys()[int(ordnance)], at.x, at.z, range_m, rad_to_deg(bearing)])


func _tick_air(delta: float) -> void:
	var at := _flow.world.get_node_or_null("AirTraffic") as AirTraffic if _flow.world != null \
		else null
	if at == null:
		return
	# The authored opening first, then a rolling cadence.
	if _air_next < AIR_OPENING.size():
		var beat: Array = AIR_OPENING[_air_next]
		if _clock >= float(beat[0]):
			_air_next += 1
			at.launch(String(beat[1]), String(beat[2]))
		return
	_air_timer -= delta
	if _air_timer > 0.0:
		return
	_air_timer = AIR_CADENCE_S
	if at.flights_in_air() >= AIR_MAX_IN_SKY:
		return
	at.launch(String(AIR_ROTATION[_air_rotation_i % AIR_ROTATION.size()]))
	_air_rotation_i += 1


var _death_routed := false
var _night_ratio_set := false
var _m6_printed := false

## ---- THE OPENING BEAT (council §2.2) ----
## There is no gate pointer in this game and the right one is not a marker: it is YOUR OWN
## SQUAD LEAVING WITHOUT YOU. It reads through the squadmate labels that already exist and
## are already exempted from the no-rails ruling, so ADR-030's HUD deferral is untouched -
## no new UI element is created for the demo.
const GATE_ORDER_AT_S: float = 10.0
## The order MUST expire or it becomes the rail it was written to avoid. Two expiries: the
## squad reaching the gate, and a hard clock for the case where compound pathing strands
## them. Whichever lands first hands the men back to FOLLOW.
const GATE_ORDER_ARRIVE_M: float = 8.0
const GATE_ORDER_MAX_S: float = 210.0

var _gate_order_issued := false
var _gate_order_released := false


## Issue at T+10, release on arrival. A man who cannot path to the gate is released by the
## clock rather than left walking into a wall for the rest of the demo.
func _tick_opening() -> void:
	if _gate_order_released:
		return
	var d: FieldDirector = _flow.director
	if d == null or d.squad_system == null or not is_instance_valid(d.squad_system):
		return
	var gate: Vector3 = d.patrol_gate_pos
	if gate == Vector3.ZERO:
		return
	var squad: SquadSystem = d.squad_system
	if not _gate_order_issued:
		if _clock < GATE_ORDER_AT_S:
			return
		_gate_order_issued = true
		for a in squad.members:
			if is_instance_valid(a) and not a.is_dead():
				a.set_order(AllyBase.OrderMode.MOVE_TO, gate)
		d.toast.emit("SQUAD MOVING OUT")
		print("[DEMO] opening: squad ordered to the gate at %.0fs" % _clock)
		return
	var arrived: int = 0
	var alive: int = 0
	for a in squad.members:
		if not is_instance_valid(a) or a.is_dead():
			continue
		alive += 1
		if a.global_position.distance_to(gate) <= GATE_ORDER_ARRIVE_M:
			arrived += 1
	var timed_out: bool = _clock >= GATE_ORDER_AT_S + GATE_ORDER_MAX_S
	# Third expiry: the beat is "your squad leaving without you", and it is over the
	# moment the player himself is at or beyond the wire - through the gate OR over
	# the berm anywhere (center-to-gate distance stands in for the perimeter radius).
	var player_out: bool = false
	var p: CharacterBody3D = _flow.world.player if _flow.world != null else null
	if p != null and is_instance_valid(p):
		var perimeter_m: float = d.fsb_center.distance_to(gate)
		player_out = p.global_position.distance_to(gate) <= GATE_ORDER_ARRIVE_M \
			or p.global_position.distance_to(d.fsb_center) >= perimeter_m
	if not timed_out and not player_out and (alive == 0 or arrived < alive):
		return
	_gate_order_released = true
	for a in squad.members:
		if is_instance_valid(a) and not a.is_dead() \
				and a.order_mode == AllyBase.OrderMode.MOVE_TO:
			a.set_order(AllyBase.OrderMode.FOLLOW)
	# M-4 counts these two numbers. The opening beat is hostage to compound pathing and
	# this line is the only place that says so out loud.
	print("[DEMO] opening: gate order released at %.0fs - %d/%d arrived%s"
		% [_clock, arrived, alive, " (TIMED OUT)" if timed_out else ""])


func _physics_process(delta: float) -> void:
	if _flow == null or _flow.director == null:
		return
	if not _death_routed:
		# enter_hub() constructs the director several awaits BEFORE it wires
		# mission_failed -> _on_mission_ended, so a non-null director does NOT mean the
		# flow is wired; that wire lands one line after the player is seated. Waiting on
		# it is both the disconnect's precondition and the arc's true start - his 60s
		# ruling counts from the spawn, not from the middle of the world build.
		if not _flow.director.mission_failed.is_connected(_flow._on_mission_ended):
			return
		_death_routed = true
		if EXCLUDE_DEBRIEF:
			_flow.director.mission_failed.disconnect(_flow._on_mission_ended)
			_flow.director.mission_failed.connect(_on_demo_death)
	_clock += minf(delta, 0.066)
	# M-6 (audit 2026-08-04): the one-shot clock print that proves the 06:30 arc is real.
	# At 38x, 60s after the seat should read ~07:08; a DUSK boot reads ~18:08 here.
	if not _m6_printed and _clock >= 60.0:
		_m6_printed = true
		print("[M-6] sim %05.2f day %d at %.0fs after seat" % [SimClock.sim_hour, SimClock.sim_day, _clock])
	_tick_opening()
	_tick_air(delta)
	_tick_napalm()
	# The ratio drops ONCE, at the day/night seam, and never climbs back inside a run.
	if not _night_ratio_set and MissionWeather.is_night:
		_night_ratio_set = true
		SimClock.real_to_sim_ratio = NIGHT_RATIO
		print("[DEMO] night at %.0fs - clock %.0fx -> %.0fx, sim %05.2f"
			% [_clock, DAY_RATIO, NIGHT_RATIO, SimClock.sim_hour])
	match _phase:
		0:
			if _clock >= PROBE_AT_S:
				_phase = 1
				_open_siege(PROBE_STRENGTH, "PROBE ON THE WIRE")
		1:
			if _clock >= SIEGE_AT_S:
				_phase = 2
				_open_siege(SIEGE_STRENGTH, "HERE THEY COME")
		2:
			if _clock >= END_BACKSTOP_S:
				print("[DEMO] BACKSTOP at %.0fs - the assault never resolved, ending anyway" % _clock)
				_phase = 3
				_ending()


func _open_siege(strength: int, toast: String) -> void:
	var d: FieldDirector = _flow.director
	if d.siege == null:
		d._attach_siege()   # idempotent; needs fsb_center, which the build set
	if d.siege != null:
		# Slice-scale assault geometry: the kilometer-AO defaults spawn cells
		# OFF the 512m map (fsb center is only 256m from every edge).
		d.siege.ring_min = 190.0
		d.siege.ring_max = 235.0
		d.siege.rally_m = 150.0
		d.siege.mortar_standoff_m = 170.0
		# BODIES MUST APPEAR OUTSIDE THE WIRE. minf against the 80m default was a no-op that left
		# cells standing up 80m from the objective - and the parapet reaches 96.1m radius
		# (firebase_v3_destructibles.json), so on many bearings men materialised INSIDE the
		# compound and tripped the overrun call before a shot was fired. 120m clears the widest
		# face with margin. The cap that matters on a small map is the LIVE cap, not this.
		d.siege.cell_materialize_m = 120.0
	if d.siege == null:
		print("[DEMO] no siege director - phase skipped")
		return
	if d.siege.active:
		# THE PROBE BECOMES THE ASSAULT. This branch used to toast and return, and
		# because the 600 s probe ran its 480 s duration to exactly the old dawn beat it was
		# ALWAYS taken - so SIEGE_STRENGTH was dead and every demo night was 11 men
		# announced twice. reinforce() grows strength and peak together so the break
		# ratio still means something.
		d.siege.reinforce(maxi(1, strength - d.siege.run_strength))
		# ARM THE WATCH HERE TOO. This branch is the one the demo actually takes - the probe is
		# still up at SIEGE_AT_S, so the assault arrives as a reinforcement, not a fresh siege.
		# Arming only on the open_siege path below would have left the ending on the backstop.
		_watch_for_the_raids_end(d)
		d.toast.emit(toast)
		print("[DEMO] phase %d: reinforced to %d at %.0fs" % [_phase, strength, _clock])
		return
	d.siege.open_siege(strength)
	_watch_for_the_raids_end(d)
	d.toast.emit(toast)
	print("[DEMO] phase %d: open_siege(%d) at %.0fs" % [_phase, strength, _clock])


## THE RAID'S END IS THE DEMO'S END. Armed on the ASSAULT only: a probe that breaks is the
## night's first beat, not its last, and ending on it would cut the demo at minute 23.
func _watch_for_the_raids_end(d: FieldDirector) -> void:
	if _phase < 2 or d.siege == null:
		return
	if not d.siege.siege_ended.is_connected(_on_raid_ended):
		d.siege.siege_ended.connect(_on_raid_ended)


func _on_raid_ended(reason: String, killed: int, strength: int) -> void:
	if _phase >= 3:
		return
	_phase = 3
	print("[DEMO] the raid ended at %.0fs (%s) - %d of %d down, sim %05.2f" % [
		_clock, reason, killed, strength, SimClock.sim_hour])
	_ending()


## THE LAST IMAGE: a flight of Huey gunships circling the wire, M60 gunners working. Not
## dawn - the sun cannot be made to rise without the three exploits named at NIGHT_RATIO.
## HIS RULING 2026-08-04 (Q2): the freeze lands only once the pair is ON STATION - a
## wall-clock hold let the fly-in eat the image - and the frozen frame then holds until
## he clicks out of the program. No timer dismisses it, no key continues past it.
## The timeout below guards a failed spawn only; it is not a pacing knob.
const GUNSHIP_WAIT_MAX_S: float = 25.0

func _ending() -> void:
	var d: FieldDirector = _flow.director
	print("[DEMO] ending at %.0fs (sim %05.2f) - gunships in" % [_clock, SimClock.sim_hour])
	var at := _flow.world.get_node_or_null("AirTraffic") as AirTraffic if _flow.world != null \
		else null
	if at != null:
		# A PAIR ON STATION, circling the wire at ORBIT_RADIUS_M. finale=true: nearer
		# spawn, exempt from the airframe ceiling. The door gunners are ART - he is
		# staging them in the Huey later (his ruling 2026-08-04, "i just want that idea
		# to be there"), so nothing here fires; the orbit carries the image on its own.
		at.launch("huey", "gun_orbit", 0, true)
	if d != null:
		d.toast.emit("GUNSHIPS ON STATION - GET YOUR HEADS DOWN")
	var waited: float = 0.0
	while at != null and not at.orbit_on_station() and waited < GUNSHIP_WAIT_MAX_S:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if _card != null:
		return   # he died under the orbit; that card already stands
	_show_end_card("FIREBASE HELD" if ENDING_PLAYER_SURVIVES else "THEY CAME BACK FOR THE WIRE")


func _on_demo_death(_result: Dictionary) -> void:
	print("[DEMO] KIA at %.0fs - end card" % _clock)
	_phase = 3
	_show_end_card("YOU FELL BEFORE DAWN")


## The demo's one terminal screen, win or lose. The war freezes behind it, the
## mouse is released, and it offers the only two verbs a stranger needs. The
## named men who held with you mitigate the cut debrief - the squad's long arc
## is the demo's biggest sacrifice, per the council.
func _show_end_card(title: String) -> void:
	if _card != null:
		return
	_flow._in_world = false   # Esc must not build a PauseMenu under the card
	GameManager.pause_game()  # freezes the world, frees the mouse
	var card := ReconUI.make_screen_root()
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.add_child(ReconUI.make_label(title, 30, ReconUI.AMBER))
	if _flow.squad != null:
		for a in _flow.squad.members:
			if a == null or not is_instance_valid(a):
				continue
			var status := "KIA" if a.is_dead() else "HELD"
			col.add_child(ReconUI.make_label(
				"%s - %s" % [str(a.member.get("name", "?")), status], 16,
				ReconUI.DIM if a.is_dead() else ReconUI.AMBER))
	# S28: the demo skips the debrief (EXCLUDE_DEBRIEF), so the rescued pilot's
	# only bank in this build is this card.
	var fd: FieldDirector = _flow.director if _flow != null else null
	if fd != null and int(fd.state.flags.get("pilot_recovered", 0)) > 0:
		col.add_child(ReconUI.make_label("THE PILOT CAME HOME", 16, ReconUI.AMBER))
	elif fd != null and int(fd.state.flags.get("pilot_lost", 0)) > 0:
		col.add_child(ReconUI.make_label("THE PILOT DIDN'T MAKE IT", 16, ReconUI.DIM))
	col.add_child(ReconUI.make_menu_button("RESTART THE NIGHT", _restart))
	col.add_child(ReconUI.make_menu_button("QUIT", _quit))
	col.add_child(ReconUI.make_label("RECON - DEMO", 13, ReconUI.DIM))
	cc.add_child(col)
	card.add_child(cc)
	_card = CanvasLayer.new()
	_card.layer = 90
	_card.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_card)
	_card.add_child(card)


func _restart() -> void:
	GameManager.resume_game()
	get_tree().reload_current_scene()


func _quit() -> void:
	get_tree().quit()
