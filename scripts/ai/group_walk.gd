## group_walk.gd - drive a group of civilians toward a shared destination.
## Picks the lead (the one with `is_group_lead == true`); followers slot at
## 1.2m offset perpendicular to the group's heading. If the lead dies, promote
## the next-lowest group_id.
##
## Used for families walking to market, families walking to the paddy, etc.
## Civilians in a group override their own BT walk target with this one.
class_name GroupWalk
extends RefCounted

const FOLLOWER_SPACING: float = 1.6
const STOP_RADIUS: float = 1.8


## Tick one group's civilians. Returns the leader (or null if empty).
static func tick(civs: Array, destination: Vector3, delta: float) -> Civilian:
	if civs.is_empty():
		return null
	var lead: Civilian = _pick_lead(civs)
	if lead == null:
		return null
	lead.group_destination = destination
	lead.is_group_lead = true
	lead.active_action = &"walk_group"
	# Walk the lead
	var to_dest: Vector3 = destination - lead.global_position
	to_dest.y = 0.0
	if to_dest.length() < STOP_RADIUS:
		lead.velocity.x = 0
		lead.velocity.z = 0
	else:
		var dir: Vector3 = to_dest.normalized()
		lead.velocity.x = lerpf(lead.velocity.x, dir.x * 1.5, delta * 6.0)
		lead.velocity.z = lerpf(lead.velocity.z, dir.z * 1.5, delta * 6.0)
	# Slot followers. Stagger left/right of the lead's heading.
	var heading: Vector3 = to_dest.normalized() if to_dest.length() > 0.1 else Vector3.FORWARD
	var right: Vector3 = heading.cross(Vector3.UP).normalized()
	var slot_idx: int = 0
	for c in civs:
		if c == lead or not is_instance_valid(c):
			continue
		c.is_group_lead = false
		var side: float = 1.0 if (slot_idx % 2) == 0 else -1.0
		var ring: int = (slot_idx / 2) + 1
		var slot_pos: Vector3 = lead.global_position \
			- heading * (FOLLOWER_SPACING * float(ring)) \
			+ right * side * FOLLOWER_SPACING
		var to_slot: Vector3 = slot_pos - c.global_position
		to_slot.y = 0.0
		c.velocity.x = lerpf(c.velocity.x, to_slot.x * 4.0, delta * 6.0)
		c.velocity.z = lerpf(c.velocity.z, to_slot.z * 4.0, delta * 6.0)
		c.active_action = &"walk_group"
		slot_idx += 1
	return lead


static func _pick_lead(civs: Array) -> Civilian:
	var best: Civilian = null
	for c in civs:
		if c == null or not is_instance_valid(c):
			continue
		if c.is_group_lead:
			return c
		if best == null or c.group_id < best.group_id:
			best = c
	return best
