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

const BAND_QUIET: StringName = &"quiet"
const BAND_WARY: StringName = &"wary"
const BAND_HOSTILE: StringName = &"hostile"

## id -> {kind: StringName, place: int, sim_hour: float}
var deeds: Dictionary = {}


## The same key civilian.gd hands the crisis factory for a village (civilian.gd:481-482):
## whole-metre centre, hashed. One village, one key, every run (ADR-010).
static func place_key(center: Vector3) -> int:
	return absi(hash(Vector2i(int(center.x), int(center.z))))


## True when the deed is new. A second note of the same id changes nothing - a reload, a
## re-run of the hook, a second shot in the same patrol all land on the first.
func note(id: String, kind: StringName, place: int, sim_hour: float) -> bool:
	if deeds.has(id):
		return false
	deeds[id] = {"kind": kind, "place": place, "sim_hour": sim_hour}
	return true


func has(id: String) -> bool:
	return deeds.has(id)


## The village's reading of the player, by the kinds of deed against it: a civilian killed
## by his hand is hostile; fire near the ville is wary; the informer's own act is not held
## against the player here (it is the enemy's readout - FieldDirector.night_warning).
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


func to_save() -> Dictionary:
	return deeds.duplicate(true)


func from_save(v: Variant) -> void:
	deeds = (v as Dictionary).duplicate(true) if v is Dictionary else {}
