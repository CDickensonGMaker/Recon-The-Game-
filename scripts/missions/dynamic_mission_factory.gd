## dynamic_mission_factory.gd - turns WorldSim state transitions into mission
## offers. Listens to entity_state_changed and maps:
##   friendly_patrol_pinned  -> RESCUE
##   convoy_ambushed         -> ESCORT
##   helicopter_crashed      -> RECOVER
##   village_requesting_aid  -> INTERDICT
##   enemy_camp_discovered   -> STRIKE
##   friendly_firebase_under_attack -> DEFEND
##
## Offers are pushed to a `source = "SIM_EVENT"` channel so static mission-board
## offers (rolled by MissionOffers.roll) are never overwritten.
class_name DynamicMissionFactory
extends Node

signal offer_generated(offer: Dictionary)

## In-flight state changes keyed by entity id. Avoids offering the same
## crisis twice.
var _seen: Dictionary = {}


## Translate a state change into a mission offer. `payload` is a free-form
## dictionary that the campaign layer reads to spawn the mission later.
static func offer_for(state: StringName, payload: Dictionary) -> Dictionary:
	var mission_type: int = -1
	match state:
		&"friendly_patrol_pinned":
			mission_type = MissionGenerator.MissionType.RESCUE
		&"convoy_ambushed":
			mission_type = MissionGenerator.MissionType.PATROL
		&"helicopter_crashed":
			mission_type = MissionGenerator.MissionType.RESCUE
		&"village_requesting_aid":
			mission_type = MissionGenerator.MissionType.VILLAGE_RAID
		&"enemy_camp_discovered":
			mission_type = MissionGenerator.MissionType.ANTI_AA
		&"friendly_firebase_under_attack":
			mission_type = MissionGenerator.MissionType.FIREBASE_DEFENSE
		_:
			return {}
	return {
		"type": mission_type,
		"source": "SIM_EVENT",
		"trigger_state": String(state),
		"position": payload.get("position", Vector3.ZERO),
		"world_seed": payload.get("seed", 0),
	}


## Hook for WorldSim/entity transitions. The caller has already vetted that
## the entity id hasn't been offered yet; this builds + emits the offer.
func emit_offer(state: StringName, entity_id: int, payload: Dictionary) -> void:
	if _seen.has(entity_id):
		return
	_seen[entity_id] = String(state)
	var offer: Dictionary = offer_for(state, payload)
	if offer.is_empty():
		return
	offer_generated.emit(offer)


## Connected by MissionGenerator to every Convoy's `ambushed` signal. Latches
## a `convoy_ambushed` state per convoy id so the player gets a dynamic offer.
func _on_convoy_ambushed(convoy: Convoy, position: Vector3) -> void:
	if convoy == null:
		return
	emit_offer(&"convoy_ambushed", convoy.get_instance_id(), {
		"position": position,
		"seed": 0,
	})
