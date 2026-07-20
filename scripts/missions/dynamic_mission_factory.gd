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
	var dirs: Array[Node] = get_tree().get_nodes_in_group("mission_director")
	for d in dirs:
		if d is FieldDirector:
			(d as FieldDirector).raise_crisis(loc)


## Connected by MissionGenerator to every Convoy's `ambushed` signal.
func _on_convoy_ambushed(convoy: Convoy, position: Vector3) -> void:
	if convoy == null:
		return
	emit_location(&"convoy_ambushed", convoy.get_instance_id(), {
		"position": position,
	})


## A villager broke for cover over violence the player is NOT standing in. His own
## firefight is not a distress call - he is already there - so the distance check
## is what separates "a village in trouble" from "the trouble is me".
const VILLAGE_DISTRESS_M: float = 150.0

func report_village_distress(village_center: Vector3, village_id: int,
		player_pos: Vector3) -> void:
	if village_center.distance_to(player_pos) < VILLAGE_DISTRESS_M:
		return
	emit_location(&"village_requesting_aid", village_id, {"position": village_center})


## Captured documents name a camp. This is the ONLY honest way the player learns
## of one today: an existing world verb he performed, not a marker from nowhere.
## The nearest camp he has not already been sold is the one the papers describe.
func report_camp_discovered(from_pos: Vector3) -> bool:
	var best: CampDirector = null
	var best_d: float = 1.0e9
	for n in get_parent().get_children():
		if not (n is CampDirector):
			continue
		var cd := n as CampDirector
		if cd.camp_pos == Vector3.ZERO or _seen.has(cd.get_instance_id()):
			continue
		var d: float = from_pos.distance_to(cd.camp_pos)
		if d < best_d:
			best_d = d
			best = cd
	if best == null:
		return false
	emit_location(&"enemy_camp_discovered", best.get_instance_id(),
		{"position": best.camp_pos})
	return true
