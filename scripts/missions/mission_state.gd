## mission_state.gd - Mission accumulators + the ADR-006 contact ledger.
class_name MissionState
extends RefCounted


var kills: int = 0
var damage_taken: int = 0
var start_time_ms: int = 0
var mission_type: String = ""
var seed_value: int = 0
var flags: Dictionary = {}  ## generator/system extras merged into the result


func record_kill() -> void:
	kills += 1


## CONTACT LEDGER (ADR-006). A group is DETECTED the first time any of its men
## reaches COMBAT with eyes on you; a group you leave the AO without ever alerting
## is AVOIDED. Per-group and one-way: once they have seen you, the contact is spent.
var contacts_detected: int = 0
var _detected_groups: Dictionary = {}   ## instance_id -> true
var _known_groups: Dictionary = {}      ## every group that ever existed


## Called by an enemy the moment he goes loud on the player.
func report_detected(group_id: int) -> void:
	_known_groups[group_id] = true
	if _detected_groups.has(group_id):
		return
	_detected_groups[group_id] = true
	contacts_detected += 1


## Called when a group is spawned/registered, so it can be scored as AVOIDED if
## it never sees you.
func register_group(group_id: int) -> void:
	_known_groups[group_id] = true


func contacts_avoided() -> int:
	return maxi(0, _known_groups.size() - _detected_groups.size())


func elapsed_seconds() -> float:
	return float(Time.get_ticks_msec() - start_time_ms) / 1000.0


func build_result(success: bool, reason: String = "") -> Dictionary:
	var result := _base_result(success, reason)
	for key in flags.keys():
		result[key] = flags[key]
	return result


func _base_result(success: bool, reason: String) -> Dictionary:
	return {
		"success": success,
		"reason": reason,
		"mission_type": mission_type,
		"seed": seed_value,
		"kills": kills,
		"damage_taken": damage_taken,
		"time_sec": elapsed_seconds(),
		# ADR-006: what the debrief actually pays on.
		"contacts_detected": contacts_detected,
		"contacts_avoided": contacts_avoided(),
	}
