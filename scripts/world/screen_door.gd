class_name ScreenDoor
extends Node3D

## A screen door on a spring.
##
## IT HAS NO COLLIDER AND IT NEVER BLOCKS. That is the whole design, and it is a Pillar 1
## requirement, not a convenience: an interior the enemy cannot follow you into is a player
## safe room. If the wire goes, they come in after you.
##
## The doorway therefore bakes OPEN and never rebakes - the same contract ZombieDoor states
## at scripts/zombies/zombie_door.gd:8-12. Nothing here is a nav_blocker, and the leaves must
## never be given a -colonly twin.
##
## No interact key either. _try_field_interact (scripts/player/player.gd:948) is a hardcoded
## branch chain with no registry, so every door added there would compete with the medkit
## crate for one button. A screen door needs no button: it opens because a body pushed it.
## Player, allies and enemies all trip it identically.

const OPEN_ANGLE: float = 1.43        ## radians, ~82 deg
const OPEN_SPEED: float = 7.0         ## a shoved screen door snaps open
const SHUT_SPEED: float = 3.2         ## the spring is slower than the shove
const HOLD_AFTER_EXIT: float = 0.30   ## s before the spring takes it back
const BOUNCE: float = 0.16            ## overshoot on the slam, so it does not just stop

@export var leaf_a_path: NodePath
@export var leaf_b_path: NodePath

## Synthesised, not recorded - there is no door foley in assets/audio/sfx and a sprung
## screen door is two sounds. Regenerate with tools/gen_screen_door_sfx.py.
const CREAK := preload("res://assets/audio/sfx/door_screen_creak.wav")
const SLAP := preload("res://assets/audio/sfx/door_screen_slap.wav")
## A door heard across the compound is a door that gives the position away.
const AUDIO_RANGE_M: float = 22.0

var _leaf_a: Node3D = null
var _leaf_b: Node3D = null
var _creak: AudioStreamPlayer3D = null
var _slap: AudioStreamPlayer3D = null
var _was_swinging: bool = false
var _rest_a: float = 0.0
var _rest_b: float = 0.0
var _open: float = 0.0
var _vel: float = 0.0
var _inside: int = 0
var _hold: float = 0.0


## Leaf naming in the export. A hooch ships a PAIR - `_l` and `_r` - sharing a Blender
## duplicate suffix (`.001`), which is what matches one leaf to its partner.
const LEAF_L: String = "door_hooch_leaf_l"
const LEAF_R: String = "door_hooch_leaf_r"
## How deep through the frame the trigger reaches. A man crossing at a run must trip it
## before he is already through.
const THRESHOLD_DEPTH_M: float = 1.5
const THRESHOLD_PAD_M: float = 0.5
## Two leaves of one doorway are within this of each other; the next hooch is not.
const PAIR_MAX_M: float = 3.0


## Hang a spring door on every `door_hooch_leaf_l/_r` PAIR under `root`. Returns the count.
##
## Built procedurally rather than authored per hooch: the export ships 11 of these and a
## hand-placed node per doorway is 11 chances to miss one. The leaves stay exactly where
## the model put them - only the pivot node and the trigger are added.
static func wire_all(root: Node3D) -> int:
	if root == null or not is_instance_valid(root):
		return 0
	var lefts: Array[Node3D] = []
	var rights: Array[Node3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as Node3D
		if mi == null:
			continue
		var nm: String = String(mi.name)
		if nm.begins_with(LEAF_L):
			lefts.append(mi)
		elif nm.begins_with(LEAF_R):
			rights.append(mi)

	# PAIRED BY DISTANCE, not by name. The export numbers duplicates `.001`, `.002`, but
	# Godot's glTF importer sanitises those out of the node names - so keying on the suffix
	# collapsed all eleven doorways into one. Geometry cannot be sanitised.
	var used: Dictionary = {}
	var hung: int = 0
	for a in lefts:
		var best: Node3D = null
		var best_d: float = PAIR_MAX_M
		for b in rights:
			if used.has(b.get_instance_id()):
				continue
			var d: float = a.global_position.distance_to(b.global_position)
			if d < best_d:
				best_d = d
				best = b
		if best != null:
			used[best.get_instance_id()] = true
		if _hang(a, best, str(hung)):
			hung += 1
	# A doorway that shipped only a right leaf still swings.
	for b in rights:
		if used.has(b.get_instance_id()):
			continue
		if _hang(b, null, str(hung)):
			hung += 1
	return hung


static func _hang(a: Node3D, b: Node3D, suffix: String) -> bool:
	var parent: Node = a.get_parent()
	if parent == null:
		return false
	# load(), not the class name: a global class is not registered until the editor
	# rescans, and referencing it inside its own file fails every headless run.
	var door: Node3D = (load("res://scripts/world/screen_door.gd") as GDScript).new()
	door.name = "ScreenDoor_%s" % (suffix if not suffix.is_empty() else "0")

	# The trigger spans the pair, so a two-leaf doorway is one threshold, not two.
	var centre: Vector3 = a.global_position
	var span: float = 1.0
	if b != null:
		centre = (a.global_position + b.global_position) * 0.5
		span = maxf(1.0, a.global_position.distance_to(b.global_position))

	var area := Area3D.new()
	area.name = "Threshold"
	# Bodies only, every faction: player and allies share layer 2, enemies are 4.
	area.collision_layer = 0
	area.collision_mask = 2 | 4
	area.monitorable = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(span + THRESHOLD_PAD_M, 2.2, THRESHOLD_DEPTH_M)
	cs.shape = box
	cs.position = Vector3(0.0, box.size.y * 0.5, 0.0)
	area.add_child(cs)
	door.add_child(area)

	# PATHS FIRST. _ready runs on add_child and resolves them there, so a path assigned
	# afterwards is read as empty and the door never finds its own leaves. The door lands
	# as a SIBLING of the leaves, so "../<name>" is the whole path.
	door.set("leaf_a_path", NodePath("../" + String(a.name)))
	if b != null:
		door.set("leaf_b_path", NodePath("../" + String(b.name)))
	parent.add_child(door)
	door.global_position = centre
	door.global_rotation = a.global_rotation
	return true


func _ready() -> void:
	_leaf_a = get_node_or_null(leaf_a_path) as Node3D
	_leaf_b = get_node_or_null(leaf_b_path) as Node3D
	if _leaf_a != null:
		_rest_a = _leaf_a.rotation.y
	if _leaf_b != null:
		_rest_b = _leaf_b.rotation.y
	var threshold: Area3D = get_node_or_null("Threshold") as Area3D
	if threshold == null:
		push_warning("[ScreenDoor] %s has no Threshold Area3D - the door will never open" % name)
		return
	threshold.body_entered.connect(_on_body_entered)
	threshold.body_exited.connect(_on_body_exited)
	_creak = _voice(CREAK, -8.0)
	_slap = _voice(SLAP, -4.0)


func _voice(stream: AudioStream, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = db
	p.max_distance = AUDIO_RANGE_M
	p.unit_size = 3.0
	add_child(p)
	return p


func _on_body_entered(_body: Node3D) -> void:
	_inside += 1
	_hold = HOLD_AFTER_EXIT


func _on_body_exited(_body: Node3D) -> void:
	_inside = maxi(0, _inside - 1)


func _physics_process(delta: float) -> void:
	var step: float = minf(delta, 0.066)
	if _inside > 0:
		_hold = HOLD_AFTER_EXIT
	elif _hold > 0.0:
		_hold -= step

	var want: float = 1.0 if (_inside > 0 or _hold > 0.0) else 0.0
	if want > _open:
		_open = minf(want, _open + OPEN_SPEED * step)
		_vel = OPEN_SPEED
	else:
		# Swing shut, then let the leaf overshoot past the jamb and settle - that overshoot
		# IS the slap. Without it the door glides to a stop and reads as a sliding panel.
		_vel -= SHUT_SPEED * step
		_open = maxf(-BOUNCE, _open + _vel * step)
		if _open <= 0.0 and _vel < 0.0:
			_vel = -_vel * 0.35
			# The frame catching the leaf, not the leaf reaching zero: this fires on the
			# bounce, so a hard shove slaps and a slow drift settles quietly.
			if _slap != null and absf(_vel) > 0.6:
				_slap.pitch_scale = randf_range(0.94, 1.08)
				_slap.play()
			if absf(_vel) < 0.25:
				_vel = 0.0
				_open = 0.0

	_update_creak()

	var swing: float = _open * OPEN_ANGLE
	if _leaf_a != null:
		_leaf_a.rotation.y = _rest_a + swing
	if _leaf_b != null:
		_leaf_b.rotation.y = _rest_b - swing


## True while either leaf is off its jamb.
func is_swinging() -> bool:
	return _open > 0.02 or absf(_vel) > 0.01


## The creak rides the SWING, not the trigger: a man who stops in the doorway holds the
## leaf still, and a still hinge is silent.
func _update_creak() -> void:
	var now: bool = is_swinging()
	if now and not _was_swinging and _creak != null:
		_creak.pitch_scale = randf_range(0.88, 1.12)
		_creak.play()
	elif not now and _was_swinging and _creak != null and _creak.playing:
		_creak.stop()
	_was_swinging = now
