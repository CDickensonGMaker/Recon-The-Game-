## probe_daylight_death.gd - item 36. Dying before stand-to must still spend a
## body, and a failed scan must NOT latch the pool shut for the rest of the run.
## Run: godot --headless --path . res://tests/probe_daylight_death.tscn
extends Node

var _fails: int = 0


func _ready() -> void:
	print("=== DAYLIGHT BODY-SWAP PROBE (item 36) ===")
	await get_tree().process_frame
	await _case_no_latch()
	await _case_daylight_swap()
	print("=== %s ===" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _fail(msg: String) -> void:
	_fails += 1
	print("[FAIL] %s" % msg)


## A death with NO candidates anywhere must refuse - and must leave the pool
## re-scannable, so the men who stand to later are still worth waking in.
func _case_no_latch() -> void:
	var host := Node3D.new()
	add_child(host)
	var rig: Dictionary = _rig(host)
	var swap: BodySwapSystem = rig["swap"]
	if swap.try_swap():
		_fail("swapped with zero candidates in the tree")
	var men: Array[AllyBase] = _make_men(host, rig["player"], 3)
	await get_tree().process_frame
	print("[PROBE] after stand-to: allies=%d" % men.size())
	if not swap.try_swap():
		_fail("pool latched shut by the earlier empty scan (item 36 root cause)")
	else:
		print("[PROBE] no-latch case: swap accepted after men appeared")
	host.queue_free()
	await get_tree().process_frame


## T+900s, daylight: nobody is promoted, only your own squad is alive.
func _case_daylight_swap() -> void:
	var host := Node3D.new()
	add_child(host)
	var rig: Dictionary = _rig(host)
	var swap: BodySwapSystem = rig["swap"]
	var men: Array[AllyBase] = _make_men(host, rig["player"], 4)
	await get_tree().process_frame
	var promoted: int = get_tree().get_nodes_in_group("garrison_promoted").size()
	print("[PROBE] daylight: garrison_promoted=%d allies=%d" % [promoted, men.size()])
	if promoted != 0:
		_fail("probe setup wrong - somebody is promoted")
	if not swap.try_swap():
		_fail("daylight death spent no body - the run ends at ~T+900s")
	else:
		print("[PROBE] daylight swap accepted; bodies_spent=%s" % str(swap.bodies_spent))
	host.queue_free()
	await get_tree().process_frame


func _rig(host: Node3D) -> Dictionary:
	var player := Node3D.new()
	host.add_child(player)
	player.global_position = Vector3.ZERO
	var hs := HealthSystem.new()
	player.add_child(hs)
	var swap := BodySwapSystem.new()
	player.add_child(swap)
	swap.setup(player, hs, "PFC Probe", Callable())
	return {"player": player, "hs": hs, "swap": swap}


func _make_men(host: Node3D, player: Node3D, n: int) -> Array[AllyBase]:
	var out: Array[AllyBase] = []
	for i in range(n):
		var a: AllyBase = AllyBase.spawn_ally(host, Vector3(float(i + 2), 0.0, 0.0))
		a.member = {"name": "Man%d" % i, "mos": "RIFLEMAN", "missions": 1}
		out.append(a)
	return out
