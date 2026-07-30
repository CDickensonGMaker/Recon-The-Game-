## demo_game.gd - DEMO GAME: the 20-minute firebase-attack slice
## (War Room 2026-07-29, production/war_room/2026-07-29_demo_slice/).
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

const DEMO_SEED: int = 29072026
const DEMO_NAME := "FIREBASE HOLDOUT"

## ---- THE SWITCHBOARD (skip-only: it may EXCLUDE systems, never fork them; a
## flag flipped true prints at boot so an excluded system is never a mystery) --
const EXCLUDE_SAVES := true          ## campaign writes go to a sandbox file
const EXCLUDE_DEBRIEF := true        ## death/dawn -> end card, no AAR screen
const EXCLUDE_AIR_TRAFFIC := false
const EXCLUDE_AMBIENT_WAR := false

## ---- THE ARC (seconds; pacing knobs for the Summoner's playtest) ----
## dusk arrival -> explore window -> probing attack -> main siege -> dawn card.
const PROBE_AT_S: float = 600.0      ## minute 10: a probe finds the wire
const SIEGE_AT_S: float = 720.0      ## minute 12: the d50 night assault
const DAWN_AT_S: float = 1080.0      ## minute 18: it breaks; card at ~20
const PROBE_STRENGTH: int = 11
## Total men on the wire after the escalation, NOT an increment. 45 and not 50: LIVE_CAP
## is 50 materialized men, and an assault authored at the cap freezes its late cells at
## the ring - the 2026-07-28 trickle failure. 45 is the largest number where every man
## the roll describes is actually on screen.
const SIEGE_STRENGTH: int = 45

var _flow: GameFlow = null
var _clock: float = 0.0
var _phase: int = 0   ## 0 explore, 1 probed, 2 siege, 3 dawn


func _ready() -> void:
	for x in [["saves", EXCLUDE_SAVES], ["debrief", EXCLUDE_DEBRIEF],
			["air_traffic", EXCLUDE_AIR_TRAFFIC], ["ambient_war", EXCLUDE_AMBIENT_WAR]]:
		if x[1]:
			print("[DEMO] EXCLUDED: %s" % x[0])
	if EXCLUDE_SAVES:
		# THE DEMO MUST NOT TOUCH HIS TOUR, and repointing the campaign file alone did not
		# achieve that - two holes, both live:
		#
		# 1. SaveManager autosaves slot 8 every AUTOSAVE_INTERVAL_S from its own _process, slot 9
		#    on exit, and game_flow.gd writes the autosave slot on "FIREBASE". `save_dir` was only
		#    ever redirected for a TEST run, so a demo session was writing demo snapshots into his
		#    REAL slots - "Continue" in the real game would boot the demo world.
		# 2. CampaignState is an AUTOLOAD: its _ready ran load_campaign() against campaign.cfg
		#    before this line executed, so the demo inherited his live rank, threat, rack condition
		#    and depot losses. Repointing the path afterwards only changed where writes GO.
		CampaignState.save_path = "user://campaign_demo.cfg"
		SaveManager.save_dir = "user://saves_demo"
		DirAccess.make_dir_recursive_absolute(SaveManager.save_dir)
		CampaignState.load_campaign()
	GameFlow.demo_mode = true
	_flow = GameFlow.new()
	add_child(_flow)
	_flow._begin_operation(DEMO_SEED, DEMO_NAME)
	print("[DEMO] booted seed %d, %dm slice, arc probe@%ds siege@%ds dawn@%ds" % [
		DEMO_SEED, int(GameFlow.DEMO_MAP_SIZE), int(PROBE_AT_S), int(SIEGE_AT_S), int(DAWN_AT_S)])


func _exit_tree() -> void:
	GameFlow.demo_mode = false   # never leak demo state into a normal boot
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
##   EARLY, at 2:40, on a bearing AWAY from the base - pure spectacle while nothing threatens
##   him. The player watches somebody else's war burn on the horizon.
##   LATE, one minute into the main assault, laid across the treeline the attack is coming out
##   of. Same beat, but now it is ON his side and it is the answer to being overrun.
##
## Distances are measured against the model: the authored treeline runs out to ~149m and the
## siege rallies at 150m, so 210m puts the strip in the trees BEHIND the assault, not on top of
## the wire - and well clear of the garrison, who take blast like anyone else.
const NAPALM_EARLY_S: float = 160.0
const NAPALM_ASSAULT_S: float = SIEGE_AT_S + 60.0
const NAPALM_RANGE_M: float = 210.0

var _napalm_early_done: bool = false
var _napalm_assault_done: bool = false


func _tick_napalm() -> void:
	var d: FieldDirector = _flow.director
	if d == null or d.fsb_center == Vector3.ZERO:
		return
	if not _napalm_early_done and _clock >= NAPALM_EARLY_S:
		_napalm_early_done = true
		# A bearing the player is not standing on: opposite the gate, out over the jungle.
		_strike_at(d, d.fsb_center, PI * 0.5, "SOMEBODY ELSE'S WAR - NAPALM ON THE TREELINE")
	elif not _napalm_assault_done and _clock >= NAPALM_ASSAULT_S:
		_napalm_assault_done = true
		# Straight down the throat of the assault: the sector the siege chose. GUNS_NAPALM -
		# he strafes the treeline on the way in and pickles the strip at the bottom of the pass.
		var bearing: float = d.siege.sector_bearing if d.siege != null else 0.0
		_strike_at(d, d.fsb_center, bearing, "GUN RUN AND NAPALM - DANGER CLOSE",
			CASAirplane.Ordnance.GUNS_NAPALM)


## Lay the strip across the player's view rather than along it: the run axis is TANGENTIAL to
## the bearing, so the length of the strip reads at a glance instead of vanishing to a point.
func _strike_at(d: FieldDirector, centre: Vector3, bearing: float, toast: String,
		ordnance: CASAirplane.Ordnance = CASAirplane.Ordnance.NAPALM) -> void:
	var outward := Vector3(cos(bearing), 0.0, sin(bearing))
	var at: Vector3 = centre + outward * NAPALM_RANGE_M
	at.y = _flow.world.surface_y(at) if _flow.world != null else at.y
	var across := Vector3(-outward.z, 0.0, outward.x)
	d.authored_strike(at, ordnance, across)
	d.toast.emit(toast)
	print("[DEMO] napalm run at %.0f,%.0f (%.0fm out on bearing %.0f deg)" % [
		at.x, at.z, NAPALM_RANGE_M, rad_to_deg(bearing)])


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


func _physics_process(delta: float) -> void:
	if _flow == null or _flow.director == null:
		return
	_clock += delta
	_tick_air(delta)
	_tick_napalm()
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
			if _clock >= DAWN_AT_S:
				_phase = 3
				_dawn()


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
		# because the 600 s probe runs its 480 s duration to exactly DAWN_AT_S it was
		# ALWAYS taken - so SIEGE_STRENGTH was dead and every demo night was 11 men
		# announced twice. reinforce() grows strength and peak together so the break
		# ratio still means something.
		d.siege.reinforce(maxi(1, strength - d.siege.run_strength))
		d.toast.emit(toast)
		print("[DEMO] phase %d: reinforced to %d at %.0fs" % [_phase, strength, _clock])
		return
	d.siege.open_siege(strength)
	d.toast.emit(toast)
	print("[DEMO] phase %d: open_siege(%d) at %.0fs" % [_phase, strength, _clock])


func _dawn() -> void:
	print("[DEMO] dawn at %.0fs - end card" % _clock)
	var d: FieldDirector = _flow.director
	d.toast.emit("DAWN. YOU HELD.")
	# End card: the named men who held with you (mitigates the cut debrief -
	# the squad's long arc is the demo's biggest sacrifice, per the council).
	var card := ReconUI.make_screen_root()
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.add_child(ReconUI.make_label("FIREBASE HELD", 30, ReconUI.AMBER))
	if _flow.squad != null:
		for a in _flow.squad.members:
			if a == null or not is_instance_valid(a):
				continue
			var status := "KIA" if a.is_dead() else "HELD"
			col.add_child(ReconUI.make_label(
				"%s - %s" % [str(a.member.get("name", "?")), status], 16,
				ReconUI.DIM if a.is_dead() else ReconUI.AMBER))
	col.add_child(ReconUI.make_label("RECON - DEMO", 13, ReconUI.DIM))
	cc.add_child(col)
	card.add_child(cc)
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	layer.add_child(card)
