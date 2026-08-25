## heli_lift.gd - WHAT A LANDING HUEY IS FOR.
##
## `Helicopter` has emitted `landed`/`took_off` and `SeatSystem` has offered
## seat/unseat/unseat_all/board_squad since both were written, and NOTHING in the game connected
## either: every seat function had zero production callers, so a Huey landed on the pad, sat for
## its ground seconds and left empty. This is the consumer.
##
## MISSION IS DECIDED AT DISPATCH, not on touchdown, because a delivery has to arrive with men
## already aboard. The Summoner's concealment rule is satisfied by the DOORS, not by the dice: they
## stay shut the whole way in and open only after the wheels are down, so an inbound ship gives
## nothing away whichever way the roll went.
##
## Need drives the roll. A garrison under establishment strength gets replacements; a garrison at
## strength sends men out. That makes the pad read as logistics rather than as a coin, and it makes
## the butcher's bill mechanical: men die, the base drops below strength, and the next ship brings
## their replacements (campaign_state.gd - kia_total / ward_wounded).
class_name HeliLift
extends Node

enum Mission { NONE, DELIVER, EXTRACT, ROTATE }

## Establishment strength of the firebase garrison. Delivery fills TOWARD this and never past it:
## bodies are ~94% of AI cost (PERF_LEDGER), so an uncapped pad grows the garrison every sortie
## until the frame dies. Replacements fill vacancies; they do not stack.
const ESTABLISHMENT: int = 28
const PAX_MIN: int = 3
const PAX_MAX: int = 6

## Cabin doors are separate nodes under the airframe and carry no baked clip, so they are driven
## here. Open is a yaw swing; the sign is per side.
const DOOR_OPEN_DEG: float = 105.0
const DOOR_RATE_DEG: float = 150.0
const DOOR_L_NAME: String = "Door_Left"
const DOOR_R_NAME: String = "Door_Right"

## One clip per passenger, so six men off one ship are six different men. All six are present in
## `assets/shared/anim_library.glb` (verified 2026-07-30).
const DISEMBARK_CLIPS: Array[String] = [
	"disembark_heli", "disembark_heli_b", "disembark_heli_c",
	"disembark_heli_d", "disembark_heli_e", "disembark_heli_f",
]
## A door this far above the man's ground is a HOVER, and a hovering ship is jumped
## out of rather than stepped down from. Below it the skids are effectively down and
## the disembark clips carry the whole exit.
const HOVER_DROP_M: float = 0.8
## Above this he takes it in the knees instead of stepping off clean.
const HARD_DROP_M: float = 1.6
## Grab-launch into a floor-seated crouch, spliced from `jump_up` (mount) into `sitting`'s
## opening pose (settle) - authored 2026-08-04, gated on the elbow/foot invariants. One clip;
## `play_first` degrades to no animation if the name is ever missing, so this stays additive.
const BOARD_CLIPS: Array[String] = ["board_heli"]

var heli: Helicopter = null
var director: FieldDirector = null
var seats: SeatSystem = null
var mission: Mission = Mission.NONE

var _door_l: Node3D = null
var _door_r: Node3D = null
var _door_l_shut: float = 0.0
var _door_r_shut: float = 0.0
var _door_want_open: bool = false
var _door_t: float = 0.0
var _pax: Array[Civilian] = []
## The two men in the cockpit. Held apart from _pax: passengers get unseated on
## landing, aircrew ride the ship.
var _crew: Array[Civilian] = []
var _delivered: bool = false
## Men THIS ship just put on the ground - a rotation must not lift its own
## arrivals straight back out.
var _rotated_off: Array[Civilian] = []
var _delivered_count: int = 0


## Bolt a lift onto a helicopter that is about to fly a landing cycle. Returns null when the
## world has no firebase to serve - an ambient sortie over open country carries nobody.
static func attach(h: Helicopter, d: FieldDirector) -> HeliLift:
	if h == null or not is_instance_valid(h) or d == null or d.fsb_center == Vector3.ZERO:
		return null
	var lift := HeliLift.new()
	lift.name = "HeliLift"
	lift.heli = h
	lift.director = d
	h.add_child(lift)
	return lift


func _ready() -> void:
	if heli == null or not is_instance_valid(heli):
		return
	# No airframe scene ships a SeatSystem node; SeatSystem carries measured
	# per-airframe fallback layouts, keyed off the scene's own tandem_rotor flag
	# (the CH-47 declares it; the UH-1 default covers everything else).
	seats = SeatSystem.new()
	seats.name = "Seats"
	seats.fallback_key = &"ch47" if heli.tandem_rotor else &"uh1"
	seats.board_clips = BOARD_CLIPS
	heli.add_child(seats)
	_find_doors()
	_shut_doors_now()
	_crew_ship()
	_choose_mission()
	if mission == Mission.DELIVER or mission == Mission.ROTATE:
		_load_pax()
	if not heli.landed.is_connected(_on_landed):
		heli.landed.connect(_on_landed)
	if not heli.took_off.is_connected(_on_took_off):
		heli.took_off.connect(_on_took_off)


## Put two men in the cockpit. SeatSystem has reserved seat_pilot_l/r since it was
## written and dresses whoever sits there (`_dress_pilots`, seat_system.gd:152) - but
## nothing ever seated them, so every Huey in the game has been flying itself.
##
## Aircrew are NOT garrison: `Civilian.spawn(garrison=true)` puts a man in the
## firebase_garrison group, and a pilot counted there inflates garrison_strength(),
## which is what decides whether a sortie DELIVERs or EXTRACTs - and would get him
## walked to a post by place_for_current_hour. So they come straight back out of it,
## the same way _load_pax does for men still in the air.
##
## They are never unseated: _on_landed only empties SeatSystem.PASSENGER_SEATS.
func _crew_ship() -> void:
	var world: Node = heli.get_parent()
	if world == null or seats == null:
		return
	var berths: Array[StringName] = [&"seat_pilot_l", &"seat_pilot_r"]
	for i in berths.size():
		if seats.occupant(berths[i]) != null:
			continue
		# Spread the mint point: Civilian.spawn derives model, face and dress from a
		# POSITION hash, so two men minted at one spot are the same man twice.
		var mint: Vector3 = heli.global_position + Vector3(float(i * 3 + 1), 0.0, float(i * 4 + 2))
		var crew: Civilian = Civilian.spawn(world, mint, director, false,
			Civilian.AIRCREW, true)
		if crew == null:
			continue
		crew.remove_from_group("firebase_garrison")
		if not seats.seat(crew, berths[i]):
			crew.queue_free()
			continue
		_crew.append(crew)
	print("[LIFT] crewed with %d pilot(s)" % _crew.size())


## Under strength: bring men. At strength: take men out.
## DEMO: a garrison seeded at 40 vs ESTABLISHMENT 28 made EVERY sortie an EXTRACT, so the
## one lz_cycle the opening flies landed, sat 35s and left - "nobody disembarked" (his
## playtest, 2026-08-04). A demo EXTRACT becomes a ROTATION: replacements walk off with
## the full disembark show, the same headcount is lifted out, net garrison ~0. The full
## game keeps pure need-driven logistics.
func _choose_mission() -> void:
	mission = Mission.DELIVER if garrison_strength() < ESTABLISHMENT else Mission.EXTRACT
	if GameFlow.demo_mode and mission == Mission.EXTRACT:
		mission = Mission.ROTATE


## Every man the firebase counts as its own, whichever side of a stand-to he is on. A garrison
## Civilian is promoted OUT of `firebase_garrison` into `garrison_promoted` for the fight
## (garrison_defender.gd:42), so counting one group alone reports half a garrison during a siege.
func garrison_strength() -> int:
	var tree: SceneTree = get_tree()
	if tree == null:
		return 0
	return tree.get_nodes_in_group("firebase_garrison").size() \
		+ tree.get_nodes_in_group("garrison_promoted").size()


# ---- THE DOORS ----

func _find_doors() -> void:
	var stack: Array[Node] = [heli]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var n3 := n as Node3D
		if n3 == null:
			continue
		if String(n3.name) == DOOR_L_NAME:
			_door_l = n3
		elif String(n3.name) == DOOR_R_NAME:
			_door_r = n3


## The shut pose is whatever the model was AUTHORED with - never assume zero. Read once, so the
## door always closes back onto the airframe it came from.
func _shut_doors_now() -> void:
	if _door_l != null:
		_door_l_shut = _door_l.rotation.y
	if _door_r != null:
		_door_r_shut = _door_r.rotation.y
	_door_want_open = false
	_door_t = 0.0


func _physics_process(delta: float) -> void:
	if _door_l == null and _door_r == null:
		return
	var target: float = 1.0 if _door_want_open else 0.0
	if is_equal_approx(_door_t, target):
		return
	var step: float = (DOOR_RATE_DEG / DOOR_OPEN_DEG) * delta
	_door_t = move_toward(_door_t, target, step)
	var swing: float = deg_to_rad(DOOR_OPEN_DEG) * _door_t
	# Opposite hands: each door slides back along its own side of the cabin.
	if _door_l != null and is_instance_valid(_door_l):
		_door_l.rotation.y = _door_l_shut + swing
	if _door_r != null and is_instance_valid(_door_r):
		_door_r.rotation.y = _door_r_shut - swing


# ---- DELIVERY ----

## First empty cabin seat, through SeatSystem's public API only. Pilot seats are crew and are
## never offered to a passenger, which is why this walks PASSENGER_SEATS rather than
## available_seats().
func _free_berth() -> StringName:
	for seat_name in SeatSystem.PASSENGER_SEATS:
		if seats.occupant(seat_name) == null:
			return seat_name
	return &""


## Men are spawned and seated BEFORE the flight, so the ship that lands is really carrying them.
## They ride as garrison Civilians, not AllyBase (his ruling 2026-07-30, REFINED not revoked by
## the 2026-08-04 soldiers ruling - war_room/2026-08-04_garrison_soldiers/synthesis.md §2): the
## garrison pipeline runs spawn -> promote at stand-to/alarm -> stand_down, an AllyBase here
## would be a second path against ADR-023, and an AllyBase has no schedule or work marker so it
## would stand where it landed forever. A soldier with a job joins camp life.
func _load_pax() -> void:
	var world: Node = heli.get_parent()
	if world == null or seats == null:
		return
	# A rotation swaps headcount 1:1, so establishment room does not gate its load.
	var room: int = PAX_MAX if mission == Mission.ROTATE \
		else maxi(0, ESTABLISHMENT - garrison_strength())
	var n: int = mini(room, randi_range(PAX_MIN, PAX_MAX))
	for i in range(n):
		# Spread the spawn positions: Civilian.spawn derives model, face and dress
		# from a POSITION hash, so a stick minted at one point is one man n times
		# (his playtest 2026-08-04: "the dropped-off replacements were all radiomen").
		var mint: Vector3 = heli.global_position + Vector3(float(i * 3 + 1), 0.0, float(i * 5 + 2))
		var man: Civilian = Civilian.spawn(world, mint, director, false,
			Civilian.GARRISON_MEN, true)
		if man == null:
			continue
		# Off the roster until he is on the ground: a man in the air is not manning anything, and
		# `place_for_current_hour` would teleport him to a post while the ship is still inbound.
		man.remove_from_group("firebase_garrison")
		var berth: StringName = _free_berth()
		if berth == &"" or not seats.seat(man, berth):
			man.queue_free()
			continue
		_pax.append(man)
	print("[LIFT] inbound with %d replacement(s) - garrison %d/%d"
		% [_pax.size(), garrison_strength(), ESTABLISHMENT])


func _on_landed(_h: Helicopter, _lz: LandingZone) -> void:
	# The reveal. Doors were shut the whole way in, so this is the first moment the player can
	# read what the ship came for.
	_door_want_open = true
	match mission:
		Mission.DELIVER:
			_deliver()
		Mission.EXTRACT:
			_extract()
		Mission.ROTATE:
			# Deliver FIRST: it frees the seats the outbound men take, and the
			# fresh arrivals are excluded from the lift home (_rotated_off).
			_deliver()
			_extract()
		Mission.NONE:
			pass


func _deliver() -> void:
	if _delivered or seats == null:
		return
	_delivered = true
	var door: Vector3 = seats.door_staging_pos()
	seats.unseat_all(door)
	var landed_men: int = 0
	for man in _pax:
		if man == null or not is_instance_valid(man):
			continue
		# `unseat` has already restored his collision, physics tick, ground position and levelled
		# the airframe's bank out of his rotation, so he is a live actor from here.
		man.add_to_group("firebase_garrison")
		# HAND HIM TO CAMP LIFE (his playtest 2026-08-04: "they just stand on the
		# helipad"). A replacement lands with occupation "farmer", no working point
		# and home ON THE PAD, so the schedule holds him where he stands forever.
		# Deterministic per man (ADR-010: his spawn hash, not a fresh roll), and
		# _placed_for_hour stays true so he WALKS off the pad instead of teleporting.
		man.occupation = "off_duty" if man._idle_seed % 2 == 0 else "detail"
		if director != null and is_instance_valid(director) and director.fsb_center != Vector3.ZERO:
			var a: float = float(man._idle_seed % 360) * (TAU / 360.0)
			var r: float = 10.0 + float(man._idle_seed % 12)
			var bunk: Vector3 = director.fsb_center + Vector3(cos(a), 0.0, sin(a)) * r
			# The hashed ring can land the bunk ON a pad - and then the schedule beds
			# down on the LZ - or ON another man's working point, which stacks two
			# arrivals into one body (his ruling 2026-08-24: one man per work point;
			# the live firebase_garrison group IS the claim ledger, freed when a man
			# dies or leaves the tree). Walk the angle (golden step, deterministic)
			# until the bunk clears both.
			for _try in range(12):
				if not LandingZone.on_pad(bunk) and _point_unclaimed(bunk):
					break
				a += 2.399963
				bunk = director.fsb_center + Vector3(cos(a), 0.0, sin(a)) * r
			bunk = _bunk_on_nav(bunk)
			bunk.y = man.global_position.y
			man.home = bunk
			man.working_point_pos = bunk
		man._placed_for_hour = true
		if man.actor != null and is_instance_valid(man.actor):
			# HOVER EXIT (his ruling 2026-08-05). The landing pair does NOT ride on top
			# of a disembark clip - those already carry the step-off, and stacking a
			# landing behind one lands the man twice (audit 2026-08-02). It REPLACES the
			# step-off, and only when the door is genuinely above the ground.
			var drop: float = door.y - man.global_position.y
			if drop >= HARD_DROP_M:
				man.actor.play_first(["hard_landing", "jump_down"])
			elif drop >= HOVER_DROP_M:
				man.actor.play_first(["jump_down", "hard_landing"])
			else:
				man.actor.play_first(DISEMBARK_CLIPS)
		_rotated_off.append(man)
		landed_men += 1
	_delivered_count = landed_men
	_pax.clear()
	# A ship that lands INTO a fight puts its men on the wire now. Waiting for the next stand-to
	# would leave replacements wandering to work posts while the base is being assaulted.
	# Reaching for the director's own stand-to rather than duplicating promote() here: the
	# firebase has exactly one path from Civilian to defender and this is not allowed to be a
	# second one (ADR-023). Same underscore-call precedent as demo_game.gd calling _attach_siege.
	if director != null and is_instance_valid(director) and director._garrison_stood_to:
		director._garrison_stand_to()
	print("[LIFT] delivered %d man/men - garrison %d/%d"
		% [landed_men, garrison_strength(), ESTABLISHMENT])


## Two working points closer than this read as one stack of men.
const POINT_CLAIM_M: float = 2.0


## No live garrison man already holds a working point within POINT_CLAIM_M of `p`.
func _point_unclaimed(p: Vector3) -> bool:
	if not is_inside_tree():
		return true
	for g in get_tree().get_nodes_in_group("firebase_garrison"):
		var c := g as Civilian
		if c == null or not is_instance_valid(c) or c.working_point_pos == Vector3.ZERO:
			continue
		if Vector2(c.working_point_pos.x - p.x, c.working_point_pos.z - p.z).length() \
				< POINT_CLAIM_M:
			return false
	return true


## Pull a bunk hashed into a structure footprint back onto walkable ground.
## Only inside a baked box: outside one, map_get_closest_point returns the
## nearest FAR region and would drag the bunk across the map (guard pattern
## nav_router.gd:67-69,87).
func _bunk_on_nav(p: Vector3) -> Vector3:
	if NavBaker.box_index_at(p) < 0:
		return p
	var w3d: World3D = heli.get_world_3d()
	if w3d == null:
		return p
	var map: RID = w3d.navigation_map
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) <= 0:
		return p
	var clamped: Vector3 = NavigationServer3D.map_get_closest_point(map, p)
	return clamped if p.distance_to(clamped) < NavRouter.CLAMP_MAX_M else p


# ---- EXTRACTION ----

## Men rotating out. Only garrison Civilians are eligible: a promoted defender is in a fight and
## does not walk off his post to catch a ride.
func _extract() -> void:
	if seats == null:
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var pad: Vector3 = heli.global_position
	var going: Array = []
	# A rotation lifts out at most the headcount it landed, so the swap nets zero.
	var out_cap: int = mini(PAX_MAX, _delivered_count) if mission == Mission.ROTATE else PAX_MAX
	if out_cap <= 0:
		return
	for n in tree.get_nodes_in_group("firebase_garrison"):
		var civ := n as Civilian
		if civ == null or not is_instance_valid(civ):
			continue
		if _rotated_off.has(civ):
			continue
		if civ.global_position.distance_to(pad) > EXTRACT_REACH_M:
			continue
		going.append(civ)
		if going.size() >= out_cap:
			break
	var queued: int = seats.board_squad(going) if not going.is_empty() else 0
	print("[LIFT] extracting %d man/men from the pad" % queued)


## How far a man will walk to a ship that is already down. Beyond this he is at a post, not
## waiting for a lift.
const EXTRACT_REACH_M: float = 35.0


## Doors shut as it lifts, and anyone still aboard leaves the garrison's books - he is gone from
## the compound whether or not the count ever sees him again.
func _on_took_off(_h: Helicopter) -> void:
	_door_want_open = false
	if seats == null:
		return
	for seat_name in SeatSystem.PASSENGER_SEATS:
		var body: Node3D = seats.occupant(seat_name)
		var civ := body as Civilian
		if civ == null or not is_instance_valid(civ):
			continue
		civ.remove_from_group("firebase_garrison")
