## test_hitzone_rebuild.gd - a body swap must rebuild the man's damage regions.
##
## AllyBase.set_sprite frees the ModelActor and builds a new one (SquadSystem swaps
## every specialist body AFTER _ready has already run). The hitzones are convex
## hulls cut from the OLD body's meshes, riding the OLD skeleton's bone indices -
## if the swap does not rebuild them, the MG gunner is shot through the rifleman's
## silhouette for the whole mission.
##
## Discriminator: us_grunt_v3 and us_grunt_mg harvest different hull point counts.
## The probe asserts the discriminator is alive before it trusts any result.
##
## NEGATIVE CONTROL (case D): the pre-fix code path is run deliberately and must
## FAIL to carry the new body's hulls. If D ever stops showing the defect, this
## probe is no longer proving anything and says so.
##
## Run: godot --headless --path . res://tests/test_hitzone_rebuild.tscn
extends Node3D

const SWAP_UNIT: String = "us_grunt_mg"
const SWAP_WEAPON: String = "m60"

var _failures: int = 0


func _fail(msg: String) -> void:
	print("FAIL: %s" % msg)
	_failures += 1


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	# A: the stock body, as spawned.
	var a: AllyBase = AllyBase.spawn_ally(self, Vector3.ZERO)
	await get_tree().process_frame
	var stock_unit: String = a.sprite_unit
	var prints_a: Dictionary = _hull_prints(a)

	# B: the reference. Built straight off a fresh ModelActor so it can never
	# inherit the very defect under test.
	var b := Node3D.new()
	add_child(b)
	b.global_position = Vector3(4, 0, 0)
	var ma := ModelActor.new()
	b.add_child(ma)
	if not ma.setup(SWAP_UNIT):
		_fail("cannot build reference actor '%s' - probe is blind" % SWAP_UNIT)
		_finish()
		return
	HitzoneBuilder.build(b, ma, 32, 16, ["hitzone"], false)
	await get_tree().process_frame
	var prints_b: Dictionary = _hull_prints(b)

	if prints_a.is_empty() or prints_b.is_empty():
		_fail("no hull zones harvested - rig or spawn path broken, probe is blind")
		_finish()
		return
	if prints_a == prints_b:
		_fail("%s and %s harvest identical hulls %s - the discriminator is DEAD, this probe proves nothing"
			% [stock_unit, SWAP_UNIT, prints_a])
		_finish()
		return
	print("  discriminator alive: %s=%s vs %s=%s" % [stock_unit, prints_a, SWAP_UNIT, prints_b])

	# C: the real path. set_sprite must leave exactly the reference zone set.
	var c: AllyBase = AllyBase.spawn_ally(self, Vector3(8, 0, 0))
	await get_tree().process_frame
	var before_ids: Array[int] = []
	for hz in _zones(c):
		before_ids.append(hz.get_instance_id())
	c.set_sprite(SWAP_UNIT, SWAP_WEAPON)
	await get_tree().process_frame

	var zones_c: Array[Hitzone] = _zones(c)
	if zones_c.size() != _zones(b).size():
		_fail("after swap the man carries %d zones, native %s carries %d (stale set left behind)"
			% [zones_c.size(), SWAP_UNIT, _zones(b).size()])
	for hz in zones_c:
		if before_ids.has(hz.get_instance_id()):
			_fail("zone '%s' survived the swap - it is cut from the OLD body and rides a freed skeleton"
				% str(hz.get_meta("region", "?")))
	if c._hitzone_sync.size() != zones_c.size():
		_fail("sync table holds %d entries for %d live zones" % [c._hitzone_sync.size(), zones_c.size()])
	var prints_c: Dictionary = _hull_prints(c)
	if prints_c != prints_b:
		_fail("swapped man wears hulls %s, native %s wears %s" % [prints_c, SWAP_UNIT, prints_b])
	else:
		print("  swapped man wears the %s hull set %s across %d zones"
			% [SWAP_UNIT, prints_c, zones_c.size()])

	# D: negative control - the pre-fix path, run on purpose.
	var d: AllyBase = AllyBase.spawn_ally(self, Vector3(12, 0, 0))
	await get_tree().process_frame
	d.sprite_actor.queue_free()
	d.sprite_actor = null
	d.sprite_unit = SWAP_UNIT
	d.sprite_weapon = SWAP_WEAPON
	d._setup_visual()
	await get_tree().process_frame
	var prints_d: Dictionary = _hull_prints(d)
	if prints_d != prints_a:
		_fail("NEGATIVE CONTROL DEAD: the un-rebuilt path produced %s, expected the stale %s hulls %s"
			% [prints_d, stock_unit, prints_a])
	else:
		print("  negative control holds: skipping the rebuild leaves the stale %s hulls %s"
			% [stock_unit, prints_d])

	_finish()


func _finish() -> void:
	if _failures == 0:
		print("PASS: a body swap rebuilds the man's hitzones against the new skeleton")
		get_tree().quit(0)
	else:
		print("FAILED: %d violations" % _failures)
		get_tree().quit(1)


func _zones(a: Node3D) -> Array[Hitzone]:
	var out: Array[Hitzone] = []
	for ch in a.get_children():
		var hz := ch as Hitzone
		if hz != null:
			out.append(hz)
	return out


## region -> harvested hull point count. The count is a fingerprint of WHICH body
## the zone was cut from; it is not a tuning value and nothing balances on it.
func _hull_prints(a: Node3D) -> Dictionary:
	var out: Dictionary = {}
	for hz in _zones(a):
		var pts: PackedVector3Array = hz.get_meta("hull_points", PackedVector3Array())
		if pts.size() > 0:
			out[str(hz.get_meta("region", "?"))] = pts.size()
	return out
