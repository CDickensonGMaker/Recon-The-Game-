## squad_leader.gd - first AI in a fireteam. Picks the waypoint, owns the formation.
## Followers read formation_positions(leader_pos, leader_facing, count) and slot in.
## Inherits EnemyBase's goal FSM + cover/perception machinery; the only addition is
## movement coordination across the squad.
class_name SquadLeader
extends EnemyBase

## Member instance-id -> formation slot index (0=point, 1..n=followers).
## Slots are stable for the squad's lifetime so a man who has cover-left keeps it.
var _slot_assignments: Dictionary = {}

## Active waypoint the squad is moving toward. Followers read this through
## EnemySquad so the leader's think rate is the bottleneck, not the followers'.
var waypoint: Vector3 = Vector3.ZERO
var has_waypoint: bool = false


func _ready() -> void:
	# SquadLeader is just an EnemyBase that publishes its waypoint. No extra nodes.
	pass


## Assign a stable formation slot. Returns 0 for the leader (always the point).
func assign_slot(member: Object) -> int:
	if member == null:
		return 0
	var mid: int = member.get_instance_id()
	if not _slot_assignments.has(mid):
		_slot_assignments[mid] = _slot_assignments.size()
	return int(_slot_assignments[mid])


## Move the whole squad toward `target`. The leader navigates; followers slot.
func set_squad_waypoint(target: Vector3) -> void:
	waypoint = target
	has_waypoint = true
	move_target = target
	is_moving = true
