## probe_friendly_lane.gd - item 33: "warn me before I fire through my own men."
##
## Evidence of absence when this was written: no friendly-lane check existed anywhere on
## the player's side - not in weapon_holder.gd, not in mission_hud.gd. The only muzzle
## discipline in the game was the AI's own (ally_base.gd:2060-2067), so the one shooter
## who can actually hit his own squad got no warning at all.
##
## Six cases, and three of them are the ones that decide whether the warning is worth
## having: a man off the line, a man behind you, and a man behind a wall must all read
## CLEAR. A warning that is always on is the same as no warning.
##   godot --headless --path . res://tests/probe_friendly_lane.tscn
extends Node

const STUB := "res://tests/stubs/lane_body_stub.gd"

var _failures: int = 0
var _player: CharacterBody3D = null
var _man: CharacterBody3D = null


func _fail(msg: String) -> void:
	print("FAIL: %s" % msg)
	_failures += 1


func _ready() -> void:
	_run()


func _run() -> void:
	print("=== FRIENDLY LANE PROBE (item 33) ===")
	_box(Vector3(0, -0.5, 0), Vector3(80, 1, 80))          # floor
	var ps: PackedScene = load("res://scenes/player/player.tscn")
	_player = ps.instantiate() as CharacterBody3D
	add_child(_player)
	_player.global_position = Vector3.ZERO
	# The player looks down -Z with no rotation applied.
	await get_tree().physics_frame

	_case("nobody out there", false)

	_man = CharacterBody3D.new()
	_man.set_script(load(STUB))
	add_child(_man)
	AgentRegistry.allies.append(_man)

	_man.global_position = Vector3(0, 0, -10)
	_case("a squadmate 10m straight down the bore", true)

	_man.global_position = Vector3(3.0, 0, -10)
	_case("a squadmate 10m out and 3m off the line", false)

	_man.global_position = Vector3(0, 0, 10)
	_case("a squadmate 10m BEHIND him", false)

	_man.global_position = Vector3(0, 0, -10)
	_box(Vector3(0, 1.5, -5), Vector3(6, 4, 1))            # a wall between them
	await get_tree().physics_frame
	_case("a squadmate down the bore with a wall in between", false)

	_man.dead = true
	_case("a dead squadmate down the bore", false)

	if _failures == 0:
		print("=== PASS ===")
	else:
		print("=== FAIL (%d) ===" % _failures)
	AgentRegistry.allies.clear()
	get_tree().quit(0 if _failures == 0 else 1)


func _case(name: String, want: bool) -> void:
	var got: bool = _player._friendly_in_lane()
	if got != want:
		_fail("%s: lane %s, expected %s" % [name, got, want])
	else:
		print("  %-48s -> %s" % [name, "CHECK FIRE" if got else "clear"])


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
