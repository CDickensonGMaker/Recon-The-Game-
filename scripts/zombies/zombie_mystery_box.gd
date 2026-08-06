## zombie_mystery_box.gd - the gamble, and the reason to leave the safe room.
##
## Rolls one of the five guns for less than most of them cost on the wall - the
## trade is that you do not choose, and the box MOVES. A box that never leaves is
## a vending machine; the walk to wherever it went is half of what it is for.
class_name ZombieMysteryBox
extends ZombieInteractable

signal rolled(weapon_path: String)
signal moved(to: Node3D)

## Seconds of theatre before the gun is handed over. The wait is the gamble.
const ROLL_TIME: float = 2.6

var _rolling: bool = false
var _roll_t: float = 0.0
var _pending: String = ""
var _rng := RandomNumberGenerator.new()
var _spots: Array[Node3D] = []


func _ready() -> void:
	super()
	add_to_group("zombie_mystery_box")
	hold_seconds = 0.3
	_rng.seed = 20260805
	_collect_spots()


func _collect_spots() -> void:
	_spots.clear()
	for n in get_tree().get_nodes_in_group("zombie_box_spots"):
		var s := n as Node3D
		if s != null and is_instance_valid(s):
			_spots.append(s)


func _process(delta: float) -> void:
	if not _rolling:
		return
	_roll_t -= delta
	if _roll_t > 0.0:
		return
	_rolling = false
	var p: Node = GameManager.player
	if p != null and is_instance_valid(p) and p.has_method("give_weapon"):
		p.call("give_weapon", _pending)
	rolled.emit(_pending)
	_pending = ""
	if _rng.randf() < ZombieEconomy.BOX_MOVE_CHANCE:
		_relocate()


func cost() -> int:
	return ZombieEconomy.MYSTERY_BOX_COST


func prompt() -> String:
	if _rolling:
		return "..."
	return "Hold [E] - MYSTERY BOX  %d" % cost()


func can_use(_who: Node) -> bool:
	return not _rolling


func _on_use(_who: Node) -> void:
	var econ: ZombieEconomy = ZombieEconomy.current
	if econ == null or not econ.buy_box():
		refused.emit("insufficient")
		return
	# The gun is decided NOW and revealed after the wait. Deciding it when the
	# timer ends would let a mid-roll save/quit reroll the result.
	var ids: Array = ZombieEconomy.WALL_BUYS.keys()
	var pick: Dictionary = ZombieEconomy.WALL_BUYS[ids[_rng.randi() % ids.size()]]
	_pending = String(pick["weapon"])
	_rolling = true
	_roll_t = ROLL_TIME


func _relocate() -> void:
	_collect_spots()
	var far: Array[Node3D] = []
	for s in _spots:
		if s.global_position.distance_to(global_position) > 1.0:
			far.append(s)
	if far.is_empty():
		return
	var to: Node3D = far[_rng.randi() % far.size()]
	global_position = to.global_position
	moved.emit(to)
