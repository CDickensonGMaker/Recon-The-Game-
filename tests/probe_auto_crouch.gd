## probe_auto_crouch.gd - item 3, THE CODE HALF: does a low ceiling duck him?
##
## tools/probe_bunker_entry.tscn measured the compound and found the doorways open
## (36 of 37 fire points nav-reachable, 32 of 36 routes clear a torso capsule) but the
## ROOMS closed: only 6 of 37 take a standing 1.8m player, 19 take him only crouched.
## Crouch was Ctrl and only Ctrl, so he walked into the lintel and stopped.
##
## This builds the defect in miniature - a floor, a lintel he can duck, and a wall he
## cannot - and drives the real Player. Four cases, and the WALL case is the one that
## matters: an auto-crouch that ducks at every wall is worse than none.
##   godot --headless --path . res://tests/probe_auto_crouch.tscn
extends Node

## Under the player's 1.8m standing capsule, over his 0.9m crouch.
const LINTEL_UNDERSIDE_Y: float = 1.30
const LINTEL_X: float = 3.0
const WALL_X: float = -3.0

var _failures: int = 0
var _player: CharacterBody3D = null


func _fail(msg: String) -> void:
	print("FAIL: %s" % msg)
	_failures += 1


func _ready() -> void:
	_run()


func _run() -> void:
	_box(Vector3(0, -0.5, 0), Vector3(40, 1, 40))                       # floor
	# The duckable opening: a slab whose underside sits at 1.30m, nothing below it.
	_box(Vector3(LINTEL_X, LINTEL_UNDERSIDE_Y + 0.6, 0), Vector3(2, 1.2, 6))
	# The wall: solid from the floor up. Crouching does not help here.
	_box(Vector3(WALL_X, 1.25, 0), Vector3(1, 2.5, 6))

	var ps: PackedScene = load("res://scenes/player/player.tscn")
	_player = ps.instantiate() as CharacterBody3D
	add_child(_player)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# 1. OPEN GROUND, standing still. Nothing may duck him here.
	_case("open ground, still", Vector3(0, 0, 0), Vector3.ZERO, false)
	# 2. OPEN GROUND, walking. Still nothing.
	_case("open ground, walking", Vector3(0, 0, 0), Vector3(2.0, 0, 0), false)
	# 3. THE DUCK: one stride short of the lintel, walking into it.
	_case("one stride from a 1.30m lintel, walking at it",
		Vector3(LINTEL_X - 1.0, 0, 0), Vector3(2.0, 0, 0), true)
	# 4. THE HOLD: already under the lintel, standing still. He may not stand up.
	_case("under the lintel, still", Vector3(LINTEL_X, 0, 0), Vector3.ZERO, true)
	# 5. THE WALL: one stride from solid ground-to-roof. Ducking buys him nothing and
	#    must not happen - this is the case that makes an auto-crouch unshippable.
	_case("one stride from a solid wall, walking at it",
		Vector3(WALL_X + 1.0, 0, 0), Vector3(-2.0, 0, 0), false)

	if _failures == 0:
		print("=== PASS ===")
	else:
		print("=== FAIL (%d) ===" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _case(name: String, at: Vector3, vel: Vector3, want: bool) -> void:
	_player.global_position = at
	_player.velocity = vel
	var got: bool = _player._auto_crouch_wanted()
	if got != want:
		_fail("%s: auto-crouch %s, expected %s" % [name, got, want])
	else:
		print("  %-46s -> %s" % [name, "DUCK" if got else "stand"])


func _box(at: Vector3, size: Vector3) -> void:
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
