## dynamic_mission_factory.gd - turns WorldSim state transitions into POINTED
## LOCATIONS for the patrol loop (ADR-029; the offer board is dead). A sim
## crisis becomes a place worth walking to: the wire gate reads these ahead of
## the standing village/camp ring.
class_name DynamicMissionFactory
extends Node

## In-flight state changes keyed by entity id. Avoids offering the same
## crisis twice.
var _seen: Dictionary = {}


## Translate a state change into a pointed location {pos, kind}.
static func location_for(state: StringName, payload: Dictionary) -> Dictionary:
	var kind: String = ""
	match state:
		&"friendly_patrol_pinned":
			kind = "pinned_patrol"
		&"convoy_ambushed":
			kind = "ambushed_convoy"
		&"village_requesting_aid":
			kind = "village"
		&"enemy_camp_discovered":
			kind = "vc_camp"
		&"friendly_firebase_under_attack":
			kind = "firebase_attack"
		_:
			return {}
	return {
		"pos": payload.get("position", Vector3.ZERO),
		"kind": kind,
		"trigger_state": String(state),
	}


## Hook for WorldSim/entity transitions. The caller has already vetted that
## the entity id hasn't been offered yet; this builds + emits the location.
func emit_location(state: StringName, entity_id: int, payload: Dictionary) -> void:
	if _seen.has(entity_id):
		return
	_seen[entity_id] = String(state)
	var loc: Dictionary = location_for(state, payload)
	if loc.is_empty():
		return
	# Feed the wire gate directly: a live crisis outranks the standing ring.
	var dirs: Array[Node] = get_tree().get_nodes_in_group("mission_director")
	for d in dirs:
		if d is FieldDirector and (loc.pos as Vector3) != Vector3.ZERO:
			(d as FieldDirector).patrol_locations.push_front(loc)


## Connected by MissionGenerator to every Convoy's `ambushed` signal.
func _on_convoy_ambushed(convoy: Convoy, position: Vector3) -> void:
	if convoy == null:
		return
	emit_location(&"convoy_ambushed", convoy.get_instance_id(), {
		"position": position,
	})
