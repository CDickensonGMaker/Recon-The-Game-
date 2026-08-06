## zombie_wall_buy.gd - a weapon chalked on a wall.
##
## Five guns only (his ruling): M16, AK, shotgun, M60, RPG. The catalogue and the
## prices live in ZombieEconomy.WALL_BUYS - this node names an entry, it never
## carries its own price, or the wall and the wallet drift.
class_name ZombieWallBuy
extends ZombieInteractable

## Key into ZombieEconomy.WALL_BUYS: m16 | ak | shotgun | m60 | rpg
@export var buy_id: String = "m16"


func _ready() -> void:
	super()
	add_to_group("zombie_wall_buys")
	if not ZombieEconomy.WALL_BUYS.has(buy_id):
		push_warning("[WALLBUY] '%s' is not in ZombieEconomy.WALL_BUYS - this wall "
			+ "sells nothing" % buy_id)


func _spec() -> Dictionary:
	return ZombieEconomy.WALL_BUYS.get(buy_id, {}) as Dictionary


## Owning the gun turns the wall into an ammo box, at the ammo price. Without this
## the wall is dead the moment you buy from it once.
func _player_owns_it() -> bool:
	var p: Node = GameManager.player
	if p == null or not is_instance_valid(p) or not p.has_method("has_weapon_path"):
		return false
	return bool(p.call("has_weapon_path", String(_spec().get("weapon", ""))))


func cost() -> int:
	var spec: Dictionary = _spec()
	if spec.is_empty():
		return 0
	return int(spec["ammo"]) if _player_owns_it() else int(spec["cost"])


func prompt() -> String:
	var spec: Dictionary = _spec()
	if spec.is_empty():
		return ""
	var label: String = buy_id.to_upper()
	return ("Hold [E] - %s AMMO  %d" if _player_owns_it() else "Hold [E] - %s  %d") \
		% [label, cost()]


func can_use(_who: Node) -> bool:
	return not _spec().is_empty()


func _on_use(who: Node) -> void:
	var spec: Dictionary = _spec()
	var ammo_only: bool = _player_owns_it()
	if not _charge("ammo" if ammo_only else "wall", buy_id, cost()):
		return
	var p: Node = who if who != null else GameManager.player
	if p == null or not is_instance_valid(p):
		return
	if ammo_only:
		if p.has_method("refill_ammo"):
			p.call("refill_ammo", String(spec["weapon"]))
	elif p.has_method("give_weapon"):
		p.call("give_weapon", String(spec["weapon"]))
