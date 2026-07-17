## bt_action.gd - leaf node wrapping a Callable. SUCCESS / RUNNING / FAILURE
## are the callee's choice. The Callable receives (civ, bb).
class_name BTAction
extends BTNode

var fn: Callable
var label: String = ""

func _init(callable: Callable, lbl: String = "") -> void:
	fn = callable
	label = lbl

func _tick(civ: Civilian, bb: Dictionary) -> int:
	if not fn.is_valid():
		return BTStatus.FAILURE
	return int(fn.call(civ, bb))
