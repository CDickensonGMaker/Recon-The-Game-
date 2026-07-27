class_name Ladder
extends Node3D

## Climbable ladder. Ported from CatacombsOfGore (scripts/world/ladder.gd +
## player_controller.gd:1076-1193) rather than written fresh, because that version already
## paid for four constraints that are not obvious until a ladder refuses to work:
##
## 1. move_and_slide CANNOT climb a ladder. It collides with the rungs and stalls. The climb
##    writes global_position.y directly and leaves the physics solver alone.
## 2. NEVER end the climb on body_exited. Snapping the climber onto the rail moves him out of
##    the trigger that just caught him, which cancels the climb on its first frame. Dismount
##    is the climber's decision; the trigger only ever starts one.
## 3. Stand him off the rail by FACE_OFFSET or the body sits inside the rungs.
## 4. Zero his velocity every frame or he launches when he steps off.
##
## Geometry comes from marker pairs baked into the GLB - `ladder_bottom*` / `ladder_top*` -
## so a model gains a ladder by gaining two empties, with no scene work. The marker's local
## +Z is its facing (gen_firebase.py:40-42, never re-derive) and points away from the
## structure, which is the side the climber stands on.

const FACE_OFFSET: float = 0.55   ## how far off the rail the body stands, clear of the rungs
const DISMOUNT_LIP: float = 0.30  ## step up at the top so he lands ON the platform
const DISMOUNT_IN: float = 0.95   ## and inboard, so he does not slide straight back off
const PAIR_RANGE: float = 6.0     ## a top marker further than this is a different ladder

@export var climb_speed: float = 2.6

var _bottom: Vector3 = Vector3.ZERO
var _top: Vector3 = Vector3.ZERO
var _face: Vector3 = Vector3.BACK
var _climber: Node3D = null
var _area: Area3D = null


## Build one Ladder per `ladder_bottom*` marker under `root`, pairing each with its nearest
## `ladder_top*`. Returns how many were built.
static func build_from_markers(root: Node3D) -> int:
	if root == null:
		return 0
	var bottoms: Array[Node3D] = []
	var tops: Array[Node3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is Node3D):
			continue
		var nm: String = String(n.name)
		if nm.begins_with("ladder_bottom"):
			bottoms.append(n as Node3D)
		elif nm.begins_with("ladder_top"):
			tops.append(n as Node3D)

	var built: int = 0
	for b in bottoms:
		var best: Node3D = null
		var best_d: float = PAIR_RANGE
		for t in tops:
			var d: float = Vector2(b.global_position.x - t.global_position.x,
				b.global_position.z - t.global_position.z).length()
			if d < best_d:
				best_d = d
				best = t
		if best == null:
			push_warning("[Ladder] %s has no ladder_top within %.1f m - skipped" % [b.name, PAIR_RANGE])
			continue
		var lad := Ladder.new()
		lad.name = "Ladder_%d" % built
		root.add_child(lad)
		# Local +Z of the bottom marker is its facing, and faces away from the structure.
		lad.setup(b.global_position, best.global_position, b.global_transform.basis.z)
		built += 1
	return built


func setup(bottom_pos: Vector3, top_pos: Vector3, face_dir: Vector3) -> void:
	_bottom = bottom_pos
	_top = top_pos
	var f := Vector3(face_dir.x, 0.0, face_dir.z)
	_face = f.normalized() if f.length() > 0.01 else Vector3.BACK
	global_position = _bottom
	_build_trigger()


func _build_trigger() -> void:
	var height: float = maxf(1.0, _top.y - _bottom.y)
	_area = Area3D.new()
	_area.name = "ClimbTrigger"
	_area.collision_layer = 0
	_area.collision_mask = 2          # layer 2 = player (RECON physics layer table)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, height, 1.4)
	shape.shape = box
	_area.add_child(shape)
	add_child(_area)
	# Centred on the standing side, not on the rungs, so he catches it walking up to it.
	var mid: Vector3 = (_bottom + _top) * 0.5 + _face * FACE_OFFSET
	_area.global_position = mid
	_area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _climber != null or body == null:
		return
	if not body.is_in_group("player"):
		return
	if not body.has_method("start_climbing"):
		return
	_climber = body
	body.call("start_climbing", self)


## Deliberately no _on_body_exited. See note 2 in the header.

func bottom_y() -> float:
	return _bottom.y


func top_y() -> float:
	return _top.y


## World point the climber's body is held at for a given height.
func rail_point(y: float) -> Vector3:
	var p: Vector3 = _bottom + _face * FACE_OFFSET
	p.y = y
	return p


## Where he ends up when he tops out: up onto the deck and inboard off the rail.
func dismount_point() -> Vector3:
	var p: Vector3 = _top - _face * DISMOUNT_IN
	p.y = _top.y + DISMOUNT_LIP
	return p


func release_climber() -> void:
	_climber = null


func _exit_tree() -> void:
	if _area != null and _area.body_entered.is_connected(_on_body_entered):
		_area.body_entered.disconnect(_on_body_entered)
