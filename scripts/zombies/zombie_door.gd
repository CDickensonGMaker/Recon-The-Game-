## zombie_door.gd - a buyable door, and the map's pacing.
##
## Doors are how a round-based map grows. Round 1 you are in one room with one
## window; by round 12 you have bought your way into three more and the horde
## comes from everywhere. Permanent once bought - re-closable doors turn the mode
## into a puzzle about doors.
##
## NAVIGATION: the navmesh is baked with every doorway OPEN and never rebakes
## (same reasoning as ZombieBarricade). A closed door is a physical blocker only.
## Nothing needs to path through it, because zombies only spawn in zones the
## player has already opened, and the player cannot be past a door he has not
## bought.
class_name ZombieDoor
extends ZombieInteractable

signal opened(zone: String)

@export var door_id: String = ""
@export var price: int = 1000
## The zone this door unlocks. ZombieSpawnPoint reads it - a spawn in a sealed
## zone must stay silent or the horde arrives from a room he has never seen.
@export var unlocks_zone: String = ""

var is_open: bool = false
var _blocker: StaticBody3D = null
var _leaf: Node3D = null


func _ready() -> void:
	super()
	add_to_group("zombie_doors")
	if door_id.is_empty():
		door_id = name
	hold_seconds = 0.35
	_blocker = get_node_or_null("Blocker") as StaticBody3D
	_leaf = get_node_or_null("Leaf") as Node3D


func cost() -> int:
	return price


func prompt() -> String:
	if is_open:
		return ""
	return "Hold [E] - OPEN  %d" % price


func can_use(_who: Node) -> bool:
	return not is_open


func _on_use(_who: Node) -> void:
	var econ: ZombieEconomy = ZombieEconomy.current
	if econ == null:
		return
	if not econ.buy_door(door_id, price):
		refused.emit("insufficient")
		return
	open()


## Public so a debug key or a test can open a door without paying.
func open() -> void:
	if is_open:
		return
	is_open = true
	if _blocker != null:
		for c in _blocker.get_children():
			var cs := c as CollisionShape3D
			if cs != null:
				cs.disabled = true
	if _leaf != null:
		_leaf.visible = false
	opened.emit(unlocks_zone)
