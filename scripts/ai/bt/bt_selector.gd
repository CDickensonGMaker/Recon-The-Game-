## bt_selector.gd - ticks children in order. SUCCESS on first-success.
## FAILURE if all FAILURE. RUNNING if any child is RUNNING.
class_name BTSelector
extends BTNode

var children: Array[BTNode] = []

func _init(c: Array[BTNode] = []) -> void:
	children = c

func _tick(civ: Civilian, bb: Dictionary) -> int:
	for child in children:
		var s: int = child.tick(civ, bb)
		if s == BTStatus.SUCCESS:
			return BTStatus.SUCCESS
		if s == BTStatus.RUNNING:
			return BTStatus.RUNNING
	return BTStatus.FAILURE
