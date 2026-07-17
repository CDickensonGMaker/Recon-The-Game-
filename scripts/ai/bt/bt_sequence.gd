## bt_sequence.gd - ticks children in order. SUCCESS on all-success.
## FAILURE on first child FAILURE. RUNNING if any child is RUNNING.
class_name BTSequence
extends BTNode

var children: Array[BTNode] = []

func _init(c: Array[BTNode] = []) -> void:
	children = c

func _tick(civ: Civilian, bb: Dictionary) -> int:
	for child in children:
		var s: int = child.tick(civ, bb)
		if s == BTStatus.FAILURE:
			return BTStatus.FAILURE
		if s == BTStatus.RUNNING:
			return BTStatus.RUNNING
	return BTStatus.SUCCESS
