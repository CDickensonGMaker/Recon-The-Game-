## bt_node.gd - base class for behavior tree nodes.
## tick() returns RUNNING, SUCCESS, or FAILURE. Subclasses override _tick().
## status is a contract: SUCCESS terminates the parent sequence/selector path,
## FAILURE skips siblings, RUNNING means "call me again next frame."
class_name BTNode
extends RefCounted

enum BTStatus { RUNNING, SUCCESS, FAILURE }

var status: int = BTStatus.RUNNING

func tick(civ: Civilian, bb: Dictionary) -> int:
	status = _tick(civ, bb)
	return status

func _tick(_civ: Civilian, _bb: Dictionary) -> int:
	return BTStatus.SUCCESS

func reset() -> void:
	status = BTStatus.RUNNING
