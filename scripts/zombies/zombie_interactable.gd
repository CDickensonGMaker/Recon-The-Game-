## zombie_interactable.gd - base for everything the player can buy or use.
##
## ONE prompt/range implementation. Wall buys, doors, the box and the power-up
## pedestals all differ only in what happens on use, and four copies of "is he
## close enough and looking at it" is four places for the prompt to drift.
class_name ZombieInteractable
extends Node3D

signal used(by: Node)
signal refused(reason: String)

@export var use_radius: float = 2.4
## Held rather than tapped. Rebuilding a barricade must not be a spam-click, and
## a hold reads as effort.
@export var hold_seconds: float = 0.0

var _hold_t: float = 0.0


func _ready() -> void:
	add_to_group("zombie_interactables")


## Overridden by each buyable. Base cost of 0 means "not for sale".
func cost() -> int:
	return 0


## What the HUD shows when in range. Concrete classes build the whole line - the
## price has to be IN the prompt, or the player is guessing what he can afford.
func prompt() -> String:
	return ""


func in_range(who: Node3D) -> bool:
	return who != null and is_instance_valid(who) \
		and global_position.distance_to(who.global_position) <= use_radius


func can_use(_who: Node) -> bool:
	return true


## Call every frame the use key is held. Returns true on the frame it fires.
func try_use(who: Node, delta: float = 0.0) -> bool:
	if not can_use(who):
		return false
	if hold_seconds > 0.0:
		_hold_t += delta
		if _hold_t < hold_seconds:
			return false
	_hold_t = 0.0
	_on_use(who)
	used.emit(who)
	return true


func release() -> void:
	_hold_t = 0.0


func hold_progress() -> float:
	return 0.0 if hold_seconds <= 0.0 else clampf(_hold_t / hold_seconds, 0.0, 1.0)


func _on_use(_who: Node) -> void:
	pass


## Shared helper: charge the run's wallet, or emit a refusal the HUD can flash.
func _charge(kind: String, id: String, amount: int) -> bool:
	var econ: ZombieEconomy = ZombieEconomy.current
	if econ == null:
		return false
	if not econ.spend(amount, kind, id):
		refused.emit("insufficient")
		return false
	return true
