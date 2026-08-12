## screen_door.gd - a screen door on a spring.
##
## Ruled by the Summoner 2026-08-12: "if the firebase ever gets over run you can hide in the
## hooch and enemies can come in." The door is ALWAYS PASSABLE by everyone - player, allies and
## enemies alike - so an interior can never become a safe room. That is a Pillar 1 requirement,
## not a convenience, and it is why this is not a ZombieDoor: there is no key, no hold, no
## blocker, and nothing to buy.
##
## The leaf is VISUAL ONLY. It carries no collider and never joins nav_blockers, so the doorway
## bakes open and stays open - the same law zombie_door.gd:8-12 already states for its own
## doorways. A man walks through whether the leaf has finished swinging or not.
class_name ScreenDoor
extends Area3D

## The leaf swings this far out of the frame, away from whoever pushed it.
const SWING_DEG: float = 78.0
## Held open while anyone is in the threshold, then sprung.
const SPRING_DELAY_S: float = 0.35
const OPEN_SPEED: float = 9.0
const CLOSE_SPEED: float = 5.5
## Overshoot on the way back, so it clacks instead of easing shut.
const REBOUND_DEG: float = 9.0
const REBOUND_SPEED: float = 14.0
## Leaves are found by name so the model owns which node is the door.
const LEAF_PREFIX: String = "door_"

var leaf: Node3D = null

var _rest_yaw: float = 0.0
var _target_yaw: float = 0.0
var _yaw: float = 0.0
var _inside: int = 0
var _spring_t: float = 0.0
var _rebounding: bool = false


## Hang a spring door on every `door_*` leaf under `root`. Returns how many were hung.
## The frame is the leaf's own AABB grown into the doorway, so the trigger follows the art
## and no separate marker has to be authored and kept in sync.
## Self-preloaded for the same reason SitePlanner preloads this file: a global class is not
## registered until the editor rescans, so referencing ScreenDoor by name inside its own
## static methods fails every headless run on a fresh script.
const SELF_SCRIPT := preload("res://scripts/world/screen_door.gd")


static func wire_all(root: Node3D) -> int:
	if root == null or not is_instance_valid(root):
		return 0
	var hung: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi == null or not String(mi.name).begins_with(LEAF_PREFIX):
			continue
		if _hang(mi) != null:
			hung += 1
	return hung


static func _hang(leaf_mi: MeshInstance3D) -> Area3D:
	var parent: Node = leaf_mi.get_parent()
	if parent == null:
		return null
	var aabb: AABB = leaf_mi.get_aabb()
	var door: Area3D = SELF_SCRIPT.new()
	door.name = "ScreenDoor_" + String(leaf_mi.name)
	# Bodies only, and every faction: player (2), enemies (4). Allies share layer 2.
	door.collision_layer = 0
	door.collision_mask = 2 | 4
	door.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Deep enough through the frame that a man crossing at speed still trips it.
	box.size = Vector3(maxf(aabb.size.x, 0.9) + 0.4, maxf(aabb.size.y, 1.8), 1.4)
	shape.shape = box
	shape.position = Vector3(0.0, box.size.y * 0.5, 0.0)
	door.add_child(shape)
	parent.add_child(door)
	door.global_transform = leaf_mi.global_transform
	door.set("leaf", leaf_mi)
	return door


func _ready() -> void:
	add_to_group(&"screen_doors")
	if leaf != null and is_instance_valid(leaf):
		_rest_yaw = leaf.rotation.y
		_yaw = _rest_yaw
		_target_yaw = _rest_yaw
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## Swing AWAY from the man pushing it: which side of the frame he is on decides the sign.
func _on_body_entered(body: Node3D) -> void:
	_inside += 1
	_spring_t = 0.0
	_rebounding = false
	if leaf == null or not is_instance_valid(leaf):
		return
	var side: float = global_transform.basis.z.dot(body.global_position - global_position)
	var sign_dir: float = -1.0 if side > 0.0 else 1.0
	_target_yaw = _rest_yaw + deg_to_rad(SWING_DEG) * sign_dir


func _on_body_exited(_body: Node3D) -> void:
	_inside = maxi(0, _inside - 1)
	if _inside == 0:
		_spring_t = SPRING_DELAY_S


func _physics_process(delta: float) -> void:
	if leaf == null or not is_instance_valid(leaf):
		set_physics_process(false)
		return

	if _inside == 0 and _spring_t > 0.0:
		_spring_t -= delta
		if _spring_t <= 0.0:
			# Past the frame and back, once - the clack that makes it read as sprung.
			var back: float = signf(_rest_yaw - _target_yaw)
			_target_yaw = _rest_yaw + deg_to_rad(REBOUND_DEG) * back
			_rebounding = true

	var speed: float = OPEN_SPEED
	if _rebounding:
		speed = REBOUND_SPEED
	elif _inside == 0:
		speed = CLOSE_SPEED
	_yaw = lerpf(_yaw, _target_yaw, clampf(delta * speed, 0.0, 1.0))

	if _rebounding and absf(_yaw - _target_yaw) < deg_to_rad(1.5):
		_rebounding = false
		_target_yaw = _rest_yaw

	leaf.rotation.y = _yaw
