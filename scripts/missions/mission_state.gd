## mission_state.gd - Objective bitmask + mission accumulators (NS07).
## The RTCW rule lives here: exfil unlocks only when required_mask is full.
class_name MissionState
extends RefCounted

signal objective_met(index: int)

var objective_titles: Dictionary = {}  ## index -> String
var required_mask: int = 0
var optional_mask: int = 0
var met_mask: int = 0

var kills: int = 0
var damage_taken: int = 0
var start_time_ms: int = 0
var emergency_exfil: bool = false
var mission_type: String = ""
var seed_value: int = 0
var flags: Dictionary = {}  ## generator/system extras merged into the result


func register_objective(index: int, title: String, required: bool = true) -> void:
	objective_titles[index] = title
	var bit: int = 1 << index
	if required:
		required_mask |= bit
	else:
		optional_mask |= bit


func complete_objective(index: int) -> bool:
	var bit: int = 1 << index
	if met_mask & bit:
		return false  # idempotent (RTCW objectivemet rule)
	met_mask |= bit
	objective_met.emit(index)
	return true


func is_objective_complete(index: int) -> bool:
	return (met_mask & (1 << index)) != 0


func is_exfil_unlocked() -> bool:
	return (met_mask & required_mask) == required_mask


func objectives_total() -> int:
	return objective_titles.size()


func objectives_done() -> int:
	var count: int = 0
	for index in objective_titles.keys():
		if is_objective_complete(int(index)):
			count += 1
	return count


func record_kill() -> void:
	kills += 1


## CONTACT LEDGER (ADR-006, audit L4). The scoring economy that GAME_GUIDE names
## - +25 avoided, -25 detected - had no numbers to score, because nobody counted.
## An enemy GROUP is "detected" the first time any of its men reaches COMBAT with
## eyes on you; a group you leave the AO without ever alerting is "avoided". The
## ledger is per-group and one-way: once they've seen you, that contact is spent.
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
		"objectives_done": objectives_done(),
		"objectives_total": objectives_total(),
		"emergency_exfil": emergency_exfil,
		# ADR-006: what the debrief actually pays on.
		"contacts_detected": contacts_detected,
		"contacts_avoided": contacts_avoided(),
	}
