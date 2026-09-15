## hm_ledger.gd - what the player DID, as the province could know it. Hearts & Minds
## (ADR-019) as a ledger of DEEDS: occurrence ids noted once, never counted. A place reads as
## a BAND derived from the KINDS of deed against it, so no consumer can score a patrol
## (ADR-038 §2a: a subject may be named, never a quantity, a rate or a direction).
##
## No method here returns a number about the player. `place_key` is the only int, and it
## names a place. tests/test_hearts_felt.gd holds that line.
class_name HmLedger
extends RefCounted

const KIND_INFORMER: StringName = &"informer"
const KIND_FIRE: StringName = &"fire"
const KIND_KILLED: StringName = &"civ_killed"
## The dealer's case walked down to the ville: the one deed that is not misconduct. It is its
## own subject - band() never reads it - and traded() is how it is felt.
const KIND_TRADE: StringName = &"trade"

const BAND_QUIET: StringName = &"quiet"
const BAND_WARY: StringName = &"wary"
const BAND_HOSTILE: StringName = &"hostile"

## id -> {kind: StringName, place: int, sim_hour: float, cause: String}
## `cause` is the caller's own words for the observatory's ledger pane (dev-only); no
## player-facing consumer reads it.
var deeds: Dictionary = {}


## The same key civilian.gd hands the crisis factory for a village (civilian.gd:481-482):
## whole-metre centre, hashed. One village, one key, every run (ADR-010).
static func place_key(center: Vector3) -> int:
	return absi(hash(Vector2i(int(center.x), int(center.z))))


## True when the deed is new. A second note of the same id changes nothing - a reload, a
## re-run of the hook, a second shot in the same patrol all land on the first.
func note(id: String, kind: StringName, place: int, sim_hour: float, cause: String = "") -> bool:
	if deeds.has(id):
		return false
	deeds[id] = {"kind": kind, "place": place, "sim_hour": sim_hour, "cause": cause}
	return true


func has(id: String) -> bool:
	return deeds.has(id)


## The village's reading of the player, by the kinds of deed against it: a civilian killed
## by his hand is hostile; fire near the ville is wary; the informer's own act is not held
## against the player here (it is the enemy's readout - FieldDirector.night_warning). A trade
## is neither: a ville that only ever took a case off him reads quiet.
func band(place: int) -> StringName:
	var wary: bool = false
	for d in deeds.values():
		if int(d.place) != place:
			continue
		if d.kind == KIND_KILLED:
			return BAND_HOSTILE
		if d.kind == KIND_FIRE:
			wary = true
	return BAND_WARY if wary else BAND_QUIET


## True when a trade deed stands against this place - the dealer's own reading of the ville.
func traded(place: int) -> bool:
	for d in deeds.values():
		if int(d.place) == place and d.kind == KIND_TRADE:
			return true
	return false


func to_save() -> Dictionary:
	return deeds.duplicate(true)


func from_save(v: Variant) -> void:
	deeds = (v as Dictionary).duplicate(true) if v is Dictionary else {}
