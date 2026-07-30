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

enum Mission { NONE, DELIVER, EXTRACT }

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

## One clip per passenger so six men off one ship are six different men. Only three ship in
## `anim_library.glb` today (`disembark_heli`, `_b`, `_c`); `play_first` falls through the rest, so
## naming all six now means d/e/f start working the moment they are exported.
const DISEMBARK_CLIPS: Array[String] = [
	"disembark_heli", "disembark_heli_b", "disembark_heli_c",
	"disembark_heli_d", "disembark_heli_e", "disembark_heli_f",
]
## NONE of these exist yet - they are being mocapped. Every name falls through until they land,
## which costs nothing: a man with no board clip still walks to the door and seats.
const BOARD_CLIPS: Array[String] = [
	"board_heli", "board_heli_b", "board_heli_c",
	"board_heli_d", "board_heli_e", "board_heli_f",
]

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
var _delivered: bool = false


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
	# The huey scene ships no SeatSystem node, but SeatSystem carries a measured UH-1 fallback
	# layout, so it works whether or not the airframe exports sockets.
	seats = SeatSystem.new()
	seats.name = "Seats"
	heli.add_child(seats)
	_find_doors()
	_shut_doors_now()
	_choose_mission()
	if mission == Mission.DELIVER:
		_load_pax()
	if not heli.landed.is_connected(_on_landed):
		heli.landed.connect(_on_landed)
	if not heli.took_off.is_connected(_on_took_off):
		heli.took_off.connect(_on_took_off)


## Under strength: bring men. At strength: take men out.
func _choose_mission() -> void:
	mission = Mission.DELIVER if garrison_strength() < ESTABLISHMENT else Mission.EXTRACT


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
## They are garrison Civilians, not AllyBase (his ruling 2026-07-30): the garrison pipeline
## already runs spawn -> promote at stand-to -> stand_down at dawn, an AllyBase would be a second
## path against ADR-023, and an AllyBase has no schedule or work marker so it would stand where it
## landed forever. A Civilian joins camp life.
func _load_pax() -> void:
	var world: Node = heli.get_parent()
	if world == null or seats == null:
		return
	var room: int = maxi(0, ESTABLISHMENT - garrison_strength())
	var n: int = mini(room, randi_range(PAX_MIN, PAX_MAX))
	for i in range(n):
		var man: Civilian = Civilian.spawn(world, heli.global_position, director, false,
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
		if man.actor != null and is_instance_valid(man.actor):
			man.actor.play_first(DISEMBARK_CLIPS)
		landed_men += 1
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
	for n in tree.get_nodes_in_group("firebase_garrison"):
		var civ := n as Civilian
		if civ == null or not is_instance_valid(civ):
			continue
		if civ.global_position.distance_to(pad) > EXTRACT_REACH_M:
			continue
		if civ.actor != null and is_instance_valid(civ.actor):
			civ.actor.play_first(BOARD_CLIPS)
		going.append(civ)
		if going.size() >= PAX_MAX:
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
