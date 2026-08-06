## zombie_power_up.gd - a bought-once perk pedestal.
##
## Three of them, per the scope ruling. Each has to be worth a round's income or
## it is a distraction from the box.
class_name ZombiePowerUp
extends ZombieInteractable

signal granted(id: String)

## Key into ZombieEconomy.POWER_UPS: stamina | toughness | speedload
@export var power_id: String = "stamina"


func _ready() -> void:
	super()
	add_to_group("zombie_power_ups")
	hold_seconds = 0.4
	if not ZombieEconomy.POWER_UPS.has(power_id):
		push_warning("[POWERUP] '%s' is not in ZombieEconomy.POWER_UPS" % power_id)


func _spec() -> Dictionary:
	return ZombieEconomy.POWER_UPS.get(power_id, {}) as Dictionary


func _owned() -> bool:
	var econ: ZombieEconomy = ZombieEconomy.current
	return econ != null and econ.has_power_up(power_id)


func cost() -> int:
	return int(_spec().get("cost", 0))


func prompt() -> String:
	var spec: Dictionary = _spec()
	if spec.is_empty() or _owned():
		return ""
	return "Hold [E] - %s  %d" % [String(spec["label"]).to_upper(), cost()]


func can_use(_who: Node) -> bool:
	return not _spec().is_empty() and not _owned()


func _on_use(_who: Node) -> void:
	var econ: ZombieEconomy = ZombieEconomy.current
	if econ == null or not econ.buy_power_up(power_id):
		refused.emit("insufficient")
		return
	granted.emit(power_id)
