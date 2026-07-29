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


## NONCOMBATANT DEATHS - a per-patrol count of civilians killed. Surfaced as one
## AAR line (Summoner decree 2026-07-25): the bank point (field_director.fail_mission)
## reads it straight off `state` into the result. Kept DELIBERATELY off _base_result /
## build_result and out of compute_score's key list - whether it ever prices into
## score stays the Summoner's call (ADR-006:10-15, ADR-019 s5).
var civilian_deaths: int = 0


func record_civilian_death() -> void:
	civilian_deaths += 1


## GROUND COVERED (patrol-contract, ADR-029 Amendment C — PROPOSED). Distinct 25m
## sectors the player actually walked: a silent patrol-quality accumulator, banked
## at the wire AAR and read ONLY there. It must never reach the in-field HUD — an
## on-screen coverage counter is the mission tracking ADR-029 §4 forbids. Derived
## from position alone (no RNG), so it is deterministic per walk (ADR-010).
const COVER_CELL_M: float = 25.0
var _covered_cells: Dictionary = {}

## Player marks reached along the planned route this excursion (silent, AAR-only).
var waypoints_reached: int = 0


func mark_covered(pos: Vector3) -> void:
	var key := Vector2i(int(floorf(pos.x / COVER_CELL_M)), int(floorf(pos.z / COVER_CELL_M)))
	_covered_cells[key] = true


func ground_covered_sectors() -> int:
	return _covered_cells.size()


## FIELD MARKS - the INTEL layer (ADR-022 Amendment A). Typed grease-pencil notes:
## pure {kind, area:{x,z,r}, placed_at} dicts and nothing else - no completed flag,
## no objective id, ever (§4). A mark never auto-updates: stale is the intended fog.
## Persist across patrols via CampaignState.field_marks (seeded at setup, banked at
## the wire). placed_at = the patrol number it was placed on.
var field_marks: Array = []


func add_field_mark(kind: String, center: Vector3, radius: float, patrol_no: int) -> void:
	field_marks.append({
		"kind": kind,
		"area": {"x": center.x, "z": center.z, "r": radius},
		"placed_at": patrol_no,
	})


## PENCIL MARKS - the ANNOTATED layer ADR-022 promised and never built. Unlike a field
## mark these need NO line of sight: the player writes what he THINKS, anywhere on the
## sheet, including places he has never been. {x, z, kind, text, placed_at}.
##
## THE GREASE-PENCIL LAW: the game NEVER validates, corrects, moves or auto-erases one
## of these. A note that turns out wrong sits there being wrong until the player
## changes it himself. No "(outdated)" tag, ever.
var pencil_marks: Array = []


func add_pencil_mark(kind: String, x: float, z: float, patrol_no: int) -> int:
	pencil_marks.append({"x": x, "z": z, "kind": kind, "text": "", "placed_at": patrol_no})
	return pencil_marks.size() - 1


## THE ROUTE (patrol-contract decree, 2026-07-28). Indices into FieldDirector's
## patrol_objectives, in the order the player intends to walk them. The circles are
## OFFERED, never REQUIRED - an empty route is legal and costs nothing.
var route_order: Array = []


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
		# Patrol-quality grade (ADR-029 Amendment C — PROPOSED). Reported at the AAR,
		# not scored: the ADR-006 payout hook stays unratified until the Summoner blesses.
		"ground_covered": ground_covered_sectors(),
		"waypoints_reached": waypoints_reached,
	}
