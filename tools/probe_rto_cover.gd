## probe_rto_cover.gd - RTO cord doctrine, measured (Summoner ruling 2026-08-04).
##
## The claim under test: when the player lives, the RTO's cover search stays
## inside the net cord (candidates within RTO_CORD_LEASH of the player; if none,
## nearest-to-player wins), and prefers spots with the player between him and
## the threat (SHADOW WEIGHT). A RIFLEMAN at the same spot must be untouched.
##
## MUST run as a SCENE, not with -s (autoloads):
##   godot --headless --path . res://tools/probe_rto_cover.tscn
extends Node

var _fails: int = 0


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
	print("\n=== RTO CORD DOCTRINE ===\n")
	await _s1_shadow_inside_leash()
	await _s2_no_cover_inside_leash()
	print("")
	if _fails == 0:
		print("*** CORD HOLDS. The radio stays with the map. ***")
	else:
		print("*** %d FAILURE(S) - THE RTO STILL WANDERS ***" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(what: String, pass_: bool, detail: String = "") -> void:
	if not pass_:
		_fails += 1
	print("  [%s] %s%s" % ["PASS" if pass_ else "FAIL",
		what, ("   (%s)" % detail) if detail != "" else ""])


func _arena() -> Node3D:
	EnemyBase._cover_claims.clear()
	var holder := Node3D.new()
	add_child(holder)
	_floor(holder)
	return holder


func _floor(holder: Node3D) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(200.0, 1.0, 200.0)
	col.shape = shape
	body.add_child(col)
	body.collision_layer = 1
	holder.add_child(body)
	body.global_position = Vector3(0.0, -0.5, 0.0)


func _wall(holder: Node3D, center_x: float, half_w: float, z: float) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(half_w * 2.0, 2.5, 0.5)
	col.shape = shape
	body.add_child(col)
	body.collision_layer = 1
	holder.add_child(body)
	body.global_position = Vector3(center_x, 1.25, z)


func _man(holder: Node3D, at: Vector3, mos: String) -> AllyBase:
	var a: AllyBase = AllyBase.spawn_ally(holder, at)
	a.member = {"mos": mos}
	a.set_order(AllyBase.OrderMode.HOLD)
	a.last_known_target_pos = THREAT
	return a


const THREAT := Vector3(0.0, 0.0, 30.0)


func _player(holder: Node3D) -> Node3D:
	var p := CharacterBody3D.new()
	holder.add_child(p)
	p.global_position = Vector3.ZERO
	GameManager.player = p
	return p


func _shadow_dot(c: Vector3, player_pos: Vector3) -> float:
	var to_player: Vector3 = player_pos - c
	var to_threat: Vector3 = THREAT - c
	to_player.y = 0.0
	to_threat.y = 0.0
	if to_player.length() < 0.05 or to_threat.length() < 0.05:
		return 0.0
	return to_player.normalized().dot(to_threat.normalized())


## Wall behind the player: candidates behind the map-man are valid hard cover,
## inside the cord. The RTO must take one of THOSE, in the player's shadow.
func _s1_shadow_inside_leash() -> void:
	print("-- 1. COVER EXISTS INSIDE THE CORD (wall behind the player) --")
	var h := _arena()
	var pl := _player(h)
	_wall(h, 0.0, 4.0, 1.0)
	var rto := _man(h, Vector3(0.0, 0.0, -4.0), "RTO")
	await get_tree().physics_frame
	var p := rto._find_cover_point()
	var d: float = p.distance_to(pl.global_position)
	var dot: float = _shadow_dot(p, pl.global_position)
	_check("RTO found cover", p != Vector3.ZERO, str(p))
	_check("chosen cover inside the 8m cord", p != Vector3.ZERO and d <= 8.0,
		"dist-to-player = %.2fm" % d)
	_check("player sits between RTO cover and threat", dot >= 0.9,
		"shadow dot = %.3f" % dot)
	EnemyBase._cover_claims.clear()
	var rifleman := _man(h, Vector3(0.0, 0.0, -4.0), "RIFLEMAN")
	await get_tree().physics_frame
	var rp := rifleman._find_cover_point()
	print("     control RIFLEMAN same spot: %s  dist-to-player = %.2fm  dot = %.3f"
		% [str(rp), rp.distance_to(pl.global_position), _shadow_dot(rp, pl.global_position)])
	GameManager.player = null
	h.queue_free()
	await get_tree().process_frame


## The RTO strayed 14m out with a wall of his own: every candidate is outside
## the cord, so nearest-to-player must win - never the 3m rock beside him.
func _s2_no_cover_inside_leash() -> void:
	print("\n-- 2. NO COVER INSIDE THE CORD (RTO strayed to x=14) --")
	var h := _arena()
	var pl := _player(h)
	_wall(h, 12.0, 6.0, 1.0)
	var rto := _man(h, Vector3(14.0, 0.0, -4.0), "RTO")
	await get_tree().physics_frame
	var p := rto._find_cover_point()
	var d: float = p.distance_to(pl.global_position)
	_check("RTO found cover", p != Vector3.ZERO, str(p))
	_check("fallback pulls TOWARD the player (nearest-to-player, not 3m-to-self)",
		p != Vector3.ZERO and d < rto.global_position.distance_to(pl.global_position),
		"dist-to-player = %.2fm vs RTO at %.2fm" % [d, rto.global_position.distance_to(pl.global_position)])
	EnemyBase._cover_claims.clear()
	var rifleman := _man(h, Vector3(14.0, 0.0, -4.0), "RIFLEMAN")
	await get_tree().physics_frame
	var rp := rifleman._find_cover_point()
	var rd: float = rp.distance_to(pl.global_position)
	_check("RIFLEMAN control is untouched (picks by his own distance)",
		rp != Vector3.ZERO and rp.distance_to(rifleman.global_position) <= 3.5,
		"his pick %.2fm from self, %.2fm from player" % [rp.distance_to(rifleman.global_position), rd])
	print("     RTO %.2fm from player vs RIFLEMAN %.2fm - the cord is the difference" % [d, rd])
	GameManager.player = null
	h.queue_free()
	await get_tree().process_frame
