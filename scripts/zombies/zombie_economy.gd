## zombie_economy.gd - points, and everything points buy.
##
## THE LOOP. Kills pay, points buy, buying opens the map. Without this a wave mode
## is an endless horde with nothing to decide; with it, every round is a question
## about whether to open the next door or save for the box. It is the first thing
## built and the thing to judge the mode on.
##
## A NODE, not an autoload. The mode scene owns one and registers it in `current`;
## ZombieBase reaches it through the static helpers, which no-op when no run is
## live. That keeps the economy out of the shipped autoload list - RECON's campaign
## must not carry a points counter it never uses.
class_name ZombieEconomy
extends Node

signal points_changed(points: int, delta: int, reason: String)
signal purchase_made(kind: String, id: String, cost: int)
signal purchase_refused(kind: String, id: String, cost: int, have: int)

## The run's live economy, or null outside a VC Zombies match.
static var current: ZombieEconomy = null

const STARTING_POINTS: int = 500

## Wall buys. His ruling: five guns only. Prices are the classic shape - the
## starting pistol's upgrade path is cheap, the RPG is the round-15 reward.
const WALL_BUYS: Dictionary = {
	"m16":     {"weapon": "res://data/weapons/m16a1.tres", "cost": 1200, "ammo": 600},
	"ak":      {"weapon": "res://data/weapons/ak47.tres",  "cost": 1400, "ammo": 700},
	"shotgun": {"weapon": "res://data/weapons/shotgun.tres", "cost": 1500, "ammo": 750},
	"m60":     {"weapon": "res://data/weapons/m60.tres",   "cost": 3000, "ammo": 1500},
	"rpg":     {"weapon": "res://data/weapons/rpg7.tres",  "cost": 5000, "ammo": 2500},
}

const MYSTERY_BOX_COST: int = 950
## The box moves. A box that never leaves is a vending machine, and the walk to
## wherever it went is half of what the box is for.
const BOX_MOVE_CHANCE: float = 0.12

## Buyable power-ups. Deliberately a SHORT list - three perks was the scope ruling,
## and each of these has to be worth a round's income.
const POWER_UPS: Dictionary = {
	"stamina":  {"cost": 2000, "label": "Field Ration"},    ## faster, longer sprint
	"toughness":{"cost": 2500, "label": "Flak Vest"},       ## take one more hit
	"speedload":{"cost": 3000, "label": "Quick Hands"},     ## faster reload
}

var points: int = STARTING_POINTS
var owned_power_ups: Dictionary = {}
var opened_doors: Dictionary = {}
var kills: int = 0
var headshots: int = 0


func _ready() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


# ---------------------------------------------------------------- earning

## Points for damage that did not kill. Paid per hit, not per point of damage, or
## the M60 out-earns every other gun by an order of magnitude.
static func award_hit(attacker: Node, amount: int) -> void:
	if current == null or not _is_player(attacker):
		return
	current._add(amount, "hit")


static func award_kill(attacker: Node, amount: int, headshot: bool) -> void:
	if current == null:
		return
	current.kills += 1
	if headshot:
		current.headshots += 1
	if not _is_player(attacker):
		return
	current._add(amount * (2 if headshot else 1), "headshot" if headshot else "kill")


## Only the player earns. A zombie killed by a barricade, a fall or another zombie
## pays nobody - otherwise the round-20 crush prints money on its own.
static func _is_player(n: Node) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	return n == GameManager.player or n.is_in_group("player")


func _add(amount: int, reason: String) -> void:
	points += amount
	points_changed.emit(points, amount, reason)


# ---------------------------------------------------------------- spending

func can_afford(cost: int) -> bool:
	return points >= cost


## The one debit path. Everything that costs points comes through here so a new
## buyable cannot forget to emit, and the HUD can never drift from the wallet.
func spend(cost: int, kind: String, id: String) -> bool:
	if cost > points:
		purchase_refused.emit(kind, id, cost, points)
		return false
	points -= cost
	points_changed.emit(points, -cost, kind)
	purchase_made.emit(kind, id, cost)
	return true


func buy_wall(id: String) -> Dictionary:
	var spec: Dictionary = WALL_BUYS.get(id, {}) as Dictionary
	if spec.is_empty():
		push_warning("[ZECON] no wall buy '%s'" % id)
		return {}
	return spec if spend(int(spec["cost"]), "wall", id) else {}


## Re-buying a gun you already hold buys AMMO for it, at a fraction of the price.
## Without this the wall is dead the moment you own what it sells.
func buy_ammo(id: String) -> bool:
	var spec: Dictionary = WALL_BUYS.get(id, {}) as Dictionary
	if spec.is_empty():
		return false
	return spend(int(spec["ammo"]), "ammo", id)


func buy_door(id: String, cost: int) -> bool:
	if opened_doors.has(id):
		return false
	if not spend(cost, "door", id):
		return false
	opened_doors[id] = true
	return true


func buy_power_up(id: String) -> bool:
	var spec: Dictionary = POWER_UPS.get(id, {}) as Dictionary
	if spec.is_empty() or owned_power_ups.has(id):
		return false
	if not spend(int(spec["cost"]), "power_up", id):
		return false
	owned_power_ups[id] = true
	return true


func has_power_up(id: String) -> bool:
	return owned_power_ups.has(id)


func buy_box() -> bool:
	return spend(MYSTERY_BOX_COST, "box", "mystery_box")
