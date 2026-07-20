## group_walk.gd - assign walk targets to a household travelling together.
##
## MOVEMENT AUTHORITY: this file writes NO velocity. `Civilian._step_toward`,
## called once per frame at the tail of `Civilian._bt_tick`, is the only thing
## that moves a civilian. GroupWalk only decides WHERE each member is walking:
## the lead gets the group destination, followers get a slot behind it.
class_name GroupWalk
extends RefCounted

const FOLLOWER_SPACING: float = 1.6


## Assign `destination` to the lead and a formation slot to every follower.
## Returns the lead (or null if the party has no living member).
static func tick(civs: Array, destination: Vector3) -> Civilian:
	var lead: Civilian = lead_of(civs)
	if lead == null:
		return null
	lead.is_group_lead = true
	lead.group_destination = destination
	var to_dest: Vector3 = destination - lead.global_position
	to_dest.y = 0.0
	var heading: Vector3 = to_dest.normalized() if to_dest.length() > 0.1 else Vector3.FORWARD
	var right: Vector3 = heading.cross(Vector3.UP).normalized()
	var slot_idx: int = 0
	for c in civs:
		if c == null or not is_instance_valid(c) or c == lead:
			continue
		var civ: Civilian = c as Civilian
		civ.is_group_lead = false
		var side: float = 1.0 if (slot_idx % 2) == 0 else -1.0
		var ring: int = (slot_idx / 2) + 1
		civ.group_destination = lead.global_position \
			- heading * (FOLLOWER_SPACING * float(ring)) \
			+ right * side * FOLLOWER_SPACING
		slot_idx += 1
	return lead


## The party's lead: the flagged one if it is still alive, else the first living
## member. Members share a group_id, so order is the tiebreak - and spawn order
## is deterministic (ADR-010), so promotion after a death is deterministic too.
static func lead_of(civs: Array) -> Civilian:
	var best: Civilian = null
	for c in civs:
		if c == null or not is_instance_valid(c):
			continue
		var civ: Civilian = c as Civilian
		if civ.state == Civilian.CivState.GONE:
			continue
		if civ.is_group_lead:
			return civ
		if best == null:
			best = civ
	return best
