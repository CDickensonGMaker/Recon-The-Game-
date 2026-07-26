class_name RadioHandset
extends Node3D
## The PRC-25 handset: who is holding it, and what happens when they walk too far.
##
## Lives on the RTO and owns TWO handset meshes, showing exactly one - stowed_mesh
## (bone-attached to the RTO) and held_mesh (on the holder's hand). Taking it is a
## SWAP, NOT a reparent: the two live in different spaces (a Mixamo bone vs the
## player's hand/viewmodel), and reparenting a bone-attached mesh across skeletons
## is how gear ends up on the floor.
##
## The cord NEVER blocks movement. It bellies, reads TAUT at `taut_at`, and past
## full stretch the handset is RIPPED out of the holder's hand and snaps back.
##
## `handset_taken` is emitted so the weapon system can stow the weapon - holding
## the handset costs you your rifle.

signal handset_taken(by: Node3D)
signal handset_returned()
signal cord_snapped()
signal cord_taut(is_taut: bool)

enum State { STOWED, HELD }

## The handset clipped to the RTO (BoneAttachment3D -> MeshInstance3D).
@export var stowed_mesh: Node3D
## The handset in the holder's hand. Hidden until taken.
@export var held_mesh: Node3D
## The procedural cord.
@export var cord: RadioCord
## The cord's anchor when stowed (on the RTO's handset).
@export var stowed_endpoint: Node3D
## The cord's anchor when held (on the holder's hand).
@export var held_endpoint: Node3D

## Fraction of full cord length at which the cord reads as taut.
@export_range(0.5, 0.99) var taut_at: float = 0.75

var state: State = State.STOWED

var _was_taut: bool = false


func _ready() -> void:
	_apply_state()


func can_take() -> bool:
	return state == State.STOWED


## Called by the player's interaction system when he grabs the handset off the RTO.
func take(by: Node3D) -> bool:
	if state != State.STOWED or by == null:
		return false
	state = State.HELD
	_apply_state()
	handset_taken.emit(by)
	return true


## Put it back. Also called when the cord snaps.
func stow() -> void:
	if state == State.STOWED:
		return
	state = State.STOWED
	_was_taut = false
	cord_taut.emit(false)
	_apply_state()
	handset_returned.emit()


func _apply_state() -> void:
	var held: bool = state == State.HELD
	if stowed_mesh != null:
		stowed_mesh.visible = not held
	if held_mesh != null:
		held_mesh.visible = held
	if cord != null:
		# the cord's far end follows the handset, wherever the handset now is
		cord.endpoint = held_endpoint if held else stowed_endpoint


func _physics_process(_delta: float) -> void:
	if state != State.HELD or cord == null:
		return

	var t: float = cord.tension()

	if t >= 1.0:
		# Past full stretch. Rip it out of his hand rather than trapping him.
		cord_snapped.emit()
		stow()
		return

	var taut: bool = t >= taut_at
	if taut != _was_taut:
		_was_taut = taut
		cord_taut.emit(taut)


## Build the RTO's radio rig: the stowed handset bound to the man's own prc25_handset
## mesh, a procedural cord over placeholder marker anchors, and the handset itself
## stamped on the RTO as meta "handset" for the player's interact to find. Returns the
## handset (already a child of `rto`), or null if the body carries no prc25_handset
## mesh. ONE builder - the arena and the squad both call it, so the rig never forks.
static func attach_to(rto: AllyBase) -> RadioHandset:
	if rto == null:
		return null
	var ma := rto.sprite_actor as ModelActor
	if ma == null:
		return null
	var root: Node3D = ma.instance_root()
	if root == null:
		return null
	var stowed: MeshInstance3D = _find_mesh_named(root, "prc25_handset")
	if stowed == null:
		push_warning("[RADIO] RTO body has no prc25_handset mesh - no handset to grab")
		return null
	var port := Marker3D.new()
	rto.add_child(port)
	port.position = Vector3(0.0, 1.25, -0.18)   # radio on his back
	var guide := Marker3D.new()
	rto.add_child(guide)
	guide.position = Vector3(0.16, 1.4, -0.05)   # over the left shoulder
	var stow_ep := Marker3D.new()
	rto.add_child(stow_ep)
	stow_ep.position = Vector3(0.14, 1.2, -0.12)  # at the stowed handset
	var new_cord := RadioCord.new()
	new_cord.port = port
	new_cord.guide = guide
	new_cord.endpoint = stow_ep
	rto.add_child(new_cord)
	var handset := RadioHandset.new()
	handset.stowed_mesh = stowed
	handset.cord = new_cord
	handset.stowed_endpoint = stow_ep
	rto.add_child(handset)
	rto.set_meta("handset", handset)
	return handset


## First MeshInstance3D under `root` whose name contains `needle`, or null.
static func _find_mesh_named(root: Node, needle: String) -> MeshInstance3D:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and String(n.name).contains(needle):
			return n as MeshInstance3D
		for c in n.get_children():
			stack.append(c)
	return null
