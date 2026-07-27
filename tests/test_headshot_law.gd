## test_headshot_law.gd - a headshot kills ANYONE (Summoner's ruling 2026-07-27).
##
## Before the ruling only enemy_base implemented the ADR-016 fatal bypass, so at
## falloff range an ally or the player SURVIVED a headshot that always killed a
## VC: ally 80 hp vs an M16 head hit at max range = 27 x 4.0 x 0.65 = 70.
##
## LETHAL_AT_RANGE below is that number. It must kill every actor and it must
## not be enough to kill any of them on raw damage alone - if it ever is, this
## probe stops proving the bypass and says so.
## Run: godot --headless --path . res://tests/test_headshot_law.tscn
extends Node3D

## M16A1 headshot at max range: base 27 x HEAD 4.0 x min_damage_mult 0.65.
const LETHAL_AT_RANGE: int = 70
const VC_DATA: String = "res://data/enemies/vc_rifleman.tres"

var _failures: int = 0


func _fail(msg: String) -> void:
	print("FAIL: %s" % msg)
	_failures += 1


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fail(msg)


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	# The rule has ONE owner; everything below must agree with it.
	_check(Hitzone.zone_name_is_fatal("HEAD"), "zone_name_is_fatal('HEAD') is false - the law is inverted")
	_check(not Hitzone.zone_name_is_fatal("BODY"), "zone_name_is_fatal('BODY') is true - everything would be fatal")

	await _ally()
	await _enemy()
	_player()
	_civilian()

	if _failures == 0:
		print("PASS: a headshot kills ally, enemy, player and civilian alike")
		get_tree().quit(0)
	else:
		print("FAILED: %d violations" % _failures)
		get_tree().quit(1)


func _ally() -> void:
	var a: AllyBase = AllyBase.spawn_ally(self, Vector3.ZERO)
	await get_tree().process_frame
	_check(a.max_hp > LETHAL_AT_RANGE,
		"ally max_hp %d <= %d - raw damage alone would kill him and this case proves nothing"
			% [a.max_hp, LETHAL_AT_RANGE])
	a.take_damage(LETHAL_AT_RANGE, Enums.DamageType.PHYSICAL, null, "HEAD")
	await get_tree().process_frame
	_check(a.current_state == Enums.AIState.DEAD,
		"ALLY survived a headshot (hp %d/%d)" % [a.current_hp, a.max_hp])

	# Control: the same damage to the body must NOT kill him.
	var b: AllyBase = AllyBase.spawn_ally(self, Vector3(4, 0, 0))
	await get_tree().process_frame
	b.take_damage(LETHAL_AT_RANGE, Enums.DamageType.PHYSICAL, null, "BODY")
	await get_tree().process_frame
	_check(b.current_state != Enums.AIState.DEAD,
		"CONTROL DEAD: %d body damage killed an %d hp ally, so the headshot case proves nothing"
			% [LETHAL_AT_RANGE, b.max_hp])


func _enemy() -> void:
	if not ResourceLoader.exists(VC_DATA):
		_fail("enemy data '%s' missing - cannot test the enemy half" % VC_DATA)
		return
	var e: EnemyBase = EnemyBase.spawn_enemy(self, Vector3(8, 0, 0), VC_DATA)
	if e == null:
		_fail("spawn_enemy returned null - cannot test the enemy half")
		return
	await get_tree().process_frame
	e.take_damage(LETHAL_AT_RANGE, Enums.DamageType.PHYSICAL, null, "HEAD")
	await get_tree().process_frame
	_check(e.current_state == Enums.AIState.DEAD, "ENEMY survived a headshot (hp %d)" % e.current_hp)


## The player's sink. A headshot must reach force_death, NOT the medic revive
## window - a revivable headshot is not a fatal one.
func _player() -> void:
	var hs := HealthSystem.new()
	add_child(hs)
	hs.revive_handler = _AlwaysRevives.new()
	add_child(hs.revive_handler)
	var died := [false]
	hs.died.connect(func() -> void: died[0] = true)
	_check(hs.max_hp > LETHAL_AT_RANGE,
		"player max_hp %d <= %d - the case proves nothing" % [hs.max_hp, LETHAL_AT_RANGE])
	hs.take_damage(LETHAL_AT_RANGE, Enums.DamageType.PHYSICAL, null, "HEAD")
	_check(died[0], "PLAYER survived a headshot (hp %d)" % hs.current_hp)
	_check(not hs.is_downed, "player headshot put him in the revive window - a headshot is final")


func _civilian() -> void:
	var c := Civilian.new()
	add_child(c)
	c.take_damage(LETHAL_AT_RANGE, Enums.DamageType.PHYSICAL, null, "HEAD")
	_check(c.state == Civilian.CivState.GONE, "CIVILIAN survived a headshot")


## Stands in for SquadSystem: always offers a revive, so a headshot that lands
## in the downed window is caught instead of passing silently.
class _AlwaysRevives extends Node:
	func can_revive() -> bool:
		return true

	func begin_revive(_hs: Node) -> void:
		pass
