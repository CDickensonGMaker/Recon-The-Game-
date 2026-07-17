## bt_conditions.gd - pure-condition BT nodes. Return SUCCESS when true.
class_name BTCondition
extends BTNode

var fn: Callable
var label: String = ""

func _init(callable: Callable, lbl: String = "") -> void:
	fn = callable
	label = lbl

func _tick(civ: Civilian, bb: Dictionary) -> int:
	if not fn.is_valid():
		return BTStatus.FAILURE
	return BTStatus.SUCCESS if bool(fn.call(civ, bb)) else BTStatus.FAILURE
