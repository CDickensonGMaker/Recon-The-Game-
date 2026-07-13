class_name RadioHandset
extends Node3D
## The PRC-25 handset: who is holding it, and what happens when they walk too far.
##
## Lives on the RTO. Owns TWO handset meshes and shows exactly one of them:
##
##     stowed_mesh  - the 116-tri H-189 clipped to the RTO, bone-attached
##     held_mesh    - the same handset, parented to the player's hand
##
## Grabbing it hides the RTO's and shows the player's. That is the "phone disappears off
## the radio backpack" - it is a SWAP, not a reparent, because the two live in different
## spaces (one on a Mixamo bone, one on the player's hand/viewmodel) and reparenting a
## bone-attached mesh across skeletons is how gear ends up on the floor. We have shipped
## that bug enough times on this project.
##
## THE LEASH, AND WHY IT DOES NOT BLOCK YOU
## A cord that hard-stops the player is miserable: you walk into an invisible wall while
## being shot at, and you cannot tell why. So the cord never blocks movement. Instead:
##
##     0%   - 75%   free. The cord visibly bellies and drags.
##     75%  - 100%  TAUT. The cord straightens (RadioCord does this for free from the
##                  slack), the screen gets a subtle tug, and a warning fires ONCE.
##     > 100%       the handset is RIPPED out of your hand and snaps back to the RTO.
##
## You are never trapped. But you cannot wander off mid-fire-mission and keep the call,
## which is the whole point: it forces you to stand still, in the open, next to the radio
## man, for the length of the call. That is the price of artillery, and it is what makes
## calling it a decision instead of a button.
##
## HOLDING IT COSTS YOUR RIFLE. `handset_taken` is emitted so the weapon system can stow
## the weapon. One hand on the handset means one hand on nothing else - which is why
## ordering the RTO to hunker somewhere safe first (see the radio-man call command) is the
## difference between a fire mission and a death.

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
var holder: Node3D = null

var _was_taut: bool = false


func _ready() -> void:
	_apply_state()


func can_take() -> bool:
	return state == State.STOWED


## Called by the player's interaction system when he grabs the handset off the RTO.
func take(by: Node3D) -> bool:
	if state != State.STOWED or by == null:
		return false
	holder = by
	state = State.HELD
	_apply_state()
	handset_taken.emit(by)
	return true


## Put it back. Also called when the cord snaps.
func stow() -> void:
	if state == State.STOWED:
		return
	holder = null
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
