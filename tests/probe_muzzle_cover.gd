## probe_muzzle_cover.gd - item 8, "own squad fires inside the wire."
##
## Half of this item was already refuted: ally LOS DOES test terrain and world colliders
## (ally_base.gd:1032-1034 -> CombatManager.has_line_of_sight + SightCap). The collider
## hypothesis that was left is this one, and it is not about sight at all:
##
##   LOS is measured from the EYE at +1.5m. The round leaves the MUZZLE.
##   Behind a parapet those are not the same line - the eye clears the sandbags and the
##   gun does not - and the pre-fire lane check aborted only on FLESH. So a squadmate
##   with a clear view of a target fired into the wall a foot in front of him: flash,
##   tracer and report, all inside the wire, at his own parapet.
##
## Measured with real physics rays against real geometry, not a table.
##   godot --headless --path . res://tests/probe_muzzle_cover.tscn
extends Node

const TARGET_M: float = 30.0

var _failures: int = 0
var _space: PhysicsDirectSpaceState3D = null


func _fail(msg: String) -> void:
	print("FAIL: %s" % msg)
	_failures += 1


func _ready() -> void:
	_run()


func _run() -> void:
	print("=== MUZZLE COVER PROBE (item 8) ===")
	_space = get_viewport().world_3d.direct_space_state

	# The parapet he is standing behind: 1.2m of sandbag, half a metre in front of him.
	var parapet: StaticBody3D = _box(Vector3(0, 0.6, -0.5), Vector3(8, 1.2, 0.4))
	# The treeline the ENEMY is behind, 22m out. Rounds into that are suppression.
	var far_cover: StaticBody3D = _box(Vector3(0, 1.5, -22.0), Vector3(8, 3.0, 0.4))
	far_cover.process_mode = Node.PROCESS_MODE_INHERIT
	await get_tree().physics_frame

	# 1. THE EYE CLEARS IT. This is what the sight system sees, and it is right.
	var eye := Vector3(0, 1.5, 0)
	# 2m only: at 30m this ray reaches the ENEMY'S treeline and that is not the
	# question. The first run of this probe cast the full range and read the
	# treeline as the parapet.
	if _ray_len(eye, Vector3.FORWARD, 2.0).is_empty():
		print("  eye at 1.5m: the parapet is below his line - LOS is clear, correctly")
	else:
		_fail("the probe's own parapet blocks the eye - the geometry is wrong, not the code")

	# 2. THE MUZZLE DOES NOT. Same man, gun at 1.0m: this is the defect.
	var muzzle := Vector3(0, 1.0, 0)
	var r_near: Dictionary = _ray(muzzle, Vector3.FORWARD)
	var d_near: float = AllyBase.muzzle_foul_distance(r_near, muzzle)
	if d_near < 0.0:
		_fail("a muzzle 0.3m from a 1.2m parapet reads CLEAR - he still shoots his own cover")
	else:
		print("  muzzle at 1.0m: FOULED at %.2fm - he holds the round" % d_near)

	# 3. AND HE IS NOT DISARMED BY DISTANT COVER. The enemy's treeline at 22m must
	#    still be shootable, or "muzzle discipline" becomes "never fire".
	parapet.queue_free()
	await get_tree().physics_frame
	var r_far: Dictionary = _ray(muzzle, Vector3.FORWARD)
	var d_far: float = AllyBase.muzzle_foul_distance(r_far, muzzle)
	if d_far >= 0.0:
		_fail("cover 22m out reads as his own parapet (%.2fm) - the squad would never fire"
			% d_far)
	else:
		print("  the enemy's treeline 22m out: not fouled - he suppresses it")

	# 4. Open ground is open ground.
	far_cover.queue_free()
	await get_tree().physics_frame
	var r_open: Dictionary = _ray(muzzle, Vector3.FORWARD)
	if AllyBase.muzzle_foul_distance(r_open, muzzle) >= 0.0:
		_fail("empty air reads as cover")
	else:
		print("  open ground: clear")

	if _failures == 0:
		print("=== PASS ===")
	else:
		print("=== FAIL (%d) ===" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _ray(from: Vector3, dir: Vector3) -> Dictionary:
	return _ray_len(from, dir, TARGET_M)


func _ray_len(from: Vector3, dir: Vector3, length: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * length, 1 | 2 | 4 | 32 | 64)
	q.collide_with_areas = true
	return _space.intersect_ray(q)


func _box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	body.add_child(cs)
	add_child(body)
	body.global_position = at
	return body
