## seat_system.gd - The 18-seat UH-1 slick contract: 2 pilots + 2 door gunners
## + 8 lip pax + 6 centre-bench pax (16 passenger seats). The 8 lip seats carry
## the squad plus the player; the bench is the overloaded-ship overflow.
## Sockets are found ANYWHERE under the vehicle by exact name - seat_pilot_l /
## seat_pilot_r / seat_gunner_l / seat_gunner_r / seat_pax_1..8 / seat_bench_1..6.
## GLB-exported empties import as plain Node3D, NOT Marker3D: the scan must
## accept any Node3D. Missing sockets are generated from FALLBACK_LAYOUTS,
## keyed per airframe via fallback_key.
##
## SOCKET ORIENTATION CONTRACT: the occupant faces the socket's LOCAL +Z
## (characters are authored facing +Z; ModelActor yaw 0 == facing +Z).
## Pilots face the nose, gunners/pax face outward.
##
## The player is glued position-only (player.enter_seat) - NEVER reparent a
## physics body. AI bodies get physics/process/collision off + a RemoteTransform3D.
class_name SeatSystem
extends Node

## Canonical seat order. Crew first, then the cabin.
const SEAT_NAMES: Array[StringName] = [
	&"seat_pilot_l", &"seat_pilot_r",
	&"seat_gunner_l", &"seat_gunner_r",
	&"seat_pax_1", &"seat_pax_2", &"seat_pax_3", &"seat_pax_4",
	&"seat_pax_5", &"seat_pax_6", &"seat_pax_7", &"seat_pax_8",
	&"seat_bench_1", &"seat_bench_2", &"seat_bench_3",
	&"seat_bench_4", &"seat_bench_5", &"seat_bench_6",
]
## Fill order for squad/player boarding: the door lip first (the iconic silhouette),
## then the centre bench for an overloaded ship, door guns as last overflow.
## Pilot seats are CREW seats - passengers never take the controls.
const PASSENGER_SEATS: Array[StringName] = [
	&"seat_pax_1", &"seat_pax_2", &"seat_pax_3", &"seat_pax_4",
	&"seat_pax_5", &"seat_pax_6", &"seat_pax_7", &"seat_pax_8",
	&"seat_bench_1", &"seat_bench_2", &"seat_bench_3",
	&"seat_bench_4", &"seat_bench_5", &"seat_bench_6",
	&"seat_gunner_l", &"seat_gunner_r",
]

## Fallback layouts in vehicle-root space, KEYED BY AIRFRAME: seat -> [position,
## facing yaw degrees]. The attacher declares the key (heli_lift reads the
## scene's own Helicopter.tandem_rotor flag) - a CH-47 running the UH-1 layout
## put every seat crosswise in a Huey-sized pocket and men unseated inside the
## fuselage.
## uh1: doors at z -3.4..-1.9, walls x +-1.56, nose = -Z, Door_Left side = +X.
## ch47: ch47_chinook_v2 bakes ALL 18 seat_* empties into the GLB, so this table
## is retired for that ship (_scan_sockets prefers real markers). It stays as
## the emergency fallback, rotated to the v2 frame: nose -Z, ramp +Z, benches
## face inward across the bay. The pre-v2 numbers (nose -X, ramp +X 4.82) died
## with the old GLB.
const FALLBACK_LAYOUTS: Dictionary = {
	&"uh1": {
		&"seat_pilot_l": [Vector3(0.55, 1.35, -5.35), 180.0],
		&"seat_pilot_r": [Vector3(-0.55, 1.35, -5.35), 180.0],
		&"seat_gunner_l": [Vector3(1.15, 1.30, -2.70), 90.0],
		&"seat_gunner_r": [Vector3(-1.15, 1.30, -2.70), -90.0],
		&"seat_pax_1": [Vector3(1.05, 0.865, -4.442), 90.0],
		&"seat_pax_2": [Vector3(1.05, 0.865, -3.984), 90.0],
		&"seat_pax_3": [Vector3(1.05, 0.865, -3.525), 90.0],
		&"seat_pax_4": [Vector3(1.05, 0.865, -3.067), 90.0],
		&"seat_pax_5": [Vector3(-1.05, 0.865, -4.442), -90.0],
		&"seat_pax_6": [Vector3(-1.05, 0.865, -3.984), -90.0],
		&"seat_pax_7": [Vector3(-1.05, 0.865, -3.525), -90.0],
		&"seat_pax_8": [Vector3(-1.05, 0.865, -3.067), -90.0],
		## Centre bench, back to back down the spine. Pan measured at y 1.125 off
		## huey_v3.blend; the two rows sit +-0.25 either side of the centreline.
		&"seat_bench_1": [Vector3(-0.25, 1.125, -4.015), -90.0],
		&"seat_bench_2": [Vector3(-0.25, 1.125, -3.565), -90.0],
		&"seat_bench_3": [Vector3(-0.25, 1.125, -3.115), -90.0],
		&"seat_bench_4": [Vector3(0.25, 1.125, -4.015), 90.0],
		&"seat_bench_5": [Vector3(0.25, 1.125, -3.565), 90.0],
		&"seat_bench_6": [Vector3(0.25, 1.125, -3.115), 90.0],
	},
	&"ch47": {
		&"seat_pilot_l": [Vector3(0.45, 1.45, -4.6), 180.0],
		&"seat_pilot_r": [Vector3(-0.45, 1.45, -4.6), 180.0],
		&"seat_gunner_l": [Vector3(0.70, 1.10, -2.6), -90.0],
		&"seat_gunner_r": [Vector3(-0.70, 1.10, -2.6), 90.0],
		## The squad stick sits aft, nearest the ramp it boards through.
		&"seat_pax_1": [Vector3(0.65, 1.10, 3.0), -90.0],
		&"seat_pax_2": [Vector3(0.65, 1.10, 2.2), -90.0],
		&"seat_pax_3": [Vector3(0.65, 1.10, 1.4), -90.0],
		&"seat_pax_4": [Vector3(0.65, 1.10, 0.6), -90.0],
		&"seat_pax_5": [Vector3(-0.65, 1.10, 3.0), 90.0],
		&"seat_pax_6": [Vector3(-0.65, 1.10, 2.2), 90.0],
		&"seat_pax_7": [Vector3(-0.65, 1.10, 1.4), 90.0],
		&"seat_pax_8": [Vector3(-0.65, 1.10, 0.6), 90.0],
		&"seat_bench_1": [Vector3(0.65, 1.10, -0.2), -90.0],
		&"seat_bench_2": [Vector3(0.65, 1.10, -1.0), -90.0],
		&"seat_bench_3": [Vector3(0.65, 1.10, -1.8), -90.0],
		&"seat_bench_4": [Vector3(-0.65, 1.10, -0.2), 90.0],
		&"seat_bench_5": [Vector3(-0.65, 1.10, -1.0), 90.0],
		&"seat_bench_6": [Vector3(-0.65, 1.10, -1.8), 90.0],
	},
}
## Set by the attacher BEFORE any seat call (heli_lift.gd). Unknown keys fall
## back to uh1 rather than crash a sortie.
var fallback_key: StringName = &"uh1"


func _layout() -> Dictionary:
	return FALLBACK_LAYOUTS.get(fallback_key, FALLBACK_LAYOUTS[&"uh1"])

## Pilot clips by flight state. A ship on the ground holds PILOT_CLIP; one run
## through the panel plays on touchdown and falls through to the hold; airborne
## is hands-on-the-controls. cockpit_dead is deliberately NOT here - there is no
## pilot damage model in the ADR-029 slice and ADR-023 forbids the dead hook.
const PILOT_CLIP := "cockpit_idle"
## The panel beat is an OVERHEAD reach (read off footage 2026-08-10), not a forward
## one. `pilot_flips_switches` is NOT this clip: it and `cockpit_idle` resolve to an
## identical accessor graph in anim_library.glb - same data, different name - so the
## panel run was invisible from the day it was wired.
const PILOT_CLIP_PANEL := "pilot_flips_switches_overhead"
const PILOT_CLIP_FLYING := "cockpit_controls"
## Door-gunner clips. The `_l`/`_r` suffix is the DOOR, and it must match the seat -
## a right-side clip in the left seat works a gun that is not there.
##
## THE GUNS ARE REAL (Summoner, 2026-08-12, superseding his 2026-08-04 "dont build the
## gun... i just want that idea to be there" - that was said before the gunship Hueys
## existed, and they shipped today). `gunners_firing` still drives the performance; it now
## also lets the door guns engage.
const GUNNER_CLIP_IDLE := "m60_gunner_idle"
const GUNNER_CLIP_SCAN := "m60_gunner_scan"
const GUNNER_CLIP_FIRE := "m60_gunner_fire"
const GUNNER_SEATS: Array[StringName] = [&"seat_gunner_l", &"seat_gunner_r"]
## Length of PILOT_CLIP_PANEL, measured off anim_library.glb (90 keys @ 30fps).
## The panel run is a one-shot; this is how long before the pilot settles back to
## the ground hold.
const PILOT_PANEL_S: float = 3.00
## Seated-troop postures. The pax seats are the OUTBOARD DOOR LIP (x +/-1.05,
## y 0.865 - the sill) and the bench is the centre row (x +/-0.25, y 1.125), so
## they are not the same pose and must not share one clip.
##
## These are play_first CHAINS rather than bare names on purpose. play() returns false for a
## clip the library lacks, so a chain degrades to SITTING_CLIP instead of leaving a seated man
## playing nothing because a name was wrong.
##
## It did exactly what it was built to do: written 2026-08-12 when none of the three clips
## existed (209 clips in anim_library.glb), it picked the authored postures up unassisted when
## aba5ca53 shipped them the same day - no second wiring pass. The lip clips are LIVE now.
const SITTING_CLIP := "sitting"
## What a man is painted with the instant he leaves a seat, so he is never left holding the
## seated pose on the ground. A chain, same reason as the seat clips: the first one the shared
## library actually carries wins, and his own think loop repaints over it on its next tick.
const EXIT_CLIPS: Array[String] = ["idle", "idle_unarmed"]
const LIP_CLIPS: Array[String] = ["sit_lip_outboard_a", "sit_lip_outboard_b"]
const BENCH_CLIP := "sit_bench_upright"


static func _seat_clips(seat_name: StringName) -> Array[String]:
	var s := String(seat_name)
	if s.begins_with("seat_bench"):
		return [BENCH_CLIP, SITTING_CLIP]
	if s.begins_with("seat_pax"):
		# Alternate a/b down the row so a full stick does not sit in unison.
		var idx: int = s.get_slice("_", 2).to_int()
		return [LIP_CLIPS[idx % 2], LIP_CLIPS[(idx + 1) % 2], SITTING_CLIP]
	return [SITTING_CLIP]
const BOARD_STAGGER_S: float = 0.6   ## seconds between ally boardings
## Close enough to the SHIP to climb in - measured to the airframe, never to the
## door staging point: the staging point sits off the LEFT door, the airframe is
## not in any navmesh, and a man approaching from the right presses the fuselage
## with the target unreachable through it (measured 2026-08-04: boarders stalled
## 6-11m from staging for the full 24s). Touching the bird is boarding it; the
## mount clip covers the last metres.
const BOARD_NEAR_M: float = 8.0
const BOARD_RETRY_S: float = 0.4     ## re-check cadence while a boarder walks up
const BOARD_RETRIES_MAX: int = 60    ## ~24s of walking, then the ship gives up on him
const BOARD_MOUNT_S: float = 1.6     ## the climb-in beat before the seat glue takes him
const FADE_S: float = 0.25           ## seconds of the board/dismount fade
const BOARD_RANGE: float = 4.5       ## player-to-door interact radius, metres
const EXIT_PUSH_M: float = 2.5       ## how far outside the door you land

## OPT-IN. Helicopters are PARKED (ADR-029 foot-only slice); nothing enables
## player_boarding today. The seat contract + test stay for the thaw.
@export var player_boarding: bool = false:
	set(v):
		player_boarding = v
		set_physics_process(v)

var auto_generated: bool = false
## Mount performance played at the door before seating (set by the vehicle's
## owner, e.g. HeliLift). Empty = seat with no clip.
var board_clips: Array[String] = []

var _vehicle: Node3D = null
var _sockets: Dictionary = {}        ## StringName -> Node3D
var _occupants: Dictionary = {}      ## StringName -> {body, glue, shapes, was_physics, was_process}
var _prompt: Label = null
var _prompt_text: String = ""
var _fading: bool = false
var _interact_cd: float = 0.0
## Last flight state the pilots were dressed for, and the panel one-shot's
## remaining time. -1 is "never dressed", which forces the first refresh.
var _pilot_state: int = -1
var _pilot_panel_s: float = 0.0

## Set by whoever owns the sortie (AirTraffic's gun orbit). Visual only.
var gunners_firing: bool = false:
	set(v):
		if v == gunners_firing:
			return
		gunners_firing = v
		_dress_gunners()


## ---------- THE DOOR GUNS ----------
## A door gun is a SHORTER, SLOWER strafe run: same BulletSystem call the CAS pass already
## makes (cas_airplane.gd:363), so tracers, penetration, suppression and audio all come for
## free and none of it is a second implementation.
##
## Each gun only sees its OWN side. The `_l`/`_r` suffix is the door, and a gunner cannot
## traverse across the airframe - that is the whole reason an orbit is flown at all.
const GUN_WEAPON: String = "res://data/weapons/m60.tres"
const GUN_RANGE_M: float = 220.0
## Half-arc off the door's outward normal. Generous, but it cannot reach the far side.
const GUN_ARC_DEG: float = 62.0
## Burst cadence. A door gun talks in bursts, not a continuous stream.
const GUN_BURST_MIN: int = 5
const GUN_BURST_MAX: int = 9
const GUN_BURST_GAP_S: float = 1.1
const GUN_ROUND_GAP_S: float = 0.09
## Cone the burst is walked through, so it hoses ground rather than sniping.
const GUN_SPREAD_DEG: float = 3.4
## NOBODY SHOOTS OVER HIS OWN PEOPLE. A friendly this close to the aim point stands the
## gun down - the airborne mirror of FieldDirector's 40m no-overfly rule.
const GUN_DANGER_CLOSE_M: float = 35.0
## Layer 4 = enemies (project.godot layer table).
const GUN_MASK: int = 4

var _gun_wd: WeaponData = null
var _gun_cd: Array[float] = [0.0, 0.0]
var _gun_left: Array[int] = [0, 0]
var _gun_tick: Array[float] = [0.0, 0.0]

## Each door runs its own burst clock, so the two guns never speak in unison - a Huey
## working a treeline is two voices, not a stereo pair.
func _tick_door_guns(delta: float) -> void:
	if _gun_wd == null:
		_gun_wd = load(GUN_WEAPON) as WeaponData
		if _gun_wd == null:
			return
	for i in range(GUNNER_SEATS.size()):
		if _gun_left[i] > 0:
			_gun_tick[i] -= delta
			if _gun_tick[i] <= 0.0:
				_gun_tick[i] = GUN_ROUND_GAP_S
				_gun_left[i] -= 1
				_fire_door_gun(i)
			continue
		_gun_cd[i] -= delta
		if _gun_cd[i] > 0.0:
			continue
		_gun_cd[i] = GUN_BURST_GAP_S * randf_range(0.7, 1.5)
		if _door_target(i) != null:
			_gun_left[i] = randi_range(GUN_BURST_MIN, GUN_BURST_MAX)
			_gun_tick[i] = 0.0


## The nearest live enemy inside THIS door's arc. Returns null when the gun has nothing,
## which is what stands it down - a gunship that fires at nothing is a firework.
func _door_target(side: int) -> Node3D:
	var seat: StringName = GUNNER_SEATS[side]
	var entry: Array = _layout().get(seat, [])
	if entry.is_empty():
		return null
	var muzzle: Vector3 = _door_muzzle(side)
	# The door's outward normal is the SEAT'S OWN FACING (layout yaw rotates
	# local +Z), never a hardcoded body axis: the Huey's doors are +-X but the
	# Chinook's are +-Z, and the old +-X rule aimed both its guns out the nose.
	var body := _vehicle as Node3D
	if body == null or not is_instance_valid(body):
		return null
	var outward: Vector3 = body.global_transform.basis \
		* (Basis(Vector3.UP, deg_to_rad(float(entry[1]))) * Vector3(0.0, 0.0, 1.0))
	outward.y = 0.0
	if outward.length() < 0.01:
		return null
	outward = outward.normalized()
	var best: Node3D = null
	var best_d: float = GUN_RANGE_M
	for e in AgentRegistry.enemies:
		var man := e as Node3D
		if man == null or not is_instance_valid(man):
			continue
		if man.has_method("is_dead") and bool(man.call("is_dead")):
			continue
		var to: Vector3 = man.global_position - muzzle
		var flat := Vector3(to.x, 0.0, to.z)
		var d: float = flat.length()
		if d > best_d or d < 1.0:
			continue
		if rad_to_deg(flat.normalized().angle_to(outward)) > GUN_ARC_DEG:
			continue
		if _friendly_near(man.global_position):
			continue
		best_d = d
		best = man
	return best


## Nobody shoots over his own people. Checked at the AIM POINT, not the muzzle: the round
## lands where the gunner is looking, and that is where a friendly would be hit.
func _friendly_near(aim: Vector3) -> bool:
	var pl := GameManager.player as Node3D
	if pl != null and is_instance_valid(pl) \
			and pl.global_position.distance_to(aim) < GUN_DANGER_CLOSE_M:
		return true
	for a in AgentRegistry.allies:
		var man := a as Node3D
		if man != null and is_instance_valid(man) \
				and man.global_position.distance_to(aim) < GUN_DANGER_CLOSE_M:
			return true
	return false


func _door_muzzle(side: int) -> Vector3:
	var entry: Array = _layout().get(GUNNER_SEATS[side], [])
	var local: Vector3 = (entry[0] as Vector3) if not entry.is_empty() else Vector3.ZERO
	var body := _vehicle as Node3D
	# SeatSystem is a plain Node hanging off the airframe: the TRANSFORM is the vehicle's.
	return (body.global_transform * local) if body != null and is_instance_valid(body) else local


func _fire_door_gun(side: int) -> void:
	var man: Node3D = _door_target(side)
	if man == null:
		_gun_left[side] = 0
		return
	var muzzle: Vector3 = _door_muzzle(side)
	var aim: Vector3 = man.global_position + Vector3.UP * 0.9
	var dir: Vector3 = (aim - muzzle).normalized()
	# Walk the burst through a cone so it hoses ground instead of sniping from 200m.
	var spread: float = deg_to_rad(GUN_SPREAD_DEG)
	dir = dir.rotated(Vector3.UP, randf_range(-spread, spread))
	var side_axis: Vector3 = dir.cross(Vector3.UP).normalized()
	if side_axis.length() > 0.01:
		dir = dir.rotated(side_axis, randf_range(-spread, spread)).normalized()
	CombatManager.bullets.fire(_gun_wd, self, muzzle, dir, GUN_MASK, [self, _vehicle], true)
	GunFX.muzzle_flash(get_tree().current_scene, muzzle)
	NoiseBus.emit_noise(NoiseBus.NoiseType.GUNSHOT, muzzle, 0, 180.0)


var _scanned: bool = false


func _ready() -> void:
	_vehicle = get_parent() as Node3D
	if _vehicle == null:
		push_warning("[SeatSystem] parent is not a Node3D - no seats")
		set_physics_process(false)
		return
	# Deferred: generating fallback markers ADDS children to the vehicle, which
	# is forbidden while the scene is still setting up ("parent busy" error).
	_scan_sockets.call_deferred()
	set_physics_process(player_boarding)
	# The pilot dressing tick is independent of player_boarding: a ship nobody can
	# board still lands with visible pilots in it.
	set_process(_vehicle is Helicopter)


## The clip a pilot should be holding right now. Ground states hold, everything
## airborne flies. The panel one-shot is owned by _process.
func _pilot_clip() -> String:
	var heli := _vehicle as Helicopter
	if heli == null:
		return PILOT_CLIP
	if heli.state == Helicopter.State.LANDED:
		return PILOT_CLIP_PANEL if _pilot_panel_s > 0.0 else PILOT_CLIP
	if heli.state == Helicopter.State.CRASHING or heli.state == Helicopter.State.DESTROYED:
		return PILOT_CLIP
	return PILOT_CLIP_FLYING


## Re-dress the crew seats when the flight state changes. Runs on _process
## rather than _physics_process because player_boarding owns the physics tick.
func _process(delta: float) -> void:
	var heli := _vehicle as Helicopter
	if heli == null:
		return
	if gunners_firing:
		_tick_door_guns(delta)
	if _pilot_panel_s > 0.0:
		_pilot_panel_s = maxf(0.0, _pilot_panel_s - delta)
		if _pilot_panel_s <= 0.0:
			_dress_pilots()
	if heli.state == _pilot_state:
		return
	# Touchdown starts one run through the panel; it expires into the ground hold.
	if heli.state == Helicopter.State.LANDED and _pilot_state != Helicopter.State.LANDED:
		_pilot_panel_s = PILOT_PANEL_S
	_pilot_state = heli.state
	_dress_pilots()
	_dress_gunners()


## Ground and wreck states hold the idle; airborne scans unless the sortie owner
## has called for fire. Side suffix comes from the SEAT, never from the ship.
func _gunner_clip(seat_name: StringName) -> String:
	var side: String = "_l" if seat_name == &"seat_gunner_l" else "_r"
	var heli := _vehicle as Helicopter
	if heli == null or heli.state == Helicopter.State.LANDED \
			or heli.state == Helicopter.State.CRASHING \
			or heli.state == Helicopter.State.DESTROYED:
		return GUNNER_CLIP_IDLE + side
	return (GUNNER_CLIP_FIRE if gunners_firing else GUNNER_CLIP_SCAN) + side


func _dress_gunners() -> void:
	for seat_name in GUNNER_SEATS:
		var rec: Dictionary = _occupants.get(seat_name, {})
		if not bool(rec.get("crew", false)):
			continue
		var body := rec.get("body") as Node3D
		if body == null or not is_instance_valid(body):
			continue
		var model: ModelActor = _model_of(body)
		if model != null:
			model.play_first([_gunner_clip(seat_name), SITTING_CLIP])


func _dress_pilots() -> void:
	var clip: String = _pilot_clip()
	for seat_name: StringName in [&"seat_pilot_l", &"seat_pilot_r"]:
		var rec: Dictionary = _occupants.get(seat_name, {})
		var body := rec.get("body") as Node3D
		if body == null or not is_instance_valid(body):
			continue
		var model: ModelActor = _model_of(body)
		if model != null:
			model.play(clip, true)


## Find real sockets by name anywhere under the vehicle (the GLB export lands them
## inside the Model subtree); generate any missing one from the airframe's
## fallback layout.
## Idempotent - the public API calls it lazily in case someone seats pre-frame-1.
func _scan_sockets() -> void:
	if _scanned or _vehicle == null:
		return
	_scanned = true
	var generated: int = 0
	for seat_name in SEAT_NAMES:
		# GLB empties arrive as plain Node3D - never type-check for Marker3D here.
		var existing := _vehicle.find_child(String(seat_name), true, false) as Node3D
		if existing != null:
			_sockets[seat_name] = existing
			continue
		var entry: Array = _layout()[seat_name]
		var m := Marker3D.new()
		m.name = String(seat_name)
		_vehicle.add_child(m)
		m.position = entry[0] as Vector3
		m.rotation_degrees = Vector3(0.0, float(entry[1]), 0.0)
		_sockets[seat_name] = m
		generated += 1
	auto_generated = generated > 0
	if generated > 0:
		print("[SeatSystem] %s: auto-generated %d/%d %s fallback sockets (real seat_* markers will override when exported)" % [_vehicle.name, generated, SEAT_NAMES.size(), fallback_key])
	else:
		print("[SeatSystem] %s: all %d seat_* sockets found in the model - fallback table retired" % [_vehicle.name, SEAT_NAMES.size()])


func available_seats() -> Array[StringName]:
	_scan_sockets()
	var out: Array[StringName] = []
	for seat_name in SEAT_NAMES:
		if _sockets.has(seat_name) and occupant(seat_name) == null:
			out.append(seat_name)
	return out


func occupant(seat_name: StringName) -> Node3D:
	if not _occupants.has(seat_name):
		return null
	var rec: Dictionary = _occupants[seat_name]
	var body := rec.get("body") as Node3D
	if body == null or not is_instance_valid(body):
		_occupants.erase(seat_name)  # occupant died/freed while seated
		return null
	return body


func is_full() -> bool:
	if _sockets.is_empty():
		return false
	for seat_name in SEAT_NAMES:
		if _sockets.has(seat_name) and occupant(seat_name) == null:
			return false
	return true


## The seat this body occupies, or &"" if not aboard.
func seat_of(body: Node3D) -> StringName:
	for seat_name in SEAT_NAMES:
		if _occupants.has(seat_name) and occupant(seat_name) == body:
			return seat_name
	return &""


func socket(seat_name: StringName) -> Node3D:
	_scan_sockets()
	return _sockets.get(seat_name) as Node3D


## Seat a body in a named socket. Returns false if the seat is unknown,
## occupied, or the body is already aboard.
##
## `as_crew` is what separates a DOOR GUNNER from a passenger riding in the door
## seat: the gunner berths are also squad overflow (PASSENGER_SEATS), so without
## this an infantryman with a rifle works an M60 he is not holding.
func seat(body: Node3D, seat_name: StringName, as_crew: bool = false) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	_scan_sockets()
	if not _sockets.has(seat_name) or occupant(seat_name) != null:
		return false
	if seat_of(body) != &"":
		return false
	var sock: Node3D = _sockets[seat_name]
	var rec: Dictionary = {"body": body, "crew": as_crew}

	if body.has_method("enter_seat"):
		# Player: position-only glue, never reparented.
		body.call("enter_seat", sock)
	else:
		# AI / mock body: freeze it and glue it to the socket.
		rec["was_physics"] = body.is_physics_processing()
		rec["was_process"] = body.is_processing()
		body.set_physics_process(false)
		body.set_process(false)
		var cb := body as CharacterBody3D
		if cb != null:
			cb.velocity = Vector3.ZERO
		var shapes: Array = []
		for c in body.get_children():
			var cs := c as CollisionShape3D
			if cs != null and not cs.disabled:
				cs.set_deferred("disabled", true)
				shapes.append(cs)
		rec["shapes"] = shapes
		body.global_transform = sock.global_transform
		body.reset_physics_interpolation()
		var glue := RemoteTransform3D.new()
		glue.update_scale = false
		sock.add_child(glue)
		glue.remote_path = glue.get_path_to(body)
		rec["glue"] = glue

	var model: ModelActor = _model_of(body)
	if model != null:
		# Zero the actor's local yaw so the authored +Z facing lines up with
		# the socket's +Z (set_facing writes GLOBAL yaw, so mid-walk actors
		# carry an arbitrary local offset in).
		model.rotation = Vector3.ZERO
		if String(seat_name).begins_with("seat_pilot"):
			model.play(_pilot_clip())
		elif as_crew and GUNNER_SEATS.has(seat_name):
			model.play_first([_gunner_clip(seat_name), SITTING_CLIP])
		else:
			model.play_first(_seat_clips(seat_name))

	_occupants[seat_name] = rec
	return true


## Restore a seated body to the world at exit_pos. Physics interpolation is ON
## project-wide, so every teleport out of the socket resets interpolation.
func unseat(body: Node3D, exit_pos: Vector3) -> void:
	var seat_name: StringName = seat_of(body)
	if seat_name == &"":
		return
	var rec: Dictionary = _occupants[seat_name]
	_occupants.erase(seat_name)
	var glue := rec.get("glue") as RemoteTransform3D
	if glue != null and is_instance_valid(glue):
		glue.queue_free()
	if body == null or not is_instance_valid(body):
		return

	if body.has_method("exit_seat"):
		body.call("exit_seat", exit_pos)  # player path (resets its own collision)
	else:
		var shapes: Array = rec.get("shapes", [])
		for s in shapes:
			var cs := s as CollisionShape3D
			if cs != null and is_instance_valid(cs):
				cs.set_deferred("disabled", false)
		# ON, not "whatever it was". was_physics/was_process are sampled at seat() time, and
		# troops are seated the same frame they spawn (the TR pax convention) - BEFORE _ready
		# has turned their processing on. So the capture reads false and this faithfully
		# restored false, and the man stood on the LZ forever, never thinking. There is no
		# case where a delivered passenger should stay frozen.
		body.set_physics_process(true)
		body.set_process(true)
		body.global_position = exit_pos
		# Level the body: the socket basis carried the airframe's bank/pitch.
		var e: Vector3 = body.global_rotation
		body.global_rotation = Vector3(0.0, e.y, 0.0)
		var cb := body as CharacterBody3D
		if cb != null:
			cb.velocity = Vector3.ZERO
	# seat() paints the seated pose and nothing ever painted it back off, so a delivered man
	# stood on the pad still holding sit_lip_outboard_* until something else happened to him.
	# His own think loop repaints from here; this just clears the seat.
	var out_model: ModelActor = _model_of(body)
	if out_model != null:
		out_model.play_first(EXIT_CLIPS)
	body.reset_physics_interpolation()


## Empty the cabin - PASSENGER_SEATS only. Pilot seats are crew berths; a crew
## bailout needs its own explicit unseat.
func unseat_all(exit_center: Vector3) -> void:
	var bodies: Array[Node3D] = []
	for seat_name in PASSENGER_SEATS:
		var body: Node3D = occupant(seat_name)
		if body != null:
			bodies.append(body)
	if bodies.is_empty():
		return
	var eg: Array = _egress()
	var origin: Vector3 = eg[0] as Vector3 if eg[0] != Vector3.ZERO else exit_center
	var normal: Vector3 = eg[1] as Vector3
	# A ramp stick files AFT in a tight fan and keeps going - a wide side-door
	# arc wrapped Chinook men back around the hull. The longer radius is the
	# "run away from the ship" half of his ruling: the last men off land 10m+
	# behind the ramp, clear of the airframe.
	var is_ramp: bool = fallback_key == &"ch47"
	var arc: float = deg_to_rad(80.0 if is_ramp else 140.0)
	var radius_cap: float = 11.0 if is_ramp else 7.0
	for i in bodies.size():
		var t: float = 0.5 if bodies.size() == 1 \
			else float(i) / float(bodies.size() - 1)
		var dir: Vector3 = normal.rotated(Vector3.UP, arc * (t - 0.5))
		var radius: float = minf(EXIT_PUSH_M + 0.9 * float(i), radius_cap)
		unseat(bodies[i], _exit_ground(origin + dir * radius))


## Order living allies to a staging point by the left door, then seat them one
## per BOARD_STAGGER_S. Dead/downed excluded. Returns how many were queued.
func board_squad(allies: Array) -> int:
	var staging: Vector3 = door_staging_pos()
	# Stick line abeam the exit: the door for a Huey, the ramp for a Chinook.
	# 1.4m spacing is the ceiling: BOARD_NEAR_M is measured to the airframe and
	# the 6th slot sits 7.4m out - 0.6m of margin.
	var sock: Node3D = _sockets.get(&"seat_gunner_l") as Node3D
	var side: Vector3 = Vector3(0.0, 0.0, 1.0)
	if fallback_key == &"ch47" and _vehicle != null and is_instance_valid(_vehicle):
		# Abeam the ramp: the v2 ramp axis is +Z, so the stick line runs +X.
		side = ((_vehicle as Node3D).global_transform.basis * Vector3(1.0, 0.0, 0.0)).normalized()
	elif sock != null:
		side = sock.global_transform.basis.x
	var queued: int = 0
	for a in allies:
		var body := a as Node3D
		if body == null or not is_instance_valid(body):
			continue
		if body.has_method("is_dead") and bool(body.call("is_dead")):
			continue
		if "is_downed" in body and bool(body.get("is_downed")):
			continue
		var slot: Vector3 = staging + side * (1.4 * float(queued))
		var ally := body as AllyBase
		if ally != null:
			ally.set_order(AllyBase.OrderMode.MOVE_TO, slot)
		elif body is Civilian:
			(body as Civilian).board_target = slot
		queued += 1
		get_tree().create_timer(BOARD_STAGGER_S * float(queued)).timeout.connect(
			_board_one.bind(body))
	return queued


## Arrival-gated: a boarder is seated only once he has WALKED to the door, so the
## glue never teleports a man across the pad. Retries bound the wait; an abandoned
## boarder gets his latch back so the schedule reclaims him.
func _board_one(body: Node3D, retries: int = 0) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body.has_method("is_dead") and bool(body.call("is_dead")):
		return
	if seat_of(body) != &"":
		return
	var civ := body as Civilian
	var ship: Vector3 = _vehicle.global_position if _vehicle != null and is_instance_valid(_vehicle) \
		else door_staging_pos()
	if Vector2(body.global_position.x - ship.x, body.global_position.z - ship.z).length() > BOARD_NEAR_M:
		if retries < BOARD_RETRIES_MAX:
			get_tree().create_timer(BOARD_RETRY_S).timeout.connect(
				_board_one.bind(body, retries + 1))
		else:
			print("[SEATS] boarder never reached the ship (%.0fm out after %.0fs) - abandoned"
				% [body.global_position.distance_to(ship),
					float(BOARD_RETRIES_MAX) * BOARD_RETRY_S])
			if civ != null:
				civ.board_target = Vector3.ZERO
		return
	if civ != null and not board_clips.is_empty() \
			and civ.actor != null and is_instance_valid(civ.actor):
		print("[SEATS] boarder at the door after ~%.1fs walk - mounting"
			% (float(retries) * BOARD_RETRY_S))
		civ.actor.play_first(board_clips)
		get_tree().create_timer(BOARD_MOUNT_S).timeout.connect(_seat_boarder.bind(body))
		return
	_seat_boarder(body)


func _seat_boarder(body: Node3D) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body.has_method("is_dead") and bool(body.call("is_dead")):
		return
	if seat_of(body) != &"":
		return
	var civ := body as Civilian
	if civ != null:
		civ.board_target = Vector3.ZERO
	var seat_name: StringName = _next_free_passenger_seat()
	if seat_name == &"":
		return
	if seat(body, seat_name):
		print("[SEATS] boarder seated in %s" % seat_name)


func _next_free_passenger_seat() -> StringName:
	for seat_name in PASSENGER_SEATS:
		if _sockets.has(seat_name) and occupant(seat_name) == null:
			return seat_name
	return &""


## World-space point EXIT_PUSH_M outside the left door - allies stage here,
## the player dismounts here.
func door_staging_pos() -> Vector3:
	return _egress()[0]


## Where a stick exits and which way it fans, PER AIRFRAME. The Huey empties out
## its side doors (gunner sockets face outward, local +Z); the Chinook empties
## out the BACK RAMP - side-door egress walked its stick out under the forward
## rotor arc and left the men bunched beside the hull (his playtest: "they dont
## run away from the ship out the back"). Returns [origin, outward_normal].
func _egress() -> Array:
	if fallback_key == &"ch47" and _vehicle != null and is_instance_valid(_vehicle):
		var xf: Transform3D = (_vehicle as Node3D).global_transform
		# ch47_chinook_v2 is convention-true: nose -Z, ramp aft at +Z (ramp hinge
		# 15.47m from the nose, plan centre 0,0 - build record production/
		# blender_notes.md 2026-08-14). Stage aft of the lip, fanning straight aft.
		return [xf * Vector3(0.0, 0.0, 9.0), (xf.basis * Vector3(0.0, 0.0, 1.0)).normalized()]
	var sock: Node3D = _sockets.get(&"seat_gunner_l") as Node3D
	if sock != null:
		# Gunner sockets face outward: local +Z is straight out the door.
		return [sock.global_position + sock.global_transform.basis.z * EXIT_PUSH_M,
			sock.global_transform.basis.z]
	if _vehicle != null and is_instance_valid(_vehicle):
		return [(_vehicle as Node3D).global_position + Vector3(EXIT_PUSH_M, 0.0, 0.0),
			Vector3(1.0, 0.0, 0.0)]
	return [Vector3.ZERO, Vector3(1.0, 0.0, 0.0)]


func _physics_process(delta: float) -> void:
	_interact_cd = maxf(0.0, _interact_cd - delta)
	if not player_boarding or _fading or _vehicle == null:
		return
	var player := GameManager.player as Node3D
	if player == null or not is_instance_valid(player):
		_set_prompt("")
		return

	if seat_of(player) != &"":
		_set_prompt("DISMOUNT [E]")
		if _interact_ok():
			_interact_cd = 0.6
			_fade_then(func() -> void:
				unseat(player, _exit_ground(door_staging_pos())))
		return

	var near: bool = player.global_position.distance_to(door_staging_pos()) <= BOARD_RANGE \
		or player.global_position.distance_to(_vehicle.global_position) <= BOARD_RANGE
	_set_prompt("BOARD THE BIRD [E]" if near else "")
	if near and _interact_ok():
		_interact_cd = 0.6
		_fade_then(func() -> void:
			var seat_name: StringName = _next_free_passenger_seat()
			if seat_name != &"":
				seat(player, seat_name))


func _interact_ok() -> bool:
	return _interact_cd <= 0.0 and Input.is_action_just_pressed("interact")


func _fade_then(action: Callable) -> void:
	var overlay: ColorRect = _ensure_overlay()
	if overlay == null:
		action.call()
		return
	_fading = true
	var tw: Tween = create_tween()
	tw.tween_property(overlay, "color:a", 1.0, FADE_S)
	tw.tween_callback(action)
	tw.tween_property(overlay, "color:a", 0.0, FADE_S)
	tw.tween_callback(func() -> void: _fading = false)


var _overlay: ColorRect = null

func _ensure_overlay() -> ColorRect:
	if _overlay != null and is_instance_valid(_overlay):
		return _overlay
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)
	return _overlay


func _set_prompt(text: String) -> void:
	if text == _prompt_text:
		return
	_prompt_text = text
	if _prompt == null:
		if text == "":
			return
		var layer := CanvasLayer.new()
		layer.layer = 10
		add_child(layer)
		_prompt = ReconUI.make_label("", 18, ReconUI.AMBER)
		_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_prompt.position = Vector2(-200, -120)
		_prompt.custom_minimum_size = Vector2(400, 0)
		_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		layer.add_child(_prompt)
	_prompt.text = text


## Ground under a door-exit point (raycast down; fallback: vehicle deck height).
func _exit_ground(pos: Vector3) -> Vector3:
	var out: Vector3 = pos
	out.y = _vehicle.global_position.y + 0.5
	var w3d: World3D = _vehicle.get_world_3d()
	if w3d != null:
		var query := PhysicsRayQueryParameters3D.create(
			pos + Vector3.UP * 2.0, pos + Vector3.DOWN * 8.0, 1)  # layer 1 = world
		var hit: Dictionary = w3d.direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var p: Vector3 = hit.position
			out.y = p.y + 1.0
	return out


func _model_of(body: Node3D) -> ModelActor:
	if body is ModelActor:
		return body as ModelActor
	if "sprite_actor" in body:  # AllyBase / EnemyBase renderer slot
		var sa := body.get("sprite_actor") as Node
		if sa is ModelActor:
			return sa as ModelActor
	for c in body.get_children():
		if c is ModelActor:
			return c as ModelActor
	return null
